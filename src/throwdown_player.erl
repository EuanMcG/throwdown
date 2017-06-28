-module(throwdown_player).
-behaviour(gen_server).

-export([
         start_link/2,
         start_link/3,
         default_strategy/1,
         play/2,
         leave/1
        ]).

-export([
         init/1,
         handle_cast/2,
         handle_call/3,
         handle_info/2,
         terminate/2,
         code_change/3
        ]).

-record(state, {
          name :: binary(),
         arena :: pid(),
      strategy :: function()
}).

start_link(Name, Arena) ->
    start_link(Name, Arena, fun default_strategy/1).

start_link(Name, Arena, Strategy) ->
    gen_server:start_link(?MODULE, [Name, Arena, Strategy], []).

default_strategy(_State = #{ choices := Choices }) ->
    pick_one(Choices).

play(Pid, State) ->
    gen_server:cast(Pid, {play, State}).

leave(Pid) ->
    gen_server:call(Pid, leave).

%% gen_server callbacks

init([Name, Arena, Strategy]) ->
    link(Arena), %% if arena dies, we die
    ok = throwdown_arena:register(Name, self()),
    {ok, #state{ name = Name, arena = Arena, strategy = Strategy }}.

handle_cast({play, _GameState}, State = #state{ arena = undefined }) ->
    {noreply, State};
handle_cast({play, GameState}, State = #state{ arena = A, name = N, strategy = S }) ->
    Choice = S(GameState),
    spawn(fun() -> ok = throwdown_arena:submit_choice(A, N, Choice) end),
    {noreply, State};
handle_cast(_Cast, State) ->
    {noreply, State}.

handle_call(leave, _From, State = #state{ arena = A }) ->
    unlink(A),
    {reply, ok, State#state{ arena = undefined }};

handle_call(_Call, _From, State) ->
    {reply, dieeeeee, State}.

handle_info(_Info, State) ->
    {noreply, State}.

terminate(_Reason, _State) ->
    ok.

code_change(_OldVsn, State, _Extra) ->
    {ok, State}.

%% private

pick_one(L) ->
    lists:nth(rand:uniform(length(L)), L).
