/**
 * Dump layout rectangles for AEB HTML using Puppeteer.
 *
 * Usage:
 *   npx tsx scripts/aeb-layout-dump.ts                 # all
 *   npx tsx scripts/aeb-layout-dump.ts --limit 10
 *   npx tsx scripts/aeb-layout-dump.ts <hash>
 *   npx tsx scripts/aeb-layout-dump.ts --viewport 1280x800
 *   npx tsx scripts/aeb-layout-dump.ts --allow-assets
 *   npx tsx scripts/aeb-layout-dump.ts --timeout 30000
 *   npx tsx scripts/aeb-layout-dump.ts --no-css
 */

import fs from 'fs';
import path from 'path';
import { gunzipSync } from 'zlib';
import puppeteer from 'puppeteer';

const AEB_PATH = path.join(
  process.env.HOME || '',
  'ghq/github.com/scrapinghub/article-extraction-benchmark'
);

interface GroundTruth {
  [key: string]: {
    articleBody: string;
    url?: string;
  };
}

function loadGroundTruth(): GroundTruth {
  const groundTruthPath = path.join(AEB_PATH, 'ground-truth.json');
  if (!fs.existsSync(groundTruthPath)) {
    throw new Error(`Ground truth not found at ${groundTruthPath}`);
  }
  return JSON.parse(fs.readFileSync(groundTruthPath, 'utf-8'));
}

function loadHtml(hash: string): string {
  const htmlPath = path.join(AEB_PATH, 'html', `${hash}.html.gz`);
  if (!fs.existsSync(htmlPath)) {
    throw new Error(`HTML file not found: ${htmlPath}`);
  }
  const gzipped = fs.readFileSync(htmlPath);
  return gunzipSync(gzipped).toString('utf-8');
}

function injectBase(html: string, baseUrl?: string): string {
  if (!baseUrl) {
    return html;
  }
  const hasBase = /<base\b/i.test(html);
  if (hasBase) {
    return html;
  }
  const baseTag = `<base href="${baseUrl}">`;
  if (/<head\b/i.test(html)) {
    return html.replace(/<head\b[^>]*>/i, match => `${match}\n${baseTag}`);
  }
  return `${baseTag}\n${html}`;
}

async function main() {
  const args = process.argv.slice(2);
  let limit = Infinity;
  let specificHash: string | null = null;
  let outDir = path.join(process.cwd(), 'render-results/aeb-layout');
  let viewportWidth = 1280;
  let viewportHeight = 800;
  let allowAssets = false;
  let timeoutMs = 15000;
  let allowCss = true;

  for (let i = 0; i < args.length; i++) {
    if (args[i] === '--limit' && args[i + 1]) {
      limit = parseInt(args[i + 1], 10);
      i++;
    } else if (args[i] === '--out' && args[i + 1]) {
      outDir = path.resolve(args[i + 1]);
      i++;
    } else if (args[i] === '--viewport' && args[i + 1]) {
      const m = args[i + 1].match(/^(\d+)x(\d+)$/);
      if (!m) {
        throw new Error(`Invalid viewport: ${args[i + 1]}`);
      }
      viewportWidth = parseInt(m[1], 10);
      viewportHeight = parseInt(m[2], 10);
      i++;
    } else if (args[i] === '--allow-assets') {
      allowAssets = true;
    } else if (args[i] === '--timeout' && args[i + 1]) {
      timeoutMs = parseInt(args[i + 1], 10);
      i++;
    } else if (args[i] === '--no-css') {
      allowCss = false;
    } else if (!args[i].startsWith('-')) {
      specificHash = args[i];
    }
  }

  const groundTruth = loadGroundTruth();
  const hashes = Object.keys(groundTruth);
  let testHashes: string[];
  if (specificHash) {
    if (!groundTruth[specificHash]) {
      throw new Error(`Hash not found: ${specificHash}`);
    }
    testHashes = [specificHash];
  } else {
    testHashes = hashes.slice(0, limit);
  }

  fs.mkdirSync(outDir, { recursive: true });

  const browser = await puppeteer.launch({
    headless: 'new',
  });
  const page = await browser.newPage();
  await page.setViewport({ width: viewportWidth, height: viewportHeight });
  page.setDefaultNavigationTimeout(timeoutMs);
  await page.setJavaScriptEnabled(false);
  await page.setRequestInterception(true);
  page.on('request', request => {
    const type = request.resourceType();
    if (type === 'document' || (type === 'stylesheet' && allowCss)) {
      request.continue();
      return;
    }
    if (allowAssets && (type === 'image' || type === 'font')) {
      request.continue();
      return;
    }
    request.abort();
  });

  for (const hash of testHashes) {
    const html = loadHtml(hash);
    const baseUrl = groundTruth[hash].url;
    const content = injectBase(html, baseUrl);
    try {
      await page.setContent(content, { waitUntil: 'domcontentloaded', timeout: timeoutMs });
    } catch (error) {
      console.error(`Failed to load ${hash}:`, error instanceof Error ? error.message : String(error));
      continue;
    }
    const data = await page.evaluate(`(() => {
      const NAV_PATTERNS = [
        'nav','menu','navbar','topbar','footer','header','sidebar','breadcrumb','masthead',
        'site-nav','site-navs','site_header','site-footer','siteheader','sitefooter'
      ];
      const AD_PATTERNS = [
        'ad','ads','advert','advertisement','sponsor','promo','banner','doubleclick',
        'taboola','outbrain','adunit','ad-slot','adslot'
      ];
      const COMMON_AD_SIZES = [
        [300,250],[728,90],[160,600],[300,600],[320,50],[970,250]
      ];
      function containsPattern(value, patterns) {
        if (!value) return false;
        const v = String(value).toLowerCase();
        return patterns.some(p => v.includes(p));
      }
      function isApprox(a, b, tol) {
        return Math.abs(a - b) <= tol;
      }
      function isCommonAdSize(rect) {
        for (const [w, h] of COMMON_AD_SIZES) {
          if ((isApprox(rect.width, w, 5) && isApprox(rect.height, h, 5)) ||
              (isApprox(rect.width, h, 5) && isApprox(rect.height, w, 5))) {
            return true;
          }
        }
        return false;
      }
      function isVisible(el) {
        const style = window.getComputedStyle(el);
        if (style.display === 'none' || style.visibility === 'hidden') {
          return false;
        }
        return true;
      }
      function buildSelector(tag, id, className) {
        if (!tag) return null;
        const base = String(tag).toLowerCase();
        if (id) {
          return base + '#' + id;
        }
        const classes = String(className || '')
          .split(/\\s+/)
          .map(s => s.trim())
          .filter(Boolean);
        if (classes.length === 0) {
          return base;
        }
        return base + '.' + classes.join('.');
      }
      const elements = Array.from(
        document.querySelectorAll(
          'article,main,section,div,p,pre,blockquote,li,ul,ol,menu,nav,header,footer,aside,h1,h2,h3,h4,h5,h6'
        )
      );
      const nodes = [];
      for (const el of elements) {
        if (!isVisible(el)) {
          continue;
        }
        const rect = el.getBoundingClientRect();
        if (rect.width <= 1 || rect.height <= 1) {
          continue;
        }
        const tag = el.tagName.toLowerCase();
        const id = el.id || '';
        const className = typeof el.className === 'string' ? el.className : '';
        const role = el.getAttribute('role') || '';
        const ariaLabel = el.getAttribute('aria-label') || '';
        const text = (el.textContent || '').trim();
        const textLen = text.length;
        if (textLen === 0) {
          continue;
        }
        const selector = buildSelector(tag, id, className);
        const linkTextLen = (() => {
          const links = Array.from(el.querySelectorAll('a'));
          let total = 0;
          for (const a of links) {
            total += (a.textContent || '').trim().length;
          }
          return total;
        })();
        const linkDensity = textLen > 0 ? linkTextLen / textLen : 0;
        const navByTag = tag === 'nav' || tag === 'header' || tag === 'footer' || tag === 'aside';
        const navByRole = role === 'navigation' || role === 'banner' || role === 'contentinfo' || role === 'complementary';
        const navByAttr = containsPattern(id, NAV_PATTERNS) || containsPattern(className, NAV_PATTERNS) || containsPattern(ariaLabel, NAV_PATTERNS);
        const isNavCandidate = navByTag || navByRole || navByAttr;
        const adByAttr = containsPattern(id, AD_PATTERNS) || containsPattern(className, AD_PATTERNS);
        const adBySize = isCommonAdSize(rect);
        const isAdCandidate = adByAttr || adBySize;
        const navByLinks = linkDensity > 0.5 && textLen < 800;
        const isNavCandidateEx = isNavCandidate || navByLinks;
        nodes.push({
          tag,
          id,
          className,
          role,
          ariaLabel,
          selector,
          text,
          textLen,
          linkTextLen,
          linkDensity,
          rect: {
            x: rect.x,
            y: rect.y,
            width: rect.width,
            height: rect.height,
          },
          area: rect.width * rect.height,
          density: textLen / Math.max(1, rect.width * rect.height),
          isNavCandidate: isNavCandidateEx,
          isAdCandidate,
        });
      }
      const navCount = nodes.filter(n => n.isNavCandidate).length;
      const adCount = nodes.filter(n => n.isAdCandidate).length;
      return {
        title: document.title,
        nodeCount: nodes.length,
        navCount,
        adCount,
        nodes,
      };
    })()`);
    const out = {
      hash,
      url: baseUrl || null,
      viewport: { width: viewportWidth, height: viewportHeight },
      ...data,
    };
    fs.writeFileSync(path.join(outDir, `${hash}.json`), JSON.stringify(out));
  }

  await browser.close();
}

main().catch(err => {
  console.error(err);
  process.exit(1);
});
