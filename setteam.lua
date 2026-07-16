-- ============================================================
-- CODE CHỌN TEAM CHO BLOX FRUIT
-- Hỗ trợ set team Marines hoặc Pirates qua biến getgenv()
-- ============================================================

-- CÁCH SỬ DỤNG:
-- 1. Set team MARINES (mặc định):
--    loadstring(game:HttpGet("https://raw.githubusercontent.com/YOUR_USERNAME/YOUR_REPO/main/SelectTeam.lua"))()
--
-- 2. Set team PIRATES:
--    getgenv().Team = "Pirates"
--    loadstring(game:HttpGet("https://raw.githubusercontent.com/YOUR_USERNAME/YOUR_REPO/main/SelectTeam.lua"))()
--
-- 3. Set team MARINES (cách khác):
--    getgenv().Team = "Marines"
--    loadstring(game:HttpGet("https://raw.githubusercontent.com/YOUR_USERNAME/YOUR_REPO/main/SelectTeam.lua"))()

-- ============================================================
-- CODE CHÍNH
-- ============================================================

-- Đợi game load
repeat task.wait() until game:IsLoaded()

-- Lấy thông tin người chơi
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Player = Players.LocalPlayer

-- Kiểm tra team từ biến getgenv()
local teamInput = getgenv().Team or "Marines"
local teamName = teamInput:lower()

-- Chuẩn hóa tên team
if teamName == "marine" or teamName == "marines" then
    teamName = "Marines"
elseif teamName == "pirate" or teamName == "pirates" then
    teamName = "Pirates"
else
    teamName = "Marines" -- Mặc định nếu nhập sai
    warn("⚠️ Team không hợp lệ! Đã set mặc định: Marines")
end

print("⏳ Đang chọn team: " .. teamName .. "...")

-- Lấy remote CommF_
local CommF = ReplicatedStorage:WaitForChild("Remotes", 9e9):WaitForChild("CommF_", 9e9)

-- Chờ vài giây để game load đầy đủ
task.wait(5)

-- HÀM CHỌN TEAM
local function SelectTeam(team)
    -- Cách 1: Gọi remote "SetTeam"
    local success, result = pcall(function()
        return CommF:InvokeServer("SetTeam", team)
    end)
    
    if success then
        print("✅ Đã chọn team " .. team .. " thành công!")
        return true
    else
        print("❌ Remote call thất bại: " .. tostring(result))
        print("🔄 Đang thử phương pháp fallback...")
        
        -- Cách 2: Click vào nút GUI
        pcall(function()
            local playerGui = Player:WaitForChild("PlayerGui", 5)
            local mainGui = playerGui:WaitForChild("Main", 3)
            local chooseTeam = mainGui:WaitForChild("ChooseTeam", 3)
            local container = chooseTeam:WaitForChild("Container", 2)
            local button = container:WaitForChild(team, 2):WaitForChild("Frame", 1):WaitForChild("ViewportFrame", 1):WaitForChild("TextButton", 1)
            
            if button then
                for _, conn in pairs(getconnections(button.MouseButton1Click)) do
                    conn.Function()
                end
                print("✅ Đã chọn team " .. team .. " qua click fallback!")
                return true
            else
                print("⚠️ Không tìm thấy nút " .. team)
                return false
            end
        end)
        return false
    end
end

-- Gọi hàm chọn team
SelectTeam(teamName)

print("🎯 Hoàn tất! Team hiện tại: " .. teamName)
