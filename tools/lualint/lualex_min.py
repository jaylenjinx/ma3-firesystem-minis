"""Tiny Lua 5.4 lexer + scope resolver, enough to:
 - find the main chunk's top-level `local` statements (to turn them into shared-env entries)
 - list every free (global) name reference with the scope it resolves to
"""
import re

KEYWORDS = set("""and break do else elseif end false for function goto if in local nil not or
repeat return then true until while""".split())

class Tok:
    __slots__ = ("kind", "val", "start", "end", "line")
    def __init__(s, kind, val, start, end, line):
        s.kind, s.val, s.start, s.end, s.line = kind, val, start, end, line
    def __repr__(s): return f"{s.kind}:{s.val}@{s.line}"

def lex(src):
    toks, i, n, line = [], 0, len(src), 1
    ops = sorted(["...", "..", "==", "~=", "<=", ">=", "//", "::", "<<", ">>",
                  "+", "-", "*", "/", "%", "^", "#", "&", "~", "|", "<", ">", "=",
                  "(", ")", "{", "}", "[", "]", ";", ":", ",", "."], key=len, reverse=True)
    while i < n:
        c = src[i]
        if c == "\n": line += 1; i += 1; continue
        if c in " \t\r": i += 1; continue
        if src.startswith("--", i):
            m = re.match(r"--\[(=*)\[", src[i:])
            if m:
                close = "]" + m.group(1) + "]"
                j = src.index(close, i) + len(close)
            else:
                j = src.find("\n", i)
                j = n if j < 0 else j
            line += src.count("\n", i, j); i = j; continue
        m = re.match(r"\[(=*)\[", src[i:])
        if m:
            close = "]" + m.group(1) + "]"
            j = src.index(close, i) + len(close)
            toks.append(Tok("str", src[i:j], i, j, line)); line += src.count("\n", i, j); i = j; continue
        if c in "\"'":
            j = i + 1
            while src[j] != c:
                if src[j] == "\\":
                    if src[j + 1] == "z":
                        j += 2
                        while src[j] in " \t\r\n": j += 1
                        continue
                    j += 2; continue
                if src[j] == "\n": raise SyntaxError(f"newline in string at line {line}")
                j += 1
            j += 1
            toks.append(Tok("str", src[i:j], i, j, line)); line += src.count("\n", i, j); i = j; continue
        m = re.match(r"0[xX][0-9a-fA-F.]+(?:[pP][+-]?\d+)?|\d+\.?\d*(?:[eE][+-]?\d+)?|\.\d+(?:[eE][+-]?\d+)?", src[i:])
        if m and (c.isdigit() or (c == "." and i + 1 < n and src[i + 1].isdigit())):
            j = i + len(m.group(0)); toks.append(Tok("num", m.group(0), i, j, line)); i = j; continue
        m = re.match(r"[A-Za-z_]\w*", src[i:])
        if m:
            w = m.group(0); j = i + len(w)
            toks.append(Tok("kw" if w in KEYWORDS else "name", w, i, j, line)); i = j; continue
        for op in ops:
            if src.startswith(op, i):
                toks.append(Tok("op", op, i, i + len(op), line)); i += len(op); break
        else:
            raise SyntaxError(f"bad char {c!r} at line {line}")
    return toks

