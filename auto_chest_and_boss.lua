-- Script tổng hợp: Auto Farm Chest + Tự động triệu hồi & Tiêu diệt Boss (Rip Indra ở Sea 3 / Darkbeard ở Sea 2) -> Đổi Server ít người
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local TeleportService = game:GetService("TeleportService")
local HttpService = game:GetService("HttpService")
local VirtualUser = game:GetService("VirtualUser")

local LocalPlayer = Players.LocalPlayer

-- Cấu hình chung
_G.AutoFarmChest = true -- Chuyển thành false để dừng script nhặt rương
_G.AutoKillBoss = false -- Điều khiển đánh boss
local ChestTargetLimit = 70 -- Số lượng rương cần nhặt trước khi đổi server
local FarmSpeed = 350 -- Tốc độ bay đi nhặt rương
local TravelSpeed = 300 -- Tốc độ bay khi làm sự kiện/diệt boss

-- Tọa độ triệu hồi ở Sea 3 (Rip Indra) và Sea 2 (Darkbeard)
local IndraSummonCFrame = CFrame.new(-5564.36, 314.57, -2661.53)
local HakiSteps = {
    { Name = "Snow White", Position = CFrame.new(-4971.71826171875, 335.9582214355469, -3720.0595703125) },
    { Name = "Pure Red", Position = CFrame.new(-5414.92041015625, 314.2582092285156, -2212.20166015625) },
    { Name = "Winter Sky", Position = CFrame.new(-5420.26318359375, 1089.3582763671875, -2666.8193359375) }
}

-- Biến lưu trữ server trống đã quét sẵn
_G.NextServerId = nil
local countChests = 0
local bossSpawned = false

-- Hàm lấy động các Remote của game Blox Fruits để tránh bị treo script ngoài luồng chính
local function getCommF()
    local remotes = ReplicatedStorage:WaitForChild("Remotes", 5)
    return remotes and remotes:WaitForChild("CommF_", 5)
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

local function getFruitCustomizerRF()
    local modules = ReplicatedStorage:WaitForChild("Modules", 5)
    local net = modules and modules:WaitForChild("Net", 5)
    return net and net:WaitForChild("RF/FruitCustomizerRF", 5)
end

-- Hàm phát hiện Sea hiện tại của người chơi
local function GetCurrentSea()
    local placeId = game.PlaceId
    if placeId == 7447738386 then
        return 3
    elseif placeId == 4442272182 then
        return 2
    else
        return 1
    end
end

-- Hàm tự động chọn phe Pirates
local function selectTeam()
    local teamName = "Pirates"
    print("Đang tự động chọn phe: " .. teamName)
    pcall(function()
        local CommF = getCommF()
        if CommF then
            CommF:InvokeServer("SetTeam", teamName)
        end
    end)
    -- Fallback click GUI nếu Remote bị chặn
    pcall(function()
        local playerGui = LocalPlayer:WaitForChild("PlayerGui", 5)
        local mainGui = playerGui and playerGui:WaitForChild("Main", 3)
        local chooseTeam = mainGui and mainGui:WaitForChild("ChooseTeam", 3)
        local container = chooseTeam and chooseTeam:WaitForChild("Container", 2)
        local button = container and container:WaitForChild(teamName, 2)
            and container[teamName]:WaitForChild("Frame", 1)
            and container[teamName].Frame:WaitForChild("ViewportFrame", 1)
            and container[teamName].Frame.ViewportFrame:WaitForChild("TextButton", 1)
            
        if button then
            if getconnections then
                for _, conn in pairs(getconnections(button.MouseButton1Click)) do conn.Function() end
            elseif firesignal then
                firesignal(button.MouseButton1Click)
            end
        end
    end)
end

-- Hàm bay đến đích (Noclip xuyên tường, không dùng Reset TP, tránh kẹt luồng chính)
local function bayDen(targetCFrame, speed)
    local character = LocalPlayer.Character
    if not character then
        pcall(function()
            character = LocalPlayer.CharacterAdded:Wait()
        end)
    end
    if not character then return end
    
    local hrp = character:WaitForChild("HumanoidRootPart", 10)
    if not hrp then return end
    
    local distance = (targetCFrame.Position - hrp.Position).Magnitude
    
    if distance > 100 then
        local duration = distance / speed
        local tweenInfo = TweenInfo.new(duration, Enum.EasingStyle.Linear)
        local tween = TweenService:Create(hrp, tweenInfo, {CFrame = targetCFrame})
        
        local noclipConnection
        noclipConnection = RunService.Stepped:Connect(function()
            if LocalPlayer.Character then
                for _, part in ipairs(LocalPlayer.Character:GetDescendants()) do
                    if part:IsA("BasePart") then part.CanCollide = false end
                end
            end
        end)
        
        tween:Play()
        tween.Completed:Wait()
        if noclipConnection then noclipConnection:Disconnect() end
    else
        hrp.CFrame = targetCFrame
    end
end

-- Hàm kiểm tra an toàn vật phẩm hiếm (Chén Thánh hoặc Fist of Darkness) trong Balo hoặc trên tay
local function checkRareItems()
    local hasItem = false
    pcall(function()
        local backpack = LocalPlayer:FindFirstChild("Backpack")
        local character = LocalPlayer.Character
        
        if backpack and (backpack:FindFirstChild("God's Chalice") or backpack:FindFirstChild("Fist of Darkness")) then
            hasItem = true
        elseif character and (character:FindFirstChild("God's Chalice") or character:FindFirstChild("Fist of Darkness")) then
            hasItem = true
        end
    end)
    return hasItem
end

-- Hàm tự trang bị vật phẩm hiếm lên tay
local function equipRareItem(itemName)
    local character = LocalPlayer.Character
    if not character or not character:FindFirstChild("Humanoid") then return end
    
    local backpack = LocalPlayer:FindFirstChild("Backpack")
    local item = backpack and backpack:FindFirstChild(itemName)
    if item then
        character.Humanoid:EquipTool(item)
    end
end

-- Tự động bật Haki vũ trang (Buso)
local function KichHoatHaki()
    local character = LocalPlayer.Character
    if character and not character:FindFirstChild("HasBuso") then
        pcall(function()
            local CommF = getCommF()
            if CommF then CommF:InvokeServer("Buso") end
        end)
    end
end

-- Tự động trang bị vũ khí cận chiến/kiếm
local function TrangBiVuKhi()
    local character = LocalPlayer.Character
    if not character or not character:FindFirstChild("Humanoid") then return end
    
    for _, tool in ipairs(character:GetChildren()) do
        if tool:IsA("Tool") and (tool.ToolTip == "Melee" or tool.ToolTip == "Sword") then return tool end
    end
    for _, tool in ipairs(LocalPlayer.Backpack:GetChildren()) do
        if tool:IsA("Tool") and (tool.ToolTip == "Melee" or tool.ToolTip == "Sword") then
            character.Humanoid:EquipTool(tool)
            return tool
        end
    end
end

-- Lấy hàm hit gốc của game
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
-- QUY TRÌNH HỌP SERVER SONG SONG (TỐI ƯU HÓA THỜI GIAN ĐỔI SERVER)
-- =========================================================================

-- Hàm đổi server quét nhanh (Fallback khi chưa có server quét ngầm sẵn)
local function hopLowServerFast()
    local CurrentPlaceId = game.PlaceId
    local apiUrl = "https://games.roblox.com/v1/games/" .. CurrentPlaceId .. "/servers/Public?sortOrder=Desc&excludeFullGames=true&limit=100"
    
    local function ListServers(cursor)
        local success, raw = pcall(function() return game:HttpGet(apiUrl .. ((cursor and "&cursor=" .. cursor) or "")) end)
        return success and HttpService:JSONDecode(raw) or nil
    end
    
    local Server, Next
    local pageAttempts = 0
    local maxPages = 5
    local candidateServers = {}
    
    pcall(function()
        repeat 
            local Servers = ListServers(Next)
            pageAttempts = pageAttempts + 1
            if Servers and Servers.data then
                for _, s in pairs(Servers.data) do
                    local playing = tonumber(s.playing)
                    local maxPlayers = tonumber(s.maxPlayers)
                    if s.id ~= game.JobId and playing and maxPlayers and playing < (maxPlayers - 1) and playing >= 1 then
                        table.insert(candidateServers, s)
                    end
                end
                Next = Servers.nextPageCursor
            else
                break
            end
            task.wait(0.05)
        until #candidateServers > 0 or not Next or pageAttempts >= maxPages
    end)
    
    if #candidateServers > 0 then
        table.sort(candidateServers, function(a, b) return tonumber(a.playing) < tonumber(b.playing) end)
        Server = candidateServers[1]
    end
    
    if Server then
        pcall(function() ReplicatedStorage:WaitForChild("__ServerBrowser", 5):InvokeServer("teleport", Server.id) end)
    end
end

-- Thực hiện Hop Server (Dùng server đã quét sẵn hoặc quét nhanh)
local function thucHienHopServer()
    if checkRareItems() then
        print("🚨 Phát hiện vật phẩm hiếm! Hủy chuyển server.")
        return
    end

    _G.AutoFarmChest = false
    print("🔄 Tiến hành chuyển server...")
    
    if _G.NextServerId then
        print("✈️ Dịch chuyển ngay lập tức đến Server đã quét sẵn: " .. _G.NextServerId)
        local teleportSuccess, teleportErr = pcall(function()
            return ReplicatedStorage:WaitForChild("__ServerBrowser", 5):InvokeServer("teleport", _G.NextServerId)
        end)
        if not teleportSuccess then
            pcall(function()
                TeleportService:TeleportToPlaceInstance(game.PlaceId, _G.NextServerId, LocalPlayer)
            end)
        end
    else
        print("⚠️ Chưa có server quét sẵn. Đang tìm nhanh...")
        hopLowServerFast()
    end
end

-- Luồng chạy ngầm liên tục quét tìm server vắng nhất có >= 1 người chơi
task.spawn(function()
    while true do
        if _G.NextServerId then
            task.wait(15) -- Cập nhật lại sau mỗi 15s để tránh server bị đầy
            _G.NextServerId = nil
        else
            task.wait(2)
        end
        
        -- Chỉ quét khi không cầm vật phẩm hiếm
        if not checkRareItems() then
            pcall(function()
                local CurrentPlaceId = game.PlaceId
                local apiUrl = "https://games.roblox.com/v1/games/" .. CurrentPlaceId .. "/servers/Public?sortOrder=Desc&excludeFullGames=true&limit=100"
                
                local function ListServers(cursor)
                    local success, raw = pcall(function() return game:HttpGet(apiUrl .. ((cursor and "&cursor=" .. cursor) or "")) end)
                    return success and HttpService:JSONDecode(raw) or nil
                end
                
                local Next
                local pageAttempts = 0
                local maxPages = 400 -- Quét tối đa 400 trang
                local candidateServers = {}
                
                repeat 
                    local Servers = ListServers(Next)
                    pageAttempts = pageAttempts + 1
                    if Servers and Servers.data then
                        for _, s in pairs(Servers.data) do
                            local playing = tonumber(s.playing)
                            local maxPlayers = tonumber(s.maxPlayers)
                            if s.id ~= game.JobId and playing and maxPlayers and playing < (maxPlayers - 1) and playing >= 1 then
                                table.insert(candidateServers, s)
                            end
                        end
                        Next = Servers.nextPageCursor
                    else
                        break
                    end
                    task.wait(0.01) -- Quét siêu tốc
                until not Next or pageAttempts >= maxPages
                
                if #candidateServers > 0 then
                    table.sort(candidateServers, function(a, b) return tonumber(a.playing) < tonumber(b.playing) end)
                    _G.NextServerId = candidateServers[1].id
                    print("📡 [Quét Server Ngầm] Đã lưu trữ sẵn Server vắng nhất: " .. candidateServers[1].playing .. " người chơi.")
                end
            end)
        end
    end
end)

-- =========================================================================
-- QUY TRÌNH TIÊU DIỆT BOSS RIP INDRA (SEA 3)
-- =========================================================================

-- Hàm đổi màu Haki
local function equipHakiColor(colorName)
    local FruitCustomizerRF = getFruitCustomizerRF()
    if FruitCustomizerRF then
        local args = { [1] = { ["StorageName"] = colorName, ["Type"] = "AuraSkin", ["Context"] = "Equip" } }
        pcall(function() FruitCustomizerRF:InvokeServer(unpack(args)) end)
    end
end

-- Kích hoạt 3 nút Haki
local function kichHoat3NutHaki()
    print("--- Đang kích hoạt 3 nút Haki pháo đài ---")
    for i, step in ipairs(HakiSteps) do
        print(string.format("Đổi màu: %s", step.Name))
        equipHakiColor(step.Name)
        task.wait(0.2)
        bayDen(step.Position, TravelSpeed)
        task.wait(1)
    end
end

-- Tìm boss Rip Indra
local function GetRipIndra()
    local enemies = workspace:FindFirstChild("Enemies")
    if enemies then
        for _, enemy in ipairs(enemies:GetChildren()) do
            if string.find(enemy.Name, "rip_indra") and enemy:FindFirstChild("Humanoid") and enemy.Humanoid.Health > 0 then
                return enemy, "Workspace"
            end
        end
    end
    for _, obj in ipairs(ReplicatedStorage:GetChildren()) do
        if string.find(obj.Name, "rip_indra") and obj:FindFirstChild("Humanoid") then
            return obj, "ReplicatedStorage"
        end
    end
    return nil, nil
end

-- Vòng lặp chính diệt Rip Indra
local function startAutoKillRipIndra()
    _G.AutoKillBoss = true
    bossSpawned = false
    local hitFunction = LayHamHitGoc()
    local RegisterAttack = getRegisterAttack()
    local RegisterHit = getRegisterHit()
    
    local globalNoclip
    globalNoclip = RunService.Stepped:Connect(function()
        if _G.AutoKillBoss then
            local boss, location = GetRipIndra()
            if boss and location == "Workspace" then
                local character = LocalPlayer.Character
                if character then
                    for _, part in ipairs(character:GetDescendants()) do
                        if part:IsA("BasePart") then part.CanCollide = false end
                    end
                end
            end
        else
            globalNoclip:Disconnect()
        end
    end)
    
    task.spawn(function()
        print("========== BẮT ĐẦU DIỆT RIP INDRA ==========")
        while _G.AutoKillBoss do
            task.wait()
            local success, err = pcall(function()
                local boss, location = GetRipIndra()
                if boss then
                    if location == "ReplicatedStorage" then
                        local targetPos = boss:FindFirstChild("HumanoidRootPart") and boss.HumanoidRootPart.CFrame or CFrame.new(-5354.76, 423.85, -2701.32)
                        bayDen(targetPos, TravelSpeed)
                    elseif location == "Workspace" then
                        bossSpawned = true
                        local hrp = boss:FindFirstChild("HumanoidRootPart")
                        local humanoid = boss:FindFirstChild("Humanoid")
                        
                        if hrp and humanoid and humanoid.Health > 0 then
                            KichHoatHaki()
                            local weapon = TrangBiVuKhi()
                            
                            local animator = humanoid:FindFirstChild("Animator")
                            if animator then animator:Destroy() end
                            
                            local targetPos = hrp.CFrame * CFrame.new(0, 12, 0)
                            bayDen(targetPos, TravelSpeed)
                            
                            if weapon then
                                local targetPart = boss:FindFirstChild("Head") or hrp
                                local targetsList = {{boss, targetPart}}
                                if RegisterAttack then RegisterAttack:FireServer(0) end
                                if hitFunction then
                                    pcall(function() hitFunction(targetPart, targetsList) end)
                                else
                                    if RegisterHit then RegisterHit:FireServer(targetPart, targetsList) end
                                end
                                pcall(function() VirtualUser:Button1Down(Vector2.new(1280, 720)) end)
                            end
                        end
                    end
                else
                    if bossSpawned then
                        print("🎉 Rip Indra đã chết! Chu kỳ hoàn thành, đổi server...")
                        _G.AutoKillBoss = false
                        globalNoclip:Disconnect()
                        task.wait(1.5)
                        thucHienHopServer()
                        break
                    else
                        task.wait(1)
                    end
                end
            end)
            if not success then warn("Lỗi vòng lặp diệt Indra: " .. tostring(err)) end
        end
    end)
end

-- =========================================================================
-- QUY TRÌNH TRIỆU HỒI & TIÊU DIỆT BOSS DARKBEARD (SEA 2)
-- =========================================================================

-- Tìm boss Darkbeard
local function GetDarkbeard()
    local enemies = workspace:FindFirstChild("Enemies")
    if enemies then
        for _, enemy in ipairs(enemies:GetChildren()) do
            if string.find(enemy.Name, "Darkbeard") and enemy:FindFirstChild("Humanoid") and enemy.Humanoid.Health > 0 then
                return enemy, "Workspace"
            end
        end
    end
    for _, obj in ipairs(ReplicatedStorage:GetChildren()) do
        if string.find(obj.Name, "Darkbeard") and obj:FindFirstChild("Humanoid") then
            return obj, "ReplicatedStorage"
        end
    end
    return nil, nil
end

-- Triệu hồi Darkbeard
local function trieuHoiDarkbeard()
    local summonerPart = workspace:WaitForChild("Map", 5)
        and workspace.Map:WaitForChild("DarkbeardArena", 5)
        and workspace.Map.DarkbeardArena:WaitForChild("Summoner", 5)
        and workspace.Map.DarkbeardArena.Summoner:WaitForChild("Detection", 5)
        
    if summonerPart then
        print("Đang bay đến bệ triệu hồi Darkbeard...")
        bayDen(summonerPart.CFrame, TravelSpeed)
        task.wait(0.5)
        
        equipRareItem("Fist of Darkness")
        task.wait(0.5)
        
        -- Kích hoạt chạm bệ triệu hồi
        pcall(function()
            local char = LocalPlayer.Character
            if char and char:FindFirstChild("Fist of Darkness") then
                firetouchinterest(char["Fist of Darkness"].Handle, summonerPart, 0)
                firetouchinterest(char["Fist of Darkness"].Handle, summonerPart, 1)
                firetouchinterest(char.HumanoidRootPart, summonerPart, 0)
                firetouchinterest(char.HumanoidRootPart, summonerPart, 1)
            end
        end)
        
        print("Đã chạm bệ. Chờ boss spawn...")
        task.wait(3)
    else
        warn("Không tìm thấy bệ triệu hồi Darkbeard Arena! Đang bay đến đảo Dark Arena mặc định...")
        bayDen(CFrame.new(3780.03, 22.65, -3498.58), TravelSpeed)
        task.wait(2)
    end
end

-- Vòng lặp chính diệt Darkbeard
local function startAutoKillDarkbeard()
    _G.AutoKillBoss = true
    bossSpawned = false
    local hitFunction = LayHamHitGoc()
    local RegisterAttack = getRegisterAttack()
    local RegisterHit = getRegisterHit()
    
    local globalNoclip
    globalNoclip = RunService.Stepped:Connect(function()
        if _G.AutoKillBoss then
            local boss, location = GetDarkbeard()
            if boss and location == "Workspace" then
                local character = LocalPlayer.Character
                if character then
                    for _, part in ipairs(character:GetDescendants()) do
                        if part:IsA("BasePart") then part.CanCollide = false end
                    end
                end
            end
        else
            globalNoclip:Disconnect()
        end
    end)
    
    task.spawn(function()
        print("========== BẮT ĐẦU DIỆT DARKBEARD ==========")
        while _G.AutoKillBoss do
            task.wait()
            local success, err = pcall(function()
                local boss, location = GetDarkbeard()
                if boss then
                    if location == "ReplicatedStorage" then
                        local targetPos = boss:FindFirstChild("HumanoidRootPart") and boss.HumanoidRootPart.CFrame or CFrame.new(3780.03, 22.65, -3498.58)
                        bayDen(targetPos, TravelSpeed)
                    elseif location == "Workspace" then
                        bossSpawned = true
                        local hrp = boss:FindFirstChild("HumanoidRootPart")
                        local humanoid = boss:FindFirstChild("Humanoid")
                        
                        if hrp and humanoid and humanoid.Health > 0 then
                            KichHoatHaki()
                            local weapon = TrangBiVuKhi()
                            
                            local animator = humanoid:FindFirstChild("Animator")
                            if animator then animator:Destroy() end
                            
                            local targetPos = hrp.CFrame * CFrame.new(0, 12, 0)
                            bayDen(targetPos, TravelSpeed)
                            
                            if weapon then
                                local targetPart = boss:FindFirstChild("Head") or hrp
                                local targetsList = {{boss, targetPart}}
                                if RegisterAttack then RegisterAttack:FireServer(0) end
                                if hitFunction then
                                    pcall(function() hitFunction(targetPart, targetsList) end)
                                else
                                    if RegisterHit then RegisterHit:FireServer(targetPart, targetsList) end
                                end
                                pcall(function() VirtualUser:Button1Down(Vector2.new(1280, 720)) end)
                            end
                        end
                    end
                else
                    if bossSpawned then
                        print("🎉 Darkbeard đã chết! Chu kỳ hoàn thành, đổi server...")
                        _G.AutoKillBoss = false
                        globalNoclip:Disconnect()
                        task.wait(1.5)
                        thucHienHopServer()
                        break
                    else
                        task.wait(1)
                    end
                end
            end)
            if not success then warn("Lỗi vòng lặp diệt Darkbeard: " .. tostring(err)) end
        end
    end)
end

-- =========================================================================
-- VÒNG LẶP CHÍNH FARM RƯƠNG & KHỞI ĐỘNG SỰ KIỆN BOSS
-- =========================================================================

-- Hàm lấy rương gần nhất
local function getNearestChest()
    local character = LocalPlayer.Character
    if not character or not character:FindFirstChild("HumanoidRootPart") then return nil end
    local myPos = character.HumanoidRootPart.Position
    
    local chests = CollectionService:GetTagged("_ChestTagged")
    local nearestChest = nil
    local shortestDistance = math.huge
    
    for _, chest in ipairs(chests) do
        if chest:IsA("BasePart") or chest:IsA("Model") then
            if not chest:GetAttribute("IsDisabled") then
                local chestPos = chest:GetPivot().Position
                local dist = (chestPos - myPos).Magnitude
                if dist < shortestDistance then
                    shortestDistance = dist
                    nearestChest = chest
                end
            end
        end
    end
    
    return nearestChest
end

task.spawn(function()
    task.wait(2)
    selectTeam()
    task.wait(2)
    
    print("========== AUTO FARM CHEST & BOSS KHỞI CHẠY ==========")
    local Sea = GetCurrentSea()
    print("🌊 Bạn đang ở Sea " .. Sea)
    
    local globalNoclip
    globalNoclip = RunService.Stepped:Connect(function()
        if _G.AutoFarmChest then
            local character = LocalPlayer.Character
            if character then
                for _, part in ipairs(character:GetDescendants()) do
                    if part:IsA("BasePart") then part.CanCollide = false end
                end
            end
        else
            globalNoclip:Disconnect()
        end
    end)
    
    while _G.AutoFarmChest do
        task.wait()
        
        -- KIỂM TRA PHÁT HIỆN VẬT PHẨM HIẾM ĐỂ KHỞI CHẠY BOSS EVENT
        local hasRareItem = checkRareItems()
        if hasRareItem then
            print("🎁 PHÁT HIỆN VẬT PHẨM SỰ KIỆN! DỪNG AUTO FARM RƯƠNG ĐỂ TRIỆU HỒI BOSS...")
            _G.AutoFarmChest = false
            globalNoclip:Disconnect()
            
            if Sea == 3 then
                -- Quy trình Sea 3 (Chén Thánh -> Rip Indra)
                kichHoat3NutHaki()
                task.wait(1)
                equipRareItem("God's Chalice")
                task.wait(0.5)
                print("Bay đến bệ triệu hồi Rip Indra...")
                bayDen(IndraSummonCFrame, TravelSpeed)
                task.wait(2)
                startAutoKillRipIndra()
            elseif Sea == 2 then
                -- Quy trình Sea 2 (Fist of Darkness -> Darkbeard)
                trieuHoiDarkbeard()
                startAutoKillDarkbeard()
            else
                warn("Vật phẩm không được hỗ trợ ở Sea 1!")
            end
            break -- Thoát hẳn vòng lặp farm rương
        end
        
        -- NHẶT RƯƠNG BÌNH THƯỜNG
        local targetChest = getNearestChest()
        if targetChest then
            local chestPos = targetChest:GetPivot().Position
            bayDen(CFrame.new(chestPos), FarmSpeed)
            
            pcall(function()
                local character = LocalPlayer.Character
                if character and character:FindFirstChild("Humanoid") then
                    character.Humanoid.Jump = true
                end
            end)
            
            local waitTime = 0
            while not targetChest:GetAttribute("IsDisabled") and targetChest.Parent ~= nil and waitTime < 0.4 do
                task.wait(0.05)
                waitTime = waitTime + 0.05
            end
            
            countChests = countChests + 1
            print(string.format("🎒 Đã nhặt rương (%d/%d)", countChests, ChestTargetLimit))
            
            if countChests >= ChestTargetLimit then
                print("🎉 Đã nhặt đủ 70 rương! Đang chuyển server vắng đã tìm sẵn...")
                globalNoclip:Disconnect()
                thucHienHopServer()
                break
            end
        else
            print("⚠️ Hết rương trên server! Đang chuyển server vắng đã tìm sẵn...")
            globalNoclip:Disconnect()
            thucHienHopServer()
            break
        end
    end
end)
