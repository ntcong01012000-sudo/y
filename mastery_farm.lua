

local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
local Workspace = game:GetService("Workspace")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local CoreGui = game:GetService("CoreGui")
local Lighting = game:GetService("Lighting")
local HttpService = game:GetService("HttpService")
local TeleportService = game:GetService("TeleportService")

-- Ensure LocalPlayer is loaded
if not LocalPlayer then
    Players:GetPropertyChangedSignal("LocalPlayer"):Wait()
    LocalPlayer = Players.LocalPlayer
end

-- Global/Gen env configurations
getgenv().MasteryConfig = {
    Enabled = false,
    BaseWeapon = "Melee", -- "Melee" or "Sword"
    MasteryWeapon = "Fruit", -- "Fruit" or "Gun"
    ThresholdHP = 20, -- percentage
    PositionMode = "Above", -- "Above", "Behind", "Below"
    DistanceOffset = 20, -- distance in studs
    LongClick = false,
    AutoHop30M = true,
    AutoSetTeam = true,
    AutoAwakenV4 = false, -- Thêm cấu hình tự bật tộc V4
    FruitGunClickInterval = 0.5, -- Tốc độ click đánh thường của Fruit và Gun (giây)
    AutoHopOnPlayer = false, -- Tự động đổi server khi phát hiện người chơi khác xung quanh
    DetectPlayerRadius = 250, -- Khoảng cách phát hiện người chơi (studs), mặc định là 250 studs
    Skills = {
        Z = true,
        X = true,
        C = true,
        V = true,
        F = true,
        Click = true
    }
}

-- 1. CONFIGURATION STORAGE (SAVE/LOAD SYSTEM)
local saveFileName = "BloxFruits_MasteryFarmConfig.json"

local function saveSettings()
    pcall(function()
        local data = HttpService:JSONEncode(getgenv().MasteryConfig)
        if writefile then
            writefile(saveFileName, data)
        end
    end)
end

local function loadSettings()
    pcall(function()
        if isfile and isfile(saveFileName) and readfile then
            local data = readfile(saveFileName)
            local decoded = HttpService:JSONDecode(data)
            if decoded then
                for k, v in pairs(decoded) do
                    if type(v) == "table" and k == "Skills" then
                        for sk, sv in pairs(v) do
                            getgenv().MasteryConfig.Skills[sk] = sv
                        end
                    else
                        getgenv().MasteryConfig[k] = v
                    end
                end
            end
        end
    end)
end

-- Load settings immediately
loadSettings()

-- 2. UNIVERSAL PLAYER CHARACTER SOLVER
local function getPlayerCharacter(player)
    if not player then return nil end
    local char = player.Character
    if char and char.Parent then return char end
    
    local BF_Characters = Workspace:FindFirstChild("Characters")
    if BF_Characters then
        local found = BF_Characters:FindFirstChild(player.Name)
        if found then return found end
        for _, child in ipairs(BF_Characters:GetChildren()) do
            if child:IsA("Model") and child.Name:lower() == player.Name:lower() then
                return child
            end
        end
    end
    
    char = Workspace:FindFirstChild(player.Name)
    if char then return char end
    
    for _, child in ipairs(Workspace:GetChildren()) do
        if child:IsA("Model") and child.Name:lower() == player.Name:lower() then
            return child
        end
    end
    return nil
end

-- 3. OBTAIN GUI PARENT
local parentGui
local guiSuccess = pcall(function()
    local testGui = Instance.new("ScreenGui")
    testGui.Parent = CoreGui
    testGui:Destroy()
    parentGui = CoreGui
end)

if not guiSuccess or not parentGui then
    parentGui = LocalPlayer:WaitForChild("PlayerGui", 10)
end

-- Cleanup old GUIs
if parentGui:FindFirstChild("MasteryFarmGui") then
    parentGui.MasteryFarmGui:Destroy()
end
if parentGui:FindFirstChild("AutoTPAimGui") then
    parentGui.AutoTPAimGui:Destroy()
end

-- 4. CREATE CONTROL PANEL WINDOW
local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "MasteryFarmGui"
ScreenGui.ResetOnSpawn = false
ScreenGui.Parent = parentGui

-- On-Screen Notification System
local function showNotification(text, color)
    task.spawn(function()
        if not ScreenGui or not ScreenGui.Parent then return end
        local notification = Instance.new("Frame")
        notification.Name = "Notification"
        notification.Size = UDim2.new(0, 240, 0, 42)
        notification.Position = UDim2.new(0.5, -120, 0, -50)
        notification.BackgroundColor3 = Color3.fromRGB(20, 15, 20)
        notification.BorderSizePixel = 0
        notification.ZIndex = 10
        notification.Parent = ScreenGui
        
        local corner = Instance.new("UICorner")
        corner.CornerRadius = UDim.new(0, 8)
        corner.Parent = notification
        
        local stroke = Instance.new("UIStroke")
        stroke.Color = color or Color3.fromRGB(255, 100, 150)
        stroke.Thickness = 1.5
        stroke.Parent = notification
        
        local label = Instance.new("TextLabel")
        label.Size = UDim2.new(1, -20, 1, 0)
        label.Position = UDim2.new(0, 10, 0, 0)
        label.BackgroundTransparency = 1
        label.Text = text
        label.Font = Enum.Font.GothamMedium
        label.TextSize = 9
        label.TextColor3 = Color3.fromRGB(255, 255, 255)
        label.TextWrapped = true
        label.Parent = notification
        
        local tweenIn = TweenService:Create(notification, TweenInfo.new(0.4, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
            Position = UDim2.new(0.5, -120, 0, 20)
        })
        local tweenOut = TweenService:Create(notification, TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
            Position = UDim2.new(0.5, -120, 0, -50),
            BackgroundTransparency = 1
        })
        
        tweenIn:Play()
        task.wait(2.5)
        tweenOut:Play()
        tweenOut.Completed:Connect(function()
            notification:Destroy()
        end)
    end)
end

-- Floating Toggle Icon Button
local IconButton = Instance.new("TextButton")
IconButton.Name = "IconButton"
IconButton.Size = UDim2.new(0, 56, 0, 56)
IconButton.Position = UDim2.new(0.05, 0, 0.35, 0)
IconButton.BackgroundColor3 = Color3.fromRGB(30, 25, 30)
IconButton.BorderSizePixel = 0
IconButton.Text = "🍰"
IconButton.TextSize = 24
IconButton.Active = true
IconButton.Parent = ScreenGui

local IconCorner = Instance.new("UICorner")
IconCorner.CornerRadius = UDim.new(0.5, 0)
IconCorner.Parent = IconButton

local IconStroke = Instance.new("UIStroke")
IconStroke.Color = Color3.fromRGB(255, 100, 150)
IconStroke.Thickness = 2
IconStroke.Parent = IconButton

local IconLabel = Instance.new("TextLabel")
IconLabel.Size = UDim2.new(1, 0, 0, 15)
IconLabel.Position = UDim2.new(0, 0, 1, -15)
IconLabel.BackgroundTransparency = 1
IconLabel.Text = "MASTERY"
IconLabel.Font = Enum.Font.GothamBold
IconLabel.TextSize = 8
IconLabel.TextColor3 = Color3.fromRGB(255, 150, 180)
IconLabel.Active = false
IconLabel.Selectable = false
IconLabel.Parent = IconButton

-- Mastery Control Panel Window
local Window = Instance.new("Frame")
Window.Name = "Window"
Window.Size = UDim2.new(0, 310, 0, 285)
Window.Position = UDim2.new(0.05, 66, 0.35, -112)
Window.BackgroundColor3 = Color3.fromRGB(20, 15, 20)
Window.BackgroundTransparency = 0.05
Window.BorderSizePixel = 0
Window.Visible = false
Window.Active = false
Window.Selectable = false
Window.Parent = ScreenGui

local WindowCorner = Instance.new("UICorner")
WindowCorner.CornerRadius = UDim.new(0, 10)
WindowCorner.Parent = Window

local WindowStroke = Instance.new("UIStroke")
WindowStroke.Color = Color3.fromRGB(255, 100, 150)
WindowStroke.Thickness = 1.5
WindowStroke.Parent = Window

local Title = Instance.new("TextLabel")
Title.Size = UDim2.new(1, 0, 0, 30)
Title.BackgroundTransparency = 1
Title.Text = "🍰 THIẾT LẬP FARM MASTERY"
Title.Font = Enum.Font.GothamBold
Title.TextSize = 11
Title.TextColor3 = Color3.fromRGB(255, 120, 170)
Title.Active = false
Title.Selectable = false
Title.Parent = Window

-- ==========================================
--             TAB MENU SYSTEM
-- ==========================================
local TabSelector = Instance.new("Frame")
TabSelector.Name = "TabSelector"
TabSelector.Size = UDim2.new(1, -30, 0, 24)
TabSelector.Position = UDim2.new(0, 15, 0, 32)
TabSelector.BackgroundTransparency = 1
TabSelector.Parent = Window

local TabFarmBtn = Instance.new("TextButton")
TabFarmBtn.Size = UDim2.new(0, 90, 1, 0)
TabFarmBtn.Position = UDim2.new(0, 0, 0, 0)
TabFarmBtn.BackgroundColor3 = Color3.fromRGB(255, 100, 150)
TabFarmBtn.Text = "FARM"
TabFarmBtn.Font = Enum.Font.GothamBold
TabFarmBtn.TextSize = 8
TabFarmBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
TabFarmBtn.Parent = TabSelector

local TabFarmCorner = Instance.new("UICorner")
TabFarmCorner.CornerRadius = UDim.new(0, 4)
TabFarmCorner.Parent = TabFarmBtn

local TabFarmStroke = Instance.new("UIStroke")
TabFarmStroke.Color = Color3.fromRGB(255, 100, 150)
TabFarmStroke.Thickness = 1
TabFarmStroke.Parent = TabFarmBtn

local TabSkillsBtn = Instance.new("TextButton")
TabSkillsBtn.Size = UDim2.new(0, 90, 1, 0)
TabSkillsBtn.Position = UDim2.new(0, 95, 0, 0)
TabSkillsBtn.BackgroundColor3 = Color3.fromRGB(30, 20, 25)
TabSkillsBtn.Text = "KỸ NĂNG"
TabSkillsBtn.Font = Enum.Font.GothamBold
TabSkillsBtn.TextSize = 8
TabSkillsBtn.TextColor3 = Color3.fromRGB(180, 180, 180)
TabSkillsBtn.Parent = TabSelector

local TabSkillsCorner = Instance.new("UICorner")
TabSkillsCorner.CornerRadius = UDim.new(0, 4)
TabSkillsCorner.Parent = TabSkillsBtn

local TabSkillsStroke = Instance.new("UIStroke")
TabSkillsStroke.Color = Color3.fromRGB(100, 50, 70)
TabSkillsStroke.Thickness = 1
TabSkillsStroke.Parent = TabSkillsBtn

local TabSettingsBtn = Instance.new("TextButton")
TabSettingsBtn.Size = UDim2.new(0, 90, 1, 0)
TabSettingsBtn.Position = UDim2.new(0, 190, 0, 0)
TabSettingsBtn.BackgroundColor3 = Color3.fromRGB(30, 20, 25)
TabSettingsBtn.Text = "CÀI ĐẶT PHỤ"
TabSettingsBtn.Font = Enum.Font.GothamBold
TabSettingsBtn.TextSize = 8
TabSettingsBtn.TextColor3 = Color3.fromRGB(180, 180, 180)
TabSettingsBtn.Parent = TabSelector

local TabSettingsCorner = Instance.new("UICorner")
TabSettingsCorner.CornerRadius = UDim.new(0, 4)
TabSettingsCorner.Parent = TabSettingsBtn

local TabSettingsStroke = Instance.new("UIStroke")
TabSettingsStroke.Color = Color3.fromRGB(100, 50, 70)
TabSettingsStroke.Thickness = 1
TabSettingsStroke.Parent = TabSettingsBtn

-- ==========================================
--             TAB BODY CONTAINERS
-- ==========================================
local TabFarm = Instance.new("Frame")
TabFarm.Name = "TabFarm"
TabFarm.Size = UDim2.new(1, -30, 0, 180)
TabFarm.Position = UDim2.new(0, 15, 0, 62)
TabFarm.BackgroundTransparency = 1
TabFarm.Visible = true
TabFarm.Parent = Window

local TabSkills = Instance.new("Frame")
TabSkills.Name = "TabSkills"
TabSkills.Size = UDim2.new(1, -30, 0, 180)
TabSkills.Position = UDim2.new(0, 15, 0, 62)
TabSkills.BackgroundTransparency = 1
TabSkills.Visible = false
TabSkills.Parent = Window

local TabSettings = Instance.new("Frame")
TabSettings.Name = "TabSettings"
TabSettings.Size = UDim2.new(1, -30, 0, 180)
TabSettings.Position = UDim2.new(0, 15, 0, 62)
TabSettings.BackgroundTransparency = 1
TabSettings.Visible = false
TabSettings.Parent = Window

-- ==========================================
--             TAB 1: FARM CONTENTS
-- ==========================================
-- Toggle Button (Auto Farm Mastery)
local ToggleButton = Instance.new("TextButton")
ToggleButton.Size = UDim2.new(1, 0, 0, 30)
ToggleButton.Position = UDim2.new(0, 0, 0, 0)
ToggleButton.BackgroundColor3 = Color3.fromRGB(45, 30, 35)
ToggleButton.BorderSizePixel = 0
ToggleButton.Text = "FARM MASTERY: TẮT"
ToggleButton.Font = Enum.Font.GothamBold
ToggleButton.TextSize = 10
ToggleButton.TextColor3 = Color3.fromRGB(255, 255, 255)
ToggleButton.Parent = TabFarm

local ToggleCorner = Instance.new("UICorner")
ToggleCorner.CornerRadius = UDim.new(0, 6)
ToggleCorner.Parent = ToggleButton

local ToggleStroke = Instance.new("UIStroke")
ToggleStroke.Color = Color3.fromRGB(150, 60, 90)
ToggleStroke.Thickness = 1
ToggleStroke.Parent = ToggleButton

-- Base Weapon Selector
local BaseLabel = Instance.new("TextLabel")
BaseLabel.Size = UDim2.new(0, 130, 0, 20)
BaseLabel.Position = UDim2.new(0, 0, 0, 36)
BaseLabel.BackgroundTransparency = 1
BaseLabel.Text = "Vũ khí cấu rỉa:"
BaseLabel.Font = Enum.Font.GothamMedium
BaseLabel.TextSize = 9
BaseLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
BaseLabel.TextXAlignment = Enum.TextXAlignment.Left
BaseLabel.Active = false
BaseLabel.Selectable = false
BaseLabel.Parent = TabFarm

local MeleeBtn = Instance.new("TextButton")
MeleeBtn.Size = UDim2.new(0, 70, 0, 20)
MeleeBtn.Position = UDim2.new(0, 135, 0, 36)
MeleeBtn.BackgroundColor3 = Color3.fromRGB(255, 100, 150)
MeleeBtn.Text = "VÕ"
MeleeBtn.Font = Enum.Font.GothamBold
MeleeBtn.TextSize = 9
MeleeBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
MeleeBtn.Parent = TabFarm

local MeleeCorner = Instance.new("UICorner")
MeleeCorner.CornerRadius = UDim.new(0, 4)
MeleeCorner.Parent = MeleeBtn

local SwordBtn = Instance.new("TextButton")
SwordBtn.Size = UDim2.new(0, 70, 0, 20)
SwordBtn.Position = UDim2.new(0, 210, 0, 36)
SwordBtn.BackgroundColor3 = Color3.fromRGB(40, 30, 35)
SwordBtn.Text = "KIẾM"
SwordBtn.Font = Enum.Font.GothamBold
SwordBtn.TextSize = 9
SwordBtn.TextColor3 = Color3.fromRGB(180, 180, 180)
SwordBtn.Parent = TabFarm

local SwordCorner = Instance.new("UICorner")
SwordCorner.CornerRadius = UDim.new(0, 4)
SwordCorner.Parent = SwordBtn

-- Mastery Weapon Selector
local MasteryLabel = Instance.new("TextLabel")
MasteryLabel.Size = UDim2.new(0, 130, 0, 20)
MasteryLabel.Position = UDim2.new(0, 0, 0, 62)
MasteryLabel.BackgroundTransparency = 1
MasteryLabel.Text = "Vũ khí kết liễu (Mastery):"
MasteryLabel.Font = Enum.Font.GothamMedium
MasteryLabel.TextSize = 9
MasteryLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
MasteryLabel.TextXAlignment = Enum.TextXAlignment.Left
MasteryLabel.Active = false
MasteryLabel.Selectable = false
MasteryLabel.Parent = TabFarm

local FruitBtn = Instance.new("TextButton")
FruitBtn.Size = UDim2.new(0, 70, 0, 20)
FruitBtn.Position = UDim2.new(0, 135, 0, 62)
FruitBtn.BackgroundColor3 = Color3.fromRGB(255, 100, 150)
FruitBtn.Text = "TRÁI"
FruitBtn.Font = Enum.Font.GothamBold
FruitBtn.TextSize = 9
FruitBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
FruitBtn.Parent = TabFarm

local FruitCorner = Instance.new("UICorner")
FruitCorner.CornerRadius = UDim.new(0, 4)
FruitCorner.Parent = FruitBtn

local GunBtn = Instance.new("TextButton")
GunBtn.Size = UDim2.new(0, 70, 0, 20)
GunBtn.Position = UDim2.new(0, 210, 0, 62)
GunBtn.BackgroundColor3 = Color3.fromRGB(40, 30, 35)
GunBtn.Text = "SÚNG"
GunBtn.Font = Enum.Font.GothamBold
GunBtn.TextSize = 9
GunBtn.TextColor3 = Color3.fromRGB(180, 180, 180)
GunBtn.Parent = TabFarm

local GunCorner = Instance.new("UICorner")
GunCorner.CornerRadius = UDim.new(0, 4)
GunCorner.Parent = GunBtn

-- Threshold HP Input
local ThresholdLabel = Instance.new("TextLabel")
ThresholdLabel.Size = UDim2.new(0, 210, 0, 20)
ThresholdLabel.Position = UDim2.new(0, 0, 0, 88)
ThresholdLabel.BackgroundTransparency = 1
ThresholdLabel.Text = "Đổi vũ khí khi Máu Quái dưới (%):"
ThresholdLabel.Font = Enum.Font.GothamMedium
ThresholdLabel.TextSize = 9
ThresholdLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
ThresholdLabel.TextXAlignment = Enum.TextXAlignment.Left
ThresholdLabel.Active = false
ThresholdLabel.Selectable = false
ThresholdLabel.Parent = TabFarm

local HPInput = Instance.new("TextBox")
HPInput.Size = UDim2.new(0, 65, 0, 20)
HPInput.Position = UDim2.new(0, 215, 0, 88)
HPInput.BackgroundColor3 = Color3.fromRGB(35, 25, 30)
HPInput.BorderSizePixel = 0
HPInput.Text = tostring(getgenv().MasteryConfig.ThresholdHP)
HPInput.Font = Enum.Font.GothamBold
HPInput.TextSize = 10
HPInput.TextColor3 = Color3.fromRGB(255, 100, 150)
HPInput.ClearTextOnFocus = false
HPInput.Active = true
HPInput.Selectable = true
HPInput.Parent = TabFarm

local InputCorner = Instance.new("UICorner")
InputCorner.CornerRadius = UDim.new(0, 4)
InputCorner.Parent = HPInput

local InputStroke = Instance.new("UIStroke")
InputStroke.Color = Color3.fromRGB(150, 60, 90)
InputStroke.Thickness = 1
InputStroke.Parent = HPInput

-- Farm Position Mode Selector
local PosModeLabel = Instance.new("TextLabel")
PosModeLabel.Size = UDim2.new(0, 100, 0, 20)
PosModeLabel.Position = UDim2.new(0, 0, 0, 114)
PosModeLabel.BackgroundTransparency = 1
PosModeLabel.Text = "Chọn hướng đứng:"
PosModeLabel.Font = Enum.Font.GothamMedium
PosModeLabel.TextSize = 9
PosModeLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
PosModeLabel.TextXAlignment = Enum.TextXAlignment.Left
PosModeLabel.Active = false
PosModeLabel.Selectable = false
PosModeLabel.Parent = TabFarm

local AboveBtn = Instance.new("TextButton")
AboveBtn.Size = UDim2.new(0, 56, 0, 20)
AboveBtn.Position = UDim2.new(0, 105, 0, 114)
AboveBtn.BackgroundColor3 = Color3.fromRGB(255, 100, 150)
AboveBtn.Text = "ĐẦU"
AboveBtn.Font = Enum.Font.GothamBold
AboveBtn.TextSize = 8
AboveBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
AboveBtn.Parent = TabFarm

local AboveCorner = Instance.new("UICorner")
AboveCorner.CornerRadius = UDim.new(0, 4)
AboveCorner.Parent = AboveBtn

local BehindBtn = Instance.new("TextButton")
BehindBtn.Size = UDim2.new(0, 56, 0, 20)
BehindBtn.Position = UDim2.new(0, 164, 0, 114)
BehindBtn.BackgroundColor3 = Color3.fromRGB(40, 30, 35)
BehindBtn.Text = "LƯNG"
BehindBtn.Font = Enum.Font.GothamBold
BehindBtn.TextSize = 8
BehindBtn.TextColor3 = Color3.fromRGB(180, 180, 180)
BehindBtn.Parent = TabFarm

local BehindCorner = Instance.new("UICorner")
BehindCorner.CornerRadius = UDim.new(0, 4)
BehindCorner.Parent = BehindBtn

local BelowBtn = Instance.new("TextButton")
BelowBtn.Size = UDim2.new(0, 56, 0, 20)
BelowBtn.Position = UDim2.new(0, 223, 0, 114)
BelowBtn.BackgroundColor3 = Color3.fromRGB(40, 30, 35)
BelowBtn.Text = "CHÂN"
BelowBtn.Font = Enum.Font.GothamBold
BelowBtn.TextSize = 8
BelowBtn.TextColor3 = Color3.fromRGB(180, 180, 180)
BelowBtn.Parent = TabFarm

local BelowCorner = Instance.new("UICorner")
BelowCorner.CornerRadius = UDim.new(0, 4)
BelowCorner.Parent = BelowBtn

-- ==========================================
--             TAB 2: SKILLS CONTENTS
-- ==========================================
local SkillsLabel = Instance.new("TextLabel")
SkillsLabel.Size = UDim2.new(1, 0, 0, 18)
SkillsLabel.Position = UDim2.new(0, 0, 0, 5)
SkillsLabel.BackgroundTransparency = 1
SkillsLabel.Text = "Kỹ năng sử dụng khi Mastery (cooldown 0.1s):"
SkillsLabel.Font = Enum.Font.GothamBold
SkillsLabel.TextSize = 9
SkillsLabel.TextColor3 = Color3.fromRGB(255, 120, 170)
SkillsLabel.TextXAlignment = Enum.TextXAlignment.Left
SkillsLabel.Active = false
SkillsLabel.Selectable = false
SkillsLabel.Parent = TabSkills

local keysList = {"Z", "X", "C", "V", "F", "Click"}
local skillButtons = {}

for i, key in ipairs(keysList) do
    local btn = Instance.new("TextButton")
    btn.Name = key .. "SkillBtn"
    btn.Size = UDim2.new(0, 85, 0, 32)
    
    local col = (i - 1) % 3
    local row = math.floor((i - 1) / 3)
    btn.Position = UDim2.new(0, col * 95, 0, 30 + row * 40)
    
    if key == "Click" then
        btn.Text = "CLICK"
    else
        btn.Text = key
    end
    
    btn.BackgroundColor3 = Color3.fromRGB(15, 80, 50) -- Default Green (ON)
    btn.Font = Enum.Font.GothamBold
    btn.TextSize = 10
    btn.TextColor3 = Color3.fromRGB(255, 255, 255)
    btn.Parent = TabSkills
    
    local c = Instance.new("UICorner")
    c.CornerRadius = UDim.new(0, 4)
    c.Parent = btn
    
    local s = Instance.new("UIStroke")
    s.Color = Color3.fromRGB(100, 255, 150)
    s.Thickness = 1
    s.Parent = btn
    
    skillButtons[key] = btn
end

-- ==========================================
--             TAB 3: SETTINGS CONTENTS
-- ==========================================
local LongClickBtn = Instance.new("TextButton")
LongClickBtn.Size = UDim2.new(0, 135, 0, 22)
LongClickBtn.Position = UDim2.new(0, 0, 0, 5)
LongClickBtn.BackgroundColor3 = Color3.fromRGB(40, 30, 35)
LongClickBtn.Text = "LONG CLICK: TẮT"
LongClickBtn.Font = Enum.Font.GothamBold
LongClickBtn.TextSize = 8
LongClickBtn.TextColor3 = Color3.fromRGB(180, 180, 180)
LongClickBtn.Parent = TabSettings

local LongClickCorner = Instance.new("UICorner")
LongClickCorner.CornerRadius = UDim.new(0, 4)
LongClickCorner.Parent = LongClickBtn

local LongClickStroke = Instance.new("UIStroke")
LongClickStroke.Color = Color3.fromRGB(100, 50, 80)
LongClickStroke.Thickness = 1
LongClickStroke.Parent = LongClickBtn

local AutoHopBtn = Instance.new("TextButton")
AutoHopBtn.Size = UDim2.new(0, 135, 0, 22)
AutoHopBtn.Position = UDim2.new(0, 145, 0, 5)
AutoHopBtn.BackgroundColor3 = Color3.fromRGB(15, 80, 50)
AutoHopBtn.Text = "AUTO HOP 30P: BẬT"
AutoHopBtn.Font = Enum.Font.GothamBold
AutoHopBtn.TextSize = 8
AutoHopBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
AutoHopBtn.Parent = TabSettings

local AutoHopCorner = Instance.new("UICorner")
AutoHopCorner.CornerRadius = UDim.new(0, 4)
AutoHopCorner.Parent = AutoHopBtn

local AutoHopStroke = Instance.new("UIStroke")
AutoHopStroke.Color = Color3.fromRGB(100, 255, 150)
AutoHopStroke.Thickness = 1
AutoHopStroke.Parent = AutoHopBtn

local AutoTeamBtn = Instance.new("TextButton")
AutoTeamBtn.Size = UDim2.new(0, 135, 0, 22)
AutoTeamBtn.Position = UDim2.new(0, 0, 0, 32)
AutoTeamBtn.BackgroundColor3 = Color3.fromRGB(15, 80, 50)
AutoTeamBtn.Text = "AUTO TEAM: BẬT"
AutoTeamBtn.Font = Enum.Font.GothamBold
AutoTeamBtn.TextSize = 8
AutoTeamBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
AutoTeamBtn.Parent = TabSettings

local AutoTeamCorner = Instance.new("UICorner")
AutoTeamCorner.CornerRadius = UDim.new(0, 4)
AutoTeamCorner.Parent = AutoTeamBtn

local AutoTeamStroke = Instance.new("UIStroke")
AutoTeamStroke.Color = Color3.fromRGB(100, 255, 150)
AutoTeamStroke.Thickness = 1
AutoTeamStroke.Parent = AutoTeamBtn

local HopCountdownLabel = Instance.new("TextLabel")
HopCountdownLabel.Size = UDim2.new(0, 135, 0, 22)
HopCountdownLabel.Position = UDim2.new(0, 145, 0, 32)
HopCountdownLabel.BackgroundTransparency = 1
HopCountdownLabel.Text = "Đổi SV sau: 30:00"
HopCountdownLabel.Font = Enum.Font.GothamMedium
HopCountdownLabel.TextSize = 8
HopCountdownLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
HopCountdownLabel.TextXAlignment = Enum.TextXAlignment.Center
HopCountdownLabel.Active = false
HopCountdownLabel.Selectable = false
HopCountdownLabel.Parent = TabSettings

local AutoAwakenBtn = Instance.new("TextButton")
AutoAwakenBtn.Size = UDim2.new(0, 280, 0, 22)
AutoAwakenBtn.Position = UDim2.new(0, 0, 0, 60)
AutoAwakenBtn.BackgroundColor3 = Color3.fromRGB(40, 30, 35)
AutoAwakenBtn.Text = "AUTO TỘC V4: TẮT"
AutoAwakenBtn.Font = Enum.Font.GothamBold
AutoAwakenBtn.TextSize = 8
AutoAwakenBtn.TextColor3 = Color3.fromRGB(180, 180, 180)
AutoAwakenBtn.Parent = TabSettings

local AutoAwakenCorner = Instance.new("UICorner")
AutoAwakenCorner.CornerRadius = UDim.new(0, 4)
AutoAwakenCorner.Parent = AutoAwakenBtn

local AutoAwakenStroke = Instance.new("UIStroke")
AutoAwakenStroke.Color = Color3.fromRGB(100, 50, 80)
AutoAwakenStroke.Thickness = 1
AutoAwakenStroke.Parent = AutoAwakenBtn

-- Distance Config inside TabSettings
local DistanceLabel = Instance.new("TextLabel")
DistanceLabel.Size = UDim2.new(0, 210, 0, 20)
DistanceLabel.Position = UDim2.new(0, 0, 0, 88)
DistanceLabel.BackgroundTransparency = 1
DistanceLabel.Text = "Khoảng cách đứng với Quái (studs):"
DistanceLabel.Font = Enum.Font.GothamMedium
DistanceLabel.TextSize = 9
DistanceLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
DistanceLabel.TextXAlignment = Enum.TextXAlignment.Left
DistanceLabel.Active = false
DistanceLabel.Selectable = false
DistanceLabel.Parent = TabSettings

local DistanceInput = Instance.new("TextBox")
DistanceInput.Size = UDim2.new(0, 65, 0, 20)
DistanceInput.Position = UDim2.new(0, 215, 0, 88)
DistanceInput.BackgroundColor3 = Color3.fromRGB(35, 25, 30)
DistanceInput.BorderSizePixel = 0
DistanceInput.Text = tostring(getgenv().MasteryConfig.DistanceOffset)
DistanceInput.Font = Enum.Font.GothamBold
DistanceInput.TextSize = 10
DistanceInput.TextColor3 = Color3.fromRGB(255, 100, 150)
DistanceInput.ClearTextOnFocus = false
DistanceInput.Active = true
DistanceInput.Selectable = true
DistanceInput.Parent = TabSettings

local DistCorner = Instance.new("UICorner")
DistCorner.CornerRadius = UDim.new(0, 4)
DistCorner.Parent = DistanceInput

local DistStroke = Instance.new("UIStroke")
DistStroke.Color = Color3.fromRGB(15, 60, 90)
DistStroke.Thickness = 1
DistStroke.Parent = DistanceInput

-- Fruit/Gun Click Interval Config inside TabSettings
local FruitGunClickLabel = Instance.new("TextLabel")
FruitGunClickLabel.Size = UDim2.new(0, 210, 0, 20)
FruitGunClickLabel.Position = UDim2.new(0, 0, 0, 114)
FruitGunClickLabel.BackgroundTransparency = 1
FruitGunClickLabel.Text = "Tốc độ click Fruit/Gun (giây):"
FruitGunClickLabel.Font = Enum.Font.GothamMedium
FruitGunClickLabel.TextSize = 9
FruitGunClickLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
FruitGunClickLabel.TextXAlignment = Enum.TextXAlignment.Left
FruitGunClickLabel.Active = false
FruitGunClickLabel.Selectable = false
FruitGunClickLabel.Parent = TabSettings

local FruitGunClickInput = Instance.new("TextBox")
FruitGunClickInput.Size = UDim2.new(0, 65, 0, 20)
FruitGunClickInput.Position = UDim2.new(0, 215, 0, 114)
FruitGunClickInput.BackgroundColor3 = Color3.fromRGB(35, 25, 30)
FruitGunClickInput.BorderSizePixel = 0
FruitGunClickInput.Text = tostring(getgenv().MasteryConfig.FruitGunClickInterval or 0.5)
FruitGunClickInput.Font = Enum.Font.GothamBold
FruitGunClickInput.TextSize = 10
FruitGunClickInput.TextColor3 = Color3.fromRGB(255, 100, 150)
FruitGunClickInput.ClearTextOnFocus = false
FruitGunClickInput.Active = true
FruitGunClickInput.Selectable = true
FruitGunClickInput.Parent = TabSettings

local FruitGunClickCorner = Instance.new("UICorner")
FruitGunClickCorner.CornerRadius = UDim.new(0, 4)
FruitGunClickCorner.Parent = FruitGunClickInput

local FruitGunClickStroke = Instance.new("UIStroke")
FruitGunClickStroke.Color = Color3.fromRGB(150, 60, 90)
FruitGunClickStroke.Thickness = 1
FruitGunClickStroke.Parent = FruitGunClickInput

-- Auto Hop On Player Button
local AutoHopPlayerBtn = Instance.new("TextButton")
AutoHopPlayerBtn.Size = UDim2.new(0, 280, 0, 22)
AutoHopPlayerBtn.Position = UDim2.new(0, 0, 0, 140)
AutoHopPlayerBtn.BackgroundColor3 = Color3.fromRGB(40, 30, 35)
AutoHopPlayerBtn.Text = "HOP KHI CÓ NGƯỜI XUNG QUANH: TẮT"
AutoHopPlayerBtn.Font = Enum.Font.GothamBold
AutoHopPlayerBtn.TextSize = 8
AutoHopPlayerBtn.TextColor3 = Color3.fromRGB(180, 180, 180)
AutoHopPlayerBtn.Parent = TabSettings

local AutoHopPlayerCorner = Instance.new("UICorner")
AutoHopPlayerCorner.CornerRadius = UDim.new(0, 4)
AutoHopPlayerCorner.Parent = AutoHopPlayerBtn

local AutoHopPlayerStroke = Instance.new("UIStroke")
AutoHopPlayerStroke.Color = Color3.fromRGB(100, 50, 80)
AutoHopPlayerStroke.Thickness = 1
AutoHopPlayerStroke.Parent = AutoHopPlayerBtn

-- ==========================================
--          MONSTER HP BAR (FIXED BOTTOM)
-- ==========================================
local Divider = Instance.new("Frame")
Divider.Size = UDim2.new(1, -30, 0, 1)
Divider.Position = UDim2.new(0, 15, 0, 247)
Divider.BackgroundColor3 = Color3.fromRGB(50, 40, 50)
Divider.BorderSizePixel = 0
Divider.Active = false
Divider.Selectable = false
Divider.Parent = Window

local MonsterHpLabel = Instance.new("TextLabel")
MonsterHpLabel.Size = UDim2.new(1, -30, 0, 14)
MonsterHpLabel.Position = UDim2.new(0, 15, 0, 251)
MonsterHpLabel.BackgroundTransparency = 1
MonsterHpLabel.Text = "Quái: Chưa có | Máu: N/A"
MonsterHpLabel.Font = Enum.Font.GothamMedium
MonsterHpLabel.TextSize = 9
MonsterHpLabel.TextColor3 = Color3.fromRGB(240, 240, 240)
MonsterHpLabel.TextXAlignment = Enum.TextXAlignment.Left
MonsterHpLabel.Active = false
MonsterHpLabel.Selectable = false
MonsterHpLabel.Parent = Window

local HPBarContainer = Instance.new("Frame")
HPBarContainer.Name = "HPBarContainer"
HPBarContainer.Size = UDim2.new(1, -30, 0, 6)
HPBarContainer.Position = UDim2.new(0, 15, 0, 267)
HPBarContainer.BackgroundColor3 = Color3.fromRGB(40, 25, 30)
HPBarContainer.BorderSizePixel = 0
HPBarContainer.Active = false
HPBarContainer.Selectable = false
HPBarContainer.Parent = Window

local HPBarCorner = Instance.new("UICorner")
HPBarCorner.CornerRadius = UDim.new(0.5, 0)
HPBarCorner.Parent = HPBarContainer

local HPBarFill = Instance.new("Frame")
HPBarFill.Name = "HPBarFill"
HPBarFill.Size = UDim2.new(0, 0, 1, 0)
HPBarFill.BackgroundColor3 = Color3.fromRGB(255, 100, 150)
HPBarFill.BorderSizePixel = 0
HPBarFill.Active = false
HPBarFill.Selectable = false
HPBarFill.Parent = HPBarContainer

local HPFillCorner = Instance.new("UICorner")
HPFillCorner.CornerRadius = UDim.new(0.5, 0)
HPFillCorner.Parent = HPBarFill

-- ==========================================
--          TAB CLICKS AND DYNAMICS
-- ==========================================
local function selectTab(tabName)
    TabFarm.Visible = (tabName == "Farm")
    TabSkills.Visible = (tabName == "Skills")
    TabSettings.Visible = (tabName == "Settings")
    
    TabFarmBtn.BackgroundColor3 = (tabName == "Farm") and Color3.fromRGB(255, 100, 150) or Color3.fromRGB(30, 20, 25)
    TabFarmBtn.TextColor3 = (tabName == "Farm") and Color3.fromRGB(255, 255, 255) or Color3.fromRGB(180, 180, 180)
    TabFarmStroke.Color = (tabName == "Farm") and Color3.fromRGB(255, 100, 150) or Color3.fromRGB(100, 50, 70)
    
    TabSkillsBtn.BackgroundColor3 = (tabName == "Skills") and Color3.fromRGB(255, 100, 150) or Color3.fromRGB(30, 20, 25)
    TabSkillsBtn.TextColor3 = (tabName == "Skills") and Color3.fromRGB(255, 255, 255) or Color3.fromRGB(180, 180, 180)
    TabSkillsStroke.Color = (tabName == "Skills") and Color3.fromRGB(255, 100, 150) or Color3.fromRGB(100, 50, 70)
    
    TabSettingsBtn.BackgroundColor3 = (tabName == "Settings") and Color3.fromRGB(255, 100, 150) or Color3.fromRGB(30, 20, 25)
    TabSettingsBtn.TextColor3 = (tabName == "Settings") and Color3.fromRGB(255, 255, 255) or Color3.fromRGB(180, 180, 180)
    TabSettingsStroke.Color = (tabName == "Settings") and Color3.fromRGB(255, 100, 150) or Color3.fromRGB(100, 50, 70)
end

TabFarmBtn.MouseButton1Click:Connect(function() selectTab("Farm") end)
TabSkillsBtn.MouseButton1Click:Connect(function() selectTab("Skills") end)
TabSettingsBtn.MouseButton1Click:Connect(function() selectTab("Settings") end)

-- 5. INTERACTION AND DYNAMICS
-- Draggable GUI
local function makeDraggable(frame)
    local dragging = false
    local dragInput, dragStart, startPos
    local dragDistance = 0

    local function update(input)
        local delta = input.Position - dragStart
        frame.Position = UDim2.new(
            startPos.X.Scale, startPos.X.Offset + delta.X,
            startPos.Y.Scale, startPos.Y.Offset + delta.Y
        )
        Window.Position = UDim2.new(
            frame.Position.X.Scale, frame.Position.X.Offset + 66,
            frame.Position.Y.Scale, frame.Position.Y.Offset - 52
        )
    end

    frame.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            dragStart = input.Position
            startPos = frame.Position
            dragDistance = 0

            input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then
                    dragging = false
                    if dragDistance < 10 then
                        Window.Visible = not Window.Visible
                        pcall(function()
                            local s = Instance.new("Sound")
                            s.SoundId = "rbxassetid://9119712151"
                            s.Volume = 0.4
                            s.Parent = game:GetService("SoundService")
                            s:Play()
                            s.Ended:Connect(function() s:Destroy() end)
                        end)
                    end
                end
            end)
        end
    end)

    frame.InputChanged:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
            dragInput = input
        end
    end)

    local inputConn
    inputConn = UserInputService.InputChanged:Connect(function(input)
        if not ScreenGui or not ScreenGui.Parent then
            inputConn:Disconnect()
            return
        end
        if input == dragInput and dragging then
            if dragStart then
                dragDistance = (input.Position - dragStart).Magnitude
            end
            update(input)
        end
    end)
end

makeDraggable(IconButton)

-- Camera Lock zoom helper (Lock zoom to 0)
local function lockCameraZoom()
    pcall(function()
        LocalPlayer.CameraMode = Enum.CameraMode.LockFirstPerson
        LocalPlayer.CameraMaxZoomDistance = 0.5
        LocalPlayer.CameraMinZoomDistance = 0.5
    end)
end

local function unlockCameraZoom()
    pcall(function()
        LocalPlayer.CameraMode = Enum.CameraMode.Classic
        LocalPlayer.CameraMaxZoomDistance = 400
        LocalPlayer.CameraMinZoomDistance = 0.5
    end)
end

ScreenGui.Destroying:Connect(function()
    unlockCameraZoom()
end)

local function updateMainToggleUI()
    if getgenv().MasteryConfig.Enabled then
        ToggleButton.Text = "FARM MASTERY: BẬT"
        ToggleButton.BackgroundColor3 = Color3.fromRGB(15, 80, 50)
        ToggleButton.TextColor3 = Color3.fromRGB(150, 255, 150)
        ToggleStroke.Color = Color3.fromRGB(100, 255, 150)
        lockCameraZoom()
    else
        ToggleButton.Text = "FARM MASTERY: TẮT"
        ToggleButton.BackgroundColor3 = Color3.fromRGB(45, 30, 35)
        ToggleButton.TextColor3 = Color3.fromRGB(255, 255, 255)
        ToggleStroke.Color = Color3.fromRGB(150, 60, 90)
        unlockCameraZoom()
    end
end

-- Mastery Main Toggle
ToggleButton.MouseButton1Click:Connect(function()
    getgenv().MasteryConfig.Enabled = not getgenv().MasteryConfig.Enabled
    updateMainToggleUI()
    if getgenv().MasteryConfig.Enabled then
        showNotification("🍰 Đã kích hoạt Farm Mastery & Camera Lock!", Color3.fromRGB(100, 255, 150))
    else
        showNotification("🛑 Đã dừng Farm Mastery!", Color3.fromRGB(255, 100, 100))
    end
    saveSettings()
end)

-- Base Weapon Selector Toggles
local function updateBaseWeaponUI()
    if getgenv().MasteryConfig.BaseWeapon == "Melee" then
        MeleeBtn.BackgroundColor3 = Color3.fromRGB(255, 100, 150)
        MeleeBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
        SwordBtn.BackgroundColor3 = Color3.fromRGB(40, 30, 35)
        SwordBtn.TextColor3 = Color3.fromRGB(180, 180, 180)
    else
        SwordBtn.BackgroundColor3 = Color3.fromRGB(255, 100, 150)
        SwordBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
        MeleeBtn.BackgroundColor3 = Color3.fromRGB(40, 30, 35)
        MeleeBtn.TextColor3 = Color3.fromRGB(180, 180, 180)
    end
end

MeleeBtn.MouseButton1Click:Connect(function()
    getgenv().MasteryConfig.BaseWeapon = "Melee"
    updateBaseWeaponUI()
    saveSettings()
end)

SwordBtn.MouseButton1Click:Connect(function()
    getgenv().MasteryConfig.BaseWeapon = "Sword"
    updateBaseWeaponUI()
    saveSettings()
end)

-- Mastery Weapon Selector Toggles
local function updateMasteryWeaponUI()
    if getgenv().MasteryConfig.MasteryWeapon == "Fruit" then
        FruitBtn.BackgroundColor3 = Color3.fromRGB(255, 100, 150)
        FruitBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
        GunBtn.BackgroundColor3 = Color3.fromRGB(40, 30, 35)
        GunBtn.TextColor3 = Color3.fromRGB(180, 180, 180)
    else
        GunBtn.BackgroundColor3 = Color3.fromRGB(255, 100, 150)
        GunBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
        FruitBtn.BackgroundColor3 = Color3.fromRGB(40, 30, 35)
        FruitBtn.TextColor3 = Color3.fromRGB(180, 180, 180)
    end
end

FruitBtn.MouseButton1Click:Connect(function()
    getgenv().MasteryConfig.MasteryWeapon = "Fruit"
    updateMasteryWeaponUI()
    saveSettings()
end)

-- Farm Position Selector Toggles UI
local function updatePositionUI()
    local mode = getgenv().MasteryConfig.PositionMode
    AboveBtn.BackgroundColor3 = (mode == "Above") and Color3.fromRGB(255, 100, 150) or Color3.fromRGB(40, 30, 35)
    AboveBtn.TextColor3 = (mode == "Above") and Color3.fromRGB(255, 255, 255) or Color3.fromRGB(180, 180, 180)
    
    BehindBtn.BackgroundColor3 = (mode == "Behind") and Color3.fromRGB(255, 100, 150) or Color3.fromRGB(40, 30, 35)
    BehindBtn.TextColor3 = (mode == "Behind") and Color3.fromRGB(255, 255, 255) or Color3.fromRGB(180, 180, 180)
    
    BelowBtn.BackgroundColor3 = (mode == "Below") and Color3.fromRGB(255, 100, 150) or Color3.fromRGB(40, 30, 35)
    BelowBtn.TextColor3 = (mode == "Below") and Color3.fromRGB(255, 255, 255) or Color3.fromRGB(180, 180, 180)
end

AboveBtn.MouseButton1Click:Connect(function()
    getgenv().MasteryConfig.PositionMode = "Above"
    updatePositionUI()
    saveSettings()
end)

BehindBtn.MouseButton1Click:Connect(function()
    getgenv().MasteryConfig.PositionMode = "Behind"
    updatePositionUI()
    saveSettings()
end)

BelowBtn.MouseButton1Click:Connect(function()
    getgenv().MasteryConfig.PositionMode = "Below"
    updatePositionUI()
    saveSettings()
end)

GunBtn.MouseButton1Click:Connect(function()
    getgenv().MasteryConfig.MasteryWeapon = "Gun"
    updateMasteryWeaponUI()
    saveSettings()
end)

-- HP Input Validation (Dynamic Instant Update on Text Change)
local updatingHP = false
HPInput:GetPropertyChangedSignal("Text"):Connect(function()
    if updatingHP then return end
    updatingHP = true
    local cleanText = HPInput.Text:gsub("%D", "")
    if HPInput.Text ~= cleanText then
        HPInput.Text = cleanText
    end
    local val = tonumber(cleanText)
    if val then
        if val > 99 then val = 99 end
        getgenv().MasteryConfig.ThresholdHP = val
        saveSettings()
    end
    updatingHP = false
end)

-- Distance Input Validation (Dynamic Instant Update on Text Change)
local updatingDist = false
DistanceInput:GetPropertyChangedSignal("Text"):Connect(function()
    if updatingDist then return end
    updatingDist = true
    local cleanText = DistanceInput.Text:gsub("%D", "")
    if DistanceInput.Text ~= cleanText then
        DistanceInput.Text = cleanText
    end
    local val = tonumber(cleanText)
    if val then
        if val > 100 then val = 100 end
        getgenv().MasteryConfig.DistanceOffset = val
        saveSettings()
    end
    updatingDist = false
end)

-- Fruit/Gun Click Interval Validation (Decimal Filter)
local updatingClickInt = false
FruitGunClickInput:GetPropertyChangedSignal("Text"):Connect(function()
    if updatingClickInt then return end
    updatingClickInt = true
    local cleanText = FruitGunClickInput.Text:gsub("[^%d%.]", "")
    -- Ensure at most one decimal point
    local firstDot = cleanText:find("%.")
    if firstDot then
        local before = cleanText:sub(1, firstDot)
        local after = cleanText:sub(firstDot + 1):gsub("%.", "")
        cleanText = before .. after
    end
    if FruitGunClickInput.Text ~= cleanText then
        FruitGunClickInput.Text = cleanText
    end
    local val = tonumber(cleanText)
    if val then
        if val < 0.05 then val = 0.05 end -- Avoid crash/kick for extremely low values
        if val > 10 then val = 10 end
        getgenv().MasteryConfig.FruitGunClickInterval = val
        saveSettings()
    end
    updatingClickInt = false
end)

-- Skill Toggles Click Bindings
for _, key in ipairs(keysList) do
    local btn = skillButtons[key]
    -- Align visual button states to loaded configs
    local isEnabled = getgenv().MasteryConfig.Skills[key]
    if isEnabled then
        btn.BackgroundColor3 = Color3.fromRGB(15, 80, 50)
        btn.TextColor3 = Color3.fromRGB(255, 255, 255)
        btn:FindFirstChildOfClass("UIStroke").Color = Color3.fromRGB(100, 255, 150)
    else
        btn.BackgroundColor3 = Color3.fromRGB(40, 30, 35)
        btn.TextColor3 = Color3.fromRGB(150, 150, 150)
        btn:FindFirstChildOfClass("UIStroke").Color = Color3.fromRGB(100, 50, 80)
    end
    
    btn.MouseButton1Click:Connect(function()
        getgenv().MasteryConfig.Skills[key] = not getgenv().MasteryConfig.Skills[key]
        if getgenv().MasteryConfig.Skills[key] then
            btn.BackgroundColor3 = Color3.fromRGB(15, 80, 50)
            btn.TextColor3 = Color3.fromRGB(255, 255, 255)
            btn:FindFirstChildOfClass("UIStroke").Color = Color3.fromRGB(100, 255, 150)
        else
            btn.BackgroundColor3 = Color3.fromRGB(40, 30, 35)
            btn.TextColor3 = Color3.fromRGB(150, 150, 150)
            btn:FindFirstChildOfClass("UIStroke").Color = Color3.fromRGB(100, 50, 80)
        end
        saveSettings()
    end)
end

-- 5. SINGLE REGULAR ATTACK REGISTRATION LOGIC (GỬI TỪNG REMOTE ĐÁNH THƯỜNG MỘT)
local function LayHamHitGoc()
    if getsenv then
        for _, scriptInstance in ipairs(LocalPlayer.PlayerScripts:GetChildren()) do
            if scriptInstance:IsA("LocalScript") then
                local success, env = pcall(getsenv, scriptInstance)
                if success and env and env._G and env._G.SendHitsToServer then
                    return env._G.SendHitsToServer
                end
            end
        end
    end
    return nil
end

local function executeSingleRegularAttack(monster, targetPart)
    pcall(function()
        local hitFunction = LayHamHitGoc()
        local targetsList = {{monster, targetPart}}
        
        local replicated = game:GetService("ReplicatedStorage")
        local regAttack = replicated:FindFirstChild("Modules") and replicated.Modules:FindFirstChild("Net") and replicated.Modules.Net:FindFirstChild("RE/RegisterAttack")
        local regHit = replicated:FindFirstChild("Modules") and replicated.Modules:FindFirstChild("Net") and replicated.Modules.Net:FindFirstChild("RE/RegisterHit")
        
        if regAttack then
            regAttack:FireServer(0)
        end
        if hitFunction then
            pcall(function()
                hitFunction(targetPart, targetsList)
            end)
        elseif regHit then
            regHit:FireServer(targetPart, targetsList)
        end
    end)
end

-- Server Hop Helper Function
local function serverHop()
    local placeId = game.PlaceId
    
    pcall(function()
        local queueteleport = (syn and syn.queue_on_teleport)
            or queue_on_teleport
            or (fluxus and fluxus.queue_on_teleport)
        if queueteleport then
            queueteleport('loadstring(readfile("mastery_farm.lua"))()')
        end
    end)
    
    while true do
        local apiUrl = "https://games.roblox.com/v1/games/" .. placeId .. "/servers/Public?sortOrder=Desc&excludeFullGames=true&limit=100"
        
        local function ListServers(cursor)
            local raw = game:HttpGet(apiUrl .. ((cursor and "&cursor=" .. cursor) or ""))
            return HttpService:JSONDecode(raw)
        end
        
        local Server, Next
        local pageAttempts = 0
        local maxPages = 5
        
        pcall(function()
            repeat task.wait(0.5)
                pageAttempts = pageAttempts + 1
                local Servers = ListServers(Next)
                if Servers and Servers.data then
                    for _, s in pairs(Servers.data) do
                        if s.id ~= game.JobId and s.playing and s.maxPlayers and s.playing < (s.maxPlayers - 1) then
                            Server = s
                            break
                        end
                    end
                    Next = Servers.nextPageCursor
                end
            until Server or not Next or pageAttempts >= maxPages
        end)
        
        if Server then
            local teleportSuccess, teleportErr = pcall(function()
                local ReplicatedStorage = game:GetService("ReplicatedStorage")
                return ReplicatedStorage:WaitForChild("__ServerBrowser", 5):InvokeServer("teleport", Server.id)
            end)
            
            if not teleportSuccess then
                pcall(function()
                    TeleportService:TeleportToPlaceInstance(placeId, Server.id, LocalPlayer)
                end)
            end
            task.wait(10)
        else
            pcall(function()
                TeleportService:Teleport(placeId, LocalPlayer)
            end)
            task.wait(15)
        end
    end
end

-- Auto Set Team Helper Function
local function runAutoSetTeam()
    if not getgenv().MasteryConfig.AutoSetTeam then return end
    task.spawn(function()
        if not game:IsLoaded() then
            game.Loaded:Wait()
        end
        task.wait(5) -- Give game components time to initialize
        
        local teamName = "Pirates" -- Default team
        local commF = game:GetService("ReplicatedStorage"):WaitForChild("Remotes", 9e9):WaitForChild("CommF_", 9e9)
        
        print("[CakeMastery] Đang chọn team: " .. teamName .. "...")
        
        local success, result = pcall(function()
            return commF:InvokeServer("SetTeam", teamName)
        end)
        
        if success then
            print("[CakeMastery] Đã tự động chọn team " .. teamName .. " thành công!")
        else
            -- GUI Click fallback
            pcall(function()
                local playerGui = LocalPlayer:WaitForChild("PlayerGui", 5)
                local mainGui = playerGui:WaitForChild("Main", 3)
                local chooseTeam = mainGui:WaitForChild("ChooseTeam", 3)
                local container = chooseTeam:WaitForChild("Container", 2)
                local button = container:WaitForChild(teamName, 2):WaitForChild("Frame", 1):WaitForChild("ViewportFrame", 1):WaitForChild("TextButton", 1)
                
                if button then
                    for _, conn in pairs(getconnections(button.MouseButton1Click)) do
                        conn.Function()
                    end
                    print("[CakeMastery] Đã chọn team " .. teamName .. " qua GUI fallback!")
                end
            end)
        end
    end)
end

-- 6. PVP/FARM HELPERS: NEAREST GENERAL MONSTER LOOKUP
local function getOriginPosition()
    local pos = nil
    pcall(function()
        local myChar = getPlayerCharacter(LocalPlayer)
        local myRoot = myChar and (myChar:FindFirstChild("HumanoidRootPart") or myChar.PrimaryPart)
        if myRoot then
            pos = myRoot.Position
        end
    end)
    if not pos then
        pcall(function()
            pos = Workspace.CurrentCamera.CFrame.Position
        end)
    end
    return pos or Vector3.new(0, 0, 0)
end

local function getNearestMonster()
    local origin = getOriginPosition()
    local nearest = nil
    local minDistance = math.huge
    
    local enemies = Workspace:FindFirstChild("Enemies")
    if enemies then
        for _, enemy in ipairs(enemies:GetChildren()) do
            local eRoot = enemy:FindFirstChild("HumanoidRootPart") or enemy.PrimaryPart
            if eRoot then
                -- Bypasses dead monster models instantly if health goes to 0
                local eHum = enemy:FindFirstChildOfClass("Humanoid")
                local isAlive = true
                if eHum and eHum.Health <= 0 then
                    isAlive = false
                end
                
                if isAlive then
                    local distToMe = (origin - eRoot.Position).Magnitude
                    if distToMe < minDistance then
                        minDistance = distToMe
                        nearest = enemy
                    end
                end
            end
        end
    end
    return nearest
end

-- 7. EQUIP WEAPON HELPER
local function equipWeapon(weaponType)
    local char = getPlayerCharacter(LocalPlayer)
    if not char then return end
    local humanoid = char:FindFirstChildOfClass("Humanoid")
    if not humanoid then return end
    
    local tool = nil
    
    for _, t in ipairs(LocalPlayer.Backpack:GetChildren()) do
        if t:IsA("Tool") then
            local tooltip = t.ToolTip:lower()
            local name = t.Name:lower()
            local wType = weaponType:lower()
            
            if tooltip == wType or name == wType or 
               (wType == "fruit" and (tooltip == "blox fruit" or string.find(name, "fruit") or string.find(tooltip, "fruit"))) or
               (wType == "melee" and (tooltip == "melee" or name == "melee")) or
               (wType == "sword" and (tooltip == "sword" or name == "sword")) or
               (wType == "gun" and (tooltip == "gun" or name == "gun")) then
                tool = t
                break
            end
        end
    end
    
    if not tool then
        for _, t in ipairs(char:GetChildren()) do
            if t:IsA("Tool") then
                local tooltip = t.ToolTip:lower()
                local name = t.Name:lower()
                local wType = weaponType:lower()
                
                if tooltip == wType or name == wType or 
                   (wType == "fruit" and (tooltip == "blox fruit" or string.find(name, "fruit") or string.find(tooltip, "fruit"))) or
                   (wType == "melee" and (tooltip == "melee" or name == "melee")) or
                   (wType == "sword" and (tooltip == "sword" or name == "sword")) or
                   (wType == "gun" and (tooltip == "gun" or name == "gun")) then
                    tool = t
                    break
                end
            end
        end
    end
    
    if tool and tool.Parent ~= char then
        humanoid:EquipTool(tool)
    end
end

-- Check if the weapon matches active weapon requirements (prevent overkill during transitions)
local function isToolFullyEquipped(weaponType)
    local char = getPlayerCharacter(LocalPlayer)
    local tool = char and char:FindFirstChildOfClass("Tool")
    if not tool then return false end
    
    local tooltip = tool.ToolTip:lower()
    local name = tool.Name:lower()
    local wType = weaponType:lower()
    
    if tooltip == wType or name == wType or 
       (wType == "fruit" and (tooltip == "blox fruit" or string.find(name, "fruit") or string.find(tooltip, "fruit"))) or
       (wType == "melee" and (tooltip == "melee" or name == "melee")) or
       (wType == "sword" and (tooltip == "sword" or name == "sword")) or
       (wType == "gun" and (tooltip == "gun" or name == "gun")) then
        return true
    end
    return false
end

-- Kiểm tra tuyệt đối vũ khí trên tay có phải là Fruit/Gun hay không (Chặn hoàn toàn Melee/Sword)
local function isHoldingMasteryWeapon()
    local char = getPlayerCharacter(LocalPlayer)
    local tool = char and char:FindFirstChildOfClass("Tool")
    if not tool then return false end
    
    local tooltip = (tool.ToolTip or ""):lower()
    local name = (tool.Name or ""):lower()
    local masteryType = (getgenv().MasteryConfig.MasteryWeapon or ""):lower()
    
    -- Nếu là Melee hoặc Sword thì tuyệt đối trả về false
    if tooltip == "melee" or tooltip == "sword" or name == "melee" or name == "sword" or name == "combat" then
        return false
    end
    
    if masteryType == "fruit" then
        return tooltip == "blox fruit" or string.find(name, "fruit") or string.find(tooltip, "fruit")
    elseif masteryType == "gun" then
        return tooltip == "gun" or string.find(name, "gun") or string.find(tooltip, "gun")
    end
    return false
end

-- 8. UNLOCKED SKILL VERIFICATION SYSTEM
local function isSkillUnlocked(keyName)
    local main = LocalPlayer:FindFirstChild("PlayerGui") and LocalPlayer.PlayerGui:FindFirstChild("Main")
    local skillsFrame = main and main:FindFirstChild("Skills")
    if skillsFrame then
        local skillFrame = skillsFrame:FindFirstChild(keyName:upper())
        if not skillFrame then
            -- Fallback key scanning search
            for _, child in ipairs(skillsFrame:GetChildren()) do
                local keyLabel = child:FindFirstChild("Key") or child:FindFirstChildOfClass("TextLabel")
                if keyLabel and keyLabel.Text:upper() == keyName:upper() then
                    skillFrame = child
                    break
                end
            end
        end
        
        if skillFrame then
            -- If skill is locked, Title contains "Mastery XXX" instead of skill name
            local titleLabel = skillFrame:FindFirstChild("Title") or skillFrame:FindFirstChild("SkillName")
            if titleLabel then
                local text = titleLabel.Text:lower()
                if string.find(text, "mastery") or string.find(text, "lock") or string.find(text, "req") then
                    return false
                end
            end
            
            -- Check for visible Lock icon overlays
            for _, child in ipairs(skillFrame:GetChildren()) do
                local cName = child.Name:lower()
                if (string.find(cName, "lock") or string.find(cName, "locked")) and (child:IsA("GuiObject") and child.Visible) then
                    return false
                end
            end
            
            return true
        end
    end
    return true -- Default fallback to avoid locking skills if UI has streaming lag
end

-- Print weapon mastery info to developer console
local function printWeaponMasteryInfo(weaponType)
    pcall(function()
        local commF = game:GetService("ReplicatedStorage"):FindFirstChild("Remotes") and game:GetService("ReplicatedStorage").Remotes:FindFirstChild("CommF_")
        if not commF then return end
        
        local inventory = commF:InvokeServer("getInventory")
        if type(inventory) ~= "table" then return end
        
        local equippedName = nil
        local equippedMastery = 0
        
        -- Find the tool name currently equipped or match by type
        local char = getPlayerCharacter(LocalPlayer)
        local tool = char and char:FindFirstChildOfClass("Tool")
        
        if tool then
            -- Match details for the equipped tool
            for _, item in pairs(inventory) do
                if type(item) == "table" and item.Name == tool.Name then
                    equippedName = item.Name
                    equippedMastery = item.Mastery or 0
                    break
                end
            end
        end
        
        if not equippedName then
            -- Fallback: match by type
            for _, item in pairs(inventory) do
                if type(item) == "table" and item.Type and item.Type:lower() == weaponType:lower() then
                    equippedName = item.Name
                    equippedMastery = item.Mastery or 0
                    break
                end
            end
        end
        
        if equippedName then
            print(string.format("\n[CakeMastery Debug] --- THÔNG TIN VŨ KHÍ %s ---", weaponType:upper()))
            print(string.format("[CakeMastery Debug] Tên vũ khí: %s | Mastery hiện tại: %s", tostring(equippedName), tostring(equippedMastery)))
            
            -- Inspect skills frame in PlayerGui
            local main = LocalPlayer:FindFirstChild("PlayerGui") and LocalPlayer.PlayerGui:FindFirstChild("Main")
            local skillsFrame = main and main:FindFirstChild("Skills")
            if skillsFrame then
                print("[CakeMastery Debug] Danh sách chiêu thức và yêu cầu mastery:")
                for _, child in ipairs(skillsFrame:GetChildren()) do
                    if child:IsA("GuiObject") then
                        local keyText = child.Name
                        local titleLabel = child:FindFirstChild("Title") or child:FindFirstChild("SkillName")
                        local skillName = titleLabel and titleLabel.Text or "N/A"
                        
                        -- Determine unlock status
                        local isLocked = false
                        if string.find(skillName:lower(), "mastery") or string.find(skillName:lower(), "lock") or string.find(skillName:lower(), "req") then
                            isLocked = true
                        end
                        for _, sub in ipairs(child:GetChildren()) do
                            if string.find(sub.Name:lower(), "lock") and (sub:IsA("GuiObject") and sub.Visible) then
                                isLocked = true
                            end
                        end
                        
                        local status = isLocked and "🔴 CHƯA MỞ KHÓA (Yêu cầu Mastery ở tên chiêu)" or "🟢 ĐÃ MỞ KHÓA"
                        print(string.format("  - Chiêu [%s]: %s (%s)", keyText, skillName, status))
                    end
                end
            else
                print("[CakeMastery Debug] Không tìm thấy Skills GUI của game!")
            end
            print("[CakeMastery Debug] -----------------------------------------------\n")
        end
    end)
end

-- 9. SMART OBSERVATION (KEN) HAKI STATE DETECTOR
local function isKenActive()
    local char = getPlayerCharacter(LocalPlayer)
    if char then
        for _, child in ipairs(char:GetChildren()) do
            local nameLower = child.Name:lower()
            if string.find(nameLower, "ken") or string.find(nameLower, "observation") or string.find(nameLower, "instinct") then
                return true
            end
        end
    end

    for attr, val in pairs(LocalPlayer:GetAttributes()) do
        local attrLower = attr:lower()
        if (string.find(attrLower, "ken") or string.find(attrLower, "observation") or string.find(attrLower, "instinct")) and type(val) == "boolean" then
            if val == true then
                return true
            end
        end
    end

    for _, effect in ipairs(Lighting:GetChildren()) do
        if effect:IsA("ColorCorrectionEffect") then
            local nameLower = effect.Name:lower()
            if string.find(nameLower, "ken") or string.find(nameLower, "observation") or string.find(nameLower, "instinct") then
                return true
            end
        end
    end

    return false
end

-- 10. AUTO HAKI THREAD (Buso & Ken)
task.spawn(function()
    local lastKenTime = 0
    while ScreenGui and ScreenGui.Parent do
        task.wait(0.5)
        if getgenv().MasteryConfig.Enabled then
            pcall(function()
                local char = getPlayerCharacter(LocalPlayer)
                if not char then return end
                
                -- Buso Haki (Armament)
                if not char:FindFirstChild("HasBuso") then
                    local replicated = game:GetService("ReplicatedStorage")
                    local commF = replicated:FindFirstChild("Remotes") and replicated.Remotes:FindFirstChild("CommF_")
                    if commF then
                        commF:InvokeServer("Buso")
                    end
                end
                
                -- Ken Haki (Observation)
                if tick() - lastKenTime > 1.0 then
                    lastKenTime = tick()
                    if not isKenActive() then
                        local replicated = game:GetService("ReplicatedStorage")
                        local commE = replicated:FindFirstChild("Remotes") and replicated.Remotes:FindFirstChild("CommE")
                        if commE then
                            commE:FireServer("Ken", true)
                        end
                    end
                end
            end)
        end
    end
end)

-- 10.5 AUTO RACE V4 AWAKEN THREAD
task.spawn(function()
    local VirtualInputManager = game:GetService("VirtualInputManager")
    while ScreenGui and ScreenGui.Parent do
        task.wait(1.0)
        if getgenv().MasteryConfig.Enabled and getgenv().MasteryConfig.AutoAwakenV4 then
            pcall(function()
                local char = getPlayerCharacter(LocalPlayer)
                if not char then return end
                
                local raceEnergy = char:FindFirstChild("RaceEnergy")
                if raceEnergy and raceEnergy.Value == 1 then
                    VirtualInputManager:SendKeyEvent(true, "Y", false, game)
                    task.wait(0.2)
                    VirtualInputManager:SendKeyEvent(false, "Y", false, game)
                end
            end)
        end
    end
end)

-- 10.6 AUTO HOP ON PLAYER DETECT THREAD
task.spawn(function()
    while ScreenGui and ScreenGui.Parent do
        task.wait(2.0)
        if getgenv().MasteryConfig.Enabled and getgenv().MasteryConfig.AutoHopOnPlayer then
            pcall(function()
                local myChar = getPlayerCharacter(LocalPlayer)
                local myRoot = myChar and myChar:FindFirstChild("HumanoidRootPart")
                
                if myRoot then
                    local detectRadius = getgenv().MasteryConfig.DetectPlayerRadius or 250
                    local foundPlayer = false
                    
                    for _, player in ipairs(Players:GetPlayers()) do
                        if player ~= LocalPlayer then
                            local char = getPlayerCharacter(player)
                            local root = char and char:FindFirstChild("HumanoidRootPart")
                            if root then
                                local distance = (myRoot.Position - root.Position).Magnitude
                                if distance <= detectRadius then
                                    foundPlayer = true
                                    print(string.format("[CakeMastery Detect] Phát hiện người chơi [%s] ở gần (%0.1f studs)! Chuẩn bị đổi server...", player.Name, distance))
                                    break
                                end
                            end
                        end
                    end
                    
                    if foundPlayer then
                        showNotification("⚠️ Phát hiện người chơi ở gần! Đang đổi server...", Color3.fromRGB(255, 50, 50))
                        task.wait(1.0)
                        serverHop()
                    end
                end
            end)
        end
    end
end)

-- 11. MAIN COMBAT CYCLE: GỬI TỪNG ĐÒN ĐÁNH THƯỜNG -> ĐỦ ĐIỀU KIỆN CHUYỂN SANG FRUIT/GUN SPAM SKILL
local lastRegularAttackTime = 0
local lastClickTime = 0
local lastSkillTime = 0
local lastLoggedWeapon = ""

-- Loop for Glide Movement, Camera CFrame, Single Regular Attacks, and Skill Spamming (Evaluates state every 0.02s)
task.spawn(function()
    while ScreenGui and ScreenGui.Parent do
        task.wait(0.02)
        
        if getgenv().MasteryConfig.Enabled then
            lockCameraZoom()
            
            local successLoop, err = pcall(function()
                local myChar = getPlayerCharacter(LocalPlayer)
                local myRoot = myChar and (myChar:FindFirstChild("HumanoidRootPart") or myChar.PrimaryPart)
                local myHumanoid = myChar and myChar:FindFirstChildOfClass("Humanoid")
                
                if myRoot and myHumanoid and myHumanoid.Health > 0 then
                    local monster = getNearestMonster()
                    
                    if monster then
                        local mRoot = monster:FindFirstChild("HumanoidRootPart") or monster.PrimaryPart
                        
                        if mRoot then
                            -- A. NOCLIP: Disable collisions
                            for _, part in ipairs(myChar:GetDescendants()) do
                                if part:IsA("BasePart") then
                                    part.CanCollide = false
                                end
                            end
                            
                            -- B. DYNAMIC GLIDE FLY (Speed 300 studs/sec) instead of instant teleport
                            local mode = getgenv().MasteryConfig.PositionMode
                            local dist = getgenv().MasteryConfig.DistanceOffset
                            local targetPos
                            
                            if mode == "Above" then
                                targetPos = mRoot.Position + Vector3.new(0, dist, 0)
                            elseif mode == "Behind" then
                                local look = mRoot.CFrame.LookVector
                                targetPos = mRoot.Position - (look * dist) + Vector3.new(0, 1.5, 0)
                            elseif mode == "Below" then
                                targetPos = mRoot.Position - Vector3.new(0, dist, 0)
                            end
                            
                            local currentPos = myRoot.Position
                            local toTarget = targetPos - currentPos
                            local distanceToTarget = toTarget.Magnitude
                            
                            local speed = 300
                            local stepDistance = speed * 0.02 -- Matches wait(0.02)
                            
                            local nextPosition
                            if distanceToTarget > stepDistance then
                                nextPosition = currentPos + (toTarget.Unit * stepDistance)
                            else
                                nextPosition = targetPos
                            end
                            
                            myRoot.CFrame = CFrame.new(nextPosition, mRoot.Position)
                            
                            myRoot.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
                            myRoot.AssemblyAngularVelocity = Vector3.new(0, 0, 0)
                            
                            -- C. LOCK CAMERA onto target (Always point screen center directly at monster)
                            local camera = Workspace.CurrentCamera
                            if camera then
                                camera.CFrame = CFrame.new(camera.CFrame.Position, mRoot.Position)
                            end
                            
                            -- D. CALCULATE TARGET HP PERCENTAGE DYNAMICALLY
                            local mHum = monster:FindFirstChildOfClass("Humanoid")
                            local monsterHPPercent = 100 -- Fallback if not streamed in yet
                            
                            if mHum and mHum.MaxHealth > 0 then
                                monsterHPPercent = (mHum.Health / mHum.MaxHealth) * 100
                                MonsterHpLabel.Text = string.format("Quái: %s | Máu: %.0f%%", monster.Name, monsterHPPercent)
                            else
                                MonsterHpLabel.Text = string.format("Quái: %s | Máu: Đang tải...", monster.Name)
                            end
                            
                            -- Update Visual Target HP Progress Bar with smooth animation
                            pcall(function()
                                TweenService:Create(HPBarFill, TweenInfo.new(0.05, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
                                    Size = UDim2.new(math.clamp(monsterHPPercent / 100, 0, 1), 0, 1, 0)
                                }):Play()
                            end)
                            
                            -- E. DECIDE WEAPON STATE
                            -- Nếu máu quái > ThresholdHP -> Dùng BaseWeapon (Melee/Sword) để làm mềm máu
                            -- Nếu máu quái <= ThresholdHP -> ĐỦ ĐIỀU KIỆN FARM -> Dùng MasteryWeapon (Fruit/Gun) để dứt điểm
                            local activeWeaponType = "Melee"
                            if monsterHPPercent > getgenv().MasteryConfig.ThresholdHP then
                                activeWeaponType = getgenv().MasteryConfig.BaseWeapon
                            else
                                activeWeaponType = getgenv().MasteryConfig.MasteryWeapon
                            end
                            
                            -- F. EQUIP CURRENT STAGE WEAPON
                            equipWeapon(activeWeaponType)
                            
                            -- Logs equipped weapon info to F9 Console on change
                            if activeWeaponType ~= lastLoggedWeapon then
                                lastLoggedWeapon = activeWeaponType
                                task.spawn(printWeaponMasteryInfo, activeWeaponType)
                            end
                            
                            -- G. COMBAT EXECUTION
                            if isToolFullyEquipped(activeWeaponType) then
                                local now = tick()
                                
                                if activeWeaponType == getgenv().MasteryConfig.BaseWeapon and (activeWeaponType == "Melee" or activeWeaponType == "Sword") then
                                    -- =========================================================================
                                    -- GIAI ĐOẠN 1: GỬI TỪNG REMOTE ĐÁNH THƯỜNG MỘT (BASE WEAPON)
                                    -- =========================================================================
                                    local regularAttackDelay = 0.15 -- Gửi từng đòn đánh thường một nhịp nhàng
                                    if now - lastRegularAttackTime >= regularAttackDelay then
                                        lastRegularAttackTime = now
                                        local targetPart = monster:FindFirstChild("Head") or mRoot
                                        executeSingleRegularAttack(monster, targetPart)
                                        
                                        local activeTool = myChar:FindFirstChildOfClass("Tool")
                                        if activeTool then
                                            pcall(function() activeTool:Activate() end)
                                        end
                                    end
                                    
                                elseif (activeWeaponType == "Fruit" or activeWeaponType == "Gun") and activeWeaponType == getgenv().MasteryConfig.MasteryWeapon then
                                    -- =========================================================================
                                    -- GIAI ĐOẠN 2: ĐỦ ĐIỀU KIỆN -> CHUYỂN SANG FRUIT/GUN VÀ SPAM LIÊN TỤC SKILL
                                    -- =========================================================================
                                    
                                    -- CHẶN TUYỆT ĐỐI: CHỈ SPAM SKILL KHI VŨ KHÍ TRÊN TAY THỰC SỰ LÀ FRUIT HOẶC GUN (KHÔNG PHẢI MELEE/SWORD)
                                    if isHoldingMasteryWeapon() then
                                        -- 1. SPAM TẤT CẢ CÁC CHIÊU THỨC (Z, X, C, V, F đối với Fruit / Z, X đối với Gun)
                                        local skillSpamDelay = 0.05 -- Tốc độ spam chiêu thức
                                        if now - lastSkillTime >= skillSpamDelay then
                                            lastSkillTime = now
                                            local allowedKeys = {}
                                            if activeWeaponType == "Fruit" then
                                                allowedKeys = {"Z", "X", "C", "V", "F"}
                                            elseif activeWeaponType == "Gun" then
                                                allowedKeys = {"Z", "X"}
                                            end
                                            
                                            local VirtualInput = game:GetService("VirtualInputManager")
                                            for _, key in ipairs(allowedKeys) do
                                                -- Kiểm tra lại từng phím: nếu đã bị chuyển về Melee/Sword hoặc quái đã chết -> DỪNG NGAY
                                                if not isHoldingMasteryWeapon() then break end
                                                if not monster or not monster.Parent then break end
                                                local currentHum = monster:FindFirstChildOfClass("Humanoid")
                                                if not currentHum or currentHum.Health <= 0 then break end
                                                
                                                if getgenv().MasteryConfig.Skills[key] and isSkillUnlocked(key) then
                                                    VirtualInput:SendKeyEvent(true, key, false, game)
                                                    task.wait(0.01)
                                                    VirtualInput:SendKeyEvent(false, key, false, game)
                                                end
                                            end
                                        end
                                        
                                        -- 2. CLICK TẤN CÔNG BẰNG FRUIT / GUN (CLICK BẮN ĐẠN / ĐÁNH THƯỜNG TRÁI)
                                        local clickInterval = getgenv().MasteryConfig.FruitGunClickInterval or 0.15
                                        if getgenv().MasteryConfig.Skills.Click and (now - lastClickTime >= clickInterval) then
                                            lastClickTime = now
                                            if camera and isHoldingMasteryWeapon() then
                                                local monsterPart = monster:FindFirstChild("Head") or monster:FindFirstChild("HumanoidRootPart") or mRoot
                                                if monsterPart then
                                                    local screenPos, onScreen = camera:WorldToViewportPoint(monsterPart.Position)
                                                    if onScreen then
                                                        local cx, cy = screenPos.X, screenPos.Y
                                                        local VirtualInput = game:GetService("VirtualInputManager")
                                                        VirtualInput:SendMouseButtonEvent(cx, cy, 0, true, game, 0)
                                                        task.wait(0.01)
                                                        VirtualInput:SendMouseButtonEvent(cx, cy, 0, false, game, 0)
                                                    end
                                                end
                                            end
                                            local activeTool = myChar:FindFirstChildOfClass("Tool")
                                            if activeTool and isHoldingMasteryWeapon() then
                                                pcall(function() activeTool:Activate() end)
                                            end
                                        end
                                    end
                                end
                            end
                        end
                    else
                        MonsterHpLabel.Text = "Quái: Không có | Đang chờ..."
                        pcall(function()
                            TweenService:Create(HPBarFill, TweenInfo.new(0.1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
                                Size = UDim2.new(0, 0, 1, 0)
                            }):Play()
                        end)
                    end
                end
            end)
            if not successLoop then
                warn("[AutoTPAim Warning]: Tải vòng lặp di chuyển/đánh thất bại: " .. tostring(err))
            end
        else
            unlockCameraZoom()
            MonsterHpLabel.Text = "Quái: Tắt Mastery | Đang chờ..."
            pcall(function()
                TweenService:Create(HPBarFill, TweenInfo.new(0.1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
                    Size = UDim2.new(0, 0, 1, 0)
                }):Play()
            end)
        end
    end
end)

-- Additional Settings Update and Toggles
local function updateAdditionalUI()
    -- Long Click
    if getgenv().MasteryConfig.LongClick then
        LongClickBtn.BackgroundColor3 = Color3.fromRGB(15, 80, 50)
        LongClickBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
        LongClickStroke.Color = Color3.fromRGB(100, 255, 150)
        LongClickBtn.Text = "LONG CLICK: BẬT"
    else
        LongClickBtn.BackgroundColor3 = Color3.fromRGB(40, 30, 35)
        LongClickBtn.TextColor3 = Color3.fromRGB(180, 180, 180)
        LongClickStroke.Color = Color3.fromRGB(100, 50, 80)
        LongClickBtn.Text = "LONG CLICK: TẮT"
    end
    
    -- Auto Hop
    if getgenv().MasteryConfig.AutoHop30M then
        AutoHopBtn.BackgroundColor3 = Color3.fromRGB(15, 80, 50)
        AutoHopBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
        AutoHopStroke.Color = Color3.fromRGB(100, 255, 150)
        AutoHopBtn.Text = "AUTO HOP 30P: BẬT"
    else
        AutoHopBtn.BackgroundColor3 = Color3.fromRGB(40, 30, 35)
        AutoHopBtn.TextColor3 = Color3.fromRGB(180, 180, 180)
        AutoHopStroke.Color = Color3.fromRGB(100, 50, 80)
        AutoHopBtn.Text = "AUTO HOP 30P: TẮT"
    end
    
    -- Auto Set Team
    if getgenv().MasteryConfig.AutoSetTeam then
        AutoTeamBtn.BackgroundColor3 = Color3.fromRGB(15, 80, 50)
        AutoTeamBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
        AutoTeamStroke.Color = Color3.fromRGB(100, 255, 150)
        AutoTeamBtn.Text = "AUTO TEAM: BẬT"
    else
        AutoTeamBtn.BackgroundColor3 = Color3.fromRGB(40, 30, 35)
        AutoTeamBtn.TextColor3 = Color3.fromRGB(180, 180, 180)
        AutoTeamStroke.Color = Color3.fromRGB(100, 50, 80)
        AutoTeamBtn.Text = "AUTO TEAM: TẮT"
    end

    -- Auto Awaken V4
    if getgenv().MasteryConfig.AutoAwakenV4 then
        AutoAwakenBtn.BackgroundColor3 = Color3.fromRGB(15, 80, 50)
        AutoAwakenBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
        AutoAwakenStroke.Color = Color3.fromRGB(100, 255, 150)
        AutoAwakenBtn.Text = "AUTO TỘC V4: BẬT"
    else
        AutoAwakenBtn.BackgroundColor3 = Color3.fromRGB(40, 30, 35)
        AutoAwakenBtn.TextColor3 = Color3.fromRGB(180, 180, 180)
        AutoAwakenStroke.Color = Color3.fromRGB(100, 50, 80)
        AutoAwakenBtn.Text = "AUTO TỘC V4: TẮT"
    end

    -- Auto Hop On Player
    if getgenv().MasteryConfig.AutoHopOnPlayer then
        AutoHopPlayerBtn.BackgroundColor3 = Color3.fromRGB(15, 80, 50)
        AutoHopPlayerBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
        AutoHopPlayerStroke.Color = Color3.fromRGB(100, 255, 150)
        AutoHopPlayerBtn.Text = "HOP KHI CÓ NGƯỜI XUNG QUANH: BẬT"
    else
        AutoHopPlayerBtn.BackgroundColor3 = Color3.fromRGB(40, 30, 35)
        AutoHopPlayerBtn.TextColor3 = Color3.fromRGB(180, 180, 180)
        AutoHopPlayerStroke.Color = Color3.fromRGB(100, 50, 80)
        AutoHopPlayerBtn.Text = "HOP KHI CÓ NGƯỜI XUNG QUANH: TẮT"
    end
end

LongClickBtn.MouseButton1Click:Connect(function()
    getgenv().MasteryConfig.LongClick = not getgenv().MasteryConfig.LongClick
    updateAdditionalUI()
    saveSettings()
end)

AutoHopBtn.MouseButton1Click:Connect(function()
    getgenv().MasteryConfig.AutoHop30M = not getgenv().MasteryConfig.AutoHop30M
    updateAdditionalUI()
    saveSettings()
end)

AutoTeamBtn.MouseButton1Click:Connect(function()
    getgenv().MasteryConfig.AutoSetTeam = not getgenv().MasteryConfig.AutoSetTeam
    updateAdditionalUI()
    saveSettings()
end)

AutoAwakenBtn.MouseButton1Click:Connect(function()
    getgenv().MasteryConfig.AutoAwakenV4 = not getgenv().MasteryConfig.AutoAwakenV4
    updateAdditionalUI()
    saveSettings()
end)

AutoHopPlayerBtn.MouseButton1Click:Connect(function()
    getgenv().MasteryConfig.AutoHopOnPlayer = not getgenv().MasteryConfig.AutoHopOnPlayer
    updateAdditionalUI()
    saveSettings()
end)

-- Auto Hop 30M Countdown Task
task.spawn(function()
    local startTime = tick()
    while ScreenGui and ScreenGui.Parent do
        task.wait(1.0)
        if getgenv().MasteryConfig.AutoHop30M then
            local elapsed = tick() - startTime
            local remaining = 1800 - elapsed
            if remaining <= 0 then
                HopCountdownLabel.Text = "Đang đổi server..."
                HopCountdownLabel.TextColor3 = Color3.fromRGB(255, 100, 150)
                serverHop()
                break
            else
                local minutes = math.floor(remaining / 60)
                local seconds = math.floor(remaining % 60)
                HopCountdownLabel.Text = string.format("Đổi SV sau: %02d:%02d", minutes, seconds)
                HopCountdownLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
            end
        else
            HopCountdownLabel.Text = "Auto Hop: Tắt"
            HopCountdownLabel.TextColor3 = Color3.fromRGB(120, 120, 120)
        end
    end
end)

-- Trigger Auto Set Team
runAutoSetTeam()

-- Restore settings view initially
updateBaseWeaponUI()
updateMasteryWeaponUI()
updatePositionUI()
updateAdditionalUI()
updateMainToggleUI()

print("[CakeMastery] Mastery Auto-farm with HP progress bar, skill unlock verification, and Auto-save loaded!")
showNotification("🍰 Mastery Farm & Targeted Click đã sẵn sàng!", Color3.fromRGB(255, 100, 150))
