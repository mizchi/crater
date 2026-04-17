import path from "node:path";
import {
  buildStableIdentityKey,
  normalizeStableIdentityVariant,
} from "./stable-test-identity.ts";

export type VrtArtifactStatus = "pass" | "fail" | "unknown";

export interface VrtArtifactViewport {
  width: number;
  height: number;
}

export interface VrtArtifactRoi {
  x: number;
  y: number;
  width: number;
  height: number;
}

export interface VrtArtifactMetrics {
  width?: number;
  height?: number;
  diffPixels?: number;
  totalPixels?: number;
  diffRatio?: number;
  threshold?: number;
  maxDiffRatio?: number;
  maskPixels?: number;
  roi?: VrtArtifactRoi;
  backend?: string;
  viewport?: VrtArtifactViewport;
  snapshotKind?: string;
}

export interface VrtStableIdentity {
  key: string;
  taskId?: string;
  spec?: string;
  filter?: string;
  title: string;
  variant: Record<string, string>;
  shard?: string;
}

export interface VrtArtifactLegacyReport extends VrtArtifactMetrics {
  status?: VrtArtifactStatus;
  title?: string;
  identity?: VrtStableIdentity;
  durationMs?: number;
  artifacts?: Record<string, string>;
  [key: string]: unknown;
}

export interface NormalizedVrtArtifactReport {
  schemaVersion: 1;
  suite: "vrt-artifact";
  status: VrtArtifactStatus;
  title: string;
  identity: VrtStableIdentity;
  durationMs?: number;
  artifacts: Record<string, string>;
  metadata: VrtArtifactMetrics;
}

export type VrtArtifactRawReport = VrtArtifactLegacyReport | NormalizedVrtArtifactReport;

export interface CreateNormalizedVrtArtifactReportInput {
  title: string;
  taskId?: string;
  spec?: string;
  filter?: string;
  variant?: Record<string, string> | null;
  shard?: string;
  status?: VrtArtifactStatus;
  durationMs?: number;
  artifacts?: Record<string, string> | null;
  metadata?: VrtArtifactMetrics | null;
}

export interface VrtArtifactReportContext {
  title: string;
  taskId?: string;
  spec?: string;
  filter?: string;
  variant?: Record<string, string>;
  shard?: string;
  snapshotKind?: string;
  backend?: string;
  durationMs?: number;
  artifacts?: Record<string, string>;
}

export interface CreateVrtArtifactReportContextInput extends VrtArtifactReportContext {
  cwd?: string;
  file?: string;
  outputDir?: string;
}

function asRecord(value: unknown): Record<string, unknown> | null {
  return typeof value === "object" && value !== null ? value as Record<string, unknown> : null;
}

function asFiniteNumber(value: unknown): number | undefined {
  return typeof value === "number" && Number.isFinite(value) ? value : undefined;
}

function asStatus(value: unknown): VrtArtifactStatus | undefined {
  return value === "pass" || value === "fail" || value === "unknown" ? value : undefined;
}

function asStringRecord(value: unknown): Record<string, string> | undefined {
  const record = asRecord(value);
  if (!record) {
    return undefined;
  }
  const entries = Object.entries(record)
    .filter((entry): entry is [string, string] => typeof entry[1] === "string" && entry[1].length > 0)
    .sort((a, b) => a[0].localeCompare(b[0]));
  return Object.fromEntries(entries);
}

function asViewport(value: unknown): VrtArtifactViewport | undefined {
  const record = asRecord(value);
  if (!record) {
    return undefined;
  }
  const width = asFiniteNumber(record.width);
  const height = asFiniteNumber(record.height);
  if (width === undefined || height === undefined) {
    return undefined;
  }
  return { width, height };
}

function asRoi(value: unknown): VrtArtifactRoi | undefined {
  const record = asRecord(value);
  if (!record) {
    return undefined;
  }
  const x = asFiniteNumber(record.x);
  const y = asFiniteNumber(record.y);
  const width = asFiniteNumber(record.width);
  const height = asFiniteNumber(record.height);
  if (x === undefined || y === undefined || width === undefined || height === undefined) {
    return undefined;
  }
  return { x, y, width, height };
}

function normalizeMetrics(record: Record<string, unknown>): VrtArtifactMetrics {
  return {
    width: asFiniteNumber(record.width),
    height: asFiniteNumber(record.height),
    diffPixels: asFiniteNumber(record.diffPixels),
    totalPixels: asFiniteNumber(record.totalPixels),
    diffRatio: asFiniteNumber(record.diffRatio),
    threshold: asFiniteNumber(record.threshold),
    maxDiffRatio: asFiniteNumber(record.maxDiffRatio),
    maskPixels: asFiniteNumber(record.maskPixels),
    roi: asRoi(record.roi),
    backend: typeof record.backend === "string" && record.backend.length > 0 ? record.backend : undefined,
    viewport: asViewport(record.viewport),
    snapshotKind: typeof record.snapshotKind === "string" && record.snapshotKind.length > 0
      ? record.snapshotKind
      : undefined,
  };
}

function normalizeArtifacts(
  artifacts: Record<string, string> | null | undefined,
): Record<string, string> {
  return asStringRecord(artifacts) ?? {};
}

function isWindowsAbsolutePath(value: string): boolean {
  return /^[A-Za-z]:[\\/]/.test(value) || value.startsWith("\\\\");
}

function usesWindowsPathSemantics(...values: string[]): boolean {
  return values.some((value) => value.includes("\\") || isWindowsAbsolutePath(value));
}

function toPortablePath(value: string): string {
  return value.replaceAll("\\", "/");
}

function splitPortablePathSegments(value: string): string[] {
  return toPortablePath(value)
    .split("/")
    .filter((segment) => segment.length > 0 && segment !== ".");
}

function normalizeSpecPath(
  file: string,
  cwd: string,
): string {
  const pathApi = usesWindowsPathSemantics(file, cwd) ? path.win32 : path;
  const normalized = pathApi.isAbsolute(file) ? pathApi.relative(cwd, file) : file;
  return toPortablePath(normalized)
    .replace(/^[.][/\\]/, "")
}

export function inferVrtSnapshotKind(input: {
  title?: string;
  spec?: string;
  outputDir?: string;
}): string | undefined {
  const title = input.title?.trim().toLowerCase() ?? "";
  if (title.startsWith("real-world snapshot:")) {
    return "real-world";
  }
  if (title.startsWith("fixture:")) {
    return "fixture";
  }

  const spec = input.spec?.replaceAll("\\", "/") ?? "";
  if (spec.endsWith("/wpt-vrt.test.ts") || spec === "tests/wpt-vrt.test.ts") {
    return "wpt";
  }
  if (
    spec.endsWith("/paint-vrt-responsive.test.ts")
    || spec === "tests/paint-vrt-responsive.test.ts"
  ) {
    return "responsive";
  }
  if (
    spec.endsWith("/paint-vrt-levels.test.ts")
    || spec === "tests/paint-vrt-levels.test.ts"
  ) {
    return "fixture";
  }

  const outputDir = input.outputDir ? path.resolve(input.outputDir) : "";
  if (outputDir.length > 0) {
    const segments = splitPortablePathSegments(outputDir);
    if (segments.includes("wpt")) {
      return "wpt";
    }
    if (segments.includes("responsive")) {
      return "responsive";
    }
    if (segments.includes("url")) {
      return "url";
    }
    if (segments.includes("real-world")) {
      return "real-world";
    }
    if (segments.includes("levels")) {
      return "fixture";
    }
    if (path.basename(outputDir).startsWith("fixture-")) {
      return "fixture";
    }
  }

  return undefined;
}

export function inferVrtStableFilter(input: {
  title?: string;
  spec?: string;
  outputDir?: string;
  snapshotKind?: string;
}): string | undefined {
  const resolvedOutputDir = input.outputDir?.trim();
  if (!resolvedOutputDir) {
    return undefined;
  }

  const segments = splitPortablePathSegments(resolvedOutputDir);
  const vrtIndex = segments.lastIndexOf("vrt");
  const afterVrt = vrtIndex >= 0 ? segments.slice(vrtIndex + 1) : segments;
  const snapshotKind = input.snapshotKind ?? inferVrtSnapshotKind(input);

  if (afterVrt[0] === "wpt" || snapshotKind === "wpt") {
    return undefined;
  }
  if (afterVrt[0] === "responsive" && afterVrt[1]) {
    return afterVrt[1];
  }
  if (afterVrt[0] === "levels" && afterVrt[1]) {
    return afterVrt[1];
  }
  if (afterVrt[0] === "url" && afterVrt[1]) {
    return afterVrt[1];
  }
  if (afterVrt[0] === "real-world" && afterVrt[1]) {
    return afterVrt[1];
  }
  if (afterVrt.length > 0) {
    return afterVrt[afterVrt.length - 1];
  }

  const fallback = segments[segments.length - 1]?.trim();
  return fallback && fallback.length > 0 ? fallback : undefined;
}

export function normalizeVrtVariant(
  variant: Record<string, string> | null | undefined,
): Record<string, string> {
  return normalizeStableIdentityVariant(variant);
}

export function buildStableVrtIdentity(input: {
  taskId?: string;
  spec?: string;
  filter?: string;
  title: string;
  variant?: Record<string, string> | null;
  shard?: string;
}): VrtStableIdentity {
  const variant = normalizeVrtVariant(input.variant);
  return {
    key: buildStableIdentityKey([
      input.filter ? undefined : ["title", input.title],
      input.taskId ? ["taskId", input.taskId] : undefined,
      input.spec ? ["spec", input.spec] : undefined,
      input.filter ? ["filter", input.filter] : undefined,
      Object.keys(variant).length > 0 ? ["variant", variant] : undefined,
      input.shard ? ["shard", input.shard] : undefined,
    ]),
    taskId: input.taskId,
    spec: input.spec,
    filter: input.filter,
    title: input.title,
    variant,
    shard: input.shard,
  };
}

export function createVrtArtifactReportContext(
  input: CreateVrtArtifactReportContextInput,
): VrtArtifactReportContext {
  const variant = normalizeVrtVariant(input.variant);
  const artifacts = asStringRecord(input.artifacts);
  const spec = input.file
    ? normalizeSpecPath(input.file, input.cwd ?? process.cwd())
    : input.spec
    ? normalizeSpecPath(input.spec, input.cwd ?? process.cwd())
    : undefined;
  const snapshotKind = input.snapshotKind ?? inferVrtSnapshotKind({
    title: input.title,
    spec,
    outputDir: input.outputDir,
  });
  const inferredFilter = inferVrtStableFilter({
    title: input.title,
    spec,
    outputDir: input.outputDir,
    snapshotKind,
  });
  return {
    title: input.title,
    ...(input.taskId ? { taskId: input.taskId } : {}),
    ...(spec ? { spec } : {}),
    filter: input.filter ?? inferredFilter ?? input.title,
    ...(Object.keys(variant).length > 0 ? { variant } : {}),
    ...(input.shard ? { shard: input.shard } : {}),
    ...(snapshotKind ? { snapshotKind } : {}),
    ...(input.backend ? { backend: input.backend } : {}),
    ...(input.durationMs !== undefined ? { durationMs: input.durationMs } : {}),
    ...(artifacts ? { artifacts } : {}),
  };
}

export function createNormalizedVrtArtifactReport(
  input: CreateNormalizedVrtArtifactReportInput,
): NormalizedVrtArtifactReport {
  const metadata = normalizeMetrics((input.metadata ?? {}) as Record<string, unknown>);
  const variant = normalizeVrtVariant({
    ...(metadata.backend ? { backend: metadata.backend } : {}),
    ...(metadata.snapshotKind ? { snapshotKind: metadata.snapshotKind } : {}),
    ...(input.variant ?? {}),
  });
  const identity = buildStableVrtIdentity({
    taskId: input.taskId,
    spec: input.spec,
    filter: input.filter,
    title: input.title,
    variant,
    shard: input.shard,
  });
  const derivedStatus = input.status ?? (
    metadata.diffRatio === undefined || metadata.maxDiffRatio === undefined
      ? "unknown"
      : metadata.diffRatio <= metadata.maxDiffRatio
      ? "pass"
      : "fail"
  );
  return {
    schemaVersion: 1,
    suite: "vrt-artifact",
    status: derivedStatus,
    title: input.title,
    identity,
    durationMs: input.durationMs,
    artifacts: normalizeArtifacts(input.artifacts),
    metadata,
  };
}

export function asNormalizedVrtArtifactReport(value: unknown): NormalizedVrtArtifactReport | null {
  const record = asRecord(value);
  if (!record) {
    return null;
  }
  if (record.schemaVersion !== 1 || record.suite !== "vrt-artifact") {
    return null;
  }
  if (typeof record.title !== "string" || record.title.length === 0) {
    return null;
  }
  const status = asStatus(record.status);
  if (!status) {
    return null;
  }
  const identityRecord = asRecord(record.identity);
  if (!identityRecord || typeof identityRecord.key !== "string" || typeof identityRecord.title !== "string") {
    return null;
  }
  const metadataRecord = asRecord(record.metadata);
  if (!metadataRecord) {
    return null;
  }
  const metadata = normalizeMetrics(metadataRecord);
  if (metadata.diffRatio === undefined) {
    return null;
  }
  const artifacts = asStringRecord(record.artifacts) ?? {};
  return {
    schemaVersion: 1,
    suite: "vrt-artifact",
    status,
    title: record.title,
    identity: {
      key: identityRecord.key,
      taskId: typeof identityRecord.taskId === "string" ? identityRecord.taskId : undefined,
      spec: typeof identityRecord.spec === "string" ? identityRecord.spec : undefined,
      filter: typeof identityRecord.filter === "string" ? identityRecord.filter : undefined,
      title: identityRecord.title,
      variant: asStringRecord(identityRecord.variant) ?? {},
      shard: typeof identityRecord.shard === "string" ? identityRecord.shard : undefined,
    },
    durationMs: asFiniteNumber(record.durationMs),
    artifacts,
    metadata,
  };
}

export function readVrtArtifactMetrics(value: unknown): VrtArtifactMetrics | null {
  const normalized = asNormalizedVrtArtifactReport(value);
  if (normalized) {
    return normalized.metadata;
  }
  const record = asRecord(value);
  if (!record) {
    return null;
  }
  const metrics = normalizeMetrics(record);
  return metrics.diffRatio === undefined ? null : metrics;
}

export function readVrtArtifactStatus(value: unknown): VrtArtifactStatus {
  const normalized = asNormalizedVrtArtifactReport(value);
  if (normalized) {
    return normalized.status;
  }
  const record = asRecord(value);
  const explicit = asStatus(record?.status);
  if (explicit) {
    return explicit;
  }
  const metrics = readVrtArtifactMetrics(value);
  if (!metrics || metrics.diffRatio === undefined || metrics.maxDiffRatio === undefined) {
    return "unknown";
  }
  return metrics.diffRatio <= metrics.maxDiffRatio ? "pass" : "fail";
}

export function readVrtArtifactTitle(
  value: unknown,
  fallbackLabel: string,
): string {
  const normalized = asNormalizedVrtArtifactReport(value);
  if (normalized) {
    return normalized.title;
  }
  const record = asRecord(value);
  if (record && typeof record.title === "string" && record.title.length > 0) {
    return record.title;
  }
  return fallbackLabel;
}

export function readVrtArtifactIdentityKey(value: unknown): string | undefined {
  const normalized = asNormalizedVrtArtifactReport(value);
  if (normalized) {
    return normalized.identity.key;
  }
  const record = asRecord(value);
  const identityRecord = asRecord(record?.identity);
  return typeof identityRecord?.key === "string" ? identityRecord.key : undefined;
}

export function readVrtArtifactIdentity(value: unknown): VrtStableIdentity | undefined {
  const normalized = asNormalizedVrtArtifactReport(value);
  if (normalized) {
    return normalized.identity;
  }
  const record = asRecord(value);
  const identityRecord = asRecord(record?.identity);
  if (
    !identityRecord
    || typeof identityRecord.key !== "string"
    || typeof identityRecord.title !== "string"
  ) {
    return undefined;
  }
  return {
    key: identityRecord.key,
    taskId: typeof identityRecord.taskId === "string" ? identityRecord.taskId : undefined,
    spec: typeof identityRecord.spec === "string" ? identityRecord.spec : undefined,
    filter: typeof identityRecord.filter === "string" ? identityRecord.filter : undefined,
    title: identityRecord.title,
    variant: asStringRecord(identityRecord.variant) ?? {},
    shard: typeof identityRecord.shard === "string" ? identityRecord.shard : undefined,
  };
}

export function readVrtArtifactDurationMs(value: unknown): number | undefined {
  const normalized = asNormalizedVrtArtifactReport(value);
  if (normalized) {
    return normalized.durationMs;
  }
  const record = asRecord(value);
  return asFiniteNumber(record?.durationMs);
}
