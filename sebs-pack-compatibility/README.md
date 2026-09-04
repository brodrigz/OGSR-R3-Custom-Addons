# Radiophobia Seb’s Pack Compatibility Patch

This is a compatibility overlay for **Seb’s Pack 19** on Radiophobia 3 1.20
with the Radiophobia OGSR engine upgrade. It is not a copy of Seb’s Pack.

Seb’s Pack has no engine edits. Its `xrEngine.exe` matches Radiophobia 3 1.20
Hotfix 8. The pack still overwrites upgrade shaders, the Lua add-on registry,
and every script the OGSR drop-in already patched (`bind_stalker.script`,
`blood_pool.script`, night-vision scripts, options UI). Installing it after the
engine upgrade without this overlay will roll the renderer back, restore
removed callbacks (`on_actor_weapon_alt_aim_switch`, `on_foot_step`), and
re-enable the laser script that crashes existing saves.

This overlay does **not** include Seb’s Pack. Obtain and install the original
pack yourself. Do not commit or redistribute its weapons, sounds, textures, or
meshes with this add-on.

## Helper installer

Double-click `Install.bat` in this folder. It asks for:

1. Your Radiophobia 3 folder (the one with `gamedata` and `bin_x64`)
2. Your extracted Seb’s Pack 19 folder (the one with `gamedata`)

It copies Seb’s Pack into the game, skips `gamedata/shaders`, `gamedata/shaders.xr`,
`bin_x64`, and every script/config the OGSR Radiophobia drop-in already replaced,
applies this overlay, then inserts Seb’s safe modules into the existing
`ogse_signals_addons_list.script` without replacing the rest of the list. If Atmospherics weather is already in the game folder, Seb’s
`config/environment` files and weather controller are not copied. You can also
drop both folders onto `Install.bat`, or run:

```text
Install.bat "D:\Radiophobia 3" "D:\Mods\Sebs Pack 19"
```

PowerShell equivalent:

```text
powershell -ExecutionPolicy Bypass -File Install-SebsPackCompatibility.ps1 -GameDir "D:\Radiophobia 3" -SebsDir "D:\Mods\Sebs Pack 19"
```

Add `-IncludeReShade` if you want Seb’s ReShade files (`dxgi.dll` and presets)
without replacing `xrEngine.exe`. Add `-Force` to skip the confirmation prompt.

Close the game before running it. Extract the pack first if it is still a zip.

## Install order

1. Radiophobia 3 1.20
2. OGSR-R3 Custom engine upgrade
3. Original Seb’s Pack 19 **or** this folder’s `Install.bat` (does steps 3 and 4)
4. This compatibility overlay last, so it wins every overlapping path
   (the helper already applies it)

Optional addons from this repository (Atmospherics compatibility, Ledge
Grabbing) should sit under this overlay. The helper inserts or enables
`ogsr_ledge_grabbing` if that addon’s script is already in the game folder.
If you install Ledge Grabbing later, add that name to
`gamedata/scripts/ogse/ogse_signals_addons_list.script` yourself. Leaving it
enabled without the addon installed will fail module attach on boot.

Back up saves before changing the script stack. Downgrading a save after
writing it with a newer engine/add-on combination is not guaranteed.

## Hide these folders in Seb’s Pack

Leave the rest of Seb’s Pack enabled. Hide or skip:

| Path | Why |
|---|---|
| `gamedata/shaders/` | 3.490 shader dump vs the upgrade renderer (DLSS/FSR3, blur UV, `screen_res`) |
| `gamedata/shaders.xr` | packed dump of the same shaders; a higher-priority overlay cannot delete it |
| `bin_x64/` | redundant Hotfix 8 engine; would hide the upgrade `xrEngine.exe` |
| Drop-in scripts/configs listed below | OGSR already patched these; Seb’s copies restore removed callbacks and old UI |

If those folders were already copied into the game directory, restore the
engine-upgrade shaders and keep the upgrade `xrEngine.exe`. Do not use Seb’s
`xrEngine.exe`.

ReShade (`dxgi.dll` and presets) is optional and separate. Never mix it with
Seb’s engine binaries.

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

Laser gadgets stay off until a later engine rebase. Fakelens still loads; its
alt-aim Lua signal is idle without the removed engine callback.

## Requirements

* [Radiophobia 3 1.20](https://www.moddb.com/mods/radiophobia/downloads/radiophobia-3-ver-120)
* [OGSR-R3 Custom](https://github.com/brodrigz/OGSR-R3-Custom)
* Seb’s Pack 19 (user-owned; not bundled)
