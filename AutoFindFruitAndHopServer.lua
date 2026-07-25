--[[
  ╔══════════════════════════════════════════════════════════════╗
  ║           BLOX FRUIT - AUTO FRUIT SNIPER SCRIPT             ║
  ║       Scan → Fly → Grab → Store (3 retries) → Hop          ║
  ║              Built for LEARNING purposes only               ║
  ║               + AUTO TEAM SELECTION (SETTEAM)               ║
  ╚══════════════════════════════════════════════════════════════╝
]]

-- ═══════════════════════════════════════════════════════════════
-- WAIT FOR GAME TO FULLY LOAD
-- ═══════════════════════════════════════════════════════════════
repeat task.wait() until game:IsLoaded()

-- ═══════════════════════════════════════════════════════════════
-- CONFIGURATION
-- ═══════════════════════════════════════════════════════════════
getgenv().AutoFruitSniper   = true   -- Master toggle for the script
getgenv().FruitESP          = true   -- Show ESP on fruits
getgenv().TweenSpeed        = 300    -- Flight speed (studs/sec)
getgenv().StoreRetries      = 3      -- Max store attempts before giving up
getgenv().HopDelay          = 3      -- Seconds to wait before server hop
getgenv().ScanInterval      = 0.5    -- How often to scan for fruits (seconds)
getgenv().AntiAFK           = true   -- Prevent AFK kick
getgenv().AutoSelectTeam    = true   -- Auto select team when entering game
getgenv().Team              = "Marines" -- "Marines" or "Pirates"

-- ═══════════════════════════════════════════════════════════════
-- SERVICES
-- ═══════════════════════════════════════════════════════════════
local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService      = game:GetService("TweenService")
local VirtualUser       = game:GetService("VirtualUser")
local HttpService       = game:GetService("HttpService")
local TeleportService   = game:GetService("TeleportService")
local RunService        = game:GetService("RunService")

-- ═══════════════════════════════════════════════════════════════
-- CORE REFERENCES
-- ═══════════════════════════════════════════════════════════════
local Remotes = ReplicatedStorage:WaitForChild("Remotes", 9e9)
local CommF   = Remotes:WaitForChild("CommF_", 9e9)
local Player  = Players.LocalPlayer

-- Global execution states
local activeTween = nil
local IsFarming = false
local uiExists = true

-- ═══════════════════════════════════════════════════════════════
-- IN-GAME GUI NOTIFICATION SYSTEM
-- ═══════════════════════════════════════════════════════════════
local oldGui = Player:FindFirstChild("PlayerGui") and Player.PlayerGui:FindFirstChild("FruitSniperGUI")
if oldGui then oldGui:Destroy() end

local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "FruitSniperGUI"
ScreenGui.ResetOnSpawn = false
ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
ScreenGui.Parent = Player:WaitForChild("PlayerGui")

local MainFrame = Instance.new("Frame")
MainFrame.Name = "MainFrame"
MainFrame.Size = UDim2.new(0, 340, 0, 260)
MainFrame.Position = UDim2.new(0, 15, 0, 15)
MainFrame.BackgroundColor3 = Color3.fromRGB(15, 15, 25)
MainFrame.BackgroundTransparency = 0.15
MainFrame.BorderSizePixel = 0
MainFrame.Parent = ScreenGui

local MainCorner = Instance.new("UICorner", MainFrame)
MainCorner.CornerRadius = UDim.new(0, 10)

local MainStroke = Instance.new("UIStroke", MainFrame)
MainStroke.Color = Color3.fromRGB(100, 50, 255)
MainStroke.Thickness = 1.5
MainStroke.Transparency = 0.3

local TitleBar = Instance.new("Frame")
TitleBar.Name = "TitleBar"
TitleBar.Size = UDim2.new(1, 0, 0, 36)
TitleBar.BackgroundColor3 = Color3.fromRGB(100, 50, 255)
TitleBar.BackgroundTransparency = 0.4
TitleBar.BorderSizePixel = 0
TitleBar.Parent = MainFrame

local TitleCorner = Instance.new("UICorner", TitleBar)
TitleCorner.CornerRadius = UDim.new(0, 10)

local TitleFix = Instance.new("Frame")
TitleFix.Size = UDim2.new(1, 0, 0, 12)
TitleFix.Position = UDim2.new(0, 0, 1, -12)
TitleFix.BackgroundColor3 = Color3.fromRGB(100, 50, 255)
TitleFix.BackgroundTransparency = 0.4
TitleFix.BorderSizePixel = 0
TitleFix.Parent = TitleBar

local TitleLabel = Instance.new("TextLabel")
TitleLabel.Name = "Title"
TitleLabel.Size = UDim2.new(1, -10, 1, 0)
TitleLabel.Position = UDim2.new(0, 10, 0, 0)
TitleLabel.BackgroundTransparency = 1
TitleLabel.Text = "🍎 FRUIT SNIPER"
TitleLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
TitleLabel.TextSize = 16
TitleLabel.Font = Enum.Font.GothamBold
TitleLabel.TextXAlignment = Enum.TextXAlignment.Left
TitleLabel.Parent = TitleBar

local StatusLabel = Instance.new("TextLabel")
StatusLabel.Name = "Status"
StatusLabel.Size = UDim2.new(1, -20, 0, 28)
StatusLabel.Position = UDim2.new(0, 10, 0, 42)
StatusLabel.BackgroundTransparency = 1
StatusLabel.Text = "⏳ Initializing..."
StatusLabel.TextColor3 = Color3.fromRGB(255, 200, 50)
StatusLabel.TextSize = 14
StatusLabel.Font = Enum.Font.GothamBold
StatusLabel.TextXAlignment = Enum.TextXAlignment.Left
StatusLabel.TextWrapped = true
StatusLabel.Parent = MainFrame

local LogFrame = Instance.new("ScrollingFrame")
LogFrame.Name = "LogFrame"
LogFrame.Size = UDim2.new(1, -20, 1, -80)
LogFrame.Position = UDim2.new(0, 10, 0, 74)
LogFrame.BackgroundColor3 = Color3.fromRGB(5, 5, 15)
LogFrame.BackgroundTransparency = 0.3
LogFrame.BorderSizePixel = 0
LogFrame.ScrollBarThickness = 4
LogFrame.ScrollBarImageColor3 = Color3.fromRGB(100, 50, 255)
LogFrame.CanvasSize = UDim2.new(0, 0, 0, 0)
LogFrame.AutomaticCanvasSize = Enum.AutomaticSize.Y
LogFrame.Parent = MainFrame

local LogCorner = Instance.new("UICorner", LogFrame)
LogCorner.CornerRadius = UDim.new(0, 6)

local LogLayout = Instance.new("UIListLayout", LogFrame)
LogLayout.SortOrder = Enum.SortOrder.LayoutOrder
LogLayout.Padding = UDim.new(0, 2)

local LogPadding = Instance.new("UIPadding", LogFrame)
LogPadding.PaddingTop = UDim.new(0, 4)
LogPadding.PaddingLeft = UDim.new(0, 6)
LogPadding.PaddingRight = UDim.new(0, 6)

local MSG_COLORS = {
  success = Color3.fromRGB(80, 255, 80),
  error   = Color3.fromRGB(255, 80, 80),
  warn    = Color3.fromRGB(255, 200, 50),
  info    = Color3.fromRGB(150, 180, 255),
  action  = Color3.fromRGB(0, 200, 255),
  fruit   = Color3.fromRGB(255, 100, 200),
  hop     = Color3.fromRGB(180, 130, 255),
}

local logOrder = 0

local function Notify(message, msgType, isStatus)
  msgType = msgType or "info"
  local color = MSG_COLORS[msgType] or MSG_COLORS.info
  if isStatus then
    StatusLabel.Text = message
    StatusLabel.TextColor3 = color
  end
  logOrder = logOrder + 1
  local LogEntry = Instance.new("TextLabel")
  LogEntry.Name = "Log_" .. logOrder
  LogEntry.LayoutOrder = logOrder
  LogEntry.Size = UDim2.new(1, 0, 0, 16)
  LogEntry.BackgroundTransparency = 1
  LogEntry.Text = os.date("%H:%M:%S") .. "  " .. message
  LogEntry.TextColor3 = color
  LogEntry.TextSize = 11
  LogEntry.Font = Enum.Font.Gotham
  LogEntry.TextXAlignment = Enum.TextXAlignment.Left
  LogEntry.TextWrapped = true
  LogEntry.AutomaticSize = Enum.AutomaticSize.Y
  LogEntry.Parent = LogFrame
  task.defer(function()
    LogFrame.CanvasPosition = Vector2.new(0, LogFrame.AbsoluteCanvasSize.Y)
  end)
  print("[FruitSniper] " .. message)
end

-- ═══════════════════════════════════════════════════════════════
-- AUTO TEAM SELECTION WITH LOAD WAIT
-- ═══════════════════════════════════════════════════════════════
local function WaitAndSelectTeam()
  if not getgenv().AutoSelectTeam then
    Notify("⏩ Auto team selection is disabled.", "info")
    return
  end

  -- Wait for Team to be set or select one
  if Player.Team and Player.Team.Name ~= "Neutral" and Player.Team.Name ~= "" then
    Notify("✅ Team already loaded: " .. Player.Team.Name, "success")
    return
  end

  local teamValue = getgenv().Team or "Marines"
  local teamName = "Marines"
  if typeof(teamValue) == "string" then
    if teamValue:lower():find("pirate") then
      teamName = "Pirates"
    end
  elseif teamValue == 1 then
    teamName = "Pirates"
  end

  Notify("⏳ Selecting team: " .. teamName .. "...", "action", true)
  
  -- Try SetTeam via Remote
  for i = 1, 15 do
    if not getgenv().AutoFruitSniper then return end
    pcall(function()
      CommF:InvokeServer("SetTeam", teamName)
    end)
    task.wait(0.5)
    if Player.Team and Player.Team.Name ~= "Neutral" and Player.Team.Name ~= "" then
      break
    end
  end

  -- Fallback: Click GUI if still neutral
  if not (Player.Team and Player.Team.Name ~= "Neutral" and Player.Team.Name ~= "") then
    pcall(function()
      local playerGui = Player:WaitForChild("PlayerGui", 5)
      local mainGui = playerGui:WaitForChild("Main", 3)
      local chooseTeam = mainGui:WaitForChild("ChooseTeam", 3)
      local container = chooseTeam:WaitForChild("Container", 2)
      local button = container:WaitForChild(teamName, 2):WaitForChild("Frame", 1):WaitForChild("ViewportFrame", 1):WaitForChild("TextButton", 1)
      
      if button then
        for _, conn in pairs(getconnections(button.MouseButton1Click)) do
          conn.Function()
        end
      end
    end)
  end

  task.wait(1)
  if Player.Team and Player.Team.Name ~= "Neutral" and Player.Team.Name ~= "" then
    Notify("✅ Team loaded: " .. Player.Team.Name, "success")
  else
    Notify("⚠️ Could not verify Team selection. Proceeding...", "warn", true)
  end
end

-- ═══════════════════════════════════════════════════════════════
-- FRUIT NAME → STORE ID MAPPING
-- ═══════════════════════════════════════════════════════════════
local function Get_Fruit(Fruit)
  if Fruit == "Rocket Fruit" then return "Rocket-Rocket"
  elseif Fruit == "Spin Fruit" then return "Spin-Spin"
  elseif Fruit == "Chop Fruit" then return "Chop-Chop"
  elseif Fruit == "Spring Fruit" then return "Spring-Spring"
  elseif Fruit == "Bomb Fruit" then return "Bomb-Bomb"
  elseif Fruit == "Smoke Fruit" then return "Smoke-Smoke"
  elseif Fruit == "Spike Fruit" then return "Spike-Spike"
  elseif Fruit == "Flame Fruit" then return "Flame-Flame"
  elseif Fruit == "Falcon Fruit" then return "Falcon-Falcon"
  elseif Fruit == "Ice Fruit" then return "Ice-Ice"
  elseif Fruit == "Sand Fruit" then return "Sand-Sand"
  elseif Fruit == "Dark Fruit" then return "Dark-Dark"
  elseif Fruit == "Ghost Fruit" then return "Ghost-Ghost"
  elseif Fruit == "Diamond Fruit" then return "Diamond-Diamond"
  elseif Fruit == "Light Fruit" then return "Light-Light"
  elseif Fruit == "Rubber Fruit" then return "Rubber-Rubber"
  elseif Fruit == "Barrier Fruit" then return "Barrier-Barrier"
  elseif Fruit == "Magma Fruit" then return "Magma-Magma"
  elseif Fruit == "Quake Fruit" then return "Quake-Quake"
  elseif Fruit == "Buddha Fruit" then return "Buddha-Buddha"
  elseif Fruit == "Love Fruit" then return "Love-Love"
  elseif Fruit == "Spider Fruit" then return "Spider-Spider"
  elseif Fruit == "Sound Fruit" then return "Sound-Sound"
  elseif Fruit == "Phoenix Fruit" then return "Phoenix-Phoenix"
  elseif Fruit == "Portal Fruit" then return "Portal-Portal"
  elseif Fruit == "Rumble Fruit" then return "Rumble-Rumble"
  elseif Fruit == "Pain Fruit" then return "Pain-Pain"
  elseif Fruit == "Blizzard Fruit" then return "Blizzard-Blizzard"
  elseif Fruit == "Gravity Fruit" then return "Gravity-Gravity"
  elseif Fruit == "Mammoth Fruit" then return "Mammoth-Mammoth"
  elseif Fruit == "T-Rex Fruit" then return "T-Rex-T-Rex"
  elseif Fruit == "Dough Fruit" then return "Dough-Dough"
  elseif Fruit == "Shadow Fruit" then return "Shadow-Shadow"
  elseif Fruit == "Venom Fruit" then return "Venom-Venom"
  elseif Fruit == "Control Fruit" then return "Control-Control"
  elseif Fruit == "Spirit Fruit" then return "Spirit-Spirit"
  elseif Fruit == "Dragon Fruit" then return "Dragon-Dragon"
  elseif Fruit == "Leopard Fruit" then return "Leopard-Leopard"
  elseif Fruit == "Kitsune Fruit" then return "Kitsune-Kitsune"
  end
end

-- ═══════════════════════════════════════════════════════════════
-- INVISIBLE PLATFORM
-- ═══════════════════════════════════════════════════════════════
local block = Instance.new("Part")
block.Size         = Vector3.new(1, 1, 1)
block.Name         = "FruitSniper_Platform"
block.Anchored     = true
block.CanCollide   = false
block.CanTouch     = false
block.Transparency = 1
block.Parent       = workspace

local existingBlock = workspace:FindFirstChild(block.Name)
if existingBlock and existingBlock ~= block then
  existingBlock:Destroy()
end

-- ═══════════════════════════════════════════════════════════════
-- NO-CLIP + POSITION SYNC
-- ═══════════════════════════════════════════════════════════════
task.spawn(function()
  repeat task.wait()
  until (Player.Character and (Player.Character:FindFirstChild("HumanoidRootPart") or Player.Character.PrimaryPart)) or not uiExists
  if not uiExists then return end
  
  local initialChar = Player.Character
  local initialPP = initialChar and (initialChar:FindFirstChild("HumanoidRootPart") or initialChar.PrimaryPart)
  if initialPP then
    block.CFrame = initialPP.CFrame
  end

  while task.wait() and uiExists do
    pcall(function()
      if IsFarming and getgenv().AutoFruitSniper then
        if block and block.Parent == workspace then
          local plrPP = Player.Character and (Player.Character:FindFirstChild("HumanoidRootPart") or Player.Character.PrimaryPart)
          if plrPP then
            plrPP.CFrame = block.CFrame
          end
        end
        local plrChar = Player.Character
        if plrChar then
          for _, part in pairs(plrChar:GetChildren()) do
            if part:IsA("BasePart") then
              part.CanCollide = false
            end
          end
          if plrChar:FindFirstChild("Stun") and plrChar.Stun.Value ~= 0 then
            plrChar.Stun.Value = 0
          end
          if plrChar:FindFirstChild("Busy") and plrChar.Busy.Value then
            plrChar.Busy.Value = false
          end
        end
      else
        local plrChar = Player.Character
        if plrChar then
          for _, part in pairs(plrChar:GetChildren()) do
            if part:IsA("BasePart") then
              part.CanCollide = true
            end
          end
        end
      end
    end)
  end
end)

-- ═══════════════════════════════════════════════════════════════
-- TWEEN / FLY TO POSITION
-- ═══════════════════════════════════════════════════════════════
local function TweenToPosition(targetCFrame, targetFruit)
  local targetPos = targetCFrame.Position or targetCFrame.p
  local reachedTarget = false
  
  while getgenv().AutoFruitSniper and uiExists do
    local plrChar = Player.Character
    local plrPP = plrChar and (plrChar:FindFirstChild("HumanoidRootPart") or plrChar.PrimaryPart)
    if not plrPP then 
      task.wait(0.5)
      continue 
    end
    
    local distance = (plrPP.Position - targetPos).Magnitude
    if distance <= 3 then
      reachedTarget = true
      break
    end
    
    -- Sync block CFrame
    if (block.Position - plrPP.Position).Magnitude > 200 then
      block.CFrame = plrPP.CFrame
    end
    
    local speed = getgenv().TweenSpeed or 300
    local tweenTime = distance / speed
    if tweenTime < 0.1 then tweenTime = 0.1 end
    
    activeTween = TweenService:Create(
      block,
      TweenInfo.new(tweenTime, Enum.EasingStyle.Linear),
      {CFrame = targetCFrame}
    )
    activeTween:Play()
    
    local completed = false
    local connection
    connection = activeTween.Completed:Connect(function(state)
      if state == Enum.PlaybackState.Completed then
        reachedTarget = true
      end
      completed = true
    end)
    
    local lastPos = plrPP.Position
    local stuckTicks = 0
    local lastCheck = tick()
    
    while not completed and getgenv().AutoFruitSniper and uiExists do
      if not FruitFind() or (targetFruit and (not targetFruit.Parent or targetFruit.Parent ~= workspace)) then
        if activeTween then activeTween:Cancel() end
        if connection then connection:Disconnect() end
        return
      end
      
      if activeTween and activeTween.PlaybackState ~= Enum.PlaybackState.Playing then
        break
      end
      
      if tick() - lastCheck >= 1 then
        local currentPos = plrPP.Position
        local distMoved = (currentPos - lastPos).Magnitude
        if distMoved < 5 then
          stuckTicks = stuckTicks + 1
          if stuckTicks >= 2 then
            Notify("⚠️ Stuck detected! Restarting flight tween...", "warn")
            break
          end
        else
          stuckTicks = 0
        end
        lastPos = currentPos
        lastCheck = tick()
      end
      
      task.wait(0.1)
    end
    
    if connection then
      connection:Disconnect()
    end
    
    if activeTween then
      activeTween:Cancel()
      activeTween = nil
    end
    
    if reachedTarget then
      break
    end
    
    task.wait(0.1)
  end
  
  activeTween = nil
end

-- ═══════════════════════════════════════════════════════════════
-- FRUIT FINDER
-- ═══════════════════════════════════════════════════════════════
function FruitFind()
  local fruits = workspace:GetChildren()
  local FruitDistance = math.huge
  local FoundFruit = nil

  for _, fruit in pairs(fruits) do
    local plrChar = Player.Character
    local plrPP = plrChar and (plrChar:FindFirstChild("HumanoidRootPart") or plrChar.PrimaryPart)
    local isTool = fruit and fruit:IsA("Tool") and fruit:FindFirstChild("Handle")
    local isFruitNamed = fruit and string.find(fruit.Name, "Fruit") and fruit:FindFirstChild("Handle")

    if plrPP and isTool and (plrPP.Position - isTool.Position).Magnitude <= FruitDistance then
      FruitDistance = (plrPP.Position - isTool.Position).Magnitude
      FoundFruit = fruit
    elseif plrPP and isFruitNamed and (plrPP.Position - isFruitNamed.Position).Magnitude <= FruitDistance then
      FruitDistance = (plrPP.Position - isFruitNamed.Position).Magnitude
      FoundFruit = fruit
    end
  end

  return FoundFruit
end

-- ═══════════════════════════════════════════════════════════════
-- FRUIT ESP
-- ═══════════════════════════════════════════════════════════════
local function AddESP(Part, ESPColor)
  if Part and Part:FindFirstChild("ESP_FruitSniper") then return end

  local Folder = Instance.new("Folder", Part)
  Folder.Name = "ESP_FruitSniper"

  local BBG = Instance.new("BillboardGui", Folder)
  BBG.Adornee = Part
  BBG.Size = UDim2.new(0, 120, 0, 50)
  BBG.StudsOffset = Vector3.new(0, 3, 0)
  BBG.AlwaysOnTop = true

  local TL = Instance.new("TextLabel", BBG)
  TL.BackgroundTransparency = 1
  TL.Size = UDim2.new(1, 0, 1, 0)
  TL.TextSize = 14
  TL.Font = Enum.Font.GothamBold
  TL.TextColor3 = ESPColor or Color3.fromRGB(255, 0, 0)
  TL.TextStrokeTransparency = 0
  TL.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
  TL.Text = "..."
  TL.ZIndex = 15

  task.spawn(function()
    while task.wait(0.5) and uiExists do
      pcall(function()
        if not Part or not Part.Parent then
          Folder:Destroy()
          return
        end
        local plrPP = Player.Character and (Player.Character:FindFirstChild("HumanoidRootPart") or Player.Character.PrimaryPart)
        if plrPP and Part then
          local distance = math.floor((plrPP.Position - Part.Position).Magnitude)
          local fruitName = Part.Parent and Part.Parent.Name or "Unknown"
          TL.Text = "🍎 " .. fruitName .. " [" .. tostring(distance) .. " studs]"
        end
      end)
    end
  end)
end

local function RemoveESP(Part)
  if Part and Part:FindFirstChild("ESP_FruitSniper") then
    Part.ESP_FruitSniper:Destroy()
  end
end

task.spawn(function()
  while uiExists do
    task.wait(1)
    if getgenv().AutoFruitSniper and getgenv().FruitESP then
      for _, obj in pairs(workspace:GetChildren()) do
        pcall(function()
          if obj and obj:IsA("Tool") and obj:FindFirstChild("Handle") then
            AddESP(obj.Handle, Color3.fromRGB(255, 50, 50))
          elseif obj and string.find(obj.Name, "Fruit") and obj:FindFirstChild("Handle") then
            AddESP(obj.Handle, Color3.fromRGB(255, 50, 50))
          end
        end)
      end
    else
      for _, obj in pairs(workspace:GetChildren()) do
        pcall(function()
          if obj and obj:IsA("Tool") and obj:FindFirstChild("Handle") then
            RemoveESP(obj.Handle)
          elseif obj and string.find(obj.Name, "Fruit") and obj:FindFirstChild("Handle") then
            RemoveESP(obj.Handle)
          end
        end)
      end
    end
  end
end)

-- ═══════════════════════════════════════════════════════════════
-- CHECK IF FRUIT IS IN INVENTORY
-- ═══════════════════════════════════════════════════════════════
function FindFruitInInventory()
  local plrChar = Player and Player.Character
  local plrBag  = Player and Player.Backpack

  if plrChar then
    for _, tool in pairs(plrChar:GetChildren()) do
      if tool:IsA("Tool") and (tool:FindFirstChild("Fruit") or tool:FindFirstChild("EatRemote") or Get_Fruit(tool.Name) or string.find(tool.Name, "Fruit")) then
        return tool
      end
    end
  end
  if plrBag then
    for _, tool in pairs(plrBag:GetChildren()) do
      if tool:IsA("Tool") and (tool:FindFirstChild("Fruit") or tool:FindFirstChild("EatRemote") or Get_Fruit(tool.Name) or string.find(tool.Name, "Fruit")) then
        return tool
      end
    end
  end

  return nil
end

-- ═══════════════════════════════════════════════════════════════
-- STORE FRUIT WITH RETRIES
-- ═══════════════════════════════════════════════════════════════
function StoreFruitWithRetry(fruitTool)
  local maxRetries = getgenv().StoreRetries or 3
  local fruitId = Get_Fruit(fruitTool.Name)

  if not fruitId then
    Notify("❌ Unknown fruit: " .. fruitTool.Name, "error")
    return false
  end

  Notify("📦 Storing: " .. fruitTool.Name .. " (" .. fruitId .. ")", "action", true)

  for attempt = 1, maxRetries do
    if not getgenv().AutoFruitSniper or not uiExists then return false end
    Notify("📦 Store attempt " .. attempt .. "/" .. maxRetries .. "...", "warn", true)

    local success, result = pcall(function()
      return CommF:InvokeServer("StoreFruit", fruitId, fruitTool)
    end)

    if success and result == true then
      Notify("✅ STORED " .. fruitTool.Name .. " on attempt " .. attempt .. "!", "success", true)
      return true
    else
      Notify("❌ Attempt " .. attempt .. " failed: " .. tostring(result), "error")
      task.wait(1)
    end
  end

  Notify("⚠️ All " .. maxRetries .. " store attempts FAILED", "error", true)
  return false
end

-- ═══════════════════════════════════════════════════════════════
-- SEA DETECTION
-- ═══════════════════════════════════════════════════════════════
local CurrentPlaceId = game.PlaceId
local CurrentSea = "Unknown"

local OLD_SEA_IDS = {
  [2753915549] = "Sea 1",
  [4442272183] = "Sea 2",
  [7449423635] = "Sea 3"
}

if OLD_SEA_IDS[CurrentPlaceId] then
  CurrentSea = OLD_SEA_IDS[CurrentPlaceId]
else
  pcall(function()
    local Locations = workspace:FindFirstChild("_WorldOrigin") and workspace._WorldOrigin:FindFirstChild("Locations")
    if Locations then
      if Locations:FindFirstChild("Hydra Island") or Locations:FindFirstChild("Floating Turtle") or Locations:FindFirstChild("Castle on the Sea") then
        CurrentSea = "Sea 3"
      elseif Locations:FindFirstChild("Kingdom of Rose") or Locations:FindFirstChild("Green Zone") or Locations:FindFirstChild("Graveyard") then
        CurrentSea = "Sea 2"
      else
        CurrentSea = "Sea 1"
      end
    end
  end)
  if CurrentSea == "Unknown" then
    CurrentSea = "Sea (ID: " .. CurrentPlaceId .. ")"
  end
end

print("[FruitSniper] 🌊 Detected: " .. CurrentSea .. " (PlaceId: " .. CurrentPlaceId .. ")")

-- ═══════════════════════════════════════════════════════════════
-- HIGH PLAYER SERVER HOP (CHỌN SERVER NHIỀU NGƯỜI NHẤT MÀ KHÔNG FULL)
-- ═══════════════════════════════════════════════════════════════
function ServerHop()
  while getgenv().AutoFruitSniper and uiExists do
    Notify("🔄 Searching for high-player servers (sort=Desc)...", "hop", true)

    pcall(function()
      local queueteleport = (syn and syn.queue_on_teleport)
        or queue_on_teleport
        or (fluxus and fluxus.queue_on_teleport)
      if queueteleport then
        queueteleport('getgenv().AutoFruitSniper = true; getgenv().FruitESP = true; getgenv().TweenSpeed = 300; getgenv().StoreRetries = 3; getgenv().HopDelay = 3; getgenv().ScanInterval = 0.5; getgenv().AntiAFK = true; getgenv().AutoSelectTeam = true; getgenv().Team = "' .. tostring(getgenv().Team or "Marines") .. '"; loadstring(game:HttpGet("https://raw.githubusercontent.com/GujjetiMokshithcode/BloxFruitAutoFruitSniper/refs/heads/main/BloxFruit_AutoFruit.lua"))()')
        Notify("📋 Script queued for next server", "info")
      end
    end)

    -- Use sortOrder=Desc & excludeFullGames=true to fetch populated servers first
    local apiUrl = "https://games.roblox.com/v1/games/" .. CurrentPlaceId .. "/servers/Public?sortOrder=Desc&excludeFullGames=true&limit=100"

    local function ListServers(cursor)
      local success, raw = pcall(function()
        return game:HttpGet(apiUrl .. ((cursor and "&cursor=" .. cursor) or ""))
      end)
      if success and raw then
        return HttpService:JSONDecode(raw)
      end
      return nil
    end

    local Server = nil
    local Next = nil
    local pageAttempts = 0
    local maxPages = 5

    pcall(function()
      repeat
        if not getgenv().AutoFruitSniper or not uiExists then return end
        local Servers = ListServers(Next)
        pageAttempts = pageAttempts + 1

        if Servers and Servers.data then
          local candidates = {}
          for _, server in pairs(Servers.data) do
            local playing = tonumber(server.playing)
            local maxPlayers = tonumber(server.maxPlayers)
            if server.id ~= game.JobId and playing and maxPlayers 
               and playing < maxPlayers 
               and playing >= 1 then
              table.insert(candidates, server)
            end
          end

          if #candidates > 0 then
            table.sort(candidates, function(a, b)
              return a.playing > b.playing
            end)
            Server = candidates[1]
            break
          end

          Next = Servers.nextPageCursor
        else
          break
        end
        task.wait(0.25)
      until Server or not Next or pageAttempts >= maxPages
    end)

    if not Server then
      Notify("⚠️ Descending search empty. Retrying fallback search...", "warn")
      local ascApiUrl = "https://games.roblox.com/v1/games/" .. CurrentPlaceId .. "/servers/Public?sortOrder=Asc&limit=100"
      pageAttempts = 0
      pcall(function()
        repeat
          if not getgenv().AutoFruitSniper or not uiExists then return end
          local raw = game:HttpGet(ascApiUrl .. ((Next and "&cursor=" .. Next) or ""))
          local Servers = HttpService:JSONDecode(raw)
          pageAttempts = pageAttempts + 1
          if Servers and Servers.data then
            local candidates = {}
            for _, server in pairs(Servers.data) do
              if server.id ~= game.JobId and server.playing and server.maxPlayers 
                 and server.playing < server.maxPlayers then
                table.insert(candidates, server)
              end
            end
            if #candidates > 0 then
              table.sort(candidates, function(a, b) return a.playing > b.playing end)
              Server = candidates[1]
              break
            end
            Next = Servers.nextPageCursor
          end
          task.wait(0.25)
        until Server or not Next or pageAttempts >= maxPages
      end)
    end

    if not getgenv().AutoFruitSniper or not uiExists then return end

    if Server then
      Notify("🌐 Found server: " .. Server.playing .. "/" .. Server.maxPlayers .. " players", "success")
      Notify("✈️ Teleporting via __ServerBrowser...", "success", true)

      local teleportSuccess, teleportErr = pcall(function()
        return game:GetService("ReplicatedStorage"):WaitForChild("__ServerBrowser"):InvokeServer("teleport", Server.id)
      end)

      if not teleportSuccess then
        Notify("⚠️ Native hop failed: " .. tostring(teleportErr), "error", true)
        Notify("🔄 Using fallback Teleport...", "warn")
        task.wait(2)
        pcall(function()
          TeleportService:TeleportToPlaceInstance(CurrentPlaceId, Server.id, Player)
        end)
        task.wait(8)
      else
        task.wait(8)
        Notify("⚠️ Still here? Retrying hop...", "warn", true)
      end
    else
      Notify("⚠️ Failed to find valid server. Retrying fallback random Teleport...", "warn", true)
      pcall(function()
        TeleportService:Teleport(CurrentPlaceId, Player)
      end)
      task.wait(8)
    end

    task.wait(2)
  end
end

-- ═══════════════════════════════════════════════════════════════
-- ANTI-AFK
-- ═══════════════════════════════════════════════════════════════
task.spawn(function()
  while uiExists do
    task.wait(60)
    if getgenv().AutoFruitSniper and getgenv().AntiAFK then
      pcall(function()
        VirtualUser:CaptureController()
        VirtualUser:ClickButton2(Vector2.new())
      end)
    end
  end
end)

-- ═══════════════════════════════════════════════════════════════
-- CHARACTER RESPAWN HANDLER
-- ═══════════════════════════════════════════════════════════════
local function WaitForCharacter()
  local char = Player.Character or Player.CharacterAdded:Wait()
  while not (char and char:FindFirstChild("HumanoidRootPart") and char:FindFirstChild("Humanoid")) do
    if not getgenv().AutoFruitSniper or not uiExists then return nil end
    task.wait(0.2)
    char = Player.Character or Player.CharacterAdded:Wait()
  end
  task.wait(1) -- Safety rest delay
  if not getgenv().AutoFruitSniper or not uiExists then return nil end
  
  local hrp = char:FindFirstChild("HumanoidRootPart")
  if hrp then
    block.CFrame = hrp.CFrame
  end
  return char
end

-- ═══════════════════════════════════════════════════════════════
-- MAIN EXECUTION CONTROL FUNCTIONS
-- ═══════════════════════════════════════════════════════════════
local function runMainLoop()
  while getgenv().AutoFruitSniper and uiExists do
    Notify("⏳ Waiting for character...", "info", true)
    local char = WaitForCharacter()
    if not char then return end
    Notify("✅ Character loaded!", "success")

    -- Check if player is already holding a fruit and store it first
    local inventoryFruit = FindFruitInInventory()
    if inventoryFruit then
      Notify("📦 Already holding a fruit: " .. inventoryFruit.Name .. "! Storing first...", "action", true)
      local stored = StoreFruitWithRetry(inventoryFruit)
      if stored then
        Notify("✅ Stored pre-existing fruit successfully!", "success")
      else
        Notify("⚠️ Could not store pre-existing fruit (possibly storage full). Hopping...", "warn", true)
        task.wait(1)
        ServerHop()
        break
      end
    end

    Notify("🔍 Scanning for fruits...", "action", true)
    local fruit = FruitFind()

    if not getgenv().AutoFruitSniper or not uiExists then return end

    if fruit then
      local fruitHandle = fruit:FindFirstChild("Handle")
      if not fruitHandle then
        Notify("❌ Fruit has no handle!", "error")
        task.wait(1)
        continue
      end

      Notify("🍎 FRUIT FOUND: " .. fruit.Name, "fruit", true)
      Notify("📍 Location: " .. tostring(fruitHandle.Position), "fruit")
      task.wait(0.5)

      local grabSuccess = false
      local maxGrabAttempts = 3
      
      for attempt = 1, maxGrabAttempts do
        if not getgenv().AutoFruitSniper or not uiExists then return end
        if not fruit.Parent or fruit.Parent ~= workspace then
          break
        end
        
        Notify("✈️ Flying to " .. fruit.Name .. " (Attempt " .. attempt .. "/" .. maxGrabAttempts .. ")...", "action", true)
        IsFarming = true
        
        local aboveFruit = CFrame.new(fruitHandle.Position + Vector3.new(0, 5, 0))
        TweenToPosition(aboveFruit, fruit)
        
        if not getgenv().AutoFruitSniper or not uiExists then return end
        if not fruit.Parent or fruit.Parent ~= workspace then
          break
        end
        
        task.wait(0.2)
        Notify("📍 Approaching fruit...", "action")
        TweenToPosition(fruitHandle.CFrame, fruit)
        
        if not getgenv().AutoFruitSniper or not uiExists then return end
        if not fruit.Parent or fruit.Parent ~= workspace then
          break
        end
        
        task.wait(0.5)
        Notify("🤚 Grabbing " .. fruit.Name .. "...", "action", true)

        local plrPP = Player.Character and (Player.Character:FindFirstChild("HumanoidRootPart") or Player.Character.PrimaryPart)
        if plrPP and fruitHandle then
          for i = 1, 10 do
            if not getgenv().AutoFruitSniper or not uiExists then return end
            if not fruit.Parent or fruit.Parent ~= workspace then
              break
            end
            plrPP.CFrame = fruitHandle.CFrame
            block.CFrame = fruitHandle.CFrame
            task.wait(0.2)
          end
        end

        task.wait(1)
        local inventoryFruit = FindFruitInInventory()
        if inventoryFruit then
          grabSuccess = true
          Notify("📦 Fruit in inventory! Storing...", "action", true)
          local stored = StoreFruitWithRetry(inventoryFruit)
          if stored then
            Notify("✅ Fruit stored successfully!", "success", true)
          else
            Notify("⚠️ Store failed (possibly storage full).", "warn", true)
          end
          break
        end
        
        Notify("⚠️ Attempt " .. attempt .. " failed to grab fruit. Retrying...", "warn")
        IsFarming = false
        task.wait(1)
      end

      if not getgenv().AutoFruitSniper or not uiExists then return end
      
      -- If the fruit is still in workspace and grab failed after all attempts, hop server
      if not grabSuccess and fruit.Parent == workspace then
        Notify("⚠️ All grab attempts failed. Hopping...", "warn", true)
      end

      IsFarming = false

      if not getgenv().AutoFruitSniper or not uiExists then return end
      Notify("⏳ Hopping in " .. getgenv().HopDelay .. "s...", "hop", true)
      
      local elapsed = 0
      while elapsed < getgenv().HopDelay do
        if not getgenv().AutoFruitSniper or not uiExists then return end
        task.wait(0.5)
        elapsed = elapsed + 0.5
      end
      
      if not getgenv().AutoFruitSniper or not uiExists then return end
      ServerHop()
      break
    else
      Notify("❌ No fruit found in this server", "error", true)
      Notify("⏳ Hopping in " .. getgenv().HopDelay .. "s...", "hop")
      
      local elapsed = 0
      while elapsed < getgenv().HopDelay do
        if not getgenv().AutoFruitSniper or not uiExists then return end
        task.wait(0.5)
        elapsed = elapsed + 0.5
      end
      
      if not getgenv().AutoFruitSniper or not uiExists then return end
      ServerHop()
      break
    end
  end
end

-- Cleanup on Character removal
Player.CharacterRemoving:Connect(function()
  IsFarming = false
end)

-- ═══════════════════════════════════════════════════════════════
-- SCRIPT INITIALIZATION
-- ═══════════════════════════════════════════════════════════════
Notify("✅ Script Initialized!", "success", true)
task.wait(0.5)

Notify("🌊 Sea: " .. CurrentSea, "info")
Notify("🆔 PlaceId: " .. tostring(CurrentPlaceId), "info")
Notify("⚡ Speed: " .. tostring(getgenv().TweenSpeed) .. " studs/sec", "info")
Notify("🔄 Store Retries: " .. tostring(getgenv().StoreRetries), "info")
Notify("👁️ ESP: " .. (getgenv().FruitESP and "ON" or "OFF"), "info")
Notify("──────────────────────────────", "info")
task.wait(0.5)

-- Execute auto team wait & selection
WaitAndSelectTeam()
task.wait(3)

-- Execute main loop
task.spawn(runMainLoop)

Notify("🚀 Auto Fruit Sniper is RUNNING!", "success")
