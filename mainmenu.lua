awful = require("awful")
settings = require("settings")
beautiful = require("beautiful")
local dpi = beautiful.xresources.apply_dpi
wibox = require("wibox")
naughty = require "naughty"
menubar = require "menubar"
gears = require "gears"
math = require "math"


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
  box = nil,
  mainmenuwidget = nil,
  listwidget = nil,
  categories = {},
  displaystate = {
    openpath = {},
    extensions = {}
  }
}

--forward function decleartions
local update_tree_menu, log, close_extensions_above


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


local function mainmenuheight()
  return itemheight(2 + min(#mainmenu.menutree, settings.desktop.startmenuentries))
end

local function frombottom(items)
  return mainmenuheight() - itemheight(items)
end

local function force_close()
  if mainmenu.box.visible then
    mainmenu.toggle()
  end
  close_extensions_above(1)
end

local function runentry(entry)

  local exec = entry.exec
  exec = exec:gsub("%%U", "")
  exec = exec:gsub("%%u", "")
  exec = exec:gsub("%%F", "")

  --naughty.notify{text = "Starting " .. entry.name .. " with command \"" .. exec .. "\""}
  awful.spawn(exec)
end

local function clickhandler(sender)
  local entry = sender.entry
  entry:click()
  force_close()
end


local function item_enter(sender)
  local depth = sender.entry.depth

  mainmenu.displaystate.openpath[depth] = sender.entry
  mainmenu.displaystate.openpath[depth+1] = nil

  update_tree_menu()
end

local function item_leave(sender, hit_data)
  local depth = sender.entry.depth
  local coords = mouse.coords()

  if coords.x >= hit_data.width then
    return
  end

  mainmenu.displaystate.openpath[depth] = nil

  update_tree_menu()
end

local function try_load_icon(icon)
  if icon == nil then
    return nil
  end

  local icon_path = menubar.utils.lookup_icon(icon)

  if icon_path == nil then
    return nil
  end

  local img = gears.surface.load(icon_path)

  if img == nil then
    naughty.notify {text = "Did not load icon at " .. icon_path}
  end

  return img
end

local function entry_create_display_raw(text, icon_left, icon_right)

  local textwidth = beautiful.menu_width - beautiful.menu_height + 4

  local icon2 = nil

  if icon_right ~= nil then
    icon2 = wibox.widget {
      widget = wibox.widget.imagebox,
      forced_width = beautiful.menu_height,
      forced_height = beautiful.menu_height,
      image = icon_right,
      point = {y = 0, x = textwidth}
    }
    textwidth = textwidth - beautiful.menu_height
  end


  local display_item = wibox.container {
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
        image = icon_left,
        point = {y = 0, x = 0}
      },
      wibox.widget {
        widget = wibox.widget.textbox,
        point = {y = 0, x = beautiful.menu_height},
        forced_width = textwidth,
        forced_height = beautiful.menu_height,
        text = text
      },
      icon2
    },
    widget = wibox.container.background
  }


  display_item:connect_signal("mouse::enter", item_enter)
  display_item:connect_signal("mouse::leave", item_leave)

  return display_item
end

local function entry_create_from_program(program)


  if program.Icon == nil then
    naughty.notify {text = program.Name .. " has no icon"}
  end

  local final = {
    name = program.Name,
    icon = program.Icon,
    exec = program.Exec,
    working_directory = program.Path,
    terminal = program.Terminal,
    click = runentry,
    display_item = entry_create_display_raw(program.Name, try_load_icon(program.Icon))
  }

  final.display_item.entry = final
  final.display_item:connect_signal("button::press", clickhandler)


  return final

end

local function get_category_entry(category_name)
  if mainmenu.categories[category_name] == nil then

    local entry = {
     name = category_name,
     display_item = entry_create_display_raw(category_name, nil, try_load_icon(beautiful.menu_submenu_icon)),
     children = {}
    }

    entry.display_item.entry = entry

    mainmenu.categories[category_name] = entry
    table.insert(mainmenu.menutree, entry)

  end

  return mainmenu.categories[category_name]
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

--start of new lazy tree based system

function log(text)
  naughty.notify {text = text}
end

local function list_first_n(list, n)
  local r = {}
  for i, v in ipairs(list) do
    table.insert(r, v)
    if i >= n then
      break
    end
  end
  return r
end

local function entry_ensure_display_item(entry)
  if entry.display_item ~= nil then
    return
  end

  entry.display_item = entry_create_display_raw(entry.name, try_load_icon(entry.icon))
  entry.display_item.entry = entry

end

local function set_widget_entries(widget, entries)
  widget:reset()
  for i, entry in ipairs(entries) do
    entry.display_item.bg = beautiful.bg_normal
    entry_ensure_display_item(entry)
    entry.display_item.point = {y = itemheight(i-1), x = 0}
    entry.slot = i - 1
    widget:add(entry.display_item)
  end
end

local function recursive_set_depth(menutree, depth)
  if depth == nil then
    depth = 1
  end

  for i, v in ipairs(menutree) do
    v.depth = depth
    if v.children ~= nil then
      recursive_set_depth(v.children, depth+1)
    end
  end
end

local function get_or_create_extension_widget(depth)
  if mainmenu.displaystate.extensions[depth] == nil then
    local widget = wibox.layout {
      layout = wibox.layout.manual
    }

    mainmenu.displaystate.extensions[depth] = {
      widget = widget,
      box = wibox {
        ontop = true,
        width = beautiful.menu_width,
        y = 400, --placeholder, remove?
        x = beautiful.menu_width * depth,
        widget = widget
      }
    }
  end

  local extension = mainmenu.displaystate.extensions[depth]
  extension.box.visible = true
  return extension
end

function close_extensions_above(level)
  for i=level, #mainmenu.displaystate.extensions do
    mainmenu.displaystate.extensions[i].box.visible = false
  end
end

local function update_menu_level(list, widget, focus)
  local cutlist = list_first_n(list, settings.desktop.startmenuentries)
  set_widget_entries(widget, cutlist)

  if focus ~= nil then
    focus.display_item.bg =beautiful.bg_focus
  end
end

function update_tree_menu()
  --naughty.notify{text = "MENU!"}

  recursive_set_depth(mainmenu.menutree) --TODO: don't do every time


  --Actually update the menu
  update_menu_level(mainmenu.menutree, mainmenu.listwidget, mainmenu.displaystate.openpath[1])

  local i = 1
  local oldy = mainmenu.box.y

  while mainmenu.displaystate.openpath[i] ~= nil  do
    local element = mainmenu.displaystate.openpath[i]
    if element.children ~= nil and #element.children >= 1 then
      local extension = get_or_create_extension_widget(i)
      local newy = oldy + itemheight(element.slot)
      extension.box.y = newy
      extension.box.height = itemheight(math.min(#element.children, settings.desktop.startmenuentries))
      update_menu_level(element.children, extension.widget, mainmenu.displaystate.openpath[i+1])
    end
    i = i + 1
  end


  close_extensions_above(i) -- -1?)


end
--end of new lazy tree based system

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

  --Reset display
  update_tree_menu()

  --Reset omnibox
  mainmenu.input_state = input_handler_state()
  mainmenu.textbox.markup = ""
  awful.keygrabber.run(input_handler)
end

local function mainmenu_onclose()
  awful.keygrabber.stop(input_handler)
  close_extensions_above(1)
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


local function file_callback(programs)
  for _, program in pairs(programs) do
    --log("found " .. program.Name)
    local entry = entry_create_from_program(program)

    local categories = program.Categories
    local category = nil


    if categories ~= nil then
      --naughty.notify {text = "Category of " .. categories}
      for str in categories:gmatch("[^;]+") do
        category = str
        break
      end
    end

    if category ~= nil then
      local category_entry = get_category_entry(category)

      table.insert(category_entry.children, entry)

    else
      table.insert(mainmenu.menutree, entry)
    end
  end
end


for _, v in pairs(settings.desktop.paths) do
  log("checking " .. v)
  menubar.utils.parse_dir(v, file_callback)
end

return mainmenu
