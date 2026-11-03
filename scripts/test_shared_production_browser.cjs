/* Complete R2 API browser campaign; live Core HTTPS is never intercepted. */
const {chromium} = require(process.env.PLAYWRIGHT_MODULE);
const assert = require('node:assert/strict');
const fs = require('node:fs');
const crypto = require('node:crypto');
const base = process.env.DOC_URL;
const reportPath = process.env.DOC_BROWSER_REPORT;
const qualification = JSON.parse(fs.readFileSync(process.env.DOC_QUALIFICATION));
const core = JSON.parse(fs.readFileSync(process.env.CORE_TYPES));
const expected = JSON.parse(fs.readFileSync(process.env.DOC_OPERATIONS));
const hash = bytes => crypto.createHash('sha256').update(bytes).digest('hex');
const report = {passed: false, requestInterception: false, campaigns: [], failures: []};

(async () => {
  const browser = await chromium.launch({executablePath: process.env.CHROME, headless: true});
  try {
    for (const width of [1280, 390]) for (const colorScheme of ['light', 'dark'])
      for (const javaScriptEnabled of [true, false]) {
        const context = await browser.newContext({viewport: {width, height: 900}, colorScheme, javaScriptEnabled});
        const page = await context.newPage();
        const errors = [];
        page.on('pageerror', error => errors.push(error.message));
        page.on('console', message => {
          if (message.type() === 'error' && !message.location().url.endsWith('/favicon.ico')) errors.push(message.text());
        });
        page.on('response', response => {
          if (response.status() >= 400 && !response.url().endsWith('/favicon.ico')) errors.push(response.url());
        });
        await page.goto(base + 'api/index.html');
        const links = page.locator('.operation-group a');
        const actual = await links.evaluateAll(elements => elements.map(e => ({
          category: e.closest('section').dataset.category,
          href: e.getAttribute('href'), label: e.textContent
        })));
        assert.deepEqual(actual, expected);
        for (let i = 0; i < expected.length; i++) {
          const item = expected[i];
          await links.nth(i).click();
          const frame = page.frameLocator('iframe[name="document-content"]');
          const anchor = item.href.split('#')[1];
          await frame.locator(`h4[id="${anchor}"]:target`).waitFor();
          assert.equal(await frame.locator('h4:target').textContent(), item.label.replace(/ \([0-9]+\)$/, ''));
          if (javaScriptEnabled) assert.equal(new URL(page.url()).searchParams.get('declaration'), anchor);
        }
        const nativePage = expected[0].href.split('#')[0];
        await page.goto(base + 'api/' + nativePage);
        const occurrences = await page.locator('pre a.type-reference').evaluateAll(elements => elements.map(e => ({
          href: e.getAttribute('href'), identity: e.dataset.type, target: e.getAttribute('target'), label: e.textContent
        })));
        const external = occurrences.filter(x => x.href.startsWith('https:'));
        const local = occurrences.filter(x => !x.href.startsWith('https:'));
        assert.equal(external.length, 586);
        assert.equal(local.length, 350);
        assert.equal(new Set(external.map(x => x.identity)).size, 14);
        for (const item of external) {
          assert.equal(item.href, core[item.identity].url);
          assert.equal(item.target, '_top');
        }
        for (const item of local) {
          assert.equal(item.target, null);
          assert.equal(item.href.split('#')[0], nativePage);
          assert.equal(await page.locator(`h4[id="${item.href.split('#')[1]}"]`).count(), 1);
        }
        // Every local occurrence is activated, not just checked for an anchor.
        for (let i = 0; i < local.length; i++) {
          const item = local[i];
          const link = page.locator('pre a.type-reference:not([href^="https:"])').nth(i);
          assert.equal(await link.getAttribute('href'), item.href);
          assert.equal(await link.textContent(), item.label);
          await link.click();
          await page.locator(`h4[id="${item.href.split('#')[1]}"]:target`).waitFor();
        }
        for (const [identity, type] of Object.entries(core)) {
          await page.goto(base + 'api/index.html');
          await page.locator('#compilation-units + ul a').click();
          const frame = page.frameLocator('iframe[name="document-content"]');
          const link = frame.locator(`pre a[data-type="${identity}"]`).first();
          assert.equal(await link.getAttribute('target'), '_top');
          await link.focus();
          await link.press('Enter');
          await page.waitForURL(type.url);
          assert.equal(page.url(), type.url);
          assert.equal(await page.locator('iframe').count(), 0);
          await page.locator('h4:target').waitFor();
          assert.equal(await page.locator('h4:target').textContent(), type.identity.split('.').pop());
          assert.equal(await page.locator('h4:target + pre').textContent(), type.native_snippet);
          const response = await page.reload();
          assert.equal(response.status(), 200);
          assert.equal(response.request().redirectedFrom(), null);
          assert.equal(hash(await response.body()), type.hosted_page_sha256);
          await page.goBack();
          await page.waitForURL(url => url.href.startsWith(base));
          await page.goForward();
          await page.waitForURL(type.url);
          await page.locator('h4:target').waitFor();
          // Mouse activation independently proves the same top-level behavior.
          await page.goto(base + 'api/' + nativePage);
          await page.locator(`pre a[data-type="${identity}"]`).first().click();
          await page.waitForURL(type.url);
        }
        for (const item of expected) {
          await page.goto(base + 'api/' + item.href);
          await page.locator('h4:target').waitFor();
          await page.reload();
          assert.equal(await page.locator('h4:target').textContent(), item.label.replace(/ \([0-9]+\)$/, ''));
        }
        if (javaScriptEnabled) {
          await page.goto(base + 'api/index.html');
          const input = page.locator('#package-search');
          await input.fill('Match_Template');
          assert.equal(await page.locator('.operation-group li:visible').count(), 2);
          await input.fill('not_a_real_declaration');
          assert.equal(await page.locator('.operation-group li:visible').count(), 0);
          await page.locator('#package-clear').click();
          assert.equal(await links.count(), 329);
          await links.nth(0).click();
          await page.reload();
          await page.frameLocator('iframe[name="document-content"]').locator('h4:target').waitFor();
        }
        assert.deepEqual(errors, []);
        report.campaigns.push({width, colorScheme, javaScriptEnabled, operations: 329,
          externalOccurrences: 586, localOccurrences: 350, topLevelCoreDestinations: 14,
          directReloads: 329, keyboardAndMouse: true, coreBackForward: true,
          sourceOccurrenceReconciliation: qualification.exact_identity_offset_label_url_parity});
        console.log(`PASS API ${width}px ${colorScheme} JS=${javaScriptEnabled}`);
        await context.close();
      }
    report.passed = true;
  } catch (error) {
    report.failures.push(error.stack);
    process.exitCode = 1;
  } finally {
    await browser.close();
    fs.writeFileSync(reportPath, JSON.stringify(report, null, 2) + '\n');
  }
})();