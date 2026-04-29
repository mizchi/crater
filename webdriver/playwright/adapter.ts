import { copyFile, mkdir, readFile, unlink, writeFile } from "node:fs/promises";
import { dirname } from "node:path";
import WebSocket from "ws";
import { resolveBidiUrl } from "../../scripts/bidi-url.ts";
export {
  CRATER_PLAYWRIGHT_API_SUPPORT,
  craterPlaywrightApisFor,
} from "./supported-apis.ts";
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
  scripts?: unknown[];
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

let sharedRoutePumpQueue: Promise<void> = Promise.resolve();

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

  async click(): Promise<void> {
    await this.waitForActionable();
    await this.page.evaluate(`
      (() => {
        const el = ${this.queryExpr("querySelector")};
        if (!el) throw new Error("Element not found: ${this.selectorForError()}");
        ${adapterDomActionsExpr()}
        __craterAction.clickElement(el);
      })()
    `);
  }

  async hover(): Promise<void> {
    await this.waitForActionable();
    await this.page.evaluate(`
      (() => {
        const el = ${this.queryExpr("querySelector")};
        if (!el) throw new Error("Element not found: ${this.selectorForError()}");
        ${adapterDomActionsExpr()}
        __craterAction.hoverElement(el);
      })()
    `);
  }

  async focus(): Promise<void> {
    await this.waitForActionable();
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

  async fill(value: string): Promise<void> {
    await this.waitForActionable();
    await this.page.evaluate(`
      (() => {
        ${adapterDomActionsExpr()}
        const el = ${this.queryExpr("querySelector")};
        if (!el) throw new Error("Element not found: ${this.selectorForError()}");
        __craterAction.setEditableValue(el, ${jsString(value)});
        __craterAction.dispatchInputChange(el);
      })()
    `);
  }

  async clear(): Promise<void> {
    await this.fill("");
  }

  async type(text: string): Promise<void> {
    await this.waitForActionable();
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
    if (handled) return;
    await this.focus();
    for (const char of [...text]) {
      await this.page.press(char);
    }
  }

  async press(key: string): Promise<void> {
    await this.focus();
    await this.page.press(key);
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
  }

  async check(): Promise<void> {
    await this.setChecked(true);
  }

  async uncheck(): Promise<void> {
    await this.setChecked(false);
  }

  async selectOption(value: CraterSelectOptionValue): Promise<void> {
    await this.waitForActionable();
    const requestExpr = jsValue(value);
    await this.page.evaluate(`
      (() => {
        ${adapterDomActionsExpr()}
        const el = ${this.queryExpr("querySelector")};
        if (!el) throw new Error("Element not found: ${this.selectorForError()}");
        __craterAction.selectOptions(el, ${requestExpr});
      })()
    `);
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

  private async setChecked(checked: boolean): Promise<void> {
    await this.waitForActionable();
    await this.page.evaluate(`
      (() => {
        ${adapterDomActionsExpr()}
        const el = ${this.queryExpr("querySelector")};
        if (!el) throw new Error("Element not found: ${this.selectorForError()}");
        __craterAction.setChecked(el, ${checked});
      })()
    `);
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
    return page;
  }

  async goto(url: string): Promise<CraterResponse | null> {
    const targetUrl = url.startsWith("http://") || url.startsWith("https://") || url.startsWith("data:") || url.startsWith("about:")
      ? url
      : `data:text/html;base64,${Buffer.from(url).toString("base64")}`;
    if (targetUrl.startsWith("http://") || targetUrl.startsWith("https://") || targetUrl.startsWith("data:")) {
      const result = await this.loadPage(targetUrl);
      return this.responseFromLoadResult(result, targetUrl);
    }
    await this.sendBidi("browsingContext.navigate", {
      context: this.requireContextId(),
      url: targetUrl,
      wait: "complete",
    });
    await this.syncRuntimeLocation(targetUrl);
    this.emitPageEvent("domcontentloaded", this);
    this.emitPageEvent("load", this);
    return null;
  }

  async setContent(html: string): Promise<void> {
    await this.syncRuntimeLocation("about:blank");
    await this.prepareRuntimeDocumentForLoad();
    await this.evaluate(`__loadHTML(${jsString(html)})`);
    await this.reinstallNetworkHooksForDocument();
    await this.runInitScripts();
    await this.setObservableFetchForScriptExecution(this.networkHooksInstalled);
    try {
      await this.evaluate(`(async () => await __executeScripts())()`, { awaitPromise: true });
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
    await this.syncRuntimeLocation(result.url ?? url);
    await this.runInitScripts();
    if (executeScripts) {
      await this.setObservableFetchForScriptExecution(this.networkHooksInstalled);
      try {
        const scriptsJson = await this.evaluate<string>(
          `(async () => JSON.stringify(await __executeScripts({ baseUrl: ${jsString(result.url ?? url)} })))()`,
          { awaitPromise: true },
        );
        result.scripts = JSON.parse(scriptsJson) as unknown[];
      } finally {
        await this.setObservableFetchForScriptExecution(false);
      }
    }
    await this.observeSubresourceLoads(result.url ?? url);
    this.emitPageEvent("domcontentloaded", this);
    this.emitPageEvent("load", this);
    return result;
  }

  private async observeSubresourceLoads(baseUrl: string): Promise<void> {
    if (!this.networkHooksInstalled) {
      return;
    }
    await this.ensureNetworkHooksReady();
    await this.evaluate(
      `(async () => {
        const resolve = (value) => {
          const raw = String(value || "");
          if (!raw) return "";
          if (globalThis.__resolveUrl) return globalThis.__resolveUrl(raw, ${jsString(baseUrl)});
          try { return new URL(raw, ${jsString(baseUrl)}).href; } catch (_e) { return raw; }
        };
        const resources = [];
        const seen = new Set();
        const add = (value) => {
          const resolved = resolve(value);
          if (!resolved || seen.has(resolved)) return;
          seen.add(resolved);
          resources.push(resolved);
        };
        for (const link of Array.from(document.querySelectorAll('link'))) {
          const rel = String(link.getAttribute('rel') || '').toLowerCase().split(/\\s+/);
          if (rel.includes('stylesheet')) add(link.getAttribute('href'));
        }
        for (const img of Array.from(document.querySelectorAll('img'))) {
          add(img.getAttribute('src'));
        }
        const fetchFn = globalThis.__craterObservableFetch;
        if (typeof fetchFn !== 'function') return;
        await Promise.all(resources.map(async (resourceUrl) => {
          try {
            const response = await fetchFn(resourceUrl, {});
            if (response && typeof response.arrayBuffer === 'function') {
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
        }));
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
        const sourceDoc = globalThis.__craterDocumentFactorySource || globalThis.document;
        if (!sourceDoc || typeof sourceDoc.createElement !== "function") return false;
        if (!globalThis.__craterDocumentFactorySource) {
          globalThis.__craterDocumentFactorySource = sourceDoc;
        }

        const currentCtx = String(globalThis.__bidiCurrentContext || "default-context");
        if (!globalThis.__bidiContextWindows) globalThis.__bidiContextWindows = new Map();
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
        const pending = JSON.parse(raw) as { url?: string };
        if (!pending.url) {
          continue;
        }
        await this.loadPage(pending.url);
      }
    } finally {
      this.navigationFlushDepth -= 1;
    }
  }

  private async syncRuntimeLocation(url: string): Promise<void> {
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
        applyUrl(next);
        location.assign = function(value) {
          const href = applyUrl(value);
          globalThis.__craterPendingNavigation = { url: href, kind: "assign" };
        };
        location.replace = function(value) {
          const href = applyUrl(value);
          globalThis.__craterPendingNavigation = { url: href, kind: "replace" };
        };
        location.reload = function() {
          const href = applyUrl(location.href || globalThis.__pageUrl || "about:blank");
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
      })()
    `);
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

  async url(): Promise<string> {
    return this.evaluate<string>("window.location.href");
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
    const isAsync = options.awaitPromise ?? (
      typeof expression === "function"
        ? expression.constructor.name === "AsyncFunction"
        : expr.includes("await ") || expr.includes("new Promise") || expr.includes(".then(")
    );
    const resp = await this.sendBidi("script.evaluate", {
      expression: expr,
      target: { context: this.requireContextId() },
      awaitPromise: evaluateOptions.awaitPromise ?? isAsync,
    });
    if (resp.type === "error") {
      throw new Error(resp.message || resp.error || "script.evaluate failed");
    }
    const result = resp.result as { result?: unknown; exceptionDetails?: unknown };
    if (result.exceptionDetails) {
      throw new Error(JSON.stringify(result.exceptionDetails));
    }
    const value = deserializeBidiValue(result.result) as T;
    if (this.navigationFlushDepth === 0) {
      await this.flushPendingNavigation();
    }
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

  async waitForFunction<T>(
    pageFunction: string | (() => T | Promise<T>),
    options: CraterWaitForFunctionOptions = {},
  ): Promise<T> {
    const timeout = this.timeoutOrDefault(options.timeout, 3000);
    const polling = options.polling ?? 30;
    const expression = this.waitForFunctionExpression(pageFunction);
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
      for (const event of events) {
        if (event.type !== "request") continue;
        if (event.timestamp < startedAt) continue;
        const request = new CraterRequest(event.request);
        if (await this.requestMatches(request, matcher)) {
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
      for (const event of events) {
        if (event.type !== "response") continue;
        if (event.timestamp < startedAt) continue;
        const response = new CraterResponse(event.response);
        if (await this.responseMatches(response, matcher)) {
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
  }

  async hover(selector: string): Promise<void> {
    const sharedId = await this.elementSharedId(selector);
    await this.performPointer(pointerMoveActions(sharedId));
  }

  async fill(selector: string, value: string): Promise<void> {
    await this.locator(selector).fill(value);
  }

  async type(selector: string, text: string): Promise<void> {
    await this.click(selector);
    await this.keyboard.type(text);
  }

  async press(key: string): Promise<void> {
    await this.keyboard.press(key);
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

  async screenshot(): Promise<Buffer> {
    return this.captureScreenshot();
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

  async captureScreenshot(): Promise<Buffer> {
    const resp = await this.sendBidi("browsingContext.captureScreenshotData", {
      context: this.requireContextId(),
      origin: "viewport",
    });
    if (resp.type === "error") {
      throw new Error(resp.message || resp.error || "captureScreenshotData failed");
    }
    return Buffer.from(String(resp.result || ""), "base64");
  }

  async capturePaintData(): Promise<{ width: number; height: number; data: Uint8Array }> {
    const resp = await this.sendBidi("browsingContext.capturePaintData", {
      context: this.requireContextId(),
      origin: "viewport",
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

  async capturePaintTree(): Promise<{ width: number; height: number; paintTree: string }> {
    const resp = await this.sendBidi("browsingContext.capturePaintTree", {
      context: this.requireContextId(),
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
    if (this.networkEventPumpBusy || this.closed) {
      return;
    }
    this.networkEventPumpBusy = true;
    try {
      const events = await this.networkEventsSince(this.networkEventEmitIndex);
      this.networkEventEmitIndex += events.length;
      for (const event of events) {
        this.emitNetworkPageEvent(event);
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
    sharedRoutePumpQueue = sharedRoutePumpQueue
      .catch(() => undefined)
      .then(async () => {
        try {
          await this.drainRouteRequests();
        } finally {
          this.routePumpQueued = false;
        }
      })
      .catch(() => {
        this.routePumpQueued = false;
        // The page may be closing; the next explicit command will surface real failures.
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
      for (const event of events) {
        if (event.type !== eventName) continue;
        const payload = this.networkPageEventPayload(event);
        if (!payload) continue;
        if (!options.predicate || await options.predicate(payload)) {
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

  private waitForFunctionExpression<T>(pageFunction: string | (() => T | Promise<T>)): string {
    return typeof pageFunction === "function"
      ? `(${pageFunction.toString()})()`
      : `(${pageFunction})`;
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
    const id = ++this.commandId;
    const payload = JSON.stringify({ id, method, params });
    return await new Promise<BidiResponse>((resolve, reject) => {
      this.pendingCommands.set(id, { resolve, reject });
      this.ws!.send(payload);
      const timeoutMs = method === "browsingContext.capturePaintData" ? 300000 : 10000;
      setTimeout(() => {
        if (this.pendingCommands.has(id)) {
          this.pendingCommands.delete(id);
          reject(new Error(`Timeout waiting for response to ${method}`));
        }
      }, timeoutMs);
    });
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
    const page = await transport.createSiblingPage((closedPage) => this.removePage(closedPage));
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
    const transport = this.transportPage;
    this.transportPage = null;
    await Promise.all(pages.map((page) => page.close()));
    if (transport) {
      await transport.close();
    }
    this.closeHandler?.(this);
  }

  private async ensureTransportPage(options: CraterBidiConnectOptions): Promise<CraterBidiPage> {
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
    if (Number.isFinite(cookie.expires) && cookie.expires >= 0) {
      storageCookie.expiry = cookie.expires;
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
    return `${stripLeadingDot(cookie.domain).toLowerCase()}\t${cookie.path || "/"}\t${cookie.name}`;
  }
}

export class CraterBrowser {
  private readonly contextList: CraterBrowserContext[] = [];
  private closed = false;

  constructor(private readonly connectOptions: CraterBidiConnectOptions = {}) {}

  async newContext(options: CraterBrowserContextOptions = {}): Promise<CraterBrowserContext> {
    if (this.closed) {
      throw new Error("Browser is closed");
    }
    const context = new CraterBrowserContext(
      { ...this.connectOptions, ...options },
      (closedContext) => this.removeContext(closedContext),
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
  }

  private removeContext(context: CraterBrowserContext): void {
    const index = this.contextList.indexOf(context);
    if (index !== -1) {
      this.contextList.splice(index, 1);
    }
  }
}

export function createCraterBrowser(
  options: CraterBidiConnectOptions = {},
): CraterBrowser {
  return new CraterBrowser(options);
}
