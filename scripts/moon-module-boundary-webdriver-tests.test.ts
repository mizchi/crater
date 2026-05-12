import fs from "node:fs";
import path from "node:path";
import { describe, expect, it } from "vitest";
import {
  BROWSER_TERMINAL_PROTOCOL_ANSI_FILES,
  DIRECT_TUI_TERMINAL_PROTOCOL_FILES,
  REPO_ROOT,
  collectMoonBitFiles,
  collectMoonPackageFiles,
  countLines,
} from "./moon-module-boundary-helpers";

describe("MoonBit WebDriver regression test boundaries", () => {
  it("keeps WebDriver BiDi protocol regression tests split by command domain", () => {
    const sourceFile = path.join(REPO_ROOT, "webdriver/webdriver/bidi_protocol_wbtest.mbt");
    const splitFiles = [
      {
        file: "webdriver/webdriver/bidi_protocol_session_context_wbtest.mbt",
        markers: [
          'test "bidi session status"',
          'test "bidi browsingContext create emits events before response"',
          'test "bidi browsingContext getCurrentUrlValue rejects invalid context type"',
        ],
      },
      {
        file: "webdriver/webdriver/bidi_protocol_fixture_wbtest.mbt",
        markers: [
          'test "bidi script getElementForTest returns first matching node"',
          'test "bidi script prepareLoadedStaticTestPage dispatches DOMContentLoaded and resets allEvents"',
          'test "bidi session isSubscribedForContext follows parent context subscriptions"',
        ],
      },
      {
        file: "webdriver/webdriver/bidi_protocol_prompt_subscription_wbtest.mbt",
        markers: [
          'test "bidi browsingContext close promptUnload waits for handleUserPrompt"',
          'test "bidi session subscribe returns subscription id"',
          'test "bidi browser setDownloadBehavior accepts user_contexts alias"',
        ],
      },
      {
        file: "webdriver/webdriver/bidi_protocol_input_wbtest.mbt",
        markers: [
          'test "bidi input performActions validates context type"',
          'test "bidi input pointer drag actions emit drag sequence"',
          'test "bidi input setFiles accepts files alias and derives display name"',
        ],
      },
      {
        file: "webdriver/webdriver/bidi_protocol_preload_realm_wbtest.mbt",
        markers: [
          'test "bidi script removeAllPreloadScripts clears future contexts"',
          'test "bidi script addPreloadScript accepts snake_case aliases"',
          'test "bidi script getRealmsList returns raw realms array"',
        ],
      },
      {
        file: "webdriver/webdriver/bidi_protocol_navigation_state_wbtest.mbt",
        markers: [
          'test "bidi browsingContext prepareNavigate reuses blocked navigation preparation"',
          'test "bidi browsingContext navigateWithState defers blocked synthetic request"',
          'test "bidi browsingContext closeWithState reports waitForDestroyed before closing"',
        ],
      },
      {
        file: "webdriver/webdriver/bidi_protocol_script_eval_wbtest.mbt",
        markers: [
          'test "bidi script evaluate validates snake_case serializationOptions aliases"',
          'test "bidi script evaluateResult keeps exceptionDetails payload"',
          'test "bidi script callFunctionResult unwraps synthetic document focus state"',
        ],
      },
      {
        file: "webdriver/webdriver/bidi_protocol_extended_domains_wbtest.mbt",
        markers: [
          'test "bidi permissions setPermission validates descriptor type"',
          'test "bidi bluetooth requestDevice emits prompt event and resolves on accept"',
          'test "bidi emulation setScreenSettingsOverride updates runtime screen metrics and matchMedia"',
        ],
      },
    ] as const;

    const source = fs.readFileSync(sourceFile, "utf8");
    const migratedTests = splitFiles.flatMap(({ markers }) => markers);
    for (const { file, markers } of splitFiles) {
      const targetFile = path.join(REPO_ROOT, file);
      expect(fs.existsSync(targetFile)).toBe(true);
      const targetSource = fs.readFileSync(targetFile, "utf8");
      expect(markers.every((marker) => targetSource.includes(marker))).toBe(true);
    }
    const offenders = migratedTests.filter((marker) => source.includes(marker));
    expect(offenders).toEqual([]);
  });
});
