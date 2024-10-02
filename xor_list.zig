const std = @import("std");
const expect = std.testing.expect;

pub fn init(comptime T: type, alloc : std.mem.Allocator) xor_list(T) {
    return xor_list(T).init(alloc);
}

pub fn xor_list(comptime T : type) type {
     return struct {
        const Self = @This();
        const xor_ptr = ?*xor_list_node;

        first : xor_ptr = null,
        last : xor_ptr = null,
        allocator : std.mem.Allocator,

        pub fn init(alloc : std.mem.Allocator) Self {
            return Self {
                .first = null,
                .last = null,
                .allocator = alloc,
            };
        }

        const xor_list_node = struct {
            val: T,
            ptr: xor_ptr,
        };

        fn ptouz(p : xor_ptr) usize {
            return if(p) |x| @intFromPtr(x) else 0;
        }

        fn next(a : xor_ptr, b : xor_ptr) xor_ptr {
            const u : usize = ptouz(a);
            const w : usize = ptouz(b);
            const xor = u ^ w;
            if(xor == 0) {return null;}
            return @ptrFromInt(u ^ w);
        }

        pub fn append(self : *Self, val : T) !void {
            const node_slice = try self.allocator.alloc(xor_list_node, 1);
            const node_ptr = &node_slice[0];

            node_ptr.val = val;

            if(self.last) |last| {
                std.debug.assert(self.first != null);
                const prev = next(last.ptr, null);
                std.debug.assert(prev != self.last);

                last.ptr = next(prev, node_ptr);
                std.debug.assert(next(last.ptr, prev) == node_ptr);
                std.debug.assert(next(last.ptr, node_ptr) == prev);
                node_ptr.ptr = next(self.last, null);
                std.debug.assert(next(node_ptr.ptr, null) == self.last);
                std.debug.assert(next(node_ptr.ptr, self.last) == null);
                self.last = node_ptr;

            }else{
                // first element
                std.debug.assert(self.first == null);
                node_ptr.ptr = next(null, null);
                self.first = node_ptr;
                self.last = node_ptr;
                std.debug.assert(next(node_ptr.ptr, null) == null);
            }
        }

        pub fn pop_last(self: *Self) void {
            std.debug.assert(self.first != null);
            std.debug.assert(self.last != null);

            if(self.last) |last| {
                const prev = next(last.ptr, null);
                if(prev) |p| {
                    p.ptr = next(next(p.ptr, self.last), null);
                    self.last = prev;
                }else{
                    self.first = null;
                    self.last = null;
                }
            }
        }

        pub fn pop_first(self: *Self) void {
            std.debug.assert(self.first != null);
            std.debug.assert(self.last != null);

            if(self.first) |first| {
                const nxt = next(first.ptr, null);
                if(nxt) |n| {
                    n.ptr = next(next(n.ptr, self.first), null);
                    self.first = n;
                }else{
                    self.first = null;
                    self.last = null;
                }
            }
        }



        pub fn free(self: *Self) void {
            while(self.first != null) {
                self.pop_last();
            }
        }

        pub const it = struct {
            prev : xor_ptr,
            curr : xor_ptr,

            fn next(self : *xor_list(T).it) ?*T {
                if(self.curr) |c| {
                    const n = Self.next(self.prev, c.ptr);
                    self.prev = self.curr;
                    self.curr = n;
                    return &c.val;
                }
                return null;
            }
        };

        pub const cit = struct {
            prev : ?*xor_list_node,
            curr : ?*xor_list_node,

            fn next(self : *xor_list(T).cit) ?*const T {
                if(self.curr) |c| {
                    const n = Self.next(self.prev, c.ptr);
                    self.prev = self.curr;
                    self.curr = n;
                    return &c.val;
                }
                return null;
            }

        };

        pub fn citer(self : *const Self) cit {
            return .{
                .prev = null,
                .curr = self.first
            };
        }


        pub fn iter(self : *Self) it {
            return .{
                .prev = null,
                .curr = self.first
            };
        }

        pub fn riter(self: *Self) it {
            return .{
                .prev = null,
                .curr = self.last
            };
        }

        pub fn format(self: *const Self, comptime _ : []const u8, _ : std.fmt.FormatOptions, writer: anytype) anyerror!void {
            var i = self.citer();
            try writer.print("[", .{});

            if(i.next()) |f| {
                try writer.print("{any}", .{f.*});
            }

            while(i.next()) |v| {
                try writer.print(", {any}", .{v.*});
            }
            return try writer.print("]", .{});
        }
    };
}

test "ptouz" {
    const list = xor_list(i32);
    const n : list.xor_ptr = null;
    var e : list.xor_list_node = undefined;
    const p : list.xor_ptr = &e;
    try expect(list.ptouz(n) == 0);
    try expect(list.ptouz(p) != 0);
}

test "trivial" {
    var v : i32 = 123;
    const ptr : ?*const i32 = &v;
    try expect(ptr != null);

    const addr_uz : usize = @intFromPtr(ptr);
    try expect(addr_uz != 0);
}

test "ptr_test" {
    const np : ?*i32 = null;
    try expect(np == null);
    if(np) |n| {
        _ = n;
        try expect(false);
    }else{
        try expect(true);
    }
    const v : i32 = 123;
    const p : ?*const i32 = &v;
    try expect(p != null);

    const bvv : usize = if(p)|cv| @intFromPtr(cv) else 0;
    try expect(bvv != 0);

    if(p) |ptr| {
        _ = ptr;
        try expect(true);
    }else{
        try expect(false);
    }

    const nv : usize = @intFromPtr(np);
    const vv : usize = if(p) |cv| @intFromPtr(cv) else 0;

    try expect(nv == 0);
    try expect(vv != 0);
}

test "empty_list" {
    var gpa : std.heap.GeneralPurposeAllocator(.{}) = .init;
    const list : xor_list(i32) = xor_list(i32).init(gpa.allocator());
    try expect(list.first == null);
    try expect(list.last == null);
}


test "one_elem" {
    var gpa : std.heap.GeneralPurposeAllocator(.{}) = .init;
    var list : xor_list(i32) = xor_list(i32).init(gpa.allocator());
    try list.append(3);

    try expect(list.first == list.last);
    try expect(list.last != null);
    if(list.first) |f| {
        try expect(f.val == 3);
        try expect(f.ptr == null);
    }
}

test "two_elem" {
    var gpa : std.heap.GeneralPurposeAllocator(.{}) = .init;
    const LT = xor_list(i32);
    var list : LT = LT.init(gpa.allocator());
    try list.append(3);
    try list.append(4);

    try expect(list.first != list.last);
    try expect(list.last != null);
    if(list.first) |f| {
        try expect(f.val == 3);
        try expect(f.ptr != null);
        if(f.ptr) |s| {
            try expect(s.val == 4);
            try expect(s.ptr != null);
        }
    }
}

test "longlist" {
    var gpa : std.heap.GeneralPurposeAllocator(.{}) = .init;
    const LT = xor_list(i32);
    var list : LT = LT.init(gpa.allocator());
    try list.append(3);
    try expect(list.first != null);
    try expect(list.last != null);
    try list.append(4);
    try list.append(5);

    try expect(list.first != null);
    try expect(list.last != null);

    if(list.first) |f| {
        try expect(f.val == 3);
        try expect(f.ptr != null);
        const second = LT.next(f.ptr, null);
        if(second) |s| {
            try expect(s.val == 4);
            try expect(s.ptr != null);
            const third = LT.next(s.ptr, list.first);

            if(third) |t| {
                try expect(t.val == 5);
                try expect(t.ptr != null);
                try expect(LT.next(t.ptr, second) == null);
            }
        }

    }
}


