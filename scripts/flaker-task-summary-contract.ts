export interface FlakerEvalReport {
  dataSufficiency: {
    totalRuns: number;
    totalResults: number;
    uniqueTests: number;
    firstDate: string | null;
    lastDate: string | null;
    avgRunsPerTest: number;
  };
  detection: {
    flakyTests: number;
    trueFlakyTests: number;
    quarantinedTests: number;
    distribution: Array<{ range: string; count: number }>;
  };
  resolution: {
    resolvedFlaky: number;
    newFlaky: number;
    mttdDays: number | null;
    mttrDays: number | null;
  };
  healthScore: number;
}

export interface FlakerReasonReport {
  classifications: Array<{
    suite: string;
    testName: string;
    classification: string;
    confidence: number;
    recommendation: string;
    priority: string;
    evidence: string[];
  }>;
  patterns: Array<{
    type: string;
    description: string;
    severity: string;
    affectedTests: string[];
  }>;
  riskPredictions: Array<{
    suite: string;
    testName: string;
    riskScore: number;
    reason: string;
  }>;
  summary: {
    totalAnalyzed: number;
    trueFlakyCount: number;
    regressionCount: number;
    quarantineRecommended: number;
    urgentFixes: number;
  };
}

export interface FlakerTaskSummaryReport {
  schemaVersion: 1;
  generatedAt: string;
  taskId: string;
  workspaceDir: string;
  eval: FlakerEvalReport;
  reason: FlakerReasonReport;
}
