const std = @import("std");
const Zynth = @import("zynth");
const c = Zynth.c;
const Waveform = Zynth.Waveform;
const Envelop = Zynth.Envelop;
const Mixer = Zynth.Mixer;
const RingBuffer = Zynth.RingBuffer;
const Replay = Zynth.Replay;
const Modulate = Zynth.Modulate;
const Audio = Zynth.Audio;
const Config = Zynth.Config;
const Streamer = Zynth.Streamer;

var rand = std.Random.Xoroshiro128.init(0);
var random = rand.random();

// TODO: Configurable parameters

pub fn bass(a: std.mem.Allocator) !Streamer {
    const sine = try a.create(Waveform.FreqEnvelop);
    sine.* = Waveform.FreqEnvelop.init(1.0, Envelop.LinearEnvelop(f64, f64).init(
            try a.dupe(f64, &.{0.02, 0.5}), 
            try a.dupe(f64, &.{300, 50, 50})

    ), .Sine);
    const envelop = try a.create(Envelop.Envelop);
    envelop.* = Envelop.Envelop.init(
        try a.dupe(f32, &.{0.02, 0.02, 0.4, 0.02}), 
        try a.dupe(f32, &.{0.0, 1.0, 0.8, 0.6, 0.0}), 
        sine.streamer()
    );
    return envelop.streamer();
}

// TODO: experiment with ring modulator
pub fn close_hi_hat(a: std.mem.Allocator) !Streamer {
    const noise = try a.create(Waveform.WhiteNoise);
    noise.amp = 0.15;
    noise.random = random;
    const envelop = try a.create(Envelop.Envelop);
    envelop.* = Envelop.Envelop.init(
        try a.dupe(f32, &.{0.01, 0.05}), 
        try a.dupe(f32, &.{0.0, 1.0, 0.0}), 
        noise.streamer());
    return envelop.streamer();
}

pub fn snare(a: std.mem.Allocator) !Streamer {
    const snare_mixer = try a.create(Mixer);
    snare_mixer.* = Mixer {};

    const hit = try a.create(Waveform.WhiteNoise);
    hit.* = Waveform.WhiteNoise {.amp = 1, .random = random };
    const hit_envelop = try a.create(Envelop.Envelop);
    hit_envelop.* = Envelop.Envelop.init(
        try a.dupe(f32, &.{0.005}), 
        try a.dupe(f32, &.{1.0, 1.0}), 
        hit.streamer());
    snare_mixer.play(hit_envelop.streamer());

    const body = try a.create(Waveform.FreqEnvelop);
    body.* = Waveform.FreqEnvelop.init(0.7, .{
        .durations = try a.dupe(f64, &.{0.01, 0.04}),
        .heights = try a.dupe(f64, &.{250, 200, 190}),
    }, .Sine);
    const body_envelop = try a.create(Envelop.Envelop);
    body_envelop.* = Envelop.Envelop.init(
        try a.dupe(f32, &.{0.05}), 
        try a.dupe(f32, &.{1, 0.0}), 
        body.streamer());
    snare_mixer.play(body_envelop.streamer());

    const vibrate = try a.create(Waveform.WhiteNoise);
    vibrate.* = Waveform.WhiteNoise {.amp = 0.3, .random = random };
    const vibrate_envelop = try a.create(Envelop.Envelop);
    vibrate_envelop.* = Envelop.Envelop.init(
        try a.dupe(f32, &.{0.015, 0.05}), 
        try a.dupe(f32, &.{0, 1.0, 0}), 
        vibrate.streamer());
    snare_mixer.play(vibrate_envelop.streamer());

    const metallic_mod = try a.create(Waveform.FreqEnvelop);
    metallic_mod.* = Waveform.FreqEnvelop.init(0.2, .{
        .durations = try a.dupe(f64, &.{0.04}),
        .heights = try a.dupe(f64, &.{200, 180}),
    }, .Triangle);

    const metallic_car = try a.create(Waveform.FreqEnvelop);
    metallic_car.* = Waveform.FreqEnvelop.init(1, .{
        .durations = try a.dupe(f64, &.{0.04}),
        .heights = try a.dupe(f64, &.{1000, 1000}),
    }, .Sine);
    const ring_mod = try a.create(Modulate.RingModulater);
    ring_mod.* = .{.modulator = metallic_mod.streamer(), .carrier = metallic_car.streamer()};
    const ring_envelop = try a.create(Envelop.Envelop);
    ring_envelop.* = Envelop.Envelop.init(
        try a.dupe(f32, &.{0.01, 0.007, 0.03}), 
        try a.dupe(f32, &.{0, 0, 1, 0.0}), 
        ring_mod.streamer());

    snare_mixer.play(ring_envelop.streamer());

    return snare_mixer.streamer();
}
