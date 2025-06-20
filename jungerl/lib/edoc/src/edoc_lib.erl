%% =====================================================================
%% This library is free software; you can redistribute it and/or modify
%% it under the terms of the GNU Lesser General Public License as
%% published by the Free Software Foundation; either version 2 of the
%% License, or (at your option) any later version.
%%
%% This library is distributed in the hope that it will be useful, but
%% WITHOUT ANY WARRANTY; without even the implied warranty of
%% MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU
%% Lesser General Public License for more details.
%%
%% You should have received a copy of the GNU Lesser General Public
%% License along with this library; if not, write to the Free Software
%% Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA 02111-1307
%% USA
%%
%% $Id: edoc_lib.erl,v 1.1 2004/12/03 00:01:11 richcarl Exp $
%%
%% @private
%% @copyright 2001-2003 Richard Carlsson
%% @author Richard Carlsson <richardc@csd.uu.se>
%% @see edoc
%% @end
%% =====================================================================

%% @doc Utility functions for EDoc.

-module(edoc_lib).

-export([count/2, lines/1, split_at/2, split_at_stop/1, filename/1,
	 transpose/1, segment/2, get_first_sentence/1, is_space/1,
	 strip_space/1, escape_uri/1, join_uri/2, is_relative_uri/1,
	 is_name/1, find_doc_dirs/0, find_sources/2, find_sources/3,
	 find_file/3, try_subdir/2, unique/1, write_file/3,
	 write_file/4, write_info_file/4, read_info_file/1,
	 get_doc_env/1, get_doc_env/4, copy_file/2, copy_dir/2,
	 uri_get/1, run_doclet/2, run_layout/2, simplify_path/1]).

-import(edoc_report, [report/2, warning/2]).

-include("edoc.hrl").
-include("xmerl.hrl").

-define(FILE_BASE, "/").


%% ---------------------------------------------------------------------
%% List and string utilities

count(X, Xs) ->
    count(X, Xs, 0).

count(X, [X | Xs], N) ->
    count(X, Xs, N + 1);
count(X, [_ | Xs], N) ->
    count(X, Xs, N);
count(_X, [], N) ->
    N.

lines(Cs) ->
    lines(Cs, [], []).

lines([$\n | Cs], As, Ls) ->
    lines(Cs, [], [lists:reverse(As) | Ls]);
lines([C | Cs], As, Ls) ->
    lines(Cs, [C | As], Ls);
lines([], As, Ls) ->
    lists:reverse([lists:reverse(As) | Ls]).

split_at(Cs, K) ->
    split_at(Cs, K, []).

split_at([K | Cs], K, As) ->
    {lists:reverse(As), Cs};
split_at([C | Cs], K, As) ->
    split_at(Cs, K, [C | As]);
split_at([], _K, As) ->
    {lists:reverse(As), []}.

split_at_stop(Cs) ->
    split_at_stop(Cs, []).

split_at_stop([$., $\s | Cs], As) ->
    {lists:reverse(As), Cs};
split_at_stop([$., $\t | Cs], As) ->
    {lists:reverse(As), Cs};
split_at_stop([$., $\n | Cs], As) ->
    {lists:reverse(As), Cs};
split_at_stop([$.], As) ->
    {lists:reverse(As), []};
split_at_stop([C | Cs], As) ->
    split_at_stop(Cs, [C | As]);
split_at_stop([], As) ->
    {lists:reverse(As), []}.

is_space([$\s | Cs]) -> is_space(Cs);
is_space([$\t | Cs]) -> is_space(Cs);
is_space([$\n | Cs]) -> is_space(Cs);
is_space([_C | _Cs]) -> false;
is_space([]) -> true.

strip_space([$\s | Cs]) -> strip_space(Cs);
strip_space([$\t | Cs]) -> strip_space(Cs);
strip_space([$\n | Cs]) -> strip_space(Cs);
strip_space(Cs) -> Cs.

segment(Es, N) ->
    segment(Es, [], [], 0, N).

segment([E | Es], As, Cs, N, M) when N < M ->
    segment(Es, [E | As], Cs, N + 1, M);
segment([_ | _] = Es, As, Cs, _N, M) ->
    segment(Es, [], [lists:reverse(As) | Cs], 0, M);
segment([], [], Cs, _N, _M) ->
    lists:reverse(Cs);
segment([], As, Cs, _N, _M) ->
    lists:reverse([lists:reverse(As) | Cs]).

transpose([]) -> [];
transpose([[] | Xss]) -> transpose(Xss);
transpose([[X | Xs] | Xss]) ->
    [[X | [H || [H | _T] <- Xss]]
     | transpose([Xs | [T || [_H | T] <- Xss]])].

%% Note that the parser will not produce two adjacent text segments;
%% thus, if a text segment ends with a period character, it marks the
%% end of the summary sentence only if it is also the last segment in
%% the list.

get_first_sentence([E = #xmlText{value = Txt}]) ->
    {_, Txt1} = end_of_sentence(Txt),
    [E#xmlText{value = Txt1}];
get_first_sentence([E = #xmlText{value = Txt} | Es]) ->
    case end_of_sentence(Txt) of
	{true, Txt1} ->
	    [E#xmlText{value = Txt1}];
	{false, _} ->
	    [E | get_first_sentence(Es)]
    end;
get_first_sentence([E | Es]) ->
    % Skip non-text segments - don't descend
    [E | get_first_sentence(Es)];
get_first_sentence([]) ->
    [].

end_of_sentence(Cs) ->
    end_of_sentence(Cs, []).

%% We detect '.' and '!' as end-of-sentence markers.

end_of_sentence([C=$., $\s | _], As) ->
    end_of_sentence(true, C, As);
end_of_sentence([C=$., $\t | _], As) ->
    end_of_sentence(true, C, As);
end_of_sentence([C=$., $\n | _], As) ->
    end_of_sentence(true, C, As);
end_of_sentence([C=$.], As) ->
    end_of_sentence(false, C, As);
end_of_sentence([C=$!, $\s | _], As) ->
    end_of_sentence(true, C, As);
end_of_sentence([C=$!, $\t | _], As) ->
    end_of_sentence(true, C, As);
end_of_sentence([C=$!, $\n | _], As) ->
    end_of_sentence(true, C, As);
end_of_sentence([C=$!], As) ->
    end_of_sentence(false, C, As);
end_of_sentence([C | Cs], As) ->
    end_of_sentence(Cs, [C | As]);
end_of_sentence([], As) ->
    end_of_sentence(false, $., strip_space(As)).  % add a '.'

end_of_sentence(Flag, C, As) ->
    {Flag, lists:reverse([C | As])}.

%% For handling ISO 8859-1 (Latin-1) we use the following information:
%%
%% 000 - 037	NUL - US	control
%% 040 - 057	SPC - /		punctuation
%% 060 - 071	0 - 9		digit
%% 072 - 100	: - @		punctuation
%% 101 - 132	A - Z		uppercase
%% 133 - 140	[ - `		punctuation
%% 141 - 172	a - z		lowercase
%% 173 - 176	{ - ~		punctuation
%% 177		DEL		control
%% 200 - 237			control
%% 240 - 277	NBSP - �	punctuation
%% 300 - 326	� - �		uppercase
%% 327		�		punctuation
%% 330 - 336	� - �		uppercase
%% 337 - 366	� - �		lowercase
%% 367		�		punctuation
%% 370 - 377	� - �		lowercase

%% Names must begin with a lowercase letter and contain only
%% alphanumerics and underscores.

is_name([C | Cs]) when C >= $a, C =< $z ->
    is_name_1(Cs);
is_name([C | Cs]) when C >= $\337, C =< $\377, C =/= $\367 ->
    is_name_1(Cs);
is_name(_) -> false.

is_name_1([C | Cs]) when C >= $a, C =< $z ->
    is_name_1(Cs);
is_name_1([C | Cs]) when C >= $A, C =< $Z ->
    is_name_1(Cs);
is_name_1([C | Cs]) when C >= $0, C =< $9 ->
    is_name_1(Cs);
is_name_1([C | Cs]) when C >= $\300, C =< $\377, C =/= $\327, C =/= $\367 ->
    is_name_1(Cs);
is_name_1([$_ | Cs]) ->
    is_name_1(Cs);
is_name_1([]) -> true;
is_name_1(_) -> false.

to_atom(A) when atom(A) -> A;
to_atom(S) when list(S) -> list_to_atom(S).
    
unique([X | Xs]) -> [X | unique(Xs, X)];
unique([]) -> [].

unique([X | Xs], X) -> unique(Xs, X);
unique([X | Xs], _) -> [X | unique(Xs, X)];
unique([], _) -> [].

% key_unique([X | Xs]) -> [X | key_unique(Xs, element(1,X))];
% key_unique([]) -> [].

% key_unique([X | Xs], K) when element(1,X) =:= K -> key_unique(Xs, K);
% key_unique([X | Xs], _) -> [X | key_unique(Xs, element(1,X))];
% key_unique([], _) -> [].


%% ---------------------------------------------------------------------
%% URI and Internet

%% This is a conservative URI escaping, which escapes anything that may
%% not appear in an NMTOKEN ([a-zA-Z0-9]|'.'|'-'|'_'), including ':'.
%% Characters are first encoded in UTF-8.
%%
%% Note that this should *not* be applied to complete URI, but only to
%% segments that may need escaping, when forming a complete URI.

escape_uri([C | Cs]) when C >= $a, C =< $z ->
    [C | escape_uri(Cs)];
escape_uri([C | Cs]) when C >= $A, C =< $Z ->
    [C | escape_uri(Cs)];
escape_uri([C | Cs]) when C >= $0, C =< $9 ->
    [C | escape_uri(Cs)];
escape_uri([C = $. | Cs]) ->
    [C | escape_uri(Cs)];
escape_uri([C = $- | Cs]) ->
    [C | escape_uri(Cs)];
escape_uri([C = $_ | Cs]) ->
    [C | escape_uri(Cs)];
escape_uri([C | Cs]) when C > 16#7f ->
    %% This assumes that characters are at most 16 bits wide.
    %% TODO: general utf-8 encoding for all of Unicode (0-16#10ffff)
    escape_byte(((C band 16#c0) bsr 6) + 16#c0)
	++ escape_byte(C band 16#3f + 16#80)
	++ escape_uri(Cs);
escape_uri([C | Cs]) ->
    escape_byte(C) ++ escape_uri(Cs);
escape_uri([]) ->
    [].

escape_byte(C) ->
    "%" ++ hex_octet(C).

% utf8([C | Cs]) when C > 16#7f ->
%     [((C band 16#c0) bsr 6) + 16#c0, C band 16#3f ++ 16#80 | utf8(Cs)];
% utf8([C | Cs]) ->
%     [C | utf8(Cs)];
% utf8([]) ->
%     [].

hex_octet(N) when N =< 9 ->
    [$0 + N];
hex_octet(N) when N > 15 ->
    hex_octet(N bsr 4) ++ hex_octet(N band 15);
hex_octet(N) ->
    [N - 10 + $a].

%% Please note that URI are *not* file names. Don't use the stdlib
%% 'filename' module for operations on (any parts of) URI.

join_uri(Base, "") ->
    Base;
join_uri("", Path) ->
    Path;
join_uri(Base, Path) ->
    Base ++ "/" ++ Path.

%% Check for relative URI; "network paths" ("//...") not included!

is_relative_uri([$: | _]) ->
    false;
is_relative_uri([$/, $/ | _]) ->
    false;
is_relative_uri([$/ | _]) ->
    true;
is_relative_uri([$? | _]) ->
    true;
is_relative_uri([$# | _]) ->
    true;
is_relative_uri([_ | Cs]) ->
    is_relative_uri(Cs);
is_relative_uri([]) ->
    true.

uri_get("file:///" ++ Path) ->
    uri_get_file(Path);
uri_get("file://localhost/" ++ Path) ->
    uri_get_file(Path);
uri_get("file://" ++ Path) ->
    Msg = io_lib:format("cannot handle 'file:' scheme with "
			"nonlocal network-path: 'file://~s'.",
			[Path]),
    {error, Msg};
uri_get("file:/" ++ Path) ->
    uri_get_file(Path);
uri_get("file:" ++ Path) ->
    Msg = io_lib:format("ignoring malformed URI: 'file:~s'.", [Path]),
    {error, Msg};
uri_get("http:" ++ Path) ->
    uri_get_http("http:" ++ Path);
uri_get("ftp:" ++ Path) ->
    uri_get_ftp("ftp:" ++ Path);
uri_get("//" ++ Path) ->
    Msg = io_lib:format("cannot access network-path: '//~s'.", [Path]),
    {error, Msg};
uri_get(URI) ->
    case is_relative_uri(URI) of
	true ->
	    uri_get_file(URI);
	false ->
	    Msg = io_lib:format("cannot handle URI: '~s'.", [URI]),
	    {error, Msg}
    end.

uri_get_file(File0) ->
    File = filename:join(?FILE_BASE, File0),
    case read_file(File) of
	{ok, Text} ->
	    {ok, Text};
	{error, R} ->
	    {error, file:format_error(R)}
    end.

%% First try unofficial undocumented, old http access function, for
%% backwards compatibility with pre-R10 versions of OTP.

%% FIXME: check somehow if we have an internet connection, making inets quieter

uri_get_http(URI) ->
    case catch {ok, http:request_sync(get, {URI,[]})} of
	{'EXIT', {undef,_}} ->
	    uri_get_http_r10(URI);
	Result ->
	    uri_get_http_1(Result, URI)
    end.

uri_get_http_1(Result, URI) ->
    case Result of
	{ok, {200,_Hdrs,Text}} ->
	    {ok, Text};
	{ok, {Status,_Hdrs,_Text}} ->
	    Reason = httpd_util:reason_phrase(Status),
	    {error, http_errmsg(Reason, URI)};
	{ok, {error, R}} ->
	    Reason = io_lib:format("~w", [R]),
	    {error, http_errmsg(Reason, URI)};
	{ok, R} ->
	    Reason = io_lib:format("bad return value ~P", [R, 5]),
	    {error, http_errmsg(Reason, URI)};
	{'EXIT', R} ->
	    Reason = io_lib:format("crashed with reason ~w", [R]),
	    {error, http_errmsg(Reason, URI)};
	R ->
	    Reason = io_lib:format("uncaught throw: ~w", [R]),
	    {error, http_errmsg(Reason, URI)}
    end.

uri_get_http_r10(URI) ->
    Result = (catch {ok, http:request(get, {URI,[]}, [], [])}),
    uri_get_http_1(Result, URI).

http_errmsg(Reason, URI) ->
    io_lib:format("http error: ~s: '~s'.", [Reason, URI]).

uri_get_ftp(URI) ->
    Msg = io_lib:format("cannot access ftp scheme yet: '~s'.", [URI]),
    {error, Msg}.


%% ---------------------------------------------------------------------
%% Files

filename([C | T]) when integer(C), C > 0 ->
    [C | filename(T)];
filename([H|T]) ->
    filename(H) ++ filename(T);
filename([]) ->
    [];
filename(N) when atom(N) ->
    atom_to_list(N);
filename(N) ->
    report("bad filename: `~P'.", [N, 25]),
    exit(error).

copy_file(From, To) ->
    case file:copy(From, To) of
	{ok, _} -> ok;
	{error, R} ->
	    R1 = file:format_error(R),
	    report("error copying '~s' to '~s': ~s.", [From, To, R1]),
	    exit(error)
    end.

list_dir(Dir, Error) ->
    case file:list_dir(Dir) of
	{ok, Fs} ->
	    Fs;
	{error, R} ->
	    F = case Error of
		    true ->
			fun (S, As) -> report(S, As), exit(error) end;
		    false ->
			fun (S, As) -> warning(S, As), [] end
		end,
	    R1 = file:format_error(R),
	    F("could not read directory '~s': ~s.", [filename(Dir), R1])
    end.

simplify_path(P) ->
    case filename:basename(P) of
	"." ->
	    simplify_path(filename:dirname(P));
	".." ->
	    simplify_path(filename:dirname(filename:dirname(P)));
	_ ->
	    P
    end.

%% The directories From and To are assumed to exist.

copy_dir(From, To) ->
    Es = list_dir(From, true),    % error if listing fails
    lists:foreach(fun (E) -> copy_dir(From, To, E) end, Es).

copy_dir(From, To, Entry) ->
    From1 = filename:join(From, Entry),
    To1 = filename:join(To, Entry),
    case filelib:is_dir(From1) of
	true ->
	    make_dir(To1),
	    copy_dir(From1, To1);
	false ->
	    copy_file(From1, To1)
    end.

make_dir(Dir) ->
    case file:make_dir(Dir) of
	{ok, _} -> ok;
	{error, R} ->
	    R1 = file:format_error(R),
	    report("cannot create directory '~s': ~s.", [Dir, R1]),
	    exit(error)
    end.

try_subdir(Dir, Subdir) ->
    D = filename:join(Dir, Subdir),
    case filelib:is_dir(D) of
	true -> D; 
	false -> Dir
    end.

%% @spec (Text::deep_string(), Dir::edoc:filename(),
%%        Name::edoc:filename()) -> ok
%%
%% @doc Write the given `Text' to the file named by `Name' in directory
%% `Dir'. If the target directory does not exist, it will be created.

write_file(Text, Dir, Name) ->
    write_file(Text, Dir, Name, '').


%% @spec (Text::deep_string(), Dir::edoc:filename(),
%%        Name::edoc:filename(), Package::atom()|string()) -> ok
%% @doc Like {@link write_file/3}, but adds path components to the target
%% directory corresponding to the specified package.

write_file(Text, Dir, Name, Package) ->
    Dir1 = filename:join([Dir | packages:split(Package)]),
    File = filename:join(Dir1, Name),
    filelib:ensure_dir(File),
    case file:open(File, [write]) of
	{ok, FD} ->
	    io:put_chars(FD, Text),
	    file:close(FD),
	    ok;
	{error, R} ->
	    R1 = file:format_error(R),
	    report("could not write file '~s': ~s.", [File, R1]),
	    exit(error)
    end.

write_info_file(App, Packages, Modules, Dir) ->
    Ts = [{packages, Packages},
	  {modules, Modules}],
    Ts1 = if App == ?NO_APP -> Ts;
	     true -> [{application, App} | Ts]
	  end,
    S = [io_lib:fwrite("~p.\n", [T]) || T <- Ts1],
    write_file(S, Dir, ?INFO_FILE).

%% @spec (Name::edoc:filename()) -> {ok, string()} | {error, Reason}
%%
%% @doc Reads text from the file named by `Name'.

read_file(File) ->
    case file:read_file(File) of
	{ok, Bin} -> {ok, binary_to_list(Bin)};
	{error, Reason} -> {error, Reason}
    end.


%% ---------------------------------------------------------------------
%% Info files

info_file_data(Ts) ->
    App = proplists:get_value(application, Ts, ?NO_APP),
    Ps = proplists:append_values(packages, Ts),
    Ms = proplists:append_values(modules, Ts),
    {App, Ps, Ms}.

%% Local file access - don't complain if file does not exist.

read_info_file(Dir) ->
    File = filename:join(Dir, ?INFO_FILE),
    case filelib:is_file(File) of
	true ->
	    case read_file(File) of
		{ok, Text} ->
		    parse_info_file(Text, File);
		{error, R} ->
		    R1 = file:format_error(R),
		    warning("could not read '~s': ~s.", [File, R1]),
		    {?NO_APP, [], []}
	    end;	    
	false ->
	    {?NO_APP, [], []}
    end.

%% URI access

uri_get_info_file(Base) ->
    URI = join_uri(Base, ?INFO_FILE),
    case uri_get(URI) of
	{ok, Text} ->
	    parse_info_file(Text, URI);
	{error, Msg} ->
	    warning("could not read '~s': ~s.", [URI, Msg]),
	    {?NO_APP, [], []}
    end.

parse_info_file(Text, Name) ->
    case parse_terms(Text) of
	{ok, Vs} ->
	    info_file_data(Vs);
	{error, eof} ->
	    warning("unexpected end of file in '~s'.", [Name]),
	    {?NO_APP, [], []};
	{error, {_Line,Module,R}} ->
	    warning("~s: ~s.", [Module:format_error(R), Name]),
	    {?NO_APP, [], []}
    end.

parse_terms(Text) ->
    case erl_scan:string(Text) of
	{ok, Ts, _Line} ->
	    parse_terms_1(Ts, [], []);
	{error, R, _Line} ->
	    {error, R}
    end.

parse_terms_1([T={dot, _L} | Ts], As, Vs) ->
    case erl_parse:parse_term(lists:reverse([T | As])) of
	{ok, V} ->
	    parse_terms_1(Ts, [], [V | Vs]);
	{error, R} ->
	    {error, R}
    end;
parse_terms_1([T | Ts], As, Vs) ->
    parse_terms_1(Ts, [T | As], Vs);
parse_terms_1([], [], Vs) ->
    {ok, lists:reverse(Vs)};
parse_terms_1([], _As, _Vs) ->
    {error, eof}.


%% ---------------------------------------------------------------------
%% Source files and packages

find_sources(Path, Opts) ->
    find_sources(Path, "", Opts).

%% @doc See {@link edoc:run/3} for a description of the options
%% `subpackages', `source_suffix' and `exclude_packages'.

%% NEW-OPTIONS: subpackages, source_suffix, exclude_packages
%% DEFER-OPTIONS: edoc:run/3

find_sources(Path, Pkg, Opts) ->
    Rec = proplists:get_bool(subpackages, Opts),
    Ext = proplists:get_value(source_suffix, Opts, ?DEFAULT_SOURCE_SUFFIX),
    find_sources(Path, Pkg, Rec, Ext, Opts).

find_sources(Path, Pkg, Rec, Ext, Opts) ->
    Skip = proplists:get_value(exclude_packages, Opts, []),
    lists:flatten(find_sources_1(Path, to_atom(Pkg), Rec, Ext, Skip)).

find_sources_1([P | Ps], Pkg, Rec, Ext, Skip) ->
    Dir = filename:join(P, filename:join(packages:split(Pkg))),
    Fs1 = find_sources_1(Ps, Pkg, Rec, Ext, Skip),
    case filelib:is_dir(Dir) of
	true ->
	    [find_sources_2(Dir, Pkg, Rec, Ext, Skip) | Fs1];
	false ->
	    Fs1
    end;
find_sources_1([], _Pkg, _Rec, _Ext, _Skip) ->
    [].

find_sources_2(Dir, Pkg, Rec, Ext, Skip) ->
    case lists:member(Pkg, Skip) of
	false ->
	    Es = list_dir(Dir, false),    % just warn if listing fails
	    Es1 = [{Pkg, E, Dir} || E <- Es, is_source_file(E, Ext)],
	    case Rec of
		true ->
		    [find_sources_3(Es, Dir, Pkg, Rec, Ext, Skip) | Es1];
		false ->
		    Es1
	    end;
	true ->
	    []
    end.

find_sources_3(Es, Dir, Pkg, Rec, Ext, Skip) ->
    [find_sources_2(filename:join(Dir, E),
		    to_atom(packages:concat(Pkg, E)), Rec, Ext, Skip)
     || E <- Es, is_package_dir(E, Dir)].

is_source_file(Name, Ext) ->
    (filename:extension(Name) == Ext)
	andalso is_name(filename:rootname(Name, Ext)).

is_package_dir(Name, Dir) ->
    is_name(filename:rootname(filename:basename(Name)))
	andalso filelib:is_dir(filename:join(Dir, Name)).

find_file([P | Ps], Pkg, Name) ->
    Dir = filename:join(P, filename:join(packages:split(Pkg))),
    File = filename:join(Dir, Name),
    case filelib:is_file(File) of
	true ->
	    File;    
	false ->
	    find_file(Ps, Pkg, Name)
    end;    
find_file([], _Pkg, _Name) ->
    "".

find_doc_dirs() ->
    find_doc_dirs(code:get_path()).

find_doc_dirs([P0 | Ps]) ->
    P = filename:absname(P0),
    P1 = case filename:basename(P) of
	     ?EBIN_DIR ->
		 filename:dirname(P);
	     _ ->
		 P
	 end,
    Dir = try_subdir(P1, ?EDOC_DIR),
    File = filename:join(Dir, ?INFO_FILE),
    case filelib:is_file(File) of
	true ->
	    [Dir | find_doc_dirs(Ps)]; 
	false ->
	    find_doc_dirs(Ps)
    end;
find_doc_dirs([]) ->
    [].

%% All names with "internal linkage" are mapped to the empty string, so
%% that relative references will be created. For apps, the empty string
%% implies that we use the default app-path.

%% NEW-OPTIONS: doc_path
%% DEFER-OPTIONS: get_doc_env/4

get_doc_links(App, Packages, Modules, Opts) ->
    Path = proplists:append_values(doc_path, Opts) ++ find_doc_dirs(),
    Ds = [{P, uri_get_info_file(P)} || P <- Path],
    Ds1 = [{"", {App, Packages, Modules}} | Ds],
    D = dict:new(),
    make_links(Ds1, D, D, D).

make_links([{Dir, {App, Ps, Ms}} | Ds], A, P, M) ->
    A1 = if App == ?NO_APP -> A;
	    true -> add_new(App, Dir, A)
	 end,
    F = fun (K, D) -> add_new(K, Dir, D) end,
    P1 = lists:foldl(F, P, Ps),
    M1 = lists:foldl(F, M, Ms),
    make_links(Ds, A1, P1, M1);
make_links([], A, P, M) ->
    F = fun (D) ->
		fun (K) ->
			case dict:find(K, D) of
			    {ok, V} -> V;
			    error -> ""
			end
		end
	end,
    {F(A), F(P), F(M)}.

add_new(K, V, D) ->
    case dict:is_key(K, D) of
	true ->
	    D;
	false ->
	    dict:store(K, V, D)
    end.

%% @spec (Options::edoc:option_list()) -> edoc_env()
%% @equiv get_doc_env([], [], [], Opts)

get_doc_env(Opts) ->
    get_doc_env([], [], [], Opts).

%% @spec (App, Packages, Modules, Options::edoc:option_list()) -> edoc_env()
%%     App = [] | atom()
%%     Packages = [atom()]
%%     Modules = [atom()]
%%
%% @type edoc_env(). Environment information needed by EDoc for
%% generating references. The data representation is not documented.
%%
%% @doc Creates an environment data structure used by parts of EDoc for
%% generating references, etc. See {@link edoc:run/3} for a description
%% of the options `file_suffix', `app_default' and `doc_path'.
%%
%% @see edoc_extract:source/4
%% @see edoc:get_doc/3

%% NEW-OPTIONS: file_suffix, app_default
%% INHERIT-OPTIONS: get_doc_links/4
%% DEFER-OPTIONS: edoc:run/3

get_doc_env(App, Packages, Modules, Opts) ->
    Suffix = proplists:get_value(file_suffix, Opts,
				 ?DEFAULT_FILE_SUFFIX),
    AppDefault = proplists:get_value(app_default, Opts, ?APP_DEFAULT),
    {A, P, M} = get_doc_links(App, Packages, Modules, Opts),
    #env{file_suffix = Suffix,
	 package_summary = ?PACKAGE_SUMMARY ++ Suffix,
	 apps = A,
	 packages = P,
	 modules = M,
	 app_default = AppDefault
	}.

%% ---------------------------------------------------------------------
%% Plug-in modules

%% @doc See {@link edoc:run/3} for a description of the `doclet' option.

%% NEW-OPTIONS: doclet
%% DEFER-OPTIONS: edoc:run/3

run_doclet(Fun, Opts) ->
    run_plugin(doclet, ?DEFAULT_DOCLET, Fun, Opts).

%% @doc See {@link edoc:layout/2} for a description of the `layout'
%% option.

%% NEW-OPTIONS: layout
%% DEFER-OPTIONS: edoc:layout/2

run_layout(Fun, Opts) ->
    run_plugin(layout, ?DEFAULT_LAYOUT, Fun, Opts).

run_plugin(Name, Default, Fun, Opts) ->
    run_plugin(Name, Name, Default, Fun, Opts).

run_plugin(Name, Key, Default, Fun, Opts) when atom(Name) ->
    Module = get_plugin(Key, Default, Opts),
    case catch {ok, Fun(Module)} of
	{ok, Value} ->
	    Value;
	R ->
	    report("error in ~s '~w': ~W.", [Name, Module, R, 20]),
	    exit(error)
    end.

get_plugin(Key, Default, Opts) ->
    case proplists:get_value(Key, Opts, Default) of
	M when atom(M) ->
	    M;
	Other ->
	    report("bad value for option '~w': ~P.", [Key, Other, 10]),
	    exit(error)
    end.
