--[[
  ╔══════════════════════════════════════════════════════════════╗
  ║           BLOX FRUIT - AUTO FRUIT SNIPER SCRIPT              ║
  ║       Scan → Fly → Grab → Store (3 retries) → Hop            ║
  ║              Built for LEARNING purposes only                ║
  ║                + AUTO TEAM SELECTION (REMOTE)                ║
  ║                + DISCORD WEBHOOK NOTIFICATIONS               ║
  ╚══════════════════════════════════════════════════════════════╝
  
  Based on patterns from REDZ HUB V2
  Features:
    • Scans workspace for devil fruits every tick
    • Tweens (flies) to the nearest fruit
    • Picks it up and tries to store it (3 attempts)
    • If store fails after 3 tries → server hops anyway
    • If store succeeds → server hops to find more
    • Anti-AFK to prevent kicks
    • No-clip so walls don't block the flight path
    • Fruit ESP to visualize fruits on the map
    • Auto team selection using remote "SetTeam" (fallback to click)
    • Discord webhook notifications on successful fruit storage
]]

-- ═══════════════════════════════════════════════════════════════
-- CONFIGURATION (can be set externally via getgenv() before loadstring)
-- ═══════════════════════════════════════════════════════════════
-- All settings default to these values if not set externally.
-- To customize, set them BEFORE executing loadstring, e.g.:
--   getgenv().Team = 1  -- Pirates
--   getgenv().DiscordWebhook = "https://discord.com/api/webhooks/..."
--   loadstring(game:HttpGet("..."))()

getgenv().AutoFruitSniper   = getgenv().AutoFruitSniper ~= nil and getgenv().AutoFruitSniper or true
getgenv().FruitESP          = getgenv().FruitESP ~= nil and getgenv().FruitESP or true
getgenv().TweenSpeed        = getgenv().TweenSpeed or 300
getgenv().StoreRetries      = getgenv().StoreRetries or 3
getgenv().HopDelay          = getgenv().HopDelay or 3
getgenv().ScanInterval      = getgenv().ScanInterval or 0.5
getgenv().AntiAFK           = getgenv().AntiAFK ~= nil and getgenv().AntiAFK or true
getgenv().AutoSelectTeam    = getgenv().AutoSelectTeam ~= nil and getgenv().AutoSelectTeam or true
getgenv().Team              = getgenv().Team or 0        -- 0 = Marines, 1 = Pirates
getgenv().TeamSelectDelay   = getgenv().TeamSelectDelay or 12
-- Discord webhook URL (set to nil or empty string to disable)
getgenv().DiscordWebhook    = getgenv().DiscordWebhook or ""

-- ═══════════════════════════════════════════════════════════════
-- WAIT FOR GAME TO FULLY LOAD
-- ═══════════════════════════════════════════════════════════════
repeat task.wait() until game:IsLoaded()

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
-- CORE REFERENCES (same pattern as REDZ HUB V2)
-- ═══════════════════════════════════════════════════════════════
local Remotes = ReplicatedStorage:WaitForChild("Remotes", 9e9)
local CommF   = Remotes:WaitForChild("CommF_", 9e9)

local Player = Players.LocalPlayer

-- ═══════════════════════════════════════════════════════════════
-- DISCORD WEBHOOK SENDER
-- ═══════════════════════════════════════════════════════════════
local function SendDiscordWebhook(fruitName, serverInfo)
    local webhookUrl = getgenv().DiscordWebhook
    if not webhookUrl or webhookUrl == "" then return end

    local playerName = Player.Name
    local placeId = game.PlaceId
    local jobId = game.JobId
    local serverText = serverInfo or ("Place ID: " .. placeId .. ", Job ID: " .. jobId)

    local embed = {
        ["title"] = "🍎 Fruit Sniper - Fruit Stored!",
        ["description"] = "**" .. playerName .. "** has successfully stored a **" .. fruitName .. "**!",
        ["color"] = 0x00ff00,
        ["fields"] = {
            {
                ["name"] = "Fruit",
                ["value"] = fruitName,
                ["inline"] = true
            },
            {
                ["name"] = "Player",
                ["value"] = playerName,
                ["inline"] = true
            },
            {
                ["name"] = "Server",
                ["value"] = serverText,
                ["inline"] = false
            }
        },
        ["footer"] = {
            ["text"] = "Auto Fruit Sniper • " .. os.date("%Y-%m-%d %H:%M:%S")
        }
    }

    local payload = {
        ["embeds"] = {embed}
    }

    pcall(function()
        local response = game:HttpGet(webhookUrl, true, "POST", {
            ["Content-Type"] = "application/json"
        }, HttpService:JSONEncode(payload))
        print("[FruitSniper] Webhook sent.")
    end)
end

-- ═══════════════════════════════════════════════════════════════
-- IN-GAME GUI NOTIFICATION SYSTEM (unchanged)
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
  local children = LogFrame:GetChildren()
  local labels = {}
  for _, child in pairs(children) do
    if child:IsA("TextLabel") then
      table.insert(labels, child)
    end
  end
  if #labels > 50 then
    table.sort(labels, function(a, b) return a.LayoutOrder < b.LayoutOrder end)
    labels[1]:Destroy()
  end
end

-- Intro animation
MainFrame.BackgroundTransparency = 1
TitleBar.BackgroundTransparency = 1
TitleFix.BackgroundTransparency = 1
TitleLabel.TextTransparency = 1
StatusLabel.TextTransparency = 1
LogFrame.BackgroundTransparency = 1

task.spawn(function()
  local fadeIn = TweenService:Create(MainFrame, TweenInfo.new(0.5, Enum.EasingStyle.Quad), {BackgroundTransparency = 0.15})
  local fadeTitle = TweenService:Create(TitleBar, TweenInfo.new(0.5, Enum.EasingStyle.Quad), {BackgroundTransparency = 0.4})
  local fadeTitleFix = TweenService:Create(TitleFix, TweenInfo.new(0.5, Enum.EasingStyle.Quad), {BackgroundTransparency = 0.4})
  local fadeTitleText = TweenService:Create(TitleLabel, TweenInfo.new(0.5, Enum.EasingStyle.Quad), {TextTransparency = 0})
  local fadeStatus = TweenService:Create(StatusLabel, TweenInfo.new(0.5, Enum.EasingStyle.Quad), {TextTransparency = 0})
  local fadeLog = TweenService:Create(LogFrame, TweenInfo.new(0.5, Enum.EasingStyle.Quad), {BackgroundTransparency = 0.3})
  fadeIn:Play() fadeTitle:Play() fadeTitleFix:Play() fadeTitleText:Play() fadeStatus:Play() fadeLog:Play()
end)

-- ═══════════════════════════════════════════════════════════════
-- AUTO TEAM SELECTION FUNCTION (dùng remote "SetTeam")
-- ═══════════════════════════════════════════════════════════════
local function AutoSelectTeam()
  if not getgenv().AutoSelectTeam then
    Notify("⏩ Auto team selection is disabled.", "info")
    return
  end

  local teamValue = getgenv().Team  -- 0 = Marines, 1 = Pirates
  local teamName = (teamValue == 0) and "Marines" or "Pirates"

  Notify("⏳ Waiting " .. tostring(getgenv().TeamSelectDelay) .. "s before selecting " .. teamName .. "...", "warn", true)
  task.wait(getgenv().TeamSelectDelay)

  -- 🔥 Cố gắng chọn team bằng remote "SetTeam"
  local success, result = pcall(function()
    CommF:InvokeServer("SetTeam", teamName)
  end)

  if success then
    Notify("✅ Team selection (" .. teamName .. ") executed via remote!", "success", true)
    return
  else
    Notify("❌ Remote call failed: " .. tostring(result), "error", true)
    Notify("🔄 Attempting fallback: click GUI...", "warn", true)
  end

  -- Fallback: click vào nút GUI (nếu remote không thành công)
  pcall(function()
    local playerGui = Player:WaitForChild("PlayerGui", 5)
    local mainGui = playerGui:WaitForChild("Main", 3)
    local chooseTeam = mainGui:WaitForChild("ChooseTeam", 3)
    local container = chooseTeam:WaitForChild("Container", 2)
    local buttonPath = (teamValue == 0) and "Marines" or "Pirates"
    local button = container:WaitForChild(buttonPath, 2):WaitForChild("Frame", 1):WaitForChild("ViewportFrame", 1):WaitForChild("TextButton", 1)
    if button then
      for _, conn in pairs(getconnections(button.MouseButton1Click)) do
        conn.Function()
      end
      Notify("✅ Team selection (" .. teamName .. ") executed via click fallback!", "success", true)
    else
      Notify("⚠️ Fallback click failed. Team may already be chosen.", "warn")
    end
  end)
end

-- ═══════════════════════════════════════════════════════════════
-- FRUIT NAME → STORE ID MAPPING (unchanged)
-- ═══════════════════════════════════════════════════════════════
local function Get_Fruit(Fruit)
  if Fruit == "Rocket Fruit" then
    return "Rocket-Rocket"
  elseif Fruit == "Spin Fruit" then
    return "Spin-Spin"
  elseif Fruit == "Chop Fruit" then
    return "Chop-Chop"
  elseif Fruit == "Spring Fruit" then
    return "Spring-Spring"
  elseif Fruit == "Bomb Fruit" then
    return "Bomb-Bomb"
  elseif Fruit == "Smoke Fruit" then
    return "Smoke-Smoke"
  elseif Fruit == "Spike Fruit" then
    return "Spike-Spike"
  elseif Fruit == "Flame Fruit" then
    return "Flame-Flame"
  elseif Fruit == "Falcon Fruit" then
    return "Falcon-Falcon"
  elseif Fruit == "Ice Fruit" then
    return "Ice-Ice"
  elseif Fruit == "Sand Fruit" then
    return "Sand-Sand"
  elseif Fruit == "Dark Fruit" then
    return "Dark-Dark"
  elseif Fruit == "Ghost Fruit" then
    return "Ghost-Ghost"
  elseif Fruit == "Diamond Fruit" then
    return "Diamond-Diamond"
  elseif Fruit == "Light Fruit" then
    return "Light-Light"
  elseif Fruit == "Rubber Fruit" then
    return "Rubber-Rubber"
  elseif Fruit == "Barrier Fruit" then
    return "Barrier-Barrier"
  elseif Fruit == "Magma Fruit" then
    return "Magma-Magma"
  elseif Fruit == "Quake Fruit" then
    return "Quake-Quake"
  elseif Fruit == "Buddha Fruit" then
    return "Buddha-Buddha"
  elseif Fruit == "Love Fruit" then
    return "Love-Love"
  elseif Fruit == "Spider Fruit" then
    return "Spider-Spider"
  elseif Fruit == "Sound Fruit" then
    return "Sound-Sound"
  elseif Fruit == "Phoenix Fruit" then
    return "Phoenix-Phoenix"
  elseif Fruit == "Portal Fruit" then
    return "Portal-Portal"
  elseif Fruit == "Rumble Fruit" then
    return "Rumble-Rumble"
  elseif Fruit == "Pain Fruit" then
    return "Pain-Pain"
  elseif Fruit == "Blizzard Fruit" then
    return "Blizzard-Blizzard"
  elseif Fruit == "Gravity Fruit" then
    return "Gravity-Gravity"
  elseif Fruit == "Mammoth Fruit" then
    return "Mammoth-Mammoth"
  elseif Fruit == "T-Rex Fruit" then
    return "T-Rex-T-Rex"
  elseif Fruit == "Dough Fruit" then
    return "Dough-Dough"
  elseif Fruit == "Shadow Fruit" then
    return "Shadow-Shadow"
  elseif Fruit == "Venom Fruit" then
    return "Venom-Venom"
  elseif Fruit == "Control Fruit" then
    return "Control-Control"
  elseif Fruit == "Spirit Fruit" then
    return "Spirit-Spirit"
  elseif Fruit == "Dragon Fruit" then
    return "Dragon-Dragon"
  elseif Fruit == "Leopard Fruit" then
    return "Leopard-Leopard"
  elseif Fruit == "Kitsune Fruit" then
    return "Kitsune-Kitsune"
  end
end

-- ═══════════════════════════════════════════════════════════════
-- UTILITY: Fire Remote (unchanged)
-- ═══════════════════════════════════════════════════════════════
local function FireRemote(...)
  return CommF:InvokeServer(...)
end

-- ═══════════════════════════════════════════════════════════════
-- INVISIBLE PLATFORM (unchanged)
-- ═══════════════════════════════════════════════════════════════
local block = Instance.new("Part", workspace)
block.Size         = Vector3.new(1, 1, 1)
block.Name         = "FruitSniper_Platform"
block.Anchored     = true
block.CanCollide   = false
block.CanTouch     = false
block.Transparency = 1

local existingBlock = workspace:FindFirstChild(block.Name)
if existingBlock and existingBlock ~= block then
  existingBlock:Destroy()
end

-- ═══════════════════════════════════════════════════════════════
-- NO-CLIP + POSITION SYNC (unchanged)
-- ═══════════════════════════════════════════════════════════════
local IsFarming = false

task.spawn(function()
  repeat task.wait()
  until Player.Character and Player.Character.PrimaryPart
  block.CFrame = Player.Character.PrimaryPart.CFrame

  while task.wait() do
    pcall(function()
      if IsFarming then
        if block and block.Parent == workspace then
          local plrPP = Player.Character and Player.Character.PrimaryPart
          if plrPP and (plrPP.Position - block.Position).Magnitude <= 200 then
            plrPP.CFrame = block.CFrame
          else
            block.CFrame = plrPP.CFrame
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
-- TWEEN / FLY TO POSITION (unchanged)
-- ═══════════════════════════════════════════════════════════════
local function TweenToPosition(targetCFrame)
  local plrPP = Player.Character and Player.Character.PrimaryPart
  if not plrPP then return end
  local distance = (plrPP.Position - targetCFrame.p).Magnitude
  local speed = getgenv().TweenSpeed or 300
  local tweenTime = distance / speed
  if tweenTime < 0.1 then tweenTime = 0.1 end
  local tween = TweenService:Create(
    block,
    TweenInfo.new(tweenTime, Enum.EasingStyle.Linear),
    {CFrame = targetCFrame}
  )
  tween:Play()
  tween.Completed:Wait()
end

-- ═══════════════════════════════════════════════════════════════
-- FRUIT FINDER (unchanged)
-- ═══════════════════════════════════════════════════════════════
local function FruitFind()
  local fruits = workspace:GetChildren()
  local FruitDistance = math.huge
  local FoundFruit = nil

  for _, fruit in pairs(fruits) do
    local plrPP = Player and Player.Character and Player.Character.PrimaryPart
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
-- FRUIT ESP (unchanged)
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
    while task.wait(0.5) do
      pcall(function()
        if not Part or not Part.Parent then
          Folder:Destroy()
          return
        end
        local plrPP = Player.Character and Player.Character:FindFirstChild("HumanoidRootPart")
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
  while getgenv().AutoFruitSniper do task.wait(1)
    if getgenv().FruitESP then
      for _, obj in pairs(workspace:GetChildren()) do
        pcall(function()
          if obj and obj:IsA("Tool") and obj:FindFirstChild("Handle") then
            AddESP(obj.Handle, Color3.fromRGB(255, 50, 50))
          elseif obj and string.find(obj.Name, "Fruit") and obj:FindFirstChild("Handle") then
            AddESP(obj.Handle, Color3.fromRGB(255, 50, 50))
          end
        end)
      end
    end
  end
end)

-- ═══════════════════════════════════════════════════════════════
-- CHECK IF FRUIT IS IN INVENTORY (unchanged)
-- ═══════════════════════════════════════════════════════════════
local function FindFruitInInventory()
  local plrChar = Player and Player.Character
  local plrBag  = Player and Player.Backpack

  if plrChar then
    for _, tool in pairs(plrChar:GetChildren()) do
      if tool:IsA("Tool") and tool:FindFirstChild("Fruit") then
        return tool
      end
    end
  end
  if plrBag then
    for _, tool in pairs(plrBag:GetChildren()) do
      if tool:IsA("Tool") and tool:FindFirstChild("Fruit") then
        return tool
      end
    end
  end

  return nil
end

-- ═══════════════════════════════════════════════════════════════
-- STORE FRUIT WITH 3 RETRIES (modified to send webhook on success)
-- ═══════════════════════════════════════════════════════════════
local function StoreFruitWithRetry(fruitTool)
  local maxRetries = getgenv().StoreRetries or 3
  local fruitId = Get_Fruit(fruitTool.Name)

  if not fruitId then
    Notify("❌ Unknown fruit: " .. fruitTool.Name, "error")
    return false
  end

  Notify("📦 Storing: " .. fruitTool.Name .. " (" .. fruitId .. ")", "action", true)

  for attempt = 1, maxRetries do
    Notify("📦 Store attempt " .. attempt .. "/" .. maxRetries .. "...", "warn", true)

    local success, result = pcall(function()
      return CommF:InvokeServer("StoreFruit", fruitId, fruitTool)
    end)

    if success and result == true then
      Notify("✅ STORED " .. fruitTool.Name .. " on attempt " .. attempt .. "!", "success", true)
      -- Send Discord webhook notification
      local serverInfo = "Place ID: " .. game.PlaceId .. ", Job ID: " .. game.JobId
      SendDiscordWebhook(fruitTool.Name, serverInfo)
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
-- SEA DETECTION (unchanged)
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
-- SERVER HOP (unchanged)
-- ═══════════════════════════════════════════════════════════════
local function ServerHop()
  Notify("🔄 Starting server hop loop...", "hop", true)

  pcall(function()
    local queueteleport = (syn and syn.queue_on_teleport)
      or queue_on_teleport
      or (fluxus and fluxus.queue_on_teleport)
    if queueteleport then
      queueteleport('loadstring(readfile("BloxFruit_AutoFruit.lua"))()')
      Notify("📋 Script queued for next server", "info")
    end
  end)

  while true do
    Notify("🔍 Searching " .. CurrentSea .. " servers...", "hop")

    local apiUrl = "https://games.roblox.com/v1/games/" .. CurrentPlaceId .. "/servers/Public?sortOrder=Desc&excludeFullGames=true&limit=100"

    local function ListServers(cursor)
      local raw = game:HttpGet(apiUrl .. ((cursor and "&cursor=" .. cursor) or ""))
      return HttpService:JSONDecode(raw)
    end

    local Server, Next
    local pageAttempts = 0
    local maxPages = 5

    local apiSuccess = pcall(function()
      repeat task.wait(0.5)
        pageAttempts = pageAttempts + 1
        local Servers = ListServers(Next)

        if Servers and Servers.data then
          for _, server in pairs(Servers.data) do
            if server.id ~= game.JobId and server.playing and server.maxPlayers
               and server.playing < (server.maxPlayers - 1) then
              Server = server
              break
            end
          end
          Next = Servers.nextPageCursor
        end
      until Server or not Next or pageAttempts >= maxPages
    end)

    if Server then
      Notify("🌐 Found server: " .. Server.playing .. "/" .. Server.maxPlayers, "success")
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
        task.wait(5)
      else
        task.wait(15)
        Notify("⚠️ Still here? Retrying hop...", "warn", true)
      end
    else
      Notify("⚠️ API failed to find valid server.", "error", true)
      Notify("🔄 Using random Teleport fallback...", "warn")

      pcall(function()
        TeleportService:Teleport(CurrentPlaceId, Player)
      end)

      task.wait(15)
      Notify("🔄 Restarting hop process...", "warn", true)
    end
  end
end

-- ═══════════════════════════════════════════════════════════════
-- ANTI-AFK (unchanged)
-- ═══════════════════════════════════════════════════════════════
task.spawn(function()
  while getgenv().AntiAFK do task.wait(60)
    pcall(function()
      VirtualUser:CaptureController()
      VirtualUser:ClickButton2(Vector2.new())
    end)
  end
end)

-- ═══════════════════════════════════════════════════════════════
-- CHARACTER RESPAWN HANDLER (unchanged)
-- ═══════════════════════════════════════════════════════════════
local function WaitForCharacter()
  local char = Player.Character or Player.CharacterAdded:Wait()
  repeat task.wait()
  until char and char:FindFirstChild("HumanoidRootPart") and char:FindFirstChild("Humanoid")
  task.wait(1)
  block.CFrame = char.HumanoidRootPart.CFrame
  return char
end

-- ═══════════════════════════════════════════════════════════════
-- EXECUTE AUTO TEAM SELECTION (chạy trước main loop)
-- ═══════════════════════════════════════════════════════════════
AutoSelectTeam()

-- ═══════════════════════════════════════════════════════════════
-- ███  MAIN LOOP: SCAN → FLY → GRAB → STORE → HOP  ███
-- ═══════════════════════════════════════════════════════════════
Notify("✅ Script Successfully Executed!", "success", true)
task.wait(0.5)
Notify("🌊 Sea: " .. CurrentSea, "info")
Notify("🆔 PlaceId: " .. tostring(CurrentPlaceId), "info")
Notify("⚡ Speed: " .. tostring(getgenv().TweenSpeed) .. " studs/sec", "info")
Notify("🔄 Store Retries: " .. tostring(getgenv().StoreRetries), "info")
Notify("👁️ ESP: " .. (getgenv().FruitESP and "ON" or "OFF"), "info")
if getgenv().DiscordWebhook and getgenv().DiscordWebhook ~= "" then
  Notify("💬 Discord Webhook: Enabled", "info")
else
  Notify("💬 Discord Webhook: Disabled", "info")
end
Notify("──────────────────────────────", "info")
task.wait(1)

task.spawn(function()
  while getgenv().AutoFruitSniper do

    Notify("⏳ Waiting for character...", "info", true)
    WaitForCharacter()
    Notify("✅ Character loaded!", "success")

    Notify("🔍 Scanning for fruits...", "action", true)
    local fruit = FruitFind()

    if fruit then
      local fruitHandle = fruit:FindFirstChild("Handle")
      Notify("🍎 FRUIT FOUND: " .. fruit.Name, "fruit", true)
      Notify("📍 Location: " .. tostring(fruitHandle.Position), "fruit")
      task.wait(0.5)

      IsFarming = true
      Notify("✈️ Flying to " .. fruit.Name .. "...", "action", true)

      local aboveFruit = CFrame.new(fruitHandle.Position + Vector3.new(0, 5, 0))
      TweenToPosition(aboveFruit)
      task.wait(0.3)
      Notify("📍 Approaching fruit...", "action")
      TweenToPosition(fruitHandle.CFrame)
      task.wait(0.5)
      Notify("✅ Arrived at fruit!", "success")

      Notify("🤚 Grabbing " .. fruit.Name .. "...", "action", true)

      local plrPP = Player.Character and Player.Character.PrimaryPart
      if plrPP and fruitHandle then
        for i = 1, 10 do
          if not fruit.Parent or fruit.Parent ~= workspace then
            Notify("✅ Fruit picked up!", "success")
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
        Notify("📦 Fruit in inventory! Storing...", "action", true)
        local stored = StoreFruitWithRetry(inventoryFruit)

        if stored then
          Notify("✅ Fruit stored successfully!", "success", true)
        else
          Notify("⚠️ Store failed after 3 tries. Hopping anyway...", "warn", true)
        end
      else
        task.wait(0.5)
        local retryFruit = FindFruitInInventory()
        if retryFruit then
          Notify("📦 Found fruit on retry! Storing...", "action")
          StoreFruitWithRetry(retryFruit)
        else
          Notify("⚠️ Fruit not in inventory. Pickup may have failed.", "warn", true)
        end
      end

      IsFarming = false

      Notify("⏳ Hopping in " .. getgenv().HopDelay .. "s...", "hop", true)
      task.wait(getgenv().HopDelay)
      ServerHop()

      task.wait(9e9)

    else
      Notify("❌ No fruit found in this server", "error", true)
      Notify("⏳ Hopping in " .. getgenv().HopDelay .. "s...", "hop")
      task.wait(getgenv().HopDelay)
      ServerHop()

      task.wait(9e9)
    end
  end
end)

-- ═══════════════════════════════════════════════════════════════
-- CLEANUP ON SCRIPT STOP
-- ═══════════════════════════════════════════════════════════════
Player.CharacterRemoving:Connect(function()
  IsFarming = false
end)

Notify("🚀 Auto Fruit Sniper is RUNNING!", "success")
