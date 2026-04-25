export type CraterPlaywrightApiOwner = "page" | "locator";

export type CraterPlaywrightApiStatus =
  | "supported"
  | "partial"
  | "crater-extension";

export type CraterPlaywrightApiEntry = {
  owner: CraterPlaywrightApiOwner;
  api: string;
  status: CraterPlaywrightApiStatus;
  notes: string;
};

export const CRATER_PLAYWRIGHT_API_SUPPORT = [
  {
    owner: "page",
    api: "connect",
    status: "supported",
    notes: "Connects to the Crater WebDriver BiDi endpoint and creates one tab context.",
  },
  {
    owner: "page",
    api: "close",
    status: "supported",
    notes: "Closes the current browsing context and WebSocket.",
  },
  {
    owner: "page",
    api: "goto",
    status: "partial",
    notes: "Supports BiDi navigation, including data URLs. Browser-grade network loading is still limited.",
  },
  {
    owner: "page",
    api: "setContent",
    status: "supported",
    notes: "Loads HTML into Crater's DOM without executing embedded scripts.",
  },
  {
    owner: "page",
    api: "setContentWithScripts",
    status: "supported",
    notes: "Loads HTML and executes inline/classic/module scripts supported by Crater's runtime.",
  },
  {
    owner: "page",
    api: "loadPage",
    status: "partial",
    notes: "Wraps Crater page loading helpers; remote fetch and external module loading are not browser-equivalent yet.",
  },
  {
    owner: "page",
    api: "evaluate",
    status: "supported",
    notes: "Runs script.evaluate and unwraps serialized values.",
  },
  {
    owner: "page",
    api: "$$eval",
    status: "supported",
    notes: "Evaluates a function against querySelectorAll results.",
  },
  {
    owner: "page",
    api: "locator",
    status: "partial",
    notes: "Supports CSS plus text/role/placeholder/alt/title/testid/label selector shorthands.",
  },
  {
    owner: "page",
    api: "getByText",
    status: "partial",
    notes: "Text locator over Crater DOM direct text nodes.",
  },
  {
    owner: "page",
    api: "getByRole",
    status: "partial",
    notes: "Matches explicit role attributes only; full ARIA role inference is not implemented.",
  },
  {
    owner: "page",
    api: "getByPlaceholder",
    status: "partial",
    notes: "Matches placeholder attributes.",
  },
  {
    owner: "page",
    api: "getByAltText",
    status: "partial",
    notes: "Matches alt attributes.",
  },
  {
    owner: "page",
    api: "getByTitle",
    status: "partial",
    notes: "Matches title attributes.",
  },
  {
    owner: "page",
    api: "getByTestId",
    status: "supported",
    notes: "Matches data-testid attributes.",
  },
  {
    owner: "page",
    api: "getByLabel",
    status: "partial",
    notes: "Matches simple label text and for/input relationships.",
  },
  {
    owner: "page",
    api: "click",
    status: "supported",
    notes: "Uses WebDriver BiDi input.performActions with a pointer source.",
  },
  {
    owner: "page",
    api: "fill",
    status: "supported",
    notes: "Sets value and dispatches input/change events.",
  },
  {
    owner: "page",
    api: "type",
    status: "supported",
    notes: "Focuses via click and sends keyDown/keyUp actions.",
  },
  {
    owner: "page",
    api: "press",
    status: "supported",
    notes: "Sends one keyDown/keyUp pair.",
  },
  {
    owner: "page",
    api: "hover",
    status: "supported",
    notes: "Uses pointerMove to the target element.",
  },
  {
    owner: "page",
    api: "drag",
    status: "supported",
    notes: "Uses pointer actions from source to target.",
  },
  {
    owner: "page",
    api: "check",
    status: "supported",
    notes: "Clicks an unchecked checkbox/radio-like element.",
  },
  {
    owner: "page",
    api: "uncheck",
    status: "supported",
    notes: "Clicks a checked checkbox-like element.",
  },
  {
    owner: "page",
    api: "select",
    status: "partial",
    notes: "Selects by option value using keyboard actions.",
  },
  {
    owner: "page",
    api: "textContent",
    status: "supported",
    notes: "Returns querySelector textContent.",
  },
  {
    owner: "page",
    api: "innerHTML",
    status: "supported",
    notes: "Returns querySelector innerHTML.",
  },
  {
    owner: "page",
    api: "inputValue",
    status: "supported",
    notes: "Returns querySelector value.",
  },
  {
    owner: "page",
    api: "isVisible",
    status: "partial",
    notes: "Checks hidden/display/visibility; full browser visibility semantics are not implemented.",
  },
  {
    owner: "page",
    api: "getAttribute",
    status: "supported",
    notes: "Returns querySelector getAttribute.",
  },
  {
    owner: "page",
    api: "count",
    status: "supported",
    notes: "Returns querySelectorAll length.",
  },
  {
    owner: "page",
    api: "waitForSelector",
    status: "supported",
    notes: "Polls querySelector until found.",
  },
  {
    owner: "page",
    api: "waitForText",
    status: "supported",
    notes: "Polls textContent until an exact string matches.",
  },
  {
    owner: "page",
    api: "waitForCondition",
    status: "supported",
    notes: "Polls a JavaScript expression until it returns truthy.",
  },
  {
    owner: "page",
    api: "waitForLoadState",
    status: "partial",
    notes: "load/domcontentloaded are immediate after Crater load; networkidle uses Crater runtime helpers.",
  },
  {
    owner: "page",
    api: "waitForNetworkIdle",
    status: "partial",
    notes: "Uses Crater runtime network-idle helpers.",
  },
  {
    owner: "page",
    api: "waitForNavigation",
    status: "partial",
    notes: "Resolves on subscribed BiDi load/domContentLoaded events.",
  },
  {
    owner: "page",
    api: "setViewport",
    status: "crater-extension",
    notes: "Crater BiDi extension for layout/VRT control.",
  },
  {
    owner: "page",
    api: "captureScreenshot",
    status: "crater-extension",
    notes: "Crater BiDi screenshot data helper.",
  },
  {
    owner: "page",
    api: "capturePaintData",
    status: "crater-extension",
    notes: "Crater BiDi RGBA paint capture helper.",
  },
  {
    owner: "page",
    api: "capturePaintTree",
    status: "crater-extension",
    notes: "Crater BiDi paint tree capture helper.",
  },
  {
    owner: "page",
    api: "getComputedStyles",
    status: "crater-extension",
    notes: "Crater computed style inspection helper.",
  },
  {
    owner: "page",
    api: "getComputedStylesBySharedId",
    status: "crater-extension",
    notes: "Crater computed style inspection helper.",
  },
  {
    owner: "page",
    api: "getAllComputedStyles",
    status: "crater-extension",
    notes: "Crater computed style inspection helper.",
  },
  {
    owner: "page",
    api: "getComputedStylesForElement",
    status: "crater-extension",
    notes: "Crater computed style inspection helper.",
  },
  {
    owner: "page",
    api: "getCssRuleUsage",
    status: "crater-extension",
    notes: "Crater CSS rule usage inspection helper.",
  },
  {
    owner: "page",
    api: "getCssRuleUsageDetails",
    status: "crater-extension",
    notes: "Crater CSS rule usage inspection helper.",
  },
  {
    owner: "locator",
    api: "locator",
    status: "partial",
    notes: "Chains a child locator under the first matching parent.",
  },
  {
    owner: "locator",
    api: "filter",
    status: "partial",
    notes: "Supports hasText/hasNotText filters.",
  },
  {
    owner: "locator",
    api: "getByText",
    status: "partial",
    notes: "Child text locator.",
  },
  {
    owner: "locator",
    api: "getByRole",
    status: "partial",
    notes: "Child explicit-role locator.",
  },
  {
    owner: "locator",
    api: "first",
    status: "supported",
    notes: "Selects the first match.",
  },
  {
    owner: "locator",
    api: "last",
    status: "supported",
    notes: "Selects the last match.",
  },
  {
    owner: "locator",
    api: "nth",
    status: "supported",
    notes: "Selects a zero-based match.",
  },
  {
    owner: "locator",
    api: "click",
    status: "supported",
    notes: "Calls element.click() in the Crater runtime.",
  },
  {
    owner: "locator",
    api: "fill",
    status: "supported",
    notes: "Sets value and dispatches input/change events.",
  },
  {
    owner: "locator",
    api: "textContent",
    status: "supported",
    notes: "Returns element textContent.",
  },
  {
    owner: "locator",
    api: "innerHTML",
    status: "supported",
    notes: "Returns element innerHTML.",
  },
  {
    owner: "locator",
    api: "inputValue",
    status: "supported",
    notes: "Returns element value.",
  },
  {
    owner: "locator",
    api: "isVisible",
    status: "partial",
    notes: "Checks hidden/display/visibility.",
  },
  {
    owner: "locator",
    api: "getAttribute",
    status: "supported",
    notes: "Returns element getAttribute.",
  },
  {
    owner: "locator",
    api: "waitFor",
    status: "supported",
    notes: "Polls until a matching element exists.",
  },
  {
    owner: "locator",
    api: "count",
    status: "supported",
    notes: "Returns match count.",
  },
] as const satisfies readonly CraterPlaywrightApiEntry[];

export function craterPlaywrightApisFor(owner: CraterPlaywrightApiOwner) {
  return CRATER_PLAYWRIGHT_API_SUPPORT.filter((entry) => entry.owner === owner);
}
