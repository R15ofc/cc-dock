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

- Mac-style desktop.
- External-display first: no UI is drawn on the PC terminal.
- Real PNG wallpaper loading through Tom GPU `decodeImage`/`drawImage`.
- Release boot splash.
- High-resolution Tom GPU renderer with glass menu/dock and rounded windows.
- System menu with About, reboot, shutdown, Files, Settings, Terminal.
- Launchpad app for opening installed apps.
- Bottom dock: pinned apps on the left, `|`, open apps on the right.
- Multiple windows.
- Drag windows by the title bar.
- Fullscreen button on every Dock window.
- Files app with create folder/file, rename, delete, preview, and open.
- Settings app for peripherals: Tom GPU/monitor/keyboard status, speaker, printer.
- Store includes built-in Documents, Paint, and Luma install.

## Apps

- **Files** - Finder-style file manager.
- **Launchpad** - app launcher.
- **Store** - install/open apps.
- **Documents** - write documents and print with a connected printer.
- **Paint** - simple pixel paint app.
- **Settings** - connect/test displays, speakers, printers, DirectGPU.
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
Best match for a `3x5` Tom bitmap monitor is usually `wallpaper-480x360.png`.

Prepare assets on your computer:

```bash
python3 tools/prepare-wallpaper.py /path/to/photo.jpg --out assets
```

Then push the generated files or install a raw image directly in Minecraft:

```lua
dock wallpaper https://example.com/wallpaper-480x360.png
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
