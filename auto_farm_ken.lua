--[[
    Blox Fruits - Auto Farm Observation Haki (Ken Haki / Instinct)
    Flow: Chọn Team → Đợi NV load → Tìm quái gần nhất với X Y Z → TP áp sát → Bật Ken (Remote + Phím E) 
          → Bám đuổi / Tìm quái mới liên tục đến khi né về 0 → Đổi Server.
--]]

-- Chờ game load xong hoàn toàn mới chạy script
if not game:IsLoaded() then
    game.Loaded:Wait()
end
task.wait(2) -- Đợi thêm 2 giây để chắc chắn các service và UI của game sẵn sàng

getgenv().AutoFarmKen = true
getgenv().Team = 1 -- Mặc định: 1 = Pirates (Hải tặc), 0 = Marines (Hải quân)
getgenv().TeamSelectDelay = 3

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Lighting = game:GetService("Lighting")
local TweenService = game:GetService("TweenService")
local TeleportService = game:GetService("TeleportService")
local RunService = game:GetService("RunService")
local HttpService = game:GetService("HttpService")
local VirtualInputManager = game:GetService("VirtualInputManager")

local plr = Players.LocalPlayer
_G.Clip = true

local function log(message)
    print(message)
    if rconsoleprint then
        rconsoleprint(message .. "\n")
    end
end

-- 1. Tự động kết nối lại khi bị Kick hoặc Mất mạng (Anti-Kick / Auto Rejoin)
task.spawn(function()
    local success, err = pcall(function()
        game:GetService("CoreGui").RobloxPromptGui.promptOverlay.ChildAdded:Connect(function(child)
            if child.Name == "ErrorPrompt" then
                log("⚠️ Phát hiện bị Kick hoặc Mất kết nối! Đang kết nối lại...")
                task.wait(2)
                pcall(function()
                    local queueteleport = (syn and syn.queue_on_teleport)
                        or queue_on_teleport
                        or (fluxus and fluxus.queue_on_teleport)
                    if queueteleport then
                        queueteleport('loadstring(readfile("auto_farm_ken.lua"))()')
                        log("[Anti-Kick] Đã xếp hàng chạy lại script.")
                    end
                end)
                pcall(function()
                    TeleportService:Teleport(game.PlaceId, plr)
                end)
            end
        end)
    end)
    if not success then
        log("⚠️ Không thể đăng ký tính năng Anti-Kick: " .. tostring(err))
    end
end)

-- 2. Thiết lập noclip liên tục chống kẹt
local noclipConnection
if noclipConnection then noclipConnection:Disconnect() end
noclipConnection = RunService.Stepped:Connect(function()
    if getgenv().AutoFarmKen and _G.Clip then
        local char = plr.Character
        if char then
            for _, part in ipairs(char:GetDescendants()) do
                if part:IsA("BasePart") then
                    part.CanCollide = false
                end
            end
        end
    end
end)

-- 2. Xác định Sea hiện tại
local function getSea()
    local placeId = game.PlaceId
    if placeId == 4442272183 or placeId == 7407950593 then
        return 2
    elseif placeId == 7407951717 or placeId == 7449423635 then
        return 3
    end
    return 1
end

-- 3. Xác định tọa độ X Y Z tập kết mặc định theo từng Sea
local function getTargetPosition()
    local currentSea = getSea()
    if currentSea == 3 then
        return Vector3.new(-13475, 536, -7115) -- Hydra Island (Sea 3)
    elseif currentSea == 2 then
        return Vector3.new(-951, 85, -2995) -- Graveyard (Sea 2)
    else
        return Vector3.new(5921, 38, 4835) -- Sea 1
    end
end

-- 4. Tự động chọn phe (Remote + GUI Click Fallback tương tự AutoFindFruitAndHopServer.lua)
local function autoSelectTeam()
    local teamValue = getgenv().Team
    local teamName = (teamValue == 0) and "Marines" or "Pirates"

    log("⏳ Đang chờ game sẵn sàng để tự động chọn phe " .. teamName .. "...")
    task.wait(getgenv().TeamSelectDelay)

    -- Gọi Remote SetTeam
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
        log("✅ Đã chọn phe (" .. teamName .. ") qua Remote thành công!")
        return
    else
        log("❌ Remote chọn phe thất bại: " .. tostring(result) .. ". Thử click GUI...")
    end

    -- Click GUI Fallback
    pcall(function()
        local playerGui = plr:WaitForChild("PlayerGui", 5)
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
                log("✅ Đã chọn phe (" .. teamName .. ") qua click GUI bypass!")
            else
                log("⚠️ Vui lòng tự nhấp nút GUI chọn phe.")
            end
        else
            log("⚠️ Không tìm thấy nút chọn phe trên GUI.")
        end
    end)
end

-- 5. Hàm kiểm tra trạng thái bật của Ken Haki
local function isKenActive()
    local char = plr.Character
    if char then
        for _, child in ipairs(char:GetChildren()) do
            local nameLower = child.Name:lower()
            if string.find(nameLower, "ken") or string.find(nameLower, "observation") or string.find(nameLower, "instinct") then
                return true
            end
        end
    end

    for attr, val in pairs(plr:GetAttributes()) do
        local attrLower = attr:lower()
        if (string.find(attrLower, "ken") or string.find(attrLower, "observation") or string.find(attrLower, "instinct")) and type(val) == "boolean" then
            if val == true then
                return true
            end
        end
    end

    for _, effect in ipairs(Lighting:GetChildren()) do
        if effect:IsA("ColorCorrectionEffect") then
            local nameLower = effect.Name:lower()
            if string.find(nameLower, "ken") or string.find(nameLower, "observation") or string.find(nameLower, "instinct") then
                return true
            end
        end
    end

    return false
end

-- 6. Hàm di chuyển mượt mà (Tween)
local function teleport(targetCFrame)
    local char = plr.Character
    if not char or not char:FindFirstChild("HumanoidRootPart") then return end
    local root = char.HumanoidRootPart
    
    local distance = (targetCFrame.Position - root.Position).Magnitude
    
    if distance < 100 then
        root.CFrame = targetCFrame
        return
    end
    
    if char:FindFirstChild("Humanoid") and char.Humanoid.Sit then
        char.Humanoid.Sit = false
    end
    
    _G.Clip = true
    
    local bv = Instance.new("BodyVelocity")
    bv.Velocity = Vector3.new(0, 0, 0)
    bv.MaxForce = Vector3.new(9e9, 9e9, 9e9)
    bv.Parent = root
    
    local speed = 350
    local duration = distance / speed
    
    local tween = TweenService:Create(root, TweenInfo.new(duration, Enum.EasingStyle.Linear), {CFrame = targetCFrame})
    local completed = false
    local connection
    connection = tween.Completed:Connect(function()
        completed = true
    end)
    
    tween:Play()
    
    while not completed and getgenv().AutoFarmKen do
        task.wait(0.1)
        if not plr.Character or not plr.Character:FindFirstChild("HumanoidRootPart") or plr.Character.Humanoid.Health <= 0 then
            tween:Cancel()
            break
        end
    end
    
    if connection then connection:Disconnect() end
    if bv then bv:Destroy() end
end

-- 7. Chờ nhân vật load xong hoàn toàn
local function WaitForCharacter()
    local char = plr.Character or plr.CharacterAdded:Wait()
    repeat task.wait(0.5)
    until char and char:FindFirstChild("HumanoidRootPart") and char:FindFirstChild("Humanoid")
    task.wait(1.5)
    return char
end

-- 8. Tìm con quái gần nhất với tọa độ chỉ định X Y Z
local function getNearestMonsterToPosition(pos)
    local nearest = nil
    local minDist = math.huge
    
    local enemiesFolder = workspace:FindFirstChild("Enemies")
    if enemiesFolder then
        for _, enemy in ipairs(enemiesFolder:GetChildren()) do
            if enemy:IsA("Model") and enemy:FindFirstChild("HumanoidRootPart") and enemy:FindFirstChild("Humanoid") and enemy.Humanoid.Health > 0 then
                local dist = (enemy.HumanoidRootPart.Position - pos).Magnitude
                if dist < minDist then
                    minDist = dist
                    nearest = enemy
                end
            end
        end
    end
    
    if not nearest then
        for _, enemy in ipairs(workspace:GetChildren()) do
            if enemy:IsA("Model") and enemy:FindFirstChild("HumanoidRootPart") and enemy:FindFirstChild("Humanoid") and enemy.Humanoid.Health > 0 and enemy.Name ~= plr.Name and not Players:GetPlayerFromCharacter(enemy) then
                local dist = (enemy.HumanoidRootPart.Position - pos).Magnitude
                if dist < minDist then
                    minDist = dist
                    nearest = enemy
                end
            end
        end
    end
    return nearest
end

-- 9. Chuyển Server cực kỳ mạnh mẽ (tương tự AutoFindFruitAndHopServer.lua)
local function serverHop()
    local placeId = game.PlaceId
    log("[Server Hop] Đang xếp hàng script và tìm server trống...")
    
    -- Xếp hàng chạy lại script này sau khi chuyển server thành công
    pcall(function()
        local queueteleport = (syn and syn.queue_on_teleport)
            or queue_on_teleport
            or (fluxus and fluxus.queue_on_teleport)
        if queueteleport then
            queueteleport('loadstring(readfile("auto_farm_ken.lua"))()')
            log("[Server Hop] Đã xếp hàng chạy lại script.")
        end
    end)
    
    while true do
        local apiUrl = "https://games.roblox.com/v1/games/" .. placeId .. "/servers/Public?sortOrder=Desc&excludeFullGames=true&limit=100"
        
        local function ListServers(cursor)
            local raw = game:HttpGet(apiUrl .. ((cursor and "&cursor=" .. cursor) or ""))
            return HttpService:JSONDecode(raw)
        end
        
        local Server, Next
        local pageAttempts = 0
        local maxPages = 5
        
        pcall(function()
            repeat task.wait(0.5)
                pageAttempts = pageAttempts + 1
                local Servers = ListServers(Next)
                if Servers and Servers.data then
                    for _, s in pairs(Servers.data) do
                        if s.id ~= game.JobId and s.playing and s.maxPlayers and s.playing < (s.maxPlayers - 1) then
                            Server = s
                            break
                        end
                    end
                    Next = Servers.nextPageCursor
                end
            until Server or not Next or pageAttempts >= maxPages
        end)
        
        if Server then
            log("[Server Hop] Đã tìm thấy server (" .. Server.playing .. "/" .. Server.maxPlayers .. "). Đang kết nối...")
            
            -- Thử nhảy bằng __ServerBrowser trước
            local teleportSuccess, teleportErr = pcall(function()
                return ReplicatedStorage:WaitForChild("__ServerBrowser", 5):InvokeServer("teleport", Server.id)
            end)
            
            if not teleportSuccess then
                log("[Server Hop] Browser lỗi. Dùng TeleportService dự phòng...")
                pcall(function()
                    TeleportService:TeleportToPlaceInstance(placeId, Server.id, plr)
                end)
            end
            task.wait(10)
        else
            log("[Server Hop] Không quét được API. Dùng Teleport ngẫu nhiên...")
            pcall(function()
                TeleportService:Teleport(placeId, plr)
            end)
            task.wait(15)
        end
    end
end

-- ==========================================================
-- LUỒNG CHẠY TUYẾN TÍNH (LINEAR PIPELINE)
-- ==========================================================

-- BƯỚC 1: Tự động chọn phe
autoSelectTeam()

-- BƯỚC 2: Chờ nhân vật load xong hoàn toàn
log("⏳ Đang chờ nhân vật tải xong hoàn toàn...")
local char = WaitForCharacter()
local root = char:WaitForChild("HumanoidRootPart")
local hum = char:WaitForChild("Humanoid")
log("✅ Nhân vật đã sẵn sàng!")

-- BƯỚC 3: Dịch chuyển ban đầu đến điểm tọa độ tập kết X Y Z và quét tìm quái
local targetAnchor = getTargetPosition()
log("✈️ Dịch chuyển ban đầu đến tọa độ X Y Z: " .. tostring(targetAnchor))
teleport(CFrame.new(targetAnchor))
task.wait(0.5)

log("🔍 Đang tìm quái gần nhất với tọa độ X Y Z...")
local enemy = nil
local scanAttempts = 0
repeat
    enemy = getNearestMonsterToPosition(targetAnchor)
    if not enemy then
        -- Nếu chưa có quái, đảm bảo đứng ở điểm neo để chờ quái hồi sinh
        teleport(CFrame.new(targetAnchor))
        task.wait(1)
        scanAttempts = scanAttempts + 1
        if scanAttempts % 5 == 0 then
            log("⏳ Vẫn đang quét tìm quái gần tọa độ...")
        end
    end
until enemy or not getgenv().AutoFarmKen or hum.Health <= 0

-- BƯỚC 4: Dịch chuyển áp sát quái và khóa vị trí
if enemy and hum.Health > 0 then
    local enemyRoot = enemy:FindFirstChild("HumanoidRootPart")
    if enemyRoot then
        log("✈️ Đang dịch chuyển áp sát quái: " .. enemy.Name)
        teleport(enemyRoot.CFrame)
        task.wait(0.2)
        
        -- Khóa vị trí nhân vật tại quái để chịu đòn
        root.Anchored = true
        log("🔒 Đã khóa vị trí. Đang kích hoạt Ken Haki...")
        
        -- Hàm bật Ken kết hợp song song cả Remote và Phím E đã kiểm chứng hoạt động tốt
        local function activateKen()
            pcall(function()
                ReplicatedStorage.Remotes.CommE:FireServer("Ken", true)
            end)
            pcall(function()
                VirtualInputManager:SendKeyEvent(true, Enum.KeyCode.E, false, game)
                task.wait(0.1)
                VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.E, false, game)
            end)
        end
        
        activateKen()
        
        -- BƯỚC 5: Đợi số lần né tránh về 0 (Liên tục bám đuổi quái nếu quái chết hoặc bị kéo đi)
        while getgenv().AutoFarmKen and hum.Health > 0 do
            local dodgesLeft = plr:GetAttribute("KenDodgesLeft")
            
            -- Nếu thuộc tính né chưa load, tự kích hoạt Ken một lần để đăng ký thuộc tính
            if not dodgesLeft then
                if not isKenActive() then
                    activateKen()
                end
                task.wait(0.5)
                dodgesLeft = plr:GetAttribute("KenDodgesLeft") or 8
            end
            
            log(string.format("🛡️ Đang chịu đòn | Lượt né tránh còn lại: %d", dodgesLeft))
            
            if dodgesLeft == 0 then
                log("⚠️ Đã hết lượt né tránh (Về 0)!")
                break
            end
            
            -- Kiểm tra khoảng cách từ vị trí hiện tại đến điểm neo (targetAnchor)
            -- Nếu bay quá xa (> 200 studs), bay ngược trở về điểm neo X Y Z để quét lại quái
            local currentDistFromAnchor = (root.Position - targetAnchor).Magnitude
            if currentDistFromAnchor > 200 then
                log("⚠️ Nhân vật bay quá xa điểm neo (> 200 studs: " .. math.floor(currentDistFromAnchor) .. " studs)!")
                log("✈️ Thực hiện bay ngược trở về điểm neo X Y Z...")
                root.Anchored = false
                teleport(CFrame.new(targetAnchor))
                task.wait(0.5)
                enemy = nil -- Xóa mục tiêu cũ để bắt đầu quét tìm con quái mới gần điểm neo hơn
            end

            -- Kiểm tra xem quái hiện tại còn sống và ở gần không
            local targetValid = false
            if enemy and enemy.Parent and enemy:FindFirstChild("HumanoidRootPart") and enemy:FindFirstChild("Humanoid") and enemy.Humanoid.Health > 0 then
                local dist = (root.Position - enemy.HumanoidRootPart.Position).Magnitude
                if dist <= 15 then
                    targetValid = true
                end
            end
            
            if not targetValid then
                log("🔄 Quái mục tiêu đã chết, biến mất hoặc bị kéo đi xa (> 15 studs). Đang tìm quái mới...")
                root.Anchored = false
                
                -- Quét tìm quái mới gần nhất với tọa độ neo
                local newEnemy = getNearestMonsterToPosition(targetAnchor)
                if newEnemy and newEnemy:FindFirstChild("HumanoidRootPart") then
                    enemy = newEnemy
                    log("✈️ Dịch chuyển áp sát quái mới: " .. enemy.Name)
                    teleport(enemy.HumanoidRootPart.CFrame)
                    task.wait(0.2)
                    root.Anchored = true
                else
                    log("⏳ Không tìm thấy quái xung quanh điểm neo, đang bay về X Y Z chờ quái hồi sinh...")
                    teleport(CFrame.new(targetAnchor))
                    task.wait(1)
                end
            else
                -- Đảm bảo nhân vật luôn ở sát quái (bám đuổi liên tục nếu quái di chuyển nhẹ)
                pcall(function()
                    root.CFrame = enemy.HumanoidRootPart.CFrame
                end)
            end
            
            -- Đảm bảo Ken Haki luôn mở
            if not isKenActive() then
                activateKen()
            end
            
            task.wait(0.5)
        end
    end
end

-- BƯỚC 6: Mở khóa vị trí và thực hiện đổi Server
root.Anchored = false
log("🔓 Đã mở khóa vị trí. Tiến hành đổi Server...")
serverHop()
