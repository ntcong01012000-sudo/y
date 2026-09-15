-- [[ ⚔️ AUTO HUNT MAGNETIZED MOBS & AUTO HOP 1-PLAYER SERVER ⚔️ ]]
-- Tác vụ:
-- 1. Tự động chọn phe (Pirates / Marines) khi vào game hoặc chưa có nhân vật.
-- 2. Tự động kích hoạt & duy trì Haki Vũ Trang (Buso Haki / Enhancement) liên tục.
-- 3. Quét thông minh TẤT CẢ các con quái có chứa từ khoá (trong Model.Name, Humanoid.DisplayName, Overhead Tag, BillboardGui, Attribute).
-- 4. Tại vị trí hiện tại: nếu có bất kỳ quái nào chứa từ khoá -> Tiêu diệt ngay bằng Fast Attack x4.
-- 5. Khi đến các vị trí mới:
--    - Nếu CÓ quái: KHÔNG DELAY 5s, lập tức lao vào đánh luôn!
--    - Nếu CHƯA CÓ quái: Đứng chờ 5s nhưng LIÊN TỤC quét mỗi 0.2s; quái vừa load/spawn trong 5s này là ngắt chờ và đánh ngay!
-- 6. Đi hết danh sách các điểm: Tự động đổi sang server 1 người qua Server Browser (__ServerBrowser & Games API).
-- 7. Chống kẹt: Chống kẹt bay (Watchdog), chống kẹt quái lag/bất tử (Blacklist có thời hạn, không bị bỏ qua vĩnh viễn).

repeat task.wait() until game:IsLoaded()

-- =========================================================================
-- ⚙️ CẤU HÌNH TÙY CHỈNH (CÓ THỂ CHỈNH SỬA Ở ĐÂY)
-- =========================================================================
local Config = {
    -- 0. Tự động chọn phe & Bật Haki
    AutoSetTeam = true,          -- Tự động chọn phe khi vào game hoặc chưa có nhân vật
    Team = "Pirates",            -- "Pirates" (Hải tặc) hoặc "Marines" (Hải quân)
    AutoBusoHaki = true,         -- Tự động bật Haki vũ trang (Buso / Enhancement)

    -- 1. Từ khoá tên quái cần săn (Bất kỳ quái nào CÓ CHỨA từ này đều sẽ bị đánh, không phân biệt hoa/thường)
    TargetKeywords = { "magnetized", "Magnetized" },
    
    -- 2. Tùy chỉnh di chuyển & bay
    FlySpeed = 250,              -- Tốc độ bay (studs/s)
    StandWaitTime = 5,           -- Thời gian dừng tối đa tại điểm nếu không có quái (giây)
    ScanRadius = 1200,           -- Bán kính quét quái xung quanh điểm (1200 studs bao quát toàn bộ đảo)
    
    -- 3. Tùy chỉnh chiến đấu (Combat)
    WeaponType = "Melee",        -- "Melee" (Võ) hoặc "Sword" (Kiếm)
    AttackHeightOffset = 15,     -- Độ cao lơ lửng trên đầu quái (15 studs đảm bảo 100% đánh trúng, quái không đánh lại được)
    FastAttackMultiplier = 4,    -- Đánh nhanh x4
    MobTimeoutSeconds = 30,      -- Tối đa 30s cho 1 quái nếu bị lag/bất tử
    
    -- 4. Tự động chuyển server 1 người sau khi hoàn thành
    AutoHopOnePlayer = true,     -- Tự động đổi server 1 người khi hết điểm
    MaxHopPages = 20,            -- Số trang tối đa duyệt trong Server Browser
    
    -- 5. Danh sách các điểm tuần tra (Đã tối ưu thứ tự lộ trình ngắn nhất)
    PatrolPoints = {
        Vector3.new(-5588.60, 18.40, 8371.20),  -- Điểm 1
        Vector3.new(-4871.80, 140.80, 4302.00), -- Điểm 2
        Vector3.new(-1256.00, 27.30, 4089.50),  -- Điểm 3
        Vector3.new(912.10, 5.90, 4512.30),     -- Điểm 4
        Vector3.new(5535.60, 71.10, 4819.60),   -- Điểm 5
        Vector3.new(5568.90, 71.10, 4020.00),   -- Điểm 6
        Vector3.new(5315.10, 19.80, 719.00),    -- Điểm 7
        Vector3.new(1088.70, 14.50, 1488.10),   -- Điểm 8
        Vector3.new(1284.10, 97.30, -1449.90),  -- Điểm 9
        Vector3.new(-1194.20, 12.20, -3265.50), -- Điểm 10
        Vector3.new(-1128.70, 12.20, -3071.10), -- Điểm 11
        Vector3.new(-5098.50, 279.30, -986.20), -- Điểm 12
        Vector3.new(-5340.90, 501.50, -389.80), -- Điểm 13
        Vector3.new(-4203.20, 1089.60, -446.10),-- Điểm 14
        Vector3.new(-1542.50, 53.70, 91.70),    -- Điểm 15
        Vector3.new(-2799.70, 58.90, 2153.50),  -- Điểm 16
        Vector3.new(-5961.10, 5471.40, 1890.30) -- Điểm 17
    }
}

-- =========================================================================
-- KHỞI TẠO DỊCH VỤ & BIẾN HỆ THỐNG
-- =========================================================================
local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TeleportService   = game:GetService("TeleportService")
local TweenService      = game:GetService("TweenService")
local RunService        = game:GetService("RunService")
local HttpService       = game:GetService("HttpService")
local UserInputService  = game:GetService("UserInputService")
local VirtualUser       = game:GetService("VirtualUser")
local CoreGui           = game:GetService("CoreGui")

local LP        = Players.LocalPlayer
local PlaceId   = game.PlaceId
local JobId     = game.JobId

_G.MagnetizedHuntID = (_G.MagnetizedHuntID or 0) + 1
local currentScriptID = _G.MagnetizedHuntID
local scriptActive = true

-- Dọn dẹp phiên bản UI và đối tượng cũ
local GUI_NAME = "MagnetizedHuntUI"
if CoreGui:FindFirstChild(GUI_NAME) then CoreGui[GUI_NAME]:Destroy() end
if LP:FindFirstChild("PlayerGui") and LP.PlayerGui:FindFirstChild(GUI_NAME) then
    LP.PlayerGui[GUI_NAME]:Destroy()
end
if workspace:FindFirstChild("MagHuntFlyPart") then workspace.MagHuntFlyPart:Destroy() end

local parentUI = pcall(function() return CoreGui end) and CoreGui or LP:WaitForChild("PlayerGui")

-- Kết nối Remote của Blox Fruits (CommF_, Fast Attack & Combat)
local Remotes = ReplicatedStorage:WaitForChild("Remotes", 5)
local CommF = Remotes and Remotes:FindFirstChild("CommF_")
local NetModules = ReplicatedStorage:FindFirstChild("Modules") and ReplicatedStorage.Modules:FindFirstChild("Net")
local RegisterAttack = NetModules and NetModules:FindFirstChild("RE/RegisterAttack")
local RegisterHit = NetModules and NetModules:FindFirstChild("RE/RegisterHit")

local CombatController = nil
pcall(function()
    local cf = require(LP.PlayerScripts:WaitForChild("CombatFramework", 4))
    CombatController = (getupvalues or debug.getupvalues)(cf)[2]
end)

-- =========================================================================
-- FLYPART ANCHORED & HỆ THỐNG NOCLIP KHÔNG RƠI NƯỚC
-- =========================================================================
local flyPart = Instance.new("Part")
flyPart.Name = "MagHuntFlyPart"
flyPart.Size = Vector3.new(2, 1, 2)
flyPart.Transparency = 1
flyPart.CanCollide = false
flyPart.Anchored = true
flyPart.Parent = workspace

local isFlying = false
local activeTween = nil

-- Noclip toàn thân & đồng bộ theo FlyPart
local noclipConn = RunService.Stepped:Connect(function()
    if not scriptActive or currentScriptID ~= _G.MagnetizedHuntID then return end
    local char = LP.Character
    if char then
        for _, p in ipairs(char:GetDescendants()) do
            if p:IsA("BasePart") then p.CanCollide = false end
        end
        local hrp = char:FindFirstChild("HumanoidRootPart")
        if hrp and isFlying then
            hrp.Velocity = Vector3.zero
            hrp.RotVelocity = Vector3.zero
            hrp.CFrame = flyPart.CFrame
        end
    end
end)

-- =========================================================================
-- GIAO DIỆN MINI HUD (TỐI ƯU CẢ CHO ANDROID & PC)
-- =========================================================================
local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = GUI_NAME
ScreenGui.ResetOnSpawn = false
ScreenGui.Parent = parentUI

-- Hàm kéo thả Touch / Mouse
local function makeDraggable(gui, handle)
    handle = handle or gui
    local drag, startPos, dragInput
    handle.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            drag = true; startPos = gui.Position; dragInput = input.Position
            input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then drag = false end
            end)
        end
    end)
    UserInputService.InputChanged:Connect(function(input)
        if drag and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
            local delta = input.Position - dragInput
            gui.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
        end
    end)
end

-- 1. Icon nổi (Floating Icon)
local FloatBtn = Instance.new("ImageButton")
FloatBtn.Size = UDim2.new(0, 44, 0, 44)
FloatBtn.Position = UDim2.new(0.04, 0, 0.45, 0)
FloatBtn.BackgroundColor3 = Color3.fromRGB(20, 22, 34)
FloatBtn.Image = "rbxassetid://6031075931"
FloatBtn.ImageColor3 = Color3.fromRGB(0, 230, 255)
FloatBtn.Visible = false
FloatBtn.Parent = ScreenGui
Instance.new("UICorner", FloatBtn).CornerRadius = UDim.new(1, 0)
local fbStroke = Instance.new("UIStroke", FloatBtn)
fbStroke.Color = Color3.fromRGB(0, 230, 255); fbStroke.Thickness = 2
makeDraggable(FloatBtn, FloatBtn)

-- 2. Khung HUD chính
local MainHud = Instance.new("Frame")
MainHud.Size = UDim2.new(0, 270, 0, 95)
MainHud.Position = UDim2.new(0.5, -135, 0.05, 0)
MainHud.BackgroundColor3 = Color3.fromRGB(15, 17, 26)
MainHud.BorderSizePixel = 0
MainHud.Parent = ScreenGui
Instance.new("UICorner", MainHud).CornerRadius = UDim.new(0, 8)
local hudStroke = Instance.new("UIStroke", MainHud)
hudStroke.Color = Color3.fromRGB(0, 220, 255); hudStroke.Thickness = 1.5

-- Header
local Header = Instance.new("Frame")
Header.Size = UDim2.new(1, 0, 0, 26)
Header.BackgroundColor3 = Color3.fromRGB(24, 28, 42)
Header.BorderSizePixel = 0
Header.Parent = MainHud
Instance.new("UICorner", Header).CornerRadius = UDim.new(0, 8)
makeDraggable(MainHud, Header)

local TitleLbl = Instance.new("TextLabel")
TitleLbl.Size = UDim2.new(1, -60, 1, 0); TitleLbl.Position = UDim2.new(0, 8, 0, 0)
TitleLbl.BackgroundTransparency = 1
TitleLbl.Text = "⚡ MAGNETIZED HUNTER PRO"
TitleLbl.TextColor3 = Color3.fromRGB(0, 230, 255)
TitleLbl.Font = Enum.Font.GothamBold; TitleLbl.TextSize = 10
TitleLbl.TextXAlignment = Enum.TextXAlignment.Left; TitleLbl.Parent = Header

local MinBtn = Instance.new("TextButton")
MinBtn.Size = UDim2.new(0, 22, 0, 20); MinBtn.Position = UDim2.new(1, -48, 0, 3)
MinBtn.BackgroundColor3 = Color3.fromRGB(40, 45, 60); MinBtn.Text = "—"
MinBtn.TextColor3 = Color3.fromRGB(255, 255, 255); MinBtn.Font = Enum.Font.GothamBold; MinBtn.TextSize = 11
MinBtn.Parent = Header
Instance.new("UICorner", MinBtn).CornerRadius = UDim.new(0, 4)

local CloseBtn = Instance.new("TextButton")
CloseBtn.Size = UDim2.new(0, 22, 0, 20); CloseBtn.Position = UDim2.new(1, -24, 0, 3)
CloseBtn.BackgroundColor3 = Color3.fromRGB(80, 25, 35); CloseBtn.Text = "✕"
CloseBtn.TextColor3 = Color3.fromRGB(255, 100, 100); CloseBtn.Font = Enum.Font.GothamBold; CloseBtn.TextSize = 10
CloseBtn.Parent = Header
Instance.new("UICorner", CloseBtn).CornerRadius = UDim.new(0, 4)

-- Nhãn trạng thái & mục tiêu
local StatusLbl = Instance.new("TextLabel")
StatusLbl.Size = UDim2.new(1, -16, 0, 20); StatusLbl.Position = UDim2.new(0, 8, 0, 30)
StatusLbl.BackgroundTransparency = 1
StatusLbl.Text = "Đang khởi động..."
StatusLbl.TextColor3 = Color3.fromRGB(255, 255, 255)
StatusLbl.Font = Enum.Font.Gotham; StatusLbl.TextSize = 10
StatusLbl.TextXAlignment = Enum.TextXAlignment.Left; StatusLbl.Parent = MainHud

local SubStatusLbl = Instance.new("TextLabel")
SubStatusLbl.Size = UDim2.new(1, -16, 0, 18); SubStatusLbl.Position = UDim2.new(0, 8, 0, 50)
SubStatusLbl.BackgroundTransparency = 1
SubStatusLbl.Text = "Vị trí: Bắt đầu tại chỗ"
SubStatusLbl.TextColor3 = Color3.fromRGB(150, 175, 210)
SubStatusLbl.Font = Enum.Font.Code; SubStatusLbl.TextSize = 9
SubStatusLbl.TextXAlignment = Enum.TextXAlignment.Left; SubStatusLbl.Parent = MainHud

-- Thanh máu quái mục tiêu
local HpBarBg = Instance.new("Frame")
HpBarBg.Size = UDim2.new(1, -16, 0, 14); HpBarBg.Position = UDim2.new(0, 8, 0, 72)
HpBarBg.BackgroundColor3 = Color3.fromRGB(30, 34, 48); HpBarBg.BorderSizePixel = 0
HpBarBg.Parent = MainHud
Instance.new("UICorner", HpBarBg).CornerRadius = UDim.new(0, 3)

local HpBarFill = Instance.new("Frame")
HpBarFill.Size = UDim2.new(0, 0, 1, 0)
HpBarFill.BackgroundColor3 = Color3.fromRGB(0, 220, 130); HpBarFill.BorderSizePixel = 0
HpBarFill.Parent = HpBarBg
Instance.new("UICorner", HpBarFill).CornerRadius = UDim.new(0, 3)

local HpBarText = Instance.new("TextLabel")
HpBarText.Size = UDim2.new(1, 0, 1, 0)
HpBarText.BackgroundTransparency = 1
HpBarText.Text = "Chờ mục tiêu..."
HpBarText.TextColor3 = Color3.fromRGB(255, 255, 255)
HpBarText.Font = Enum.Font.GothamBold; HpBarText.TextSize = 9
HpBarText.Parent = HpBarBg

MinBtn.MouseButton1Click:Connect(function() MainHud.Visible = false; FloatBtn.Visible = true end)
FloatBtn.MouseButton1Click:Connect(function() FloatBtn.Visible = false; MainHud.Visible = true end)
CloseBtn.MouseButton1Click:Connect(function()
    scriptActive = false
    isFlying = false
    if activeTween then activeTween:Cancel() end
    if noclipConn then noclipConn:Disconnect() end
    if flyPart then flyPart:Destroy() end
    ScreenGui:Destroy()
    print("🛑 [Magnetized Hunter] Đã dừng script.")
end)

local function setHUD(status, subStatus, hpPercent, hpString)
    if not MainHud or not MainHud.Parent then return end
    if status then StatusLbl.Text = status end
    if subStatus then SubStatusLbl.Text = subStatus end
    if hpPercent then
        hpPercent = math.clamp(hpPercent, 0, 1)
        HpBarFill.Size = UDim2.new(hpPercent, 0, 1, 0)
        if hpPercent > 0.5 then
            HpBarFill.BackgroundColor3 = Color3.fromRGB(0, 220, 130)
        elseif hpPercent > 0.25 then
            HpBarFill.BackgroundColor3 = Color3.fromRGB(255, 180, 50)
        else
            HpBarFill.BackgroundColor3 = Color3.fromRGB(255, 60, 60)
        end
    end
    if hpString then HpBarText.Text = hpString end
end

-- =========================================================================
-- HỆ THỐNG TỰ ĐỘNG CHỌN PHE & ĐỢI NHÂN VẬT (AUTO SET TEAM)
-- =========================================================================
local function ensureTeamAndCharacter()
    local function hasSelectedTeam()
        return LP.Team and LP.Team.Name ~= "" and LP.Team.Name ~= "Neutral"
    end
    
    local teamTarget = Config.Team or "Pirates"
    if teamTarget:lower():find("marine") then
        teamTarget = "Marines"
    else
        teamTarget = "Pirates"
    end
    
    if Config.AutoSetTeam and not hasSelectedTeam() then
        print(string.format("🏴‍☠️ [SetTeam] Chưa chọn phe! Đang tự động chọn phe: %s...", teamTarget))
        setHUD("🏴‍☠️ Đang tự động chọn phe...", "Chọn phe: " .. teamTarget .. "...")
        
        for attempt = 1, 12 do
            if hasSelectedTeam() then break end
            
            -- Cách 1: Remote CommF_
            pcall(function()
                if not CommF then
                    local rems = ReplicatedStorage:FindFirstChild("Remotes")
                    CommF = rems and rems:FindFirstChild("CommF_")
                end
                if CommF then
                    CommF:InvokeServer("SetTeam", teamTarget)
                end
            end)
            
            -- Cách 2: Click nút UI chọn phe
            pcall(function()
                local pg = LP:FindFirstChildOfClass("PlayerGui")
                if pg then
                    local mainGui = pg:FindFirstChild("Main")
                    local chooseTeam = mainGui and mainGui:FindFirstChild("ChooseTeam")
                    if chooseTeam and chooseTeam.Visible then
                        local container = chooseTeam:FindFirstChild("Container")
                        local tFrame = container and container:FindFirstChild(teamTarget)
                        if tFrame then
                            local btn = tFrame:FindFirstChildWhichIsA("TextButton", true)
                            if btn then
                                if firesignal then firesignal(btn.MouseButton1Click) else btn:Click() end
                            end
                        end
                    end
                end
            end)
            
            task.wait(0.5)
        end
    end
    
    -- Đợi nhân vật spawn hoàn chỉnh
    if not LP.Character or not LP.Character:FindFirstChild("HumanoidRootPart") then
        print("⏳ [Spawn] Đang đợi nhân vật xuất hiện trên bản đồ...")
        setHUD("⏳ Đang đợi nhân vật xuất hiện...", "Chờ spawn nhân vật...")
        local waitLimit = 0
        while (not LP.Character or not LP.Character:FindFirstChild("HumanoidRootPart")) and waitLimit < 25 do
            waitLimit = waitLimit + 1
            task.wait(0.5)
        end
    end
end

-- =========================================================================
-- HỆ THỐNG TỰ ĐỘNG BẬT & DUY TRÌ HAKI VŨ TRANG (BUSO HAKI)
-- =========================================================================
local function activateBuso()
    if not Config.AutoBusoHaki then return end
    local char = LP.Character
    if char and not char:FindFirstChild("HasBuso") then
        pcall(function()
            if not CommF then
                local rems = ReplicatedStorage:FindFirstChild("Remotes")
                CommF = rems and rems:FindFirstChild("CommF_")
            end
            if CommF then
                CommF:InvokeServer("Buso")
            end
        end)
    end
end

-- Luồng nền tự động kiểm tra và duy trì Haki vũ trang liên tục
task.spawn(function()
    while scriptActive and currentScriptID == _G.MagnetizedHuntID do
        task.wait(1.0)
        if Config.AutoBusoHaki then
            pcall(activateBuso)
        end
    end
end)

-- =========================================================================
-- HÀM TRANG BỊ VŨ KHÍ TỰ ĐỘNG (MELEE HOẶC SWORD)
-- =========================================================================
local function equipPreferredWeapon()
    local char = LP.Character
    if not char then return nil end
    local hum = char:FindFirstChildOfClass("Humanoid")
    if not hum or hum.Health <= 0 then return nil end
    
    local pref = Config.WeaponType or "Melee"
    
    -- Kiểm tra vũ khí đang cầm trên tay
    for _, tool in ipairs(char:GetChildren()) do
        if tool:IsA("Tool") then
            if pref == "Melee" and (tool.ToolTip == "Melee" or tool:FindFirstChild("CombatScript")) then
                return tool
            elseif tool.ToolTip == pref or tool.Name:lower():find(pref:lower()) then
                return tool
            end
        end
    end
    
    -- Lấy từ Backpack
    local bp = LP:FindFirstChild("Backpack")
    if bp then
        for _, tool in ipairs(bp:GetChildren()) do
            if tool:IsA("Tool") then
                if pref == "Melee" and (tool.ToolTip == "Melee" or tool:FindFirstChild("CombatScript")) then
                    hum:EquipTool(tool)
                    return tool
                elseif tool.ToolTip == pref or tool.Name:lower():find(pref:lower()) then
                    hum:EquipTool(tool)
                    return tool
                end
            end
        end
        -- Fallback: Cầm bất kỳ tool nào đầu tiên
        for _, tool in ipairs(bp:GetChildren()) do
            if tool:IsA("Tool") then
                hum:EquipTool(tool)
                return tool
            end
        end
    end
    return nil
end

-- =========================================================================
-- HỆ THỐNG BAY CHỐNG KẸT & TỰ PHỤC HỒI (TỐC ĐỘ 250)
-- =========================================================================
local function safeFlyTo(targetPos)
    local char = LP.Character
    local hrp = char and (char:FindFirstChild("HumanoidRootPart") or char.PrimaryPart)
    if not hrp then return false end
    
    local dist = (targetPos - hrp.Position).Magnitude
    if dist <= 8 then
        hrp.CFrame = CFrame.new(targetPos)
        return true
    end
    
    flyPart.CFrame = hrp.CFrame
    isFlying = true
    
    local duration = dist / Config.FlySpeed
    activeTween = TweenService:Create(flyPart, TweenInfo.new(duration, Enum.EasingStyle.Linear), {
        CFrame = CFrame.new(targetPos)
    })
    activeTween:Play()
    
    local finished = false
    local conn = activeTween.Completed:Connect(function() finished = true end)
    
    local lastCheckPos = hrp.Position
    local stuckSeconds = 0
    
    while not finished and scriptActive and currentScriptID == _G.MagnetizedHuntID do
        task.wait(0.2)
        
        -- Kiểm tra nhân vật còn sống không
        local curChar = LP.Character
        local curHrp = curChar and curChar:FindFirstChild("HumanoidRootPart")
        if not curHrp or not curChar:FindFirstChild("Humanoid") or curChar.Humanoid.Health <= 0 then
            if activeTween then activeTween:Cancel() end
            if conn then conn:Disconnect() end
            isFlying = false
            return false
        end
        
        -- Watchdog giải kẹt khi bay: nếu đứng im quá 2.5s mà chưa tới nơi
        if (curHrp.Position - lastCheckPos).Magnitude < 1.0 then
            stuckSeconds = stuckSeconds + 0.2
            if stuckSeconds >= 2.6 then
                print("⚠️ [Watchdog] Phát hiện kẹt khi bay! Đang đặt lại vị trí bay...")
                stuckSeconds = 0
                flyPart.CFrame = curHrp.CFrame * CFrame.new(0, 15, 0)
            end
        else
            stuckSeconds = 0
            lastCheckPos = curHrp.Position
        end
    end
    
    if conn then conn:Disconnect() end
    isFlying = false
    
    if LP.Character and LP.Character:FindFirstChild("HumanoidRootPart") then
        LP.Character.HumanoidRootPart.CFrame = CFrame.new(targetPos)
    end
    return true
end

-- =========================================================================
-- HỆ THỐNG QUÉT TỪ KHÓA ĐA NĂNG (TOÀN DIỆN: NAME, DISPLAYNAME, TAGS, ATTRIBUTES)
-- =========================================================================
local mobBlacklistTimeouts = {} -- Blacklist tạm thời theo thời gian, tránh bỏ qua vĩnh viễn

local function isBlacklisted(mob)
    if not mob then return false end
    local expireTime = mobBlacklistTimeouts[mob]
    if expireTime then
        if tick() < expireTime then
            return true
        else
            mobBlacklistTimeouts[mob] = nil
        end
    end
    return false
end

local function addBlacklist(mob, duration)
    if mob then
        mobBlacklistTimeouts[mob] = tick() + (duration or 20)
    end
end

-- Hàm trích xuất TOÀN BỘ các chuỗi tên, danh hiệu, thẻ hiển thị của quái
local function getAllMobStrings(mob)
    local results = {}
    if not mob then return results end
    
    -- 1. Tên Model
    if mob.Name and mob.Name ~= "" then
        table.insert(results, mob.Name)
    end
    
    -- 2. DisplayName của Humanoid
    local hum = mob:FindFirstChildOfClass("Humanoid")
    if hum and hum.DisplayName and hum.DisplayName ~= "" then
        table.insert(results, hum.DisplayName)
    end
    
    -- 3. Toàn bộ Attributes trên Model
    pcall(function()
        for attrName, attrVal in pairs(mob:GetAttributes()) do
            if type(attrVal) == "string" and attrVal ~= "" then
                table.insert(results, attrVal)
            end
        end
    end)
    
    -- 4. Toàn bộ TextLabel và StringValue (Overhead BillboardGui, Title, Mutation Tag)
    for _, desc in ipairs(mob:GetDescendants()) do
        if desc:IsA("TextLabel") and desc.Text and desc.Text ~= "" then
            table.insert(results, desc.Text)
        elseif desc:IsA("StringValue") and desc.Value and desc.Value ~= "" then
            table.insert(results, desc.Value)
        end
    end
    
    return results
end

-- Kiểm tra xem quái có chứa BẤT KỲ từ khoá nào không (So sánh substring không phân biệt hoa thường)
local function hasTargetKeyword(mob)
    local allStrings = getAllMobStrings(mob)
    for _, rawStr in ipairs(allStrings) do
        local lowerStr = rawStr:lower()
        for _, kw in ipairs(Config.TargetKeywords) do
            if kw and kw ~= "" then
                -- Tìm kiếm chuỗi con chính xác bằng plain text (tham số thứ 4 = true)
                if lowerStr:find(kw:lower(), 1, true) then
                    return true, rawStr
                end
            end
        end
    end
    return false, nil
end

-- Quét toàn bộ quái xung quanh tọa độ
local function scanTargetMobsAround(centerPos, radius)
    local targets = {}
    radius = radius or Config.ScanRadius
    
    local function evaluate(m)
        if not m or not m:IsA("Model") or isBlacklisted(m) then return end
        if m == LP.Character or Players:GetPlayerFromCharacter(m) then return end
        
        local isTarget, matchedName = hasTargetKeyword(m)
        if isTarget then
            local hum = m:FindFirstChildOfClass("Humanoid")
            local root = m:FindFirstChild("HumanoidRootPart") or m.PrimaryPart or m:FindFirstChild("Torso") or m:FindFirstChild("UpperTorso")
            
            if hum and hum.Health > 0 and root then
                local dist = (root.Position - centerPos).Magnitude
                if dist <= radius then
                    table.insert(targets, {
                        model = m,
                        name = matchedName or m.Name,
                        hum = hum,
                        root = root,
                        dist = dist
                    })
                end
            end
        end
    end
    
    -- 1. Quét sâu trong folder Enemies (kể cả sub-folder)
    local enemiesFolder = workspace:FindFirstChild("Enemies")
    if enemiesFolder then
        for _, e in ipairs(enemiesFolder:GetChildren()) do
            evaluate(e)
            -- Quét nếu có model con bên trong
            if e:IsA("Folder") or e:IsA("Model") then
                for _, sub in ipairs(e:GetChildren()) do
                    evaluate(sub)
                end
            end
        end
    end
    
    -- 2. Quét thêm trong toàn bộ Workspace (các NPC/quái ngoài folder Enemies)
    for _, obj in ipairs(workspace:GetChildren()) do
        if obj:IsA("Model") and obj ~= enemiesFolder and obj ~= LP.Character then
            evaluate(obj)
        end
    end
    
    -- Sắp xếp con gần nhất lên trước
    table.sort(targets, function(a, b) return a.dist < b.dist end)
    return targets
end

-- =========================================================================
-- HỆ THỐNG TIÊU DIỆT QUÁI (FAST ATTACK X4 & CHỐNG QUÁI BẤT TỬ)
-- =========================================================================
local function killTargetMob(targetData)
    local mob = targetData.model
    local hum = targetData.hum
    local root = targetData.root
    
    if not mob or not hum or hum.Health <= 0 or not root then return false end
    
    print(string.format("⚔️ [Combat] Phát hiện quái: %s (HP: %d/%d). Bắt đầu tấn công!", 
        targetData.name, hum.Health, hum.MaxHealth))
    
    -- Đảm bảo Haki đã bật trước khi đánh
    activateBuso()
    
    local startTime = tick()
    local lastHp = hum.Health
    local lastHpChangeTime = tick()
    
    while scriptActive and currentScriptID == _G.MagnetizedHuntID and mob.Parent and hum.Health > 0 do
        task.wait(0.02)
        
        local char = LP.Character
        local myHrp = char and (char:FindFirstChild("HumanoidRootPart") or char.PrimaryPart)
        if not myHrp or not char:FindFirstChild("Humanoid") or char.Humanoid.Health <= 0 then
            task.wait(1)
            return false
        end
        
        -- Cập nhật HUD
        local curHp = math.floor(hum.Health)
        local maxHp = math.max(math.floor(hum.MaxHealth), 1)
        local pct = curHp / maxHp
        setHUD("⚔️ Đang tiêu diệt: " .. targetData.name, 
               string.format("Khoảng cách: %.0f studs", (root.Position - myHrp.Position).Magnitude),
               pct, string.format("%d / %d (%.0f%%)", curHp, maxHp, pct * 100))
        
        -- Lơ lửng trên đầu quái cách AttackHeightOffset (15 studs chuẩn tầm đánh)
        local attackPos = root.Position + Vector3.new(0, Config.AttackHeightOffset, 0)
        myHrp.Velocity = Vector3.zero
        myHrp.RotVelocity = Vector3.zero
        myHrp.CFrame = CFrame.new(attackPos, root.Position)
        
        -- Trang bị vũ khí & kích hoạt Haki nếu mất
        local weapon = equipPreferredWeapon()
        activateBuso()
        
        local head = mob:FindFirstChild("Head") or root
        local hitList = {{mob, head}}
        
        -- Fast Attack x4
        if CombatController and CombatController.activeController then
            pcall(function()
                local ac = CombatController.activeController
                ac.hitboxMagnitude = 65
                ac.active = false
                ac.blocking = false
                ac.timeToNextAttack = 0
                ac:attack()
            end)
        end
        
        for _ = 1, math.clamp(Config.FastAttackMultiplier or 4, 1, 6) do
            if RegisterAttack then pcall(function() RegisterAttack:FireServer(0) end) end
            if RegisterHit then pcall(function() RegisterHit:FireServer(head, hitList) end) end
        end
        
        pcall(function() VirtualUser:Button1Down(Vector2.new(1280, 720)) end)
        if weapon then pcall(function() weapon:Activate() end) end
        
        -- Kiểm tra biến đổi máu
        if hum.Health < lastHp then
            lastHp = hum.Health
            lastHpChangeTime = tick()
        end
        
        -- Chống kẹt quái bất tử: Nếu quá MobTimeoutSeconds hoặc 12s máu không giảm tí nào
        if (tick() - lastHpChangeTime) >= 12 or (tick() - startTime) >= Config.MobTimeoutSeconds then
            warn(string.format("⚠️ [Combat Timeout] Quái %s không mất máu! Tạm dừng target trong 25 giây...", targetData.name))
            addBlacklist(mob, 25)
            break
        end
    end
    
    print(string.format("✅ [Combat] Đã hạ gục / giải quyết xong: %s", targetData.name))
    setHUD("✅ Đã tiêu diệt xong quái!", "Đang quét các con tiếp theo...", 0, "0 / 0 (0%)")
    task.wait(0.2)
    return true
end

-- Tiêu diệt tất cả quái mục tiêu xung quanh một vị trí
local function killAllTargetMobsAt(centerPos)
    while scriptActive and currentScriptID == _G.MagnetizedHuntID do
        local targets = scanTargetMobsAround(centerPos, Config.ScanRadius)
        if #targets == 0 then break end
        
        for _, mobData in ipairs(targets) do
            if not scriptActive then break end
            killTargetMob(mobData)
        end
        task.wait(0.2)
    end
end

-- =========================================================================
-- HỆ THỐNG ĐỔI SERVER 1 NGƯỜI (SERVER BROWSER & RETRY THÔNG MINH)
-- =========================================================================
local visitedJobIds = {}
visitedJobIds[JobId] = true
local isHopping = false

local function hopToOnePlayerServer()
    if isHopping then return end
    isHopping = true
    print("🌐 [Server Hop] Bắt đầu tìm kiếm server 1 người qua Server Browser...")
    setHUD("🌐 Đang quét tìm server 1 người...", "Dùng Server Browser API...", 0, "Chờ chuyển server...")
    
    task.spawn(function()
        local cursor = ""
        local page = 0
        local targetServer = nil
        local fallbackServer = nil
        
        while scriptActive and page < (Config.MaxHopPages or 20) do
            page = page + 1
            setHUD(string.format("🔍 Đang duyệt Server Browser (Trang %d)...", page), "Tìm server có đúng 1 người")
            
            local url = string.format("https://games.roblox.com/v1/games/%d/servers/Public?sortOrder=Asc&limit=100", PlaceId)
            if cursor ~= "" then url = url .. "&cursor=" .. cursor end
            
            local success, raw = pcall(function() return game:HttpGet(url) end)
            if success and raw then
                local data = nil
                pcall(function() data = HttpService:JSONDecode(raw) end)
                if data and data.data and #data.data > 0 then
                    for _, s in ipairs(data.data) do
                        local pl = tonumber(s.playing)
                        local maxP = tonumber(s.maxPlayers) or 12
                        local sid = tostring(s.id)
                        if sid ~= JobId and not visitedJobIds[sid] and pl and pl < maxP then
                            if pl == 1 then
                                targetServer = s
                                break
                            elseif pl > 1 and pl <= 3 and not fallbackServer then
                                fallbackServer = s
                            end
                        end
                    end
                    if targetServer then break end
                    if data.nextPageCursor and data.nextPageCursor ~= "null" and data.nextPageCursor ~= "" then
                        cursor = data.nextPageCursor
                    else
                        break
                    end
                else
                    break
                end
            end
            task.wait(0.2)
        end
        
        local chosen = targetServer or fallbackServer
        if chosen then
            visitedJobIds[tostring(chosen.id)] = true
            setHUD("🎯 Tìm thấy server 1 người!", "Đang kết nối qua __ServerBrowser...")
            print(string.format("🚀 [Server Hop] Chuyển đến server: %s (Người: %d)", chosen.id, chosen.playing))
            
            -- Bước 1: ReplicatedStorage.__ServerBrowser
            pcall(function()
                local sb = ReplicatedStorage:FindFirstChild("__ServerBrowser")
                if sb and sb:IsA("RemoteFunction") then
                    sb:InvokeServer("teleport", chosen.id)
                end
            end)
            
            -- Bước 2: TeleportService dự phòng
            task.wait(2.5)
            pcall(function()
                TeleportService:TeleportToPlaceInstance(PlaceId, chosen.id, LP)
            end)
            
            task.wait(7)
            isHopping = false
            setHUD("⚠️ Chưa kết nối được", "Đang thử lại server 1 người khác...")
            hopToOnePlayerServer()
        else
            isHopping = false
            setHUD("❌ Hết server 1 người", "Thử lại sau 3s...")
            task.wait(3)
            hopToOnePlayerServer()
        end
    end)
end

TeleportService.TeleportInitFailed:Connect(function(player)
    if player == LP then
        isHopping = false
        print("⚠️ [Server Hop] Teleport thất bại, tìm server khác ngay...")
        task.wait(1.5)
        hopToOnePlayerServer()
    end
end)

-- =========================================================================
-- QUY TRÌNH THỰC THI CHÍNH (MAIN WORKFLOW)
-- =========================================================================
task.spawn(function()
    print("🚀 [Magnetized Hunter] Khởi động quy trình tuần tra & săn quái...")
    
    -- ---------------------------------------------------------------------
    -- BƯỚC 0: TỰ ĐỘNG CHỌN PHE & CHỜ NHÂN VẬT SPAWN
    -- ---------------------------------------------------------------------
    ensureTeamAndCharacter()
    
    local char = LP.Character or LP.CharacterAdded:Wait()
    local hrp = char:WaitForChild("HumanoidRootPart", 10)
    if not hrp then
        setHUD("❌ Lỗi: Không tìm thấy nhân vật!", "Vui lòng hồi sinh và thử lại.")
        return
    end
    
    -- Kích hoạt Haki vũ trang ngay khi spawn
    activateBuso()
    
    -- ---------------------------------------------------------------------
    -- BƯỚC 1: QUÉT TẠI VỊ TRÍ HIỆN TẠI TRƯỚC TIÊN
    -- ---------------------------------------------------------------------
    setHUD("🔍 Đang quét vị trí ban đầu...", "Tìm quái mục tiêu xung quanh...")
    task.wait(0.5)
    
    local initialTargets = scanTargetMobsAround(hrp.Position, Config.ScanRadius)
    if #initialTargets > 0 then
        print(string.format("🎯 Tìm thấy %d quái mục tiêu tại vị trí ban đầu! Tiêu diệt ngay...", #initialTargets))
        killAllTargetMobsAt(hrp.Position)
    else
        print("ℹ️ Không có quái mục tiêu tại vị trí ban đầu. Bắt đầu di chuyển lộ trình...")
    end
    
    -- ---------------------------------------------------------------------
    -- BƯỚC 2: DUYỆT QUA CÁC ĐIỂM TUẦN TRA TRONG DANH SÁCH
    -- ---------------------------------------------------------------------
    local route = Config.PatrolPoints
    local totalPoints = #route
    
    for idx, targetPos in ipairs(route) do
        if not scriptActive then break end
        
        -- Bay đến điểm tiếp theo
        setHUD(string.format("✈️ Bay đến Điểm [%d/%d]", idx, totalPoints), 
               string.format("Tọa độ: X=%.0f, Y=%.0f, Z=%.0f", targetPos.X, targetPos.Y, targetPos.Z))
        print(string.format("✈️ [%d/%d] Đang bay đến Điểm (X: %.1f, Y: %.1f, Z: %.1f)...", 
            idx, totalPoints, targetPos.X, targetPos.Y, targetPos.Z))
        
        local success = safeFlyTo(targetPos)
        if not success then
            -- Nếu chết giữa đường, đợi hồi sinh và bật lại Haki
            local newChar = LP.Character or LP.CharacterAdded:Wait()
            newChar:WaitForChild("HumanoidRootPart", 10)
            activateBuso()
            task.wait(1)
            safeFlyTo(targetPos)
        end
        
        -- ĐÃ ĐẾN ĐIỂM MỚI: QUÉT QUÁI MỤC TIÊU XUNG QUANH
        setHUD(string.format("📍 Đã đến Điểm [%d/%d]", idx, totalPoints), "Đang quét quái mục tiêu...")
        task.wait(0.2)
        
        local immediateMobs = scanTargetMobsAround(targetPos, Config.ScanRadius)
        
        if #immediateMobs > 0 then
            -- CÓ QUÁI: KHÔNG DELAY 5S NỮA -> LAO VÀO ĐÁNH LUÔN!
            print(string.format("🔥 [Điểm %d] Phát hiện %d quái mục tiêu! KHÔNG DELAY 5s -> Đánh ngay!", idx, #immediateMobs))
            killAllTargetMobsAt(targetPos)
        else
            -- CHƯA CÓ QUÁI: CHỜ TỐI ĐA 5 GIÂY, NHƯNG LIÊN TỤC QUÉT MỖI 0.2S
            -- NẾU QUÁI VỪA SPAWN TRONG 5S NÀY THÌ NGẮT CHỜ VÀ ĐÁNH NGAY!
            print(string.format("⏳ [Điểm %d] Chưa thấy quái mục tiêu. Chờ tối đa %ds (quét liên tục)...", idx, Config.StandWaitTime))
            
            local foundWhileWaiting = false
            for tickCount = 1, Config.StandWaitTime * 5 do
                if not scriptActive then break end
                
                local remainingSec = math.ceil((Config.StandWaitTime * 5 - tickCount) / 5)
                setHUD(string.format("⏳ Điểm [%d/%d] - Quét quái...", idx, totalPoints), 
                       string.format("Chờ %d giây trước khi chuyển điểm...", remainingSec))
                
                task.wait(0.2)
                
                local scanAgain = scanTargetMobsAround(targetPos, Config.ScanRadius)
                if #scanAgain > 0 then
                    print(string.format("🔥 [Điểm %d] Quái vừa xuất hiện trong lúc chờ! Ngắt delay 5s -> Đánh luôn!", idx))
                    foundWhileWaiting = true
                    killAllTargetMobsAt(targetPos)
                    break
                end
            end
            
            if not foundWhileWaiting then
                print(string.format("➡️ [Điểm %d] Hết 5s không có quái mục tiêu. Chuyển sang điểm tiếp theo!", idx))
            end
        end
    end
    
    -- ---------------------------------------------------------------------
    -- BƯỚC 3: HOÀN THÀNH LỘ TRÌNH -> CHUYỂN SANG SERVER 1 NGƯỜI
    -- ---------------------------------------------------------------------
    if scriptActive and Config.AutoHopOnePlayer then
        print("🎉 [Hoàn thành] Đã đi hết toàn bộ các điểm! Bắt đầu đổi sang server 1 người...")
        setHUD("🎉 ĐÃ HOÀN THÀNH TẤT CẢ CÁC ĐIỂM!", "Đang chuẩn bị đổi server 1 người...")
        task.wait(1.5)
        hopToOnePlayerServer()
    end
end)

print("✅ [Magnetized Hunter] Script đã nạp thành công và đang chạy!")
