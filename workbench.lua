dofile("/craft/tableio.lua")
local move = dofile("/craft/move.lua")
local inventory = dofile("/craft/inventory.lua")

-- eg: /craft/patterns/minecraft_crafting_table
local PATTERN_BASE = "/craft/patterns/" 
-- filenames can't have ':' so use '_' instead
function fixName(name) return string.gsub(name, ':', '_') end


local lib = {}
-- save/load patterns
function lib.loadPattern(item)
  return table.load(PATTERN_BASE .. fixName(item))
end

function lib.savePattern(item, pattern)
  table.save(pattern, PATTERN_BASE .. fixName(item))
end

function lib.searchPatterns(needle)
  local needle = string.lower(needle)
  local results = {}
  for _,name in pairs(fs.list(PATTERN_BASE)) do
    if string.match(string.lower(name), needle) then
      itemName = string.gsub(name, '_', ':', 1)-- map back to item name
      table.insert(results, itemName)  
    end
  end
  return results
end

function lib.planCrafting(inputResources, item) 
  print("planCrafting:", item)
  -- returns {
  --    bool craftable,
  --    table missing requirements {{'foo',1}, {'bar',2}},
  --    table instructions {{'inv', 'foo', 1}, {'craft', 'bar'}}
  -- }   
  -- true, {},
  -- false, {{resource,count}, {resource, count}..}
  count = inputResources[item]
  if count ~= nil and count > 0 then
    -- we already have it, no crafting changes.
    return true, {}, {{'inv', item, 1}}
  else
    local pattern = lib.loadPattern(item)
    if pattern == nil then -- no pattern for this, can't go deeper
      return false, {{item, 1}}, {{'userProvide', item, 1}}
    end
    
    -- check all of the inputs for craftability
    local overallCraftable = true
    local overallMissing = {}
    local overallInstructions = {}
    for _,ingredient in pairs(pattern.i) do
      local craftable, missing, instructions = lib.planCrafting(inputResources, ingredient.name)
      -- add instructions to our list of things to do
      for _, instr in pairs(instructions) do
        table.insert(overallInstructions, instr)
      end
      
      if craftable then 
        -- it was available (maybe through crafting?) regardless spend it here
        inputResources[ingredient.name] = inputResources[ingredient.name] - 1
      else
        -- missing
        overallCraftable = false
        for _, need in pairs(missing) do
          table.insert(overallMissing, need)
        end
      end
    end
    -- add the result of crafting
    inputResources[pattern.o.name] = (inputResources[pattern.o.name] or 0)+pattern.o.count
    table.insert(overallInstructions, {'craft', item}) -- crafting action 
    table.insert(overallInstructions, {'inv', item, 1})  -- getting the result from inv.
    return overallCraftable, overallMissing, overallInstructions
  end
end


-- read the state of the table
function lib.scanTable()
  local workbench = {}
  for i=1,12 do
    if i % 4 then -- 1 2 3, 5 6 7, 9 10 11
      turtle.select(i)
      item = turtle.getItemDetail()
      if item ~= nil then
        workbench[i] = item
      end
    end
  end
  return workbench
end

-- watch a pattern get crafted, record the input/output
function lib.learnCrafting()
  inputs = lib.scanTable()
  turtle.select(1)
  if not turtle.craft() then
    return nil
  end
  outputs = turtle.getItemDetail()
  
  pattern = {i=inputs,o=outputs}
  lib.savePattern(outputs.name, pattern)
  return pattern
end

--
function lib.craftFromExports(itemtype)
  local pattern = lib.loadPattern(itemtype)
  print("Crafting " .. itemtype)
  move.toOutput()
  turtle.select(16)
  -- pull items from the export chest
  -- if they're right, place them. if not put them in tmp
  
  local hasMoreParts = true
  while hasMoreParts and turtle.suck() do
    -- pulled the entire stack
    local detail = turtle.getItemDetail()
    local placedAt = 0
    for pos, ingr in pairs(pattern.i) do
      if placedAt == 0 and ingr.name == detail.name then
        placedAt = pos
        turtle.transferTo(pos, 1)
        turtle.drop() -- put the rest back in the chest
      end
    end
    
    if placedAt == 0 then
      -- not part of this pattern, put it in storage
      turtle.dropDown()
    else
      -- we placed a piece, remove it from the pattern
      pattern.i[placedAt]=nil
    end
    
    -- check if the pattern is done
    hasMoreParts = false
    for _,_ in pairs(pattern.i) do 
      hasMoreParts=true
    end
  end

  if not hasMoreParts then
    turtle.craft()
    turtle.drop()
    while turtle.suckDown() do turtle.drop() end
  else
    print("Unsatified pattern?")
  end
  
  move.toChest(1,1)
  
end

--- cli endpoints
local cli = {}
function cli.addPattern()
  print("Configure input then press enter")
  read()
  pattern = lib.learnCrafting()
  print(pattern)
end

function cli.craft(name)
  if name == nil then
    print("Enter name:")
    name = read()
  end
  
  local matches = lib.searchPatterns(name)
  local count = table.getn(matches)
  if count ~=1 then
    if count == 0 then
      print("No match found")
    elseif count > 1 then
      print("Multiple matches found:")
      for _,match in pairs(matches) do
        print("-"..match)
      end
    end
    return -- need exactly 1 to continue
  end
  local match = matches[1]
  local inputResources = inventory.getTotalResources()
  local ok, missing, instructions = lib.planCrafting(inputResources, match)
  if not ok then
    print("Can't craft, missing:")
    for _,need in pairs(missing) do
      print(need[1], need[0])
    end
    return
  end
  print("OK")
  local total = table.getn(instructions)
  for n, instr in pairs(instructions) do
    --print(string.format("[%u of %u]\n%s", n, total, table.concat(instr,', ')))
    if instr[1] == 'inv' then
      local itemtype = instr[2]
      local count = instr[3]
      inventory.exportItem(itemtype, count)
    elseif instr[1] == 'craft' then
      lib.craftFromExports(instr[2])
    end
  end
end
  

  
function lib.main(cmd, ...)
  if cmd == nil then 
    return
  end
  cb = cli[cmd]
  if cb ~= nil then 
    print(cb(...))
  else
    print("Expected one of:")
    for k,_ in pairs(cli) do
      print(k)
    end
  end
end
lib.main(...)
return lib
