const std = @import("std");
const assert = std.debug.assert;
const mvzr = @import("mvzr.zig");
const zgrep = @import("zgrep");

pub fn main() !void {
    var debug_allocator: std.heap.DebugAllocator(.{}) = .init;
    defer assert(debug_allocator.deinit() == .ok);
    const gpa = debug_allocator.allocator();

    var args = try std.process.argsWithAllocator(gpa);
    defer args.deinit();

    _ = args.skip();

    const pattern = args.next() orelse return error.NoPattern;

    const regex: mvzr.Regex = mvzr.compile(pattern) orelse return error.BadPattern;

    const file = args.next();

    var source: std.fs.File = undefined;

    var opened_file = false;
    if (file) | f| {
        source = try std.fs.cwd().openFile(f, .{});
        opened_file = true;
    }else {
        source =  std.fs.File.stdin();
    }

    var read_buf: [100]u8 = undefined;
    var reader = source.reader(&read_buf);

    var stdout_buf: [1024]u8 = undefined;
    const stdout_file = std.fs.File.stdout();
    var stdout = stdout_file.writer(&stdout_buf);

    var writer = std.Io.Writer.Allocating.init(gpa);
    defer writer.deinit();

    while (true) {
        if (reader.interface.streamDelimiter(&writer.writer, '\n')) | _ | {
            const line = writer.written();
            if (regex.isMatch(line)) {
                try stdout.interface.print("{s}\n", .{line});
            }
            writer.clearRetainingCapacity();
            reader.interface.toss(1);
        }else |err| switch (err) {
            error.EndOfStream => {
                break;
            },
            else => {
                return err;
            },
        }
    }

    try stdout.interface.flush();

    if (opened_file) {
        source.close();
    }

}

