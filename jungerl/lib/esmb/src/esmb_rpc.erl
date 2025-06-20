%%% --------------------------------------------------------------------
%%% File    : esmb_rpc.erl
%%% Created : 20 Sep 2004 by Torbjorn Tornkvist <tobbe@bluetail.com>
%%% Purpose : 
%%%
%%% @doc Implementation of DCE/RPC over SMB.
%%% @author  Torbj�rn T�rnkvist <tobbe@bluetail.com>
%%% @reference "DCE 1.1: RPC", Spec.C706 from 
%%%    <a href="http://www.opengroup.org/pubs/catalog/c706.htm">
%%%       www.opengroup.org</a>
%%% @reference "DCE/RPC over SMB", Luke Leighton, ISBN-1-57870-150-3 .
%%% @end
%%%
%%% $Id: esmb_rpc.erl,v 1.5 2005/11/24 13:59:10 etnt Exp $
%%% --------------------------------------------------------------------
-module(esmb_rpc).
-export([rpc_samr_connect/3, rpc_samr_close/3, rpc_samr_enum_doms/3,
	 rpc_samr_lookup_doms/4, rpc_samr_lookup_names/5,
	 rpc_samr_open_domain/5, rpc_samr_user_groups/4,
	 rpc_samr_open_user/5, rpc_samr_open_user/6, 
	 open_srvsvc_pipe/2, open_samr_pipe/2, rpc_samr_lookup_rids/5,
	 rpc_netr_share_enum/3, rpc_bind/3]).

%%% For testing
-export([test/0,skrak/0,test/3,test2/0,test2/1]).

-import(esmb, [unicode_p/1, to_ucs2/2, to_ucs2_and_null/2, ucs2_to_ascii/1]).
-import(esmb, [b2l/1, hexprint/1]).

-include("esmb_lib.hrl").
-include("esmb_rpc.hrl").


%%% ==============================================
%%% ====== T Y P E  D E C L A R A T I O N S ======
%%% ==============================================
%%%
%%% @type pdu(). The smbpdu{} record.
%%%
%%% @type exception(). Raises a throw(Error) exception.
%%%
%%% @type ctxHandle() = {ok, CtxHandle} | {error, ReturnCode}
%%%              CtxHandle  = binary()
%%%              ReturnCode = integer().
%%%
%%% @type rpcResponse(). The #rpc_response{} record.
%%%
%%% @type domain(). The #dom_entry{} record.
%%% @type domains(). List of domain()
%%%
%%% @type nameEntry(). The #name_entry{} record
%%% @type nameEntries(). List of nameEntry()
%%%
%%% @type nseEntry(). The #nse_entry{} record
%%% @type nseEntries(). List of nseEntry()
%%%
%%% @type serviceType(). Either of ?ST_SRVSVC or ?ST_SAMR
%%%





%%% @hidden
test() ->
    test("192.168.128.65", "tobbe", "qwe123").

%%% @hidden
skrak() ->
    test("192.168.128.42", "tobbe", "qwe123").

%%% @hidden
test(Host, User, Passwd) ->
    %%
    %% List shares on server
    %%
    {ok,S,Neg} = esmb:connect(Host),
    U = #user{pw = Passwd, name = User},
    Pdu0 = esmb:user_logon(S, Neg, U),
    esmb:exit_if_error(Pdu0, "Login failed"),
    IPC = "\\\\"++Host++"\\IPC"++[$$],
    Path1 = to_ucs2(unicode_p(Neg), IPC),
    Pdu1 = esmb:tree_connect(S, Neg, Pdu0, Path1, ?SERVICE_NAMED_PIPE),
    esmb:exit_if_error(Pdu1, "Tree connect failed"),
    %%
    Pdu2 = open_srvsvc_pipe(S, Pdu1),
    esmb:exit_if_error(Pdu2, "Open file, failed"),
    %%
    rpc_bind(S, Pdu2, ?ST_SRVSVC),
    IpStr = "\\\\192.168.128.51",
    Nse = rpc_netr_share_enum(S, Pdu2, IpStr),
    esmb:close_file(S, Pdu2),
    esmb:close(S),
    print_nse(Nse).

		
print_nse(L) -> 
    F = fun(E) -> io:format("Share(~p): ~s~n",
			    [dir_type(E#nse_entry.type),
			     b2l(ucs2_to_ascii(E#nse_entry.name))])
	end,
    lists:foreach(F,L).

dir_type(?DIR)           -> "dir";
dir_type(?HIDDEN_DIR)    -> "hdir";
dir_type(?HIDDEN_IPC)    -> "hipc";
dir_type(?PRINTER_QUEUE) -> "prtQ";
dir_type(Else)           -> Else.


%%% @hidden
test2() ->
    test2("192.168.128.65").

%%% @hidden
test2(Host) ->
    %%
    %% NTLM authenticate user
    %%
    {ok,S,Neg} = esmb:connect(Host),
    U = #user{pw = "qwe123", name = "tobbe"},
    Pdu0 = esmb:user_logon(S, Neg, U),
    esmb:exit_if_error(Pdu0, "Login failed"),
    IPC = "\\\\"++Host++"\\IPC"++[$$],
    Path1 = to_ucs2(unicode_p(Neg), IPC),
    Pdu1 = esmb:tree_connect(S, Neg, Pdu0, Path1, ?SERVICE_NAMED_PIPE),
    esmb:exit_if_error(Pdu1, "Tree connect failed"),
    %%
    {ok,Pdu2} = open_samr_pipe(S, Pdu1),
    %%
    rpc_bind(S, Pdu2, ?ST_SAMR),
    IpStr = "\\\\192.168.128.51",     % FIXME
    Res = samr_test(S, Pdu2, IpStr),
    esmb:close_file(S, Pdu2),
    esmb:close(S),
    Res.

samr_test(S, Pdu, IpStr) ->
    catch do_samr_test(S, Pdu, IpStr).

do_samr_test(S, Pdu, IpStr) ->
    %%
    %% Test case 1
    %%
    CtxHandle1 = rpc_samr_connect(S, Pdu, IpStr),
    Doms1 = rpc_samr_enum_doms(S, Pdu, CtxHandle1),
    Doms2 = rpc_samr_lookup_doms(S, Pdu, CtxHandle1, Doms1),
    rpc_samr_close(S, Pdu, CtxHandle1),
    print_edom(Doms2),
    %%
    %% Test case 2
    %%
    CtxHandle2 = rpc_samr_connect(S, Pdu, IpStr),
    %% NB: Doms2 will be just a single record at the moment, FIXME !!
    CtxHandle3 = rpc_samr_open_domain(S, Pdu, IpStr, CtxHandle2, Doms2),
    Name = to_ucs2(unicode_p(Pdu), "tobbe"),
    {Rid, Type} = rpc_samr_lookup_names(S, Pdu, IpStr, CtxHandle3, Name),
    User = #name_entry{name = Name, rid = Rid},
    CtxHandleU = rpc_samr_open_user(S, Pdu, IpStr, CtxHandle3, User),
    RidList = rpc_samr_user_groups(S, Pdu, IpStr, CtxHandleU),
    rpc_samr_close(S, Pdu, CtxHandleU),
    Ns = rpc_samr_lookup_rids(S, Pdu, IpStr, CtxHandle3, RidList),
    rpc_samr_close(S, Pdu, CtxHandle3),
    rpc_samr_close(S, Pdu, CtxHandle2),
    print_names(Ns),
    Ns.

    

print_names(L) when list(L) -> 
    F = fun(E) -> io:format("Group Names: ~s~n",
			    [b2l(ucs2_to_ascii(E#name_entry.name))])
	end,
    lists:foreach(F,L);
print_names(E) ->
    print_names([E]).

    

print_edom(L) when list(L) -> 
    F = fun(E) -> io:format("Domain: ~s~n",
			    [b2l(ucs2_to_ascii(E#dom_entry.domain))])
	end,
    lists:foreach(F,L);
print_edom(E) ->
    print_edom([E]).



%%% ================================================
%%% ====== E X P O R T E D  I N T E R F A C E ======
%%% ================================================


%%%
%%% @spec open_srvsvc_pipe(S::socket(), PDU::pdu()) ->
%%%          {ok,pdu()} | exception()
%%%
%%% @doc Opens up the <em>srvsvc</em> pipe (NT Administrative
%%%      Services). This is the first thing that needs to be
%%%      done before any DCE/RPC requests can be issued.
%%%      The returned pdu() record will contain the <em>FID</em>
%%%      file descriptor.
%%% @end
%%%
open_srvsvc_pipe(S, Pdu0) ->
    Path = to_ucs2(unicode_p(Pdu0), "\\srvsvc"),
    Pdu1 = esmb:open_file_rw(S, Pdu0, Path),
    esmb:exit_if_error(Pdu1, "Open srvsvc pipe, failed"),
    {ok,Pdu1}.

%%%
%%% @spec open_samr_pipe(S::socket(), PDU::pdu()) ->
%%%          {ok,pdu()} | exception()
%%%
%%% @doc Opens up the <em>samr</em> pipe (NT SAM Database
%%%      Management Services). This is the first thing that 
%%%      needs to be done before any DCE/RPC requests can 
%%%      be issued.
%%% @end
%%%
open_samr_pipe(S, Pdu0) ->
    Path = to_ucs2(unicode_p(Pdu0), "\\samr"),
    Pdu1 = esmb:open_file_rw(S, Pdu0, Path),
    esmb:exit_if_error(Pdu0, "Open samr pipe, failed"),
    {ok,Pdu1}.


%%%
%%% @spec rpc_bind(S::socket(), PDU::pdu(), 
%%%                ST::serviceType()) ->
%%%          {ok, pdu()} | exception()
%%%
%%% @doc This is where a RPC connection is setup. 
%%%      The <em>ServiceType</em> input argument defines
%%%      what Pipe service to use.
%%% @end
%%%
rpc_bind(S, Pdu, ServiceType) ->
    Rpc = e_rpc_bind(ServiceType),
    Pdu2 = esmb:named_pipe_transaction(S, Pdu, Rpc),
    case esmb:error_p(Pdu2) of
	false ->
	    case catch d_bind_response(Pdu2#smbpdu.data) of
		Ack when record(Ack, rpc_bind_ack) ->
		    {ok,Pdu2};
		Else ->
		    ?elog("<CRASH> rpc_bind, d_bind_response=~p~n",[Else]),
		    throw({error, Else})
	    end;
	{true, _Ecode, Emsg} ->
	    throw({error, Emsg})
    end.
	    


%%%
%%% @spec rpc_netr_share_enum(S::socket(), PDU::pdu(), 
%%%                           IpStr::string()) ->
%%%          {ok, nseEntries(), pdu()} | exception()
%%%
%%% @doc The <em>NetrShareEnum</em> request is used to retrieve
%%%      information about the shares offered by the Server,
%%%      including hidden shares (those ending with $).
%%%      Works over the <em>srvsvc</em> pipe.
%%%      <br/>Example:
%%% ```
%%%  IpStr = "\\\\192.168.128.51",
%%%  Nse = rpc_netr_share_enum(S, Pdu, IpStr),
%%% '''
%%%      Where: Nse = [{nse_entry, ?DIR, "NETLOGON", "Logon Server Share"}, ...]
%%% @end
%%%
rpc_netr_share_enum(S, Pdu, IpStr) ->
    UnicodeP = unicode_p(Pdu),
    SrvSvcPdu = e_rpc_netr_share_enum(UnicodeP, IpStr),
    Pdu2 = esmb:named_pipe_transaction(S, Pdu, SrvSvcPdu),
    case esmb:error_p(Pdu2) of
	false ->
	    case catch d_rpc_response(S, Pdu2, Pdu2#smbpdu.data) of
		{Pdu3, NseRes} when record(NseRes, rpc_response) ->
		    case catch d_rpc_netr_share_enum(UnicodeP, NseRes) of
			{ok, Nse} -> {ok,Nse,Pdu3};
			Else ->
			    ?elog("d_netr_share_enum failed: ~p~n",[Else]),
			    throw({error, "netr_share_enum"})
		    end;
		Else ->
		    ?elog("r_netr_share_enum failed: ~p~n",[Else]),
		    throw({error, "rpc_response"})
	    end;
	{true, _Ecode, Emsg} ->
	    throw({error, Emsg})
    end.
	

	 


%%%
%%% @spec rpc_samr_connect(S::socket(), PDU::pdu(), 
%%%                        IpStr::string()) ->
%%%          {ok, CtxHandle, pdu()} | exception()
%%%
%%% @doc The <em>SamrConnect</em> request is the first call that
%%%      must be made on the <em>samr pipe</em>. 
%%% @end
%%%
rpc_samr_connect(S, Pdu, IpStr) ->
    UnicodeP = unicode_p(Pdu),
    SamrPDU = e_rpc_samr_connect2(UnicodeP, IpStr),
    Pdu2 = esmb:named_pipe_transaction(S, Pdu, SamrPDU),
    case esmb:error_p(Pdu2) of
	false ->
	    case catch d_rpc_response(S, Pdu2, Pdu2#smbpdu.data) of
		{Pdu3, Resp1} when record(Resp1, rpc_response) ->
		    case catch d_rpc_samr_connect2(UnicodeP, Resp1) of
			{ok, CtxHandle}   -> {ok, CtxHandle, Pdu3};
			{error, Rc} = Err -> throw(Err);
			Else ->
			    ?elog("d_samr_connect failed: ~p~n",[Else]),
			    throw({error, "samr_connect"})
		    end;
		Else ->
		    ?elog("r_samr_connect failed: ~p~n",[Else]),
		    throw({error, "rpc_response"})
	    end;
	{true, _Ecode, Emsg} ->
	    throw({error, Emsg})
    end.



%%%
%%% @spec rpc_samr_close(S::socket(), PDU::pdu(), 
%%%                      C::ctxHandle()) ->
%%%          {ok, pdu()} | throw(Error)
%%%
%%% @doc After any Policy Handles allocated by any SAM Database
%%%      calls are no longer needed they must be freed with a
%%%      call to this function.
%%% @end
%%%
rpc_samr_close(S, Pdu, CtxHandle) ->
    SamrPDU = e_rpc_samr_close(CtxHandle),
    Pdu2 = esmb:named_pipe_transaction(S, Pdu, SamrPDU),
    case esmb:error_p(Pdu2) of
	false ->
	    case catch d_rpc_response(S, Pdu2, Pdu2#smbpdu.data) of
		{Pdu3, Resp} when record(Resp, rpc_response) ->
		    case catch d_rpc_samr_close(Resp) of
			ok                -> {ok, Pdu3};
			{error, Rc} = Err -> throw(Err);
			Else ->
			    ?elog("d_samr_close failed: ~p~n",[Else]),
			    throw({error, "samr_close"})
		    end;
		Else ->
		    ?elog("r_samr_close failed: ~p~n",[Else]),
		    throw({error, "rpc_response"})
	    end;
	{true, _Ecode, Emsg} ->
	    throw({error, Emsg})
    end.



%%%
%%% @spec rpc_samr_enum_doms(S::socket(), PDU::pdu(), 
%%%                          C::ctxHandle()) ->
%%%          {ok, CtxHandle, pdu()} | throw(Error)
%%%
%%% @doc Obtains a list of Domains at the specified server.
%%% @end
%%%
rpc_samr_enum_doms(S, Pdu, CtxHandle) ->
    UnicodeP = unicode_p(Pdu),
    SamrPDU = e_rpc_samr_enum_doms(UnicodeP, CtxHandle),
    Pdu2 = esmb:named_pipe_transaction(S, Pdu, SamrPDU),
    case esmb:error_p(Pdu2) of
	false ->
	    case catch d_rpc_response(S, Pdu2, Pdu2#smbpdu.data) of
		{Pdu3, Resp1} when record(Resp1, rpc_response) ->
		    case d_rpc_samr_enum_doms(UnicodeP, Resp1) of
			{ok, Doms}        -> {ok, Doms, Pdu3};
			{error, Rc} = Err -> throw(Err);
			Else ->
			    ?elog("d_samr_enum_dom failed: ~p~n",[Else]),
			    throw({error, "samr_enum_dom"})
		    end;
		Else ->
		    ?elog("r_samr_enum_dom failed: ~p~n",[Else]),
		    throw({error, "rpc_response"})
	    end;
	{true, _Ecode, Emsg} ->
	    throw({error, Emsg})
    end.



%%%
%%% @spec rpc_samr_lookup_doms(S::socket(), PDU::pdu(), 
%%%                            C::ctxHandle(), D::domains()) ->
%%%          {ok, domains(), pdu()} | throw(Error)
%%%
%%% @doc Obtains information about the Domains at the specified server.
%%%      The information contains the SID (Security Identifier) to be
%%%      used in succeedeing domain operations.
%%% @end
%%%
rpc_samr_lookup_doms(S, Pdu, CtxHandle, Doms) ->
    UnicodeP = unicode_p(Pdu),
    Builtin = to_ucs2(UnicodeP, "Builtin"),
    X = [D || D <- Doms, D#dom_entry.domain =/= Builtin],
    %% Just one domain at the moment....
    Dom = hd(X),
    SamrPDU = e_rpc_samr_lookup_doms(UnicodeP, CtxHandle, Dom),
    Pdu2 = esmb:named_pipe_transaction(S, Pdu, SamrPDU),
    case esmb:error_p(Pdu2) of
	false ->
	    case catch d_rpc_response(S, Pdu2, Pdu2#smbpdu.data) of
		{Pdu3, Resp1} when record(Resp1, rpc_response) ->
		    case d_rpc_samr_lookup_doms(UnicodeP, Resp1, Dom) of
			{ok, Ds}          -> {ok, Ds, Pdu3};
			{error, Rc} = Err -> throw(Err);
			Else ->
			    ?elog("d_samr_lookup_doms failed: ~p~n",[Else]),
			    throw({error, "samr_lookup_doms"})
		    end;
		Else ->
		    ?elog("r_samr_lookup_doms failed: ~p~n",[Else]),
		    throw({error, "rpc_response"})
	    end;
	{true, _Ecode, Emsg} ->
	    throw({error, Emsg})
    end.


%%%
%%% @spec rpc_samr_open_domain(S::socket(), PDU::pdu(), 
%%%                          IpStr:: string(), C::ctxHandle(),
%%%                          Dom::domain()) ->
%%%          {ok, ctxHandle(), pdu()} | throw(Error)
%%%
%%% @doc Obtains the returned Policy Handle, to be used as input to
%%%      other Domain operations.
%%% @end
%%%
rpc_samr_open_domain(S, Pdu, IpStr, CtxHandle, Domain) ->
    SamrPDU = e_rpc_samr_open_domain(CtxHandle, Domain),
    Pdu2 = esmb:named_pipe_transaction(S, Pdu, SamrPDU),
    case esmb:error_p(Pdu2) of
	false ->
	    case catch d_rpc_response(S, Pdu2, Pdu2#smbpdu.data) of
		{Pdu3, Resp1} when record(Resp1, rpc_response) ->
		    case d_rpc_samr_open_domain(Resp1) of
			{ok, CtxHandle2}  -> {ok, CtxHandle2, Pdu3};
			{error, Rc} = Err -> throw(Err);
			Else ->
			    ?elog("d_samr_open_domain failed: ~p~n",[Else]),
			    throw({error, "samr_open_domain"})
		    end;
		Else ->
		    ?elog("r_samr_open_domain failed: ~p~n",[Else]),
		    throw({error, "rpc_response"})
	    end;
	{true, _Ecode, Emsg} ->
	    throw({error, Emsg})
    end.


%%%
%%% @spec rpc_samr_lookup_names(S::socket(), PDU::pdu(), 
%%%                          IpStr:: string(), C::ctxHandle(),
%%%                          N::names()) ->
%%%          {ok, rid(), ridType(), pdu()} | throw(Error)
%%%
%%% @doc Resolves User, Group, and Alias names in a Domain to
%%%      Relative Identifiers (RIDs). The request takes a Domain
%%%      Policy Handle as input, plus a list of names to be 
%%%      resolved to RIDs.
%%% @end
%%%
rpc_samr_lookup_names(S, Pdu, IpStr, CtxHandle, Names) ->
    SamrPDU = e_rpc_samr_lookup_names(Pdu, CtxHandle, Names),
    Pdu2 = esmb:named_pipe_transaction(S, Pdu, SamrPDU),
    case esmb:error_p(Pdu2) of
	false ->
	    case catch d_rpc_response(S, Pdu2, Pdu2#smbpdu.data) of
		{Pdu3, Resp1} when record(Resp1, rpc_response) ->
		    case d_rpc_samr_lookup_names(Resp1) of
			{ok, Rid, Type}   -> {ok, Rid, Type, Pdu3};
			{error, Rc} = Err -> throw(Err);
			Else ->
			    ?elog("d_samr_lookup_names failed: ~p~n",[Else]),
			    throw({error, "samr_lookup_names"})
		    end;
		Else ->
		    ?elog("r_samr_lookup_names failed: ~p~n",[Else]),
		    throw({error, "rpc_response"})
	    end;
	{true, _Ecode, Emsg} ->
	    throw({error, Emsg})
    end.



%%%
%%% @spec rpc_samr_open_user(S::socket(), PDU::pdu(), 
%%%                          IpStr:: string(), C::ctxHandle(),
%%%                          Name::string(), R::rid()) ->
%%%          {ok,ctxHandle(),pdu()} | throw(Error)
%%%
%%% @doc Obtains the returned Policy Handle, to be used as input to
%%%      other User operations.
%%% @end
%%%
rpc_samr_open_user(S, Pdu, IpStr, CtxHandle, Name, Rid) ->
    User = #name_entry{name = Name, rid = Rid},
    rpc_samr_open_user(S, Pdu, IpStr, CtxHandle, User).

%%%
%%% @spec rpc_samr_open_user(S::socket(), PDU::pdu(), 
%%%                          IpStr:: string(), C::ctxHandle(),
%%%                          U::user()) ->
%%%          {ok,ctxHandle(),pdu()} | throw(Error)
%%%
%%% @doc Obtains the returned Policy Handle, to be used as input to
%%%      other User operations.
%%% @end
%%%
rpc_samr_open_user(S, Pdu, IpStr, CtxHandle, User) ->
    SamrPDU = e_rpc_samr_open_user(CtxHandle, User),
    Pdu2 = esmb:named_pipe_transaction(S, Pdu, SamrPDU),
    case esmb:error_p(Pdu2) of
	false ->
	    case catch d_rpc_response(S, Pdu2, Pdu2#smbpdu.data) of
		{Pdu3, Resp1} when record(Resp1, rpc_response) ->
		    case d_rpc_samr_open_user(Resp1) of
			{ok, CtxHandle2}  -> {ok,CtxHandle2,Pdu3};
			{error, Rc} = Err -> throw(Err);
			Else ->
			    ?elog("d_samr_open_user failed: ~p~n",[Else]),
			    throw({error, "samr_open_user"})
		    end;
		Else ->
		    ?elog("r_samr_open_user failed: ~p~n",[Else]),
		    throw({error, "rpc_response"})
	    end;
	{true, _Ecode, Emsg} ->
	    throw({error, Emsg})
    end.


%%%
%%% @spec rpc_samr_user_groups(S::socket(), PDU::pdu(), 
%%%                          IpStr:: string(), C::ctxHandle()) ->
%%%          {ok, nameEntries(), pdu()} | throw(Error)
%%%
%%% @doc Obtains the RIDs of the groups a certain User belongs to.
%%%      As input, the Policy Handle returned from an OpenUser
%%%      is required.
%%% @end
%%%
rpc_samr_user_groups(S, Pdu, IpStr, CtxHandle) ->
    SamrPDU = e_rpc_samr_user_groups(CtxHandle),
    Pdu2 = esmb:named_pipe_transaction(S, Pdu, SamrPDU),
    case esmb:error_p(Pdu2) of
	false ->
	    case catch d_rpc_response(S, Pdu2, Pdu2#smbpdu.data) of
		{Pdu3, Resp1} when record(Resp1, rpc_response) ->
		    case d_rpc_samr_user_groups(Resp1) of
			{ok, RidList}     -> {ok,RidList,Pdu3};
			{error, Rc} = Err -> throw(Err);
			Else ->
			    ?elog("d_samr_user_groups failed: ~p~n",[Else]),
			    throw({error, "samr_open_user"})
		    end;
		Else ->
		    ?elog("r_samr_user_groups failed: ~p~n",[Else]),
		    throw({error, "rpc_response"})
	    end;
	{true, _Ecode, Emsg} ->
	    throw({error, Emsg})
    end.



%%%
%%% @spec rpc_samr_lookup_rids(S::socket(), PDU::pdu(), 
%%%                          IpStr:: string(), C::ctxHandle(),
%%%                          nameEntries()) ->
%%%          {ok, nameEntries(), pdu()} | throw(Error)
%%%
%%% @doc Resolves User, Group, and Alias names in a Domain, from
%%%      Relative Identifiers (RIDs). The request takes a Domain
%%%      Policy Handle as input, plus a list of RIDs.
%%% @end
%%%
rpc_samr_lookup_rids(S, Pdu, IpStr, CtxHandle, Ns0) ->
    SamrPDU = e_rpc_samr_lookup_rids(CtxHandle, Ns0),
    Pdu2 = esmb:named_pipe_transaction(S, Pdu, SamrPDU),
    case esmb:error_p(Pdu2) of
	false ->
	    case catch d_rpc_response(S, Pdu2, Pdu2#smbpdu.data) of
		{Pdu3, Resp1} when record(Resp1, rpc_response) ->
		    case d_rpc_samr_lookup_rids(unicode_p(Pdu), Resp1, Ns0) of
			{ok, Ns}          -> {ok,Ns,Pdu3};
			{error, Rc} = Err -> throw(Err);
			Else ->
			    ?elog("d_samr_lookup_rids failed: ~p~n",[Else]),
			    throw({error, "samr_lookup_rids"})
		    end;
		Else ->
		    ?elog("r_samr_lookup_rids failed: ~p~n",[Else]),
		    throw({error, "rpc_response"})
	    end;
	{true, _Ecode, Emsg} ->
	    throw({error, Emsg})
    end.






%%% ========================================
%%% === I N T E R N A L  R O U T I N E S ===
%%% ========================================


%%%
%%% Encode a DCE/RPC bind request
%%%
e_rpc_bind(ServiceType) ->
    FragLength = 72,  % The length of the whole RPC packet.
    AuthLength = 0,   % ?
    Call_ID = 1,      % To match the response
    AssocGroup = 0,   % Zero(0) indicates a new assoc.grp
    B0 = <<?RPC_VERSION, 
	  ?RPC_MINOR_VERSION, 
	  ?RPC_OP_BIND,
	  ?PACKET_FLAGS,
	  ?DATA_REPRESENTATION:32, % NB: don't use 'little', it is a vector
	  FragLength:16/little,
	  AuthLength:16/little,
	  Call_ID:32/little,
	  ?MAX_XMIT_FRAG:16/little,
	  ?MAX_RECV_FRAG:16/little,
	  AssocGroup:32/little>>,
    %% We just handle one single entry in the list for now	
    NumCtxItems = 1,
    NumTransItems = 1, % only one transfer syntax item for now
    Context_ID = 0,    % defined by the client
    UUID = uuid(ServiceType),
    IfaceVer = iface_ver(ServiceType),
    TransferSyntax = transfer_syntax(),
    ContextList = <<Context_ID:16/little,
                   NumTransItems,
                   0,              % pad
                   UUID/binary,
                   IfaceVer:16/little,          
                   ?IFACE_VER_MINOR:16/little,
                   TransferSyntax/binary,       % a list really...
                   ?SYNTAX_VERSION:32/little>>, % - "" -
    B1 = <<NumCtxItems,
	  0,0,0,           % reserved
	  ContextList/binary>>,
    <<B0/binary,B1/binary>>.


%%% Depending on "service type" ?
iface_ver(?ST_SAMR)   -> 1;
iface_ver(?ST_SRVSVC) -> 3.

%%%
%%% Encode a DCE/RPC request
%%%


e_rpc_samr_lookup_rids(CtxHandle, Rids) ->
    Pdu = e_samr_lookup_rids(CtxHandle, Rids),
    e_rpc_request(?OP_SAMR_LOOKUP_RIDS_IN_DOMAIN, Pdu).

%%% Rids == list of nameEntry()
e_samr_lookup_rids(CtxHandle, Rids) when list(Rids) ->
    Count = length(Rids),
    F = fun(R,Acc) -> <<(R#name_entry.rid):32/little, Acc/binary>> end,
    B = lists:foldr(F, <<>>, Rids),
    MaxCount = 1000,    % some sort of flag ?
    ActualCount = Count,
    <<CtxHandle/binary,
      Count:32/little,
      MaxCount:32/little,
      0:32/little,           % Offset
      ActualCount:32/little,
      B/binary>>.

%%% ---

%%% NB: The context handle is obtained from the OpenUser-Reply
e_rpc_samr_user_groups(CtxHandle) ->
    Pdu = e_samr_user_groups(CtxHandle),
    e_rpc_request(?OP_SAMR_GET_GROUPS_FOR_USER, Pdu).

e_samr_user_groups(CtxHandle) when binary(CtxHandle) ->
    CtxHandle.

%%% ---

e_rpc_samr_open_user(CtxHandle, U) ->
    Pdu = e_samr_open_user(CtxHandle, U),
    e_rpc_request(?OP_SAMR_OPEN_USER, Pdu).

e_samr_open_user(CtxHandle, U) ->
    Rid = U#name_entry.rid,
    <<CtxHandle/binary,
      16#0002011b:32/little,   % AccessMask, unknown value...
      Rid:32/little>>.

%%% ---

%%% Name(s) should be Unicode "processed" already.
e_rpc_samr_lookup_names(Pdu, CtxHandle, Names) ->
    Pdu2 = e_samr_lookup_names(unicode_p(Pdu), CtxHandle, Names),
    e_rpc_request(?OP_SAMR_LOOKUP_NAMES_IN_DOMAIN, Pdu2).

e_samr_lookup_names(UnicodeP, CtxHandle, Name) when binary(Name) ->
    Count = 1, 
    MaxCount = 1000,   % Some sort of flag ?
    ActualCount = 1,
    Length = Size = size(Name),
    MaxCount2 = ActualCount2 = Length div nchars(UnicodeP),
    <<CtxHandle/binary,
      Count:32/little,
      %% --- Only handling one single name at the moment...
      MaxCount:32/little,
      0:32/little,            % Offset
      ActualCount:32/little,
      Length:16/little,
      Size:16/little,
      1:32/little,            % RefId
      MaxCount2:32/little,
      0:32/little,            % Offset
      ActualCount2:32/little,
      Name/binary>>.

%%% ---

e_rpc_samr_open_domain(CtxHandle, Dom) ->
    Pdu = e_samr_open_domain(CtxHandle, Dom),
    e_rpc_request(?OP_SAMR_OPEN_DOMAIN, Pdu).

%%% Open account, Enum account, Lookup info2
-define(SAMR_OD_ACCESS_MASK,  16#00000304).

e_samr_open_domain(CtxHandle, Dom) ->
    SidCount = 4,  % ?
    Sid = Dom#dom_entry.sid,
    <<CtxHandle/binary,
      ?SAMR_OD_ACCESS_MASK:32/little,
      SidCount:32/little,
      Sid/binary>>.

%%% ---


e_rpc_samr_close(CtxHandle) ->
    Pdu = e_samr_close(CtxHandle),
    e_rpc_request(?OP_SAMR_CLOSE_HANDLE, Pdu).

e_samr_close(CtxHandle) when binary(CtxHandle) ->
    CtxHandle.

%%% ---

e_rpc_samr_lookup_doms(UnicodeP, CtxHandle, Dom) ->
    Pdu = e_samr_lookup_doms(UnicodeP, CtxHandle, Dom),
    e_rpc_request(?OP_SAMR_LOOKUP_DOMAIN_IN_SAM_SERVER, Pdu).

e_samr_lookup_doms(UnicodeP, CtxHandle, Dom) ->
    Length = Size = Dom#dom_entry.len,
    Domain = Dom#dom_entry.domain,
    Offset = 0,
    MaxCount = ActualCount = Length div nchars(UnicodeP),
    <<CtxHandle/binary,
      Length:16/little,
      Size:16/little,
      1:32/little,             % RefId
      MaxCount:32/little,
      0:32/little,             % Offset
      ActualCount:32/little,
      Domain/binary>>.

%%% ---

e_rpc_samr_enum_doms(UnicodeP, CtxHandle) ->
    Pdu = e_samr_enum_doms(UnicodeP, CtxHandle),
    e_rpc_request(?OP_SAMR_ENUMERATE_DOMAINS_IN_SAM_SERVER, Pdu).

e_samr_enum_doms(UnicodeP, CtxHandle) ->
    ResumeHandle = 0,         % ?
    PrefMaxSize  = 16#10000,  % ?
    <<CtxHandle/binary,
     ResumeHandle:32/little,
     PrefMaxSize:32/little>>.

%%% ---

e_rpc_samr_connect2(UnicodeP, IpStr) ->
    Pdu = e_samr_connect2(UnicodeP, IpStr),
    e_rpc_request(?OP_SAMR_CONNECT2, Pdu).

e_samr_connect2(UnicodeP, IpStr) ->
    UipStr = to_ucs2_and_null(UnicodeP, IpStr),
    MaxCount = ActualCount = length(IpStr) + 1, % null byte at end
    B0 = <<1:32/little,           % RefId
	  MaxCount:32/little,     % max.num of array elems
	  0:32/little,            % Offset for first elem in array
	  ActualCount:32/little,
	  UipStr/binary>>,
    Pad = size(B0) rem 4,
    AccessMask = ?SAMR_ACCESS_MASK,
    <<B0/binary,
      0:Pad/?BYTE,
      AccessMask:32/little>>.
    

%%% ---

e_rpc_netr_share_enum(UnicodeP, IpStr) ->
    Pdu = e_ss_netr_share_enum(UnicodeP, IpStr),
    e_rpc_request(?OP_SS_NETR_SHARE_ENUM, Pdu).

%%% Example: IpStr = "\\\\192.168.128.51"
e_ss_netr_share_enum(UnicodeP, IpStr) when list(IpStr) ->
    RefId = 1,      % ?
    Offset = 0,
    UipStr = to_ucs2_and_null(UnicodeP, IpStr),
    MaxCount = ActualCount = length(IpStr) + 1, % null byte at end
    B0 = <<RefId:32/little,
	  MaxCount:32/little,     % max.num of array elems
	  Offset:32/little,       % Offset for first elem in array
	  ActualCount:32/little,
	  UipStr/binary>>,
    Pad = size(B0) rem 4,
    %% Different information levels are available,
    %% representing the amount of information returned.
    %% If changing the level here, then the decode routine 
    %% has to be changed accordingly.
    InfoLevel1 = InfoLevel2 = 1,
    NumEntries = 0,
    NullPtr = 0,    % ?
    PrefLength = 16#ffffffff,
    <<B0/binary,
      0:Pad/?BYTE,
      InfoLevel1:32/little,
      InfoLevel2:32/little,
      RefId:32/little,
      NumEntries:32/little,
      NullPtr:32/little,     % share_info_1 array
      PrefLength:32/little,
      NullPtr:32/little>>.   % Enum handle


%%% ---

e_rpc_request(OpNum, PDU) when integer(OpNum), binary(PDU) -> 
    PDUsize = size(PDU),
    FragLength = PDUsize + 24, % The length of the whole RPC packet.
    AuthLength = 0,      % ?
    Call_ID = 2,         % To match the response
    AllocHint = PDUsize, % optional, zero(0) = not provided
    Context_ID = 0,      % the same as in the Bind request
    <<?RPC_VERSION, 
      ?RPC_MINOR_VERSION, 
      ?RPC_OP_REQUEST,
      ?PACKET_FLAGS,
      ?DATA_REPRESENTATION:32,  % don't use little !!
      FragLength:16/little,
      AuthLength:16/little,
      Call_ID:32/little,
      AllocHint:32/little,
      Context_ID:16/little,
      OpNum:16/little,
      PDU/binary>>.

    
%%% ===============================================
%%% ====== D E C O D I N G   R O U T I N E S ======
%%% ===============================================


%%%
%%% Decode a SAMR LookupRids response
%%%

d_rpc_samr_lookup_rids(UnicodeP, R, Ns0) when record(R,rpc_response),list(Ns0)->
    <<Count:32/little,     % Number of array entries
     _:4/binary,           % RefId
     MaxCount:32/little,
     Rest0/binary>> = R#rpc_response.data,
    HeaderSz = Count * 8,
    %% The array headers consist of `Count` number of entries like this:
    %%  <<Length:16,Size:16,RefId:32, ...>>
    <<_:HeaderSz/binary,
      Rest1/binary>> = Rest0,
    case catch parse_rid_names(UnicodeP, Count, Rest1, Ns0) of
	{ok, Ns1, <<_:12/binary, Rest2/binary>>} -> 
	    case catch parse_rid_types(UnicodeP, Count, Rest2, Ns1) of
		{ok, Ns2, ReturnCode} when ReturnCode == 0 -> 
		    {ok, Ns2};
		Else ->
		    {error, "parse_rid_types"}
	    end;
	Else -> 
	    {error, "parse_rid_names"}
    end.

parse_rid_names(UnicodeP, NumEntries, Blob, Ns) ->
    parse_rid_names(UnicodeP, NumEntries, Blob, Ns, []).

parse_rid_names(_, 0, Blob, _, Acc) ->
    {ok, lists:reverse(Acc), Blob};
parse_rid_names(UnicodeP, NumEntries, Blob, [N|Ns], Acc) ->
    <<MaxCount:32/little,
      Offset:32/little,
      ActualCount:32/little,
      Rest0/binary>> = Blob,
    Nchars = nchars(UnicodeP),
    Len = ActualCount * nchars(UnicodeP),
    %%
    %% NB: The strings seem to be word aligned (?)
    %%
    if ((ActualCount rem 2) == 0) ->
	    <<Name:Len/binary, Rest1/binary>> = Rest0;
       true ->
	    <<Name:Len/binary, _:Nchars/binary, Rest1/binary>> = Rest0
    end,
    N1 = N#name_entry{name = Name},
    parse_rid_names(UnicodeP, NumEntries - 1, Rest1, Ns, [N1|Acc]).


parse_rid_types(UnicodeP, NumEntries, Blob, Ns) ->
    parse_rid_types(UnicodeP, NumEntries, Blob, Ns, []).

parse_rid_types(_, 0, <<ReturnCode:32/little,_/binary>>, _, Acc) ->
    {ok, lists:reverse(Acc), ReturnCode};
parse_rid_types(UnicodeP, NumEntries, 
		<<RidType:32/little, Rest/binary>>, [N|Ns], Acc) ->
    N1 = N#name_entry{type = RidType},
    parse_rid_types(UnicodeP, NumEntries - 1, Rest, Ns, [N1|Acc]).




%%%
%%% Decode a SAMR Get User Groups response.
%%% 

d_rpc_samr_user_groups(R)  when record(R, rpc_response) ->
    <<_:4/binary,         % RefId
      Count:32/little,    % Num of array entries
      _:4/binary,         % RefId2
      MaxCount:32/little, 
      Rest/binary>> = R#rpc_response.data,
    Size = Count * 8,
    <<Blob:Size/binary,
      ReturnCode:32/little>> = Rest,
    if (ReturnCode == 0) -> {ok, parse_user_groups(Count, Blob)};
       true              -> {error, ReturnCode}
    end.

parse_user_groups(Count, <<Rid:32/little,RidAttr:32/little,Rest/binary>>) 
  when Count > 1 ->
    [#name_entry{rid = Rid} | 
     parse_user_groups(Count - 1, Rest)];
parse_user_groups(1, <<Rid:32/little,RidAttr:32/little>>) ->
    [#name_entry{rid = Rid}];
parse_user_groups(0, _) -> 
    [].


%%%
%%% Decode a SAMR OpenUser response.
%%% 

d_rpc_samr_open_user(R)  when record(R, rpc_response) ->
    <<CtxHandle:20/binary,
      ReturnCode:32/little>> = R#rpc_response.data,
    if (ReturnCode == 0) -> {ok, CtxHandle};
       true              -> {error, ReturnCode}
    end.


%%%
%%% Decode a SAMR OpenDomain response.
%%% 

d_rpc_samr_open_domain(R)  when record(R, rpc_response) ->
    <<CtxHandle:20/binary,
      ReturnCode:32/little>> = R#rpc_response.data,
    if (ReturnCode == 0) -> {ok, CtxHandle};
       true              -> {error, ReturnCode}
    end.


%%%
%%% Decode a SAMR LookupNames response
%%%

%%% NB: We only takes care of one single entry at the moment
d_rpc_samr_lookup_names(R) when record(R, rpc_response) ->
    %% --- Rid Array ---
    <<Count:32/little,   
      _:32/little,        % RefId
      MaxCount:32/little,
      Rid:32/little,
    %% --- Types Array ---
      Tcount:32/little,
      _:32/little,        % RefId,
      TMaxCount:32/little,
      Type:32/little,
    %% ---
      ReturnCode:32/little>> = R#rpc_response.data,
    if (ReturnCode == 0) -> {ok, Rid, Type};
       true              -> {error, ReturnCode}
    end.


%%%
%%% Decode a SAMR Close response
%%%

d_rpc_samr_close(R)  when record(R, rpc_response) ->
    <<_:20/binary,            % CtxHandle
     ReturnCode:32/little>> = R#rpc_response.data,
    if (ReturnCode == 0) -> ok;
       true              -> {error, ReturnCode}
    end.


%%%
%%% Decode a SAMR LookupDomain response
%%%

d_rpc_samr_lookup_doms(UnicodeP, R, Dom) 
  when record(R, rpc_response), record(Dom, dom_entry)  ->
    <<RefId:32/little,
      Count:32/little,
      Sid:24/binary,
      ReturnCode:32/little>> = R#rpc_response.data,
    if (ReturnCode == 0) -> {ok, Dom#dom_entry{sid = Sid}};
       true              -> {error, ReturnCode}
    end.
%%%
%%% Decode a SAMR Connect2 response
%%%

d_rpc_samr_connect2(UnicodeP, R) when record(R, rpc_response) ->
    <<CtxHandle:20/binary,
     ReturnCode:32/little>> = R#rpc_response.data,
    if (ReturnCode == 0) -> {ok, CtxHandle};
       true              -> {error, ReturnCode}
    end.
    
%%%
%%% Decode a SAMR Enumerate Domains response
%%%

d_rpc_samr_enum_doms(UnicodeP, R) when record(R, rpc_response) ->
    <<ResumeHandle:32/little,
     RefId1:32/little,
     Count:32/little,
     RefId2:32/little,
     MaxCount:32/little,
     Blob/binary>> = R#rpc_response.data,
    case catch parse_edom_blob(UnicodeP, Count, Blob) of
	L when list(L) -> {ok, L};
	Else           -> {error, "parse_edom_blob"}
    end.

parse_edom_blob(UnicodeP, NumEntries, Blob) ->
    {Rest, Acc} = parse_edom_headers(NumEntries, Blob, []),
    parse_edom_bodies(UnicodeP, Rest, Acc).

parse_edom_headers(0, Blob, Acc) ->
    {Blob, lists:reverse(Acc)};
parse_edom_headers(NumEntries, Blob, Acc) ->
    <<Index:32/little,
     Length:16/little,
     Size:16/little,
     RefId:32/little,
     Rest/binary>> = Blob,
    N = #dom_entry{index = Index,
		    len   = Length,
		    size  = Size},
    parse_edom_headers(NumEntries - 1, Rest, [N|Acc]).

parse_edom_bodies(UnicodeP, Blob, []) ->
    [];
parse_edom_bodies(UnicodeP, Blob, [H|T]) ->
    <<MaxCount:32/little,
     Offset:32/little,
     ActualCount:32/little,
     B0/binary>> = Blob,
    {Domain, Rest} = str_extract2(UnicodeP, ActualCount, B0),
    [H#dom_entry{domain = Domain} |
     parse_edom_bodies(UnicodeP, Rest, T)].




%%%
%%% Decode a SRSVC NetrShareEnum response
%%%
      
d_rpc_netr_share_enum(UnicodeP, R) when record(R, rpc_response) ->
    <<InfoLevel1:32/little,
     InfoLevel2:32/little,
     RefId1:32/little,
     NumEntries:32/little,
     RefId2:32/little,
     MaxCount:32/little,
     Blob/binary>> = R#rpc_response.data,
    {ok, parse_nse_blob(UnicodeP, NumEntries, Blob)}.


parse_nse_blob(UnicodeP, NumEntries, Blob) ->
    {Rest, Acc} = parse_nse_headers(NumEntries, Blob, []),
    parse_nse_bodies(UnicodeP, Rest, Acc).

parse_nse_headers(0, Blob, Acc) ->
    {Blob, lists:reverse(Acc)};
parse_nse_headers(NumEntries, Blob, Acc) ->
    <<RefId1:32/little,
     ShareType:32/little,
     RefId2:32/little,
     Rest/binary>> = Blob,
    N = #nse_entry{type = ShareType},
    parse_nse_headers(NumEntries - 1, Rest, [N|Acc]).


parse_nse_bodies(UnicodeP, Blob, []) ->
    [];
parse_nse_bodies(UnicodeP, Blob, [H|T]) ->
    <<MaxCount:32/little,
     Offset:32/little,
     ActualCount:32/little,
     B0/binary>> = Blob,
    {Share, B1} = str_extract(UnicodeP, ActualCount, B0),
    <<C_MaxCount:32/little,
     C_Offset:32/little,
     C_ActualCount:32/little,
     B2/binary>> = B1,
    {Comment, Rest} = str_extract2(UnicodeP, C_ActualCount, B2),
    [H#nse_entry{name    = Share,
		 comment = Comment} |
     parse_nse_bodies(UnicodeP, Rest, T)].

%%% ---

str_extract(UnicodeP, ActualCount, B0) ->
    Nchars = nchars(UnicodeP),
    Len   = (ActualCount - 1) * Nchars,
    if ((ActualCount rem 2) == 0) ->
	    <<S0:Len/binary,
	     _:Nchars/binary,     % remove null string termination
	     B1/binary>> = B0,
	    {S0,B1};
       true ->
	    <<S0:Len/binary,
	     _:Nchars/binary,     % remove null string termination
	     _:16,                % string alignement ?
	     B1/binary>> = B0,
	    {S0,B1}
    end.
    
str_extract2(UnicodeP, ActualCount, B0) ->
    Nchars = nchars(UnicodeP),
    Len    = ActualCount * Nchars,
    X = Len+4,
    if ((ActualCount rem 2) == 0) ->
	    <<S0:Len/binary,
	     B1/binary>> = B0,
	    {S0,B1};
       true ->
	    <<S0:Len/binary,
	     _:16,                % string alignement ?
	     B1/binary>> = B0,
	    {S0,B1}
    end.
    



%%%
%%% Decode an RPC response
%%%

-define(DCE_RPC_HSIZE,  16#18).  % DCE/RPC header size in bytes

d_rpc_response(S, Pdu, Packet) ->
    frag_handler(S, Pdu, d_rpc_response_0(Packet)).

frag_handler(_, Pdu, R) when R#rpc_response.frag_type == ?FRAG_LAST ->
    %% Just one packet !
    {Pdu, R};
frag_handler(S, Pdu, R) when R#rpc_response.frag_type == ?FRAG_FIRST ->
    %% First fragmented packet !
    AllocHint = R#rpc_response.alloc_hint,
    DataLen = R#rpc_response.frag_len - ?DCE_RPC_HSIZE,
    Dbin = trim_binary(R#rpc_response.data, DataLen),
    %%?elog("############### FIRST FRAG: Ahint=~p , Dlen=~p , DataLen=~p , size(Dbin)=~p~n", 
    %%[AllocHint, DataLen, DataLen, size(Dbin)]), 
    frag_handler(S, Pdu, R, AllocHint, DataLen, [Dbin]).

frag_handler(S, Pdu, R, Ahint, Dlen, Acc) 
  when R#rpc_response.frag_type =/= ?FRAG_LAST ->
    ReadSize = frag_read_size(R#rpc_response.frag_len, Ahint, Dlen),
    Finfo = #file_info{max_count = ReadSize, min_count = ReadSize},
    {Pdu1, Packet} = read_frag(S, Pdu, Finfo),
    R1 = d_rpc_response_0(Packet),
    DataLen = R1#rpc_response.frag_len - ?DCE_RPC_HSIZE,
    Dbin = trim_binary(R1#rpc_response.data, DataLen),
    %%?elog("############### MIDDLE FRAG: Ahint=~p , Dlen=~p , DataLen=~p , size(Dbin)=~p~n", 
    %%[Ahint, DataLen+Dlen, DataLen, size(Dbin)]),
    frag_handler(S, Pdu1, R1, Ahint, Dlen + DataLen, [Dbin|Acc]);
frag_handler(S, Pdu, R, Ahint, Dlen, Acc) 
  when R#rpc_response.frag_type == ?FRAG_LAST ->
    Data = concat_binary(lists:reverse(Acc)),
    %%?elog("############### LAST FRAG: Ahint=~p , size(Data)=~p~n", [Ahint, size(Data)]),
    {Pdu, R#rpc_response{frag_type    = ?FRAG_LAST,
			 frag_len     = Ahint + ?DCE_RPC_HSIZE,
			 alloc_hint   = Ahint,
			 data         = Data}}.

read_frag(S, Pdu, Finfo) ->
    {Pdu1, Bin} = esmb:smb_read_andx_pdu(Pdu, Finfo),
    case catch esmb:decode_smb_response(Pdu1, esmb_netbios:nbss_session_service(S, Bin)) of
	?IS_OK(Pdu2) -> 
	    Packet = Pdu2#smbpdu.data,
	    {Pdu2, Packet};
	?IS_ERROR(Pdu2) ->
	    throw(Pdu2);
	_ ->
	    throw(Pdu1#smbpdu{eclass = ?INTERNAL, emsg = "read_frag/3"})
    end.

trim_binary(Bin, Size) when size(Bin) > Size -> 
    element(1, split_binary(Bin, Size));
trim_binary(Bin, _) -> 
    Bin.


%%%
%%% How much data should we ask for ?
%%% For now we assume that the FragLen that we have got
%%% is an upper bound on what we can ask for.
%%% It is (apparently) important however to not ask for
%%% more than what could be expected.
%%%
frag_read_size(FragLen, Ahint, Dlen) ->
    Expected = Ahint - Dlen,
    PacketSize = Expected + ?DCE_RPC_HSIZE,
    if (PacketSize > FragLen) -> FragLen;
       true                   -> PacketSize
    end.

d_rpc_response_0(<<?RPC_VERSION, ?RPC_MINOR_VERSION, 
		  ?RPC_OP_RESPONSE, B/binary>>) ->
    d_rpc_response_1(B);
d_rpc_response_0(<<?RPC_VERSION, ?RPC_MINOR_VERSION, 
		  ?RPC_OP_FAULT, B/binary>>) ->
    d_rpc_fault(B);
d_rpc_response_0(<<RPC_VERSION, RPC_MINOR_VERSION, OP, _/binary>>) ->
    ?elog("d_rpc_response got unknown Op: ~p~n",[OP]),
    throw({error,"unknown_op"}).

d_rpc_fault(_B) ->
    %% FIXME ,parse message
    ?elog("GOT RPC-FAULT~n",[]),
    throw({error,"rpc fault"}).

d_rpc_response_1(Resp) ->
    AuthLength = 0,            % assume this for now
    <<PacketFlags,
     ?DATA_REPRESENTATION:32,  % don't use little !!
     FragLength:16/little,
     AuthLength:16/little,
     Call_ID:32/little,
     AllocHint:32/little,
     Context_ID:16/little,
     CancelCount,
     _,                        % reserved
     Bin/binary>> = Resp,
    #rpc_response{frag_type    = frag_type(PacketFlags),
		  frag_len     = FragLength,
		  alloc_hint   = AllocHint,
		  call_id      = Call_ID,
		  ctx_id       = Context_ID,
		  cancel_count = CancelCount,
		  data         = Bin}.

frag_type(PF) when ?IS_FRAG_LAST(PF)  -> ?FRAG_LAST;
frag_type(PF) when ?IS_FRAG_FIRST(PF) -> ?FRAG_FIRST;
frag_type(_)                          -> ?FRAG_PART.
    
           

%%%
%%% Decode a DCE/RPC bind response
%%%

d_bind_response(<<?RPC_VERSION, ?RPC_MINOR_VERSION,
		 ?RPC_OP_BIND_ACK, B/binary>>) ->
    d_rpc_bind_ack(B);
d_bind_response(<<?RPC_VERSION, ?RPC_MINOR_VERSION,
		 ?RPC_OP_BIND_NACK, B/binary>>) ->
    d_rpc_bind_nack(B);
d_bind_response(B) ->
    Emsg = "DCE/RPC Bind-Response unknown",
    error_logger:info_msg("~s~n",[Emsg]),
    {error, Emsg}.


%%%
%%% Decode a DCE/RPC bind_ack reply
%%%
d_rpc_bind_ack(B0) ->
    <<PacketFlags,                 % 4:1 (byte:len)
     DataRepresentation:32/little,
     FragLength:16/little,
     AuthLength:16/little,
     Call_ID:32/little,            % 12:4
     MaxXmitFrag:16/little,
     MaxRecvFrag:16/little,
     AssocGroup:32/little,         % 20:4 
     ScndryAddrLen:16/little,      % 24:2 
     B1/binary>>  = B0,
    %% Restore 4-octet alignment
    Pad = 4 - ((26 + ScndryAddrLen) rem 4),
    <<ScndryAddr:ScndryAddrLen/binary, % null term.ASCII string
     _:Pad/?BYTE,
     B2/binary>> = B1,
    %% Presentation context result list
    <<NumRes,
     0,0,0,                        % reserved
     B3/binary>> = B2,
    %% List with NumRes number of entries
    %% AckRes: Acceptance(0), UserReject(1), ProviderReject(2)
    <<AckRes:16/little,  
     %% ProvReason: ReasonNotSpecified(0), AbstractSyntaxNotSupported(1),
     %%   ProposedTransferSyntaxNotSupported(2), LocalLimitExceeded(3)
     ProvReason:16/little,  % only relevant if AckRes =/= Acceptance
     TransferSyntax:16/binary,
     SyntaxVersion:32/little,
     %% FIXME , we only check the first entry for now...
     _/binary>> = B3,
    #rpc_bind_ack{assoc_group = AssocGroup,
		  ack_result  = AckRes,
		  prov_reason = ProvReason}.


%%%
%%% Decode a DCE/RPC bind_nack reply
%%%
d_rpc_bind_nack(B0) ->
    <<PacketFlags,
     DataRepresentation:32/little,
     FragLength:16/little,
     AuthLength:16/little,
     Call_ID:32/little,
     ProvRejectReason:16/little,
     NumOfProtos,
     B1/binary>> = B0, % list(NumOfProtos): <<Major:8,Minor:8,...>>
    #rpc_bind_nack{prov_reason = ProvRejectReason}.



%%%
%%% An UUID is an identifier that is unique across both space and time, 
%%% with respect to the space of all UUIDs. The UUID consists of a record 
%%% of 16 octets and must not contain padding between fields. 
%%% The total size is 128 bits.
%%%
%%% The generation of UUIDs requires a unique value over space for each UUID
%%% generator. This spatially unique value is specified as an IEEE-802 address.
%%%
%%% The timestamp is a 60 bit value. For UUID version 1, this is represented 
%%% by Coordinated Universal Time (UTC) as a count of 100-nanosecond intervals 
%%% since 00:00:00.00, 15 October 1582 (the date of Gregorian reform to the 
%%% Christian calendar).
%%%
%%% DataType  Octet  Note
%%% ulong      0-3    The low field of the timestamp.
%%% ushort     4-5    The middle field of the timestamp.
%%% ushort     6-7    The high field of the timestamp multiplexed with the version number.
%%% usmall       8    The high field of the clock sequence multiplexed with the variant.
%%% usmall       9    The low field of the clock sequence.
%%% char     10-15    The spatially unique node identifier. 
%%%
uuid() ->
    TS = calendar:datetime_to_gregorian_seconds({date(),time()}) * 10000000,
    Low = TS band 16#ffffffff,
    Mid = (TS bsr 32) band 16#ffff,
    HiV = ((TS bsr 48) band 16#fff) bor ?DCE_VERSION,
    CHi = ((?CLK_SEQ bsr 8) band 16#3f) bor ?DCE_VARIANT,
    CLo = ?CLK_SEQ band 16#ff,
    NId = node_id(),
    <<Low:32/little,
     Mid:16/little,
     HiV:16/little,
     CHi,
     CLo,
     NId/binary>>,
    %% hardcoded for now
    <<16#c8, 16#4f, 16#32, 16#4b, 16#70, 16#16, 16#d3, 16#01,
      16#12, 16#78, 16#5a, 16#47, 16#bf, 16#6e, 16#e1, 16#88>>.


%%% Depending on "service type" ?
uuid(?ST_SRVSVC) ->
    <<16#c8, 16#4f, 16#32, 16#4b, 16#70, 16#16, 16#d3, 16#01,
      16#12, 16#78, 16#5a, 16#47, 16#bf, 16#6e, 16#e1, 16#88>>;
uuid(?ST_SAMR) ->
    <<16#78,16#57,16#34,16#12,16#34,16#12,16#cd,16#ab,16#ef,16#00,
     16#01,16#23,16#45,16#67,16#89,16#ac>>.

node_id() ->
    %% FIXME , kiwi's MAC address for now
    <<16#00,
     16#50,
     16#BA,
     16#1E,
     16#47,
     16#10>>.
    
    
%%%
%%% Seem to be a fixed value (?)
%%%
%%%   8a885d04-1ceb-11c9-9fe8-08002b104860
%%%
transfer_syntax() ->
    <<16#04,
     16#5d,
     16#88,
     16#8a,
     16#eb,
     16#1c,
     16#c9,
     16#11,
     16#9f,
     16#e8,
     16#08,
     16#00,
     16#2b,
     16#10,
     16#48,
     16#60>>.




%%%
%%% Expect multi-byte chars ?
%%%
%%%   nchars(UnicodeP) -> 1 | 2
%%%
nchars(true) -> 2;
nchars(_)    -> 1.
    
