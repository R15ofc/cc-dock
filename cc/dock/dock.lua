local VERSION = "1.2.9"
local RELEASE_NAME = "Kyrenia"
local DISPLAY_VERSION = "DockOS " .. RELEASE_NAME .. " " .. VERSION
local DOCS_DIR = "/dock/documents"
local PAINT_DIR = "/dock/paintings"
local ASSETS_DIR = "/dock/assets"
local CONFIG_PATH = "/dock/config.txt"
local LUMA_SITES_PATH = "/dock/luma-sites.txt"

local args = { ... }
local unpacker = table.unpack or unpack
local IMAGE_FILE_READ_CHUNK = 4096
local IMAGE_BUFFER_WRITE_CHUNK = 512
local DEFAULT_TIMEZONE_OFFSET = 3
local MIN_TIMEZONE_OFFSET = -12
local MAX_TIMEZONE_OFFSET = 14
local CUBE_TRIANGLES = "000010110;000110100;101111011;101011001;100110111;100111101;001011010;001010000;010011111;010111110;101001000;101000100"

local DEFAULT_EXTERNAL_WIDTH = 80
local DEFAULT_EXTERNAL_HEIGHT = 30
local CELL_WIDTH = 6
local CELL_HEIGHT = 9
local PERIPHERAL_SCAN_SECONDS = 1
local TARGET_3X6_WIDTH = 384
local TARGET_3X6_HEIGHT = 192
local DOCK_LEFT_PIXELS = 32
local DOCK_BOTTOM_PIXELS = 34
local DOCK_BUTTON_PIXELS = 24
local DOCK_ICON_PIXELS = 24
local DOCK_GAP_PIXELS = 6

local THEME = {
  desktop = colors.black,
  menubar = colors.black,
  dock = colors.gray,
  dock_shadow = colors.black,
  window = colors.black,
  window_title = colors.gray,
  window_inactive = colors.black,
  surface = colors.gray,
  field = colors.black,
  text = colors.white,
  muted = colors.lightGray,
  accent = colors.orange,
  selected = colors.orange,
  button = colors.orange,
  danger = colors.red,
  warning = colors.yellow,
  success = colors.lime,
}

local THEME_PRESETS = {
  linux = {
    id = "linux",
    name = "Linux",
    color = colors.orange,
    values = {
      desktop = colors.black,
      menubar = colors.black,
      dock = colors.gray,
      dock_shadow = colors.black,
      window = colors.black,
      window_title = colors.gray,
      window_inactive = colors.black,
      surface = colors.gray,
      field = colors.black,
      text = colors.white,
      muted = colors.lightGray,
      accent = colors.orange,
      selected = colors.orange,
      button = colors.orange,
      danger = colors.red,
      warning = colors.yellow,
      success = colors.lime,
    },
  },
  win10 = {
    id = "win10",
    name = "Win10",
    color = colors.blue,
    values = {
      desktop = colors.black,
      menubar = colors.black,
      dock = colors.black,
      dock_shadow = colors.black,
      window = colors.black,
      window_title = colors.blue,
      window_inactive = colors.gray,
      surface = colors.gray,
      field = colors.black,
      text = colors.white,
      muted = colors.lightGray,
      accent = colors.lightBlue,
      selected = colors.blue,
      button = colors.blue,
      danger = colors.red,
      warning = colors.orange,
      success = colors.lime,
    },
  },
  dark = {
    id = "dark",
    name = "Dark",
    color = colors.gray,
    values = {
      desktop = colors.black,
      menubar = colors.black,
      dock = colors.black,
      dock_shadow = colors.black,
      window = colors.black,
      window_title = colors.gray,
      window_inactive = colors.gray,
      surface = colors.gray,
      field = colors.black,
      text = colors.white,
      muted = colors.lightGray,
      accent = colors.cyan,
      selected = colors.gray,
      button = colors.gray,
      danger = colors.red,
      warning = colors.orange,
      success = colors.lime,
    },
  },
  forest = {
    id = "forest",
    name = "Forest",
    color = colors.green,
    values = {
      desktop = colors.black,
      menubar = colors.black,
      dock = colors.black,
      dock_shadow = colors.black,
      window = colors.black,
      window_title = colors.green,
      window_inactive = colors.gray,
      surface = colors.gray,
      field = colors.black,
      text = colors.white,
      muted = colors.lightGray,
      accent = colors.lime,
      selected = colors.green,
      button = colors.green,
      danger = colors.red,
      warning = colors.orange,
      success = colors.lime,
    },
  },
  purple = {
    id = "purple",
    name = "Purple",
    color = colors.purple,
    values = {
      desktop = colors.black,
      menubar = colors.black,
      dock = colors.black,
      dock_shadow = colors.black,
      window = colors.black,
      window_title = colors.purple,
      window_inactive = colors.gray,
      surface = colors.gray,
      field = colors.black,
      text = colors.white,
      muted = colors.lightGray,
      accent = colors.pink,
      selected = colors.purple,
      button = colors.purple,
      danger = colors.red,
      warning = colors.orange,
      success = colors.lime,
    },
  },
}

local THEME_ORDER = { "linux", "dark", "forest", "purple", "win10" }
local SETTINGS_TABS = {
  { id = "general", label = "General" },
  { id = "theme", label = "Theme" },
  { id = "time", label = "Time" },
  { id = "devices", label = "Devices" },
  { id = "privacy", label = "Privacy" },
  { id = "power", label = "Power" },
}

local APPS = {
  launcher = { id = "launcher", name = "Apps", icon = "D", icon_asset = "dock_tile", color = colors.lightGray },
  finder = { id = "finder", name = "Files", icon = "FS", icon_asset = "folder_tile", color = colors.blue },
  store = { id = "store", name = "Store", icon = "ST", icon_asset = "store_tile", color = colors.cyan },
  docs = { id = "docs", name = "Docs", icon = "DC", icon_asset = "docs_tile", color = colors.orange },
  paint = { id = "paint", name = "Paint", icon = "PT", icon_asset = "paint_tile", color = colors.pink },
  settings = { id = "settings", name = "Settings", icon = "SG", icon_asset = "settings_tile", color = colors.orange },
  blend = { id = "blend", name = "Blend", icon = "3D", icon_asset = "blend_tile", color = colors.orange },
  luma = { id = "luma", name = "Luma", icon = "LM", icon_asset = "luma_tile", color = colors.purple },
  studio = { id = "studio", name = "App Studio", icon = "AS", icon_asset = "studio_tile", color = colors.lightBlue },
  terminal = { id = "terminal", name = "Terminal", icon = ">_", icon_asset = "terminal_tile", color = colors.green },
}

local PINNED = { "launcher", "finder", "store", "luma", "docs", "paint", "blend", "settings", "terminal" }

local STORE_APPS = {
  { id = "docs", name = "Docs", trust = "built-in", popular = true, description = "Write documents and print them." },
  { id = "paint", name = "Paint", trust = "built-in", popular = true, description = "Draw images on a wide canvas." },
  { id = "blend", name = "Blend", trust = "built-in", popular = true, description = "Model blocky 3D scenes and preview renders." },
  { id = "studio", name = "App Studio", trust = "built-in", popular = true, description = "Build apps with code, components, and live preview." },
  { id = "finder", name = "Files", trust = "built-in", description = "Browse, create, rename, and delete files." },
  { id = "terminal", name = "Terminal", trust = "built-in", description = "Run DockOS shell commands." },
  { id = "settings", name = "Settings", trust = "built-in", description = "Themes, display, speakers, printer, security." },
  { id = "luma", name = "Luma Browser", trust = "built-in", popular = true, description = "Browse Luma pages and create web sites." },
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
  docs_scroll = 0,
  docs_menu_open = false,
  paint_color = colors.white,
  paint_cells = {},
  paint_canvas_width = 42,
  paint_canvas_height = 14,
  blend_mode = "Layout",
  blend_object = "Cube",
  settings_message = "",
  settings_tab = "general",
  app_search_query = "",
  store_search_query = "",
  store_scroll = 0,
  focused_field = nil,
  luma_page = "home",
  luma_query = "",
  luma_tabs = {
    { title = "New Tab", url = "", page = "home" },
  },
  luma_active_tab = 1,
  luma_tlds = { ".luma", ".lw", ".store", ".online", ".ai", ".game", ".tv" },
  luma_creator_name = "RoadRover Official Site",
  luma_creator_slug = "roadrover-official-site",
  luma_creator_tld = ".store",
  luma_creator_title = "RoadRover Official Site",
  luma_creator_body = "Adventure cars, parts, and field notes for every road.",
  luma_creator_elements = {
    { kind = "heading", text = "RoadRover Official Site" },
    { kind = "text", text = "Built with Luma Web Creator." },
  },
  luma_sites = {
    {
      name = "RoadRover Official Site",
      slug = "roadrover-official-site",
      tld = ".store",
      title = "RoadRover Official Site",
      body = "Adventure cars, parts, and field notes for every road.",
      elements = {
        { kind = "heading", text = "RoadRover Official Site" },
        { kind = "text", text = "Official store and garage notes." },
      },
    },
  },
  luma_sites_loaded = false,
  studio_code = "app.title='Demo App'; shape(4,3,18,5); text(6,5,'Hello DockOS')",
  studio_message = "Preview ready",
  studio_examples_open = false,
  studio_preview = "blank",
  studio_elements = {
    { kind = "shape", label = "Panel" },
    { kind = "text", label = "Hello DockOS" },
  },
  toast = "",
  modal = nil,
  input = nil,
  system_menu_open = false,
  terminal_lines = {},
  terminal_input = "",
  terminal_cwd = "/",
  boot_splash_done = false,
  theme_id = "win10",
  wallpaper = nil,
  wallpaper_key = nil,
  wallpaper_error = nil,
  wallpaper_attempted = false,
  timezone_offset = DEFAULT_TIMEZONE_OFFSET,
  icon_cache = {},
  directgpu = nil,
  headless = true,
  frame_ops = {},
  virtual_width = DEFAULT_EXTERNAL_WIDTH,
  virtual_height = DEFAULT_EXTERNAL_HEIGHT,
  peripheral_scan_timer = nil,
  external = {
    gpu = nil,
    gpu_name = nil,
    gpu_ready = false,
    gpu_error = nil,
    keyboard = nil,
    keyboard_name = nil,
    monitor = nil,
    monitor_name = nil,
    pixel_width = DEFAULT_EXTERNAL_WIDTH * CELL_WIDTH,
    pixel_height = DEFAULT_EXTERNAL_HEIGHT * CELL_HEIGHT,
    cell_width = CELL_WIDTH,
    cell_height = CELL_HEIGHT,
    initialized_gpu = nil,
  },
}

local hitboxes = {}
local draw

local function blank_terminal()
  if not term then
    return
  end
  if term.setBackgroundColor then
    pcall(term.setBackgroundColor, colors.black)
  end
  if term.clear then
    pcall(term.clear)
  end
  if term.setTextColor then
    pcall(term.setTextColor, colors.white)
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

local function ceil_div(value, divisor)
  return math.floor((value + divisor - 1) / divisor)
end

local function shell_left_cell()
  if not state.headless then
    return 1
  end
  return ceil_div(DOCK_LEFT_PIXELS, state.external.cell_width) + 1
end

local function shell_bottom_cells()
  if not state.headless then
    return 2
  end
  return ceil_div(DOCK_BOTTOM_PIXELS, state.external.cell_height)
end

local function shell_usable_rect()
  local screen_width, screen_height = screen_size()
  local left = shell_left_cell()
  local top = 1
  local bottom = shell_bottom_cells()
  return left, top, math.max(24, screen_width - left + 1), math.max(10, screen_height - top - bottom + 1)
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

local function foreground_for_background(background)
  if background == colors.white or background == colors.lightGray or background == colors.yellow or background == colors.lime or background == colors.cyan or background == colors.lightBlue then
    return colors.black
  end
  return colors.white
end

local function contains_text(text, query)
  query = tostring(query or ""):lower()
  if query == "" then
    return true
  end
  return tostring(text or ""):lower():find(query, 1, true) ~= nil
end

local function wrap_text(text, width)
  local lines = {}
  width = math.max(1, tonumber(width) or 1)
  for raw_line in (tostring(text or "") .. "\n"):gmatch("(.-)\n") do
    local line = raw_line
    while #line > width do
      local chunk = line:sub(1, width)
      local split_at = chunk:match("^.*()%s+")
      if not split_at or split_at < math.floor(width * 0.45) then
        split_at = width
      end
      table.insert(lines, (line:sub(1, split_at):gsub("%s+$", "")))
      line = line:sub(split_at + 1):gsub("^%s+", "")
    end
    table.insert(lines, line)
  end
  if #lines == 0 then
    table.insert(lines, "")
  end
  return lines
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

local function normalize_timezone_offset(value)
  local offset = tonumber(value) or DEFAULT_TIMEZONE_OFFSET
  offset = math.floor(offset)
  return math.max(MIN_TIMEZONE_OFFSET, math.min(MAX_TIMEZONE_OFFSET, offset))
end

local function timezone_label()
  local offset = normalize_timezone_offset(state.timezone_offset)
  if offset == 0 then
    return "UTC"
  end
  return "UTC" .. (offset > 0 and "+" or "") .. tostring(offset)
end

local function current_time_text()
  local offset = normalize_timezone_offset(state.timezone_offset)
  if os.epoch and os.date then
    local ok, epoch_ms = pcall(os.epoch, "utc")
    if ok and type(epoch_ms) == "number" then
      local seconds = math.floor(epoch_ms / 1000) + offset * 3600
      local date_ok, date = pcall(os.date, "!*t", seconds)
      if date_ok and type(date) == "table" and date.hour and date.min then
        return string.format("%s %02d:%02d", timezone_label(), date.hour, date.min)
      end
    end
  end
  local clock = textutils and textutils.formatTime and textutils.formatTime(os.time(), true) or tostring(os.time())
  return timezone_label() .. " " .. tostring(clock)
end

local function apply_theme(theme_id)
  local preset = THEME_PRESETS[theme_id] or THEME_PRESETS.linux
  for key, value in pairs(preset.values) do
    THEME[key] = value
  end
  state.theme_id = preset.id
end

local function load_config()
  apply_theme(state.theme_id or "linux")
  local config = read_file(CONFIG_PATH)
  if not config then
    return
  end
  for line in config:gmatch("[^\r\n]+") do
    local key, value = line:match("^%s*([%w_%-]+)%s*=%s*(.-)%s*$")
    if key == "theme" then
      apply_theme(value)
    elseif key == "timezone_offset" then
      state.timezone_offset = normalize_timezone_offset(value)
    end
  end
end

local function save_config()
  local config = "theme=" .. tostring(state.theme_id or "linux") .. "\n"
    .. "timezone_offset=" .. tostring(normalize_timezone_offset(state.timezone_offset)) .. "\n"
  return write_file(CONFIG_PATH, config)
end

local function write_buffer_chunk(buffer, chunk)
  if not chunk or #chunk == 0 then
    return true
  end
  if type(chunk) == "string" then
    local offset = 1
    while offset <= #chunk do
      local last = math.min(#chunk, offset + IMAGE_BUFFER_WRITE_CHUNK - 1)
      local ok, err = pcall(function()
        buffer.write(chunk:byte(offset, last))
      end)
      if not ok then
        return nil, err
      end
      offset = last + 1
    end
    return true
  end
  return pcall(function()
    buffer.write(unpacker(chunk))
  end)
end

local function read_binary_chunk(handle)
  local ok, chunk = pcall(handle.read, IMAGE_FILE_READ_CHUNK)
  if ok then
    return chunk
  end
  ok, chunk = pcall(handle.read)
  if ok then
    return chunk
  end
  return nil, chunk
end

local function read_binary_into_gpu_buffer(gpu, path)
  if not gpu.newBuffer or not fs.exists(path) or fs.isDir(path) then
    return nil, "missing image buffer support or file"
  end
  local file_size = fs.getSize(path) or 32
  local ok, buffer = pcall(gpu.newBuffer, math.max(32, file_size))
  if not ok or not buffer then
    return nil, buffer or "newBuffer failed"
  end

  local handle = fs.open(path, "rb") or fs.open(path, "r")
  if not handle then
    return nil, "cannot open " .. path
  end

  while true do
    local chunk, read_err = read_binary_chunk(handle)
    if chunk == nil then
      if read_err then
        handle.close()
        return nil, read_err
      end
      break
    end
    if type(chunk) == "number" then
      chunk = string.char(chunk)
    end
    local wrote, err = write_buffer_chunk(buffer, chunk)
    if not wrote then
      handle.close()
      return nil, err
    end
  end
  handle.close()
  return buffer
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

local function normalize_path(path)
  path = tostring(path or "/")
  if path == "" then
    return "/"
  end
  local absolute = path:sub(1, 1) == "/"
  local parts = {}
  for part in path:gmatch("[^/]+") do
    if part == ".." then
      table.remove(parts)
    elseif part ~= "." and part ~= "" then
      table.insert(parts, part)
    end
  end
  local normalized = table.concat(parts, "/")
  if absolute then
    normalized = "/" .. normalized
  end
  if normalized == "" then
    return absolute and "/" or "."
  end
  return normalized
end

local function resolve_path(path, cwd)
  path = tostring(path or "")
  if path == "" then
    return normalize_path(cwd or "/")
  end
  if path:sub(1, 1) == "/" then
    return normalize_path(path)
  end
  return normalize_path(path_join(cwd or "/", path))
end

local function split_words(text)
  local words = {}
  for word in tostring(text or ""):gmatch("%S+") do
    table.insert(words, word)
  end
  return words
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

local function download_to_file(url, path)
  if not http then
    return nil, "HTTP API is disabled"
  end
  local handle, err = http.get(url, { ["Accept"] = "image/*,*/*" }, true)
  if not handle then
    return nil, err or "request failed"
  end
  local code = 200
  if handle.getResponseCode then
    code = handle.getResponseCode()
  end
  if code < 200 or code >= 300 then
    handle.close()
    return nil, "HTTP " .. tostring(code)
  end
  ensure_parent(path)
  local output = fs.open(path, "wb") or fs.open(path, "w")
  if not output then
    handle.close()
    return nil, "cannot open " .. path
  end
  while true do
    local chunk = handle.read(8192)
    if chunk == nil then
      break
    end
    if type(chunk) == "number" then
      output.write(string.char(chunk))
    elseif type(chunk) == "table" then
      for _, byte in ipairs(chunk) do
        output.write(string.char(byte))
      end
    else
      output.write(chunk)
    end
  end
  output.close()
  handle.close()
  return true
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

function inline_field_value(field)
  if field == "luma_query" then
    return state.luma_query or ""
  elseif field == "luma_creator_name" then
    return state.luma_creator_name or ""
  elseif field == "luma_creator_slug" then
    return state.luma_creator_slug or ""
  elseif field == "luma_creator_title" then
    return state.luma_creator_title or ""
  elseif field == "luma_creator_body" then
    return state.luma_creator_body or ""
  elseif field == "studio_code" then
    return state.studio_code or ""
  end
  return ""
end

function set_inline_field_value(field, value)
  value = tostring(value or "")
  if field == "luma_query" then
    state.luma_query = value
  elseif field == "luma_creator_name" then
    state.luma_creator_name = value
  elseif field == "luma_creator_slug" then
    state.luma_creator_slug = value
  elseif field == "luma_creator_title" then
    state.luma_creator_title = value
  elseif field == "luma_creator_body" then
    state.luma_creator_body = value
  elseif field == "studio_code" then
    state.studio_code = value
  end
end

function luma_slugify(text)
  local slug = string.lower(tostring(text or ""))
  slug = slug:gsub("[^a-z0-9]+", "-"):gsub("^-+", ""):gsub("-+$", "")
  if slug == "" then
    slug = "untitled-site"
  end
  return slug
end

function luma_domain(slug, tld)
  slug = luma_slugify(slug)
  tld = tostring(tld or ".luma")
  if tld:sub(1, 1) ~= "." then
    tld = "." .. tld
  end
  return "www." .. slug .. tld
end

function luma_current_tab()
  if type(state.luma_tabs) ~= "table" or #state.luma_tabs == 0 then
    state.luma_tabs = { { title = "New Tab", url = "", page = "home" } }
    state.luma_active_tab = 1
  end
  state.luma_active_tab = math.max(1, math.min(#state.luma_tabs, tonumber(state.luma_active_tab) or 1))
  return state.luma_tabs[state.luma_active_tab]
end

function luma_site_domain(site)
  return luma_domain(site and site.slug or "", site and site.tld or ".luma")
end

function luma_normalize_address(value)
  local address = string.lower(tostring(value or "")):gsub("^%s+", ""):gsub("%s+$", "")
  address = address:gsub("^https?://", ""):gsub("/$", "")
  return address
end

function luma_find_site(value)
  local address = luma_normalize_address(value)
  for _, site in ipairs(state.luma_sites or {}) do
    local domain = luma_normalize_address(luma_site_domain(site))
    if address == domain or address == luma_normalize_address(site.slug) then
      return site, domain
    end
  end
  return nil, nil
end

function luma_load_sites()
  if state.luma_sites_loaded then
    return
  end
  state.luma_sites_loaded = true
  if not textutils or not textutils.unserialize or not fs.exists(LUMA_SITES_PATH) then
    return
  end
  local body = read_file(LUMA_SITES_PATH)
  local ok, sites = pcall(textutils.unserialize, body or "")
  if ok and type(sites) == "table" and #sites > 0 then
    state.luma_sites = sites
  end
end

function luma_save_sites()
  if not textutils or not textutils.serialize then
    return
  end
  local ok, data = pcall(textutils.serialize, state.luma_sites or {})
  if ok and data then
    write_file(LUMA_SITES_PATH, data)
  end
end

function luma_set_tab(page, url, title, site)
  local tab = luma_current_tab()
  tab.page = page or "home"
  tab.url = url or ""
  tab.title = title or (url ~= "" and url or "New Tab")
  tab.site = site
  state.luma_page = tab.page
  if state.focused_field ~= "luma_query" then
    state.luma_query = tab.url or ""
  end
end

function luma_open_new_tab()
  table.insert(state.luma_tabs, { title = "New Tab", url = "", page = "home" })
  state.luma_active_tab = #state.luma_tabs
  state.luma_query = ""
  state.luma_page = "home"
end

function luma_close_tab(index)
  index = tonumber(index) or state.luma_active_tab or 1
  if #state.luma_tabs <= 1 then
    state.luma_tabs = { { title = "New Tab", url = "", page = "home" } }
    state.luma_active_tab = 1
  else
    table.remove(state.luma_tabs, math.max(1, math.min(#state.luma_tabs, index)))
    state.luma_active_tab = math.max(1, math.min(#state.luma_tabs, state.luma_active_tab or 1))
  end
  local tab = luma_current_tab()
  state.luma_query = tab.url or ""
  state.luma_page = tab.page or "home"
end

function luma_navigate(value)
  local query = tostring(value or "")
  local lowered = string.lower(query)
  if query == "" then
    luma_set_tab("home", "", "New Tab", nil)
    return
  end
  if lowered:find("creator", 1, true) or lowered:find("luma://create", 1, true) then
    luma_set_tab("creator", "luma://creator", "Web Creator", nil)
    return
  end
  local site, domain = luma_find_site(query)
  if site then
    luma_set_tab("site", domain, site.name, site)
  else
    luma_set_tab("search", query, "Search", nil)
  end
end

function luma_publish_site()
  luma_load_sites()
  local raw_slug = tostring(state.luma_creator_slug or "")
  local raw_name = tostring(state.luma_creator_name or "")
  local raw_title = tostring(state.luma_creator_title or "")
  local slug = luma_slugify(raw_slug ~= "" and raw_slug or raw_name)
  state.luma_creator_slug = slug
  local site = {
    name = raw_name ~= "" and raw_name or raw_title,
    slug = slug,
    tld = state.luma_creator_tld or ".luma",
    title = raw_title,
    body = tostring(state.luma_creator_body or ""),
    elements = {},
  }
  for _, element in ipairs(state.luma_creator_elements or {}) do
    table.insert(site.elements, { kind = element.kind, text = element.text })
  end
  local domain = luma_site_domain(site)
  local replaced = false
  for index, existing in ipairs(state.luma_sites or {}) do
    if luma_site_domain(existing) == domain then
      state.luma_sites[index] = site
      replaced = true
      break
    end
  end
  if not replaced then
    table.insert(state.luma_sites, site)
  end
  luma_save_sites()
  luma_set_tab("site", domain, site.name, site)
  state.toast = "Published " .. domain
end

function submit_luma_query()
  luma_navigate(state.luma_query or "")
  state.focused_field = nil
end

function apply_studio_example(example_id)
  state.studio_examples_open = false
  if example_id == "pong" then
    state.studio_preview = "pong"
    state.studio_code = "example('ping-pong'); paddle('left'); paddle('right'); ball(18,7)"
    state.studio_elements = {
      { kind = "shape", label = "Left paddle" },
      { kind = "shape", label = "Right paddle" },
      { kind = "shape", label = "Ball" },
    }
    state.studio_message = "Example loaded: Ping Pong"
  elseif example_id == "music" then
    state.studio_preview = "music"
    state.studio_code = "example('music-player'); text('Dock Beats'); image('cover'); button('Play')"
    state.studio_elements = {
      { kind = "image", label = "Album art" },
      { kind = "text", label = "Track title" },
      { kind = "shape", label = "Play button" },
    }
    state.studio_message = "Example loaded: Music Player"
  else
    state.studio_preview = "blank"
    state.studio_code = "app.title='Demo App'; shape(4,3,18,5); text(6,5,'Hello DockOS')"
    state.studio_elements = {
      { kind = "shape", label = "Panel" },
      { kind = "text", label = "Hello DockOS" },
    }
    state.studio_message = "Example loaded: Blank"
  end
end

function studio_add_component(kind)
  kind = tostring(kind or "shape")
  if kind == "textinput" then
    state.studio_code = tostring(state.studio_code or "") .. "; input('Name')"
    table.insert(state.studio_elements, { kind = "textinput", label = "Text input" })
  elseif kind == "image" then
    state.studio_code = tostring(state.studio_code or "") .. "; image('asset')"
    table.insert(state.studio_elements, { kind = "image", label = "Image" })
  elseif kind == "text" then
    state.studio_code = tostring(state.studio_code or "") .. "; text('Label')"
    table.insert(state.studio_elements, { kind = "text", label = "Text" })
  else
    state.studio_code = tostring(state.studio_code or "") .. "; shape(2,2,12,4)"
    table.insert(state.studio_elements, { kind = "shape", label = "Shape" })
  end
  state.studio_preview = "custom"
  state.studio_message = "Component added: " .. kind
end

function submit_inline_field(field)
  if field == "luma_query" then
    submit_luma_query()
  elseif field == "studio_code" then
    state.studio_preview = "custom"
    state.studio_message = "Preview updated"
  elseif field == "luma_creator_name" then
    state.luma_creator_slug = luma_slugify(state.luma_creator_name)
    state.toast = "Domain updated"
  elseif field == "luma_creator_slug" then
    state.luma_creator_slug = luma_slugify(state.luma_creator_slug)
    state.toast = "Domain updated"
  elseif field == "luma_creator_title" or field == "luma_creator_body" then
    state.toast = "Luma page updated"
  end
end

function handle_inline_field_event(event, first)
  if not state.focused_field or state.input or state.modal then
    return false
  end
  if event == "char" or event == "paste" then
    local value = inline_field_value(state.focused_field)
    set_inline_field_value(state.focused_field, value .. tostring(first or ""))
    return true
  elseif event == "key" then
    if first == keys.enter then
      submit_inline_field(state.focused_field)
      return true
    elseif first == keys.backspace then
      local value = inline_field_value(state.focused_field)
      set_inline_field_value(state.focused_field, value:sub(1, math.max(0, #value - 1)))
      return true
    elseif keys.escape and first == keys.escape then
      state.focused_field = nil
      return true
    end
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
  state.windows[window_id].minimized = false
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
  local shell_left, shell_top, usable_width, usable_height = shell_usable_rect()
  local window_id = state.next_window_id
  state.next_window_id = state.next_window_id + 1
  local window_width = math.min(preferred_width or 42, usable_width)
  local window_height = math.min(preferred_height or 14, usable_height)
  local offset = (#state.window_order % 3) * 2
  local screen_width, screen_height = screen_size()
  local shell_bottom = shell_bottom_cells()
  local max_left = math.max(shell_left, screen_width - window_width + 1)
  local max_top = math.max(shell_top, screen_height - shell_bottom - window_height + 1)
  local window_state = {
    id = window_id,
    app = app_id,
    title = title,
    left = math.min(max_left, math.max(shell_left, shell_left + math.floor((usable_width - window_width) / 2) + offset)),
    top = math.min(max_top, math.max(shell_top, shell_top + math.floor((usable_height - window_height) / 2) + offset)),
    width = window_width,
    height = window_height,
    fullscreen = false,
    minimized = false,
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

local function minimize_window(window_id)
  local window_state = state.windows[window_id]
  if not window_state then
    return
  end
  window_state.minimized = true
  if state.active_window == window_id then
    state.active_window = nil
    for index = #state.window_order, 1, -1 do
      local candidate = state.windows[state.window_order[index]]
      if candidate and not candidate.minimized then
        state.active_window = candidate.id
        break
      end
    end
  end
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
    window_state.top = 1
    window_state.width = math.max(24, screen_width)
    window_state.height = math.max(10, screen_height)
    window_state.fullscreen = true
    window_state.minimized = false
  end
end

function begin_window_drag(window_id, mouse_left, mouse_top)
  local window_state = state.windows[window_id]
  if not window_state or window_state.fullscreen then
    return
  end
  state.dragging_window = {
    id = window_id,
    start_left = window_state.left,
    start_top = window_state.top,
    mouse_left = mouse_left,
    mouse_top = mouse_top,
  }
  bring_to_front(window_id)
end

local open_app

local function install_wallpaper_url(url)
  if not url or url == "" then
    return nil, "missing wallpaper URL"
  end
  local ok, write_err = download_to_file(url, path_join(ASSETS_DIR, "wallpaper.png"))
  if not ok then
    return nil, write_err
  end
  if state.wallpaper and state.wallpaper.free then
    pcall(state.wallpaper.free)
  end
  state.wallpaper = nil
  state.wallpaper_key = nil
  state.wallpaper_error = nil
  state.wallpaper_attempted = false
  return true
end

local function terminal_print(line, color)
  state.terminal_lines = state.terminal_lines or {}
  table.insert(state.terminal_lines, { text = tostring(line or ""), color = color or colors.lightGray })
  while #state.terminal_lines > 160 do
    table.remove(state.terminal_lines, 1)
  end
end

local function terminal_boot()
  if #state.terminal_lines > 0 then
    return
  end
  terminal_print("DockOS " .. RELEASE_NAME .. " Terminal " .. VERSION, colors.cyan)
  terminal_print("Enter 'help' to list commands.", colors.lightGray)
end

local function terminal_list(path)
  local target = resolve_path(path or state.terminal_cwd, state.terminal_cwd)
  if not fs.exists(target) then
    terminal_print("Not found: " .. target, colors.red)
    return
  end
  if not fs.isDir(target) then
    terminal_print(target .. " " .. tostring(fs.getSize(target) or 0) .. "b", colors.white)
    return
  end
  local entries = list_dir(target)
  if #entries == 0 then
    terminal_print("(empty)", colors.lightGray)
    return
  end
  local line = ""
  for _, entry in ipairs(entries) do
    local token = entry.dir and ("[" .. entry.name .. "]") or entry.name
    if #line + #token + 2 > 70 then
      terminal_print(line, colors.white)
      line = token
    else
      line = line == "" and token or (line .. "  " .. token)
    end
  end
  if line ~= "" then
    terminal_print(line, colors.white)
  end
end

local function terminal_cat(path)
  local target = resolve_path(path or "", state.terminal_cwd)
  if not fs.exists(target) or fs.isDir(target) then
    terminal_print("File not found: " .. target, colors.red)
    return
  end
  local body = read_file(target) or ""
  local count = 0
  for line in (body .. "\n"):gmatch("(.-)\n") do
    count = count + 1
    if count > 12 then
      terminal_print("... truncated", colors.orange)
      break
    end
    terminal_print(line, colors.white)
  end
end

local function terminal_execute(command_line)
  command_line = tostring(command_line or "")
  terminal_print("> " .. command_line, colors.white)
  local words = split_words(command_line)
  local command = words[1]
  if not command then
    return
  end
  if command == "help" then
    terminal_print("help, clear, pwd, ls [path], cd <path>", colors.cyan)
    terminal_print("cat <file>, mkdir <path>, touch <file>, rm <path>", colors.cyan)
    terminal_print("open <app>, apps, wallpaper <url>, version, time", colors.cyan)
    terminal_print("reboot, shutdown", colors.cyan)
  elseif command == "clear" then
    state.terminal_lines = {}
  elseif command == "pwd" then
    terminal_print(state.terminal_cwd, colors.white)
  elseif command == "ls" then
    terminal_list(words[2])
  elseif command == "cd" then
    local target = resolve_path(words[2] or "/", state.terminal_cwd)
    if fs.exists(target) and fs.isDir(target) then
      state.terminal_cwd = target
    else
      terminal_print("Directory not found: " .. target, colors.red)
    end
  elseif command == "cat" then
    terminal_cat(words[2])
  elseif command == "mkdir" then
    local target = resolve_path(words[2] or "", state.terminal_cwd)
    if target == "/" or target == "." then
      terminal_print("Invalid path.", colors.red)
    elseif fs.exists(target) then
      terminal_print("Already exists: " .. target, colors.red)
    else
      fs.makeDir(target)
      terminal_print("Created: " .. target, colors.lime)
    end
  elseif command == "touch" then
    local target = resolve_path(words[2] or "", state.terminal_cwd)
    if target == "/" or target == "." then
      terminal_print("Invalid path.", colors.red)
    else
      write_file(target, read_file(target) or "")
      terminal_print("Written: " .. target, colors.lime)
    end
  elseif command == "rm" then
    local target = resolve_path(words[2] or "", state.terminal_cwd)
    if target == "/" or target == "." then
      terminal_print("Refusing to remove root.", colors.red)
    elseif fs.exists(target) then
      fs.delete(target)
      terminal_print("Removed: " .. target, colors.lime)
    else
      terminal_print("Not found: " .. target, colors.red)
    end
  elseif command == "apps" then
    local ids = {}
    for app_id in pairs(APPS) do
      table.insert(ids, app_id)
    end
    table.sort(ids)
    terminal_print(table.concat(ids, " "), colors.white)
  elseif command == "wallpaper" then
    local ok, err = install_wallpaper_url(words[2])
    if ok then
      terminal_print("Wallpaper installed.", colors.lime)
    else
      terminal_print("Wallpaper failed: " .. tostring(err), colors.red)
    end
  elseif command == "open" then
    local app_id = words[2]
    if app_id and APPS[app_id] and open_app then
      open_app(app_id)
      terminal_print("Opened: " .. app_id, colors.lime)
    else
      terminal_print("Application not found.", colors.red)
    end
  elseif command == "time" then
    terminal_print(current_time_text(), colors.white)
  elseif command == "version" then
    terminal_print(DISPLAY_VERSION, colors.white)
  elseif command == "reboot" then
    os.reboot()
  elseif command == "shutdown" then
    os.shutdown()
  else
    terminal_print("Unknown command: " .. command, colors.red)
  end
end

local function open_luma()
  luma_load_sites()
  local existing_window = find_window_by_app("luma")
  if existing_window then
    bring_to_front(existing_window.id)
    return
  end
  create_window("luma", "Luma Browser", 64, 21)
end

local function open_terminal()
  terminal_boot()
  local existing_window = find_window_by_app("terminal")
  if existing_window then
    bring_to_front(existing_window.id)
    return
  end
  create_window("terminal", "Terminal", 70, 32)
end

function open_app(app_id)
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
  local preferred_width = app_id == "finder" and 70
    or app_id == "paint" and 70
    or app_id == "blend" and 72
    or app_id == "studio" and 72
    or app_id == "launcher" and 66
    or app_id == "docs" and 70
    or app_id == "settings" and 70
    or app_id == "store" and 68
    or 64
  local preferred_height = app_id == "finder" and 34
    or app_id == "paint" and 35
    or app_id == "blend" and 36
    or app_id == "studio" and 34
    or app_id == "launcher" and 32
    or app_id == "docs" and 36
    or app_id == "settings" and 34
    or app_id == "store" and 34
    or 30
  create_window(app_id, app.name, preferred_width, preferred_height)
end

local function draw_button(action, left, top, label, payload, background)
  local width = #label + 2
  local button_background = background or THEME.button
  fill(left, top, width, 1, button_background)
  write_at(left + 1, top, label, foreground_for_background(button_background), button_background)
  add_hit(action, left, top, width, 1, payload)
  return width
end

function draw_inline_field(left, top, width, field, placeholder, background)
  if width < 3 then
    return
  end
  local field_background = background or THEME.field
  local active = state.focused_field == field
  local value = inline_field_value(field)
  local text = value ~= "" and value or tostring(placeholder or "")
  local text_color = value ~= "" and colors.white or colors.lightGray
  fill(left, top, width, 1, field_background)
  if active then
    fill(left, top, 1, 1, THEME.accent)
    text = trim(text .. "_", width - 3)
    write_at(left + 2, top, text, text_color, field_background)
  else
    write_at(left + 1, top, trim(text, width - 2), text_color, field_background)
  end
  add_hit("inline_focus", left, top, width, 1, field)
end

local function icon_asset_path(icon_id)
  return path_join(path_join(ASSETS_DIR, "icons"), tostring(icon_id or "apps") .. ".png")
end

local function draw_icon_asset(left, top, width, height, icon_id, fallback, foreground, background)
  if background then
    fill(left, top, width, height, background)
  end
  if state.headless then
    queue_frame_op({
      kind = "image",
      left = left,
      top = top,
      width = width,
      height = height,
      path = icon_asset_path(icon_id),
      fallback = tostring(fallback or ""),
      foreground = foreground or foreground_for_background(background),
      background = background,
    })
  else
    local text_left = left + math.max(0, math.floor((width - #(fallback or "")) / 2))
    local text_top = top + math.max(0, math.floor((height - 1) / 2))
    write_at(text_left, text_top, tostring(fallback or ""), foreground or foreground_for_background(background), background)
  end
end

local function draw_app_icon(left, top, app, width, height, action, payload)
  local icon_width = width or 4
  local icon_height = height or 2
  draw_icon_asset(left, top, icon_width, icon_height, app.icon_asset, app.icon, foreground_for_background(app.color), app.color)
  if action then
    add_hit(action, left, top, icon_width, icon_height, payload or app.id)
  end
end

local function pixel_fill(left, top, width, height, color)
  if state.headless then
    queue_frame_op({ kind = "pixel_fill", left = left, top = top, width = width, height = height, color = color or colors.black })
  end
end

local function pixel_round(left, top, width, height, radius, color)
  if state.headless then
    queue_frame_op({ kind = "pixel_round", left = left, top = top, width = width, height = height, radius = radius or 3, color = color or colors.black })
  end
end

local function pixel_icon(left, top, width, height, icon_id, fallback, background, foreground)
  if state.headless then
    queue_frame_op({
      kind = "pixel_image",
      left = left,
      top = top,
      width = width,
      height = height,
      path = icon_asset_path(icon_id),
      fallback = tostring(fallback or ""),
      background = background,
      foreground = foreground or foreground_for_background(background),
    })
  end
end

local function pixel_tiny_text(left, top, text, color, scale)
  if state.headless then
    queue_frame_op({ kind = "tiny_text", left = left, top = top, text = tostring(text or ""), color = color or colors.white, scale = scale or 1 })
  end
end

local function tiny_text_width(text, scale)
  scale = scale or 1
  local width = 0
  for _ = 1, #tostring(text or "") do
    width = width + 4 * scale
  end
  return math.max(0, width - scale)
end


local function draw_menu_bar()
end

local function draw_system_menu()
  if not state.system_menu_open then
    return
  end
  local left, top, width, height = shell_usable_rect()
  fill(left, top, width, height, colors.black)
  fill(left + 1, top + 1, width - 2, 3, THEME.field)
  write_at(left + 2, top + 1, "Activities", colors.orange, THEME.field)
  draw_icon_asset(left + 2, top + 2, 3, 1, "search_tile", "?", colors.lightGray, THEME.field)
  write_at(left + 6, top + 2, trim(state.app_search_query ~= "" and state.app_search_query or "Type to search applications", width - 18), colors.lightGray, THEME.field)
  draw_button("app_search_prompt", left + width - 10, top + 2, "Search", nil, THEME.button)

  local apps = {}
  for app_id, app in pairs(APPS) do
    if contains_text(app.name .. " " .. app_id, state.app_search_query) then
      table.insert(apps, { id = app_id, app = app })
    end
  end
  table.sort(apps, function(left_app, right_app)
    return left_app.app.name < right_app.app.name
  end)

  local card_width = 12
  local card_height = 4
  local grid_left = left + 2
  local grid_top = top + 5
  local columns = math.max(1, math.floor((width - 4) / (card_width + 1)))
  for index, item in ipairs(apps) do
    local zero = index - 1
    local col = zero % columns
    local row = math.floor(zero / columns)
    local card_left = grid_left + col * (card_width + 1)
    local card_top = grid_top + row * (card_height + 1)
    if card_top + card_height > top + height - 3 then
      break
    end
    fill(card_left, card_top, card_width, card_height, THEME.surface)
    draw_app_icon(card_left + 4, card_top + 1, item.app, 4, 2, nil, nil)
    write_at(card_left + 1, card_top + 3, trim(item.app.name, card_width - 2), colors.white, THEME.surface)
    add_hit("launcher_open", card_left, card_top, card_width, card_height, item.id)
  end

  local action_top = top + height - 2
  draw_button("system_about", left + 2, action_top, "About", nil, colors.gray)
  draw_button("system_reboot", left + 11, action_top, "Reboot", nil, colors.orange)
  draw_button("system_shutdown", left + 22, action_top, "Power off", nil, THEME.danger)
end

local function draw_desktop()
end

local function dock_width()
  return (#PINNED * 5) + 3 + (#state.open_dock_order * 5)
end

local function is_pinned(app_id)
  for _, pinned_app_id in ipairs(PINNED) do
    if pinned_app_id == app_id then
      return true
    end
  end
  return false
end

local function draw_dock()
  local screen_width, screen_height = screen_size()
  local pixel_width = state.external.pixel_width or (screen_width * state.external.cell_width)
  local pixel_height = state.external.pixel_height or (screen_height * state.external.cell_height)
  local bottom_height = math.max(DOCK_BOTTOM_PIXELS, math.floor(pixel_height * 0.10))
  local bottom_top = math.max(1, pixel_height - bottom_height + 1)

  if state.headless then
    local quick = {
      { app = "launcher", action = "system_menu_toggle", color = colors.red },
      { app = "finder", action = "dock_pinned", color = colors.blue },
      { app = "terminal", action = "dock_pinned", color = colors.lime },
      { app = "store", action = "dock_pinned", color = colors.magenta },
      { app = "settings", action = "dock_pinned", color = colors.black },
    }
    for index, item in ipairs(quick) do
      local app = APPS[item.app]
      local icon_top = 8 + (index - 1) * (DOCK_BUTTON_PIXELS + DOCK_GAP_PIXELS)
      pixel_fill(5, icon_top, DOCK_BUTTON_PIXELS, DOCK_BUTTON_PIXELS, item.color)
      if app then
        pixel_icon(5 + math.floor((DOCK_BUTTON_PIXELS - DOCK_ICON_PIXELS) / 2), icon_top + math.floor((DOCK_BUTTON_PIXELS - DOCK_ICON_PIXELS) / 2), DOCK_ICON_PIXELS, DOCK_ICON_PIXELS, app.icon_asset, app.icon, nil, colors.white)
      end
      local hit_top = math.max(1, math.floor((icon_top - 1) / state.external.cell_height) + 1)
      add_hit(item.action, 1, hit_top, shell_left_cell() - 1, math.max(3, ceil_div(DOCK_BUTTON_PIXELS, state.external.cell_height)), item.app)
    end

    pixel_fill(1, bottom_top, pixel_width, bottom_height, colors.black)
    local icon_left = 8
    local icon_top = bottom_top + math.floor((bottom_height - DOCK_BUTTON_PIXELS) / 2)
    for _, app_id in ipairs(PINNED) do
      local app = APPS[app_id]
      if icon_left + DOCK_BUTTON_PIXELS >= pixel_width - 96 then
        break
      end
      pixel_fill(icon_left, icon_top, DOCK_BUTTON_PIXELS, DOCK_BUTTON_PIXELS, app and app.color or colors.red)
      if app then
        pixel_icon(icon_left + math.floor((DOCK_BUTTON_PIXELS - DOCK_ICON_PIXELS) / 2), icon_top + math.floor((DOCK_BUTTON_PIXELS - DOCK_ICON_PIXELS) / 2), DOCK_ICON_PIXELS, DOCK_ICON_PIXELS, app.icon_asset, app.icon, nil, colors.white)
      end
      if is_open_dock_app(app_id) then
        pixel_fill(icon_left, icon_top + DOCK_BUTTON_PIXELS - 3, DOCK_BUTTON_PIXELS, 3, colors.white)
      end
      local hit_left = math.max(1, math.floor((icon_left - 1) / state.external.cell_width) + 1)
      local hit_top = math.max(1, math.floor((icon_top - 1) / state.external.cell_height) + 1)
      add_hit("dock_pinned", hit_left, hit_top, ceil_div(DOCK_BUTTON_PIXELS, state.external.cell_width), ceil_div(DOCK_BUTTON_PIXELS, state.external.cell_height), app_id)
      icon_left = icon_left + DOCK_BUTTON_PIXELS + DOCK_GAP_PIXELS
    end
    local open_left = icon_left + 4
    for _, app_id in ipairs(state.open_dock_order) do
      local app = APPS[app_id]
      if not is_pinned(app_id) and open_left + DOCK_BUTTON_PIXELS < pixel_width - 96 then
        pixel_fill(open_left, icon_top, DOCK_BUTTON_PIXELS, DOCK_BUTTON_PIXELS, app and app.color or colors.orange)
        if app then
          pixel_icon(open_left + math.floor((DOCK_BUTTON_PIXELS - DOCK_ICON_PIXELS) / 2), icon_top + math.floor((DOCK_BUTTON_PIXELS - DOCK_ICON_PIXELS) / 2), DOCK_ICON_PIXELS, DOCK_ICON_PIXELS, app.icon_asset, app.icon, nil, colors.white)
        end
        local hit_left = math.max(1, math.floor((open_left - 1) / state.external.cell_width) + 1)
        local hit_top = math.max(1, math.floor((icon_top - 1) / state.external.cell_height) + 1)
        add_hit("dock_open", hit_left, hit_top, ceil_div(DOCK_BUTTON_PIXELS, state.external.cell_width), ceil_div(DOCK_BUTTON_PIXELS, state.external.cell_height), app_id)
        open_left = open_left + DOCK_BUTTON_PIXELS + DOCK_GAP_PIXELS
      end
    end
    add_hit("dock_drop_end", math.max(1, math.floor((open_left - 1) / state.external.cell_width) + 1), screen_height - 1, 3, 2, nil)
    local status = current_time_text()
    local status_width = tiny_text_width(status, 1)
    pixel_tiny_text(math.max(1, pixel_width - status_width - 8), bottom_top + math.floor((bottom_height - 5) / 2), status, colors.white, 1)
  else
    local bottom_row = math.max(1, screen_height - 1)
    fill(1, bottom_row, screen_width, 2, colors.black)
    local icon_left = 1
    for _, app_id in ipairs(PINNED) do
      if icon_left + 2 >= screen_width - 12 then
        break
      end
      fill(icon_left, bottom_row, 2, 2, colors.red)
      add_hit("dock_pinned", icon_left, bottom_row, 2, 2, app_id)
      icon_left = icon_left + 3
    end
    local status = current_time_text()
    write_at(math.max(1, screen_width - #status), bottom_row, status, colors.white, colors.black)
  end
end

local function draw_top_panel()
end

local function window_title_height(window_state)
  return window_state and window_state.fullscreen and 1 or 2
end

local function draw_window_frame(window_state)
  local active = state.active_window == window_state.id
  local title_color = active and THEME.window_title or THEME.window_inactive
  local title_foreground = active and colors.white or colors.lightGray
  local title_height = window_title_height(window_state)
  fill(window_state.left, window_state.top, window_state.width, window_state.height, THEME.window)
  fill(window_state.left, window_state.top, window_state.width, title_height, title_color)
  add_hit("window_focus", window_state.left, window_state.top, window_state.width, window_state.height, window_state.id)
  local controls_left = math.max(window_state.left + 1, window_state.left + window_state.width - 8)
  write_at(window_state.left + 1, window_state.top, trim(window_state.title, math.max(1, controls_left - window_state.left - 2)), title_foreground, title_color)
  write_at(controls_left, window_state.top, "-", colors.lightGray, title_color)
  write_at(controls_left + 3, window_state.top, window_state.fullscreen and "<>" or "[]", colors.lightGray, title_color)
  write_at(controls_left + 6, window_state.top, "x", colors.white, THEME.danger)
  add_hit("window_minimize", controls_left, window_state.top, 1, 1, window_state.id)
  add_hit("window_fullscreen", controls_left + 3, window_state.top, 2, 1, window_state.id)
  add_hit("window_close", controls_left + 6, window_state.top, 1, 1, window_state.id)
  add_hit("window_drag", window_state.left, window_state.top, math.max(1, controls_left - window_state.left), title_height, window_state.id)
end

local function content_rect(window_state)
  local title_height = window_title_height(window_state)
  if window_state and window_state.fullscreen then
    return window_state.left, window_state.top + title_height, window_state.width, window_state.height - title_height
  end
  return window_state.left + 1, window_state.top + title_height + 1, window_state.width - 2, window_state.height - title_height - 2
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
  fill(left, top, width, height, colors.lightGray)
  fill(left, top, width, 2, colors.white)
  local cursor_left = left + 1
  cursor_left = cursor_left + draw_button("doc_menu_toggle", cursor_left, top, "File", nil, colors.orange) + 1
  cursor_left = cursor_left + draw_button("doc_edit", cursor_left, top, "Edit", nil, colors.gray) + 1
  cursor_left = cursor_left + draw_button("doc_print", cursor_left, top, "Print", nil, colors.gray) + 1
  draw_button("doc_delete", cursor_left, top, "Delete", nil, THEME.danger)

  local list_left = left + 1
  local list_top = top + 3
  local list_width = math.max(16, math.floor(width * 0.25))
  local list_height = height - 4
  fill(list_left, list_top, list_width, list_height, colors.gray)
  write_at(list_left + 1, list_top, "Docs", colors.white, colors.gray)
  for row_index, doc in ipairs(docs_list()) do
    if row_index >= list_height then
      break
    end
    local row_top = list_top + row_index
    local selected = state.docs_selected == doc.path
    local row_background = selected and colors.orange or colors.gray
    fill(list_left, row_top, list_width, 1, row_background)
    write_at(list_left + 1, row_top, trim(doc.name, list_width - 2), foreground_for_background(row_background), row_background)
    add_hit("doc_select", list_left, row_top, list_width, 1, doc.path)
  end

  local paper_width = math.min(math.max(20, width - list_width - 6), 52)
  local paper_height = math.max(8, height - 6)
  local paper_left = list_left + list_width + math.max(2, math.floor((width - list_width - paper_width - 2) / 2))
  local paper_top = top + 3
  fill(paper_left + 1, paper_top + 1, paper_width, paper_height, colors.gray)
  fill(paper_left, paper_top, paper_width, paper_height, colors.white)
  if state.docs_selected then
    write_at(paper_left + 2, paper_top + 1, trim(basename(state.docs_selected), paper_width - 4), colors.black, colors.white)
    local body = state.docs_preview ~= "" and state.docs_preview or read_file(state.docs_selected) or ""
    local lines = wrap_text(body, paper_width - 4)
    local visible_rows = paper_height - 4
    for row_index = 1, visible_rows do
      local line = lines[row_index + state.docs_scroll]
      if not line then
        break
      end
      write_at(paper_left + 2, paper_top + 2 + row_index, trim(line, paper_width - 4), colors.black, colors.white)
    end
  else
    write_at(paper_left + 2, paper_top + 2, "Select or create a document.", colors.gray, colors.white)
  end
  if state.docs_menu_open then
    fill(left + 1, top + 1, 15, 4, colors.white)
    draw_button("doc_new", left + 2, top + 2, "New", nil, colors.orange)
    draw_button("doc_edit", left + 2, top + 3, "Edit", nil, colors.gray)
    draw_button("doc_print", left + 2, top + 4, "Print", nil, colors.gray)
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
  return state.paint_cells[paint_key(col, row)] or colors.white
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
    local save_width = tonumber(state.paint_canvas_width) or 42
    local save_height = tonumber(state.paint_canvas_height) or 14
    for row = 1, save_height do
      local parts = {}
      for col = 1, save_width do
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
  local left, top, width, height = content_rect(window_state)
  fill(left, top, width, height, colors.lightGray)
  fill(left, top, width, 2, colors.white)
  local cursor_left = left + 1
  cursor_left = cursor_left + draw_button("paint_clear", cursor_left, top, "Clear", nil, colors.gray) + 1
  cursor_left = cursor_left + draw_button("paint_save", cursor_left, top, "Save", nil, colors.orange) + 1
  write_at(cursor_left, top, "Color", colors.black, colors.white)

  local palette = { colors.white, colors.lightGray, colors.gray, colors.black, colors.red, colors.orange, colors.yellow, colors.lime, colors.green, colors.cyan, colors.blue, colors.purple, colors.pink, colors.brown }
  local palette_left = left + 1
  local palette_top = top + 3
  for index, color in ipairs(palette) do
    local cell_left = palette_left + ((index - 1) % 7) * 3
    local cell_top = palette_top + math.floor((index - 1) / 7)
    fill(cell_left, cell_top, 2, 1, color)
    add_hit("paint_color", cell_left, cell_top, 2, 1, color)
  end

  local canvas_width = math.min(60, width - 4)
  local canvas_height = math.min(24, height - 7)
  state.paint_canvas_width = canvas_width
  state.paint_canvas_height = canvas_height
  local canvas_left = left + math.max(2, math.floor((width - canvas_width) / 2))
  local canvas_top = top + 6
  fill(canvas_left + 1, canvas_top + 1, canvas_width, canvas_height, colors.gray)
  fill(canvas_left, canvas_top, canvas_width, canvas_height, colors.white)
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
  local left, top, width, height = content_rect(window_state)
  fill(left, top, width, height, colors.black)
  fill(left, top, width, 3, THEME.field)
  write_at(left + 1, top, "Software", colors.orange, THEME.field)
  draw_icon_asset(left + 2, top + 1, 3, 1, "search_tile", "?", colors.lightGray, THEME.field)
  write_at(left + 6, top + 1, trim(state.store_search_query ~= "" and state.store_search_query or "Search packages", width - 18), colors.lightGray, THEME.field)
  draw_button("store_search_prompt", left + width - 10, top + 1, "Search", nil, THEME.button)

  local filtered = {}
  for _, app in ipairs(STORE_APPS) do
    if contains_text(app.name .. " " .. app.description .. " " .. app.id, state.store_search_query) then
      table.insert(filtered, app)
    end
  end

  write_at(left + 1, top + 4, "Featured", colors.white, colors.black)
  local popular = {}
  for _, store_app in ipairs(filtered) do
    if store_app.popular then
      table.insert(popular, store_app)
    end
  end
  local card_width = math.max(10, math.min(14, math.floor((width - 4) / 3)))
  local card_height = 5
  for index, store_app in ipairs(popular) do
    if index > 3 then
      break
    end
    local card_left = left + 1 + (index - 1) * (card_width + 1)
    if card_left + card_width > left + width then
      break
    end
    local app = APPS[store_app.id] or APPS.store
    fill(card_left, top + 5, card_width, card_height, THEME.surface)
    draw_app_icon(card_left + 1, top + 6, app, 4, 3, nil, nil)
    write_at(card_left + 6, top + 6, trim(store_app.name, card_width - 7), colors.white, THEME.surface)
    write_at(card_left + 6, top + 7, trim(store_app.trust, card_width - 7), trust_color(store_app), THEME.surface)
    draw_button("store_open", card_left + 1, top + 8, "Open", store_app, colors.purple)
  end

  write_at(left + 1, top + 9, "Catalog", colors.white, colors.black)
  local row_top = top + 10
  for _, store_app in ipairs(filtered) do
    if row_top + 2 >= top + height then
      break
    end
    local app = APPS[store_app.id] or APPS.store
    local row_background = THEME.field
    fill(left + 1, row_top, width - 2, 3, row_background)
    draw_app_icon(left + 2, row_top, app, 4, 3, nil, nil)
    write_at(left + 8, row_top, trim(store_app.name, width - 22), colors.white, row_background)
    write_at(left + 8, row_top + 1, trim(store_app.description, width - 22), colors.lightGray, row_background)
    write_at(left + 8, row_top + 2, string.upper(store_app.trust), trust_color(store_app), row_background)
    local installed = store_app.trust == "built-in"
    draw_button(installed and "store_open" or "store_install", left + width - 11, row_top + 1, installed and "Open" or "Install", store_app, installed and colors.purple or THEME.button)
    row_top = row_top + 4
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
  local tabs_width = math.min(20, math.max(14, math.floor(width * 0.32)))
  fill(left, top, width, height, colors.black)
  fill(left, top, tabs_width, height, colors.gray)
  fill(left + tabs_width, top, width - tabs_width, height, THEME.field)
  write_at(left + 1, top, "Settings", colors.white, colors.gray)
  local tab_top = top + 2
  for _, tab in ipairs(SETTINGS_TABS) do
    local selected = state.settings_tab == tab.id
    local row_background = selected and THEME.window_title or colors.gray
    fill(left + 1, tab_top, tabs_width - 2, 1, row_background)
    write_at(left + 2, tab_top, trim(tab.label, tabs_width - 4), foreground_for_background(row_background), row_background)
    add_hit("settings_tab", left + 1, tab_top, tabs_width - 2, 1, tab.id)
    tab_top = tab_top + 2
  end

  local content_left = left + tabs_width + 2
  local content_top = top + 1
  local content_width = width - tabs_width - 3
  write_at(content_left, content_top, trim(state.settings_message, content_width), colors.cyan, THEME.field)
  if state.settings_tab == "general" then
    write_at(content_left, content_top + 2, "General", colors.white, THEME.field)
    write_at(content_left, content_top + 4, DISPLAY_VERSION, colors.lightGray, THEME.field)
    write_at(content_left, content_top + 5, "Screen " .. tostring(state.external.pixel_width) .. "x" .. tostring(state.external.pixel_height), colors.lightGray, THEME.field)
    write_at(content_left, content_top + 6, "Target 3x6 " .. tostring(TARGET_3X6_WIDTH) .. "x" .. tostring(TARGET_3X6_HEIGHT), colors.lightGray, THEME.field)
    write_at(content_left, content_top + 7, "Wallpaper " .. (state.wallpaper and "image" or tostring(state.wallpaper_error or "waiting")), colors.lightGray, THEME.field)
    draw_button("settings_gpu", content_left, content_top + 9, "Rescan display", nil, THEME.button)
  elseif state.settings_tab == "theme" then
    write_at(content_left, content_top + 2, "Theme", colors.white, THEME.field)
    write_at(content_left, content_top + 4, "Current: " .. tostring(state.theme_id or "linux"), colors.lightGray, THEME.field)
    local theme_top = content_top + 6
    for _, theme_id in ipairs(THEME_ORDER) do
      local preset = THEME_PRESETS[theme_id]
      if preset then
        draw_button("theme_set", content_left, theme_top, preset.name, theme_id, preset.color)
        theme_top = theme_top + 2
      end
    end
  elseif state.settings_tab == "time" then
    write_at(content_left, content_top + 2, "Time", colors.white, THEME.field)
    write_at(content_left, content_top + 4, "Current: " .. current_time_text(), colors.lightGray, THEME.field)
    write_at(content_left, content_top + 5, "Timezone: " .. timezone_label(), colors.lightGray, THEME.field)
    local button_left = content_left
    button_left = button_left + draw_button("time_decrease", button_left, content_top + 7, "-1 hour", nil, colors.gray) + 1
    button_left = button_left + draw_button("time_increase", button_left, content_top + 7, "+1 hour", nil, colors.gray) + 1
    draw_button("time_reset", button_left, content_top + 7, "UTC+3", nil, THEME.button)
  elseif state.settings_tab == "devices" then
    write_at(content_left, content_top + 2, "Devices", colors.white, THEME.field)
    local button_left = content_left
    button_left = button_left + draw_button("settings_monitor", button_left, content_top + 4, "Display", nil, colors.gray) + 1
    button_left = button_left + draw_button("settings_speaker", button_left, content_top + 4, "Speaker", nil, colors.gray) + 1
    draw_button("settings_printer", button_left, content_top + 4, "Printer", nil, colors.gray)
    local row_top = content_top + 7
    for _, row in ipairs(peripheral_rows()) do
      if row_top >= top + height then
        break
      end
      write_at(content_left, row_top, pad(row.name, 18), colors.white, THEME.field)
      write_at(content_left + 20, row_top, trim(row.kind, content_width - 21), colors.lightGray, THEME.field)
      row_top = row_top + 1
    end
  elseif state.settings_tab == "privacy" then
    write_at(content_left, content_top + 2, "Privacy & Security", colors.white, THEME.field)
    write_at(content_left, content_top + 4, "DockOS does not collect chat or private data.", colors.lightGray, THEME.field)
    write_at(content_left, content_top + 5, "App trust is shown in Store before install.", colors.lightGray, THEME.field)
  elseif state.settings_tab == "power" then
    write_at(content_left, content_top + 2, "Power", colors.white, THEME.field)
    local button_left = content_left
    button_left = button_left + draw_button("system_reboot", button_left, content_top + 4, "Reboot", nil, colors.orange) + 1
    draw_button("system_shutdown", button_left, content_top + 4, "Power off", nil, THEME.danger)
  end
end

local function draw_launcher(window_state)
  local left, top, width, height = content_rect(window_state)
  fill(left, top, width, height, colors.black)
  fill(left + 1, top, width - 2, 3, THEME.field)
  write_at(left + 2, top, "Applications", colors.orange, THEME.field)
  draw_icon_asset(left + 2, top + 1, 3, 1, "search_tile", "?", colors.lightGray, THEME.field)
  write_at(left + 6, top + 1, trim(state.app_search_query ~= "" and state.app_search_query or "Search installed apps", width - 18), colors.lightGray, THEME.field)
  draw_button("app_search_prompt", left + width - 10, top + 1, "Search", nil, THEME.button)
  if state.app_search_query ~= "" then
    draw_button("app_search_clear", left + width - 18, top + 1, "Clear", nil, colors.gray)
  end
  local apps = {}
  for app_id, app in pairs(APPS) do
    if contains_text(app.name .. " " .. app_id, state.app_search_query) then
      table.insert(apps, { id = app_id, app = app })
    end
  end
  table.sort(apps, function(left_app, right_app)
    return left_app.app.name < right_app.app.name
  end)
  local card_width = 14
  local card_height = 7
  local columns = math.max(1, math.floor((width - 2) / (card_width + 1)))
  for index, item in ipairs(apps) do
    local zero = index - 1
    local col = zero % columns
    local row = math.floor(zero / columns)
    local card_left = left + 1 + col * (card_width + 1)
    local card_top = top + 4 + row * (card_height + 1)
    if card_top + card_height > top + height then
      break
    end
    fill(card_left, card_top, card_width, card_height, THEME.surface)
    draw_app_icon(card_left + 5, card_top + 1, item.app, 4, 3, nil, nil)
    write_at(card_left + 1, card_top + 4, trim(item.app.name, card_width - 2), colors.white, THEME.surface)
    write_at(card_left + 1, card_top + 5, trim(item.id, card_width - 2), colors.lightGray, THEME.surface)
    add_hit("launcher_open", card_left, card_top, card_width, card_height, item.id)
  end
end

local function draw_blend(window_state)
  local left, top, width, height = content_rect(window_state)
  fill(left, top, width, height, colors.black)
  fill(left, top, width, 2, colors.gray)
  local cursor_left = left + 1
  cursor_left = cursor_left + draw_button("blend_mode_layout", cursor_left, top, "Layout", nil, state.blend_mode == "Layout" and colors.orange or colors.gray) + 1
  cursor_left = cursor_left + draw_button("blend_mode_model", cursor_left, top, "Model", nil, state.blend_mode == "Model" and colors.orange or colors.gray) + 1
  cursor_left = cursor_left + draw_button("blend_mode_render", cursor_left, top, "Render", nil, state.blend_mode == "Render" and colors.orange or colors.gray) + 1
  cursor_left = cursor_left + draw_button("blend_add_cube", cursor_left, top, "Cube", nil, colors.blue) + 1
  draw_button("blend_render", cursor_left, top, "Preview", nil, colors.green)

  local sidebar_width = math.min(18, math.max(12, math.floor(width * 0.24)))
  local timeline_height = 3
  local viewport_left = left + sidebar_width + 1
  local viewport_top = top + 3
  local viewport_width = math.max(16, width - sidebar_width - 2)
  local viewport_height = math.max(8, height - timeline_height - 4)
  fill(left, top + 2, sidebar_width, height - 2, THEME.field)
  fill(viewport_left, viewport_top, viewport_width, viewport_height, colors.black)
  write_at(left + 1, top + 3, "Scene", colors.orange, THEME.field)
  write_at(left + 1, top + 5, "Object", colors.lightGray, THEME.field)
  write_at(left + 1, top + 6, trim(state.blend_object, sidebar_width - 2), colors.white, THEME.field)
  write_at(left + 1, top + 8, "Mode", colors.lightGray, THEME.field)
  write_at(left + 1, top + 9, state.blend_mode, colors.white, THEME.field)
  write_at(left + 1, top + 11, "Tools", colors.lightGray, THEME.field)
  write_at(left + 1, top + 12, "Move Scale", colors.white, THEME.field)
  write_at(left + 1, top + 13, "Extrude Cut", colors.white, THEME.field)

  for row = 0, viewport_height - 1 do
    local row_top = viewport_top + row
    if row % 3 == 0 then
      fill(viewport_left, row_top, viewport_width, 1, colors.gray)
    end
  end
  for col = 0, viewport_width - 1, 6 do
    fill(viewport_left + col, viewport_top, 1, viewport_height, colors.gray)
  end
  local cx = viewport_left + math.floor(viewport_width / 2)
  local cy = viewport_top + math.floor(viewport_height / 2)
  write_at(cx - 5, cy - 3, "+------+")
  write_at(cx - 6, cy - 2, "/      /|")
  write_at(cx - 7, cy - 1, "+------+ |", colors.orange, nil)
  write_at(cx - 7, cy, "|      | +", colors.orange, nil)
  write_at(cx - 7, cy + 1, "|      |/", colors.orange, nil)
  write_at(cx - 7, cy + 2, "+------+")
  write_at(viewport_left + 1, viewport_top, "Viewport  Grid  Camera  Light", colors.lightGray, colors.black)
  if state.blend_mode == "Render" then
    fill(cx - 8, cy + 4, 18, 1, colors.orange)
    write_at(cx - 6, cy + 4, "Preview ready", colors.black, colors.orange)
  end

  local timeline_top = top + height - timeline_height
  fill(viewport_left, timeline_top, viewport_width, timeline_height, THEME.field)
  write_at(viewport_left + 1, timeline_top, "Timeline", colors.lightGray, THEME.field)
  fill(viewport_left + 1, timeline_top + 1, math.max(1, viewport_width - 2), 1, colors.gray)
  fill(viewport_left + 2, timeline_top + 1, math.max(1, math.floor((viewport_width - 4) * 0.35)), 1, colors.orange)
end

local function draw_terminal(window_state)
  terminal_boot()
  local left, top, width, height = content_rect(window_state)
  fill(left, top, width, height, THEME.field)
  local visible_rows = math.max(1, height - 2)
  local first_line = math.max(1, #state.terminal_lines - visible_rows + 1)
  local row_top = top
  for index = first_line, #state.terminal_lines do
    local line = state.terminal_lines[index]
    if row_top >= top + visible_rows then
      break
    end
    write_at(left + 1, row_top, trim(line.text, width - 2), line.color or colors.lightGray, THEME.field)
    row_top = row_top + 1
  end
  fill(left, top + height - 1, width, 1, colors.black)
  write_at(left + 1, top + height - 1, trim(state.terminal_cwd .. " $ " .. state.terminal_input .. "_", width - 2), colors.white, colors.black)
end

function draw_luma_tabs(left, top, width)
  fill(left, top, width, 1, colors.gray)
  local tab_left = left + 1
  for index, tab in ipairs(state.luma_tabs or {}) do
    if index > 5 or tab_left + 9 >= left + width then
      break
    end
    local active = index == state.luma_active_tab
    local background = active and colors.lightGray or colors.gray
    fill(tab_left, top, 9, 1, background)
    write_at(tab_left + 1, top, trim(tab.title or "Tab", 6), active and colors.black or colors.white, background)
    write_at(tab_left + 7, top, "x", active and colors.gray or colors.lightGray, background)
    add_hit("luma_tab_select", tab_left, top, 7, 1, index)
    add_hit("luma_tab_close", tab_left + 7, top, 1, 1, index)
    tab_left = tab_left + 10
  end
  draw_button("luma_new_tab", math.min(left + width - 4, tab_left), top, "+", nil, colors.lightGray)
end

function draw_luma_toolbar(left, top, width)
  fill(left, top, width, 1, colors.lightGray)
  draw_button("luma_back", left + 1, top, "<", nil, colors.gray)
  draw_button("luma_home", left + 4, top, "^", nil, colors.gray)
  draw_button("luma_reload", left + 7, top, "R", nil, colors.gray)
  draw_inline_field(left + 10, top, math.max(12, width - 18), "luma_query", "Search or enter address", colors.black)
  draw_button("luma_creator", left + width - 6, top, "Web", nil, colors.purple)
end

function draw_luma_site_preview(left, top, width, height, site)
  fill(left, top, width, height, colors.white)
  fill(left, top, width, 2, colors.lightGray)
  write_at(left + 2, top, trim(site.name or "Untitled Site", width - 4), colors.black, colors.lightGray)
  write_at(left + 2, top + 1, trim(luma_site_domain(site), width - 4), colors.gray, colors.lightGray)
  write_at(left + 2, top + 3, trim(site.title or site.name or "Welcome", width - 4), colors.black, colors.white)
  local row_top = top + 5
  for _, element in ipairs(site.elements or {}) do
    if row_top >= top + height - 1 then
      break
    end
    local marker = element.kind == "heading" and "# " or "- "
    write_at(left + 2, row_top, trim(marker .. tostring(element.text or ""), width - 4), colors.gray, colors.white)
    row_top = row_top + 1
  end
  for _, line in ipairs(wrap_text(site.body or "", width - 4)) do
    if row_top >= top + height - 1 then
      break
    end
    write_at(left + 2, row_top, trim(line, width - 4), colors.gray, colors.white)
    row_top = row_top + 1
  end
end

function draw_luma_creator(left, top, width, height)
  fill(left, top, width, height, colors.black)
  fill(left, top, width, 1, colors.purple)
  write_at(left + 1, top, "Luma Web Creator", colors.white, colors.purple)
  draw_button("luma_publish", left + width - 10, top, "Publish", nil, colors.orange)
  local edit_width = math.min(28, math.max(18, math.floor(width * 0.46)))
  local preview_left = left + edit_width + 1
  local preview_width = math.max(12, width - edit_width - 1)
  fill(left, top + 1, edit_width, height - 1, THEME.field)
  write_at(left + 1, top + 1, "Site name", colors.orange, THEME.field)
  draw_inline_field(left + 1, top + 2, edit_width - 2, "luma_creator_name", "RoadRover Official Site", colors.black)
  write_at(left + 1, top + 3, "Username / domain", colors.orange, THEME.field)
  draw_inline_field(left + 1, top + 4, edit_width - 2, "luma_creator_slug", "roadrover-official-site", colors.black)
  local tld_left = left + 1
  local tld_top = top + 5
  for _, tld in ipairs(state.luma_tlds or {}) do
    if tld_left + #tld + 2 >= left + edit_width then
      tld_left = left + 1
      tld_top = tld_top + 1
    end
    if tld_top > top + 7 then
      break
    end
    tld_left = tld_left + draw_button("luma_tld", tld_left, tld_top, tld, tld, tld == state.luma_creator_tld and colors.orange or colors.gray)
  end
  write_at(left + 1, top + 7, trim(luma_domain(state.luma_creator_slug, state.luma_creator_tld), edit_width - 2), colors.lightGray, THEME.field)
  draw_inline_field(left + 1, top + 8, edit_width - 2, "luma_creator_title", "Headline", colors.black)
  draw_inline_field(left + 1, top + 9, edit_width - 2, "luma_creator_body", "Page text", colors.black)
  draw_button("luma_add_heading", left + 1, top + 10, "Heading", nil, colors.purple)
  draw_button("luma_add_text", left + 10, top + 10, "Text", nil, colors.purple)
  draw_button("luma_clear", left + 17, top + 10, "Clear", nil, colors.gray)

  draw_luma_site_preview(preview_left, top + 1, preview_width, height - 1, {
    name = state.luma_creator_name,
    slug = state.luma_creator_slug,
    tld = state.luma_creator_tld,
    title = state.luma_creator_title,
    body = state.luma_creator_body,
    elements = state.luma_creator_elements,
  })
end

function draw_luma_search(left, top, width, height)
  fill(left, top, width, height, colors.white)
  write_at(left + 2, top, "Search results", colors.black, colors.white)
  write_at(left + 17, top, trim(state.luma_query, math.max(1, width - 20)), colors.gray, colors.white)
  local row_top = top + 2
  fill(left + 2, row_top, width - 4, 3, colors.lightGray)
  write_at(left + 4, row_top, "Luma Web Creator", colors.black, colors.lightGray)
  write_at(left + 4, row_top + 1, "Create and publish a Luma site.", colors.gray, colors.lightGray)
  draw_button("luma_creator", left + width - 11, row_top + 1, "Open", nil, colors.purple)
  row_top = row_top + 4
  for _, site in ipairs(state.luma_sites or {}) do
    if row_top + 2 >= top + height then
      break
    end
    fill(left + 2, row_top, width - 4, 3, colors.lightGray)
    write_at(left + 4, row_top, trim(site.name, width - 10), colors.black, colors.lightGray)
    write_at(left + 4, row_top + 1, trim(luma_site_domain(site), width - 10), colors.gray, colors.lightGray)
    add_hit("luma_open_site", left + 2, row_top, width - 4, 3, luma_site_domain(site))
    row_top = row_top + 4
  end
end

function draw_luma_home(left, top, width, height)
  fill(left, top, width, height, colors.black)
  local logo_left = left + math.max(1, math.floor(width / 2) - 3)
  write_at(logo_left, top + 1, "Luma", colors.purple, colors.black)
  write_at(left + math.max(2, math.floor(width / 2) - 10), top + 2, "Anything you Imagine", colors.lightGray, colors.black)
  local search_width = math.min(42, math.max(16, width - 10))
  local search_left = left + math.max(2, math.floor((width - search_width) / 2))
  draw_inline_field(search_left, top + 4, search_width, "luma_query", "Anything you Imagine", colors.gray)
  draw_button("luma_search", search_left + search_width - 5, top + 5, "Go", nil, colors.purple)
  write_at(left + 2, top + 7, "Pinned", colors.lightGray, colors.black)
  draw_app_icon(left + 2, top + 8, APPS.luma, 4, 3, "luma_creator", nil)
  draw_app_icon(left + 8, top + 8, APPS.studio, 4, 3, "dock_pinned", "studio")
  draw_app_icon(left + 14, top + 8, APPS.store, 4, 3, "dock_pinned", "store")
  local site = state.luma_sites and state.luma_sites[1]
  if site then
    fill(left + 21, top + 8, 4, 3, colors.orange)
    write_at(left + 22, top + 9, "RR", colors.black, colors.orange)
    add_hit("luma_open_site", left + 21, top + 8, 4, 3, luma_site_domain(site))
  end
end

function draw_luma(window_state)
  local left, top, width, height = content_rect(window_state)
  local tab = luma_current_tab()
  if state.focused_field ~= "luma_query" then
    state.luma_query = tab.url or ""
  end
  draw_luma_tabs(left, top, width)
  draw_luma_toolbar(left, top + 1, width)
  local content_top = top + 2
  local content_height = math.max(1, height - 2)
  if tab.page == "creator" then
    draw_luma_creator(left, content_top, width, content_height)
  elseif tab.page == "site" and tab.site then
    draw_luma_site_preview(left, content_top, width, content_height, tab.site)
  elseif tab.page == "search" then
    draw_luma_search(left, content_top, width, content_height)
  else
    draw_luma_home(left, content_top, width, content_height)
  end
end

function draw_studio_preview(left, top, width, height)
  fill(left, top, width, height, colors.lightGray)
  write_at(left + 1, top, "Preview", colors.black, colors.lightGray)
  if state.studio_preview == "pong" then
    local field_left = left + 2
    local field_top = top + 2
    local field_width = math.max(10, width - 4)
    local field_height = math.max(5, height - 4)
    fill(field_left, field_top, field_width, field_height, colors.black)
    for row = 1, field_height do
      if row % 2 == 0 then
        write_at(field_left + math.floor(field_width / 2), field_top + row - 1, "|", colors.gray, colors.black)
      end
    end
    write_at(field_left + 2, field_top + 2, "|", colors.white, colors.black)
    write_at(field_left + field_width - 3, field_top + field_height - 3, "|", colors.white, colors.black)
    write_at(field_left + math.floor(field_width / 2), field_top + math.floor(field_height / 2), "o", colors.orange, colors.black)
  elseif state.studio_preview == "music" then
    fill(left + 2, top + 2, math.max(10, width - 4), math.max(5, height - 4), colors.gray)
    write_at(left + 4, top + 3, "Dock Beats", colors.white, colors.gray)
    write_at(left + 4, top + 5, ">> ===o----", colors.orange, colors.gray)
    draw_button("studio_run", left + 4, top + 7, "Play", nil, colors.orange)
  else
    local panel_left = left + 2
    local panel_top = top + 2
    local panel_width = math.max(10, width - 4)
    fill(panel_left, panel_top, panel_width, math.max(4, height - 4), colors.white)
    local row_top = panel_top + 1
    for _, element in ipairs(state.studio_elements or {}) do
      if row_top >= top + height - 1 then
        break
      end
      if element.kind == "shape" then
        fill(panel_left + 1, row_top, math.max(6, math.floor(panel_width * 0.45)), 1, colors.orange)
        write_at(panel_left + 2, row_top, trim(element.label or "Shape", panel_width - 4), colors.black, colors.orange)
      elseif element.kind == "textinput" then
        fill(panel_left + 1, row_top, math.max(8, math.floor(panel_width * 0.55)), 1, colors.lightGray)
        write_at(panel_left + 2, row_top, trim(element.label or "Input", panel_width - 4), colors.gray, colors.lightGray)
      elseif element.kind == "image" then
        fill(panel_left + 1, row_top, 6, 2, colors.blue)
        write_at(panel_left + 8, row_top, trim(element.label or "Image", panel_width - 9), colors.gray, colors.white)
        row_top = row_top + 1
      else
        write_at(panel_left + 1, row_top, trim(element.label or "Text", panel_width - 2), colors.black, colors.white)
      end
      row_top = row_top + 1
    end
  end
end

function draw_studio(window_state)
  local left, top, width, height = content_rect(window_state)
  fill(left, top, width, height, colors.black)
  fill(left, top, width, 2, colors.gray)
  local cursor_left = left + 1
  cursor_left = cursor_left + draw_button("studio_file", cursor_left, top, "File", nil, colors.gray) + 1
  cursor_left = cursor_left + draw_button("studio_edit", cursor_left, top, "Edit", nil, colors.gray) + 1
  cursor_left = cursor_left + draw_button("studio_examples_toggle", cursor_left, top, "Examples", nil, colors.orange) + 1
  cursor_left = cursor_left + draw_button("studio_run", cursor_left, top, "Run", nil, colors.lime) + 1
  draw_button("studio_add", cursor_left, top, "Shape", "shape", colors.blue)
  cursor_left = cursor_left + 8
  draw_button("studio_add", cursor_left, top, "Input", "textinput", colors.blue)
  cursor_left = cursor_left + 8
  draw_button("studio_add", cursor_left, top, "Image", "image", colors.blue)

  if state.studio_examples_open then
    fill(left + 13, top + 1, 18, 4, colors.black)
    draw_button("studio_example", left + 14, top + 1, "Blank", "blank", colors.gray)
    draw_button("studio_example", left + 14, top + 2, "Ping Pong", "pong", colors.gray)
    draw_button("studio_example", left + 14, top + 3, "Music Player", "music", colors.gray)
  end

  local editor_width = math.max(20, math.floor(width * 0.48))
  local preview_left = left + editor_width + 1
  local preview_width = math.max(12, width - editor_width - 1)
  fill(left, top + 2, editor_width, height - 2, THEME.field)
  fill(preview_left, top + 2, preview_width, height - 2, colors.lightGray)
  write_at(left + 1, top + 2, "Code", colors.orange, THEME.field)
  draw_inline_field(left + 1, top + 3, editor_width - 2, "studio_code", "Write app script", colors.black)
  local lines = wrap_text(state.studio_code or "", editor_width - 2)
  local line_top = top + 5
  for index, line in ipairs(lines) do
    if line_top >= top + height - 1 then
      break
    end
    write_at(left + 1, line_top, trim(tostring(index) .. "  " .. line, editor_width - 2), colors.lightGray, THEME.field)
    line_top = line_top + 1
  end
  write_at(left + 1, top + height - 1, trim(state.studio_message or "", editor_width - 2), colors.lime, THEME.field)
  draw_studio_preview(preview_left, top + 2, preview_width, height - 2)
end

local function draw_window_content(window_state)
  if window_state.app == "launcher" then
    draw_launcher(window_state)
  elseif window_state.app == "finder" then
    draw_finder(window_state)
  elseif window_state.app == "store" then
    draw_store(window_state)
  elseif window_state.app == "docs" then
    draw_documents(window_state)
  elseif window_state.app == "paint" then
    draw_paint(window_state)
  elseif window_state.app == "settings" then
    draw_settings(window_state)
  elseif window_state.app == "blend" then
    draw_blend(window_state)
  elseif window_state.app == "studio" then
    draw_studio(window_state)
  elseif window_state.app == "terminal" then
    draw_terminal(window_state)
  elseif window_state.app == "luma" then
    draw_luma(window_state)
  end
end

local function draw_windows()
  for _, window_id in ipairs(state.window_order) do
    local window_state = state.windows[window_id]
    if window_state and not window_state.minimized then
      draw_window_frame(window_state)
      draw_window_content(window_state)
    end
  end
end

local function active_fullscreen_window()
  local window_state = state.windows[state.active_window]
  return window_state and window_state.fullscreen and not window_state.minimized
end

function draw_toast()
  if not state.toast or state.toast == "" then
    return
  end
  local screen_width, screen_height = screen_size()
  local text = trim(state.toast, screen_width - 12)
  local left = math.max(2, screen_width - #text - 3)
  fill(left, screen_height - 4, #text + 2, 1, colors.black)
  write_at(left + 1, screen_height - 4, text, colors.cyan, colors.black)
end

function draw_modal()
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

function draw_input()
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
  cursor_left = cursor_left + draw_button("input_ok", cursor_left, button_top, "Apply", nil, THEME.button) + 2
  draw_button("input_cancel", cursor_left, button_top, "Cancel", nil, colors.gray)
end

function color_rgb(color)
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

function gpu_rect(gpu, display, left, top, width, height, color)
  local rgb = color_rgb(color)
  if gpu.fillRect then
    gpu.fillRect(display, left, top, width, height, rgb[1], rgb[2], rgb[3])
  end
end

function gpu_text(gpu, display, text, left, top, color, size, style)
  local rgb = color_rgb(color)
  if gpu.drawText then
    gpu.drawText(display, tostring(text or ""), left, top, rgb[1], rgb[2], rgb[3], "Arial", size or 14, style or "bold")
  end
end

function color_value(color)
  local rgb = color_rgb(color)
  return rgb[1] * 65536 + rgb[2] * 256 + rgb[3]
end

function rgb_value(red, green, blue)
  red = math.max(0, math.min(255, math.floor(red or 0)))
  green = math.max(0, math.min(255, math.floor(green or 0)))
  blue = math.max(0, math.min(255, math.floor(blue or 0)))
  return red * 65536 + green * 256 + blue
end

function lerp(left, right, amount)
  return left + (right - left) * amount
end

function lerp_rgb(left, right, amount)
  return rgb_value(
    lerp(left[1], right[1], amount),
    lerp(left[2], right[2], amount),
    lerp(left[3], right[3], amount)
  )
end

function peripheral_type_text(name)
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

function find_peripheral(predicate)
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

function is_tom_gpu(_, device, kind)
  if type(device.refreshSize) == "function" and type(device.sync) == "function" then
    return type(device.filledRectangle) == "function" or type(device.drawText) == "function" or type(device.fill) == "function"
  end
  return kind:find("gpu", 1, true) and type(device.filledRectangle) == "function"
end

function is_tom_keyboard(_, device, kind)
  return type(device.setFireNativeEvents) == "function" or kind:find("keyboard", 1, true) ~= nil
end

function is_external_monitor(_, device, kind)
  return kind:find("monitor", 1, true) ~= nil and type(device.setFireNativeEvents) ~= "function"
end

function refresh_external_size()
  local gpu = state.external.gpu
  local pixel_width = DEFAULT_EXTERNAL_WIDTH * CELL_WIDTH
  local pixel_height = DEFAULT_EXTERNAL_HEIGHT * CELL_HEIGHT
  if gpu then
    if gpu.refreshSize then
      pcall(gpu.refreshSize)
    end
    if gpu.setSize then
      pcall(gpu.setSize, 64)
    end
    sleep(0)
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

function initialize_tom_gpu(force)
  local gpu = state.external.gpu
  if not gpu then
    state.external.gpu_ready = false
    state.external.gpu_error = "GPU not found"
    return false
  end
  if not force and state.external.initialized_gpu == state.external.gpu_name and state.external.gpu_ready then
    return true
  end
  local ok, err = pcall(function()
    if gpu.refreshSize then
      gpu.refreshSize()
    end
    if gpu.setSize then
      gpu.setSize(64)
    end
    sleep(0.25)
    if gpu.fill then
      gpu.fill(0)
    end
    if gpu.sync then
      gpu.sync()
    end
  end)
  state.external.initialized_gpu = state.external.gpu_name
  state.external.gpu_ready = ok
  state.external.gpu_error = ok and nil or tostring(err)
  refresh_external_size()
  return ok
end

function scan_external_peripherals()
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
  initialize_tom_gpu(false)

  local parts = {}
  table.insert(parts, gpu_name and ("GPU " .. gpu_name .. (state.external.gpu_ready and " ready" or " error")) or "GPU waiting")
  table.insert(parts, keyboard_name and ("Keyboard " .. keyboard_name) or "Keyboard waiting")
  if monitor_name then
    table.insert(parts, "Monitor " .. monitor_name)
  elseif gpu_name and state.external.pixel_width > 0 and state.external.pixel_height > 0 then
    table.insert(parts, "Bitmap screen " .. tostring(state.external.pixel_width) .. "x" .. tostring(state.external.pixel_height))
  else
    table.insert(parts, "Monitor waiting")
  end
  state.settings_message = table.concat(parts, " | ")
end

function start_peripheral_scan_timer()
  if os and os.startTimer then
    state.peripheral_scan_timer = os.startTimer(PERIPHERAL_SCAN_SECONDS)
  end
end

function tom_fill_rect(gpu, left, top, width, height, color)
  left = math.max(1, math.floor(tonumber(left) or 1))
  top = math.max(1, math.floor(tonumber(top) or 1))
  width = math.floor(tonumber(width) or 0)
  height = math.floor(tonumber(height) or 0)
  width = math.min(width, math.max(0, state.external.pixel_width - left + 1))
  height = math.min(height, math.max(0, state.external.pixel_height - top + 1))
  if width <= 0 or height <= 0 then
    return
  end
  if gpu.filledRectangle then
    gpu.filledRectangle(left, top, width, height, color_value(color))
  end
end

function tom_fill_rgb(gpu, left, top, width, height, rgb)
  left = math.max(1, math.floor(tonumber(left) or 1))
  top = math.max(1, math.floor(tonumber(top) or 1))
  width = math.floor(tonumber(width) or 0)
  height = math.floor(tonumber(height) or 0)
  width = math.min(width, math.max(0, state.external.pixel_width - left + 1))
  height = math.min(height, math.max(0, state.external.pixel_height - top + 1))
  if width <= 0 or height <= 0 or not gpu.filledRectangle then
    return
  end
  gpu.filledRectangle(left, top, width, height, rgb)
end

function tom_round_rect(gpu, left, top, width, height, radius, rgb)
  radius = math.max(0, math.min(math.floor(radius or 0), math.floor(math.min(width, height) / 2)))
  if radius <= 1 then
    tom_fill_rgb(gpu, left, top, width, height, rgb)
    return
  end
  tom_fill_rgb(gpu, left + radius, top, width - radius * 2, height, rgb)
  tom_fill_rgb(gpu, left, top + radius, width, height - radius * 2, rgb)
  for offset = 0, radius - 1 do
    local inset = math.floor((radius - offset) * 0.55)
    local row_width = width - inset * 2
    tom_fill_rgb(gpu, left + inset, top + offset, row_width, 1, rgb)
    tom_fill_rgb(gpu, left + inset, top + height - offset - 1, row_width, 1, rgb)
  end
end

function tom_draw_text(gpu, left, top, text, foreground, background)
  if not gpu.drawText then
    return
  end
  left = math.max(1, math.min(state.external.pixel_width - 1, math.floor(tonumber(left) or 1)))
  top = math.max(1, math.min(state.external.pixel_height - 1, math.floor(tonumber(top) or 1)))
  local bg = background and color_value(background) or -1
  local ok = pcall(gpu.drawText, left, top, tostring(text or ""), color_value(foreground or colors.white), bg, 1, 0)
  if not ok and background then
    pcall(gpu.drawText, left, top, tostring(text or ""), color_value(foreground or colors.white), -1, 1)
  elseif not ok then
    pcall(gpu.drawText, left, top, tostring(text or ""))
  end
end

local TINY_FONT = {
  ["0"] = { "111", "101", "101", "101", "111" },
  ["1"] = { "010", "110", "010", "010", "111" },
  ["2"] = { "111", "001", "111", "100", "111" },
  ["3"] = { "111", "001", "111", "001", "111" },
  ["4"] = { "101", "101", "111", "001", "001" },
  ["5"] = { "111", "100", "111", "001", "111" },
  ["6"] = { "111", "100", "111", "101", "111" },
  ["7"] = { "111", "001", "010", "010", "010" },
  ["8"] = { "111", "101", "111", "101", "111" },
  ["9"] = { "111", "101", "111", "001", "111" },
  [":"] = { "000", "010", "000", "010", "000" },
  ["A"] = { "010", "101", "111", "101", "101" },
  ["C"] = { "111", "100", "100", "100", "111" },
  ["D"] = { "110", "101", "101", "101", "110" },
  ["K"] = { "101", "110", "100", "110", "101" },
  ["M"] = { "101", "111", "111", "101", "101" },
  ["O"] = { "111", "101", "101", "101", "111" },
  ["P"] = { "110", "101", "110", "100", "100" },
  ["S"] = { "111", "100", "111", "001", "111" },
  ["T"] = { "111", "010", "010", "010", "010" },
  ["U"] = { "101", "101", "101", "101", "111" },
  ["Y"] = { "101", "101", "010", "010", "010" },
  ["+"] = { "000", "010", "111", "010", "000" },
  ["-"] = { "000", "000", "111", "000", "000" },
  [" "] = { "000", "000", "000", "000", "000" },
}

function tom_tiny_text(gpu, left, top, text, color, scale)
  scale = math.max(1, math.floor(tonumber(scale) or 1))
  local rgb = color_value(color or colors.white)
  local cursor = math.floor(tonumber(left) or 1)
  local base_top = math.floor(tonumber(top) or 1)
  for index = 1, #tostring(text or "") do
    local char = tostring(text):sub(index, index):upper()
    local glyph = TINY_FONT[char] or TINY_FONT[" "]
    for row = 1, #glyph do
      local line = glyph[row]
      for col = 1, #line do
        if line:sub(col, col) == "1" then
          tom_fill_rgb(gpu, cursor + (col - 1) * scale, base_top + (row - 1) * scale, scale, scale, rgb)
        end
      end
    end
    cursor = cursor + 4 * scale
  end
end

function render_wallpaper(gpu)
  local function wallpaper_candidates()
    local screen_width = state.external.pixel_width
    local screen_height = state.external.pixel_height
    return {
      path_join(ASSETS_DIR, "wallpaper-" .. tostring(screen_width) .. "x" .. tostring(screen_height) .. ".png"),
      path_join(ASSETS_DIR, "wallpaper-384x192.png"),
      path_join(ASSETS_DIR, "wallpaper-382x192.png"),
      path_join(ASSETS_DIR, "wallpaper-640x576.png"),
      path_join(ASSETS_DIR, "wallpaper-480x432.png"),
      path_join(ASSETS_DIR, "wallpaper-320x288.png"),
      path_join(ASSETS_DIR, "wallpaper-320x216.png"),
      path_join(ASSETS_DIR, "wallpaper-160x144.png"),
      path_join(ASSETS_DIR, "wallpaper.png"),
      "/dock/wallpaper.png",
    }
  end

  local function load_wallpaper()
    if not gpu.decodeImage or not gpu.drawImage then
      state.wallpaper_error = "GPU decodeImage/drawImage unavailable"
      return nil
    end
    local screen_key = tostring(state.external.gpu_name) .. ":" .. tostring(state.external.pixel_width) .. "x" .. tostring(state.external.pixel_height)
    for _, path in ipairs(wallpaper_candidates()) do
      if fs.exists(path) and not fs.isDir(path) then
        local key = screen_key .. ":" .. path .. ":" .. tostring(fs.getSize(path) or 0)
        if state.wallpaper and state.wallpaper_key == key then
          return state.wallpaper
        end
        if state.wallpaper and state.wallpaper.free then
          pcall(state.wallpaper.free)
        end
        state.wallpaper = nil
        state.wallpaper_key = nil
        local buffer, buffer_err = read_binary_into_gpu_buffer(gpu, path)
        if not buffer then
          state.wallpaper_error = tostring(buffer_err)
        else
          local ok, image = pcall(function()
            return gpu.decodeImage(buffer.ref())
          end)
          pcall(buffer.free)
          if ok and image then
            local image_width = image.getWidth and image.getWidth() or 0
            local image_height = image.getHeight and image.getHeight() or 0
            if image_width <= state.external.pixel_width and image_height <= state.external.pixel_height then
              state.wallpaper = image
              state.wallpaper_key = key
              state.wallpaper_error = nil
              return image
            end
            if image.free then
              pcall(image.free)
            end
            state.wallpaper_error = "wallpaper larger than screen"
          else
            state.wallpaper_error = tostring(image)
          end
        end
      end
    end
    state.wallpaper_error = state.wallpaper_error or "missing /dock/assets/wallpaper*.png"
    return nil
  end

  local image = load_wallpaper()
  if image then
    local image_width = image.getWidth and image.getWidth() or state.external.pixel_width
    local image_height = image.getHeight and image.getHeight() or state.external.pixel_height
    local left = math.floor((state.external.pixel_width - image_width) / 2) + 1
    local top = math.floor((state.external.pixel_height - image_height) / 2) + 1
    if image_width < state.external.pixel_width or image_height < state.external.pixel_height then
      gpu.fill(rgb_value(10, 15, 18))
    end
    local ok = pcall(gpu.drawImage, left, top, image.ref())
    if ok then
      return
    end
  end

  if gpu.fill then
    gpu.fill(rgb_value(10, 15, 18))
    return
  end
end

function load_icon_image(gpu, path)
  if not gpu.decodeImage or not gpu.drawImage or not path or not fs.exists(path) or fs.isDir(path) then
    return nil
  end
  local key = path .. ":" .. tostring(fs.getSize(path) or 0)
  local cached = state.icon_cache[path]
  if cached and cached.key == key and cached.image then
    return cached.image
  end
  if cached and cached.image and cached.image.free then
    pcall(cached.image.free)
  end
  local buffer = read_binary_into_gpu_buffer(gpu, path)
  if not buffer then
    state.icon_cache[path] = nil
    return nil
  end
  local ok, image = pcall(function()
    return gpu.decodeImage(buffer.ref())
  end)
  pcall(buffer.free)
  if not ok or not image then
    state.icon_cache[path] = nil
    return nil
  end
  state.icon_cache[path] = { key = key, image = image }
  return image
end

function render_image_op(gpu, op, pixel_left, pixel_top, pixel_width, pixel_height)
  pixel_width = pixel_width or op.width * state.external.cell_width
  pixel_height = pixel_height or op.height * state.external.cell_height
  if op.background then
    tom_fill_rect(gpu, pixel_left, pixel_top, pixel_width, pixel_height, op.background)
  end
  local image = load_icon_image(gpu, op.path)
  if image then
    local image_width = image.getWidth and image.getWidth() or 0
    local image_height = image.getHeight and image.getHeight() or 0
    if image_width <= pixel_width and image_height <= pixel_height then
      local image_left = pixel_left + math.floor((pixel_width - image_width) / 2)
      local image_top = pixel_top + math.floor((pixel_height - image_height) / 2)
      if pcall(gpu.drawImage, image_left, image_top, image.ref()) then
        return
      end
    end
  end
  if op.fallback and op.fallback ~= "" then
    tom_draw_text(gpu, pixel_left, pixel_top, op.fallback, op.foreground or colors.white, op.background)
  end
end

function should_skip_highres_op(op)
  if op.kind ~= "fill" then
    return false
  end
  if op.left == 1 and op.top == 1 and op.width >= state.virtual_width and op.height >= state.virtual_height then
    return true
  end
  return false
end

function op_pixel_rect(op)
  local op_left = tonumber(op.left) or 1
  local op_top = tonumber(op.top) or 1
  local op_width = tonumber(op.width) or math.max(1, #(op.text or op.fallback or ""))
  local op_height = tonumber(op.height) or 1
  local pixel_left = (op_left - 1) * state.external.cell_width + 1
  local pixel_top = (op_top - 1) * state.external.cell_height + 1
  local pixel_width = op_width * state.external.cell_width
  local pixel_height = op_height * state.external.cell_height
  if op_left + op_width - 1 >= state.virtual_width then
    pixel_width = state.external.pixel_width - pixel_left + 1
  end
  if op_top + op_height - 1 >= state.virtual_height then
    pixel_height = state.external.pixel_height - pixel_top + 1
  end
  return pixel_left, pixel_top, math.max(0, pixel_width), math.max(0, pixel_height)
end

function render_gpu_error(gpu, err)
  state.external.gpu_error = tostring(err or "render failed")
  if gpu.fill then
    pcall(gpu.fill, rgb_value(0, 0, 0))
  else
    tom_fill_rgb(gpu, 1, 1, state.external.pixel_width, state.external.pixel_height, rgb_value(0, 0, 0))
  end
  tom_draw_text(gpu, 18, 22, "DockOS render error", colors.red, nil)
  tom_draw_text(gpu, 18, 42, trim(state.external.gpu_error, 70), colors.white, nil)
  tom_draw_text(gpu, 18, 62, "Run: dock doctor", colors.lightGray, nil)
  if gpu.sync then
    pcall(gpu.sync)
  end
end

function render_tom_gpu()
  local gpu = state.external.gpu
  if not state.headless or not gpu then
    return
  end
  local ok, err = pcall(function()
    initialize_tom_gpu(false)
    if state.wallpaper or state.wallpaper_attempted then
      render_wallpaper(gpu)
    else
      state.wallpaper_attempted = true
      if gpu.fill then
        gpu.fill(rgb_value(10, 15, 18))
      else
        tom_fill_rgb(gpu, 1, 1, state.external.pixel_width, state.external.pixel_height, rgb_value(10, 15, 18))
      end
    end
    for _, op in ipairs(state.frame_ops or {}) do
      if should_skip_highres_op(op) and state.wallpaper then
        -- wallpaper already drew this surface
      else
        local pixel_left, pixel_top, pixel_width, pixel_height = op_pixel_rect(op)
        if op.kind == "fill" then
          tom_fill_rect(gpu, pixel_left, pixel_top, pixel_width, pixel_height, op.background)
        elseif op.kind == "text" then
          tom_draw_text(gpu, pixel_left, pixel_top, op.text, op.foreground, op.background)
        elseif op.kind == "image" then
          render_image_op(gpu, op, pixel_left, pixel_top, pixel_width, pixel_height)
        elseif op.kind == "pixel_image" then
          render_image_op(gpu, op, op.left, op.top, op.width, op.height)
        elseif op.kind == "pixel_fill" then
          tom_fill_rect(gpu, op.left, op.top, op.width, op.height, op.color)
        elseif op.kind == "pixel_round" then
          tom_round_rect(gpu, op.left, op.top, op.width, op.height, op.radius or 3, color_value(op.color or colors.black))
        elseif op.kind == "tiny_text" then
          tom_tiny_text(gpu, op.left, op.top, op.text, op.color, op.scale)
        end
      end
    end
    if gpu.sync then
      gpu.sync()
    end
  end)
  if not ok then
    render_gpu_error(gpu, err)
  end
end

function select_boot_logo(gpu, screen_width, screen_height)
  local candidates = {
    { path = path_join(ASSETS_DIR, "brand/dock_boot_logo_440.png"), width = 440, height = 190 },
    { path = path_join(ASSETS_DIR, "brand/dock_boot_logo_320.png"), width = 320, height = 138 },
    { path = path_join(ASSETS_DIR, "brand/dock_boot_logo.png"), width = 320, height = 138 },
    { path = path_join(ASSETS_DIR, "brand/dock_boot_logo_220.png"), width = 220, height = 95 },
    { path = path_join(ASSETS_DIR, "brand/dock_boot_logo_128.png"), width = 128, height = 55 },
  }
  local max_width = math.floor(screen_width * 0.82)
  local max_height = math.floor(screen_height * 0.45)
  for _, candidate in ipairs(candidates) do
    if candidate.width > max_width or candidate.height > max_height then
      candidate.skip = true
    end
  end
  for _, candidate in ipairs(candidates) do
    if not candidate.skip and fs.exists(candidate.path) and not fs.isDir(candidate.path) then
      local image = load_icon_image(gpu, candidate.path)
      if image then
        local width = image.getWidth and image.getWidth() or candidate.width
        local height = image.getHeight and image.getHeight() or candidate.height
        if width > 0 and height > 0 and width <= max_width and height <= max_height then
          return image, width, height
        end
      end
    end
  end
  return nil, 0, 0
end

function show_boot_splash()
  local gpu = state.external.gpu
  if not gpu or state.boot_splash_done then
    return
  end
  state.boot_splash_done = true
  pcall(function()
    initialize_tom_gpu(false)
    for step = 1, 5 do
      local screen_width = state.external.pixel_width
      local screen_height = state.external.pixel_height
      if gpu.fill then
        gpu.fill(rgb_value(0, 0, 0))
      else
        tom_fill_rgb(gpu, 1, 1, screen_width, screen_height, rgb_value(0, 0, 0))
      end

      local logo, logo_width, logo_height = select_boot_logo(gpu, screen_width, screen_height)
      local logo_top = math.max(1, math.floor((screen_height - logo_height) / 2) - math.floor(screen_height * 0.08))
      if logo then
        local logo_left = math.floor((screen_width - logo_width) / 2) + 1
        pcall(gpu.drawImage, logo_left, logo_top, logo.ref())
      else
        local text_left = math.max(1, math.floor(screen_width / 2) - 18)
        logo_top = math.max(1, math.floor(screen_height / 2) - 16)
        tom_draw_text(gpu, text_left, logo_top, "DockOS", colors.white, nil)
        logo_height = 16
      end

      local bar_width = math.max(48, math.min(180, math.floor(screen_width * 0.42)))
      local bar_height = math.max(2, math.min(6, math.floor(screen_height * 0.012)))
      local bar_left = math.floor((screen_width - bar_width) / 2) + 1
      local bar_top = math.min(screen_height - bar_height, logo_top + logo_height + math.max(10, math.floor(screen_height * 0.06)))
      local progress_width = math.max(1, math.floor(bar_width * step / 5))
      tom_fill_rgb(gpu, bar_left, bar_top, progress_width, bar_height, rgb_value(255, 255, 255))

      if gpu.sync then
        gpu.sync()
      end
      sleep(0.08)
    end
  end)
end

function draw_directgpu()
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
  local fullscreen_active = active_fullscreen_window()
  if not fullscreen_active then
    draw_dock()
  end
  draw_windows()
  if not fullscreen_active then
    draw_system_menu()
  end
  draw_toast()
  draw_modal()
  draw_input()
  if state.headless then
    render_tom_gpu()
  else
    draw_directgpu()
  end
end

function draw_or_stop()
  local ok, err = pcall(draw)
  if ok then
    return true
  end
  local message = tostring(err)
  if state.external.gpu then
    pcall(render_gpu_error, state.external.gpu, message)
  end
  if term then
    if term.setBackgroundColor then
      pcall(term.setBackgroundColor, colors.black)
    end
    if term.setTextColor then
      pcall(term.setTextColor, colors.red)
    end
    if term.clear then
      pcall(term.clear)
    end
    if term.setCursorPos then
      pcall(term.setCursorPos, 1, 1)
    end
  end
  print("DockOS render failed:")
  print(message)
  return false
end

function handle_action(action, payload, mouse_left, mouse_top)
  if action == "modal_close" then
    state.modal = nil
  elseif action == "input_ok" then
    finish_input(state.input and state.input.value or "")
  elseif action == "input_cancel" then
    cancel_input()
  elseif action == "inline_focus" then
    state.focused_field = payload
    state.input = nil
    state.modal = nil
  elseif action == "system_menu_toggle" then
    state.system_menu_open = not state.system_menu_open
  elseif action == "system_open" then
    state.system_menu_open = false
    open_app(payload)
  elseif action == "app_search_prompt" then
    state.system_menu_open = false
    open_app("launcher")
    prompt_text("Search apps", state.app_search_query or "", function(value)
      state.app_search_query = tostring(value or "")
    end)
  elseif action == "app_search_clear" then
    state.app_search_query = ""
  elseif action == "store_search_prompt" then
    prompt_text("Search Store", state.store_search_query or "", function(value)
      state.store_search_query = tostring(value or "")
      state.store_scroll = 0
    end)
  elseif action == "system_about" then
    state.system_menu_open = false
    set_modal("About DockOS", {
      DISPLAY_VERSION,
      "Linux-style Tom GPU desktop",
      "Screen " .. tostring(state.external.pixel_width) .. "x" .. tostring(state.external.pixel_height),
    }, {
      { label = "Close", action = "modal_close", color = THEME.button },
    })
  elseif action == "system_reboot" then
    os.reboot()
  elseif action == "system_shutdown" then
    os.shutdown()
  elseif action == "desktop_app" or action == "dock_pinned" then
    state.system_menu_open = false
    open_app(payload)
  elseif action == "launcher_open" then
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
    local window_state = state.windows[payload]
    if window_state and mouse_top and mouse_top <= window_state.top + window_title_height(window_state) - 1 then
      begin_window_drag(payload, mouse_left, mouse_top)
    end
  elseif action == "window_close" then
    close_window(payload)
  elseif action == "window_minimize" then
    minimize_window(payload)
  elseif action == "window_fullscreen" then
    local window_state = state.windows[payload]
    if window_state then
      toggle_fullscreen(window_state)
      bring_to_front(payload)
    end
  elseif action == "window_drag" then
    begin_window_drag(payload, mouse_left, mouse_top)
  elseif action == "blend_mode_layout" then
    state.blend_mode = "Layout"
  elseif action == "blend_mode_model" then
    state.blend_mode = "Model"
  elseif action == "blend_mode_render" or action == "blend_render" then
    state.blend_mode = "Render"
    state.toast = "Blend preview rendered"
  elseif action == "blend_add_cube" then
    state.blend_object = "Cube " .. tostring((os.time and os.time()) or "")
    state.blend_mode = "Model"
  elseif action == "luma_search" then
    submit_luma_query()
  elseif action == "luma_home" then
    luma_set_tab("home", "", "New Tab", nil)
  elseif action == "luma_back" then
    luma_set_tab("home", "", "New Tab", nil)
  elseif action == "luma_reload" then
    state.toast = "Reloaded"
  elseif action == "luma_new_tab" then
    luma_open_new_tab()
  elseif action == "luma_tab_select" then
    state.luma_active_tab = payload
    local tab = luma_current_tab()
    state.luma_query = tab.url or ""
    state.luma_page = tab.page or "home"
  elseif action == "luma_tab_close" then
    luma_close_tab(payload)
  elseif action == "luma_creator" then
    luma_set_tab("creator", "luma://creator", "Web Creator", nil)
  elseif action == "luma_open_site" then
    luma_navigate(payload)
  elseif action == "luma_tld" then
    state.luma_creator_tld = payload or ".luma"
  elseif action == "luma_publish" then
    luma_publish_site()
  elseif action == "luma_add_heading" then
    table.insert(state.luma_creator_elements, { kind = "heading", text = state.luma_creator_title or "Heading" })
  elseif action == "luma_add_text" then
    table.insert(state.luma_creator_elements, { kind = "text", text = state.luma_creator_body or "Text" })
  elseif action == "luma_clear" then
    state.luma_creator_elements = {}
  elseif action == "studio_examples_toggle" then
    state.studio_examples_open = not state.studio_examples_open
  elseif action == "studio_example" then
    apply_studio_example(payload)
  elseif action == "studio_add" then
    studio_add_component(payload)
  elseif action == "studio_run" then
    submit_inline_field("studio_code")
  elseif action == "store_install" then
    if payload and payload.trust == "built-in" then
      open_app(payload.id)
    elseif payload then
      state.toast = "Package unavailable"
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
    state.docs_scroll = 0
    state.docs_menu_open = false
  elseif action == "doc_menu_toggle" then
    state.docs_menu_open = not state.docs_menu_open
  elseif action == "doc_new" then
    state.docs_menu_open = false
    new_document()
  elseif action == "doc_edit" then
    state.docs_menu_open = false
    edit_document()
  elseif action == "doc_print" then
    state.docs_menu_open = false
    print_document()
  elseif action == "doc_delete" and state.docs_selected then
    state.docs_menu_open = false
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
  elseif action == "settings_tab" then
    state.settings_tab = payload or "general"
  elseif action == "time_decrease" then
    state.timezone_offset = normalize_timezone_offset((state.timezone_offset or DEFAULT_TIMEZONE_OFFSET) - 1)
    local ok, err = save_config()
    state.settings_message = ok and ("Timezone saved: " .. timezone_label()) or ("Timezone save failed: " .. tostring(err))
  elseif action == "time_increase" then
    state.timezone_offset = normalize_timezone_offset((state.timezone_offset or DEFAULT_TIMEZONE_OFFSET) + 1)
    local ok, err = save_config()
    state.settings_message = ok and ("Timezone saved: " .. timezone_label()) or ("Timezone save failed: " .. tostring(err))
  elseif action == "time_reset" then
    state.timezone_offset = DEFAULT_TIMEZONE_OFFSET
    local ok, err = save_config()
    state.settings_message = ok and ("Timezone saved: " .. timezone_label()) or ("Timezone save failed: " .. tostring(err))
  elseif action == "theme_set" then
    apply_theme(payload)
    local ok, err = save_config()
    state.settings_message = ok and ("Theme saved: " .. tostring(state.theme_id)) or ("Theme save failed: " .. tostring(err))
    state.toast = "Theme " .. tostring(state.theme_id)
  end
end

function pixel_to_cell(pixel_left, pixel_top)
  local left = math.floor(math.max(0, (tonumber(pixel_left) or 1) - 1) / state.external.cell_width) + 1
  local top = math.floor(math.max(0, (tonumber(pixel_top) or 1) - 1) / state.external.cell_height) + 1
  left = math.max(1, math.min(state.virtual_width, left))
  top = math.max(1, math.min(state.virtual_height, top))
  return left, top
end

function monitor_event_pixels(first, second, third, fourth)
  if type(first) == "number" and type(second) == "number" then
    return first, second, third
  end
  if type(second) == "number" and type(third) == "number" then
    return second, third, fourth
  end
  return 0, 0, third
end

function normalize_external_event(event, first, second, third, fourth)
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

function active_app()
  if state.active_window and state.windows[state.active_window] then
    return state.windows[state.active_window].app
  end
  return nil
end

function handle_terminal_event(event, first)
  if active_app() ~= "terminal" or state.input or state.modal then
    return false
  end
  if event == "char" then
    state.terminal_input = tostring(state.terminal_input or "") .. tostring(first or "")
    return true
  elseif event == "paste" then
    state.terminal_input = tostring(state.terminal_input or "") .. tostring(first or "")
    return true
  elseif event == "key" then
    if first == keys.enter then
      local command_line = state.terminal_input or ""
      state.terminal_input = ""
      terminal_execute(command_line)
    elseif first == keys.backspace then
      local value = tostring(state.terminal_input or "")
      state.terminal_input = value:sub(1, math.max(0, #value - 1))
    elseif keys.escape and first == keys.escape then
      state.terminal_input = ""
    end
    return true
  end
  return false
end

function run_loop()
  state.headless = true
  load_config()
  blank_terminal()
  scan_external_peripherals()
  show_boot_splash()
  start_peripheral_scan_timer()
  while true do
    if not draw_or_stop() then
      return
    end
    local event, first, second, third, fourth = os.pullEvent()
    event, first, second, third = normalize_external_event(event, first, second, third, fourth)
    if event == "mouse_click" then
      local hitbox = hit_at(second, third)
      if hitbox and (not state.input or hitbox.id == "input_ok" or hitbox.id == "input_cancel") then
        handle_action(hitbox.id, hitbox.payload, second, third)
      end
    elseif event == "mouse_drag" then
      if not state.dragging_window then
        local hitbox = hit_at(second, third)
        if hitbox and (hitbox.id == "window_drag" or hitbox.id == "window_focus") then
          begin_window_drag(hitbox.payload, second, third)
        end
      end
      local window_state = state.dragging_window and state.windows[state.dragging_window.id]
      if window_state then
        local screen_width, screen_height = screen_size()
        local shell_left = shell_left_cell()
        local max_left = math.max(shell_left, screen_width - window_state.width + 1)
        local max_top = math.max(1, screen_height - shell_bottom_cells() - window_state.height + 1)
        window_state.left = math.max(shell_left, math.min(max_left, state.dragging_window.start_left + second - state.dragging_window.mouse_left))
        window_state.top = math.max(1, math.min(max_top, state.dragging_window.start_top + third - state.dragging_window.mouse_top))
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
      elseif active_window and active_window.app == "docs" then
        state.docs_scroll = math.max(0, state.docs_scroll + first)
      elseif active_window and active_window.app == "store" then
        state.store_scroll = math.max(0, state.store_scroll + first)
      end
    elseif event == "timer" and first == state.peripheral_scan_timer then
      scan_external_peripherals()
      start_peripheral_scan_timer()
    elseif event == "peripheral" or event == "peripheral_detach" then
      scan_external_peripherals()
    elseif event == "key" then
      if handle_input_event(event, first) then
        -- input consumed
      elseif handle_inline_field_event(event, first) then
        -- inline field consumed
      elseif handle_terminal_event(event, first) then
        -- terminal consumed
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
      if handle_input_event(event, first) then
        -- input consumed
      elseif handle_inline_field_event(event, first) then
        -- inline field consumed
      else
        handle_terminal_event(event, first)
      end
    end
  end
end

function print_apps()
  print(DISPLAY_VERSION)
  local app_ids = {}
  for app_id in pairs(APPS) do
    table.insert(app_ids, app_id)
  end
  table.sort(app_ids)
  for _, app_id in ipairs(app_ids) do
    local app = APPS[app_id]
    print(app.id .. " " .. app.name)
  end
end

function install_from_store(app_id)
  if APPS[app_id] then
    print("Built-in application.")
  else
    print("Application not found: " .. tostring(app_id))
  end
end

function method_summary(name)
  if not peripheral or not peripheral.getMethods then
    return ""
  end
  local ok, methods = pcall(peripheral.getMethods, name)
  if not ok or type(methods) ~= "table" then
    return ""
  end
  table.sort(methods)
  return table.concat(methods, ",")
end

function cube_vertex_value(triangle, offset)
  return tonumber(triangle:sub(offset, offset)) or 0
end

function draw_cube_triangles(gl)
  gl.glBegin()
  local index = 0
  for triangle in CUBE_TRIANGLES:gmatch("[^;]+") do
    index = index + 1
    local side = math.floor((index - 1) / 2) % 3
    if side == 0 then
      gl.glColor(255, 80, 80)
    elseif side == 1 then
      gl.glColor(80, 220, 120)
    else
      gl.glColor(90, 160, 255)
    end
    gl.glVertex(cube_vertex_value(triangle, 1), cube_vertex_value(triangle, 2), cube_vertex_value(triangle, 3))
    gl.glVertex(cube_vertex_value(triangle, 4), cube_vertex_value(triangle, 5), cube_vertex_value(triangle, 6))
    gl.glVertex(cube_vertex_value(triangle, 7), cube_vertex_value(triangle, 8), cube_vertex_value(triangle, 9))
  end
  gl.glEnd()
end

function render_3d_doctor_frame(gpu)
  initialize_tom_gpu(true)
  if gpu.fill then
    gpu.fill(0)
  end
  local width = math.min(state.external.pixel_width - 2, 420)
  local height = math.min(state.external.pixel_height - 2, 260)
  local left = math.max(1, math.floor((state.external.pixel_width - width) / 2))
  local top = math.max(1, math.floor((state.external.pixel_height - height) / 2))
  local gl = gpu.createWindow3D(left, top, width, height)
  gl.glFrustum(90, 0.1, 1000)
  gl.glDirLight(0, 0, -1)
  gl.clear()
  gl.glDisable(0xDE1)
  gl.glTranslate(0, 1, 3)
  gl.glRotate(28, 0, 1, 0)
  gl.glRotate(20, 0, 0, 1)
  draw_cube_triangles(gl)
  gl.render()
  gl.sync()
  if gpu.sync then
    gpu.sync()
  end
end

function run_3d_doctor()
  state.headless = false
  reset_colors()
  print(DISPLAY_VERSION .. " 3D doctor")
  scan_external_peripherals()
  local gpu = state.external.gpu
  if not gpu then
    print("Tom GPU not found.")
    return
  end
  if not gpu.createWindow3D then
    print("3D window API is not available on this GPU.")
    return
  end
  local ok, err = pcall(render_3d_doctor_frame, gpu)
  if ok then
    print("3D cube frame rendered.")
  else
    print("3D render failed: " .. tostring(err))
  end
end

function run_doctor()
  state.headless = false
  reset_colors()
  print(DISPLAY_VERSION .. " doctor")
  print("")
  if not peripheral or not peripheral.getNames then
    print("Peripheral API is missing.")
    return
  end

  local names = peripheral.getNames()
  table.sort(names)
  if #names == 0 then
    print("No peripherals attached.")
  else
    print("Peripherals:")
    for _, name in ipairs(names) do
      print("- " .. name .. " type=" .. peripheral_type_text(name))
      local methods = method_summary(name)
      if methods ~= "" then
        print("  methods=" .. trim(methods, 90))
      end
    end
  end

  print("")
  scan_external_peripherals()
  print("GPU: " .. tostring(state.external.gpu_name or "not found"))
  print("Keyboard: " .. tostring(state.external.keyboard_name or "not found"))
  if state.external.monitor_name then
    print("Monitor peripheral: " .. tostring(state.external.monitor_name))
  elseif state.external.gpu_name then
    print("Monitor peripheral: none")
    print("Bitmap monitor: via GPU screen, not separate peripheral")
  else
    print("Monitor: not found")
  end
  print("Size: " .. tostring(state.external.pixel_width) .. "x" .. tostring(state.external.pixel_height))
  if state.external.gpu then
    pcall(render_wallpaper, state.external.gpu)
  end
  print("Image API: decode=" .. tostring(state.external.gpu and state.external.gpu.decodeImage ~= nil) .. " draw=" .. tostring(state.external.gpu and state.external.gpu.drawImage ~= nil))
  print("Wallpaper: " .. (state.wallpaper and "loaded" or tostring(state.wallpaper_error or "not loaded yet")))
  if state.external.gpu_error then
    print("GPU error: " .. tostring(state.external.gpu_error))
  end

  if not state.external.gpu then
    print("")
    print("Tom GPU not detected. Expected peripheral like tm_gpu_0.")
    return
  end

  local gpu = state.external.gpu
  local ok, err = pcall(function()
    initialize_tom_gpu(true)
    if gpu.fill then
      gpu.fill(0)
    end
    if gpu.filledRectangle then
      tom_fill_rect(gpu, 1, 1, 180, 80, colors.black)
      gpu.filledRectangle(9, 9, 164, 64, 0x0A84FF)
      gpu.filledRectangle(15, 15, 152, 52, 0x2C2C2E)
    end
    if gpu.drawText then
      tom_draw_text(gpu, 25, 27, "DockOS GPU active", colors.white, nil)
      tom_draw_text(gpu, 25, 45, tostring(state.external.gpu_name), colors.cyan, nil)
    end
    if gpu.sync then
      gpu.sync()
    end
  end)
  if ok then
    print("")
    print("Test pattern sent to Tom GPU.")
  else
    print("")
    print("GPU test failed: " .. tostring(err))
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
elseif command == "luma" then
  open_app("luma")
  run_loop()
elseif command == "studio" then
  open_app("studio")
  run_loop()
elseif command == "apps" then
  print_apps()
elseif command == "wallpaper" and args[2] then
  local ok, err = install_wallpaper_url(args[2])
  if ok then
    print("Wallpaper installed.")
  else
    print("Wallpaper failed: " .. tostring(err))
  end
elseif command == "doctor" and args[2] == "3d" then
  run_3d_doctor()
elseif command == "doctor" or command == "gpu-test" then
  run_doctor()
elseif command == "version" then
  print(DISPLAY_VERSION)
else
  run_loop()
end
