use adler::Adler32;
use flate2::read::{DeflateDecoder, GzDecoder, ZlibDecoder};
use flate2::write::{DeflateEncoder, GzEncoder, ZlibEncoder};
use flate2::Compression;
use std::env;
use std::fs;
use std::io::{Read, Write};

#[derive(Clone, Copy)]
enum Mode {
    Compress,
    Decompress,
}

#[derive(Clone, Copy)]
enum Format {
    Zlib,
    Deflate,
    Gzip,
}

fn parse_mode(s: &str) -> Option<Mode> {
    match s {
        "compress" => Some(Mode::Compress),
        "decompress" => Some(Mode::Decompress),
        _ => None,
    }
}

fn parse_format(s: &str) -> Option<Format> {
    match s {
        "zlib" => Some(Format::Zlib),
        "deflate" => Some(Format::Deflate),
        "gzip" => Some(Format::Gzip),
        _ => None,
    }
}

fn usage() {
    eprintln!("Usage: rust-bench <compress|decompress> <zlib|deflate|gzip> <input>");
    eprintln!("Note: compress uses stored blocks (no compression).");
}

fn compress(format: Format, data: &[u8]) -> Vec<u8> {
    let mut out = Vec::new();
    match format {
        Format::Zlib => {
            let mut enc = ZlibEncoder::new(&mut out, Compression::none());
            enc.write_all(data).expect("write zlib");
            enc.finish().expect("finish zlib");
        }
        Format::Deflate => {
            let mut enc = DeflateEncoder::new(&mut out, Compression::none());
            enc.write_all(data).expect("write deflate");
            enc.finish().expect("finish deflate");
        }
        Format::Gzip => {
            let mut enc = GzEncoder::new(&mut out, Compression::none());
            enc.write_all(data).expect("write gzip");
            enc.finish().expect("finish gzip");
        }
    }
    out
}

fn decompress(format: Format, data: &[u8]) -> Vec<u8> {
    let mut out = Vec::new();
    match format {
        Format::Zlib => {
            let mut dec = ZlibDecoder::new(data);
            dec.read_to_end(&mut out).expect("read zlib");
        }
        Format::Deflate => {
            let mut dec = DeflateDecoder::new(data);
            dec.read_to_end(&mut out).expect("read deflate");
        }
        Format::Gzip => {
            let mut dec = GzDecoder::new(data);
            dec.read_to_end(&mut out).expect("read gzip");
        }
    }
    out
}

fn main() {
    let args: Vec<String> = env::args().collect();
    if args.len() < 4 {
        usage();
        std::process::exit(1);
    }

    let mode = match parse_mode(&args[1]) {
        Some(v) => v,
        None => {
            usage();
            std::process::exit(1);
        }
    };

    let format = match parse_format(&args[2]) {
        Some(v) => v,
        None => {
            usage();
            std::process::exit(1);
        }
    };

    let input = fs::read(&args[3]).expect("read input");
    let output = match mode {
        Mode::Compress => compress(format, &input),
        Mode::Decompress => decompress(format, &input),
    };

    let mut adler = Adler32::new();
    adler.write_slice(&output);
    let checksum = adler.checksum();
    println!("{} {}", output.len(), checksum);
}
