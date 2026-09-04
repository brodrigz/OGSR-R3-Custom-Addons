# Radiophobia Seb’s Pack Compatibility Patch

This is a compatibility overlay for **Seb’s Pack 19** on Radiophobia 3 1.20
with the Radiophobia OGSR engine upgrade. This overlay does **not** include Seb’s Pack. Obtain and install the original
pack yourself. Do not commit or redistribute its weapons, sounds, textures, or meshes with this add-on.

## Helper installer

Double-click `Install.bat` in this folder. It asks for:

1. Your Radiophobia 3 folder (the one with `gamedata` and `bin_x64`)
2. Your extracted Seb’s Pack 19 folder (the one with `gamedata`)

It copies Seb’s Pack into the game, skips `gamedata/shaders`, `gamedata/shaders.xr`,
`bin_x64`, and every script/config the OGSR Radiophobia drop-in already replaced,
applies this overlay, then inserts Seb’s safe modules into the existing
`ogse_signals_addons_list.script` without replacing the rest of the list. If Atmospherics weather is already in the game folder, Seb’s
`config/environment` files and weather controller are not copied. 

## What this overlay restores or merges

- Every script from the OGSR Radiophobia drop-in that Seb also ships:
  `bind_stalker.script` (alt-aim callback stays commented), `blood_pool.script`
  (`callback.on_footstep`, not `on_foot_step`), `game_difficulties.script`,
  `ogse_night_vision.script`, `ogsr_scope_nightvision.script`, `ui_main_menu.script`,
  and the options UI scripts
- Matching drop-in configs Seb would overwrite: `addon_scope.ltx`,
  `default_controls.ltx`, `ui_keybinding.xml`, `ui_mm_opt.xml`,
  `pda.xml` / `pda_16.xml` (upgrade restores Radiophobia’s hidden Contacts tab)
- The installer inserts `rad_qol_moves` and `hoc_backpack_inventory_anim`
  into the existing add-on list instead of replacing the file
- `rad_laser_control` / `zzz_bas_laser_control` / `rad_quick_nade` stay
  commented (`get_laser_on` / `switch_state` are not in this engine)
- Upgrade video options (`ui_mm_opt.xml`, `ui_mm_opt_video_adv.script`,
  upscaler strings) so DLSS/FSR3 quality rows remain
- Upgrade `rspec_*.ltx` presets so Seb does not stomp them
- Gameplay options: upgrade auto-aim zoom, late reload, and lean toggle,
  plus Seb’s backpack-inventory animation checkbox
- If Ledge Grabbing is already installed, the HUD motion section
  `[item_anm_ledge_grabbing]` is restored into `items_anim.ltx` (Seb’s
  backpack HUD entries stay; that file is not skipped wholesale)
- Backpack HUD vs item-use: `ogsr_items_anims` tells the backpack to skip
  its close/restore so eating from inventory cannot leave `only_allow_movekeys` stuck
- Detector HUD is not started or hidden with a clip while inventory is open
  (engine). Toggle it after closing.

Laser gadgets stay off until a later engine rebase. Fakelens still loads; its
alt-aim Lua signal is idle without the removed engine callback.

## Requirements

* [Radiophobia 3 1.20](https://www.moddb.com/mods/radiophobia/downloads/radiophobia-3-ver-120)
* [OGSR-R3 Custom](https://github.com/brodrigz/OGSR-R3-Custom)
* Seb’s Pack 19 (user-owned; not bundled)
