use std::env;
use std::fs;
use std::io::{self, Write};
use std::process::ExitCode;
use std::str::FromStr;
use std::time::Duration;

use sanqi_core::{Color, Move, Position};

struct BenchmarkCase {
    name: &'static str,
    moves: &'static [&'static str],
}

struct BenchmarkRow {
    name: String,
    best: String,
    score: String,
    depth: u8,
    root_done: usize,
    root_total: usize,
    nodes: u64,
    qnodes: u64,
    qpruned: u64,
    qms: u128,
    total_ms: u128,
    pv: String,
}

const BENCHMARK_CASES: &[BenchmarkCase] = &[
    BenchmarkCase {
        name: "initial",
        moves: &[],
    },
    BenchmarkCase {
        name: "after-h1-d3",
        moves: &["h1-d3"],
    },
    BenchmarkCase {
        name: "after-h1-d3-h8-d6",
        moves: &["h1-d3", "h8-d6"],
    },
    BenchmarkCase {
        name: "sparse-center",
        moves: &["h1-d3", "h8-d6", "a1-d4"],
    },
];

fn main() -> ExitCode {
    match run() {
        Ok(()) => ExitCode::SUCCESS,
        Err(message) => {
            eprintln!("{message}");
            ExitCode::from(1)
        }
    }
}

fn run() -> Result<(), String> {
    let mut args = env::args().skip(1);
    let Some(command) = args.next() else {
        print_usage();
        return Ok(());
    };

    match command.as_str() {
        "board" => {
            let position = position_from_moves(args.collect())?;
            print!("{}", sanqi_render::ascii_board(&position));
        }
        "moves" => {
            let position = position_from_moves(args.collect())?;
            for mv in position.legal_moves() {
                println!("{mv}");
            }
        }
        "best" => {
            let depth = args
                .next()
                .ok_or_else(|| "missing depth".to_string())?
                .parse::<u8>()
                .map_err(|_| "depth must be an integer between 0 and 255".to_string())?;
            let position = position_from_moves(args.collect())?;
            if let Some(result) = sanqi_engine::best_move(&position, depth) {
                println!("best_move: {}", result.best_move);
                println!("score: {}", result.score);
                println!("depth: {}", result.depth);
                println!("pv: {}", format_pv(&result.principal_variation));
            } else {
                println!("no legal move");
            }
        }
        "best-time" => {
            let max_depth = args
                .next()
                .ok_or_else(|| "missing max depth".to_string())?
                .parse::<u8>()
                .map_err(|_| "max depth must be an integer between 0 and 255".to_string())?;
            let budget_ms = args
                .next()
                .ok_or_else(|| "missing time budget in milliseconds".to_string())?
                .parse::<u64>()
                .map_err(|_| "time budget must be an integer number of milliseconds".to_string())?;
            let position = position_from_moves(args.collect())?;
            if let Some(result) =
                sanqi_engine::best_move_iterative(&position, max_depth, Duration::from_millis(budget_ms))
            {
                println!("best_move: {}", result.best_move);
                println!("score: {}", result.score);
                println!("depth: {}", result.depth);
                println!("pv: {}", format_pv(&result.principal_variation));
                println!("time_budget_ms: {budget_ms}");
            } else {
                println!("no legal move");
            }
        }
        "analyze" => {
            let max_depth = args
                .next()
                .ok_or_else(|| "missing max depth".to_string())?
                .parse::<u8>()
                .map_err(|_| "max depth must be an integer between 0 and 255".to_string())?;
            let budget_ms = args
                .next()
                .ok_or_else(|| "missing time budget in milliseconds".to_string())?
                .parse::<u64>()
                .map_err(|_| "time budget must be an integer number of milliseconds".to_string())?;
            let position = position_from_moves(args.collect())?;
            let analysis =
                sanqi_engine::analyze_iterative(&position, max_depth, Duration::from_millis(budget_ms));
            println!("root_legal_moves: {}", analysis.stats.root_legal_moves);
            println!(
                "completed_root_moves_current_depth: {}",
                analysis.stats.completed_root_moves_current_depth
            );
            println!(
                "completed_root_moves_total: {}",
                analysis.stats.completed_root_moves_total
            );
            println!("completed_depth: {}", analysis.stats.completed_depth);
            println!("nodes: {}", analysis.stats.nodes);
            println!("quiescence_nodes: {}", analysis.stats.quiescence_nodes);
            println!("quiescence_pruned_moves: {}", analysis.stats.quiescence_pruned_moves);
            println!("evaluation_calls: {}", analysis.stats.evaluation_calls);
            println!("legal_move_generations: {}", analysis.stats.legal_move_generations);
            println!("total_time_ms: {}", analysis.stats.total_time.as_millis());
            println!(
                "quiescence_time_ms: {}",
                analysis.stats.quiescence_time.as_millis()
            );
            println!(
                "depth_times_ms: {}",
                format_depth_timings(&analysis.stats.depth_timings)
            );
            println!("timed_out: {}", analysis.stats.timed_out);
            if let Some(result) = analysis.best {
                println!("best_move: {}", result.best_move);
                println!("score: {}", result.score);
                println!("pv: {}", format_pv(&result.principal_variation));
            } else {
                println!("best_move: -");
            }
        }
        "bench" => {
            let max_depth = args
                .next()
                .ok_or_else(|| "missing max depth".to_string())?
                .parse::<u8>()
                .map_err(|_| "max depth must be an integer between 0 and 255".to_string())?;
            let budget_ms = args
                .next()
                .ok_or_else(|| "missing time budget in milliseconds".to_string())?
                .parse::<u64>()
                .map_err(|_| "time budget must be an integer number of milliseconds".to_string())?;
            run_benchmark(max_depth, Duration::from_millis(budget_ms))?;
        }
        "bench-save" => {
            let max_depth = args
                .next()
                .ok_or_else(|| "missing max depth".to_string())?
                .parse::<u8>()
                .map_err(|_| "max depth must be an integer between 0 and 255".to_string())?;
            let budget_ms = args
                .next()
                .ok_or_else(|| "missing time budget in milliseconds".to_string())?
                .parse::<u64>()
                .map_err(|_| "time budget must be an integer number of milliseconds".to_string())?;
            let path = args.next().ok_or_else(|| "missing output path".to_string())?;
            save_benchmark(max_depth, Duration::from_millis(budget_ms), &path)?;
        }
        "bench-compare" => {
            let baseline = args.next().ok_or_else(|| "missing baseline path".to_string())?;
            let candidate = args.next().ok_or_else(|| "missing candidate path".to_string())?;
            compare_benchmarks(&baseline, &candidate)?;
        }
        "apply" => {
            let moves: Vec<String> = args.collect();
            if moves.is_empty() {
                return Err("apply requires at least one move".to_string());
            }
            let position = position_from_moves(moves)?;
            print!("{}", sanqi_render::ascii_board(&position));
        }
        "svg" => {
            let mut rest: Vec<String> = args.collect();
            if rest.is_empty() {
                return Err("svg requires a highlight move".to_string());
            }
            let highlight = rest.remove(0);
            let position = position_from_moves(rest)?;
            let mv = Move::from_str(&highlight).map_err(|error| error.to_string())?;
            print!("{}", sanqi_render::svg_for_move(&position, mv));
        }
        "play" => {
            let depth = match args.next() {
                Some(value) => value
                    .parse::<u8>()
                    .map_err(|_| "depth must be an integer between 0 and 255".to_string())?,
                None => 2,
            };
            let budget_ms = match args.next() {
                Some(value) => value
                    .parse::<u64>()
                    .map_err(|_| "time budget must be an integer number of milliseconds".to_string())?,
                None => 250,
            };
            let engine_side = match args.next() {
                Some(side) => parse_side(&side)?,
                None => Color::Black,
            };
            run_repl(depth, Duration::from_millis(budget_ms), engine_side)?;
        }
        "help" | "--help" | "-h" => print_usage(),
        other => {
            return Err(format!("unknown command: {other}"));
        }
    }

    Ok(())
}

fn position_from_moves(moves: Vec<String>) -> Result<Position, String> {
    let mut position = Position::initial();
    for mv in moves {
        let parsed = Move::from_str(&mv).map_err(|error| format!("invalid move '{mv}': {error}"))?;
        position
            .apply_move(parsed)
            .map_err(|error| format!("illegal move '{mv}': {error}"))?;
    }
    Ok(position)
}

fn parse_side(value: &str) -> Result<Color, String> {
    match value.to_ascii_lowercase().as_str() {
        "white" | "w" => Ok(Color::White),
        "black" | "b" => Ok(Color::Black),
        _ => Err("side must be 'white' or 'black'".to_string()),
    }
}

fn run_repl(depth: u8, budget: Duration, engine_side: Color) -> Result<(), String> {
    let mut position = Position::initial();
    let stdin = io::stdin();

    println!("interactive Sanqi");
    println!("engine side: {}", color_name(engine_side));
    println!("max depth: {depth}, time budget: {} ms", budget.as_millis());
    println!("commands: board, moves, hint, svg <move>, help, quit");
    println!("enter moves as a1-b3");

    loop {
        println!();
        print!("{}", sanqi_render::ascii_board(&position));

        if let Some(winner) = position.outcome() {
            let sanqi_core::Outcome::Winner(color) = winner;
            println!("game over: {} wins", color_name(color));
            break;
        }

        if position.side_to_move() == engine_side {
            let Some(result) = sanqi_engine::best_move_iterative(&position, depth, budget) else {
                println!("engine search did not return a move");
                break;
            };
            println!(
                "engine plays {} at depth {} with score {}",
                result.best_move, result.depth, result.score
            );
            println!("pv: {}", format_pv(&result.principal_variation));
            position
                .apply_move(result.best_move)
                .map_err(|error| error.to_string())?;
            continue;
        }

        print!("{}> ", color_name(position.side_to_move()));
        io::stdout()
            .flush()
            .map_err(|error| format!("failed to flush stdout: {error}"))?;

        let mut line = String::new();
        stdin
            .read_line(&mut line)
            .map_err(|error| format!("failed to read input: {error}"))?;
        let input = line.trim();

        if input.is_empty() {
            continue;
        }

        match input {
            "quit" | "exit" => break,
            "help" => {
                println!("board       show the current board");
                println!("moves       list legal moves");
                println!("hint        ask the engine for a recommendation for the current side");
                println!("go          alias for hint");
                println!("svg <move>  print annotated SVG for a move");
                println!("quit        exit interactive mode");
            }
            "board" => {}
            "moves" => {
                for mv in position.legal_moves() {
                    println!("{mv}");
                }
            }
            "hint" | "go" => {
                let Some(result) = sanqi_engine::best_move_iterative(&position, depth, budget) else {
                    println!("engine search did not return a move");
                    continue;
                };
                println!(
                    "recommended for {}: {} at depth {} with score {}",
                    color_name(position.side_to_move()),
                    result.best_move,
                    result.depth,
                    result.score
                );
                println!("pv: {}", format_pv(&result.principal_variation));
            }
            _ if input.starts_with("svg ") => {
                let mv_text = input["svg ".len()..].trim();
                let mv = match Move::from_str(mv_text) {
                    Ok(mv) => mv,
                    Err(error) => {
                        println!("invalid move: {error}");
                        continue;
                    }
                };
                println!("{}", sanqi_render::svg_for_move(&position, mv));
            }
            _ => {
                let mv = match Move::from_str(input) {
                    Ok(mv) => mv,
                    Err(error) => {
                        println!("invalid move: {error}");
                        continue;
                    }
                };
                if let Err(error) = position.apply_move(mv) {
                    println!("illegal move: {error}");
                    continue;
                }
            }
        }
    }

    Ok(())
}

fn run_benchmark(depth: u8, budget: Duration) -> Result<(), String> {
    let rows = benchmark_rows(depth, budget)?;
    println!(
        "benchmark_suite: {} cases, depth {}, budget {} ms",
        BENCHMARK_CASES.len(),
        depth,
        budget.as_millis()
    );
    println!(
        "name\tbest\tscore\tdepth\troot_done\troot_total\tnodes\tqnodes\tqpruned\tqms\ttotal_ms\tpv"
    );
    let mut sum_depth = 0_u64;
    let mut sum_root_done = 0_u64;
    let mut sum_root_total = 0_u64;
    let mut sum_nodes = 0_u64;
    let mut sum_qnodes = 0_u64;
    let mut sum_qpruned = 0_u64;
    let mut sum_qms = 0_u128;
    let mut sum_total_ms = 0_u128;

    for row in rows {
        sum_depth += u64::from(row.depth);
        sum_root_done += row.root_done as u64;
        sum_root_total += row.root_total as u64;
        sum_nodes += row.nodes;
        sum_qnodes += row.qnodes;
        sum_qpruned += row.qpruned;
        sum_qms += row.qms;
        sum_total_ms += row.total_ms;
        println!(
            "{}\t{}\t{}\t{}\t{}\t{}\t{}\t{}\t{}\t{}\t{}\t{}",
            row.name,
            row.best,
            row.score,
            row.depth,
            row.root_done,
            row.root_total,
            row.nodes,
            row.qnodes,
            row.qpruned,
            row.qms,
            row.total_ms,
            row.pv,
        );
    }
    println!(
        "summary\t-\t-\t{}\t{}\t{}\t{}\t{}\t{}\t{}\t{}\t-",
        sum_depth,
        sum_root_done,
        sum_root_total,
        sum_nodes,
        sum_qnodes,
        sum_qpruned,
        sum_qms,
        sum_total_ms,
    );
    Ok(())
}

fn benchmark_rows(depth: u8, budget: Duration) -> Result<Vec<BenchmarkRow>, String> {
    let mut rows = Vec::with_capacity(BENCHMARK_CASES.len());
    for case in BENCHMARK_CASES {
        let moves = case
            .moves
            .iter()
            .map(|mv| (*mv).to_string())
            .collect::<Vec<_>>();
        let position = position_from_moves(moves)?;
        let analysis = sanqi_engine::analyze_iterative(&position, depth, budget);
        let best = analysis
            .best
            .as_ref()
            .map(|result| result.best_move.to_string())
            .unwrap_or_else(|| "-".to_string());
        let score = analysis
            .best
            .as_ref()
            .map(|result| result.score.to_string())
            .unwrap_or_else(|| "-".to_string());
        let pv = analysis
            .best
            .as_ref()
            .map(|result| format_pv(&result.principal_variation))
            .unwrap_or_else(|| "-".to_string());
        rows.push(BenchmarkRow {
            name: case.name.to_string(),
            best,
            score,
            depth: analysis.stats.completed_depth,
            root_done: analysis.stats.completed_root_moves_current_depth,
            root_total: analysis.stats.root_legal_moves,
            nodes: analysis.stats.nodes,
            qnodes: analysis.stats.quiescence_nodes,
            qpruned: analysis.stats.quiescence_pruned_moves,
            qms: analysis.stats.quiescence_time.as_millis(),
            total_ms: analysis.stats.total_time.as_millis(),
            pv,
        });
    }
    Ok(rows)
}

fn save_benchmark(depth: u8, budget: Duration, path: &str) -> Result<(), String> {
    let rows = benchmark_rows(depth, budget)?;
    let mut output = String::new();
    output.push_str(&format!(
        "# benchmark_suite depth={} budget_ms={}\n",
        depth,
        budget.as_millis()
    ));
    output.push_str(
        "name\tbest\tscore\tdepth\troot_done\troot_total\tnodes\tqnodes\tqpruned\tqms\ttotal_ms\tpv\n",
    );
    for row in rows {
        output.push_str(&format!(
            "{}\t{}\t{}\t{}\t{}\t{}\t{}\t{}\t{}\t{}\t{}\t{}\n",
            row.name,
            row.best,
            row.score,
            row.depth,
            row.root_done,
            row.root_total,
            row.nodes,
            row.qnodes,
            row.qpruned,
            row.qms,
            row.total_ms,
            row.pv,
        ));
    }
    fs::write(path, output).map_err(|error| format!("failed to write {path}: {error}"))?;
    println!("saved benchmark to {path}");
    Ok(())
}

fn compare_benchmarks(baseline: &str, candidate: &str) -> Result<(), String> {
    let baseline_rows = load_benchmark_rows(baseline)?;
    let candidate_rows = load_benchmark_rows(candidate)?;
    println!("case\td_depth\td_nodes\td_qnodes\td_qpruned\td_qms\td_total_ms\tbest_changed");
    for base in &baseline_rows {
        let Some(next) = candidate_rows.iter().find(|row| row.name == base.name) else {
            continue;
        };
        println!(
            "{}\t{:+}\t{:+}\t{:+}\t{:+}\t{:+}\t{:+}\t{}",
            base.name,
            i32::from(next.depth) - i32::from(base.depth),
            next.nodes as i64 - base.nodes as i64,
            next.qnodes as i64 - base.qnodes as i64,
            next.qpruned as i64 - base.qpruned as i64,
            next.qms as i128 - base.qms as i128,
            next.total_ms as i128 - base.total_ms as i128,
            if next.best == base.best { "no" } else { "yes" },
        );
    }
    Ok(())
}

fn load_benchmark_rows(path: &str) -> Result<Vec<BenchmarkRow>, String> {
    let content = fs::read_to_string(path).map_err(|error| format!("failed to read {path}: {error}"))?;
    let mut rows = Vec::new();
    for line in content.lines() {
        if line.is_empty() || line.starts_with('#') || line.starts_with("name\t") {
            continue;
        }
        let parts = line.split('\t').collect::<Vec<_>>();
        if parts.len() != 12 {
            return Err(format!("invalid benchmark row in {path}: {line}"));
        }
        rows.push(BenchmarkRow {
            name: parts[0].to_string(),
            best: parts[1].to_string(),
            score: parts[2].to_string(),
            depth: parts[3]
                .parse()
                .map_err(|_| format!("invalid depth in {path}: {}", parts[3]))?,
            root_done: parts[4]
                .parse()
                .map_err(|_| format!("invalid root_done in {path}: {}", parts[4]))?,
            root_total: parts[5]
                .parse()
                .map_err(|_| format!("invalid root_total in {path}: {}", parts[5]))?,
            nodes: parts[6]
                .parse()
                .map_err(|_| format!("invalid nodes in {path}: {}", parts[6]))?,
            qnodes: parts[7]
                .parse()
                .map_err(|_| format!("invalid qnodes in {path}: {}", parts[7]))?,
            qpruned: parts[8]
                .parse()
                .map_err(|_| format!("invalid qpruned in {path}: {}", parts[8]))?,
            qms: parts[9]
                .parse()
                .map_err(|_| format!("invalid qms in {path}: {}", parts[9]))?,
            total_ms: parts[10]
                .parse()
                .map_err(|_| format!("invalid total_ms in {path}: {}", parts[10]))?,
            pv: parts[11].to_string(),
        });
    }
    Ok(rows)
}

fn color_name(color: Color) -> &'static str {
    match color {
        Color::White => "white",
        Color::Black => "black",
    }
}

fn format_pv(pv: &[Move]) -> String {
    if pv.is_empty() {
        return "-".to_string();
    }
    pv.iter()
        .map(ToString::to_string)
        .collect::<Vec<_>>()
        .join(" ")
}

fn format_depth_timings(timings: &[sanqi_engine::DepthTiming]) -> String {
    if timings.is_empty() {
        return "-".to_string();
    }
    timings
        .iter()
        .map(|timing| {
            format!(
                "d{}={}ms/{}",
                timing.depth,
                timing.elapsed.as_millis(),
                timing.completed_root_moves
            )
        })
        .collect::<Vec<_>>()
        .join(" ")
}

fn print_usage() {
    println!("sanqi <command> [arguments]");
    println!();
    println!("Commands:");
    println!("  board [moves...]        Show the board after applying moves");
    println!("  moves [moves...]        List legal moves in the resulting position");
    println!("  best <depth> [moves...] Show the engine's best move");
    println!("  best-time <depth> <ms> [moves...]  Search with iterative deepening and time budget");
    println!("  analyze <depth> <ms> [moves...]    Show search diagnostics");
    println!("  bench <depth> <ms>      Run the built-in benchmark suite");
    println!("  bench-save <depth> <ms> <path>  Save benchmark TSV to a file");
    println!("  bench-compare <base> <candidate> Compare two saved benchmark TSV files");
    println!("  apply <moves...>        Alias for board with at least one move");
    println!("  svg <move> [moves...]   Render SVG for a highlighted move");
    println!("  play [depth] [ms] [side] Start interactive play, default depth 2, 250 ms, engine side black");
    println!("  help                    Show this help");
    println!();
    println!("Examples:");
    println!("  sanqi board");
    println!("  sanqi moves a1-b3");
    println!("  sanqi best 2 a1-b3");
    println!("  sanqi best-time 4 250 a1-b3");
    println!("  sanqi analyze 4 250 a1-b3");
    println!("  sanqi bench 4 250");
    println!("  sanqi bench-save 4 250 baseline.tsv");
    println!("  sanqi bench-compare baseline.tsv candidate.tsv");
    println!("  sanqi svg a7-b5 a1-b3");
    println!("  sanqi play 3 250 black");
}
