naughty = require "naughty"
gears = require "gears"

menubar = require "menubar"

mainmenu = require "mainmenu_interface"
settings = require "settings"

local function log(text)
  naughty.notify{text = text, timeout = 300}
end


local unique_names = {}
local function insert_sorted(target, item, sortkey)

  --log("inserting based on " .. sortkey)
  --log("inserting into " .. tostring(target))
  --log("inserting " .. tostring(item))
  if unique_names[sortkey] then
    --log("duplicate " .. sortkey)
  else
    --log("bux " .. type(sortkey) .. " " .. sortkey)
    unique_names[sortkey] = 1
  end

  pos = 1

  --log("entering insert, #target = " .. #target)

  if #target ~= 0 then
    for i=#target,1,-1 do
    --  log("loop, i = " .. i)
      target[i+1] = target[i]
      pos = i
      if target[i+1].key < sortkey then
        break
      end
    end
  end

  --log("pos = " .. pos)

  target[pos] = item

  --log("inserted, setting up key")

  item.key = sortkey


  --log("end of insert")


end

local function find_or_create_category(entry, category_name)
  for _, child in ipairs(entry) do
    if child.key == category_name then
      return child
    end
  end

  local item = {name = category_name}
  insert_sorted(entry, item, category_name)

  return item

end


local function generate(programs)

  log("alive!")

  local root_entry = {}


  for _, program in ipairs(programs) do
    log("processing " .. program.name .. "(" .. (program.category or "nil")  .. ")")

    --for k,v in pairs(program) do
    --  log(k .. " = " .. v)
    --end

    local destination_entry
    if program.category ~= nil then
      destination_entry = find_or_create_category(root_entry, program.category)
    else
      destination_entry = root_entry
    end

    --log("after")

    log("dest = " .. gears.debug.dump_return(destination_entry))

    insert_sorted(destination_entry, {name = program.name}, program.name)

   log("done " .. program.name)
  end

  log("tree = " .. gears.debug.dump_return(root_entry))

  mainmenu.settree(root_entry)
end


function regenerate()
  log(gears.debug.dump_return(menubar.menu_gen.all_menu_dirs))
  menubar.menu_gen.all_menu_dirs = settings.desktop.paths
  menubar.menu_gen.generate(generate)
end

function extract_category(categories)
  --log("Categories = " .. tostring(categories))
  --for k, v in pairs(categories) do
  --  log("categories[" .. k .. "]=" .. tostring(v))
  --end

  if ((categories == nil) or (#categories == 0)) then
    --log("returning NIL")
    return nil
  end

  return categories[1]

  --for str in categories:gmatch("[^;]+") do
  --  log("returning " .. str)
  --  return str
  --end

  --log("bad end of extract_category")
end


function regenerate2()
  local directories = #settings.desktop.paths
  local root_entry = {}

  log("searching for desktop entries in " .. directories .. " directories")


  for _, path in pairs(settings.desktop.paths) do
    menubar.utils.parse_dir(
      path,
      function (programs)
        log(path .. " Starting")
        for _, program in pairs(programs) do

          --log("start of loop")

          if program.NoDisplay then
 --           log("ignoring " .. tostring(program.Name) .. " due NoDisplay")
          else
            --log("creating entry")
            local entry = {
              name = program.Name,
              category = extract_category(program.Categories),
             -- exec = program.Exec,
              icon = program.Icon
            }
            local destination_entry
            --log("Category = " .. (program.category or "nil" ))
            if entry.category ~= nil then
              destination_entry = find_or_create_category(root_entry, entry.category)
            else
              destination_entry = root_entry
            end
            insert_sorted(destination_entry, entry, entry.name)
          end
        end

        directories = directories - 1
        log("finished " .. path .. " containing " .. #programs .. " entries (" .. directories .. ") left")
        if directories == 0 then
          mainmenu.settree(root_entry)
        end
    end)
  end


end

regenerate2()
