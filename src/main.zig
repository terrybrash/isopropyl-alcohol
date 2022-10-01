const w4 = @import("wasm4.zig");
const math = @import("zlm.zig");
const atlas = @import("atlas.zig");

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

var player = math.Vec2.new(0, 0);
const blip = Sound{
    .freq1 = 280,
    .freq2 = 370,
    .attack = 10,
    .decay = 0,
    .sustain = 4,
    .release = 0,
    .volume = 8,
    .channel = 4,
    .mode = 0,
};

var now: f32 = 0;

var last_blip: f32 = 0;

export fn update() void {
    now += 1.0 / 60.0;

    w4.PALETTE.* = .{
        0xfff6d3, // yellow
        0xf9a875, // orange
        0xeb6b6f, // red
        0x7c3f58, // brown
    };

    w4.DRAW_COLORS.* = 0x03;
    // w4.DRAW_COLORS.* = 2;
    w4.text("Hello from Zig!", 10, 10);
    w4.DRAW_COLORS.* = 2;
    w4.oval(@floatToInt(i32, player.x), @floatToInt(i32, player.y), 10, 10);

    const gamepad = w4.GAMEPAD1.*;
    if (gamepad & w4.BUTTON_UP != 0) {
        player.y -= 1;
    }
    if (gamepad & w4.BUTTON_DOWN != 0) {
        player.y += 1;
    }
    if (gamepad & w4.BUTTON_LEFT != 0) {
        player.x -= 1;
    }
    if (gamepad & w4.BUTTON_RIGHT != 0) {
        player.x += 1;
    }
    if (gamepad & w4.BUTTON_1 != 0) {
        w4.DRAW_COLORS.* = 0x01;
        if (now - last_blip > 0.50) {
            play(blip);
            last_blip = now;
        }
    }

    // w4.blit(&smiley, 76, 76, 8, 8, w4.BLIT_1BPP);
    w4.DRAW_COLORS.* = 4;
    // w4.rect(79, 79, 20, 20);
    w4.DRAW_COLORS.* = 0x4321;
    // w4.blit(&atlas.data, 80 + @floatToInt(i32, player.x), 80 + @floatToInt(i32, player.y), atlas.width, atlas.height, atlas.flags);
    // const size = 16;
    w4.blitSub(&atlas.data, 80, 80, 8, 8, 0, 0, atlas.width, atlas.flags);
    // w4.text("Press X to blink", 16, 90);
}
