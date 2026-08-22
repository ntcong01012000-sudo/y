--[[
    ========================================================================================
    🍩 BLOX FRUITS - KATAKURI ULTRA FARM & SMART SERVER HOPPER (PRO EDITION) 🍩
    ========================================================================================
    ✨ TÍNH NĂNG ĐỘT PHÁ:
      1. Centralized Katakuri Tracker:
         - 1 luồng duy nhất định kỳ 1.5s truy vấn CakePrinceSpawner, triệt tiêu 100% tình trạng spam/nghẽn RemoteFunction.
         - Phân tích chính xác số quái CÒN LẠI (Remaining) & ĐÃ DIỆT (Killed = 500 - Remaining).
      2. Tự Động Kiểm Tra & Lọc Server Thông Minh Khi Mới Vào:
         - Nếu server CÒN PHẢI ĐÁNH HƠN 200 con (đã diệt < 300 con) -> TỰ ĐỘNG ĐỔI SERVER NGAY.
         - Nếu server ĐÃ DIỆT ÍT NHẤT 300/500 con (còn lại <= 200 con / Cổng mở / Có Boss) -> Ở lại và TỰ ĐỘNG BẬT FARM!
      3. Tự Động Đổi Server Sau Khi Diệt Boss: Khi boss Katakuri chết -> Tự động chuyển ngay sang server ngẫu nhiên mới chưa vào.
      4. Server Browser Random Hop Siêu Tốc:
         - Quét song song Asc & Desc, lọc server còn chỗ (1-11 người).
         - Kết nối qua __ServerBrowser và TeleportToPlaceInstance với vòng lặp thử lần lượt từng server.
         - Dự phòng TeleportService:Teleport(placeId) đảm bảo 100% đổi server thành công.
      5. Tự Động Trang Bị Melee (Cận chiến) liên tục trong suốt trận đánh.
      6. Tự Động Bật Tộc V4 (Awakening - Phím Y) & Tộc V3 (Ability - Phím T) & Haki (Buso, Ken).
      7. Triệt tiêu 100% trọng lực bằng BodyVelocity (9e9) - Lơ lửng 15 studs không bị rơi/giật và quái không thể đánh trúng.
      8. Gom Quái Magnet 60x60 (SimulationRadius huge + ChangeState 11, 14 - Không bị đơ quái).
      9. Đánh Siêu Nhanh x4 (100 CPS Multi Burst + Bypass Cooldown CombatFramework).
      10. Tự Động Nhận Nhiệm Vụ (Auto Quest Beli & EXP).
      11. Tự Động Chọn Phe Hải Tặc (Auto Set Team Pirates) & Lưu/Tải Cấu Hình theo tên người dùng.
      12. Dashboard Katakuri chi tiết & GUI Icon trôi nổi (🍩) kéo thả tiện lợi trên PC/Mobile.
    ========================================================================================
--]]

if not game:IsLoaded() then
    game.Loaded:Wait()
end

-- ==================== KHỞI TẠO DỊCH VỤ ====================
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local TeleportService = game:GetService("TeleportService")
local UIS = game:GetService("UserInputService")
local VIM = game:GetService("VirtualInputManager")
local VU = game:GetService("VirtualUser")
local HttpService = game:GetService("HttpService")
local CoreGui = game:GetService("CoreGui")

local LP = Players.LocalPlayer or Players:GetPropertyChangedSignal("LocalPlayer"):Wait() or Players.LocalPlayer
_G.KatakuriFarmID = (_G.KatakuriFarmID or 0) + 1
local scriptID = _G.KatakuriFarmID

-- Tắt rung lắc camera để góc nhìn mượt mà
pcall(function()
    if RS:FindFirstChild("Util") and RS.Util:FindFirstChild("CameraShaker") then
        require(RS.Util.CameraShaker):Stop()
    end
end)

-- Quản lý GUI chứa
local parentGui = pcall(function() local _ = CoreGui.Name end) and CoreGui or LP:WaitForChild("PlayerGui", 10)
pcall(function()
    if parentGui:FindFirstChild("KatakuriFarmGui") then parentGui.KatakuriFarmGui:Destroy() end
    if CoreGui:FindFirstChild("KatakuriFarmGui") then CoreGui.KatakuriFarmGui:Destroy() end
    if LP.PlayerGui:FindFirstChild("KatakuriFarmGui") then LP.PlayerGui.KatakuriFarmGui:Destroy() end
end)

-- ==================== CẤU HÌNH & TỰ LƯU / NẠP THEO USER ====================
local userName = LP.Name
local saveFile = "BloxFruits_Katakuri_" .. userName .. ".json"
local visitedFile = "visited_katakuri_servers.json"

local Config = {
    AutoFarm = false,
    AutoHopKatakuriServer = true,  -- Tự đổi server nếu server chưa đánh đủ quái
    MinKilledToStay = 300,         -- Đã đánh ít nhất 300 con thì mới ở lại (còn lại <= 200 con)
    AutoHopAfterKillBoss = true,   -- Tự đổi server sau khi diệt xong Katakuri
    
    AutoBring = true,
    BringRadius = 300,
    FastAttack = true,
    AttackMultiplier = 4,
    AutoQuest = true,
    AutoSpawnBoss = true,
    AutoKillBossOnly = false,
    WeaponType = "Melee",          -- Mặc định luôn tự động cầm Melee
    AutoBuso = true,
    AutoKen = true,
    AutoRaceV3 = true,
    AutoRaceV4 = true,
    FlySpeed = 250,
    FarmDistance = 15,             -- 15 studs trên đầu quái (An toàn tuyệt đối)
    NoClip = true
}

local function saveSettings()
    pcall(function()
        if writefile then writefile(saveFile, HttpService:JSONEncode(Config)) end
    end)
end

local function loadSettings()
    pcall(function()
        if isfile and isfile(saveFile) and readfile then
            local decoded = HttpService:JSONDecode(readfile(saveFile))
            if decoded and type(decoded) == "table" then
                for k, v in pairs(decoded) do
                    if Config[k] ~= nil then
                        Config[k] = (k == "FlySpeed") and math.clamp(v, 50, 250) or v
                    end
                end
            end
        end
    end)
end
loadSettings()

-- ==================== HỆ THỐNG LƯU SERVER ĐÃ VÀO ====================
local function getVisitedServers()
    local visited = {}
    pcall(function()
        if isfile and isfile(visitedFile) and readfile then
            local data = HttpService:JSONDecode(readfile(visitedFile))
            if type(data) == "table" then visited = data end
        end
    end)
    return visited
end

local function saveVisitedServer(id)
    pcall(function()
        local visited = getVisitedServers()
        visited[id] = os.time()
        if writefile then writefile(visitedFile, HttpService:JSONEncode(visited)) end
    end)
end

pcall(function() saveVisitedServer(game.JobId) end)

-- ==================== REMOTE & CHỌN PHE (SET TEAM) ====================
local CommF = RS:WaitForChild("Remotes"):WaitForChild("CommF_")
local CommE = RS:WaitForChild("Remotes"):WaitForChild("CommE")
local RegisterAttack = RS:WaitForChild("Modules"):WaitForChild("Net"):WaitForChild("RE/RegisterAttack")
local RegisterHit = RS:WaitForChild("Modules"):WaitForChild("Net"):WaitForChild("RE/RegisterHit")

local CombatController = nil
pcall(function()
    local cf = require(LP.PlayerScripts:WaitForChild("CombatFramework", 5))
    CombatController = (getupvalues or debug.getupvalues)(cf)[2]
end)

local function autoSetTeam()
    pcall(function() CommF:InvokeServer("SetTeam", "Pirates") end)
    pcall(function()
        local pg = LP:FindFirstChildOfClass("PlayerGui")
        if pg then
            for _, v in ipairs(pg:GetDescendants()) do
                if v:IsA("TextButton") and (v.Name == "Pirates" or v.Text:find("Pirates")) then
                    if firesignal then firesignal(v.MouseButton1Click) else v:Click() end
                end
            end
        end
    end)
end

task.spawn(function()
    if not LP.Team or not LP.Character or not LP.Character:FindFirstChild("HumanoidRootPart") then
        autoSetTeam()
        task.wait(1.5)
        if not LP.Character or not LP.Character:FindFirstChild("HumanoidRootPart") then autoSetTeam() end
    end
end)

local hitFunc = nil
pcall(function()
    for _, s in ipairs(LP.PlayerScripts:GetChildren()) do
        if s:IsA("LocalScript") and getsenv then
            local env = getsenv(s)
            if env and env._G and env._G.SendHitsToServer then hitFunc = env._G.SendHitsToServer break end
        end
    end
end)

local function isAlive(e)
    local hum = e and e.Parent and e:FindFirstChildOfClass("Humanoid")
    return hum and hum.Health > 0
end

-- ==================== TỰ ĐỘNG TRANG BỊ MELEE / VŨ KHÍ ====================
local function TrangBiVuKhi()
    local char = LP.Character
    if not char or not char:FindFirstChild("Humanoid") or char.Humanoid.Health <= 0 then return nil end
    local hum = char.Humanoid
    local pref = Config.WeaponType or "Melee"
    
    for _, tool in ipairs(char:GetChildren()) do
        if tool:IsA("Tool") then
            if pref == "Melee" and (tool.ToolTip == "Melee" or tool:FindFirstChild("CombatScript") or tool:FindFirstChild("Melee")) then
                return tool
            elseif tool.ToolTip == pref then
                return tool
            end
        end
    end
    
    local bp = LP:FindFirstChild("Backpack")
    if bp then
        for _, tool in ipairs(bp:GetChildren()) do
            if tool:IsA("Tool") then
                if pref == "Melee" and (tool.ToolTip == "Melee" or tool:FindFirstChild("CombatScript") or tool:FindFirstChild("Melee")) then
                    hum:EquipTool(tool)
                    return tool
                elseif tool.ToolTip == pref then
                    hum:EquipTool(tool)
                    return tool
                end
            end
        end
        for _, tool in ipairs(bp:GetChildren()) do
            if tool:IsA("Tool") and tool.ToolTip == "Melee" then
                hum:EquipTool(tool)
                return tool
            end
        end
        for _, tool in ipairs(bp:GetChildren()) do
            if tool:IsA("Tool") then
                hum:EquipTool(tool)
                return tool
            end
        end
    end
    
    return char:FindFirstChildOfClass("Tool")
end

-- ==================== TỰ ĐỘNG BẬT HAKI & TỘC V3 / V4 ====================
task.spawn(function()
    while scriptID == _G.KatakuriFarmID do
        task.wait(0.5)
        local char = LP.Character
        if char and Config.AutoFarm then
            if Config.AutoBuso and not char:FindFirstChild("HasBuso") then
                pcall(function() CommF:InvokeServer("Buso") end)
            end
            if Config.AutoKen then
                pcall(function() CommE:FireServer("Ken", true) end)
            end
        end
    end
end)

task.spawn(function()
    while scriptID == _G.KatakuriFarmID do
        task.wait(1.0)
        if Config.AutoFarm and Config.AutoRaceV3 and LP.Character then
            pcall(function()
                CommE:FireServer("ActivateAbility")
                VIM:SendKeyEvent(true, Enum.KeyCode.T, false, game)
                task.wait(0.05)
                VIM:SendKeyEvent(false, Enum.KeyCode.T, false, game)
            end)
        end
    end
end)

task.spawn(function()
    while scriptID == _G.KatakuriFarmID do
        task.wait(0.2)
        if Config.AutoFarm and Config.AutoRaceV4 and LP.Character then
            pcall(function()
                local char = LP.Character
                local isTransformed = char:FindFirstChild("RaceTransformed") and char.RaceTransformed.Value == true
                if not isTransformed then
                    VIM:SendKeyEvent(true, Enum.KeyCode.Y, false, game)
                    task.wait(0.05)
                    VIM:SendKeyEvent(false, Enum.KeyCode.Y, false, game)
                    CommE:FireServer("Awakening")
                    local pg = LP:FindFirstChild("PlayerGui")
                    if pg and pg:FindFirstChild("Main") then
                        local awkBtn = pg.Main:FindFirstChild("Awakening") or pg.Main:FindFirstChild("AwakeningToggler")
                        if awkBtn and awkBtn.Visible and firesignal then firesignal(awkBtn.MouseButton1Click) end
                    end
                end
            end)
        end
    end
end)

-- ==================== QUẢN LÝ QUÁI, QUEST & BOSS KATAKURI ====================
local CakeIslandMobs = {"Cookie Crafter", "Cake Guard", "Baking Staff", "Head Baker", "Peanut Scout", "Peanut President", "Ice Cream Chef", "Ice Cream Commander"}
local KatakuriBosses = {"Cake Prince", "Cake Prince [Lv. 2300] [Raid Boss]", "Dough King", "Dough King [Lv. 2300] [Raid Boss]"}
local CakeIslandPos = CFrame.new(-2091.91, 70.01, -12142.84)
local MirrorPos = CFrame.new(-2091.91, 70.01, -12142.84)

local function isCakeMob(e)
    if not e or not e.Parent then return false end
    for _, n in ipairs(CakeIslandMobs) do if e.Name:find(n) then return true end end
    return false
end

local lastQuest = 0
local function takeQuest(name)
    if not Config.AutoQuest or (LP.PlayerGui.Main:FindFirstChild("Quest") and LP.PlayerGui.Main.Quest.Visible) or tick() - lastQuest < 2 then return end
    lastQuest = tick()
    pcall(function()
        if name:find("Cookie") then CommF:InvokeServer("StartQuest", "CakeQuest1", 1)
        elseif name:find("Cake Guard") then CommF:InvokeServer("StartQuest", "CakeQuest1", 2)
        elseif name:find("Baking") then CommF:InvokeServer("StartQuest", "CakeQuest2", 1)
        elseif name:find("Head Baker") then CommF:InvokeServer("StartQuest", "CakeQuest2", 2)
        elseif name:find("Peanut Scout") then CommF:InvokeServer("StartQuest", "PeanutQuest", 1)
        elseif name:find("Peanut President") then CommF:InvokeServer("StartQuest", "PeanutQuest", 2)
        elseif name:find("Ice Cream Chef") then CommF:InvokeServer("StartQuest", "IceCreamIslandQuest", 1)
        elseif name:find("Ice Cream Commander") then CommF:InvokeServer("StartQuest", "IceCreamIslandQuest", 2) end
    end)
end

local function getActiveBoss()
    local enemies = workspace:FindFirstChild("Enemies")
    if enemies then
        for _, e in ipairs(enemies:GetChildren()) do
            if isAlive(e) then
                for _, b in ipairs(KatakuriBosses) do if e.Name:find(b) then return e end end
            end
        end
    end
    for _, b in ipairs(KatakuriBosses) do
        local rb = RS:FindFirstChild(b)
        if rb and rb:FindFirstChild("HumanoidRootPart") then return rb end
    end
    return nil
end

local function isMirrorOpen()
    local m = workspace:FindFirstChild("Map") and workspace.Map:FindFirstChild("CakeLoaf")
    return (m and m:FindFirstChild("BigMirror") and m.BigMirror:FindFirstChild("Other") and m.BigMirror.Other.Transparency == 0) or false
end

-- =========================================================================
-- HỆ THỐNG THEO DÕI KATAKURI ĐỒNG BỘ (CENTRALIZED TRACKER - 1 LUỒNG DUY NHẤT)
-- =========================================================================
local kataData = {
    Rem = 500,
    Killed = 0,
    Pct = 0,
    Open = false,
    Boss = nil,
    Hp = 0,
    MaxHp = 0,
    HasData = false
}

task.spawn(function()
    while scriptID == _G.KatakuriFarmID do
        pcall(function()
            local res = CommF:InvokeServer("CakePrinceSpawner")
            local boss = getActiveBoss()
            local open = isMirrorOpen()
            local bHum = boss and boss:FindFirstChildOfClass("Humanoid")
            
            local remaining = 500
            local killed = 0
            
            if type(res) == "string" then
                local text = res:lower()
                if text:find("open") or text:find("spawn") or text:find("arrived") then
                    open = true
                    remaining = 0
                    killed = 500
                else
                    local num = tonumber(res:match("%d+"))
                    if num then
                        remaining = math.clamp(num, 0, 500)
                        killed = math.clamp(500 - remaining, 0, 500)
                    end
                end
            elseif open then
                remaining = 0
                killed = 500
            end
            
            kataData.Rem = remaining
            kataData.Killed = killed
            kataData.Pct = math.floor((killed / 500) * 100)
            kataData.Open = open or (remaining == 0)
            kataData.Boss = boss and boss.Name or (open and "Cake Prince / Dough King" or nil)
            kataData.Hp = bHum and bHum.Health > 0 and math.floor(bHum.Health) or 0
            kataData.MaxHp = bHum and bHum.MaxHealth > 0 and math.floor(bHum.MaxHealth) or 0
            kataData.HasData = (type(res) == "string") or open or (boss ~= nil)
        end)
        task.wait(1.5)
    end
end)

local function getKataData()
    return kataData
end

-- =========================================================================
-- HỌP SERVER NGẪU NHIÊN QUA SERVER BROWSER & API (CỰC KỲ MẠNH MẼ VÀ ĐẢM BẢO 100%)
-- =========================================================================
local isHopping = false
local function hopRandomServer(force)
    if isHopping and not force then return end
    isHopping = true
    print("[Server Hop] 🚀 Đang quét và tìm kiếm server ngẫu nhiên mới...")
    
    local placeId = game.PlaceId
    local visited = getVisitedServers()
    local candidateServers = {}
    
    local function fetchServers(sortOrder)
        local url = "https://games.roblox.com/v1/games/" .. placeId .. "/servers/Public?sortOrder=" .. sortOrder .. "&limit=100"
        local success, raw = pcall(function() return game:HttpGet(url) end)
        if success and raw then
            local decoded = nil
            pcall(function() decoded = HttpService:JSONDecode(raw) end)
            if decoded and decoded.data then
                for _, s in pairs(decoded.data) do
                    local playing = tonumber(s.playing)
                    local maxP = tonumber(s.maxPlayers) or 12
                    if s.id ~= game.JobId and not visited[s.id] and playing and playing < maxP and playing >= 1 then
                        table.insert(candidateServers, s)
                    end
                end
            end
        end
    end
    
    fetchServers("Asc")
    if #candidateServers < 5 then
        fetchServers("Desc")
    end
    
    print(string.format("[Server Hop] Đã tìm thấy %d server ứng viên phù hợp.", #candidateServers))
    
    if #candidateServers > 0 then
        for i = #candidateServers, 2, -1 do
            local j = math.random(i)
            candidateServers[i], candidateServers[j] = candidateServers[j], candidateServers[i]
        end
        
        for _, s in ipairs(candidateServers) do
            saveVisitedServer(s.id)
            print(string.format("[Server Hop] ✈️ Đang kết nối đến server: %s (%d/%d người)...", s.id, s.playing, s.maxPlayers or 12))
            
            pcall(function()
                local sb = RS:FindFirstChild("__ServerBrowser")
                if sb and sb:IsA("RemoteFunction") then
                    sb:InvokeServer("teleport", s.id)
                end
            end)
            
            pcall(function()
                TeleportService:TeleportToPlaceInstance(placeId, s.id, LP)
            end)
            
            task.wait(4)
        end
    end
    
    print("[Server Hop] ⚡ Thực hiện Teleport trực tiếp để đổi server...")
    pcall(function()
        TeleportService:Teleport(placeId, LP)
    end)
    
    task.wait(5)
    isHopping = false
end

TeleportService.TeleportInitFailed:Connect(function(player)
    if player == LP then
        isHopping = false
        task.wait(2)
        hopRandomServer(true)
    end
end)

-- =========================================================================
-- KIỂM TRA ĐIỀU KIỆN KATAKURI KHI VỪA VÀO SERVER & THEO DÕI SAU KHI DIỆT BOSS
-- =========================================================================
task.spawn(function()
    task.wait(3.0)
    
    if Config.AutoHopKatakuriServer then
        print("[Katakuri Check] Đang chờ đồng bộ dữ liệu Katakuri từ server...")
        local waitCount = 0
        while not kataData.HasData and waitCount < 10 and scriptID == _G.KatakuriFarmID do
            waitCount = waitCount + 1
            task.wait(0.5)
        end
        
        local d = getKataData()
        local maxRemainingAllowed = 500 - (Config.MinKilledToStay or 300)
        local canStay = d.Open or (d.Boss ~= nil) or (d.Rem <= maxRemainingAllowed) or (d.Killed >= Config.MinKilledToStay)
        
        if canStay then
            print(string.format("✅ [Katakuri Check] ĐẠT YÊU CẦU! Server đã diệt %d/500 con (Chỉ còn %d con nữa). Ở lại farm!", d.Killed, d.Rem))
            Config.AutoFarm = true
            saveSettings()
        else
            print(string.format("⚠️ [Katakuri Check] CHƯA ĐẠT! Server mới diệt %d/500 con (Còn phải đánh tận %d con nữa > %d). Đổi server khác ngay...", d.Killed, d.Rem, maxRemainingAllowed))
            hopRandomServer(true)
        end
    end
end)

-- Theo dõi sau khi Boss Katakuri bị hạ gục -> Tự động chuyển server mới
local hadBossSpawned = false
task.spawn(function()
    while scriptID == _G.KatakuriFarmID do
        task.wait(1.5)
        if Config.AutoHopAfterKillBoss then
            local d = getKataData()
            if d.Boss and d.Hp > 0 then
                hadBossSpawned = true
            elseif hadBossSpawned and (not d.Boss or d.Hp <= 0) then
                hadBossSpawned = false
                print("🎉 [Katakuri Pro] ĐÃ DIỆT XONG KATAKURI! Bắt đầu chuyển sang server ngẫu nhiên mới...")
                task.wait(2)
                hopRandomServer(true)
            end
        end
    end
end)

-- =========================================================================
-- HỆ THỐNG DI CHUYỂN & TRIỆT TIÊU TRỌNG LỰC (BODYVELOCITY CHỐNG RƠI / GIẬT)
-- =========================================================================
local activeTween = nil
local currentFarmCFrame = nil
local activeAttackEntity = nil

local function applyAntiGravity(hrp)
    local bv = hrp:FindFirstChild("FarmFlightBV")
    if not bv then
        bv = Instance.new("BodyVelocity")
        bv.Name = "FarmFlightBV"
        bv.MaxForce = Vector3.new(9e9, 9e9, 9e9)
        bv.Velocity = Vector3.zero
        bv.Parent = hrp
    else
        bv.Velocity = Vector3.zero
    end
end

local function removeAntiGravity(char)
    if char and char:FindFirstChild("HumanoidRootPart") then
        local bv = char.HumanoidRootPart:FindFirstChild("FarmFlightBV")
        if bv then bv:Destroy() end
    end
end

local function DiChuyenDen(targetCF)
    local char = LP.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    if not hrp then return end
    
    applyAntiGravity(hrp)
    
    local dist = (targetCF.Position - hrp.Position).Magnitude
    local speed = math.clamp(Config.FlySpeed or 250, 50, 250)
    
    if dist > 80 then
        local duration = dist / speed
        if activeTween then activeTween:Cancel() end
        activeTween = TweenService:Create(hrp, TweenInfo.new(duration, Enum.EasingStyle.Linear), {CFrame = targetCF})
        activeTween:Play()
    else
        if activeTween then activeTween:Cancel() activeTween = nil end
        hrp.Velocity = Vector3.zero
        hrp.RotVelocity = Vector3.zero
        hrp.CFrame = targetCF
    end
end

RunService.Stepped:Connect(function()
    if Config.AutoFarm and LP.Character then
        for _, p in ipairs(LP.Character:GetDescendants()) do
            if p:IsA("BasePart") then p.CanCollide = false end
        end
        local hrp = LP.Character:FindFirstChild("HumanoidRootPart")
        if hrp then applyAntiGravity(hrp) end
    else
        removeAntiGravity(LP.Character)
    end
end)

-- ==================== GOM QUÁI MAGNET 60x60 ====================
task.spawn(function()
    while scriptID == _G.KatakuriFarmID do
        task.wait()
        pcall(function()
            if setscriptable then setscriptable(LP, "SimulationRadius", true) end
            if sethiddenproperty then
                sethiddenproperty(LP, "SimulationRadius", math.huge)
                sethiddenproperty(LP, "MaxSimulationRadius", math.huge)
            end
            LP.SimulationRadius = math.huge
        end)
        
        if Config.AutoFarm and Config.AutoBring and currentFarmCFrame and workspace:FindFirstChild("Enemies") then
            pcall(function()
                for _, v in ipairs(workspace.Enemies:GetChildren()) do
                    if isAlive(v) and not v:GetAttribute("IsBoat") and isCakeMob(v) and not v.Name:find("Prince") and not v.Name:find("King") then
                        local vr, vh, head = v:FindFirstChild("HumanoidRootPart"), v:FindFirstChildOfClass("Humanoid"), v:FindFirstChild("Head")
                        if vr and vh and (vr.Position - currentFarmCFrame.Position).Magnitude <= Config.BringRadius then
                            vr.Size = Vector3.new(60, 60, 60)
                            vr.Transparency = 1
                            vr.CanCollide = false
                            if head then head.CanCollide = false end
                            pcall(function() vh:ChangeState(11) vh:ChangeState(14) end)
                            vr.CFrame = currentFarmCFrame
                        end
                    end
                end
            end)
        end
    end
end)

-- ==================== LUỒNG ĐÁNH SIÊU NHANH X4 (100 CPS) ====================
task.spawn(function()
    while scriptID == _G.KatakuriFarmID do
        task.wait(0.01)
        if Config.FastAttack and Config.AutoFarm and activeAttackEntity and isAlive(activeAttackEntity) and LP.Character then
            pcall(function()
                local hrp = LP.Character:FindFirstChild("HumanoidRootPart")
                local er = activeAttackEntity:FindFirstChild("HumanoidRootPart") or activeAttackEntity.PrimaryPart
                if hrp and er and (er.Position - hrp.Position).Magnitude <= 55 then
                    local weapon = TrangBiVuKhi()
                    if weapon then
                        local head = activeAttackEntity:FindFirstChild("Head") or er
                        local list = {{activeAttackEntity, head}}
                        
                        if Config.AutoBring and workspace:FindFirstChild("Enemies") then
                            for _, e in ipairs(workspace.Enemies:GetChildren()) do
                                if e ~= activeAttackEntity and isAlive(e) and isCakeMob(e) then
                                    local r = e:FindFirstChild("HumanoidRootPart") or e.PrimaryPart
                                    if r and (r.Position - hrp.Position).Magnitude <= 55 then
                                        table.insert(list, {e, e:FindFirstChild("Head") or r})
                                    end
                                end
                            end
                        end
                        
                        if CombatController and CombatController.activeController then
                            pcall(function()
                                local ac = CombatController.activeController
                                ac.hitboxMagnitude, ac.active, ac.blocking, ac.timeToNextAttack = 65, false, false, 0
                                ac:attack()
                            end)
                        end
                        
                        for _ = 1, math.clamp(Config.AttackMultiplier or 4, 1, 6) do
                            RegisterAttack:FireServer(0)
                            if hitFunc then pcall(function() hitFunc(head, list) end) else RegisterHit:FireServer(head, list) end
                        end
                        pcall(function() VU:Button1Down(Vector2.new(1280, 720)) end)
                        pcall(function() weapon:Activate() end)
                    end
                end
            end)
        end
    end
end)

-- ==================== VÒNG LẶP FARM CHÍNH ====================
local currentTargetName = nil
local farmingMob = nil

local function getTargetMob()
    if farmingMob and isAlive(farmingMob) then return farmingMob end
    farmingMob = nil
    local hrp = LP.Character and LP.Character:FindFirstChild("HumanoidRootPart")
    if not hrp or not workspace:FindFirstChild("Enemies") then return nil end
    
    local nearest, minDist = nil, math.huge
    for _, e in ipairs(workspace.Enemies:GetChildren()) do
        if isAlive(e) and not e:GetAttribute("IsBoat") and isCakeMob(e) then
            local r = e:FindFirstChild("HumanoidRootPart") or e.PrimaryPart
            if r then
                local d = (r.Position - hrp.Position).Magnitude
                if d < minDist then minDist, nearest = d, e end
            end
        end
    end
    farmingMob = nearest
    return nearest
end

task.spawn(function()
    while scriptID == _G.KatakuriFarmID do
        task.wait(0.05)
        if Config.AutoFarm then
            pcall(function()
                local hrp = LP.Character and LP.Character:FindFirstChild("HumanoidRootPart")
                if not hrp then return end
                
                TrangBiVuKhi()
                
                -- 1. Ưu tiên Boss Katakuri
                local boss = getActiveBoss()
                if boss then
                    local br = boss:FindFirstChild("HumanoidRootPart") or boss.PrimaryPart
                    local bh = boss:FindFirstChildOfClass("Humanoid")
                    if br and bh and bh.Health > 0 then
                        currentTargetName, activeAttackEntity, currentFarmCFrame = boss.Name, boss, br.CFrame
                        local animator = bh:FindFirstChild("Animator")
                        if animator then animator:Destroy() end
                        
                        local tPos = br.CFrame * CFrame.new(0, Config.FarmDistance, 0) * CFrame.Angles(math.rad(-90), 0, 0)
                        DiChuyenDen(tPos)
                        return
                    elseif isMirrorOpen() then
                        DiChuyenDen(MirrorPos)
                        activeAttackEntity, currentFarmCFrame = nil, nil
                        return
                    end
                end
                
                if Config.AutoKillBossOnly then
                    pcall(function() CommF:InvokeServer("CakePrinceSpawner", true) end)
                    DiChuyenDen(CakeIslandPos)
                    currentTargetName = "Đang chờ Katakuri..."
                    activeAttackEntity, currentFarmCFrame = nil, nil
                    return
                end
                
                if Config.AutoSpawnBoss then pcall(function() CommF:InvokeServer("CakePrinceSpawner", true) end) end
                
                -- 2. Farm quái Đảo Bánh
                local mob = getTargetMob()
                if mob then
                    local mr = mob:FindFirstChild("HumanoidRootPart") or mob.PrimaryPart
                    local mh = mob:FindFirstChildOfClass("Humanoid")
                    if mr and mh and mh.Health > 0 then
                        currentTargetName, activeAttackEntity, currentFarmCFrame = mob.Name, mob, mr.CFrame
                        takeQuest(mob.Name)
                        
                        local animator = mh:FindFirstChild("Animator")
                        if animator then animator:Destroy() end
                        
                        local tPos = mr.CFrame * CFrame.new(0, Config.FarmDistance, 0) * CFrame.Angles(math.rad(-90), 0, 0)
                        DiChuyenDen(tPos)
                    else
                        farmingMob, activeAttackEntity, currentFarmCFrame = nil, nil, nil
                    end
                else
                    farmingMob, activeAttackEntity, currentFarmCFrame = nil, nil, nil
                    currentTargetName = "Đang tìm quái..."
                    DiChuyenDen(CakeIslandPos)
                end
            end)
        else
            farmingMob, activeAttackEntity, currentFarmCFrame, currentTargetName = nil, nil, nil, nil
        end
    end
end)

-- ==================== GIAO DIỆN COMPACT UI & DASHBOARD ====================
local Gui = Instance.new("ScreenGui", parentGui)
Gui.Name = "KatakuriFarmGui"
Gui.ResetOnSpawn = false

local function drag(f, t)
    local d, ds, sp
    t.InputBegan:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
            d, ds, sp = true, i.Position, f.Position
            i.Changed:Connect(function() if i.UserInputState == Enum.UserInputState.End then d = false end end)
        end
    end)
    UIS.InputChanged:Connect(function(i)
        if d and (i.UserInputType == Enum.UserInputType.MouseMovement or i.UserInputType == Enum.UserInputType.Touch) then
            local dt = i.Position - ds
            f.Position = UDim2.new(sp.X.Scale, sp.X.Offset + dt.X, sp.Y.Scale, sp.Y.Offset + dt.Y)
        end
    end)
end

-- Floating Icon
local Icon = Instance.new("TextButton", Gui)
Icon.Size = UDim2.new(0, 48, 0, 48)
Icon.Position = UDim2.new(0, 15, 0.4, 0)
Icon.BackgroundColor3 = Color3.fromRGB(25, 20, 35)
Icon.Text = "🍩"
Icon.TextSize = 24
Instance.new("UICorner", Icon).CornerRadius = UDim.new(1, 0)
local iStr = Instance.new("UIStroke", Icon)
iStr.Thickness, iStr.Color = 2, Color3.fromRGB(255, 140, 0)
drag(Icon, Icon)

-- Main Frame
local MF = Instance.new("Frame", Gui)
MF.Size = UDim2.new(0, 460, 0, 340)
MF.Position = UDim2.new(0.5, -230, 0.5, -170)
MF.BackgroundColor3 = Color3.fromRGB(18, 16, 25)
MF.BorderSizePixel = 0
MF.ClipsDescendants = true
Instance.new("UICorner", MF).CornerRadius = UDim.new(0, 10)
local mStr = Instance.new("UIStroke", MF)
mStr.Thickness, mStr.Color = 1.5, Color3.fromRGB(255, 140, 0)

local Top = Instance.new("Frame", MF)
Top.Size = UDim2.new(1, 0, 0, 38)
Top.BackgroundColor3 = Color3.fromRGB(26, 22, 36)
Top.BorderSizePixel = 0
drag(MF, Top)

local TLbl = Instance.new("TextLabel", Top)
TLbl.Size = UDim2.new(1, -50, 1, 0)
TLbl.Position = UDim2.new(0, 12, 0, 0)
TLbl.BackgroundTransparency = 1
TLbl.Text = "🍩 KATAKURI AUTO FARM • " .. userName
TLbl.TextColor3 = Color3.fromRGB(255, 180, 50)
TLbl.Font = Enum.Font.GothamBold
TLbl.TextSize = 12
TLbl.TextXAlignment = Enum.TextXAlignment.Left

local Close = Instance.new("TextButton", Top)
Close.Size = UDim2.new(0, 26, 0, 26)
Close.Position = UDim2.new(1, -32, 0, 6)
Close.BackgroundColor3 = Color3.fromRGB(235, 60, 70)
Close.Text, Close.TextColor3, Close.TextSize = "✕", Color3.fromRGB(255, 255, 255), 12
Close.Font = Enum.Font.GothamBold
Instance.new("UICorner", Close).CornerRadius = UDim.new(0, 6)
Close.MouseButton1Click:Connect(function() MF.Visible = false end)
Icon.MouseButton1Click:Connect(function() MF.Visible = not MF.Visible end)

local SB = Instance.new("Frame", MF)
SB.Size = UDim2.new(0, 120, 1, -38)
SB.Position = UDim2.new(0, 0, 0, 38)
SB.BackgroundColor3 = Color3.fromRGB(22, 19, 30)
SB.BorderSizePixel = 0
local sLay = Instance.new("UIListLayout", SB)
sLay.Padding = UDim.new(0, 4)
local sPad = Instance.new("UIPadding", SB)
sPad.PaddingTop, sPad.PaddingLeft, sPad.PaddingRight = UDim.new(0, 6), UDim.new(0, 6), UDim.new(0, 6)

local TC = Instance.new("Frame", MF)
TC.Size = UDim2.new(1, -125, 1, -44)
TC.Position = UDim2.new(0, 124, 0, 42)
TC.BackgroundTransparency = 1

local pages, tabBtns = {}, {}
local function switchTab(name)
    for n, p in pairs(pages) do p.Visible = (n == name) end
    for n, b in pairs(tabBtns) do
        local on = (n == name)
        b.BackgroundColor3 = on and Color3.fromRGB(255, 140, 0) or Color3.fromRGB(28, 24, 38)
        b.TextColor3 = on and Color3.fromRGB(20, 15, 25) or Color3.fromRGB(190, 190, 210)
    end
end

local function addTab(name, icon)
    local b = Instance.new("TextButton", SB)
    b.Size = UDim2.new(1, 0, 0, 32)
    b.BackgroundColor3 = Color3.fromRGB(28, 24, 38)
    b.Text = icon .. " " .. name
    b.TextColor3 = Color3.fromRGB(190, 190, 210)
    b.Font = Enum.Font.GothamBold
    b.TextSize = 10
    Instance.new("UICorner", b).CornerRadius = UDim.new(0, 6)
    
    local sf = Instance.new("ScrollingFrame", TC)
    sf.Size = UDim2.new(1, -4, 1, 0)
    sf.BackgroundTransparency = 1
    sf.ScrollBarThickness = 3
    sf.ScrollBarImageColor3 = Color3.fromRGB(255, 140, 0)
    sf.Visible = false
    local l = Instance.new("UIListLayout", sf)
    l.Padding = UDim.new(0, 5)
    l:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function() sf.CanvasSize = UDim2.new(0, 0, 0, l.AbsoluteContentSize.Y + 10) end)
    
    pages[name], tabBtns[name] = sf, b
    b.MouseButton1Click:Connect(function() switchTab(name) end)
    return sf
end

local function addToggle(p, text, key, cb)
    local f = Instance.new("Frame", p)
    f.Size = UDim2.new(1, -6, 0, 34)
    f.BackgroundColor3 = Color3.fromRGB(25, 22, 35)
    Instance.new("UICorner", f).CornerRadius = UDim.new(0, 6)
    local str = Instance.new("UIStroke", f)
    str.Color = Config[key] and Color3.fromRGB(255, 140, 0) or Color3.fromRGB(45, 40, 60)
    
    local l = Instance.new("TextLabel", f)
    l.Size = UDim2.new(1, -60, 1, 0)
    l.Position = UDim2.new(0, 8, 0, 0)
    l.BackgroundTransparency = 1
    l.Text = text
    l.TextColor3 = Config[key] and Color3.fromRGB(255, 255, 255) or Color3.fromRGB(180, 180, 200)
    l.Font = Enum.Font.GothamBold
    l.TextSize = 10
    l.TextXAlignment = Enum.TextXAlignment.Left
    
    local btn = Instance.new("TextButton", f)
    btn.Size = UDim2.new(0, 44, 0, 22)
    btn.Position = UDim2.new(1, -50, 0.5, -11)
    btn.BackgroundColor3 = Config[key] and Color3.fromRGB(255, 140, 0) or Color3.fromRGB(45, 40, 60)
    btn.Text = Config[key] and "BẬT" or "TẮT"
    btn.TextColor3 = Config[key] and Color3.fromRGB(20, 15, 25) or Color3.fromRGB(200, 200, 200)
    btn.Font = Enum.Font.GothamBold
    btn.TextSize = 9
    Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 4)
    
    btn.MouseButton1Click:Connect(function()
        Config[key] = not Config[key]
        btn.Text = Config[key] and "BẬT" or "TẮT"
        btn.BackgroundColor3 = Config[key] and Color3.fromRGB(255, 140, 0) or Color3.fromRGB(45, 40, 60)
        btn.TextColor3 = Config[key] and Color3.fromRGB(20, 15, 25) or Color3.fromRGB(200, 200, 200)
        str.Color = Config[key] and Color3.fromRGB(255, 140, 0) or Color3.fromRGB(45, 40, 60)
        l.TextColor3 = Config[key] and Color3.fromRGB(255, 255, 255) or Color3.fromRGB(180, 180, 200)
        saveSettings()
        if cb then cb(Config[key]) end
    end)
end

local function addSlider(p, text, key, minV, maxV, step, cb)
    local f = Instance.new("Frame", p)
    f.Size = UDim2.new(1, -6, 0, 44)
    f.BackgroundColor3 = Color3.fromRGB(25, 22, 35)
    Instance.new("UICorner", f).CornerRadius = UDim.new(0, 6)
    
    local l = Instance.new("TextLabel", f)
    l.Size = UDim2.new(1, -50, 0, 18)
    l.Position = UDim2.new(0, 8, 0, 3)
    l.BackgroundTransparency = 1
    l.Text, l.TextColor3, l.Font, l.TextSize = text, Color3.fromRGB(220, 220, 230), Enum.Font.GothamBold, 10
    l.TextXAlignment = Enum.TextXAlignment.Left
    
    local vl = Instance.new("TextLabel", f)
    vl.Size = UDim2.new(0, 45, 0, 18)
    vl.Position = UDim2.new(1, -50, 0, 3)
    vl.BackgroundTransparency = 1
    vl.Text, vl.TextColor3, vl.Font, vl.TextSize = tostring(Config[key]), Color3.fromRGB(255, 180, 50), Enum.Font.GothamBold, 10
    vl.TextXAlignment = Enum.TextXAlignment.Right
    
    local bg = Instance.new("TextButton", f)
    bg.Size = UDim2.new(1, -16, 0, 6)
    bg.Position = UDim2.new(0, 8, 0, 28)
    bg.BackgroundColor3 = Color3.fromRGB(45, 40, 60)
    bg.Text = ""
    Instance.new("UICorner", bg).CornerRadius = UDim.new(1, 0)
    
    local fill = Instance.new("Frame", bg)
    local v0 = math.clamp(Config[key], minV, maxV)
    fill.Size = UDim2.new((v0 - minV) / (maxV - minV), 0, 1, 0)
    fill.BackgroundColor3 = Color3.fromRGB(255, 140, 0)
    fill.BorderSizePixel = 0
    Instance.new("UICorner", fill).CornerRadius = UDim.new(1, 0)
    
    local sliding = false
    local function up(i)
        local rel = math.clamp((i.Position.X - bg.AbsolutePosition.X) / bg.AbsoluteSize.X, 0, 1)
        local val = minV + (maxV - minV) * rel
        if step and step > 0 then val = math.floor(val / step + 0.5) * step end
        val = math.clamp(val, minV, maxV)
        Config[key] = val
        vl.Text = tostring(val)
        fill.Size = UDim2.new((val - minV) / (maxV - minV), 0, 1, 0)
        saveSettings()
        if cb then cb(val) end
    end
    bg.InputBegan:Connect(function(i) if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then sliding = true up(i) end end)
    UIS.InputEnded:Connect(function(i) if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then sliding = false end end)
    UIS.InputChanged:Connect(function(i) if sliding and (i.UserInputType == Enum.UserInputType.MouseMovement or i.UserInputType == Enum.UserInputType.Touch) then up(i) end end)
end

local function addDropdown(p, text, key, opts)
    local f = Instance.new("Frame", p)
    f.Size = UDim2.new(1, -6, 0, 50)
    f.BackgroundColor3 = Color3.fromRGB(25, 22, 35)
    Instance.new("UICorner", f).CornerRadius = UDim.new(0, 6)
    
    local l = Instance.new("TextLabel", f)
    l.Size = UDim2.new(1, -16, 0, 18)
    l.Position = UDim2.new(0, 8, 0, 2)
    l.BackgroundTransparency = 1
    l.Text, l.TextColor3, l.Font, l.TextSize = text, Color3.fromRGB(220, 220, 230), Enum.Font.GothamBold, 10
    l.TextXAlignment = Enum.TextXAlignment.Left
    
    local c = Instance.new("Frame", f)
    c.Size = UDim2.new(1, -16, 0, 22)
    c.Position = UDim2.new(0, 8, 0, 22)
    c.BackgroundTransparency = 1
    local lay = Instance.new("UIListLayout", c)
    lay.FillDirection, lay.Padding = Enum.FillDirection.Horizontal, UDim.new(0, 4)
    
    local btns = {}
    for _, opt in ipairs(opts) do
        local b = Instance.new("TextButton", c)
        b.Size = UDim2.new(1 / #opts, -4, 1, 0)
        b.BackgroundColor3 = (Config[key] == opt) and Color3.fromRGB(255, 140, 0) or Color3.fromRGB(40, 35, 55)
        b.Text = opt
        b.TextColor3 = (Config[key] == opt) and Color3.fromRGB(20, 15, 25) or Color3.fromRGB(180, 180, 200)
        b.Font = Enum.Font.GothamBold
        b.TextSize = 9
        Instance.new("UICorner", b).CornerRadius = UDim.new(0, 4)
        btns[opt] = b
        b.MouseButton1Click:Connect(function()
            Config[key] = opt
            for o, btn in pairs(btns) do
                local sel = (Config[key] == o)
                btn.BackgroundColor3 = sel and Color3.fromRGB(255, 140, 0) or Color3.fromRGB(40, 35, 55)
                btn.TextColor3 = sel and Color3.fromRGB(20, 15, 25) or Color3.fromRGB(180, 180, 200)
            end
            saveSettings()
            TrangBiVuKhi()
        end)
    end
end

local function addButton(p, text, color, cb)
    local b = Instance.new("TextButton", p)
    b.Size = UDim2.new(1, -6, 0, 30)
    b.BackgroundColor3 = color or Color3.fromRGB(255, 140, 0)
    b.Text = text
    b.TextColor3 = Color3.fromRGB(20, 15, 25)
    b.Font = Enum.Font.GothamBold
    b.TextSize = 10
    Instance.new("UICorner", b).CornerRadius = UDim.new(0, 6)
    b.MouseButton1Click:Connect(function() if cb then cb() end end)
end

-- Katakuri Dashboard Widget
local function addDashboard(p)
    local f = Instance.new("Frame", p)
    f.Size = UDim2.new(1, -6, 0, 100)
    f.BackgroundColor3 = Color3.fromRGB(26, 20, 36)
    Instance.new("UICorner", f).CornerRadius = UDim.new(0, 8)
    local str = Instance.new("UIStroke", f)
    str.Thickness, str.Color = 1.5, Color3.fromRGB(255, 140, 0)
    
    local rLbl = Instance.new("TextLabel", f)
    rLbl.Size, rLbl.Position = UDim2.new(1, -50, 0, 18), UDim2.new(0, 8, 0, 4)
    rLbl.BackgroundTransparency, rLbl.TextColor3, rLbl.Font, rLbl.TextSize = 1, Color3.fromRGB(255, 230, 80), Enum.Font.GothamBold, 10
    rLbl.TextXAlignment, rLbl.Text = Enum.TextXAlignment.Left, "⚔️ Đang tải dữ liệu Katakuri..."
    
    local pLbl = Instance.new("TextLabel", f)
    pLbl.Size, pLbl.Position = UDim2.new(0, 45, 0, 18), UDim2.new(1, -50, 0, 4)
    pLbl.BackgroundTransparency, pLbl.TextColor3, pLbl.Font, pLbl.TextSize = 1, Color3.fromRGB(255, 180, 50), Enum.Font.GothamBold, 10
    pLbl.TextXAlignment, pLbl.Text = Enum.TextXAlignment.Right, "0%"
    
    local bg = Instance.new("Frame", f)
    bg.Size, bg.Position = UDim2.new(1, -16, 0, 6), UDim2.new(0, 8, 0, 24)
    bg.BackgroundColor3 = Color3.fromRGB(45, 38, 60)
    Instance.new("UICorner", bg).CornerRadius = UDim.new(1, 0)
    
    local fill = Instance.new("Frame", bg)
    fill.Size, fill.BackgroundColor3 = UDim2.new(0, 0, 1, 0), Color3.fromRGB(255, 140, 0)
    Instance.new("UICorner", fill).CornerRadius = UDim.new(1, 0)
    
    local sLbl = Instance.new("TextLabel", f)
    sLbl.Size, sLbl.Position = UDim2.new(1, -16, 0, 16), UDim2.new(0, 8, 0, 34)
    sLbl.BackgroundTransparency, sLbl.TextColor3, sLbl.Font, sLbl.TextSize = 1, Color3.fromRGB(200, 210, 230), Enum.Font.Gotham, 9
    sLbl.TextXAlignment, sLbl.Text = Enum.TextXAlignment.Left, "🚪 Cổng Gương: Đang kiểm tra..."
    
    local tLbl = Instance.new("TextLabel", f)
    tLbl.Size, tLbl.Position = UDim2.new(1, -16, 0, 16), UDim2.new(0, 8, 0, 52)
    tLbl.BackgroundTransparency, tLbl.TextColor3, tLbl.Font, tLbl.TextSize = 1, Color3.fromRGB(150, 255, 180), Enum.Font.Gotham, 9
    tLbl.TextXAlignment, tLbl.Text = Enum.TextXAlignment.Left, "🎯 Mục tiêu: Chưa kích hoạt"
    
    local kLbl = Instance.new("TextLabel", f)
    kLbl.Size, kLbl.Position = UDim2.new(1, -16, 0, 16), UDim2.new(0, 8, 0, 70)
    kLbl.BackgroundTransparency, kLbl.TextColor3, kLbl.Font, kLbl.TextSize = 1, Color3.fromRGB(255, 120, 120), Enum.Font.GothamBold, 9
    kLbl.TextXAlignment, kLbl.Text = Enum.TextXAlignment.Left, "⚡ Khả dụng: Chưa mở Katakuri"
    
    task.spawn(function()
        while scriptID == _G.KatakuriFarmID and f.Parent do
            task.wait(1.0)
            pcall(function()
                local d = getKataData()
                rLbl.Text = "⚔️ Đã diệt: " .. tostring(d.Killed) .. "/500 | Cần thêm: " .. tostring(d.Rem)
                pLbl.Text = tostring(d.Pct) .. "%"
                fill.Size = UDim2.new(math.clamp(d.Killed / 500, 0, 1), 0, 1, 0)
                
                if d.Open then
                    sLbl.Text, sLbl.TextColor3 = "🚪 Cổng Gương: ĐÃ MỞ!", Color3.fromRGB(0, 255, 200)
                else
                    sLbl.Text, sLbl.TextColor3 = "🔒 Cổng Gương: CHƯA MỞ", Color3.fromRGB(255, 140, 140)
                end
                
                if d.Boss then
                    tLbl.Text, tLbl.TextColor3 = "👑 Boss: " .. d.Boss .. " (HP: " .. d.Hp .. "/" .. d.MaxHp .. ")", Color3.fromRGB(255, 215, 0)
                    kLbl.Text, kLbl.TextColor3 = "🔥 ĐANG ĐÁNH BOSS KATAKURI!", Color3.fromRGB(0, 255, 120)
                elseif currentTargetName then
                    tLbl.Text, tLbl.TextColor3 = "🎯 Đang farm: " .. currentTargetName, Color3.fromRGB(150, 255, 180)
                    kLbl.Text, kLbl.TextColor3 = d.Open and "✨ CỔNG ĐÃ MỞ SẴN SÀNG!" or "⏳ Đã diệt " .. d.Killed .. "/500 con", d.Open and Color3.fromRGB(0, 220, 255) or Color3.fromRGB(255, 100, 100)
                else
                    tLbl.Text = "🎯 Đang tìm quái..."
                end
            end)
        end
    end)
end

-- ==================== CẤU TRÚC TAB GIAO DIỆN ====================
local T1 = addTab("Katakuri", "🍩")
local T2 = addTab("Gom Quái", "🌪️")
local T3 = addTab("Tấn Công", "⚔️")
local T4 = addTab("Haki & Tộc", "🛡️")
local T5 = addTab("Di Chuyển", "🚀")
local T6 = addTab("Đổi Server", "🌐")
local T7 = addTab("Cài Đặt", "⚙️")

-- Tab 1: Katakuri
addDashboard(T1)
addToggle(T1, "🍩 Kích Hoạt Auto Farm Katakuri", "AutoFarm")
addToggle(T1, "💰 Tự Động Nhận Nhiệm Vụ (Beli)", "AutoQuest")
addToggle(T1, "✨ Tự Động Gọi Boss (Auto Spawn)", "AutoSpawnBoss")
addToggle(T1, "👑 Chỉ Đánh Boss Katakuri", "AutoKillBossOnly")
addButton(T1, "🚀 Triệu Hồi Katakuri Ngay", Color3.fromRGB(255, 170, 40), function() pcall(function() CommF:InvokeServer("CakePrinceSpawner", true) end) end)

-- Tab 2: Gom Quái
addToggle(T2, "🌪️ Bật Gom Quái Siêu Tốc (Magnet)", "AutoBring")
addSlider(T2, "📍 Bán Kính Gom Quái (Studs)", "BringRadius", 100, 400, 20)

-- Tab 3: Tấn Công
addToggle(T3, "⚡ Đánh Siêu Nhanh (Fast Attack x4)", "FastAttack")
addSlider(T3, "🚀 Hệ Số Đòn Đánh (Burst: 1x - 6x)", "AttackMultiplier", 1, 6, 1)
addDropdown(T3, "🗡️ Vũ Khí Tự Trang Bị", "WeaponType", {"Melee", "Sword", "Blox Fruit", "Gun"})

-- Tab 4: Haki & Tộc
addToggle(T4, "🛡️ Tự Bật Haki Vũ Trang (Buso)", "AutoBuso")
addToggle(T4, "👁️ Tự Bật Haki Quan Sát (Ken)", "AutoKen")
addToggle(T4, "⚡ Tự Bật Kỹ Năng Tộc V3 (Phím T)", "AutoRaceV3")
addToggle(T4, "🔥 Tự Thức Tỉnh Tộc V4 (Phím Y)", "AutoRaceV4")

-- Tab 5: Di Chuyển
addSlider(T5, "🚀 Tốc Độ Bay (Max 250 studs/s)", "FlySpeed", 50, 250, 10)
addSlider(T5, "📏 Khoảng Cách Trên Quái (Height)", "FarmDistance", 10, 25, 1)
addToggle(T5, "👻 Đi Xuyên Tường (NoClip)", "NoClip")

-- Tab 6: Đổi Server (Server Hopper)
addToggle(T6, "🌐 Tự Đổi Server Khi Chưa Đủ 300 Quái", "AutoHopKatakuriServer")
addSlider(T6, "📊 Số Quái Đã Diệt Tối Thiểu Để Ở Lại", "MinKilledToStay", 100, 450, 25)
addToggle(T6, "🔄 Đổi Server Sau Khi Diệt Xong Katakuri", "AutoHopAfterKillBoss")
addButton(T6, "✈️ Đổi Sang Server Ngẫu Nhiên Ngay", Color3.fromRGB(0, 180, 255), function()
    isHopping = false
    task.spawn(function()
        hopRandomServer(true)
    end)
end)

-- Tab 7: Cài Đặt
addButton(T7, "💾 Lưu Cấu Hình (" .. saveFile .. ")", Color3.fromRGB(50, 200, 120), saveSettings)
addButton(T7, "📂 Nạp Cấu Hình Đã Lưu", Color3.fromRGB(70, 150, 255), loadSettings)

switchTab("Katakuri")
print("[Katakuri Farm Pro] Khởi chạy thành công! Cấu hình lưu tại: " .. saveFile)
