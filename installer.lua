local shell = require("shell")
local fs = require("filesystem")
local prefix = "https://raw.githubusercontent.com/DanXvoIsMe/RacoonNet-2/master/main/"
local comp = require("computer")
local files = {"/lib/forms.lua","/lib/rainbow.lua","/lib/stem.lua","/lib/sysutils.lua","/bin/chat.lua","/bin/chat_server.lua","/bin/ping.lua","/bin/rnconfig.lua","/bin/routconf.lua","/bin/router.lua","/bin/webserver.lua","/bin/wr.lua","/etc/config/sys.cfg","/etc/lang/ru.router.lang","/lib/opennet.lua","/lib/racoonnet.lua","/lib/rn_modem.lua","/lib/rn_stem.lua","/lib/rn_tunnel.lua",}

shell.execute("wget -f https://raw.githubusercontent.com/DanXvoIsMe/RacoonNet-2/master/main/etc/boot/05_config.lua /boot/05_config.lua")
fs.makeDirectory("/etc/themes/")
shell.execute("wget -f https://raw.githubusercontent.com/DanXvoIsMe/RacoonNet-2/master/main/etc/themes/standart.thm /etc/themes/standart.thm")

for _,v in pairs(files) do
  if not fs.exists(v:match(".*/")) then fs.makeDirectory(v:match(".*/")) end
  shell.execute("wget -f "..prefix..v.." "..v)
end
comp.shutdown("true")
