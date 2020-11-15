// Minimal types to replace glm functionality for this tutorial

// TODO: Inline and fix cross once #3893 is fixed upstream
const std = @import("std");
const sqrt = std.math.sqrt;
const cos = std.math.cos;
const sin = std.math.sin;
const tan = std.math.tan;
const max = std.math.max;
const min = std.math.min;

pub fn clamp(v: f32, lo: f32, hi: f32) f32 {
    return max(min(v, hi), lo);
}

/// Mathematical vector types
fn Vector(comptime d: usize) type {
    return extern struct {
        vals: [d]f32,

        const Self = @This();

        // Constructors
        pub fn fill(v: f32) Self {
            var vals: [d]f32 = undefined;
            comptime var i = 0;
            inline while (i < d) : (i += 1) {
                vals[i] = v;
            }
            return Self{ .vals = vals };
        }

        pub fn zeros() Self {
            return Self.fill(0.0);
        }

        pub fn ones() Self {
            return Self.fill(1.0);
        }

        // Math Operations
        pub fn sum(self: Self) f32 {
            var total: f32 = 0.0;
            for (self.vals) |val| {
                total += val;
            }
            return total;
        }

        pub fn add(self: Self, other: Self) Self {
            const vs: @Vector(d, f32) = self.vals;
            const vo: @Vector(d, f32) = other.vals;

            return Self{ .vals = vs + vo };
        }

        pub fn sub(self: Self, other: Self) Self {
            const vs: @Vector(d, f32) = self.vals;
            const vo: @Vector(d, f32) = other.vals;

            return Self{ .vals = vs - vo };
        }

        pub fn mul(self: Self, other: Self) Self {
            const vs: @Vector(d, f32) = self.vals;
            const vo: @Vector(d, f32) = other.vals;

            return Self{ .vals = vs * vo };
        }

        pub fn mulScalar(self: Self, other: f32) Self {
            const vs: @Vector(d, f32) = self.vals;
            const vo: @Vector(d, f32) = Self.fill(other).vals;

            return Self{ .vals = vs * vo };
        }

        pub fn div(self: Self, other: Self) Self {
            const vs: @Vector(d, f32) = self.vals;
            const vo: @Vector(d, f32) = other.vals;

            return Self{ .vals = vs / vo };
        }

        pub fn dot(self: Self, other: Self) f32 {
            const product = self.mul(other);
            return product.sum();
        }

        pub fn normSq(self: Self) f32 {
            return self.dot(self);
        }

        pub fn norm(self: Self) f32 {
            return sqrt(self.normSq());
        }

        pub fn normalize(self: Self) Self {
            const n = self.norm();
            var vals = self.vals;
            for (vals) |*val| {
                val.* /= n;
            }
            return Self{ .vals = vals };
        }

        pub fn cross(self: Self, other: Self) Self {
            if (d != 3) {
                // @compileError("Cross product only defined for 3D vectors");
                // https://github.com/ziglang/zig/issues/3893
                // Silently fail for now
                return Self.zeros();
            }
            const vals = [3]f32{
                self.vals[1] * other.vals[2] - self.vals[2] * other.vals[1],
                self.vals[2] * other.vals[0] - self.vals[0] * other.vals[2],
                self.vals[0] * other.vals[1] - self.vals[1] * other.vals[0],
            };
            return Self{ .vals = vals };
        }
    };
}

pub const Vec2 = Vector(2);
pub const Vec3 = Vector(3);
pub const Vec4 = Vector(4);

pub fn vec3(x: f32, y: f32, z: f32) Vec3 {
    return Vec3{ .vals = [3]f32{ x, y, z } };
}

/// Square matrix type with columnar memory layout
fn Matrix(comptime d: usize) type {
    return extern struct {
        vals: [d][d]f32,

        const Self = @This();

        pub fn zeros() Self {
            var vals: [d][d]f32 = undefined;
            comptime var i = 0;
            inline while (i < d) : (i += 1) {
                comptime var j = 0;
                inline while (j < d) : (j += 1) {
                    vals[i][j] = 0.0;
                }
            }
            return Self{ .vals = vals };
        }

        pub fn identity() Self {
            var vals: [d][d]f32 = undefined;
            comptime var i = 0;
            inline while (i < d) : (i += 1) {
                comptime var j = 0;
                inline while (j < d) : (j += 1) {
                    vals[i][j] = if (i == j) 1.0 else 0.0;
                }
            }
            return Self{ .vals = vals };
        }

        pub fn transpose(self: Self) Self {
            var vals: [d][d]f32 = undefined;
            comptime var i = 0;
            inline while (i < d) : (i += 1) {
                comptime var j = 0;
                inline while (j < d) : (j += 1) {
                    vals[i][j] = self.vals[j][i];
                }
            }
            return Self{ .vals = vals };
        }

        pub fn matmul(self: Self, other: Self) Self {
            var vals: [d][d]f32 = undefined;
            const a = self.transpose();
            const b = other;

            comptime var i = 0;
            inline while (i < d) : (i += 1) {
                comptime var j = 0;
                inline while (j < d) : (j += 1) {
                    const row: @Vector(d, f32) = a.vals[j];
                    const col: @Vector(d, f32) = b.vals[i];
                    const prod: [d]f32 = row * col;

                    var sum: f32 = 0;
                    for (prod) |p| {
                        sum += p;
                    }
                    vals[i][j] = sum;
                }
            }

            return Self{ .vals = vals };
        }

        // while std.testing.expectEqual is broken
        pub fn expectEqual(self: Self, other: Self) void {
            comptime var i = 0;
            inline while (i < d) : (i += 1) {
                std.testing.expectEqual(self.vals[i], other.vals[i]);
            }
        }
    };
}

pub const Mat2 = Matrix(2);
pub const Mat3 = Matrix(3);
pub const Mat4 = Matrix(4);

/// Transformation matrix for translation by v
pub fn translation(v: Vec3) Mat4 {
    return Mat4{
        .vals = [4][4]f32{
            .{ 1.0, 0.0, 0.0, 0.0 },
            .{ 0.0, 1.0, 0.0, 0.0 },
            .{ 0.0, 0.0, 1.0, 0.0 },
            .{ v.vals[0], v.vals[1], v.vals[2], 1.0 },
        },
    };
}

/// Transformation matrix for rotation around the z axis by a radians
pub fn rotation(angle: f32, axis: Vec3) Mat4 {
    const unit = axis.normalize();
    const x = unit.vals[0];
    const y = unit.vals[1];
    const z = unit.vals[2];

    const a = cos(angle) + x * x * (1 - cos(angle));
    const b = y * x * (1 - cos(angle)) + z * sin(angle);
    const c = z * x * (1 - cos(angle)) - y * sin(angle);

    const d = x * y * (1 - cos(angle)) - z * sin(angle);
    const e = cos(angle) + y * y * (1 - cos(angle));
    const f = z * y * (1 - cos(angle)) + x * sin(angle);

    const h = x * z * (1 - cos(angle)) + y * sin(angle);
    const i = y * z * (1 - cos(angle)) - x * sin(angle);
    const j = cos(angle) + z * z * (1 - cos(angle));

    return Mat4{
        .vals = [4][4]f32{
            .{ a, b, c, 0.0 },
            .{ d, e, f, 0.0 },
            .{ h, i, j, 0.0 },
            .{ 0.0, 0.0, 0.0, 1.0 },
        },
    };
}

pub fn scale(magnitude: Vec3) Mat4 {
    return Mat4{
        .vals = [4][4]f32{
            .{ magnitude.vals[0], 0.0, 0.0, 0.0 },
            .{ 0.0, magnitude.vals[1], 0.0, 0.0 },
            .{ 0.0, 0.0, magnitude.vals[2], 0.0 },
            .{ 0.0, 0.0, 0.0, 1.0 },
        },
    };
}

/// View matrix for camera at eye, looking at center, oriented by up
pub fn lookAt(eye: Vec3, center: Vec3, up: Vec3) Mat4 {
    const f = center.sub(eye).normalize();
    const s = f.cross(up).normalize();
    const u = s.cross(f);

    return Mat4{
        .vals = [4][4]f32{
            .{ s.vals[0], u.vals[0], -f.vals[0], 0.0 },
            .{ s.vals[1], u.vals[1], -f.vals[1], 0.0 },
            .{ s.vals[2], u.vals[2], -f.vals[2], 0.0 },
            .{ -s.dot(eye), -u.dot(eye), f.dot(eye), 1.0 },
        },
    };
}

/// Perspective projection matrix
pub fn perspective(fovy: f32, aspect: f32, znear: f32, zfar: f32) Mat4 {
    const tanhalffovy = tan(fovy / 2.0);

    const a = 1.0 / (aspect * tanhalffovy);
    const b = 1.0 / tanhalffovy;
    const c = -(zfar + znear) / (zfar - znear);
    const d = -(2.0 * zfar * znear) / (zfar - znear);

    return Mat4{
        .vals = [4][4]f32{
            .{ a, 0.0, 0.0, 0.0 },
            .{ 0.0, b, 0.0, 0.0 },
            .{ 0.0, 0.0, c, -1.0 },
            .{ 0.0, 0.0, d, 0.0 },
        },
    };
}

/// Orthographic projection matrix
pub fn ortho(left: f32, right: f32, bottom: f32, top: f32, znear: f32, zfar: f32) Mat4 {
    const a = 2.0 / (right - left);
    const b = 2.0 / (top - bottom);
    const c = -2.0 / (zfar - znear);
    const d = -(right + left) / (right - left);
    const e = -(top + bottom) / (top - bottom);
    const f = -(zfar + znear) / (zfar - znear);

    return Mat4{
        .vals = [4][4]f32{
            .{ a, 0.0, 0.0, 0.0 },
            .{ 0.0, b, 0.0, 0.0 },
            .{ 0.0, 0.0, c, -1.0 },
            .{ d, e, f, 0.0 },
        },
    };
}
