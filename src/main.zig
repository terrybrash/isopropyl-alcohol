const std = @import("std");
const w4 = @import("wasm4.zig");
const zlm = @import("zlm.zig");
const atlas = @import("atlas.zig");
const Vec2 = zlm.Vec2;
const Mat2 = zlm.Mat2;

const Sound = struct {
    freq1: u32,
    freq2: u32,
    attack: u32,
    decay: u32,
    sustain: u32,
    release: u32,
    volume: u32,
    channel: u4,
    mode: u4,
};

fn play(s: Sound) void {
    const freq = s.freq1 | s.freq2 << 16;
    const duration = s.attack << 24 | s.decay << 16 | s.sustain | s.release << 8;
    const flags = s.channel | s.mode << 2;
    w4.tone(freq, duration, s.volume, flags);
}

const sound = .{
    .shoot = Sound{
        .freq1 = 830,
        .freq2 = 30,
        .attack = 0,
        .decay = 0,
        .sustain = 4,
        .release = 15,
        .volume = 50,
        .channel = 3,
        .mode = 0,
    },
    .hit = Sound{
        .freq1 = 830,
        .freq2 = 30,
        .attack = 0,
        .decay = 12,
        .sustain = 0,
        .release = 0,
        .volume = 50,
        .channel = 3,
        .mode = 0,
    },
};

const Player = struct {
    position: Vec2,
    alive: bool,
};

const Projectile = struct {
    start: Vec2,
    end: Vec2,
    center: Vec2,
    lifetime: f32,
    born: f32,
    radius: u16,
    owner: usize,
};

const Controller = struct {
    gamepad: *const u8,
    connected: bool,
};

const turn_time = 10.0; // EVERY 10 SECONDS
const camera = Vec2.new(160 / 2, 160 / 2);
const ring_radius = 70;
const player_radius: u16 = 5;

var controllers = [4]Controller{ .{
    .gamepad = w4.GAMEPAD1,
    .connected = true,
}, .{
    .gamepad = w4.GAMEPAD2,
    .connected = false,
}, .{
    .gamepad = w4.GAMEPAD3,
    .connected = false,
}, .{
    .gamepad = w4.GAMEPAD4,
    .connected = false,
} };


const Game = struct {
    players: [4]Player,
    attacker: usize,
    power: f32,
    turn_elapsed: f32,
    projectiles: std.BoundedArray(Projectile, 100),
    restart: ?f32,
    now: f32,
    last_tick: f32,

    fn new(seed: f32) Game {
        // std.rand.DefaultPrng.random().
        var attacker = @mod(@floatToInt(u32, seed), controllers.len);

        return Game{
            .players = [4]Player{ .{
                .position = Vec2.new(40, 40),
                .alive = true,
            }, .{
                .position = Vec2.new(-40, -40),
                .alive = true,
            }, .{
                .position = Vec2.new(40, -40),
                .alive = true,
            }, .{
                .position = Vec2.new(-40, 40),
                .alive = true,
            } },
            .attacker = attacker,
            .power = 0,
            .turn_elapsed = 0,
            .projectiles = std.BoundedArray(Projectile, 100).init(0) catch unreachable,
            .restart = null,
            .now = 0,
            .last_tick = 0,
        };
    }
};

var game = Game.new(0);

export fn update() void {
    const dt = 1.0 / 60.0;
    game.now += dt;
    game.turn_elapsed += dt;

    w4.PALETTE.* = .{
        0xfff6d3, // yellow
        0xf9a875, // orange
        0xeb6b6f, // red
        0x7c3f58, // brown
    };
        
    while (true) {
        if (controllers[game.attacker].connected and game.players[game.attacker].alive) {
            break;
        }
        game.attacker = @mod(game.attacker + 1, controllers.len);
    }

    while (game.now - game.last_tick >= 1.0) {
        game.last_tick += 1;
        play(.{
            .freq1 = 550,
            .freq2 = 0,
            .attack = 0,
            .decay = 3,
            .sustain = 0,
            .release = 4,
            .volume = 13,
            .channel = 2,
            .mode = 1,
        });
    }

    {
        w4.DRAW_COLORS.* = 0x1;
        const center = Vec2.zero.add(camera);
        w4.oval(@floatToInt(i32, center.x) - ring_radius, @floatToInt(i32, center.y) - ring_radius, ring_radius * 2, ring_radius * 2);
        w4.oval(@floatToInt(i32, center.x) - 2, @floatToInt(i32, center.y) - 2, 5, 5);
    }

    if (game.turn_elapsed >= turn_time) {
        game.turn_elapsed -= turn_time;
        game.power = 0;
        game.attacker = @mod(game.attacker + 1, game.players.len);
        while (true) {
            const player = game.players[game.attacker];
            const controller = controllers[game.attacker];
            if (controller.connected and player.alive) {
                break;
            }
            game.attacker = @mod(game.attacker + 1, game.players.len);
        }
        play(.{
            .freq1 = 600,
            .freq2 = 900,
            .attack = 0,
            .decay = 0,
            .sustain = 5,
            .release = 10,
            .volume = 50,
            .channel = 0,
            .mode = 3,
        });
    }

    {
        w4.DRAW_COLORS.* = 0x3;
        w4.text("power", 74, 150);
        var i: u16 = 0;
        const height = 10;
        const width = 4;
        const bars = 10;
        const offset_x = 116;
        const offset_y = 147;
        while (i < bars) : (i += 1) {
            w4.rect(offset_x + width * i, offset_y + height - i - 1, width, i + 1);
        }
        w4.DRAW_COLORS.* = 0x4;
        const p = @floatToInt(u16, game.power * width * bars);
        w4.line(offset_x + p, offset_y, offset_x + p, offset_y + height);
    }

    {
        w4.DRAW_COLORS.* = 0x3;
        var buf: [12]u8 = undefined;
        var result = std.fmt.bufPrint(&buf, "time {}", .{@floatToInt(u32, std.math.floor(turn_time - game.turn_elapsed))}) catch unreachable;
        w4.text(result, 2, 150);
    }

    for (game.players) |*player, i| {
        const gamepad = controllers[i].gamepad.*;
        if (gamepad != 0) {
            controllers[i].connected = true;
        }
        if (!controllers[i].connected) {
            continue;
        }
        if (!player.alive) {
            w4.DRAW_COLORS.* = 0x40;
            const pos = Vec2.add(player.position, camera);
            w4.oval(@floatToInt(i32, pos.x) - player_radius, @floatToInt(i32, pos.y) - player_radius, player_radius * 2, player_radius * 2);
            continue;
        }

        if (game.attacker == i) {
            w4.DRAW_COLORS.* = 0x3;
        } else {
            w4.DRAW_COLORS.* = 0x2;
        }

        if (game.attacker == i) {
            const start = Vec2.add(player.position, camera);
            const end = Vec2.add(Vec2.zero, camera);
            w4.line(@floatToInt(i32, start.x), @floatToInt(i32, start.y), @floatToInt(i32, end.x), @floatToInt(i32, end.y));
            w4.oval(@floatToInt(i32, start.x) - 2, @floatToInt(i32, start.y) - 2, 5, 5);
        }

        const pos = Vec2.add(player.position, camera);
        w4.oval(@floatToInt(i32, pos.x) - player_radius, @floatToInt(i32, pos.y) - player_radius, player_radius * 2, player_radius * 2);

        var dir = Vec2.zero;
        if (gamepad & w4.BUTTON_UP != 0) {
            dir.y -= 1;
        }
        if (gamepad & w4.BUTTON_DOWN != 0) {
            dir.y += 1;
        }
        if (gamepad & w4.BUTTON_LEFT != 0) {
            dir.x -= 1;
        }
        if (gamepad & w4.BUTTON_RIGHT != 0) {
            dir.x += 1;
        }
        player.position = Vec2.add(player.position, dir.normalize().scale(1.4));
        {
            const distance = std.math.min(player.position.length(), ring_radius);
            player.position = player.position.normalize().scale(distance);
        }

        if (game.attacker == i) {
            if (gamepad & w4.BUTTON_1 != 0) {
                game.power = std.math.min(game.power + dt, 1);
                play(.{
                    .freq1 = 300 + @floatToInt(u32, game.power * 500),
                    .freq2 = 0,
                    .attack = 0,
                    .decay = 0,
                    .sustain = 0,
                    .release = 14,
                    .volume = 30 - @floatToInt(u32, game.power * 20),
                    .channel = 0,
                    .mode = 1,
                });
            } else if (game.power > 0) {
                var playerToTarget = Vec2.sub(Vec2.zero, player.position).normalize().scale(ring_radius * 2 * game.power);
                play(.{
                    .freq1 = 500 + @floatToInt(u32, game.power * 300),
                    .freq2 = 300 + @floatToInt(u32, game.power * 200),
                    .attack = 0,
                    .decay = 5,
                    .sustain = 0,
                    .release = 12,
                    .volume = 30,
                    .channel = 2,
                    .mode = 3,
                });
                play(.{
                    .freq1 = 500 + @floatToInt(u32, game.power * 500),
                    .freq2 = 300 + @floatToInt(u32, game.power * 200),
                    .attack = 0,
                    .decay = 0,
                    .sustain = 5,
                    .release = 15,
                    .volume = 80,
                    .channel = 1,
                    .mode = 0,
                });
                game.projectiles.append(.{
                    .start = player.position,
                    .end = player.position.add(playerToTarget),
                    .center = player.position,
                    .lifetime = 0.5,
                    .born = game.now,
                    .radius = 2 + @floatToInt(u16, std.math.round(game.power * 4)),
                    .owner = i,
                }) catch unreachable;
                game.power = 0;
            }
        }
    }

    var p = game.projectiles.len;
    outer: while (p > 0) {
        p -= 1;
        var projectile = game.projectiles.get(p);
        var t = (game.now - projectile.born) / projectile.lifetime;
        if (t >= 1.0) {
            _ = game.projectiles.swapRemove(p);
            continue;
        }

        var center = Vec2.lerp(projectile.start, projectile.end, easeOutSine(t));
        for (game.players) |*player, i| {
            if (!controllers[i].connected or !player.alive or projectile.owner == i) {
                continue;
            }
            if (center.sub(player.position).length() < @intToFloat(f32, projectile.radius + player_radius)) {
                player.alive = false;
                play(sound.hit);
                _ = game.projectiles.swapRemove(p);
                continue :outer;
            }
        }

        var velocity = center.sub(projectile.center).normalize();
        projectile.center = center;
        var i: u16 = 0;
        w4.DRAW_COLORS.* = 0x33;
        var radius_offset: f32 = 0;
        while (i < projectile.radius) : (i += 1) {
            var r = projectile.radius - i;
            var tail = velocity.scale(-radius_offset).add(projectile.center).add(camera);
            radius_offset += @intToFloat(f32, r);
            w4.oval(@floatToInt(i32, tail.x) - r, @floatToInt(i32, tail.y) - r, r * 2, r * 2);
        }
    }

    if (game.restart == null) {
        var connected: u32 = 0;
        var alive: u32 = 0;
        for (game.players) |player, i| {
            if (controllers[i].connected) {
                connected += 1;
                if (player.alive) {
                    alive += 1;
                }
            }
        }
        if (connected > 1 and alive <= 1) {
            game.restart = game.now + 3;
        }
    }

    if (game.restart) |restart| {
        if (game.now > restart) {
            game = Game.new(game.now);
        }
    }
}

fn lerp(a: f32, b: f32, t: f32) f32 {
    return a + t * (b - a);
}

// -- IN-OUT --

pub fn easeInOutSine(x: f32) f32 {
    return -(std.math.cos(std.math.pi * x) - 1) / 2;
}

pub fn easeInOutCubic(x: f32) f32 {
    if (x < 0.5) {
        return 4 * x * x * x;
    } else {
        return 1 - std.math.pow(-2 * x + 2, 3) / 2;
    }
}

pub fn easeInOutQuint(x: f32) f32 {
    if (x < 0.5) {
        return 16 * x * x * x * x * x;
    } else {
        return 1 - std.math.pow(-2 * x + 2, 5) / 2;
    }
}

pub fn easeInOutCirc(x: f32) f32 {
    if (x < 0.5) {
        return (1 - std.math.sqrt(1 - std.math.pow(2 * x, 2))) / 2;
    } else {
        return (std.math.sqrt(1 - std.math.pow(-2 * x + 2, 2)) + 1) / 2;
    }
}

pub fn easeInOutElastic(x: f32) f32 {
    const c5 = (2 * std.math.pi) / 4.5;
    if (x == 0) {
        return 0;
    } else if (x == 1) {
        return 1;
    } else if (x < 0.5) {
        return -(std.math.pow(2, 20 * x - 10) * std.math.sin((20 * x - 11.125) * c5)) / 2;
    } else {
        return (std.math.pow(2, -20 * x + 10) * std.math.sin((20 * x - 11.125) * c5)) / 2 + 1;
    }
}

pub fn easeInOutQuad(x: f32) f32 {
    if (x < 0.5) {
        return 2 * x * x;
    } else {
        return 1 - std.math.pow(-2 * x + 2, 2) / 2;
    }
}

pub fn easeInOutQuart(x: f32) f32 {
    if (x < 0.5) {
        return 8 * x * x * x * x;
    } else {
        return 1 - std.math.pow(-2 * x + 2, 4) / 2;
    }
}

pub fn easeInOutExpo(x: f32) f32 {
    if (x == 0) {
        return 0;
    } else if (x == 1) {
        return 1;
    } else if (x < 0.5) {
        return std.math.pow(2, 20 * x - 10) / 2;
    } else {
        return (2 - std.math.pow(2, -20 * x + 10)) / 2;
    }
}

pub fn easeInOutBack(x: f32) f32 {
    const c1 = 1.70158;
    const c2 = c1 * 1.525;
    if (x < 0.5) {
        return (std.math.pow(2 * x, 2) * ((c2 + 1) * 2 * x - c2)) / 2;
    } else {
        return (std.math.pow(2 * x - 2, 2) * ((c2 + 1) * (x * 2 - 2) + c2) + 2) / 2;
    }
}

// -- IN --

pub fn easeInSine(x: f32) f32 {
    return 1 - std.math.cos((x * std.math.pi) / 2);
}

pub fn easeInCubic(x: f32) f32 {
    return x * x * x;
}

pub fn easeInQuint(x: f32) f32 {
    return x * x * x * x * x;
}

pub fn easeInCirc(x: f32) f32 {
    return 1 - std.math.sqrt(1 - std.math.pow(x, 2));
}

pub fn easeInElastic(x: f32) f32 {
    const c4 = (2 * std.math.pi) / 3;
    if (x == 0) {
        return 0;
    } else {
        if (x == 1) {
            return 1;
        } else {
            return -std.math.pow(2, 10 * x - 10) * std.math.sin((x * 10 - 10.75) * c4);
        }
    }
}

pub fn easeInQuad(x: f32) f32 {
    return x * x;
}

pub fn easeInQuart(x: f32) f32 {
    return x * x * x * x;
}

pub fn easeInExpo(x: f32) f32 {
    if (x == 0) {
        return 0;
    } else {
        return std.math.pow(2, 10 * x - 10);
    }
}

pub fn easeInBack(x: f32) f32 {
    const strength = 1.70158;
    const c3 = strength + 1;
    return c3 * x * x * x - strength * x * x;
}

// -- OUT --

pub fn easeOutSine(x: f32) f32 {
    return std.math.sin((x * std.math.pi) / 2);
}

pub fn easeOutCubic(x: f32) f32 {
    return 1 - std.math.pow(1 - x, 3);
}

pub fn easeOutQuint(x: f32) f32 {
    return 1 - std.math.pow(1 - x, 5);
}

pub fn easeOutCirc(x: f32) f32 {
    return std.math.sqrt(1 - std.math.pow(x - 1, 2));
}

pub fn easeOutElastic(x: f32) f32 {
    const c4 = (2 * std.math.pi) / 3;
    if (x == 0) {
        return 0;
    } else if (x == 1) {
        return 1;
    } else {
        return std.math.pow(2, -10 * x) * std.math.sin((x * 10 - 0.75) * c4) + 1;
    }
}

pub fn easeOutQuad(x: f32) f32 {
    return 1 - (1 - x) * (1 - x);
}

pub fn easeOutQuart(x: f32) f32 {
    return 1 - std.math.pow(1 - x, 4);
}

pub fn easeOutExpo(x: f32) f32 {
    if (x == 1) {
        return 1;
    } else {
        return 1 - std.math.pow(2, -10 * x);
    }
}

pub fn easeOutBack(x: f32) f32 {
    const c1 = 1.70158;
    const c3 = c1 + 1;
    return 1 + c3 * std.math.pow(x - 1, 3) + c1 * std.math.pow(x - 1, 2);
}
