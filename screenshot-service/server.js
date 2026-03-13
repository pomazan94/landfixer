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

// Strip tracking query params — same page with different affiliate params = same file
function stripTrackingParams(url) {
  try {
    const u = new URL(url);
    // Remove known tracking/affiliate params, keep meaningful ones
    const trackingKeys = [
      'utm_source','utm_medium','utm_campaign','utm_content','utm_term',
      'subid','subid1','subid2','subid3','subid4','subid5',
      'sid1','sid2','sid3','sid4','sid5','sid6','sid7',
      'click_id','clickid','click','clid','gclid','fbclid',
      'c1','c2','c3','c4','c5','mpc3',
      'blockid','block','block_id','siteid','adid','ad_id',
      'adgroupid','ad_campaign_id','creative_id',
      'source','cost','bid','cs','price',
      'ref','referrer','aff_id','offer_id','pid','tid',
      'external_id','transaction_id','idfa','gaid','sub1','sub2','sub3','sub4','sub5',
      'fbpixel','pixel','ttclid','sclid','msclkid','twclid','li_fat_id',
    ];
    for (const key of trackingKeys) {
      u.searchParams.delete(key);
      u.searchParams.delete(key.toUpperCase());
    }
    return u.toString();
  } catch {
    return url;
  }
}

// Generate unique filename from URL (ignores tracking params)
function urlToFilename(url) {
  const cleanUrl = stripTrackingParams(url);
  const hash = crypto.createHash('md5').update(cleanUrl).digest('hex').slice(0, 10);
  const domain = cleanUrl.replace(/^https?:\/\//, '').replace(/[^a-zA-Z0-9.-]/g, '_').slice(0, 60);
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

// Create ZIP archive with HTML + collected assets
async function createArchive(htmlContent, assets, baseName) {
  const zipPath = path.join(ARCHIVES_DIR, `${baseName}.zip`);
  return new Promise((resolve, reject) => {
    const output = fs.createWriteStream(zipPath);
    const archive = archiver('zip', { zlib: { level: 6 } });

    output.on('close', () => resolve(zipPath));
    archive.on('error', reject);

    archive.pipe(output);
    archive.append(htmlContent, { name: 'index.html' });
    // Add collected assets (images, css, js, fonts)
    for (const asset of assets) {
      archive.append(asset.buffer, { name: 'assets/' + asset.filename });
    }
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

    // Collect assets via network interception
    const collectedAssets = [];
    const assetUrls = new Map(); // url -> local filename
    let assetIdx = 0;
    page.on('response', async (response) => {
      try {
        const resUrl = response.url();
        const contentType = response.headers()['content-type'] || '';
        const status = response.status();
        if (status < 200 || status >= 400) return;
        // Collect images, CSS, JS, fonts
        const isAsset = /\.(png|jpg|jpeg|gif|webp|svg|css|js|woff2?|ttf|eot|ico)(\?|$)/i.test(resUrl)
          || /image\/|text\/css|javascript|font\//i.test(contentType);
        if (isAsset && !assetUrls.has(resUrl)) {
          const ext = (contentType.split('/')[1] || 'bin').split(';')[0].replace('javascript', 'js').replace('svg+xml', 'svg');
          const filename = `${assetIdx++}_${crypto.createHash('md5').update(resUrl).digest('hex').slice(0, 8)}.${ext}`;
          assetUrls.set(resUrl, filename);
          const body = await response.body().catch(() => null);
          if (body) {
            collectedAssets.push({ url: resUrl, filename, buffer: body });
          }
        }
      } catch {}
    });

    // Navigate and wait for content
    await page.goto(url, {
      waitUntil: 'networkidle',
      timeout: TIMEOUT,
    });

    // Wait for page to be fully rendered
    await page.waitForTimeout(3000);

    // Scroll down to trigger lazy-loaded images
    await page.evaluate(() => window.scrollTo(0, document.body.scrollHeight));
    await page.waitForTimeout(1500);
    await page.evaluate(() => window.scrollTo(0, 0));
    await page.waitForTimeout(500);

    // Check if page has visible content (anti-blank detection)
    const hasContent = await page.evaluate(() => {
      const body = document.body;
      return body && body.innerText.trim().length > 10;
    });

    if (!hasContent) {
      // Try waiting more for JS-heavy pages
      await page.waitForTimeout(5000);
    }

    // Take screenshot
    await page.screenshot({
      path: screenshotPath,
      fullPage: true,
      type: 'png',
    });

    // Build archive HTML — replace asset URLs with local paths
    let htmlContent;
    try {
      htmlContent = await page.content();
    } catch {
      htmlContent = '<html><body>Failed to capture page content</body></html>';
    }

    // Replace absolute URLs with local asset paths in HTML
    for (const [assetUrl, filename] of assetUrls) {
      // Escape special regex chars in URL
      const escaped = assetUrl.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
      htmlContent = htmlContent.replace(new RegExp(escaped, 'g'), 'assets/' + filename);
    }

    // Create ZIP archive with HTML + assets
    const zipPath = await createArchive(
      htmlContent,
      collectedAssets,
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
