# DockOS

DockOS is the Advanced Computer OS layer for the RIG platform.

It is not a text menu. The main UI is mouse-driven and built for color Advanced PCs:

- Mac-style desktop;
- bottom dock with pinned apps on the left;
- `|` separator with open apps on the right;
- draggable open-app dock order;
- Finder-style Files with folder/file creation, rename, delete, preview, and open.

Repositories:

- RIG core: `R15ofc/cc-rig`
- DockOS: `R15ofc/cc-dock`
- Luma Browser: `R15ofc/cc-luma`

## Install

From a CC:Tweaked computer:

```lua
wget https://raw.githubusercontent.com/R15ofc/cc-dock/main/dock-installer.lua dock-installer.lua
dock-installer.lua
```

Or from RIG:

```lua
rig os install dock
dock
```

## Commands

```lua
dock
dock store
dock store install luma
dock apps
```

Dock uses `/rig/devapi/*` automatically when RIG is installed.

## CC Server PC

Use this on a dedicated CC PC with a modem to serve Dock Store and basic Luma pages over rednet:

```lua
wget https://raw.githubusercontent.com/R15ofc/cc-dock/main/dock-installer.lua dock-installer.lua
dock-installer.lua --source https://raw.githubusercontent.com/R15ofc/cc-dock/main/cc
dock-server startup install
dock-server
```

The startup hook runs `/startup/dock-server.lua` after reboot.
