const std = @import("std");
const testing = std.testing;

const Allocator = std.mem.Allocator;
const File = std.fs.File;

const string = []const u8;

const Foreground = struct {
    pub const Black = "\x1b[30m";
    pub const Red = "\x1b[31m";
    pub const Green = "\x1b[32m";
    pub const Yellow = "\x1b[33m";
    pub const Blue = "\x1b[34m";
    pub const Magenta = "\x1b[35m";
    pub const Cyan = "\x1b[36m";
    pub const White = "\x1b[37m";
};

const Background = struct {
    pub const Black = "\x1b[40m";
    pub const Red = "\x1b[41m";
    pub const Green = "\x1b[42m";
    pub const Yellow = "\x1b[43m";
    pub const Blue = "\x1b[44m";
    pub const Magenta = "\x1b[45m";
    pub const Cyan = "\x1b[46m";
    pub const White = "\x1b[47m";
};

pub const Color = struct {
    pub const FG = Foreground;
    pub const BG = Background;

    pub const Clear = "\x1b[0m";
    pub const Transparent = "\x1b[8m";
};

fn sleep(ms: u64) void {
    std.time.sleep(std.time.ns_per_ms * ms);
}

pub const Progrezzbar = struct {
    allocator: Allocator,
    width: u32,
    character: string = "█",
    message: ?string,
    end_message: ?string,
    show_percentage: bool = false,
    color: string = Color.Clear,

    pub fn init(
        allocator: Allocator,
        width: u32,
        character: ?string,
        message: ?string,
        end_message: ?string,
        show_percentage: bool,
        color: ?string,
    ) Progrezzbar {
        return .{
            .allocator = allocator,
            .width = width,
            .character = if (character == null) "█" else character.?,
            .message = message,
            .end_message = end_message,
            .show_percentage = show_percentage,
            .color = if (color == null) Color.Clear else color.?,
        };
    }

    pub fn run(self: *Progrezzbar) !void {
        var _self = self.*;
        const stdout = std.io.getStdOut();

        var chars = try _self.allocator.alloc(string, _self.width);
        defer _self.allocator.free(chars);
        @memset(chars, try std.fmt.allocPrint(_self.allocator, "{s}{s}", .{ Color.Transparent, _self.character }));

        try stdout.writer().print("{s}\n", .{try std.mem.join(_self.allocator, "", chars)});

        for (chars, 0..) |_, i| {
            chars[i] = try std.fmt.allocPrint(_self.allocator, "{s}{s}", .{ _self.color, _self.character });

            if (_self.show_percentage) {
                try _self.updateWithPercent(stdout, chars, i + 1);
            } else {
                try _self.update(stdout, chars);
            }

            sleep(80);
        }

        sleep(100);
        try stdout.writer().print("\x1b[A\x1b[K{s}", .{Color.Clear});

        if (_self.end_message) |message| {
            try stdout.writer().print("{s}{s}{s}\n", .{ Color.FG.Green, message, Color.Clear });
        }
    }

    fn update(self: Progrezzbar, stdout: File, chars: []string) !void {
        try stdout.writer().print("\x1b[A\x1b[K{s}", .{Color.Clear});

        if (self.message) |message| {
            try stdout.writer().print("{s} ", .{message});
        }

        try stdout.writer().print("{s}", .{try std.mem.join(self.allocator, "", chars)});
        try stdout.writer().print("{s}\n", .{Color.Clear});
    }

    fn updateWithPercent(self: Progrezzbar, stdout: File, chars: []string, index: usize) !void {
        const percent = @as(f32, @floatFromInt(index)) / @as(f32, @floatFromInt(self.width)) * 100;

        try stdout.writer().print("\x1b[A\x1b[K{s}", .{Color.Clear});
        if (self.message) |message| {
            try stdout.writer().print("{s} ", .{message});
        }

        try stdout.writer().print("{s}{s} {d:.0}%", .{ try std.mem.join(self.allocator, "", chars), Color.Clear, percent });
        try stdout.writer().print("{s}\n", .{Color.Clear});
    }
};

test "no percent, no message, no end message" {
    const allocator = std.heap.page_allocator;
    var p = Progrezzbar.init(allocator, 25, null, null, null, false, Color.Clear);
    try p.run();
}

test "no percent, no message, end message" {
    const allocator = std.heap.page_allocator;
    var p = Progrezzbar.init(allocator, 25, null, null, "End Message", false, Color.Clear);
    try p.run();
}

test "no percent, message, end message" {
    const allocator = std.heap.page_allocator;
    var p = Progrezzbar.init(allocator, 25, null, "Test Message", "End Message", false, Color.Clear);
    try p.run();
}

test "percent, no message, no end message" {
    const allocator = std.heap.page_allocator;
    var p = Progrezzbar.init(allocator, 25, null, null, null, true, Color.Clear);
    try p.run();
}

test "percent, no message, end message" {
    const allocator = std.heap.page_allocator;
    var p = Progrezzbar.init(allocator, 25, null, null, "End Message", true, Color.Clear);
    try p.run();
}

test "percent, message, end message" {
    const allocator = std.heap.page_allocator;
    var p = Progrezzbar.init(allocator, 25, null, "Test Message", "End Message", true, Color.Clear);
    try p.run();
}

test "custom char, no percent" {
    const allocator = std.heap.page_allocator;
    var p = Progrezzbar.init(allocator, 25, "#", "Test Message", "End Message", false, Color.Clear);
    try p.run();
}

test "custom char, percent" {
    const allocator = std.heap.page_allocator;
    var p = Progrezzbar.init(allocator, 25, "#", "Test Message", "End Message", true, Color.Clear);
    try p.run();
}
