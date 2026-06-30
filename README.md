🍎 Blox Fruit - Auto Fruit Sniper
Scan → Fly → Grab → Store (3 retries) → Hop
Tự động tìm, nhặt, lưu trữ trái ác quỷ và chuyển server trong Blox Fruits.

⚠️ Disclaimer: Script này chỉ dành cho mục đích học tập. Sử dụng ở rủi ro của bạn.

🚀 Tính năng
🔍 Scan fruit – quét toàn bộ workspace để tìm trái gần nhất.

✈️ Fly – dùng TweenService để bay tới trái.

🤚 Grab – nhặt trái tự động.

📦 Store – lưu trữ trái với 3 lần thử (có thể cấu hình).

🌀 Server Hop – nếu không có trái hoặc đã lưu trữ thành công, script sẽ tự động tìm và chuyển server khác.

🛡️ Anti‑AFK – tránh bị kick do không hoạt động.

🚫 No‑Clip – xuyên tường để bay không bị cản.

👁️ ESP – hiển thị vị trí trái trên map.

🤖 Auto Team – tự chọn team (Marines / Pirates) khi vào game.

💬 Discord Webhook – gửi thông báo khi lưu trữ trái thành công.

📦 Cài đặt
Chạy script bằng loadstring (từ GitHub của bạn):

lua
loadstring(game:HttpGet("https://raw.githubusercontent.com/ntcong01012000-sudo/y/refs/heads/main/AutoFindFruitAndHopServer.lua"))()
Để tùy chỉnh, bạn có thể set các biến cấu hình trước khi load:

lua
-- Ví dụ cấu hình
getgenv().Team = 1                      -- 0 = Marines, 1 = Pirates
getgenv().DiscordWebhook = "https://discord.com/api/webhooks/..."   -- URL webhook
getgenv().TweenSpeed = 400              -- tốc độ bay (studs/giây)
getgenv().StoreRetries = 5              -- số lần thử lưu trữ

loadstring(game:HttpGet("https://raw.githubusercontent.com/ntcong01012000-sudo/y/refs/heads/main/AutoFindFruitAndHopServer.lua"))()
⚙️ Cấu hình
Tất cả các biến cấu hình được khai báo trong getgenv() và có thể thiết lập trước khi load script.

Biến	Kiểu	Mặc định	Mô tả
AutoFruitSniper	boolean	true	Bật/tắt toàn bộ script.
FruitESP	boolean	true	Bật/tắt ESP cho trái.
TweenSpeed	number	300	Tốc độ bay (studs/giây).
StoreRetries	number	3	Số lần thử lưu trữ trái tối đa.
HopDelay	number	3	Thời gian (giây) chờ trước khi hop server.
ScanInterval	number	0.5	Khoảng thời gian giữa các lần quét (giây).
AntiAFK	boolean	true	Bật/tắt chống AFK.
AutoSelectTeam	boolean	true	Bật/tắt tự chọn team.
Team	number	0	0 = Marines, 1 = Pirates.
TeamSelectDelay	number	12	Thời gian (giây) chờ trước khi chọn team.
DiscordWebhook	string	""	URL Discord Webhook (để trống nếu không dùng).
💬 Discord Webhook
Khi một trái được lưu trữ thành công, script sẽ gửi một embed tới webhook với thông tin:

Tên người chơi

Tên trái

ID Place và Job ID của server

Cách cấu hình:

lua
getgenv().DiscordWebhook = "https://discord.com/api/webhooks/1234567890/abcdef"
📝 Ví dụ đầy đủ
lua
-- Cấu hình trước khi chạy
getgenv().Team = 1                      -- Chọn Pirates
getgenv().DiscordWebhook = "https://discord.com/api/webhooks/..."
getgenv().TweenSpeed = 450
getgenv().StoreRetries = 5
getgenv().HopDelay = 2

-- Tải và chạy script
loadstring(game:HttpGet("https://raw.githubusercontent.com/ntcong01012000-sudo/y/refs/heads/main/AutoFindFruitAndHopServer.lua"))()
🖥️ GUI
Script tạo một giao diện đồ họa (GUI) nhỏ ở góc trên bên trái:

Hiển thị trạng thái hiện tại (status)

Log các hành động (có màu sắc phân loại)

Tự động cuộn xuống dòng mới nhất

⚠️ Lưu ý
Script yêu cầu executor hỗ trợ các hàm như getconnections, queue_on_teleport, task.wait, pcall.

Nếu remote SetTeam không thành công, script sẽ thử click vào nút GUI (fallback).

Nếu không thiết lập DiscordWebhook, webhook sẽ bị tắt.

Các biến cấu hình có thể thay đổi trước khi load để ảnh hưởng đến toàn bộ quá trình.

Khi hop server, script sẽ cố gắng dùng native __ServerBrowser của game; nếu thất bại, sẽ dùng TeleportService.

📄 License
Script này được chia sẻ với mục đích học tập.

