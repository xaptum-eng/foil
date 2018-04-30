-module(foil_compiler).
-include("foil.hrl").

-export([
    load/2
]).

%% public
-spec load(namespace(), [{key(), value()}]) ->
    ok.

load(Module, KVs) when is_atom(Module) ->
    ModuleForm = {attribute, 0, module, Module},
    ExportForm = {attribute, 0, export, [{lookup,1}]},
    LookupFunForm = {function, 0, lookup, 1, lookup_fun_clauses(KVs)},
    
    Forms = [ModuleForm, ExportForm, LookupFunForm],
    {ok, Module, Bin} = compile:forms(Forms, [debug_info]),
    code:soft_purge(Module),
    Filename = atom_to_list(Module) ++ ".erl",
    {module, Module} = code:load_binary(Module, Filename, Bin),
    ok.


lookup_fun_clauses(KVs) ->
    Clauses = [ {clause, 0, [erl_parse:abstract(K)],[], lookup_fun_value_form(V)} || {K,V} <- KVs ],
    DefaultClause = [{clause, 0, [{var, 0, '_'}], [], [ erl_parse:abstract({error, key_not_found})]}],
    Clauses ++ DefaultClause.

lookup_fun_value_form(V) ->
    ValueForm = value_form(V),
    [ {tuple,0,[erl_parse:abstract(ok), ValueForm]} ].

value_form(V) ->
    try 
	erl_parse:abstract(V)
    catch 
	_ : _ ->
	    Bin = erlang:term_to_binary(V),
	    M = erl_parse:abstract(erlang),
	    F = erl_parse:abstract(binary_to_term),
	    A = erl_parse:abstract(Bin),
	    {call, 0, {remote, 0, M, F}, [A]}
    end.
