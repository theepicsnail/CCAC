if _G.movelib ~=nil then
  return _G.movelib
end

dofile("/craft/tableio.lua")
local CONFIG_FILE = "/craft/config/move"

local X=1
local Y=1
local W=1
local H=1

local O=0 
-- orientation, 
-- 0=forward,  1=right
 

function init() 
  -- Assuming facing the wall of chests.
  -- This moves the turtle to (1,1) and computes W/H
  local config, err = table.load(CONFIG_FILE)
  turtle.turnRight()
  if err ~= nil then
    print("Starting calibration")
    while turtle.forward() do end
    while turtle.up() do end
    while turtle.down() do 
      H = H + 1 
    end
    while turtle.down() do 
      H = H + 1 
    end
    while turtle.back() do
      W = W + 1
    end
    table.save({W=W,H=H}, CONFIG_FILE)
    print("Calibration complete:")
  else
    print("Loaded config from "..CONFIG_FILE)
    W=config.W
    H=config.H
    while turtle.down() do end
    while turtle.back() do end
  end
  turtle.turnLeft()  
  ---
  print(string.format("W: %u H: %u", W,H))
end

-- Semi intelligent movement things.
-- Keeps track of orientation and location
-- tries to prevent things from getting too out of whack.
function faceForward()
  if O==1 then
    turtle.turnLeft()
    O = 0
    return true
  end
  return false
end

function faceRight()
  if O == 0 then
    turtle.turnRight()
    O = 1
    return true
  end
  return false
end

function forward()
  if O == 1 then
    if turtle.forward() then
      X = X + 1
      return true
    end
  end
  return false
end

function back()
  if O == 1 then
    if turtle.back() then
      X = X - 1
      return true
    end
  end
  return false
end

function up()
  if turtle.up() then
    Y = Y + 1
    return true
  end
  return false
end

function down()
  if turtle.down() then
    Y = Y - 1
    return true
  end
  return false
end

-- Exports
local move = {}
function move.toChest(x,y)
  if x ~= X then
    faceRight()
    while x>X do forward() end
    while x<X do back() end
  end
  while y<Y do down() end
  while Y<y do up() end
  faceForward()
end

function move.toOutput()
  faceRight()
  while Y > 1 do down() end
  while forward() do end
end
init()
move.W = W
move.H = H

_G.movelib = move
return move
