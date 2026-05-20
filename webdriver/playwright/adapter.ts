import { copyFile, mkdir, readFile, unlink, writeFile } from "node:fs/promises";
import { createServer } from "node:net";
import { dirname } from "node:path";
import WebSocket from "ws";
import {
  ensureCraterBidiServer,
  type CraterBidiServerHandle,
  type EnsureCraterBidiServerOptions,
} from "../../scripts/crater-bidi-server.ts";
import { resolveBidiUrl } from "../../scripts/bidi-url.ts";
import {
  modelContextRuntimeExpression,
  type CraterModelContextToolCallEnvelope,
  type CraterModelContextToolDescriptor,
} from "./model-context.ts";
export {
  CRATER_PLAYWRIGHT_API_SUPPORT,
  craterPlaywrightApisFor,
} from "./supported-apis.ts";
export type {
  CraterModelContextToolAnnotations,
  CraterModelContextToolDescriptor,
} from "./model-context.ts";
export type {
  CraterPlaywrightApiEntry,
  CraterPlaywrightApiImplementation,
  CraterPlaywrightApiOwner,
  CraterPlaywrightApiStatus,
} from "./supported-apis.ts";

export interface BidiResponse {
  id: number;
  type: "success" | "error";
  result?: unknown;
  error?: string;
  message?: string;
}

export interface BidiEvent {
  type: "event";
  method: string;
  params: unknown;
}

export type CraterBidiConnectOptions = {
  timeout?: number;
  retries?: number;
  url?: string;
};

export type CraterLaunchOptions = CraterBidiConnectOptions & {
  autoStartBidi?: boolean;
  isolateContexts?: boolean;
  craterRoot?: string;
  denoBin?: string;
  env?: NodeJS.ProcessEnv;
  headless?: boolean;
  args?: string[];
  executablePath?: string;
  serverTimeoutMs?: number;
  pollIntervalMs?: number;
  statusTimeoutMs?: number;
  statusUrl?: string;
  stdio?: EnsureCraterBidiServerOptions["stdio"];
  shutdownTimeoutMs?: number;
};

export type CraterBrowserTypeDependencies = {
  ensureBidiServer?: (
    options?: EnsureCraterBidiServerOptions,
  ) => Promise<CraterBidiServerHandle>;
  allocateBidiPort?: () => Promise<number>;
};

export type CraterViewportSize = {
  width: number;
  height: number;
};

export type CraterBrowserContextOptions = CraterBidiConnectOptions & {
  storageState?: CraterStorageState | string;
  viewport?: CraterViewportSize | null;
  userAgent?: string;
  locale?: string;
  offline?: boolean;
  geolocation?: CraterGeolocation | null;
  permissions?: string[];
};

export type CraterEvaluateOptions = {
  awaitPromise?: boolean;
};

export type CraterInitScript = string | (() => unknown | Promise<unknown>);

export type CraterLoadState =
  | "load"
  | "domcontentloaded"
  | "networkidle"
  | "networkidle0"
  | "networkidle2";

export type CraterGotoWaitUntil = CraterLoadState | "commit";

export type CraterGotoOptions = {
  timeout?: number;
  waitUntil?: CraterGotoWaitUntil;
};

export type CraterUrlMatcher = string | RegExp | ((url: URL) => boolean);

export type CraterRequestMatcher =
  | string
  | RegExp
  | ((request: CraterRequest) => boolean | Promise<boolean>);

export type CraterResponseMatcher =
  | string
  | RegExp
  | ((response: CraterResponse) => boolean | Promise<boolean>);

export type CraterAddScriptTagOptions = {
  content?: string;
  url?: string;
  type?: string;
};

export type CraterAddStyleTagOptions = {
  content?: string;
  url?: string;
};

export type CraterWaitForFunctionOptions = {
  timeout?: number;
  polling?: number;
};

export type CraterLocatorActionOptions = {
  timeout?: number;
  /**
   * Skip the actionability check (visible + enabled + stable bounding rect).
   * Matches Playwright's `force` option. Useful for pages where Crater's
   * visibility heuristic incorrectly rejects an element (#207) — the caller
   * has already decided the element is the right target.
   */
  force?: boolean;
};

const FULL_PAGE_SCREENSHOT_MAX_HEIGHT = 16384;

export type CraterScreenshotClip = {
  x: number;
  y: number;
  width: number;
  height: number;
};

export type CraterScreenshotOptions = {
  fullPage?: boolean;
  timeout?: number;
  clip?: CraterScreenshotClip;
  type?: "png" | "jpeg";
  quality?: number;
  path?: string;
};

export type CraterAriaSnapshotOptions = {
  mode?: string;
  depth?: number;
  timeout?: number;
};

export type CraterA11ySnapshotNode = {
  role: string;
  name?: string;
  value?: string | number;
  description?: string;
  modal?: boolean;
  expanded?: boolean;
  checked?: boolean | "mixed";
  disabled?: boolean;
  selected?: boolean;
  children?: CraterA11ySnapshotNode[];
};

export type CraterWaitForSelectorState = "attached" | "detached" | "visible" | "hidden";

export type CraterWaitForSelectorOptions = {
  timeout?: number;
  state?: CraterWaitForSelectorState;
};

export type CraterWaitForNetworkOptions = {
  timeout?: number;
  polling?: number;
};

export type CraterRouteFulfillOptions = {
  status?: number;
  headers?: Record<string, string>;
  contentType?: string;
  body?: string | Buffer | Uint8Array | Record<string, unknown> | unknown[];
};

export type CraterRouteContinueOptions = {
  url?: string;
  method?: string;
  headers?: Record<string, string>;
  postData?: string;
};

export type CraterRouteHandler = (
  route: CraterRoute,
  request: CraterRequest,
) => void | Promise<void>;

export type CraterGetByRoleOptions = {
  name?: string | RegExp;
  exact?: boolean;
  includeHidden?: boolean;
  disabled?: boolean;
};

export type CraterTextMatcher = string | RegExp;

export type CraterTextMatchOptions = {
  exact?: boolean;
};

export type CraterSelectOptionSingle =
  | string
  | {
    value?: string;
    label?: string;
    index?: number;
  };

export type CraterSelectOptionValue = CraterSelectOptionSingle | CraterSelectOptionSingle[];

export type CraterSetInputFilePayload = {
  name: string;
  mimeType?: string;
  buffer: Buffer | Uint8Array | ArrayBuffer | string;
};

export type CraterSetInputFile = string | CraterSetInputFilePayload;

export type CraterSetInputFilesValue = CraterSetInputFile | CraterSetInputFile[];

export type CraterStorageCookie = {
  name: string;
  value: string;
  url?: string;
  domain?: string;
  path?: string;
  expires?: number;
  httpOnly?: boolean;
  secure?: boolean;
  sameSite?: "Lax" | "None" | "Strict";
};

export type CraterStorageOrigin = {
  origin: string;
  localStorage: Array<{ name: string; value: string }>;
};

export type CraterStorageState = {
  cookies: CraterStorageCookie[];
  origins: CraterStorageOrigin[];
};

export type CraterStorageStateOptions = {
  path?: string;
};

export type CraterCookieUrlFilter = string | string[];

export type CraterClearCookiesOptions = {
  name?: string | RegExp;
  domain?: string | RegExp;
  path?: string | RegExp;
};

export type CraterGeolocation = {
  latitude: number;
  longitude: number;
  accuracy?: number;
  altitude?: number;
  altitudeAccuracy?: number;
  heading?: number;
  speed?: number;
};

export type CraterGrantPermissionsOptions = {
  origin?: string;
};

type CraterStorageCookieValue = {
  type?: string;
  value?: string;
};

type CraterPermissionState = "granted" | "denied" | "prompt";

type CraterPermissionGrant = {
  permissions: string[];
  origin?: string;
};

type PendingCommand = {
  resolve: (value: BidiResponse) => void;
  reject: (error: Error) => void;
};

type CraterNetworkRequestPayload = {
  id: string;
  url: string;
  method: string;
  headers: Record<string, string>;
  postData?: string | null;
};

type CraterNetworkResponsePayload = {
  url: string;
  status: number;
  statusText?: string;
  headers: Record<string, string>;
  body?: string | null;
  request: CraterNetworkRequestPayload;
};

type CraterPageLoadResult = {
  requestedUrl?: string;
  url: string;
  status: number;
  statusText?: string;
  headers?: Record<string, string>;
  body?: string | null;
  scripts?: CraterScriptExecutionResult[];
};

type CraterScriptExecutionResult = {
  error?: boolean;
  message?: string;
  src?: string;
  status?: number;
  inline?: boolean;
  module?: boolean;
};

type CraterNetworkEventPayload =
  | {
    type: "request";
    timestamp: number;
    request: CraterNetworkRequestPayload;
  }
  | {
    type: "response";
    timestamp: number;
    request: CraterNetworkRequestPayload;
    response: CraterNetworkResponsePayload;
  }
  | {
    type: "requestfailed";
    timestamp: number;
    request: CraterNetworkRequestPayload;
    errorText: string;
  };

type CraterFileChooserEventPayload = {
  selector: string;
  multiple: boolean;
};

export type CraterDialogType = "alert" | "beforeunload" | "confirm" | "prompt";

type CraterDialogEventPayload = {
  context: string;
  type: CraterDialogType;
  message: string;
  defaultValue?: string;
};

type CraterDownloadWillBeginPayload = {
  context: string;
  navigation: string | null;
  suggestedFilename: string;
  url: string;
};

type CraterDownloadEndPayload = {
  context: string;
  navigation: string | null;
  status: string;
  filepath: string | null;
  url: string;
};

type CraterConsoleEventPayload = {
  type: string;
  text: string;
  args: string[];
  timestamp: number;
};

type CraterPendingDownload = {
  download: CraterDownload;
  resolveEnd: (end: CraterDownloadEndPayload) => void;
};

export type CraterPageEventMap = {
  request: CraterRequest;
  response: CraterResponse;
  requestfailed: CraterRequestFailure;
  filechooser: CraterFileChooser;
  dialog: CraterDialog;
  download: CraterDownload;
  console: CraterConsoleMessage;
  pageerror: Error;
  load: CraterBidiPage;
  domcontentloaded: CraterBidiPage;
  close: CraterBidiPage;
};

export type CraterPageEventName = keyof CraterPageEventMap;

export type CraterPageEventPayload = CraterPageEventMap[CraterPageEventName];

type CraterLocalPageEventName = Exclude<
  CraterPageEventName,
  "request" | "response" | "requestfailed" | "filechooser"
>;

export type CraterPageEventHandler<T = CraterPageEventPayload> = (event: T) => void;

export type CraterWaitForEventOptions<T = CraterPageEventPayload> = {
  timeout?: number;
  predicate?: (event: T) => boolean | Promise<boolean>;
};

type CraterPageEventWaiter = {
  eventName: string;
  predicate?: (event: CraterPageEventPayload) => boolean | Promise<boolean>;
  resolve: (event: CraterPageEventPayload) => void;
  reject: (error: Error) => void;
  timer: ReturnType<typeof setTimeout>;
  settled: boolean;
};

type CraterRouteDecision =
  | {
    action: "fulfill";
    status: number;
    headers: Record<string, string>;
    body: string;
  }
  | {
    action: "continue";
    url?: string;
    method?: string;
    headers?: Record<string, string>;
    postData?: string;
  }
  | {
    action: "abort";
    errorCode?: string;
  };

type CraterRouteEntry = {
  matcher: CraterRequestMatcher;
  handler: CraterRouteHandler;
};

type SharedBidiConnection = {
  sendBidi(method: string, params: unknown): Promise<BidiResponse>;
  onEvent(handler: (event: BidiEvent) => void): void;
};

type CraterPageCloseHandler = (page: CraterBidiPage) => void;
type CraterContextCloseHandler = (context: CraterBrowserContext) => void;
type CraterTransportProvider = (options: CraterBidiConnectOptions) => Promise<CraterBidiPage>;

async function allocateBidiPort(): Promise<number> {
  return await new Promise((resolve, reject) => {
    const server = createServer();
    server.unref();
    server.once("error", reject);
    server.listen(0, "127.0.0.1", () => {
      const address = server.address();
      server.close((error) => {
        if (error) {
          reject(error);
          return;
        }
        if (address && typeof address === "object") {
          resolve(address.port);
        } else {
          reject(new Error("Failed to allocate a Crater BiDi port"));
        }
      });
    });
  });
}

type CraterTimeoutResolver = (timeout: number | undefined, fallback: number) => number;

type ParsedLocatorSelector = {
  type: string;
  value: string;
  exact?: boolean;
  regexp?: boolean;
  flags?: string;
};

type LocatorFilter = {
  kind: "hasText" | "hasNotText" | "hasAccessibleName" | "visible" | "disabled";
  value: string;
  flags?: string;
  regexp: boolean;
  exact?: boolean;
};

const SPECIAL_KEYS: Record<string, string> = {
  Enter: "\uE006",
  Tab: "\uE004",
  Backspace: "\uE003",
  Delete: "\uE017",
  ArrowLeft: "\uE012",
  ArrowRight: "\uE014",
  ArrowUp: "\uE013",
  ArrowDown: "\uE015",
  Shift: "\uE008",
  Control: "\uE009",
  Alt: "\uE00A",
  Meta: "\uE03D",
  Space: " ",
};

const keyValue = (key: string): string => SPECIAL_KEYS[key] ?? key;

function normalizeModifierKey(key: string): string | null {
  if (key === "ControlOrMeta") return process.platform === "darwin" ? "Meta" : "Control";
  if (key === "Control" || key === "Meta" || key === "Shift" || key === "Alt") return key;
  return null;
}

function keyPressActions(key: string): Array<Record<string, string>> {
  const parts = key.includes("+") && key !== "+" ? key.split("+").filter((part) => part !== "") : [key];
  if (parts.length === 1) {
    return [
      { type: "keyDown", value: keyValue(parts[0]) },
      { type: "keyUp", value: keyValue(parts[0]) },
    ];
  }

  const keyPart = parts[parts.length - 1];
  const modifiers = parts.slice(0, -1).map((part) => normalizeModifierKey(part) ?? part);
  return [
    ...modifiers.map((modifier) => ({ type: "keyDown", value: keyValue(modifier) })),
    { type: "keyDown", value: keyValue(keyPart) },
    { type: "keyUp", value: keyValue(keyPart) },
    ...[...modifiers].reverse().map((modifier) => ({ type: "keyUp", value: keyValue(modifier) })),
  ];
}

const jsString = (value: string): string => JSON.stringify(value);

type CraterNormalizedInputFile = {
  sourcePath: string;
  name: string;
  type: string;
  size: number;
};

function inputFileDisplayName(sourcePath: string): string {
  const parts = sourcePath.split(/[\\/]/);
  return parts[parts.length - 1] ?? sourcePath;
}

function inputFilePayloadSize(buffer: CraterSetInputFilePayload["buffer"]): number {
  if (typeof buffer === "string") {
    return Buffer.byteLength(buffer);
  }
  if (buffer instanceof ArrayBuffer) {
    return buffer.byteLength;
  }
  if (ArrayBuffer.isView(buffer)) {
    return buffer.byteLength;
  }
  return 0;
}

function normalizeInputFiles(files: CraterSetInputFilesValue): CraterNormalizedInputFile[] {
  const values = Array.isArray(files) ? files : [files];
  return values.map((file) => {
    if (typeof file === "string") {
      return {
        sourcePath: file,
        name: inputFileDisplayName(file),
        type: "",
        size: 0,
      };
    }
    const name = String(file.name);
    const type = String(file.mimeType ?? "");
    const size = inputFilePayloadSize(file.buffer);
    return {
      sourcePath: `payload:${name}:${type}:${size}`,
      name,
      type,
      size,
    };
  });
}

function isNetworkPageEvent(eventName: string): eventName is "request" | "response" | "requestfailed" {
  return eventName === "request" || eventName === "response" || eventName === "requestfailed";
}

function isFileChooserPageEvent(eventName: string): eventName is "filechooser" {
  return eventName === "filechooser";
}

function isDialogPageEvent(eventName: string): eventName is "dialog" {
  return eventName === "dialog";
}

function isDownloadPageEvent(eventName: string): eventName is "download" {
  return eventName === "download";
}

function isConsolePageEvent(eventName: string): eventName is "console" {
  return eventName === "console";
}

function pointerMoveActions(sharedId: string): Array<Record<string, unknown>> {
  return [
    {
      type: "pointerMove",
      origin: { type: "element", element: { sharedId } },
      x: 0,
      y: 0,
    },
  ];
}

function pointerClickActions(sharedId: string): Array<Record<string, unknown>> {
  return [
    ...pointerMoveActions(sharedId),
    { type: "pointerDown", button: 0 },
    { type: "pointerUp", button: 0 },
  ];
}

function adapterDomActionsExpr(): string {
  return `
    const __craterAction = (() => {
      const tagName = (element) => String(element?.tagName || element?.nodeName || "").toLowerCase();
      const attr = (target, name) => {
        let value = null;
        try {
          if (target && typeof target.getAttribute === "function") value = target.getAttribute(name);
        } catch (_e) {}
        if ((value === null || value === undefined) && target && target._attrs) value = target._attrs[name];
        return value == null ? "" : String(value);
      };
      const isContentEditable = (element) =>
        !!element?.isContentEditable ||
        String(element?.contentEditable || "").toLowerCase() === "true" ||
        String(element?.getAttribute?.("contenteditable") || "").toLowerCase() === "true";
      const focusElement = (element) => {
        if (typeof element.focus === "function") element.focus();
        globalThis.__bidiFocusedElement = element;
      };
      const makeKeyEvent = (type, key) => {
        const event = typeof KeyboardEvent === "function"
          ? new KeyboardEvent(type, { key, bubbles: true, cancelable: true })
          : new Event(type, { bubbles: true, cancelable: true });
        if (event.key !== key) Object.defineProperty(event, "key", { value: key });
        return event;
      };
      const makeInputEvent = (type, data) => {
        const init = {
          data,
          inputType: "insertText",
          bubbles: true,
          cancelable: type === "beforeinput",
        };
        const event = typeof InputEvent === "function"
          ? new InputEvent(type, init)
          : new Event(type, init);
        if (event.data !== data) Object.defineProperty(event, "data", { value: data });
        if (event.inputType !== "insertText") {
          Object.defineProperty(event, "inputType", { value: "insertText" });
        }
        return event;
      };
      const setEditableValue = (element, value) => {
        const tag = tagName(element);
        if (isContentEditable(element) && tag !== "input" && tag !== "textarea") {
          element.textContent = value;
        } else {
          element.value = value;
        }
      };
      const dispatchInputChange = (element) => {
        element.dispatchEvent(new Event("input", { bubbles: true }));
        element.dispatchEvent(new Event("change", { bubbles: true }));
      };
      const recordFileChooser = (element) => {
        if (tagName(element) !== "input") return;
        const inputType = String(element.type || attr(element, "type") || "").toLowerCase();
        if (inputType !== "file") return;
        let chooserId = attr(element, "data-crater-filechooser-id");
        if (!chooserId) {
          chooserId = "fc" + Math.random().toString(36).slice(2);
          if (typeof element.setAttribute === "function") {
            element.setAttribute("data-crater-filechooser-id", chooserId);
          } else {
            element.__craterFileChooserId = chooserId;
          }
        }
        if (!Array.isArray(globalThis.__craterFileChooserEvents)) {
          globalThis.__craterFileChooserEvents = [];
        }
        globalThis.__craterFileChooserEvents.push({
          selector: "[data-crater-filechooser-id=\\"" + chooserId + "\\"]",
          multiple: Boolean(element.multiple) ||
            (typeof element.hasAttribute === "function" && element.hasAttribute("multiple")) ||
            attr(element, "multiple") !== "",
        });
      };
      const clickElement = (element) => {
        recordFileChooser(element);
        // Pre-record anchor default-action navigation. The in-realm
        // shim click() would do this, but the element returned by
        // the Locator-path querySelectorAll is not always the same
        // object the runtime shim attached methods to, so the override
        // never fires. Recording here is a no-op when the shim does
        // run (same URL gets written twice). See issue 208.
        try {
          const tag = String(element.tagName || "").toUpperCase();
          if (tag === "A" || tag === "AREA") {
            const targetAttr = element._attrs && element._attrs.target;
            const targetGet = (typeof element.getAttribute === "function") ? element.getAttribute("target") : "";
            const target = String(targetAttr || targetGet || "").toLowerCase();
            if (!target || target === "_self") {
              const hrefProp = element.href;
              const hrefAttr = element._attrs && element._attrs.href;
              const href = hrefProp || hrefAttr || "";
              if (href) {
                globalThis.__craterPendingNavigation = {
                  url: String(href),
                  kind: "anchor",
                  urlOnly: true,
                };
              }
            }
          }
        } catch (_e) {}
        element.click();
      };
      const hoverElement = (element) => {
        element.dispatchEvent(new Event("pointerenter", { bubbles: false }));
        element.dispatchEvent(new Event("mouseover", { bubbles: true }));
      };
      const setChecked = (element, checked) => {
        if (element.checked === checked) return;
        const radioName = String(element.name || attr(element, "name") || "");
        if (checked && String(element.type || attr(element, "type") || "").toLowerCase() === "radio" && radioName) {
          const inputs = Array.from(document.querySelectorAll("input"));
          for (const input of inputs) {
            const inputName = String(input.name || attr(input, "name") || "");
            if (input !== element && String(input.type || attr(input, "type") || "").toLowerCase() === "radio" && inputName === radioName) {
              input.checked = false;
            }
          }
        }
        element.checked = checked;
        dispatchInputChange(element);
      };
      const selectOptions = (element, requestedValue) => {
        const options = Array.from(element.options || element.children || element._children || []).filter((option) => {
          return tagName(option) === "option";
        });
        const requested = Array.isArray(requestedValue) ? requestedValue : [requestedValue];
        const normalize = (text) => String(text || "").replace(/\\s+/g, " ").trim();
        const optionValue = (option) => String(option.value ?? option.getAttribute?.("value") ?? option.textContent ?? "");
        const optionLabel = (option) => normalize(option.label ?? option.textContent ?? "");
        const findOne = (entry) => {
          if (typeof entry === "string") {
            const byValue = options.findIndex((option) => optionValue(option) === entry);
            if (byValue >= 0) return byValue;
            return options.findIndex((option) => optionLabel(option) === entry);
          }
          if (!entry || typeof entry !== "object") return -1;
          if (entry.index !== undefined) {
            const index = Number(entry.index);
            return Number.isInteger(index) && index >= 0 && index < options.length ? index : -1;
          }
          if (entry.value !== undefined) {
            return options.findIndex((option) => optionValue(option) === String(entry.value));
          }
          if (entry.label !== undefined) {
            return options.findIndex((option) => optionLabel(option) === String(entry.label));
          }
          return -1;
        };
        const targetIndexes = requested.map(findOne);
        const missing = targetIndexes.findIndex((index) => index < 0);
        if (missing >= 0) throw new Error("Option not found: " + JSON.stringify(requested[missing]));
        const selectedIndexes = element.multiple ? new Set(targetIndexes) : new Set([targetIndexes[targetIndexes.length - 1]]);
        for (let i = 0; i < options.length; i += 1) {
          options[i].selected = selectedIndexes.has(i);
        }
        const selectedIndex = targetIndexes[targetIndexes.length - 1];
        element.selectedIndex = selectedIndex;
        element.value = selectedIndex >= 0 ? optionValue(options[selectedIndex]) : "";
        dispatchInputChange(element);
      };
      const replaceSelectedValue = (element, text) => {
        const value = typeof element.value === "string" ? element.value : "";
        let start = typeof element.selectionStart === "number" ? element.selectionStart : value.length;
        let end = typeof element.selectionEnd === "number" ? element.selectionEnd : value.length;
        start = Math.max(0, Math.min(value.length, Number(start)));
        end = Math.max(0, Math.min(value.length, Number(end)));
        if (end < start) {
          const tmp = start;
          start = end;
          end = tmp;
        }
        element.value = value.slice(0, start) + text + value.slice(end);
        const caret = start + text.length;
        try { element.selectionStart = caret; } catch (_e) {}
        try { element.selectionEnd = caret; } catch (_e) {}
        element.__bidiSelectionStart = caret;
        element.__bidiSelectionEnd = caret;
      };
      const insertText = (element, text, options = {}) => {
        const chunks = options.perCharacter ? Array.from(text) : [text];
        for (const chunk of chunks) {
          if (options.keyEvents) element.dispatchEvent(makeKeyEvent("keydown", chunk));
          if (element.dispatchEvent(makeInputEvent("beforeinput", chunk))) {
            if (typeof element.value === "string" && !options.textContentOnly) {
              replaceSelectedValue(element, chunk);
            } else {
              element.textContent = String(element.textContent || "") + chunk;
            }
            element.dispatchEvent(makeInputEvent("input", chunk));
          }
          if (options.keyEvents) element.dispatchEvent(makeKeyEvent("keyup", chunk));
        }
      };
      return {
        clickElement,
        dispatchInputChange,
        focusElement,
        hoverElement,
        insertText,
        isContentEditable,
        selectOptions,
        setEditableValue,
        setChecked,
        tagName,
      };
    })();
  `;
}

const normalizeLocatorText = (value: string): string => value.replace(/\s+/g, " ").trim();
const foldLocatorText = (value: string): string => normalizeLocatorText(value).toLowerCase();

type CssSelectorBranch = {
  selector: string;
  hasText: string[];
};

function splitSelectorList(selector: string): string[] {
  const parts: string[] = [];
  let start = 0;
  let quote: string | null = null;
  let bracketDepth = 0;
  let parenDepth = 0;
  for (let i = 0; i < selector.length; i += 1) {
    const char = selector[i];
    if (quote) {
      if (char === "\\") {
        i += 1;
      } else if (char === quote) {
        quote = null;
      }
      continue;
    }
    if (char === "'" || char === "\"") {
      quote = char;
      continue;
    }
    if (char === "[") {
      bracketDepth += 1;
      continue;
    }
    if (char === "]") {
      bracketDepth = Math.max(0, bracketDepth - 1);
      continue;
    }
    if (bracketDepth > 0) {
      continue;
    }
    if (char === "(") {
      parenDepth += 1;
      continue;
    }
    if (char === ")") {
      parenDepth = Math.max(0, parenDepth - 1);
      continue;
    }
    if (char === "," && parenDepth === 0) {
      const part = selector.slice(start, i).trim();
      if (part !== "") {
        parts.push(part);
      }
      start = i + 1;
    }
  }
  const tail = selector.slice(start).trim();
  if (tail !== "") {
    parts.push(tail);
  }
  return parts.length > 0 ? parts : [selector];
}

function readFunctionArgument(source: string, start: number): { value: string; end: number } | null {
  let quote: string | null = null;
  let depth = 1;
  for (let i = start; i < source.length; i += 1) {
    const char = source[i];
    if (quote) {
      if (char === "\\") {
        i += 1;
      } else if (char === quote) {
        quote = null;
      }
      continue;
    }
    if (char === "'" || char === "\"") {
      quote = char;
      continue;
    }
    if (char === "(") {
      depth += 1;
      continue;
    }
    if (char === ")") {
      depth -= 1;
      if (depth === 0) {
        return { value: source.slice(start, i), end: i };
      }
    }
  }
  return null;
}

function unescapeCssString(value: string): string {
  let result = "";
  for (let i = 0; i < value.length; i += 1) {
    const char = value[i];
    if (char !== "\\") {
      result += char;
      continue;
    }
    const next = value[i + 1];
    if (next === undefined) {
      result += char;
      continue;
    }
    result += next;
    i += 1;
  }
  return result;
}

function parsePlaywrightTextArgument(value: string): string {
  const trimmed = value.trim();
  const quote = trimmed[0];
  if ((quote === "'" || quote === "\"") && trimmed[trimmed.length - 1] === quote) {
    return unescapeCssString(trimmed.slice(1, -1));
  }
  return trimmed;
}

function stripHasTextPseudo(selector: string): CssSelectorBranch {
  const pseudo = ":has-text(";
  const hasText: string[] = [];
  let css = "";
  let quote: string | null = null;
  let bracketDepth = 0;
  for (let i = 0; i < selector.length; i += 1) {
    const char = selector[i];
    if (quote) {
      css += char;
      if (char === "\\") {
        i += 1;
        if (i < selector.length) {
          css += selector[i];
        }
      } else if (char === quote) {
        quote = null;
      }
      continue;
    }
    if (char === "'" || char === "\"") {
      quote = char;
      css += char;
      continue;
    }
    if (char === "[") {
      bracketDepth += 1;
      css += char;
      continue;
    }
    if (char === "]") {
      bracketDepth = Math.max(0, bracketDepth - 1);
      css += char;
      continue;
    }
    if (bracketDepth === 0 && selector.slice(i, i + pseudo.length).toLowerCase() === pseudo) {
      const argument = readFunctionArgument(selector, i + pseudo.length);
      if (!argument) {
        css += char;
        continue;
      }
      hasText.push(parsePlaywrightTextArgument(argument.value));
      i = argument.end;
      continue;
    }
    css += char;
  }
  return { selector: css.trim() || "*", hasText };
}

function parsePlaywrightCssSelector(selector: string): CssSelectorBranch[] | null {
  const branches = splitSelectorList(selector).map(stripHasTextPseudo);
  return branches.some((branch) => branch.hasText.length > 0) ? branches : null;
}

function locatorSelector(
  type: string,
  value: CraterTextMatcher,
  options: CraterTextMatchOptions = {},
): string {
  if (value instanceof RegExp) {
    return `${type}=regex:${value.flags}:${value.source}`;
  }
  return `${type}=${options.exact ? "exact:" : ""}${String(value)}`;
}

const jsValue = (value: unknown): string => {
  const serialized = JSON.stringify(value);
  return serialized === undefined ? "undefined" : serialized;
};

const CRATER_SUPPORTED_PERMISSIONS = new Set(["geolocation", "storage-access"]);

const stripLeadingDot = (value: string): string => value.replace(/^\.+/, "");

function storageSameSite(value: CraterStorageCookie["sameSite"] | string | undefined): string {
  const normalized = String(value ?? "Lax").toLowerCase();
  if (normalized === "none" || normalized === "strict") {
    return normalized;
  }
  return "lax";
}

function playwrightSameSite(value: string | undefined): CraterStorageCookie["sameSite"] {
  const normalized = String(value ?? "lax").toLowerCase();
  if (normalized === "none") return "None";
  if (normalized === "strict") return "Strict";
  return "Lax";
}

function storageCookieValue(value: unknown): string {
  if (value && typeof value === "object" && "value" in value) {
    const payload = value as CraterStorageCookieValue;
    return String(payload.value ?? "");
  }
  return String(value ?? "");
}

const deserializeBidiValue = (remoteValue: unknown): unknown => {
  if (!remoteValue || typeof remoteValue !== "object") {
    return remoteValue;
  }
  const record = remoteValue as Record<string, unknown>;
  const type = record.type;
  if (typeof type !== "string") {
    return Object.fromEntries(
      Object.entries(record).map(([key, value]) => [key, deserializeBidiValue(value)]),
    );
  }

  switch (type) {
    case "undefined":
      return undefined;
    case "null":
      return null;
    case "string":
    case "boolean":
    case "bigint":
      return record.value;
    case "number": {
      if (record.value === "NaN") return Number.NaN;
      if (record.value === "-0") return -0;
      if (record.value === "Infinity") return Infinity;
      if (record.value === "-Infinity") return -Infinity;
      return record.value;
    }
    case "array":
      return Array.isArray(record.value)
        ? record.value.map(deserializeBidiValue)
        : [];
    case "object": {
      if (!Array.isArray(record.value)) {
        return {};
      }
      const out: Record<string, unknown> = {};
      for (const entry of record.value) {
        if (Array.isArray(entry) && entry.length >= 2) {
          out[String(deserializeBidiValue(entry[0]))] = deserializeBidiValue(entry[1]);
        } else if (entry && typeof entry === "object") {
          const pair = entry as Record<string, unknown>;
          if ("key" in pair && "value" in pair) {
            out[String(deserializeBidiValue(pair.key))] = deserializeBidiValue(pair.value);
          }
        }
      }
      return out;
    }
    default:
      return "value" in record ? deserializeBidiValue(record.value) : remoteValue;
  }
};

const domKeyValue = (key: string): string => key === "Space" ? " " : key;

function isEvaluateOptions(value: unknown): value is CraterEvaluateOptions {
  return !!value && typeof value === "object" && "awaitPromise" in value;
}

function isWaitForFunctionOptions(value: unknown): value is CraterWaitForFunctionOptions {
  return !!value && typeof value === "object" &&
    ("timeout" in value || "polling" in value);
}

function summarizeBidiExpression(expression: unknown, limit = 180): string {
  if (typeof expression !== "string") {
    return "";
  }
  const normalized = expression.replace(/\s+/g, " ").trim();
  if (normalized.length <= limit) {
    return normalized;
  }
  return `${normalized.slice(0, limit - 3)}...`;
}

function bidiCommandTimeoutLabel(method: string, params: unknown): string {
  if (!params || typeof params !== "object") {
    return method;
  }
  const record = params as Record<string, unknown>;
  if (method === "script.evaluate" && "expression" in record) {
    const summary = summarizeBidiExpression(record.expression);
    return summary ? `${method}: ${summary}` : method;
  }
  return method;
}

function bidiCommandContext(method: string, params: unknown): string | null {
  if (!params || typeof params !== "object") {
    return null;
  }
  const record = params as Record<string, unknown>;
  if (typeof record.context === "string") {
    return record.context;
  }
  if (method === "script.evaluate") {
    const target = record.target;
    if (target && typeof target === "object") {
      const context = (target as Record<string, unknown>).context;
      return typeof context === "string" ? context : null;
    }
  }
  const partition = record.partition;
  if (partition && typeof partition === "object") {
    const context = (partition as Record<string, unknown>).context;
    return typeof context === "string" ? context : null;
  }
  return null;
}

function isAwaitedScriptEvaluate(method: string, params: unknown): boolean {
  return method === "script.evaluate" &&
    !!params &&
    typeof params === "object" &&
    (params as Record<string, unknown>).awaitPromise === true;
}

export function parseLocatorSelector(selector: string): ParsedLocatorSelector {
  const prefixMatch = selector.match(/^(text|role|placeholder|alt|title|testid|label)=([\s\S]+)$/i);
  if (prefixMatch) {
    const [, type, value] = prefixMatch;
    const exactMatch = value.match(/^exact:([\s\S]+)$/i);
    if (exactMatch) {
      return { type: type.toLowerCase(), value: exactMatch[1], exact: true };
    }
    const regexpMatch = value.match(/^regex:([a-z]*):([\s\S]*)$/i);
    if (regexpMatch) {
      return {
        type: type.toLowerCase(),
        value: regexpMatch[2],
        regexp: true,
        flags: regexpMatch[1],
      };
    }
    return { type: type.toLowerCase(), value };
  }
  return { type: "css", value: selector };
}

function composedTreeHelpersExpr(): string {
  return `
    const attrOf = (target, name) => {
      let value = null;
      try {
        if (target && typeof target.getAttribute === "function") value = target.getAttribute(name);
      } catch (_e) {}
      if ((value === null || value === undefined) && target && target._attrs) value = target._attrs[name];
      return value == null ? "" : String(value);
    };
    const childrenOf = (node) =>
      Array.from((node && (node._children || node.children || node.childNodes)) || [])
        .filter((child) => !(child && child._isShadowRoot));
    const openShadowRootOf = (node) => {
      if (!node) return null;
      let shadowRoot = null;
      try {
        shadowRoot = node.shadowRoot || null;
      } catch (_e) {}
      if (!shadowRoot && node._shadowRoot) {
        const mode = String(node._shadowRoot.mode || "open").toLowerCase();
        if (mode !== "closed") shadowRoot = node._shadowRoot;
      }
      return shadowRoot;
    };
    const isClosedShadowRoot = (node) =>
      !!(node && node._isShadowRoot && String(node.mode || "open").toLowerCase() === "closed");
    const isInsideClosedShadow = (node) => {
      let current = node;
      while (current) {
        if (isClosedShadowRoot(current)) return true;
        current = current._parent || current.parentNode || null;
      }
      return false;
    };
    const collectElements = (root, includeRoot = true) => {
      const all = [];
      const walk = (node, includeCurrent) => {
        if (!node) return;
        if (isClosedShadowRoot(node)) return;
        if (node.nodeType === 1) {
          if (isInsideClosedShadow(node)) return;
          if (includeCurrent) all.push(node);
          const shadowRoot = openShadowRootOf(node);
          if (shadowRoot) walk(shadowRoot, false);
        }
        for (const child of childrenOf(node)) walk(child, true);
      };
      if (!root) return all;
      if (root.nodeType === 9) {
        walk(root.documentElement || root.body, true);
      } else if (root.nodeType === 11 || root._isShadowRoot) {
        for (const child of childrenOf(root)) walk(child, true);
      } else {
        walk(root, includeRoot);
      }
      return all;
    };
    const textForLocator = (node) => {
      const read = (current) => {
        if (!current) return "";
        if (current.nodeType === 3 || current.nodeType === 4) {
          return String(current.textContent || "");
        }
        if (current.nodeType !== 1 && current.nodeType !== 11 && !current._isShadowRoot) {
          return "";
        }
        return childrenOf(current).map(read).join("");
      };
      return read(node);
    };
  `;
}

function allElementsExpr(rootExpr: string, options: { includeRoot?: boolean } = {}): string {
  const includeRoot = options.includeRoot !== false ? "true" : "false";
  return `(() => {
    ${composedTreeHelpersExpr()}
    return collectElements(${rootExpr}, ${includeRoot});
  })()`;
}

function selectorResultExpr(all: string, method: "first" | "all"): string {
  return method === "first" ? `(${all})[0] || null` : all;
}

function composedElementsFilterExpr(
  rootExpr: string,
  predicate: string,
  method: "first" | "all",
  options: { includeRoot?: boolean } = {},
): string {
  const includeRoot = options.includeRoot !== false ? "true" : "false";
  const all = `(() => {
    ${composedTreeHelpersExpr()}
    return collectElements(${rootExpr}, ${includeRoot}).filter(${predicate});
  })()`;
  return selectorResultExpr(all, method);
}

function attrSelectorExpr(
  rootExpr: string,
  name: string,
  parsed: ParsedLocatorSelector,
  method: "first" | "all",
  options: { forceExact?: boolean } = {},
): string {
  const normalized = jsString(normalizeLocatorText(parsed.value));
  const folded = jsString(foldLocatorText(parsed.value));
  const flags = (parsed.flags ?? "").replace(/g/g, "");
  const predicate = parsed.regexp
    ? `(el) => {
        const attr = String(attrOf(el, ${jsString(name)}) || "").replace(/\\s+/g, " ").trim();
        return new RegExp(${jsString(parsed.value)}, ${jsString(flags)}).test(attr);
      }`
    : parsed.exact || options.forceExact
    ? `(el) => String(attrOf(el, ${jsString(name)}) || "").replace(/\\s+/g, " ").trim() === ${normalized}`
    : `(el) => {
        const attr = String(attrOf(el, ${jsString(name)}) || "").replace(/\\s+/g, " ").trim().toLowerCase();
        return attr.includes(${folded});
      }`;
  return composedElementsFilterExpr(rootExpr, predicate, method);
}

function cssSelectorExpr(rootExpr: string, selector: string, method: "first" | "all"): string {
  const playwrightBranches = parsePlaywrightCssSelector(selector);
  if (playwrightBranches) {
    const branchPredicates = playwrightBranches.map((branch) => {
      const quotedSelector = jsString(branch.selector);
      const textPredicates = branch.hasText.map((value) =>
        `normalize(textForLocator(el)).toLowerCase().includes(${jsString(foldLocatorText(value))})`
      );
      const textPredicate = textPredicates.length > 0 ? textPredicates.join(" && ") : "true";
      return `(() => {
        try {
          if (!(typeof el.matches === "function" && el.matches(${quotedSelector}))) return false;
        } catch (_e) {
          return false;
        }
        return ${textPredicate};
      })()`;
    });
    return composedElementsFilterExpr(rootExpr, `(el) => {
      const normalize = (text) => String(text || "").replace(/\\s+/g, " ").trim();
      return ${branchPredicates.join(" || ")};
    }`, method, { includeRoot: false });
  }
  const quoted = jsString(selector);
  return composedElementsFilterExpr(rootExpr, `(el) => {
    try {
      return typeof el.matches === "function" && el.matches(${quoted});
    } catch (_e) {
      return false;
    }
  }`, method, { includeRoot: false });
}

function textSelectorExpr(
  rootExpr: string,
  parsed: ParsedLocatorSelector,
  method: "first" | "all",
): string {
  const normalizedQuoted = jsString(normalizeLocatorText(parsed.value));
  const foldedQuoted = jsString(foldLocatorText(parsed.value));
  const flags = (parsed.flags ?? "").replace(/g/g, "");
  const predicate = parsed.regexp
    ? `(el) => {
        const normalize = (text) => String(text || "").replace(/\\s+/g, " ").trim();
        const matches = (node) => new RegExp(${jsString(parsed.value)}, ${jsString(flags)}).test(normalize(textForLocator(node)));
        if (!matches(el)) return false;
        const children = Array.from(el._children || el.children || el.childNodes || []);
        return !children.some((node) => node.nodeType === 1 && matches(node));
      }`
    : parsed.exact
    ? `(el) => {
        const normalize = (text) => String(text || "").replace(/\\s+/g, " ").trim();
        const matches = (node) => normalize(textForLocator(node)) === ${normalizedQuoted};
        if (!matches(el)) return false;
        const children = Array.from(el._children || el.children || el.childNodes || []);
        return !children.some((node) => node.nodeType === 1 && matches(node));
      }`
    : `(el) => {
        const normalize = (text) => String(text || "").replace(/\\s+/g, " ").trim();
        const matches = (node) => normalize(textForLocator(node)).toLowerCase().includes(${foldedQuoted});
        if (!matches(el)) return false;
        const children = Array.from(el._children || el.children || el.childNodes || []);
        return !children.some((node) => node.nodeType === 1 && matches(node));
      }`;
  return composedElementsFilterExpr(rootExpr, predicate, method);
}

function roleSelectorExpr(rootExpr: string, role: string, method: "first" | "all"): string {
  const quoted = jsString(role);
  return composedElementsFilterExpr(rootExpr, `(el) => {
    const explicitRole = attrOf(el, "role").trim();
    if (explicitRole !== "") return explicitRole === ${quoted};
    const tag = String(el.localName || el.tagName || el.nodeName || "").toLowerCase();
    if (/^h[1-6]$/.test(tag)) return ${quoted} === "heading";
    if (tag === "button") return ${quoted} === "button";
    if (tag === "a" && attrOf(el, "href") !== "") return ${quoted} === "link";
    if (tag === "textarea") return ${quoted} === "textbox";
    if (tag === "select") return ${quoted} === "combobox";
    if (tag === "img") return ${quoted} === "img";
    if (tag === "ul" || tag === "ol") return ${quoted} === "list";
    if (tag === "li") return ${quoted} === "listitem";
    if (tag === "input") {
      const type = attrOf(el, "type").trim().toLowerCase() || "text";
      if (type === "hidden") return false;
      if (type === "button" || type === "submit" || type === "reset") return ${quoted} === "button";
      if (type === "checkbox") return ${quoted} === "checkbox";
      if (type === "radio") return ${quoted} === "radio";
      if (type === "search") return ${quoted} === "searchbox";
      if (type === "range") return ${quoted} === "slider";
      if (type === "number") return ${quoted} === "spinbutton";
      return ${quoted} === "textbox";
    }
    return false;
  }`, method);
}

function labelSelectorExpr(
  rootExpr: string,
  parsed: ParsedLocatorSelector,
  method: "first" | "all",
): string {
  const normalizedQuoted = jsString(normalizeLocatorText(parsed.value));
  const foldedQuoted = jsString(foldLocatorText(parsed.value));
  const flags = (parsed.flags ?? "").replace(/g/g, "");
  const matchExpr = parsed.regexp
    ? `(text) => new RegExp(${jsString(parsed.value)}, ${jsString(flags)}).test(normalize(text))`
    : parsed.exact
    ? `(text) => normalize(text) === ${normalizedQuoted}`
    : `(text) => normalize(text).toLowerCase().includes(${foldedQuoted})`;
  const all = `(() => {
    ${composedTreeHelpersExpr()}
    const normalize = (text) => String(text || "").replace(/\\s+/g, " ").trim();
    const textMatches = ${matchExpr};
    const rootOf = (node) => {
      try {
        if (node && typeof node.getRootNode === "function") return node.getRootNode();
      } catch (_e) {}
      let current = node;
      while (current && current._parent) current = current._parent;
      return current || document;
    };
    const findById = (scope, id) => {
      if (!scope || !id) return null;
      try {
        if (typeof scope.getElementById === "function") {
          const found = scope.getElementById(id);
          if (found) return found;
        }
      } catch (_e) {}
      return collectElements(scope, false).find((el) => attrOf(el, "id") === id) || null;
    };
    const isLabelable = (el) => {
      const tag = String(el.localName || el.tagName || el.nodeName || "").toLowerCase();
      if (tag === "input") return attrOf(el, "type").trim().toLowerCase() !== "hidden";
      return tag === "button" || tag === "meter" || tag === "output" || tag === "progress" ||
        tag === "select" || tag === "textarea";
    };
    const findControl = (label) => collectElements(label, false).find(isLabelable) || null;
    const candidates = collectElements(${rootExpr}, true);
    const labels = candidates
      .filter((el) => String(el.tagName || el.nodeName || "").toLowerCase() === "label");
    const results = [];
    const seen = new Set();
    const add = (el) => {
      if (!el || seen.has(el)) return;
      seen.add(el);
      results.push(el);
    };
    for (const label of labels) {
      if (!textMatches(textForLocator(label))) continue;
      const forId = attrOf(label, "for");
      add(forId ? findById(rootOf(label), forId) : findControl(label));
    }
    for (const el of candidates) {
      if (!isLabelable(el)) continue;
      const ariaLabelledBy = attrOf(el, "aria-labelledby").trim();
      if (ariaLabelledBy !== "") {
        const parts = [];
        for (const id of ariaLabelledBy.split(/\\s+/)) {
          const ref = findById(rootOf(el), id);
          if (ref) parts.push(textForLocator(ref));
        }
        if (parts.length > 0 && textMatches(parts.join(" "))) add(el);
      }
      const ariaLabel = attrOf(el, "aria-label").trim();
      if (ariaLabel !== "" && textMatches(ariaLabel)) add(el);
    }
    return results;
  })()`;
  return selectorResultExpr(all, method);
}

function buildSelectorExpr(
  parsed: ParsedLocatorSelector,
  method: "first" | "all",
  rootExpr = "document",
): string {
  switch (parsed.type) {
    case "text":
      return textSelectorExpr(rootExpr, parsed, method);
    case "role":
      return roleSelectorExpr(rootExpr, parsed.value, method);
    case "placeholder":
      return attrSelectorExpr(rootExpr, "placeholder", parsed, method);
    case "alt":
      return attrSelectorExpr(rootExpr, "alt", parsed, method);
    case "title":
      return attrSelectorExpr(rootExpr, "title", parsed, method);
    case "testid":
      return attrSelectorExpr(rootExpr, "data-testid", parsed, method, { forceExact: true });
    case "label":
      return labelSelectorExpr(rootExpr, parsed, method);
    case "css":
    default:
      return cssSelectorExpr(rootExpr, parsed.value, method);
  }
}

function normalizeLocatorFilter(
  kind: LocatorFilter["kind"],
  value: string | RegExp,
  options: { exact?: boolean } = {},
): LocatorFilter {
  if (value instanceof RegExp) {
    return { kind, value: value.source, flags: value.flags, regexp: true };
  }
  return { kind, value: String(value), regexp: false, exact: options.exact };
}

function normalizeBooleanLocatorFilter(kind: "visible" | "disabled", value: boolean): LocatorFilter {
  return { kind, value: value ? "true" : "false", regexp: false };
}

function roleOptionFilters(options: CraterGetByRoleOptions): LocatorFilter[] {
  const filters: LocatorFilter[] = [];
  if (!options.includeHidden) {
    filters.push(normalizeBooleanLocatorFilter("visible", true));
  }
  if (options.disabled !== undefined) {
    filters.push(normalizeBooleanLocatorFilter("disabled", options.disabled));
  }
  if (options.name !== undefined) {
    filters.push(normalizeLocatorFilter("hasAccessibleName", options.name, {
      exact: options.exact,
    }));
  }
  return filters;
}

function accessibleNameExpr(nodeExpr: string): string {
  return `(() => {
    const node = ${nodeExpr};
    if (!node) return "";
    const attr = (target, name) => {
      let value = null;
      try {
        if (target && typeof target.getAttribute === "function") value = target.getAttribute(name);
      } catch (_e) {}
      if ((value === null || value === undefined) && target && target._attrs) value = target._attrs[name];
      return value == null ? "" : String(value);
    };
    const normalize = (text) => String(text ?? "").replace(/\\s+/g, " ").trim();
    const findById = (doc, id) => {
      if (!doc || !id) return null;
      let found = null;
      try {
        if (typeof doc.getElementById === "function") found = doc.getElementById(id);
      } catch (_e) {}
      if (found) return found;
      const stack = [doc.documentElement || doc.body || doc];
      while (stack.length > 0) {
        const current = stack.pop();
        if (!current) continue;
        if (current.nodeType === 1 && attr(current, "id") === id) return current;
        const children = Array.from(current._children || current.children || current.childNodes || []);
        for (let i = children.length - 1; i >= 0; i--) stack.push(children[i]);
      }
      return null;
    };
    const labelledBy = attr(node, "aria-labelledby").trim();
    if (labelledBy !== "") {
      const doc = node.ownerDocument || globalThis.document;
      const parts = [];
      for (const id of labelledBy.split(/\\s+/)) {
        if (!id) continue;
        const ref = findById(doc, id);
        if (ref) {
          const text = normalize((ref.innerText !== undefined && ref.innerText !== null && String(ref.innerText) !== "") ? ref.innerText : (ref.textContent || ""));
          if (text !== "") parts.push(text);
        }
      }
      if (parts.length > 0) return parts.join(" ").trim();
    }
    const ariaLabel = attr(node, "aria-label").trim();
    if (ariaLabel !== "") return ariaLabel;
    const tag = String(node.localName || node.tagName || node.nodeName || "").toLowerCase();
    if (tag === "img") {
      const alt = attr(node, "alt").trim();
      if (alt !== "") return alt;
    }
    const textFrom = (target) => normalize((target && target.innerText !== undefined && target.innerText !== null && String(target.innerText) !== "") ? target.innerText : ((target && target.textContent) || ""));
    const labelsFor = (target) => {
      const doc = target.ownerDocument || globalThis.document;
      const id = attr(target, "id").trim();
      const labels = [];
      if (doc) {
        try {
          if (typeof doc.querySelectorAll === "function") {
            labels.push(...Array.from(doc.querySelectorAll("label")));
          }
        } catch (_e) {}
        if (labels.length === 0) {
          const stack = [doc.documentElement || doc.body || doc];
          while (stack.length > 0) {
            const current = stack.pop();
            if (!current) continue;
            const currentTag = String(current.localName || current.tagName || current.nodeName || "").toLowerCase();
            if (current.nodeType === 1 && currentTag === "label") labels.push(current);
            const children = Array.from(current._children || current.children || current.childNodes || []);
            for (let i = children.length - 1; i >= 0; i--) stack.push(children[i]);
          }
        }
      }
      const parts = [];
      if (id !== "") {
        for (const label of labels) {
          if (attr(label, "for") === id) {
            const text = textFrom(label);
            if (text !== "") parts.push(text);
          }
        }
      }
      let parent = target._parent || target.parentElement || target.parentNode || null;
      while (parent) {
        const parentTag = String(parent.localName || parent.tagName || parent.nodeName || "").toLowerCase();
        if (parent.nodeType === 1 && parentTag === "label") {
          const text = textFrom(parent);
          if (text !== "") parts.push(text);
          break;
        }
        parent = parent._parent || parent.parentElement || parent.parentNode || null;
      }
      return parts.join(" ").trim();
    };
    if (tag === "input" || tag === "textarea" || tag === "select") {
      const label = labelsFor(node);
      if (label !== "") return label;
      if (tag === "input") {
        const type = attr(node, "type").trim().toLowerCase();
        if (type === "button" || type === "submit" || type === "reset") {
          const value = attr(node, "value").trim();
          if (value !== "") return value;
        }
      }
    }
    return normalize((node.innerText !== undefined && node.innerText !== null && String(node.innerText) !== "") ? node.innerText : (node.textContent || ""));
  })()`;
}

function elementVisibleExpr(nodeExpr: string): string {
  return `(() => {
    const target = ${nodeExpr};
    if (!target) return false;
    const styleOf = (node) => window.getComputedStyle ? window.getComputedStyle(node) : node.style;
    const ownStyle = styleOf(target) || {};
    if (ownStyle.visibility === "hidden" || ownStyle.visibility === "collapse") return false;
    let node = target;
    while (node && node.nodeType === 1) {
      const style = styleOf(node) || {};
      if (node.hidden || style.display === "none") return false;
      node = node.parentElement || node.parentNode || node._parent || null;
    }
    return true;
  })()`;
}

function elementDisabledExpr(nodeExpr: string): string {
  return `(() => {
    const target = ${nodeExpr};
    if (!target) return false;
    const attr = (target, name) => {
      let value = null;
      try {
        if (target && typeof target.getAttribute === "function") value = target.getAttribute(name);
      } catch (_e) {}
      if ((value === null || value === undefined) && target && target._attrs) value = target._attrs[name];
      return value == null ? "" : String(value);
    };
    if (typeof target.disabled === "boolean") return target.disabled;
    if (typeof target.hasAttribute === "function" && target.hasAttribute("disabled")) return true;
    return attr(target, "aria-disabled").trim().toLowerCase() === "true";
  })()`;
}

function filterPredicateExpr(filter: LocatorFilter): string {
  if (filter.kind === "visible") {
    const visible = elementVisibleExpr("el");
    return filter.value === "true" ? visible : `!(${visible})`;
  }
  if (filter.kind === "disabled") {
    const disabled = elementDisabledExpr("el");
    return filter.value === "true" ? disabled : `!(${disabled})`;
  }
  const textExpr = filter.kind === "hasAccessibleName"
    ? accessibleNameExpr("el")
    : `String(el.textContent || "").replace(/\\s+/g, " ").trim()`;
  const normalizedTextExpr = `String(${textExpr} ?? "").replace(/\\s+/g, " ").trim()`;
  const testExpr = filter.regexp
    ? `new RegExp(${jsString(filter.value)}, ${jsString(filter.flags ?? "")}).test(${normalizedTextExpr})`
    : filter.exact
    ? `${normalizedTextExpr}.toLowerCase() === ${jsString(foldLocatorText(filter.value))}`
    : `${normalizedTextExpr}.toLowerCase().includes(${jsString(foldLocatorText(filter.value))})`;
  return filter.kind === "hasNotText" ? `!(${testExpr})` : testExpr;
}

export class CraterRequest {
  constructor(private readonly data: CraterNetworkRequestPayload) {}

  url(): string {
    return this.data.url;
  }

  method(): string {
    return this.data.method;
  }

  headers(): Record<string, string> {
    return { ...this.data.headers };
  }

  postData(): string | null {
    return this.data.postData ?? null;
  }

  payload(): CraterNetworkRequestPayload {
    return this.data;
  }
}

export class CraterResponse {
  private readonly requestValue: CraterRequest;

  constructor(private readonly data: CraterNetworkResponsePayload) {
    this.requestValue = new CraterRequest(data.request);
  }

  url(): string {
    return this.data.url;
  }

  status(): number {
    return this.data.status;
  }

  statusText(): string {
    return this.data.statusText ?? "";
  }

  ok(): boolean {
    return this.status() >= 200 && this.status() <= 299;
  }

  headers(): Record<string, string> {
    return { ...this.data.headers };
  }

  request(): CraterRequest {
    return this.requestValue;
  }

  async text(): Promise<string> {
    return this.data.body ?? "";
  }
}

export class CraterFileChooser {
  constructor(
    private readonly pageValue: CraterBidiPage,
    private readonly selector: string,
    private readonly multipleValue: boolean,
  ) {}

  page(): CraterBidiPage {
    return this.pageValue;
  }

  isMultiple(): boolean {
    return this.multipleValue;
  }

  async setFiles(files: CraterSetInputFilesValue): Promise<void> {
    await this.pageValue.setInputFiles(this.selector, files);
  }
}

export class CraterDialog {
  private handled = false;

  constructor(
    private readonly pageValue: CraterBidiPage,
    private readonly data: CraterDialogEventPayload,
    private readonly handlePrompt: (
      context: string,
      accept: boolean,
      promptText?: string,
    ) => Promise<void>,
  ) {}

  page(): CraterBidiPage {
    return this.pageValue;
  }

  type(): CraterDialogType {
    return this.data.type;
  }

  message(): string {
    return this.data.message;
  }

  defaultValue(): string {
    return this.data.defaultValue ?? "";
  }

  async accept(promptText?: string): Promise<void> {
    await this.handle(true, promptText);
  }

  async dismiss(): Promise<void> {
    await this.handle(false);
  }

  private async handle(accept: boolean, promptText?: string): Promise<void> {
    if (this.handled) {
      throw new Error("Dialog has already been handled");
    }
    this.handled = true;
    await this.handlePrompt(this.data.context, accept, promptText);
  }
}

export class CraterDownload {
  constructor(
    private readonly pageValue: CraterBidiPage,
    private readonly start: CraterDownloadWillBeginPayload,
    private readonly endPromise: Promise<CraterDownloadEndPayload>,
  ) {}

  page(): CraterBidiPage {
    return this.pageValue;
  }

  url(): string {
    return this.start.url;
  }

  suggestedFilename(): string {
    return this.start.suggestedFilename;
  }

  async path(): Promise<string | null> {
    const end = await this.endPromise;
    return end.status === "complete" ? end.filepath : null;
  }

  async saveAs(path: string): Promise<void> {
    const sourcePath = await this.path();
    if (!sourcePath) {
      throw new Error(`Cannot save failed download: ${await this.failure() ?? "unknown"}`);
    }
    await mkdir(dirname(path), { recursive: true });
    await copyFile(sourcePath, path);
  }

  async failure(): Promise<string | null> {
    const end = await this.endPromise;
    return end.status === "complete" ? null : end.status;
  }

  async cancel(): Promise<void> {
    await this.endPromise;
  }

  async delete(): Promise<void> {
    const sourcePath = await this.path();
    if (!sourcePath) {
      return;
    }
    try {
      await unlink(sourcePath);
    } catch (error) {
      if (
        !error ||
        typeof error !== "object" ||
        !("code" in error) ||
        (error as { code?: string }).code !== "ENOENT"
      ) {
        throw error;
      }
    }
  }
}

export class CraterConsoleMessage {
  constructor(
    private readonly pageValue: CraterBidiPage,
    private readonly data: CraterConsoleEventPayload,
  ) {}

  page(): CraterBidiPage {
    return this.pageValue;
  }

  type(): string {
    return this.data.type;
  }

  text(): string {
    return this.data.text;
  }

  args(): string[] {
    return [...this.data.args];
  }
}

export class CraterRequestFailure {
  private readonly requestValue: CraterRequest;

  constructor(private readonly data: {
    request: CraterNetworkRequestPayload;
    errorText: string;
  }) {
    this.requestValue = new CraterRequest(data.request);
  }

  request(): CraterRequest {
    return this.requestValue;
  }

  errorText(): string {
    return this.data.errorText;
  }
}

export class CraterRoute {
  private handledValue = false;

  constructor(
    private readonly requestValue: CraterRequest,
    private readonly resolveDecision: (decision: CraterRouteDecision) => Promise<void>,
  ) {}

  request(): CraterRequest {
    return this.requestValue;
  }

  handled(): boolean {
    return this.handledValue;
  }

  async fulfill(options: CraterRouteFulfillOptions = {}): Promise<void> {
    const headers = { ...(options.headers ?? {}) };
    if (options.contentType && !headers["content-type"]) {
      headers["content-type"] = options.contentType;
    }
    await this.resolveOnce({
      action: "fulfill",
      status: options.status ?? 200,
      headers,
      body: routeBodyToString(options.body),
    });
  }

  async continue(options: CraterRouteContinueOptions = {}): Promise<void> {
    await this.resolveOnce({
      action: "continue",
      ...options,
    });
  }

  async abort(errorCode = "failed"): Promise<void> {
    await this.resolveOnce({ action: "abort", errorCode });
  }

  private async resolveOnce(decision: CraterRouteDecision): Promise<void> {
    if (this.handledValue) {
      throw new Error("Route is already handled");
    }
    this.handledValue = true;
    await this.resolveDecision(decision);
  }
}

function routeBodyToString(body: CraterRouteFulfillOptions["body"]): string {
  if (body === undefined || body === null) {
    return "";
  }
  if (typeof body === "string") {
    return body;
  }
  if (Buffer.isBuffer(body)) {
    return body.toString();
  }
  if (body instanceof Uint8Array) {
    return Buffer.from(body).toString();
  }
  return JSON.stringify(body);
}

async function markLiveDomCaptureNeeded(page: CraterBidiPage): Promise<void> {
  await page.evaluate(paintCaptureSourceExpression("live"));
}

function paintCaptureSourceExpression(source: "live" | "original"): string {
  return `(() => {
    globalThis.__craterPaintCaptureSource = ${jsString(source)};
    if (globalThis.window && typeof globalThis.window === "object") {
      globalThis.window.__craterPaintCaptureSource = ${jsString(source)};
    }
  })()`;
}

class CraterKeyboard {
  constructor(
    private readonly performActions: (actions: Array<Record<string, string>>) => Promise<void>,
    private readonly insertFocusedText: (text: string) => Promise<void>,
  ) {}

  async type(text: string): Promise<void> {
    for (const char of [...text]) {
      await this.press(char);
    }
  }

  async press(key: string): Promise<void> {
    await this.performActions(keyPressActions(key));
  }

  async down(key: string): Promise<void> {
    await this.performActions([
      { type: "keyDown", value: keyValue(normalizeModifierKey(key) ?? key) },
    ]);
  }

  async up(key: string): Promise<void> {
    await this.performActions([
      { type: "keyUp", value: keyValue(normalizeModifierKey(key) ?? key) },
    ]);
  }

  async insertText(text: string): Promise<void> {
    await this.insertFocusedText(text);
  }
}

export class CraterLocator {
  private readonly parsed: ParsedLocatorSelector;
  private readonly filters: LocatorFilter[];
  private readonly rootExpression: string | null;
  private readonly index: number | "last" | null;
  private readonly timeoutResolver: CraterTimeoutResolver;

  constructor(
    protected page: CraterBidiPage,
    protected selector: string,
    options: {
      rootExpression?: string | null;
      filters?: LocatorFilter[];
      index?: number | "last" | null;
      timeoutResolver?: CraterTimeoutResolver;
    } = {},
  ) {
    this.parsed = parseLocatorSelector(selector);
    this.rootExpression = options.rootExpression ?? null;
    this.filters = options.filters ?? [];
    this.index = options.index ?? null;
    this.timeoutResolver = options.timeoutResolver ?? ((timeout, fallback) => timeout ?? fallback);
  }

  filter(options: { hasText?: string | RegExp; hasNotText?: string | RegExp }): CraterLocator {
    const filters = [...this.filters];
    if (options.hasText !== undefined) {
      filters.push(normalizeLocatorFilter("hasText", options.hasText));
    }
    if (options.hasNotText !== undefined) {
      filters.push(normalizeLocatorFilter("hasNotText", options.hasNotText));
    }
    return new CraterLocator(this.page, this.selector, {
      rootExpression: this.rootExpression,
      filters,
      index: this.index,
      timeoutResolver: this.timeoutResolver,
    });
  }

  private withAdditionalFilters(filters: LocatorFilter[]): CraterLocator {
    if (filters.length === 0) {
      return this;
    }
    return new CraterLocator(this.page, this.selector, {
      rootExpression: this.rootExpression,
      filters: [...this.filters, ...filters],
      index: this.index,
      timeoutResolver: this.timeoutResolver,
    });
  }

  locator(selector: string): CraterLocator {
    return new CraterLocator(this.page, selector, {
      rootExpression: this.queryExpr("querySelector"),
      timeoutResolver: this.timeoutResolver,
    });
  }

  getByText(text: CraterTextMatcher, options: CraterTextMatchOptions = {}): CraterLocator {
    return this.locator(locatorSelector("text", text, options));
  }

  getByRole(role: string, options: CraterGetByRoleOptions = {}): CraterLocator {
    return this.locator(`role=${role}`).withAdditionalFilters(roleOptionFilters(options));
  }

  getByPlaceholder(text: CraterTextMatcher, options: CraterTextMatchOptions = {}): CraterLocator {
    return this.locator(locatorSelector("placeholder", text, options));
  }

  getByAltText(text: CraterTextMatcher, options: CraterTextMatchOptions = {}): CraterLocator {
    return this.locator(locatorSelector("alt", text, options));
  }

  getByTitle(text: CraterTextMatcher, options: CraterTextMatchOptions = {}): CraterLocator {
    return this.locator(locatorSelector("title", text, options));
  }

  getByTestId(testId: CraterTextMatcher): CraterLocator {
    return this.locator(locatorSelector("testid", testId));
  }

  getByLabel(text: CraterTextMatcher, options: CraterTextMatchOptions = {}): CraterLocator {
    return this.locator(locatorSelector("label", text, options));
  }

  first(): CraterLocator {
    return new CraterLocator(this.page, this.selector, {
      rootExpression: this.rootExpression,
      filters: this.filters,
      index: 0,
      timeoutResolver: this.timeoutResolver,
    });
  }

  last(): CraterLocator {
    return new CraterLocator(this.page, this.selector, {
      rootExpression: this.rootExpression,
      filters: this.filters,
      index: "last",
      timeoutResolver: this.timeoutResolver,
    });
  }

  nth(index: number): CraterLocator {
    return new CraterLocator(this.page, this.selector, {
      rootExpression: this.rootExpression,
      filters: this.filters,
      index,
      timeoutResolver: this.timeoutResolver,
    });
  }

  async click(options: CraterLocatorActionOptions = {}): Promise<void> {
    if (!options.force) await this.waitForActionable(options);
    await this.page.evaluate(`
      (() => {
        const el = ${this.queryExpr("querySelector")};
        if (!el) throw new Error("Element not found: ${this.selectorForError()}");
        ${adapterDomActionsExpr()}
        __craterAction.clickElement(el);
      })()
    `);
    await markLiveDomCaptureNeeded(this.page);
  }

  async hover(options: CraterLocatorActionOptions = {}): Promise<void> {
    if (!options.force) await this.waitForActionable(options);
    await this.page.evaluate(`
      (() => {
        const el = ${this.queryExpr("querySelector")};
        if (!el) throw new Error("Element not found: ${this.selectorForError()}");
        ${adapterDomActionsExpr()}
        __craterAction.hoverElement(el);
      })()
    `);
    await markLiveDomCaptureNeeded(this.page);
  }

  async scrollIntoViewIfNeeded(options: CraterLocatorActionOptions = {}): Promise<void> {
    await this.waitFor({ state: "attached", timeout: options.timeout });
    await this.page.evaluate(`
      (() => {
        const el = ${this.queryExpr("querySelector")};
        if (!el) throw new Error("Element not found: ${this.selectorForError()}");
        if (typeof el.scrollIntoView === "function") {
          el.scrollIntoView({ block: "nearest", inline: "nearest" });
          return;
        }
        const win = globalThis.window || globalThis;
        let targetX = Number(win.scrollX || globalThis.scrollX || 0);
        let targetY = Number(win.scrollY || globalThis.scrollY || 0);
        if (typeof el.getBoundingClientRect === "function") {
          try {
            const rect = el.getBoundingClientRect();
            const viewportWidth = Number(win.innerWidth || globalThis.innerWidth || 1024);
            const viewportHeight = Number(win.innerHeight || globalThis.innerHeight || 768);
            const left = Number(rect.left ?? rect.x ?? 0);
            const top = Number(rect.top ?? rect.y ?? 0);
            const right = Number(rect.right ?? (left + Number(rect.width || 0)));
            const bottom = Number(rect.bottom ?? (top + Number(rect.height || 0)));
            if (top < 0) {
              targetY += top;
            } else if (bottom > viewportHeight) {
              targetY += bottom - viewportHeight;
            }
            if (left < 0) {
              targetX += left;
            } else if (right > viewportWidth) {
              targetX += right - viewportWidth;
            }
          } catch (_e) {}
        }
        targetX = Math.max(0, targetX);
        targetY = Math.max(0, targetY);
        if (typeof win.scrollTo === "function") {
          try {
            win.scrollTo({ left: targetX, top: targetY, behavior: "instant" });
          } catch (_e) {
            try { win.scrollTo(targetX, targetY); } catch (_err) {}
          }
        }
        win.scrollX = targetX;
        win.scrollY = targetY;
        win.pageXOffset = targetX;
        win.pageYOffset = targetY;
        globalThis.scrollX = targetX;
        globalThis.scrollY = targetY;
        globalThis.pageXOffset = targetX;
        globalThis.pageYOffset = targetY;
        const scroller = document.scrollingElement || document.documentElement || document.body;
        if (scroller) {
          scroller.scrollLeft = targetX;
          scroller.scrollTop = targetY;
        }
      })()
    `);
    await markLiveDomCaptureNeeded(this.page);
  }

  async focus(options: CraterLocatorActionOptions = {}): Promise<void> {
    if (!options.force) await this.waitForActionable(options);
    await this.page.evaluate(`
      (() => {
        const el = ${this.queryExpr("querySelector")};
        if (!el) throw new Error("Element not found: ${this.selectorForError()}");
        if (typeof el.focus === "function") {
          el.focus();
        }
        globalThis.__bidiFocusedElement = el;
        el.dispatchEvent(new Event("focus", { bubbles: false }));
        el.dispatchEvent(new Event("focusin", { bubbles: true }));
      })()
    `);
  }

  async fill(value: string, options: CraterLocatorActionOptions = {}): Promise<void> {
    if (!options.force) await this.waitForActionable(options);
    await this.page.evaluate(`
      (() => {
        ${adapterDomActionsExpr()}
        const el = ${this.queryExpr("querySelector")};
        if (!el) throw new Error("Element not found: ${this.selectorForError()}");
        __craterAction.setEditableValue(el, ${jsString(value)});
        __craterAction.dispatchInputChange(el);
      })()
    `);
    await markLiveDomCaptureNeeded(this.page);
  }

  async clear(): Promise<void> {
    await this.fill("");
  }

  async type(text: string, options: CraterLocatorActionOptions = {}): Promise<void> {
    if (!options.force) await this.waitForActionable(options);
    const handled = await this.page.evaluate<boolean>(`
      (() => {
        ${adapterDomActionsExpr()}
        const el = ${this.queryExpr("querySelector")};
        if (!el) throw new Error("Element not found: ${this.selectorForError()}");
        const tag = __craterAction.tagName(el);
        if (!__craterAction.isContentEditable(el) || tag === "input" || tag === "textarea") return false;
        __craterAction.focusElement(el);
        __craterAction.insertText(el, ${jsString(text)}, {
          keyEvents: true,
          perCharacter: true,
          textContentOnly: true,
        });
        return true;
      })()
    `);
    if (handled) {
      await markLiveDomCaptureNeeded(this.page);
      return;
    }
    await this.focus();
    for (const char of [...text]) {
      await this.page.press(char);
    }
    await markLiveDomCaptureNeeded(this.page);
  }

  async press(key: string): Promise<void> {
    await this.focus();
    await this.page.press(key);
    await markLiveDomCaptureNeeded(this.page);
  }

  async dispatchEvent(type: string, eventInit: Record<string, unknown> = {}): Promise<void> {
    await this.page.evaluate(`
      (() => {
        const el = ${this.queryExpr("querySelector")};
        if (!el) throw new Error("Element not found: ${this.selectorForError()}");
        const init = ${JSON.stringify(eventInit)};
        const hasDetail = Object.prototype.hasOwnProperty.call(init, "detail");
        const event = hasDetail && typeof CustomEvent === "function"
          ? new CustomEvent(${jsString(type)}, { bubbles: true, cancelable: true, ...init })
          : new Event(${jsString(type)}, { bubbles: true, cancelable: true, ...init });
        if (hasDetail && event.detail !== init.detail) {
          Object.defineProperty(event, "detail", { value: init.detail });
        }
        el.dispatchEvent(event);
      })()
    `);
    await markLiveDomCaptureNeeded(this.page);
  }

  async check(options: CraterLocatorActionOptions = {}): Promise<void> {
    await this.setChecked(true, options);
  }

  async uncheck(options: CraterLocatorActionOptions = {}): Promise<void> {
    await this.setChecked(false, options);
  }

  async selectOption(
    value: CraterSelectOptionValue,
    options: CraterLocatorActionOptions = {},
  ): Promise<void> {
    if (!options.force) await this.waitForActionable(options);
    const requestExpr = jsValue(value);
    await this.page.evaluate(`
      (() => {
        ${adapterDomActionsExpr()}
        const el = ${this.queryExpr("querySelector")};
        if (!el) throw new Error("Element not found: ${this.selectorForError()}");
        __craterAction.selectOptions(el, ${requestExpr});
      })()
    `);
    await markLiveDomCaptureNeeded(this.page);
  }

  async setInputFiles(files: CraterSetInputFilesValue): Promise<void> {
    await this.waitFor();
    const inputFiles = normalizeInputFiles(files);
    const sourcePaths = inputFiles.map((file) => file.sourcePath);
    const syntheticFiles = inputFiles.map((file) => ({
      name: file.name,
      type: file.type,
      size: file.size,
    }));
    await this.page.evaluate(`
      (() => {
        const input = ${this.queryExpr("querySelector")};
        if (!input) throw new Error("Element not found: ${this.selectorForError()}");
        const sourcePaths = ${jsValue(sourcePaths)};
        const syntheticFiles = ${jsValue(syntheticFiles)};
        const attr = (name) => {
          try {
            if (typeof input.getAttribute === "function") return input.getAttribute(name);
          } catch (_e) {}
          return input._attrs ? input._attrs[name] : null;
        };
        const tag = String(input.localName || input.tagName || input.nodeName || "").toLowerCase();
        const type = tag === "input" ? String(input.type || attr("type") || "").toLowerCase() : "";
        const disabled = Boolean(input.disabled) || attr("disabled") !== null;
        const multiple = Boolean(input.multiple) || attr("multiple") !== null;
        if (tag !== "input" || type !== "file") {
          throw new Error("Target is not a file input: ${this.selectorForError()}");
        }
        if (disabled || (!multiple && sourcePaths.length > 1)) {
          throw new Error("Unable to set file input: ${this.selectorForError()}");
        }
        const previousSourcePaths = Array.isArray(input.__craterSyntheticSourcePaths)
          ? input.__craterSyntheticSourcePaths.slice()
          : [];
        const sameSelection = previousSourcePaths.length === sourcePaths.length &&
          previousSourcePaths.every((path, index) => path === sourcePaths[index]);
        try {
          Object.defineProperty(input, "files", {
            configurable: true,
            get: () => syntheticFiles,
          });
        } catch (_e) {
          input.files = syntheticFiles;
        }
        input.__craterSyntheticSourcePaths = sourcePaths.slice();
        const emit = (type) => {
          if (typeof Event === "function") {
            input.dispatchEvent(new Event(type, { bubbles: true }));
          } else if (document && typeof document.createEvent === "function") {
            const event = document.createEvent("Event");
            event.initEvent(type, true, false);
            input.dispatchEvent(event);
          }
        };
        if (sameSelection) {
          emit("cancel");
          return;
        }
        emit("input");
        emit("change");
      })()
    `);
  }

  async evaluate<T, Arg = unknown>(
    fn: (element: Element, arg: Arg) => T | Promise<T>,
    arg?: Arg,
  ): Promise<T> {
    const fnStr = fn.toString();
    const argExpr = arguments.length >= 2 ? `, ${jsValue(arg)}` : "";
    return this.page.evaluate(
      `(() => {
        const element = ${this.queryExpr("querySelector")};
        if (!element) throw new Error("Element not found: ${this.selectorForError()}");
        return (${fnStr})(element${argExpr});
      })()`,
      { awaitPromise: fn.constructor.name === "AsyncFunction" },
    );
  }

  async evaluateAll<T, Arg = unknown>(
    fn: (elements: Element[], arg: Arg) => T | Promise<T>,
    arg?: Arg,
  ): Promise<T> {
    const fnStr = fn.toString();
    const argExpr = arguments.length >= 2 ? `, ${jsValue(arg)}` : "";
    return this.page.evaluate(
      `(() => {
        const elements = ${this.queryExpr("querySelectorAll")};
        return (${fnStr})(elements${argExpr});
      })()`,
      { awaitPromise: fn.constructor.name === "AsyncFunction" },
    );
  }

  async allTextContents(): Promise<string[]> {
    const json = await this.page.evaluate<string>(
      `JSON.stringify((${this.queryExpr("querySelectorAll")}).map((el) => String(el.textContent || "")))`,
    );
    return JSON.parse(json) as string[];
  }

  async allInnerTexts(): Promise<string[]> {
    const json = await this.page.evaluate<string>(
      `JSON.stringify((${this.queryExpr("querySelectorAll")}).map((el) => String(el.innerText ?? el.textContent ?? "")))`,
    );
    return JSON.parse(json) as string[];
  }

  async textContent(): Promise<string | null> {
    return this.page.evaluate(`
      (() => {
        const el = ${this.queryExpr("querySelector")};
        return el ? el.textContent : null;
      })()
    `);
  }

  async innerHTML(): Promise<string> {
    return this.page.evaluate(`
      (() => {
        const el = ${this.queryExpr("querySelector")};
        return el ? el.innerHTML : "";
      })()
    `);
  }

  async inputValue(): Promise<string> {
    return this.page.evaluate(`
      (() => {
        const el = ${this.queryExpr("querySelector")};
        return el ? el.value : "";
      })()
    `);
  }

  async isVisible(): Promise<boolean> {
    return this.page.evaluate(elementVisibleExpr(this.queryExpr("querySelector")));
  }

  async isHidden(): Promise<boolean> {
    return !(await this.isVisible());
  }

  async isChecked(): Promise<boolean> {
    return this.page.evaluate(`
      (() => {
        const el = ${this.queryExpr("querySelector")};
        return !!(el && el.checked);
      })()
    `);
  }

  async isDisabled(): Promise<boolean> {
    return this.page.evaluate(elementDisabledExpr(this.queryExpr("querySelector")));
  }

  async isEnabled(): Promise<boolean> {
    return !(await this.isDisabled());
  }

  async isEditable(): Promise<boolean> {
    return this.page.evaluate(`
      (() => {
        const el = ${this.queryExpr("querySelector")};
        if (!el) return false;
        const tag = String(el.tagName || el.nodeName || "").toLowerCase();
        const editableTag = tag === "input" || tag === "textarea";
        const contentEditable = String(el.contentEditable || "").toLowerCase() === "true";
        const disabled = ${elementDisabledExpr("el")};
        const readonly = !!(el.readOnly || (typeof el.hasAttribute === "function" && el.hasAttribute("readonly")));
        return (editableTag || contentEditable) && !disabled && !readonly;
      })()
    `);
  }

  async getAttribute(name: string): Promise<string | null> {
    return this.page.evaluate(`
      (() => {
        const el = ${this.queryExpr("querySelector")};
        return el ? el.getAttribute(${jsString(name)}) : null;
      })()
    `);
  }

  async waitFor(options: CraterWaitForSelectorOptions = {}): Promise<void> {
    const state = this.normalizeWaitForState(options.state ?? "attached");
    const timeout = this.timeoutResolver(options.timeout, 5000);
    const start = Date.now();
    let lastState: { attached: boolean; visible: boolean } | null = null;
    while (Date.now() - start < timeout) {
      const current = await this.page.evaluate<{
        attached: boolean;
        visible: boolean;
      }>(`
        (() => {
          const el = ${this.queryExpr("querySelector")};
          return {
            attached: !!el,
            visible: ${elementVisibleExpr("el")},
          };
        })()
      `);
      lastState = current;
      if (this.waitForStateMatches(state, current)) {
        return;
      }
      await new Promise((resolve) => setTimeout(resolve, 30));
    }
    const suffix = lastState ? ` (last state: ${this.describeWaitForState(lastState)})` : "";
    throw new Error(`Timeout waiting for selector state ${state}: ${this.selector}${suffix}`);
  }

  async count(): Promise<number> {
    return this.page.evaluate(`
      (() => {
        const els = ${this.queryExpr("querySelectorAll")};
        return els ? els.length : 0;
      })()
    `);
  }

  private async setChecked(
    checked: boolean,
    options: CraterLocatorActionOptions = {},
  ): Promise<void> {
    if (!options.force) await this.waitForActionable(options);
    await this.page.evaluate(`
      (() => {
        ${adapterDomActionsExpr()}
        const el = ${this.queryExpr("querySelector")};
        if (!el) throw new Error("Element not found: ${this.selectorForError()}");
        __craterAction.setChecked(el, ${checked});
      })()
    `);
    await markLiveDomCaptureNeeded(this.page);
  }

  private async waitForActionable(options: { timeout?: number } = {}): Promise<void> {
    const timeout = this.timeoutResolver(options.timeout, 5000);
    const start = Date.now();
    let previousRectKey: string | null | undefined;
    let lastState: {
      attached: boolean;
      visible: boolean;
      enabled: boolean;
      rectKey: string | null;
    } | null = null;
    while (Date.now() - start < timeout) {
      const state = await this.page.evaluate<{
        attached: boolean;
        visible: boolean;
        enabled: boolean;
        rectKey: string | null;
      }>(`
        (() => {
          const el = ${this.queryExpr("querySelector")};
          const attached = !!el;
          const visible = ${elementVisibleExpr("el")};
          const disabled = ${elementDisabledExpr("el")};
          let rectKey = null;
          if (el && typeof el.getBoundingClientRect === "function") {
            try {
              const rect = el.getBoundingClientRect();
              const values = [
                rect.x ?? rect.left ?? 0,
                rect.y ?? rect.top ?? 0,
                rect.width ?? ((rect.right ?? 0) - (rect.left ?? 0)),
                rect.height ?? ((rect.bottom ?? 0) - (rect.top ?? 0)),
              ];
              rectKey = values.map((value) => Number(value).toFixed(3)).join(":");
            } catch (_e) {}
          }
          return { attached, visible, enabled: !disabled, rectKey };
        })()
      `);
      lastState = state;
      if (state.attached && state.visible && state.enabled) {
        if (state.rectKey === null || previousRectKey === state.rectKey) {
          return;
        }
        previousRectKey = state.rectKey;
      } else {
        previousRectKey = undefined;
      }
      await new Promise((resolve) => setTimeout(resolve, 30));
    }
    const reason = !lastState?.attached
      ? "not attached"
      : !lastState.visible
      ? "not visible"
      : !lastState.enabled
      ? "not enabled"
      : "not stable";
    throw new Error(`Timeout waiting for actionable selector (${reason}): ${this.selector}`);
  }

  private waitForStateMatches(
    state: CraterWaitForSelectorState,
    current: { attached: boolean; visible: boolean },
  ): boolean {
    switch (state) {
      case "attached":
        return current.attached;
      case "detached":
        return !current.attached;
      case "visible":
        return current.attached && current.visible;
      case "hidden":
        return !current.attached || !current.visible;
      default:
        throw new Error(`Unsupported waitFor state: ${String(state)}`);
    }
  }

  private normalizeWaitForState(state: string): CraterWaitForSelectorState {
    switch (state) {
      case "attached":
      case "detached":
      case "visible":
      case "hidden":
        return state;
      default:
        throw new Error(`Unsupported waitFor state: ${state}`);
    }
  }

  private describeWaitForState(current: { attached: boolean; visible: boolean }): string {
    return `${current.attached ? "attached" : "detached"} ${current.visible ? "visible" : "hidden"}`;
  }

  protected queryExpr(method: "querySelector" | "querySelectorAll"): string {
    const allExpr = this.filteredAllQueryExpr();
    if (method === "querySelectorAll") {
      return allExpr;
    }
    if (this.index === "last") {
      return `(() => {
        const els = ${allExpr};
        return els.length > 0 ? els[els.length - 1] : null;
      })()`;
    }
    const index = this.index ?? 0;
    return `(() => {
      const els = ${allExpr};
      return els[${index}] || null;
    })()`;
  }

  private filteredAllQueryExpr(): string {
    const rootExpr = this.rootExpression
      ? `(() => {
          const root = ${this.rootExpression};
          if (!root) return [];
          return ${buildSelectorExpr(this.parsed, "all", "root")};
        })()`
      : buildSelectorExpr(this.parsed, "all");
    if (this.filters.length === 0) {
      return rootExpr;
    }
    const predicate = this.filters.map(filterPredicateExpr).join(" && ");
    return `(${rootExpr}).filter((el) => ${predicate})`;
  }

  private selectorForError(): string {
    return this.selector.replace(/\\/g, "\\\\").replace(/"/g, '\\"');
  }
}

export class CraterFrameLocator {
  private readonly parsed: ParsedLocatorSelector;

  constructor(
    private readonly page: CraterBidiPage,
    private readonly selector: string,
    private readonly timeoutResolver: CraterTimeoutResolver,
  ) {
    this.parsed = parseLocatorSelector(selector);
  }

  locator(selector: string): CraterLocator {
    return this.createLocator(selector);
  }

  getByText(text: CraterTextMatcher, options: CraterTextMatchOptions = {}): CraterLocator {
    return this.locator(locatorSelector("text", text, options));
  }

  getByRole(role: string, options: CraterGetByRoleOptions = {}): CraterLocator {
    return this.createLocator(`role=${role}`, {
      filters: roleOptionFilters(options),
    });
  }

  getByPlaceholder(text: CraterTextMatcher, options: CraterTextMatchOptions = {}): CraterLocator {
    return this.locator(locatorSelector("placeholder", text, options));
  }

  getByAltText(text: CraterTextMatcher, options: CraterTextMatchOptions = {}): CraterLocator {
    return this.locator(locatorSelector("alt", text, options));
  }

  getByTitle(text: CraterTextMatcher, options: CraterTextMatchOptions = {}): CraterLocator {
    return this.locator(locatorSelector("title", text, options));
  }

  getByTestId(testId: CraterTextMatcher): CraterLocator {
    return this.locator(locatorSelector("testid", testId));
  }

  getByLabel(text: CraterTextMatcher, options: CraterTextMatchOptions = {}): CraterLocator {
    return this.locator(locatorSelector("label", text, options));
  }

  private createLocator(
    selector: string,
    options: { filters?: LocatorFilter[] } = {},
  ): CraterLocator {
    return new CraterLocator(this.page, selector, {
      rootExpression: this.frameRootExpression(),
      filters: options.filters,
      timeoutResolver: this.timeoutResolver,
    });
  }

  private frameRootExpression(): string {
    const frameExpr = buildSelectorExpr(this.parsed, "first");
    return `(() => {
      const frame = ${frameExpr};
      if (!frame) return null;
      let frameDocument = null;
      try {
        frameDocument = frame.contentDocument || null;
      } catch (_e) {}
      if (!frameDocument) {
        try {
          frameDocument = (frame.contentWindow && frame.contentWindow.document) || null;
        } catch (_e) {}
      }
      if (!frameDocument) return null;
      return frameDocument.documentElement || frameDocument.body || frameDocument;
    })()`;
  }
}

export class CraterBidiPage {
  readonly keyboard = new CraterKeyboard(
    (actions) => this.performKeyboardActions(actions),
    (text) => this.insertTextIntoFocusedElement(text),
  );
  private ws: WebSocket | null = null;
  private commandId = 0;
  private pendingCommands = new Map<number, PendingCommand>();
  private eventHandlers: ((event: BidiEvent) => void)[] = [];
  private contextId: string | null = null;
  private runtimeLockContext: string | null = null;
  private runtimeLockCount = 0;
  private runtimeLockSettled: Promise<void> = Promise.resolve();
  private runtimeLockRelease: (() => void) | null = null;
  private navigationPromise: Promise<void> | null = null;
  private navigationResolve: (() => void) | null = null;
  private initScripts: string[] = [];
  private defaultTimeout: number | null = null;
  private routes: CraterRouteEntry[] = [];
  private routePump: ReturnType<typeof setInterval> | null = null;
  private routePumpBusy = false;
  private routePumpQueued = false;
  private networkHooksInstalled = false;
  private networkHookInstallPromise: Promise<void> | null = null;
  private networkEventPump: ReturnType<typeof setInterval> | null = null;
  private networkEventPumpStarting: Promise<void> | null = null;
  private networkEventPumpBusy = false;
  private networkEventEmitIndex = 0;
  private fileChooserEventPump: ReturnType<typeof setInterval> | null = null;
  private fileChooserEventPumpBusy = false;
  private fileChooserEventEmitIndex = 0;
  private dialogSubscribed = false;
  private dialogSubscribePromise: Promise<void> | null = null;
  private downloadSubscribed = false;
  private downloadSubscribePromise: Promise<void> | null = null;
  private pendingDownloads = new Map<string, CraterPendingDownload>();
  private consoleSubscribed = false;
  private consoleSubscribePromise: Promise<void> | null = null;
  private closed = false;
  private currentUrl = "about:blank";
  private navigationFlushDepth = 0;
  private pageEventHandlers = new Map<string, Set<CraterPageEventHandler>>();
  private pageEventWaiters: CraterPageEventWaiter[] = [];

  constructor(
    private readonly sharedConnection: SharedBidiConnection | null = null,
    private readonly closeHandler: CraterPageCloseHandler | null = null,
  ) {
    if (this.sharedConnection) {
      this.sharedConnection.onEvent((event) => this.handleEventMessage(event));
    }
  }

  async connect(options: CraterBidiConnectOptions = {}): Promise<void> {
    if (this.sharedConnection) {
      throw new Error("Shared CraterBidiPage instances are connected by their browser context");
    }
    const timeout = options.timeout ?? 15000;
    const retries = options.retries ?? 2;
    let lastError: Error | undefined;
    for (let attempt = 0; attempt <= retries; attempt++) {
      if (attempt > 0) {
        await new Promise((resolve) => setTimeout(resolve, 1000 * attempt));
      }
      try {
        await this.connectOnce(timeout, options.url);
        return;
      } catch (error) {
        lastError = error instanceof Error ? error : new Error(String(error));
        this.ws?.close();
        this.ws = null;
      }
    }
    throw lastError ?? new Error("connect failed");
  }

  onEvent(handler: (event: BidiEvent) => void): void {
    this.eventHandlers.push(handler);
  }

  on<K extends CraterPageEventName>(
    eventName: K,
    handler: CraterPageEventHandler<CraterPageEventMap[K]>,
  ): this {
    const handlers = this.pageEventHandlers.get(eventName) ?? new Set();
    handlers.add(handler as CraterPageEventHandler);
    this.pageEventHandlers.set(eventName, handlers);
    if (isNetworkPageEvent(eventName)) {
      void this.startNetworkEventPump();
    }
    if (isFileChooserPageEvent(eventName)) {
      this.startFileChooserEventPump();
    }
    if (isDialogPageEvent(eventName)) {
      void this.ensureDialogSubscription();
    }
    if (isDownloadPageEvent(eventName)) {
      void this.ensureDownloadSubscription();
    }
    if (isConsolePageEvent(eventName)) {
      void this.ensureConsoleSubscription();
    }
    return this;
  }

  async waitForEvent<K extends CraterPageEventName>(
    eventName: K,
    options: CraterWaitForEventOptions<CraterPageEventMap[K]> = {},
  ): Promise<CraterPageEventMap[K]> {
    if (isNetworkPageEvent(eventName)) {
      return await this.waitForNetworkPageEvent(eventName, options as CraterWaitForEventOptions) as CraterPageEventMap[K];
    }
    if (isFileChooserPageEvent(eventName)) {
      return await this.waitForFileChooserEvent(options as CraterWaitForEventOptions) as CraterPageEventMap[K];
    }
    const eventPromise = this.waitForLocalPageEvent(
      eventName as CraterLocalPageEventName,
      options as CraterWaitForEventOptions,
    ) as Promise<CraterPageEventMap[K]>;
    if (isDialogPageEvent(eventName)) {
      await this.ensureSubscribedBeforeReturning(eventPromise, () => this.ensureDialogSubscription());
    }
    if (isDownloadPageEvent(eventName)) {
      await this.ensureSubscribedBeforeReturning(eventPromise, () => this.ensureDownloadSubscription());
    }
    if (isConsolePageEvent(eventName)) {
      await this.ensureSubscribedBeforeReturning(eventPromise, () => this.ensureConsoleSubscription());
    }
    return await eventPromise;
  }

  async close(): Promise<void> {
    if (this.closed) {
      return;
    }
    if (this.contextId && (this.routes.length > 0 || this.routePump)) {
      try {
        await this.installNetworkHooks({ routeEnabled: false });
      } catch {
        // Best-effort cleanup; close should continue even if the context is already gone.
      }
    }
    const contextId = this.contextId;
    this.contextId = null;
    if (contextId) {
      try {
        await this.sendBidi("browsingContext.close", { context: contextId });
      } catch {
        // Best-effort close for long-running VRT cases; the socket is closed below regardless.
      }
    }
    if (this.routePump) {
      clearInterval(this.routePump);
      this.routePump = null;
    }
    if (this.networkEventPump) {
      clearInterval(this.networkEventPump);
      this.networkEventPump = null;
    }
    if (this.fileChooserEventPump) {
      clearInterval(this.fileChooserEventPump);
      this.fileChooserEventPump = null;
    }
    this.routes = [];
    if (!this.sharedConnection) {
      this.ws?.close();
      this.ws = null;
    }
    this.closed = true;
    this.closeHandler?.(this);
    this.emitPageEvent("close", this);
  }

  async createSiblingPage(closeHandler: CraterPageCloseHandler | null = null): Promise<CraterBidiPage> {
    const page = new CraterBidiPage({
      sendBidi: (method, params) => this.sendBidi(method, params),
      onEvent: (handler) => this.onEvent(handler),
    }, closeHandler);
    const resp = await this.sendBidi("browsingContext.create", { type: "tab" });
    page.contextId = (resp.result as { context: string }).context;
    await page.installModelContextRuntime({ resetRegistry: true });
    return page;
  }

  async goto(url: string, options: CraterGotoOptions = {}): Promise<CraterResponse | null> {
    return await this.withOperationTimeout(
      this.gotoInternal(url, options),
      options.timeout,
      "page.goto",
    );
  }

  private async gotoInternal(
    url: string,
    options: CraterGotoOptions,
  ): Promise<CraterResponse | null> {
    const targetUrl = url.startsWith("http://") || url.startsWith("https://") || url.startsWith("data:") || url.startsWith("about:")
      ? url
      : `data:text/html;base64,${Buffer.from(url).toString("base64")}`;
    if (targetUrl.startsWith("http://") || targetUrl.startsWith("https://") || targetUrl.startsWith("data:")) {
      const result = await this.loadPage(targetUrl);
      await this.waitForGotoLoadState(options);
      return this.responseFromLoadResult(result, targetUrl);
    }
    const wait = this.gotoBidiWaitMode(options.waitUntil);
    await this.sendBidi("browsingContext.navigate", {
      context: this.requireContextId(),
      url: targetUrl,
      wait,
    });
    await this.syncRuntimeLocation(targetUrl);
    this.emitPageEvent("domcontentloaded", this);
    this.emitPageEvent("load", this);
    await this.waitForGotoLoadState(options);
    return null;
  }

  private gotoBidiWaitMode(waitUntil: CraterGotoWaitUntil | undefined): "none" | "interactive" | "complete" {
    switch (waitUntil) {
      case "commit":
        return "none";
      case "domcontentloaded":
        return "interactive";
      case "networkidle":
      case "networkidle0":
      case "networkidle2":
      case "load":
      case undefined:
      default:
        return "complete";
    }
  }

  private async waitForGotoLoadState(options: CraterGotoOptions): Promise<void> {
    const waitUntil = options.waitUntil ?? "load";
    if (waitUntil === "commit") {
      return;
    }
    await this.waitForLoadState(waitUntil, { timeout: options.timeout });
  }

  async setContent(html: string): Promise<void> {
    await this.prepareRuntimeDocumentForLoad();
    await this.installModelContextRuntime({ resetRegistry: true });
    await this.syncRuntimeLocation("about:blank");
    await this.evaluate(`__loadHTML(${jsString(html)})`);
    await this.evaluate(`globalThis.__craterInstallScrollingStubs && globalThis.__craterInstallScrollingStubs()`);
    await this.evaluate(paintCaptureSourceExpression("original"));
    await this.reinstallNetworkHooksForDocument();
    await this.runInitScripts();
    await this.setObservableFetchForScriptExecution(this.networkHooksInstalled);
    try {
      const scriptsJson = await this.evaluate<string>(
        `(async () => JSON.stringify(await __executeScripts()))()`,
        { awaitPromise: true },
      );
      this.emitPageErrorsFromScriptResults(JSON.parse(scriptsJson) as CraterScriptExecutionResult[]);
    } finally {
      await this.setObservableFetchForScriptExecution(false);
    }
    this.emitPageEvent("domcontentloaded", this);
    this.emitPageEvent("load", this);
  }

  async setContentWithScripts(html: string): Promise<void> {
    await this.setContent(html);
  }

  async loadPage(
    url: string,
    options: { executeScripts?: boolean } = {},
  ): Promise<CraterPageLoadResult> {
    const executeScripts = options.executeScripts !== false;
    await this.prepareRuntimeDocumentForLoad({ resetWindow: true });
    await this.installModelContextRuntime({ resetRegistry: true });
    await this.ensureNetworkHooksReady();
    const json = await this.evaluate<string>(
      `(async () => {
        const targetUrl = ${jsString(url)};
        const fetchFn = ${this.networkHooksInstalled ? "true" : "false"}
          ? (globalThis.__craterObservableFetch || globalThis.__fetchInternal || globalThis.fetch)
          : (globalThis.__fetchInternal || globalThis.fetch);
        if (typeof fetchFn !== "function") {
          throw new Error("fetch is not available in Crater runtime");
        }
        const response = await fetchFn(targetUrl, { mode: "navigate" });
        const headers = {};
        if (response && response.headers && typeof response.headers.forEach === "function") {
          response.headers.forEach((value, key) => {
            headers[String(key).toLowerCase()] = String(value);
          });
        }
        const body = response && typeof response.text === "function"
          ? await response.text()
          : "";
        if (typeof globalThis.__loadHTML === "function") {
          globalThis.__loadHTML(body);
        }
        const finalUrl = response && response.url ? String(response.url) : targetUrl;
        globalThis.__pageUrl = finalUrl;
        return JSON.stringify({
          requestedUrl: targetUrl,
          url: finalUrl,
          status: response && typeof response.status === "number" ? response.status : 0,
          statusText: response && response.statusText ? String(response.statusText) : "",
          headers,
          body,
        });
      })()`,
      { awaitPromise: true },
    );
    const result = JSON.parse(json) as CraterPageLoadResult;
    await this.evaluate(`globalThis.__craterInstallScrollingStubs && globalThis.__craterInstallScrollingStubs()`);
    await this.syncRuntimeLocation(result.url ?? url);
    await this.runInitScripts();
    if (executeScripts) {
      await this.setObservableFetchForScriptExecution(this.networkHooksInstalled);
      try {
        const scriptsJson = await this.evaluate<string>(
          `(async () => JSON.stringify(await __executeScripts({ baseUrl: ${jsString(result.url ?? url)} })))()`,
          { awaitPromise: true },
        );
        result.scripts = JSON.parse(scriptsJson) as CraterScriptExecutionResult[];
        this.emitPageErrorsFromScriptResults(result.scripts);
      } finally {
        await this.setObservableFetchForScriptExecution(false);
      }
    }
    await this.evaluate(paintCaptureSourceExpression("live"));
    await this.observeSubresourceLoads(result.url ?? url);
    this.emitPageEvent("domcontentloaded", this);
    this.emitPageEvent("load", this);
    return result;
  }

  private async observeSubresourceLoads(baseUrl: string): Promise<void> {
    if (this.networkHooksInstalled) {
      await this.ensureNetworkHooksReady();
    }
    await this.evaluate(
      `(async () => {
        const resolve = (value, base) => {
          const raw = String(value || "");
          if (!raw) return "";
          const sourceBase = base || ${jsString(baseUrl)};
          if (globalThis.__resolveUrl) return globalThis.__resolveUrl(raw, sourceBase);
          try { return new URL(raw, sourceBase).href; } catch (_e) { return raw; }
        };
        const resources = [];
        const seen = new Set();
        const add = (value, kind, base) => {
          const resolved = resolve(value, base);
          if (!resolved || resolved.startsWith('data:') || seen.has(resolved)) return;
          seen.add(resolved);
          resources.push({ url: resolved, kind });
        };
        const addCssUrlResources = (cssText, cssBaseUrl) => {
          const source = String(cssText || "");
          const urlRegex = /url\\(\\s*(?:"([^"]+)"|'([^']+)'|([^\\)'\"\\s]+))\\s*\\)/g;
          let match;
          while ((match = urlRegex.exec(source))) {
            add(match[1] || match[2] || match[3] || "", 'css-url', cssBaseUrl);
          }
        };
        for (const link of Array.from(document.querySelectorAll('link'))) {
          const rel = String(link.getAttribute('rel') || '').toLowerCase().split(/\\s+/);
          if (rel.includes('stylesheet')) add(link.getAttribute('href'), 'stylesheet');
        }
        for (const img of Array.from(document.querySelectorAll('img'))) {
          add(img.getAttribute('src'), 'image');
        }
        const fetchFn = ${this.networkHooksInstalled ? "globalThis.__craterObservableFetch || globalThis.__fetchInternal || globalThis.fetch" : "globalThis.__fetchInternal || globalThis.fetch"};
        if (typeof fetchFn !== 'function') return;
        for (let index = 0; index < resources.length; index++) {
          const resource = resources[index];
          const resourceUrl = resource.url;
          try {
            const response = await fetchFn(resourceUrl, {});
            if (resource.kind === 'stylesheet' && response && response.ok && typeof response.text === 'function') {
              const cssText = await response.text();
              if (typeof globalThis.__craterApplyStyleText === 'function') {
                globalThis.__craterApplyStyleText(cssText);
              }
              addCssUrlResources(cssText, resourceUrl);
            } else if (response && typeof response.arrayBuffer === 'function') {
              try { await response.arrayBuffer(); } catch (_e) {}
            }
          } catch (_e) {
            try {
              const internalFetch = globalThis.__fetchInternal || globalThis.fetch;
              if (typeof internalFetch !== 'function') return;
              const response = await internalFetch(resourceUrl, {});
              const headers = {};
              if (response && response.headers && typeof response.headers.forEach === 'function') {
                response.headers.forEach((value, key) => {
                  headers[String(key).toLowerCase()] = String(value);
                });
              }
              if (globalThis.__craterRecordSyntheticResponse) {
                globalThis.__craterRecordSyntheticResponse(
                  resourceUrl,
                  response && typeof response.status === 'number' ? response.status : 0,
                  response && response.statusText ? String(response.statusText) : '',
                  headers,
                  null,
                );
              }
            } catch (_fallbackError) {}
          }
        }
      })()`,
      { awaitPromise: true },
    );
  }

  private async setObservableFetchForScriptExecution(enabled: boolean): Promise<void> {
    await this.evaluate(`
      (() => {
        globalThis.__craterUseObservableFetch = ${enabled ? "true" : "false"};
      })()
    `);
  }

  private async ensureNetworkHooksReady(): Promise<void> {
    if (this.networkHookInstallPromise) {
      await this.networkHookInstallPromise;
    }
  }

  private async reinstallNetworkHooksForDocument(): Promise<void> {
    if (!this.networkHooksInstalled && this.routes.length === 0) {
      return;
    }
    await this.installNetworkHooks(this.routes.length > 0 ? { routeEnabled: true } : {});
    if (this.routes.length > 0) {
      this.startRoutePump();
    }
  }

  private async prepareRuntimeDocumentForLoad(
    options: { resetWindow?: boolean } = {},
  ): Promise<void> {
    const resetWindow = options.resetWindow === true;
    await this.evaluate(`
      (() => {
        const resetWindow = ${resetWindow ? "true" : "false"};
        // The Playwright adapter should behave like a browser page: send
        // cross-origin requests, then enforce CORS at the response boundary.
        if (typeof globalThis.__setRequestSandbox === "function") {
          globalThis.__setRequestSandbox({ mode: "open" });
        }
        const sourceDoc = globalThis.__craterDocumentFactorySource || globalThis.document;
        if (!sourceDoc || typeof sourceDoc.createElement !== "function") return false;
        if (!globalThis.__craterDocumentFactorySource) {
          globalThis.__craterDocumentFactorySource = sourceDoc;
        }

        const currentCtx = String(globalThis.__bidiCurrentContext || "default-context");
        if (!globalThis.__bidiContextWindows) globalThis.__bidiContextWindows = new Map();
        const installWindowEventTarget = (target) => {
          if (!target || typeof target !== "object") return;
          if (!target._listeners || typeof target._listeners !== "object") {
            target._listeners = {};
          }
          target.addEventListener = function(type, listener) {
            if (!listener) return;
            const eventType = String(type);
            if (!this._listeners[eventType]) this._listeners[eventType] = [];
            if (!this._listeners[eventType].includes(listener)) {
              this._listeners[eventType].push(listener);
            }
          };
          target.removeEventListener = function(type, listener) {
            const eventType = String(type);
            if (!this._listeners[eventType]) return;
            this._listeners[eventType] = this._listeners[eventType].filter((entry) => entry !== listener);
          };
          target.dispatchEvent = function(event) {
            if (!event || !event.type) {
              throw new TypeError("Failed to execute dispatchEvent: parameter 1 is not of type Event");
            }
            try { event.target = this; } catch (_error) {}
            try { event.currentTarget = this; } catch (_error) {}
            const previousEvent = globalThis.event;
            globalThis.event = event;
            try {
              const listeners = (this._listeners && this._listeners[String(event.type)]) || [];
              for (const listener of listeners.slice()) {
                try {
                  if (typeof listener === "function") listener.call(this, event);
                  else if (listener && typeof listener.handleEvent === "function") listener.handleEvent(event);
                } catch (_listenerError) {}
              }
            } finally {
              globalThis.event = previousEvent;
            }
            return !event.defaultPrevented;
          };
        };
        if (resetWindow || !globalThis.__bidiContextWindows.has(currentCtx)) {
          const previousWindow = globalThis.__bidiContextWindows.get(currentCtx);
          const win = { __bidiContextId: currentCtx };
          win.window = win;
          win.frames = [];
          if (previousWindow && previousWindow.navigator) {
            win.navigator = previousWindow.navigator;
          } else if (globalThis.navigator) {
            win.navigator = globalThis.navigator;
          }
          globalThis.__bidiContextWindows.set(currentCtx, win);
        }
        const contextWindow = globalThis.__bidiContextWindows.get(currentCtx);
        if (!contextWindow.navigator && globalThis.navigator) {
          contextWindow.navigator = globalThis.navigator;
        }
        for (const nav of [contextWindow.navigator, globalThis.navigator]) {
          if (!nav || typeof nav !== "object") continue;
          try {
            Object.defineProperty(nav, "cookieEnabled", {
              configurable: true,
              enumerable: true,
              value: true,
            });
          } catch (_e) {
            nav.cookieEnabled = true;
          }
        }
        installWindowEventTarget(contextWindow);
        globalThis.addEventListener = contextWindow.addEventListener.bind(contextWindow);
        globalThis.removeEventListener = contextWindow.removeEventListener.bind(contextWindow);
        globalThis.dispatchEvent = contextWindow.dispatchEvent.bind(contextWindow);

        const doc = {
          nodeType: 9,
          doctype: null,
          documentElement: null,
          head: null,
          body: null,
          activeElement: null,
          _listeners: {},
          createElement(tag) {
            const el = sourceDoc.createElement.call(doc, tag);
            el.ownerDocument = doc;
            return el;
          },
          createElementNS(namespaceURI, qualifiedName) {
            const ns = String(namespaceURI || "");
            const name = String(qualifiedName || "div");
            const el = typeof sourceDoc.createElementNS === "function"
              ? sourceDoc.createElementNS.call(doc, ns, name)
              : sourceDoc.createElement.call(doc, name);
            el.ownerDocument = doc;
            el.namespaceURI = ns;
            if (ns === "http://www.w3.org/2000/svg") {
              const localName = name.includes(":") ? name.split(":").pop() : name;
              el.tagName = localName;
              el.nodeName = localName;
              el._tagName = localName;
            }
            return el;
          },
          createTextNode(text) {
            const node = sourceDoc.createTextNode.call(doc, text);
            node.ownerDocument = doc;
            return node;
          },
          createComment(text) {
            const node = typeof sourceDoc.createComment === "function"
              ? sourceDoc.createComment.call(doc, text)
              : { nodeType: 8, nodeName: "#comment", textContent: String(text) };
            node.ownerDocument = doc;
            return node;
          },
          createCDATASection(text) {
            const node = typeof sourceDoc.createCDATASection === "function"
              ? sourceDoc.createCDATASection.call(doc, text)
              : { nodeType: 4, nodeName: "#cdata-section", textContent: String(text) };
            node.ownerDocument = doc;
            return node;
          },
          createProcessingInstruction(target, data) {
            const node = typeof sourceDoc.createProcessingInstruction === "function"
              ? sourceDoc.createProcessingInstruction.call(doc, target, data)
              : { nodeType: 7, nodeName: String(target), target: String(target), data: String(data) };
            node.ownerDocument = doc;
            return node;
          },
          createDocumentFragment() {
            const frag = sourceDoc.createDocumentFragment.call(doc);
            frag.ownerDocument = doc;
            return frag;
          },
          getElementById(id) {
            return this.querySelector("#" + String(id));
          },
          querySelector(selector) {
            return this.documentElement && typeof this.documentElement.querySelector === "function"
              ? this.documentElement.querySelector(selector)
              : null;
          },
          querySelectorAll(selector) {
            return this.documentElement && typeof this.documentElement.querySelectorAll === "function"
              ? this.documentElement.querySelectorAll(selector)
              : [];
          },
          getElementsByTagName(tag) {
            return this.documentElement && typeof this.documentElement.getElementsByTagName === "function"
              ? this.documentElement.getElementsByTagName(tag)
              : [];
          },
          getElementsByClassName(className) {
            return this.documentElement && typeof this.documentElement.getElementsByClassName === "function"
              ? this.documentElement.getElementsByClassName(className)
              : [];
          },
          addEventListener(type, fn) {
            if (!this._listeners[type]) this._listeners[type] = [];
            this._listeners[type].push(fn);
          },
          removeEventListener(type, fn) {
            if (!this._listeners[type]) return;
            this._listeners[type] = this._listeners[type].filter((listener) => listener !== fn);
          },
          dispatchEvent(event) {
            const listeners = this._listeners[event.type] || [];
            for (const fn of listeners) {
              try { fn.call(this, event); } catch (_e) {}
            }
            return !event.defaultPrevented;
          },
          elementFromPoint(x, y) {
            return typeof sourceDoc.elementFromPoint === "function"
              ? sourceDoc.elementFromPoint.call(this, x, y)
              : this.body;
          },
          execCommand(command) {
            return typeof sourceDoc.execCommand === "function"
              ? sourceDoc.execCommand.call(this, command)
              : false;
          },
        };
        Object.defineProperty(doc, "childNodes", {
          configurable: true,
          enumerable: true,
          get() {
            return [this.doctype, this.documentElement].filter(Boolean);
          },
        });
        Object.defineProperty(doc, "scrollingElement", {
          configurable: true,
          enumerable: true,
          get() {
            return this.documentElement || this.body || null;
          },
        });
        if (!contextWindow.__craterCookieJar) {
          contextWindow.__craterCookieJar = new Map();
        }
        Object.defineProperty(doc, "cookie", {
          configurable: true,
          enumerable: true,
          get() {
            return Array.from(contextWindow.__craterCookieJar.entries())
              .map(([name, value]) => String(name) + "=" + String(value))
              .join("; ");
          },
          set(value) {
            const pair = String(value ?? "").split(";")[0] || "";
            const eq = pair.indexOf("=");
            if (eq <= 0) return;
            const name = pair.slice(0, eq).trim();
            const cookieValue = pair.slice(eq + 1).trim();
            if (!name) return;
            contextWindow.__craterCookieJar.set(name, cookieValue);
          },
        });
        const installCaptureStabilizationStubs = (targetWindow, targetDocument) => {
          if (!targetDocument.fonts) {
            const fontSet = {
              status: "loaded",
              check() { return true; },
              load() { return Promise.resolve([]); },
              addEventListener() {},
              removeEventListener() {},
              dispatchEvent() { return true; },
            };
            fontSet.ready = Promise.resolve(fontSet);
            Object.defineProperty(targetDocument, "fonts", {
              configurable: true,
              enumerable: true,
              value: fontSet,
            });
          }
          if (typeof targetDocument.getAnimations !== "function") {
            targetDocument.getAnimations = () => [];
          }
          const host = targetWindow || globalThis;
          const craterPerformanceEntryTypes = [
            "element",
            "largest-contentful-paint",
            "layout-shift",
            "mark",
            "measure",
            "navigation",
            "paint",
            "resource",
          ];
          const makeEntryList = (entries) => ({
            getEntries: () => entries.slice(),
            getEntriesByName: (name) => entries.filter((entry) => entry.name === name),
            getEntriesByType: (type) => entries.filter((entry) => entry.entryType === type),
          });
          const defineObserverProperty = (observerCtor, name, value, enumerable = false) => {
            try {
              Object.defineProperty(observerCtor, name, {
                configurable: true,
                enumerable,
                value,
              });
            } catch (_error) {
              try { observerCtor[name] = value; } catch (_assignError) {}
            }
          };
          const normalizePerformanceObserverSupport = (observerCtor) => {
            if (!observerCtor || (typeof observerCtor !== "function" && typeof observerCtor !== "object")) {
              return observerCtor;
            }
            const existing = Array.isArray(observerCtor.supportedEntryTypes)
              ? observerCtor.supportedEntryTypes
              : [];
            const supportedEntryTypes = Array.from(new Set([
              ...existing,
              ...craterPerformanceEntryTypes,
            ]));
            defineObserverProperty(observerCtor, "supportedEntryTypes", supportedEntryTypes, true);
            defineObserverProperty(observerCtor, "__craterMakeEntryList", makeEntryList);
            return observerCtor;
          };
          if (typeof globalThis.PerformanceObserver !== "function") {
            class CraterPerformanceObserver {
              constructor(callback) {
                this._callback = typeof callback === "function" ? callback : () => {};
                this._records = [];
              }
              observe() {}
              disconnect() {
                this._records = [];
              }
              takeRecords() {
                const records = this._records.slice();
                this._records = [];
                return records;
              }
            }
            CraterPerformanceObserver.supportedEntryTypes = craterPerformanceEntryTypes.slice();
            globalThis.PerformanceObserver = CraterPerformanceObserver;
          }
          normalizePerformanceObserverSupport(globalThis.PerformanceObserver);
          host.PerformanceObserver = globalThis.PerformanceObserver;
          normalizePerformanceObserverSupport(host.PerformanceObserver);
          if (typeof globalThis.IntersectionObserver !== "function") {
            const makeRect = (source) => {
              const left = Number(source && (source.left ?? source.x) || 0);
              const top = Number(source && (source.top ?? source.y) || 0);
              const width = Math.max(0, Number(source && source.width || 0));
              const height = Math.max(0, Number(source && source.height || 0));
              const rect = {
                x: left,
                y: top,
                left,
                top,
                width,
                height,
                right: left + width,
                bottom: top + height,
              };
              rect.toJSON = () => ({
                x: rect.x,
                y: rect.y,
                left: rect.left,
                top: rect.top,
                width: rect.width,
                height: rect.height,
                right: rect.right,
                bottom: rect.bottom,
              });
              return rect;
            };
            const viewportRect = () => makeRect({
              x: 0,
              y: 0,
              width: Number(host.innerWidth || globalThis.innerWidth || 0),
              height: Number(host.innerHeight || globalThis.innerHeight || 0),
            });
            const normalizeThresholds = (threshold) => {
              const values = Array.isArray(threshold) ? threshold : [threshold ?? 0];
              return values
                .map((value) => Number(value))
                .filter((value) => Number.isFinite(value))
                .map((value) => Math.min(1, Math.max(0, value)))
                .sort((a, b) => a - b);
            };
            class CraterIntersectionObserver {
              constructor(callback, options) {
                if (typeof callback !== "function") {
                  throw new TypeError("IntersectionObserver callback must be a function");
                }
                this._callback = callback;
                this._targets = new Set();
                this._records = [];
                this._scheduled = false;
                this.root = options && options.root ? options.root : null;
                this.rootMargin = options && options.rootMargin !== undefined ? String(options.rootMargin) : "0px";
                this.thresholds = normalizeThresholds(options && options.threshold);
              }
              observe(target) {
                if (!target || typeof target !== "object") {
                  throw new TypeError("IntersectionObserver.observe target must be an Element");
                }
                this._targets.add(target);
                this._queue(target);
              }
              unobserve(target) {
                this._targets.delete(target);
              }
              disconnect() {
                this._targets.clear();
                this._records = [];
              }
              takeRecords() {
                const records = this._records.slice();
                this._records = [];
                return records;
              }
              _queue(target) {
                this._records.push(this._entryFor(target));
                if (this._scheduled) return;
                this._scheduled = true;
                setTimeout(() => {
                  this._scheduled = false;
                  const records = this.takeRecords();
                  if (records.length > 0) {
                    this._callback(records, this);
                  }
                }, 0);
              }
              _entryFor(target) {
                const targetRect = makeRect(
                  target && typeof target.getBoundingClientRect === "function"
                    ? target.getBoundingClientRect()
                    : {},
                );
                const rootBounds = this.root && typeof this.root.getBoundingClientRect === "function"
                  ? makeRect(this.root.getBoundingClientRect())
                  : viewportRect();
                const left = Math.max(targetRect.left, rootBounds.left);
                const top = Math.max(targetRect.top, rootBounds.top);
                const right = Math.min(targetRect.right, rootBounds.right);
                const bottom = Math.min(targetRect.bottom, rootBounds.bottom);
                const intersectionRect = makeRect({
                  x: left,
                  y: top,
                  width: Math.max(0, right - left),
                  height: Math.max(0, bottom - top),
                });
                const targetArea = targetRect.width * targetRect.height;
                const intersectionArea = intersectionRect.width * intersectionRect.height;
                const isIntersecting = intersectionArea > 0;
                return {
                  time: Date.now(),
                  rootBounds,
                  boundingClientRect: targetRect,
                  intersectionRect,
                  isIntersecting,
                  intersectionRatio: targetArea > 0 ? intersectionArea / targetArea : (isIntersecting ? 1 : 0),
                  target,
                };
              }
            }
            globalThis.IntersectionObserver = CraterIntersectionObserver;
          }
          host.IntersectionObserver = globalThis.IntersectionObserver;
          if (typeof globalThis.ResizeObserver !== "function") {
            const makeResizeRect = (source) => {
              const left = Number(source && (source.left ?? source.x) || 0);
              const top = Number(source && (source.top ?? source.y) || 0);
              const width = Math.max(0, Number(source && source.width || 0));
              const height = Math.max(0, Number(source && source.height || 0));
              const rect = {
                x: left,
                y: top,
                left,
                top,
                width,
                height,
                right: left + width,
                bottom: top + height,
              };
              rect.toJSON = () => ({
                x: rect.x,
                y: rect.y,
                left: rect.left,
                top: rect.top,
                width: rect.width,
                height: rect.height,
                right: rect.right,
                bottom: rect.bottom,
              });
              return rect;
            };
            const makeResizeBoxSize = (rect) => [{
              inlineSize: rect.width,
              blockSize: rect.height,
            }];
            class CraterResizeObserver {
              constructor(callback) {
                if (typeof callback !== "function") {
                  throw new TypeError("ResizeObserver callback must be a function");
                }
                this._callback = callback;
                this._targets = new Set();
                this._records = [];
                this._scheduled = false;
              }
              observe(target) {
                if (!target || typeof target !== "object") {
                  throw new TypeError("ResizeObserver.observe target must be an Element");
                }
                this._targets.add(target);
                this._queue(target);
              }
              unobserve(target) {
                this._targets.delete(target);
              }
              disconnect() {
                this._targets.clear();
                this._records = [];
              }
              takeRecords() {
                const records = this._records.slice();
                this._records = [];
                return records;
              }
              _queue(target) {
                if (!this._targets.has(target)) return;
                this._records.push(this._entryFor(target));
                if (this._scheduled) return;
                this._scheduled = true;
                setTimeout(() => {
                  this._scheduled = false;
                  const records = this.takeRecords();
                  if (records.length > 0) {
                    this._callback(records, this);
                  }
                }, 0);
              }
              _entryFor(target) {
                const contentRect = makeResizeRect(
                  target && typeof target.getBoundingClientRect === "function"
                    ? target.getBoundingClientRect()
                    : {},
                );
                return {
                  target,
                  contentRect,
                  borderBoxSize: makeResizeBoxSize(contentRect),
                  contentBoxSize: makeResizeBoxSize(contentRect),
                  devicePixelContentBoxSize: makeResizeBoxSize(contentRect),
                };
              }
            }
            globalThis.ResizeObserver = CraterResizeObserver;
          }
          host.ResizeObserver = globalThis.ResizeObserver;
          if (typeof globalThis.DOMParser !== "function") {
            class CraterDOMParser {
              parseFromString(markup, contentType) {
                const normalizedType = String(contentType || "text/html").toLowerCase();
                const parsedDoc = {
                  nodeType: 9,
                  contentType: normalizedType,
                  doctype: null,
                  documentElement: null,
                  head: null,
                  body: null,
                  activeElement: null,
                  createElement(tag) {
                    const el = targetDocument.createElement(String(tag || "div"));
                    el.ownerDocument = parsedDoc;
                    return el;
                  },
                  createElementNS(namespaceURI, qualifiedName) {
                    const el = typeof targetDocument.createElementNS === "function"
                      ? targetDocument.createElementNS(String(namespaceURI || ""), String(qualifiedName || "div"))
                      : targetDocument.createElement(String(qualifiedName || "div"));
                    el.ownerDocument = parsedDoc;
                    return el;
                  },
                  createTextNode(text) {
                    const node = targetDocument.createTextNode(String(text ?? ""));
                    node.ownerDocument = parsedDoc;
                    return node;
                  },
                  createComment(text) {
                    const node = typeof targetDocument.createComment === "function"
                      ? targetDocument.createComment(String(text ?? ""))
                      : { nodeType: 8, nodeName: "#comment", textContent: String(text ?? "") };
                    node.ownerDocument = parsedDoc;
                    return node;
                  },
                  createDocumentFragment() {
                    const node = targetDocument.createDocumentFragment();
                    node.ownerDocument = parsedDoc;
                    return node;
                  },
                  getElementById(id) {
                    return this.querySelector("#" + String(id));
                  },
                  querySelector(selector) {
                    return this.documentElement && typeof this.documentElement.querySelector === "function"
                      ? this.documentElement.querySelector(selector)
                      : null;
                  },
                  querySelectorAll(selector) {
                    return this.documentElement && typeof this.documentElement.querySelectorAll === "function"
                      ? this.documentElement.querySelectorAll(selector)
                      : [];
                  },
                  getElementsByTagName(tag) {
                    return this.documentElement && typeof this.documentElement.getElementsByTagName === "function"
                      ? this.documentElement.getElementsByTagName(tag)
                      : [];
                  },
                };
                Object.defineProperty(parsedDoc, "childNodes", {
                  configurable: true,
                  enumerable: true,
                  get() {
                    return [this.doctype, this.documentElement].filter(Boolean);
                  },
                });
                Object.defineProperty(parsedDoc, "scrollingElement", {
                  configurable: true,
                  enumerable: true,
                  get() {
                    return this.documentElement || this.body || null;
                  },
                });
                const html = parsedDoc.createElement("html");
                const head = parsedDoc.createElement("head");
                const body = parsedDoc.createElement("body");
                html.appendChild(head);
                html.appendChild(body);
                parsedDoc.documentElement = html;
                parsedDoc.head = head;
                parsedDoc.body = body;
                parsedDoc.activeElement = body;

                const assignOwner = (node) => {
                  if (!node || typeof node !== "object") return;
                  node.ownerDocument = parsedDoc;
                  const children = node.childNodes || node._children || [];
                  for (const child of Array.from(children)) assignOwner(child);
                };
                const copyAttributes = (from, to) => {
                  const attrs = from && from._attrs ? from._attrs : {};
                  for (const [name, value] of Object.entries(attrs)) {
                    if (typeof to.setAttribute === "function") to.setAttribute(name, value);
                  }
                };
                const moveChildren = (from, to) => {
                  for (const child of Array.from(from && from.childNodes || [])) {
                    to.appendChild(child);
                    assignOwner(child);
                  }
                };
                const container = parsedDoc.createElement("div");
                if (normalizedType === "text/html") {
                  container.innerHTML = String(markup ?? "");
                } else {
                  container.textContent = String(markup ?? "");
                }
                const nodes = Array.from(container.childNodes || []);
                const htmlNode = nodes.find((node) => node && node.tagName === "HTML") || null;
                if (htmlNode) {
                  copyAttributes(htmlNode, html);
                  for (const child of Array.from(htmlNode.childNodes || [])) {
                    if (child && child.tagName === "HEAD") {
                      moveChildren(child, head);
                    } else if (child && child.tagName === "BODY") {
                      copyAttributes(child, body);
                      moveChildren(child, body);
                    } else {
                      body.appendChild(child);
                      assignOwner(child);
                    }
                  }
                } else {
                  for (const node of nodes) {
                    if (node && node.tagName === "HEAD") {
                      moveChildren(node, head);
                    } else if (node && node.tagName === "BODY") {
                      copyAttributes(node, body);
                      moveChildren(node, body);
                    } else {
                      body.appendChild(node);
                      assignOwner(node);
                    }
                  }
                }
                return parsedDoc;
              }
            }
            globalThis.DOMParser = CraterDOMParser;
          }
          host.DOMParser = globalThis.DOMParser;

          const installPageConsole = (target) => {
            if (!target || typeof target !== "object") return;
            const entries = Array.isArray(globalThis.__craterAsyncConsoleEntries)
              ? globalThis.__craterAsyncConsoleEntries
              : [];
            globalThis.__craterAsyncConsoleEntries = entries;
            const textOf = (arg) => {
              if (typeof arg === "string") return arg.length > 512 ? arg.slice(0, 512) + "..." : arg;
              if (arg === undefined) return "undefined";
              if (arg === null) return "null";
              if (typeof arg === "number" || typeof arg === "boolean" || typeof arg === "bigint") return String(arg);
              const tag = Object.prototype.toString.call(arg);
              return tag === "[object Object]" ? "[object Object]" : tag;
            };
            const push = (level, method, args) => {
              entries.push({
                level,
                method,
                text: Array.from(args).map(textOf).join(" "),
                timestamp: Date.now(),
              });
              if (entries.length > 200) entries.splice(0, entries.length - 200);
            };
            const pageConsole = {
              log: (...args) => push("info", "log", args),
              warn: (...args) => push("warn", "warn", args),
              error: (...args) => push("error", "error", args),
              info: (...args) => push("info", "info", args),
              debug: (...args) => push("debug", "debug", args),
              table: (...args) => push("info", "table", args),
              trace: (...args) => push("debug", "trace", args),
              assert: (...args) => {
                if (args.length > 0 && args[0]) return;
                push("error", "assert", args.length > 1 ? args.slice(1) : ["Assertion failed"]);
              },
              time: () => {},
              timeEnd: (...args) => push("info", "timeEnd", args.length > 0 ? args : ["default"]),
            };
            globalThis.console = pageConsole;
            target.console = pageConsole;
          };
          installPageConsole(host);

          const cssEscape = (value) => {
            const input = String(value);
            const escapePrefix = String.fromCharCode(92);
            return input.replace(/[\\0-\\x1f\\x7f]|^-?\\d|^-$|[^\\w-]/gu, (match) => {
              if (match.charCodeAt(0) === 0) return "\\uFFFD";
              if (/^-?\\d/u.test(match)) {
                return match.replace(/\\d/u, (digit) => escapePrefix + digit + " ");
              }
              return escapePrefix + match;
            });
          };
          const installCssObject = (target) => {
            if (!target || typeof target !== "object") return null;
            const css = target.CSS && typeof target.CSS === "object"
              ? target.CSS
              : (globalThis.CSS && typeof globalThis.CSS === "object" ? globalThis.CSS : {});
            css.supports = function(property, value) {
              const source = arguments.length > 1
                ? String(property) + ": " + String(value)
                : String(property || "");
              const normalized = source.trim().toLowerCase();
              if (!normalized) return false;
              if (
                normalized.includes("animation-timeline") ||
                normalized.includes("scroll-timeline") ||
                normalized.includes("view-timeline") ||
                normalized.includes("timeline-scope")
              ) {
                return true;
              }
              if (arguments.length > 1) {
                return String(property || "").trim().length > 0 && String(value || "").trim().length > 0;
              }
              return normalized.includes(":");
            };
            css.escape = cssEscape;
            target.CSS = css;
            return css;
          };
          const cssObject = installCssObject(host) || {};
          globalThis.CSS = cssObject;
          host.CSS = cssObject;

          const elementTagName = (value) =>
            String(value && (value.tagName || value.localName || value.nodeName || "")).toUpperCase();
          const isSvgElement = (value) =>
            Boolean(value && value.nodeType === 1 && value.namespaceURI === "http://www.w3.org/2000/svg");
          const installHTMLElementConstructor = () => {
            const ctor = function HTMLElement() {
              const docForElement = globalThis.document || targetDocument;
              if (!docForElement || typeof docForElement.createElement !== "function") return;
              try {
                const element = docForElement.createElement("div");
                Object.defineProperties(this, Object.getOwnPropertyDescriptors(element));
              } catch (_error) {}
            };
            Object.defineProperty(ctor, "name", {
              configurable: true,
              value: "HTMLElement",
            });
            Object.defineProperty(ctor, Symbol.hasInstance, {
              configurable: true,
              value: (value) => Boolean(value && value.nodeType === 1),
            });
            globalThis.HTMLElement = ctor;
            host.HTMLElement = ctor;
          };
          const installInstanceConstructor = (name, predicate) => {
            const ctor = function() {
              throw new TypeError("Illegal constructor");
            };
            Object.defineProperty(ctor, "name", {
              configurable: true,
              value: name,
            });
            Object.defineProperty(ctor, Symbol.hasInstance, {
              configurable: true,
              value: predicate,
            });
            globalThis[name] = ctor;
            host[name] = ctor;
          };
          const installNodeConstructor = () => {
            const ctor = function Node() {
              throw new TypeError("Illegal constructor");
            };
            Object.defineProperty(ctor, "name", {
              configurable: true,
              value: "Node",
            });
            Object.defineProperty(ctor, Symbol.hasInstance, {
              configurable: true,
              value: (value) => Boolean(value && typeof value.nodeType === "number"),
            });
            const constants = {
              ELEMENT_NODE: 1,
              ATTRIBUTE_NODE: 2,
              TEXT_NODE: 3,
              CDATA_SECTION_NODE: 4,
              ENTITY_REFERENCE_NODE: 5,
              ENTITY_NODE: 6,
              PROCESSING_INSTRUCTION_NODE: 7,
              COMMENT_NODE: 8,
              DOCUMENT_NODE: 9,
              DOCUMENT_TYPE_NODE: 10,
              DOCUMENT_FRAGMENT_NODE: 11,
              NOTATION_NODE: 12,
            };
            for (const [name, value] of Object.entries(constants)) {
              Object.defineProperty(ctor, name, {
                configurable: true,
                enumerable: true,
                value,
              });
              Object.defineProperty(ctor.prototype, name, {
                configurable: true,
                enumerable: true,
                value,
              });
            }
            globalThis.Node = ctor;
            host.Node = ctor;
          };
          installNodeConstructor();
          installInstanceConstructor("Element", (value) => Boolean(value && value.nodeType === 1));
          installInstanceConstructor("Document", (value) => Boolean(value && value.nodeType === 9));
          installInstanceConstructor("Text", (value) => Boolean(value && value.nodeType === 3));
          installInstanceConstructor("Comment", (value) => Boolean(value && value.nodeType === 8));
          installHTMLElementConstructor();
          installInstanceConstructor("HTMLInputElement", (value) => elementTagName(value) === "INPUT");
          installInstanceConstructor("HTMLSelectElement", (value) => elementTagName(value) === "SELECT");
          installInstanceConstructor("HTMLTextAreaElement", (value) => elementTagName(value) === "TEXTAREA");
          installInstanceConstructor("HTMLDialogElement", (value) => elementTagName(value) === "DIALOG");
          installInstanceConstructor("HTMLImageElement", (value) => elementTagName(value) === "IMG");
          installInstanceConstructor("HTMLMediaElement", (value) => {
            const tagName = elementTagName(value);
            return tagName === "AUDIO" || tagName === "VIDEO";
          });
          installInstanceConstructor("HTMLAudioElement", (value) => elementTagName(value) === "AUDIO");
          installInstanceConstructor("HTMLVideoElement", (value) => elementTagName(value) === "VIDEO");
          installInstanceConstructor("SVGElement", isSvgElement);
          installInstanceConstructor("SVGSVGElement", (value) => isSvgElement(value) && elementTagName(value) === "SVG");
          installInstanceConstructor("SVGPathElement", (value) => isSvgElement(value) && elementTagName(value) === "PATH");

          const installCustomElementRegistry = () => {
            const existingRegistry = globalThis.customElements && typeof globalThis.customElements === "object"
              ? globalThis.customElements
              : null;
            const definitionsByName = existingRegistry && existingRegistry.__craterDefinitionsByName instanceof Map
              ? existingRegistry.__craterDefinitionsByName
              : new Map();
            const namesByConstructor = existingRegistry && existingRegistry.__craterNamesByConstructor instanceof Map
              ? existingRegistry.__craterNamesByConstructor
              : new Map();
            const whenDefinedWaiters = existingRegistry && existingRegistry.__craterWhenDefinedWaiters instanceof Map
              ? existingRegistry.__craterWhenDefinedWaiters
              : new Map();
            const normalizeCustomElementName = (name) => String(name || "").toLowerCase();
            const isValidCustomElementName = (name) => /^[a-z][.0-9_a-z-]*-[.0-9_a-z-]*$/u.test(name);
            const elementLocalName = (element) =>
              String(element && (element.localName || element.tagName || element.nodeName || "")).toLowerCase();
            const childNodesOf = (node) => Array.from(
              node && (node.childNodes || node.children || node._children) || [],
            );
            const isConnectedForLifecycle = (node) => {
              let current = node;
              while (current) {
                if (current === targetDocument) return true;
                if (current === targetDocument.documentElement) return true;
                current = current.parentNode || current.parentElement || current.host || null;
              }
              return false;
            };
            const readAttribute = (element, name) => {
              if (!element || typeof element !== "object") return null;
              if (typeof element.getAttribute === "function") {
                const value = element.getAttribute(name);
                return value === undefined ? null : value;
              }
              const attrs = element._attrs || element.attributes || {};
              const value = attrs[name];
              return value === undefined ? null : String(value);
            };
            const installConstructorInstanceCheck = (ctor, definition) => {
              try {
                Object.defineProperty(ctor, Symbol.hasInstance, {
                  configurable: true,
                  value(value) {
                    return Boolean(value && value.__craterCustomElementDefinition === definition);
                  },
                });
              } catch (_error) {}
            };
            const installPrototypeMembers = (element, definition) => {
              const prototype = definition.ctor && definition.ctor.prototype;
              if (!prototype || typeof prototype !== "object") return;
              const descriptors = Object.getOwnPropertyDescriptors(prototype);
              for (const [name, descriptor] of Object.entries(descriptors)) {
                if (name === "constructor") continue;
                const nextDescriptor = Object.prototype.hasOwnProperty.call(descriptor, "value")
                  ? {
                    configurable: descriptor.configurable,
                    enumerable: descriptor.enumerable,
                    value: descriptor.value,
                    writable: descriptor.writable,
                  }
                  : {
                    configurable: descriptor.configurable,
                    enumerable: descriptor.enumerable,
                    get: descriptor.get,
                    set: descriptor.set,
                  };
                try {
                  Object.defineProperty(element, name, nextDescriptor);
                } catch (_error) {}
              }
            };
            const callConnected = (element) => {
              const definition = element && element.__craterCustomElementDefinition;
              if (!definition || element.__craterCustomElementConnected) return;
              if (!isConnectedForLifecycle(element)) return;
              element.__craterCustomElementConnected = true;
              const callback = definition.callbacks.connected;
              if (typeof callback === "function") callback.call(element);
            };
            const callDisconnected = (element) => {
              const definition = element && element.__craterCustomElementDefinition;
              if (!definition || !element.__craterCustomElementConnected) return;
              element.__craterCustomElementConnected = false;
              const callback = definition.callbacks.disconnected;
              if (typeof callback === "function") callback.call(element);
            };
            const callAttributeChanged = (element, name, oldValue, newValue) => {
              const definition = element && element.__craterCustomElementDefinition;
              if (!definition || oldValue === newValue) return;
              const normalizedName = String(name || "").toLowerCase();
              if (!definition.observedAttributes.includes(normalizedName)) return;
              const callback = definition.callbacks.attributeChanged;
              if (typeof callback === "function") {
                callback.call(element, normalizedName, oldValue, newValue);
              }
            };
            const patchCustomElementNode = (node) => {
              if (!node || typeof node !== "object" || node.__craterCustomElementPatched) return;
              node.__craterCustomElementPatched = true;
              if (node.nodeType !== 9 && !node.__craterIsConnectedPatched) {
                try {
                  Object.defineProperty(node, "isConnected", {
                    configurable: true,
                    enumerable: true,
                    get() {
                      return isConnectedForLifecycle(this);
                    },
                  });
                  node.__craterIsConnectedPatched = true;
                } catch (_error) {}
              }
              if (typeof node.setAttribute === "function") {
                const originalSetAttribute = node.setAttribute;
                node.setAttribute = function(name, value) {
                  const normalizedName = String(name || "").toLowerCase();
                  const oldValue = readAttribute(this, normalizedName);
                  const result = originalSetAttribute.call(this, name, value);
                  callAttributeChanged(this, normalizedName, oldValue, readAttribute(this, normalizedName));
                  return result;
                };
              }
              if (typeof node.removeAttribute === "function") {
                const originalRemoveAttribute = node.removeAttribute;
                node.removeAttribute = function(name) {
                  const normalizedName = String(name || "").toLowerCase();
                  const oldValue = readAttribute(this, normalizedName);
                  const result = originalRemoveAttribute.call(this, name);
                  callAttributeChanged(this, normalizedName, oldValue, null);
                  return result;
                };
              }
              if (typeof node.appendChild === "function") {
                const originalAppendChild = node.appendChild;
                node.appendChild = function(child) {
                  const result = originalAppendChild.call(this, child);
                  patchCustomElementTree(child);
                  upgradeCustomElementTree(child);
                  if (isConnectedForLifecycle(this)) connectCustomElementTree(child);
                  return result;
                };
              }
              if (typeof node.insertBefore === "function") {
                const originalInsertBefore = node.insertBefore;
                node.insertBefore = function(child, reference) {
                  const result = originalInsertBefore.call(this, child, reference);
                  patchCustomElementTree(child);
                  upgradeCustomElementTree(child);
                  if (isConnectedForLifecycle(this)) connectCustomElementTree(child);
                  return result;
                };
              }
              if (typeof node.removeChild === "function") {
                const originalRemoveChild = node.removeChild;
                node.removeChild = function(child) {
                  const wasConnected = isConnectedForLifecycle(child);
                  const result = originalRemoveChild.call(this, child);
                  if (wasConnected) disconnectCustomElementTree(child);
                  return result;
                };
              }
              if (typeof node.replaceChild === "function") {
                const originalReplaceChild = node.replaceChild;
                node.replaceChild = function(child, oldChild) {
                  const oldWasConnected = isConnectedForLifecycle(oldChild);
                  const result = originalReplaceChild.call(this, child, oldChild);
                  if (oldWasConnected) disconnectCustomElementTree(oldChild);
                  patchCustomElementTree(child);
                  upgradeCustomElementTree(child);
                  if (isConnectedForLifecycle(this)) connectCustomElementTree(child);
                  return result;
                };
              }
            };
            const patchCustomElementTree = (root) => {
              if (!root || typeof root !== "object") return;
              patchCustomElementNode(root);
              for (const child of childNodesOf(root)) patchCustomElementTree(child);
              if (root.shadowRoot) patchCustomElementTree(root.shadowRoot);
            };
            const definitionForElement = (element) => {
              if (!element || element.nodeType !== 1) return null;
              return definitionsByName.get(elementLocalName(element)) || null;
            };
            const upgradeCustomElement = (element) => {
              const definition = definitionForElement(element);
              if (!definition || element.__craterCustomElementDefinition === definition) return;
              patchCustomElementNode(element);
              installPrototypeMembers(element, definition);
              element.__craterCustomElementDefinition = definition;
              element.__craterCustomElementName = definition.name;
              for (const attrName of definition.observedAttributes) {
                const value = readAttribute(element, attrName);
                if (value !== null) callAttributeChanged(element, attrName, null, value);
              }
              callConnected(element);
            };
            const upgradeCustomElementTree = (root) => {
              if (!root || typeof root !== "object") return;
              upgradeCustomElement(root);
              for (const child of childNodesOf(root)) upgradeCustomElementTree(child);
              if (root.shadowRoot) upgradeCustomElementTree(root.shadowRoot);
            };
            const connectCustomElementTree = (root) => {
              if (!root || typeof root !== "object") return;
              callConnected(root);
              for (const child of childNodesOf(root)) connectCustomElementTree(child);
              if (root.shadowRoot) connectCustomElementTree(root.shadowRoot);
            };
            const disconnectCustomElementTree = (root) => {
              if (!root || typeof root !== "object") return;
              callDisconnected(root);
              for (const child of childNodesOf(root)) disconnectCustomElementTree(child);
              if (root.shadowRoot) disconnectCustomElementTree(root.shadowRoot);
            };
            class CraterCustomElementRegistry {
              define(name, ctor, options) {
                const normalizedName = normalizeCustomElementName(name);
                if (!isValidCustomElementName(normalizedName)) {
                  throw new DOMException(
                    "Failed to execute 'define' on 'CustomElementRegistry': invalid custom element name",
                    "SyntaxError",
                  );
                }
                if (options && options.extends !== undefined) {
                  throw new DOMException(
                    "Failed to execute 'define' on 'CustomElementRegistry': customized built-in elements are not supported",
                    "NotSupportedError",
                  );
                }
                if (typeof ctor !== "function") {
                  throw new TypeError("Custom element constructor must be a function");
                }
                if (definitionsByName.has(normalizedName)) {
                  throw new DOMException(
                    "Failed to execute 'define' on 'CustomElementRegistry': the name has already been used",
                    "NotSupportedError",
                  );
                }
                if (namesByConstructor.has(ctor)) {
                  throw new DOMException(
                    "Failed to execute 'define' on 'CustomElementRegistry': the constructor has already been used",
                    "NotSupportedError",
                  );
                }
                const prototype = ctor.prototype || {};
                const callbacks = {
                  connected: typeof prototype.connectedCallback === "function" ? prototype.connectedCallback : null,
                  disconnected: typeof prototype.disconnectedCallback === "function" ? prototype.disconnectedCallback : null,
                  attributeChanged: typeof prototype.attributeChangedCallback === "function"
                    ? prototype.attributeChangedCallback
                    : null,
                };
                const observedAttributes = callbacks.attributeChanged
                  ? Array.from(ctor.observedAttributes || []).map((attr) => String(attr).toLowerCase())
                  : [];
                const definition = {
                  name: normalizedName,
                  ctor,
                  callbacks,
                  observedAttributes,
                };
                installConstructorInstanceCheck(ctor, definition);
                definitionsByName.set(normalizedName, definition);
                namesByConstructor.set(ctor, normalizedName);
                const waiters = whenDefinedWaiters.get(normalizedName) || [];
                whenDefinedWaiters.delete(normalizedName);
                for (const resolve of waiters) resolve(ctor);
                upgradeCustomElementTree(targetDocument.documentElement);
                upgradeCustomElementTree(targetDocument.body);
              }
              get(name) {
                const definition = definitionsByName.get(normalizeCustomElementName(name));
                return definition ? definition.ctor : undefined;
              }
              getName(ctor) {
                return namesByConstructor.get(ctor);
              }
              whenDefined(name) {
                const normalizedName = normalizeCustomElementName(name);
                if (!isValidCustomElementName(normalizedName)) {
                  return Promise.reject(new DOMException(
                    "Failed to execute 'whenDefined' on 'CustomElementRegistry': invalid custom element name",
                    "SyntaxError",
                  ));
                }
                const definition = definitionsByName.get(normalizedName);
                if (definition) return Promise.resolve(definition.ctor);
                return new Promise((resolve) => {
                  const waiters = whenDefinedWaiters.get(normalizedName) || [];
                  waiters.push(resolve);
                  whenDefinedWaiters.set(normalizedName, waiters);
                });
              }
              upgrade(root) {
                patchCustomElementTree(root);
                upgradeCustomElementTree(root);
              }
            }
            const registry = new CraterCustomElementRegistry();
            registry.__craterDefinitionsByName = definitionsByName;
            registry.__craterNamesByConstructor = namesByConstructor;
            registry.__craterWhenDefinedWaiters = whenDefinedWaiters;
            globalThis.customElements = registry;
            host.customElements = registry;
            globalThis.CustomElementRegistry = CraterCustomElementRegistry;
            host.CustomElementRegistry = CraterCustomElementRegistry;
            if (typeof targetDocument.createElement === "function" && !targetDocument.__craterCustomElementCreateWrapped) {
              const originalCreateElement = targetDocument.createElement;
              targetDocument.createElement = function(tagName) {
                const element = originalCreateElement.apply(this, arguments);
                patchCustomElementTree(element);
                upgradeCustomElementTree(element);
                return element;
              };
              targetDocument.__craterCustomElementCreateWrapped = true;
            }
            patchCustomElementTree(targetDocument.documentElement);
            patchCustomElementTree(targetDocument.body);
            upgradeCustomElementTree(targetDocument.documentElement);
            upgradeCustomElementTree(targetDocument.body);
          };
          installCustomElementRegistry();

          const numberOr = (value, fallback) => {
            const num = Number(value);
            return Number.isFinite(num) ? num : fallback;
          };
          const px = (value) => {
            const parsed = Number.parseFloat(String(value ?? ""));
            return Number.isFinite(parsed) ? parsed : 0;
          };
          const currentScrollLeft = () => numberOr(host.scrollX ?? globalThis.scrollX ?? host.pageXOffset ?? globalThis.pageXOffset, 0);
          const currentScrollTop = () => numberOr(host.scrollY ?? globalThis.scrollY ?? host.pageYOffset ?? globalThis.pageYOffset, 0);
          const rootScroller = () =>
            targetDocument.scrollingElement || targetDocument.documentElement || targetDocument.body || null;
          const dispatchScrollEvent = (target) => {
            if (!target || typeof target.dispatchEvent !== "function") return;
            const createEvent = globalThis.__bidiCreateEvent;
            const event = typeof createEvent === "function"
              ? createEvent("scroll", { bubbles: false, cancelable: false })
              : { type: "scroll", bubbles: false, cancelable: false };
            try { target.dispatchEvent(event); } catch (_error) {}
          };
          const setViewportScroll = (left, top) => {
            const nextLeft = Math.max(0, numberOr(left, currentScrollLeft()));
            const nextTop = Math.max(0, numberOr(top, currentScrollTop()));
            host.scrollX = nextLeft;
            host.scrollY = nextTop;
            host.pageXOffset = nextLeft;
            host.pageYOffset = nextTop;
            globalThis.scrollX = nextLeft;
            globalThis.scrollY = nextTop;
            globalThis.pageXOffset = nextLeft;
            globalThis.pageYOffset = nextTop;
            const scroller = rootScroller();
            if (scroller) {
              scroller.scrollLeft = nextLeft;
              scroller.scrollTop = nextTop;
            }
            dispatchScrollEvent(host);
          };
          const scrollArgs = (first, second, currentLeft, currentTop) => {
            if (first && typeof first === "object") {
              return {
                left: first.left === undefined ? currentLeft : numberOr(first.left, currentLeft),
                top: first.top === undefined ? currentTop : numberOr(first.top, currentTop),
              };
            }
            return {
              left: numberOr(first, currentLeft),
              top: numberOr(second, currentTop),
            };
          };
          const childrenOf = (element) => {
            if (!element) return [];
            if (Array.isArray(element._children)) return element._children;
            try { return Array.from(element.children || element.childNodes || []); } catch (_error) { return []; }
          };
          const readStyleValue = (element, property) => {
            if (!element) return "";
            const dashed = String(property || "").replace(/[A-Z]/g, (ch) => "-" + ch.toLowerCase());
            const camel = dashed.replace(/-([a-z])/g, (_, ch) => ch.toUpperCase());
            const sources = [element.style, element._style];
            for (const style of sources) {
              if (!style) continue;
              if (typeof style.getPropertyValue === "function") {
                const value = style.getPropertyValue(dashed);
                if (value !== undefined && value !== null && String(value) !== "") return String(value);
              }
              const camelValue = style[camel];
              if (camelValue !== undefined && camelValue !== null && String(camelValue) !== "") return String(camelValue);
              const dashedValue = style[dashed];
              if (dashedValue !== undefined && dashedValue !== null && String(dashedValue) !== "") return String(dashedValue);
            }
            return "";
          };
          const attrNumber = (element, name) => {
            if (!element) return 0;
            let value = "";
            try {
              value = typeof element.getAttribute === "function" ? element.getAttribute(name) || "" : "";
            } catch (_error) {}
            if (!value && element._attrs) value = element._attrs[name] || "";
            return px(value);
          };
          const elementOwnMetrics = (element) => {
            const tagName = elementTagName(element);
            if (tagName === "SCRIPT" || tagName === "STYLE" || tagName === "LINK" ||
              tagName === "META" || tagName === "TITLE" || tagName === "HEAD") {
              return { width: 0, height: 0 };
            }
            let width = px(readStyleValue(element, "width")) ||
              attrNumber(element, "width") ||
              numberOr(element && element.width, 0);
            let height = px(readStyleValue(element, "height")) ||
              attrNumber(element, "height") ||
              numberOr(element && element.height, 0);
            if (typeof element?.getBoundingClientRect === "function") {
              try {
                const rect = element.getBoundingClientRect();
                width = Math.max(width, numberOr(rect?.width, 0));
                height = Math.max(height, numberOr(rect?.height, 0));
              } catch (_error) {}
            }
            if (tagName === "HTML" || tagName === "BODY") {
              width = Math.max(width, numberOr(host.innerWidth ?? globalThis.innerWidth, 1));
              height = Math.max(height, numberOr(host.innerHeight ?? globalThis.innerHeight, 1));
            }
            return { width: Math.max(0, width), height: Math.max(0, height) };
          };
          const estimateFlowMetrics = (element, seen) => {
            if (!element || seen.has(element)) return { width: 0, height: 0 };
            seen.add(element);
            const own = elementOwnMetrics(element);
            let width = own.width;
            let height = own.height;
            let flowBottom = 0;
            for (const child of childrenOf(element)) {
              if (!child || child.nodeType !== 1) continue;
              const childMetrics = estimateFlowMetrics(child, seen);
              const position = readStyleValue(child, "position").toLowerCase();
              const hasExplicitTop = readStyleValue(child, "top") !== "" || readStyleValue(child, "bottom") !== "";
              const childLeft = px(readStyleValue(child, "left")) + px(readStyleValue(child, "marginLeft"));
              const marginTop = px(readStyleValue(child, "marginTop"));
              const marginBottom = px(readStyleValue(child, "marginBottom"));
              width = Math.max(width, childLeft + childMetrics.width);
              if (position === "absolute" || position === "fixed" || hasExplicitTop) {
                const childTop = px(readStyleValue(child, "top")) + marginTop;
                height = Math.max(height, childTop + childMetrics.height + marginBottom);
              } else {
                flowBottom += marginTop;
                height = Math.max(height, flowBottom + childMetrics.height);
                flowBottom += childMetrics.height + marginBottom;
              }
            }
            return {
              width: Math.max(1, width),
              height: Math.max(1, height),
            };
          };
          const installMetricAccessors = (element) => {
            if (!element || element.__craterMetricAccessorsInstalled) return;
            const defineMetric = (name, getter) => {
              try {
                Object.defineProperty(element, name, {
                  configurable: true,
                  enumerable: true,
                  get: getter,
                });
              } catch (_error) {}
            };
            defineMetric("scrollWidth", function() {
              return Math.max(1, Math.ceil(estimateFlowMetrics(this, new Set()).width));
            });
            defineMetric("scrollHeight", function() {
              return Math.max(1, Math.ceil(estimateFlowMetrics(this, new Set()).height));
            });
            element.__craterMetricAccessorsInstalled = true;
          };
          const scrollTo = function(first, second) {
            const next = scrollArgs(first, second, currentScrollLeft(), currentScrollTop());
            setViewportScroll(next.left, next.top);
          };
          const scrollBy = function(first, second) {
            const currentLeft = currentScrollLeft();
            const currentTop = currentScrollTop();
            const delta = scrollArgs(first, second, 0, 0);
            setViewportScroll(currentLeft + delta.left, currentTop + delta.top);
          };
          host.scrollTo = scrollTo;
          host.scrollBy = scrollBy;
          globalThis.scrollTo = scrollTo;
          globalThis.scrollBy = scrollBy;

          const setElementStyle = (element, property, value) => {
            if (!element) return;
            const trimmedProperty = String(property || "").trim();
            if (!trimmedProperty) return;
            const trimmedValue = String(value || "").replace(/!important\\b/g, "").trim();
            if (!element._style) element._style = {};
            const camelProperty = trimmedProperty.replace(/-([a-z])/g, (_, ch) => ch.toUpperCase());
            element._style[trimmedProperty] = trimmedValue;
            element._style[camelProperty] = trimmedValue;
            if (element.style) {
              try { element.style[trimmedProperty] = trimmedValue; } catch (_error) {}
              try { element.style[camelProperty] = trimmedValue; } catch (_error) {}
            }
          };
          const applyStyleText = (cssText) => {
            const source = String(cssText || "").replace(/\\/\\*[\\s\\S]*?\\*\\//g, "");
            const ruleRegex = /([^{}]+)\\{([^{}]+)\\}/g;
            let match;
            while ((match = ruleRegex.exec(source))) {
              const selectors = match[1].split(",").map((part) => part.trim()).filter(Boolean);
              const declarations = match[2].split(";")
                .map((part) => part.trim())
                .filter(Boolean)
                .map((part) => {
                  const colon = part.indexOf(":");
                  if (colon < 0) return null;
                  return [part.slice(0, colon).trim(), part.slice(colon + 1).trim()];
                })
                .filter(Boolean);
              for (const selector of selectors) {
                let elements = [];
                try {
                  elements = Array.from(targetDocument.querySelectorAll(selector) || []);
                } catch (_error) {
                  continue;
                }
                for (const element of elements) {
                  for (const [property, value] of declarations) {
                    setElementStyle(element, property, value);
                  }
                }
              }
            }
          };
          globalThis.__craterApplyStyleText = applyStyleText;
          host.__craterApplyStyleText = applyStyleText;
          const applyStyleElement = (element) => {
            if (elementTagName(element) !== "STYLE") return;
            applyStyleText(element.textContent || "");
          };
          const imageElements = () => {
            const nodes = typeof targetDocument.getElementsByTagName === "function"
              ? Array.from(targetDocument.getElementsByTagName("img") || [])
              : Array.from(targetDocument.querySelectorAll ? targetDocument.querySelectorAll("img") : []);
            nodes.item = function(index) {
              return this[index] || null;
            };
            return nodes;
          };
          if (!targetDocument.__craterImagesPatched) {
            Object.defineProperty(targetDocument, "images", {
              configurable: true,
              enumerable: true,
              get: imageElements,
            });
            targetDocument.__craterImagesPatched = true;
          }
          const dispatchImageLoad = (element) => {
            Promise.resolve().then(() => {
              if (!element || typeof element.dispatchEvent !== "function") return;
              const createEvent = globalThis.__bidiCreateEvent;
              const event = typeof createEvent === "function"
                ? createEvent("load", { bubbles: false, cancelable: false })
                : { type: "load", bubbles: false, cancelable: false };
              try { element.dispatchEvent(event); } catch (_error) {}
              if (typeof element.onload === "function") {
                try { element.onload.call(element, event); } catch (_error) {}
              }
            });
          };
          const resolveImageRequestUrl = (value) => {
            const raw = String(value || "");
            if (!raw || raw.startsWith("data:") || raw.startsWith("blob:") || raw.startsWith("about:")) return "";
            const base = host.__pageUrl || globalThis.__pageUrl ||
              (host.location && host.location.href) ||
              (globalThis.location && globalThis.location.href) ||
              "about:blank";
            if (globalThis.__resolveUrl) return globalThis.__resolveUrl(raw, base);
            try { return new URL(raw, base).href; } catch (_error) { return raw; }
          };
          const fetchImageResource = (value) => {
            const resourceUrl = resolveImageRequestUrl(value);
            if (!resourceUrl) return;
            Promise.resolve().then(async () => {
              const fetchFn = globalThis.__craterObservableFetch || globalThis.__fetchInternal || globalThis.fetch;
              if (typeof fetchFn !== "function") return;
              try {
                const response = await fetchFn(resourceUrl, {});
                if (response && typeof response.arrayBuffer === "function") {
                  try { await response.arrayBuffer(); } catch (_error) {}
                }
              } catch (_error) {}
            });
          };
          const handleImageSourceMutation = (element, value) => {
            fetchImageResource(value);
            dispatchImageLoad(element);
          };
          const patchImageElement = (element) => {
            const tagName = String(element && (element.tagName || element.localName || "")).toUpperCase();
            if (tagName !== "IMG" || element.__craterImagePatched) return;
            element.__craterImagePatched = true;
            if (typeof element.setAttribute === "function" && !element.__craterImageSetAttributeWrapped) {
              const originalSetAttribute = element.setAttribute;
              element.setAttribute = function(name, value) {
                const result = originalSetAttribute.call(this, name, value);
                if (String(name || "").toLowerCase() === "src") {
                  handleImageSourceMutation(this, value);
                }
                return result;
              };
              element.__craterImageSetAttributeWrapped = true;
            }
            Object.defineProperty(element, "complete", {
              configurable: true,
              enumerable: true,
              get() {
                return true;
              },
            });
            Object.defineProperty(element, "loading", {
              configurable: true,
              enumerable: true,
              get() {
                return typeof this.getAttribute === "function" ? this.getAttribute("loading") || "" : "";
              },
              set(value) {
                if (typeof this.setAttribute === "function") this.setAttribute("loading", String(value));
              },
            });
            Object.defineProperty(element, "src", {
              configurable: true,
              enumerable: true,
              get() {
                return typeof this.getAttribute === "function" ? this.getAttribute("src") || "" : "";
              },
              set(value) {
                if (typeof this.setAttribute === "function") this.setAttribute("src", String(value));
                else handleImageSourceMutation(this, value);
                const nextWidth = Math.max(1, numberOr(this.width ?? this.naturalWidth, 1));
                const nextHeight = Math.max(1, numberOr(this.height ?? this.naturalHeight, 1));
                if (!numberOr(this.width, 0)) this.width = nextWidth;
                if (!numberOr(this.height, 0)) this.height = nextHeight;
                if (!numberOr(this.naturalWidth, 0)) this.naturalWidth = numberOr(this.width, nextWidth);
                if (!numberOr(this.naturalHeight, 0)) this.naturalHeight = numberOr(this.height, nextHeight);
              },
            });
            element.decode = function() {
              return Promise.resolve();
            };
            if (element.naturalWidth === undefined) element.naturalWidth = 0;
            if (element.naturalHeight === undefined) element.naturalHeight = 0;
          };
          if (typeof globalThis.Image !== "function") {
            const ImageConstructor = function Image(width, height) {
              const image = targetDocument.createElement("img");
              patchImageElement(image);
              if (width !== undefined) {
                image.width = Math.max(0, numberOr(width, 0));
                if (typeof image.setAttribute === "function") image.setAttribute("width", String(image.width));
              }
              if (height !== undefined) {
                image.height = Math.max(0, numberOr(height, 0));
                if (typeof image.setAttribute === "function") image.setAttribute("height", String(image.height));
              }
              return image;
            };
            Object.defineProperty(ImageConstructor, "name", {
              configurable: true,
              value: "Image",
            });
            globalThis.Image = ImageConstructor;
          }
          host.Image = globalThis.Image;
          const patchMediaElement = (element) => {
            const tagName = String(element && (element.tagName || element.localName || "")).toUpperCase();
            if ((tagName !== "VIDEO" && tagName !== "AUDIO") || element.__craterMediaPatched) return;
            element.__craterMediaPatched = true;
            element.__craterCurrentTime = numberOr(element.currentTime, 0);
            element.__craterPaused = true;
            Object.defineProperty(element, "currentTime", {
              configurable: true,
              enumerable: true,
              get() {
                return numberOr(this.__craterCurrentTime, 0);
              },
              set(value) {
                this.__craterCurrentTime = Math.max(0, numberOr(value, 0));
              },
            });
            Object.defineProperty(element, "paused", {
              configurable: true,
              enumerable: true,
              get() {
                return this.__craterPaused !== false;
              },
            });
            element.pause = function() {
              this.__craterPaused = true;
              const createEvent = globalThis.__bidiCreateEvent;
              const event = typeof createEvent === "function"
                ? createEvent("pause", { bubbles: false, cancelable: false })
                : { type: "pause", bubbles: false, cancelable: false };
              try { this.dispatchEvent(event); } catch (_error) {}
            };
            element.play = function() {
              this.__craterPaused = false;
              return Promise.resolve();
            };
          };
          const patchElementScrolling = (element) => {
            if (!element || typeof element !== "object" || element.__craterScrollingPatched) return;
            element.__craterScrollingPatched = true;
            installMetricAccessors(element);
            patchImageElement(element);
            patchMediaElement(element);
            applyStyleElement(element);
            if (typeof element.appendChild === "function" && !element.__craterStyleAppendWrapped) {
              const originalAppendChild = element.appendChild;
              element.appendChild = function(child) {
                const result = originalAppendChild.call(this, child);
                patchElementTree(child);
                applyStyleElement(child);
                return result;
              };
              element.__craterStyleAppendWrapped = true;
            }
            if (element.scrollLeft === undefined) element.scrollLeft = 0;
            if (element.scrollTop === undefined) element.scrollTop = 0;
            element.scrollTo = function(first, second) {
              const next = scrollArgs(first, second, numberOr(this.scrollLeft, 0), numberOr(this.scrollTop, 0));
              this.scrollLeft = Math.max(0, next.left);
              this.scrollTop = Math.max(0, next.top);
              dispatchScrollEvent(this);
            };
            element.scrollBy = function(first, second) {
              const currentLeft = numberOr(this.scrollLeft, 0);
              const currentTop = numberOr(this.scrollTop, 0);
              const delta = scrollArgs(first, second, 0, 0);
              this.scrollTo(currentLeft + delta.left, currentTop + delta.top);
            };
            element.scrollIntoView = function() {
              const rect = typeof this.getBoundingClientRect === "function"
                ? this.getBoundingClientRect()
                : { left: 0, top: 0 };
              setViewportScroll(numberOr(rect.left, currentScrollLeft()), numberOr(rect.top, currentScrollTop()));
            };
          };
          const patchElementTree = (root) => {
            if (!root || typeof root !== "object") return;
            patchElementScrolling(root);
            const children = Array.isArray(root._children)
              ? root._children
              : Array.from(root.childNodes || []);
            for (const child of children) {
              patchElementTree(child);
            }
            if (root.shadowRoot) {
              patchElementTree(root.shadowRoot);
            }
          };
          if (typeof targetDocument.createElement === "function" && !targetDocument.__craterScrollCreateElementWrapped) {
            const originalCreateElement = targetDocument.createElement;
            targetDocument.createElement = function(tagName) {
              const element = originalCreateElement.call(this, tagName);
              patchElementScrolling(element);
              return element;
            };
            targetDocument.__craterScrollCreateElementWrapped = true;
          }
          globalThis.__craterInstallScrollingStubs = () => {
            patchElementTree(targetDocument.documentElement);
            patchElementTree(targetDocument.body);
            return true;
          };
          host.__craterInstallScrollingStubs = globalThis.__craterInstallScrollingStubs;
          globalThis.__craterInstallScrollingStubs();
        };

        const html = doc.createElement("html");
        const head = doc.createElement("head");
        const body = doc.createElement("body");
        html.appendChild(head);
        html.appendChild(body);

        const sourceDoctype = sourceDoc.doctype || {};
        const doctype = {
          nodeType: 10,
          nodeName: sourceDoctype.nodeName || "html",
          name: sourceDoctype.name || "html",
          publicId: sourceDoctype.publicId || "",
          systemId: sourceDoctype.systemId || "",
          ownerDocument: doc,
          parentNode: doc,
        };

        doc.doctype = doctype;
        doc.documentElement = html;
        doc.head = head;
        doc.body = body;
        doc.activeElement = body;

        contextWindow.document = doc;
        contextWindow.window = contextWindow;
        globalThis.document = doc;
        globalThis.window = contextWindow;
        globalThis.self = contextWindow;
        globalThis.parent = contextWindow;
        globalThis.top = contextWindow;
        contextWindow.document = doc;
        contextWindow.window.document = doc;
        installCaptureStabilizationStubs(contextWindow, doc);
        return true;
      })()
    `);
  }

  private responseFromLoadResult(
    result: CraterPageLoadResult,
    fallbackUrl: string,
  ): CraterResponse {
    const responseUrl = result.url ?? fallbackUrl;
    const request = {
      id: "crater-goto",
      url: responseUrl,
      method: "GET",
      headers: {},
      postData: null,
    };
    return new CraterResponse({
      url: responseUrl,
      status: result.status ?? 200,
      statusText: result.statusText ?? "",
      headers: { ...(result.headers ?? {}) },
      body: result.body ?? null,
      request,
    });
  }

  private async flushPendingNavigation(): Promise<void> {
    if (this.navigationFlushDepth > 0 || this.closed) {
      return;
    }
    this.navigationFlushDepth += 1;
    try {
      while (true) {
        const raw = await this.evaluate<string | null>(`
          (() => {
            const pending = globalThis.__craterPendingNavigation || null;
            globalThis.__craterPendingNavigation = null;
            return pending ? JSON.stringify(pending) : null;
          })()
        `);
        if (!raw) {
          return;
        }
        const pending = JSON.parse(raw) as { url?: string; urlOnly?: boolean };
        if (!pending.url) {
          continue;
        }
        if (pending.urlOnly) {
          // Synthetic URL update — anchor / form default action recorded
          // a new in-realm location but didn't request a real fetch.
          // Mirror it onto `currentUrl` so `page.url()` reflects the
          // new location without tearing down the document. (#208)
          this.currentUrl = pending.url;
          continue;
        }
        await this.loadPage(pending.url);
      }
    } finally {
      this.navigationFlushDepth -= 1;
    }
  }

  private async syncRuntimeLocation(url: string): Promise<void> {
    this.currentUrl = url;
    await this.evaluate(`
      (() => {
        const next = ${jsString(url)};
        globalThis.__pageUrl = next;
        const location = globalThis.location || {};
        const resolve = (value) => {
          const raw = String(value);
          if (globalThis.__resolveUrl) return globalThis.__resolveUrl(raw, globalThis.__pageUrl || location.href || "about:blank");
          try { return new URL(raw, globalThis.__pageUrl || location.href || "about:blank").href; } catch (_e) { return raw; }
        };
        const applyUrl = (value) => {
          const href = resolve(value);
          let parsed = null;
          try { parsed = new URL(href, location.href || "about:blank"); } catch (_e) {}
          location.href = parsed ? parsed.href : href;
          location.origin = parsed ? parsed.origin : "";
          location.protocol = parsed ? parsed.protocol : "";
          location.host = parsed ? parsed.host : "";
          location.hostname = parsed ? parsed.hostname : "";
          location.port = parsed ? parsed.port : "";
          location.pathname = parsed ? parsed.pathname : "";
          location.search = parsed ? parsed.search : "";
          location.hash = parsed ? parsed.hash : "";
          globalThis.__pageUrl = location.href;
          return location.href;
        };
        const installLocationStringifier = () => {
          const asHref = function() {
            return String(this && this.href ? this.href : globalThis.__pageUrl || "about:blank");
          };
          try {
            Object.defineProperty(location, "toString", {
              configurable: true,
              value: asHref,
            });
          } catch (_e) {
            location.toString = asHref;
          }
          try {
            Object.defineProperty(location, "valueOf", {
              configurable: true,
              value: asHref,
            });
          } catch (_e) {
            location.valueOf = asHref;
          }
          if (typeof Symbol !== "undefined" && Symbol.toPrimitive) {
            try {
              Object.defineProperty(location, Symbol.toPrimitive, {
                configurable: true,
                value: asHref,
              });
            } catch (_e) {}
          }
          if (globalThis.document && typeof globalThis.document === "object") {
            try {
              Object.defineProperty(globalThis.document, "location", {
                configurable: true,
                enumerable: true,
                value: location,
              });
            } catch (_e) {
              globalThis.document.location = location;
            }
          }
        };
        applyUrl(next);
        installLocationStringifier();
        location.assign = function(value) {
          const href = applyUrl(value);
          installLocationStringifier();
          globalThis.__craterPendingNavigation = { url: href, kind: "assign" };
        };
        location.replace = function(value) {
          const href = applyUrl(value);
          installLocationStringifier();
          globalThis.__craterPendingNavigation = { url: href, kind: "replace" };
        };
        location.reload = function() {
          const href = applyUrl(location.href || globalThis.__pageUrl || "about:blank");
          installLocationStringifier();
          globalThis.__craterPendingNavigation = { url: href, kind: "reload" };
        };
        const history = globalThis.history || {};
        if (!Array.isArray(history.__craterEntries)) {
          history.__craterEntries = [location.href];
          history.__craterIndex = 0;
        }
        history.state = history.state ?? null;
        history.pushState = function(state, _title, value) {
          if (value !== undefined && value !== null) {
            const href = applyUrl(value);
            const nextIndex = Number(history.__craterIndex || 0) + 1;
            history.__craterEntries = history.__craterEntries.slice(0, nextIndex);
            history.__craterEntries.push(href);
            history.__craterIndex = nextIndex;
          }
          history.state = state ?? null;
        };
        history.replaceState = function(state, _title, value) {
          if (value !== undefined && value !== null) {
            const href = applyUrl(value);
            const index = Number(history.__craterIndex || 0);
            history.__craterEntries[index] = href;
          }
          history.state = state ?? null;
        };
        history.length = history.__craterEntries.length;
        globalThis.history = history;
        globalThis.location = location;
        if (globalThis.window && typeof globalThis.window === "object") {
          globalThis.window.location = location;
          globalThis.window.history = history;
        }
        installLocationStringifier();
      })()
    `);
  }

  private async refreshCurrentUrl(): Promise<void> {
    if (!this.contextId) {
      return;
    }
    try {
      const resp = await this.sendBidi("script.evaluate", {
        expression: "globalThis.location && globalThis.location.href || globalThis.__pageUrl || 'about:blank'",
        target: { context: this.contextId },
        awaitPromise: false,
      });
      if (resp.type !== "success") {
        return;
      }
      const result = resp.result as { result?: unknown; exceptionDetails?: unknown };
      if (result.exceptionDetails) {
        return;
      }
      const value = deserializeBidiValue(result.result);
      // Skip overwriting `currentUrl` with the in-realm
      // `about:blank` default — the realm starts there for every fresh
      // context and never gets the synthetic post-click URL written
      // back because the click happens in a different context-window
      // instance (see #208 attempt notes). A real navigation calls
      // `syncRuntimeLocation` directly, which sets `currentUrl` ahead
      // of the realm read, so skipping `about:blank` here only loses
      // information when the truth was already `about:blank`.
      if (typeof value === "string" && value && value !== "about:blank") {
        this.currentUrl = value;
      }
    } catch (_error) {}
  }

  async addInitScript(script: CraterInitScript): Promise<void> {
    this.initScripts.push(this.scriptSource(script));
  }

  async addScriptTag(options: CraterAddScriptTagOptions): Promise<CraterLocator> {
    const content = await this.resolveInjectableContent(options, "script");
    await this.evaluate(
      `(async () => {
        const script = document.createElement("script");
        if (${jsString(options.type ?? "")}) script.setAttribute("type", ${jsString(options.type ?? "")});
        if (${jsString(options.url ?? "")}) script.setAttribute("src", ${jsString(options.url ?? "")});
        script.textContent = ${jsString(content)};
        (document.head || document.querySelector("head") || document.body || document.documentElement).appendChild(script);
        (0, eval)(${jsString(content)});
      })()`,
      { awaitPromise: true },
    );
    return this.locator("script").last();
  }

  async addStyleTag(options: CraterAddStyleTagOptions): Promise<CraterLocator> {
    const content = await this.resolveInjectableContent(options, "style");
    await this.evaluate(`
      (() => {
        const style = document.createElement("style");
        if (${jsString(options.url ?? "")}) style.setAttribute("data-crater-source", ${jsString(options.url ?? "")});
        style.textContent = ${jsString(content)};
        (document.head || document.querySelector("head") || document.body || document.documentElement).appendChild(style);
      })()
    `);
    return this.locator("style").last();
  }

  url(): string {
    return this.currentUrl;
  }

  async title(): Promise<string> {
    return this.evaluate<string>(
      "document.title || document.querySelector('title')?.textContent || ''",
    );
  }

  async content(): Promise<string> {
    return this.evaluate<string>(`
      (() => {
        const html = document.documentElement;
        if (!html) return "";
        if (typeof html.outerHTML === "string") return html.outerHTML;
        const head = document.querySelector("head");
        const body = document.body || document.querySelector("body");
        const headHtml = head ? "<head>" + head.innerHTML + "</head>" : "";
        const bodyHtml = body ? "<body>" + body.innerHTML + "</body>" : "";
        return "<html>" + headHtml + bodyHtml + "</html>";
      })()
    `);
  }

  async modelContextTools(): Promise<CraterModelContextToolDescriptor[]> {
    await this.installModelContextRuntime();
    return await this.evaluate<CraterModelContextToolDescriptor[]>(
      "globalThis.__craterListModelContextTools()",
    );
  }

  async callModelContextTool<T = unknown>(name: string, input?: unknown): Promise<T> {
    await this.installModelContextRuntime();
    const envelope = await this.evaluate<CraterModelContextToolCallEnvelope<T>>(
      `(async () => await globalThis.__craterCallModelContextTool(${jsString(name)}, ${jsValue(input)}))()`,
      { awaitPromise: true },
    );
    if (!envelope.ok) {
      const error = new Error(envelope.error.message);
      error.name = envelope.error.name;
      throw error;
    }
    return envelope.value;
  }

  async setViewport(width: number, height: number): Promise<void> {
    await this.sendBidi("browsingContext.setViewport", {
      context: this.requireContextId(),
      viewport: { width, height },
    });
  }

  setDefaultTimeout(timeout: number): void {
    if (!Number.isFinite(timeout) || timeout < 0) {
      throw new Error(`Invalid timeout: ${timeout}`);
    }
    this.defaultTimeout = timeout;
  }

  async evaluate<T, Arg = unknown>(
    expression: string | ((arg: Arg) => T | Promise<T>),
    argOrOptions?: Arg | CraterEvaluateOptions,
    options: CraterEvaluateOptions = {},
  ): Promise<T> {
    const hasFunctionArg = typeof expression === "function" && arguments.length >= 2;
    const expr = typeof expression === "function"
      ? `(${expression.toString()})(${hasFunctionArg ? jsValue(argOrOptions) : ""})`
      : expression;
    const evaluateOptions = typeof expression === "function"
      ? options
      : isEvaluateOptions(argOrOptions) ? argOrOptions : {};
    const shouldAwaitPromise = evaluateOptions.awaitPromise ?? (
      typeof expression === "function"
        ? expression.constructor.name === "AsyncFunction"
        : expr.includes("await ") || expr.includes("new Promise") || expr.includes(".then(")
    );
    const resp = await this.sendBidi("script.evaluate", {
      expression: expr,
      target: { context: this.requireContextId() },
      awaitPromise: shouldAwaitPromise,
    });
    if (resp.type === "error") {
      throw new Error(resp.message || resp.error || "script.evaluate failed");
    }
    const result = resp.result as { result?: unknown; exceptionDetails?: unknown };
    if (result.exceptionDetails) {
      const error = this.pageErrorFromExceptionDetails(result.exceptionDetails);
      this.emitPageEvent("pageerror", error);
      throw error;
    }
    const value = deserializeBidiValue(result.result) as T;
    if (this.navigationFlushDepth === 0) {
      await this.flushPendingNavigation();
    }
    await this.refreshCurrentUrl();
    return value;
  }

  async waitForSelector(
    selector: string,
    options: CraterWaitForSelectorOptions = {},
  ): Promise<CraterLocator | null> {
    const locator = this.locator(selector);
    await locator.waitFor(options);
    const state = options.state ?? "attached";
    return state === "hidden" || state === "detached" ? null : locator;
  }

  async waitForTimeout(timeout: number): Promise<void> {
    await new Promise((resolve) => setTimeout(resolve, timeout));
  }

  async waitForFunction<T, Arg = unknown>(
    pageFunction: string | ((arg: Arg) => T | Promise<T>),
    argOrOptions?: Arg | CraterWaitForFunctionOptions,
    options: CraterWaitForFunctionOptions = {},
  ): Promise<T> {
    const hasArg = arguments.length >= 3 ||
      (arguments.length >= 2 && !isWaitForFunctionOptions(argOrOptions));
    const waitOptions = hasArg
      ? options
      : (isWaitForFunctionOptions(argOrOptions) ? argOrOptions : {});
    const timeout = this.timeoutOrDefault(waitOptions.timeout, 3000);
    const polling = waitOptions.polling ?? 30;
    const expression = this.waitForFunctionExpression(pageFunction, argOrOptions as Arg, hasArg);
    const start = Date.now();
    let lastError: Error | null = null;
    while (Date.now() - start < timeout) {
      try {
        const value = await this.evaluate<T>(
          `(async () => await ${expression})()`,
          { awaitPromise: true },
        );
        if (value) {
          return value;
        }
      } catch (error) {
        lastError = error instanceof Error ? error : new Error(String(error));
      }
      await this.waitForTimeout(polling);
    }
    const suffix = lastError ? ` Last error: ${lastError.message}` : "";
    throw new Error(`Timeout waiting for function.${suffix}`);
  }

  async route(matcher: CraterRequestMatcher, handler: CraterRouteHandler): Promise<void> {
    this.routes.push({ matcher, handler });
    await this.installNetworkHooks({ routeEnabled: true });
    this.startRoutePump();
  }

  async unroute(matcher?: CraterRequestMatcher): Promise<void> {
    if (matcher === undefined) {
      this.routes = [];
    } else {
      this.routes = this.routes.filter((entry) => entry.matcher !== matcher);
    }
    if (this.routes.length === 0) {
      await this.installNetworkHooks({ routeEnabled: false });
      if (this.routePump) {
        clearInterval(this.routePump);
        this.routePump = null;
      }
    }
  }

  async waitForRequest(
    matcher: CraterRequestMatcher,
    options: CraterWaitForNetworkOptions = {},
  ): Promise<CraterRequest> {
    const startedAt = Date.now();
    await this.installNetworkHooks();
    const startIndex = Math.max(0, await this.networkEventCount() - 20);
    const timeout = this.timeoutOrDefault(options.timeout, 3000);
    const polling = options.polling ?? 30;
    const start = Date.now();
    while (Date.now() - start < timeout) {
      const events = await this.networkEventsSince(startIndex);
      for (let i = 0; i < events.length; i += 1) {
        const event = events[i];
        if (event.type !== "request") continue;
        if (event.timestamp < startedAt) continue;
        const request = new CraterRequest(event.request);
        if (await this.requestMatches(request, matcher)) {
          await this.drainNetworkPageEventsUpTo(startIndex + i + 1);
          return request;
        }
      }
      await this.waitForTimeout(polling);
    }
    throw new Error(`Timeout waiting for request: ${String(matcher)}`);
  }

  async waitForResponse(
    matcher: CraterResponseMatcher,
    options: CraterWaitForNetworkOptions = {},
  ): Promise<CraterResponse> {
    const startedAt = Date.now();
    await this.installNetworkHooks();
    const startIndex = Math.max(0, await this.networkEventCount() - 20);
    const timeout = this.timeoutOrDefault(options.timeout, 3000);
    const polling = options.polling ?? 30;
    const start = Date.now();
    while (Date.now() - start < timeout) {
      const events = await this.networkEventsSince(startIndex);
      for (let i = 0; i < events.length; i += 1) {
        const event = events[i];
        if (event.type !== "response") continue;
        if (event.timestamp < startedAt) continue;
        const response = new CraterResponse(event.response);
        if (await this.responseMatches(response, matcher)) {
          await this.drainNetworkPageEventsUpTo(startIndex + i + 1);
          return response;
        }
      }
      await this.waitForTimeout(polling);
    }
    throw new Error(`Timeout waiting for response: ${String(matcher)}`);
  }

  async click(selector: string): Promise<void> {
    const sharedId = await this.elementSharedId(selector);
    await this.performPointer(pointerClickActions(sharedId));
    await markLiveDomCaptureNeeded(this);
  }

  async hover(selector: string): Promise<void> {
    const sharedId = await this.elementSharedId(selector);
    await this.performPointer(pointerMoveActions(sharedId));
  }

  async fill(
    selector: string,
    value: string,
    options: CraterLocatorActionOptions = {},
  ): Promise<void> {
    await this.locator(selector).fill(value, options);
  }

  async type(selector: string, text: string): Promise<void> {
    await this.click(selector);
    await this.keyboard.type(text);
    await markLiveDomCaptureNeeded(this);
  }

  async press(key: string): Promise<void> {
    await this.keyboard.press(key);
    await markLiveDomCaptureNeeded(this);
  }

  async check(selector: string): Promise<void> {
    const checked = await this.evaluate<boolean>(`(() => {
      const el = document.querySelector(${jsString(selector)});
      return !!(el && el.checked);
    })()`);
    if (!checked) {
      await this.click(selector);
    }
  }

  async uncheck(selector: string): Promise<void> {
    const checked = await this.evaluate<boolean>(`(() => {
      const el = document.querySelector(${jsString(selector)});
      return !!(el && el.checked);
    })()`);
    if (checked) {
      await this.click(selector);
    }
  }

  async select(selector: string, value: string): Promise<void> {
    const rawState = await this.evaluate<string | null>(`(() => {
      const el = document.querySelector(${jsString(selector)});
      if (!el) return null;
      const options = Array.from(el.options || el.children || el._children || []).filter((option) => {
        const tag = String(option?.tagName || option?.nodeName || "").toLowerCase();
        return tag === "option";
      });
      return JSON.stringify({
        selectedIndex: typeof el.selectedIndex === "number" ? el.selectedIndex : -1,
        values: options.map((option) =>
          String(option.value ?? option.getAttribute?.("value") ?? option.textContent ?? ""),
        ),
      });
    })()`);
    if (!rawState) {
      throw new Error(`Element not found: ${selector}`);
    }
    const state = JSON.parse(rawState) as { selectedIndex: number; values: string[] };
    const targetIndex = state.values.indexOf(value);
    if (targetIndex < 0) {
      throw new Error(`Option not found: ${value}`);
    }
    if (state.selectedIndex === targetIndex) {
      return;
    }
    await this.click(selector);
    const delta = targetIndex - state.selectedIndex;
    const key = delta >= 0 ? "ArrowDown" : "ArrowUp";
    const steps = Math.abs(delta);
    const actions = Array.from({ length: steps }, () => [
      { type: "keyDown", value: keyValue(key) },
      { type: "keyUp", value: keyValue(key) },
    ]).flat();
    await this.performKey(actions);
  }

  async textContent(selector: string): Promise<string | null> {
    return this.locator(selector).textContent();
  }

  async innerHTML(selector: string): Promise<string> {
    return this.locator(selector).innerHTML();
  }

  async inputValue(selector: string): Promise<string> {
    return this.locator(selector).inputValue();
  }

  async isVisible(selector: string): Promise<boolean> {
    return this.locator(selector).isVisible();
  }

  async getAttribute(selector: string, name: string): Promise<string | null> {
    return this.locator(selector).getAttribute(name);
  }

  async count(selector: string): Promise<number> {
    return this.locator(selector).count();
  }

  async $(selector: string): Promise<CraterLocator | null> {
    const count = await this.count(selector);
    return count > 0 ? this.locator(selector) : null;
  }

  async $$(selector: string): Promise<CraterLocator[]> {
    const count = await this.count(selector);
    const locator = this.locator(selector);
    return Array.from({ length: count }, (_, index) => locator.nth(index));
  }

  async $eval<T>(selector: string, fn: (element: Element) => T | Promise<T>): Promise<T> {
    return this.locator(selector).evaluate(fn);
  }

  async $$eval<T>(selector: string, fn: (elements: Element[]) => T): Promise<T> {
    const fnStr = fn.toString();
    return this.evaluate(`
      (() => {
        const elements = Array.from(document.querySelectorAll(${jsString(selector)}));
        return (${fnStr})(elements);
      })()
    `);
  }

  private createLocator(
    selector: string,
    options: { filters?: LocatorFilter[] } = {},
  ): CraterLocator {
    return new CraterLocator(this, selector, {
      filters: options.filters,
      timeoutResolver: (timeout, fallback) => this.timeoutOrDefault(timeout, fallback),
    });
  }

  locator(selector: string): CraterLocator {
    return this.createLocator(selector);
  }

  frameLocator(selector: string): CraterFrameLocator {
    return new CraterFrameLocator(
      this,
      selector,
      (timeout, fallback) => this.timeoutOrDefault(timeout, fallback),
    );
  }

  getByText(text: CraterTextMatcher, options: CraterTextMatchOptions = {}): CraterLocator {
    return this.locator(locatorSelector("text", text, options));
  }

  getByRole(role: string, options: CraterGetByRoleOptions = {}): CraterLocator {
    return this.createLocator(`role=${role}`, {
      filters: roleOptionFilters(options),
    });
  }

  getByPlaceholder(text: CraterTextMatcher, options: CraterTextMatchOptions = {}): CraterLocator {
    return this.locator(locatorSelector("placeholder", text, options));
  }

  getByAltText(text: CraterTextMatcher, options: CraterTextMatchOptions = {}): CraterLocator {
    return this.locator(locatorSelector("alt", text, options));
  }

  getByTitle(text: CraterTextMatcher, options: CraterTextMatchOptions = {}): CraterLocator {
    return this.locator(locatorSelector("title", text, options));
  }

  getByTestId(testId: CraterTextMatcher): CraterLocator {
    return this.locator(locatorSelector("testid", testId));
  }

  getByLabel(text: CraterTextMatcher, options: CraterTextMatchOptions = {}): CraterLocator {
    return this.locator(locatorSelector("label", text, options));
  }

  async selectOption(selector: string, value: CraterSelectOptionValue): Promise<void> {
    await this.locator(selector).selectOption(value);
  }

  async setInputFiles(selector: string, files: CraterSetInputFilesValue): Promise<void> {
    await this.locator(selector).setInputFiles(files);
  }

  async screenshot(options: CraterScreenshotOptions = {}): Promise<Buffer> {
    return await this.captureScreenshotWithBackend(options, null);
  }

  async ariaSnapshot(options: CraterAriaSnapshotOptions = {}): Promise<CraterA11ySnapshotNode | null> {
    const depth = Number.isFinite(options.depth)
      ? Math.max(0, Math.floor(Number(options.depth)))
      : 8;
    const timeout = this.timeoutOrDefault(options.timeout, 5000);
    const payload = await this.withOperationTimeout(
      this.evaluate<string>(this.ariaSnapshotExpression(depth)),
      timeout,
      "page.ariaSnapshot",
    );
    try {
      const parsed = JSON.parse(payload) as CraterA11ySnapshotNode | null;
      return parsed && typeof parsed === "object" && typeof parsed.role === "string"
        ? parsed
        : null;
    } catch {
      return null;
    }
  }

  async drag(sourceSelector: string, targetSelector: string): Promise<void> {
    const sourceSharedId = await this.elementSharedId(sourceSelector);
    const targetSharedId = await this.elementSharedId(targetSelector);
    await this.performPointer([
      {
        type: "pointerMove",
        origin: { type: "element", element: { sharedId: sourceSharedId } },
        x: 0,
        y: 0,
      },
      { type: "pointerDown", button: 0 },
      {
        type: "pointerMove",
        origin: { type: "element", element: { sharedId: targetSharedId } },
        x: 0,
        y: 0,
      },
      { type: "pointerUp", button: 0 },
    ]);
  }

  async waitForText(selector: string, expected: string, options: { timeout?: number } = {}): Promise<void> {
    const timeout = this.timeoutOrDefault(options.timeout, 3000);
    const start = Date.now();
    while (Date.now() - start < timeout) {
      const text = await this.textContent(selector);
      if (text === expected) {
        return;
      }
      await new Promise((resolve) => setTimeout(resolve, 30));
    }
    throw new Error(`Timeout waiting for ${selector} to become ${expected}`);
  }

  async waitForCondition(expression: string, options: { timeout?: number } = {}): Promise<void> {
    const timeout = this.timeoutOrDefault(options.timeout, 3000);
    const start = Date.now();
    while (Date.now() - start < timeout) {
      const ok = await this.evaluate<boolean>(expression);
      if (ok) {
        return;
      }
      await new Promise((resolve) => setTimeout(resolve, 30));
    }
    throw new Error(`Timeout waiting for condition: ${expression}`);
  }

  async waitForURL(expected: CraterUrlMatcher, options: { timeout?: number } = {}): Promise<void> {
    const timeout = this.timeoutOrDefault(options.timeout, 3000);
    const start = Date.now();
    while (Date.now() - start < timeout) {
      await this.flushPendingNavigation();
      const current = await this.url();
      if (this.urlMatches(current, expected)) {
        return;
      }
      await new Promise((resolve) => setTimeout(resolve, 30));
    }
    throw new Error(`Timeout waiting for URL: ${String(expected)}`);
  }

  async waitForNavigation(options: { timeout?: number } = {}): Promise<void> {
    const timeout = this.timeoutOrDefault(options.timeout, 10000);
    await this.sendBidi("session.subscribe", {
      events: ["browsingContext.load", "browsingContext.domContentLoaded"],
      contexts: [this.requireContextId()],
    });
    this.navigationPromise = new Promise<void>((resolve, reject) => {
      this.navigationResolve = resolve;
      setTimeout(() => {
        if (this.navigationResolve) {
          this.navigationResolve = null;
          this.navigationPromise = null;
          reject(new Error("Navigation timeout"));
        }
      }, timeout);
    });
    return this.navigationPromise;
  }

  async waitForLoadState(
    state: CraterLoadState = "load",
    options: { timeout?: number } = {},
  ): Promise<void> {
    await this.flushPendingNavigation();
    const timeout = this.timeoutOrDefault(options.timeout, 30000);
    switch (state) {
      case "networkidle":
      case "networkidle0":
        await this.evaluate(`__waitForNetworkIdle0({ timeout: ${timeout} })`, { awaitPromise: true });
        break;
      case "networkidle2":
        await this.evaluate(`__waitForNetworkIdle2({ timeout: ${timeout} })`, { awaitPromise: true });
        break;
      case "load":
      case "domcontentloaded":
      default:
        await this.evaluate("document.readyState");
        break;
    }
  }

  async waitForNetworkIdle(
    options: { timeout?: number; idleTime?: number; maxInflight?: number } = {},
  ): Promise<void> {
    const timeout = this.timeoutOrDefault(options.timeout, 30000);
    const idleTime = options.idleTime ?? 500;
    const maxInflight = options.maxInflight ?? 0;
    await this.evaluate(
      `__waitForNetworkIdle({ timeout: ${timeout}, idleTime: ${idleTime}, maxInflight: ${maxInflight} })`,
      { awaitPromise: true },
    );
  }

  async captureScreenshot(options: CraterScreenshotOptions = {}): Promise<Buffer> {
    return await this.captureScreenshotWithBackend(options, null);
  }

  private async captureScreenshotWithBackend(
    options: CraterScreenshotOptions,
    backend: "synthetic" | null,
  ): Promise<Buffer> {
    const params = await this.screenshotBidiParams(options, backend);
    const resp = await this.withOperationTimeout(
      this.sendBidi("browsingContext.captureScreenshotData", params),
      options.timeout,
      "browsingContext.captureScreenshotData",
    );
    if (resp.type === "error") {
      throw new Error(resp.message || resp.error || "captureScreenshotData failed");
    }
    const buffer = Buffer.from(String(resp.result || ""), "base64");
    if (options.path) {
      await writeFile(options.path, buffer);
    }
    return buffer;
  }

  async capturePaintData(options: { html?: string } = {}): Promise<{ width: number; height: number; data: Uint8Array }> {
    const resp = await this.sendBidi("browsingContext.capturePaintData", {
      context: this.requireContextId(),
      origin: "viewport",
      ...(options.html === undefined ? {} : { html: options.html }),
    });
    if (resp.type === "error") {
      throw new Error(resp.message || resp.error || "capturePaintData failed");
    }
    const result = resp.result as { width?: number; height?: number; data?: string };
    const width = Number(result.width ?? 0);
    const height = Number(result.height ?? 0);
    const data = Buffer.from(String(result.data || ""), "base64");
    return {
      width,
      height,
      data: Uint8Array.from(data),
    };
  }

  async capturePaintTree(
    options: { origin?: "viewport" | "document" } = {},
  ): Promise<{ width: number; height: number; paintTree: string }> {
    const resp = await this.sendBidi("browsingContext.capturePaintTree", {
      context: this.requireContextId(),
      origin: options.origin ?? "viewport",
    });
    if (resp.type === "error") {
      throw new Error(resp.message || resp.error || "capturePaintTree failed");
    }
    const result = resp.result as { width?: number; height?: number; paintTree?: string };
    return {
      width: Number(result.width ?? 0),
      height: Number(result.height ?? 0),
      paintTree: String(result.paintTree || "{}"),
    };
  }

  async getComputedStyles(selector: string, properties: string[]): Promise<Record<string, string>> {
    return this.requestComputedStyles({ selector, properties });
  }

  async getComputedStylesBySharedId(
    sharedId: string,
    properties: string[],
  ): Promise<Record<string, string>> {
    return this.requestComputedStyles({ sharedId, properties });
  }

  async getAllComputedStyles(properties: string[]): Promise<Record<string, Record<string, string>>> {
    const resp = await this.sendBidi("browsingContext.getAllComputedStyles", {
      context: this.requireContextId(),
      properties,
    });
    if (resp.type === "error") {
      throw new Error(resp.message || resp.error || "getAllComputedStyles failed");
    }
    const result = resp.result as {
      styles?: Record<string, Record<string, string>>;
    };
    return result.styles ?? {};
  }

  async getComputedStylesForElement(
    selector: string,
    properties: string[],
  ): Promise<Record<string, string>> {
    const sharedId = await this.elementSharedId(selector);
    return this.getComputedStylesBySharedId(sharedId, properties);
  }

  async getCssRuleUsage(): Promise<
    Array<{
      selector: string;
      matched: boolean;
      elements: number;
      overridden: boolean;
      overriddenBy?: string;
    }>
  > {
    const resp = await this.sendBidi("browsingContext.getCssRuleUsage", {
      context: this.requireContextId(),
    });
    if (resp.type === "error") {
      throw new Error(resp.message || resp.error || "getCssRuleUsage failed");
    }
    const result = resp.result as {
      rules?: Array<{
        selector?: string;
        matched?: boolean;
        elements?: number;
        overridden?: boolean;
        overriddenBy?: string;
      }>;
    };
    return (result.rules ?? []).map((rule) => ({
      selector: String(rule.selector ?? ""),
      matched: Boolean(rule.matched),
      elements: Number(rule.elements ?? 0),
      overridden: Boolean(rule.overridden),
      ...(rule.overriddenBy ? { overriddenBy: String(rule.overriddenBy) } : {}),
    }));
  }

  async getCssRuleUsageDetails(): Promise<{
    rules: Array<{
      selector: string;
      matched: boolean;
      elements: number;
      overridden: boolean;
      overriddenBy?: string;
      noEffect?: boolean;
      noEffectReason?: string;
    }>;
    elements: Record<string, Record<string, string>>;
  }> {
    const resp = await this.sendBidi("browsingContext.getCssRuleUsage", {
      context: this.requireContextId(),
    });
    if (resp.type === "error") {
      throw new Error(resp.message || resp.error || "getCssRuleUsage failed");
    }
    const result = resp.result as {
      rules?: Array<{
        selector?: string;
        matched?: boolean;
        elements?: number;
        overridden?: boolean;
        overriddenBy?: string;
        noEffect?: boolean;
        noEffectReason?: string;
      }>;
      elements?: Record<string, Record<string, string>>;
    };
    return {
      rules: (result.rules ?? []) as Array<{
        selector: string;
        matched: boolean;
        elements: number;
        overridden: boolean;
        overriddenBy?: string;
        noEffect?: boolean;
        noEffectReason?: string;
      }>,
      elements: result.elements ?? {},
    };
  }

  private async connectOnce(timeout: number, url?: string): Promise<void> {
    await new Promise<void>((resolve, reject) => {
      const timer = setTimeout(() => {
        reject(new Error(`BiDi connect timeout after ${timeout}ms`));
      }, timeout);
      void (url ? Promise.resolve(url) : resolveBidiUrl())
        .then((bidiUrl) => {
          this.ws = new WebSocket(bidiUrl);
          this.ws.on("open", async () => {
            try {
              const resp = await this.sendBidi("browsingContext.create", { type: "tab" });
              this.contextId = (resp.result as { context: string }).context;
              await this.installModelContextRuntime({ resetRegistry: true });
              clearTimeout(timer);
              resolve();
            } catch (error) {
              clearTimeout(timer);
              reject(error);
            }
          });
          this.ws.on("error", (error) => {
            clearTimeout(timer);
            reject(error);
          });
          this.ws.on("message", (data) => this.handleMessage(data.toString()));
        })
        .catch((error) => {
          clearTimeout(timer);
          reject(error);
        });
    });
  }

  private async installModelContextRuntime(
    options: { resetRegistry?: boolean } = {},
  ): Promise<void> {
    await this.evaluate(modelContextRuntimeExpression(options));
  }

  private async requestComputedStyles(params: Record<string, unknown>): Promise<Record<string, string>> {
    const resp = await this.sendBidi("browsingContext.getComputedStyles", {
      context: this.requireContextId(),
      ...params,
    });
    if (resp.type === "error") {
      throw new Error(resp.message || resp.error || "getComputedStyles failed");
    }
    const result = resp.result as { styles?: Record<string, string> };
    return result.styles ?? {};
  }

  private async performKeyboardActions(actions: Array<Record<string, string>>): Promise<void> {
    await this.performKey(actions);
  }

  private async insertTextIntoFocusedElement(text: string): Promise<void> {
    await this.evaluate(`
      (() => {
        ${adapterDomActionsExpr()}
        const element = globalThis.__bidiFocusedElement || document.activeElement;
        if (!element) throw new Error("No focused element");
        __craterAction.insertText(element, ${jsString(text)});
      })()
    `);
  }

  private async elementSharedId(selector: string): Promise<string> {
    const resp = await this.sendBidi("script.evaluate", {
      expression: `document.querySelector(${jsString(selector)})`,
      target: { context: this.requireContextId() },
      awaitPromise: false,
    });
    if (resp.type === "error") {
      throw new Error(resp.message || resp.error || `Failed to resolve ${selector}`);
    }
    const result = resp.result as {
      result?: { type?: string; sharedId?: string; value?: unknown };
    };
    const sharedId = result.result?.sharedId;
    if (!sharedId) {
      throw new Error(`Element not found: ${selector}`);
    }
    return sharedId;
  }

  private async performPointer(actions: Array<Record<string, unknown>>): Promise<void> {
    await this.sendBidi("input.performActions", {
      context: this.requireContextId(),
      actions: [
        {
          type: "pointer",
          id: "mouse-0",
          parameters: { pointerType: "mouse" },
          actions,
        },
      ],
    });
  }

  private async performKey(actions: Array<Record<string, string>>): Promise<void> {
    await this.sendBidi("input.performActions", {
      context: this.requireContextId(),
      actions: [
        {
          type: "key",
          id: "keyboard-0",
          actions,
        },
      ],
    });
  }

  private requireContextId(): string {
    if (this.closed) {
      throw new Error("Page is closed");
    }
    if (!this.contextId) {
      throw new Error("No browsing context");
    }
    return this.contextId;
  }

  private async installNetworkHooks(options: { routeEnabled?: boolean } = {}): Promise<void> {
    const routeEnabled = options.routeEnabled === true;
    this.networkHooksInstalled = true;
    const installPromise = this.evaluate(`
      (() => {
        const root = globalThis;
        const state = root.__craterNetworkState || {
          installed: false,
          events: [],
          pendingRoutes: [],
          resolvers: Object.create(null),
          nextId: 0,
          routeEnabled: false,
          baseFetch: null,
        };
        root.__craterNetworkState = state;

        const headersToObject = (headers) => {
          const out = {};
          if (!headers) return out;
          try {
            new Headers(headers).forEach((value, key) => {
              out[String(key).toLowerCase()] = String(value);
            });
          } catch (_error) {
            if (typeof headers === "object") {
              for (const key of Object.keys(headers)) {
                out[String(key).toLowerCase()] = String(headers[key]);
              }
            }
          }
          return out;
        };

        const normalizeRequest = (input, options) => {
          const rawUrl = typeof input === "string" || input instanceof URL
            ? String(input)
            : input && input.url ? String(input.url) : String(input);
          const url = root.__resolveUrl ? root.__resolveUrl(rawUrl, root.__pageUrl) : rawUrl;
          const method = String(
            options && options.method ? options.method : input && input.method ? input.method : "GET"
          ).toUpperCase();
          const headers = headersToObject(options && options.headers ? options.headers : input && input.headers);
          const body = options && Object.prototype.hasOwnProperty.call(options, "body")
            ? options.body
            : null;
          return {
            id: "crater-route-" + (++state.nextId),
            url,
            method,
            headers,
            postData: body === null || body === undefined ? null : String(body),
          };
        };

        const emitRequest = (request) => {
          state.events.push({ type: "request", timestamp: Date.now(), request });
        };
        const emitResponse = (request, response, body) => {
          state.events.push({
            type: "response",
            timestamp: Date.now(),
            request,
            response: {
              url: response && response.url ? String(response.url) : request.url,
              status: response && typeof response.status === "number" ? response.status : 0,
              statusText: response && response.statusText ? String(response.statusText) : "",
              headers: response ? headersToObject(response.headers) : {},
              body: body === undefined ? null : body,
              request,
            },
          });
        };
        const emitFailure = (request, error) => {
          state.events.push({
            type: "requestfailed",
            timestamp: Date.now(),
            request,
            errorText: error && error.message ? String(error.message) : String(error),
          });
        };

        root.__craterNetworkEventCount = () => state.events.length;
        root.__craterNetworkEventsSince = (index) => JSON.stringify(state.events.slice(index));
        root.__craterRecordSyntheticResponse = (url, status, statusText, headers, body) => {
          const request = {
            id: "crater-synthetic-" + (++state.nextId),
            url: String(url),
            method: "GET",
            headers: {},
            postData: null,
          };
          emitResponse(request, {
            url: String(url),
            status: Number(status || 0),
            statusText: String(statusText || ""),
            headers: headers || {},
          }, body === undefined ? null : body);
        };
        root.__craterTakePendingRoutes = () => {
          const pending = state.pendingRoutes.splice(0, state.pendingRoutes.length);
          return JSON.stringify(pending);
        };
        root.__craterResolveRoute = (id, decision) => {
          const resolver = state.resolvers[id];
          if (!resolver) return false;
          delete state.resolvers[id];
          resolver(decision || { action: "continue" });
          return true;
        };
        root.__craterSetRouteEnabled = (enabled) => {
          state.routeEnabled = !!enabled;
          return state.routeEnabled;
        };

        if (!state.installed) {
          if (typeof root.fetch !== "function") {
            throw new Error("fetch is not available in Crater runtime");
          }
          state.baseFetch = root.fetch.bind(root);
          root.fetch = async function(input, options) {
            const request = normalizeRequest(input, options || {});
            emitRequest(request);
            let decision = { action: "continue" };
            if (state.routeEnabled) {
              decision = await new Promise((resolve) => {
                state.resolvers[request.id] = resolve;
                state.pendingRoutes.push(request);
              });
            }
            try {
              if (decision.action === "abort") {
                throw new Error(decision.errorCode || "aborted");
              }
              if (decision.action === "fulfill") {
                const response = new Response(decision.body || "", {
                  status: decision.status || 200,
                  headers: decision.headers || {},
                });
                emitResponse(request, response, decision.body || "");
                return response;
              }
              const nextOptions = { ...(options || {}) };
              if (decision.method) nextOptions.method = decision.method;
              if (decision.headers) nextOptions.headers = decision.headers;
              if (Object.prototype.hasOwnProperty.call(decision, "postData")) {
                nextOptions.body = decision.postData;
              }
              const response = await state.baseFetch(decision.url || request.url, nextOptions);
              emitResponse(request, response, null);
              return response;
            } catch (error) {
              emitFailure(request, error);
              throw error;
            }
          };
          root.__craterObservableFetch = root.fetch.bind(root);
          state.installed = true;
        }

        if (${routeEnabled ? "true" : "false"}) {
          state.routeEnabled = true;
        }
        return true;
      })()
    `);
    this.networkHookInstallPromise = installPromise.then(() => undefined);
    await this.networkHookInstallPromise;
    if (options.routeEnabled === false) {
      await this.evaluate(`
        (() => {
          if (globalThis.__craterSetRouteEnabled) {
            globalThis.__craterSetRouteEnabled(false);
          }
        })()
      `);
    }
  }

  private async startNetworkEventPump(): Promise<void> {
    if (this.networkEventPump) {
      return;
    }
    if (this.networkEventPumpStarting) {
      await this.networkEventPumpStarting;
      return;
    }
    this.networkEventPumpStarting = (async () => {
      await this.installNetworkHooks();
      this.networkEventPump = setInterval(() => {
        void this.drainNetworkPageEvents().catch(() => {
          // Best-effort EventEmitter compatibility; explicit waits surface failures.
        });
      }, 10);
    })();
    try {
      await this.networkEventPumpStarting;
    } finally {
      this.networkEventPumpStarting = null;
    }
  }

  private async drainNetworkPageEvents(): Promise<void> {
    await this.drainNetworkPageEventsUpTo();
  }

  private async drainNetworkPageEventsUpTo(endIndexExclusive?: number): Promise<void> {
    if (this.closed) {
      return;
    }
    while (this.networkEventPumpBusy) {
      if (
        endIndexExclusive !== undefined &&
        this.networkEventEmitIndex >= endIndexExclusive
      ) {
        return;
      }
      await this.waitForTimeout(1);
    }
    if (
      endIndexExclusive !== undefined &&
      this.networkEventEmitIndex >= endIndexExclusive
    ) {
      return;
    }
    this.networkEventPumpBusy = true;
    try {
      while (!this.closed) {
        if (
          endIndexExclusive !== undefined &&
          this.networkEventEmitIndex >= endIndexExclusive
        ) {
          break;
        }
        const events = await this.networkEventsSince(this.networkEventEmitIndex);
        if (events.length === 0) {
          break;
        }
        const limit = endIndexExclusive === undefined
          ? events.length
          : Math.min(events.length, endIndexExclusive - this.networkEventEmitIndex);
        if (limit <= 0) {
          break;
        }
        const eventsToEmit = events.slice(0, limit);
        this.networkEventEmitIndex += eventsToEmit.length;
        for (const event of eventsToEmit) {
          this.emitNetworkPageEvent(event);
        }
      }
    } finally {
      this.networkEventPumpBusy = false;
    }
  }

  private startFileChooserEventPump(): void {
    if (this.fileChooserEventPump) {
      return;
    }
    this.fileChooserEventPump = setInterval(() => {
      void this.drainFileChooserPageEvents().catch(() => {
        // Best-effort EventEmitter compatibility; explicit waits surface failures.
      });
    }, 10);
  }

  private async drainFileChooserPageEvents(): Promise<void> {
    if (this.fileChooserEventPumpBusy || this.closed) {
      return;
    }
    this.fileChooserEventPumpBusy = true;
    try {
      const events = await this.fileChooserEventsSince(this.fileChooserEventEmitIndex);
      this.fileChooserEventEmitIndex += events.length;
      for (const event of events) {
        this.emitPageEvent("filechooser", this.fileChooserPageEventPayload(event));
      }
    } finally {
      this.fileChooserEventPumpBusy = false;
    }
  }

  private async ensureDialogSubscription(): Promise<void> {
    if (this.dialogSubscribed) {
      return;
    }
    if (this.dialogSubscribePromise) {
      await this.dialogSubscribePromise;
      return;
    }
    this.dialogSubscribePromise = (async () => {
      const resp = await this.sendBidi("session.subscribe", {
        events: ["browsingContext.userPromptOpened"],
        contexts: [this.requireContextId()],
      });
      if (resp.type === "error") {
        throw new Error(resp.message || resp.error || "session.subscribe failed");
      }
      this.dialogSubscribed = true;
    })();
    try {
      await this.dialogSubscribePromise;
    } finally {
      if (!this.dialogSubscribed) {
        this.dialogSubscribePromise = null;
      }
    }
  }

  private async ensureDownloadSubscription(): Promise<void> {
    if (this.downloadSubscribed) {
      return;
    }
    if (this.downloadSubscribePromise) {
      await this.downloadSubscribePromise;
      return;
    }
    this.downloadSubscribePromise = (async () => {
      const resp = await this.sendBidi("session.subscribe", {
        events: ["browsingContext.downloadWillBegin", "browsingContext.downloadEnd"],
        contexts: [this.requireContextId()],
      });
      if (resp.type === "error") {
        throw new Error(resp.message || resp.error || "session.subscribe failed");
      }
      this.downloadSubscribed = true;
    })();
    try {
      await this.downloadSubscribePromise;
    } finally {
      if (!this.downloadSubscribed) {
        this.downloadSubscribePromise = null;
      }
    }
  }

  private async ensureConsoleSubscription(): Promise<void> {
    if (this.consoleSubscribed) {
      return;
    }
    if (this.consoleSubscribePromise) {
      await this.consoleSubscribePromise;
      return;
    }
    this.consoleSubscribePromise = (async () => {
      const resp = await this.sendBidi("session.subscribe", {
        events: ["log.entryAdded"],
        contexts: [this.requireContextId()],
      });
      if (resp.type === "error") {
        throw new Error(resp.message || resp.error || "session.subscribe failed");
      }
      this.consoleSubscribed = true;
    })();
    try {
      await this.consoleSubscribePromise;
    } finally {
      if (!this.consoleSubscribed) {
        this.consoleSubscribePromise = null;
      }
    }
  }

  private startRoutePump(): void {
    if (this.routePump) {
      return;
    }
    this.routePump = setInterval(() => {
      this.enqueueRoutePumpDrain();
    }, 10);
  }

  private enqueueRoutePumpDrain(): void {
    if (this.routePumpQueued) {
      return;
    }
    this.routePumpQueued = true;
    void this.drainRouteRequests()
      .catch(() => {
        // The page may be closing; the next explicit command will surface real failures.
      })
      .finally(() => {
        this.routePumpQueued = false;
      });
  }

  private async drainRouteRequests(): Promise<void> {
    if (this.routePumpBusy || this.closed || !this.contextId) {
      return;
    }
    this.routePumpBusy = true;
    try {
      const raw = await this.evaluate<string>(
        `globalThis.__craterTakePendingRoutes ? globalThis.__craterTakePendingRoutes() : "[]"`,
      );
      const pending = JSON.parse(raw) as CraterNetworkRequestPayload[];
      for (const payload of pending) {
        const request = new CraterRequest(payload);
        const route = new CraterRoute(request, (decision) =>
          this.resolveRoute(payload.id, decision)
        );
        const entry = await this.matchRoute(request);
        if (entry) {
          try {
            await entry.handler(route, request);
          } catch (error) {
            if (!route.handled()) {
              const message = error instanceof Error ? error.message : String(error);
              await route.abort(message);
            }
            continue;
          }
          if (!route.handled()) {
            await route.continue();
          }
        } else {
          await route.continue();
        }
      }
    } finally {
      this.routePumpBusy = false;
    }
  }

  private async resolveRoute(id: string, decision: CraterRouteDecision): Promise<void> {
    await this.evaluate(
      `globalThis.__craterResolveRoute(${jsString(id)}, ${jsValue(decision)})`,
    );
  }

  private async matchRoute(request: CraterRequest): Promise<CraterRouteEntry | null> {
    for (const entry of this.routes) {
      if (await this.requestMatches(request, entry.matcher)) {
        return entry;
      }
    }
    return null;
  }

  private async waitForNetworkPageEvent(
    eventName: "request" | "response" | "requestfailed",
    options: CraterWaitForEventOptions,
  ): Promise<CraterPageEventPayload> {
    await this.installNetworkHooks();
    const startIndex = 0;
    const timeout = this.timeoutOrDefault(options.timeout, 3000);
    const polling = 30;
    const start = Date.now();
    while (Date.now() - start < timeout) {
      const events = await this.networkEventsSince(startIndex);
      for (let i = 0; i < events.length; i += 1) {
        const event = events[i];
        if (event.type !== eventName) continue;
        const eventIndex = startIndex + i;
        const payload = this.networkPageEventPayload(event);
        if (!payload) continue;
        if (!options.predicate || await options.predicate(payload)) {
          await this.drainNetworkPageEventsUpTo(eventIndex + 1);
          return payload;
        }
      }
      await this.waitForTimeout(polling);
    }
    throw new Error(`Timeout waiting for event: ${eventName}`);
  }

  private async waitForFileChooserEvent(
    options: CraterWaitForEventOptions,
  ): Promise<CraterFileChooser> {
    const startIndex = 0;
    const timeout = this.timeoutOrDefault(options.timeout, 3000);
    const polling = 30;
    const start = Date.now();
    while (Date.now() - start < timeout) {
      const events = await this.fileChooserEventsSince(startIndex);
      for (const event of events) {
        const payload = this.fileChooserPageEventPayload(event);
        if (!options.predicate || await options.predicate(payload)) {
          return payload;
        }
      }
      await this.waitForTimeout(polling);
    }
    throw new Error("Timeout waiting for event: filechooser");
  }

  private waitForLocalPageEvent(
    eventName: CraterLocalPageEventName,
    options: CraterWaitForEventOptions,
  ): Promise<CraterPageEventPayload> {
    const timeout = this.timeoutOrDefault(options.timeout, 3000);
    return new Promise((resolve, reject) => {
      const waiter: CraterPageEventWaiter = {
        eventName,
        predicate: options.predicate,
        resolve,
        reject,
        settled: false,
        timer: setTimeout(() => {
          if (waiter.settled) return;
          waiter.settled = true;
          this.pageEventWaiters = this.pageEventWaiters.filter((entry) => entry !== waiter);
          reject(new Error(`Timeout waiting for event: ${eventName}`));
        }, timeout),
      };
      this.pageEventWaiters.push(waiter);
    });
  }

  private async ensureSubscribedBeforeReturning<T>(
    eventPromise: Promise<T>,
    subscribe: () => Promise<void>,
  ): Promise<void> {
    try {
      await subscribe();
    } catch (error) {
      eventPromise.catch(() => undefined);
      throw error;
    }
  }

  private emitNetworkPageEvent(event: CraterNetworkEventPayload): void {
    const payload = this.networkPageEventPayload(event);
    if (!payload) {
      return;
    }
    this.emitPageEvent(event.type, payload);
  }

  private networkPageEventPayload(event: CraterNetworkEventPayload): CraterPageEventPayload | null {
    if (event.type === "request") {
      return new CraterRequest(event.request);
    }
    if (event.type === "response") {
      return new CraterResponse(event.response);
    }
    return new CraterRequestFailure({
      request: event.request,
      errorText: event.errorText,
    });
  }

  private fileChooserPageEventPayload(event: CraterFileChooserEventPayload): CraterFileChooser {
    return new CraterFileChooser(this, event.selector, event.multiple);
  }

  private consolePageEventPayload(event: CraterConsoleEventPayload): CraterConsoleMessage {
    return new CraterConsoleMessage(this, event);
  }

  private consolePageEventPayloadFromLogEntry(params: unknown): CraterConsoleMessage | null {
    if (!params || typeof params !== "object") {
      return null;
    }
    const record = params as Record<string, unknown>;
    if (record.type !== "console") {
      return null;
    }
    const source = record.source && typeof record.source === "object"
      ? record.source as Record<string, unknown>
      : {};
    if (source.context !== this.contextId) {
      return null;
    }
    const args = Array.isArray(record.args)
      ? record.args.map((arg) => this.consoleArgText(arg))
      : [];
    const text = typeof record.text === "string" ? record.text : args.join(" ");
    const type = typeof record.method === "string" ? record.method : "log";
    const timestamp = typeof record.timestamp === "number" ? record.timestamp : Date.now();
    return new CraterConsoleMessage(this, {
      type,
      text,
      args,
      timestamp,
    });
  }

  private consoleArgText(arg: unknown): string {
    const value = deserializeBidiValue(arg);
    if (value === undefined) return "undefined";
    if (value === null) return "null";
    if (typeof value === "string") return value;
    if (typeof value === "number" || typeof value === "boolean" || typeof value === "bigint") {
      return String(value);
    }
    try {
      const json = JSON.stringify(value);
      if (json !== undefined) return json;
    } catch (_e) {}
    return String(value);
  }

  private dialogPageEventPayload(params: unknown): CraterDialog | null {
    if (!params || typeof params !== "object") {
      return null;
    }
    const record = params as Record<string, unknown>;
    const context = typeof record.context === "string" ? record.context : "";
    if (!context || context !== this.contextId) {
      return null;
    }
    const rawType = typeof record.type === "string" ? record.type : "alert";
    const type: CraterDialogType =
      rawType === "beforeunload" || rawType === "confirm" || rawType === "prompt"
        ? rawType
        : "alert";
    const message = typeof record.message === "string" ? record.message : "";
    const defaultValue = typeof record.defaultValue === "string" ? record.defaultValue : undefined;
    return new CraterDialog(
      this,
      {
        context,
        type,
        message,
        defaultValue,
      },
      (dialogContext, accept, promptText) =>
        this.handleDialog(dialogContext, accept, promptText),
    );
  }

  private downloadWillBeginPayload(params: unknown): CraterDownloadWillBeginPayload | null {
    if (!params || typeof params !== "object") {
      return null;
    }
    const record = params as Record<string, unknown>;
    const context = typeof record.context === "string" ? record.context : "";
    if (!context || context !== this.contextId) {
      return null;
    }
    const url = typeof record.url === "string" ? record.url : "";
    if (!url) {
      return null;
    }
    return {
      context,
      navigation: typeof record.navigation === "string" ? record.navigation : null,
      suggestedFilename: typeof record.suggestedFilename === "string"
        ? record.suggestedFilename
        : "",
      url,
    };
  }

  private downloadEndPayload(params: unknown): CraterDownloadEndPayload | null {
    if (!params || typeof params !== "object") {
      return null;
    }
    const record = params as Record<string, unknown>;
    const context = typeof record.context === "string" ? record.context : "";
    if (!context || context !== this.contextId) {
      return null;
    }
    const url = typeof record.url === "string" ? record.url : "";
    if (!url) {
      return null;
    }
    return {
      context,
      navigation: typeof record.navigation === "string" ? record.navigation : null,
      status: typeof record.status === "string" ? record.status : "canceled",
      filepath: typeof record.filepath === "string" ? record.filepath : null,
      url,
    };
  }

  private downloadEventKey(event: { context: string; navigation: string | null; url: string }): string {
    return `${event.context}\0${event.navigation ?? event.url}`;
  }

  private emitDownloadWillBegin(params: unknown): void {
    const payload = this.downloadWillBeginPayload(params);
    if (!payload) {
      return;
    }
    let resolveEnd!: (end: CraterDownloadEndPayload) => void;
    const endPromise = new Promise<CraterDownloadEndPayload>((resolve) => {
      resolveEnd = resolve;
    });
    const download = new CraterDownload(this, payload, endPromise);
    this.pendingDownloads.set(this.downloadEventKey(payload), { download, resolveEnd });
    this.emitPageEvent("download", download);
  }

  private resolveDownloadEnd(params: unknown): void {
    const payload = this.downloadEndPayload(params);
    if (!payload) {
      return;
    }
    const key = this.downloadEventKey(payload);
    const pending = this.pendingDownloads.get(key);
    if (!pending) {
      return;
    }
    this.pendingDownloads.delete(key);
    pending.resolveEnd(payload);
  }

  private async fileChooserEventsSince(index: number): Promise<CraterFileChooserEventPayload[]> {
    const raw = await this.evaluate<string>(
      `(() => {
        const events = Array.isArray(globalThis.__craterFileChooserEvents)
          ? globalThis.__craterFileChooserEvents
          : [];
        return JSON.stringify(events.slice(${index}));
      })()`,
    );
    return JSON.parse(raw) as CraterFileChooserEventPayload[];
  }

  private async handleDialog(context: string, accept: boolean, promptText?: string): Promise<void> {
    const params: Record<string, unknown> = { context, accept };
    if (promptText !== undefined) {
      params.userText = promptText;
    }
    const resp = await this.sendBidi("browsingContext.handleUserPrompt", params);
    if (resp.type === "error") {
      throw new Error(resp.message || resp.error || "handleUserPrompt failed");
    }
  }

  private emitPageEvent(eventName: CraterPageEventName, payload: CraterPageEventPayload): void {
    const handlers = this.pageEventHandlers.get(eventName);
    if (handlers) {
      for (const handler of handlers) {
        handler(payload);
      }
    }
    const waiters = this.pageEventWaiters.filter((waiter) => waiter.eventName === eventName);
    for (const waiter of waiters) {
      if (waiter.settled) continue;
      void Promise.resolve(waiter.predicate ? waiter.predicate(payload) : true).then((matched) => {
        if (!matched || waiter.settled) return;
        waiter.settled = true;
        clearTimeout(waiter.timer);
        this.pageEventWaiters = this.pageEventWaiters.filter((entry) => entry !== waiter);
        waiter.resolve(payload);
      }).catch((error) => {
        if (waiter.settled) return;
        waiter.settled = true;
        clearTimeout(waiter.timer);
        this.pageEventWaiters = this.pageEventWaiters.filter((entry) => entry !== waiter);
        waiter.reject(error instanceof Error ? error : new Error(String(error)));
      });
    }
  }

  private async networkEventCount(): Promise<number> {
    await this.installNetworkHooks();
    return this.evaluate<number>(
      `globalThis.__craterNetworkEventCount ? globalThis.__craterNetworkEventCount() : 0`,
    );
  }

  private async networkEventsSince(index: number): Promise<CraterNetworkEventPayload[]> {
    const raw = await this.evaluate<string>(
      `globalThis.__craterNetworkEventsSince ? globalThis.__craterNetworkEventsSince(${index}) : "[]"`,
    );
    return JSON.parse(raw) as CraterNetworkEventPayload[];
  }

  private async requestMatches(
    request: CraterRequest,
    matcher: CraterRequestMatcher,
  ): Promise<boolean> {
    if (typeof matcher === "string") {
      return request.url().includes(matcher);
    }
    if (matcher instanceof RegExp) {
      return matcher.test(request.url());
    }
    return await matcher(request);
  }

  private async responseMatches(
    response: CraterResponse,
    matcher: CraterResponseMatcher,
  ): Promise<boolean> {
    if (typeof matcher === "string") {
      return response.url().includes(matcher);
    }
    if (matcher instanceof RegExp) {
      return matcher.test(response.url());
    }
    return await matcher(response);
  }

  private scriptSource(script: string | (() => unknown | Promise<unknown>)): string {
    return typeof script === "function" ? `(${script.toString()})()` : script;
  }

  private timeoutOrDefault(timeout: number | undefined, fallback: number): number {
    return timeout ?? this.defaultTimeout ?? fallback;
  }

  private pageErrorFromExceptionDetails(exceptionDetails: unknown): Error {
    const record = exceptionDetails && typeof exceptionDetails === "object"
      ? exceptionDetails as Record<string, unknown>
      : {};
    const exception = record.exception && typeof record.exception === "object"
      ? record.exception as Record<string, unknown>
      : {};
    const description = typeof exception.description === "string" ? exception.description : "";
    const text = typeof record.text === "string" ? record.text : "";
    const fallback = (() => {
      try {
        return JSON.stringify(exceptionDetails);
      } catch (_error) {
        return String(exceptionDetails);
      }
    })();
    const message = description || text || fallback || "Page error";
    const error = new Error(message);
    if (typeof exception.className === "string" && exception.className) {
      error.name = exception.className;
    }
    if (description.includes("\n")) {
      error.stack = description;
    }
    return error;
  }

  private emitPageErrorsFromScriptResults(results: unknown): void {
    if (!Array.isArray(results)) {
      return;
    }
    for (const result of results) {
      if (!result || typeof result !== "object") {
        continue;
      }
      const record = result as CraterScriptExecutionResult;
      if (!record.error) {
        continue;
      }
      const message = record.message || (
        typeof record.status === "number"
          ? `Script failed to load with status ${record.status}`
          : "Script execution failed"
      );
      const prefix = record.src && record.src !== "inline" ? `${record.src}: ` : "";
      this.emitPageEvent("pageerror", new Error(`${prefix}${message}`));
    }
  }

  private waitForFunctionExpression<T, Arg>(
    pageFunction: string | ((arg: Arg) => T | Promise<T>),
    arg: Arg,
    hasArg: boolean,
  ): string {
    const argExpr = hasArg ? jsValue(arg) : "";
    return typeof pageFunction === "function"
      ? `(${pageFunction.toString()})(${argExpr})`
      : hasArg
      ? `(${pageFunction})(${argExpr})`
      : `(${pageFunction})`;
  }

  private async screenshotBidiParams(
    options: CraterScreenshotOptions,
    backend: "synthetic" | null,
  ): Promise<Record<string, unknown>> {
    const params: Record<string, unknown> = {
      context: this.requireContextId(),
      origin: options.fullPage ? "document" : "viewport",
    };
    if (backend) {
      params.backend = backend;
    }
    let clip = options.clip ?? null;
    if (!clip && options.fullPage) {
      const fullPageClip = await this.fullPageScreenshotClip();
      if (backend === "synthetic" || fullPageClip.height >= FULL_PAGE_SCREENSHOT_MAX_HEIGHT) {
        clip = fullPageClip;
      }
    }
    if (clip) {
      params.clip = {
        type: "box",
        x: clip.x,
        y: clip.y,
        width: clip.width,
        height: clip.height,
      };
    }
    if (options.type || options.quality !== undefined) {
      const format: Record<string, unknown> = {
        type: options.type === "jpeg" ? "image/jpeg" : "image/png",
      };
      if (options.quality !== undefined) {
        format.quality = Math.max(0, Math.min(1, options.quality / 100));
      }
      params.format = format;
    }
    return params;
  }

  private ariaSnapshotExpression(depth: number): string {
    const safeDepth = Math.max(0, Math.min(64, Math.floor(depth)));
    return `(() => {
      const maxDepth = ${safeDepth};
      const normalize = (value) => String(value ?? "").replace(/\\s+/g, " ").trim();
      const attr = (target, name) => {
        let value = null;
        try {
          if (target && typeof target.getAttribute === "function") value = target.getAttribute(name);
        } catch (_error) {}
        if ((value === null || value === undefined) && target && target._attrs) value = target._attrs[name];
        return value == null ? "" : String(value);
      };
      const hasAttr = (target, name) => {
        try {
          if (target && typeof target.hasAttribute === "function" && target.hasAttribute(name)) return true;
        } catch (_error) {}
        return Boolean(target && target._attrs && Object.prototype.hasOwnProperty.call(target._attrs, name));
      };
      const tagOf = (node) => String(node?.localName || node?.tagName || node?.nodeName || "").toLowerCase();
      const childrenOf = (node) => Array.from(node?._children || node?.children || node?.childNodes || [])
        .filter((child) => child && child.nodeType === 1);
      const textOf = (node) => normalize(
        node && node.innerText !== undefined && node.innerText !== null && String(node.innerText) !== ""
          ? node.innerText
          : node?.textContent || ""
      );
      const findById = (doc, id) => {
        if (!doc || !id) return null;
        try {
          if (typeof doc.getElementById === "function") {
            const found = doc.getElementById(id);
            if (found) return found;
          }
        } catch (_error) {}
        const stack = [doc.documentElement || doc.body || doc];
        while (stack.length > 0) {
          const current = stack.pop();
          if (!current) continue;
          if (current.nodeType === 1 && attr(current, "id") === id) return current;
          const children = Array.from(current._children || current.children || current.childNodes || []);
          for (let i = children.length - 1; i >= 0; i--) stack.push(children[i]);
        }
        return null;
      };
      const labelsFor = (target) => {
        const doc = target?.ownerDocument || globalThis.document;
        const id = attr(target, "id").trim();
        const labels = [];
        if (doc) {
          try {
            if (typeof doc.querySelectorAll === "function") {
              labels.push(...Array.from(doc.querySelectorAll("label")));
            }
          } catch (_error) {}
        }
        const parts = [];
        if (id) {
          for (const label of labels) {
            if (attr(label, "for") === id) {
              const text = textOf(label);
              if (text) parts.push(text);
            }
          }
        }
        let parent = target?._parent || target?.parentElement || target?.parentNode || null;
        while (parent) {
          if (parent.nodeType === 1 && tagOf(parent) === "label") {
            const text = textOf(parent);
            if (text) parts.push(text);
            break;
          }
          parent = parent._parent || parent.parentElement || parent.parentNode || null;
        }
        return parts.join(" ").trim();
      };
      const explicitRole = (node) => {
        const role = attr(node, "role").trim().split(/\\s+/).find(Boolean) || "";
        return role === "none" || role === "presentation" ? "" : role;
      };
      const implicitRole = (node) => {
        const tag = tagOf(node);
        if (tag === "a" && attr(node, "href").trim() !== "") return "link";
        if (tag === "button") return "button";
        if (tag === "textarea") return "textbox";
        if (tag === "select") return "combobox";
        if (tag === "option") return "option";
        if (tag === "img") return attr(node, "alt").trim() === "" ? "generic" : "img";
        if (tag === "main") return "main";
        if (tag === "nav") return "navigation";
        if (tag === "header") return "banner";
        if (tag === "footer") return "contentinfo";
        if (tag === "aside") return "complementary";
        if (tag === "article") return "article";
        if (tag === "form") return "form";
        if (tag === "dialog") return "dialog";
        if (tag === "ul" || tag === "ol") return "list";
        if (tag === "li") return "listitem";
        if (tag === "table") return "table";
        if (tag === "tr") return "row";
        if (tag === "td") return "cell";
        if (tag === "th") return "columnheader";
        if (/^h[1-6]$/.test(tag)) return "heading";
        if (tag === "input") {
          const type = attr(node, "type").trim().toLowerCase() || "text";
          if (type === "hidden") return "generic";
          if (type === "checkbox") return "checkbox";
          if (type === "radio") return "radio";
          if (type === "range") return "slider";
          if (type === "button" || type === "submit" || type === "reset") return "button";
          if (type === "search") return "searchbox";
          return "textbox";
        }
        if (tag === "progress") return "progressbar";
        if (tag === "meter") return "meter";
        if (tag === "section" && accessibleName(node, "region") !== "") return "region";
        return "generic";
      };
      const roleOf = (node) => explicitRole(node) || implicitRole(node);
      function accessibleName(node, role) {
        const labelledBy = attr(node, "aria-labelledby").trim();
        if (labelledBy) {
          const doc = node.ownerDocument || globalThis.document;
          const parts = [];
          for (const id of labelledBy.split(/\\s+/)) {
            const ref = findById(doc, id);
            const text = ref ? textOf(ref) : "";
            if (text) parts.push(text);
          }
          if (parts.length > 0) return parts.join(" ").trim();
        }
        const ariaLabel = attr(node, "aria-label").trim();
        if (ariaLabel) return ariaLabel;
        const tag = tagOf(node);
        if (tag === "img") return attr(node, "alt").trim();
        if (tag === "input" || tag === "textarea" || tag === "select") {
          const label = labelsFor(node);
          if (label) return label;
          const type = attr(node, "type").trim().toLowerCase();
          if (role === "button" && (type === "button" || type === "submit" || type === "reset")) {
            const value = attr(node, "value").trim();
            if (value) return value;
          }
        }
        if (role === "button" || role === "link" || role === "heading" || role === "listitem" || role === "option") {
          return textOf(node);
        }
        return "";
      }
      const isHidden = (node) => {
        if (!node || node.nodeType !== 1) return true;
        if (attr(node, "aria-hidden").trim().toLowerCase() === "true") return true;
        if (node.hidden || hasAttr(node, "hidden")) return true;
        let current = node;
        while (current && current.nodeType === 1) {
          const style = current.style || {};
          if (style.display === "none" || style.visibility === "hidden" || style.visibility === "collapse") return true;
          current = current.parentElement || current.parentNode || current._parent || null;
        }
        return false;
      };
      const boolAttr = (node, name) => attr(node, name).trim().toLowerCase() === "true";
      const isDisabled = (node) => Boolean(node?.disabled) || hasAttr(node, "disabled") || boolAttr(node, "aria-disabled");
      const buildElement = (node, currentDepth) => {
        if (!node || node.nodeType !== 1 || isHidden(node)) return [];
        const role = roleOf(node);
        const name = accessibleName(node, role);
        const result = { role };
        if (name) result.name = name;
        const description = attr(node, "aria-description").trim() || attr(node, "title").trim();
        if (description) result.description = description;
        const ariaExpanded = attr(node, "aria-expanded").trim().toLowerCase();
        if (ariaExpanded === "true" || ariaExpanded === "false") result.expanded = ariaExpanded === "true";
        const ariaChecked = attr(node, "aria-checked").trim().toLowerCase();
        if (ariaChecked === "mixed") result.checked = "mixed";
        else if (ariaChecked === "true" || ariaChecked === "false") result.checked = ariaChecked === "true";
        else if (role === "checkbox" || role === "radio") result.checked = Boolean(node.checked) || hasAttr(node, "checked");
        if (isDisabled(node)) result.disabled = true;
        const ariaSelected = attr(node, "aria-selected").trim().toLowerCase();
        if (ariaSelected === "true" || ariaSelected === "false") result.selected = ariaSelected === "true";
        else if (role === "option" && (Boolean(node.selected) || hasAttr(node, "selected"))) result.selected = true;
        if (boolAttr(node, "aria-modal")) result.modal = true;
        if (role === "textbox" || role === "searchbox" || role === "slider" || role === "progressbar") {
          const value = normalize(node.value !== undefined ? node.value : attr(node, "value"));
          if (value) result.value = value;
        }
        const childSnapshots = [];
        if (currentDepth < maxDepth) {
          for (const child of childrenOf(node)) {
            childSnapshots.push(...buildElement(child, currentDepth + 1));
          }
        }
        if (childSnapshots.length > 0) result.children = childSnapshots;
        const hasState = result.value !== undefined || result.description !== undefined ||
          result.modal !== undefined || result.expanded !== undefined ||
          result.checked !== undefined || result.disabled !== undefined ||
          result.selected !== undefined;
        if (role === "generic" && !name && !hasState) {
          return childSnapshots;
        }
        return [result];
      };
      const rootElement = document.body || document.documentElement;
      const root = { role: "document" };
      const title = normalize(document.title || "");
      if (title) root.name = title;
      const children = rootElement ? buildElement(rootElement, 0) : [];
      if (children.length > 0) root.children = children;
      return JSON.stringify(root);
    })()`;
  }

  private async fullPageScreenshotClip(): Promise<CraterScreenshotClip> {
    return await this.evaluate<CraterScreenshotClip>(`
      (() => {
        const win = globalThis.window || globalThis;
        const viewportWidth = Number(win.innerWidth || globalThis.innerWidth || 1);
        const viewportHeight = Number(win.innerHeight || globalThis.innerHeight || 1);
        let width = viewportWidth > 0 ? viewportWidth : 1;
        let height = viewportHeight > 0 ? viewportHeight : 1;
        const px = (value) => {
          const parsed = Number.parseFloat(String(value ?? ""));
          return Number.isFinite(parsed) ? parsed : 0;
        };
        const visit = (el) => {
          if (!el) return;
          width = Math.max(
            width,
            Number(el.scrollWidth || 0),
            Number(el.clientWidth || 0),
            Number(el.offsetWidth || 0),
          );
          height = Math.max(
            height,
            Number(el.scrollHeight || 0),
            Number(el.clientHeight || 0),
            Number(el.offsetHeight || 0),
          );
          const style = el.style || {};
          let left = px(style.left) + px(style.marginLeft);
          let top = px(style.top) + px(style.marginTop);
          let rectWidth = px(style.width);
          let rectHeight = px(style.height);
          if (typeof el.getBoundingClientRect === "function") {
            try {
              const rect = el.getBoundingClientRect();
              left = Number(rect.left ?? rect.x ?? left) || left;
              top = Number(rect.top ?? rect.y ?? top) || top;
              rectWidth = Number(rect.width ?? ((rect.right ?? 0) - (rect.left ?? 0))) || rectWidth;
              rectHeight = Number(rect.height ?? ((rect.bottom ?? 0) - (rect.top ?? 0))) || rectHeight;
            } catch (_e) {}
          }
          width = Math.max(width, left + Math.max(0, rectWidth));
          height = Math.max(height, top + Math.max(0, rectHeight));
        };
        visit(document.documentElement);
        visit(document.body);
        for (const el of Array.from(document.querySelectorAll("body *"))) {
          visit(el);
        }
        const cappedHeight = Math.min(
          ${FULL_PAGE_SCREENSHOT_MAX_HEIGHT},
          Math.max(1, Math.ceil(height)),
        );
        return {
          x: 0,
          y: 0,
          width: Math.max(1, Math.ceil(width)),
          height: cappedHeight,
        };
      })()
    `);
  }

  private async withOperationTimeout<T>(
    promise: Promise<T>,
    timeout: number | undefined,
    label: string,
  ): Promise<T> {
    if (timeout === undefined || timeout === 0) {
      return await promise;
    }
    let timer: ReturnType<typeof setTimeout> | null = null;
    try {
      return await Promise.race([
        promise,
        new Promise<never>((_resolve, reject) => {
          timer = setTimeout(() => {
            reject(new Error(`Timeout waiting for response to ${label}`));
          }, timeout);
        }),
      ]);
    } finally {
      if (timer) {
        clearTimeout(timer);
      }
    }
  }

  private async runInitScripts(): Promise<void> {
    for (const script of this.initScripts) {
      await this.evaluate(script, {
        awaitPromise: script.includes("await ") || script.includes("new Promise") || script.includes(".then("),
      });
    }
  }

  private async resolveInjectableContent(
    options: CraterAddScriptTagOptions | CraterAddStyleTagOptions,
    kind: "script" | "style",
  ): Promise<string> {
    if (options.content !== undefined) {
      return options.content;
    }
    if (options.url) {
      return this.evaluate<string>(
        `(async () => await (await fetch(${jsString(options.url!)})).text())()`,
        { awaitPromise: true },
      );
    }
    throw new Error(`add${kind === "script" ? "Script" : "Style"}Tag requires content or url`);
  }

  private urlMatches(current: string, expected: CraterUrlMatcher): boolean {
    if (typeof expected === "string") {
      return current === expected || current.includes(expected);
    }
    if (expected instanceof RegExp) {
      return expected.test(current);
    }
    return expected(new URL(current));
  }

  private handleMessage(data: string): void {
    const message = JSON.parse(data) as { type?: string; id?: number; method?: string } & Record<string, unknown>;
    if (message.type === "event") {
      this.handleEventMessage(message as unknown as BidiEvent);
      return;
    }
    const pending = typeof message.id === "number" ? this.pendingCommands.get(message.id) : null;
    if (!pending) {
      return;
    }
    this.pendingCommands.delete(message.id as number);
    pending.resolve(message as unknown as BidiResponse);
  }

  private handleEventMessage(event: BidiEvent): void {
    if (event.method === "browsingContext.userPromptOpened") {
      const dialog = this.dialogPageEventPayload(event.params);
      if (dialog) {
        this.emitPageEvent("dialog", dialog);
      }
    }
    if (event.method === "browsingContext.downloadWillBegin") {
      this.emitDownloadWillBegin(event.params);
    }
    if (event.method === "browsingContext.downloadEnd") {
      this.resolveDownloadEnd(event.params);
    }
    if (event.method === "log.entryAdded") {
      const message = this.consolePageEventPayloadFromLogEntry(event.params);
      if (message) {
        this.emitPageEvent("console", message);
      }
    }
    if (event.method === "browsingContext.load" || event.method === "browsingContext.domContentLoaded") {
      if (this.navigationResolve) {
        this.navigationResolve();
        this.navigationResolve = null;
        this.navigationPromise = null;
      }
      this.emitPageEvent(
        event.method === "browsingContext.load" ? "load" : "domcontentloaded",
        this,
      );
    }
    for (const handler of this.eventHandlers) {
      handler(event);
    }
  }

  private async sendBidi(method: string, params: unknown): Promise<BidiResponse> {
    if (this.sharedConnection) {
      return this.sharedConnection.sendBidi(method, params);
    }
    if (!this.ws) {
      throw new Error("Not connected");
    }
    const releaseRuntimeLock = await this.acquireRuntimeLock(method, params);
    const id = ++this.commandId;
    const payload = JSON.stringify({ id, method, params });
    try {
      return await new Promise<BidiResponse>((resolve, reject) => {
        this.pendingCommands.set(id, { resolve, reject });
        this.ws!.send(payload);
        const timeoutMs = method === "browsingContext.capturePaintData" ? 300000 : 10000;
        const timeoutLabel = bidiCommandTimeoutLabel(method, params);
        setTimeout(() => {
          if (this.pendingCommands.has(id)) {
            this.pendingCommands.delete(id);
            reject(new Error(`Timeout waiting for response to ${timeoutLabel}`));
          }
        }, timeoutMs);
      });
    } finally {
      releaseRuntimeLock();
    }
  }

  private async acquireRuntimeLock(method: string, params: unknown): Promise<() => void> {
    const context = bidiCommandContext(method, params);
    while (
      this.runtimeLockContext !== null &&
      (context === null || this.runtimeLockContext !== context)
    ) {
      await this.runtimeLockSettled;
    }
    if (!isAwaitedScriptEvaluate(method, params) || context === null) {
      return () => {};
    }
    if (this.runtimeLockContext === null) {
      this.runtimeLockContext = context;
      this.runtimeLockSettled = new Promise<void>((resolve) => {
        this.runtimeLockRelease = resolve;
      });
    }
    this.runtimeLockCount += 1;
    let released = false;
    return () => {
      if (released) {
        return;
      }
      released = true;
      this.runtimeLockCount = Math.max(0, this.runtimeLockCount - 1);
      if (this.runtimeLockCount === 0 && this.runtimeLockContext === context) {
        this.runtimeLockContext = null;
        const release = this.runtimeLockRelease;
        this.runtimeLockRelease = null;
        release?.();
      }
    };
  }
}

export class CraterBrowserContext {
  private readonly pageList: CraterBidiPage[] = [];
  private readonly cookieStore: CraterStorageCookie[] = [];
  private readonly localStorageStore = new Map<string, Map<string, string>>();
  private readonly initScripts: CraterInitScript[] = [];
  private readonly permissionGrants: CraterPermissionGrant[] = [];
  private readonly appliedPermissionKeys = new Set<string>();
  private routes: CraterRouteEntry[] = [];
  private defaultTimeout: number | undefined;
  private offlineOverride: boolean | undefined;
  private geolocationOverride: CraterGeolocation | null | undefined;
  private initialStorageStateLoaded = false;
  private transportPage: CraterBidiPage | null = null;
  private closed = false;

  constructor(
    private readonly contextOptions: CraterBrowserContextOptions = {},
    private readonly closeHandler: CraterContextCloseHandler | null = null,
    private readonly transportProvider: CraterTransportProvider | null = null,
  ) {
    this.offlineOverride = contextOptions.offline;
    this.geolocationOverride = contextOptions.geolocation;
    if (contextOptions.permissions && contextOptions.permissions.length > 0) {
      this.permissionGrants.push({
        permissions: this.normalizePermissions(contextOptions.permissions),
      });
    }
  }

  async newPage(options: CraterBidiConnectOptions = {}): Promise<CraterBidiPage> {
    if (this.closed) {
      throw new Error("Browser context is closed");
    }
    await this.ensureInitialStorageStateLoaded();
    const transport = await this.ensureTransportPage(options);
    const shouldResetRuntimeStorage = this.pageList.length === 0;
    const page = await transport.createSiblingPage((closedPage) => this.removePage(closedPage));
    if (shouldResetRuntimeStorage) {
      await this.resetRuntimeStorageForPage(page);
    }
    this.pageList.push(page);
    this.attachContextPageHooks(page);
    await this.installLocalStorageInitScript(page);
    await this.applyInitScriptsToPage(page);
    await this.applyStoredCookiesToPage(page);
    await this.applyStoredLocalStorageToPage(page);
    await this.applyRoutesToPage(page);
    await this.applyContextOptionsToPage(page);
    await this.applyPermissionGrantsToPage(page);
    this.applyDefaultTimeoutToPage(page);
    return page;
  }

  pages(): CraterBidiPage[] {
    return [...this.pageList];
  }

  async cookies(urls?: CraterCookieUrlFilter): Promise<CraterStorageCookie[]> {
    if (this.closed) {
      throw new Error("Browser context is closed");
    }
    const cookies = await this.collectCookies();
    return this.filterCookiesByUrls(cookies, urls);
  }

  async addCookies(cookies: CraterStorageCookie[]): Promise<void> {
    if (this.closed) {
      throw new Error("Browser context is closed");
    }
    await this.ensureInitialStorageStateLoaded();
    for (const cookie of cookies) {
      const normalized = this.normalizeCookie(cookie);
      this.upsertStoredCookie(normalized);
      for (const page of this.pageList) {
        await this.setStorageCookieForPage(page, normalized);
      }
    }
  }

  async clearCookies(options: CraterClearCookiesOptions = {}): Promise<void> {
    if (this.closed) {
      throw new Error("Browser context is closed");
    }
    await this.ensureInitialStorageStateLoaded();
    const cookiesToDelete = (await this.collectCookies()).filter((cookie) =>
      this.cookieMatchesClearOptions(cookie, options)
    );
    const deleteKeys = new Set(cookiesToDelete.map((cookie) => this.cookieKey(cookie)));
    for (let index = this.cookieStore.length - 1; index >= 0; index -= 1) {
      if (deleteKeys.has(this.cookieKey(this.cookieStore[index]))) {
        this.cookieStore.splice(index, 1);
      }
    }
    for (const page of this.pageList) {
      for (const cookie of cookiesToDelete) {
        await this.deleteCookieForPage(page, cookie);
      }
    }
  }

  async grantPermissions(
    permissions: string[],
    options: CraterGrantPermissionsOptions = {},
  ): Promise<void> {
    if (this.closed) {
      throw new Error("Browser context is closed");
    }
    const grant: CraterPermissionGrant = {
      permissions: this.normalizePermissions(permissions),
      origin: options.origin === undefined
        ? undefined
        : this.normalizePermissionOrigin(options.origin),
    };
    for (const page of this.pageList) {
      await this.applyPermissionGrantToPage(page, grant);
    }
    this.permissionGrants.push(grant);
  }

  async clearPermissions(): Promise<void> {
    if (this.closed) {
      throw new Error("Browser context is closed");
    }
    const keys = new Set(this.appliedPermissionKeys);
    const permissionNames = new Set<string>();
    for (const page of this.pageList) {
      const origin = await this.permissionOriginForPage(page);
      for (const grant of this.permissionGrants) {
        for (const permission of grant.permissions) {
          permissionNames.add(permission);
          keys.add(this.permissionKey(permission, grant.origin ?? origin));
        }
      }
    }
    this.permissionGrants.splice(0, this.permissionGrants.length);
    for (const key of keys) {
      const [permission, origin] = key.split("\0");
      if (permission && origin !== undefined) {
        await this.setPermissionState(permission, "prompt", origin);
      }
    }
    for (const page of this.pageList) {
      for (const permission of permissionNames) {
        await this.setPermissionRuntimeStateForPage(page, permission, "prompt");
      }
    }
    this.appliedPermissionKeys.clear();
  }

  async setGeolocation(geolocation: CraterGeolocation | null): Promise<void> {
    if (this.closed) {
      throw new Error("Browser context is closed");
    }
    this.geolocationOverride = geolocation === null
      ? null
      : this.normalizeGeolocation(geolocation);
    for (const page of this.pageList) {
      await this.applyGeolocationToPage(page);
    }
  }

  async route(matcher: CraterRequestMatcher, handler: CraterRouteHandler): Promise<void> {
    if (this.closed) {
      throw new Error("Browser context is closed");
    }
    const entry = { matcher, handler };
    this.routes.push(entry);
    for (const page of this.pageList) {
      await page.route(matcher, handler);
    }
  }

  async addInitScript(script: CraterInitScript): Promise<void> {
    if (this.closed) {
      throw new Error("Browser context is closed");
    }
    this.initScripts.push(script);
    for (const page of this.pageList) {
      await page.addInitScript(script);
    }
  }

  setDefaultTimeout(timeout: number): void {
    if (this.closed) {
      throw new Error("Browser context is closed");
    }
    if (!Number.isFinite(timeout) || timeout < 0) {
      throw new Error(`Invalid timeout: ${timeout}`);
    }
    this.defaultTimeout = timeout;
    for (const page of this.pageList) {
      page.setDefaultTimeout(timeout);
    }
  }

  async setOffline(offline: boolean): Promise<void> {
    if (this.closed) {
      throw new Error("Browser context is closed");
    }
    this.offlineOverride = offline;
    for (const page of this.pageList) {
      await this.applyOfflineToPage(page);
    }
  }

  async unroute(matcher?: CraterRequestMatcher): Promise<void> {
    if (this.closed) {
      throw new Error("Browser context is closed");
    }
    if (matcher === undefined) {
      this.routes = [];
    } else {
      this.routes = this.routes.filter((entry) => entry.matcher !== matcher);
    }
    for (const page of this.pageList) {
      await page.unroute(matcher);
    }
  }

  async storageState(options: CraterStorageStateOptions = {}): Promise<CraterStorageState> {
    if (this.closed) {
      throw new Error("Browser context is closed");
    }
    await this.ensureInitialStorageStateLoaded();
    const state: CraterStorageState = {
      cookies: [],
      origins: [],
    };
    const cookiesByKey = new Map<string, CraterStorageCookie>();
    const originsByOrigin = new Map<string, Map<string, string>>();
    for (const cookie of this.cookieStore) {
      cookiesByKey.set(this.cookieKey(cookie), cookie);
    }
    for (const [origin, entries] of this.localStorageStore) {
      originsByOrigin.set(origin, new Map(entries));
    }
    for (const page of this.pageList) {
      const snapshot = await page.evaluate<string>(`
        (() => {
          const origin = location.origin && location.origin !== "null" ? location.origin : location.href;
          const localStorage = [];
          try {
            for (let i = 0; i < globalThis.localStorage.length; i += 1) {
              const name = globalThis.localStorage.key(i);
              if (name !== null) {
                localStorage.push({ name, value: String(globalThis.localStorage.getItem(name) ?? "") });
              }
            }
          } catch (_e) {}
          const host = String(location.hostname || "");
          const secure = String(location.protocol || "") === "https:";
          const cookies = String(document.cookie || "")
            .split(";")
            .map((part) => part.trim())
            .filter(Boolean)
            .map((part) => {
              const eq = part.indexOf("=");
              const name = eq === -1 ? part : part.slice(0, eq);
              const value = eq === -1 ? "" : part.slice(eq + 1);
              return { name, value, domain: host, path: "/", expires: -1, httpOnly: false, secure, sameSite: "Lax" };
            });
          return JSON.stringify({ origin, localStorage, cookies });
        })()
      `);
      const parsed = JSON.parse(snapshot) as {
        origin?: string;
        localStorage?: Array<{ name: string; value: string }>;
        cookies?: CraterStorageCookie[];
      };
      const origin = parsed.origin || "about:blank";
      if (Array.isArray(parsed.localStorage) && parsed.localStorage.length > 0) {
        const entries = originsByOrigin.get(origin) ?? new Map<string, string>();
        for (const entry of parsed.localStorage) {
          entries.set(entry.name, entry.value);
        }
        originsByOrigin.set(origin, entries);
      }
      for (const cookie of parsed.cookies ?? []) {
        const key = `${cookie.domain}\t${cookie.path}\t${cookie.name}`;
        cookiesByKey.set(key, cookie);
      }
    }
    state.cookies = [...cookiesByKey.values()].sort((a, b) =>
      `${a.domain}\t${a.path}\t${a.name}`.localeCompare(`${b.domain}\t${b.path}\t${b.name}`)
    );
    state.origins = [...originsByOrigin.entries()]
      .sort(([a], [b]) => a.localeCompare(b))
      .map(([origin, entries]) => ({
        origin,
        localStorage: [...entries.entries()]
          .sort(([a], [b]) => a.localeCompare(b))
          .map(([name, value]) => ({ name, value })),
      }));
    if (options.path) {
      await writeFile(options.path, JSON.stringify(state, null, 2));
    }
    return state;
  }

  async close(): Promise<void> {
    if (this.closed) {
      return;
    }
    this.closed = true;
    const pages = this.pageList.splice(0, this.pageList.length);
    const transport = this.transportProvider ? null : this.transportPage;
    this.transportPage = null;
    await Promise.all(pages.map((page) => page.close()));
    if (transport) {
      await transport.close();
    }
    this.closeHandler?.(this);
  }

  private async ensureTransportPage(options: CraterBidiConnectOptions): Promise<CraterBidiPage> {
    if (this.transportProvider) {
      return await this.transportProvider({ ...this.connectionOptions(), ...options });
    }
    if (!this.transportPage) {
      const transport = new CraterBidiPage();
      await transport.connect({ ...this.connectionOptions(), ...options });
      this.transportPage = transport;
    }
    return this.transportPage;
  }

  private connectionOptions(): CraterBidiConnectOptions {
    const {
      storageState: _storageState,
      viewport: _viewport,
      userAgent: _userAgent,
      locale: _locale,
      offline: _offline,
      geolocation: _geolocation,
      permissions: _permissions,
      ...options
    } = this.contextOptions;
    return options;
  }

  private async ensureInitialStorageStateLoaded(): Promise<void> {
    if (this.initialStorageStateLoaded) {
      return;
    }
    this.initialStorageStateLoaded = true;
    const state = await this.resolveInitialStorageState();
    if (!state) {
      return;
    }
    for (const cookie of state.cookies ?? []) {
      this.upsertStoredCookie(this.normalizeCookie(cookie));
    }
    for (const origin of state.origins ?? []) {
      if (!origin || typeof origin.origin !== "string") {
        continue;
      }
      const entries = this.localStorageStore.get(origin.origin) ?? new Map<string, string>();
      for (const entry of origin.localStorage ?? []) {
        entries.set(String(entry.name), String(entry.value));
      }
      this.localStorageStore.set(origin.origin, entries);
    }
  }

  private async resolveInitialStorageState(): Promise<CraterStorageState | null> {
    const source = this.contextOptions.storageState;
    if (!source) {
      return null;
    }
    if (typeof source === "string") {
      return JSON.parse(await readFile(source, "utf8")) as CraterStorageState;
    }
    return source;
  }

  private removePage(page: CraterBidiPage): void {
    const index = this.pageList.indexOf(page);
    if (index !== -1) {
      this.pageList.splice(index, 1);
    }
  }

  private async collectCookies(): Promise<CraterStorageCookie[]> {
    await this.ensureInitialStorageStateLoaded();
    const cookiesByKey = new Map<string, CraterStorageCookie>();
    for (const cookie of this.cookieStore) {
      cookiesByKey.set(this.cookieKey(cookie), cookie);
    }
    for (const page of this.pageList) {
      const resp = await this.sendBidi("storage.getCookies", {
        partition: { type: "context", context: this.pageContextId(page) },
      });
      const rawCookies = (resp.result as { cookies?: unknown[] } | undefined)?.cookies ?? [];
      for (const rawCookie of rawCookies) {
        const cookie = this.cookieFromStorage(rawCookie);
        if (cookie) {
          cookiesByKey.set(this.cookieKey(cookie), cookie);
        }
      }
    }
    return [...cookiesByKey.values()].sort((a, b) =>
      `${a.domain}\t${a.path}\t${a.name}`.localeCompare(`${b.domain}\t${b.path}\t${b.name}`)
    );
  }

  private filterCookiesByUrls(
    cookies: CraterStorageCookie[],
    urls: CraterCookieUrlFilter | undefined,
  ): CraterStorageCookie[] {
    if (urls === undefined) {
      return cookies;
    }
    const urlList = Array.isArray(urls) ? urls : [urls];
    return cookies.filter((cookie) =>
      urlList.some((url) => this.cookieMatchesUrl(cookie, url))
    );
  }

  private cookieMatchesUrl(cookie: CraterStorageCookie, url: string): boolean {
    let parsed: URL;
    try {
      parsed = new URL(url);
    } catch {
      return false;
    }
    const domain = stripLeadingDot(String(cookie.domain ?? "")).toLowerCase();
    const host = parsed.hostname.toLowerCase();
    if (domain && host !== domain && !host.endsWith(`.${domain}`)) {
      return false;
    }
    const path = String(cookie.path || "/");
    if (!parsed.pathname.startsWith(path)) {
      return false;
    }
    if (cookie.secure && parsed.protocol !== "https:") {
      return false;
    }
    return true;
  }

  private cookieMatchesClearOptions(
    cookie: CraterStorageCookie,
    options: CraterClearCookiesOptions,
  ): boolean {
    return this.cookieFieldMatches(cookie.name, options.name) &&
      this.cookieFieldMatches(String(cookie.domain ?? ""), options.domain) &&
      this.cookieFieldMatches(String(cookie.path ?? "/"), options.path);
  }

  private cookieFieldMatches(value: string, matcher: string | RegExp | undefined): boolean {
    if (matcher === undefined) {
      return true;
    }
    return typeof matcher === "string" ? value === matcher : matcher.test(value);
  }

  private attachContextPageHooks(page: CraterBidiPage): void {
    page.on("load", () => {
      void this.applyOriginlessPermissionGrantsToPage(page).catch(() => {});
    });
  }

  private async applyStoredCookiesToPage(page: CraterBidiPage): Promise<void> {
    for (const cookie of this.cookieStore) {
      await this.setStorageCookieForPage(page, cookie);
    }
  }

  private async installLocalStorageInitScript(page: CraterBidiPage): Promise<void> {
    if (this.localStorageStore.size === 0) {
      return;
    }
    await page.addInitScript(this.localStoragePreloadScript());
  }

  private async applyInitScriptsToPage(page: CraterBidiPage): Promise<void> {
    for (const script of this.initScripts) {
      await page.addInitScript(script);
    }
  }

  private async applyStoredLocalStorageToPage(page: CraterBidiPage): Promise<void> {
    if (this.localStorageStore.size === 0) {
      return;
    }
    await page.evaluate(this.localStoragePreloadScript());
  }

  private async resetRuntimeStorageForPage(page: CraterBidiPage): Promise<void> {
    await page.evaluate(`
      (() => {
        try { globalThis.localStorage && globalThis.localStorage.clear(); } catch (_e) {}
        try { globalThis.sessionStorage && globalThis.sessionStorage.clear(); } catch (_e) {}
      })()
    `);
  }

  private async applyRoutesToPage(page: CraterBidiPage): Promise<void> {
    for (const route of this.routes) {
      await page.route(route.matcher, route.handler);
    }
  }

  private async applyContextOptionsToPage(page: CraterBidiPage): Promise<void> {
    const viewport = this.contextOptions.viewport;
    if (viewport) {
      await page.setViewport(viewport.width, viewport.height);
    }
    if (this.contextOptions.userAgent !== undefined) {
      await this.sendBidi("emulation.setUserAgentOverride", {
        contexts: [this.pageContextId(page)],
        userAgent: this.contextOptions.userAgent,
      });
    }
    if (this.contextOptions.locale !== undefined) {
      await this.sendBidi("emulation.setLocaleOverride", {
        contexts: [this.pageContextId(page)],
        locale: this.contextOptions.locale,
      });
    }
    await this.applyOfflineToPage(page);
    await this.applyGeolocationToPage(page);
  }

  private applyDefaultTimeoutToPage(page: CraterBidiPage): void {
    if (this.defaultTimeout !== undefined) {
      page.setDefaultTimeout(this.defaultTimeout);
    }
  }

  private async applyOfflineToPage(page: CraterBidiPage): Promise<void> {
    if (this.offlineOverride === undefined) {
      return;
    }
    await this.sendBidi("emulation.setNetworkConditions", {
      contexts: [this.pageContextId(page)],
      networkConditions: this.offlineOverride ? { type: "offline" } : null,
    });
  }

  private async applyGeolocationToPage(page: CraterBidiPage): Promise<void> {
    if (this.geolocationOverride === undefined) {
      return;
    }
    await this.sendBidi("emulation.setGeolocationOverride", {
      contexts: [this.pageContextId(page)],
      coordinates: this.geolocationOverride === null ? null : this.geolocationOverride,
    });
    await this.setGeolocationRuntimeStateForPage(page, this.geolocationOverride);
  }

  private async applyPermissionGrantsToPage(page: CraterBidiPage): Promise<void> {
    for (const grant of this.permissionGrants) {
      await this.applyPermissionGrantToPage(page, grant);
    }
  }

  private async applyOriginlessPermissionGrantsToPage(page: CraterBidiPage): Promise<void> {
    if (this.closed) {
      return;
    }
    for (const grant of this.permissionGrants) {
      if (grant.origin === undefined) {
        await this.applyPermissionGrantToPage(page, grant);
      }
    }
  }

  private async applyPermissionGrantToPage(
    page: CraterBidiPage,
    grant: CraterPermissionGrant,
  ): Promise<void> {
    const origin = grant.origin ?? await this.permissionOriginForPage(page);
    for (const permission of grant.permissions) {
      await this.setPermissionState(permission, "granted", origin);
      await this.setPermissionRuntimeStateForPage(page, permission, "granted");
    }
  }

  private async setPermissionState(
    permission: string,
    state: CraterPermissionState,
    origin: string,
  ): Promise<void> {
    const normalizedOrigin = this.normalizePermissionOrigin(origin);
    await this.sendBidi("permissions.setPermission", {
      descriptor: { name: permission },
      state,
      origin: normalizedOrigin,
    });
    if (state === "prompt") {
      this.appliedPermissionKeys.delete(this.permissionKey(permission, normalizedOrigin));
    } else {
      this.appliedPermissionKeys.add(this.permissionKey(permission, normalizedOrigin));
    }
  }

  private async permissionOriginForPage(page: CraterBidiPage): Promise<string> {
    const resp = await this.sendBidi("browsingContext.getRequestedNavigationUrl", {
      context: this.pageContextId(page),
    });
    const url = (resp.result as { url?: unknown } | undefined)?.url;
    return this.permissionOriginFromUrl(typeof url === "string" ? url : "about:blank");
  }

  private permissionOriginFromUrl(url: string): string {
    if (url.startsWith("about:")) {
      return "null";
    }
    if (url.startsWith("data:")) {
      return url.includes("#domain=alt")
        ? "http://alt.localhost:8000"
        : "http://localhost:8000";
    }
    if (url.startsWith("http://") || url.startsWith("https://")) {
      try {
        return new URL(url).origin;
      } catch {
        return "null";
      }
    }
    return "null";
  }

  private normalizePermissionOrigin(origin: string): string {
    if (origin === "null") {
      return "null";
    }
    try {
      return new URL(origin).origin;
    } catch {
      return origin.replace(/\/$/, "");
    }
  }

  private permissionKey(permission: string, origin: string): string {
    return `${permission}\0${this.normalizePermissionOrigin(origin)}`;
  }

  private normalizePermissions(permissions: string[]): string[] {
    if (!Array.isArray(permissions)) {
      throw new Error("permissions must be an array");
    }
    const normalized = permissions.map((permission) => String(permission));
    const unsupported = normalized.filter((permission) => !CRATER_SUPPORTED_PERMISSIONS.has(permission));
    if (unsupported.length > 0) {
      throw new Error(`Unsupported permissions: ${unsupported.join(", ")}`);
    }
    return normalized;
  }

  private normalizeGeolocation(geolocation: CraterGeolocation): CraterGeolocation {
    return {
      latitude: Number(geolocation.latitude),
      longitude: Number(geolocation.longitude),
      ...(geolocation.accuracy === undefined ? {} : { accuracy: Number(geolocation.accuracy) }),
      ...(geolocation.altitude === undefined ? {} : { altitude: Number(geolocation.altitude) }),
      ...(geolocation.altitudeAccuracy === undefined
        ? {}
        : { altitudeAccuracy: Number(geolocation.altitudeAccuracy) }),
      ...(geolocation.heading === undefined ? {} : { heading: Number(geolocation.heading) }),
      ...(geolocation.speed === undefined ? {} : { speed: Number(geolocation.speed) }),
    };
  }

  private async setPermissionRuntimeStateForPage(
    page: CraterBidiPage,
    permission: string,
    state: CraterPermissionState,
  ): Promise<void> {
    await this.installRuntimeOverrideStubs(page);
    await page.evaluate(
      `(() => {
        globalThis.__craterPlaywrightPermissions[${jsValue(permission)}] = ${jsValue(state)};
      })()`,
    );
  }

  private async setGeolocationRuntimeStateForPage(
    page: CraterBidiPage,
    geolocation: CraterGeolocation | null,
  ): Promise<void> {
    await this.installRuntimeOverrideStubs(page);
    await page.evaluate(
      `(() => {
        globalThis.__craterPlaywrightGeolocation = ${jsValue(geolocation)};
      })()`,
    );
  }

  private async installRuntimeOverrideStubs(page: CraterBidiPage): Promise<void> {
    await page.evaluate(`
      (() => {
        if (!globalThis.__craterPlaywrightPermissions) {
          globalThis.__craterPlaywrightPermissions = {};
        }
        if (!("navigator" in globalThis) || !globalThis.navigator) {
          globalThis.navigator = {};
        }
        const navigator = globalThis.navigator;
        if (!navigator.permissions) {
          navigator.permissions = {};
        }
        navigator.permissions.query = (descriptor) => {
          const name = descriptor && descriptor.name ? String(descriptor.name) : "";
          const state = globalThis.__craterPlaywrightPermissions[name] || "prompt";
          return Promise.resolve({
            name,
            state,
            onchange: null,
            addEventListener() {},
            removeEventListener() {},
            dispatchEvent() { return true; },
          });
        };
        if (!navigator.geolocation) {
          navigator.geolocation = {};
        }
        if (!globalThis.__craterPlaywrightGeolocationWatchIds) {
          globalThis.__craterPlaywrightGeolocationWatchIds = new Map();
          globalThis.__craterPlaywrightNextGeolocationWatchId = 1;
        }
        const defaultCoordinates = {
          latitude: 35.6895,
          longitude: 139.6917,
          accuracy: 1,
        };
        const currentCoordinates = () => (
          globalThis.__craterPlaywrightGeolocation || defaultCoordinates
        );
        const currentPosition = () => {
          const raw = currentCoordinates();
          const coords = {
            latitude: Number(raw.latitude),
            longitude: Number(raw.longitude),
            accuracy: raw.accuracy === undefined ? 1 : Number(raw.accuracy),
          };
          for (const key of ["altitude", "altitudeAccuracy", "heading", "speed"]) {
            if (raw[key] !== undefined) coords[key] = Number(raw[key]);
          }
          coords.toJSON = () => {
            const json = {};
            for (const key of ["latitude", "longitude", "accuracy", "altitude", "altitudeAccuracy", "heading", "speed"]) {
              if (coords[key] !== undefined) json[key] = coords[key];
            }
            return json;
          };
          return { coords, timestamp: Date.now() };
        };
        const deniedError = () => ({
          code: 1,
          message: "User denied Geolocation",
          PERMISSION_DENIED: 1,
          POSITION_UNAVAILABLE: 2,
          TIMEOUT: 3,
        });
        navigator.geolocation.getCurrentPosition = (success, error) => {
          if (globalThis.__craterPlaywrightPermissions.geolocation !== "granted") {
            if (typeof error === "function") error(deniedError());
            return;
          }
          if (typeof success === "function") success(currentPosition());
        };
        navigator.geolocation.watchPosition = (success, error) => {
          const id = Number(globalThis.__craterPlaywrightNextGeolocationWatchId || 1);
          globalThis.__craterPlaywrightNextGeolocationWatchId = id + 1;
          const emit = () => {
            if (globalThis.__craterPlaywrightPermissions.geolocation !== "granted") {
              if (typeof error === "function") error(deniedError());
              return;
            }
            if (typeof success === "function") success(currentPosition());
          };
          const timer = setTimeout(emit, 0);
          globalThis.__craterPlaywrightGeolocationWatchIds.set(id, timer);
          return id;
        };
        navigator.geolocation.clearWatch = (id) => {
          const timer = globalThis.__craterPlaywrightGeolocationWatchIds.get(Number(id));
          if (timer !== undefined) clearTimeout(timer);
          globalThis.__craterPlaywrightGeolocationWatchIds.delete(Number(id));
        };
      })()
    `);
  }

  private localStoragePreloadScript(): string {
    const stores = Object.fromEntries(
      [...this.localStorageStore.entries()].map(([origin, entries]) => [
        origin,
        Object.fromEntries(entries),
      ]),
    );
    return `
      (() => {
        const stores = ${JSON.stringify(stores)};
        const origin = location.origin && location.origin !== "null" ? location.origin : location.href;
        const entries = stores[origin] || stores[location.href] || stores["about:blank"];
        if (!entries) return;
        for (const [name, value] of Object.entries(entries)) {
          localStorage.setItem(name, String(value));
        }
      })()
    `;
  }

  private async setStorageCookieForPage(page: CraterBidiPage, cookie: CraterStorageCookie): Promise<void> {
    const storageCookie: Record<string, unknown> = {
      name: cookie.name,
      value: { type: "string", value: cookie.value },
      domain: stripLeadingDot(String(cookie.domain ?? "localhost")),
      path: cookie.path || "/",
      httpOnly: cookie.httpOnly === true,
      secure: cookie.secure === true,
      sameSite: storageSameSite(cookie.sameSite),
    };
    const expires = cookie.expires;
    if (Number.isFinite(expires) && expires !== undefined && expires >= 0) {
      storageCookie.expiry = expires;
    }
    await this.sendBidi("storage.setCookie", {
      cookie: storageCookie,
      partition: { type: "context", context: this.pageContextId(page) },
    });
  }

  private async deleteCookieForPage(page: CraterBidiPage, cookie: CraterStorageCookie): Promise<void> {
    await this.sendBidi("storage.deleteCookies", {
      filter: {
        name: cookie.name,
        domain: stripLeadingDot(String(cookie.domain ?? "")).toLowerCase(),
        path: cookie.path || "/",
      },
      partition: { type: "context", context: this.pageContextId(page) },
    });
  }

  private async sendBidi(method: string, params: unknown): Promise<BidiResponse> {
    const transport = await this.ensureTransportPage({});
    const send = (transport as unknown as {
      sendBidi(method: string, params: unknown): Promise<BidiResponse>;
    }).sendBidi.bind(transport);
    const resp = await send(method, params);
    if (resp.type === "error") {
      throw new Error(resp.message || resp.error || `${method} failed`);
    }
    return resp;
  }

  private pageContextId(page: CraterBidiPage): string {
    const contextId = (page as unknown as { contextId: string | null }).contextId;
    if (!contextId) {
      throw new Error("No browsing context");
    }
    return contextId;
  }

  private normalizeCookie(cookie: CraterStorageCookie): CraterStorageCookie {
    const defaults = cookie.url ? this.cookieDefaultsFromUrl(cookie.url) : null;
    return {
      name: String(cookie.name),
      value: String(cookie.value),
      domain: stripLeadingDot(String(cookie.domain || defaults?.domain || "localhost")).toLowerCase(),
      path: String(cookie.path || defaults?.path || "/"),
      expires: Number.isFinite(cookie.expires) ? Number(cookie.expires) : -1,
      httpOnly: Boolean(cookie.httpOnly),
      secure: cookie.secure === undefined ? Boolean(defaults?.secure) : Boolean(cookie.secure),
      sameSite: playwrightSameSite(cookie.sameSite),
    };
  }

  private cookieDefaultsFromUrl(url: string): { domain: string; path: string; secure: boolean } {
    let parsed: URL;
    try {
      parsed = new URL(url);
    } catch {
      throw new Error(`Invalid cookie url: ${url}`);
    }
    if (parsed.protocol !== "http:" && parsed.protocol !== "https:") {
      throw new Error(`Cookie url must be http or https: ${url}`);
    }
    return {
      domain: parsed.hostname,
      path: this.cookieDefaultPath(parsed.pathname),
      secure: parsed.protocol === "https:",
    };
  }

  private cookieDefaultPath(pathname: string): string {
    if (!pathname || pathname[0] !== "/" || pathname === "/") {
      return "/";
    }
    const slash = pathname.lastIndexOf("/");
    if (slash <= 0) {
      return "/";
    }
    return pathname.slice(0, slash);
  }

  private cookieFromStorage(rawCookie: unknown): CraterStorageCookie | null {
    if (!rawCookie || typeof rawCookie !== "object") {
      return null;
    }
    const cookie = rawCookie as Record<string, unknown>;
    const name = typeof cookie.name === "string" ? cookie.name : "";
    if (!name) {
      return null;
    }
    return {
      name,
      value: storageCookieValue(cookie.value),
      domain: stripLeadingDot(String(cookie.domain ?? "localhost")).toLowerCase(),
      path: typeof cookie.path === "string" && cookie.path ? cookie.path : "/",
      expires: typeof cookie.expiry === "number" ? cookie.expiry : -1,
      httpOnly: cookie.httpOnly === true,
      secure: cookie.secure === true,
      sameSite: playwrightSameSite(typeof cookie.sameSite === "string" ? cookie.sameSite : undefined),
    };
  }

  private upsertStoredCookie(cookie: CraterStorageCookie): void {
    const key = this.cookieKey(cookie);
    const index = this.cookieStore.findIndex((entry) => this.cookieKey(entry) === key);
    if (index === -1) {
      this.cookieStore.push(cookie);
    } else {
      this.cookieStore[index] = cookie;
    }
  }

  private cookieKey(cookie: CraterStorageCookie): string {
    return `${stripLeadingDot(String(cookie.domain ?? "localhost")).toLowerCase()}\t${cookie.path || "/"}\t${cookie.name}`;
  }
}

export class CraterBrowser {
  protected readonly contextList: CraterBrowserContext[] = [];
  protected transportPage: CraterBidiPage | null = null;
  protected transportConnectPromise: Promise<CraterBidiPage> | null = null;
  protected closed = false;

  constructor(protected readonly connectOptions: CraterBidiConnectOptions = {}) {}

  async newContext(options: CraterBrowserContextOptions = {}): Promise<CraterBrowserContext> {
    if (this.closed) {
      throw new Error("Browser is closed");
    }
    const context = new CraterBrowserContext(
      { ...this.connectOptions, ...options },
      (closedContext) => this.removeContext(closedContext),
      (transportOptions) => this.ensureTransportPage(transportOptions),
    );
    this.contextList.push(context);
    return context;
  }

  async newPage(options: CraterBidiConnectOptions = {}): Promise<CraterBidiPage> {
    const context = await this.newContext(options);
    return context.newPage();
  }

  contexts(): CraterBrowserContext[] {
    return [...this.contextList];
  }

  async close(): Promise<void> {
    if (this.closed) {
      return;
    }
    this.closed = true;
    const contexts = this.contextList.splice(0, this.contextList.length);
    await Promise.all(contexts.map((context) => context.close()));
    const transport = this.transportPage;
    this.transportPage = null;
    this.transportConnectPromise = null;
    if (transport) {
      await transport.close();
    }
  }

  protected removeContext(context: CraterBrowserContext): void {
    const index = this.contextList.indexOf(context);
    if (index !== -1) {
      this.contextList.splice(index, 1);
    }
  }

  private async ensureTransportPage(options: CraterBidiConnectOptions): Promise<CraterBidiPage> {
    if (this.closed) {
      throw new Error("Browser is closed");
    }
    if (this.transportPage) {
      return this.transportPage;
    }
    if (!this.transportConnectPromise) {
      this.transportConnectPromise = (async () => {
        const transport = new CraterBidiPage();
        try {
          await transport.connect({ ...this.connectOptions, ...options });
          this.transportPage = transport;
          return transport;
        } catch (error) {
          await transport.close().catch(() => undefined);
          throw error;
        }
      })().finally(() => {
        this.transportConnectPromise = null;
      });
    }
    return await this.transportConnectPromise;
  }
}

export class CraterBrowserType {
  constructor(
    private readonly browserName = "chromium",
    private readonly dependencies: CraterBrowserTypeDependencies = {},
  ) {}

  name(): string {
    return this.browserName;
  }

  async launch(options: CraterLaunchOptions = {}): Promise<CraterBrowser> {
    const {
      autoStartBidi,
      isolateContexts,
      craterRoot,
      denoBin,
      env,
      headless: _headless,
      args: _args,
      executablePath: _executablePath,
      serverTimeoutMs,
      pollIntervalMs,
      statusTimeoutMs,
      statusUrl,
      stdio,
      shutdownTimeoutMs,
      ...connectOptions
    } = options;
    const shouldStartServer = autoStartBidi ?? !connectOptions.url;
    if (!shouldStartServer) {
      return new CraterBrowser(connectOptions);
    }

    const ensureServer = this.dependencies.ensureBidiServer ?? ensureCraterBidiServer;
    const allocatePort = this.dependencies.allocateBidiPort ?? allocateBidiPort;
    const serverOptions: EnsureCraterBidiServerOptions = {
      craterRoot,
      denoBin,
      env,
      timeoutMs: serverTimeoutMs ?? connectOptions.timeout,
      pollIntervalMs,
      statusTimeoutMs,
      statusUrl,
      stdio,
      shutdownTimeoutMs,
    };
    if (isolateContexts) {
      return new CraterIsolatedLaunchedBrowser(
        connectOptions,
        serverOptions,
        ensureServer,
        allocatePort,
      );
    }

    const server = await ensureServer(serverOptions);
    return new CraterLaunchedBrowser(
      { ...connectOptions, url: server.url },
      server,
    );
  }
}

class CraterIsolatedLaunchedBrowser extends CraterBrowser {
  constructor(
    connectOptions: CraterBidiConnectOptions,
    private readonly serverOptions: EnsureCraterBidiServerOptions,
    private readonly ensureServer: (
      options?: EnsureCraterBidiServerOptions,
    ) => Promise<CraterBidiServerHandle>,
    private readonly allocatePort: () => Promise<number>,
  ) {
    super(connectOptions);
  }

  override async newContext(options: CraterBrowserContextOptions = {}): Promise<CraterBrowserContext> {
    if (this.closed) {
      throw new Error("Browser is closed");
    }
    const port = await this.allocatePort();
    const env = {
      ...(this.serverOptions.env ?? process.env),
      CRATER_BIDI_PORT: String(port),
    };
    const server = await this.ensureServer({
      ...this.serverOptions,
      env,
      statusUrl: `http://127.0.0.1:${port}/`,
      readUrlFile: false,
    });
    const context = new CraterLaunchedContext(
      { ...this.connectOptions, ...options, url: server.url },
      server,
      (closedContext) => this.removeContext(closedContext),
    );
    this.contextList.push(context);
    return context;
  }
}

class CraterLaunchedBrowser extends CraterBrowser {
  constructor(
    connectOptions: CraterBidiConnectOptions,
    private readonly server: CraterBidiServerHandle,
  ) {
    super(connectOptions);
  }

  override async close(): Promise<void> {
    try {
      await super.close();
    } finally {
      await this.server.close();
    }
  }
}

class CraterLaunchedContext extends CraterBrowserContext {
  private serverClosed = false;

  constructor(
    contextOptions: CraterBrowserContextOptions,
    private readonly server: CraterBidiServerHandle,
    closeHandler: CraterContextCloseHandler | null,
  ) {
    super(contextOptions, closeHandler);
  }

  override async close(): Promise<void> {
    try {
      await super.close();
    } finally {
      if (!this.serverClosed) {
        this.serverClosed = true;
        await this.server.close();
      }
    }
  }
}

export function createCraterBrowser(
  options: CraterBidiConnectOptions = {},
): CraterBrowser {
  return new CraterBrowser(options);
}

export function createCraterBrowserType(
  dependencies: CraterBrowserTypeDependencies = {},
): CraterBrowserType {
  return new CraterBrowserType("chromium", dependencies);
}

export const chromium = createCraterBrowserType();
