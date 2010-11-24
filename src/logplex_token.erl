-module(logplex_token).
-behaviour(gen_server).

%% gen_server callbacks
-export([start_link/0, init/1, handle_call/3, handle_cast/2, 
	     handle_info/2, terminate/2, code_change/3]).

-export([create/3, lookup/1, delete/1]).

-include_lib("logplex.hrl").

%% API functions
start_link() ->
	gen_server:start_link({local, ?MODULE}, ?MODULE, [], []).

create(ChannelId, TokenName, Addon) when is_binary(ChannelId), is_binary(TokenName), is_binary(Addon) ->
    TokenId = list_to_binary("t." ++ string:strip(os:cmd("uuidgen"), right, $\n)),
    logplex_grid:publish(?MODULE, {create_token, ChannelId, TokenId, TokenName, Addon}),
    logplex_grid:publish(logplex_channel, {create_token, ChannelId, TokenId, TokenName, Addon}),
    redis_helper:create_token(ChannelId, TokenId, TokenName, Addon),
    TokenId.

delete(TokenId) when is_binary(TokenId) ->
    case lookup(TokenId) of
        #token{channel_id=ChannelId} ->
            logplex_grid:publish(?MODULE, {delete_token, TokenId}),
            logplex_grid:publish(logplex_channel, {delete_token, ChannelId, TokenId}),
            redis_helper:delete_token(ChannelId, TokenId);
        _ ->
            ok
    end.

lookup(Token) when is_binary(Token) ->
    case ets:lookup(?MODULE, Token) of
        [Token1] when is_record(Token1, token) ->
            Token1;
        _ ->
            redis_helper:lookup_token(Token)
    end.

%%====================================================================
%% gen_server callbacks
%%====================================================================

%%--------------------------------------------------------------------
%% Function: init(Args) -> {ok, State} |
%%                         {ok, State, Timeout} |
%%                         ignore               |
%%                         {stop, Reason}
%% Description: Initiates the server
%% @hidden
%%--------------------------------------------------------------------
init([]) ->
    ets:new(?MODULE, [protected, named_table, set, {keypos, 2}]),
    populate_cache(),
	{ok, []}.

%%--------------------------------------------------------------------
%% Function: %% handle_call(Request, From, State) -> {reply, Reply, State} |
%%                                      {reply, Reply, State, Timeout} |
%%                                      {noreply, State} |
%%                                      {noreply, State, Timeout} |
%%                                      {stop, Reason, Reply, State} |
%%                                      {stop, Reason, State}
%% Description: Handling call messages
%% @hidden
%%--------------------------------------------------------------------
handle_call(_Msg, _From, State) ->
    {reply, {error, invalid_call}, State}.

%%--------------------------------------------------------------------
%% Function: handle_cast(Msg, State) -> {noreply, State} |
%%                                      {noreply, State, Timeout} |
%%                                      {stop, Reason, State}
%% Description: Handling cast messages
%% @hidden
%%--------------------------------------------------------------------
handle_cast(_Msg, State) ->
    {noreply, State}.

%%--------------------------------------------------------------------
%% Function: handle_info(Info, State) -> {noreply, State} |
%%                                       {noreply, State, Timeout} |
%%                                       {stop, Reason, State}
%% Description: Handling all non call/cast messages
%% @hidden
%%--------------------------------------------------------------------
handle_info({create_token, ChannelId, TokenId, TokenName, Addon}, State) ->
    ets:insert(?MODULE, #token{id=TokenId, channel_id=ChannelId, name=TokenName, addon=Addon}),
    {noreply, State};

handle_info({delete_token, TokenId}, State) ->
    ets:delete(?MODULE, TokenId),
    {noreply, State};

handle_info(_Info, State) ->
    {noreply, State}.

%%--------------------------------------------------------------------
%% Function: terminate(Reason, State) -> void()
%% Description: This function is called by a gen_server when it is about to
%% terminate. It should be the opposite of Module:init/1 and do any necessary
%% cleaning up. When it returns, the gen_server terminates with Reason.
%% The return value is ignored.
%% @hidden
%%--------------------------------------------------------------------
terminate(_Reason, _State) -> 
    ok.

%%--------------------------------------------------------------------
%% Func: code_change(OldVsn, State, Extra) -> {ok, NewState}
%% Description: Convert process state when code is changed
%% @hidden
%%--------------------------------------------------------------------
code_change(_OldVsn, State, _Extra) ->
    {ok, State}.

%%--------------------------------------------------------------------
%%% Internal functions
%%--------------------------------------------------------------------
populate_cache() ->
    Data = redis_helper:lookup_tokens(),
    length(Data) > 0 andalso ets:insert(?MODULE, Data).