"""Finds assignments to a for-loop variable inside its loop: python3 tools/lualint/forcheck.py file.lua ...

grandMA3 2.5.1's Lua refuses them (stock Lua 5.4 accepts them), so `loadfile` alone won't catch it.
Prints each hit as file:line: name and exits 1 when there are any.
"""
import os, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from luaparse import P


class ForCheck(P):
    def __init__(s, src):
        P.__init__(s, src)
        s.hits = []
        s._fornames = None

    def statement(s):
        x = s.v()
        if x == "for":
            start = s.i
            s.next()
            names = [s.next().val]
            while s.v() == ",":
                s.next()
                names.append(s.next().val)
            s.i = start
            s._fornames = names
        if x not in ("for", "local", "function", "do", "while", "repeat", "if", "return", ";", "::", "break", "goto"):
            t = s.peek()
            if t is not None and t.kind == "name" and s.v(1) in ("=", ","):
                for sc in reversed(s.scopes):
                    if t.val in sc:
                        if t.val in sc.get("__for__", set()):
                            s.hits.append((t.line, t.val))
                        break
        return P.statement(s)

    def declare(s, name):
        P.declare(s, name)
        fn = s._fornames
        if fn and name in fn:
            s.scopes[-1].setdefault("__for__", set()).add(name)
            if name == fn[-1]:
                s._fornames = None


def check(path):
    with open(path, encoding="utf-8") as f:
        p = ForCheck(f.read())
    p.block()
    return p.hits


def main(paths):
    bad = 0
    for path in paths:
        for line, name in check(path):
            print(f"{path}:{line}: assigns to for-loop variable '{name}' (grandMA3 rejects this)")
            bad += 1
    return 1 if bad else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
