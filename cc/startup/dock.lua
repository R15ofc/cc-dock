local function append_path(entry)
  if shell and shell.path and shell.setPath then
    local current = shell.path()
    for part in string.gmatch(current, "[^:]+") do
      if part == entry then
        return
      end
    end
    shell.setPath(current .. ":" .. entry)
  end
end

append_path("/bin")

if fs.exists("/dock/dock.lua") and shell then
  shell.run("/dock/dock.lua", "home")
end

