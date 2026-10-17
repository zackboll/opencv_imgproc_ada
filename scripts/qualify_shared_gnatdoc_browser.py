#!/usr/bin/env python3
"""Executed Chromium assertions against real shadow output, never production.

Reserved Core URLs are intercepted with hash-verified Core 0.4.1 native bytes.
This is explicitly not a production HTTPS hosting check.
"""
from __future__ import annotations

import argparse
import functools
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
import threading
from urllib.parse import urljoin, urlsplit

from qualify_shared_gnatdoc_shadow import CORE, EVIDENCE, digest, read_json, require, write_json


class Quiet(SimpleHTTPRequestHandler):
    def log_message(self, *args):
        pass


def run(workspace):
    from playwright.sync_api import sync_playwright
    from ada_gnatdoc_enhancer.config import load
    from ada_gnatdoc_enhancer.external_types import destinations
    from ada_gnatdoc_enhancer.pipeline import verify
    from ada_gnatdoc_enhancer.validation import Page
    root = workspace / "first"
    site = root / "_site"
    config = load(root, "qualification.toml")
    verify(config, site)
    destinations(config)
    contract = read_json(root / EVIDENCE / "authored.json")
    core = read_json(root / EVIDENCE / "core-types.json")
    server = ThreadingHTTPServer(("127.0.0.1", 0), functools.partial(Quiet, directory=str(site)))
    thread = threading.Thread(target=server.serve_forever, daemon=True)
    thread.start()
    base = f"http://127.0.0.1:{server.server_port}/"
    report = {"checks": [], "production_https_verified": False,
              "external_transport": "explicit local interception of pinned Core 0.4.1; offline-test"}

    def check(name, action, **dimensions):
        try:
            action()
            record = {"name": name, "status": "pass", **dimensions}
        except Exception as exc:
            record = {"name": name, "status": "fail", "reason": str(exc), **dimensions}
        report["checks"].append(record)
        write_json(workspace / "browser-progress.json", report)

    def intercept(route):
        url = urlsplit(route.request.url)
        prefix = f"/{CORE}/api/"
        require(url.hostname == "core.invalid" and url.path.startswith(prefix), "unqualified intercepted URL")
        name = url.path.removeprefix(prefix)
        require("api/" + name in core["native_sha256"], "unapproved intercepted artifact")
        content = (root / "qualification-dependencies/core-0.4.1/native/api" / name).read_bytes()
        require(digest(content) == core["native_sha256"]["api/" + name], "intercepted bytes changed")
        route.fulfill(status=200, body=content,
                      content_type="text/css" if name.endswith(".css") else "text/html")

    try:
        with sync_playwright() as p:
            browser = p.chromium.launch()
            report["chromium"] = browser.version
            for width in (1280, 390):
                for theme in ("light", "dark"):
                    for javascript in (True, False):
                        context = browser.new_context(viewport={"width": width, "height": 760},
                                                      color_scheme=theme, java_script_enabled=javascript)
                        context.route("https://core.invalid/**", intercept)
                        page = context.new_page()
                        page.set_default_timeout(5000)
                        errors = []
                        page.on("pageerror", lambda error: errors.append(str(error)))
                        dimensions = {"width": width, "theme": theme, "javascript": javascript}
                        try:
                            pages = ["index.html", *(g["path"] for g in contract["guides"])]
                            for name in pages:
                                parsed = Page((site / name).read_text())
                                url = urljoin(base, name)

                                def authored():
                                    response = page.goto(url)
                                    require(response.status == 200 and page.locator("h1").count() == 1,
                                            "authored page unavailable")
                                    require(page.locator("body").evaluate("e => e.scrollWidth <= innerWidth + 2"),
                                            "unexpected page overflow")
                                    for table in page.locator(".table-scroll").all():
                                        require(table.evaluate("e => e.clientWidth <= innerWidth + 2"),
                                                "table exceeds viewport")
                                check("authored page and responsive tables", authored, page=name, **dimensions)
                                # Direct native guide heading fragments: exercise every actual heading.
                                for identity in parsed.ids:
                                    if identity in ("main-content",):
                                        continue

                                    def fragment():
                                        page.goto(url + "#" + identity)
                                        require(page.locator('[id="' + identity + '"]').count() == 1,
                                                "direct heading fragment missing")
                                    check("direct authored heading fragment", fragment,
                                          page=name, fragment=identity, **dimensions)
                                for guide in contract["guides"]:
                                    target = ("guides/" if name == "index.html" else "") + guide["id"] + ".html"

                                    def guide_navigation():
                                        page.goto(url)
                                        link = page.locator('a[href="' + target + '"]').first
                                        require(link.count() == 1, "guide navigation missing")
                                        link.click()
                                        page.wait_for_url(urljoin(url, target))
                                    check("guide-to-guide navigation", guide_navigation, page=name,
                                          destination=target, **dimensions)
                                # Verify all source-owned overload entry links in the browser.
                                for href in sorted(set(link for link in parsed.links
                                                       if "api/" in link and "#" in link and not urlsplit(link).scheme)):
                                    def api_destination():
                                        page.goto(url)
                                        page.locator('a[href="' + href + '"]').first.click()
                                        page.wait_for_url(urljoin(url, href))
                                        require(page.locator('h4[id="' + urlsplit(href).fragment + '"]').count() == 1,
                                                "source-backed declaration destination missing")
                                        page.go_back()
                                        page.wait_for_url(url)
                                        page.go_forward()
                                        page.wait_for_url(urljoin(url, href))
                                    check("source-backed API overload and Back Forward", api_destination,
                                          page=name, destination=href, **dimensions)

                                def keyboard():
                                    page.goto(url)
                                    link = page.locator('a:not([href^="https:"])').first
                                    link.focus()
                                    require(link.evaluate("e => e === document.activeElement"), "focus missing")
                                    require(link.evaluate("e => getComputedStyle(e).outlineStyle !== 'none'"),
                                            "focus outline missing")
                                    target = link.get_attribute("href")
                                    page.keyboard.press("Enter")
                                    page.wait_for_url(urljoin(url, target))
                                check("keyboard focus and activation", keyboard, page=name, **dimensions)

                            def api_browser():
                                page.goto(base + "api/index.html")
                                require(page.locator("#operation-navigation").count() == 1, "operation browser missing")
                                require(page.locator(".operation-group a").count() == 314, "operation inventory changed")
                                categories = read_json(root / "docs/api-categories.json")["categories"]
                                require(page.locator(".operation-group h3").all_text_contents()
                                        == [c["title"] for c in categories], "category order/identity mismatch")
                                if javascript:
                                    page.locator("#package-search").fill("Gaussian_Blur")
                                    require(page.locator('.operation-group a').filter(has_text="Gaussian_Blur").first.is_visible(),
                                            "search lost expected operation")
                                    require(page.locator('.operation-group a').filter(has_text="Convert_Color").first.is_hidden(),
                                            "search did not filter unrelated operation")
                                    page.locator("#package-clear").click()
                            check("operation browser search and categories", api_browser, **dimensions)

                            def local_anchor():
                                page.goto(base + "api/index.html")
                                entry = page.locator('.operation-group a').filter(has_text="Gaussian_Blur").first
                                href = entry.get_attribute("href")
                                entry.click()
                                frame = page.frame(name="document-content")
                                frame.wait_for_url(urljoin(base + "api/index.html", href))
                                require(frame.locator('h4[id="' + urlsplit(href).fragment + '"]').count() == 1,
                                        "native declaration anchor missing")
                                link = frame.locator('a.type-reference:not([href^="https:"])').first
                                require(link.count() == 1, "local type link missing")
                                target = urljoin(frame.url, link.get_attribute("href"))
                                link.click()
                                frame.wait_for_url(target)
                                require(frame.locator('[id="' + urlsplit(target).fragment + '"]').count() == 1,
                                        "local type destination missing")
                            check("native declaration and local type anchors", local_anchor, **dimensions)

                            def external_click():
                                page.goto(base + "api/index.html")
                                entry = page.locator('.operation-group a').filter(has_text="Gaussian_Blur").first
                                href = entry.get_attribute("href")
                                entry.click()
                                frame = page.frame(name="document-content")
                                frame.wait_for_url(urljoin(base + "api/index.html", href))
                                link = frame.locator('a.type-reference[href^="https://core.invalid/"]').first
                                require(link.count() == 1, "external type hyperlink missing")
                                destination = link.get_attribute("href")
                                before = frame.url
                                link.click()
                                frame.wait_for_url(destination)
                                require(frame.locator('h4[id="' + urlsplit(destination).fragment + '"]').count() == 1,
                                        "clicked Core declaration missing")
                                page.evaluate("history.back()")
                                frame.wait_for_url(before)
                                page.evaluate("history.forward()")
                                frame.wait_for_url(destination)
                            check("offline Core type click and frame Back Forward", external_click, **dimensions)

                            # Every selected external type is exercised directly, with real bytes and signature proof.
                            for identity in config.dependencies[0]["types"]:
                                proof = core["types"][identity.lower()]
                                destination = f"https://core.invalid/{CORE}/api/{proof['page']}#{proof['anchor']}"

                                def external():
                                    page.goto(destination)
                                    heading = page.locator('h4[id="' + proof["anchor"] + '"]')
                                    require(heading.count() == 1 and heading.inner_text() == identity.rsplit(".", 1)[1],
                                            "external declaration identity mismatch")
                                    code = heading.locator("xpath=following-sibling::pre[1]/code").inner_text()
                                    require(digest(code.encode()) == proof["native_declaration_sha256"],
                                            "external declaration text mismatch")
                                check("offline pinned Core destination", external, destination=destination, **dimensions)
                            check("no JavaScript errors", lambda: require(not errors, str(errors)), **dimensions)
                        finally:
                            context.close()
            browser.close()
    finally:
        server.shutdown()
        report["status"] = "pass" if report["checks"] and all(
            c["status"] == "pass" for c in report["checks"]) else "fail"
        report["executed"] = len(report["checks"])
        report["failures"] = sum(c["status"] != "pass" for c in report["checks"])
        write_json(workspace / "browser.json", report)
    require(report["status"] == "pass", f"browser qualification: {report['failures']} failures")
    return report


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--workspace", required=True, type=Path)
    args = parser.parse_args()
    run(args.workspace)