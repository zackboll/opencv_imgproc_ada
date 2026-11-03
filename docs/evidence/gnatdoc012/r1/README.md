# IMGPROC-GNATDOC-012R1: hosted Chromium reselection-precondition race

Failing head `5d5547dcc2064c49a3b449ea2e8a70838d44439d`, run
[41557578674](https://github.com/zackboll/opencv_imgproc_ada/actions/runs/41557578674),
job `125660102312`. The diagnostics artifact `13196713185` cannot be downloaded
from this sandbox (its blob host is refused by the egress policy). The reported
failure is `frame.waitForFunction: Timeout 30000ms exceeded` at
`scripts/test_shared_production_browser.cjs:146`, in the API 390 px / dark /
JavaScript-on campaign. The guide campaign passed 8/8, and the API campaign
passed its first six configurations, live Core destinations included.

## Measurements (`instrumented-timeline.json`)

These come from a replay of lines 109–147 against the generated v0.1.5 site
(Chromium 1243 / Playwright 1.64.1 runtime). Init-script hooks recorded every
frame's `scrollIntoView`, scroll, `hashchange` and load events.

* Selected declaration: `expected[164]` `Background_Label`, native anchor
  `49f23914348d447f67af72bc705fe3581cf9f23bd374f364a20c9ab2fd37b9ff` in
  `api/ad8b3be9…048172f.html`.
* Frame document: `readyState` `complete`. The scrolling element is `HTML`
  with computed `scroll-behavior: auto`.
* 390 px: frame viewport 390×513, `scrollHeight` 393,765. The target top is 19
  when revealed (`scrollTop`/`scrollY` 45,005) and 45,024 after `scrollTo(0,0)`.
* 1280 px: frame viewport 912×900, `scrollHeight` 286,538. The target top is 19,
  and 34,009 after scrolling.
* Timeline after clicking the link: native fragment scroll at t=561 ms →
  `hashchange` at t=578 → router `scrollIntoView` at t=579 → the test's
  `revealed()` resolves at t=588 → the test's `scrollTo(0,0)` at t=595.

## Root cause: unreliable test precondition, not an enhancer defect

Native fragment navigation makes `revealed(mid)` true about one frame **before**
the v0.1.5 router handles that selection's `hashchange` and runs its deferred
single-frame reveal. That reveal is upstream `0eeeadbb`'s designed behavior.
If the test's line-145 `scrollTo(0,0)` lands inside that window, the router
correctly re-shows the declaration the reader has just selected, and line 146
can never become true. `deterministic-reproduction.json` places the test's
scroll in that window. v0.1.5 then reproduces the hosted timeout at both 390 px
and 1280 px, while v0.1.1 (which has no router reveal) passes line 146. No
navigation defect was found: v0.1.5 reveals only the current selection, once,
after its hash completes.

## Correction (test setup only)

Before clicking, the test now arms a bounded wait for that selection's own
`hashchange`. After `revealed(mid)` it awaits that event (and `load`, if the
document is still loading), then two animation frames for the router's
deferred reveal, and only then scrolls away. It then independently asserts:

* visible immediately before scrolling;
* off-screen in each of the next 10 frames;
* still the `:target` with the exact hash.

It reselects the same link and requires `revealed(mid)`, the outer
`?declaration=` and the frame hash. There are no sleeps, the timeouts are
unchanged, and the history and reload checks and all eight configurations are
unchanged.

## Negative-first (`negative-first-all-configurations.log`)

| Site | Result |
| --- | --- |
| v0.1.5 | 8/8 pass |
| v0.1.5 + injected hosted race (scroll inside the window) | 8/8 pass |
| v0.1.1, label skipped | every JS-on configuration fails at the post-reselection `revealed(mid)`, after the setup proved off-screen (34,009 / 45,024 px). JS-off configurations pass, because restoration is a JavaScript-only check. |
| v0.1.1, full | 8/8 fail at the exact filter label |
