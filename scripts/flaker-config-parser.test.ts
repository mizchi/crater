import { describe, expect, it } from "vitest";
import { parseFlakerStar } from "./flaker-config-parser.ts";

describe("flaker-config-parser", () => {
  it("parses workflow, nodes, and tasks directly", () => {
    const config = parseFlakerStar(`
workflow(name="example", max_parallel=2)

node(id="layout", depends_on=[])
node(id="browser", depends_on=["layout"])

task(
  id="paint-vrt",
  node="layout",
  cmd=["pnpm", "exec", "playwright", "test", "tests/paint-vrt.test.ts"],
  srcs=["src/layout/**"],
  needs=["wpt-vrt"],
  trigger="auto",
)
`);

    expect(config.workflow).toEqual({
      name: "example",
      maxParallel: 2,
    });
    expect(config.nodes).toEqual([
      { id: "layout", dependsOn: [] },
      { id: "browser", dependsOn: ["layout"] },
    ]);
    expect(config.tasks).toEqual([
      {
        id: "paint-vrt",
        node: "layout",
        cmd: ["pnpm", "exec", "playwright", "test", "tests/paint-vrt.test.ts"],
        srcs: ["src/layout/**"],
        needs: ["wpt-vrt"],
        trigger: "auto",
      },
    ]);
  });
});
