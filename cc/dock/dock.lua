local VERSION = "0.6.0"
local LUMA_INSTALLER_URL = "https://raw.githubusercontent.com/R15ofc/cc-luma/main/luma-installer.lua"
local LUMA_SOURCE_URL = "https://raw.githubusercontent.com/R15ofc/cc-luma/main/cc"
local DOCS_DIR = "/dock/documents"
local PAINT_DIR = "/dock/paintings"

local args = { ... }

local DEFAULT_EXTERNAL_WIDTH = 80
local DEFAULT_EXTERNAL_HEIGHT = 30
local CELL_WIDTH = 8
local CELL_HEIGHT = 12
local PERIPHERAL_SCAN_SECONDS = 1

local THEME = {
  desktop = colors.black,
  menubar = colors.gray,
  dock = colors.gray,
  dock_shadow = colors.black,
  window = colors.black,
  window_title = colors.lightGray,
  window_inactive = colors.gray,
  surface = colors.gray,
  field = colors.black,
  text = colors.white,
  muted = colors.lightGray,
  accent = colors.cyan,
  selected = colors.blue,
  button = colors.blue,
  danger = colors.red,
  warning = colors.orange,
  success = colors.lime,
}

local APPS = {
  finder = { id = "finder", name = "Files", icon = "FS", color = colors.blue },
  store = { id = "store", name = "Store", icon = "ST", color = colors.cyan },
  docs = { id = "docs", name = "Documents", icon = "DC", color = colors.lightBlue },
  paint = { id = "paint", name = "Paint", icon = "PT", color = colors.pink },
  settings = { id = "settings", name = "Settings", icon = "SG", color = colors.orange },
  luma = { id = "luma", name = "Luma", icon = "LM", color = colors.purple },
  terminal = { id = "terminal", name = "Terminal", icon = ">_", color = colors.green },
}

local PINNED = { "finder", "store", "docs", "paint", "settings", "luma", "terminal" }

local STORE_APPS = {
  { id = "docs", name = "Documents", trust = "built-in", description = "Write documents and print them." },
  { id = "paint", name = "Paint", trust = "built-in", description = "Simple pixel drawing studio." },
  {
    id = "luma",
    name = "Luma Browser",
    trust = "verified",
    description = "Browser for Luma pages and internet gateway.",
    installer = LUMA_INSTALLER_URL,
    source = LUMA_SOURCE_URL,
  },
}

local state = {
  windows = {},
  window_order = {},
  next_window_id = 1,
  active_window = nil,
  open_dock_order = {},
  dragging_window = nil,
  dragging_dock_app = nil,
  file_path = "/",
  file_scroll = 0,
  file_selected = nil,
  file_preview = nil,
  docs_selected = nil,
  docs_preview = "",
  paint_color = colors.white,
  paint_cells = {},
  settings_message = "",
  toast = "",
  modal = nil,
  input = nil,
  directgpu = nil,
  headless = true,
  frame_ops = {},
  virtual_width = DEFAULT_EXTERNAL_WIDTH,
  virtual_height = DEFAULT_EXTERNAL_HEIGHT,
  peripheral_scan_timer = nil,
  external = {
    gpu = nil,
    gpu_name = nil,
    keyboard = nil,
    keyboard_name = nil,
    monitor = nil,
    monitor_name = nil,
    pixel_width = DEFAULT_EXTERNAL_WIDTH * CELL_WIDTH,
    pixel_height = DEFAULT_EXTERNAL_HEIGHT * CELL_HEIGHT,
    cell_width = CELL_WIDTH,
    cell_height = CELL_HEIGHT,
  },
}

local hitboxes = {}
local draw

local function blank_terminal()
  if not term then
    return
  end
  if term.setTextColor then
    pcall(term.setTextColor, colors.black)
  end
  if term.setBackgroundColor then
    pcall(term.setBackgroundColor, colors.black)
  end
  if term.clear then
    pcall(term.clear)
  end
  if term.setCursorPos then
    pcall(term.setCursorPos, 1, 1)
  end
end

local function can_color()
  return term and term.isColor and term.isColor()
end

local function reset_colors()
  if can_color() then
    term.setTextColor(colors.white)
    term.setBackgroundColor(colors.black)
  end
end

local function set_foreground(color)
  if can_color() and color then
    term.setTextColor(color)
  end
end

local function set_background(color)
  if can_color() and color then
    term.setBackgroundColor(color)
  end
end

local function screen_size()
  if state.headless then
    return state.virtual_width or DEFAULT_EXTERNAL_WIDTH, state.virtual_height or DEFAULT_EXTERNAL_HEIGHT
  end
  local screen_width, screen_height = term.getSize()
  return screen_width or 51, screen_height or 19
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

local function queue_frame_op(op)
  state.frame_ops = state.frame_ops or {}
  table.insert(state.frame_ops, op)
end

local function write_at(left, top, text, foreground, background)
  local screen_width, screen_height = screen_size()
  if left < 1 or top < 1 or left > screen_width or top > screen_height then
    return
  end
  text = trim(text, screen_width - left + 1)
  if state.headless then
    queue_frame_op({
      kind = "text",
      left = left,
      top = top,
      text = tostring(text or ""),
      foreground = foreground or colors.white,
      background = background,
    })
    return
  end
  set_foreground(foreground)
  set_background(background)
  term.setCursorPos(left, top)
  term.write(tostring(text or ""))
  reset_colors()
end

local function fill(left, top, width, height, background)
  local screen_width, screen_height = screen_size()
  if left < 1 then
    width = width + left - 1
    left = 1
  end
  if top < 1 then
    height = height + top - 1
    top = 1
  end
  if left + width - 1 > screen_width then
    width = screen_width - left + 1
  end
  if top + height - 1 > screen_height then
    height = screen_height - top + 1
  end
  if width <= 0 or height <= 0 then
    return
  end
  if state.headless then
    queue_frame_op({
      kind = "fill",
      left = left,
      top = top,
      width = width,
      height = height,
      background = background or colors.black,
    })
    return
  end
  set_background(background or colors.black)
  for row = top, top + height - 1 do
    term.setCursorPos(left, row)
    term.write(string.rep(" ", width))
  end
  reset_colors()
end

local function clear()
  if state.headless then
    state.frame_ops = {}
    return
  end
  reset_colors()
  term.clear()
  term.setCursorPos(1, 1)
end

local function add_hit(id, left, top, width, height, payload)
  if width <= 0 or height <= 0 then
    return
  end
  table.insert(hitboxes, {
    id = id,
    left = left,
    top = top,
    right = left + width - 1,
    bottom = top + height - 1,
    payload = payload,
  })
end

local function hit_at(left, top)
  for index = #hitboxes, 1, -1 do
    local hitbox = hitboxes[index]
    if left >= hitbox.left and left <= hitbox.right and top >= hitbox.top and top <= hitbox.bottom then
      return hitbox
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
  if not fs.exists(path) or fs.isDir(path) then
    return nil
  end
  local handle = fs.open(path, "r")
  if not handle then
    return nil
  end
  local data = handle.readAll()
  handle.close()
  return data or ""
end

local function path_join(base_path, child)
  base_path = tostring(base_path or "/")
  child = tostring(child or "")
  if base_path == "/" then
    return "/" .. child
  end
  return base_path:gsub("/+$", "") .. "/" .. child
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
  return tostring(path or ""):match("[^/]+$") or tostring(path or "")
end

local function list_dir(path)
  local entries = {}
  if not fs.exists(path) or not fs.isDir(path) then
    return entries
  end
  for _, name in ipairs(fs.list(path)) do
    local full_path = path_join(path, name)
    table.insert(entries, {
      name = name,
      path = full_path,
      dir = fs.isDir(full_path),
      size = fs.isDir(full_path) and "-" or tostring(fs.getSize(full_path) or 0),
    })
  end
  table.sort(entries, function(left_entry, right_entry)
    if left_entry.dir ~= right_entry.dir then
      return left_entry.dir
    end
    return left_entry.name:lower() < right_entry.name:lower()
  end)
  return entries
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

local function run_hidden(callback)
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

local function set_modal(title, body, buttons)
  state.modal = { title = title, body = body or {}, buttons = buttons or {} }
end

local function show_error(message)
  set_modal("Error", { tostring(message) }, {
    { label = "Close", action = "modal_close", color = THEME.button },
  })
end

local function finish_input(value)
  local input = state.input
  state.input = nil
  if input and input.callback then
    local ok, err = pcall(input.callback, value)
    if not ok then
      show_error(err)
    end
  end
end

local function cancel_input()
  state.input = nil
end

local function prompt_text(title, default, callback)
  state.modal = nil
  state.input = {
    title = title or "Input",
    value = tostring(default or ""),
    callback = callback,
  }
end

local function handle_input_event(event, first)
  if not state.input then
    return false
  end
  if event == "char" then
    state.input.value = tostring(state.input.value or "") .. tostring(first or "")
    return true
  elseif event == "paste" then
    state.input.value = tostring(state.input.value or "") .. tostring(first or "")
    return true
  elseif event == "key" then
    if first == keys.enter then
      finish_input(state.input.value or "")
    elseif first == keys.backspace then
      local value = tostring(state.input.value or "")
      state.input.value = value:sub(1, math.max(0, #value - 1))
    elseif keys.escape and first == keys.escape then
      cancel_input()
    end
    return true
  end
  return false
end

local function add_open_app(app_id)
  for _, existing_app_id in ipairs(state.open_dock_order) do
    if existing_app_id == app_id then
      return
    end
  end
  table.insert(state.open_dock_order, app_id)
end

local function remove_open_app_if_unused(app_id)
  for _, window_id in ipairs(state.window_order) do
    local window_state = state.windows[window_id]
    if window_state and window_state.app == app_id then
      return
    end
  end
  local next_order = {}
  for _, existing_app_id in ipairs(state.open_dock_order) do
    if existing_app_id ~= app_id then
      table.insert(next_order, existing_app_id)
    end
  end
  state.open_dock_order = next_order
end

local function move_open_app(app_id, target_app_id)
  if not app_id or app_id == target_app_id then
    return
  end
  local next_order = {}
  for _, existing_app_id in ipairs(state.open_dock_order) do
    if existing_app_id ~= app_id then
      table.insert(next_order, existing_app_id)
    end
  end
  local inserted = false
  if target_app_id then
    for index, existing_app_id in ipairs(next_order) do
      if existing_app_id == target_app_id then
        table.insert(next_order, index, app_id)
        inserted = true
        break
      end
    end
  end
  if not inserted then
    table.insert(next_order, app_id)
  end
  state.open_dock_order = next_order
end

local function is_open_dock_app(app_id)
  for _, existing_app_id in ipairs(state.open_dock_order) do
    if existing_app_id == app_id then
      return true
    end
  end
  return false
end

local function bring_to_front(window_id)
  if not state.windows[window_id] then
    return
  end
  local next_order = {}
  for _, existing_window_id in ipairs(state.window_order) do
    if existing_window_id ~= window_id then
      table.insert(next_order, existing_window_id)
    end
  end
  table.insert(next_order, window_id)
  state.window_order = next_order
  state.active_window = window_id
end

local function create_window(app_id, title, preferred_width, preferred_height)
  local screen_width, screen_height = screen_size()
  local window_id = state.next_window_id
  state.next_window_id = state.next_window_id + 1
  local window_width = math.min(preferred_width or 42, screen_width - 4)
  local window_height = math.min(preferred_height or 14, screen_height - 6)
  local offset = (#state.window_order % 4) * 2
  local window_state = {
    id = window_id,
    app = app_id,
    title = title,
    left = math.max(2, math.floor((screen_width - window_width) / 2) + 1 + offset),
    top = math.max(2, math.floor((screen_height - window_height) / 2) + 1 + offset),
    width = window_width,
    height = window_height,
    fullscreen = false,
    saved_rect = nil,
    data = {},
  }
  state.windows[window_id] = window_state
  table.insert(state.window_order, window_id)
  state.active_window = window_id
  add_open_app(app_id)
  return window_state
end

local function find_window_by_app(app_id)
  for index = #state.window_order, 1, -1 do
    local window_state = state.windows[state.window_order[index]]
    if window_state and window_state.app == app_id then
      return window_state
    end
  end
  return nil
end

local function close_window(window_id)
  local window_state = state.windows[window_id]
  if not window_state then
    return
  end
  state.windows[window_id] = nil
  local next_order = {}
  for _, existing_window_id in ipairs(state.window_order) do
    if existing_window_id ~= window_id then
      table.insert(next_order, existing_window_id)
    end
  end
  state.window_order = next_order
  if state.active_window == window_id then
    state.active_window = state.window_order[#state.window_order]
  end
  remove_open_app_if_unused(window_state.app)
end

local function toggle_fullscreen(window_state)
  local screen_width, screen_height = screen_size()
  if window_state.fullscreen then
    local saved = window_state.saved_rect
    if saved then
      window_state.left = saved.left
      window_state.top = saved.top
      window_state.width = saved.width
      window_state.height = saved.height
    end
    window_state.fullscreen = false
    window_state.saved_rect = nil
  else
    window_state.saved_rect = {
      left = window_state.left,
      top = window_state.top,
      width = window_state.width,
      height = window_state.height,
    }
    window_state.left = 1
    window_state.top = 2
    window_state.width = screen_width
    window_state.height = screen_height - 5
    window_state.fullscreen = true
  end
end

local function luma_installed()
  return fs.exists("/luma/luma.lua")
end

local function install_luma()
  state.toast = "Downloading Luma"
  draw()
  local body, err = download(LUMA_INSTALLER_URL)
  if not body then
    show_error("Download failed: " .. tostring(err))
    return
  end
  local installer_path = "/tmp/luma-installer.lua"
  local ok, write_err = write_file(installer_path, body)
  if not ok then
    show_error(write_err)
    return
  end
  state.toast = "Installing Luma"
  draw()
  local run_ok, run_err = run_hidden(function()
    if shell then
      return shell.run(installer_path, "--source", LUMA_SOURCE_URL)
    end
    return dofile(installer_path)
  end)
  if not run_ok then
    show_error("Install failed: " .. tostring(run_err))
    return
  end
  state.toast = "Luma installed"
end

local function open_luma()
  if not luma_installed() then
    state.toast = "Install Luma in Store"
    local store_window = find_window_by_app("store") or create_window("store", "Store", 46, 15)
    bring_to_front(store_window.id)
    return
  end
  add_open_app("luma")
  clear()
  if shell then
    shell.run("/bin/luma.lua")
  else
    dofile("/luma/luma.lua")
  end
  remove_open_app_if_unused("luma")
end

local function open_terminal()
  add_open_app("terminal")
  clear()
  if shell then
    shell.run("shell")
  end
  remove_open_app_if_unused("terminal")
end

local function open_app(app_id)
  if app_id == "luma" then
    open_luma()
    return
  elseif app_id == "terminal" then
    open_terminal()
    return
  end
  local existing_window = find_window_by_app(app_id)
  if existing_window then
    bring_to_front(existing_window.id)
    return
  end
  local app = APPS[app_id]
  if not app then
    return
  end
  local preferred_width = app_id == "finder" and 58 or app_id == "paint" and 54 or 46
  local preferred_height = app_id == "finder" and 17 or app_id == "paint" and 18 or 15
  create_window(app_id, app.name, preferred_width, preferred_height)
end

local function draw_button(action, left, top, label, payload, background)
  local width = #label + 2
  fill(left, top, width, 1, background or THEME.button)
  write_at(left + 1, top, label, colors.white, background or THEME.button)
  add_hit(action, left, top, width, 1, payload)
  return width
end

local function draw_menu_bar()
  local screen_width = screen_size()
  fill(1, 1, screen_width, 1, THEME.menubar)
  write_at(2, 1, "DockOS", colors.white, THEME.menubar)
  local active_title = "Desktop"
  if state.active_window and state.windows[state.active_window] then
    active_title = state.windows[state.active_window].title
  end
  write_at(10, 1, trim(active_title, 20), colors.white, THEME.menubar)
  local clock = textutils and textutils.formatTime and textutils.formatTime(os.time(), true) or ""
  if clock ~= "" then
    write_at(screen_width - #clock, 1, clock, colors.lightGray, THEME.menubar)
  end
end

local function draw_desktop()
  local desktop_icons = {
    { app = "finder", name = "Computer", icon = "HD" },
    { app = "store", name = "Store", icon = "ST" },
    { app = "docs", name = "Docs", icon = "DC" },
    { app = "paint", name = "Paint", icon = "PT" },
  }
  local left = 3
  local top = 3
  for _, item in ipairs(desktop_icons) do
    fill(left, top, 10, 3, colors.black)
    write_at(left + 3, top, item.icon, colors.white, colors.black)
    write_at(left, top + 1, trim(item.name, 10), colors.lightGray, colors.black)
    add_hit("desktop_app", left, top, 10, 3, item.app)
    top = top + 4
  end
end

local function dock_width()
  return (#PINNED * 5) + 3 + (#state.open_dock_order * 5)
end

local function draw_dock_icon(left, top, app_id, action)
  local app = APPS[app_id]
  if not app then
    return
  end
  fill(left, top, 4, 2, app.color)
  write_at(left + 1, top, app.icon, colors.white, app.color)
  if is_open_dock_app(app_id) then
    write_at(left + 1, top + 1, "  ", colors.white, colors.white)
  end
  add_hit(action, left, top, 4, 2, app_id)
end

local function draw_dock()
  local screen_width, screen_height = screen_size()
  local dock_top = screen_height - 2
  local total_width = math.min(screen_width - 2, dock_width())
  local left = math.max(2, math.floor((screen_width - total_width) / 2) + 1)
  fill(left - 1, dock_top - 1, total_width + 2, 3, THEME.dock_shadow)
  fill(left, dock_top, total_width, 3, THEME.dock)
  local cursor_left = left + 1
  for _, app_id in ipairs(PINNED) do
    draw_dock_icon(cursor_left, dock_top, app_id, "dock_pinned")
    cursor_left = cursor_left + 5
  end
  write_at(cursor_left, dock_top, "|", colors.lightGray, THEME.dock)
  add_hit("dock_drop_end", cursor_left, dock_top, 2, 2, nil)
  cursor_left = cursor_left + 3
  for _, app_id in ipairs(state.open_dock_order) do
    draw_dock_icon(cursor_left, dock_top, app_id, "dock_open")
    cursor_left = cursor_left + 5
  end
end

local function draw_window_frame(window_state)
  local active = state.active_window == window_state.id
  local title_color = active and THEME.window_title or THEME.window_inactive
  fill(window_state.left + 1, window_state.top + 1, window_state.width, window_state.height, colors.black)
  fill(window_state.left, window_state.top, window_state.width, window_state.height, THEME.window)
  fill(window_state.left, window_state.top, window_state.width, 1, title_color)
  add_hit("window_focus", window_state.left, window_state.top, window_state.width, window_state.height, window_state.id)
  write_at(window_state.left + 1, window_state.top, "x", colors.red, title_color)
  write_at(window_state.left + 3, window_state.top, "[]", colors.green, title_color)
  write_at(window_state.left + 7, window_state.top, trim(window_state.title, window_state.width - 8), colors.black, title_color)
  add_hit("window_close", window_state.left + 1, window_state.top, 1, 1, window_state.id)
  add_hit("window_fullscreen", window_state.left + 3, window_state.top, 2, 1, window_state.id)
  add_hit("window_drag", window_state.left + 6, window_state.top, window_state.width - 6, 1, window_state.id)
end

local function content_rect(window_state)
  return window_state.left + 1, window_state.top + 2, window_state.width - 2, window_state.height - 3
end

local function selected_file_entry()
  if state.file_selected and fs.exists(state.file_selected) then
    return {
      path = state.file_selected,
      name = basename(state.file_selected),
      dir = fs.isDir(state.file_selected),
    }
  end
  state.file_selected = nil
  return nil
end

local function open_selected_file()
  local entry = selected_file_entry()
  if not entry then
    return
  end
  if entry.dir then
    state.file_path = entry.path
    state.file_scroll = 0
    state.file_selected = nil
    state.file_preview = nil
  else
    state.file_preview = read_file(entry.path) or ""
  end
end

local function create_file(kind)
  local default_name = kind == "folder" and "New Folder" or "Untitled.txt"
  prompt_text(kind == "folder" and "New Folder" or "New File", default_name, function(name)
    if not name or name == "" then
      return
    end
    local new_path = path_join(state.file_path, name)
    if fs.exists(new_path) then
      state.toast = "Already exists"
      return
    end
    if kind == "folder" then
      fs.makeDir(new_path)
    else
      write_file(new_path, "")
    end
    state.file_selected = new_path
  end)
end

local function rename_selected_file()
  local entry = selected_file_entry()
  if not entry then
    return
  end
  prompt_text("Rename", entry.name, function(name)
    if not name or name == "" or name == entry.name then
      return
    end
    if not fs.exists(entry.path) then
      state.toast = "Missing file"
      return
    end
    local target_path = path_join(state.file_path, name)
    if fs.exists(target_path) then
      state.toast = "Already exists"
      return
    end
    fs.move(entry.path, target_path)
    state.file_selected = target_path
  end)
end

local function delete_selected_file()
  local entry = selected_file_entry()
  if not entry then
    return
  end
  set_modal("Delete", { entry.name }, {
    { label = "Delete", action = "file_delete_confirm", color = THEME.danger },
    { label = "Cancel", action = "modal_close", color = THEME.button },
  })
end

local function draw_finder(window_state)
  local left, top, width, height = content_rect(window_state)
  local toolbar_top = top
  local cursor_left = left + 1
  cursor_left = cursor_left + draw_button("file_back", cursor_left, toolbar_top, "<", nil, colors.gray) + 1
  cursor_left = cursor_left + draw_button("file_new_folder", cursor_left, toolbar_top, "Folder", nil, THEME.button) + 1
  cursor_left = cursor_left + draw_button("file_new_file", cursor_left, toolbar_top, "File", nil, THEME.button) + 1
  cursor_left = cursor_left + draw_button("file_rename", cursor_left, toolbar_top, "Rename", nil, colors.gray) + 1
  cursor_left = cursor_left + draw_button("file_delete", cursor_left, toolbar_top, "Delete", nil, THEME.danger) + 1
  draw_button("file_open", cursor_left, toolbar_top, "Open", nil, colors.purple)

  write_at(left + 1, top + 2, trim(state.file_path, width - 2), colors.cyan, THEME.window)
  local list_left = left + 1
  local list_top = top + 4
  local list_width = math.max(24, math.floor(width * 0.58))
  local preview_left = list_left + list_width + 2
  local preview_width = width - list_width - 4
  local visible_rows = height - 5
  fill(list_left, list_top, list_width, visible_rows + 1, THEME.field)
  fill(preview_left, list_top, preview_width, visible_rows + 1, THEME.field)
  write_at(list_left + 1, list_top, pad("Name", list_width - 14) .. "Kind  Size", colors.lightGray, THEME.field)

  local entries = list_dir(state.file_path)
  for row_index = 1, visible_rows do
    local entry = entries[row_index + state.file_scroll]
    if not entry then
      break
    end
    local row_top = list_top + row_index
    local selected = state.file_selected == entry.path
    local row_background = selected and THEME.selected or (row_index % 2 == 0 and colors.black or colors.gray)
    fill(list_left, row_top, list_width, 1, row_background)
    write_at(list_left + 1, row_top, pad(entry.name, list_width - 14), entry.dir and colors.cyan or colors.white, row_background)
    write_at(list_left + list_width - 12, row_top, entry.dir and "DIR " or "FILE", colors.lightGray, row_background)
    write_at(list_left + list_width - 6, row_top, trim(entry.size, 5), colors.lightGray, row_background)
    add_hit("file_select", list_left, row_top, list_width, 1, entry.path)
  end

  local entry = selected_file_entry()
  if entry then
    write_at(preview_left + 1, list_top, trim(entry.name, preview_width - 2), colors.white, THEME.field)
    write_at(preview_left + 1, list_top + 1, entry.dir and "Folder" or "File", colors.lightGray, THEME.field)
    if state.file_preview and not entry.dir then
      local preview_top = list_top + 3
      for line in (state.file_preview .. "\n"):gmatch("(.-)\n") do
        if preview_top >= list_top + visible_rows then
          break
        end
        write_at(preview_left + 1, preview_top, trim(line, preview_width - 2), colors.lightGray, THEME.field)
        preview_top = preview_top + 1
      end
    end
  end
end

local function docs_list()
  if not fs.exists(DOCS_DIR) then
    fs.makeDir(DOCS_DIR)
  end
  local docs = {}
  for _, name in ipairs(fs.list(DOCS_DIR)) do
    local doc_path = path_join(DOCS_DIR, name)
    if not fs.isDir(doc_path) then
      table.insert(docs, { name = name, path = doc_path })
    end
  end
  table.sort(docs, function(left_doc, right_doc)
    return left_doc.name:lower() < right_doc.name:lower()
  end)
  return docs
end

local function new_document()
  prompt_text("New Document", "Document.txt", function(name)
    if not name or name == "" then
      return
    end
    if not name:match("%.txt$") then
      name = name .. ".txt"
    end
    local doc_path = path_join(DOCS_DIR, name)
    if fs.exists(doc_path) then
      state.toast = "Already exists"
      return
    end
    prompt_text("Text", "", function(body)
      write_file(doc_path, body or "")
      state.docs_selected = doc_path
      state.docs_preview = body or ""
    end)
  end)
end

local function edit_document()
  if not state.docs_selected then
    return
  end
  local doc_path = state.docs_selected
  local current = read_file(state.docs_selected) or ""
  prompt_text("Edit", current, function(body)
    if body then
      write_file(doc_path, body)
      state.docs_preview = body
    end
  end)
end

local function print_document()
  if not state.docs_selected then
    return
  end
  local printer = peripheral and peripheral.find and peripheral.find("printer")
  if not printer then
    state.toast = "No printer"
    return
  end
  if printer.newPage and not printer.newPage() then
    state.toast = "Printer not ready"
    return
  end
  if printer.setPageTitle then
    printer.setPageTitle(basename(state.docs_selected))
  end
  local body = read_file(state.docs_selected) or ""
  local line_top = 1
  for line in (body .. "\n"):gmatch("(.-)\n") do
    if printer.setCursorPos then
      printer.setCursorPos(1, line_top)
    end
    if printer.write then
      printer.write(line)
    end
    line_top = line_top + 1
  end
  if printer.endPage then
    printer.endPage()
  end
  state.toast = "Printed"
end

local function draw_documents(window_state)
  local left, top, width, height = content_rect(window_state)
  local cursor_left = left + 1
  cursor_left = cursor_left + draw_button("doc_new", cursor_left, top, "New", nil, THEME.button) + 1
  cursor_left = cursor_left + draw_button("doc_edit", cursor_left, top, "Edit", nil, colors.gray) + 1
  cursor_left = cursor_left + draw_button("doc_print", cursor_left, top, "Print", nil, colors.purple) + 1
  draw_button("doc_delete", cursor_left, top, "Delete", nil, THEME.danger)

  local list_left = left + 1
  local list_top = top + 2
  local list_width = math.max(18, math.floor(width * 0.35))
  local preview_left = list_left + list_width + 2
  local preview_width = width - list_width - 4
  local visible_rows = height - 3
  fill(list_left, list_top, list_width, visible_rows, THEME.field)
  fill(preview_left, list_top, preview_width, visible_rows, THEME.field)

  for row_index, doc in ipairs(docs_list()) do
    if row_index > visible_rows then
      break
    end
    local selected = state.docs_selected == doc.path
    local row_background = selected and THEME.selected or THEME.field
    fill(list_left, list_top + row_index - 1, list_width, 1, row_background)
    write_at(list_left + 1, list_top + row_index - 1, trim(doc.name, list_width - 2), colors.white, row_background)
    add_hit("doc_select", list_left, list_top + row_index - 1, list_width, 1, doc.path)
  end

  if state.docs_selected then
    write_at(preview_left + 1, list_top, trim(basename(state.docs_selected), preview_width - 2), colors.white, THEME.field)
    local preview_top = list_top + 2
    local body = state.docs_preview ~= "" and state.docs_preview or read_file(state.docs_selected) or ""
    for line in (body .. "\n"):gmatch("(.-)\n") do
      if preview_top >= list_top + visible_rows then
        break
      end
      write_at(preview_left + 1, preview_top, trim(line, preview_width - 2), colors.lightGray, THEME.field)
      preview_top = preview_top + 1
    end
  end
end

local function init_paint()
  if not fs.exists(PAINT_DIR) then
    fs.makeDir(PAINT_DIR)
  end
  if not state.paint_cells then
    state.paint_cells = {}
  end
end

local function paint_key(col, row)
  return tostring(col) .. ":" .. tostring(row)
end

local function paint_cell(col, row)
  return state.paint_cells[paint_key(col, row)] or colors.black
end

local function set_paint_cell(col, row, color)
  state.paint_cells[paint_key(col, row)] = color
end

local function save_painting()
  init_paint()
  prompt_text("Save Painting", "Painting.txt", function(name)
    if not name or name == "" then
      return
    end
    if not name:match("%.txt$") then
      name = name .. ".txt"
    end
    local lines = {}
    for row = 1, 12 do
      local parts = {}
      for col = 1, 24 do
        table.insert(parts, tostring(paint_cell(col, row)))
      end
      table.insert(lines, table.concat(parts, ","))
    end
    write_file(path_join(PAINT_DIR, name), table.concat(lines, "\n"))
    state.toast = "Saved"
  end)
end

local function draw_paint(window_state)
  init_paint()
  local left, top, width = content_rect(window_state)
  local cursor_left = left + 1
  cursor_left = cursor_left + draw_button("paint_clear", cursor_left, top, "Clear", nil, colors.gray) + 1
  cursor_left = cursor_left + draw_button("paint_save", cursor_left, top, "Save", nil, THEME.button) + 1
  write_at(cursor_left, top, "Color", colors.lightGray, THEME.window)

  local palette = { colors.white, colors.lightGray, colors.gray, colors.black, colors.red, colors.orange, colors.yellow, colors.lime, colors.green, colors.cyan, colors.blue, colors.purple, colors.pink, colors.brown }
  local palette_left = left + 1
  local palette_top = top + 2
  for index, color in ipairs(palette) do
    local cell_left = palette_left + ((index - 1) % 7) * 3
    local cell_top = palette_top + math.floor((index - 1) / 7)
    fill(cell_left, cell_top, 2, 1, color)
    add_hit("paint_color", cell_left, cell_top, 2, 1, color)
  end

  local canvas_left = left + 1
  local canvas_top = top + 5
  local canvas_width = math.min(24, width - 2)
  local canvas_height = 12
  for row = 1, canvas_height do
    for col = 1, canvas_width do
      fill(canvas_left + col - 1, canvas_top + row - 1, 1, 1, paint_cell(col, row))
      add_hit("paint_cell", canvas_left + col - 1, canvas_top + row - 1, 1, 1, { col = col, row = row })
    end
  end
end

local function trust_color(app)
  if app.trust == "verified" or app.trust == "built-in" then
    return THEME.success
  end
  return THEME.warning
end

local function draw_store(window_state)
  local left, top, width = content_rect(window_state)
  local row_top = top
  for _, app in ipairs(STORE_APPS) do
    if row_top + 4 >= top + window_state.height - 3 then
      break
    end
    fill(left + 1, row_top, width - 2, 4, THEME.field)
    fill(left + 1, row_top, 2, 4, trust_color(app))
    write_at(left + 4, row_top, trim(app.name, width - 18), colors.white, THEME.field)
    write_at(left + 4, row_top + 1, trim(app.description, width - 8), colors.lightGray, THEME.field)
    write_at(left + 4, row_top + 2, string.upper(app.trust), trust_color(app), THEME.field)
    local built_in = app.trust == "built-in"
    local installed = built_in or app.id == "luma" and luma_installed()
    local label = installed and "Open" or "Install"
    draw_button(installed and "store_open" or "store_install", left + width - 11, row_top + 1, label, app, installed and colors.purple or THEME.button)
    row_top = row_top + 5
  end
end

local function directgpu_connect()
  local gpu = peripheral and peripheral.find and peripheral.find("directgpu")
  if not gpu then
    state.settings_message = "DirectGPU not found"
    return
  end
  local ok, display_id = pcall(function()
    if gpu.autoDetectAndCreateDisplay then
      return gpu.autoDetectAndCreateDisplay()
    end
    return nil
  end)
  if not ok or not display_id then
    state.settings_message = "No GPU display"
    return
  end
  state.directgpu = { gpu = gpu, display = display_id }
  state.settings_message = "DirectGPU display connected"
  pcall(function()
    gpu.clear(display_id, 20, 20, 28)
    gpu.fillRect(display_id, 20, 20, 260, 80, 45, 45, 55)
    gpu.drawText(display_id, "DockOS", 35, 38, 255, 255, 255, "Arial", 28, "bold")
    gpu.drawText(display_id, "External display connected", 35, 72, 120, 220, 255, "Arial", 16, "plain")
    gpu.updateDisplay(display_id)
  end)
end

local function monitor_connect()
  local monitor = peripheral and peripheral.find and peripheral.find("monitor")
  if not monitor then
    state.settings_message = "Monitor not found"
    return
  end
  monitor.setTextScale(0.5)
  monitor.setBackgroundColor(colors.black)
  monitor.setTextColor(colors.white)
  monitor.clear()
  monitor.setCursorPos(2, 2)
  monitor.write("DockOS display")
  state.settings_message = "Monitor connected"
end

local function speaker_test()
  local speaker = peripheral and peripheral.find and peripheral.find("speaker")
  if not speaker then
    state.settings_message = "Speaker not found"
    return
  end
  if speaker.playNote then
    speaker.playNote("pling", 1, 12)
  elseif speaker.playSound then
    speaker.playSound("minecraft:block.note_block.pling")
  end
  state.settings_message = "Speaker test sent"
end

local function printer_test()
  local printer = peripheral and peripheral.find and peripheral.find("printer")
  if not printer then
    state.settings_message = "Printer not found"
    return
  end
  state.settings_message = "Printer connected"
end

local function peripheral_rows()
  local rows = {}
  if peripheral then
    for _, name in ipairs(peripheral.getNames()) do
      table.insert(rows, { name = name, kind = peripheral.getType(name) or "unknown" })
    end
  end
  table.sort(rows, function(left_row, right_row)
    return left_row.name < right_row.name
  end)
  return rows
end

local function draw_settings(window_state)
  local left, top, width, height = content_rect(window_state)
  local cursor_left = left + 1
  cursor_left = cursor_left + draw_button("settings_gpu", cursor_left, top, "Rescan", nil, THEME.button) + 1
  cursor_left = cursor_left + draw_button("settings_monitor", cursor_left, top, "Display", nil, colors.gray) + 1
  cursor_left = cursor_left + draw_button("settings_speaker", cursor_left, top, "Speaker", nil, colors.gray) + 1
  draw_button("settings_printer", cursor_left, top, "Printer", nil, colors.gray)
  write_at(left + 1, top + 2, trim(state.settings_message, width - 2), colors.cyan, THEME.window)
  write_at(left + 1, top + 4, "Peripherals", colors.white, THEME.window)
  local row_top = top + 6
  for _, row in ipairs(peripheral_rows()) do
    if row_top >= top + height then
      break
    end
    write_at(left + 1, row_top, pad(row.name, 18), colors.white, THEME.window)
    write_at(left + 21, row_top, trim(row.kind, width - 22), colors.lightGray, THEME.window)
    row_top = row_top + 1
  end
end

local function draw_window_content(window_state)
  if window_state.app == "finder" then
    draw_finder(window_state)
  elseif window_state.app == "store" then
    draw_store(window_state)
  elseif window_state.app == "docs" then
    draw_documents(window_state)
  elseif window_state.app == "paint" then
    draw_paint(window_state)
  elseif window_state.app == "settings" then
    draw_settings(window_state)
  end
end

local function draw_windows()
  for _, window_id in ipairs(state.window_order) do
    local window_state = state.windows[window_id]
    if window_state then
      draw_window_frame(window_state)
      draw_window_content(window_state)
    end
  end
end

local function draw_toast()
  if not state.toast or state.toast == "" then
    return
  end
  local screen_width, screen_height = screen_size()
  local text = trim(state.toast, screen_width - 12)
  local left = math.max(2, screen_width - #text - 3)
  fill(left, screen_height - 4, #text + 2, 1, colors.black)
  write_at(left + 1, screen_height - 4, text, colors.cyan, colors.black)
end

local function draw_modal()
  if not state.modal then
    return
  end
  local screen_width, screen_height = screen_size()
  local modal_width = math.min(screen_width - 8, 40)
  local modal_height = 7 + #(state.modal.body or {})
  local left = math.floor((screen_width - modal_width) / 2) + 1
  local top = math.floor((screen_height - modal_height) / 2) + 1
  fill(left + 1, top + 1, modal_width, modal_height, colors.black)
  fill(left, top, modal_width, modal_height, THEME.surface)
  fill(left, top, modal_width, 1, THEME.accent)
  write_at(left + 1, top, trim(state.modal.title, modal_width - 2), colors.black, THEME.accent)
  for index, line in ipairs(state.modal.body or {}) do
    write_at(left + 2, top + 1 + index, trim(line, modal_width - 4), colors.white, THEME.surface)
  end
  local cursor_left = left + 2
  local button_top = top + modal_height - 2
  for _, button in ipairs(state.modal.buttons or {}) do
    cursor_left = cursor_left + draw_button(button.action, cursor_left, button_top, button.label, button.payload, button.color) + 2
  end
end

local function draw_input()
  if not state.input then
    return
  end
  local screen_width, screen_height = screen_size()
  local modal_width = math.min(screen_width - 8, 46)
  local modal_height = 7
  local left = math.floor((screen_width - modal_width) / 2) + 1
  local top = math.floor((screen_height - modal_height) / 2) + 1
  local field_width = modal_width - 4
  local value = tostring(state.input.value or "")
  local visible_value = value
  if #visible_value > field_width - 1 then
    visible_value = visible_value:sub(#visible_value - field_width + 2)
  end

  fill(left + 1, top + 1, modal_width, modal_height, colors.black)
  fill(left, top, modal_width, modal_height, THEME.surface)
  fill(left, top, modal_width, 1, THEME.accent)
  write_at(left + 1, top, trim(state.input.title, modal_width - 2), colors.black, THEME.accent)
  fill(left + 2, top + 2, field_width, 1, THEME.field)
  write_at(left + 2, top + 2, pad(visible_value .. "_", field_width), colors.white, THEME.field)
  local cursor_left = left + 2
  local button_top = top + modal_height - 2
  cursor_left = cursor_left + draw_button("input_ok", cursor_left, button_top, "OK", nil, THEME.button) + 2
  draw_button("input_cancel", cursor_left, button_top, "Cancel", nil, colors.gray)
end

local function color_rgb(color)
  local map = {
    [colors.white] = { 245, 245, 245 },
    [colors.orange] = { 255, 149, 0 },
    [colors.magenta] = { 255, 45, 180 },
    [colors.lightBlue] = { 90, 180, 255 },
    [colors.yellow] = { 255, 214, 10 },
    [colors.lime] = { 50, 215, 75 },
    [colors.pink] = { 255, 55, 95 },
    [colors.gray] = { 92, 92, 96 },
    [colors.lightGray] = { 180, 180, 188 },
    [colors.cyan] = { 90, 200, 250 },
    [colors.purple] = { 191, 90, 242 },
    [colors.blue] = { 10, 132, 255 },
    [colors.brown] = { 162, 132, 94 },
    [colors.green] = { 48, 209, 88 },
    [colors.red] = { 255, 69, 58 },
    [colors.black] = { 28, 28, 30 },
  }
  return map[color] or map[colors.white]
end

local function gpu_rect(gpu, display, left, top, width, height, color)
  local rgb = color_rgb(color)
  if gpu.fillRect then
    gpu.fillRect(display, left, top, width, height, rgb[1], rgb[2], rgb[3])
  end
end

local function gpu_text(gpu, display, text, left, top, color, size, style)
  local rgb = color_rgb(color)
  if gpu.drawText then
    gpu.drawText(display, tostring(text or ""), left, top, rgb[1], rgb[2], rgb[3], "Arial", size or 14, style or "bold")
  end
end

local function color_argb(color)
  local rgb = color_rgb(color)
  local value = 4278190080 + rgb[1] * 65536 + rgb[2] * 256 + rgb[3]
  if value > 2147483647 then
    return value - 4294967296
  end
  return value
end

local function peripheral_type_text(name)
  if not peripheral or not peripheral.getType then
    return ""
  end
  local ok, kind = pcall(peripheral.getType, name)
  if not ok or not kind then
    return ""
  end
  if type(kind) == "table" then
    return table.concat(kind, ",")
  end
  return tostring(kind)
end

local function find_peripheral(predicate)
  if not peripheral or not peripheral.getNames or not peripheral.wrap then
    return nil, nil
  end
  for _, name in ipairs(peripheral.getNames()) do
    local device = peripheral.wrap(name)
    local kind = peripheral_type_text(name):lower()
    if device and predicate(name, device, kind) then
      return name, device
    end
  end
  return nil, nil
end

local function is_tom_gpu(_, device, kind)
  if type(device.refreshSize) == "function" and type(device.sync) == "function" then
    return type(device.filledRectangle) == "function" or type(device.drawText) == "function" or type(device.fill) == "function"
  end
  return kind:find("gpu", 1, true) and type(device.filledRectangle) == "function"
end

local function is_tom_keyboard(_, device, kind)
  return type(device.setFireNativeEvents) == "function" or kind:find("keyboard", 1, true) ~= nil
end

local function is_external_monitor(_, device, kind)
  return kind:find("monitor", 1, true) ~= nil and type(device.setFireNativeEvents) ~= "function"
end

local function refresh_external_size()
  local gpu = state.external.gpu
  local pixel_width = DEFAULT_EXTERNAL_WIDTH * CELL_WIDTH
  local pixel_height = DEFAULT_EXTERNAL_HEIGHT * CELL_HEIGHT
  if gpu then
    if gpu.refreshSize then
      pcall(gpu.refreshSize)
    end
    if gpu.getSize then
      local ok, width, height = pcall(function()
        return gpu.getSize()
      end)
      if ok and type(width) == "number" and type(height) == "number" and width > 0 and height > 0 then
        pixel_width = width
        pixel_height = height
      end
    end
  end

  state.external.pixel_width = math.max(CELL_WIDTH * 40, math.floor(pixel_width))
  state.external.pixel_height = math.max(CELL_HEIGHT * 18, math.floor(pixel_height))
  state.virtual_width = math.max(40, math.floor(state.external.pixel_width / state.external.cell_width))
  state.virtual_height = math.max(18, math.floor(state.external.pixel_height / state.external.cell_height))
end

local function scan_external_peripherals()
  local gpu_name, gpu = find_peripheral(is_tom_gpu)
  state.external.gpu_name = gpu_name
  state.external.gpu = gpu

  local keyboard_name, keyboard = find_peripheral(is_tom_keyboard)
  state.external.keyboard_name = keyboard_name
  state.external.keyboard = keyboard
  if keyboard and keyboard.setFireNativeEvents then
    pcall(keyboard.setFireNativeEvents, true)
  end

  local monitor_name, monitor = find_peripheral(is_external_monitor)
  state.external.monitor_name = monitor_name
  state.external.monitor = monitor

  refresh_external_size()

  local parts = {}
  table.insert(parts, gpu_name and ("GPU " .. gpu_name) or "GPU waiting")
  table.insert(parts, keyboard_name and ("Keyboard " .. keyboard_name) or "Keyboard waiting")
  table.insert(parts, monitor_name and ("Monitor " .. monitor_name) or "Monitor waiting")
  state.settings_message = table.concat(parts, " | ")
end

local function start_peripheral_scan_timer()
  if os and os.startTimer then
    state.peripheral_scan_timer = os.startTimer(PERIPHERAL_SCAN_SECONDS)
  end
end

local function tom_fill_rect(gpu, left, top, width, height, color)
  if width <= 0 or height <= 0 then
    return
  end
  if gpu.filledRectangle then
    gpu.filledRectangle(left, top, width, height, color_argb(color))
  end
end

local function tom_draw_text(gpu, left, top, text, foreground, background)
  if not gpu.drawText then
    return
  end
  local bg = background and color_argb(background) or 0
  gpu.drawText(left, top, tostring(text or ""), color_argb(foreground or colors.white), bg, 10, 0)
end

local function render_tom_gpu()
  local gpu = state.external.gpu
  if not state.headless or not gpu then
    return
  end
  pcall(function()
    if gpu.fill then
      gpu.fill(color_argb(THEME.desktop))
    elseif gpu.filledRectangle then
      gpu.filledRectangle(0, 0, state.external.pixel_width, state.external.pixel_height, color_argb(THEME.desktop))
    end
    for _, op in ipairs(state.frame_ops or {}) do
      local pixel_left = (op.left - 1) * state.external.cell_width
      local pixel_top = (op.top - 1) * state.external.cell_height
      if op.kind == "fill" then
        tom_fill_rect(
          gpu,
          pixel_left,
          pixel_top,
          op.width * state.external.cell_width,
          op.height * state.external.cell_height,
          op.background
        )
      elseif op.kind == "text" then
        tom_draw_text(gpu, pixel_left, pixel_top, op.text, op.foreground, op.background)
      end
    end
    if gpu.sync then
      gpu.sync()
    end
  end)
end

local function draw_directgpu()
  if not state.directgpu or not state.directgpu.gpu or not state.directgpu.display then
    return
  end
  local gpu = state.directgpu.gpu
  local display = state.directgpu.display
  pcall(function()
    if gpu.clear then
      gpu.clear(display, 18, 18, 28)
    end
    gpu_rect(gpu, display, 0, 0, 640, 28, colors.gray)
    gpu_text(gpu, display, "DockOS", 18, 6, colors.white, 16, "bold")
    local active_title = "Desktop"
    if state.active_window and state.windows[state.active_window] then
      active_title = state.windows[state.active_window].title
    end
    gpu_text(gpu, display, active_title, 110, 7, colors.lightGray, 14, "bold")

    for _, window_id in ipairs(state.window_order) do
      local window_state = state.windows[window_id]
      if window_state then
        local pixel_left = (window_state.left - 1) * 10
        local pixel_top = (window_state.top - 1) * 14
        local pixel_width = window_state.width * 10
        local pixel_height = window_state.height * 14
        gpu_rect(gpu, display, pixel_left + 6, pixel_top + 8, pixel_width, pixel_height, colors.black)
        gpu_rect(gpu, display, pixel_left, pixel_top, pixel_width, pixel_height, colors.black)
        gpu_rect(gpu, display, pixel_left, pixel_top, pixel_width, 24, window_state.id == state.active_window and colors.lightGray or colors.gray)
        gpu_text(gpu, display, window_state.title, pixel_left + 18, pixel_top + 5, colors.black, 13, "bold")
      end
    end

    local dock_width_pixels = math.min(580, (#PINNED + #state.open_dock_order) * 42 + 28)
    local dock_left = math.floor((640 - dock_width_pixels) / 2)
    local dock_top = 320
    gpu_rect(gpu, display, dock_left + 6, dock_top + 6, dock_width_pixels, 48, colors.black)
    gpu_rect(gpu, display, dock_left, dock_top, dock_width_pixels, 48, colors.gray)
    local cursor_left = dock_left + 12
    for _, app_id in ipairs(PINNED) do
      local app = APPS[app_id]
      gpu_rect(gpu, display, cursor_left, dock_top + 8, 30, 30, app.color)
      gpu_text(gpu, display, app.icon, cursor_left + 5, dock_top + 13, colors.white, 12, "bold")
      cursor_left = cursor_left + 38
    end
    gpu_text(gpu, display, "|", cursor_left, dock_top + 10, colors.lightGray, 18, "bold")
    cursor_left = cursor_left + 22
    for _, app_id in ipairs(state.open_dock_order) do
      local app = APPS[app_id]
      if app then
        gpu_rect(gpu, display, cursor_left, dock_top + 8, 30, 30, app.color)
        gpu_text(gpu, display, app.icon, cursor_left + 5, dock_top + 13, colors.white, 12, "bold")
        cursor_left = cursor_left + 38
      end
    end

    if gpu.updateDisplay then
      gpu.updateDisplay(display)
    end
  end)
end

function draw()
  hitboxes = {}
  local screen_width, screen_height = screen_size()
  clear()
  fill(1, 1, screen_width, screen_height, THEME.desktop)
  draw_menu_bar()
  draw_desktop()
  draw_windows()
  draw_dock()
  draw_toast()
  draw_modal()
  draw_input()
  if state.headless then
    render_tom_gpu()
  else
    draw_directgpu()
  end
end

local function handle_action(action, payload, mouse_left, mouse_top)
  if action == "modal_close" then
    state.modal = nil
  elseif action == "input_ok" then
    finish_input(state.input and state.input.value or "")
  elseif action == "input_cancel" then
    cancel_input()
  elseif action == "desktop_app" or action == "dock_pinned" then
    open_app(payload)
  elseif action == "dock_open" then
    state.dragging_dock_app = payload
    local existing_window = find_window_by_app(payload)
    if existing_window then
      bring_to_front(existing_window.id)
    end
  elseif action == "dock_drop_end" and state.dragging_dock_app then
    move_open_app(state.dragging_dock_app, nil)
    state.dragging_dock_app = nil
  elseif action == "window_focus" then
    bring_to_front(payload)
  elseif action == "window_close" then
    close_window(payload)
  elseif action == "window_fullscreen" then
    local window_state = state.windows[payload]
    if window_state then
      toggle_fullscreen(window_state)
      bring_to_front(payload)
    end
  elseif action == "window_drag" then
    local window_state = state.windows[payload]
    if window_state and not window_state.fullscreen then
      state.dragging_window = {
        id = payload,
        start_left = window_state.left,
        start_top = window_state.top,
        mouse_left = mouse_left,
        mouse_top = mouse_top,
      }
      bring_to_front(payload)
    end
  elseif action == "store_install" then
    if payload.id == "luma" then
      install_luma()
    end
  elseif action == "store_open" then
    open_app(payload.id)
  elseif action == "file_select" then
    if state.file_selected == payload then
      open_selected_file()
    else
      state.file_selected = payload
      state.file_preview = nil
    end
  elseif action == "file_back" then
    state.file_path = parent_path(state.file_path)
    state.file_selected = nil
    state.file_scroll = 0
    state.file_preview = nil
  elseif action == "file_new_folder" then
    create_file("folder")
  elseif action == "file_new_file" then
    create_file("file")
  elseif action == "file_rename" then
    rename_selected_file()
  elseif action == "file_delete" then
    delete_selected_file()
  elseif action == "file_open" then
    open_selected_file()
  elseif action == "file_delete_confirm" then
    local entry = selected_file_entry()
    if entry then
      fs.delete(entry.path)
      state.file_selected = nil
      state.file_preview = nil
    end
    state.modal = nil
  elseif action == "doc_select" then
    state.docs_selected = payload
    state.docs_preview = read_file(payload) or ""
  elseif action == "doc_new" then
    new_document()
  elseif action == "doc_edit" then
    edit_document()
  elseif action == "doc_print" then
    print_document()
  elseif action == "doc_delete" and state.docs_selected then
    fs.delete(state.docs_selected)
    state.docs_selected = nil
    state.docs_preview = ""
  elseif action == "paint_color" then
    state.paint_color = payload
  elseif action == "paint_cell" then
    set_paint_cell(payload.col, payload.row, state.paint_color)
  elseif action == "paint_clear" then
    state.paint_cells = {}
  elseif action == "paint_save" then
    save_painting()
  elseif action == "settings_gpu" then
    scan_external_peripherals()
  elseif action == "settings_monitor" then
    scan_external_peripherals()
  elseif action == "settings_speaker" then
    speaker_test()
  elseif action == "settings_printer" then
    printer_test()
  end
end

local function pixel_to_cell(pixel_left, pixel_top)
  local left = math.floor((tonumber(pixel_left) or 0) / state.external.cell_width) + 1
  local top = math.floor((tonumber(pixel_top) or 0) / state.external.cell_height) + 1
  left = math.max(1, math.min(state.virtual_width, left))
  top = math.max(1, math.min(state.virtual_height, top))
  return left, top
end

local function monitor_event_pixels(first, second, third, fourth)
  if type(first) == "number" and type(second) == "number" then
    return first, second, third
  end
  if type(second) == "number" and type(third) == "number" then
    return second, third, fourth
  end
  return 0, 0, third
end

local function normalize_external_event(event, first, second, third, fourth)
  if event == "tm_keyboard_key" then
    return "key", second, third
  elseif event == "tm_keyboard_key_up" then
    return "key_up", second
  elseif event == "tm_keyboard_char" then
    return "char", second
  elseif event == "tm_keyboard_paste" then
    return "paste", second
  elseif event == "tm_monitor_mouse_click" then
    local pixel_left, pixel_top, button = monitor_event_pixels(first, second, third, fourth)
    local left, top = pixel_to_cell(pixel_left, pixel_top)
    return "mouse_click", button or 1, left, top
  elseif event == "tm_monitor_mouse_up" then
    local pixel_left, pixel_top, button = monitor_event_pixels(first, second, third, fourth)
    local left, top = pixel_to_cell(pixel_left, pixel_top)
    return "mouse_up", button or 1, left, top
  elseif event == "tm_monitor_mouse_scroll" then
    local pixel_left, pixel_top, direction = monitor_event_pixels(first, second, third, fourth)
    local left, top = pixel_to_cell(pixel_left, pixel_top)
    return "mouse_scroll", direction or 0, left, top
  elseif event == "tm_monitor_mouse_drag" then
    local pixel_left, pixel_top = monitor_event_pixels(first, second, third, fourth)
    local left, top = pixel_to_cell(pixel_left, pixel_top)
    return "mouse_drag", 1, left, top
  elseif event == "tm_monitor_touch" then
    local pixel_left, pixel_top = monitor_event_pixels(first, second, third, fourth)
    local left, top = pixel_to_cell(pixel_left, pixel_top)
    return "mouse_click", 1, left, top
  end
  return event, first, second, third
end

local function run_loop()
  state.headless = true
  blank_terminal()
  scan_external_peripherals()
  start_peripheral_scan_timer()
  while true do
    draw()
    local event, first, second, third, fourth = os.pullEvent()
    event, first, second, third = normalize_external_event(event, first, second, third, fourth)
    if event == "mouse_click" then
      local hitbox = hit_at(second, third)
      if hitbox and (not state.input or hitbox.id == "input_ok" or hitbox.id == "input_cancel") then
        handle_action(hitbox.id, hitbox.payload, second, third)
      end
    elseif event == "mouse_drag" and state.dragging_window then
      local window_state = state.windows[state.dragging_window.id]
      if window_state then
        window_state.left = math.max(1, state.dragging_window.start_left + second - state.dragging_window.mouse_left)
        window_state.top = math.max(2, state.dragging_window.start_top + third - state.dragging_window.mouse_top)
      end
    elseif event == "mouse_up" then
      local hitbox = hit_at(second, third)
      if state.dragging_dock_app then
        if hitbox and hitbox.id == "dock_open" then
          move_open_app(state.dragging_dock_app, hitbox.payload)
        elseif hitbox and hitbox.id == "dock_drop_end" then
          move_open_app(state.dragging_dock_app, nil)
        end
      end
      state.dragging_window = nil
      state.dragging_dock_app = nil
    elseif event == "mouse_scroll" then
      local active_window = state.windows[state.active_window]
      if active_window and active_window.app == "finder" then
        state.file_scroll = math.max(0, state.file_scroll + first)
      end
    elseif event == "timer" and first == state.peripheral_scan_timer then
      scan_external_peripherals()
      start_peripheral_scan_timer()
    elseif event == "peripheral" or event == "peripheral_detach" then
      scan_external_peripherals()
    elseif event == "key" then
      if handle_input_event(event, first) then
        -- input consumed
      elseif first == keys.q then
        blank_terminal()
        return
      elseif first == keys.backspace then
        state.modal = nil
      elseif first == keys.enter then
        local active_window = state.windows[state.active_window]
        if active_window and active_window.app == "finder" then
          open_selected_file()
        end
      elseif first == keys.delete then
        local active_window = state.windows[state.active_window]
        if active_window and active_window.app == "finder" then
          delete_selected_file()
        end
      end
    elseif event == "char" or event == "paste" then
      handle_input_event(event, first)
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

local function install_from_store(app_id)
  if app_id == "luma" then
    install_luma()
  elseif app_id == "docs" or app_id == "paint" then
    print("OK built-in")
  else
    print("ERR app not found: " .. tostring(app_id))
  end
end

local command = args[1] or "home"

if command == "home" or command == "ui" then
  run_loop()
elseif command == "store" and args[2] == "install" and args[3] then
  install_from_store(args[3])
elseif command == "store" then
  open_app("store")
  run_loop()
elseif command == "files" then
  open_app("finder")
  run_loop()
elseif command == "apps" then
  print_apps()
elseif command == "version" then
  print(VERSION)
else
  run_loop()
end
