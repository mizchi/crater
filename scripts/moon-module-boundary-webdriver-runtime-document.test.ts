import fs from "node:fs";
import path from "node:path";
import { describe, expect, it } from "vitest";
import { REPO_ROOT, countLines } from "./moon-module-boundary-helpers";

describe("MoonBit WebDriver runtime document and eval boundaries", () => {
  it("keeps WebDriver runtime document helpers out of the server transport", () => {
    expect(fs.existsSync(path.join(REPO_ROOT, "webdriver/webdriver/bidi_runtime_document.mbt"))).toBe(
      true,
    );

    const source = fs.readFileSync(
      path.join(REPO_ROOT, "webdriver/webdriver/bidi_server.mbt"),
      "utf8",
    );
    const implementationMarkers = [
      "extern \"js\" fn js_sync_runtime_html_async",
      "extern \"js\" fn js_sync_runtime_page_async",
      "pub fn sync_runtime_page",
      "pub fn sync_runtime_html",
      "extern \"js\" fn js_decode_base64",
      "pub fn decode_base64",
      "pub fn parse_data_url",
      "fn make_substr",
    ] as const;

    const offenders = implementationMarkers.filter((marker) => source.includes(marker));
    expect(offenders).toEqual([]);
  });

  it("keeps WebDriver runtime eval helpers out of the server transport", () => {
    expect(fs.existsSync(path.join(REPO_ROOT, "webdriver/webdriver/bidi_runtime_eval.mbt"))).toBe(
      true,
    );

    const source = fs.readFileSync(
      path.join(REPO_ROOT, "webdriver/webdriver/bidi_server.mbt"),
      "utf8",
    );
    const implementationMarkers = [
      "extern \"js\" fn js_evaluate_expression",
      "extern \"js\" fn js_evaluate_expression_fast",
      "fn evaluate_js_with_console",
      "pub fn evaluate_js",
      "extern \"js\" fn js_evaluate_expression_async",
      "extern \"js\" fn js_await_promise",
      "pub fn evaluate_js_async",
      "extern \"js\" fn js_eval_and_send_async",
      "fn eval_and_send_async_with_console",
      "pub fn eval_and_send_async",
      "pub fn await_promise",
    ] as const;

    const offenders = implementationMarkers.filter((marker) => source.includes(marker));
    expect(offenders).toEqual([]);
  });
});
