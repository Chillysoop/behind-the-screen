"""The Defold builder refuses a project with a require cycle in it, even when the require is
inside a function and only runs later. This finds any cycle the way the builder does (every
`require "x"` in the source, comments aside), so a cycle shows up here and not at build time.
Use util.lazy(name) for a require that has to go back the other way.

The builder also bundles only the modules a script reaches through a literal `require "x"`. A
module reached only through util.lazy(name) is left out, and the game stops with "module not
found" when it's first used (v2, October 30: game.model.museum_night). So every util.lazy target
must also be required literally somewhere a script reaches.

    python3 tools/tests/require_check.py      (exit code 1 on a cycle or an unbundled lazy module)
"""
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
EXTS = (".lua", ".script", ".gui_script", ".render_script")
SKIP = ("build", "tools", ".git")


LAZY = {}   # module path -> the files that reach it only through util.lazy


def modules():
    mods = {}
    for root, dirs, files in os.walk(ROOT):
        rel = os.path.relpath(root, ROOT)
        if rel.split(os.sep)[0] in SKIP:
            dirs[:] = []
            continue
        for f in files:
            if f.endswith(EXTS):
                p = os.path.relpath(os.path.join(root, f), ROOT).replace(os.sep, "/")
                src = open(os.path.join(root, f), encoding="utf-8").read()
                src = re.sub(r"--\[\[.*?\]\]", "", src, flags=re.S)
                src = re.sub(r"--[^\n]*", "", src)
                reqs = re.findall(r"require\s*\(?\s*[\"']([\w\.]+)[\"']", src)
                mods[p] = [r.replace(".", "/") + ".lua" for r in reqs]
                for r in re.findall(r"lazy\s*\(\s*[\"']([\w\.]+)[\"']", src):
                    LAZY.setdefault(r.replace(".", "/") + ".lua", []).append(p)
    return mods


def cycles(mods):
    graph = {k: [d for d in v if d in mods] for k, v in mods.items()}
    sys.setrecursionlimit(100000)
    index, low, on, stack, out, n = {}, {}, set(), [], [], [0]

    def visit(v):
        index[v] = low[v] = n[0]
        n[0] += 1
        stack.append(v)
        on.add(v)
        for w in graph[v]:
            if w not in index:
                visit(w)
                low[v] = min(low[v], low[w])
            elif w in on:
                low[v] = min(low[v], index[w])
        if low[v] == index[v]:
            comp = []
            while True:
                w = stack.pop()
                on.discard(w)
                comp.append(w)
                if w == v:
                    break
            if len(comp) > 1 or v in graph[v]:
                out.append(sorted(comp))

    for v in graph:
        if v not in index:
            visit(v)
    return out


def bundled(mods):
    """What the builder packs: every module a script reaches through literal requires."""
    seen = set()
    todo = [m for m in mods if not m.endswith(".lua")]
    while todo:
        m = todo.pop()
        if m in seen:
            continue
        seen.add(m)
        todo.extend(d for d in mods.get(m, []) if d in mods)
    return seen


if __name__ == "__main__":
    mods = modules()
    found = cycles(mods)
    for c in found:
        print("require cycle: " + " <-> ".join(c))
    packed = bundled(mods)
    missing = sorted(m for m in LAZY if m in mods and m not in packed)
    for m in missing:
        print("only reached through util.lazy, so not bundled: %s (from %s)" % (m, ", ".join(sorted(set(LAZY[m])))))
    print("%d modules, %d cycles, %d lazy modules left out of the build" % (len(mods), len(found), len(missing)))
    sys.exit(1 if (found or missing) else 0)
