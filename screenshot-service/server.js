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

// Detect error/garbage pages that should NOT be cached
function detectErrorPage(page, httpStatus) {
  return page.evaluate((status) => {
    const text = (document.body?.innerText || '').toLowerCase();
    const title = (document.title || '').toLowerCase();

    // HTTP-level errors
    if (status >= 400) return `HTTP ${status}`;

    // Cloudflare errors
    if (/error \d{3}/.test(title) && /cloudflare/i.test(text)) return 'Cloudflare error page';
    if (/connection timed out|error 522|error 521|error 520|error 523|error 524|error 525|error 526/.test(text) && /cloudflare/.test(text)) return 'Cloudflare error';

    // Generic error pages
    if (/502 bad gateway|503 service|504 gateway|500 internal server/i.test(text) && text.length < 2000) return 'Server error page';

    // Hosting/parking pages
    if (/this domain|domain is parked|domain has expired|buy this domain|this site can.t be reached/i.test(text) && text.length < 1000) return 'Parked/expired domain';

    // Blank or near-blank pages
    if (text.trim().length < 20) return 'Blank page';

    return null;
  }, httpStatus);
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

// Fingerprint profiles for cloaker bypass retry rotation
// Each attempt uses a different profile to fool antifraud checks
const FINGERPRINT_PROFILES = [
  // Profile 0: use caller-provided params (mobile from workflow) — handled separately
  null,
  // Profile 1: Desktop Chrome (Windows) — fresh, like SunBrowser
  {
    user_agent: 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/145.0.7535.50 Safari/537.36',
    viewport: { width: 1920, height: 1080 },
    isMobile: false,
    hasTouch: false,
  },
  // Profile 2: Desktop Chrome (Mac)
  {
    user_agent: 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/145.0.7535.50 Safari/537.36',
    viewport: { width: 1440, height: 900 },
    isMobile: false,
    hasTouch: false,
  },
  // Profile 3: Mobile Samsung (Android 16)
  {
    user_agent: 'Mozilla/5.0 (Linux; Android 16; SM-S936B) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/145.0.7535.50 Mobile Safari/537.36',
    viewport: { width: 412, height: 915 },
    isMobile: true,
    hasTouch: true,
  },
];

const MAX_CAPTURE_RETRIES = parseInt(process.env.MAX_CAPTURE_RETRIES || '3', 10);

// Stealth scripts — injected BEFORE page navigation to hide headless/automation markers
// Cloakers check these via JS: navigator.webdriver, chrome object, plugins, WebGL, etc.
const STEALTH_SCRIPTS = `
  // 1. Hide navigator.webdriver (primary headless detection)
  Object.defineProperty(navigator, 'webdriver', { get: () => false });

  // 2. Fake window.chrome object (missing in headless Chromium)
  if (!window.chrome) {
    window.chrome = {
      runtime: {
        onMessage: { addListener: function(){}, removeListener: function(){} },
        sendMessage: function(){},
        connect: function(){ return { onMessage: { addListener: function(){} }, postMessage: function(){} }; }
      },
      loadTimes: function(){ return {}; },
      csi: function(){ return {}; },
      app: { isInstalled: false, getIsInstalled: function(){ return false; }, installState: 'disabled' }
    };
  }

  // 3. Fake plugins (headless has empty plugins array)
  Object.defineProperty(navigator, 'plugins', {
    get: () => {
      const plugins = [
        { name: 'Chrome PDF Plugin', filename: 'internal-pdf-viewer', description: 'Portable Document Format', length: 1, item: function(i){ return this[i]; }, 0: { type: 'application/x-google-chrome-pdf', suffixes: 'pdf', description: 'Portable Document Format' } },
        { name: 'Chrome PDF Viewer', filename: 'mhjfbmdgcfjbbpaeojofohoefgiehjai', description: '', length: 1, item: function(i){ return this[i]; }, 0: { type: 'application/pdf', suffixes: 'pdf', description: '' } },
        { name: 'Native Client', filename: 'internal-nacl-plugin', description: '', length: 2, item: function(i){ return this[i]; }, 0: { type: 'application/x-nacl', suffixes: '', description: 'Native Client Executable' }, 1: { type: 'application/x-pnacl', suffixes: '', description: 'Portable Native Client Executable' } }
      ];
      plugins.namedItem = function(name) { return this.find(p => p.name === name) || null; };
      plugins.refresh = function(){};
      return plugins;
    }
  });

  // 4. Fake languages (headless may have empty array)
  Object.defineProperty(navigator, 'languages', {
    get: () => [navigator.language || 'en-US', 'en']
  });

  // 5. Fix permissions API (headless returns 'denied' for notifications)
  const origQuery = window.Permissions?.prototype?.query;
  if (origQuery) {
    window.Permissions.prototype.query = function(params) {
      if (params.name === 'notifications') {
        return Promise.resolve({ state: 'default', onchange: null });
      }
      return origQuery.call(this, params);
    };
  }

  // 6. Fake WebGL vendor/renderer (headless shows "Google SwiftShader")
  const getParameterOrig = WebGLRenderingContext.prototype.getParameter;
  WebGLRenderingContext.prototype.getParameter = function(param) {
    if (param === 37445) return 'Google Inc. (NVIDIA)';  // UNMASKED_VENDOR_WEBGL
    if (param === 37446) return 'ANGLE (NVIDIA, NVIDIA GeForce GTX 1060 6GB Direct3D11 vs_5_0 ps_5_0, D3D11)';  // UNMASKED_RENDERER_WEBGL
    return getParameterOrig.call(this, param);
  };
  if (typeof WebGL2RenderingContext !== 'undefined') {
    const getParameter2Orig = WebGL2RenderingContext.prototype.getParameter;
    WebGL2RenderingContext.prototype.getParameter = function(param) {
      if (param === 37445) return 'Google Inc. (NVIDIA)';
      if (param === 37446) return 'ANGLE (NVIDIA, NVIDIA GeForce GTX 1060 6GB Direct3D11 vs_5_0 ps_5_0, D3D11)';
      return getParameter2Orig.call(this, param);
    };
  }

  // 7. Fake media devices (headless has none)
  if (navigator.mediaDevices?.enumerateDevices) {
    const origEnum = navigator.mediaDevices.enumerateDevices.bind(navigator.mediaDevices);
    navigator.mediaDevices.enumerateDevices = async function() {
      const devices = await origEnum();
      if (devices.length === 0) {
        return [
          { deviceId: 'default', kind: 'audioinput', label: '', groupId: 'default' },
          { deviceId: 'default', kind: 'audiooutput', label: '', groupId: 'default' },
          { deviceId: 'default', kind: 'videoinput', label: '', groupId: 'default' },
        ];
      }
      return devices;
    };
  }

  // 8. Fix platform for consistency with User-Agent
  // (navigator.platform will be set by Playwright based on UA, but override if needed)

  // 9. Fake connection info
  if (!navigator.connection) {
    Object.defineProperty(navigator, 'connection', {
      get: () => ({
        downlink: 10, effectiveType: '4g', rtt: 50, saveData: false,
        onchange: null, addEventListener: function(){}, removeEventListener: function(){}
      })
    });
  }

  // 10. Hide automation-related properties
  delete window.__playwright;
  delete window.__pw_manual;
`;

// Extract referer from cloaker URL — `blp` param contains the publisher page URL
function extractReferer(url) {
  try {
    const u = new URL(url);
    // Common cloaker params that contain the referrer/publisher URL
    const refParam = u.searchParams.get('blp') || u.searchParams.get('ref')
      || u.searchParams.get('referrer') || u.searchParams.get('back_url');
    if (refParam && refParam.startsWith('http')) return refParam;
    return null;
  } catch {
    return null;
  }
}

// Build Chrome Sec-CH-UA header from User-Agent
function buildSecChUa(ua) {
  const chromeMatch = ua.match(/Chrome\/(\d+)/);
  const ver = chromeMatch ? chromeMatch[1] : '145';
  // Chromium-based browsers send these brand hints
  return `"Chromium";v="${ver}", "Google Chrome";v="${ver}", "Not-A.Brand";v="99"`;
}

// Build Playwright context options from fingerprint params
function buildContextOptions(params, retryProfile, captureUrl) {
  const profile = retryProfile || {};
  const ua = profile.user_agent || params.user_agent
    || 'Mozilla/5.0 (Linux; Android 15; SM-S928B) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/145.0.7535.50 Mobile Safari/537.36';
  const vp = profile.viewport || params.viewport || { width: 412, height: 915 };
  const isMobile = profile.isMobile !== undefined ? profile.isMobile : ua.toLowerCase().includes('mobile');

  const opts = {
    viewport: { width: vp.width || 412, height: vp.height || 915 },
    userAgent: ua,
    locale: params.locale || 'en-US',
    ignoreHTTPSErrors: true,
  };
  if (params.timezone_id) opts.timezoneId = params.timezone_id;

  // Mobile flags
  if (isMobile) {
    opts.isMobile = true;
    opts.hasTouch = true;
  }

  // Build HTTP headers that real Chrome sends — cloakers check these server-side
  const headers = {};

  // Accept-Language
  if (params.accept_language) {
    headers['Accept-Language'] = params.accept_language;
  }

  // Sec-CH-UA client hints — Chrome sends these on every request
  headers['Sec-CH-UA'] = buildSecChUa(ua);
  headers['Sec-CH-UA-Mobile'] = isMobile ? '?1' : '?0';
  headers['Sec-CH-UA-Platform'] = ua.includes('Windows') ? '"Windows"'
    : ua.includes('Macintosh') ? '"macOS"'
    : ua.includes('Android') ? '"Android"'
    : ua.includes('iPhone') || ua.includes('iPad') ? '"iOS"'
    : '"Linux"';

  // Sec-Fetch-* headers — real browsers always send these for navigation
  headers['Sec-Fetch-Dest'] = 'document';
  headers['Sec-Fetch-Mode'] = 'navigate';
  headers['Sec-Fetch-Site'] = 'cross-site';
  headers['Sec-Fetch-User'] = '?1';
  headers['Upgrade-Insecure-Requests'] = '1';

  // Referer — critical for cloakers that check traffic source
  // Extract from URL params (blp, ref) or use a search engine
  const referer = extractReferer(captureUrl) || params.referer || '';
  if (referer) {
    headers['Referer'] = referer;
  }

  opts.extraHTTPHeaders = headers;

  return opts;
}

// Single capture attempt — returns { success, errorReason, httpStatus, page, browser, collectedAssets, assetUrls }
async function attemptCapture(url, proxyConfig, contextOptions) {
  const launchOptions = {
    headless: true,
    args: [
      '--disable-blink-features=AutomationControlled',  // removes navigator.webdriver at browser level
      '--disable-features=IsolateOrigins,site-per-process',  // reduce fingerprint differences
      '--disable-site-isolation-trials',
      '--disable-web-security',   // allow cross-origin for TDS redirects
      '--no-first-run',
      '--no-default-browser-check',
    ],
  };
  if (proxyConfig) launchOptions.proxy = proxyConfig;

  const browser = await chromium.launch(launchOptions);
  const context = await browser.newContext(contextOptions);

  // Inject stealth scripts BEFORE any page loads — critical for cloaker bypass
  await context.addInitScript(STEALTH_SCRIPTS);

  const page = await context.newPage();

  // Collect assets via network interception
  const collectedAssets = [];
  const assetUrls = new Map();
  let assetIdx = 0;
  page.on('response', async (response) => {
    try {
      const resUrl = response.url();
      const contentType = response.headers()['content-type'] || '';
      const status = response.status();
      if (status < 200 || status >= 400) return;
      const isAsset = /\.(png|jpg|jpeg|gif|webp|svg|css|js|woff2?|ttf|eot|ico)(\?|$)/i.test(resUrl)
        || /image\/|text\/css|javascript|font\//i.test(contentType);
      if (isAsset && !assetUrls.has(resUrl)) {
        let localPath = '';
        try {
          const parsed = new URL(resUrl);
          const safeDomain = parsed.hostname.replace(/[^a-zA-Z0-9.-]/g, '_');
          let safePath = parsed.pathname.replace(/^\/+/, '').replace(/[^a-zA-Z0-9._\/-]/g, '_');
          if (!safePath || safePath.endsWith('/')) {
            const ext = (contentType.split('/')[1] || 'bin').split(';')[0].replace('javascript', 'js').replace('svg+xml', 'svg');
            safePath += `index_${assetIdx}.${ext}`;
          }
          localPath = `${safeDomain}/${safePath}`;
        } catch {
          const ext = (contentType.split('/')[1] || 'bin').split(';')[0].replace('javascript', 'js').replace('svg+xml', 'svg');
          localPath = `unknown/${assetIdx}.${ext}`;
        }
        assetIdx++;
        assetUrls.set(resUrl, localPath);
        const body = await response.body().catch(() => null);
        if (body) {
          collectedAssets.push({ url: resUrl, filename: localPath, buffer: body });
        }
      }
    } catch {}
  });

  // Navigate and wait for content
  const startUrl = url;
  const response = await page.goto(url, { waitUntil: 'networkidle', timeout: TIMEOUT });
  const httpStatus = response ? response.status() : 0;

  // Debug: log HTTP response details for the main navigation
  if (response) {
    const respHeaders = response.headers();
    const contentType = respHeaders['content-type'] || 'none';
    const contentLength = respHeaders['content-length'] || 'unknown';
    const server = respHeaders['server'] || respHeaders['x-powered-by'] || 'unknown';
    console.log(`[capture] HTTP ${httpStatus} | content-type: ${contentType} | content-length: ${contentLength} | server: ${server} | final-url: ${page.url()}`);
  }

  // Wait for page to be fully rendered
  await page.waitForTimeout(3000);

  // Check if page did a JS redirect (cloaker TDS) — wait for it to complete
  const currentUrl = page.url();
  if (currentUrl !== startUrl) {
    console.log(`[capture] JS redirect detected: ${startUrl} -> ${currentUrl}`);
    // Wait for the redirected page to fully load
    try {
      await page.waitForLoadState('networkidle', { timeout: 15000 });
    } catch {}
    await page.waitForTimeout(2000);
  }

  // Also check for pending meta-refresh / JS location changes
  const pendingRedirect = await page.evaluate(() => {
    // Check meta refresh
    const meta = document.querySelector('meta[http-equiv="refresh"]');
    if (meta) {
      const match = meta.content.match(/url=(.+)/i);
      if (match) return match[1].trim().replace(/['"]/g, '');
    }
    // Check for JS redirect patterns in inline scripts
    const scripts = document.querySelectorAll('script:not([src])');
    for (const s of scripts) {
      const code = s.textContent || '';
      const locMatch = code.match(/(?:window\.location|location\.href|location\.replace)\s*[=(]\s*["']([^"']+)["']/);
      if (locMatch && locMatch[1].startsWith('http')) return locMatch[1];
    }
    return null;
  });

  if (pendingRedirect) {
    console.log(`[capture] Following pending redirect: ${pendingRedirect}`);
    try {
      await page.goto(pendingRedirect, { waitUntil: 'networkidle', timeout: TIMEOUT });
      await page.waitForTimeout(3000);
    } catch (err) {
      console.log(`[capture] Redirect follow failed: ${err.message}`);
    }
  }

  // Scroll down to trigger lazy-loaded images
  await page.evaluate(() => window.scrollTo(0, document.body.scrollHeight));
  await page.waitForTimeout(1500);
  await page.evaluate(() => window.scrollTo(0, 0));
  await page.waitForTimeout(500);

  // Detect error/garbage pages
  const errorReason = await detectErrorPage(page, httpStatus);

  // Debug logging for blank pages — helps diagnose what cloaker returned
  if (errorReason) {
    const debugInfo = await page.evaluate(() => ({
      url: location.href,
      title: document.title,
      bodyText: (document.body?.innerText || '').substring(0, 200),
      bodyHTML: (document.body?.innerHTML || '').substring(0, 500),
      scripts: document.querySelectorAll('script').length,
      iframes: document.querySelectorAll('iframe').length,
    }));
    console.log(`[capture] Debug (${errorReason}): url=${debugInfo.url} title="${debugInfo.title}" scripts=${debugInfo.scripts} iframes=${debugInfo.iframes} bodyText="${debugInfo.bodyText}" bodyHTML="${debugInfo.bodyHTML.substring(0, 200)}"`);
  }

  return { success: !errorReason, errorReason, httpStatus, page, browser, collectedAssets, assetUrls };
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
  console.log(`[archive] Creating ${baseName}.zip with ${assets.length} assets:`);
  for (const asset of assets) {
    console.log(`  [asset] ${asset.filename} (${(asset.buffer.length / 1024).toFixed(1)} KB) <- ${asset.url}`);
  }
  return new Promise((resolve, reject) => {
    const output = fs.createWriteStream(zipPath);
    const archive = archiver('zip', { zlib: { level: 6 } });

    output.on('close', () => {
      const sizeMB = (archive.pointer() / 1024 / 1024).toFixed(2);
      console.log(`[archive] Done: ${baseName}.zip (${sizeMB} MB, ${assets.length} assets)`);
      resolve(zipPath);
    });
    archive.on('error', reject);

    archive.pipe(output);
    archive.append(htmlContent, { name: 'index.html' });
    // Add collected assets preserving original path structure
    for (const asset of assets) {
      archive.append(asset.buffer, { name: asset.filename });
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
// Retries with different fingerprint profiles if cloaker blocks the page
app.post('/capture', async (req, res) => {
  const { url, proxy, viewport, force, user_agent, locale, timezone_id, accept_language } = req.body;

  if (!url) {
    return res.status(400).json({ error: 'url is required' });
  }

  const baseName = urlToFilename(url);
  const screenshotPath = path.join(SCREENSHOTS_DIR, `${baseName}.png`);
  const screenshotRelative = `screenshots/${baseName}.png`;
  const archiveRelative = `archives/${baseName}.zip`;

  // Check if already captured (skip if force=true)
  if (!force && fs.existsSync(screenshotPath)) {
    const archivePath = path.join(ARCHIVES_DIR, `${baseName}.zip`);
    return res.json({
      captured: true,
      screenshot_path: screenshotRelative,
      archive_path: fs.existsSync(archivePath) ? archiveRelative : null,
      cached: true,
    });
  }

  await acquireSlot();

  const params = { user_agent, locale, timezone_id, accept_language, viewport };
  const proxyConfig = parseProxy(proxy);
  let lastErrorReason = null;
  let lastHttpStatus = 0;

  try {
    // Retry with different fingerprint profiles to bypass cloaker
    for (let attempt = 0; attempt <= MAX_CAPTURE_RETRIES; attempt++) {
      const profile = attempt === 0 ? null : FINGERPRINT_PROFILES[attempt] || FINGERPRINT_PROFILES[1];
      const contextOptions = buildContextOptions(params, profile, url);

      const profileName = attempt === 0 ? 'caller' : `profile-${attempt} (${(profile?.user_agent || '').includes('Mobile') ? 'mobile' : 'desktop'})`;
      console.log(`[capture] Attempt ${attempt + 1}/${MAX_CAPTURE_RETRIES + 1} for ${url} using ${profileName}`);

      let result;
      try {
        result = await attemptCapture(url, proxyConfig, contextOptions);
      } catch (err) {
        console.log(`[capture] Attempt ${attempt + 1} failed with error: ${err.message}`);
        lastErrorReason = err.message;
        continue;
      }

      if (result.success) {
        // Capture succeeded — take screenshot and build archive
        try {
          await result.page.screenshot({ path: screenshotPath, fullPage: true, type: 'png' });

          let htmlContent;
          try {
            htmlContent = await result.page.content();
          } catch {
            htmlContent = '<html><body>Failed to capture page content</body></html>';
          }

          for (const [assetUrl, localPath] of result.assetUrls) {
            const escaped = assetUrl.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
            htmlContent = htmlContent.replace(new RegExp(escaped, 'g'), localPath);
          }

          await createArchive(htmlContent, result.collectedAssets, baseName);

          await result.browser.close();

          if (attempt > 0) {
            console.log(`[capture] SUCCESS on attempt ${attempt + 1} for ${url}`);
          }

          return res.json({
            captured: true,
            screenshot_path: screenshotRelative,
            archive_path: archiveRelative,
            cached: false,
            attempts: attempt + 1,
          });
        } catch (err) {
          try { await result.browser.close(); } catch {}
          throw err;
        }
      } else {
        // Cloaker blocked — close browser (gets new IP on residential proxy) and retry
        lastErrorReason = result.errorReason;
        lastHttpStatus = result.httpStatus;
        console.log(`[capture] Attempt ${attempt + 1} blocked: ${result.errorReason}`);
        try { await result.browser.close(); } catch {}
      }
    }

    // All attempts exhausted
    console.log(`[capture] All ${MAX_CAPTURE_RETRIES + 1} attempts failed for ${url}: ${lastErrorReason}`);
    return res.json({
      captured: false,
      reason: lastErrorReason,
      http_status: lastHttpStatus,
      screenshot_path: null,
      archive_path: null,
      attempts: MAX_CAPTURE_RETRIES + 1,
    });
  } catch (err) {
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

// Screenshot only (with retry logic)
app.post('/screenshot', async (req, res) => {
  const { url, proxy, viewport, force, user_agent, locale, timezone_id, accept_language } = req.body;
  if (!url) return res.status(400).json({ error: 'url is required' });

  const baseName = urlToFilename(url);
  const screenshotPath = path.join(SCREENSHOTS_DIR, `${baseName}.png`);
  const screenshotRelative = `screenshots/${baseName}.png`;

  if (!force && fs.existsSync(screenshotPath)) {
    return res.json({ captured: true, screenshot_path: screenshotRelative, cached: true });
  }

  await acquireSlot();
  const params = { user_agent, locale, timezone_id, accept_language, viewport };
  const proxyConfig = parseProxy(proxy);
  let lastErrorReason = null;

  try {
    for (let attempt = 0; attempt <= MAX_CAPTURE_RETRIES; attempt++) {
      const profile = attempt === 0 ? null : FINGERPRINT_PROFILES[attempt] || FINGERPRINT_PROFILES[1];
      const contextOptions = buildContextOptions(params, profile, url);
      let browser;
      try {
        const launchOptions = {
          headless: true,
          args: [
            '--disable-blink-features=AutomationControlled',
            '--disable-features=IsolateOrigins,site-per-process',
            '--no-first-run',
            '--no-default-browser-check',
          ],
        };
        if (proxyConfig) launchOptions.proxy = proxyConfig;
        browser = await chromium.launch(launchOptions);
        const context = await browser.newContext(contextOptions);
        await context.addInitScript(STEALTH_SCRIPTS);
        const page = await context.newPage();
        const response = await page.goto(url, { waitUntil: 'networkidle', timeout: TIMEOUT });
        const httpStatus = response ? response.status() : 0;
        await page.waitForTimeout(2000);

        const errorReason = await detectErrorPage(page, httpStatus);
        if (errorReason) {
          lastErrorReason = errorReason;
          await browser.close();
          console.log(`[screenshot] Attempt ${attempt + 1} blocked: ${errorReason}`);
          continue;
        }

        await page.screenshot({ path: screenshotPath, fullPage: true, type: 'png' });
        await browser.close();
        return res.json({ captured: true, screenshot_path: screenshotRelative, cached: false, attempts: attempt + 1 });
      } catch (err) {
        if (browser) try { await browser.close(); } catch {}
        lastErrorReason = err.message;
        console.log(`[screenshot] Attempt ${attempt + 1} error: ${err.message}`);
      }
    }

    res.json({ captured: false, reason: lastErrorReason, screenshot_path: null, attempts: MAX_CAPTURE_RETRIES + 1 });
  } catch (err) {
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
