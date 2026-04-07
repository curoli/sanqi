//! Text and SVG rendering for Sanqi positions.
//!
//! This crate provides lightweight rendering helpers for CLI tools, tests,
//! and applications which want a simple board visualization.
//!
//! ```
//! use sanqi_core::Position;
//!
//! let board = sanqi_render::ascii_board(&Position::initial());
//! assert!(board.contains("a b c d e f g h"));
//! ```

use std::fmt::Write;

use sanqi_core::{Color, Move, Pivot, Position, Square, BOARD_SIZE};

const TILE: i32 = 64;
const BOARD_PX: i32 = 8 * TILE;

/// Rendering options for SVG output.
#[derive(Clone, Debug, Default)]
pub struct RenderOptions {
    /// Optional move to highlight.
    pub highlight_move: Option<Move>,
    /// Optional pivots to draw as blue markers.
    pub pivots: Vec<Pivot>,
}

/// Piece style for ASCII board rendering.
#[derive(Clone, Copy, Debug, Default, PartialEq, Eq)]
pub enum TextPieceStyle {
    /// Render white and black pieces as `W` and `B`.
    Letters,
    /// Render white and black pieces as `●` and `○`.
    #[default]
    Discs,
}

/// Renders a position as an ASCII board using [`TextPieceStyle::Discs`].
pub fn ascii_board(position: &Position) -> String {
    ascii_board_with_style(position, TextPieceStyle::Discs)
}

/// Renders a position as an ASCII board with an explicit piece style.
pub fn ascii_board_with_style(position: &Position, style: TextPieceStyle) -> String {
    let mut out = String::new();
    let files = "  a b c d e f g h\n";
    out.push_str(files);
    for rank in (0..BOARD_SIZE).rev() {
        let _ = write!(out, "{} ", rank + 1);
        for file in 0..BOARD_SIZE {
            let square = Square::from_coords(file, rank).expect("board square");
            let symbol = piece_symbol(position.piece_at(square), style);
            let _ = write!(out, "{symbol} ");
        }
        let _ = writeln!(out, "{}", rank + 1);
    }
    out.push_str(files);
    out
}

/// Renders a position as plain SVG without highlights.
pub fn svg_board(position: &Position) -> String {
    svg_board_with_options(position, &RenderOptions::default())
}

/// Renders a position as SVG and highlights a move for the side to move.
pub fn svg_for_move(position: &Position, mv: Move) -> String {
    svg_for_move_for_color(position, position.side_to_move(), mv)
}

/// Renders a position as SVG and highlights a move for an explicit side.
///
/// Any pivots supporting the move for `color` are also marked automatically.
pub fn svg_for_move_for_color(position: &Position, color: Color, mv: Move) -> String {
    let pivots = position
        .supporting_pivots(color, mv)
        .into_iter()
        .map(|entry| entry.pivot)
        .collect();
    let options = RenderOptions {
        highlight_move: Some(mv),
        pivots,
    };
    svg_board_with_options(position, &options)
}

/// Renders a position as SVG with explicit rendering options.
pub fn svg_board_with_options(position: &Position, options: &RenderOptions) -> String {
    let mut svg = String::new();
    let _ = write!(
        svg,
        r#"<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 {BOARD_PX} {BOARD_PX}" width="{BOARD_PX}" height="{BOARD_PX}">"#
    );
    svg.push_str(r##"<rect width="100%" height="100%" fill="#f5e6c8"/>"##);
    render_squares(&mut svg);
    render_move_highlight(&mut svg, options.highlight_move);
    render_pivots(&mut svg, &options.pivots);
    render_pieces(&mut svg, position);
    svg.push_str("</svg>");
    svg
}

fn render_squares(svg: &mut String) {
    for rank in 0..BOARD_SIZE {
        for file in 0..BOARD_SIZE {
            let x = i32::from(file) * TILE;
            let y = i32::from(BOARD_SIZE - 1 - rank) * TILE;
            let dark = (file + rank) % 2 == 1;
            let fill = if dark { "#a06b3b" } else { "#f5e6c8" };
            let _ = write!(
                svg,
                r#"<rect x="{x}" y="{y}" width="{TILE}" height="{TILE}" fill="{fill}"/>"#
            );
        }
    }
}

fn render_move_highlight(svg: &mut String, highlight_move: Option<Move>) {
    let Some(mv) = highlight_move else {
        return;
    };

    let (from_x, from_y) = square_center(mv.from);
    let (to_x, to_y) = square_center(mv.to);
    let _ = write!(
        svg,
        r##"<line x1="{from_x}" y1="{from_y}" x2="{to_x}" y2="{to_y}" stroke="#d7263d" stroke-width="6" stroke-linecap="round" opacity="0.75"/>"##
    );
    for square in [mv.from, mv.to] {
        let (cx, cy) = square_center(square);
        let _ = write!(
            svg,
            r##"<circle cx="{cx}" cy="{cy}" r="26" fill="none" stroke="#d7263d" stroke-width="4"/>"##
        );
    }
}

fn render_pivots(svg: &mut String, pivots: &[Pivot]) {
    for pivot in pivots {
        let x = f64::from(pivot.file_twice()) * f64::from(TILE) / 2.0 + f64::from(TILE) / 2.0;
        let y = f64::from(2 * (BOARD_SIZE - 1) - pivot.rank_twice()) * f64::from(TILE) / 2.0
            + f64::from(TILE) / 2.0;
        let _ = write!(
            svg,
            r##"<circle cx="{x:.1}" cy="{y:.1}" r="8" fill="#118ab2" opacity="0.9"/>"##
        );
    }
}

fn render_pieces(svg: &mut String, position: &Position) {
    for rank in 0..BOARD_SIZE {
        for file in 0..BOARD_SIZE {
            let square = Square::from_coords(file, rank).expect("board square");
            if let Some(color) = position.piece_at(square) {
                let (cx, cy) = square_center(square);
                let fill = match color {
                    Color::White => "#fffdf7",
                    Color::Black => "#1f1f1f",
                };
                let stroke = match color {
                    Color::White => "#56452f",
                    Color::Black => "#f2eadb",
                };
                let _ = write!(
                    svg,
                    r#"<circle cx="{cx}" cy="{cy}" r="20" fill="{fill}" stroke="{stroke}" stroke-width="3"/>"#
                );
            }
        }
    }
}

fn piece_symbol(piece: Option<Color>, style: TextPieceStyle) -> char {
    match (piece, style) {
        (Some(Color::White), TextPieceStyle::Letters) => 'W',
        (Some(Color::Black), TextPieceStyle::Letters) => 'B',
        (Some(Color::White), TextPieceStyle::Discs) => '●',
        (Some(Color::Black), TextPieceStyle::Discs) => '○',
        (None, _) => '.',
    }
}

fn square_center(square: Square) -> (i32, i32) {
    let x = i32::from(square.file()) * TILE + TILE / 2;
    let y = i32::from(BOARD_SIZE - 1 - square.rank()) * TILE + TILE / 2;
    (x, y)
}

#[cfg(test)]
mod tests {
    use sanqi_core::SupportPair;

    use super::*;

    #[test]
    fn ascii_board_contains_coordinates() {
        let board = ascii_board(&Position::initial());
        assert!(board.starts_with("  a b c d e f g h\n"));
        assert!(board.contains("8 ○ ○ ○"));
        assert!(board.contains("8\n"));
        assert!(board.ends_with("  a b c d e f g h\n"));
    }

    #[test]
    fn ascii_board_can_use_letter_style() {
        let board = ascii_board_with_style(&Position::initial(), TextPieceStyle::Letters);
        assert!(board.contains("8 B B B"));
        assert!(board.contains("1 W W W"));
    }

    #[test]
    fn svg_board_contains_svg_root() {
        let svg = svg_board(&Position::initial());
        assert!(svg.starts_with("<svg"));
        assert!(svg.contains("<circle"));
    }

    #[test]
    fn svg_board_can_highlight_move_and_pivots() {
        let position = Position::initial();
        let options = RenderOptions {
            highlight_move: Some("a1-b3".parse().expect("move")),
            pivots: vec![SupportPair::new(
                "a2".parse().expect("square"),
                "b2".parse().expect("square"),
            )
            .pivot()],
        };

        let svg = svg_board_with_options(&position, &options);
        assert!(svg.contains("stroke=\"#d7263d\""));
        assert!(svg.contains("fill=\"#118ab2\""));
    }

    #[test]
    fn svg_for_move_resolves_pivots_automatically() {
        let position = Position::initial();
        let svg = svg_for_move(&position, "a1-b3".parse().expect("move"));
        assert!(svg.contains("stroke=\"#d7263d\""));
        assert!(svg.contains("fill=\"#118ab2\""));
    }
}
