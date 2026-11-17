use std::hash::BuildHasher;

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
    pub computer_both: bool,
    pub revision: u64,
    pub human_color: Option<String>,
    pub computer_turn: bool,
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
    computer_both: bool,
    revision: u64,
    human_color: Option<Color>,
    game: Game,
    selected: Option<Square>,
    inspected: Option<Move>,
    last_supports: Vec<SupportView>,
}

pub fn create_game() -> MobileGame {
    MobileGame::new()
}

pub fn find_computer_move(movetext: String) -> Result<Option<String>, String> {
    let game = Game::from_movetext(&movetext).map_err(|error| error.to_string())?;
    let position = game.current_position();
    if position.outcome().is_some() {
        return Ok(None);
    }
    Ok(sanqi_engine::analyze_iterative_varied(
        position,
        6,
        std::time::Duration::from_millis(600),
        // Fresh standard-library randomized hashing seeds each search without
        // clocks, shared mutable RNG state, or an additional dependency.
        std::collections::hash_map::RandomState::new().hash_one(()),
    )
    .best
    .map(|result| result.best_move.to_string()))
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
            computer_both: false,
            revision: 0,
            human_color: None,
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
            computer_both: self.computer_both,
            revision: self.revision,
            human_color: self.human_color.map(color_name),
            computer_turn: (self.computer_both
                || self
                    .human_color
                    .is_some_and(|human| human != position.side_to_move()))
                && winner.is_none(),
            svg,
            side_to_move: color_name(position.side_to_move()),
            winner,
            selected: self.selected.map(Square::index),
            legal_moves,
            inspected_move: self.inspected.map(move_view),
            supports: self.last_supports.clone(),
            movetext: self.game.to_movetext(),
            can_undo: !self.game.moves().is_empty()
                && !(self.human_color == Some(Color::Black) && self.game.moves().len() == 1),
        }
    }

    pub fn tap(&mut self, index: u8) -> Result<GameView, String> {
        let square = Square::new(index).ok_or("Square must be between 0 and 63")?;
        if self.view().computer_turn || self.game.current_position().outcome().is_some() {
            return Ok(self.view());
        }
        if let Some(from) = self.selected {
            let mv = Move::new(from, square);
            if self.game.current_position().legal_moves().contains(&mv) {
                self.game.play(mv).map_err(|error| error.to_string())?;
                self.revision += 1;
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
        let revision = self.revision + 1;
        let human_color = self.human_color;
        let computer_both = self.computer_both;
        *self = Self::new();
        self.revision = revision;
        self.human_color = human_color;
        self.computer_both = computer_both;
        self.view()
    }

    pub fn start_game(&mut self, human_color: Option<String>) -> Result<GameView, String> {
        let human = match human_color.as_deref() {
            None => None,
            Some("White") => Some(Color::White),
            Some("Black") => Some(Color::Black),
            _ => return Err("Human color must be White or Black".to_owned()),
        };
        self.human_color = human;
        self.computer_both = false;
        Ok(self.new_game())
    }

    pub fn start_computer_game(&mut self) -> GameView {
        self.human_color = None;
        self.computer_both = true;
        self.new_game()
    }

    pub fn cancel_search(&mut self) -> GameView {
        self.revision += 1;
        self.view()
    }

    pub fn apply_computer_move(
        &mut self,
        expected_revision: u64,
        notation: String,
    ) -> Result<GameView, String> {
        if self.revision != expected_revision || !self.view().computer_turn {
            return Ok(self.view());
        }
        self.game
            .play_str(&notation)
            .map_err(|error| error.to_string())?;
        self.revision += 1;
        self.selected = None;
        self.inspected = None;
        self.last_supports.clear();
        Ok(self.view())
    }

    pub fn undo(&mut self) -> Result<GameView, String> {
        let mut replacement = Game::new();
        let moves = self.game.moves();
        let remove = if self.human_color == Some(self.game.current_position().side_to_move())
            && moves.len() >= 2
        {
            2
        } else {
            1
        };
        for mv in moves.iter().take(moves.len().saturating_sub(remove)) {
            replacement.play(*mv).map_err(|error| error.to_string())?;
        }
        self.game = replacement;
        self.revision += 1;
        self.selected = None;
        self.inspected = None;
        self.last_supports.clear();
        Ok(self.view())
    }

    pub fn restore(&mut self, movetext: String) -> Result<GameView, String> {
        let replacement = Game::from_movetext(&movetext).map_err(|error| error.to_string())?;
        self.game = replacement;
        self.revision += 1;
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
    fn both_computers_alternate_and_cancelled_search_cannot_commit() {
        let mut session = MobileGame::new();
        let opening = session.start_computer_game();
        assert!(opening.computer_both && opening.computer_turn);
        assert_eq!(session.tap(0).expect("blocked human").selected, None);
        let first = opening.legal_moves[0].notation.clone();
        let cancelled = session.cancel_search();
        assert!(cancelled.revision > opening.revision);
        assert_eq!(cancelled.movetext, opening.movetext);
        assert_eq!(
            session
                .apply_computer_move(opening.revision, first.clone())
                .expect("cancelled result")
                .movetext,
            ""
        );
        let white = session
            .apply_computer_move(cancelled.revision, first)
            .expect("white move");
        assert_eq!(white.side_to_move, "Black");
        assert!(white.computer_turn);
        let black = session
            .apply_computer_move(white.revision, white.legal_moves[0].notation.clone())
            .expect("black move");
        assert_eq!(black.side_to_move, "White");
        assert!(black.computer_turn);
        let undone = session.undo().expect("one ply");
        assert_eq!(undone.movetext, white.movetext);
        assert!(undone.computer_turn);
        assert!(session.new_game().computer_both);
        let local = session.start_game(None).expect("local");
        assert!(!local.computer_both && !local.computer_turn);
        let human = session.start_game(Some("White".to_owned())).expect("human");
        assert!(!human.computer_both && !human.computer_turn);
    }

    #[test]
    fn computer_search_is_legal_and_stale_results_cannot_change_a_new_game() {
        let mut session = MobileGame::new();
        let before = session.start_game(Some("Black".to_owned())).expect("mode");
        assert!(before.computer_turn);
        assert_eq!(session.tap(0).expect("blocked tap").movetext, "");
        let reply = find_computer_move(before.movetext)
            .expect("search")
            .expect("move");
        assert!(
            session
                .game
                .current_position()
                .legal_moves()
                .iter()
                .any(|mv| mv.to_string() == reply)
        );
        session.new_game();
        assert_eq!(
            session
                .apply_computer_move(before.revision, reply)
                .expect("stale")
                .movetext,
            ""
        );
    }

    #[test]
    fn computer_reply_and_undo_return_control_to_the_human() {
        let mut session = MobileGame::new();
        session.start_game(Some("White".to_owned())).expect("mode");
        let mv = session.view().legal_moves[0].clone();
        session.tap(mv.from).expect("select");
        let pending = session.tap(mv.to).expect("human move");
        assert!(pending.computer_turn);
        let reply = find_computer_move(pending.movetext.clone())
            .expect("search")
            .expect("reply");
        let played = session
            .apply_computer_move(pending.revision, reply.clone())
            .expect("computer");
        assert!(!played.computer_turn);
        assert_eq!(
            session
                .apply_computer_move(pending.revision, reply)
                .expect("duplicate")
                .movetext,
            played.movetext
        );
        assert_eq!(session.undo().expect("undo round").movetext, "");
        session.restore(pending.movetext).expect("restore pending");
        assert!(session.view().computer_turn);
        assert_eq!(session.undo().expect("undo pending").movetext, "");
        assert!(!session.view().computer_turn);
        session.start_game(None).expect("local mode");
        assert_eq!(session.view().human_color, None);
    }

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
