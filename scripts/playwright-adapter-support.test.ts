import { describe, expect, test } from "vitest";
import {
  CraterBidiPage,
  CraterLocator,
  CRATER_PLAYWRIGHT_API_SUPPORT,
} from "../webdriver/playwright/adapter.ts";

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
  "drag",
  "evaluate",
  "fill",
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
  "loadPage",
  "locator",
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
  "getByRole",
  "getByText",
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

describe("Crater Playwright adapter support table", () => {
  test("has a stable public page API list", () => {
    const pageApis = CRATER_PLAYWRIGHT_API_SUPPORT
      .filter((entry) => entry.owner === "page")
      .map((entry) => entry.api)
      .sort();
    expect(pageApis).toEqual(expectedPageApis);
  });

  test("has a stable public locator API list", () => {
    const locatorApis = CRATER_PLAYWRIGHT_API_SUPPORT
      .filter((entry) => entry.owner === "locator")
      .map((entry) => entry.api)
      .sort();
    expect(locatorApis).toEqual(expectedLocatorApis);
  });

  test("does not contain duplicate owner/api entries", () => {
    const keys = CRATER_PLAYWRIGHT_API_SUPPORT.map((entry) => `${entry.owner}.${entry.api}`);
    expect(new Set(keys).size).toBe(keys.length);
  });

  test("points every supported page entry at an implemented method", () => {
    for (const api of expectedPageApis) {
      expect(typeof CraterBidiPage.prototype[api as keyof CraterBidiPage]).toBe("function");
    }
  });

  test("points every supported locator entry at an implemented method", () => {
    for (const api of expectedLocatorApis) {
      expect(typeof CraterLocator.prototype[api as keyof CraterLocator]).toBe("function");
    }
  });
});
