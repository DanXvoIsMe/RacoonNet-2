local shell = require("shell")
local fs = require("filesystem")
local prefix = "https://raw.githubusercontent.com/DanXvoIsMe/RacoonNet-2/master/main/"
local comp = require("computer")
local files = {"/bin/chat.lua","/bin/chat_server.lua","/bin/ping.lua","/bin/rnconfig.lua","/bin/routconf.lua","/bin/router.lua","/bin/webserver.lua","/bin/wr.lua","/etc/config/sys.cfg","/etc/lang/ru.router.lang","/lib/opennet.lua","/lib/racoonnet.lua","/lib/rn_modem.lua","/lib/rn_stem.lua","/lib/rn_tunnel.lua",}

shell.execute("wget -f https://pastebin.com/raw/iKzRve2g /lib/forms.lua")
shell.execute("wget -f https://pastebin.com/raw/C5aBuY5e /lib/rainbow.lua")
shell.execute("wget -f https://pastebin.com/raw/nt0j4iXU /lib/stem.lua")
shell.execute("wget -f https://pastebin.com/raw/e5uEpxpZ /lib/sysutils.lua")
shell.execute("wget -f https://pastebin.com/raw/WBH19bBg /boot/05_config.lua")
fs.makeDirectory("/etc/themes/")
shell.execute("wget -f https://pastebin.com/raw/00XsAdhf /etc/themes/standart.thm")

for _,v in pairs(files) do
  if not fs.exists(v:match(".*/")) then fs.makeDirectory(v:match(".*/")) end
  shell.execute("wget -f "..prefix..v.." "..v)
end
comp.shutdown("true")
