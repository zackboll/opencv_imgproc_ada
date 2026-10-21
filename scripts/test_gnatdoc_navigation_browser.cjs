/* Optional real-browser qualification of the operation-level API browser.
 * Set PLAYWRIGHT_MODULE to a separately installed Playwright module and
 * serve _site over HTTP; this is not a documentation runtime dependency.
 *
 *   python3 -m http.server 8073 --bind 127.0.0.1 --directory _site
 *   PLAYWRIGHT_MODULE=/path/to/node_modules/playwright DOC_URL=http://127.0.0.1:8073/ \
 *     node scripts/test_gnatdoc_navigation_browser.cjs
 */
const {chromium} = require(process.env.PLAYWRIGHT_MODULE);
const assert = require('node:assert/strict');
const fs = require('node:fs');
const root = process.env.DOC_URL || 'http://127.0.0.1:8073/';
const base = root + 'api/index.html';
const evidence = process.env.DOC_EVIDENCE || '/tmp/imgproc-doc-004-screenshots';
const chrome = process.env.CHROME || '/usr/bin/google-chrome';
fs.mkdirSync(evidence, {recursive: true});

const visible = page => page.locator('#api-browser li[data-op]:not([hidden]) > a');
const names = async page => (await visible(page).evaluateAll(
  links => links.map(a => a.parentElement.dataset.op)));

async function expectDeclaration(page, name, frameName = name) {
  await page.frameLocator('iframe[name="document-content"]').locator('h1').waitFor();
  const content = page.frame({name: 'document-content'});
  await content.waitForFunction(() => location.hash.length > 1);
  await content.waitForFunction(
    expected => document.querySelector(':target')?.textContent === expected, frameName);
  const current = page.locator('#api-browser a[aria-current="page"]');
  assert.equal(await current.count(), 1);
  assert.equal(await current.evaluate(a => a.parentElement.dataset.op), name);
}

(async () => {
  const browser = await chromium.launch({executablePath: chrome, headless: true});
  try {
    for (const width of [1280, 390]) for (const colorScheme of ['light', 'dark']) {
      const label = `${width}-${colorScheme}`;
      const context = await browser.newContext({viewport: {width, height: 900}, colorScheme});
      await context.route('**/favicon.ico', route => route.fulfill({status: 204}));
      const page = await context.newPage();
      const errors = [];
      page.on('pageerror', e => errors.push(e.message));
      page.on('console', m => { if (m.type() === 'error') errors.push(m.text()); });

      // Default: the package page loads; every declaration is listed once.
      await page.goto(base);
      await page.frameLocator('iframe').locator('h1', {hasText: 'OpenCV.Image_Processing'}).waitFor();
      assert.equal(await page.locator('#api-browser li[data-op]').count(), 329);
      assert.equal(await page.locator('#api-browser details').count(), 8);
      assert.notEqual(await page.evaluate(() => document.activeElement.id), 'api-search');
      const search = page.getByLabel('Search operations and types');

      // Case-insensitive identifier, word and category searches.
      for (const [query, expected] of [
        ['gAuSsIaN', 'Gaussian_Blur'], ['warp', 'Warp_Affine'], ['contours', 'Find_Contours'],
        ['hough', 'Find_Hough_Lines'], ['match_template', 'Match_Template'],
        ['phase_correlate', 'Phase_Correlate'], ['match template', 'Match_Template'],
        ['color conversion', 'Convert_Color']]) {
        await search.fill(query);
        const found = await names(page);
        assert.ok(found.includes(expected), `${query}: ${expected} missing`);
        for (const name of found) {
          const text = await page.locator(`#api-browser li[data-op="${name}"]`).first()
            .getAttribute('data-search');
          for (const word of query.toLowerCase().split(/\s+/)) assert.ok(text.includes(word));
        }
        assert.match(await page.locator('#api-results').textContent(), /matching declaration/);
      }
      // Overloads are distinguished.
      await search.fill('match_template');
      const overloads = await page.locator('#api-browser li[data-op="Match_Template"] .entry-detail')
        .allTextContents();
      assert.deepEqual(overloads.map(s => s.trim()),
                       ['procedure, overload 1 of 2', 'procedure, overload 2 of 2']);
      await search.fill('NOT_AN_IMGPROC_NAME');
      assert.equal(await page.locator('#api-results').textContent(), 'No matching declarations.');
      assert.equal(await visible(page).count(), 0);
      await page.getByRole('button', {name: 'Clear', exact: true}).click();
      assert.equal(await visible(page).count(), 329);
      assert.equal(await page.evaluate(() => document.activeElement.id), 'api-search');

      // Selection navigates the frame to the native anchor and is bookmarkable.
      await search.fill('match_template');
      await page.locator('#api-browser li[data-op="Match_Template"][data-overload="2"] > a').click();
      await expectDeclaration(page, 'Match_Template');
      const url = new URL(page.url());
      assert.equal(url.searchParams.get('op'), 'Match_Template');
      assert.equal(url.searchParams.get('overload'), '2');
      const bookmark = page.url();
      await search.fill('warp_affine');
      await page.locator('#api-browser li[data-op="Warp_Affine"] > a').click();
      await expectDeclaration(page, 'Warp_Affine');
      await page.goBack();
      await expectDeclaration(page, 'Match_Template');
      assert.equal(page.url(), bookmark);
      await page.goForward();
      await expectDeclaration(page, 'Warp_Affine');
      await page.reload();
      await expectDeclaration(page, 'Warp_Affine');
      // Fresh context from a copied bookmark, with case-insensitive lookup.
      const fresh = await browser.newContext({viewport: {width, height: 900}, colorScheme});
      const copy = await fresh.newPage();
      await copy.goto(base + '?op=match_TEMPLATE&overload=2');
      await expectDeclaration(copy, 'Match_Template');
      assert.equal(new URL(copy.url()).searchParams.get('op'), 'Match_Template');
      // Unknown requests select nothing and are removed from the URL.
      await copy.goto(base + '?op=../../etc/passwd');
      await copy.frameLocator('iframe').locator('h1', {hasText: 'OpenCV.Image_Processing'}).waitFor();
      assert.equal(new URL(copy.url()).search, '');
      assert.equal(await copy.locator('#api-browser a[aria-current="page"]').count(), 0);
      await fresh.close();

      // Keyboard: search, Tab to the first result, Enter.
      await page.goto(base);
      await search.focus();
      await page.keyboard.type('Phase_Correlate');
      // Clear, then the opened category's summary, then its first entry.
      for (const expected of ['api-clear', 'SUMMARY']) {
        await page.keyboard.press('Tab');
        assert.equal(await page.evaluate(() => document.activeElement.id ||
                                         document.activeElement.tagName), expected);
      }
      await page.keyboard.press('Tab');
      assert.equal(await page.evaluate(() => document.activeElement.closest('li')?.dataset.op),
                   'Phase_Correlate');
      const outline = await page.evaluate(() => getComputedStyle(document.activeElement).outlineStyle);
      assert.notEqual(outline, 'none');
      await page.keyboard.press('Enter');
      await expectDeclaration(page, 'Phase_Correlate');

      const overflow = await page.evaluate(() =>
        document.documentElement.scrollWidth > document.documentElement.clientWidth + 1);
      assert.equal(overflow, false);
      await search.fill('hough');
      await page.screenshot({path: `${evidence}/browser-${label}.png`});
      assert.deepEqual(errors, []);
      await context.close();
    }

    // Without JavaScript the categorized links still navigate the frame.
    const disabled = await browser.newContext({javaScriptEnabled: false});
    const page = await disabled.newPage();
    await page.goto(base);
    assert.equal(await page.locator('#api-search-controls').isHidden(), true);
    await page.locator('#api-browser details[data-category="matching"] > summary').click();
    await page.locator('#api-browser li[data-op="Match_Template"] > a').first().click();
    await page.frameLocator('iframe').locator('h4:target', {hasText: 'Match_Template'}).waitFor();
    await page.screenshot({path: `${evidence}/browser-no-javascript.png`});
    await disabled.close();
    console.log(`Navigation browser qualification passed; screenshots in ${evidence}`);
  } finally {
    await browser.close();
  }
})().catch(error => { console.error(error); process.exit(1); });
