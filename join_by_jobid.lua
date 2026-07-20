--[[
    ================================================================
                    JOBID TELEPORTER FOR MOBILE/ANDROID
             Smooth UI, Draggable, Floating Icon & Spam Join
    ================================================================
--]]

repeat task.wait() until game:IsLoaded()

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService      = game:GetService("TweenService")
local TeleportService   = game:GetService("TeleportService")
local UserInputService  = game:GetService("UserInputService")
local CoreGui           = game:GetService("CoreGui")

local Player = Players.LocalPlayer
local PlaceId = game.PlaceId

-- 1. DETERMINE PARENT GUI (CoreGui for exploits, fallback to PlayerGui)
local parentGui = Player:WaitForChild("PlayerGui")
pcall(function()
    if not game:GetService("RunService"):IsStudio() then
        parentGui = game:GetService("CoreGui") or parentGui
    end
end)

-- Destroy existing UI to avoid duplicates
local existing = parentGui:FindFirstChild("JobIdTeleporter")
if existing then existing:Destroy() end

-- 2. CREATE SCREEN GUI
local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "JobIdTeleporter"
ScreenGui.ResetOnSpawn = false
ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
ScreenGui.Parent = parentGui

-- 3. UTILITY FUNCTIONS (Dragging & Animate Press)
local function makeDraggable(gui, trigger)
    trigger = trigger or gui
    local dragging, dragInput, dragStart, startPosition

    local function update(input)
        local delta = input.Position - dragStart
        gui.Position = UDim2.new(
            startPosition.X.Scale, 
            startPosition.X.Offset + delta.X, 
            startPosition.Y.Scale, 
            startPosition.Y.Offset + delta.Y
        )
    end

    trigger.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            dragStart = input.Position
            startPosition = gui.Position

            input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then
                    dragging = false
                end
            end)
        end
    end)

    trigger.InputChanged:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
            dragInput = input
        end
    end)

    UserInputService.InputChanged:Connect(function(input)
        if input == dragInput and dragging then
            update(input)
        end
    end)
end

local function addPressEffect(button)
    button.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            TweenService:Create(button, TweenInfo.new(0.1, Enum.EasingStyle.Quad), {Size = UDim2.new(button.Size.X.Scale, button.Size.X.Offset - 4, button.Size.Y.Scale, button.Size.Y.Offset - 4)}):Play()
        end
    end)
    button.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            TweenService:Create(button, TweenInfo.new(0.1, Enum.EasingStyle.Quad), {Size = button.Size}):Play()
        end
    end)
end

-- 4. BUILD FLOATING TOGGLE ICON (🌀)
local FloatingIcon = Instance.new("ImageButton")
FloatingIcon.Name = "FloatingIcon"
FloatingIcon.Size = UDim2.new(0, 52, 0, 52)
FloatingIcon.Position = UDim2.new(0.1, 0, 0.2, 0)
FloatingIcon.BackgroundColor3 = Color3.fromRGB(18, 18, 30)
FloatingIcon.BackgroundTransparency = 0.15
FloatingIcon.Visible = false -- Starts hidden because Main Frame starts visible
FloatingIcon.Parent = ScreenGui

local IconCorner = Instance.new("UICorner", FloatingIcon)
IconCorner.CornerRadius = UDim.new(1, 0) -- Circle

local IconStroke = Instance.new("UIStroke", FloatingIcon)
IconStroke.Thickness = 2
IconStroke.Color = Color3.fromRGB(90, 80, 255)
IconStroke.Transparency = 0.3

local IconText = Instance.new("TextLabel", FloatingIcon)
IconText.Size = UDim2.new(1, 0, 1, 0)
IconText.BackgroundTransparency = 1
IconText.Text = "🌀"
IconText.TextSize = 26
IconText.Font = Enum.Font.GothamBold
IconText.TextColor3 = Color3.fromRGB(255, 255, 255)

makeDraggable(FloatingIcon)

-- Pulse Animation for Floating Icon
task.spawn(function()
    while FloatingIcon.Parent do
        if FloatingIcon.Visible then
            local tween1 = TweenService:Create(IconStroke, TweenInfo.new(1.2, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut), {Transparency = 0.8})
            tween1:Play()
            tween1.Completed:Wait()
            local tween2 = TweenService:Create(IconStroke, TweenInfo.new(1.2, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut), {Transparency = 0.2})
            tween2:Play()
            tween2.Completed:Wait()
        else
            task.wait(1)
        end
    end
end)

-- 5. BUILD MAIN FRAME
local MainFrame = Instance.new("Frame")
MainFrame.Name = "MainFrame"
MainFrame.Size = UDim2.new(0, 320, 0, 230)
MainFrame.Position = UDim2.new(0.5, -160, 0.5, -115) -- Centered
MainFrame.BackgroundColor3 = Color3.fromRGB(15, 15, 24)
MainFrame.BackgroundTransparency = 0.1
MainFrame.BorderSizePixel = 0
MainFrame.Parent = ScreenGui

local MainCorner = Instance.new("UICorner", MainFrame)
MainCorner.CornerRadius = UDim.new(0, 12)

local MainStroke = Instance.new("UIStroke", MainFrame)
MainStroke.Thickness = 2
MainStroke.Color = Color3.fromRGB(90, 80, 255)
MainStroke.Transparency = 0.2

-- Title Bar
local TitleBar = Instance.new("Frame")
TitleBar.Name = "TitleBar"
TitleBar.Size = UDim2.new(1, 0, 0, 40)
TitleBar.BackgroundColor3 = Color3.fromRGB(25, 25, 40)
TitleBar.BorderSizePixel = 0
TitleBar.Parent = MainFrame

local TitleCorner = Instance.new("UICorner", TitleBar)
TitleCorner.CornerRadius = UDim.new(0, 12)

-- Visual fix for bottom corners of Title Bar
local TitleFix = Instance.new("Frame")
TitleFix.Size = UDim2.new(1, 0, 0, 10)
TitleFix.Position = UDim2.new(0, 0, 1, -10)
TitleFix.BackgroundColor3 = Color3.fromRGB(25, 25, 40)
TitleFix.BorderSizePixel = 0
TitleFix.Parent = TitleBar

local TitleLabel = Instance.new("TextLabel")
TitleLabel.Size = UDim2.new(1, -50, 1, 0)
TitleLabel.Position = UDim2.new(0, 12, 0, 0)
TitleLabel.BackgroundTransparency = 1
TitleLabel.Text = "🚀 JOBID TELEPORTER"
TitleLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
TitleLabel.TextSize = 14
TitleLabel.Font = Enum.Font.GothamBold
TitleLabel.TextXAlignment = Enum.TextXAlignment.Left
TitleLabel.Parent = TitleBar

-- Minimize Button (X)
local CloseBtn = Instance.new("TextButton")
CloseBtn.Size = UDim2.new(0, 28, 0, 28)
CloseBtn.Position = UDim2.new(1, -34, 0.5, -14)
CloseBtn.BackgroundColor3 = Color3.fromRGB(220, 60, 80)
CloseBtn.Text = "X"
CloseBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
CloseBtn.TextSize = 13
CloseBtn.Font = Enum.Font.GothamBold
CloseBtn.Parent = TitleBar

local CloseCorner = Instance.new("UICorner", CloseBtn)
CloseCorner.CornerRadius = UDim.new(0, 6)

makeDraggable(MainFrame, TitleBar)

-- JobID Text Box Container
local BoxContainer = Instance.new("Frame")
BoxContainer.Size = UDim2.new(1, -24, 0, 42)
BoxContainer.Position = UDim2.new(0, 12, 0, 56)
BoxContainer.BackgroundColor3 = Color3.fromRGB(22, 22, 34)
BoxContainer.BorderSizePixel = 0
BoxContainer.Parent = MainFrame

local BoxCorner = Instance.new("UICorner", BoxContainer)
BoxCorner.CornerRadius = UDim.new(0, 8)

local BoxStroke = Instance.new("UIStroke", BoxContainer)
BoxStroke.Thickness = 1.5
BoxStroke.Color = Color3.fromRGB(90, 80, 255)
BoxStroke.Transparency = 0.6

-- Text Box for JobID Input
local TextBox = Instance.new("TextBox")
TextBox.Size = UDim2.new(1, -12, 1, 0)
TextBox.Position = UDim2.new(0, 6, 0, 0)
TextBox.BackgroundTransparency = 1
TextBox.PlaceholderText = "Tap to enter / paste JobID..."
TextBox.PlaceholderColor3 = Color3.fromRGB(110, 110, 130)
TextBox.TextColor3 = Color3.fromRGB(255, 255, 255)
TextBox.TextSize = 12
TextBox.Font = Enum.Font.GothamMedium
TextBox.Text = ""
TextBox.ClearTextOnFocus = true -- Standard Roblox property to clear text on focus
TextBox.Parent = BoxContainer

-- Double Guarantee: Clear previous JobID completely when user taps/clicks to focus TextBox
TextBox.Focused:Connect(function()
    TextBox.Text = ""
end)

-- Button: Join Server
local JoinBtn = Instance.new("TextButton")
JoinBtn.Size = UDim2.new(0.5, -16, 0, 38)
JoinBtn.Position = UDim2.new(0, 12, 0, 112)
JoinBtn.BackgroundColor3 = Color3.fromRGB(50, 150, 255)
JoinBtn.Text = "Join Server"
JoinBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
JoinBtn.TextSize = 13
JoinBtn.Font = Enum.Font.GothamBold
JoinBtn.Parent = MainFrame

local JoinCorner = Instance.new("UICorner", JoinBtn)
JoinCorner.CornerRadius = UDim.new(0, 8)

local JoinGradient = Instance.new("UIGradient", JoinBtn)
JoinGradient.Color = ColorSequence.new({
    ColorSequenceKeypoint.new(0, Color3.fromRGB(80, 170, 255)),
    ColorSequenceKeypoint.new(1, Color3.fromRGB(40, 110, 220))
})

-- Button: Spam Join
local SpamBtn = Instance.new("TextButton")
SpamBtn.Size = UDim2.new(0.5, -16, 0, 38)
SpamBtn.Position = UDim2.new(0.5, 4, 0, 112)
SpamBtn.BackgroundColor3 = Color3.fromRGB(45, 45, 60)
SpamBtn.Text = "Spam Join: OFF"
SpamBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
SpamBtn.TextSize = 13
SpamBtn.Font = Enum.Font.GothamBold
SpamBtn.Parent = MainFrame

local SpamCorner = Instance.new("UICorner", SpamBtn)
SpamCorner.CornerRadius = UDim.new(0, 8)

-- Status Label
local StatusLabel = Instance.new("TextLabel")
StatusLabel.Size = UDim2.new(1, -24, 0, 52)
StatusLabel.Position = UDim2.new(0, 12, 0, 162)
StatusLabel.BackgroundTransparency = 1
StatusLabel.Text = "💤 Status: Idle"
StatusLabel.TextColor3 = Color3.fromRGB(180, 180, 200)
StatusLabel.TextSize = 11
StatusLabel.Font = Enum.Font.GothamMedium
StatusLabel.TextWrapped = true
StatusLabel.TextYAlignment = Enum.TextYAlignment.Top
StatusLabel.Parent = MainFrame

addPressEffect(JoinBtn)
addPressEffect(SpamBtn)
addPressEffect(CloseBtn)

-- 6. TOGGLE VISIBILITY HANDLERS
CloseBtn.MouseButton1Click:Connect(function()
    MainFrame.Visible = false
    FloatingIcon.Visible = true
end)

FloatingIcon.MouseButton1Click:Connect(function()
    FloatingIcon.Visible = false
    MainFrame.Visible = true
end)

-- 7. TELEPORTATION & SPAM LOGIC
local spamActive = false
local spamThread = nil

local function updateStatus(text, color)
    StatusLabel.Text = "📡 Status: " .. text
    StatusLabel.TextColor3 = color or Color3.fromRGB(200, 200, 200)
end

local function cleanJobId(id)
    return string.gsub(id, "%s+", "")
end

local function attemptTeleport(jobId)
    if not jobId or jobId == "" or #jobId < 10 then
        return false, "Invalid JobID format"
    end

    -- Method 1: Blox Fruits Native __ServerBrowser Remote Function
    local nativeSuccess, nativeResult = pcall(function()
        local browser = ReplicatedStorage:FindFirstChild("__ServerBrowser")
        if browser then
            return browser:InvokeServer("teleport", jobId)
        end
        error("No Native Browser")
    end)

    if nativeSuccess then
        return true, "Requested native teleport!"
    end

    -- Method 2: Standard TeleportService Fallback
    local fallbackSuccess, fallbackErr = pcall(function()
        TeleportService:TeleportToPlaceInstance(PlaceId, jobId, Player)
    end)

    if fallbackSuccess then
        return true, "Requested fallback teleport!"
    end

    return false, tostring(fallbackErr or nativeResult or "Unknown error")
end

-- Single Join Click Handler
JoinBtn.MouseButton1Click:Connect(function()
    local jobId = cleanJobId(TextBox.Text)
    if jobId == "" then
        updateStatus("Please enter a JobID first!", Color3.fromRGB(255, 100, 100))
        return
    end

    updateStatus("Connecting to " .. string.sub(jobId, 1, 8) .. "...", Color3.fromRGB(255, 200, 50))
    
    local ok, msg = attemptTeleport(jobId)
    if ok then
        updateStatus("Teleport triggered successfully!", Color3.fromRGB(100, 255, 100))
    else
        updateStatus("Error: " .. msg, Color3.fromRGB(255, 80, 80))
    end
end)

-- Spam Join Toggle Handler
local function updateSpamUI(active)
    if active then
        SpamBtn.Text = "Spam Join: ON"
        SpamBtn.BackgroundColor3 = Color3.fromRGB(50, 200, 120) -- Green
    else
        SpamBtn.Text = "Spam Join: OFF"
        SpamBtn.BackgroundColor3 = Color3.fromRGB(45, 45, 60)   -- Grey/Blue
    end
end

local function startSpamLoop(jobId)
    if spamActive then return end
    spamActive = true
    updateSpamUI(true)

    spamThread = task.spawn(function()
        local attempt = 0
        while spamActive do
            attempt = attempt + 1
            updateStatus("Spamming... Attempt " .. attempt .. " to join " .. string.sub(jobId, 1, 8), Color3.fromRGB(255, 200, 50))
            
            local ok, msg = attemptTeleport(jobId)
            if ok then
                updateStatus("Teleport requested! Attempt #" .. attempt, Color3.fromRGB(100, 255, 150))
            else
                updateStatus("Attempt #" .. attempt .. " failed: " .. msg .. ". Retrying...", Color3.fromRGB(255, 80, 80))
            end
            
            task.wait(3.5) -- Cool down wait between spam attempts to avoid rate limiting / crashing
        end
    end)
end

local function stopSpamLoop()
    spamActive = false
    if spamThread then
        spamThread = nil
    end
    updateSpamUI(false)
    updateStatus("Spam Join stopped.", Color3.fromRGB(180, 180, 200))
end

SpamBtn.MouseButton1Click:Connect(function()
    if spamActive then
        stopSpamLoop()
    else
        local jobId = cleanJobId(TextBox.Text)
        if jobId == "" then
            updateStatus("Please enter a JobID first!", Color3.fromRGB(255, 100, 100))
            return
        end
        startSpamLoop(jobId)
    end
end)

-- Auto Rejoin on Prompt (Alternative Anti-Kick/Full-Server support)
pcall(function()
    local promptOverlay = game:GetService("CoreGui"):WaitForChild("RobloxPromptGui"):WaitForChild("promptOverlay")
    promptOverlay.ChildAdded:Connect(function(child)
        if child.Name == "ErrorPrompt" and spamActive then
            local jobId = cleanJobId(TextBox.Text)
            if jobId ~= "" then
                updateStatus("Teleport failed / prompt detected. Retrying in 3s...", Color3.fromRGB(255, 80, 80))
                task.wait(3)
                attemptTeleport(jobId)
            end
        end
    end)
end)

updateStatus("Ready. Put JobID and click Join.", Color3.fromRGB(150, 180, 255))
print("[JobIdTeleporter] UI Loaded successfully!")
