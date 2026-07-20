-- [[ Antigravity Hub - Blox Fruits Ultimate Integration Script ]]
-- Tích hợp: Kaitun Farm, Fast Attack CPS, Auto Farm, Boss Spawn, Auto Chest, Fruit Sniper, ESP, Haki, Anti-AFK & Lag Fix.
-- Thiết kế UI kính mờ (Glassmorphic UI) có tab & icon mở khóa. Lưu cấu hình theo tên người dùng.

repeat task.wait() until game:IsLoaded()

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local VirtualUser = game:GetService("VirtualUser")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local CoreGui = game:GetService("CoreGui")
local Lighting = game:GetService("Lighting")
local TeleportService = game:GetService("TeleportService")
local HttpService = game:GetService("HttpService")
local CollectionService = game:GetService("CollectionService")

local LocalPlayer = Players.LocalPlayer
local username = LocalPlayer.Name

-- Độc lập hóa các phiên chạy script cũ
_G.AntigravityRunID = (_G.AntigravityRunID or 0) + 1
local currentRunID = _G.AntigravityRunID

-- Dọn dẹp UI cũ nếu có
if CoreGui:FindFirstChild("AntigravityUltimateUI") then
    CoreGui.AntigravityUltimateUI:Destroy()
end
if LocalPlayer:WaitForChild("PlayerGui"):FindFirstChild("AntigravityUltimateUI") then
    LocalPlayer.PlayerGui.AntigravityUltimateUI:Destroy()
end

-- Tìm vị trí lưu trữ UI an toàn
local parentUI = nil
local success, err = pcall(function() parentUI = CoreGui end)
if not success or not parentUI then
    parentUI = LocalPlayer:WaitForChild("PlayerGui")
end

-- =========================================================================
-- CẤU HÌNH HOẠT ĐỘNG (CONFIG - LƯU THEO TÊN NGƯỜI DÙNG)
-- =========================================================================
local CONFIG_FILE = "Antigravity_Config_" .. username .. ".json"

local Config = {
    -- Combat
    AutoFarm = false,
    FastAttack = false,
    WeaponType = "Melee",   -- "Melee" hoặc "Sword"
    AttackCPS = 20,
    ScanRange = 250,
    YOffset = 20,
    FarmSpeed = 300,
    AutoHaki = false,
    AutoKen = false,
    AutoCompassTP = true,
    
    -- Bosses & Chests
    AutoFarmChest = false,
    ChestTargetLimit = 70,
    AutoKillRipIndra = false,
    AutoKillDarkbeard = false,
    
    -- Fruit Sniper
    AutoFruitSniper = false,
    FruitESP = false,
    StoreRetries = 3,
    DiscordWebhook = "",
    
    -- Utilities / System
    LowGraphics = false,
    AutoSelectTeam = false,
    Team = 1, -- 0 = Marines, 1 = Pirates
}

local function loadConfig()
    if isfile and isfile(CONFIG_FILE) then
        local success, result = pcall(function()
            return HttpService:JSONDecode(readfile(CONFIG_FILE))
        end)
        if success and type(result) == "table" then
            for k, v in pairs(result) do
                Config[k] = v
            end
            print("💾 [Antigravity] Đã nạp cấu hình cho tài khoản: " .. username)
        end
    end
end

local function saveConfig()
    if writefile then
        local success, content = pcall(function()
            return HttpService:JSONEncode(Config)
        end)
        if success then
            writefile(CONFIG_FILE, content)
        end
    end
end

loadConfig()

-- Biến toàn cục kiểm soát
local scriptRunning = true
local render3DEnabled = true
local _G_ActiveTarget = nil
local _G_StatusText = "Đang chờ lệnh..."
local countChests = 0
local sessionStartTime = os.time()

-- Dữ liệu tọa độ
local SummonCFrame = CFrame.new(-5564.36, 314.57, -2661.53) -- Bệ spawn Rip Indra (Sea 3)
local HakiSteps = {
    { Name = "Snow White", Position = CFrame.new(-4971.72, 335.96, -3720.06) },
    { Name = "Pure Red", Position = CFrame.new(-5414.92, 314.26, -2212.20) },
    { Name = "Winter Sky", Position = CFrame.new(-5420.26, 1089.36, -2666.82) }
}
local DarkbeardSummonCFrame = CFrame.new(3780.88, 17.05, -3499.23) -- Vệ spawn Darkbeard (Sea 2)

-- Các Remote tham chiếu
local CommF = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("CommF_")
local FruitCustomizerRF = ReplicatedStorage:WaitForChild("Modules"):WaitForChild("Net"):WaitForChild("RF/FruitCustomizerRF")

-- =========================================================================
-- CHỨC NĂNG LẺ 1: KHỬ ANTI-CHEAT 3TN (ANTI-3TN DISABLER)
-- =========================================================================
local function runAnti3TN()
    local function kill3TN(o)
        if o and o.Name == "3TN" then o:Destroy() end
    end
    pcall(function() kill3TN(CoreGui:FindFirstChild("3TN")) end)
    RunService.RenderStepped:Connect(function() kill3TN(CoreGui:FindFirstChild("3TN")) end)
    CoreGui.ChildAdded:Connect(kill3TN)
    CoreGui.DescendantAdded:Connect(kill3TN)
    task.spawn(function()
        while scriptRunning and currentRunID == _G.AntigravityRunID do
            task.wait(0.1)
            kill3TN(CoreGui:FindFirstChild("3TN"))
        end
    end)
    print("🛡️ [Anti-3TN] Đã kích hoạt cơ chế bảo vệ chạy ngầm.")
end
runAnti3TN()

-- =========================================================================
-- CHỨC NĂNG LẺ 2: TỐI ƯU HÓA ĐỒ HỌA NÂNG CAO (ADVANCED LAG FIX & FPS BOOST)
-- =========================================================================
local function optimizeGraphics()
    pcall(function()
        Lighting.GlobalShadows = false
        Lighting.FogEnd = 9e9
        Lighting.Brightness = 1
        Lighting.ClockTime = 12
        
        local Terrain = workspace:FindFirstChildOfClass("Terrain")
        if Terrain then
            Terrain.WaterWaveSize = 0
            Terrain.WaterWaveSpeed = 0
            Terrain.WaterReflectance = 0
            Terrain.WaterTransparency = 0
        end
        
        for _, obj in pairs(workspace:GetDescendants()) do
            if obj:IsA("ParticleEmitter") or obj:IsA("Trail") or obj:IsA("Fire") or obj:IsA("Smoke") then
                obj.Enabled = false
            end
            if obj:IsA("BasePart") then
                obj.Material = Enum.Material.Plastic
                obj.Reflectance = 0
                obj.CastShadow = false
            end
            if obj:IsA("Decal") or obj:IsA("Texture") then
                obj.Transparency = 1
            end
        end
        
        for _, effect in pairs(Lighting:GetChildren()) do
            if effect:IsA("PostEffect") or (effect:IsA("BlurEffect") and effect.Name ~= "NexusBlur") then
                effect.Enabled = false
            end
        end
        
        -- Xóa Island LOD
        local playerScripts = LocalPlayer:FindFirstChild("PlayerScripts")
        if playerScripts then
            if playerScripts:FindFirstChild("NewIslandLOD") then playerScripts.NewIslandLOD:Destroy() end
            if playerScripts:FindFirstChild("IslandLOD") then playerScripts.IslandLOD:Destroy() end
        end
        
        -- Dọn hiệu ứng game thừa từ Container
        local container = ReplicatedStorage:FindFirstChild("Container", true)
        if container then
            for _, name in ipairs({"AirDash", "LightningTP", "Damage", "Confetti", "LevelUp"}) do
                local target = container:FindFirstChild(name, true)
                if target then target:Destroy() end
            end
        end
        
        if setfps then pcall(setfps, 120) end
        print("⚡ [Lag Fix] Tối ưu hóa bộ nhớ và đồ họa nâng cao thành công!")
    end)
end

-- Bộ dọn RAM định kỳ
task.spawn(function()
    while scriptRunning and currentRunID == _G.AntigravityRunID do
        task.wait(5)
        if Config.LowGraphics then
            pcall(function()
                gcinfo()
                collectgarbage("collect")
            end)
        end
    end
end)

-- Khởi động lag fix nếu cấu hình bật
if Config.LowGraphics then
    task.spawn(optimizeGraphics)
end

-- =========================================================================
-- CHỨC NĂNG LẺ 3: GỌI MODULE FARM CỦA KAITUN (KAITUN LOADER)
-- =========================================================================
local function loadKaitunModule()
    _G_StatusText = "Đang tải Kaitun..."
    task.spawn(function()
        local success, err = pcall(function()
            loadstring(game:HttpGet("https://raw.githubusercontent.com/sucvatthieunang/djtme/refs/heads/main/module"))()
        end)
        if success then
            _G_StatusText = "Kaitun Module hoạt động!"
            print("🚀 [Kaitun] Đã nạp thành công module từ sucvatthieunang!")
        else
            _G_StatusText = "Lỗi tải Kaitun"
            warn("❌ [Kaitun] Lỗi nạp module: " .. tostring(err))
        end
    end)
end

-- =========================================================================
-- CHỨC NĂNG LẺ 4: THEO DÕI THÔNG TIN VÀ KIỂM TRA ĐỒ ĐẠC (STATS TRACKER)
-- =========================================================================
local function getPlayerData()
    local level, beli, bounty, frag = 0, 0, 0, 0
    local race = "Unknown"
    
    local data = LocalPlayer:FindFirstChild("Data")
    local leaderstats = LocalPlayer:FindFirstChild("leaderstats")
    
    if data then
        local lv = data:FindFirstChild("Level")
        if lv then level = lv.Value end
        local b = data:FindFirstChild("Beli")
        if b then beli = b.Value end
        local f = data:FindFirstChild("Fragments")
        if f then frag = f.Value end
        local r = data:FindFirstChild("Race")
        if r then race = r.Value end
    end
    if leaderstats then
        local bo = leaderstats:FindFirstChild("Bounty/Honor")
        if bo then bounty = bo.Value end
    end
    
    return level, beli, bounty, frag, race
end

local function getFarmProgress()
    local backpack = LocalPlayer:FindFirstChild("Backpack")
    local character = LocalPlayer.Character
    
    local function hasItem(itemName)
        local inBackpack = backpack and backpack:FindFirstChild(itemName) ~= nil
        local inCharacter = character and character:FindFirstChild(itemName) ~= nil
        return inBackpack or inCharacter
    end
    
    local hasGodHuman = hasItem("Godhuman")
    local hasSoulGuitar = hasItem("Soul Guitar") or hasItem("Skull Guitar")
    local hasCDK = hasItem("Cursed Dual Katana")
    
    local pullLever = false
    pcall(function()
        pullLever = CommF:InvokeServer("CheckTempleDoor") == true
    end)
    
    return hasGodHuman, hasSoulGuitar, hasCDK, pullLever
end

-- =========================================================================
-- TÍNH NĂNG CHỐNG AFK & TRANG BỊ VŨ KHÍ
-- =========================================================================
local function getMyPosition()
    local char = LocalPlayer.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    return hrp and hrp.Position
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

local function getWeapon(toolTip)
    local character = LocalPlayer.Character
    if not character then return nil end
    for _, item in ipairs(LocalPlayer.Backpack:GetChildren()) do
        if item:IsA("Tool") and item.ToolTip == toolTip then
            return item
        end
    end
    for _, item in ipairs(character:GetChildren()) do
        if item:IsA("Tool") and item.ToolTip == toolTip then
            return item
        end
    end
    return nil
end

local function equipWeapon(toolTip)
    local tool = getWeapon(toolTip)
    if tool then
        local character = LocalPlayer.Character
        if character and character:FindFirstChildOfClass("Humanoid") then
            if tool.Parent == LocalPlayer.Backpack then
                character.Humanoid:EquipTool(tool)
            end
        end
    end
end

-- =========================================================================
-- HAKI VÀ CHỌN PHE MẠC ĐỊNH
-- =========================================================================
local function activateBuso()
    local character = LocalPlayer.Character
    if character and not character:FindFirstChild("HasBuso") then
        pcall(function() CommF:InvokeServer("Buso") end)
    end
end

local function activateKen()
    pcall(function()
        if not isKenActive() then
            local Remotes = ReplicatedStorage:FindFirstChild("Remotes")
            local CommE = Remotes and Remotes:FindFirstChild("CommE")
            if CommE then
                CommE:FireServer("Ken", true)
            end
        end
    end)
end

local function selectTeam()
    if not Config.AutoSelectTeam then return end
    local teamName = (Config.Team == 0) and "Marines" or "Pirates"
    pcall(function() CommF:InvokeServer("SetTeam", teamName) end)
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
        end
    end)
end

-- =========================================================================
-- HỌP SERVER CÓ ƯU TIÊN SERVER CÓ ĐÚNG 1 NGƯỜI CHƠI
-- =========================================================================
local function getVisitedServers()
    local list = {}
    pcall(function()
        if readfile and isfile and isfile("visited_servers.txt") then
            local content = readfile("visited_servers.txt")
            for id in string.gmatch(content, "[^\n]+") do
                list[id] = true
            end
        end
    end)
    return list
end

local function saveVisitedServer(serverId)
    pcall(function()
        if writefile and readfile then
            local content = ""
            if isfile and isfile("visited_servers.txt") then
                content = readfile("visited_servers.txt")
            end
            local lines = {}
            for id in string.gmatch(content, "[^\n]+") do
                if id ~= serverId then table.insert(lines, id) end
            end
            table.insert(lines, serverId)
            if #lines > 80 then table.remove(lines, 1) end
            writefile("visited_servers.txt", table.concat(lines, "\n"))
        end
    end)
end

local function hopLowServerFast()
    local CurrentPlaceId = game.PlaceId
    local apiUrl = "https://games.roblox.com/v1/games/" .. CurrentPlaceId .. "/servers/Public?sortOrder=Asc&limit=100"
    
    local function ListServers(cursor)
        local success, raw = pcall(function() return game:HttpGet(apiUrl .. ((cursor and "&cursor=" .. cursor) or "")) end)
        return success and HttpService:JSONDecode(raw) or nil
    end
    
    local Server, Next
    local pageAttempts = 0
    local maxPages = 8
    local candidateServers = {}
    local fallbackServers = {}
    local visited = getVisitedServers()
    
    pcall(function()
        repeat 
            local Servers = ListServers(Next)
            pageAttempts = pageAttempts + 1
            if Servers and Servers.data then
                for _, s in pairs(Servers.data) do
                    local playing = tonumber(s.playing)
                    local maxPlayers = tonumber(s.maxPlayers)
                    if s.id ~= game.JobId and not visited[s.id] and playing and maxPlayers and playing < (maxPlayers - 1) then
                        if playing == 1 then
                            table.insert(candidateServers, s)
                        else
                            table.insert(fallbackServers, s)
                        end
                    end
                end
                Next = Servers.nextPageCursor
            else
                break
            end
            task.wait(0.1)
        until #candidateServers > 0 or not Next or pageAttempts >= maxPages
    end)
    
    if #candidateServers > 0 then
        Server = candidateServers[math.random(1, #candidateServers)]
    elseif #fallbackServers > 0 then
        table.sort(fallbackServers, function(a, b) return tonumber(a.playing) < tonumber(b.playing) end)
        Server = fallbackServers[1]
    end
    
    if Server then
        saveVisitedServer(Server.id)
        _G_StatusText = "Đang chuyển server..."
        task.wait(0.2)
        pcall(function() ReplicatedStorage:WaitForChild("__ServerBrowser", 5):InvokeServer("teleport", Server.id) end)
        task.wait(2)
        pcall(function() TeleportService:TeleportToPlaceInstance(CurrentPlaceId, Server.id, LocalPlayer) end)
    end
end

local function thucHienHopServer()
    while scriptRunning and currentRunID == _G.AntigravityRunID do
        hopLowServerFast()
        task.wait(6)
    end
end

-- Tắt màn hình 3D (Treo máy)
local function toggle3DRender(state)
    render3DEnabled = state
    pcall(function()
        RunService:Set3dRenderingEnabled(render3DEnabled)
    end)
end

-- =========================================================================
-- NOCLIP & PLATFORM VẬT LÝ
-- =========================================================================
local noclipConnection

local function updatePlatform()
    local char = LocalPlayer.Character
    if char and char:FindFirstChild("HumanoidRootPart") then
        local platform = workspace:FindFirstChild("FastFarmPlatform")
        if not platform then
            platform = Instance.new("Part")
            platform.Name = "FastFarmPlatform"
            platform.Parent = workspace
            platform.Anchored = true
            platform.Transparency = 1
            platform.Size = Vector3.new(15, 1, 15)
            platform.CanCollide = true
        end
        platform.CFrame = char.HumanoidRootPart.CFrame * CFrame.new(0, -3.5, 0)
    end
end

local function removePlatform()
    local platform = workspace:FindFirstChild("FastFarmPlatform")
    if platform then platform:Destroy() end
end

local function startNoclipAndPlatform()
    if not noclipConnection then
        noclipConnection = RunService.Stepped:Connect(function()
            local character = LocalPlayer.Character
            if character then
                for _, part in ipairs(character:GetDescendants()) do
                    if part:IsA("BasePart") then
                        part.CanCollide = false
                    end
                end
                updatePlatform()
            end
        end)
    end
end

local function stopNoclipAndPlatform()
    if noclipConnection then
        noclipConnection:Disconnect()
        noclipConnection = nil
    end
    removePlatform()
end

-- =========================================================================
-- LOGIC DI CHUYỂN TWEEN
-- =========================================================================
local function bayDen(targetCFrame, speed)
    local character = LocalPlayer.Character
    if not character then return end
    
    local hrp = character:FindFirstChild("HumanoidRootPart")
    if not hrp then return end
    
    local distance = (targetCFrame.Position - hrp.Position).Magnitude
    
    if distance > 100 then
        local duration = distance / speed
        local tweenInfo = TweenInfo.new(duration, Enum.EasingStyle.Linear)
        local tween = TweenService:Create(hrp, tweenInfo, {CFrame = targetCFrame})
        
        tween:Play()
        
        while tween.PlaybackState == Enum.PlaybackState.Playing and scriptRunning and currentRunID == _G.AntigravityRunID do
            task.wait(0.05)
        end
        
        if tween.PlaybackState == Enum.PlaybackState.Playing then
            tween:Cancel()
        end
    else
        hrp.CFrame = targetCFrame
    end
end

-- =========================================================================
-- QUÉT THỰC THỂ & ĐỐI TƯỢNG
-- =========================================================================
local function isPlayerOrClone(model)
    if not model or not model:IsA("Model") then return true end
    if Players:GetPlayerFromCharacter(model) then return true end
    
    local nameLower = model.Name:lower()
    local humanoid = model:FindFirstChildOfClass("Humanoid")
    local displayNameLower = humanoid and humanoid.DisplayName and humanoid.DisplayName:lower() or ""
    
    if string.find(nameLower, "shadow") or string.find(displayNameLower, "shadow") then
        return true
    end
    
    for _, player in ipairs(Players:GetPlayers()) do
        local pName = player.Name:lower()
        local pDisplayName = player.DisplayName:lower()
        if nameLower == pName or nameLower == pDisplayName 
           or displayNameLower == pName or displayNameLower == pDisplayName then
            return true
        end
    end
    return false
end

local function getNearestMonster(range)
    local myPos = getMyPosition()
    if not myPos then return nil end
    
    local targetEnemy = nil
    local lowestHealth = math.huge
    local shortestDistance = math.huge
    
    local function checkEnemy(enemy)
        if enemy:IsA("Model") and enemy:FindFirstChild("Humanoid") and enemy.Humanoid.Health > 0 then
            if not isPlayerOrClone(enemy) then
                local hrp = enemy:FindFirstChild("HumanoidRootPart")
                if hrp then
                    local dist = (hrp.Position - myPos).Magnitude
                    if dist <= range then
                        local hp = enemy.Humanoid.Health
                        if hp < lowestHealth then
                            lowestHealth = hp
                            shortestDistance = dist
                            targetEnemy = enemy
                        elseif hp == lowestHealth then
                            if dist < shortestDistance then
                                shortestDistance = dist
                                targetEnemy = enemy
                            end
                        end
                    end
                end
            end
        end
    end
    
    local enemies = workspace:FindFirstChild("Enemies")
    if enemies then
        for _, enemy in ipairs(enemies:GetChildren()) do
            checkEnemy(enemy)
        end
    end
    
    for _, obj in ipairs(workspace:GetChildren()) do
        if obj:IsA("Model") and obj.Name ~= LocalPlayer.Name then
            checkEnemy(obj)
        end
    end
    
    return targetEnemy
end

local function getNearestPlayer()
    local myPos = getMyPosition()
    if not myPos then return nil end
    local nearestPlr = nil
    local shortest = math.huge
    
    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= LocalPlayer and player.Character and player.Character:FindFirstChild("HumanoidRootPart") then
            local hrp = player.Character.HumanoidRootPart
            local dist = (hrp.Position - myPos).Magnitude
            if dist < shortest then
                shortest = dist
                nearestPlr = player
            end
        end
    end
    return nearestPlr
end

local function getCompassTarget()
    local playerGui = LocalPlayer:FindFirstChildOfClass("PlayerGui")
    local mainGui = playerGui and playerGui:FindFirstChild("Main")
    if not mainGui then return nil, nil end
    
    local compass = mainGui:FindFirstChild("Compass")
    if compass then
        for _, child in ipairs(compass:GetDescendants()) do
            if child:IsA("ObjectValue") and child.Value then
                local target = child.Value
                if target:IsA("BasePart") or target:IsA("Model") then
                    return target:GetPivot().Position, target
                end
            end
        end
        for _, child in ipairs(compass:GetDescendants()) do
            if child:IsA("Vector3Value") then
                return child.Value, nil
            end
        end
    end
    return nil, nil
end

-- =========================================================================
-- EVENT BOSS DETECTION
-- =========================================================================
local function isRipIndraSpawned()
    local enemies = workspace:FindFirstChild("Enemies")
    if enemies then
        for _, enemy in ipairs(enemies:GetChildren()) do
            if string.find(enemy.Name, "rip_indra") and enemy:FindFirstChild("Humanoid") and enemy.Humanoid.Health > 0 then
                return true
            end
        end
    end
    for _, obj in ipairs(ReplicatedStorage:GetChildren()) do
        if string.find(obj.Name, "rip_indra") and obj:FindFirstChild("Humanoid") then
            return true
        end
    end
    return false
end

local function isDarkbeardSpawned()
    local enemies = workspace:FindFirstChild("Enemies")
    if enemies then
        for _, enemy in ipairs(enemies:GetChildren()) do
            if string.find(enemy.Name, "Darkbeard") and enemy:FindFirstChild("Humanoid") and enemy.Humanoid.Health > 0 then
                return true
            end
        end
    end
    for _, obj in ipairs(ReplicatedStorage:GetChildren()) do
        if string.find(obj.Name, "Darkbeard") and obj:FindFirstChild("Humanoid") then
            return true
        end
    end
    return false
end

local function summonDarkbeard()
    local char = LocalPlayer.Character
    local tool = char and (char:FindFirstChild("Fist of Darkness") or LocalPlayer.Backpack:FindFirstChild("Fist of Darkness"))
    if tool then
        if tool.Parent == LocalPlayer.Backpack then
            char.Humanoid:EquipTool(tool)
            task.wait(0.2)
        end
        local detection = workspace:FindFirstChild("Map") 
            and workspace.Map:FindFirstChild("DarkbeardArena")
            and workspace.Map.DarkbeardArena:FindFirstChild("Summoner")
            and workspace.Map.DarkbeardArena.Summoner:FindFirstChild("Detection")
        
        if detection then
            if firetouchinterest then
                pcall(function() firetouchinterest(tool.Handle, detection, 0) end)
                pcall(function() firetouchinterest(tool.Handle, detection, 1) end)
                pcall(function() firetouchinterest(char.HumanoidRootPart, detection, 0) end)
                pcall(function() firetouchinterest(char.HumanoidRootPart, detection, 1) end)
            else
                char.HumanoidRootPart.CFrame = detection.CFrame
            end
        end
    end
end

-- =========================================================================
-- BỘ ĐIỀU PHỐI TRẠNG THÁI (PRIORITY STATE COORDINATOR)
-- =========================================================================
local function getCurrentState()
    if Config.AutoKillRipIndra and isRipIndraSpawned() then
        return "RipIndra"
    elseif Config.AutoKillDarkbeard and isDarkbeardSpawned() then
        return "Darkbeard"
    elseif Config.AutoFarmChest then
        return "ChestFarm"
    elseif Config.AutoFruitSniper and FruitFind() then
        return "FruitSniper"
    elseif Config.AutoFarm then
        return "AutoFarm"
    else
        return "Idle"
    end
end

-- Luồng di chuyển chính
task.spawn(function()
    while scriptRunning and currentRunID == _G.AntigravityRunID do
        task.wait(0.1)
        local state = getCurrentState()
        
        if state == "RipIndra" then
            _G_StatusText = "Săn Rip Indra..."
            pcall(function()
                if hasGodChalice() and not isRipIndraSpawned() then
                    for i, step in ipairs(HakiSteps) do
                        if not hasGodChalice() or isRipIndraSpawned() then break end
                        equipHakiColor(step.Name)
                        task.wait(0.3)
                        bayDen(step.Position, Config.FarmSpeed)
                        task.wait(0.2)
                        bayDen(step.Position * CFrame.new(0, 0, 1), Config.FarmSpeed)
                        task.wait(0.2)
                        bayDen(step.Position * CFrame.new(0, 0, -1), Config.FarmSpeed)
                        task.wait(0.5)
                    end
                    if hasGodChalice() and not isRipIndraSpawned() then
                        equipRareItem()
                        task.wait(0.3)
                        bayDen(SummonCFrame, Config.FarmSpeed)
                        task.wait(0.3)
                        bayDen(SummonCFrame * CFrame.new(0, 0, 2), Config.FarmSpeed)
                        task.wait(0.3)
                        bayDen(SummonCFrame, Config.FarmSpeed)
                        task.wait(2)
                    end
                else
                    local enemies = workspace:FindFirstChild("Enemies")
                    local boss = nil
                    if enemies then
                        for _, enemy in ipairs(enemies:GetChildren()) do
                            if string.find(enemy.Name, "rip_indra") and enemy:FindFirstChild("Humanoid") and enemy.Humanoid.Health > 0 then
                                boss = enemy; break
                            end
                        end
                    end
                    if not boss then
                        for _, obj in ipairs(ReplicatedStorage:GetChildren()) do
                            if string.find(obj.Name, "rip_indra") and obj:FindFirstChild("Humanoid") then
                                boss = obj; break
                            end
                        end
                    end
                    
                    if boss then
                        if boss.Parent == ReplicatedStorage then
                            local targetPos = boss:FindFirstChild("HumanoidRootPart") and boss.HumanoidRootPart.CFrame or CFrame.new(-5354.76, 423.85, -2701.32)
                            bayDen(targetPos, Config.FarmSpeed)
                        else
                            local hrp = boss:FindFirstChild("HumanoidRootPart")
                            local humanoid = boss:FindFirstChild("Humanoid")
                            if hrp and humanoid and humanoid.Health > 0 then
                                startNoclipAndPlatform()
                                equipWeapon(Config.WeaponType)
                                local animator = humanoid:FindFirstChild("Animator")
                                if animator then animator:Destroy() end
                                
                                local targetCFrame = hrp.CFrame * CFrame.new(0, Config.YOffset, 0)
                                bayDen(targetCFrame, Config.FarmSpeed)
                                
                                local char = LocalPlayer.Character
                                if char and char:FindFirstChild("HumanoidRootPart") then
                                    char.HumanoidRootPart.CFrame = CFrame.lookAt(targetCFrame.Position, hrp.Position)
                                end
                            end
                        end
                    else
                        _G_StatusText = "Săn Rip Indra Xong! Đang chuyển Server..."
                        thucHienHopServer()
                    end
                end
            end)
            
        elseif state == "Darkbeard" then
            _G_StatusText = "Săn Darkbeard..."
            pcall(function()
                if hasFistOfDarkness() and not isDarkbeardSpawned() then
                    equipRareItem()
                    task.wait(0.3)
                    local targetPos = DarkbeardSummonCFrame
                    pcall(function()
                        local detection = workspace.Map.DarkbeardArena.Summoner.Detection
                        if detection then targetPos = detection.CFrame end
                    end)
                    bayDen(targetPos, Config.FarmSpeed)
                    task.wait(0.5)
                    summonDarkbeard()
                    task.wait(0.5)
                    bayDen(targetPos * CFrame.new(0, 0, 2), Config.FarmSpeed)
                    task.wait(0.5)
                    bayDen(targetPos, Config.FarmSpeed)
                    task.wait(2)
                else
                    local enemies = workspace:FindFirstChild("Enemies")
                    local boss = nil
                    if enemies then
                        for _, enemy in ipairs(enemies:GetChildren()) do
                            if string.find(enemy.Name, "Darkbeard") and enemy:FindFirstChild("Humanoid") and enemy.Humanoid.Health > 0 then
                                boss = enemy; break
                            end
                        end
                    end
                    if not boss then
                        for _, obj in ipairs(ReplicatedStorage:GetChildren()) do
                            if string.find(obj.Name, "Darkbeard") and obj:FindFirstChild("Humanoid") then
                                boss = obj; break
                            end
                        end
                    end
                    
                    if boss then
                        if boss.Parent == ReplicatedStorage then
                            local targetPos = boss:FindFirstChild("HumanoidRootPart") and boss.HumanoidRootPart.CFrame or DarkbeardSummonCFrame
                            bayDen(targetPos, Config.FarmSpeed)
                        else
                            local hrp = boss:FindFirstChild("HumanoidRootPart")
                            local humanoid = boss:FindFirstChild("Humanoid")
                            if hrp and humanoid and humanoid.Health > 0 then
                                startNoclipAndPlatform()
                                equipWeapon(Config.WeaponType)
                                local animator = humanoid:FindFirstChild("Animator")
                                if animator then animator:Destroy() end
                                
                                local targetCFrame = hrp.CFrame * CFrame.new(0, Config.YOffset, 0)
                                bayDen(targetCFrame, Config.FarmSpeed)
                                
                                local char = LocalPlayer.Character
                                if char and char:FindFirstChild("HumanoidRootPart") then
                                    char.HumanoidRootPart.CFrame = CFrame.lookAt(targetCFrame.Position, hrp.Position)
                                end
                            end
                        end
                    else
                        _G_StatusText = "Săn Darkbeard Xong! Đang chuyển Server..."
                        thucHienHopServer()
                    end
                end
            end)
            
        elseif state == "ChestFarm" then
            _G_StatusText = "Farm rương..."
            pcall(function()
                if checkRareItems() then
                    Config.AutoFarmChest = false
                    return
                end
                local targetChest = getNearestChest()
                if targetChest then
                    startNoclipAndPlatform()
                    local chestPos = targetChest:GetPivot().Position
                    _G_StatusText = "Bay tới rương: " .. targetChest.Name
                    bayDen(CFrame.new(chestPos), Config.FarmSpeed)
                    
                    pcall(function()
                        if LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("Humanoid") then
                            LocalPlayer.Character.Humanoid.Jump = true
                        end
                    end)
                    
                    local waitTime = 0
                    while not targetChest:GetAttribute("IsDisabled") and targetChest.Parent ~= nil and waitTime < 0.4 do
                        task.wait(0.05)
                        waitTime = waitTime + 0.05
                    end
                    
                    countChests = countChests + 1
                    if countChests >= Config.ChestTargetLimit then
                        _G_StatusText = "Đạt giới hạn rương! Đang đổi server..."
                        thucHienHopServer()
                    end
                else
                    _G_StatusText = "Hết rương! Đang chuyển server..."
                    thucHienHopServer()
                end
            end)
            
        elseif state == "FruitSniper" then
            _G_StatusText = "Săn Trái ác quỷ..."
            pcall(function()
                local fruit = FruitFind()
                if fruit then
                    local handle = fruit:FindFirstChild("Handle")
                    if handle then
                        startNoclipAndPlatform()
                        bayDen(handle.CFrame, Config.FarmSpeed)
                        task.wait(0.2)
                        
                        local fruitTool = FindFruitInInventory()
                        if fruitTool then
                            _G_StatusText = "Đang cất: " .. fruit.Name
                            local stored = StoreFruitWithRetry(fruitTool)
                            _G_StatusText = stored and "Cất thành công! Đổi server..." or "Thất bại! Đổi server..."
                            task.wait(1)
                            thucHienHopServer()
                        end
                    end
                end
            end)
            
        elseif state == "AutoFarm" then
            pcall(function()
                local compassPos, compassTarget = getCompassTarget()
                if Config.AutoCompassTP and compassPos then
                    startNoclipAndPlatform()
                    _G_ActiveTarget = nil
                    _G_StatusText = "Bay theo La Bàn..."
                    
                    local targetCFrame = CFrame.new(compassPos + Vector3.new(0, 5, 0))
                    bayDen(targetCFrame, Config.FarmSpeed)
                    
                    local waitC = 0
                    while getCurrentState() == "AutoFarm" and getCompassTarget() and waitC < 5 do
                        local char = LocalPlayer.Character
                        if char and char:FindFirstChild("HumanoidRootPart") then
                            char.HumanoidRootPart.CFrame = targetCFrame
                        end
                        task.wait(0.1)
                        waitC = waitC + 0.1
                    end
                else
                    local enemy = getNearestMonster(Config.ScanRange)
                    if enemy and enemy:FindFirstChild("HumanoidRootPart") and enemy:FindFirstChild("Humanoid") and enemy.Humanoid.Health > 0 then
                        startNoclipAndPlatform()
                        _G_ActiveTarget = enemy
                        _G_StatusText = "Đang đánh: " .. enemy.Name
                        
                        local targetCFrame = enemy.HumanoidRootPart.CFrame * CFrame.new(0, Config.YOffset, 0)
                        bayDen(targetCFrame, Config.FarmSpeed)
                        
                        local waitTimeout = 0
                        while getCurrentState() == "AutoFarm" and enemy and enemy:FindFirstChild("Humanoid") and enemy.Humanoid.Health > 0 and waitTimeout < 10 do
                            if Config.AutoCompassTP and getCompassTarget() then break end
                            local char = LocalPlayer.Character
                            if char and char:FindFirstChild("HumanoidRootPart") then
                                local enemyPos = enemy.HumanoidRootPart.Position
                                local desiredPos = enemyPos + Vector3.new(0, Config.YOffset, 0)
                                char.HumanoidRootPart.CFrame = CFrame.lookAt(desiredPos, enemyPos)
                            end
                            task.wait(0.02)
                            waitTimeout = waitTimeout + 0.02
                        end
                        _G_ActiveTarget = nil
                    else
                        _G_ActiveTarget = nil
                        local targetPlayer = getNearestPlayer()
                        if targetPlayer and targetPlayer.Character and targetPlayer.Character:FindFirstChild("HumanoidRootPart") then
                            startNoclipAndPlatform()
                            _G_StatusText = "Không có quái, bay tới: " .. targetPlayer.DisplayName
                            local targetCFrame = targetPlayer.Character.HumanoidRootPart.CFrame * CFrame.new(0, 0, -6)
                            bayDen(targetCFrame, Config.FarmSpeed)
                        else
                            _G_StatusText = "Đang tìm quái..."
                            stopNoclipAndPlatform()
                            task.wait(0.5)
                        end
                    end
                end
            end)
        else
            _G_StatusText = "Đang chờ lệnh..."
            stopNoclipAndPlatform()
        end
    end
    stopNoclipAndPlatform()
end)

-- Luồng tấn công (Fast Attack / Kill Aura)
task.spawn(function()
    local RegisterAttack = ReplicatedStorage:WaitForChild("Modules"):WaitForChild("Net"):WaitForChild("RE/RegisterAttack")
    local RegisterHit = ReplicatedStorage:WaitForChild("Modules"):WaitForChild("Net"):WaitForChild("RE/RegisterHit")
    
    while scriptRunning and currentRunID == _G.AntigravityRunID do
        local cps = Config.AttackCPS or 20
        local delayTime = 0.05
        local hitCount = 1
        
        if cps <= 40 then
            delayTime = 1 / cps
            hitCount = 1
        else
            delayTime = 0.015
            hitCount = math.max(1, math.round(cps * 0.015))
        end
        
        task.wait(delayTime)
        
        local state = getCurrentState()
        if Config.FastAttack and state ~= "Idle" and state ~= "ChestFarm" then
            pcall(function()
                local myPos = getMyPosition()
                if not myPos then return end
                
                equipWeapon(Config.WeaponType)
                
                local targets = {}
                if _G_ActiveTarget and isAlive(_G_ActiveTarget) then
                    local root = _G_ActiveTarget:FindFirstChild("HumanoidRootPart") or _G_ActiveTarget.PrimaryPart
                    if root and (root.Position - myPos).Magnitude <= Config.ScanRange then
                        table.insert(targets, _G_ActiveTarget)
                    end
                end
                
                if #targets == 0 then
                    local enemies = workspace:FindFirstChild("Enemies")
                    if enemies then
                        for _, enemy in ipairs(enemies:GetChildren()) do
                            if isAlive(enemy) and not isPlayerOrClone(enemy) then
                                local root = enemy:FindFirstChild("HumanoidRootPart") or enemy.PrimaryPart
                                if root and (root.Position - myPos).Magnitude <= Config.ScanRange then
                                    table.insert(targets, enemy)
                                end
                            end
                        end
                    end
                end
                
                if #targets == 0 then
                    for _, obj in ipairs(workspace:GetChildren()) do
                        if obj:IsA("Model") and obj.Name ~= LocalPlayer.Name and isAlive(obj) and not isPlayerOrClone(obj) then
                            local root = obj:FindFirstChild("HumanoidRootPart") or obj.PrimaryPart
                            if root and (root.Position - myPos).Magnitude <= Config.ScanRange then
                                table.insert(targets, obj)
                            end
                        end
                    end
                end
                
                if #targets > 0 then
                    local targetsList = {}
                    local mainTarget = nil
                    for _, enemy in ipairs(targets) do
                        local head = enemy:FindFirstChild("Head") or enemy:FindFirstChild("HumanoidRootPart") or enemy.PrimaryPart
                        if head then
                            table.insert(targetsList, {enemy, head})
                            if not mainTarget then mainTarget = head end
                        end
                    end
                    
                    if mainTarget and #targetsList > 0 then
                        local hitFunction = getHitFunction()
                        local combatRemoteThread = false
                        pcall(function()
                            local modules = ReplicatedStorage:FindFirstChild("Modules")
                            local flags = modules and modules:FindFirstChild("Flags")
                            if flags then
                                combatRemoteThread = require(flags).COMBAT_REMOTE_THREAD or false
                            end
                        end)
                        
                        for i = 1, hitCount do
                            RegisterAttack:FireServer(0)
                            if combatRemoteThread and hitFunction then
                                hitFunction(mainTarget, targetsList)
                            else
                                RegisterHit:FireServer(mainTarget, targetsList)
                            end
                        end
                        pcall(function() VirtualUser:Button1Down(Vector2.new(1280, 720)) end)
                    end
                end
            end)
        end
    end
end)

-- Luồng duy trì Haki Quan Sát & Haki Vũ Trang
task.spawn(function()
    while scriptRunning and currentRunID == _G.AntigravityRunID do
        task.wait(1.0)
        if Config.AutoHaki then
            pcall(activateBuso)
        end
        if Config.AutoKen then
            pcall(activateKen)
        end
    end
end)

-- =========================================================================
-- GIAO DIỆN NGƯỜI DÙNG CHUYÊN NGHIỆP (CUSTOM NATIVE GLASSMORPHIC UI)
-- =========================================================================
local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "AntigravityUltimateUI"
ScreenGui.ResetOnSpawn = false
ScreenGui.Parent = parentUI

-- 1. NÚT TRÔI NỔI ĐỂ ĐÓNG MỞ (FLOATING BANNER BUTTON)
local FloatingBtn = Instance.new("ImageButton")
local FloatingCorner = Instance.new("UICorner")
local FloatingStroke = Instance.new("UIStroke")
local FloatingGradient = Instance.new("UIGradient")

FloatingBtn.Name = "FloatingBtn"
FloatingBtn.Size = UDim2.new(0, 52, 0, 52)
FloatingBtn.Position = UDim2.new(0.05, 0, 0.25, 0)
FloatingBtn.BackgroundColor3 = Color3.fromRGB(13, 13, 17)
FloatingBtn.Image = "rbxassetid://15694200676" -- Icon song kiếm sáng
FloatingBtn.ImageColor3 = Color3.fromRGB(0, 220, 255)
FloatingBtn.Visible = false
FloatingBtn.Parent = ScreenGui

FloatingCorner.CornerRadius = UDim.new(1, 0)
FloatingCorner.Parent = FloatingBtn

FloatingStroke.Thickness = 2.5
FloatingStroke.Color = Color3.fromRGB(0, 220, 255)
FloatingStroke.Parent = FloatingBtn

FloatingGradient.Color = ColorSequence.new({
    ColorSequenceKeypoint.new(0, Color3.fromRGB(0, 220, 255)),
    ColorSequenceKeypoint.new(0.5, Color3.fromRGB(170, 0, 255)),
    ColorSequenceKeypoint.new(1, Color3.fromRGB(0, 220, 255))
})
FloatingGradient.Parent = FloatingStroke

-- Kéo thả Floating Button
local function makeDraggable(gui, trigger)
    local dragging = false
    local dragInput, dragStart, startPos
    
    local function update(input)
        local delta = input.Position - dragStart
        gui.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
    end
    
    trigger.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            dragStart = input.Position
            startPos = gui.Position
            
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
makeDraggable(FloatingBtn, FloatingBtn)

-- 2. KHUNG MENU CHÍNH (MAIN PANEL)
local MainFrame = Instance.new("Frame")
local MainCorner = Instance.new("UICorner")
local MainStroke = Instance.new("UIStroke")
local MainGradient = Instance.new("UIGradient")

MainFrame.Name = "MainFrame"
MainFrame.Size = UDim2.new(0, 520, 0, 360)
MainFrame.Position = UDim2.new(0.5, -260, 0.5, -180)
MainFrame.BackgroundColor3 = Color3.fromRGB(13, 13, 17)
MainFrame.BackgroundTransparency = 0.12
MainFrame.Visible = true
MainFrame.Parent = ScreenGui

MainCorner.CornerRadius = UDim.new(0, 10)
MainCorner.Parent = MainFrame

MainStroke.Thickness = 2
MainStroke.Color = Color3.fromRGB(0, 220, 255)
MainStroke.Parent = MainFrame

MainGradient.Color = ColorSequence.new({
    ColorSequenceKeypoint.new(0, Color3.fromRGB(0, 220, 255)),
    ColorSequenceKeypoint.new(0.5, Color3.fromRGB(170, 0, 255)),
    ColorSequenceKeypoint.new(1, Color3.fromRGB(0, 220, 255))
})
MainGradient.Parent = MainStroke

-- Header dragging
local Header = Instance.new("Frame")
local HeaderCorner = Instance.new("UICorner")
Header.Name = "Header"
Header.Size = UDim2.new(1, 0, 0, 40)
Header.BackgroundColor3 = Color3.fromRGB(20, 20, 25)
Header.Parent = MainFrame
HeaderCorner.CornerRadius = UDim.new(0, 10)
HeaderCorner.Parent = Header
makeDraggable(MainFrame, Header)

-- Tiêu đề Menu
local TitleText = Instance.new("TextLabel")
TitleText.Size = UDim2.new(0.7, 0, 1, 0)
TitleText.Position = UDim2.new(0.04, 0, 0, 0)
TitleText.BackgroundTransparency = 1
TitleText.Text = "ANTIGRAVITY KAITUN PRO"
TitleText.TextColor3 = Color3.fromRGB(255, 255, 255)
TitleText.TextSize = 13
TitleText.Font = Enum.Font.GothamBold
TitleText.TextXAlignment = Enum.TextXAlignment.Left
TitleText.Parent = Header

-- Nút thu nhỏ (-)
local MinBtn = Instance.new("TextButton")
MinBtn.Name = "MinBtn"
MinBtn.Size = UDim2.new(0, 30, 0, 30)
MinBtn.Position = UDim2.new(0.86, -5, 0.5, -15)
MinBtn.BackgroundTransparency = 1
MinBtn.Text = "—"
MinBtn.TextColor3 = Color3.fromRGB(180, 180, 180)
MinBtn.TextSize = 14
MinBtn.Font = Enum.Font.GothamBold
MinBtn.Parent = Header

-- Nút đóng hẳn (X)
local CloseBtn = Instance.new("TextButton")
CloseBtn.Name = "CloseBtn"
CloseBtn.Size = UDim2.new(0, 30, 0, 30)
CloseBtn.Position = UDim2.new(0.94, -5, 0.5, -15)
CloseBtn.BackgroundTransparency = 1
CloseBtn.Text = "✕"
CloseBtn.TextColor3 = Color3.fromRGB(255, 70, 70)
CloseBtn.TextSize = 14
CloseBtn.Font = Enum.Font.GothamBold
CloseBtn.Parent = Header

-- Sidebar Panel (Trái)
local Sidebar = Instance.new("Frame")
local SB_Corner = Instance.new("UICorner")
Sidebar.Name = "Sidebar"
Sidebar.Size = UDim2.new(0, 130, 1, -40)
Sidebar.Position = UDim2.new(0, 0, 0, 40)
Sidebar.BackgroundColor3 = Color3.fromRGB(15, 15, 20)
Sidebar.Parent = MainFrame
SB_Corner.CornerRadius = UDim.new(0, 10)
SB_Corner.Parent = Sidebar

local sbLayout = Instance.new("UIListLayout")
sbLayout.Padding = UDim.new(0, 6)
sbLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
sbLayout.SortOrder = Enum.SortOrder.LayoutOrder
sbLayout.Parent = Sidebar

local sbPadding = Instance.new("UIPadding")
sbPadding.PaddingTop = UDim.new(0, 8)
sbPadding.Parent = Sidebar

-- Divider phân cách
local Divider = Instance.new("Frame")
Divider.Size = UDim2.new(0, 1, 1, -40)
Divider.Position = UDim2.new(0, 130, 0, 40)
Divider.BackgroundColor3 = Color3.fromRGB(45, 45, 50)
Divider.BorderSizePixel = 0
Divider.Parent = MainFrame

-- Content Container (Phải)
local ContentContainer = Instance.new("Frame")
ContentContainer.Size = UDim2.new(1, -130, 1, -40)
ContentContainer.Position = UDim2.new(0, 130, 0, 40)
ContentContainer.BackgroundTransparency = 1
ContentContainer.Parent = MainFrame

-- Helper Hover Effect
local function addHoverEffect(button, defaultColor, hoverColor)
    button.MouseEnter:Connect(function()
        TweenService:Create(button, TweenInfo.new(0.2), {BackgroundColor3 = hoverColor}):Play()
    end)
    button.MouseLeave:Connect(function()
        TweenService:Create(button, TweenInfo.new(0.2), {BackgroundColor3 = defaultColor}):Play()
    end)
end

-- =========================================================================
-- CÁC COMPONENT GIAO DIỆN (CREATION HELPERS)
-- =========================================================================

-- 1. SWITCH TOGGLE SWITCH SLIDER
local function createToggle(parent, configKey, titleText, callback)
    local frame = Instance.new("Frame")
    frame.Size = UDim2.new(0.94, 0, 0, 40)
    frame.BackgroundColor3 = Color3.fromRGB(20, 20, 25)
    frame.Parent = parent
    
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 6)
    corner.Parent = frame
    
    local stroke = Instance.new("UIStroke")
    stroke.Thickness = 1
    stroke.Color = Config[configKey] and Color3.fromRGB(0, 200, 255) or Color3.fromRGB(45, 45, 50)
    stroke.Parent = frame
    
    local title = Instance.new("TextLabel")
    title.Size = UDim2.new(0.7, 0, 1, 0)
    title.Position = UDim2.new(0.04, 0, 0, 0)
    title.BackgroundTransparency = 1
    title.Text = titleText
    title.TextColor3 = Color3.fromRGB(230, 230, 230)
    title.TextSize = 11
    title.Font = Enum.Font.GothamSemibold
    title.TextXAlignment = Enum.TextXAlignment.Left
    title.Parent = frame
    
    local switch = Instance.new("TextButton")
    switch.Size = UDim2.new(0, 45, 0, 22)
    switch.Position = UDim2.new(0.96, -45, 0.5, -11)
    switch.BackgroundColor3 = Config[configKey] and Color3.fromRGB(0, 200, 255) or Color3.fromRGB(50, 50, 55)
    switch.Text = ""
    switch.Parent = frame
    
    local switchCorner = Instance.new("UICorner")
    switchCorner.CornerRadius = UDim.new(1, 0)
    switchCorner.Parent = switch
    
    local knob = Instance.new("Frame")
    knob.Size = UDim2.new(0, 18, 0, 18)
    knob.Position = Config[configKey] and UDim2.new(1, -20, 0.5, -9) or UDim2.new(0, 2, 0.5, -9)
    knob.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    knob.Parent = switch
    
    local knobCorner = Instance.new("UICorner")
    knobCorner.CornerRadius = UDim.new(1, 0)
    knobCorner.Parent = knob
    
    local state = Config[configKey]
    
    local function updateVisuals()
        local targetColor = state and Color3.fromRGB(0, 200, 255) or Color3.fromRGB(50, 50, 55)
        local targetPos = state and UDim2.new(1, -20, 0.5, -9) or UDim2.new(0, 2, 0.5, -9)
        local strokeColor = state and Color3.fromRGB(0, 200, 255) or Color3.fromRGB(45, 45, 50)
        
        TweenService:Create(switch, TweenInfo.new(0.2), {BackgroundColor3 = targetColor}):Play()
        TweenService:Create(knob, TweenInfo.new(0.2), {Position = targetPos}):Play()
        TweenService:Create(stroke, TweenInfo.new(0.2), {Color = strokeColor}):Play()
    end
    
    switch.MouseButton1Click:Connect(function()
        state = not state
        Config[configKey] = state
        saveConfig()
        updateVisuals()
        if callback then callback(state) end
    end)
    
    task.spawn(function()
        while scriptRunning and currentRunID == _G.AntigravityRunID do
            task.wait(0.5)
            if Config[configKey] ~= state then
                state = Config[configKey]
                updateVisuals()
            end
        end
    end)
end

-- 2. ADJUSTABLE SLIDER
local function createSlider(parent, configKey, titleText, minVal, maxVal, unit, step, callback)
    local frame = Instance.new("Frame")
    frame.Size = UDim2.new(0.94, 0, 0, 55)
    frame.BackgroundColor3 = Color3.fromRGB(20, 20, 25)
    frame.Parent = parent
    
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 6)
    corner.Parent = frame
    
    local stroke = Instance.new("UIStroke")
    stroke.Thickness = 1
    stroke.Color = Color3.fromRGB(45, 45, 50)
    stroke.Parent = frame
    
    local title = Instance.new("TextLabel")
    title.Size = UDim2.new(0.6, 0, 0, 20)
    title.Position = UDim2.new(0.04, 0, 0, 5)
    title.BackgroundTransparency = 1
    title.Text = titleText
    title.TextColor3 = Color3.fromRGB(180, 180, 180)
    title.TextSize = 10
    title.Font = Enum.Font.GothamSemibold
    title.TextXAlignment = Enum.TextXAlignment.Left
    title.Parent = frame
    
    local valLabel = Instance.new("TextLabel")
    valLabel.Size = UDim2.new(0.3, 0, 0, 20)
    valLabel.Position = UDim2.new(0.66, 0, 0, 5)
    valLabel.BackgroundTransparency = 1
    valLabel.Text = Config[configKey] .. " " .. unit
    valLabel.TextColor3 = Color3.fromRGB(0, 220, 255)
    valLabel.TextSize = 10
    valLabel.Font = Enum.Font.Code
    valLabel.TextXAlignment = Enum.TextXAlignment.Right
    valLabel.Parent = frame
    
    local sliderBar = Instance.new("TextButton")
    sliderBar.Size = UDim2.new(0.92, 0, 0, 6)
    sliderBar.Position = UDim2.new(0.04, 0, 0, 35)
    sliderBar.BackgroundColor3 = Color3.fromRGB(40, 40, 45)
    sliderBar.Text = ""
    sliderBar.AutoButtonColor = false
    sliderBar.Parent = frame
    
    local barCorner = Instance.new("UICorner")
    barCorner.CornerRadius = UDim.new(1, 0)
    barCorner.Parent = sliderBar
    
    local fill = Instance.new("Frame")
    local pct = (Config[configKey] - minVal) / (maxVal - minVal)
    fill.Size = UDim2.new(pct, 0, 1, 0)
    fill.BackgroundColor3 = Color3.fromRGB(0, 220, 255)
    fill.Parent = sliderBar
    
    local fillCorner = Instance.new("UICorner")
    fillCorner.CornerRadius = UDim.new(1, 0)
    fillCorner.Parent = fill
    
    local handle = Instance.new("Frame")
    handle.Size = UDim2.new(0, 12, 0, 12)
    handle.Position = UDim2.new(pct, -6, 0.5, -6)
    handle.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    handle.Parent = sliderBar
    
    local handleCorner = Instance.new("UICorner")
    handleCorner.CornerRadius = UDim.new(1, 0)
    handleCorner.Parent = handle
    
    local handleStroke = Instance.new("UIStroke")
    handleStroke.Thickness = 1.5
    handleStroke.Color = Color3.fromRGB(0, 220, 255)
    handleStroke.Parent = handle
    
    local dragging = false
    local function updateValue(input)
        local relativeX = math.clamp((input.Position.X - sliderBar.AbsolutePosition.X) / sliderBar.AbsoluteSize.X, 0, 1)
        local value = minVal + relativeX * (maxVal - minVal)
        value = math.round(value / step) * step
        value = math.clamp(value, minVal, maxVal)
        
        Config[configKey] = value
        saveConfig()
        
        valLabel.Text = value .. " " .. unit
        local newPct = (value - minVal) / (maxVal - minVal)
        fill.Size = UDim2.new(newPct, 0, 1, 0)
        handle.Position = UDim2.new(newPct, -6, 0.5, -6)
        
        if callback then callback(value) end
    end
    
    sliderBar.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            updateValue(input)
        end
    end)
    
    UserInputService.InputChanged:Connect(function(input)
        if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
            updateValue(input)
        end
    end)
    
    UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = false
        end
    end)
end

-- 3. INTERACTIVE DROPDOWN
local function createDropdown(parent, configKey, titleText, options, callback)
    local frame = Instance.new("Frame")
    frame.Size = UDim2.new(0.94, 0, 0, 40)
    frame.BackgroundColor3 = Color3.fromRGB(20, 20, 25)
    frame.ClipsDescendants = true
    frame.Parent = parent
    
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 6)
    corner.Parent = frame
    
    local stroke = Instance.new("UIStroke")
    stroke.Thickness = 1
    stroke.Color = Color3.fromRGB(45, 45, 50)
    stroke.Parent = frame
    
    local title = Instance.new("TextLabel")
    title.Size = UDim2.new(0.5, 0, 0, 40)
    title.Position = UDim2.new(0.04, 0, 0, 0)
    title.BackgroundTransparency = 1
    title.Text = titleText
    title.TextColor3 = Color3.fromRGB(230, 230, 230)
    title.TextSize = 11
    title.Font = Enum.Font.GothamSemibold
    title.TextXAlignment = Enum.TextXAlignment.Left
    title.Parent = frame
    
    local button = Instance.new("TextButton")
    button.Size = UDim2.new(0.4, 0, 0, 26)
    button.Position = UDim2.new(0.96, -140, 0.5, -13)
    button.BackgroundColor3 = Color3.fromRGB(30, 30, 35)
    button.Text = tostring(Config[configKey])
    button.TextColor3 = Color3.fromRGB(0, 220, 255)
    button.TextSize = 10
    button.Font = Enum.Font.GothamBold
    button.Parent = frame
    
    local btnCorner = Instance.new("UICorner")
    btnCorner.CornerRadius = UDim.new(0, 4)
    btnCorner.Parent = button
    
    local btnStroke = Instance.new("UIStroke")
    btnStroke.Thickness = 1
    btnStroke.Color = Color3.fromRGB(55, 55, 60)
    btnStroke.Parent = button
    
    local list = Instance.new("Frame")
    list.Size = UDim2.new(0.92, 0, 0, #options * 26)
    list.Position = UDim2.new(0.04, 0, 0, 44)
    list.BackgroundTransparency = 1
    list.Parent = frame
    
    local listLayout = Instance.new("UIListLayout")
    listLayout.Padding = UDim.new(0, 4)
    listLayout.SortOrder = Enum.SortOrder.LayoutOrder
    listLayout.Parent = list
    
    local open = false
    
    local function setDropdownOpen(isOpen)
        open = isOpen
        local targetHeight = open and (48 + #options * 30) or 40
        TweenService:Create(frame, TweenInfo.new(0.25, Enum.EasingStyle.Quad), {Size = UDim2.new(0.94, 0, 0, targetHeight)}):Play()
        button.TextColor3 = open and Color3.fromRGB(255, 255, 255) or Color3.fromRGB(0, 220, 255)
        btnStroke.Color = open and Color3.fromRGB(0, 220, 255) or Color3.fromRGB(55, 55, 60)
    end
    
    button.MouseButton1Click:Connect(function()
        setDropdownOpen(not open)
    end)
    
    for i, opt in ipairs(options) do
        local optBtn = Instance.new("TextButton")
        optBtn.Size = UDim2.new(1, 0, 0, 26)
        optBtn.BackgroundColor3 = opt == Config[configKey] and Color3.fromRGB(0, 120, 255) or Color3.fromRGB(30, 30, 35)
        optBtn.Text = tostring(opt)
        optBtn.TextColor3 = Color3.fromRGB(240, 240, 240)
        optBtn.TextSize = 10
        optBtn.Font = Enum.Font.GothamSemibold
        optBtn.LayoutOrder = i
        optBtn.Parent = list
        
        local optCorner = Instance.new("UICorner")
        optCorner.CornerRadius = UDim.new(0, 4)
        optCorner.Parent = optBtn
        
        optBtn.MouseButton1Click:Connect(function()
            Config[configKey] = opt
            saveConfig()
            button.Text = tostring(opt)
            setDropdownOpen(false)
            
            for _, child in ipairs(list:GetChildren()) do
                if child:IsA("TextButton") then
                    child.BackgroundColor3 = child.Text == tostring(opt) and Color3.fromRGB(0, 120, 255) or Color3.fromRGB(30, 30, 35)
                end
            end
            if callback then callback(opt) end
        end)
    end
end

-- 4. TEXT INPUT BOX
local function createInput(parent, configKey, titleText, placeholderText, callback)
    local frame = Instance.new("Frame")
    frame.Size = UDim2.new(0.94, 0, 0, 40)
    frame.BackgroundColor3 = Color3.fromRGB(20, 20, 25)
    frame.Parent = parent
    
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 6)
    corner.Parent = frame
    
    local stroke = Instance.new("UIStroke")
    stroke.Thickness = 1
    stroke.Color = Color3.fromRGB(45, 45, 50)
    stroke.Parent = frame
    
    local title = Instance.new("TextLabel")
    title.Size = UDim2.new(0.4, 0, 1, 0)
    title.Position = UDim2.new(0.04, 0, 0, 0)
    title.BackgroundTransparency = 1
    title.Text = titleText
    title.TextColor3 = Color3.fromRGB(230, 230, 230)
    title.TextSize = 11
    title.Font = Enum.Font.GothamSemibold
    title.TextXAlignment = Enum.TextXAlignment.Left
    title.Parent = frame
    
    local box = Instance.new("TextBox")
    box.Size = UDim2.new(0.5, 0, 0, 26)
    box.Position = UDim2.new(0.96, -170, 0.5, -13)
    box.BackgroundColor3 = Color3.fromRGB(30, 30, 35)
    box.Text = Config[configKey] or ""
    box.PlaceholderText = placeholderText
    box.TextColor3 = Color3.fromRGB(255, 255, 255)
    box.TextSize = 10
    box.Font = Enum.Font.Gotham
    box.Parent = frame
    
    local boxCorner = Instance.new("UICorner")
    boxCorner.CornerRadius = UDim.new(0, 4)
    boxCorner.Parent = box
    
    local boxStroke = Instance.new("UIStroke")
    boxStroke.Thickness = 1
    boxStroke.Color = Color3.fromRGB(55, 55, 60)
    boxStroke.Parent = box
    
    box.FocusLost:Connect(function(enterPressed)
        Config[configKey] = box.Text
        saveConfig()
        if callback then callback(box.Text) end
    end)
end

-- 5. INTERACTIVE BUTTON
local function createButton(parent, text, callback)
    local button = Instance.new("TextButton")
    button.Size = UDim2.new(0.94, 0, 0, 36)
    button.BackgroundColor3 = Color3.fromRGB(0, 120, 255)
    button.Text = text
    button.TextColor3 = Color3.fromRGB(255, 255, 255)
    button.TextSize = 11
    button.Font = Enum.Font.GothamBold
    button.Parent = parent
    
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 6)
    corner.Parent = button
    
    local stroke = Instance.new("UIStroke")
    stroke.Thickness = 1
    stroke.Color = Color3.fromRGB(0, 200, 255)
    stroke.Parent = button
    
    button.MouseButton1Click:Connect(function()
        local origSize = button.Size
        TweenService:Create(button, TweenInfo.new(0.1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out, 0, true), {
            Size = UDim2.new(origSize.X.Scale, origSize.X.Offset - 10, origSize.Y.Scale, origSize.Y.Offset - 2)
        }):Play()
        task.wait(0.08)
        if callback then callback() end
    end)
    
    addHoverEffect(button, Color3.fromRGB(0, 120, 255), Color3.fromRGB(0, 140, 255))
end

-- =========================================================================
-- HỆ THỐNG PHÂN TAB DƯỚI DẠNG DANH SÁCH CUỘN (SCROLLING PAGE TABS)
-- =========================================================================
local tabs = {}
local activeTab = nil
local tabButtons = {}

local function createTab(name)
    local tabScroll = Instance.new("ScrollingFrame")
    tabScroll.Size = UDim2.new(1, -12, 1, -12)
    tabScroll.Position = UDim2.new(0, 6, 0, 6)
    tabScroll.BackgroundTransparency = 1
    tabScroll.CanvasSize = UDim2.new(0, 0, 0, 520)
    tabScroll.ScrollBarThickness = 3
    tabScroll.ScrollBarImageColor3 = Color3.fromRGB(0, 220, 255)
    tabScroll.Visible = false
    tabScroll.Parent = ContentContainer
    
    local listLayout = Instance.new("UIListLayout")
    listLayout.Padding = UDim.new(0, 8)
    listLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
    listLayout.SortOrder = Enum.SortOrder.LayoutOrder
    listLayout.Parent = tabScroll
    
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(0.9, 0, 0, 36)
    btn.BackgroundColor3 = Color3.fromRGB(20, 20, 25)
    btn.Text = name
    btn.TextColor3 = Color3.fromRGB(150, 150, 160)
    btn.TextSize = 11
    btn.Font = Enum.Font.GothamSemibold
    btn.Parent = Sidebar
    
    local btnCorner = Instance.new("UICorner")
    btnCorner.CornerRadius = UDim.new(0, 6)
    btnCorner.Parent = btn
    
    local btnStroke = Instance.new("UIStroke")
    btnStroke.Thickness = 1
    btnStroke.Color = Color3.fromRGB(35, 35, 40)
    btnStroke.Parent = btn
    
    local leftGlow = Instance.new("Frame")
    leftGlow.Size = UDim2.new(0, 4, 0.6, 0)
    leftGlow.Position = UDim2.new(0, 4, 0.2, 0)
    leftGlow.BackgroundColor3 = Color3.fromRGB(0, 220, 255)
    leftGlow.Visible = false
    leftGlow.Parent = btn
    local lgCorner = Instance.new("UICorner")
    lgCorner.CornerRadius = UDim.new(1, 0)
    lgCorner.Parent = leftGlow
    
    tabs[name] = tabScroll
    tabButtons[name] = {btn = btn, glow = leftGlow, stroke = btnStroke}
    
    local function select()
        if activeTab == name then return end
        activeTab = name
        
        for tName, scroll in pairs(tabs) do
            if tName == name then
                scroll.Visible = true
                tabButtons[tName].btn.BackgroundColor3 = Color3.fromRGB(30, 30, 40)
                tabButtons[tName].btn.TextColor3 = Color3.fromRGB(255, 255, 255)
                tabButtons[tName].glow.Visible = true
                tabButtons[tName].stroke.Color = Color3.fromRGB(0, 220, 255)
            else
                scroll.Visible = false
                tabButtons[tName].btn.BackgroundColor3 = Color3.fromRGB(20, 20, 25)
                tabButtons[tName].btn.TextColor3 = Color3.fromRGB(150, 150, 160)
                tabButtons[tName].glow.Visible = false
                tabButtons[tName].stroke.Color = Color3.fromRGB(35, 35, 40)
            end
        end
    end
    
    btn.MouseButton1Click:Connect(select)
    
    return tabScroll, select
end

-- Khởi tạo các Tab (Bổ sung Tab Bảng Thống Kê / Dashboard lên đầu)
local TabDashboard, selectDashboard = createTab("Bảng Thống kê")
local TabCombat, _ = createTab("Farm & Tấn công")
local TabBoss, _ = createTab("Boss & Rương")
local TabFruit, _ = createTab("Săn Trái cây")
local TabSystem, _ = createTab("Hệ thống")

selectDashboard() -- Mở tab Bảng Thống Kê mặc định

-- =========================================================================
-- KHỞI TẠO NỘI DUNG TỪNG TAB
-- =========================================================================

-- 1. TAB BẢNG THỐNG KÊ (DASHBOARD)
local StatsGrid = Instance.new("Frame")
StatsGrid.Size = UDim2.new(0.94, 0, 0, 130)
StatsGrid.BackgroundTransparency = 1
StatsGrid.Parent = TabDashboard

local function createStatCard(parent, labelText, iconText, startVal, color, pos)
    local card = Instance.new("Frame")
    card.Size = UDim2.new(0.48, -4, 0, 60)
    card.Position = pos
    card.BackgroundColor3 = Color3.fromRGB(20, 20, 25)
    card.Parent = parent
    
    local cardCorner = Instance.new("UICorner")
    cardCorner.CornerRadius = UDim.new(0, 8)
    cardCorner.Parent = card
    
    local cardStroke = Instance.new("UIStroke")
    cardStroke.Color = Color3.fromRGB(45, 45, 50)
    cardStroke.Thickness = 1
    cardStroke.Parent = card
    
    local icon = Instance.new("TextLabel")
    icon.Size = UDim2.new(0, 20, 0, 20)
    icon.Position = UDim2.new(0, 10, 0, 5)
    icon.BackgroundTransparency = 1
    icon.Text = iconText
    icon.TextColor3 = color
    icon.TextSize = 11
    icon.Font = Enum.Font.GothamBold
    icon.TextXAlignment = Enum.TextXAlignment.Left
    icon.Parent = card
    
    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(0.7, 0, 0, 20)
    label.Position = UDim2.new(0, 30, 0, 5)
    label.BackgroundTransparency = 1
    label.Text = labelText
    label.TextColor3 = Color3.fromRGB(160, 160, 170)
    label.TextSize = 10
    label.Font = Enum.Font.GothamSemibold
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.Parent = card
    
    local val = Instance.new("TextLabel")
    val.Size = UDim2.new(1, -20, 0, 30)
    val.Position = UDim2.new(0, 10, 0, 25)
    val.BackgroundTransparency = 1
    val.Text = tostring(startVal)
    val.TextColor3 = Color3.fromRGB(255, 255, 255)
    val.TextSize = 15
    val.Font = Enum.Font.GothamBold
    val.TextXAlignment = Enum.TextXAlignment.Left
    val.Parent = card
    
    return val
end

local levelVal = createStatCard(StatsGrid, "Cấp độ (Level)", "Lv", "0", Color3.fromRGB(170, 130, 255), UDim2.new(0, 0, 0, 0))
local beliVal = createStatCard(StatsGrid, "Tiền (Beli)", "₿", "0", Color3.fromRGB(230, 180, 50), UDim2.new(0.5, 4, 0, 0))
local bountyVal = createStatCard(StatsGrid, "Bounty / Honor", "✪", "0", Color3.fromRGB(240, 80, 80), UDim2.new(0, 0, 0, 65))
local fragVal = createStatCard(StatsGrid, "F các mảnh (Frag)", "◆", "0", Color3.fromRGB(80, 220, 120), UDim2.new(0.5, 4, 0, 65))

-- Checklist Panel
local ChecklistFrame = Instance.new("Frame")
ChecklistFrame.Size = UDim2.new(0.94, 0, 0, 110)
ChecklistFrame.BackgroundColor3 = Color3.fromRGB(20, 20, 25)
ChecklistFrame.Parent = TabDashboard
local ckCorner = Instance.new("UICorner")
ckCorner.CornerRadius = UDim.new(0, 8)
ckCorner.Parent = ChecklistFrame
local ckStroke = Instance.new("UIStroke")
ckStroke.Color = Color3.fromRGB(45, 45, 50)
ckStroke.Thickness = 1
ckStroke.Parent = ChecklistFrame

local ckTitle = Instance.new("TextLabel")
ckTitle.Size = UDim2.new(1, -16, 0, 20)
ckTitle.Position = UDim2.new(0, 8, 0, 4)
ckTitle.BackgroundTransparency = 1
ckTitle.Text = "Kiểm tra tiến độ tài khoản (Checklist)"
ckTitle.TextColor3 = Color3.fromRGB(150, 150, 160)
ckTitle.TextSize = 10
ckTitle.Font = Enum.Font.GothamBold
ckTitle.TextXAlignment = Enum.TextXAlignment.Left
ckTitle.Parent = ChecklistFrame

local progressLabel = Instance.new("TextLabel")
progressLabel.Size = UDim2.new(1, -16, 0, 80)
progressLabel.Position = UDim2.new(0, 8, 0, 24)
progressLabel.BackgroundTransparency = 1
progressLabel.Text = "Godhuman: ❌\nSoul Guitar: ❌\nCursed Dual Katana: ❌\nTemple Lever: ❌"
progressLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
progressLabel.TextSize = 11
progressLabel.Font = Enum.Font.Gotham
progressLabel.LineHeight = 1.3
progressLabel.TextXAlignment = Enum.TextXAlignment.Left
progressLabel.Parent = ChecklistFrame

-- Race + Session timer Frame
local InfoGrid = Instance.new("Frame")
InfoGrid.Size = UDim2.new(0.94, 0, 0, 50)
InfoGrid.BackgroundTransparency = 1
InfoGrid.Parent = TabDashboard

local raceLabel = Instance.new("TextLabel")
raceLabel.Size = UDim2.new(0.5, -4, 1, 0)
raceLabel.BackgroundTransparency = 1
raceLabel.Text = "Chủng tộc: Đang đọc..."
raceLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
raceLabel.TextSize = 11
raceLabel.Font = Enum.Font.GothamSemibold
raceLabel.TextXAlignment = Enum.TextXAlignment.Left
raceLabel.Parent = InfoGrid

local sessionLabel = Instance.new("TextLabel")
sessionLabel.Size = UDim2.new(0.5, -4, 1, 0)
sessionLabel.Position = UDim2.new(0.5, 4, 0, 0)
sessionLabel.BackgroundTransparency = 1
sessionLabel.Text = "Thời gian chạy: 00:00:00"
sessionLabel.TextColor3 = Color3.fromRGB(170, 130, 255)
sessionLabel.TextSize = 11
sessionLabel.Font = Enum.Font.Code
sessionLabel.TextXAlignment = Enum.TextXAlignment.Right
sessionLabel.Parent = InfoGrid

-- Run Kaitun button
createButton(TabDashboard, "Khởi động Kaitun Farm Module", function()
    loadKaitunModule()
end)

-- Luồng cập nhật Dashboard liên tục
local function updateDashboard()
    local lv, bel, bty, frg, rc = getPlayerData()
    levelVal.Text = tostring(lv)
    beliVal.Text = tostring(bel)
    bountyVal.Text = tostring(bty)
    fragVal.Text = tostring(frg)
    raceLabel.Text = "Chủng tộc: " .. tostring(rc)
    
    local elapsed = os.time() - sessionStartTime
    local h = math.floor(elapsed / 3600)
    local m = math.floor((elapsed % 3600) / 60)
    local s = elapsed % 60
    sessionLabel.Text = string.format("Thời gian chạy: %02d:%02d:%02d", h, m, s)
    
    local god, guitar, cdk, lever = getFarmProgress()
    progressLabel.Text = string.format(
        "Godhuman: %s\nSoul Guitar: %s\nCursed Dual Katana: %s\nTemple Lever: %s",
        god and "✅" or "❌",
        guitar and "✅" or "❌",
        cdk and "✅" or "❌",
        lever and "✅" or "❌"
    )
end

task.spawn(function()
    while scriptRunning and currentRunID == _G.AntigravityRunID do
        pcall(updateDashboard)
        task.wait(1.5)
    end
end)


-- 2. TAB COMBAT (FARM & TẤN CÔNG)
createToggle(TabCombat, "AutoFarm", "Tự động Farm quái & La bàn", function(val)
    if val then
        selectTeam()
    end
end)

createToggle(TabCombat, "FastAttack", "Fast Attack (Đánh siêu nhanh)")

createDropdown(TabCombat, "WeaponType", "Trang bị vũ khí sử dụng", {"Melee", "Sword"})

createSlider(TabCombat, "AttackCPS", "Tốc độ đánh (Đòn/giây)", 1, 100, "cps", 1)

createSlider(TabCombat, "ScanRange", "Phạm vi quét quái", 50, 600, "studs", 25)

createSlider(TabCombat, "YOffset", "Khoảng cách đứng trên đầu quái", -20, 60, "studs", 5)

createSlider(TabCombat, "FarmSpeed", "Tốc độ bay Tween", 100, 450, "studs/s", 10)

createToggle(TabCombat, "AutoHaki", "Tự kích hoạt Haki Vũ Trang (Buso)")

createToggle(TabCombat, "AutoKen", "Tự kích hoạt Haki Quan Sát (Ken)")

createToggle(TabCombat, "AutoCompassTP", "Ưu tiên bay theo La bàn chỉ đường")


-- 3. TAB BOSS & RƯƠNG
createToggle(TabBoss, "AutoFarmChest", "Auto nhặt Rương tiền")

createSlider(TabBoss, "ChestTargetLimit", "Số rương tối đa rồi đổi Server", 10, 200, "rương", 5)

createToggle(TabBoss, "AutoKillRipIndra", "Tự gọi & Diệt Boss Rip Indra (Sea 3)")

createToggle(TabBoss, "AutoKillDarkbeard", "Tự gọi & Diệt Boss Darkbeard (Sea 2)")

createButton(TabBoss, "Đổi Server (Hop Low-Player Server)", function()
    task.spawn(thucHienHopServer)
end)


-- 4. TAB SĂN TRÁI CÂY (FRUIT SNIPER)
createToggle(TabFruit, "AutoFruitSniper", "Auto nhặt & Cất Trái ác quỷ")

createToggle(TabFruit, "FruitESP", "Bật vẽ ESP Trái ác quỷ")

createSlider(TabFruit, "StoreRetries", "Số lần thử cất Trái ác quỷ", 1, 10, "lần", 1)

createInput(TabFruit, "DiscordWebhook", "Discord Webhook URL", "Nhập Webhook để nhận thông báo...", function(val)
    print("📢 [Antigravity] Cập nhật webhook URL.")
end)


-- 5. TAB HỆ THỐNG (SYSTEM & UTILITIES)
createToggle(TabSystem, "LowGraphics", "Giảm đồ họa & Tối ưu hóa (Giảm Lag)", function(val)
    if val then optimizeGraphics() end
end)

local RenderBtn = Instance.new("TextButton")
RenderBtn.Size = UDim2.new(0.94, 0, 0, 36)
RenderBtn.BackgroundColor3 = Color3.fromRGB(50, 15, 75)
RenderBtn.Text = "Tắt Màn Hình 3D (Treo máy)"
RenderBtn.TextColor3 = Color3.fromRGB(240, 220, 255)
RenderBtn.TextSize = 11
RenderBtn.Font = Enum.Font.GothamBold
RenderBtn.Parent = TabSystem
local RB_Corner = Instance.new("UICorner")
RB_Corner.CornerRadius = UDim.new(0, 6)
RB_Corner.Parent = RenderBtn
local RB_Stroke = Instance.new("UIStroke")
RB_Stroke.Color = Color3.fromRGB(160, 50, 255)
RB_Stroke.Thickness = 1
RB_Stroke.Parent = RenderBtn

RenderBtn.MouseButton1Click:Connect(function()
    toggle3DRender(not render3DEnabled)
    if render3DEnabled then
        RenderBtn.Text = "Tắt Màn Hình 3D (Treo máy)"
        RenderBtn.BackgroundColor3 = Color3.fromRGB(50, 15, 75)
    else
        RenderBtn.Text = "Mở lại Màn Hình 3D (Ấn P)"
        RenderBtn.BackgroundColor3 = Color3.fromRGB(180, 40, 40)
    end
end)

createToggle(TabSystem, "AutoSelectTeam", "Tự động chọn Phe khi khởi chạy", function(val)
    if val then selectTeam() end
end)

createDropdown(TabSystem, "Team", "Chọn Phe mặc định", {"Marines", "Pirates"}, function(val)
    Config.Team = (val == "Marines") and 0 or 1
    saveConfig()
end)

local InfoLabel = Instance.new("TextLabel")
InfoLabel.Size = UDim2.new(0.94, 0, 0, 45)
InfoLabel.BackgroundTransparency = 1
InfoLabel.Text = "Tốc độ đập: 20 cps\nTrạng thái: Đang chờ lệnh..."
InfoLabel.TextColor3 = Color3.fromRGB(140, 140, 140)
InfoLabel.TextSize = 10
InfoLabel.Font = Enum.Font.SourceSansItalic
InfoLabel.Parent = TabSystem

createButton(TabSystem, "Dừng & Hủy bỏ Script (Unload)", function()
    scriptRunning = false
    Config.FastAttack = false
    Config.AutoFarm = false
    Config.AutoFarmChest = false
    Config.AutoFruitSniper = false
    toggle3DRender(true)
    stopNoclipAndPlatform()
    ScreenGui:Destroy()
    print("🛑 [Antigravity] Đã đóng UI và dừng toàn bộ luồng hoạt động.")
end)

-- =========================================================================
-- LOGIC ĐÓNG/MỞ BANNER TỰ ĐỘNG & REALTIME UPDATE
-- =========================================================================
FloatingBtn.MouseButton1Click:Connect(function()
    MainFrame.Visible = true
    FloatingBtn.Visible = false
end)

MinBtn.MouseButton1Click:Connect(function()
    MainFrame.Visible = false
    FloatingBtn.Visible = true
end)

CloseBtn.MouseButton1Click:Connect(function()
    scriptRunning = false
    Config.FastAttack = false
    Config.AutoFarm = false
    Config.AutoFarmChest = false
    Config.AutoFruitSniper = false
    toggle3DRender(true)
    stopNoclipAndPlatform()
    ScreenGui:Destroy()
    print("🛑 [Antigravity] Đã đóng UI và dừng toàn bộ luồng hoạt động.")
end)

-- Đồng bộ realtime trạng thái lên nhãn Info
task.spawn(function()
    while scriptRunning and currentRunID == _G.AntigravityRunID do
        task.wait(0.2)
        pcall(function()
            InfoLabel.Text = "Tốc độ đập: " .. (Config.AttackCPS or 20) .. " cps\nTrạng thái: " .. _G_StatusText
            if getCurrentState() ~= "Idle" then
                InfoLabel.TextColor3 = Color3.fromRGB(0, 220, 255)
            else
                InfoLabel.TextColor3 = Color3.fromRGB(140, 140, 140)
            end
        end)
    end
end)

-- Triển khai chọn team tự động lúc đầu
task.spawn(function()
    task.wait(2.5)
    selectTeam()
end)

print("⚡ [Antigravity Pro] Đã nạp thành công phiên bản tích hợp tối ưu tại test.lua!")
