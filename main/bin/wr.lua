local component = require("component")
local forms = require("forms")
local io = require("io")
local fs = require("filesystem")
local term = require("term")
local event= require("event")
local rn = require("racoonnet")
local sysutils = require("sysutils")
local gpu  = require("component").gpu
local text = require("text")
local wlen = require("unicode").wlen

local config = sysutils.readconfig("wr")

file_types = {}
file_types["html"] = "text/html"

local card, err = rn.init(sysutils.readconfig("racoonnet"))

local wScr, hScr = component.gpu.getResolution()
local WinW = wScr - 4
local WinH = hScr - 8
local cursorX, cursorY = 1, 1
local ShiftX = 0
local ShiftY = 0
local Left,Top = 3, 7
local Site=""
local txColour = 0xFFFFFF
local bgColour = 0x000000
local tagColour = 0x0080FF
local History = {}
local object={}
local MainForm
if not config.downloads_dir then config.downloads_dir = "/home/downloads" end
if not config.home then config.home = "/" end
local download_src

local siteform = {}

forms.ignoreAll()

function draw_header(label)
  local head = " Wet Racoon 1.1"
  if label then head = head.." ("..label..")"end
  Header.W=wScr -  head:len() - 5
  head = head..string.rep(" ",Header.W)
  Header.caption = head
  Header:redraw()
end

function get_file(path)
  if path=='' or path==nil or path=="\n" then return end
  if path:sub(-1)=="\n" then path=path:sub(1,-2) end
  if path:sub(1,1)=="." then
	if Site:sub(-1) ~= "/" then
      Site=Site:match(".*/") or Site
	end
	path = fs.concat(Site,path)
  end
  if path:sub(1,1) ~= "/" then
    return rn_request(path)
  elseif path:sub(1,1) == "/" then
    return local_request(path)
  end
end

function back()
  if #History>1 then
    History[#History]=nil
    load(History[#History])
  end
end

function linkcheck(...)
local ev, _, X, Y, S = ...
  for i=1,#object do
    if object[i]:check(X,Y) then object[i]:work() break end
  end
end

event.listen("touch", linkcheck)

function winwrite(value)
  value = text.detab(tostring(value))
  if wlen(value) == 0 then
    return
  end
  local line, nl
  repeat
    if cursorY > WinH then return end
    line, value, nl = text.wrap(value, WinW - (cursorX - 2), WinW)
    if cursorY>=1 then gpu.set(cursorX+Left-1-ShiftX, cursorY+Top-1, line) end
    cursorX = cursorX + wlen(line)
    if nl or (cursorX > WinW) then
      cursorX = 1
      cursorY = cursorY + 1 
    end
  until not value
end

function winclear()
  gpu.setForeground( txColour )
  gpu.setBackground( bgColour )
  object={}
  gpu.fill(Left, Top, WinW, WinH, " ")
  cursorX, cursorY = 1, 1
end


tags={}
tags['/html']=function(arg)
end
tags['html']=function(arg)
end
tags['/body']=function(arg)
end
tags['/luascript']=function(arg)
end
tags['luascript'] = function(arg)
    local content = arg.text or ""
    if content then
        local func, err = load(content)
        if func then
            local success, result = pcall(func)
            if not success then
                gpu.setForeground(0xFF0000)
                winwrite("Error executing Lua code: " .. result)
                gpu.setForeground(txColour)
            end
        else
            gpu.setForeground(0xFF0000)
            winwrite("Invalid Lua code: " .. err)
            gpu.setForeground(txColour)
        end
    end
end
tags['body']=function(arg)
  local param=tonumber(arg.text)
  if param then txColour = param gpu.setForeground(param) end
  param=tonumber(arg.bgcolor)
  if param then bgColour = param gpu.setBackground(param) winclear() end
end
tags['font']=function(arg)
  local param=tonumber(arg.color)
  if param then gpu.setForeground(param) end
  param=tonumber(arg.bgcolor)
  if param then gpu.setBackground(param) end
end
tags['/font']=function()
    gpu.setForeground( txColour )
    gpu.setBackground( bgColour )
end
tags['br']=function()
    cursorY=cursorY+1
    cursorX=1
end
tags['hr']=function(arg)
  local param=tonumber(arg.color)
  if param then gpu.setForeground(param) end
  param=tonumber(arg.bgcolor)
  if param then gpu.setBackground(param) end
  if cursorX>1 then cursorY=cursorY+1 cursorX=1 end
  winwrite(string.rep('─',WinW))
  gpu.setForeground( txColour )
  gpu.setBackground( bgColour )
end

local function line_check(obj,x,y)
  if y>=obj.y1 and y<=obj.y2 then
    if (x>=obj.x1 or y>obj.y1) and (x<=obj.x2 or y<obj.y2) then return true end
  end
end

local function ref_work(obj) if obj.target == "download" then download(obj.ref) else load(obj.ref) end end
tags['a']=function(arg)
  if arg.href then
    table.insert(object, {check=line_check,
    x1=cursorX+Left-1-ShiftX, y1=cursorY+Top-1,
    work=ref_work, ref = arg.href, target = arg.target,
    col=gpu.getForeground()})
  end
  local color=tonumber(arg.color) or tagColour
  gpu.setForeground(color)
end

tags['/a']=function()
  local ref=object[#object]
  if ref and not ref.x2 then
    gpu.setForeground(ref.col or txColour)
    ref.x2, ref.y2 = cursorX+Left-2-ShiftX, cursorY+Top-1
  end
end

tags['getIP']=function()
	local MyIP,err=on.getIP()
	if not MyIP then
	  error(err)
	end
end

function tagWork(tag)
    local name = tag:match('%S+')
    if tags[name] then
        local params = {}
        for k, v in tag:gmatch('(%w+)=([^%s"]+)') do params[k] = v end
        for k, v in tag:gmatch('(%w+)="([^"]+)"') do params[k] = v end
        params.text = tag:match('>(.-)<')
        tags[name](params)
    else
        winwrite('<'..tag..'>')
    end
end


function winline(line)
  if line then
    cursorY=line.Y-ShiftY
    cursorX=line.X
    local sLine=line.text
	while string.len(sLine) > 0 do
      local p1,p2
      p1=sLine:find("<")
      if p1 then p2=sLine:find(">",p1) end
      if p2 then
        winwrite(sLine:sub(1,p1-1))
        tagWork(sLine:sub(p1+1,p2-1))
        sLine=sLine:sub(p2+1)
      else
        winwrite(sLine)
        sLine=""
      end
	end
    if cursorY <= WinH then return true end
  end
end

function htmltext()
  winclear()
  local line=1
  for i=#lines,1,-1 do
    if lines[i].Y<=ShiftY then line=i break end
  end
  while winline(lines[line]) do
    line=line+1
    if lines[line] then lines[line].Y=ShiftY+cursorY lines[line].X=cursorX end
  end
end
function codetext()
  winclear()
  for i=1,WinH do
    if lines[i+ShiftY] then gpu.set(Left-ShiftX,i+Top-1,lines[i+ShiftY].text)
    else break end
  end
end
wintext=htmltext

function winshift(shX,shY)
  ShiftX=ShiftX+shX
  ShiftY=ShiftY+shY
  if ShiftX<0 then ShiftX=0 end
  if ShiftY<0 then ShiftY=0 end
  wintext()
end

function download(path)
  if not path then path = Site end
  local fname = path:match("/[^/]*")
  SaveForm.src = path
  SavePath.text = fs.concat(config.downloads_dir, fname)
  forms.run(SaveForm)
end

function rn_request(site)
  if card then
    local host,doc=site:match('(.-)/(.*)')
    if not host then host=site doc=nil end
    if doc == nil then doc = "/" end
	card:send(host,"GET "..doc.." HTTP/1.1\nHost: "..host)
	local adr, resp
	while true do
	  adr, resp = card:receive(5)
	  if not adr then
	    local err = "<html><body>Превышено время ожидания ответа.</body></html>"
	    return err, err, nil , nil, site, "text/html"
	  elseif adr == host then
	    break
	  end  
	end
	local code = tonumber(resp:match(" %d%d%d "))
	local headers = {}
	for str in string.gmatch(resp, "\n[^:\n]*:[^:\n]*") do
      headers[str:sub(2,str:find(":")-1)] = str:sub(str:find(":")+2)
    end
	if code == 302 then
      return get_file(headers["Location"])
    elseif resp:match("\n\n") then
	  local body = resp:match("\n\n.*"):sub(3,-1)
      return resp, body, code, headers, site, headers["Content-Type"]
	else
	  return resp, nil, code, headers, site, headers["Content-Type"]
	end
  else
	local err = "<html><body>Ошибка подключения к сети OpenNet: <font color=0xFF0000>"..err.."</font></body></html>"
	return err, err, nil , nil , site, "text/html"
  end
end



function local_request(path)
  if fs.exists(path) then
	if fs.isDirectory(path) then
	  if path:sub(-1) == "/" then
		local fcontent = "<html><body>Индекс \""..path.."\":<br><a href=\"../\">../</a><br>"
		for name in fs.list(path)do
		  fcontent = fcontent.."<a href=\"./"..name.."\">"..name.."</a><br>"
		end
		fcontent = fcontent.."</body></html>"
		return fcontent, fcontent, nil, nil, path, "text/html"
      else
		return get_file(path.."/")
	  end
	else
	  local file=io.open(path,"r")
      if file then
        local body = file:read("*a")
        file:close()
		local ftype
		if file_types[path:match("%.([%a%d]*)")] ~= nil then
		  ftype = file_types[path:match("%.([%a%d]*)")]
		else
		  ftype = "text/plain"
		end
		return body, body, nil , nil , path, ftype
      else
		local err = "<html><body>Ошибка при открытии файла!</body></html>"
	    return err, err, nil , nil , path, "text/html"
	  end
	end
  else
	local err = "<html><body>Файл не найден!</body></html>"
	return err, err, nil , nil , path, "text/html"
  end
end

function render(text, content_type)
  text=tostring(text)
  lines={}
  ShiftX=0
  ShiftY=0
  txColour = 0xFFFFFF
  bgColour = 0x000000
  if content_type == "text/html" then
    text = text:match("<body.*</body>")
	wintext=htmltext  
  else
    wintext=codetext
  end
  local line=1
  while #text>0 do
    local p=text:find("\n")
    if p then
      lines[line],text={X=1,Y=math.huge,text=text:sub(1,p-1)}, text:sub(p+1)
    else
      lines[line],text={X=1,Y=math.huge,text=text}, ""
    end
    line=line+1
  end
  if lines[1] then
    lines[1].Y=1
  end
  wintext()
end

function load(sPath)
  local raw, body, code, headers, path, content_type = get_file(sPath)
  if not raw then return end
  Site=path
  AddressLine.text = path
  AddressLine:redraw()
  render(body, content_type)
  if body:match("<title>.*</title>") then
	draw_header(body:match("<title>.*</title>"):sub(8,-9))
  else
    draw_header()
  end
  if History[#History]~=Site then table.insert( History, Site ) end
end

function main_form()
  forms.activeForm():hide()
  MainForm:setActive()
end

function save_file(save_to, download_src)
  if download_src ~= nil and download_src ~= "" then
    if not fs.exists(save_to:match(".*/")) then fs.makeDirectory(save_to:match(".*/")) end
    local file = io.open(save_to, "w")
	local body
	_, body = get_file(download_src)
	file:write(body)
	file:close()
  end
  SaveForm:hide()
  main_form()
end

function menu_item(self,line,item)
  MenuForm:hide()
  main_form()
  if type(item)=="function" then item() end
end

SaveForm=forms.addForm()
SaveForm.H=9
SaveForm.W=34
SaveForm.top=(hScr - SaveForm.H)/2
SaveForm.left=(wScr - SaveForm.W)/2
SaveForm.border=1

SaveLabel1=SaveForm:addLabel(3,2,"Куда Вы хотите сохранить файл?")
SaveLabel1.W=30

SavePath=SaveForm:addEdit(2,3)
SavePath.W=32

SaveSafe=SaveForm:addButton(5,6,"Сохранить",function() save_file(SavePath.text, SaveForm.src) end)
SaveSafe.H=3
SaveSafe.W=11

SaveCancel=SaveForm:addButton(20,6,"Отмена",function() SaveForm:hide() main_form() end)
SaveCancel.H=3
SaveCancel.W=11

MenuForm=forms.addForm()
MenuForm.W=20
MenuForm.H=5
MenuForm.left = 3
MenuForm.top = 3

Menu=MenuForm:addList(1,1,menu_item)
Menu.W=MenuForm.W
Menu.H=MenuForm.H

Menu:insert("Сохранить файл", download)
Menu:insert("Сделать домашней", function() config.home = AddressLine.text sysutils.writeconfig("wr", config) end)
Menu:insert("Закрыть меню")

MainForm=forms.addForm()
MainForm.border=1
--MainForm.onDraw = function() load(AddressLine.text) end
function MainForm:draw()         
  getmetatable(self).draw(self)  
  load(AddressLine.text)
end

Header=MainForm:addLabel(2,2,"")

Close=MainForm:addButton(wScr-3,2,"X", forms.stop)
Close.W=3

AddressLine=MainForm:addEdit(26,3,function() load(AddressLine.text) end)
AddressLine.W=wScr-37

Refresh=MainForm:addButton(3,3," Меню", function() Menu.index=0 Menu.shift=0 MenuForm:setActive() end)
Refresh.H=3
Refresh.W=7

Back=MainForm:addButton(11,3,"Назад", back)
Back.H=3
Back.W=7

Home=MainForm:addButton(19,3,"Домой", function() load(config.home) end)
Home.H=3
Home.W=7

Frame1=MainForm:addFrame(2,6,1)
Frame1.H=hScr - 6
Frame1.W=wScr - 2

Go=MainForm:addButton(wScr-10,3,"Вперёд!",function() load(AddressLine.text) end)
Go.H=3
Go.W=9

if gpu.getDepth() > 1 then
  Go.color = 0x33cc33
  Back.color = 0x6699ff
  Home.color = 0x6699ff
  Refresh.color = 0x6699ff
  Close.color=0xff3333
  Header.color=0x333399
else
  Go.color = 0x000000
  Back.color = 0x000000
  Refresh.color = 0x000000
  Home.color = 0x000000
  Home.border = 2
  Go.border = 2
  Back.border = 2
  Refresh.border = 2
  Close.color=0xffffff
  Close.fontColor=0x000000
  Header.color=0x000000
end

draw_header()
local param=...
if param then Site = param AddressLine.text = param end
forms.run(MainForm)
term.clear()
