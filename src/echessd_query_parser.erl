%%% @doc
%%% HTTP query string parsing tools.

%%% @author Aleksey Morarash <aleksey.morarash@gmail.com>
%%% @since 23 Nov 2013
%%% @copyright 2013, Aleksey Morarash

-module(echessd_query_parser).

%% API exports
-export([parse/1, encode/1, encode/2]).

-include("echessd.hrl").

%% ----------------------------------------------------------------------
%% Type definitions
%% ----------------------------------------------------------------------

-export_type(
   [http_query/0,
    http_query_item/0,
    http_query_key/0,
    section/0,
    step/0
   ]).

-type http_query() :: [http_query_item()].

-type http_query_item() ::
        {?Q_PAGE, section()} |
        {?Q_STEP, step()} |
        {?Q_GAME, pos_integer()} |
        {?Q_MOVE, nonempty_string()} |
        {?Q_COMMENT, string()} |
        {?Q_PRIVATE, boolean()} |
        {?Q_GAMETYPE, echessd_game:gametype()} |
        {?Q_COLOR, ?black | ?white} |
        {?Q_EDIT_JID, string()} |
        {?Q_EDIT_STYLE, StyleID :: atom()} |
        {?Q_EDIT_AUTO_PERIOD, pos_integer()} |
        {?Q_EDIT_AUTO_REFRESH, boolean()} |
        {?Q_EDIT_NOTIFY, boolean()} |
        {?Q_EDIT_SHOW_COMMENT, boolean()} |
        {?Q_EDIT_SHOW_HISTORY, boolean()} |
        {?Q_EDIT_SHOW_IN_LIST, boolean()} |
        {?Q_EDIT_LANGUAGE, LangID :: atom()} |
        {?Q_EDIT_TIMEZONE, echessd_lib:administrative_offset()} |
        {?Q_EDIT_FULLNAME, string()} |
        {?Q_EDIT_PASSWORD0, nonempty_string()} |
        {?Q_EDIT_PASSWORD1, nonempty_string()} |
        {?Q_EDIT_PASSWORD2, nonempty_string()} |
        {?Q_EDIT_USERNAME, nonempty_string()} |
        {?Q_USERNAME, nonempty_string()} |
        {?Q_PASSWORD, nonempty_string()} |
        {?Q_LANG, LangID :: atom()}.

-type http_query_key() ::
        ?Q_PAGE | ?Q_STEP | ?Q_GAME | ?Q_MOVE | ?Q_COMMENT |
        ?Q_PRIVATE | ?Q_GAMETYPE | ?Q_COLOR |
        ?Q_EDIT_JID | ?Q_EDIT_STYLE | ?Q_EDIT_AUTO_PERIOD |
        ?Q_EDIT_AUTO_REFRESH | ?Q_EDIT_NOTIFY | ?Q_EDIT_SHOW_COMMENT |
        ?Q_EDIT_SHOW_HISTORY | ?Q_EDIT_SHOW_IN_LIST | ?Q_EDIT_LANGUAGE |
        ?Q_EDIT_TIMEZONE | ?Q_EDIT_FULLNAME | ?Q_EDIT_PASSWORD0 |
        ?Q_EDIT_PASSWORD1 | ?Q_EDIT_PASSWORD2 | ?Q_EDIT_USERNAME |
        ?Q_USERNAME | ?Q_PASSWORD | ?Q_LANG.

-type section() ::
        ?PAGE_HOME | ?PAGE_GAME | ?PAGE_USERS |
        ?PAGE_USER | ?PAGE_NEWGAME | ?PAGE_REGISTER |
        ?PAGE_LOGIN | ?PAGE_EXIT | ?PAGE_MOVE |
        ?PAGE_ACKGAME | ?PAGE_DENYGAME | ?PAGE_EDITUSER |
        ?PAGE_SAVEUSER | ?PAGE_PASSWD_FORM | ?PAGE_PASSWD |
        ?PAGE_DRAW_CONFIRM | ?PAGE_DRAW | ?PAGE_GIVEUP_CONFIRM |
        ?PAGE_GIVEUP.

-type step() :: non_neg_integer() | ?last.

%% ----------------------------------------------------------------------
%% API functions
%% ----------------------------------------------------------------------

%% @doc Parse the HTTP query (query string for GET, query data for POST).
-spec parse(ModData :: #mod{}) -> DecodedQuery :: http_query().
parse(ModData) ->
    {Path, GetQueryString} =
        echessd_lib:split4pathNquery(ModData#mod.request_uri),
    parse_(
      httpd:parse_query(
        case ModData#mod.method of
            ?HTTP_GET when GetQueryString == [] ->
                try
                    %% handle shortcut http://host/$GAME_ID
                    "/" ++ StrGameID = Path,
                    {ok, GameID} = parse_query_value(?Q_GAME, StrGameID),
                    "/?" ++ Str = encode([{?Q_PAGE, ?PAGE_GAME},
                                          {?Q_GAME, GameID}]),
                    Str
                catch _:_ ->
                        GetQueryString
                end;
            ?HTTP_GET ->
                GetQueryString;
            ?HTTP_POST ->
                ModData#mod.entity_body
        end)).

%% @doc Encode the query to URL query string.
-spec encode(Query :: echessd_query_parser:http_query()) ->
                    URL :: nonempty_string().
encode(Query) ->
    lists:flatten(
      ["/?",
       string:join([atom_to_list(K) ++ "=" ++ encode(K, V) ||
                       {K, V} <- Query], "&")]).

%% @doc Encode the query item value.
-spec encode(QueryKey :: http_query_key(),
             QueryValue :: any()) -> iolist().
encode(?Q_EDIT_TIMEZONE, Offset) ->
    echessd_lib:time_offset_to_list(Offset);
encode(_QueryKey, QueryValue) when is_list(QueryValue) ->
    QueryValue;
encode(_QueryKey, QueryValue) ->
    io_lib:format("~w", [QueryValue]).

%% ----------------------------------------------------------------------
%% Internal functions
%% ----------------------------------------------------------------------

%% @doc
-spec parse_(DecodedQuery :: [{Key :: nonempty_string(),
                              Value :: string()}]) ->
                   Query :: echessd_query_parser:http_query().
parse_([]) ->
    [];
parse_([{StrKey, StrValue} | Tail]) ->
    case echessd_lib:list_to_atom(StrKey, ?ALL_Q_KEYS) of
        {ok, Key} ->
            case parse_query_value(Key, StrValue) of
                {ok, Value} ->
                    [{Key, Value} | parse_(Tail)];
                error ->
                    parse_(Tail)
            end;
        error ->
            parse_(Tail)
    end.

%% @doc Parse the value for the query variable.
-spec parse_query_value(Key :: echessd_query_parser:http_query_key(),
                        StrValue :: string()) ->
                               {ok, Value :: any()} | error.
parse_query_value(Key, StrValue) ->
    try
        {ok, parse_query_value_(Key, StrValue)}
    catch
        _:_ ->
            error
    end.

%% @doc Parse the value for the query variable.
%% The function return valid Erlang term or throws exception on an error.
-spec parse_query_value_(Key :: echessd_query_parser:http_query_key(),
                         StrValue :: string()) ->
                                Value :: any().
parse_query_value_(?Q_PAGE, String) ->
    echessd_lib:list_to_atom(String, ?ALL_PAGES, ?PAGE_HOME);
parse_query_value_(?Q_STEP, String) ->
    try list_to_integer(String) of
        Int when Int >= 0 ->
            Int;
        _ ->
            ?last
    catch
        _:_ ->
            ?last
    end;
parse_query_value_(?Q_GAME, String) ->
    Int = list_to_integer(String),
    true = Int >= 1,
    Int;
parse_query_value_(?Q_MOVE, [_ | _] = String) ->
    [_, _, _, _ | _] = string:to_lower(echessd_lib:strip(String, " \t\r\n"));
parse_query_value_(?Q_COMMENT, String) ->
    echessd_lib:strip(String, " \t\r\n");
parse_query_value_(?Q_GAMETYPE, String) ->
    echessd_lib:list_to_atom(String, ?GAME_TYPES, ?GAME_CLASSIC);
parse_query_value_(?Q_COLOR, String) ->
    echessd_lib:list_to_atom(
      String, [?black, ?white],
      echessd_lib:random_elem([?white, ?black]));
parse_query_value_(?Q_EDIT_JID, String) ->
    echessd_lib:strip(String, " \t\r\n");
parse_query_value_(?Q_EDIT_STYLE, String) ->
    echessd_styles:parse(String);
parse_query_value_(?Q_EDIT_AUTO_PERIOD, String) ->
    try
        Int = list_to_integer(String),
        true = Int > 0,
        Int
    catch
        _:_ ->
            echessd_user:default(?ui_auto_refresh_period)
    end;
parse_query_value_(?Q_EDIT_TIMEZONE, String) ->
    case echessd_lib:list_to_time_offset(String) of
        {ok, Offset} ->
            Offset;
        error ->
            echessd_lib:local_offset()
    end;
parse_query_value_(?Q_EDIT_FULLNAME, String) ->
    echessd_lib:strip(String, " \t\r\n");
parse_query_value_(PasswordKey, [_ | _] = String)
  when PasswordKey == ?Q_PASSWORD;
       PasswordKey == ?Q_EDIT_PASSWORD0;
       PasswordKey == ?Q_EDIT_PASSWORD1;
       PasswordKey == ?Q_EDIT_PASSWORD2 ->
    String;
parse_query_value_(UsernameKey, String)
  when UsernameKey == ?Q_EDIT_USERNAME;
       UsernameKey == ?Q_USERNAME ->
    [_ | _] = echessd_lib:strip(String, " \t\r\n");
parse_query_value_(BooleanKey, String)
  when BooleanKey == ?Q_PRIVATE;
       BooleanKey == ?Q_EDIT_AUTO_REFRESH;
       BooleanKey == ?Q_EDIT_NOTIFY;
       BooleanKey == ?Q_EDIT_SHOW_COMMENT;
       BooleanKey == ?Q_EDIT_SHOW_HISTORY;
       BooleanKey == ?Q_EDIT_SHOW_IN_LIST ->
    length(String) > 0;
parse_query_value_(LanguageKey, String)
  when LanguageKey == ?Q_EDIT_LANGUAGE;
       LanguageKey == ?Q_LANG ->
    echessd_lang:parse(String).
