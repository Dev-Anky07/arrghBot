-- Initializing global variables to store the latest game state and game host process.
LatestGameState = LatestGameState or nil  -- Stores all game data
InAction = InAction or false     -- Prevents your bot from doing multiple actions

colors = {
  red = "\27[31m",
  green = "\27[32m",
  blue = "\27[34m",
  reset = "\27[0m",
  gray = "\27[90m"
}

-- Checks if two points are within a given range.
-- @param x1, y1: Coordinates of the first point.
-- @param x2, y2: Coordinates of the second point.
-- @param range: The maximum allowed distance between the points.
-- @return: Boolean indicating if the points are within the specified range.
function inRange(x1, y1, x2, y2, range)
    return math.abs(x1 - x2) <= range and math.abs(y1 - y2) <= range
end

-- Enhanced decision-making for movement and attacking
local function findStrategicPosition(player)
    local bestPosition = {x = player.x, y = player.y}
    local minDistance = math.huge

    -- Iterate through the grid to find the closest position to the nearest enemy
    for x = 1, Width do
        for y = 1, Height do
            local distanceToNearestEnemy = math.huge
            for _, enemy in pairs(Players) do
                if enemy ~= player and inRange(player.x, player.y, enemy.x, enemy.y, Range) then
                    local dx = x - enemy.x
                    local dy = y - enemy.y
                    distanceToNearestEnemy = math.sqrt(dx*dx + dy*dy)
                    break
                end
            end
            if distanceToNearestEnemy < minDistance then
                minDistance = distanceToNearestEnemy
                bestPosition = {x = x, y = y}
            end
        end
    end

    return bestPosition
end

local function shouldConserveEnergy(player)
    local shouldConserve = false

    -- Conserve energy if health is low
    if player.health < 50 then
        shouldConserve = true
    end

    -- Conserve energy if there are multiple enemies nearby
    local nearbyEnemies = 0
    for _, enemy in pairs(Players) do
        if enemy ~= player and inRange(player.x, player.y, enemy.x, enemy.y, Range) then
            nearbyEnemies = nearbyEnemies + 1
        end
    end
    if nearbyEnemies > 1 then
        shouldConserve = true
    end

    return shouldConserve
end

function decideNextAction(player)
    -- Find the strategic position to move to
    local strategicPosition = findStrategicPosition(player)

    -- Determine if the bot should conserve energy
    local shouldConserve = shouldConserveEnergy(player)

    -- Decide between moving and attacking based on strategic position and energy conservation
    if shouldConserve then
        -- If the bot should conserve energy, move towards the strategic position
        moveTo(player, strategicPosition)
    else
        -- Otherwise, attack the nearest enemy
        local nearestEnemy = findNearestEnemy(player)
        if nearestEnemy then
            attack(player, nearestEnemy)
        end
    end
end


--[[

function decideNextAction()
  local player = LatestGameState.Players[ao.id]
  local targetInRange = false
  local bestTarget = nil  -- Stores the ID of the best target player (considering health, distance)
  
  -- Find closest and weakest target within attack range
  for target, state in pairs(LatestGameState.Players) do
    if target ~= ao.id and inRange(player.x, player.y, state.x, state.y, 1) then
      targetInRange = true
      if not bestTarget or state.health < bestTarget.health or (state.health == bestTarget.health and inRange(player.x, player.y, state.x, state.y, 1) < inRange(player.x, player.y, bestTarget.x, bestTarget.y, 1)) then
        bestTarget = state
      end
    end
  end

]]--

  -- Check if the bot should conserve energy
  if shouldConserveEnergy() then
    local strategicPosition = findStrategicPosition()
    if strategicPosition then
        ao.send({Target = Game, Action = "PlayerMove", Player = ao.id, Direction = strategicPosition})
    end
  elseif player.energy > 5 and targetInRange then
    print(colors.red.. "Player in range. Attacking.".. colors.reset)
    ao.send({  -- Attack the closest player with all your energy.
      Target = Game,
      Action = "PlayerAttack",
      Player = ao.id,
      AttackEnergy = tostring(player.energy),
    })
  else
    -- map analysis
    local directionRandom = {"Up", "Down", "Left", "Right", "UpLeft", "UpRight", "DownLeft", "DownRight}
    local randomIndex = math.random(#directionRandom)
    ao.send({Target = Game, Action = "PlayerMove", Player = ao.id, Direction = directionRandom[randomIndex]})
  end
  
  InAction = false -- Reset the "InAction" flag
end

-- Main loop or event handler to call decideNextAction
-- This part of the code depends on how your bot's main loop or event handling is structured
-- Ensure that decideNextAction is called appropriately based on game events or ticks

-- Handler to print game announcements and trigger game state updates.
Handlers.add(
  "PrintAnnouncements",
  Handlers.utils.hasMatchingTag("Action", "Announcement"),
  function (msg)
    if msg.Event == "Started-Waiting-Period" then
      ao.send({Target = ao.id, Action = "AutoPay"})
    elseif (msg.Event == "Tick" or msg.Event == "Started-Game") and not InAction then
      InAction = true -- InAction logic added
      ao.send({Target = Game, Action = "GetGameState"})
    elseif InAction then -- InAction logic added
      print("Previous action still in progress. Skipping.")
    end
    print(colors.green .. msg.Event .. ": " .. msg.Data .. colors.reset)
  end
)

-- Handler to trigger game state updates.
Handlers.add(
  "GetGameStateOnTick",
  Handlers.utils.hasMatchingTag("Action", "Tick"),
  function ()
    if not InAction then -- InAction logic added
      InAction = true -- InAction logic added
      print(colors.gray .. "Getting game state..." .. colors.reset)
      ao.send({Target = Game, Action = "GetGameState"})
    else
      print("Previous action still in progress. Skipping.")
    end
  end
)

-- Handler to automate payment confirmation when waiting period starts.
Handlers.add(
  "AutoPay",
  Handlers.utils.hasMatchingTag("Action", "AutoPay"),
  function (msg)
    print("Auto-paying confirmation fees.")
    ao.send({ Target = Game, Action = "Transfer", Recipient = Game, Quantity = "1000"})
  end
)


-- Handler to update the game state upon receiving game state information.
Handlers.add(
  "UpdateGameState",
  Handlers.utils.hasMatchingTag("Action", "GameState"),
  function (msg)
    local json = require("json")
    LatestGameState = json.decode(msg.Data)
    ao.send({Target = ao.id, Action = "UpdatedGameState"})
    print("Game state updated. Print \'LatestGameState\' for detailed view.")
  end
)

-- Handler to decide the next best action.
Handlers.add(
  "decideNextAction",
  Handlers.utils.hasMatchingTag("Action", "UpdatedGameState"),
  function ()
    if LatestGameState.GameMode ~= "Playing" then
      InAction = false -- InAction logic added
      return
    end
    print("Deciding next action.")
    decideNextAction()
    ao.send({Target = ao.id, Action = "Tick"})
  end
)

-- Handler to automatically attack when hit by another player.
Handlers.add(
  "ReturnAttack",
  Handlers.utils.hasMatchingTag("Action", "Hit"),
  function (msg)
    if not InAction then -- InAction logic added
      InAction = true -- InAction logic added
      local playerEnergy = LatestGameState.Players[ao.id].energy
      if playerEnergy == undefined then
        print(colors.red .. "Unable to read energy." .. colors.reset)
        ao.send({Target = Game, Action = "Attack-Failed", Reason = "Unable to read energy."})
      elseif playerEnergy == 0 then
        print(colors.red .. "Player has insufficient energy." .. colors.reset)
        ao.send({Target = Game, Action = "Attack-Failed", Reason = "Player has no energy."})
      else
        print(colors.red .. "Returning attack." .. colors.reset)
        ao.send({Target = Game, Action = "PlayerAttack", Player = ao.id, AttackEnergy = tostring(playerEnergy)})
      end
      InAction = false -- InAction logic added
      ao.send({Target = ao.id, Action = "Tick"})
    else
      print("Previous action still in progress. Skipping.")
    end
  end
)

Handlers.add(
"HandleAnnouncements",
Handlers.utils.hasMatchingTag("Action", "Announcement"),
function (msg)
  ao.send({Target = Game, Action = "GetGameState"})
  print(msg.Event .. ": " .. msg.Data)
end
)

Handlers.add(
  "ReSpawn",
  Handlers.utils.hasMatchingTag("Action", "Eliminated"),
  function (msg)
    Send({Target = CRED, Action = "Transfer", Quantity = "1000", Recipient = Game})
  end
)

Handlers.add(
  "StartTick",
  Handlers.utils.hasMatchingTag("Action", "Payment-Received"),
  function (msg)
    Send({Target = Game, Action = "GetGameState", Name = Name, Owner = Owner })
    print('Start Moooooving!')
  end
)