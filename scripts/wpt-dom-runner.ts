/**
 * WPT DOM Test Runner for Crater
 *
 * Runs WPT DOM tests against Crater's mock DOM implementation.
 *
 * Usage:
 *   npx tsx scripts/wpt-dom-runner.ts wpt/dom/nodes/Document-createTextNode.html
 *   npx tsx scripts/wpt-dom-runner.ts --list
 *   npx tsx scripts/wpt-dom-runner.ts --all
 */

import vm from 'vm';
import fs from 'fs';
import path from 'path';

// Test result types
interface TestResult {
  name: string;
  status: 'pass' | 'fail' | 'error' | 'timeout';
  message?: string;
}

interface TestFileResult {
  file: string;
  tests: TestResult[];
  passed: number;
  failed: number;
  errors: number;
}

// Read mock DOM setup from js_runtime_quickjs.mbt
function extractMockDomSetup(): string {
  const mbtPath = path.join(process.cwd(), 'browser/src/js/js_runtime_quickjs.mbt');
  const content = fs.readFileSync(mbtPath, 'utf-8');

  // Extract setupCode from the file
  const match = content.match(/const setupCode = `([\s\S]*?)`;/);
  if (!match) {
    throw new Error('Could not find setupCode in js_runtime_quickjs.mbt');
  }

  // The setupCode in the MBT file uses #| prefixes, we need to clean it
  // Actually the setupCode is a template literal, let's extract it differently
  const setupStart = content.indexOf('const setupCode = `');
  if (setupStart === -1) {
    throw new Error('Could not find setupCode start');
  }

  // Find the matching backtick
  let depth = 0;
  let inString = false;
  let setupEnd = setupStart + 'const setupCode = `'.length;

  for (let i = setupEnd; i < content.length; i++) {
    const char = content[i];
    const prevChar = content[i - 1];

    if (char === '`' && prevChar !== '\\') {
      // Found closing backtick
      setupEnd = i;
      break;
    }
  }

  let setupCode = content.slice(setupStart + 'const setupCode = `'.length, setupEnd);

  // Clean up #| prefixes used in MoonBit raw strings
  setupCode = setupCode.replace(/^  #\| ?/gm, '');

  return setupCode;
}

// Minimal testharness.js implementation
function createTestHarness() {
  return `
    const __tests = [];
    const __results = [];
    let __currentTest = null;

    // DOMException class
    function DOMException(message, name) {
      this.message = message || '';
      this.name = name || 'Error';
      this.code = DOMException[name] || 0;
    }
    DOMException.prototype = Object.create(Error.prototype);
    DOMException.prototype.constructor = DOMException;
    DOMException.INDEX_SIZE_ERR = 1;
    DOMException.DOMSTRING_SIZE_ERR = 2;
    DOMException.HIERARCHY_REQUEST_ERR = 3;
    DOMException.WRONG_DOCUMENT_ERR = 4;
    DOMException.INVALID_CHARACTER_ERR = 5;
    DOMException.NO_DATA_ALLOWED_ERR = 6;
    DOMException.NO_MODIFICATION_ALLOWED_ERR = 7;
    DOMException.NOT_FOUND_ERR = 8;
    DOMException.NOT_SUPPORTED_ERR = 9;
    DOMException.INUSE_ATTRIBUTE_ERR = 10;
    DOMException.INVALID_STATE_ERR = 11;
    DOMException.SYNTAX_ERR = 12;
    DOMException.INVALID_MODIFICATION_ERR = 13;
    DOMException.NAMESPACE_ERR = 14;
    DOMException.INVALID_ACCESS_ERR = 15;
    DOMException.VALIDATION_ERR = 16;
    DOMException.TYPE_MISMATCH_ERR = 17;
    DOMException.SECURITY_ERR = 18;
    DOMException.NETWORK_ERR = 19;
    DOMException.ABORT_ERR = 20;
    DOMException.URL_MISMATCH_ERR = 21;
    DOMException.QUOTA_EXCEEDED_ERR = 22;
    DOMException.TIMEOUT_ERR = 23;
    DOMException.INVALID_NODE_TYPE_ERR = 24;
    DOMException.DATA_CLONE_ERR = 25;
    // Name to code mapping
    DOMException.IndexSizeError = 1;
    DOMException.HierarchyRequestError = 3;
    DOMException.WrongDocumentError = 4;
    DOMException.InvalidCharacterError = 5;
    DOMException.NoModificationAllowedError = 7;
    DOMException.NotFoundError = 8;
    DOMException.NotSupportedError = 9;
    DOMException.InUseAttributeError = 10;
    DOMException.InvalidStateError = 11;
    DOMException.SyntaxError = 12;
    DOMException.InvalidModificationError = 13;
    DOMException.NamespaceError = 14;
    DOMException.InvalidAccessError = 15;
    DOMException.SecurityError = 18;
    DOMException.NetworkError = 19;
    DOMException.AbortError = 20;
    DOMException.QuotaExceededError = 22;
    DOMException.TimeoutError = 23;
    DOMException.DataCloneError = 25;

    // DOM interface constructors for instanceof checks
    function Node() {}
    // Node type constants
    Node.ELEMENT_NODE = 1;
    Node.ATTRIBUTE_NODE = 2;
    Node.TEXT_NODE = 3;
    Node.CDATA_SECTION_NODE = 4;
    Node.ENTITY_REFERENCE_NODE = 5;
    Node.ENTITY_NODE = 6;
    Node.PROCESSING_INSTRUCTION_NODE = 7;
    Node.COMMENT_NODE = 8;
    Node.DOCUMENT_NODE = 9;
    Node.DOCUMENT_TYPE_NODE = 10;
    Node.DOCUMENT_FRAGMENT_NODE = 11;
    Node.NOTATION_NODE = 12;
    // Document position constants
    Node.DOCUMENT_POSITION_DISCONNECTED = 0x01;
    Node.DOCUMENT_POSITION_PRECEDING = 0x02;
    Node.DOCUMENT_POSITION_FOLLOWING = 0x04;
    Node.DOCUMENT_POSITION_CONTAINS = 0x08;
    Node.DOCUMENT_POSITION_CONTAINED_BY = 0x10;
    Node.DOCUMENT_POSITION_IMPLEMENTATION_SPECIFIC = 0x20;
    // Copy constants to prototype
    Node.prototype.ELEMENT_NODE = 1;
    Node.prototype.ATTRIBUTE_NODE = 2;
    Node.prototype.TEXT_NODE = 3;
    Node.prototype.CDATA_SECTION_NODE = 4;
    Node.prototype.ENTITY_REFERENCE_NODE = 5;
    Node.prototype.ENTITY_NODE = 6;
    Node.prototype.PROCESSING_INSTRUCTION_NODE = 7;
    Node.prototype.COMMENT_NODE = 8;
    Node.prototype.DOCUMENT_NODE = 9;
    Node.prototype.DOCUMENT_TYPE_NODE = 10;
    Node.prototype.DOCUMENT_FRAGMENT_NODE = 11;
    Node.prototype.NOTATION_NODE = 12;
    Node.prototype.DOCUMENT_POSITION_DISCONNECTED = 0x01;
    Node.prototype.DOCUMENT_POSITION_PRECEDING = 0x02;
    Node.prototype.DOCUMENT_POSITION_FOLLOWING = 0x04;
    Node.prototype.DOCUMENT_POSITION_CONTAINS = 0x08;
    Node.prototype.DOCUMENT_POSITION_CONTAINED_BY = 0x10;
    Node.prototype.DOCUMENT_POSITION_IMPLEMENTATION_SPECIFIC = 0x20;

    // CharacterData, Text, Comment are defined in mockDomCode
    // Only define if not already defined (for backwards compatibility)
    if (typeof CharacterData === 'undefined') {
      function CharacterData() {}
      CharacterData.prototype = Object.create(Node.prototype);
    }

    // Text and Comment constructors with proper functionality are defined in mockDomCode
    // Do NOT override them here - just ensure prototype chain is correct
    if (typeof Text !== 'undefined' && Text.prototype) {
      // Ensure Text inherits from CharacterData
      if (Object.getPrototypeOf(Text.prototype) !== CharacterData.prototype) {
        Object.setPrototypeOf(Text.prototype, CharacterData.prototype);
      }
    }

    if (typeof Comment !== 'undefined' && Comment.prototype) {
      // Ensure Comment inherits from CharacterData
      if (Object.getPrototypeOf(Comment.prototype) !== CharacterData.prototype) {
        Object.setPrototypeOf(Comment.prototype, CharacterData.prototype);
      }
    }

    function Element() {}
    Element.prototype = Object.create(Node.prototype);
    Element.prototype.constructor = Element;

    // HTMLElement and subclasses are defined in mockDomCode
    // Just ensure prototype chain is correct
    if (typeof HTMLElement !== 'undefined' && HTMLElement.prototype) {
      if (Object.getPrototypeOf(HTMLElement.prototype) !== Element.prototype) {
        Object.setPrototypeOf(HTMLElement.prototype, Element.prototype);
      }
    }

    function Document() {
      // new Document() creates a Document (not XMLDocument) per spec
      const doc = {
        _nodeType: 9,
        nodeType: 9,
        nodeName: '#document',
        documentElement: null,
        doctype: null,
        _children: [],
        location: null,  // null for documents not associated with browsing context
        URL: 'about:blank',
        documentURI: 'about:blank',
        compatMode: 'CSS1Compat',
        characterSet: 'UTF-8',
        charset: 'UTF-8',
        inputEncoding: 'UTF-8',
        contentType: 'application/xml',
        get firstChild() { return this._children[0] || null; },
        get lastChild() { return this._children[this._children.length - 1] || null; },
        get childNodes() { return this._children; },
        appendChild(child) { this._children.push(child); child._parent = this; child.parentNode = this; if (child._nodeType === 1) this.documentElement = child; return child; },
        removeChild(child) { const idx = this._children.indexOf(child); if (idx >= 0) { this._children.splice(idx, 1); child._parent = null; child.parentNode = null; } return child; },
        // For XML documents (non-HTML), createElement returns Element (not HTMLElement)
        createElement(name) {
          const el = document.createElement(name);
          // XML document: use generic Element prototype, keep localName as-is
          Object.setPrototypeOf(el, Element.prototype);
          el.localName = name;
          return el;
        },
        // createElementNS with HTML namespace returns HTML elements
        createElementNS(ns, name) {
          const el = document.createElementNS(ns, name);
          if (ns === 'http://www.w3.org/1999/xhtml') {
            // HTML element - use appropriate HTML constructor
            const lowerName = name.toLowerCase();
            const Ctor = tagToConstructor[lowerName] || HTMLElement;
            Object.setPrototypeOf(el, Ctor.prototype);
          } else {
            // Non-HTML element
            Object.setPrototypeOf(el, Element.prototype);
          }
          return el;
        },
        createTextNode(text) { return document.createTextNode(text); },
        createComment(text) { return document.createComment(text); },
        createDocumentFragment() { return document.createDocumentFragment(); },
        getRootNode() { return this; },
        isSameNode(other) { return this === other; },
        isEqualNode(other) { return this === other; },
        adoptNode(node) {
          if (!node) return null;
          if (node._nodeType === 9) throw new DOMException('Cannot adopt a document node', 'NotSupportedError');
          if (node._parent) node._parent.removeChild(node);
          node.ownerDocument = this;
          return node;
        }
      };
      Object.setPrototypeOf(doc, Document.prototype);
      return doc;
    }
    Document.prototype = Object.create(Node.prototype);

    function XMLDocument() {}
    XMLDocument.prototype = Object.create(Document.prototype);

    function DocumentFragment() {}
    DocumentFragment.prototype = Object.create(Node.prototype);

    function DocumentType() {}
    DocumentType.prototype = Object.create(Node.prototype);

    function ProcessingInstruction() {}
    ProcessingInstruction.prototype = Object.create(CharacterData.prototype);

    function DOMImplementation() {}

    // Make mock nodes inherit from proper constructors
    const _origCreateMockElement = createMockElement;
    createMockElement = function(tagName, mockId) {
      const el = _origCreateMockElement(tagName, mockId);
      const lowerTag = tagName.toLowerCase();
      const Ctor = tagToConstructor[lowerTag] || HTMLElement;
      Object.setPrototypeOf(el, Ctor.prototype);
      return el;
    };

    const _origCreateMockTextNode = createMockTextNode;
    createMockTextNode = function(text, mockId) {
      const node = _origCreateMockTextNode(text, mockId);
      Object.setPrototypeOf(node, Text.prototype);
      return node;
    };

    const _origCreateMockComment = createMockComment;
    createMockComment = function(text, mockId) {
      const node = _origCreateMockComment(text, mockId);
      Object.setPrototypeOf(node, Comment.prototype);
      return node;
    };

    const _origCreateMockDocumentFragment = createMockDocumentFragment;
    createMockDocumentFragment = function(mockId) {
      const frag = _origCreateMockDocumentFragment(mockId);
      Object.setPrototypeOf(frag, DocumentFragment.prototype);
      return frag;
    };

    const _origCreateMockProcessingInstruction = createMockProcessingInstruction;
    createMockProcessingInstruction = function(target, data, mockId) {
      const node = _origCreateMockProcessingInstruction(target, data, mockId);
      Object.setPrototypeOf(node, ProcessingInstruction.prototype);
      return node;
    };

    // Set document prototype
    Object.setPrototypeOf(document, Document.prototype);

    function test(func, name) {
      const testObj = { name: name || 'unnamed test', func: func };
      __tests.push(testObj);
    }

    function async_test(funcOrName, maybeName) {
      // Form 1: async_test(function, name) - traditional
      // Form 2: async_test(name) - returns test object for step/done pattern
      if (typeof funcOrName === 'function') {
        const testObj = { name: maybeName || 'unnamed async test', func: funcOrName, async: true };
        __tests.push(testObj);
        return testObj;
      } else {
        // Form 2: funcOrName is the test name
        const testObj = {
          name: funcOrName || 'unnamed async test',
          func: null,
          async: true,
          steps: [],
          step: function(f) {
            this.steps.push(f);
            try { f(); } catch(e) { this._error = e; }
          },
          step_func: function(f) {
            const self = this;
            return function() { self.step(function() { f.apply(this, arguments); }); };
          },
          step_func_done: function(f) {
            const self = this;
            return function() {
              self.step(function() { f.apply(this, arguments); });
              self._done = true;
            };
          },
          done: function() { this._done = true; },
          unreached_func: function(msg) { return function() { throw new Error(msg || 'unreached'); }; },
          add_cleanup: function(f) { /* ignored */ }
        };
        __tests.push(testObj);
        return testObj;
      }
    }

    function promise_test(func, name) {
      const testObj = { name: name || 'unnamed promise test', func: func, promise: true };
      __tests.push(testObj);
    }

    function setup(funcOrOptions, maybeOptions) {
      // If first argument is a function, execute it for setup
      if (typeof funcOrOptions === 'function') {
        funcOrOptions();
      }
      // options are ignored
    }

    function done() {
      // Test harness done - ignore
    }

    function format_value(val) {
      if (val === null) return 'null';
      if (val === undefined) return 'undefined';
      if (typeof val === 'string') return '"' + val + '"';
      if (typeof val === 'object') {
        try { return JSON.stringify(val); } catch { return String(val); }
      }
      return String(val);
    }

    function assert_equals(actual, expected, description) {
      if (actual !== expected) {
        throw new Error((description ? description + ': ' : '') +
          'expected ' + format_value(expected) + ' but got ' + format_value(actual));
      }
    }

    function assert_not_equals(actual, expected, description) {
      if (actual === expected) {
        throw new Error((description ? description + ': ' : '') +
          'got disallowed value ' + format_value(actual));
      }
    }

    function assert_true(actual, description) {
      if (actual !== true) {
        throw new Error((description ? description + ': ' : '') +
          'expected true but got ' + format_value(actual));
      }
    }

    function assert_false(actual, description) {
      if (actual !== false) {
        throw new Error((description ? description + ': ' : '') +
          'expected false but got ' + format_value(actual));
      }
    }

    function assert_in_array(actual, expected, description) {
      if (!expected.includes(actual)) {
        throw new Error((description ? description + ': ' : '') +
          format_value(actual) + ' not in ' + format_value(expected));
      }
    }

    function assert_array_equals(actual, expected, description) {
      if (!Array.isArray(actual) || !Array.isArray(expected)) {
        throw new Error((description ? description + ': ' : '') + 'not arrays');
      }
      if (actual.length !== expected.length) {
        throw new Error((description ? description + ': ' : '') +
          'array lengths differ: ' + actual.length + ' vs ' + expected.length);
      }
      for (let i = 0; i < actual.length; i++) {
        if (actual[i] !== expected[i]) {
          throw new Error((description ? description + ': ' : '') +
            'arrays differ at index ' + i + ': ' + format_value(actual[i]) + ' vs ' + format_value(expected[i]));
        }
      }
    }

    function assert_class_string(object, expected, description) {
      const actual = Object.prototype.toString.call(object);
      const expectedStr = '[object ' + expected + ']';
      if (actual !== expectedStr) {
        throw new Error((description ? description + ': ' : '') +
          'expected ' + expectedStr + ' but got ' + actual);
      }
    }

    function assert_throws_js(type, func, description) {
      let threw = false;
      let error = null;
      try {
        func();
      } catch (e) {
        threw = true;
        error = e;
      }
      if (!threw) {
        throw new Error((description ? description + ': ' : '') +
          'expected ' + (type.name || type) + ' to be thrown');
      }
      if (!(error instanceof type)) {
        throw new Error((description ? description + ': ' : '') +
          'expected ' + (type.name || type) + ' but got ' + (error.constructor.name || error));
      }
    }

    function assert_throws_dom(name, func, description) {
      // Map between legacy constant names and new names
      const legacyToName = {
        'INDEX_SIZE_ERR': 'IndexSizeError',
        'HIERARCHY_REQUEST_ERR': 'HierarchyRequestError',
        'WRONG_DOCUMENT_ERR': 'WrongDocumentError',
        'INVALID_CHARACTER_ERR': 'InvalidCharacterError',
        'NOT_FOUND_ERR': 'NotFoundError',
        'NOT_SUPPORTED_ERR': 'NotSupportedError',
        'INVALID_STATE_ERR': 'InvalidStateError',
        'SYNTAX_ERR': 'SyntaxError',
        'INVALID_MODIFICATION_ERR': 'InvalidModificationError',
        'NAMESPACE_ERR': 'NamespaceError'
      };
      const nameToLegacy = {};
      for (const [k, v] of Object.entries(legacyToName)) nameToLegacy[v] = k;

      let threw = false;
      let error = null;
      try {
        func();
      } catch (e) {
        threw = true;
        error = e;
      }
      if (!threw) {
        throw new Error((description ? description + ': ' : '') +
          'expected DOMException ' + name + ' to be thrown');
      }
      // Check if it's a DOMException with the right name
      const expectedName = legacyToName[name] || name;
      const expectedLegacy = nameToLegacy[name] || name;
      if (error.name !== expectedName && error.name !== expectedLegacy &&
          error.name !== name && error.code !== name) {
        throw new Error((description ? description + ': ' : '') +
          'expected DOMException ' + name + ' but got ' + (error.name || error.code || error));
      }
    }

    function assert_throws_exactly(expected, func, description) {
      let threw = false;
      let error = null;
      try {
        func();
      } catch (e) {
        threw = true;
        error = e;
      }
      if (!threw) {
        throw new Error((description ? description + ': ' : '') + 'expected exception');
      }
      if (error !== expected) {
        throw new Error((description ? description + ': ' : '') +
          'expected exactly ' + format_value(expected) + ' but got ' + format_value(error));
      }
    }

    function assert_readonly(object, property, description) {
      const desc = Object.getOwnPropertyDescriptor(object, property);
      if (desc && desc.writable) {
        throw new Error((description ? description + ': ' : '') +
          property + ' is not readonly');
      }
    }

    function assert_own_property(object, property, description) {
      if (!object.hasOwnProperty(property)) {
        throw new Error((description ? description + ': ' : '') +
          'expected own property ' + property);
      }
    }

    function assert_inherits(object, property, description) {
      if (!(property in object)) {
        throw new Error((description ? description + ': ' : '') +
          'expected inherited property ' + property);
      }
      if (object.hasOwnProperty(property)) {
        throw new Error((description ? description + ': ' : '') +
          'property ' + property + ' is own, not inherited');
      }
    }

    function assert_idl_attribute(object, name, description) {
      if (!(name in object)) {
        throw new Error((description ? description + ': ' : '') +
          'expected IDL attribute ' + name);
      }
    }

    function assert_regexp_match(actual, regexp, description) {
      if (!regexp.test(actual)) {
        throw new Error((description ? description + ': ' : '') +
          format_value(actual) + ' does not match ' + regexp);
      }
    }

    function assert_unreached(description) {
      throw new Error((description ? description + ': ' : '') + 'should not be reached');
      }

    // Run all tests and collect results
    function __runTests() {
      for (const t of __tests) {
        try {
          if (t.async) {
            // Form 2: func is null, test was created with just a name
            if (t.func === null) {
              // Steps were already executed when step() was called
              // Check if there was an error
              if (t._error) {
                throw t._error;
              }
              // Test passes if no error occurred
            } else {
              // Form 1: traditional async_test with function
              let completed = false;
              const testContext = {
                step: function(f) { if (typeof f === 'function') f(); },
                step_func: function(f) { return f; },
                step_func_done: function(f) { return function() { f.apply(this, arguments); completed = true; }; },
                done: function() { completed = true; },
                unreached_func: function(msg) { return function() { throw new Error(msg || 'unreached'); }; },
                add_cleanup: function(f) { /* ignored */ }
              };
              // WPT async_test passes test object as first parameter
              t.func(testContext);
            }
          } else if (t.promise) {
            // Skip promise tests for now
            __results.push({ name: t.name, status: 'skip', message: 'promise tests not supported' });
            continue;
          } else {
            t.func();
          }
          __results.push({ name: t.name, status: 'pass' });
        } catch (e) {
          __results.push({ name: t.name, status: 'fail', message: e.message || String(e) });
        }
      }
      return __results;
    }
  `;
}

// Extract test scripts from HTML file
function extractTestScripts(htmlPath: string): { inline: string[]; external: string[] } {
  const content = fs.readFileSync(htmlPath, 'utf-8');
  const htmlDir = path.dirname(htmlPath);

  const inline: string[] = [];
  const external: string[] = [];

  // Extract inline scripts (excluding testharness.js and testharnessreport.js)
  const scriptRegex = /<script[^>]*>([\s\S]*?)<\/script>/gi;
  let match;

  while ((match = scriptRegex.exec(content)) !== null) {
    const tag = match[0];
    const scriptContent = match[1];

    // Check for src attribute
    const srcMatch = tag.match(/src\s*=\s*["']([^"']+)["']/i);
    if (srcMatch) {
      const src = srcMatch[1];
      // Skip testharness files
      if (src.includes('testharness')) continue;

      // Try to load external script
      let scriptPath: string;
      if (src.startsWith('/')) {
        // Absolute path from WPT root
        scriptPath = path.join(process.cwd(), 'wpt', src);
      } else {
        scriptPath = path.join(htmlDir, src);
      }

      if (fs.existsSync(scriptPath)) {
        external.push(fs.readFileSync(scriptPath, 'utf-8'));
      }
    } else if (scriptContent.trim()) {
      inline.push(scriptContent);
    }
  }

  return { inline, external };
}

// Build mock DOM code from the MBT file
function buildMockDomCode(): string {
  // Read the full js_runtime_quickjs.mbt and extract the setup code
  const mbtPath = path.join(process.cwd(), 'browser/src/js/js_runtime_quickjs.mbt');
  const content = fs.readFileSync(mbtPath, 'utf-8');

  // Find all #| lines that form the setup code
  const lines = content.split('\n');
  const setupLines: string[] = [];
  let inSetupCode = false;

  for (const line of lines) {
    if (line.includes('const setupCode = `')) {
      inSetupCode = true;
      continue;
    }
    if (inSetupCode) {
      // Check for end marker: #|   `; (backtick followed by semicolon)
      if (line.trim() === '#|   `;' || line.trim() === '#|  `;') {
        break;
      }
      if (line.trim().startsWith('#|')) {
        // Extract the code after #|
        const codeLine = line.replace(/^\s*#\|\s?/, '');
        setupLines.push(codeLine);
      }
    }
  }

  return setupLines.join('\n');
}

// Run a single test file
function runTestFile(htmlPath: string): TestFileResult {
  const fileName = path.basename(htmlPath);

  try {
    const scripts = extractTestScripts(htmlPath);
    const mockDomCode = buildMockDomCode();
    const testHarness = createTestHarness();

    // Combine all code
    // mockDomCode must come first as it defines document, createMockElement, etc.
    // testHarness augments these with prototype inheritance
    const fullCode = [
      mockDomCode,
      testHarness,
      ...scripts.external,
      ...scripts.inline,
      '__runTests();',
    ].join('\n');

    // Create sandbox context
    const sandbox = {
      console: {
        log: (...args: unknown[]) => {},
        error: (...args: unknown[]) => {},
        warn: (...args: unknown[]) => {},
      },
      setTimeout: (fn: () => void, ms: number) => {
        fn();
        return 0;
      },
      clearTimeout: () => {},
      setInterval: () => 0,
      clearInterval: () => {},
    };

    // Run in VM
    const context = vm.createContext(sandbox);
    const results = vm.runInContext(fullCode, context, {
      timeout: 5000,
      filename: fileName,
    }) as TestResult[];

    const passed = results.filter((r) => r.status === 'pass').length;
    const failed = results.filter((r) => r.status === 'fail').length;
    const errors = results.filter((r) => r.status === 'error').length;

    return { file: fileName, tests: results, passed, failed, errors };
  } catch (error) {
    const message = error instanceof Error ? error.message : String(error);
    return {
      file: fileName,
      tests: [{ name: 'execution', status: 'error', message }],
      passed: 0,
      failed: 0,
      errors: 1,
    };
  }
}

// Get available DOM test files
function getDomTestFiles(): string[] {
  const domDir = path.join(process.cwd(), 'wpt/dom/nodes');
  if (!fs.existsSync(domDir)) {
    return [];
  }

  return fs
    .readdirSync(domDir)
    .filter((f) => f.endsWith('.html'))
    .filter((f) => !f.includes('-ref.html'))
    .map((f) => path.join(domDir, f));
}

// List available tests
function listTests(): void {
  const files = getDomTestFiles();
  console.log(`Available DOM tests: ${files.length}\n`);

  // Group by prefix
  const groups: Record<string, string[]> = {};
  for (const file of files) {
    const name = path.basename(file);
    const prefix = name.split('-')[0];
    if (!groups[prefix]) groups[prefix] = [];
    groups[prefix].push(name);
  }

  for (const [prefix, names] of Object.entries(groups).sort()) {
    console.log(`${prefix}: ${names.length} tests`);
  }
}

// Main
async function main(): Promise<void> {
  const args = process.argv.slice(2);

  if (args.length === 0) {
    console.log('WPT DOM Test Runner for Crater\n');
    console.log('Usage:');
    console.log('  npx tsx scripts/wpt-dom-runner.ts <path/to/test.html>');
    console.log('  npx tsx scripts/wpt-dom-runner.ts --list      # List available tests');
    console.log('  npx tsx scripts/wpt-dom-runner.ts --all       # Run all DOM tests');
    console.log('  npx tsx scripts/wpt-dom-runner.ts Document-*  # Run tests matching pattern');
    return;
  }

  if (args[0] === '--list') {
    listTests();
    return;
  }

  // Collect test files
  let testFiles: string[] = [];

  if (args[0] === '--all') {
    testFiles = getDomTestFiles();
  } else {
    for (const arg of args) {
      if (arg.includes('*')) {
        // Pattern match
        const pattern = arg.replace('*', '');
        testFiles.push(...getDomTestFiles().filter((f) => path.basename(f).includes(pattern)));
      } else if (fs.existsSync(arg)) {
        testFiles.push(arg);
      } else {
        // Try to find in wpt/dom/nodes
        const fullPath = path.join(process.cwd(), 'wpt/dom/nodes', arg);
        if (fs.existsSync(fullPath)) {
          testFiles.push(fullPath);
        } else if (fs.existsSync(fullPath + '.html')) {
          testFiles.push(fullPath + '.html');
        }
      }
    }
  }

  if (testFiles.length === 0) {
    console.error('No test files found');
    process.exit(1);
  }

  console.log(`Running ${testFiles.length} test file(s)...\n`);

  let totalPassed = 0;
  let totalFailed = 0;
  let totalErrors = 0;
  const failedFiles: TestFileResult[] = [];

  for (const file of testFiles) {
    const result = runTestFile(file);

    const icon = result.failed === 0 && result.errors === 0 ? '✓' : '✗';
    console.log(`${icon} ${result.file}: ${result.passed} passed, ${result.failed} failed`);

    totalPassed += result.passed;
    totalFailed += result.failed;
    totalErrors += result.errors;

    if (result.failed > 0 || result.errors > 0) {
      failedFiles.push(result);
    }
  }

  // Print failed test details
  if (failedFiles.length > 0) {
    console.log('\nFailed tests:\n');
    for (const result of failedFiles.slice(0, 10)) {
      console.log(`  ${result.file}:`);
      for (const test of result.tests.filter((t) => t.status !== 'pass').slice(0, 5)) {
        console.log(`    ✗ ${test.name}`);
        if (test.message) {
          console.log(`      ${test.message.slice(0, 100)}`);
        }
      }
      if (result.tests.filter((t) => t.status !== 'pass').length > 5) {
        console.log(`    ... and ${result.tests.filter((t) => t.status !== 'pass').length - 5} more`);
      }
    }
    if (failedFiles.length > 10) {
      console.log(`... and ${failedFiles.length - 10} more failed files`);
    }
  }

  console.log(`\nSummary: ${totalPassed} passed, ${totalFailed} failed, ${totalErrors} errors`);
  process.exit(totalFailed + totalErrors > 0 ? 1 : 0);
}

main().catch(console.error);
