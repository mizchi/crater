/**
 * Real-world site downloader for Crater testing
 *
 * Downloads a webpage with all assets inlined for offline testing.
 *
 * Usage:
 *   npx tsx tools/download-site.ts <url> [output-name]
 *
 * Examples:
 *   npx tsx tools/download-site.ts https://www.google.com google
 *   npx tsx tools/download-site.ts https://zenn.dev/mizchi zenn-mizchi
 */

import puppeteer from 'puppeteer';
import * as fs from 'fs';
import * as path from 'path';

const VIEWPORT = { width: 1280, height: 800 };
const OUTPUT_DIR = path.join(process.cwd(), 'real-world');

interface DownloadOptions {
  url: string;
  outputName: string;
  inlineImages?: boolean;
  waitFor?: number;
  simplified?: boolean;
  inlineComputed?: boolean;
  viewportWidth?: number;
  viewportHeight?: number;
}

/**
 * Convert image URL to base64 data URL
 */
async function imageToBase64(page: puppeteer.Page, imageUrl: string): Promise<string | null> {
  try {
    const response = await page.evaluate(async (url: string) => {
      try {
        const res = await fetch(url);
        if (!res.ok) return null;
        const blob = await res.blob();
        return new Promise<string>((resolve) => {
          const reader = new FileReader();
          reader.onloadend = () => resolve(reader.result as string);
          reader.readAsDataURL(blob);
        });
      } catch {
        return null;
      }
    }, imageUrl);
    return response;
  } catch {
    return null;
  }
}

/**
 * Get all stylesheets content (including external ones)
 */
async function getAllStyles(page: puppeteer.Page): Promise<string> {
  return page.evaluate(() => {
    const styles: string[] = [];

    // Get all stylesheets
    for (const sheet of Array.from(document.styleSheets)) {
      try {
        const rules = Array.from(sheet.cssRules || []);
        const cssText = rules.map(rule => rule.cssText).join('\n');
        if (cssText) {
          styles.push(`/* From: ${sheet.href || 'inline'} */\n${cssText}`);
        }
      } catch (e) {
        // Cross-origin stylesheets may throw
        console.warn('Could not access stylesheet:', sheet.href);
      }
    }

    return styles.join('\n\n');
  });
}

/**
 * Get computed styles for all elements and inline them as style attribute
 * Preserves responsive properties (width/height) from original CSS
 */
async function inlineComputedStyles(page: puppeteer.Page): Promise<void> {
  await page.evaluate(() => {
    const elements = document.querySelectorAll('*');
    elements.forEach((el) => {
      if (el instanceof HTMLElement) {
        const computed = window.getComputedStyle(el);

        // Get original inline style values to preserve responsive units
        const originalStyle = el.style;

        // Layout properties that should be inlined (excluding width/height to preserve responsiveness)
        const layoutProps = [
          'display', 'position',
          'margin-top', 'margin-right', 'margin-bottom', 'margin-left',
          'padding-top', 'padding-right', 'padding-bottom', 'padding-left',
          'border-top-width', 'border-right-width', 'border-bottom-width', 'border-left-width',
          'flex-direction', 'flex-wrap', 'justify-content', 'align-items', 'align-content',
          'flex-grow', 'flex-shrink', 'flex-basis',
          'gap', 'row-gap', 'column-gap',
          'box-sizing', 'overflow',
          'top', 'right', 'bottom', 'left',
          'background-color', 'color'
        ];

        // Properties where we want computed pixel values (for fixed-size elements only)
        const sizeProps = ['width', 'height', 'min-width', 'max-width', 'min-height', 'max-height'];

        const inlineStyles: string[] = [];

        // Add layout props
        layoutProps.forEach(prop => {
          const value = computed.getPropertyValue(prop);
          if (value && value !== 'none' && value !== 'auto' && value !== 'normal' && value !== '0px') {
            inlineStyles.push(`${prop}: ${value}`);
          }
        });

        // Only add size props if they were explicitly set (not auto/100%)
        sizeProps.forEach(prop => {
          const computedValue = computed.getPropertyValue(prop);
          const originalValue = originalStyle.getPropertyValue(prop);

          // If there's an explicit original value, use it
          if (originalValue && originalValue !== 'auto') {
            inlineStyles.push(`${prop}: ${originalValue}`);
          }
          // Otherwise, only inline if it's a specific pixel value and not filling parent
          else if (computedValue && computedValue !== 'auto' && computedValue !== 'none') {
            // Skip large values that are likely viewport-relative
            const numValue = parseFloat(computedValue);
            if (!isNaN(numValue) && numValue < 1000 && numValue > 0) {
              inlineStyles.push(`${prop}: ${computedValue}`);
            }
          }
        });

        // Append to existing style attribute
        if (inlineStyles.length > 0) {
          const existingStyle = el.getAttribute('style') || '';
          const newStyle = existingStyle
            ? existingStyle + '; ' + inlineStyles.join('; ')
            : inlineStyles.join('; ');
          el.setAttribute('style', newStyle);
        }
      }
    });
  });
}

/**
 * Clean up the HTML for Crater consumption
 */
async function cleanupHTML(page: puppeteer.Page, simplified: boolean = false): Promise<string> {
  return page.evaluate((simplify) => {
    // Remove scripts
    document.querySelectorAll('script').forEach(el => el.remove());

    // Remove noscript
    document.querySelectorAll('noscript').forEach(el => el.remove());

    // Remove iframes
    document.querySelectorAll('iframe').forEach(el => el.remove());

    // Remove style tags (styles are now inlined)
    if (simplify) {
      document.querySelectorAll('style').forEach(el => el.remove());
      document.querySelectorAll('link[rel="stylesheet"]').forEach(el => el.remove());
    }

    // Remove SVG icons that are too complex (keep simple ones)
    document.querySelectorAll('svg').forEach(el => {
      if (el.innerHTML.length > 1000) {
        el.remove();
      }
    });

    // Remove hidden elements
    if (simplify) {
      document.querySelectorAll('*').forEach(el => {
        if (el instanceof HTMLElement) {
          const computed = window.getComputedStyle(el);
          if (computed.display === 'none' || computed.visibility === 'hidden' || computed.opacity === '0') {
            el.remove();
          }
        }
      });
    }

    // Remove event handlers and unnecessary attributes
    const allElements = document.querySelectorAll('*');
    allElements.forEach(el => {
      // Remove all on* attributes
      Array.from(el.attributes).forEach(attr => {
        if (attr.name.startsWith('on')) {
          el.removeAttribute(attr.name);
        }
        // Remove data attributes except data-computed
        if (simplify && attr.name.startsWith('data-') && attr.name !== 'data-computed') {
          el.removeAttribute(attr.name);
        }
        // Remove aria attributes
        if (simplify && attr.name.startsWith('aria-')) {
          el.removeAttribute(attr.name);
        }
      });
    });

    return document.documentElement.outerHTML;
  }, simplified);
}

/**
 * Download a site with all assets inlined
 */
async function downloadSite(options: DownloadOptions): Promise<void> {
  const {
    url,
    outputName,
    inlineImages = false,
    waitFor = 3000,
    simplified = false,
    inlineComputed = false,
    viewportWidth = VIEWPORT.width,
    viewportHeight = VIEWPORT.height
  } = options;
  const viewport = { width: viewportWidth, height: viewportHeight };

  console.log(`Downloading: ${url}`);
  console.log(`Output: ${outputName}`);

  const browser = await puppeteer.launch({
    headless: true,
    args: ['--no-sandbox', '--disable-setuid-sandbox']
  });

  try {
    const page = await browser.newPage();

    // Set viewport
    await page.setViewport(viewport);

    // Set a desktop user agent
    await page.setUserAgent('Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36');

    // Navigate to URL
    console.log('Loading page...');
    await page.goto(url, {
      waitUntil: 'networkidle2',
      timeout: 30000
    });

    // Wait additional time for JS rendering
    console.log(`Waiting ${waitFor}ms for rendering...`);
    await new Promise(resolve => setTimeout(resolve, waitFor));

    // Scroll to trigger lazy loading
    console.log('Triggering lazy load...');
    await page.evaluate(async () => {
      await new Promise<void>((resolve) => {
        let totalHeight = 0;
        const distance = 300;
        const timer = setInterval(() => {
          window.scrollBy(0, distance);
          totalHeight += distance;
          if (totalHeight >= document.body.scrollHeight) {
            clearInterval(timer);
            window.scrollTo(0, 0);
            resolve();
          }
        }, 100);
      });
    });

    // Wait for images to load
    await new Promise(resolve => setTimeout(resolve, 1000));

    // Get all CSS
    console.log('Extracting styles...');
    const allStyles = await getAllStyles(page);

    // Inline computed styles for CSS-in-JS sites (optional)
    if (inlineComputed) {
      console.log('Inlining computed styles...');
      await inlineComputedStyles(page);
    }

    // Get page title
    const title = await page.title();

    // Inline images if requested
    if (inlineImages) {
      console.log('Inlining images...');
      const images = await page.$$eval('img', imgs =>
        imgs.map(img => ({ src: img.src, selector: `img[src="${img.src}"]` }))
      );

      for (const img of images) {
        if (img.src && !img.src.startsWith('data:')) {
          const base64 = await imageToBase64(page, img.src);
          if (base64) {
            await page.evaluate((src, data) => {
              const imgs = document.querySelectorAll(`img[src="${src}"]`);
              imgs.forEach(img => img.setAttribute('src', data));
            }, img.src, base64);
          }
        }
      }
    }

    // Clean up HTML
    console.log('Cleaning up HTML...');
    const html = await cleanupHTML(page, simplified);

    // Create output directory if needed
    const outputDir = path.join(OUTPUT_DIR, outputName);
    if (!fs.existsSync(outputDir)) {
      fs.mkdirSync(outputDir, { recursive: true });
    }

    // Build final HTML with inlined styles
    const finalHTML = `<!DOCTYPE html>
<html>
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=${viewport.width}, height=${viewport.height}">
  <title>${title}</title>
  <style>
/* Reset */
* { margin: 0; padding: 0; box-sizing: border-box; }
body { font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif; }

/* Extracted styles */
${allStyles}
  </style>
</head>
${html.replace(/<html[^>]*>/, '').replace(/<\/html>/, '')}
</html>`;

    // Save HTML
    const htmlPath = path.join(outputDir, 'index.html');
    fs.writeFileSync(htmlPath, finalHTML);
    console.log(`Saved: ${htmlPath}`);

    // Take a screenshot for reference
    const screenshotPath = path.join(outputDir, 'screenshot.png');
    await page.screenshot({ path: screenshotPath, fullPage: true });
    console.log(`Screenshot: ${screenshotPath}`);

    // Save metadata
    const metadata = {
      url,
      title,
      downloadedAt: new Date().toISOString(),
      viewport,
      htmlSize: finalHTML.length,
      stylesSize: allStyles.length
    };
    const metadataPath = path.join(outputDir, 'metadata.json');
    fs.writeFileSync(metadataPath, JSON.stringify(metadata, null, 2));
    console.log(`Metadata: ${metadataPath}`);

    console.log('\nDone!');
    console.log(`  HTML size: ${(finalHTML.length / 1024).toFixed(1)} KB`);
    console.log(`  CSS size: ${(allStyles.length / 1024).toFixed(1)} KB`);

  } finally {
    await browser.close();
  }
}

// Main
const args = process.argv.slice(2);

// Parse flags
const simplified = args.includes('--simplified');
const inlineComputed = args.includes('--inline-computed');

// Parse --width and --height options
let viewportWidth = VIEWPORT.width;
let viewportHeight = VIEWPORT.height;
for (const arg of args) {
  if (arg.startsWith('--width=')) {
    viewportWidth = parseInt(arg.split('=')[1], 10) || VIEWPORT.width;
  }
  if (arg.startsWith('--height=')) {
    viewportHeight = parseInt(arg.split('=')[1], 10) || VIEWPORT.height;
  }
}

const filteredArgs = args.filter(a => !a.startsWith('--'));

if (filteredArgs.length === 0) {
  console.log('Usage: npx tsx tools/download-site.ts <url> [output-name] [options]');
  console.log('');
  console.log('Options:');
  console.log('  --simplified       Remove hidden elements and style tags');
  console.log('  --inline-computed  Inline computed CSS styles (for CSS-in-JS sites)');
  console.log('  --width=<px>       Viewport width (default: 1280)');
  console.log('  --height=<px>      Viewport height (default: 800)');
  console.log('');
  console.log('Examples:');
  console.log('  npx tsx tools/download-site.ts https://www.google.com google');
  console.log('  npx tsx tools/download-site.ts https://zenn.dev/mizchi --simplified --inline-computed');
  console.log('  npx tsx tools/download-site.ts https://example.com --width=800 --height=600');
  process.exit(1);
}

const url = filteredArgs[0];
let outputName = filteredArgs[1];

if (!outputName) {
  // Generate name from URL
  try {
    const urlObj = new URL(url);
    outputName = urlObj.hostname.replace(/^www\./, '').replace(/\./g, '-');
    if (urlObj.pathname !== '/') {
      outputName += urlObj.pathname.replace(/\//g, '-').replace(/-$/, '');
    }
  } catch {
    outputName = 'download';
  }
}

downloadSite({
  url,
  outputName,
  inlineImages: true,
  waitFor: 3000,
  simplified,
  inlineComputed,
  viewportWidth,
  viewportHeight
}).catch(err => {
  console.error('Error:', err);
  process.exit(1);
});
