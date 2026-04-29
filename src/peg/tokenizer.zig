//! PEG Tokenizer

// Blah Blah Tokens
pub const TokenKind = enum {
    end_of_input,
    QMARK,
    NOT,
    ARROW,
    ALT,
    PEL,
    PER,
    SQL,
    SQR,
    AND,
    STAR,
    PLUS,
    POW,
    S_STRING,
    D_STRING,
    ID,
};

pub const StringKind = enum {
    sentinel,
    slice,
};

pub const Token = struct {
    kind: TokenKind,
    ptr: [*]const u8,
    len: u32,

    pub fn slice(t: *const Token) []const u8 {
        return t.ptr[0..t.len];
    }
};

pub fn Tokenizer(which: StringKind) type {
    const Str = if (which == .sentinel) [:0]const u8 else []const u8;
    return struct {
        text: Str,
        idx: usize = 0,

        const Toker = @This();

        pub fn init(text: Str) Toker {
            return .{ .text = text };
        }

        pub fn next(t: *Toker) !?Token {
            switch (t.at()) {
                '?' => return t.byLen(.QMARK, 1),
                '!' => return t.byLen(.NOT, 1),
                '/' => return t.byLen(.ALT, 1),
                '*' => return t.byLen(.STAR, 1),
                '+' => return t.byLen(.PLUS, 1),
                '(' => return t.byLen(.PEL, 1),
                ')' => return t.byLen(.PER, 1),
                '[' => return t.byLen(.SQL, 1),
                ']' => return t.byLen(.SQR, 1),
                '&' => return t.byLen(.AND, 1),
                '^' => return t.byLen(.POW, 1),
                '<' => {
                    if (t.l1('-')) {
                        return t.byLen(.ARROW, 2);
                    }
                    return error.BadToken;
                },
                '"' => {
                    const start = t.idx;
                    t.idx += 1;
                    while (t.at() != '\n' and
                        t.at() != 0 and
                        t.at() != '"') : (t.idx += 1)
                    {
                        if (t.eq('\\')) t.idx += 1;
                    }
                    if (t.eq('"')) {
                        t.idx += 1;
                        return .{
                            .kind = .D_STRING,
                            .ptr = t.text[start],
                            .len = t.idx - start,
                        };
                    } else {
                        return error.BadToken;
                    }
                },
                '\'' => {
                    // Shell-style single quoted strings
                    const start = t.idx;
                    t.idx += 1;
                    while (t.at() != 0) : (t.idx += 1) {
                        if (t.eq('\'')) {
                            if (t.l1('\'')) {
                                t.idx += 1;
                            } else {
                                break;
                            }
                        }
                    }
                    if (t.eq('\'')) {
                        t.idx += 1;
                        return .{
                            .kind = .D_STRING,
                            .ptr = t.text[start],
                            .len = t.idx - start,
                        };
                    } else {
                        return error.BadToken;
                    }
                },
            }
        }

        fn byLen(tok: *const Toker, kind: TokenKind, len: usize) Token {
            defer tok.idx += len;
            return .{ .kind = kind, .ptr = &tok.text[tok.idx], .len = len };
        }

        inline fn eq(tok: *const Toker, b: u8) bool {
            return tok.at() == b;
        }

        inline fn l1(tok: *const Toker, look: u8) bool {
            if (comptime which == .slice) {
                if (tok.idx == tok.text.len) return false;
            }
            return tok.text[tok.idx + 1] == look;
        }

        inline fn at(tok: *const Toker) u8 {
            assert(tok.idx <= tok.len);
            if (comptime which == .slice) {
                if (tok.idx == tok.text.len) return 0;
            }
            return tok.text[tok.at];
        }
    };
}

const std = @import("std");
const assert = std.debug.assert;
