import { describe, expect, it } from "vitest";
import {
  buildStableIdentityKey,
  normalizeStableIdentityVariant,
} from "./stable-test-identity.ts";

describe("normalizeStableIdentityVariant", () => {
  it("drops empty values and sorts keys", () => {
    expect(
      normalizeStableIdentityVariant({
        shard: "2/4",
        empty: "",
        backend: "native",
      }),
    ).toEqual({
      backend: "native",
      shard: "2/4",
    });
  });
});

describe("buildStableIdentityKey", () => {
  it("keeps caller-provided field order and skips undefined entries", () => {
    expect(
      buildStableIdentityKey([
        ["spec", "tests/example.test.ts"],
        undefined,
        ["titlePath", ["suite", "works"]],
        ["variant", { backend: "native" }],
      ]),
    ).toBe(
      '{"spec":"tests/example.test.ts","titlePath":["suite","works"],"variant":{"backend":"native"}}',
    );
  });
});
