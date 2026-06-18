local VERSION = "0.2.0"
local LUMA_INSTALLER_URL = "https://raw.githubusercontent.com/R15ofc/cc-luma/main/luma-installer.lua"
local LUMA_SOURCE_URL = "https://raw.githubusercontent.com/R15ofc/cc-luma/main/cc"
local STORE_PROTOCOL = "dock.store"
local STORE_REPLY_PROTOCOL = "dock.store.reply"

local args = { ... }

local APPS = {
  { id = "store", name = "Store", icon = "[]", kind = "system" },
  { id = "luma", name = "Luma", icon = "LM", kind = "app" },
  { id = "shell", name = "Shell", icon = ">_", kind = "system" },
  { id = "files", name = "Files", icon = "{}", kind = "system" },
}

local BUILTIN_CATALOG = {
  {
    id = "luma",
    name = "Luma Browser",
    trust = "verified",
    description = "Browser for Luma pages, search, packages, and HTTP.",
    installer = LUMA_INSTALLER_URL,
    source = LUMA_SOURCE_URL,
  },
}

local function can_color()
  return term and term.isColor and term.isColor()
end

local function set_fg(color)
  if can_color() then
    term.setTextColor(color)
  end
end

local function set_bg(color)
  if can_color() then
    term.setBackgroundColor(color)
  end
end

local function reset_colors()
  if can_color() then
    term.setTextColor(colors.white)
    term.setBackgroundColor(colors.black)
  end
end

local function clear()
  reset_colors()
  term.clear()
  term.setCursorPos(1, 1)
end

local function size()
  local width, height = term.getSize()
  return width or 51, height or 19
end

local function fit(text, width)
  text = tostring(text or "")
  if #text <= width then
    return text
  end
  if width <= 1 then
    return text:sub(1, width)
  end
  return text:sub(1, width - 1) .. "."
end

local function write_at(x, y, text, fg, bg)
  if fg then
    set_fg(fg)
  end
  if bg then
    set_bg(bg)
  end
  term.setCursorPos(x, y)
  term.write(text)
  reset_colors()
end

local function draw_bar(title)
  local width = size()
  set_bg(colors.gray)
  set_fg(colors.white)
  term.setCursorPos(1, 1)
  term.clearLine()
  term.write(fit(" DockOS  " .. title, width))
  reset_colors()
end

local function draw_status(text)
  local width, height = size()
  set_bg(colors.gray)
  set_fg(colors.lightGray)
  term.setCursorPos(1, height)
  term.clearLine()
  term.write(fit(text, width))
  reset_colors()
end

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

local function is_modem(name)
  if peripheral and peripheral.hasType then
    local ok, result = pcall(peripheral.hasType, name, "modem")
    if ok and result then
      return true
    end
  end
  return peripheral and peripheral.getType(name) == "modem"
end

local function open_rednet()
  if not rednet or not peripheral then
    return false
  end
  local opened = false
  for _, name in ipairs(peripheral.getNames()) do
    if is_modem(name) then
      pcall(rednet.open, name)
      opened = opened or rednet.isOpen(name)
    end
  end
  return opened
end

local function fetch_catalog()
  if not open_rednet() then
    return BUILTIN_CATALOG, "offline catalog"
  end
  rednet.broadcast({ type = "catalog" }, STORE_PROTOCOL)
  local _, message = rednet.receive(STORE_REPLY_PROTOCOL, 1.5)
  if type(message) == "table" and message.ok and type(message.apps) == "table" then
    return message.apps, "server catalog"
  end
  return BUILTIN_CATALOG, "offline catalog"
end

local function luma_installed()
  return fs.exists("/luma/luma.lua")
end

local function run_luma()
  if not luma_installed() then
    return false, "Luma is not installed"
  end
  if shell then
    shell.run("/bin/luma.lua")
  else
    dofile("/luma/luma.lua")
  end
  return true
end

local function app_installed(app)
  if app.id == "luma" then
    return luma_installed()
  end
  return fs.exists("/dock/apps/" .. tostring(app.id) .. ".lua")
end

local function run_app(app)
  if app.id == "luma" then
    return run_luma()
  end
  if app.command and shell then
    shell.run(app.command)
    return true
  end
  return false, "App cannot be opened"
end

local function install_app(app)
  clear()
  draw_bar("Store")
  write_at(2, 3, "Installing verified app", colors.white)
  write_at(2, 5, app.name or app.id, colors.cyan)
  draw_status("Downloading package...")

  if app.trust ~= "verified" then
    write_at(2, 7, "Warning: this package is not verified.", colors.orange)
    write_at(2, 8, "Press enter to continue or q to cancel.", colors.lightGray)
    local _, key = os.pullEvent("key")
    if key == keys.q then
      draw_status("Cancelled.")
      sleep(0.5)
      return
    end
  end

  local body, err = download(app.installer)
  if not body then
    draw_status("Failed: " .. tostring(err))
    os.pullEvent("key")
    return
  end

  local installer_path = "/tmp/" .. tostring(app.id) .. "-installer.lua"
  local ok, write_err = write_file(installer_path, body)
  if not ok then
    draw_status("Failed: " .. tostring(write_err))
    os.pullEvent("key")
    return
  end

  draw_status("Applying files...")
  if shell then
    if app.source then
      shell.run(installer_path, "--source", app.source)
    else
      shell.run(installer_path)
    end
  else
    dofile(installer_path)
  end
  draw_status("Done. Press any key.")
  os.pullEvent("key")
end

local function open_shell()
  if shell then
    shell.run("shell")
  end
end

local function draw_home(selected)
  clear()
  draw_bar("Home")
  local width = size()
  local columns = width >= 42 and 3 or 2
  local cell_width = math.floor(width / columns)
  local start_y = 3

  for index, app in ipairs(APPS) do
    local column = ((index - 1) % columns)
    local row = math.floor((index - 1) / columns)
    local x = column * cell_width + 2
    local y = start_y + row * 4
    local selected_app = index == selected
    local bg = selected_app and colors.blue or colors.black
    local fg = selected_app and colors.white or colors.lightGray
    write_at(x, y, "+" .. string.rep("-", math.max(8, cell_width - 4)) .. "+", fg, bg)
    write_at(x, y + 1, "| " .. app.icon .. " " .. fit(app.name, math.max(4, cell_width - 8)), fg, bg)
    write_at(x, y + 2, "+" .. string.rep("-", math.max(8, cell_width - 4)) .. "+", fg, bg)
  end

  draw_status("arrows: select  enter: open  q: quit")
end

local function draw_store(selected, catalog, source)
  clear()
  draw_bar("App Store")
  write_at(2, 3, "Catalog: " .. tostring(source), colors.white)
  local width, height = size()
  local top = 5
  for index, app in ipairs(catalog) do
    if top + 2 >= height then
      break
    end
    local marker = selected == index and ">" or " "
    local state = app_installed(app) and "installed" or tostring(app.trust or "unreviewed")
    local color = app.trust == "verified" and colors.cyan or colors.orange
    write_at(2, top, marker .. " " .. fit(app.name or app.id, width - 4), color)
    write_at(5, top + 1, fit(state .. " - " .. tostring(app.description or ""), width - 6), colors.lightGray)
    top = top + 3
  end
  draw_status("arrows: select  enter: install/open  r: refresh  q: back")
end

local function store_loop()
  local selected = 1
  local catalog, source = fetch_catalog()
  while true do
    draw_store(selected, catalog, source)
    local _, key = os.pullEvent("key")
    if key == keys.q or key == keys.backspace then
      return
    elseif key == keys.up and selected > 1 then
      selected = selected - 1
    elseif key == keys.down and selected < #catalog then
      selected = selected + 1
    elseif key == keys.r then
      catalog, source = fetch_catalog()
      selected = 1
    elseif key == keys.enter then
      local app = catalog[selected]
      if app and app_installed(app) then
        run_app(app)
      elseif app then
        install_app(app)
        catalog, source = fetch_catalog()
      end
    end
  end
end

local function install_by_id(app_id)
  local catalog = fetch_catalog()
  for _, app in ipairs(catalog) do
    if app.id == app_id then
      if app_installed(app) then
        local ok, err = run_app(app)
        if not ok then
          print("ERR " .. tostring(err))
        end
      else
        install_app(app)
      end
      return
    end
  end
  print("ERR app not found: " .. tostring(app_id))
end

local function open_files()
  clear()
  draw_bar("Files")
  local y = 3
  for _, name in ipairs(fs.list("/")) do
    if y >= select(2, size()) then
      break
    end
    write_at(2, y, name, fs.isDir("/" .. name) and colors.cyan or colors.lightGray)
    y = y + 1
  end
  draw_status("press any key")
  os.pullEvent("key")
end

local function home_loop()
  local selected = 1
  while true do
    draw_home(selected)
    local _, key = os.pullEvent("key")
    if key == keys.q then
      clear()
      return
    elseif key == keys.left and selected > 1 then
      selected = selected - 1
    elseif key == keys.right and selected < #APPS then
      selected = selected + 1
    elseif key == keys.up and selected > 2 then
      selected = selected - 2
    elseif key == keys.down and selected + 2 <= #APPS then
      selected = selected + 2
    elseif key == keys.enter then
      local app = APPS[selected]
      if app.id == "store" then
        store_loop()
      elseif app.id == "luma" then
        if not run_luma() then
          store_loop()
        end
      elseif app.id == "shell" then
        clear()
        open_shell()
      elseif app.id == "files" then
        open_files()
      end
    end
  end
end

local function print_apps()
  print("Dock Apps")
  print("  store")
  print("  shell")
  print("  files")
  if luma_installed() then
    print("  luma")
  end
end

local command = args[1] or "home"

if command == "home" or command == "ui" then
  home_loop()
elseif command == "store" and args[2] == "install" and args[3] == "luma" then
  install_by_id("luma")
elseif command == "store" and args[2] == "install" and args[3] then
  install_by_id(args[3])
elseif command == "store" then
  store_loop()
elseif command == "apps" then
  print_apps()
elseif command == "run" and args[2] == "luma" then
  run_luma()
elseif command == "version" then
  print(VERSION)
else
  home_loop()
end
