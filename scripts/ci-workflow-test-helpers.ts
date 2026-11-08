export function extractWorkflowJob(workflow: string, jobName: string): string {
  const start = workflow.indexOf(`  ${jobName}:\n`);
  if (start === -1) {
    throw new Error(`Workflow job not found: ${jobName}`);
  }
  const rest = workflow.slice(start);
  const nextJob = rest.search(/\n  [a-zA-Z0-9_-]+:\n/);
  return nextJob === -1 ? rest : rest.slice(0, nextJob);
}

export function extractWorkflowStep(job: string, stepName: string): string {
  const start = job.indexOf(`      - name: ${stepName}\n`);
  if (start === -1) {
    throw new Error(`Workflow step not found: ${stepName}`);
  }
  const rest = job.slice(start);
  const nextStep = rest.search(/\n      - /);
  return nextStep === -1 ? rest : rest.slice(0, nextStep);
}
