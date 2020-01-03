const std = @import("std");
const panic = std.debug.panic;
const builtin = @import("builtin");
const warn = std.debug.warn;
const join = std.fs.path.join;
const pi = std.math.pi;
const sin = std.math.sin;
const cos = std.math.cos;

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
    const cubeVertPath = try join(allocator, &[_][]const u8{ "shaders", "2_6_multiple_lights.vert" });
    const cubeFragPath = try join(allocator, &[_][]const u8{ "shaders", "2_6_multiple_lights.frag" });

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

    // world space positions of our cubes
    const cubePositions = [_]Vec3{
        vec3(0.0, 0.0, 0.0),
        vec3(2.0, 5.0, -15.0),
        vec3(-1.5, -2.2, -2.5),
        vec3(-3.8, -2.0, -12.3),
        vec3(2.4, -0.4, -3.5),
        vec3(-1.7, 3.0, -7.5),
        vec3(1.3, -2.0, -2.5),
        vec3(1.5, 2.0, -2.5),
        vec3(1.5, 0.2, -1.5),
        vec3(-1.3, 1.0, -1.5),
    };
    //     // positions of the point lights
    const pointLightPositions = [_]Vec3{
        vec3(0.7, 0.2, 2.0),
        vec3(2.3, -3.3, -4.0),
        vec3(-4.0, 2.0, -12.0),
        vec3(0.0, 0.0, -3.0),
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
        cubeShader.setVec3("viewPos", camera.position);
        cubeShader.setFloat("material.shininess", 32.0);

        // Here we set all the uniforms for the 5/6 types of lights we have. We have to set them manually and index
        // the proper PointLight struct in the array to set each uniform variable. This can be done more code-friendly
        // by defining light types as classes and set their values in there, or by using a more efficient uniform approach
        // by using 'Uniform buffer objects', but that is something we'll discuss in the 'Advanced GLSL' tutorial.

        // directional light
        cubeShader.setVec3("dirLight.direction", vec3(-0.2, -1.0, -0.3));
        cubeShader.setVec3("dirLight.ambient", vec3(0.05, 0.05, 0.05));
        cubeShader.setVec3("dirLight.diffuse", vec3(0.4, 0.4, 0.4));
        cubeShader.setVec3("dirLight.specular", vec3(0.5, 0.5, 0.5));
        // point light 1
        cubeShader.setVec3("pointLights[0].position", pointLightPositions[0]);
        cubeShader.setVec3("pointLights[0].ambient", vec3(0.05, 0.05, 0.05));
        cubeShader.setVec3("pointLights[0].diffuse", vec3(0.8, 0.8, 0.8));
        cubeShader.setVec3("pointLights[0].specular", vec3(1.0, 1.0, 1.0));
        cubeShader.setFloat("pointLights[0].constant", 1.0);
        cubeShader.setFloat("pointLights[0].linear", 0.09);
        cubeShader.setFloat("pointLights[0].quadratic", 0.032);
        // point light 2
        cubeShader.setVec3("pointLights[1].position", pointLightPositions[1]);
        cubeShader.setVec3("pointLights[1].ambient", vec3(0.05, 0.05, 0.05));
        cubeShader.setVec3("pointLights[1].diffuse", vec3(0.8, 0.8, 0.8));
        cubeShader.setVec3("pointLights[1].specular", vec3(1.0, 1.0, 1.0));
        cubeShader.setFloat("pointLights[1].constant", 1.0);
        cubeShader.setFloat("pointLights[1].linear", 0.09);
        cubeShader.setFloat("pointLights[1].quadratic", 0.032);
        // point light 3
        cubeShader.setVec3("pointLights[2].position", pointLightPositions[2]);
        cubeShader.setVec3("pointLights[2].ambient", vec3(0.05, 0.05, 0.05));
        cubeShader.setVec3("pointLights[2].diffuse", vec3(0.8, 0.8, 0.8));
        cubeShader.setVec3("pointLights[2].specular", vec3(1.0, 1.0, 1.0));
        cubeShader.setFloat("pointLights[2].constant", 1.0);
        cubeShader.setFloat("pointLights[2].linear", 0.09);
        cubeShader.setFloat("pointLights[2].quadratic", 0.032);
        // point light 4
        cubeShader.setVec3("pointLights[3].position", pointLightPositions[3]);
        cubeShader.setVec3("pointLights[3].ambient", vec3(0.05, 0.05, 0.05));
        cubeShader.setVec3("pointLights[3].diffuse", vec3(0.8, 0.8, 0.8));
        cubeShader.setVec3("pointLights[3].specular", vec3(1.0, 1.0, 1.0));
        cubeShader.setFloat("pointLights[3].constant", 1.0);
        cubeShader.setFloat("pointLights[3].linear", 0.09);
        cubeShader.setFloat("pointLights[3].quadratic", 0.032);
        // spotLight
        cubeShader.setVec3("spotLight.position", camera.position);
        cubeShader.setVec3("spotLight.direction", camera.front);
        cubeShader.setVec3("spotLight.ambient", vec3(0.0, 0.0, 0.0));
        cubeShader.setVec3("spotLight.diffuse", vec3(1.0, 1.0, 1.0));
        cubeShader.setVec3("spotLight.specular", vec3(1.0, 1.0, 1.0));
        cubeShader.setFloat("spotLight.constant", 1.0);
        cubeShader.setFloat("spotLight.linear", 0.09);
        cubeShader.setFloat("spotLight.quadratic", 0.032);
        cubeShader.setFloat("spotLight.cutOff", cos(@floatCast(f32, 12.5 / 180.0 * pi)));
        cubeShader.setFloat("spotLight.outerCutOff", cos(@floatCast(f32, 15.0 / 180.0 * pi)));

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

        // render boxes
        glBindVertexArray(cubeVAO);
        var i: usize = 0;
        while (i < 10) : (i += 1) {
            // calculate the model matrix for each object and pass it to shader before drawing
            const model = translation(cubePositions[i]);
            const angle = 20.0 * @intToFloat(f32, i);
            model = model.matmul(rotation(angle / 180.0 * pi, vec3(1.0, 0.3, 0.5)));
            cubeShader.setMat4("model", model);

            glDrawArrays(GL_TRIANGLES, 0, 36);
        }

        // glfw: swap buffers and poll IO events (keys pressed/released, mouse moved etc.)
        glfwSwapBuffers(window);
        glfwPollEvents();
    }
}

// process all input: query GLFW whether relevant keys are pressed/released this frame and react accordingly
pub extern fn processInput(window: ?*GLFWwindow) void {
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
pub extern fn framebuffer_size_callback(window: ?*GLFWwindow, width: c_int, height: c_int) void {
    // make sure the viewport matches the new window dimensions; note that width and
    // height will be significantly larger than specified on retina displays.
    glViewport(0, 0, width, height);
}

// glfw: whenever the mouse moves, this callback is called
pub extern fn mouse_callback(window: ?*GLFWwindow, xpos: f64, ypos: f64) void {
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
pub extern fn scroll_callback(window: ?*GLFWwindow, xoffset: f64, yoffset: f64) void {
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
        warn("Failed to load texture at path: {}\n", .{path});
    }

    return textureID;
}
