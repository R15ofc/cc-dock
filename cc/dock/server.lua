local VERSION = "0.1.0"
local START_MARK = "-- DockOS server startup: begin"
local END_MARK = "-- DockOS server startup: end"

local CATALOG = {
  {
    id = "luma",
    name = "Luma Browser",
    trust = "verified",
    description = "Browser for Luma pages, search, packages, and HTTP.",
    installer = "https://raw.githubusercontent.com/R15ofc/cc-luma/main/luma-installer.lua",
    source = "https://raw.githubusercontent.com/R15ofc/cc-luma/main/cc",
  },
}

local LUMA_PAGES = {
  ["luma://home"] = {
    title = "Luma Home",
    body = {
      "Welcome to the Luma network.",
      "",
      "This page is served by a CC PC over rednet.",
      "Open luma://packages to see package discovery.",
    },
  },
  ["luma://packages"] = {
    title = "Packages",
    body = {
      "Dock Store provides verified apps.",
      "",
      "Installed now:",
      "  Luma Browser - verified",
      "",
      "RIG remains the developer API and package tooling layer.",
    },
  },
}

local STARTUP_BLOCK = START_MARK .. "\n" .. [[
if fs.exists("/startup/dock-server.lua") then
  if shell then
    shell.run("/startup/dock-server.lua")
  else
    dofile("/startup/dock-server.lua")
  end
end
]] .. END_MARK .. "\n"

local args = { ... }

local function read_file(path)
  if not fs.exists(path) then
    return nil
  end
  local handle = fs.open(path, "r")
  if not handle then
    return nil
  end
  local data = handle.readAll()
  handle.close()
  return data
end

local function write_file(path, data)
  local dir = fs.getDir(path)
  if dir and dir ~= "" and not fs.exists(dir) then
    fs.makeDir(dir)
  end
  local handle = fs.open(path, "w")
  if not handle then
    return nil, "cannot open " .. path
  end
  handle.write(data or "")
  handle.close()
  return true
end

local function replace_block(existing)
  existing = existing or ""
  local start_pos = existing:find(START_MARK, 1, true)
  if start_pos then
    local end_start, end_finish = existing:find(END_MARK, start_pos, true)
    if end_start then
      return existing:sub(1, start_pos - 1) .. STARTUP_BLOCK .. existing:sub(end_finish + 1)
    end
  end
  if existing ~= "" and existing:sub(-1) ~= "\n" then
    existing = existing .. "\n"
  end
  return existing .. "\n" .. STARTUP_BLOCK
end

local function install_startup()
  if not fs.exists("/startup") then
    fs.makeDir("/startup")
  end
  if fs.exists("/startup.lua") and not fs.exists("/startup.lua.dock-server.bak") then
    fs.copy("/startup.lua", "/startup.lua.dock-server.bak")
  end
  local ok, err = write_file("/startup.lua", replace_block(read_file("/startup.lua") or ""))
  if ok then
    print("OK DockOS server startup installed")
  else
    print("ERR " .. tostring(err))
  end
end

local function is_modem(name)
  if peripheral and peripheral.hasType then
    local ok, result = pcall(peripheral.hasType, name, "modem")
    if ok and result then
      return true
    end
  end
  return peripheral and peripheral.getType(name) == "modem"
end

local function open_modems()
  local opened = {}
  if not rednet or not peripheral then
    return opened
  end
  for _, name in ipairs(peripheral.getNames()) do
    if is_modem(name) then
      pcall(rednet.open, name)
      if rednet.isOpen(name) then
        table.insert(opened, name)
      end
    end
  end
  return opened
end

local function serve()
  local opened = open_modems()
  print("DockOS Server " .. VERSION)
  if #opened == 0 then
    print("No rednet modem is open.")
    print("Attach a modem to serve app store over rednet.")
  else
    print("Rednet: " .. table.concat(opened, ", "))
  end
  if rednet and rednet.host then
    pcall(rednet.host, "dock.store", "dock-store")
    pcall(rednet.host, "luma.directory", "luma-directory")
    pcall(rednet.host, "luma.web", "luma-web")
  end
  print("Protocols: dock.store, luma.directory, luma.web")
  print("Press Ctrl+T to stop.")

  while true do
    if not rednet then
      sleep(2)
    else
      local sender, message, protocol = rednet.receive(nil, 5)
      if sender and protocol == "dock.store" then
        rednet.send(sender, {
          ok = true,
          type = "catalog",
          apps = CATALOG,
        }, "dock.store.reply")
      elseif sender and protocol == "luma.directory" then
        rednet.send(sender, {
          ok = true,
          type = "directory",
          sites = {
            { address = "luma://home", title = "Luma Home" },
            { address = "luma://packages", title = "Packages" },
          },
        }, "luma.directory.reply")
      elseif sender and protocol == "luma.web" then
        local address = type(message) == "table" and message.address or "luma://home"
        local page = LUMA_PAGES[address]
        rednet.send(sender, {
          ok = page ~= nil,
          address = address,
          page = page,
        }, "luma.web.reply")
      end
    end
  end
end

if args[1] == "startup" and args[2] == "install" then
  install_startup()
else
  serve()
end
