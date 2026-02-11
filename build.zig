const std = @import("std");

pub const ClientGenerator = struct {
    b: *std.Build,
    exe: *std.Build.Step.Compile,
    dbus: *std.Build.Module,

    pub fn init(b: *std.Build, sphtud: *std.Build.Module, dbus: *std.Build.Module) ClientGenerator {
        const exe = b.addExecutable(.{
            .name = "generate",
            .root_module = b.createModule(.{
                .root_source_file = b.path("src/generate.zig"),
                .target = b.graph.host,
                .optimize = .Debug,
            }),
        });
        exe.root_module.addImport("sphtud", sphtud);

        return .{
            .b = b,
            .exe = exe,
            .dbus = dbus,
        };
    }

    pub fn genClientMod(self: ClientGenerator, xml_path: std.Build.LazyPath) *std.Build.Module {
        const run = self.b.addRunArtifact(self.exe);
        run.addFileArg(xml_path);
        const out_path = run.addOutputFileArg("mod.zig");
        const mod = self.b.createModule(.{
            .root_source_file = out_path,
        });
        mod.addImport("sphdbus", self.dbus);

        return mod;
    }
};

pub fn build(b: *std.Build) !void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const sphtud_dep = b.dependency("sphtud", .{});
    const sphtud = sphtud_dep.module("sphtud");

    const dbus_mod = b.addModule("sphdbus", .{
        .root_source_file = b.path("src/sphdbus.zig"),
        .target = target,
        .optimize = optimize,
    });

    const cg = ClientGenerator.init(b, sphtud, dbus_mod);
    b.installArtifact(cg.exe);
}
