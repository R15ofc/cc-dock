# DockOS

Standalone OS shell for CC:Tweaked Advanced Computers.

Current release: **DockOS Kyrenia 1.2.9**.

DockOS release names follow Cyprus locations. Kyrenia is the first named visual release.

DockOS currently targets a `3x6` Tom bitmap-monitor wall (`384x192`) as the primary desktop size.
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
Supported Tom bitmap monitor walls: `2x3`, `2x4`, `3x6`, `4x8`; `1x2` has a compact fallback.

## UI

- Linux-style desktop shell with top panel, left dock, Activities overview, and app grid.
- External-display first: no UI is drawn on the PC terminal.
- Activities opens from the top panel or dock and includes app search, app grid, About, reboot, and shutdown.
- Search lives inside Activities and the Applications window.
- Real PNG wallpaper loading through Tom GPU `decodeImage`/`drawImage`.
- Default Pexels mountain wallpaper assets are installed into `/dock/assets`.
- App icons are generated from Google Material Icons.
- Minimal black boot splash with centered white Dock logo and white loading bar.
- High-resolution Tom GPU renderer with square opaque surfaces and strict Z-order.
- Linux-style app windows with dark header bars, close, minimize, fullscreen, focus, and drag.
- Sharp square app icons in the left dock and bottom shelf, tuned for `3x6`.
- Pinned left-dock apps plus open-app indicators.
- Files app with create folder/file, rename, delete, preview, and open.
- Store has search, popular square app cards, compact app rows, and built-in apps.
- Docs uses a white page workspace, orange File menu, wrapping preview, print, and edit.
- Paint uses a wide white canvas with a compact toolbar.
- Settings uses vertical tabs for General, Theme, Time, Devices, Privacy, and Power.
- Luma has inline search, pinned Luma Web Creator, and a simple page editor.
- App Studio has a code panel, live preview, component buttons, and example projects.

## Apps

- **Files** - desktop file manager.
- **Launchpad** - app launcher.
- **Store** - open built-in apps.
- **Documents** - write documents and print with a connected printer.
- **Paint** - simple pixel paint app.
- **Blend** - blocky 3D modeling and render preview app.
- **Settings** - themes, display rescan, speakers, printers, DirectGPU.
- **Luma** - browser with inline search and Web Creator.
- **App Studio** - build DockOS app prototypes with code and preview.
- **Terminal** - DockOS shell with file/app/power commands.

## Commands

```lua
dock
dock files
dock store
dock luma
dock studio
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
Built-in wallpaper assets include exact sizes for `2x3`, `2x4`, `3x6` (`384x192`), and `4x8` Tom bitmap monitor walls, plus legacy `382x192` and compact `1x2` fallbacks.
The installer downloads only the best matching wallpaper for the detected GPU size to avoid CC disk space errors.
Use a direct raw image URL, not a normal web page URL.

Prepare assets on your computer:

```bash
python3 tools/prepare-wallpaper.py /path/to/photo.jpg --out assets
```

Then push the generated files or install a raw image directly in Minecraft:

```lua
dock wallpaper https://example.com/wallpaper-320x216.png
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
