%%%-------------------------------------------------------------------
%%% File    : echessd.hrl
%%% Author  : Aleksey Morarash <aleksey.morarash@gmail.com>
%%% Created : 20 Jan 2012
%%% License : FreeBSD
%%% Description : common constants definitions
%%%
%%%-------------------------------------------------------------------

-ifndef(_ECHESSD).
-define(_ECHESSD, true).

%% Configuration items names
-define(CFG_LOGLEVEL, loglevel).
-define(CFG_LOGFILE, logfile).
-define(CFG_BIND_ADDR, bind_addr).
-define(CFG_BIND_PORT, bind_port).
-define(CFG_DEF_LANG, default_language).
-define(CFG_DEF_STYLE, default_style).
-define(CFG_XMPP_ENABLED, xmpp_enabled).
-define(CFG_XMPP_USER, xmpp_user).
-define(CFG_XMPP_SERVER, xmpp_server).
-define(CFG_XMPP_PASSWORD, xmpp_password).
-define(CFG_SHOW_ABOUT, show_about).
-define(CFG_SHOW_COPYRIGHTS, show_copyrights).
-define(CFG_DB_PATH, db_path).
-define(CFG_MIME_TYPES, mime_types).
-define(CFG_INSTANCE_ID, instance_id).
-define(CFG_COOKIE, cookie).

-define(CFGS, [?CFG_LOGLEVEL, ?CFG_LOGFILE,
               ?CFG_BIND_ADDR, ?CFG_BIND_PORT,
               ?CFG_DEF_LANG, ?CFG_DEF_STYLE,
               ?CFG_XMPP_USER, ?CFG_XMPP_SERVER,
               ?CFG_XMPP_PASSWORD, ?CFG_XMPP_ENABLED,
               ?CFG_SHOW_ABOUT, ?CFG_SHOW_COPYRIGHTS,
               ?CFG_MIME_TYPES, ?CFG_INSTANCE_ID,
               ?CFG_COOKIE, ?CFG_DB_PATH]).

-define(CFG_CONFIG_PATH, config_path).

%% log message classes
-define(LOG_ERR, err).
-define(LOG_INFO, info).
-define(LOG_DEBUG, debug).

-define(LOG_LEVELS, [?LOG_ERR, ?LOG_INFO, ?LOG_DEBUG]).

%% game types
-define(GAME_CLASSIC, classic).
-define(GAME_TYPES, [?GAME_CLASSIC]).

%% page identifiers
-define(PAGE_HOME, home).
-define(PAGE_GAME, game).
-define(PAGE_USERS, users).
-define(PAGE_USER, user).
-define(PAGE_NEWGAME, newgame).
-define(PAGE_REGISTER, register).
-define(PAGE_LOGIN, login).
-define(PAGE_EXIT, exit).
-define(PAGE_MOVE, move).
-define(PAGE_ACKGAME, ackgame).
-define(PAGE_DENYGAME, denygame).
-define(PAGE_EDITUSER, edituser).
-define(PAGE_SAVEUSER, saveuser).
-define(PAGE_PASSWD_FORM, passwdform).
-define(PAGE_PASSWD, passwd).
-define(PAGE_DRAW_CONFIRM, drawconfirm).
-define(PAGE_DRAW, draw).
-define(PAGE_GIVEUP_CONFIRM, giveupconfirm).
-define(PAGE_GIVEUP, giveup).

-define(ALL_PAGES,
        [?PAGE_HOME, ?PAGE_GAME, ?PAGE_USERS, ?PAGE_USER, ?PAGE_NEWGAME,
         ?PAGE_REGISTER, ?PAGE_LOGIN, ?PAGE_EXIT, ?PAGE_MOVE, ?PAGE_ACKGAME,
         ?PAGE_DENYGAME, ?PAGE_EDITUSER, ?PAGE_SAVEUSER, ?PAGE_PASSWD_FORM,
         ?PAGE_PASSWD, ?PAGE_DRAW_CONFIRM, ?PAGE_DRAW, ?PAGE_GIVEUP_CONFIRM,
         ?PAGE_GIVEUP]).

%% http query keys
-define(Q_PAGE, page).
-define(Q_STEP, step).
-define(Q_GAME, game).
-define(Q_MOVE, move).
-define(Q_COMMENT, comment).
-define(Q_PRIVATE, private).
-define(Q_GAMETYPE, gametype).
-define(Q_COLOR, color).
-define(Q_EDIT_JID, editjid).
-define(Q_EDIT_STYLE, editstyle).
-define(Q_EDIT_AUTO_PERIOD, editautoperiod).
-define(Q_EDIT_AUTO_REFRESH, editautorefresh).
-define(Q_EDIT_NOTIFY, editnotify).
-define(Q_EDIT_SHOW_COMMENT, editshowcomment).
-define(Q_EDIT_SHOW_HISTORY, editshowhistory).
-define(Q_EDIT_SHOW_IN_LIST, editshowinlist).
-define(Q_EDIT_LANGUAGE, editlanguage).
-define(Q_EDIT_TIMEZONE, edittimezone).
-define(Q_EDIT_FULLNAME, editfullname).
-define(Q_EDIT_PASSWORD0, editpassword0).
-define(Q_EDIT_PASSWORD1, editpassword1).
-define(Q_EDIT_PASSWORD2, editpassword2).
-define(Q_EDIT_USERNAME, editusername).
-define(Q_USERNAME, username).
-define(Q_PASSWORD, password).
-define(Q_LANG, lang).

-define(ALL_Q_KEYS,
        [?Q_PAGE, ?Q_STEP, ?Q_GAME, ?Q_MOVE, ?Q_COMMENT,
         ?Q_PRIVATE, ?Q_GAMETYPE, ?Q_COLOR, ?Q_EDIT_JID,
         ?Q_EDIT_STYLE, ?Q_EDIT_AUTO_PERIOD, ?Q_EDIT_AUTO_REFRESH,
         ?Q_EDIT_NOTIFY, ?Q_EDIT_SHOW_COMMENT, ?Q_EDIT_SHOW_HISTORY,
         ?Q_EDIT_SHOW_IN_LIST, ?Q_EDIT_LANGUAGE, ?Q_EDIT_TIMEZONE,
         ?Q_EDIT_FULLNAME, ?Q_EDIT_PASSWORD0, ?Q_EDIT_PASSWORD1,
         ?Q_EDIT_PASSWORD2, ?Q_EDIT_USERNAME, ?Q_USERNAME, ?Q_PASSWORD,
         ?Q_LANG
        ]).

%% colors
-define(white, w).
-define(black, b).

%% chessman types
-define(pawn, p).
-define(rook, r).
-define(knight, h).
-define(bishop, b).
-define(queen, q).
-define(king, k).

%% chessmen
-define(wpawn, {?white, ?pawn}).
-define(bpawn, {?black, ?pawn}).
-define(wrook, {?white, ?rook}).
-define(brook, {?black, ?rook}).
-define(wknight, {?white, ?knight}).
-define(bknight, {?black, ?knight}).
-define(wbishop, {?white, ?bishop}).
-define(bbishop, {?black, ?bishop}).
-define(wqueen, {?white, ?queen}).
-define(bqueen, {?black, ?queen}).
-define(wking, {?white, ?king}).
-define(bking, {?black, ?king}).

-define(empty, z).

%% user info item keys
-define(ui_password, password).
-define(ui_created, created).
-define(ui_login, login).
-define(ui_fullname, fullname).
-define(ui_timezone, timezone).
-define(ui_language, language).
-define(ui_show_in_list, show_in_list).
-define(ui_show_history, show_history).
-define(ui_show_comment, show_comment).
-define(ui_notify, notify).
-define(ui_auto_refresh, auto_refresh).
-define(ui_auto_refresh_period, auto_refresh_period).
-define(ui_style, style).
-define(ui_jid, jid).
-define(ui_games, games).

%% game info item keys
-define(gi_type, type).
-define(gi_history, history).
-define(gi_created, created).
-define(gi_private, private).
-define(gi_creator, creator).
-define(gi_users, users).
-define(gi_status, status).
-define(gi_winner, winner).
-define(gi_winner_color, winner_color).
-define(gi_draw_request_from, draw_request_from).
-define(gi_acknowledged, acknowledged).

%% game statuses
-define(gs_alive, alive).
-define(gs_checkmate, checkmate).
-define(gs_draw_stalemate, draw_stalemate).
-define(gs_draw_agreement, draw_agreement).
-define(gs_give_up, give_up).

%% ply info item keys
-define(pi_time, time).
-define(pi_notation, notation).
-define(pi_comment, comment).

%% user session record
-record(session,
        {id :: echessd_session:id(),
         created :: erlang:timestamp(),
         username :: echessd_user:name() | undefined,
         timezone :: echessd_lib:administrative_offset() | undefined,
         language :: (LanguageID :: atom() | undefined),
         style :: (StyleID :: atom() | undefined),
         userinfo = [] :: echessd_user:info(),
         vars = [] :: [{Key :: any(), Value :: any()}]
        }).

%% error reasons
-define(e_user_already_exists, user_already_exists).
-define(e_not_your_game, not_your_game).
-define(e_not_your_turn, not_your_turn).
-define(e_unable_to_deny_confirmed_game, unable_to_deny_confirmed_game).
-define(e_game_not_acknowledged, game_not_acknowledged).
-define(e_game_ended, game_ended).
-define(e_no_such_user, no_such_user).
-define(e_no_such_game, no_such_game).
-define(e_no_such_item, no_such_item).
-define(e_bad_username, bad_username).
-define(e_password_incorrect, password_incorrect).
-define(e_bad_info_item, bad_info_item).
-define(e_httpd_start, httpd_start).
-define(e_undefined_language, undefined_language).
-define(e_enoent, enoent).
-define(e_bad_move, bad_move).

%% ----------------------------------------------------------------------

%% special value for the 'step' HTTP query variable
-define(last, last).

-define(nonnegint(I), (is_integer(I) andalso I >= 0)).

-define(is_now(T),
        (is_tuple(T)
         andalso size(T) == 3
         andalso ?nonnegint(element(1, T))
         andalso ?nonnegint(element(2, T))
         andalso ?nonnegint(element(3, T)))).

%% ----------------------------------------------------------------------

-include_lib("inets/include/httpd.hrl").

-define(HTTP_GET, "GET").
-define(HTTP_POST, "POST").

-endif.
