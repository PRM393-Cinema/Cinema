# Demo CosmoQ Cinema

Chuẩn bị máy và kịch bản demo khoảng 15 phút: khách đặt vé và thanh toán, khách yêu cầu hoàn tiền, nhân viên xử lý hoàn tiền, admin quản lý tài khoản, bản web.

## 1. Chuẩn bị (trước buổi demo)

1. Lấy code mới của cả hai repo (`Project-Cinema-DB` nằm cạnh thư mục `Cinema`):

   ```powershell
   cd Cinema; git checkout dev; git pull
   cd ..\Project-Cinema-DB; git pull
   ```

2. Mở Docker Desktop. Trong thư mục `Cinema\Cinema_BE` (cần file `.env`, xem [DOCKER.md](Cinema_BE/docs/DOCKER.md)):

   ```powershell
   docker compose --profile monitoring up -d --build
   ```

   - DB tạo mới: lịch chiếu một tháng được nạp tự động.
   - DB đang dùng, hoặc lịch chiếu đã hết: chạy hai lệnh ở mục **Lịch chiếu demo một tháng** trong [DOCKER.md](Cinema_BE/docs/DOCKER.md). Chạy lại nhiều lần vẫn an toàn.

3. Kiểm tra `http://localhost:5000/health/services`: cả ba cụm phải `Healthy`.

4. Chạy app trong thư mục `Cinema\Cinema_Mobile`:

   | Thiết bị | Lệnh |
   |---|---|
   | Trình duyệt | `flutter run -d chrome` |
   | Android emulator | `flutter run` (app gọi `http://10.0.2.2:5000`) |
   | Điện thoại thật cùng wifi | `flutter run --dart-define=API_BASE_URL=http://<IP máy>:5000` |

## 2. Tài khoản

| Vai trò | Email | Mật khẩu |
|---|---|---|
| Admin | `admin@cinema.com` | `123456` |
| Nhân viên | `nhanvien1@cinema.com` | `123456` |
| Khách | `khachhang1@gmail.com` | `123456` |

> Khi `.env` có cấu hình SMTP, email OTP, vé và hoàn tiền được gửi thật tới email của tài khoản. Trước buổi demo, đăng nhập Admin → **Accounts** → tạo một tài khoản khách bằng email của nhóm (tài khoản do Admin tạo dùng được ngay, không cần OTP) rồi dùng tài khoản đó để demo.

## 3. Kịch bản demo

### A. Khách đặt vé (khoảng 5 phút)

1. Trang chủ: danh sách phim đang chiếu, ô tìm kiếm.
2. Mở một phim: suất chiếu 7 ngày tới, kèm phòng và giá. Chọn suất → **Continue to Seats**. Nếu chưa đăng nhập, app mở màn đăng nhập rồi quay lại đúng bước này.
3. Chọn ghế (thường, VIP, sweetbox; ghế đã có người đặt không chọn được) → **Continue** → **Confirm Booking**. Vé chờ thanh toán và giữ ghế 10 phút.
4. **Pay with PayOS** mở trang thanh toán PayOS thật. Không cần trả tiền: trong thư mục `Cinema\Cinema_BE`, giả lập PayOS báo đã nhận tiền:

   ```powershell
   .\scripts\payos-webhook.ps1 -OrderCode <id vé> -Amount <tổng tiền>
   ```

   Id vé là số trong địa chỉ trang thanh toán trên bản web (`#/bookings/<id>/payment`). Vài giây sau app tự chuyển sang **Payment successful** và email vé được gửi.
5. Tab **Tickets**: vé nằm trong **Active**, mở xem chi tiết.

### B. Hoàn tiền (khoảng 3 phút)

1. Khách mở vé đã thanh toán (suất chiếu còn hơn 2 giờ) → **Cancel booking** → gửi yêu cầu hoàn tiền. Vé chuyển sang **Refund pending**, ghế vẫn được giữ trong lúc chờ.
2. Đăng nhập nhân viên → **Operations** → **Refunds** → mở yêu cầu:
   - **Complete refund** kèm mã giao dịch chuyển khoản: vé bị huỷ, ghế được nhả.
   - Hoặc từ chối kèm lý do: vé trở lại hiệu lực. Chỉ từ chối được yêu cầu do khách gửi; vé do rạp huỷ thì bắt buộc hoàn tiền.
3. Khách xem kết quả ở chi tiết vé và trong email.

### C. Admin (khoảng 3 phút)

1. Đăng nhập Admin → **Dashboard** (thống kê tài khoản) → **Accounts**: tìm kiếm, lọc, xem chi tiết, tạo tài khoản, gán quyền.
2. Khách đang đăng nhập trên một thiết bị khác. Admin chọn **Lock account** → ở thao tác tiếp theo, app của khách báo tài khoản bị khoá và quay về màn đăng nhập. Mở khoá để khách đăng nhập lại.
3. Đổi quyền một tài khoản: phiên cũ bị đăng xuất, đăng nhập lại để nhận quyền mới.

### D. Bản web (khoảng 2 phút)

- Mở trên máy tính: bố cục rộng, có thẻ phim nổi bật ở trang chủ.
- Mỗi màn có địa chỉ riêng (`#/movies/7`, `#/bookings/<id>`). F5 hoặc mở link được gửi vẫn ra đúng màn; trang cần đăng nhập thì đăng nhập xong vào đúng trang đó.

### E. Hạ tầng (khi được hỏi)

| Công cụ | Địa chỉ |
|---|---|
| Grafana / Prometheus / Jaeger | `http://localhost:3000` / `http://localhost:9090` / `http://localhost:16686` |
| RabbitMQ (event giữa các service) | `http://localhost:15672`, tài khoản `cinema` / `cinema` |
| Swagger AuthService / MovieService / BookingService | `http://localhost:5100/swagger` / `:5168/swagger` / `:5063/swagger` |

## 4. Lưu ý

- Gateway giới hạn 100 request mỗi phút cho một IP. Gặp lỗi "quá nhiều yêu cầu" thì chờ một phút.
- App chỉ hiện suất chưa bắt đầu trong 7 ngày tới. Không thấy suất nào thì chạy lại lệnh lịch chiếu demo.
- Muốn dữ liệu sạch như máy mới: `docker compose down -v` rồi chạy lại bước 2. Lệnh này xoá toàn bộ dữ liệu, kể cả tài khoản và vé đã tạo.
- Docker và Visual Studio dùng chung cổng 5000/5100/5168/5063: dừng các service đang chạy trong Visual Studio trước khi demo.
