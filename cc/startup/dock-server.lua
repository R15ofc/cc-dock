if fs.exists("/dock/server.lua") then
  if shell then
    shell.run("/dock/server.lua")
  else
    dofile("/dock/server.lua")
  end
end

