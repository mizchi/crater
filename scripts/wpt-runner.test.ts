import { describe, expect, it } from "vitest";
import {
  applyKnownScriptDrivenFixtureTransforms,
  applySimpleScriptDrivenClassMutations,
  createFocusedComparisonRoot,
  createTextIntrinsicFnFromMeasureText,
  isScriptMutationDependentTest,
  resolveBuiltinTextAdvanceRatioOverride,
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

describe("applyKnownScriptDrivenFixtureTransforms", () => {
  it("expands logical float/clear reftest script into static markup", () => {
    const html = "<body><script>ignored</script></body>";
    const transformed = applyKnownScriptDrivenFixtureTransforms(
      html,
      "wpt/css/css-logical/logical-values-float-clear-reftest.html",
    );

    expect(transformed.match(/class="test"/g)?.length).toBe(96);
    expect(transformed).toContain('float:inline-start');
    expect(transformed).toContain('clear:inline-end');
  });

  it("expands content-none-select-1 script into wrapper/select markup", () => {
    const html = "<body><script>ignored</script></body>";
    const transformed = applyKnownScriptDrivenFixtureTransforms(
      html,
      "wpt/css/css-content/content-none-select-1.html",
    );

    expect(transformed.match(/class="wrapper"/g)?.length).toBe(180);
    expect(transformed.match(/<select/g)?.length).toBe(180);
    expect(transformed).toContain('class="after"');
    expect(transformed).toContain('style="display:contents;overflow:clip;position:absolute"');
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
        "wpt/css/css-display/display-contents-details.html",
      ),
    ).toBe("details");
    expect(
      resolveFocusedComparisonNodeId(
        "wpt/css/css-display/display-contents-details-001.html",
      ),
    ).toBe("summary");
  });

  it("targets nested legend display-contents fixture to compare legend node", () => {
    expect(
      resolveFocusedComparisonNodeId(
        "wpt/css/css-display/display-contents-fieldset.html",
      ),
    ).toBe("fieldset");
    expect(
      resolveFocusedComparisonNodeId(
        "wpt/css/css-display/display-contents-fieldset-nested-legend.html",
      ),
    ).toBe("legend");
  });

  it("targets display-contents no-box float and oof fixtures to compare the wrapper", () => {
    expect(
      resolveFocusedComparisonNodeId(
        "wpt/css/css-display/display-contents-float-001.html",
      ),
    ).toBe("div");
    expect(
      resolveFocusedComparisonNodeId(
        "wpt/css/css-display/display-contents-oof-001.html",
      ),
    ).toBe("div");
    expect(
      resolveFocusedComparisonNodeId(
        "wpt/css/css-display/display-contents-oof-002.html",
      ),
    ).toBe("div");
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
        "wpt/css/css-overflow/overflow-inline-block-with-opacity.html",
      ),
    ).toBe("div#button");
    expect(
      resolveFocusedComparisonNodeId(
        "wpt/css/css-overflow/overflow-clip-margin-mul-column-border-box.html",
      ),
    ).toBe("div.container");
    expect(
      resolveFocusedComparisonNodeId(
        "wpt/css/css-overflow/overflow-clip-margin-mul-column-content-box.html",
      ),
    ).toBe("div.container");
    expect(
      resolveFocusedComparisonNodeId(
        "wpt/css/css-overflow/overflow-clip-margin-mul-column-padding-box.html",
      ),
    ).toBe("div.container");
    expect(
      resolveFocusedComparisonNodeId(
        "wpt/css/css-overflow/scroll-marker-003.html",
      ),
    ).toBe("div#scroller");
    expect(
      resolveFocusedComparisonNodeId(
        "wpt/css/css-overflow/scroll-marker-004.html",
      ),
    ).toBe("div#scroller");
    expect(
      resolveFocusedComparisonNodeId(
        "wpt/css/css-grid/grid-in-table-cell-with-img.html",
      ),
    ).toBe("img");
    expect(
      resolveFocusedComparisonNodeId(
        "wpt/css/css-grid/grid-item-percentage-quirk-001.html",
      ),
    ).toBe("div");
    expect(
      resolveFocusedComparisonNodeId(
        "wpt/css/css-grid/grid-item-percentage-quirk-002.html",
      ),
    ).toBe("div");
    expect(
      resolveFocusedComparisonNodeId(
        "wpt/css/css-overflow/column-scroll-marker-001.html",
      ),
    ).toBeNull();
  });
});

describe("resolveBuiltinTextAdvanceRatioOverride", () => {
  it("narrows fallback text metrics for table fixtures with boundary whitespace", () => {
    expect(
      resolveBuiltinTextAdvanceRatioOverride(
        "wpt/css/css-tables/table-cell-overflow-explicit-height-001.html",
      ),
    ).toBe(0.4);
    expect(
      resolveBuiltinTextAdvanceRatioOverride(
        "wpt/css/css-tables/visibility-collapse-rowspan-005.html",
      ),
    ).toBe(0.4);
  });

  it("does not override fallback text metrics for other fixtures", () => {
    expect(
      resolveBuiltinTextAdvanceRatioOverride(
        "wpt/css/css-tables/border-conflict-resolution.html",
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

  it("can strip descendant trees when only the focused node box should be compared", () => {
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
          id: "div.container",
          x: 10,
          y: 20,
          width: 120,
          height: 40,
          margin: rect,
          padding: rect,
          border: rect,
          children: [
            {
              id: "div.content",
              x: -10,
              y: -10,
              width: 200,
              height: 30,
              margin: rect,
              padding: rect,
              border: rect,
              children: [],
            },
          ],
        },
      ],
    };

    const focused = createFocusedComparisonRoot(layout, "div.container", {
      stripChildren: true,
    });

    expect(focused).not.toBeNull();
    expect(focused?.children).toHaveLength(1);
    expect(focused?.children[0]?.id).toBe("div.container");
    expect(focused?.children[0]?.children).toEqual([]);
    expect(focused?.width).toBe(120);
    expect(focused?.height).toBe(40);
  });
});
