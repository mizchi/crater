import { readFileSync } from "node:fs";
import { describe, expect, test } from "vitest";

function readRepoFile(relativePath: string): string {
  return readFileSync(new URL(`../${relativePath}`, import.meta.url), "utf8");
}

describe("CI compatible font setup", () => {
  test("installs compatible fonts in VRT jobs", () => {
    const workflow = readRepoFile(".github/workflows/ci.yml");
    const matches = workflow.match(/bash scripts\/ci\/install-compatible-fonts\.sh/g) ?? [];
    expect(matches).toHaveLength(2);
  });

  test("font install script retries flaky msttcorefonts extraction", () => {
    const script = readRepoFile("scripts/ci/install-compatible-fonts.sh");

    expect(script).toContain("for attempt in 1 2 3; do");
    expect(script).toContain("sudo dpkg-reconfigure ttf-mscorefonts-installer || true");
    expect(script).toContain("sudo rm -f /var/lib/update-notifier/package-data-downloads/partial/* || true");
    expect(script).toContain("sudo apt-get install -y --reinstall --no-install-recommends ttf-mscorefonts-installer || true");
  });

  test("font resolvers include msttcorefonts file variants", () => {
    const bidiSource = readRepoFile("browser/jsbidi/bidi_main/start-with-font.ts");
    const resolverSource = readRepoFile("scripts/system-font-resolver.ts");

    for (const source of [bidiSource, resolverSource]) {
      expect(source).toContain("Times_New_Roman.ttf");
      expect(source).toContain("Times_New_Roman_Bold.ttf");
      expect(source).toContain("Courier_New.ttf");
      expect(source).toContain("Georgia_Bold.ttf");
      expect(source).toContain("verdanab.ttf");
    }
  });
});
