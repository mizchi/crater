export type CraterModelContextToolAnnotations = {
  readOnlyHint?: boolean;
  destructiveHint?: boolean;
  idempotentHint?: boolean;
  openWorldHint?: boolean;
  untrustedContentHint?: boolean;
};

export type CraterModelContextToolDescriptor = {
  name: string;
  description: string;
  inputSchema?: unknown;
  outputSchema?: unknown;
  annotations?: CraterModelContextToolAnnotations;
};

export type CraterModelContextToolCallEnvelope<T = unknown> =
  | { ok: true; value: T }
  | { ok: false; error: { name: string; message: string } };

export function modelContextRuntimeExpression(
  options: { resetRegistry?: boolean } = {},
): string {
  return `
    (() => {
      const resetRegistry = ${options.resetRegistry === true ? "true" : "false"};
      const root = globalThis;
      const host = root.window && typeof root.window === "object" ? root.window : root;
      const defineValue = (target, name, value, enumerable = true) => {
        if (!target || typeof target !== "object") return value;
        try {
          Object.defineProperty(target, name, {
            configurable: true,
            enumerable,
            writable: true,
            value,
          });
        } catch (_error) {
          try { target[name] = value; } catch (_assignError) {}
        }
        return value;
      };
      const cloneObject = (value) => {
        if (!value || typeof value !== "object") return undefined;
        return JSON.parse(JSON.stringify(value));
      };
      const cloneNavigator = (current, owner) => {
        const proto = current && typeof current === "object"
          ? Object.getPrototypeOf(current)
          : Object.prototype;
        const next = Object.create(proto || Object.prototype);
        if (current && typeof current === "object") {
          try {
            Object.defineProperties(next, Object.getOwnPropertyDescriptors(current));
          } catch (_error) {
            for (const key of Object.keys(current)) {
              try { next[key] = current[key]; } catch (_assignError) {}
            }
          }
        }
        defineValue(next, "__craterNavigatorOwner", owner, false);
        return next;
      };
      const ensureNavigator = (target) => {
        if (!target || typeof target !== "object") return {};
        const current = target.navigator && typeof target.navigator === "object"
          ? target.navigator
          : null;
        if (target !== root && (!current || current.__craterNavigatorOwner !== target)) {
          return defineValue(target, "navigator", cloneNavigator(current || root.navigator, target));
        }
        if (current) return current;
        return defineValue(target, "navigator", cloneNavigator(root.navigator, target));
      };
      const navigator = ensureNavigator(host);
      defineValue(root, "navigator", navigator);
      const registryOwner = host;
      if (
        resetRegistry ||
        !registryOwner.__craterModelContextRegistry ||
        typeof registryOwner.__craterModelContextRegistry.get !== "function"
      ) {
        defineValue(registryOwner, "__craterModelContextRegistry", new Map(), false);
      }
      if (
        resetRegistry ||
        !registryOwner.__craterModelContextListeners ||
        typeof registryOwner.__craterModelContextListeners.add !== "function"
      ) {
        defineValue(registryOwner, "__craterModelContextListeners", new Set(), false);
      }
      const registry = registryOwner.__craterModelContextRegistry;
      const listeners = registryOwner.__craterModelContextListeners;
      const toolNamePattern = /^[A-Za-z0-9_-]{1,128}$/;
      const makeDomError = (name, message) => {
        if (typeof root.DOMException === "function") {
          return new root.DOMException(message, name);
        }
        const error = new Error(message);
        error.name = name;
        return error;
      };
      const descriptorFor = (entry) => {
        const descriptor = {
          name: entry.name,
          description: entry.description,
        };
        if (entry.inputSchema !== undefined) descriptor.inputSchema = cloneObject(entry.inputSchema);
        if (entry.outputSchema !== undefined) descriptor.outputSchema = cloneObject(entry.outputSchema);
        if (entry.annotations !== undefined) descriptor.annotations = { ...entry.annotations };
        return descriptor;
      };
      const listTools = () => Array.from(registry.values()).map(descriptorFor);
      const notifyToolsChanged = () => {
        const run = () => {
          for (const listener of Array.from(listeners)) {
            try { listener(listTools()); } catch (_error) {}
          }
        };
        if (typeof root.queueMicrotask === "function") {
          root.queueMicrotask(run);
        } else if (typeof root.setTimeout === "function") {
          root.setTimeout(run, 0);
        } else {
          run();
        }
      };
      const normalizeAnnotations = (tool) => {
        const source = tool.annotations && typeof tool.annotations === "object"
          ? tool.annotations
          : tool;
        const annotations = {};
        for (const key of [
          "readOnlyHint",
          "destructiveHint",
          "idempotentHint",
          "openWorldHint",
          "untrustedContentHint",
        ]) {
          if (source[key] !== undefined) annotations[key] = Boolean(source[key]);
        }
        return Object.keys(annotations).length === 0 ? undefined : annotations;
      };
      const normalizeSchema = (value, fieldName) => {
        if (value === undefined) return undefined;
        try {
          return cloneObject(value);
        } catch (_error) {
          throw new TypeError(fieldName + " must be JSON serializable");
        }
      };
      const normalizeTool = (tool) => {
        if (!tool || typeof tool !== "object") {
          throw new TypeError("modelContext.registerTool requires a tool descriptor");
        }
        const name = String(tool.name ?? "");
        if (!toolNamePattern.test(name)) {
          throw new TypeError("WebMCP tool name must be 1-128 ASCII letters, digits, underscores, or hyphens");
        }
        const description = String(tool.description ?? "");
        if (description.length === 0) {
          throw new TypeError("WebMCP tool description must be non-empty");
        }
        if (typeof tool.execute !== "function") {
          throw new TypeError("WebMCP tool execute callback must be a function");
        }
        return {
          name,
          description,
          inputSchema: normalizeSchema(tool.inputSchema, "inputSchema"),
          outputSchema: normalizeSchema(tool.outputSchema, "outputSchema"),
          annotations: normalizeAnnotations(tool),
          execute: tool.execute,
          unregister: null,
        };
      };
      let modelContext = navigator.modelContext;
      if (
        !modelContext ||
        typeof modelContext !== "object" ||
        modelContext.__craterModelContextRegistry !== registry
      ) {
        modelContext = {};
        defineValue(modelContext, "__craterModelContextRegistry", registry, false);
        defineValue(navigator, "modelContext", modelContext);
      }
      defineValue(modelContext, "registerTool", (tool, options = {}) => {
        const entry = normalizeTool(tool);
        if (registry.has(entry.name)) {
          throw makeDomError("InvalidStateError", "WebMCP tool is already registered: " + entry.name);
        }
        const signal = options && typeof options === "object" ? options.signal : undefined;
        if (signal && signal.aborted) {
          return undefined;
        }
        let disposed = false;
        const unregister = () => {
          if (disposed) return;
          disposed = true;
          if (registry.get(entry.name) === entry) {
            registry.delete(entry.name);
            notifyToolsChanged();
          }
          if (signal && typeof signal.removeEventListener === "function") {
            try { signal.removeEventListener("abort", unregister); } catch (_error) {}
          }
        };
        entry.unregister = unregister;
        registry.set(entry.name, entry);
        if (signal && typeof signal.addEventListener === "function") {
          try { signal.addEventListener("abort", unregister, { once: true }); } catch (_error) {}
        }
        notifyToolsChanged();
        return undefined;
      });
      const testing = {};
      defineValue(testing, "listTools", () => listTools());
      defineValue(testing, "callTool", async (name, input) => {
        const toolName = String(name ?? "");
        const entry = registry.get(toolName);
        if (!entry) {
          throw makeDomError("NotFoundError", "WebMCP tool is not registered: " + toolName);
        }
        return await entry.execute(input);
      });
      defineValue(testing, "clearTools", () => {
        for (const entry of Array.from(registry.values())) {
          if (typeof entry.unregister === "function") entry.unregister();
          else registry.delete(entry.name);
        }
        notifyToolsChanged();
      });
      defineValue(testing, "addToolsChangedListener", (listener) => {
        if (typeof listener !== "function") {
          throw new TypeError("listener must be a function");
        }
        listeners.add(listener);
        return () => listeners.delete(listener);
      });
      defineValue(navigator, "modelContextTesting", testing, false);
      defineValue(registryOwner, "__craterListModelContextTools", () => listTools(), false);
      defineValue(registryOwner, "__craterCallModelContextTool", async (name, input) => {
        try {
          return { ok: true, value: await testing.callTool(name, input) };
        } catch (error) {
          return {
            ok: false,
            error: {
              name: error && error.name ? String(error.name) : "Error",
              message: error && error.message ? String(error.message) : String(error),
            },
          };
        }
      }, false);
      defineValue(root, "__craterListModelContextTools", () => {
        const currentHost = root.window && typeof root.window === "object" ? root.window : registryOwner;
        return typeof currentHost.__craterListModelContextTools === "function"
          ? currentHost.__craterListModelContextTools()
          : listTools();
      }, false);
      defineValue(root, "__craterCallModelContextTool", async (name, input) => {
        const currentHost = root.window && typeof root.window === "object" ? root.window : registryOwner;
        return typeof currentHost.__craterCallModelContextTool === "function"
          ? await currentHost.__craterCallModelContextTool(name, input)
          : await registryOwner.__craterCallModelContextTool(name, input);
      }, false);
      return true;
    })()
  `;
}
