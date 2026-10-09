# Chức năng, endpoint và giao diện mobile

Nhánh: `feat/Ngữ/UI_Update`. Đối chiếu từ controller backend, service Flutter và router hiện tại. Có **73 endpoint nghiệp vụ** trong các controller; mỗi dòng dưới đây tương ứng một method + đường dẫn. Không tính Swagger, metrics và health check.

“Đã nối API” nghĩa là có lời gọi thật trong code; không khẳng định đã thử end-to-end với server, SMTP hay PayOS thật.

## Các màn đã tinh chỉnh

| Màn | UI mobile | API chính |
|---|---|---|
| Home | Hero gọn, poster dạng lưới, tìm kiếm, navigation Home–Tickets–Account | GET movies/status/ACTIVE |
| Tài khoản | Avatar viền cyan/cam, thông tin xếp dọc, các mục thao tác | GET auth/me |
| Đổi mật khẩu | Email được điền sẵn từ hồ sơ, OTP, mật khẩu mới và xác nhận | POST auth/forgot-password, POST auth/reset-password |
| Vé đã đặt | Active/History, thẻ vé, trạng thái, giờ chiếu, ghế, tổng tiền | GET bookings/user/{userId} |
| Lịch sử thanh toán | Số tiền, trạng thái, ngày, phương thức, mã giao dịch, mở chi tiết vé | GET payments/user/{userId} |

Các đường dẫn rút gọn trong bảng này có prefix `/api/v1/`; danh sách đầy đủ phía dưới. Nền, cyan/xanh dương, viền và quầng sáng dùng cùng thành phần với login. Hiệu ứng nền ở màn nội dung giảm độ sáng để ưu tiên đọc.

## Tài khoản

| Chức năng | Method | Endpoint | UI hiện có | Nguồn backend |
|---|---|---|---|---|
| Danh sách tài khoản | GET | `/api/v1/auth/users` | Chưa có UI nối endpoint này | [UsersController:24](../../Cinema_BE/AuthService/AuthService/Controllers/UsersController.cs#L24) |
| Chi tiết tài khoản | GET | `/api/v1/auth/users/{id}` | Chưa có UI nối endpoint này | [UsersController:36](../../Cinema_BE/AuthService/AuthService/Controllers/UsersController.cs#L36) |
| Tạo tài khoản | POST | `/api/v1/auth/users` | Chưa có UI nối endpoint này | [UsersController:43](../../Cinema_BE/AuthService/AuthService/Controllers/UsersController.cs#L43) |
| Đổi quyền tài khoản | PUT | `/api/v1/auth/users/{id}/roles` | Chưa có UI nối endpoint này | [UsersController:51](../../Cinema_BE/AuthService/AuthService/Controllers/UsersController.cs#L51) |
| Bật/tắt tài khoản | PATCH | `/api/v1/auth/users/{id}/status` | Chưa có UI nối endpoint này | [UsersController:58](../../Cinema_BE/AuthService/AuthService/Controllers/UsersController.cs#L58) |
| Danh sách vai trò | GET | `/api/v1/auth/roles` | Chưa có UI nối endpoint này | [RolesController:20](../../Cinema_BE/AuthService/AuthService/Controllers/RolesController.cs#L20) |
| Đăng ký tài khoản và gửi OTP | POST | `/api/v1/auth/register` | Đăng ký · đã nối API | [AuthController:22](../../Cinema_BE/AuthService/AuthService/Controllers/AuthController.cs#L22) |
| Xác thực email | POST | `/api/v1/auth/verify-email` | Xác thực email · đã nối API | [AuthController:30](../../Cinema_BE/AuthService/AuthService/Controllers/AuthController.cs#L30) |
| Gửi lại OTP xác thực | POST | `/api/v1/auth/resend-verification` | Gửi lại OTP · đã nối API | [AuthController:38](../../Cinema_BE/AuthService/AuthService/Controllers/AuthController.cs#L38) |
| Đăng nhập | POST | `/api/v1/auth/login` | Đăng nhập · đã nối API | [AuthController:46](../../Cinema_BE/AuthService/AuthService/Controllers/AuthController.cs#L46) |
| Gửi OTP đặt lại mật khẩu | POST | `/api/v1/auth/forgot-password` | Quên/đổi mật khẩu qua OTP · đã nối API | [AuthController:54](../../Cinema_BE/AuthService/AuthService/Controllers/AuthController.cs#L54) |
| Đặt mật khẩu mới bằng OTP | POST | `/api/v1/auth/reset-password` | Mật khẩu mới + xác nhận · đã nối API | [AuthController:62](../../Cinema_BE/AuthService/AuthService/Controllers/AuthController.cs#L62) |
| Làm mới token | POST | `/api/v1/auth/refresh` | Tự làm mới token, không có màn riêng | [AuthController:70](../../Cinema_BE/AuthService/AuthService/Controllers/AuthController.cs#L70) |
| Thu hồi refresh token | POST | `/api/v1/auth/logout` | Tài khoản → Đăng xuất · đã nối API | [AuthController:79](../../Cinema_BE/AuthService/AuthService/Controllers/AuthController.cs#L79) |
| Lấy hồ sơ hiện tại | GET | `/api/v1/auth/me` | Hồ sơ tài khoản · đã nối API | [AuthController:88](../../Cinema_BE/AuthService/AuthService/Controllers/AuthController.cs#L88) |

## Phim

| Chức năng | Method | Endpoint | UI hiện có | Nguồn backend |
|---|---|---|---|---|
| Danh sách phim | GET | `/api/v1/movies` | Chưa có UI nối endpoint này | [MoviesController:22](../../Cinema_BE/MovieService/MovieService/Controllers/MoviesController.cs#L22) |
| Chi tiết phim | GET | `/api/v1/movies/{id}` | Chi tiết phim · đã nối API | [MoviesController:34](../../Cinema_BE/MovieService/MovieService/Controllers/MoviesController.cs#L34) |
| Lọc trạng thái phim | GET | `/api/v1/movies/status/{status}` | Home/phim đang chiếu · đã nối API | [MoviesController:42](../../Cinema_BE/MovieService/MovieService/Controllers/MoviesController.cs#L42) |
| Tìm kiếm phim | GET | `/api/v1/movies/search` | Có ô tìm kiếm local trên Home; chưa gọi API này | [MoviesController:55](../../Cinema_BE/MovieService/MovieService/Controllers/MoviesController.cs#L55) |
| Tạo phim | POST | `/api/v1/movies` | Chưa có UI nối endpoint này | [MoviesController:68](../../Cinema_BE/MovieService/MovieService/Controllers/MoviesController.cs#L68) |
| Sửa phim | PUT | `/api/v1/movies/{id}` | Chưa có UI nối endpoint này | [MoviesController:77](../../Cinema_BE/MovieService/MovieService/Controllers/MoviesController.cs#L77) |
| Xoá phim | DELETE | `/api/v1/movies/{id}` | Chưa có UI nối endpoint này | [MoviesController:85](../../Cinema_BE/MovieService/MovieService/Controllers/MoviesController.cs#L85) |

## Phòng và ghế

| Chức năng | Method | Endpoint | UI hiện có | Nguồn backend |
|---|---|---|---|---|
| Danh sách phòng | GET | `/api/rooms` | Chưa có UI nối endpoint này | [RoomsController:24](../../Cinema_BE/MovieService/MovieService/Controllers/RoomsController.cs#L24) |
| Chi tiết phòng | GET | `/api/rooms/{roomId}` | Chưa có UI nối endpoint này | [RoomsController:41](../../Cinema_BE/MovieService/MovieService/Controllers/RoomsController.cs#L41) |
| Tạo phòng | POST | `/api/rooms` | Chưa có UI nối endpoint này | [RoomsController:52](../../Cinema_BE/MovieService/MovieService/Controllers/RoomsController.cs#L52) |
| Sửa phòng | PUT | `/api/rooms/{roomId}` | Chưa có UI nối endpoint này | [RoomsController:67](../../Cinema_BE/MovieService/MovieService/Controllers/RoomsController.cs#L67) |
| Xoá phòng | DELETE | `/api/rooms/{roomId}` | Chưa có UI nối endpoint này | [RoomsController:80](../../Cinema_BE/MovieService/MovieService/Controllers/RoomsController.cs#L80) |
| Tìm phòng | GET | `/api/rooms/search` | Chưa có UI nối endpoint này | [RoomsController:91](../../Cinema_BE/MovieService/MovieService/Controllers/RoomsController.cs#L91) |
| Chi tiết ghế | GET | `/api/seats/{seatId}` | Chưa có UI nối endpoint này | [SeatsController:23](../../Cinema_BE/MovieService/MovieService/Controllers/SeatsController.cs#L23) |
| Ghế trong phòng | GET | `/api/seats/room/{roomId}` | Sơ đồ ghế · đã nối API | [SeatsController:36](../../Cinema_BE/MovieService/MovieService/Controllers/SeatsController.cs#L36) |
| Sinh sơ đồ ghế | POST | `/api/seats/generate` | Chưa có UI nối endpoint này | [SeatsController:48](../../Cinema_BE/MovieService/MovieService/Controllers/SeatsController.cs#L48) |
| Đổi loại ghế | PUT | `/api/seats/{seatId}/type` | Chưa có UI nối endpoint này | [SeatsController:60](../../Cinema_BE/MovieService/MovieService/Controllers/SeatsController.cs#L60) |
| Xoá ghế | DELETE | `/api/seats/{seatId}` | Chưa có UI nối endpoint này | [SeatsController:73](../../Cinema_BE/MovieService/MovieService/Controllers/SeatsController.cs#L73) |

## Suất chiếu

| Chức năng | Method | Endpoint | UI hiện có | Nguồn backend |
|---|---|---|---|---|
| Danh sách suất chiếu | GET | `/api/showtimes` | Chưa có UI nối endpoint này | [ShowtimesController:23](../../Cinema_BE/MovieService/MovieService/Controllers/ShowtimesController.cs#L23) |
| Chi tiết suất chiếu | GET | `/api/showtimes/{showtimeId}` | Chọn ghế/mở URL suất chiếu · đã nối API | [ShowtimesController:41](../../Cinema_BE/MovieService/MovieService/Controllers/ShowtimesController.cs#L41) |
| Ghế phục vụ đặt vé | POST | `/api/showtimes/{showtimeId}/seats` | Có UI chọn ghế; lấy dữ liệu bằng hai API room/occupied-seats | [ShowtimesController:55](../../Cinema_BE/MovieService/MovieService/Controllers/ShowtimesController.cs#L55) |
| Tạo suất chiếu | POST | `/api/showtimes` | Chưa có UI nối endpoint này | [ShowtimesController:68](../../Cinema_BE/MovieService/MovieService/Controllers/ShowtimesController.cs#L68) |
| Sửa suất chiếu | PUT | `/api/showtimes/{showtimeId}` | Chưa có UI nối endpoint này | [ShowtimesController:83](../../Cinema_BE/MovieService/MovieService/Controllers/ShowtimesController.cs#L83) |
| Huỷ suất chiếu | DELETE | `/api/showtimes/{showtimeId}` | Chưa có UI nối endpoint này | [ShowtimesController:97](../../Cinema_BE/MovieService/MovieService/Controllers/ShowtimesController.cs#L97) |
| Đổi trạng thái suất chiếu | PATCH | `/api/showtimes/{showtimeId}/status` | Chưa có UI nối endpoint này | [ShowtimesController:108](../../Cinema_BE/MovieService/MovieService/Controllers/ShowtimesController.cs#L108) |
| Suất chiếu đang mở | GET | `/api/showtimes/open` | Chưa có UI nối endpoint này | [ShowtimesController:121](../../Cinema_BE/MovieService/MovieService/Controllers/ShowtimesController.cs#L121) |
| Suất chiếu theo phim | GET | `/api/showtimes/movie/{movieId}` | Chưa có UI nối endpoint này | [ShowtimesController:139](../../Cinema_BE/MovieService/MovieService/Controllers/ShowtimesController.cs#L139) |
| Suất chiếu đang mở theo phim | GET | `/api/showtimes/movie/{movieId}/open` | Suất chiếu trong chi tiết phim · đã nối API | [ShowtimesController:160](../../Cinema_BE/MovieService/MovieService/Controllers/ShowtimesController.cs#L160) |
| Suất chiếu theo khoảng ngày | GET | `/api/showtimes/date-range` | Chưa có UI nối endpoint này | [ShowtimesController:180](../../Cinema_BE/MovieService/MovieService/Controllers/ShowtimesController.cs#L180) |

## Đặt vé

| Chức năng | Method | Endpoint | UI hiện có | Nguồn backend |
|---|---|---|---|---|
| Danh sách vé | GET | `/api/v1/bookings` | Chưa có UI nối endpoint này | [BookingController:23](../../Cinema_BE/BookingService/BookingService/Controllers/BookingController.cs#L23) |
| Chi tiết vé | GET | `/api/v1/bookings/{id}` | Chi tiết vé/kết quả thanh toán · đã nối API | [BookingController:37](../../Cinema_BE/BookingService/BookingService/Controllers/BookingController.cs#L37) |
| Lịch sử theo người dùng vé | GET | `/api/v1/bookings/user/{userId}` | Vé đã đặt: Active/History · đã nối API | [BookingController:50](../../Cinema_BE/BookingService/BookingService/Controllers/BookingController.cs#L50) |
| Lọc trạng thái vé | GET | `/api/v1/bookings/status/{status}` | Chưa có UI nối endpoint này | [BookingController:69](../../Cinema_BE/BookingService/BookingService/Controllers/BookingController.cs#L69) |
| Lọc khoảng ngày vé | GET | `/api/v1/bookings/date-range` | Chưa có UI nối endpoint này | [BookingController:84](../../Cinema_BE/BookingService/BookingService/Controllers/BookingController.cs#L84) |
| Ghế đã giữ/đặt | GET | `/api/v1/bookings/showtime/{showtimeId}/occupied-seats` | Ghế đã giữ/đặt · đã nối API | [BookingController:100](../../Cinema_BE/BookingService/BookingService/Controllers/BookingController.cs#L100) |
| Tạo vé | POST | `/api/v1/bookings` | Xác nhận đặt vé · đã nối API | [BookingController:110](../../Cinema_BE/BookingService/BookingService/Controllers/BookingController.cs#L110) |
| Xác nhận vé tại quầy | POST | `/api/v1/bookings/{id}/confirm` | Chưa có UI nối endpoint này | [BookingController:133](../../Cinema_BE/BookingService/BookingService/Controllers/BookingController.cs#L133) |
| Huỷ vé | POST | `/api/v1/bookings/{id}/cancel` | Huỷ vé ở chi tiết · đã nối API | [BookingController:154](../../Cinema_BE/BookingService/BookingService/Controllers/BookingController.cs#L154) |

## Thanh toán và hoàn tiền

| Chức năng | Method | Endpoint | UI hiện có | Nguồn backend |
|---|---|---|---|---|
| Danh sách thanh toán | GET | `/api/v1/payments` | Chưa có UI nối endpoint này | [PaymentController:31](../../Cinema_BE/BookingService/BookingService/Controllers/PaymentController.cs#L31) |
| Chi tiết thanh toán | GET | `/api/v1/payments/{id}` | Chưa có UI nối endpoint này | [PaymentController:45](../../Cinema_BE/BookingService/BookingService/Controllers/PaymentController.cs#L45) |
| Lịch sử theo người dùng thanh toán | GET | `/api/v1/payments/user/{userId}` | Lịch sử thanh toán mobile · mới nối API | [PaymentController:58](../../Cinema_BE/BookingService/BookingService/Controllers/PaymentController.cs#L58) |
| Theo vé thanh toán | GET | `/api/v1/payments/booking/{bookingId}` | Chưa có UI nối endpoint này | [PaymentController:76](../../Cinema_BE/BookingService/BookingService/Controllers/PaymentController.cs#L76) |
| Tạo thanh toán | POST | `/api/v1/payments` | Chưa có UI nối endpoint này | [PaymentController:98](../../Cinema_BE/BookingService/BookingService/Controllers/PaymentController.cs#L98) |
| Tạo link thanh toán PayOS | POST | `/api/v1/payments/payos/checkout` | Thanh toán PayOS · đã nối API | [PaymentController:110](../../Cinema_BE/BookingService/BookingService/Controllers/PaymentController.cs#L110) |
| Xác minh thanh toán PayOS | POST | `/api/v1/payments/payos/{orderCode}/verify` | Kiểm tra thanh toán/kết quả · đã nối API | [PaymentController:125](../../Cinema_BE/BookingService/BookingService/Controllers/PaymentController.cs#L125) |
| Nhận webhook PayOS | POST | `/api/v1/payments/payos/webhook` | PayOS gọi server; không phải thao tác UI | [PaymentController:150](../../Cinema_BE/BookingService/BookingService/Controllers/PaymentController.cs#L150) |
| Xử lý thanh toán | POST | `/api/v1/payments/{id}/process` | Chưa có UI nối endpoint này | [PaymentController:164](../../Cinema_BE/BookingService/BookingService/Controllers/PaymentController.cs#L164) |
| Yêu cầu hoàn tiền | POST | `/api/v1/payments/{id}/refund` | Chưa có UI nối endpoint này | [PaymentController:176](../../Cinema_BE/BookingService/BookingService/Controllers/PaymentController.cs#L176) |
| Hoàn tiền của giao dịch | GET | `/api/v1/payments/{id}/refund` | Thông tin hoàn tiền trong chi tiết vé · đã nối API | [PaymentController:186](../../Cinema_BE/BookingService/BookingService/Controllers/PaymentController.cs#L186) |
| Danh sách yêu cầu hoàn tiền | GET | `/api/v1/payments/refunds` | Chưa có UI nối endpoint này | [PaymentController:200](../../Cinema_BE/BookingService/BookingService/Controllers/PaymentController.cs#L200) |
| Chi tiết hoàn tiền | GET | `/api/v1/payments/refunds/{refundId}` | Chưa có UI nối endpoint này | [PaymentController:210](../../Cinema_BE/BookingService/BookingService/Controllers/PaymentController.cs#L210) |
| Xác nhận đã hoàn tiền | POST | `/api/v1/payments/refunds/{refundId}/complete` | Chưa có UI nối endpoint này | [PaymentController:224](../../Cinema_BE/BookingService/BookingService/Controllers/PaymentController.cs#L224) |

## Thông báo

| Chức năng | Method | Endpoint | UI hiện có | Nguồn backend |
|---|---|---|---|---|
| Danh sách thông báo | GET | `/api/v1/notifications` | Chưa có UI nối endpoint này | [NotificationController:24](../../Cinema_BE/BookingService/BookingService/Controllers/NotificationController.cs#L24) |
| Chi tiết thông báo | GET | `/api/v1/notifications/{id}` | Có UI chi tiết lấy từ danh sách; chưa gọi API này | [NotificationController:36](../../Cinema_BE/BookingService/BookingService/Controllers/NotificationController.cs#L36) |
| Lịch sử theo người dùng thông báo | GET | `/api/v1/notifications/user/{userId}` | Danh sách thông báo · đã nối API | [NotificationController:49](../../Cinema_BE/BookingService/BookingService/Controllers/NotificationController.cs#L49) |
| Tạo thông báo | POST | `/api/v1/notifications` | Chưa có UI nối endpoint này | [NotificationController:66](../../Cinema_BE/BookingService/BookingService/Controllers/NotificationController.cs#L66) |
| Gửi thông báo | POST | `/api/v1/notifications/{id}/send` | Chưa có UI nối endpoint này | [NotificationController:74](../../Cinema_BE/BookingService/BookingService/Controllers/NotificationController.cs#L74) |
| Xoá thông báo | DELETE | `/api/v1/notifications/{id}` | Chưa có UI nối endpoint này | [NotificationController:82](../../Cinema_BE/BookingService/BookingService/Controllers/NotificationController.cs#L82) |

## Kết quả đối chiếu và giới hạn

1. **Đổi mật khẩu bằng mật khẩu hiện tại:** backend chưa có endpoint cho luồng ba ô trong ảnh mẫu. UI hiện dùng OTP email, có xác nhận mật khẩu mới; sau khi thành công xoá phiên local và yêu cầu đăng nhập lại.
2. **Sửa hồ sơ:** chưa có API cập nhật hồ sơ cá nhân. Màn tài khoản đang hiển thị dữ liệu thật; không có nút lưu giả.
3. **Tìm phim:** ô tìm kiếm trên Home lọc danh sách đã tải. `GET /api/v1/movies/search` tồn tại nhưng chưa được gọi từ ô này.
4. **Vé và thông báo:** repository hiện lấy trang đầu tối đa 50 bản ghi. Khi tài khoản vượt 50 bản ghi cần thêm tải trang tiếp; lịch sử thanh toán mới đã đọc đủ các trang.
5. **Quản trị:** các API quản lý user, role, phim, phòng, ghế, suất chiếu, xử lý hoàn tiền và gửi thông báo chưa có UI quản trị trong app khách hàng.
6. **Chi tiết thông báo:** UI hiện lấy đối tượng từ danh sách. Mở URL chi tiết mà không có đối tượng sẽ về danh sách; backend thực tế có GET thông báo theo id nhưng Flutter chưa nối.

Không thay đổi backend, cơ chế giữ ghế, tính tiền hoặc PayOS webhook trong lần tinh chỉnh UI này. Chưa kiểm tra thiết bị thật, email thật, thanh toán thật hoặc tải đồng thời nhiều người dùng.

## Các file chính

- [Home](../lib/features/home/screens/home_screen.dart)
- [Tài khoản](../lib/features/profile/screens/profile_screen.dart)
- [Vé đã đặt](../lib/features/booking/screens/my_bookings_screen.dart)
- [Lịch sử thanh toán](../lib/features/payment/screens/payment_history_screen.dart)
- [Gửi OTP](../lib/features/auth/screens/forgot_password_screen.dart)
- [Mật khẩu mới](../lib/features/auth/screens/reset_password_screen.dart)
