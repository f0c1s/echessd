%%%-------------------------------------------------------------------
%%% File    : echessd_db.erl
%%% Author  : Aleksey Morarash <aleksey.morarash@gmail.com>
%%% Created : 20 Jan 2012
%%% License : FreeBSD
%%% Description : persistent storage interface
%%%
%%%-------------------------------------------------------------------

-module(echessd_db).

-export([init/0, wait/0,
         list_users/0,
         adduser/2,
         deluser/1,
         get_user_props/1,
         set_user_props/2,
         addgame/1,
         get_game_props/1,
         set_game_props/2,
         delgame/1,
         gamemove/3
        ]).

-include("echessd.hrl").

%% db table record
-record(hrec, {key, val}).

%% ----------------------------------------------------------------------
%% API functions
%% ----------------------------------------------------------------------

%% @doc Creates mnesia database from scratch. All previous data if
%%      such exists will be wiped off.
%%      Normally this function called from 'init.sh' script only
%%      once before first server start.
%% @spec init() -> ok
init() ->
    stopped = mnesia:stop(),
    ok = mnesia:delete_schema([node()]),
    ok = mnesia:create_schema([node()]),
    ok = mnesia:start(),
    DbOpts =
        [{type, set},
         {record_name, hrec},
         {disc_copies, [node()]}],
    {atomic, ok} =
        mnesia:create_table(?dbt_users, DbOpts),
    {atomic, ok} =
        mnesia:create_table(?dbt_games, DbOpts),
    ok.

%% @doc Waits until all needed database tables becomes available
%%      or fails if timeout of 10 seconds reaches faster.
%%      Called at server start from application supervisor init/0.
%% @spec wait() -> ok
wait() ->
    case mnesia:wait_for_tables(
           [?dbt_users, ?dbt_games], 10000) of
        ok -> ok;
        {timeout, BadTabList} = Error ->
            echessd_log:err(
              "Timeout waiting DB tables: ", [BadTabList]),
            throw(Error);
        {error, Reason} ->
            echessd_log:err(
              "Error occured while waiting DB tables: ", [Reason]),
            throw(Reason)
    end.

%% @doc Fetch registered users names.
%% @spec list_users() -> {ok, Users} | {error, Reason}
%%     Users = [echessd_user:echessd_user()],
%%     Reason = term()
list_users() ->
    transaction(
      fun() ->
              mnesia:foldl(
                fun(HRec, Acc) ->
                        [HRec#hrec.key | Acc]
                end, [], ?dbt_users)
      end).

%% @doc Adds new user.
%% @spec adduser(Username, UserProperties) -> ok | {error, Reason}
%%     Username = echessd_user:echessd_user(),
%%     UserProperties = echessd_user:echessd_user_info(),
%%     Reason = term()
adduser(Username, UserProperties) ->
    transaction_ok(
      fun() ->
              case mnesia:read({?dbt_users, Username}) of
                  [_] ->
                      mnesia:abort({user_already_exists, Username});
                  _ ->
                      ll_set_props(?dbt_users, Username, UserProperties)
              end
      end).

%% @doc Removes existing user.
%% @spec deluser(Username) -> ok | {error, Reason}
%%     Username = echessd_user:echessd_user(),
%%     Reason = term()
deluser(Username) ->
    transaction_ok(
      fun() ->
              mnesia:delete({?dbt_users, Username})
      end).

%% @doc Fetch user properties.
%% @spec get_user_props(Username) -> {ok, UserProperties} | {error, Reason}
%%     Username = echessd_user:echessd_user(),
%%     UserProperties = echessd_user:echessd_user_info(),
%%     Reason = term()
get_user_props(Name) ->
    transaction(
      fun() ->
              ll_get_props(?dbt_users, Name)
      end).

%% @doc Set user properties.
%% @spec set_user_props(Username, UserProperties) -> ok | {error, Reason}
%%     Username = echessd_user:echessd_user(),
%%     UserProperties = echessd_user:echessd_user_info(),
%%     Reason = term()
set_user_props(Username, UserProperties) ->
    transaction_ok(
      fun() ->
              OldProps = ll_get_props(?dbt_users, Username),
              ll_replace_props(
                ?dbt_users, Username, OldProps, UserProperties)
      end).

%% @doc Adds new game to database.
%% @spec addgame(GameInfo) -> {ok, GameID} | {error, Reason}
%%     GameInfo = echessd_game:echessd_game_props(),
%%     GameID = echessd_game:echessd_game_id(),
%%     Reason = term()
addgame(GameInfo) ->
    transaction(
      fun() ->
              GameID =
                  case mnesia:read({?dbt_games, counter}) of
                      [HRec] -> HRec#hrec.val;
                      _ -> 1
                  end,
              ll_set_props(?dbt_games, counter, GameID + 1),
              set_game_props_(GameID, GameInfo),
              GameID
      end).

%% @doc Fetch game properties.
%% @spec get_game_props(GameID) -> {ok, GameInfo} | {error, Reason}
%%     GameID = echessd_game:echessd_game_id(),
%%     GameInfo = echessd_game:echessd_game_props(),
%%     Reason = term()
get_game_props(GameID) ->
    transaction(
      fun() ->
              ll_get_props(?dbt_games, GameID)
      end).

%% @doc Set game properties.
%% @spec set_game_props(GameID, GameInfo) -> ok | {error, Reason}
%%     GameID = echessd_game:echessd_game_id(),
%%     GameInfo = echessd_game:echessd_game_props(),
%%     Reason = term()
set_game_props(GameID, GameInfo) ->
    transaction_ok(
      fun() ->
              OldInfo = ll_get_props(?dbt_games, GameID),
              NewInfo =
                  echessd_lib:proplist_replace(
                    OldInfo, GameInfo),
              set_game_props_(GameID, NewInfo)
      end).
set_game_props_(GameID, GameInfo) ->
    Users =
        [N || {users, L} <- GameInfo,
              {N, _Role} <- L],
    lists:foreach(
      fun(Username) ->
              UserProperties = ll_get_props(?dbt_users, Username),
              UserGames =
                  lists:usort(
                    [GameID | proplists:get_value(
                                games, UserProperties, [])]),
              ll_replace_props(
                ?dbt_users, Username, UserProperties,
                [{games, UserGames}])
      end, Users),
    ll_set_props(?dbt_games, GameID, GameInfo).

%% @doc Remove game from database.
%% @spec delgame(GameID) -> ok | {error, Reason}
%%     GameID = echessd_game:echessd_game_id(),
%%     Reason = term()
delgame(GameID) ->
    transaction_ok(
      fun() ->
              case mnesia:read({?dbt_games, GameID}) of
                  [HRec] ->
                      GameInfo = HRec#hrec.val,
                      Users =
                          [N || {users, L} <- GameInfo,
                                {N, _Role} <- L],
                      lists:foreach(
                        fun(Username) ->
                                UserProperties =
                                    ll_get_props(?dbt_users, Username),
                                UserGames =
                                    lists:usort(
                                      proplists:get_value(
                                        games, UserProperties, []) --
                                          [GameID]),
                                ll_replace_props(
                                  ?dbt_users, Username, UserProperties,
                                  [{games, UserGames}])
                        end, Users),
                      mnesia:delete({?dbt_games, GameID});
                  _ -> ok
              end
      end).

%% @doc Makes game move for user.
%% @spec gamemove(GameID, Username, Move) -> ok | {error, Reason}
%%     GameID = echessd_game:echessd_game_id(),
%%     Username = echessd_user:echessd_user(),
%%     Move = echessd_game:echessd_move(),
%%     Reason = term()
gamemove(GameID, Username, Move) ->
    transaction_ok(
      fun() ->
              GameInfo = ll_get_props(?dbt_games, GameID),
              %% check if such user exists
              _UserProperties = ll_get_props(?dbt_users, Username),
              case echessd_game:who_must_turn(GameInfo) of
                  Username ->
                      TurnColor = echessd_game:turn_color(GameInfo),
                      GameType = proplists:get_value(type, GameInfo),
                      History = proplists:get_value(moves, GameInfo, []),
                      {Board, _Captures} =
                          echessd_game:from_scratch(GameType, History),
                      case echessd_game:is_valid_move(
                             GameType, Board, TurnColor, Move, History) of
                          ok ->
                              ll_replace_props(
                                ?dbt_games, GameID, GameInfo,
                                [{moves, History ++ [Move]}]);
                          {error, Reason} ->
                              mnesia:abort({wrong_move, Reason})
                      end;
                  _ ->
                      case lists:member(
                             Username,
                             [N || {users, L} <- GameInfo,
                                   {N, Role} <- L,
                                   lists:member(Role, [?white, ?black])]) of
                          true ->
                              mnesia:abort(not_your_turn);
                          _ ->
                              mnesia:abort(not_your_game)
                      end
              end
      end).

%% ----------------------------------------------------------------------
%% Internal functions
%% ----------------------------------------------------------------------

transaction_ok(Fun) ->
    case transaction(Fun) of
        {ok, _} -> ok;
        Error -> Error
    end.

transaction(Fun) ->
    case mnesia:transaction(Fun) of
        {atomic, Result} ->
            {ok, Result};
        {aborted, Reason} ->
            {error, Reason}
    end.

ll_replace_props(DbTable, RecID, OldProps, Props2Replace) ->
    NewProps = echessd_lib:proplist_replace(OldProps, Props2Replace),
    mnesia:write(
      DbTable,
      #hrec{key = RecID,
            val = NewProps},
      write).

ll_get_props(DbTable, RecID) ->
    case mnesia:read({DbTable, RecID}) of
        [HRec] ->
            HRec#hrec.val;
        _ when DbTable == ?dbt_users ->
            mnesia:abort({no_such_user, RecID});
        _ when DbTable == ?dbt_games ->
            mnesia:abort({no_such_game, RecID});
        _ ->
            mnesia:abort({no_such_item, RecID})
    end.

ll_set_props(DbTable, RecID, Props) ->
    mnesia:write(
      DbTable,
      #hrec{key = RecID,
            val = Props},
      write).

