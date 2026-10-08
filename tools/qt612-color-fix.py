#!/usr/bin/env python3
"""Qualify Omarchy palette references for Qt 6.12 in shell plugin QML.

Qt 6.12 adds a built-in `Color` type to QtQuick that shadows Omarchy's `Color`
singleton, so unqualified `Color.accent` / `Color.composed(...)` silently become
undefined (invisible bar text, broken dock). Omarchy's own fix (upstream commit
b83d3df) is: `import qs.Commons as Commons` and use `Commons.Color`.

    tools/qt612-color-fix.py ~/.config/omarchy/plugins

Idempotent. Skips strings, comments, import/pragma lines, .git and node_modules.
"""
import os, re, sys

ID = re.compile(r'(?<![\w.$])Color\b(?=\s*[.)\]},;:]|\s*$)')


def patch_line(line):
    out, i, start, n = [], 0, 0, len(line)
    while i < n:
        c = line[i]
        if c in "\"'`":
            out.append(ID.sub("Commons.Color", line[start:i]))
            j = i + 1
            while j < n and line[j] != c:
                j += 2 if line[j] == "\\" else 1
            out.append(line[i:j + 1]); i = j + 1; start = i
            continue
        if line.startswith("//", i):
            out.append(ID.sub("Commons.Color", line[start:i])); out.append(line[i:])
            return "".join(out)
        i += 1
    out.append(ID.sub("Commons.Color", line[start:]))
    return "".join(out)


def main(base):
    changed = 0
    for root, dirs, files in os.walk(base):
        dirs[:] = [d for d in dirs if d not in (".git", "node_modules") and not d.startswith(".")]
        if "kde-plasmoid" in root:
            continue
        for f in files:
            if not f.endswith(".qml"):
                continue
            p = os.path.join(root, f)
            t = open(p, encoding="utf-8").read()
            if "import qs.Commons" not in t or not ID.search(t):
                continue
            new, block = [], False
            for ln in t.split("\n"):
                s = ln.strip()
                if s.startswith("/*"):
                    block = True
                new.append(ln if block or s.startswith(("import ", "pragma ")) else patch_line(ln))
                if "*/" in s:
                    block = False
            t2 = "\n".join(new)
            if "import qs.Commons as Commons" not in t2:
                t2 = re.sub(r'^(import qs\.Commons[ \t]*)$', r'\1\nimport qs.Commons as Commons', t2, count=1, flags=re.M)
            if t2 != t:
                open(p, "w", encoding="utf-8").write(t2)
                changed += 1
    print(f"qt612-color-fix: patched {changed} file(s) under {base}")


if __name__ == "__main__":
    main(os.path.expanduser(sys.argv[1] if len(sys.argv) > 1 else "~/.config/omarchy/plugins"))
