--[[
    Blox Fruits - Auto Farm Premium (Dưới Quái & Bay Đến Cổng 1-3)
    Được viết bởi: Antigravity AI
    Mô tả:
        1. Tự động kiểm tra và HỦY/ĐÓNG toàn bộ luồng hoạt động, sự kiện kết nối,
           vật thể phụ trợ, và UI của tất cả các script cũ chạy trước đó.
        2. Tab 1 (Farm):
           - Vị trí farm luôn ở DƯỚI QUÁI 50 studs (CFrame * CFrame.new(0, -50, 0)), kết hợp Noclip xuyên lòng đất.
           - Khoảng cách <= 500 studs: Dịch chuyển tức thời (TP) không có delay.
             Khoảng cách > 500 studs: Bay mượt tốc độ 300 studs/s.
           - Ưu tiên quái có MÁU ÍT nhất. Đang đánh con nào thì tập trung tiêu diệt xong mới đổi mục tiêu.
           - Lọc bỏ hoàn toàn quái có chữ "shadow" trong Model Name và DisplayName.
           - Tự động bật Haki Vũ Trang và Haki Quan Sát mỗi 1 giây.
           - Tự động trang bị Melee vũ khí khi chạy farm.
        3. Tab 2 (Portals):
           - Cho phép bay đến các Cổng từ 1 đến 3 với các tọa độ chính xác.
        4. Tối ưu hiệu năng UI: Sử dụng cơ chế Pool để tái sử dụng Gui Object,
           loại bỏ hoàn toàn hiện tượng tạo mới/hủy liên tục gây giật lag FPS (UI Lag).
--]]

-- ==================== HỆ THỐNG ĐÓNG/HỦY SCRIPT CŨ ====================
_G.AntigravityV2ID = (_G.AntigravityV2ID or 0) + 1
local scriptID = _G.AntigravityV2ID

-- Tăng ID của script FastAttack cũ để dừng vòng lặp của nó nếu đang chạy
_G.FastAttackID = (_G.FastAttackID or 0) + 1

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local CoreGui = game:GetService("CoreGui")
local LocalPlayer = Players.LocalPlayer

-- Ngắt kết nối các sự kiện noclip hoặc tween đang chạy dở của script cũ
if _G.AntigravityV2Noclip then
    pcall(function() _G.AntigravityV2Noclip:Disconnect() end)
    _G.AntigravityV2Noclip = nil
end

if _G.AntigravityV2Tween then
    pcall(function() _G.AntigravityV2Tween:Cancel() end)
    _G.AntigravityV2Tween = nil
end

-- Dọn dẹp sạch sẽ tài nguyên cũ (UI, ESP, BodyVelocity, Platform)
local function cleanupOldAssets()
    pcall(function()
        if CoreGui:FindFirstChild("AntigravityV2UI") then CoreGui.AntigravityV2UI:Destroy() end
        if LocalPlayer:WaitForChild("PlayerGui"):FindFirstChild("AntigravityV2UI") then LocalPlayer.PlayerGui.AntigravityV2UI:Destroy() end
        if CoreGui:FindFirstChild("AntigravityFastAttack") then CoreGui.AntigravityFastAttack:Destroy() end
        if LocalPlayer:WaitForChild("PlayerGui"):FindFirstChild("AntigravityFastAttack") then LocalPlayer.PlayerGui.AntigravityFastAttack:Destroy() end
        if CoreGui:FindFirstChild("PortalESP_Container") then CoreGui.PortalESP_Container:Destroy() end
        
        local char = LocalPlayer.Character
        local hrp = char and char:FindFirstChild("HumanoidRootPart")
        if hrp then
            local bv = hrp:FindFirstChild("FlyBodyVelocity")
            if bv then bv:Destroy() end
        end
        
        local platform = workspace:FindFirstChild("FarmingPlatform")
        if platform then platform:Destroy() end
    end)
end
cleanupOldAssets()

local parentUI = nil
local success, err = pcall(function() parentUI = CoreGui end)
if not success or not parentUI then
    parentUI = LocalPlayer:WaitForChild("PlayerGui")
end

-- ==================== CẤU HÌNH & TRẠNG THÁI ====================
local Config = {
    Running = false,
    PrioritizeLowestHealth = true,
    Speed = 300,
    Range = 1000,
    ExcludeName = "shadow"
}

local UPDATE_INTERVAL = 0.1
local currentTarget = nil -- Lưu trữ mục tiêu hiện tại để không bị nhảy quái lung tung
local isTeleportingToPortal = false -- Tránh xung đột luồng hủy tween của luồng chính

-- ==================== HỆ THỐNG DI CHUYỂN & BYPASS ====================
local function startNoclip()
    if not _G.AntigravityV2Noclip then
        _G.AntigravityV2Noclip = RunService.Stepped:Connect(function()
            local character = LocalPlayer.Character
            if character then
                for _, part in ipairs(character:GetDescendants()) do
                    if part:IsA("BasePart") then
                        part.CanCollide = false
                    end
                end
            end
        end)
    end
end

local function stopNoclip()
    if _G.AntigravityV2Noclip then
        _G.AntigravityV2Noclip:Disconnect()
        _G.AntigravityV2Noclip = nil
    end
end

local function startFloat(hrp)
    local bv = hrp:FindFirstChild("FlyBodyVelocity")
    if not bv then
        bv = Instance.new("BodyVelocity")
        bv.Name = "FlyBodyVelocity"
        bv.MaxForce = Vector3.new(1e6, 1e6, 1e6)
        bv.Velocity = Vector3.new(0, 0, 0)
        bv.Parent = hrp
    end
end

local function stopFloat(hrp)
    local bv = hrp:FindFirstChild("FlyBodyVelocity")
    if bv then bv:Destroy() end
end

-- Dịch chuyển hoặc bay tùy theo khoảng cách
local function flyOrTp(hrp, targetCFrame)
    local distance = (targetCFrame.Position - hrp.Position).Magnitude
    
    if distance <= 500 then
        -- Dưới 500 studs: TP thẳng lập tức không delay
        if _G.AntigravityV2Tween then
            _G.AntigravityV2Tween:Cancel()
            _G.AntigravityV2Tween = nil
        end
        hrp.CFrame = targetCFrame
    else
        -- Trên 500 studs: Tween bay tốc độ 300
        if _G.AntigravityV2Tween then
            _G.AntigravityV2Tween:Cancel()
        end
        local duration = distance / Config.Speed
        local tweenInfo = TweenInfo.new(duration, Enum.EasingStyle.Linear)
        _G.AntigravityV2Tween = TweenService:Create(hrp, tweenInfo, {CFrame = targetCFrame})
        _G.AntigravityV2Tween:Play()
    end
end

-- Hàm bay đến Cổng cụ thể (Tránh bị hủy luồng bởi luồng chính khi Auto Farm = Tắt)
local function travelToPortal(portalPos)
    local character = LocalPlayer.Character
    local hrp = character and character:FindFirstChild("HumanoidRootPart")
    if not hrp then return end
    
    -- Tắt trạng thái Auto Farm để tránh kéo giật ngược về quái
    Config.Running = false
    currentTarget = nil
    
    -- Đánh dấu đang di chuyển cổng
    isTeleportingToPortal = true
    startNoclip()
    startFloat(hrp)
    
    if _G.AntigravityV2Tween then
        _G.AntigravityV2Tween:Cancel()
        _G.AntigravityV2Tween = nil
    end
    
    local targetCFrame = CFrame.new(portalPos)
    local distance = (targetCFrame.Position - hrp.Position).Magnitude
    
    if distance <= 500 then
        -- Dưới 500 studs: TP thẳng lập tức
        hrp.CFrame = targetCFrame
        task.wait(0.2)
        isTeleportingToPortal = false
        stopNoclip()
        stopFloat(hrp)
    else
        -- Trên 500 studs: Bay mượt
        local duration = distance / Config.Speed
        local tweenInfo = TweenInfo.new(duration, Enum.EasingStyle.Linear)
        _G.AntigravityV2Tween = TweenService:Create(hrp, tweenInfo, {CFrame = targetCFrame})
        
        local connection
        connection = _G.AntigravityV2Tween.Completed:Connect(function()
            isTeleportingToPortal = false
            stopNoclip()
            stopFloat(hrp)
            if connection then connection:Disconnect() end
        end)
        
        _G.AntigravityV2Tween:Play()
    end
end

-- ==================== TẤN CÔNG & QUÉT MỤC TIÊU ====================
local function isAlive(entity)
    if not entity or not entity.Parent then return false end
    local humanoid = entity:FindFirstChildOfClass("Humanoid")
    return humanoid and humanoid.Health > 0
end

-- Hàm lọc quái có chứa chữ "shadow" trong Model Name hoặc DisplayName
local function hasExcludeKeyword(enemy)
    local name = string.lower(enemy.Name)
    if string.find(name, Config.ExcludeName) then
        return true
    end
    
    local humanoid = enemy:FindFirstChildOfClass("Humanoid")
    if humanoid then
        local displayName = string.lower(humanoid.DisplayName)
        if string.find(displayName, Config.ExcludeName) then
            return true
        end
    end
    
    return false
end

local function getTargets(hrp)
    local targets = {}
    local playerPos = hrp.Position
    local enemies = workspace:FindFirstChild("Enemies") or workspace
    
    for _, enemy in ipairs(enemies:GetChildren()) do
        if enemy:IsA("Model") and isAlive(enemy) then
            local enemyHrp = enemy:FindFirstChild("HumanoidRootPart") or enemy.PrimaryPart
            if enemyHrp then
                local name = string.lower(enemy.Name)
                if not hasExcludeKeyword(enemy) and not string.find(name, "boat") then
                    local dist = (enemyHrp.Position - playerPos).Magnitude
                    if dist <= Config.Range then
                        table.insert(targets, enemy)
                    end
                end
            end
        end
    end
    
    -- Quét quái dự phòng ở Workspace
    if #targets == 0 then
        for _, obj in ipairs(workspace:GetChildren()) do
            if obj:IsA("Model") and obj.Name ~= LocalPlayer.Name and not Players:GetPlayerFromCharacter(obj) then
                local humanoid = obj:FindFirstChildOfClass("Humanoid")
                local enemyHrp = obj:FindFirstChild("HumanoidRootPart")
                if humanoid and enemyHrp and humanoid.Health > 0 then
                    local name = string.lower(obj.Name)
                    if not hasExcludeKeyword(obj) and not string.find(name, "boat") then
                        local dist = (enemyHrp.Position - playerPos).Magnitude
                        if dist <= Config.Range then
                            table.insert(targets, obj)
                        end
                    end
                end
            end
        end
    end
    
    -- Sắp xếp theo ưu tiên máu ít nhất
    if Config.PrioritizeLowestHealth then
        table.sort(targets, function(a, b)
            local humA = a:FindFirstChildOfClass("Humanoid")
            local humB = b:FindFirstChildOfClass("Humanoid")
            local hpA = humA and humA.Health or math.huge
            local hpB = humB and humB.Health or math.huge
            return hpA < hpB
        end)
    else
        -- Sắp xếp theo khoảng cách gần nhất
        table.sort(targets, function(a, b)
            local hrpA = a:FindFirstChild("HumanoidRootPart") or a.PrimaryPart
            local hrpB = b:FindFirstChild("HumanoidRootPart") or b.PrimaryPart
            local distA = hrpA and (hrpA.Position - playerPos).Magnitude or math.huge
            local distB = hrpB and (hrpB.Position - playerPos).Magnitude or math.huge
            return distA < distB
        end)
    end
    
    return targets
end

local function getNearestPlayer(hrp)
    local nearest = nil
    local shortest = math.huge
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= LocalPlayer and p.Character and p.Character:FindFirstChild("HumanoidRootPart") then
            local hum = p.Character:FindFirstChildOfClass("Humanoid")
            if hum and hum.Health > 0 then
                local dist = (p.Character.HumanoidRootPart.Position - hrp.Position).Magnitude
                if dist < shortest then
                    shortest = dist
                    nearest = p
                end
            end
        end
    end
    return nearest
end

local function getMeleeWeapon()
    local character = LocalPlayer.Character
    if not character then return nil end
    for _, item in ipairs(LocalPlayer.Backpack:GetChildren()) do
        if item:IsA("Tool") and item.ToolTip == "Melee" then return item end
    end
    for _, item in ipairs(character:GetChildren()) do
        if item:IsA("Tool") and item.ToolTip == "Melee" then return item end
    end
    return nil
end

local function equipMelee()
    local weapon = getMeleeWeapon()
    if weapon and weapon.Parent == LocalPlayer.Backpack then
        local character = LocalPlayer.Character
        if character and character:FindFirstChildOfClass("Humanoid") then
            character.Humanoid:EquipTool(weapon)
        end
    end
end

local function getHitFunction()
    if getsenv then
        for _, s in ipairs(LocalPlayer.PlayerScripts:GetChildren()) do
            if s:IsA("LocalScript") then
                local success, env = pcall(getsenv, s)
                if success and env and env._G and env._G.SendHitsToServer then
                    return env._G.SendHitsToServer
                end
            end
        end
    end
    return nil
end

local RegisterAttack = ReplicatedStorage:WaitForChild("Modules"):WaitForChild("Net"):WaitForChild("RE/RegisterAttack")
local RegisterHit = ReplicatedStorage:WaitForChild("Modules"):WaitForChild("Net"):WaitForChild("RE/RegisterHit")
local hitFunction = getHitFunction()

local function attackTargets(targets, mainEnemy)
    if not mainEnemy then return end
    local targetsList = {}
    local mainTargetHead = mainEnemy:FindFirstChild("Head") or mainEnemy:FindFirstChild("HumanoidRootPart")
    if not mainTargetHead then return end
    
    local playerPos = LocalPlayer.Character.HumanoidRootPart.Position
    
    -- Chém lan thêm các con quái phụ nếu chúng ở cực gần
    for _, enemy in ipairs(targets) do
        local head = enemy:FindFirstChild("Head") or enemy:FindFirstChild("HumanoidRootPart")
        if head and (head.Position - playerPos).Magnitude <= 120 then
            table.insert(targetsList, {enemy, head})
        end
    end
    
    if #targetsList == 0 then
        table.insert(targetsList, {mainEnemy, mainTargetHead})
    end
    
    equipMelee()
    local combatRemoteThread = false
    pcall(function()
        local modules = ReplicatedStorage:FindFirstChild("Modules")
        local flags = modules and modules:FindFirstChild("Flags")
        if flags then
            combatRemoteThread = require(flags).COMBAT_REMOTE_THREAD or false
        end
    end)
    
    -- Spam 4 đòn đánh mỗi 0.1 giây để đạt 40 CPS
    for i = 1, 4 do
        RegisterAttack:FireServer(0)
        if combatRemoteThread and hitFunction then
            hitFunction(mainTargetHead, targetsList)
        else
            RegisterHit:FireServer(mainTargetHead, targetsList)
        end
    end
end

-- ==================== HÀM KÉO THẢ GIAO DIỆN (DRAG) HOÀN CHỈNH ====================
local function makeDraggable(frame, handle)
    local dragging, dragInput, dragStart, startPos
    
    handle.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            dragStart = input.Position
            startPos = frame.Position
            
            input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then
                    dragging = false
                end
            end)
        end
    end)
    
    handle.InputChanged:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
            dragInput = input
        end
    end)
    
    UserInputService.InputChanged:Connect(function(input)
        if input == dragInput and dragging then
            local delta = input.Position - dragStart
            frame.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
        end
    end)
end

-- ==================== THIẾT KẾ UI GIAO DIỆN (SMOOTH GLASS) ====================
local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "AntigravityV2UI"
ScreenGui.ResetOnSpawn = false
ScreenGui.Parent = parentUI

-- Nút Trôi Nổi (Floating Mini Icon)
local FloatingBtn = Instance.new("ImageButton")
FloatingBtn.Name = "FloatingBtn"
FloatingBtn.Size = UDim2.new(0, 38, 0, 38)
FloatingBtn.Position = UDim2.new(0.1, 0, 0.2, 0)
FloatingBtn.BackgroundColor3 = Color3.fromRGB(15, 15, 20)
FloatingBtn.Image = "rbxassetid://15694200676"
FloatingBtn.Parent = ScreenGui

local FCorner = Instance.new("UICorner")
FCorner.CornerRadius = UDim.new(1, 0)
FCorner.Parent = FloatingBtn

local FStroke = Instance.new("UIStroke")
FStroke.Thickness = 1.5
FStroke.Color = Color3.fromRGB(0, 255, 255)
FStroke.Parent = FloatingBtn
makeDraggable(FloatingBtn, FloatingBtn)

-- Khung hiển thị chính (Main Frame)
local MainFrame = Instance.new("Frame")
MainFrame.Name = "MainFrame"
MainFrame.Size = UDim2.new(0, 300, 0, 240)
MainFrame.Position = UDim2.new(0.5, -150, 0.5, -120)
MainFrame.BackgroundColor3 = Color3.fromRGB(15, 15, 20)
MainFrame.BackgroundTransparency = 0.15
MainFrame.Visible = false
MainFrame.ClipsDescendants = true
MainFrame.Parent = ScreenGui

local MainCorner = Instance.new("UICorner")
MainCorner.CornerRadius = UDim.new(0, 8)
MainCorner.Parent = MainFrame

local MainStroke = Instance.new("UIStroke")
MainStroke.Thickness = 1.5
MainStroke.Color = Color3.fromRGB(0, 255, 255)
MainStroke.Parent = MainFrame

-- Header bar
local Header = Instance.new("Frame")
Header.Name = "Header"
Header.Size = UDim2.new(1, 0, 0, 30)
Header.BackgroundColor3 = Color3.fromRGB(24, 24, 30)
Header.BorderSizePixel = 0
Header.Parent = MainFrame
makeDraggable(MainFrame, Header)

local HeaderTitle = Instance.new("TextLabel")
HeaderTitle.Size = UDim2.new(0.8, 0, 1, 0)
HeaderTitle.Position = UDim2.new(0.04, 0, 0, 0)
HeaderTitle.BackgroundTransparency = 1
HeaderTitle.Text = "Antigravity Hub v2 (Farm & Portals)"
HeaderTitle.TextColor3 = Color3.fromRGB(255, 255, 255)
HeaderTitle.TextSize = 11
HeaderTitle.Font = Enum.Font.SourceSansBold
HeaderTitle.TextXAlignment = Enum.TextXAlignment.Left
HeaderTitle.Parent = Header

-- Tab bar
local TabBar = Instance.new("Frame")
TabBar.Size = UDim2.new(1, 0, 0, 25)
TabBar.Position = UDim2.new(0, 0, 0, 30)
TabBar.BackgroundColor3 = Color3.fromRGB(20, 20, 25)
TabBar.BorderSizePixel = 0
TabBar.Parent = MainFrame

local FarmTabBtn = Instance.new("TextButton")
FarmTabBtn.Size = UDim2.new(0.5, 0, 1, 0)
FarmTabBtn.BackgroundTransparency = 1
FarmTabBtn.Text = "AUTO FARM"
FarmTabBtn.TextColor3 = Color3.fromRGB(0, 255, 255)
FarmTabBtn.TextSize = 10
FarmTabBtn.Font = Enum.Font.SourceSansBold
FarmTabBtn.Parent = TabBar

local PortalTabBtn = Instance.new("TextButton")
PortalTabBtn.Size = UDim2.new(0.5, 0, 1, 0)
PortalTabBtn.Position = UDim2.new(0.5, 0, 0, 0)
PortalTabBtn.BackgroundTransparency = 1
PortalTabBtn.Text = "TELEPORT PORTALS"
PortalTabBtn.TextColor3 = Color3.fromRGB(150, 150, 150)
PortalTabBtn.TextSize = 10
PortalTabBtn.Font = Enum.Font.SourceSansBold
PortalTabBtn.Parent = TabBar

-- Content Pages Container
local Pages = Instance.new("Frame")
Pages.Size = UDim2.new(1, 0, 1, -55)
Pages.Position = UDim2.new(0, 0, 0, 55)
Pages.BackgroundTransparency = 1
Pages.Parent = MainFrame

-- Page 1: Farm/Aura
local FarmPage = Instance.new("Frame")
FarmPage.Size = UDim2.new(1, 0, 1, 0)
FarmPage.BackgroundTransparency = 1
FarmPage.Visible = true
FarmPage.Parent = Pages

local RunBtn = Instance.new("TextButton")
RunBtn.Size = UDim2.new(0.42, 0, 0, 28)
RunBtn.Position = UDim2.new(0.06, 0, 0.05, 0)
RunBtn.BackgroundColor3 = Color3.fromRGB(40, 40, 45)
RunBtn.Text = "AUTO FARM: TẮT"
RunBtn.TextColor3 = Color3.fromRGB(255, 80, 80)
RunBtn.TextSize = 10
RunBtn.Font = Enum.Font.SourceSansBold
RunBtn.Parent = FarmPage
local RunBtnCorner = Instance.new("UICorner")
RunBtnCorner.CornerRadius = UDim.new(0, 5)
RunBtnCorner.Parent = RunBtn

local HPFilterBtn = Instance.new("TextButton")
HPFilterBtn.Size = UDim2.new(0.46, 0, 0, 28)
HPFilterBtn.Position = UDim2.new(0.51, 0, 0.05, 0)
HPFilterBtn.BackgroundColor3 = Color3.fromRGB(0, 150, 150)
HPFilterBtn.Text = "ƯU TIÊN MÁU ÍT: BẬT"
HPFilterBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
HPFilterBtn.TextSize = 10
HPFilterBtn.Font = Enum.Font.SourceSansBold
HPFilterBtn.Parent = FarmPage
local HPFilterCorner = Instance.new("UICorner")
HPFilterCorner.CornerRadius = UDim.new(0, 5)
HPFilterCorner.Parent = HPFilterBtn

-- Danh sách quái vật xung quanh
local MonsterListLabel = Instance.new("TextLabel")
MonsterListLabel.Size = UDim2.new(0.88, 0, 0, 15)
MonsterListLabel.Position = UDim2.new(0.06, 0, 0.25, 0)
MonsterListLabel.BackgroundTransparency = 1
MonsterListLabel.Text = "Quái vật trong phạm vi hoạt động:"
MonsterListLabel.TextColor3 = Color3.fromRGB(160, 160, 170)
MonsterListLabel.TextSize = 9
MonsterListLabel.Font = Enum.Font.SourceSansBold
MonsterListLabel.TextXAlignment = Enum.TextXAlignment.Left
MonsterListLabel.Parent = FarmPage

local MonsterScroll = Instance.new("ScrollingFrame")
MonsterScroll.Size = UDim2.new(0.88, 0, 0.54, 0)
MonsterScroll.Position = UDim2.new(0.06, 0, 0.35, 0)
MonsterScroll.BackgroundColor3 = Color3.fromRGB(10, 10, 12)
MonsterScroll.BackgroundTransparency = 0.5
MonsterScroll.ScrollBarThickness = 3
MonsterScroll.ScrollBarImageColor3 = Color3.fromRGB(0, 255, 255)
MonsterScroll.CanvasSize = UDim2.new(0, 0, 0, 0)
MonsterScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
MonsterScroll.Parent = FarmPage
local MonsterScrollCorner = Instance.new("UICorner")
MonsterScrollCorner.CornerRadius = UDim.new(0, 5)
MonsterScrollCorner.Parent = MonsterScroll

local MonsterLayout = Instance.new("UIListLayout", MonsterScroll)
MonsterLayout.Padding = UDim.new(0, 3)

-- ==================== KHỞI TẠO POOL OBJECTS CHO LIST QUÁI VẬT (TỐI ƯU CỰC MẠNH) ====================
-- Tạo sẵn 15 Row tĩnh để hiển thị thông tin quái, tránh việc Destroy/Instance.new liên tục gây sụt FPS
local RowPool = {}
for i = 1, 15 do
    local row = Instance.new("TextLabel")
    row.Size = UDim2.new(1, -8, 0, 16)
    row.BackgroundTransparency = 1
    row.TextColor3 = Color3.fromRGB(230, 230, 235)
    row.TextSize = 10
    row.Font = Enum.Font.SourceSans
    row.TextXAlignment = Enum.TextXAlignment.Left
    row.Visible = false
    row.Parent = MonsterScroll
    table.insert(RowPool, row)
end

-- Page 2: Portals (Cổng 1-3)
local PortalPage = Instance.new("Frame")
PortalPage.Size = UDim2.new(1, 0, 1, 0)
PortalPage.BackgroundTransparency = 1
PortalPage.Visible = false
PortalPage.Parent = Pages

local PortalTitle = Instance.new("TextLabel")
PortalTitle.Size = UDim2.new(0.88, 0, 0, 15)
PortalTitle.Position = UDim2.new(0.06, 0, 0.05, 0)
PortalTitle.BackgroundTransparency = 1
PortalTitle.Text = "Di chuyển nhanh đến các cổng dịch chuyển:"
PortalTitle.TextColor3 = Color3.fromRGB(160, 160, 170)
PortalTitle.TextSize = 9
PortalTitle.Font = Enum.Font.SourceSansBold
PortalTitle.TextXAlignment = Enum.TextXAlignment.Left
PortalTitle.Parent = PortalPage

-- 3 nút Cổng
local portalsList = {
    {name = "CỔNG DỊCH CHUYỂN 1", pos = Vector3.new(-238.21, 236.54, -426.61)},
    {name = "CỔNG DỊCH CHUYỂN 2", pos = Vector3.new(-358.51, 236.54, -448.36)},
    {name = "CỔNG DỊCH CHUYỂN 3", pos = Vector3.new(-480.76, 236.54, -431.06)}
}

for i, pInfo in ipairs(portalsList) do
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(0.88, 0, 0, 32)
    btn.Position = UDim2.new(0.06, 0, 0.12 + (i - 1) * 0.24, 0)
    btn.BackgroundColor3 = Color3.fromRGB(30, 30, 35)
    btn.Text = string.format("%s\n(%.1f, %.1f, %.1f)", pInfo.name, pInfo.pos.X, pInfo.pos.Y, pInfo.pos.Z)
    btn.TextColor3 = Color3.fromRGB(0, 255, 255)
    btn.TextSize = 9
    btn.Font = Enum.Font.SourceSansBold
    btn.Parent = PortalPage
    
    local btnCorner = Instance.new("UICorner")
    btnCorner.CornerRadius = UDim.new(0, 5)
    btnCorner.Parent = btn
    
    btn.MouseButton1Click:Connect(function()
        print("[Teleport Portals]: Đang di chuyển đến " .. pInfo.name)
        travelToPortal(pInfo.pos)
    end)
end

-- ==================== XỬ LÝ SỰ KIỆN GIAO DIỆN ====================
local function updateUI()
    if Config.Running then
        RunBtn.BackgroundColor3 = Color3.fromRGB(0, 255, 120)
        RunBtn.Text = "AUTO FARM: BẬT"
        RunBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    else
        RunBtn.BackgroundColor3 = Color3.fromRGB(40, 40, 45)
        RunBtn.Text = "AUTO FARM: TẮT"
        RunBtn.TextColor3 = Color3.fromRGB(255, 80, 80)
    end
    
    if Config.PrioritizeLowestHealth then
        HPFilterBtn.BackgroundColor3 = Color3.fromRGB(0, 180, 180)
        HPFilterBtn.Text = "ƯU TIÊN MÁU ÍT: BẬT"
    else
        HPFilterBtn.BackgroundColor3 = Color3.fromRGB(40, 40, 45)
        HPFilterBtn.Text = "ƯU TIÊN MÁU ÍT: TẮT"
    end
end

-- Tải/Thu phóng Menu thông qua floating button
local uiOpen = false
FloatingBtn.MouseButton1Click:Connect(function()
    uiOpen = not uiOpen
    if uiOpen then
        MainFrame.Visible = true
        MainFrame:TweenSize(UDim2.new(0, 300, 0, 240), "Out", "Quad", 0.25, true)
    else
        MainFrame:TweenSize(UDim2.new(0, 0, 0, 0), "Out", "Quad", 0.25, true)
        task.delay(0.25, function() if not uiOpen then MainFrame.Visible = false end end)
    end
end)

-- Nhấp tab
FarmTabBtn.MouseButton1Click:Connect(function()
    FarmTabBtn.TextColor3 = Color3.fromRGB(0, 255, 255)
    PortalTabBtn.TextColor3 = Color3.fromRGB(150, 150, 150)
    FarmPage.Visible = true
    PortalPage.Visible = false
end)

PortalTabBtn.MouseButton1Click:Connect(function()
    PortalTabBtn.TextColor3 = Color3.fromRGB(0, 255, 255)
    FarmTabBtn.TextColor3 = Color3.fromRGB(150, 150, 150)
    FarmPage.Visible = false
    PortalPage.Visible = true
end)

-- Xử lý nút bật tắt Farm
RunBtn.MouseButton1Click:Connect(function()
    Config.Running = not Config.Running
    updateUI()
end)

-- Xử lý nút lọc máu
HPFilterBtn.MouseButton1Click:Connect(function()
    Config.PrioritizeLowestHealth = not Config.PrioritizeLowestHealth
    updateUI()
end)

updateUI()

-- ==================== VÒNG LẶP CẬP NHẬT GIAO DIỆN QUÁI VẬT (TỐI ƯU HÓA) ====================
task.spawn(function()
    while scriptID == _G.AntigravityV2ID do
        task.wait(0.5)
        pcall(function()
            local character = LocalPlayer.Character
            local hrp = character and character:FindFirstChild("HumanoidRootPart")
            if hrp then
                if FarmPage.Visible then
                    local targets = getTargets(hrp)
                    
                    -- Cập nhật chữ tĩnh thay vì tạo mới/hủy liên tục
                    for i = 1, 15 do
                        local row = RowPool[i]
                        local enemy = targets[i]
                        
                        if enemy and isAlive(enemy) then
                            local eHrp = enemy:FindFirstChild("HumanoidRootPart")
                            local hum = enemy:FindFirstChildOfClass("Humanoid")
                            if eHrp and hum then
                                local dist = math.round((eHrp.Position - hrp.Position).Magnitude)
                                local hpPercent = math.round((hum.Health / hum.MaxHealth) * 100)
                                row.Text = string.format(" 👾 %s - HP: %d%% - %dm", enemy.Name, hpPercent, dist)
                                row.Visible = true
                            else
                                row.Visible = false
                            end
                        else
                            row.Visible = false
                        end
                    end
                else
                    -- Ẩn hết danh sách quái khi đổi qua tab Cổng để tiết kiệm tài nguyên
                    for i = 1, 15 do
                        RowPool[i].Visible = false
                    end
                end
            end
        end)
    end
end)

-- ==================== LUỒNG TỰ ĐỘNG BẬT HAKI (CHECK MỖI 1 GIÂY) ====================
task.spawn(function()
    print("[Antigravity HakiManager]: Đang giám sát Haki (1s/lần)...")
    while scriptID == _G.AntigravityV2ID do
        task.wait(1)
        
        if Config.Running then
            pcall(function()
                local character = LocalPlayer.Character
                local humanoid = character and character:FindFirstChildOfClass("Humanoid")
                
                if character and humanoid and humanoid.Health > 0 then
                    -- 1. Tự động kiểm tra và bật Haki Vũ Trang (Buso)
                    if not character:FindFirstChild("HasBuso") then
                        local CommF = ReplicatedStorage:FindFirstChild("Remotes") and ReplicatedStorage.Remotes:FindFirstChild("CommF_")
                        if CommF then
                            CommF:InvokeServer("Buso")
                        end
                    end
                    
                    -- 2. Tự động bật Haki Quan Sát (Ken / Instinct)
                    local CommE = ReplicatedStorage:FindFirstChild("Remotes") and ReplicatedStorage.Remotes:FindFirstChild("CommE")
                    if CommE then
                        CommE:FireServer("Ken", true)
                    end
                end
            end)
        end
    end
end)

-- ==================== LUỒNG HOẠT ĐỘNG CHÍNH (UPDATE 0.1S) ====================
task.spawn(function()
    print("[Antigravity Hub]: Luồng chính của Script đã chạy.")
    while scriptID == _G.AntigravityV2ID do
        task.wait(UPDATE_INTERVAL)
        
        if Config.Running then
            pcall(function()
                local character = LocalPlayer.Character
                local hrp = character and character:FindFirstChild("HumanoidRootPart")
                
                if hrp then
                    startNoclip()
                    startFloat(hrp)
                    equipMelee()
                    
                    local targets = getTargets(hrp)
                    
                    -- KIỂM TRA MỤC TIÊU HIỆN TẠI (Đang đánh con nào thì dồn lực đánh xong con đó)
                    if currentTarget and isAlive(currentTarget) and (currentTarget.HumanoidRootPart.Position - hrp.Position).Magnitude <= Config.Range then
                        -- Tiếp tục giữ nguyên mục tiêu hiện tại để không bị nhảy quái
                    else
                        -- Mục tiêu đã chết hoặc ngoài tầm, chọn mục tiêu mới
                        currentTarget = nil
                        if #targets > 0 then
                            currentTarget = targets[1] -- targets[1] là quái yếu máu nhất đã được lọc
                        end
                    end
                    
                    if currentTarget then
                        -- Vị trí luôn là BÊN DƯỚI QUÁI 50 studs
                        local targetCFrame = currentTarget.HumanoidRootPart.CFrame * CFrame.new(0, -50, 0)
                        
                        -- Bay hoặc dịch chuyển đến
                        flyOrTp(hrp, targetCFrame)
                        
                        -- Chém quái
                        attackTargets(targets, currentTarget)
                    else
                        -- Không có quái: Tìm và bay đến trước mặt người chơi gần nhất
                        local nearestPlayer = getNearestPlayer(hrp)
                        if nearestPlayer and nearestPlayer.Character and nearestPlayer.Character:FindFirstChild("HumanoidRootPart") then
                            local targetCFrame = nearestPlayer.Character.HumanoidRootPart.CFrame * CFrame.new(0, 0, -5) * CFrame.Angles(0, math.pi, 0)
                            flyOrTp(hrp, targetCFrame)
                        else
                            -- Đứng im lơ lửng nếu hoàn toàn không có quái hay người chơi
                            if _G.AntigravityV2Tween then
                                _G.AntigravityV2Tween:Cancel()
                                _G.AntigravityV2Tween = nil
                            end
                        end
                    end
                end
            end)
        else
            stopNoclip()
            pcall(function()
                local character = LocalPlayer.Character
                local hrp = character and character:FindFirstChild("HumanoidRootPart")
                if hrp and not isTeleportingToPortal then stopFloat(hrp) end
            end)
            if _G.AntigravityV2Tween and not isTeleportingToPortal then
                _G.AntigravityV2Tween:Cancel()
                _G.AntigravityV2Tween = nil
            end
            currentTarget = nil
        end
    end
end)
