const express = require('express');
const { chromium } = require('playwright');
const archiver = require('archiver');
const fs = require('fs');
const path = require('path');
const crypto = require('crypto');

const app = express();
app.use(express.json());

const DATA_DIR = process.env.DATA_DIR || '/data';
const SCREENSHOTS_DIR = path.join(DATA_DIR, 'screenshots');
const ARCHIVES_DIR = path.join(DATA_DIR, 'archives');
const PORT = process.env.PORT || 3000;
const TIMEOUT = parseInt(process.env.PAGE_TIMEOUT || '45000', 10);

// Ensure dirs exist
[SCREENSHOTS_DIR, ARCHIVES_DIR].forEach(d => fs.mkdirSync(d, { recursive: true }));

// Generate unique filename from URL
function urlToFilename(url) {
  const hash = crypto.createHash('md5').update(url).digest('hex').slice(0, 10);
  const domain = url.replace(/^https?:\/\//, '').replace(/[^a-zA-Z0-9.-]/g, '_').slice(0, 60);
  return `${domain}_${hash}`;
}

// Parse proxy URL into Playwright format
// Input: socks5://user:pass@host:port or http://user:pass@host:port
function parseProxy(proxyUrl) {
  if (!proxyUrl) return undefined;
  try {
    const url = new URL(proxyUrl);
    return {
      server: `${url.protocol}//${url.hostname}:${url.port}`,
      username: url.username || undefined,
      password: url.password || undefined,
    };
  } catch {
    return undefined;
  }
}

// Inline external resources (CSS, images) as data URIs for offline viewing
async function inlineResources(page) {
  return await page.evaluate(async () => {
    // Inline stylesheets
    const links = document.querySelectorAll('link[rel="stylesheet"]');
    for (const link of links) {
      try {
        const resp = await fetch(link.href);
        if (resp.ok) {
          const css = await resp.text();
          const style = document.createElement('style');
          style.textContent = css;
          link.replaceWith(style);
        }
      } catch {}
    }

    // Inline images as data URIs
    const imgs = document.querySelectorAll('img[src]');
    for (const img of imgs) {
      if (img.src.startsWith('data:')) continue;
      try {
        const resp = await fetch(img.src);
        if (resp.ok) {
          const blob = await resp.blob();
          const reader = new FileReader();
          const dataUri = await new Promise((resolve) => {
            reader.onloadend = () => resolve(reader.result);
            reader.readAsDataURL(blob);
          });
          img.setAttribute('src', dataUri);
        }
      } catch {}
    }

    // Inline background images in style attributes
    const allEls = document.querySelectorAll('[style*="background"]');
    for (const el of allEls) {
      const bgMatch = el.style.backgroundImage?.match(/url\(["']?(https?:\/\/[^"')]+)["']?\)/);
      if (bgMatch) {
        try {
          const resp = await fetch(bgMatch[1]);
          if (resp.ok) {
            const blob = await resp.blob();
            const reader = new FileReader();
            const dataUri = await new Promise((resolve) => {
              reader.onloadend = () => resolve(reader.result);
              reader.readAsDataURL(blob);
            });
            el.style.backgroundImage = `url(${dataUri})`;
          }
        } catch {}
      }
    }

    return document.documentElement.outerHTML;
  });
}

// Create ZIP archive from HTML content
async function createArchive(htmlContent, baseName) {
  const zipPath = path.join(ARCHIVES_DIR, `${baseName}.zip`);
  return new Promise((resolve, reject) => {
    const output = fs.createWriteStream(zipPath);
    const archive = archiver('zip', { zlib: { level: 6 } });

    output.on('close', () => resolve(zipPath));
    archive.on('error', reject);

    archive.pipe(output);
    archive.append(htmlContent, { name: 'index.html' });
    archive.finalize();
  });
}

// Semaphore for limiting concurrent captures
let activeCaptures = 0;
const MAX_CONCURRENT = parseInt(process.env.MAX_CONCURRENT || '3', 10);
const queue = [];

function acquireSlot() {
  return new Promise(resolve => {
    if (activeCaptures < MAX_CONCURRENT) {
      activeCaptures++;
      resolve();
    } else {
      queue.push(resolve);
    }
  });
}

function releaseSlot() {
  activeCaptures--;
  if (queue.length > 0) {
    activeCaptures++;
    queue.shift()();
  }
}

// Main capture endpoint — screenshot + download
app.post('/capture', async (req, res) => {
  const { url, proxy, viewport } = req.body;

  if (!url) {
    return res.status(400).json({ error: 'url is required' });
  }

  const baseName = urlToFilename(url);
  const screenshotPath = path.join(SCREENSHOTS_DIR, `${baseName}.png`);
  const screenshotRelative = `screenshots/${baseName}.png`;
  const archiveRelative = `archives/${baseName}.zip`;

  // Check if already captured
  if (fs.existsSync(screenshotPath)) {
    const archivePath = path.join(ARCHIVES_DIR, `${baseName}.zip`);
    return res.json({
      screenshot_path: screenshotRelative,
      archive_path: fs.existsSync(archivePath) ? archiveRelative : null,
      cached: true,
    });
  }

  await acquireSlot();
  let browser;

  try {
    const launchOptions = { headless: true };
    const proxyConfig = parseProxy(proxy);
    if (proxyConfig) {
      launchOptions.proxy = proxyConfig;
    }

    browser = await chromium.launch(launchOptions);
    const context = await browser.newContext({
      viewport: {
        width: viewport?.width || 1280,
        height: viewport?.height || 800,
      },
      userAgent: 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36',
      locale: 'en-US',
      ignoreHTTPSErrors: true,
    });

    const page = await context.newPage();

    // Navigate and wait for content
    await page.goto(url, {
      waitUntil: 'networkidle',
      timeout: TIMEOUT,
    });

    // Wait a bit for lazy-loaded content
    await page.waitForTimeout(2000);

    // Take screenshot
    await page.screenshot({
      path: screenshotPath,
      fullPage: true,
      type: 'png',
    });

    // Get page content with inlined resources
    let htmlContent;
    try {
      htmlContent = await inlineResources(page);
    } catch {
      // Fallback to raw HTML if inlining fails
      htmlContent = await page.content();
    }

    // Create ZIP archive
    const zipPath = await createArchive(
      `<!DOCTYPE html>\n<html>\n${htmlContent}\n</html>`,
      baseName
    );

    await browser.close();
    browser = null;

    res.json({
      screenshot_path: screenshotRelative,
      archive_path: archiveRelative,
      cached: false,
    });
  } catch (err) {
    if (browser) {
      try { await browser.close(); } catch {}
    }
    console.error(`Capture failed for ${url}:`, err.message);
    res.status(500).json({
      error: err.message,
      screenshot_path: null,
      archive_path: null,
    });
  } finally {
    releaseSlot();
  }
});

// Screenshot only
app.post('/screenshot', async (req, res) => {
  const { url, proxy, viewport } = req.body;
  if (!url) return res.status(400).json({ error: 'url is required' });

  const baseName = urlToFilename(url);
  const screenshotPath = path.join(SCREENSHOTS_DIR, `${baseName}.png`);
  const screenshotRelative = `screenshots/${baseName}.png`;

  if (fs.existsSync(screenshotPath)) {
    return res.json({ screenshot_path: screenshotRelative, cached: true });
  }

  await acquireSlot();
  let browser;
  try {
    const launchOptions = { headless: true };
    const proxyConfig = parseProxy(proxy);
    if (proxyConfig) launchOptions.proxy = proxyConfig;

    browser = await chromium.launch(launchOptions);
    const context = await browser.newContext({
      viewport: { width: viewport?.width || 1280, height: viewport?.height || 800 },
      userAgent: 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36',
      ignoreHTTPSErrors: true,
    });
    const page = await context.newPage();
    await page.goto(url, { waitUntil: 'networkidle', timeout: TIMEOUT });
    await page.waitForTimeout(2000);
    await page.screenshot({ path: screenshotPath, fullPage: true, type: 'png' });
    await browser.close();
    browser = null;

    res.json({ screenshot_path: screenshotRelative, cached: false });
  } catch (err) {
    if (browser) try { await browser.close(); } catch {}
    console.error(`Screenshot failed for ${url}:`, err.message);
    res.status(500).json({ error: err.message });
  } finally {
    releaseSlot();
  }
});

// Health check
app.get('/health', (req, res) => {
  res.json({
    status: 'ok',
    active_captures: activeCaptures,
    queue_length: queue.length,
  });
});

// Static file serving for screenshots and archives
app.use('/data', express.static(DATA_DIR));

app.listen(PORT, '0.0.0.0', () => {
  console.log(`Screenshot service running on port ${PORT}`);
  console.log(`Data directory: ${DATA_DIR}`);
  console.log(`Max concurrent captures: ${MAX_CONCURRENT}`);
});
