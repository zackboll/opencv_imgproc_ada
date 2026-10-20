"""Audit release lockfiles; only the test crate's parent pin is excepted."""

import argparse
from pathlib import Path
import tomllib


CORE_050 = "f8aef00c5366b4275ccd3d934f9c73ea5b83cd4f"
CORE_URL = "git+https://github.com/zackboll/opencv_core_ada.git"
IMGPROC_URL = "git+https://github.com/zackboll/opencv_imgproc_ada.git"


def require(condition, message):
    if not condition:
        raise ValueError(message)


def verify(path, core_version=None, imgproc_commit=None,
           allow_parent_pin=False):
    states = tomllib.loads(Path(path).read_text())["solution"]["state"]
    selected = {}
    for state in states:
        name = state["crate"]
        if state["fulfilment"] == "linked":
            require(allow_parent_pin and name == "opencv_imgproc",
                    f"source link is not allowed for {name}")
            require(state["link"]["path"] == "..",
                    "Imgproc link must select the test crate parent")
            print("opencv_imgproc linked to test crate parent (allowed)")
            continue
        require(state["fulfilment"] == "solved",
                f"unsolved dependency: {name} ({state['fulfilment']})")
        if state.get("pinned", False):
            require(allow_parent_pin and name == "opencv_imgproc",
                    f"pin is not allowed for {name}")
        release = state["release"]
        selected[name] = release
        print(name, release["version"], release.get("origin"),
              "pinned=" + str(state.get("pinned", False)))
    core = selected["opencv_core"]
    require(core["origin"]["url"] == CORE_URL, "unexpected Core repository")
    if core_version is not None:
        require(core["version"] == core_version, "unexpected Core version")
        if core_version == "0.5.0":
            require(core["origin"]["commit"] == CORE_050,
                    "unexpected Core 0.5.0 origin commit")
    if imgproc_commit is not None:
        imgproc = selected["opencv_imgproc"]
        require(imgproc["version"] == "0.3.0", "unexpected Imgproc version")
        require(imgproc["origin"] == {
            "commit": imgproc_commit, "url": IMGPROC_URL},
            "unexpected Imgproc origin")
    print("PASS release selection and immutable origins:", path)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("lockfile", type=Path)
    parser.add_argument("--core-version")
    parser.add_argument("--imgproc-commit")
    parser.add_argument("--allow-parent-pin", action="store_true")
    args = parser.parse_args()
    try:
        verify(args.lockfile, args.core_version, args.imgproc_commit,
               args.allow_parent_pin)
    except (ValueError, KeyError, TypeError, OSError) as error:
        parser.exit(1, f"error: invalid release selection: {error}\n")


if __name__ == "__main__":
    main()