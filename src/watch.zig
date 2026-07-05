const std = @import("std");
const oid = @import("oid.zig");
const workspace = @import("workspace.zig");
const Store = @import("store.zig").Store;
const Oid = oid.Oid;

pub const Options = struct {
    interval_ms: u32 = 800,
    author: []const u8 = "you <you@localhost>",
    on_change: ?*const fn () void = null,
};

fn skipDir(name: []const u8) bool {
    return std.mem.eql(u8, name, ".gr") or std.mem.eql(u8, name, ".git");
}

/// Cheap state signature of the working tree: a BLAKE3 over (path, size,
/// content hash) of every file, skipping `.gr` and `.git`. Content is folded
/// in so a change is detected regardless of mtime resolution. A file that
/// vanishes mid-walk is skipped rather than fatal.
pub fn signature(store: *Store, work_dir: std.Io.Dir) !Oid {
    const io = store.io;
    const alloc = store.alloc;

    var hasher = oid.Hasher.init();

    var walker = try work_dir.walkSelectively(alloc);
    defer walker.deinit();

    while (try walker.next(io)) |entry| {
        switch (entry.kind) {
            .directory => {
                if (!skipDir(std.fs.path.basenamePosix(entry.path))) {
                    walker.enter(io, entry) catch continue;
                }
            },
            .file => {
                const st = work_dir.statFile(io, entry.path, .{}) catch continue;
                const data = work_dir.readFileAlloc(io, entry.path, alloc, .unlimited) catch continue;
                defer alloc.free(data);
                var content: Oid = undefined;
                oid.Blake3.hash(data, &content.bytes, .{});

                var sz: [8]u8 = undefined;
                std.mem.writeInt(u64, &sz, st.size, .big);

                hasher.update(entry.path);
                hasher.update(&sz);
                hasher.update(&content.bytes);
            },
            .sym_link => {
                var buf: [4096]u8 = undefined;
                const n = work_dir.readLink(io, entry.path, &buf) catch continue;
                hasher.update(entry.path);
                hasher.update(buf[0..n]);
            },
            else => {},
        }
    }

    return hasher.finalOid();
}

fn nowSeconds(store: *Store) i64 {
    return @intCast(@divTrunc(std.Io.Clock.now(.real, store.io).nanoseconds, 1_000_000_000));
}

/// Poll the working tree forever, auto-saving a snapshot whenever it changes.
/// Runs until the process is killed (Ctrl-C).
pub fn watch(store: *Store, work_dir: std.Io.Dir, opts: Options) !void {
    const io = store.io;
    const alloc = store.alloc;

    var buf: [256]u8 = undefined;
    var w = std.Io.File.stdout().writer(io, &buf);
    const out = &w.interface;

    var last = try signature(store, work_dir);

    while (true) {
        std.Io.sleep(io, std.Io.Duration.fromMilliseconds(opts.interval_ms), .awake) catch {};

        const sig = signature(store, work_dir) catch continue;
        if (sig.eql(last)) continue;
        last = sig;

        const st = workspace.status(store, work_dir, alloc) catch continue;
        const changed = st.len > 0;
        for (st) |e| alloc.free(e.path);
        alloc.free(st);
        if (!changed) continue;

        const change_oid = workspace.snapshot(store, work_dir, opts.author, "live: auto-save", nowSeconds(store)) catch continue;

        var hex: [Oid.len * 2]u8 = undefined;
        _ = change_oid.toHex(&hex);
        out.print("\u{25cf} auto-saved {s}\n", .{hex[0..12]}) catch {};
        out.flush() catch {};

        if (opts.on_change) |cb| cb();
    }
}

// --- tests ---

const testing = std.testing;

test "signature changes on content change, stable otherwise" {
    const io = std.testing.io;
    const alloc = testing.allocator;

    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();

    var store = try Store.init(io, alloc, tmp.dir);
    defer store.deinit();

    try tmp.dir.createDirPath(io, "work");
    try tmp.dir.writeFile(io, .{ .sub_path = "work/a.txt", .data = "hello" });

    var work = try tmp.dir.openDir(io, "work", .{ .iterate = true });
    defer work.close(io);

    const s1 = try signature(&store, work);
    const s1b = try signature(&store, work);
    try testing.expect(s1.eql(s1b));

    try tmp.dir.writeFile(io, .{ .sub_path = "work/a.txt", .data = "hello world!!" });
    const s2 = try signature(&store, work);
    try testing.expect(!s1.eql(s2));
}
