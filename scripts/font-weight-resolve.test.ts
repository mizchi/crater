import { describe, expect, test } from "vitest";
import { pickNearestFontWeight } from "./font-weight-resolve";

describe("pickNearestFontWeight (CSS Fonts L4 §5.2)", () => {
  test("returns null when no weights are available", () => {
    expect(pickNearestFontWeight([], 500)).toBeNull();
  });

  test("requested 500 with only 400 and 700 falls to 400 per CSS L4 §5.2 (lighter before heavier)", () => {
    expect(pickNearestFontWeight([400, 700], 500)).toBe(400);
  });

  test("requested 500 picks 500 exactly when available", () => {
    expect(pickNearestFontWeight([400, 500, 700], 500)).toBe(500);
  });

  test("requested 500 picks 500 when only regular/medium loaded", () => {
    expect(pickNearestFontWeight([400, 500], 500)).toBe(500);
  });

  test("requested 400 picks 500 in 400..500 ascending before falling lower or higher", () => {
    expect(pickNearestFontWeight([300, 500, 700], 400)).toBe(500);
  });

  test("requested 400 with only lighter weights picks the heaviest below requested", () => {
    expect(pickNearestFontWeight([100, 200, 300], 400)).toBe(300);
  });

  test("requested 400 with only weights above 500 picks the lightest above", () => {
    expect(pickNearestFontWeight([600, 700, 900], 400)).toBe(600);
  });

  test("requested 300 picks the heaviest weight at or below requested", () => {
    expect(pickNearestFontWeight([100, 300, 400, 700], 300)).toBe(300);
  });

  test("requested 300 with only heavier weights picks the lightest above", () => {
    expect(pickNearestFontWeight([400, 500, 700], 300)).toBe(400);
  });

  test("requested 700 picks the lightest weight at or above requested", () => {
    expect(pickNearestFontWeight([400, 500, 700, 900], 700)).toBe(700);
  });

  test("requested 700 with only lighter weights picks the heaviest below", () => {
    expect(pickNearestFontWeight([300, 400, 500], 700)).toBe(500);
  });

  test("requested 900 picks 900 when present, else heaviest below", () => {
    expect(pickNearestFontWeight([400, 700, 900], 900)).toBe(900);
    expect(pickNearestFontWeight([400, 700], 900)).toBe(700);
  });

  test("requested 600 (bold-ish) picks 700 over 500", () => {
    expect(pickNearestFontWeight([400, 500, 700], 600)).toBe(700);
  });

  test("requested 500 with only 400 falls to 400 (no medium, no heavier)", () => {
    expect(pickNearestFontWeight([400], 500)).toBe(400);
  });

  test("duplicate weights are deduplicated before selection", () => {
    expect(pickNearestFontWeight([400, 400, 700, 700], 500)).toBe(400);
  });
});
