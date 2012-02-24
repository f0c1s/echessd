%%% @author Aleksey Morarash <aleksey.morarash@gmail.com>
%%% @since 21 Jan 2012
%%% @copyright 2012, Aleksey Morarash
%%% @doc HTTP session implementation.

-module(echessd_session).

-export([init/0,
         mk/1,
         get/1,
         del/1,
         read/1
        ]).

-include("echessd.hrl").

%% ----------------------------------------------------------------------
%% Type definitions
%% ----------------------------------------------------------------------

-type echessd_session_id() :: string().
%% HTTP session identifier.

%% ----------------------------------------------------------------------
%% API functions
%% ----------------------------------------------------------------------

%% @doc Creates non-persistent storage of user current sessions.
%% @spec init() -> ok
init() ->
    ?dbt_session =
        ets:new(?dbt_session, [named_table, public, set]),
    ok.

%% @doc Creates new session for user.
%% @spec mk(Username) -> echessd_session_id()
%%     Username = echessd_user:echessd_user()
mk(User) ->
    ets:insert(?dbt_session, [{SID = sid(), User, ""}]),
    SID.

%% @doc Fetch session data.
%% @spec get(SID) -> {ok, Username, SessionVars} | undefined
%%     SID = echessd_session_id(),
%%     Username = echessd_user:echessd_user(),
%%     SessionVars = proplist()
get(SID) ->
    case ets:lookup(?dbt_session, SID) of
        [{_, User, Vars}] ->
            {ok, User, Vars};
        _ ->
            undefined
    end.

%% @doc Removes session (logout user).
%% @spec del(SID) -> ok
%%     SID = echessd_session_id()
del(SID) ->
    true = ets:delete(?dbt_session, SID),
    ok.

%% @doc Read session data according to cookie contents and
%%      write such data in process dictionary.
%% @spec read(Cookie) -> ok
%%     Cookie = proplist()
read(Cookie) ->
    put(logged_in, false),
    erase(sid),
    erase(username),
    erase(userinfo),
    erase(timezone),
    erase(language),
    [erase(K) || {{session_var, _} = K, _} <- erlang:get()],
    SID = proplists:get_value("sid", Cookie),
    case echessd_session:get(SID) of
        {ok, Username, Vars} ->
            case echessd_user:getprops(Username) of
                {ok, UserInfo} ->
                    put(logged_in, true),
                    put(sid, SID),
                    put(username, Username),
                    put(userinfo, UserInfo),
                    put(timezone,
                        proplists:get_value(
                          timezone, UserInfo,
                          echessd_lib:local_offset())),
                    {LangAbbr, _LangName} =
                        echessd_user:lang_info(UserInfo),
                    put(language, LangAbbr),
                    lists:foreach(
                      fun({K, V}) ->
                              put({session_var, K}, V)
                      end, Vars);
                _ ->
                    echessd_session:del(SID)
            end;
        _ ->
            case echessd_lib:parse_language(
                   proplists:get_value("lang", Cookie)) of
                {LangAbbr, _LangName} ->
                    put(language, LangAbbr);
                _ -> nop
            end
    end, ok.

%% ----------------------------------------------------------------------
%% Internal functions
%% ----------------------------------------------------------------------

%% @doc Generates user session ID.
%% @spec sid() -> echessd_session_id()
sid() ->
    random:seed(now()),
    integer_to_list(random:uniform(1000000000000000000)).

