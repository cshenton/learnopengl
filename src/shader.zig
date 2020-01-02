const std = @import("std");
const builtin = @import("builtin");
const panic = std.debug.panic;
const Allocator = std.mem.Allocator;
const cwd = std.fs.cwd;
const OpenFlags = std.fs.File.OpenFlags;

usingnamespace @import("c.zig");

pub const Shader = struct {
    id: c_uint,

    pub fn init(allocator: *Allocator, vertexPath: []const u8, fragmentPath: []const u8) !Shader {
        // 1. retrieve the vertex/fragment source code from filePath
        const vShaderFile = try cwd().openFile(vertexPath, OpenFlags{ .read = true, .write = false });
        defer vShaderFile.close();

        const fShaderFile = try cwd().openFile(fragmentPath, OpenFlags{ .read = true, .write = false });
        defer fShaderFile.close();

        var vertexCode = try allocator.alloc(u8, try vShaderFile.getEndPos());
        defer allocator.free(vertexCode);

        var fragmentCode = try allocator.alloc(u8, try fShaderFile.getEndPos());
        defer allocator.free(fragmentCode);

        const vLen = try vShaderFile.read(vertexCode);
        const fLen = try fShaderFile.read(fragmentCode);

        // 2. compile shaders
        // vertex shader
        const vertex = glCreateShader(GL_VERTEX_SHADER);
        const vertexSrcPtr: ?[*]const u8 = vertexCode.ptr;
        glShaderSource(vertex, 1, &vertexSrcPtr, null);
        glCompileShader(vertex);
        checkCompileErrors(vertex, "VERTEX");
        // fragment Shader
        const fragment = glCreateShader(GL_FRAGMENT_SHADER);
        const fragmentSrcPtr: ?[*]const u8 = fragmentCode.ptr;
        glShaderSource(fragment, 1, &fragmentSrcPtr, null);
        glCompileShader(fragment);
        checkCompileErrors(fragment, "FRAGMENT");
        // shader Program
        const id = glCreateProgram();
        glAttachShader(id, vertex);
        glAttachShader(id, fragment);
        glLinkProgram(id);
        checkCompileErrors(id, "PROGRAM");
        // delete the shaders as they're linked into our program now and no longer necessary
        glDeleteShader(vertex);
        glDeleteShader(fragment);

        return Shader{ .id = id };
    }

    pub fn use(self: Shader) void {
        glUseProgram(self.id);
    }

    pub fn setBool(self: Shader, name: [:0]const u8, val: bool) void {
        // glUniform1i(glGetUniformLocation(ID, name.c_str()), (int)value);
    }

    pub fn setInt(self: Shader, name: [:0]const u8, val: c_int) void {
        glUniform1i(glGetUniformLocation(self.id, name), val);
    }

    pub fn setFloat(self: Shader, name: [:0]const u8, val: f32) void {
        // glUniform1f(glGetUniformLocation(ID, name.c_str()), value);
    }

    fn checkCompileErrors(shader: c_uint, errType: []const u8) void {
        var success: c_int = undefined;
        var infoLog: [1024]u8 = undefined;
        if (std.mem.eql(u8, errType, "PROGRAM")) {
            glGetShaderiv(shader, GL_COMPILE_STATUS, &success);
            if (success == 0) {
                glGetShaderInfoLog(shader, 1024, null, @ptrCast([*c]u8, &infoLog));
                panic("ERROR::SHADER::{}::COMPILATION_FAILED\n{}\n", .{ errType, infoLog });
            }
        } else {
            glGetShaderiv(shader, GL_LINK_STATUS, &success);
            if (success == 0) {
                glGetShaderInfoLog(shader, 1024, null, @ptrCast([*c]u8, &infoLog));
                panic("ERROR::SHADER::LINKING_FAILED\n{}\n", .{infoLog});
            }
        }
    }
};
