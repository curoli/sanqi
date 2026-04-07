//! Search and evaluation for Sanqi.
//!
//! This crate builds on `sanqi-core` and provides a static evaluator, fixed
//! depth search, iterative deepening with a time budget, and detailed search
//! statistics.
//!
//! ```
//! use sanqi_core::Position;
//!
//! let position = Position::initial();
//! let result = sanqi_engine::best_move(&position, 2).expect("legal move");
//! assert!(position.legal_moves().contains(&result.best_move));
//! ```

use std::time::{Duration, Instant};

use sanqi_core::{Move, Outcome, Position};

/// Score assigned to positions where the side to move has already lost.
pub const WIN_SCORE: i32 = 100_000;
const TT_BUCKETS: usize = 1 << 14;
const TT_BUCKET_SIZE: usize = 4;
const MAX_QUIESCENCE_DEPTH: u8 = 4;
const MAX_QUIESCENCE_MOVES: usize = 4;
const QUIESCENCE_DELTA_MARGIN: i32 = 80;

/// Result of a completed search.
#[derive(Clone, Debug, PartialEq, Eq)]
pub struct SearchResult {
    /// Best move found by the search.
    pub best_move: Move,
    /// Evaluation score from the perspective of the side to move.
    pub score: i32,
    /// Search depth that produced this result.
    pub depth: u8,
    /// Principal variation starting with `best_move`.
    pub principal_variation: Vec<Move>,
}

/// Timing information for one completed iterative-deepening iteration.
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub struct DepthTiming {
    /// Search depth for this iteration.
    pub depth: u8,
    /// Wall-clock time spent in this iteration.
    pub elapsed: Duration,
    /// Number of root moves finished at this depth.
    pub completed_root_moves: usize,
}

/// Search diagnostics collected during one engine run.
#[derive(Clone, Debug, Default, PartialEq, Eq)]
pub struct SearchStats {
    /// Number of normal search nodes visited.
    pub nodes: u64,
    /// Number of quiescence nodes visited.
    pub quiescence_nodes: u64,
    /// Number of quiescence moves skipped by pruning.
    pub quiescence_pruned_moves: u64,
    /// Number of static evaluations performed.
    pub evaluation_calls: u64,
    /// Number of move-generation calls performed.
    pub legal_move_generations: u64,
    /// Total wall-clock time spent in the search.
    pub total_time: Duration,
    /// Time spent specifically inside quiescence search.
    pub quiescence_time: Duration,
    /// Per-depth timing information for iterative deepening.
    pub depth_timings: Vec<DepthTiming>,
    /// Deepest fully completed iteration.
    pub completed_depth: u8,
    /// Whether the search stopped because the deadline was reached.
    pub timed_out: bool,
    /// Number of legal moves at the root position.
    pub root_legal_moves: usize,
    /// Total number of root moves completed across all iterations.
    pub completed_root_moves_total: usize,
    /// Number of root moves completed in the last attempted depth.
    pub completed_root_moves_current_depth: usize,
}

/// Search result together with diagnostics.
#[derive(Clone, Debug, PartialEq, Eq)]
pub struct AnalysisResult {
    /// Best search result, if at least one legal move exists.
    pub best: Option<SearchResult>,
    /// Collected diagnostics for the search run.
    pub stats: SearchStats,
}

#[derive(Clone, Copy, Debug, PartialEq, Eq)]
enum Bound {
    Exact,
    Lower,
    Upper,
}

#[derive(Clone, Copy, Debug, PartialEq, Eq)]
struct TableEntry {
    key: u64,
    depth: u8,
    score: i32,
    bound: Bound,
    best_move: Option<Move>,
}

#[derive(Clone, Debug)]
struct TranspositionTable {
    buckets: Vec<[Option<TableEntry>; TT_BUCKET_SIZE]>,
}

impl TranspositionTable {
    fn new(bucket_count: usize) -> Self {
        Self {
            buckets: vec![[None; TT_BUCKET_SIZE]; bucket_count.max(1)],
        }
    }

    fn get(&self, position: &Position) -> Option<TableEntry> {
        let key = position_key(position);
        let bucket = &self.buckets[self.index_for(key)];
        bucket
            .iter()
            .flatten()
            .find(|entry| entry.key == key)
            .copied()
    }

    fn insert(&mut self, position: &Position, entry: TableEntry) {
        let key = position_key(position);
        let index = self.index_for(key);
        let bucket = &mut self.buckets[index];
        let new_entry = TableEntry { key, ..entry };

        if let Some(slot) = bucket
            .iter_mut()
            .find(|slot| slot.is_some_and(|existing| existing.key == key))
        {
            if slot.is_some_and(|existing| existing.depth > new_entry.depth) {
                return;
            }
            *slot = Some(new_entry);
            return;
        }

        if let Some(slot) = bucket.iter_mut().find(|slot| slot.is_none()) {
            *slot = Some(new_entry);
            return;
        }

        let replace_index = bucket
            .iter()
            .enumerate()
            .min_by_key(|(_, slot)| slot.expect("full bucket").depth)
            .map(|(index, _)| index)
            .expect("bucket has slots");

        if bucket[replace_index].is_some_and(|existing| existing.depth > new_entry.depth) {
            return;
        }

        bucket[replace_index] = Some(new_entry);
    }

    fn index_for(&self, key: u64) -> usize {
        (key as usize) % self.buckets.len()
    }
}

impl Default for TranspositionTable {
    fn default() -> Self {
        Self::new(TT_BUCKETS)
    }
}

/// Returns a static evaluation of a position.
///
/// Positive scores favor the side to move and negative scores favor the
/// opponent.
pub fn evaluate(position: &Position) -> i32 {
    evaluate_impl(position, None)
}

fn evaluate_with_stats(position: &Position, stats: &mut SearchStats) -> i32 {
    evaluate_impl(position, Some(stats))
}

fn evaluate_impl(position: &Position, stats: Option<&mut SearchStats>) -> i32 {
    let mut stats = stats;
    if let Some(stats) = stats.as_deref_mut() {
        stats.evaluation_calls += 1;
    }
    if let Some(Outcome::Winner(_)) = position.outcome() {
        return -WIN_SCORE;
    }

    let side = position.side_to_move();
    let opponent = side.opponent();
    let side_pieces = position.squares_of(side);
    let opponent_pieces = position.squares_of(opponent);
    let material = side_pieces.len() as i32 - opponent_pieces.len() as i32;
    let side_moves = legal_moves_for_eval(position, stats.as_deref_mut());
    let mobility = side_moves.len() as i32;
    let capture_pressure = capture_count_from_moves(position, &side_moves) as i32;
    let centrality = side_pieces
        .iter()
        .map(|square| square_centrality(*square))
        .sum::<i32>();
    let blocked = blocked_piece_count_from_moves(&side_pieces, &side_moves) as i32;

    let mut flipped = position.clone();
    flipped.apply_null_turn();
    let opponent_moves = legal_moves_for_eval(&flipped, stats);
    let opponent_mobility = opponent_moves.len() as i32;
    let opponent_capture_pressure = capture_count_from_moves(&flipped, &opponent_moves) as i32;
    let opponent_centrality = opponent_pieces
        .iter()
        .map(|square| square_centrality(*square))
        .sum::<i32>();
    let opponent_blocked = blocked_piece_count_from_moves(&opponent_pieces, &opponent_moves) as i32;

    material * 120
        + (mobility - opponent_mobility) * 12
        + (capture_pressure - opponent_capture_pressure) * 35
        + (centrality - opponent_centrality) * 3
        + (opponent_blocked - blocked) * 8
}

/// Searches to a fixed depth and returns the best move, if any exists.
pub fn best_move(position: &Position, depth: u8) -> Option<SearchResult> {
    analyze(position, depth, None).best
}

fn best_move_with_table(
    position: &Position,
    depth: u8,
    table: &mut TranspositionTable,
    deadline: Option<Instant>,
    stats: &mut SearchStats,
) -> Option<SearchResult> {
    if search_expired(deadline) {
        return None;
    }
    let tt_move = table.get(position).and_then(|entry| entry.best_move);
    let moves = ordered_moves(position, tt_move, stats);
    if moves.is_empty() {
        return None;
    }

    let mut best: Option<SearchResult> = None;
    let mut alpha = -WIN_SCORE - 1;
    let beta = WIN_SCORE + 1;
    let root_moves_before = stats.completed_root_moves_total;
    let root_moves_start = stats.completed_root_moves_total;

    for mv in moves {
        if search_expired(deadline) {
            stats.timed_out = true;
            stats.completed_root_moves_current_depth = stats
                .completed_root_moves_total
                .saturating_sub(root_moves_start);
            return finalize_root_result(position, depth, table, best);
        }
        let mut next = position.clone();
        next.apply_move(mv).ok()?;
        let Some(score) = negamax(
            &next,
            depth.saturating_sub(1),
            -beta,
            -alpha,
            table,
            deadline,
            stats,
        ) else {
            stats.timed_out = true;
            stats.completed_root_moves_current_depth = stats
                .completed_root_moves_total
                .saturating_sub(root_moves_start);
            return finalize_root_result(position, depth, table, best);
        };
        let score = -score;
        stats.completed_root_moves_total += 1;
        if score > alpha {
            alpha = score;
            best = Some(SearchResult {
                best_move: mv,
                score,
                depth,
                principal_variation: Vec::new(),
            });
        }
    }

    if best.is_some() {
        stats.completed_root_moves_current_depth = stats
            .completed_root_moves_total
            .saturating_sub(root_moves_start);
        finalize_root_result(position, depth, table, best)
    } else {
        stats.completed_root_moves_total = root_moves_before;
        stats.completed_root_moves_current_depth = 0;
        None
    }
}

fn finalize_root_result(
    position: &Position,
    depth: u8,
    table: &mut TranspositionTable,
    best: Option<SearchResult>,
) -> Option<SearchResult> {
    let mut result = best?;
    table.insert(
        position,
        TableEntry {
            key: 0,
            depth,
            score: result.score,
            bound: Bound::Exact,
            best_move: Some(result.best_move),
        },
    );
    result.principal_variation = build_principal_variation(position, depth, table);
    if result.principal_variation.is_empty() {
        result.principal_variation.push(result.best_move);
    }
    Some(result)
}

/// Searches with iterative deepening up to `max_depth` and stops when the
/// given time budget expires.
pub fn best_move_iterative(
    position: &Position,
    max_depth: u8,
    time_budget: Duration,
) -> Option<SearchResult> {
    analyze(position, max_depth, Some(time_budget)).best
}

/// Returns a fixed-depth analysis together with search statistics.
pub fn analyze_fixed_depth(position: &Position, depth: u8) -> AnalysisResult {
    analyze(position, depth, None)
}

/// Returns an iterative-deepening analysis together with search statistics.
pub fn analyze_iterative(
    position: &Position,
    max_depth: u8,
    time_budget: Duration,
) -> AnalysisResult {
    analyze(position, max_depth, Some(time_budget))
}

fn analyze(position: &Position, max_depth: u8, time_budget: Option<Duration>) -> AnalysisResult {
    let search_started = Instant::now();
    let deadline = time_budget.and_then(|budget| Instant::now().checked_add(budget));
    let mut table = TranspositionTable::default();
    let mut best = None;
    let mut stats = SearchStats::default();
    let root_moves = legal_moves_counted(position, &mut stats);
    let legal_moves_exist = !root_moves.is_empty();
    stats.root_legal_moves = root_moves.len();

    if time_budget.is_some() {
        for depth in 1..=max_depth {
            let depth_started = Instant::now();
            let Some(result) =
                best_move_with_table(position, depth, &mut table, deadline, &mut stats)
            else {
                stats.depth_timings.push(DepthTiming {
                    depth,
                    elapsed: depth_started.elapsed(),
                    completed_root_moves: stats.completed_root_moves_current_depth,
                });
                stats.timed_out = search_expired(deadline);
                stats.total_time = search_started.elapsed();
                break;
            };
            stats.depth_timings.push(DepthTiming {
                depth,
                elapsed: depth_started.elapsed(),
                completed_root_moves: stats.completed_root_moves_current_depth,
            });
            stats.completed_depth = depth;
            best = Some(result);
            if search_expired(deadline) {
                stats.timed_out = true;
                stats.total_time = search_started.elapsed();
                break;
            }
        }
    } else {
        let depth_started = Instant::now();
        best = best_move_with_table(position, max_depth, &mut table, None, &mut stats);
        stats.depth_timings.push(DepthTiming {
            depth: max_depth,
            elapsed: depth_started.elapsed(),
            completed_root_moves: stats.completed_root_moves_current_depth,
        });
        if best.is_some() {
            stats.completed_depth = max_depth;
        }
    }

    if best.is_none() && legal_moves_exist {
        let fallback = cheap_fallback(position, &table);
        stats.total_time = search_started.elapsed();
        return AnalysisResult {
            best: fallback,
            stats,
        };
    }

    stats.total_time = search_started.elapsed();
    AnalysisResult { best, stats }
}

fn cheap_fallback(position: &Position, table: &TranspositionTable) -> Option<SearchResult> {
    let tt_move = table.get(position).and_then(|entry| entry.best_move);
    let mut stats = SearchStats::default();
    let mv = ordered_moves(position, tt_move, &mut stats)
        .into_iter()
        .next()?;
    Some(SearchResult {
        best_move: mv,
        score: evaluate(position),
        depth: 0,
        principal_variation: vec![mv],
    })
}

fn negamax(
    position: &Position,
    depth: u8,
    mut alpha: i32,
    mut beta: i32,
    table: &mut TranspositionTable,
    deadline: Option<Instant>,
    stats: &mut SearchStats,
) -> Option<i32> {
    stats.nodes += 1;
    if search_expired(deadline) {
        return None;
    }
    if position.outcome().is_some() {
        return Some(evaluate_with_stats(position, stats));
    }
    if depth == 0 {
        return quiescence(position, alpha, beta, 0, table, deadline, stats);
    }

    let original_alpha = alpha;
    let original_beta = beta;

    if let Some(entry) = table.get(position)
        && entry.depth >= depth
    {
        match entry.bound {
            Bound::Exact => return Some(entry.score),
            Bound::Lower => alpha = alpha.max(entry.score),
            Bound::Upper => beta = beta.min(entry.score),
        }
        if alpha >= beta {
            return Some(entry.score);
        }
    }

    let tt_move = table.get(position).and_then(|entry| entry.best_move);
    let moves = ordered_moves(position, tt_move, stats);

    let mut best_score = -WIN_SCORE - 1;
    let mut best_move = None;
    for mv in moves {
        if search_expired(deadline) {
            return None;
        }
        let mut next = position.clone();
        if next.apply_move(mv).is_err() {
            continue;
        }
        let score = -negamax(&next, depth - 1, -beta, -alpha, table, deadline, stats)?;
        if score > best_score {
            best_score = score;
            best_move = Some(mv);
        }
        if score > alpha {
            alpha = score;
        }
        if alpha >= beta {
            break;
        }
    }

    let bound = if best_score <= original_alpha {
        Bound::Upper
    } else if best_score >= original_beta {
        Bound::Lower
    } else {
        Bound::Exact
    };

    table.insert(
        position,
        TableEntry {
            key: 0,
            depth,
            score: best_score,
            bound,
            best_move,
        },
    );

    Some(best_score)
}

fn quiescence(
    position: &Position,
    mut alpha: i32,
    mut beta: i32,
    depth: u8,
    table: &mut TranspositionTable,
    deadline: Option<Instant>,
    stats: &mut SearchStats,
) -> Option<i32> {
    let started = Instant::now();
    stats.quiescence_nodes += 1;
    if search_expired(deadline) {
        stats.quiescence_time += started.elapsed();
        return None;
    }

    let original_alpha = alpha;
    let original_beta = beta;

    if let Some(entry) = table.get(position)
        && entry.depth == 0
    {
        match entry.bound {
            Bound::Exact => {
                stats.quiescence_time += started.elapsed();
                return Some(entry.score);
            }
            Bound::Lower => alpha = alpha.max(entry.score),
            Bound::Upper => beta = beta.min(entry.score),
        }
        if alpha >= beta {
            stats.quiescence_time += started.elapsed();
            return Some(entry.score);
        }
    }

    let stand_pat = evaluate_with_stats(position, stats);
    if depth >= MAX_QUIESCENCE_DEPTH {
        table.insert(
            position,
            TableEntry {
                key: 0,
                depth: 0,
                score: stand_pat,
                bound: Bound::Exact,
                best_move: None,
            },
        );
        stats.quiescence_time += started.elapsed();
        return Some(stand_pat);
    }
    if stand_pat >= beta {
        table.insert(
            position,
            TableEntry {
                key: 0,
                depth: 0,
                score: beta,
                bound: Bound::Lower,
                best_move: None,
            },
        );
        stats.quiescence_time += started.elapsed();
        return Some(beta);
    }
    if stand_pat > alpha {
        alpha = stand_pat;
    }

    let tt_move = table.get(position).and_then(|entry| entry.best_move);
    let mut best_move = None;
    for mv in capture_moves(position, tt_move, stats) {
        if search_expired(deadline) {
            stats.quiescence_time += started.elapsed();
            return None;
        }
        if stand_pat + quiescence_capture_delta(position, mv) <= alpha {
            stats.quiescence_pruned_moves += 1;
            continue;
        }
        let mut next = position.clone();
        if next.apply_move(mv).is_err() {
            continue;
        }
        let score = -quiescence(&next, -beta, -alpha, depth + 1, table, deadline, stats)?;
        if score >= beta {
            table.insert(
                position,
                TableEntry {
                    key: 0,
                    depth: 0,
                    score: beta,
                    bound: Bound::Lower,
                    best_move: Some(mv),
                },
            );
            stats.quiescence_time += started.elapsed();
            return Some(beta);
        }
        if score > alpha {
            alpha = score;
            best_move = Some(mv);
        }
    }

    let bound = if alpha <= original_alpha {
        Bound::Upper
    } else if alpha >= original_beta {
        Bound::Lower
    } else {
        Bound::Exact
    };
    table.insert(
        position,
        TableEntry {
            key: 0,
            depth: 0,
            score: alpha,
            bound,
            best_move,
        },
    );
    stats.quiescence_time += started.elapsed();
    Some(alpha)
}

fn ordered_moves(position: &Position, tt_move: Option<Move>, stats: &mut SearchStats) -> Vec<Move> {
    let mut moves = legal_moves_counted(position, stats);
    moves.sort_by_key(|mv| move_ordering_score(position, *mv, tt_move));
    moves.reverse();
    moves
}

fn capture_moves(position: &Position, tt_move: Option<Move>, stats: &mut SearchStats) -> Vec<Move> {
    let mut moves = direct_capture_moves_counted(position, stats);
    moves.sort_by_key(|mv| move_ordering_score(position, *mv, tt_move));
    moves.reverse();
    if moves.len() > MAX_QUIESCENCE_MOVES {
        moves.truncate(MAX_QUIESCENCE_MOVES);
    }
    moves
}

fn move_ordering_score(position: &Position, mv: Move, tt_move: Option<Move>) -> i32 {
    let mut score = 0;

    if Some(mv) == tt_move {
        score += 1_000_000;
    }
    if position.piece_at(mv.to).is_some() {
        score += 100_000;
    }

    let from_file = i32::from(mv.from.file());
    let from_rank = i32::from(mv.from.rank());
    let to_file = i32::from(mv.to.file());
    let to_rank = i32::from(mv.to.rank());

    let distance = (to_file - from_file).abs() + (to_rank - from_rank).abs();
    score += distance * 100;

    let center_bias = square_centrality(mv.to) - square_centrality(mv.from);
    score += center_bias * 10;

    score
}

fn quiescence_capture_delta(position: &Position, mv: Move) -> i32 {
    let center_gain = square_centrality(mv.to) - square_centrality(mv.from);
    let capture_bonus = if position.piece_at(mv.to).is_some() {
        120
    } else {
        0
    };
    capture_bonus + center_gain * 3 + QUIESCENCE_DELTA_MARGIN
}

fn square_centrality(square: sanqi_core::Square) -> i32 {
    let center_file_distance = (2 * i32::from(square.file()) - 7).abs();
    let center_rank_distance = (2 * i32::from(square.rank()) - 7).abs();
    -(center_file_distance + center_rank_distance)
}

fn legal_moves_counted(position: &Position, stats: &mut SearchStats) -> Vec<Move> {
    stats.legal_move_generations += 1;
    position.legal_moves()
}

fn direct_capture_moves_counted(position: &Position, stats: &mut SearchStats) -> Vec<Move> {
    stats.legal_move_generations += 1;
    let color = position.side_to_move();
    let own_occupancy = position.occupancy_of(color);
    let opponent_occupancy = position.occupancy_of(color.opponent());
    let pieces = position.squares_of(color);
    let mut seen = [false; sanqi_core::BOARD_SQUARES * sanqi_core::BOARD_SQUARES];
    let mut moves = Vec::new();

    for i in 0..pieces.len() {
        for j in (i + 1)..pieces.len() {
            let pivot = sanqi_core::SupportPair::new(pieces[i], pieces[j]).pivot();
            for attacker in &pieces {
                if let Some(to) = pivot.reflect(*attacker) {
                    let target_mask = 1_u64 << to.index();
                    if to == *attacker
                        || own_occupancy & target_mask != 0
                        || opponent_occupancy & target_mask == 0
                    {
                        continue;
                    }
                    let mv = Move::new(*attacker, to);
                    let slot = mv.from.index() as usize * sanqi_core::BOARD_SQUARES
                        + mv.to.index() as usize;
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

fn legal_moves_for_eval(position: &Position, stats: Option<&mut SearchStats>) -> Vec<Move> {
    if let Some(stats) = stats {
        legal_moves_counted(position, stats)
    } else {
        position.legal_moves()
    }
}

fn capture_count_from_moves(position: &Position, moves: &[Move]) -> usize {
    let opponent = position.side_to_move().opponent();
    moves
        .iter()
        .filter(|mv| position.has_piece(opponent, mv.to))
        .count()
}

fn blocked_piece_count_from_moves(pieces: &[sanqi_core::Square], moves: &[Move]) -> usize {
    pieces
        .iter()
        .filter(|square| !moves.iter().any(|mv| mv.from == **square))
        .count()
}

fn position_key(position: &Position) -> u64 {
    position.zobrist_key()
}

fn build_principal_variation(
    position: &Position,
    max_depth: u8,
    table: &TranspositionTable,
) -> Vec<Move> {
    let mut pv = Vec::new();
    let mut current = position.clone();

    for _ in 0..max_depth {
        let Some(entry) = table.get(&current) else {
            break;
        };
        let Some(mv) = entry.best_move else {
            break;
        };
        if current.apply_move(mv).is_err() {
            break;
        }
        pv.push(mv);
    }

    pv
}

fn search_expired(deadline: Option<Instant>) -> bool {
    deadline.is_some_and(|deadline| Instant::now() >= deadline)
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
        assert_eq!(
            result.principal_variation.first().copied(),
            Some(result.best_move)
        );
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

    #[test]
    fn evaluation_prefers_capture_pressure() {
        let mut attacking = Position::empty(Color::White);
        attacking.set_piece(Color::White, Square::from_coords(0, 0).expect("square"));
        attacking.set_piece(Color::White, Square::from_coords(0, 1).expect("square"));
        attacking.set_piece(Color::White, Square::from_coords(1, 1).expect("square"));
        attacking.set_piece(Color::Black, Square::from_coords(1, 2).expect("square"));
        attacking.set_piece(Color::Black, Square::from_coords(7, 7).expect("square"));

        let mut quiet = Position::empty(Color::White);
        quiet.set_piece(Color::White, Square::from_coords(0, 0).expect("square"));
        quiet.set_piece(Color::White, Square::from_coords(0, 1).expect("square"));
        quiet.set_piece(Color::White, Square::from_coords(1, 1).expect("square"));
        quiet.set_piece(Color::Black, Square::from_coords(7, 7).expect("square"));
        quiet.set_piece(Color::Black, Square::from_coords(6, 7).expect("square"));

        assert!(evaluate(&attacking) > evaluate(&quiet));
    }

    #[test]
    fn evaluation_prefers_centralized_pieces() {
        let mut centered = Position::empty(Color::White);
        centered.set_piece(Color::White, Square::from_coords(3, 3).expect("square"));
        centered.set_piece(Color::White, Square::from_coords(3, 4).expect("square"));
        centered.set_piece(Color::White, Square::from_coords(4, 3).expect("square"));
        centered.set_piece(Color::Black, Square::from_coords(7, 7).expect("square"));
        centered.set_piece(Color::Black, Square::from_coords(7, 6).expect("square"));
        centered.set_piece(Color::Black, Square::from_coords(6, 7).expect("square"));

        let mut rim = Position::empty(Color::White);
        rim.set_piece(Color::White, Square::from_coords(0, 0).expect("square"));
        rim.set_piece(Color::White, Square::from_coords(0, 1).expect("square"));
        rim.set_piece(Color::White, Square::from_coords(1, 0).expect("square"));
        rim.set_piece(Color::Black, Square::from_coords(7, 7).expect("square"));
        rim.set_piece(Color::Black, Square::from_coords(7, 6).expect("square"));
        rim.set_piece(Color::Black, Square::from_coords(6, 7).expect("square"));

        assert!(evaluate(&centered) > evaluate(&rim));
    }

    #[test]
    fn identical_positions_have_identical_keys() {
        let left = Position::initial();
        let right = Position::initial();
        assert_eq!(position_key(&left), position_key(&right));
    }

    #[test]
    fn different_side_to_move_changes_key() {
        let left = Position::initial();
        let mut right = Position::initial();
        right.set_side_to_move(Color::Black);
        assert_ne!(position_key(&left), position_key(&right));
    }

    #[test]
    fn different_piece_placement_changes_key() {
        let left = Position::initial();
        let mut right = Position::initial();
        right.clear_square("a1".parse().expect("square"));
        right.set_piece(Color::White, "a3".parse().expect("square"));
        assert_ne!(position_key(&left), position_key(&right));
    }

    #[test]
    fn position_key_is_stable_through_apply_and_undo() {
        let mut position = Position::initial();
        let original = position_key(&position);
        let mv: Move = "a1-b3".parse().expect("move");
        let undo = position.apply_move(mv).expect("apply");
        assert_ne!(position_key(&position), original);
        position.undo_move(mv, undo).expect("undo");
        assert_eq!(position_key(&position), original);
    }

    #[test]
    fn transposition_table_stores_root_result() {
        let position = Position::initial();
        let mut table = TranspositionTable::default();
        let mut stats = SearchStats::default();
        let result =
            best_move_with_table(&position, 2, &mut table, None, &mut stats).expect("move");
        let entry = table.get(&position).expect("table entry");
        assert_eq!(entry.depth, 2);
        assert_eq!(entry.best_move, Some(result.best_move));
    }

    #[test]
    fn move_ordering_prefers_captures() {
        let mut position = Position::empty(Color::White);
        position.set_piece(Color::White, Square::from_coords(0, 0).expect("square"));
        position.set_piece(Color::White, Square::from_coords(0, 1).expect("square"));
        position.set_piece(Color::White, Square::from_coords(1, 1).expect("square"));
        position.set_piece(Color::Black, Square::from_coords(1, 2).expect("square"));
        position.set_piece(Color::Black, Square::from_coords(7, 7).expect("square"));
        position.set_side_to_move(Color::White);

        let mut stats = SearchStats::default();
        let moves = ordered_moves(&position, None, &mut stats);
        assert_eq!(moves.first().copied(), Some("a1-b3".parse().expect("move")));
    }

    #[test]
    fn move_ordering_prefers_tt_move() {
        let position = Position::initial();
        let candidate: Move = "a1-b3".parse().expect("move");
        let mut stats = SearchStats::default();
        let moves = ordered_moves(&position, Some(candidate), &mut stats);
        assert_eq!(moves.first().copied(), Some(candidate));
    }

    #[test]
    fn iterative_search_returns_legal_move() {
        let position = Position::initial();
        let result = best_move_iterative(&position, 3, Duration::from_millis(50)).expect("move");
        assert!(position.legal_moves().contains(&result.best_move));
        assert!(result.depth >= 1);
        if let Some(first) = result.principal_variation.first().copied() {
            assert_eq!(first, result.best_move);
        }
    }

    #[test]
    fn analysis_reports_root_move_count_and_nodes() {
        let position = Position::initial();
        let analysis = analyze_iterative(&position, 2, Duration::from_millis(20));
        assert_eq!(
            analysis.stats.root_legal_moves,
            position.legal_moves().len()
        );
        assert!(analysis.stats.nodes > 0 || analysis.stats.timed_out);
        assert!(analysis.stats.legal_move_generations > 0);
        assert!(analysis.stats.evaluation_calls > 0 || analysis.stats.timed_out);
    }

    #[test]
    fn iterative_analysis_returns_fallback_move_on_immediate_timeout() {
        let position = Position::initial();
        let analysis = analyze_iterative(&position, 4, Duration::from_millis(0));
        assert!(analysis.best.is_some());
        let best = analysis.best.expect("fallback");
        assert!(position.legal_moves().contains(&best.best_move));
    }

    #[test]
    fn partial_root_progress_is_preserved_on_timeout() {
        let position = Position::initial();
        let analysis = analyze_iterative(&position, 1, Duration::from_millis(1));
        assert!(analysis.best.is_some());
        assert!(
            analysis.stats.completed_root_moves_current_depth <= analysis.stats.root_legal_moves
        );
        assert!(
            analysis.stats.completed_root_moves_total
                >= analysis.stats.completed_root_moves_current_depth
        );
    }

    #[test]
    fn quiescence_depth_is_bounded() {
        let mut position = Position::empty(Color::White);
        position.set_piece(Color::White, Square::from_coords(0, 0).expect("square"));
        position.set_piece(Color::White, Square::from_coords(0, 1).expect("square"));
        position.set_piece(Color::White, Square::from_coords(1, 1).expect("square"));
        position.set_piece(Color::Black, Square::from_coords(1, 2).expect("square"));
        position.set_piece(Color::Black, Square::from_coords(1, 4).expect("square"));
        position.set_piece(Color::Black, Square::from_coords(0, 4).expect("square"));

        let mut stats = SearchStats::default();
        let mut table = TranspositionTable::default();
        let _ = quiescence(
            &position,
            -WIN_SCORE - 1,
            WIN_SCORE + 1,
            0,
            &mut table,
            None,
            &mut stats,
        )
        .expect("quiescence");
        assert!(stats.quiescence_nodes > 0);
        assert!(stats.quiescence_nodes < 10_000);
    }

    #[test]
    fn quiescence_move_count_is_bounded() {
        let mut position = Position::empty(Color::White);
        position.set_piece(Color::White, Square::from_coords(3, 3).expect("square"));
        position.set_piece(Color::White, Square::from_coords(2, 2).expect("square"));
        position.set_piece(Color::White, Square::from_coords(4, 2).expect("square"));
        position.set_piece(Color::White, Square::from_coords(2, 4).expect("square"));
        position.set_piece(Color::White, Square::from_coords(4, 4).expect("square"));
        position.set_piece(Color::Black, Square::from_coords(1, 1).expect("square"));
        position.set_piece(Color::Black, Square::from_coords(5, 1).expect("square"));
        position.set_piece(Color::Black, Square::from_coords(1, 5).expect("square"));
        position.set_piece(Color::Black, Square::from_coords(5, 5).expect("square"));
        position.set_piece(Color::Black, Square::from_coords(3, 1).expect("square"));

        let mut stats = SearchStats::default();
        assert!(capture_moves(&position, None, &mut stats).len() <= MAX_QUIESCENCE_MOVES);
    }

    #[test]
    fn tt_keeps_deeper_entry_for_same_key() {
        let position = Position::initial();
        let mut table = TranspositionTable::new(1);
        table.insert(
            &position,
            TableEntry {
                key: 0,
                depth: 4,
                score: 10,
                bound: Bound::Exact,
                best_move: None,
            },
        );
        table.insert(
            &position,
            TableEntry {
                key: 0,
                depth: 2,
                score: 99,
                bound: Bound::Exact,
                best_move: None,
            },
        );

        let entry = table.get(&position).expect("entry");
        assert_eq!(entry.depth, 4);
        assert_eq!(entry.score, 10);
    }

    #[test]
    fn tt_bucket_can_hold_multiple_colliding_positions() {
        let first = Position::initial();
        let mut second = Position::initial();
        second.clear_square("a1".parse().expect("square"));
        second.set_piece(Color::White, "a3".parse().expect("square"));

        let mut table = TranspositionTable::new(1);
        table.insert(
            &first,
            TableEntry {
                key: 0,
                depth: 3,
                score: 11,
                bound: Bound::Exact,
                best_move: None,
            },
        );
        table.insert(
            &second,
            TableEntry {
                key: 0,
                depth: 2,
                score: 22,
                bound: Bound::Exact,
                best_move: None,
            },
        );

        assert_eq!(table.get(&first).expect("first").score, 11);
        assert_eq!(table.get(&second).expect("second").score, 22);
    }

    #[test]
    fn quiescence_search_follows_capture_sequence() {
        let mut position = Position::empty(Color::White);
        position.set_piece(Color::White, Square::from_coords(0, 0).expect("square"));
        position.set_piece(Color::White, Square::from_coords(0, 1).expect("square"));
        position.set_piece(Color::White, Square::from_coords(1, 1).expect("square"));
        position.set_piece(Color::Black, Square::from_coords(1, 2).expect("square"));
        position.set_piece(Color::Black, Square::from_coords(1, 4).expect("square"));
        position.set_piece(Color::Black, Square::from_coords(0, 4).expect("square"));

        let static_eval = evaluate(&position);
        let mut stats = SearchStats::default();
        let mut table = TranspositionTable::default();
        let quiet_eval = quiescence(
            &position,
            -WIN_SCORE - 1,
            WIN_SCORE + 1,
            0,
            &mut table,
            None,
            &mut stats,
        )
        .expect("quiescence");
        assert!(quiet_eval != static_eval);
    }
}
