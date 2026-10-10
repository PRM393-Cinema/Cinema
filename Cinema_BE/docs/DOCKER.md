# Chạy toàn bộ backend bằng Docker

Một lệnh chạy cả 6 thành phần: **PostgreSQL + RabbitMQ + AuthService + MovieService + BookingService + ApiGateway**. Không cần cài PostgreSQL, không cần cài User Secrets, không cần mở từng service trong Visual Studio.

## 1. Chuẩn bị (làm một lần)

1. Cài và **mở Docker Desktop**.
2. Clone repo `Cinema` (repo này) và repo `Project-Cinema-DB` **nằm cạnh nhau** (container PostgreSQL lấy file SQL từ repo DB):
   ```
   <thư mục bất kỳ>/
   ├── Cinema/
   │   ├── Cinema_BE/
   │   └── Cinema_Mobile/
   └── Project-Cinema-DB/
   ```
   Nếu để chỗ khác thì khai báo `DB_SCRIPTS_DIR` trong `.env` (đường dẫn tính từ thư mục `Cinema_BE`).
3. Tạo file `.env` trong thư mục `Cinema_BE`:
   - **Đã được cấp quyền giải mã** ([SECRETS_SOPS.md](SECRETS_SOPS.md)): chạy `.\scripts\secrets.ps1 decrypt` là có `.env` đầy đủ, kể cả SMTP. Bỏ qua phần điền tay bên dưới.
   - **Chưa được cấp quyền**: tạo từ mẫu rồi điền 2 giá trị bắt buộc:
   ```powershell
   Copy-Item .env.example .env
   ```
   - `POSTGRES_PASSWORD`: tự đặt bất kỳ (mật khẩu của PostgreSQL trong container, không liên quan PostgreSQL trên máy).
   - `JWT_SECRET_KEY`: chuỗi ngẫu nhiên ≥ 32 ký tự. Tạo bằng PowerShell:
     ```powershell
     $b = New-Object byte[] 32; [System.Security.Cryptography.RandomNumberGenerator]::Create().GetBytes($b); -join ($b | ForEach-Object { $_.ToString("x2") })
     ```
   - PayOS: tuỳ chọn, để trống thì chỉ thanh toán PayOS báo lỗi, mọi thứ khác vẫn chạy. Luồng thanh toán, webhook, cách test không cần trả tiền thật: [PAYOS.md](PAYOS.md).
   - SMTP (Gmail gửi OTP + email đặt vé): tuỳ chọn, xem [EMAIL_SETUP.md](EMAIL_SETUP.md). Để trống thì email không được gửi thật, mã OTP được in ra `docker compose logs -f auth-service`.

> File `.env` đã nằm trong `.gitignore` — **không commit** file này.

## 2. Chạy

Mở PowerShell **trong thư mục `Cinema_BE`** rồi chạy:

```powershell
docker compose up -d --build
```

- Lần đầu mất vài phút (tải image, build 4 service, tạo 6 database và nạp dữ liệu seed). Các lần sau nhanh hơn nhiều.
- Kèm công cụ giám sát (Grafana, Prometheus, Jaeger): `docker compose --profile monitoring up -d --build`, xem [MONITORING.md](MONITORING.md).
- Kiểm tra trạng thái: `docker compose ps` — `postgres` và `rabbitmq` phải là `healthy`, các service khác là `running`.

| Thành phần | Địa chỉ trên máy |
|---|---|
| **API Gateway (Flutter gọi vào đây)** | `http://localhost:5000` — Android emulator: `http://10.0.2.2:5000` — điện thoại thật cùng wifi: `http://<IP máy>:5000` |
| Swagger AuthService | `http://localhost:5100/swagger` |
| Swagger MovieService | `http://localhost:5168/swagger` |
| Swagger BookingService | `http://localhost:5063/swagger` |
| PostgreSQL (pgAdmin/DBeaver) | `localhost:5433`, user `postgres`, mật khẩu = `POSTGRES_PASSWORD` trong `.env` |
| RabbitMQ (trang quản lý) | `http://localhost:15672`, tài khoản `cinema` / `cinema` (event giữa các service: [MESSAGING.md](MESSAGING.md)) |
| **Tình trạng cả hệ thống** | `http://localhost:5000/health/services` (từng service: `Healthy` / `Unhealthy`) |
| Tình trạng một service | `http://localhost:5100/health` (5168, 5063 tương tự): chỉ ra database nào đang lỗi |
| Grafana / Prometheus / Jaeger (chỉ khi có `--profile monitoring`) | `http://localhost:3000` / `http://localhost:9090` / `http://localhost:16686` ([MONITORING.md](MONITORING.md)) |

> Chỉ **gateway** mở cho máy khác trong mạng. Các service và PostgreSQL chỉ nghe ở `127.0.0.1`: trên máy mình vẫn mở Swagger/pgAdmin bình thường, còn máy khác cùng wifi không gọi thẳng vào được (phải đi qua gateway, nơi kiểm tra quyền và giới hạn số request).

Tài khoản seed (mật khẩu `123456`): `admin@cinema.com`, `nhanvien1@cinema.com`, `khachhang1@gmail.com`. Trên mobile, đăng nhập Admin → **Dashboard → tab Accounts** để tìm kiếm, lọc, phân trang, xem chi tiết, tạo tài khoản, gán quyền và khóa/mở tài khoản (hoặc gọi `POST /api/v1/auth/users` trong `ApiGateway.http`).

**Khi một service lỗi** (retry + circuit breaker, SRS §13.2):
- BookingService gọi MovieService/PayOS: lỗi tạm thời thì **tự thử lại** tối đa 2 lần. Riêng lệnh tạo link PayOS không thử lại, để tránh tạo trùng.
- Lỗi liên tục: **circuit breaker mở 15 giây**, API trả **503** ngay ("... temporarily unavailable. Please try again later.") thay vì để người dùng chờ timeout. Hết 15 giây thì thử lại một request, thành công thì hoạt động bình thường.
- Gateway kiểm tra `/health/live` của từng service mỗi 10 giây. Service chết thì gateway trả 503 ngay, service sống lại thì tự định tuyến lại.
- Flutter: gặp **503** thì báo "Hệ thống đang bận, vui lòng thử lại sau", không cần xử lý gì thêm.

## 3. Các lệnh hay dùng

| Việc | Lệnh |
|---|---|
| Xem log tất cả / một service | `docker compose logs -f` / `docker compose logs -f booking-service` |
| Build lại sau khi sửa code | `docker compose up -d --build` (hoặc chỉ một service: `docker compose up -d --build movie-service`) |
| Dừng (giữ dữ liệu) | `docker compose down` |
| **Xoá sạch DB, tạo lại từ file SQL** | `docker compose down -v` rồi `docker compose up -d --build` |

## 4. Lưu ý

### Lịch chiếu demo một tháng

DB mới tự bổ sung 2 phòng demo (03 Standard, 04 IMAX), rồi tạo lịch cho tất cả phim `ACTIVE` từ hôm nay trong một tháng theo giờ Việt Nam. Mỗi phòng có các suất 09:00, 12:30, 16:00, 19:30, 23:00 hằng ngày; phòng tiếp theo lệch 15 phút. Với 4 phòng có khoảng 20 suất/ngày, riêng hôm nay chỉ thêm giờ chưa bắt đầu. Lịch dùng đúng thời lượng phim, chừa ít nhất 20 phút dọn phòng, giá khác nhau theo phòng, giờ tối và cuối tuần.

Mỗi phòng demo có sơ đồ ghế riêng; Flutter đọc hàng và số ghế thực tế từ API:

| Phòng | Ghế mỗi hàng (A trở đi) | Tổng ghế |
|---|---|---|
| 01 IMAX | 10 / 10 / 10 / 12 / 12 | 54 |
| 02 Standard | 10 / 10 / 10 / 8 | 38 |
| 03 Standard | 12 / 12 / 12 | 36 |
| 04 IMAX | 10 / 10 / 10 / 14 / 14 / 14 | 72 |

UI chừa một lối đi giữa hàng 8–12 ghế, hai lối đi cho hàng 14 ghế. Sơ đồ rộng hỗ trợ kéo và phóng to. Migration chỉ bổ sung ghế, giữ nguyên ID và loại ghế cũ để bảo toàn tham chiếu của vé đã đặt.

Với DB đang chạy hoặc khi lịch demo đã hết, bổ sung bằng lệnh sau. Script giữ nguyên dữ liệu cũ và bỏ qua các khung giờ đã có lịch:

```powershell
docker compose exec -T postgres psql -X -U postgres -d cinema_showtime_db -v ON_ERROR_STOP=1 -f /db-scripts/migrations/2026-10-10_cinema_more_daily_showtimes.sql
docker compose exec -T postgres psql -X -U postgres -d cinema_showtime_db -v ON_ERROR_STOP=1 -f /db-scripts/migrations/2026-10-10_cinema_distinct_room_layouts.sql
```

Lệnh đọc danh sách phim từ `cinema_movie_db` rồi thêm lịch vào `cinema_showtime_db`; không cần extension PostgreSQL. File nằm trong repo `Project-Cinema-DB`, cần pull cả repo này khi cập nhật.

- **Database trong Docker tách biệt** với PostgreSQL cài trên máy: dữ liệu hai bên khác nhau. Với DB đang dùng, áp dụng các file migration tương ứng trong `Project-Cinema-DB/migrations`; lịch demo dùng lệnh ở trên. `docker compose down -v` xoá dữ liệu, chỉ dùng khi chủ động muốn tạo lại toàn bộ DB.
- Docker dùng **cùng cổng** với khi chạy bằng Visual Studio (5000/5100/5168/5063) → không chạy song song hai cách. Muốn debug một service bằng Visual Studio thì dừng container của service đó trước (vd: `docker compose stop booking-service`).
- Trong Docker, cấu hình lấy từ biến môi trường do `docker-compose.yml` truyền vào (đọc từ `.env`), User Secrets trên máy **không** được dùng.
- Các container chạy theo giờ Việt Nam (`Asia/Ho_Chi_Minh`) để khớp dữ liệu seed và code dùng `DateTime.Now`.

## 5. Lỗi thường gặp

| Lỗi | Cách sửa |
|---|---|
| `failed to connect to the docker API ... dockerDesktopLinuxEngine` | Docker Desktop chưa mở — mở lên rồi chạy lại |
| `Set POSTGRES_PASSWORD in .env` / `Set JWT_SECRET_KEY in .env` | Chưa tạo `.env` hoặc chưa điền giá trị (mục 1) |
| `Bind for 0.0.0.0:5000 failed: port is already allocated` | Cổng đang bị chiếm (thường do service đang chạy trong Visual Studio) — tắt đi rồi chạy lại |
| Container `postgres` dừng, log có `Khong tim thay /db-scripts/...` | Thiếu repo `Project-Cinema-DB` cạnh thư mục `Cinema` (hoặc sai `DB_SCRIPTS_DIR`) → sửa rồi chạy `docker compose down -v` và `up` lại |
| Đổi `POSTGRES_PASSWORD` sau lần chạy đầu thì service không kết nối được DB | Mật khẩu chỉ được đặt lúc tạo volume → `docker compose down -v` rồi chạy lại |
| AuthService lỗi `42703: column u.email_verified does not exist` / BookingService lỗi `column b.customer_email does not exist` | DB trong volume được tạo từ file SQL cũ → `docker compose down -v` rồi chạy lại (hoặc chạy file mới trong `Project-Cinema-DB/migrations`) |
| Đăng ký xong không nhận được email OTP | Chưa cấu hình SMTP trong `.env` → lấy mã trong `docker compose logs auth-service`, hoặc cấu hình Gmail ([EMAIL_SETUP.md](EMAIL_SETUP.md)) |
| Thanh toán xong không có email vé / huỷ vé không thấy hoàn tiền | Xem `http://localhost:5063/health`: `rabbitmq` phải `Healthy`. Event chưa gửi được thì nằm chờ, RabbitMQ chạy lại sẽ gửi bù ([MESSAGING.md](MESSAGING.md)) |
| `relation "outbox_messages" does not exist` / `column ... payer_account_number does not exist` | DB tạo từ file SQL cũ → `docker compose down -v` rồi chạy lại (hoặc chạy các file `2026-10-02_*.sql` trong `Project-Cinema-DB/migrations`) |

### Quản lý tài khoản trên mobile

- Admin local/demo: `admin@cinema.com`, mật khẩu `123456` (seed hiện có; dùng mật khẩu riêng khi triển khai).
- Admin đăng nhập vào `/admin/dashboard`, dùng dashboard quản trị và nav dưới riêng **Dashboard / Accounts / Profile**. Accounts bao gồm `/admin/users`, `/admin/users/new`, `/admin/users/{id}`; Profile tại `/admin/profile`. Thống kê tài khoản và vai trò lấy từ API thật. Chỉ `ROLE_ADMIN` được vào khu vực này; backend tiếp tục kiểm tra quyền. Customer dùng giao diện khách hàng; Staff có dashboard riêng `/staff/dashboard` với nav Dashboard / Operations / Profile.
- Có thể chọn nhiều vai trò `ROLE_ADMIN`, `ROLE_STAFF`, `ROLE_CUSTOMER`. Tài khoản do Admin tạo được bật và xác thực email ngay, có thể đăng nhập mà không cần OTP.
- Không thể tự khóa hoặc tự bỏ quyền Admin. Khóa tài khoản thu hồi refresh token; access token đã cấp có thể còn hiệu lực đến khi hết hạn. Quyền mới cập nhật khi đăng nhập/làm mới phiên.
- Bảng [MOBILE_UI_ENDPOINTS.md](../../Cinema_Mobile/docs/MOBILE_UI_ENDPOINTS.md) liệt kê đủ 6 API đã nối và các API khác còn thiếu UI.

### Khu vực Staff trên mobile

Staff seed local/demo: `nhanvien1@cinema.com`, mật khẩu `123456`. Đăng nhập sẽ vào dashboard Staff; tài khoản có cả Admin và Staff ưu tiên dashboard Admin.

Tab **Operations** gồm vé, suất chiếu, phòng/ghế, thanh toán và hoàn tiền. Xem [STAFF_WORKSPACE.md](../../Cinema_Mobile/docs/STAFF_WORKSPACE.md) về thao tác, quyền và giới hạn backend; [MOBILE_UI_ENDPOINTS.md](../../Cinema_Mobile/docs/MOBILE_UI_ENDPOINTS.md) ghi rõ endpoint đã có UI và phần còn thiếu.
