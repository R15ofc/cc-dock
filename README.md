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

## UI

- Mac-style desktop.
- External-display first: no UI is drawn on the PC terminal.
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
