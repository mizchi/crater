import { readFileSync } from "fs";
import { execSync } from "child_process";
import { brotliCompressSync, brotliDecompressSync, constants } from "zlib";
import { join } from "path";

const ROOT = join(import.meta.dirname!, "..");

// Build the JS target first
console.log("Building JS target...");
execSync("moon build --target js", { cwd: ROOT, stdio: "inherit" });

// Import the compiled module
const wasmPath = join(ROOT, "_build/js/release/build/brotli/brotli.js");

// Create test cases
const testCases: { name: string; data: Buffer }[] = [
  { name: "empty", data: Buffer.from("") },
  { name: "Hello", data: Buffer.from("Hello") },
  { name: "Hello, World!", data: Buffer.from("Hello, World!") },
  { name: "repeated-a", data: Buffer.alloc(100, "a") },
  { name: "alphabet-repeated", data: Buffer.from("abcdefghijklmnopqrstuvwxyz".repeat(10)) },
  { name: "json-like", data: Buffer.from(JSON.stringify({ key: "value", num: 42, arr: [1, 2, 3] })) },
];

// Add larger test
const largeText = "The quick brown fox jumps over the lazy dog. ".repeat(100);
testCases.push({ name: "large-text-4.5KB", data: Buffer.from(largeText) });

let passed = 0;
let failed = 0;

for (const tc of testCases) {
  const compressed = brotliCompressSync(tc.data, {
    params: { [constants.BROTLI_PARAM_QUALITY]: 11 },
  });

  // Verify with Node's own decompressor first
  const nodeResult = brotliDecompressSync(compressed);
  if (!nodeResult.equals(tc.data)) {
    console.error(`FAIL [${tc.name}]: Node.js brotli roundtrip failed`);
    failed++;
    continue;
  }

  console.log(
    `  ${tc.name}: original=${tc.data.length}B, compressed=${compressed.length}B`
  );

  // Write compressed data to a temp file for the MoonBit test
  const hexBytes = Array.from(compressed)
    .map((b) => `0x${b.toString(16).padStart(2, "0")}`)
    .join(", ");
  console.log(`    compressed bytes: [${hexBytes.slice(0, 100)}${hexBytes.length > 100 ? "..." : ""}]`);

  passed++;
}

console.log(`\nNode.js brotli compression verification: ${passed} passed, ${failed} failed`);
console.log("\nNote: Full E2E test (MoonBit JS → decompress) requires wasm-gc JS build setup.");
console.log("Unit tests via 'moon test -p mizchi/font/brotli' cover the decompression logic.");
