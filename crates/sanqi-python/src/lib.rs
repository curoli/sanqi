use std::str::FromStr;

use pyo3::exceptions::PyValueError;
use pyo3::prelude::*;
use pyo3::types::PyDict;
use sanqi_core::{Color, Move, Position};
use sanqi_render::TextPieceStyle;

fn parse_color(value: &str) -> PyResult<Color> {
    match value.to_ascii_lowercase().as_str() {
        "white" | "w" => Ok(Color::White),
        "black" | "b" => Ok(Color::Black),
        _ => Err(PyValueError::new_err("color must be 'white' or 'black'")),
    }
}

fn parse_move(value: &str) -> PyResult<Move> {
    Move::from_str(value).map_err(|error| PyValueError::new_err(error.to_string()))
}

fn parse_square(value: &str) -> PyResult<sanqi_core::Square> {
    sanqi_core::Square::from_str(value).map_err(|error| PyValueError::new_err(error.to_string()))
}

fn parse_piece_style(value: Option<&str>) -> PyResult<TextPieceStyle> {
    match value.unwrap_or("discs").to_ascii_lowercase().as_str() {
        "discs" | "disc" | "circles" | "circle" | "unicode" => Ok(TextPieceStyle::Discs),
        "letters" | "ascii" => Ok(TextPieceStyle::Letters),
        _ => Err(PyValueError::new_err(
            "style must be 'discs' or 'letters'",
        )),
    }
}

#[pyclass(name = "Position")]
#[derive(Clone)]
struct PyPosition {
    inner: Position,
}

#[pymethods]
impl PyPosition {
    #[new]
    fn new() -> Self {
        Self {
            inner: Position::initial(),
        }
    }

    #[staticmethod]
    fn initial() -> Self {
        Self::new()
    }

    #[staticmethod]
    fn empty(side_to_move: &str) -> PyResult<Self> {
        Ok(Self {
            inner: Position::empty(parse_color(side_to_move)?),
        })
    }

    fn copy(&self) -> Self {
        self.clone()
    }

    fn side_to_move(&self) -> &'static str {
        match self.inner.side_to_move() {
            Color::White => "white",
            Color::Black => "black",
        }
    }

    fn legal_moves(&self) -> Vec<String> {
        self.inner
            .legal_moves()
            .into_iter()
            .map(|mv| mv.to_string())
            .collect()
    }

    fn is_legal_move(&self, mv: &str) -> PyResult<bool> {
        Ok(self.inner.is_legal_move(parse_move(mv)?).is_ok())
    }

    fn apply_move(&mut self, mv: &str) -> PyResult<()> {
        self.inner
            .apply_move(parse_move(mv)?)
            .map(|_| ())
            .map_err(|error| PyValueError::new_err(error.to_string()))
    }

    fn piece_at(&self, square: &str) -> PyResult<Option<&'static str>> {
        Ok(match self.inner.piece_at(parse_square(square)?) {
            Some(Color::White) => Some("white"),
            Some(Color::Black) => Some("black"),
            None => None,
        })
    }

    fn set_piece(&mut self, color: &str, square: &str) -> PyResult<()> {
        self.inner.set_piece(parse_color(color)?, parse_square(square)?);
        Ok(())
    }

    fn clear_square(&mut self, square: &str) -> PyResult<()> {
        self.inner.clear_square(parse_square(square)?);
        Ok(())
    }

    fn piece_count(&self, color: &str) -> PyResult<usize> {
        Ok(self.inner.piece_count(parse_color(color)?))
    }

    #[pyo3(signature = (style=None))]
    fn ascii_board(&self, style: Option<&str>) -> PyResult<String> {
        Ok(sanqi_render::ascii_board_with_style(
            &self.inner,
            parse_piece_style(style)?,
        ))
    }

    fn svg_board(&self) -> String {
        sanqi_render::svg_board(&self.inner)
    }

    fn svg_for_move(&self, mv: &str) -> PyResult<String> {
        Ok(sanqi_render::svg_for_move(&self.inner, parse_move(mv)?))
    }

    fn best_move(&self, depth: u8) -> Option<String> {
        sanqi_engine::best_move(&self.inner, depth).map(|result| result.best_move.to_string())
    }

    fn analyze<'py>(&self, py: Python<'py>, depth: u8) -> PyResult<Option<Bound<'py, PyAny>>> {
        let Some(result) = sanqi_engine::best_move(&self.inner, depth) else {
            return Ok(None);
        };
        let dict = PyDict::new_bound(py);
        dict.set_item("best_move", result.best_move.to_string())?;
        dict.set_item("score", result.score)?;
        dict.set_item("depth", result.depth)?;
        dict.set_item(
            "principal_variation",
            result
                .principal_variation
                .iter()
                .map(ToString::to_string)
                .collect::<Vec<_>>(),
        )?;
        Ok(Some(dict.into_any()))
    }

    fn analyze_timed<'py>(
        &self,
        py: Python<'py>,
        depth: u8,
        budget_ms: u64,
    ) -> PyResult<Bound<'py, PyAny>> {
        let analysis =
            sanqi_engine::analyze_iterative(&self.inner, depth, std::time::Duration::from_millis(budget_ms));
        let dict = PyDict::new_bound(py);
        dict.set_item("root_legal_moves", analysis.stats.root_legal_moves)?;
        dict.set_item("completed_depth", analysis.stats.completed_depth)?;
        dict.set_item("nodes", analysis.stats.nodes)?;
        dict.set_item("quiescence_nodes", analysis.stats.quiescence_nodes)?;
        dict.set_item("timed_out", analysis.stats.timed_out)?;
        if let Some(result) = analysis.best {
            dict.set_item("best_move", result.best_move.to_string())?;
            dict.set_item("score", result.score)?;
            dict.set_item(
                "principal_variation",
                result
                    .principal_variation
                    .iter()
                    .map(ToString::to_string)
                    .collect::<Vec<_>>(),
            )?;
        } else {
            dict.set_item("best_move", py.None())?;
            dict.set_item("score", py.None())?;
            dict.set_item("principal_variation", Vec::<String>::new())?;
        }
        Ok(dict.into_any())
    }

    fn evaluate(&self) -> i32 {
        sanqi_engine::evaluate(&self.inner)
    }

    fn outcome(&self) -> Option<&'static str> {
        match self.inner.outcome() {
            Some(sanqi_core::Outcome::Winner(Color::White)) => Some("white"),
            Some(sanqi_core::Outcome::Winner(Color::Black)) => Some("black"),
            None => None,
        }
    }

    fn supporting_pivots<'py>(&self, py: Python<'py>, mv: &str) -> PyResult<Bound<'py, PyAny>> {
        let entries = self
            .inner
            .supporting_pivots(self.inner.side_to_move(), parse_move(mv)?);
        let items = entries
            .into_iter()
            .map(|entry| {
                let dict = PyDict::new_bound(py);
                let supports = vec![entry.supports.a.to_string(), entry.supports.b.to_string()];
                dict.set_item("supports", supports)?;
                dict.set_item("file_twice", entry.pivot.file_twice())?;
                dict.set_item("rank_twice", entry.pivot.rank_twice())?;
                if let Some(center) = entry.pivot.center_square() {
                    dict.set_item("center_square", center.to_string())?;
                } else {
                    dict.set_item("center_square", py.None())?;
                }
                Ok(dict.into_any())
            })
            .collect::<PyResult<Vec<_>>>()?;
        Ok(items.into_py(py).into_bound(py))
    }
}

#[pyfunction]
fn parse_move_string(mv: &str) -> PyResult<String> {
    Ok(parse_move(mv)?.to_string())
}

#[pyfunction]
fn initial_position() -> PyPosition {
    PyPosition::new()
}

#[pymodule]
fn sanqi_python(_py: Python<'_>, module: &Bound<'_, PyModule>) -> PyResult<()> {
    module.add_class::<PyPosition>()?;
    module.add_function(wrap_pyfunction!(parse_move_string, module)?)?;
    module.add_function(wrap_pyfunction!(initial_position, module)?)?;
    Ok(())
}
