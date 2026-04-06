use sanqi_core::{Move, Outcome, Position};

pub const WIN_SCORE: i32 = 100_000;

#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub struct SearchResult {
    pub best_move: Move,
    pub score: i32,
    pub depth: u8,
}

pub fn evaluate(position: &Position) -> i32 {
    if let Some(Outcome::Winner(_)) = position.outcome() {
        return -WIN_SCORE;
    }

    let side = position.side_to_move();
    let opponent = side.opponent();
    let material = position.piece_count(side) as i32 - position.piece_count(opponent) as i32;

    let mobility = position.legal_moves().len() as i32;
    let mut flipped = position.clone();
    flipped.apply_null_turn();
    let opponent_mobility = flipped.legal_moves().len() as i32;

    material * 100 + (mobility - opponent_mobility) * 10
}

pub fn best_move(position: &Position, depth: u8) -> Option<SearchResult> {
    let moves = position.legal_moves();
    let mut best: Option<SearchResult> = None;
    let mut alpha = -WIN_SCORE - 1;
    let beta = WIN_SCORE + 1;

    for mv in moves {
        let mut next = position.clone();
        next.apply_move(mv).ok()?;
        let score = -negamax(&next, depth.saturating_sub(1), -beta, -alpha);
        if score > alpha {
            alpha = score;
            best = Some(SearchResult {
                best_move: mv,
                score,
                depth,
            });
        }
    }

    best
}

fn negamax(position: &Position, depth: u8, mut alpha: i32, beta: i32) -> i32 {
    if depth == 0 || position.outcome().is_some() {
        return evaluate(position);
    }

    let mut best_score = -WIN_SCORE - 1;
    for mv in position.legal_moves() {
        let mut next = position.clone();
        if next.apply_move(mv).is_err() {
            continue;
        }
        let score = -negamax(&next, depth - 1, -beta, -alpha);
        if score > best_score {
            best_score = score;
        }
        if score > alpha {
            alpha = score;
        }
        if alpha >= beta {
            break;
        }
    }
    best_score
}

trait NullTurn {
    fn apply_null_turn(&mut self);
}

impl NullTurn for Position {
    fn apply_null_turn(&mut self) {
        self.set_side_to_move(self.side_to_move().opponent());
    }
}

#[cfg(test)]
mod tests {
    use sanqi_core::{Color, Square};

    use super::*;

    #[test]
    fn engine_finds_a_legal_move() {
        let position = Position::initial();
        let result = best_move(&position, 1).expect("move");
        assert!(position.legal_moves().contains(&result.best_move));
    }

    #[test]
    fn evaluation_prefers_extra_material() {
        let mut position = Position::empty(Color::White);
        position.set_piece(Color::White, Square::from_coords(0, 0).expect("square"));
        position.set_piece(Color::White, Square::from_coords(1, 0).expect("square"));
        position.set_piece(Color::White, Square::from_coords(2, 0).expect("square"));
        position.set_piece(Color::Black, Square::from_coords(7, 7).expect("square"));
        position.set_piece(Color::Black, Square::from_coords(6, 7).expect("square"));
        assert!(evaluate(&position) > 0);
    }
}
