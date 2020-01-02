const std = @import("std");
const builtin = @import("builtin");
const panic = std.debug.panic;
const Allocator = std.mem.Allocator;
const cwd = std.fs.cwd;

usingnamespace @import("c.zig");

const Shader = struct {
    id: c_uint,

    pub fn init(allocator: *Allocator, vertexPath: []const u8, fragmentPath: []const u8) !Shader {
        // 1. retrieve the vertex/fragment source code from filePath
        const vShaderFile = try cwd().openFile(vertexPath, OpenFlags{ .read = true, .write = false});
        defer vShaderFile.close()

        const fShaderFile = try cwd().openFile(fragmentPath, OpenFlags{ .read = true, .write = false});
        defer fShaderFile.close();

        var vertexCode = try allocator.alloc(u8, try vShaderCode.getEndPos());
        defer allocator.free(vertexCode);

        var fragmentCode = try allocator.alloc(u8, try fShaderFile.getEndPos());
        defer allocator.free(fragmentCode);

        const vLen = try vShaderFile.read(vertexCode);
        const fLen = try vShaderFile.read(vertexCode);

        // 2. compile shaders
        // vertex shader
        const vertex = glCreateShader(GL_VERTEX_SHADER);
        const vertexSrcPtr: ?[*]const u8 = vertexCode.ptr;
        glShaderSource(vertex, 1, &vertexSrcPtr, NULL);
        glCompileShader(vertex);
        checkCompileErrors(vertex, "VERTEX");
        // fragment Shader
        const fragment = glCreateShader(GL_FRAGMENT_SHADER);
        const fragmentSrcPtr: ?[*]const u8 = fragmentCode.ptr;
        glShaderSource(fragment, 1, &vertexSrcPtr, NULL);
        glCompileShader(fragment);
        // checkCompileErrors(fragment, "FRAGMENT");
        // shader Program
        const id = glCreateProgram();
        glAttachShader(id, vertex);
        glAttachShader(id, fragment);
        glLinkProgram(id);
        // checkCompileErrors(id, "PROGRAM");
        // delete the shaders as they're linked into our program now and no longer necessary
        glDeleteShader(vertex);
        glDeleteShader(fragment);

        return Shader{ .id = id };
    }

    pub fn use() void {
        glUseProgram(ID);
    }

    pub fn setBool(name: []const u8, val: bool) void{
        // glUniform1i(glGetUniformLocation(ID, name.c_str()), (int)value);
    }

    pub fn setInt(name: []const u8, val: c_int) void{
        // glUniform1i(glGetUniformLocation(ID, name.c_str()), value);
    }

    pub fn setFloat(name: []const u8, val: f32) void {
        // glUniform1f(glGetUniformLocation(ID, name.c_str()), value);
    }

    fn checkCompileErrors(shader: c_uint, errType: []const u8) void {
        // int success;
        // char infoLog[1024];
        // if (errType != "PROGRAM") {
        //     glGetShaderiv(shader, GL_COMPILE_STATUS, &success);
        //     if (!success)
        //     {
        //         glGetShaderInfoLog(shader, 1024, NULL, infoLog);
        //         std::cout << "ERROR::SHADER_COMPILATION_ERROR of type: " << type << "\n" << infoLog << "\n -- --------------------------------------------------- -- " << std::endl;
        //     }
        // } else {
        //     glGetProgramiv(shader, GL_LINK_STATUS, &success);
        //     if (!success)
        //     {
        //         glGetProgramInfoLog(shader, 1024, NULL, infoLog);
        //         std::cout << "ERROR::PROGRAM_LINKING_ERROR of type: " << type << "\n" << infoLog << "\n -- --------------------------------------------------- -- " << std::endl;
        //     }
        // }
    }
}
