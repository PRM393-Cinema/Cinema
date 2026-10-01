# Hướng dẫn cấu hình key & secrets (Cinema BE)

> **TL;DR**
> - **Không bao giờ** ghi key/mật khẩu thật vào `appsettings.json` hay commit lên Git.
> - Mỗi người tự đặt key trên máy mình bằng **User Secrets** (chạy script ở [mục 3](#3-cài-đặt-nhanh-bằng-powershell-khuyên-dùng) là xong).
> - **JWT key phải giống hệt nhau** ở AuthService, BookingService và ApiGateway (trên cùng một máy).

---

## 1. Service nào cần key gì

| Service | Thư mục | Cổng http / https | Key cần đặt |
|---|---|---|---|
| AuthService | `AuthService/AuthService` | 5100 / 7100 | `ConnectionStrings:DefaultConnection`, `Jwt:SecretKey` |
| MovieService | `MovieService/MovieService` | 5168 / 7253 | `ConnectionStrings:MovieDb`, `ConnectionStrings:ShowtimeDb` |
| BookingService | `BookingService/BookingService` | 5063 / 7116 | `ConnectionStrings:BookingDb`, `ConnectionStrings:NotificationDb`, `ConnectionStrings:PaymentDb`, `Jwt:SecretKey`<br>Tuỳ chọn: `PayOS:*`, `Smtp:*` |
| ApiGateway | `ApiGateway/ApiGateway` | 5000 / 7000 | `Jwt:SecretKey` |

Ghi chú:
- MovieService **không cần** JWT key — nó không tự xác thực, việc phân quyền do ApiGateway đảm nhận.
- `Jwt:Issuer` (`CinemaAuthService`) và `Jwt:Audience` (`CinemaClients`) đã có sẵn trong `appsettings.json`, không phải bí mật.
- BookingService gọi thẳng MovieService qua `ShowtimeService:BaseUrl` = `http://localhost:5168/` (đã có trong `appsettings.json`) — MovieService phải đang chạy thì mới tạo booking được.

## 2. Vì sao dùng User Secrets

- `appsettings.json` chỉ chứa **giá trị mẫu** (`Password=2005`, `Password=postgres`, `SecretKey` rỗng…). Mật khẩu PostgreSQL mỗi máy một khác nên không thể commit chung.
- Khi chạy ở môi trường **Development** (mặc định khi chạy bằng Visual Studio hoặc `dotnet run`), giá trị trong User Secrets **ghi đè** `appsettings.json`.
- User Secrets nằm **ngoài repo**, tại `%APPDATA%\Microsoft\UserSecrets\<UserSecretsId>\secrets.json`, nên không thể lỡ tay commit:

| Service | UserSecretsId |
|---|---|
| AuthService | `c4c31d67-6d60-4e9b-b9fa-87ae1b17c11e` |
| MovieService | `ca4d045c-aa45-4401-808f-66aa31f07b7c` |
| BookingService | `275becd6-e0f7-46f6-b405-fc31270148e9` |
| ApiGateway | `0ab9bd05-1f24-4da9-bf90-a7cc507e1fba` |

## 3. Cài đặt nhanh bằng PowerShell (khuyên dùng)

Mở PowerShell **trong thư mục `Cinema_BE`**, sửa dòng `$PG` thành mật khẩu user `postgres` trên máy bạn, rồi chạy cả khối. Script tự sinh một JWT key ngẫu nhiên và đặt **cùng một key** cho cả 3 service cần dùng.

```powershell
$PG = "<mat_khau_postgres_cua_ban>"

# Sinh JWT key ngẫu nhiên 64 ký tự hex (dùng chung cho Auth, Booking, Gateway)
$bytes = New-Object byte[] 32
[System.Security.Cryptography.RandomNumberGenerator]::Create().GetBytes($bytes)
$JWT = -join ($bytes | ForEach-Object { $_.ToString("x2") })

# AuthService
dotnet user-secrets set "ConnectionStrings:DefaultConnection" "Host=localhost;Port=5432;Database=cinema_auth_db;Username=postgres;Password=$PG" --project AuthService/AuthService
dotnet user-secrets set "Jwt:SecretKey" $JWT --project AuthService/AuthService

# MovieService
dotnet user-secrets set "ConnectionStrings:MovieDb" "Host=localhost;Port=5432;Database=cinema_movie_db;Username=postgres;Password=$PG" --project MovieService/MovieService
dotnet user-secrets set "ConnectionStrings:ShowtimeDb" "Host=localhost;Port=5432;Database=cinema_showtime_db;Username=postgres;Password=$PG" --project MovieService/MovieService

# BookingService
dotnet user-secrets set "ConnectionStrings:BookingDb" "Host=localhost;Port=5432;Database=cinema_booking_db;Username=postgres;Password=$PG" --project BookingService/BookingService
dotnet user-secrets set "ConnectionStrings:NotificationDb" "Host=localhost;Port=5432;Database=cinema_notification_db;Username=postgres;Password=$PG" --project BookingService/BookingService
dotnet user-secrets set "ConnectionStrings:PaymentDb" "Host=localhost;Port=5432;Database=cinema_payment_db;Username=postgres;Password=$PG" --project BookingService/BookingService
dotnet user-secrets set "Jwt:SecretKey" $JWT --project BookingService/BookingService

# ApiGateway
dotnet user-secrets set "Jwt:SecretKey" $JWT --project ApiGateway/ApiGateway
```

> Chạy lại script lúc nào cũng được: nó sinh JWT key mới và cập nhật đồng loạt cả 3 service. Token cũ sẽ hết hiệu lực, chỉ cần đăng nhập lại.

## 4. Cách khác: dùng Visual Studio

Chuột phải vào project → **Manage User Secrets** → dán nội dung tương ứng vào `secrets.json` rồi lưu. Nhớ dùng **cùng một JWT key** cho cả 3 service (có thể tạo key bằng 3 dòng "Sinh JWT key" ở mục 3).

**AuthService**
```json
{
  "ConnectionStrings:DefaultConnection": "Host=localhost;Port=5432;Database=cinema_auth_db;Username=postgres;Password=<mat_khau>",
  "Jwt:SecretKey": "<jwt_key_dung_chung>"
}
```

**MovieService**
```json
{
  "ConnectionStrings:MovieDb": "Host=localhost;Port=5432;Database=cinema_movie_db;Username=postgres;Password=<mat_khau>",
  "ConnectionStrings:ShowtimeDb": "Host=localhost;Port=5432;Database=cinema_showtime_db;Username=postgres;Password=<mat_khau>"
}
```

**BookingService**
```json
{
  "ConnectionStrings:BookingDb": "Host=localhost;Port=5432;Database=cinema_booking_db;Username=postgres;Password=<mat_khau>",
  "ConnectionStrings:NotificationDb": "Host=localhost;Port=5432;Database=cinema_notification_db;Username=postgres;Password=<mat_khau>",
  "ConnectionStrings:PaymentDb": "Host=localhost;Port=5432;Database=cinema_payment_db;Username=postgres;Password=<mat_khau>",
  "Jwt:SecretKey": "<jwt_key_dung_chung>"
}
```

**ApiGateway**
```json
{
  "Jwt:SecretKey": "<jwt_key_dung_chung>"
}
```

## 5. Kiểm tra / xoá secrets

```powershell
dotnet user-secrets list --project AuthService/AuthService                 # xem các key đã đặt
dotnet user-secrets remove "Jwt:SecretKey" --project AuthService/AuthService  # xoá 1 key
dotnet user-secrets clear --project AuthService/AuthService                # xoá hết
```

## 6. PayOS & SMTP (tuỳ chọn, chỉ BookingService)

Không đặt thì các luồng khác vẫn chạy bình thường, chỉ riêng 2 tính năng này báo lỗi:

| Thiếu | Hiện tượng |
|---|---|
| PayOS | `POST /api/v1/payments/payos/checkout` trả **502** "PayOS credentials are not configured." |
| SMTP | Booking vẫn xác nhận được, nhưng notification chuyển sang `FAILED` với lỗi "SMTP email settings are not configured." |

**PayOS** — xin key từ người quản lý tài khoản PayOS của nhóm (**gửi riêng, không dán vào group chat**):
```powershell
dotnet user-secrets set "PayOS:ClientId" "<client_id>" --project BookingService/BookingService
dotnet user-secrets set "PayOS:ApiKey" "<api_key>" --project BookingService/BookingService
dotnet user-secrets set "PayOS:ChecksumKey" "<checksum_key>" --project BookingService/BookingService
```

**SMTP (ví dụ Gmail)** — tài khoản Google cần bật xác minh 2 bước và tạo **App Password** (Google Account → Security → App passwords). `Port` 587 và `EnableSsl` true đã có sẵn trong `appsettings.json`.
```powershell
dotnet user-secrets set "Smtp:Host" "smtp.gmail.com" --project BookingService/BookingService
dotnet user-secrets set "Smtp:Username" "<gmail_cua_ban>" --project BookingService/BookingService
dotnet user-secrets set "Smtp:Password" "<app_password_16_ky_tu>" --project BookingService/BookingService
dotnet user-secrets set "Smtp:FromEmail" "<gmail_cua_ban>" --project BookingService/BookingService
```

## 7. Database

Các connection string ở trên trỏ tới 6 database tạo từ repo **Project-Cinema-DB**.

- **Tạo mới:** chạy trong thư mục `Project-Cinema-DB`. Bắt buộc đặt `PGCLIENTENCODING=UTF8`, nếu không dữ liệu tiếng Việt sẽ lỗi encoding (WIN1252):
  ```powershell
  $env:PGPASSWORD = "<mat_khau_postgres>"; $env:PGCLIENTENCODING = "UTF8"
  $psql = "C:\Program Files\PostgreSQL\18\bin\psql.exe"   # sửa theo phiên bản PostgreSQL của bạn
  foreach ($db in "auth", "movie", "showtime", "booking", "payment", "notification") {
      & $psql -h localhost -U postgres -c "CREATE DATABASE cinema_${db}_db;"
      & $psql -h localhost -U postgres -d "cinema_${db}_db" -f "cinema_${db}_db.sql"
  }
  ```
- **DB đã tạo từ bản SQL cũ** (trước 30/09/2026): chạy thêm 2 script trong `Project-Cinema-DB/migrations/` — `2026-09-30_cinema_notification_db.sql` trên `cinema_notification_db` và `2026-09-30_cinema_booking_db.sql` trên `cinema_booking_db`. Chạy nhiều lần vẫn an toàn.

## 8. Lỗi thường gặp

| Lỗi | Nguyên nhân | Cách sửa |
|---|---|---|
| `28P01: password authentication failed for user "postgres"` | Connection string đang dùng mật khẩu mẫu trong `appsettings.json` | Đặt connection string bằng User Secrets (mục 3) |
| Service không khởi động được: `Jwt:SecretKey chưa được cấu hình…` / `Jwt:SecretKey must be configured with at least 32 characters` | Chưa đặt JWT key hoặc key ngắn hơn 32 ký tự | Đặt `Jwt:SecretKey` (mục 3) |
| Đăng nhập được nhưng gọi API khác báo **401** "Token không hợp lệ hoặc đã hết hạn" | JWT key giữa AuthService và Gateway/BookingService **không giống nhau** | Chạy lại script mục 3 để cả 3 dùng chung một key, rồi đăng nhập lại |
| `42703: column n.error_message does not exist` (API notification lỗi 500) | DB tạo từ bản SQL cũ | Chạy script migration (mục 7) |
| MovieService lỗi kết nối DB dù đã cài secret | Đang dùng key cũ `ConnectionStrings:DefaultConnection` (MovieService đã đổi sang `MovieDb` + `ShowtimeDb`) | Đặt lại 2 key mới (mục 3) |
| Tạo booking báo **502** "Showtime service is unavailable" | MovieService chưa chạy ở cổng 5168 | Chạy MovieService trước |
| `character with byte sequence … in encoding "WIN1252"` khi chạy file SQL | psql trên Windows mặc định dùng WIN1252 | Đặt `$env:PGCLIENTENCODING = "UTF8"` trước khi chạy |

## 9. Quy tắc bảo mật

- Chỉ để giá trị mẫu trong `appsettings.json`; key thật luôn nằm trong User Secrets (khi deploy thì dùng biến môi trường).
- Không dán key PayOS, App Password SMTP… vào group chat hay tài liệu chung. Cần chia sẻ thì gửi riêng.
- Lỡ để lộ key: JWT key → chạy lại script mục 3 để sinh key mới; PayOS → tạo lại key trên trang quản trị PayOS; Gmail → thu hồi App Password cũ.
- Khi chạy bằng Docker/môi trường thật, User Secrets không còn tác dụng. Hãy dùng biến môi trường với `__` thay cho `:`, ví dụ `Jwt__SecretKey`, `ConnectionStrings__MovieDb`.

## 10. Chạy thử

1. Thứ tự khởi động: **AuthService → MovieService → BookingService → ApiGateway** (profile `http` hay `https` đều được).
2. Mở `http://localhost:5000/health` → thấy `Healthy` là gateway đã chạy.
3. Flutter gọi qua gateway: `http://localhost:5000` (Android emulator dùng `http://10.0.2.2:5000`).
4. Tài khoản seed (mật khẩu đều là `123456`):

| Email | Role |
|---|---|
| `admin@cinema.com` | ROLE_ADMIN |
| `nhanvien1@cinema.com` | ROLE_STAFF |
| `khachhang1@gmail.com` | ROLE_CUSTOMER |
