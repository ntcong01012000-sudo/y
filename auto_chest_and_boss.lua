local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local TeleportService = game:GetService("TeleportService")
local HttpService = game:GetService("HttpService")
local VirtualUser = game:GetService("VirtualUser")

local LocalPlayer = Players.LocalPlayer

-- =========================================================================
-- KHAI BÁO CÁC REMOTE GỐC TỪ AUTO_KILL_RIP_INDRA.LUA ĐỂ GÂY SÁT THƯƠNG CHUẨN XÁC
-- =========================================================================
local CommF = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("CommF_")
local RegisterAttack = ReplicatedStorage:WaitForChild("Modules"):WaitForChild("Net"):WaitForChild("RE/RegisterAttack")
local RegisterHit = ReplicatedStorage:WaitForChild("Modules"):WaitForChild("Net"):WaitForChild("RE/RegisterHit")
local FruitCustomizerRF = ReplicatedStorage:WaitForChild("Modules"):WaitForChild("Net"):WaitForChild("RF/FruitCustomizerRF")

-- =========================================================================
-- CẤU HÌNH HỆ THỐNG
-- =========================================================================
_G.AutoFarmChest = true
local ChestTargetLimit = 70
local FarmSpeed = 300
local countChests = 0

-- Cấu hình Sea 3 (Rip Indra)
local SummonCFrame = CFrame.new(-5564.36, 314.57, -2661.53) -- Bệ spawn Rip Indra
local HakiSteps = {
    { Name = "Snow White", Position = CFrame.new(-4971.72, 334.96, -3720.06) },
    { Name = "Pure Red", Position = CFrame.new(-5414.92, 314.26, -2212.20) },
    { Name = "Winter Sky", Position = CFrame.new(-5420.26, 1089.36, -2666.82) }
}
_G.AutoKillRipIndra = false

-- Cấu hình Sea 2 (Darkbeard / Râu Đen)
local DarkbeardSummonCFrame = CFrame.new(3780.88, 17.05, -3499.23) -- Vị trí bệ spawn Darkbeard ở Sea 2
_G.AutoKillDarkbeard = false

-- Biến lưu trữ trạng thái boss đã spawn và server vắng quét sẵn
local bossSpawned = false
local hadRareItem = false
_G.NextServerId = nil

-- =========================================================================
-- HỆ THỐNG GHI NHỚ SERVER (LƯU FILE visited_servers.txt)
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
            if #lines > 50 then table.remove(lines, 1) end
            writefile("visited_servers.txt", table.concat(lines, "\n"))
        end
    end)
end

pcall(function() saveVisitedServer(game.JobId) end)

-- =========================================================================
-- HÀM CHỌN PHE & DI CHUYỂN (NGUYÊN BẢN TỪ AUTO_KILL_RIP_INDRA.LUA)
-- =========================================================================
local function selectTeam()
    local teamName = "Pirates"
    print("Đang tự động chọn phe: " .. teamName)
    pcall(function()
        if CommF then CommF:InvokeServer("SetTeam", teamName) end
    end)
    pcall(function()
        local pg = LocalPlayer:FindFirstChildOfClass("PlayerGui")
        if pg then
            for _, v in ipairs(pg:GetDescendants()) do
                if v:IsA("TextButton") and (v.Name == teamName or string.find(v.Text, teamName)) then
                    local clicked = false
                    if getconnections then
                        for _, c in pairs(getconnections(v.MouseButton1Click)) do
                            c.Function()
                            clicked = true
                        end
                    end
                    if not clicked and firesignal then
                        firesignal(v.MouseButton1Click)
                        clicked = true
                    end
                    if not clicked then
                        pcall(function() v:Click() end)
                    end
                end
            end
        end
    end)
end

-- Hàm di chuyển (Tween nếu ở xa, Teleport CFrame nếu ở gần) - Nguyên bản từ auto_kill_rip_indra.lua
local function DiChuyenDen(targetCFrame, customSpeed)
    local speed = customSpeed or 300
    local character = LocalPlayer.Character
    if not character or not character:FindFirstChild("HumanoidRootPart") then return end
    local hrp = character.HumanoidRootPart
    
    local distance = (targetCFrame.Position - hrp.Position).Magnitude
    
    if distance > 150 then
        -- Bay mượt bằng Tween nếu ở xa để tránh bị kick anti-cheat
        local duration = distance / speed
        local tweenInfo = TweenInfo.new(duration, Enum.EasingStyle.Linear)
        local tween = TweenService:Create(hrp, tweenInfo, {CFrame = targetCFrame})
        
        -- Bật Noclip khi đang bay để không bị kẹt địa hình
        local noclip
        noclip = RunService.Stepped:Connect(function()
            if character then
                for _, part in ipairs(character:GetDescendants()) do
                    if part:IsA("BasePart") then
                        part.CanCollide = false
                    end
                end
            end
        end)
        
        tween:Play()
        tween.Completed:Wait()
        
        if noclip then noclip:Disconnect() end
    else
        -- Khi ở cực gần thì bám sát trực tiếp (Teleport CFrame) để đập boss không bị trượt
        hrp.CFrame = targetCFrame
    end
end

-- =========================================================================
-- HỆ THỐNG VẬT PHẨM HIẾM (CÚP / FIST) - PHÁT HIỆN TRỰC TIẾP KHÔNG DÙNG PLACEID
-- =========================================================================
local function checkRareItems()
    local bp = LocalPlayer:FindFirstChild("Backpack")
    local char = LocalPlayer.Character
    
    local hasChalice = (bp and bp:FindFirstChild("God's Chalice")) or (char and char:FindFirstChild("God's Chalice"))
    local hasFist = (bp and bp:FindFirstChild("Fist of Darkness")) or (char and char:FindFirstChild("Fist of Darkness"))
    
    return hasChalice or hasFist
end

local function equipRareItem()
    local char = LocalPlayer.Character
    if not char or not char:FindFirstChild("Humanoid") then return end
    local bp = LocalPlayer:FindFirstChild("Backpack")
    if not bp then return end
    
    local chalice = bp:FindFirstChild("God's Chalice")
    if chalice then
        char.Humanoid:EquipTool(chalice)
        return
    end
    
    local fist = bp:FindFirstChild("Fist of Darkness")
    if fist then
        char.Humanoid:EquipTool(fist)
        return
    end
end

-- =========================================================================
-- HỌP SERVER CÓ ƯU TIÊN SERVER CÓ ĐÚNG 1 NGƯỜI CHƠI
-- =========================================================================
local function hopLowServerFast()
    local CurrentPlaceId = game.PlaceId
    local apiUrl = "https://games.roblox.com/v1/games/" .. CurrentPlaceId .. "/servers/Public?sortOrder=Asc&limit=100"
    
    local function ListServers(cursor)
        local success, raw = pcall(function() return game:HttpGet(apiUrl .. ((cursor and "&cursor=" .. cursor) or "")) end)
        return success and HttpService:JSONDecode(raw) or nil
    end
    
    local Server, Next
    local pageAttempts = 0
    local maxPages = 5
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
            task.wait(0.2)
        until #candidateServers > 0 or not Next or pageAttempts >= maxPages
    end)
    
    if #candidateServers > 0 then
        Server = candidateServers[1]
    elseif #fallbackServers > 0 then
        table.sort(fallbackServers, function(a, b) return tonumber(a.playing) < tonumber(b.playing) end)
        Server = fallbackServers[1]
    end
    
    if Server then
        saveVisitedServer(Server.id)
        pcall(function() ReplicatedStorage:WaitForChild("__ServerBrowser", 5):InvokeServer("teleport", Server.id) end)
        task.wait(3)
        pcall(function() TeleportService:TeleportToPlaceInstance(CurrentPlaceId, Server.id, LocalPlayer) end)
    end
end

local function thucHienHopServer()
    if checkRareItems() then return end
    _G.AutoFarmChest = false
    _G.AutoKillRipIndra = false
    _G.AutoKillDarkbeard = false
    
    print("🔄 Bắt đầu chu kỳ đổi Server liên tục cho đến khi thành công...")
    while true do
        if checkRareItems() then
            print("🚨 Nhận vật phẩm hiếm lúc đang chuyển server! Dừng đổi server.")
            break
        end
        
        local targetId = _G.NextServerId
        _G.NextServerId = nil
        
        if targetId then
            print("✈️ Thử dịch chuyển đến Server: " .. targetId)
            saveVisitedServer(targetId)
            pcall(function() ReplicatedStorage:WaitForChild("__ServerBrowser", 5):InvokeServer("teleport", targetId) end)
            task.wait(3)
            pcall(function() TeleportService:TeleportToPlaceInstance(game.PlaceId, targetId, LocalPlayer) end)
        else
            hopLowServerFast()
        end
        task.wait(8)
    end
end

-- =========================================================================
-- FARM RƯƠNG
-- =========================================================================
local function getNearestChest()
    local char = LocalPlayer.Character
    if not char or not char:FindFirstChild("HumanoidRootPart") then return nil end
    local myPos = char.HumanoidRootPart.Position
    local chests = CollectionService:GetTagged("_ChestTagged")
    local nearest = nil
    local shortest = math.huge
    
    for _, chest in ipairs(chests) do
        if (chest:IsA("BasePart") or chest:IsA("Model")) and not chest:GetAttribute("IsDisabled") then
            local chestPos = chest:GetPivot().Position
            local dist = (chestPos - myPos).Magnitude
            if dist < shortest then
                shortest = dist
                nearest = chest
            end
        end
    end
    return nearest
end

local function runFarmChest()
    local globalNoclip = RunService.Stepped:Connect(function()
        if _G.AutoFarmChest and LocalPlayer.Character then
            for _, part in ipairs(LocalPlayer.Character:GetDescendants()) do
                if part:IsA("BasePart") then part.CanCollide = false end
            end
        end
    end)
    
    task.spawn(function()
        while _G.AutoFarmChest do
            task.wait()
            if checkRareItems() then
                _G.AutoFarmChest = false
                globalNoclip:Disconnect()
                break
            end
            
            local targetChest = getNearestChest()
            if targetChest then
                local chestPos = targetChest:GetPivot().Position
                DiChuyenDen(CFrame.new(chestPos), FarmSpeed)
                
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
                print(string.format("🎒 Nhặt rương (%d/%d)", countChests, ChestTargetLimit))
                
                if countChests >= ChestTargetLimit then
                    globalNoclip:Disconnect()
                    thucHienHopServer()
                    break
                end
            else
                print("⚠️ Hết rương trên server này. Đang đổi server...")
                globalNoclip:Disconnect()
                thucHienHopServer()
                break
            end
        end
    end)
end

-- =========================================================================
-- LOGIC CHIẾN ĐẤU & TRANG BỊ VŨ KHÍ (NGUYÊN BẢN TỪ AUTO_KILL_RIP_INDRA.LUA)
-- =========================================================================

-- Tự động bật Haki vũ trang (Buso Haki)
local function KichHoatHaki()
    local character = LocalPlayer.Character
    if character and not character:FindFirstChild("HasBuso") then
        pcall(function()
            CommF:InvokeServer("Buso")
        end)
    end
end

-- Tự động trang bị vũ khí cận chiến/kiếm
local function TrangBiVuKhi()
    local character = LocalPlayer.Character
    if not character or not character:FindFirstChild("Humanoid") then return end
    
    for _, tool in ipairs(character:GetChildren()) do
        if tool:IsA("Tool") and (tool.ToolTip == "Melee" or tool.ToolTip == "Sword") then
            return tool
        end
    end
    
    for _, tool in ipairs(LocalPlayer.Backpack:GetChildren()) do
        if tool:IsA("Tool") and (tool.ToolTip == "Melee" or tool.ToolTip == "Sword") then
            character.Humanoid:EquipTool(tool)
            return tool
        end
    end
end

-- Lấy hàm hit gốc
local function LayHamHitGoc()
    if getsenv then
        for _, script in ipairs(LocalPlayer.PlayerScripts:GetChildren()) do
            if script:IsA("LocalScript") then
                local success, env = pcall(getsenv, script)
                if success and env and env._G and env._G.SendHitsToServer then
                    return env._G.SendHitsToServer
                end
            end
        end
    end
    return nil
end

-- =========================================================================
-- LOGIC SĂN BOSS RIP INDRA (SEA 3) - NGUYÊN BẢN TỪ AUTO_KILL_RIP_INDRA.LUA
-- =========================================================================
local function equipHakiColor(colorName)
    if FruitCustomizerRF then
        local args = { [1] = { ["StorageName"] = colorName, ["Type"] = "AuraSkin", ["Context"] = "Equip" } }
        pcall(function() FruitCustomizerRF:InvokeServer(unpack(args)) end)
    end
end

local function hasGodChalice()
    local bp = LocalPlayer:FindFirstChild("Backpack")
    local char = LocalPlayer.Character
    return (bp and bp:FindFirstChild("God's Chalice")) or (char and char:FindFirstChild("God's Chalice"))
end

local function hasFistOfDarkness()
    local bp = LocalPlayer:FindFirstChild("Backpack")
    local char = LocalPlayer.Character
    return (bp and bp:FindFirstChild("Fist of Darkness")) or (char and char:FindFirstChild("Fist of Darkness"))
end

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

local function processRipIndraSummon()
    local attempts = 0
    while hasGodChalice() and not isRipIndraSpawned() do
        attempts = attempts + 1
        print(string.format("🔥 [Lần thử %d] Đang tiến hành kích hoạt 3 nút Haki pháo đài...", attempts))
        for i, step in ipairs(HakiSteps) do
            if not hasGodChalice() or isRipIndraSpawned() then break end
            print(string.format("[%d/3] Đổi màu: %s -> Bay đến nút", i, step.Name))
            equipHakiColor(step.Name)
            task.wait(0.5)
            DiChuyenDen(step.Position, 300)
            task.wait(0.2)
            -- Di chuyển nhẹ qua lại để chắc chắn chạm nút Haki
            DiChuyenDen(step.Position * CFrame.new(0, 0, 1), 300)
            task.wait(0.2)
            DiChuyenDen(step.Position * CFrame.new(0, 0, -1), 300)
            task.wait(0.8)
        end
        
        if not hasGodChalice() or isRipIndraSpawned() then break end
        
        print("🎒 Đeo Chén Thánh và bay đến bệ triệu hồi...")
        equipRareItem()
        task.wait(0.5)
        DiChuyenDen(SummonCFrame, 300)
        task.wait(0.2)
        -- Di chuyển nhẹ trên bệ để kích hoạt touch
        DiChuyenDen(SummonCFrame * CFrame.new(0, 0, 2), 300)
        task.wait(0.5)
        DiChuyenDen(SummonCFrame * CFrame.new(0, 0, -2), 300)
        task.wait(0.5)
        DiChuyenDen(SummonCFrame, 300)
        
        -- Đợi một lát xem boss đã spawn chưa
        print("⏳ Đang đợi boss Rip Indra spawn...")
        local spawnWaitTime = 0
        while spawnWaitTime < 5 do
            task.wait(0.5)
            spawnWaitTime = spawnWaitTime + 0.5
            if isRipIndraSpawned() or not hasGodChalice() then
                break
            end
        end
        
        if isRipIndraSpawned() or not hasGodChalice() then
            print("✅ Boss đã xuất hiện hoặc đã mất Chén Thánh (đã spawn thành công)!")
            break
        else
            print("❌ Chưa spawn được boss! Tiến hành thử lại...")
        end
    end
    
    _G.AutoKillRipIndra = true
    bossSpawned = isRipIndraSpawned()
    local hitFunction = LayHamHitGoc()
    
    local noclip = RunService.Stepped:Connect(function()
        if _G.AutoKillRipIndra and LocalPlayer.Character then
            for _, p in ipairs(LocalPlayer.Character:GetDescendants()) do
                if p:IsA("BasePart") then p.CanCollide = false end
            end
        end
    end)
    
    task.spawn(function()
        while _G.AutoKillRipIndra do
            task.wait()
            pcall(function()
                local enemies = workspace:FindFirstChild("Enemies")
                local boss = nil
                
                if enemies then
                    for _, enemy in ipairs(enemies:GetChildren()) do
                        if string.find(enemy.Name, "rip_indra") and enemy:FindFirstChild("Humanoid") and enemy.Humanoid.Health > 0 then
                            boss = enemy
                            bossSpawned = true
                            break
                        end
                    end
                end
                
                if not boss then
                    for _, obj in ipairs(ReplicatedStorage:GetChildren()) do
                        if string.find(obj.Name, "rip_indra") and obj:FindFirstChild("Humanoid") then
                            boss = obj
                            break
                        end
                    end
                end
                
                if boss then
                    if boss.Parent == ReplicatedStorage then
                        local targetPos = boss:FindFirstChild("HumanoidRootPart") and boss.HumanoidRootPart.CFrame or CFrame.new(-5354.76, 423.85, -2701.32)
                        DiChuyenDen(targetPos, 300)
                    else
                        local hrp = boss:FindFirstChild("HumanoidRootPart")
                        local humanoid = boss:FindFirstChild("Humanoid")
                        
                        if hrp and humanoid and humanoid.Health > 0 then
                            KichHoatHaki()
                            local weapon = TrangBiVuKhi()
                            
                            local animator = humanoid:FindFirstChild("Animator")
                            if animator then animator:Destroy() end
                            
                            local targetPos = hrp.CFrame * CFrame.new(0, 12, 0)
                            DiChuyenDen(targetPos, 300)
                            
                            if weapon then
                                local targetPart = boss:FindFirstChild("Head") or hrp
                                local targetsList = {{boss, targetPart}}
                                
                                RegisterAttack:FireServer(0)
                                
                                if hitFunction then
                                    pcall(function()
                                        hitFunction(targetPart, targetsList)
                                    end)
                                else
                                    RegisterHit:FireServer(targetPart, targetsList)
                                end
                                
                                pcall(function()
                                    VirtualUser:Button1Down(Vector2.new(1280, 720))
                                end)
                            end
                        end
                    end
                else
                    if bossSpawned then
                        print("🎉 Boss Rip Indra đã bị tiêu diệt! Đổi server...")
                        _G.AutoKillRipIndra = false
                        noclip:Disconnect()
                        task.wait(1.5)
                        thucHienHopServer()
                    end
                end
            end)
        end
    end)
end

-- =========================================================================
-- LOGIC SĂN BOSS DARKBEARD (SEA 2) - SỬ DỤNG CHUNG LOGIC ĐÁNH BOSS GỐC
-- =========================================================================
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

local function processDarkbeardSummon()
    local attempts = 0
    while hasFistOfDarkness() and not isDarkbeardSpawned() do
        attempts = attempts + 1
        print(string.format("🎒 [Lần thử %d] Đeo Fist of Darkness và bay đến bệ triệu hồi Darkbeard...", attempts))
        equipRareItem()
        task.wait(0.5)
        
        local targetPos = DarkbeardSummonCFrame
        pcall(function()
            local detection = workspace.Map.DarkbeardArena.Summoner.Detection
            if detection then targetPos = detection.CFrame end
        end)
        
        DiChuyenDen(targetPos, 300)
        task.wait(0.5)
        summonDarkbeard()
        task.wait(0.5)
        -- Di chuyển nhẹ qua lại xung quanh bệ để kích hoạt touch
        DiChuyenDen(targetPos * CFrame.new(0, 0, 2), 300)
        task.wait(0.5)
        DiChuyenDen(targetPos * CFrame.new(0, 0, -2), 300)
        task.wait(0.5)
        DiChuyenDen(targetPos, 300)
        
        -- Chờ một lúc xem boss đã spawn chưa
        print("⏳ Đang đợi boss Darkbeard spawn...")
        local spawnWaitTime = 0
        while spawnWaitTime < 5 do
            task.wait(0.5)
            spawnWaitTime = spawnWaitTime + 0.5
            if isDarkbeardSpawned() or not hasFistOfDarkness() then
                break
            end
        end
        
        if isDarkbeardSpawned() or not hasFistOfDarkness() then
            print("✅ Boss Darkbeard đã xuất hiện hoặc đã mất Fist of Darkness (đã spawn thành công)!")
            break
        else
            print("❌ Chưa spawn được boss Darkbeard! Tiến hành thử lại...")
        end
    end
    
    _G.AutoKillDarkbeard = true
    bossSpawned = isDarkbeardSpawned()
    local hitFunction = LayHamHitGoc()
    
    local noclip = RunService.Stepped:Connect(function()
        if _G.AutoKillDarkbeard and LocalPlayer.Character then
            for _, p in ipairs(LocalPlayer.Character:GetDescendants()) do
                if p:IsA("BasePart") then p.CanCollide = false end
            end
        end
    end)
    
    task.spawn(function()
        while _G.AutoKillDarkbeard do
            task.wait()
            pcall(function()
                local enemies = workspace:FindFirstChild("Enemies")
                local boss = nil
                
                if enemies then
                    for _, enemy in ipairs(enemies:GetChildren()) do
                        if string.find(enemy.Name, "Darkbeard") and enemy:FindFirstChild("Humanoid") and enemy.Humanoid.Health > 0 then
                            boss = enemy
                            bossSpawned = true
                            break
                        end
                    end
                end
                
                if not boss then
                    for _, obj in ipairs(ReplicatedStorage:GetChildren()) do
                        if string.find(obj.Name, "Darkbeard") and obj:FindFirstChild("Humanoid") then
                            boss = obj
                            break
                        end
                    end
                end
                
                if boss then
                    if boss.Parent == ReplicatedStorage then
                        local targetPos = boss:FindFirstChild("HumanoidRootPart") and boss.HumanoidRootPart.CFrame or DarkbeardSummonCFrame
                        DiChuyenDen(targetPos, 300)
                    else
                        local hrp = boss:FindFirstChild("HumanoidRootPart")
                        local humanoid = boss:FindFirstChild("Humanoid")
                        
                        if hrp and humanoid and humanoid.Health > 0 then
                            KichHoatHaki()
                            local weapon = TrangBiVuKhi()
                            
                            local animator = humanoid:FindFirstChild("Animator")
                            if animator then animator:Destroy() end
                            
                            local targetPos = hrp.CFrame * CFrame.new(0, 12, 0)
                            DiChuyenDen(targetPos, 300)
                            
                            if weapon then
                                local targetPart = boss:FindFirstChild("Head") or hrp
                                local targetsList = {{boss, targetPart}}
                                
                                RegisterAttack:FireServer(0)
                                
                                if hitFunction then
                                    pcall(function()
                                        hitFunction(targetPart, targetsList)
                                    end)
                                else
                                    RegisterHit:FireServer(targetPart, targetsList)
                                end
                                
                                pcall(function()
                                    VirtualUser:Button1Down(Vector2.new(1280, 720))
                                end)
                            end
                        end
                    end
                else
                    if bossSpawned then
                        print("🎉 Boss Darkbeard đã bị tiêu diệt! Đổi server...")
                        _G.AutoKillDarkbeard = false
                        noclip:Disconnect()
                        task.wait(1.5)
                        thucHienHopServer()
                    end
                end
            end)
        end
    end)
end

-- =========================================================================
-- LUỒNG GIÁM SÁT RƠI CÚP / FIST / LỖI BOSS (FALLBACK AN TOÀN CHUNG)
-- =========================================================================
task.spawn(function()
    while true do
        task.wait(1)
        local hasRare = checkRareItems()
        if hasRare then hadRareItem = true end
        
        if hadRareItem and not hasRare then
            task.wait(2)
            if not checkRareItems() then
                local boss = nil
                local enemies = workspace:FindFirstChild("Enemies")
                
                if enemies then
                    for _, enemy in ipairs(enemies:GetChildren()) do
                        if (string.find(enemy.Name, "rip_indra") or string.find(enemy.Name, "Darkbeard")) 
                           and enemy:FindFirstChild("Humanoid") and enemy.Humanoid.Health > 0 then
                            boss = enemy; break
                        end
                    end
                end
                
                if not boss then
                    print("🚨 CẢNH BÁO: Mất vật phẩm sự kiện nhưng không tìm thấy Boss! Tự động đổi Server...")
                    task.wait(1)
                    thucHienHopServer()
                    break
                end
            end
        end
    end
end)

-- =========================================================================
-- LUỒNG QUÉT TÌM SERVER 1 NGƯỜI CHƠI CHẠY SONG SONG
-- =========================================================================
task.spawn(function()
    while true do
        if _G.NextServerId then
            task.wait(15)
            _G.NextServerId = nil
        else
            task.wait(2)
        end
        
        if _G.AutoFarmChest and not checkRareItems() then
            pcall(function()
                local apiUrl = "https://games.roblox.com/v1/games/" .. game.PlaceId .. "/servers/Public?sortOrder=Asc&limit=100"
                local function ListServers(cursor)
                    local success, raw = pcall(function() return game:HttpGet(apiUrl .. ((cursor and "&cursor=" .. cursor) or "")) end)
                    return success and HttpService:JSONDecode(raw) or nil
                end
                local Next
                local pageAttempts = 0
                local candidateServers = {}
                local fallbackServers = {}
                local visited = getVisitedServers()
                
                repeat 
                    local Servers = ListServers(Next)
                    pageAttempts = pageAttempts + 1
                    if Servers and Servers.data then
                        for _, server in pairs(Servers.data) do
                            local playing = tonumber(server.playing)
                            local maxPlayers = tonumber(server.maxPlayers)
                            if server.id ~= game.JobId and not visited[server.id] and playing and maxPlayers and playing < (maxPlayers - 1) then
                                if playing == 1 then
                                    table.insert(candidateServers, server)
                                else
                                    table.insert(fallbackServers, server)
                                end
                            end
                        end
                        Next = Servers.nextPageCursor
                    else
                        break
                    end
                    task.wait(0.2)
                until #candidateServers > 0 or not Next or pageAttempts >= 5
                
                local selectedServer = nil
                if #candidateServers > 0 then
                    selectedServer = candidateServers[1]
                elseif #fallbackServers > 0 then
                    table.sort(fallbackServers, function(a, b) return tonumber(a.playing) < tonumber(b.playing) end)
                    selectedServer = fallbackServers[1]
                end
                
                if selectedServer then
                    _G.NextServerId = selectedServer.id
                    print("📡 [Quét Server Ngầm] Đã lưu trữ sẵn Server vắng: " .. selectedServer.playing .. " người chơi.")
                end
            end)
        end
    end
end)

-- =========================================================================
-- VÒNG LẶP KHỞI CHẠY CHÍNH (ĐỊNH TUYẾN DỰA TRÊN VẬT PHẨM TRỰC TIẾP)
-- =========================================================================
task.spawn(function()
    task.wait(2)
    selectTeam()
    task.wait(2)
    
    print("========== HỆ THỐNG AUTO CHEST & BOSS KHỞI CHẠY ==========")
    runFarmChest()
    
    while true do
        task.wait(1)
        
        local bp = LocalPlayer:FindFirstChild("Backpack")
        local char = LocalPlayer.Character
        
        local chalice = (bp and bp:FindFirstChild("God's Chalice")) or (char and char:FindFirstChild("God's Chalice"))
        local fist = (bp and bp:FindFirstChild("Fist of Darkness")) or (char and char:FindFirstChild("Fist of Darkness"))
        
        if chalice or fist then
            print("🔥 PHÁT HIỆN VẬT PHẨM SỰ KIỆN TRONG BALO! DỪNG FARM RƯƠNG...")
            _G.AutoFarmChest = false
            task.wait(1.5)
            
            if chalice then
                print("Chén Thánh phát hiện. Khởi động quy trình Rip Indra Sea 3...")
                processRipIndraSummon()
            elseif fist then
                print("Fist of Darkness phát hiện. Khởi động quy trình Darkbeard Sea 2...")
                processDarkbeardSummon()
            end
            break
        end
    end
end)
