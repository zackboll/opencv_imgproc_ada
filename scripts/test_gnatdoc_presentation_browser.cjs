/* Optional real-browser qualification of the themed, linked and highlighted
 * site. Set PLAYWRIGHT_MODULE to a separately installed Playwright module and
 * serve _site over HTTP; this is not a documentation runtime dependency.
 *
 *   python3 -m http.server 8072 --bind 127.0.0.1 --directory _site
 *   PLAYWRIGHT_MODULE=/path/to/node_modules/playwright \
 *     node scripts/test_gnatdoc_presentation_browser.cjs
 */
const {chromium} = require(process.env.PLAYWRIGHT_MODULE);
const assert = require('node:assert/strict');
const fs = require('node:fs');
const root = process.env.DOC_URL || 'http://127.0.0.1:8072/';
const evidence = process.env.DOC_EVIDENCE || '/tmp/imgproc-doc-003-screenshots';
const chrome = process.env.CHROME || '/usr/bin/google-chrome';
const core = 'https://zackboll.github.io/opencv_core_ada/api/index.html?package=';
fs.mkdirSync(evidence, {recursive: true});

const background = {light: 'rgb(255, 255, 255)', dark: 'rgb(20, 27, 38)'};

async function noOverflow(target, label) {
  const sizes = await target.evaluate(() => ({
    scroll: document.documentElement.scrollWidth,
    client: document.documentElement.clientWidth}));
  assert.ok(sizes.scroll <= sizes.client + 1,
            `${label}: horizontal overflow ${sizes.scroll} > ${sizes.client}`);
}

(async () => {
  const browser = await chromium.launch({executablePath: chrome, headless: true});
  try {
    for (const width of [1280, 390]) for (const colorScheme of ['light', 'dark']) {
      const label = `${width}-${colorScheme}`;
      const context = await browser.newContext({viewport: {width, height: 900}, colorScheme});
      await context.route('**/favicon.ico', route => route.fulfill({status: 204}));
      await context.route(/^https:\/\/zackboll\.github\.io\//, route => route.fulfill({
        status: 200, contentType: 'text/html', body: '<title>Core stub</title>'}));
      const page = await context.newPage();
      const errors = [];
      page.on('pageerror', e => errors.push(e.message));
      page.on('console', m => { if (m.type() === 'error') errors.push(m.text()); });

      await page.goto(root + 'index.html');
      await noOverflow(page, `${label} landing`);
      assert.equal(await page.evaluate(() => getComputedStyle(document.documentElement)
        .backgroundColor), background[colorScheme]);
      await page.getByRole('link', {name: /Explore the API reference/}).waitFor();
      await page.screenshot({path: `${evidence}/landing-${label}.png`, fullPage: true});

      await page.goto(root + 'api/index.html');
      await page.getByRole('link', {name: 'OpenCV.Image_Processing', exact: true}).click();
      const frame = page.frameLocator('iframe[name="document-content"]');
      await frame.locator('h1', {hasText: 'OpenCV.Image_Processing'}).waitFor();
      const content = page.frame({name: 'document-content'});
      await noOverflow(content, `${label} package page`);
      assert.equal(await content.evaluate(() => getComputedStyle(document.documentElement)
        .backgroundColor), background[colorScheme]);
      assert.ok(await content.locator('.ada-keyword').count() > 800);

      // Every Core link is a verified package-level bookmark opening at top level.
      const external = await content.locator('a.type-reference[target="_top"]')
        .evaluateAll(links => links.map(a => a.getAttribute('href')));
      assert.ok(external.length >= 500);
      for (const href of external) {
        assert.ok(href === core + 'OpenCV' || href === core + 'OpenCV.Core', href);
      }
      // Internal type links land on the native declaration anchor.
      const phase = content.locator('h4', {hasText: /^Phase_Correlate$/}).first();
      await phase.scrollIntoViewIfNeeded();
      const snippet = content.locator('h4:has-text("Phase_Correlate") + pre').first();
      const local = snippet.locator('a.type-reference[href^="#"]').first();
      const anchor = (await local.getAttribute('href')).slice(1);
      await local.click();
      await content.waitForFunction(id => location.hash === '#' + id, anchor);
      assert.equal(await content.evaluate(() => document.querySelector(':target').textContent),
                   'Phase_Correlation_Result');
      await page.screenshot({path: `${evidence}/api-${label}.png`});

      // Keyboard focus is visible on links inside the documentation frame.
      await content.locator('a.type-reference').first().focus();
      await page.keyboard.press('Tab');
      await page.keyboard.press('Shift+Tab');
      assert.equal(await content.evaluate(() => document.activeElement.className),
                   'type-reference');
      const outline = await content.evaluate(() =>
        getComputedStyle(document.activeElement).outlineStyle);
      assert.notEqual(outline, 'none');

      // A Core link replaces the whole window rather than nesting frames.
      const coreLink = snippet.locator('a.type-reference[target="_top"]').first();
      await Promise.all([page.waitForURL(/opencv_core_ada/), coreLink.click()]);
      assert.equal(new URL(page.url()).searchParams.get('package'), 'OpenCV.Core');
      assert.deepEqual(errors, []);
      await context.close();
    }
    // Native navigation does not need JavaScript.
    const disabled = await browser.newContext({javaScriptEnabled: false});
    const page = await disabled.newPage();
    await page.goto(root + 'api/index.html');
    await page.getByRole('link', {name: 'OpenCV.Image_Processing', exact: true}).click();
    await page.frameLocator('iframe').locator('h1', {hasText: 'OpenCV.Image_Processing'}).waitFor();
    await disabled.close();
    console.log(`Presentation browser qualification passed; screenshots in ${evidence}`);
  } finally {
    await browser.close();
  }
})().catch(error => { console.error(error); process.exit(1); });
