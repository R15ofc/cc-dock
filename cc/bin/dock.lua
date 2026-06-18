local args = { ... }
local unpacker = table.unpack or unpack

if shell then
  shell.run("/dock/dock.lua", unpacker(args))
else
  dofile("/dock/dock.lua")
end

