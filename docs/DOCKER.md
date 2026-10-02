# Chạy toàn bộ backend bằng Docker

Một lệnh chạy cả 5 thành phần: **PostgreSQL + AuthService + MovieService + BookingService + ApiGateway**. Không cần cài PostgreSQL, không cần cài User Secrets, không cần mở từng service trong Visual Studio.

## 1. Chuẩn bị (làm một lần)

1. Cài và **mở Docker Desktop**.
2. Clone 2 repo **nằm cạnh nhau** (container PostgreSQL lấy file SQL từ repo DB):
   ```
   <thư mục bất kỳ>/
   ├── Cinema_BE/
   └── Project-Cinema-DB/
   ```
   Nếu để chỗ khác thì khai báo `DB_SCRIPTS_DIR` trong `.env`.
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
   - PayOS: tuỳ chọn, để trống thì chỉ thanh toán PayOS báo lỗi, mọi thứ khác vẫn chạy (xem [SETUP_SECRETS.md mục 6](SETUP_SECRETS.md#6-payos--smtp-tuỳ-chọn)).
   - SMTP (Gmail gửi OTP + email đặt vé): tuỳ chọn, xem [EMAIL_SETUP.md](EMAIL_SETUP.md). Để trống thì email không được gửi thật, mã OTP được in ra `docker compose logs -f auth-service`.

> File `.env` đã nằm trong `.gitignore` — **không commit** file này.

## 2. Chạy

```powershell
docker compose up -d --build
```

- Lần đầu mất vài phút (tải image, build 4 service, tạo 6 database và nạp dữ liệu seed). Các lần sau nhanh hơn nhiều.
- Kiểm tra trạng thái: `docker compose ps` — `postgres` phải là `healthy`, các service khác là `running`.

| Thành phần | Địa chỉ trên máy |
|---|---|
| **API Gateway (Flutter gọi vào đây)** | `http://localhost:5000` — Android emulator: `http://10.0.2.2:5000` — điện thoại thật cùng wifi: `http://<IP máy>:5000` |
| Swagger AuthService | `http://localhost:5100/swagger` |
| Swagger MovieService | `http://localhost:5168/swagger` |
| Swagger BookingService | `http://localhost:5063/swagger` |
| PostgreSQL (pgAdmin/DBeaver) | `localhost:5433`, user `postgres`, mật khẩu = `POSTGRES_PASSWORD` trong `.env` |

> Chỉ **gateway** mở cho máy khác trong mạng. Các service và PostgreSQL chỉ nghe ở `127.0.0.1`: trên máy mình vẫn mở Swagger/pgAdmin bình thường, còn máy khác cùng wifi không gọi thẳng vào được (phải đi qua gateway, nơi kiểm tra quyền và giới hạn số request).

Tài khoản seed (mật khẩu `123456`): `admin@cinema.com`, `nhanvien1@cinema.com`, `khachhang1@gmail.com`.

## 3. Các lệnh hay dùng

| Việc | Lệnh |
|---|---|
| Xem log tất cả / một service | `docker compose logs -f` / `docker compose logs -f booking-service` |
| Build lại sau khi sửa code | `docker compose up -d --build` (hoặc chỉ một service: `docker compose up -d --build movie-service`) |
| Dừng (giữ dữ liệu) | `docker compose down` |
| **Xoá sạch DB, tạo lại từ file SQL** | `docker compose down -v` rồi `docker compose up -d --build` |

## 4. Lưu ý

- **Database trong Docker tách biệt** với PostgreSQL cài trên máy: dữ liệu hai bên khác nhau. Khi repo `Project-Cinema-DB` có thay đổi, chạy `docker compose down -v` để tạo lại DB từ file SQL mới.
- Docker dùng **cùng cổng** với khi chạy bằng Visual Studio (5000/5100/5168/5063) → không chạy song song hai cách. Muốn debug một service bằng Visual Studio thì dừng container của service đó trước (vd: `docker compose stop booking-service`).
- Trong Docker, cấu hình lấy từ biến môi trường do `docker-compose.yml` truyền vào (đọc từ `.env`), User Secrets trên máy **không** được dùng.
- Các container chạy theo giờ Việt Nam (`Asia/Ho_Chi_Minh`) để khớp dữ liệu seed và code dùng `DateTime.Now`.

## 5. Lỗi thường gặp

| Lỗi | Cách sửa |
|---|---|
| `failed to connect to the docker API ... dockerDesktopLinuxEngine` | Docker Desktop chưa mở — mở lên rồi chạy lại |
| `Set POSTGRES_PASSWORD in .env` / `Set JWT_SECRET_KEY in .env` | Chưa tạo `.env` hoặc chưa điền giá trị (mục 1) |
| `Bind for 0.0.0.0:5000 failed: port is already allocated` | Cổng đang bị chiếm (thường do service đang chạy trong Visual Studio) — tắt đi rồi chạy lại |
| Container `postgres` dừng, log có `Khong tim thay /db-scripts/...` | Thiếu repo `Project-Cinema-DB` cạnh `Cinema_BE` (hoặc sai `DB_SCRIPTS_DIR`) → sửa rồi chạy `docker compose down -v` và `up` lại |
| Đổi `POSTGRES_PASSWORD` sau lần chạy đầu thì service không kết nối được DB | Mật khẩu chỉ được đặt lúc tạo volume → `docker compose down -v` rồi chạy lại |
| AuthService lỗi `42703: column u.email_verified does not exist` | DB trong volume được tạo từ file SQL cũ → `docker compose down -v` rồi chạy lại |
| Đăng ký xong không nhận được email OTP | Chưa cấu hình SMTP trong `.env` → lấy mã trong `docker compose logs auth-service`, hoặc cấu hình Gmail ([EMAIL_SETUP.md](EMAIL_SETUP.md)) |
