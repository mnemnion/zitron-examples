//! Main Executable of zitron-examples
const std = @import("std");

test "exe mentioned" {
    std.debug.print("hello from zitron-examples main\n", .{});
}


pub fn main() void {
    std.debug.print("zitron-examples for great justice!\n", .{});
    std.process.exit(0);
}
