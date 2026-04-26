import { readFileSync } from "node:fs";
import { describe, expect, test } from "vitest";
import {
  CraterBidiPage,
  CraterBrowser,
  CraterBrowserContext,
  CraterLocator,
  CRATER_PLAYWRIGHT_API_SUPPORT,
} from "../webdriver/playwright/adapter.ts";

const expectedBrowserApis = [
  "close",
  "contexts",
  "newContext",
  "newPage",
];

const expectedContextApis = [
  "close",
  "newPage",
  "pages",
  "storageState",
];

const expectedPageApis = [
  "$",
  "$$",
  "$$eval",
  "$eval",
  "addInitScript",
  "addScriptTag",
  "addStyleTag",
  "capturePaintData",
  "capturePaintTree",
  "captureScreenshot",
  "check",
  "click",
  "close",
  "connect",
  "content",
  "count",
  "createSiblingPage",
  "drag",
  "evaluate",
  "fill",
  "frameLocator",
  "getAllComputedStyles",
  "getAttribute",
  "getByAltText",
  "getByLabel",
  "getByPlaceholder",
  "getByRole",
  "getByTestId",
  "getByText",
  "getByTitle",
  "getComputedStyles",
  "getComputedStylesBySharedId",
  "getComputedStylesForElement",
  "getCssRuleUsage",
  "getCssRuleUsageDetails",
  "goto",
  "hover",
  "innerHTML",
  "inputValue",
  "isVisible",
  "keyboard",
  "loadPage",
  "locator",
  "onEvent",
  "press",
  "route",
  "screenshot",
  "select",
  "selectOption",
  "setContent",
  "setContentWithScripts",
  "setDefaultTimeout",
  "setViewport",
  "textContent",
  "title",
  "type",
  "uncheck",
  "unroute",
  "url",
  "waitForCondition",
  "waitForFunction",
  "waitForLoadState",
  "waitForNavigation",
  "waitForNetworkIdle",
  "waitForRequest",
  "waitForResponse",
  "waitForSelector",
  "waitForText",
  "waitForTimeout",
  "waitForURL",
];

const expectedLocatorApis = [
  "allInnerTexts",
  "allTextContents",
  "check",
  "clear",
  "click",
  "count",
  "dispatchEvent",
  "evaluate",
  "evaluateAll",
  "fill",
  "filter",
  "first",
  "focus",
  "getAttribute",
  "getByAltText",
  "getByLabel",
  "getByPlaceholder",
  "getByRole",
  "getByTestId",
  "getByText",
  "getByTitle",
  "hover",
  "innerHTML",
  "inputValue",
  "isChecked",
  "isDisabled",
  "isEditable",
  "isEnabled",
  "isHidden",
  "isVisible",
  "last",
  "locator",
  "nth",
  "press",
  "selectOption",
  "textContent",
  "type",
  "uncheck",
  "waitFor",
];

const adapterSource = readFileSync(
  new URL("../webdriver/playwright/adapter.ts", import.meta.url),
  "utf8",
);

function sourcePublicApiNames(className: string): string[] {
  const classMatch = new RegExp(`export class ${className}\\b`).exec(adapterSource);
  if (!classMatch) {
    throw new Error(`Class not found: ${className}`);
  }
  const rest = adapterSource.slice(classMatch.index);
  const nextClass = rest.indexOf("\nexport class ", 1);
  const classSource = nextClass === -1 ? rest : rest.slice(0, nextClass);
  const methods = new Set<string>();
  for (const line of classSource.split("\n")) {
    if (/^  (?:private|protected|constructor)\b/.test(line)) {
      continue;
    }
    const match = line.match(/^  (?:async\s+)?([A-Za-z_$][A-Za-z0-9_$]*)\s*(?:<[^>]+>)?\(/);
    if (match) {
      methods.add(match[1]);
      continue;
    }
    const fieldMatch = line.match(/^  (?:readonly\s+)?([A-Za-z_$][A-Za-z0-9_$]*)\s*=/);
    if (fieldMatch) {
      methods.add(fieldMatch[1]);
    }
  }
  return [...methods].sort();
}

function publicApisFor(owner: "browser" | "context" | "page" | "locator"): string[] {
  return CRATER_PLAYWRIGHT_API_SUPPORT
    .filter((entry) => entry.owner === owner && entry.status !== "unsupported")
    .map((entry) => entry.api)
    .sort();
}

function supportEntryFor(owner: "browser" | "context" | "page" | "locator", api: string) {
  const entry = CRATER_PLAYWRIGHT_API_SUPPORT.find((item) =>
    item.owner === owner && item.api === api
  );
  if (!entry) {
    throw new Error(`Missing support entry: ${owner}.${api}`);
  }
  return entry;
}

describe("Crater Playwright adapter support table", () => {
  test("has a stable public browser API list", () => {
    expect(publicApisFor("browser")).toEqual(expectedBrowserApis);
  });

  test("has a stable public context API list", () => {
    expect(publicApisFor("context")).toEqual(expectedContextApis);
  });

  test("has a stable public page API list", () => {
    expect(publicApisFor("page")).toEqual(expectedPageApis);
  });

  test("has a stable public locator API list", () => {
    expect(publicApisFor("locator")).toEqual(expectedLocatorApis);
  });

  test("does not contain duplicate owner/api entries", () => {
    const keys = CRATER_PLAYWRIGHT_API_SUPPORT.map((entry) => `${entry.owner}.${entry.api}`);
    expect(new Set(keys).size).toBe(keys.length);
  });

  test("classifies implementation-backed APIs separately from API mocks", () => {
    const implementations = new Set(
      CRATER_PLAYWRIGHT_API_SUPPORT.map((entry) => entry.implementation),
    );
    expect([...implementations].sort()).toEqual(["api-mock", "implemented", "unsupported"]);

    for (const entry of CRATER_PLAYWRIGHT_API_SUPPORT) {
      expect(["api-mock", "implemented", "unsupported"]).toContain(entry.implementation);
      if (entry.implementation === "api-mock") {
        expect(entry.status).toBe("partial");
      }
      if (entry.implementation === "unsupported") {
        expect(entry.status).toBe("unsupported");
      }
    }

    expect(supportEntryFor("page", "frameLocator").implementation).toBe("api-mock");
    expect(supportEntryFor("context", "storageState").implementation).toBe("implemented");
    expect(supportEntryFor("page", "keyboard").implementation).toBe("implemented");
  });

  test("explicitly lists unsupported long-tail Playwright event and file APIs", () => {
    const unsupported = [
      supportEntryFor("page", "on"),
      supportEntryFor("page", "waitForEvent"),
      supportEntryFor("page", "setInputFiles"),
      supportEntryFor("locator", "setInputFiles"),
    ];

    for (const entry of unsupported) {
      expect(entry.status).toBe("unsupported");
      expect(entry.implementation).toBe("unsupported");
      expect(entry.notes).toMatch(/not implemented|unsupported/i);
    }
  });

  test("lists every source-level public method in the support table", () => {
    expect(sourcePublicApiNames("CraterBrowser")).toEqual(expectedBrowserApis);
    expect(sourcePublicApiNames("CraterBrowserContext")).toEqual(expectedContextApis);
    expect(sourcePublicApiNames("CraterBidiPage")).toEqual(expectedPageApis);
    expect(sourcePublicApiNames("CraterLocator")).toEqual(expectedLocatorApis);
  });

  test("points every supported browser entry at an implemented method", () => {
    for (const api of expectedBrowserApis) {
      expect(typeof CraterBrowser.prototype[api as keyof CraterBrowser]).toBe("function");
    }
  });

  test("points every supported context entry at an implemented method", () => {
    for (const api of expectedContextApis) {
      expect(typeof CraterBrowserContext.prototype[api as keyof CraterBrowserContext]).toBe("function");
    }
  });

  test("points every supported page entry at an implemented method", () => {
    const page = new CraterBidiPage();
    for (const api of expectedPageApis) {
      const protoValue = CraterBidiPage.prototype[api as keyof CraterBidiPage];
      const instanceValue = page[api as keyof CraterBidiPage];
      expect(typeof protoValue === "function" || instanceValue !== undefined).toBe(true);
    }
  });

  test("points every supported locator entry at an implemented method", () => {
    for (const api of expectedLocatorApis) {
      expect(typeof CraterLocator.prototype[api as keyof CraterLocator]).toBe("function");
    }
  });
});
