///|
enum Mode {
  Compress
  Decompress
}

///|
enum Format {
  Zlib
  Deflate
  Gzip
}

///|
fn parse_mode(s : String) -> Mode? {
  if s == "compress" {
    Some(Compress)
  } else if s == "decompress" {
    Some(Decompress)
  } else {
    None
  }
}

///|
fn parse_format(s : String) -> Format? {
  if s == "zlib" {
    Some(Zlib)
  } else if s == "deflate" {
    Some(Deflate)
  } else if s == "gzip" {
    Some(Gzip)
  } else {
    None
  }
}

///|
fn usage() -> Unit {
  println("Usage: zlib-bench <compress|decompress> <zlib|deflate|gzip> <input>")
  println("Note: compress uses stored blocks (no compression).")
}

///|
fn compress(format : Format, data : Bytes) -> Bytes {
  match format {
    Zlib => @zlib.zlib_compress_stored(data)
    Deflate => @zlib.deflate_compress_stored(data)
    Gzip => @zlib.gzip_compress_stored(data)
  }
}

///|
fn decompress(format : Format, data : Bytes) -> Bytes raise {
  match format {
    Zlib => @zlib.zlib_decompress(data)
    Deflate => @zlib.deflate_decompress(data)
    Gzip => @zlib.gzip_decompress(data)
  }
}

///|
fn main {
  let args = @sys.get_cli_args()
  if args.length() < 4 {
    usage()
    @sys.exit(1)
  }
  let mode_str = args[1]
  let format_str = args[2]
  let input_path = args[3]
  guard parse_mode(mode_str) is Some(mode) else {
    usage()
    @sys.exit(1)
  }
  guard parse_format(format_str) is Some(format) else {
    usage()
    @sys.exit(1)
  }
  let input = try! @fs.read_file_to_bytes(input_path)
  let output = match mode {
    Compress => compress(format, input)
    Decompress => try! decompress(format, input)
  }
  let checksum = @zlib.adler32(output)
  println("\{output.length()} \{checksum}")
}
