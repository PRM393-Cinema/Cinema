# Gửi email bằng Gmail (OTP, email chào mừng, xác nhận đặt vé)

> **TL;DR**
> - Hệ thống gửi email qua SMTP của Gmail bằng **App Password**, không dùng mật khẩu Gmail thường.
> - Chỉ người giữ tài khoản Gmail của hệ thống mới tạo App Password, rồi gửi riêng cho người cần. **Không commit, không dán vào group chat.**
> - Chưa có App Password vẫn dev được: ở môi trường Development, AuthService không gửi email mà **in nội dung email (kèm mã OTP) ra log**.

---

## 1. Hệ thống gửi những email nào

| Email | Service | Khi nào |
|---|---|---|
| Mã OTP xác thực email | AuthService | Đăng ký, gửi lại mã |
| Chào mừng | AuthService | Xác thực email thành công |
| Mã OTP đặt lại mật khẩu | AuthService | Quên mật khẩu |
| Xác nhận đặt vé | BookingService | Booking được xác nhận: PayOS báo đã thanh toán, hoặc Staff xác nhận tại quầy |

Hai service dùng chung **một tài khoản Gmail** với cùng bộ key `Smtp:*`.

## 2. Tạo App Password (người giữ tài khoản Gmail làm một lần)

1. Đăng nhập Gmail của hệ thống, mở <https://myaccount.google.com/security> rồi bật **Xác minh 2 bước** (2-Step Verification). Google chỉ cho tạo App Password khi đã bật mục này.
2. Mở <https://myaccount.google.com/apppasswords>, đặt tên (vd: `Cinema BE`) rồi bấm **Tạo**.
3. Google hiện mật khẩu 16 ký tự dạng `abcd efgh ijkl mnop`. Khi dùng thì **viết liền, bỏ dấu cách**. Mật khẩu chỉ hiện một lần, lỡ mất thì tạo cái mới.
4. Gửi App Password **riêng** cho người cần (tin nhắn riêng), không dán vào group chat hay tài liệu chung.

> - Trang App passwords báo *"The setting you are looking for is not available for your account"*: chưa bật xác minh 2 bước, hoặc tài khoản Google Workspace bị quản trị viên tắt tính năng này.
> - Lỡ để lộ: vào lại trang App passwords và xoá mật khẩu đó. Đổi mật khẩu Gmail cũng làm mọi App Password mất hiệu lực.

## 3. Cấu hình

| Key | Giá trị cho Gmail |
|---|---|
| `Smtp:Host` | `smtp.gmail.com` |
| `Smtp:Port` | `587` (đã có sẵn trong `appsettings.json`) — **không dùng 465** |
| `Smtp:EnableSsl` | `true` (đã có sẵn) |
| `Smtp:Username` | Địa chỉ Gmail của hệ thống |
| `Smtp:Password` | App Password 16 ký tự, viết liền |
| `Smtp:FromEmail` | Địa chỉ Gmail của hệ thống (trùng `Username`, Gmail không cho gửi bằng địa chỉ khác) |
| `Smtp:FromName` | Tên người gửi hiển thị, mặc định `Mobile Cinema` |

### Chạy bằng Docker

Đã được cấp quyền giải mã `secrets.enc.env` ([SECRETS_SOPS.md](SECRETS_SOPS.md)) thì chạy `.\scripts\secrets.ps1 decrypt` là có sẵn SMTP, không cần xin App Password. Nếu không, sửa file `.env` trong thư mục `Cinema_BE`:

```
SMTP_HOST=smtp.gmail.com
SMTP_USERNAME=<gmail_he_thong>@gmail.com
SMTP_PASSWORD=<app_password_viet_lien>
SMTP_FROM_EMAIL=<gmail_he_thong>@gmail.com
```

Rồi chạy `docker compose up -d`. Compose tự tạo lại `auth-service` và `booking-service` với cấu hình mới, không cần `--build`.

### Chạy bằng Visual Studio / `dotnet run` (User Secrets)

Mở PowerShell **trong thư mục `Cinema_BE`** rồi chạy cả khối. Script hỏi Gmail và App Password (gõ App Password không hiện lên màn hình), tự bỏ dấu cách, rồi đặt cho cả AuthService và BookingService:

```powershell
$gmail = Read-Host "Gmail he thong"
$secure = Read-Host "App Password" -AsSecureString
$appPassword = ([System.Net.NetworkCredential]::new("", $secure).Password) -replace '\s', ''

foreach ($project in "AuthService/AuthService", "BookingService/BookingService") {
    dotnet user-secrets set "Smtp:Host" "smtp.gmail.com" --project $project
    dotnet user-secrets set "Smtp:Username" $gmail --project $project
    dotnet user-secrets set "Smtp:Password" $appPassword --project $project
    dotnet user-secrets set "Smtp:FromEmail" $gmail --project $project
}
```

Sau đó chạy lại AuthService và BookingService.

### Chưa có App Password

- Môi trường **Development** mà `Smtp:Host` hoặc `Smtp:FromEmail` để trống: AuthService **không gửi** email mà in cảnh báo `SMTP chưa được cấu hình...` kèm toàn bộ nội dung email (có mã OTP) ra log:
  - Visual Studio / `dotnet run`: cửa sổ console của AuthService.
  - Docker: `docker compose logs -f auth-service`.
- BookingService không có chế độ này: booking vẫn xác nhận được, nhưng notification chuyển `FAILED`.
- Môi trường khác Development mà thiếu SMTP: API gửi OTP trả **503**.

## 4. Luồng cho Flutter (gọi qua gateway `http://localhost:5000`)

### Đăng ký và xác thực email

1. `POST /api/v1/auth/register`, body `{ "email", "password", "fullName", "phone" }` → **200**. API **không trả token nữa**:
   ```json
   { "email": "khach@gmail.com", "message": "Đăng ký thành công. Mã OTP xác thực đã được gửi tới email của bạn.", "expiresInSeconds": 300, "resendAfterSeconds": 60 }
   ```
   Chuyển sang màn hình nhập OTP, nhớ giữ lại `email` và `password` trong state.
2. `POST /api/v1/auth/verify-email`, body `{ "email", "otp", "password" }` → **200** trả về giống đăng nhập (`accessToken`, `refreshToken`, `user`), tức là đăng nhập luôn. Hệ thống gửi thêm email chào mừng.
   - Phải gửi kèm `password` đã dùng khi đăng ký. Nhờ vậy người khác không thể đăng ký trước bằng email của bạn rồi chiếm tài khoản sau khi bạn xác thực.
3. Gửi lại mã: `POST /api/v1/auth/resend-verification`, body `{ "email" }` → **200**, response giống bước 1. Nút "Gửi lại mã" nên đếm ngược theo `resendAfterSeconds`.

Đăng ký lại một email **chưa xác thực** vẫn được: thông tin mới thay thông tin cũ và hệ thống gửi mã mới.

### Đăng nhập khi chưa xác thực email

`POST /api/v1/auth/login` trả **403**:

```json
{ "title": "Forbidden", "status": 403, "detail": "Email chưa được xác thực. Vui lòng nhập mã OTP đã gửi tới email của bạn.", "errorCode": "EMAIL_NOT_VERIFIED" }
```

Khi đó chuyển sang màn hình OTP, gọi `resend-verification` để lấy mã mới, rồi gọi `verify-email` với mật khẩu vừa nhập ở form đăng nhập.

### Quên mật khẩu

1. `POST /api/v1/auth/forgot-password`, body `{ "email" }` → **luôn 200**, kể cả khi email chưa đăng ký, để không ai dò được email nào đã có tài khoản.
2. `POST /api/v1/auth/reset-password`, body `{ "email", "otp", "newPassword" }` → **200** `{ "message": "..." }`. Mọi thiết bị bị đăng xuất (refresh token cũ hết hiệu lực), người dùng đăng nhập lại bằng mật khẩu mới.
   - Tài khoản chưa xác thực cũng dùng được luồng này. Đặt lại mật khẩu thành công thì email được coi là đã xác thực.

### Email xác nhận đặt vé

BookingService gửi email chi tiết vé ngay khi booking được xác nhận:

- **Khách thanh toán PayOS:** sau khi trả tiền xong, app gọi `POST /api/v1/payments/payos/{orderCode}/verify`. PayOS báo đã nhận tiền thì booking tự chuyển sang CONFIRMED và email vé được gửi về **email trong token** của khách. Muốn gửi tới email khác thì thêm `?recipientEmail=...`. Khách không tự gọi `/bookings/{id}/confirm` được.
- **Staff xác nhận tại quầy** (khách trả tiền mặt): `POST /api/v1/bookings/{id}/confirm?paymentMethod=CASH&recipientEmail=<email khách>`.

Gửi email lỗi không làm hỏng booking, trạng thái gửi xem ở `/api/v1/notifications`. Gọi xác minh lại nhiều lần cũng không gửi trùng email.

### Mã lỗi

| HTTP | Khi nào | Client nên làm |
|---|---|---|
| 400 | OTP sai (`detail` ghi số lần thử còn lại), hết hạn hoặc hết lượt; email đã được đăng ký; dữ liệu không hợp lệ | Hiện `detail` cho người dùng |
| 403 + `errorCode: EMAIL_NOT_VERIFIED` | Đăng nhập khi chưa xác thực email | Chuyển sang màn hình OTP |
| 404 | `resend-verification` với email chưa đăng ký | Chuyển sang màn hình đăng ký |
| 429 + header `Retry-After` | Xin mã mới khi chưa hết thời gian chờ (AuthService), hoặc vượt **10 request/phút/IP** cho các API auth (gateway) | Đợi đủ số giây trong `Retry-After` |
| 503 | Không gửi được email (Gmail lỗi hoặc sai cấu hình) | Báo người dùng thử lại sau |

## 5. Quy tắc OTP

- 6 chữ số, hết hạn sau **5 phút**, nhập tối đa **5 lần**, phải chờ **60 giây** giữa hai lần gửi. Mã mới thay mã cũ, mỗi mã chỉ dùng một lần.
- DB chỉ lưu **hash** (BCrypt) của mã, trong bảng `otp_codes`.
- Thay đổi các giá trị trên ở mục `Otp` trong `appsettings.json` của AuthService (`ExpiryMinutes`, `MaxAttempts`, `ResendCooldownSeconds`).

## 6. Cập nhật database

Tính năng này thêm cột `users.email_verified` và bảng `otp_codes` (repo **Project-Cinema-DB**):

- **Docker:** chạy `docker compose down -v` rồi `docker compose up -d --build` để tạo lại DB từ file SQL mới. Lệnh này xoá dữ liệu test cũ.
- **DB trên máy tạo từ bản SQL cũ:** chạy `migrations/2026-10-01_cinema_auth_db.sql` trên `cinema_auth_db`. Script chạy nhiều lần vẫn an toàn, và các tài khoản có sẵn được coi là đã xác thực:
  ```powershell
  # Chạy trong thư mục Project-Cinema-DB
  $env:PGPASSWORD = "<mat_khau_postgres>"; $env:PGCLIENTENCODING = "UTF8"
  & "C:\Program Files\PostgreSQL\18\bin\psql.exe" -h localhost -U postgres -d cinema_auth_db -f migrations/2026-10-01_cinema_auth_db.sql
  ```
- Chưa chạy migration thì AuthService báo lỗi `42703: column u.email_verified does not exist`.

## 7. Lỗi thường gặp

| Lỗi (trong log AuthService / BookingService) | Nguyên nhân | Cách sửa |
|---|---|---|
| `535 5.7.8 Username and Password not accepted` | Sai App Password, còn dấu cách, hoặc dùng mật khẩu Gmail thường | Nhập lại App Password viết liền, hoặc tạo App Password mới |
| `534 5.7.9 Application-specific password required` | Đang dùng mật khẩu Gmail thường | Dùng App Password (mục 2) |
| API trả 503 sau khoảng 10 giây, log có `TaskCanceledException` | Mạng chặn cổng 587 (hay gặp ở wifi trường, công ty) | Thử mạng khác (4G) hoặc kiểm tra firewall |
| `550 5.4.5 Daily user sending limit exceeded` | Gmail giới hạn khoảng 500 email/ngày | Đợi 24 giờ |
| Người nhận không thấy email | Email rơi vào Spam / Quảng cáo | Đánh dấu "Không phải spam" |
| Vẫn thấy log `SMTP chưa được cấu hình` dù đã đặt key | Đặt nhầm project, sai tên key, hoặc chưa chạy lại service | Kiểm tra bằng `dotnet user-secrets list --project AuthService/AuthService` |
