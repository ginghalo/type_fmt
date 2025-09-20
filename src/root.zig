//! By convention, root.zig is the root source file when making a library.
const std = @import("std");

const Allocator = std.mem.Allocator;

const StructField = std.builtin.Type.StructField;
const Declaration = std.builtin.Type.Declaration;

const Writer = std.Io.Writer;

pub const str = []const u8;
pub const Fmt = struct {
    t: type,
    fmt: str,
};

fn indexOf(comptime slice: []const str, comptime value: str) ?usize {
    for (0..slice.len) |i| if (std.mem.eql(u8, slice[i], value) == true) return i;
    return null;
}
pub fn type_fmt(comptime T: type, comptime fmt: str) Fmt {
    const info = @typeInfo(T).@"struct";
    const fieldnames = comptime FIELDNAMES: {
        var fs: []const str = &[0]str{};
        for (info.fields) |field| {
            fs = fs ++ .{field.name};
        }
        break :FIELDNAMES fs;
    };

    comptime var fmtstr: str = "";
    comptime var t = struct {};

    comptime var idx: usize = 0;
    comptime var end: usize = 0;
    @setEvalBranchQuota(fmt.len * 500);
    comptime while (idx + end < fmt.len) : (end += 1) {
        if (fmt[idx + end] == '{') {
            fmtstr = fmtstr ++ fmt[idx..][0 .. end + 1];
            if (fmt[idx + end + 1] != '(') return error.@"Must have fieldname of T!";
            if (std.mem.indexOfScalar(u8, fmt[idx + end + 1 ..], ')')) |index| {
                idx += end + 1;
                end = 0;
                if (indexOf(fieldnames, fmt[idx + 1 ..][0 .. index - 1])) |i| {
                    const fieldname = fieldnames[i];
                    const fieldtype = @FieldType(T, fieldname);
                    const tinfo = @typeInfo(t).@"struct";
                    t = @Type(.{ .@"struct" = .{
                        .layout = .auto,
                        .decls = &[_]Declaration{},
                        .is_tuple = false,
                        .fields = tinfo.fields ++ .{StructField{
                            .alignment = @alignOf(fieldtype),
                            .is_comptime = false,
                            .default_value_ptr = null,
                            .type = fieldtype,
                            .name = std.fmt.comptimePrint("{s}", .{fieldname}),
                        }},
                    } });
                } else {
                    return error.@"Must one of the field of T!";
                }
                idx += index + 1;
            } else {
                return error.@"Must have right format character!";
            }
        }
    };
    comptime if (end > 1) {
        fmtstr = fmtstr ++ fmt[idx..][0..end];
    };
    return .{ .fmt = fmtstr, .t = t };
}

pub fn printValue(comptime T: type, value: T, comptime fmt: str) type_fmt(T, fmt).t {
    const TF = type_fmt(T, fmt);
    const info = @typeInfo(TF.t).@"struct";
    var v: TF.t = undefined;

    inline for (info.fields) |field| {
        @field(v, field.name) = @field(value, field.name);
    }
    return v;
}

pub fn bufPrint(comptime T: type, value: T, comptime fmt: str, buf: []u8) ![]u8 {
    const TF = type_fmt(T, fmt);

    const v = printValue(T, value, fmt);
    return try std.fmt.bufPrint(buf, TF.fmt, v);
}
pub fn allocPrint(comptime T: type, value: T, comptime fmt: str, allocator: Allocator) !str {
    const TF = type_fmt(T, fmt);
    const v = printValue(T, value, fmt);
    return try std.fmt.allocPrint(allocator, TF.fmt, v);
}
pub fn print(comptime T: type, value: T, comptime fmt: str, writer: *Writer) !void {
    const TF = type_fmt(T, fmt);
    const v = printValue(T, value, fmt);
    try writer.print(TF.fmt, v);
}

test bufPrint {
    var buf: [64]u8 = undefined;
    const s = try bufPrint(
        struct { a: str, b: i64, c: u66 },
        .{ .a = "123", .b = -1, .c = 255 },
        "{(b)d} / {(a)s}",
        &buf,
    );
    try std.testing.expect(std.mem.eql(u8, s, "-1 / 123"));
}
test allocPrint {
    const allocator = std.testing.allocator;
    const s = try allocPrint(
        struct { a: str, b: i64, c: u66 },
        .{ .a = "123", .b = -1, .c = 255 },
        "{(c)d} - {(b)d}",
        allocator,
    );
    defer allocator.free(s);
    try std.testing.expect(std.mem.eql(u8, s, "255 - -1"));
}
test print {
    var buf: [64]u8 = undefined;
    var fw: Writer = .fixed(&buf);
    try print(
        struct { a: str, b: i64, c: u66 },
        .{ .a = "123", .b = -1, .c = 255 },
        "{(c)d} - {(b)d}",
        &fw.writer,
    );
    try std.testing.expect(std.mem.eql(u8, fw.buffer[0..fw.end], "255 - -1"));
}
