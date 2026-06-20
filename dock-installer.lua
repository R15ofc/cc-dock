local DEFAULT_SOURCE_URL = "https://raw.githubusercontent.com/R15ofc/cc-dock/a115315538a46fc7e4c92994f3461f7918f0c8a7/cc"
local TEMP_DIR = "/dock/.installer"

local FILES = {
  { source = "dock/dock.lua", target = "/dock/dock.lua" },
  { source = "dock/server.lua", target = "/dock/server.lua" },
  { source = "bin/dock.lua", target = "/bin/dock.lua" },
  { source = "bin/dock-server.lua", target = "/bin/dock-server.lua" },
  { source = "startup/dock.lua", target = "/startup/dock.lua" },
  { source = "startup/dock-server.lua", target = "/startup/dock-server.lua" },
}

local WALLPAPER_ASSETS = {
  { source = "wallpaper-160x144.png", target = "/dock/assets/wallpaper-160x144.png", width = 160, height = 144, binary = true },
  { source = "wallpaper-320x216.png", target = "/dock/assets/wallpaper-320x216.png", width = 320, height = 216, binary = true },
  { source = "wallpaper-382x192.png", target = "/dock/assets/wallpaper-382x192.png", width = 382, height = 192, binary = true },
  { source = "wallpaper-384x192.png", target = "/dock/assets/wallpaper-384x192.png", width = 384, height = 192, binary = true },
  { source = "wallpaper-320x288.png", target = "/dock/assets/wallpaper-320x288.png", width = 320, height = 288, binary = true },
  { source = "wallpaper-480x432.png", target = "/dock/assets/wallpaper-480x432.png", width = 480, height = 432, binary = true },
  { source = "wallpaper-640x576.png", target = "/dock/assets/wallpaper-640x576.png", width = 640, height = 576, binary = true },
}

local OPTIONAL_ASSETS = {
  { source = "brand/dock_boot_logo.png", target = "/dock/assets/brand/dock_boot_logo.png", binary = true },
  { source = "brand/dock_boot_logo_128.png", target = "/dock/assets/brand/dock_boot_logo_128.png", binary = true },
  { source = "brand/dock_boot_logo_220.png", target = "/dock/assets/brand/dock_boot_logo_220.png", binary = true },
  { source = "brand/dock_boot_logo_320.png", target = "/dock/assets/brand/dock_boot_logo_320.png", binary = true },
  { source = "brand/dock_boot_logo_440.png", target = "/dock/assets/brand/dock_boot_logo_440.png", binary = true },
  { source = "brand/dock_logo_white.png", target = "/dock/assets/brand/dock_logo_white.png", binary = true },
  { source = "icons/dock_tile.png", target = "/dock/assets/icons/dock_tile.png", binary = true },
  { source = "icons/folder_tile.png", target = "/dock/assets/icons/folder_tile.png", binary = true },
  { source = "icons/store_tile.png", target = "/dock/assets/icons/store_tile.png", binary = true },
  { source = "icons/docs_tile.png", target = "/dock/assets/icons/docs_tile.png", binary = true },
  { source = "icons/blend_tile.png", target = "/dock/assets/icons/blend_tile.png", binary = true },
  { source = "icons/paint_tile.png", target = "/dock/assets/icons/paint_tile.png", binary = true },
  { source = "icons/settings_tile.png", target = "/dock/assets/icons/settings_tile.png", binary = true },
  { source = "icons/luma_tile.png", target = "/dock/assets/icons/luma_tile.png", binary = true },
  { source = "icons/studio_tile.png", target = "/dock/assets/icons/studio_tile.png", binary = true },
  { source = "icons/terminal_tile.png", target = "/dock/assets/icons/terminal_tile.png", binary = true },
  { source = "icons/messenger_tile.png", target = "/dock/assets/icons/messenger_tile.png", binary = true },
  { source = "icons/info_tile.png", target = "/dock/assets/icons/info_tile.png", binary = true },
  { source = "icons/search_tile.png", target = "/dock/assets/icons/search_tile.png", binary = true },
}
local LEGACY_ASSETS = {
  "/dock/assets/wallpaper-160x144.png",
  "/dock/assets/wallpaper-320x216.png",
  "/dock/assets/wallpaper-320x288.png",
  "/dock/assets/wallpaper-382x192.png",
  "/dock/assets/wallpaper-384x192.png",
  "/dock/assets/wallpaper-480x432.png",
  "/dock/assets/wallpaper-640x576.png",
  "/dock/assets/wallpaper-160x144.jpg",
  "/dock/assets/wallpaper-320x216.jpg",
  "/dock/assets/wallpaper-320x288.jpg",
  "/dock/assets/wallpaper-382x192.jpg",
  "/dock/assets/wallpaper-384x192.jpg",
  "/dock/assets/wallpaper-480x432.jpg",
  "/dock/assets/wallpaper-640x576.jpg",
  "/dock/assets/wallpaper-480x270.jpg",
  "/dock/assets/wallpaper-480x270.png",
  "/dock/assets/wallpaper-480x360.jpg",
  "/dock/assets/wallpaper-480x360.png",
  "/dock/assets/wallpaper-640x360.jpg",
  "/dock/assets/wallpaper-640x360.png",
  "/dock/assets/wallpaper-800x360.jpg",
  "/dock/assets/wallpaper-800x360.png",
  "/dock/assets/wallpaper-800x480.jpg",
  "/dock/assets/wallpaper-800x480.png",
  "/dock/assets/wallpaper-960x540.jpg",
  "/dock/assets/wallpaper-960x540.png",
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

local function download_text(url)
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

local function write_chunk(handle, chunk)
  if chunk == nil then
    return true
  end
  return pcall(function()
    if type(chunk) == "number" then
      handle.write(string.char(chunk))
    elseif type(chunk) == "table" then
      for _, byte in ipairs(chunk) do
        handle.write(string.char(byte))
      end
    else
      handle.write(chunk)
    end
  end)
end

local function download_file(url, target, binary)
  if not http then
    return nil, "HTTP API is disabled"
  end
  local input, err = http.get(url, { ["Accept"] = "*/*" }, binary)
  if not input then
    return nil, err or "request failed"
  end
  local code = 200
  if input.getResponseCode then
    code = input.getResponseCode()
  end
  if code < 200 or code >= 300 then
    input.close()
    return nil, "HTTP " .. tostring(code)
  end
  ensure_parent(target)
  local output = fs.open(target, binary and "wb" or "w") or fs.open(target, "w")
  if not output then
    input.close()
    return nil, "cannot open " .. target
  end
  while true do
    local chunk = input.read(8192)
    if chunk == nil then
      break
    end
    local wrote, write_err = write_chunk(output, chunk)
    if not wrote then
      output.close()
      input.close()
      if fs.exists(target) then
        fs.delete(target)
      end
      return nil, tostring(write_err or "write failed")
    end
  end
  output.close()
  input.close()
  return true
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

local function detect_gpu_size()
  if not peripheral or not peripheral.getNames or not peripheral.wrap then
    return 382, 192
  end
  for _, name in ipairs(peripheral.getNames()) do
    local device = peripheral.wrap(name)
    if device and type(device.getSize) == "function" and (type(device.refreshSize) == "function" or type(device.filledRectangle) == "function" or type(device.drawImage) == "function") then
      pcall(function()
        if device.refreshSize then
          device.refreshSize()
        end
        if device.setSize then
          device.setSize(64)
        end
      end)
      local ok, width, height = pcall(function()
        return device.getSize()
      end)
      if ok and type(width) == "number" and type(height) == "number" and width > 0 and height > 0 then
        return math.floor(width), math.floor(height)
      end
    end
  end
  return 382, 192
end

local function select_wallpaper_asset()
  local width, height = detect_gpu_size()
  for _, file in ipairs(WALLPAPER_ASSETS) do
    if file.width == width and file.height == height then
      return file, width, height
    end
  end
  local selected = WALLPAPER_ASSETS[1]
  for _, file in ipairs(WALLPAPER_ASSETS) do
    if file.width <= width and file.height <= height and file.width * file.height > selected.width * selected.height then
      selected = file
    end
  end
  return selected, width, height
end

local function cleanup_legacy_assets()
  for _, path in ipairs(LEGACY_ASSETS) do
    if fs.exists(path) then
      fs.delete(path)
    end
  end
end

local function install_files(source_url, asset_url)
  cleanup_legacy_assets()
  if fs.exists(TEMP_DIR) then
    fs.delete(TEMP_DIR)
  end
  fs.makeDir(TEMP_DIR)

  for index, file in ipairs(FILES) do
    print("DockOS [" .. tostring(index) .. "/" .. tostring(#FILES) .. "] " .. file.source)
    local ok, err
    if file.binary then
      ok, err = download_file(join_url(source_url, file.source), temp_path(file.target), true)
    else
      local body
      body, err = download_text(join_url(source_url, file.source))
      if body then
        ok, err = write_file(temp_path(file.target), body, false)
      end
    end
    if not ok then
      fs.delete(TEMP_DIR)
      return nil, err
    end
  end

  for _, file in ipairs(FILES) do
    if fs.exists(file.target) then
      fs.delete(file.target)
    end
    ensure_parent(file.target)
    fs.move(temp_path(file.target), file.target)
  end

  cleanup_legacy_assets()

  local wallpaper, detected_width, detected_height = select_wallpaper_asset()
  if wallpaper then
    print("DockOS wallpaper " .. wallpaper.source .. " for " .. tostring(detected_width) .. "x" .. tostring(detected_height))
    local ok, err = download_file(join_url(asset_url, wallpaper.source), temp_path(wallpaper.target), wallpaper.binary)
    if ok then
      ensure_parent(wallpaper.target)
      fs.move(temp_path(wallpaper.target), wallpaper.target)
    else
      print("Skip wallpaper: " .. tostring(err))
    end
  end

  for _, file in ipairs(OPTIONAL_ASSETS) do
    print("DockOS asset " .. file.source)
    local ok, err = download_file(join_url(asset_url, file.source), temp_path(file.target), file.binary)
    if ok then
      if fs.exists(file.target) then
        fs.delete(file.target)
      end
      ensure_parent(file.target)
      fs.move(temp_path(file.target), file.target)
    else
      print("Skip optional asset: " .. tostring(err))
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
  print("Install failed: " .. tostring(err))
  return
end

install_startup()
append_shell_path("/bin")

print("DockOS installed")
print("Run: dock")
