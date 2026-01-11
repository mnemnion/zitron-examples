//! EDN tokenizer

const TokenKind = @import("TokenKind.zig").TokenKind;

pub const Token = struct {
    kind: TokenKind,
    span: []const u8,
    line: usize,

    pub fn new(kind: TokenKind, span: []const u8, line: usize) Token {
        return .{ .kind = kind, .span = span, .line = line };
    }
};

const Tok = Token.new;

const key_words = std.StaticStringMap(TokenKind).initComptime(.{
    .{ "true", .TRUE },
    .{ "false", .FALSE },
    .{ "nil", .NIL },
});

const char_words = std.StaticStringMap(usize).initComptime(.{
    .{ "tab", 3 },
    .{ "space", 5 },
    .{ "newline", 7 },
    .{ "return", 6 },
});

pub const Tokenizer = struct {
    text: [:0]const u8,
    idx: usize = 0,
    line: usize = 1,

    pub fn init(text: [:0]const u8) Tokenizer {
        return .{ .text = text };
    }

    pub fn next(t: *Tokenizer) error{BadToken}!?Token {
        var m_symbol: ?TokenKind = null;
        scan: switch (t.text[t.idx]) {
            '(' => {
                defer t.idx += 1;
                return Tok(.PAL, t.text[t.idx..][0..1], t.line);
            },
            ')' => {
                defer t.idx += 1;
                return Tok(.PAR, t.text[t.idx..][0..1], t.line);
            },
            '{' => {
                defer t.idx += 1;
                return Tok(.CRL, t.text[t.idx..][0..1], t.line);
            },
            '}' => {
                defer t.idx += 1;
                return Tok(.CRR, t.text[t.idx..][0..1], t.line);
            },
            '[' => {
                defer t.idx += 1;
                return Tok(.SQL, t.text[t.idx..][0..1], t.line);
            },
            ']' => {
                defer t.idx += 1;
                return Tok(.SQR, t.text[t.idx..][0..1], t.line);
            },
            '"' => {
                const start = t.idx;
                t.idx += 1;
                while (t.text[t.idx] != '\n' and
                    t.text[t.idx] != 0 and
                    t.text[t.idx] != '"') : (t.idx += 1)
                {
                    if (t.text[t.idx] == '\\') t.idx += 1;
                }
                if (t.text[t.idx] == '"') {
                    t.idx += 1;
                    return Tok(.STRING, t.text[start..t.idx], t.line);
                } else {
                    return error.BadToken;
                }
            },
            ':' => {
                m_symbol = .KEYWORD;
                continue :scan 'a';
            },
            '#' => {
                const nb = t.text[t.idx + 1];
                if (nb == '_') {
                    defer t.idx += 2;
                    return Tok(.DISCARD, t.text[t.idx..][0..2], t.line);
                } else if (nb == '{') {
                    defer t.idx += 2;
                    return Tok(.LSET, t.text[t.idx..][0..2], t.line);
                } else if (std.ascii.isAlphabetic(nb)) {
                    m_symbol = .TAGGED;
                    continue :scan 'a';
                } else return error.BadToken;
            },
            '.', '+', '-' => {
                if ('0' <= t.text[t.idx + 1] and t.text[t.idx + 1] <= '9') {
                    continue :scan '1';
                } else {
                    continue :scan 'a';
                }
            },
            'a'...'z', 'A'...'Z', '*', '!', '_', '?', '$', '%', '&', '=', '<', '>' => {
                const start = t.idx;
                t.idx += 1;
                while (symbolFollow(t.text[t.idx])) : (t.idx += 1) {}
                if (t.text[t.idx] == '/') {
                    t.idx += 1;
                    while (symbolFollow(t.text[t.idx])) : (t.idx += 1) {}
                    if (t.text[t.idx] == '/') return error.BadToken;
                }
                const span = t.text[start..t.idx];
                const tag = if (m_symbol) |symbol| symbol else key_words.get(span) orelse .SYMBOL;
                return Tok(tag, t.text[start..t.idx], t.line);
            },
            '0' => {
                const start = t.idx;
                t.idx += 1;
                if (t.text[t.idx] == 'x' or t.text[t.idx] == 'X') {
                    t.idx += 1;
                    while (std.ascii.isHex(t.text[t.idx])) : (t.idx += 1) {}
                    return Tok(.NUMBER, t.text[start..t.idx], t.line);
                } else {
                    // TODO: Parser should reject integers starting with a 0.

                    // This is a hack, but it works.
                    t.idx -= 1;
                    continue :scan '1';
                }
            },
            '1'...'9' => {
                const start = t.idx;
                t.idx += 1;
                while ('0' <= t.text[t.idx] and t.text[t.idx] <= '9') : (t.idx += 1) {}
                var saw_n = false;
                if (t.text[t.idx] == 'N') {
                    t.idx += 1;
                    saw_n = true;
                } else if (t.text[t.idx] == '.') {
                    t.idx += 1;
                    const frac_start = t.idx;
                    while ('0' <= t.text[t.idx] and t.text[t.idx] <= '9') : (t.idx += 1) {}
                    if (frac_start == t.idx) return error.BadToken;
                }
                if (t.text[t.idx] == 'e' or t.text[t.idx] == 'E') {
                    t.idx += 1;
                    if (t.text[t.idx] == '+' or t.text[t.idx] == '-') t.idx += 1;
                    const exp_start = t.idx;
                    while ('0' <= t.text[t.idx] and t.text[t.idx] <= '9') : (t.idx += 1) {}
                    if (exp_start == t.idx) return error.BadToken;
                } // Absolutely not clear how 10NM should be parsed. Let's go with: 10N M. ¯\_(ツ)_/¯
                if (t.text[t.idx] == 'M' and !saw_n) t.idx += 1;
                return Tok(.NUMBER, t.text[start..t.idx], t.line);
            },
            '/' => {
                if (!symbolFollow(t.text[t.idx + 1])) {
                    defer t.idx += 1;
                    return Tok(.SYMBOL, t.text[t.idx..][0..1], t.line);
                } else {
                    return error.BadToken;
                }
            },
            '\\' => {
                // We need to recognize a little better here, but edn uses
                // weird stuff like \tab so we'll let the parser deal with
                // some kinds of malformation, since it needs to make this
                // into an atom and such.
                t.idx += 1;
                const start = t.idx;
                if (t.text[t.idx] == ' ') {
                    return error.BadToken;
                }
                while (std.ascii.isAlphanumeric(t.text[t.idx])) : (t.idx += 1) {}
                return Tok(.CHARACTER, t.text[start..t.idx], t.line);
            },
            ' ', '\t', '\n', ',' => |w| {
                if (w == '\n') t.line += 1;
                t.idx += 1;
                continue :scan t.text[t.idx];
            },
            ';' => {
                t.idx += 1;
                while (t.text[t.idx] != 0 and t.text[t.idx] != '\n') : (t.idx += 1) {}
                if (t.text[t.idx] == 0) return null;
                continue :scan t.text[t.idx];
            },
            0 => {
                return null;
            },
            else => {
                t.idx += 1; // No reason to loop forever here
                return error.BadToken;
            },
        }
    }

    inline fn symbolFollow(b: u8) bool {
        return switch (b) {
            '0'...'9',
            'a'...'z',
            'A'...'Z',
            '.',
            '*',
            '+',
            '!',
            ':',
            '#',
            '-',
            '_',
            '\'', // https://github.com/edn-format/edn/pull/89 (?)
            '?',
            '$',
            '%',
            '&',
            '=',
            '<',
            '>',
            => true,
            else => false,
        };
    }

    /// Just a hack to reuse reportError
    fn tokenForReport(t: *Tokenizer) Token {
        return Tok(.end_of_input, t[t.idx -| 1..t.idx], t.line);
    }

    /// Report an error at the Tokenizer's current code location.
    pub fn reportErrorHere(t: *Tokenizer, out: anytype, what: []const u8) !void {
        return t.reportError(out, t.tokenForReport(), what);
    }

    /// Print an error message identifying `tok` on its line.  Bad things will happen if
    /// the span of `tok` is not taken from this Tokenizer.
    pub fn reportError(t: *Tokenizer, out: anytype, tok: Token, what: []const u8) !void {
        const idx = tok.span.ptr - t.text.ptr;
        const l_end = std.mem.indexOfScalarPos(u8, t.text, idx, '\n') orelse t.text.len;
        const l_start = std.mem.lastIndexOfScalar(u8, t.text[0..idx], '\n') orelse 0;
        const l_off = idx - l_start;
        const line = t.text[l_start..l_end];
        try out.print("{d}:{d}: {s}\n", .{ tok.line, l_off, what });
        try out.print("{s}\n", .{line});
        try out.splatByteAll(' ', l_off);
        try out.writeAll("^\n");
    }
};

const std = @import("std");
const assert = std.debug.assert;
const isAlphanumeric = std.ascii.isAlphanumeric;
