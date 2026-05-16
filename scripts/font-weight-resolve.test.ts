import { describe, expect, test } from "vitest";
import {
  declaredWeightsForEntry,
  type FontFileMapEntry,
  pickNearestFontWeight,
  selectWeightCandidates,
} from "./font-weight-resolve";

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

describe("selectWeightCandidates / declaredWeightsForEntry", () => {
  const sansLikeEntry: FontFileMapEntry = {
    regular: ["NotoSans-Regular.ttf"],
    bold: ["NotoSans-Bold.ttf"],
    byWeight: {
      300: ["NotoSans-Light.ttf"],
      500: ["NotoSans-Medium.ttf"],
      600: ["NotoSans-SemiBold.ttf"],
    },
  };

  const minimalEntry: FontFileMapEntry = {
    regular: ["Arial.ttf"],
    bold: ["Arial Bold.ttf"],
  };

  test("selectWeightCandidates returns regular slot for 400 even without byWeight key", () => {
    expect(selectWeightCandidates(sansLikeEntry, 400)).toEqual(["NotoSans-Regular.ttf"]);
    expect(selectWeightCandidates(minimalEntry, 400)).toEqual(["Arial.ttf"]);
  });

  test("selectWeightCandidates returns bold slot for 700 even without byWeight key", () => {
    expect(selectWeightCandidates(sansLikeEntry, 700)).toEqual(["NotoSans-Bold.ttf"]);
    expect(selectWeightCandidates(minimalEntry, 700)).toEqual(["Arial Bold.ttf"]);
  });

  test("selectWeightCandidates returns byWeight slot for declared non-default weights", () => {
    expect(selectWeightCandidates(sansLikeEntry, 500)).toEqual(["NotoSans-Medium.ttf"]);
    expect(selectWeightCandidates(sansLikeEntry, 600)).toEqual(["NotoSans-SemiBold.ttf"]);
    expect(selectWeightCandidates(sansLikeEntry, 300)).toEqual(["NotoSans-Light.ttf"]);
  });

  test("selectWeightCandidates returns [] for undeclared weights", () => {
    expect(selectWeightCandidates(sansLikeEntry, 100)).toEqual([]);
    expect(selectWeightCandidates(minimalEntry, 500)).toEqual([]);
    expect(selectWeightCandidates(minimalEntry, 900)).toEqual([]);
  });

  test("declaredWeightsForEntry includes regular and bold implicitly", () => {
    expect(declaredWeightsForEntry(minimalEntry)).toEqual([400, 700]);
  });

  test("declaredWeightsForEntry merges byWeight with implicit 400 / 700", () => {
    expect(declaredWeightsForEntry(sansLikeEntry)).toEqual([300, 400, 500, 600, 700]);
  });

  test("declaredWeightsForEntry skips empty regular / bold slots", () => {
    const onlyByWeight: FontFileMapEntry = {
      regular: [],
      bold: [],
      byWeight: { 500: ["Foo-Medium.ttf"] },
    };
    expect(declaredWeightsForEntry(onlyByWeight)).toEqual([500]);
  });

  test("declaredWeightsForEntry ignores byWeight slots that have no candidates", () => {
    const sparse: FontFileMapEntry = {
      regular: ["a.ttf"],
      bold: ["b.ttf"],
      byWeight: { 500: [], 600: ["x.ttf"] },
    };
    expect(declaredWeightsForEntry(sparse)).toEqual([400, 600, 700]);
  });
});
