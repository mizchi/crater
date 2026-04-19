// Instrument foliojs/brotli to trace decode_context_map behavior
const fs = require('fs');
const path = require('path');

// Read the original decode.js
let decodeCode = fs.readFileSync(path.join(__dirname, '../node_modules/brotli/dec/decode.js'), 'utf8');

// Add trace to DecodeContextMap
decodeCode = decodeCode.replace(
  'function DecodeContextMap(context_map_size, br) {',
  `function DecodeContextMap(context_map_size, br) {`
);

// Add trace after num_htrees decode
decodeCode = decodeCode.replace(
  'var num_htrees = out.num_htrees = DecodeVarLenUint8(br) + 1;',
  `var num_htrees = out.num_htrees = DecodeVarLenUint8(br) + 1;
  // TRACE
  `
);

// Add trace after use_rle_for_zeros
decodeCode = decodeCode.replace(
  `use_rle_for_zeros = br.readBits(1);
  if (use_rle_for_zeros) {
    max_run_length_prefix = br.readBits(4) + 1;
  }`,
  `use_rle_for_zeros = br.readBits(1);
  if (use_rle_for_zeros) {
    max_run_length_prefix = br.readBits(4) + 1;
  }
  console.log("JS decode_context_map: size=" + context_map_size + " htrees=" + num_htrees + " rle=" + use_rle_for_zeros + " max_rle=" + max_run_length_prefix + " br_pos=" + br.pos_ + " br_bit_pos=" + br.bit_pos_ + " br_bit_end_pos=" + br.bit_end_pos_);`
);

// Add trace to RLE section
decodeCode = decodeCode.replace(
  `var reps = 1 + (1 << code) + br.readBits(code);
      while (--reps) {`,
  `var extra_bits = br.readBits(code);
      var reps = 1 + (1 << code) + extra_bits;
      if (DecodeContextMap._iter < 20 || i + reps > context_map_size) {
        console.log("  rle: iter=" + DecodeContextMap._iter + " i=" + i + " code=" + code + " extra=" + extra_bits + " reps=" + reps + " remaining=" + (context_map_size - i) + " br_pos=" + br.pos_ + " br_bit_pos=" + br.bit_pos_);
      }
      while (--reps) {`
);

// Add val trace
decodeCode = decodeCode.replace(
  `context_map[i] = code - max_run_length_prefix;
      ++i;`,
  `if (DecodeContextMap._iter < 20) {
        console.log("  val: iter=" + DecodeContextMap._iter + " i=" + i + " code=" + code + " val=" + (code - max_run_length_prefix));
      }
      context_map[i] = code - max_run_length_prefix;
      ++i;`
);

// Add iter counter
decodeCode = decodeCode.replace(
  'for (i = 0; i < context_map_size;) {',
  `DecodeContextMap._iter = 0;
  for (i = 0; i < context_map_size;) {`
);

decodeCode = decodeCode.replace(
  `context_map[i] = code - max_run_length_prefix;
      ++i;`,
  `context_map[i] = code - max_run_length_prefix;
      ++i;
      DecodeContextMap._iter++;`
);

// Also increment after RLE and zero
decodeCode = decodeCode.replace(
  `if (code === 0) {
      context_map[i] = 0;
      ++i;
    } else`,
  `if (code === 0) {
      context_map[i] = 0;
      ++i;
      DecodeContextMap._iter++;
    } else`
);

// After RLE while loop ends
// Actually this is getting complex. Let me just write a simpler instrumented version.

// Reset and do a cleaner approach
decodeCode = fs.readFileSync(path.join(__dirname, '../node_modules/brotli/dec/decode.js'), 'utf8');

// Add block_types trace
decodeCode = decodeCode.replace(
  `br.readMoreInput();

    distance_postfix_bits = br.readBits(2);`,
  `console.log("JS block_types=[" + num_block_types[0] + "," + num_block_types[1] + "," + num_block_types[2] + "] block_len=[" + block_length[0] + "," + block_length[1] + "," + block_length[2] + "]");
    br.readMoreInput();

    distance_postfix_bits = br.readBits(2);`
);

// Add trace to DecodeContextMap - inject right after context_map allocation
decodeCode = decodeCode.replace(
  `var context_map = out.context_map = new Uint8Array(context_map_size);
  if (num_htrees <= 1) {
    return out;
  }

  use_rle_for_zeros = br.readBits(1);
  if (use_rle_for_zeros) {
    max_run_length_prefix = br.readBits(4) + 1;
  }

  table = [];`,
  `var context_map = out.context_map = new Uint8Array(context_map_size);
  if (num_htrees <= 1) {
    return out;
  }

  use_rle_for_zeros = br.readBits(1);
  if (use_rle_for_zeros) {
    max_run_length_prefix = br.readBits(4) + 1;
  }
  console.log("JS DCM: size=" + context_map_size + " htrees=" + num_htrees + " rle=" + use_rle_for_zeros + " max_rle=" + max_run_length_prefix + " br_pos=" + br.pos_ + " bp=" + br.bit_pos_ + " bep=" + br.bit_end_pos_);

  table = [];`
);

// After ReadHuffmanCode in DCM
decodeCode = decodeCode.replace(
  `ReadHuffmanCode(num_htrees + max_run_length_prefix, table, 0, br);

  for (i = 0; i < context_map_size;) {`,
  `ReadHuffmanCode(num_htrees + max_run_length_prefix, table, 0, br);
  console.log("  JS after huffman: br_pos=" + br.pos_ + " bp=" + br.bit_pos_);

  var _dcm_iter = 0;
  for (i = 0; i < context_map_size;) {`
);

// Add trace to RLE
decodeCode = decodeCode.replace(
  `var reps = 1 + (1 << code) + br.readBits(code);`,
  `var _extra = br.readBits(code);
      var reps = 1 + (1 << code) + _extra;
      if (_dcm_iter < 20) { console.log("  rle: iter=" + _dcm_iter + " i=" + i + " code=" + code + " extra=" + _extra + " reps=" + reps + " remaining=" + (context_map_size - i) + " br_pos=" + br.pos_ + " bp=" + br.bit_pos_); }`
);

// Add trace to value case
decodeCode = decodeCode.replace(
  `context_map[i] = code - max_run_length_prefix;
      ++i;
    }
  }`,
  `if (_dcm_iter < 20) { console.log("  val: iter=" + _dcm_iter + " i=" + i + " code=" + code + " val=" + (code - max_run_length_prefix)); }
      context_map[i] = code - max_run_length_prefix;
      ++i;
      _dcm_iter++;
    }
  }`
);

// Increment iter for code == 0 and rle cases
decodeCode = decodeCode.replace(
  `if (code === 0) {
      context_map[i] = 0;
      ++i;
    } else if (code <= max_run_length_prefix)`,
  `if (code === 0) {
      context_map[i] = 0;
      ++i;
      _dcm_iter++;
    } else if (code <= max_run_length_prefix)`
);

// Increment after RLE while
decodeCode = decodeCode.replace(
  `while (--reps) {
        if (i >= context_map_size) {
          throw new Error("[DecodeContextMap] i >= context_map_size");
        }
        context_map[i] = 0;
        ++i;
      }
    } else {`,
  `while (--reps) {
        if (i >= context_map_size) {
          throw new Error("[DecodeContextMap] i >= context_map_size");
        }
        context_map[i] = 0;
        ++i;
      }
      _dcm_iter++;
    } else {`
);

fs.writeFileSync(path.join(__dirname, '../node_modules/brotli/dec/decode_debug.js'), decodeCode);
console.log('Created debug version');

// Now run with the WOFF2 data
const BrotliBitReader = require('brotli/dec/bit_reader');
const BrotliInput = require('brotli/dec/streams').BrotliInput;

// Load the patched decode module
delete require.cache[require.resolve('brotli/dec/decode')];
const decode_debug = require('./debug-brotli-run.js');
