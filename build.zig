const std = @import("std");
const Builder = std.build.Builder;
const builtin = @import("builtin");

pub fn build(b: *Builder) void {
    // Each tutorial stage, its source file, and description
    const targets = [_]Target{
        .{ .name = "hello_window", .src = "src/01_hello_window.zig", .description = "Hello GLFW Window" },
        .{ .name = "hello_triangle", .src = "src/02_hello_triangle.zig", .description = "Hello OpenGL Triangle" },
        .{ .name = "shaders", .src = "src/03_shaders.zig", .description = "OpenGL Shaders" },
        .{ .name = "textures", .src = "src/04_textures.zig", .description = "OpenGL Textures" },
        .{ .name = "transformations", .src = "src/05_transformations.zig", .description = "Vector Transformations" },
        .{ .name = "coordinate_systems", .src = "src/06_coordinate_systems.zig", .description = "Coordinate Systems" },
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

        // GLFW
        exe.addIncludeDir("C:\\Users\\charlie\\src\\github.com\\Microsoft\\vcpkg\\installed\\x64-windows-static\\include\\");
        exe.addLibPath("C:\\Users\\charlie\\src\\github.com\\Microsoft\\vcpkg\\installed\\x64-windows-static\\lib");
        exe.linkSystemLibrary("glfw3");

        // STB
        exe.addCSourceFile("deps/stb_image/src/stb_image_impl.c", &[_][]const u8{"-std=c99"});
        exe.addIncludeDir("deps/stb_image/include");

        // GLAD
        exe.addCSourceFile("deps/glad/src/glad.c", &[_][]const u8{"-std=c99"});
        exe.addIncludeDir("deps/glad/include");

        b.default_step.dependOn(&exe.step);
        b.step(self.name, self.description).dependOn(&exe.run().step);
    }
};
