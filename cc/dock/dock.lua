local VERSION = "0.3.0"
local LUMA_INSTALLER_URL = "https://raw.githubusercontent.com/R15ofc/cc-luma/main/luma-installer.lua"
local LUMA_SOURCE_URL = "https://raw.githubusercontent.com/R15ofc/cc-luma/main/cc"
local STORE_PROTOCOL = "dock.store"
local STORE_REPLY_PROTOCOL = "dock.store.reply"

local args = { ... }

local THEME = {
  desktop = colors.black,
  sidebar = colors.gray,
  sidebar_active = colors.cyan,
  topbar = colors.gray,
  panel = colors.gray,
  panel_dark = colors.black,
  panel_light = colors.lightGray,
  text = colors.white,
  muted = colors.lightGray,
  accent = colors.cyan,
  success = colors.lime,
  warning = colors.orange,
  danger = colors.red,
  button = colors.blue,
  button_alt = colors.gray,
}

local APPS = {
  { id = "store", name = "Store", icon = "ST", color = colors.cyan },
  { id = "luma", name = "Luma", icon = "LM", color = colors.purple },
  { id = "files", name = "Files", icon = "FS", color = colors.blue },
  { id = "shell", name = "Shell", icon = ">_", color = colors.green },
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

local function load_rig_devapi(name)
  if fs.exists("/rig/bootstrap.lua") then
    local ok, module = pcall(function()
      return dofile("/rig/bootstrap.lua").require("devapi." .. name)
    end)
    if ok and type(module) == "table" then
      return module
    end
  end
  local path = "/rig/devapi/" .. name .. ".lua"
  if fs.exists(path) then
    local ok, module = pcall(dofile, path)
    if ok and type(module) == "table" then
      return module
    end
  end
  return nil
end

local rig_app = load_rig_devapi("app")
local rig_store = load_rig_devapi("store")
local rig_ui = load_rig_devapi("ui")

local state = {
  view = "home",
  catalog = nil,
  catalog_source = "offline",
  selected = 1,
  store_scroll = 0,
  file_scroll = 0,
  toast = "",
  modal = nil,
}

local hitboxes = {}
local draw

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

local function size()
  local width, height = term.getSize()
  return width or 51, height or 19
end

local function fit(text, width)
  text = tostring(text or "")
  if #text <= width then
    return text .. string.rep(" ", math.max(0, width - #text))
  end
  if width <= 1 then
    return text:sub(1, width)
  end
  return text:sub(1, width - 1) .. "."
end

local function trim_fit(text, width)
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
  term.write(tostring(text or ""))
  reset_colors()
end

local function fill(x, y, width, height, bg)
  if width <= 0 or height <= 0 then
    return
  end
  set_bg(bg or colors.black)
  for row = y, y + height - 1 do
    term.setCursorPos(x, row)
    term.write(string.rep(" ", width))
  end
  reset_colors()
end

local function clear()
  reset_colors()
  term.clear()
  term.setCursorPos(1, 1)
end

local function hit(id, x, y, width, height, payload)
  if width <= 0 or height <= 0 then
    return
  end
  table.insert(hitboxes, {
    id = id,
    x1 = x,
    y1 = y,
    x2 = x + width - 1,
    y2 = y + height - 1,
    payload = payload,
  })
end

local function hit_at(x, y)
  for index = #hitboxes, 1, -1 do
    local box = hitboxes[index]
    if x >= box.x1 and x <= box.x2 and y >= box.y1 and y <= box.y2 then
      return box
    end
  end
  return nil
end

local function ensure_parent(path)
  local dir = fs.getDir(path)
  if dir and dir ~= "" and not fs.exists(dir) then
    fs.makeDir(dir)
  end
end

local function write_file(path, data)
  if rig_app and rig_app.write_file then
    return rig_app.write_file(path, data)
  end
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
  if rig_app and rig_app.download then
    return rig_app.download(url, { ["Accept"] = "text/plain" })
  end
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

local function run_hidden(callback)
  if rig_app and rig_app.run_hidden then
    return rig_app.run_hidden(callback)
  end
  if window and term and term.current and term.redirect then
    local current = term.current()
    local hidden = window.create(current, 1, 1, 1, 1, false)
    term.redirect(hidden)
    local ok, result = pcall(callback)
    term.redirect(current)
    return ok, result
  end
  return pcall(callback)
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
  if rig_store and rig_store.catalog then
    return rig_store.catalog()
  end
  if not open_rednet() then
    return BUILTIN_CATALOG, "offline"
  end
  rednet.broadcast({ type = "catalog" }, STORE_PROTOCOL)
  local _, message = rednet.receive(STORE_REPLY_PROTOCOL, 1)
  if type(message) == "table" and message.ok and type(message.apps) == "table" then
    return message.apps, "server"
  end
  return BUILTIN_CATALOG, "offline"
end

local function refresh_catalog()
  state.catalog, state.catalog_source = fetch_catalog()
  state.store_scroll = 0
end

local function luma_installed()
  return fs.exists("/luma/luma.lua")
end

local function app_installed(app)
  if app.id == "luma" then
    return luma_installed()
  end
  return fs.exists("/dock/apps/" .. tostring(app.id) .. ".lua")
end

local function run_luma()
  if not luma_installed() then
    state.view = "store"
    if not state.catalog then
      refresh_catalog()
    end
    state.toast = "Luma is not installed"
    return false
  end
  clear()
  if shell then
    shell.run("/bin/luma.lua")
  else
    dofile("/luma/luma.lua")
  end
  return true
end

local function run_app(app)
  if app.id == "luma" then
    return run_luma()
  end
  if app.command and shell then
    clear()
    shell.run(app.command)
    return true
  end
  state.toast = "App cannot be opened"
  return false
end

local function set_modal(title, body, buttons)
  state.modal = {
    title = title,
    body = body or {},
    buttons = buttons or {},
  }
end

local function show_error(message)
  set_modal("Error", { tostring(message) }, {
    { label = "Close", action = "close_modal", color = THEME.button_alt },
  })
end

local function install_app(app)
  if not app or not app.installer then
    show_error("Invalid package")
    return
  end

  state.modal = nil
  state.toast = "Downloading " .. tostring(app.name or app.id)
  draw()

  local body, err = download(app.installer)
  if not body then
    show_error("Download failed: " .. tostring(err))
    return
  end

  state.toast = "Installing " .. tostring(app.name or app.id)
  draw()

  local installer_path = "/tmp/" .. tostring(app.id) .. "-installer.lua"
  local ok, write_err = write_file(installer_path, body)
  if not ok then
    show_error(write_err)
    return
  end

  local run_ok, run_err = run_hidden(function()
    if shell then
      if app.source then
        return shell.run(installer_path, "--source", app.source)
      end
      return shell.run(installer_path)
    end
    return dofile(installer_path)
  end)

  if not run_ok then
    show_error("Install failed: " .. tostring(run_err))
    return
  end

  state.toast = tostring(app.name or app.id) .. " installed"
  refresh_catalog()
end

local function open_shell()
  clear()
  if shell then
    shell.run("shell")
  end
end

local function title_for_view()
  if state.view == "store" then
    return "Store"
  elseif state.view == "files" then
    return "Files"
  elseif state.view == "system" then
    return "System"
  end
  return "Desktop"
end

local function clock_text()
  if textutils and textutils.formatTime and os.time then
    return textutils.formatTime(os.time(), true)
  end
  return ""
end

local function draw_topbar()
  local width = size()
  fill(1, 1, width, 1, THEME.topbar)
  write_at(2, 1, "DockOS", colors.white, THEME.topbar)
  write_at(10, 1, title_for_view(), colors.cyan, THEME.topbar)
  local clock = clock_text()
  if clock ~= "" then
    write_at(width - #clock, 1, clock, colors.lightGray, THEME.topbar)
  end
end

local function draw_sidebar()
  local _, height = size()
  fill(1, 2, 11, height - 1, THEME.sidebar)
  local items = {
    { id = "home", label = "Home", icon = "HM" },
    { id = "store", label = "Store", icon = "ST" },
    { id = "files", label = "Files", icon = "FS" },
    { id = "system", label = "System", icon = "SY" },
  }
  local y = 3
  for _, item in ipairs(items) do
    local active = state.view == item.id or (state.view == "home" and item.id == "home")
    local bg = active and THEME.sidebar_active or THEME.sidebar
    local fg = active and colors.black or colors.white
    fill(2, y, 9, 2, bg)
    write_at(3, y, item.icon, fg, bg)
    write_at(6, y, trim_fit(item.label, 4), fg, bg)
    hit("nav", 2, y, 9, 2, item.id)
    y = y + 3
  end
end

local function draw_toast()
  if not state.toast or state.toast == "" then
    return
  end
  local width, height = size()
  local text = trim_fit(state.toast, width - 16)
  local x = math.max(13, width - #text - 4)
  fill(x, height, #text + 3, 1, colors.black)
  write_at(x + 1, height, text, colors.cyan, colors.black)
end

local function draw_card(x, y, width, height, title, subtitle, color, action, payload)
  fill(x + 1, y + 1, width, height, colors.black)
  fill(x, y, width, height, THEME.panel)
  fill(x, y, width, 1, color or THEME.accent)
  write_at(x + 1, y + 2, trim_fit(title, width - 2), colors.white, THEME.panel)
  if subtitle then
    write_at(x + 1, y + 3, trim_fit(subtitle, width - 2), colors.lightGray, THEME.panel)
  end
  hit(action, x, y, width, height, payload)
end

local function draw_desktop()
  local width, height = size()
  local x = 14
  local y = 3
  local card_w = math.max(15, math.floor((width - x - 2) / 2))
  local card_h = 5
  write_at(x, y, "Workspace", colors.white, THEME.desktop)
  y = y + 2
  for index, app in ipairs(APPS) do
    local column = (index - 1) % 2
    local row = math.floor((index - 1) / 2)
    local card_x = x + column * (card_w + 2)
    local card_y = y + row * (card_h + 1)
    local state_text = app.id == "luma" and (luma_installed() and "Installed" or "Available") or "Ready"
    draw_card(card_x, card_y, card_w, card_h, app.icon .. "  " .. app.name, state_text, app.color, "app", app.id)
  end

  local panel_y = math.min(height - 4, y + 12)
  fill(x, panel_y, width - x - 1, 3, THEME.panel_dark)
  write_at(x + 1, panel_y + 1, "RIG is dev API. Dock is the UI.", colors.lightGray, THEME.panel_dark)
end

local function trust_color(app)
  if app.trust == "verified" then
    return THEME.success
  elseif app.trust == "blocked" then
    return THEME.danger
  end
  return THEME.warning
end

local function draw_store()
  if not state.catalog then
    refresh_catalog()
  end
  local width, height = size()
  local x = 14
  local y = 3
  write_at(x, y, "App Store", colors.white, THEME.desktop)
  write_at(width - 12, y, state.catalog_source, colors.lightGray, THEME.desktop)
  hit("refresh_store", width - 12, y, 10, 1, nil)

  local top = y + 2
  local card_h = 5
  local visible = math.max(1, math.floor((height - top) / (card_h + 1)))
  for row = 1, visible do
    local app = state.catalog[row + state.store_scroll]
    if not app then
      break
    end
    local card_y = top + (row - 1) * (card_h + 1)
    local card_w = width - x - 1
    fill(x, card_y, card_w, card_h, THEME.panel)
    fill(x, card_y, 2, card_h, trust_color(app))
    write_at(x + 3, card_y + 1, trim_fit(app.name or app.id, card_w - 18), colors.white, THEME.panel)
    write_at(x + 3, card_y + 2, trim_fit(app.description or "", card_w - 6), colors.lightGray, THEME.panel)
    write_at(x + 3, card_y + 3, string.upper(tostring(app.trust or "unreviewed")), trust_color(app), THEME.panel)

    local installed = app_installed(app)
    local button_label = installed and "OPEN" or "INSTALL"
    local button_w = #button_label + 2
    fill(x + card_w - button_w - 1, card_y + 1, button_w, 3, installed and colors.purple or THEME.button)
    write_at(x + card_w - button_w, card_y + 2, button_label, colors.white, installed and colors.purple or THEME.button)
    hit(installed and "run_catalog_app" or "install_catalog_app", x, card_y, card_w, card_h, app)
  end
end

local function draw_files()
  local width, height = size()
  local x = 14
  local y = 3
  write_at(x, y, "Files", colors.white, THEME.desktop)
  local files = fs.list("/")
  table.sort(files)
  local visible = height - y - 1
  for row = 1, visible do
    local name = files[row + state.file_scroll]
    if not name then
      break
    end
    local path = "/" .. name
    local bg = row % 2 == 0 and colors.black or THEME.panel_dark
    fill(x, y + row, width - x - 1, 1, bg)
    write_at(x + 1, y + row, fs.isDir(path) and "DIR" or "FILE", fs.isDir(path) and colors.cyan or colors.lightGray, bg)
    write_at(x + 7, y + row, trim_fit(name, width - x - 8), colors.white, bg)
  end
end

local function draw_system()
  local width = size()
  local x = 14
  local y = 3
  write_at(x, y, "System", colors.white, THEME.desktop)
  local rows = {
    { "DockOS", VERSION },
    { "RIG devapi", rig_ui and "ready" or "fallback" },
    { "Computer", tostring(os.getComputerID and os.getComputerID() or "?") },
    { "HTTP", http and "enabled" or "disabled" },
    { "Luma", luma_installed() and "installed" or "missing" },
    { "Store", state.catalog_source or "offline" },
  }
  y = y + 2
  for _, row in ipairs(rows) do
    fill(x, y, width - x - 1, 2, THEME.panel_dark)
    write_at(x + 1, y, row[1], colors.lightGray, THEME.panel_dark)
    write_at(x + 16, y, row[2], colors.white, THEME.panel_dark)
    y = y + 3
  end
end

function draw()
  hitboxes = {}
  clear()
  fill(1, 1, size(), select(2, size()), THEME.desktop)
  draw_topbar()
  draw_sidebar()
  if state.view == "store" then
    draw_store()
  elseif state.view == "files" then
    draw_files()
  elseif state.view == "system" then
    draw_system()
  else
    draw_desktop()
  end
  draw_toast()

  if state.modal then
    local width, height = size()
    local modal_w = math.min(width - 8, 38)
    local modal_h = 7 + #(state.modal.body or {})
    local x = math.floor((width - modal_w) / 2) + 1
    local y = math.floor((height - modal_h) / 2) + 1
    fill(x + 1, y + 1, modal_w, modal_h, colors.black)
    fill(x, y, modal_w, modal_h, THEME.panel)
    fill(x, y, modal_w, 1, THEME.accent)
    write_at(x + 1, y, trim_fit(state.modal.title, modal_w - 2), colors.black, THEME.accent)
    for index, line in ipairs(state.modal.body or {}) do
      write_at(x + 2, y + 1 + index, trim_fit(line, modal_w - 4), colors.white, THEME.panel)
    end
    local button_y = y + modal_h - 2
    local button_x = x + 2
    for _, button in ipairs(state.modal.buttons or {}) do
      local button_w = #button.label + 4
      fill(button_x, button_y, button_w, 2, button.color or THEME.button)
      write_at(button_x + 2, button_y, button.label, colors.white, button.color or THEME.button)
      hit(button.action, button_x, button_y, button_w, 2, button.payload)
      button_x = button_x + button_w + 2
    end
  end
end

local function open_view(view)
  state.view = view
  state.toast = ""
  if view == "store" and not state.catalog then
    refresh_catalog()
  end
end

local function confirm_install(app)
  if app.trust == "verified" then
    install_app(app)
    return
  end
  set_modal("Unreviewed package", {
    tostring(app.name or app.id),
    "This package is not verified.",
  }, {
    { label = "Install", action = "confirm_install", payload = app, color = THEME.warning },
    { label = "Cancel", action = "close_modal", color = THEME.button_alt },
  })
end

local function handle_action(id, payload)
  if id == "close_modal" then
    state.modal = nil
  elseif id == "confirm_install" then
    install_app(payload)
  elseif id == "nav" then
    open_view(payload)
  elseif id == "refresh_store" then
    refresh_catalog()
    state.toast = "Store refreshed"
  elseif id == "app" then
    if payload == "store" then
      open_view("store")
    elseif payload == "luma" then
      run_luma()
    elseif payload == "files" then
      open_view("files")
    elseif payload == "shell" then
      open_shell()
    end
  elseif id == "install_catalog_app" then
    confirm_install(payload)
  elseif id == "run_catalog_app" then
    run_app(payload)
  end
end

local function loop(initial_view)
  open_view(initial_view or "home")
  while true do
    draw()
    local event, first, second, third = os.pullEvent()
    if event == "mouse_click" then
      local box = hit_at(second, third)
      if box then
        handle_action(box.id, box.payload)
      end
    elseif event == "mouse_scroll" then
      if state.view == "store" and state.catalog then
        state.store_scroll = math.max(0, math.min(math.max(0, #state.catalog - 1), state.store_scroll + first))
      elseif state.view == "files" then
        state.file_scroll = math.max(0, state.file_scroll + first)
      end
    elseif event == "key" then
      if first == keys.q then
        clear()
        return
      elseif first == keys.backspace then
        if state.modal then
          state.modal = nil
        else
          open_view("home")
        end
      elseif first == keys.r and state.view == "store" then
        refresh_catalog()
      end
    end
  end
end

local function print_apps()
  print("DockOS " .. VERSION)
  for _, app in ipairs(APPS) do
    local status = "ready"
    if app.id == "luma" then
      status = luma_installed() and "installed" or "available"
    end
    print(app.id .. "  " .. status)
  end
end

local function install_by_id(app_id)
  refresh_catalog()
  for _, app in ipairs(state.catalog) do
    if app.id == app_id then
      install_app(app)
      return
    end
  end
  print("ERR app not found: " .. tostring(app_id))
end

local command = args[1] or "home"

if command == "home" or command == "ui" then
  loop("home")
elseif command == "store" and args[2] == "install" and args[3] then
  install_by_id(args[3])
elseif command == "store" then
  loop("store")
elseif command == "apps" then
  print_apps()
elseif command == "run" and args[2] == "luma" then
  run_luma()
elseif command == "version" then
  print(VERSION)
else
  loop("home")
end
