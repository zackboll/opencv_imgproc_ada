/* Optional real-browser qualification of the developer guides, adapted from
 * opencv_core_ada. Set PLAYWRIGHT_MODULE to a separately installed
 * Playwright module and serve _site over HTTP; no site runtime dependency.
 *
 *   python3 -m http.server 8074 --bind 127.0.0.1 --directory _site
 *   PLAYWRIGHT_MODULE=/path/to/node_modules/playwright DOC_URL=http://127.0.0.1:8074/ \
 *     node scripts/test_gnatdoc_guides_browser.cjs
 */
const {chromium} = require(process.env.PLAYWRIGHT_MODULE);
const assert = require('node:assert/strict');
const fs = require('node:fs');
const base = process.env.DOC_URL || 'http://127.0.0.1:8074/';
const evidence = process.env.DOC_EVIDENCE || '/tmp/imgproc-doc-005-screenshots';
const chrome = process.env.CHROME || '/usr/bin/google-chrome';
fs.mkdirSync(evidence, {recursive: true});
const names = ['filtering-and-transforms', 'color-and-image-representation',
  'features-and-structural-analysis', 'segmentation-contours-and-morphology',
  'template-matching-and-registration'];

(async () => {
  const browser = await chromium.launch({executablePath: chrome, headless: true});
  try {
    for (const width of [1280, 390]) for (const colorScheme of ['light', 'dark'])
      for (const javaScriptEnabled of [true, false]) {
        const context = await browser.newContext(
          {viewport: {width, height: 900}, colorScheme, javaScriptEnabled});
        await context.route('**/favicon.ico', route => route.fulfill({status: 204}));
        await context.route(/^https:\/\//, route => route.fulfill(
          {status: 200, contentType: 'text/html', body: '<title>external stub</title>'}));
        const page = await context.newPage();
        const errors = [];
        page.on('pageerror', e => errors.push(e.message));
        page.on('console', m => { if (m.type() === 'error') errors.push(m.text()); });
        await page.goto(base);
        assert.equal(await page.locator('#developer-guides + ul a').count(), 5);
        for (const name of names) {
          await page.locator(`a[href="guides/${name}.html"]`).click();
          const url = new URL('guides/' + name + '.html', base).href;
          assert.equal(await page.locator('main').count(), 1);
          assert.equal(await page.locator('h1').count(), 1);
          assert.equal(await page.locator('.guide-nav [aria-current="page"]').getAttribute('href'),
                       name + '.html');
          assert.equal(await page.locator('.guide-source a').getAttribute('href'),
            `https://github.com/zackboll/opencv_imgproc_ada/blob/main/docs/guides/${name}.md`);
          assert.ok(await page.evaluate(() =>
            document.documentElement.scrollWidth <= innerWidth));
          assert.ok(await page.locator('pre, .table-scroll').evaluateAll(es => es.every(e =>
            e.scrollWidth <= e.clientWidth || getComputedStyle(e).overflowX === 'auto')));
          // Every API link lands on the native declaration it names.
          const api = await page.locator('main a[href^="../api/"]').evaluateAll(es =>
            es.map(e => [e.getAttribute('href'), e.textContent]));
          assert.ok(api.length >= 5);
          for (const [href, text] of api.slice(0, 6)) {
            await page.goto(new URL(href, url).href);
            const heading = await page.locator(':target').textContent();
            const declaration = text.replace(/^(masked|unmasked|windowed) overload$/, '')
              .replace(/^second overload$/, '');
            if (/^[A-Z][A-Za-z0-9_]*$/.test(declaration)) assert.equal(heading, declaration);
            assert.ok(/^[A-Z][A-Za-z0-9_]*$/.test(heading));
          }
          await page.goto(url);
          const cross = await page.locator('main a[href$=".html"], main a[href*=".html#"]')
            .evaluateAll(es => es.map(e => e.getAttribute('href'))
              .filter(h => !h.startsWith('../') && !h.includes('://')));
          for (const destination of cross) {
            await page.goto(url);
            await page.locator(`main a[href="${destination}"]`).first().click();
            assert.equal(new URL(page.url()).pathname.split('/').pop(),
                         destination.split('#')[0]);
          }
          await page.goto(url);
          await page.keyboard.press('Tab');
          assert.equal(await page.evaluate(() =>
            getComputedStyle(document.activeElement).outlineStyle), 'solid');
          // The focused skip link overlays the header; Enter follows it.
          await page.keyboard.press('Enter');
          await page.waitForFunction(() => location.hash === '#main-content');
          await page.goto(url);
          if (javaScriptEnabled) {
            await page.screenshot({path: `${evidence}/${name}-${width}-${colorScheme}.png`});
          }
          await page.getByRole('link', {name: 'Documentation home', exact: true}).click();
        }
        assert.deepEqual(errors, []);
        console.log(`PASS ${width}px ${colorScheme} JS=${javaScriptEnabled}: five guides, ` +
                    'API anchors, cross-links, focus, overflow');
        await context.close();
      }
  } finally {
    await browser.close();
  }
})().catch(error => { console.error(error); process.exitCode = 1; });
