local settings = require("settings")
local awful = require("awful")
local gears = require("gears")
local naughty = require("naughty")


local wallpaper = {
  bag = {},
  queue = {}
}

function wallpaper.reinitialize()
  wallpaper.paths = nil
  local error = awful.spawn.easy_async("ls -1 " .. settings.wallpaper.path,
                         function(stdout, stderr, reason, exit_code)
                           if not (foo == nil or foo == '') then
                             naughty.notify {text = ">" .. stderr .. "<"} 
                           else
                             wallpaper.paths = {}

                             for file in stdout:gmatch("[^\r\n]+") do
                               table.insert(wallpaper.paths, settings.wallpaper.path .. file)
                             end

                             for i=#wallpaper.queue,1,-1 do
                               wallpaper.set(wallpaper.queue[i])
                               table.remove(wallpaper.queue,i)
                             end
                           end


                         end
  )

end

local function random_image()
  if #wallpaper.bag == 0 then
    for k,v in pairs(wallpaper.paths) do
      table.insert(wallpaper.bag, v)
    end
  end

  local length = #wallpaper.bag


  local element = math.random(length)

  --naughty.notify{text = "selected " .. tostring(element) .. " of " .. tostring(length)}

  local path = wallpaper.bag[element]
  table.remove(wallpaper.bag, element)

  return gears.surface.load(path)


end

function wallpaper.set(s)
  if wallpaper.paths == nil then
    table.insert(wallpaper.queue, s)
    return;
  end

  gears.wallpaper.maximized(random_image(), s, true)
end

wallpaper.reinitialize()

gears.timer {
  timeout = settings.wallpaper.switchduration,
  autostart = true,
  callback = function()
    for s in screen do
      wallpaper.set(s)
    end
  end


}


return wallpaper
