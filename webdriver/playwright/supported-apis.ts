export type CraterPlaywrightApiOwner =
  | "browser"
  | "context"
  | "page"
  | "locator";

export type CraterPlaywrightApiStatus =
  | "supported"
  | "partial"
  | "crater-extension"
  | "unsupported";

export type CraterPlaywrightApiImplementation =
  | "implemented"
  | "api-mock"
  | "unsupported";

export type CraterPlaywrightApiEntry = {
  owner: CraterPlaywrightApiOwner;
  api: string;
  status: CraterPlaywrightApiStatus;
  implementation: CraterPlaywrightApiImplementation;
  notes: string;
};

type CraterPlaywrightApiSourceEntry =
  Omit<CraterPlaywrightApiEntry, "implementation"> & {
    implementation?: CraterPlaywrightApiImplementation;
  };

const CRATER_PLAYWRIGHT_API_SUPPORT_SOURCE = [
  {
    owner: "browser",
    api: "newContext",
    status: "partial",
    notes: "Creates a lightweight Crater context wrapper until browser.close(); Playwright BrowserContext options such as preloaded storageState/cookies are not implemented.",
  },
  {
    owner: "browser",
    api: "newPage",
    status: "partial",
    notes: "Convenience helper that creates a new Crater context and page until browser.close(); browser-process semantics are not implemented.",
  },
  {
    owner: "browser",
    api: "contexts",
    status: "supported",
    notes: "Returns currently open tracked Crater context wrappers; manually closed contexts are removed.",
  },
  {
    owner: "browser",
    api: "close",
    status: "partial",
    notes: "Idempotently closes tracked contexts and pages best-effort over the Crater BiDi transport; the closed browser rejects new contexts.",
  },
  {
    owner: "context",
    api: "newPage",
    status: "partial",
    notes: "Creates an isolated Crater tab over a hidden shared BiDi transport page; context-level storage/session isolation is not implemented.",
  },
  {
    owner: "context",
    api: "pages",
    status: "supported",
    notes: "Returns currently open tracked Crater pages; manually closed pages are removed.",
  },
  {
    owner: "context",
    api: "storageState",
    status: "partial",
    notes: "Snapshots visible cookies and localStorage from currently open Crater pages into Playwright's { cookies, origins } shape; preloading, httpOnly cookie metadata, and sessionStorage are not implemented.",
  },
  {
    owner: "context",
    api: "close",
    status: "partial",
    notes: "Idempotently closes tracked pages and the hidden shared transport best-effort; the closed context rejects new pages.",
  },
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
    api: "onEvent",
    status: "crater-extension",
    notes: "Low-level Crater BiDi event hook used by adapter internals and diagnostics.",
  },
  {
    owner: "page",
    api: "createSiblingPage",
    status: "crater-extension",
    notes: "Low-level helper that creates another tab over the same Crater BiDi transport.",
  },
  {
    owner: "page",
    api: "url",
    status: "supported",
    notes: "Returns window.location.href from the current Crater runtime.",
  },
  {
    owner: "page",
    api: "title",
    status: "supported",
    notes: "Returns document.title.",
  },
  {
    owner: "page",
    api: "content",
    status: "supported",
    notes: "Returns document.documentElement.outerHTML.",
  },
  {
    owner: "page",
    api: "goto",
    status: "partial",
    notes: "Loads http/https/data URLs through Crater runtime, follows fetch redirects, preserves HTTP error documents, runs init scripts before page scripts, and returns response metadata; browser-grade navigation remains limited.",
  },
  {
    owner: "page",
    api: "setContent",
    status: "supported",
    notes: "Loads HTML into an about:blank Crater document and executes inline/classic/module scripts supported by Crater's runtime.",
  },
  {
    owner: "page",
    api: "setContentWithScripts",
    status: "supported",
    notes: "Compatibility alias for setContent().",
  },
  {
    owner: "page",
    api: "setDefaultTimeout",
    status: "partial",
    notes: "Overrides timeout defaults for Crater polling-based wait helpers.",
  },
  {
    owner: "page",
    api: "keyboard",
    status: "partial",
    notes: "Exposes a minimal Playwright-like keyboard object with type/press/down/up/insertText; insertText mutates the focused editable element without key or native composition events.",
  },
  {
    owner: "page",
    api: "loadPage",
    status: "partial",
    notes: "Fetches a URL through Crater runtime, parses HTML including 4xx/5xx documents, emits observable document network events when hooks are installed, runs init scripts, and executes supported scripts against the final response URL; remote and module loading are still not browser-equivalent.",
  },
  {
    owner: "page",
    api: "addInitScript",
    status: "partial",
    notes: "Stores serializable init scripts and runs them before Crater executes page scripts.",
  },
  {
    owner: "page",
    api: "addScriptTag",
    status: "partial",
    notes: "Injects a script tag and executes content/url text in the Crater runtime.",
  },
  {
    owner: "page",
    api: "addStyleTag",
    status: "partial",
    notes: "Injects a style tag with content or fetched url text.",
  },
  {
    owner: "page",
    api: "evaluate",
    status: "supported",
    notes: "Runs script.evaluate and recursively unwraps serializable BiDi values, with optional JSON-serializable arg support.",
  },
  {
    owner: "page",
    api: "$",
    status: "partial",
    notes: "Returns a Crater locator for the first matching element, not a Playwright ElementHandle.",
  },
  {
    owner: "page",
    api: "$$",
    status: "partial",
    notes: "Returns Crater locators for matching elements, not Playwright ElementHandles.",
  },
  {
    owner: "page",
    api: "$eval",
    status: "partial",
    notes: "Evaluates a serializable function against the first matching element.",
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
    notes: "Supports CSS plus text/role/placeholder/alt/title/testid/label selector shorthands over Crater's composed traversal for open shadow DOM; XPath locators are not implemented.",
  },
  {
    owner: "page",
    api: "frameLocator",
    status: "partial",
    implementation: "api-mock",
    notes: "Creates locators rooted at an iframe contentDocument/contentWindow.document or synthetic fixture root; independent iframe browsing contexts and iframe navigation are not implemented.",
  },
  {
    owner: "page",
    api: "on",
    status: "unsupported",
    implementation: "unsupported",
    notes: "Playwright's EventEmitter-style page.on() API is not implemented; dialog/download/filechooser events are intentionally unsupported at the adapter layer for now.",
  },
  {
    owner: "page",
    api: "waitForEvent",
    status: "unsupported",
    implementation: "unsupported",
    notes: "Playwright waitForEvent() is not implemented; dialog/download/filechooser flows should stay in WebDriver BiDi/WPT coverage until an adapter user scenario is defined.",
  },
  {
    owner: "page",
    api: "setInputFiles",
    status: "unsupported",
    implementation: "unsupported",
    notes: "Playwright page.setInputFiles() is not implemented; WebDriver BiDi input.setFiles coverage exists, but there is no Playwright adapter wrapper yet.",
  },
  {
    owner: "page",
    api: "getByText",
    status: "partial",
    notes: "Text locator over Crater DOM with Playwright-style whitespace normalization, exact/RegExp matching, and open shadow DOM traversal; closed shadow DOM is excluded.",
  },
  {
    owner: "page",
    api: "getByRole",
    status: "partial",
    notes: "Matches explicit roles, common native implicit roles, basic accessible names, default hidden filtering, exact/includeHidden/disabled options, and open shadow DOM traversal; full ARIA role inference and slot-based accessible names are not implemented.",
  },
  {
    owner: "page",
    api: "getByPlaceholder",
    status: "partial",
    notes: "Matches placeholder attributes with default substring, exact, or RegExp matching over open shadow DOM traversal.",
  },
  {
    owner: "page",
    api: "getByAltText",
    status: "partial",
    notes: "Matches alt attributes with default substring, exact, or RegExp matching over open shadow DOM traversal.",
  },
  {
    owner: "page",
    api: "getByTitle",
    status: "partial",
    notes: "Matches title attributes with default substring, exact, or RegExp matching over open shadow DOM traversal.",
  },
  {
    owner: "page",
    api: "getByTestId",
    status: "supported",
    notes: "Matches data-testid attributes by exact string or RegExp over open shadow DOM traversal.",
  },
  {
    owner: "page",
    api: "getByLabel",
    status: "partial",
    notes: "Matches label text, for/nested controls, aria-label, and aria-labelledby with exact/RegExp support in the same tree scope, including open shadow DOM.",
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
    notes: "Sets input/textarea value or contenteditable textContent and dispatches input/change events.",
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
    notes: "Sends a key press through BiDi input.performActions, including basic plus-separated modifier chords.",
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
    api: "selectOption",
    status: "partial",
    notes: "Playwright-style alias that selects option(s) by value, label fallback, or basic { value | label | index } descriptors.",
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
    notes: "Checks hidden/display ancestor state and element visibility; full browser visibility semantics are not implemented.",
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
    api: "route",
    status: "partial",
    notes: "Intercepts Crater runtime fetch(), document loads, and supported external classic script/subresource loads with fulfill/continue/abort decisions.",
  },
  {
    owner: "page",
    api: "unroute",
    status: "partial",
    notes: "Removes Crater runtime fetch() route handlers by matcher identity or clears all handlers.",
  },
  {
    owner: "page",
    api: "waitForFunction",
    status: "partial",
    notes: "Polls a serializable expression/function until it returns a truthy serialized value.",
  },
  {
    owner: "page",
    api: "waitForRequest",
    status: "partial",
    notes: "Waits for Crater runtime fetch(), document, external classic script, and best-effort style/image requests observed by the adapter network hook.",
  },
  {
    owner: "page",
    api: "waitForResponse",
    status: "partial",
    notes: "Waits for Crater runtime fetch(), document, and external classic script responses observed by the adapter network hook; style/image response details are best-effort.",
  },
  {
    owner: "page",
    api: "waitForURL",
    status: "partial",
    notes: "Polls current URL against string, RegExp, or URL predicate matchers and consumes pending Crater location.assign/replace/reload navigation.",
  },
  {
    owner: "page",
    api: "waitForLoadState",
    status: "partial",
    notes: "Consumes pending Crater location navigation; load/domcontentloaded are immediate after Crater load; networkidle uses Crater runtime helpers.",
  },
  {
    owner: "page",
    api: "waitForNetworkIdle",
    status: "partial",
    notes: "Uses Crater runtime network-idle helpers.",
  },
  {
    owner: "page",
    api: "waitForTimeout",
    status: "supported",
    notes: "Resolves after the requested host-side timeout.",
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
    api: "screenshot",
    status: "partial",
    notes: "Playwright-style alias for Crater screenshot capture.",
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
    notes: "Supports hasText/hasNotText filters with Playwright-style whitespace normalization.",
  },
  {
    owner: "locator",
    api: "getByText",
    status: "partial",
    notes: "Child text locator with whitespace normalization, exact/RegExp matching, and open shadow DOM traversal.",
  },
  {
    owner: "locator",
    api: "getByRole",
    status: "partial",
    notes: "Child role locator with the same partial role/name/hidden/exact/disabled/open-shadow support as page.getByRole.",
  },
  {
    owner: "locator",
    api: "getByPlaceholder",
    status: "partial",
    notes: "Child placeholder locator with default substring, exact, or RegExp matching over open shadow DOM traversal.",
  },
  {
    owner: "locator",
    api: "getByAltText",
    status: "partial",
    notes: "Child alt-text locator with default substring, exact, or RegExp matching over open shadow DOM traversal.",
  },
  {
    owner: "locator",
    api: "getByTitle",
    status: "partial",
    notes: "Child title locator with default substring, exact, or RegExp matching over open shadow DOM traversal.",
  },
  {
    owner: "locator",
    api: "getByTestId",
    status: "supported",
    notes: "Child test-id locator by exact data-testid string or RegExp over open shadow DOM traversal.",
  },
  {
    owner: "locator",
    api: "getByLabel",
    status: "partial",
    notes: "Child label locator with for/nested controls, aria-label, aria-labelledby, exact/RegExp matching, and open shadow DOM traversal.",
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
    notes: "Waits for attached/visible/enabled/stable target state, then calls element.click() in the Crater runtime.",
  },
  {
    owner: "locator",
    api: "hover",
    status: "partial",
    notes: "Waits for attached/visible/enabled/stable target state, then dispatches pointerenter/mouseover events in the Crater runtime.",
  },
  {
    owner: "locator",
    api: "focus",
    status: "partial",
    notes: "Waits for attached/visible/enabled/stable target state, then focuses the element when available and dispatches focus/focusin events.",
  },
  {
    owner: "locator",
    api: "fill",
    status: "supported",
    notes: "Waits for attached/visible/enabled/stable target state, then sets input/textarea value or contenteditable textContent and dispatches input/change events.",
  },
  {
    owner: "locator",
    api: "clear",
    status: "supported",
    notes: "Clears value and dispatches input/change events.",
  },
  {
    owner: "locator",
    api: "type",
    status: "partial",
    notes: "Focuses the target and uses the BiDi keyboard pipeline for input/textarea selection, beforeinput, and input events; contenteditable typing is textContent-based and narrower than browser editing.",
  },
  {
    owner: "locator",
    api: "press",
    status: "partial",
    notes: "Focuses the target and sends a key press through BiDi input.performActions, including basic plus-separated modifier chords.",
  },
  {
    owner: "locator",
    api: "dispatchEvent",
    status: "partial",
    notes: "Dispatches Event or CustomEvent with serializable init data; composition and input event shapes are covered for synthetic IME-style test flows.",
  },
  {
    owner: "locator",
    api: "check",
    status: "supported",
    notes: "Waits for attached/visible/enabled/stable target state, then sets checkbox/radio checked state and dispatches input/change events.",
  },
  {
    owner: "locator",
    api: "uncheck",
    status: "supported",
    notes: "Waits for attached/visible/enabled/stable target state, then clears checkbox checked state and dispatches input/change events.",
  },
  {
    owner: "locator",
    api: "selectOption",
    status: "partial",
    notes: "Waits for attached/visible/enabled/stable target state, then selects option(s) by value, label fallback, or basic descriptors and dispatches input/change events.",
  },
  {
    owner: "locator",
    api: "setInputFiles",
    status: "unsupported",
    implementation: "unsupported",
    notes: "Playwright locator.setInputFiles() is not implemented; file chooser and file input upload scenarios are not exposed through the adapter yet.",
  },
  {
    owner: "locator",
    api: "evaluate",
    status: "partial",
    notes: "Evaluates a serializable function against the first matching element and unwraps serializable BiDi values.",
  },
  {
    owner: "locator",
    api: "evaluateAll",
    status: "partial",
    notes: "Evaluates a serializable function against all matching elements and unwraps serializable BiDi values.",
  },
  {
    owner: "locator",
    api: "allTextContents",
    status: "supported",
    notes: "Returns textContent for all matching elements.",
  },
  {
    owner: "locator",
    api: "allInnerTexts",
    status: "partial",
    notes: "Returns innerText when available, falling back to textContent.",
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
    notes: "Checks hidden/display ancestor state and element visibility.",
  },
  {
    owner: "locator",
    api: "isHidden",
    status: "partial",
    notes: "Inverse of Crater isVisible().",
  },
  {
    owner: "locator",
    api: "isChecked",
    status: "supported",
    notes: "Returns checked state.",
  },
  {
    owner: "locator",
    api: "isDisabled",
    status: "partial",
    notes: "Checks disabled property, disabled attribute fallback, and aria-disabled=true.",
  },
  {
    owner: "locator",
    api: "isEnabled",
    status: "partial",
    notes: "Inverse of Crater isDisabled().",
  },
  {
    owner: "locator",
    api: "isEditable",
    status: "partial",
    notes: "Checks simple input/textarea/contenteditable editability.",
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
] as const satisfies readonly CraterPlaywrightApiSourceEntry[];

export const CRATER_PLAYWRIGHT_API_SUPPORT = CRATER_PLAYWRIGHT_API_SUPPORT_SOURCE.map((entry) => ({
  implementation: "implemented" as const,
  ...entry,
})) satisfies readonly CraterPlaywrightApiEntry[];

export function craterPlaywrightApisFor(owner: CraterPlaywrightApiOwner) {
  return CRATER_PLAYWRIGHT_API_SUPPORT.filter((entry) => entry.owner === owner);
}
