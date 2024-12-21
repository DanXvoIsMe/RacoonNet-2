local gpu = require("component").gpu

local core = {
  print = function(...)
    local text = table.concat({...}, "")
    text = "\\F+FFFFFF\\\\B+000000\\" .. text
    for _type, _color, __p in string.gmatch(text, "\\([FB])%+(......)\\()") do
      local substr = text:sub(__p, -1)
      local _text, gPtrn = substr:match("(.-)(\\[FB]%+......\\)")
      _text = _text or (gPtrn and "" or substr)
      if _type == "F" then
        gpu.setForeground(tonumber(_color, 16)) 
      else
        gpu.setBackground(tonumber(_color, 16)) 
      end
      io.write(_text)
    end
  end,
  colorize = function (color, fg)
    local hexstr = '0123456789ABCDEF'
    local s = ''
    
    while color > 0 do
      local mod = math.fmod(color, 16)
      s = string.sub(hexstr, mod+1, mod+1) .. s
      color = math.floor(color / 16)
    end
    
    for i=1, 6 - #s do
      s = s .. "0"
    end
    return function(t) 
      return "\\" .. (fg and "F" or "B") .. "+" .. s .. "\\" .. t 
    end
  end,
  colors = {
    background = {
      black      = 0x000000,
      gray       = 0x424242,
      white      = 0xFFFFFF,
      red        = 0xCE0202,
      green      = 0x02CE02,
      yellow     = 0xCECE02,
      blue       = 0x0202CE,
      violet     = 0xCE02CE,
      light_blue = 0x02CECE,
    },
    foreground = {
      black      = 0x000000,
      gray       = 0x424242,
      white      = 0xFFFFFF,
      red        = 0xCE0202,
      green      = 0x02CE02,
      yellow     = 0xCECE02,
      blue       = 0x0202CE,
      violet     = 0xCE02CE,
      light_blue = 0x02CECE,
    }
  }
}
local core_meta = {
  __call = function (self, ...) 
    rawget(self, "print")(...) 
  end, 
  __index = function (self, k)
    if type(rawget(self, k)) ~= "function" and 
       rawget(self, "colors")["foreground"][k:sub(4, -1)] or
       rawget(self, "colors")["background"][k:sub(4, -1)] then
      if k:sub(1, 3) == "fg_" then 
        return rawget(self, "colorize")
              (rawget(self, "colors")["foreground"][k:sub(4, -1)], true) 
      elseif k:sub(1, 3) == "bg_" then 
        return rawget(self, "colorize")
              (rawget(self, "colors")["background"][k:sub(4, -1)]) 
      end
    end
    return rawget(self, k) 
  end
}
setmetatable(core, core_meta)

local buffer = function (options)
  local self = {}
  
  options = options or {}
  options.colors_ext = options.colors_ext or {}
  options.colors_ext.foreground = options.colors_ext.foreground or {}
  options.colors_ext.background = options.colors_ext.background or {}
  
  local colors = options.colors or core.colors
  local patterns = options.patterns or {}
  
  for k, v in pairs(options.colors_ext.foreground) do
    colors.foreground[k] = v
  end
  
  for k, v in pairs(options.colors_ext.background) do
    colors.background[k] = v
  end
  
  self.colorize = core.colorize
  
  function self.print(ispattern, pattern, ...)
    if type(ispattern) == "string" then
      core.print(ispattern, pattern, ...)
    else
      if patterns[pattern] then
        core.print(patterns[pattern](self, ...))
      else
        error("no such pattern")
      end
    end
  end
  
  setmetatable(self, {
    __call = function (tbl, ...)
      self.print(...)
    end,
    __index = function (tbl, key)
      if type(rawget(self, key)) ~= "function" then
        if colors.foreground[key:sub(4, -1)] or
           colors.background[key:sub(4, -1)] then
          if key:sub(1, 3) == "fg_" then
            return core.colorize(colors.foreground[key:sub(4, -1)], true)
          else
            return core.colorize(colors.background[key:sub(4, -1)])
          end
        end
      end
      return rawget(self, key)
    end
  })
  
  return self
end

return {
  core = core,
  buffer = buffer
}
