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
const clamp = glm.clamp;
const translation = glm.translation;
const rotation = glm.rotation;
const scale = glm.scale;
const perspective = glm.perspective;
const lookAt = glm.lookAt;

// settings
const SCR_WIDTH: u32 = 1920;
const SCR_HEIGHT: u32 = 1080;

// camera
var camera = Camera.default();
var lastX: f32 = 1920.0 / 2.0;
var lastY: f32 = 1080.0 / 2.0;
var firstMouse = true;

// timing
var deltaTime: f32 = 0.0;
var lastFrame: f32 = 0.0;

pub fn main() !void {
    camera.movementSpeed = 10.0;

    const allocator = std.heap.page_allocator;

    // Shader paths
    const backgroundFragPath = try join(allocator, &[_][]const u8{ "shaders", "6_2_2_background.frag" });
    const backgroundVertPath = try join(allocator, &[_][]const u8{ "shaders", "6_2_2_background.vert" });
    const brdfFragPath = try join(allocator, &[_][]const u8{ "shaders", "6_2_2_brdf.frag" });
    const brdfVertPath = try join(allocator, &[_][]const u8{ "shaders", "6_2_2_brdf.vert" });
    const cubemapVertPath = try join(allocator, &[_][]const u8{ "shaders", "6_2_2_cubemap.vert" });
    const equirectFragPath = try join(allocator, &[_][]const u8{ "shaders", "6_2_2_equirectangular_to_cubemap.frag" });
    const irradianceFragPath = try join(allocator, &[_][]const u8{ "shaders", "6_2_2_irradiance_convolution.frag" });
    const pbrFragPath = try join(allocator, &[_][]const u8{ "shaders", "6_2_2_pbr.frag" });
    const pbrVertPath = try join(allocator, &[_][]const u8{ "shaders", "6_2_2_pbr.vert" });
    const prefilterFragPath = try join(allocator, &[_][]const u8{ "shaders", "6_2_2_prefilter.frag" });

    const ok = glfwInit();
    if (ok == 0) {
        panic("Failed to initialise GLFW\n", .{});
    }
    defer glfwTerminate();

    glfwWindowHint(GLFW_CONTEXT_VERSION_MAJOR, 3);
    glfwWindowHint(GLFW_CONTEXT_VERSION_MINOR, 3);
    glfwWindowHint(GLFW_SAMPLES, 4);
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
    // set depth function to less than AND equal for skybox depth trick.
    glDepthFunc(GL_LEQUAL);
    // enable seamless cubemap sampling for lower mip levels in the pre-filter map.
    glEnable(GL_TEXTURE_CUBE_MAP_SEAMLESS);

    const cube = Cube.init();
    const sphere = Sphere.init();
    const quad = Quad.init();

    // build and compile shaders
    const pbrShader = try Shader.init(allocator, pbrVertPath, pbrFragPath);
    const equirectangularToCubemapShader = try Shader.init(allocator, cubemapVertPath, equirectFragPath);
    const irradianceShader = try Shader.init(allocator, cubemapVertPath, irradianceFragPath);
    const prefilterShader = try Shader.init(allocator, cubemapVertPath, prefilterFragPath);
    const brdfShader = try Shader.init(allocator, brdfVertPath, brdfFragPath);
    const backgroundShader = try Shader.init(allocator, backgroundVertPath, backgroundFragPath);

    pbrShader.use();
    pbrShader.setInt("irradianceMap", 0);
    pbrShader.setInt("prefilterMap", 1);
    pbrShader.setInt("brdfLUT", 2);
    pbrShader.setVec3("albedo", vec3(0.5, 0.0, 0.0));
    pbrShader.setFloat("ao", 1.0);

    backgroundShader.use();
    backgroundShader.setInt("environmentMap", 0);

    // lights
    const lightPositions = [_]Vec3{
        vec3(-10.0, 10.0, 10.0),
        vec3(10.0, 10.0, 10.0),
        vec3(-10.0, -10.0, 10.0),
        vec3(10.0, -10.0, 10.0),
    };
    const lightColors = [_]Vec3{
        vec3(300.0, 300.0, 300.0),
        vec3(300.0, 300.0, 300.0),
        vec3(300.0, 300.0, 300.0),
        vec3(300.0, 300.0, 300.0),
    };
    const nrRows = 7;
    const nrColumns = 7;
    const spacing: f32 = 2.5;

    // pbr: setup framebuffer
    var captureFBO: c_uint = undefined;
    var captureRBO: c_uint = undefined;
    glGenFramebuffers(1, &captureFBO);
    glGenRenderbuffers(1, &captureRBO);

    glBindFramebuffer(GL_FRAMEBUFFER, captureFBO);
    glBindRenderbuffer(GL_RENDERBUFFER, captureRBO);
    glRenderbufferStorage(GL_RENDERBUFFER, GL_DEPTH_COMPONENT24, 512, 512);
    glFramebufferRenderbuffer(GL_FRAMEBUFFER, GL_DEPTH_ATTACHMENT, GL_RENDERBUFFER, captureRBO);

    // pbr: load the HDR environment map
    var width: c_int = undefined;
    var height: c_int = undefined;
    var nrComponents: c_int = undefined;
    stbi_set_flip_vertically_on_load(1);
    const data = stbi_loadf("textures/newport_loft.hdr", &width, &height, &nrComponents, 0);
    if (data == null) {
        panic("Failed to load HDR Image\n", .{});
    }

    var hdrTexture: c_uint = undefined;
    glGenTextures(1, &hdrTexture);
    glBindTexture(GL_TEXTURE_2D, hdrTexture);
    glTexImage2D(GL_TEXTURE_2D, 0, GL_RGB16F, width, height, 0, GL_RGB, GL_FLOAT, data); // note how we specify the texture's data value to be float

    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);

    // pbr: setup cubemap to render to and attach to framebuffer
    var envCubemap: c_uint = undefined;
    glGenTextures(1, &envCubemap);
    glBindTexture(GL_TEXTURE_CUBE_MAP, envCubemap);
    var i: c_uint = 0;
    while (i < 6) : (i += 1) {
        glTexImage2D(GL_TEXTURE_CUBE_MAP_POSITIVE_X + i, 0, GL_RGB16F, 512, 512, 0, GL_RGB, GL_FLOAT, null);
    }
    glTexParameteri(GL_TEXTURE_CUBE_MAP, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
    glTexParameteri(GL_TEXTURE_CUBE_MAP, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
    glTexParameteri(GL_TEXTURE_CUBE_MAP, GL_TEXTURE_WRAP_R, GL_CLAMP_TO_EDGE);
    glTexParameteri(GL_TEXTURE_CUBE_MAP, GL_TEXTURE_MIN_FILTER, GL_LINEAR_MIPMAP_LINEAR); // enable pre-filter mipmap sampling (combatting visible dots artifact)
    glTexParameteri(GL_TEXTURE_CUBE_MAP, GL_TEXTURE_MAG_FILTER, GL_LINEAR);

    // pbr: set up projection and view matrices for capturing data onto the 6 cubemap face directions
    const captureProjection = perspective(pi / 2.0, 1.0, 0.1, 10.0);
    const captureViews = [_]Mat4{
        lookAt(vec3(0.0, 0.0, 0.0), vec3(1.0, 0.0, 0.0), vec3(0.0, -1.0, 0.0)),
        lookAt(vec3(0.0, 0.0, 0.0), vec3(-1.0, 0.0, 0.0), vec3(0.0, -1.0, 0.0)),
        lookAt(vec3(0.0, 0.0, 0.0), vec3(0.0, 1.0, 0.0), vec3(0.0, 0.0, 1.0)),
        lookAt(vec3(0.0, 0.0, 0.0), vec3(0.0, -1.0, 0.0), vec3(0.0, 0.0, -1.0)),
        lookAt(vec3(0.0, 0.0, 0.0), vec3(0.0, 0.0, 1.0), vec3(0.0, -1.0, 0.0)),
        lookAt(vec3(0.0, 0.0, 0.0), vec3(0.0, 0.0, -1.0), vec3(0.0, -1.0, 0.0)),
    };

    // pbr: convert HDR equirectangular environment map to cubemap equivalent
    equirectangularToCubemapShader.use();
    equirectangularToCubemapShader.setInt("equirectangularMap", 0);
    equirectangularToCubemapShader.setMat4("projection", captureProjection);
    glActiveTexture(GL_TEXTURE0);
    glBindTexture(GL_TEXTURE_2D, hdrTexture);

    glViewport(0, 0, 512, 512); // don't forget to configure the viewport to the capture dimensions.
    glBindFramebuffer(GL_FRAMEBUFFER, captureFBO);
    i = 0;
    while (i < 6) : (i += 1) {
        equirectangularToCubemapShader.setMat4("view", captureViews[i]);
        glFramebufferTexture2D(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0, GL_TEXTURE_CUBE_MAP_POSITIVE_X + i, envCubemap, 0);
        glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);
        cube.render();
    }
    glBindFramebuffer(GL_FRAMEBUFFER, 0);

    // then let OpenGL generate mipmaps from first mip face (combatting visible dots artifact)
    glBindTexture(GL_TEXTURE_CUBE_MAP, envCubemap);
    glGenerateMipmap(GL_TEXTURE_CUBE_MAP);

    // pbr: create an irradiance cubemap, and re-scale capture FBO to irradiance scale.
    var irradianceMap: c_uint = undefined;
    glGenTextures(1, &irradianceMap);
    glBindTexture(GL_TEXTURE_CUBE_MAP, irradianceMap);
    i = 0;
    while (i < 6) : (i += 1) {
        glTexImage2D(GL_TEXTURE_CUBE_MAP_POSITIVE_X + i, 0, GL_RGB16F, 32, 32, 0, GL_RGB, GL_FLOAT, null);
    }
    glTexParameteri(GL_TEXTURE_CUBE_MAP, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
    glTexParameteri(GL_TEXTURE_CUBE_MAP, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
    glTexParameteri(GL_TEXTURE_CUBE_MAP, GL_TEXTURE_WRAP_R, GL_CLAMP_TO_EDGE);
    glTexParameteri(GL_TEXTURE_CUBE_MAP, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
    glTexParameteri(GL_TEXTURE_CUBE_MAP, GL_TEXTURE_MAG_FILTER, GL_LINEAR);

    glBindFramebuffer(GL_FRAMEBUFFER, captureFBO);
    glBindRenderbuffer(GL_RENDERBUFFER, captureRBO);
    glRenderbufferStorage(GL_RENDERBUFFER, GL_DEPTH_COMPONENT24, 32, 32);

    // pbr: solve diffuse integral by convolution to create an irradiance (cube)map.
    irradianceShader.use();
    irradianceShader.setInt("environmentMap", 0);
    irradianceShader.setMat4("projection", captureProjection);
    glActiveTexture(GL_TEXTURE0);
    glBindTexture(GL_TEXTURE_CUBE_MAP, envCubemap);

    glViewport(0, 0, 32, 32); // don't forget to configure the viewport to the capture dimensions.
    glBindFramebuffer(GL_FRAMEBUFFER, captureFBO);
    i = 0;
    while (i < 6) : (i += 1) {
        irradianceShader.setMat4("view", captureViews[i]);
        glFramebufferTexture2D(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0, GL_TEXTURE_CUBE_MAP_POSITIVE_X + i, irradianceMap, 0);
        glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);
        cube.render();
    }
    glBindFramebuffer(GL_FRAMEBUFFER, 0);

    // pbr: create a pre-filter cubemap, and re-scale capture FBO to pre-filter scale.
    var prefilterMap: c_uint = undefined;
    glGenTextures(1, &prefilterMap);
    glBindTexture(GL_TEXTURE_CUBE_MAP, prefilterMap);
    i = 0;
    while (i < 6) : (i += 1) {
        glTexImage2D(GL_TEXTURE_CUBE_MAP_POSITIVE_X + i, 0, GL_RGB16F, 128, 128, 0, GL_RGB, GL_FLOAT, null);
    }
    glTexParameteri(GL_TEXTURE_CUBE_MAP, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
    glTexParameteri(GL_TEXTURE_CUBE_MAP, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
    glTexParameteri(GL_TEXTURE_CUBE_MAP, GL_TEXTURE_WRAP_R, GL_CLAMP_TO_EDGE);
    glTexParameteri(GL_TEXTURE_CUBE_MAP, GL_TEXTURE_MIN_FILTER, GL_LINEAR_MIPMAP_LINEAR); // be sure to set minifcation filter to mip_linear
    glTexParameteri(GL_TEXTURE_CUBE_MAP, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
    // generate mipmaps for the cubemap so OpenGL automatically allocates the required memory.
    glGenerateMipmap(GL_TEXTURE_CUBE_MAP);

    // pbr: run a quasi monte-carlo simulation on the environment lighting to create a prefilter (cube)map.
    prefilterShader.use();
    prefilterShader.setInt("environmentMap", 0);
    prefilterShader.setMat4("projection", captureProjection);
    glActiveTexture(GL_TEXTURE0);
    glBindTexture(GL_TEXTURE_CUBE_MAP, envCubemap);

    glBindFramebuffer(GL_FRAMEBUFFER, captureFBO);
    var mip: c_uint = 0;
    while (mip < 5) : (mip += 1) {
        // reisze framebuffer according to mip-level size.
        const okayThen: c_uint = 128;
        const mipWidth: c_uint = okayThen >> @intCast(u5, mip);
        const mipHeight: c_uint = okayThen >> @intCast(u5, mip);
        glBindRenderbuffer(GL_RENDERBUFFER, captureRBO);
        glRenderbufferStorage(GL_RENDERBUFFER, GL_DEPTH_COMPONENT24, @intCast(c_int, mipWidth), @intCast(c_int, mipHeight));
        glViewport(0, 0, @intCast(c_int, mipWidth), @intCast(c_int, mipHeight));

        const roughness = @intToFloat(f32, mip) / @intToFloat(f32, 5 - 1);
        prefilterShader.setFloat("roughness", roughness);
        i = 0;
        while (i < 6) : (i += 1) {
            prefilterShader.setMat4("view", captureViews[i]);
            glFramebufferTexture2D(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0, GL_TEXTURE_CUBE_MAP_POSITIVE_X + i, prefilterMap, @intCast(c_int, mip));
            glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);
            cube.render();
        }
    }
    glBindFramebuffer(GL_FRAMEBUFFER, 0);

    // pbr: generate a 2D LUT from the BRDF equations used.
    var brdfLUTTexture: c_uint = undefined;
    glGenTextures(1, &brdfLUTTexture);

    // pre-allocate enough memory for the LUT texture.
    glBindTexture(GL_TEXTURE_2D, brdfLUTTexture);
    glTexImage2D(GL_TEXTURE_2D, 0, GL_RG16F, 512, 512, 0, GL_RG, GL_FLOAT, null);
    // be sure to set wrapping mode to GL_CLAMP_TO_EDGE
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);

    // then re-configure capture framebuffer object and render screen-space quad with BRDF shader.
    glBindFramebuffer(GL_FRAMEBUFFER, captureFBO);
    glBindRenderbuffer(GL_RENDERBUFFER, captureRBO);
    glRenderbufferStorage(GL_RENDERBUFFER, GL_DEPTH_COMPONENT24, 512, 512);
    glFramebufferTexture2D(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0, GL_TEXTURE_2D, brdfLUTTexture, 0);

    glViewport(0, 0, 512, 512);
    brdfShader.use();
    glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);
    quad.render();

    glBindFramebuffer(GL_FRAMEBUFFER, 0);



    // then before rendering, configure the viewport to the original framebuffer's screen dimensions
    var scrWidth: c_int = undefined;
    var scrHeight: c_int = undefined;
    glfwGetFramebufferSize(window, &scrWidth, &scrHeight);
    glViewport(0, 0, scrWidth, scrHeight);

    // render loop
    while (glfwWindowShouldClose(window) == 0) {
        // initialize static shader uniforms before rendering
        const projection = perspective(camera.zoom / 180.0 * pi, @intToFloat(f32, SCR_WIDTH) / @intToFloat(f32, SCR_HEIGHT), 0.1, 100.0);
        pbrShader.use();
        pbrShader.setMat4("projection", projection);
        backgroundShader.use();
        backgroundShader.setMat4("projection", projection);

        // per-frame time logic
        const currentFrame = @floatCast(f32, glfwGetTime());
        deltaTime = currentFrame - lastFrame;
        lastFrame = currentFrame;

        // input
        processInput(window);

        // render
        glClearColor(0.2, 0.3, 0.3, 1.0);
        glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);

        // render scene, supplying the convoluted irradiance map to the final shader.
        pbrShader.use();
        const view = camera.getViewMatrix();
        pbrShader.setMat4("view", view);
        pbrShader.setVec3("camPos", camera.position);

        // bind pre-computed IBL data
        glActiveTexture(GL_TEXTURE0);
        glBindTexture(GL_TEXTURE_CUBE_MAP, irradianceMap);
        glActiveTexture(GL_TEXTURE1);
        glBindTexture(GL_TEXTURE_CUBE_MAP, prefilterMap);
        glActiveTexture(GL_TEXTURE2);
        glBindTexture(GL_TEXTURE_2D, brdfLUTTexture);

        // render rows*column number of spheres with material properties defined by textures (they all have the same material properties)
        var row: i32 = 0;
        while (row < nrRows) : (row += 1) {
            pbrShader.setFloat("metallic", @intToFloat(f32, row) / @intToFloat(f32, nrRows));
            var col: i32 = 0;
            while (col < nrColumns) : (col += 1) {
                // we clamp the roughness to 0.025 - 1.0 as perfectly smooth surfaces (roughness of 0.0) tend to look a bit off
                // on direct lighting.
                pbrShader.setFloat("roughness", clamp(@intToFloat(f32, col) / @intToFloat(f32, nrColumns), 0.05, 1.0));

                const model = translation(vec3(
                    @intToFloat(f32, col - (nrColumns / 2)) * spacing,
                    @intToFloat(f32, row - (nrRows / 2)) * spacing,
                    -2.0,
                ));
                pbrShader.setMat4("model", model);
                sphere.render();
            }
        }

        // render light source (simply re-render sphere at light positions)
        // this looks a bit off as we use the same shader, but it'll make their positions obvious and
        // keeps the codeprint small.

        // I am done
        const posNames = [_][:0]const u8{
            "lightPositions[0]",
            "lightPositions[1]",
            "lightPositions[2]",
            "lightPositions[3]",
        };

        const colNames = [_][:0]const u8{
            "lightColors[0]",
            "lightColors[1]",
            "lightColors[2]",
            "lightColors[3]",
        };

        i = 0;
        while (i < lightPositions.len) : (i += 1) {
            const newPos = lightPositions[i].add(vec3(sin(@floatCast(f32, glfwGetTime()) * 5.0 - @intToFloat(f32, i)) * 5.0, 0.0, 0.0));
            // const newPos = lightPositions[i];
            pbrShader.setVec3(posNames[i], newPos);
            pbrShader.setVec3(colNames[i], lightColors[i]);

            const model = translation(newPos).matmul(scale(vec3(0.5, 0.5, 0.5)));
            pbrShader.setMat4("model", model);
            sphere.render();
        }

        // render skybox (render as last to prevent overdraw)
        backgroundShader.use();
        backgroundShader.setMat4("view", view);
        glActiveTexture(GL_TEXTURE0);
        glBindTexture(GL_TEXTURE_CUBE_MAP, envCubemap);
        // glBindTexture(GL_TEXTURE_CUBE_MAP, irradianceMap); // display irradiance map
        // glBindTexture(GL_TEXTURE_CUBE_MAP, prefilterMap); // display prefilter map
        cube.render();

        // render BRDF map to screen
        // brdfShader.use();
        // quad.render();

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

// 64x64 segment UV Sphere
const Sphere = struct {
    vao: c_uint,
    vbo: c_uint,
    ebo: c_uint,
    len: c_uint,

    /// Initialise the sphere on the GPU
    pub fn init() Sphere {
        var vao: c_uint = undefined;
        var vbo: c_uint = undefined;
        var ebo: c_uint = undefined;

        glGenVertexArrays(1, &vao);
        glGenBuffers(1, &vbo);
        glGenBuffers(1, &ebo);

        const X_SEGMENTS = 256;
        const Y_SEGMENTS = 256;

        const numVertices = 8 * (X_SEGMENTS + 1) * (Y_SEGMENTS + 1);
        const numElements = 2 * (X_SEGMENTS + 1) * Y_SEGMENTS;

        // Stack allocated vertex, element buffers
        var vertices: [numVertices]f32 = undefined;
        var elements: [numElements]u32 = undefined;

        var i: u32 = 0;
        var y: u32 = 0;
        while (y <= Y_SEGMENTS) : (y += 1) {
            var x: u32 = 0;
            while (x <= X_SEGMENTS) : (x += 1) {
                const xSegment = @intToFloat(f32, x) / @intToFloat(f32, X_SEGMENTS);
                const ySegment = @intToFloat(f32, y) / @intToFloat(f32, Y_SEGMENTS);
                const xPos = cos(xSegment * 2.0 * pi) * sin(ySegment * pi);
                const yPos = cos(ySegment * pi);
                const zPos = sin(xSegment * 2.0 * pi) * sin(ySegment * pi);

                vertices[i + 0] = xPos;
                vertices[i + 1] = yPos;
                vertices[i + 2] = zPos;
                vertices[i + 3] = xSegment;
                vertices[i + 4] = ySegment;
                vertices[i + 5] = xPos;
                vertices[i + 6] = yPos;
                vertices[i + 7] = zPos;

                i += 8;
            }
        }

        i = 0;
        y = 0;
        while (y < Y_SEGMENTS) : (y += 1) {
            if (y % 2 == 0) {
                var x: u32 = 0;
                while (x <= X_SEGMENTS) : (x += 1) {
                    elements[i + 0] = y * (X_SEGMENTS + 1) + x;
                    elements[i + 1] = (y + 1) * (X_SEGMENTS + 1) + x;
                    i += 2;
                }
            } else {
                var x: u32 = X_SEGMENTS + 1;
                while (x > 0) : (x -= 1) {
                    elements[i + 0] = (y + 1) * (X_SEGMENTS + 1) + x - 1;
                    elements[i + 1] = y * (X_SEGMENTS + 1) + x - 1;
                    i += 2;
                }
            }
        }

        glBindVertexArray(vao);
        glBindBuffer(GL_ARRAY_BUFFER, vbo);
        glBufferData(GL_ARRAY_BUFFER, numVertices * @sizeOf(f32), &vertices, GL_STATIC_DRAW);
        glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, ebo);
        glBufferData(GL_ELEMENT_ARRAY_BUFFER, numElements * @sizeOf(u32), &elements, GL_STATIC_DRAW);

        const stride = (3 + 2 + 3) * @sizeOf(f32);
        glVertexAttribPointer(0, 3, GL_FLOAT, GL_FALSE, stride, null);
        glEnableVertexAttribArray(0);
        glVertexAttribPointer(1, 2, GL_FLOAT, GL_FALSE, stride, @intToPtr(*c_void, 3 * @sizeOf(f32)));
        glEnableVertexAttribArray(1);
        glVertexAttribPointer(2, 3, GL_FLOAT, GL_FALSE, stride, @intToPtr(*c_void, 5 * @sizeOf(f32)));
        glEnableVertexAttribArray(2);

        return Sphere{ .vao = vao, .vbo = vbo, .ebo = ebo, .len = numElements };
    }

    /// Render the sphere
    pub fn render(self: Sphere) void {
        glBindVertexArray(self.vao);
        glDrawElements(GL_TRIANGLE_STRIP, @intCast(c_int, self.len), GL_UNSIGNED_INT, null);
        // glBindVertexArray(0);
    }
};

/// A Cube in three dimensions
const Cube = struct {
    vao: c_uint,
    vbo: c_uint,

    /// Initialise the cube on the GPU
    pub fn init() Cube {
        var vao: c_uint = undefined;
        var vbo: c_uint = undefined;

        const vertices = [_]f32{
            // back face
            -1.0, -1.0, -1.0, 0.0,  0.0,  -1.0, 0.0, 0.0, // bottom-left
            1.0,  1.0,  -1.0, 0.0,  0.0,  -1.0, 1.0, 1.0, // top-right
            1.0,  -1.0, -1.0, 0.0,  0.0,  -1.0, 1.0, 0.0, // bottom-right
            1.0,  1.0,  -1.0, 0.0,  0.0,  -1.0, 1.0, 1.0, // top-right
            -1.0, -1.0, -1.0, 0.0,  0.0,  -1.0, 0.0, 0.0, // bottom-left
            -1.0, 1.0,  -1.0, 0.0,  0.0,  -1.0, 0.0, 1.0, // top-left
            // front face
            -1.0, -1.0, 1.0,  0.0,  0.0,  1.0,  0.0, 0.0, // bottom-left
            1.0,  -1.0, 1.0,  0.0,  0.0,  1.0,  1.0, 0.0, // bottom-right
            1.0,  1.0,  1.0,  0.0,  0.0,  1.0,  1.0, 1.0, // top-right
            1.0,  1.0,  1.0,  0.0,  0.0,  1.0,  1.0, 1.0, // top-right
            -1.0, 1.0,  1.0,  0.0,  0.0,  1.0,  0.0, 1.0, // top-left
            -1.0, -1.0, 1.0,  0.0,  0.0,  1.0,  0.0, 0.0, // bottom-left
            // left face
            -1.0, 1.0,  1.0,  -1.0, 0.0,  0.0,  1.0, 0.0, // top-right
            -1.0, 1.0,  -1.0, -1.0, 0.0,  0.0,  1.0, 1.0, // top-left
            -1.0, -1.0, -1.0, -1.0, 0.0,  0.0,  0.0, 1.0, // bottom-left
            -1.0, -1.0, -1.0, -1.0, 0.0,  0.0,  0.0, 1.0, // bottom-left
            -1.0, -1.0, 1.0,  -1.0, 0.0,  0.0,  0.0, 0.0, // bottom-right
            -1.0, 1.0,  1.0,  -1.0, 0.0,  0.0,  1.0, 0.0, // top-right
            // right face
            1.0,  1.0,  1.0,  1.0,  0.0,  0.0,  1.0, 0.0, // top-left
            1.0,  -1.0, -1.0, 1.0,  0.0,  0.0,  0.0, 1.0, // bottom-right
            1.0,  1.0,  -1.0, 1.0,  0.0,  0.0,  1.0, 1.0, // top-right
            1.0,  -1.0, -1.0, 1.0,  0.0,  0.0,  0.0, 1.0, // bottom-right
            1.0,  1.0,  1.0,  1.0,  0.0,  0.0,  1.0, 0.0, // top-left
            1.0,  -1.0, 1.0,  1.0,  0.0,  0.0,  0.0, 0.0, // bottom-left
            // bottom face
            -1.0, -1.0, -1.0, 0.0,  -1.0, 0.0,  0.0, 1.0, // top-right
            1.0,  -1.0, -1.0, 0.0,  -1.0, 0.0,  1.0, 1.0, // top-left
            1.0,  -1.0, 1.0,  0.0,  -1.0, 0.0,  1.0, 0.0, // bottom-left
            1.0,  -1.0, 1.0,  0.0,  -1.0, 0.0,  1.0, 0.0, // bottom-left
            -1.0, -1.0, 1.0,  0.0,  -1.0, 0.0,  0.0, 0.0, // bottom-right
            -1.0, -1.0, -1.0, 0.0,  -1.0, 0.0,  0.0, 1.0, // top-right
            // top face
            -1.0, 1.0,  -1.0, 0.0,  1.0,  0.0,  0.0, 1.0, // top-left
            1.0,  1.0,  1.0,  0.0,  1.0,  0.0,  1.0, 0.0, // bottom-right
            1.0,  1.0,  -1.0, 0.0,  1.0,  0.0,  1.0, 1.0, // top-right
            1.0,  1.0,  1.0,  0.0,  1.0,  0.0,  1.0, 0.0, // bottom-right
            -1.0, 1.0,  -1.0, 0.0,  1.0,  0.0,  0.0, 1.0, // top-left
            -1.0, 1.0,  1.0,  0.0,  1.0,  0.0,  0.0, 0.0, // bottom-left
        };
        glGenVertexArrays(1, &vao);
        glGenBuffers(1, &vbo);
        // fill buffer
        glBindBuffer(GL_ARRAY_BUFFER, vbo);
        glBufferData(GL_ARRAY_BUFFER, vertices.len * @sizeOf(f32), &vertices, GL_STATIC_DRAW);
        // link vertex attributes
        glBindVertexArray(vao);
        glEnableVertexAttribArray(0);
        glVertexAttribPointer(0, 3, GL_FLOAT, GL_FALSE, 8 * @sizeOf(f32), null);
        glEnableVertexAttribArray(1);
        glVertexAttribPointer(1, 3, GL_FLOAT, GL_FALSE, 8 * @sizeOf(f32), @intToPtr(*c_void, 3 * @sizeOf(f32)));
        glEnableVertexAttribArray(2);
        glVertexAttribPointer(2, 2, GL_FLOAT, GL_FALSE, 8 * @sizeOf(f32), @intToPtr(*c_void, 6 * @sizeOf(f32)));
        glBindBuffer(GL_ARRAY_BUFFER, 0);
        glBindVertexArray(0);

        return Cube{ .vao = vao, .vbo = vbo };
    }

    /// Render the cube
    pub fn render(self: Cube) void {
        glBindVertexArray(self.vao);
        glDrawArrays(GL_TRIANGLES, 0, 36);
        glBindVertexArray(0);
    }
};

/// A 1x1 XY quad
const Quad = struct {
    vao: c_uint,
    vbo: c_uint,

    /// Initialise the quad on the GPU
    pub fn init() Quad {
        var vao: c_uint = undefined;
        var vbo: c_uint = undefined;

        const quadVertices = [_]f32{
            // positions     // texture Coords
            -1.0, 1.0,  0.0, 0.0, 1.0,
            -1.0, -1.0, 0.0, 0.0, 0.0,
            1.0,  1.0,  0.0, 1.0, 1.0,
            1.0,  -1.0, 0.0, 1.0, 0.0,
        };

        glGenVertexArrays(1, &vao);
        glGenBuffers(1, &vbo);
        glBindVertexArray(vao);
        glBindBuffer(GL_ARRAY_BUFFER, vbo);
        glBufferData(GL_ARRAY_BUFFER, quadVertices.len * @sizeOf(f32), &quadVertices, GL_STATIC_DRAW);
        glEnableVertexAttribArray(0);
        glVertexAttribPointer(0, 3, GL_FLOAT, GL_FALSE, 5 * @sizeOf(f32), null);
        glEnableVertexAttribArray(1);
        glVertexAttribPointer(1, 2, GL_FLOAT, GL_FALSE, 5 * @sizeOf(f32), @intToPtr(*c_void, 3 * @sizeOf(f32)));

        return Quad{ .vao = vao, .vbo = vbo };
    }

    /// Render the quad
    pub fn render(self: Quad) void {
        glBindVertexArray(self.vao);
        glDrawArrays(GL_TRIANGLE_STRIP, 0, 4);
        glBindVertexArray(0);
    }
};
