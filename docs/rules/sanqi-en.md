# Sanqi (三棋)

Sanqi (Chinese 三棋, Sānqí, “Three Chess”) is a two-player strategy game in which coordination between pieces plays a central role.

The two players, White and Black, take turns. White moves first.

Sanqi is played on a chessboard. Each player has sixteen pieces, which occupy the two ranks closest to that player.

![Figure 1: Initial position](images/sanqi-start.svg "Figure 1: Initial position")

A move involves three pieces: one attacker (the piece that moves) and two supports (which do not move). Any piece can act as either an attacker or a support.

The two supports define a pivot point, which is the point exactly halfway between them. The pivot point may lie in the center of a square, at the midpoint of the edge between two squares, or at a corner where four squares meet.

The attacker is moved across the pivot point so that it lands on the opposite side, with the pivot point exactly midway between the starting square and the destination square (Figure 2). The starting and destination squares must not be identical, even if the attacker is initially located on a pivot point.

There is no restriction on how far the attacker may move, except that it must land within the board. The direction of movement does not have to be parallel to the edges or diagonals of the board; many directions are possible.

The destination square must either be empty or occupied by an opponent’s piece, which is then captured and removed from the game.

![Figure 2: Examples of possible moves](images/sanqi-moves.svg "Figure 2: Examples of possible moves")

A player loses if they have no legal move. This may occur, for example, if a player has fewer than three pieces remaining. It may also happen that a player loses because their pieces block each other in such a way that no move is possible.

![Figure 3: Example of a position with no legal moves](images/sanqi-blocked.svg "Figure 3: Example of a position with no legal moves")