//! Types for edn.zig example project

pub const Atom = union(enum(u8)) {
    boolean: bool,
    number: f64,
    nil: void,
    symbol: []const u8,
    character: u21,
    keyword: Keyword,
    string: []const u8,

    pub const the_nil: Atom = .nil;

    pub fn new(t: Token, allocator: Allocator) !*Atom {
        const new_atom = try allocator.create(Atom);
        switch (t.kind) {
            .TRUE => new_atom.* = .{ .boolean = true },
            .FALSE => new_atom.* = .{ .boolean = false },
            .NUMBER => new_atom.* = .{ .number = std.fmt.parseFloat(f64, t.span) catch unreachable },
            .NIL => new_atom.* = .nil,
            .SYMBOL => new_atom.* = .{ .symbol = t.span },
            .CHARACTER => new_atom.* = char: {
                break :char .nil; // TODO:
            },
            .KEYWORD => new_atom.* = .{ .keyword = try Keyword.new(t, allocator) },
            // TODO: escapes and such
            .STRING => {
                const str = try std.zig.string_literal.parseAlloc(allocator, t.span);
                new_atom.* = .{ .string = str };
            },
            else => unreachable,
        }
        return new_atom;
    }

    pub fn destroy(atom: *Atom, allocator: Allocator) void {
        switch (atom.*) {
            .boolean, .number, .nil, .character => {},
            inline .symbol, .string => |sym| allocator.free(sym),
            .keyword => |kw| allocator.free(kw.symbol),
        }
        allocator.destroy(atom);
    }

    pub fn format(atom: *const Atom, writer: *std.Io.Writer) !void {
        switch (atom.*) {
            .symbol => |s| try writer.writeAll(s),
            .number => |n| try writer.print("{d}", .{n}),
            .keyword => |k| try writer.print("{f}", .{k}),
            .string => |s| try writer.print("\"{s}\"", .{s}),
            .nil => try writer.writeAll("∅"),
            .boolean => |b| try writer.print("`{any}`", .{b}),
            else => try writer.writeAll("more atoms"),
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
    atom: *Atom,
    set: *Set,
    map: *Map,
    vector: *Vector,
    list: ?*FormCons,
    tagged: *Tagged,
    nil,

    pub fn new(val: anytype) Form {
        const V = @TypeOf(val);
        if (V == *Atom) {
            return .{ .atom = val };
        } else if (V == *Set) {
            return .{ .set = val };
        } else if (V == *Map) {
            return .{ .map = val };
        } else if (V == *Vector) {
            return .{ .vector = val };
        } else if (V == ?*FormCons or V == *FormCons) {
            return .{ .list = val };
        } else if (V == *Tagged) {
            return .{ .tagged = val };
        } else if (V == @TypeOf(null)) {
            // This is a bit of 'type punning', but list is our
            // only optional type (in Form), so it's ok.  Or at least, I
            // can get away with it.
            return .{ .list = null };
        } else @compileError("Cannot make a Form from a " ++ @typeName(V) ++ ".");
    }

    pub fn deinit(form: Form, allocator: Allocator) void {
        _ = .{ form, allocator };
    }

    pub fn format(form: Form, writer: *std.Io.Writer) !void {
        switch (form) {
            .nil => try writer.writeAll("∅"),
            .set => |set| {
                try writer.writeAll("#{");
                var key_iter = set.keyIterator();
                while (key_iter.next()) |key| {
                    try writer.print(" {f}", .{key});
                }
                try writer.writeAll(" }");
            },
            .vector => |vec| {
                try writer.writeByte('[');
                for (vec.items, 0..) |item, i| {
                    try writer.print("{f}", .{item});
                    if (i < vec.items.len - 1) {
                        try writer.writeByte(' ');
                    }
                }
                try writer.writeByte(']');
            },
            .map => |map| {
                try writer.writeByte('{');
                var key_iter = map.iterator();
                while (key_iter.next()) |elem| {
                    try writer.print(" {f} {f} ", .{ elem.key_ptr, elem.value_ptr });
                }
                try writer.writeByte('}');
            },
            .list => |m_l| {
                if (m_l) |l| {
                    try writer.print("{f}", .{l});
                } else {
                    try writer.writeAll("()");
                }
            },
            .tagged => |t| try writer.print("{f}", .{t}),
            .atom => |a| try writer.print("{f}", .{a}),
        }
    }

    pub fn deinit1(form: Form, allocator: Allocator) void {
        switch (form) {
            .vector => |alist| {
                for (alist.items) |f| {
                    f.deinit(allocator);
                }
                alist.deinit(allocator);
            },
            .list => |car| {
                car.deinit(allocator);
            },
            .set => |s| {
                var key_iter = s.keyIterator();
                while (key_iter.next()) |elem| {
                    elem.deinit(allocator);
                }
                s.deinit(allocator);
            },
            .map => |map| {
                var iter = map.iterator();
                while (iter.next()) |pair| {
                    pair.key_ptr.deinit(allocator);
                    pair.value_ptr.deinit(allocator);
                }
                map.deinit(allocator);
            },
            .tagged => |tagged| tagged.destroy(allocator),
            .atom => |atom| {
                atom.destroy(allocator);
            },
        }
    }
};

pub const Pair = struct {
    key: Form,
    value: Form,

    pub fn create(allocator: Allocator, key: Form, value: Form) !*Pair {
        const new_pair = try allocator.create(Pair);
        new_pair.key = key;
        new_pair.value = value;
        return new_pair;
    }

    pub fn destroy(pair: *Pair, allocator: Allocator) void {
        pair.key.deinit(allocator);
        pair.value.deinit(allocator);
        allocator.destroy(pair);
    }
    pub fn format(pair: *const Pair, writer: anytype) !void {
        try writer.print("{f},{f}", .{ pair.key, pair.value });
    }
};

pub const Keyword = struct {
    symbol: []const u8,

    pub fn format(k: *const Keyword, writer: anytype) !void {
        try writer.print(":{s}", .{k.symbol});
    }

    pub fn new(t: Token, allocator: Allocator) !Keyword {
        assert(t.span[0] == ':');
        return .{ .symbol = try allocator.dupe(u8, t.span[1..]) };
    }
};

pub const Tagged = struct {
    symbol: []const u8,
    form: Form,

    pub fn new(allocator: Allocator, tag: *const Token, form: *const Form) !*Tagged {
        const tag_p = try allocator.create(Tagged);
        errdefer allocator.destroy(tag_p);
        tag_p.symbol = try allocator.dupe(u8, tag.span[1..]);
        tag_p.form = form.*;
        return tag_p;
    }

    pub fn format(tag: *const Tagged, writer: *std.Io.Writer) !void {
        try writer.print("#{s} ({f})", .{ tag.symbol, tag.form });
    }

    pub fn destroy(tag: *Tagged, allocator: Allocator) void {
        tag.form.deinit(allocator);
        allocator.free(tag.symbol);
        allocator.destroy(tag);
    }
};

pub const FormCons = struct {
    form: Form,
    next: ?*FormCons,

    pub const empty: FormCons = .{ .form = .nil, .next = null };

    pub fn create(allocator: Allocator, form: Form) !*FormCons {
        var car = try allocator.create(FormCons);
        car.form = form;
        car.next = null;
        return car;
    }

    pub fn cons(car: *FormCons, cdr: ?*FormCons) void {
        car.next = cdr;
    }

    pub fn format(car: *FormCons, writer: *std.Io.Writer) !void {
        var next: ?*FormCons = car;
        try writer.writeByte('(');
        while (next) |this| : (next = this.next) {
            try writer.print("{f}", .{this.form});
            if (this.next) |_| try writer.writeAll(", ");
        }
        try writer.writeByte(')');
    }

    pub fn deinit(car: *FormCons, allocator: Allocator) void {
        var next: ?*FormCons = car;
        while (next) |this| {
            next = this.next;
            this.form.deinit(allocator);
            allocator.destroy(this);
        }
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
