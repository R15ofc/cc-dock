local VERSION = "0.4.0"
local LUMA_INSTALLER_URL = "https://raw.githubusercontent.com/R15ofc/cc-luma/main/luma-installer.lua"
local LUMA_SOURCE_URL = "https://raw.githubusercontent.com/R15ofc/cc-luma/main/cc"
local STORE_PROTOCOL = "dock.store"
local STORE_REPLY_PROTOCOL = "dock.store.reply"

local args = { ... }

local THEME = {
  desktop = colors.black,
  glass = colors.gray,
  glass_dark = colors.black,
  title = colors.lightGray,
  text = colors.white,
  muted = colors.lightGray,
  accent = colors.cyan,
  button = colors.blue,
  danger = colors.red,
  warning = colors.orange,
  success = colors.lime,
  selected = colors.blue,
}

local APPS = {
  finder = { id = "finder", name = "Files", icon = "FS", color = colors.blue },
  store = { id = "store", name = "Store", icon = "ST", color = colors.cyan },
  luma = { id = "luma", name = "Luma", icon = "LM", color = colors.purple },
  terminal = { id = "terminal", name = "Terminal", icon = ">_", color = colors.green },
  system = { id = "system", name = "System", icon = "SY", color = colors.orange },
}

local PINNED = { "finder", "store", "luma", "terminal", "system" }

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

local state = {
  view = "desktop",
  open = {},
  open_order = {},
  dragging_open = nil,
  catalog = nil,
  catalog_source = "offline",
  store_scroll = 0,
  file_path = "/",
  file_scroll = 0,
  file_selected = nil,
  preview = nil,
  toast = "",
  modal = nil,
}

local hitboxes = {}
local draw

local function can_color()
  return term and term.isColor and term.isColor()
end

local function set_fg(color)
  if can_color() and color then
    term.setTextColor(color)
  end
end

local function set_bg(color)
  if can_color() and color then
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

local function trim(text, width)
  text = tostring(text or "")
  if #text <= width then
    return text
  end
  if width <= 1 then
    return text:sub(1, width)
  end
  return text:sub(1, width - 1) .. "."
end

local function pad(text, width)
  text = trim(text, width)
  return text .. string.rep(" ", math.max(0, width - #text))
end

local function write_at(x, y, text, fg, bg)
  set_fg(fg)
  set_bg(bg)
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

local function read_file(path)
  local handle = fs.open(path, "r")
  if not handle then
    return nil
  end
  local data = handle.readAll()
  handle.close()
  return data or ""
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

local function path_join(base, name)
  base = tostring(base or "/")
  name = tostring(name or "")
  if base == "/" then
    return "/" .. name
  end
  return base:gsub("/+$", "") .. "/" .. name
end

local function parent_path(path)
  path = tostring(path or "/")
  if path == "/" then
    return "/"
  end
  local parent = fs.getDir(path)
  if parent == "" then
    return "/"
  end
  return "/" .. parent:gsub("^/+", "")
end

local function basename(path)
  path = tostring(path or "")
  return path:match("[^/]+$") or path
end

local function add_open(app_id)
  if not state.open[app_id] then
    state.open[app_id] = true
    table.insert(state.open_order, app_id)
  end
end

local function move_open(app_id, target_id)
  if not app_id or app_id == target_id then
    return
  end
  local next_order = {}
  for _, id in ipairs(state.open_order) do
    if id ~= app_id then
      table.insert(next_order, id)
    end
  end
  local inserted = false
  for index, id in ipairs(next_order) do
    if id == target_id then
      table.insert(next_order, index, app_id)
      inserted = true
      break
    end
  end
  if not inserted then
    table.insert(next_order, app_id)
  end
  state.open_order = next_order
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

local function set_modal(title, body, buttons)
  state.modal = { title = title, body = body or {}, buttons = buttons or {} }
end

local function show_error(message)
  set_modal("Error", { tostring(message) }, {
    { label = "Close", action = "close_modal", color = THEME.button },
  })
end

local function prompt_text(title, default)
  local width, height = size()
  local modal_w = math.min(width - 8, 38)
  local x = math.floor((width - modal_w) / 2) + 1
  local y = math.floor(height / 2) - 2
  fill(x + 1, y + 1, modal_w, 5, colors.black)
  fill(x, y, modal_w, 5, THEME.glass)
  fill(x, y, modal_w, 1, THEME.accent)
  write_at(x + 1, y, trim(title, modal_w - 2), colors.black, THEME.accent)
  write_at(x + 2, y + 2, string.rep(" ", modal_w - 4), colors.white, colors.black)
  term.setCursorPos(x + 2, y + 2)
  set_fg(colors.white)
  set_bg(colors.black)
  local value = read(nil, nil, nil, default or "")
  reset_colors()
  return value
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

local function open_view(view, app_id)
  state.view = view
  state.toast = ""
  if app_id then
    add_open(app_id)
  end
  if view == "store" and not state.catalog then
    refresh_catalog()
  end
end

local function run_luma()
  if not luma_installed() then
    open_view("store", "store")
    state.toast = "Luma not installed"
    return
  end
  add_open("luma")
  clear()
  if shell then
    shell.run("/bin/luma.lua")
  else
    dofile("/luma/luma.lua")
  end
end

local function open_terminal()
  add_open("terminal")
  clear()
  if shell then
    shell.run("shell")
  end
end

local function open_app(app_id)
  if app_id == "finder" then
    open_view("files", "finder")
  elseif app_id == "store" then
    open_view("store", "store")
  elseif app_id == "luma" then
    run_luma()
  elseif app_id == "terminal" then
    open_terminal()
  elseif app_id == "system" then
    open_view("system", "system")
  end
end

local function draw_menu_bar()
  local width = size()
  fill(1, 1, width, 1, colors.gray)
  write_at(2, 1, "DockOS", colors.white, colors.gray)
  local title = state.view == "files" and "Files" or state.view == "store" and "Store" or state.view == "system" and "System" or "Desktop"
  write_at(10, 1, title, colors.white, colors.gray)
  local time_text = textutils and textutils.formatTime and textutils.formatTime(os.time(), true) or ""
  if time_text ~= "" then
    write_at(width - #time_text, 1, time_text, colors.lightGray, colors.gray)
  end
end

local function draw_desktop_icons()
  local icons = {
    { id = "finder", name = "Computer", icon = "HD" },
    { id = "store", name = "Store", icon = "ST" },
    { id = "luma", name = "Luma", icon = "LM" },
  }
  local x = 3
  local y = 3
  for _, item in ipairs(icons) do
    fill(x, y, 8, 3, colors.black)
    write_at(x + 2, y, item.icon, colors.white, colors.black)
    write_at(x, y + 1, trim(item.name, 8), colors.lightGray, colors.black)
    hit("desktop_app", x, y, 10, 3, item.id)
    y = y + 4
  end
end

local function dock_width()
  return (#PINNED * 5) + 3 + (#state.open_order * 5)
end

local function draw_dock_icon(x, y, app_id, hit_id)
  local app = APPS[app_id]
  if not app then
    return
  end
  fill(x, y, 4, 2, app.color)
  write_at(x + 1, y, app.icon, colors.white, app.color)
  if state.open[app_id] then
    write_at(x + 1, y + 1, "  ", colors.white, colors.white)
  end
  hit(hit_id, x, y, 4, 2, app_id)
end

local function draw_dock()
  local width, height = size()
  local y = height - 2
  local total = math.min(width - 2, dock_width())
  local x = math.max(2, math.floor((width - total) / 2) + 1)
  fill(x - 1, y - 1, total + 2, 3, colors.black)
  fill(x, y, total, 3, colors.gray)

  local cursor = x + 1
  for _, app_id in ipairs(PINNED) do
    draw_dock_icon(cursor, y, app_id, "dock_pinned")
    cursor = cursor + 5
  end

  write_at(cursor, y, "|", colors.lightGray, colors.gray)
  hit("open_drop_end", cursor, y, 2, 2, nil)
  cursor = cursor + 3

  for _, app_id in ipairs(state.open_order) do
    draw_dock_icon(cursor, y, app_id, "dock_open")
    cursor = cursor + 5
  end
end

local function window_rect()
  local width, height = size()
  return 3, 3, width - 4, height - 7
end

local function draw_window(title)
  local x, y, width, height = window_rect()
  fill(x + 1, y + 1, width, height, colors.black)
  fill(x, y, width, height, THEME.glass_dark)
  fill(x, y, width, 1, THEME.title)
  write_at(x + 2, y, trim(title, width - 4), colors.black, THEME.title)
  return x, y, width, height
end

local function draw_button(id, x, y, label, payload, color)
  local width = #label + 2
  fill(x, y, width, 1, color or THEME.button)
  write_at(x + 1, y, label, colors.white, color or THEME.button)
  hit(id, x, y, width, 1, payload)
  return width
end

local function list_files(path)
  local entries = {}
  for _, name in ipairs(fs.list(path)) do
    local full = path_join(path, name)
    table.insert(entries, {
      name = name,
      path = full,
      dir = fs.isDir(full),
      size = fs.isDir(full) and "-" or tostring(fs.getSize(full) or 0),
    })
  end
  table.sort(entries, function(left, right)
    if left.dir ~= right.dir then
      return left.dir
    end
    return left.name:lower() < right.name:lower()
  end)
  return entries
end

local function selected_entry()
  if not state.file_selected then
    return nil
  end
  if fs.exists(state.file_selected) then
    return {
      name = basename(state.file_selected),
      path = state.file_selected,
      dir = fs.isDir(state.file_selected),
    }
  end
  state.file_selected = nil
  return nil
end

local function open_selected_file()
  local entry = selected_entry()
  if not entry then
    return
  end
  if entry.dir then
    state.file_path = entry.path
    state.file_selected = nil
    state.file_scroll = 0
    state.preview = nil
    return
  end
  if entry.path:match("%.lua$") and shell then
    clear()
    shell.run(entry.path)
    return
  end
  state.preview = read_file(entry.path) or ""
end

local function create_file(kind)
  local default = kind == "folder" and "New Folder" or "Untitled.txt"
  local name = prompt_text(kind == "folder" and "New Folder" or "New File", default)
  if not name or name == "" then
    return
  end
  local path = path_join(state.file_path, name)
  if fs.exists(path) then
    state.toast = "Already exists"
    return
  end
  if kind == "folder" then
    fs.makeDir(path)
  else
    write_file(path, "")
  end
  state.file_selected = path
end

local function rename_selected()
  local entry = selected_entry()
  if not entry then
    return
  end
  local name = prompt_text("Rename", entry.name)
  if not name or name == "" or name == entry.name then
    return
  end
  local target = path_join(state.file_path, name)
  if fs.exists(target) then
    state.toast = "Already exists"
    return
  end
  fs.move(entry.path, target)
  state.file_selected = target
end

local function delete_selected()
  local entry = selected_entry()
  if not entry then
    return
  end
  set_modal("Delete", { entry.name }, {
    { label = "Delete", action = "confirm_delete_file", color = THEME.danger },
    { label = "Cancel", action = "close_modal", color = THEME.button },
  })
end

local function draw_files()
  local x, y, width, height = draw_window("Files")
  local toolbar_y = y + 2
  local bx = x + 2
  bx = bx + draw_button("file_back", bx, toolbar_y, "<", nil, colors.gray) + 1
  bx = bx + draw_button("file_new_folder", bx, toolbar_y, "Folder", nil, THEME.button) + 1
  bx = bx + draw_button("file_new_file", bx, toolbar_y, "File", nil, THEME.button) + 1
  bx = bx + draw_button("file_rename", bx, toolbar_y, "Rename", nil, colors.gray) + 1
  bx = bx + draw_button("file_delete", bx, toolbar_y, "Delete", nil, THEME.danger) + 1
  draw_button("file_open", bx, toolbar_y, "Open", nil, colors.purple)

  write_at(x + 2, y + 4, trim(state.file_path, width - 4), colors.cyan, THEME.glass_dark)
  local list_x = x + 2
  local list_y = y + 6
  local list_w = math.floor(width * 0.58)
  local preview_x = list_x + list_w + 2
  local preview_w = width - list_w - 6
  local rows = height - 8
  fill(list_x, list_y, list_w, rows + 1, colors.black)
  fill(preview_x, list_y, preview_w, rows + 1, colors.black)
  write_at(list_x + 1, list_y, pad("Name", list_w - 14) .. "Kind  Size", colors.lightGray, colors.black)

  local entries = list_files(state.file_path)
  for row = 1, rows do
    local item = entries[row + state.file_scroll]
    if not item then
      break
    end
    local row_y = list_y + row
    local selected = state.file_selected == item.path
    local bg = selected and THEME.selected or (row % 2 == 0 and colors.black or colors.gray)
    fill(list_x, row_y, list_w, 1, bg)
    local kind = item.dir and "DIR " or "FILE"
    write_at(list_x + 1, row_y, pad(item.name, list_w - 14), item.dir and colors.cyan or colors.white, bg)
    write_at(list_x + list_w - 12, row_y, kind, colors.lightGray, bg)
    write_at(list_x + list_w - 6, row_y, trim(item.size, 5), colors.lightGray, bg)
    hit("file_select", list_x, row_y, list_w, 1, item.path)
  end

  local entry = selected_entry()
  if entry then
    write_at(preview_x + 1, list_y, trim(entry.name, preview_w - 2), colors.white, colors.black)
    write_at(preview_x + 1, list_y + 1, entry.dir and "Folder" or "File", colors.lightGray, colors.black)
    if state.preview and not entry.dir then
      local line_y = list_y + 3
      for line in (state.preview .. "\n"):gmatch("(.-)\n") do
        if line_y >= list_y + rows then
          break
        end
        write_at(preview_x + 1, line_y, trim(line, preview_w - 2), colors.lightGray, colors.black)
        line_y = line_y + 1
      end
    end
  end
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
  local x, y, width, height = draw_window("Store")
  write_at(x + width - 10, y, state.catalog_source, colors.black, THEME.title)
  local row_y = y + 2
  for index = 1 + state.store_scroll, #state.catalog do
    local app = state.catalog[index]
    if row_y + 4 >= y + height then
      break
    end
    fill(x + 2, row_y, width - 4, 4, colors.black)
    fill(x + 2, row_y, 2, 4, trust_color(app))
    write_at(x + 5, row_y, trim(app.name or app.id, width - 24), colors.white, colors.black)
    write_at(x + 5, row_y + 1, trim(app.description or "", width - 10), colors.lightGray, colors.black)
    write_at(x + 5, row_y + 2, string.upper(tostring(app.trust or "unreviewed")), trust_color(app), colors.black)
    local installed = app_installed(app)
    draw_button(installed and "catalog_open" or "catalog_install", x + width - 13, row_y + 1, installed and "Open" or "Install", app, installed and colors.purple or THEME.button)
    hit(installed and "catalog_open" or "catalog_install", x + 2, row_y, width - 4, 4, app)
    row_y = row_y + 5
  end
end

local function draw_system()
  local x, y, width = draw_window("System")
  local rows = {
    { "DockOS", VERSION },
    { "Computer", tostring(os.getComputerID and os.getComputerID() or "?") },
    { "HTTP", http and "enabled" or "disabled" },
    { "RIG", fs.exists("/rig/devapi/ui.lua") and "devapi" or "fallback" },
  }
  local row_y = y + 3
  for _, row in ipairs(rows) do
    write_at(x + 3, row_y, pad(row[1], 12), colors.lightGray, THEME.glass_dark)
    write_at(x + 17, row_y, trim(row[2], width - 20), colors.white, THEME.glass_dark)
    row_y = row_y + 2
  end
end

local function draw_modal()
  if not state.modal then
    return
  end
  local width, height = size()
  local modal_w = math.min(width - 8, 38)
  local modal_h = 7 + #(state.modal.body or {})
  local x = math.floor((width - modal_w) / 2) + 1
  local y = math.floor((height - modal_h) / 2) + 1
  fill(x + 1, y + 1, modal_w, modal_h, colors.black)
  fill(x, y, modal_w, modal_h, THEME.glass)
  fill(x, y, modal_w, 1, THEME.accent)
  write_at(x + 1, y, trim(state.modal.title, modal_w - 2), colors.black, THEME.accent)
  for index, line in ipairs(state.modal.body or {}) do
    write_at(x + 2, y + 1 + index, trim(line, modal_w - 4), colors.white, THEME.glass)
  end
  local bx = x + 2
  local by = y + modal_h - 2
  for _, button in ipairs(state.modal.buttons or {}) do
    bx = bx + draw_button(button.action, bx, by, button.label, button.payload, button.color) + 2
  end
end

local function draw_toast()
  if not state.toast or state.toast == "" then
    return
  end
  local width, height = size()
  local text = trim(state.toast, width - 12)
  local x = math.max(2, width - #text - 3)
  fill(x, height - 4, #text + 2, 1, colors.black)
  write_at(x + 1, height - 4, text, colors.cyan, colors.black)
end

function draw()
  hitboxes = {}
  clear()
  local width, height = size()
  fill(1, 1, width, height, THEME.desktop)
  draw_menu_bar()
  draw_desktop_icons()
  if state.view == "files" then
    draw_files()
  elseif state.view == "store" then
    draw_store()
  elseif state.view == "system" then
    draw_system()
  end
  draw_dock()
  draw_toast()
  draw_modal()
end

local function confirm_install(app)
  if app.trust == "verified" then
    install_app(app)
    return
  end
  set_modal("Unreviewed", { tostring(app.name or app.id) }, {
    { label = "Install", action = "confirm_install", payload = app, color = THEME.warning },
    { label = "Cancel", action = "close_modal", color = THEME.button },
  })
end

local function handle_action(id, payload)
  if id == "close_modal" then
    state.modal = nil
  elseif id == "desktop_app" or id == "dock_pinned" then
    open_app(payload)
  elseif id == "dock_open" then
    state.dragging_open = payload
    if payload == "finder" then
      open_view("files", "finder")
    elseif payload == "store" then
      open_view("store", "store")
    elseif payload == "system" then
      open_view("system", "system")
    else
      state.toast = APPS[payload] and APPS[payload].name or ""
    end
  elseif id == "open_drop_end" and state.dragging_open then
    move_open(state.dragging_open, nil)
    state.dragging_open = nil
  elseif id == "catalog_install" then
    confirm_install(payload)
  elseif id == "confirm_install" then
    install_app(payload)
  elseif id == "catalog_open" then
    if payload.id == "luma" then
      run_luma()
    end
  elseif id == "file_select" then
    if state.file_selected == payload then
      open_selected_file()
    else
      state.file_selected = payload
      state.preview = nil
    end
  elseif id == "file_back" then
    state.file_path = parent_path(state.file_path)
    state.file_selected = nil
    state.file_scroll = 0
  elseif id == "file_new_folder" then
    create_file("folder")
  elseif id == "file_new_file" then
    create_file("file")
  elseif id == "file_rename" then
    rename_selected()
  elseif id == "file_delete" then
    delete_selected()
  elseif id == "file_open" then
    open_selected_file()
  elseif id == "confirm_delete_file" then
    local entry = selected_entry()
    if entry then
      fs.delete(entry.path)
      state.file_selected = nil
      state.preview = nil
    end
    state.modal = nil
  end
end

local function loop(initial_view)
  if initial_view and initial_view ~= "desktop" then
    open_view(initial_view, initial_view == "files" and "finder" or initial_view)
  end
  while true do
    draw()
    local event, first, second, third = os.pullEvent()
    if event == "mouse_click" then
      local box = hit_at(second, third)
      if box then
        handle_action(box.id, box.payload)
      else
        state.view = "desktop"
      end
    elseif event == "mouse_up" then
      local box = hit_at(second, third)
      if state.dragging_open then
        if box and box.id == "dock_open" then
          move_open(state.dragging_open, box.payload)
        elseif box and box.id == "open_drop_end" then
          move_open(state.dragging_open, nil)
        end
        state.dragging_open = nil
      end
    elseif event == "mouse_scroll" then
      if state.view == "files" then
        state.file_scroll = math.max(0, state.file_scroll + first)
      elseif state.view == "store" and state.catalog then
        state.store_scroll = math.max(0, math.min(math.max(0, #state.catalog - 1), state.store_scroll + first))
      end
    elseif event == "key" then
      if first == keys.q then
        clear()
        return
      elseif first == keys.backspace then
        if state.modal then
          state.modal = nil
        else
          state.view = "desktop"
        end
      elseif first == keys.enter and state.view == "files" then
        open_selected_file()
      elseif first == keys.delete and state.view == "files" then
        delete_selected()
      end
    end
  end
end

local function print_apps()
  print("DockOS " .. VERSION)
  for _, app_id in ipairs(PINNED) do
    local app = APPS[app_id]
    print(app.id .. " " .. app.name)
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
  loop("desktop")
elseif command == "store" and args[2] == "install" and args[3] then
  install_by_id(args[3])
elseif command == "store" then
  loop("store")
elseif command == "files" then
  loop("files")
elseif command == "apps" then
  print_apps()
elseif command == "run" and args[2] == "luma" then
  run_luma()
elseif command == "version" then
  print(VERSION)
else
  loop("desktop")
end
