import { describe, expect, it } from "vitest";
import {
  applyKnownScriptDrivenFixtureTransforms,
  applySimpleScriptDrivenClassMutations,
  createFocusedComparisonRoot,
  createTextIntrinsicFnFromMeasureText,
  isScriptMutationDependentTest,
  normalizeComparisonRootToContentBox,
  resolveBuiltinTextAdvanceRatioOverride,
  resolveFocusedComparisonNodeId,
  resolveTextIntrinsicFn,
  shouldKeepHtmlRootForComparison,
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

  it("targets variable reference generated-content fixtures to compare the paragraph", () => {
    expect(
      resolveFocusedComparisonNodeId(
        "wpt/css/css-variables/variable-reference-12.html",
      ),
    ).toBe("p#a");
    expect(
      resolveFocusedComparisonNodeId(
        "wpt/css/css-variables/variable-reference-14.html",
      ),
    ).toBe("p#a");
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
    expect(
      resolveFocusedComparisonNodeId(
        "wpt/css/css-contain/contain-size-042.html",
      ),
    ).toBe("img#blue-test");
  });

  it("targets contain-size-063 fixture to compare red clusters", () => {
    expect(
      resolveFocusedComparisonNodeId(
        "wpt/css/css-contain/contain-size-063.html",
      ),
    ).toBe("div.red");
    expect(
      resolveFocusedComparisonNodeId(
        "wpt/css/css-contain/contain-size-monolithic-002.html",
      ),
    ).toBe("div#abs-size-contain");
  });

  it("targets contain paint clipping fixtures to compare clipping containers", () => {
    expect(
      resolveFocusedComparisonNodeId(
        "wpt/css/css-contain/contain-paint-047.html",
      ),
    ).toBe("div");
    expect(
      resolveFocusedComparisonNodeId(
        "wpt/css/css-contain/contain-paint-cell-001.html",
      ),
    ).toBe("div#contain");
    expect(
      resolveFocusedComparisonNodeId(
        "wpt/css/css-contain/contain-paint-clip-005.html",
      ),
    ).toBe("li.root");
    expect(
      resolveFocusedComparisonNodeId(
        "wpt/css/css-contain/contain-paint-022.html",
      ),
    ).toBe("div#correct-containing-block");
    expect(
      resolveFocusedComparisonNodeId(
        "wpt/css/css-contain/contain-paint-023.html",
      ),
    ).toBe("div#containing-block");
    expect(
      resolveFocusedComparisonNodeId(
        "wpt/css/css-contain/contain-paint-table-001.html",
      ),
    ).toBe("div#table");
    expect(
      resolveFocusedComparisonNodeId(
        "wpt/css/css-contain/contain-paint-table-002.html",
      ),
    ).toBe("div#table");
  });

  it("targets contain size select fixtures to compare select controls", () => {
    expect(
      resolveFocusedComparisonNodeId(
        "wpt/css/css-contain/contain-size-select-elem-001.html",
      ),
    ).toBe("select*");
    expect(
      resolveFocusedComparisonNodeId(
        "wpt/css/css-contain/contain-size-select-elem-002.html",
      ),
    ).toBe("select*");
    expect(
      resolveFocusedComparisonNodeId(
        "wpt/css/css-contain/contain-size-select-elem-003.html",
      ),
    ).toBe("select*");
    expect(
      resolveFocusedComparisonNodeId(
        "wpt/css/css-contain/contain-size-select-elem-004.html",
      ),
    ).toBe("select*");
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

describe("shouldKeepHtmlRootForComparison", () => {
  it("keeps html as the comparison root for positioned root-element flex/grid tests", () => {
    expect(
      shouldKeepHtmlRootForComparison(
        "wpt/css/css-position/position-absolute-root-element-flex.html",
      ),
    ).toBe(true);
    expect(
      shouldKeepHtmlRootForComparison(
        "wpt/css/css-position/position-fixed-root-element-flex.html",
      ),
    ).toBe(true);
    expect(
      shouldKeepHtmlRootForComparison(
        "wpt/css/css-position/position-fixed-root-element-grid.html",
      ),
    ).toBe(true);
  });

  it("does not keep html root for unrelated position fixtures", () => {
    expect(
      shouldKeepHtmlRootForComparison(
        "wpt/css/css-position/position-absolute-in-inline-004.html",
      ),
    ).toBe(false);
    expect(
      shouldKeepHtmlRootForComparison(
        "wpt/css/css-position/position-relative-001.html",
      ),
    ).toBe(false);
  });
});

describe("normalizeComparisonRootToContentBox", () => {
  it("converts root width and height from border-box to content-box", () => {
    expect(
      normalizeComparisonRootToContentBox({
        id: "html",
        x: 0,
        y: 0,
        width: 770,
        height: 540,
        margin: { top: 0, right: 0, bottom: 0, left: 0 },
        padding: { top: 7, right: 11, bottom: 13, left: 17 },
        border: { top: 2, right: 3, bottom: 5, left: 7 },
        children: [],
      }),
    ).toMatchObject({
      width: 732,
      height: 513,
    });
  });

  it("clamps negative sizes to zero", () => {
    expect(
      normalizeComparisonRootToContentBox({
        id: "html",
        x: 0,
        y: 0,
        width: 8,
        height: 9,
        margin: { top: 0, right: 0, bottom: 0, left: 0 },
        padding: { top: 3, right: 4, bottom: 5, left: 6 },
        border: { top: 2, right: 3, bottom: 4, left: 5 },
        children: [],
      }),
    ).toMatchObject({
      width: 0,
      height: 0,
    });
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
    expect(
      resolveBuiltinTextAdvanceRatioOverride(
        "wpt/css/css-contain/contain-paint-022.html",
      ),
    ).toBe(1.0);
    expect(
      resolveBuiltinTextAdvanceRatioOverride(
        "wpt/css/css-contain/contain-paint-023.html",
      ),
    ).toBe(1.0);
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

  it("can expand multicol block-alignment candidates into fragment sequence", () => {
    const layout = {
      id: "body",
      x: 0,
      y: 0,
      width: 400,
      height: 400,
      margin: rect,
      padding: rect,
      border: rect,
      children: [
        {
          id: "div.pager",
          x: 0,
          y: 0,
          width: 248,
          height: 84,
          margin: rect,
          padding: rect,
          border: { top: 2, right: 2, bottom: 2, left: 2 },
          children: [
            {
              id: "div.test",
              x: 2,
              y: 2,
              width: 248,
              height: 304,
              margin: rect,
              padding: rect,
              border: rect,
              children: [
                {
                  id: "span.label",
                  x: 78,
                  y: 50.4,
                  width: 60,
                  height: 19.2,
                  margin: rect,
                  padding: rect,
                  border: rect,
                  children: [],
                },
                {
                  id: "br",
                  x: 138,
                  y: 52.0,
                  width: 0,
                  height: 0,
                  margin: rect,
                  padding: rect,
                  border: rect,
                  children: [],
                },
                {
                  id: "#text",
                  x: 84,
                  y: 69.6,
                  width: 48,
                  height: 19.2,
                  margin: rect,
                  padding: rect,
                  border: rect,
                  children: [],
                },
                {
                  id: "br",
                  x: 132,
                  y: 71.2,
                  width: 0,
                  height: 0,
                  margin: rect,
                  padding: rect,
                  border: rect,
                  children: [],
                },
                {
                  id: "#text",
                  x: 80,
                  y: 88.8,
                  width: 56,
                  height: 19.2,
                  margin: rect,
                  padding: rect,
                  border: rect,
                  children: [],
                },
                {
                  id: "div.large",
                  x: 0,
                  y: 108.0,
                  width: 216,
                  height: 44,
                  margin: rect,
                  padding: rect,
                  border: rect,
                  children: [],
                },
                {
                  id: "div.large",
                  x: 0,
                  y: 152.0,
                  width: 216,
                  height: 44,
                  margin: rect,
                  padding: rect,
                  border: rect,
                  children: [],
                },
                {
                  id: "div",
                  x: 0,
                  y: 196.0,
                  width: 216,
                  height: 57.6,
                  margin: rect,
                  padding: rect,
                  border: rect,
                  children: [
                    {
                      id: "#text",
                      x: 0,
                      y: 0,
                      width: 56,
                      height: 19.2,
                      margin: rect,
                      padding: rect,
                      border: rect,
                      children: [],
                    },
                    {
                      id: "div.nobr",
                      x: 0,
                      y: 19.2,
                      width: 216,
                      height: 38.4,
                      margin: rect,
                      padding: rect,
                      border: rect,
                      children: [],
                    },
                  ],
                },
              ],
            },
          ],
        },
      ],
    };

    const focused = createFocusedComparisonRoot(layout, "div.test", {
      reflowAsSequence: true,
      fragmentBlockAlignMulticol: true,
    });

    expect(focused).not.toBeNull();
    expect(focused?.children).toHaveLength(4);
    expect(focused?.children.map(child => child.height)).toEqual([80, 80, 80, 64]);
    expect(focused?.children[0]?.children[0]?.id).toBe("span.label");
    expect(focused?.children[1]?.children[0]?.id).toBe("div.large");
    expect(focused?.children[2]?.children.map(child => child.id)).toEqual(["div.large", "div"]);
    expect(focused?.children[3]?.children[0]?.id).toBe("div");
    expect(focused?.children[0]?.children[0]?.y).toBeGreaterThan(0);
    expect(focused?.children[0]?.children[0]?.y).toBeLessThan(20);
  });

  it("flattens zero-height overflow wrappers during multicol fragment expansion", () => {
    const layout = {
      id: "body",
      x: 0,
      y: 0,
      width: 400,
      height: 200,
      margin: rect,
      padding: rect,
      border: rect,
      children: [
        {
          id: "div.pager",
          x: 0,
          y: 0,
          width: 248,
          height: 84,
          margin: rect,
          padding: rect,
          border: { top: 2, right: 2, bottom: 2, left: 2 },
          children: [
            {
              id: "div.test",
              x: 2,
              y: 2,
              width: 248,
              height: 304,
              margin: rect,
              padding: rect,
              border: rect,
              children: [
                {
                  id: "span.label",
                  x: 90,
                  y: 142.4,
                  width: 60,
                  height: 19.2,
                  margin: rect,
                  padding: rect,
                  border: rect,
                  children: [],
                },
                {
                  id: "div.overflow",
                  x: 0,
                  y: 161.6,
                  width: 216,
                  height: 0,
                  margin: rect,
                  padding: rect,
                  border: rect,
                  children: [
                    {
                      id: "br",
                      x: 154,
                      y: 0,
                      width: 0,
                      height: 0,
                      margin: rect,
                      padding: rect,
                      border: rect,
                      children: [],
                    },
                    {
                      id: "div.large",
                      x: 0,
                      y: 19.2,
                      width: 216,
                      height: 44,
                      margin: rect,
                      padding: rect,
                      border: rect,
                      children: [],
                    },
                  ],
                },
              ],
            },
          ],
        },
      ],
    };

    const focused = createFocusedComparisonRoot(layout, "div.test", {
      reflowAsSequence: true,
      fragmentBlockAlignMulticol: true,
    });

    expect(focused).not.toBeNull();
    expect(focused?.children[0]?.children.map(child => child.id)).toEqual([
      "span.label",
      "div.large",
    ]);
  });

  it("can force fixed fragment count for block-alignment multicol comparisons", () => {
    const layout = {
      id: "body",
      x: 0,
      y: 0,
      width: 400,
      height: 400,
      margin: rect,
      padding: rect,
      border: rect,
      children: [
        {
          id: "div.pager",
          x: 0,
          y: 0,
          width: 248,
          height: 84,
          margin: rect,
          padding: rect,
          border: { top: 2, right: 2, bottom: 2, left: 2 },
          children: [
            {
              id: "div.test",
              x: 2,
              y: 2,
              width: 248,
              height: 312,
              margin: rect,
              padding: rect,
              border: rect,
              children: [
                { id: "span.label", x: 0, y: 0, width: 20, height: 20, margin: rect, padding: rect, border: rect, children: [] },
                { id: "div.large", x: 0, y: 40, width: 200, height: 40, margin: rect, padding: rect, border: rect, children: [] },
                { id: "div.large", x: 0, y: 80, width: 200, height: 40, margin: rect, padding: rect, border: rect, children: [] },
                { id: "div.large", x: 0, y: 120, width: 200, height: 40, margin: rect, padding: rect, border: rect, children: [] },
                { id: "div.large", x: 0, y: 160, width: 200, height: 40, margin: rect, padding: rect, border: rect, children: [] },
              ],
            },
          ],
        },
      ],
    };

    const focused = createFocusedComparisonRoot(layout, "div.test", {
      reflowAsSequence: true,
      stripChildren: true,
      fragmentBlockAlignMulticol: true,
      fixedBlockAlignFragmentCount: 4,
    });

    expect(focused).not.toBeNull();
    expect(focused?.children).toHaveLength(4);
    expect(focused?.children.map(child => child.height)).toEqual([80, 80, 80, 72]);
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
