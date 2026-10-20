"""Audit release lockfiles; the test crate's parent pin is the only exception."""

import argparse
from pathlib import Path
import tomllib


CORE_050 = "f8aef00c5366b4275ccd3d934f9c73ea5b83cd4f"
CORE_URL = "git+https://github.com/zackboll/opencv_core_ada.git"
IMGPROC_URL = "git+https://github.com/zackboll/opencv_imgproc_ada.git"


def verify(path, core_version=None, imgproc_commit=None, allow_parent_pin=False):
    states = tomllib.loads(Path(path).read_text())["solution"]["state"]
    selected = {}
    for state in states:
        name = state["crate"]
        if state["fulfilment"] == "linked":
            assert allow_parent_pin and name == "opencv_imgproc", name
            assert state["link"]["path"] == "..", state
            print("opencv_imgproc linked to test crate parent (allowed)")
            continue
        assert state["fulfilment"] == "solved", (name, state["fulfilment"])
        if state.get("pinned", False):
            assert allow_parent_pin and name == "opencv_imgproc", name
        release = state["release"]
        selected[name] = release
        print(name, release["version"], release.get("origin"),
              "pinned=" + str(state.get("pinned", False)))
    core = selected["opencv_core"]
    assert core["origin"]["url"] == CORE_URL, core
    if core_version is not None:
        assert core["version"] == core_version, core
        if core_version == "0.5.0":
            assert core["origin"]["commit"] == CORE_050, core
    if imgproc_commit is not None:
        imgproc = selected["opencv_imgproc"]
        assert imgproc["version"] == "0.3.0", imgproc
        assert imgproc["origin"] == {
            "commit": imgproc_commit, "url": IMGPROC_URL}, imgproc
    print("PASS release selection and immutable origins:", path)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("lockfile", type=Path)
    parser.add_argument("--core-version")
    parser.add_argument("--imgproc-commit")
    parser.add_argument("--allow-parent-pin", action="store_true")
    args = parser.parse_args()
    verify(args.lockfile, args.core_version, args.imgproc_commit,
           args.allow_parent_pin)


if __name__ == "__main__":
    main()