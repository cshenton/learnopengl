const std = @import("std");
const builtin = @import("builtin");
const panic = std.debug.panic;

usingnamespace @import("c.zig");

// settings
const SCR_WIDTH: u32 = 800;
const SCR_HEIGHT: u32 = 600;

const vertexShaderSource: [:0]const u8 =
    \\#version 330 core
    \\layout (location = 0) in vec3 aPos;
    \\void main()
    \\{
    \\   gl_Position = vec4(aPos.x, aPos.y, aPos.z, 1.0);
    \\};
;
const fragmentShaderSource: [:0]const u8 =
    \\#version 330 core
    \\out vec4 FragColor;
    \\void main()
    \\{
    \\   FragColor = vec4(1.0f, 0.5f, 0.2f, 1.0f);
    \\};
;

pub fn main() void {
    const ok = glfwInit();
    if (ok == 0) {
        panic("Failed to initialise GLFW\n", .{});
    }
    defer glfwTerminate();

    glfwWindowHint(GLFW_CONTEXT_VERSION_MAJOR, 3);
    glfwWindowHint(GLFW_CONTEXT_VERSION_MINOR, 3);
    glfwWindowHint(GLFW_OPENGL_PROFILE, GLFW_OPENGL_CORE_PROFILE);

    if (builtin.os == builtin.Os.macosx) {
        glfwWindowHint(GLFW_OPENGL_FORWARD_COMPAT, GL_TRUE);
    }

    // glfw: initialize and configure
    var window = glfwCreateWindow(SCR_WIDTH, SCR_HEIGHT, "Learn OpenGL", null, null);
    if (window == null) {
        panic("Failed to create GLFW window\n", .{});
    }

    glfwMakeContextCurrent(window);
    const resizeCallback = glfwSetFramebufferSizeCallback(window, framebuffer_size_callback);

    // glad: load all OpenGL function pointers
    if (gladLoadGLLoader(@ptrCast(GLADloadproc, glfwGetProcAddress)) == 0) {
        panic("Failed to initialise GLAD\n", .{});
    }

    // build and compile our shader program

    // vertex shader
    const vertexShader = glCreateShader(GL_VERTEX_SHADER);
    const vertexSrcPtr: ?[*]const u8 = vertexShaderSource.ptr;
    // const vertexSrcLen = @intCast(c_int, vertexShaderSource.len);
    glShaderSource(vertexShader, 1, &vertexSrcPtr, null);
    glCompileShader(vertexShader);
    // check for shader compile errors
    var success: c_int = undefined;
    var infoLog: [512]u8 = undefined;
    glGetShaderiv(vertexShader, GL_COMPILE_STATUS, &success);
    if (success == 0) {
        glGetShaderInfoLog(vertexShader, 512, null, &infoLog);
        panic("ERROR::SHADER::VERTEX::COMPILATION_FAILED\n{}\n", .{infoLog});
    }
    // fragment shader
    const fragmentShader = glCreateShader(GL_FRAGMENT_SHADER);
    const fragmentSrcPtr: ?[*]const u8 = fragmentShaderSource.ptr;
    glShaderSource(fragmentShader, 1, &fragmentSrcPtr, null);
    glCompileShader(fragmentShader);
    // check for shader compile errors
    glGetShaderiv(fragmentShader, GL_COMPILE_STATUS, &success);
    if (success == 0) {
        glGetShaderInfoLog(vertexShader, 512, null, &infoLog);
        panic("ERROR::SHADER::FRAGMENT::COMPILATION_FAILED\n{}\n", .{infoLog});
    }
    // link shaders
    const shaderProgram = glCreateProgram();
    glAttachShader(shaderProgram, vertexShader);
    glAttachShader(shaderProgram, fragmentShader);
    glLinkProgram(shaderProgram);
    // check for linking errors
    glGetProgramiv(shaderProgram, GL_LINK_STATUS, &success);
    if (success == 0) {
        glGetShaderInfoLog(vertexShader, 512, null, &infoLog);
        panic("ERROR::SHADER::PROGRAM::LINKING_FAILED\n{}\n", .{infoLog});
    }
    glDeleteShader(vertexShader);
    glDeleteShader(fragmentShader);

    // set up vertex data (and buffer(s)) and configure vertex attributes

    const vertices = [_]f32{
        0.5,  0.5,  0.0, // top right
        0.5,  -0.5, 0.0, // bottom right
        -0.5, -0.5, 0.0, // bottom let
        -0.5, 0.5,  0.0, // top left
    };
    const indices = [_]u32{ // note that we start from 0!
        0, 1, 3, // first Triangle
        1, 2, 3, // second Triangle
    };
    var VAO: c_uint = undefined;
    var VBO: c_uint = undefined;
    var EBO: c_uint = undefined;
    glGenVertexArrays(1, &VAO);
    defer glDeleteVertexArrays(1, &VAO);
    glGenBuffers(1, &VBO);
    defer glDeleteBuffers(1, &VBO);
    glGenBuffers(1, &EBO);
    defer glDeleteBuffers(1, &EBO);
    // bind the Vertex Array Object first, then bind and set vertex buffer(s), and then configure vertex attributes(s).
    glBindVertexArray(VAO);

    glBindBuffer(GL_ARRAY_BUFFER, VBO);
    glBufferData(GL_ARRAY_BUFFER, vertices.len * @sizeOf(f32), &vertices, GL_STATIC_DRAW);

    glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, EBO);
    glBufferData(GL_ELEMENT_ARRAY_BUFFER, indices.len * @sizeOf(u32), &indices, GL_STATIC_DRAW);

    glVertexAttribPointer(0, 3, GL_FLOAT, GL_FALSE, 3 * @sizeOf(f32), null);
    glEnableVertexAttribArray(0);

    // note that this is allowed, the call to glVertexAttribPointer registered VBO as the vertex attribute's bound vertex buffer object so afterwards we can safely unbind
    glBindBuffer(GL_ARRAY_BUFFER, 0);

    // remember: do NOT unbind the EBO while a VAO is active as the bound element buffer object IS stored in the VAO; keep the EBO bound.
    //glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, 0);

    // You can unbind the VAO afterwards so other VAO calls won't accidentally modify this VAO, but this rarely happens. Modifying other
    // VAOs requires a call to glBindVertexArray anyways so we generally don't unbind VAOs (nor VBOs) when it's not directly necessary.
    glBindVertexArray(0);

    // uncomment this call to draw in wireframe polygons.
    //glPolygonMode(GL_FRONT_AND_BACK, GL_LINE);

    // render loop
    // -----------
    while (glfwWindowShouldClose(window) == 0) {
        // input
        processInput(window);

        // render

        glClearColor(0.2, 0.3, 0.3, 1.0);
        glClear(GL_COLOR_BUFFER_BIT);

        // draw our first triangle
        glUseProgram(shaderProgram);
        glBindVertexArray(VAO); // seeing as we only have a single VAO there's no need to bind it every time, but we'll do so to keep things a bit more organized
        //glDrawArrays(GL_TRIANGLES, 0, 6);
        glDrawElements(GL_TRIANGLES, 6, GL_UNSIGNED_INT, null);
        // glBindVertexArray(0); // no need to unbind it every time

        // glfw: swap buffers and poll IO events (keys pressed/released, mouse moved etc.)

        glfwSwapBuffers(window);
        glfwPollEvents();
    }
}

// process all input: query GLFW whether relevant keys are pressed/released this frame and react accordingly
pub extern fn processInput(window: ?*GLFWwindow) void {
    if (glfwGetKey(window, GLFW_KEY_ESCAPE) == GLFW_PRESS)
        glfwSetWindowShouldClose(window, 1);
}

// glfw: whenever the window size changed (by OS or user resize) this callback function executes
pub extern fn framebuffer_size_callback(window: ?*GLFWwindow, width: c_int, height: c_int) void {
    // make sure the viewport matches the new window dimensions; note that width and
    // height will be significantly larger than specified on retina displays.
    glViewport(0, 0, width, height);
}
