--[[
  ╔══════════════════════════════════════════════════════════════╗
  ║           BLOX FRUIT - AUTO FRUIT SNIPER SCRIPT              ║
  ║       Scan → Fly → Grab → Store (3 retries) → Hop            ║
  ║              Built for LEARNING purposes only                ║
  ║                + AUTO TEAM SELECTION (REMOTE)                ║
  ║                + DISCORD WEBHOOK NOTIFICATIONS               ║
  ║                + STOP / CLOSE BUTTONS + LOW PLAYER HOP       ║
  ╚══════════════════════════════════════════════════════════════╝
]]

-- ═══════════════════════════════════════════════════════════════
-- CONFIGURATION
-- ═══════════════════════════════════════════════════════════════
getgenv().AutoFruitSniper   = getgenv().AutoFruitSniper ~= nil and getgenv().AutoFruitSniper or true
getgenv().FruitESP          = getgenv().FruitESP ~= nil and getgenv().FruitESP or true
getgenv().TweenSpeed        = getgenv().TweenSpeed or 300
getgenv().StoreRetries      = getgenv().StoreRetries or 3
getgenv().HopDelay          = getgenv().HopDelay or 3
getgenv().ScanInterval      = getgenv().ScanInterval or 0.5
getgenv().AntiAFK           = getgenv().AntiAFK ~= nil and getgenv().AntiAFK or true
getgenv().AutoSelectTeam    = getgenv().AutoSelectTeam ~= nil and getgenv().AutoSelectTeam or true
getgenv().Team              = getgenv().Team or 0        -- 0 = Marines, 1 = Pirates
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
-- CORE REFERENCES
-- ═══════════════════════════════════════════════════════════════
local Remotes = ReplicatedStorage:WaitForChild("Remotes", 9e9)
local CommF   = Remotes:WaitForChild("CommF_", 9e9)
local Player  = Players.LocalPlayer

-- Global execution states
local scriptRunning = true
local activeTween = nil
local IsFarming = false

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
        game:HttpGet(webhookUrl, true, "POST", {
            ["Content-Type"] = "application/json"
        }, HttpService:JSONEncode(payload))
        print("[FruitSniper] Webhook sent.")
    end)
end

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
MainFrame.Size = UDim2.new(0, 340, 0, 310)
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
LogFrame.Size = UDim2.new(1, -20, 0, 180)
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

-- ═══════════════════════════════════════════════════════════════
-- DOCK/BUTTON CONTAINER (TẠO CÁC NÚT DỪNG SCRIPT & ĐÓNG UI)
-- ═══════════════════════════════════════════════════════════════
local ButtonFrame = Instance.new("Frame")
ButtonFrame.Name = "ButtonFrame"
ButtonFrame.Size = UDim2.new(1, -20, 0, 36)
ButtonFrame.Position = UDim2.new(0, 10, 1, -48)
ButtonFrame.BackgroundTransparency = 1
ButtonFrame.Parent = MainFrame

local ButtonLayout = Instance.new("UIListLayout", ButtonFrame)
ButtonLayout.FillDirection = Enum.FillDirection.Horizontal
ButtonLayout.SortOrder = Enum.SortOrder.LayoutOrder
ButtonLayout.Padding = UDim.new(0, 10)

-- Stop / Start Button
local StopButton = Instance.new("TextButton")
StopButton.Name = "StopButton"
StopButton.Size = UDim2.new(0.5, -5, 1, 0)
StopButton.BackgroundColor3 = Color3.fromRGB(180, 40, 40)
StopButton.BorderSizePixel = 0
StopButton.Text = "🛑 STOP SCRIPT"
StopButton.TextColor3 = Color3.fromRGB(255, 255, 255)
StopButton.Font = Enum.Font.GothamBold
StopButton.TextSize = 12
StopButton.AutoButtonColor = false
StopButton.Parent = ButtonFrame

local StopCorner = Instance.new("UICorner", StopButton)
StopCorner.CornerRadius = UDim.new(0, 6)

local StopGradient = Instance.new("UIGradient", StopButton)
StopGradient.Color = ColorSequence.new({
  ColorSequenceKeypoint.new(0, Color3.fromRGB(200, 50, 50)),
  ColorSequenceKeypoint.new(1, Color3.fromRGB(140, 20, 20))
})

local StopStroke = Instance.new("UIStroke", StopButton)
StopStroke.Color = Color3.fromRGB(255, 100, 100)
StopStroke.Thickness = 1
StopStroke.Transparency = 0.5

-- Close UI Button
local CloseButton = Instance.new("TextButton")
CloseButton.Name = "CloseButton"
CloseButton.Size = UDim2.new(0.5, -5, 1, 0)
CloseButton.BackgroundColor3 = Color3.fromRGB(60, 60, 70)
CloseButton.BorderSizePixel = 0
CloseButton.Text = "❌ CLOSE UI"
CloseButton.TextColor3 = Color3.fromRGB(255, 255, 255)
CloseButton.Font = Enum.Font.GothamBold
CloseButton.TextSize = 12
CloseButton.AutoButtonColor = false
CloseButton.Parent = ButtonFrame

local CloseCorner = Instance.new("UICorner", CloseButton)
CloseCorner.CornerRadius = UDim.new(0, 6)

local CloseGradient = Instance.new("UIGradient", CloseButton)
CloseGradient.Color = ColorSequence.new({
  ColorSequenceKeypoint.new(0, Color3.fromRGB(80, 80, 90)),
  ColorSequenceKeypoint.new(1, Color3.fromRGB(45, 45, 55))
})

local CloseStroke = Instance.new("UIStroke", CloseButton)
CloseStroke.Color = Color3.fromRGB(120, 120, 130)
CloseStroke.Thickness = 1
CloseStroke.Transparency = 0.5

-- Color Table for log messages
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

-- Dragging code for TitleBar
local dragging, dragInput, dragStart, startPos
local function update(input)
  local delta = input.Position - dragStart
  MainFrame.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
end

TitleBar.InputBegan:Connect(function(input)
  if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
    dragging = true
    dragStart = input.Position
    startPos = MainFrame.Position
    
    input.Changed:Connect(function()
      if input.UserInputState == Enum.UserInputState.End then
        dragging = false
      end
    end)
  end
end)

TitleBar.InputChanged:Connect(function(input)
  if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
    dragInput = input
  end
end)

game:GetService("UserInputService").InputChanged:Connect(function(input)
  if input == dragInput and dragging then
    update(input)
  end
end)

-- Button Hover Effects
StopButton.MouseEnter:Connect(function()
  TweenService:Create(StopButton, TweenInfo.new(0.2), {BackgroundTransparency = 0.15}):Play()
  TweenService:Create(StopStroke, TweenInfo.new(0.2), {Transparency = 0.2}):Play()
end)
StopButton.MouseLeave:Connect(function()
  TweenService:Create(StopButton, TweenInfo.new(0.2), {BackgroundTransparency = 0}):Play()
  TweenService:Create(StopStroke, TweenInfo.new(0.2), {Transparency = 0.5}):Play()
end)

CloseButton.MouseEnter:Connect(function()
  TweenService:Create(CloseButton, TweenInfo.new(0.2), {BackgroundTransparency = 0.15}):Play()
  TweenService:Create(CloseStroke, TweenInfo.new(0.2), {Transparency = 0.2}):Play()
end)
CloseButton.MouseLeave:Connect(function()
  TweenService:Create(CloseButton, TweenInfo.new(0.2), {BackgroundTransparency = 0}):Play()
  TweenService:Create(CloseStroke, TweenInfo.new(0.2), {Transparency = 0.5}):Play()
end)

-- Intro fade-in animation
MainFrame.BackgroundTransparency = 1
TitleBar.BackgroundTransparency = 1
TitleFix.BackgroundTransparency = 1
TitleLabel.TextTransparency = 1
StatusLabel.TextTransparency = 1
LogFrame.BackgroundTransparency = 1
StopButton.BackgroundTransparency = 1
CloseButton.BackgroundTransparency = 1

task.spawn(function()
  local fadeIn = TweenService:Create(MainFrame, TweenInfo.new(0.5, Enum.EasingStyle.Quad), {BackgroundTransparency = 0.15})
  local fadeTitle = TweenService:Create(TitleBar, TweenInfo.new(0.5, Enum.EasingStyle.Quad), {BackgroundTransparency = 0.4})
  local fadeTitleFix = TweenService:Create(TitleFix, TweenInfo.new(0.5, Enum.EasingStyle.Quad), {BackgroundTransparency = 0.4})
  local fadeTitleText = TweenService:Create(TitleLabel, TweenInfo.new(0.5, Enum.EasingStyle.Quad), {TextTransparency = 0})
  local fadeStatus = TweenService:Create(StatusLabel, TweenInfo.new(0.5, Enum.EasingStyle.Quad), {TextTransparency = 0})
  local fadeLog = TweenService:Create(LogFrame, TweenInfo.new(0.5, Enum.EasingStyle.Quad), {BackgroundTransparency = 0.3})
  local fadeBtn1 = TweenService:Create(StopButton, TweenInfo.new(0.5, Enum.EasingStyle.Quad), {BackgroundTransparency = 0})
  local fadeBtn2 = TweenService:Create(CloseButton, TweenInfo.new(0.5, Enum.EasingStyle.Quad), {BackgroundTransparency = 0})
  fadeIn:Play() fadeTitle:Play() fadeTitleFix:Play() fadeTitleText:Play() fadeStatus:Play() fadeLog:Play() fadeBtn1:Play() fadeBtn2:Play()
end)

-- ═══════════════════════════════════════════════════════════════
-- AUTO TEAM SELECTION WITH LOAD WAIT (CHỜ LOAD TEAM ĐẦU SCRIPT)
-- ═══════════════════════════════════════════════════════════════
local function WaitAndSelectTeam()
  if not getgenv().AutoSelectTeam then
    Notify("⏩ Auto team selection is disabled.", "info")
    return
  end

  Notify("⏳ Waiting for game resources...", "info", true)
  local success, remotes = pcall(function()
    return ReplicatedStorage:WaitForChild("Remotes", 30)
  end)
  if not success or not remotes then
    Notify("❌ Remotes folder not found.", "warn", true)
  end
  
  local playerGui = Player:WaitForChild("PlayerGui", 30)
  if not playerGui then
    Notify("❌ PlayerGui not found. Cannot proceed.", "error", true)
    return
  end

  -- Wait for Team to be set or select one
  if Player.Team and Player.Team.Name ~= "Neutral" and Player.Team.Name ~= "" then
    Notify("✅ Team already loaded: " .. Player.Team.Name, "success")
    return
  end

  Notify("⏳ Waiting for team selection GUI to load...", "warn", true)
  
  local mainGui = playerGui:WaitForChild("Main", 30)
  local chooseTeam = mainGui and mainGui:WaitForChild("ChooseTeam", 30)
  
  if chooseTeam then
    local elapsed = 0
    while elapsed < 30 do
      if not getgenv().AutoFruitSniper then return end
      if chooseTeam.Visible == true or (Player.Team and Player.Team.Name ~= "Neutral" and Player.Team.Name ~= "") then
        break
      end
      task.wait(0.5)
      elapsed = elapsed + 0.5
    end
  end

  if Player.Team and Player.Team.Name ~= "Neutral" and Player.Team.Name ~= "" then
    Notify("✅ Team loaded: " .. Player.Team.Name, "success")
    return
  end

  local teamValue = getgenv().Team or 0 -- 0 = Marines, 1 = Pirates
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
  local teamSuccess = false
  for i = 1, 10 do
    if not getgenv().AutoFruitSniper then return end
    pcall(function()
      CommF:InvokeServer("SetTeam", teamName)
    end)
    task.wait(0.2)
    if Player.Team and Player.Team.Name ~= "Neutral" and Player.Team.Name ~= "" then
      teamSuccess = true
      break
    end
  end

  -- Fallback click
  if not teamSuccess and chooseTeam then
    Notify("🔄 SetTeam Remote failed. Attempting GUI click fallback...", "warn", true)
    pcall(function()
      local container = chooseTeam:WaitForChild("Container", 5)
      local button = container:WaitForChild(teamName, 5):WaitForChild("Frame", 5):WaitForChild("ViewportFrame", 5):WaitForChild("TextButton", 5)
      if button then
        for _, conn in pairs(getconnections(button.MouseButton1Click)) do
          conn.Function()
        end
      end
    end)
  end

  -- Wait for Team assignment verification (LOAD TEAM)
  local elapsed = 0
  while elapsed < 10 do
    if not getgenv().AutoFruitSniper then return end
    if Player.Team and Player.Team.Name ~= "Neutral" and Player.Team.Name ~= "" then
      break
    end
    task.wait(0.5)
    elapsed = elapsed + 0.5
  end

  -- KHÔNG CÓ DELAY SAU KHI CHỌN TEAM THÀNH CÔNG (PROCEED IMMEDIATELY)
  if Player.Team and Player.Team.Name ~= "Neutral" and Player.Team.Name ~= "" then
    Notify("✅ Team loaded: " .. Player.Team.Name, "success")
  else
    Notify("⚠️ Could not verify Team selection. Proceeding anyway...", "warn", true)
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
-- NO-CLIP + POSITION SYNC
-- ═══════════════════════════════════════════════════════════════
task.spawn(function()
  repeat task.wait()
  until Player.Character and Player.Character.PrimaryPart
  block.CFrame = Player.Character.PrimaryPart.CFrame

  while task.wait() do
    pcall(function()
      if IsFarming and getgenv().AutoFruitSniper then
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
-- TWEEN / FLY TO POSITION (DỪNG BAY LẬP TỨC KHI TẮT SCRIPT)
-- ═══════════════════════════════════════════════════════════════
local function TweenToPosition(targetCFrame)
  local plrPP = Player.Character and Player.Character.PrimaryPart
  if not plrPP then return end
  local distance = (plrPP.Position - targetCFrame.p).Magnitude
  local speed = getgenv().TweenSpeed or 300
  local tweenTime = distance / speed
  if tweenTime < 0.1 then tweenTime = 0.1 end
  
  activeTween = TweenService:Create(
    block,
    TweenInfo.new(tweenTime, Enum.EasingStyle.Linear),
    {CFrame = targetCFrame}
  )
  activeTween:Play()
  
  -- Check periodically to allow instant cancellations
  local completed = false
  local connection
  connection = activeTween.Completed:Connect(function()
    completed = true
  end)

  while not completed and getgenv().AutoFruitSniper do
    task.wait(0.05)
  end

  if connection then
    connection:Disconnect()
  end

  if not getgenv().AutoFruitSniper and activeTween then
    activeTween:Cancel()
  end
  
  activeTween = nil
end

-- ═══════════════════════════════════════════════════════════════
-- FRUIT FINDER
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
  while true do
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
-- STORE FRUIT WITH RETRIES
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
    if not getgenv().AutoFruitSniper then return false end
    Notify("📦 Store attempt " .. attempt .. "/" .. maxRetries .. "...", "warn", true)

    local success, result = pcall(function()
      return CommF:InvokeServer("StoreFruit", fruitId, fruitTool)
    end)

    if success and result == true then
      Notify("✅ STORED " .. fruitTool.Name .. " on attempt " .. attempt .. "!", "success", true)
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
-- LOW PLAYER SERVER HOP (CHỌN SERVER ÍT NGƯỜI NHẤT)
-- ═══════════════════════════════════════════════════════════════
local function ServerHop()
  Notify("🔄 Searching for low-player servers (sort=Asc)...", "hop", true)

  pcall(function()
    local queueteleport = (syn and syn.queue_on_teleport)
      or queue_on_teleport
      or (fluxus and fluxus.queue_on_teleport)
    if queueteleport then
      queueteleport('loadstring(readfile("BloxFruit_AutoFruit.lua"))()')
      Notify("📋 Script queued for next server", "info")
    end
  end)

  -- Use sortOrder=Asc to fetch the least populated servers first
  local apiUrl = "https://games.roblox.com/v1/games/" .. CurrentPlaceId .. "/servers/Public?sortOrder=Asc&limit=100"

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
  local maxPages = 5 -- We only need to check the first few pages since they contain the lowest player counts!

  pcall(function()
    repeat
      if not getgenv().AutoFruitSniper then return end
      local Servers = ListServers(Next)
      pageAttempts = pageAttempts + 1

      if Servers and Servers.data then
        local candidates = {}
        for _, server in pairs(Servers.data) do
          local playing = tonumber(server.playing)
          local maxPlayers = tonumber(server.maxPlayers)
          -- Filter for active, non-full, non-empty, and different servers
          if server.id ~= game.JobId and playing and maxPlayers 
             and playing < (maxPlayers - 1) 
             and playing >= 1 then
            table.insert(candidates, server)
          end
        end

        if #candidates > 0 then
          table.sort(candidates, function(a, b)
            return a.playing < b.playing
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

  -- Fallback to standard server hop if low-player search returned nothing
  if not Server then
    Notify("⚠️ Ascending search empty. Retrying standard search...", "warn")
    local descApiUrl = "https://games.roblox.com/v1/games/" .. CurrentPlaceId .. "/servers/Public?sortOrder=Desc&excludeFullGames=true&limit=100"
    pageAttempts = 0
    pcall(function()
      repeat
        if not getgenv().AutoFruitSniper then return end
        local raw = game:HttpGet(descApiUrl .. ((Next and "&cursor=" .. Next) or ""))
        local Servers = HttpService:JSONDecode(raw)
        pageAttempts = pageAttempts + 1
        if Servers and Servers.data then
          local candidates = {}
          for _, server in pairs(Servers.data) do
            if server.id ~= game.JobId and server.playing and server.maxPlayers 
               and server.playing < (server.maxPlayers - 1) then
              table.insert(candidates, server)
            end
          end
          if #candidates > 0 then
            table.sort(candidates, function(a, b) return a.playing < b.playing end)
            Server = candidates[1]
            break
          end
          Next = Servers.nextPageCursor
        end
        task.wait(0.25)
      until Server or not Next or pageAttempts >= maxPages
    end)
  end

  if not getgenv().AutoFruitSniper then return end

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
      task.wait(5)
    else
      task.wait(15)
      Notify("⚠️ Still here? Retrying hop...", "warn", true)
    end
  else
    Notify("⚠️ Failed to find valid server.", "error", true)
    Notify("🔄 Using random Teleport fallback...", "warn")

    pcall(function()
      TeleportService:Teleport(CurrentPlaceId, Player)
    end)

    task.wait(15)
  end
end

-- ═══════════════════════════════════════════════════════════════
-- ANTI-AFK
-- ═══════════════════════════════════════════════════════════════
task.spawn(function()
  while true do
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
    if not getgenv().AutoFruitSniper then return nil end
    task.wait(0.2)
    char = Player.Character or Player.CharacterAdded:Wait()
  end
  block.CFrame = char.HumanoidRootPart.CFrame
  return char
end

-- ═══════════════════════════════════════════════════════════════
-- MAIN EXECUTION CONTROL FUNCTIONS
-- ═══════════════════════════════════════════════════════════════
local function runMainLoop()
  while getgenv().AutoFruitSniper do
    Notify("⏳ Waiting for character...", "info", true)
    local char = WaitForCharacter()
    if not char then return end
    Notify("✅ Character loaded!", "success")

    Notify("🔍 Scanning for fruits...", "action", true)
    local fruit = FruitFind()

    if not getgenv().AutoFruitSniper then return end

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

      if not getgenv().AutoFruitSniper then return end

      IsFarming = true
      Notify("✈️ Flying to " .. fruit.Name .. "...", "action", true)

      local aboveFruit = CFrame.new(fruitHandle.Position + Vector3.new(0, 5, 0))
      TweenToPosition(aboveFruit)
      
      if not getgenv().AutoFruitSniper then return end
      task.wait(0.3)
      
      Notify("📍 Approaching fruit...", "action")
      TweenToPosition(fruitHandle.CFrame)
      
      if not getgenv().AutoFruitSniper then return end
      task.wait(0.5)
      Notify("✅ Arrived at fruit!", "success")

      Notify("🤚 Grabbing " .. fruit.Name .. "...", "action", true)

      local plrPP = Player.Character and Player.Character.PrimaryPart
      if plrPP and fruitHandle then
        for i = 1, 10 do
          if not getgenv().AutoFruitSniper then return end
          if not fruit.Parent or fruit.Parent ~= workspace then
            Notify("✅ Fruit picked up!", "success")
            break
          end
          plrPP.CFrame = fruitHandle.CFrame
          block.CFrame = fruitHandle.CFrame
          task.wait(0.2)
        end
      end

      if not getgenv().AutoFruitSniper then return end
      task.wait(1)

      local inventoryFruit = FindFruitInInventory()

      if inventoryFruit then
        Notify("📦 Fruit in inventory! Storing...", "action", true)
        local stored = StoreFruitWithRetry(inventoryFruit)

        if stored then
          Notify("✅ Fruit stored successfully!", "success", true)
        else
          Notify("⚠️ Store failed. Hopping anyway...", "warn", true)
        end
      else
        task.wait(0.5)
        if not getgenv().AutoFruitSniper then return end
        local retryFruit = FindFruitInInventory()
        if retryFruit then
          Notify("📦 Found fruit on retry! Storing...", "action")
          StoreFruitWithRetry(retryFruit)
        else
          Notify("⚠️ Fruit not in inventory. Pickup may have failed.", "warn", true)
        end
      end

      IsFarming = false

      if not getgenv().AutoFruitSniper then return end
      Notify("⏳ Hopping in " .. getgenv().HopDelay .. "s...", "hop", true)
      
      local elapsed = 0
      while elapsed < getgenv().HopDelay do
        if not getgenv().AutoFruitSniper then return end
        task.wait(0.5)
        elapsed = elapsed + 0.5
      end
      
      if not getgenv().AutoFruitSniper then return end
      ServerHop()
      break
    else
      Notify("❌ No fruit found in this server", "error", true)
      Notify("⏳ Hopping in " .. getgenv().HopDelay .. "s...", "hop")
      
      local elapsed = 0
      while elapsed < getgenv().HopDelay do
        if not getgenv().AutoFruitSniper then return end
        task.wait(0.5)
        elapsed = elapsed + 0.5
      end
      
      if not getgenv().AutoFruitSniper then return end
      ServerHop()
      break
    end
  end
end

-- Stop script and cleanup states
local function stopScript()
  scriptRunning = false
  getgenv().AutoFruitSniper = false
  IsFarming = false
  if activeTween then
    activeTween:Cancel()
    activeTween = nil
  end
  pcall(function()
    local plrChar = Player.Character
    if plrChar then
      for _, part in pairs(plrChar:GetChildren()) do
        if part:IsA("BasePart") then
          part.CanCollide = true
        end
      end
    end
  end)
  -- Remove existing ESP
  for _, obj in pairs(workspace:GetChildren()) do
    pcall(function()
      if obj and obj:IsA("Tool") and obj:FindFirstChild("Handle") then
        RemoveESP(obj.Handle)
      elseif obj and string.find(obj.Name, "Fruit") and obj:FindFirstChild("Handle") then
        RemoveESP(obj.Handle)
      end
    end)
  end
  Notify("🛑 Script Stopped!", "error", true)
end

-- Start script states
local function startScript()
  scriptRunning = true
  getgenv().AutoFruitSniper = true
  Notify("▶️ Script Started!", "success", true)
  task.spawn(runMainLoop)
end

-- Close UI, stop scripts, delete elements
local function closeUI()
  stopScript()
  if block then block:Destroy() end
  if ScreenGui then ScreenGui:Destroy() end
end

-- Connect UI controls
StopButton.MouseButton1Click:Connect(function()
  if scriptRunning then
    stopScript()
    StopButton.Text = "▶️ START SCRIPT"
    StopGradient.Color = ColorSequence.new({
      ColorSequenceKeypoint.new(0, Color3.fromRGB(60, 180, 60)),
      ColorSequenceKeypoint.new(1, Color3.fromRGB(30, 120, 30))
    })
    StopStroke.Color = Color3.fromRGB(100, 255, 100)
  else
    startScript()
    StopButton.Text = "🛑 STOP SCRIPT"
    StopGradient.Color = ColorSequence.new({
      ColorSequenceKeypoint.new(0, Color3.fromRGB(200, 50, 50)),
      ColorSequenceKeypoint.new(1, Color3.fromRGB(140, 20, 20))
    })
    StopStroke.Color = Color3.fromRGB(255, 100, 100)
  end
end)

CloseButton.MouseButton1Click:Connect(function()
  closeUI()
end)

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
if getgenv().DiscordWebhook and getgenv().DiscordWebhook ~= "" then
  Notify("💬 Discord Webhook: Enabled", "info")
else
  Notify("💬 Discord Webhook: Disabled", "info")
end
Notify("──────────────────────────────", "info")
task.wait(0.5)

-- Execute auto team wait & selection
WaitAndSelectTeam()

-- Execute main loop
task.spawn(runMainLoop)

Notify("🚀 Auto Fruit Sniper is RUNNING!", "success")
