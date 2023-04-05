%% @doc Sample restricted remote shell module disabling `q/0' and
%%      `init:stop/{0,1}' commands. The shell introduces a replacement command
%%      to stop remote node: `remote:stop/1' equivalent to `init:stop/1'.
%%
%%      To activate restricted shell, run the server node like this:
%%      `erl -sname node@host +Bi -shell restricted_shell restrict_remsh_mod'
%%
%%      Then you can connect to it with:
%%      `erl -sname a@myhost -remsh node@host'
%%
%% See: [http://www.erlang.org/doc/man/shell.html#start_restricted-1]
-module(restrict_remsh_mod).
-author('saleyn@gmail.com').

%% Restricted shell callbacks
-export([local_allowed/3, non_local_allowed/3]).

%% Internal API
-export([remote_node_stop/1]).

%% @private
-spec local_allowed(Func::atom(), Args::list(), State::term()) ->
        {boolean(), NewState::term()}.
local_allowed(q,    _Args, State) -> {false, State};
local_allowed(halt, _Args, State) -> {false, State};
local_allowed(_Cmd, _Args, State) -> {true, State}.

%% @private
-type funspec() :: {Mod::atom(), Fun::atom()}.
-spec non_local_allowed(FunSpec::funspec(), Args::list(), State::term()) ->
        {true,NewState::term()} | {false,NewState::term()} |
        {{redirect, NewFuncSpec::funspec(), NewArgs::list()}, NewState::term()}.
non_local_allowed({erlang, halt}, _Args, State) -> {false, State};
non_local_allowed({init,   stop}, _Args, State) -> {false, State};
non_local_allowed({remote, stop}, [A],   State) -> {{redirect, {?MODULE, remote_node_stop}, [A]}, State};
non_local_allowed({_M, _F},       _Args, State) -> {true, State}.

%% @doc Replaces `init:stop/1' with `remote:stop/1' to avoid accidental
%%      exit of remote shell.
-spec remote_node_stop(Status::integer()) -> ok.
remote_node_stop(Status) ->
    init:stop(Status).
