# DockOS

Standalone OS shell for CC:Tweaked Advanced Computers.

## Install

Run one command on a CC:Tweaked Advanced Computer:

```lua
wget run https://raw.githubusercontent.com/R15ofc/cc-dock/main/dock-installer.lua
```

Then:

```lua
dock
```

## UI

- Mac-style desktop.
- Bottom dock: pinned apps on the left, `|`, open apps on the right.
- Multiple windows.
- Drag windows by the title bar.
- Fullscreen button on every Dock window.
- Files app with create folder/file, rename, delete, preview, and open.
- Settings app for peripherals: DirectGPU, monitor, speaker, printer.
- Store includes built-in Documents, Paint, and Luma install.

## Apps

- **Files** - Finder-style file manager.
- **Store** - install/open apps.
- **Documents** - write documents and print with a connected printer.
- **Paint** - simple pixel paint app.
- **Settings** - connect/test displays, speakers, printers, DirectGPU.
- **Luma** - external browser app, installable from Store.
- **Terminal** - normal CC shell.

## Commands

```lua
dock
dock files
dock store
dock store install luma
dock apps
```

## CC Server PC

Use this only if you want a dedicated rednet Store/Luma server:

```lua
wget run https://raw.githubusercontent.com/R15ofc/cc-dock/main/dock-installer.lua
dock-server startup install
dock-server
```
