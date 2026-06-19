local DEFAULT_SOURCE_URL = "https://raw.githubusercontent.com/R15ofc/cc-dock/main/cc"
local TEMP_DIR = "/dock/.installer"

local FILES = {
  { source = "dock/dock.lua", target = "/dock/dock.lua" },
  { source = "dock/server.lua", target = "/dock/server.lua" },
  { source = "bin/dock.lua", target = "/bin/dock.lua" },
  { source = "bin/dock-server.lua", target = "/bin/dock-server.lua" },
  { source = "startup/dock.lua", target = "/startup/dock.lua" },
  { source = "startup/dock-server.lua", target = "/startup/dock-server.lua" },
}

local OPTIONAL_ASSETS = {
  { source = "wallpaper-480x360.png", target = "/dock/assets/wallpaper-480x360.png", binary = true },
  { source = "wallpaper-320x216.png", target = "/dock/assets/wallpaper-320x216.png", binary = true },
  { source = "wallpaper-800x480.png", target = "/dock/assets/wallpaper-800x480.png", binary = true },
  { source = "wallpaper.png", target = "/dock/assets/wallpaper.png", binary = true },
}

local START_MARK = "-- DockOS startup hook: begin"
local END_MARK = "-- DockOS startup hook: end"

local ROOT_STARTUP_BLOCK = START_MARK .. "\n" .. [[
if fs.exists("/startup/dock.lua") then
  if shell then
    shell.run("/startup/dock.lua")
  else
    dofile("/startup/dock.lua")
  end
end
]] .. END_MARK .. "\n"

local function parse_args(raw)
  local source_url = DEFAULT_SOURCE_URL
  local asset_url = nil
  local index = 1
  while index <= #raw do
    if raw[index] == "--source" then
      source_url = raw[index + 1] or source_url
      index = index + 2
    elseif raw[index] == "--assets" then
      asset_url = raw[index + 1] or asset_url
      index = index + 2
    else
      index = index + 1
    end
  end
  if not asset_url then
    asset_url = source_url:gsub("/cc/?$", "/assets")
  end
  return source_url, asset_url
end

local function ensure_parent(path)
  local dir = fs.getDir(path)
  if dir and dir ~= "" and not fs.exists(dir) then
    fs.makeDir(dir)
  end
end

local function write_file(path, data, binary)
  ensure_parent(path)
  local handle = fs.open(path, binary and "wb" or "w") or fs.open(path, "w")
  if not handle then
    return nil, "cannot open " .. path
  end
  handle.write(data or "")
  handle.close()
  return true
end

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

local function join_url(base_url, path)
  return tostring(base_url):gsub("/+$", "") .. "/" .. tostring(path):gsub("^/+", "")
end

local function download(url)
  if not http then
    return nil, "HTTP API is disabled"
  end
  local handle, err = http.get(url, { ["Accept"] = "*/*" })
  if not handle then
    return nil, err or "request failed"
  end
  local body = handle.readAll()
  local code = 200
  if handle.getResponseCode then
    code = handle.getResponseCode()
  end
  handle.close()
  if code < 200 or code >= 300 then
    return nil, "HTTP " .. tostring(code)
  end
  return body or ""
end

local function temp_path(target)
  return TEMP_DIR .. "/" .. target:gsub("^/+", "")
end

local function replace_block(existing)
  existing = existing or ""
  local start_pos = existing:find(START_MARK, 1, true)
  if start_pos then
    local end_start, end_finish = existing:find(END_MARK, start_pos, true)
    if end_start then
      return existing:sub(1, start_pos - 1) .. ROOT_STARTUP_BLOCK .. existing:sub(end_finish + 1)
    end
  end
  if existing:find("/startup/dock.lua", 1, true) then
    return existing
  end
  if existing ~= "" and existing:sub(-1) ~= "\n" then
    existing = existing .. "\n"
  end
  return existing .. "\n" .. ROOT_STARTUP_BLOCK
end

local function install_startup()
  if not fs.exists("/startup") then
    fs.makeDir("/startup")
  end
  if fs.exists("/startup.lua") and not fs.exists("/startup.lua.dock.bak") then
    fs.copy("/startup.lua", "/startup.lua.dock.bak")
  end
  return write_file("/startup.lua", replace_block(read_file("/startup.lua") or ""))
end

local function install_files(source_url, asset_url)
  if fs.exists(TEMP_DIR) then
    fs.delete(TEMP_DIR)
  end
  fs.makeDir(TEMP_DIR)

  for index, file in ipairs(FILES) do
    print("DockOS [" .. tostring(index) .. "/" .. tostring(#FILES) .. "] " .. file.source)
    local body, err = download(join_url(source_url, file.source))
    if not body then
      fs.delete(TEMP_DIR)
      return nil, err
    end
    local ok, write_err = write_file(temp_path(file.target), body, file.binary)
    if not ok then
      fs.delete(TEMP_DIR)
      return nil, write_err
    end
  end

  for _, file in ipairs(FILES) do
    if fs.exists(file.target) then
      fs.delete(file.target)
    end
    ensure_parent(file.target)
    fs.move(temp_path(file.target), file.target)
  end

  for _, file in ipairs(OPTIONAL_ASSETS) do
    print("DockOS asset " .. file.source)
    local body = download(join_url(asset_url, file.source))
    if body then
      local ok, write_err = write_file(temp_path(file.target), body, file.binary)
      if not ok then
        fs.delete(TEMP_DIR)
        return nil, write_err
      end
      if fs.exists(file.target) then
        fs.delete(file.target)
      end
      ensure_parent(file.target)
      fs.move(temp_path(file.target), file.target)
    else
      print("Skip optional asset")
    end
  end

  fs.delete(TEMP_DIR)
  return true
end

local function append_shell_path(path)
  if not shell or not shell.path or not shell.setPath then
    return
  end
  local current = shell.path()
  for part in string.gmatch(current, "[^:]+") do
    if part == path then
      return
    end
  end
  shell.setPath(current .. ":" .. path)
end

local source_url, asset_url = parse_args({ ... })

print("DockOS Installer")
print("Source: " .. source_url)
print("Assets: " .. asset_url)

local ok, err = install_files(source_url, asset_url)
if not ok then
  print("ERR Install failed: " .. tostring(err))
  return
end

install_startup()
append_shell_path("/bin")

print("OK DockOS installed")
print("Run: dock")
