const std = @import("std");
const Builder = std.build.Builder;
const builtin = @import("builtin");

pub fn build(b: *Builder) void {
    // Each tutorial stage, its source file, and description
    const targets = [_]Target{
        .{ .name = "hello_window", .src = "src/01_hello_window.zig", .description = "Hello GLFW Window" },
        .{ .name = "hello_triangle", .src = "src/02_hello_triangle.zig", .description = "Hello OpenGL Triangle" },
    };

    // Build all targets
    for (targets) |target| {
        target.build(b);
    }
}

const Target = struct {
    name: []const u8,
    src: []const u8,
    description: []const u8,

    pub fn build(self: Target, b: *Builder) void {
        var exe = b.addExecutable(self.name, self.src);
        exe.setBuildMode(b.standardReleaseOptions());

        // OS stuff
        exe.linkLibC();
        exe.linkSystemLibrary("kernel32");
        exe.linkSystemLibrary("user32");
        exe.linkSystemLibrary("shell32");
        exe.linkSystemLibrary("gdi32");

        exe.addIncludeDir("C:\\Users\\charlie\\src\\github.com\\Microsoft\\vcpkg\\installed\\x64-windows-static\\include\\");
        exe.addLibPath("C:\\Users\\charlie\\src\\github.com\\Microsoft\\vcpkg\\installed\\x64-windows-static\\lib");

        const copts = [1][]const u8{"-std=c99"};

        // STB
        // exe.addCSourceFile("deps/stb_image/stb_image_impl.c", copts[0..]);

        // GLFW
        exe.linkSystemLibrary("glfw3");

        // GLAD
        exe.addCSourceFile("deps/glad/src/glad.c", copts[0..]);
        exe.addIncludeDir("deps/glad/include");

        b.default_step.dependOn(&exe.step);
        b.step(self.name, self.description).dependOn(&exe.run().step);
    }
};
