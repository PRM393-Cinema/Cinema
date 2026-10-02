# Test tự động

Mỗi service có một project test xUnit nằm cạnh project chính, và đã được thêm vào file `.sln` của service đó. Trong Visual Studio, mở **Test Explorer** rồi bấm *Run All*.

| Service | Project test | Số test |
|---|---|---|
| AuthService | `AuthService/AuthService.Tests` | 8 |
| MovieService | `MovieService/MovieService.Tests` | 6 |
| BookingService | `BookingService/BookingService.Tests` | 41 |

## 1. Chạy test

Test tích hợp dùng **PostgreSQL thật**, và một phần dùng **RabbitMQ thật**. Testcontainers tự bật container riêng cho mỗi lần chạy rồi tự xoá khi xong. Vì vậy:

- **Docker Desktop phải đang mở.** Không cần database hay `.env` của bạn: test không đụng vào DB đang dùng để phát triển.
- Test dùng image `postgres:17-alpine` và `rabbitmq:4-management-alpine`. Đã chạy `docker compose up` thì máy có sẵn 2 image này.

```powershell
dotnet test AuthService/AuthService.sln
dotnet test MovieService/MovieService.sln
dotnet test BookingService/BookingService.sln
```

Mỗi service chạy xong trong khoảng 15–30 giây.

## 2. Test những gì (SRS §18)

| Mức | Nội dung | Ở đâu |
|---|---|---|
| Unit | Chữ ký webhook PayOS: so với ví dụ trong tài liệu PayOS, chặn dữ liệu bị sửa, sai key, body hỏng | `BookingService.Tests/Unit/PayOsSignatureTests.cs` |
| Unit | Email: đủ thông tin vé, encode dữ liệu người dùng nhập (chống chèn HTML) | `BookingService.Tests/Unit/EmailTemplatesTests.cs` |
| Integration (EF Core + PostgreSQL) | Đặt vé, giữ ghế (409 khi ghế bận), giờ chiếu / tên phim lấy từ server, webhook xác nhận vé, hết hạn giữ ghế, trả tiền muộn tự tạo yêu cầu hoàn | `BookingService.Tests/Integration/BookingFlowTests.cs` |
| Integration | Huỷ vé theo chính sách 2 giờ, hoàn tiền, Staff xác nhận đã hoàn, huỷ suất chiếu kéo theo huỷ booking. Consumer xử lý message trùng không gửi email / hoàn tiền lần hai | `BookingService.Tests/Integration/RefundTests.cs` |
| Integration (RabbitMQ) | Event đi qua RabbitMQ thật: email vé, yêu cầu hoàn tiền được tạo bất đồng bộ | `BookingService.Tests/Integration/RabbitMqFlowTests.cs` |
| Contract / API | Mã trạng thái 400 / 401 / 403 / 404 / 409 / 503, phân trang tối đa 50 | Các file Integration |
| Security | Thiếu token, token giả chữ ký, token hết hạn: 401. Khách gọi API của Staff / Admin, xem dữ liệu của người khác: 403 | `BookingService.Tests/Integration/AuthorizationTests.cs`, `AuthService.Tests/Integration/*` |
| Failure | MovieService chết: đặt vé trả 503. PayOS chết: thanh toán trả 503 và booking vẫn thanh toán lại được | `BookingFlowTests.cs` |
| Auth | Đăng ký, OTP (khoá sau 5 lần sai), đăng nhập, refresh token xoay vòng, đăng xuất, Admin tạo / khoá tài khoản | `AuthService.Tests/Integration/*` |
| Suất chiếu | Quyền, trùng lịch 409, suất còn đặt được theo phim, huỷ mềm và ghi event `showtime.cancelled` | `MovieService.Tests/Integration/ShowtimeTests.cs` |

Trong test, MovieService, PayOS và SMTP được thay bằng bản giả: không gọi PayOS thật, không gửi email thật. JWT trong test được ký bằng key riêng của test.

## 3. CI trên GitHub

Workflow `.github/workflows/ci.yml` tự build và chạy toàn bộ test khi:
- mở pull request vào `dev` hoặc `main`;
- push lên `dev`.

Kết quả hiện ở tab **Checks** của pull request. Test lỗi thì file kết quả (`.trx`) nằm trong mục *Artifacts* của lần chạy.

## 4. Viết thêm test

- Test gọi API: thêm class vào thư mục `Integration`, gắn `[Collection(...)]` giống các file có sẵn để dùng chung container. Mỗi test tự tạo dữ liệu riêng (suất chiếu mới, ghế mới), không dựa vào dữ liệu của test khác.
- Token cho từng vai trò: `TestUsers.CustomerAToken`, `TestUsers.StaffToken`, `TestUsers.AdminToken` (BookingService) hoặc `TestJwt.Create(...)`.
- Event: đọc từ outbox bằng `OutboxEventsAsync`, rồi chạy consumer bằng `HandleAsync<THandler>` (không cần RabbitMQ).
