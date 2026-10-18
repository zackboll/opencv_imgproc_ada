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
from urllib.parse import urlencode, urljoin, urlsplit

from qualify_shared_gnatdoc_shadow import CORE, EVIDENCE, digest, hashes, read_json, require, write_json


def history_checks(page, base, workspace, check, report, dimensions):
    """Independent consumer source oracle, genuine native bytes, real shared UI."""
    from enhance_gnatdoc_navigation import entries
    from link_gnatdoc_types import SECTION, plain
    legacy = workspace / "legacy"
    _, groups = entries(legacy / "_site/api", legacy / "src", legacy / "docs/api-categories.json")
    selected = [e for _, _, group in groups for e in group
                if e["name"] in ("Filter_2D", "Get_Gaussian_Kernel", "Bilateral_Filter", "Pyramid_Up")]
    native = {}
    for path in (workspace / "pristine-first/api").glob("*.html"):
        for section in SECTION.finditer(path.read_text()):
            native[path.name + "#" + section[1]] = plain(section[3])
    package = "OpenCV.Image_Processing"
    shell = base + "api/index.html"

    def outer(entry=None):
        query = {"package": package}
        if entry:
            query["declaration"] = urlsplit(entry["href"]).fragment
        return shell + "?" + urlencode(query)

    def declaration(frame, entry):
        heading = frame.locator('h4[id="' + urlsplit(entry["href"]).fragment + '"]')
        heading.wait_for(state="attached")
        require(heading.count() == 1 and heading.inner_text() == entry["name"],
                "wrong native declaration identity")
        code = heading.locator("xpath=following-sibling::pre[1]").inner_text()
        require(" ".join(code.split()) == " ".join(native[entry["href"]].split()),
                "restored content differs from complete genuine native declaration")
        # entries() independently source-matches that exact native profile.
        require(entry["profile"].split()[0] in code, "source declaration kind missing")

    def restored(entry):
        page.wait_for_url(outer(entry))
        require(page.evaluate("window.__consumerHistoryDocument") == "same-shell",
                "top-level API document reloaded during declaration history")
        frame = page.frame(name="document-content")
        frame.wait_for_url(urljoin(shell, entry["href"]))
        declaration(frame, entry)
        label = entry["name"] + f" ({entry['overload']})"
        active = page.locator('a[aria-current="location"]')
        require(active.inner_text() == label and active.get_attribute("href") == entry["href"],
                "wrong source-order active overload label")
        report.setdefault("history_traces", []).append({"outer": page.url.replace(base, "http://local/"),
            "native": frame.url.replace(base, "http://local/"), "label": label,
            "source_profile": entry["profile"], "native_profile": native[entry["href"]], **dimensions})

    def initialize(url):
        page.goto(url)
        page.locator('#package-navigation[data-ready="true"]').wait_for(state="visible")
        page.evaluate('window.__consumerHistoryDocument = "same-shell"')

    for entry in selected:
        label = entry["name"] + f" ({entry['overload']})"

        def native_selection(entry=entry, label=label):
            if dimensions["javascript"]:
                initialize(shell)
            else:
                page.goto(shell)
            link = page.get_by_role("link", name=label, exact=True)
            require(link.get_attribute("href") == entry["href"], "source-order destination differs")
            link.focus()
            page.keyboard.press("Enter")
            frame = page.frame(name="document-content")
            frame.wait_for_url(urljoin(shell, entry["href"]))
            declaration(frame, entry)
            if dimensions["javascript"]:
                restored(entry)
        check("additional source-order keyboard selection full native profile", native_selection,
              label=label, **dimensions)

        def direct(entry=entry):
            page.goto(urljoin(shell, entry["href"]))
            declaration(page, entry)
        check("additional direct native declaration bookmark full profile", direct, label=label, **dimensions)

    if not dimensions["javascript"]:
        return

    def sequence(name, filtered=False):
        first, second = [e for e in selected if e["name"] == name]
        if name == "Get_Gaussian_Kernel":
            native_text = (workspace / "pristine-first/api" / urlsplit(first["href"]).path).read_text()
            require(native_text.index('id=' + urlsplit(first["href"]).fragment)
                    > native_text.index('id=' + urlsplit(second["href"]).fragment),
                    "Gaussian reversal regression precondition no longer holds")
        initialize(outer())
        page.frame(name="document-content").wait_for_url(urljoin(shell, urlsplit(first["href"]).path))
        if filtered:
            page.locator("#package-search").fill(name)
        for entry in (first, second):
            page.get_by_role("link", name=entry["name"] + f" ({entry['overload']})", exact=True).click()
            restored(entry)
        length = page.evaluate("history.length")
        page.get_by_role("link", name=name + " (2)", exact=True).click()
        require(page.evaluate("history.length") == length, "active overload duplicated history")
        for _ in range(3):
            page.evaluate("history.back()")
            restored(first)
            page.evaluate("history.forward()")
            restored(second)
            require(page.evaluate("history.length") == length, "traversal added history")
        if filtered:
            page.locator("#package-clear").click()
            require(page.locator("#package-search").input_value() == "", "search reset failed")

    check("declaration history Filter_2D repeated Back Forward and active selection",
          lambda: sequence("Filter_2D"), **dimensions)
    check("declaration history Get_Gaussian_Kernel source order differs from native order",
          lambda: sequence("Get_Gaussian_Kernel"), **dimensions)
    check("declaration history after operation search", lambda: sequence("Filter_2D", True), **dimensions)

    def reload():
        entry = selected[0]
        initialize(outer(entry))
        restored(entry)
        length = page.evaluate("history.length")
        page.reload()
        page.locator('#package-navigation[data-ready="true"]').wait_for(state="visible")
        page.evaluate('window.__consumerHistoryDocument = "same-shell"')
        restored(entry)
        require(page.evaluate("history.length") == length, "reload duplicated history")
    check("declaration deep link reload full profile", reload, **dimensions)

    def invalid():
        anchor = urlsplit(selected[0]["href"]).fragment
        core = read_json(workspace / "first" / EVIDENCE / "core-types.json")
        wrong_owner = core["types"]["opencv.core.mat"]["anchor"]
        for query in ("package=Unknown", "package=" + package + "&declaration=" + "f" * 64,
                      "package=" + package + "&declaration=%ZZ",
                      "package=" + package + "&declaration=%23" + anchor,
                      "package=" + package + "&package=" + package,
                      "package=" + package + "&declaration=" + anchor + "&declaration=" + anchor,
                      "package=" + package + "&declaration=" + wrong_owner):
            initialize(shell + "?" + query)
            page.wait_for_url(outer())
            frame = page.frame(name="document-content")
            frame.wait_for_url(urljoin(shell, urlsplit(selected[0]["href"]).path))
            frame.locator("h1").wait_for(state="attached")
            require(frame.locator("h1").inner_text() == package, "invalid query lost genuine package content")
            require(page.locator('a[aria-current="location"]').count() == 0,
                    "invalid query selected a declaration")
    check("invalid duplicate unknown and wrong-owner declaration queries fail closed", invalid, **dimensions)

    def package_bookmark():
        initialize(outer())
        frame = page.frame(name="document-content")
        frame.wait_for_url(urljoin(shell, urlsplit(selected[0]["href"]).path))
        frame.locator("h1").wait_for(state="attached")
        require(frame.locator("h1").inner_text() == package, "package-only bookmark broken")
    check("package-only bookmark compatibility", package_bookmark, **dimensions)


class Quiet(SimpleHTTPRequestHandler):
    def log_message(self, *args):
        pass


def run(workspace):
    from playwright.sync_api import sync_playwright
    from ada_gnatdoc_enhancer.config import load
    from ada_gnatdoc_enhancer.external_types import destinations
    from ada_gnatdoc_enhancer.pipeline import verify
    from ada_gnatdoc_enhancer.validation import Page
    from ada_gnatdoc_enhancer.qualification import identities
    root = workspace / "first"
    site = root / "_site"
    qualification = read_json(workspace / "qualification.json")
    require(hashes(site) == qualification["shadow_sha256"],
            "browser input differs from independently qualified output (tamper restoration required)")
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
              "qualification_sha256": digest((workspace / "qualification.json").read_bytes()),
              "external_transport": "explicit local interception of pinned Core 0.4.1; offline-test",
              "tested_shadow_sha256": hashes(site)}

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
                            native_pages = identities(workspace / "pristine-first")
                            for native_name, native_page in native_pages.items():
                                if not native_page["package"]:
                                    continue

                                def all_native_anchors():
                                    page.goto(urljoin(base, native_name))
                                    observed = page.locator("h4[id]").evaluate_all("es => es.map(e => e.id)")
                                    expected = [anchor for anchor, _ in native_page["declarations"]]
                                    require(observed == expected, "native browser declaration anchors differ")
                                check("all 314 genuine native declaration anchors", all_native_anchors, **dimensions)

                            def responsive_api():
                                page.goto(base + "api/index.html")
                                require(page.locator("body").evaluate("e => e.scrollWidth <= innerWidth + 2"),
                                        "API shell unexpectedly overflows viewport")
                            check("responsive API browser viewport", responsive_api, **dimensions)

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
                            history_checks(page, base, workspace, check, report, dimensions)
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
        historical = read_json(workspace / "legacy" / EVIDENCE / "browser-summary.json")
        original_names = set(historical["assertion_names"])
        report["original_assertions_retained"] = sum(c["name"] in original_names for c in report["checks"])
        report["original_assertion_names_retained"] = original_names <= {c["name"] for c in report["checks"]}
        if report["original_assertions_retained"] < 1840 or not report["original_assertion_names_retained"]:
            report["status"] = "fail"
        write_json(workspace / "browser.json", report)
    require(report["status"] == "pass", f"browser qualification: {report['failures']} failures")
    return report


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--workspace", required=True, type=Path)
    args = parser.parse_args()
    run(args.workspace)