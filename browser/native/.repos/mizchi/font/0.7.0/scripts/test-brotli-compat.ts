import { readFileSync } from "fs";
import { brotliDecompressSync, brotliCompressSync, constants } from "zlib";
import { loadFont, debugWoff2 } from "../target/js/release/build/js/js.mjs";

// We need a way to test brotli directly. Let's use debugWoff2 to exercise brotli
// or we can build a separate test entry point.
// For now, let's just test with the actual WOFF2 file.

const woff2 = readFileSync("test_data/NotoSansMono-Regular.woff2");
console.log("WOFF2 file size:", woff2.length);

// Test debug_woff2 first
const debugResult = debugWoff2(new Uint8Array(woff2));
console.log("debug_woff2 result:");
console.log(debugResult);

console.log("\n---\nTesting loadFont with WOFF2...");
const result = loadFont(new Uint8Array(woff2));
console.log("loadFont result:", result || "(empty - failed)");
