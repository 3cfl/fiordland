.pragma library

const functions = {
    sqrt: Math.sqrt, cbrt: Math.cbrt, abs: Math.abs, sin: Math.sin, cos: Math.cos, tan: Math.tan,
    asin: Math.asin, acos: Math.acos, atan: Math.atan, ln: Math.log, log: Math.log10, log2: Math.log2,
    exp: Math.exp, floor: Math.floor, ceil: Math.ceil, round: Math.round, min: Math.min, max: Math.max
};
const constants = { pi: Math.PI, "π": Math.PI, e: Math.E, tau: Math.PI * 2 };
const aliases = { "×": "*", "÷": "/", "−": "-" };

function has(obj, key) {
    return Object.prototype.hasOwnProperty.call(obj, key);
}

function tokenize(src) {
    const tokens = [];
    let i = 0;
    while (i < src.length) {
        const c = src[i];
        if (/\s/.test(c)) {
            i++;
        } else if (/[0-9.]/.test(c)) {
            const m = /^(\d+\.?\d*|\.\d+)(e[+-]?\d+)?/i.exec(src.slice(i));
            if (!m)
                throw new Error("bad number");
            tokens.push({ t: "num", v: parseFloat(m[0]) });
            i += m[0].length;
        } else if (/[a-zπ]/i.test(c)) {
            const m = /^([a-z][a-z0-9]*|π)/i.exec(src.slice(i));
            tokens.push({ t: "id", v: m[0].toLowerCase() });
            i += m[0].length;
        } else if ("+-*/%^()!,".indexOf(c) >= 0 || has(aliases, c)) {
            tokens.push({ t: "op", v: aliases[c] || c });
            i++;
        } else {
            throw new Error("bad char");
        }
    }
    return tokens;
}

function factorial(n) {
    if (n < 0 || n !== Math.floor(n) || n > 170)
        return NaN;
    let r = 1;
    for (let k = 2; k <= n; k++)
        r *= k;
    return r;
}

function parse(tokens) {
    let pos = 0;
    let ops = 0;
    const peek = () => tokens[pos];
    const isOp = v => peek() !== undefined && peek().t === "op" && peek().v === v;
    const expect = v => {
        if (!isOp(v))
            throw new Error("expected " + v);
        pos++;
    };

    function expr() {
        let v = term();
        while (isOp("+") || isOp("-")) {
            const o = tokens[pos++].v;
            ops++;
            const r = term();
            v = o === "+" ? v + r : v - r;
        }
        return v;
    }

    function term() {
        let v = unary();
        for (;;) {
            if (isOp("*") || isOp("/") || isOp("%")) {
                const o = tokens[pos++].v;
                ops++;
                const r = unary();
                v = o === "*" ? v * r : o === "/" ? v / r : v % r;
            } else if (peek() !== undefined && (peek().t === "id" || isOp("("))) {
                ops++;
                v *= unary();
            } else {
                return v;
            }
        }
    }

    function unary() {
        if (isOp("-")) {
            pos++;
            return -unary();
        }
        if (isOp("+")) {
            pos++;
            return unary();
        }
        return power();
    }

    function power() {
        const base = postfix();
        if (isOp("^")) {
            pos++;
            ops++;
            return Math.pow(base, unary());
        }
        return base;
    }

    function postfix() {
        let v = primary();
        while (isOp("!")) {
            pos++;
            ops++;
            v = factorial(v);
        }
        return v;
    }

    function primary() {
        const tok = peek();
        if (tok === undefined)
            throw new Error("unexpected end");
        if (tok.t === "num") {
            pos++;
            return tok.v;
        }
        if (isOp("(")) {
            pos++;
            const v = expr();
            expect(")");
            return v;
        }
        if (tok.t === "id") {
            pos++;
            if (has(functions, tok.v)) {
                expect("(");
                const args = [expr()];
                while (isOp(",")) {
                    pos++;
                    args.push(expr());
                }
                expect(")");
                ops++;
                return functions[tok.v].apply(null, args);
            }
            if (has(constants, tok.v))
                return constants[tok.v];
            throw new Error("unknown " + tok.v);
        }
        throw new Error("unexpected " + tok.v);
    }

    const value = expr();
    if (pos !== tokens.length)
        throw new Error("trailing input");
    return { value: value, ops: ops };
}

function format(v) {
    if (typeof v !== "number" || !isFinite(v))
        return null;
    if (Math.abs(v) >= 1e15 || (Math.abs(v) < 1e-9 && v !== 0))
        return v.toExponential(6).replace(/\.?0+e/, "e");
    return String(parseFloat(v.toPrecision(12)));
}

function evaluate(input, force) {
    const src = String(input || "").trim().replace(/^=/, "");
    if (!src || src.length > 200)
        return null;
    try {
        const r = parse(tokenize(src));
        if (!force && r.ops === 0)
            return null;
        return format(r.value);
    } catch (e) {
        return null;
    }
}
