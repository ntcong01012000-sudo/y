-- script tự động lượm rương trong blox fruit
-- lượm tối đa 70 rương, nếu có chén thánh hay key râu đen thì tự dừng lại
-- hopserver sau khi nhạt 70 rương
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local TeleportService = game:GetService("TeleportService")
local HttpService = game:GetService("HttpService")

local LocalPlayer = Players.LocalPlayer

-- Cấu hình
_G.AutoFarmChest = true -- Chuyển thành false để dừng script
local ChestTargetLimit = 70 -- Số lượng rương cần nhặt trước khi đổi server
local FarmSpeed = 350 -- Tốc độ bay đi nhặt rương

local countChests = 0
local CommF = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("CommF_")

-- Biến lưu trữ server trống đã quét sẵn
_G.NextServerId = nil

-- Hàm tự động chọn phe (mặc định chọn phe Pirates để vào game)
local function selectTeam()
    local teamName = "Pirates"
    print("Đang tự động chọn phe: " .. teamName)
    
    -- 1. Thử gọi Remote SetTeam trước
    local success, result = pcall(function()
        local Remotes = ReplicatedStorage:WaitForChild("Remotes", 5)
        local CommF = Remotes and Remotes:WaitForChild("CommF_", 5)
        if CommF then
            CommF:InvokeServer("SetTeam", teamName)
        else
            error("CommF_ not found")
        end
    end)
    
    if success then
        print("Đã chọn Phe qua Remote thành công!")
        return
    end
    
    -- 2. Fallback: Click nút GUI trong game nếu Remote bị lỗi/chặn
    pcall(function()
        local playerGui = LocalPlayer:WaitForChild("PlayerGui", 5)
        local mainGui = playerGui:WaitForChild("Main", 3)
        local chooseTeam = mainGui:WaitForChild("ChooseTeam", 3)
        local container = chooseTeam:WaitForChild("Container", 2)
        local button = container:WaitForChild(teamName, 2)
            :WaitForChild("Frame", 1)
            :WaitForChild("ViewportFrame", 1)
            :WaitForChild("TextButton", 1)
            
        if button then
            local clicked = false
            if getconnections then
                for _, conn in pairs(getconnections(button.MouseButton1Click)) do
                    conn.Function()
                    clicked = true
                end
            end
            if not clicked and firesignal then
                firesignal(button.MouseButton1Click)
                clicked = true
            end
            if clicked then
                print("Đã click nút chọn Phe (" .. teamName .. ") qua GUI Fallback!")
            end
        end
    end)
end

-- Hàm bay đến tọa độ chỉ định với Noclip xuyên tường toàn diện (Không dùng Reset TP)
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
        -- Bay mượt bằng Tween khi ở xa để tránh bị kick anti-cheat
        local duration = distance / speed
        local tweenInfo = TweenInfo.new(duration, Enum.EasingStyle.Linear)
        local tween = TweenService:Create(hrp, tweenInfo, {CFrame = targetCFrame})
        
        -- Kích hoạt Noclip đi xuyên tường trong lúc bay
        local noclipConnection
        noclipConnection = RunService.Stepped:Connect(function()
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
        
        if noclipConnection then
            noclipConnection:Disconnect()
        end
    else
        -- Teleport trực tiếp nếu khoảng cách quá gần
        hrp.CFrame = targetCFrame
    end
end

-- Hàm tìm rương gần nhất chưa bị nhặt (chưa disabled)
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

-- =========================================================================
-- QUY TRÌNH HỌP SERVER SONG SONG (TỐI ƯU HÓA THỜI GIAN ĐỔI SERVER)
-- =========================================================================

-- Hàm quét tìm server trống khẩn cấp (Fallback nếu chưa quét ngầm xong)
local function hopLowServerFast()
    local CurrentPlaceId = game.PlaceId
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
        table.sort(candidateServers, function(a, b)
            return tonumber(a.playing) < tonumber(b.playing)
        end)
        Server = candidateServers[1]
    end
    
    if Server then
        pcall(function()
            ReplicatedStorage:WaitForChild("__ServerBrowser", 5):InvokeServer("teleport", Server.id)
        end)
    end
end

-- Thực hiện Hop Server (Dùng server đã quét ngầm hoặc quét khẩn cấp)
local function thucHienHopServer()
    -- BẢO VỆ TUYỆT ĐỐI: Nếu có chén thánh hoặc fist of darkness thì KHÔNG đổi server
    if checkRareItems() then
        print("🚨 Phát hiện vật phẩm hiếm (God's Chalice / Fist of Darkness)! Hủy lệnh chuyển Server để bảo toàn vật phẩm.")
        return
    end

    _G.AutoFarmChest = false
    print("🔄 Bắt đầu chuyển Server...")
    
    if _G.NextServerId then
        print("✈️ Dịch chuyển ngay lập tức đến Server đã quét sẵn: " .. _G.NextServerId)
        local teleportSuccess, teleportErr = pcall(function()
            return ReplicatedStorage:WaitForChild("__ServerBrowser", 5):InvokeServer("teleport", _G.NextServerId)
        end)
        
        if not teleportSuccess then
            warn("⚠️ Dịch chuyển qua __ServerBrowser thất bại: " .. tostring(teleportErr))
            print("🔄 Đang thử cách dịch chuyển dự phòng thủ công (Fallback)...")
            pcall(function()
                TeleportService:TeleportToPlaceInstance(game.PlaceId, _G.NextServerId, LocalPlayer)
            end)
        end
    else
        print("⚠️ Chưa có server quét sẵn trong bộ nhớ. Đang tìm nhanh...")
        hopLowServerFast()
    end
end

-- Luồng chạy ngầm liên tục quét tìm server vắng nhất có >= 1 người chơi (Quét diện rộng 400 trang)
task.spawn(function()
    while true do
        if _G.NextServerId then
            task.wait(15) -- Sau 15s reset để quét lại, đảm bảo server đó không bị đầy người
            _G.NextServerId = nil
        else
            task.wait(2)
        end
        
        -- Chỉ quét khi balo/character không có vật phẩm hiếm
        if not checkRareItems() then
            pcall(function()
                local CurrentPlaceId = game.PlaceId
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
                local maxPages = 400 -- Cấu hình quét tối đa 400 trang
                local candidateServers = {}
                
                repeat 
                    local Servers = ListServers(Next)
                    pageAttempts = pageAttempts + 1
                    
                    if Servers and Servers.data then
                        for _, server in pairs(Servers.data) do
                            local playing = tonumber(server.playing)
                            local maxPlayers = tonumber(server.maxPlayers)
                            
                            -- LỌC CHỌN SERVER ÍT NGƯỜI NHẤT BẮT ĐẦU TỪ 1 NGƯỜI:
                            if server.id ~= game.JobId and playing and maxPlayers
                               and playing < (maxPlayers - 1) and playing >= 1 then
                                table.insert(candidateServers, server)
                            end
                        end
                        Next = Servers.nextPageCursor
                    else
                        break
                    end
                    task.wait(0.01) -- Trễ siêu nhỏ để quét cực nhanh
                until not Next or pageAttempts >= maxPages
                
                if #candidateServers > 0 then
                    -- Sắp xếp tăng dần theo số lượng người chơi
                    table.sort(candidateServers, function(a, b)
                        return tonumber(a.playing) < tonumber(b.playing)
                    end)
                    _G.NextServerId = candidateServers[1].id
                    print("📡 [Quét Server Ngầm] Đã lưu trữ sẵn Server vắng nhất: " .. candidateServers[1].playing .. " người chơi.")
                end
            end)
        end
    end
end)

-- =========================================================================
-- VÒNG LẶP CHÍNH FARM RƯƠNG
-- =========================================================================
task.spawn(function()
    -- Thực hiện chọn team trước khi bắt đầu
    task.wait(2)
    selectTeam()
    task.wait(2)
    
    print("========== SCRIPT AUTO FARM CHEST ĐÃ KHỞI CHẠY ==========")
    
    -- Kích hoạt Noclip liên tục trong toàn bộ chu kỳ farm
    local globalNoclip
    globalNoclip = RunService.Stepped:Connect(function()
        if _G.AutoFarmChest then
            local character = LocalPlayer.Character
            if character then
                for _, part in ipairs(character:GetDescendants()) do
                    if part:IsA("BasePart") then
                        part.CanCollide = false
                    end
                end
            end
        else
            globalNoclip:Disconnect()
        end
    end)
    
    while _G.AutoFarmChest do
        task.wait()
        
        -- KIỂM TRA VẬT PHẨM HIẾM: Dừng ngay lập tức nếu nhặt được Chén Thánh hoặc Fist of Darkness
        if checkRareItems() then
            print("🎁 PHÁT HIỆN VẬT PHẨM HIẾM (God's Chalice / Fist of Darkness) TRONG BALO! DỪNG AUTO NHẶT RƯƠNG VÀ KHÔNG HOP SERVER! 🎁")
            _G.AutoFarmChest = false
            globalNoclip:Disconnect()
            break
        end
        
        local targetChest = getNearestChest()
        
        if targetChest then
            local chestPos = targetChest:GetPivot().Position
            
            -- Bay đến rương
            bayDen(CFrame.new(chestPos), FarmSpeed)
            
            -- Thực hiện nhảy 1 lần ngay sau khi chạm rương
            pcall(function()
                local character = LocalPlayer.Character
                if character and character:FindFirstChild("Humanoid") then
                    character.Humanoid.Jump = true
                end
            end)
            
            -- Đợi rương được nhặt (tối đa 0.4s để tránh kẹt nếu rương bị lỗi)
            local waitTime = 0
            while not targetChest:GetAttribute("IsDisabled") and targetChest.Parent ~= nil and waitTime < 0.4 do
                task.wait(0.05)
                waitTime = waitTime + 0.05
            end
            
            -- Tăng biến đếm và in thông báo
            countChests = countChests + 1
            print(string.format("🎒 Đã nhặt rương (%d/%d)", countChests, ChestTargetLimit))
            
            -- Kiểm tra nếu đạt giới hạn rương đã nhặt
            if countChests >= ChestTargetLimit then
                print("🎉 Đã nhặt đủ 70 rương! Đang tiến hành đổi sang server vắng đã quét sẵn...")
                globalNoclip:Disconnect()
                thucHienHopServer()
                break
            end
        else
            -- Nếu không còn rương nào trên server, tự động đổi server luôn để tránh mất thời gian
            print("⚠️ Không tìm thấy rương nào khác trên server này! Đang đổi server...")
            globalNoclip:Disconnect()
            thucHienHopServer()
            break
        end
    end
end)
