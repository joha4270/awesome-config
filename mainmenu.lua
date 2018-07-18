awful = require("awful")
settings = require("settings")
beautiful = require("beautiful")
local dpi = beautiful.xresources.apply_dpi
wibox = require("wibox")
naughty = require "naughty"
menubar = require "menubar"
gears = require "gears"


--[[
  Entry needs to store:
  Icon
  Children?
  Name
  Tooltip?
  Launch

]]

local mainmenu = {
  menutree = {
    
  },
  mainmenuwidget = nil,
  listwidget = nil,
  displaystate = {
    currentvisible = {}
  }
}

local categories = {}


local function min(a, b)
  if(a < b) then
    return a
  end
  return b
end


local function itemheight(items)
  items = items or 1
  return beautiful.menu_height * items
end

local function set_display_entries(entries)

  mainmenu.listwidget:reset()
  for i, entry in ipairs(entries) do
    entry.display_item.point =  {y = itemheight(i-1), x = 0}
    mainmenu.listwidget:add(entry.display_item)
  end

  --Assumption: Will never get too many entries to display
  --Assumption: will never try to display the same entry twice


  -- local oldvisible = {table.unpack(mainmenu.displaystate.currentvisible)}

  --local foo = {}
  --naughty.notify {text = "Has " .. #oldvisible .. " items in copy and " .. #mainmenu.displaystate.currentvisible .. " in old"}
  --for i, entry in ipairs(entries) do  --old entries
  --  --set position
    -- entry.display_item.point = {y = itemheight(i-1), x = 0}

    -- if oldvisible[tostring(entry)] then
    --   --remove from oldvisible
    --   oldvisible[tostring(entry)] = nil
    --   naughty.notify {text = "Removing old " .. tostring(entry)}
    -- else
    --   --Display it
    --   mainmenu.mainmenuwidget:add(entry.display_item)

    --   naughty.notify{text = "Showing new item!" .. tostring(entry)}

    --   --Add to currentvisible
    --   mainmenu.displaystate.currentvisible[tostring(entry)] = true
    -- end
  -- end


  -- local count = 0
  -- for k,v in pairs(foo) do
  --   count = count +1
  --   naughty.notify{text = "key is " .. tostring(k)}
  -- end

  -- naughty.notify { text = "After has " .. #oldvisible .. " items in copy and " .. count .. " in old"}

  -- --remove everything in oldvisible

  -- for k, v in pairs(oldvisible) do
  --   if v == nil then
  --     naughty.notify{text "ASSERT FAILED, oldvisible not removed"}
  --   end
  --   mainmenu.mainmenuwidget:remove(k.display_item)
  -- end




end



local function force_close()
  if mainmenu.box.visible then
    mainmenu.toggle()
  end
end

local function runentry(entry)
  naughty.notify{text = "Starting " .. entry.name .. " with command \"" .. entry.exec .. "\""}
  awful.spawn(entry.exec)
end

local function clickhandler(sender)
  local entry = sender.entry
  entry:click()
  force_close()
end

local function hoverhighlight_enter(sender)
  sender.bg = beautiful.bg_focus

end

local function hoverhighlight_leave(sender)

  sender.bg = beautiful.bg_normal

  local output = ""

  for k,v in pairs(sender) do

    --naughty.notify{ text = tostring(k)}
  end



end

local function try_load_icon(icon)
  if icon == nil then
    return nil
  end

  local icon_path = menubar.utils.lookup_icon(icon)

  if icon_path == nil then
    naughty.notify{text = "Did not find icon path for " .. icon}
    return nil
  end

  local img = gears.surface.load(icon_path)

  if img == nil then
    naughty.notify {text = "Did not load icon at " .. icon_path}
  end


  return img
end



local function entry_create_from_program(program)


  if program.Icon == nil then
    naughty.notify {text = program.Name .. " has no icon"}
  end

  --local icon_path = menubar.utils.lookup_icon(program.Icon)

  --naughty.notify{text = "Loading icon " .. icon_path}

  --local icon, err = gears.surface.load_silently(icon_path)

  --naughty.notify {text ="Loaded " .. tostring(icon) .. " with result " .. tostring(err)}


  

  local final = {
    name = program.Name,
    exec = program.Exec,
    working_directory = program.Path,
    terminal = program.Terminal,
    click = runentry,
    display_item = wibox.container {
      wibox.layout {
        layout = wibox.layout.manual,
        forced_height = beautiful.menu_height,
        wibox.widget {
          widget = wibox.widget.imagebox,
          --Should be square with size fitting in menu, so it be width = height
          forced_width = beautiful.menu_height,
          forced_height = beautiful.menu_height,
          --resize_allowed = true,
          --clip_shape = gears.shape.rectangle,
          image = try_load_icon(program.Icon),
          point = {y = 0, x = 0}
        },
        wibox.widget {
          widget = wibox.widget.textbox,
          point = {y = 0, x = beautiful.menu_height},
          forced_width = beautiful.menu_width - beautiful.menu_height,
          forced_height = beautiful.menu_height,
          text = program.Name
        }
      },
      widget = wibox.container.background
    }
  }

  final.display_item.entry = final
  final.display_item:connect_signal("button::press", clickhandler)

  final.display_item:connect_signal("mouse::enter", hoverhighlight_enter)
  final.display_item:connect_signal("mouse::leave", hoverhighlight_leave)

  --Set icon if existing



  return final

end

local function file_callback(programs)
  --naughty.notify{text = "Found " .. #programs .. " programs"}
  for _, program in pairs(programs) do


    

    for z,q in pairs(program) do
      if categories[z] == nil then
        categories[z] = {}
        --naughty.notify {text = "Key: " .. z, timeout = 30}
      end
    end

    --naughty.notify {text = "Before " .. tostring(program.Name)}
    local entry = entry_create_from_program(program)
    --naughty.notify {text = "Created " .. tostring(program.Name)}

    table.insert(mainmenu.menutree, entry) 
    --naughty.notify {text = "After " ..tostring(program.Name)}


    --naughty.notify {text = tostring(v)}
  end
end




local function mainmenuheight()
  return itemheight(2 + min(#mainmenu.menutree, settings.desktop.startmenuentries))
end

local function frombottom(items)
  return mainmenuheight() - itemheight(items)
end


local function input_handler_state()
  return {
    text = "",
    cursor_pos = 1
  }
end

local function input_handler(mod, key, event)
  if event == "release" then
    return
  end

  --update state
  local handlers = {
    ["Super_L"] = force_close,
    ["Escape"] = force_close,
    ["Left"] = function() if mainmenu.input_state.cursor_pos > 1 then
        mainmenu.input_state.cursor_pos = mainmenu.input_state.cursor_pos - 1 end
    end,
    ["Right"] = function() if mainmenu.input_state.cursor_pos < mainmenu.input_state.text:len() +1 then
        mainmenu.input_state.cursor_pos = mainmenu.input_state.cursor_pos + 1 end
    end,


  }

  local handler = handlers[key]
  if handler == nil then
    if(key:len() ~= 1) then
      naughty.notify {text = "Unhandled long key of " .. key}
    else
      mainmenu.input_state.text = mainmenu.input_state.text:sub(1, mainmenu.input_state.cursor_pos-1) .. key .. mainmenu.input_state.text:sub(mainmenu.input_state.cursor_pos )
      mainmenu.input_state.cursor_pos = mainmenu.input_state.cursor_pos + 1
    end
  elseif type(handler) == "function" then
    handler()
  else
    naughty.notify( {text = "non function handler for " .. key})
  end


  --display updated state
  mainmenu.textbox.markup = "<b>" .. mainmenu.input_state.text .. "</b>"

  
end

local function ensure_init()
  if mainmenu.init ~= nil then
    return
  end
  mainmenu.init = 1


  mainmenu.listwidget = wibox.layout {
    layout = wibox.layout.manual,
    point = {x = 0, y = 0},
    forced_width = beautiful.menu_width,
    forced_height = itemheight(settings.desktop.startmenuentries)
  }

  mainmenu.textbox = wibox.widget {
    markup = "",
    valign = 'center',
 --   font = "Source Sans Pro 8",
    widget = wibox.widget.textbox,
    point = {x = dpi(2), y = frombottom(2)},
    forced_height = itemheight(1),
    forced_width = beautiful.menu_width - dpi(4)
  }
  
  --mainmenu.textbox.point = {x = 000, y = frombottom(2) }
  --mainmenu.textbox.forced_width = beautiful.menu_width
  --mainmenu.textbox.forced_height = itemheight(1)
  
  mainmenu.mainmenuwidget = wibox.layout{
    layout =  wibox.layout.manual,
    mainmenu.textbox,
    mainmenu.listwidget
  }

  
  mainmenu.box = wibox({
      ontop = true,
      x = 200,
      y = 0,
      height = mainmenuheight() ,
      width = beautiful.menu_width,
      visible = false,
      widget = mainmenu.mainmenuwidget
  })

  
end


--function called just before the main menu opens, to ensure everything is in correct state
local function mainmenu_onopen()
  local s =  awful.screen.focused()
  mainmenu.box.x = s.geometry.x

  --calculate vertical location
  local bottom_pos = itemheight()
  local top_pos = mainmenu.box.height + bottom_pos
  mainmenu.box.y = s.geometry.height - top_pos

  --Reset omnibox
  mainmenu.input_state = input_handler_state()
  mainmenu.textbox.markup = ""
  awful.keygrabber.run(input_handler)

  --Reset display
  local todisplay = {}

  for i, v in ipairs(mainmenu.menutree) do
    table.insert(todisplay, v)
    if i >= settings.desktop.startmenuentries then
      break
    end
  end
  set_display_entries(todisplay)

  


end

local function mainmenu_onclose()
  awful.keygrabber.stop(input_handler)
end


function mainmenu.toggle()
  ensure_init()
  if mainmenu.box.visible then
    mainmenu_onclose()
  else
    mainmenu_onopen()
  end

  mainmenu.box.visible = not mainmenu.box.visible
end

for _, v in pairs(settings.desktop.paths) do
  menubar.utils.parse_dir(v, file_callback)
end

return mainmenu
