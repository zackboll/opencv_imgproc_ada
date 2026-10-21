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
const path = require('node:path');
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
        // Optional exact-head Core Documentation artifact, not a fabricated
        // external response. URLs and cross-origin behavior remain published.
        if (process.env.CORE_DOC_SITE) {
          const root = path.resolve(process.env.CORE_DOC_SITE);
          await context.route('https://zackboll.github.io/opencv_core_ada/**', async route => {
            const url = new URL(route.request().url());
            const relative = decodeURIComponent(url.pathname.slice('/opencv_core_ada/'.length));
            const file = path.resolve(root, relative || 'index.html');
            assert.ok(file.startsWith(root + path.sep));
            assert.ok(fs.statSync(file).isFile());
            await route.fulfill({path: file});
          });
        }
        const page = await context.newPage();
        const errors = [];
        page.on('pageerror', e => errors.push(e.message));
        page.on('console', m => { if (m.type() === 'error') errors.push(m.text()); });
        await page.goto(base);
        assert.equal(await page.locator('#developer-guides + ul a').count(), 5);
        const coreSeen = new Set();
        async function examples(url) {
          const block = page.locator('pre.ada-example');
          assert.equal(await block.count(), 1);
          assert.ok(await block.locator('.ada-keyword').count());
          assert.ok(await block.locator('.ada-number').count());
          assert.ok(await block.locator('.ada-operator').count());
          assert.equal(await block.getAttribute('tabindex'), '0');
          const palette = await block.locator('.ada-keyword').first().evaluate(e => ({
            actual: getComputedStyle(e).color,
            variable: getComputedStyle(e).getPropertyValue('--keyword').trim()
          }));
          assert.equal(palette.variable, colorScheme === 'dark' ? '#d4a8ff' : '#7040a0');
          assert.notEqual(palette.actual, await block.evaluate(e => getComputedStyle(e).color));
          assert.ok(await page.evaluate(() => document.documentElement.scrollWidth <= innerWidth));
          const links = await block.locator('a.type-reference').evaluateAll(es =>
            es.map(e => ({href: e.getAttribute('href'), identity: e.dataset.type})));
          assert.ok(links.length);
          for (const {href, identity} of links.filter((e, i, a) =>
            a.findIndex(x => x.identity === e.identity) === i)) {
            if (href.startsWith('https:') && coreSeen.has(identity)) continue;
            await page.goto(url);
            const link = page.locator(`pre.ada-example a[data-type="${identity}"]`).first();
            await link.focus();
            // Keyboard, not a synthetic click; :focus-visible is required.
            await page.keyboard.press('Tab');
            await page.keyboard.press('Shift+Tab');
            assert.equal(await link.evaluate(e => document.activeElement === e), true);
            assert.equal(await link.evaluate(e => getComputedStyle(e).outlineStyle), 'solid');
            await page.keyboard.press('Enter');
            await page.waitForURL(u => href.startsWith('https:')
              ? u.origin === 'https://zackboll.github.io'
              : u.pathname === new URL(href, url).pathname);
            const simple = identity.split('.').pop();
            if (!href.startsWith('https:')) {
              assert.equal((await page.locator('h4:target').textContent()).toLowerCase(), simple);
              assert.equal(new URL(page.url()).hash, new URL(href, url).hash);
            } else {
              coreSeen.add(identity);
              assert.equal(new URL(href).searchParams.get('symbol').toLowerCase(), identity);
              const symbol = page.locator('#type-navigation a');
              const observed = await symbol.evaluateAll((es, id) => es
                .filter(e => e.dataset.symbol.toLowerCase() === id)
                .map(e => e.getAttribute('href')), identity);
              assert.equal(observed.length, 1, 'published Core symbol missing');
              const frame = page.frameLocator('iframe[name="document-content"]');
              if (!javaScriptEnabled) {
                // Core's documented no-JS fallback is native package navigation,
                // not interpretation of ?symbol=. Use its observed native href.
                const owner = identity.slice(0, identity.lastIndexOf('.'));
                const packageLink = page.locator('.content-column a').filter({
                  hasText: new RegExp('^' + owner.replaceAll('.', '\\.') + '$', 'i')});
                await packageLink.click();
                await frame.locator(`a[href="#${observed[0].split('#')[1]}"]`).first().click();
              }
              await frame.locator('h4:target').waitFor();
              assert.equal((await frame.locator('h4:target').textContent()).toLowerCase(), simple);
              const child = page.frames().find(f => f.url().includes(observed[0]));
              assert.ok(child, 'Core did not reach its indexed native declaration');
            }
            if (!href.startsWith('https:') || javaScriptEnabled) {
              await page.goBack();
              assert.equal(page.url(), url);
              await page.goForward();
              if (!href.startsWith('https:')) {
                assert.equal((await page.locator('h4:target').textContent()).toLowerCase(), simple);
              } else {
                await page.frameLocator('iframe[name="document-content"]').locator('h4:target').waitFor();
              }
            }
          }
          await page.goto(url);
          await block.focus();
          assert.equal(await block.evaluate(e => getComputedStyle(e).overflowX), 'auto');
        }
        await examples(base);
        await page.screenshot({path: `${evidence}/landing-${width}-${colorScheme}-js${javaScriptEnabled}.png`});
        for (const name of names) {
          await page.locator(`a[href="guides/${name}.html"]`).click();
          const url = new URL('guides/' + name + '.html', base).href;
          await examples(url);
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
          const api = await page.locator('main a[href^="../api/"]:not(.type-reference)').evaluateAll(es =>
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
        assert.equal(coreSeen.size, 7);
        console.log(`PASS ${width}px ${colorScheme} JS=${javaScriptEnabled}: five guides, ` +
                    'API anchors, cross-links, focus, overflow');
        await context.close();
      }
  } finally {
    await browser.close();
  }
})().catch(error => { console.error(error); process.exitCode = 1; });
