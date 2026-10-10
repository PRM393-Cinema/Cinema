# Chức năng, endpoint và giao diện mobile

Nhánh: `feat/Ngữ/UI_Update`. Đối chiếu từ controller backend, service Flutter và router hiện tại. Có **73 endpoint nghiệp vụ** trong các controller; mỗi dòng dưới đây tương ứng một method + đường dẫn. Không tính Swagger, metrics và health check.

“Đã nối API” nghĩa là có lời gọi thật trong code; không khẳng định đã thử end-to-end với server, SMTP hay PayOS thật.

## Màn hình và endpoint đã kết nối

Cập nhật: 10/10/2026. Đây là bảng kiểm tra kết nối API, không phải lịch sử sửa giao diện. Các bảng theo nhóm bên dưới liệt kê cả endpoint chưa nối để đối chiếu phần còn thiếu.

| Màn/chức năng | Route mobile | Endpoint gọi thật | Trạng thái |
|---|---|---|---|
| Home | `/home` | GET `/api/v1/movies/status/ACTIVE` | Đã nối; tìm kiếm hiện lọc local |
| Đăng nhập | `/login` | POST `/api/v1/auth/login` | Đã nối |
| Đăng ký | `/register` | POST `/api/v1/auth/register` | Đã nối |
| Xác thực email/gửi lại OTP | `/verify-email` | POST `/api/v1/auth/verify-email`; POST `/api/v1/auth/resend-verification` | Đã nối |
| Quên/đổi mật khẩu: gửi mã | `/forgot-password` | POST `/api/v1/auth/forgot-password` | Đã nối; Login và Account dùng cùng màn |
| Đặt mật khẩu mới | `/reset-password` | POST `/api/v1/auth/reset-password`; POST `/api/v1/auth/logout` | Đã nối; cần email từ bước gửi mã |
| Tài khoản/đăng xuất | `/profile` | GET `/api/v1/auth/me`; POST `/api/v1/auth/logout` | Đã nối |
| Chi tiết phim và suất chiếu | `/movies/{id}` | GET `/api/v1/movies/{id}`; GET `/api/showtimes/movie/{movieId}/open` | Đã nối |
| Chọn ghế | `/showtimes/{id}/seats` | GET `/api/showtimes/{showtimeId}`; GET `/api/seats/room/{roomId}`; GET `/api/v1/bookings/showtime/{showtimeId}/occupied-seats` | Đã nối |
| Xác nhận đặt vé | `/showtimes/{id}/summary` | POST `/api/v1/bookings` | Đã nối; ghế được truyền từ màn chọn ghế |
| Vé đã đặt | `/bookings` | GET `/api/v1/bookings/user/{userId}` | Đã nối; mới lấy trang đầu |
| Chi tiết/hủy vé | `/bookings/{id}` | GET `/api/v1/bookings/{id}`; POST `/api/v1/bookings/{id}/cancel`; GET `/api/v1/payments/{id}/refund` | Đã nối |
| Thanh toán/kết quả | `/bookings/{id}/payment`, `/bookings/{id}/result` | GET `/api/v1/bookings/{id}`; POST `/api/v1/payments/payos/checkout`; POST `/api/v1/payments/payos/{orderCode}/verify` | Đã nối |
| Lịch sử thanh toán | `/payments` | GET `/api/v1/payments/user/{userId}` | Đã nối; đọc đủ các trang |
| Danh sách thông báo/làm mới | `/notifications` | GET `/api/v1/notifications/user/{userId}` | Đã nối; đọc đủ các trang |
| Chi tiết thông báo/mở vé liên quan | `/notifications/{id}` | GET `/api/v1/notifications/{id}`; GET `/api/v1/bookings/{id}` khi mở vé | Đã nối; tải theo ID, hỗ trợ mở lại URL |
| Làm mới phiên | Không có màn riêng | POST `/api/v1/auth/refresh` | Đã nối tự động trong lớp API |
| Dashboard Admin | `/admin/dashboard` | GET `/api/v1/auth/users` (tổng/active/locked); GET `/api/v1/auth/roles` | Đã nối; thống kê từ API thật, ROLE_ADMIN |
| Hồ sơ Admin | `/admin/profile` | GET `/api/v1/auth/me`; POST `/api/v1/auth/logout` | Đã nối; hồ sơ và đăng xuất trong khu vực Admin |
| Quản lý tài khoản Admin | `/admin/users` | GET `/api/v1/auth/users`; GET `/api/v1/auth/roles` | Đã nối; tìm kiếm, lọc quyền/trạng thái, phân trang; chỉ ROLE_ADMIN |
| Chi tiết/phân quyền/khóa tài khoản | `/admin/users/{id}` | GET `/api/v1/auth/users/{id}`; GET `/api/v1/auth/roles`; PUT `/api/v1/auth/users/{id}/roles`; PATCH `/api/v1/auth/users/{id}/status` | Đã nối; chỉ ROLE_ADMIN |
| Tạo tài khoản (Admin quản lý) | `/admin/users/new` | GET `/api/v1/auth/roles`; POST `/api/v1/auth/users` | Đã nối; chọn một hoặc nhiều quyền; chỉ ROLE_ADMIN |
| Dashboard Staff | `/staff/dashboard` | GET `/api/v1/bookings/status/PENDING`; GET `/api/v1/bookings/date-range`; GET `/api/v1/payments/refunds`; GET `/api/showtimes/date-range` | Đã nối; thống kê từ API thật |
| Nghiệp vụ Staff | `/staff/operations` | GET `/api/v1/bookings`, `/api/v1/bookings/status/{status}`, `/api/v1/bookings/date-range`; GET `/api/showtimes`, `/api/showtimes/date-range`; GET `/api/rooms`, `/api/rooms/search`; GET `/api/v1/payments`, `/api/v1/payments/refunds` | Đã nối; 5 nhóm, lọc/phân trang |
| Đặt vé hộ khách | `/staff/bookings/new` | POST `/api/v1/bookings`; GET `/api/showtimes/{id}`, `/api/seats/room/{id}`, `/api/v1/bookings/showtime/{id}/occupied-seats` | Đã nối; ID/email khách và chọn ghế thật |
| Chi tiết/xác nhận/hủy vé Staff | `/staff/bookings/{id}` | GET `/api/v1/bookings/{id}`; GET `/api/v1/payments/booking/{bookingId}`; POST `/api/v1/bookings/{id}/confirm`, `/api/v1/bookings/{id}/cancel` | Đã nối; xác nhận tay có điều kiện |
| Suất chiếu Staff | `/staff/showtimes/{id}`, `/staff/showtimes/new`, `/staff/showtimes/{id}/edit` | GET `/api/showtimes/{id}`, `/api/v1/movies`, `/api/rooms`; POST `/api/showtimes`; PUT `/api/showtimes/{id}`; PATCH `/api/showtimes/{id}/status`; DELETE `/api/showtimes/{id}` | Đã nối; tạo/sửa/mở/đóng/hủy |
| Phòng/ghế Staff | `/staff/rooms/{id}` | GET `/api/rooms/{id}`, `/api/seats/room/{id}`, `/api/seats/{id}`; POST `/api/seats/generate`; PUT `/api/seats/{id}/type` | Đã nối; không có thao tác phòng/ghế chỉ dành Admin |
| Thanh toán/hoàn tiền Staff | `/staff/payments/{id}`, `/staff/refunds/{id}` | GET `/api/v1/payments/{id}`, `/api/v1/payments/refunds/{id}`; POST `/api/v1/payments/{id}/process`, `/api/v1/payments/{id}/refund`, `/api/v1/payments/refunds/{id}/complete` | Đã nối; PayOS xác minh thật, hoàn tiền ghi nhận chuyển khoản |
| Thông báo cho khách | `/staff/bookings/{id}/notify` | GET `/api/v1/bookings/{id}`; POST `/api/v1/notifications`; POST `/api/v1/notifications/{id}/send` | Đã nối; retry cùng ID khi gửi thất bại |
| Hồ sơ Staff | `/staff/profile` | GET `/api/v1/auth/me`; POST `/api/v1/auth/logout` | Đã nối; đổi mật khẩu dùng luồng OTP chung |

Admin đăng nhập hoặc mở `/home` khi còn phiên sẽ vào `/admin/dashboard`. Khu vực quản trị có nav dưới riêng: **Dashboard / Accounts / Profile**; màn tạo và chi tiết tài khoản thuộc tab Accounts. Các màn chỉ dành cho ROLE_ADMIN, dùng chung API/AuthService hiện có. Customer dùng giao diện khách hàng. Staff có ROLE_STAFF đăng nhập vào `/staff/dashboard`, nav **Dashboard / Operations / Profile**. ROLE_ADMIN ưu tiên dashboard Admin nhưng backend cho phép truy cập nghiệp vụ Staff. Customer bị chặn các route `/staff/*`. Xem [STAFF_WORKSPACE.md](STAFF_WORKSPACE.md) về quy trình và giới hạn API.

## Tài khoản

| Chức năng | Method | Endpoint | UI hiện có | Nguồn backend |
|---|---|---|---|---|
| Danh sách tài khoản | GET | `/api/v1/auth/users` | Admin → Manage accounts · đã nối API | [UsersController:24](../../Cinema_BE/AuthService/AuthService/Controllers/UsersController.cs#L24) |
| Chi tiết tài khoản | GET | `/api/v1/auth/users/{id}` | Admin → Account details · đã nối API | [UsersController:36](../../Cinema_BE/AuthService/AuthService/Controllers/UsersController.cs#L36) |
| Tạo tài khoản | POST | `/api/v1/auth/users` | Admin → Create account · đã nối API | [UsersController:43](../../Cinema_BE/AuthService/AuthService/Controllers/UsersController.cs#L43) |
| Đổi quyền tài khoản | PUT | `/api/v1/auth/users/{id}/roles` | Admin → Account details → Save roles · đã nối API | [UsersController:51](../../Cinema_BE/AuthService/AuthService/Controllers/UsersController.cs#L51) |
| Bật/tắt tài khoản | PATCH | `/api/v1/auth/users/{id}/status` | Admin → Account details → Lock/Unlock account · đã nối API | [UsersController:58](../../Cinema_BE/AuthService/AuthService/Controllers/UsersController.cs#L58) |
| Danh sách vai trò | GET | `/api/v1/auth/roles` | Bộ lọc/quyền tại các màn Admin · đã nối API | [RolesController:20](../../Cinema_BE/AuthService/AuthService/Controllers/RolesController.cs#L20) |
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
| Danh sách phim | GET | `/api/v1/movies` | Staff → chọn phim khi tạo/sửa suất chiếu · đã nối API | [MoviesController:22](../../Cinema_BE/MovieService/MovieService/Controllers/MoviesController.cs#L22) |
| Chi tiết phim | GET | `/api/v1/movies/{id}` | Chi tiết phim · đã nối API | [MoviesController:34](../../Cinema_BE/MovieService/MovieService/Controllers/MoviesController.cs#L34) |
| Lọc trạng thái phim | GET | `/api/v1/movies/status/{status}` | Home/phim đang chiếu · đã nối API | [MoviesController:42](../../Cinema_BE/MovieService/MovieService/Controllers/MoviesController.cs#L42) |
| Tìm kiếm phim | GET | `/api/v1/movies/search` | Có ô tìm kiếm local trên Home; chưa gọi API này | [MoviesController:55](../../Cinema_BE/MovieService/MovieService/Controllers/MoviesController.cs#L55) |
| Tạo phim | POST | `/api/v1/movies` | Chưa có UI nối endpoint này | [MoviesController:68](../../Cinema_BE/MovieService/MovieService/Controllers/MoviesController.cs#L68) |
| Sửa phim | PUT | `/api/v1/movies/{id}` | Chưa có UI nối endpoint này | [MoviesController:77](../../Cinema_BE/MovieService/MovieService/Controllers/MoviesController.cs#L77) |
| Xoá phim | DELETE | `/api/v1/movies/{id}` | Chưa có UI nối endpoint này | [MoviesController:85](../../Cinema_BE/MovieService/MovieService/Controllers/MoviesController.cs#L85) |

## Phòng và ghế

| Chức năng | Method | Endpoint | UI hiện có | Nguồn backend |
|---|---|---|---|---|
| Danh sách phòng | GET | `/api/rooms` | Staff → Rooms/chọn phòng khi tạo suất chiếu · đã nối API | [RoomsController:24](../../Cinema_BE/MovieService/MovieService/Controllers/RoomsController.cs#L24) |
| Chi tiết phòng | GET | `/api/rooms/{roomId}` | Staff → Room details · đã nối API | [RoomsController:41](../../Cinema_BE/MovieService/MovieService/Controllers/RoomsController.cs#L41) |
| Tạo phòng | POST | `/api/rooms` | Chưa có UI nối endpoint này | [RoomsController:52](../../Cinema_BE/MovieService/MovieService/Controllers/RoomsController.cs#L52) |
| Sửa phòng | PUT | `/api/rooms/{roomId}` | Chưa có UI nối endpoint này | [RoomsController:67](../../Cinema_BE/MovieService/MovieService/Controllers/RoomsController.cs#L67) |
| Xoá phòng | DELETE | `/api/rooms/{roomId}` | Chưa có UI nối endpoint này | [RoomsController:80](../../Cinema_BE/MovieService/MovieService/Controllers/RoomsController.cs#L80) |
| Tìm phòng | GET | `/api/rooms/search` | Staff → tìm phòng · đã nối API | [RoomsController:91](../../Cinema_BE/MovieService/MovieService/Controllers/RoomsController.cs#L91) |
| Chi tiết ghế | GET | `/api/seats/{seatId}` | Staff → đọc ghế trước khi đổi loại · đã nối API | [SeatsController:23](../../Cinema_BE/MovieService/MovieService/Controllers/SeatsController.cs#L23) |
| Ghế trong phòng | GET | `/api/seats/room/{roomId}` | Sơ đồ ghế · đã nối API | [SeatsController:36](../../Cinema_BE/MovieService/MovieService/Controllers/SeatsController.cs#L36) |
| Sinh sơ đồ ghế | POST | `/api/seats/generate` | Staff → phòng trống → Generate seat layout · đã nối API | [SeatsController:48](../../Cinema_BE/MovieService/MovieService/Controllers/SeatsController.cs#L48) |
| Đổi loại ghế | PUT | `/api/seats/{seatId}/type` | Staff → Room details → đổi NORMAL/VIP · đã nối API | [SeatsController:60](../../Cinema_BE/MovieService/MovieService/Controllers/SeatsController.cs#L60) |
| Xoá ghế | DELETE | `/api/seats/{seatId}` | Chưa có UI nối endpoint này | [SeatsController:73](../../Cinema_BE/MovieService/MovieService/Controllers/SeatsController.cs#L73) |

## Suất chiếu

| Chức năng | Method | Endpoint | UI hiện có | Nguồn backend |
|---|---|---|---|---|
| Danh sách suất chiếu | GET | `/api/showtimes` | Staff → Operations → Showtimes · đã nối API, phân trang | [ShowtimesController:23](../../Cinema_BE/MovieService/MovieService/Controllers/ShowtimesController.cs#L23) |
| Chi tiết suất chiếu | GET | `/api/showtimes/{showtimeId}` | Chọn ghế/mở URL suất chiếu · đã nối API | [ShowtimesController:41](../../Cinema_BE/MovieService/MovieService/Controllers/ShowtimesController.cs#L41) |
| Ghế phục vụ đặt vé | POST | `/api/showtimes/{showtimeId}/seats` | Có UI chọn ghế; lấy dữ liệu bằng hai API room/occupied-seats | [ShowtimesController:55](../../Cinema_BE/MovieService/MovieService/Controllers/ShowtimesController.cs#L55) |
| Tạo suất chiếu | POST | `/api/showtimes` | Staff → Create showtime · đã nối API | [ShowtimesController:68](../../Cinema_BE/MovieService/MovieService/Controllers/ShowtimesController.cs#L68) |
| Sửa suất chiếu | PUT | `/api/showtimes/{showtimeId}` | Staff → Edit showtime · đã nối API | [ShowtimesController:83](../../Cinema_BE/MovieService/MovieService/Controllers/ShowtimesController.cs#L83) |
| Huỷ suất chiếu | DELETE | `/api/showtimes/{showtimeId}` | Staff → Showtime details → Cancel · đã nối API | [ShowtimesController:97](../../Cinema_BE/MovieService/MovieService/Controllers/ShowtimesController.cs#L97) |
| Đổi trạng thái suất chiếu | PATCH | `/api/showtimes/{showtimeId}/status` | Staff → Showtime details → Open/Close sales · đã nối API | [ShowtimesController:108](../../Cinema_BE/MovieService/MovieService/Controllers/ShowtimesController.cs#L108) |
| Suất chiếu đang mở | GET | `/api/showtimes/open` | Chưa có UI nối endpoint này | [ShowtimesController:121](../../Cinema_BE/MovieService/MovieService/Controllers/ShowtimesController.cs#L121) |
| Suất chiếu theo phim | GET | `/api/showtimes/movie/{movieId}` | Chưa có UI nối endpoint này | [ShowtimesController:139](../../Cinema_BE/MovieService/MovieService/Controllers/ShowtimesController.cs#L139) |
| Suất chiếu đang mở theo phim | GET | `/api/showtimes/movie/{movieId}/open` | Suất chiếu trong chi tiết phim · đã nối API | [ShowtimesController:160](../../Cinema_BE/MovieService/MovieService/Controllers/ShowtimesController.cs#L160) |
| Suất chiếu theo khoảng ngày | GET | `/api/showtimes/date-range` | Staff → bộ lọc ngày suất chiếu/Dashboard · đã nối API | [ShowtimesController:180](../../Cinema_BE/MovieService/MovieService/Controllers/ShowtimesController.cs#L180) |

## Đặt vé

| Chức năng | Method | Endpoint | UI hiện có | Nguồn backend |
|---|---|---|---|---|
| Danh sách vé | GET | `/api/v1/bookings` | Staff → Operations → Bookings · đã nối API, phân trang | [BookingController:23](../../Cinema_BE/BookingService/BookingService/Controllers/BookingController.cs#L23) |
| Chi tiết vé | GET | `/api/v1/bookings/{id}` | Chi tiết vé khách / Staff → Booking details · đã nối API | [BookingController:37](../../Cinema_BE/BookingService/BookingService/Controllers/BookingController.cs#L37) |
| Lịch sử theo người dùng vé | GET | `/api/v1/bookings/user/{userId}` | Vé đã đặt: Active/History · đã nối API | [BookingController:50](../../Cinema_BE/BookingService/BookingService/Controllers/BookingController.cs#L50) |
| Lọc trạng thái vé | GET | `/api/v1/bookings/status/{status}` | Staff → bộ lọc trạng thái vé/Dashboard · đã nối API | [BookingController:69](../../Cinema_BE/BookingService/BookingService/Controllers/BookingController.cs#L69) |
| Lọc khoảng ngày vé | GET | `/api/v1/bookings/date-range` | Staff → bộ lọc ngày tạo vé/Dashboard · đã nối API | [BookingController:84](../../Cinema_BE/BookingService/BookingService/Controllers/BookingController.cs#L84) |
| Ghế đã giữ/đặt | GET | `/api/v1/bookings/showtime/{showtimeId}/occupied-seats` | Ghế đã giữ/đặt · đã nối API | [BookingController:100](../../Cinema_BE/BookingService/BookingService/Controllers/BookingController.cs#L100) |
| Tạo vé | POST | `/api/v1/bookings` | Đặt vé khách / Staff → Book for customer · đã nối API | [BookingController:110](../../Cinema_BE/BookingService/BookingService/Controllers/BookingController.cs#L110) |
| Xác nhận vé tại quầy | POST | `/api/v1/bookings/{id}/confirm` | Staff → Booking details → Confirm at counter · đã nối API | [BookingController:133](../../Cinema_BE/BookingService/BookingService/Controllers/BookingController.cs#L133) |
| Huỷ vé | POST | `/api/v1/bookings/{id}/cancel` | Hủy vé khách / Staff → Booking details → Cancel · đã nối API | [BookingController:154](../../Cinema_BE/BookingService/BookingService/Controllers/BookingController.cs#L154) |

## Thanh toán và hoàn tiền

| Chức năng | Method | Endpoint | UI hiện có | Nguồn backend |
|---|---|---|---|---|
| Danh sách thanh toán | GET | `/api/v1/payments` | Staff → Operations → Payments · đã nối API, phân trang | [PaymentController:31](../../Cinema_BE/BookingService/BookingService/Controllers/PaymentController.cs#L31) |
| Chi tiết thanh toán | GET | `/api/v1/payments/{id}` | Staff → Payment details · đã nối API | [PaymentController:45](../../Cinema_BE/BookingService/BookingService/Controllers/PaymentController.cs#L45) |
| Lịch sử theo người dùng thanh toán | GET | `/api/v1/payments/user/{userId}` | Lịch sử thanh toán mobile · mới nối API | [PaymentController:58](../../Cinema_BE/BookingService/BookingService/Controllers/PaymentController.cs#L58) |
| Theo vé thanh toán | GET | `/api/v1/payments/booking/{bookingId}` | Staff → Booking details → danh sách giao dịch · đã nối API | [PaymentController:76](../../Cinema_BE/BookingService/BookingService/Controllers/PaymentController.cs#L76) |
| Tạo thanh toán | POST | `/api/v1/payments` | Chưa có UI nối endpoint này | [PaymentController:98](../../Cinema_BE/BookingService/BookingService/Controllers/PaymentController.cs#L98) |
| Tạo link thanh toán PayOS | POST | `/api/v1/payments/payos/checkout` | Thanh toán PayOS · đã nối API | [PaymentController:110](../../Cinema_BE/BookingService/BookingService/Controllers/PaymentController.cs#L110) |
| Xác minh thanh toán PayOS | POST | `/api/v1/payments/payos/{orderCode}/verify` | Kiểm tra thanh toán/kết quả · đã nối API | [PaymentController:125](../../Cinema_BE/BookingService/BookingService/Controllers/PaymentController.cs#L125) |
| Nhận webhook PayOS | POST | `/api/v1/payments/payos/webhook` | PayOS gọi server; không phải thao tác UI | [PaymentController:150](../../Cinema_BE/BookingService/BookingService/Controllers/PaymentController.cs#L150) |
| Xử lý thanh toán | POST | `/api/v1/payments/{id}/process` | Staff → Payment details → Verify with PayOS · đã nối API | [PaymentController:164](../../Cinema_BE/BookingService/BookingService/Controllers/PaymentController.cs#L164) |
| Yêu cầu hoàn tiền | POST | `/api/v1/payments/{id}/refund` | Staff → Payment details → Request refund · đã nối API | [PaymentController:176](../../Cinema_BE/BookingService/BookingService/Controllers/PaymentController.cs#L176) |
| Hoàn tiền của giao dịch | GET | `/api/v1/payments/{id}/refund` | Thông tin hoàn tiền trong chi tiết vé · đã nối API | [PaymentController:186](../../Cinema_BE/BookingService/BookingService/Controllers/PaymentController.cs#L186) |
| Danh sách yêu cầu hoàn tiền | GET | `/api/v1/payments/refunds` | Staff → Operations → Refunds/Dashboard · đã nối API | [PaymentController:200](../../Cinema_BE/BookingService/BookingService/Controllers/PaymentController.cs#L200) |
| Chi tiết hoàn tiền | GET | `/api/v1/payments/refunds/{refundId}` | Staff → Refund details · đã nối API | [PaymentController:210](../../Cinema_BE/BookingService/BookingService/Controllers/PaymentController.cs#L210) |
| Xác nhận đã hoàn tiền | POST | `/api/v1/payments/refunds/{refundId}/complete` | Staff → Refund details → Record completed transfer · đã nối API | [PaymentController:224](../../Cinema_BE/BookingService/BookingService/Controllers/PaymentController.cs#L224) |

## Thông báo

| Chức năng | Method | Endpoint | UI hiện có | Nguồn backend |
|---|---|---|---|---|
| Danh sách thông báo | GET | `/api/v1/notifications` | Chưa có UI nối endpoint này | [NotificationController:24](../../Cinema_BE/BookingService/BookingService/Controllers/NotificationController.cs#L24) |
| Chi tiết thông báo | GET | `/api/v1/notifications/{id}` | Chi tiết thông báo theo ID · đã nối API | [NotificationController:36](../../Cinema_BE/BookingService/BookingService/Controllers/NotificationController.cs#L36) |
| Lịch sử theo người dùng thông báo | GET | `/api/v1/notifications/user/{userId}` | Danh sách thông báo · đã nối API | [NotificationController:49](../../Cinema_BE/BookingService/BookingService/Controllers/NotificationController.cs#L49) |
| Tạo thông báo | POST | `/api/v1/notifications` | Staff → Booking details → Customer notification · đã nối API | [NotificationController:66](../../Cinema_BE/BookingService/BookingService/Controllers/NotificationController.cs#L66) |
| Gửi thông báo | POST | `/api/v1/notifications/{id}/send` | Staff → gửi/gửi lại thông báo đã tạo · đã nối API | [NotificationController:74](../../Cinema_BE/BookingService/BookingService/Controllers/NotificationController.cs#L74) |
| Xoá thông báo | DELETE | `/api/v1/notifications/{id}` | Chưa có UI nối endpoint này | [NotificationController:82](../../Cinema_BE/BookingService/BookingService/Controllers/NotificationController.cs#L82) |

## Kết quả đối chiếu và giới hạn

1. **Đổi mật khẩu bằng mật khẩu hiện tại:** backend chưa có endpoint cho luồng ba ô trong ảnh mẫu. UI hiện dùng OTP email, có xác nhận mật khẩu mới; sau khi thành công xoá phiên local và yêu cầu đăng nhập lại.
2. **Sửa hồ sơ:** chưa có API cập nhật hồ sơ cá nhân. Màn tài khoản đang hiển thị dữ liệu thật; không có nút lưu giả.
3. **Tìm phim:** ô tìm kiếm trên Home lọc danh sách đã tải. `GET /api/v1/movies/search` tồn tại nhưng chưa được gọi từ ô này.
4. **Phân trang:** vé đã đặt hiện chỉ lấy trang đầu tối đa 50 bản ghi; thông báo và lịch sử thanh toán đã đọc đủ các trang. Hai danh sách này tải toàn bộ khi mở/làm mới, chưa tải thêm theo cuộn.
5. **Quản trị:** các API quản lý user, role, phim, phòng, ghế, suất chiếu, xử lý hoàn tiền và gửi thông báo chưa có UI quản trị trong app khách hàng.
6. **Thông báo còn thiếu:** DELETE `/api/v1/notifications/{id}` có ở backend nhưng chưa có thao tác xóa trên mobile. Backend chưa có endpoint đánh dấu đã đọc/chưa đọc hoặc số thông báo chưa đọc. `status` hiện là trạng thái gửi email, không phải trạng thái đọc.
7. **Thông báo trống:** thông báo được tạo từ sự kiện xác nhận/hủy/hết hạn vé, yêu cầu/hoàn tiền. Đăng ký, xác thực email và đặt lại mật khẩu chưa tạo bản ghi trong lịch sử này. Không có dữ liệu mẫu tự chèn cho tài khoản mới; kéo xuống để lấy dữ liệu mới. Chưa có cập nhật thời gian thực/push notification.

Chưa kiểm tra thiết bị thật, email thật, thanh toán thật hoặc tải đồng thời nhiều người dùng. Trạng thái kết nối API ở trên được đối chiếu từ code.

## Các file chính

- [Home](../lib/features/home/screens/home_screen.dart)
- [Tài khoản](../lib/features/profile/screens/profile_screen.dart)
- [Vé đã đặt](../lib/features/booking/screens/my_bookings_screen.dart)
- [Lịch sử thanh toán](../lib/features/payment/screens/payment_history_screen.dart)
- [Gửi OTP](../lib/features/auth/screens/forgot_password_screen.dart)
- [Mật khẩu mới](../lib/features/auth/screens/reset_password_screen.dart)
- [Danh sách thông báo](../lib/features/notification/screens/notification_list_screen.dart)
- [Chi tiết thông báo](../lib/features/notification/screens/notification_detail_screen.dart)
