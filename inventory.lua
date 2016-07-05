if _G.inventorylib ~=nil then
  _G.inventorylib.main(...)
  return _G.inventorylib
end

dofile("/craft/tableio.lua")
local move=dofile("/craft/move.lua")

local INV_FILE = "/craft/config/inv"
local inventory, err = table.load(INV_FILE)
local lib = {} -- library methods


function lib.searchName(needle)
  -- return names that match the needle
  local matches = {}
  if not needle then
    return matches
  end

  needle = string.lower(needle)
  for itemType, locations in pairs(inventory) do
    if string.find(string.lower(itemType), needle) ~= nil then
      table.insert(matches, itemType)
    end
  end
  return matches
end


function lib.findLocations(resourceName)
  -- return the locations for a resource
  return inventory[resourceName] or {}
end


function lib.getTotal(resourceName)
  local locs = lib.findLocations(resourceName)
  local total = 0
  for _,entry in pairs(locs) do
    total = total + entry.c
  end
  return total
end

function lib.getTotalResources()
  -- returns a summany of resources
  -- item type -> total
  local resources = {}
  for itemType, locs in pairs(inventory) do
    local total = 0
    for _,loc in pairs(locs) do
      total = total + loc.c
    end
    resources[itemType] = total
  end
  return resources
end
  


function lib.refreshInventory() 
  -- slooowwwww
  local items = {}
  for x = 1, move.W do
    for y = 1, move.H do
      move.toChest(x,y)
      -- pull the contents out
      local item_count = lib.suckChest()
      -- put them back, recording what we put back
      for i = 1,item_count do
        turtle.select(i)
        local item = turtle.getItemDetail()
        local name = item['name']
        local count = item['count']
        local entry = items[name] or {}
        table.insert(entry, {x=x, y=y, c=count})
        items[name] = entry
        turtle.drop()
      end
    end
  end
  table.save(items, INV_FILE)
  move.toChest(1,1)
  return items
end

function lib.suckChest()
  -- pulls items from the chest the robot is facing
  -- pulls up to 16, and returns the number of items it got
  local item_count = 0
  for i = 1,16 do 
    -- item_count = number of found item types
    -- if it's ever not <cur - 1> then we ran out of items
    -- skip doing work
    if item_count == i-1 then
      turtle.select(i)
      if turtle.suck() then
        item_count = i
      end
    end        
  end
  return item_count
end

function lib.findSlotByContents(name)
  -- given an exact name, search the robots personal inv for that
  -- return the index or 0
  for i = 1, 16 do
    turtle.select(i)
    local item = turtle.getItemDetail()
    if item and item['name'] == name then
      return i
    end
  end
  return 0
end

function lib.takeItemFromChest(name, want)
  -- try to take the specified item from whatever chest we're facing.
  -- resulting item is in slot 1, returns how many were taken
  local ntypes = lib.suckChest()
  local targetpos = lib.findSlotByContents(name)
  
  -- put everything else back
  local got = 0
  for i=1,ntypes do
    turtle.select(i)
    if i == targetpos then
      local have = turtle.getItemCount()
      if have > want then
        turtle.drop(have-want)
                
        got = want
      else
        got = have
      end
    else
      turtle.drop()
    end
  end
  turtle.select(targetpos)
  turtle.transferTo(1, got)
  turtle.select(1)
  return got
end

function lib.exportItem(itemtype, itemcount)
  itemcount = itemcount or 1
  local chests = lib.findLocations(itemtype)
  local newChestData = {}
  for _,chest in pairs(chests) do
    if itemcount > 0 then 
      move.toChest(chest.x, chest.y)
      taken = lib.takeItemFromChest(itemtype, itemcount)
      if taken ~= chest.c then
        table.insert(newChestData, {
          x=chest.x,
          y=chest.y,
          c=chest.c-taken
        })
      end
      itemcount = itemcount - taken
      move.toOutput()
      turtle.drop()
    else
      table.insert(newChestData, chest)
    end
  end
  inventory[itemtype] = newChestData
  table.save(inventory, INV_FILE)
end


-- command line functions
local cli = {}

function cli.get(itemtype, itemcount)
  if not itemtype then
    print("get type [count=1]")
    return
  end  
  itemcount = tonumber(itemcount)
  itemcount = itemcount or 1
  local results = lib.searchName(itemtype)
  local count = table.getn(results)
  if count ~= 1 then
    print("item type did not match exactly one type.")
    print("use 'lookup' to refine your search.")
    return
  end
  lib.exportItem(results[1], itemcount)
end

function cli.lookup(needle) 
  if not needle then
    print("Expected name to look up")
    return
  end
  local results = lib.searchName(needle)
  local matches = table.getn(results)
  if matches == 0 then
    print("No results.")
  elseif matches > 1 then
    print(string.format("Found %s results:", matches))
    for _,name in pairs(results) do
      print(string.format("%u : %s", lib.getTotal(name), name))
    end
  else -- exactly 1 match
    local match = results[1]
    print("-- Found:")
    print(match)
    local locs = lib.findLocations(match)
    local total = 0
    for _,loc in pairs(locs) do
      print(string.format("[%u, %u] has %u", loc.x, loc.y, loc.c))
      total = total + loc.c
    end
    print("Total:" .. tostring(total))
  end
end

function cli.refresh()
  local items = lib.refreshInventory()
  local totalTypes = 0
  local totalItems = 0
  for item, _ in pairs(items) do
    totalTypes = totalTypes + 1
    totalItems = totalItems + lib.getTotal(item)
  end
  print("Refreshed inventory:")
  print(string.format("Total types: %u", totalTypes))
  print(string.format("Total items: %u", totalItems))
  
end
function cli.main()
  local exit = false
  cli.exit = function() exit = true end
  cli.main = nil -- hide main
  while not exit do
    term.clear()
    term.setCursorPos(1,1)
    print("Inventory system:")
    for k,_ in pairs(cli) do
      print("-",k)
    end

    print("")
    line = read()
    args = {}
    cmd = nil
    for chunk in string.gmatch(line, "%S+") do
      if cmd == nil then
        cmd = chunk
      else
        table.insert(args, chunk)
      end
    end
    cmd = cli[cmd]
    if cmd ~= nil then
      print(cmd(unpack(args)))
      if exit then return end
    else
      print("Invalid command")
    end
    
    print('Press enter to continue')
    read()
    print("")
  end
end


if err then
  print("Warning: No inventory file found")
  print("Doing inventory sweep")
  inventory = lib.refreshInventory()
  print("Sweep done.")
end
function lib.main(action,...)
  if action ~= nil then 
    local cb = cli[action]
    if cb == nil then
      print("Expected one of:")
      for k,_ in pairs(cli) do
        print("-",k)
      end
    else
      cb(...)
    end
  end
end
lib.main(...)

_G.inventorylib=lib
return lib
