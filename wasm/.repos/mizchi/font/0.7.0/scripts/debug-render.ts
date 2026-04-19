import { readFileSync, writeFileSync } from "node:fs";
import { resolve, dirname } from "node:path";
import { fileURLToPath } from "node:url";

const __dirname = dirname(fileURLToPath(import.meta.url));

async function main() {
  const fontPath =
    process.argv[2] || resolve(__dirname, "../fixtures/NotoSansMono-Regular.ttf");
  const text = process.argv[3] || "Hello, World!";
  const fontSize = Number(process.argv[4]) || 48;
  const outputPath = process.argv[5] || resolve(__dirname, "../debug-output.svg");

  // Load compiled MoonBit module
  const mod = await import(
    resolve(__dirname, "../target/js/release/build/js/js.js")
  );

  // Read font file
  const fontData = readFileSync(fontPath);
  const fontBytes = new Uint8Array(fontData);

  // Load font
  const info = mod.loadFont(fontBytes);
  if (!info) {
    console.error("Failed to parse font");
    process.exit(1);
  }
  const fontInfo = JSON.parse(info);
  console.log("Font info:", fontInfo);

  // Generate SVG paths for each character
  const paths: { d: string; x: number }[] = [];
  let cursorX = 10; // left margin
  const baselineY = fontSize + 10; // top margin + ascent

  for (let i = 0; i < text.length; i++) {
    const codepoint = text.codePointAt(i)!;
    const d = mod.glyphToSvgPath(codepoint, fontSize);
    const advance = mod.glyphAdvance(codepoint, fontSize);

    if (d) {
      paths.push({ d, x: cursorX });
    }
    cursorX += advance;
  }

  // Build SVG
  const width = Math.ceil(cursorX + 10);
  const height = Math.ceil(fontSize * 1.5 + 20);

  let svg = `<?xml version="1.0" encoding="UTF-8"?>
<svg xmlns="http://www.w3.org/2000/svg" width="${width}" height="${height}" viewBox="0 0 ${width} ${height}">
  <rect width="100%" height="100%" fill="white"/>
  <!-- baseline -->
  <line x1="0" y1="${baselineY}" x2="${width}" y2="${baselineY}" stroke="#ccc" stroke-width="0.5"/>
`;

  for (const { d, x } of paths) {
    // Translate each glyph to its position
    svg += `  <path d="${d}" fill="black" transform="translate(${x}, ${baselineY})"/>\n`;
  }

  svg += `</svg>\n`;

  writeFileSync(outputPath, svg);
  console.log(`SVG written to: ${outputPath}`);
  console.log(`Text: "${text}", Font size: ${fontSize}, Glyphs: ${paths.length}`);
}

main();
