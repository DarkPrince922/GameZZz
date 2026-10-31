You are reviewing a Godot 4.5 (GDScript) Android platformer project for **compile-time and runtime errors only**. Godot is NOT installed in this environment, so this is a careful static review against Godot 4.x API knowledge. Do not comment on style, naming, game design or missing features.

Scope: all .gd files under scripts/, tests/, tools/ and the .tscn files in scenes/.

Focus on these specific error classes, in priority order:
1. **Static typing errors**: calling a script-defined method/property on a variable statically typed as a built-in class (e.g. `var e: CharacterBody2D = ...; e.configure()`), assigning Variant to typed vars illegally, wrong signal callback arity, returning wrong types.
2. **Wrong Godot 4.x API**: methods/properties that do not exist in Godot 4.5 or were renamed from Godot 3 (AudioServer, AudioStreamWAV/AudioStreamOggVorbis, CharacterBody2D.move_and_slide/velocity, Tween API, Control anchors/theme overrides, Input, DisplayServer, FileAccess, DirAccess, JSON, ThemeDB, draw_* signatures, SceneTree signals).
3. **Autoload/order problems**: autoload list in project.godot vs usage, nodes accessing autoloads during _ready before they exist, `get_node_or_null("/root/X")` guards.
4. **Preload/cycle problems**: preload of a scene/script that preloads back, preload paths that do not exist (cross-check with files on disk).
5. **Node lifecycle**: adding children in _ready, freeing nodes that are still referenced, signals connected to freed objects, awaiting on a paused tree.

Deliverable: a numbered list of concrete problems as `path:line — what is wrong — minimal fix`. If a file is correct, do not mention it. Be precise and conservative: only report things you are confident are actual errors in Godot 4.5, and mark anything uncertain as "UNSURE". Do not modify any files.