"""The Defold builder refuses a project with a require cycle in it, even when the require is
inside a function and only runs later. This finds any cycle the way the builder does (every
`require "x"` in the source, comments aside), so a cycle shows up here and not at build time.
Use util.lazy(name) for a require that has to go back the other way.

    python3 tools/tests/require_check.py      (exit code 1 on a cycle)
"""
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
EXTS = (".lua", ".script", ".gui_script", ".render_script")
SKIP = ("build", "tools", ".git")


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


if __name__ == "__main__":
    mods = modules()
    found = cycles(mods)
    for c in found:
        print("require cycle: " + " <-> ".join(c))
    print("%d modules, %d cycles" % (len(mods), len(found)))
    sys.exit(1 if found else 0)
