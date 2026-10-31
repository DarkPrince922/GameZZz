"""Declarative SFX table: game event id -> synthesis recipe.

`variants` = how many alternative files are generated (frequent sounds get
several so repeats do not become annoying, spec section 4).
`pitch` = random pitch spread applied by AudioManager (+-10% for frequent ones).
`spatial` = play through AudioStreamPlayer2D at the emitter position.
"""

from __future__ import annotations

SFX = {
    # ------------------------------------------------------------------ hero
    "hero_step": {
        "arch": "thump", "variants": 4, "vol": -13.0, "pitch": 0.10,
        "dur": 0.085, "f0": 190.0, "f1": 95.0, "decay": 34.0,
        "noise": 0.55, "noise_decay": 70.0, "low": 300.0, "cut": 2600.0,
    },
    "hero_jump": {
        "arch": "chirp", "variants": 2, "vol": -9.0, "pitch": 0.06,
        "dur": 0.19, "f0": 330.0, "f1": 760.0, "wave": "tri", "curve": 0.7,
        "decay": 13.0, "attack": 0.004,
    },
    "hero_double_jump": {
        "arch": "chirp", "variants": 2, "vol": -8.0, "pitch": 0.06,
        "dur": 0.24, "f0": 520.0, "f1": 1180.0, "wave": "tri", "curve": 0.65,
        "decay": 11.0, "vibrato": 0.02, "vib_rate": 18.0,
    },
    "hero_land": {
        "arch": "thump", "variants": 3, "vol": -10.0, "pitch": 0.08,
        "dur": 0.14, "f0": 130.0, "f1": 60.0, "decay": 22.0,
        "noise": 0.45, "noise_decay": 45.0, "low": 200.0, "cut": 2000.0,
    },
    "hero_dash": {
        "arch": "noiseburst", "variants": 2, "vol": -9.0, "pitch": 0.07,
        "dur": 0.26, "low": 700.0, "cut": 5200.0, "decay": 16.0,
        "body_f0": 420.0, "body_f1": 160.0, "body": 0.35,
    },
    "hero_crouch": {
        "arch": "blip", "variants": 1, "vol": -14.0, "pitch": 0.0,
        "dur": 0.09, "f0": 240.0, "f1": 170.0, "wave": "tri", "decay": 26.0,
    },
    "hero_climb": {
        "arch": "rattle", "variants": 3, "vol": -15.0, "pitch": 0.10,
        "dur": 0.32, "hits": 3, "spacing": 0.10, "low": 600.0,
        "cut": 3800.0,
    },
    "hero_hurt": {
        "arch": "zap", "variants": 2, "vol": -7.0, "pitch": 0.05,
        "dur": 0.28, "f0": 900.0, "f1": 220.0, "wave": "saw", "decay": 13.0,
        "crackle": 0.35,
    },
    "hero_death": {
        "arch": "chord", "variants": 1, "vol": -6.0, "pitch": 0.0,
        "dur": 1.1, "notes": [64, 60, 55, 48], "wave": "tri", "attack": 0.01,
        "d_attack": 0.15, "sustain": 0.35, "release": 0.6, "spread": 0.9,
        "shimmer": 0.2, "reverb": 0.25,
    },
    "hero_respawn": {
        "arch": "chord", "variants": 1, "vol": -8.0, "pitch": 0.0,
        "dur": 0.9, "notes": [60, 67, 72, 76], "wave": "tri", "attack": 0.02,
        "d_attack": 0.1, "sustain": 0.4, "release": 0.5, "shimmer": 0.35,
        "reverb": 0.3,
    },
    "hero_low_health": {
        "arch": "pattern", "variants": 1, "vol": -15.0, "pitch": 0.0,
        "notes": [76, 72], "step": 0.16, "wave": "sine", "decay": 10.0,
        "tail": 0.2,
    },

    # --------------------------------------------------------------- weapons
    "weapon_swing_light_sword": {
        "arch": "noiseburst", "variants": 3, "vol": -7.0, "pitch": 0.08,
        "dur": 0.2, "low": 900.0, "cut": 6800.0, "decay": 20.0,
        "body_f0": 620.0, "body_f1": 300.0, "body": 0.3, "reverb": 0.12,
    },
    "weapon_swing_lantern": {
        "arch": "sweep", "variants": 2, "vol": -8.0, "pitch": 0.06,
        "dur": 0.34, "f0": 300.0, "f1": 900.0, "wave": "tri", "curve": 0.6,
        "sustain": 0.4,
    },
    "weapon_swing_moon_bow": {
        "arch": "blip", "variants": 2, "vol": -8.0, "pitch": 0.05,
        "dur": 0.16, "f0": 880.0, "f1": 320.0, "wave": "saw", "decay": 18.0,
        "cut": 4200.0, "layers": [{"arch": "noiseburst", "dur": 0.16,
                                   "low": 1500.0, "cut": 7000.0, "decay": 30.0}],
    },
    "weapon_swing_alarm_hammer": {
        "arch": "thump", "variants": 2, "vol": -6.0, "pitch": 0.05,
        "dur": 0.3, "f0": 120.0, "f1": 48.0, "decay": 12.0,
        "noise": 0.6, "noise_decay": 26.0, "low": 200.0, "cut": 3000.0,
        "layers": [{"arch": "blip", "dur": 0.3, "f0": 1720.0, "wave": "sine",
                    "decay": 9.0, "peak": 0.3}],
    },
    "weapon_swing_pillow_gloves": {
        "arch": "noiseburst", "variants": 2, "vol": -10.0, "pitch": 0.07,
        "dur": 0.17, "low": 250.0, "cut": 1800.0, "decay": 26.0,
        "body_f0": 150.0, "body_f1": 80.0, "body": 0.5,
    },

    # ---------------------------------------------------------------- combat
    "combat_hit": {
        "arch": "thump", "variants": 3, "vol": -6.0, "pitch": 0.10,
        "dur": 0.16, "f0": 220.0, "f1": 90.0, "decay": 24.0,
        "noise": 0.5, "noise_decay": 38.0, "low": 300.0, "cut": 4200.0,
        "layers": [{"arch": "blip", "dur": 0.16, "f0": 640.0, "wave": "square",
                    "decay": 22.0, "peak": 0.3}],
    },
    "combat_miss": {
        "arch": "noiseburst", "variants": 2, "vol": -14.0, "pitch": 0.08,
        "dur": 0.14, "low": 1400.0, "cut": 7000.0, "decay": 34.0,
    },
    "combat_combo": {
        "arch": "pattern", "variants": 1, "vol": -8.0, "pitch": 0.0,
        "notes": [72, 76, 79], "step": 0.07, "wave": "square", "decay": 16.0,
        "tail": 0.16, "fade_ms": 6.0,
    },
    "combat_block": {
        "arch": "blip", "variants": 2, "vol": -7.0, "pitch": 0.05,
        "dur": 0.22, "f0": 1180.0, "f1": 900.0, "wave": "pulse", "decay": 16.0,
        "cut": 6000.0,
        "layers": [{"arch": "noiseburst", "dur": 0.1, "low": 2500.0,
                    "cut": 8000.0, "decay": 40.0, "peak": 0.4}],
    },
    "combat_crit": {
        "arch": "chord", "variants": 1, "vol": -5.0, "pitch": 0.0,
        "dur": 0.4, "notes": [84, 88, 91], "wave": "square", "attack": 0.002,
        "d_attack": 0.05, "sustain": 0.2, "release": 0.2, "shimmer": 0.4,
        "reverb": 0.2,
    },

    # ---------------------------------------------------------------- skills
    "skill_dash": {
        "arch": "sweep", "variants": 2, "vol": -7.0, "pitch": 0.06,
        "dur": 0.24, "f0": 260.0, "f1": 1400.0, "wave": "saw", "curve": 0.4,
        "sustain": 0.3,
    },
    "skill_light_burst": {
        "arch": "chord", "variants": 1, "vol": -4.0, "pitch": 0.0,
        "dur": 0.75, "notes": [72, 76, 79, 84], "wave": "tri", "attack": 0.005,
        "d_attack": 0.08, "sustain": 0.3, "release": 0.4, "shimmer": 0.5,
        "reverb": 0.35,
    },
    "skill_shield_on": {
        "arch": "chord", "variants": 1, "vol": -8.0, "pitch": 0.0,
        "dur": 0.5, "notes": [67, 74, 79], "wave": "sine", "attack": 0.01,
        "d_attack": 0.06, "sustain": 0.5, "release": 0.2, "shimmer": 0.25,
    },
    "skill_shield_break": {
        "arch": "noiseburst", "variants": 1, "vol": -5.0, "pitch": 0.04,
        "dur": 0.45, "low": 900.0, "cut": 7500.0, "decay": 11.0,
        "layers": [{"arch": "rattle", "dur": 0.45, "hits": 5, "spacing": 0.06,
                    "low": 1800.0, "cut": 8000.0, "peak": 0.5}],
    },
    "skill_chain_lightning": {
        "arch": "zap", "variants": 1, "vol": -6.0, "pitch": 0.03,
        "dur": 0.42, "f0": 3200.0, "f1": 900.0, "wave": "square", "decay": 9.0,
        "crackle": 0.5,
        "layers": [{"arch": "pattern", "notes": [88, 84, 80], "step": 0.08,
                    "wave": "square", "decay": 20.0, "peak": 0.35}],
    },
    "skill_time_slow_in": {
        "arch": "chirp", "variants": 1, "vol": -9.0, "pitch": 0.0,
        "dur": 0.7, "f0": 900.0, "f1": 180.0, "wave": "sine", "curve": 0.5,
        "decay": 5.0, "attack": 0.05, "vibrato": 0.01, "vib_rate": 6.0,
    },
    "skill_time_slow_out": {
        "arch": "chirp", "variants": 1, "vol": -9.0, "pitch": 0.0,
        "dur": 0.6, "f0": 180.0, "f1": 820.0, "wave": "sine", "curve": 0.6,
        "decay": 5.0, "attack": 0.03, "vibrato": 0.012, "vib_rate": 7.0,
    },
    "skill_plush_friend": {
        "arch": "pattern", "variants": 1, "vol": -9.0, "pitch": 0.0,
        "notes": [79, 83, 86, 83], "step": 0.1, "wave": "tri", "decay": 14.0,
        "tail": 0.3, "reverb": 0.15,
    },
    "skill_fire_trail": {
        "arch": "noiseburst", "variants": 2, "vol": -8.0, "pitch": 0.07,
        "dur": 0.45, "low": 300.0, "cut": 3400.0, "decay": 8.0,
        "body_f0": 210.0, "body_f1": 120.0, "body": 0.4,
    },
    "skill_attract": {
        "arch": "sweep", "variants": 1, "vol": -9.0, "pitch": 0.0,
        "dur": 0.55, "f0": 1400.0, "f1": 240.0, "wave": "sine", "curve": 0.45,
        "sustain": 0.5,
    },
    "skill_invisibility": {
        "arch": "noiseburst", "variants": 1, "vol": -12.0, "pitch": 0.0,
        "dur": 0.6, "low": 2000.0, "cut": 9000.0, "decay": 6.0,
        "body_f0": 1400.0, "body_f1": 2400.0, "body": 0.15,
    },
    "skill_heal": {
        "arch": "chord", "variants": 1, "vol": -8.0, "pitch": 0.0,
        "dur": 0.8, "notes": [72, 76, 79, 83], "wave": "sine", "attack": 0.03,
        "d_attack": 0.1, "sustain": 0.4, "release": 0.35, "shimmer": 0.3,
        "reverb": 0.3,
    },
    "skill_star_rain": {
        "arch": "pattern", "variants": 1, "vol": -7.0, "pitch": 0.0,
        "notes": [84, 88, 91, 88, 84, 79], "step": 0.075, "wave": "tri",
        "decay": 18.0, "tail": 0.35, "reverb": 0.25,
    },
    "skill_dawn": {
        "arch": "chord", "variants": 1, "vol": -3.0, "pitch": 0.0,
        "dur": 1.8, "notes": [60, 64, 67, 72, 76], "wave": "tri",
        "attack": 0.12, "d_attack": 0.25, "sustain": 0.5, "release": 0.7,
        "shimmer": 0.6, "reverb": 0.45, "fade_ms": 40.0,
    },
    "skill_ready": {
        "arch": "blip", "variants": 1, "vol": -16.0, "pitch": 0.0,
        "dur": 0.12, "f0": 1320.0, "f1": 1760.0, "wave": "sine", "decay": 20.0,
    },

    # --------------------------------------------------------------- enemies
    "enemy_spawn": {
        "arch": "chirp", "variants": 2, "vol": -10.0, "pitch": 0.07, "spatial": True,
        "dur": 0.4, "f0": 120.0, "f1": 380.0, "wave": "saw", "curve": 0.7,
        "decay": 8.0, "vibrato": 0.03, "vib_rate": 14.0,
    },
    "enemy_attack": {
        "arch": "noiseburst", "variants": 2, "vol": -9.0, "pitch": 0.08, "spatial": True,
        "dur": 0.22, "low": 500.0, "cut": 4200.0, "decay": 18.0,
        "body_f0": 300.0, "body_f1": 140.0, "body": 0.35,
    },
    "enemy_hurt": {
        "arch": "blip", "variants": 2, "vol": -8.0, "pitch": 0.10, "spatial": True,
        "dur": 0.16, "f0": 420.0, "f1": 220.0, "wave": "square", "decay": 20.0,
        "cut": 4200.0,
    },
    "enemy_death": {
        "arch": "noiseburst", "variants": 2, "vol": -7.0, "pitch": 0.08, "spatial": True,
        "dur": 0.5, "low": 200.0, "cut": 3600.0, "decay": 9.0,
        "body_f0": 240.0, "body_f1": 60.0, "body": 0.45, "reverb": 0.15,
    },
    "enemy_bomber_beep": {
        "arch": "pattern", "variants": 2, "vol": -11.0, "pitch": 0.03, "spatial": True,
        "notes": [88, 88, 88], "step": 0.1, "wave": "square", "decay": 8.0,
        "tail": 0.05,
    },
    "enemy_bomber_explode": {
        "arch": "noiseburst", "variants": 1, "vol": -3.0, "pitch": 0.04, "spatial": True,
        "dur": 0.9, "low": 90.0, "cut": 3000.0, "decay": 5.5,
        "body_f0": 90.0, "body_f1": 35.0, "body": 0.7, "reverb": 0.3,
        "drive": 2.0,
    },
    "enemy_shooter_shoot": {
        "arch": "blip", "variants": 2, "vol": -8.0, "pitch": 0.06, "spatial": True,
        "dur": 0.15, "f0": 1500.0, "f1": 400.0, "wave": "saw", "decay": 22.0,
        "cut": 6000.0,
    },
    "enemy_flyer_fly": {
        "arch": "hum", "variants": 2, "vol": -14.0, "pitch": 0.06, "spatial": True,
        "dur": 0.55, "f0": 190.0, "harmonic": 2.6, "lfo": 9.0, "drift": 1.01,
        "air": 0.4,
    },
    "enemy_revive": {
        "arch": "chord", "variants": 1, "vol": -8.0, "pitch": 0.0, "spatial": True,
        "dur": 0.9, "notes": [48, 55, 60], "wave": "saw", "attack": 0.05,
        "d_attack": 0.15, "sustain": 0.3, "release": 0.4, "reverb": 0.3,
    },

    # ---------------------------------------------------------------- bosses
    "boss_roar": {
        "arch": "sweep", "variants": 1, "vol": -4.0, "pitch": 0.0, "spatial": True,
        "dur": 1.6, "f0": 70.0, "f1": 240.0, "wave": "saw", "curve": 0.5,
        "attack": 0.15, "sustain": 0.55, "reverb": 0.4, "drive": 1.8,
        "layers": [{"arch": "noiseburst", "dur": 1.6, "low": 120.0,
                    "cut": 1800.0, "decay": 3.0, "peak": 0.5}],
    },
    "boss_telegraph": {
        "arch": "pattern", "variants": 1, "vol": -10.0, "pitch": 0.0, "spatial": True,
        "notes": [79, 75], "step": 0.12, "wave": "pulse", "decay": 14.0,
        "tail": 0.15,
    },
    "boss_attack_claw": {
        "arch": "noiseburst", "variants": 1, "vol": -5.0, "pitch": 0.04, "spatial": True,
        "dur": 0.35, "low": 700.0, "cut": 7000.0, "decay": 14.0,
        "body_f0": 380.0, "body_f1": 150.0, "body": 0.4,
    },
    "boss_attack_toys": {
        "arch": "rattle", "variants": 1, "vol": -8.0, "pitch": 0.05, "spatial": True,
        "dur": 0.7, "hits": 6, "spacing": 0.1, "low": 900.0, "cut": 6000.0,
    },
    "boss_attack_tantrum": {
        "arch": "thump", "variants": 1, "vol": -3.0, "pitch": 0.03, "spatial": True,
        "dur": 0.8, "f0": 70.0, "f1": 32.0, "decay": 6.0,
        "noise": 0.7, "noise_decay": 9.0, "low": 80.0, "cut": 1600.0,
        "drive": 1.9, "reverb": 0.25,
    },
    "boss_hurt": {
        "arch": "blip", "variants": 2, "vol": -7.0, "pitch": 0.07, "spatial": True,
        "dur": 0.4, "f0": 190.0, "f1": 110.0, "wave": "saw", "decay": 12.0,
        "cut": 2600.0, "noise": 0.2,
    },
    "boss_phase": {
        "arch": "chord", "variants": 1, "vol": -4.0, "pitch": 0.0, "spatial": True,
        "dur": 1.3, "notes": [48, 55, 58, 63], "wave": "saw", "attack": 0.05,
        "d_attack": 0.2, "sustain": 0.45, "release": 0.5, "reverb": 0.35,
        "shimmer": 0.25,
    },
    "boss_stun": {
        "arch": "zap", "variants": 1, "vol": -6.0, "pitch": 0.0, "spatial": True,
        "dur": 0.7, "f0": 1400.0, "f1": 120.0, "wave": "saw", "decay": 7.0,
        "crackle": 0.6,
    },
    "boss_weakpoint_break": {
        "arch": "noiseburst", "variants": 1, "vol": -4.0, "pitch": 0.0, "spatial": True,
        "dur": 0.65, "low": 300.0, "cut": 6000.0, "decay": 10.0,
        "layers": [{"arch": "rattle", "dur": 0.6, "hits": 6, "spacing": 0.07,
                    "low": 1200.0, "cut": 9000.0, "peak": 0.6}],
        "reverb": 0.2,
    },
    "boss_death": {
        "arch": "chord", "variants": 1, "vol": -3.0, "pitch": 0.0, "spatial": True,
        "dur": 2.6, "notes": [45, 48, 52, 55], "wave": "saw", "attack": 0.02,
        "d_attack": 0.4, "sustain": 0.35, "release": 1.2, "reverb": 0.45,
        "drive": 1.6,
        "layers": [{"arch": "noiseburst", "dur": 2.6, "low": 90.0, "cut": 2400.0,
                    "decay": 2.2, "peak": 0.5}],
    },
    "boss_victory_line": {
        "arch": "pattern", "variants": 1, "vol": -8.0, "pitch": 0.0,
        "notes": [67, 71, 74, 79], "step": 0.16, "wave": "tri", "decay": 10.0,
        "tail": 0.6, "reverb": 0.3,
    },

    # ----------------------------------------------------------------- world
    "shard_pickup": {
        "arch": "blip", "variants": 3, "vol": -10.0, "pitch": 0.06,
        "dur": 0.2, "f0": 880.0, "f1": 1480.0, "wave": "sine", "decay": 16.0,
        "layers": [{"arch": "blip", "dur": 0.2, "f0": 1320.0, "f1": 1980.0,
                    "wave": "sine", "decay": 20.0, "peak": 0.35}],
    },
    "chest_open": {
        "arch": "rattle", "variants": 1, "vol": -8.0, "pitch": 0.0, "spatial": True,
        "dur": 0.6, "hits": 3, "spacing": 0.12, "low": 400.0, "cut": 4000.0,
        "layers": [{"arch": "chord", "dur": 0.6, "notes": [72, 79, 84],
                    "wave": "tri", "sustain": 0.4, "peak": 0.4}],
    },
    "secret_found": {
        "arch": "pattern", "variants": 1, "vol": -8.0, "pitch": 0.0,
        "notes": [72, 76, 79, 84, 88], "step": 0.09, "wave": "tri",
        "decay": 12.0, "tail": 0.4, "reverb": 0.25,
    },
    "trap_spikes": {
        "arch": "rattle", "variants": 2, "vol": -8.0, "pitch": 0.08, "spatial": True,
        "dur": 0.3, "hits": 3, "spacing": 0.05, "low": 900.0, "cut": 7000.0,
    },
    "trap_falling_platform": {
        "arch": "thump", "variants": 1, "vol": -9.0, "pitch": 0.05, "spatial": True,
        "dur": 0.45, "f0": 140.0, "f1": 60.0, "decay": 8.0,
        "noise": 0.4, "noise_decay": 12.0, "low": 200.0, "cut": 2400.0,
    },
    "trap_laser": {
        "arch": "hum", "variants": 1, "vol": -12.0, "pitch": 0.0, "spatial": True,
        "dur": 0.45, "f0": 620.0, "harmonic": 3.0, "lfo": 24.0, "drift": 1.0,
    },
    "trap_moving_wall": {
        "arch": "noiseburst", "variants": 1, "vol": -11.0, "pitch": 0.04, "spatial": True,
        "dur": 0.7, "low": 120.0, "cut": 1400.0, "decay": 5.0,
        "body_f0": 80.0, "body_f1": 60.0, "body": 0.3,
    },
    "door_open": {
        "arch": "noiseburst", "variants": 1, "vol": -9.0, "pitch": 0.0, "spatial": True,
        "dur": 0.8, "low": 200.0, "cut": 2200.0, "decay": 4.0,
        "body_f0": 110.0, "body_f1": 90.0, "body": 0.35,
        "layers": [{"arch": "chord", "dur": 0.8, "notes": [60, 67, 72],
                    "wave": "sine", "sustain": 0.4, "peak": 0.35}],
    },
    "water_splash": {
        "arch": "noiseburst", "variants": 2, "vol": -8.0, "pitch": 0.06, "spatial": True,
        "dur": 0.5, "low": 500.0, "cut": 6500.0, "decay": 10.0,
        "body_f0": 240.0, "body_f1": 520.0, "body": 0.2,
    },
    "rewind": {
        "arch": "sweep", "variants": 1, "vol": -8.0, "pitch": 0.0,
        "dur": 1.1, "f0": 1400.0, "f1": 180.0, "wave": "square", "curve": 0.35,
        "sustain": 0.5,
        "layers": [{"arch": "pattern", "notes": [84, 79, 74, 69], "step": 0.11,
                    "wave": "square", "decay": 16.0, "peak": 0.35}],
    },

    # ------------------------------------------------------------- ambience
    "amb_world_1": {
        "arch": "hum", "variants": 1, "vol": -20.0, "pitch": 0.0,
        "dur": 6.0, "f0": 96.0, "harmonic": 1.5, "lfo": 0.18, "drift": 1.004,
        "air": 0.5, "fade_ms": 60.0,
    },
    "amb_world_2": {
        "arch": "hum", "variants": 1, "vol": -20.0, "pitch": 0.0,
        "dur": 6.0, "f0": 74.0, "harmonic": 2.2, "lfo": 0.12, "drift": 1.002,
        "air": 1.0, "fade_ms": 60.0,
    },
    "amb_world_3": {
        "arch": "hum", "variants": 1, "vol": -21.0, "pitch": 0.0,
        "dur": 6.0, "f0": 58.0, "harmonic": 3.1, "lfo": 0.09, "drift": 1.003,
        "air": 0.6, "fade_ms": 80.0,
    },
    "amb_world_4": {
        "arch": "hum", "variants": 1, "vol": -22.0, "pitch": 0.0,
        "dur": 6.0, "f0": 110.0, "harmonic": 4.0, "lfo": 0.3, "drift": 1.006,
        "air": 0.4, "fade_ms": 80.0,
    },
    "amb_world_5": {
        "arch": "hum", "variants": 1, "vol": -19.0, "pitch": 0.0,
        "dur": 6.0, "f0": 66.0, "harmonic": 1.8, "lfo": 0.15, "drift": 1.002,
        "air": 1.4, "fade_ms": 90.0,
    },
    "amb_world_6": {
        "arch": "hum", "variants": 1, "vol": -22.0, "pitch": 0.0,
        "dur": 6.0, "f0": 132.0, "harmonic": 5.0, "lfo": 0.22, "drift": 1.008,
        "air": 0.3, "fade_ms": 60.0,
    },
    "amb_world_7": {
        "arch": "hum", "variants": 1, "vol": -21.0, "pitch": 0.0,
        "dur": 6.0, "f0": 88.0, "harmonic": 6.0, "lfo": 1.0, "drift": 1.001,
        "air": 0.25, "fade_ms": 50.0,
    },
    "amb_world_8": {
        "arch": "hum", "variants": 1, "vol": -18.0, "pitch": 0.0,
        "dur": 6.0, "f0": 44.0, "harmonic": 2.0, "lfo": 0.07, "drift": 1.002,
        "air": 0.8, "fade_ms": 100.0,
    },

    # ------------------------------------------------------------------- ui
    "ui_click": {
        "arch": "blip", "variants": 2, "vol": -14.0, "pitch": 0.03, "bus": "UI",
        "dur": 0.08, "f0": 900.0, "f1": 1200.0, "wave": "sine", "decay": 30.0,
    },
    "ui_toggle": {
        "arch": "blip", "variants": 1, "vol": -14.0, "pitch": 0.0, "bus": "UI",
        "dur": 0.1, "f0": 660.0, "f1": 880.0, "wave": "tri", "decay": 24.0,
    },
    "ui_purchase": {
        "arch": "pattern", "variants": 1, "vol": -9.0, "pitch": 0.0, "bus": "UI",
        "notes": [79, 84, 88], "step": 0.08, "wave": "tri", "decay": 14.0,
        "tail": 0.3,
    },
    "ui_denied": {
        "arch": "pattern", "variants": 1, "vol": -11.0, "pitch": 0.0, "bus": "UI",
        "notes": [55, 52], "step": 0.1, "wave": "square", "decay": 16.0,
        "tail": 0.12,
    },
    "ui_achievement": {
        "arch": "pattern", "variants": 1, "vol": -8.0, "pitch": 0.0, "bus": "UI",
        "notes": [72, 76, 79, 84], "step": 0.1, "wave": "tri", "decay": 10.0,
        "tail": 0.5, "reverb": 0.25,
    },
    "ui_star": {
        "arch": "blip", "variants": 3, "vol": -10.0, "pitch": 0.02, "bus": "UI",
        "dur": 0.25, "f0": 1180.0, "f1": 1760.0, "wave": "sine", "decay": 12.0,
    },
    "ui_pause": {
        "arch": "chord", "variants": 1, "vol": -13.0, "pitch": 0.0, "bus": "UI",
        "dur": 0.25, "notes": [67, 62], "wave": "sine", "attack": 0.004,
        "d_attack": 0.05, "sustain": 0.3, "release": 0.12,
    },
    "ui_level_start": {
        "arch": "pattern", "variants": 1, "vol": -9.0, "pitch": 0.0, "bus": "UI",
        "notes": [60, 67, 72], "step": 0.11, "wave": "tri", "decay": 10.0,
        "tail": 0.45, "reverb": 0.2,
    },
}
