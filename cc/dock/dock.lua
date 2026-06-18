local VERSION = "0.1.0"
local LUMA_INSTALLER_URL = "https://raw.githubusercontent.com/R15ofc/cc-luma/main/luma-installer.lua"
local LUMA_SOURCE_URL = "https://raw.githubusercontent.com/R15ofc/cc-luma/main/cc"

local args = { ... }

local function ensure_parent(path)
  local dir = fs.getDir(path)
  if dir and dir ~= "" and not fs.exists(dir) then
    fs.makeDir(dir)
  end
end

local function write_file(path, data)
  ensure_parent(path)
  local handle = fs.open(path, "w")
  if not handle then
    return nil, "cannot open " .. path
  end
  handle.write(data or "")
  handle.close()
  return true
end

local function download(url)
  if not http then
    return nil, "HTTP API is disabled"
  end
  local handle, err = http.get(url, { ["Accept"] = "text/plain" })
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

local function print_home()
  print("DockOS " .. VERSION)
  print("")
  print("Commands:")
  print("  dock home")
  print("  dock store")
  print("  dock store install luma")
  print("  dock apps")
  print("  dock run luma")
end

local function print_store()
  print("Dock App Store")
  print("")
  print("verified  luma  Luma Browser")
  print("")
  print("Install: dock store install luma")
end

local function install_luma()
  print("Dock App Store")
  print("Installing verified app: Luma Browser")
  local body, err = download(LUMA_INSTALLER_URL)
  if not body then
    print("ERR Download failed: " .. tostring(err))
    return
  end
  local installer_path = "/tmp/luma-installer.lua"
  local ok, write_err = write_file(installer_path, body)
  if not ok then
    print("ERR " .. tostring(write_err))
    return
  end
  if shell then
    shell.run(installer_path, "--source", LUMA_SOURCE_URL)
  else
    dofile(installer_path)
  end
end

local function print_apps()
  print("Dock Apps")
  if fs.exists("/luma/luma.lua") then
    print("  luma")
  else
    print("  No apps installed.")
  end
end

local function run_app(name)
  if name == "luma" then
    if shell then
      shell.run("/bin/luma.lua")
    else
      dofile("/luma/luma.lua")
    end
    return
  end
  print("ERR Unknown app: " .. tostring(name))
end

local command = args[1] or "home"

if command == "home" then
  print_home()
elseif command == "store" and args[2] == "install" and args[3] == "luma" then
  install_luma()
elseif command == "store" then
  print_store()
elseif command == "apps" then
  print_apps()
elseif command == "run" then
  run_app(args[2])
elseif command == "version" then
  print(VERSION)
else
  print("ERR Unknown Dock command")
  print_home()
end

