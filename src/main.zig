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

    var stdout_buf: [1024]u8 = undefined;
    const stdout_file = std.fs.File.stdout();
    var stdout = stdout_file.writer(&stdout_buf);

    var writer = std.Io.Writer.Allocating.init(gpa);
    defer writer.deinit();

    var files = try std.ArrayList([:0]const u8).initCapacity(gpa, 5);
    defer files.deinit(gpa);

    while (args.next()) | file | {
        try files.append(gpa, file);
    }

    var read_buf: [1024]u8 = undefined;

    if (files.items.len == 0) {
        const source = std.fs.File.stdin();
        var reader = source.reader(&read_buf);
        try search(&reader.interface, regex, &writer, &stdout.interface, null);
    }

    for (files.items) |file_name | {
        var source = try std.fs.cwd().openFile(file_name, .{.mode = .read_only});
        defer source.close();
        var reader = source.reader(&read_buf);
        try search(&reader.interface, regex, &writer, &stdout.interface, file_name);
    }
}


fn search(
    source: *std.Io.Reader,
    pattern: mvzr.Regex,
    writer: *std.Io.Writer.Allocating,
    stdout: *std.Io.Writer,
    file_name: ?[]const u8) !void {

    while (true) {
        if (source.streamDelimiter(&writer.writer, '\n')) | _ | {
            const line = writer.written();
            var reg_iterator = pattern.iterator(line);
            var current: usize = 0;

            while (reg_iterator.next()) |match | {

                if (file_name) |name | {
                    try stdout.print("{s}:{s}\x1b[31m{s}\x1b[0m", .{name, line[current..match.start], match.slice});

                }else {
                    try stdout.print("{s}\x1b[31m{s}\x1b[0m", .{line[current..match.start], match.slice});
                }

                current = match.end;
            }

            if (current > 0) {
                try stdout.print("{s}\n", .{line[current..]});
            }

            writer.clearRetainingCapacity();
            source.toss(1);

        }else |err| switch (err) {
            error.EndOfStream => {
                break;
            },
            else => {
                return err;
            },
        }
    }
    try stdout.flush();
}
