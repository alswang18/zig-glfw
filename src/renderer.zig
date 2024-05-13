const std = @import("std");
const glfw = @import("mach-glfw");
const gl = @import("gl");

const glfw_log = std.log.scoped(.glfw);
const gl_log = std.log.scoped(.gl);

/// Procedure table that will hold loaded OpenGL functions.
var gl_procs: gl.ProcTable = undefined;

fn createGLWindow() ?glfw.Window {
    return glfw.Window.create(640, 480, "GLFW + OpenGL", null, null, .{
        .context_version_major = gl.info.version_major,
        .context_version_minor = gl.info.version_minor,
        .opengl_profile = .opengl_core_profile,
        .opengl_forward_compat = true,
    }) orelse {
        return null;
    };
}

test "Init GLFW and OpenGL GLFW Window Test" {
    if (!glfw.init(.{})) {
        glfw_log.err("failed to initialize GLFW: {?s}", .{glfw.getErrorString()});
        return error.GLFWInitFailed;
    }
    defer glfw.terminate();
    const window = createGLWindow();
    defer if (window != null) {
        window.?.destroy();
    };
}

fn createProgram(vertex_shader_source: []const u8, fragment_shader_source: []const u8) ?c_uint {
    var success: c_int = undefined;
    var info_log_buf: [512:0]u8 = undefined;

    const vertex_shader = gl.CreateShader(gl.VERTEX_SHADER);
    if (vertex_shader == 0) return null;
    defer gl.DeleteShader(vertex_shader);

    gl.ShaderSource(
        vertex_shader,
        1,
        (&vertex_shader_source.ptr)[0..1],
        (&@as(c_int, @intCast(vertex_shader_source.len)))[0..1],
    );
    gl.CompileShader(vertex_shader);
    gl.GetShaderiv(vertex_shader, gl.COMPILE_STATUS, &success);
    if (success == gl.FALSE) {
        gl.GetShaderInfoLog(vertex_shader, info_log_buf.len, null, &info_log_buf);
        gl_log.err("{s}", .{std.mem.sliceTo(&info_log_buf, 0)});
        return null;
    }

    const fragment_shader = gl.CreateShader(gl.FRAGMENT_SHADER);
    if (fragment_shader == 0) return null;
    defer gl.DeleteShader(fragment_shader);

    gl.ShaderSource(
        fragment_shader,
        1,
        (&fragment_shader_source.ptr)[0..1],
        (&@as(c_int, @intCast(fragment_shader_source.len)))[0..1],
    );
    gl.CompileShader(fragment_shader);
    gl.GetShaderiv(fragment_shader, gl.COMPILE_STATUS, &success);
    if (success == gl.FALSE) {
        gl.GetShaderInfoLog(fragment_shader, info_log_buf.len, null, &info_log_buf);
        gl_log.err("{s}", .{std.mem.sliceTo(&info_log_buf, 0)});
        return null;
    }

    const program = gl.CreateProgram();
    if (program == 0) return null;
    errdefer gl.DeleteProgram(program);

    gl.AttachShader(program, vertex_shader);
    gl.AttachShader(program, fragment_shader);
    gl.LinkProgram(program);
    gl.GetProgramiv(program, gl.LINK_STATUS, &success);
    if (success == gl.FALSE) {
        gl.GetProgramInfoLog(program, info_log_buf.len, null, &info_log_buf);
        gl_log.err("{s}", .{std.mem.sliceTo(&info_log_buf, 0)});
        return null;
    }
    return program;
}

fn startRender(window: glfw.Window) void {
    while (true) {
        glfw.pollEvents();
        gl.ClearColor(0.2, 0.3, 0.3, 1.0);
        gl.Clear(gl.COLOR_BUFFER_BIT);
        if (window.shouldClose()) break;
        {}
        window.swapBuffers();
    }
}

fn errorCallback(error_code: glfw.ErrorCode, description: [:0]const u8) void {
    std.log.err("glfw: {}: {s}\n", .{ error_code, description });
}

pub fn run() void {
    if (!glfw.init(.{})) {
        glfw_log.err("failed to initialize GLFW: {?s}", .{glfw.getErrorString()});
        return;
    }
    defer glfw.terminate();

    // Create our window, specifying that we want to use OpenGL.
    const window = createGLWindow() orelse {
        glfw_log.err("failed to create GLFW window: {?s}", .{glfw.getErrorString()});
        std.process.exit(1);
    };
    defer window.destroy();

    // Make the window's OpenGL context current.
    glfw.makeContextCurrent(window);
    defer glfw.makeContextCurrent(null);

    // Enable VSync to avoid drawing more often than necessary.
    glfw.swapInterval(1);

    // Initialize the OpenGL procedure table.
    if (!gl_procs.init(glfw.getProcAddress)) {
        gl_log.err("failed to load OpenGL functions", .{});
        return;
    }

    // Make the OpenGL procedure table current.
    gl.makeProcTableCurrent(&gl_procs);
    defer gl.makeProcTableCurrent(null);

    // set off zig linter

    // zig fmt: off
    const vertices: [9]f32 = .{
         -0.5, -0.5, 0.0, 
        0.5, -0.5, 0.0, 
        0.0, 0.5, 0.0 
    };

    _ = vertices;

    const vertex_shader_source = @embedFile("shaders/vertex.glsl");
    std.debug.print("Vertex Shader Source: {s}\n", .{vertex_shader_source});
    const fragment_shader_source = @embedFile("shaders/fragment.glsl");
    std.debug.print("Fragment Shader Source: {s}\n", .{fragment_shader_source});

    const program = createProgram(vertex_shader_source, fragment_shader_source) orelse {
        return;
    };
    defer gl.DeleteProgram(program);

    // const framebuffer_size_uniform = gl.GetUniformLocation(program, "u_FramebufferSize");

    // Vertex Array Object (VAO), remembers instructions for how vertex data is laid out in memory.
    // Using VAOs is strictly required in modern OpenGL.
    var vao: c_uint = undefined;
    gl.GenVertexArrays(1, (&vao)[0..1]);
    defer gl.DeleteVertexArrays(1, (&vao)[0..1]);

    // Vertex Buffer Object (VBO), holds vertex data.
    var vbo: c_uint = undefined;
    gl.GenBuffers(1, (&vbo)[0..1]);
    defer gl.DeleteBuffers(1, (&vbo)[0..1]);

    // Index Buffer Object (IBO), maps indices to vertices (to enable reusing vertices).
    var ibo: c_uint = undefined;
    gl.GenBuffers(1, (&ibo)[0..1]);
    defer gl.DeleteBuffers(1, (&ibo)[0..1]);

    // zig fmt: on

    startRender(window);
}
