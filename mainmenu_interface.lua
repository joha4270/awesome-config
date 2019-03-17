naughty = require "naughty"
wibox = require "wibox"
beautiful = require "beautiful"
settings = require "settings"
awful = require "awful"

local mainmenu = {
  open = false,
  tree = {},
  containers = {}
}

local function log(text)
  naughty.notify{text = text, timeout = 300}

end

local function itemheight(items)
  items = items or 1
  return beautiful.menu_height * items
end


local function item_ensure_display(item)
  if item.display then
    return
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



  local textwidth = beautiful.menu_width - beautiful.menu_height + 4

  local icon_left = try_load_icon(item.icon)

  local icon_right = nil
  if #item > 0 then
    icon_right = wibox.widget {
      widget = wibox.widget.imagebox,
      forced_height = beautiful.menu_height,
      forced_width = beautiful.menu_height,
      image = try_load_icon(beautiful.menu_submenu_icon),
      point = {y = 0, x = textwidth}
    }
    textwidth = textwidth - beautiful.menu_height
  end


  item.display = wibox.container {
    wibox.layout {
      layout = wibox.layout.manual,
      forced_height = beautiful.menu_height,
      wibox.widget {
        widget = wibox.widget.imagebox,
        forced_width = beautiful.menu_height,
        forced_height = beautiful.menu_height,
        image = icon_left,
        point = {x = 0, y = 0}
      },
      wibox.widget {
        widget = wibox.widget.textbox,
        point = {x = beautiful.menu_height, y = 0},
        forced_width = textwidth,
        forced_height = beautiful.menu_height,
        text = item.name
      },
      icon_right
    },
    widget = wibox.container.background
  }

  --item.display.item = item


  item.display:connect_signal(
    "mouse::enter",
    function(sender)
      sender.bg = beautiful.bg_focus
    end
  )
  item.display:connect_signal(
    "mouse::leave",
    function(sender, hit_data)
      sender.bg = beautiful.bg_normal
    end
  )


end

--- Creates or reuses a container for placing items. Before returning it is sized correctly to the amount of items
local function get_container_for(items)
  local pair = mainmenu.containers[items.depth]
  if not pair then

    pair = {
      container = wibox.layout {
        layout = wibox.layout.manual,
        point = {x = 0, y = 0},
        forced_width = beautiful.menu_width
      }
    }

    if items.depth == 1 then
      log("depth 1 container")
    else

      pair.box = wibox {
        ontop = true,
        x = 0, y = 0,
        width = beautiful.menu_width,
        --height = set later
        visible = false,
        widget = pair.container
      }
      
      log("depth > 1 container")


    end

    mainmenu.containers[items.depth] = pair

  end
  pair.container.height = itemheight(#items)
  return pair.container
end

local function container_set_items(container, items, instant)
  instant = instant or true

  container:reset()
  for i, item in ipairs(items) do
    item_ensure_display(item)
    item.display.bg = beautiful.bg_normal
    item.display.point = {y = itemheight(i-1), x = 0}
    item.slot = i
    container:add(item.display)
  end

end

local function activate(items)
  local container = get_container_for(items)
  container_set_items(container, items, true)
end

--- Initializes or re-initializes the central part of the main window,
-- creating the main container, the level 1 container and the buttons in the main container
-- and setting all those up correctly
local function reinit()
  if not mainmenu.maincontainer then
    local container = get_container_for(mainmenu.tree)
    mainmenu.maincontainer = wibox.layout {
      layout = wibox.layout.manual,
      point = {x = 0, y = 0},
      forced_width = beautiful.menu_width,
      --forced_height = set later
      get_container_for(mainmenu.tree)
    }
    mainmenu.mainbox = wibox{
      ontop = true,
      x = 0,
      y = 0,
      --height = set later
      width = beautiful.menu_width,
      visible = false,
      widget = mainmenu.maincontainer
    }
  end

  local mainmenu_items = math.min(settings.desktop.startmenuentries, #mainmenu.tree)
  mainmenu.mainbox.height = itemheight(mainmenu_items + 0) -- extra items for buttons/omnitext
  mainmenu.mainbox.y = 0 --itemheight(mainmenu_items + 0 + 1)
  mainmenu.maincontainer.forced_height = itemheight(mainmenu_items)


end

local function mainmenu_open()
  local s = awful.screen.focused()
  local ypos = s.geometry.height + s.geometry.y - (mainmenu.mainbox.height + itemheight(1))

  mainmenu.mainbox.x = s.geometry.x
  mainmenu.mainbox.y = ypos

  activate(mainmenu.tree)
  mainmenu.mainbox.visible = true
end

local function mainmenu_close()
  mainmenu.mainbox.visible = false
end

--- Decorates a tree with a few extra pieces of data to support displaying it
local function treefix(tree, depth, path)
  depth = depth or 1
  path = path or {}

  tree.depth = depth
  tree.path = gears.table.clone(path)
  
  for i=1,#tree do
    path[depth] = i
    treefix(tree[i], depth + 1, path)
    path[depth] = nil
  end

end

function mainmenu.settree(newtree)
  log("Manumenu tree updated with " .. (#newtree) .. " root elements")

  treefix(newtree)

  local menufile = io.open("/tmp/awesomemnu.txt", "w+")
  menufile:write(gears.debug.dump_return(newtree))
  menufile:flush()
  menufile:close()


  mainmenu.tree = newtree

  reinit()

  local arrays = 0
  for _, child in ipairs(newtree) do
    --log("Entry: " .. child.name)
    if #child > 0 then
      arrays = arrays + 1
    end
  end
  log("arrays = " .. arrays)
end

function mainmenu.toggle(...)
  mainmenu.open = not mainmenu.open
  if mainmenu.open then
    mainmenu_open()
    log("mainmenu opening")
  else
    mainmenu_close()
    log("mainmenu closing")
  end

end

--[[(function ()
  if mainmenu.maincontainer then
    return
  end

  treefix(mainmenu.tree)

  local listcontainer = get_container_for(mainmenu.tree)

  mainmenu.maincontainer = wibox.layout {
    layout = wibox.layout.manual,
    
  }
  end)()]]--

--[[(function()
    local ks = 0
    for k,_ in pairs(beautiful) do
      ks = ks+ 1
      log("k = " .. k)
    end

    log("test" .. tostring(ks))
  end)()]]--


return mainmenu
