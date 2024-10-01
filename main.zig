const std = @import("std");
const xor_list = @import("xor_list.zig");

pub fn main() !void {
    var gpa : std.heap.GeneralPurposeAllocator(.{}) = .init;
    var list = xor_list.init(i32, gpa.allocator());
    defer list.free();
    try list.append(3);
    try list.append(4);
    try list.append(5);
    try list.append(6);
    try list.append(9);
    try list.append(1);

    std.debug.print("My List: {any}\n", .{list});

    list.pop_last();

    std.debug.print("removed last from List: {any}\n", .{list});
    list.pop_first();
    std.debug.print("removed first from List: {any}\n", .{list});

    list.free();

    std.debug.print("freed List: {any}\n", .{list});
    

}
