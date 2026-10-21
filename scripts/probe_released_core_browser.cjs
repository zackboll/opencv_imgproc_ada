/* Read-only live HTTPS observation. Not an external-link approval manifest.
 * Usage: PLAYWRIGHT_MODULE=/absolute/playwright CORE_PROBE_OUTPUT=/absolute/report.json
 *        node /absolute/scripts/probe_released_core_browser.cjs
 * No request interception or HTTP-success-only navigation assertions.
 */
const {chromium} = require(process.env.PLAYWRIGHT_MODULE);
const assert = require('node:assert/strict');
const fs = require('node:fs');

(async () => {
  const report = {scope: 'Live hosting capability observation, not version-compatible Core approval',
    requestInterception: false, observations: [], errors: []};
  const browser = await chromium.launch({executablePath: process.env.CHROME || '/usr/bin/google-chrome', headless: true});
  try {
    const context = await browser.newContext();
    const page = await context.newPage();
    page.on('pageerror', e => report.errors.push(e.message));
    const base = 'https://zackboll.github.io/opencv_core_ada/api/index.html';
    for (const owner of ['OpenCV', 'OpenCV.Core']) {
      await page.goto(base + '?package=' + owner);
      const frame = page.frameLocator('iframe[name="document-content"]');
      await frame.locator('h1').waitFor();
      assert.equal(await frame.locator('h1').textContent(), owner);
      report.observations.push({kind: 'package-query', owner, url: page.url(),
        heading: await frame.locator('h1').textContent()});
    }
    for (const identity of ['OpenCV.Core.Mat', 'OpenCV.Core.Mat_Array',
      'OpenCV.Angle_Unit', 'OpenCV.Border_Kind', 'OpenCV.Float32_Point',
      'OpenCV.Float32_Value', 'OpenCV.Float64_Value', 'OpenCV.Point',
      'OpenCV.Point_Array', 'OpenCV.Rect', 'OpenCV.Scalar', 'OpenCV.Size',
      'OpenCV.Size_Coordinate', 'OpenCV.UInt8_Value']) {
      await page.goto(base + '?symbol=' + identity);
      // Read source-owned bookmark metadata, then verify loaded declaration text.
      const href = await page.locator('#type-navigation a').evaluateAll((es, name) =>
        es.filter(e => e.dataset.symbol === name).map(e => e.getAttribute('href')), identity);
      assert.equal(href.length, 1, 'missing or duplicate hosted symbol identity');
      const frame = page.frameLocator('iframe[name="document-content"]');
      await frame.locator('h4:target').waitFor();
      const heading = await frame.locator('h4:target').textContent();
      assert.equal(heading, identity.split('.').pop());
      const direct = new URL(href[0], base).href;
      await page.goto(direct);
      await page.locator('h4:target').waitFor();
      assert.equal(await page.locator('h4:target').textContent(), heading);
      const snippet = await page.locator('h4:target + pre').textContent();
      assert.ok(snippet.includes(heading));
      report.observations.push({kind: 'symbol-query-and-genuine-direct-fragment', identity,
        bookmark: base + '?symbol=' + identity, direct, heading, snippet});
    }
    assert.deepEqual(report.errors, []);
    report.status = 'pass';
  } catch (error) {
    report.status = 'fail';
    report.failure = error.stack;
    process.exitCode = 1;
  } finally {
    await browser.close();
    fs.writeFileSync(process.env.CORE_PROBE_OUTPUT, JSON.stringify(report, null, 2) + '\n');
  }
})();