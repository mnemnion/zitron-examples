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
            .SYMBOL => new_atom.* = .{ .symbol = try allocator.dupe(u8, t.span) },
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

pub const Set = std.ArrayHashMapUnmanaged(Form, void, Context, true);
pub const Map = std.ArrayHashMapUnmanaged(Form, Form, Context, true);
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

    pub fn format(form: Form, writer: *std.Io.Writer) !void {
        switch (form) {
            .nil => try writer.writeAll("∅"),
            .set => |set| {
                try writer.writeAll("#{");
                const keys = set.keys();
                for (keys) |key| {
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

    pub fn deinit(form: Form, allocator: Allocator) void {
        switch (form) {
            .vector => |alist| {
                for (alist.items) |f| {
                    f.deinit(allocator);
                }
                alist.deinit(allocator);
                allocator.destroy(alist);
            },
            .list => |m_car| {
                if (m_car) |car| car.deinit(allocator);
            },
            .set => |set| {
                const elems = set.keys();
                for (elems) |elem| {
                    elem.deinit(allocator);
                }
                set.deinit(allocator);
                allocator.destroy(set);
            },
            .map => |map| {
                var iter = map.iterator();
                while (iter.next()) |pair| {
                    pair.key_ptr.deinit(allocator);
                    pair.value_ptr.deinit(allocator);
                }
                map.deinit(allocator);
                allocator.destroy(map);
            },
            .tagged => |tagged| tagged.destroy(allocator),
            .atom => |atom| {
                atom.destroy(allocator);
            },
            .nil => {},
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
        try writer.print("«#{s} {f}»", .{ tag.symbol, tag.form });
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

//| Hash context
//|
//| Note that this does not in fact provide edn-equivalent hash equality.  This
//| version considers #{:foo :baz :bar} to be different from #{:foo :bar: baz},
//| which is wrong.  Ultimately this is simply using the wrong data structure.
//|
//| Important note: this **only works** because a parser is unable to generate
//| cycles.  Any subsequent mutation of these structures which creates a cycle
//| **will** stack overflow.
//|
//| Note that this _could_ be fixed.  Every pointer in the collection is either
//| a string-slice, and those can't have cycles, or is word-aligned.  So the
//| physical pointer could be mutated, by setting the bit to 1, then followed
//| in its original state.  Each pointer encountered must then be checked for
//| this condition, and if it is in that condition, either hash or take equality
//| of the pointer itself.  Of course deferring a re-mutation of every followed
//| pointer to its original state.
//|
//| As it stands I have very little interest in doing this.  "Works on my machine".

const equal = struct {
    const activeTag = std.meta.activeTag;

    pub fn form(f1: *const Form, f2: *const Form) bool {
        if (activeTag(f1.*) != activeTag(f2.*)) return false;
        return switch (f1.*) {
            .nil => true,
            .atom => |f1a| equal.atom(f1a, f2.atom),
            .set => |f1s| equal.set(f1s, f2.set),
            .map => |f1m| equal.map(f1m, f2.map),
            .vector => |f1v| equal.vector(f1v, f2.vector),
            .list => |f1l| equal.list(f1l, f2.list),
            .tagged => |f1tag| equal.tagged(f1tag, f2.tagged),
        };
    }

    pub fn atom(a1: *const Atom, a2: *const Atom) bool {
        if (activeTag(a1.*) != activeTag(a2.*)) return false;
        return switch (a1.*) {
            .nil => true,
            inline .boolean, .number, .character => |lit, tag| lit == @field(a2.*, @tagName(tag)),
            inline .string, .symbol => |slice, tag| std.mem.eql(u8, slice, @field(a2.*, @tagName(tag))),
            .keyword => |key| std.mem.eql(u8, key.symbol, a2.keyword.symbol),
        };
    }

    pub fn list(l1: ?*const FormCons, l2: ?*const FormCons) bool {
        var m_l1 = l1;
        var m_l2 = l2;
        while (m_l1) |list1| : (m_l1 = list1.next) {
            if (m_l2) |list2| {
                if (!equal.form(&list1.form, &list2.form)) return false;
                m_l2 = list2.next;
            } else return false;
        } else return true;
    }

    pub fn set(s1: *const Set, s2: *const Set) bool {
        if (s1.count() != s2.count()) return false;
        const s1k = s1.keys();
        const s2k = s2.keys();
        for (s1k, s2k) |*f1, *f2| {
            if (!equal.form(f1, f2)) return false;
        }
        return true;
    }

    pub fn map(m1: *const Map, m2: *const Map) bool {
        if (m1.count() != m2.count()) return false;
        const m1k = m1.keys();
        const m1v = m1.values();
        const m2k = m2.keys();
        const m2v = m2.values();
        for (m1k, m2k, m1v, m2v) |*k1, *k2, *v1, *v2| {
            if (!equal.form(k1, k2)) return false;
            if (!equal.form(v1, v2)) return false;
        }
        return true;
    }

    pub fn vector(v1: *const Vector, v2: *const Vector) bool {
        const v1s = v1.items;
        const v2s = v2.items;
        if (v1s.len != v2s.len) return false;
        for (v1s, v2s) |*f1, *f2| {
            if (!equal.form(f1, f2)) return false;
        }
        return true;
    }

    pub fn tagged(t1: *const Tagged, t2: *const Tagged) bool {
        if (!std.mem.eql(u8, t1.symbol, t2.symbol)) return false;
        return equal.form(&t1.form, &t2.form);
    }
};

const Hash = struct {
    pub fn form(hasher: anytype, a_form: *const Form) void {
        const b = @intFromEnum(std.meta.activeTag(a_form.*));
        hasher.update(&.{b});
        switch (a_form.*) {
            .nil => {},
            .atom => |f1a| Hash.atom(hasher, f1a),
            .set => |f1s| Hash.set(hasher, f1s),
            .map => |f1m| Hash.map(hasher, f1m),
            .vector => |f1v| Hash.vector(hasher, f1v),
            .list => |f1l| Hash.list(hasher, f1l),
            .tagged => |f1tag| Hash.tagged(hasher, f1tag),
        }
    }

    pub fn atom(hasher: anytype, an_atom: *const Atom) void {
        const b = @intFromEnum(std.meta.activeTag(an_atom.*));
        hasher.update(&.{b});
        switch (an_atom.*) {
            .nil => {},
            inline .number, .character, .boolean => |v| hasher.update(std.mem.asBytes(&v)),
            inline .string, .symbol => |slice| hasher.update(slice),
            .keyword => |key| hasher.update(key.symbol),
        }
    }

    pub fn list(hasher: anytype, a_list: ?*const FormCons) void {
        var m_l1 = a_list;
        while (m_l1) |list1| : (m_l1 = list1.next) {
            Hash.form(hasher, &list1.form);
        }
    }

    pub fn set(hasher: anytype, a_set: *const Set) void {
        const set_keys = a_set.keys();
        for (set_keys) |*elem| {
            Hash.form(hasher, elem);
        }
    }

    pub fn map(hasher: anytype, a_map: *const Map) void {
        const m1k = a_map.keys();
        const m1v = a_map.values();
        for (m1k, m1v) |*key, *val| {
            Hash.form(hasher, key);
            Hash.form(hasher, val);
        }
    }

    pub fn vector(hasher: anytype, a_vector: *const Vector) void {
        for (a_vector.items) |*f| {
            Hash.form(hasher, f);
        }
    }

    pub fn tagged(hasher: anytype, a_tagged: *const Tagged) void {
        hasher.update(a_tagged.symbol);
        Hash.form(hasher, &a_tagged.form);
    }
};

const Context = struct {
    pub fn eql(_: Context, f1: Form, f2: Form, _: usize) bool {
        return equal.form(&f1, &f2);
    }

    pub fn hash(_: Context, form: Form) u32 {
        var hasher = std.hash.Wyhash.init(0);
        Hash.form(&hasher, &form);
        return @truncate(hasher.final());
    }
};

const std = @import("std");
const Allocator = std.mem.Allocator;
const assert = std.debug.assert;
const tokenizer = @import("tokenize.zig");
const Token = tokenizer.Token;
