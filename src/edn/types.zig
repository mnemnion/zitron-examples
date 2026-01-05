//! Types for edn.zig example project

pub const Atom = union(enum(u8)) {
    boolean: bool,
    number: f64,
    nil: void = {},
    symbol: []const u8,
    character: u21,
    keyword: Keyword,
    string: []const u8,

    pub fn new(t: Token, allocator: Allocator) !Atom {
        return switch (t.kind) {
            .TRUE => .{ .boolean = true },
            .FALSE => .{ .boolean = false },
            .NUMBER => .{ .number = std.fmt.parseFloat(u64, t.span) catch unreachable },
            .NIL => .nil,
            .SYMBOL => .{ .symbol = t.span },
            .CHARACTER => char: {
                break :char .nil; // TODO:
            },
            .KEYWORD => try Keyword.new(t, allocator),
            // TODO: escapes and such
            .STRING => .{ .string = try allocator.dupe(u8, t.span[1 .. t.len - 2]) },
            else => unreachable,
        };
    }

    pub fn deinit(atom: *Atom, allocator: Allocator) void {
        switch (atom.*) {
            .boolean, .number, .nil, .character => {},
            inline .symbol, .string => |sym| allocator.free(sym),
            .keyword => |kw| allocator.free(kw.symbol),
        }
    }
};

pub const AtomKind = std.meta.Tag(Atom);
pub const FormKind = std.meta.Tag(Form);

pub const Set = std.AutoHashMapUnmanaged(Form, void);
pub const Map = std.AutoHashMapUnmanaged(Form, Form);
pub const Vector = std.ArrayList(Form);
pub const List = std.ArrayList(Form);

pub const Form = union(enum(u8)) {
    atom: Atom,
    set: Set,
    map: Map,
    vector: Vector,
    list: List,

    pub fn new(val: anytype) Form {
        const V = @TypeOf(val);
        if (V == Atom) {
            return .{ .atom = val };
        } else if (V == Set) {
            return .{ .set = val };
        } else if (V == Map) {
            return .{ .map = val };
        } else if (V == Vector) {
            return .{ .vector = val };
        } else if (V == List) {
            return .{ .list = val };
        } else @compileError("Cannot make a Form from a " ++ @typeName(V) ++ ".");
    }

    pub fn deinit(form: *Form, allocator: Allocator) void {
        switch (form.*) {
            inline .vector, .list => |*alist| {
                for (alist.items) |f| {
                    f.deinit(allocator);
                }
                alist.deinit(allocator);
            },
            .set => |*s| {
                var key_iter = s.keyIterator();
                while (key_iter.next()) |elem| {
                    elem.deinit(allocator);
                }
                s.deinit(allocator);
            },
            .map => |*map| {
                var iter = map.iterator();
                while (iter.next()) |pair| {
                    pair.key_ptr.deinit(allocator);
                    pair.value_ptr.deinit(allocator);
                }
                map.deinit(allocator);
            },
            .atom => |atom| {
                atom.deinit(allocator);
            },
        }
    }
};

pub const Keyword = struct {
    symbol: []const u8,

    pub fn new(t: Token, allocator: Allocator) !Keyword {
        assert(t.span[0] == ':');
        return .{ .symbol = try allocator.dupe(u8, t.span[1..]) };
    }
};

pub const FormCons = struct {
    form: Form,
    next: ?*FormCons,

    pub fn cons(car: *FormCons, cdr: *FormCons) *FormCons {
        car.next = cdr;
        return car;
    }

    pub fn reverse(car: *FormCons) *FormCons {
        var m_next = car.next;
        var prev = car;
        prev.next = null;
        while (m_next) |next| {
            const next_next = next.next;
            next.next = prev;
            if (next_next) |_| {
                m_next = next_next;
                prev = next;
            } else {
                return next;
            }
        }
        return car;
    }
};

const std = @import("std");
const Allocator = std.mem.Allocator;
const assert = std.debug.assert;
const tokenizer = @import("tokenize.zig");
const Token = tokenizer.Token;
