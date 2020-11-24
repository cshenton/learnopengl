const std = @import("std");
const Builder = std.build.Builder;
const builtin = @import("builtin");

pub fn build(b: *Builder) void {
    // Each tutorial stage, its source file, and description
    const targets = [_]Target{
        .{ .name = "hello_window", .src = "src/1_1_hello_window.zig", .description = "Hello GLFW Window" },
        .{ .name = "hello_triangle", .src = "src/1_2_hello_triangle.zig", .description = "Hello OpenGL Triangle" },
        .{ .name = "shaders", .src = "src/1_3_shaders.zig", .description = "OpenGL Shaders" },
        .{ .name = "textures", .src = "src/1_4_textures.zig", .description = "OpenGL Textures" },
        .{ .name = "transformations", .src = "src/1_5_transformations.zig", .description = "Vector Transformations" },
        .{ .name = "coordinate_systems", .src = "src/1_6_coordinate_systems.zig", .description = "Coordinate Systems" },
        .{ .name = "camera", .src = "src/1_7_camera.zig", .description = "Camera" },
        .{ .name = "colors", .src = "src/2_1_colors.zig", .description = "Colors" },
        .{ .name = "basic_lighting", .src = "src/2_2_basic_lighting.zig", .description = "Basic Lighting" },
        .{ .name = "materials", .src = "src/2_3_materials.zig", .description = "Materials" },
        .{ .name = "lighting_maps", .src = "src/2_4_lighting_maps.zig", .description = "Lighting Maps" },
        .{ .name = "light_casters", .src = "src/2_5_light_casters.zig", .description = "Light Casters" },
        .{ .name = "multiple_lights", .src = "src/2_6_multiple_lights.zig", .description = "Multiple Light Sources" },
        .{ .name = "ibl_specular", .src = "src/6_2_2_ibl_specular.zig", .description = "Image Based Lighting with Specular" },
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

        // Includes
        exe.addIncludeDir("deps/include");

        // Sources
        exe.addCSourceFile("deps/src/stb_image_impl.c", &[_][]const u8{"-std=c99"});
        exe.addCSourceFile("deps/src/glad.c", &[_][]const u8{"-std=c99"});

        // Libraries
        exe.linkLibC();
        exe.addLibPath("deps/lib");

        // OS specific
        switch (builtin.os.tag) {
            .windows => {
                exe.linkSystemLibrary("glfw3");
                exe.linkSystemLibrary("kernel32");
                exe.linkSystemLibrary("user32");
                exe.linkSystemLibrary("shell32");
                exe.linkSystemLibrary("gdi32");
            },
            else => {
                exe.linkSystemLibrary("glfw");
            },
        }

        b.default_step.dependOn(&exe.step);
        b.step(self.name, self.description).dependOn(&exe.run().step);
    }
};
