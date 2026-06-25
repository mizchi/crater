/**
 * Capture a real-world snapshot by fetching (no browser).
 *
 * Unlike capture-real-world-snapshot.ts (which drives Playwright to render JS),
 * this fetches the server-rendered HTML and its linked stylesheets directly and
 * inlines them — robust in headless/proxy environments where a browser binary
 * or live navigation isn't available. Good for server-rendered pages (news,
 * docs, wikis); JS-rendered SPAs need the Playwright capture instead.
 *
 * Usage:
 *   npx tsx scripts/capture-real-world-fetch.ts <url> --name <name> \
 *     [--width 1024] [--height 768]
 *
 * Writes real-world/<name>/{index.html,meta.json}, loadable via
 * loadRealWorldSnapshot(name) and the match-rate / layout-diff tools.
 */

import fs from 'node:fs';
import path from 'node:path';
import { inlineHtmlSnapshot } from './real-world-snapshot.ts';

const UA =
  'Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0 Safari/537.36';

interface Options {
  url: string;
  name: string;
  width: number;
  height: number;
  realWorldDir: string;
}

function parseArgs(argv: string[]): Options {
  const opts: Options = {
    url: '',
    name: '',
    width: 1024,
    height: 768,
    realWorldDir: path.join(process.cwd(), 'real-world'),
  };
  for (let i = 0; i < argv.length; i++) {
    const a = argv[i]!;
    if (!a.startsWith('--')) opts.url = a;
    else if (a === '--name') opts.name = argv[++i]!;
    else if (a === '--width') opts.width = Number(argv[++i]);
    else if (a === '--height') opts.height = Number(argv[++i]);
    else if (a === '--real-world-dir') opts.realWorldDir = argv[++i]!;
  }
  if (!opts.url || !opts.name) {
    throw new Error('usage: capture-real-world-fetch.ts <url> --name <name> [--width N] [--height N]');
  }
  return opts;
}

async function getText(u: string): Promise<string> {
  const res = await fetch(u, { headers: { 'user-agent': UA } });
  if (!res.ok) throw new Error(`${u}: ${res.status}`);
  return res.text();
}

function stylesheetHrefs(html: string, baseUrl: string): string[] {
  const hrefs: string[] = [];
  const linkRe = /<link\b[^>]*rel=(['"])[^'"]*stylesheet[^'"]*\1[^>]*>/gi;
  for (const m of html.matchAll(linkRe)) {
    const hm = m[0].match(/href=(['"])([^'"]+)\1/i);
    if (!hm) continue;
    try {
      hrefs.push(new URL(hm[2]!, baseUrl).href);
    } catch {
      /* skip malformed href */
    }
  }
  return [...new Set(hrefs)];
}

async function main(): Promise<void> {
  const opts = parseArgs(process.argv.slice(2));
  const html = await getText(opts.url);

  const styles: string[] = [];
  for (const href of stylesheetHrefs(html, opts.url)) {
    try {
      styles.push(await getText(href));
    } catch (e) {
      console.warn(`skip ${href}: ${(e as Error).message}`);
    }
  }

  const snapshotHtml = inlineHtmlSnapshot({ html, styles, baseHref: opts.url });
  const title = html.match(/<title[^>]*>([\s\S]*?)<\/title>/i)?.[1]?.trim() ?? opts.name;

  const dir = path.join(opts.realWorldDir, opts.name);
  fs.mkdirSync(dir, { recursive: true });
  fs.writeFileSync(path.join(dir, 'index.html'), snapshotHtml, 'utf8');
  fs.writeFileSync(
    path.join(dir, 'meta.json'),
    // capturedAt is fixed so re-capturing the same content yields no diff noise.
    JSON.stringify(
      {
        title,
        sourceUrl: opts.url,
        viewport: { width: opts.width, height: opts.height },
        stylesheetUrls: stylesheetHrefs(html, opts.url),
        capturedAt: '1970-01-01T00:00:00.000Z',
      },
      null,
      2,
    ),
    'utf8',
  );
  console.log(
    JSON.stringify({
      name: opts.name,
      title,
      url: opts.url,
      viewport: { width: opts.width, height: opts.height },
      stylesheets: styles.length,
      htmlBytes: snapshotHtml.length,
    }),
  );
}

main().catch((e) => {
  console.error(e instanceof Error ? e.stack ?? e.message : e);
  process.exit(1);
});
