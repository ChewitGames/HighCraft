# HighCraft 1.1 Patch Notes

## Split-Screen and Game UI

- Increased gameplay UI text readability in real split-screen layouts.
- Improved text scaling in the Villager trading screen, Creative Inventory, player inventory, Enchantment Table, Chest, Hopper, Dropper, Dispenser and Command Block interfaces.
- Kept the on-screen keyboard layout compatible with split-screen.
- Redesigned the active-effect HUD with larger text, clearer colors, bordered panels and improved spacing.
- Achievements now show a checkmark when completed and an empty checkbox while incomplete.
- Achievement progress is stored per world and per local player instead of being treated as global progress.
- Added player-specific controller navigation to the Recipe Book and Achievements interfaces, including stick/D-Pad selection, A confirmation and B closing.
- Smoothed the animated main-menu world preview by moving its terrain generation off the main thread and spreading render-section uploads across frames.

## Blocks and Chunk Updates

- Split rendered terrain chunks into independent 16 x 16 x 16 render sections.
- Player block placement, mining and explosion remeshing now use a dedicated edit thread, separate from both the streaming worker pool and the main gameplay thread.
- Block changes rebuild only their affected render section; directly adjacent sections are included only when a change touches a section or chunk boundary.
- Only the required GPU mesh and collision installation remains on the main thread, as required by Godot's rendering and physics servers.
- Improved handling of repeated edits while a chunk is already being rebuilt.
- Explosions batch their changes per affected render section and prioritize those smaller mesh updates immediately.
- Existing chunk geometry remains visible until the updated geometry is ready, reducing disappearing chunks and visible reloads.
- Fixed a background chunk-job race that could report a null mutex when leaving a server.

## Fire and TNT

- Normal fire now burns out after a limited amount of time.
- Portal blocks remain permanent and are not treated as temporary fire.
- Added a world-creation option controlling whether fire can spread.
- Fire expiration remains active even when fire spreading is disabled.
- Added a world-creation option controlling whether TNT damages blocks.
- Added a separate world-creation option controlling TNT chain reactions.
- Exploding TNT can ignite other TNT blocks inside its blast radius with a shortened randomized fuse.
- Fire and TNT world rules are stored in each save and synchronized with multiplayer clients.

## Worlds and Servers

- Added support for multiple separately stored worlds.
- New worlds can be given a name during creation.
- Added a saved-world list with loading and renaming controls.
- Saved worlds can now be loaded directly in local split-screen with a selectable 2–4 player count.
- Fixed controller navigation in the saved-world screen so left/right moves across a world row and up/down moves between rows.
- Existing legacy single-slot saves are imported automatically as an individual world.
- Added named saved-server profiles for room codes.
- Saved servers can be selected again or renamed by updating the profile with the same room code.

## Animals

- Added species-specific taming for horses, pigs, wolves and ocelots.
- Horses are tamed with wheat or apples; pigs with carrots; wolves with meat; ocelots with chicken.
- Horses and pigs can only receive a saddle after they have been tamed.
- Fixed mounted horses and pigs accumulating invalid movement and throwing the rider outside the map.
- Mount steering now supports the correct local split-screen controller and is clamped to the world border.
- Tamed wolves become dogs and tamed ocelots become cats.
- Adult peaceful animals can enter love mode with their species' breeding food, run toward a matching partner and produce a baby mob.
- Babies grow into adults after one in-game day. Parents have a five-minute breeding cooldown.

## Difficulty and Creative

- Hostile mobs no longer spawn on Peaceful and existing hostile mobs disappear.
- Passive mobs remain non-aggressive on Peaceful.
- Mobs no longer target or damage Creative-mode players.

## Commands

- Added `/effect [@target] <effect_name> <level> <duration>` and the `/effekt` alias.
- Effect levels support values from 1 to 255.
- Effect duration supports values from 1 to 1,000,000 seconds.

## Farming

- Wheat, carrots and potatoes now have four visible growth stages.
- Added a dedicated pixel-art crop texture atlas.
- Hydrated crops mature in one complete in-game day; dry crops pause until watered or rained on.
- Nearby water converts farmland to moist farmland.

## Weather

- Lightning transforms pigs into Zombie Piglins.
- Lightning turns Creepers into Charged Creepers.

## Achievements

- Opening the inventory completes Taking Inventory for the current player and world.
- Mining stone completes Stone Age for the current player and world.
- Planting wheat completes A Seedy Place for the current player and world.
