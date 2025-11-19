//! Prolog tokenizer

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

pub const Tokenizer = struct {
    text: [:0]const u8,
    idx: usize = 0,
    line: usize = 1,

    pub fn next(t: Tokenizer) error{BadToken}!?Token {
        scan: switch (t.text[t.idx]) {
            '(' => {
                const end = t.idx + 1;
                defer t.idx = end;
                return Tok(.PAL, t.text[t.idx..end], t.line);
            },
            ')' => {
                const end = t.idx + 1;
                defer t.idx = end;
                return Tok(.PAR, t.text[t.idx..end], t.line);
            },
            '.' => {
                const end = t.idx + 1;
                defer t.idx = end;
                return Tok(.DOT, t.text[t.idx..end], t.line);
            },
            ',' => {
                const end = t.idx + 1;
                defer t.idx = end;
                return Tok(.DOT, t.text[t.idx..end], t.line);
            },
            ':' => {
                if (t.text[t.idx + 1] == '-') {
                    const end = t.idx + 2;
                    defer t.idx = end;
                    return Tok(.ISA, t.text[t.idx..end], t.line);
                } else {
                    return error.BadToken;
                }
            },
            '-' => {
                if (t.text[t.idx + 1] == '?') {
                    const end = t.idx + 2;
                    defer t.idx = end;
                    return Tok(.WHAT, t.text[t.idx..end], t.line);
                } else {
                    // Probably this is minus actually...
                    return error.BadToken;
                }
            },
            '\'' => {
                // Why not do it sh style?
                const start = t.idx;
                t.idx += 1;
                while (t.text[t.idx] != '\n' and
                    t.text[t.idx] != 0 and
                    (t.text[t.idx] != '\'' and t.text[t.idx + 1] != '\'')) : (t.idx += 1)
                { // Only happens if we see '':
                    if (t.text[t.idx == '\'']) {
                        assert(t.text[t.idx + 1] == '\'');
                        t.idx += 1;
                    }
                }
                if (t.text == '\'') {
                    t.idx += 1;
                    return Tok(.SINGLE_STRING, t.text[start..t.idx], t.line);
                } else {
                    return error.BadToken;
                }
            },
            'a'...'z' => {
                const start = t.idx;
                t.idx += 1;
                while (isAlphanumeric(t.text[t.idx]) or t.text[t.idx] == '_') : (t.idx += 1) {}
                t.idx += 1;
                return Tok(.SYMBOL, t.text[start..t.idx], t.line);
            },
            'A'...'Z' => {
                const start = t.idx;
                t.idx += 1;
                while (std.ascii.isAlphanumeric(t.text[t.idx]) or t.text[t.idx] == '_') : (t.idx += 1) {}
                t.idx += 1;
                return Tok(.VARIABLE, t.text[start..t.idx], t.line);
            },
            '0' => {
                const start = t.idx;
                t.idx += 1;
                if (t.text[t.idx] == 'x' or t.text[t.idx] == 'X') {
                    t.idx += 1;
                    while (std.ascii.isHex(t.text[t.idx])) : (t.idx += 1) {}
                    t.idx += 1;
                    return Tok(.NUMBER, t.text[start..t.idx], t.line);
                } else {
                    // This is a hack, but it works.
                    t.idx -= 1;
                    continue :scan '1';
                }
            },
            '1'...'9' => {
                const start = t.idx;
                t.idx += 1;
                while ('0' <= t.text[t.idx] and t.text[t.idx] <= '9') : (t.idx += 1) {}
                if (t.text[t.idx] == '.') {
                    t.idx += 1;
                    while ('0' <= t.text[t.idx] and t.text[t.idx] <= '9') : (t.idx += 1) {}
                }
                if (t.text[t.idx] == 'e' or t.text[t.idx] == 'E') {
                    t.idx += 1;
                    while ('0' <= t.text[t.idx] and t.text[t.idx] <= '9') : (t.idx += 1) {}
                }
                t.idx += 1;
                return Tok(.NUMBER, t.text[start..t.idx], t.line);
            },
            ' ', '\t', '\n' => |w| {
                if (w == '\n') t.line += 1;
                t.idx += 1;
                continue :scan t.text[t.idx];
            },
            0 => return null,
            else => {
                t.idx += 1; // No reason to loop forever here
                return error.BadToken;
            },
        }
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
