"""Recursive-descent Lua 5.4 parser that only tracks scopes:
   - top-level `local` statements of the main chunk
   - every name reference, resolved to 'top' (main-chunk local), 'local', or 'global'
"""
import re, sys
sys.setrecursionlimit(20000)
from lualex_min import lex

class P:
    def __init__(s, src):
        s.t = lex(src); s.i = 0
        s.scopes = [{}]
        s.top_locals = []   # (local_tok, is_func, [name toks], has_assign)
        s.refs = []         # (tok, resolution, depth_of_function)
        s.fdepth = 0
    # -- helpers
    def peek(s, k=0): return s.t[s.i + k] if s.i + k < len(s.t) else None
    def v(s, k=0):
        x = s.peek(k); return x.val if x else None
    def kind(s, k=0):
        x = s.peek(k); return x.kind if x else None
    def next(s): x = s.t[s.i]; s.i += 1; return x
    def expect(s, val):
        x = s.next()
        if x.val != val: raise SyntaxError(f"expected {val} got {x} ")
        return x
    def resolve(s, name):
        for sc in reversed(s.scopes):
            if name in sc: return sc[name]
        return "global"
    def declare(s, name):
        s.scopes[-1][name] = "top" if (len(s.scopes) == 1) else "local"
    def push(s): s.scopes.append({})
    def pop(s): s.scopes.pop()
    def ref(s, tok): s.refs.append((tok, s.resolve(tok.val)))

    # -- blocks
    def block_end(s):
        return s.peek() is None or s.v() in ("end", "else", "elseif", "until")
    def block(s):
        while not s.block_end():
            if s.v() == "return":
                s.next()
                if not s.block_end() and s.v() != ";": s.exprlist()
                if s.v() == ";": s.next()
                break
            s.statement()

    def statement(s):
        x = s.v()
        if x == ";": s.next(); return
        if x == "::": s.next(); s.next(); s.expect("::"); return
        if x == "break": s.next(); return
        if x == "goto": s.next(); s.next(); return
        if x == "do":
            s.next(); s.push(); s.block(); s.expect("end"); s.pop(); return
        if x == "while":
            s.next(); s.expr(); s.expect("do"); s.push(); s.block(); s.expect("end"); s.pop(); return
        if x == "repeat":
            s.next(); s.push(); s.block(); s.expect("until"); s.expr(); s.pop(); return
        if x == "if":
            s.next(); s.expr(); s.expect("then"); s.push(); s.block(); s.pop()
            while s.v() == "elseif":
                s.next(); s.expr(); s.expect("then"); s.push(); s.block(); s.pop()
            if s.v() == "else":
                s.next(); s.push(); s.block(); s.pop()
            s.expect("end"); return
        if x == "for":
            s.next()
            names = [s.next().val]
            while s.v() == ",": s.next(); names.append(s.next().val)
            if s.v() == "=":
                s.next(); s.exprlist()
            else:
                s.expect("in"); s.exprlist()
            s.expect("do"); s.push()
            for nm in names: s.declare(nm)
            s.block(); s.expect("end"); s.pop(); return
        if x == "function":
            s.next()
            nt = s.next(); s.ref(nt)
            method = False
            while s.v() in (".", ":"):
                if s.v() == ":": method = True
                s.next(); s.next()
            s.funcbody(method); return
        if x == "local":
            ltok = s.next()
            if s.v() == "function":
                s.next(); nt = s.next()
                top = len(s.scopes) == 1
                if top: s.top_locals.append((ltok, True, [nt], True))
                s.declare(nt.val)
                s.funcbody(False); return
            names = [s.next()]
            if s.v() == "<": s.next(); s.next(); s.expect(">")
            while s.v() == ",":
                s.next(); names.append(s.next())
                if s.v() == "<": s.next(); s.next(); s.expect(">")
            has = False
            if s.v() == "=":
                has = True; s.next(); s.exprlist()
            if len(s.scopes) == 1: s.top_locals.append((ltok, False, names, has))
            for nm in names: s.declare(nm.val)
            return
        # exprstat: assignment or call
        s.suffixedexp()
        if s.v() in ("=", ","):
            while s.v() == ",": s.next(); s.suffixedexp()
            s.expect("="); s.exprlist()

    def funcbody(s, method):
        s.expect("(")
        s.push(); s.fdepth += 1
        if method: s.declare("self")
        while s.v() != ")":
            if s.v() == "...": s.next()
            else: s.declare(s.next().val)
            if s.v() == ",": s.next()
        s.expect(")")
        s.block(); s.expect("end")
        s.pop(); s.fdepth -= 1

    # -- expressions
    def exprlist(s):
        s.expr()
        while s.v() == ",": s.next(); s.expr()

    BIN = set("+ - * / // % ^ .. == ~= < <= > >= and or & | ~ << >>".split())
    def expr(s):
        if s.v() in ("not", "-", "#", "~"): s.next(); s.expr(); return
        s.simpleexp()
        while s.v() in s.BIN and s.kind() in ("op", "kw"):
            s.next()
            if s.v() in ("not", "-", "#", "~"): s.next(); s.unary_rest()
            else: s.simpleexp()
    def unary_rest(s):
        while s.v() in ("not", "-", "#", "~"): s.next()
        s.simpleexp()
    def simpleexp(s):
        k, x = s.kind(), s.v()
        if k in ("num", "str") or x in ("nil", "true", "false", "..."): s.next(); return
        if x == "{": s.table(); return
        if x == "function": s.next(); s.funcbody(False); return
        s.suffixedexp()
    def primaryexp(s):
        if s.v() == "(":
            s.next(); s.expr(); s.expect(")"); return
        t = s.next()
        if t.kind != "name": raise SyntaxError(f"unexpected {t}")
        s.ref(t)
    def suffixedexp(s):
        s.primaryexp()
        while True:
            x = s.v()
            if x == ".": s.next(); s.next()
            elif x == "[": s.next(); s.expr(); s.expect("]")
            elif x == ":": s.next(); s.next(); s.args()
            elif x in ("(", "{") or s.kind() == "str": s.args()
            else: return
    def args(s):
        if s.kind() == "str": s.next(); return
        if s.v() == "{": s.table(); return
        s.expect("(")
        if s.v() != ")": s.exprlist()
        s.expect(")")
    def table(s):
        s.expect("{")
        while s.v() != "}":
            if s.v() == "[":
                s.next(); s.expr(); s.expect("]"); s.expect("="); s.expr()
            elif s.kind() == "name" and s.v(1) == "=":
                s.next(); s.next(); s.expr()
            else:
                s.expr()
            if s.v() in (",", ";"): s.next()
        s.expect("}")

def parse(src):
    p = P(src); p.block()
    if p.peek() is not None: raise SyntaxError(f"trailing {p.peek()}")
    return p
