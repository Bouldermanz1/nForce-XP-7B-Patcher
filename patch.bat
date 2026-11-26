@echo off
setlocal
title nForce-XP-7B-Patcher (v0.1.0)

set "WORKING_DIR=%~dp0"
set "SRC_DIR=%WORKING_DIR%working_src"
set "DRIVERS_DIR=%WORKING_DIR%drivers"
set "DRIVER_SYS=%DRIVERS_DIR%\nvgts.sys"
set "DRIVER_INF=%DRIVERS_DIR%\nvgts.inf"
set "DRIVER_CAT=%DRIVERS_DIR%\nvata.cat"
set "I386_DIR=%SRC_DIR%\I386"
set "OEM_DRV_DIR=%SRC_DIR%\$OEM$\$1\Drivers\nForce"
set "WINNT_SIF=%I386_DIR%\WINNT.SIF"
set "TXTSETUP=%I386_DIR%\TXTSETUP.SIF"
set "DOSNET=%I386_DIR%\DOSNET.INF"
set "BOOT_BIN=%WORKING_DIR%xpboot.bin"
set "SOURCE_ISO=%WORKING_DIR%XP_SP3_CLEAN.iso"

echo ===================================================
echo   nForce-XP-7B-Patcher Engine (v0.1.0)
echo ===================================================

if not exist "%SRC_DIR%\" (
    echo [ERROR] "working_src" folder not found. Extract your clean XP SP3 ISO there first.
    pause & exit /b 1
)
if not exist "%DRIVER_SYS%" (
    echo [ERROR] Driver not found at drivers\nvgts.sys.
    pause & exit /b 1
)
if not exist "%TXTSETUP%" (
    echo [ERROR] TXTSETUP.SIF not found in %I386_DIR%.
    pause & exit /b 1
)
if not exist "%DOSNET%" (
    echo [ERROR] DOSNET.INF not found in %I386_DIR%.
    pause & exit /b 1
)

:: Auto-detect a single clean source ISO in the root folder if XP_SP3_CLEAN.iso is not present
if not exist "%SOURCE_ISO%" (
    set "ISO_COUNT=0"
    for %%F in ("%WORKING_DIR%*.iso") do (
        if /I not "%%~nxF"=="nForce_700_Series_XP.iso" (
            set /a ISO_COUNT+=1
            set "SOURCE_ISO=%%~fF"
        )
    )
    if not "%ISO_COUNT%"=="1" set "SOURCE_ISO="
)

:: Extract 2048-byte El Torito boot sector (handles single and multi-entry boot catalogs)
if not exist "%BOOT_BIN%" (
    if defined SOURCE_ISO (
        if exist "%SOURCE_ISO%" (
            echo [BOOT] Extracting 2048-byte El Torito boot sector from source ISO...
            set "PS_ISO=%SOURCE_ISO%"
            set "PS_BOOT=%BOOT_BIN%"
            powershell -NoProfile -ExecutionPolicy Bypass -Command ^
              "$iso = $env:PS_ISO; $out = $env:PS_BOOT;" ^
              "$fs = [System.IO.File]::OpenRead($iso);" ^
              "try {" ^
              "  $br = New-Object System.IO.BinaryReader($fs);" ^
              "  $bootCatSec = $null;" ^
              "  for ($sec = 16; $sec -lt 32; $sec++) {" ^
              "    $fs.Position = $sec * 2048;" ^
              "    $vd = $br.ReadBytes(2048);" ^
              "    if ($vd.Length -lt 2048) { break }" ^
              "    $type = $vd[0];" ^
              "    $ident = [System.Text.Encoding]::ASCII.GetString($vd, 1, 5);" ^
              "    if ($type -eq 255) { break }" ^
              "    if ($type -eq 0 -and $ident -eq 'CD001') {" ^
              "      $sysId = [System.Text.Encoding]::ASCII.GetString($vd, 7, 32).Trim([char]0, ' ');" ^
              "      if ($sysId -like 'EL TORITO SPECIFICATION*') {" ^
              "        $bootCatSec = [BitConverter]::ToUInt32($vd, 0x47);" ^
              "        break;" ^
              "      }" ^
              "    }" ^
              "  }" ^
              "  if ($null -eq $bootCatSec) { throw 'El Torito Boot Record Volume Descriptor not found.' }" ^
              "  $fs.Position = $bootCatSec * 2048;" ^
              "  $cat = $br.ReadBytes(2048);" ^
              "  if ($cat[0] -ne 1 -or $cat[0x1E] -ne 0x55 -or $cat[0x1F] -ne 0xAA) { throw 'Invalid El Torito Validation Entry.' }" ^
              "  $bootSec = $null;" ^
              "  for ($off = 0x20; $off -le 0x7E0; $off += 0x20) {" ^
              "    $ind = $cat[$off];" ^
              "    if ($ind -eq 0x88) {" ^
              "      $bootSec = [BitConverter]::ToUInt32($cat, $off + 0x08);" ^
              "      break;" ^
              "    }" ^
              "  }" ^
              "  if ($null -eq $bootSec) { throw 'No bootable El Torito entry found in catalog.' }" ^
              "  $fs.Position = $bootSec * 2048;" ^
              "  $seg = $br.ReadBytes(2048);" ^
              "  if ($seg.Length -ne 2048) { throw 'Boot sector truncated.' }" ^
              "  [System.IO.File]::WriteAllBytes($out, $seg);" ^
              "  Write-Host '  Extracted 2048-byte boot sector to xpboot.bin';" ^
              "} finally { $fs.Dispose() }"
            if errorlevel 1 (
                echo [WARN] Could not extract boot sector automatically. Extract xpboot.bin via ImgBurn if needed.
            )
        )
    )
)

echo [1/5] Compressing nvgts.sys into NVGTS.SY_...
if exist "%I386_DIR%\NVGTS.SY_" del /F /Q "%I386_DIR%\NVGTS.SY_"
makecab /D CompressionType=LZX /D CompressionMemory=21 "%DRIVER_SYS%" "%I386_DIR%\NVGTS.SY_" >nul
if not exist "%I386_DIR%\NVGTS.SY_" (
    echo [ERROR] Failed to produce NVGTS.SY_.
    pause & exit /b 1
)

echo [2/5] Copying raw driver to I386...
copy /Y "%DRIVER_SYS%" "%I386_DIR%\nvgts.sys" >nul
if errorlevel 1 (
    echo [ERROR] Failed to copy nvgts.sys to I386.
    pause & exit /b 1
)

echo [3/5] Staging GUI-mode / PnP driver files ($OEM$\$1\Drivers\nForce)...
if not exist "%OEM_DRV_DIR%\" mkdir "%OEM_DRV_DIR%"
copy /Y "%DRIVER_SYS%" "%OEM_DRV_DIR%\nvgts.sys" >nul
if exist "%DRIVER_INF%" copy /Y "%DRIVER_INF%" "%OEM_DRV_DIR%\nvgts.inf" >nul
if exist "%DRIVER_CAT%" copy /Y "%DRIVER_CAT%" "%OEM_DRV_DIR%\nvata.cat" >nul
if exist "%DRIVERS_DIR%\nvraid.sys" copy /Y "%DRIVERS_DIR%\nvraid.sys" "%OEM_DRV_DIR%\nvraid.sys" >nul
if exist "%DRIVERS_DIR%\nvraid.inf" copy /Y "%DRIVERS_DIR%\nvraid.inf" "%OEM_DRV_DIR%\nvraid.inf" >nul

if exist "%DRIVER_INF%" (
    if not exist "%WINNT_SIF%" (
        (
            echo [Data]
            echo AutoPartition=0
            echo MsDosInitiated="0"
            echo UnattendedInstall="Yes"
            echo.
            echo [Unattended]
            echo UnattendMode=ProvideDefault
            echo OemPreinstall=Yes
            echo OemPnPDriversPath="Drivers\nForce"
            echo DriverSigningPolicy=Ignore
        ) > "%WINNT_SIF%"
        echo   Created WINNT.SIF with OemPnPDriversPath="Drivers\nForce"
    ) else (
        echo   Existing WINNT.SIF detected; ensure OemPreinstall=Yes and OemPnPDriversPath="Drivers\nForce" are set.
    )
) else (
    echo   [NOTE] drivers\nvgts.inf not found; staged nvgts.sys only. Add nvgts.inf + nvata.cat for full GUI PnP signing.
)

echo [4/5] Updating TXTSETUP.SIF and DOSNET.INF under existing sections...
set "PS_SIF=%TXTSETUP%"
set "PS_INF=%DOSNET%"
powershell -NoProfile -ExecutionPolicy Bypass -Command ^
  "$sif = $env:PS_SIF; $inf = $env:PS_INF;" ^
  "function Add-UniqueLinesUnderSection($path, $section, [string[]]$lines) {" ^
  "  $content = [System.Collections.Generic.List[string]][string[]](Get-Content -LiteralPath $path);" ^
  "  $secIdx = -1;" ^
  "  for ($i = 0; $i -lt $content.Count; $i++) {" ^
  "    if ($content[$i].Trim() -ieq $section) { $secIdx = $i; break }" ^
  "  }" ^
  "  if ($secIdx -lt 0) { Write-Warning \"Section $section not found in $path\"; return }" ^
  "  $existingKeys = @{};" ^
  "  foreach ($line in $content) {" ^
  "    $k = (($line -split '=')[0]).Trim().ToUpperInvariant();" ^
  "    if ($k) { $existingKeys[$k] = $true }" ^
  "  }" ^
  "  $insertAt = $secIdx + 1;" ^
  "  $addedCount = 0;" ^
  "  foreach ($line in $lines) {" ^
  "    $k = (($line -split '=')[0]).Trim().ToUpperInvariant();" ^
  "    if (-not $existingKeys.ContainsKey($k)) {" ^
  "      $content.Insert($insertAt, $line);" ^
  "      $existingKeys[$k] = $true;" ^
  "      $insertAt++;" ^
  "      $addedCount++;" ^
  "    }" ^
  "  }" ^
  "  if ($addedCount -gt 0) {" ^
  "    [System.IO.File]::WriteAllLines($path, $content, [System.Text.Encoding]::ASCII);" ^
  "    Write-Host \"  Added $addedCount entry/entries under $section in $(Split-Path $path -Leaf)\";" ^
  "  } else {" ^
  "    Write-Host \"  No new entries needed under $section in $(Split-Path $path -Leaf)\";" ^
  "  }" ^
  "};" ^
  "$hwIds = @(" ^
  "  'PCI\VEN_10DE&DEV_0266 = \"nvgts\"'," ^
  "  'PCI\VEN_10DE&DEV_0267 = \"nvgts\"'," ^
  "  'PCI\VEN_10DE&DEV_037E = \"nvgts\"'," ^
  "  'PCI\VEN_10DE&DEV_037F = \"nvgts\"'," ^
  "  'PCI\VEN_10DE&DEV_036F = \"nvgts\"'," ^
  "  'PCI\VEN_10DE&DEV_07F4 = \"nvgts\"'," ^
  "  'PCI\VEN_10DE&DEV_07F5 = \"nvgts\"'," ^
  "  'PCI\VEN_10DE&DEV_07F6 = \"nvgts\"'," ^
  "  'PCI\VEN_10DE&DEV_07F7 = \"nvgts\"'," ^
  "  'PCI\VEN_10DE&DEV_0768 = \"nvgts\"'," ^
  "  'PCI\VEN_10DE&DEV_0AD4 = \"nvgts\"'," ^
  "  'PCI\VEN_10DE&DEV_0AD5 = \"nvgts\"'" ^
  ");" ^
  "Add-UniqueLinesUnderSection $sif '[SourceDisksFiles]' @('nvgts.sys = 1,,,,,,3_,4,1,,,1,4');" ^
  "Add-UniqueLinesUnderSection $sif '[HardwareIdsDatabase]' $hwIds;" ^
  "Add-UniqueLinesUnderSection $sif '[SCSI.Load]' @('nvgts = nvgts.sys,4');" ^
  "Add-UniqueLinesUnderSection $sif '[SCSI]' @('nvgts = \"NVIDIA nForce Storage Controller\"');" ^
  "Add-UniqueLinesUnderSection $inf '[Files]' @('d1,nvgts.sys');"
if errorlevel 1 (
    echo [ERROR] Failed while updating INF/SIF files.
    pause & exit /b 1
)

echo [5/5] Compiling final bootable ISO image...
where oscdimg.exe >nul 2>nul
if %errorlevel% equ 0 (
    if exist "%BOOT_BIN%" (
        oscdimg.exe -b"%BOOT_BIN%" -n -m -o "%SRC_DIR%" "%WORKING_DIR%nForce_700_Series_XP.iso"
        if errorlevel 1 (
            echo [ERROR] oscdimg failed to build ISO.
            pause & exit /b 1
        )
        echo [SUCCESS] ISO generated at: %WORKING_DIR%nForce_700_Series_XP.iso
    ) else (
        echo [NOTICE] oscdimg.exe found, but xpboot.bin is missing and no source ISO was provided.
        echo          Place your clean XP SP3 ISO in the script folder or use ImgBurn on "working_src".
    )
) else (
    echo [NOTICE] oscdimg.exe not found in PATH. Use ImgBurn with "working_src" to build a bootable disc.
)

pause
exit /b 0
