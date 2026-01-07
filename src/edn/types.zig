//! Types for edn.zig example project

pub const Atom = union(enum(u8)) {
    boolean: bool,
    number: f64,
    nil: void,
    symbol: []const u8,
    character: u21,
    keyword: Keyword,
    string: []const u8,

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
            .STRING => new_atom.* = .{ .string = try allocator.dupe(u8, t.span[1 .. t.span.len - 2]) },
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
    list: *FormCons,

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
        } else if (V == *FormCons) {
            return .{ .list = val };
        } else @compileError("Cannot make a Form from a " ++ @typeName(V) ++ ".");
    }

    pub fn deinit(form: Form, allocator: Allocator) void {
        _ = .{ form, allocator };
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
            .atom => |atom| {
                atom.destroy(allocator);
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

    pub fn create(allocator: Allocator, form: Form) !*FormCons {
        var car = try allocator.create(FormCons);
        car.form = form;
        car.next = null;
        return car;
    }

    pub fn cons(car: *FormCons, cdr: *FormCons) *FormCons {
        car.next = cdr;
        return car;
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
