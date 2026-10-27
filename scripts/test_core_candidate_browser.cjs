/* R1 live Core and candidate link qualification. No request interception.
 * CORE_PROPOSAL=/absolute/core-destination-proposal.json
 * CORE_CANDIDATE=/absolute/candidate/first
 * CORE_BROWSER_REPORT=/absolute/new-report.json
 * PLAYWRIGHT_MODULE=/absolute/playwright node /absolute/this-file.cjs
 */
const {chromium} = require(process.env.PLAYWRIGHT_MODULE);
const assert = require('node:assert/strict');
const fs = require('node:fs');
const http = require('node:http');
const path = require('node:path');
const crypto = require('node:crypto');

(async () => {
  const proposal = JSON.parse(fs.readFileSync(process.env.CORE_PROPOSAL));
  const candidate = path.resolve(process.env.CORE_CANDIDATE);
  const report = {requestInterception: false, assertions: [], failures: [],
    navigationDifferences: [], sourcePolicyApproved: false};
  const prefix = '/opencv_imgproc_ada/';
  const server = http.createServer((req, res) => {
    const url = new URL(req.url, 'http://127.0.0.1');
    if (url.pathname === '/favicon.ico') { res.writeHead(204); res.end(); return; }
    if (!url.pathname.startsWith(prefix)) { res.writeHead(404); res.end(); return; }
    const relative = decodeURIComponent(url.pathname.slice(prefix.length));
    const file = path.resolve(candidate, relative || 'index.html');
    if (!file.startsWith(candidate + path.sep) || !fs.existsSync(file) || !fs.statSync(file).isFile()) {
      res.writeHead(404); res.end(); return;
    }
    const types = {'.html': 'text/html; charset=utf-8', '.css': 'text/css', '.js': 'text/javascript', '.json': 'application/json'};
    res.writeHead(200, {'Content-Type': types[path.extname(file)] || 'application/octet-stream'});
    fs.createReadStream(file).pipe(res);
  });
  await new Promise(resolve => server.listen(0, '127.0.0.1', resolve));
  const base = `http://127.0.0.1:${server.address().port}${prefix}`;
  const browser = await chromium.launch({executablePath: process.env.CHROME || '/usr/bin/google-chrome', headless: true});
  const hash = bytes => crypto.createHash('sha256').update(bytes).digest('hex');
  try {
    for (const width of [1280, 390]) for (const colorScheme of ['light', 'dark'])
      for (const javaScriptEnabled of [true, false]) {
        const context = await browser.newContext({viewport: {width, height: 900}, colorScheme, javaScriptEnabled});
        const page = await context.newPage();
        const errors = [];
        const network = [];
        page.on('pageerror', e => errors.push(e.message));
        page.on('console', m => { if (m.type() === 'error') {
          const url = m.location().url;
          if (url === 'https://zackboll.github.io/favicon.ico' && m.text().includes('404')) {
            report.assertions.push({expectedOptionalFavicon404: url});
          } else errors.push({text: m.text(), url});
        }});
        page.on('response', response => {
          if (response.status() >= 400) network.push({url: response.url(), status: response.status()});
        });
        const campaign = `${width}-${colorScheme}-js${javaScriptEnabled}`;
        // Every distinct type: live HTTPS, exact artifact bytes and real visible
        // native target. No HTTP-success-only assertion or synthetic route.
        for (const [identity, type] of Object.entries(proposal.types)) {
          // Two types may share a package page. Force a document load rather
          // than interpreting a hash-only goto (which returns no Response).
          await page.goto('about:blank');
          const response = await page.goto(type.url);
          assert.equal(response.status(), 200);
          assert.equal(response.url(), type.url.split('#')[0]);
          assert.equal(response.request().redirectedFrom(), null);
          assert.equal(page.url(), type.url);
          assert.equal(hash(await response.body()), type.hosted_page_sha256);
          const target = page.locator('h4:target');
          await target.waitFor({state: 'visible'});
          assert.equal(await target.textContent(), type.identity.split('.').pop());
          assert.equal((await page.locator('h1').textContent()).toLowerCase(), type.owner);
          assert.equal(await page.locator('h4:target + pre').textContent(), type.native_snippet);
          assert.equal(await page.locator(`[id="${type.native_anchor}"]`).count(), 1);
          report.assertions.push({campaign, identity, direct: true, artifactBytesEqual: true, declarationVisible: true});
        }
        // Exercise genuine generated links through the API shell with keyboard
        // activation. Observe, do not conceal, any change from target=_top.
        for (const [identity, type] of Object.entries(proposal.types)) {
          const occurrence = proposal.occurrences.find(x => x.core_identity === identity);
          const packageName = 'OpenCV.Image_Processing';
          const outer = base + 'api/index.html';
          await page.goto(outer + (javaScriptEnabled
            ? `?package=${packageName}&declaration=${occurrence.native_anchor}` : ''));
          let frame = page.frameLocator('iframe[name="document-content"]');
          if (!javaScriptEnabled) {
            await page.locator('.content-column a').filter({hasText: /^OpenCV.Image_Processing$/}).click();
          }
          await frame.locator('h1').waitFor();
          const declaration = frame.locator(`h4[id="${occurrence.native_anchor}"] + pre`);
          const link = declaration.locator(`a[data-type="${identity}"]`).first();
          assert.equal(await link.getAttribute('href'), type.url);
          const targetAttribute = await link.getAttribute('target');
          const outerBefore = page.url();
          await link.focus();
          await link.press('Enter');
          const child = page.frame({name: 'document-content'});
          assert.ok(child);
          await child.waitForURL(type.url);
          await child.waitForFunction(name => document.querySelector('h4:target')?.textContent === name,
            type.identity.split('.').pop());
          await frame.locator('h4:target').waitFor({state: 'visible'});
          assert.equal(await frame.locator('h4:target').textContent(), type.identity.split('.').pop());
          assert.equal(page.url(), outerBefore);
          const loaded = page.frames().filter(f => f.url() === type.url);
          assert.equal(loaded.length, 1);
          report.navigationDifferences.push({campaign, identity,
            legacyTarget: '_top', sharedTarget: targetAttribute,
            actualDestination: loaded[0].url(), outerUrlUnchanged: true,
            classification: 'External Core navigation remains inside Imgproc iframe; legacy exited frame. Independent policy review required.'});
          // This is a joint iframe-history entry, not an outer document load.
          // Browser goBack(waitUntil=load) waits for the wrong lifecycle here.
          await page.evaluate(() => history.back());
          await frame.locator('h1').filter({hasText: /^OpenCV.Image_Processing$/}).waitFor();
          await page.evaluate(() => history.forward());
          const forward = page.frame({name: 'document-content'});
          assert.ok(forward);
          await forward.waitForURL(type.url);
          await forward.waitForFunction(name => document.querySelector('h4:target')?.textContent === name,
            type.identity.split('.').pop());
          assert.equal(await frame.locator('h4:target').textContent(), type.identity.split('.').pop());
          report.assertions.push({campaign, identity, generatedKeyboardLink: true, iframeBackForward: true});
        }
        report.assertions.push({campaign, networkErrorsObserved: network});
        assert.deepEqual(network.filter(x => x.url !== 'https://zackboll.github.io/favicon.ico'), []);
        assert.deepEqual(errors, []);
        await context.close();
      }
    report.status = 'observation-pass-policy-not-approved';
  } catch (error) {
    report.status = 'fail';
    report.failures.push(error.stack);
    process.exitCode = 1;
  } finally {
    await browser.close();
    await new Promise(resolve => server.close(resolve));
    fs.writeFileSync(process.env.CORE_BROWSER_REPORT, JSON.stringify(report, null, 2) + '\n');
  }
})();