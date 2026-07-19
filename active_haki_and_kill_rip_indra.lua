-- Script tổng hợp: Tự động giám sát Chén Thánh (God's Chalice) -> Kích hoạt 3 màu Haki -> Triệu hồi -> Tiêu diệt Rip Indra -> Đổi Server (Hop Server)
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local VirtualUser = game:GetService("VirtualUser")
local TeleportService = game:GetService("TeleportService")
local HttpService = game:GetService("HttpService")

local LocalPlayer = Players.LocalPlayer

-- Các Remote của game Blox Fruits
local CommF = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("CommF_")
local RegisterAttack = ReplicatedStorage:WaitForChild("Modules"):WaitForChild("Net"):WaitForChild("RE/RegisterAttack")
local RegisterHit = ReplicatedStorage:WaitForChild("Modules"):WaitForChild("Net"):WaitForChild("RE/RegisterHit")
local FruitCustomizerRF = ReplicatedStorage:WaitForChild("Modules"):WaitForChild("Net"):WaitForChild("RF/FruitCustomizerRF")

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

-- Hàm bay đến đích với tốc độ 300 kèm Noclip xuyên tường
local function bayDen(targetCFrame, speed)
    local character = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
    local hrp = character:WaitForChild("HumanoidRootPart")
    
    local distance = (targetCFrame.Position - hrp.Position).Magnitude
    
    if distance > 150 then
        -- Bay mượt bằng Tween nếu ở xa để tránh bị kick anti-cheat
        local duration = distance / speed
        local tweenInfo = TweenInfo.new(duration, Enum.EasingStyle.Linear)
        local tween = TweenService:Create(hrp, tweenInfo, {CFrame = targetCFrame})
        
        -- Bật Noclip khi bay để không bị kẹt địa hình
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
        -- Bám sát trực tiếp nếu ở khoảng cách gần (< 150 studs)
        hrp.CFrame = targetCFrame
    end
end

-- Hàm đổi màu Haki
local function equipHakiColor(colorName)
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

-- Hàm chuyển Server thông minh (Hop Server)
local function hopServer()
    print("🔄 Đang quét danh sách Server công khai để chuyển Server...")
    local PlaceID = game.PlaceId
    
    local function teleportRandomServer()
        local success, result = pcall(function()
            -- Gọi API Roblox lấy danh sách server
            local url = "https://games.roblox.com/v1/games/" .. PlaceID .. "/servers/Public?sortOrder=Asc&limit=100"
            local servers = HttpService:JSONDecode(game:HttpGet(url))
            local candidateServers = {}
            
            for _, sv in ipairs(servers.data) do
                if tonumber(sv.playing) < tonumber(sv.maxPlayers) and sv.id ~= game.JobId then
                    table.insert(candidateServers, sv.id)
                end
            end
            
            if #candidateServers > 0 then
                local randomServerId = candidateServers[math.random(1, #candidateServers)]
                print("Dịch chuyển đến Server ID: " .. randomServerId)
                TeleportService:TeleportToPlaceInstance(PlaceID, randomServerId, LocalPlayer)
            else
                print("Không tìm thấy server trống, thực hiện Teleport mặc định...")
                TeleportService:Teleport(PlaceID, LocalPlayer)
            end
        end)
        
        if not success then
            warn("Lỗi khi tìm server: " .. tostring(result) .. ". Đang fallback teleport mặc định...")
            TeleportService:Teleport(PlaceID, LocalPlayer)
        end
    end

    -- Đổi server
    while task.wait(2) do
        teleportRandomServer()
    end
end

-- Bắt đầu vòng lặp tiêu diệt Rip Indra
local function startAutoKillRipIndra()
    _G.AutoKillRipIndra = true
    bossSpawned = false -- Reset trạng thái xác nhận boss spawn
    local hitFunction = LayHamHitGoc()
    
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
                    -- Không tìm thấy boss
                    -- Nếu trước đó boss đã spawn thực tế và bây giờ biến mất -> Xác nhận boss ĐÃ BỊ TIÊU DIỆT
                    if bossSpawned then
                        print("🎉 Boss Rip Indra đã bị tiêu diệt hoàn toàn! Chuẩn bị chuyển Server... 🎉")
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
