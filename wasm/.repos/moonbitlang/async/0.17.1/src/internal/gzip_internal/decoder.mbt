// Copyright 2025 International Digital Economy Academy
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

///|
priv enum DecodeMode {
  Header
  Blocks
  DynamicHeader(is_final~ : Bool)
  DynamicCodeLengths(
    is_final~ : Bool,
    hlit~ : Int,
    hdist~ : Int,
    hclen~ : Int,
    index~ : Int,
    code_lengths~ : FixedArray[Int]
  )
  DynamicLengths(
    is_final~ : Bool,
    hlit~ : Int,
    hdist~ : Int,
    code_tree~ : HuffmanTree,
    index~ : Int,
    previous~ : Int,
    lengths~ : FixedArray[Int]
  )
  StoredLengths(is_final~ : Bool)
  StoredBlock(is_final~ : Bool, remaining~ : Int)
  HuffmanBlock(
    is_final~ : Bool,
    literal_tree~ : HuffmanTree,
    distance_tree~ : HuffmanTree
  )
  Trailer
  Finished
}

///|
pub struct Decoder {
  priv trailer_state : TrailerState
  priv mut mode : DecodeMode
  priv mut bit_buffer : UInt
  priv mut bit_count : Int
  priv mut copy_remaining : Int
  priv mut copy_distance : Int
  priv mut pending_buf : FixedArray[Byte]
  priv mut pending_len : Int
  priv history : FixedArray[Byte]
  priv mut history_pos : Int
  priv mut history_len : Int

  fn new() -> Decoder
}

///|
/// Create a decoder state machine.
/// The gzip header is consumed by the first successful `write` call.
pub fn Decoder::new() -> Decoder {
  {
    trailer_state: TrailerState::new(),
    mode: Header,
    bit_buffer: 0U,
    bit_count: 0,
    copy_remaining: 0,
    copy_distance: 0,
    pending_buf: [],
    pending_len: 0,
    history: FixedArray::make(32768, b'\x00'),
    history_pos: 0,
    history_len: 0,
  }
}

///|
pub fn Decoder::is_finished(self : Decoder) -> Bool {
  self.mode is Finished
}

///|
/// Return the minimum compressed input required for
/// the next `write` call to make any progress.
/// The caller may provide more than this amount.
pub fn Decoder::minimum_input_size(self : Decoder) -> Int {
  @cmp.maximum(0, self.raw_minimum_input_size() - self.pending_len)
}

///|
fn Decoder::raw_minimum_input_size(self : Decoder) -> Int {
  match self.mode {
    Header => HEADER_SIZE
    DynamicHeader(_) => @cmp.maximum(0, (14 - self.bit_count + 7) / 8)
    DynamicCodeLengths(hclen~, index~, ..) => {
      let remaining = hclen - index
      @cmp.maximum(0, (remaining * 3 - self.bit_count + 7) / 8)
    }
    DynamicLengths(hlit~, hdist~, code_tree~, index~, ..) =>
      if index < hlit + hdist {
        @cmp.maximum(0, (code_tree.max_bits + 7 - self.bit_count + 7) / 8)
      } else {
        0
      }
    StoredLengths(_) => 4
    StoredBlock(remaining~, ..) => if remaining > 0 { 1 } else { 0 }
    HuffmanBlock(..) =>
      if self.copy_remaining != 0 {
        0
      } else {
        self.minimum_huffman_input_size()
      }
    Trailer => @cmp.maximum(0, 8 - self.bit_count / 8)
    Finished => 0
    Blocks => 1
  }
}

///|
fn Decoder::ensure_pending_capacity(self : Decoder, len : Int) -> Unit {
  guard len > self.pending_buf.length() else { return }
  let new_buf = FixedArray::make(len, b'\x00')
  if self.pending_len > 0 {
    self.pending_buf.blit_to(new_buf, len=self.pending_len)
  }
  self.pending_buf = new_buf
}

///|
fn Decoder::drop_pending(self : Decoder, len : Int) -> Unit {
  guard len > 0 else { return }
  self.pending_len -= len
  if self.pending_len > 0 {
    self.pending_buf.blit_to(
      self.pending_buf,
      src_offset=len,
      dst_offset=0,
      len=self.pending_len,
    )
  }
}

///|
fn Decoder::copy_to_pending(
  self : Decoder,
  input : Bytes,
  input_offset : Int,
  len : Int,
) -> Unit {
  guard len > 0 else { return }
  self.ensure_pending_capacity(self.pending_len + len)
  self.pending_buf.blit_from_bytes(self.pending_len, input, input_offset, len)
  self.pending_len += len
}

///|
/// Buffer compressed input that is smaller than `minimum_input_size()`.
/// `input_len` must be smaller than `minimum_input_size`.
pub fn Decoder::write_partial_data(
  self : Decoder,
  input : Bytes,
  input_offset? : Int = 0,
  input_len? : Int = input.length() - input_offset,
) -> Unit {
  guard input_len < self.minimum_input_size()
  self.ensure_pending_capacity(self.raw_minimum_input_size())
  self.copy_to_pending(input, input_offset, input_len)
}

///|
fn Decoder::finish_dynamic_header(
  self : Decoder,
  input : Bytes,
  start : Int,
  end : Int,
  is_final~ : Bool,
) -> Int raise {
  let (index, hlit) = self.read_bits(input, start, end, 5)
  let (index, hdist) = self.read_bits(input, index, end, 5)
  let (index, hclen) = self.read_bits(input, index, end, 4)
  let hlit = hlit.reinterpret_as_int() + 257
  let hdist = hdist.reinterpret_as_int() + 1
  let hclen = hclen.reinterpret_as_int() + 4
  self.mode = DynamicCodeLengths(
    is_final~,
    hlit~,
    hdist~,
    hclen~,
    index=0,
    code_lengths=FixedArray::make(19, 0),
  )
  index
}

///|
fn Decoder::finish_dynamic_code_lengths(
  self : Decoder,
  input : Bytes,
  start : Int,
  end : Int,
  is_final~ : Bool,
  hlit~ : Int,
  hdist~ : Int,
  hclen~ : Int,
  code_lengths : FixedArray[Int],
  length_index~ : Int,
) -> Int raise {
  let mut index = start
  for i in length_index..<hclen {
    let (next, bits) = self.read_bits(input, index, end, 3)
    index = next
    code_lengths[code_length_order[i]] = bits.reinterpret_as_int()
  }
  self.mode = DynamicLengths(
    is_final~,
    hlit~,
    hdist~,
    code_tree=build_huffman_tree(code_lengths),
    index=0,
    previous=0,
    lengths=FixedArray::make(320, 0),
  )
  index
}

///|
fn Decoder::finish_dynamic_trees(
  self : Decoder,
  is_final~ : Bool,
  hlit~ : Int,
  hdist~ : Int,
  lengths : FixedArray[Int],
) -> Unit raise {
  let literal_lengths = FixedArray::make(hlit, 0)
  for i in 0..<hlit {
    literal_lengths[i] = lengths[i]
  }
  guard hlit > 256 && literal_lengths[256] > 0 else {
    raise InvalidBlock("invalid code -- missing end-of-block")
  }
  let distance_lengths = FixedArray::make(hdist, 0)
  for i in 0..<hdist {
    distance_lengths[i] = lengths[hlit + i]
  }
  self.mode = HuffmanBlock(
    is_final~,
    literal_tree=build_huffman_tree(literal_lengths),
    distance_tree=build_huffman_tree(distance_lengths),
  )
}

///|
fn Decoder::decode_dynamic_length_step(
  self : Decoder,
  input : Bytes,
  start : Int,
  end : Int,
  is_final~ : Bool,
  hlit~ : Int,
  hdist~ : Int,
  code_tree~ : HuffmanTree,
  lengths : FixedArray[Int],
  length_index~ : Int,
  previous~ : Int,
) -> Int raise {
  let total = hlit + hdist
  guard length_index < total else {
    self.finish_dynamic_trees(is_final~, hlit~, hdist~, lengths)
    return start
  }
  let (next, symbol) = self.decode_symbol(input, start, end, code_tree)
  let mut index = next
  let mut length_index = length_index
  let mut previous = previous
  match symbol {
    0..=15 => {
      lengths[length_index] = symbol
      previous = symbol
      length_index += 1
    }
    16 => {
      guard length_index > 0 else {
        raise InvalidBlock("invalid bit length repeat")
      }
      let (next, bits) = self.read_bits(input, index, end, 2)
      index = next
      let repeat = bits.reinterpret_as_int() + 3
      guard length_index + repeat <= total else {
        raise InvalidBlock("invalid bit length repeat")
      }
      for _ in 0..<repeat {
        lengths[length_index] = previous
        length_index += 1
      }
    }
    17 => {
      let (next, bits) = self.read_bits(input, index, end, 3)
      index = next
      let repeat = bits.reinterpret_as_int() + 3
      guard length_index + repeat <= total else {
        raise InvalidBlock("invalid bit length repeat")
      }
      for _ in 0..<repeat {
        lengths[length_index] = 0
        length_index += 1
      }
      previous = 0
    }
    18 => {
      let (next, bits) = self.read_bits(input, index, end, 7)
      index = next
      let repeat = bits.reinterpret_as_int() + 11
      guard length_index + repeat <= total else {
        raise InvalidBlock("invalid bit length repeat")
      }
      for _ in 0..<repeat {
        lengths[length_index] = 0
        length_index += 1
      }
      previous = 0
    }
    _ => raise InvalidBlock("invalid code lengths set")
  }
  if length_index == total {
    self.finish_dynamic_trees(is_final~, hlit~, hdist~, lengths)
  } else {
    self.mode = DynamicLengths(
      is_final~,
      hlit~,
      hdist~,
      code_tree~,
      index=length_index,
      previous~,
      lengths~,
    )
  }
  index
}

///|
fn Decoder::finish_header(
  self : Decoder,
  input : Bytes,
  start : Int,
) -> Int raise {
  ignore(Header::from_bytes(input[start:start + HEADER_SIZE]))
  self.mode = Blocks
  start + HEADER_SIZE
}

///|
fn Decoder::available_output(output_capacity : Int, produced : Int) -> Int {
  output_capacity - produced
}

///|
fn Decoder::minimum_huffman_input_size(self : Decoder) -> Int {
  let needed_bits = 48 - self.bit_count
  if needed_bits <= 0 {
    0
  } else {
    (needed_bits + 7) / 8
  }
}

///|
fn Decoder::append_history(self : Decoder, byte : Byte) -> Unit {
  self.history[self.history_pos] = byte
  self.history_pos = (self.history_pos + 1) & 0x7fff
  if self.history_len < 32768 {
    self.history_len += 1
  }
}

///|
fn Decoder::append_history_bytes(
  self : Decoder,
  src : FixedArray[Byte],
  src_offset : Int,
  len : Int,
) -> Unit {
  guard len > 0 else { return }
  let first_len = @cmp.minimum(len, 32768 - self.history_pos)
  src.blit_to(
    self.history,
    src_offset~,
    dst_offset=self.history_pos,
    len=first_len,
  )
  if first_len < len {
    src.blit_to(
      self.history,
      src_offset=src_offset + first_len,
      dst_offset=0,
      len=len - first_len,
    )
  }
  self.history_pos = (self.history_pos + len) & 0x7fff
  self.history_len = @cmp.minimum(32768, self.history_len + len)
}

///|
fn Decoder::history_index(self : Decoder, distance : Int) -> Int raise {
  guard distance >= 1 && distance <= self.history_len else {
    raise InvalidBlock("invalid distance too far back")
  }
  let mut index = self.history_pos - distance
  if index < 0 {
    index += 32768
  }
  index
}

///|
fn Decoder::write_output_byte(
  self : Decoder,
  output : FixedArray[Byte],
  output_offset : Int,
  produced : Int,
  byte : Byte,
) -> Int {
  output[output_offset + produced] = byte
  self.trailer_state.update(
    output.unsafe_reinterpret_as_bytes()[output_offset + produced:output_offset +
    produced +
    1],
  )
  self.append_history(byte)
  produced + 1
}

///|
fn Decoder::align_to_byte(self : Decoder) -> Unit {
  self.bit_buffer = 0U
  self.bit_count = 0
}

///|
fn Decoder::begin_trailer(self : Decoder) -> Unit {
  let discard = self.bit_count & 7
  if discard > 0 {
    self.bit_buffer = self.bit_buffer >> discard
    self.bit_count -= discard
  }
  self.mode = Trailer
}

///|
fn Decoder::finish_stored_header(
  self : Decoder,
  input : Bytes,
  start : Int,
  is_final~ : Bool,
) -> Int raise {
  guard input[start:] is [u16le(len), u16le(nlen), ..]
  guard (len ^ nlen) == 0xffff else {
    raise InvalidBlock("stored block length checksum mismatch")
  }
  if len == 0 {
    if is_final {
      self.begin_trailer()
    } else {
      self.mode = Blocks
    }
  } else {
    self.mode = StoredBlock(is_final~, remaining=len.reinterpret_as_int())
  }
  start + 4
}

///|
fn Decoder::read_aligned_byte(
  self : Decoder,
  input : Bytes,
  start : Int,
) -> (Int, Byte) {
  guard (self.bit_count & 7) == 0 else { abort("unreachable") }
  if self.bit_count >= 8 {
    let byte = (self.bit_buffer & 0xffU).to_byte()
    self.bit_buffer = self.bit_buffer >> 8
    self.bit_count -= 8
    (start, byte)
  } else {
    (start + 1, input[start])
  }
}

///|
fn Decoder::read_aligned_uint32_le(
  self : Decoder,
  input : Bytes,
  start : Int,
) -> (Int, UInt) {
  let (index, b0) = self.read_aligned_byte(input, start)
  let (index, b1) = self.read_aligned_byte(input, index)
  let (index, b2) = self.read_aligned_byte(input, index)
  let (index, b3) = self.read_aligned_byte(input, index)
  let value = b0.to_uint() |
    (b1.to_uint() << 8) |
    (b2.to_uint() << 16) |
    (b3.to_uint() << 24)
  (index, value)
}

///|
fn Decoder::finish_trailer(
  self : Decoder,
  input : Bytes,
  start : Int,
) -> Int raise {
  let (index, crc32) = self.read_aligned_uint32_le(input, start)
  let (index, input_size) = self.read_aligned_uint32_le(input, index)
  let expected = self.trailer_state.snapshot()
  guard crc32 == expected.crc32 else {
    raise InvalidTrailer("gzip trailer CRC32 mismatch")
  }
  guard input_size == expected.input_size else {
    raise InvalidTrailer("gzip trailer input size mismatch")
  }
  self.mode = Finished
  index
}

///|
fn Decoder::ensure_bits(
  self : Decoder,
  input : Bytes,
  start : Int,
  end : Int,
  count : Int,
  allow_eof~ : Bool,
) -> (Int, Bool) raise {
  let mut index = start
  while self.bit_count < count {
    if index >= end {
      guard allow_eof else {
        raise InvalidBlock("unexpected EOF in compressed data")
      }
      return (index, false)
    }
    self.bit_buffer = self.bit_buffer |
      (input[index].to_uint() << self.bit_count)
    self.bit_count += 8
    index += 1
  }
  (index, true)
}

///|
fn Decoder::read_bits(
  self : Decoder,
  input : Bytes,
  start : Int,
  end : Int,
  count : Int,
) -> (Int, UInt) raise {
  let (index, _) = self.ensure_bits(input, start, end, count, allow_eof=false)
  let mask = if count == 32 { 0xffffffffU } else { (1U << count) - 1U }
  let bits = self.bit_buffer & mask
  self.bit_buffer = self.bit_buffer >> count
  self.bit_count -= count
  (index, bits)
}

///|
fn Decoder::start_next_block(
  self : Decoder,
  input : Bytes,
  start : Int,
  end : Int,
) -> Int raise {
  let (index, header) = self.read_bits(input, start, end, 3)
  let is_final = (header & 1U) == 1U
  let block_type = (header >> 1).reinterpret_as_int()
  match block_type {
    0 => {
      self.align_to_byte()
      self.mode = StoredLengths(is_final~)
      index
    }
    1 => {
      self.mode = HuffmanBlock(
        is_final~,
        literal_tree=fixed_literal_tree,
        distance_tree=fixed_distance_tree,
      )
      index
    }
    2 => {
      self.mode = DynamicHeader(is_final~)
      index
    }
    _ => raise InvalidBlock("invalid block type")
  }
}

///|
fn Decoder::continue_copy(
  self : Decoder,
  output : FixedArray[Byte],
  output_offset : Int,
  produced : Int,
  output_len : Int,
) -> Int raise {
  ignore(self.history_index(self.copy_distance))
  let max_len = @cmp.minimum(
    Decoder::available_output(output_len, produced),
    self.copy_remaining,
  )
  for written = 0; written < max_len && self.copy_remaining > 0; {
    let src_index = self.history_index(self.copy_distance)
    let chunk = @cmp.minimum(
      @cmp.minimum(max_len - written, self.copy_remaining),
      @cmp.minimum(self.copy_distance, 32768 - src_index),
    )
    self.history.blit_to(
      output,
      src_offset=src_index,
      dst_offset=output_offset + produced + written,
      len=chunk,
    )
    self.append_history_bytes(output, output_offset + produced + written, chunk)
    self.copy_remaining -= chunk
    continue written + chunk
  } nobreak {
    if written > 0 {
      self.trailer_state.update(
        output.unsafe_reinterpret_as_bytes()[output_offset + produced:output_offset +
        produced +
        written],
      )
    }
    if self.copy_remaining == 0 {
      self.copy_distance = 0
    }
    written
  }
}

///|
fn Decoder::decode_symbol(
  self : Decoder,
  input : Bytes,
  start : Int,
  end : Int,
  tree : HuffmanTree,
) -> (Int, Int) raise {
  let mut index = start
  for ;; {
    let (next_index, _) = self.ensure_bits(
      input,
      index,
      end,
      tree.max_bits,
      allow_eof=true,
    )
    index = next_index
    let lookup = (self.bit_buffer & ((1U << tree.max_bits) - 1U)).reinterpret_as_int()
    let packed = tree.table[lookup]
    let bit_len = packed & 0x1f
    if bit_len > 0 && bit_len <= self.bit_count {
      self.bit_buffer = self.bit_buffer >> bit_len
      self.bit_count -= bit_len
      return (index, packed >> 5)
    }
    guard self.bit_count < tree.max_bits else {
      raise InvalidBlock("invalid huffman code")
    }
    let prev_bits = self.bit_count
    let (next_index, has_more) = self.ensure_bits(
      input,
      index,
      end,
      prev_bits + 1,
      allow_eof=true,
    )
    index = next_index
    if !has_more && self.bit_count <= prev_bits {
      raise InvalidBlock("unexpected EOF in huffman block")
    }
  }
}

///|
fn Decoder::read_length(
  self : Decoder,
  input : Bytes,
  start : Int,
  end : Int,
  symbol : Int,
) -> (Int, Int) raise {
  let index = symbol - 257
  guard index >= 0 && index < length_bases.length() else {
    raise InvalidBlock("invalid literal/length code")
  }
  let extra_bits = length_extras[index]
  if extra_bits == 0 {
    (start, length_bases[index])
  } else {
    let (next, extra) = self.read_bits(input, start, end, extra_bits)
    (next, length_bases[index] + extra.reinterpret_as_int())
  }
}

///|
fn Decoder::read_distance(
  self : Decoder,
  input : Bytes,
  start : Int,
  end : Int,
  symbol : Int,
) -> (Int, Int) raise {
  guard symbol >= 0 && symbol < distance_bases.length() else {
    raise InvalidBlock("invalid distance code")
  }
  let extra_bits = distance_extras[symbol]
  if extra_bits == 0 {
    (start, distance_bases[symbol])
  } else {
    let (next, extra) = self.read_bits(input, start, end, extra_bits)
    (next, distance_bases[symbol] + extra.reinterpret_as_int())
  }
}

///|
fn Decoder::decode_huffman_step(
  self : Decoder,
  input : Bytes,
  start : Int,
  end : Int,
  is_final~ : Bool,
  literal_tree~ : HuffmanTree,
  distance_tree~ : HuffmanTree,
) -> Int raise {
  let (index, symbol) = self.decode_symbol(input, start, end, literal_tree)
  match symbol {
    0..=255 => {
      self.copy_remaining = -symbol - 1
      self.copy_distance = 0
      index
    }
    256 => {
      if is_final {
        self.begin_trailer()
      } else {
        self.mode = Blocks
      }
      index
    }
    _ => {
      let (index, length) = self.read_length(input, index, end, symbol)
      let (index, distance_symbol) = self.decode_symbol(
        input, index, end, distance_tree,
      )
      let (index, distance) = self.read_distance(
        input, index, end, distance_symbol,
      )
      self.copy_remaining = length
      self.copy_distance = distance
      index
    }
  }
}

///|
fn Decoder::read_stored_from_input(
  self : Decoder,
  input : Bytes,
  start : Int,
  end : Int,
  is_final~ : Bool,
  remaining~ : Int,
  output : FixedArray[Byte],
  output_offset : Int,
  produced : Int,
  output_len : Int,
) -> (Int, Int) {
  let len = @cmp.minimum(
    @cmp.minimum(Decoder::available_output(output_len, produced), remaining),
    end - start,
  )
  guard len > 0 else { return (start, 0) }
  output.blit_from_bytes(output_offset + produced, input, start, len)
  self.append_history_bytes(output, output_offset + produced, len)
  self.trailer_state.update(
    output.unsafe_reinterpret_as_bytes()[output_offset + produced:output_offset +
    produced +
    len],
  )
  let remaining = remaining - len
  if remaining == 0 {
    if is_final {
      self.begin_trailer()
    } else {
      self.mode = Blocks
    }
  } else {
    self.mode = StoredBlock(is_final~, remaining~)
  }
  (start + len, len)
}

///|
/// Decode compressed input into `output`.
/// The caller must provide at least `minimum_input_size()` bytes of input and a
/// non-empty output buffer. The result is `(consumed, produced)`,
/// where `consumed` is the number of bytes consumed from the input
/// and `produced` is the number of bytes written to the output.
/// `produced == 0` is allowed: it means the call only advanced decoder state,
/// for example by reading a block header, stored lengths, or the trailer.
/// EOF should be checked explicitly via `is_finished`.
fn Decoder::write_direct(
  self : Decoder,
  input : Bytes,
  output : FixedArray[Byte],
  input_offset? : Int = 0,
  input_len? : Int = input.length() - input_offset,
  output_offset? : Int = 0,
  output_len? : Int = output.length() - output_offset,
) -> (Int, Int) raise {
  let end = input_offset + input_len
  let mut index = input_offset
  let mut produced = 0
  for ;; {
    if Decoder::available_output(output_len, produced) == 0 {
      break
    }
    match self.mode {
      Header => {
        if end - index < self.raw_minimum_input_size() {
          break
        }
        index = self.finish_header(input, index)
        if self.mode is Header || index >= end {
          break
        }
      }
      DynamicHeader(is_final~) => {
        if end - index < self.raw_minimum_input_size() {
          break
        }
        index = self.finish_dynamic_header(input, index, end, is_final~)
        if self.mode is DynamicHeader(_) || index >= end {
          break
        }
      }
      DynamicCodeLengths(
        is_final~,
        hlit~,
        hdist~,
        hclen~,
        index=length_index,
        code_lengths~
      ) => {
        if end - index < self.raw_minimum_input_size() {
          break
        }
        index = self.finish_dynamic_code_lengths(
          input,
          index,
          end,
          is_final~,
          hlit~,
          hdist~,
          hclen~,
          code_lengths,
          length_index~,
        )
        if self.mode is DynamicCodeLengths(..) || index >= end {
          break
        }
      }
      DynamicLengths(
        is_final~,
        hlit~,
        hdist~,
        code_tree~,
        index=length_index,
        previous~,
        lengths~
      ) => {
        if end - index < self.raw_minimum_input_size() {
          break
        }
        index = self.decode_dynamic_length_step(
          input,
          index,
          end,
          is_final~,
          hlit~,
          hdist~,
          code_tree~,
          lengths,
          length_index~,
          previous~,
        )
        if self.mode is DynamicLengths(..) || index >= end {
          break
        }
      }
      StoredLengths(is_final~) => {
        if end - index < self.raw_minimum_input_size() {
          break
        }
        index = self.finish_stored_header(input, index, is_final~)
        if self.mode is StoredLengths(_) || index >= end {
          break
        }
      }
      StoredBlock(is_final~, remaining~) => {
        let (next, written) = self.read_stored_from_input(
          input,
          index,
          end,
          is_final~,
          remaining~,
          output,
          output_offset,
          produced,
          output_len,
        )
        if next == index {
          break
        }
        index = next
        produced += written
        continue
      }
      HuffmanBlock(is_final~, literal_tree~, distance_tree~) => {
        if self.copy_remaining > 0 {
          let written = self.continue_copy(
            output, output_offset, produced, output_len,
          )
          if written == 0 {
            break
          }
          produced += written
          continue
        }
        if self.copy_remaining < 0 {
          produced = self.write_output_byte(
            output,
            output_offset,
            produced,
            (-self.copy_remaining - 1).to_byte(),
          )
          self.copy_remaining = 0
          continue
        }
        if end - index < self.minimum_huffman_input_size() {
          break
        }
        index = self.decode_huffman_step(
          input,
          index,
          end,
          is_final~,
          literal_tree~,
          distance_tree~,
        )
      }
      Trailer => {
        if end - index < self.raw_minimum_input_size() {
          break
        }
        index = self.finish_trailer(input, index)
        if self.mode is Trailer || index >= end {
          break
        }
      }
      Finished => break
      Blocks => {
        if index >= end {
          break
        }
        index = self.start_next_block(input, index, end)
      }
    }
  }
  (index - input_offset, produced)
}

///|
/// Decode compressed input into `output`.
/// The caller must provide at least `minimum_input_size()` bytes of input and a
/// non-empty output buffer. The result is `(consumed, produced)`,
/// where `consumed` is the number of bytes consumed from the input
/// and `produced` is the number of bytes written to the output.
/// `produced == 0` is allowed: it means the call only advanced decoder state,
/// for example by reading a block header, stored lengths, or the trailer.
/// EOF should be checked explicitly via `is_finished`.
pub fn Decoder::write(
  self : Decoder,
  input : Bytes,
  output : FixedArray[Byte],
  input_offset? : Int = 0,
  input_len? : Int = input.length() - input_offset,
  output_offset? : Int = 0,
  output_len? : Int = output.length() - output_offset,
) -> (Int, Int) raise {
  if self.pending_len == 0 {
    return self.write_direct(
      input,
      output,
      input_offset~,
      input_len~,
      output_offset~,
      output_len~,
    )
  }
  let needed = self.raw_minimum_input_size()
  let copied = @cmp.maximum(0, needed - self.pending_len)
  if copied > 0 {
    self.copy_to_pending(input, input_offset, copied)
  }
  let (pending_consumed, produced) = self.write_direct(
    self.pending_buf.unsafe_reinterpret_as_bytes(),
    output,
    input_offset=0,
    input_len=self.pending_len,
    output_offset~,
    output_len~,
  )
  self.drop_pending(pending_consumed)
  (copied, produced)
}
