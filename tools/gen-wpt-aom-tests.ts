/**
 * Generate MoonBit tests from WPT accessibility test files
 *
 * This script reads WPT accessibility tests and generates MoonBit test files
 * for html-aam role mappings and accname tests.
 *
 * Usage:
 *   npx tsx tools/gen-wpt-aom-tests.ts html-aam-roles
 *   npx tsx tools/gen-wpt-aom-tests.ts accname
 */

import * as fs from "fs";
import * as path from "path";

interface TestCase {
  id?: string;
  testName?: string;
  className?: string;
  expectedLabel?: string;
  expectedRole?: string;
}

// Extract CSS rules from HTML <style> block
function extractStyleBlock(html: string): string {
  const styleMatch = html.match(/<style[^>]*>([\s\S]*?)<\/style>/i);
  return styleMatch ? styleMatch[1] : "";
}

// Extract CSS rules that match given class names
function extractRelevantCssRules(cssContent: string, classNames: string[]): string {
  if (!cssContent || classNames.length === 0) {
    return "";
  }

  const rules: string[] = [];
  // Match CSS rules: selector { declarations }
  const ruleRegex = /([^{}]+)\{([^{}]*)\}/g;
  let match;

  while ((match = ruleRegex.exec(cssContent)) !== null) {
    const selector = match[1].trim();
    const declarations = match[2].trim();

    // Check if selector contains any of our class names and is a pseudo-element
    for (const className of classNames) {
      if (selector.includes(`.${className}`) &&
          (selector.includes("::before") || selector.includes("::after") ||
           selector.includes(":before") || selector.includes(":after"))) {
        // Normalize selector - remove complex parts like :dir() that we don't support
        let normalizedSelector = selector
          .replace(/:dir\([^)]*\)/g, "")  // Remove :dir() pseudo-class
          .replace(/:nth-child\([^)]*\)/g, "")  // Remove :nth-child()
          .trim();

        if (normalizedSelector) {
          rules.push(`${normalizedSelector} { ${declarations} }`);
        }
        break;
      }
    }
  }

  return rules.join("\n    ");
}

// Extract class names from an HTML element string
function extractClassNames(html: string): string[] {
  const classMatch = html.match(/class="([^"]+)"/);
  if (!classMatch) return [];
  return classMatch[1].split(/\s+/).filter(c => c && c !== "ex");
}

function escapeString(s: string): string {
  return s
    .replace(/\\/g, "\\\\")
    .replace(/"/g, '\\"')
    .replace(/\n/g, "\\n")
    .replace(/\r/g, "\\r")
    .replace(/\t/g, "\\t");
}

// Determine MoonBit Role for an HTML element string
function getRoleForElement(html: string): string {
  // Extract tag name and type attribute
  let tagMatch = html.match(/^<([a-z][a-z0-9]*)/i);
  let tag = tagMatch ? tagMatch[1].toLowerCase() : "div";

  // For label encapsulation, look for the inner input/select/textarea
  if (tag === "label") {
    const innerInputMatch = html.match(/<input[^>]*type="([^"]+)"/i);
    if (innerInputMatch) {
      tag = "input";
    } else if (html.includes("<select")) {
      tag = "select";
    } else if (html.includes("<textarea")) {
      tag = "textarea";
    }
  }

  // Extract type attribute for input elements
  const typeMatch = html.match(/type="([^"]+)"/i);
  const inputType = typeMatch ? typeMatch[1].toLowerCase() : "text";

  // Extract explicit role
  const roleMatch = html.match(/role="([^"]+)"/i);
  if (roleMatch) {
    const mapped = mapRoleToMoonBit(roleMatch[1]);
    if (mapped) return mapped;
  }

  // Map HTML elements to roles
  switch (tag) {
    case "input":
      switch (inputType) {
        case "checkbox": return "Checkbox";
        case "radio": return "Radio";
        case "button": return "Button";
        case "submit": return "Button";
        case "reset": return "Button";
        case "image": return "Button";
        case "range": return "Slider";
        case "number": return "SpinButton";
        case "search": return "SearchBox";
        case "email":
        case "tel":
        case "url":
        case "text":
        case "password": return "Textbox";
        case "hidden": return "Generic";
        case "color": return "Generic";
        case "date":
        case "datetime-local":
        case "month":
        case "time":
        case "week": return "Generic";
        case "file": return "Generic";
        default: return "Textbox";
      }
    case "button": return "Button";
    case "a": return "Link";
    case "select": return "Combobox";
    case "textarea": return "Textbox";
    case "img": return "Img";
    case "nav": return "Navigation";
    case "main": return "Main";
    case "header": return "Banner";
    case "footer": return "ContentInfo";
    case "aside": return "Complementary";
    case "section": return "Region";
    case "article": return "Article";
    case "form": return "Form";
    case "table": return "Table";
    case "ul":
    case "ol": return "List";
    case "li": return "ListItem";
    case "h1":
    case "h2":
    case "h3":
    case "h4":
    case "h5":
    case "h6": return "Heading";
    default: return "Generic";
  }
}

// Map WPT role names to MoonBit Role enum names
function mapRoleToMoonBit(role: string): string | null {
  const mapping: Record<string, string> = {
    article: "Article",
    blockquote: "Blockquote",
    button: "Button",
    caption: "Caption",
    cell: "Cell",
    checkbox: "Checkbox",
    code: "Code",
    columnheader: "ColumnHeader",
    combobox: "Combobox",
    definition: "Definition",
    deletion: "Deletion",
    dialog: "Dialog",
    directory: "Directory",
    document: "Document",
    emphasis: "Emphasis",
    feed: "Feed",
    figure: "Figure",
    form: "Form",
    generic: "Generic",
    grid: "Grid",
    gridcell: "GridCell",
    group: "Group",
    heading: "Heading",
    image: "Img",
    img: "Img",
    insertion: "Insertion",
    link: "Link",
    list: "List",
    listbox: "Listbox",
    listitem: "ListItem",
    log: "Log",
    main: "Main",
    mark: "Mark",
    marquee: "Marquee",
    math: "Math",
    menu: "Menu",
    menubar: "MenuBar",
    menuitem: "MenuItem",
    menuitemcheckbox: "MenuItemCheckbox",
    menuitemradio: "MenuItemRadio",
    meter: "Meter",
    navigation: "Navigation",
    none: "None",
    note: "Note",
    option: "Option",
    paragraph: "Paragraph",
    presentation: "Presentation",
    progressbar: "Progressbar",
    radio: "Radio",
    radiogroup: "RadioGroup",
    region: "Region",
    row: "Row",
    rowgroup: "RowGroup",
    rowheader: "RowHeader",
    scrollbar: "Scrollbar",
    search: "Search",
    searchbox: "SearchBox",
    separator: "Separator",
    slider: "Slider",
    spinbutton: "SpinButton",
    status: "Status",
    strong: "Strong",
    subscript: "Subscript",
    superscript: "Superscript",
    switch: "Switch",
    tab: "Tab",
    table: "Table",
    tablist: "TabList",
    tabpanel: "TabPanel",
    term: "Term",
    textbox: "Textbox",
    time: "Time",
    timer: "Timer",
    toolbar: "Toolbar",
    tooltip: "Tooltip",
    tree: "Tree",
    treegrid: "TreeGrid",
    treeitem: "TreeItem",
  };
  return mapping[role.toLowerCase()] || null;
}

// Extract minimal HTML for a test element from the full HTML
function extractTestElement(html: string, testName: string): string | null {
  // Escape special regex chars in testName
  const escapedTestName = testName.replace(/[.*+?^${}()|[\]\\]/g, "\\$&");

  // Find the opening tag with the matching data-testname
  const openTagRegex = new RegExp(
    `<([a-z][a-z0-9]*)([^>]*data-testname="${escapedTestName}"[^>]*)>`,
    "i"
  );
  const openMatch = html.match(openTagRegex);
  if (!openMatch) {
    return null;
  }

  const tagName = openMatch[1];
  let startIdx = openMatch.index!;

  // For encapsulation or embedded control tests, we need to include the parent <label> element
  if (testName.includes("encapsulation") || testName.includes("label with embedded")) {
    // Look backwards for the immediately preceding <label> tag (no > between label and input)
    const beforeMatch = html.substring(0, startIdx);
    // Find the last <label> that opens before our element
    const labelMatches = [...beforeMatch.matchAll(/<label[^>]*>/gi)];
    if (labelMatches.length > 0) {
      const lastLabel = labelMatches[labelMatches.length - 1];
      const labelStartIdx = lastLabel.index!;
      // Check if there's a </label> between the label start and our element
      const between = html.substring(labelStartIdx + lastLabel[0].length, startIdx);
      if (!between.includes("</label>")) {
        // Find the closing </label> tag after the input
        const afterInput = html.substring(startIdx);
        const labelCloseMatch = afterInput.match(/<\/label>/i);
        if (labelCloseMatch) {
          const endIdx = startIdx + labelCloseMatch.index! + labelCloseMatch[0].length;
          return html.substring(labelStartIdx, endIdx);
        }
      }
    }
  }

  // Self-closing tags
  const selfClosingTags = ["area", "base", "br", "col", "embed", "hr", "img", "input", "link", "meta", "source", "track", "wbr"];
  if (selfClosingTags.includes(tagName.toLowerCase())) {
    return openMatch[0];
  }

  // Find the matching closing tag with proper nesting
  const afterOpen = html.substring(startIdx + openMatch[0].length);
  let depth = 1;
  let pos = 0;
  const tagLower = tagName.toLowerCase();

  while (pos < afterOpen.length && depth > 0) {
    const remaining = afterOpen.substring(pos);

    // Look for next opening or closing tag of the same type
    const openTagMatch = remaining.match(new RegExp(`<${tagLower}(?:\\s|>|\\/)`, "i"));
    const closeTagMatch = remaining.match(new RegExp(`<\\/${tagLower}>`, "i"));

    if (!closeTagMatch) {
      // No more closing tags
      break;
    }

    const closePos = closeTagMatch.index!;
    const openPos = openTagMatch?.index ?? Infinity;

    if (openPos < closePos) {
      // Found an opening tag first - check if self-closing
      const selfClosingTags = ["area", "base", "br", "col", "embed", "hr", "img", "input", "link", "meta", "source", "track", "wbr"];
      if (!selfClosingTags.includes(tagLower)) {
        depth++;
      }
      pos += openPos + 1;
    } else {
      // Found a closing tag
      depth--;
      if (depth === 0) {
        const endIdx = startIdx + openMatch[0].length + pos + closePos + closeTagMatch[0].length;
        return html.substring(startIdx, endIdx);
      }
      pos += closePos + closeTagMatch[0].length;
    }
  }

  // If no closing tag found, return just the opening tag with a placeholder
  return openMatch[0] + `x</${tagName}>`;
}

function generateHtmlAamRolesTests(): string {
  const jsonPath = "wpt-tests/html-aam/roles.json";
  const htmlPath = "wpt-tests/html-aam/roles.html";

  if (!fs.existsSync(jsonPath) || !fs.existsSync(htmlPath)) {
    console.error("Run: npx tsx tools/fetch-wpt-a11y.ts html-aam");
    return "";
  }

  const json = JSON.parse(fs.readFileSync(jsonPath, "utf-8"));
  const html = fs.readFileSync(htmlPath, "utf-8");
  const testCases: TestCase[] = json.testCases || [];

  const tests: string[] = [];
  let skipped = 0;

  for (const tc of testCases) {
    if (!tc.expectedRole || !tc.testName) continue;

    const moonBitRole = mapRoleToMoonBit(tc.expectedRole);
    if (!moonBitRole) {
      console.warn(`  Skipping ${tc.testName}: unknown role ${tc.expectedRole}`);
      skipped++;
      continue;
    }

    // Extract minimal HTML for the test
    const testHtml = extractTestElement(html, tc.testName);
    if (!testHtml) {
      console.warn(`  Skipping ${tc.testName}: could not extract HTML`);
      skipped++;
      continue;
    }

    // Clean up the HTML
    const cleanHtml = testHtml
      .replace(/data-testname="[^"]*"/g, "")
      .replace(/data-expectedrole="[^"]*"/g, "")
      .replace(/class="[^"]*"/g, "")
      .replace(/\s+/g, " ")
      .trim();

    tests.push(`
///|
test "html-aam/roles: ${tc.testName}" {
  let html = "${escapeString(cleanHtml)}"
  let elem = @html.parse(html).unwrap()
  let tree = build_accessibility_tree_from_element(elem)
  inspect(tree.root.role, content="${moonBitRole}")
}`);
  }

  console.log(`Generated ${tests.length} tests, skipped ${skipped}`);

  return `///|
/// WPT html-aam Role Mapping Tests (auto-generated)
/// Source: wpt-tests/html-aam/roles.html
/// Run: npx tsx tools/gen-wpt-aom-tests.ts html-aam-roles
${tests.join("\n")}
`;
}

function generateHtmlAamNamesTests(): string {
  const jsonPath = "wpt-tests/html-aam/names.json";
  const htmlPath = "wpt-tests/html-aam/names.html";

  if (!fs.existsSync(jsonPath) || !fs.existsSync(htmlPath)) {
    console.error("Run: npx tsx tools/fetch-wpt-a11y.ts html-aam");
    return "";
  }

  const json = JSON.parse(fs.readFileSync(jsonPath, "utf-8"));
  const html = fs.readFileSync(htmlPath, "utf-8");
  const testCases: TestCase[] = json.testCases || [];

  const tests: string[] = [];
  let skipped = 0;

  for (const tc of testCases) {
    if (tc.expectedLabel === undefined || !tc.testName) continue;

    // Extract minimal HTML for the test
    const testHtml = extractTestElement(html, tc.testName);
    if (!testHtml) {
      console.warn(`  Skipping ${tc.testName}: could not extract HTML`);
      skipped++;
      continue;
    }

    // Clean up the HTML - keep aria attributes but remove test metadata
    const cleanHtml = testHtml
      .replace(/data-testname="[^"]*"/g, "")
      .replace(/data-expectedlabel="[^"]*"/g, "")
      .replace(/class="[^"]*"/g, "")
      .replace(/\s+/g, " ")
      .trim();

    // Determine expected name (escape inner quotes for MoonBit string)
    const expectedName = tc.expectedLabel === ""
      ? "None"
      : `Some(\\"${escapeString(tc.expectedLabel)}\\")`;

    // For aria-labelledby tests, we need the full document with the referenced element
    const needsLabelledBy = cleanHtml.includes('aria-labelledby="labelledby"');

    if (needsLabelledBy) {
      // Extract element tag from cleanHtml for role-based lookup
      const tagMatch = cleanHtml.match(/^<([a-z][a-z0-9]*)/i);
      const tag = tagMatch ? tagMatch[1].toLowerCase() : "div";

      // Determine expected role for this element
      const roleForTag: Record<string, string> = {
        address: "Group",
        aside: "Complementary",
        blockquote: "Blockquote",
        details: "Group",
        dialog: "Dialog",
        dl: "List",
        fieldset: "Group",
        figure: "Figure",
        footer: "ContentInfo",
        form: "Form",
        header: "Banner",
        hgroup: "Group",
        hr: "Separator",
        main: "Main",
        menu: "List",
        nav: "Navigation",
        ol: "List",
        search: "Search",
        section: "Region",
        table: "Table",
        ul: "List",
      };
      const targetRole = roleForTag[tag] || "Generic";

      // For raw strings (#|), don't escape quotes
      tests.push(`
///|
test "html-aam/names: ${tc.testName}" {
  let html =
    #|<div>
    #|  <span id="labelledby">labelledby</span>
    #|  ${cleanHtml}
    #|</div>
  let doc = @html.parse_document(html)
  let tree = build_accessibility_tree(doc)
  // Find the test element by role
  let nodes = tree.find_by_role(${targetRole})
  let name = if nodes.length() > 0 { nodes[0].name } else { None }
  inspect(name, content="${expectedName}")
}`);
    } else {
      tests.push(`
///|
test "html-aam/names: ${tc.testName}" {
  let html = "${escapeString(cleanHtml)}"
  let elem = @html.parse(html).unwrap()
  let tree = build_accessibility_tree_from_element(elem)
  inspect(tree.root.name, content="${expectedName}")
}`);
    }
  }

  console.log(`Generated ${tests.length} tests, skipped ${skipped}`);

  return `///|
/// WPT html-aam Accessible Name Tests (auto-generated)
/// Source: wpt-tests/html-aam/names.html
/// Run: npx tsx tools/gen-wpt-aom-tests.ts html-aam-names
${tests.join("\n")}
`;
}

function generateAccnameTests(): string {
  const summaryPath = "wpt-tests/accname/_summary.json";
  if (!fs.existsSync(summaryPath)) {
    console.error("Run: npx tsx tools/fetch-wpt-a11y.ts accname");
    return "";
  }

  const summary = JSON.parse(fs.readFileSync(summaryPath, "utf-8"));
  const tests: string[] = [];
  let totalGenerated = 0;
  let totalSkipped = 0;

  const testNames = new Set<string>();

  for (const file of summary) {
    const htmlPath = path.join("wpt-tests/accname", file.file);
    const jsonPath = htmlPath.replace(".html", ".json");

    if (!fs.existsSync(jsonPath) || !fs.existsSync(htmlPath)) {
      console.warn(`  Skipping ${file.file}: missing files`);
      continue;
    }

    const json = JSON.parse(fs.readFileSync(jsonPath, "utf-8"));
    const html = fs.readFileSync(htmlPath, "utf-8");
    const testCases: TestCase[] = json.testCases || [];

    // Skip shadow DOM tests (not supported yet)
    if (file.file.includes("shadowdom")) {
      console.warn(`  Skipping ${file.file}: shadow DOM not supported`);
      totalSkipped += testCases.length;
      continue;
    }

    // Extract CSS from source HTML file for pseudo-element tests
    const cssContent = extractStyleBlock(html);

    // Get file basename for unique test names
    const fileBase = path.basename(file.file, ".html");

    for (const tc of testCases) {
      if (tc.expectedLabel === undefined || !tc.testName) continue;

      const testHtml = extractTestElement(html, tc.testName);
      if (!testHtml) {
        totalSkipped++;
        continue;
      }

      // Check if this is a pseudo-element test (::before or ::after)
      const isPseudoElementTest = tc.testName?.includes("::before") ||
                                   tc.testName?.includes("::after") ||
                                   tc.testName?.includes("with ::before") ||
                                   tc.testName?.includes("with ::after");

      // Clean up the HTML - remove metadata and normalize whitespace to single line
      // Keep class attribute for pseudo-element tests
      let cleanHtml = testHtml
        .replace(/data-testname="[^"]*"/g, "")
        .replace(/data-expectedlabel="[^"]*"/g, "");

      // Extract class names before potentially removing class attribute
      const classNames = extractClassNames(cleanHtml);

      if (!isPseudoElementTest) {
        cleanHtml = cleanHtml.replace(/class="[^"]*"/g, "");
      }

      cleanHtml = cleanHtml
        .replace(/[\r\n]+/g, " ")  // Convert newlines to spaces
        .replace(/\s+/g, " ")
        .trim();

      // For pseudo-element tests, extract relevant CSS rules
      const relevantCss = isPseudoElementTest ? extractRelevantCssRules(cssContent, classNames) : "";

      // Escape for MoonBit string
      const expectedName = tc.expectedLabel === ""
        ? "None"
        : `Some(\\"${escapeString(tc.expectedLabel)}\\")`;

      // Check if aria-labelledby is used or label[for] is needed
      const needsAriaLabelledby = cleanHtml.includes('aria-labelledby=');

      // Check for label[for] association - extract element id
      const elementIdMatch = cleanHtml.match(/id="([^"]+)"/);
      const elementId = elementIdMatch ? elementIdMatch[1] : null;
      let labelForElement = "";
      if (elementId) {
        // Find label with for="elementId"
        const labelRegex = new RegExp(`<label[^>]+for="${elementId}"[^>]*>[^<]*</label>`, "i");
        const labelMatch = html.match(labelRegex);
        if (labelMatch) {
          labelForElement = labelMatch[0]
            .replace(/[\r\n]+/g, " ")
            .replace(/\s+/g, " ")
            .trim();
        }
      }

      // Check for aria-owns references
      const ariaOwnsMatch = cleanHtml.match(/aria-owns="([^"]+)"/);
      const ariaOwnsIds = ariaOwnsMatch ? ariaOwnsMatch[1].split(" ") : [];
      let ariaOwnsElements = "";
      for (const ownsId of ariaOwnsIds) {
        if (ownsId.trim()) {
          // Find the element with this id in the full HTML
          // Also check if it has a hidden ancestor
          const ownsRegex = new RegExp(`<[^>]+id="${ownsId}"[^>]*>([\\s\\S]*?)</[^>]+>`, "i");
          const ownsMatch = html.match(ownsRegex);
          if (ownsMatch) {
            // Check for hidden ancestor by looking for <...hidden...> before the match
            const beforeMatch = html.substring(0, ownsMatch.index!);
            const hiddenDivMatch = beforeMatch.match(/<div[^>]*hidden[^>]*>\s*$/i);
            const hiddenSpanMatch = beforeMatch.match(/<span[^>]*hidden[^>]*>\s*$/i);

            let elementHtml = ownsMatch[0];
            if (hiddenDivMatch) {
              // Wrap the element in a hidden div
              elementHtml = `<div hidden>${ownsMatch[0]}</div>`;
            } else if (hiddenSpanMatch) {
              elementHtml = `<span hidden>${ownsMatch[0]}</span>`;
            }

            const singleLine = elementHtml.replace(/[\r\n]+/g, " ").replace(/\s+/g, " ");
            ariaOwnsElements += `    #|  ${singleLine}\n`;
          }
        }
      }

      const needsDocument = needsAriaLabelledby || labelForElement !== "" || ariaOwnsElements !== "";

      // Sanitize test name for MoonBit and make unique
      let safeName = tc.testName.replace(/"/g, "'");
      if (testNames.has(safeName)) {
        safeName = `${fileBase}: ${safeName}`;
      }
      testNames.add(safeName);

      if (needsDocument) {
        let refElements = "";

        // Add aria-labelledby referenced elements
        if (needsAriaLabelledby) {
          const idMatch = cleanHtml.match(/aria-labelledby="([^"]+)"/);
          const refIds = idMatch ? idMatch[1].split(" ") : [];
          for (const refId of refIds) {
            const refRegex = new RegExp(`<[^>]+id="${refId}"[^>]*>[^<]*</[^>]+>`, "i");
            const refMatch = html.match(refRegex);
            if (refMatch) {
              const singleLine = refMatch[0].replace(/[\r\n]+/g, " ").replace(/\s+/g, " ");
              refElements += `    #|  ${singleLine}\n`;
            }
          }
        }

        // Add label[for] element
        if (labelForElement) {
          refElements += `    #|  ${labelForElement}\n`;
        }

        // Add aria-owns referenced elements
        if (ariaOwnsElements) {
          refElements += ariaOwnsElements;
        }

        if (refElements) {
          // Determine role for the test element
          const roleForTest = getRoleForElement(cleanHtml);

          // For Generic role, use source_id lookup instead
          if (roleForTest === "Generic" && elementId) {
            tests.push(`
///|
test "accname: ${safeName}" {
  let html =
    #|<div>
${refElements}    #|  ${cleanHtml}
    #|</div>
  let doc = @html.parse_document(html)
  let tree = build_accessibility_tree(doc)
  // Find the test element by source id
  let name = match tree.find_by_source_id("${elementId}") {
    Some(node) => node.name
    Option::None => None
  }
  inspect(name, content="${expectedName}")
}`);
          } else {
            tests.push(`
///|
test "accname: ${safeName}" {
  let html =
    #|<div>
${refElements}    #|  ${cleanHtml}
    #|</div>
  let doc = @html.parse_document(html)
  let tree = build_accessibility_tree(doc)
  // Find the test element by role
  let nodes = tree.find_by_role(${roleForTest})
  let name = if nodes.length() > 0 { nodes[0].name } else { None }
  inspect(name, content="${expectedName}")
}`);
          }
          totalGenerated++;
        } else {
          totalSkipped++;
        }
      } else {
        // For encapsulation or embedded control tests, use document-level parsing
        const isEncapsulation = tc.testName?.includes("encapsulation");
        const isEmbeddedLabel = tc.testName?.includes("label with embedded");
        if (isEncapsulation || isEmbeddedLabel) {
          // For embedded label tests, extract role from the test name
          // e.g., "checkbox label with embedded textfield" -> Checkbox
          let roleForTest: string;
          if (isEmbeddedLabel) {
            const testNameLower = tc.testName?.toLowerCase() || "";
            if (testNameLower.startsWith("checkbox")) {
              roleForTest = "Checkbox";
            } else if (testNameLower.startsWith("radio")) {
              roleForTest = "Radio";
            } else {
              roleForTest = getRoleForElement(cleanHtml);
            }
          } else {
            roleForTest = getRoleForElement(cleanHtml);
          }
          // For Generic role, find the focusable node (the input) since there may be
          // multiple Generic nodes (document root, input, text node)
          if (roleForTest === "Generic") {
            tests.push(`
///|
test "accname: ${safeName}" {
  let html = "${escapeString(cleanHtml)}"
  let doc = @html.parse_document(html)
  let tree = build_accessibility_tree(doc)
  let focusable = tree.find_focusable()
  let name = if focusable.length() > 0 { focusable[0].name } else { None }
  inspect(name, content="${expectedName}")
}`);
          } else {
            tests.push(`
///|
test "accname: ${safeName}" {
  let html = "${escapeString(cleanHtml)}"
  let doc = @html.parse_document(html)
  let tree = build_accessibility_tree(doc)
  let nodes = tree.find_by_role(${roleForTest})
  let name = if nodes.length() > 0 { nodes[0].name } else { None }
  inspect(name, content="${expectedName}")
}`);
          }
        } else if (isPseudoElementTest && relevantCss) {
          // Pseudo-element test with CSS - use document-level parsing with style block
          const roleForTest = getRoleForElement(cleanHtml);
          tests.push(`
///|
test "accname: ${safeName}" {
  let html =
    #|<style>
    #|    ${relevantCss.replace(/\n/g, "\n    #|    ")}
    #|</style>
    #|${cleanHtml}
  let doc = @html.parse_document(html)
  let tree = build_accessibility_tree(doc)
  let nodes = tree.find_by_role(${roleForTest})
  let name = if nodes.length() > 0 { nodes[0].name } else { None }
  inspect(name, content="${expectedName}")
}`);
        } else {
          tests.push(`
///|
test "accname: ${safeName}" {
  let html = "${escapeString(cleanHtml)}"
  let elem = @html.parse(html).unwrap()
  let tree = build_accessibility_tree_from_element(elem)
  inspect(tree.root.name, content="${expectedName}")
}`);
        }
        totalGenerated++;
      }
    }
  }

  console.log(`Generated ${totalGenerated} tests, skipped ${totalSkipped}`);

  return `///|
/// WPT accname Tests (auto-generated)
/// Source: wpt-tests/accname/
/// Run: npx tsx tools/gen-wpt-aom-tests.ts accname
${tests.join("\n")}
`;
}

function main(): void {
  const args = process.argv.slice(2);

  if (args.length === 0 || args[0] === "--help") {
    console.log("Usage: npx tsx tools/gen-wpt-aom-tests.ts <type>");
    console.log("Types:");
    console.log("  html-aam-roles  Generate role mapping tests");
    console.log("  html-aam-names  Generate accessible name tests");
    console.log("  accname         Generate accname tests");
    return;
  }

  switch (args[0]) {
    case "html-aam-roles": {
      const output = generateHtmlAamRolesTests();
      const outFile = "aom/wpt_roles_test.mbt";
      fs.writeFileSync(outFile, output);
      console.log(`Output: ${outFile}`);
      break;
    }
    case "html-aam-names": {
      const output = generateHtmlAamNamesTests();
      const outFile = "aom/wpt_names_test.mbt";
      fs.writeFileSync(outFile, output);
      console.log(`Output: ${outFile}`);
      break;
    }
    case "accname": {
      const output = generateAccnameTests();
      const outFile = "aom/wpt_accname_test.mbt";
      fs.writeFileSync(outFile, output);
      console.log(`Output: ${outFile}`);
      break;
    }
    default:
      console.error(`Unknown type: ${args[0]}`);
  }
}

main();
