% 动态谓词声明，用于维护状态
:- dynamic see_key/0.
:- dynamic has_key/0.
:- dynamic see_door/0.
:- dynamic open_door/0.
:- dynamic see_final/0.
:- dynamic act_queue/1.
:- dynamic constant/0.

% 对象类型定义
object(empty, 0).
object(wall, 1).
object(floor, 2).
object(door, 3).
object(key, 4).
object(player, 5).
object(final, 6).

% 动作定义
action(north, 0).
action(east, 1).
action(south, 2).
action(west, 3).
action(pickup, 8).
action(apply, 9).
action(open, 10).

% 方向向量
direction(north, -1, 0).
direction(east, 0, 1).
direction(south, 1, 0).
direction(west, 0, -1).

% 主入口函数
process_observation(Obs, Action) :-
    update_state(Obs),
    decide_action(Obs, Action).

% 更新状态
update_state(Obs) :-
    check_key(Obs),
    check_door(Obs),
    check_final(Obs).

% 检查是否看到钥匙
check_key(Obs) :-
    (contains_object(Obs, 4) -> 
        (not(see_key) -> assertz(see_key) ; true)
    ; true).

% 检查是否看到门
check_door(Obs) :-
    (contains_object(Obs, 3) ->
        (not(see_door) -> assertz(see_door) ; true)
    ; true).

% 检查是否看到终点
check_final(Obs) :-
    (contains_object(Obs, 6) ->
        (not(see_final) -> assertz(see_final) ; true)
    ; true).

% 检查观察中是否包含特定对象
contains_object(Obs, Target) :-
    member(Row, Obs),
    member(Target, Row).

% 决策逻辑
decide_action(Obs, Action) :-
    % 如果有动作队列且是不可打断的，执行队列动作
    (constant, act_queue([H|T]) ->
        retract(act_queue([H|T])),
        (T = [] -> retract(constant) ; assertz(act_queue(T))),
        Action = H
    ;
    % 如果队列为空，解除不可打断状态
    (act_queue([]) -> (constant -> retract(constant) ; true) ; true),
    
    % 主决策逻辑
    (not(see_key) ->
        % 没看到钥匙，探索
        bfs(Obs, 0, Path),
        path_to_actions(Path, Actions),
        clear_queue,
        assertz(act_queue(Actions)),
        act_queue([Action|Rest]),
        retract(act_queue([Action|Rest])),
        (Rest = [] -> true ; assertz(act_queue(Rest)))
    ; not(has_key) ->
        % 看到钥匙但没有，去拿
        bfs(Obs, 4, Path),
        path_to_actions(Path, Actions),
        append(Actions, [8], ActionsWithPickup), % 8是pickup
        clear_queue,
        assertz(act_queue(ActionsWithPickup)),
        assertz(has_key),
        assertz(constant),
        act_queue([Action|Rest]),
        retract(act_queue([Action|Rest])),
        assertz(act_queue(Rest))
    ; not(see_door) ->
        % 有钥匙但没看到门，探索
        bfs(Obs, 0, Path),
        path_to_actions(Path, Actions),
        clear_queue,
        assertz(act_queue(Actions)),
        act_queue([Action|Rest]),
        retract(act_queue([Action|Rest])),
        (Rest = [] -> true ; assertz(act_queue(Rest)))
    ; not(open_door) ->
        % 看到门但没开
        (boy_next_door(Obs) ->
            % 在门旁边，直接开门
            clear_queue,
            assertz(act_queue([9, 10])), % apply和open
            assertz(open_door),
            assertz(constant),
            act_queue([Action|Rest]),
            retract(act_queue([Action|Rest])),
            assertz(act_queue(Rest))
        ;
            % 不在门旁边，走到门旁
            bfs(Obs, 3, Path),
            path_to_actions(Path, Actions),
            clear_queue,
            assertz(act_queue(Actions)),
            act_queue([Action|Rest]),
            retract(act_queue([Action|Rest])),
            (Rest = [] -> true ; assertz(act_queue(Rest)))
        )
    ; not(see_final) ->
        % 开了门但没看到终点，探索
        bfs(Obs, 0, Path),
        path_to_actions(Path, Actions),
        clear_queue,
        assertz(act_queue(Actions)),
        act_queue([Action|Rest]),
        retract(act_queue([Action|Rest])),
        (Rest = [] -> true ; assertz(act_queue(Rest)))
    ;
        % 看到终点，走过去
        bfs(Obs, 6, Path),
        path_to_actions(Path, Actions),
        clear_queue,
        assertz(act_queue(Actions)),
        assertz(constant),
        act_queue([Action|Rest]),
        retract(act_queue([Action|Rest])),
        (Rest = [] -> true ; assertz(act_queue(Rest)))
    )).

% 清空动作队列
clear_queue :-
    retractall(act_queue(_)).

% 定位对象
locate(Obs, Target, Row, Col) :-
    nth0(Row, Obs, RowList),
    nth0(Col, RowList, Target).

% BFS搜索
bfs(Obs, Target, Path) :-
    locate(Obs, 5, StartRow, StartCol), % 5是玩家
    bfs_search(Obs, Target, [(StartRow, StartCol)], [], [], Path).

% BFS搜索实现
bfs_search(Obs, Target, [(Row, Col)|_], _, Parent, Path) :-
    get_cell(Obs, Row, Col, Target), !,
    reconstruct_path((Row, Col), Parent, Path).

bfs_search(Obs, Target, [(Row, Col)|Rest], Visited, Parent, Path) :-
    findall((NewRow, NewCol),
        (direction(_, DR, DC),
         NewRow is Row + DR,
         NewCol is Col + DC,
         valid_move(Obs, NewRow, NewCol),
         not(member((NewRow, NewCol), Visited))),
        Neighbors),
    append(Visited, [(Row, Col)], NewVisited),
    add_parents(Neighbors, (Row, Col), Parent, NewParent),
    append(Rest, Neighbors, NewQueue),
    bfs_search(Obs, Target, NewQueue, NewVisited, NewParent, Path).

% 重建路径
reconstruct_path(Node, Parent, Path) :-
    reconstruct_path_helper(Node, Parent, [], Path).

reconstruct_path_helper(Node, Parent, Acc, Path) :-
    (member((Node, ParentNode), Parent) ->
        reconstruct_path_helper(ParentNode, Parent, [Node|Acc], Path)
    ;
        Path = [Node|Acc]).

% 添加父节点关系
add_parents([], _, Parent, Parent).
add_parents([Node|Rest], ParentNode, Parent, NewParent) :-
    add_parents(Rest, ParentNode, [(Node, ParentNode)|Parent], NewParent).

% 检查移动是否有效
valid_move(Obs, Row, Col) :-
    length(Obs, Rows),
    Obs = [FirstRow|_],
    length(FirstRow, Cols),
    Row >= 0, Row < Rows,
    Col >= 0, Col < Cols,
    get_cell(Obs, Row, Col, Cell),
    move_available(Cell).

% 获取单元格值
get_cell(Obs, Row, Col, Value) :-
    nth0(Row, Obs, RowList),
    nth0(Col, RowList, Value).

% 检查是否可移动
move_available(1) :- !, fail. % 墙壁不可移动
move_available(_).

% 路径转换为动作
path_to_actions([], []).
path_to_actions([_], []).
path_to_actions([(R1,C1),(R2,C2)|Rest], [Action|Actions]) :-
    DR is R2 - R1,
    DC is C2 - C1,
    direction_to_action(DR, DC, Action),
    path_to_actions([(R2,C2)|Rest], Actions).

% 方向转换为动作
direction_to_action(-1, 0, 0). % north
direction_to_action(0, 1, 1).  % east
direction_to_action(1, 0, 2).  % south
direction_to_action(0, -1, 3). % west

% 检查是否在门旁边
boy_next_door(Obs) :-
    locate(Obs, 5, PlayerRow, PlayerCol), % 5是玩家
    direction(_, DR, DC),
    NewRow is PlayerRow + DR,
    NewCol is PlayerCol + DC,
    valid_position(Obs, NewRow, NewCol),
    get_cell(Obs, NewRow, NewCol, 3). % 3是门

% 检查位置是否有效
valid_position(Obs, Row, Col) :-
    length(Obs, Rows),
    Obs = [FirstRow|_],
    length(FirstRow, Cols),
    Row >= 0, Row < Rows,
    Col >= 0, Col < Cols.