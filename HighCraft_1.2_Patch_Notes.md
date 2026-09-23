# HighCraft 1.2 Patch Notes

A big new update for HighCraft, introducing a brand-new boss, a new dimension, real biomes, improved world generation, new villages, new tools, new sounds, and much more.

## 🔥 New Boss: The Red Dragon

Update 1.2 introduces the Red Dragon, found in a completely new dimension.

### How to enter the Red Dimension

- Build a portal frame out of **wool** (any colour works).
- Light it with **flint and steel** to activate it.
- The dimension looks similar to the Overworld, but with a clear, cloudless deep-blue sky.

### Red Dragon features

The dragons of the Red Dimension are **not aggressive by default** — they only attack once you hit them first. You can either:

- **Fight** the dragon, or
- **Tame** it using **fish** (the taming food).

Hold fish in your hand and the dragon will fly down to you and land within reach so it can be fed. Each dragon needs several fish to be tamed. Once tamed you can mount it directly (no saddle required) and take to the skies:

- **Space / A** → Fly up
- **Shift / B** → Fly down
- **X / LT / Left Mouse Button** → Shoot TNT

Attacking a dragon makes it fight back immediately — it circles the sky, lands near you and strikes. If you stop fighting it for long enough it calms down and becomes peaceful again.

### 🔥 Additional Dragon Variants

The Red Dragon is not alone in Update 1.2 — the new dimension also includes two alternate dragon variants:

- **Pink Dragon**
- **White Dragon**

All three variants behave the same way: you can fight them or tame them with fish, and once tamed you can fly them with the same controls. Each variant appears naturally in the wool-portal dimension, giving players more choice and more fun when exploring or collecting rare creatures.

## 🌍 Real Biomes Added to the Overworld

The Overworld finally gets proper biome generation, driven by temperature and moisture noise:

- **Ice biome** — snow-covered ground and frozen water surfaces.
- **Snow biome** — spruce trees and snowy ground.
- **Desert biome** — sand and sandstone, no trees.
- **Standard Overworld biome** — classic oak trees and grass.
- **Spruce forest biome** — dense spruce woodland.

Each biome also receives its own unique villages.

## 🏘️ New Village Types

Villages now match their biome:

- **Ice Villages** → Igloos with doors.
- **Snow Villages** → Wooden villages built from spruce.
- **Spruce Forest Villages** → Full spruce-wood architecture.
- **Overworld Villages** → Improved classic villages with fixed roofs, doors, windows, blacksmiths, churches, farms and wells.
- **Desert Villages** → Sand villages built from sandstone.
- **Desert Temples** → Classic-style sand temples return, with a hidden chamber beneath the floor.

The entire Overworld feels much more alive and varied.

## ⛏️ New Tools & Armor

Update 1.2 adds:

- **Emerald Tools** — the highest tier (tier 6), 1900 durability and 8 base attack damage.
- **Emerald Armor** — the strongest armor set (helmet 4 / chestplate 8 / leggings 7 / boots 4).
- **Enchanted Diamond Apple**
- **Enchanted Emerald Apple**

## 🕳️ Improved Cave Generation

Caves are no longer empty or boring single holes. A 3D-noise cave carver now generates a connected network of winding tunnels and caverns that vary in:

- **Size** — a second, slower noise modulates the tunnel radius, so caves range from narrow passages to large caverns.
- **Shape** — tunnels twist and branch naturally instead of running in a straight line.
- **Contents** — ore veins are exposed directly in the cave walls (coal, copper, iron, gold, redstone, lapis, diamond and emerald, distributed by depth), along with loot chests, lava pools deep underground and cobwebs for atmosphere.

Caving is now the rewarding way to find rare ore.

## 🗣️ New Villager Sounds

Villagers received new custom-recorded sounds inspired by a well-known block game (cannot name it due to copyright). These sounds give HighCraft's villagers a more recognizable personality.

## 🎮 Controls and Interface

- **Item drop button moved to X / Square** (left action button). It previously shared Select/Back, which is now reserved for chat and the on-screen keyboard. Ctrl + X drops the whole stack.
- **X removed as a secondary attack/button** — attack, mine and shoot the bow remain on the right trigger and the left mouse button, so the bow no longer double-fires when X is pressed.
- **World options panels now scroll.** The New World and Load Options panels clamp to the screen height, scroll with the mouse wheel, and auto-scroll to keep the focused control (including the Create World button) visible when navigating with a controller.

## 🐉 Dragon and World Fixes

- **Fixed End/Heaven spawn travel**: the obsidian spawn platform is now meshed first (the chunk the player stands in is prioritized in the build queue) and the player is held on the spawn point until its collision exists, so you no longer fall through the platform and out of the map on arrival.
- Fixed player model build errors (`foot_h`, `head_size`, stack-count inference) that could break the avatar entirely.
- Fixed a worker-thread race in the chunk mesher that resolved the block registry off the main thread, causing "Bad address index" and "previously freed" errors and lag while streaming chunks — most visible in split-screen.
- Fixed Q / drop-all dropping the wrong items from crafting, furnace and chest bags (armor was dropped instead of the bag's contents).
- Fixed villager sound files not loading from the alternate audio folder.
- Dropped items now use fully opaque item textures (no black transparency), burn in fire and lava when enabled, and can be picked up by every player.
- Armor is now visible on the player model and scales with the skin, legs adapt their width and position to the skin, and the hand swings forward when hitting or breaking blocks.
- Added world-creation options for whether items burn in fire/lava and whether players keep their inventory on death.

## ✨ Summary

HighCraft Update 1.2 brings:

- A new dimension
- A tameable Red Dragon boss with Pink and White variants
- Real biome generation
- Unique biome-based villages
- Desert temples
- Improved Overworld structures
- New emerald gear and enchanted apples
- Proper procedural caves with ores
- New villager sounds
- Controller/interface improvements and bug fixes

This update makes the world feel bigger, more alive, more varied, and more fun to explore.
