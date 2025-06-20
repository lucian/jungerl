%% =====================================================================
%% Tidies Erlang source code, removing unused functions, updating
%% obsolete constructs and function calls, etc.
%%
%% Copyright (C) 1999-2002 Richard Carlsson
%%
%% This library is free software; you can redistribute it and/or
%% modify it under the terms of the GNU Lesser General Public License
%% as published by the Free Software Foundation; either version 2 of
%% the License, or (at your option) any later version.
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
%% Author contact: richardc@csd.uu.se
%%
%% $Id: erl_tidy.erl,v 1.2 2004/12/02 22:47:54 richcarl Exp $
%%
%% =====================================================================
%%
%% @doc Tidies and pretty-prints Erlang source code, removing unused
%% functions, updating obsolete constructs and function calls, etc.
%%
%% <p>Caveats: It is possible that in some intricate uses of macros,
%% the automatic addition or removal of parentheses around uses or
%% arguments could cause the resulting program to be rejected by the
%% compiler; however, we have found no such case in existing
%% code. Programs defining strange macros can usually not be read by
%% this program, and in those cases, no changes will be made.</p>
%%
%% <p>If you really, really want to, you may call it "Inga".</p>
%%
%% <p>Disclaimer: The author accepts no responsibility for errors
%% introduced in code that has been processed by the program. It has
%% been reasonably well tested, but the possibility of errors remains.
%% Keep backups of your original code safely stored, until you feel
%% confident that the new, modified code can be trusted.</p>

-module(erl_tidy).

-export([dir/0, dir/1, dir/2, file/1, file/2, module/1, module/2]).

-include_lib("kernel/include/file.hrl").

-define(DEFAULT_BACKUP_SUFFIX, ".bak").
-define(DEFAULT_DIR, "").
-define(DEFAULT_REGEXP, ".*\\.erl$").


dir__defaults() ->
    [{follow_links, false},
     recursive,
     {regexp, ?DEFAULT_REGEXP},
     verbose].

%% =====================================================================
%% @spec dir() -> ok
%% @equiv dir("")

dir() ->
    dir("").

%% =====================================================================
%% @spec dir(Dir) -> ok
%% @equiv dir(Dir, [])

dir(Dir) ->
    dir(Dir, []).

%% =====================================================================
%% @spec dir(Directory::filename(), Options::[term()]) -> ok
%%           filename() = file:filename()
%%
%% @doc Tidies Erlang source files in a directory and its
%% subdirectories.
%%
%% <p>Available options:
%% <dl>
%%   <dt>{follow_links, bool()}</dt>
%%
%%       <dd>If the value is <code>true</code>, symbolic directory
%%       links will be followed.  The default value is
%%       <code>false</code>.</dd>
%%
%%   <dt>{recursive, bool()}</dt>
%%
%%       <dd>If the value is <code>true</code>, subdirectories will be
%%       visited recursively.  The default value is
%%       <code>true</code>.</dd>
%%
%%   <dt>{regexp, string()}</dt>
%%
%%       <dd>The value denotes a regular expression (see module
%%       <code>regexp</code>).  Tidying will only be applied to those
%%       regular files whose names match this pattern. The default
%%       value is <code>".*\\.erl$"</code>, which matches normal
%%       Erlang source file names.</dd>
%%
%%   <dt>{test, bool()}</dt>
%%
%%       <dd>If the value is <code>true</code>, no files will be
%%       modified. The default value is <code>false</code>.</dd>
%%
%%   <dt>{verbose, bool()}</dt>
%%
%%       <dd>If the value is <code>true</code>, progress messages will
%%       be output while the program is running, unless the
%%       <code>quiet</code> option is <code>true</code>. The default
%%       value when calling <code>dir/2</code> is
%%       <code>true</code>.</dd>
%%
%% </dl></p>
%%
%% <p>See the function <code>file/2</code> for further options.</p>
%%
%% @see regexp
%% @see file/2

-record(dir, {follow_links = false, recursive = true, options}).

dir(Dir, Opts) ->
    Opts1 = Opts ++ dir__defaults(),
    Env = #dir{follow_links = proplists:get_bool(follow_links, Opts1),
               recursive = proplists:get_bool(recursive, Opts1),
               options = Opts1},
    Regexp = proplists:get_value(regexp, Opts1),
    case filename(Dir) of
        "" ->
            Dir1 = ".";
        Dir1 ->
            ok
    end,
    dir_1(Dir1, Regexp, Env).

dir_1(Dir, Regexp, Env) ->
    case file:list_dir(Dir) of
        {ok, Files} ->
            lists:foreach(fun (X) -> dir_2(X, Regexp, Dir, Env) end,
                          Files);
        {error, _} ->
            report_error("error reading directory `~s'",
                         [filename(Dir)]),
            exit(error)
    end.

dir_2(Name, Regexp, Dir, Env) ->
    File = if Dir == "" ->
                   Name;
              true ->
                   filename:join(Dir, Name)
           end,
    case file_type(File) of
        {value, regular} ->
            dir_4(File, Regexp, Env);
        {value, directory} when Env#dir.recursive == true ->
            case is_symlink(Name) of
                false ->
                    dir_3(Name, Dir, Regexp, Env);
                true when Env#dir.follow_links == true ->
                    dir_3(Name, Dir, Regexp, Env);
                _ ->
                    ok
            end;
        _ ->
            ok
    end.

dir_3(Name, Dir, Regexp, Env) ->
    Dir1 = filename:join(Dir, Name),
    verbose("tidying directory `~s'.", [Dir1], Env#dir.options),
    dir_1(Dir1, Regexp, Env).

dir_4(File, Regexp, Env) ->
    case regexp:first_match(File, Regexp) of
        {match, _, _} ->
            Opts = [{outfile, File}, {dir, ""} | Env#dir.options],
            case catch file(File, Opts) of
                {'EXIT', _} ->
                    warn("error tidying `~s'.", [File], Opts);
                _ ->
                    ok
            end;
        _ ->
            ok
    end.


file__defaults() ->
    [{backup_suffix, ?DEFAULT_BACKUP_SUFFIX},
     backups, 
     {dir, ?DEFAULT_DIR},
     {printer, default_printer()},
     {quiet, false},
     {verbose, false}].

default_printer() ->
    fun (Tree, Options) -> erl_prettypr:format(Tree, Options) end.

%% =====================================================================
%% @spec file(Name) -> ok
%% @equiv file(Name, [])

file(Name) ->
    file(Name, []).

%% =====================================================================
%% @spec file(Name::filename(), Options::[term()]) -> ok
%%
%% @doc Tidies an Erlang source code file.
%%
%% <p>Available options are:
%% <dl>
%%   <dt>{backup_suffix, string()}</dt>
%%
%%       <dd>Specifies the file name suffix to be used when a backup
%%       file is created; the default value is <code>".bak"</code>
%%       (cf. the <code>backups</code> option).</dd>
%%
%%   <dt>{backups, bool()}</dt>
%%
%%       <dd>If the value is <code>true</code>, existing files will be
%%       renamed before new files are opened for writing. The new
%%       names are formed by appending the string given by the
%%       <code>backup_suffix</code> option to the original name. The
%%       default value is <code>true</code>.</dd>
%%
%%   <dt>{dir, filename()}</dt>
%%
%%       <dd>Specifies the name of the directory in which the output
%%       file is to be written. By default, the current directory is
%%       used. If the value is an empty string, the current directory
%%       is used. </dd>
%%
%%   <dt>{outfile, filename()}</dt>
%%
%%       <dd>Specifies the name of the file (without suffix) to which
%%       the resulting source code is to be written. If this option is
%%       not specified, the <code>Name</code> argument is used.</dd>
%%
%%   <dt>{printer, Function}</dt>
%%       <dd><ul>
%%         <li><code>Function = (syntaxTree()) -> string()</code></li>
%%       </ul>
%%
%%       <p>Specifies a function for prettyprinting Erlang syntax trees.
%%       This is used for outputting the resulting module definition.
%%       The function is assumed to return formatted text for the given
%%       syntax tree, and should raise an exception if an error occurs.
%%       The default formatting function calls
%%       <code>erl_prettypr:format/2</code>.</p></dd>
%%
%%   <dt>{test, bool()}</dt>
%%
%%       <dd>If the value is <code>true</code>, no files will be
%%       modified; this is typically most useful if the
%%       <code>verbose</code> flag is enabled, to generate reports
%%       about the program files without affecting them. The default
%%       value is <code>false</code>.</dd>
%% </dl></p>
%%
%% <p>See the function <code>module/2</code> for further options.</p>
%%
%% @see erl_prettypr:format/2
%% @see module/2

file(Name, Opts) ->
    Parent = self(),
    Child = spawn_link(fun () -> file_1(Parent, Name, Opts) end),
    receive
        {Child, ok} ->
            ok;
        {Child, {error, Reason}} ->
            exit(Reason)
    end.

file_1(Parent, Name, Opts) ->
    case catch file_2(Name, Opts) of
        {'EXIT', Reason} ->
            Parent ! {self(), {error, Reason}};
        _ ->
            Parent ! {self(), ok}
    end.

file_2(Name, Opts) ->
    Opts1 = Opts ++ file__defaults(),
    Forms = read_module(Name, Opts1),
    Comments = erl_comment_scan:file(Name),
    Forms1 = erl_recomment:recomment_forms(Forms, Comments),
    Tree = module(Forms1, [{file, Name} | Opts1]),
    case proplists:get_bool(test, Opts1) of
        true ->
            ok;
        false ->
            write_module(Tree, Name, Opts1),
            ok
    end.

read_module(Name, Opts) ->
    verbose("reading module `~s'.", [filename(Name)], Opts),
    case epp_dodger:parse_file(Name) of
        {ok, Forms} ->
            check_forms(Forms, Name),
            Forms;
        {error, R} ->
            error_read_file(Name),
            exit({error, R})
    end.

check_forms(Fs, Name) ->
    Fun = fun (F) ->
                  case erl_syntax:type(F) of
                      error_marker ->
                          S = case erl_syntax:error_marker_info(F) of
                                  {_, M, D} ->
                                      M:format_error(D);
                                  _ ->
                                      "unknown error"
                              end,
                          report_error({Name, erl_syntax:get_pos(F),
                                        "\n  ~s"}, [S]),
                          exit(error);
                      _ ->
                          ok
                  end
          end,
    lists:foreach(Fun, Fs).

%% Create the target directory and make a backup file if necessary,
%% then open the file, output the text and close the file
%% safely. Returns the file name.

write_module(Tree, Name, Opts) ->
    Name1 = proplists:get_value(outfile, Opts, filename(Name)),
    Dir = filename(proplists:get_value(dir, Opts, "")),
    File = if Dir == "" ->
                   Name1;
              true ->
                   case file_type(Dir) of
                       {value, directory} ->
                           ok;
                       {value, _} ->
                           report_error("`~s' is not a directory.",
                                        [filename(Dir)]),
                           exit(error);
                       none ->
                           case file:make_dir(Dir) of
                               ok ->
                                   verbose("created directory `~s'.",
                                           [filename(Dir)], Opts),
                                   ok;
                               E ->
                                   report_error("failed to create "
                                                "directory `~s'.",
                                                [filename(Dir)]),
                                   exit({make_dir, E})
                           end
                   end,
                   filename(filename:join(Dir, Name1))
           end,
    case proplists:get_bool(backups, Opts) of
        true ->
            backup_file(File, Opts);
        false ->
            ok
    end,
    Printer = proplists:get_value(printer, Opts),
    FD = open_output_file(File),
    verbose("writing to file `~s'.", [File], Opts),
    V = (catch {ok, output(FD, Printer, Tree, Opts)}),
    file:close(FD),
    case V of
        {ok, _} ->
            File;
        {'EXIT', R} ->
            error_write_file(File),
            exit(R);
        R ->
            error_write_file(File),
            throw(R)
    end.

output(FD, Printer, Tree, Opts) ->
    io:put_chars(FD, Printer(Tree, Opts)),
    io:nl(FD).

%% file_type(filename()) -> {value, Type} | none

file_type(Name) ->
    file_type(Name, false).

is_symlink(Name) ->
    file_type(Name, true) == {value, symlink}.

file_type(Name, Links) ->
    V = case Links of
            true ->
                catch file:read_link_info(Name);
            false ->
                catch file:read_file_info(Name)
        end,
    case V of
        {ok, Env} ->
            {value, Env#file_info.type};
        {error, enoent} ->
            none;
        {error, R} ->
            error_read_file(Name),
            exit({error, R});
        {'EXIT', R} ->
            error_read_file(Name),
            exit(R);
        R ->
            error_read_file(Name),
            throw(R)
    end.

open_output_file(FName) ->
    case catch file:open(FName, [write]) of
        {ok, FD} ->
            FD;
        {error, R} ->
            error_open_output(FName),
            exit({error, R});
        {'EXIT', R} ->
            error_open_output(FName),
            exit(R);
        R ->
            error_open_output(FName),
            exit(R)
    end.

%% If the file exists, rename it by appending the given suffix to the
%% file name.

backup_file(Name, Opts) ->
    case file_type(Name) of
        {value, regular} ->
            backup_file_1(Name, Opts);
        {value, _} ->
            error_backup_file(Name),
            exit(error);
        none ->
            ok
    end.

%% The file should exist and be a regular file here.

backup_file_1(Name, Opts) ->
    Suffix = proplists:get_value(backup_suffix, Opts, ""),
    Dest = filename:join(filename:dirname(Name),
                         filename:basename(Name) ++ Suffix),
    case catch file:rename(Name, Dest) of
        ok ->
            verbose("made backup of file `~s'.", [Name], Opts);
        {error, R} ->
            error_backup_file(Name),
            exit({error, R});
        {'EXIT', R} ->
            error_backup_file(Name),
            exit(R);
        R ->
            error_backup_file(Name),
            throw(R)
    end.


%% =====================================================================
%% @spec module(Forms) -> syntaxTree()
%% @equiv module(Forms, [])

module(Forms) ->
    module(Forms, []).

%% =====================================================================
%% @spec module(Forms, Options::[term()]) -> syntaxTree()
%%
%%          Forms = syntaxTree() | [syntaxTree()]
%%          syntaxTree() = erl_syntax:syntaxTree()
%%
%% @doc Tidies a syntax tree representation of a module
%% definition. The given <code>Forms</code> may be either a single
%% syntax tree of type <code>form_list</code>, or a list of syntax
%% trees representing "program forms". In either case,
%% <code>Forms</code> must represents a single complete module
%% definition. The returned syntax tree has type
%% <code>form_list</code> and represents a tidied-up version of the
%% same source code.
%%
%% <p>Available options are:
%% <dl>
%%   <dt>{auto_export_vars, bool()}</dt>
%%
%%       <dd>If the value is <code>true</code>, all matches
%%       "<code>{V1, ..., Vn} = E</code>" where <code>E</code> is a
%%       case-, if- or receive-expression whose branches all return
%%       n-tuples (or explicitly throw exceptions) will be rewritten
%%       to bind and export the variables <code>V1</code>, ...,
%%       <code>Vn</code> directly. The default value is
%%       <code>false</code>.
%%
%%       <p>For example:
%%       <pre>
%%                {X, Y} = case ... of
%%                             ... -> {17, foo()};
%%                             ... -> {42, bar()}
%%                         end
%%       </pre>
%%       will be rewritten to:
%%       <pre>
%%                case ... of
%%                    ... -> X = 17, Y = foo(), {X, Y};
%%                    ... -> X = 42, Y = bar(), {X, Y}
%%                end
%%       </pre></p></dd>
%%
%%   <dt>{auto_list_comp, bool()}</dt>
%%
%%       <dd>If the value is <code>true</code>, calls to
%%       <code>lists:map/2</code> and <code>lists:filter/2</code> will
%%       be rewritten using list comprehensions. The default value is
%%       <code>true</code>.</dd>
%%
%%   <dt>{file, string()}</dt>
%%
%%       <dd>Specifies the name of the file from which the source code
%%       was taken. This is only used for generation of error
%%       reports. The default value is the empty string.</dd>
%%
%%   <dt>{idem, bool()}</dt>
%%
%%       <dd>If the value is <code>true</code>, all options that affect
%%       how the code is modified are set to "no changes". For example,
%%       to only update guard tests, and nothing else, use the options
%%       <code>[new_guard_tests, idem]</code>. (Recall that options
%%       closer to the beginning of the list have higher
%%       precedence.)</dd>
%%
%%   <dt>{keep_unused, bool()}</dt>
%%
%%       <dd>If the value is <code>true</code>, unused functions will
%%       not be removed from the code. The default value is
%%       <code>false</code>.</dd>
%%
%%   <dt>{new_guard_tests, bool()}</dt>
%%
%%       <dd>If the value is <code>true</code>, guard tests will be
%%       updated to use the new names, e.g. "<code>is_integer(X)</code>"
%%       instead of "<code>integer(X)</code>". The default value is
%%       <code>true</code>. See also <code>old_guard_tests</code>.</dd>
%%
%%   <dt>{no_imports, bool()}</dt>
%%
%%       <dd>If the value is <code>true</code>, all import statements
%%       will be removed and calls to imported functions will be
%%       expanded to explicit remote calls. The default value is
%%       <code>false</code>.</dd>
%%
%%   <dt>{old_guard_tests, bool()}</dt>
%%
%%       <dd>If the value is <code>true</code>, guard tests will be
%%       changed to use the old names instead of the new ones,
%%       e.g. "<code>integer(X)</code>" instead of
%%       "<code>is_integer(X)</code>". The default value is
%%       <code>false</code>. This option overrides the
%%       <code>new_guard_tests</code> option.</dd>
%%
%%   <dt>{quiet, bool()}</dt>
%%
%%       <dd>If the value is <code>true</code>, all information
%%       messages and warning messages will be suppressed. The default
%%       value is <code>false</code>.</dd>
%%
%%   <dt>{rename, [{{atom(), atom(), integer()},
%%                  {atom(), atom()}}]}</dt>
%%
%%       <dd>The value is a list of pairs, associating tuples
%%       <code>{Module, Name, Arity}</code> with tuples
%%       <code>{NewModule, NewName}</code>, specifying renamings of
%%       calls to remote functions. By default, the value is the empty
%%       list.
%%
%%       <p>The renaming affects only remote calls (also when
%%       disguised by import declarations); local calls within a
%%       module are not affected, and no function definitions are
%%       renamed. Since the arity cannot change, the new name is
%%       represented by <code>{NewModule, NewName}</code> only. Only
%%       calls matching the specified arity will match; multiple
%%       entries are necessary for renaming calls to functions that
%%       have the same module and function name, but different
%%       arities.</p>
%%
%%       <p>This option can also be used to override the default
%%       renaming of calls which use obsolete function names.</p></dd>
%%
%%   <dt>{verbose, bool()}</dt>
%%
%%       <dd>If the value is <code>true</code>, progress messages
%%       will be output while the program is running, unless the
%%       <code>quiet</code> option is <code>true</code>. The default
%%       value is <code>false</code>.</dd>
%%
%% </dl></p>

module(Forms, Opts) when list(Forms) ->
    module(erl_syntax:form_list(Forms), Opts);
module(Forms, Opts) ->
    Opts1 = proplists:expand(module__expansions(), Opts)
	    ++ module__defaults(),
    File = proplists:get_value(file, Opts1, ""),
    Forms1 = erl_syntax:flatten_form_list(Forms),
    module_1(Forms1, File, Opts1).

module__defaults() ->
    [{auto_export_vars, false},
     {auto_list_comp, true},
     {keep_unused, false},
     {new_guard_tests, true},
     {no_imports, false},
     {old_guard_tests, false},
     {quiet, false},
     {verbose, false}].

module__expansions() ->
    [{idem, [{auto_export_vars, false},
	     {auto_list_comp, false},
	     {keep_unused, true},
	     {new_guard_tests, false},
	     {no_imports, false},
	     {old_guard_tests, false}]}].

module_1(Forms, File, Opts) ->
    Info = analyze_forms(Forms, File),
    Module = get_module_name(Info, File),
    Attrs = get_module_attributes(Info),
    Exports = get_module_exports(Info),
    Imports = get_module_imports(Info),
    Opts1 = check_imports(Imports, Opts, File),
    Fs = erl_syntax:form_list_elements(Forms),
    {Names, Defs} = collect_functions(Fs),
    Exports1 = check_export_all(Attrs, Names, Exports),
    Roots = ordsets:union(ordsets:from_list(Exports1),
                          hidden_uses(Fs, Imports)),
    {Names1, Used, Imported, Defs1} = visit_used(Names, Defs, Roots,
                                                 Imports, Module,
                                                 Opts1),
    Fs1 = update_forms(Fs, Defs1, Imported, Opts1),
    Fs2 = filter_forms(Fs1, Names1, Used, Opts1),
    rewrite(Forms, erl_syntax:form_list(Fs2)).

analyze_forms(Forms, File) ->
    case catch {ok, erl_syntax_lib:analyze_forms(Forms)} of
        {ok, L1} ->
            L1;
        syntax_error ->
            report_error({File, 0, "syntax error."}),
            erlang:fault(badarg);
        {'EXIT', R} ->
            exit(R);
        R ->
            throw(R)
    end.

get_module_name(List, File) ->
    case lists:keysearch(module, 1, List) of
        {value, {module, M}} ->
            M;
        _ ->
            report_error({File, 0,
                          "cannot determine module name."}),
            exit(error)
    end.

get_module_attributes(List) ->
    case lists:keysearch(attributes, 1, List) of
        {value, {attributes, As}} ->
            As;
        _ ->
            []
    end.

get_module_exports(List) ->
    case lists:keysearch(exports, 1, List) of
        {value, {exports, Es}} ->
            Es;
        _ ->
            []
    end.

get_module_imports(List) ->
    case lists:keysearch(imports, 1, List) of
        {value, {imports, Is}} ->
            flatten_imports(Is);
        _ ->
            []
    end.

compile_attrs(As) ->
    lists:append([if list(T) -> T; true -> [T] end
                  || {compile, T} <- As]).

flatten_imports(Is) ->
    [{F, M} || {M, Fs} <- Is, F <- Fs].

check_imports(Is, Opts, File) ->
    case check_imports_1(lists:sort(Is)) of
        true ->
            Opts;
        false ->
            case proplists:get_bool(no_imports, Opts) of
                true ->
                    warn({File, 0,
			  "conflicting import declarations - "
			  "will not expand imports."},
			 [], Opts),
                    %% prevent expansion of imports
                    [{no_imports, false} | Opts];
                false ->
                    Opts
            end
    end.

check_imports_1([{F1, M1}, {F2, M2} | _Is]) when F1 == F2, M1 /= M2 ->
    false;
check_imports_1([_ | Is]) ->
    check_imports_1(Is);
check_imports_1([]) ->
    true.

check_export_all(Attrs, Names, Exports) ->
    case lists:member(export_all, compile_attrs(Attrs)) of
        true ->
            Exports ++ sets:to_list(Names);
        false ->
            Exports
    end.

filter_forms(Fs, Names, Used, Opts) ->
    Keep = case proplists:get_bool(keep_unused, Opts) of
               true ->
                   Names;
               false ->
                   Used
           end,
    [F || F <- Fs, keep_form(F, Keep, Opts)].

keep_form(Form, Used, Opts) ->
    case erl_syntax:type(Form) of
        function ->
            N = erl_syntax_lib:analyze_function(Form),
            case sets:is_element(N, Used) of
                false ->
                    report_removed_def("function", N, Form, Opts),
                    false;
                true ->
                    true
            end;
        rule ->
            N = erl_syntax_lib:analyze_rule(Form),
            case sets:is_element(N, Used) of
                false ->
                    report_removed_def("rule", N, Form, Opts),
                    false;
                true ->
                    true
            end;
        attribute ->
            case erl_syntax_lib:analyze_attribute(Form) of
                {file, _} ->
                    false;
                _ ->
                    true
            end;
        error_marker ->
            false;
        warning_marker ->
            false;
        eof_marker ->
            false;
        _ ->
            true
    end.

report_removed_def(Type, {N, A}, Form, Opts) ->
    File = proplists:get_value(file, Opts, ""),
    report({File, erl_syntax:get_pos(Form),
	    "removing unused ~s `~w/~w'."},
	   [Type, N, A], Opts).

collect_functions(Forms) ->
    lists:foldl(
      fun (F, {Names, Defs}) ->
              case erl_syntax:type(F) of
                  function ->
                      N = erl_syntax_lib:analyze_function(F),
                      {sets:add_element(N, Names),
                       dict:store(N, {F, []}, Defs)};
                  rule ->
                      N = erl_syntax_lib:analyze_rule(F),
                      {sets:add_element(N, Names),
                       dict:store(N, {F, []}, Defs)};
                  _ ->
                      {Names, Defs}
              end
      end,
      {sets:new(), dict:new()},
      Forms).

update_forms([F | Fs], Defs, Imports, Opts) ->
    case erl_syntax:type(F) of
        function ->
            N = erl_syntax_lib:analyze_function(F),
            {F1, Fs1} = dict:fetch(N, Defs),
            [F1 | lists:reverse(Fs1)] ++ update_forms(Fs, Defs, Imports,
                                                      Opts);
        rule ->
            N = erl_syntax_lib:analyze_rule(F),
            {F1, Fs1} = dict:fetch(N, Defs),
            [F1 | lists:reverse(Fs1)] ++ update_forms(Fs, Defs, Imports,
                                                      Opts);
        attribute ->
            [update_attribute(F, Imports, Opts)
             | update_forms(Fs, Defs, Imports, Opts)];
        _ ->
            [F | update_forms(Fs, Defs, Imports, Opts)]
    end;
update_forms([], _, _, _) ->
    [].

update_attribute(F, Imports, Opts) ->
    case erl_syntax_lib:analyze_attribute(F) of
        {import, {M, Ns}} ->
            Ns1 = ordsets:from_list([N || N <- Ns,
                                          sets:is_element(N, Imports)]),
            case ordsets:subtract(ordsets:from_list(Ns), Ns1) of
                [] ->
                    ok;
                Names ->
                    File = proplists:get_value(file, Opts, ""),
                    report({File, erl_syntax:get_pos(F),
			    "removing unused imports:~s"},
			   [[io_lib:fwrite("\n\t`~w:~w/~w'", [M, N, A])
			     || {N, A} <- Names]], Opts)
            end,
            Is = [make_fname(N) || N <- Ns1],
            if Is == [] ->
                    %% This will be filtered out later.
                    erl_syntax:warning_marker(deleted);
               true ->
                    F1 = erl_syntax:attribute(erl_syntax:atom(import),
                                              [erl_syntax:atom(M),
                                               erl_syntax:list(Is)]),
                    rewrite(F, F1)
            end;
        {export, Ns} ->
            Es = [make_fname(N) || N <- ordsets:from_list(Ns)],
            F1 = erl_syntax:attribute(erl_syntax:atom(export),
                                      [erl_syntax:list(Es)]),
            rewrite(F, F1);
        _ ->
            F
    end.

make_fname({F, A}) ->
    erl_syntax:arity_qualifier(erl_syntax:atom(F),
                               erl_syntax:integer(A)).

hidden_uses(Fs, Imports) ->
    Used = lists:foldl(fun (F, S) ->
                               case erl_syntax:type(F) of
                                   attribute ->
                                       hidden_uses_1(F, S);
                                   _ ->
                                       S
                               end
                       end,
                       [], Fs),
    ordsets:subtract(Used, ordsets:from_list([F || {F, _M} <- Imports])).

hidden_uses_1(Tree, Used) ->
    erl_syntax_lib:fold(fun hidden_uses_2/2, Used, Tree).

hidden_uses_2(Tree, Used) ->
    case erl_syntax:type(Tree) of
        application ->
            F = erl_syntax:application_operator(Tree),
            case erl_syntax:type(F) of
                atom ->
                    As = erl_syntax:application_arguments(Tree),
                    N = {erl_syntax:atom_value(F), length(As)},
                    case is_auto_imported(N) of
                        true ->
                            Used;
                        false ->
                            ordsets:add_element(N, Used)
                    end;
                _ ->
                    Used
            end;
        implicit_fun ->
            F = erl_syntax:implicit_fun_name(Tree),
            case catch {ok, erl_syntax_lib:analyze_function_name(F)} of
                {ok, {Name, Arity} = N}
                when atom(Name), integer(Arity) ->
                    ordsets:add_element(N, Used);
                _ ->
                    Used
            end;
        _ ->
            Used
    end.

-record(env, {file,
              module,
              current,
              imports,
              context = normal,
              verbosity = 1,
              quiet = false,
              no_imports = false,
              spawn_funs = false,
              auto_list_comp = true,
              auto_export_vars = false,
              new_guard_tests = true,
	      old_guard_tests = false}).

-record(st, {varc, used, imported, vars, functions, new_forms, rename}).

visit_used(Names, Defs, Roots, Imports, Module, Opts) ->
    File = proplists:get_value(file, Opts, ""),
    NoImports = proplists:get_bool(no_imports, Opts),
    Rename = proplists:append_values(rename, Opts),
    loop(Roots, sets:new(), Defs,
         #env{file = File,
              module = Module,
              imports = dict:from_list(Imports),
              verbosity = verbosity(Opts),
              no_imports = NoImports,
              spawn_funs = proplists:get_bool(spawn_funs, Opts),
              auto_list_comp = proplists:get_bool(auto_list_comp, Opts),
              auto_export_vars = proplists:get_bool(auto_export_vars,
						    Opts),
              new_guard_tests = proplists:get_bool(new_guard_tests,
						   Opts),
              old_guard_tests = proplists:get_bool(old_guard_tests,
						   Opts)},
         #st{used = sets:from_list(Roots),
             imported = sets:new(),
             functions = Names,
             rename = dict:from_list([X || {F1, F2} = X <- Rename,
                                           is_remote_name(F1),
                                           is_atom_pair(F2)])}).

loop([F | Work], Seen0, Defs0, Env, St0) ->
    case sets:is_element(F, Seen0) of
        true ->
            loop(Work, Seen0, Defs0, Env, St0);
        false ->
            Seen1 = sets:add_element(F, Seen0),
            case dict:find(F, Defs0) of
                {ok, {Form, Fs}} ->
                    Vars = erl_syntax_lib:variables(Form),
                    Form1 = erl_syntax_lib:annotate_bindings(Form, []),
                    {Form2, St1} = visit(Form1, Env#env{current = F},
                                         St0#st{varc = 1,
                                                used = sets:new(),
                                                vars = Vars,
                                                new_forms = []}),
                    Fs1 = St1#st.new_forms ++ Fs,
                    Defs1 = dict:store(F, {Form2, Fs1}, Defs0),
                    Used = St1#st.used,
                    Work1 = sets:to_list(Used) ++ Work,
                    St2 = St1#st{used = sets:union(Used, St0#st.used)},
                    loop(Work1, Seen1, Defs1, Env, St2);
                error ->
                    %% Quietly ignore any names that have no definition.
                    loop(Work, Seen1, Defs0, Env, St0)
            end
    end;
loop([], _, Defs, _, St) ->
    {St#st.functions, St#st.used, St#st.imported, Defs}.

visit(Tree, Env, St0) ->
    case erl_syntax:type(Tree) of
        application ->
            visit_application(Tree, Env, St0);
        infix_expr ->
            visit_infix_expr(Tree, Env, St0);
        prefix_expr ->
            visit_prefix_expr(Tree, Env, St0);
        implicit_fun ->
            visit_implicit_fun(Tree, Env, St0);
        clause ->
            visit_clause(Tree, Env, St0);
        list_comp ->
            visit_list_comp(Tree, Env, St0);
        match_expr ->
            visit_match_expr(Tree, Env, St0);
        _ ->
            visit_other(Tree, Env, St0)
    end.

visit_other(Tree, Env, St) ->
    F = fun (T, S) -> visit(T, Env, S) end,
    erl_syntax_lib:mapfold_subtrees(F, St, Tree).

visit_list(Ts, Env, St0) ->
    lists:mapfoldl(fun (T, S) -> visit(T, Env, S) end, St0, Ts).

visit_implicit_fun(Tree, _Env, St0) ->
    F = erl_syntax:implicit_fun_name(Tree),
    case catch {ok, erl_syntax_lib:analyze_function_name(F)} of
        {ok, {Name, Arity} = N}
        when atom(Name), integer(Arity) ->
            Used = sets:add_element(N, St0#st.used),
            {Tree, St0#st{used = Used}};
        _ ->
            Tree
    end.

visit_clause(Tree, Env, St0) ->
    %% We do not visit the patterns (for now, anyway).
    Ps = erl_syntax:clause_patterns(Tree),
    {G, St1} = case erl_syntax:clause_guard(Tree) of
                   none ->
                       {none, St0};
                   G0 ->
                       visit(G0, Env#env{context = guard_test}, St0)
               end,
    {B, St2} = visit_list(erl_syntax:clause_body(Tree), Env, St1),
    {rewrite(Tree, erl_syntax:clause(Ps, G, B)), St2}.

visit_infix_expr(Tree, #env{context = guard_test}, St0) ->
    %% Detect transition from guard test to guard expression.
    visit_other(Tree, #env{context = guard_expr}, St0);
visit_infix_expr(Tree, Env, St0) ->
    visit_other(Tree, Env, St0).

visit_prefix_expr(Tree, #env{context = guard_test}, St0) ->
    %% Detect transition from guard test to guard expression.
    visit_other(Tree, #env{context = guard_expr}, St0);
visit_prefix_expr(Tree, Env, St0) ->
    visit_other(Tree, Env, St0).

visit_application(Tree, Env, St0) ->
    Env1 = case Env of
               #env{context = guard_test} ->
                   Env#env{context = guard_expr};
               _ ->
                   Env
           end,
    {F, St1} = visit(erl_syntax:application_operator(Tree), Env1, St0),
    {As, St2} = visit_list(erl_syntax:application_arguments(Tree), Env1,
                           St1),
    case erl_syntax:type(F) of
        atom ->
            visit_atom_application(F, As, Tree, Env, St2);
        implicit_fun ->
            visit_named_fun_application(F, As, Tree, Env, St2);
        fun_expr ->
            visit_lambda_application(F, As, Tree, Env, St2);
        _ ->
            visit_nonlocal_application(F, As, Tree, Env, St2)
    end.

visit_application_final(F, As, Tree, St0) ->
    {rewrite(Tree, erl_syntax:application(F, As)), St0}.

revisit_application(F, As, Tree, Env, St0) ->
    visit(rewrite(Tree, erl_syntax:application(F, As)), Env, St0).

visit_atom_application(F, As, Tree, #env{context = guard_test} = Env,
                       St0) ->
    N = erl_syntax:atom_value(F),
    A = length(As),
    N1 = case Env#env.old_guard_tests of
             true ->
                 reverse_guard_test(N, A);
             false ->
		 case Env#env.new_guard_tests of
		     true ->
			 rewrite_guard_test(N, A);
		     false ->
			 N
		 end
	 end,
    if N1 /= N ->
            report({Env#env.file, erl_syntax:get_pos(F),
		    "changing guard test `~w' to `~w'."},
		   [N, N1], Env#env.verbosity);
       true ->
            ok
    end,
    %% No need to revisit here.
    F1 = rewrite(F, erl_syntax:atom(N1)),
    visit_application_final(F1, As, Tree, St0);
visit_atom_application(F, As, Tree, #env{context = guard_expr}, St0) ->
    %% Atom applications in guard expressions are never local calls.
    visit_application_final(F, As, Tree, St0);
visit_atom_application(F, As, Tree, Env, St0) ->
    N = {erl_syntax:atom_value(F), length(As)},
    case is_auto_imported(N) of
        true ->
            visit_bif_call(N, F, As, Tree, Env, St0);
        false ->
            case is_imported(N, Env) of
                true ->
                    visit_import_application(N, F, As, Tree, Env, St0);
                false ->
                    Used = sets:add_element(N, St0#st.used),
                    visit_application_final(F, As, Tree,
                                            St0#st{used = Used})
            end
    end.

visit_import_application({N, A} = Name, F, As, Tree, Env, St0) ->
    M = dict:fetch(Name, Env#env.imports),
    Expand = case Env#env.no_imports of
                 true ->
                     true;
                 false ->
                     auto_expand_import({M, N, A}, St0)
             end,
    case Expand of
        true ->
            report({Env#env.file, erl_syntax:get_pos(F),
		    "expanding call to imported function `~w:~w/~w'."},
		   [M, N, A], Env#env.verbosity),
            F1 = erl_syntax:module_qualifier(erl_syntax:atom(M),
                                             erl_syntax:atom(N)),
            revisit_application(rewrite(F, F1), As, Tree, Env, St0);
        false ->
            Is = sets:add_element(Name, St0#st.imported),
            visit_application_final(F, As, Tree, St0#st{imported = Is})
    end.

visit_bif_call({apply, 2}, F, [E, Args] = As, Tree, Env, St0) ->
    case erl_syntax:is_proper_list(Args) of
        true ->
            report({Env#env.file, erl_syntax:get_pos(F),
		    "changing use of `apply/2' "
		    "to direct function call."},
		   [], Env#env.verbosity),
            As1 = erl_syntax:list_elements(Args),
            revisit_application(E, As1, Tree, Env, St0);
        false ->
            visit_application_final(F, As, Tree, St0)
    end;
visit_bif_call({apply, 3}, F, [M, N, Args] = As, Tree, Env, St0) ->
    case erl_syntax:is_proper_list(Args) of
        true ->
            report({Env#env.file, erl_syntax:get_pos(F),
		    "changing use of `apply/3' "
		    "to direct remote call."},
		   [], Env#env.verbosity),
            F1 = rewrite(F, erl_syntax:module_qualifier(M, N)),
            As1 = erl_syntax:list_elements(Args),
            visit_nonlocal_application(F1, As1, Tree, Env, St0);
        false ->
            visit_application_final(F, As, Tree, St0)
    end;
visit_bif_call({spawn, 3} = N, F, [_, _, _] = As, Tree, Env, St0) ->
    visit_spawn_call(N, F, [], As, Tree, Env, St0);
visit_bif_call({spawn_link, 3} = N, F, [_, _, _] = As, Tree, Env,
               St0) ->
    visit_spawn_call(N, F, [], As, Tree, Env, St0);
visit_bif_call({spawn, 4} = N, F, [A | [_, _, _] = As], Tree, Env,
               St0) ->
    visit_spawn_call(N, F, [A], As, Tree, Env, St0);
visit_bif_call({spawn_link, 4} = N, F, [A | [_, _, _] = As], Tree, Env,
               St0) ->
    visit_spawn_call(N, F, [A], As, Tree, Env, St0);
visit_bif_call(_, F, As, Tree, _Env, St0) ->
    visit_application_final(F, As, Tree, St0).

visit_spawn_call({N, A}, F, Ps, [A1, A2, A3] = As, Tree,
                 #env{spawn_funs = true} = Env, St0) ->
    case erl_syntax:is_proper_list(A3) of
        true ->
            report({Env#env.file, erl_syntax:get_pos(F),
		    "changing use of `~w/~w' to `~w/~w' with a fun."},
		   [N, A, N, 1 + length(Ps)], Env#env.verbosity),
            F1 = case erl_syntax:is_atom(A1, Env#env.module) of
                     true ->
                         A2;    % calling self
                     false ->
                         clone(A1,
                               erl_syntax:module_qualifier(A1, A2))
                 end,
            %% Need to do some scoping tricks here to make sure the
            %% arguments are evaluated by the parent, not by the spawned
            %% process.
            As1 = erl_syntax:list_elements(A3),
            {Vs, St1} = new_variables(length(As1), St0),
            E1 = clone(F1, erl_syntax:application(F1, Vs)),
            C1 = clone(E1, erl_syntax:clause([], [E1])),
            E2 = clone(C1, erl_syntax:fun_expr([C1])),
            C2 = clone(E2, erl_syntax:clause(Vs, [], [E2])),
            E3 = clone(C2, erl_syntax:fun_expr([C2])),
            E4 = clone(E3, erl_syntax:application(E3, As1)),
            E5 = erl_syntax_lib:annotate_bindings(E4, get_env(A1)),
            {E6, St2} = visit(E5, Env, St1),
            F2 = rewrite(F, erl_syntax:atom(N)),
            visit_nonlocal_application(F2, Ps ++ [E6], Tree, Env, St2);
        false ->
            visit_application_final(F, Ps ++ As, Tree, St0)
    end;
visit_spawn_call(_, F, Ps, As, Tree, _Env, St0) ->
    visit_application_final(F, Ps ++ As, Tree, St0).

visit_named_fun_application(F, As, Tree, Env, St0) ->
    Name = erl_syntax:implicit_fun_name(F),
    case catch {ok, erl_syntax_lib:analyze_function_name(Name)} of
        {ok, {A, N}} when atom(A), integer(N), N == length(As) ->
            case is_nonlocal({A, N}, Env) of
                true ->
                    %% Making this a direct call would be an error.
                    visit_application_final(F, As, Tree, St0);
                false ->
                    report({Env#env.file, erl_syntax:get_pos(F),
			    "changing application of implicit fun "
			    "to direct local call."},
			   [], Env#env.verbosity),
                    Used = sets:add_element({A, N}, St0#st.used),
                    F1 = rewrite(F, erl_syntax:atom(A)),
                    revisit_application(F1, As, Tree, Env,
                                        St0#st{used = Used})
            end;
        _  ->
            visit_application_final(F, As, Tree, St0)
    end.

visit_lambda_application(F, As, Tree, Env, St0) ->
    A = erl_syntax:fun_expr_arity(F),
    case A == length(As) of
        true ->
            report({Env#env.file, erl_syntax:get_pos(F),
		    "changing application of fun-expression "
		    "to local function call."},
		   [], Env#env.verbosity),
            {Base, _} = Env#env.current,
            Free = [erl_syntax:variable(V) || V <- get_free_vars(F)],
            N = length(Free),
            A1 = A + N,
            {Name, St1} = new_fname({Base, A1}, St0),
            Cs = augment_clauses(erl_syntax:fun_expr_clauses(F), Free),
            F1 = erl_syntax:atom(Name),
            New = rewrite(F, erl_syntax:function(F1, Cs)),
            Used = sets:add_element({Name, A1}, St1#st.used),
            Forms = [New | St1#st.new_forms],
            St2 = St1#st{new_forms = Forms, used = Used},
            visit_application_final(F1, As ++ Free, Tree, St2);
        false ->
            warn({Env#env.file, erl_syntax:get_pos(F),
		  "arity mismatch in fun-expression application."},
		 [], Env#env.verbosity),
            visit_application_final(F, As, Tree, St0)
    end.

augment_clauses(Cs, Vs) ->
    [begin
	 Ps = erl_syntax:clause_patterns(C),
	 G = erl_syntax:clause_guard(C),
	 Es = erl_syntax:clause_body(C),
	 rewrite(C, erl_syntax:clause(Ps ++ Vs, G, Es))
     end
     || C <- Cs].

visit_nonlocal_application(F, As, Tree, Env, St0) ->
    case erl_syntax:type(F) of
        tuple ->
            case erl_syntax:tuple_elements(F) of
                [X1, X2] ->
                    report({Env#env.file, erl_syntax:get_pos(F),
			    "changing application of 2-tuple "
			    "to direct remote call."},
			   [], Env#env.verbosity),
                    F1 = erl_syntax:module_qualifier(X1, X2),
                    revisit_application(rewrite(F, F1), As, Tree, Env,
                                        St0);
                _ ->
                    visit_application_final(F, As, Tree, St0)
            end;
        module_qualifier ->
            case catch {ok, erl_syntax_lib:analyze_function_name(F)} of
                {ok, {M, N}} when atom(M), atom(N) ->
                    visit_remote_application({M, N, length(As)}, F, As,
                                             Tree, Env, St0);
                _ ->
                    visit_application_final(F, As, Tree, St0)
            end;
        _ ->
            visit_application_final(F, As, Tree, St0)
    end.

visit_remote_application({lists, append, 2}, F, [A1, A2], Tree, Env,
                         St0) ->
    report({Env#env.file, erl_syntax:get_pos(F),
	    "replacing call to `lists:append/2' "
	    "with the `++' operator."},
	   [], Env#env.verbosity),
    Tree1 = erl_syntax:infix_expr(A1, erl_syntax:operator('++'), A2),
    visit(rewrite(Tree, Tree1), Env, St0);
visit_remote_application({lists, subtract, 2}, F, [A1, A2], Tree, Env,
                         St0) ->
    report({Env#env.file, erl_syntax:get_pos(F),
	    "replacing call to `lists:subtract/2' "
	    "with the `--' operator."},
	   [], Env#env.verbosity),
    Tree1 = erl_syntax:infix_expr(A1, erl_syntax:operator('--'), A2),
    visit(rewrite(Tree, Tree1), Env, St0);

visit_remote_application({lists, filter, 2}, F, [A1, A2] = As, Tree,
                         Env, St0) ->
    case Env#env.auto_list_comp
	and (get_var_exports(A1) == [])
	and (get_var_exports(A2) == []) of
        true ->
            report({Env#env.file, erl_syntax:get_pos(F),
		    "replacing call to `lists:filter/2' "
		    "with a list comprehension."},
		   [], Env#env.verbosity),
            {V, St1} = new_variable(St0),
            G = clone(A2, erl_syntax:generator(V, A2)),
            T = clone(A1, erl_syntax:application(A1, [V])),
            L = erl_syntax:list_comp(V, [G, T]),
            L1 = erl_syntax_lib:annotate_bindings(L, get_env(Tree)),
            visit(rewrite(Tree, L1), Env, St1);
        false ->
            visit_application_final(F, As, Tree, St0)
    end;
visit_remote_application({lists, map, 2}, F, [A1, A2] = As, Tree, Env,
                         St0) ->
    case Env#env.auto_list_comp
	and (get_var_exports(A1) == [])
	and (get_var_exports(A2) == []) of
        true ->
            report({Env#env.file, erl_syntax:get_pos(F),
		    "replacing call to `lists:map/2' "
		    "with a list comprehension."},
		   [], Env#env.verbosity),
            {V, St1} = new_variable(St0),
            T = clone(A1, erl_syntax:application(A1, [V])),
            G = clone(A2, erl_syntax:generator(V, A2)),
            L = erl_syntax:list_comp(T, [G]),
            L1 = erl_syntax_lib:annotate_bindings(L, get_env(Tree)),
            visit(rewrite(Tree, L1), Env, St1);
        false ->
            visit_application_final(F, As, Tree, St0)
    end;
visit_remote_application({M, N, A} = Name, F, As, Tree, Env, St) ->
    case is_auto_imported(Name) of
        true ->
            %% We don't remove the qualifier - it might be there for the
            %% sake of clarity.
            visit_bif_call({N, A}, F, As, Tree, Env, St);
        false ->
            case rename_remote_call(Name, St) of
                {M1, N1} ->
                    report({Env#env.file, erl_syntax:get_pos(F),
			    "updating obsolete call to `~w:~w/~w' "
			    "to use `~w:~w/~w' instead."},
			   [M, N, A, M1, N1, A], Env#env.verbosity),
                    M2 = erl_syntax:atom(M1),
                    N2 = erl_syntax:atom(N1),
                    F1 = erl_syntax:module_qualifier(M2, N2),
                    revisit_application(rewrite(F, F1), As, Tree, Env,
                                        St);
                false ->
                    visit_application_final(F, As, Tree, St)
            end
    end.

auto_expand_import({lists, append, 2}, _St) -> true;
auto_expand_import({lists, filter, 2}, _St) -> true;
auto_expand_import({lists, map, 2}, _St) -> true;
auto_expand_import(Name, St) ->
    case is_auto_imported(Name) of
        true ->
            true;
        false ->
            case rename_remote_call(Name, St) of
                false ->
                    false;
                _ ->
                    true
            end
    end.

visit_list_comp(Tree, Env, St0) ->
    Es = erl_syntax:list_comp_body(Tree),
    {Es1, St1} = visit_list_comp_body(Es, Env, St0),
    {T, St2} = visit(erl_syntax:list_comp_template(Tree), Env, St1),
    {rewrite(Tree, erl_syntax:list_comp(T, Es1)), St2}.

visit_list_comp_body_join(Env) ->
    fun (E, St0) ->
            case is_generator(E) of
                true ->
                    visit_generator(E, Env, St0);
                false ->
                    visit_filter(E, Env, St0)
            end
    end.

visit_list_comp_body(Es, Env, St0) ->
    lists:mapfoldl(visit_list_comp_body_join(Env), St0, Es).

%% 'visit_filter' also handles uninteresting generators.

visit_filter(E, Env, St0) ->
    visit(E, Env, St0).

%% "interesting" generators have the form V <- [V || ...]; this can be
%% unfolded as long as no bindings become erroneously shadowed.

visit_generator(G, Env, St0) ->
    P = erl_syntax:generator_pattern(G),
    case erl_syntax:type(P) of
        variable ->
            B = erl_syntax:generator_body(G),
            case erl_syntax:type(B) of
                list_comp ->
                    T = erl_syntax:list_comp_template(B),
                    case erl_syntax:type(T) of
                        variable ->
                            visit_generator_1(G, Env, St0);
                        _ ->
                            visit_filter(G, Env, St0)
                    end;
                _ ->
                    visit_filter(G, Env, St0)
            end;
        _ ->
            visit_filter(G, Env, St0)
    end.

visit_generator_1(G, Env, St0) ->
    recommend({Env#env.file, erl_syntax:get_pos(G),
	       "unfold that this nested list comprehension can be unfolded "
	       "by hand to get better efficiency."},
	      [], Env#env.verbosity),
    visit_filter(G, Env, St0).

visit_match_expr(Tree, Env, St0) ->
    %% We do not visit the pattern (for now, anyway).
    P = erl_syntax:match_expr_pattern(Tree),
    {B, St1} = visit(erl_syntax:match_expr_body(Tree), Env, St0),
    case erl_syntax:type(P) of
        tuple ->
            Ps = erl_syntax:tuple_elements(P),
            case lists:all(fun is_variable/1, Ps) of
                true ->
                    Vs = lists:sort([erl_syntax:variable_name(X)
                                     || X <- Ps]),
                    case ordsets:is_set(Vs) of
                        true ->
                            Xs = get_var_exports(B),
                            case ordsets:intersection(Vs, Xs) of
                                [] ->
                                    visit_match_body(Ps, P, B, Tree,
                                                     Env, St1);
                                _ ->
                                    visit_match_expr_final(P, B, Tree,
                                                           Env, St1)
                            end;
                        false ->
                            visit_match_expr_final(P, B, Tree, Env, St1)
                    end;
                false ->
                    visit_match_expr_final(P, B, Tree, Env, St1)
            end;
        _  ->
            visit_match_expr_final(P, B, Tree, Env, St1)
    end.

visit_match_expr_final(P, B, Tree, _Env, St0) ->
    {rewrite(Tree, erl_syntax:match_expr(P, B)), St0}.

visit_match_body(_Ps, P, B, Tree, #env{auto_export_vars = false} = Env,
                 St0) ->
    visit_match_expr_final(P, B, Tree, Env, St0);
visit_match_body(Ps, P, B, Tree, Env, St0) ->
    case erl_syntax:type(B) of
        case_expr ->
            Cs = erl_syntax:case_expr_clauses(B),
            case multival_clauses(Cs, length(Ps), Ps) of
                {true, Cs1} ->
                    report_export_vars(Env#env.file,
				       erl_syntax:get_pos(B),
				       "case", Env#env.verbosity),
                    A = erl_syntax:case_expr_argument(B),
                    Tree1 = erl_syntax:case_expr(A, Cs1),
                    {rewrite(Tree, Tree1), St0};
                false ->
                    visit_match_expr_final(P, B, Tree, Env, St0)
            end;
        if_expr ->
            Cs = erl_syntax:if_expr_clauses(B),
            case multival_clauses(Cs, length(Ps), Ps) of
                {true, Cs1} ->
                    report_export_vars(Env#env.file,
				       erl_syntax:get_pos(B),
				       "if", Env#env.verbosity),
                    Tree1 = erl_syntax:if_expr(Cs1),
                    {rewrite(Tree, Tree1), St0};
                false ->
                    visit_match_expr_final(P, B, Tree, Env, St0)
            end;
        cond_expr ->
            Cs = erl_syntax:cond_expr_clauses(B),
            case multival_clauses(Cs, length(Ps), Ps) of
                {true, Cs1} ->
                    report_export_vars(Env#env.file,
				       erl_syntax:get_pos(B),
				       "cond", Env#env.verbosity),
                    Tree1 = erl_syntax:cond_expr(Cs1),
                    {rewrite(Tree, Tree1), St0};
                false ->
                    visit_match_expr_final(P, B, Tree, Env, St0)
            end;
        receive_expr ->
            %% Handle the timeout case as an extra clause.
            As = erl_syntax:receive_expr_action(B),
            C = erl_syntax:clause([], As),
            Cs = erl_syntax:receive_expr_clauses(B),
            case multival_clauses([C | Cs], length(Ps), Ps) of
                {true, [C1 | Cs1]} ->
                    report_export_vars(Env#env.file,
				       erl_syntax:get_pos(B),
				       "receive", Env#env.verbosity),
                    T = erl_syntax:receive_expr_timeout(B),
                    As1 = erl_syntax:clause_body(C1),
                    Tree1 = erl_syntax:receive_expr(Cs1, T, As1),
                    {rewrite(Tree, Tree1), St0};
                false ->
                    visit_match_expr_final(P, B, Tree, Env, St0)
            end;
        _ ->
            visit_match_expr_final(P, B, Tree, Env, St0)
    end.

multival_clauses(Cs, N, Vs) ->
    multival_clauses(Cs, N, Vs, []).

multival_clauses([C | Cs], N, Vs, Cs1) ->
    case erl_syntax:clause_body(C) of
        [] ->
            false;
        Es ->
            E = lists:last(Es),
            case erl_syntax:type(E) of
                tuple ->
                    Ts = erl_syntax:tuple_elements(E),
                    if length(Ts) == N ->
                            Bs = make_matches(E, Vs, Ts),
                            Es1 = replace_last(Es, Bs),
                            Ps = erl_syntax:clause_patterns(C),
                            G = erl_syntax:clause_guard(C),
                            C1 = erl_syntax:clause(Ps, G, Es1),
                            multival_clauses(Cs, N, Vs,
                                             [rewrite(C, C1) | Cs1]);
                       true ->
                            false
                    end;
                _ ->
                    case erl_syntax_lib:is_fail_expr(E) of
                        true ->
                            %% We must add dummy bindings here so we
                            %% don't introduce compilation errors due to
                            %% "unsafe" variable exports.
                            Bs = make_matches(Vs,
                                              erl_syntax:atom(false)),
                            Es1 = replace_last(Es, Bs ++ [E]),
                            Ps = erl_syntax:clause_patterns(C),
                            G = erl_syntax:clause_guard(C),
                            C1 = erl_syntax:clause(Ps, G, Es1),
                            multival_clauses(Cs, N, Vs,
                                             [rewrite(C, C1) | Cs1]);
                        false ->
                            false
                    end
            end
    end;
multival_clauses([], _N, _Vs, Cs) ->
    {true, lists:reverse(Cs)}.

make_matches(E, Vs, Ts) ->
    case make_matches(Vs, Ts) of
        [] ->
            [];
        [B | Bs] ->
            [rewrite(E, B) | Bs]    % preserve comments on E (but not B)
    end.

make_matches([V | Vs], [T | Ts]) ->
    [erl_syntax:match_expr(V, T) | make_matches(Vs, Ts)];
make_matches([V | Vs], T) when T /= [] ->
    [erl_syntax:match_expr(V, T) | make_matches(Vs, T)];
make_matches([], _) ->
    [].

rename_remote_call(F, St) ->
    case dict:find(F, St#st.rename) of
        error ->
            rename_remote_call_1(F);
        {ok, F1} -> F1
    end.

rename_remote_call_1({dict, dict_to_list, 1}) -> {dict, to_list};
rename_remote_call_1({dict, list_to_dict, 1}) -> {dict, from_list};
rename_remote_call_1({erl_eval, arg_list, 2}) -> {erl_eval, expr_list};
rename_remote_call_1({erl_eval, arg_list, 3}) -> {erl_eval, expr_list};
rename_remote_call_1({erl_eval, seq, 2}) -> {erl_eval, exprs};
rename_remote_call_1({erl_eval, seq, 3}) -> {erl_eval, exprs};
rename_remote_call_1({erl_pp, seq, 1}) -> {erl_eval, seq};
rename_remote_call_1({erl_pp, seq, 2}) -> {erl_eval, seq};
rename_remote_call_1({erlang, info, 1}) -> {erlang, system_info};
rename_remote_call_1({io, parse_erl_seq, 1}) -> {io, parse_erl_exprs};
rename_remote_call_1({io, parse_erl_seq, 2}) -> {io, parse_erl_exprs};
rename_remote_call_1({io, parse_erl_seq, 3}) -> {io, parse_erl_exprs};
rename_remote_call_1({io, scan_erl_seq, 1}) -> {io, scan_erl_exprs};
rename_remote_call_1({io, scan_erl_seq, 2}) -> {io, scan_erl_exprs};
rename_remote_call_1({io, scan_erl_seq, 3}) -> {io, scan_erl_exprs};
rename_remote_call_1({io_lib, reserved_word, 1}) -> {erl_scan, reserved_word};
rename_remote_call_1({io_lib, scan, 1}) -> {erl_scan, string};
rename_remote_call_1({io_lib, scan, 2}) -> {erl_scan, string};
rename_remote_call_1({io_lib, scan, 3}) -> {erl_scan, tokens};
rename_remote_call_1({orddict, dict_to_list, 1}) -> {orddict, to_list};
rename_remote_call_1({orddict, list_to_dict, 1}) -> {orddict, from_list};
rename_remote_call_1({ordsets, list_to_set, 1}) -> {ordsets, from_list};
rename_remote_call_1({ordsets, new_set, 0}) -> {ordsets, new};
rename_remote_call_1({ordsets, set_to_list, 1}) -> {ordsets, to_list};
rename_remote_call_1({ordsets, subset, 2}) -> {ordsets, is_subset};
rename_remote_call_1({sets, list_to_set, 1}) -> {sets, from_list};
rename_remote_call_1({sets, new_set, 0}) -> {sets, new};
rename_remote_call_1({sets, set_to_list, 1}) -> {sets, to_list};
rename_remote_call_1({sets, subset, 2}) -> {sets, is_subset};
rename_remote_call_1({string, index, 2}) -> {string, str};
rename_remote_call_1({unix, cmd, 1}) -> {os, cmd};
rename_remote_call_1(_) -> false.

rewrite_guard_test(atom, 1) -> is_atom;
rewrite_guard_test(binary, 1) -> is_binary;
rewrite_guard_test(constant, 1) -> is_constant;
rewrite_guard_test(float, 1) -> is_float;
rewrite_guard_test(function, 1) -> is_function;
rewrite_guard_test(integer, 1) -> is_integer;
rewrite_guard_test(list, 1) -> is_list;
rewrite_guard_test(number, 1) -> is_number;
rewrite_guard_test(pid, 1) -> is_pid;
rewrite_guard_test(port, 1) -> is_port;
rewrite_guard_test(reference, 1) -> is_reference;
rewrite_guard_test(tuple, 1) -> is_tuple;
rewrite_guard_test(record, 2) -> is_record;
rewrite_guard_test(N, _A) -> N.

reverse_guard_test(is_atom, 1) -> atom;
reverse_guard_test(is_binary, 1) -> binary;
reverse_guard_test(is_constant, 1) -> constant;
reverse_guard_test(is_float, 1) -> float;
reverse_guard_test(is_function, 1) -> function;
reverse_guard_test(is_integer, 1) -> integer;
reverse_guard_test(is_list, 1) -> list;
reverse_guard_test(is_number, 1) -> number;
reverse_guard_test(is_pid, 1) -> pid;
reverse_guard_test(is_port, 1) -> port;
reverse_guard_test(is_reference, 1) -> reference;
reverse_guard_test(is_tuple, 1) -> tuple;
reverse_guard_test(is_record, 2) -> record;
reverse_guard_test(N, _A) -> N.


%% =====================================================================
%% Utility functions

is_remote_name({M,F,A}) when atom(M), atom(F), integer(A) -> true;
is_remote_name(_) -> false.

is_atom_pair({M,F}) when atom(M), atom(F) -> true;
is_atom_pair(_) -> false.

replace_last([_E], Xs) ->
    Xs;
replace_last([E | Es], Xs) ->
    [E | replace_last(Es, Xs)].

is_generator(E) ->
    erl_syntax:type(E) == generator.

is_variable(E) ->
    erl_syntax:type(E) == variable.

new_variables(N, St0) when N > 0 ->
    {V, St1} = new_variable(St0),
    {Vs, St2} = new_variables(N - 1, St1),
    {[V | Vs], St2};
new_variables(0, St) ->
    {[], St}.

new_variable(St0) ->
    Fun = fun (N) ->
                  list_to_atom("V" ++ integer_to_list(N))
          end,
    Vs = St0#st.vars,
    {Name, N} = new_name(St0#st.varc, Fun, Vs),
    St1 = St0#st{varc = N + 1, vars = sets:add_element(Name, Vs)},
    {erl_syntax:variable(Name), St1}.

new_fname({F, A}, St0) ->
    Base = atom_to_list(F),
    Fun = fun (N) ->
                  {list_to_atom(Base ++ "_" ++ integer_to_list(N)), A}
          end,
    Fs = St0#st.functions,
    {{F1, _A} = Name, _N} = new_name(1, Fun, Fs),
    {F1, St0#st{functions = sets:add_element(Name, Fs)}}.

new_name(N, F, Set) ->
    Name = F(N),
    case sets:is_element(Name, Set) of
        true ->
            new_name(N + 1, F, Set);
        false ->
            {Name, N}
    end.

is_imported(F, Env) ->
    dict:is_key(F, Env#env.imports).

is_auto_imported({erlang, N, A}) ->
    is_auto_imported({N, A});
is_auto_imported({_, _N, _A}) ->
    false;
is_auto_imported({N, A}) ->
    erl_internal:bif(N, A).

is_nonlocal(N, Env) ->
    case is_imported(N, Env) of
        true ->
            true;
        false ->
            is_auto_imported(N)
    end.

get_var_exports(Node) ->
    get_var_exports_1(erl_syntax:get_ann(Node)).

get_var_exports_1([{bound, B} | _Bs]) -> B;
get_var_exports_1([_ | Bs]) -> get_var_exports_1(Bs);
get_var_exports_1([]) -> [].

get_free_vars(Node) ->
    get_free_vars_1(erl_syntax:get_ann(Node)).

get_free_vars_1([{free, B} | _Bs]) -> B;
get_free_vars_1([_ | Bs]) -> get_free_vars_1(Bs);
get_free_vars_1([]) -> [].

filename([C | T]) when integer(C), C > 0, C =< 255 ->
    [C | filename(T)];
filename([H|T]) ->
    filename(H) ++ filename(T);
filename([]) ->
    [];
filename(N) when atom(N) ->
    atom_to_list(N);
filename(N) ->
    report_error("bad filename: `~P'.", [N, 25]),
    exit(error).

get_env(Tree) ->
    case lists:keysearch(env, 1, erl_syntax:get_ann(Tree)) of
        {value, {env, Env}} ->
            Env;
        _ ->
            []
    end.

rewrite(Source, Target) ->
    erl_syntax:copy_attrs(Source, Target).

clone(Source, Target) ->
    erl_syntax:copy_pos(Source, Target).


%% =====================================================================
%% Reporting

report_export_vars(F, L, Type, Opts) ->
    report({F, L, "rewrote ~s-expression to export variables."},
	   [Type], Opts).

error_read_file(Name) ->
    report_error("error reading file `~s'.", [filename(Name)]).

error_write_file(Name) ->
    report_error("error writing to file `~s'.", [filename(Name)]).

error_backup_file(Name) ->
    report_error("could not create backup of file `~s'.",
                 [filename(Name)]).

error_open_output(Name) ->
    report_error("cannot open file `~s' for output.", [filename(Name)]).

verbosity(Opts) ->
    case proplists:get_bool(quiet, Opts) of 
        true -> 0;
        false ->
            case proplists:get_value(verbose, Opts) of
                true -> 2;
                N when integer(N) -> N; 
                _ -> 1
            end
    end.

report_error(D) ->
    report_error(D, []).
    
report_error({F, L, D}, Vs) ->
    report({F, L, {error, D}}, Vs);
report_error(D, Vs) ->
    report({error, D}, Vs).

% warn(D, N) ->
%     warn(D, [], N).

warn({F, L, D}, Vs, N) ->
    report({F, L, {warning, D}}, Vs, N);
warn(D, Vs, N) ->
    report({warning, D}, Vs, N).

recommend(D, Vs, N) ->
    report({recommend, D}, Vs, N).

verbose(D, Vs, N) ->
    report(2, D, Vs, N).

report(D, Vs) ->
    report(D, Vs, 1).

report(D, Vs, N) ->
    report(1, D, Vs, N).

report(Level, _D, _Vs, N) when integer(N), N < Level ->
    ok;
report(_Level, D, Vs, N) when integer(N) ->
    io:put_chars(format(D, Vs));
report(Level, D, Vs, Options) when list(Options) ->
    report(Level, D, Vs, verbosity(Options)).

format({error, D}, Vs) ->
    ["error: ", format(D, Vs)];
format({warning, D}, Vs) ->
    ["warning: ", format(D, Vs)];
format({recommend, D}, Vs) ->
    ["recommendation: ", format(D, Vs)];
format({"", L, D}, Vs) when integer(L), L > 0 ->
    [io_lib:fwrite("~w: ", [L]), format(D, Vs)];
format({"", _L, D}, Vs) ->
    format(D, Vs);
format({F, L, D}, Vs) when integer(L), L > 0 ->
    [io_lib:fwrite("~s:~w: ", [filename(F), L]), format(D, Vs)];
format({F, _L, D}, Vs) ->
    [io_lib:fwrite("~s: ", [filename(F)]), format(D, Vs)];
format(S, Vs) when list(S) ->
    [io_lib:fwrite(S, Vs), $\n].


%% =====================================================================
