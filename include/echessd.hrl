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
-define(CFG_DOC_ROOT, doc_root).

-define(CFGS, [?CFG_LOGLEVEL, ?CFG_LOGFILE,
               ?CFG_BIND_ADDR, ?CFG_BIND_PORT,
               ?CFG_DOC_ROOT]).

-define(MANDATORY_CFGS, []).

%% Configuration storage (ETS) name
-define(echessd_cfg, echessd_cfg).

%% database tables
-define(dbt_users, echessd_dbt_users).
-define(dbt_games, echessd_dbt_games).
-define(dbt_session, echessd_dbt_session).

%% log message classes
-define(LOG_ERR, err).
-define(LOG_INFO, info).
-define(LOG_DEBUG, debug).

-define(LOG_LEVELS, [?LOG_ERR, ?LOG_INFO, ?LOG_DEBUG]).

%% game styles
-define(GAME_CLASSIC, "classic").

-define(GAME_TYPES, [?GAME_CLASSIC]).

%% site sections
-define(SECTION_HOME, "home").
-define(SECTION_GAME, "game").
-define(SECTION_USERS, "users").
-define(SECTION_USER, "user").
-define(SECTION_NEWGAME, "newgame").
-define(SECTION_REG, "register").
-define(SECTION_LOGIN, "login").
-define(SECTION_EXIT, "exit").
-define(SECTION_MOVE, "move").

-define(SECTIONS,
        [?SECTION_HOME, ?SECTION_GAME,
         ?SECTION_USERS, ?SECTION_USER,
         ?SECTION_NEWGAME]).

%% colors
-define(white, w).
-define(black, b).

%% figures
-define(pawn, p).
-define(rook, r).
-define(knight, h).
-define(bishop, b).
-define(queen, q).
-define(king, k).

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

%% ----------------------------------------------------------------------

-define(nonnegint(I), (is_integer(I) andalso I >= 0)).

-define(is_now(T),
        (is_tuple(T)
         andalso size(T) == 3
         andalso ?nonnegint(element(1, T))
         andalso ?nonnegint(element(2, T))
         andalso ?nonnegint(element(3, T)))).

-endif.

