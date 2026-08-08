--[[
  ╔══════════════════════════════════════════════════════════════════════╗
  ║         BLOX FRUITS - SMART FRUIT COLLECTOR v2                      ║
  ║  • Chọn phe tự động khi vào server                                  ║
  ║  • Quét trái trong server → lọc theo kho + MAX CAP                  ║
  ║  • Ưu tiên trái không tên / giá trị cao → bay nhặt → cất            ║
  ║  • ESP: BillboardGui + Highlight cho trái đủ điều kiện nhặt         ║
  ║  • Panel danh sách trái real-time bên phải màn hình                 ║
  ║  • Hết trái → hop server ưu tiên ~11 người, check lại nếu thất bại  ║
  ╚══════════════════════════════════════════════════════════════════════╝
]]

-- ══════════════════════════════════════════════════════════════════
-- ▌ CẤU HÌNH NGƯỜI DÙNG – CHỈNH TẠI ĐÂY
-- ══════════════════════════════════════════════════════════════════
local CFG = {
    -- Số trái tối đa có thể lưu trong rương (Max Storage Cap của game)
    -- Chỉnh theo số slot rương thực tế của bạn trong Blox Fruits
    MAX_CAP = 2,

    -- Phe muốn vào: "Pirates" hoặc "Marines"
    TEAM = "Pirates",

    -- Tốc độ bay đến trái (studs/giây) – LUÔN CỐ ĐỊNH 250
    FLY_SPEED = 250,

    -- Số lần retry khi cất thất bại
    STORE_RETRIES = 3,

    -- Delay giữa mỗi lần kiểm tra trái trong server (giây)
    SCAN_INTERVAL = 0.5,

    -- Target player count khi hop server (ưu tiên server gần 11 người)
    HOP_TARGET_PLAYERS = 11,

    -- Cơ chế hop: "high" = ưu tiên nhiều người, "low" = ưu tiên ít người
    HOP_MODE = "high",

    -- CẤU HÌNH DISCORD WEBHOOK
    WEBHOOK_FRUIT = "https://discord.com/api/webhooks/1535615262794059786/vSCqu2ACqshTBfzkAbpQPCV3VETINI1DPgALgHPgyCyT2vsv_2vDrnKJaH8gtaELnz-7",  -- Webhook thông báo khi nhặt & cất trái thành công/lỗi
    WEBHOOK_STATUS = "https://discord.com/api/webhooks/1535615430759026689/KeE5Cq0a8TKEmOMiYILjPwaLXCYWiT1bKoOYeR_wKFI_ZmADKQM3gbpCKiupMAtIlcqr", -- Webhook thông báo trạng thái hoạt động mỗi 5 phút
}

-- ══════════════════════════════════════════════════════════════════
-- ▌ BẢNG GIÁ TRÁI (cập nhật theo wiki 2026 - Blox Fruits Fandom)
--   Giá = Beli mua tại NPC Blox Fruit Dealer
--   Dùng để SORT ưu tiên: giá càng cao → nhặt trước
--   Trái không có tên (Tool không có "Fruit" trong tên) → ưu tiên MAX
-- ══════════════════════════════════════════════════════════════════
local FRUIT_PRICE = {
    -- ―― COMMON ――
    ["Bomb Fruit"]                = 5000,
    ["Spike Fruit"]               = 7500,
    ["Rocket Fruit"]              = 5000,
    ["Spin Fruit"]                = 7500,
    ["Chop Fruit"]                = 30000,
    ["Spring Fruit"]              = 60000,
    ["Kilo Fruit"]                = 5000,
    ["Smoke Fruit"]               = 100000,
    ["Flame Fruit"]               = 250000,
    ["Ice Fruit"]                 = 350000,
    ["Sand Fruit"]                = 420000,
    ["Dark Fruit"]                = 500000,
    ["Revive Fruit"]              = 550000,
    ["Diamond Fruit"]             = 600000,
    ["Light Fruit"]               = 650000,
    ["Rubber Fruit"]              = 750000,
    ["Magma Fruit"]               = 850000,
    -- ―― UNCOMMON ――
    ["Eagle Fruit"]               = 550000,
    ["Bird: Eagle Fruit"]         = 550000,
    ["Falcon Fruit"]              = 550000,
    ["Bird: Falcon Fruit"]        = 550000,
    ["Ghost Fruit"]               = 1000000,
    ["Spider Fruit"]              = 1500000,
    ["Blizzard Fruit"]            = 1500000,
    ["String Fruit"]              = 1500000,
    ["Thunder Fruit"]             = 1500000,
    ["Mammoth Fruit"]             = 1700000,
    ["Phoenix Fruit"]             = 1800000,
    ["Bird: Phoenix Fruit"]       = 1800000,
    ["Sound Fruit"]               = 1800000,
    -- ―― RARE ――
    ["Buddha Fruit"]              = 1250000,
    ["Human-Human: Buddha Fruit"] = 1250000,
    ["Portal Fruit"]              = 1000000,
    ["Quake Fruit"]               = 1000000,
    ["Rumble Fruit"]              = 2100000,
    ["Gravity Fruit"]             = 2500000,
    ["Paw Fruit"]                 = 2300000,
    ["Dough Fruit"]               = 2800000,
    ["Pain Fruit"]                = 2900000,
    ["Shadow Fruit"]              = 2900000,
    ["Venom Fruit"]               = 3000000,
    ["Control Fruit"]             = 3000000,
    ["Spirit Fruit"]              = 3400000,
    -- ―― LEGENDARY / MYTHICAL ――
    ["Creation Fruit"]            = 1400000,
    ["Barrier Fruit"]             = 800000,
    ["Dragon Fruit"]              = 15000000,
    ["Kitsune Fruit"]             = 8000000,
    ["Tiger Fruit"]               = 5000000,
    ["Leopard Fruit"]             = 5000000,
    ["T-Rex Fruit"]               = 5000000,
}

-- ▌ BẢNG TRA CỨU: Tool Name → StoreFruit Code (cập nhật 2026)
local FRUIT_MAP = {
    -- ―― COMMON ――
    ["Bomb Fruit"]                   = "Bomb-Bomb",
    ["Spike Fruit"]                  = "Spike-Spike",
    ["Rocket Fruit"]                 = "Rocket-Rocket",
    ["Spin Fruit"]                   = "Spin-Spin",
    ["Chop Fruit"]                   = "Chop-Chop",
    ["Spring Fruit"]                 = "Spring-Spring",
    ["Kilo Fruit"]                   = "Kilo-Kilo",
    ["Smoke Fruit"]                  = "Smoke-Smoke",
    ["Flame Fruit"]                  = "Flame-Flame",
    ["Ice Fruit"]                    = "Ice-Ice",
    ["Sand Fruit"]                   = "Sand-Sand",
    ["Dark Fruit"]                   = "Dark-Dark",
    ["Ghost Fruit"]                  = "Ghost-Ghost",
    ["Revive Fruit"]                 = "Revive-Revive",
    ["Diamond Fruit"]                = "Diamond-Diamond",
    ["Light Fruit"]                  = "Light-Light",
    ["Love Fruit"]                   = "Love-Love",
    ["Rubber Fruit"]                 = "Rubber-Rubber",
    ["Magma Fruit"]                  = "Magma-Magma",
    ["Portal Fruit"]                 = "Door-Door",
    ["Quake Fruit"]                  = "Quake-Quake",
    -- ―― UNCOMMON ――
    ["Spider Fruit"]                 = "Spider-Spider",
    ["Sound Fruit"]                  = "Sound-Sound",
    ["Rumble Fruit"]                 = "Rumble-Rumble",
    ["Pain Fruit"]                   = "Pain-Pain",
    ["Blizzard Fruit"]               = "Blizzard-Blizzard",
    ["Gravity Fruit"]                = "Gravity-Gravity",
    ["Mammoth Fruit"]                = "Mammoth-Mammoth",
    ["Thunder Fruit"]                = "Thunder-Thunder",
    ["T-Rex Fruit"]                  = "TRex-TRex",
    ["Dough Fruit"]                  = "Dough-Dough",
    ["Shadow Fruit"]                 = "Shadow-Shadow",
    ["Venom Fruit"]                  = "Venom-Venom",
    ["Control Fruit"]                = "Control-Control",
    ["Spirit Fruit"]                 = "Soul-Soul",
    ["String Fruit"]                 = "String-String",
    ["Paw Fruit"]                    = "Paw-Paw",
    -- ―― RARE ――
    ["Buddha Fruit"]                 = "Human-Human: Buddha",
    ["Human-Human: Buddha Fruit"]    = "Human-Human: Buddha",
    -- ―― LEGENDARY ――
    -- Eagle (thay thế Falcon từ Update 26+)
    ["Eagle Fruit"]                  = "Bird-Bird: Eagle",
    ["Bird: Eagle Fruit"]            = "Bird-Bird: Eagle",
    -- Legacy Falcon (server cũ vẫn có thể có)
    ["Falcon Fruit"]                 = "Bird-Bird: Falcon",
    ["Bird: Falcon Fruit"]           = "Bird-Bird: Falcon",
    -- Phoenix
    ["Phoenix Fruit"]                = "Bird-Bird: Phoenix",
    ["Bird: Phoenix Fruit"]          = "Bird-Bird: Phoenix",
    -- Creation (thay thế Barrier từ Update 26+)
    ["Creation Fruit"]               = "Creation-Creation",
    -- Legacy Barrier
    ["Barrier Fruit"]                = "Barrier-Barrier",
    -- ―― MYTHICAL ――
    ["Dragon Fruit"]                 = "Dragon-Dragon",
    ["Kitsune Fruit"]                = "Kitsune-Kitsune",
    -- Tiger (thay thế Leopard từ Update 28+)
    ["Tiger Fruit"]                  = "Tiger-Tiger",
    -- Legacy Leopard
    ["Leopard Fruit"]                = "Leopard-Leopard",
}

-- ══════════════════════════════════════════════════════════════════
-- ▌ KHỞI TẠO DỊCH VỤ
-- ══════════════════════════════════════════════════════════════════
if not game:IsLoaded() then
    local loaded = false
    local conn
    pcall(function()
        conn = game.Loaded:Connect(function()
            loaded = true
            if conn then conn:Disconnect() end
        end)
    end)
    local waited = 0
    while not loaded and waited < 5 do
        task.wait(0.5)
        waited = waited + 0.5
    end
    pcall(function()
        if conn and conn.Connected then conn:Disconnect() end
    end)
end
task.wait(0.5)

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService      = game:GetService("TweenService")
local TeleportService   = game:GetService("TeleportService")
local RunService        = game:GetService("RunService")
local HttpService       = game:GetService("HttpService")
local VirtualUser       = game:GetService("VirtualUser")

local LocalPlayer = Players.LocalPlayer
while not LocalPlayer do
    task.wait(0.1)
    LocalPlayer = Players.LocalPlayer
end

-- ══════════════════════════════════════════════════════════════════
-- ▌ BIẾN TRẠNG THÁI TOÀN CỤC
-- ══════════════════════════════════════════════════════════════════
_G.SmartFruitCollector = true   -- false để dừng
local isFlying    = false
local activeTween = nil
local totalStored = 0           -- tổng số trái đã cất trong phiên
local storedLog   = {}          -- {"Dragon Fruit", "Nika Fruit", ...}

-- ESP state: lưu các ESP đang active { [tool] = {billboard, highlight, selbox} }
local espObjects  = {}          -- key = tool object
local currentPickupList = {}    -- danh sách trái đủ điều kiện nhặt hiện tại

-- Khởi tạo Remote bất đồng bộ / an toàn
local CommF = nil
task.spawn(function()
    local Remotes = ReplicatedStorage:WaitForChild("Remotes", 15)
    if Remotes then
        CommF = Remotes:WaitForChild("CommF_", 15)
    end
end)

-- ══════════════════════════════════════════════════════════════════
-- ▌ GUI SETUP (Tạo ngay lập tức để người dùng thấy giao diện)
-- ══════════════════════════════════════════════════════════════════
-- Huỷ GUI cũ ở cả hai vị trí (nếu có) để tránh trùng lặp
pcall(function()
    local cg = game:GetService("CoreGui")
    if cg and cg:FindFirstChild("SmartFruitCollectorGUI") then
        cg.SmartFruitCollectorGUI:Destroy()
    end
end)
pcall(function()
    local pg = LocalPlayer:FindFirstChild("PlayerGui")
    if pg and pg:FindFirstChild("SmartFruitCollectorGUI") then
        pg.SmartFruitCollectorGUI:Destroy()
    end
end)

local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name          = "SmartFruitCollectorGUI"
ScreenGui.ResetOnSpawn  = false
ScreenGui.ZIndexBehavior= Enum.ZIndexBehavior.Sibling

-- Gán parent an toàn bằng pcall
local parentSet = false
pcall(function()
    ScreenGui.Parent = game:GetService("CoreGui")
    parentSet = true
end)
if not parentSet then
    pcall(function()
        ScreenGui.Parent = LocalPlayer:WaitForChild("PlayerGui", 10) or LocalPlayer.PlayerGui
    end)
end

-- ScreenGui chuyên dụng cho ESP (bắt buộc phải nằm dưới PlayerGui để vẽ được đối tượng 3D Billboard)
local EspGui = Instance.new("ScreenGui")
EspGui.Name          = "SFC_EspGui"
EspGui.ResetOnSpawn  = false
pcall(function()
    local pg = LocalPlayer:FindFirstChild("PlayerGui")
    if pg and pg:FindFirstChild("SFC_EspGui") then
        pg.SFC_EspGui:Destroy()
    end
end)
pcall(function()
    EspGui.Parent = LocalPlayer:WaitForChild("PlayerGui", 10) or LocalPlayer.PlayerGui
end)

-- Nút tròn quả táo để khôi phục giao diện (khi bị thu nhỏ)
local OpenBtn = Instance.new("TextButton", ScreenGui)
OpenBtn.Name             = "OpenButton"
OpenBtn.Size             = UDim2.new(0, 46, 0, 46)
OpenBtn.Position         = UDim2.new(0, 14, 0, 14)
OpenBtn.BackgroundColor3 = Color3.fromRGB(60, 20, 180)
OpenBtn.BackgroundTransparency = 0.15
OpenBtn.BorderSizePixel  = 0
OpenBtn.Text             = "🍎"
OpenBtn.TextColor3       = Color3.fromRGB(255, 255, 255)
OpenBtn.TextSize         = 20
OpenBtn.Font             = Enum.Font.GothamBold
OpenBtn.Visible          = false
OpenBtn.Active           = true
OpenBtn.Draggable        = true
Instance.new("UICorner", OpenBtn).CornerRadius = UDim.new(0, 23)
local openStroke = Instance.new("UIStroke", OpenBtn)
openStroke.Color     = Color3.fromRGB(255, 120, 30)
openStroke.Thickness = 1.5

local MainFrame = Instance.new("Frame", ScreenGui)
MainFrame.Name             = "Main"
MainFrame.Size             = UDim2.new(0, 360, 0, 340)
MainFrame.Position         = UDim2.new(0, 14, 0, 14)
MainFrame.BackgroundColor3 = Color3.fromRGB(12, 12, 22)
MainFrame.BackgroundTransparency = 0.1
MainFrame.BorderSizePixel  = 0
MainFrame.Active           = true
MainFrame.Draggable        = true

Instance.new("UICorner", MainFrame).CornerRadius = UDim.new(0, 12)
local mainStroke = Instance.new("UIStroke", MainFrame)
mainStroke.Color     = Color3.fromRGB(120, 60, 255)
mainStroke.Thickness = 1.8

-- Title bar
local TitleBar = Instance.new("Frame", MainFrame)
TitleBar.Size              = UDim2.new(1, 0, 0, 38)
TitleBar.BackgroundColor3  = Color3.fromRGB(80, 30, 220)
TitleBar.BackgroundTransparency = 0.35
TitleBar.BorderSizePixel   = 0
Instance.new("UICorner", TitleBar).CornerRadius = UDim.new(0, 12)
local titleFix = Instance.new("Frame", TitleBar)
titleFix.Size             = UDim2.new(1, 0, 0, 14)
titleFix.Position         = UDim2.new(0, 0, 1, -14)
titleFix.BackgroundColor3 = Color3.fromRGB(80, 30, 220)
titleFix.BackgroundTransparency = 0.35
titleFix.BorderSizePixel  = 0

local TitleLbl = Instance.new("TextLabel", TitleBar)
TitleLbl.Size             = UDim2.new(1, -50, 1, 0)
TitleLbl.Position         = UDim2.new(0, 10, 0, 0)
TitleLbl.BackgroundTransparency = 1
TitleLbl.Text             = "🍎  Smart Fruit Collector"
TitleLbl.TextColor3       = Color3.fromRGB(255, 255, 255)
TitleLbl.TextSize         = 15
TitleLbl.Font             = Enum.Font.GothamBold
TitleLbl.TextXAlignment   = Enum.TextXAlignment.Left

-- Nút thu nhỏ giao diện
local MinBtn = Instance.new("TextButton", TitleBar)
MinBtn.Name             = "MinBtn"
MinBtn.Size             = UDim2.new(0, 24, 0, 24)
MinBtn.Position         = UDim2.new(1, -34, 0.5, -12)
MinBtn.BackgroundColor3 = Color3.fromRGB(180, 40, 40)
MinBtn.BorderSizePixel  = 0
MinBtn.Text             = "➖"
MinBtn.TextColor3       = Color3.fromRGB(255, 255, 255)
MinBtn.TextSize         = 10
MinBtn.Font             = Enum.Font.GothamBold
Instance.new("UICorner", MinBtn).CornerRadius = UDim.new(0, 6)

MinBtn.MouseButton1Click:Connect(function()
    MainFrame.Visible = false
    local espP = ScreenGui:FindFirstChild("EspPanel")
    if espP then espP.Visible = false end
    OpenBtn.Visible = true
end)

OpenBtn.MouseButton1Click:Connect(function()
    MainFrame.Visible = true
    local espP = ScreenGui:FindFirstChild("EspPanel")
    if espP then espP.Visible = true end
    OpenBtn.Visible = false
end)

-- Status label
local StatusLbl = Instance.new("TextLabel", MainFrame)
StatusLbl.Size             = UDim2.new(1, -20, 0, 30)
StatusLbl.Position         = UDim2.new(0, 10, 0, 44)
StatusLbl.BackgroundTransparency = 1
StatusLbl.Text             = "⏳ Đang khởi động..."
StatusLbl.TextColor3       = Color3.fromRGB(255, 200, 50)
StatusLbl.TextSize         = 13
StatusLbl.Font             = Enum.Font.GothamBold
StatusLbl.TextXAlignment   = Enum.TextXAlignment.Left
StatusLbl.TextWrapped      = true

-- Stored count label
local StoredLbl = Instance.new("TextLabel", MainFrame)
StoredLbl.Size             = UDim2.new(1, -20, 0, 20)
StoredLbl.Position         = UDim2.new(0, 10, 0, 78)
StoredLbl.BackgroundTransparency = 1
StoredLbl.Text             = "📦 Đã cất: 0 trái  |  MAX CAP: " .. CFG.MAX_CAP
StoredLbl.TextColor3       = Color3.fromRGB(120, 220, 120)
StoredLbl.TextSize         = 11
StoredLbl.Font             = Enum.Font.Gotham
StoredLbl.TextXAlignment   = Enum.TextXAlignment.Left

-- Log scrolling frame
local LogFrame = Instance.new("ScrollingFrame", MainFrame)
LogFrame.Size              = UDim2.new(1, -20, 0, 190)
LogFrame.Position          = UDim2.new(0, 10, 0, 104)
LogFrame.BackgroundColor3  = Color3.fromRGB(5, 5, 15)
LogFrame.BackgroundTransparency = 0.25
LogFrame.BorderSizePixel   = 0
LogFrame.ScrollBarThickness= 4
LogFrame.ScrollBarImageColor3 = Color3.fromRGB(120, 60, 255)
LogFrame.AutomaticCanvasSize = Enum.AutomaticSize.Y
LogFrame.CanvasSize        = UDim2.new(0, 0, 0, 0)
Instance.new("UICorner", LogFrame).CornerRadius = UDim.new(0, 8)
local logLayout = Instance.new("UIListLayout", LogFrame)
logLayout.SortOrder = Enum.SortOrder.LayoutOrder
logLayout.Padding   = UDim.new(0, 2)
local logPad = Instance.new("UIPadding", LogFrame)
logPad.PaddingTop    = UDim.new(0, 4)
logPad.PaddingLeft   = UDim.new(0, 6)
logPad.PaddingRight  = UDim.new(0, 6)

-- Stop button
local StopBtn = Instance.new("TextButton", MainFrame)
StopBtn.Size             = UDim2.new(1, -20, 0, 32)
StopBtn.Position         = UDim2.new(0, 10, 1, -42)
StopBtn.BackgroundColor3 = Color3.fromRGB(180, 40, 40)
StopBtn.BorderSizePixel  = 0
StopBtn.Text             = "🛑  DỪNG SCRIPT"
StopBtn.TextColor3       = Color3.fromRGB(255, 255, 255)
StopBtn.TextSize         = 13
StopBtn.Font             = Enum.Font.GothamBold
Instance.new("UICorner", StopBtn).CornerRadius = UDim.new(0, 8)

-- ══════════════════════════════════════════════════════════════════
-- ▌ DISCORD WEBHOOK INTEGRATION
-- ══════════════════════════════════════════════════════════════════
local function SendWebhook(webhookUrl, payload)
    if not webhookUrl or webhookUrl == "" or webhookUrl == "YOUR_FRUIT_WEBHOOK_HERE" or webhookUrl == "YOUR_STATUS_WEBHOOK_HERE" then return end
    
    local json = HttpService:JSONEncode(payload)
    local requestFunc = syn and syn.request or http_request or request or (http and http.request)
    
    if requestFunc then
        task.spawn(function()
            pcall(function()
                requestFunc({
                    Url = webhookUrl,
                    Method = "POST",
                    Headers = {
                        ["Content-Type"] = "application/json"
                    },
                    Body = json
                })
            end)
        end)
    end
end

local function SendFruitWebhook(toolName, isSuccess)
    local displayName = LocalPlayer.DisplayName or LocalPlayer.Name
    local userName    = LocalPlayer.Name
    local price       = FRUIT_PRICE[toolName] or 0
    local priceStr    = price > 0 and ("💰 " .. tostring(price):reverse():gsub("%d%d%d","%1,"):reverse():gsub("^,","") .. "$") or "Giá: Không rõ"
    
    local embed = {
        title = isSuccess and "🍎 TRÁI ÁC QUỶ MỚI ĐÃ ĐƯỢC CẤT!" or "⚠️ LỖI CẤT TRÁI ÁC QUỶ",
        color = isSuccess and 65407 or 16729088, -- Xanh lá (0x00FF7F) hoặc Đỏ (0xFF4500)
        fields = {
            { name = "👤 Người chơi", value = ("%s (@%s)"):format(displayName, userName), inline = true },
            { name = "🍎 Tên Trái", value = toolName, inline = true },
            { name = "💲 Giá trị", value = priceStr, inline = true },
            { name = "⚙️ Trạng thái", value = isSuccess and "✅ Đã cất vào rương thành công" or "❌ Lỗi cất trái (rương đầy hoặc lỗi game)", inline = false },
            { name = "🌐 Server JobID", value = ("`%s`"):format(game.JobId), inline = false }
        },
        timestamp = DateTime.now():ToIsoDate(),
        footer = { text = "Antigravity Smart Fruit Collector • 2026" }
    }
    
    SendWebhook(CFG.WEBHOOK_FRUIT, { embeds = { embed } })
end

local function SendStatusWebhook()
    local displayName = LocalPlayer.DisplayName or LocalPlayer.Name
    local userName    = LocalPlayer.Name
    
    -- Lấy danh sách 5 trái gần nhất đã cất
    local lastFruits = {}
    local startIdx = math.max(1, #storedLog - 4)
    for i = startIdx, #storedLog do
        table.insert(lastFruits, ("- %s (%s)"):format(storedLog[i].name, storedLog[i].time))
    end
    local listStr = #lastFruits > 0 and table.concat(lastFruits, "\n") or "*Chưa cất được trái nào trong phiên này*"

    local embed = {
        title = "⏳ THÔNG BÁO HOẠT ĐỘNG (PING)",
        color = 49151, -- Xanh dương (0x00BFFF)
        fields = {
            { name = "👤 Người chơi", value = ("%s (@%s)"):format(displayName, userName), inline = true },
            { name = "🟢 Trạng thái", value = "🟢 Đang chạy ổn định (Noclip Fly & Server Hop active)", inline = true },
            { name = "📦 Đã cất trong phiên", value = ("**%d trái**"):format(totalStored), inline = true },
            { name = "📋 Các trái vừa cất gần nhất", value = listStr, inline = false },
            { name = "🌐 Server JobID", value = ("`%s`"):format(game.JobId), inline = false }
        },
        timestamp = DateTime.now():ToIsoDate(),
        footer = { text = "Antigravity Smart Fruit Collector • 2026" }
    }
    
    SendWebhook(CFG.WEBHOOK_STATUS, { embeds = { embed } })
end

local logOrder = 0
local MSG_COLOR = {
    info    = Color3.fromRGB(160, 200, 255),
    success = Color3.fromRGB(80,  230, 80),
    warn    = Color3.fromRGB(255, 200, 50),
    error   = Color3.fromRGB(255, 80,  80),
    action  = Color3.fromRGB(0,   200, 255),
    fruit   = Color3.fromRGB(255, 120, 220),
    hop     = Color3.fromRGB(200, 140, 255),
    store   = Color3.fromRGB(80,  255, 180),
}

local function GetTimeStr()
    local success, result = pcall(function()
        return DateTime.now():FormatLocalTime("HH:mm:ss", "en-us")
    end)
    if success and result then
        return result
    end
    
    local success2, result2 = pcall(function()
        return os.date("%H:%M:%S")
    end)
    if success2 and result2 then
        return result2
    end
    
    local t = os.time()
    local th = math.floor(t / 3600) % 24
    local tm = math.floor(t / 60) % 60
    local ts = t % 60
    return string.format("%02d:%02d:%02d", th, tm, ts)
end

local function Log(msg, mtype, asStatus)
    mtype = mtype or "info"
    local color = MSG_COLOR[mtype] or MSG_COLOR.info
    if asStatus then
        StatusLbl.Text      = msg
        StatusLbl.TextColor3= color
    end
    logOrder = logOrder + 1
    local lbl = Instance.new("TextLabel", LogFrame)
    lbl.LayoutOrder          = logOrder
    lbl.Size                 = UDim2.new(1, 0, 0, 16)
    lbl.BackgroundTransparency = 1
    lbl.Text                 = GetTimeStr() .. "  " .. msg
    lbl.TextColor3           = color
    lbl.TextSize             = 11
    lbl.Font                 = Enum.Font.Gotham
    lbl.TextXAlignment       = Enum.TextXAlignment.Left
    lbl.TextWrapped          = true
    lbl.AutomaticSize        = Enum.AutomaticSize.Y
    task.defer(function()
        if LogFrame and LogFrame.Parent then
            local canvasHeight = LogFrame.AbsoluteCanvasSize.Y
            local frameHeight  = LogFrame.AbsoluteSize.Y
            if canvasHeight > frameHeight then
                LogFrame.CanvasPosition = Vector2.new(0, canvasHeight - frameHeight)
            else
                LogFrame.CanvasPosition = Vector2.new(0, 0)
            end
        end
    end)
    print("[SmartFruit] " .. msg)
    -- Giới hạn 60 dòng log
    local labels = {}
    for _, c in pairs(LogFrame:GetChildren()) do
        if c:IsA("TextLabel") then table.insert(labels, c) end
    end
    if #labels > 60 then
        table.sort(labels, function(a, b) return a.LayoutOrder < b.LayoutOrder end)
        labels[1]:Destroy()
    end
end

local function UpdateStoredLabel()
    StoredLbl.Text = ("📦 Đã cất: %d trái"):format(totalStored)
    if #storedLog > 0 then
        local lastEntry = storedLog[#storedLog]
        Log("📋 Vừa cất thành công: " .. lastEntry.name .. " lúc " .. lastEntry.time, "store")
    end
end

StopBtn.MouseButton1Click:Connect(function()
    _G.SmartFruitCollector = false
    if activeTween then activeTween:Cancel() end
    -- Xóa toàn bộ ESP
    for tool, esp in pairs(espObjects) do
        pcall(function()
            if esp.billboard and esp.billboard.Parent then esp.billboard:Destroy() end
            if esp.highlight and esp.highlight.Parent then esp.highlight:Destroy() end
            if esp.selbox    and esp.selbox.Parent    then esp.selbox:Destroy() end
        end)
    end
    espObjects = {}
    if EspGui then pcall(function() EspGui:Destroy() end) end
    Log("🛑 Script đã bị dừng bởi người dùng.", "error", true)
    StopBtn.Text = "▶️  ĐÃ DỪNG"
    StopBtn.BackgroundColor3 = Color3.fromRGB(60, 60, 80)
end)

-- ══════════════════════════════════════════════════════════════════
-- ▌ ESP FRUIT LIST PANEL (bên phải màn hình)
-- ══════════════════════════════════════════════════════════════════
local EspPanel = Instance.new("Frame", ScreenGui)
EspPanel.Name             = "EspPanel"
EspPanel.Size             = UDim2.new(0, 240, 0, 400)
EspPanel.Position         = UDim2.new(1, -254, 0, 14)
EspPanel.BackgroundColor3 = Color3.fromRGB(8, 8, 18)
EspPanel.BackgroundTransparency = 0.15
EspPanel.BorderSizePixel  = 0
EspPanel.Active           = true
EspPanel.Draggable        = true
Instance.new("UICorner", EspPanel).CornerRadius = UDim.new(0, 10)
local espStroke = Instance.new("UIStroke", EspPanel)
espStroke.Color     = Color3.fromRGB(255, 120, 30)
espStroke.Thickness = 1.5

local EspTitleBar = Instance.new("Frame", EspPanel)
EspTitleBar.Size              = UDim2.new(1, 0, 0, 32)
EspTitleBar.BackgroundColor3  = Color3.fromRGB(200, 80, 10)
EspTitleBar.BackgroundTransparency = 0.4
EspTitleBar.BorderSizePixel   = 0
Instance.new("UICorner", EspTitleBar).CornerRadius = UDim.new(0, 10)
local espTitleFix = Instance.new("Frame", EspTitleBar)
espTitleFix.Size             = UDim2.new(1, 0, 0, 12)
espTitleFix.Position         = UDim2.new(0, 0, 1, -12)
espTitleFix.BackgroundColor3 = Color3.fromRGB(200, 80, 10)
espTitleFix.BackgroundTransparency = 0.4
espTitleFix.BorderSizePixel  = 0

local EspTitleLbl = Instance.new("TextLabel", EspTitleBar)
EspTitleLbl.Size             = UDim2.new(1, -10, 1, 0)
EspTitleLbl.Position         = UDim2.new(0, 8, 0, 0)
EspTitleLbl.BackgroundTransparency = 1
EspTitleLbl.Text             = "📦  Stored Fruits Log"
EspTitleLbl.TextColor3       = Color3.fromRGB(255, 255, 255)
EspTitleLbl.TextSize         = 13
EspTitleLbl.Font             = Enum.Font.GothamBold
EspTitleLbl.TextXAlignment   = Enum.TextXAlignment.Left

local EspCount = Instance.new("TextLabel", EspPanel)
EspCount.Size             = UDim2.new(1, -10, 0, 18)
EspCount.Position         = UDim2.new(0, 8, 0, 34)
EspCount.BackgroundTransparency = 1
EspCount.Text             = "Chưa cất được trái nào"
EspCount.TextColor3       = Color3.fromRGB(180, 180, 180)
EspCount.TextSize         = 10
EspCount.Font             = Enum.Font.Gotham
EspCount.TextXAlignment   = Enum.TextXAlignment.Left

local EspListFrame = Instance.new("ScrollingFrame", EspPanel)
EspListFrame.Size              = UDim2.new(1, -10, 1, -58)
EspListFrame.Position          = UDim2.new(0, 5, 0, 54)
EspListFrame.BackgroundColor3  = Color3.fromRGB(5, 5, 12)
EspListFrame.BackgroundTransparency = 0.2
EspListFrame.BorderSizePixel   = 0
EspListFrame.ScrollBarThickness= 3
EspListFrame.ScrollBarImageColor3 = Color3.fromRGB(255, 120, 30)
EspListFrame.AutomaticCanvasSize = Enum.AutomaticSize.Y
EspListFrame.CanvasSize        = UDim2.new(0, 0, 0, 0)
Instance.new("UICorner", EspListFrame).CornerRadius = UDim.new(0, 6)
local espListLayout = Instance.new("UIListLayout", EspListFrame)
espListLayout.SortOrder = Enum.SortOrder.LayoutOrder
espListLayout.Padding   = UDim.new(0, 2)
local espListPad = Instance.new("UIPadding", EspListFrame)
espListPad.PaddingTop   = UDim.new(0, 4)
espListPad.PaddingLeft  = UDim.new(0, 4)
espListPad.PaddingRight = UDim.new(0, 4)

-- Hàm cập nhật panel danh sách đã cất (bên phải)
local function UpdateStoredPanel()
    -- Xóa các dòng cũ
    for _, child in pairs(EspListFrame:GetChildren()) do
        if child:IsA("Frame") or child:IsA("TextLabel") then
            child:Destroy()
        end
    end

    if #storedLog == 0 then
        EspCount.Text = "Chưa cất được trái nào"
        EspCount.TextColor3 = Color3.fromRGB(180, 180, 180)
        return
    end

    EspCount.Text = ("✅ Đã cất thành công %d trái:"):format(#storedLog)
    EspCount.TextColor3 = Color3.fromRGB(80, 230, 80)

    -- Duyệt ngược để hiển thị trái mới cất lên đầu
    for i = #storedLog, 1, -1 do
        local entry = storedLog[i]
        local row = Instance.new("Frame", EspListFrame)
        row.Name              = "Row_" .. i
        row.LayoutOrder       = -i -- Để đưa phần tử mới nhất lên đầu
        row.Size              = UDim2.new(1, 0, 0, 36)
        row.BackgroundColor3  = Color3.fromRGB(20, 20, 35)
        row.BackgroundTransparency = 0.3
        row.BorderSizePixel   = 0
        Instance.new("UICorner", row).CornerRadius = UDim.new(0, 6)

        -- Tên trái
        local nameLbl = Instance.new("TextLabel", row)
        nameLbl.Size             = UDim2.new(1, -90, 1, 0)
        nameLbl.Position         = UDim2.new(0, 10, 0, 0)
        nameLbl.BackgroundTransparency = 1
        nameLbl.Text             = "🍎  " .. entry.name
        nameLbl.TextColor3       = Color3.fromRGB(255, 255, 255)
        nameLbl.TextSize         = 11
        nameLbl.Font             = Enum.Font.GothamBold
        nameLbl.TextXAlignment   = Enum.TextXAlignment.Left
        nameLbl.TextTruncate     = Enum.TextTruncate.AtEnd

        -- Thời gian cất
        local timeLbl = Instance.new("TextLabel", row)
        timeLbl.Size             = UDim2.new(0, 80, 1, 0)
        timeLbl.Position         = UDim2.new(1, -90, 0, 0)
        timeLbl.BackgroundTransparency = 1
        timeLbl.Text             = entry.time
        timeLbl.TextColor3       = Color3.fromRGB(150, 150, 150)
        timeLbl.TextSize         = 10
        timeLbl.Font             = Enum.Font.Gotham
        timeLbl.TextXAlignment   = Enum.TextXAlignment.Right
    end
end

-- ══════════════════════════════════════════════════════════════════
-- ▌ HỆ THỐNG ESP 3D (BillboardGui + Highlight)
-- ══════════════════════════════════════════════════════════════════
local ESP_ELIGIBLE_COLOR   = Color3.fromRGB(0,  255, 120)  -- xanh lá = có thể nhặt
local ESP_ANON_COLOR       = Color3.fromRGB(255, 60, 200)  -- magenta = ẩn tên
local ESP_LEGENDARY_COLOR  = Color3.fromRGB(255, 210, 0)   -- vàng = legendary

local function GetEspColor(entry)
    if entry.isAnon                 then return ESP_ANON_COLOR
    elseif entry.price >= 3000000  then return ESP_LEGENDARY_COLOR
    elseif entry.price >= 1000000  then return Color3.fromRGB(80, 180, 255)
    else                                return ESP_ELIGIBLE_COLOR
    end
end

local function CreateESP(entry)
    local handle = entry.handle
    if not handle or not handle.Parent then return end
    if espObjects[entry.tool] then return end  -- đã có ESP

    local color = GetEspColor(entry)

    -- BillboardGui
    local bbg = Instance.new("BillboardGui")
    bbg.Name        = "SFC_ESP"
    bbg.Adornee     = handle
    bbg.Size        = UDim2.new(0, 180, 0, 60)
    bbg.StudsOffset = Vector3.new(0, 4.5, 0)
    bbg.AlwaysOnTop = true
    bbg.Parent      = EspGui -- Gán parent vào EspGui (dưới PlayerGui) để hiển thị 3D Billboard

    -- Background label
    local bg = Instance.new("Frame", bbg)
    bg.Size              = UDim2.new(1, 0, 1, 0)
    bg.BackgroundColor3  = Color3.fromRGB(0, 0, 0)
    bg.BackgroundTransparency = 0.45
    bg.BorderSizePixel   = 0
    Instance.new("UICorner", bg).CornerRadius = UDim.new(0, 6)
    local bgStroke = Instance.new("UIStroke", bg)
    bgStroke.Color     = color
    bgStroke.Thickness = 1.2

    -- Tên trái
    local nameLbl = Instance.new("TextLabel", bg)
    nameLbl.Size             = UDim2.new(1, -6, 0, 26)
    nameLbl.Position         = UDim2.new(0, 3, 0, 2)
    nameLbl.BackgroundTransparency = 1
    nameLbl.Text             = entry.isAnon and ("❓ " .. entry.name) or ("🍎 " .. entry.name)
    nameLbl.TextColor3       = color
    nameLbl.TextSize         = 13
    nameLbl.Font             = Enum.Font.GothamBold
    nameLbl.TextStrokeTransparency = 0.4
    nameLbl.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
    nameLbl.TextTruncate     = Enum.TextTruncate.AtEnd
    nameLbl.ZIndex           = 10

    -- Khoảng cách + giá
    local infoLbl = Instance.new("TextLabel", bg)
    infoLbl.Size             = UDim2.new(1, -6, 0, 20)
    infoLbl.Position         = UDim2.new(0, 3, 0, 30)
    infoLbl.BackgroundTransparency = 1
    infoLbl.TextColor3       = Color3.fromRGB(220, 220, 220)
    infoLbl.TextSize         = 11
    infoLbl.Font             = Enum.Font.Gotham
    infoLbl.TextStrokeTransparency = 0.5
    infoLbl.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
    infoLbl.ZIndex           = 10

    -- Highlight (neon glow xuyên tường - thử Highlight class trước)
    local hl
    local okHL, _ = pcall(function()
        hl = Instance.new("Highlight")
        hl.Name           = "SFC_Highlight"
        hl.Adornee        = entry.tool
        hl.FillColor      = color
        hl.FillTransparency = 0.55
        hl.OutlineColor   = color
        hl.OutlineTransparency = 0.15
        hl.DepthMode      = Enum.HighlightDepthMode.AlwaysOnTop
        hl.Parent         = EspGui -- Gán parent vào EspGui để an toàn
    end)

    if not okHL or not hl then
        -- Fallback sang SelectionBox nếu Executor quá cũ
        hl = Instance.new("SelectionBox")
        hl.Name           = "SFC_Highlight"
        hl.Adornee        = handle
        hl.Color3         = color
        hl.LineThickness  = 0.05
        hl.SurfaceColor3  = color
        hl.SurfaceTransparency = 0.85
        hl.Parent         = EspGui
    end

    -- Cập nhật khoảng cách real-time
    task.spawn(function()
        while handle and handle.Parent and espObjects[entry.tool] and _G.SmartFruitCollector do
            task.wait(0.3)
            pcall(function()
                local char = LocalPlayer.Character
                local hrp  = char and char:FindFirstChild("HumanoidRootPart")
                if hrp and handle.Parent then
                    local dist = math.floor((hrp.Position - handle.Position).Magnitude)
                    local priceStr = entry.isAnon and "???" or tostring(entry.price)
                    infoLbl.Text = ("📍 %d studs  💰 %s"):format(dist, priceStr)
                end
            end)
        end
    end)

    espObjects[entry.tool] = {
        billboard = bbg,
        highlight = hl,
    }
end

local function RemoveESP(tool)
    local esp = espObjects[tool]
    if not esp then return end
    pcall(function()
        if esp.billboard and esp.billboard.Parent then esp.billboard:Destroy() end
        if esp.highlight  and esp.highlight.Parent  then esp.highlight:Destroy() end
    end)
    espObjects[tool] = nil
end

-- Vòng lặp nền: cập nhật ESP + panel mỗi 0.5s
task.spawn(function()
    while _G.SmartFruitCollector do
        task.wait(0.5)
        pcall(function()
            -- Xóa ESP của các tool đã biến mất khỏi Workspace
            for tool, esp in pairs(espObjects) do
                if not tool or not tool.Parent or tool.Parent ~= workspace then
                    RemoveESP(tool)
                end
            end

            -- Quét và tạo ESP cho các trái hiện tại trên Workspace
            local fruits = {}
            if typeof(ScanFruitsInServer) == "function" then
                fruits = ScanFruitsInServer()
            end

            for _, entry in ipairs(fruits) do
                if entry.handle and entry.handle.Parent then
                    if not espObjects[entry.tool] then
                        CreateESP(entry)
                    end
                end
            end
        end)
    end
end)

-- ══════════════════════════════════════════════════════════════════
-- ▌ NOCLIP BLOCK (để bay xuyên tường)
-- ══════════════════════════════════════════════════════════════════
local flyBlock = Instance.new("Part")
flyBlock.Size        = Vector3.new(1, 1, 1)
flyBlock.Name        = "SFC_FlyBlock"
flyBlock.Anchored    = true
flyBlock.CanCollide  = false
flyBlock.CanTouch    = false
flyBlock.Transparency= 1
flyBlock.Parent      = workspace

-- Noclip + sync HRP → block (tối ưu hóa loại bỏ check dist để tránh kẹt đứng im)
task.spawn(function()
    while _G.SmartFruitCollector do
        task.wait()
        pcall(function()
            local char = LocalPlayer.Character
            if not char then return end
            local hrp = char:FindFirstChild("HumanoidRootPart")
            if isFlying then
                if hrp then
                    hrp.CFrame = flyBlock.CFrame
                end
                for _, p in pairs(char:GetDescendants()) do
                    if p:IsA("BasePart") then p.CanCollide = false end
                end
            else
                for _, p in pairs(char:GetDescendants()) do
                    if p:IsA("BasePart") then p.CanCollide = true end
                end
            end
        end)
    end
end)

-- Luồng Watchdog giám sát chống kẹt khi bay (tự động khôi phục nếu đứng im quá 2s)
task.spawn(function()
    local lastPos = nil
    local stuckTicks = 0
    while _G.SmartFruitCollector do
        task.wait(1)
        pcall(function()
            if isFlying then
                local char = LocalPlayer.Character
                local hrp = char and char:FindFirstChild("HumanoidRootPart")
                if hrp then
                    local currentPos = hrp.Position
                    if lastPos and (currentPos - lastPos).Magnitude < 1.5 then
                        stuckTicks = stuckTicks + 1
                        if stuckTicks >= 2 then
                            Log("⚠️ Phát hiện kẹt đứng im khi bay! Đang giải kẹt...", "warn")
                            stuckTicks = 0
                            if activeTween then
                                pcall(function() activeTween:Cancel() end)
                                activeTween = nil
                            end
                            flyBlock.CFrame = hrp.CFrame
                            isFlying = false
                        end
                    else
                        stuckTicks = 0
                    end
                    lastPos = currentPos
                end
            else
                lastPos = nil
                stuckTicks = 0
            end
        end)
    end
end)

-- ══════════════════════════════════════════════════════════════════
-- ▌ HÀM BAY ĐẾN VỊ TRÍ (Tween qua flyBlock) – tốc độ cố định 250
-- ══════════════════════════════════════════════════════════════════
local FLY_SPEED_FIXED = 250  -- luôn cố định, không phụ thuộc CFG

local function FlyTo(targetCFrame)
    local char = LocalPlayer.Character
    local hrp  = char and char:FindFirstChild("HumanoidRootPart")
    if not hrp then return end

    flyBlock.CFrame = hrp.CFrame
    local dist = (targetCFrame.Position - hrp.Position).Magnitude
    local t    = math.max(dist / FLY_SPEED_FIXED, 0.08)

    activeTween = TweenService:Create(flyBlock, TweenInfo.new(t, Enum.EasingStyle.Linear), {CFrame = targetCFrame})
    activeTween:Play()
    activeTween.Completed:Wait()
    activeTween = nil
end

-- ══════════════════════════════════════════════════════════════════
-- ▌ HÀM CHỌN PHE
-- ══════════════════════════════════════════════════════════════════
local function SelectTeam()
    -- Kiểm tra đã có character chưa (= đã chọn phe)
    if LocalPlayer.Character and
       LocalPlayer.Character:FindFirstChild("HumanoidRootPart") and
       LocalPlayer.Team and
       LocalPlayer.Team.Name ~= "" and
       LocalPlayer.Team.Name ~= "Neutral" then
        Log("✅ Đã ở trong phe: " .. LocalPlayer.Team.Name, "success")
        return
    end

    Log("⚙️ Chưa chọn phe. Đang chọn: " .. CFG.TEAM .. "...", "action", true)

    for i = 1, 15 do
        if not _G.SmartFruitCollector then return end
        pcall(function()
            CommF:InvokeServer("SetTeam", CFG.TEAM)
        end)
        task.wait(0.3)
        if LocalPlayer.Team and
           LocalPlayer.Team.Name ~= "" and
           LocalPlayer.Team.Name ~= "Neutral" then
            Log("✅ Đã chọn phe: " .. LocalPlayer.Team.Name, "success", true)
            return
        end
    end
    Log("⚠️ Chọn phe thất bại – tiếp tục anyway...", "warn", true)
end

-- ══════════════════════════════════════════════════════════════════
-- ▌ HÀM LẤY DANH SÁCH TRÁI TRONG RƯƠNG (SERVER)
-- ══════════════════════════════════════════════════════════════════
-- Trả về: { ["Dragon Fruit"] = 2, ["Nika Fruit"] = 1, ... }
-- ══════════════════════════════════════════════════════════════════
-- ▌ HÀM CHUẨN HÓA TÊN TRÁI ÁC QUỶ (Đồng bộ Rương, Túi & Map)
-- ══════════════════════════════════════════════════════════════════
local function GetStorageKey(rawName)
    local name = tostring(rawName or "")
    
    -- Lấy phần sau dấu hai chấm (nếu có, ví dụ "Human-Human: Buddha" -> "Buddha")
    if string.find(name, ":") then
        local split = string.split(name, ":")
        name = split[#split]
    end
    
    -- Lấy phần trước dấu gạch ngang (nếu có, ví dụ "Dragon-Dragon" -> "Dragon")
    if string.find(name, "-") then
        local split = string.split(name, "-")
        name = split[1]
    end
    
    -- Loại bỏ khoảng trắng thừa ở hai đầu
    name = string.gsub(name, "^%s*(.-)%s*$", "%1")
    
    -- Map đồng bộ các tên khác biệt
    if name == "Door" then name = "Portal" end
    if name == "Soul" then name = "Spirit" end
    if name == "Falcon" then name = "Eagle" end -- Rework 2026
    
    -- Loại bỏ chữ "Fruit" (nếu có) để chuẩn hóa về đuôi duy nhất
    name = string.gsub(name, "%s*Fruit$", "")
    
    return name .. " Fruit"
end

-- ══════════════════════════════════════════════════════════════════
-- ▌ HÀM LẤY DANH SÁCH TRÁI TRONG RƯƠNG (SERVER)
-- ══════════════════════════════════════════════════════════════════
-- Trả về: { ["Dragon Fruit"] = 2, ["Buddha Fruit"] = 1, ... } và tổng số trái
local function GetStoredFruitCount()
    local counts = {}
    local total = 0
    local ok, inv = pcall(function()
        return CommF:InvokeServer("getInventoryFruits")
    end)
    if ok and type(inv) == "table" then
        for _, item in pairs(inv) do
            local raw = tostring(item.Name or "")
            local key = GetStorageKey(raw)
            counts[key] = (counts[key] or 0) + 1
            total = total + 1
        end
    end
    return counts, total
end

-- ══════════════════════════════════════════════════════════════════
-- ▌ HÀM QUÉT TRÁI TRÊN MAP
--   Trả về danh sách {tool=..., name=..., pos=..., price=..., hasName=...}
--   Sắp xếp theo ưu tiên: không tên > giá cao > giá thấp
-- ══════════════════════════════════════════════════════════════════
local function ScanFruitsInServer()
    local found = {}
    for _, obj in pairs(workspace:GetChildren()) do
        pcall(function()
            if not obj or not obj.Parent then return end
            local handle = obj:FindFirstChild("Handle")
            if not handle then return end

            -- Phân loại: Tool có "Fruit" trong tên = trái rõ tên
            -- Tool không có "Fruit" trong tên = trái ẩn/không rõ tên
            local isTool   = obj:IsA("Tool")
            local hasFruit = string.find(obj.Name, "Fruit", 1, true) ~= nil
            local isAnon   = isTool and not hasFruit -- không tên = anonymous

            if isTool or hasFruit then
                local price   = FRUIT_PRICE[obj.Name] or 0
                local priority = isAnon and math.huge or price
                table.insert(found, {
                    tool     = obj,
                    name     = obj.Name,
                    handle   = handle,
                    pos      = handle.Position,
                    price    = price,
                    isAnon   = isAnon,
                    priority = priority,
                })
            end
        end)
    end

    -- Sort: anonymous (math.huge) → giá cao → giá thấp
    table.sort(found, function(a, b)
        return a.priority > b.priority
    end)
    return found
end

-- ══════════════════════════════════════════════════════════════════
-- ▌ HÀM KIỂM TRA TRÁI CÓ CẦN NHẶT KHÔNG
--   - Trái không tên: luôn nhặt
--   - Trái có tên: kiểm tra kho, nếu >= MAX_CAP → bỏ qua
-- ══════════════════════════════════════════════════════════════════
local function ShouldPickup(fruitEntry, storedCounts, totalInStorage)
    return true
end

-- ══════════════════════════════════════════════════════════════════
-- ▌ HÀM NHẶT + CẤT TRÁI
-- ══════════════════════════════════════════════════════════════════
local function PickAndStore(fruitEntry)
    local fruit  = fruitEntry.tool
    local handle = fruitEntry.handle
    if not fruit or not fruit.Parent then return false end

    Log(("🍎 Đang bay đến: [%s] (giá: %s)"):format(
        fruitEntry.name,
        fruitEntry.isAnon and "???" or tostring(fruitEntry.price)
    ), "fruit", true)

    -- Bay thẳng sát vào trái
    isFlying = true
    FlyTo(handle.CFrame)

    if not _G.SmartFruitCollector then isFlying = false return false end
    if not fruit.Parent then
        Log("⚠️ Trái biến mất khi đang tiếp cận!", "warn", true)
        isFlying = false return false
    end

    -- Đứng vào đúng vị trí trái để nhặt (chờ tối đa 0.3 giây hoặc khi trái biến mất)
    local char = LocalPlayer.Character
    local hrp  = char and char:FindFirstChild("HumanoidRootPart")
    if hrp and handle and handle.Parent then
        local startTick = tick()
        while fruit.Parent == workspace and (tick() - startTick) < 0.3 do
            if not _G.SmartFruitCollector then break end
            hrp.CFrame   = handle.CFrame
            flyBlock.CFrame = handle.CFrame
            task.wait(0.02)
        end
    end

    isFlying = false
    
    if fruit.Parent ~= workspace then
        Log("✅ Đã nhặt thành công: " .. fruitEntry.name, "success")
        return true
    else
        Log("⚠️ Không nhặt được trái (timeout).", "warn")
        return false
    end
end

-- ══════════════════════════════════════════════════════════════════
-- ▌ LUỒNG TỰ ĐỘNG CẤT TRÁI CHẠY NGẦM (DAEMON AUTO-STORE)
--   Chạy song song liên tục, phát hiện là unequip & cất tức thời
-- ══════════════════════════════════════════════════════════════════
task.spawn(function()
    local lastStoreCall = 0
    local STORE_COOLDOWN = 0.3 -- Khoảng cách an toàn giữa các lần gọi store

    while _G.SmartFruitCollector do
        task.wait(0.05)
        pcall(function()
            if (tick() - lastStoreCall) < STORE_COOLDOWN then return end

            local character = LocalPlayer.Character
            local backpack  = LocalPlayer:FindFirstChild("Backpack")
            if not character then return end

            -- Tìm trái trong túi hoặc trên tay
            local targetTool = nil
            local inCharacter = false

            -- Quét trong Backpack trước
            if backpack then
                for _, tool in pairs(backpack:GetChildren()) do
                    if tool:IsA("Tool") and FRUIT_MAP[tool.Name] then
                        targetTool = tool
                        break
                    end
                end
            end

            -- Quét trong Character (đang cầm trên tay)
            if not targetTool then
                for _, tool in pairs(character:GetChildren()) do
                    if tool:IsA("Tool") and FRUIT_MAP[tool.Name] then
                        targetTool = tool
                        inCharacter = true
                        break
                    end
                end
            end

            if targetTool then
                local toolName  = targetTool.Name
                local storeCode = FRUIT_MAP[toolName]
                lastStoreCall   = tick()

                -- Nếu đang cầm trên tay → Unequip lập tức
                if inCharacter then
                    local humanoid = character:FindFirstChildOfClass("Humanoid")
                    if humanoid then
                        Log("🔄 Gỡ [" .. toolName .. "] về Backpack...", "action")
                        humanoid:UnequipTools()
                        task.wait(0.12) -- Đợi tool chuyển sang Backpack
                    end
                end

                -- Lấy lại tool reference từ Backpack
                local bp = LocalPlayer:FindFirstChild("Backpack")
                local toolRef = bp and bp:FindFirstChild(toolName)

                Log("📦 Đang cất ngay lập tức: [" .. toolName .. "]...", "action", true)

                task.spawn(function()
                    local stored = false
                    for attempt = 1, CFG.STORE_RETRIES do
                        local ok, res = pcall(function()
                            if storeCode and toolRef then
                                return CommF:InvokeServer("StoreFruit", storeCode, toolRef)
                            elseif storeCode then
                                return CommF:InvokeServer("StoreFruit", storeCode)
                            else
                                return CommF:InvokeServer("StoreFruit", toolName, toolRef)
                            end
                        end)
                        if ok and res ~= false then
                            stored = true
                            break
                        end
                        task.wait(0.25)
                    end

                    if stored then
                        totalStored = totalStored + 1
                        table.insert(storedLog, {name = toolName, time = GetTimeStr()})
                        Log("✅ ĐÃ CẤT: [" .. toolName .. "]! (Tổng: " .. totalStored .. ")", "store", true)
                        UpdateStoredLabel()
                        pcall(UpdateStoredPanel) -- Cập nhật panel hiển thị bên phải
                        pcall(function() SendFruitWebhook(toolName, true) end) -- Gửi webhook thành công
                    else
                        Log("❌ Lỗi cất trái: " .. toolName, "error", true)
                        pcall(function() SendFruitWebhook(toolName, false) end) -- Gửi webhook thất bại
                    end
                end)
            end
        end)
    end
end)

-- ══════════════════════════════════════════════════════════════════
-- ▌ HÀM SERVER HOP (ưu tiên server ~11 người, nhiều người có thể join)
-- ══════════════════════════════════════════════════════════════════
local CurrentPlaceId = game.PlaceId

local function ServerHop()
    Log("🔄 Đang tìm server (~11 người)...", "hop", true)

    local function fetchServers(cursor, sortOrder)
        local url = ("https://games.roblox.com/v1/games/%d/servers/Public?sortOrder=%s&limit=100"):format(
            CurrentPlaceId, sortOrder or "Desc"
        )
        if cursor then url = url .. "&cursor=" .. cursor end
        local ok, raw = pcall(function() return game:HttpGet(url) end)
        if ok and raw then
            local decoded = pcall(function() return HttpService:JSONDecode(raw) end)
            if not decoded then
                return HttpService:JSONDecode(raw)
            end
        end
        return nil
    end

    -- Lấy danh sách server
    local allCandidates = {}
    for _, sortMode in ipairs({"Desc", "Asc"}) do
        local cursor = nil
        for page = 1, 4 do
            local ok, raw = pcall(function()
                local url = ("https://games.roblox.com/v1/games/%d/servers/Public?sortOrder=%s&limit=100"):format(
                    CurrentPlaceId, sortMode)
                if cursor then url = url .. "&cursor=" .. cursor end
                return game:HttpGet(url)
            end)
            if not ok or not raw then break end
            local data
            pcall(function() data = HttpService:JSONDecode(raw) end)
            if not data or not data.data then break end

            for _, sv in pairs(data.data) do
                local playing   = tonumber(sv.playing) or 0
                local maxP      = tonumber(sv.maxPlayers) or 1
                -- Chỉ lấy server: khác server hiện tại, chưa full, còn chỗ vào
                if sv.id ~= game.JobId and playing < maxP and playing >= 1 then
                    table.insert(allCandidates, {
                        id      = sv.id,
                        playing = playing,
                        maxP    = maxP,
                    })
                end
            end
            cursor = data.nextPageCursor
            if not cursor then break end
            task.wait(0.2)
        end
        if #allCandidates > 0 then break end
    end

    if #allCandidates == 0 then
        Log("⚠️ Không tìm thấy server phù hợp! Teleport ngẫu nhiên...", "error", true)
        pcall(function() TeleportService:Teleport(CurrentPlaceId, LocalPlayer) end)
        return
    end

    -- Sort: server gần 11 người nhất lên đầu
    local TARGET = CFG.HOP_TARGET_PLAYERS
    table.sort(allCandidates, function(a, b)
        return math.abs(a.playing - TARGET) < math.abs(b.playing - TARGET)
    end)

    -- Thử teleport theo thứ tự, retry nếu thất bại
    for _, sv in ipairs(allCandidates) do
        if not _G.SmartFruitCollector then return end
        Log(("✈️ Teleport → server %d/%d người..."):format(sv.playing, sv.maxP), "hop", true)

        -- Thử qua __ServerBrowser trước
        local ok1 = false
        pcall(function()
            local sb = ReplicatedStorage:FindFirstChild("__ServerBrowser")
            if sb then
                sb:InvokeServer("teleport", sv.id)
                ok1 = true
            end
        end)

        task.wait(5)

        -- Kiểm tra đã đổi server chưa
        if game.JobId ~= sv.id then
            -- Fallback bằng TeleportService
            Log("🔁 Chưa đổi server. Thử TeleportService...", "warn")
            pcall(function()
                TeleportService:TeleportToPlaceInstance(CurrentPlaceId, sv.id, LocalPlayer)
            end)
            task.wait(8)
        end

        if game.JobId == sv.id then
            Log("✅ Đã vào server mới!", "success", true)
            return
        end
        Log("⚠️ Server hop thất bại, thử server khác...", "warn")
        task.wait(1)
    end

    Log("❌ Không hop được. Thử Teleport thẳng...", "error")
    pcall(function() TeleportService:Teleport(CurrentPlaceId, LocalPlayer) end)
end

-- ══════════════════════════════════════════════════════════════════
-- ▌ ANTI-AFK
-- ══════════════════════════════════════════════════════════════════
task.spawn(function()
    while _G.SmartFruitCollector do
        task.wait(55)
        pcall(function()
            VirtualUser:CaptureController()
            VirtualUser:ClickButton2(Vector2.new())
        end)
    end
end)

-- ══════════════════════════════════════════════════════════════════
-- ▌ VÒNG LẶP CHÍNH
-- ══════════════════════════════════════════════════════════════════
local function WaitForCharacter()
    local elapsed = 0
    while elapsed < 15 do
        if not _G.SmartFruitCollector then return nil end
        local char = LocalPlayer.Character
        if char and char:FindFirstChild("HumanoidRootPart") and char:FindFirstChild("Humanoid") then
            task.wait(0.5)
            return char
        end
        task.wait(0.3)
        elapsed = elapsed + 0.3
    end
    return LocalPlayer.Character
end

local function WaitForCommF()
    local elapsed = 0
    while not CommF and elapsed < 15 do
        if not _G.SmartFruitCollector then return false end
        task.wait(0.5)
        elapsed = elapsed + 0.5
    end
    return CommF ~= nil
end

local function HasFruitOnSelf()
    local char = LocalPlayer.Character
    local backpack = LocalPlayer:FindFirstChild("Backpack")
    if backpack then
        for _, t in pairs(backpack:GetChildren()) do
            if t:IsA("Tool") and FRUIT_MAP[t.Name] then
                return true, t.Name
            end
        end
    end
    if char then
        for _, t in pairs(char:GetChildren()) do
            if t:IsA("Tool") and FRUIT_MAP[t.Name] then
                return true, t.Name
            end
        end
    end
    return false
end

local function MainLoop()
    Log("🚀 Smart Fruit Collector đã khởi động!", "success", true)
    Log(("⚙️  MAX CAP: %d  |  Phe: %s  |  Tốc độ: %d"):format(
        CFG.MAX_CAP, CFG.TEAM, CFG.FLY_SPEED), "info")

    Log("🔌 Đớng kốt nối game server remotes...", "info", true)
    if not WaitForCommF() then
        Log("❌ Lỗi: Không kốt nối được Remotes (CommF_). Vui lòng thử lại khi game đã load xong hoàn toàn!", "error", true)
        return
    end
    Log("✅ Kốt nối Remotes thành công!", "success")

    -- Bước 1: Chọn phe ngay lửp tức
    SelectTeam()
    task.wait(0.5)

    -- Bước 2: Đợi character spawn
    Log("⌛ Đớng đợi character spawn...", "info", true)
    local char = WaitForCharacter()
    if not char then
        Log("❌ Không thể tải character. Thử lại...", "error", true)
        return
    end
    Log("✅ Character đã load xong!", "success")
    task.wait(1)

    while _G.SmartFruitCollector do
        -- Kiểm tra xem người chơi có đang giữ trái ác quỷ trên người (trong Backpack/Character) chưa cốt hay không
        local hasFruit, fruitName = HasFruitOnSelf()
        if hasFruit then
            Log(("🍒 Đớng giữ [%s] trên người. Chờ cốt..."):format(fruitName), "warn", true)
            task.wait(1)
        else
            -- Đảm bảo character hợp lệ trước khi tiếp tục (kiểm tra nhanh tránh delay)
            local checkChar = LocalPlayer.Character
            local checkHrp  = checkChar and checkChar:FindFirstChild("HumanoidRootPart")
            if not checkHrp then
                char = WaitForCharacter()
            else
                char = checkChar
            end

            if not char then
                Log("⌛ Character không hợp lệ, đợi thêm...", "warn")
                task.wait(1)
            else
                -- Quét trái trên map
                Log("🔍 Đớng quét trái trong server...", "action", true)
                local fruits = ScanFruitsInServer()

                if #fruits == 0 then
                    Log("❌ Không có trái nào trong server → HOP SERVER!", "hop", true)
                    task.wait(1)
                    ServerHop()
                    task.wait(8)
                else
                    Log(("🍎 Tìm thấy %d trái trên map! Đớng nhặt..."):format(#fruits), "fruit")

                    -- Xử lý từng trái theo ưu tiên
                    for _, fruitEntry in ipairs(fruits) do
                        if not _G.SmartFruitCollector then break end

                        Log(("🔎 Tiỿp cận: [%s] | Giá: %s | Ưu tiên: %s"):format(
                            fruitEntry.name,
                            fruitEntry.isAnon and "???" or tostring(fruitEntry.price),
                            fruitEntry.isAnon and "CAO NHẤT" or tostring(fruitEntry.priority)
                        ), "info")

                        -- Kiểm tra trái còn tồn tại không
                        if fruitEntry.tool.Parent ~= workspace then
                            Log("⚠️ Trái [" .. fruitEntry.name .. "] đã biến mất.", "warn")
                        else
                            local ok = PickAndStore(fruitEntry)
                            if ok then
                                task.wait(0.5)
                            end
                        end
                    end

                    -- Quét lại sau khi nhặt xong
                    task.wait(0.5)
                    local fruitsLeft = ScanFruitsInServer()
                    if #fruitsLeft == 0 then
                        Log("✅ Đã nhặt sạch trái trên map → HOP SERVER!", "hop", true)
                        task.wait(1)
                        ServerHop()
                        task.wait(8)
                    else
                        Log(("🔄 Còn %d trái trên map. Tiếp tục nhặt..."):format(#fruitsLeft), "info", true)
                        task.wait(0.2)
                    end
                end
            end
        end
    end

    Log("🚑 Script đã dừng.", "error", true)
end

-- ══════════════════════════════════════════════════════════════════
-- ▌ KHỞI CHẠY
-- ══════════════════════════════════════════════════════════════════
task.spawn(MainLoop)

-- Luồng ngầm gửi Webhook báo trạng thái hoạt động định kỳ (mỗi 5 phút)
task.spawn(function()
    task.wait(20) -- Đợi 20s đầu để game load ổn định trước ping đầu tiên
    if _G.SmartFruitCollector then
        pcall(SendStatusWebhook)
    end
    while _G.SmartFruitCollector do
        task.wait(300) -- 5 phút
        if _G.SmartFruitCollector then
            pcall(SendStatusWebhook)
        end
    end
end)
