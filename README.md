# DockOS

DockOS is the CC:Tweaked OS layer for the RIG platform.

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
```

## Commands

```lua
dock
dock store
dock store install luma
dock apps
```

## CC Server PC

Use this on a dedicated CC PC with a modem to serve Dock Store and basic Luma pages over rednet:

```lua
wget https://raw.githubusercontent.com/R15ofc/cc-dock/main/dock-installer.lua dock-installer.lua
dock-installer.lua --source https://raw.githubusercontent.com/R15ofc/cc-dock/main/cc
dock-server startup install
dock-server
```

The startup hook runs `/startup/dock-server.lua` after reboot.
