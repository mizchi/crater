import { describe, expect, it } from "vitest";
import { loadWptConfigFromText } from "./wpt-config.ts";

describe("loadWptConfigFromText", () => {
  it("parses line and block comments in WPT config", () => {
    const config = loadWptConfigFromText(`{
      // enabled modules
      "modules": [
        "css-flexbox",
        "css-logical", // logical layout
        /* later:
        "css-ruby"
        */
        "css-content"
      ],
      "recursiveModules": [
        "css-align"
      ],
      "modulePrefixes": {
        "css-multicol": ["column-count-", "break-before-"]
      },
      "includePrefixes": [
        "flex-",
        "logical-",
        "content-"
      ]
    }`);

    expect(config.modules).toEqual([
      "css-flexbox",
      "css-logical",
      "css-content",
    ]);
    expect(config.recursiveModules).toEqual(["css-align"]);
    expect(config.modulePrefixes).toEqual({
      "css-multicol": ["column-count-", "break-before-"],
    });
    expect(config.includePrefixes).toEqual([
      "flex-",
      "logical-",
      "content-",
    ]);
  });
});
