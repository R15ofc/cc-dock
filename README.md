# DockOS

Standalone OS shell for CC:Tweaked Advanced Computers.

DockOS renders on an external Tom's Peripherals GPU/Bitmap Monitor setup.
The computer's own terminal is intentionally kept blank while the OS is running.

## Install

Run one command on a CC:Tweaked Advanced Computer:

```lua
wget run https://raw.githubusercontent.com/R15ofc/cc-dock/main/dock-installer.lua
```

Then:

```lua
dock
```

DockOS continuously scans for:

- Tom's Peripherals GPU.
- Tom's Peripherals keyboard.
- Tom's Peripherals bitmap monitor / monitor.

If the hardware is connected after boot, DockOS picks it up automatically.
Recommended screen size for the current UI is at least a `3x5` Tom bitmap monitor wall.

## UI

- Windows-style desktop shell with a full-width bottom taskbar.
- External-display first: no UI is drawn on the PC terminal.
- Start menu opens from the taskbar and includes Apps, Files, Store, Terminal, Settings, About, reboot, and shutdown.
- Search box on the taskbar opens app search.
- Real JPEG/PNG wallpaper loading through Tom GPU `decodeImage`/`drawImage`.
- Default Pexels mountain wallpaper assets are installed into `/dock/assets`.
- App icons are generated from Google Material Icons.
- Minimal black boot splash with centered white Dock logo and white loading bar.
- High-resolution Tom GPU renderer with square opaque surfaces and strict Z-order.
- Square app windows with colored title bars, close, fullscreen, focus, and drag.
- Pinned taskbar apps plus open-app indicators.
- Files app with create folder/file, rename, delete, preview, and open.
- Store has search, popular square app cards, and compact app rows.
- Docs uses a white page workspace, orange File menu, wrapping preview, print, and edit.
- Paint uses a wide white canvas with a compact toolbar.
- Settings uses vertical tabs for General, Theme, Devices, Privacy & Security, and Power.

## Apps

- **Files** - desktop file manager.
- **Launchpad** - app launcher.
- **Store** - install/open apps.
- **Documents** - write documents and print with a connected printer.
- **Paint** - simple pixel paint app.
- **Settings** - themes, display rescan, speakers, printers, DirectGPU.
- **Luma** - browser shell, installable from Store.
- **Terminal** - DockOS shell with file/app/power commands.

## Commands

```lua
dock
dock files
dock store
dock store install luma
dock apps
dock doctor
dock doctor 3d
dock wallpaper <raw_png_or_jpg_url>
```

Terminal commands inside DockOS:

```lua
help
apps
open files
ls /
cd /dock
cat /startup.lua
mkdir /work
touch /work/readme.txt
rm /work/readme.txt
reboot
shutdown
```

## Wallpaper Assets

DockOS loads real image files from `/dock/assets`, not a Lua-drawn fake wallpaper.
Best match for a `3x5` Tom bitmap monitor is usually `wallpaper-480x360.jpg`.
Use a direct raw image URL, not a normal web page URL.

Prepare assets on your computer:

```bash
python3 tools/prepare-wallpaper.py /path/to/photo.jpg --out assets
```

Then push the generated files or install a raw image directly in Minecraft:

```lua
dock wallpaper https://example.com/wallpaper-480x360.jpg
```

`dock doctor` keeps output on the computer terminal and prints attached peripherals,
then sends a visible test pattern to the Tom GPU.
For Tom bitmap monitors, `Monitor peripheral: none` is normal: the screen is
controlled through the Tom GPU and confirmed by the reported pixel size.

## CC Server PC

Use this only if you want a dedicated rednet Store/Luma server:

```lua
wget run https://raw.githubusercontent.com/R15ofc/cc-dock/main/dock-installer.lua
dock-server startup install
dock-server
```
