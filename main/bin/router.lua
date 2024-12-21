local component = require("component")
local event = require("event")
local rn = require("racoonnet")
local computer = require('computer')
local sysutils = require("sysutils")
local thread = require("thread")

local clients = {}
local clientscard = {}
local wan
local lan = {}
local ip
local err
local config = sysutils.readconfig("router")
local lang = sysutils.readlang("router")


--//Функция отправки пакета по ip получателя
function route(recieverip, senderip, ... )
  local m
  local cl
  for client in pairs(clients) do
    m = recieverip:find(client)
    if m then cl = client break end
  end
  if m then
    lan[clientscard[cl]:sub(1,3)]:directsend(clients[cl], recieverip, senderip, ...)
  else
    if wan then
    wan:directsend(wan.router, recieverip, senderip, ...)
    end
  end
end

--//Список команд роутера
commands={}

--//Пинг
function commands.ping()
  sysutils.log(lang.ping..": "..sendIP, 1, "router")
  route(sendIP, recIP, "pong" )
  return 
end

--//Версия
function commands.ver()
  sysutils.log(lang.ver..": "..sendIP, 1, "router")
  route(sendIP, recIP, "DNSROUTER-v1" )
  return 
end

local IPtoDNS = {
    ["IP"] = "domain"
}

function commands.getip()
    local adr
    local acceptedPrefix = acceptedAdr:sub(1, 3)
    local found = false
    if lan[acceptedPrefix] then
        local senderPrefix = senderAdr:sub(1, 3)
        if IPtoDNS[senderPrefix] then
            adr = IPtoDNS[senderPrefix]
            found = true
        else
            found = false
        end
        if not found then
            adr = ip .. "." .. senderPrefix
        end
        clients[adr] = senderAdr
        clientscard[adr] = acceptedAdr
        lan[acceptedPrefix]:directsend(senderAdr, adr, ip, "setip")
        sysutils.log(lang.givenip .. ": " .. adr, 1, "router")
    else
        sysutils.log(lang.noLan .. ": " .. acceptedAdr, 2, "router")  -- Log if no LAN found
    end
end

sysutils.log(lang.launch, 1, "router")
if not config.lan then
  sysutils.log(lang.noconfig, 4, "router")
  return
end


--//Инициализируем WAN карту
if config.wan.type then
  wan, err = rn.init(config.wan)
  if wan then
    sysutils.log(lang.waninit..": \""..wan.address:sub(1,3).."\". ".."\". "..lang.gateway..": \""..wan.routerip.."\".", 0, "router")
  else
    sysutils.log(lang.wanerr..": \""..err.."\"!", 3, "router")
  end
else
  sysutils.log(lang.nowan, 2, "router")
end

if wan then
  ip = wan.ip
else
  ip = computer.address():sub(1,3)
end
sysutils.log("IP: \""..ip.."\"", 1, "router")

--//Инициализируе LAN карты
for saddr, obj in pairs(config.lan) do
  obj.master = ip
  lan[obj.address:sub(1,3)], err = rn.init(obj)
  if lan[obj.address:sub(1,3)] then
    sysutils.log(lang.laninit..": \""..lan[obj.address:sub(1,3)].address:sub(1,3).."\".", 0, "router")
  else 
    sysutils.log(lang.lanerr..": \""..err.."\"!", 3, "router")
  end
end

function routing()
  while true do
    packet, acceptedAdr, senderAdr, recIP, sendIP, command = rn.receiveall()
  if recIP == ip or recIP == "" then
    if commands[command] then
        commands[command](table.unpack(packet,9))
    end  
  else
    route(recIP,sendIP,table.unpack(packet,8))
  end
  end
end

local t = thread.create(routing)

while true do
  ev = {event.pull(_, "key_down")}
  local key=ev[4]
  if key==16 then --Q
    t:kill()
  break
  end
end
