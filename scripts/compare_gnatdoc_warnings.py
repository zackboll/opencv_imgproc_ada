#!/usr/bin/env python3
"""Compare GNATdoc warnings by Ada declaration, not by source position.

A warning identity is the filename, the enclosing Ada scope, the normalized
declaration signature, and the warning message. Source line and column
numbers only locate that declaration. They are not part of the identity.

The scope is the package and, for a component, the record type that contains
the declaration. Two subprograms with the same profile in different packages
therefore cannot cancel, and two record components with the same name stay
distinct. A semicolon inside a parameter list does not end the declaration:
the signature keeps the full profile, including a function's return type.
Comments and Ada string literals are not treated as code.

Every current warning must map to exactly one declaration. Ambiguous,
unscoped, or unmapped locations fail closed. Warning-shaped diagnostics that
do not match the pinned GNATdoc 26.0.0 format also fail, including malformed
baseline entries. Ordinary non-warning log text is ignored.

The baseline is the normalized identity list produced by --write-baseline from
one complete GNATdoc log and the sources of that same revision. It is not a
raw copy of the log: a later comment edit would make those old line numbers
name a different declaration.

Adapted from opencv_core_ada for Imgproc's single large specification: an
identifier list such as `X_Shift, Y_Shift : T;` declares one identity per
name, each found at its own column, and a declaration may span up to
MAX_DECLARATION_LINES source lines (Color_Conversion spans 87 lines).
Longer unterminated declarations still fail closed. With --fail-on-removed,
a baseline that still lists fixed warnings also fails, so a warning removed
by one change cannot silently return in a later one.
"""

import argparse
import re
import sys
from collections import Counter
from pathlib import Path

WARNING_RE = re.compile(
    r"^(?P<file>[^:\s]+):(?P<line>\d+):(?P<column>\d+):\s+warning:\s+(?P<message>.+)$"
)
WARNING_HINT_RE = re.compile(r"(^|\s)warning:", re.IGNORECASE)
HEADER_RE = re.compile(
    r"(\s*)((?:overriding|not|abstract|private)\s+)*"
    r"(procedure|function|package|type|subtype)\b"
)
OBJECT_RE = re.compile(
    r"^(\s*)([A-Za-z][A-Za-z0-9_.]*(?:\s*,\s*[A-Za-z][A-Za-z0-9_]*)*)\s*:"
)
NAME_AFTER_KEYWORD_RE = re.compile(
    r"\s*([A-Za-z][A-Za-z0-9_]*(?:\.[A-Za-z][A-Za-z0-9_]*)*)"
)
MAX_DECLARATION_LINES = 200


class WarningComparisonError(Exception):
    """A diagnostic cannot be identified safely."""


def code_tokens(line):
    """Yield code characters, skipping comments and Ada string literals.

    A doubled quote inside a string is one escaped quote. Text after `--`
    outside a string is a comment, so a semicolon or `--` inside a string does
    not end a declaration or hide the following code.
    """
    characters = []
    index = 0
    while index < len(line):
        if line.startswith("--", index):
            break
        if line[index] == '"':
            characters.append(" ")
            index += 1
            while index < len(line):
                if line[index] == '"':
                    if index + 1 < len(line) and line[index + 1] == '"':
                        index += 2
                        continue
                    index += 1
                    break
                index += 1
            else:
                raise WarningComparisonError("unterminated Ada string literal")
            continue
        characters.append(line[index])
        index += 1
    return "".join(characters)


def name_at(line, column):
    """Return the identifier occupying a 1-based column, ignoring comments."""
    if line.lstrip().startswith("--"):
        return None
    if not (0 < column <= len(line)):
        return None
    if column > 1 and (line[column - 2].isalnum() or line[column - 2] == "_"):
        return None
    if not (line[column - 1].isalpha() or line[column - 1] == "_"):
        return None
    end = column - 1
    while end < len(line) and (line[end].isalnum() or line[end] in "._"):
        end += 1
    return line[column - 1:end]


def _normalize(text):
    signature = re.sub(r"\s+", " ", text).strip()
    signature = re.sub(r"\(\s+", "(", signature)
    signature = re.sub(r"\s+\)", ")", signature)
    signature = re.sub(r"\s*,\s*", ", ", signature)
    signature = re.sub(r"\s*:\s*", " : ", signature)
    signature = re.sub(r"\s*;", ";", signature)
    return re.sub(r"\s+", " ", signature).strip()


def _scope_name(stack):
    if not any(item[0] == "package" for item in stack):
        raise WarningComparisonError("declaration is not inside a package")
    return ".".join(item[1] for item in stack if item[0] in ("package", "record"))



def declaration_index(lines):
    """Index declarations by the column and name GNATdoc reports.

    Parentheses are counted character by character after comments and string
    literals are removed. A semicolon ends a subprogram only at parenthesis
    depth zero, so a parameter separator cannot drop the return profile.
    Package and record boundaries update the scope used in the identity.
    """
    declarations = []
    stack = []
    pending_generic = []
    index = 0
    while index < len(lines):
        try:
            code = code_tokens(lines[index])
        except WarningComparisonError as error:
            raise WarningComparisonError(f"line {index + 1}: {error}") from error
        header = HEADER_RE.match(code)
        component = None if header else OBJECT_RE.match(code)
        if header is None and component is None:
            if code.strip() == "generic":
                pending_generic.append(index)
            else:
                _close_scopes(lines, stack, index, code)
            index += 1
            continue
        if component is not None:
            if pending_generic and not any(item[0] == "package" for item in stack):
                index += 1
                continue
            if not any(item[0] == "package" for item in stack):
                index += 1
                continue
            in_record = any(item[0] == "record" for item in stack)
            scope = _scope_name(stack) if in_record else ".".join(
                item[1] for item in stack if item[0] == "package"
            )
            end, signature, _depth = _declaration_span(lines, index, "object")
            for name, column in _identifier_list(lines[index], component.group(2)):
                declarations.append(
                    _declaration(
                        index + 1, end + 1, column, name, f"{scope}.{name}",
                        _normalize(signature),
                    )
                )
            index = end + 1
            continue
        name_match = NAME_AFTER_KEYWORD_RE.match(code[header.end():])
        if name_match is None:
            index += 1
            continue
        name = name_match.group(1)
        column = lines[index].find(name, header.end()) + 1
        kind = header.group(3)
        if kind == "package":
            scope = ".".join(item[1] for item in stack if item[0] == "package")
            qualified = f"{scope}.{name}" if scope else name
            end, package_text, _depth = _package_header(lines, index)
            if pending_generic:
                generic_start = pending_generic.pop(0)
                formals = _generic_formals(lines, generic_start + 1, index)
                for formal in formals:
                    declarations.append(formal)
            signature = _normalize(f"package {qualified} is")
            if " is new " in _normalize(package_text):
                signature = _normalize(package_text.replace(name, qualified, 1))
            declarations.append(
                _declaration(index + 1, end + 1, column, name, qualified, signature)
            )
            if " is new " not in _normalize(package_text):
                stack.append(("package", name, None))
            index = end + 1
            continue
        if kind == "type" and pending_generic and not any(
            item[0] == "package" for item in stack
        ):
            end, signature, _depth = _declaration_span(lines, index, "object")
            declarations.append(
                _declaration(
                    index + 1, end + 1, column, name,
                    f"generic {name}", _normalize(signature),
                )
            )
            index = end + 1
            continue
        try:
            scope = _scope_name(stack)
        except WarningComparisonError as error:
            raise WarningComparisonError(
                f"line {index + 1}: {name}: {error}"
            ) from error
        end, signature, depth_at_end = _declaration_span(lines, index, kind)
        signature = _normalize(signature)
        qualified = f"{scope}.{name}"
        declarations.append(
            _declaration(index + 1, end + 1, column, name, qualified, signature)
        )
        if kind == "type" and "(" in signature and " is record" not in signature:
            _enumeration_literals(lines, declarations, index, end, qualified, signature)
        if kind == "type" and re.search(r"\bis\s+record\b|\brecord\b", signature):
            header_only = re.split(r"\brecord\b", signature, maxsplit=1)[0] + "record"
            declarations[-1]["signature"] = _normalize(header_only)
            record_end = _record_end(lines, index + 2)
            declarations[-1]["end"] = record_end + 1
            stack.append(("record", name, depth_at_end))
            index += 1
            continue
        if (
            kind == "type"
            and signature.rstrip(";").endswith(" is")
            and index + 1 < len(lines)
            and code_tokens(lines[index + 1]).strip() == "record"
        ):
            declarations[-1]["signature"] = _normalize(signature.rstrip(";") + " record")
            record_end = _record_end(lines, index + 2)
            declarations[-1]["end"] = record_end + 1
            stack.append(("record", name, 0))
            index += 2
            continue
        index = end + 1
    if stack:
        raise WarningComparisonError(
            "unclosed Ada scope: " + ".".join(item[1] for item in stack)
        )
    return _by_location(declarations)


def _find_identifier(text, name, start=0):
    """Return the 0-based column of a whole identifier, or -1."""
    match = re.compile(
        rf"(?<![A-Za-z0-9_.]){re.escape(name)}(?![A-Za-z0-9_])"
    ).search(text, start)
    return -1 if match is None else match.start()


def _identifier_list(line, names):
    """Return each name of `A, B : T` with its own 1-based column."""
    result = []
    cursor = 0
    for name in (item.strip() for item in names.split(",")):
        column = _find_identifier(line, name, cursor)
        if column < 0:
            raise WarningComparisonError(f"identifier {name} not found")
        result.append((name, column + 1))
        cursor = column + len(name)
    return result


def _package_header(lines, start):
    return _declaration_span(lines, start, "package")


def _generic_formals(lines, start, stop):
    """Return formal declarations between `generic` and the package header."""
    formals = []
    cursor = start
    while cursor < stop:
        code = code_tokens(lines[cursor])
        header = HEADER_RE.match(code)
        formal = None if header else OBJECT_RE.match(code)
        if header is None and formal is None:
            cursor += 1
            continue
        if formal is not None:
            names = _identifier_list(lines[cursor], formal.group(2))
        else:
            name_match = NAME_AFTER_KEYWORD_RE.match(code[header.end():])
            if name_match is None:
                cursor += 1
                continue
            name = name_match.group(1)
            names = [(name, lines[cursor].find(name, header.end()) + 1)]
        end, signature, _depth = _declaration_span(lines, cursor, "object")
        for name, column in names:
            formals.append(
                _declaration(
                    cursor + 1, end + 1, column, name,
                    f"generic {name}", _normalize(signature),
                )
            )
        cursor = end + 1
    return formals


def _record_end(lines, start):
    """Return the line index of the matching `end record`, ignoring nested records."""
    depth = 1
    for cursor in range(start, len(lines)):
        stripped = " ".join(code_tokens(lines[cursor]).split())
        if re.search(r"\brecord\b", stripped) and not re.match(r"end\s+record\b", stripped):
            depth += 1
        if re.match(r"end\s+record\b", stripped):
            depth -= 1
            if depth == 0:
                return cursor
    raise WarningComparisonError(f"line {start + 1}: record has no end record")


def _declaration(start, end, column, name, scope, signature):
    return {
        "start": start,
        "end": end,
        "column": column,
        "name": name,
        "scope": scope,
        "signature": signature,
    }


def _enumeration_literals(lines, declarations, start, end, scope, signature):
    """Record enumeration literals. Other parenthesized types simply add none."""
    if " is (" not in signature and not signature.rstrip(";").endswith(" is"):
        return
    text = " ".join(code_tokens(lines[cursor]) for cursor in range(start, end + 1))
    listed = re.search(r"\bis\s*\((.*)\)\s*;", text, re.S)
    if listed is None:
        return
    for literal in re.findall(r"[A-Za-z][A-Za-z0-9_]*", listed.group(1)):
        for cursor in range(start, end + 1):
            column = _find_identifier(code_tokens(lines[cursor]), literal)
            if column < 0:
                continue
            declarations.append(
                _declaration(
                    cursor + 1, cursor + 1, column + 1, literal,
                    f"{scope}.{literal}", signature,
                )
            )
            break


def _declaration_span(lines, start, kind):
    """Return the last line, signature text, and parenthesis depth."""
    depth = 0
    parts = []
    for cursor in range(start, min(len(lines), start + MAX_DECLARATION_LINES)):
        code = code_tokens(lines[cursor])
        parts.append(" ".join(code.split()))
        ended = False
        for character in code:
            if character == "(":
                depth += 1
            elif character == ")":
                depth -= 1
                if depth < 0:
                    raise WarningComparisonError(
                        f"line {cursor + 1}: unbalanced parenthesis"
                    )
            elif character == ";" and depth == 0 and kind != "package":
                ended = True
                break
        if kind == "package" and depth == 0 and ";" in code:
            ended = True
        if kind == "package" and depth == 0 and re.search(r"\bis\b", code):
            if "is new" not in " ".join(code.split()):
                ended = True
        if ended:
            return cursor, " ".join(part for part in parts if part), depth
    raise WarningComparisonError(
        f"line {start + 1}: declaration signature did not terminate"
    )


def _close_scopes(lines, stack, index, code):
    stripped = " ".join(code.split())
    if re.match(r"end\s+record\b", stripped) or stripped == "end record;":
        if not stack or stack[-1][0] != "record":
            raise WarningComparisonError(f"line {index + 1}: end record without a record")
        stack.pop()
        return
    if re.match(r"end\b", stripped) and not re.match(
        r"end\s+(record|case|loop)\b", stripped
    ):
        if not stack or stack[-1][0] != "package":
            raise WarningComparisonError(f"line {index + 1}: end without a package")
        stack.pop()


def _by_location(declarations):
    grouped = {}
    for declaration in declarations:
        key = (
            declaration["column"],
            declaration["name"],
            declaration["scope"],
            declaration["signature"],
        )
        grouped.setdefault(key, []).append(declaration)
    for duplicates in grouped.values():
        if len(duplicates) > 1:
            for declaration in duplicates:
                declaration["ambiguous"] = True
    by_location = {}
    for declaration in declarations:
        by_location.setdefault(
            (declaration["column"], declaration["name"]), []
        ).append(declaration)
    return by_location


def _subject_declaration(lines, indexed, owner, subject, message):
    """Attach a component, literal, or generic formal to its owner.

    GNATdoc reports these warnings at the enclosing type or package name.
    The identity uses the member found inside that owner's span. Several
    members with the same name, or none, fail closed.
    """
    if message.startswith("generic formal "):
        start = 1
    else:
        start = owner["start"]
    if message.startswith("component "):
        profile = owner["signature"]
        head = profile.split(" is ", 1)[0]
        if re.search(rf"\b{re.escape(subject)}\b", head) and "(" in head:
            located = dict(owner)
            located["scope"] = f"{owner['scope']}.{subject}"
            return located
    matches = []
    for declarations in indexed.values():
        for declaration in declarations:
            if declaration["name"] != subject:
                continue
            if not (start <= declaration["start"] <= owner["end"]):
                continue
            if message.startswith("component ") and owner["name"] not in declaration["scope"]:
                continue
            matches.append(declaration)
    unique = {(item["scope"], item["signature"]): item for item in matches}
    if len(unique) != 1:
        raise WarningComparisonError(
            f"ambiguous or missing {message} under {owner['scope']}"
        )
    return next(iter(unique.values()))


def _comment_gap(lines, start, stop):
    return all(
        not lines[cursor].strip() or lines[cursor].strip().startswith("--")
        for cursor in range(start, stop)
    )


def locate_declaration(lines, indexed, line_number, column):
    """Find the one declaration named at this column.

    GNATdoc 26.0.0 points at the declaration name. Scanning may continue
    through a directly preceding comment block, because an older log line can
    land there after comments are inserted. It stops at the first code line
    and never crosses another declaration. Zero or several matches fail.
    """
    delta = 0
    while line_number + delta <= len(lines) and delta <= 80:
        source_line = lines[line_number + delta - 1]
        name = name_at(source_line, column)
        if name is not None:
            hits = [
                declaration
                for declaration in indexed.get((column, name), [])
                if declaration["start"] <= line_number + delta <= declaration["end"]
            ]
            if len(hits) != 1 or hits[0].get("ambiguous"):
                raise WarningComparisonError(
                    f"ambiguous or unmapped declaration at column {column} "
                    f"name {name}"
                )
            if delta != 0 and not _comment_gap(
                lines, line_number - 1, line_number - 1 + delta
            ):
                raise WarningComparisonError(
                    f"warning column crossed unrelated code before {name}"
                )
            return hits[0]
        stripped = source_line.strip()
        if stripped and not stripped.startswith("--"):
            raise WarningComparisonError(
                f"column {column} is not a declaration name on line {line_number}"
            )
        delta += 1
    raise WarningComparisonError(
        f"no declaration name at column {column} near line {line_number}"
    )


def parse_warnings(text, label):
    """Return warning records. Unrecognized warning-shaped lines fail."""
    records = []
    for number, raw in enumerate(text.splitlines(), start=1):
        stripped = raw.strip()
        if not stripped:
            continue
        match = WARNING_RE.match(stripped)
        if match is None:
            if WARNING_HINT_RE.search(stripped):
                raise WarningComparisonError(
                    f"{label}:{number}: unrecognized warning diagnostic: {stripped}"
                )
            continue
        message = match.group("message").strip()
        subject = re.match(
            r"(?:parameter|component|enumeration literal|generic formal) `([^`]+)`",
            message,
        )
        records.append(
            (
                match.group("file"),
                int(match.group("line")),
                int(match.group("column")),
                message,
                None if subject is None else subject.group(1),
            )
        )
    return records


def identities_from_log(text, source_root, label):
    """Map one GNATdoc log to stable declaration identities."""
    records = parse_warnings(text, label)
    sources = {}
    indexes = {}
    identities = []
    for filename, line_number, column, message, subject in records:
        if filename not in sources:
            path = source_root / filename
            if not path.is_file():
                raise WarningComparisonError(
                    f"{label}: missing Ada source for warning: {path}"
                )
            sources[filename] = path.read_text(encoding="utf-8").splitlines()
            indexes[filename] = declaration_index(sources[filename])
        try:
            declaration = locate_declaration(
                sources[filename], indexes[filename], line_number, column
            )
            if subject is not None and (
                message.startswith("component ")
                or message.startswith("enumeration literal ")
                or message.startswith("generic formal ")
            ):
                declaration = _subject_declaration(
                    sources[filename], indexes[filename], declaration, subject, message
                )
        except WarningComparisonError as error:
            raise WarningComparisonError(
                f"{label}: {filename}:{line_number}:{column}: {error}"
            ) from error
        identities.append(
            f"{filename}: {declaration['scope']}: {declaration['signature']}: "
            f"warning: {message}"
        )
    return identities


def parse_baseline(text):
    """Return identities from a structured baseline. Malformed lines fail."""
    identities = []
    for number, raw in enumerate(text.splitlines(), start=1):
        stripped = raw.strip()
        if not stripped:
            continue
        marker = stripped.rfind(": warning: ")
        filename = stripped.split(": ", 1)[0]
        if WARNING_RE.match(stripped) or marker < 0 or not filename.endswith(".ads"):
            raise WarningComparisonError(
                f"baseline:{number}: malformed baseline identity: {stripped}"
            )
        identities.append(stripped)
    return identities


def compare_identities(baseline_identities, current_identities):
    """Return added and removed identities, preserving duplicate occurrences."""
    baseline = Counter(baseline_identities)
    current = Counter(current_identities)
    added = []
    removed = []
    for identity, count in sorted((current - baseline).items()):
        added.extend([identity] * count)
    for identity, count in sorted((baseline - current).items()):
        removed.extend([identity] * count)
    return added, removed


def compare(baseline_text, current_text, source_root):
    """Compare a structured baseline with a current GNATdoc log."""
    return compare_identities(
        parse_baseline(baseline_text),
        identities_from_log(current_text, source_root, "current"),
    )


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("baseline", type=Path)
    parser.add_argument("current", type=Path)
    parser.add_argument(
        "--sources",
        type=Path,
        default=None,
        help="Directory containing the Ada sources named by the log",
    )
    parser.add_argument(
        "--write-baseline",
        action="store_true",
        help="Write normalized identities for the current log",
    )
    parser.add_argument(
        "--fail-on-removed",
        action="store_true",
        help="Also fail when the baseline lists warnings that no longer occur",
    )
    args = parser.parse_args(argv)
    source_root = args.sources
    if source_root is None:
        source_root = Path(__file__).resolve().parent.parent / "src"
    try:
        if args.write_baseline:
            identities = identities_from_log(
                args.current.read_text(encoding="utf-8"), source_root, "current"
            )
            args.baseline.write_text("\n".join(identities) + "\n", encoding="utf-8")
            print(f"Wrote {len(identities)} declaration warning identities")
            return 0
        added, removed = compare(
            args.baseline.read_text(encoding="utf-8"),
            args.current.read_text(encoding="utf-8"),
            source_root,
        )
    except WarningComparisonError as error:
        print(f"error: {error}", file=sys.stderr)
        return 1
    print(
        "GNATdoc warning delta: {added} added, {removed} removed".format(
            added=len(added), removed=len(removed)
        )
    )
    for item in added:
        print("added: " + item)
    for item in removed:
        print("removed: " + item)
    if removed and args.fail_on_removed:
        print(
            "error: warnings were fixed; regenerate the baseline with "
            "--write-baseline so they cannot silently return",
            file=sys.stderr,
        )
        return 1
    return 1 if added else 0


if __name__ == "__main__":
    sys.exit(main())

