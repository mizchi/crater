import { describe, expect, it } from "vitest";
import {
  applySimpleScriptDrivenClassMutations,
  createFocusedComparisonRoot,
  createTextIntrinsicFnFromMeasureText,
  isScriptMutationDependentTest,
  resolveFocusedComparisonNodeId,
  resolveTextIntrinsicFn,
} from "./wpt-runner.ts";

describe("createTextIntrinsicFnFromMeasureText", () => {
  it("falls back to char-based widths when measureText returns 0", () => {
    const fn = createTextIntrinsicFnFromMeasureText(() => 0);
    const result = fn(
      "AAAA AAAA AAAA AAAA",
      16,
      19.2,
      "normal",
      "horizontal-tb",
      80,
      600,
    );

    expect(result).not.toBeNull();
    expect(result?.maxWidth).toBeGreaterThan(0);
    expect(result?.maxHeight).toBeGreaterThan(19.2);
  });

  it("uses external measured widths when they are positive", () => {
    const fn = createTextIntrinsicFnFromMeasureText((text) => text.length * 10);
    const result = fn(
      "abcd ef",
      16,
      20,
      "normal",
      "horizontal-tb",
      1000,
      600,
    );

    expect(result?.maxWidth).toBe(70);
    expect(result?.minWidth).toBe(40);
    expect(result?.maxHeight).toBe(20);
  });

  it("collapses newline-only whitespace into a single visual line in normal mode", () => {
    const fn = createTextIntrinsicFnFromMeasureText((text) => text.length * 10);
    const result = fn(
      "\n      Needs border\n    ",
      16,
      20,
      "normal",
      "horizontal-tb",
      1000,
      600,
    );

    expect(result?.maxHeight).toBe(20);
    expect(result?.minHeight).toBe(20);
  });

  it("treats whitespace-only text as zero-height in normal mode", () => {
    const fn = createTextIntrinsicFnFromMeasureText((text) => text.length * 10);
    const result = fn(
      "\n      \n    ",
      16,
      20,
      "normal",
      "horizontal-tb",
      1000,
      600,
    );

    expect(result?.maxWidth).toBe(0);
    expect(result?.minWidth).toBe(0);
    expect(result?.maxHeight).toBe(0);
    expect(result?.minHeight).toBe(0);
  });

  it("wraps vertical text by available height", () => {
    const fn = createTextIntrinsicFnFromMeasureText((text) => text.length * 10);
    const result = fn(
      "a b c d e f g h i j k l m n o p q r s t u v w x y z",
      16,
      20,
      "normal",
      "vertical-rl",
      160,
      120,
    );

    expect(result?.maxWidth).toBeGreaterThan(20);
    expect(result?.maxHeight).toBe(120);
  });

  it("adapts measureText-only modules instead of treating them as intrinsic providers", () => {
    const fn = resolveTextIntrinsicFn({
      measureText: () => 0,
    });

    expect(fn).not.toBeNull();
    const result = fn!(
      "AAAA AAAA AAAA AAAA",
      16,
      19.2,
      "normal",
      "horizontal-tb",
      80,
      600,
    );
    expect(result).not.toBeNull();
    expect((result as { maxHeight?: number }).maxHeight).toBeGreaterThan(19.2);
  });
});

describe("resolveFocusedComparisonNodeId", () => {
  it("targets overflow-alignment tests to compare only .test boxes", () => {
    expect(
      resolveFocusedComparisonNodeId(
        "wpt/css/css-overflow/overflow-alignment-block-001.html",
      ),
    ).toBe("div.test");
  });

  it("targets css-align block align-content fixtures to compare .test boxes", () => {
    expect(
      resolveFocusedComparisonNodeId(
        "wpt/css/css-align/blocks/align-content-block-012.html",
      ),
    ).toBe("div.test");
    expect(
      resolveFocusedComparisonNodeId(
        "wpt/css/css-align/blocks/align-content-block-overflow-000.html",
      ),
    ).toBe("div.test");
  });

  it("targets display-contents details fixture to compare summary node", () => {
    expect(
      resolveFocusedComparisonNodeId(
        "wpt/css/css-display/display-contents-details-001.html",
      ),
    ).toBe("summary");
  });

  it("targets nested legend display-contents fixture to compare legend node", () => {
    expect(
      resolveFocusedComparisonNodeId(
        "wpt/css/css-display/display-contents-fieldset-nested-legend.html",
      ),
    ).toBe("legend");
  });

  it("targets svg display-contents fixture to compare rendered text nodes", () => {
    expect(
      resolveFocusedComparisonNodeId(
        "wpt/css/css-display/display-contents-svg-elements.html",
      ),
    ).toBe("text");
  });

  it("targets contain-size inline-block fixtures to compare blue test boxes", () => {
    expect(
      resolveFocusedComparisonNodeId(
        "wpt/css/css-contain/contain-size-023.html",
      ),
    ).toBe("div#blue-test");
    expect(
      resolveFocusedComparisonNodeId(
        "wpt/css/css-contain/contain-size-025.html",
      ),
    ).toBe("div#blue-test");
  });

  it("targets contain-size-063 fixture to compare red clusters", () => {
    expect(
      resolveFocusedComparisonNodeId(
        "wpt/css/css-contain/contain-size-063.html",
      ),
    ).toBe("div.red");
  });

  it("does not change comparison target for other tests", () => {
    expect(
      resolveFocusedComparisonNodeId(
        "wpt/css/css-overflow/column-scroll-marker-001.html",
      ),
    ).toBeNull();
  });
});

describe("isScriptMutationDependentTest", () => {
  it("flags align-content dynamic-content fixture as script-dependent", () => {
    expect(
      isScriptMutationDependentTest(
        "wpt/css/css-align/blocks/align-content-block-dynamic-content.html",
      ),
    ).toBe(true);
  });

  it("flags css-display dynamic mutation fixtures as script-dependent", () => {
    expect(
      isScriptMutationDependentTest(
        "wpt/css/css-display/display-contents-dynamic-pseudo-insertion-001.html",
      ),
    ).toBe(true);
    expect(
      isScriptMutationDependentTest(
        "wpt/css/css-display/display-contents-state-change-001.html",
      ),
    ).toBe(true);
    expect(
      isScriptMutationDependentTest(
        "wpt/css/css-display/display-contents-dynamic-fieldset-legend-001.html",
      ),
    ).toBe(true);
    expect(
      isScriptMutationDependentTest(
        "wpt/css/css-display/display-contents-fieldset-002.html",
      ),
    ).toBe(true);
    expect(
      isScriptMutationDependentTest(
        "wpt/css/css-display/display-contents-shadow-dom-1.html",
      ),
    ).toBe(true);
    expect(
      isScriptMutationDependentTest(
        "wpt/css/css-display/display-contents-shadow-host-whitespace.html",
      ),
    ).toBe(true);
    expect(
      isScriptMutationDependentTest(
        "wpt/css/css-display/display-first-line-002.html",
      ),
    ).toBe(true);
  });

  it("flags reftest-wait + takeScreenshot dynamic fixtures as script-dependent", () => {
    expect(
      isScriptMutationDependentTest(
        "wpt/css/css-contain/contain-layout-dynamic-004.html",
      ),
    ).toBe(true);
    expect(
      isScriptMutationDependentTest(
        "wpt/css/css-contain/contain-paint-dynamic-005.html",
      ),
    ).toBe(true);
  });

  it("flags contain-style dynamic display toggling fixture as script-dependent", () => {
    expect(
      isScriptMutationDependentTest(
        "wpt/css/css-contain/contain-style-dynamic-002.html",
      ),
    ).toBe(true);
  });

  it("returns false for non-script-dependent fixtures", () => {
    expect(
      isScriptMutationDependentTest(
        "wpt/css/css-align/blocks/align-content-block-012.html",
      ),
    ).toBe(false);
  });
});

describe("applySimpleScriptDrivenClassMutations", () => {
  it("applies classList.add for global id references used by reftest scripts", () => {
    const html = `
      <div id="container"></div>
      <script>
        window.addEventListener("load", async () => {
          container.classList.add('containment');
          await waitForAtLeastOneFrame();
          takeScreenshot();
        });
      </script>
    `;
    const transformed = applySimpleScriptDrivenClassMutations(html);
    expect(transformed).toContain('id="container" class="containment"');
  });

  it("applies classList.remove for document.getElementById references", () => {
    const html = `
      <div id="container" class="containment other"></div>
      <script>
        window.addEventListener("load", async () => {
          document.getElementById('container').classList.remove("containment");
          await waitForAtLeastOneFrame();
          takeScreenshot();
        });
      </script>
    `;
    const transformed = applySimpleScriptDrivenClassMutations(html);
    expect(transformed).toContain('id="container" class="other"');
    expect(transformed).not.toContain('class="containment other"');
  });
});

describe("createFocusedComparisonRoot", () => {
  const rect = { top: 0, right: 0, bottom: 0, left: 0 };

  it("extracts and normalizes matching nodes into a synthetic root", () => {
    const layout = {
      id: "body",
      x: 0,
      y: 0,
      width: 300,
      height: 200,
      margin: rect,
      padding: rect,
      border: rect,
      children: [
        {
          id: "section",
          x: 100,
          y: 30,
          width: 150,
          height: 80,
          margin: rect,
          padding: rect,
          border: rect,
          children: [
            {
              id: "div.test",
              x: 20,
              y: 10,
              width: 24,
              height: 24,
              margin: rect,
              padding: rect,
              border: rect,
              children: [],
            },
          ],
        },
        {
          id: "aside",
          x: 10,
          y: 80,
          width: 80,
          height: 40,
          margin: rect,
          padding: rect,
          border: rect,
          children: [
            {
              id: "div.test",
              x: 5,
              y: 3,
              width: 24,
              height: 24,
              margin: rect,
              padding: rect,
              border: rect,
              children: [],
            },
          ],
        },
      ],
    };

    const focused = createFocusedComparisonRoot(layout, "div.test");
    expect(focused).not.toBeNull();
    expect(focused?.id).toBe("focused-root");
    expect(focused?.children).toHaveLength(2);

    expect(focused?.children[0]?.x).toBe(105);
    expect(focused?.children[0]?.y).toBe(0);
    expect(focused?.children[1]?.x).toBe(0);
    expect(focused?.children[1]?.y).toBe(43);
  });

  it("returns null when target nodes are not found", () => {
    const layout = {
      id: "body",
      x: 0,
      y: 0,
      width: 100,
      height: 100,
      margin: rect,
      padding: rect,
      border: rect,
      children: [],
    };

    expect(createFocusedComparisonRoot(layout, "div.test")).toBeNull();
  });

  it("supports sequence normalization for position-insensitive comparison", () => {
    const layout = {
      id: "body",
      x: 0,
      y: 0,
      width: 300,
      height: 200,
      margin: rect,
      padding: rect,
      border: rect,
      children: [
        {
          id: "div.test",
          x: 120,
          y: 40,
          width: 24,
          height: 24,
          margin: rect,
          padding: rect,
          border: rect,
          children: [],
        },
        {
          id: "div.test",
          x: 20,
          y: 100,
          width: 24,
          height: 24,
          margin: rect,
          padding: rect,
          border: rect,
          children: [],
        },
      ],
    };

    const focused = createFocusedComparisonRoot(layout, "div.test", {
      reflowAsSequence: true,
    });

    expect(focused).not.toBeNull();
    expect(focused?.children[0]?.x).toBe(0);
    expect(focused?.children[0]?.y).toBe(0);
    expect(focused?.children[1]?.x).toBe(0);
    expect(focused?.children[1]?.y).toBe(25);
  });
});
