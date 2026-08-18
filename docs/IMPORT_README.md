# HighCraft Update Pack — Desktop Full Version (Foundation)

## Where to import

Copy files into your Godot project:

| Pack file | Project path |
|-----------|----------------|
| `scripts/hc_settings.gd` | `res://scripts/hc_settings.gd` |
| `scripts/room_code.gd` | `res://scripts/room_code.gd` |
| `scripts/split_screen_manager.gd` | `res://scripts/split_screen_manager.gd` |
| `scripts/chunk_stream_config.gd` | `res://scripts/world/chunk_stream_config.gd` (or `res://scripts/`) |
| `scripts/multiplayer_manager.gd` | **Replace** `res://scripts/multiplayer_manager.gd` |
| `scripts/main_menu.gd` | **Replace** `res://scripts/main_menu.gd` |

### Autoloads (Project → Project Settings → Autoload)

| Name | Path |
|------|------|
| `HCSettings` | `res://scripts/hc_settings.gd` |
| `Multiplayer` | `res://scripts/multiplayer_manager.gd` (already) |

Keep existing: Registry, Config, Textures, Audio, Music, SaveManager, …

### Wire split-screen in `game.gd` (after player spawn)

```gdscript
var split_n := 1
if has_node("/root/HCSettings"):
    split_n = HCSettings.splitscreen_players
if split_n > 1:
    var ssm = SplitScreenManager.new()
    add_child(ssm)
    ssm.start(split_n, self, player.global_position)
    # hide / disable the default single player or use players[0] as primary
```

### Wire chunk threshold in your chunk loader `_process`

```gdscript
var _stream := ChunkStreamConfig.new()

# inside tick:
if not _stream.should_reeval(player.global_position):
    return
var load_r = _stream.load_radius()
var unload_r = _stream.unload_radius()
# ... existing load/unload logic using load_r / unload_r
```

### Player controller (per split index)

In `player.gd` movement, if `has_meta("split_index")`:

```gdscript
var idx = int(get_meta("split_index", 0))
var mv = SplitScreenManager.read_move_axis(idx, HCSettings.controller_deadzone)
var look = SplitScreenManager.read_look_axis(idx, HCSettings.controller_aim_sensitivity, HCSettings.controller_deadzone)
```

P1: keyboard + mouse + pad0. P2–P4: **controller or second keyboard only** (no shared mouse).

### Room codes

- Host → menu **Host Server** → code like `AB3K-9Q2M` = LAN IP + port  
- Same Wi‑Fi: friends enter code under **Join**  
- Internet without Tailscale: still need port-forward or a future relay (code alone cannot punch NAT)

### Platforms

This pack targets **Linux / Windows / macOS** desktop export. Android later (touch UI + different input).

### Physics FX flags

Read `HCSettings.physics_fx` / `realistic_water` / `footprints` / `swaying_flowers` / `tall_grass_mesh` in mesher / player footstep code and skip work when false.

### Saves

Load World lists `user://saves/*.json`. Implement `SaveManager.list_saves()` / `rename_save()` if missing.
