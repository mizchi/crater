#!/usr/bin/env node --experimental-strip-types
/**
 * Generate MoonBit test code from html5lib-tests tree-construction fixtures
 *
 * Usage:
 *   npm run gen-html5lib-tests -- [options]
 *
 * Options:
 *   --limit=N     Limit number of tests per file (default: all)
 *   --file=NAME   Process only specific .dat file
 *   --simple      Only process simple tests (no nested structures)
 */

import * as fs from 'fs';
import * as path from 'path';

const TREE_CONSTRUCTION_DIR = 'tests/html5lib-tests/tree-construction';
const OUTPUT_FILE = 'html/html5lib_test.mbt';

interface TreeConstructionTest {
  name: string;
  data: string;
  errors: string[];
  document: string;
  fragment?: string;
  scriptOff?: boolean;
  scriptOn?: boolean;
}

/**
 * Parse a .dat file containing tree-construction tests
 */
function parseDatFile(content: string, filename: string): TreeConstructionTest[] {
  const tests: TreeConstructionTest[] = [];
  const sections = content.split(/\n(?=#data\n)/);

  for (let i = 0; i < sections.length; i++) {
    const section = sections[i].trim();
    if (!section.startsWith('#data')) continue;

    const test = parseTestSection(section, `${filename}_${i}`);
    if (test) {
      tests.push(test);
    }
  }

  return tests;
}

function parseTestSection(section: string, defaultName: string): TreeConstructionTest | null {
  const lines = section.split('\n');
  let mode: 'data' | 'errors' | 'new-errors' | 'document' | 'document-fragment' | 'script-off' | 'script-on' | null = null;

  let data = '';
  const errors: string[] = [];
  let document = '';
  let fragment: string | undefined;
  let scriptOff = false;
  let scriptOn = false;

  for (const line of lines) {
    if (line === '#data') {
      mode = 'data';
      continue;
    } else if (line === '#errors') {
      mode = 'errors';
      continue;
    } else if (line === '#new-errors') {
      mode = 'new-errors';
      continue;
    } else if (line === '#document') {
      mode = 'document';
      continue;
    } else if (line.startsWith('#document-fragment')) {
      mode = 'document-fragment';
      fragment = line.replace('#document-fragment', '').trim();
      continue;
    } else if (line === '#script-off') {
      scriptOff = true;
      continue;
    } else if (line === '#script-on') {
      scriptOn = true;
      continue;
    }

    switch (mode) {
      case 'data':
        data += (data ? '\n' : '') + line;
        break;
      case 'errors':
      case 'new-errors':
        if (line.trim()) {
          errors.push(line.trim());
        }
        break;
      case 'document':
        document += (document ? '\n' : '') + line;
        break;
    }
  }

  if (!data && !document) {
    return null;
  }

  return {
    name: defaultName,
    data,
    errors,
    document,
    fragment,
    scriptOff,
    scriptOn,
  };
}

/**
 * Parse expected document tree from html5lib format
 * Format: "| <tag>" with 2-space indentation per level
 */
interface ExpectedNode {
  type: 'element' | 'text' | 'comment' | 'doctype';
  tag?: string;
  text?: string;
  attributes?: Record<string, string>;
  children: ExpectedNode[];
  indent: number;
}

function parseExpectedDocument(doc: string): ExpectedNode[] {
  const lines = doc.split('\n').filter(l => l.startsWith('|'));
  const result: ExpectedNode[] = [];
  const stack: ExpectedNode[] = [];

  for (const line of lines) {
    // Count indent (each level is 2 spaces after "|")
    const match = line.match(/^\|( *)/);
    if (!match) continue;

    const indent = match[1].length;
    const content = line.slice(1 + indent).trim();

    if (!content) continue;

    const node = parseNodeContent(content, indent);
    if (!node) continue;

    // Pop stack to find parent
    while (stack.length > 0 && stack[stack.length - 1].indent >= indent) {
      stack.pop();
    }

    if (stack.length === 0) {
      result.push(node);
    } else {
      const parent = stack[stack.length - 1];
      parent.children.push(node);
    }

    // Only elements can have children
    if (node.type === 'element') {
      stack.push(node);
    }
  }

  return result;
}

function parseNodeContent(content: string, indent: number): ExpectedNode | null {
  // Text node: "text content"
  if (content.startsWith('"') && content.endsWith('"')) {
    return {
      type: 'text',
      text: content.slice(1, -1),
      children: [],
      indent,
    };
  }

  // Comment: <!-- comment -->
  if (content.startsWith('<!-- ')) {
    const endIndex = content.indexOf(' -->');
    const text = endIndex >= 0 ? content.slice(5, endIndex) : content.slice(5);
    return {
      type: 'comment',
      text,
      children: [],
      indent,
    };
  }

  // DOCTYPE: <!DOCTYPE html>
  if (content.startsWith('<!DOCTYPE')) {
    return {
      type: 'doctype',
      text: content,
      children: [],
      indent,
    };
  }

  // Element: <tag>
  if (content.startsWith('<') && !content.startsWith('<!')) {
    const tagMatch = content.match(/^<([a-zA-Z0-9:-]+)/);
    if (tagMatch) {
      return {
        type: 'element',
        tag: tagMatch[1].toLowerCase(),
        children: [],
        indent,
      };
    }
  }

  // Attribute (not a node, skip)
  return null;
}

/**
 * Find body node in expected tree
 */
function findBodyNode(nodes: ExpectedNode[]): ExpectedNode | null {
  for (const node of nodes) {
    if (node.type === 'element' && node.tag === 'html') {
      for (const child of node.children) {
        if (child.type === 'element' && child.tag === 'body') {
          return child;
        }
      }
    }
    if (node.type === 'element' && node.tag === 'body') {
      return node;
    }
  }
  return null;
}

/**
 * Generate assertions for comparing DOM tree
 */
function generateNodeAssertions(
  node: ExpectedNode,
  path: string,
  assertions: string[],
  depth: number = 0
): void {
  if (depth > 3) return; // Limit depth to avoid overly complex tests

  if (node.type === 'element') {
    assertions.push(`inspect(${path}.tag, content="${node.tag}")`);

    // Check children count
    const elementChildren = node.children.filter(c => c.type === 'element');
    const textChildren = node.children.filter(c => c.type === 'text');

    if (elementChildren.length > 0 && depth < 2) {
      // Check first few element children
      for (let i = 0; i < Math.min(elementChildren.length, 2); i++) {
        const childPath = `${path}_child${i}`;
        assertions.push(`let ${childPath} = match ${path}.children[${i}] {`);
        assertions.push(`  @html.Node::Element(e) => e`);
        assertions.push(`  _ => panic()`);
        assertions.push(`}`);
        generateNodeAssertions(elementChildren[i], childPath, assertions, depth + 1);
      }
    }
  } else if (node.type === 'text' && node.text) {
    // For text nodes, we just note what text is expected
    assertions.push(`// Expected text: "${escapeForComment(node.text)}"`);
  }
}

function escapeForComment(s: string): string {
  return s.replace(/"/g, '\\"').replace(/\n/g, '\\n');
}

/**
 * Generate MoonBit test code
 */
function generateMoonBitTest(test: TreeConstructionTest, index: number): string | null {
  // Skip fragment tests for now
  if (test.fragment) {
    return null;
  }

  // Skip script-specific tests
  if (test.scriptOn || test.scriptOff) {
    return null;
  }

  // Skip tests with null bytes or complex unicode
  if (test.data.includes('\0') || test.data.includes('\uFFFD')) {
    return null;
  }

  const testName = sanitizeTestName(test.name);
  const escapedData = escapeString(test.data);

  // Parse expected document to understand structure
  const expected = parseExpectedDocument(test.document);
  const bodyNode = findBodyNode(expected);

  if (!bodyNode) {
    return null;
  }

  // Generate assertions
  const assertions: string[] = [];

  // Count expected element children in body
  const elementChildren = bodyNode.children.filter(c => c.type === 'element');
  const textChildren = bodyNode.children.filter(c => c.type === 'text');

  if (elementChildren.length === 0 && textChildren.length === 0) {
    return null;
  }

  // Basic structure check
  assertions.push(`// Body should have ${bodyNode.children.length} children`);

  // Find actual body in result
  assertions.push(`let body = find_body(result)`);

  // Check first element child if exists
  if (elementChildren.length > 0) {
    const first = elementChildren[0];
    assertions.push(`match body.children[0] {`);
    assertions.push(`  @html.Node::Element(e) => inspect(e.tag, content="${first.tag}")`);
    assertions.push(`  @html.Node::Text(_) => ()`);
    assertions.push(`}`);
  }

  return `
///|
test "html5lib/${testName}" {
  let html = ${escapedData}
  let result = @html.parse_fragment(html)
  ${assertions.join('\n  ')}
}
`;
}

function sanitizeTestName(name: string): string {
  return name
    .replace(/[^a-zA-Z0-9_]/g, '_')
    .replace(/_+/g, '_')
    .replace(/^_|_$/g, '')
    .toLowerCase();
}

function escapeString(s: string): string {
  // Check if we need multi-line string
  if (s.includes('\n')) {
    const lines = s.split('\n');
    return lines.map(l => `#|${l}`).join('\n  ');
  }
  // Escape special characters
  return `"${s.replace(/\\/g, '\\\\').replace(/"/g, '\\"')}"`;
}

/**
 * Generate helper functions for tests
 */
function generateHelpers(): string {
  return `
///|
/// Helper to find body element in parsed tree
fn find_body(elem : @html.Element) -> @html.Element {
  // If the element is body, return it
  if elem.tag == "body" {
    return elem
  }
  // If the element is html, look for body child
  if elem.tag == "html" {
    for child in elem.children {
      match child {
        @html.Node::Element(e) => {
          if e.tag == "body" {
            return e
          }
        }
        _ => ()
      }
    }
  }
  // Search recursively
  for child in elem.children {
    match child {
      @html.Node::Element(e) => {
        let found = find_body(e)
        if found.tag == "body" {
          return found
        }
      }
      _ => ()
    }
  }
  // Return a dummy body if not found
  elem
}
`;
}

/**
 * Main function
 */
function main() {
  const args = process.argv.slice(2);
  let limit = 50; // Default limit
  let fileFilter: string | null = null;
  let simpleOnly = false;

  for (const arg of args) {
    if (arg.startsWith('--limit=')) {
      limit = parseInt(arg.slice(8), 10);
    } else if (arg.startsWith('--file=')) {
      fileFilter = arg.slice(7);
    } else if (arg === '--simple') {
      simpleOnly = true;
    }
  }

  // Process specific useful test files
  const priorityFiles = [
    'tests1.dat',    // Basic tests
    'tests2.dat',
    'tests3.dat',
    'tests4.dat',
    'comments01.dat', // Comment handling
    'doctype01.dat',  // DOCTYPE handling
    'entities01.dat', // Entity handling
    'entities02.dat',
  ];

  const datFiles = fs.readdirSync(TREE_CONSTRUCTION_DIR)
    .filter(f => f.endsWith('.dat'))
    .filter(f => !fileFilter || f === fileFilter || f === `${fileFilter}.dat`)
    .sort((a, b) => {
      const aIdx = priorityFiles.indexOf(a);
      const bIdx = priorityFiles.indexOf(b);
      if (aIdx >= 0 && bIdx >= 0) return aIdx - bIdx;
      if (aIdx >= 0) return -1;
      if (bIdx >= 0) return 1;
      return a.localeCompare(b);
    });

  console.log(`Found ${datFiles.length} .dat files`);

  const stats = {
    total: 0,
    skipped: 0,
    generated: 0,
  };

  const testCodes: string[] = [];

  for (const datFile of datFiles) {
    const filePath = path.join(TREE_CONSTRUCTION_DIR, datFile);
    const content = fs.readFileSync(filePath, 'utf-8');
    const tests = parseDatFile(content, datFile.replace('.dat', ''));

    console.log(`  ${datFile}: ${tests.length} tests`);
    stats.total += tests.length;

    for (const test of tests) {
      if (testCodes.length >= limit) break;

      const code = generateMoonBitTest(test, testCodes.length);
      if (code) {
        testCodes.push(code);
        stats.generated++;
      } else {
        stats.skipped++;
      }
    }

    if (testCodes.length >= limit) break;
  }

  // Generate MoonBit test file
  const header = `///|
/// Auto-generated tests from html5lib-tests/tree-construction
/// Do not edit manually - regenerate with:
///   npm run gen-html5lib-tests
///
`;

  const output = header + generateHelpers() + testCodes.join('\n');
  fs.writeFileSync(OUTPUT_FILE, output);

  console.log(`\nGenerated ${OUTPUT_FILE}`);
  console.log(`  Total tests: ${stats.total}`);
  console.log(`  Generated: ${stats.generated}`);
  console.log(`  Skipped: ${stats.skipped}`);
}

main();
