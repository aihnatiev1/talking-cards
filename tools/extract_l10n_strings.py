#!/usr/bin/env python3
"""Extract all bilingual UI string pairs routed through AppS.

Scans lib/ for calls like:

    s('Привіт', 'Hello')            # plain lookup
    s.p('Рівень {n}', 'Level {n}', {'n': n})   # parameterised lookup

where the receiver is any variable known to hold an AppS instance
(assignment `final s = AppS(...)`, field/param `AppS s`), plus inline
`AppS(...)('uk', 'en')` calls.

Emits test/fixtures/l10n_strings.json — a sorted, deduplicated list of
{"uk": ..., "en": ...} pairs. This file is:
  * the byte-identical proof artifact for the multilingual refactor
    (phase 1 diff must be empty; phase 2 may only ADD pairs), and
  * the future translation source for additional locales.

Dart string interpolation is normalized to template form so that
`'Рівень $n'` and the phase-2 `s.p('Рівень {n}', ...)` rewrite produce
the SAME fixture entry:
  * `$name`             -> `{name}`
  * `${cards.length}`   -> `{length}`   (last identifier; `(...)`/`[...]`
                           argument groups stripped: `${f(x)}` -> `{f}`)
  * on collision of two DIFFERENT expressions within one string, each
    gets the camel-joined identifier path instead
    (`'${cards.length}/${allCards.length}'`
     -> `'{cardsLength}/{allCardsLength}'`)

Usage:
    python3 tools/extract_l10n_strings.py          # (re)write the fixture
    python3 tools/extract_l10n_strings.py --check  # compare against fixture:
        exit 1 if any existing pair changed/disappeared; added pairs listed.
"""

from __future__ import annotations

import json
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
LIB = ROOT / "lib"
FIXTURE = ROOT / "test" / "fixtures" / "l10n_strings.json"

ASSIGN_RE = re.compile(
    r"(?:final|var|const)\s+(\w+)\s*=\s*(?:const\s+)?AppS\s*\("
)
TYPED_RE = re.compile(r"\bAppS\s+(\w+)\b")

SIMPLE_ESCAPES = {
    "n": "\n",
    "t": "\t",
    "r": "\r",
    "'": "'",
    '"': '"',
    "\\": "\\",
    "$": "$",
}


# Sentinels wrapping a raw interpolation expression inside a parsed literal
# until placeholder names are resolved per whole template string.
PH_OPEN = "\x00"
PH_CLOSE = "\x01"
PH_RE = re.compile("\x00(.*?)\x01", re.S)


def _identifiers(expr: str) -> list[str]:
    """Identifier path of `expr` with `(...)`/`[...]` groups stripped and a
    leading `widget.`/`this.` receiver dropped."""
    out = []
    depth = 0
    for ch in expr:
        if ch in "([":
            depth += 1
        elif ch in ")]":
            depth -= 1
        elif depth == 0:
            out.append(ch)
    idents = re.findall(r"[A-Za-z_][A-Za-z0-9_]*", "".join(out))
    if len(idents) > 1 and idents[0] in ("widget", "this"):
        idents = idents[1:]
    return idents


def _preferred_name(expr: str) -> str:
    idents = _identifiers(expr)
    return idents[-1] if idents else expr.strip()


def _camel_join_name(expr: str) -> str:
    idents = _identifiers(expr)
    if not idents:
        return expr.strip()
    joined = idents[0]
    for part in idents[1:]:
        joined += part[0].upper() + part[1:]
    return joined


def resolve_placeholders(template: str) -> str:
    """Turn `\x00expr\x01` sentinels into `{name}` placeholders.

    Each distinct expression prefers its last identifier; if two different
    expressions in the same string would share a name, both fall back to
    the camel-joined identifier path.
    """
    groups: dict[str, set] = {}
    for expr in set(PH_RE.findall(template)):
        groups.setdefault(_preferred_name(expr), set()).add(expr)
    names = {}
    for preferred, exprs in groups.items():
        if len(exprs) == 1:
            names[next(iter(exprs))] = preferred
        else:
            for expr in exprs:
                names[expr] = _camel_join_name(expr)
    return PH_RE.sub(lambda m: "{" + names[m.group(1)] + "}", template)


def parse_string_literal(src: str, i: int):
    """Parse one Dart string literal starting at src[i] (a quote char).

    Returns (value, next_index) with escapes decoded and interpolation
    normalized to `{name}` placeholders, or None if src[i] is not a quote.
    """
    if i >= len(src) or src[i] not in "'\"":
        return None
    quote = src[i]
    # Triple-quoted strings are not used for AppS calls; treat as opaque.
    i += 1
    out = []
    while i < len(src):
        ch = src[i]
        if ch == "\\":
            nxt = src[i + 1] if i + 1 < len(src) else ""
            out.append(SIMPLE_ESCAPES.get(nxt, "\\" + nxt))
            i += 2
            continue
        if ch == quote:
            return "".join(out), i + 1
        if ch == "$":
            nxt = src[i + 1] if i + 1 < len(src) else ""
            if nxt == "{":
                depth = 1
                j = i + 2
                expr_start = j
                while j < len(src) and depth > 0:
                    c = src[j]
                    if c in "'\"":
                        lit = parse_string_literal(src, j)
                        if lit is None:
                            j += 1
                        else:
                            j = lit[1]
                        continue
                    if c == "{":
                        depth += 1
                    elif c == "}":
                        depth -= 1
                    j += 1
                expr = src[expr_start : j - 1]
                out.append(PH_OPEN + expr + PH_CLOSE)
                i = j
                continue
            m = re.match(r"[A-Za-z_][A-Za-z0-9_]*", src[i + 1 :])
            if m:
                out.append(PH_OPEN + m.group(0) + PH_CLOSE)
                i += 1 + m.end()
                continue
            out.append("$")
            i += 1
            continue
        out.append(ch)
        i += 1
    return None  # unterminated — not a valid literal


def skip_ws_and_comments(src: str, i: int) -> int:
    while i < len(src):
        if src[i].isspace():
            i += 1
        elif src.startswith("//", i):
            nl = src.find("\n", i)
            i = len(src) if nl == -1 else nl + 1
        elif src.startswith("/*", i):
            end = src.find("*/", i + 2)
            i = len(src) if end == -1 else end + 2
        else:
            break
    return i


def parse_adjacent_literals(src: str, i: int):
    """Parse one or more adjacent (implicitly concatenated) string literals."""
    first = parse_string_literal(src, i)
    if first is None:
        return None
    value, i = first
    while True:
        j = skip_ws_and_comments(src, i)
        nxt = parse_string_literal(src, j)
        if nxt is None:
            return value, i
        value += nxt[0]
        i = nxt[1]


def parse_pair_at(src: str, i: int):
    """At src[i] == '(' of an AppS call: parse ('uk literal', 'en literal', ...)."""
    assert src[i] == "("
    j = skip_ws_and_comments(src, i + 1)
    uk = parse_adjacent_literals(src, j)
    if uk is None:
        return None
    j = skip_ws_and_comments(src, uk[1])
    if j >= len(src) or src[j] != ",":
        return None
    j = skip_ws_and_comments(src, j + 1)
    en = parse_adjacent_literals(src, j)
    if en is None:
        return None
    return resolve_placeholders(uk[0]), resolve_placeholders(en[0])


def find_matching_paren(src: str, i: int):
    """src[i] == '(' — return index just past the matching ')'."""
    depth = 0
    while i < len(src):
        c = src[i]
        if c in "'\"":
            lit = parse_string_literal(src, i)
            if lit is None:
                i += 1
            else:
                i = lit[1]
            continue
        if c == "(":
            depth += 1
        elif c == ")":
            depth -= 1
            if depth == 0:
                return i + 1
        elif src.startswith("//", i) or src.startswith("/*", i):
            i = skip_ws_and_comments(src, i)
            continue
        i += 1
    return None


def extract_from_file(path: Path):
    src = path.read_text(encoding="utf-8")
    names = set(ASSIGN_RE.findall(src)) | set(TYPED_RE.findall(src))
    names.discard("AppS")
    pairs = []

    # Calls on named AppS receivers: s('uk', 'en') and s.p('uk', 'en', {...})
    for name in names:
        for m in re.finditer(
            r"\b%s(\.p)?\s*\(" % re.escape(name), src
        ):
            pair = parse_pair_at(src, m.end() - 1)
            if pair is not None:
                pairs.append(pair)

    # Inline AppS(...)('uk', 'en') calls.
    for m in re.finditer(r"\bAppS\s*\(", src):
        close = find_matching_paren(src, m.end() - 1)
        if close is None:
            continue
        j = skip_ws_and_comments(src, close)
        if j < len(src) and src[j] == "(":
            pair = parse_pair_at(src, j)
            if pair is not None:
                pairs.append(pair)
    return pairs


def extract_all():
    pairs = set()
    for path in sorted(LIB.rglob("*.dart")):
        pairs.update(extract_from_file(path))
    return sorted(pairs)


def main() -> int:
    check = "--check" in sys.argv[1:]
    pairs = extract_all()
    payload = [{"uk": uk, "en": en} for uk, en in pairs]

    if not check:
        FIXTURE.parent.mkdir(parents=True, exist_ok=True)
        FIXTURE.write_text(
            json.dumps(payload, ensure_ascii=False, indent=2) + "\n",
            encoding="utf-8",
        )
        print(f"Wrote {len(payload)} pairs to {FIXTURE.relative_to(ROOT)}")
        return 0

    if not FIXTURE.exists():
        print(f"ERROR: fixture {FIXTURE} missing — run without --check first")
        return 1
    old = {(p["uk"], p["en"]) for p in json.loads(FIXTURE.read_text("utf-8"))}
    new = set(pairs)
    removed = sorted(old - new)
    added = sorted(new - old)
    if added:
        print(f"Added pairs ({len(added)}):")
        for uk, en in added:
            print(f"  + uk={uk!r} en={en!r}")
    if removed:
        print(f"CHANGED/REMOVED pairs ({len(removed)}) — MUST be zero:")
        for uk, en in removed:
            print(f"  - uk={uk!r} en={en!r}")
        return 1
    print(f"OK: {len(old)} fixture pairs all present ({len(added)} added).")
    return 0


if __name__ == "__main__":
    sys.exit(main())
