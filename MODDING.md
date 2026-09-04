# HighCraft add-ons

On first launch HighCraft creates `Mods`, `Shaders`, and `Texture Packs`. Portable Windows/Linux builds use `HighCraft Addons` beside the executable. Sandboxed systems—including consoles, mobile, Web and macOS app bundles—use the platform-owned application data directory. The **Mods & Packs** screen displays the exact location available on the current platform. In the Godot editor the equivalent directory is `external_addons` in the project root.

Every add-on is one folder containing a `pack.json` file. ZIP downloads may contain that folder or place `pack.json` at the ZIP root.

## Texture pack

```json
{
  "id": "my_textures",
  "name": "My Textures",
  "type": "texture_pack",
  "version": "1.0",
  "textures": "textures",
  "enabled": true
}
```

Put PNG files in `textures/`. Their filename is the registry ID, for example `grass_block.png`, `diamond_sword.png`, or `zombie.png`. Packs loaded later alphabetically override earlier packs. Restart the world after changing textures so chunk materials are rebuilt.

## Shader pack

```json
{
  "id": "my_sky",
  "name": "My Sky",
  "type": "shader",
  "version": "1.0",
  "sky_shader": "sky.gdshader",
  "enabled": true
}
```

`sky.gdshader` must use `shader_type sky`. HighCraft supplies the parameters `time_of_day`, `rain_amount`, and `thunder_flash`, so compatible shaders should declare those uniforms.

## GDScript mod

For a single-file mod, simply place `my_mod.gd` directly inside the `Mods` folder. No manifest or subfolder is required. Larger mods can use the folder format below.

```json
{
  "id": "hello_mod",
  "name": "Hello Mod",
  "type": "mod",
  "version": "1.0",
  "entry": "main.gd",
  "enabled": true
}
```

```gdscript
extends Node

func on_mod_loaded(api: Node) -> void:
    print("Hello Mod loaded from ", api.root_dir)

func on_game_ready(game: Node) -> void:
    print("World ready: ", game)
```

Mods are arbitrary executable code. Only install GDScript mods from authors you trust. Downloaded GDScript execution is enabled on desktop/editor builds. Consoles generally prohibit downloaded executable code, so console builds load texture and shader content but skip GDScript entry points. Platform-native, reviewed mods can still be shipped as game content for a console release.

## In-game downloads

Open **Mods & Packs** on the main menu, paste a direct HTTP or HTTPS URL to a ZIP, and choose **Download and install ZIP**. The installer reads `pack.json`, selects the correct destination, rejects parent-directory paths, installs the pack, and rescans it. Restart the current world when requested.
