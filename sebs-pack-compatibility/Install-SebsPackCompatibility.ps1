#requires -Version 5.1
<#
.SYNOPSIS
    Installs Seb's Pack 19 into a Radiophobia 3 folder, then applies this
    compatibility overlay. Skips Seb shaders, engine binaries, and every
    script/config the OGSR Radiophobia drop-in already patched.

.PARAMETER GameDir
    Radiophobia 3 install folder (the one that contains gamedata and bin_x64).

.PARAMETER SebsDir
    Extracted Seb's Pack 19 folder (the one that contains gamedata).

.PARAMETER IncludeReShade
    Also copy ReShade (dxgi.dll, ini files, reshade-shaders) from Seb's Pack
    into the game bin_x64 folder. Never copies xrEngine.exe.

.PARAMETER Force
    Skip the confirmation prompt.

.PARAMETER WhatIf
    Show what would be copied without writing files.
#>
[CmdletBinding(SupportsShouldProcess = $true)]
param(
    [string]$GameDir,
    [string]$SebsDir,
    [switch]$IncludeReShade,
    [switch]$Force
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$OverlayRoot = $PSScriptRoot
$OverlayGamedata = Join-Path $OverlayRoot 'gamedata'
$OverlayRegistryRel = 'scripts\ogse\ogse_signals_addons_list.script'

# OGSR Radiophobia drop-in replacements (COMPATIBILITY-FILES.csv). Seb must not
# copy these. The overlay ships the upgrade copies so they also win in MO2.
# Extra scripts-root duplicates are leftover Seb copies of bind\ and ui\ files.
$ForkProtectedRel = @(
    'scripts\bind\bind_stalker.script',
    'scripts\bind_stalker.script',
    'scripts\blood_pool.script',
    'scripts\game_difficulties.script',
    'scripts\hoc_backpack_inventory_anim.script',
    'scripts\ogse\ogse_night_vision.script',
    'scripts\ogse\ogse_signals_addons_list.script',
    'scripts\ogsr\ogsr_items_anims.script',
    'scripts\ogsr_scope_nightvision.script',
    'scripts\ui\ui_main_menu.script',
    'scripts\ui_main_menu.script',
    'scripts\ui\ui_mm_opt_gameplay.script',
    'scripts\ui\ui_mm_opt_main.script',
    'scripts\ui\ui_mm_opt_video.script',
    'scripts\ui\ui_mm_opt_video_adv.script',
    'config\default_controls.ltx',
    'config\ui\pda.xml',
    'config\ui\pda_16.xml',
    'config\ui\ui_keybinding.xml',
    'config\ui\ui_mm_opt.xml',
    'config\weapons\addons\addon_scope.ltx',
    'config\text\eng\ui_st_ogsr_upscaler.xml',
    'config\text\rus\ui_st_ogsr_upscaler.xml'
)

$SebDuplicateRel = @(
    'scripts\bind_stalker.script',
    'scripts\ui_main_menu.script'
)

function Write-Header {
    Write-Host ''
    Write-Host 'Seb''s Pack + OGSR compatibility installer' -ForegroundColor Cyan
    Write-Host 'Copies Seb''s Pack, skips shaders, bin_x64, and OGSR drop-in scripts, then applies this overlay.'
    Write-Host ''
}

function Write-Step {
    param([string]$Message)
    Write-Host ">> $Message" -ForegroundColor Yellow
}

function Write-Ok {
    param([string]$Message)
    Write-Host "   $Message" -ForegroundColor Green
}

function Write-WarnLine {
    param([string]$Message)
    Write-Host "   $Message" -ForegroundColor DarkYellow
}

function Select-Folder {
    param(
        [Parameter(Mandatory)][string]$Description,
        [string]$SelectedPath
    )

    Add-Type -AssemblyName System.Windows.Forms | Out-Null
    $dialog = New-Object System.Windows.Forms.FolderBrowserDialog
    $dialog.Description = $Description
    $dialog.ShowNewFolderButton = $false
    if ($SelectedPath -and (Test-Path -LiteralPath $SelectedPath)) {
        $dialog.SelectedPath = $SelectedPath
    }

    $form = New-Object System.Windows.Forms.Form
    $form.TopMost = $true
    $form.MinimizeBox = $false
    $form.MaximizeBox = $false
    $form.ShowInTaskbar = $false
    $form.FormBorderStyle = [System.Windows.Forms.FormBorderStyle]::FixedToolWindow
    $form.StartPosition = [System.Windows.Forms.FormStartPosition]::CenterScreen
    $form.Size = New-Object System.Drawing.Size(0, 0)
    $form.Show() | Out-Null
    $form.Hide()
    try {
        $result = $dialog.ShowDialog($form)
    }
    finally {
        $form.Dispose()
    }
    if ($result -ne [System.Windows.Forms.DialogResult]::OK) {
        throw 'Folder selection cancelled.'
    }
    return $dialog.SelectedPath
}

function Read-Folder {
    param(
        [Parameter(Mandatory)][string]$Prompt,
        [string]$Default
    )

    if ($Default) {
        $entered = Read-Host "$Prompt [$Default]"
        if ([string]::IsNullOrWhiteSpace($entered)) { return $Default }
        return $entered.Trim().Trim('"')
    }

    $entered = Read-Host $Prompt
    if ([string]::IsNullOrWhiteSpace($entered)) {
        throw 'A folder path is required.'
    }
    return $entered.Trim().Trim('"')
}

function Get-FolderInteractive {
    param(
        [Parameter(Mandatory)][string]$Title,
        [string]$FallbackPrompt,
        [string]$Default
    )

    try {
        return Select-Folder -Description $Title -SelectedPath $Default
    }
    catch {
        Write-WarnLine 'Folder picker unavailable; type the path instead.'
        return Read-Folder -Prompt $FallbackPrompt -Default $Default
    }
}

function Resolve-ExistingPath {
    param([Parameter(Mandatory)][string]$Path)

    if ($Path -match '\.zip$') {
        throw "That path is a zip file. Extract it first, then select the folder: $Path"
    }
    if (-not (Test-Path -LiteralPath $Path)) {
        throw "Folder not found: $Path"
    }
    return (Resolve-Path -LiteralPath $Path).Path
}

function Resolve-GameRoot {
    param([Parameter(Mandatory)][string]$Path)

    $Path = Resolve-ExistingPath $Path
    $leaf = Split-Path $Path -Leaf

    $candidates = [System.Collections.Generic.List[string]]::new()
    [void]$candidates.Add($Path)
    if ($leaf -eq 'gamedata' -or $leaf -eq 'bin_x64') {
        [void]$candidates.Add((Split-Path $Path -Parent))
    }

    foreach ($candidate in $candidates) {
        $exe = Join-Path $candidate 'bin_x64\xrEngine.exe'
        $gamedata = Join-Path $candidate 'gamedata'
        if ((Test-Path -LiteralPath $exe) -and (Test-Path -LiteralPath $gamedata)) {
            return $candidate
        }
    }

    throw @"
That does not look like a Radiophobia 3 install.
Expected both:
  bin_x64\xrEngine.exe
  gamedata\
Selected: $Path
"@
}

function Resolve-SebsRoot {
    param([Parameter(Mandatory)][string]$Path)

    $Path = Resolve-ExistingPath $Path
    $markers = @(
        'gamedata\scripts\rad_qol_moves.script',
        'gamedata\scripts\hoc_backpack_inventory_anim.script'
    )

    $testRoot = {
        param($Root)
        foreach ($marker in $markers) {
            if (Test-Path -LiteralPath (Join-Path $Root $marker)) { return $true }
        }
        return $false
    }

    if (& $testRoot $Path) { return $Path }

    if ((Split-Path $Path -Leaf) -eq 'gamedata') {
        $parent = Split-Path $Path -Parent
        if (& $testRoot $parent) { return $parent }
    }

    $hit = Get-ChildItem -LiteralPath $Path -Recurse -File -Filter 'rad_qol_moves.script' -ErrorAction SilentlyContinue |
        Select-Object -First 1
    if ($hit) {
        # ...\gamedata\scripts\rad_qol_moves.script -> pack root
        $scriptsDir = $hit.DirectoryName
        $gamedataDir = Split-Path $scriptsDir -Parent
        $root = Split-Path $gamedataDir -Parent
        if (& $testRoot $root) { return $root }
    }

    throw @"
That does not look like an extracted Seb's Pack 19 folder.
Expected gamedata\scripts\rad_qol_moves.script (or hoc_backpack_inventory_anim.script).
Selected: $Path
"@
}

function Test-EngineUpgrade {
    param([Parameter(Mandatory)][string]$GameRoot)

    $exe = Get-Item -LiteralPath (Join-Path $GameRoot 'bin_x64\xrEngine.exe')
    $ssr = Join-Path $GameRoot 'gamedata\shaders\r3\ogsr_ssr.ps'
    $upscaler = Join-Path $GameRoot 'gamedata\config\text\eng\ui_st_ogsr_upscaler.xml'

    $exeLooksVanilla = $exe.Length -lt 25MB
    $hasUpgradeShaders = Test-Path -LiteralPath $ssr
    $hasUpscalerUi = Test-Path -LiteralPath $upscaler

    if ($exeLooksVanilla) {
        throw @"
This Radiophobia folder still has the Hotfix 8 / Seb's Pack engine
($($exe.FullName), $([math]::Round($exe.Length / 1MB, 1)) MB).
Install the OGSR-R3 Custom engine upgrade first, then run this installer again.
"@
    }

    if (-not $hasUpgradeShaders) {
        throw @"
Upgrade shaders were not found (missing gamedata\shaders\r3\ogsr_ssr.ps).
If Seb's Pack was already copied over the game, restore the engine-upgrade
shader folder first. This installer will not copy Seb shaders, but it cannot
rebuild shaders that were already overwritten.
"@
    }

    return [pscustomobject]@{
        ExePath          = $exe.FullName
        ExeMegabytes     = [math]::Round($exe.Length / 1MB, 1)
        HasUpgradeShaders = $hasUpgradeShaders
        HasUpscalerUi    = $hasUpscalerUi
    }
}

function Test-GameNotRunning {
    $running = @(Get-Process -Name 'xrEngine' -ErrorAction SilentlyContinue)
    if ($running.Count -gt 0) {
        throw 'Radiophobia is running (xrEngine.exe). Close the game, then run this installer again.'
    }
}

function Invoke-Robo {
    param(
        [Parameter(Mandatory)][string]$Source,
        [Parameter(Mandatory)][string]$Destination,
        [string[]]$ExtraArgs = @()
    )

    if (-not (Test-Path -LiteralPath $Destination)) {
        New-Item -ItemType Directory -Path $Destination | Out-Null
    }

    $roboArgs = @(
        $Source,
        $Destination,
        '/E', '/IS', '/IT',
        '/R:2', '/W:1',
        '/NFL', '/NDL', '/NJH', '/NJS', '/NC', '/NS', '/NP'
    ) + $ExtraArgs

    if ($WhatIfPreference) {
        $roboArgs += '/L'
        Write-WarnLine "WhatIf: robocopy $($roboArgs -join ' ')"
    }

    & robocopy @roboArgs | Out-Null
    $code = $LASTEXITCODE
    # 0-7 are success (copied / extra / mismatch / extra dirs). 8+ is failure.
    if ($code -ge 8) {
        throw "robocopy failed with exit code $code (source: $Source)"
    }
    return $code
}

function Test-AtmosphericsPresent {
    param([Parameter(Mandatory)][string]$GameRoot)

    $envDir = Join-Path $GameRoot 'gamedata\config\environment'
    if (-not (Test-Path -LiteralPath $envDir)) { return $false }

    $hit = Get-ChildItem -LiteralPath $envDir -Recurse -File -Filter '*.ltx' -ErrorAction SilentlyContinue |
        Select-String -Pattern 'moon_full_clear' -SimpleMatch -List |
        Select-Object -First 1
    return [bool]$hit
}

function Write-AtmosphericsSunsWarning {
    param([Parameter(Mandatory)][string]$GameRoot)

    $suns = Join-Path $GameRoot 'gamedata\config\environment\suns.ltx'
    $hasSection = (Test-Path -LiteralPath $suns) -and
        [bool](Select-String -LiteralPath $suns -Pattern '[moon_full_clear]' -SimpleMatch -Quiet)
    if ($hasSection) { return }

    Write-WarnLine 'Atmospherics weather is present, but suns.ltx is missing moon_full_clear.'
    Write-WarnLine 'Re-apply your Atmospherics overlay, then run this installer again. This script will not replace suns.ltx.'
}

function Get-ProtectedFileNames {
    $names = New-Object 'System.Collections.Generic.HashSet[string]' ([StringComparer]::OrdinalIgnoreCase)
    [void]$names.Add('shaders.xr')
    foreach ($rel in $ForkProtectedRel) {
        [void]$names.Add([System.IO.Path]::GetFileName($rel))
    }
    if (Test-Path -LiteralPath $OverlayGamedata) {
        Get-ChildItem -LiteralPath $OverlayGamedata -Recurse -File -ErrorAction SilentlyContinue |
            ForEach-Object { [void]$names.Add($_.Name) }
    }
    return @($names)
}

function Copy-SebsPack {
    param(
        [Parameter(Mandatory)][string]$SebsRoot,
        [Parameter(Mandatory)][string]$GameRoot,
        [bool]$SkipAtmospherics
    )

    $xd = @(
        (Join-Path $SebsRoot 'bin_x64'),
        (Join-Path $SebsRoot 'gamedata\shaders')
    )
    $xf = @(
        (Join-Path $SebsRoot 'gamedata\shaders.xr')
    )
    foreach ($rel in $ForkProtectedRel) {
        $xf += (Join-Path $SebsRoot "gamedata\$rel")
    }

    if ($SkipAtmospherics) {
        $xd += (Join-Path $SebsRoot 'gamedata\config\environment')
        $xf += @(
            (Join-Path $SebsRoot 'gamedata\scripts\dsh\dsh_cop_weather.script'),
            (Join-Path $SebsRoot 'gamedata\config\dsh\weather.ltx'),
            (Join-Path $SebsRoot 'gamedata\config\game_maps_single.ltx'),
            (Join-Path $SebsRoot 'fsgame.ltx')
        )
    }

    $extra = @()
    foreach ($dir in $xd) {
        if (Test-Path -LiteralPath $dir) { $extra += @('/XD', $dir) }
    }
    foreach ($file in $xf) {
        if (Test-Path -LiteralPath $file) { $extra += @('/XF', $file) }
    }
    foreach ($name in Get-ProtectedFileNames) {
        $extra += @('/XF', $name)
    }
    if ($SkipAtmospherics) {
        $extra += @('/XF', 'dsh_cop_weather.script', 'weather.ltx', 'game_maps_single.ltx', 'fsgame.ltx')
    }

    $skipMsg = 'shaders, bin_x64, and OGSR drop-in scripts skipped'
    if ($SkipAtmospherics) {
        $skipMsg = 'shaders, bin_x64, OGSR drop-in scripts, and Atmospherics weather skipped'
    }
    Write-Step "Copying Seb's Pack ($skipMsg). This can take several minutes..."
    Invoke-Robo -Source $SebsRoot -Destination $GameRoot -ExtraArgs $extra | Out-Null
    Write-Ok 'Seb''s Pack files copied.'
}

function Remove-LeftoverSebRenderer {
    param([Parameter(Mandatory)][string]$GameRoot)

    $packed = Join-Path $GameRoot 'gamedata\shaders.xr'
    if (Test-Path -LiteralPath $packed) {
        if ($WhatIfPreference) {
            Write-WarnLine "WhatIf: would remove $packed"
        }
        else {
            Remove-Item -LiteralPath $packed -Force
            Write-Ok 'Removed leftover gamedata\shaders.xr (Seb packed shader dump).'
        }
    }

    foreach ($rel in $SebDuplicateRel) {
        $dup = Join-Path $GameRoot "gamedata\$rel"
        if (Test-Path -LiteralPath $dup) {
            if ($WhatIfPreference) {
                Write-WarnLine "WhatIf: would remove $dup"
            }
            else {
                Remove-Item -LiteralPath $dup -Force
                Write-Ok "Removed leftover gamedata\$rel (Seb duplicate of the upgrade script)."
            }
        }
    }
}

function Copy-CompatibilityOverlay {
    param([Parameter(Mandatory)][string]$GameRoot)

    $dest = Join-Path $GameRoot 'gamedata'
    Write-Step 'Applying compatibility overlay (wins overlapping files)...'
    Invoke-Robo -Source $OverlayGamedata -Destination $dest -ExtraArgs @('/XF', 'ogse_signals_addons_list.script') | Out-Null
    Write-Ok 'Compatibility overlay applied.'
}

function Restore-LedgeGrabbingHud {
    param([Parameter(Mandatory)][string]$GameRoot)

    $ledgeScript = Join-Path $GameRoot 'gamedata\scripts\ogsr_ledge_grabbing.script'
    if (-not (Test-Path -LiteralPath $ledgeScript)) { return }

    $itemsAnim = Join-Path $GameRoot 'gamedata\config\misc\hud_items\items_anim.ltx'
    if (-not (Test-Path -LiteralPath $itemsAnim)) {
        Write-WarnLine 'Ledge Grabbing is installed, but items_anim.ltx was not found.'
        return
    }

    $includeName = 'anm_ledge_grabbing.ltx'
    $file = Read-AddonListFile $itemsAnim
    $text = $file.Text
    if ($text -match '(?m)^\[item_anm_ledge_grabbing\]' -or $text -match '(?i)anm_ledge_grabbing\.ltx') {
        Write-Ok 'Ledge grabbing HUD motion section is already present.'
        return
    }

    if ($WhatIfPreference) {
        Write-WarnLine 'WhatIf: would restore [item_anm_ledge_grabbing] include in items_anim.ltx.'
        return
    }

    $nl = if ($text -match "`r`n") { "`r`n" } else { "`n" }
    $trimmed = $text.TrimEnd()
    $text = $trimmed + $nl + $nl + ";--=============< Ledge grabbing >=============--" + $nl + '#include "' + $includeName + '"' + $nl
    [System.IO.File]::WriteAllText($itemsAnim, $text, $file.Encoding)
    Write-Ok 'Restored ledge grabbing HUD motion (Seb overwrote items_anim.ltx).'
}

function Read-AddonListFile {
    param([Parameter(Mandatory)][string]$Path)

    $bytes = [System.IO.File]::ReadAllBytes($Path)
    $utf8Bom = $bytes.Length -ge 3 -and $bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF
    if ($utf8Bom) {
        return [pscustomobject]@{
            Text     = [System.Text.UTF8Encoding]::new($false).GetString($bytes, 3, $bytes.Length - 3)
            Encoding = [System.Text.UTF8Encoding]::new($true)
        }
    }

    $utf8 = [System.Text.UTF8Encoding]::new($false)
    $asUtf8 = $utf8.GetString($bytes)
    if ($asUtf8 -match 'addons\s*=') {
        return [pscustomobject]@{ Text = $asUtf8; Encoding = $utf8 }
    }

    $ansi = [System.Text.Encoding]::Default
    return [pscustomobject]@{ Text = $ansi.GetString($bytes); Encoding = $ansi }
}

function Test-LuaAddonQuoted {
    param(
        [Parameter(Mandatory)][string]$Text,
        [Parameter(Mandatory)][string]$Name
    )
    return [regex]::IsMatch($Text, '["'']' + [regex]::Escape($Name) + '["'']')
}

function Disable-LuaAddonLine {
    param(
        [Parameter(Mandatory)][string]$Text,
        [Parameter(Mandatory)][string]$Name
    )
    return [regex]::Replace(
        $Text,
        '(?m)^(\s*)(?!--\s*)("' + [regex]::Escape($Name) + '"\s*,?)',
        '$1-- $2'
    )
}

function Enable-LuaAddonLine {
    param(
        [Parameter(Mandatory)][string]$Text,
        [Parameter(Mandatory)][string]$Name
    )
    return [regex]::Replace(
        $Text,
        '(?m)^(\s*)--\s*("' + [regex]::Escape($Name) + '"\s*,?)',
        '$1$2'
    )
}

function Add-LuaAddonLine {
    param(
        [Parameter(Mandatory)][string]$Text,
        [Parameter(Mandatory)][string]$Name,
        [string]$Comment
    )

    $match = [regex]::Match($Text, '(?s)^(?<pre>.*)(?<open>addons\s*=\s*\{)(?<body>.*)(?<close>\r?\n\})(?<post>.*)\z')
    if (-not $match.Success) {
        throw 'Could not find the addons = { ... } table in ogse_signals_addons_list.script.'
    }

    $body = $match.Groups['body'].Value
    if ($body -notmatch '(?s),\s*$') {
        $body = [regex]::Replace($body, '(")\s*$', '$1,')
    }

    $line = "`t`"$Name`","
    if ($Comment) { $line += " -- $Comment" }
    $body = $body.TrimEnd() + [Environment]::NewLine + $line + [Environment]::NewLine

    return $match.Groups['pre'].Value + $match.Groups['open'].Value + $body + $match.Groups['close'].Value + $match.Groups['post'].Value
}

function Update-AddonsRegistry {
    param([Parameter(Mandatory)][string]$GameRoot)

    $registry = Join-Path $GameRoot "gamedata\$OverlayRegistryRel"
    if (-not (Test-Path -LiteralPath $registry)) {
        throw "Add-on list not found: $registry"
    }

    Write-Step 'Merging Seb modules into the existing add-on list...'
    $file = Read-AddonListFile $registry
    $text = $file.Text
    $added = [System.Collections.Generic.List[string]]::new()

    foreach ($disable in @('rad_laser_control', 'zzz_bas_laser_control', 'rad_quick_nade')) {
        $text = Disable-LuaAddonLine -Text $text -Name $disable
    }

    $insert = @(
        @{ Name = 'hoc_backpack_inventory_anim'; Comment = "Seb's Pack" },
        @{ Name = 'rad_qol_moves'; Comment = "Seb's Pack" }
    )
    foreach ($item in $insert) {
        if (Test-LuaAddonQuoted -Text $text -Name $item.Name) {
            $text = Enable-LuaAddonLine -Text $text -Name $item.Name
            continue
        }
        $text = Add-LuaAddonLine -Text $text -Name $item.Name -Comment $item.Comment
        [void]$added.Add($item.Name)
    }

    $ledgeScript = Join-Path $GameRoot 'gamedata\scripts\ogsr_ledge_grabbing.script'
    if (Test-Path -LiteralPath $ledgeScript) {
        if (Test-LuaAddonQuoted -Text $text -Name 'ogsr_ledge_grabbing') {
            $text = Enable-LuaAddonLine -Text $text -Name 'ogsr_ledge_grabbing'
        }
        else {
            $text = Add-LuaAddonLine -Text $text -Name 'ogsr_ledge_grabbing' -Comment 'Ledge Grabbing addon'
            [void]$added.Add('ogsr_ledge_grabbing')
        }
    }

    if ($WhatIfPreference) {
        Write-WarnLine 'WhatIf: would update ogse_signals_addons_list.script in place.'
        return
    }

    [System.IO.File]::WriteAllText($registry, $text, $file.Encoding)
    if ($added.Count -gt 0) {
        Write-Ok ('Added: ' + ($added -join ', '))
    }
    else {
        Write-Ok 'Seb modules were already present in the add-on list.'
    }
}

function Copy-ReShadeOptional {
    param(
        [Parameter(Mandatory)][string]$SebsRoot,
        [Parameter(Mandatory)][string]$GameRoot
    )

    $srcBin = Join-Path $SebsRoot 'bin_x64'
    $dstBin = Join-Path $GameRoot 'bin_x64'
    if (-not (Test-Path -LiteralPath $srcBin)) {
        Write-WarnLine 'Seb''s Pack has no bin_x64 folder; nothing to copy for ReShade.'
        return
    }

    Write-Step 'Copying ReShade files only (not xrEngine.exe)...'
    $names = @(
        'dxgi.dll',
        'ReShade.ini',
        'ReShadePreset.ini'
    )
    foreach ($name in $names) {
        $src = Join-Path $srcBin $name
        if (Test-Path -LiteralPath $src) {
            if ($WhatIfPreference) {
                Write-WarnLine "WhatIf: would copy $name"
            }
            else {
                Copy-Item -LiteralPath $src -Destination (Join-Path $dstBin $name) -Force
            }
        }
    }

    Get-ChildItem -LiteralPath $srcBin -File -Filter '*.ini' -ErrorAction SilentlyContinue |
        Where-Object { $_.Name -notmatch '^(ReShade|ReShadePreset)\.ini$' } |
        ForEach-Object {
            if ($WhatIfPreference) {
                Write-WarnLine "WhatIf: would copy $($_.Name)"
            }
            else {
                Copy-Item -LiteralPath $_.FullName -Destination (Join-Path $dstBin $_.Name) -Force
            }
        }

    $srcShaders = Join-Path $srcBin 'reshade-shaders'
    if (Test-Path -LiteralPath $srcShaders) {
        Invoke-Robo -Source $srcShaders -Destination (Join-Path $dstBin 'reshade-shaders') | Out-Null
    }

    Write-Ok 'ReShade files copied. Leave the upgrade xrEngine.exe in place.'
}

function Confirm-Plan {
    param(
        [Parameter(Mandatory)][string]$GameRoot,
        [Parameter(Mandatory)][string]$SebsRoot,
        [Parameter(Mandatory)]$UpgradeInfo,
        [bool]$CopyReShade,
        [bool]$SkipAtmospherics
    )

    Write-Host ''
    Write-Host 'Plan' -ForegroundColor Cyan
    Write-Host "  Game:     $GameRoot"
    Write-Host "  Engine:   $($UpgradeInfo.ExePath) ($($UpgradeInfo.ExeMegabytes) MB)"
    Write-Host "  Seb pack: $SebsRoot"
    Write-Host "  Overlay:  $OverlayGamedata"
    Write-Host ''
    Write-Host '  Will copy Seb''s Pack into the game folder.'
    Write-Host '  Will skip: shaders, bin_x64, and every script/config the OGSR drop-in already patched.'
    if ($SkipAtmospherics) {
        Write-Host '  Will skip Atmospherics weather (environment, suns, dsh weather).'
    }
    Write-Host '  Will apply this compatibility overlay last.'
    Write-Host '  Will insert Seb modules into the existing add-on list.'
    if ($CopyReShade) {
        Write-Host '  Will also copy ReShade (dxgi.dll / ini / reshade-shaders).'
    }
    else {
        Write-Host '  Will not copy ReShade. Re-run with -IncludeReShade if you want it.'
    }
    Write-Host ''

    if ($Force -or $WhatIfPreference) { return }

    $answer = Read-Host 'Continue? [Y/n]'
    if ($answer -and $answer -notmatch '^(y|yes)$') {
        throw 'Cancelled.'
    }
}

if (-not (Test-Path -LiteralPath (Join-Path $OverlayGamedata $OverlayRegistryRel))) {
    throw "This script must live next to the overlay gamedata folder: $OverlayGamedata"
}

Write-Header
Test-GameNotRunning

if (-not $GameDir) {
    $GameDir = Get-FolderInteractive `
        -Title 'Select your Radiophobia 3 folder (contains gamedata and bin_x64)' `
        -FallbackPrompt 'Radiophobia 3 folder'
}
if (-not $SebsDir) {
    $SebsDir = Get-FolderInteractive `
        -Title 'Select your extracted Seb''s Pack 19 folder (contains gamedata)' `
        -FallbackPrompt 'Seb''s Pack 19 folder'
}

$gameRoot = Resolve-GameRoot $GameDir
$sebsRoot = Resolve-SebsRoot $SebsDir
$upgrade = Test-EngineUpgrade $gameRoot
$skipAtmos = Test-AtmosphericsPresent $gameRoot

if (-not $IncludeReShade -and -not $Force -and -not $WhatIfPreference) {
    $reshadeAnswer = Read-Host 'Copy ReShade from Seb''s Pack into bin_x64? [y/N]'
    if ($reshadeAnswer -match '^(y|yes)$') {
        $IncludeReShade = $true
    }
}

Confirm-Plan -GameRoot $gameRoot -SebsRoot $sebsRoot -UpgradeInfo $upgrade -CopyReShade ([bool]$IncludeReShade) -SkipAtmospherics $skipAtmos

Copy-SebsPack -SebsRoot $sebsRoot -GameRoot $gameRoot -SkipAtmospherics $skipAtmos
Remove-LeftoverSebRenderer -GameRoot $gameRoot
if ($skipAtmos) {
    Write-AtmosphericsSunsWarning -GameRoot $gameRoot
}
Copy-CompatibilityOverlay -GameRoot $gameRoot
Restore-LedgeGrabbingHud -GameRoot $gameRoot
Update-AddonsRegistry -GameRoot $gameRoot

if ($IncludeReShade) {
    Copy-ReShadeOptional -SebsRoot $sebsRoot -GameRoot $gameRoot
}

Write-Host ''
Write-Host 'Done.' -ForegroundColor Green
Write-Host 'Launch Radiophobia with the OGSR engine upgrade exe (bin_x64\xrEngine.exe).'
Write-Host 'Do not replace it with the exe from Seb''s Pack.'
Write-Host ''
