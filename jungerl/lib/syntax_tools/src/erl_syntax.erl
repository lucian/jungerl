%% =====================================================================
%% Abstract Erlang syntax trees (`erl_parse'-compatible).
%%
%% Copyright (C) 1997-2004 Richard Carlsson
%%
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
%% Author contact: richardc@csd.uu.se
%%
%% $Id: erl_syntax.erl,v 1.3 2004/12/02 22:47:54 richcarl Exp $
%%
%% =====================================================================
%%
%% @doc Abstract Erlang syntax trees.
%%
%% <p> This module defines an abstract data type for representing Erlang
%% source code as syntax trees, in a way that is backwards compatible
%% with the data structures created by the Erlang standard library
%% parser module <code>erl_parse</code> (often referred to as "parse
%% trees", which is a bit of a misnomer). This means that all
%% <code>erl_parse</code> trees are valid abstract syntax trees, but the
%% reverse is not true: abstract syntax trees can in general not be used
%% as input to functions expecting an <code>erl_parse</code> tree.
%% However, as long as an abstract syntax tree represents a correct
%% Erlang program, the function <a
%% href="#revert-1"><code>revert/1</code></a> should be able to
%% transform it to the corresponding <code>erl_parse</code>
%% representation.</p>
%%
%% <p>A recommended starting point for the first-time user is the
%% documentation of the <a
%% href="#type-syntaxTree"><code>syntaxTree()</code></a> data type, and
%% the function <a href="#type-1"><code>type/1</code></a>.</p>
%%
%% <h3><b>NOTES:</b></h3>
%%
%% <p>This module deals with the composition and decomposition of
%% <em>syntactic</em> entities (as opposed to semantic ones); its
%% purpose is to hide all direct references to the data structures used
%% to represent these entities. With few exceptions, the functions in
%% this module perform no semantic interpretation of their inputs, and
%% in general, the user is assumed to pass type-correct arguments - if
%% this is not done, the effects are not defined.</p>
%%
%% <p>With the exception of the <code>erl_parse</code> data structures,
%% the internal representations of abstract syntax trees are subject to
%% change without notice, and should not be documented outside this
%% module. Furthermore, we do not give any guarantees on how an abstract
%% syntax tree may or may not be represented, <em>with the following
%% exceptions</em>: no syntax tree is represented by a single atom, such
%% as <code>none</code>, by a list constructor <code>[X | Y]</code>, or
%% by the empty list <code>[]</code>. This can be relied on when writing
%% functions that operate on syntax trees.</p>
%%
%% @type syntaxTree(). An abstract syntax tree. The
%% <code>erl_parse</code> "parse tree" representation is a subset of the
%% <code>syntaxTree()</code> representation.
%%
%% <p>Every abstract syntax tree node has a <em>type</em>, given by the
%% function <a href="#type-1"><code>type/1</code></a>. Each node also
%% has associated <em>attributes</em>; see <a
%% href="#get_attrs-1"><code>get_attrs/1</code></a> for details. The
%% functions <a href="#make_tree-2"><code>make_tree/2</code></a> and <a
%% href="#subtrees-1"><code>subtrees/1</code></a> are generic
%% constructor/decomposition functions for abstract syntax trees. The
%% functions <a href="#abstract-1"><code>abstract/1</code></a> and <a
%% href="#concrete-1"><code>concrete/1</code></a> convert between
%% constant Erlang terms and their syntactic representations. The set of
%% syntax tree nodes is extensible through the <a
%% href="#tree-2"><code>tree/2</code></a> function.</p>
%%
%% <p>A syntax tree can be transformed to the <code>erl_parse</code>
%% representation with the <a href="#revert-1"><code>revert/1</code></a>
%% function.</p>
%% 
%% @end
%% =====================================================================

-module(erl_syntax).

-export([type/1,
	 is_leaf/1,
	 is_form/1,
	 is_literal/1,
	 abstract/1,
	 concrete/1,
	 revert/1,
	 revert_forms/1,
	 subtrees/1,
	 make_tree/2,
	 update_tree/2,
	 meta/1,

	 get_pos/1,
	 set_pos/2,
	 copy_pos/2,
	 get_precomments/1,
	 set_precomments/2,
	 add_precomments/2,
	 get_postcomments/1,
	 set_postcomments/2,
	 add_postcomments/2,
	 has_comments/1,
	 remove_comments/1,
	 copy_comments/2,
	 join_comments/2,
	 get_ann/1,
	 set_ann/2,
	 add_ann/2,
	 copy_ann/2,
	 get_attrs/1,
	 set_attrs/2,
	 copy_attrs/2,

	 flatten_form_list/1,
	 cons/2,
	 list_head/1,
	 list_tail/1,
	 is_list_skeleton/1,
	 is_proper_list/1,
	 list_elements/1,
	 list_length/1,
	 normalize_list/1,
	 compact_list/1,

	 application/2,
	 application/3,
	 application_arguments/1,
	 application_operator/1,
	 arity_qualifier/2,
	 arity_qualifier_argument/1,
	 arity_qualifier_body/1,
	 atom/1,
	 is_atom/2,
	 atom_value/1,
	 atom_literal/1,
	 atom_name/1,
	 attribute/1,
	 attribute/2,
	 attribute_arguments/1,
	 attribute_name/1,
	 binary/1,
	 binary_field/1,
	 binary_field/2,
	 binary_field/3,
	 binary_field_body/1,
	 binary_field_types/1,
	 binary_field_size/1,
	 binary_fields/1,
	 block_expr/1,
	 block_expr_body/1,
	 case_expr/2,
	 case_expr_argument/1,
	 case_expr_clauses/1,
	 catch_expr/1,
	 catch_expr_body/1,
	 char/1,
	 is_char/2,
	 char_value/1,
	 char_literal/1,
	 clause/2,
	 clause/3,
	 clause_body/1,
	 clause_guard/1,
	 clause_patterns/1,
	 comment/1,
	 comment/2,
	 comment_padding/1,
	 comment_text/1,
	 cond_expr/1,
	 cond_expr_clauses/1,
	 conjunction/1,
	 conjunction_body/1,
	 disjunction/1,
	 disjunction_body/1,
	 eof_marker/0,
	 error_marker/1,
	 error_marker_info/1,
	 float/1,
	 float_value/1,
	 float_literal/1,
	 form_list/1,
	 form_list_elements/1,
	 fun_expr/1,
	 fun_expr_arity/1,
	 fun_expr_clauses/1,
	 function/2,
	 function_arity/1,
	 function_clauses/1,
	 function_name/1,
	 generator/2,
	 generator_body/1,
	 generator_pattern/1,
	 if_expr/1,
	 if_expr_clauses/1,
	 implicit_fun/1,
	 implicit_fun/2,
	 implicit_fun_name/1,
	 infix_expr/3,
	 infix_expr_left/1,
	 infix_expr_operator/1,
	 infix_expr_right/1,
	 integer/1,
	 is_integer/2,
	 integer_value/1,
	 integer_literal/1,
	 list/1,
	 list/2,
	 list_comp/2,
	 list_comp_body/1,
	 list_comp_template/1,
	 list_prefix/1,
	 list_suffix/1,
	 macro/1,
	 macro/2,
	 macro_arguments/1,
	 macro_name/1,
	 match_expr/2,
	 match_expr_body/1,
	 match_expr_pattern/1,
	 module_qualifier/2,
	 module_qualifier_argument/1,
	 module_qualifier_body/1,
	 nil/0,
	 operator/1,
	 operator_literal/1,
	 operator_name/1,
	 parentheses/1,
	 parentheses_body/1,
	 prefix_expr/2,
	 prefix_expr_argument/1,
	 prefix_expr_operator/1,
	 qualified_name/1,
	 qualified_name_segments/1,
	 query_expr/1,
	 query_expr_body/1,
	 receive_expr/1,
	 receive_expr/3,
	 receive_expr_action/1,
	 receive_expr_clauses/1,
	 receive_expr_timeout/1,
	 record_access/2,
	 record_access/3,
	 record_access_argument/1,
	 record_access_field/1,
	 record_access_type/1,
	 record_expr/2,
	 record_expr/3,
	 record_expr_argument/1,
	 record_expr_fields/1,
	 record_expr_type/1,
	 record_field/1,
	 record_field/2,
	 record_field_name/1,
	 record_field_value/1,
	 record_index_expr/2,
	 record_index_expr_field/1,
	 record_index_expr_type/1,
	 rule/2,
	 rule_arity/1,
	 rule_clauses/1,
	 rule_name/1,
	 size_qualifier/2,
	 size_qualifier_argument/1,
	 size_qualifier_body/1,
	 string/1,
	 is_string/2,
	 string_value/1,
	 string_literal/1,
	 text/1,
	 text_string/1,
	 try_expr/2,
	 try_expr/3,
	 try_expr/4,
	 try_after_expr/2,
	 try_expr_body/1,
	 try_expr_clauses/1,
	 try_expr_handlers/1,
	 try_expr_after/1,
	 class_qualifier/2,
	 class_qualifier_argument/1,
	 class_qualifier_body/1,
	 tuple/1,
	 tuple_elements/1,
	 tuple_size/1,
	 underscore/0,
	 variable/1,
	 variable_name/1,
	 variable_literal/1,
	 warning_marker/1,
	 warning_marker_info/1,

	 tree/1,
	 tree/2,
	 data/1,
	 is_tree/1]).


%% =====================================================================
%% IMPLEMENTATION NOTES:
%%
%% All nodes are represented by tuples of arity 2 or greater, whose
%% first element is an atom which uniquely identifies the type of the
%% node. (In the backwards-compatible representation, the interpretation
%% is also often dependent on the context; the second element generally
%% holds the position information - with a couple of exceptions; see
%% `get_pos' and `set_pos' for details). In the documentation of this
%% module, `Pos' is the source code position information associated with
%% a node; usually, this is a positive integer indicating the original
%% source code line, but no assumptions are made in this module
%% regarding the format or interpretation of position information. When
%% a syntax tree node is constructed, its associated position is by
%% default set to the integer zero.
%% =====================================================================

-define(NO_UNUSED, true).

%% =====================================================================
%% Declarations of globally used internal data structures
%% =====================================================================

%% `com' records are used to hold comment information attached to a
%% syntax tree node or a wrapper structure.
%%
%% #com{pre :: Pre, post :: Post}
%%
%%	Pre = Post = [Com]
%%	Com = syntaxTree()
%%
%%	type(Com) = comment

-record(com, {pre = [],
	      post = []}).

%% `attr' records store node attributes as an aggregate.
%%
%% #attr{pos :: Pos, ann :: Ann, com :: Comments}
%%
%%	Pos = term()
%%	Ann = [term()]
%%	Comments = none | #com{}
%%
%% where `Pos' `Ann' and `Comments' are the corresponding values of a
%% `tree' or `wrapper' record.

-record(attr, {pos = 0,
	       ann = [],
	       com = none}).

%% `tree' records represent new-form syntax tree nodes.
%%
%% Tree = #tree{type :: Type, attr :: Attr, data :: Data}
%%
%%	Type = atom()
%%	Attr = #attr{}
%%	Data = term()
%%
%%	is_tree(Tree) = true

-record(tree, {type,
	       attr = #attr{},
	       data}).

%% `wrapper' records are used for attaching new-form node information to
%% `erl_parse' trees.
%%
%% Wrapper = #wrapper{type :: Type, attr :: Attr, tree :: ParseTree}
%%
%%	Type = atom()
%%	Attr = #attr{}
%%	ParseTree = term()
%%
%%	is_tree(Wrapper) = false

-record(wrapper, {type,
		  attr = #attr{},
		  tree}).


%% =====================================================================
%%
%%			Exported functions
%%
%% =====================================================================


%% =====================================================================
%% @spec type(Node::syntaxTree()) -> atom()
%%
%% @doc Returns the type tag of <code>Node</code>. If <code>Node</code>
%% does not represent a syntax tree, evaluation fails with reason
%% <code>badarg</code>. Node types currently defined by this module are:
%% <p><center><table border="1">
%%  <tr>
%%   <td>application</td>
%%   <td>arity_qualifier</td>
%%   <td>atom</td>
%%   <td>attribute</td>
%%  </tr><tr>
%%   <td>binary</td>
%%   <td>binary_field</td>
%%   <td>block_expr</td>
%%   <td>case_expr</td>
%%  </tr><tr>
%%   <td>catch_expr</td>
%%   <td>char</td>
%%   <td>class_qualifier</td>
%%   <td>clause</td>
%%  </tr><tr>
%%   <td>comment</td>
%%   <td>cond_expr</td>
%%   <td>conjunction</td>
%%   <td>disjunction</td>
%%  </tr><tr>
%%   <td>eof_marker</td>
%%   <td>error_marker</td>
%%   <td>float</td>
%%   <td>form_list</td>
%%  </tr><tr>
%%   <td>fun_expr</td>
%%   <td>function</td>
%%   <td>generator</td>
%%   <td>if_expr</td>
%%  </tr><tr>
%%   <td>implicit_fun</td>
%%   <td>infix_expr</td>
%%   <td>integer</td>
%%   <td>list</td>
%%  </tr><tr>
%%   <td>list_comp</td>
%%   <td>macro</td>
%%   <td>match_expr</td>
%%   <td>module_qualifier</td>
%%  </tr><tr>
%%   <td>nil</td>
%%   <td>operator</td>
%%   <td>parentheses</td>
%%   <td>prefix_expr</td>
%%  </tr><tr>
%%   <td>qualified_name</td>
%%   <td>query_expr</td>
%%   <td>receive_expr</td>
%%   <td>record_access</td>
%%  </tr><tr>
%%   <td>record_expr</td>
%%   <td>record_field</td>
%%   <td>record_index_expr</td>
%%   <td>rule</td>
%%  </tr><tr>
%%   <td>size_qualifier</td>
%%   <td>string</td>
%%   <td>text</td>
%%   <td>try_expr</td>
%%  </tr><tr>
%%   <td>tuple</td>
%%   <td>underscore</td>
%%   <td>variable</td>
%%   <td>warning_marker</td>
%%  </tr>
%% </table></center></p>
%% <p>The user may (for special purposes) create additional nodes
%% with other type tags, using the <code>tree/2</code> function.</p>
%%
%% <p>Note: The primary constructor functions for a node type should
%% always have the same name as the node type itself.</p>
%%
%% @see tree/2
%% @see application/3
%% @see arity_qualifier/2
%% @see atom/1
%% @see attribute/2
%% @see binary/1
%% @see binary_field/2
%% @see block_expr/1
%% @see case_expr/2
%% @see catch_expr/1
%% @see char/1
%% @see class_qualifier/2
%% @see clause/3
%% @see comment/2
%% @see cond_expr/1
%% @see conjunction/1
%% @see disjunction/1
%% @see eof_marker/0
%% @see error_marker/1
%% @see float/1
%% @see form_list/1
%% @see fun_expr/1
%% @see function/2
%% @see generator/2
%% @see if_expr/1
%% @see implicit_fun/2
%% @see infix_expr/3
%% @see integer/1
%% @see list/2
%% @see list_comp/2
%% @see macro/2
%% @see match_expr/2
%% @see module_qualifier/2
%% @see nil/0
%% @see operator/1
%% @see parentheses/1
%% @see prefix_expr/2
%% @see qualified_name/1
%% @see query_expr/1
%% @see receive_expr/3
%% @see record_access/3
%% @see record_expr/2
%% @see record_field/2
%% @see record_index_expr/2
%% @see rule/2
%% @see size_qualifier/2
%% @see string/1
%% @see text/1
%% @see try_expr/3
%% @see tuple/1
%% @see underscore/0
%% @see variable/1
%% @see warning_marker/1

type(#tree{type = T}) ->
    T;
type(#wrapper{type = T}) ->
    T;
type(Node) ->
    %% Check for `erl_parse'-compatible nodes, and otherwise fail.
    case Node of
	%% Leaf types
	{atom, _, _} -> atom;
	{char, _, _} -> char;
	{float, _, _} -> float;
	{integer, _, _} -> integer;
	{nil, _} -> nil;
	{string, _, _} -> string;
	{var, _, Name} ->
	    if Name == '_' -> underscore;
	       true -> variable
	    end;
	{error, _} -> error_marker;
	{warning, _} -> warning_marker;
	{eof, _} -> eof_marker;

	%% Composite types
	{'case', _, _, _} -> case_expr;
	{'catch', _, _} -> catch_expr;
	{'cond', _, _} -> cond_expr;
	{'fun', _, {clauses, _}} -> fun_expr;
	{'fun', _, {function, _, _}} -> implicit_fun;
	{'if', _, _} -> if_expr;
	{'receive', _, _, _, _} -> receive_expr;
	{'receive', _, _} -> receive_expr;
	{attribute, _, _, _} -> attribute;
	{bin, _, _} -> binary;
	{bin_element, _, _, _, _} -> binary_field;
	{block, _, _} -> block_expr;
	{call, _, _, _} -> application;
	{clause, _, _, _, _} -> clause;
	{cons, _, _, _} -> list;
	{function, _, _, _, _} -> function;
	{generate, _, _, _} -> generator;
	{lc, _, _, _} -> list_comp;
	{match, _, _, _} -> match_expr;
	{op, _, _, _, _} -> infix_expr;
	{op, _, _, _} -> prefix_expr;
	{'query', _, _} -> query_expr;
	{record, _, _, _, _} -> record_expr;
	{record, _, _, _} -> record_expr;
	{record_field, _, _, _, _} -> record_access;
	{record_field, _, _, _} ->
	    case is_qualified_name(Node) of
		true -> qualified_name;
		false -> record_access
	    end;
	{record_index, _, _, _} -> record_index_expr;
	{remote, _, _, _} -> module_qualifier;
	{rule, _, _, _, _} -> rule;
	{'try', _, _, _, _, _} -> try_expr;
	{tuple, _, _} -> tuple;
	_ ->
	    erlang:fault({badarg, Node})
    end.


%% =====================================================================
%% @spec is_leaf(Node::syntaxTree()) -> bool()
%%
%% @doc Returns <code>true</code> if <code>Node</code> is a leaf node,
%% otherwise <code>false</code>. The currently recognised leaf node
%% types are:
%% <p><center><table border="1">
%%  <tr>
%%   <td><code>atom</code></td>
%%   <td><code>char</code></td>
%%   <td><code>comment</code></td>
%%   <td><code>eof_marker</code></td>
%%   <td><code>error_marker</code></td>
%%  </tr><tr>
%%   <td><code>float</code></td>
%%   <td><code>integer</code></td>
%%   <td><code>nil</code></td>
%%   <td><code>operator</code></td>
%%   <td><code>string</code></td>
%%  </tr><tr>
%%   <td><code>text</code></td>
%%   <td><code>underscore</code></td>
%%   <td><code>variable</code></td>
%%   <td><code>warning_marker</code></td>
%%  </tr>
%% </table></center></p>
%% <p>A node of type <code>tuple</code> is a leaf node if and only if
%% its arity is zero.</p>
%%
%% <p>Note: not all literals are leaf nodes, and vice versa. E.g.,
%% tuples with nonzero arity and nonempty lists may be literals, but are
%% not leaf nodes. Variables, on the other hand, are leaf nodes but not
%% literals.</p>
%% 
%% @see type/1
%% @see is_literal/1

is_leaf(Node) ->
    case type(Node) of
	atom -> true;
	char -> true;
	comment -> true;	% nonstandard type
	eof_marker -> true;
	error_marker -> true;
	float -> true;
	integer -> true;
	nil -> true;
	operator -> true;	% nonstandard type
	string -> true;
	text -> true;		% nonstandard type
	tuple ->
	    case tuple_elements(Node) of
		[] -> true;
		_ -> false
	    end;
	underscore -> true;
	variable -> true;
	warning_marker -> true;
	_ -> false
    end.


%% =====================================================================
%% @spec is_form(Node::syntaxTree()) -> bool()
%%
%% @doc Returns <code>true</code> if <code>Node</code> is a syntax tree
%% representing a so-called "source code form", otherwise
%% <code>false</code>. Forms are the Erlang source code units which,
%% placed in sequence, constitute an Erlang program. Current form types
%% are:
%% <p><center><table border="1">
%%  <tr>
%%   <td><code>attribute</code></td>
%%   <td><code>comment</code></td>
%%   <td><code>error_marker</code></td>
%%   <td><code>eof_marker</code></td>
%%  </tr><tr>
%%   <td><code>form_list</code></td>
%%   <td><code>function</code></td>
%%   <td><code>rule</code></td>
%%   <td><code>warning_marker</code></td>
%%  </tr>
%% </table></center></p>
%% @see type/1
%% @see attribute/2 
%% @see comment/2
%% @see eof_marker/1
%% @see error_marker/1
%% @see form_list/1
%% @see function/2
%% @see rule/2
%% @see warning_marker/1

is_form(Node) ->
    case type(Node) of
	attribute -> true;
	comment -> true;
	function -> true;
	eof_marker -> true;
	error_marker -> true;
	form_list -> true;
	rule -> true;
	warning_marker -> true;
	_ -> false
    end.


%% =====================================================================
%% @spec get_pos(Node::syntaxTree()) -> term()
%%
%% @doc Returns the position information associated with
%% <code>Node</code>. This is usually a nonnegative integer (indicating
%% the source code line number), but may be any term. By default, all
%% new tree nodes have their associated position information set to the
%% integer zero.
%%
%% @see set_pos/2
%% @see get_attrs/1

%% All `erl_parse' tree nodes are represented by tuples whose second
%% field is the position information (usually an integer), *with the
%% exceptions of* `{error, ...}' (type `error_marker') and `{warning,
%% ...}' (type `warning_marker'), which only contain the associated line
%% number *of the error descriptor*; this is all handled transparently
%% by `get_pos' and `set_pos'.

get_pos(#tree{attr = Attr}) ->
    Attr#attr.pos;
get_pos(#wrapper{attr = Attr}) ->
    Attr#attr.pos;
get_pos({error, {Pos, _, _}}) ->
    Pos;
get_pos({warning, {Pos, _, _}}) ->
    Pos;
get_pos(Node) ->
    %% Here, we assume that we have an `erl_parse' node with position
    %% information in element 2.
    element(2, Node).


%% =====================================================================
%% @spec set_pos(Node::syntaxTree(), Pos::term()) -> syntaxTree()
%%
%% @doc Sets the position information of <code>Node</code> to
%% <code>Pos</code>.
%%
%% @see get_pos/1
%% @see copy_pos/2

set_pos(Node, Pos) ->
    case Node of
	#tree{attr = Attr} ->
	    Node#tree{attr = Attr#attr{pos = Pos}};
	#wrapper{attr = Attr} ->
	    Node#wrapper{attr = Attr#attr{pos = Pos}};
	_ ->
	    %% We then assume we have an `erl_parse' node, and create a
	    %% wrapper around it to make things more uniform.
	    set_pos(wrap(Node), Pos)
    end.


%% =====================================================================
%% @spec copy_pos(Source::syntaxTree(), Target::syntaxTree()) ->
%%           syntaxTree()
%%
%% @doc Copies the position information from <code>Source</code> to
%% <code>Target</code>.
%%
%% <p>This is equivalent to <code>set_pos(Target,
%% get_pos(Source))</code>, but potentially more efficient.</p>
%%
%% @see get_pos/1
%% @see set_pos/2

copy_pos(Source, Target) ->
    set_pos(Target, get_pos(Source)).


%% =====================================================================
%% `get_com' and `set_com' are for internal use only.

get_com(#tree{attr = Attr}) -> Attr#attr.com;
get_com(#wrapper{attr = Attr}) -> Attr#attr.com;
get_com(_) -> none.

set_com(Node, Com) ->
    case Node of
	#tree{attr = Attr} ->
	    Node#tree{attr = Attr#attr{com = Com}};
	#wrapper{attr = Attr} ->
	    Node#wrapper{attr = Attr#attr{com = Com}};
	_ ->
	    set_com(wrap(Node), Com)
    end.


%% =====================================================================
%% @spec get_precomments(syntaxTree()) -> [syntaxTree()]
%%
%% @doc Returns the associated pre-comments of a node. This is a
%% possibly empty list of abstract comments, in top-down textual order.
%% When the code is formatted, pre-comments are typically displayed
%% directly above the node. For example:
%% <pre>
%%         % Pre-comment of function
%%         foo(X) -> {bar, X}.</pre>
%%
%% <p>If possible, the comment should be moved before any preceding
%% separator characters on the same line. E.g.:
%% <pre>
%%         foo([X | Xs]) ->
%%             % Pre-comment of 'bar(X)' node
%%             [bar(X) | foo(Xs)];
%%         ...</pre>
%% (where the comment is moved before the "<code>[</code>").</p>
%%
%% @see comment/2
%% @see set_precomments/2
%% @see get_postcomments/1
%% @see get_attrs/1

get_precomments(#tree{attr = Attr}) -> get_precomments_1(Attr);
get_precomments(#wrapper{attr = Attr}) -> get_precomments_1(Attr);
get_precomments(_) -> [].

get_precomments_1(#attr{com = none}) -> [];
get_precomments_1(#attr{com = #com{pre = Cs}}) -> Cs.


%% =====================================================================
%% @spec set_precomments(Node::syntaxTree(),
%%                       Comments::[syntaxTree()]) -> syntaxTree()
%%
%% @doc Sets the pre-comments of <code>Node</code> to
%% <code>Comments</code>. <code>Comments</code> should be a possibly
%% empty list of abstract comments, in top-down textual order.
%%
%% @see comment/2
%% @see get_precomments/1
%% @see add_precomments/2
%% @see set_postcomments/2
%% @see copy_comments/2
%% @see remove_comments/1
%% @see join_comments/2

set_precomments(Node, Cs) ->
    case Node of
	#tree{attr = Attr} ->
	    Node#tree{attr = set_precomments_1(Attr, Cs)};
	#wrapper{attr = Attr} ->
	    Node#wrapper{attr = set_precomments_1(Attr, Cs)};
	_ ->
	    set_precomments(wrap(Node), Cs)
    end.

set_precomments_1(#attr{com = none} = Attr, Cs) ->
    Attr#attr{com = #com{pre = Cs}};
set_precomments_1(#attr{com = Com} = Attr, Cs) ->
    Attr#attr{com = Com#com{pre = Cs}}.


%% =====================================================================
%% @spec add_precomments(Comments::[syntaxTree()],
%%                       Node::syntaxTree()) -> syntaxTree()
%%
%% @doc Appends <code>Comments</code> to the pre-comments of
%% <code>Node</code>.
%%
%% <p>Note: This is equivalent to <code>set_precomments(Node,
%% get_precomments(Node) ++ Comments)</code>, but potentially more
%% efficient.</p>
%%
%% @see comment/2
%% @see get_precomments/1
%% @see set_precomments/2
%% @see add_postcomments/2
%% @see join_comments/2

add_precomments(Cs, Node) ->
    case Node of
	#tree{attr = Attr} ->
	    Node#tree{attr = add_precomments_1(Cs, Attr)};
	#wrapper{attr = Attr} ->
	    Node#wrapper{attr = add_precomments_1(Cs, Attr)};
	_ ->
	    add_precomments(Cs, wrap(Node))
    end.

add_precomments_1(Cs, #attr{com = none} = Attr) ->
    Attr#attr{com = #com{pre = Cs}};
add_precomments_1(Cs, #attr{com = Com} = Attr) ->
    Attr#attr{com = Com#com{pre = Com#com.pre ++ Cs}}.


%% =====================================================================
%% @spec get_postcomments(syntaxTree()) -> [syntaxTree()]
%%
%% @doc Returns the associated post-comments of a node. This is a
%% possibly empty list of abstract comments, in top-down textual order.
%% When the code is formatted, post-comments are typically displayed to
%% the right of and/or below the node. For example:
%% <pre>
%%         {foo, X, Y}     % Post-comment of tuple</pre>
%%
%% <p>If possible, the comment should be moved past any following
%% separator characters on the same line, rather than placing the
%% separators on the following line. E.g.:
%% <pre>
%%         foo([X | Xs], Y) ->
%%             foo(Xs, bar(X));     % Post-comment of 'bar(X)' node
%%          ...</pre>
%% (where the comment is moved past the rightmost "<code>)</code>" and
%% the "<code>;</code>").</p>
%%
%% @see comment/2
%% @see set_postcomments/2
%% @see get_precomments/1
%% @see get_attrs/1

get_postcomments(#tree{attr = Attr}) -> get_postcomments_1(Attr);
get_postcomments(#wrapper{attr = Attr}) -> get_postcomments_1(Attr);
get_postcomments(_) -> [].

get_postcomments_1(#attr{com = none}) -> [];
get_postcomments_1(#attr{com = #com{post = Cs}}) -> Cs.


%% =====================================================================
%% @spec set_postcomments(Node::syntaxTree(),
%%                        Comments::[syntaxTree()]) -> syntaxTree()
%%
%% @doc Sets the post-comments of <code>Node</code> to
%% <code>Comments</code>. <code>Comments</code> should be a possibly
%% empty list of abstract comments, in top-down textual order
%%
%% @see comment/2
%% @see get_postcomments/1
%% @see add_postcomments/2
%% @see set_precomments/2
%% @see copy_comments/2
%% @see remove_comments/1
%% @see join_comments/2

set_postcomments(Node, Cs) ->
    case Node of
	#tree{attr = Attr} ->
	    Node#tree{attr = set_postcomments_1(Attr, Cs)};
	#wrapper{attr = Attr} ->
	    Node#wrapper{attr = set_postcomments_1(Attr, Cs)};
	_ ->
	    set_postcomments(wrap(Node), Cs)
    end.

set_postcomments_1(#attr{com = none} = Attr, Cs) ->
    Attr#attr{com = #com{post = Cs}};
set_postcomments_1(#attr{com = Com} = Attr, Cs) ->
    Attr#attr{com = Com#com{post = Cs}}.


%% =====================================================================
%% @spec add_postcomments(Comments::[syntaxTree()],
%%                        Node::syntaxTree()) -> syntaxTree()
%%
%% @doc Appends <code>Comments</code> to the post-comments of
%% <code>Node</code>.
%%
%% <p>Note: This is equivalent to <code>set_postcomments(Node,
%% get_postcomments(Node) ++ Comments)</code>, but potentially more
%% efficient.</p>
%%
%% @see comment/2
%% @see get_postcomments/1
%% @see set_postcomments/2
%% @see add_precomments/2
%% @see join_comments/2

add_postcomments(Cs, Node) ->
    case Node of
	#tree{attr = Attr} ->
	    Node#tree{attr = add_postcomments_1(Cs, Attr)};
	#wrapper{attr = Attr} ->
	    Node#wrapper{attr = add_postcomments_1(Cs, Attr)};
	_ ->
	    add_postcomments(Cs, wrap(Node))
    end.

add_postcomments_1(Cs, #attr{com = none} = Attr) ->
    Attr#attr{com = #com{post = Cs}};
add_postcomments_1(Cs, #attr{com = Com} = Attr) ->
    Attr#attr{com = Com#com{post = Com#com.post ++ Cs}}.


%% =====================================================================
%% @spec has_comments(Node::syntaxTree()) -> bool()
%%
%% @doc Yields <code>false</code> if the node has no associated
%% comments, and <code>true</code> otherwise.
%%
%% <p>Note: This is equivalent to <code>(get_precomments(Node) == [])
%% and (get_postcomments(Node) == [])</code>, but potentially more
%% efficient.</p>
%%
%% @see get_precomments/1
%% @see get_postcomments/1
%% @see remove_comments/1

has_comments(#tree{attr = Attr}) ->
    case Attr#attr.com of
	none -> false;
	#com{pre = [], post = []} -> false;
	_ -> true
    end;
has_comments(#wrapper{attr = Attr}) ->
    case Attr#attr.com of
	none -> false;
	#com{pre = [], post = []} -> false;
	_ -> true
    end;
has_comments(_) -> false.


%% =====================================================================
%% @spec remove_comments(Node::syntaxTree()) -> syntaxTree()
%%
%% @doc Clears the associated comments of <code>Node</code>.
%%
%% <p>Note: This is equivalent to
%% <code>set_precomments(set_postcomments(Node, []), [])</code>, but
%% potentially more efficient.</p>
%%
%% @see set_precomments/2
%% @see set_postcomments/2

remove_comments(Node) ->
    case Node of
	#tree{attr = Attr} ->
	    Node#tree{attr = Attr#attr{com = none}};
	#wrapper{attr = Attr} ->
	    Node#wrapper{attr = Attr#attr{com = none}};
	_ ->
	    Node
    end.


%% =====================================================================
%% @spec copy_comments(Source::syntaxTree(), Target::syntaxTree()) ->
%%           syntaxTree()
%%
%% @doc Copies the pre- and postcomments from <code>Source</code> to
%% <code>Target</code>.
%%
%% <p>Note: This is equivalent to
%% <code>set_postcomments(set_precomments(Target,
%% get_precomments(Source)), get_postcomments(Source))</code>, but
%% potentially more efficient.</p>
%%
%% @see comment/2
%% @see get_precomments/1
%% @see get_postcomments/1
%% @see set_precomments/2
%% @see set_postcomments/2

copy_comments(Source, Target) ->
    set_com(Target, get_com(Source)).


%% =====================================================================
%% @spec join_comments(Source::syntaxTree(), Target::syntaxTree()) ->
%%           syntaxTree()
%%
%% @doc Appends the comments of <code>Source</code> to the current
%% comments of <code>Target</code>.
%%
%% <p>Note: This is equivalent to
%% <code>add_postcomments(get_postcomments(Source),
%% add_precomments(get_precomments(Source), Target))</code>, but
%% potentially more efficient.</p>
%%
%% @see comment/2
%% @see get_precomments/1
%% @see get_postcomments/1
%% @see add_precomments/2
%% @see add_postcomments/2

join_comments(Source, Target) ->
    add_postcomments(
      get_postcomments(Source),
      add_precomments(get_precomments(Source), Target)).


%% =====================================================================
%% @spec get_ann(syntaxTree()) -> [term()]
%%
%% @doc Returns the list of user annotations associated with a syntax
%% tree node. For a newly created node, this is the empty list. The
%% annotations may be any terms.
%%
%% @see set_ann/2
%% @see get_attrs/1

get_ann(#tree{attr = Attr}) -> Attr#attr.ann;
get_ann(#wrapper{attr = Attr}) -> Attr#attr.ann;
get_ann(_) -> [].


%% =====================================================================
%% @spec set_ann(Node::syntaxTree(), Annotations::[term()]) ->
%%           syntaxTree()
%%
%% @doc Sets the list of user annotations of <code>Node</code> to
%% <code>Annotations</code>.
%%
%% @see get_ann/1
%% @see add_ann/2
%% @see copy_ann/2

set_ann(Node, As) ->
    case Node of
	#tree{attr = Attr} ->
	    Node#tree{attr = Attr#attr{ann = As}};
	#wrapper{attr = Attr} ->
	    Node#wrapper{attr = Attr#attr{ann = As}};
	_ ->
	    %% Assume we have an `erl_parse' node and create a wrapper
	    %% structure to carry the annotation.
	    set_ann(wrap(Node), As)
    end.


%% =====================================================================
%% @spec add_ann(Annotation::term(), Node::syntaxTree()) -> syntaxTree()
%%
%% @doc Appends the term <code>Annotation</code> to the list of user
%% annotations of <code>Node</code>.
%%
%% <p>Note: this is equivalent to <code>set_ann(Node, [Annotation |
%% get_ann(Node)])</code>, but potentially more efficient.</p>
%%
%% @see get_ann/1
%% @see set_ann/2

add_ann(A, Node) ->
    case Node of
	#tree{attr = Attr} ->
	    Node#tree{attr = Attr#attr{ann = [A | Attr#attr.ann]}};
	#wrapper{attr = Attr} ->
	    Node#wrapper{attr = Attr#attr{ann = [A | Attr#attr.ann]}};
	_ ->
	    %% Assume we have an `erl_parse' node and create a wrapper
	    %% structure to carry the annotation.
	    add_ann(A, wrap(Node))
    end.


%% =====================================================================
%% @spec copy_ann(Source::syntaxTree(), Target::syntaxTree()) ->
%%           syntaxTree()
%%
%% @doc Copies the list of user annotations from <code>Source</code> to
%% <code>Target</code>.
%%
%% <p>Note: this is equivalent to <code>set_ann(Target,
%% get_ann(Source))</code>, but potentially more efficient.</p>
%%
%% @see get_ann/1
%% @see set_ann/2

copy_ann(Source, Target) ->
    set_ann(Target, get_ann(Source)).


%% =====================================================================
%% @spec get_attrs(syntaxTree()) -> syntaxTreeAttributes()
%%
%% @doc Returns a representation of the attributes associated with a
%% syntax tree node. The attributes are all the extra information that
%% can be attached to a node. Currently, this includes position
%% information, source code comments, and user annotations. The result
%% of this function cannot be inspected directly; only attached to
%% another node (cf. <code>set_attrs/2</code>).
%%
%% <p>For accessing individual attributes, see <code>get_pos/1</code>,
%% <code>get_ann/1</code>, <code>get_precomments/1</code> and
%% <code>get_postcomments/1</code>.</p>
%%
%% @type syntaxTreeAttributes(). This is an abstract representation of
%% syntax tree node attributes; see the function <a
%% href="#get_attrs-1"><code>get_attrs/1</code></a>.
%% 
%% @see set_attrs/2
%% @see get_pos/1
%% @see get_ann/1
%% @see get_precomments/1
%% @see get_postcomments/1

get_attrs(#tree{attr = Attr}) -> Attr;
get_attrs(#wrapper{attr = Attr}) -> Attr;
get_attrs(Node) -> #attr{pos = get_pos(Node),
			 ann = get_ann(Node),
			 com = get_com(Node)}.


%% =====================================================================
%% @spec set_attrs(Node::syntaxTree(),
%%                 Attributes::syntaxTreeAttributes()) -> syntaxTree()
%%
%% @doc Sets the attributes of <code>Node</code> to
%% <code>Attributes</code>.
%%
%% @see get_attrs/1
%% @see copy_attrs/2

set_attrs(Node, Attr) ->
    case Node of
	#tree{} ->
	    Node#tree{attr = Attr};
	#wrapper{} ->
	    Node#wrapper{attr = Attr};
	_ ->
	    set_attrs(wrap(Node), Attr)
    end.


%% =====================================================================
%% @spec copy_attrs(Source::syntaxTree(), Target::syntaxTree()) ->
%%           syntaxTree()
%%
%% @doc Copies the attributes from <code>Source</code> to
%% <code>Target</code>.
%%
%% <p>Note: this is equivalent to <code>set_attrs(Target,
%% get_attrs(Source))</code>, but potentially more efficient.</p>
%%
%% @see get_attrs/1
%% @see set_attrs/2

copy_attrs(S, T) ->
    set_attrs(T, get_attrs(S)).


%% =====================================================================
%% @spec comment(Strings) -> syntaxTree()
%% @equiv comment(none, Strings)

comment(Strings) ->
    comment(none, Strings).


%% =====================================================================
%% @spec comment(Padding, Strings::[string()]) -> syntaxTree()
%%	    Padding = none | integer()
%%
%% @doc Creates an abstract comment with the given padding and text. If
%% <code>Strings</code> is a (possibly empty) list
%% <code>["<em>Txt1</em>", ..., "<em>TxtN</em>"]</code>, the result
%% represents the source code text
%% <pre>
%%     %<em>Txt1</em>
%%     ...
%%     %<em>TxtN</em></pre>
%% <code>Padding</code> states the number of empty character positions
%% to the left of the comment separating it horizontally from
%% source code on the same line (if any). If <code>Padding</code> is
%% <code>none</code>, a default positive number is used. If
%% <code>Padding</code> is an integer less than 1, there should be no
%% separating space. Comments are in themselves regarded as source
%% program forms.
%%
%% @see comment/1
%% @see is_form/1

-record(comment, {pad, text}).

%% type(Node) = comment
%% data(Node) = #comment{pad :: Padding, text :: Strings}
%%
%%	Padding = none | integer()
%%	Strings = [string()]

comment(Pad, Strings) ->
    tree(comment, #comment{pad = Pad, text = Strings}).


%% =====================================================================
%% @spec comment_text(Node::syntaxTree()) -> [string()]
%%
%% @doc Returns the lines of text of the abstract comment.
%%
%% @see comment/2

comment_text(Node) ->
    (data(Node))#comment.text.


%% =====================================================================
%% @spec comment_padding(Node::syntaxTree()) -> none | integer()
%%
%% @doc Returns the amount of padding before the comment, or
%% <code>none</code>. The latter means that a default padding may be
%% used.
%%
%% @see comment/2

comment_padding(Node) ->
    (data(Node))#comment.pad.


%% =====================================================================
%% @spec form_list(Forms::[syntaxTree()]) -> syntaxTree()
%%
%% @doc Creates an abstract sequence of "source code forms". If
%% <code>Forms</code> is <code>[F1, ..., Fn]</code>, where each
%% <code>Fi</code> is a form (cf. <code>is_form/1</code>, the result
%% represents
%% <pre>
%%     <em>F1</em>
%%     ...
%%     <em>Fn</em></pre>
%% where the <code>Fi</code> are separated by one or more line breaks. A
%% node of type <code>form_list</code> is itself regarded as a source
%% code form; cf. <code>flatten_form_list/1</code>.
%%
%% <p>Note: this is simply a way of grouping source code forms as a
%% single syntax tree, usually in order to form an Erlang module
%% definition.</p>
%%
%% @see form_list_elements/1
%% @see is_form/1
%% @see flatten_form_list/1

%% type(Node) = form_list
%% data(Node) = [Form]
%%
%%	Form = syntaxTree()
%%	is_form(Form) = true

form_list(Forms) ->
    tree(form_list, Forms).


%% =====================================================================
%% @spec form_list_elements(syntaxTree()) -> [syntaxTree()]
%%
%% @doc Returns the list of subnodes of a <code>form_list</code> node.
%%
%% @see form_list/1

form_list_elements(Node) ->
    data(Node).


%% =====================================================================
%% @spec flatten_form_list(Node::syntaxTree()) -> syntaxTree()
%%
%% @doc Flattens sublists of a <code>form_list</code> node. Returns
%% <code>Node</code> with all subtrees of type <code>form_list</code>
%% recursively expanded, yielding a single "flat" abstract form
%% sequence.
%%
%% @see form_list/1

flatten_form_list(Node) ->
    Fs = form_list_elements(Node),
    Fs1 = lists:reverse(flatten_form_list_1(Fs, [])),
    copy_attrs(Node, form_list(Fs1)).

flatten_form_list_1([F | Fs], As) ->
    case type(F) of
	form_list ->
	    As1 = flatten_form_list_1(form_list_elements(F), As),
	    flatten_form_list_1(Fs, As1);
	_ ->
	    flatten_form_list_1(Fs, [F | As])
    end;
flatten_form_list_1([], As) ->
    As.


%% =====================================================================
%% @spec text(String::string()) -> syntaxTree()
%%
%% @doc Creates an abstract piece of source code text. The result
%% represents exactly the sequence of characters in <code>String</code>.
%% This is useful in cases when one wants full control of the resulting
%% output, e.g., for the appearance of floating-point numbers or macro
%% definitions.
%%
%% @see text_string/1

%% type(Node) = text
%% data(Node) = string()

text(String) ->
    tree(text, String).


%% =====================================================================
%% @spec text_string(syntaxTree()) -> string()
%%
%% @doc Returns the character sequence represented by a
%% <code>text</code> node.
%%
%% @see text/1

text_string(Node) ->
    data(Node).


%% =====================================================================
%% @spec variable(Name) -> syntaxTree()
%%	    Name = atom() | string()
%%
%% @doc Creates an abstract variable with the given name.
%% <code>Name</code> may be any atom or string that represents a
%% lexically valid variable name, but <em>not</em> a single underscore
%% character; cf. <code>underscore/0</code>.
%%
%% <p>Note: no checking is done whether the character sequence
%% represents a proper variable name, i.e., whether or not its first
%% character is an uppercase Erlang character, or whether it does not
%% contain control characters, whitespace, etc.</p>
%%
%% @see variable_name/1
%% @see variable_literal/1
%% @see underscore/0

%% type(Node) = variable
%% data(Node) = atom()
%%
%% `erl_parse' representation:
%%
%% {var, Pos, Name}
%%
%%	Name = atom() \ '_'

variable(Name) when atom(Name) ->
    tree(variable, Name);
variable(Name) ->
    tree(variable, list_to_atom(Name)).

revert_variable(Node) ->
    Pos = get_pos(Node),
    Name = variable_name(Node),
    {var, Pos, Name}.


%% =====================================================================
%% @spec variable_name(syntaxTree()) -> atom()
%%
%% @doc Returns the name of a <code>variable</code> node as an atom.
%%
%% @see variable/1

variable_name(Node) ->
    case unwrap(Node) of
	{var, _, Name} ->
	    Name;
	Node1 ->
	    data(Node1)
    end.


%% =====================================================================
%% @spec variable_literal(syntaxTree()) -> string()
%%
%% @doc Returns the name of a <code>variable</code> node as a string.
%%
%% @see variable/1

variable_literal(Node) ->
    case unwrap(Node) of
	{var, _, Name} ->
	    atom_to_list(Name);
	Node1 ->
	    atom_to_list(data(Node1))
    end.


%% =====================================================================
%% @spec underscore() -> syntaxTree()
%%
%% @doc Creates an abstract universal pattern ("<code>_</code>"). The
%% lexical representation is a single underscore character. Note that
%% this is <em>not</em> a variable, lexically speaking.
%%
%% @see variable/1

%% type(Node) = underscore
%% data(Node) = []
%%
%% `erl_parse' representation:
%%
%% {var, Pos, '_'}

underscore() ->
    tree(underscore, []).

revert_underscore(Node) ->
    Pos = get_pos(Node),
    {var, Pos, '_'}.


%% =====================================================================
%% @spec integer(Value::integer()) -> syntaxTree()
%%
%% @doc Creates an abstract integer literal. The lexical representation
%% is the canonical decimal numeral of <code>Value</code>.
%%
%% @see integer_value/1
%% @see integer_literal/1
%% @see is_integer/2

%% type(Node) = integer
%% data(Node) = integer()
%%
%% `erl_parse' representation:
%%
%% {integer, Pos, Value}
%%
%%	Value = integer()

integer(Value) ->
    tree(integer, Value).

revert_integer(Node) ->
    Pos = get_pos(Node),
    {integer, Pos, integer_value(Node)}.


%% =====================================================================
%% @spec is_integer(Node::syntaxTree(), Value::integer()) -> bool()
%%
%% @doc Returns <code>true</code> if <code>Node</code> has type
%% <code>integer</code> and represents <code>Value</code>, otherwise
%% <code>false</code>.
%%
%% @see integer/1

is_integer(Node, Value) ->
    case unwrap(Node) of
	{integer, _, Value} ->
	    true;
	#tree{type = integer, data = Value} ->
	    true;
	_ ->
	    false
    end.


%% =====================================================================
%% @spec integer_value(syntaxTree()) -> integer()
%%
%% @doc Returns the value represented by an <code>integer</code> node.
%%
%% @see integer/1

integer_value(Node) ->
    case unwrap(Node) of
	{integer, _, Value} ->
	    Value;
	Node1 ->
	    data(Node1)
    end.


%% =====================================================================
%% @spec integer_literal(syntaxTree()) -> string()
%%
%% @doc Returns the numeral string represented by an
%% <code>integer</code> node.
%%
%% @see integer/1

integer_literal(Node) ->
    integer_to_list(integer_value(Node)).


%% =====================================================================
%% @spec float(Value::float()) -> syntaxTree()
%%
%% @doc Creates an abstract floating-point literal. The lexical
%% representation is the decimal floating-point numeral of
%% <code>Value</code>.
%%
%% @see float_value/1
%% @see float_literal/1

%% type(Node) = float
%% data(Node) = Value
%%
%%	Value = float()
%%
%% `erl_parse' representation:
%%
%% {float, Pos, Value}
%%
%%	Value = float()

%% Note that under current versions of Erlang, the name `float/1' cannot
%% be used for local calls (i.e., within the module) - it will be
%% overridden by the type conversion BIF of the same name, so always use
%% `make_float/1' for local calls.

float(Value) ->
    make_float(Value).

make_float(Value) ->
    tree(float, Value).

revert_float(Node) ->
    Pos = get_pos(Node),
    {float, Pos, float_value(Node)}.


%% =====================================================================
%% @spec float_value(syntaxTree()) -> float()
%%
%% @doc Returns the value represented by a <code>float</code> node. Note
%% that floating-point values should usually not be compared for
%% equality.
%%
%% @see float/1

float_value(Node) ->
    case unwrap(Node) of
	{float, _, Value} ->
	    Value;
	Node1 ->
	    data(Node1)
    end.


%% =====================================================================
%% @spec float_literal(syntaxTree()) -> string()
%%
%% @doc Returns the numeral string represented by a <code>float</code>
%% node.
%%
%% @see float/1

float_literal(Node) ->
    float_to_list(float_value(Node)).


%% =====================================================================
%% @spec char(Value::char()) -> syntaxTree()
%%
%% @doc Creates an abstract character literal. The result represents
%% "<code>$<em>Name</em></code>", where <code>Name</code> corresponds to
%% <code>Value</code>.
%%
%% <p>Note: the literal corresponding to a particular character value is
%% not uniquely defined. E.g., the character "<code>a</code>" can be
%% written both as "<code>$a</code>" and "<code>$\141</code>", and a Tab
%% character can be written as "<code>$\11</code>", "<code>$\011</code>"
%% or "<code>$\t</code>".</p>
%%
%% @see char_value/1
%% @see char_literal/1
%% @see is_char/2

%% type(Node) = char
%% data(Node) = char()
%%
%% `erl_parse' representation:
%%
%% {char, Pos, Code}
%%
%%	Code = integer()

char(Char) ->
    tree(char, Char).

revert_char(Node) ->
    Pos = get_pos(Node),
    {char, Pos, char_value(Node)}.


%% =====================================================================
%% @spec is_char(Node::syntaxTree(), Value::char()) -> bool()
%%
%% @doc Returns <code>true</code> if <code>Node</code> has type
%% <code>char</code> and represents <code>Value</code>, otherwise
%% <code>false</code>.
%%
%% @see char/1

is_char(Node, Value) ->
    case unwrap(Node) of
	{char, _, Value} ->
	    true;
	#tree{type = char, data = Value} ->
	    true;
	_ ->
	    false
    end.


%% =====================================================================
%% @spec char_value(syntaxTree()) -> char()
%%
%% @doc Returns the value represented by a <code>char</code> node.
%%
%% @see char/1

char_value(Node) ->
    case unwrap(Node) of
	{char, _, Char} ->
	    Char;
	Node1 ->
	    data(Node1)
    end.


%% =====================================================================
%% @spec char_literal(syntaxTree()) -> string()
%%
%% @doc Returns the literal string represented by a <code>char</code>
%% node. This includes the leading "<code>$</code>" character.
%%
%% @see char/1

char_literal(Node) ->
    io_lib:write_char(char_value(Node)).


%% =====================================================================
%% @spec string(Value::string()) -> syntaxTree()
%%
%% @doc Creates an abstract string literal. The result represents
%% <code>"<em>Text</em>"</code> (including the surrounding
%% double-quotes), where <code>Text</code> corresponds to the sequence
%% of characters in <code>Value</code>, but not representing a
%% <em>specific</em> string literal. E.g., the result of
%% <code>string("x\ny")</code> represents any and all of
%% <code>"x\ny"</code>, <code>"x\12y"</code>, <code>"x\012y"</code> and
%% <code>"x\^Jy"</code>; cf. <code>char/1</code>.
%%
%% @see string_value/1
%% @see string_literal/1
%% @see is_string/2
%% @see char/1

%% type(Node) = string
%% data(Node) = string()
%%
%% `erl_parse' representation:
%%
%% {string, Pos, Chars}
%%
%%	Chars = string()

string(String) ->
    tree(string, String).

revert_string(Node) ->
    Pos = get_pos(Node),
    {string, Pos, string_value(Node)}.


%% =====================================================================
%% @spec is_string(Node::syntaxTree(), Value::string()) -> bool()
%%
%% @doc Returns <code>true</code> if <code>Node</code> has type
%% <code>string</code> and represents <code>Value</code>, otherwise
%% <code>false</code>.
%%
%% @see string/1

is_string(Node, Value) ->
    case unwrap(Node) of
	{string, _, Value} ->
	    true;
	#tree{type = string, data = Value} ->
	    true;
	_ ->
	    false
    end.


%% =====================================================================
%% @spec string_value(syntaxTree()) -> string()
%%
%% @doc Returns the value represented by a <code>string</code> node.
%%
%% @see string/1

string_value(Node) ->
    case unwrap(Node) of
	{string, _, List} ->
	    List;
	Node1 ->
	    data(Node1)
    end.


%% =====================================================================
%% @spec string_literal(syntaxTree()) -> string()
%%
%% @doc Returns the literal string represented by a <code>string</code>
%% node. This includes surrounding double-quote characters.
%%
%% @see string/1

string_literal(Node) ->
    io_lib:write_string(string_value(Node)).


%% =====================================================================
%% @spec atom(Name) -> syntaxTree()
%%	    Name = atom() | string()
%%
%% @doc Creates an abstract atom literal. The print name of the atom is
%% the character sequence represented by <code>Name</code>.
%%
%% @see atom_value/1
%% @see atom_name/1
%% @see atom_literal/1
%% @see is_atom/2

%% type(Node) = atom
%% data(Node) = atom()
%%
%% `erl_parse' representation:
%%
%% {atom, Pos, Value}
%%
%%	Value = atom()

atom(Name) when atom(Name) ->
    tree(atom, Name);
atom(Name) ->
    tree(atom, list_to_atom(Name)).

revert_atom(Node) ->
    Pos = get_pos(Node),
    {atom, Pos, atom_value(Node)}.


%% =====================================================================
%% @spec is_atom(Node::syntaxTree(), Value::atom()) -> bool()
%%
%% @doc Returns <code>true</code> if <code>Node</code> has type
%% <code>atom</code> and represents <code>Value</code>, otherwise
%% <code>false</code>.
%%
%% @see atom/1

is_atom(Node, Value) ->
    case unwrap(Node) of
	{atom, _, Value} ->
	    true;
	#tree{type = atom, data = Value} ->
	    true;
	_ ->
	    false
    end.


%% =====================================================================
%% @spec atom_value(syntaxTree())-> atom()
%%
%% @doc Returns the value represented by an <code>atom</code> node.
%%
%% @see atom/1

atom_value(Node) ->
    case unwrap(Node) of
	{atom, _, Name} ->
	    Name;
	Node1 ->
	    data(Node1)
    end.


%% =====================================================================
%% @spec atom_name(syntaxTree()) -> string()
%%
%% @doc Returns the printname of an <code>atom</code> node.
%%
%% @see atom/1

atom_name(Node) ->
    atom_to_list(atom_value(Node)).


%% =====================================================================
%% @spec atom_literal(syntaxTree()) -> string()
%%
%% @doc Returns the literal string represented by an <code>atom</code>
%% node. This includes surrounding single-quote characters if necessary.
%%
%% <p>Note that e.g. the result of <code>atom("x\ny")</code> represents
%% any and all of <code>'x\ny'</code>, <code>'x\12y'</code>,
%% <code>'x\012y'</code> and <code>'x\^Jy\'</code>; cf.
%% <code>string/1</code>.</p>
%%
%% @see atom/1
%% @see string/1

atom_literal(Node) ->
    io_lib:write_atom(atom_value(Node)).


%% =====================================================================
%% @spec tuple(Elements::[syntaxTree()]) -> syntaxTree()
%%
%% @doc Creates an abstract tuple. If <code>Elements</code> is
%% <code>[X1, ..., Xn]</code>, the result represents
%% "<code>{<em>X1</em>, ..., <em>Xn</em>}</code>".
%%
%% <p>Note: The Erlang language has distinct 1-tuples, i.e.,
%% <code>{X}</code> is always distinct from <code>X</code> itself.</p>
%%
%% @see tuple_elements/1
%% @see tuple_size/1

%% type(Node) = tuple
%% data(Node) = Elements
%%
%%	Elements = [syntaxTree()]
%%
%% `erl_parse' representation:
%%
%% {tuple, Pos, Elements}
%%
%%	Elements = [erl_parse()]

tuple(List) ->
    tree(tuple, List).

revert_tuple(Node) ->
    Pos = get_pos(Node),
    {tuple, Pos, tuple_elements(Node)}.


%% =====================================================================
%% @spec tuple_elements(syntaxTree()) -> [syntaxTree()]
%%
%% @doc Returns the list of element subtrees of a <code>tuple</code>
%% node.
%%
%% @see tuple/1

tuple_elements(Node) ->
    case unwrap(Node) of
	{tuple, _, List} ->
	    List;
	Node1 ->
	    data(Node1)
    end.


%% =====================================================================
%% @spec tuple_size(syntaxTree()) -> integer()
%%
%% @doc Returns the number of elements of a <code>tuple</code> node.
%%
%% <p>Note: this is equivalent to
%% <code>length(tuple_elements(Node))</code>, but potentially more
%% efficient.</p>
%%
%% @see tuple/1
%% @see tuple_elements/1

tuple_size(Node) ->
    length(tuple_elements(Node)).


%% =====================================================================
%% @spec list(List) -> syntaxTree()
%% @equiv list(List, none)

list(List) ->
    list(List, none).


%% =====================================================================
%% @spec list(List, Tail) -> syntaxTree()
%%	    List = [syntaxTree()]
%%	    Tail = none | syntaxTree()
%%
%% @doc Constructs an abstract list skeleton. The result has type
%% <code>list</code> or <code>nil</code>. If <code>List</code> is a
%% nonempty list <code>[E1, ..., En]</code>, the result has type
%% <code>list</code> and represents either "<code>[<em>E1</em>, ...,
%% <em>En</em>]</code>", if <code>Tail</code> is <code>none</code>, or
%% otherwise "<code>[<em>E1</em>, ..., <em>En</em> |
%% <em>Tail</em>]</code>". If <code>List</code> is the empty list,
%% <code>Tail</code> <em>must</em> be <code>none</code>, and in that
%% case the result has type <code>nil</code> and represents
%% "<code>[]</code>" (cf. <code>nil/0</code>).
%%
%% <p>The difference between lists as semantic objects (built up of
%% individual "cons" and "nil" terms) and the various syntactic forms
%% for denoting lists may be bewildering at first. This module provides
%% functions both for exact control of the syntactic representation as
%% well as for the simple composition and deconstruction in terms of
%% cons and head/tail operations.</p>
%%
%% <p>Note: in <code>list(Elements, none)</code>, the "nil" list
%% terminator is implicit and has no associated information (cf.
%% <code>get_attrs/1</code>), while in the seemingly equivalent
%% <code>list(Elements, Tail)</code> when <code>Tail</code> has type
%% <code>nil</code>, the list terminator subtree <code>Tail</code> may
%% have attached attributes such as position, comments, and annotations,
%% which will be preserved in the result.</p>
%%
%% @see nil/0
%% @see list/1
%% @see list_prefix/1
%% @see list_suffix/1
%% @see cons/2
%% @see list_head/1
%% @see list_tail/1
%% @see is_list_skeleton/1
%% @see is_proper_list/1
%% @see list_elements/1
%% @see list_length/1
%% @see normalize_list/1
%% @see compact_list/1
%% @see get_attrs/1

-record(list, {prefix, suffix}).

%% type(Node) = list
%% data(Node) = #list{prefix :: Elements, suffix :: Tail}
%%
%%	    Elements = [syntaxTree()]
%%	    Tail = none | syntaxTree()
%%
%% `erl_parse' representation:
%%
%% {cons, Pos, Head, Tail}
%%
%%	Head = Tail = [erl_parse()]
%%
%%	This represents `[<Head> | <Tail>]', or more generally `[<Head>
%%	<Suffix>]' where the form of <Suffix> can depend on the
%%	structure of <Tail>; there is no fixed printed form.

list([], none) ->
    nil();
list(Elements, Tail) when Elements /= [] ->
    tree(list, #list{prefix = Elements, suffix = Tail}).

revert_list(Node) ->
    Pos = get_pos(Node),
    P = list_prefix(Node),
    S = case list_suffix(Node) of
	    none ->
		revert_nil(set_pos(nil(), Pos));
	    S1 ->
		S1
	end,
    lists:foldr(fun (X, A) ->
			{cons, Pos, X, A}
		end,
		S, P).

%% =====================================================================
%% @spec nil() -> syntaxTree()
%%
%% @doc Creates an abstract empty list. The result represents
%% "<code>[]</code>". The empty list is traditionally called "nil".
%%
%% @see list/2
%% @see is_list_skeleton/1

%% type(Node) = nil
%% data(Node) = term()
%%
%% `erl_parse' representation:
%%
%% {nil, Pos}

nil() ->
    tree(nil).

revert_nil(Node) ->
    Pos = get_pos(Node),
    {nil, Pos}.


%% =====================================================================
%% @spec list_prefix(Node::syntaxTree()) -> [syntaxTree()]
%%
%% @doc Returns the prefix element subtrees of a <code>list</code> node.
%% If <code>Node</code> represents "<code>[<em>E1</em>, ...,
%% <em>En</em>]</code>" or "<code>[<em>E1</em>, ..., <em>En</em> |
%% <em>Tail</em>]</code>", the returned value is <code>[E1, ...,
%% En]</code>.
%%
%% @see list/2

list_prefix(Node) ->
    case unwrap(Node) of
	{cons, _, Head, _} ->
	    [Head];
	Node1 ->
	    (data(Node1))#list.prefix
    end.


%% =====================================================================
%% @spec list_suffix(Node::syntaxTree()) ->  none | syntaxTree()
%%
%% @doc Returns the suffix subtree of a <code>list</code> node, if one
%% exists. If <code>Node</code> represents "<code>[<em>E1</em>, ...,
%% <em>En</em> | <em>Tail</em>]</code>", the returned value is
%% <code>Tail</code>, otherwise, i.e., if <code>Node</code> represents
%% "<code>[<em>E1</em>, ..., <em>En</em>]</code>", <code>none</code> is
%% returned.
%%
%% <p>Note that even if this function returns some <code>Tail</code>
%% that is not <code>none</code>, the type of <code>Tail</code> can be
%% <code>nil</code>, if the tail has been given explicitly, and the list
%% skeleton has not been compacted (cf.
%% <code>compact_list/1</code>).</p>
%%
%% @see list/2
%% @see nil/0
%% @see compact_list/1

list_suffix(Node) ->
    case unwrap(Node) of
	{cons, _, _, Tail} ->
	    %% If there could be comments/annotations on the tail node,
	    %% we should not return `none' even if it has type `nil'.
	    case Tail of
		{nil, _} ->
		    none;    % no interesting information is lost
		_ ->
		    Tail
	    end;
	Node1 ->
	    (data(Node1))#list.suffix
    end.


%% =====================================================================
%% @spec cons(Head::syntaxTree(), Tail::syntaxTree()) -> syntaxTree()
%%
%% @doc "Optimising" list skeleton cons operation. Creates an abstract
%% list skeleton whose first element is <code>Head</code> and whose tail
%% corresponds to <code>Tail</code>. This is similar to
%% <code>list([Head], Tail)</code>, except that <code>Tail</code> may
%% not be <code>none</code>, and that the result does not necessarily
%% represent exactly "<code>[<em>Head</em> | <em>Tail</em>]</code>", but
%% may depend on the <code>Tail</code> subtree. E.g., if
%% <code>Tail</code> represents <code>[X, Y]</code>, the result may
%% represent "<code>[<em>Head</em>, X, Y]</code>", rather than
%% "<code>[<em>Head</em> | [X, Y]]</code>". Annotations on
%% <code>Tail</code> itself may be lost if <code>Tail</code> represents
%% a list skeleton, but comments on <code>Tail</code> are propagated to
%% the result.
%%
%% @see list/2
%% @see list_head/1
%% @see list_tail/1

cons(Head, Tail) ->
    case type(Tail) of
	list ->
	    copy_comments(Tail, list([Head | list_prefix(Tail)],
				     list_suffix(Tail)));
	nil ->
	    copy_comments(Tail, list([Head]));
	_ ->
	    list([Head], Tail)
    end.


%% =====================================================================
%% @spec list_head(Node::syntaxTree()) -> syntaxTree()
%%
%% @doc Returns the head element subtree of a <code>list</code> node. If
%% <code>Node</code> represents "<code>[<em>Head</em> ...]</code>", the
%% result will represent "<code><em>Head</em></code>".
%%
%% @see list/2
%% @see list_tail/1
%% @see cons/2

list_head(Node) ->
    hd(list_prefix(Node)).


%% =====================================================================
%% list_tail(Node::syntaxTree()) -> syntaxTree()
%%
%% @doc Returns the tail of a <code>list</code> node. If
%% <code>Node</code> represents a single-element list
%% "<code>[<em>E</em>]</code>", then the result has type
%% <code>nil</code>, representing "<code>[]</code>". If
%% <code>Node</code> represents "<code>[<em>E1</em>, <em>E2</em>
%% ...]</code>", the result will represent "<code>[<em>E2</em>
%% ...]</code>", and if <code>Node</code> represents
%% "<code>[<em>Head</em> | <em>Tail</em>]</code>", the result will
%% represent "<code><em>Tail</em></code>".
%%
%% @see list/2
%% @see list_head/1
%% @see cons/2

list_tail(Node) ->
    Tail = list_suffix(Node),
    case tl(list_prefix(Node)) of
	[] ->
	    if Tail == none ->
		    nil();    % implicit list terminator.
	       true ->
		    Tail
	    end;
	Es ->
	    list(Es, Tail)    % `Es' is nonempty.
    end.


%% =====================================================================
%% @spec is_list_skeleton(syntaxTree()) -> bool()
%%
%% @doc Returns <code>true</code> if <code>Node</code> has type
%% <code>list</code> or <code>nil</code>, otherwise <code>false</code>.
%%
%% @see list/2
%% @see nil/0

is_list_skeleton(Node) ->
    case type(Node) of
	list -> true;
	nil -> true;
	_ -> false
    end.


%% =====================================================================
%% @spec is_proper_list(Node::syntaxTree()) -> bool()
%%
%% @doc Returns <code>true</code> if <code>Node</code> represents a
%% proper list, and <code>false</code> otherwise. A proper list is a
%% list skeleton either on the form "<code>[]</code>" or
%% "<code>[<em>E1</em>, ..., <em>En</em>]</code>", or "<code>[... |
%% <em>Tail</em>]</code>" where recursively <code>Tail</code> also
%% represents a proper list.
%%
%% <p>Note: Since <code>Node</code> is a syntax tree, the actual
%% run-time values corresponding to its subtrees may often be partially
%% or completely unknown. Thus, if <code>Node</code> represents e.g.
%% "<code>[... | Ns]</code>" (where <code>Ns</code> is a variable), then
%% the function will return <code>false</code>, because it is not known
%% whether <code>Ns</code> will be bound to a list at run-time. If
%% <code>Node</code> instead represents e.g. "<code>[1, 2, 3]</code>" or
%% "<code>[A | []]</code>", then the function will return
%% <code>true</code>.</p>
%%
%% @see list/2

is_proper_list(Node) ->
    case type(Node) of
	list ->
	    case list_suffix(Node) of
		none ->
		    true;
		Tail ->
		    is_proper_list(Tail)
	    end;
	nil ->
	    true;
	_ ->
	    false
    end.


%% =====================================================================
%% @spec list_elements(Node::syntaxTree()) -> [syntaxTree()]
%%
%% @doc Returns the list of element subtrees of a list skeleton.
%% <code>Node</code> must represent a proper list. E.g., if
%% <code>Node</code> represents "<code>[<em>X1</em>, <em>X2</em> |
%% [<em>X3</em>, <em>X4</em> | []]</code>", then
%% <code>list_elements(Node)</code> yields the list <code>[X1, X2, X3,
%% X4]</code>.
%%
%% @see list/2
%% @see is_proper_list/1

list_elements(Node) ->
    lists:reverse(list_elements(Node, [])).

list_elements(Node, As) ->
    case type(Node) of
	list ->
	    As1 = lists:reverse(list_prefix(Node)) ++ As,
	    case list_suffix(Node) of
		none ->
		    As1;
		Tail ->
		    list_elements(Tail, As1)
	    end;
	nil ->
	    As
    end.


%% =====================================================================
%% list_length(Node::syntaxTree()) -> integer()
%%
%% @doc Returns the number of element subtrees of a list skeleton.
%% <code>Node</code> must represent a proper list. E.g., if
%% <code>Node</code> represents "<code>[X1 | [X2, X3 | [X4, X5,
%% X6]]]</code>", then <code>list_length(Node)</code> returns the
%% integer 6.
%%
%% <p>Note: this is equivalent to
%% <code>length(list_elements(Node))</code>, but potentially more
%% efficient.</p>
%%
%% @see list/2
%% @see is_proper_list/1
%% @see list_elements/1

list_length(Node) ->
    list_length(Node, 0).

list_length(Node, A) ->
    case type(Node) of
	list ->
	    A1 = length(list_prefix(Node)) + A,
	    case list_suffix(Node) of
		none ->
		    A1;
		Tail ->
		    list_length(Tail, A1)
	    end;
	nil ->
	    A
    end.


%% =====================================================================
%% @spec normalize_list(Node::syntaxTree()) -> syntaxTree()
%%
%% @doc Expands an abstract list skeleton to its most explicit form. If
%% <code>Node</code> represents "<code>[<em>E1</em>, ..., <em>En</em> |
%% <em>Tail</em>]</code>", the result represents "<code>[<em>E1</em> |
%% ... [<em>En</em> | <em>Tail1</em>] ... ]</code>", where
%% <code>Tail1</code> is the result of
%% <code>normalize_list(Tail)</code>. If <code>Node</code> represents
%% "<code>[<em>E1</em>, ..., <em>En</em>]</code>", the result simply
%% represents "<code>[<em>E1</em> | ... [<em>En</em> | []] ...
%% ]</code>". If <code>Node</code> does not represent a list skeleton,
%% <code>Node</code> itself is returned.
%%
%% @see list/2
%% @see compact_list/1

normalize_list(Node) ->
    case type(Node) of
	list ->
	    P = list_prefix(Node),
	    case list_suffix(Node) of
		none ->
		    copy_attrs(Node, normalize_list_1(P, nil()));
		Tail ->
		    Tail1 = normalize_list(Tail),
		    copy_attrs(Node, normalize_list_1(P, Tail1))
	    end;
	_ ->
	    Node
    end.

normalize_list_1(Es, Tail) ->
    lists:foldr(fun (X, A) ->
			list([X], A)    % not `cons'!
		end,
		Tail, Es).


%% =====================================================================
%% @spec compact_list(Node::syntaxTree()) -> syntaxTree()
%%
%% @doc Yields the most compact form for an abstract list skeleton. The
%% result either represents "<code>[<em>E1</em>, ..., <em>En</em> |
%% <em>Tail</em>]</code>", where <code>Tail</code> is not a list
%% skeleton, or otherwise simply "<code>[<em>E1</em>, ...,
%% <em>En</em>]</code>". Annotations on subtrees of <code>Node</code>
%% that represent list skeletons may be lost, but comments will be
%% propagated to the result. Returns <code>Node</code> itself if
%% <code>Node</code> does not represent a list skeleton.
%%
%% @see list/2
%% @see normalize_list/1

compact_list(Node) ->
    case type(Node) of
	list ->
	    case list_suffix(Node) of
		none ->
		    Node;
		Tail ->
		    case type(Tail) of
			list ->
			    Tail1 = compact_list(Tail),
			    Node1 = list(list_prefix(Node) ++
					 list_prefix(Tail1),
					 list_suffix(Tail1)),
			    join_comments(Tail1,
					  copy_attrs(Node,
						     Node1));
			nil ->
			    Node1 = list(list_prefix(Node)),
			    join_comments(Tail,
					  copy_attrs(Node,
						     Node1));
			_ ->
			    Node 
		    end
	    end;
	_ ->
	    Node
    end.


%% =====================================================================
%% @spec binary(Fields::[syntaxTree()]) -> syntaxTree()
%%
%% @doc Creates an abstract binary-object template. If
%% <code>Fields</code> is <code>[F1, ..., Fn]</code>, the result
%% represents "<code>&lt;&lt;<em>F1</em>, ...,
%% <em>Fn</em>&gt;&gt;</code>".
%%
%% @see binary_fields/1
%% @see binary_field/2

%% type(Node) = binary
%% data(Node) = Fields
%%
%%	Fields = [syntaxTree()]
%%
%% `erl_parse' representation:
%%
%% {bin, Pos, Fields}
%%
%%	Fields = [Field]
%%	Field = {bin_element, ...}
%%
%%	See `binary_field' for documentation on `erl_parse' binary
%%	fields (or "elements").

binary(List) ->
    tree(binary, List).

revert_binary(Node) ->
    Pos = get_pos(Node),
    {bin, Pos, binary_fields(Node)}.


%% =====================================================================
%% @spec binary_fields(syntaxTree()) -> [syntaxTree()]
%%
%% @doc Returns the list of field subtrees of a <code>binary</code>
%% node.
%%
%% @see binary/1
%% @see binary_field/2

binary_fields(Node) ->
    case unwrap(Node) of
	{bin, _, List} ->
	    List;
	Node1 ->
	    data(Node1)
    end.


%% =====================================================================
%% @spec binary_field(Body) -> syntaxTree()
%% @equiv binary_field(Body, [])

binary_field(Body) ->
    binary_field(Body, []).


%% =====================================================================
%% @spec binary_field(Body::syntaxTree(), Size,
%%                    Types::[syntaxTree()]) -> syntaxTree()
%%	    Size = none | syntaxTree()
%%
%% @doc Creates an abstract binary template field. (Utility function.)
%% If <code>Size</code> is <code>none</code>, this is equivalent to
%% "<code>binary_field(Body, Types)</code>", otherwise it is
%% equivalent to "<code>binary_field(size_qualifier(Body, Size),
%% Types)</code>".
%%
%% @see binary/1
%% @see binary_field/2
%% @see size_qualifier/2

binary_field(Body, none, Types) ->
    binary_field(Body, Types);
binary_field(Body, Size, Types) ->
    binary_field(size_qualifier(Body, Size), Types).


%% =====================================================================
%% @spec binary_field(Body::syntaxTree(), Types::[syntaxTree()]) ->
%%           syntaxTree()
%%
%% @doc Creates an abstract binary template field. If
%% <code>Types</code> is the empty list, the result simply represents
%% "<code><em>Body</em></code>", otherwise, if <code>Types</code> is
%% <code>[T1, ..., Tn]</code>, the result represents
%% "<code><em>Body</em>/<em>T1</em>-...-<em>Tn</em></code>".
%%
%% @see binary/1
%% @see binary_field/1
%% @see binary_field/3
%% @see binary_field_body/1
%% @see binary_field_types/1
%% @see binary_field_size/1

-record(binary_field, {body, types}).

%% type(Node) = binary_field
%% data(Node) = #binary_field{body :: Body, types :: Types}
%%
%%	    Body = syntaxTree()
%%	    Types = [Type]
%%
%% `erl_parse' representation:
%%
%% {bin_element, Pos, Expr, Size, TypeList}
%%
%%	Expr = erl_parse()
%%	Size = default | erl_parse()
%%	TypeList = default | [Type] \ []
%%	Type = atom() | {atom(), integer()}

binary_field(Body, Types) ->
    tree(binary_field, #binary_field{body = Body, types = Types}).

revert_binary_field(Node) ->
    Pos = get_pos(Node),
    Body = binary_field_body(Node),
    {Expr, Size} = case type(Body) of
		       size_qualifier ->
			   %% Note that size qualifiers are not
			   %% revertible out of context.
			   {size_qualifier_body(Body),
			    size_qualifier_argument(Body)};
		       _ ->
			   {Body, default}
		   end,
    Types = case binary_field_types(Node) of
		[] ->
		    default;
		Ts ->
		    fold_binary_field_types(Ts)
	    end,
    {bin_element, Pos, Expr, Size, Types}.


%% =====================================================================
%% @spec binary_field_body(syntaxTree()) -> syntaxTree()
%%
%% @doc Returns the body subtree of a <code>binary_field</code>.
%%
%% @see binary_field/2

binary_field_body(Node) ->
    case unwrap(Node) of
	{bin_element, _, Body, Size, _} ->
	    if Size == default ->
		    Body;
	       true ->
		    size_qualifier(Body, Size)
	    end;
	Node1 ->
	    (data(Node1))#binary_field.body
    end.


%% =====================================================================
%% @spec binary_field_types(Node::syntaxTree()) -> [syntaxTree()]
%%
%% @doc Returns the list of type-specifier subtrees of a
%% <code>binary_field</code> node. If <code>Node</code> represents
%% "<code>.../<em>T1</em>, ..., <em>Tn</em></code>", the result is
%% <code>[T1, ..., Tn]</code>, otherwise the result is the empty list.
%%
%% @see binary_field/2

binary_field_types(Node) ->
    case unwrap(Node) of
	{bin_element, Pos, _, _, Types} ->
	    if Types == default ->
		    [];
	       true ->
		    unfold_binary_field_types(Types, Pos)
	    end;
	Node1 ->
	    (data(Node1))#binary_field.types
    end.


%% =====================================================================
%% @spec binary_field_size(Node::syntaxTree()) -> none | syntaxTree()
%%
%% @doc Returns the size specifier subtree of a
%% <code>binary_field</code> node, if any. (Utility function.) If
%% <code>Node</code> represents
%% "<code><em>Body</em>:<em>Size</em></code>" or
%% "<code><em>Body</em>:<em>Size</em>/<em>T1</em>, ...,
%% <em>Tn</em></code>", the result is <code>Size</code>, otherwise
%% <code>none</code> is returned.
%%
%% @see binary_field/2
%% @see binary_field/3

binary_field_size(Node) ->
    case unwrap(Node) of
	{bin_element, _, _, Size, _} ->
	    if Size == default ->
		    none;
	       true ->
		    Size
	    end;
	Node1 ->
	    Body = (data(Node1))#binary_field.body,
	    case type(Body) of
		size_qualifier ->
		    size_qualifier_argument(Body);
		_ ->
		    none
	    end
    end.


%% =====================================================================
%% @spec size_qualifier(Body::syntaxTree(), Size::syntaxTree()) ->
%%           syntaxTree()
%%
%% @doc Creates an abstract size qualifier. The result represents
%% "<code><em>Body</em>:<em>Size</em></code>".
%%
%% @see size_qualifier_body/1
%% @see size_qualifier_argument/1

-record(size_qualifier, {body, size}).

%% type(Node) = size_qualifier
%% data(Node) = #size_qualifier{body :: Body, size :: Size}
%%
%%	Body = Size = syntaxTree()

size_qualifier(Body, Size) ->
    tree(size_qualifier,
	 #size_qualifier{body = Body, size = Size}).


%% =====================================================================
%% @spec size_qualifier_body(syntaxTree()) -> syntaxTree()
%%
%% @doc Returns the body subtree of a <code>size_qualifier</code>
%% node.
%%
%% @see size_qualifier/2

size_qualifier_body(Node) ->
    (data(Node))#size_qualifier.body.


%% =====================================================================
%% @spec size_qualifier_argument(syntaxTree()) -> syntaxTree()
%%
%% @doc Returns the argument subtree (the size) of a
%% <code>size_qualifier</code> node.
%%
%% @see size_qualifier/2

size_qualifier_argument(Node) ->
    (data(Node))#size_qualifier.size.


%% =====================================================================
%% @spec error_marker(Error::term()) -> syntaxTree()
%%
%% @doc Creates an abstract error marker. The result represents an
%% occurrence of an error in the source code, with an associated Erlang
%% I/O ErrorInfo structure given by <code>Error</code> (see module
%% <code>io</code> for details). Error markers are regarded as source
%% code forms, but have no defined lexical form.
%%
%% <p>Note: this is supported only for backwards compatibility with
%% existing parsers and tools.</p>
%%
%% @see error_marker_info/1
%% @see warning_marker/1
%% @see eof_marker/0
%% @see is_form/1
%% @see io

%% type(Node) = error_marker
%% data(Node) = term()
%%
%% `erl_parse' representation:
%%
%% {error, Error}
%%
%%	Error = term()
%%
%%	Note that there is no position information for the node
%%	itself: `get_pos' and `set_pos' handle this as a special case.

error_marker(Error) ->
    tree(error_marker, Error).

revert_error_marker(Node) ->
    %% Note that the position information of the node itself is not
    %% preserved.
    {error, error_marker_info(Node)}.


%% =====================================================================
%% @spec error_marker_info(syntaxTree()) -> term()
%%
%% @doc Returns the ErrorInfo structure of an <code>error_marker</code>
%% node.
%%
%% @see error_marker/1

error_marker_info(Node) ->
    case unwrap(Node) of
	{error, Error} ->
	    Error;
	T ->
	    data(T)
    end.


%% =====================================================================
%% @spec warning_marker(Error::term()) -> syntaxTree()
%%
%% @doc Creates an abstract warning marker. The result represents an
%% occurrence of a possible problem in the source code, with an
%% associated Erlang I/O ErrorInfo structure given by <code>Error</code>
%% (see module <code>io</code> for details). Warning markers are
%% regarded as source code forms, but have no defined lexical form.
%%
%% <p>Note: this is supported only for backwards compatibility with
%% existing parsers and tools.</p>
%%
%% @see warning_marker_info/1
%% @see error_marker/1
%% @see eof_marker/0
%% @see is_form/1
%% @see io

%% type(Node) = warning_marker
%% data(Node) = term()
%%
%% `erl_parse' representation:
%%
%% {warning, Error}
%%
%%	Error = term()
%%
%%	Note that there is no position information for the node
%%	itself: `get_pos' and `set_pos' handle this as a special case.

warning_marker(Warning) ->
    tree(warning_marker, Warning).

revert_warning_marker(Node) ->
    %% Note that the position information of the node itself is not
    %% preserved.
    {warning, warning_marker_info(Node)}.


%% =====================================================================
%% @spec warning_marker_info(syntaxTree()) -> term()
%%
%% @doc Returns the ErrorInfo structure of a <code>warning_marker</code>
%% node.
%%
%% @see warning_marker/1

warning_marker_info(Node) ->
    case unwrap(Node) of
	{warning, Error} ->
	    Error;
	T ->
	    data(T)
    end.


%% =====================================================================
%% @spec eof_marker() -> syntaxTree()
%%
%% @doc Creates an abstract end-of-file marker. This represents the
%% end of input when reading a sequence of source code forms. An
%% end-of-file marker is itself regarded as a source code form
%% (namely, the last in any sequence in which it occurs). It has no
%% defined lexical form.
%%
%% <p>Note: this is retained only for backwards compatibility with
%% existing parsers and tools.</p>
%%
%% @see error_marker/1
%% @see warning_marker/1
%% @see is_form/1

%% type(Node) = eof_marker
%% data(Node) = term()
%%
%% `erl_parse' representation:
%%
%% {eof, Pos}

eof_marker() ->
    tree(eof_marker).

revert_eof_marker(Node) ->
    Pos = get_pos(Node),
    {eof, Pos}.


%% =====================================================================
%% @spec attribute(Name) -> syntaxTree()
%% @equiv attribute(Name, none)

attribute(Name) ->
    attribute(Name, none).


%% =====================================================================
%% @spec attribute(Name::syntaxTree(), Arguments) -> syntaxTree()
%%           Arguments = none | [syntaxTree()]
%%
%% @doc Creates an abstract program attribute. If
%% <code>Arguments</code> is <code>[A1, ..., An]</code>, the result
%% represents "<code>-<em>Name</em>(<em>A1</em>, ...,
%% <em>An</em>).</code>". Otherwise, if <code>Arguments</code> is
%% <code>none</code>, the result represents
%% "<code>-<em>Name</em>.</code>". The latter form makes it possible
%% to represent preprocessor directives such as
%% "<code>-endif.</code>". Attributes are source code forms.
%%
%% <p>Note: The preprocessor macro definition directive
%% "<code>-define(<em>Name</em>, <em>Body</em>).</code>" has relatively
%% few requirements on the syntactical form of <code>Body</code> (viewed
%% as a sequence of tokens). The <code>text</code> node type can be used
%% for a <code>Body</code> that is not a normal Erlang construct.</p>
%%
%% @see attribute/1
%% @see attribute_name/1
%% @see attribute_arguments/1
%% @see text/1
%% @see is_form/1

-record(attribute, {name, args}).

%% type(Node) = attribute
%% data(Node) = #attribute{name :: Name, args :: Arguments}
%%
%%	Name = syntaxTree()
%%	Arguments = none | [syntaxTree()]
%%
%% `erl_parse' representation:
%%
%% {attribute, Pos, module, {Name,Vars}}
%% {attribute, Pos, module, Name}
%%
%%	Name = atom() | [atom()]
%%	Vars = [atom()]
%%
%%	Representing `-module(M).', or `-module(M, Vs).', where M is
%%	`A1.A2.....An' if Name is `[A1, A2, ..., An]', and Vs is `[V1,
%%	..., Vm]' if Vars is `[V1, ..., Vm]'.
%%
%% {attribute, Pos, export, Exports}
%%
%%	Exports = [{atom(), integer()}]
%%
%%	Representing `-export([A1/N1, ..., Ak/Nk]).', if `Exports' is
%%	`[{A1, N1}, ..., {Ak, Nk}]'.
%%
%% {attribute, Pos, import, Imports}
%%
%%	Imports = {atom(), Pairs} | [atom()]
%%	Pairs = [{atom(), integer()]
%%
%%	Representing `-import(Module, [A1/N1, ..., Ak/Nk]).', if
%%	`Imports' is `{Module, [{A1, N1}, ..., {Ak, Nk}]}', or
%%	`-import(A1.....An).', if `Imports' is `[A1, ..., An]'.
%%
%% {attribute, Pos, file, Position}
%%
%%	Position = {filename(), integer()}
%%
%%	Representing `-file(Name, Line).', if `Position' is `{Name,
%%	Line}'.
%%
%% {attribute, Pos, record, Info}
%%
%%	Info = {Name, [Entries]}
%%	Name = atom()
%%	Entries = {record_field, Pos, atom()}
%%		| {record_field, Pos, atom(), erl_parse()}
%%
%%	Representing `-record(Name, {<F1>, ..., <Fn>}).', if `Info' is
%%	`{Name, [D1, ..., D1]}', where each `Fi' is either `Ai = <Ei>',
%%	if the corresponding `Di' is `{record_field, Pos, Ai, Ei}', or
%%	otherwise simply `Ai', if `Di' is `{record_field, Pos, Ai}'.
%%
%% {attribute, L, Name, Term}
%%
%%	Name = atom() \ StandardName
%%	StandardName = module | export | import | file | record
%%	Term = term()
%%
%%	Representing `-Name(Term).'.

attribute(Name, Args) ->
    tree(attribute, #attribute{name = Name, args = Args}).

revert_attribute(Node) ->
    Name = attribute_name(Node),
    Args = attribute_arguments(Node),
    Pos = get_pos(Node),
    case type(Name) of
	atom ->
	    revert_attribute_1(atom_value(Name), Args, Pos, Node);
	_ ->
	    Node
    end.

%% All the checking makes this part a bit messy:

revert_attribute_1(module, [M], Pos, Node) ->
    case revert_module_name(M) of
	{ok, A} -> 
	    {attribute, Pos, module, A};
	error -> Node
    end;
revert_attribute_1(module, [M, List], Pos, Node) ->
    Vs = case is_list_skeleton(List) of
	     true ->
		 case is_proper_list(List) of
		     true ->
			 fold_variable_names(list_elements(List));
		     false ->
			 Node
		 end;
	     false ->
		 Node
	 end,
    case revert_module_name(M) of
	{ok, A} -> 
	    {attribute, Pos, module, {A, Vs}};
	error -> Node
    end;
revert_attribute_1(export, [List], Pos, Node) ->
    case is_list_skeleton(List) of
	true ->
	    case is_proper_list(List) of
		true ->
		    Fs = fold_function_names(list_elements(List)),
		    {attribute, Pos, export, Fs};
		false ->
		    Node
	    end;
	false ->
	    Node
    end;
revert_attribute_1(import, [M], Pos, Node) ->
    case revert_module_name(M) of
	{ok, A} -> {attribute, Pos, import, A};
	error -> Node
    end;
revert_attribute_1(import, [A, List], Pos, Node) ->
    case type(A) of
	atom ->
	    case is_list_skeleton(List) of
		true ->
		    case is_proper_list(List) of
			true ->
			    Fs = fold_function_names(
				   list_elements(List)),
			    {attribute, Pos, import,
			     {concrete(A), Fs}};
			false ->
			    Node
		    end;
		false ->
		    Node
	    end;
	_ ->
	    Node
    end;
revert_attribute_1(file, [A, Line], Pos, Node) ->
    case type(A) of
	string ->
	    case type(Line) of
		integer ->
		    {attribute, Pos, file,
		     {concrete(A), concrete(Line)}};
		_ ->
		    Node
	    end;
	_ ->
	    Node
    end;
revert_attribute_1(record, [A, Tuple], Pos, Node) ->
    case type(A) of
	atom ->
	    case type(Tuple) of
		tuple ->
		    Fs = fold_record_fields(
			   tuple_elements(Tuple)),
		    {attribute, Pos, record, {concrete(A), Fs}};
		_ ->
		    Node
	    end;
	_ ->
	    Node
    end;
revert_attribute_1(N, [T], Pos, _) ->
    {attribute, Pos, N, concrete(T)};
revert_attribute_1(_, _, _, Node) ->
    Node.

revert_module_name(A) ->
    case type(A) of
	atom ->
	    {ok, concrete(A)};
	qualified_name ->
	    Ss = qualified_name_segments(A),
	    {ok, [concrete(S) || S <- Ss]};
	_ ->
	    error
    end.


%% =====================================================================
%% @spec attribute_name(syntaxTree()) -> syntaxTree()
%%
%% @doc Returns the name subtree of an <code>attribute</code> node.
%%
%% @see attribute/1

attribute_name(Node) ->
    case unwrap(Node) of
	{attribute, Pos, Name, _} ->
	    set_pos(atom(Name), Pos);
	Node1 ->
	    (data(Node1))#attribute.name
    end.


%% =====================================================================
%% @spec attribute_arguments(Node::syntaxTree()) ->
%%           none | [syntaxTree()]
%%
%% @doc Returns the list of argument subtrees of an
%% <code>attribute</code> node, if any. If <code>Node</code>
%% represents "<code>-<em>Name</em>.</code>", the result is
%% <code>none</code>. Otherwise, if <code>Node</code> represents
%% "<code>-<em>Name</em>(<em>E1</em>, ..., <em>En</em>).</code>",
%% <code>[E1, ..., E1]</code> is returned.
%%
%% @see attribute/1

attribute_arguments(Node) ->
    case unwrap(Node) of
	{attribute, Pos, Name, Data} ->
	    case Name of
		module ->
		    {M1, Vs} =
			case Data of
			    {M0, Vs0} ->
				{M0, unfold_variable_names(Vs0, Pos)};
			    M0 ->
				{M0, none}
			end,
		    M2 = if list(M1) ->
				 qualified_name([atom(A) || A <- M1]);
			    true ->
				 atom(M1)
			 end,
		    M = set_pos(M2, Pos),
		    if Vs == none -> [M];
		       true -> [M, set_pos(list(Vs), Pos)]
		    end;
		export ->
		    [set_pos(
		       list(unfold_function_names(Data, Pos)),
		       Pos)];
		import ->
		    case Data of
			{Module, Imports} ->
			    [if list(Module) ->
				     qualified_name([atom(A)
						     || A <- Module]);
				true ->
				     set_pos(atom(Module), Pos)
			     end,
			     set_pos(
			       list(unfold_function_names(Imports, Pos)),
			       Pos)];
			_ ->
			    [qualified_name([atom(A) || A <- Data])]
		    end;
		file ->
		    {File, Line} = Data,
		    [set_pos(string(File), Pos),
		     set_pos(integer(Line), Pos)];
		record ->
		    %% Note that we create a tuple as container
		    %% for the second argument!
		    {Type, Entries} = Data,
		    [set_pos(atom(Type), Pos),
		     set_pos(tuple(unfold_record_fields(Entries)),
			     Pos)];
		_ ->
		    %% Standard single-term generic attribute.
		    [set_pos(abstract(Data), Pos)]
	    end;
	Node1 ->
	    (data(Node1))#attribute.args
    end.


%% =====================================================================
%% @spec arity_qualifier(Body::syntaxTree(), Arity::syntaxTree()) ->
%%           syntaxTree()
%%
%% @doc Creates an abstract arity qualifier. The result represents
%% "<code><em>Body</em>/<em>Arity</em></code>".
%%
%% @see arity_qualifier_body/1
%% @see arity_qualifier_argument/1

-record(arity_qualifier, {body, arity}).

%% type(Node) = arity_qualifier
%% data(Node) = #arity_qualifier{body :: Body, arity :: Arity}
%%
%%	Body = Arity = syntaxTree()

arity_qualifier(Body, Arity) ->
    tree(arity_qualifier,
	 #arity_qualifier{body = Body, arity = Arity}).


%% =====================================================================
%% @spec arity_qualifier_body(syntaxTree()) -> syntaxTree()
%%
%% @doc Returns the body subtree of an <code>arity_qualifier</code>
%% node.
%%
%% @see arity_qualifier/1

arity_qualifier_body(Node) ->
    (data(Node))#arity_qualifier.body.


%% =====================================================================
%% @spec arity_qualifier_argument(syntaxTree()) -> syntaxTree()
%%
%% @doc Returns the argument (the arity) subtree of an
%% <code>arity_qualifier</code> node.
%%
%% @see arity_qualifier/1

arity_qualifier_argument(Node) ->
    (data(Node))#arity_qualifier.arity.


%% =====================================================================
%% @spec module_qualifier(Module::syntaxTree(), Body::syntaxTree()) ->
%%           syntaxTree()
%%
%% @doc Creates an abstract module qualifier. The result represents
%% "<code><em>Module</em>:<em>Body</em></code>".
%%
%% @see module_qualifier_argument/1
%% @see module_qualifier_body/1

-record(module_qualifier, {module, body}).

%% type(Node) = module_qualifier
%% data(Node) = #module_qualifier{module :: Module, body :: Body}
%%
%%	Module = Body = syntaxTree()
%%
%% `erl_parse' representation:
%%
%% {remote, Pos, Module, Arg}
%%
%%	Module = Arg = erl_parse()

module_qualifier(Module, Body) ->
    tree(module_qualifier,
	 #module_qualifier{module = Module, body = Body}).

revert_module_qualifier(Node) ->
    Pos = get_pos(Node),
    Module = module_qualifier_argument(Node),
    Body = module_qualifier_body(Node),
    {remote, Pos, Module, Body}.


%% =====================================================================
%% @spec module_qualifier_argument(syntaxTree()) -> syntaxTree()
%%
%% @doc Returns the argument (the module) subtree of a
%% <code>module_qualifier</code> node.
%%
%% @see module_qualifier/2

module_qualifier_argument(Node) ->
    case unwrap(Node) of
	{remote, _, Module, _} ->
	    Module;
	Node1 ->
	    (data(Node1))#module_qualifier.module
    end.


%% =====================================================================
%% @spec module_qualifier_body(syntaxTree()) -> syntaxTree()
%%
%% @doc Returns the body subtree of a <code>module_qualifier</code>
%% node.
%%
%% @see module_qualifier/2

module_qualifier_body(Node) ->
    case unwrap(Node) of
	{remote, _, _, Body} ->
	    Body;
	Node1 ->
	    (data(Node1))#module_qualifier.body
    end.


%% =====================================================================
%% @spec qualified_name(Segments::[syntaxTree()]) -> syntaxTree()
%%
%% @doc Creates an abstract qualified name. The result represents
%% "<code><em>S1</em>.<em>S2</em>. ... .<em>Sn</em></code>", if
%% <code>Segments</code> is <code>[S1, S2, ..., Sn]</code>.
%%
%% @see qualified_name_segments/1

%% type(Node) = qualified_name
%% data(Node) = [syntaxTree()]
%%
%% `erl_parse' representation:
%%
%% {record_field, Pos, Node, Node}
%%
%%	Node = {atom, Pos, Value} | {record_field, Pos, Node, Node}
%%
%% Note that if not all leaf subnodes are (abstract) atoms, then Node
%% represents a Mnemosyne query record field access ('record_access');
%% see type/1 for details.

qualified_name(Segments) ->
    tree(qualified_name, Segments).

revert_qualified_name(Node) ->
    Pos = get_pos(Node),
    fold_qualified_name(qualified_name_segments(Node), Pos).


%% =====================================================================
%% @spec qualified_name_segments(syntaxTree()) -> [syntaxTree()]
%%
%% @doc Returns the list of name segments of a
%% <code>qualified_name</code> node.
%%
%% @see qualified_name/1

qualified_name_segments(Node) ->
    case unwrap(Node) of
	{record_field, _, _, _} = Node1 ->
	    unfold_qualified_name(Node1);
	Node1 ->
	    data(Node1)
    end.


%% =====================================================================
%% @spec function(Name::syntaxTree(), Clauses::[syntaxTree()]) ->
%%           syntaxTree()
%%
%% @doc Creates an abstract function definition. If <code>Clauses</code>
%% is <code>[C1, ..., Cn]</code>, the result represents
%% "<code><em>Name</em> <em>C1</em>; ...; <em>Name</em>
%% <em>Cn</em>.</code>". More exactly, if each <code>Ci</code>
%% represents "<code>(<em>Pi1</em>, ..., <em>Pim</em>) <em>Gi</em> ->
%% <em>Bi</em></code>", then the result represents
%% "<code><em>Name</em>(<em>P11</em>, ..., <em>P1m</em>) <em>G1</em> ->
%% <em>B1</em>; ...; <em>Name</em>(<em>Pn1</em>, ..., <em>Pnm</em>)
%% <em>Gn</em> -> <em>Bn</em>.</code>". Function definitions are source
%% code forms.
%%
%% @see function_name/1
%% @see function_clauses/1
%% @see function_arity/1
%% @see is_form/1
%% @see rule/2

-record(function, {name, clauses}).

%% type(Node) = function
%% data(Node) = #function{name :: Name, clauses :: Clauses}
%%
%%	Name = syntaxTree()
%%	Clauses = [syntaxTree()]
%%
%%	(There's no real point in precomputing and storing the arity,
%%	and passing it as a constructor argument makes it possible to
%%	end up with an inconsistent value. Besides, some people might
%%	want to check all clauses, and not just the first, so the
%%	computation is not obvious.)
%%
%% `erl_parse' representation:
%%
%% {function, Pos, Name, Arity, Clauses}
%%
%%	Name = atom()
%%	Arity = integer()
%%	Clauses = [Clause] \ []
%%	Clause = {clause, ...}
%%
%%	where the number of patterns in each clause should be equal to
%%	the integer `Arity'; see `clause' for documentation on
%%	`erl_parse' clauses.

function(Name, Clauses) ->
    tree(function, #function{name = Name, clauses = Clauses}).

revert_function(Node) ->
    Name = function_name(Node),
    Clauses = [revert_clause(C) || C <- function_clauses(Node)],
    Pos = get_pos(Node),
    case type(Name) of
	atom ->
	    A = function_arity(Node),
	    {function, Pos, concrete(Name), A, Clauses};
	_ ->
	    Node
    end.


%% =====================================================================
%% function_name(Node) -> Name
%%
%%	    Node = Name = syntaxTree()
%%	    type(Node) = function
%%
%% @doc Returns the name subtree of a <code>function</code> node.
%%
%% @see function/2

function_name(Node) ->
    case unwrap(Node) of
	{function, Pos, Name, _, _} ->
	    set_pos(atom(Name), Pos);
	Node1 ->
	    (data(Node1))#function.name
    end.


%% =====================================================================
%% function_clauses(Node) -> Clauses
%%
%%	    Node = syntaxTree()
%%	    Clauses = [syntaxTree()]
%%	    type(Node) = function
%%
%% @doc Returns the list of clause subtrees of a <code>function</code>
%% node.
%%
%% @see function/2

function_clauses(Node) ->
    case unwrap(Node) of
	{function, _, _, _, Clauses} ->
	    Clauses;
	Node1 ->
	    (data(Node1))#function.clauses
    end.


%% =====================================================================
%% @spec function_arity(Node::syntaxTree()) -> integer()
%%
%% @doc Returns the arity of a <code>function</code> node. The result
%% is the number of parameter patterns in the first clause of the
%% function; subsequent clauses are ignored.
%%
%% <p>An exception is thrown if <code>function_clauses(Node)</code>
%% returns an empty list, or if the first element of that list is not
%% a syntax tree <code>C</code> of type <code>clause</code> such that
%% <code>clause_patterns(C)</code> is a nonempty list.</p>
%%
%% @see function/2
%% @see function_clauses/1
%% @see clause/3
%% @see clause_patterns/1

function_arity(Node) ->
    %% Note that this never accesses the arity field of `erl_parse'
    %% function nodes.
    length(clause_patterns(hd(function_clauses(Node)))).


%% =====================================================================
%% @spec clause(Guard, Body) -> syntaxTree()
%% @equiv clause([], Guard, Body)

clause(Guard, Body) ->
    clause([], Guard, Body).


%% =====================================================================
%% @spec clause(Patterns::[syntaxTree()], Guard,
%%              Body::[syntaxTree()]) -> syntaxTree()
%%	    Guard = none | syntaxTree()
%%                | [syntaxTree()] | [[syntaxTree()]]
%%
%% @doc Creates an abstract clause. If <code>Patterns</code> is
%% <code>[P1, ..., Pn]</code> and <code>Body</code> is <code>[B1, ...,
%% Bm]</code>, then if <code>Guard</code> is <code>none</code>, the
%% result represents "<code>(<em>P1</em>, ..., <em>Pn</em>) ->
%% <em>B1</em>, ..., <em>Bm</em></code>", otherwise, unless
%% <code>Guard</code> is a list, the result represents
%% "<code>(<em>P1</em>, ..., <em>Pn</em>) when <em>Guard</em> ->
%% <em>B1</em>, ..., <em>Bm</em></code>".
%%
%% <p>For simplicity, the <code>Guard</code> argument may also be any
%% of the following:
%% <ul>
%%   <li>An empty list <code>[]</code>. This is equivalent to passing
%%       <code>none</code>.</li>
%%   <li>A nonempty list <code>[E1, ..., Ej]</code> of syntax trees.
%%       This is equivalent to passing <code>conjunction([E1, ...,
%%       Ej])</code>.</li>
%%   <li>A nonempty list of lists of syntax trees <code>[[E1_1, ...,
%%       E1_k1], ..., [Ej_1, ..., Ej_kj]]</code>, which is equivalent
%%       to passing <code>disjunction([conjunction([E1_1, ...,
%%       E1_k1]), ..., conjunction([Ej_1, ..., Ej_kj])])</code>.</li>
%% </ul>
%% </p>
%%
%% @see clause/2
%% @see clause_patterns/1
%% @see clause_guard/1
%% @see clause_body/1

-record(clause, {patterns, guard, body}).

%% type(Node) = clause
%% data(Node) = #clause{patterns :: Patterns, guard :: Guard,
%%		        body :: Body}
%%
%%	Patterns = [syntaxTree()]
%%	Guard = syntaxTree() | none
%%	Body = [syntaxTree()]
%%
%% `erl_parse' representation:
%%
%% {clause, Pos, Patterns, Guard, Body}
%%
%%	Patterns = [erl_parse()]
%%	Guard = [[erl_parse()]] | [erl_parse()]
%%	Body = [erl_parse()] \ []
%%
%%	Taken out of context, if `Patterns' is `[P1, ..., Pn]' and
%%	`Body' is `[B1, ..., Bm]', this represents `(<P1>, ..., <Pn>) ->
%%	<B1>, ..., <Bm>' if `Guard' is `[]', or otherwise `(<P1>, ...,
%%	<Pn>) when <G> -> <Body>', where `G' is `<E1_1>, ..., <E1_k1>;
%%	...; <Ej_1>, ..., <Ej_kj>', if `Guard' is a list of lists
%%	`[[E1_1, ..., E1_k1], ..., [Ej_1, ..., Ej_kj]]'. In older
%%	versions, `Guard' was simply a list `[E1, ..., En]' of parse
%%	trees, which is equivalent to the new form `[[E1, ..., En]]'.

clause(Patterns, Guard, Body) ->
    Guard1 = case Guard of
		 [] ->
		     none;
		 [X | _] when list(X) ->
		     disjunction(conjunction_list(Guard));
		 [_ | _] ->
		     %% Handle older forms also.
		     conjunction(Guard);
		 _ ->
		     %% This should be `none' or a syntax tree.
		     Guard
	     end,
    tree(clause, #clause{patterns = Patterns, guard = Guard1,
			 body = Body}).

conjunction_list([L | Ls]) ->
    [conjunction(L) | conjunction_list(Ls)];
conjunction_list([]) ->
    [].

revert_clause(Node) ->
    Pos = get_pos(Node),
    Guard = case clause_guard(Node) of
		none ->
		    [];
		E ->
		    case type(E) of
			disjunction ->
			    revert_clause_disjunction(E);
			conjunction ->
			    %% Only the top level expression is
			    %% unfolded here; no recursion.
			    [conjunction_body(E)];
			_ ->
			    [[E]]	% a single expression
		    end
	    end,
    {clause, Pos, clause_patterns(Node), Guard,
     clause_body(Node)}.

revert_clause_disjunction(D) ->
    %% We handle conjunctions within a disjunction, but only at
    %% the top level; no recursion.
    [case type(E) of
	 conjunction ->
	     conjunction_body(E);
	 _ ->
	     [E]
     end
     || E <- disjunction_body(D)].

revert_try_clause(Node) ->
    fold_try_clause(revert_clause(Node)).

fold_try_clause({clause, Pos, [P], Guard, Body}) ->
    P1 = case type(P) of
	     class_qualifier ->
		 {tuple, Pos, [class_qualifier_argument(P),
			       class_qualifier_body(P),
			       {var, Pos, '_'}]};
	     _ ->
		 {tuple, Pos, [{atom, Pos, throw}, P, {var, Pos, '_'}]}
	 end,
    {clause, Pos, [P1], Guard, Body}.

unfold_try_clauses(Cs) ->
    [unfold_try_clause(C) || C <- Cs].

unfold_try_clause({clause, Pos, [{tuple, _, [{atom,_,throw}, V, _]}],
		   Guard, Body}) ->
    {clause, Pos, [V], Guard, Body};
unfold_try_clause({clause, Pos, [{tuple, _, [C, V, _]}],
		   Guard, Body}) ->
    {clause, Pos, [class_qualifier(C, V)], Guard, Body}.


%% =====================================================================
%% @spec clause_patterns(syntaxTree()) -> [syntaxTree()]
%%
%% @doc Returns the list of pattern subtrees of a <code>clause</code>
%% node.
%%
%% @see clause/3

clause_patterns(Node) ->
    case unwrap(Node) of
	{clause, _, Patterns, _, _} ->
	    Patterns;
	Node1 ->
	    (data(Node1))#clause.patterns
    end.


%% =====================================================================
%% @spec clause_guard(Node::syntaxTree()) -> none | syntaxTree()
%%
%% @doc Returns the guard subtree of a <code>clause</code> node, if
%% any. If <code>Node</code> represents "<code>(<em>P1</em>, ...,
%% <em>Pn</em>) when <em>Guard</em> -> <em>B1</em>, ...,
%% <em>Bm</em></code>", <code>Guard</code> is returned. Otherwise, the
%% result is <code>none</code>.
%%
%% @see clause/3

clause_guard(Node) ->
    case unwrap(Node) of
	{clause, _, _, Guard, _} ->
	    case Guard of
		[] -> none;
		[L | _] when list(L) ->
		    disjunction(conjunction_list(Guard));
		[_ | _] ->
		    conjunction(Guard)
	    end;
	Node1 ->
	    (data(Node1))#clause.guard
    end.


%% =====================================================================
%% @spec clause_body(syntaxTree()) -> [syntaxTree()]
%%
%% @doc Return the list of body subtrees of a <code>clause</code>
%% node.
%%
%% @see clause/3

clause_body(Node) ->
    case unwrap(Node) of
	{clause, _, _, _, Body} ->
	    Body;
	Node1 ->
	    (data(Node1))#clause.body
    end.


%% =====================================================================
%% @spec disjunction(List::[syntaxTree()]) -> syntaxTree()
%%
%% @doc Creates an abstract disjunction. If <code>List</code> is
%% <code>[E1, ..., En]</code>, the result represents
%% "<code><em>E1</em>; ...; <em>En</em></code>".
%%
%% @see disjunction_body/1
%% @see conjunction/1

%% type(Node) = disjunction
%% data(Node) = [syntaxTree()]

disjunction(Tests) ->
    tree(disjunction, Tests).


%% =====================================================================
%% @spec disjunction_body(syntaxTree()) -> [syntaxTree()]
%%
%% @doc Returns the list of body subtrees of a
%% <code>disjunction</code> node.
%%
%% @see disjunction/1

disjunction_body(Node) ->
    data(Node).


%% =====================================================================
%% @spec conjunction(List::[syntaxTree()]) -> syntaxTree()
%%
%% @doc Creates an abstract conjunction. If <code>List</code> is
%% <code>[E1, ..., En]</code>, the result represents
%% "<code><em>E1</em>, ..., <em>En</em></code>".
%%
%% @see conjunction_body/1
%% @see disjunction/1

%% type(Node) = conjunction
%% data(Node) = [syntaxTree()]

conjunction(Tests) ->
    tree(conjunction, Tests).


%% =====================================================================
%% @spec conjunction_body(syntaxTree()) -> [syntaxTree()]
%%
%% @doc Returns the list of body subtrees of a
%% <code>conjunction</code> node.
%%
%% @see conjunction/1

conjunction_body(Node) ->
    data(Node).


%% =====================================================================
%% @spec catch_expr(Expr::syntaxTree()) -> syntaxTree()
%%
%% @doc Creates an abstract catch-expression. The result represents
%% "<code>catch <em>Expr</em></code>".
%%
%% @see catch_expr_body/1

%% type(Node) = catch_expr
%% data(Node) = syntaxTree()
%%
%% `erl_parse' representation:
%%
%% {'catch', Pos, Expr}
%%
%%	Expr = erl_parse()

catch_expr(Expr) ->
    tree(catch_expr, Expr).

revert_catch_expr(Node) ->
    Pos = get_pos(Node),
    Expr = catch_expr_body(Node),
    {'catch', Pos, Expr}.


%% =====================================================================
%% @spec catch_expr_body(syntaxTree()) -> syntaxTree()
%%
%% @doc Returns the body subtree of a <code>catch_expr</code> node.
%%
%% @see catch_expr/1

catch_expr_body(Node) ->
    case unwrap(Node) of
	{'catch', _, Expr} ->
	    Expr;
	Node1 ->
	    data(Node1)
    end.


%% =====================================================================
%% @spec match_expr(Pattern::syntaxTree(), Body::syntaxTree()) ->
%%           syntaxTree()
%%
%% @doc Creates an abstract match-expression. The result represents
%% "<code><em>Pattern</em> = <em>Body</em></code>".
%%
%% @see match_expr_pattern/1
%% @see match_expr_body/1

-record(match_expr, {pattern, body}).

%% type(Node) = match_expr
%% data(Node) = #match_expr{pattern :: Pattern, body :: Body}
%%
%%	Pattern = Body = syntaxTree()
%%
%% `erl_parse' representation:
%%
%% {match, Pos, Pattern, Body}
%%
%%	Pattern = Body = erl_parse()

match_expr(Pattern, Body) ->
    tree(match_expr, #match_expr{pattern = Pattern, body = Body}).

revert_match_expr(Node) ->
    Pos = get_pos(Node),
    Pattern = match_expr_pattern(Node),
    Body = match_expr_body(Node),
    {match, Pos, Pattern, Body}.


%% =====================================================================
%% @spec match_expr_pattern(syntaxTree()) -> syntaxTree()
%%
%% @doc Returns the pattern subtree of a <code>match_expr</code> node.
%%
%% @see match_expr/2

match_expr_pattern(Node) ->
    case unwrap(Node) of
	{match, _, Pattern, _} ->
	    Pattern;
	Node1 ->
	    (data(Node1))#match_expr.pattern
    end.


%% =====================================================================
%% @spec match_expr_body(syntaxTree()) -> syntaxTree()
%%
%% @doc Returns the body subtree of a <code>match_expr</code> node.
%%
%% @see match_expr/2

match_expr_body(Node) ->
    case unwrap(Node) of
	{match, _, _, Body} ->
	    Body;
	Node1 ->
	    (data(Node1))#match_expr.body
    end.


%% =====================================================================
%% @spec operator(Name) -> syntaxTree()
%%	    Name = atom() | string()
%%
%% @doc Creates an abstract operator. The name of the operator is the
%% character sequence represented by <code>Name</code>. This is
%% analogous to the print name of an atom, but an operator is never
%% written within single-quotes; e.g., the result of
%% <code>operator('++')</code> represents "<code>++</code>" rather
%% than "<code>'++'</code>".
%%
%% @see operator_name/1
%% @see operator_literal/1
%% @see atom/1

%% type(Node) = operator
%% data(Node) = atom()

operator(Name) when atom(Name) ->
    tree(operator, Name);
operator(Name) ->
    tree(operator, list_to_atom(Name)).


%% =====================================================================
%% @spec operator_name(syntaxTree())-> atom()
%%
%% @doc Returns the name of an <code>operator</code> node. Note that
%% the name is returned as an atom.
%%
%% @see operator/1

operator_name(Node) ->
    data(Node).


%% =====================================================================
%% @spec operator_literal(syntaxTree())-> string()
%%
%% @doc Returns the literal string represented by an
%% <code>operator</code> node. This is simply the operator name as a
%% string.
%%
%% @see operator/1

operator_literal(Node) ->
    atom_to_list(operator_name(Node)).


%% =====================================================================
%% @spec infix_expr(Left::syntaxTree(), Operator::syntaxTree(),
%%                  Right::syntaxTree()) -> syntaxTree()
%%
%% @doc Creates an abstract infix operator expression. The result
%% represents "<code><em>Left</em> <em>Operator</em>
%% <em>Right</em></code>".
%%
%% @see infix_expr_left/1
%% @see infix_expr_right/1
%% @see infix_expr_operator/1
%% @see prefix_expr/2

-record(infix_expr, {operator, left, right}).

%% type(Node) = infix_expr
%% data(Node) = #infix_expr{left :: Left, operator :: Operator,
%%		            right :: Right}
%%
%%	Left = Operator = Right = syntaxTree()
%%
%% `erl_parse' representation:
%%
%% {op, Pos, Operator, Left, Right}
%%
%%	Operator = atom()
%%	Left = Right = erl_parse()

infix_expr(Left, Operator, Right) ->
    tree(infix_expr, #infix_expr{operator = Operator, left = Left,
				 right = Right}).

revert_infix_expr(Node) ->
    Pos = get_pos(Node),
    Operator = infix_expr_operator(Node),
    Left = infix_expr_left(Node),
    Right = infix_expr_right(Node),
    case type(Operator) of
	operator ->
	    %% Note that the operator itself is not revertible out
	    %% of context.
	    {op, Pos, operator_name(Operator), Left, Right};
	_ ->
	    Node
    end.


%% =====================================================================
%% @spec infix_expr_left(syntaxTree()) -> syntaxTree()
%%
%% @doc Returns the left argument subtree of an
%% <code>infix_expr</code> node.
%%
%% @see infix_expr/3

infix_expr_left(Node) ->
    case unwrap(Node) of
	{op, _, _, Left, _} ->
	    Left;
	Node1 ->
	    (data(Node1))#infix_expr.left
    end.


%% =====================================================================
%% @spec infix_expr_operator(syntaxTree()) -> syntaxTree()
%%
%% @doc Returns the operator subtree of an <code>infix_expr</code>
%% node.
%%
%% @see infix_expr/3

infix_expr_operator(Node) ->
    case unwrap(Node) of
	{op, Pos, Operator, _, _} ->
	    set_pos(operator(Operator), Pos);
	Node1 ->
	    (data(Node1))#infix_expr.operator
    end.


%% =====================================================================
%% @spec infix_expr_right(syntaxTree()) -> syntaxTree()
%%
%% @doc Returns the right argument subtree of an
%% <code>infix_expr</code> node.
%%
%% @see infix_expr/3

infix_expr_right(Node) ->
    case unwrap(Node) of
	{op, _, _, _, Right} ->
	    Right;
	Node1 ->
	    (data(Node1))#infix_expr.right
    end.


%% =====================================================================
%% @spec prefix_expr(Operator::syntaxTree(), Argument::syntaxTree()) ->
%%           syntaxTree()
%%
%% @doc Creates an abstract prefix operator expression. The result
%% represents "<code><em>Operator</em> <em>Argument</em></code>".
%%
%% @see prefix_expr_argument/1
%% @see prefix_expr_operator/1
%% @see infix_expr/3

-record(prefix_expr, {operator, argument}).

%% type(Node) = prefix_expr
%% data(Node) = #prefix_expr{operator :: Operator,
%%		             argument :: Argument}
%%
%%	Operator = Argument = syntaxTree()
%%
%% `erl_parse' representation:
%%
%% {op, Pos, Operator, Arg}
%%
%%	Operator = atom()
%%	Argument = erl_parse()

prefix_expr(Operator, Argument) ->
    tree(prefix_expr, #prefix_expr{operator = Operator,
				   argument = Argument}).

revert_prefix_expr(Node) ->
    Pos = get_pos(Node),
    Operator = prefix_expr_operator(Node),
    Argument = prefix_expr_argument(Node),
    case type(Operator) of
	operator ->
	    %% Note that the operator itself is not revertible out
	    %% of context.
	    {op, Pos, operator_name(Operator), Argument};
	_ ->
	    Node
    end.


%% =====================================================================
%% @spec prefix_expr_operator(syntaxTree()) -> syntaxTree()
%%
%% @doc Returns the operator subtree of a <code>prefix_expr</code>
%% node.
%%
%% @see prefix_expr/2

prefix_expr_operator(Node) ->
    case unwrap(Node) of
	{op, Pos, Operator, _} ->
	    set_pos(operator(Operator), Pos);
	Node1 ->
	    (data(Node1))#prefix_expr.operator
    end.


%% =====================================================================
%% @spec prefix_expr_argument(syntaxTree()) -> syntaxTree()
%%
%% @doc Returns the argument subtree of a <code>prefix_expr</code>
%% node.
%%
%% @see prefix_expr/2

prefix_expr_argument(Node) ->
    case unwrap(Node) of
	{op, _, _, Argument} ->
	    Argument;
	Node1 ->
	    (data(Node1))#prefix_expr.argument
    end.


%% =====================================================================
%% @spec record_field(Name) -> syntaxTree()
%% @equiv record_field(Name, none)

record_field(Name) ->
    record_field(Name, none).


%% =====================================================================
%% @spec record_field(Name::syntaxTree(), Value) -> syntaxTree()
%%	    Value = none | syntaxTree()
%%
%% @doc Creates an abstract record field specification. If
%% <code>Value</code> is <code>none</code>, the result represents
%% simply "<code><em>Name</em></code>", otherwise it represents
%% "<code><em>Name</em> = <em>Value</em></code>".
%%
%% @see record_field_name/1
%% @see record_field_value/1
%% @see record_expr/3

-record(record_field, {name, value}).

%% type(Node) = record_field
%% data(Node) = #record_field{name :: Name, value :: Value}
%%
%%	Name = Value = syntaxTree()

record_field(Name, Value) ->
    tree(record_field, #record_field{name = Name, value = Value}).


%% =====================================================================
%% @spec record_field_name(syntaxTree()) -> syntaxTree()
%%
%% @doc Returns the name subtree of a <code>record_field</code> node.
%%
%% @see record_field/2

record_field_name(Node) ->
    (data(Node))#record_field.name.


%% =====================================================================
%% @spec record_field_value(syntaxTree()) -> none | syntaxTree()
%%
%% @doc Returns the value subtree of a <code>record_field</code> node,
%% if any. If <code>Node</code> represents
%% "<code><em>Name</em></code>", <code>none</code> is
%% returned. Otherwise, if <code>Node</code> represents
%% "<code><em>Name</em> = <em>Value</em></code>", <code>Value</code>
%% is returned.
%%
%% @see record_field/2

record_field_value(Node) ->
    (data(Node))#record_field.value.


%% =====================================================================
%% @spec record_index_expr(Type::syntaxTree(), Field::syntaxTree()) ->
%%           syntaxTree()
%%
%% @doc Creates an abstract record field index expression. The result
%% represents "<code>#<em>Type</em>.<em>Field</em></code>".
%%
%% <p>(Note: the function name <code>record_index/2</code> is reserved
%% by the Erlang compiler, which is why that name could not be used
%% for this constructor.)</p>
%%
%% @see record_index_expr_type/1
%% @see record_index_expr_field/1
%% @see record_expr/3

-record(record_index_expr, {type, field}).

%% type(Node) = record_index_expr
%% data(Node) = #record_index_expr{type :: Type, field :: Field}
%%
%%	Type = Field = syntaxTree()
%%
%% `erl_parse' representation:
%%
%% {record_index, Pos, Type, Field}
%%
%%	Type = atom()
%%	Field = erl_parse()

record_index_expr(Type, Field) ->
    tree(record_index_expr, #record_index_expr{type = Type,
					       field = Field}).

revert_record_index_expr(Node) ->
    Pos = get_pos(Node),
    Type = record_index_expr_type(Node),
    Field = record_index_expr_field(Node),
    case type(Type) of
	atom ->
	    {record_index, Pos, concrete(Type), Field};
	_ ->
	    Node
    end.


%% =====================================================================
%% @spec record_index_expr_type(syntaxTree()) -> syntaxTree()
%%
%% @doc Returns the type subtree of a <code>record_index_expr</code>
%% node.
%%
%% @see record_index_expr/2

record_index_expr_type(Node) ->
    case unwrap(Node) of
	{record_index, Pos, Type, _} ->
	    set_pos(atom(Type), Pos);
	Node1 ->
	    (data(Node1))#record_index_expr.type
    end.


%% =====================================================================
%% @spec record_index_expr_field(syntaxTree()) -> syntaxTree()
%%
%% @doc Returns the field subtree of a <code>record_index_expr</code>
%% node.
%%
%% @see record_index_expr/2

record_index_expr_field(Node) ->
    case unwrap(Node) of
	{record_index, _, _, Field} ->
	    Field;
	Node1 ->
	    (data(Node1))#record_index_expr.field
    end.


%% =====================================================================
%% @spec record_access(Argument, Field) -> syntaxTree()
%% @equiv record_access(Argument, none, Field)

record_access(Argument, Field) ->
    record_access(Argument, none, Field).


%% =====================================================================
%% @spec record_access(Argument::syntaxTree(), Type,
%%                     Field::syntaxTree()) -> syntaxTree()
%%	    Type = none | syntaxTree()
%%
%% @doc Creates an abstract record field access expression. If
%% <code>Type</code> is not <code>none</code>, the result represents
%% "<code><em>Argument</em>#<em>Type</em>.<em>Field</em></code>".
%%
%% <p>If <code>Type</code> is <code>none</code>, the result represents
%% "<code><em>Argument</em>.<em>Field</em></code>". This is a special
%% form only allowed within Mnemosyne queries.</p>
%%
%% @see record_access/2
%% @see record_access_argument/1
%% @see record_access_type/1
%% @see record_access_field/1
%% @see record_expr/3
%% @see query_expr/1

-record(record_access, {argument, type, field}).

%% type(Node) = record_access
%% data(Node) = #record_access{argument :: Argument, type :: Type,
%%			       field :: Field}
%%
%%	Argument = Field = syntaxTree()
%%	Type = none | syntaxTree()
%%
%% `erl_parse' representation:
%%
%% {record_field, Pos, Argument, Type, Field}
%% {record_field, Pos, Argument, Field}
%%
%%	Argument = Field = erl_parse()
%%	Type = atom()

record_access(Argument, Type, Field) ->
    tree(record_access,#record_access{argument = Argument,
				      type = Type,
				      field = Field}).

revert_record_access(Node) ->
    Pos = get_pos(Node),
    Argument = record_access_argument(Node),
    Type = record_access_type(Node),
    Field = record_access_field(Node),
    if Type == none ->
	    {record_field, Pos, Argument, Field};
       true ->
	    case type(Type) of
		atom ->
		    {record_field, Pos,
		     Argument, concrete(Type), Field};
		_ ->
		    Node
	    end
    end.


%% =====================================================================
%% @spec record_access_argument(syntaxTree()) -> syntaxTree()
%%
%% @doc Returns the argument subtree of a <code>record_access</code>
%% node.
%%
%% @see record_access/3

record_access_argument(Node) ->
    case unwrap(Node) of
	{record_field, _, Argument, _} ->
	    Argument;
	{record_field, _, Argument, _, _} ->
	    Argument;
	Node1 ->
	    (data(Node1))#record_access.argument
    end.


%% =====================================================================
%% @spec record_access_type(syntaxTree()) -> none | syntaxTree()
%%
%% @doc Returns the type subtree of a <code>record_access</code> node,
%% if any. If <code>Node</code> represents
%% "<code><em>Argument</em>.<em>Field</em></code>", <code>none</code>
%% is returned, otherwise if <code>Node</code> represents
%% "<code><em>Argument</em>#<em>Type</em>.<em>Field</em></code>",
%% <code>Type</code> is returned.
%%
%% @see record_access/3

record_access_type(Node) ->
    case unwrap(Node) of
	{record_field, _, _, _} ->
	    none;
	{record_field, Pos, _, Type, _} ->
	    set_pos(atom(Type), Pos);
	Node1 ->
	    (data(Node1))#record_access.type
    end.


%% =====================================================================
%% @spec record_access_field(syntaxTree()) -> syntaxTree()
%%
%% @doc Returns the field subtree of a <code>record_access</code>
%% node.
%%
%% @see record_access/3

record_access_field(Node) ->
    case unwrap(Node) of
	{record_field, _, _, Field} ->
	    Field;
	{record_field, _, _, _, Field} ->
	    Field;
	Node1 ->
	    (data(Node1))#record_access.field
    end.


%% =====================================================================
%% @spec record_expr(Type, Fields) -> syntaxTree()
%% @equiv record_expr(none, Type, Fields)

record_expr(Type, Fields) ->
    record_expr(none, Type, Fields).


%% =====================================================================
%% @spec record_expr(Argument, Type::syntaxTree(),
%%                   Fields::[syntaxTree()]) -> syntaxTree()
%%	    Argument = none | syntaxTree()
%%
%% @doc Creates an abstract record expression. If <code>Fields</code> is
%% <code>[F1, ..., Fn]</code>, then if <code>Argument</code> is
%% <code>none</code>, the result represents
%% "<code>#<em>Type</em>{<em>F1</em>, ..., <em>Fn</em>}</code>",
%% otherwise it represents
%% "<code><em>Argument</em>#<em>Type</em>{<em>F1</em>, ...,
%% <em>Fn</em>}</code>".
%%
%% @see record_expr/2
%% @see record_expr_argument/1
%% @see record_expr_fields/1
%% @see record_expr_type/1
%% @see record_field/2
%% @see record_index_expr/2
%% @see record_access/3

-record(record_expr, {argument, type, fields}).

%% type(Node) = record_expr
%% data(Node) = #record_expr{argument :: Argument, type :: Type,
%%			     fields :: Fields}
%%
%%	Argument = none | syntaxTree()
%%	Type = syntaxTree
%%	Fields = [syntaxTree()]
%%
%% `erl_parse' representation:
%%
%% {record, Pos, Type, Fields}
%% {record, Pos, Argument, Type, Fields}
%%
%%	Argument = erl_parse()
%%	Type = atom()
%%	Fields = [Entry]
%%	Entry = {record_field, Pos, Field, Value}
%%	      | {record_field, Pos, Field}
%%	Field = Value = erl_parse()

record_expr(Argument, Type, Fields) ->
    tree(record_expr, #record_expr{argument = Argument,
				   type = Type, fields = Fields}).

revert_record_expr(Node) ->
    Pos = get_pos(Node),
    Argument = record_expr_argument(Node),
    Type = record_expr_type(Node),
    Fields = record_expr_fields(Node),
    case type(Type) of
	atom ->
	    T = concrete(Type),
	    Fs = fold_record_fields(Fields),
	    case Argument of
		none ->
		    {record, Pos, T, Fs};
		_ ->
		    {record, Pos, Argument, T, Fs}
	    end;
	_ ->
	    Node
    end.


%% =====================================================================
%% @spec record_expr_argument(syntaxTree()) -> none | syntaxTree()
%%
%% @doc Returns the argument subtree of a <code>record_expr</code> node,
%% if any. If <code>Node</code> represents
%% "<code>#<em>Type</em>{...}</code>", <code>none</code> is returned.
%% Otherwise, if <code>Node</code> represents
%% "<code><em>Argument</em>#<em>Type</em>{...}</code>",
%% <code>Argument</code> is returned.
%%
%% @see record_expr/3

record_expr_argument(Node) ->
    case unwrap(Node) of
	{record, _, _, _} ->
	    none;
	{record, _, Argument, _, _} ->
	    Argument;
	Node1 ->
	    (data(Node1))#record_expr.argument
    end.


%% =====================================================================
%% record_expr_type(Node) -> Type
%%
%%	    Node = Type = syntaxTree()
%%	    type(Node) = record_expr
%%
%% @doc Returns the type subtree of a <code>record_expr</code> node.
%%
%% @see record_expr/3

record_expr_type(Node) ->
    case unwrap(Node) of
	{record, Pos, Type, _} ->
	    set_pos(atom(Type), Pos);
	{record, Pos, _, Type, _} ->
	    set_pos(atom(Type), Pos);
	Node1 ->
	    (data(Node1))#record_expr.type
    end.


%% =====================================================================
%% record_expr_fields(Node) -> Fields
%%
%%	    Node = syntaxTree()
%%	    Fields = [syntaxTree()]
%%	    type(Node) = record_expr
%%
%% @doc Returns the list of field subtrees of a
%% <code>record_expr</code> node.
%%
%% @see record_expr/3

record_expr_fields(Node) ->
    case unwrap(Node) of
	{record, _, _, Fields} ->
	    unfold_record_fields(Fields);
	{record, _, _, _, Fields} ->
	    unfold_record_fields(Fields);
	Node1 ->
	    (data(Node1))#record_expr.fields
    end.


%% =====================================================================
%% @spec application(Module, Function::syntaxTree(),
%%                   Arguments::[syntaxTree()]) -> syntaxTree()
%%	    Module = none | syntaxTree()
%%
%% @doc Creates an abstract function application expression. (Utility
%% function.) If <code>Module</code> is <code>none</code>, this is
%% call is equivalent to <code>application(Function,
%% Arguments)</code>, otherwise it is equivalent to
%% <code>application(module_qualifier(Module, Function),
%% Arguments)</code>.
%%
%% @see application/2
%% @see module_qualifier/2

application(none, Name, Arguments) ->
    application(Name, Arguments);
application(Module, Name, Arguments) ->
    application(module_qualifier(Module, Name), Arguments).


%% =====================================================================
%% @spec application(Operator::syntaxTree(),
%%                   Arguments::[syntaxTree()]) -> syntaxTree()
%%
%% @doc Creates an abstract function application expression. If
%% <code>Arguments</code> is <code>[A1, ..., An]</code>, the result
%% represents "<code><em>Operator</em>(<em>A1</em>, ...,
%% <em>An</em>)</code>".
%%
%% @see application_operator/1
%% @see application_arguments/1
%% @see application/3

-record(application, {operator, arguments}).

%% type(Node) = application
%% data(Node) = #application{operator :: Operator,
%%			     arguments :: Arguments}
%%
%%	Operator = syntaxTree()
%%	Arguments = [syntaxTree()]
%%
%% `erl_parse' representation:
%%
%% {call, Pos, Fun, Args}
%%
%%	Operator = erl_parse()
%%	Arguments = [erl_parse()]

application(Operator, Arguments) ->
    tree(application, #application{operator = Operator,
				   arguments = Arguments}).

revert_application(Node) ->
    Pos = get_pos(Node),
    Operator = application_operator(Node),
    Arguments = application_arguments(Node),
    {call, Pos, Operator, Arguments}.


%% =====================================================================
%% @spec application_operator(syntaxTree()) -> syntaxTree()
%%
%% @doc Returns the operator subtree of an <code>application</code>
%% node.
%%
%% <p>Note: if <code>Node</code> represents
%% "<code><em>M</em>:<em>F</em>(...)</code>", then the result is the
%% subtree representing "<code><em>M</em>:<em>F</em></code>".</p>
%%
%% @see application/2
%% @see module_qualifier/2

application_operator(Node) ->
    case unwrap(Node) of
	{call, _, Operator, _} ->
	    Operator;
	Node1 ->
	    (data(Node1))#application.operator
    end.


%% =====================================================================
%% @spec application_arguments(syntaxTree()) -> [syntaxTree()]
%%
%% @doc Returns the list of argument subtrees of an
%% <code>application</code> node.
%%
%% @see application/2

application_arguments(Node) ->
    case unwrap(Node) of
	{call, _, _, Arguments} ->
	    Arguments;
	Node1 ->
	    (data(Node1))#application.arguments
    end.


%% =====================================================================
%% @spec list_comp(Template::syntaxTree(), Body::[syntaxTree()]) ->
%%           syntaxTree()
%%
%% @doc Creates an abstract list comprehension. If <code>Body</code> is
%% <code>[E1, ..., En]</code>, the result represents
%% "<code>[<em>Template</em> || <em>E1</em>, ..., <em>En</em>]</code>".
%%
%% @see list_comp_template/1
%% @see list_comp_body/1
%% @see generator/2

-record(list_comp, {template, body}).

%% type(Node) = list_comp
%% data(Node) = #list_comp{template :: Template, body :: Body}
%%
%%	Template = Node = syntaxTree()
%%	Body = [syntaxTree()]
%%
%% `erl_parse' representation:
%%
%% {lc, Pos, Template, Body}
%%
%%	Template = erl_parse()
%%	Body = [erl_parse()] \ []

list_comp(Template, Body) ->
    tree(list_comp, #list_comp{template = Template, body = Body}).

revert_list_comp(Node) ->
    Pos = get_pos(Node),
    Template = list_comp_template(Node),
    Body = list_comp_body(Node),
    {lc, Pos, Template, Body}.


%% =====================================================================
%% @spec list_comp_template(syntaxTree()) -> syntaxTree()
%%
%% @doc Returns the template subtree of a <code>list_comp</code> node.
%%
%% @see list_comp/2

list_comp_template(Node) ->
    case unwrap(Node) of
	{lc, _, Template, _} ->
	    Template;
	Node1 ->
	    (data(Node1))#list_comp.template
    end.


%% =====================================================================
%% @spec list_comp_body(syntaxTree()) -> [syntaxTree()]
%%
%% @doc Returns the list of body subtrees of a <code>list_comp</code>
%% node.
%%
%% @see list_comp/2

list_comp_body(Node) ->
    case unwrap(Node) of
	{lc, _, _, Body} ->
	    Body;
	Node1 ->
	    (data(Node1))#list_comp.body
    end.


%% =====================================================================
%% @spec query_expr(Body::syntaxTree()) -> syntaxTree()
%%
%% @doc Creates an abstract Mnemosyne query expression. The result
%% represents "<code>query <em>Body</em> end</code>".
%%
%% @see query_expr_body/1
%% @see record_access/2
%% @see rule/2

%% type(Node) = query_expr
%% data(Node) = syntaxTree()
%%
%% `erl_parse' representation:
%%
%% {'query', Pos, Body}
%%
%%	Body = erl_parse()

query_expr(Body) ->
    tree(query_expr, Body).

revert_query_expr(Node) ->
    Pos = get_pos(Node),
    Body = list_comp_body(Node),
    {'query', Pos, Body}.


%% =====================================================================
%% @spec query_expr_body(syntaxTree()) -> syntaxTree()
%%
%% @doc Returns the body subtree of a <code>query_expr</code> node.
%%
%% @see query_expr/1

query_expr_body(Node) ->
    case unwrap(Node) of
	{'query', _, Body} ->
	    Body;
	Node1 ->
	    data(Node1)
    end.


%% =====================================================================
%% @spec rule(Name::syntaxTree(), Clauses::[syntaxTree()]) ->
%%           syntaxTree()
%%
%% @doc Creates an abstract Mnemosyne rule. If <code>Clauses</code> is
%% <code>[C1, ..., Cn]</code>, the results represents
%% "<code><em>Name</em> <em>C1</em>; ...; <em>Name</em>
%% <em>Cn</em>.</code>". More exactly, if each <code>Ci</code>
%% represents "<code>(<em>Pi1</em>, ..., <em>Pim</em>) <em>Gi</em> ->
%% <em>Bi</em></code>", then the result represents
%% "<code><em>Name</em>(<em>P11</em>, ..., <em>P1m</em>) <em>G1</em> :-
%% <em>B1</em>; ...; <em>Name</em>(<em>Pn1</em>, ..., <em>Pnm</em>)
%% <em>Gn</em> :- <em>Bn</em>.</code>". Rules are source code forms.
%%
%% @see rule_name/1
%% @see rule_clauses/1
%% @see rule_arity/1
%% @see is_form/1
%% @see function/2

-record(rule, {name, clauses}).

%% type(Node) = rule
%% data(Node) = #rule{name :: Name, clauses :: Clauses}
%%
%%	Name = syntaxTree()
%%	Clauses = [syntaxTree()]
%%
%%	(See `function' for notes on why the arity is not stored.)
%%
%% `erl_parse' representation:
%%
%% {rule, Pos, Name, Arity, Clauses}
%%
%%	Name = atom()
%%	Arity = integer()
%%	Clauses = [Clause] \ []
%%	Clause = {clause, ...}
%%
%%	where the number of patterns in each clause should be equal to
%%	the integer `Arity'; see `clause' for documentation on
%%	`erl_parse' clauses.

rule(Name, Clauses) ->
    tree(rule, #rule{name = Name, clauses = Clauses}).

revert_rule(Node) ->
    Name = rule_name(Node),
    Clauses = [revert_clause(C) || C <- rule_clauses(Node)],
    Pos = get_pos(Node),
    case type(Name) of
	atom ->
	    A = rule_arity(Node),
	    {rule, Pos, concrete(Name), A, Clauses};
	_ ->
	    Node
    end.


%% =====================================================================
%% @spec rule_name(syntaxTree()) -> syntaxTree()
%%
%% @doc Returns the name subtree of a <code>rule</code> node.
%%
%% @see rule/2

rule_name(Node) ->
    case unwrap(Node) of
	{rule, Pos, Name, _, _} ->
	    set_pos(atom(Name), Pos);
	Node1 ->
	    (data(Node1))#rule.name
    end.

%% =====================================================================
%% @spec rule_clauses(syntaxTree()) -> [syntaxTree()]
%%
%% @doc Returns the list of clause subtrees of a <code>rule</code> node.
%%
%% @see rule/2

rule_clauses(Node) ->
    case unwrap(Node) of
	{rule, _, _, _, Clauses} ->
	    Clauses;
	Node1 ->
	    (data(Node1))#rule.clauses
    end.

%% =====================================================================
%% @spec rule_arity(Node::syntaxTree()) -> integer()
%%
%% @doc Returns the arity of a <code>rule</code> node. The result is the
%% number of parameter patterns in the first clause of the rule;
%% subsequent clauses are ignored.
%%
%% <p>An exception is thrown if <code>rule_clauses(Node)</code> returns
%% an empty list, or if the first element of that list is not a syntax
%% tree <code>C</code> of type <code>clause</code> such that
%% <code>clause_patterns(C)</code> is a nonempty list.</p>
%%
%% @see rule/2
%% @see rule_clauses/1
%% @see clause/3
%% @see clause_patterns/1

rule_arity(Node) ->
    %% Note that this never accesses the arity field of
    %% `erl_parse' rule nodes.
    length(clause_patterns(hd(rule_clauses(Node)))).


%% =====================================================================
%% @spec generator(Pattern::syntaxTree(), Body::syntaxTree()) ->
%%           syntaxTree()
%%
%% @doc Creates an abstract generator. The result represents
%% "<code><em>Pattern</em> &lt;- <em>Body</em></code>".
%%
%% @see generator_pattern/1
%% @see generator_body/1
%% @see list_comp/2

-record(generator, {pattern, body}).

%% type(Node) = generator
%% data(Node) = #generator{pattern :: Pattern, body :: Body}
%%
%%	Pattern = Argument = syntaxTree()
%%
%% `erl_parse' representation:
%%
%% {generate, Pos, Pattern, Body}
%%
%%	Pattern = Body = erl_parse()

generator(Pattern, Body) ->
    tree(generator, #generator{pattern = Pattern, body = Body}).

revert_generator(Node) ->
    Pos = get_pos(Node),
    Pattern = generator_pattern(Node),
    Body = generator_body(Node),
    {generate, Pos, Pattern, Body}.


%% =====================================================================
%% @spec generator_pattern(syntaxTree()) -> syntaxTree()
%%
%% @doc Returns the pattern subtree of a <code>generator</code> node.
%%
%% @see generator/2

generator_pattern(Node) ->
    case unwrap(Node) of
	{generate, _, Pattern, _} ->
	    Pattern;
	Node1 ->
	    (data(Node1))#generator.pattern
    end.


%% =====================================================================
%% @spec generator_body(syntaxTree()) -> syntaxTree()
%%
%% @doc Returns the body subtree of a <code>generator</code> node.
%%
%% @see generator/2

generator_body(Node) ->
    case unwrap(Node) of
	{generate, _, _, Body} ->
	    Body;
	Node1 ->
	    (data(Node1))#generator.body
    end.


%% =====================================================================
%% @spec block_expr(Body::[syntaxTree()]) -> syntaxTree()
%%
%% @doc Creates an abstract block expression. If <code>Body</code> is
%% <code>[B1, ..., Bn]</code>, the result represents "<code>begin
%% <em>B1</em>, ..., <em>Bn</em> end</code>".
%%
%% @see block_expr_body/1

%% type(Node) = block_expr
%% data(Node) = Body
%%
%%	Body = [syntaxTree()]
%%
%% `erl_parse' representation:
%%
%% {block, Pos, Body}
%%
%%	    Body = [erl_parse()] \ []

block_expr(Body) ->
    tree(block_expr, Body).

revert_block_expr(Node) ->
    Pos = get_pos(Node),
    Body = block_expr_body(Node),
    {block, Pos, Body}.


%% =====================================================================
%% @spec block_expr_body(syntaxTree()) -> [syntaxTree()]
%%
%% @doc Returns the list of body subtrees of a <code>block_expr</code>
%% node.
%%
%% @see block_expr/1

block_expr_body(Node) ->
    case unwrap(Node) of
	{block, _, Body} ->
	    Body;
	Node1 ->
	    data(Node1)
    end.


%% =====================================================================
%% @spec if_expr(Clauses::[syntaxTree()]) -> syntaxTree()
%%
%% @doc Creates an abstract if-expression. If <code>Clauses</code> is
%% <code>[C1, ..., Cn]</code>, the result represents "<code>if
%% <em>C1</em>; ...; <em>Cn</em> end</code>". More exactly, if each
%% <code>Ci</code> represents "<code>() <em>Gi</em> ->
%% <em>Bi</em></code>", then the result represents "<code>if
%% <em>G1</em> -> <em>B1</em>; ...; <em>Gn</em> -> <em>Bn</em>
%% end</code>".
%%
%% @see if_expr_clauses/1
%% @see clause/3
%% @see case_expr/2

%% type(Node) = if_expr
%% data(Node) = Clauses
%%
%%	Clauses = [syntaxTree()]
%%
%% `erl_parse' representation:
%%
%% {'if', Pos, Clauses}
%%
%%	Clauses = [Clause] \ []
%%	Clause = {clause, ...}
%%
%%	See `clause' for documentation on `erl_parse' clauses.

if_expr(Clauses) ->
    tree(if_expr, Clauses).

revert_if_expr(Node) ->
    Pos = get_pos(Node),
    Clauses = [revert_clause(C) || C <- if_expr_clauses(Node)],
    {'if', Pos, Clauses}.


%% =====================================================================
%% if_expr_clauses(Node) -> Clauses
%%
%%	    Node = syntaxTree()
%%	    Clauses = [syntaxTree()]
%%	    type(Node) = if_expr
%%
%% @doc Returns the list of clause subtrees of an <code>if_expr</code>
%% node.
%%
%% @see if_expr/1

if_expr_clauses(Node) ->
    case unwrap(Node) of
	{'if', _, Clauses} ->
	    Clauses;
	Node1 ->
	    data(Node1)
    end.


%% =====================================================================
%% @spec case_expr(Argument::syntaxTree(), Clauses::[syntaxTree()]) ->
%%           syntaxTree()
%%
%% @doc Creates an abstract case-expression. If <code>Clauses</code> is
%% <code>[C1, ..., Cn]</code>, the result represents "<code>case
%% <em>Argument</em> of <em>C1</em>; ...; <em>Cn</em> end</code>". More
%% exactly, if each <code>Ci</code> represents "<code>(<em>Pi</em>)
%% <em>Gi</em> -> <em>Bi</em></code>", then the result represents
%% "<code>case <em>Argument</em> of <em>P1</em> <em>G1</em> ->
%% <em>B1</em>; ...; <em>Pn</em> <em>Gn</em> -> <em>Bn</em> end</code>".
%%
%% @see case_expr_clauses/1
%% @see case_expr_argument/1
%% @see clause/3
%% @see if_expr/1
%% @see cond_expr/1

-record(case_expr, {argument, clauses}).

%% type(Node) = case_expr
%% data(Node) = #case_expr{argument :: Argument,
%%			   clauses :: Clauses}
%%
%%	Argument = syntaxTree()
%%	Clauses = [syntaxTree()]
%%
%% `erl_parse' representation:
%%
%% {'case', Pos, Argument, Clauses}
%%
%%	Argument = erl_parse()
%%	Clauses = [Clause] \ []
%%	Clause = {clause, ...}
%%
%%	See `clause' for documentation on `erl_parse' clauses.

case_expr(Argument, Clauses) ->
    tree(case_expr, #case_expr{argument = Argument,
			       clauses = Clauses}).

revert_case_expr(Node) ->
    Pos = get_pos(Node),
    Argument = case_expr_argument(Node),
    Clauses = [revert_clause(C) || C <- case_expr_clauses(Node)],
    {'case', Pos, Argument, Clauses}.


%% =====================================================================
%% @spec case_expr_argument(syntaxTree()) -> syntaxTree()
%%
%% @doc Returns the argument subtree of a <code>case_expr</code> node.
%%
%% @see case_expr/2

case_expr_argument(Node) ->
    case unwrap(Node) of
	{'case', _, Argument, _} ->
	    Argument;
	Node1 ->
	    (data(Node1))#case_expr.argument
    end.


%% =====================================================================
%% @spec case_expr_clauses(syntaxTree()) -> [syntaxTree()]
%%
%% @doc Returns the list of clause subtrees of a <code>case_expr</code>
%% node.
%%
%% @see case_expr/2

case_expr_clauses(Node) ->
    case unwrap(Node) of
	{'case', _, _, Clauses} ->
	    Clauses;
	Node1 ->
	    (data(Node1))#case_expr.clauses
    end.


%% =====================================================================
%% @spec cond_expr(Clauses::[syntaxTree()]) -> syntaxTree()
%%
%% @doc Creates an abstract cond-expression. If <code>Clauses</code> is
%% <code>[C1, ..., Cn]</code>, the result represents "<code>cond
%% <em>C1</em>; ...; <em>Cn</em> end</code>". More exactly, if each
%% <code>Ci</code> represents "<code>() <em>Ei</em> ->
%% <em>Bi</em></code>", then the result represents "<code>cond
%% <em>E1</em> -> <em>B1</em>; ...; <em>En</em> -> <em>Bn</em>
%% end</code>".
%%
%% @see cond_expr_clauses/1
%% @see clause/3
%% @see case_expr/2

%% type(Node) = cond_expr
%% data(Node) = Clauses
%%
%%	Clauses = [syntaxTree()]
%%
%% `erl_parse' representation:
%%
%% {'cond', Pos, Clauses}
%%
%%	Clauses = [Clause] \ []
%%	Clause = {clause, ...}
%%
%%	See `clause' for documentation on `erl_parse' clauses.

cond_expr(Clauses) ->
    tree(cond_expr, Clauses).

revert_cond_expr(Node) ->
    Pos = get_pos(Node),
    Clauses = [revert_clause(C) || C <- cond_expr_clauses(Node)],
    {'cond', Pos, Clauses}.


%% =====================================================================
%% cond_expr_clauses(Node) -> Clauses
%%
%%	    Node = syntaxTree()
%%	    Clauses = [syntaxTree()]
%%	    type(Node) = cond_expr
%%
%% @doc Returns the list of clause subtrees of a <code>cond_expr</code>
%% node.
%%
%% @see cond_expr/1

cond_expr_clauses(Node) ->
    case unwrap(Node) of
	{'cond', _, Clauses} ->
	    Clauses;
	Node1 ->
	    data(Node1)
    end.


%% =====================================================================
%% @spec receive_expr(Clauses) -> syntaxTree()
%% @equiv receive_expr(Clauses, none, [])

receive_expr(Clauses) ->
    receive_expr(Clauses, none, []).


%% =====================================================================
%% @spec receive_expr(Clauses::[syntaxTree()], Timeout,
%%                    Action::[syntaxTree()]) -> syntaxTree()
%%	    Timeout = none | syntaxTree()
%%
%% @doc Creates an abstract receive-expression. If <code>Timeout</code>
%% is <code>none</code>, the result represents "<code>receive
%% <em>C1</em>; ...; <em>Cn</em> end</code>" (the <code>Action</code>
%% argument is ignored). Otherwise, if <code>Clauses</code> is
%% <code>[C1, ..., Cn]</code> and <code>Action</code> is <code>[A1, ...,
%% Am]</code>, the result represents "<code>receive <em>C1</em>; ...;
%% <em>Cn</em> after <em>Timeout</em> -> <em>A1</em>, ..., <em>Am</em>
%% end</code>". More exactly, if each <code>Ci</code> represents
%% "<code>(<em>Pi</em>) <em>Gi</em> -> <em>Bi</em></code>", then the
%% result represents "<code>receive <em>P1</em> <em>G1</em> ->
%% <em>B1</em>; ...; <em>Pn</em> <em>Gn</em> -> <em>Bn</em> ...
%% end</code>".
%%
%% <p>Note that in Erlang, a receive-expression must have at least one
%% clause if no timeout part is specified.</p>
%%
%% @see receive_expr_clauses/1
%% @see receive_expr_timeout/1
%% @see receive_expr_action/1
%% @see receive_expr/1
%% @see clause/3
%% @see case_expr/2

-record(receive_expr, {clauses, timeout, action}).

%% type(Node) = receive_expr
%% data(Node) = #receive_expr{clauses :: Clauses,
%%			      timeout :: Timeout,
%%			      action :: Action}
%%
%%	Clauses = [syntaxTree()]
%%	Timeout = none | syntaxTree()
%%	Action = [syntaxTree()]
%%
%% `erl_parse' representation:
%%
%% {'receive', Pos, Clauses}
%% {'receive', Pos, Clauses, Timeout, Action}
%%
%%	Clauses = [Clause] \ []
%%	Clause = {clause, ...}
%%	Timeout = erl_parse()
%%	Action = [erl_parse()] \ []
%%
%%	See `clause' for documentation on `erl_parse' clauses.

receive_expr(Clauses, Timeout, Action) ->
    %% If `Timeout' is `none', we always replace the actual
    %% `Action' argument with an empty list, since
    %% `receive_expr_action' should in that case return the empty
    %% list regardless.
    Action1 = case Timeout of
		  none -> [];
		  _ -> Action
	      end,
    tree(receive_expr, #receive_expr{clauses = Clauses,
				     timeout = Timeout,
				     action = Action1}).

revert_receive_expr(Node) ->
    Pos = get_pos(Node),
    Clauses = [revert_clause(C) || C <- receive_expr_clauses(Node)],
    Timeout = receive_expr_timeout(Node),
    Action = receive_expr_action(Node),
    case Timeout of
	none ->
	    {'receive', Pos, Clauses};
	_ ->
	    {'receive', Pos, Clauses, Timeout, Action}
    end.


%% =====================================================================
%% @spec receive_expr_clauses(syntaxTree()) -> [syntaxTree()]
%%	     type(Node) = receive_expr
%%
%% @doc Returns the list of clause subtrees of a
%% <code>receive_expr</code> node.
%%
%% @see receive_expr/3

receive_expr_clauses(Node) ->
    case unwrap(Node) of
	{'receive', _, Clauses} ->
	    Clauses;
	{'receive', _, Clauses, _, _} ->
	    Clauses;
	Node1 ->
	    (data(Node1))#receive_expr.clauses
    end.


%% =====================================================================
%% @spec receive_expr_timeout(Node::syntaxTree()) -> Timeout
%%	     Timeout = none | syntaxTree()
%%
%% @doc Returns the timeout subtree of a <code>receive_expr</code> node,
%% if any. If <code>Node</code> represents "<code>receive <em>C1</em>;
%% ...; <em>Cn</em> end</code>", <code>none</code> is returned.
%% Otherwise, if <code>Node</code> represents "<code>receive
%% <em>C1</em>; ...; <em>Cn</em> after <em>Timeout</em> -> <em>A1</em>,
%% ..., <em>Am</em> end</code>", <code>[A1, ..., Am]</code> is returned.
%%
%% @see receive_expr/3

receive_expr_timeout(Node) ->
    case unwrap(Node) of
	{'receive', _, _} ->
	    none;
	{'receive', _, _, Timeout, _} ->
	    Timeout;
	Node1 ->
	    (data(Node1))#receive_expr.timeout
    end.


%% =====================================================================
%% @spec receive_expr_action(Node::syntaxTree()) -> [syntaxTree()]
%%
%% @doc Returns the list of action body subtrees of a
%% <code>receive_expr</code> node. If <code>Node</code> represents
%% "<code>receive <em>C1</em>; ...; <em>Cn</em> end</code>", this is the
%% empty list.
%%
%% @see receive_expr/3

receive_expr_action(Node) ->
    case unwrap(Node) of
	{'receive', _, _} ->
	    [];
	{'receive', _, _, _, Action} ->
	    Action;
	Node1 ->
	    (data(Node1))#receive_expr.action
    end.


%% =====================================================================
%% @spec try_expr(Body::syntaxTree(), Handlers::[syntaxTree()]) ->
%%           syntaxTree()
%% @equiv try_expr(Body, [], Handlers)

try_expr(Body, Handlers) ->
    try_expr(Body, [], Handlers).


%% =====================================================================
%% @spec try_expr(Body::syntaxTree(), Clauses::[syntaxTree()],
%%           Handlers::[syntaxTree()]) -> syntaxTree()
%% @equiv try_expr(Body, Clauses, Handlers, [])

try_expr(Body, Clauses, Handlers) ->
    try_expr(Body, Clauses, Handlers, []).


%% =====================================================================
%% @spec try_after_expr(Body::syntaxTree(), After::[syntaxTree()]) ->
%%           syntaxTree()
%% @equiv try_expr(Body, [], [], After)

try_after_expr(Body, After) ->
    try_expr(Body, [], [], After).


%% =====================================================================
%% @spec try_expr(Body::[syntaxTree()], Clauses::[syntaxTree()],
%%                Handlers::[syntaxTree()], After::[syntaxTree()]) ->
%%           syntaxTree()
%%
%% @doc Creates an abstract try-expression. If <code>Body</code> is
%% <code>[B1, ..., Bn]</code>, <code>Clauses</code> is <code>[C1, ...,
%% Cj]</code>, <code>Handlers</code> is <code>[H1, ..., Hk]</code>, and
%% <code>After</code> is <code>[A1, ..., Am]</code>, the result
%% represents "<code>try <em>B1</em>, ..., <em>Bn</em> of <em>C1</em>;
%% ...; <em>Cj</em> catch <em>H1</em>; ...; <em>Hk</em> after
%% <em>A1</em>, ..., <em>Am</em> end</code>". More exactly, if each
%% <code>Ci</code> represents "<code>(<em>CPi</em>) <em>CGi</em> ->
%% <em>CBi</em></code>", and each <code>Hi</code> represents
%% "<code>(<em>HPi</em>) <em>HGi</em> -> <em>HBi</em></code>", then the
%% result represents "<code>try <em>B1</em>, ..., <em>Bn</em> of
%% <em>CP1</em> <em>CG1</em> -> <em>CB1</em>; ...; <em>CPj</em>
%% <em>CGj</em> -> <em>CBj</em> catch <em>HP1</em> <em>HG1</em> ->
%% <em>HB1</em>; ...; <em>HPk</em> <em>HGk</em> -> <em>HBk</em> after
%% <em>A1</em>, ..., <em>Am</em> end</code>"; cf.
%% <code>case_expr/2</code>. If <code>Clauses</code> is the empty list,
%% the <code>of ...</code> section is left out. If <code>After</code> is
%% the empty list, the <code>after ...</code> section is left out. If
%% <code>Handlers</code> is the empty list, and <code>After</code> is
%% nonempty, the <code>catch ...</code> section is left out.
%%
%% @see try_expr_body/1
%% @see try_expr_clauses/1
%% @see try_expr_handlers/1
%% @see try_expr_after/1
%% @see try_expr/2
%% @see try_expr/3
%% @see try_after_expr/2
%% @see clause/3
%% @see class_qualifier/2
%% @see case_expr/2

-record(try_expr, {body, clauses, handlers, 'after'}).

%% type(Node) = try_expr
%% data(Node) = #try_expr{body :: Body,
%%			  clauses :: Clauses,
%%			  handlers :: Clauses,
%%			  after :: Body}
%%
%%	Body = syntaxTree()
%%	Clauses = [syntaxTree()]
%%
%% `erl_parse' representation:
%%
%% {'try', Pos, Body, Clauses, Handlers, After}
%%
%%	Body = [erl_parse()]
%%	Clauses = [Clause]
%%	Handlers = [Clause] \ []
%%	Clause = {clause, ...}
%%	After = [erl_parse()]
%%
%%	See `clause' for documentation on `erl_parse' clauses.

try_expr(Body, Clauses, Handlers, After) ->
    tree(try_expr, #try_expr{body = Body,
			     clauses = Clauses,
			     handlers = Handlers,
			     'after' = After}).

revert_try_expr(Node) ->
    Pos = get_pos(Node),
    Body = try_expr_body(Node),
    Clauses = [revert_clause(C) || C <- try_expr_clauses(Node)],
    Handlers = [revert_try_clause(C) || C <- try_expr_handlers(Node)],
    After = try_expr_after(Node),
    {'try', Pos, Body, Clauses, Handlers, After}.


%% =====================================================================
%% @spec try_expr_body(syntaxTree()) -> [syntaxTree()]
%%
%% @doc Returns the list of body subtrees of a <code>try_expr</code>
%% node.
%%
%% @see try_expr/4

try_expr_body(Node) ->
    case unwrap(Node) of
	{'try', _, Body, _, _, _} ->
	    Body;
	Node1 ->
	    (data(Node1))#try_expr.body
    end.


%% =====================================================================
%% @spec try_expr_clauses(Node::syntaxTree()) -> [syntaxTree()]
%%
%% @doc Returns the list of case-clause subtrees of a
%% <code>try_expr</code> node. If <code>Node</code> represents
%% "<code>try <em>Body</em> catch <em>H1</em>; ...; <em>Hn</em>
%% end</code>", the result is the empty list.
%%
%% @see try_expr/4

try_expr_clauses(Node) ->
    case unwrap(Node) of
	{'try', _, _, Clauses, _, _} ->
	    Clauses;
	Node1 ->
	    (data(Node1))#try_expr.clauses
    end.


%% =====================================================================
%% @spec try_expr_handlers(syntaxTree()) -> [syntaxTree()]
%%
%% @doc Returns the list of handler-clause subtrees of a
%% <code>try_expr</code> node.
%%
%% @see try_expr/4

try_expr_handlers(Node) ->
    case unwrap(Node) of
	{'try', _, _, _, Handlers, _} ->
	    unfold_try_clauses(Handlers);
	Node1 ->
	    (data(Node1))#try_expr.handlers
    end.


%% =====================================================================
%% @spec try_expr_after(syntaxTree()) -> [syntaxTree()]
%%
%% @doc Returns the list of "after" subtrees of a <code>try_expr</code>
%% node.
%%
%% @see try_expr/4

try_expr_after(Node) ->
    case unwrap(Node) of
	{'try', _, _, _, _, After} ->
	    After;
	Node1 ->
	    (data(Node1))#try_expr.'after'
    end.


%% =====================================================================
%% @spec class_qualifier(Class::syntaxTree(), Body::syntaxTree()) ->
%%           syntaxTree()
%%
%% @doc Creates an abstract class qualifier. The result represents
%% "<code><em>Class</em>:<em>Body</em></code>".
%%
%% @see class_qualifier_argument/1
%% @see class_qualifier_body/1
%% @see try_expr/4

-record(class_qualifier, {class, body}).

%% type(Node) = class_qualifier
%% data(Node) = #class_qualifier{class :: Class, body :: Body}
%%
%%	Class = Body = syntaxTree()

class_qualifier(Class, Body) ->
    tree(class_qualifier,
	 #class_qualifier{class = Class, body = Body}).


%% =====================================================================
%% @spec class_qualifier_argument(syntaxTree()) -> syntaxTree()
%%
%% @doc Returns the argument (the class) subtree of a
%% <code>class_qualifier</code> node.
%%
%% @see class_qualifier/1

class_qualifier_argument(Node) ->
    (data(Node))#class_qualifier.class.


%% =====================================================================
%% @spec class_qualifier_body(syntaxTree()) -> syntaxTree()
%%
%% @doc Returns the body subtree of a <code>class_qualifier</code> node.
%%
%% @see class_qualifier/1

class_qualifier_body(Node) ->
    (data(Node))#class_qualifier.body.


%% =====================================================================
%% @spec implicit_fun(Name::syntaxTree(), Arity::syntaxTree()) ->
%%           syntaxTree()
%%
%% @doc Creates an abstract "implicit fun" expression. (Utility
%% function.) If <code>Arity</code> is <code>none</code>, this is
%% equivalent to <code>implicit_fun(Name)</code>, otherwise it is
%% equivalent to <code>implicit_fun(arity_qualifier(Name,
%% Arity))</code>.
%%
%% @see implicit_fun/1


implicit_fun(Name, none) ->
    implicit_fun(Name);
implicit_fun(Name, Arity) ->
    implicit_fun(arity_qualifier(Name, Arity)).


%% =====================================================================
%% @spec implicit_fun(Name::syntaxTree()) -> syntaxTree()
%%
%% @doc Creates an abstract "implicit fun" expression. The result
%% represents "<code>fun <em>Name</em></code>".
%%
%% @see implicit_fun_name/1
%% @see implicit_fun/2

%% type(Node) = implicit_fun
%% data(Node) = syntaxTree()
%%
%% `erl_parse' representation:
%%
%% {'fun', Pos, {function, Name, Arity}}
%%
%%	Name = atom()
%%	Arity = integer()

implicit_fun(Name) ->
    tree(implicit_fun, Name).

revert_implicit_fun(Node) ->
    Pos = get_pos(Node),
    Name = implicit_fun_name(Node),
    case type(Name) of
	arity_qualifier ->
	    F = arity_qualifier_body(Name),
	    A = arity_qualifier_argument(Name),
	    case {type(F), type(A)} of
		{atom, integer} ->
		    {'fun', Pos,
		     {function, concrete(F), concrete(A)}};
		_ ->
		    Node
	    end;
	_ ->
	    Node
    end.


%% =====================================================================
%% @spec implicit_fun_name(Node::syntaxTree()) -> syntaxTree()
%%
%% @doc Returns the name subtree of an <code>implicit_fun</code> node.
%%
%% <p>Note: if <code>Node</code> represents "<code>fun
%% <em>N</em>/<em>A</em></code>", then the result is the subtree
%% representing "<code><em>N</em>/<em>A</em></code>".</p>
%%
%% @see implicit_fun/1

implicit_fun_name(Node) ->
    case unwrap(Node) of
	{'fun', Pos, {function, Atom, Arity}} ->
	    arity_qualifier(set_pos(atom(Atom), Pos),
			    set_pos(integer(Arity), Pos));
	Node1 ->
	    data(Node1)
    end.


%% =====================================================================
%% @spec fun_expr(Clauses::[syntaxTree()]) -> syntaxTree()
%%
%% @doc Creates an abstract fun-expression. If <code>Clauses</code> is
%% <code>[C1, ..., Cn]</code>, the result represents "<code>fun
%% <em>C1</em>; ...; <em>Cn</em> end</code>". More exactly, if each
%% <code>Ci</code> represents "<code>(<em>Pi1</em>, ..., <em>Pim</em>)
%% <em>Gi</em> -> <em>Bi</em></code>", then the result represents
%% "<code>fun (<em>P11</em>, ..., <em>P1m</em>) <em>G1</em> ->
%% <em>B1</em>; ...; (<em>Pn1</em>, ..., <em>Pnm</em>) <em>Gn</em> ->
%% <em>Bn</em> end</code>".
%%
%% @see fun_expr_clauses/1
%% @see fun_expr_arity/1

%% type(Node) = fun_expr
%% data(Node) = Clauses
%%
%%	Clauses = [syntaxTree()]
%%
%%	(See `function' for notes; e.g. why the arity is not stored.)
%%
%% `erl_parse' representation:
%%
%% {'fun', Pos, {clauses, Clauses}}
%%
%%	Clauses = [Clause] \ []
%%	Clause = {clause, ...}
%%
%%	See `clause' for documentation on `erl_parse' clauses.

fun_expr(Clauses) ->
    tree(fun_expr, Clauses).

revert_fun_expr(Node) ->
    Clauses = [revert_clause(C) || C <- fun_expr_clauses(Node)],
    Pos = get_pos(Node),
    {'fun', Pos, {clauses, Clauses}}.


%% =====================================================================
%% @spec fun_expr_clauses(syntaxTree()) -> [syntaxTree()]
%%
%% @doc Returns the list of clause subtrees of a <code>fun_expr</code>
%% node.
%%
%% @see fun_expr/1

fun_expr_clauses(Node) ->
    case unwrap(Node) of
	{'fun', _, {clauses, Clauses}} ->
	    Clauses;
	Node1 ->
	    data(Node1)
    end.


%% =====================================================================
%% @spec fun_expr_arity(syntaxTree()) -> integer()
%%
%% @doc Returns the arity of a <code>fun_expr</code> node. The result is
%% the number of parameter patterns in the first clause of the
%% fun-expression; subsequent clauses are ignored.
%%
%% <p>An exception is thrown if <code>fun_expr_clauses(Node)</code>
%% returns an empty list, or if the first element of that list is not a
%% syntax tree <code>C</code> of type <code>clause</code> such that
%% <code>clause_patterns(C)</code> is a nonempty list.</p>
%%
%% @see fun_expr/1
%% @see fun_expr_clauses/1
%% @see clause/3
%% @see clause_patterns/1

fun_expr_arity(Node) ->
    length(clause_patterns(hd(fun_expr_clauses(Node)))).


%% =====================================================================
%% @spec parentheses(Body::syntaxTree()) -> syntaxTree()
%%
%% @doc Creates an abstract parenthesised expression. The result
%% represents "<code>(<em>Body</em>)</code>", independently of the
%% context.
%%
%% @see parentheses_body/1

%% type(Node) = parentheses
%% data(Node) = syntaxTree()

parentheses(Expr) ->
    tree(parentheses, Expr).

revert_parentheses(Node) ->
    parentheses_body(Node).


%% =====================================================================
%% @spec parentheses_body(syntaxTree()) -> syntaxTree()
%%
%% @doc Returns the body subtree of a <code>parentheses</code> node.
%%
%% @see parentheses/1

parentheses_body(Node) ->
    data(Node).


%% =====================================================================
%% @spec macro(Name) -> syntaxTree()
%% @equiv macro(Name, none)

macro(Name) ->
    macro(Name, none).


%% =====================================================================
%% @spec macro(Name::syntaxTree(), Arguments) -> syntaxTree()
%%	    Arguments = none | [syntaxTree()]
%%
%% @doc Creates an abstract macro application. If <code>Arguments</code>
%% is <code>none</code>, the result represents
%% "<code>?<em>Name</em></code>", otherwise, if <code>Arguments</code>
%% is <code>[A1, ..., An]</code>, the result represents
%% "<code>?<em>Name</em>(<em>A1</em>, ..., <em>An</em>)</code>".
%%
%% <p>Notes: if <code>Arguments</code> is the empty list, the result
%% will thus represent "<code>?<em>Name</em>()</code>", including a pair
%% of matching parentheses.</p>
%%
%% <p>The only syntactical limitation imposed by the preprocessor on the
%% arguments to a macro application (viewed as sequences of tokens) is
%% that they must be balanced with respect to parentheses, brackets,
%% <code>begin ... end</code>, <code>case ... end</code>, etc. The
%% <code>text</code> node type can be used to represent arguments which
%% are not regular Erlang constructs.</p>
%%
%% @see macro_name/1
%% @see macro_arguments/1
%% @see macro/1
%% @see text/1

-record(macro, {name, arguments}).

%% type(Node) = macro
%% data(Node) = #macro{name :: Name, arguments :: Arguments}
%%
%%	Name = syntaxTree()
%%	Arguments = none | [syntaxTree()]

macro(Name, Arguments) ->
    tree(macro, #macro{name = Name, arguments = Arguments}).


%% =====================================================================
%% @spec macro_name(syntaxTree()) -> syntaxTree()
%%
%% @doc Returns the name subtree of a <code>macro</code> node.
%%
%% @see macro/2

macro_name(Node) ->
    (data(Node))#macro.name.


%% =====================================================================
%% @spec macro_arguments(Node::syntaxTree()) -> none | [syntaxTree()]
%%
%% @doc Returns the list of argument subtrees of a <code>macro</code>
%% node, if any. If <code>Node</code> represents
%% "<code>?<em>Name</em></code>", <code>none</code> is returned.
%% Otherwise, if <code>Node</code> represents
%% "<code>?<em>Name</em>(<em>A1</em>, ..., <em>An</em>)</code>",
%% <code>[A1, ..., An]</code> is returned.
%%
%% @see macro/2

macro_arguments(Node) ->
    (data(Node))#macro.arguments.


%% =====================================================================
%% @spec abstract(Term::term()) -> syntaxTree()
%%
%% @doc Returns the syntax tree corresponding to an Erlang term.
%% <code>Term</code> must be a literal term, i.e., one that can be
%% represented as a source code literal. Thus, it may not contain a
%% process identifier, port, reference, binary or function value as a
%% subterm. The function recognises printable strings, in order to get a
%% compact and readable representation. Evaluation fails with reason
%% <code>badarg</code> if <code>Term</code> is not a literal term.
%%
%% @see concrete/1
%% @see is_literal/1

abstract([H | T]) when integer(H) ->
    case is_printable([H | T]) of
	true ->
	    string([H | T]);
	false ->
	    abstract_tail(H, T)
    end;
abstract([H | T]) ->
    abstract_tail(H, T);
abstract(T) when atom(T) ->
    atom(T);
abstract(T) when integer(T) ->
    integer(T);
abstract(T) when float(T) ->
    make_float(T);    % (not `float', which would call the BIF)
abstract([]) ->
    nil();
abstract(T) when tuple(T) ->
    tuple(abstract_list(tuple_to_list(T)));
abstract(T) when binary(T) ->
    binary([binary_field(integer(B)) || B <- binary_to_list(T)]);
abstract(T) ->
    erlang:fault({badarg, T}).

abstract_list([T | Ts]) ->
    [abstract(T) | abstract_list(Ts)];
abstract_list([]) ->
    [].

%% This is entered when we might have a sequence of conses that might or
%% might not be a proper list, but which should not be considered as a
%% potential string, to avoid unnecessary checking. This also avoids
%% that a list like `[4711, 42, 10]' could be abstracted to represent
%% `[4711 | "*\n"]'.

abstract_tail(H1, [H2 | T]) ->
    %% Recall that `cons' does "intelligent" composition
    cons(abstract(H1), abstract_tail(H2, T));
abstract_tail(H, T) ->
    cons(abstract(H), abstract(T)).


%% =====================================================================
%% @spec concrete(Node::syntaxTree()) -> term()
%%
%% @doc Returns the Erlang term represented by a syntax tree. Evaluation
%% fails with reason <code>badarg</code> if <code>Node</code> does not
%% represent a literal term.
%%
%% <p>Note: Currently, the set of syntax trees which have a concrete
%% representation is larger than the set of trees which can be built
%% using the function <code>abstract/1</code>. An abstract character
%% will be concretised as an integer, while <code>abstract/1</code> does
%% not at present yield an abstract character for any input. (Use the
%% <code>char/1</code> function to explicitly create an abstract
%% character.)</p>
%%
%% @see abstract/1
%% @see is_literal/1
%% @see char/1

concrete(Node) ->
    case type(Node) of
	atom ->
	    atom_value(Node);
	integer ->
	    integer_value(Node);
	float ->
	    float_value(Node);
	char ->
	    char_value(Node);
	string ->
	    string_value(Node);
	nil ->
	    [];
	list ->
	    [concrete(list_head(Node))
	     | concrete(list_tail(Node))];
	tuple ->
	    list_to_tuple(concrete_list(tuple_elements(Node)));
	binary ->
	    Fs = [revert_binary_field(
		    binary_field(binary_field_body(F),
				 case binary_field_size(F) of
				     none -> none;
				     S ->
					 revert(S)
				 end,
				 binary_field_types(F)))
		  || F <- binary_fields(Node)],
	    {value, B, _} =
		eval_bits:expr_grp(Fs, [],
				   fun(F, _) ->
					   {value, concrete(F), []}
				   end, [], true),
	    B;
    	_ ->
	    erlang:fault({badarg, Node})
    end.

concrete_list([E | Es]) ->
    [concrete(E) | concrete_list(Es)];
concrete_list([]) ->
    [].


%% =====================================================================
%% @spec is_literal(Node::syntaxTree()) -> bool()
%%
%% @doc Returns <code>true</code> if <code>Node</code> represents a
%% literal term, otherwise <code>false</code>. This function returns
%% <code>true</code> if and only if the value of
%% <code>concrete(Node)</code> is defined.
%%
%% @see abstract/1
%% @see concrete/1

is_literal(T) ->
    case type(T) of
	atom ->
	    true;
	integer ->
	    true;
	float ->
	    true;
	char->
	    true;
	string ->
	    true;
	nil ->
	    true;
	list ->
	    case is_literal(list_head(T)) of
		true ->
		    is_literal(list_tail(T));
		false ->
		    false
	    end;
	tuple ->
	    lists:all(fun is_literal/1, tuple_elements(T));
	_ ->
	    false
    end.


%% =====================================================================
%% @spec revert(Tree::syntaxTree()) -> syntaxTree()
%%
%% @doc Returns an <code>erl_parse</code>-compatible representation of a
%% syntax tree, if possible. If <code>Tree</code> represents a
%% well-formed Erlang program or expression, the conversion should work
%% without problems. Typically, <code>is_tree/1</code> yields
%% <code>true</code> if conversion failed (i.e., the result is still an
%% abstract syntax tree), and <code>false</code> otherwise.
%%
%% <p>The <code>is_tree/1</code> test is not completely foolproof. For a
%% few special node types (e.g. <code>arity_qualifier</code>), if such a
%% node occurs in a context where it is not expected, it will be left
%% unchanged as a non-reverted subtree of the result. This can only
%% happen if <code>Tree</code> does not actually represent legal Erlang
%% code.</p>
%%
%% @see revert_forms/1
%% @see erl_parse

revert(Node) ->
    case is_tree(Node) of
	false ->
	    %% Just remove any wrapper. `erl_parse' nodes never contain
	    %% abstract syntax tree nodes as subtrees.
	    unwrap(Node);
	true ->
	    case is_leaf(Node) of
		true ->
		    revert_root(Node);
		false ->
		    %% First revert the subtrees, where possible.
		    %% (Sometimes, subtrees cannot be reverted out of
		    %% context, and the real work will be done when the
		    %% parent node is reverted.)
		    Gs = [[revert(X) || X <- L] || L <- subtrees(Node)],

		    %% Then reconstruct the node from the reverted
		    %% parts, and revert the node itself.
		    Node1 = update_tree(Node, Gs),
		    revert_root(Node1)
	    end
    end.

%% Note: The concept of "compatible root node" is not strictly defined.
%% At a minimum, if `make_tree' is used to compose a node `T' from
%% subtrees that are all completely backwards compatible, then the
%% result of `revert_root(T)' should also be completely backwards
%% compatible.

revert_root(Node) ->
    case type(Node) of
	application ->
	    revert_application(Node);
	atom ->
	    revert_atom(Node);
	attribute ->
	    revert_attribute(Node);
	binary ->
	    revert_binary(Node);
	binary_field ->
	    revert_binary_field(Node);
	block_expr ->
	    revert_block_expr(Node);
	case_expr ->
	    revert_case_expr(Node);
	catch_expr ->
	    revert_catch_expr(Node);
	char ->
	    revert_char(Node);
	clause ->
	    revert_clause(Node);
	cond_expr ->
	    revert_cond_expr(Node);
	eof_marker ->
	    revert_eof_marker(Node);
	error_marker ->
	    revert_error_marker(Node);
	float ->
	    revert_float(Node);
	fun_expr ->
	    revert_fun_expr(Node);
	function ->
	    revert_function(Node);
	generator ->
	    revert_generator(Node);
	if_expr ->
	    revert_if_expr(Node);
	implicit_fun ->
	    revert_implicit_fun(Node);
	infix_expr ->
	    revert_infix_expr(Node);
	integer ->
	    revert_integer(Node);
	list ->
	    revert_list(Node);
	list_comp ->
	    revert_list_comp(Node);
	match_expr ->
	    revert_match_expr(Node);
	module_qualifier ->
	    revert_module_qualifier(Node);
	nil ->
	    revert_nil(Node);
	parentheses ->
	    revert_parentheses(Node);
	prefix_expr ->
	    revert_prefix_expr(Node);
	qualified_name ->
	    revert_qualified_name(Node);
	query_expr ->
	    revert_query_expr(Node);
	receive_expr ->
	    revert_receive_expr(Node);
	record_access ->
	    revert_record_access(Node);
	record_expr ->
	    revert_record_expr(Node);
	record_index_expr ->
	    revert_record_index_expr(Node);
	rule ->
	    revert_rule(Node);
	string ->
	    revert_string(Node);
	try_expr ->
	    revert_try_expr(Node);
	tuple ->
	    revert_tuple(Node);
	underscore ->
	    revert_underscore(Node);
	variable ->
	    revert_variable(Node);
	warning_marker ->
	    revert_warning_marker(Node);
	_ ->
	    %% Non-revertible new-form node
	    Node
    end.


%% =====================================================================
%% @spec revert_forms(Forms) -> [erl_parse()]
%%
%%	    Forms = syntaxTree() | [syntaxTree()]
%%
%% @doc Reverts a sequence of Erlang source code forms. The sequence can
%% be given either as a <code>form_list</code> syntax tree (possibly
%% nested), or as a list of "program form" syntax trees. If successful,
%% the corresponding flat list of <code>erl_parse</code>-compatible
%% syntax trees is returned (cf. <code>revert/1</code>). If some program
%% form could not be reverted, <code>{error, Form}</code> is thrown.
%% Standalone comments in the form sequence are discarded.
%%
%% @see revert/1
%% @see form_list/1
%% @see is_form/1

revert_forms(L) when list(L) ->
    revert_forms(form_list(L));
revert_forms(T) ->
    case type(T) of
	form_list ->
	    T1 = flatten_form_list(T),
	    case catch {ok, revert_forms_1(form_list_elements(T1))} of
		{ok, Fs} ->
		    Fs;
		{error, R} ->
		    erlang:fault({error, R});
		{'EXIT', R} ->
		    exit(R);
		R ->
		    throw(R)
	    end;
	_ ->
	    erlang:fault({badarg, T})
    end.

revert_forms_1([T | Ts]) ->
    case type(T) of
	comment ->
	    revert_forms_1(Ts);
	_ ->
	    T1 = revert(T),
	    case is_tree(T1) of
		true ->
		    throw({error, T1});
		false ->
		    [T1 | revert_forms_1(Ts)]
	    end
    end;
revert_forms_1([]) ->
    [].


%% =====================================================================
%% @spec subtrees(Node::syntaxTree()) -> [[syntaxTree()]]
%%
%% @doc Returns the grouped list of all subtrees of a syntax tree. If
%% <code>Node</code> is a leaf node (cf. <code>is_leaf/1</code>), this
%% is the empty list, otherwise the result is always a nonempty list,
%% containing the lists of subtrees of <code>Node</code>, in
%% left-to-right order as they occur in the printed program text, and
%% grouped by category. Often, each group contains only a single
%% subtree.
%%
%% <p>Depending on the type of <code>Node</code>, the size of some
%% groups may be variable (e.g., the group consisting of all the
%% elements of a tuple), while others always contain the same number of
%% elements - usually exactly one (e.g., the group containing the
%% argument expression of a case-expression). Note, however, that the
%% exact structure of the returned list (for a given node type) should
%% in general not be depended upon, since it might be subject to change
%% without notice.</p>
%%
%% <p>The function <code>subtrees/1</code> and the constructor functions
%% <code>make_tree/2</code> and <code>update_tree/2</code> can be a
%% great help if one wants to traverse a syntax tree, visiting all its
%% subtrees, but treat nodes of the tree in a uniform way in most or all
%% cases. Using these functions makes this simple, and also assures that
%% your code is not overly sensitive to extensions of the syntax tree
%% data type, because any node types not explicitly handled by your code
%% can be left to a default case.</p>
%%
%% <p>For example:
%% <pre>
%%   postorder(F, Tree) ->
%%       F(case subtrees(Tree) of
%%           [] -> Tree;
%%           List -> update_tree(Tree,
%%                               [[postorder(F, Subtree)
%%                                 || Subtree &lt;- Group]
%%                                || Group &lt;- List])
%%         end).
%% </pre>
%% maps the function <code>F</code> on <code>Tree</code> and all its
%% subtrees, doing a post-order traversal of the syntax tree. (Note the
%% use of <code>update_tree/2</code> to preserve node attributes.) For a
%% simple function like:
%% <pre>
%%   f(Node) ->
%%       case type(Node) of
%%           atom -> atom("a_" ++ atom_name(Node));
%%           _ -> Node
%%       end.
%% </pre>
%% the call <code>postorder(fun f/1, Tree)</code> will yield a new
%% representation of <code>Tree</code> in which all atom names have been
%% extended with the prefix "a_", but nothing else (including comments,
%% annotations and line numbers) has been changed.</p>
%%
%% @see make_tree/2
%% @see type/1
%% @see is_leaf/1
%% @see copy_attrs/2

subtrees(T) ->
    case is_leaf(T) of
	true ->
	    [];
	false ->
	    case type(T) of
		application ->
		    [[application_operator(T)],
		     application_arguments(T)];
		arity_qualifier ->
		    [[arity_qualifier_body(T)],
		     [arity_qualifier_argument(T)]];
		attribute ->
		    case attribute_arguments(T) of
			none ->
			    [[attribute_name(T)]];
			As ->
			    [[attribute_name(T)], As]
		    end;
		binary ->
		    [binary_fields(T)];
		binary_field ->
		    case binary_field_types(T) of
			[] ->
			    [[binary_field_body(T)]];
			Ts ->
			    [[binary_field_body(T)],
			     Ts]
		    end;
		block_expr ->
		    [block_expr_body(T)];
		case_expr ->
		    [[case_expr_argument(T)],
		     case_expr_clauses(T)];
		catch_expr ->
		    [[catch_expr_body(T)]];
		class_qualifier ->
		    [[class_qualifier_argument(T)],
		     [class_qualifier_body(T)]];
		clause ->
		    case clause_guard(T) of
			none ->
			    [clause_patterns(T), clause_body(T)];
			G ->
			    [clause_patterns(T), [G],
			     clause_body(T)]
		    end;
		cond_expr ->
		    [cond_expr_clauses(T)];
		conjunction ->
		    [conjunction_body(T)];
		disjunction ->
		    [disjunction_body(T)];
		form_list ->
		    [form_list_elements(T)];
		fun_expr ->
		    [fun_expr_clauses(T)];
		function ->
		    [[function_name(T)], function_clauses(T)];
		generator ->
		    [[generator_pattern(T)], [generator_body(T)]];
		if_expr ->
		    [if_expr_clauses(T)];
		implicit_fun ->
		    [[implicit_fun_name(T)]];
		infix_expr ->
		    [[infix_expr_left(T)],
		     [infix_expr_operator(T)],
		     [infix_expr_right(T)]];
		list ->
		    case list_suffix(T) of
			none ->
			    [list_prefix(T)];
			S ->
			    [list_prefix(T), [S]]
		    end;
		list_comp ->
		    [[list_comp_template(T)], list_comp_body(T)];
		macro ->
		    case macro_arguments(T) of
			none ->
			    [[macro_name(T)]];
			As ->
			    [[macro_name(T)], As]
		    end;
		match_expr ->
		    [[match_expr_pattern(T)],
		     [match_expr_body(T)]];
		module_qualifier ->
		    [[module_qualifier_argument(T)],
		     [module_qualifier_body(T)]];
		parentheses ->
		    [[parentheses_body(T)]];
		prefix_expr ->
		    [[prefix_expr_operator(T)],
		     [prefix_expr_argument(T)]];
		qualified_name ->
		    [qualified_name_segments(T)];
		query_expr ->
		    [[query_expr_body(T)]];
		receive_expr ->
		    case receive_expr_timeout(T) of
			none ->
			    [receive_expr_clauses(T)];
			E ->
			    [receive_expr_clauses(T),
			     [E],
			     receive_expr_action(T)]
		    end;
		record_access ->
		    case record_access_type(T) of
			none ->
			    [[record_access_argument(T)],
			     [record_access_field(T)]];
			R ->
			    [[record_access_argument(T)],
			     [R],
			     [record_access_field(T)]]
		    end;
		record_expr ->
		    case record_expr_argument(T) of
			none ->
			    [[record_expr_type(T)],
			     record_expr_fields(T)];
			V ->
			    [[V],
			     [record_expr_type(T)],
			     record_expr_fields(T)]
		    end;
		record_field ->
		    case record_field_value(T) of
			none ->
			    [[record_field_name(T)]];
			V ->
			    [[record_field_name(T)], [V]]
		    end;
		record_index_expr ->
		    [[record_index_expr_type(T)],
		     [record_index_expr_field(T)]];
		rule ->
		    [[rule_name(T)], rule_clauses(T)];
		size_qualifier ->
		    [[size_qualifier_body(T)],
		     [size_qualifier_argument(T)]];
		try_expr ->
		    [try_expr_body(T),
		     try_expr_clauses(T),
		     try_expr_handlers(T),
		     try_expr_after(T)];
		tuple ->
		    [tuple_elements(T)]
	    end
    end.


%% =====================================================================
%% @spec update_tree(Node::syntaxTree(), Groups::[[syntaxTree()]]) ->
%%           syntaxTree()
%%
%% @doc Creates a syntax tree with the same type and attributes as the
%% given tree. This is equivalent to <code>copy_attrs(Node,
%% make_tree(type(Node), Groups))</code>.
%%
%% @see make_tree/2
%% @see copy_attrs/2
%% @see type/1

update_tree(Node, Groups) ->
    copy_attrs(Node, make_tree(type(Node), Groups)).


%% =====================================================================
%% @spec make_tree(Type::atom(), Groups::[[syntaxTree()]]) ->
%%           syntaxTree()
%%
%% @doc Creates a syntax tree with the given type and subtrees.
%% <code>Type</code> must be a node type name (cf. <code>type/1</code>)
%% that does not denote a leaf node type (cf. <code>is_leaf/1</code>).
%% <code>Groups</code> must be a <em>nonempty</em> list of groups of
%% syntax trees, representing the subtrees of a node of the given type,
%% in left-to-right order as they would occur in the printed program
%% text, grouped by category as done by <code>subtrees/1</code>.
%%
%% <p>The result of <code>copy_attrs(Node, make_tree(type(Node),
%% subtrees(Node)))</code> (cf. <code>update_tree/2</code>) represents
%% the same source code text as the original <code>Node</code>, assuming
%% that <code>subtrees(Node)</code> yields a nonempty list. However, it
%% does not necessarily have the same data representation as
%% <code>Node</code>.</p>
%%
%% @see update_tree/1
%% @see subtrees/1
%% @see type/1
%% @see is_leaf/1
%% @see copy_attrs/2

make_tree(application, [[F], A]) -> application(F, A);
make_tree(arity_qualifier, [[N], [A]]) -> arity_qualifier(N, A);
make_tree(attribute, [[N]]) -> attribute(N);
make_tree(attribute, [[N], A]) -> attribute(N, A);
make_tree(binary, [Fs]) -> binary(Fs);
make_tree(binary_field, [[B]]) -> binary_field(B);
make_tree(binary_field, [[B], Ts]) -> binary_field(B, Ts);
make_tree(block_expr, [B]) -> block_expr(B);
make_tree(case_expr, [[A], C]) -> case_expr(A, C);
make_tree(catch_expr, [[B]]) -> catch_expr(B);
make_tree(class_qualifier, [[A], [B]]) -> class_qualifier(A, B);
make_tree(clause, [P, B]) -> clause(P, none, B);
make_tree(clause, [P, [G], B]) -> clause(P, G, B);
make_tree(cond_expr, [C]) -> cond_expr(C);
make_tree(conjunction, [E]) -> conjunction(E);
make_tree(disjunction, [E]) -> disjunction(E);
make_tree(form_list, [E]) -> form_list(E);
make_tree(fun_expr, [C]) -> fun_expr(C);
make_tree(function, [[N], C]) -> function(N, C);
make_tree(generator, [[P], [E]]) -> generator(P, E);
make_tree(if_expr, [C]) -> if_expr(C);
make_tree(implicit_fun, [[N]]) -> implicit_fun(N);
make_tree(infix_expr, [[L], [F], [R]]) -> infix_expr(L, F, R);
make_tree(list, [P]) -> list(P);
make_tree(list, [P, [S]]) -> list(P, S);
make_tree(list_comp, [[T], B]) -> list_comp(T, B);
make_tree(macro, [[N]]) -> macro(N);
make_tree(macro, [[N], A]) -> macro(N, A);
make_tree(match_expr, [[P], [E]]) -> match_expr(P, E);
make_tree(module_qualifier, [[M], [N]]) -> module_qualifier(M, N);
make_tree(parentheses, [[E]]) -> parentheses(E);
make_tree(prefix_expr, [[F], [A]]) -> prefix_expr(F, A);
make_tree(qualified_name, [S]) -> qualified_name(S);
make_tree(query_expr, [[B]]) -> query_expr(B);
make_tree(receive_expr, [C]) -> receive_expr(C);
make_tree(receive_expr, [C, [E], A]) -> receive_expr(C, E, A);
make_tree(record_access, [[E], [F]]) ->
    record_access(E, F);
make_tree(record_access, [[E], [T], [F]]) ->
    record_access(E, T, F);
make_tree(record_expr, [[T], F]) -> record_expr(T, F);
make_tree(record_expr, [[E], [T], F]) -> record_expr(E, T, F);
make_tree(record_field, [[N]]) -> record_field(N);
make_tree(record_field, [[N], [E]]) -> record_field(N, E);
make_tree(record_index_expr, [[T], [F]]) ->
    record_index_expr(T, F);
make_tree(rule, [[N], C]) -> rule(N, C);
make_tree(size_qualifier, [[N], [A]]) -> size_qualifier(N, A);
make_tree(try_expr, [B, C, H, A]) -> try_expr(B, C, H, A);
make_tree(tuple, [E]) -> tuple(E).


%% =====================================================================
%% @spec meta(Tree::syntaxTree()) -> syntaxTree()
%%
%% @doc Creates a meta-representation of a syntax tree. The result
%% represents an Erlang expression "<code><em>MetaTree</em></code>"
%% which, if evaluated, will yield a new syntax tree representing the
%% same source code text as <code>Tree</code> (although the actual data
%% representation may be different). The expression represented by
%% <code>MetaTree</code> is <em>implementation independent</em> with
%% regard to the data structures used by the abstract syntax tree
%% implementation. Comments attached to nodes of <code>Tree</code> will
%% be preserved, but other attributes are lost.
%%
%% <p>Any node in <code>Tree</code> whose node type is
%% <code>variable</code> (cf. <code>type/1</code>), and whose list of
%% annotations (cf. <code>get_ann/1</code>) contains the atom
%% <code>meta_var</code>, will remain unchanged in the resulting tree,
%% except that exactly one occurrence of <code>meta_var</code> is
%% removed from its annotation list.</p>
%%
%% <p>The main use of the function <code>meta/1</code> is to transform a
%% data structure <code>Tree</code>, which represents a piece of program
%% code, into a form that is <em>representation independent when
%% printed</em>. E.g., suppose <code>Tree</code> represents a variable
%% named "V". Then (assuming a function <code>print/1</code> for
%% printing syntax trees), evaluating <code>print(abstract(Tree))</code>
%% - simply using <code>abstract/1</code> to map the actual data
%% structure onto a syntax tree representation - would output a string
%% that might look something like "<code>{tree, variable, ..., "V",
%% ...}</code>", which is obviously dependent on the implementation of
%% the abstract syntax trees. This could e.g. be useful for caching a
%% syntax tree in a file. However, in some situations like in a program
%% generator generator (with two "generator"), it may be unacceptable.
%% Using <code>print(meta(Tree))</code> instead would output a
%% <em>representation independent</em> syntax tree generating
%% expression; in the above case, something like
%% "<code>erl_syntax:variable("V")</code>".</p>
%%
%% @see abstract/1
%% @see type/1
%% @see get_ann/1

meta(T) ->
    %% First of all we check for metavariables:
    case type(T) of
	variable ->
	    case lists:member(meta_var, get_ann(T)) of
		false ->
		    meta_precomment(T);
		true ->
		    %% A meta-variable: remove the first found
		    %% `meta_var' annotation, but otherwise leave
		    %% the node unchanged.
		    set_ann(T, lists:delete(meta_var, get_ann(T)))
	    end;
	_ ->
	    case has_comments(T) of
		true ->
		    meta_precomment(T);
		false ->
		    meta_1(T)
	    end
    end.

meta_precomment(T) ->
    case get_precomments(T) of
	[] ->
	    meta_postcomment(T);
	Cs ->
	    meta_call(set_precomments,
		      [meta_postcomment(T), list(meta_list(Cs))])
    end.

meta_postcomment(T) ->
    case get_postcomments(T) of
	[] ->
	    meta_0(T);
	Cs ->
	    meta_call(set_postcomments,
		      [meta_0(T), list(meta_list(Cs))])
    end.

meta_0(T) ->
    meta_1(remove_comments(T)).

meta_1(T) ->
    %% First handle leaf nodes and other common cases, in order to
    %% generate compact code.
    case type(T) of
	atom ->
	    meta_call(atom, [T]);
	char ->
	    meta_call(char, [T]);
	comment ->
	    meta_call(comment, [list([string(S)
				      || S <- comment_text(T)])]);
	eof_marker ->
	    meta_call(eof_marker, []);
	error_marker ->
	    meta_call(error_marker,
		      [abstract(error_marker_info(T))]);
	float ->
	    meta_call(float, [T]);
	integer ->
	    meta_call(integer, [T]);
	nil ->
	    meta_call(nil, []);
	operator ->
	    meta_call(operator, [atom(operator_name(T))]);
	string ->
	    meta_call(string, [T]);
	text ->
	    meta_call(text, [string(text_string(T))]);
	underscore ->
	    meta_call(underscore, []);
	variable ->
	    meta_call(variable, [string(variable_name(T))]);
	warning_marker ->
	    meta_call(warning_marker,
		      [abstract(warning_marker_info(T))]);
	list ->
	    case list_suffix(T) of
		none ->
		    meta_call(list,
			      [list(meta_list(list_prefix(T)))]);
		S ->
		    meta_call(list,
			      [list(meta_list(list_prefix(T))),
			       meta(S)])
	    end;
	tuple ->
	    meta_call(tuple,
		      [list(meta_list(tuple_elements(T)))]);
	Type ->
	    %% All remaining cases are handled using `subtrees'
	    %% and `make_tree' to decompose and reassemble the
	    %% nodes. More cases could of course be handled
	    %% directly to get a more compact output, but I can't
	    %% be bothered right now.
	    meta_call(make_tree,
		      [abstract(Type),
		       meta_subtrees(subtrees(T))])
    end.

meta_list([T | Ts]) ->
    [meta(T) | meta_list(Ts)];
meta_list([]) ->
    [].

meta_subtrees(Gs) ->
    list([list([meta(T)
		|| T <- G])
	  || G <- Gs]).

meta_call(F, As) ->
    application(atom(?MODULE), atom(F), As).


%% =====================================================================
%% Functions for abstraction of the syntax tree representation; may be
%% used externally, but not intended for the normal user.
%% =====================================================================


%% =====================================================================
%% @spec tree(Type) -> syntaxTree()
%% @equiv tree(Type, [])

tree(Type) ->
    tree(Type, []).

%% =====================================================================
%% @spec tree(Type::atom(), Data::term()) -> syntaxTree()
%%
%% @doc <em>For special purposes only</em>. Creates an abstract syntax
%% tree node with type tag <code>Type</code> and associated data
%% <code>Data</code>.
%%
%% <p>This function and the related <code>is_tree/1</code> and
%% <code>data/1</code> provide a uniform way to extend the set of
%% <code>erl_parse</code> node types. The associated data is any term,
%% whose format may depend on the type tag.</p>
%%
%% <h4>Notes:</h4>
%% <ul>
%%  <li>Any nodes created outside of this module must have type tags
%%      distinct from those currently defined by this module; see
%%      <code>type/1</code> for a complete list.</li>
%%  <li>The type tag of a syntax tree node may also be used
%%      as a primary tag by the <code>erl_parse</code> representation;
%%      in that case, the selector functions for that node type
%%      <em>must</em> handle both the abstract syntax tree and the
%%      <code>erl_parse</code> form. The function <code>type(T)</code>
%%      should return the correct type tag regardless of the
%%      representation of <code>T</code>, so that the user sees no
%%      difference between <code>erl_syntax</code> and
%%      <code>erl_parse</code> nodes.</li>
%% </ul>
%% @see is_tree/1
%% @see data/1
%% @see type/1

tree(Type, Data) ->
    #tree{type = Type, data = Data}.


%% =====================================================================
%% @spec is_tree(Tree::syntaxTree()) -> bool()
%%
%% @doc <em>For special purposes only</em>. Returns <code>true</code> if
%% <code>Tree</code> is an abstract syntax tree and <code>false</code>
%% otherwise.
%%
%% <p><em>Note</em>: this function yields <code>false</code> for all
%% "old-style" <code>erl_parse</code>-compatible "parse trees".</p>
%%
%% @see tree/2

is_tree(#tree{}) ->
    true;
is_tree(_) ->
    false.


%% =====================================================================
%% @spec data(Tree::syntaxTree()) -> term()
%%
%% @doc <em>For special purposes only</em>. Returns the associated data
%% of a syntax tree node. Evaluation fails with reason
%% <code>badarg</code> if <code>is_tree(Node)</code> does not yield
%% <code>true</code>.
%%
%% @see tree/2

data(#tree{data = D}) -> D;
data(T) -> erlang:fault({badarg, T}).


%% =====================================================================
%% Primitives for backwards compatibility; for internal use only
%% =====================================================================


%% =====================================================================
%% @spec wrap(Node::erl_parse()) -> syntaxTree()
%%
%% @type erl_parse() = erl_parse:parse_tree(). The "parse tree"
%% representation built by the Erlang standard library parser
%% <code>erl_parse</code>. This is a subset of the
%% <a href="#type-syntaxTree"><code>syntaxTree</code></a> type.
%%
%% @doc Creates a wrapper structure around an <code>erl_parse</code>
%% "parse tree".
%%
%% <p>This function and the related <code>unwrap/1</code> and
%% <code>is_wrapper/1</code> provide a uniform way to attach arbitrary
%% information to an <code>erl_parse</code> tree. Some information about
%% the encapsuled tree may be cached in the wrapper, such as the node
%% type. All functions on syntax trees must behave so that the user sees
%% no difference between wrapped and non-wrapped <code>erl_parse</code>
%% trees. <em>Attaching a wrapper onto another wrapper structure is an
%% error</em>.</p>

wrap(Node) ->
    %% We assume that Node is an old-school `erl_parse' tree.
    #wrapper{type = type(Node), attr = #attr{pos = get_pos(Node)},
	     tree = Node}.


%% =====================================================================
%% @spec unwrap(Node::syntaxTree()) -> syntaxTree()
%%
%% @doc Removes any wrapper structure, if present. If <code>Node</code>
%% is a wrapper structure, this function returns the wrapped
%% <code>erl_parse</code> tree; otherwise it returns <code>Node</code>
%% itself.

unwrap(#wrapper{tree = Node}) -> Node;
unwrap(Node) -> Node.	 % This could also be a new-form node.


%% =====================================================================
%% @spec is_wrapper(Term::term()) -> bool()
%%
%% @doc Returns <code>true</code> if the argument is a wrapper
%% structure, otherwise <code>false</code>.

-ifndef(NO_UNUSED).
is_wrapper(#wrapper{}) ->
    true;
is_wrapper(_) ->
    false.
-endif.


%% =====================================================================
%% General utility functions for internal use
%% =====================================================================

is_printable(S) ->
    io_lib:printable_list(S).

%% Support functions for transforming lists of function names
%% specified as `arity_qualifier' nodes.

unfold_function_names(Ns, Pos) ->
    F = fun ({Atom, Arity}) ->
		N = arity_qualifier(atom(Atom), integer(Arity)),
		set_pos(N, Pos)
	end,
    [F(N) || N <- Ns].

fold_function_names(Ns) ->
    [fold_function_name(N) || N <- Ns].

fold_function_name(N) ->
    Name = arity_qualifier_body(N),
    Arity = arity_qualifier_argument(N),
    case (type(Name) == atom) and (type(Arity) == integer) of
	true ->
	    {concrete(Name), concrete(Arity)}
    end.

fold_variable_names(Vs) ->
    [variable_name(V) || V <- Vs].

unfold_variable_names(Vs, Pos) ->
    [set_pos(variable(V), Pos) || V <- Vs].

%% Support functions for qualified names ("foo.bar.baz",
%% "erl.lang.lists", etc.). The representation overlaps with the weird
%% "Mnesia query record access" operators. The '.' operator is left
%% associative, so folding should nest on the left.

is_qualified_name({record_field, _, L, R}) ->
    case is_qualified_name(L) of
	true -> is_qualified_name(R);
	false -> false
    end;
is_qualified_name({atom, _, _}) -> true;
is_qualified_name(_) -> false.

unfold_qualified_name(Node) ->
    lists:reverse(unfold_qualified_name(Node, [])).

unfold_qualified_name({record_field, _, L, R}, Ss) ->
    unfold_qualified_name(R, unfold_qualified_name(L, Ss));
unfold_qualified_name(S, Ss) -> [S | Ss].

fold_qualified_name([S | Ss], Pos) ->
    fold_qualified_name(Ss, Pos, {atom, Pos, atom_value(S)}).

fold_qualified_name([S | Ss], Pos, Ack) ->
    fold_qualified_name(Ss, Pos, {record_field, Pos, Ack,
				  {atom, Pos, atom_value(S)}});
fold_qualified_name([], _Pos, Ack) ->
    Ack.

%% Support functions for transforming lists of record field definitions.
%%
%% There is no unique representation for field definitions in the
%% standard form. There, they may only occur in the "fields" part of a
%% record expression or declaration, and are represented as
%% `{record_field, Pos, Name, Value}', or as `{record_field, Pos, Name}'
%% if the value part is left out. However, these cannot be distinguished
%% out of context from the representation of record field access
%% expressions (see `record_access').

fold_record_fields(Fs) ->
    [fold_record_field(F) || F <- Fs].

fold_record_field(F) ->
    Pos = get_pos(F),
    Name = record_field_name(F),
    case record_field_value(F) of
	none ->
	    {record_field, Pos, Name};
	Value ->
	    {record_field, Pos, Name, Value}
    end.

unfold_record_fields(Fs) ->
    [unfold_record_field(F) || F <- Fs].

unfold_record_field({record_field, Pos, Name}) ->
    set_pos(record_field(Name), Pos);
unfold_record_field({record_field, Pos, Name, Value}) ->
    set_pos(record_field(Name, Value), Pos).

fold_binary_field_types(Ts) ->
    [fold_binary_field_type(T) || T <- Ts].

fold_binary_field_type(Node) ->
    case type(Node) of
	size_qualifier ->
	    {concrete(size_qualifier_body(Node)),
	     concrete(size_qualifier_argument(Node))};
	_ ->
	    concrete(Node)
    end.

unfold_binary_field_types(Ts, Pos) ->
    [unfold_binary_field_type(T, Pos) || T <- Ts].

unfold_binary_field_type({Type, Size}, Pos) ->
    set_pos(size_qualifier(atom(Type), integer(Size)), Pos);
unfold_binary_field_type(Type, Pos) ->
    set_pos(atom(Type), Pos).


%% =====================================================================
