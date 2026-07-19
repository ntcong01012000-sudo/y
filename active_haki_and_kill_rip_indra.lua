-- Script tổng hợp: Tự động giám sát Chén Thánh (God's Chalice) -> Kích hoạt 3 màu Haki -> Triệu hồi -> Tiêu diệt Rip Indra -> Đổi Server (Hop Server)
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local VirtualUser = game:GetService("VirtualUser")
local TeleportService = game:GetService("TeleportService")
local HttpService = game:GetService("HttpService")

local LocalPlayer = Players.LocalPlayer

-- Cấu hình tọa độ bệ triệu hồi Rip Indra mới yêu cầu
local SummonCFrame = CFrame.new(-5564.36, 314.57, -2661.53)
local TravelSpeed = 300 -- Tốc độ bay (Speed: 300)

-- Cấu hình 3 màu Haki Legendary và tọa độ tương ứng của 3 nút
local HakiSteps = {
    {
        Name = "Snow White", -- Nút màu Trắng
        Position = CFrame.new(-4971.71826171875, 335.9582214355469, -3720.0595703125)
    },
    {
        Name = "Pure Red", -- Nút màu Đỏ
        Position = CFrame.new(-5414.92041015625, 314.2582092285156, -2212.20166015625)
    },
    {
        Name = "Winter Sky", -- Nút màu Hồng
        Position = CFrame.new(-5420.26318359375, 1089.3582763671875, -2666.8193359375)
    }
}

-- Trạng thái điều khiển Auto Kill Boss và trạng thái xác nhận boss đã spawn
_G.AutoKillRipIndra = false
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

-- Hàm tự động chọn phe Pirates để vào game tránh bị kẹt màn hình chọn đội
local function selectTeam()
    local teamName = "Pirates"
    print("Đang tự động chọn phe: " .. teamName)
    pcall(function()
        local CommF = getCommF()
        if CommF then
            CommF:InvokeServer("SetTeam", teamName)
        end
    end)
    -- Click GUI đệ quy an toàn
    pcall(function()
        local playerGui = LocalPlayer:FindFirstChildOfClass("PlayerGui")
        if playerGui then
            for _, v in ipairs(playerGui:GetDescendants()) do
                if v:IsA("TextButton") and (string.find(v.Name, teamName) or string.find(v.Text, teamName)) then
                    local clicked = false
                    if getconnections then
                        for _, conn in pairs(getconnections(v.MouseButton1Click)) do
                            conn.Function()
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

-- Hàm bay đến đích với tốc độ 300 kèm Noclip xuyên tường
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
    
    if distance > 150 then
        -- Bay mượt bằng Tween nếu ở xa để tránh bị kick anti-cheat
        local duration = distance / speed
        local tweenInfo = TweenInfo.new(duration, Enum.EasingStyle.Linear)
        local tween = TweenService:Create(hrp, tweenInfo, {CFrame = targetCFrame})
        
        -- Bật Noclip khi bay để không bị kẹt địa hình
        local noclip
        noclip = RunService.Stepped:Connect(function()
            if LocalPlayer.Character then
                for _, part in ipairs(LocalPlayer.Character:GetDescendants()) do
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
        -- Bám sát trực tiếp nếu ở khoảng cách gần (< 150 studs)
        hrp.CFrame = targetCFrame
    end
end

-- Hàm đổi màu Haki
local function equipHakiColor(colorName)
    local FruitCustomizerRF = getFruitCustomizerRF()
    if FruitCustomizerRF then
        local args = {
            [1] = {
                ["StorageName"] = colorName,
                ["Type"] = "AuraSkin",
                ["Context"] = "Equip"
            }
        }
        pcall(function()
            FruitCustomizerRF:InvokeServer(unpack(args))
        end)
    end
end

-- Hàm thực hiện kích hoạt tuần tự cả 3 nút Haki pháo đài
local function kichHoat3NutHaki()
    print("--- Khởi động quy trình kích hoạt 3 nút Haki pháo đài ---")
    for i, step in ipairs(HakiSteps) do
        print(string.format("Bước %d: Đổi Haki sang màu %s", i, step.Name))
        equipHakiColor(step.Name)
        task.wait(0.2)
        
        print(string.format("Bước %d: Bay đến nút %s...", i, step.Name))
        bayDen(step.Position, TravelSpeed)
        
        print(string.format("Bước %d: Đã đến nút %s. Đợi 1 giây...", i, step.Name))
        task.wait(1)
    end
    print("--- Kích hoạt thành công 3 nút Haki ---")
end

-- Hàm kiểm tra chén thánh (God's Chalice) trong Balo hoặc trên tay
local function checkGodChalice()
    local chalice = nil
    
    local backpack = LocalPlayer:FindFirstChild("Backpack")
    if backpack then
        chalice = backpack:FindFirstChild("God's Chalice")
    end
    
    if not chalice and LocalPlayer.Character then
        chalice = LocalPlayer.Character:FindFirstChild("God's Chalice")
    end
    
    return chalice
end

-- Hàm trang bị chén thánh lên tay
local function equipGodChalice()
    local character = LocalPlayer.Character
    if not character or not character:FindFirstChild("Humanoid") then return end
    
    local chalice = checkGodChalice()
    if chalice and chalice.Parent == LocalPlayer.Backpack then
        character.Humanoid:EquipTool(chalice)
    end
end

-- Hàm tìm kiếm Boss Rip Indra
local function GetRipIndra()
    -- 1. Tìm trong Workspace
    local enemies = workspace:FindFirstChild("Enemies")
    if enemies then
        for _, enemy in ipairs(enemies:GetChildren()) do
            if string.find(enemy.Name, "rip_indra") and enemy:FindFirstChild("Humanoid") and enemy.Humanoid.Health > 0 then
                return enemy, "Workspace"
            end
        end
    end
    
    -- 2. Tìm trong ReplicatedStorage
    for _, obj in ipairs(ReplicatedStorage:GetChildren()) do
        if string.find(obj.Name, "rip_indra") and obj:FindFirstChild("Humanoid") then
            return obj, "ReplicatedStorage"
        end
    end
    
    return nil, nil
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

-- Lấy hàm đăng ký đòn đánh gốc của game để tăng sát thương (nếu executor hỗ trợ)
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

-- Hàm đổi sang Server ít người chơi (Quét diện rộng 20 trang để tìm ra server vắng nhất có > 3 người và bypass lỗi 773)
local function hopServer()
    print("🔄 Bắt đầu quét diện rộng tìm kiếm Server ít người chơi nhất...")
    local CurrentPlaceId = game.PlaceId
    local Player = LocalPlayer
    
    while true do
        local apiUrl = "https://games.roblox.com/v1/games/" .. CurrentPlaceId .. "/servers/Public?sortOrder=Desc&excludeFullGames=true&limit=100"
        
        local function ListServers(cursor)
            local success, raw = pcall(function()
                return game:HttpGet(apiUrl .. ((cursor and "&cursor=" .. cursor) or ""))
            end)
            if success and raw then
                return HttpService:JSONDecode(raw)
            end
            return nil
        end
        
        local Next
        local pageAttempts = 0
        local maxPages = 20 -- Quét tối đa 20 trang để tìm server vắng nhất
        local candidateServers = {}
        
        pcall(function()
            repeat 
                local Servers = ListServers(Next)
                pageAttempts = pageAttempts + 1
                
                if Servers and Servers.data then
                    for _, server in pairs(Servers.data) do
                        local playing = tonumber(server.playing)
                        local maxPlayers = tonumber(server.maxPlayers)
                        
                        -- Lọc các server an toàn (> 3 người để tránh lỗi 773) và còn chỗ trống
                        if server.id ~= game.JobId and playing and maxPlayers
                           and playing < (maxPlayers - 1) and playing > 3 then
                            table.insert(candidateServers, server)
                        end
                    end
                    Next = Servers.nextPageCursor
                else
                    break
                end
                
                task.wait(0.1)
            until not Next or pageAttempts >= maxPages
        end)
        
        local Server = nil
        if #candidateServers > 0 then
            table.sort(candidateServers, function(a, b)
                return tonumber(a.playing) < tonumber(b.playing)
            end)
            Server = candidateServers[1]
        end
        
        if Server then
            print(string.format("🏆 Đã tìm thấy Server vắng: %d/%d người chơi. Đang dịch chuyển...", Server.playing, Server.maxPlayers))
            local teleportSuccess, teleportErr = pcall(function()
                return ReplicatedStorage:WaitForChild("__ServerBrowser", 5):InvokeServer("teleport", Server.id)
            end)
            
            if not teleportSuccess then
                warn("⚠️ Dịch chuyển qua __ServerBrowser thất bại: " .. tostring(teleportErr))
                print("🔄 Đang thử cách dịch chuyển dự phòng...")
                task.wait(2)
                pcall(function()
                    TeleportService:TeleportToPlaceInstance(CurrentPlaceId, Server.id, Player)
                end)
                task.wait(5)
            else
                task.wait(15)
            end
        else
            warn("⚠️ Không tìm thấy server trống hợp lệ. Quét lại sau 5 giây...")
            task.wait(5)
        end
    end
end

-- Bắt đầu vòng lặp tiêu diệt Rip Indra
local function startAutoKillRipIndra()
    _G.AutoKillRipIndra = true
    bossSpawned = false -- Reset trạng thái xác nhận boss spawn
    local hitFunction = LayHamHitGoc()
    local RegisterAttack = getRegisterAttack()
    local RegisterHit = getRegisterHit()
    
    -- Bật Noclip liên tục khi đang farm boss
    local globalNoclip
    globalNoclip = RunService.Stepped:Connect(function()
        if _G.AutoKillRipIndra then
            local boss, location = GetRipIndra()
            if boss and location == "Workspace" then
                local character = LocalPlayer.Character
                if character then
                    for _, part in ipairs(character:GetDescendants()) do
                        if part:IsA("BasePart") then
                            part.CanCollide = false
                        end
                    end
                end
            end
        else
            globalNoclip:Disconnect()
        end
    end)
    
    task.spawn(function()
        print("========== BẮT ĐẦU TIÊU DIỆT RIP INDRA ==========")
        while _G.AutoKillRipIndra do
            task.wait()
            
            local success, err = pcall(function()
                local boss, location = GetRipIndra()
                
                if boss then
                    if location == "ReplicatedStorage" then
                        -- Bay đến tọa độ boss để ép game load
                        local targetPos = boss:FindFirstChild("HumanoidRootPart") and boss.HumanoidRootPart.CFrame or CFrame.new(-5354.76, 423.85, -2701.32)
                        bayDen(targetPos, TravelSpeed)
                    elseif location == "Workspace" then
                        bossSpawned = true -- Xác nhận boss đã xuất hiện trong map thực tế
                        
                        local hrp = boss:FindFirstChild("HumanoidRootPart")
                        local humanoid = boss:FindFirstChild("Humanoid")
                        
                        if hrp and humanoid and humanoid.Health > 0 then
                            KichHoatHaki()
                            local weapon = TrangBiVuKhi()
                            
                            -- Xóa Animator để boss không đánh trả được và tránh lag
                            local animator = humanoid:FindFirstChild("Animator")
                            if animator then animator:Destroy() end
                            
                            -- Bám sát phía trên đầu boss 12 studs
                            local targetPos = hrp.CFrame * CFrame.new(0, 12, 0)
                            bayDen(targetPos, TravelSpeed)
                            
                            -- Gây sát thương liên tục
                            if weapon then
                                local targetPart = boss:FindFirstChild("Head") or hrp
                                local targetsList = {{boss, targetPart}}
                                
                                if RegisterAttack then RegisterAttack:FireServer(0) end
                                
                                if hitFunction then
                                    pcall(function()
                                        hitFunction(targetPart, targetsList)
                                    end)
                                else
                                    if RegisterHit then RegisterHit:FireServer(targetPart, targetsList) end
                                end
                                
                                pcall(function()
                                    VirtualUser:Button1Down(Vector2.new(1280, 720))
                                end)
                            end
                        end
                    end
                else
                    -- Không tìm thấy boss
                    -- Nếu trước đó boss đã spawn thực tế và bây giờ biến mất -> Xác nhận boss ĐÃ BỊ TIÊU DIỆT
                    if bossSpawned then
                        print("🎉 Boss Rip Indra đã bị tiêu diệt hoàn toàn! Chu chuẩn bị chuyển Server... 🎉")
                        _G.AutoKillRipIndra = false
                        globalNoclip:Disconnect()
                        task.wait(1.5)
                        hopServer()
                        break
                    else
                        -- Chờ boss spawn (nếu boss chưa từng load ra Workspace)
                        task.wait(1)
                    end
                end
            end)
            
            if not success then
                warn("Lỗi vòng lặp diệt boss: " .. tostring(err))
            end
        end
    end)
end

-- VÒNG LẶP CHÍNH: Giám sát God's Chalice mỗi 1 giây
task.spawn(function()
    task.wait(2)
    selectTeam() -- Tự chọn đội
    task.wait(2)
    
    print("========== SCRIPT GIÁM SÁT CHÉN THÁNH (GOD'S CHALICE) ĐÃ KHỞI CHẠY ==========")
    while true do
        task.wait(1)
        
        local chalice = checkGodChalice()
        if chalice then
            print("🔥 PHÁT HIỆN CHÉN THÁNH (GOD'S CHALICE) TRONG BALO! BẮT ĐẦU CHU TRÌNH... 🔥")
            
            -- Bước 1: Tự động chạy quy trình kích hoạt cả 3 nút Haki
            kichHoat3NutHaki()
            task.wait(1)
            
            -- Bước 2: Trang bị Chén Thánh lên tay và bay đến bệ triệu hồi với tọa độ mới
            print("Trang bị Chén Thánh...")
            equipGodChalice()
            task.wait(0.5)
            
            print("Bay đến bệ triệu hồi Rip Indra tại " .. tostring(SummonCFrame.Position) .. "...")
            bayDen(SummonCFrame, TravelSpeed)
            
            -- Đợi tại bệ triệu hồi
            print("Đã đến bệ triệu hồi. Đợi 2 giây để boss spawn...")
            task.wait(2)
            
            -- Bước 3: Tự động kích hoạt quy trình tiêu diệt Rip Indra
            startAutoKillRipIndra()
            
            -- Dừng vòng lặp giám sát balo sau khi đã khởi chạy quy trình thành công
            break
        end
    end
end)
