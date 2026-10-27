# ĐẶC TẢ YÊU CẦU PHẦN MỀM (SRS)

## Hệ thống đặt vé và quản lý rạp chiếu phim CosmoQ Cinema

| Mục | Nội dung |
|---|---|
| Phiên bản | 2.0 (bản tổng hợp) |
| Ngày | 26/10/2026 |
| Môn học | PRM393 |
| Trạng thái | Mô tả hệ thống đã triển khai trên nhánh `dev` (merge PR #18) |
| Thay thế | SRS 1.0 (`Cinema_BE/Cinema_Microservice_SRS_Complete.md`, bản thiết kế ban đầu) |
| Bản tiếng Anh | [SRS_EN.md](SRS_EN.md) (cùng cấu trúc, cùng mã yêu cầu) |

### Lịch sử phiên bản

| Phiên bản | Nội dung |
|---|---|
| 1.0 | Thiết kế ban đầu: 6 microservice dự kiến, yêu cầu cốt lõi về phim, phòng/ghế, suất chiếu, đặt vé, thanh toán, thông báo. |
| 2.0 | Tổng hợp theo hệ thống thật: kiến trúc 3 service nghiệp vụ + gateway; xác thực email bằng OTP, khoá tài khoản; loại ghế và giá theo loại; hoàn tiền có duyệt; bán vé tại quầy (tiền mặt, chuyển khoản, khách vãng lai); check-in bằng QR; dashboard vận hành; giám sát; kiểm thử. |

---

## 1. Giới thiệu

### 1.1 Mục đích

Tài liệu mô tả đầy đủ yêu cầu chức năng, phi chức năng, quy tắc nghiệp vụ, vai trò người dùng và giao diện của hệ thống CosmoQ Cinema. Tài liệu dùng làm căn cứ chung cho phát triển, kiểm thử, demo và chấm điểm. Mỗi yêu cầu có mã riêng để đối chiếu với code, test và tài liệu kỹ thuật.

### 1.2 Phạm vi sản phẩm

CosmoQ Cinema gồm ba phần:

- **App khách** (Flutter: Android, web, Windows): xem phim và lịch chiếu, chọn ghế, giữ ghế 10 phút, thanh toán qua PayOS, xem vé có mã QR, huỷ vé và yêu cầu hoàn tiền, xem thông báo và lịch sử thanh toán.
- **Trang quản trị web** (Flutter web, cùng mã nguồn): nhân viên bán vé tại quầy, thu tiền, check-in, quản lý suất chiếu và sơ đồ ghế, xử lý hoàn tiền; quản trị viên quản lý phim, phòng, tài khoản và xem doanh thu.
- **Backend microservice** (ASP.NET Core 8): API Gateway và ba service nghiệp vụ, mỗi service sở hữu database riêng, giao tiếp bất đồng bộ qua RabbitMQ.

### 1.3 Thuật ngữ và viết tắt

| Thuật ngữ | Ý nghĩa |
|---|---|
| Booking / vé | Một đơn đặt chỗ gồm một hoặc nhiều ghế của một suất chiếu. Mã vé dạng `BK-yyyyMMddHHmmss-xxxxxx`. |
| Giữ ghế (hold) | Ghế được khoá cho một booking `PENDING` trong 10 phút, chờ thanh toán. |
| Khách vãng lai (walk-in) | Khách mua vé tại quầy, không có tài khoản; vé không gắn `userId`. |
| Sweetbox | Ghế đôi: ghế số lẻ ghép với ghế chẵn bên phải trong cùng hàng (1-2, 3-4…). |
| OTP | Mã 6 chữ số gửi qua email để xác thực email hoặc đặt lại mật khẩu. |
| JWT | JSON Web Token, access token có hạn 60 phút. |
| Refresh token | Token làm mới phiên, hạn 7 ngày, xoay vòng sau mỗi lần dùng. |
| PayOS | Cổng thanh toán chuyển khoản ngân hàng qua VietQR. |
| Outbox | Bảng lưu event trong cùng transaction với dữ liệu, gửi lên RabbitMQ sau khi commit. |
| DLQ | Dead-letter queue: nơi chứa message xử lý lỗi sau 3 lần thử. |
| RBAC | Phân quyền theo vai trò (Customer, Staff, Admin). |

### 1.4 Tài liệu tham chiếu

| Tài liệu | Nội dung |
|---|---|
| [README.md](../README.md) | Cài đặt và cấu trúc repo |
| [DEMO.md](../DEMO.md) | Chuẩn bị và kịch bản demo |
| [Cinema_BE/docs/DOCKER.md](../Cinema_BE/docs/DOCKER.md) | Chạy backend bằng Docker, cổng, tài khoản seed |
| [Cinema_BE/docs/EMAIL_SETUP.md](../Cinema_BE/docs/EMAIL_SETUP.md) | Email, OTP, quy tắc dữ liệu tài khoản |
| [Cinema_BE/docs/PAYOS.md](../Cinema_BE/docs/PAYOS.md) | Thanh toán, webhook, hoàn tiền |
| [Cinema_BE/docs/MESSAGING.md](../Cinema_BE/docs/MESSAGING.md) | Event RabbitMQ, outbox, idempotency |
| [Cinema_BE/docs/MONITORING.md](../Cinema_BE/docs/MONITORING.md) | Metrics, trace, log |
| [Cinema_BE/docs/TESTING.md](../Cinema_BE/docs/TESTING.md) | Test tự động và CI |
| [Cinema_Mobile/docs/MOBILE_UI_ENDPOINTS.md](../Cinema_Mobile/docs/MOBILE_UI_ENDPOINTS.md) | Toàn bộ 89 endpoint và màn hình đang dùng |
| [Cinema_Mobile/docs/STAFF_WORKSPACE.md](../Cinema_Mobile/docs/STAFF_WORKSPACE.md) | Nghiệp vụ trang quản trị |
| `Resource/PRM393.docx` | Yêu cầu môn học: ma trận quyền, thành phần kỹ thuật bắt buộc |

---

## 2. Mô tả tổng quan

### 2.1 Kiến trúc

```text
 App khách (Android / web / Windows)      Trang quản trị web (Staff / Admin)
                    \                         /
                     \   HTTPS / REST + JWT  /
                      v                     v
            +----------------------------------------+
            |  API Gateway (YARP)  :5000             |
            |  JWT, phân quyền theo route, rate limit,|
            |  kiểm tra khoá tài khoản, CorrelationId |
            +----------------------------------------+
                 |                |                 |
                 v                v                 v
          AuthService       MovieService      BookingService ---> PayOS (VietQR, webhook)
          :5100             :5168             :5063           ---> SMTP (Gmail)
          auth_db           movie_db          booking_db
                            showtime_db       payment_db
                                              notification_db
                 \                |                 /
                  +------ RabbitMQ (cinema.events) +
          PostgreSQL 17 (một database cho mỗi phần dữ liệu)
          Prometheus, Grafana, Jaeger (giám sát, tuỳ chọn)
```

### 2.2 Thành phần

| Thành phần | Trách nhiệm | Dữ liệu |
|---|---|---|
| API Gateway | Điểm vào duy nhất từ client; định tuyến 24 route; kiểm tra JWT và quyền theo route; giới hạn tần suất; kiểm tra tài khoản bị khoá / đổi quyền ở mỗi request; health check service | Không có |
| AuthService | Đăng ký, OTP, đăng nhập, refresh token, đặt lại mật khẩu, quản lý tài khoản và vai trò | `cinema_auth_db`: users, roles, users_roles, refresh_tokens, otp_codes |
| MovieService | Phim; phòng, ghế, loại ghế; suất chiếu và giá theo loại ghế; phát event huỷ suất chiếu | `cinema_movie_db`: movies. `cinema_showtime_db`: rooms, seats, showtimes, outbox |
| BookingService | Đặt vé, giữ ghế, check-in; thanh toán PayOS và tiền mặt; hoàn tiền; thông báo email | `cinema_booking_db`: bookings, booking_seats, seat_reservations, outbox. `cinema_payment_db`: payments, refunds, outbox. `cinema_notification_db`: notifications |
| RabbitMQ | Event bất đồng bộ giữa các service (exchange `cinema.events`) | Queue và DLQ |
| App Flutter | App khách (`lib/main.dart`) và trang quản trị (`lib/main_admin.dart`) | Lưu token bằng secure storage |
| Giám sát | Prometheus (metrics), Grafana (dashboard), Jaeger (trace) | Bộ nhớ trong / volume |

### 2.3 Người dùng

| Vai trò | Mô tả | Dùng ở đâu |
|---|---|---|
| Khách chưa đăng nhập | Xem phim, lịch chiếu, giá | App khách |
| Customer | Đặt vé, thanh toán, quản lý vé và giao dịch của mình | App khách |
| Khách vãng lai | Mua vé tại quầy, không có tài khoản; nhận vé qua email (nếu cho), vé in hoặc QR trên màn hình | Thông qua Staff |
| Staff | Bán vé, thu tiền, check-in, quản lý suất chiếu và sơ đồ ghế, xử lý hoàn tiền, gửi thông báo | Trang quản trị; app điện thoại chỉ để quét QR check-in |
| Admin | Toàn quyền Staff, cộng quản lý phim, phòng, tài khoản, xem doanh thu, hoàn tiền thủ công | Trang quản trị |
| Hệ thống | Job hết hạn giữ ghế, xử lý event, webhook PayOS | Backend |

Một tài khoản có thể có nhiều vai trò. Tài khoản Staff/Admin đăng nhập app khách sẽ thấy hướng dẫn mở trang quản trị và nút **Check in tickets**. Tài khoản Customer mở trang quản trị sẽ được chỉ về trang khách.

### 2.4 Môi trường vận hành

- Backend: .NET 8, PostgreSQL 17, RabbitMQ 4, chạy bằng Docker Compose (`docker compose up -d --build`), múi giờ `Asia/Ho_Chi_Minh`.
- Client: Flutter 3.38+ (Dart 3.13). App khách chạy trên Android, trình duyệt (Chrome / Edge) và Windows. Trang quản trị chạy trên trình duyệt máy tính.
- Android emulator gọi gateway qua `http://10.0.2.2:5000`; điện thoại thật dùng `--dart-define=API_BASE_URL=http://<IP máy>:5000`.
- Camera trên web chỉ hoạt động với `localhost` hoặc HTTPS.

### 2.5 Ràng buộc thiết kế

- **C-01** Client chỉ gọi qua API Gateway; các service và PostgreSQL chỉ mở ở `127.0.0.1`.
- **C-02** Mỗi service sở hữu database riêng; không có khoá ngoại xuyên database. Tham chiếu giữa service (userId, showtimeId, seatId…) được kiểm tra qua API hoặc event.
- **C-03** Cấu trúc service: Controller → Service → Repository, DTO, validator, global exception handler.
- **C-04** Secret (`.env`) không commit; chia sẻ trong nhóm bằng SOPS + age (`secrets.enc.env`).
- **C-05** Thời gian dùng giờ địa phương Việt Nam ở cả container và dữ liệu seed.

### 2.6 Giả định và phụ thuộc

- PayOS và SMTP (Gmail App Password) là dịch vụ ngoài. Thiếu khoá PayOS thì chỉ thanh toán PayOS lỗi; thiếu SMTP thì email không gửi thật (OTP in ra log ở môi trường Development).
- Webhook PayOS cần địa chỉ public (tunnel khi chạy local). Không có webhook, app vẫn xác nhận thanh toán bằng cách hỏi PayOS (verify).
- Tài khoản PayOS dùng chung cho nhiều môi trường (máy từng người, Docker) mà PayOS không cho trùng mã đơn, nên mã đơn được sinh để không trùng giữa các môi trường (FR-PAY-01).

### 2.7 Ngoài phạm vi

- Tích điểm thành viên và khuyến mãi (để phát triển sau).
- Đổi mật khẩu bằng mật khẩu hiện tại; sửa hồ sơ cá nhân.
- Push notification và trạng thái đã đọc của thông báo.
- Hoàn tiền tự động qua cổng thanh toán (PayOS không có API hoàn tiền).
- Kế toán, nhân sự, kho; thiết bị POS chuyên dụng; Kubernetes, service mesh.

---

## 3. Quy tắc nghiệp vụ

| Mã | Quy tắc |
|---|---|
| BR-01 | Tài khoản khách phải xác thực email bằng OTP trước khi đăng nhập. Tài khoản do Admin tạo không cần OTP. |
| BR-02 | Mọi API cần đăng nhập dùng JWT; gateway và service đều kiểm tra. |
| BR-03 | Quyền truy cập theo vai trò; Customer không dùng được API quản trị. |
| BR-04 | Mỗi ghế thuộc một phòng, không trùng vị trí (hàng + số) trong phòng. |
| BR-05 | Một suất chiếu thuộc một phim và một phòng, giờ bắt đầu phải trước giờ kết thúc. |
| BR-06 | Một phòng không có hai suất chiếu trùng thời gian (409). |
| BR-07 | Một ghế của một suất chiếu chỉ thuộc một booking còn hiệu lực (đang giữ hoặc đã bán). |
| BR-08 | Booking gắn với một suất chiếu và các ghế; gắn với tài khoản khách, trừ vé khách vãng lai bán tại quầy. |
| BR-09 | Thanh toán gắn với booking; trạng thái booking và payment chỉ chuyển theo sơ đồ ở mục 7. |
| BR-10 | Webhook PayOS phải đúng chữ ký HMAC-SHA256 trước khi dùng dữ liệu. |
| BR-11 | Event được ghi vào outbox trong cùng transaction với dữ liệu và chỉ gửi sau khi commit. |
| BR-12 | Lời gọi tới service khác hoặc PayOS có retry giới hạn và circuit breaker. |
| BR-13 | Lỗi gửi email hoặc RabbitMQ tạm dừng không làm hỏng giao dịch đặt vé / thanh toán. |
| BR-14 | Ghế được giữ 10 phút; quá hạn chưa thanh toán thì booking `EXPIRED` và ghế được nhả. |
| BR-15 | Giá ghế: giá suất chiếu là giá ghế thường; VIP +20%, sweetbox +30% mỗi ghế; phụ thu làm tròn tới 1.000đ. Server tự tính giá, không nhận giá từ client. |
| BR-16 | Sweetbox luôn được đặt, đổi loại và bán theo cặp. |
| BR-17 | Khách tự huỷ vé đã thanh toán khi còn ít nhất 2 giờ trước giờ chiếu và được hoàn 100%; muộn hơn phải liên hệ rạp. Staff/Admin huỷ được mọi lúc. |
| BR-18 | Mỗi payment có tối đa một yêu cầu hoàn tiền. Hoàn tiền được thực hiện bằng chuyển khoản thủ công và ghi nhận mã giao dịch. |
| BR-19 | Suất chiếu bị huỷ thì mọi vé còn hiệu lực của suất đó bị huỷ; vé đã thanh toán được tạo yêu cầu hoàn tiền. |
| BR-20 | Trả tiền muộn (booking đã hết hạn): ghế còn trống thì vẫn xác nhận vé; ghế đã bán cho người khác thì tự tạo yêu cầu hoàn 100%. |
| BR-21 | Check-in chỉ cho vé `CONFIRMED`, mỗi vé một lần, từ 3 giờ trước đến 2 giờ sau giờ chiếu. |
| BR-22 | Thu tiền mặt phải đủ tổng tiền vé. Vé đang có QR chuyển khoản chưa trả thì huỷ link PayOS trước khi ghi tiền mặt; khách đã chuyển khoản thì không thu tiền mặt. |
| BR-23 | Tiền mặt và chuyển khoản đều tạo bản ghi thanh toán, nên được tính vào doanh thu và hoàn tiền như nhau. |
| BR-24 | Khoá tài khoản hoặc đổi vai trò có hiệu lực ngay ở request tiếp theo, kể cả khi token cũ còn hạn. |
| BR-25 | Không tiết lộ email nào đã đăng ký: quên mật khẩu luôn trả 200; sai email hoặc mật khẩu trả cùng một thông báo. |
| BR-26 | Phim ngừng chiếu chỉ chuyển `INACTIVE`, không xoá; vé đã đặt giữ nguyên. Phòng có suất chiếu không xoá và không sửa sơ đồ ghế được. |

---

## 4. Yêu cầu chức năng

Mức ưu tiên: **H** (bắt buộc), **M** (quan trọng), **L** (bổ trợ).

### 4.1 Xác thực và phiên đăng nhập

| Mã | Yêu cầu | Ưu tiên |
|---|---|---|
| FR-AUTH-01 | Khách đăng ký bằng email, mật khẩu, họ tên, số điện thoại (không bắt buộc). Hệ thống gửi OTP xác thực, chưa cấp token. | H |
| FR-AUTH-02 | Đăng nhập bằng email + mật khẩu, nhận access token (JWT, 60 phút) và refresh token (7 ngày). Chưa xác thực email thì trả 403 `EMAIL_NOT_VERIFIED`. | H |
| FR-AUTH-03 | JWT chứa userId, email và danh sách vai trò. | H |
| FR-AUTH-04 | Gateway và service kiểm tra chữ ký, hạn, issuer, audience của JWT trước API cần đăng nhập. | H |
| FR-AUTH-05 | Phân quyền API theo vai trò Customer / Staff / Admin (policy `StaffOrAdmin`, `AdminOnly`, mặc định là đã đăng nhập). | H |
| FR-AUTH-06 | Chưa đăng nhập hoặc token sai trả 401; đủ đăng nhập nhưng thiếu quyền trả 403. | H |
| FR-AUTH-07 | Xác thực email bằng OTP 6 số: hết hạn sau 5 phút, tối đa 5 lần nhập, chờ 60 giây giữa hai lần gửi, mã mới thay mã cũ. Khi xác thực phải gửi kèm mật khẩu đã đăng ký; thành công thì đăng nhập luôn và gửi email chào mừng. | H |
| FR-AUTH-08 | Đăng ký lại một email chưa xác thực thì thông tin mới thay thông tin cũ và gửi mã mới. Email đã xác thực thì báo đã đăng ký. | M |
| FR-AUTH-09 | Quên mật khẩu: gửi OTP qua email (luôn trả 200); đặt mật khẩu mới bằng OTP thì mọi refresh token cũ bị thu hồi và email được coi là đã xác thực. | H |
| FR-AUTH-10 | Làm mới phiên bằng refresh token (xoay vòng, token cũ hết hiệu lực); đăng xuất thu hồi refresh token. App tự làm mới khi access token hết hạn. | H |
| FR-AUTH-11 | Xem hồ sơ tài khoản hiện tại (`GET /api/v1/auth/me`). | M |
| FR-AUTH-12 | Gateway kiểm tra trạng thái tài khoản ở mỗi request cần đăng nhập: bị khoá trả 401 `ACCOUNT_LOCKED`; vai trò đã đổi trả 403 `ROLE_CHANGED`; AuthService không phản hồi trả 503. App khách hiện lý do và đưa về màn đăng nhập. | H |
| FR-AUTH-13 | Kiểm tra dữ liệu tài khoản giống nhau ở app và API (đăng ký, đăng nhập, quên / đặt lại mật khẩu, Admin tạo tài khoản): email bắt buộc, tối đa 150 ký tự, có tên miền và đuôi ≥ 2 chữ cái, không dấu cách; mật khẩu mới 6–72 ký tự tính theo byte UTF-8; họ tên bắt buộc, tối đa 150 ký tự; số điện thoại không bắt buộc, 8–15 chữ số, tối đa 20 ký tự. Sai thì 400 kèm lỗi theo từng trường. Form đăng ký có ô nhập lại mật khẩu. | H |
| FR-AUTH-14 | Giới hạn 10 request / phút / IP cho các API đăng ký, đăng nhập, OTP, làm mới, quên / đặt lại mật khẩu; vượt thì 429 kèm `Retry-After`. | M |

### 4.2 Quản lý tài khoản (Admin)

| Mã | Yêu cầu | Ưu tiên |
|---|---|---|
| FR-USER-01 | Xem danh sách tài khoản: tìm kiếm, lọc theo vai trò và trạng thái, phân trang. | H |
| FR-USER-02 | Xem chi tiết tài khoản. | H |
| FR-USER-03 | Tạo tài khoản với một hoặc nhiều vai trò; không cần xác thực OTP. | H |
| FR-USER-04 | Đổi vai trò: refresh token cũ bị thu hồi, phiên cũ bị yêu cầu đăng nhập lại; lưu lại đúng vai trò cũ thì giữ phiên. | H |
| FR-USER-05 | Khoá / mở khoá tài khoản; Admin không tự khoá chính mình. | H |
| FR-USER-06 | Xem danh sách vai trò (`ROLE_CUSTOMER`, `ROLE_STAFF`, `ROLE_ADMIN`). | M |

### 4.3 Phim

| Mã | Yêu cầu | Ưu tiên |
|---|---|---|
| FR-MOV-01 | Danh sách phim có phân trang (Admin). | H |
| FR-MOV-02 | Chi tiết phim: tên, mô tả, thời lượng, thể loại, ngôn ngữ, ngày phát hành, poster, trailer, trạng thái. | H |
| FR-MOV-03 | Tìm phim theo tên. | M |
| FR-MOV-04 | Lọc phim theo trạng thái; trang chủ app khách chỉ hiện phim `ACTIVE`. | H |
| FR-MOV-05 | Admin thêm phim. | H |
| FR-MOV-06 | Admin sửa phim, kể cả cho phim đã ngừng chiếu chiếu lại (**Show again**). | H |
| FR-MOV-07 | Admin ngừng chiếu (**Stop showing**): phim chuyển `INACTIVE`, ẩn khỏi app khách, dữ liệu và vé cũ giữ nguyên. | H |
| FR-MOV-08 | App khách mở trailer của phim (`trailerUrl`). | L |
| FR-MOV-09 | Phân loại phim theo Luật Điện ảnh 2022: P (mọi độ tuổi), K (dưới 13 tuổi xem cùng cha mẹ / người giám hộ), T13, T16, T18. Admin chọn khi thêm / sửa phim (mặc định P). Nhãn hiện trên thẻ phim, chi tiết phim, xác nhận đặt vé, màn bán vé tại quầy và check-in. Phim khác P thì khách phải xác nhận trước khi giữ ghế; khi check-in, nhân viên được nhắc kiểm tra giấy tờ. | H |

### 4.4 Phòng và ghế

| Mã | Yêu cầu | Ưu tiên |
|---|---|---|
| FR-ROOM-01 | Danh sách và tìm phòng theo tên (Staff/Admin). | H |
| FR-ROOM-02 | Chi tiết phòng kèm sơ đồ ghế theo hàng, màu theo loại ghế. | H |
| FR-ROOM-03 | Admin tạo phòng bằng số hàng × số ghế mỗi hàng; ghế được tạo luôn. | H |
| FR-ROOM-04 | Admin đổi tên phòng, giữ nguyên ghế. | M |
| FR-ROOM-05 | Admin xoá phòng chưa có suất chiếu (xoá cả ghế); phòng đã có suất chiếu bị từ chối. | M |
| FR-SEAT-01 | Sinh sơ đồ ghế thường cho phòng trống (Staff/Admin). | H |
| FR-SEAT-02 | Xem chi tiết một ghế. | L |
| FR-SEAT-03 | Lấy sơ đồ ghế của phòng (người dùng đã đăng nhập). | H |
| FR-SEAT-04 | Admin xoá ghế (chỉ qua API). | L |
| FR-SEAT-05 | Đổi loại một ghế: NORMAL / VIP / SWEETBOX. Sweetbox đổi cả cặp; ghế không có ghế cặp không thành sweetbox được. | H |
| FR-SEAT-06 | Đổi loại nhiều ghế một lần trên sơ đồ: chọn loại rồi bấm, kéo qua nhiều ghế, hoặc bấm chữ đầu hàng để đổi cả hàng. Hàng có ghế lẻ không đủ cặp thì 400. | M |
| FR-SEAT-07 | Admin đổi số ghế của phòng: thêm thì lấp hàng cuối rồi sang hàng mới (tối đa hàng Z), bớt thì bỏ từ ghế cuối; nửa sweetbox còn lại thành ghế thường. | M |
| FR-SEAT-08 | Phòng đã có suất chiếu thì không sinh, đổi loại hay đổi số ghế (giữ đúng vé đã bán). | H |
| FR-SEAT-09 | Sơ đồ ghế ở trang quản trị tự làm mới mỗi 5 giây khi người khác đổi. | L |

### 4.5 Suất chiếu

| Mã | Yêu cầu | Ưu tiên |
|---|---|---|
| FR-SHOW-01 | Danh sách suất chiếu có phân trang và lọc. | H |
| FR-SHOW-02 | Staff/Admin tạo suất chiếu: phim, phòng, giờ bắt đầu, giờ kết thúc, giá ghế thường, trạng thái. | H |
| FR-SHOW-03 | Chi tiết suất chiếu kèm `seatPrices`: giá một ghế theo từng loại. | H |
| FR-SHOW-04 | Staff/Admin sửa suất chiếu; vẫn kiểm tra trùng lịch. | H |
| FR-SHOW-05 | Staff/Admin huỷ suất chiếu (chuyển `CANCELLED`, không xoá); hệ thống huỷ các vé và tạo hoàn tiền theo BR-19. | H |
| FR-SHOW-06 | Lấy các suất đang mở bán (`OPEN`, chưa bắt đầu). | H |
| FR-SHOW-07 | Lấy suất chiếu theo phim. | M |
| FR-SHOW-08 | Lấy suất đang mở bán theo phim; app khách hiện các suất trong 7 ngày tới. | H |
| FR-SHOW-09 | Tra suất chiếu theo khoảng thời gian (Staff/Admin). | H |
| FR-SHOW-10 | Mở / đóng bán suất chiếu (`OPEN` ↔ `CLOSED`). | M |
| FR-SHOW-11 | Trùng lịch trong cùng phòng trả 409. | H |
| FR-SHOW-12 | Sơ đồ ghế của suất chiếu cho Staff: ghế trống / chờ thanh toán / đã bán / đã check-in, bấm ghế mở vé, kèm danh sách khách (email, ghế, mã vé, giờ check-in); tự làm mới mỗi 5 giây. | M |

### 4.6 Đặt vé

| Mã | Yêu cầu | Ưu tiên |
|---|---|---|
| FR-BOOK-01 | Tạo booking từ suất chiếu và danh sách ghế: suất phải `OPEN` và chưa bắt đầu, ít nhất một ghế, không trùng ghế. Server lấy giờ chiếu, tên phim và giá từ MovieService. Booking `PENDING`, giữ ghế 10 phút. | H |
| FR-BOOK-02 | Xem chi tiết booking: chủ vé hoặc Staff/Admin. | H |
| FR-BOOK-03 | Staff/Admin xem danh sách booking, lọc theo trạng thái và ngày tạo. | H |
| FR-BOOK-04 | Khách xem vé của mình, chia **Active** và **History**. | H |
| FR-BOOK-05 | Xác nhận booking sau khi thanh toán thành công (chi tiết ở 4.7 và 4.9). | H |
| FR-BOOK-06 | Huỷ booking: vé chờ thanh toán thì huỷ và nhả ghế; vé đã thanh toán thì theo BR-17. Khách huỷ vé đã thanh toán tạo yêu cầu hoàn tiền: booking `REFUND_PENDING` và vẫn giữ ghế cho tới khi Staff xử lý. | H |
| FR-BOOK-07 | Lấy các ghế đã giữ / đã bán của một suất chiếu. | H |
| FR-BOOK-08 | Ghế đang được booking khác giữ hoặc đã bán thì trả 409. | H |
| FR-BOOK-09 | Sweetbox phải đặt đủ cặp (server từ chối nửa cặp). | H |
| FR-BOOK-10 | Job nền chạy mỗi 30 giây chuyển booking quá hạn giữ ghế sang `EXPIRED` và nhả ghế. | H |
| FR-BOOK-11 | Màn chọn ghế tự làm mới mỗi 5 giây; ghế đang chọn bị người khác đặt thì bỏ chọn và báo cho khách. | M |
| FR-BOOK-12 | Thống kê vé theo suất chiếu cho Staff/Admin: số đơn, ghế đã bán, đang giữ, đã check-in (theo danh sách id hoặc khoảng giờ chiếu, tối đa 31 ngày). | M |
| FR-BOOK-13 | **Bắp nước kèm vé**: khách (màn xác nhận đặt vé) và quầy (màn bán vé) chọn món trong menu, mỗi món 1–20, tối đa 10 món khác nhau. Giá lấy từ menu đang bán; tiền bắp nước nằm trong tổng tiền nên thanh toán, doanh thu và hoàn tiền tính luôn. Đơn lưu tên và giá lúc mua. Bắp nước hiện trên vé, trang thanh toán, email vé và vé in. Món đã ngừng bán bị từ chối (400). | M |
| FR-BOOK-14 | Admin quản lý menu bắp nước (Admin → Snacks): thêm, sửa tên / giá / mô tả / ảnh / thứ tự, ngừng bán hoặc bán lại (không xoá món). Khách chỉ thấy món đang bán. | M |
| FR-BOOK-15 | **Khuyến mãi**: chỉ giảm tiền vé (không giảm bắp nước), theo % (có thể kèm mức giảm tối đa) hoặc số tiền, tối đa 90% tiền vé, làm tròn xuống 1.000đ. Điều kiện: thời gian chạy, thứ của ngày chiếu, số vé tối thiểu, số lượt tối đa. Khuyến mãi không có mã tự áp dụng (chọn cái giảm nhiều nhất); khách / quầy nhập mã voucher thì dùng mã thay cho khuyến mãi tự áp dụng — mỗi đơn một khuyến mãi. Mã sai hoặc không đủ điều kiện bị 400 kèm lý do. Server tính lại khi tạo đơn; lượt dùng chỉ được đếm khi vé đã thanh toán. Giảm giá hiện trên vé, trang thanh toán, email vé và vé in. | M |
| FR-BOOK-16 | Admin quản lý khuyến mãi (Admin → Promotions): thêm, sửa, tạm dừng / chạy lại (không xoá), xem số lượt đã dùng. Mã voucher không trùng nhau (409). Khách chưa đăng nhập chỉ xem được khuyến mãi tự áp dụng đang chạy. | M |

### 4.7 Thanh toán (PayOS)

| Mã | Yêu cầu | Ưu tiên |
|---|---|---|
| FR-PAY-01 | Tạo link thanh toán PayOS cho booking `PENDING`. Mỗi booking một payment; gọi lại thì trả link cũ, không tạo thêm. Mã đơn PayOS = id booking × 1.000.000 + 6 số ngẫu nhiên cuối mã vé: cố định cho mỗi booking và không trùng với đơn của môi trường khác trên tài khoản PayOS dùng chung. Link hết hạn cùng lúc với thời gian giữ ghế. | H |
| FR-PAY-02 | Xác minh thanh toán theo mã đơn (hoặc id booking): PayOS báo đã trả thì payment `SUCCESS` và booking `CONFIRMED`; khách huỷ trên trang PayOS thì payment `FAILED`, booking `CANCELLED` và nhả ghế ngay. Gọi lại nhiều lần vẫn an toàn. | H |
| FR-PAY-03 | Xem chi tiết payment: chủ vé hoặc Staff/Admin. | H |
| FR-PAY-04 | Khách xem lịch sử thanh toán của mình. | M |
| FR-PAY-05 | Xem các payment của một booking. | M |
| FR-PAY-06 | Hoàn tiền: xem mục 4.8. | H |
| FR-PAY-07 | Nhận webhook PayOS: kiểm tra chữ ký HMAC-SHA256 (sai thì 400); đơn không tồn tại hoặc sai số tiền thì 200 và bỏ qua; webhook lặp không xác nhận hay gửi email lần hai. Lưu tài khoản người trả (số tài khoản, tên, ngân hàng) để hoàn tiền. | H |
| FR-PAY-08 | Trả tiền muộn theo BR-20. | M |
| FR-PAY-09 | Staff/Admin xem danh sách payment và xác minh lại một payment PayOS đang chờ. | M |
| FR-PAY-10 | Admin xem doanh thu theo khoảng thời gian: số thanh toán đã nhận, doanh thu (`SUCCESS` + `REFUND_PENDING`), tiền đã hoàn (`REFUNDED`). | M |
| FR-PAY-11 | Trang thanh toán của app tự kiểm tra booking mỗi 5 giây và hỏi PayOS mỗi 30 giây khi đang mở; không có nút "Tôi đã trả tiền". | M |

### 4.8 Huỷ vé và hoàn tiền

| Mã | Yêu cầu | Ưu tiên |
|---|---|---|
| FR-REF-01 | Yêu cầu hoàn tiền (`PENDING`) được tạo khi: khách huỷ vé đã thanh toán đúng hạn; Staff/Admin huỷ vé đã thanh toán; suất chiếu bị huỷ; trả tiền muộn mà mất ghế; Admin hoàn tiền thủ công cho một payment. Payment chuyển `REFUND_PENDING`, khách nhận email. | H |
| FR-REF-02 | Staff/Admin xem danh sách yêu cầu hoàn tiền (lọc theo trạng thái) và chi tiết: số tiền, lý do, tài khoản người trả. | H |
| FR-REF-03 | Staff chuyển khoản xong thì ghi nhận mã giao dịch: hoàn tiền `COMPLETED`, payment `REFUNDED`, booking `CANCELLED` và nhả ghế, khách nhận email kèm mã giao dịch. | H |
| FR-REF-04 | Staff từ chối yêu cầu (bắt buộc lý do, chỉ khi `PENDING`): payment về `SUCCESS`, booking về `CONFIRMED` và giữ ghế; khách thấy lý do trong chi tiết vé và nhận email. Không từ chối được hoàn tiền của vé do rạp huỷ. | H |
| FR-REF-05 | Yêu cầu đã bị từ chối được mở lại khi rạp huỷ vé hoặc suất chiếu sau đó. | M |
| FR-REF-06 | Khách xem trạng thái hoàn tiền của vé. | M |
| FR-REF-07 | Mỗi payment chỉ có một yêu cầu hoàn tiền, kể cả khi event bị giao lại. | H |

### 4.9 Bán vé tại quầy

| Mã | Yêu cầu | Ưu tiên |
|---|---|---|
| FR-POS-01 | Staff/Admin bán vé cho **khách vãng lai** (không tài khoản; email và số điện thoại không bắt buộc) hoặc **thành viên** (ID tài khoản + email). Chọn phim, suất trong 7 ngày tới, ghế trên sơ đồ (sweetbox theo cặp, giá theo loại). | H |
| FR-POS-02 | Giữ ghế xong chuyển sang màn **Take payment**: thông tin vé, khách, tổng tiền, đồng hồ giữ ghế, ô email nhận vé. | H |
| FR-POS-03 | **Tiền mặt**: nhập số tiền khách đưa (có nút số tiền chẵn), màn hình tính tiền thối; thiếu tiền thì không cho xác nhận. Server ghi payment `CASH` `SUCCESS` (mã giao dịch `CASH-<mã vé>`) và xác nhận vé. | H |
| FR-POS-04 | **Chuyển khoản**: hiện VietQR của PayOS để khách quét bằng app ngân hàng (link tạo trước đó thì hiện QR của trang thanh toán); màn hình tự kiểm tra mỗi 3 giây và chuyển sang đã thanh toán khi tiền về. | H |
| FR-POS-05 | Đổi từ chuyển khoản sang tiền mặt theo BR-22: link PayOS bị huỷ, payment PayOS `FAILED`; khách đã chuyển khoản thì 409. | H |
| FR-POS-06 | Email khách cho ở quầy được lưu vào vé để các email huỷ / hoàn tiền sau đó cũng tới. | M |
| FR-POS-07 | Sau khi trả tiền: hiện QR vé; **Print ticket** (trên web, khổ giấy in hoá đơn 80 mm); **Check in now** khi suất bắt đầu trong 3 giờ; **Sell another ticket**. Không có email thì in vé hoặc để khách chụp QR. | H |
| FR-POS-08 | Vé đã trả có nút **Show ticket** ở chi tiết vé để in lại hoặc check-in. | M |

### 4.10 Check-in tại rạp

| Mã | Yêu cầu | Ưu tiên |
|---|---|---|
| FR-CHK-01 | Vé đã thanh toán có mã QR chứa mã vé, hiện trong app khách, trong email xác nhận và trên vé in. | H |
| FR-CHK-02 | Staff/Admin tra vé theo mã (không phân biệt hoa thường): phim, giờ, phòng, ghế, tổng tiền, trạng thái. | H |
| FR-CHK-03 | Check-in theo BR-21; không hợp lệ thì 409 kèm lý do (chưa thanh toán, đã huỷ, chờ hoàn tiền, chưa tới giờ, quá giờ, đã check-in lúc mấy giờ). Hai quầy quét cùng lúc thì quầy sau nhận 409. | H |
| FR-CHK-04 | Quét QR bằng camera điện thoại (app), webcam laptop / camera USB (trang quản trị), hoặc gõ mã / máy quét cầm tay (gõ mã rồi Enter). | H |
| FR-CHK-05 | Giờ check-in hiện trên vé của khách, chi tiết vé, sơ đồ ghế và danh sách khách của suất chiếu. | M |

### 4.11 Thông báo và email

| Mã | Yêu cầu | Ưu tiên |
|---|---|---|
| FR-NOTI-01 | Khách xem danh sách và chi tiết thông báo của mình, mở vé liên quan. Admin xem tất cả. | M |
| FR-NOTI-02 | Staff/Admin soạn thông báo email cho khách của một vé (kể cả khách vãng lai có email). | M |
| FR-NOTI-03 | Gửi thông báo; gửi lỗi thì lưu `FAILED` kèm lỗi và cho gửi lại cùng thông báo. | M |
| FR-NOTI-04 | Xem chi tiết thông báo. | M |
| FR-NOTI-05 | Xoá thông báo: người nhận xoá của mình, Admin xoá mọi thông báo (qua API). | L |
| FR-NOTI-06 | Tự gửi email theo event: vé đã xác nhận (kèm ảnh QR nhúng), vé bị huỷ, vé hết hạn, đã ghi nhận yêu cầu hoàn tiền, từ chối hoàn tiền, đã hoàn tiền. Mỗi event gửi đúng một lần. Vé không có email thì bỏ qua. | H |
| FR-NOTI-07 | AuthService gửi email OTP (xác thực, đặt lại mật khẩu) và email chào mừng. | H |

### 4.12 Dashboard và báo cáo

| Mã | Yêu cầu | Ưu tiên |
|---|---|---|
| FR-DASH-01 | Khối **Today** (Staff và Admin): vé tạo hôm nay; suất hôm nay có vé (x / tổng suất); vé của các suất hôm nay; số đã check-in. | M |
| FR-DASH-02 | Bảng suất chiếu: **Now showing** (mọi suất đang chiếu, số khách đang xem = đã check-in, vé đã bán / sức chứa, thời gian còn lại); **Up next** (3 suất tiếp theo: đã đặt, chờ thanh toán, đã check-in sớm); **Just finished** (3 suất vừa xong: vé đã bán, số khách đã vào). Bấm suất mở sơ đồ ghế và danh sách khách. Tự làm mới mỗi phút. | M |
| FR-DASH-03 | Dashboard Staff có mục **Needs attention**: vé chờ thanh toán, yêu cầu hoàn tiền chờ xử lý; lối tắt **Sell tickets** và **Check in**. | M |
| FR-DASH-04 | Dashboard Admin: booking và doanh thu tháng này, tiền đã hoàn, phim đang chiếu, suất hôm nay, thống kê tài khoản (tổng, đang hoạt động, bị khoá). Các phần tải độc lập, một phần lỗi không làm hỏng phần khác. | M |

---

## 5. Yêu cầu giao diện người dùng

### 5.1 App khách (Android, web, Windows)

| Màn hình | Chức năng |
|---|---|
| Trang chủ | Phim đang chiếu, ô tìm phim (lọc trên danh sách đã tải) |
| Chi tiết phim | Thông tin phim, trailer, suất chiếu 7 ngày tới theo ngày, phòng và giá |
| Chọn ghế | Sơ đồ theo hàng, màu theo loại, chú thích giá, sweetbox theo cặp, tổng tiền, tự làm mới |
| Xác nhận đặt vé | Tóm tắt phim, suất, ghế, tổng tiền → giữ ghế |
| Thanh toán / kết quả | Đồng hồ giữ ghế, **Pay with PayOS** / **Continue with PayOS**, tự kiểm tra kết quả |
| Vé của tôi | Tab Active / History; chi tiết vé có QR, giờ check-in, huỷ vé / yêu cầu hoàn tiền, trạng thái và lý do từ chối hoàn tiền |
| Thông báo | Danh sách, chi tiết, mở vé liên quan |
| Lịch sử thanh toán | Các giao dịch và trạng thái |
| Tài khoản | Hồ sơ, đổi mật khẩu qua OTP, đăng xuất |
| Đăng nhập / đăng ký / OTP / quên mật khẩu | Form có kiểm tra từng ô (FR-AUTH-13), đếm ngược gửi lại mã |
| Staff trên điện thoại | Hướng dẫn mở trang quản trị và nút **Check in tickets** (quét QR bằng camera) |

### 5.2 Trang quản trị web

Thanh điều hướng bên trái; cửa sổ hẹp hơn 640 px thì mở bằng nút menu. Staff: **Dashboard / Operations / Check-in / Profile**. Admin thêm **Movies / Rooms / Accounts**.

| Màn hình | Vai trò | Chức năng |
|---|---|---|
| Dashboard | Staff, Admin | FR-DASH-01..04 |
| Operations | Staff, Admin | 5 nhóm Bookings / Showtimes / Rooms / Payments / Refunds, lọc và phân trang |
| Sell tickets, Take payment | Staff, Admin | FR-POS-01..08 |
| Check-in | Staff, Admin | FR-CHK-01..05 |
| Chi tiết vé / payment / hoàn tiền | Staff, Admin | Huỷ vé, check-in, thu tiền, xác minh PayOS, ghi nhận / từ chối hoàn tiền, gửi thông báo |
| Suất chiếu | Staff, Admin | Tạo, sửa, mở / đóng bán, huỷ, sơ đồ ghế và danh sách khách |
| Sơ đồ ghế của phòng | Staff, Admin | Đổi loại từng ghế hoặc tô hàng loạt; Admin đổi số ghế |
| Movies | Admin | Thêm, sửa, ngừng chiếu / chiếu lại, lọc, tìm |
| Rooms | Admin | Thêm phòng theo hàng × ghế, đổi tên, xoá, mở sơ đồ |
| Snacks | Admin | Menu bắp nước: thêm, sửa, ngừng bán / bán lại |
| Promotions | Admin | Khuyến mãi tự áp dụng và mã voucher: thêm, sửa, tạm dừng / chạy lại, xem lượt dùng |
| Accounts | Admin | Tìm, lọc, phân trang, chi tiết, tạo, đổi vai trò, khoá / mở khoá |
| Profile | Staff, Admin | Hồ sơ, đổi mật khẩu qua OTP, đăng xuất |

### 5.3 Yêu cầu chung

- **UI-01** Giao diện tối, điểm nhấn cyan, cùng một bộ thành phần cho app và trang quản trị.
- **UI-02** Lỗi nhập liệu hiện ngay dưới ô; lỗi từ server hiện theo thông báo của server (`detail` hoặc `errors`).
- **UI-03** Có trạng thái đang tải, lỗi kèm nút thử lại và trạng thái rỗng cho mọi danh sách.
- **UI-04** Thao tác thay đổi dữ liệu quan trọng (huỷ vé, thu tiền, hoàn tiền, khoá tài khoản) có hộp xác nhận.
- **UI-05** Bố cục co giãn theo màn hình: điện thoại, máy tính bảng, máy tính; không cuộn ngang toàn trang.
- **UI-06** Route web giữ id trong URL để tải lại trang vẫn mở đúng bản ghi.

---

## 6. Luồng nghiệp vụ chính

### 6.1 Đăng ký và xác thực email
1. Khách đăng ký → AuthService tạo tài khoản chưa xác thực, gửi OTP.
2. Khách nhập OTP cùng mật khẩu → tài khoản được xác thực, nhận token, nhận email chào mừng.
3. Đăng nhập khi chưa xác thực → 403 `EMAIL_NOT_VERIFIED` → app chuyển sang màn OTP, có thể gửi lại mã sau 60 giây.

### 6.2 Đặt vé và thanh toán online
1. Khách chọn phim → suất chiếu → ghế → xác nhận: booking `PENDING`, giữ ghế 10 phút, event `booking.created`.
2. App tạo link PayOS → khách trả tiền bằng app ngân hàng.
3. PayOS gọi webhook (hoặc app gọi verify) → payment `SUCCESS`, booking `CONFIRMED`, event `booking.confirmed`.
4. Consumer gửi email vé kèm QR. Khách thấy vé trong **Active**.
5. Quá 10 phút chưa trả → job chuyển `EXPIRED`, nhả ghế, payment `FAILED`, email hết hạn.

### 6.3 Huỷ vé và hoàn tiền
1. Khách huỷ vé đã thanh toán (còn ≥ 2 giờ) → booking `REFUND_PENDING`, event `booking.refund_requested` → tạo yêu cầu hoàn tiền, payment `REFUND_PENDING`, email.
2. Staff mở **Operations → Refunds**, chuyển khoản cho khách ngoài hệ thống.
3. Staff ghi nhận mã giao dịch → `COMPLETED` / `REFUNDED`, booking `CANCELLED`, nhả ghế, email. Hoặc từ chối kèm lý do → booking về `CONFIRMED`.

### 6.4 Bán vé tại quầy
1. Staff **Sell tickets** → khách vãng lai / thành viên → phim, suất, ghế → giữ ghế.
2. **Take payment**: tiền mặt (nhập tiền, tính tiền thối, xác nhận) hoặc chuyển khoản (VietQR, tự xác nhận).
3. Vé `CONFIRMED`, có payment; email vé nếu có email; in vé hoặc hiện QR; **Check in now** nếu suất sắp chiếu.

### 6.5 Check-in
1. Khách đưa QR (app, email, vé in) → Staff quét bằng camera / webcam / máy quét hoặc gõ mã.
2. Hệ thống hiện thông tin vé → **Check in** → ghi giờ check-in; dashboard tính khách vào "đang xem".

### 6.6 Huỷ suất chiếu
1. Staff huỷ suất → MovieService ghi `showtime.cancelled` vào outbox.
2. BookingService huỷ mọi vé còn hiệu lực của suất; vé đã thanh toán được tạo yêu cầu hoàn tiền; khách nhận email.

### 6.7 Khoá tài khoản / đổi vai trò
1. Admin khoá tài khoản hoặc đổi vai trò. Đổi vai trò thu hồi refresh token cũ; tài khoản bị khoá không đăng nhập hay làm mới phiên được.
2. Request tiếp theo của người đó qua gateway nhận 401 `ACCOUNT_LOCKED` hoặc 403 `ROLE_CHANGED` → app báo lý do và về màn đăng nhập.

---

## 7. Trạng thái

### 7.1 Booking
| Từ | Sang | Khi nào |
|---|---|---|
| — | `PENDING` | Tạo booking, giữ ghế 10 phút |
| `PENDING` | `CONFIRMED` | Thanh toán thành công (PayOS, tiền mặt) |
| `PENDING` | `EXPIRED` | Quá hạn giữ ghế |
| `PENDING` | `CANCELLED` | Khách / Staff huỷ, khách huỷ trên trang PayOS, suất chiếu bị huỷ |
| `EXPIRED` | `CONFIRMED` | Trả tiền muộn khi ghế còn trống |
| `CONFIRMED` | `REFUND_PENDING` | Khách huỷ đúng hạn (giữ ghế) |
| `REFUND_PENDING` | `CANCELLED` | Staff ghi nhận đã hoàn tiền (nhả ghế) |
| `REFUND_PENDING` | `CONFIRMED` | Staff từ chối hoàn tiền |
| `CONFIRMED` | `CANCELLED` | Staff/Admin huỷ, suất chiếu bị huỷ (tạo hoàn tiền) |

Check-in là thuộc tính `checkedInAt` của vé `CONFIRMED`, không phải một trạng thái riêng.

### 7.2 Payment
`PENDING` → `SUCCESS` / `FAILED`; `FAILED` → `SUCCESS` (PayOS báo đã trả sau khi job đánh hết hạn); `SUCCESS` → `REFUND_PENDING` → `REFUNDED`; `REFUND_PENDING` → `SUCCESS` (từ chối hoàn tiền). Phương thức: `PAYOS`, `CASH`.

### 7.3 Hoàn tiền
`PENDING` → `COMPLETED` / `REJECTED`; `REJECTED` → `PENDING` (rạp huỷ vé sau đó).

### 7.4 Khác
| Đối tượng | Trạng thái |
|---|---|
| Suất chiếu | `OPEN` ↔ `CLOSED`; `OPEN` / `CLOSED` → `CANCELLED` (không quay lại) |
| Phim | `ACTIVE` ↔ `INACTIVE` |
| Thông báo | `PENDING` → `SENT` / `FAILED`; `FAILED` → `SENT` (gửi lại) |
| Tài khoản | Chưa xác thực → đã xác thực; hoạt động ↔ bị khoá |

---

## 8. Ma trận phân quyền

| Chức năng | Khách chưa đăng nhập | Customer | Staff | Admin |
|---|:-:|:-:|:-:|:-:|
| Đăng ký / đăng nhập | ✓ | ✓ | ✓ | ✓ |
| Xem phim, suất chiếu đang mở | ✓ | ✓ | ✓ | ✓ |
| Thêm / sửa / ngừng chiếu phim | | | | ✓ |
| Tạo / sửa / mở đóng / huỷ suất chiếu | | | ✓ | ✓ |
| Xem phòng; sinh ghế, đổi loại ghế | | | ✓ | ✓ |
| Tạo / đổi tên / xoá phòng; đổi số ghế; xoá ghế | | | | ✓ |
| Đặt vé cho mình, xem / huỷ vé của mình | | ✓ | ✓ | ✓ |
| Thanh toán PayOS cho vé của mình | | ✓ | ✓ | ✓ |
| Bán vé tại quầy (vãng lai / thành viên), thu tiền mặt, QR chuyển khoản | | | ✓ | ✓ |
| Xem mọi vé, payment; check-in | | | ✓ | ✓ |
| Ghi nhận / từ chối hoàn tiền | | | ✓ | ✓ |
| Hoàn tiền thủ công cho một payment | | | | ✓ |
| Tạo và gửi thông báo cho khách | | | ✓ | ✓ |
| Xem thông báo của mình / của mọi người | | ✓ / | ✓ / | ✓ / ✓ |
| Xem doanh thu | | | | ✓ |
| Quản lý tài khoản và vai trò | | | | ✓ |

**Đối chiếu với ma trận trong đề bài (`PRM393.docx`):**

| Điểm khác | Đề bài | Hệ thống | Lý do |
|---|---|---|---|
| Tạo / sửa phim | Staff, Admin | Chỉ Admin | Danh mục phim là dữ liệu dùng chung, chỉ người quản trị sửa; Staff tập trung vận hành |
| Quản lý phòng | Staff, Admin | Staff xem và sửa loại ghế; tạo / xoá phòng chỉ Admin | Tránh làm sai sơ đồ đang bán vé |
| Tạo booking, thanh toán | Chỉ Customer | Customer, cộng Staff/Admin bán tại quầy | Yêu cầu bổ sung: bán vé cho khách đến rạp |
| Refund | Chỉ Admin | Staff ghi nhận / từ chối; Admin thêm hoàn tiền thủ công | Hoàn tiền là việc hằng ngày ở quầy |

---

## 9. Dữ liệu

| Database | Bảng chính | Ghi chú |
|---|---|---|
| `cinema_auth_db` | `users`, `roles`, `users_roles`, `refresh_tokens`, `otp_codes` | Mật khẩu và OTP chỉ lưu hash BCrypt; email duy nhất |
| `cinema_movie_db` | `movies` | Trạng thái `ACTIVE` / `INACTIVE`; phân loại `age_rating` P / K / T13 / T16 / T18 |
| `cinema_showtime_db` | `rooms`, `seats`, `showtimes`, `outbox_messages` | Ghế duy nhất theo (phòng, hàng, số); loại ghế NORMAL / VIP / SWEETBOX |
| `cinema_booking_db` | `bookings`, `booking_seats`, `seat_reservations`, `concession_items`, `booking_concessions`, `promotions`, `outbox_messages` | `user_id` NULL cho khách vãng lai; `customer_email`, `customer_phone`, `checked_in_at`, `expires_at` |
| `cinema_payment_db` | `payments`, `refunds`, `outbox_messages` | Phương thức `PAYOS` / `CASH`; thông tin tài khoản người trả để hoàn tiền |
| `cinema_notification_db` | `notifications` | Duy nhất theo `event_id` để không gửi trùng |

- Lược đồ và dữ liệu seed nằm ở repo **Project-Cinema-DB**: file dump cho DB mới và thư mục `migrations/` cho DB đang có dữ liệu (chạy lại nhiều lần vẫn an toàn).
- Seed có tài khoản demo, phim mẫu, các phòng Standard / IMAX với sơ đồ ghế khác nhau, và lịch chiếu một tháng cho mọi phim đang chiếu (migration bổ sung lịch khi hết).

---

## 10. Giao diện bên ngoài

### 10.1 API

- 89 endpoint nghiệp vụ, REST/JSON, qua gateway `http://<host>:5000`. Danh sách đầy đủ: [MOBILE_UI_ENDPOINTS.md](../Cinema_Mobile/docs/MOBILE_UI_ENDPOINTS.md).

| Nhóm | Tiền tố | Số endpoint |
|---|---|---|
| Xác thực, tài khoản, vai trò | `/api/v1/auth` | 15 |
| Phim | `/api/v1/movies` | 7 |
| Phòng, ghế | `/api/rooms`, `/api/seats` | 13 |
| Suất chiếu | `/api/showtimes` | 11 |
| Đặt vé, check-in | `/api/v1/bookings` | 13 |
| Thanh toán, hoàn tiền | `/api/v1/payments` | 17 |
| Thông báo | `/api/v1/notifications` | 6 |
| Bắp nước | `/api/v1/concessions` | 3 |
| Khuyến mãi | `/api/v1/promotions` | 4 |

- Danh sách có phân trang (`page` / `size` hoặc `pageNumber` / `pageSize`), tối đa 50 bản ghi một trang, sắp xếp `sortBy` / `sortDir`.
- Lỗi theo chuẩn ProblemDetails: `title`, `status`, `detail`, `errors` (lỗi theo trường), `errorCode` (mã nghiệp vụ).
- Mỗi service có Swagger (`/swagger`), `/health`, `/health/live`, `/metrics`.

### 10.2 PayOS
- Tạo link thanh toán, tra cứu, huỷ link qua API merchant; webhook `POST /api/v1/payments/payos/webhook` ký bằng Checksum Key.
- Link vừa tạo trả kèm chuỗi VietQR (`qrCode`) cho màn quầy.

### 10.3 Email (SMTP)
- Gmail SMTP cổng 587, TLS, App Password; timeout 10 giây.
- Email vé có ảnh QR nhúng (`cid:`) để hiện ngay trong Gmail / Outlook; nội dung người dùng nhập được encode HTML.

### 10.4 RabbitMQ
| Event | Phát bởi | Nhận và xử lý |
|---|---|---|
| `booking.created`, `booking.confirmed`, `booking.cancelled`, `booking.expired`, `booking.refund_requested` | BookingService | Gửi email; huỷ / đánh `FAILED` payment chưa trả; tạo yêu cầu hoàn tiền |
| `payment.created`, `payment.succeeded`, `payment.failed`, `payment.refund_requested`, `payment.refund_rejected`, `payment.refunded` | BookingService | Gửi email cho khách |
| `showtime.cancelled` | MovieService | Huỷ vé của suất chiếu |

---

## 11. Yêu cầu phi chức năng

| Mã | Nhóm | Yêu cầu |
|---|---|---|
| NFR-SEC-01 | Bảo mật | Mật khẩu và OTP băm bằng BCrypt; không trả stack trace hay lỗi nội bộ ra response. |
| NFR-SEC-02 | Bảo mật | JWT ký bằng secret ≥ 32 ký tự; access token 60 phút; refresh token 7 ngày, xoay vòng, thu hồi khi đăng xuất, đặt lại mật khẩu, đổi quyền. |
| NFR-SEC-03 | Bảo mật | Kiểm tra quyền ở cả gateway (theo route) và service (theo dữ liệu, ví dụ chỉ xem vé của mình). |
| NFR-SEC-04 | Bảo mật | Giới hạn tần suất: 100 request / phút / IP cho mọi API, 10 cho API xác thực. |
| NFR-SEC-05 | Bảo mật | Chỉ gateway mở ra mạng; service, PostgreSQL, RabbitMQ, công cụ giám sát chỉ nghe `127.0.0.1`. |
| NFR-SEC-06 | Bảo mật | Secret không nằm trong mã nguồn; chia sẻ bằng SOPS + age. |
| NFR-SEC-07 | Bảo mật | Mọi input được kiểm tra ở server (DataAnnotations + validator); client kiểm tra trước để báo lỗi sớm. |
| NFR-PERF-01 | Hiệu năng | Mọi danh sách có phân trang, tối đa 50 bản ghi. |
| NFR-PERF-02 | Hiệu năng | Giữ ghế, xác nhận vé và thu tiền khoá dòng booking (`SELECT … FOR UPDATE`) trong transaction để không bán trùng ghế hay thu tiền hai lần khi nhiều người thao tác cùng lúc. |
| NFR-REL-01 | Tin cậy | Lời gọi MovieService / PayOS: thử lại tối đa 2 lần với lỗi tạm thời (riêng tạo link PayOS không thử lại); circuit breaker mở 15 giây khi lỗi liên tục và trả 503 ngay. |
| NFR-REL-02 | Tin cậy | Outbox: event không mất khi RabbitMQ dừng, gửi bù khi RabbitMQ chạy lại. |
| NFR-REL-03 | Tin cậy | Consumer idempotent; message lỗi thử lại 3 lần rồi chuyển sang DLQ. |
| NFR-REL-04 | Tin cậy | Gateway kiểm tra `/health/live` của service mỗi 10 giây, service chết thì trả 503 ngay. |
| NFR-OBS-01 | Giám sát | Metrics Prometheus cho HTTP, runtime và nghiệp vụ (booking, payment, refund, outbox); dashboard Grafana "Cinema - Tổng quan". |
| NFR-OBS-02 | Giám sát | Trace OpenTelemetry → Jaeger, xuyên qua gateway, service, SQL, PayOS và RabbitMQ. |
| NFR-OBS-03 | Giám sát | Log có TraceId, SpanId, CorrelationId; header `X-Correlation-ID` trên mọi response. |
| NFR-MAINT-01 | Bảo trì | Kiến trúc lớp, DTO, validator, global exception handler ở mọi service; tài liệu trong `docs/`. |
| NFR-MAINT-02 | Bảo trì | CI GitHub Actions chạy test backend và `flutter analyze` / `flutter test` / build web cho mọi pull request vào `dev` / `main`. |
| NFR-DEP-01 | Triển khai | Một lệnh `docker compose up -d --build` chạy toàn bộ backend; giám sát qua profile `monitoring`. |
| NFR-USE-01 | Sử dụng | App khách hỗ trợ Android, web, Windows; trang quản trị tối ưu cho máy tính và vẫn dùng được trên màn hình hẹp. |
| NFR-COMP-01 | Tương thích | Camera web cần `localhost` hoặc HTTPS; ứng dụng triển khai thật phải dùng HTTPS. |

---

## 12. Xử lý lỗi

| HTTP | Ý nghĩa | Ví dụ |
|---|---|---|
| 400 | Dữ liệu không hợp lệ | Sai định dạng email, thiếu ghế, OTP sai (kèm số lần còn lại), thiếu tiền mặt |
| 401 | Chưa xác thực | Thiếu / sai / hết hạn token; `ACCOUNT_LOCKED` |
| 403 | Không đủ quyền | Khách gọi API Staff; `EMAIL_NOT_VERIFIED`; `ROLE_CHANGED` |
| 404 | Không tìm thấy | Phim, suất chiếu, vé, mã vé không tồn tại |
| 409 | Xung đột trạng thái | Ghế đã có người giữ; trùng lịch phòng; vé đã check-in; vé đã thanh toán; huỷ muộn |
| 429 | Quá nhiều request | Vượt giới hạn tần suất; gửi lại OTP quá sớm (kèm `Retry-After`) |
| 500 | Lỗi ngoài dự kiến | Ghi log mức lỗi kèm stack trace, response không lộ chi tiết |
| 503 | Dịch vụ tạm ngưng | Service phụ thuộc chết / circuit mở; thiếu cấu hình PayOS; không gửi được email OTP |

---

## 13. Kiểm thử và nghiệm thu

### 13.1 Kiểm thử tự động

| Phần | Số test | Nội dung chính |
|---|---|---|
| AuthService | 27 | Đăng ký, OTP và khoá OTP, đăng nhập, refresh xoay vòng, đăng xuất, khoá tài khoản, đổi vai trò, validate dữ liệu |
| ApiGateway | 21 | Chặn token của tài khoản bị khoá hoặc đã đổi vai trò trước khi chuyển tiếp, không chuyển tiếp khi kiểm tra tài khoản lỗi, 503 khi AuthService không phản hồi |
| MovieService | 21 | Suất chiếu, trùng lịch, huỷ suất và event, ghế, sweetbox, đổi số ghế, giá theo loại ghế |
| BookingService | 66 | Đặt vé, giữ ghế, webhook, hết hạn, trả muộn, hoàn tiền, RabbitMQ thật, phân quyền, check-in, thống kê, doanh thu, bán vé tại quầy |
| Flutter | 180 | Widget test các màn khách và quản trị, validator, luồng thanh toán, check-in, quầy |

Test tích hợp backend chạy với PostgreSQL và RabbitMQ thật (Testcontainers); PayOS, MovieService, SMTP được thay bằng bản giả.

### 13.2 Tiêu chí nghiệm thu

1. Khách đăng ký, xác thực OTP, đăng nhập và nhận JWT.
2. Mỗi vai trò chỉ gọi được API đúng quyền; khoá tài khoản và đổi quyền có hiệu lực ngay.
3. Khách xem phim, suất chiếu, ghế trống và giá theo loại ghế.
4. Không thể bán một ghế cho hai booking còn hiệu lực của cùng suất chiếu.
5. Booking và payment luôn ở trạng thái hợp lệ theo mục 7.
6. Webhook PayOS được kiểm tra chữ ký trước khi cập nhật.
7. PayOS hoặc MovieService lỗi: API trả 503 nhanh, không treo dây chuyền.
8. Event RabbitMQ được gửi và xử lý đúng; message lặp không gây gửi email hay hoàn tiền hai lần.
9. Email vé (kèm QR), huỷ, hết hạn, hoàn tiền được gửi sau event tương ứng.
10. Staff bán vé tại quầy bằng tiền mặt hoặc chuyển khoản; tiền này có trong doanh thu.
11. Staff check-in bằng QR đúng khung giờ, mỗi vé một lần.
12. Hoàn tiền đi đủ vòng: yêu cầu → ghi nhận / từ chối → email.
13. Toàn bộ backend chạy bằng Docker Compose; mọi service có Swagger, health check và metrics.

---

## 14. Giới hạn đã biết và hướng phát triển

| Giới hạn | Ảnh hưởng | Hướng xử lý |
|---|---|---|
| PayOS không có API hoàn tiền | Hoàn tiền phải chuyển khoản tay | Tích hợp cổng có API hoàn tiền nếu cần |
| Chưa có đổi mật khẩu bằng mật khẩu cũ, chưa sửa hồ sơ | Đổi mật khẩu dùng luồng OTP | Bổ sung endpoint |
| Tìm phim ở trang chủ lọc trên danh sách đã tải | Không tìm được phim chưa tải | Gọi `GET /api/v1/movies/search` |
| Thông báo chưa có trạng thái đã đọc / push | Khách phải mở app để xem | Bổ sung trạng thái đọc, FCM |
| Danh sách vé của khách lấy trang đầu (50 vé) | Khách có rất nhiều vé không thấy vé cũ | Tải thêm khi cuộn |
| Tích điểm, khuyến mãi | Chưa có | Giai đoạn sau |

---

## Phụ lục A. Đối chiếu với SRS 1.0

Chú thích trong mã nguồn và tài liệu kỹ thuật có thể dẫn số mục của bản 1.0:

| Bản 1.0 | Bản 2.0 |
|---|---|
| §4 Business Rules (BR 1–13) | Mục 3 (BR-01..BR-13 giữ nguyên ý nghĩa, thêm BR-14..BR-26) |
| §5 System Architecture | Mục 2.1, 2.2 (6 service dự kiến được gộp thành 3 service nghiệp vụ) |
| §6 Functional Requirements | Mục 4 (giữ mã FR cũ, thêm FR mới) |
| §8 Core Business Workflows | Mục 6 |
| §9 Role & Permission Matrix | Mục 8 |
| §11 Non-Functional Requirements | Mục 11 |
| §12 Error Handling | Mục 12 |
| §13.1 RabbitMQ, §13.2 Circuit Breaker | Mục 10.4, NFR-REL-01..03 |
| §14 Payment – PayOS | Mục 4.7, 4.8, 10.2 |
| §18 Testing Scope, §19 Acceptance Criteria | Mục 13 |

## Phụ lục B. Môi trường demo

| Thành phần | Địa chỉ |
|---|---|
| API Gateway | `http://localhost:5000` (Android emulator: `http://10.0.2.2:5000`) |
| App khách (web) | `http://localhost:8080` |
| Trang quản trị (web) | `http://localhost:8081` |
| Swagger | Auth `:5100`, Movie `:5168`, Booking `:5063` (`/swagger`) |
| RabbitMQ | `http://localhost:15672` |
| Grafana / Prometheus / Jaeger | `:3000` / `:9090` / `:16686` |

Tài khoản seed (mật khẩu `123456`): `admin@cinema.com` (Admin), `nhanvien1@cinema.com` (Staff), `khachhang1@gmail.com` (Customer).
