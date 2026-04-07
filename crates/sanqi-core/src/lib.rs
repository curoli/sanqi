//! Core data structures and rules for Sanqi.
//!
//! This crate models board positions, moves, pivot geometry, and complete
//! games. The public move notation is `from-to`, for example `a1-b3`.
//!
//! Typical usage starts with [`Position::initial`]:
//!
//! ```
//! use sanqi_core::Position;
//!
//! let position = Position::initial();
//! let legal_moves = position.legal_moves();
//! assert!(!legal_moves.is_empty());
//! ```

use std::fmt;
use std::str::FromStr;

/// Board width and height in squares.
pub const BOARD_SIZE: i8 = 8;
/// Number of squares on the Sanqi board.
pub const BOARD_SQUARES: usize = 64;
const SIDE_TO_MOVE_KEY: u64 = 0x9e37_79b9_7f4a_7c15;

/// The side to move or the owner of a piece.
#[derive(Clone, Copy, Debug, PartialEq, Eq, Hash)]
pub enum Color {
    White,
    Black,
}

impl Color {
    /// Returns the opposite color.
    pub fn opponent(self) -> Self {
        match self {
            Self::White => Self::Black,
            Self::Black => Self::White,
        }
    }
}

/// A square on the 8x8 Sanqi board.
///
/// Squares use chess-like coordinates such as `a1` and `h8`.
#[derive(Clone, Copy, PartialEq, Eq, Hash, PartialOrd, Ord)]
pub struct Square(u8);

impl Square {
    /// Creates a square from a zero-based board index.
    pub fn new(index: u8) -> Option<Self> {
        (index < BOARD_SQUARES as u8).then_some(Self(index))
    }

    /// Creates a square from zero-based file and rank coordinates.
    pub fn from_coords(file: i8, rank: i8) -> Option<Self> {
        if (0..BOARD_SIZE).contains(&file) && (0..BOARD_SIZE).contains(&rank) {
            let index = rank as u8 * BOARD_SIZE as u8 + file as u8;
            Some(Self(index))
        } else {
            None
        }
    }

    /// Returns the zero-based square index.
    pub fn index(self) -> u8 {
        self.0
    }

    /// Returns the zero-based file.
    pub fn file(self) -> i8 {
        (self.0 % BOARD_SIZE as u8) as i8
    }

    /// Returns the zero-based rank.
    pub fn rank(self) -> i8 {
        (self.0 / BOARD_SIZE as u8) as i8
    }

    /// Formats the square as an algebraic coordinate such as `a1`.
    pub fn to_coord(self) -> String {
        let file = (b'a' + self.file() as u8) as char;
        let rank = (b'1' + self.rank() as u8) as char;
        format!("{file}{rank}")
    }
}

impl fmt::Debug for Square {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        f.write_str(&self.to_coord())
    }
}

impl fmt::Display for Square {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        f.write_str(&self.to_coord())
    }
}

/// Error returned when parsing a square from text fails.
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub struct ParseSquareError;

impl fmt::Display for ParseSquareError {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        f.write_str("invalid square")
    }
}

impl std::error::Error for ParseSquareError {}

impl FromStr for Square {
    type Err = ParseSquareError;

    fn from_str(value: &str) -> Result<Self, Self::Err> {
        let bytes = value.as_bytes();
        if bytes.len() != 2 {
            return Err(ParseSquareError);
        }
        let file = bytes[0].to_ascii_lowercase();
        let rank = bytes[1];
        if !(b'a'..=b'h').contains(&file) || !(b'1'..=b'8').contains(&rank) {
            return Err(ParseSquareError);
        }
        Square::from_coords((file - b'a') as i8, (rank - b'1') as i8).ok_or(ParseSquareError)
    }
}

/// A Sanqi move written as `from-to`.
#[derive(Clone, Copy, Debug, PartialEq, Eq, Hash)]
pub struct Move {
    /// Origin square.
    pub from: Square,
    /// Destination square.
    pub to: Square,
}

impl Move {
    /// Creates a move from two squares.
    pub fn new(from: Square, to: Square) -> Self {
        Self { from, to }
    }
}

/// A canonicalized pair of supporting pieces.
#[derive(Clone, Copy, Debug, PartialEq, Eq, Hash)]
pub struct SupportPair {
    /// First support square.
    pub a: Square,
    /// Second support square.
    pub b: Square,
}

impl SupportPair {
    /// Creates a support pair and stores it in a stable order.
    pub fn new(a: Square, b: Square) -> Self {
        if a <= b {
            Self { a, b }
        } else {
            Self { a: b, b: a }
        }
    }

    /// Returns the pivot implied by the support pair.
    pub fn pivot(self) -> Pivot {
        Pivot::from_supports(self)
    }
}

/// A doubled-coordinate pivot used for Sanqi reflections.
#[derive(Clone, Copy, Debug, PartialEq, Eq, Hash)]
pub struct Pivot {
    file_twice: i8,
    rank_twice: i8,
}

impl Pivot {
    /// Builds a pivot from a support pair.
    pub fn from_supports(supports: SupportPair) -> Self {
        Self {
            file_twice: supports.a.file() + supports.b.file(),
            rank_twice: supports.a.rank() + supports.b.rank(),
        }
    }

    /// Returns twice the file coordinate of the pivot.
    pub fn file_twice(self) -> i8 {
        self.file_twice
    }

    /// Returns twice the rank coordinate of the pivot.
    pub fn rank_twice(self) -> i8 {
        self.rank_twice
    }

    /// Returns whether the pivot lies on the center of a board square.
    pub fn is_square_center(self) -> bool {
        self.file_twice % 2 == 0 && self.rank_twice % 2 == 0
    }

    /// Returns the center square if the pivot lies on an actual square center.
    pub fn center_square(self) -> Option<Square> {
        if self.is_square_center() {
            Square::from_coords(self.file_twice / 2, self.rank_twice / 2)
        } else {
            None
        }
    }

    /// Reflects a square through this pivot.
    pub fn reflect(self, square: Square) -> Option<Square> {
        Square::from_coords(self.file_twice - square.file(), self.rank_twice - square.rank())
    }
}

impl fmt::Display for Move {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        write!(f, "{}-{}", self.from, self.to)
    }
}

/// Error returned when parsing a move from text fails.
#[derive(Clone, Debug, PartialEq, Eq)]
pub enum ParseMoveError {
    InvalidFormat,
    InvalidSquare(ParseSquareError),
}

impl fmt::Display for ParseMoveError {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        match self {
            Self::InvalidFormat => f.write_str("invalid move format"),
            Self::InvalidSquare(_) => f.write_str("invalid square in move"),
        }
    }
}

impl std::error::Error for ParseMoveError {}

impl From<ParseSquareError> for ParseMoveError {
    fn from(value: ParseSquareError) -> Self {
        Self::InvalidSquare(value)
    }
}

impl FromStr for Move {
    type Err = ParseMoveError;

    fn from_str(value: &str) -> Result<Self, Self::Err> {
        let mut parts = value.split('-');
        let from = parts.next().ok_or(ParseMoveError::InvalidFormat)?.parse()?;
        let to = parts.next().ok_or(ParseMoveError::InvalidFormat)?.parse()?;
        if parts.next().is_some() {
            return Err(ParseMoveError::InvalidFormat);
        }
        Ok(Self::new(from, to))
    }
}

/// Information required to undo a previously applied move.
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub struct Undo {
    moved_color: Color,
    captured: Option<Square>,
    previous_side_to_move: Color,
}

/// Errors that can occur when validating or applying a move.
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum MoveError {
    WrongColorToMove,
    OriginMissing,
    NullMove,
    DestinationOccupiedByOwnPiece,
    MissingPivot,
}

impl fmt::Display for MoveError {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        match self {
            Self::WrongColorToMove => f.write_str("piece does not belong to player to move"),
            Self::OriginMissing => f.write_str("origin square is empty"),
            Self::NullMove => f.write_str("start and destination must differ"),
            Self::DestinationOccupiedByOwnPiece => {
                f.write_str("destination is occupied by a friendly piece")
            }
            Self::MissingPivot => f.write_str("no supporting pivot exists for this move"),
        }
    }
}

impl std::error::Error for MoveError {}

/// The result of a finished position.
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum Outcome {
    Winner(Color),
}

/// A complete Sanqi board position.
///
/// The position stores both bitboards and the side to move. Legal move
/// generation uses pivot geometry and returns de-duplicated `from-to` moves.
#[derive(Clone, PartialEq, Eq)]
pub struct Position {
    white: u64,
    black: u64,
    side_to_move: Color,
    zobrist_key: u64,
}

impl fmt::Debug for Position {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        f.debug_struct("Position")
            .field("white", &format_args!("{:#018x}", self.white))
            .field("black", &format_args!("{:#018x}", self.black))
            .field("side_to_move", &self.side_to_move)
            .finish()
    }
}

const fn compute_zobrist_key(white: u64, black: u64, side_to_move: Color) -> u64 {
    let mut key = 0_u64;
    let mut index = 0_usize;
    while index < BOARD_SQUARES {
        let mask = 1_u64 << index;
        if white & mask != 0 {
            key ^= zobrist_piece(Color::White, index);
        } else if black & mask != 0 {
            key ^= zobrist_piece(Color::Black, index);
        }
        index += 1;
    }
    if matches!(side_to_move, Color::White) {
        key ^= SIDE_TO_MOVE_KEY;
    }
    key
}

const fn zobrist_piece(color: Color, square: usize) -> u64 {
    let color_offset = match color {
        Color::White => 0_u64,
        Color::Black => 0x94d0_49bb_1331_11eb,
    };
    splitmix64(square as u64 ^ color_offset ^ 0x243f_6a88_85a3_08d3)
}

const fn splitmix64(mut value: u64) -> u64 {
    value = value.wrapping_add(0x9e37_79b9_7f4a_7c15);
    value = (value ^ (value >> 30)).wrapping_mul(0xbf58_476d_1ce4_e5b9);
    value = (value ^ (value >> 27)).wrapping_mul(0x94d0_49bb_1331_11eb);
    value ^ (value >> 31)
}

impl Default for Position {
    fn default() -> Self {
        Self::initial()
    }
}

impl Position {
    /// Returns the standard initial position.
    pub fn initial() -> Self {
        let mut white = 0_u64;
        let mut black = 0_u64;
        for rank in 0..=1 {
            for file in 0..BOARD_SIZE {
                let square = Square::from_coords(file, rank).expect("initial white square");
                white |= 1_u64 << square.index();
            }
        }
        for rank in 6..=7 {
            for file in 0..BOARD_SIZE {
                let square = Square::from_coords(file, rank).expect("initial black square");
                black |= 1_u64 << square.index();
            }
        }
        Self {
            white,
            black,
            side_to_move: Color::White,
            zobrist_key: compute_zobrist_key(white, black, Color::White),
        }
    }

    /// Returns an empty position with the given side to move.
    pub fn empty(side_to_move: Color) -> Self {
        Self {
            white: 0,
            black: 0,
            side_to_move,
            zobrist_key: compute_zobrist_key(0, 0, side_to_move),
        }
    }

    /// Returns the side to move.
    pub fn side_to_move(&self) -> Color {
        self.side_to_move
    }

    /// Sets the side to move.
    pub fn set_side_to_move(&mut self, color: Color) {
        if self.side_to_move == color {
            return;
        }
        self.zobrist_key ^= SIDE_TO_MOVE_KEY;
        self.side_to_move = color;
    }

    /// Returns the incremental Zobrist key for the position.
    pub fn zobrist_key(&self) -> u64 {
        self.zobrist_key
    }

    /// Returns the occupancy bitboard of both sides.
    pub fn occupancy(&self) -> u64 {
        self.white | self.black
    }

    /// Returns the occupancy bitboard for one side.
    pub fn occupancy_of(&self, color: Color) -> u64 {
        match color {
            Color::White => self.white,
            Color::Black => self.black,
        }
    }

    /// Returns the piece color on a square, if any.
    pub fn piece_at(&self, square: Square) -> Option<Color> {
        let mask = 1_u64 << square.index();
        if self.white & mask != 0 {
            Some(Color::White)
        } else if self.black & mask != 0 {
            Some(Color::Black)
        } else {
            None
        }
    }

    /// Returns whether `color` occupies `square`.
    pub fn has_piece(&self, color: Color, square: Square) -> bool {
        self.occupancy_of(color) & (1_u64 << square.index()) != 0
    }

    /// Returns the number of pieces owned by one side.
    pub fn piece_count(&self, color: Color) -> usize {
        self.occupancy_of(color).count_ones() as usize
    }

    /// Places a piece on a square, replacing any previous occupant.
    pub fn set_piece(&mut self, color: Color, square: Square) {
        self.clear_square(square);
        let mask = 1_u64 << square.index();
        match color {
            Color::White => self.white |= mask,
            Color::Black => self.black |= mask,
        }
        self.zobrist_key ^= zobrist_piece(color, square.index() as usize);
    }

    /// Removes any piece from a square.
    pub fn clear_square(&mut self, square: Square) {
        let mask = 1_u64 << square.index();
        if self.white & mask != 0 {
            self.white &= !mask;
            self.zobrist_key ^= zobrist_piece(Color::White, square.index() as usize);
        } else if self.black & mask != 0 {
            self.black &= !mask;
            self.zobrist_key ^= zobrist_piece(Color::Black, square.index() as usize);
        }
    }

    /// Returns all legal moves for the side to move.
    ///
    /// Moves are returned in `from-to` form and are de-duplicated even when
    /// multiple support pairs allow the same move.
    pub fn legal_moves(&self) -> Vec<Move> {
        let color = self.side_to_move;
        let pieces = self.squares_of(color);
        let own_occupancy = self.occupancy_of(color);
        let mut seen = [false; BOARD_SQUARES * BOARD_SQUARES];
        let mut moves = Vec::new();

        for i in 0..pieces.len() {
            for j in (i + 1)..pieces.len() {
                let pivot = SupportPair::new(pieces[i], pieces[j]).pivot();
                for attacker in &pieces {
                    if let Some(to) = pivot.reflect(*attacker) {
                        if to == *attacker || own_occupancy & (1_u64 << to.index()) != 0 {
                            continue;
                        }
                        let mv = Move::new(*attacker, to);
                        let slot = mv.from.index() as usize * BOARD_SQUARES + mv.to.index() as usize;
                        if !seen[slot] {
                            seen[slot] = true;
                            moves.push(mv);
                        }
                    }
                }
            }
        }
        moves
    }

    /// Checks whether a move is legal in the current position.
    pub fn is_legal_move(&self, mv: Move) -> Result<(), MoveError> {
        let color = self.side_to_move;

        if mv.from == mv.to {
            return Err(MoveError::NullMove);
        }
        if !self.has_piece(color, mv.from) {
            return match self.piece_at(mv.from) {
                Some(_) => Err(MoveError::WrongColorToMove),
                None => Err(MoveError::OriginMissing),
            };
        }
        if self.has_piece(color, mv.to) {
            return Err(MoveError::DestinationOccupiedByOwnPiece);
        }
        if !self.has_supporting_pivot(color, mv) {
            return Err(MoveError::MissingPivot);
        }

        Ok(())
    }

    /// Applies a legal move and returns undo information.
    pub fn apply_move(&mut self, mv: Move) -> Result<Undo, MoveError> {
        self.is_legal_move(mv)?;
        let color = self.side_to_move;
        let opponent = color.opponent();
        let captured = self.has_piece(opponent, mv.to).then_some(mv.to);

        self.clear_square(mv.from);
        self.set_piece(color, mv.to);
        self.side_to_move = opponent;

        Ok(Undo {
            moved_color: color,
            captured,
            previous_side_to_move: color,
        })
    }

    /// Reverts a move that was previously applied with [`Position::apply_move`].
    pub fn undo_move(&mut self, mv: Move, undo: Undo) -> Result<(), MoveError> {
        self.side_to_move = undo.previous_side_to_move;
        self.clear_square(mv.to);
        self.set_piece(undo.moved_color, mv.from);
        if let Some(square) = undo.captured {
            self.set_piece(undo.moved_color.opponent(), square);
        }
        Ok(())
    }

    /// Returns the winner if the side to move has no legal moves.
    pub fn outcome(&self) -> Option<Outcome> {
        self.legal_moves()
            .is_empty()
            .then_some(Outcome::Winner(self.side_to_move.opponent()))
    }

    /// Returns all occupied squares for one side.
    pub fn squares_of(&self, color: Color) -> Vec<Square> {
        squares_from_bits(self.occupancy_of(color))
    }

    /// Returns all supporting pivots for the side to move.
    pub fn pivots(&self) -> Vec<PivotEntry> {
        self.pivots_for(self.side_to_move)
    }

    /// Returns all supporting pivots for a given side.
    pub fn pivots_for(&self, color: Color) -> Vec<PivotEntry> {
        let pieces = self.squares_of(color);
        let mut pivots = Vec::new();
        for i in 0..pieces.len() {
            for j in (i + 1)..pieces.len() {
                let supports = SupportPair::new(pieces[i], pieces[j]);
                pivots.push(PivotEntry {
                    pivot: supports.pivot(),
                    supports,
                });
            }
        }
        pivots
    }

    /// Returns all moves that can be generated from one pivot for one side.
    pub fn moves_from_pivot(&self, color: Color, pivot: Pivot) -> Vec<Move> {
        let pieces = self.squares_of(color);
        let own_occupancy = self.occupancy_of(color);
        let mut moves = Vec::new();

        for attacker in pieces {
            if let Some(to) = pivot.reflect(attacker) {
                if to == attacker {
                    continue;
                }
                if own_occupancy & (1_u64 << to.index()) != 0 {
                    continue;
                }
                moves.push(Move::new(attacker, to));
            }
        }

        moves
    }

    /// Returns all pivots and support pairs that justify a given move.
    pub fn supporting_pivots(&self, color: Color, mv: Move) -> Vec<PivotEntry> {
        let pieces = self.squares_of(color);
        let pivot = Pivot {
            file_twice: mv.from.file() + mv.to.file(),
            rank_twice: mv.from.rank() + mv.to.rank(),
        };
        let mut matches = Vec::new();

        for i in 0..pieces.len() {
            let support_a = pieces[i];
            if support_a == mv.from {
                continue;
            }
            for &support_b in &pieces[(i + 1)..] {
                if support_b == mv.from {
                    continue;
                }
                let supports = SupportPair::new(support_a, support_b);
                if supports.pivot() == pivot {
                    matches.push(PivotEntry { pivot, supports });
                }
            }
        }

        matches
    }

    fn has_supporting_pivot(&self, color: Color, mv: Move) -> bool {
        let pieces = self.squares_of(color);
        let pivot = Pivot {
            file_twice: mv.from.file() + mv.to.file(),
            rank_twice: mv.from.rank() + mv.to.rank(),
        };

        for i in 0..pieces.len() {
            let support_a = pieces[i];
            if support_a == mv.from {
                continue;
            }
            for &support_b in &pieces[(i + 1)..] {
                if support_b == mv.from {
                    continue;
                }
                if SupportPair::new(support_a, support_b).pivot() == pivot {
                    return true;
                }
            }
        }

        false
    }
}

fn squares_from_bits(mut bits: u64) -> Vec<Square> {
        let mut squares = Vec::with_capacity(bits.count_ones() as usize);
        while bits != 0 {
            let index = bits.trailing_zeros() as u8;
            squares.push(Square(index));
            bits &= bits - 1;
        }
        squares
    }

/// A pivot together with the supporting pair that defines it.
#[derive(Clone, Copy, Debug, PartialEq, Eq, Hash)]
pub struct PivotEntry {
    /// The pivot derived from `supports`.
    pub pivot: Pivot,
    /// The support pair that defines the pivot.
    pub supports: SupportPair,
}

/// A move history together with all reached positions.
#[derive(Clone, Debug, Default)]
pub struct Game {
    positions: Vec<Position>,
    moves: Vec<Move>,
}

impl Game {
    /// Creates a game from the standard initial position.
    pub fn new() -> Self {
        Self {
            positions: vec![Position::initial()],
            moves: Vec::new(),
        }
    }

    /// Creates a game from an arbitrary starting position.
    pub fn from_position(position: Position) -> Self {
        Self {
            positions: vec![position],
            moves: Vec::new(),
        }
    }

    /// Returns the current position.
    pub fn current_position(&self) -> &Position {
        self.positions
            .last()
            .expect("game always contains a current position")
    }

    /// Returns the played move list.
    pub fn moves(&self) -> &[Move] {
        &self.moves
    }

    /// Plays one move from the current position.
    pub fn play(&mut self, mv: Move) -> Result<(), MoveError> {
        let mut position = self.current_position().clone();
        position.apply_move(mv)?;
        self.positions.push(position);
        self.moves.push(mv);
        Ok(())
    }

    /// Parses and plays one move in `from-to` notation.
    pub fn play_str(&mut self, mv: &str) -> Result<(), GameError> {
        let parsed: Move = mv.parse()?;
        self.play(parsed)?;
        Ok(())
    }
}

/// Errors that can occur while parsing or playing moves in a game.
#[derive(Debug)]
pub enum GameError {
    Parse(ParseMoveError),
    IllegalMove(MoveError),
}

impl fmt::Display for GameError {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        match self {
            Self::Parse(error) => error.fmt(f),
            Self::IllegalMove(error) => error.fmt(f),
        }
    }
}

impl std::error::Error for GameError {}

impl From<ParseMoveError> for GameError {
    fn from(value: ParseMoveError) -> Self {
        Self::Parse(value)
    }
}

impl From<MoveError> for GameError {
    fn from(value: MoveError) -> Self {
        Self::IllegalMove(value)
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn initial_position_has_expected_piece_counts() {
        let position = Position::initial();
        assert_eq!(position.piece_count(Color::White), 16);
        assert_eq!(position.piece_count(Color::Black), 16);
        assert_eq!(position.side_to_move(), Color::White);
        assert!(position.has_piece(Color::White, "a1".parse().expect("square")));
        assert!(position.has_piece(Color::White, "h2".parse().expect("square")));
        assert!(position.has_piece(Color::Black, "a7".parse().expect("square")));
        assert!(position.has_piece(Color::Black, "h8".parse().expect("square")));
    }

    #[test]
    fn parses_move() {
        let mv: Move = "a1-b3".parse().expect("move");
        assert_eq!(mv.from, "a1".parse().expect("square"));
        assert_eq!(mv.to, "b3".parse().expect("square"));
        assert_eq!(mv.to_string(), "a1-b3");
    }

    #[test]
    fn legal_move_is_generated_from_initial_position() {
        let position = Position::initial();
        let mv: Move = "a1-b3".parse().expect("move");
        let legal_moves = position.legal_moves();
        assert!(legal_moves.contains(&mv));
    }

    #[test]
    fn applying_move_updates_board_and_side_to_move() {
        let mut position = Position::initial();
        let mv: Move = "a1-b3".parse().expect("move");
        let undo = position.apply_move(mv).expect("legal move");
        assert!(!position.has_piece(Color::White, "a1".parse().expect("square")));
        assert!(position.has_piece(Color::White, "b3".parse().expect("square")));
        assert_eq!(position.side_to_move(), Color::Black);
        position.undo_move(mv, undo).expect("undo");
        assert!(position.has_piece(Color::White, "a1".parse().expect("square")));
        assert_eq!(position.side_to_move(), Color::White);
    }

    #[test]
    fn position_with_two_pieces_has_no_legal_moves() {
        let mut position = Position::empty(Color::White);
        position.set_piece(Color::White, "a1".parse().expect("square"));
        position.set_piece(Color::White, "b1".parse().expect("square"));
        position.set_piece(Color::Black, "h8".parse().expect("square"));
        assert!(position.legal_moves().is_empty());
        assert_eq!(position.outcome(), Some(Outcome::Winner(Color::Black)));
    }

    #[test]
    fn multiple_support_pairs_collapse_to_single_move() {
        let mut position = Position::empty(Color::White);
        position.set_piece(Color::White, "b2".parse().expect("square"));
        position.set_piece(Color::White, "a1".parse().expect("square"));
        position.set_piece(Color::White, "c1".parse().expect("square"));
        position.set_piece(Color::White, "a3".parse().expect("square"));
        position.set_piece(Color::White, "c3".parse().expect("square"));

        let target: Move = "b2-b4".parse().expect("move");
        let matching = position
            .legal_moves()
            .into_iter()
            .filter(|mv| *mv == target)
            .count();
        assert_eq!(matching, 1);
    }

    #[test]
    fn zobrist_key_is_restored_after_undo() {
        let mut position = Position::initial();
        let original_key = position.zobrist_key();
        let mv: Move = "a1-b3".parse().expect("move");
        let undo = position.apply_move(mv).expect("apply");
        assert_ne!(position.zobrist_key(), original_key);
        position.undo_move(mv, undo).expect("undo");
        assert_eq!(position.zobrist_key(), original_key);
    }

    #[test]
    fn pivot_api_exposes_center_and_reflections() {
        let supports = SupportPair::new("a2".parse().expect("square"), "b2".parse().expect("square"));
        let pivot = supports.pivot();
        assert!(!pivot.is_square_center());
        assert_eq!(pivot.center_square(), None);
        assert_eq!(
            pivot.reflect("a1".parse().expect("square")),
            Some("b3".parse().expect("square"))
        );
    }

    #[test]
    fn supporting_pivots_are_queryable_for_move() {
        let position = Position::initial();
        let mv: Move = "a1-b3".parse().expect("move");
        let pivots = position.supporting_pivots(Color::White, mv);
        assert!(!pivots.is_empty());
        assert!(pivots.iter().any(|entry| {
            entry.supports == SupportPair::new(
                "a2".parse().expect("square"),
                "b2".parse().expect("square")
            )
        }));
    }
}
