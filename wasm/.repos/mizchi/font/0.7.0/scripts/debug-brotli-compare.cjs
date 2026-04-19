// Compare foliojs/brotli trace with MoonBit trace
const fs = require('fs');
const path = require('path');

// Patch foliojs/brotli DecodeContextMap with tracing
const decodeJsPath = path.join(__dirname, '../node_modules/brotli/dec/decode.js');
let code = fs.readFileSync(decodeJsPath, 'utf8');

// Save original
const backupPath = decodeJsPath + '.bak';
if (!fs.existsSync(backupPath)) {
  fs.writeFileSync(backupPath, code);
}

// Inject tracing into DecodeContextMap
code = code.replace(
  `function DecodeContextMap(context_map_size, br) {
  var out = { num_htrees: null, context_map: null };
  var use_rle_for_zeros;
  var max_run_length_prefix = 0;
  var table;
  var i;

  br.readMoreInput();
  var num_htrees = out.num_htrees = DecodeVarLenUint8(br) + 1;

  var context_map = out.context_map = new Uint8Array(context_map_size);
  if (num_htrees <= 1) {
    return out;
  }

  use_rle_for_zeros = br.readBits(1);
  if (use_rle_for_zeros) {
    max_run_length_prefix = br.readBits(4) + 1;
  }

  table = [];
  for (i = 0; i < HUFFMAN_MAX_TABLE_SIZE; i++) {
    table[i] = new HuffmanCode(0, 0);
  }

  ReadHuffmanCode(num_htrees + max_run_length_prefix, table, 0, br);

  for (i = 0; i < context_map_size;) {
    var code;

    br.readMoreInput();
    code = ReadSymbol(table, 0, br);
    if (code === 0) {
      context_map[i] = 0;
      ++i;
    } else if (code <= max_run_length_prefix) {
      var reps = 1 + (1 << code) + br.readBits(code);
      while (--reps) {
        if (i >= context_map_size) {
          throw new Error("[DecodeContextMap] i >= context_map_size");
        }
        context_map[i] = 0;
        ++i;
      }
    } else {
      context_map[i] = code - max_run_length_prefix;
      ++i;
    }
  }
  if (br.readBits(1)) {
    InverseMoveToFrontTransform(context_map, context_map_size);
  }

  return out;
}`,
  `function DecodeContextMap(context_map_size, br) {
  var out = { num_htrees: null, context_map: null };
  var use_rle_for_zeros;
  var max_run_length_prefix = 0;
  var table;
  var i;

  br.readMoreInput();
  var num_htrees = out.num_htrees = DecodeVarLenUint8(br) + 1;

  var context_map = out.context_map = new Uint8Array(context_map_size);
  if (num_htrees <= 1) {
    return out;
  }

  use_rle_for_zeros = br.readBits(1);
  if (use_rle_for_zeros) {
    max_run_length_prefix = br.readBits(4) + 1;
  }
  console.log("JS DCM: size=" + context_map_size + " htrees=" + num_htrees + " rle=" + use_rle_for_zeros + " max_rle=" + max_run_length_prefix + " br_pos=" + br.pos_ + " bp=" + br.bit_pos_ + " bep=" + br.bit_end_pos_);

  table = [];
  for (i = 0; i < HUFFMAN_MAX_TABLE_SIZE; i++) {
    table[i] = new HuffmanCode(0, 0);
  }

  ReadHuffmanCode(num_htrees + max_run_length_prefix, table, 0, br);
  console.log("  JS after huffman: br_pos=" + br.pos_ + " bp=" + br.bit_pos_);

  var _iter = 0;
  for (i = 0; i < context_map_size;) {
    var code;

    br.readMoreInput();
    code = ReadSymbol(table, 0, br);
    if (code === 0) {
      context_map[i] = 0;
      ++i;
      _iter++;
    } else if (code <= max_run_length_prefix) {
      var _extra = br.readBits(code);
      var reps = 1 + (1 << code) + _extra;
      if (_iter < 20 || i + reps > context_map_size) {
        console.log("  rle: iter=" + _iter + " i=" + i + " code=" + code + " extra=" + _extra + " reps=" + reps + " remaining=" + (context_map_size - i) + " br_pos=" + br.pos_ + " bp=" + br.bit_pos_);
      }
      while (--reps) {
        if (i >= context_map_size) {
          throw new Error("[DecodeContextMap] i >= context_map_size");
        }
        context_map[i] = 0;
        ++i;
      }
      _iter++;
    } else {
      if (_iter < 20) {
        console.log("  val: iter=" + _iter + " i=" + i + " code=" + code + " val=" + (code - max_run_length_prefix));
      }
      context_map[i] = code - max_run_length_prefix;
      ++i;
      _iter++;
    }
  }
  if (br.readBits(1)) {
    InverseMoveToFrontTransform(context_map, context_map_size);
  }

  return out;
}`
);

// Add block types trace
code = code.replace(
  `br.readMoreInput();

    distance_postfix_bits = br.readBits(2);`,
  `console.log("JS block_types=[" + num_block_types[0] + "," + num_block_types[1] + "," + num_block_types[2] + "] block_len=[" + block_length[0] + "," + block_length[1] + "," + block_length[2] + "]");
    br.readMoreInput();

    distance_postfix_bits = br.readBits(2);`
);

fs.writeFileSync(decodeJsPath, code);
console.log('Patched decode.js');

// Run decompression
const brotli = require('brotli');
const compressed = fs.readFileSync(path.join(__dirname, '../fixtures/woff2_brotli_stream.br'));
console.log('Decompressing ' + compressed.length + ' bytes...\n');
const result = brotli.decompress(compressed);
console.log('\nResult: ' + (result ? result.length : 'null') + ' bytes');

// Restore original
fs.writeFileSync(decodeJsPath, fs.readFileSync(backupPath));
console.log('Restored original decode.js');
