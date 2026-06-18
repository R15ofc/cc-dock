local args = { ... }
local unpacker = table.unpack or unpack

if shell then
  shell.run("/dock/server.lua", unpacker(args))
else
  dofile("/dock/server.lua")
end

