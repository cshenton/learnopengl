const std = @import("std");
const pi = std.math.pi;
const cos = std.math.cos;
const sin = std.math.sin;

const glm = @import("glm.zig");
const Mat4 = glm.Mat4;
const Vec3 = glm.Vec3;
const vec3 = glm.vec3;
const lookAt = glm.lookAt;

usingnamespace @import("c.zig");

// Defines several possible options for camera movement. Used as abstraction to stay away from window-system specific input methods
const CameraMovement = enum {
    Forward,
    Backward,
    Left,
    Right,
};

// Default camera values
const YAW = -90.0;
const PITCH = 0.0;
const SPEED = 2.5;
const SENSITIVITY = 0.1;
const ZOOM = 45.0;

// An abstract camera class that processes input and calculates the corresponding Euler Angles, Vectors and Matrices for use in OpenGL
pub const Camera = struct {
    // Camera Attributes
    position: Vec3,
    front: Vec3,
    up: Vec3,
    right: Vec3,
    worldUp: Vec3,

    // Euler Angles
    yaw: f32,
    pitch: f32,

    // Camera options
    movementSpeed: f32,
    mouseSensitivity: f32,
    zoom: f32,

    // Constructor with vectors
    pub fn init(position: Vec3, up: Vec3, yaw: f32, pitch: f32) Camera {
        var camera = Camera{
            .position = position,
            .front = vec3(0.0, 0.0, -1.0),
            .up = up,
            .right = vec3(-1.0, 0.0, 0.0),
            .worldUp = up,

            .yaw = yaw,
            .pitch = pitch,

            .movementSpeed = SPEED,
            .mouseSensitivity = SENSITIVITY,
            .zoom = ZOOM,
        };
        camera.updateCameraVectors();
        return camera;
    }

    pub fn default() Camera {
        var camera = Camera{
            .position = vec3(0.0, 0.0, 3.0),
            .front = vec3(0.0, 0.0, -1.0),
            .up = vec3(0.0, 1.0, 0.0),
            .right = vec3(-1.0, 0.0, 0.0),
            .worldUp = vec3(0.0, 1.0, 0.0),

            .yaw = YAW,
            .pitch = PITCH,

            .movementSpeed = SPEED,
            .mouseSensitivity = SENSITIVITY,
            .zoom = ZOOM,
        };
        camera.updateCameraVectors();
        return camera;
    }

    // Returns the view matrix calculated using Euler Angles and the LookAt Matrix
    pub fn getViewMatrix(self: Camera) Mat4 {
        return lookAt(self.position, self.position.add(self.front), self.up);
    }

    // Processes input received from any keyboard-like input system. Accepts input parameter in the form of camera defined ENUM (to abstract it from windowing systems)
    pub fn processKeyboard(self: *Camera, direction: CameraMovement, deltaTime: f32) void {
        const velocity = self.movementSpeed * deltaTime;
        switch (direction) {
            .Forward => self.position = self.position.add(self.front.mulScalar(velocity)),
            .Backward => self.position = self.position.sub(self.front.mulScalar(velocity)),
            .Left => self.position = self.position.sub(self.right.mulScalar(velocity)),
            .Right => self.position = self.position.add(self.right.mulScalar(velocity)),
        }
    }

    // Processes input received from a mouse input system. Expects the offset value in both the x and y direction.
    pub fn processMouseMovement(self: *Camera, xoffset: f32, yoffset: f32) void {
        self.yaw += xoffset * self.mouseSensitivity;
        self.pitch += yoffset * self.mouseSensitivity;

        // Make sure that when pitch is out of bounds, screen doesn't get flipped
        if (self.pitch > 89.0)
            self.pitch = 89.0;
        if (self.pitch < -89.0)
            self.pitch = -89.0;

        // Update Front, Right and Up Vectors using the updated Euler angles
        self.updateCameraVectors();
    }

    // Processes input received from a mouse scroll-wheel event. Only requires input on the vertical wheel-axis
    pub fn processMouseScroll(self: *Camera, yoffset: f32) void {
        if (self.zoom >= 1.0 and self.zoom <= 45.0)
            self.zoom -= yoffset;
        if (self.zoom <= 1.0)
            self.zoom = 1.0;
        if (self.zoom >= 45.0)
            self.zoom = 45.0;
    }

    // Calculates the front vector from the Camera's (updated) Euler Angles
    fn updateCameraVectors(self: *Camera) void {
        // Calculate the new Front vector
        var front: Vec3 = undefined;
        front.vals[0] = cos(self.yaw / 180.0 * pi) * cos(self.pitch / 180.0 * pi);
        front.vals[1] = sin(self.pitch / 180.0 * pi);
        front.vals[2] = sin(self.yaw / 180.0 * pi) * cos(self.pitch / 180.0 * pi);
        self.front = front.normalize();
        // Also re-calculate the Right and Up vector
        self.right = self.front.cross(self.worldUp).normalize();
        self.up = self.right.cross(self.front).normalize();
    }
};
