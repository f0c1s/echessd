%%%-------------------------------------------------------------------
%%% File    : echessd_rules_classic.erl
%%% Author  : Aleksey Morarash <aleksey.morarash@gmail.com>
%%% Created : 22 Jan 2012
%%% License : FreeBSD
%%% Description : Classic chess rules implementation
%%%
%%%-------------------------------------------------------------------

-module(echessd_rules_classic).

-export([new/0,
         is_valid_ply/4,
         move_chessman/2,
         transpose/1
        ]).

-include("echessd.hrl").

%% ----------------------------------------------------------------------
%% API functions
%% ----------------------------------------------------------------------

%% @doc Creates chess board with all chessmans at start point.
%% @spec new() -> echessd_game:echessd_board()
new() ->
    {{?brook,?bknight,?bbishop,?bqueen,?bking,?bbishop,?bknight,?brook}, %% 8
     {?bpawn,?bpawn,?bpawn,?bpawn,?bpawn,?bpawn,?bpawn,?bpawn}, %% 7
     {?empty,?empty,?empty,?empty,?empty,?empty,?empty,?empty}, %% 6
     {?empty,?empty,?empty,?empty,?empty,?empty,?empty,?empty}, %% 5
     {?empty,?empty,?empty,?empty,?empty,?empty,?empty,?empty}, %% 4
     {?empty,?empty,?empty,?empty,?empty,?empty,?empty,?empty}, %% 3
     {?wpawn,?wpawn,?wpawn,?wpawn,?wpawn,?wpawn,?wpawn,?wpawn}, %% 2
     {?wrook,?wknight,?wbishop,?wqueen,?wking,?wbishop,?wknight,?wrook}  %% 1
     %% a,b,c,d,e,f,g,h
    }.

%% @doc Checks if ply is valid.
%% @spec is_valid_ply(Board, TurnColor, Ply, History) ->
%%                 ok | {error, Reason}
%%     Board = echessd_game:echessd_board(),
%%     TurnColor = echessd_game:echessd_color(),
%%     Ply = echessd_game:echessd_ply(),
%%     History = echessd_game:echessd_history(),
%%     Reason = term()
is_valid_ply(Board, TurnColor, Ply, History) ->
    try is_valid_ply_(Board, TurnColor, Ply, History) of
        ok -> ok;
        {error, _} = Error -> Error;
        Other -> {error, Other}
    catch
        _:{error, _} = ExcError -> ExcError;
        Type:Reason ->
            {error, {Type, Reason, erlang:get_stacktrace()}}
    end.

%% @doc Make chessman move.
%% @spec move_chessman(Board, Ply) -> {NewBoard, Capture}
%%     Board = NewBoard = echessd_game:echessd_board(),
%%     Ply = echessd_game:echessd_ply(),
%%     Capture = echessd_game:echessd_chessman()
move_chessman(Board, Ply) ->
    {I1, I2, Tail} = ply_dec(Ply),
    move_chessman(Board, I1, I2, Tail).
move_chessman(Board, I1, I2, Tail) ->
    F1 = cell(Board, I1),
    F2 = cell(Board, I2),
    case is_en_passant_simple(Board, I1, I2, F1, F2) of
        {ok, EnemyPawnIndex, EnemyPawn} ->
            Board2 = setcell(Board, EnemyPawnIndex, ?empty),
            {Board3, ?empty} =
                move_chessman_normal(Board2, I1, I2, F1, F2),
            {Board3, EnemyPawn};
        _ ->
            case is_promotion(I2, F1, Tail) of
                {ok, ChessmanType} ->
                    {Color, _} = F1,
                    move_chessman_normal(
                      Board, I1, I2,
                      {Color, ChessmanType}, ?empty);
                _ ->
                    case is_castling(I1, I2, F1, F2) of
                        {ok, RookPly} ->
                            {Board2, _} =
                                move_chessman_normal(
                                  Board, I1, I2, F1, F2),
                            move_chessman(Board2, RookPly);
                        _ ->
                            move_chessman_normal(
                              Board, I1, I2, F1, F2)
                    end
            end
    end.
move_chessman_normal(Board, I1, I2, F1, F2) ->
    {setcell(setcell(Board, I1, ?empty), I2, F1), F2}.

%% @doc Turns internal board representation at 180 degrees.
%% @spec transpose(Board) -> NewBoard
%%     GameType = echessd_game:echessd_game_type(),
%%     Board = NewBoard = echessd_game:echessd_board()
transpose(Board) ->
    list_to_tuple(
      lists:reverse(
        [list_to_tuple(
           lists:reverse(
             tuple_to_list(R))) ||
            R <- tuple_to_list(Board)])).

%% ----------------------------------------------------------------------
%% Internal functions
%% ----------------------------------------------------------------------

-define(null, '*null').

is_valid_ply_(Board, TurnColor, Ply, History) ->
    {I1, I2, Tail} = ply_dec(Ply),
    {MyColor, ChessmanType} =
        case cell(Board, I1) of
            ?empty -> throw({error, {cell_is_empty, I1}});
            {TurnColor, _} = Chessman0 -> Chessman0;
            {_, _} -> throw({error, not_your_chessman})
        end,
    case cell(Board, I2) of
        {TurnColor, _} -> throw({error, friendly_fire});
        {_, ?king} -> throw({error, cannot_take_king});
        _ -> ok
    end,
    Possible = possible(Board, I1, MyColor, ChessmanType, History),
    case lists:member(I2, Possible) of
        true ->
            {Board2, _Capture} = move_chessman(Board, I1, I2, Tail),
            MyKingIndex =
                if ChessmanType == ?king -> I2;
                   true ->
                        whereis_my_king(History, MyColor)
                end,
            case is_cell_under_attack(
                   Board2, MyKingIndex, MyColor) of
                true ->
                    throw({error, check});
                _ -> ok
            end;
        _ ->
            throw({error, badmove})
    end.

possible(B, I, C, ChessmanType, History) ->
    lists:usort(
      lists:flatten(
        possible_(B, I, C, ChessmanType, History))) -- [?null].
possible_(B, I, C, ?pawn, History) ->
    {StartRow, Direction} =
        if C == ?white -> {2, 1};
           true -> {7, -1}
        end,
    F1 = ind_inc(I, {0, Direction}),
    F2 = ind_inc(I, {0, Direction * 2}),
    FL = ind_inc(I, {-1, Direction}),
    FR = ind_inc(I, {1, Direction}),
    EnPassL = ind_inc(I, {-1, 0}),
    EnPassR = ind_inc(I, {1, 0}),
    OppPawn = {not_color(C), ?pawn},
    case cell(B, F1) of
        ?empty ->
            [F1] ++
                case ind_row(I) of
                    StartRow ->
                        case cell(B, F2) of
                            ?empty -> [F2];
                            _ -> []
                        end;
                    _ -> []
                end;
        _ -> []
    end ++
        case cell(B, FL) of
            {_, _} -> [FL];
            _ -> []
        end ++
        case cell(B, FR) of
            {_, _} -> [FR];
            _ -> []
        end ++
        case cell(B, EnPassL) of
            OppPawn ->
                case is_en_passant(History, EnPassL) of
                    true ->
                        [ind_inc(I, {-1, Direction})];
                    _ -> []
                end;
            _ -> []
        end ++
        case cell(B, EnPassR) of
            OppPawn ->
                case is_en_passant(History, EnPassR) of
                    true ->
                        [ind_inc(I, {1, Direction})];
                    _ -> []
                end;
            _ -> []
        end;
possible_(B, I, C, ?rook, _History) ->
    [free_cells_until_enemy(B, C, I, {0, 1}),
     free_cells_until_enemy(B, C, I, {0, -1}),
     free_cells_until_enemy(B, C, I, {1, 0}),
     free_cells_until_enemy(B, C, I, {-1, 0})];
possible_(B, I, C, ?bishop, _History) ->
    [free_cells_until_enemy(B, C, I, {-1, -1}),
     free_cells_until_enemy(B, C, I, {1, -1}),
     free_cells_until_enemy(B, C, I, {-1, 1}),
     free_cells_until_enemy(B, C, I, {1, 1})];
possible_(B, I, C, ?queen, History) ->
    [possible_(B, I, C, ?bishop, History),
     possible_(B, I, C, ?rook, History)];
possible_(B, I, C, ?knight, _History) ->
    [is_empty_or_enemy(B, C, ind_inc(I, Step)) ||
        Step <- knight_steps()];
possible_(B, I, C, ?king, History) ->
    [is_empty_or_enemy(B, C, ind_inc(I, {-1, -1})),
     is_empty_or_enemy(B, C, ind_inc(I, {-1, 0})),
     is_empty_or_enemy(B, C, ind_inc(I, {-1, 1})),
     is_empty_or_enemy(B, C, ind_inc(I, {0, -1})),
     is_empty_or_enemy(B, C, ind_inc(I, {0, 1})),
     is_empty_or_enemy(B, C, ind_inc(I, {1, -1})),
     is_empty_or_enemy(B, C, ind_inc(I, {1, 0})),
     is_empty_or_enemy(B, C, ind_inc(I, {1, 1}))] ++
        possible_castlings(B, C, History);
possible_(_, _, _, _, _) -> [].

possible_castlings(Board, Color, History) ->
    case is_king_have_been_moved(History, Color) of
        true -> [];
        _ ->
            KingStart =
                ind_dec(
                  if Color == ?white -> "e1";
                     true -> "e8"
                  end),
            PossibleCastlings =
                %% castling long
                case search_rook(Board, KingStart, {-1, 0}, Color) of
                    {1, _} = LongRookC ->
                        case is_rook_have_been_moved(
                               History, LongRookC) of
                            true -> [];
                            _ ->
                                case is_cell_under_attack(
                                       Board, ind_inc(KingStart, {-1, 0}),
                                       Color) of
                                    true -> [];
                                    _ ->
                                        [ind_inc(KingStart, {-2, 0})]
                                end
                        end;
                    _ -> []
                end ++
                %% castling short
                case search_rook(Board, KingStart, {1, 0}, Color) of
                    {8, _} = ShortRookC ->
                        case is_rook_have_been_moved(
                               History, ShortRookC) of
                            true -> [];
                            _ ->
                                case is_cell_under_attack(
                                       Board, ind_inc(KingStart, {1, 0}),
                                       Color) of
                                    true -> [];
                                    _ ->
                                        [ind_inc(KingStart, {2, 0})]
                                end
                        end;
                    _ -> []
                end,
            case PossibleCastlings of
                [_ | _] ->
                    %% is there is check?
                    case is_cell_under_attack(
                           Board, KingStart, Color) of
                        true -> [];
                        _ -> PossibleCastlings
                    end;
                _ -> []
            end
    end.

search_rook(Board, I, Step, Color) ->
    I2 = ind_inc(I, Step),
    case cell(Board, I2) of
        {Color, ?rook} -> I2;
        ?empty -> search_rook(Board, I2, Step, Color);
        _ -> ?null
    end.

%% ----------------------------------------------------------------------
%% low level tools
%% ----------------------------------------------------------------------

is_en_passant([_ | _] = History, {C2, R2} = OppPawnCoord) ->
    [A, B, C, D | _] = lists:last(History),
    case ind_dec(C, D) of
        OppPawnCoord ->
            case ind_dec(A, B) of
                {C2, R1} when abs(abs(R1) - abs(R2)) == 2 ->
                    true;
                _ -> false
            end;
        _ -> false
    end;
is_en_passant(_, _) -> false.

is_en_passant_simple(
  Board, {IC1, IR1} = _I1, {IC2, _IR2} = _I2,
  {C, ?pawn} = _SrcChm, ?empty = _DstChm)
  when abs(IC2 - IC1) == 1 ->
    EnemyPawnIndex = {IC2, IR1},
    EnemyPawn = {not_color(C), ?pawn},
    case cell(Board, EnemyPawnIndex) == EnemyPawn of
        true ->
            {ok, EnemyPawnIndex, EnemyPawn};
        _ -> false
    end;
is_en_passant_simple(_, _, _, _, _) -> false.

is_promotion({_IC2, 1 = _IR2} = _I2, ?bpawn = _SrcChm, PlyTail) ->
    {ok, promotion_dec(PlyTail)};
is_promotion({_IC2, 8 = _IR2} = _I2, ?wpawn = _SrcChm, PlyTail) ->
    {ok, promotion_dec(PlyTail)};
is_promotion(_, _, _) -> false.

is_castling(
  {IC1, IR} = _I1, {IC2, IR} = _I2,
  {C, ?king} = _SrcChm, ?empty = _DstChm)
  when abs(IC2 - IC1) == 2
       andalso
       ((C == ?black andalso IR == 8 andalso IC1 == 5)
        orelse
          (C == ?white andalso IR == 1 andalso IC1 == 5)) ->
    case {C, IC2 - IC1} of
        {?black, -2} -> {ok, "a8d8"};
        {?black, 2}  -> {ok, "h8f8"};
        {?white, -2} -> {ok, "a1d1"};
        {?white, 2}  -> {ok, "h1f1"}
    end;
is_castling(_, _, _, _) -> false.

is_empty_or_enemy(Board, MyColor, Coord) ->
    case cell(Board, Coord) of
        ?empty -> Coord;
        {Color, _} when Color /= MyColor -> Coord;
        _ -> ?null
    end.

free_cells_until_enemy(Board, MyColor, Start, Step) ->
    case ind_inc(Start, Step) of
        ?null -> [];
        Crd ->
            case cell(Board, Crd) of
                ?empty ->
                    [Crd |
                     free_cells_until_enemy(
                       Board, MyColor, Crd, Step)];
                {MyColor, _} -> [];
                _ -> [Crd]
            end
    end.

knight_steps() ->
    [{1, 2}, {-1, 2}, {1, -2}, {-1, -2},
     {2, 1}, {-2, 1}, {2, -1}, {-2, -1}].

is_cell_under_attack(Board, I, Color) ->
    EnemyColor = not_color(Color),
    lists:any(
      fun(Step) ->
              case cell(Board, ind_inc(I, Step)) of
                  {EnemyColor, ?knight} -> true;
                  _ -> false
              end
      end, knight_steps())
        orelse
        lists:any(
          fun({DC, DR} = Step) ->
                  case find_enemy(
                         Board, I, Step, EnemyColor) of
                      {?pawn, 1}
                        when EnemyColor == ?black
                             andalso abs(DC) == 1
                             andalso DR == 1 ->
                          true;
                      {?pawn, 1}
                        when EnemyColor == ?white
                             andalso abs(DC) == 1
                             andalso DR == -1 ->
                          true;
                      {?king, 1} ->
                          true;
                      {?queen, _} ->
                          true;
                      {?bishop, _}
                        when abs(DC) == abs(DR) ->
                          true;
                      {?rook, _}
                        when abs(DC) /= abs(DR) ->
                          true;
                      _ -> false
                  end
          end,
          [{-1, -1}, {-1, 0}, {-1, 1}, {0, -1},
           {0, 1}, {1, -1}, {1, 0}, {1, 1}]).

find_enemy(Board, I, Step, EnemyColor) ->
    find_enemy(Board, I, Step, EnemyColor, 1).
find_enemy(Board, I, Step, EnemyColor, Distance) ->
    I2 = ind_inc(I, Step),
    case cell(Board, I2) of
        {EnemyColor, ChessmanType} ->
            {ChessmanType, Distance};
        ?empty ->
            find_enemy(
              Board, I2, Step,
              EnemyColor, Distance + 1);
        _ ->
            %% board end reached or
            %% friendly chessman found
            undefined
    end.

is_king_have_been_moved(History, ?white) ->
    lists:any(fun(Ply) -> lists:prefix("e1", Ply) end, History);
is_king_have_been_moved(History, ?black) ->
    lists:any(fun(Ply) -> lists:prefix("e8", Ply) end, History).

is_rook_have_been_moved(History, C) ->
    lists:any(fun(Ply) -> lists:prefix(ind_enc(C), Ply) end, History).

whereis_my_king(History, ?white) ->
    whereis_my_king(History, "e1");
whereis_my_king(History, ?black) ->
    whereis_my_king(History, "e8");
whereis_my_king([[A, B, C, D | _] | Tail], [A, B]) ->
    whereis_my_king(Tail, [C, D]);
whereis_my_king([_ | Tail], Pos) ->
    whereis_my_king(Tail, Pos);
whereis_my_king(_, [A, B]) ->
    ind_dec(A, B).

cell(Board, {C, R})
  when R >= 1 andalso R =< 8 andalso
       C >= 1 andalso C =< 8 ->
    element(C, element(9 - R, Board));
cell(_, _) -> ?null.

setcell(Board, {C, R}, Chessman) ->
    Row = element(9 - R, Board),
    NewRow = setelement(C, Row, Chessman),
    setelement(9 - R, Board, NewRow).

ply_dec([A, B, C, D | Tail])
  when is_integer(A), is_integer(B),
       is_integer(C), is_integer(D) ->
    case {ind_dec(A, B), ind_dec(C, D)} of
        {{_,_} = C1, {_,_} = C2} ->
            {C1, C2, Tail};
        _ ->
            throw({error, badmove})
    end;
ply_dec(_) ->
    throw({error, badmove}).

ind_dec([C, R]) ->
    ind_dec(C, R).
ind_dec(C, R) ->
    Crd = {C - $a + 1, R - $1 + 1},
    case ind_ok(Crd) of
        true -> Crd;
        _ -> ?null
    end.

ind_enc({C, R}) ->
    [$a + C - 1, $1 + R - 1].

ind_inc({C, R}, {CS, RS}) ->
    Crd = {C + CS, R + RS},
    case ind_ok(Crd) of
        true -> Crd;
        _ -> ?null
    end.

ind_row({_, R}) -> R.

ind_ok({C, R})
  when C >= 1 andalso C =< 8 andalso
       R >= 1 andalso R =< 8 ->
    true;
ind_ok(_) -> false.

not_color(Color) ->
    hd([?white, ?black] -- [Color]).

promotion_dec([$r | _]) -> ?rook;
promotion_dec([$k | _]) -> ?knight;
promotion_dec([$s | _]) -> ?knight;
promotion_dec([$h | _]) -> ?knight;
promotion_dec([$b | _]) -> ?bishop;
promotion_dec([$q | _]) -> ?queen;
promotion_dec([_ | _] = Str) ->
    throw({error, {bad_promotion_type, Str}});
promotion_dec(_) ->
    throw({error, no_promotion_type_specified}).
