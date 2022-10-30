const std = @import("std");
const window = @import("window");
const gl = @import("gl");
const ls = @import("ls");
const nm = @import("nm");
const util = @import("util");
const zlua = @import("ziglua");

const Allocator = std.mem.Allocator;

const Vec3 = nm.Vec3;
const vec3 = nm.vec3;

const munleko = @import("munleko");

const Engine = munleko.Engine;
const Session = munleko.Session;


const Window = window.Window;

pub const rendering = @import("rendering.zig");


pub fn main() !void {

    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();

    // var lua = try zlua.Lua.init(allocator);
    // defer lua.deinit();

    try window.init();
    defer window.deinit();

    var client: Client = undefined;
    try client.init(allocator);
    defer client.deinit();

    try client.run();

}

pub const Client = struct {

    window: Window,
    engine: Engine,


    pub fn init(self: *Client, allocator: Allocator) !void {
        self.window = Window.init(allocator);
        self.engine = try Engine.init(allocator);
    }

    pub fn deinit(self: *Client) void {
        self.window.deinit();
        self.engine.deinit();
    }


    pub fn run(self: *Client) !void {
        try self.window.create(.{});
        defer self.window.destroy();
        self.window.makeContextCurrent();
        self.window.setVsync(.disabled);
        try gl.init(window.getGlProcAddress);
        gl.viewport(self.window.size);
        gl.enable(.depth_test);
        gl.setDepthFunction(.less);
        gl.enable(.cull_face);
        var session = try self.engine.createSession(Session.Callbacks.init(
            self,
            &tick,
        ));

        try session.start();
        defer session.stop();

        self.window.setMouseMode(.disabled);
        var cam = @import("FlyCam.zig").init(self.window);


        const dbg = try rendering.Debug.init();
        defer dbg.deinit();
        
        dbg.setLight(vec3(.{1, 3, 2}).norm() orelse unreachable);

        gl.clearColor(.{0, 0, 0, 1});
        gl.clearDepth(.float, 1);

        dbg.start();

        var fps_counter = try util.FpsCounter.start(1);

        while (self.window.nextFrame()) {
            for(self.window.events.get(.framebuffer_size)) |size| {
                gl.viewport(size);
            }
            if (self.window.buttonPressed(.grave)) {
                switch (self.window.mouse_mode) {
                    .disabled => self.window.setMouseMode(.visible),
                    else => self.window.setMouseMode(.disabled),
                }
            }

            cam.update(self.window);
            dbg.setView(cam.viewMatrix());

            gl.clear(.color_depth);
            dbg.setProj(
                nm.transform.createPerspective(
                    90.0 * std.math.pi / 180.0,
                    @intToFloat(f32, self.window.size[0]) / @intToFloat(f32, self.window.size[1]),
                    0.001, 1000,
                )
            );
            dbg.drawCube(Vec3.zero, 1, vec3(.{0.8, 1, 1}));
            if (fps_counter.tick()) |frames| {
                std.log.info("fps: {d}", .{frames});
            }
        }
    }

    pub fn tick(self: *Client, session: *Session) !void {
        _ = self;
        _ = session;
        // if (session.tick_count % 100 == 0) {
        //     std.log.debug("tick {d}", .{ session.tick_count });
        // }
    }

};