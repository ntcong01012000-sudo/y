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
-- CẤU HÌNH HỆ THỐNG
-- =========================================================================
_G.AutoFarmChest = true
local ChestTargetLimit = 70
local FarmSpeed = 350
local countChests = 0

-- Kiểm tra thế giới (Sea) hiện tại
local isWorld3 = (game.PlaceId == 7449423635)
local isWorld2 = (game.PlaceId == 444227218)

-- Cấu hình Sea 3 (Rip Indra)
local SummonCFrame = CFrame.new(-5564.36, 314.57, -2661.53) -- Bệ spawn Rip Indra
local HakiSteps = {
    { Name = "Snow White", Position = CFrame.new(-4971.72, 335.96, -3720.06) },
    { Name = "Pure Red", Position = CFrame.new(-5414.92, 314.26, -2212.20) },
    { Name = "Winter Sky", Position = CFrame.new(-5420.26, 1089.36, -2666.82) }
}
_G.AutoKillRipIndra = false

-- Cấu hình Sea 2 (Darkbeard / Râu Đen)
-- Bạn có thể sửa tay tọa độ x, y, z của bệ spawn Râu Đen ở đây nếu muốn
local DarkbeardSummonCFrame = CFrame.new(3777.6, 14.8, -3498.4) 
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
-- PHƯƠNG THỨC TRUY XUẤT REMOTE AN TOÀN TRÁNH KẸT LUỒNG
-- =========================================================================
local function getCommF()
    local remotes = ReplicatedStorage:WaitForChild("Remotes", 5)
    return remotes and remotes:WaitForChild("CommF_", 5)
end

local function getFruitCustomizerRF()
    local modules = ReplicatedStorage:WaitForChild("Modules", 5)
    local net = modules and modules:WaitForChild("Net", 5)
    return net and net:WaitForChild("RF/FruitCustomizerRF", 5)
end

local function getRegisterAttack()
    local modules = ReplicatedStorage:WaitForChild("Modules", 5)
    local net = modules and modules:WaitForChild("Net", 5)
    return net and net:WaitForChild("RE/RegisterAttack", 5)
end

local function getRegisterHit()
    local modules = ReplicatedStorage:WaitForChild("Modules", 5)
    local net = modules and modules:WaitForChild("Net", 5)
    return net and net:WaitForChild("RE/RegisterHit", 5)
end

-- =========================================================================
-- DI CHUYỂN & CHỌN PHE
-- =========================================================================
local function selectTeam()
    local teamName = "Pirates"
    print("Đang tự động chọn phe: " .. teamName)
    pcall(function()
        local CommF = getCommF()
        if CommF then CommF:InvokeServer("SetTeam", teamName) end
    end)
    pcall(function()
        local pg = LocalPlayer:FindFirstChildOfClass("PlayerGui")
        if pg then
            for _, v in ipairs(pg:GetDescendants()) do
                if v:IsA("TextButton") and (v.Name == teamName or string.find(v.Text, teamName)) then
                    if getconnections then
                        for _, c in pairs(getconnections(v.MouseButton1Click)) do c.Function() end
                    elseif firesignal then
                        firesignal(v.MouseButton1Click)
                    end
                end
            end
        end
    end)
end

local function bayDen(targetCFrame, speed)
    local character = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
    local hrp = character:WaitForChild("HumanoidRootPart")
    local distance = (targetCFrame.Position - hrp.Position).Magnitude
    local duration = distance / speed
    
    local tween = TweenService:Create(hrp, TweenInfo.new(duration, Enum.EasingStyle.Linear), {CFrame = targetCFrame})
    
    local noclipConnection = RunService.Stepped:Connect(function()
        if character then
            for _, part in ipairs(character:GetDescendants()) do
                if part:IsA("BasePart") and part.CanCollide then
                    part.CanCollide = false
                end
            end
        end
    end)
    
    tween:Play()
    tween.Completed:Wait()
    if noclipConnection then noclipConnection:Disconnect() end
end

-- =========================================================================
-- HỆ THỐNG VẬT PHẨM HIẾM (CÚP / FIST)
-- =========================================================================
local function checkRareItems()
    local bp = LocalPlayer:FindFirstChild("Backpack")
    local char = LocalPlayer.Character
    if isWorld3 then
        return (bp and bp:FindFirstChild("God's Chalice")) or (char and char:FindFirstChild("God's Chalice"))
    elseif isWorld2 then
        return (bp and bp:FindFirstChild("Fist of Darkness")) or (char and char:FindFirstChild("Fist of Darkness"))
    end
    return false
end

local function equipRareItem()
    local char = LocalPlayer.Character
    if not char or not char:FindFirstChild("Humanoid") then return end
    local bp = LocalPlayer:FindFirstChild("Backpack")
    
    local itemName = isWorld3 and "God's Chalice" or "Fist of Darkness"
    local tool = bp and bp:FindFirstChild(itemName)
    if tool then
        char.Humanoid:EquipTool(tool)
    end
end

-- =========================================================================
-- HỌP SERVER VỚI KIỂM SOÁT THỬ LẠI LIÊN TỤC
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
    local maxPages = 3
    local candidateServers = {}
    local visited = getVisitedServers()
    
    pcall(function()
        repeat 
            local Servers = ListServers(Next)
            pageAttempts = pageAttempts + 1
            if Servers and Servers.data then
                for _, s in pairs(Servers.data) do
                    local playing = tonumber(s.playing)
                    local maxPlayers = tonumber(s.maxPlayers)
                    if s.id ~= game.JobId and not visited[s.id] and playing and maxPlayers and playing < (maxPlayers - 1) and playing >= 1 then
                        table.insert(candidateServers, s)
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
        table.sort(candidateServers, function(a, b) return tonumber(a.playing) < tonumber(b.playing) end)
        Server = candidateServers[1]
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
            print("🚨 Nhập vật phẩm hiếm lúc đang chuyển server! Dừng đổi server.")
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
-- FARM RƯƠNG (CHẠY CHUNG CHO CẢ SEA 2 VÀ SEA 3)
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
                bayDen(CFrame.new(chestPos), FarmSpeed)
                
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
-- LOGIC CHIẾN ĐẤU & TRANG BỊ VŨ KHÍ
-- =========================================================================
local function equipWeapon()
    local char = LocalPlayer.Character
    if not char or not char:FindFirstChild("Humanoid") then return end
    for _, tool in ipairs(char:GetChildren()) do
        if tool:IsA("Tool") and (tool.ToolTip == "Melee" or tool.ToolTip == "Sword") then return tool end
    end
    for _, tool in ipairs(LocalPlayer.Backpack:GetChildren()) do
        if tool:IsA("Tool") and (tool.ToolTip == "Melee" or tool.ToolTip == "Sword") then
            char.Humanoid:EquipTool(tool)
            return tool
        end
    end
end

local function attackBoss(boss, hitFunc, regAttack, regHit)
    local hrp = boss:FindFirstChild("HumanoidRootPart")
    local hum = boss:FindFirstChild("Humanoid")
    if hrp and hum and hum.Health > 0 then
        -- Vô hiệu hóa Animator của boss
        local anim = hum:FindFirstChild("Animator")
        if anim then anim:Destroy() end
        
        -- Bay bám sát cách đầu boss 12 studs
        bayDen(hrp.CFrame * CFrame.new(0, 12, 0), 300)
        
        -- Kích hoạt Haki vũ trang
        pcall(function() getCommF():InvokeServer("Buso") end)
        
        local wp = equipWeapon()
        if wp then
            if regAttack then regAttack:FireServer(0) end
            local targetPart = boss:FindFirstChild("Head") or hrp
            local targets = {{boss, targetPart}}
            if hitFunc then
                pcall(function() hitFunc(targetPart, targets) end)
            else
                if regHit then regHit:FireServer(targetPart, targets) end
            end
            VirtualUser:Button1Down(Vector2.new(1280, 720))
        end
    end
end

-- Lấy hàm hit gốc nếu executor hỗ trợ để tối ưu sát thương
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

-- =========================================================================
-- LOGIC SĂN BOSS RIP INDRA (SEA 3)
-- =========================================================================
local function equipHakiColor(colorName)
    local rf = getFruitCustomizerRF()
    if rf then
        local args = { [1] = { ["StorageName"] = colorName, ["Type"] = "AuraSkin", ["Context"] = "Equip" } }
        pcall(function() rf:InvokeServer(unpack(args)) end)
    end
end

local function processRipIndraSummon()
    print("🔥 Đang tiến hành kích hoạt 3 nút Haki pháo đài...")
    for i, step in ipairs(HakiSteps) do
        print(string.format("[%d/3] Đổi màu: %s -> Bay đến nút", i, step.Name))
        equipHakiColor(step.Name)
        task.wait(0.2)
        bayDen(step.Position, 300)
        task.wait(1)
    end
    
    print("🎒 Đeo Chén Thánh và bay đến bệ triệu hồi...")
    equipRareItem()
    task.wait(0.5)
    bayDen(SummonCFrame, 300)
    task.wait(2)
    
    -- Bắt đầu đánh boss Rip Indra
    _G.AutoKillRipIndra = true
    bossSpawned = false
    local hitFunc = getHitFunction()
    local regAttack = getRegisterAttack()
    local regHit = getRegisterHit()
    
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
                
                -- Tìm boss ở Workspace
                if enemies then
                    for _, enemy in ipairs(enemies:GetChildren()) do
                        if string.find(enemy.Name, "rip_indra") and enemy:FindFirstChild("Humanoid") and enemy.Humanoid.Health > 0 then
                            boss = enemy
                            bossSpawned = true
                            break
                        end
                    end
                end
                
                -- Tìm boss ở ReplicatedStorage
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
                        -- Bay đến ép game load
                        local targetPos = boss:FindFirstChild("HumanoidRootPart") and boss.HumanoidRootPart.CFrame or CFrame.new(-5354.76, 423.85, -2701.32)
                        bayDen(targetPos, 300)
                    else
                        attackBoss(boss, hitFunc, regAttack, regHit)
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
-- LOGIC SĂN BOSS DARKBEARD (SEA 2)
-- =========================================================================
local function summonDarkbeard()
    local char = LocalPlayer.Character
    local tool = char and (char:FindFirstChild("Fist of Darkness") or LocalPlayer.Backpack:FindFirstChild("Fist of Darkness"))
    if tool then
        if tool.Parent == LocalPlayer.Backpack then
            char.Humanoid:EquipTool(tool)
        end
        local detection = workspace:FindFirstChild("Map") 
            and workspace.Map:FindFirstChild("DarkbeardArena")
            and workspace.Map.DarkbeardArena:FindFirstChild("Summoner")
            and workspace.Map.DarkbeardArena.Summoner:FindFirstChild("Detection")
        
        if detection then
            firetouchinterest(tool.Handle, detection, 0)
            firetouchinterest(tool.Handle, detection, 1)
            firetouchinterest(char.HumanoidRootPart, detection, 0)
            firetouchinterest(char.HumanoidRootPart, detection, 1)
        end
    end
end

local function processDarkbeardSummon()
    print("🎒 Đeo Fist of Darkness và bay đến bệ triệu hồi Darkbeard...")
    equipRareItem()
    task.wait(0.5)
    
    local targetPos = DarkbeardSummonCFrame
    pcall(function()
        local detection = workspace.Map.DarkbeardArena.Summoner.Detection
        if detection then targetPos = detection.CFrame end
    end)
    
    bayDen(targetPos, 300)
    task.wait(1)
    summonDarkbeard()
    task.wait(2)
    
    -- Bắt đầu đánh boss Darkbeard
    _G.AutoKillDarkbeard = true
    bossSpawned = false
    local hitFunc = getHitFunction()
    local regAttack = getRegisterAttack()
    local regHit = getRegisterHit()
    
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
                
                -- Tìm Râu Đen ở Workspace
                if enemies then
                    for _, enemy in ipairs(enemies:GetChildren()) do
                        if string.find(enemy.Name, "Darkbeard") and enemy:FindFirstChild("Humanoid") and enemy.Humanoid.Health > 0 then
                            boss = enemy
                            bossSpawned = true
                            break
                        end
                    end
                end
                
                -- Tìm Râu Đen ở ReplicatedStorage
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
                        bayDen(targetPos, 300)
                    else
                        attackBoss(boss, hitFunc, regAttack, regHit)
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
-- LUỒNG GIÁM SÁT RƠI CÚP / FIST / LỖI BOSS (FALLBACK)
-- =========================================================================
task.spawn(function()
    while true do
        task.wait(1)
        local hasRare = checkRareItems()
        if hasRare then hadRareItem = true end
        
        if hadRareItem and not hasRare then
            task.wait(2) -- Chờ tải balo
            if not checkRareItems() then
                local boss = nil
                local enemies = workspace:FindFirstChild("Enemies")
                
                if isWorld3 then
                    if enemies then
                        for _, enemy in ipairs(enemies:GetChildren()) do
                            if string.find(enemy.Name, "rip_indra") and enemy:FindFirstChild("Humanoid") and enemy.Humanoid.Health > 0 then
                                boss = enemy; break
                            end
                        end
                    end
                elseif isWorld2 then
                    if enemies then
                        for _, enemy in ipairs(enemies:GetChildren()) do
                            if string.find(enemy.Name, "Darkbeard") and enemy:FindFirstChild("Humanoid") and enemy.Humanoid.Health > 0 then
                                boss = enemy; break
                            end
                        end
                    end
                end
                
                -- Mất vật phẩm mà boss không xuất hiện -> Đổi server ngay lập tức
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
-- LUỒNG QUÉT TÌM SERVER VẮNG CHẠY SONG SONG
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
                local visited = getVisitedServers()
                
                repeat 
                    local Servers = ListServers(Next)
                    pageAttempts = pageAttempts + 1
                    if Servers and Servers.data then
                        for _, server in pairs(Servers.data) do
                            local playing = tonumber(server.playing)
                            local maxPlayers = tonumber(server.maxPlayers)
                            if server.id ~= game.JobId and not visited[server.id] and playing and maxPlayers and playing < (maxPlayers - 1) and playing >= 1 then
                                table.insert(candidateServers, server)
                            end
                        end
                        Next = Servers.nextPageCursor
                    else
                        break
                    end
                    task.wait(0.2)
                until #candidateServers > 0 or not Next or pageAttempts >= 3
                
                if #candidateServers > 0 then
                    table.sort(candidateServers, function(a, b) return tonumber(a.playing) < tonumber(b.playing) end)
                    _G.NextServerId = candidateServers[1].id
                    print("📡 [Quét Server Ngầm] Đã lưu trữ sẵn Server vắng: " .. candidateServers[1].playing .. " người chơi.")
                end
            end)
        end
    end
end)

-- =========================================================================
-- VÒNG LẶP KHỞI CHẠY CHÍNH
-- =========================================================================
task.spawn(function()
    task.wait(2)
    selectTeam()
    task.wait(2)
    
    print("========== HỆ THỐNG AUTO CHEST & BOSS KHỞI CHẠY ==========")
    runFarmChest()
    
    while true do
        task.wait(1)
        if checkRareItems() then
            print("🔥 PHÁT HIỆN VẬT PHẨM SỰ KIỆN TRONG BALO! DỪNG FARM RƯƠNG...")
            _G.AutoFarmChest = false
            task.wait(1.5)
            
            if isWorld3 then
                processRipIndraSummon()
            elseif isWorld2 then
                processDarkbeardSummon()
            end
            break
        end
    end
end)
