const std = @import("std");
const panic = std.debug.panic;
const builtin = @import("builtin");
const warn = std.debug.warn;
const join = std.fs.path.join;
const pi = std.math.pi;
const sin = std.math.sin;

usingnamespace @import("c.zig");

const Camera = @import("camera.zig").Camera;
const Shader = @import("shader.zig").Shader;

const glm = @import("glm.zig");
const Mat4 = glm.Mat4;
const Vec3 = glm.Vec3;
const vec3 = glm.vec3;
const translation = glm.translation;
const rotation = glm.rotation;
const scale = glm.scale;
const perspective = glm.perspective;

// settings
const SCR_WIDTH: u32 = 1920;
const SCR_HEIGHT: u32 = 1080;

// camera
var camera = Camera.default();
var lastX: f32 = 1920.0 / 2.0;
var lastY: f32 = 1080.0 / 2.0;
var firstMouse = true;

// timing
var deltaTime: f32 = 0.0; // time between current frame and last frame
var lastFrame: f32 = 0.0;

// lighting
const lightPos = vec3(1.2, 1.0, 2.0);

pub fn main() !void {
    const allocator = std.heap.page_allocator;
    const lampVertPath = try join(allocator, &[_][]const u8{ "shaders", "2_0_lamp.vert" });
    const lampFragPath = try join(allocator, &[_][]const u8{ "shaders", "2_0_lamp.frag" });
    const cubeVertPath = try join(allocator, &[_][]const u8{ "shaders", "2_4_lighting_maps.vert" });
    const cubeFragPath = try join(allocator, &[_][]const u8{ "shaders", "2_4_lighting_maps.frag" });

    const ok = glfwInit();
    if (ok == 0) {
        panic("Failed to initialise GLFW\n", .{});
    }
    defer glfwTerminate();

    glfwWindowHint(GLFW_CONTEXT_VERSION_MAJOR, 3);
    glfwWindowHint(GLFW_CONTEXT_VERSION_MINOR, 3);
    glfwWindowHint(GLFW_OPENGL_PROFILE, GLFW_OPENGL_CORE_PROFILE);
    glfwWindowHint(GLFW_OPENGL_FORWARD_COMPAT, GL_TRUE);

    // glfw: initialize and configure
    var window = glfwCreateWindow(SCR_WIDTH, SCR_HEIGHT, "Learn OpenGL", null, null);
    if (window == null) {
        panic("Failed to create GLFW window\n", .{});
    }

    glfwMakeContextCurrent(window);
    const resizeCallback = glfwSetFramebufferSizeCallback(window, framebuffer_size_callback);
    const posCallback = glfwSetCursorPosCallback(window, mouse_callback);
    const scrollCallback = glfwSetScrollCallback(window, scroll_callback);

    // tell GLFW to capture our mouse
    glfwSetInputMode(window, GLFW_CURSOR, GLFW_CURSOR_DISABLED);

    // glad: load all OpenGL function pointers
    if (gladLoadGLLoader(@ptrCast(GLADloadproc, glfwGetProcAddress)) == 0) {
        panic("Failed to initialise GLAD\n", .{});
    }

    glEnable(GL_DEPTH_TEST);

    // build and compile our shader zprogram
    const cubeShader = try Shader.init(allocator, cubeVertPath, cubeFragPath);
    const lampShader = try Shader.init(allocator, lampVertPath, lampFragPath);

    // set up vertex data (and buffer(s)) and configure vertex attributes
    const vertices = [_]f32{
        // positions       // normals        // texture coords
        -0.5, -0.5, -0.5, 0.0,  0.0,  -1.0, 0.0, 0.0,
        0.5,  -0.5, -0.5, 0.0,  0.0,  -1.0, 1.0, 0.0,
        0.5,  0.5,  -0.5, 0.0,  0.0,  -1.0, 1.0, 1.0,
        0.5,  0.5,  -0.5, 0.0,  0.0,  -1.0, 1.0, 1.0,
        -0.5, 0.5,  -0.5, 0.0,  0.0,  -1.0, 0.0, 1.0,
        -0.5, -0.5, -0.5, 0.0,  0.0,  -1.0, 0.0, 0.0,

        -0.5, -0.5, 0.5,  0.0,  0.0,  1.0,  0.0, 0.0,
        0.5,  -0.5, 0.5,  0.0,  0.0,  1.0,  1.0, 0.0,
        0.5,  0.5,  0.5,  0.0,  0.0,  1.0,  1.0, 1.0,
        0.5,  0.5,  0.5,  0.0,  0.0,  1.0,  1.0, 1.0,
        -0.5, 0.5,  0.5,  0.0,  0.0,  1.0,  0.0, 1.0,
        -0.5, -0.5, 0.5,  0.0,  0.0,  1.0,  0.0, 0.0,

        -0.5, 0.5,  0.5,  -1.0, 0.0,  0.0,  1.0, 0.0,
        -0.5, 0.5,  -0.5, -1.0, 0.0,  0.0,  1.0, 1.0,
        -0.5, -0.5, -0.5, -1.0, 0.0,  0.0,  0.0, 1.0,
        -0.5, -0.5, -0.5, -1.0, 0.0,  0.0,  0.0, 1.0,
        -0.5, -0.5, 0.5,  -1.0, 0.0,  0.0,  0.0, 0.0,
        -0.5, 0.5,  0.5,  -1.0, 0.0,  0.0,  1.0, 0.0,

        0.5,  0.5,  0.5,  1.0,  0.0,  0.0,  1.0, 0.0,
        0.5,  0.5,  -0.5, 1.0,  0.0,  0.0,  1.0, 1.0,
        0.5,  -0.5, -0.5, 1.0,  0.0,  0.0,  0.0, 1.0,
        0.5,  -0.5, -0.5, 1.0,  0.0,  0.0,  0.0, 1.0,
        0.5,  -0.5, 0.5,  1.0,  0.0,  0.0,  0.0, 0.0,
        0.5,  0.5,  0.5,  1.0,  0.0,  0.0,  1.0, 0.0,

        -0.5, -0.5, -0.5, 0.0,  -1.0, 0.0,  0.0, 1.0,
        0.5,  -0.5, -0.5, 0.0,  -1.0, 0.0,  1.0, 1.0,
        0.5,  -0.5, 0.5,  0.0,  -1.0, 0.0,  1.0, 0.0,
        0.5,  -0.5, 0.5,  0.0,  -1.0, 0.0,  1.0, 0.0,
        -0.5, -0.5, 0.5,  0.0,  -1.0, 0.0,  0.0, 0.0,
        -0.5, -0.5, -0.5, 0.0,  -1.0, 0.0,  0.0, 1.0,

        -0.5, 0.5,  -0.5, 0.0,  1.0,  0.0,  0.0, 1.0,
        0.5,  0.5,  -0.5, 0.0,  1.0,  0.0,  1.0, 1.0,
        0.5,  0.5,  0.5,  0.0,  1.0,  0.0,  1.0, 0.0,
        0.5,  0.5,  0.5,  0.0,  1.0,  0.0,  1.0, 0.0,
        -0.5, 0.5,  0.5,  0.0,  1.0,  0.0,  0.0, 0.0,
        -0.5, 0.5,  -0.5, 0.0,  1.0,  0.0,  0.0, 1.0,
    };
    // first, configure the cube's VAO (and VBO)
    var VBO: c_uint = undefined;
    var cubeVAO: c_uint = undefined;
    glGenVertexArrays(1, &cubeVAO);
    glGenBuffers(1, &VBO);

    glBindBuffer(GL_ARRAY_BUFFER, VBO);
    glBufferData(GL_ARRAY_BUFFER, vertices.len * @sizeOf(f32), &vertices, GL_STATIC_DRAW);

    glBindVertexArray(cubeVAO);
    glVertexAttribPointer(0, 3, GL_FLOAT, GL_FALSE, 8 * @sizeOf(f32), null);
    glEnableVertexAttribArray(0);
    glVertexAttribPointer(1, 3, GL_FLOAT, GL_FALSE, 8 * @sizeOf(f32), @intToPtr(*c_void, 3 * @sizeOf(f32)));
    glEnableVertexAttribArray(1);
    glVertexAttribPointer(2, 2, GL_FLOAT, GL_FALSE, 8 * @sizeOf(f32), @intToPtr(*c_void, 6 * @sizeOf(f32)));
    glEnableVertexAttribArray(2);

    // second, configure the light's VAO (VBO stays the same; the vertices are the same for the light object which is also a 3D cube)
    var lampVAO: c_uint = undefined;
    glGenVertexArrays(1, &lampVAO);
    glBindVertexArray(lampVAO);

    glBindBuffer(GL_ARRAY_BUFFER, VBO);
    // note that we update the lamp's position attribute's stride to reflect the updated buffer data
    glVertexAttribPointer(0, 3, GL_FLOAT, GL_FALSE, 8 * @sizeOf(f32), null);
    glEnableVertexAttribArray(0);

    // load textures (we now use a utility function to keep the code more organized)
    const diffuseMap = loadTexture("textures/container2.png");
    const specularMap = loadTexture("textures/container2_specular.png");

    // shader configuration
    cubeShader.use();
    cubeShader.setInt("material.diffuse", 0);
    cubeShader.setInt("material.specular", 1);

    // render loop

    while (glfwWindowShouldClose(window) == 0) {
        // per-frame time logic
        const currentFrame = @floatCast(f32, glfwGetTime());
        deltaTime = currentFrame - lastFrame;
        lastFrame = currentFrame;

        // input
        processInput(window);

        // render
        glClearColor(0.1, 0.1, 0.1, 0.1);
        glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);

        // be sure to activate shader when setting uniforms/drawing objects
        cubeShader.use();
        cubeShader.setVec3("light.position", lightPos);
        cubeShader.setVec3("viewPos", camera.position);

        // light properties
        cubeShader.setVec3("light.ambient", vec3(0.2, 0.2, 0.2));
        cubeShader.setVec3("light.diffuse", vec3(0.5, 0.5, 0.5));
        cubeShader.setVec3("light.specular", vec3(1.0, 1.0, 1.0));

        // material properties
        cubeShader.setFloat("material.shininess", 64.0);

        // view/projection transformations
        const projection = perspective(camera.zoom / 180.0 * pi, @intToFloat(f32, SCR_WIDTH) / @intToFloat(f32, SCR_HEIGHT), 0.1, 100.0);
        const view = camera.getViewMatrix();
        cubeShader.setMat4("projection", projection);
        cubeShader.setMat4("view", view);

        // world transformation
        const cubeModel = Mat4.identity();
        cubeShader.setMat4("model", cubeModel);

        // bind diffuse map
        glActiveTexture(GL_TEXTURE0);
        glBindTexture(GL_TEXTURE_2D, diffuseMap);
        // bind specular map
        glActiveTexture(GL_TEXTURE1);
        glBindTexture(GL_TEXTURE_2D, specularMap);

        // render the cube
        glBindVertexArray(cubeVAO);
        glDrawArrays(GL_TRIANGLES, 0, 36);

        // also draw the lamp object
        lampShader.use();
        lampShader.setMat4("projection", projection);
        lampShader.setMat4("view", view);
        const lampModel = translation(lightPos).matmul(scale(vec3(0.2, 0.2, 0.2)));
        lampShader.setMat4("model", lampModel);

        glBindVertexArray(lampVAO);
        glDrawArrays(GL_TRIANGLES, 0, 36);

        // glfw: swap buffers and poll IO events (keys pressed/released, mouse moved etc.)
        glfwSwapBuffers(window);
        glfwPollEvents();
    }
}

// process all input: query GLFW whether relevant keys are pressed/released this frame and react accordingly
pub fn processInput(window: ?*GLFWwindow) callconv(.C) void {
    if (glfwGetKey(window, GLFW_KEY_ESCAPE) == GLFW_PRESS)
        glfwSetWindowShouldClose(window, 1);

    if (glfwGetKey(window, GLFW_KEY_W) == GLFW_PRESS)
        camera.processKeyboard(.Forward, deltaTime);
    if (glfwGetKey(window, GLFW_KEY_S) == GLFW_PRESS)
        camera.processKeyboard(.Backward, deltaTime);
    if (glfwGetKey(window, GLFW_KEY_A) == GLFW_PRESS)
        camera.processKeyboard(.Left, deltaTime);
    if (glfwGetKey(window, GLFW_KEY_D) == GLFW_PRESS)
        camera.processKeyboard(.Right, deltaTime);
}

// glfw: whenever the window size changed (by OS or user resize) this callback function executes
pub fn framebuffer_size_callback(window: ?*GLFWwindow, width: c_int, height: c_int) callconv(.C) void {
    // make sure the viewport matches the new window dimensions; note that width and
    // height will be significantly larger than specified on retina displays.
    glViewport(0, 0, width, height);
}

// glfw: whenever the mouse moves, this callback is called
pub fn mouse_callback(window: ?*GLFWwindow, xpos: f64, ypos: f64) callconv(.C) void {
    if (firstMouse) {
        lastX = @floatCast(f32, xpos);
        lastY = @floatCast(f32, ypos);
        firstMouse = false;
    }

    const xoffset = @floatCast(f32, xpos) - lastX;
    const yoffset = lastY - @floatCast(f32, ypos); // reversed since y-coordinates go from bottom to top

    lastX = @floatCast(f32, xpos);
    lastY = @floatCast(f32, ypos);

    camera.processMouseMovement(xoffset, yoffset);
}

// glfw: whenever the mouse scroll wheel scrolls, this callback is called
pub fn scroll_callback(window: ?*GLFWwindow, xoffset: f64, yoffset: f64) callconv(.C) void {
    camera.processMouseScroll(@floatCast(f32, yoffset));
}

// utility function for loading a 2D texture from file
pub fn loadTexture(path: [:0]const u8) c_uint {
    var textureID: c_uint = undefined;
    glGenTextures(1, &textureID);

    var width: c_int = undefined;
    var height: c_int = undefined;
    var nrChannels: c_int = undefined;
    const data = stbi_load(path, &width, &height, &nrChannels, 0);
    if (data != null) {
        var format: GLenum = undefined;
        if (nrChannels == 1) {
            format = GL_RED;
        } else if (nrChannels == 3) {
            format = GL_RGB;
        } else if (nrChannels == 4) {
            format = GL_RGBA;
        }

        glBindTexture(GL_TEXTURE_2D, textureID);
        glTexImage2D(GL_TEXTURE_2D, 0, @intCast(c_int, format), width, height, 0, format, GL_UNSIGNED_BYTE, data);
        glGenerateMipmap(GL_TEXTURE_2D);

        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_REPEAT);
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_REPEAT);
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR_MIPMAP_LINEAR);
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);

        stbi_image_free(data);
    } else {
        warn("Failed to load texture at path: {s}\n", .{path});
    }

    return textureID;
}
