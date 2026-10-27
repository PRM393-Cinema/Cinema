# Test tự động

Mỗi service có một project test xUnit nằm cạnh project chính, và đã được thêm vào file `.sln` của service đó. Trong Visual Studio, mở **Test Explorer** rồi bấm *Run All*.

| Service | Project test | Số test |
|---|---|---|
| AuthService | `AuthService/AuthService.Tests` | 28 |
| ApiGateway | `ApiGateway/ApiGateway.Tests` | 21 |
| MovieService | `MovieService/MovieService.Tests` | 21 |
| BookingService | `BookingService/BookingService.Tests` | 69 |

## 1. Chạy test

Test tích hợp dùng **PostgreSQL thật**, và một phần dùng **RabbitMQ thật**. Testcontainers tự bật container riêng cho mỗi lần chạy rồi tự xoá khi xong. Vì vậy:

- **Docker Desktop phải đang mở.** Không cần database hay `.env` của bạn: test không đụng vào DB đang dùng để phát triển.
- Test dùng image `postgres:17-alpine` và `rabbitmq:4-management-alpine`. Đã chạy `docker compose up` thì máy có sẵn 2 image này.

```powershell
dotnet test AuthService/AuthService.sln
dotnet test ApiGateway/ApiGateway.sln
dotnet test MovieService/MovieService.sln
dotnet test BookingService/BookingService.sln
```

Mỗi service chạy xong trong khoảng 15–30 giây.

## 2. Test những gì (SRS §18)

| Mức | Nội dung | Ở đâu |
|---|---|---|
| Unit | Chữ ký webhook PayOS: so với ví dụ trong tài liệu PayOS, chặn dữ liệu bị sửa, sai key, body hỏng | `BookingService.Tests/Unit/PayOsSignatureTests.cs` |
| Unit | Email: đủ thông tin vé, email xác nhận kèm ảnh QR (PNG nhúng `cid:`), encode dữ liệu người dùng nhập (chống chèn HTML) | `BookingService.Tests/Unit/EmailTemplatesTests.cs` |
| Integration (EF Core + PostgreSQL) | Đặt vé, giữ ghế (409 khi ghế bận), giờ chiếu / tên phim lấy từ server, webhook xác nhận vé, hết hạn giữ ghế, trả tiền muộn tự tạo yêu cầu hoàn | `BookingService.Tests/Integration/BookingFlowTests.cs` |
| Integration | Huỷ vé theo chính sách 2 giờ, hoàn tiền, Staff xác nhận đã hoàn, huỷ suất chiếu kéo theo huỷ booking. Consumer xử lý message trùng không gửi email / hoàn tiền lần hai | `BookingService.Tests/Integration/RefundTests.cs` |
| Integration (RabbitMQ) | Event đi qua RabbitMQ thật: email vé, yêu cầu hoàn tiền được tạo bất đồng bộ | `BookingService.Tests/Integration/RabbitMqFlowTests.cs` |
| Contract / API | Mã trạng thái 400 / 401 / 403 / 404 / 409 / 503, phân trang tối đa 50 | Các file Integration |
| Security | Thiếu token, token giả chữ ký, token hết hạn: 401. Khách gọi API của Staff / Admin, xem dữ liệu của người khác: 403 | `BookingService.Tests/Integration/AuthorizationTests.cs`, `AuthService.Tests/Integration/*` |
| Failure | MovieService chết: đặt vé trả 503. PayOS chết: thanh toán trả 503 và booking vẫn thanh toán lại được | `BookingFlowTests.cs` |
| Auth | Đăng ký, OTP (khoá sau 5 lần sai), đăng nhập, refresh token xoay vòng, đăng xuất, Admin tạo / khoá tài khoản | `AuthService.Tests/Integration/*` |
| Validate tài khoản | Đăng ký, đăng nhập, quên / đặt lại mật khẩu, Admin tạo tài khoản: email sai định dạng (`a b@test.local`, `abc@def`) hoặc dài hơn 150 ký tự, mật khẩu ngoài 6–72 ký tự (tính cả byte của chữ có dấu), họ tên trống hoặc dài hơn 150, số điện thoại không đủ 8–15 chữ số đều bị 400 kèm lỗi theo trường, không tạo tài khoản, không gửi email | `AuthService.Tests/Integration/AccountValidationTests.cs` |
| Khóa tài khoản | Token còn hạn bị từ chối ở gateway sau khi khóa; lỗi kết nối AuthService trả 503 và không chuyển tiếp request | `ApiGateway.Tests/*`, `AuthService.Tests/Integration/UserManagementTests.cs` |
| Đổi role | Role cũ bị từ chối với `403 ROLE_CHANGED`; thu hồi refresh token khi quyền thay đổi, giữ phiên khi lưu cùng quyền | `ApiGateway.Tests/*`, `AuthService.Tests/Integration/UserManagementTests.cs` |
| Check-in | Staff tra vé theo mã (QR), check-in một lần; vé chưa trả tiền, đã huỷ, chưa tới giờ hoặc đã check-in bị 409; khách không tra / check-in được; sơ đồ ghế đã đặt của suất (kèm email khách); thống kê vé theo suất (đã bán, đang giữ, đã check-in) theo id và theo giờ chiếu | `BookingService.Tests/Integration/CheckInTests.cs` |
| Phim | Ngừng / chiếu lại phim chỉ Admin; phân loại phim mặc định P, bỏ trống khi sửa thì giữ nguyên, mức không có (vd `C18`) bị 400 | `MovieService.Tests/Integration/AdminCatalogTests.cs` |
| Suất chiếu | Quyền, trùng lịch 409, suất còn đặt được theo phim, huỷ mềm và ghi event `showtime.cancelled` | `MovieService.Tests/Integration/ShowtimeTests.cs` |
| Sơ đồ ghế | Sinh ghế một lần, đổi loại ghế; đổi số ghế lấp hàng cuối rồi sang hàng mới, bớt từ ghế cuối, chỉ Admin, không quá hàng Z, chặn khi phòng có suất chiếu. Sweetbox theo cặp (1-2, 3-4): đổi loại cả cặp (cả khi tô nhiều ghế một lần; hàng có ghế lẻ cặp bị từ chối), xoá / bớt ghế làm nửa cặp còn lại thành ghế thường, đặt vé phải đủ cặp. Giá ghế theo loại: VIP +20%, sweetbox +30% mỗi ghế, phụ thu làm tròn tới 1.000đ | `MovieService.Tests/Integration/SeatTests.cs` |
| Bán vé tại quầy | Vé khách vãng lai (không tài khoản, số điện thoại sai bị 400); thu tiền mặt: thiếu tiền 400, khách gọi 403, trả lần hai 409, payment CASH tính vào doanh thu, email vé tới email khách cho ở quầy, check-in ngay; vé vãng lai không email thì không gửi email nhưng vẫn hoàn tiền được; Staff tạo QR chuyển khoản (có `qrCode`) rồi khách trả tiền mặt thì link PayOS bị huỷ; khách đã chuyển khoản thì tiền mặt bị 409 | `BookingService.Tests/Integration/CounterSaleTests.cs` |
| Mã đơn PayOS | Mã đơn = id booking × 1.000.000 + 6 số cuối mã vé, gọi lại không đổi; webhook của đơn môi trường khác bị bỏ qua; xác minh bằng mã đơn hoặc id booking; payment cũ (mã = id booking) vẫn dùng được | `BookingService.Tests/Integration/PayOsOrderCodeTests.cs` |
| Bắp nước | Chỉ Admin sửa menu, khách chỉ thấy món đang bán; tiền bắp nước cộng vào tổng tiền theo giá menu, đổi giá menu không đổi đơn cũ, email vé liệt kê bắp nước; món ngừng bán / không có / quá số lượng / trùng món bị 400 | `BookingService.Tests/Integration/ConcessionTests.cs` |
| Khuyến mãi | Chỉ Admin quản lý, mã trùng bị 409, khách chỉ thấy khuyến mãi tự áp dụng đang chạy; mã voucher chỉ giảm tiền vé (không giảm bắp nước), có trần, cần đủ số vé, lượt dùng đếm khi đã thanh toán và hết lượt thì bị 400, email vé có dòng giảm giá; khuyến mãi tự áp dụng chọn cái giảm nhiều nhất, đúng thứ của ngày chiếu, nhập mã thì thay cho khuyến mãi tự áp dụng | `BookingService.Tests/Integration/PromotionTests.cs` |
| Điểm thành viên | Cộng điểm khi đã thanh toán theo hạng (5% / 7% / 10%), lên VIP khi tổng chi tiêu đủ 2.000.000đ; dùng điểm tối đa 50%, không quá số điểm đang có; giữ chỗ hết hạn thì trả điểm; quầy huỷ vé đã trả thì trả điểm đã dùng, thu hồi điểm đã cộng; quầy dùng điểm của thành viên và trả tiền mặt; chỉ Admin chỉnh điểm, phải có lý do, không để điểm âm; khách không xem thẻ người khác; vé vãng lai không dùng điểm | `BookingService.Tests/Integration/LoyaltyTests.cs` |
| Tra cứu thành viên | Staff tìm khách theo số điện thoại, bỏ qua dấu ngăn cách, chỉ trả tài khoản khách hàng; số quá ngắn bị 400; khách hàng bị 403 | `AuthService.Tests/Integration/MemberLookupTests.cs` |
| Doanh thu | Dashboard Admin: doanh thu tăng đúng số tiền vé vừa thanh toán; Staff / khách bị 403; khoảng thời gian ngược bị 400 | `BookingService.Tests/Integration/PaymentSummaryTests.cs` |
| Giám sát | `/metrics` mở cho Prometheus và đếm booking theo trạng thái; chỉ trả ở cổng nội bộ khi cấu hình `MetricsPort` | `BookingService.Tests/Integration/ObservabilityTests.cs` |

Trong test, MovieService, PayOS và SMTP được thay bằng bản giả: không gọi PayOS thật, không gửi email thật. JWT trong test được ký bằng key riêng của test.

## 3. CI trên GitHub

Workflow `.github/workflows/ci.yml` (ở gốc repo) tự build và chạy toàn bộ test khi:
- mở pull request vào `dev` hoặc `main`;
- push lên `dev`.

Workflow chỉ chạy khi có thay đổi trong `Cinema_BE/` (hoặc chính file workflow); pull request chỉ sửa `Cinema_Mobile/` thì không chạy.

Kết quả hiện ở tab **Checks** của pull request. Test lỗi thì file kết quả (`.trx`) nằm trong mục *Artifacts* của lần chạy.

## 4. Viết thêm test

- Test gọi API: thêm class vào thư mục `Integration`, gắn `[Collection(...)]` giống các file có sẵn để dùng chung container. Mỗi test tự tạo dữ liệu riêng (suất chiếu mới, ghế mới), không dựa vào dữ liệu của test khác.
- Token cho từng vai trò: `TestUsers.CustomerAToken`, `TestUsers.StaffToken`, `TestUsers.AdminToken` (BookingService) hoặc `TestJwt.Create(...)`.
- Event: đọc từ outbox bằng `OutboxEventsAsync`, rồi chạy consumer bằng `HandleAsync<THandler>` (không cần RabbitMQ).
