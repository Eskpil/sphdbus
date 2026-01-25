//
// FIXME: All these w.prints() are so hard to parse, maybe give names to what
// we are trying to achieve
//
const std = @import("std");
const sphtud = @import("sphtud");
const DbusSchemaParser = @import("DbusSchemaParser.zig");
const helpers = @import("generate_helpers.zig");

fn genInterfaceProperty(prop: *DbusSchemaParser.Property, w: *std.Io.Writer) !void {
    try w.print(
        \\                @"{s}": {f},
        \\
    , .{
        prop.name,
        helpers.dbusToZigType(prop.typ),
    });

    return;
}

fn genInterfaceMethod(method: *DbusSchemaParser.Method, w: *std.Io.Writer) !void {
    if (method.args.len == 0) {
        try w.print(
            \\                @"{s}": void,
            \\
        , .{method.name});

        return;
    }

    try w.print(
        \\                @"{s}": struct {{
        \\
    , .{method.name});

    var args_it = method.args.iter();
    while (args_it.next()) |arg| {
        try w.print(
            \\                    @"{s}": {f},
            \\
        , .{
            arg.name,
            helpers.dbusToZigType(arg.typ),
        });
    }

    try w.writeAll(
        \\                },
        \\
    );
}

fn genInterfaceRequest(reader: *std.fs.File.Reader, interface: *DbusSchemaParser.Interface, w: *std.Io.Writer) !void {
    try w.print(
        \\        @"{s}": union(enum) {{
        \\            method: union(enum) {{
        \\
    , .{interface.name});

    var method_it = interface.methods.iter();
    while (method_it.next()) |method| {
        try genInterfaceMethod(method, w);
    }

    //FIXME: Don't inline property and give it a named type that is used for both getter and setter
    //FIXME: Impl set property
    try w.writeAll(
        \\            },
        \\            get_property: Property,
        \\            set_property: Property,
        \\
        \\
    );

    if (interface.properties.len == 0) {
        try w.writeAll(
            \\            const Property = struct {};
            \\
        );
    } else {
        try w.writeAll(
            \\            const Property = union(enum) {
            \\
        );
        var property_it = interface.properties.iter();
        while (property_it.next()) |prop| {
            try genInterfaceProperty(prop, w);
        }

        // Finish property
        try w.writeAll(
            \\            };
            \\
        );
    }

    // docstring
    // FIXME: split gen docstring
    // FIXME: Remove any node starting with tp: to remove all the useless docs
    try reader.seekTo(interface.xml_start);
    const xml_len = interface.xml_end - interface.xml_start;
    std.debug.print("start: {d} , end: {d}\n", .{ interface.xml_start, interface.xml_end });
    var line_buf: [4096]u8 = undefined;
    var limited = reader.interface.limited(.limited(xml_len), &line_buf);
    try w.writeAll(
        \\
        \\            pub const docstring: []const u8 =
        \\
    );

    while (true) {
        const line = limited.interface.takeDelimiterExclusive('\n') catch |e| switch (e) {
            error.EndOfStream => break,
            else => return e,
        };

        // FIXME: Merge failure with above
        _ = limited.interface.discard(.limited(1)) catch |e| switch (e) {
            error.EndOfStream => break,
            else => return e,
        };

        try w.print(
            \\                \\{s}
            \\
        , .{line});
    }

    try w.writeAll(
        \\
        \\           ;
        \\
    );

    // Finish interface union
    try w.writeAll(
        \\        }
        \\
    );
    //const Request = union(enum) {
    //    @"/my/path/1": union(enum) {
    //        @"org.MyInterface1": union(enum) {
    //            method: union(enum) {
    //                @"DoThing1": void,
    //                @"DoThing2": struct {
    //                    a_string: dbus.DbusString,
    //                    a_int: u32,
    //                },
    //                @"DoThing3": struct {
    //                    dbus.DbusString,
    //                    u32,
    //                },
    //            },
    //            property: union(enum) {
    //                @"MyProp": struct { dbus.DbusString },
    //            },
    //        },
    //    },
    //    @"/my/path/2": union(enum) {},
    //    @"/something_else_entirely": union(enum) {},
    //};

}

fn genInterfaces(alloc: sphtud.alloc.LinearAllocator, base_path: []const u8, interface_path: []const u8, w: *std.Io.Writer) !void {
    const cp = alloc.checkpoint();
    defer alloc.restore(cp);

    // lol funny name...
    var full_relative_path_buf: [std.fs.max_path_bytes]u8 = undefined;
    const full_relative_path = try std.fmt.bufPrint(&full_relative_path_buf, "{f}", .{std.fs.path.fmtJoin(&.{ base_path, interface_path })});

    std.debug.print("{s}\n", .{full_relative_path});
    const interface_f = try std.fs.cwd().openFile(full_relative_path, .{});
    defer interface_f.close();

    var reader_buf: [4096]u8 = undefined;
    var reader = interface_f.reader(&reader_buf);

    var xmlr = sphtud.xml.Parser.init(&reader.interface);
    var schema_parser = try DbusSchemaParser.init(alloc.allocator(), alloc.expansion());

    var content_writer = std.Io.Writer.Discarding.init(&.{});
    while (try xmlr.next(&content_writer.writer)) |item| {
        try schema_parser.step(item);
    }

    var interfaces = schema_parser.output.iter();
    while (interfaces.next()) |interface| {
        try genInterfaceRequest(&reader, interface, w);
    }
}

pub fn main() !void {
    var alloc_buf: [1 * 1024 * 1024]u8 = undefined;
    var alloc = sphtud.alloc.BufAllocator.init(&alloc_buf);

    var args = std.process.args();

    // process name
    _ = args.next();

    const service_def_path = args.next() orelse return error.NoServiceDef;
    const output_path = args.next() orelse return error.NoOutPath;

    const service_def_file = try std.fs.cwd().openFile(service_def_path, .{});
    defer service_def_file.close();

    const base_path = std.fs.path.dirname(service_def_path).?;
    var service_def_reader_buf: [4096]u8 = undefined;
    var service_f_reader = service_def_file.reader(&service_def_reader_buf);

    var output_file = try std.fs.cwd().createFile(output_path, .{});
    var output_buf: [4096]u8 = undefined;
    var output_writer = output_file.writer(&output_buf);

    const w = &output_writer.interface;

    try w.writeAll(
        \\const dbus = @import("sphdbus");
        \\
        \\pub const Request = union(enum) {
        \\
    );
    var service_parser = sphtud.xml.Parser.init(&service_f_reader.interface);
    var discarding_w = std.Io.Writer.Discarding.init(&.{});
    while (try service_parser.next(&discarding_w.writer)) |item| switch (item.type) {
        .element_start => {
            // FXIME: name -> object-path
            const object_path = try item.attributeByKey("name");
            const interface = try item.attributeByKey("interface");

            try w.print(
                \\    @"{s}": union(enum) {{
                \\
            , .{object_path.?});

            try genInterfaces(alloc.linear(), base_path, interface.?, &output_writer.interface);

            try w.writeAll(
                \\    },
                \\
            );
        },
        else => {},
    };

    try w.writeAll(
        \\};
        \\
    );
    try output_writer.interface.flush();
}
