const std = @import("std");
const type_fmt = @import("type_fmt");

pub fn main() !void {
    const Date = struct {
        sec: u6, // into minute
        min: u6, // into hour
        hour: u5, // into day
        day: u5, // into month
        month: u4, // into year
        year: u16,
    };
    const today = Date{
        .year = 2077,
        .month = 11,
        .day = 4,
        .hour = 5,
        .min = 1,
        .sec = 4,
    };
    var buf: [64]u8 = undefined;
    var w = std.fs.File.stdout().writer(&buf);
    try type_fmt.print(Date, today, "Today is {(year)}/{(month):0>2}/{(day):0>2} {(hour):0>2}:{(min):0>2}:{(sec):0>2}.", &w.interface);
    try w.interface.flush();
}
