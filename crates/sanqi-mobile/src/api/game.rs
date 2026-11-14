use flutter_rust_bridge::frb;
use sanqi_core::{Color, Game, Move, Outcome, Square};

#[derive(Clone, Debug, PartialEq, Eq)]
pub struct MobileMove {
    pub from: u8,
    pub to: u8,
    pub notation: String,
}

#[derive(Clone, Debug, PartialEq, Eq)]
pub struct SupportView {
    pub first: u8,
    pub second: u8,
    pub file_twice: i8,
    pub rank_twice: i8,
}

#[derive(Clone, Debug)]
pub struct GameView {
    pub svg: String,
    pub side_to_move: String,
    pub winner: Option<String>,
    pub selected: Option<u8>,
    pub legal_moves: Vec<MobileMove>,
    pub inspected_move: Option<MobileMove>,
    pub supports: Vec<SupportView>,
    pub movetext: String,
    pub can_undo: bool,
}

#[frb(opaque)]
pub struct MobileGame {
    game: Game,
    selected: Option<Square>,
    inspected: Option<Move>,
    last_supports: Vec<SupportView>,
}

pub fn create_game() -> MobileGame {
    MobileGame::new()
}

fn move_view(mv: Move) -> MobileMove {
    MobileMove {
        from: mv.from.index(),
        to: mv.to.index(),
        notation: mv.to_string(),
    }
}

fn color_name(color: Color) -> String {
    match color {
        Color::White => "White".to_owned(),
        Color::Black => "Black".to_owned(),
    }
}

impl Default for MobileGame {
    fn default() -> Self {
        Self::new()
    }
}

impl MobileGame {
    pub fn new() -> Self {
        Self {
            game: Game::new(),
            selected: None,
            inspected: None,
            last_supports: Vec::new(),
        }
    }

    pub fn view(&self) -> GameView {
        let position = self.game.current_position();
        let winner = position
            .outcome()
            .map(|Outcome::Winner(color)| color_name(color));
        let legal_moves = if winner.is_none() {
            position.legal_moves().into_iter().map(move_view).collect()
        } else {
            Vec::new()
        };
        let svg = match self.inspected {
            Some(mv) => sanqi_render::svg_for_move(position, mv),
            None => sanqi_render::svg_board(position),
        };
        GameView {
            svg,
            side_to_move: color_name(position.side_to_move()),
            winner,
            selected: self.selected.map(Square::index),
            legal_moves,
            inspected_move: self.inspected.map(move_view),
            supports: self.last_supports.clone(),
            movetext: self.game.to_movetext(),
            can_undo: !self.game.moves().is_empty(),
        }
    }

    pub fn tap(&mut self, index: u8) -> Result<GameView, String> {
        let square = Square::new(index).ok_or("Square must be between 0 and 63")?;
        if self.game.current_position().outcome().is_some() {
            return Ok(self.view());
        }
        if let Some(from) = self.selected {
            let mv = Move::new(from, square);
            if self.game.current_position().legal_moves().contains(&mv) {
                self.game.play(mv).map_err(|error| error.to_string())?;
                self.selected = None;
                self.inspected = None;
                self.last_supports.clear();
                return Ok(self.view());
            }
        }
        let position = self.game.current_position();
        self.selected = if self.selected != Some(square)
            && position.piece_at(square) == Some(position.side_to_move())
        {
            Some(square)
        } else {
            None
        };
        self.inspected = None;
        self.last_supports.clear();
        Ok(self.view())
    }

    pub fn inspect_move(&mut self, notation: String) -> Result<GameView, String> {
        let mv: Move = notation
            .parse()
            .map_err(|error: sanqi_core::ParseMoveError| error.to_string())?;
        let position = self.game.current_position();
        if position.outcome().is_some() || !position.legal_moves().contains(&mv) {
            return Err("Only a legal move for the current player can be inspected".to_owned());
        }
        self.last_supports = position
            .supporting_pivots(position.side_to_move(), mv)
            .into_iter()
            .map(|entry| SupportView {
                first: entry.supports.a.index(),
                second: entry.supports.b.index(),
                file_twice: entry.pivot.file_twice(),
                rank_twice: entry.pivot.rank_twice(),
            })
            .collect();
        self.selected = Some(mv.from);
        self.inspected = Some(mv);
        Ok(self.view())
    }

    pub fn new_game(&mut self) -> GameView {
        *self = Self::new();
        self.view()
    }

    pub fn undo(&mut self) -> Result<GameView, String> {
        let mut replacement = Game::new();
        let moves = self.game.moves();
        for mv in moves.iter().take(moves.len().saturating_sub(1)) {
            replacement.play(*mv).map_err(|error| error.to_string())?;
        }
        self.game = replacement;
        self.selected = None;
        self.inspected = None;
        self.last_supports.clear();
        Ok(self.view())
    }

    pub fn restore(&mut self, movetext: String) -> Result<GameView, String> {
        let replacement = Game::from_movetext(&movetext).map_err(|error| error.to_string())?;
        self.game = replacement;
        self.selected = None;
        self.inspected = None;
        self.last_supports.clear();
        Ok(self.view())
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn moves_and_turns_are_owned_by_game() {
        let mut session = MobileGame::new();
        let initial = session.view();
        let mv = initial.legal_moves[0].clone();
        assert!(initial.svg.contains("<svg"));
        assert_eq!(
            session.tap(mv.from).expect("select").selected,
            Some(mv.from)
        );
        let played = session.tap(mv.to).expect("play");
        assert_eq!(played.side_to_move, "Black");
        let mut expected = Game::new();
        expected.play_str(&mv.notation).expect("core play");
        assert_eq!(played.movetext, expected.to_movetext());
        assert!(played.can_undo);
        assert_eq!(session.undo().expect("undo").svg, initial.svg);
        assert!(!session.view().can_undo);
        assert_eq!(session.undo().expect("empty undo").movetext, "");
    }

    #[test]
    fn inspection_preserves_move_semantics_and_reports_every_support() {
        let mut session = MobileGame::new();
        for mv in session.view().legal_moves {
            let inspected = session.inspect_move(mv.notation.clone()).expect("inspect");
            let expected = session
                .game
                .current_position()
                .supporting_pivots(Color::White, mv.notation.parse().expect("move"));
            assert_eq!(inspected.supports.len(), expected.len());
            assert!(!inspected.supports.is_empty());
            assert_eq!(inspected.movetext, "");
            assert_eq!(inspected.inspected_move, Some(mv));
        }
    }

    #[test]
    fn restore_is_atomic_and_undo_retains_history() {
        let mut session = MobileGame::new();
        session
            .restore("1. h1-d3 h8-d6 2. a1-d4".to_owned())
            .expect("restore");
        let saved = session.view().movetext;
        assert!(session.restore("1. nonsense".to_owned()).is_err());
        assert_eq!(session.view().movetext, saved);
        assert_eq!(session.undo().expect("undo").movetext, "1. h1-d3 h8-d6");
        assert_eq!(session.new_game().movetext, "");
        assert!(session.tap(64).is_err());
        assert!(session.inspect_move("a1-a8".to_owned()).is_err());
    }

    #[test]
    fn multiple_pairs_are_previews_of_one_move() {
        let mut position = sanqi_core::Position::empty(Color::White);
        for name in ["b2", "a1", "c1", "a3", "c3", "a2", "c4"] {
            position.set_piece(Color::White, name.parse().expect("square"));
        }
        position.set_piece(Color::Black, "h8".parse().expect("square"));
        let mut session = MobileGame::new();
        session.game = Game::from_position(position);
        let preview = session.inspect_move("b2-b4".to_owned()).expect("inspect");
        assert!(preview.supports.len() > 1);
        assert_eq!(
            preview
                .legal_moves
                .iter()
                .filter(|mv| mv.notation == "b2-b4")
                .count(),
            1
        );
        let played = session
            .tap("b4".parse::<Square>().expect("square").index())
            .expect("play");
        assert_eq!(played.movetext, "1. b2-b4");
    }

    #[test]
    fn selection_and_terminal_positions_do_not_accept_illegal_moves() {
        let mut session = MobileGame::new();
        assert_eq!(session.tap(56).expect("opponent piece").selected, None);
        assert_eq!(session.tap(0).expect("own piece").selected, Some(0));
        assert_eq!(session.tap(0).expect("deselect").selected, None);
        assert_eq!(session.view().movetext, "");
        let mut position = sanqi_core::Position::empty(Color::White);
        position.set_piece(Color::White, "a1".parse().expect("square"));
        position.set_piece(Color::White, "b1".parse().expect("square"));
        position.set_piece(Color::Black, "h8".parse().expect("square"));
        session.game = Game::from_position(position);
        let terminal = session.view();
        assert_eq!(terminal.winner.as_deref(), Some("Black"));
        assert!(terminal.legal_moves.is_empty());
        assert_eq!(session.tap(0).expect("terminal tap").movetext, "");
    }
}
