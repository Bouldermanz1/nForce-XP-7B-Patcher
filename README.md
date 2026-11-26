# nForce-XP-7B-Patcher

An automated batch and PowerShell utility that injects NVIDIA nForce storage drivers (`nvgts.sys`) into an extracted 32-bit Windows XP SP3 installation source to prevent the `0x0000007B` (`INACCESSIBLE_BOOT_DEVICE`) stop error on nForce 700-series motherboards.

> [!NOTE]
> **Project Status (`v0.1.0`):** This is an initial pre-release build targeting NVIDIA nForce 700-series chipsets (`nvgts.sys` from nForce 15.23) on 32-bit Windows XP SP3. File staging, `TXTSETUP.SIF` / `DOSNET.INF` injection, and ISO generation are implemented, and real-hardware boot/install verification on an **EVGA nForce 750i FTW** is currently pending. Feedback and test reports from other nForce 750i/780i/790i boards are welcome!

## What It Does
1. **Extracts Boot Sector (`xpboot.bin`):** Scans a clean source `.iso` in the project root and extracts its 2048-byte El Torito boot sector if `xpboot.bin` is not already present.
2. **Compresses & Stages Text-Mode Driver:** Compresses `nvgts.sys` to `I386\NVGTS.SY_` using `makecab` and copies `nvgts.sys` into `I386\`.
3. **Stages GUI-Mode PnP Drivers (`$OEM$`):** Copies `nvgts.sys` (plus `nvgts.inf`, `nvata.cat`, and optional `nvraid.*` files if supplied) into `working_src\$OEM$\$1\Drivers\nForce\` and generates `I386\WINNT.SIF` with `OemPnPDriversPath="Drivers\nForce"` when `nvgts.inf` is present.
4. **Patches Setup Configs:** Safely inserts required entries under existing sections in `I386\TXTSETUP.SIF` (`[SourceDisksFiles]`, `[HardwareIdsDatabase]`, `[SCSI.Load]`, `[SCSI]`) and `I386\DOSNET.INF` (`[Files]`) without duplicating keys.
5. **Builds Bootable ISO (Optional):** Uses `oscdimg.exe` (if available in `PATH`) with `xpboot.bin` to compile `nForce_700_Series_XP.iso`, or leaves `working_src\` ready for ImgBurn.

## Prerequisites
* A clean **32-bit Windows XP SP3** ISO extracted into a `working_src\` folder inside this directory (and optionally the `.iso` file itself in the root folder for automatic `xpboot.bin` extraction).
* **NVIDIA nForce 15.23 (32-bit Windows XP)** storage driver files extracted from `IDE\WinXP\` into `drivers\`:
  * `drivers\nvgts.sys` (required)
  * `drivers\nvgts.inf` (recommended for GUI-mode PnP setup)
  * `drivers\nvata.cat` (recommended WHQL catalog)
* Optional: `oscdimg.exe` (from the Windows ADK) in your system `PATH`, or **ImgBurn** to build/burn the final disc from `working_src\`.

## Usage
1. Place your extracted Windows XP SP3 files inside `working_src\`.
2. Copy `nvgts.sys`, `nvgts.inf`, and `nvata.cat` into `drivers\`.
3. Right-click `patch.bat` and select **Run as administrator**.
4. Boot the generated `nForce_700_Series_XP.iso` (or build/burn `working_src\` with ImgBurn using `xpboot.bin`).

## Roadmap
* Verify end-to-end installation on **EVGA nForce 750i FTW** hardware.
* Expand support to **nForce 600-series** and additional legacy storage controllers affected by `0x0000007B` on Windows XP.

## Legal Disclaimer
This repository contains only patching scripts and documentation. **No Microsoft Windows files or NVIDIA proprietary driver binaries are included.** Users must supply their own legally obtained Windows XP media and official NVIDIA driver packages.

## License
Licensed under the [MIT License](LICENSE).
