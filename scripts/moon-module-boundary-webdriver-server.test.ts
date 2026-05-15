import fs from "node:fs";
import path from "node:path";
import { describe, expect, it } from "vitest";
import { REPO_ROOT, countLines } from "./moon-module-boundary-helpers";

const read = (relativePath: string): string => {
  return fs.readFileSync(path.join(REPO_ROOT, relativePath), "utf8");
};

const SERVER_FILES = [
  "webdriver/server/moon.pkg",
  "webdriver/server/server.mbt",
  "webdriver/server/server_test.mbt",
] as const;

const MOVED_DEFINITIONS = [
  "struct SessionManager",
  "struct SessionState",
  "fn SessionManager::new",
  "fn SessionManager::create_session",
  "fn SessionManager::delete_session",
  "fn SessionManager::get_session",
  "fn SessionManager::handle_request",
  "fn capabilities_to_value",
  "fn handle_status",
  "fn parse_navigation_url",
  "fn navigation_title_for_url",
  "fn is_example_domain_url",
  "fn navigation_host_for_url",
] as const;

describe("webdriver/server isolation", () => {
  it("declares only the REST/session-handler surface", () => {
    for (const file of SERVER_FILES) {
      expect(fs.existsSync(path.join(REPO_ROOT, file))).toBe(true);
    }
  });

  it("server package is small and self-contained", () => {
    const server = read("webdriver/server/server.mbt");
    expect(countLines("webdriver/server/server.mbt")).toBeLessThan(400);
    // Should not pull in protocol/runtime/rendering internals.
    expect(server).not.toContain("@protocol");
    expect(server).not.toContain("@runtime");
    expect(server).not.toContain("@rendering");
    expect(server).not.toContain("@browser_domain");
    expect(server).not.toContain("@raster");
    expect(server).not.toContain("@renderer");
    // Transport-specific FFIs belong in bidi_server, not the REST handler.
    expect(server).not.toContain("@deno");
    expect(server).not.toContain("@core");
    expect(server).not.toContain("upgrade_websocket");
  });

  it("REST handler definitions live only in the server package", () => {
    for (const def of MOVED_DEFINITIONS) {
      const server = read("webdriver/server/server.mbt");
      expect(server.includes(def)).toBe(true);
    }
  });

  it("webdriver/webdriver no longer owns the REST handler implementation", () => {
    const oldServerExists = fs.existsSync(
      path.join(REPO_ROOT, "webdriver/webdriver/server.mbt"),
    );
    expect(oldServerExists).toBe(false);
    const oldTestExists = fs.existsSync(
      path.join(REPO_ROOT, "webdriver/webdriver/server_test.mbt"),
    );
    expect(oldTestExists).toBe(false);
  });

  it("webdriver/webdriver re-exports SessionManager/SessionState via a thin facade", () => {
    const facade = read("webdriver/webdriver/server_facade.mbt");
    expect(facade).toContain("pub using @server");
    expect(facade).toContain("type SessionManager");
    expect(facade).toContain("type SessionState");
  });

  it("server package only depends on contract + core/json", () => {
    const pkg = read("webdriver/server/moon.pkg");
    expect(pkg).toContain("mizchi/crater-webdriver-bidi/contract");
    expect(pkg).toContain("moonbitlang/core/json");
    expect(pkg).not.toContain("protocol");
    expect(pkg).not.toContain("runtime");
    expect(pkg).not.toContain("rendering");
    expect(pkg).not.toContain("browser_domain");
  });
});
