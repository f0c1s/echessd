%%% @doc
%%% Classic chess rules implementation.

%%% @author Aleksey Morarash <aleksey.morarash@gmail.com>
%%% @since 22 Jan 2012
%%% @copyright 2012, Aleksey Morarash

-module(echessd_rules_classic).

-export(
   [move/2,
    hint/1,
    from_scratch/1,
    transpose/1
   ]).

-include("echessd.hrl").

-define(null, '*null').

%% ----------------------------------------------------------------------
%% Type definitions
%% ----------------------------------------------------------------------

-type board() ::
        {board_row(), board_row(), board_row(), board_row(),
         board_row(), board_row(), board_row(), board_row()}.

-type board_row() ::
        {echessd_game:entry(), echessd_game:entry(),
         echessd_game:entry(), echessd_game:entry(),
         echessd_game:entry(), echessd_game:entry(),
         echessd_game:entry(), echessd_game:entry()}.

-type coord() ::
        {Column :: 1..8, Row :: 1..8}.

-type delta() ::
        {ColumnDelta :: -2..2, RowDelta :: -2..2}.

-type promotion_chessman_type() ::
        ?rook | ?knight | ?bishop | ?queen.

%% ----------------------------------------------------------------------
%% API functions
%% ----------------------------------------------------------------------

%% @doc Do the next move.
-spec move(History :: echessd_game:history(), Ply :: echessd_game:ply()) ->
                  {ok, NewBoard :: board(),
                   NewHistory :: echessd_game:history(),
                   GameStatus :: echessd_game:final_status()}.
move(History, {PlyCoords, PlyInfo} = Ply) ->
    {Board, _Captured, Color} = from_scratch(History),
    {SrcCoord, DstCoord, PlyCoordsTail} = ply_dec(Ply),
    {Color, _ChessmanType} = Chessman = getcell(Board, SrcCoord),
    case getcell(Board, DstCoord) of
        {Color, _} ->
            %% friendly fire
            throw(?e_bad_move);
        {_, ?king} ->
            %% can't capture the king
            throw(?e_bad_move);
        _ -> ok
    end,
    true = lists:member(
             DstCoord, hint_for_cell_unsafe(Board, SrcCoord, History)),
    {ok, NewBoard, Capture} =
        move_safe(Board, SrcCoord, DstCoord, PlyCoordsTail, History),
    NewHistory = History ++ [Ply],
    Status = status(NewBoard, not_color(Color), NewHistory),
    Notation =
        notation(Chessman, Ply, Capture, NewBoard, Status, NewHistory),
    FinalPly =
        {PlyCoords,
         [{?pi_notation, Notation} | lists:keydelete(?pi_notation, 1, PlyInfo)]},
    {ok, NewBoard, History ++ [FinalPly], Status}.

%% @doc Return a list of all available moves.
%% The function used only for next move highlighting
%% in the user interface.
-spec hint(History :: echessd_game:history()) ->
                  Plies :: [echessd_game:ply_coords()].
hint(History) ->
    {Board, _Captured, Color} = from_scratch(History),
    lists:flatmap(
      fun(SrcCoord) ->
              case getcell(Board, SrcCoord) of
                  {Color, _ChessmanType} ->
                      lists:flatmap(
                        fun(DstCoord) ->
                                case is_valid(Board, SrcCoord, DstCoord, History) of
                                    true ->
                                        [ind_enc(SrcCoord) ++ ind_enc(DstCoord)];
                                    false ->
                                        []
                                end
                        end, hint_for_cell_unsafe(Board, SrcCoord, History));
                  _ -> []
              end
      end, all_cells()).

%% @doc Return chess board with chessmen in their current positions,
%% a list of all captured chessmen and the color of the next move.
-spec from_scratch(History :: echessd_game:history()) ->
                          {Board :: board(),
                           Captured :: [echessd_game:chessman()],
                           NextColor :: echessd_game:color()}.
from_scratch(History) ->
    {Board, Captured, HistoryLen} =
        lists:foldl(
          fun(Ply, {B, C, HL}) ->
                  {NewBoard, Capture} = move_unsafe(B, Ply),
                  {NewBoard, [Capture | C], HL + 1}
          end, {new(), _Captured = [], _HistoryLen = 0}, History),
    {Board, Captured,
     if HistoryLen rem 2 == 0 ->
             ?white;
        true ->
             ?black
     end}.

%% @doc Turn the board at 180 degrees.
-spec transpose(Board :: board()) -> TransposedBoard :: board().
transpose(Board) ->
    list_to_tuple(
      lists:reverse(
        [list_to_tuple(
           lists:reverse(
             tuple_to_list(R))) || R <- tuple_to_list(Board)])).

%% ----------------------------------------------------------------------
%% Internal functions
%% ----------------------------------------------------------------------

%% @doc Create a chess board with the all chessmen at their start point.
-spec new() -> board().
new() ->
    {
     %%  a       b        c       d       e       f        g       h
     {?brook,?bknight,?bbishop,?bqueen,?bking,?bbishop,?bknight,?brook}, % 8
     {?bpawn,?bpawn,  ?bpawn,  ?bpawn, ?bpawn,?bpawn,  ?bpawn,  ?bpawn}, % 7
     {?empty,?empty,  ?empty,  ?empty, ?empty,?empty,  ?empty,  ?empty}, % 6
     {?empty,?empty,  ?empty,  ?empty, ?empty,?empty,  ?empty,  ?empty}, % 5
     {?empty,?empty,  ?empty,  ?empty, ?empty,?empty,  ?empty,  ?empty}, % 4
     {?empty,?empty,  ?empty,  ?empty, ?empty,?empty,  ?empty,  ?empty}, % 3
     {?wpawn,?wpawn,  ?wpawn,  ?wpawn, ?wpawn,?wpawn,  ?wpawn,  ?wpawn}, % 2
     {?wrook,?wknight,?wbishop,?wqueen,?wking,?wbishop,?wknight,?wrook}  % 1
     %%  a       b        c       d       e       f        g       h
    }.

%% @doc Just change chessman locations on the chess board.
-spec move_chessman(Board :: board(),
                    SrcCoord :: coord(), DstCoord :: coord(),
                    SrcEntry :: echessd_game:entry(),
                    DstEntry :: echessd_game:entry()) ->
                           {NewBoard :: board(),
                            Capture :: echessd_game:entry()}.
move_chessman(Board, SrcCoord, DstCoord, SrcEntry, DstEntry) ->
    {setcell(setcell(Board, SrcCoord, ?empty), DstCoord, SrcEntry),
     DstEntry}.

%% @doc Return game status.
-spec status(Board :: board(), Color :: echessd_game:color(),
             History :: echessd_game:history()) ->
                    GameStatus :: echessd_game:status().
status(Board, Color, History) ->
    case can_move(Board, Color, History) of
        true ->
            ?gs_alive;
        false ->
            KingCoord = whereis_the_king(History, Color),
            case is_cell_attacked(Board, KingCoord, not_color(Color)) of
                false ->
                    ?gs_draw_stalemate;
                _ ->
                    ?gs_checkmate
            end
    end.

%% @doc Helper for the can_move/1 fun.
-spec can_move(Board :: board(), Color :: echessd_game:color(),
               History :: echessd_game:history()) -> boolean().
can_move(Board, Color, History) ->
    lists:any(
      fun(I1) ->
              case getcell(Board, I1) of
                  {Color, _ChessmanType} ->
                      lists:any(
                        fun(I2) ->
                                is_valid(Board, I1, I2, History)
                        end, hint_for_cell_unsafe(Board, I1, History));
                  _ -> false
              end
      end, all_cells()).

%% @doc Make the chessman move according to the chessman type.
%% No additional checks will be performed (e.g is king checked).
-spec move_unsafe(Board :: board(),
                  Ply :: echessd_game:ply() |
                         echessd_game:ply_coords()) ->
                         {NewBoard :: board(),
                          Capture :: echessd_game:entry()}.
move_unsafe(Board, Ply) ->
    {I1, I2, Tail} = ply_dec(Ply),
    move_unsafe(Board, I1, I2, Tail).

%% @doc Helper for the move_unsafe/2 fun.
-spec move_unsafe(Board :: board(), SrcCoord :: coord(),
                  DstCoord :: coord(), Tail :: string()) ->
                         {NewBoard :: board(),
                          Capture :: echessd_game:entry()}.
move_unsafe(Board, I1, I2, Tail) ->
    {MyColor, _SrcChessmanType} = F1 = getcell(Board, I1),
    F2 = getcell(Board, I2),
    case is_en_passant_simple(Board, I1, I2, F1, F2) of
        {ok, EnemyPawnCoord, EnemyPawn} ->
            Board2 = setcell(Board, EnemyPawnCoord, ?empty),
            {Board3, ?empty} = move_chessman(Board2, I1, I2, F1, F2),
            {Board3, EnemyPawn};
        _ ->
            case is_promotion(I2, F1, Tail) of
                {ok, DstChessmanType} ->
                    move_chessman(
                      Board, I1, I2, {MyColor, DstChessmanType}, F2);
                _ ->
                    case is_castling(I1, I2, F1, F2) of
                        {ok, RookPlyCoords} ->
                            {B2, _} = move_chessman(Board, I1, I2, F1, F2),
                            RookPly = {RookPlyCoords, []},
                            move_unsafe(B2, RookPly);
                        false ->
                            move_chessman(Board, I1, I2, F1, F2)
                    end
            end
    end.

%% @doc Check if the ply is correct or not (according to *ALL*
%% chess rules).
-spec is_valid(Board :: board(), SrcCoord :: coord(),
               DstCoord :: coord(), History :: echessd_game:history()) ->
                      boolean().
is_valid(Board, SrcCoord, DstCoord, History) ->
    try
        {ok, _NewBoard, _Capture} =
            move_safe(Board, SrcCoord, DstCoord, [], History),
        true
    catch
        _:_ ->
            false
    end.

%% @doc Return a list of all valid chess board cell coordinates.
-spec all_cells() -> [coord()].
all_cells() ->
    [{C, R} || C <- lists:seq(1, 8), R <- lists:seq(1, 8)].

%% @doc Make the next ply according to *ALL* chess rules.
-spec move_safe(Board :: board(), SrcCoord :: coord(), DstCoord :: coord(),
                Tail :: string(), History :: echessd_game:history()) ->
                       {ok, NewBoard :: board(),
                        Capture :: echessd_game:entry()}.
move_safe(Board, SrcCoord, DstCoord, Tail, History) ->
    {Color, ChessmanType} = getcell(Board, SrcCoord),
    {NewBoard, Capture} = move_unsafe(Board, SrcCoord, DstCoord, Tail),
    KingCoord =
        if ChessmanType == ?king ->
                DstCoord;
           true ->
                whereis_the_king(History, Color)
        end,
    false = is_cell_attacked(NewBoard, KingCoord, not_color(Color)),
    {ok, NewBoard, Capture}.

%% @doc Return a list of possible moves from the cell.
%% The result is not been checked to avoid new or existing checks.
-spec hint_for_cell_unsafe(Board :: board(), CellCoord :: coord(),
                           History :: echessd_game:history()) ->
                                  [coord()].
hint_for_cell_unsafe(Board, CellCoord, History) ->
    case getcell(Board, CellCoord) of
        {Color, ChessmanType} ->
            lists:usort(
              lists:flatten(
                hint_for_chessman_type(
                  Board, CellCoord, Color, ChessmanType, History)))
                -- [?null];
        ?empty ->
            []
    end.

-type coord_deep_list() :: [coord() | ?null | coord_deep_list()].

%% @doc
-spec hint_for_chessman_type(
        Board :: board(), Coord :: coord(),
        Color :: echessd_game:color(),
        ChessmanType :: echessd_game:chessman_type(),
        History :: echessd_game:history()) -> coord_deep_list().
hint_for_chessman_type(Board, Coord, Color, ?pawn, History) ->
    {StartRow, Direction} =
        if Color == ?white -> {2, 1};
           true -> {7, -1}
        end,
    EnemyPawn = {not_color(Color), ?pawn},
    [case getcell(Board, F1 = ind_inc(Coord, {0, Direction})) of
         ?empty ->
             [F1,
              case Coord of
                  {_, StartRow} ->
                      case getcell(Board, F2 = ind_inc(Coord, {0, Direction * 2})) of
                          ?empty -> F2;
                          _ -> []
                      end;
                  _ -> []
              end];
         _ -> []
     end,
     case getcell(Board, FL = ind_inc(Coord, {-1, Direction})) of
         {Color, _} -> [];
         {_, _} -> FL;
         _ -> []
     end,
     case getcell(Board, FR = ind_inc(Coord, {1, Direction})) of
         {Color, _} -> [];
         {_, _} -> FR;
         _ -> []
     end,
     case getcell(Board, EnPassL = ind_inc(Coord, {-1, 0})) of
         EnemyPawn ->
             case is_en_passant(History, EnPassL) of
                 true ->
                     ind_inc(Coord, {-1, Direction});
                 _ -> []
             end;
         _ -> []
     end,
     case getcell(Board, EnPassR = ind_inc(Coord, {1, 0})) of
         EnemyPawn ->
             case is_en_passant(History, EnPassR) of
                 true ->
                     ind_inc(Coord, {1, Direction});
                 _ -> []
             end;
         _ -> []
     end];
hint_for_chessman_type(Board, Coord, Color, ?rook, _History) ->
    [free_cells_until_enemy(Board, Color, Coord, {0, 1}),
     free_cells_until_enemy(Board, Color, Coord, {0, -1}),
     free_cells_until_enemy(Board, Color, Coord, {1, 0}),
     free_cells_until_enemy(Board, Color, Coord, {-1, 0})];
hint_for_chessman_type(Board, Coord, Color, ?bishop, _History) ->
    [free_cells_until_enemy(Board, Color, Coord, {-1, -1}),
     free_cells_until_enemy(Board, Color, Coord, {1, -1}),
     free_cells_until_enemy(Board, Color, Coord, {-1, 1}),
     free_cells_until_enemy(Board, Color, Coord, {1, 1})];
hint_for_chessman_type(Board, Coord, Color, ?queen, History) ->
    [hint_for_chessman_type(Board, Coord, Color, ?bishop, History),
     hint_for_chessman_type(Board, Coord, Color, ?rook, History)];
hint_for_chessman_type(Board, Coord, Color, ?knight, _History) ->
    [is_empty_or_enemy(Board, Color, ind_inc(Coord, Delta)) ||
        Delta <- knight_deltas()];
hint_for_chessman_type(Board, Coord, Color, ?king, History) ->
    [is_empty_or_enemy(Board, Color, ind_inc(Coord, {-1, -1})),
     is_empty_or_enemy(Board, Color, ind_inc(Coord, {-1, 0})),
     is_empty_or_enemy(Board, Color, ind_inc(Coord, {-1, 1})),
     is_empty_or_enemy(Board, Color, ind_inc(Coord, {0, -1})),
     is_empty_or_enemy(Board, Color, ind_inc(Coord, {0, 1})),
     is_empty_or_enemy(Board, Color, ind_inc(Coord, {1, -1})),
     is_empty_or_enemy(Board, Color, ind_inc(Coord, {1, 0})),
     is_empty_or_enemy(Board, Color, ind_inc(Coord, {1, 1})),
     available_castlings(Board, Color, History)].

%% ----------------------------------------------------------------------
%% castlings

%% @doc
-spec available_castlings(Board :: board(),
                          Color :: echessd_game:color(),
                          History :: echessd_game:history()) ->
                                 [coord()].
available_castlings(Board, Color, History) ->
    KingStartCoord = king_start_coord(Color),
    case is_have_been_moved(History, KingStartCoord) orelse
        is_cell_attacked(Board, KingStartCoord, not_color(Color)) of
        true ->
            [];
        _ ->
            case long_castling(Board, Color, History) of
                ?null ->
                    [];
                LongCastlingCoord ->
                    [LongCastlingCoord]
            end ++
                case short_castling(Board, Color, History) of
                    ?null ->
                        [];
                    ShortCastlingCoord ->
                        [ShortCastlingCoord]
                end
    end.

%% @doc
-spec long_castling(Board :: board(),
                    Color :: echessd_game:color(),
                    History :: echessd_game:history()) ->
                           coord() | ?null.
long_castling(Board, Color, History) ->
    castling(Board, Color, History, long_rook_coord(Color), {-1, 0}).

%% @doc
-spec short_castling(Board :: board(),
                     Color :: echessd_game:color(),
                     History :: echessd_game:history()) ->
                            coord() | ?null.
short_castling(Board, Color, History) ->
    castling(Board, Color, History, short_rook_coord(Color), {1, 0}).

%% @doc
-spec castling(Board :: board(), Color :: echessd_game:color(),
               History :: echessd_game:history(),
               RookCoord :: coord(), Delta :: delta()) ->
                      coord() | ?null.
castling(Board, Color, History, RookCoord, Delta) ->
    case is_have_been_moved(History, RookCoord) of
        true ->
            ?null;
        _ ->
            KingStartCoord = king_start_coord(Color),
            EnemyColor = not_color(Color),
            KingStep1 = ind_inc(KingStartCoord, Delta),
            KingStep2 = ind_inc(KingStep1, Delta),
            case is_good_for_king(Board, KingStep1, EnemyColor)
                andalso is_good_for_king(Board, KingStep2, EnemyColor) of
                true ->
                    KingStep2;
                false ->
                    ?null
            end
    end.

%% @doc Check if cell is good for the king (not settled and not attacked
%% by the enemy.
-spec is_good_for_king(Board :: board(), Coord :: coord(),
                       EnemyColor :: echessd_game:color()) -> boolean().
is_good_for_king(Board, Coord, EnemyColor) ->
    is_empty(Board, Coord) andalso
        not is_cell_attacked(Board, Coord, EnemyColor).

%% @doc
-spec king_start_coord(Color :: echessd_game:color()) -> coord().
king_start_coord(?white) ->
    ind_dec("e1");
king_start_coord(?black) ->
    ind_dec("e8").

%% @doc
-spec long_rook_coord(Color :: echessd_game:color()) -> coord().
long_rook_coord(?white) ->
    ind_dec("a1");
long_rook_coord(?black) ->
    ind_dec("a8").

%% @doc
-spec short_rook_coord(Color :: echessd_game:color()) -> coord().
short_rook_coord(?white) ->
    ind_dec("h1");
short_rook_coord(?black) ->
    ind_dec("h8").

%% @doc
-spec is_have_been_moved(History :: echessd_game:history(),
                         Coord :: coord()) -> boolean().
is_have_been_moved(History, Coord) ->
    HalfPly = ind_enc(Coord),
    lists:any(
      fun({PlyCoords, _PlyInfo}) ->
              lists:prefix(HalfPly, PlyCoords)
      end, History).

%% @doc
-spec is_castling(SrcCoord :: coord(), DstCoord :: coord(),
                  SrcChessman :: echessd_game:chessman(),
                  DstChessman :: echessd_game:entry()) ->
                         {ok, RookPlyCoords :: echessd_game:ply_coords()} |
                         false.
is_castling({IC1, IR}, {IC2, IR}, {C, ?king}, ?empty)
  when abs(IC2 - IC1) == 2,
       ((C == ?black andalso IR == 8 andalso IC1 == 5)
        orelse (C == ?white andalso IR == 1 andalso IC1 == 5)) ->
    case {C, IC2 - IC1} of
        {?black, -2} ->
            {ok, "a8d8"};
        {?black, 2} ->
            {ok, "h8f8"};
        {?white, -2} ->
            {ok, "a1d1"};
        {?white, 2} ->
            {ok, "h1f1"}
    end;
is_castling(_, _, _, _) ->
    false.

%% ----------------------------------------------------------------------
%% chess notation

%% @doc Generate chess notation string for the ply.
-spec notation(Chessman :: echessd_game:chessman(),
               Ply :: echessd_game:ply(),
               Capture :: echessd_game:entry(), NewBoard :: board(),
               GameStatus :: echessd_game:status(),
               History :: echessd_game:history()) ->
                      ChessNotation :: nonempty_string().
notation(Chessman, Ply, Capture, NewBoard, GameStatus, History) ->
    {SrcCoord, DstCoord, _Tail} = ply_dec(Ply),
    {Color, ChessmanType} = Chessman,
    {PlyCoords, _PlyInfo} = Ply,
    lists:flatten(
      [case {Chessman, PlyCoords} of
           {?wking, "e1g1" ++ _} -> "0-0";
           {?wking, "e1c1" ++ _} -> "0-0-0";
           {?bking, "e8g8" ++ _} -> "0-0";
           {?bking, "e8c8" ++ _} -> "0-0-0";
           _ ->
               {_, NewChessmanType} = getcell(NewBoard, DstCoord),
               [chessman_type_to_notation(ChessmanType),
                ind_enc(SrcCoord),
                if_then_else(Capture == ?empty, "-", "x"),
                ind_enc(DstCoord),
                if ChessmanType == ?pawn andalso
                   NewChessmanType /= ?pawn ->
                        chessman_type_to_notation(NewChessmanType);
                   true -> ""
                end]
       end,
       case GameStatus of
           ?gs_alive ->
               EnemyColor = not_color(Color),
               EnemyKingCoord = whereis_the_king(History, EnemyColor),
               case cell_attackers_count(
                      NewBoard, EnemyKingCoord, Color) of
                   0 -> "";
                   1 -> "+";
                   2 -> "++"
               end;
           ?gs_checkmate ->
               "#";
           ?gs_draw_stalemate ->
               "="
       end]).

%% @doc Encode the chessman type to a string used by chess notation.
-spec chessman_type_to_notation(echessd_game:chessman_type()) ->
                                       string().
chessman_type_to_notation(?king) ->
    "K";
chessman_type_to_notation(?queen) ->
    "Q";
chessman_type_to_notation(?rook) ->
    "R";
chessman_type_to_notation(?knight) ->
    "N";
chessman_type_to_notation(?bishop) ->
    "B";
chessman_type_to_notation(?pawn) ->
    "".

%% ----------------------------------------------------------------------
%% en passant

%% @doc
-spec is_en_passant(History :: echessd_game:history(),
                    OpponentPawnCoord :: coord()) ->
                           boolean().
is_en_passant([_ | _] = History, {C2, R2} = OppPawnCoord) ->
    case ply_dec(lists:last(History)) of
        {{C2, R1}, OppPawnCoord, _PrevPlyCoordsTail}
          when abs(abs(R1) - abs(R2)) == 2 ->
            true;
        _ ->
            false
    end;
is_en_passant(_, _) ->
    false.

%% @doc
-spec is_en_passant_simple(Board :: board(),
                           SrcCoord :: coord(), DstCoord :: coord(),
                           SrcChessman :: echessd_game:entry(),
                           DstChessman :: echessd_game:entry()) ->
                                  {ok, EnemyPawnCoord :: coord(),
                                   EnemyPawn :: echessd_game:chessman()} |
                                  false.
is_en_passant_simple(Board, {IC1, IR1}, {IC2, _IR2},
                     {C, ?pawn}, ?empty) when abs(IC2 - IC1) == 1 ->
    EnemyPawnCoord = {IC2, IR1},
    EnemyPawn = {not_color(C), ?pawn},
    case getcell(Board, EnemyPawnCoord) == EnemyPawn of
        true ->
            {ok, EnemyPawnCoord, EnemyPawn};
        false ->
            false
    end;
is_en_passant_simple(_, _, _, _, _) ->
    false.

%% ----------------------------------------------------------------------
%% low level tools
%% ----------------------------------------------------------------------

%% @doc Check if the chessman must be promoted or not.
-spec is_promotion(Coord :: coord(), Chessman :: echessd_game:entry(),
                   PlyCoordsTail :: string()) ->
                          {ok, NewChessmanType :: echessd_game:chessman_type()} |
                          false.
is_promotion({_IC2, 1 = _IR2} = _I2, ?bpawn, PlyCoordsTail) ->
    {ok, promotion_dec(PlyCoordsTail)};
is_promotion({_IC2, 8 = _IR2} = _I2, ?wpawn, PlyCoordsTail) ->
    {ok, promotion_dec(PlyCoordsTail)};
is_promotion(_, _, _) ->
    false.

%% @doc Return the coordinates if the cell is empty or settled by
%% the enemy. In other cases return ?null.
-spec is_empty_or_enemy(Board :: board(), MyColor :: echessd_game:color(),
                        Coord :: coord()) ->
                               (Coord :: coord()) | ?null.
is_empty_or_enemy(Board, MyColor, Coord) ->
    case getcell(Board, Coord) of
        ?empty ->
            Coord;
        {EnemyColor, _} when EnemyColor /= MyColor ->
            Coord;
        _ ->
            ?null
    end.

%% @doc Check if cell is empty or not.
-spec is_empty(Board :: board(), Coord :: coord()) -> boolean().
is_empty(Board, Coord) ->
    getcell(Board, Coord) == ?empty.

%% @doc Search free cells in the given direction until enemy chessman
%% or board end found. When the enemy chessman found the enemy
%% coordinates will also be returned.
-spec free_cells_until_enemy(Board :: board(),
                             MyColor :: echessd_game:color(),
                             Start :: coord(),
                             Direction :: delta()) ->
                                    [FreeCell :: coord()].
free_cells_until_enemy(Board, MyColor, Start, Direction) ->
    case getcell(Board, NextCoord = ind_inc(Start, Direction)) of
        ?null ->
            [];
        ?empty ->
            [NextCoord |
             free_cells_until_enemy(Board, MyColor, NextCoord, Direction)];
        {MyColor, _} ->
            [];
        _ ->
            [NextCoord]
    end.

%% @doc Check if the cell is attacked by the enemy or not.
-spec is_cell_attacked(Board :: board(), CellCoord :: coord(),
                       EnemyColor :: echessd_game:color()) ->
                              boolean().
is_cell_attacked(Board, CellCoord, EnemyColor) ->
    cell_attackers_count(Board, CellCoord, EnemyColor) > 0.

%% @doc Return the number of enemy chessmen attacking the board cell.
%% The maximum value which can be returned is 2 for optimization
%% reasons.
-spec cell_attackers_count(Board :: board(), Coord :: coord(),
                           EnemyColor :: echessd_game:color()) -> 0..2.
cell_attackers_count(Board, Coord, EnemyColor) ->
    AttackingKnights = attacking_knights(Board, Coord, EnemyColor),
    SearchDirections =
        [{-1, -1}, {-1, 0}, {-1, 1}, {0, -1},
         {0, 1}, {1, -1}, {1, 0}, {1, 1}],
    cell_attackers_loop(
      Board, Coord, EnemyColor, SearchDirections, AttackingKnights).

%% @doc Helper for the cell_attackers_count/3 fun.
-spec cell_attackers_loop(Board :: board(), Coord :: coord(),
                          EnemyColor :: echessd_game:color(),
                          SearchDirections :: [delta()],
                          Found :: non_neg_integer()) ->
                                 0..2.
cell_attackers_loop(_Board, _Coord, _EnemyColor, _SearchDirections, Found)
  when Found >= 2 ->
    2;
cell_attackers_loop(_Board, _Coord, _EnemyColor, [], Found) ->
    Found;
cell_attackers_loop(Board, Coord, EnemyColor, [SearchDirection | Tail],
                    Found) ->
    {DC, DR} = SearchDirection,
    case find_enemy(Board, Coord, SearchDirection, EnemyColor) of
        {?pawn, 1} when EnemyColor == ?black, abs(DC) == 1, DR == 1 ->
            cell_attackers_loop(Board, Coord, EnemyColor, Tail, Found + 1);
        {?pawn, 1} when EnemyColor == ?white, abs(DC) == 1, DR == -1 ->
            cell_attackers_loop(Board, Coord, EnemyColor, Tail, Found + 1);
        {?king, 1} ->
            cell_attackers_loop(Board, Coord, EnemyColor, Tail, Found + 1);
        {?queen, _} ->
            cell_attackers_loop(Board, Coord, EnemyColor, Tail, Found + 1);
        {?bishop, _} when abs(DC) == abs(DR) ->
            cell_attackers_loop(Board, Coord, EnemyColor, Tail, Found + 1);
        {?rook, _} when abs(DC) /= abs(DR) ->
            cell_attackers_loop(Board, Coord, EnemyColor, Tail, Found + 1);
        _ ->
            cell_attackers_loop(Board, Coord, EnemyColor, Tail, Found)
    end.

%% @doc Return the number of enemy knights attacking the board cell.
%% The maximum value which can be returned is 2 for optimization
%% reasons.
-spec attacking_knights(Board :: board(), Coord :: coord(),
                        EnemyColor :: echessd_game:color()) -> 0..2.
attacking_knights(Board, Coord, EnemyColor) ->
    attacking_knights_loop(
      Board, Coord, knight_deltas(), EnemyColor, _Found = 0).

%% @doc Return a list of available Knight moves.
-spec knight_deltas() -> [delta()].
knight_deltas() ->
    [{1, 2}, {-1, 2}, {1, -2}, {-1, -2},
     {2, 1}, {-2, 1}, {2, -1}, {-2, -1}].

%% @doc Helper for the attacking_knights/3 fun.
-spec attacking_knights_loop(Board :: board(), Coord :: coord(),
                             KnightDeltas :: [delta()],
                             EnemyColor :: echessd_game:color(),
                             Found :: 0..2) -> 0..2.
attacking_knights_loop(_Board, _Coord, [], _EnemyColor, Found) ->
    Found;
attacking_knights_loop(Board, Coord, [Delta | Tail], EnemyColor, Found) ->
    case getcell(Board, ind_inc(Coord, Delta)) of
        {EnemyColor, ?knight} when Found >= 1 ->
            2;
        {EnemyColor, ?knight} ->
            attacking_knights_loop(Board, Coord, Tail, EnemyColor, Found + 1);
        _ ->
            attacking_knights_loop(Board, Coord, Tail, EnemyColor, Found)
    end.

%% @doc Search the enemy chessman starting from the coordinates
%% with the direction.
-spec find_enemy(Board :: board(), Coord :: coord(), Delta :: delta(),
                 EnemyColor :: echessd_game:color()) ->
                        {EnemyChessmanType :: echessd_game:chessman_type(),
                         Distance :: pos_integer()} |
                        undefined.
find_enemy(Board, Coord, Delta, EnemyColor) ->
    find_enemy(Board, Coord, Delta, EnemyColor, _Distance = 1).

%% @doc Helper for the find_enemy/4 fun.
-spec find_enemy(Board :: board(), Coord :: coord(), Direction :: delta(),
                 EnemyColor :: echessd_game:color(),
                 Distance :: pos_integer()) ->
                        {EnemyChessmanType :: echessd_game:chessman_type(),
                         Distance :: pos_integer()} |
                        undefined.
find_enemy(Board, Coord, Direction, EnemyColor, Distance) ->
    NextCoord = ind_inc(Coord, Direction),
    case getcell(Board, NextCoord) of
        {EnemyColor, ChessmanType} ->
            {ChessmanType, Distance};
        ?empty ->
            find_enemy(Board, NextCoord, Direction, EnemyColor, Distance + 1);
        _ ->
            %% board end reached or
            %% friendly chessman found
            undefined
    end.

%% @doc Return the king location.
-spec whereis_the_king(History :: echessd_game:history(),
                       Color :: echessd_game:color()) ->
                              Coord :: coord().
whereis_the_king(History, Color) ->
    whereis_the_king_(History, king_start_coord(Color)).

%% @doc Helper for the whereis_the_king/2 fun.
-spec whereis_the_king_(History :: echessd_game:history(),
                        KingCoord :: coord()) ->
                               FinalKingCoord :: coord().
whereis_the_king_([], Coord) ->
    Coord;
whereis_the_king_([Ply | Tail], Coord) ->
    case ply_dec(Ply) of
        {Coord, NewCoord, _Tail} ->
            whereis_the_king_(Tail, NewCoord);
        {_SrcCoord, _DstCoord, _Tail} ->
            whereis_the_king_(Tail, Coord)
    end.

%% @doc Return the contents of the board cell.
-spec getcell(Board :: board(), Coord :: coord()) ->
                  (Entry :: echessd_game:entry()) | ?null.
getcell(Board, {C, R})
  when R >= 1 andalso R =< 8 andalso
       C >= 1 andalso C =< 8 ->
    element(C, element(9 - R, Board));
getcell(_, _) ->
    ?null.

%% @doc Settle the board cell with the chessman (or clear the
%% board cell if NewEntry is set to ?empty).
-spec setcell(Board :: board(), Coord :: coord(),
              NewEntry :: echessd_game:entry()) ->
                     NewBoard :: board().
setcell(Board, {C, R}, NewEntry) ->
    Row = element(9 - R, Board),
    NewRow = setelement(C, Row, NewEntry),
    setelement(9 - R, Board, NewRow).

%% @doc Decode ply structure to the numeric coordinates of
%% the start cell, the destination cell and extra string which
%% will be used on pawn promotion.
-spec ply_dec(Ply :: echessd_game:ply()) ->
                     {SrcCoord :: coord(), DstCoord :: coord(),
                      PlyCoordsTail :: string()}.
ply_dec({[A, B, C, D | PlyCoordsTail], _PlyInfo})
  when is_integer(A), is_integer(B), is_integer(C), is_integer(D) ->
    {{_, _} = ind_dec(A, B), {_, _} = ind_dec(C, D), PlyCoordsTail}.

%% @doc Decode human readable cell coordinates to numeric,
%% e.g. "a1" -> {1,1}; "h8" -> {8,8}.
-spec ind_dec(HalfPly :: nonempty_string()) -> Coord :: coord().
ind_dec([C, R]) ->
    ind_dec(C, R).

%% @doc Helper for the ind_dec/1 fun.
-spec ind_dec(BoardLetter :: 97..104, %% $a..$h
              BoardNumber :: 49..56   %% $1..$8
                             ) -> (Coord :: coord()) | ?null.
ind_dec(C, R) ->
    Crd = {C - $a + 1, R - $1 + 1},
    case ind_ok(Crd) of
        true ->
            Crd;
        _ ->
            ?null
    end.

%% @doc Encode the cell coordinates to human-readable form,
%% e.g. {1,1} -> "a1"; {8,8} -> "h8"
-spec ind_enc(Coord :: coord()) -> HalfPly :: nonempty_string().
ind_enc({C, R}) ->
    [$a + C - 1, $1 + R - 1].

%% @doc Increment the cell coordinates with the Delta.
%% The function return new coordinates or ?null if result
%% is out of valid coordinates range (out of the chess board).
-spec ind_inc(Coord :: coord(), Delta :: delta()) ->
                     (NewCoord :: coord()) | ?null.
ind_inc({C, R}, {CS, RS}) ->
    Crd = {C + CS, R + RS},
    case ind_ok(Crd) of
        true ->
            Crd;
        _ ->
            ?null
    end.

%% @doc Check if the numeric coordinates is valid chess
%% board coordinates or not.
-spec ind_ok(coord() | any()) -> boolean().
ind_ok({C, R})
  when C >= 1 andalso C =< 8 andalso
       R >= 1 andalso R =< 8 ->
    true;
ind_ok(_) ->
    false.

%% @doc Invert the player color.
-spec not_color(MyColor :: echessd_game:color()) ->
                       OpponentColor :: echessd_game:color().
not_color(MyColor) ->
    hd([?white, ?black] -- [MyColor]).

%% @doc Decode extra string from the ply structure to
%% chessman type. The function used on a pawn promotion.
-spec promotion_dec(PlyTail :: string()) -> promotion_chessman_type().
promotion_dec([$r | _]) -> ?rook;
promotion_dec([$k | _]) -> ?knight;
promotion_dec([$s | _]) -> ?knight;
promotion_dec([$h | _]) -> ?knight;
promotion_dec([$b | _]) -> ?bishop;
promotion_dec([$q | _]) -> ?queen;
promotion_dec([]) -> ?queen.

%% @doc Syntax sugar like (expr)?true:false.
-spec if_then_else(Expression :: boolean(),
                   OnTrue :: any(), OnFalse :: any()) -> any().
if_then_else(true, OnTrue, _OnFalse) ->
    OnTrue;
if_then_else(false, _OnTrue, OnFalse) ->
    OnFalse.
