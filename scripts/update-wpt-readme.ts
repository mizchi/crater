/**
 * Generate WPT compatibility table and update README.md
 * Run: npx tsx scripts/update-wpt-readme.ts
 */

import { execSync } from 'child_process';
import * as fs from 'fs';
import * as path from 'path';

// Load config from wpt.json
const wptConfig = JSON.parse(fs.readFileSync(path.join(process.cwd(), 'wpt.json'), 'utf-8'));
const CSS_MODULES: string[] = wptConfig.modules;

interface ModuleResult {
  module: string;
  passed: number;
  total: number;
  rate: string;
}

function runWptTests(): ModuleResult[] {
  const results: ModuleResult[] = [];

  for (const module of CSS_MODULES) {
    console.log(`Testing ${module}...`);

    try {
      const output = execSync(`npx tsx scripts/wpt-runner.ts ${module}`, {
        encoding: 'utf-8',
        stdio: ['pipe', 'pipe', 'pipe'],
      });

      const summaryMatch = output.match(/Summary: (\d+) passed, (\d+) failed/);
      if (summaryMatch) {
        const passed = parseInt(summaryMatch[1], 10);
        const failed = parseInt(summaryMatch[2], 10);
        const total = passed + failed;
        const rate = ((passed / total) * 100).toFixed(1);

        results.push({ module, passed, total, rate });
        console.log(`  ${module}: ${passed}/${total} (${rate}%)`);
      } else {
        console.log(`  ${module}: No tests found`);
      }
    } catch (error: any) {
      const output = error.stdout?.toString() || error.message;
      const summaryMatch = output.match(/Summary: (\d+) passed, (\d+) failed/);

      if (summaryMatch) {
        const passed = parseInt(summaryMatch[1], 10);
        const failed = parseInt(summaryMatch[2], 10);
        const total = passed + failed;
        const rate = ((passed / total) * 100).toFixed(1);

        results.push({ module, passed, total, rate });
        console.log(`  ${module}: ${passed}/${total} (${rate}%)`);
      } else {
        console.log(`  ${module}: No tests or error`);
      }
    }
  }

  return results;
}

function generateTable(results: ModuleResult[]): string {
  const totalPassed = results.reduce((sum, r) => sum + r.passed, 0);
  const totalTests = results.reduce((sum, r) => sum + r.total, 0);
  const totalRate = totalTests > 0 ? ((totalPassed / totalTests) * 100).toFixed(1) : '0.0';

  let table = `| Module | Passed | Total | Rate |
|--------|--------|-------|------|`;

  for (const r of results) {
    table += `\n| ${r.module} | ${r.passed} | ${r.total} | ${r.rate}% |`;
  }

  table += `\n| **Total** | **${totalPassed}** | **${totalTests}** | **${totalRate}%** |`;

  return table;
}

function updateReadme(readmePath: string, table: string): boolean {
  if (!fs.existsSync(readmePath)) {
    console.log(`File not found: ${readmePath}`);
    return false;
  }

  let content = fs.readFileSync(readmePath, 'utf-8');

  const wptSectionPattern = /(### Web Platform Tests \(WPT\)[\s\S]*?CSS tests from \[web-platform-tests\][^\n]*\n\n)\| Module \| Passed \| Total \| Rate \|[\s\S]*?\| \*\*Total\*\* \| \*\*\d+\*\* \| \*\*\d+\*\* \| \*\*[\d.]+%\*\* \|/;

  if (wptSectionPattern.test(content)) {
    content = content.replace(wptSectionPattern, `$1${table}`);
    fs.writeFileSync(readmePath, content);
    console.log(`Updated ${readmePath}`);
    return true;
  } else {
    console.log(`Could not find WPT section in ${readmePath}`);
    return false;
  }
}

async function main() {
  console.log('Running WPT tests and generating compatibility table...\n');

  const results = runWptTests();

  if (results.length === 0) {
    console.log('No test results.');
    process.exit(1);
  }

  console.log('\nGenerated table:');
  const table = generateTable(results);
  console.log(table);
  console.log('');

  const readmeFiles = ['README.md', 'README.mbt.md'];
  for (const file of readmeFiles) {
    const filePath = path.join(process.cwd(), file);
    updateReadme(filePath, table);
  }

  console.log('\nDone!');
}

main().catch(console.error);
