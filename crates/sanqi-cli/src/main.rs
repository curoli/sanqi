use std::env;
use std::io::{self, Write};
use std::process::ExitCode;
use std::str::FromStr;

use sanqi_core::{Color, Move, Position};

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
            } else {
                println!("no legal move");
            }
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
            let engine_side = match args.next() {
                Some(side) => parse_side(&side)?,
                None => Color::Black,
            };
            run_repl(depth, engine_side)?;
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

fn run_repl(depth: u8, engine_side: Color) -> Result<(), String> {
    let mut position = Position::initial();
    let stdin = io::stdin();

    println!("interactive Sanqi");
    println!("engine side: {}", color_name(engine_side));
    println!("commands: board, moves, go, svg <move>, help, quit");
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
            let Some(result) = sanqi_engine::best_move(&position, depth) else {
                println!("no legal move");
                break;
            };
            println!(
                "engine plays {} at depth {} with score {}",
                result.best_move, result.depth, result.score
            );
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
                println!("go          ask the engine for the current side to move");
                println!("svg <move>  print annotated SVG for a move");
                println!("quit        exit interactive mode");
            }
            "board" => {}
            "moves" => {
                for mv in position.legal_moves() {
                    println!("{mv}");
                }
            }
            "go" => {
                let Some(result) = sanqi_engine::best_move(&position, depth) else {
                    println!("no legal move");
                    continue;
                };
                println!(
                    "recommended: {} at depth {} with score {}",
                    result.best_move, result.depth, result.score
                );
            }
            _ if input.starts_with("svg ") => {
                let mv_text = input["svg ".len()..].trim();
                let mv = Move::from_str(mv_text).map_err(|error| error.to_string())?;
                println!("{}", sanqi_render::svg_for_move(&position, mv));
            }
            _ => {
                let mv = Move::from_str(input).map_err(|error| error.to_string())?;
                position.apply_move(mv).map_err(|error| error.to_string())?;
            }
        }
    }

    Ok(())
}

fn color_name(color: Color) -> &'static str {
    match color {
        Color::White => "white",
        Color::Black => "black",
    }
}

fn print_usage() {
    println!("sanqi <command> [arguments]");
    println!();
    println!("Commands:");
    println!("  board [moves...]        Show the board after applying moves");
    println!("  moves [moves...]        List legal moves in the resulting position");
    println!("  best <depth> [moves...] Show the engine's best move");
    println!("  apply <moves...>        Alias for board with at least one move");
    println!("  svg <move> [moves...]   Render SVG for a highlighted move");
    println!("  play [depth] [side]     Start interactive play, default depth 2, engine side black");
    println!("  help                    Show this help");
    println!();
    println!("Examples:");
    println!("  sanqi board");
    println!("  sanqi moves a1-b3");
    println!("  sanqi best 2 a1-b3");
    println!("  sanqi svg a7-b5 a1-b3");
    println!("  sanqi play 2 black");
}
