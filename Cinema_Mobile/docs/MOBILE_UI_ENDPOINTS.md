# Chức năng, endpoint và giao diện mobile

Nhánh: `feat/Ngữ/UI_Update`. Đối chiếu từ controller backend, service Flutter và router hiện tại. Có **73 endpoint nghiệp vụ** trong các controller; mỗi dòng dưới đây tương ứng một method + đường dẫn. Không tính Swagger, metrics và health check.

“Đã nối API” nghĩa là có lời gọi thật trong code; không khẳng định đã thử end-to-end với server, SMTP hay PayOS thật.

## Màn hình và endpoint đã kết nối

Cập nhật: 12/10/2026. Đây là bảng kiểm tra kết nối API, không phải lịch sử sửa giao diện. Các bảng theo nhóm bên dưới liệt kê cả endpoint chưa nối để đối chiếu phần còn thiếu.

| Màn/chức năng | Route mobile | Endpoint gọi thật | Trạng thái |
|---|---|---|---|
| Home | `/home` | GET `/api/v1/movies/status/ACTIVE` | Đã nối; tìm kiếm hiện lọc local |
| Đăng nhập | `/login` | POST `/api/v1/auth/login` | Đã nối |
| Đăng ký | `/register` | POST `/api/v1/auth/register` | Đã nối |
| Xác thực email/gửi lại OTP | `/verify-email` | POST `/api/v1/auth/verify-email`; POST `/api/v1/auth/resend-verification` | Đã nối |
| Quên/đổi mật khẩu: gửi mã | `/forgot-password` | POST `/api/v1/auth/forgot-password` | Đã nối; Login và Account dùng cùng màn |
| Đặt mật khẩu mới | `/reset-password` | POST `/api/v1/auth/reset-password`; POST `/api/v1/auth/logout` | Đã nối; cần email từ bước gửi mã |
| Tài khoản/đăng xuất | `/profile` | GET `/api/v1/auth/me`; POST `/api/v1/auth/logout` | Đã nối |
| Chi tiết phim và suất chiếu | `/movies/{id}` | GET `/api/v1/movies/{id}`; GET `/api/showtimes/movie/{movieId}/open` | Đã nối; nút **Watch trailer** mở `trailerUrl` của phim |
| Chọn ghế | `/showtimes/{id}/seats` | GET `/api/showtimes/{showtimeId}`; GET `/api/seats/room/{roomId}`; GET `/api/v1/bookings/showtime/{showtimeId}/occupied-seats` | Đã nối; màu theo loại ghế, hàng sweetbox ở cuối; sweetbox chọn / bỏ theo cặp (1-2, 3-4), server cũng từ chối đặt nửa cặp; giá theo loại ghế lấy từ `seatPrices` của suất chiếu; tự làm mới mỗi 5 giây, ghế đang chọn bị người khác đặt thì bỏ chọn và báo |
| Xác nhận đặt vé | `/showtimes/{id}/summary` | POST `/api/v1/bookings` | Đã nối; ghế được truyền từ màn chọn ghế |
| Vé đã đặt | `/bookings` | GET `/api/v1/bookings/user/{userId}` | Đã nối; mới lấy trang đầu |
| Chi tiết/hủy vé | `/bookings/{id}` | GET `/api/v1/bookings/{id}`; POST `/api/v1/bookings/{id}/cancel`; GET `/api/v1/payments/{id}/refund` | Đã nối; vé đã thanh toán có mã QR (mã vé) để check-in tại rạp, vé đã dùng hiện giờ check-in |
| Thanh toán/kết quả | `/bookings/{id}/payment`, `/bookings/{id}/result` | GET `/api/v1/bookings/{id}`; POST `/api/v1/payments/payos/checkout`; POST `/api/v1/payments/payos/{orderCode}/verify` | Đã nối |
| Lịch sử thanh toán | `/payments` | GET `/api/v1/payments/user/{userId}` | Đã nối; đọc đủ các trang |
| Danh sách thông báo/làm mới | `/notifications` | GET `/api/v1/notifications/user/{userId}` | Đã nối; đọc đủ các trang |
| Chi tiết thông báo/mở vé liên quan | `/notifications/{id}` | GET `/api/v1/notifications/{id}`; GET `/api/v1/bookings/{id}` khi mở vé | Đã nối; tải theo ID, hỗ trợ mở lại URL |
| Làm mới phiên | Không có màn riêng | POST `/api/v1/auth/refresh` | Đã nối tự động trong lớp API |
| Dashboard Admin | `/admin/dashboard` | GET `/api/v1/bookings/date-range`; GET `/api/v1/payments/summary`; GET `/api/v1/movies/status/ACTIVE`; GET `/api/showtimes/date-range`; GET `/api/v1/auth/users` (tổng/active/locked); GET `/api/v1/auth/roles` | Đã nối; booking và doanh thu tháng này, phim đang chiếu, suất hôm nay, rồi thống kê tài khoản (hai phần tải độc lập); ROLE_ADMIN |
| Hồ sơ Admin | `/admin/profile` | GET `/api/v1/auth/me`; POST `/api/v1/auth/logout` | Đã nối; hồ sơ và đăng xuất trong khu vực Admin |
| Quản lý tài khoản Admin | `/admin/users` | GET `/api/v1/auth/users`; GET `/api/v1/auth/roles` | Đã nối; tìm kiếm, lọc quyền/trạng thái, phân trang; chỉ ROLE_ADMIN |
| Chi tiết/phân quyền/khóa tài khoản | `/admin/users/{id}` | GET `/api/v1/auth/users/{id}`; GET `/api/v1/auth/roles`; PUT `/api/v1/auth/users/{id}/roles`; PATCH `/api/v1/auth/users/{id}/status` | Đã nối; chỉ ROLE_ADMIN |
| Quản lý phim (Admin) | `/admin/movies` | GET `/api/v1/movies`, `/api/v1/movies/status/{status}`, `/api/v1/movies/search`; POST `/api/v1/movies`; PUT `/api/v1/movies/{id}`; DELETE `/api/v1/movies/{id}` | Đã nối; thêm/sửa, ngừng chiếu và chiếu lại, lọc trạng thái, tìm tên, phân trang; chỉ ROLE_ADMIN |
| Quản lý phòng (Admin) | `/admin/rooms` | GET `/api/rooms`, `/api/rooms/search`; POST `/api/rooms`; POST `/api/seats/generate`; PUT `/api/rooms/{id}`; DELETE `/api/rooms/{id}` | Đã nối; thêm phòng kèm ghế, đổi tên, xoá phòng chưa có suất chiếu, mở sơ đồ ghế; chỉ ROLE_ADMIN |
| Tạo tài khoản (Admin quản lý) | `/admin/users/new` | GET `/api/v1/auth/roles`; POST `/api/v1/auth/users` | Đã nối; chọn một hoặc nhiều quyền; chỉ ROLE_ADMIN |
| Dashboard Staff | `/staff/dashboard` | GET `/api/v1/bookings/status/PENDING`; GET `/api/v1/bookings/date-range`; GET `/api/v1/payments/refunds`; GET `/api/showtimes/date-range` | Đã nối; thống kê từ API thật |
| Nghiệp vụ Staff | `/staff/operations` | GET `/api/v1/bookings`, `/api/v1/bookings/status/{status}`, `/api/v1/bookings/date-range`; GET `/api/showtimes`, `/api/showtimes/date-range`; GET `/api/rooms`, `/api/rooms/search`; GET `/api/v1/payments`, `/api/v1/payments/refunds` | Đã nối; 5 nhóm, lọc/phân trang |
| Đặt vé hộ khách | `/staff/bookings/new` | POST `/api/v1/bookings`; GET `/api/v1/movies/status/ACTIVE`, `/api/showtimes/movie/{movieId}/open`, `/api/seats/room/{id}`, `/api/v1/bookings/showtime/{id}/occupied-seats` | Đã nối; ID/email khách, chọn phim rồi suất trong 7 ngày tới, chọn ghế trên sơ đồ (sweetbox theo cặp, giá theo loại) |
| Chi tiết/xác nhận/hủy vé Staff | `/staff/bookings/{id}` | GET `/api/v1/bookings/{id}`; GET `/api/v1/payments/booking/{bookingId}`; POST `/api/v1/bookings/{id}/confirm`, `/api/v1/bookings/{id}/cancel`, `/api/v1/bookings/{id}/check-in` | Đã nối; xác nhận tay có điều kiện; check-in tại quầy |
| Check-in tại rạp | `/staff/check-in` (trang quản trị; app: tài khoản Staff → **Check in tickets**) | GET `/api/v1/bookings/code/{bookingCode}`; GET `/api/showtimes/{id}`; POST `/api/v1/bookings/{id}/check-in` | Đã nối; quét QR bằng camera (điện thoại, webcam) hoặc nhập mã / máy quét cầm tay (gõ mã + Enter) |
| Suất chiếu Staff | `/staff/showtimes/{id}`, `/staff/showtimes/new`, `/staff/showtimes/{id}/edit` | GET `/api/showtimes/{id}`, `/api/v1/movies`, `/api/rooms`; POST `/api/showtimes`; PUT `/api/showtimes/{id}`; PATCH `/api/showtimes/{id}/status`; DELETE `/api/showtimes/{id}` | Đã nối; tạo/sửa/mở/đóng/hủy |
| Phòng/ghế Staff | `/staff/rooms/{id}` | GET `/api/rooms/{id}`, `/api/seats/room/{id}`; POST `/api/seats/generate`; PUT `/api/seats/{id}/type`; PUT `/api/seats/room/{id}/types`; PUT `/api/seats/room/{id}/capacity` (Admin) | Đã nối; sơ đồ ghế theo hàng, màu theo loại ghế, tự làm mới mỗi 5 giây; tô loại ghế hàng loạt (chọn loại rồi bấm / kéo qua ghế, bấm chữ đầu hàng để đổi cả hàng); Admin đổi số ghế (ghế mới lấp hàng cuối rồi sang hàng mới); tạo/đổi tên/xoá phòng ở Admin → Rooms |
| Thanh toán/hoàn tiền Staff | `/staff/payments/{id}`, `/staff/refunds/{id}` | GET `/api/v1/payments/{id}`, `/api/v1/payments/refunds/{id}`; POST `/api/v1/payments/{id}/process`, `/api/v1/payments/{id}/refund`, `/api/v1/payments/refunds/{id}/complete` | Đã nối; PayOS xác minh thật, hoàn tiền ghi nhận chuyển khoản |
| Thông báo cho khách | `/staff/bookings/{id}/notify` | GET `/api/v1/bookings/{id}`; POST `/api/v1/notifications`; POST `/api/v1/notifications/{id}/send` | Đã nối; retry cùng ID khi gửi thất bại |
| Hồ sơ Staff | `/staff/profile` | GET `/api/v1/auth/me`; POST `/api/v1/auth/logout` | Đã nối; đổi mật khẩu dùng luồng OTP chung |

Các route `/admin/*` và `/staff/*` thuộc **trang quản trị web** (`lib/main_admin.dart`, phục vụ ở `/admin/`), không có trong app khách. Admin đăng nhập vào `/admin/dashboard`, thanh điều hướng bên trái **Dashboard / Operations / Movies / Rooms / Accounts / Profile**; Staff vào `/staff/dashboard` với **Dashboard / Operations / Profile**. Movies, Rooms, Accounts chỉ dành cho ROLE_ADMIN; Staff mở các trang này được đưa về dashboard. Tài khoản khách mở trang quản trị được chỉ về trang khách; tài khoản Staff/Admin đăng nhập app khách thấy hướng dẫn mở trang quản trị. Xem [STAFF_WORKSPACE.md](STAFF_WORKSPACE.md) về quy trình và giới hạn API.

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
| Danh sách phim | GET | `/api/v1/movies` | Admin → Movies; Staff → chọn phim khi tạo/sửa suất chiếu · đã nối API | [MoviesController:22](../../Cinema_BE/MovieService/MovieService/Controllers/MoviesController.cs#L22) |
| Chi tiết phim | GET | `/api/v1/movies/{id}` | Chi tiết phim · đã nối API | [MoviesController:34](../../Cinema_BE/MovieService/MovieService/Controllers/MoviesController.cs#L34) |
| Lọc trạng thái phim | GET | `/api/v1/movies/status/{status}` | Home/phim đang chiếu; Admin → Movies → lọc Showing/Stopped · đã nối API | [MoviesController:42](../../Cinema_BE/MovieService/MovieService/Controllers/MoviesController.cs#L42) |
| Tìm kiếm phim | GET | `/api/v1/movies/search` | Admin → Movies → tìm tên · đã nối API; ô tìm trên Home vẫn lọc local | [MoviesController:55](../../Cinema_BE/MovieService/MovieService/Controllers/MoviesController.cs#L55) |
| Tạo phim | POST | `/api/v1/movies` | Admin → Movies → Add movie · đã nối API | [MoviesController:68](../../Cinema_BE/MovieService/MovieService/Controllers/MoviesController.cs#L68) |
| Sửa phim | PUT | `/api/v1/movies/{id}` | Admin → Movies → Edit; Show again gửi `status: ACTIVE` · đã nối API | [MoviesController:77](../../Cinema_BE/MovieService/MovieService/Controllers/MoviesController.cs#L77) |
| Xoá phim | DELETE | `/api/v1/movies/{id}` | Admin → Movies → Stop showing (chuyển `INACTIVE`, không xoá dữ liệu) · đã nối API | [MoviesController:85](../../Cinema_BE/MovieService/MovieService/Controllers/MoviesController.cs#L85) |

## Phòng và ghế

| Chức năng | Method | Endpoint | UI hiện có | Nguồn backend |
|---|---|---|---|---|
| Danh sách phòng | GET | `/api/rooms` | Admin → Rooms; Staff → Rooms/chọn phòng khi tạo suất chiếu · đã nối API | [RoomsController:24](../../Cinema_BE/MovieService/MovieService/Controllers/RoomsController.cs#L24) |
| Chi tiết phòng | GET | `/api/rooms/{roomId}` | Staff → Room details · đã nối API | [RoomsController:41](../../Cinema_BE/MovieService/MovieService/Controllers/RoomsController.cs#L41) |
| Tạo phòng | POST | `/api/rooms` | Admin → Rooms → Add room (kèm sinh ghế) · đã nối API | [RoomsController:52](../../Cinema_BE/MovieService/MovieService/Controllers/RoomsController.cs#L52) |
| Sửa phòng | PUT | `/api/rooms/{roomId}` | Admin → Rooms → Rename (giữ nguyên ghế) · đã nối API | [RoomsController:67](../../Cinema_BE/MovieService/MovieService/Controllers/RoomsController.cs#L67) |
| Xoá phòng | DELETE | `/api/rooms/{roomId}` | Admin → Rooms → Delete (xoá cả ghế; bị từ chối khi phòng có suất chiếu) · đã nối API | [RoomsController:80](../../Cinema_BE/MovieService/MovieService/Controllers/RoomsController.cs#L80) |
| Tìm phòng | GET | `/api/rooms/search` | Staff → tìm phòng · đã nối API | [RoomsController:91](../../Cinema_BE/MovieService/MovieService/Controllers/RoomsController.cs#L91) |
| Chi tiết ghế | GET | `/api/seats/{seatId}` | Chưa có UI dùng (đổi loại ghế trả về ghế mới) | [SeatsController:23](../../Cinema_BE/MovieService/MovieService/Controllers/SeatsController.cs#L23) |
| Ghế trong phòng | GET | `/api/seats/room/{roomId}` | Sơ đồ ghế · đã nối API | [SeatsController:36](../../Cinema_BE/MovieService/MovieService/Controllers/SeatsController.cs#L36) |
| Sinh sơ đồ ghế | POST | `/api/seats/generate` | Admin → Rooms → Add room; Staff → phòng trống → Generate seat layout · đã nối API | [SeatsController:48](../../Cinema_BE/MovieService/MovieService/Controllers/SeatsController.cs#L48) |
| Đổi loại ghế | PUT | `/api/seats/{seatId}/type` | Staff → Room details → bấm ghế trên sơ đồ → NORMAL/VIP/SWEETBOX; sweetbox đổi cả cặp, ghế không có ghế cặp không thành sweetbox được · đã nối API | [SeatsController:60](../../Cinema_BE/MovieService/MovieService/Controllers/SeatsController.cs#L60) |
| Đổi loại nhiều ghế | PUT | `/api/seats/room/{roomId}/types` | Staff/Admin → Room details → Paint Standard / VIP / Sweetbox: bấm, kéo qua ghế hoặc bấm chữ đầu hàng; body `{ seatIds, seatType }`, sweetbox đổi cả cặp, hàng có ghế lẻ cặp thì 400 · đã nối API | [SeatsController:74](../../Cinema_BE/MovieService/MovieService/Controllers/SeatsController.cs#L74) |
| Đổi số ghế | PUT | `/api/seats/room/{roomId}/capacity` | Admin → Room details → Change seat count (thêm cuối sơ đồ / bỏ ghế cuối; chặn khi phòng có suất chiếu) · đã nối API | [SeatsController:88](../../Cinema_BE/MovieService/MovieService/Controllers/SeatsController.cs#L88) |
| Xoá ghế | DELETE | `/api/seats/{seatId}` | Chưa có UI nối endpoint này | [SeatsController:101](../../Cinema_BE/MovieService/MovieService/Controllers/SeatsController.cs#L101) |

## Suất chiếu

| Chức năng | Method | Endpoint | UI hiện có | Nguồn backend |
|---|---|---|---|---|
| Danh sách suất chiếu | GET | `/api/showtimes` | Staff → Operations → Showtimes · đã nối API, phân trang | [ShowtimesController:23](../../Cinema_BE/MovieService/MovieService/Controllers/ShowtimesController.cs#L23) |
| Chi tiết suất chiếu | GET | `/api/showtimes/{showtimeId}` | Chọn ghế/mở URL suất chiếu; `price` là giá ghế thường, `seatPrices` là giá một ghế theo loại (NORMAL, VIP, SWEETBOX) · đã nối API | [ShowtimesController:41](../../Cinema_BE/MovieService/MovieService/Controllers/ShowtimesController.cs#L41) |
| Ghế phục vụ đặt vé | POST | `/api/showtimes/{showtimeId}/seats` | BookingService gọi khi đặt vé, giá từng ghế theo loại ghế; app lấy sơ đồ bằng hai API room/occupied-seats | [ShowtimesController:55](../../Cinema_BE/MovieService/MovieService/Controllers/ShowtimesController.cs#L55) |
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
| Ghế đã đặt kèm vé (Staff) | GET | `/api/v1/bookings/showtime/{showtimeId}/seats` | Staff → Showtime details: sơ đồ ghế giữ chờ thanh toán / đã bán / đã check-in, bấm ghế mở vé · đã nối API | [BookingController:111](../../Cinema_BE/BookingService/BookingService/Controllers/BookingController.cs#L111) |
| Tra vé theo mã (Staff) | GET | `/api/v1/bookings/code/{bookingCode}` | Staff → Check-in: quét QR / nhập mã vé · đã nối API | [BookingController:123](../../Cinema_BE/BookingService/BookingService/Controllers/BookingController.cs#L123) |
| Check-in vé (Staff) | POST | `/api/v1/bookings/{id}/check-in` | Staff → Check-in / Booking details → Check in. Chỉ vé CONFIRMED, mỗi vé một lần, từ 3 giờ trước đến 2 giờ sau giờ chiếu (`CheckIn` trong appsettings); không được thì 409 kèm lý do · đã nối API | [BookingController:133](../../Cinema_BE/BookingService/BookingService/Controllers/BookingController.cs#L133) |
| Tạo vé | POST | `/api/v1/bookings` | Đặt vé khách / Staff → Book for customer · đã nối API | [BookingController:142](../../Cinema_BE/BookingService/BookingService/Controllers/BookingController.cs#L142) |
| Xác nhận vé tại quầy | POST | `/api/v1/bookings/{id}/confirm` | Staff → Booking details → Confirm at counter · đã nối API | [BookingController:165](../../Cinema_BE/BookingService/BookingService/Controllers/BookingController.cs#L165) |
| Huỷ vé | POST | `/api/v1/bookings/{id}/cancel` | Hủy vé khách / Staff → Booking details → Cancel · đã nối API | [BookingController:186](../../Cinema_BE/BookingService/BookingService/Controllers/BookingController.cs#L186) |

## Thanh toán và hoàn tiền

| Chức năng | Method | Endpoint | UI hiện có | Nguồn backend |
|---|---|---|---|---|
| Danh sách thanh toán | GET | `/api/v1/payments` | Staff → Operations → Payments · đã nối API, phân trang | [PaymentController:31](../../Cinema_BE/BookingService/BookingService/Controllers/PaymentController.cs#L31) |
| Doanh thu theo khoảng thời gian | GET | `/api/v1/payments/summary?start&end` | Admin → Dashboard: số thanh toán đã nhận và doanh thu (SUCCESS + REFUND_PENDING), tiền đã hoàn (REFUNDED), theo thời điểm tạo thanh toán; chỉ Admin · đã nối API | [PaymentController:46](../../Cinema_BE/BookingService/BookingService/Controllers/PaymentController.cs#L46) |
| Chi tiết thanh toán | GET | `/api/v1/payments/{id}` | Staff → Payment details · đã nối API | [PaymentController:57](../../Cinema_BE/BookingService/BookingService/Controllers/PaymentController.cs#L57) |
| Lịch sử theo người dùng thanh toán | GET | `/api/v1/payments/user/{userId}` | Lịch sử thanh toán mobile · mới nối API | [PaymentController:70](../../Cinema_BE/BookingService/BookingService/Controllers/PaymentController.cs#L70) |
| Theo vé thanh toán | GET | `/api/v1/payments/booking/{bookingId}` | Staff → Booking details → danh sách giao dịch · đã nối API | [PaymentController:88](../../Cinema_BE/BookingService/BookingService/Controllers/PaymentController.cs#L88) |
| Tạo thanh toán | POST | `/api/v1/payments` | Chưa có UI nối endpoint này | [PaymentController:110](../../Cinema_BE/BookingService/BookingService/Controllers/PaymentController.cs#L110) |
| Tạo link thanh toán PayOS | POST | `/api/v1/payments/payos/checkout` | Thanh toán PayOS · đã nối API | [PaymentController:122](../../Cinema_BE/BookingService/BookingService/Controllers/PaymentController.cs#L122) |
| Xác minh thanh toán PayOS | POST | `/api/v1/payments/payos/{orderCode}/verify` | Kiểm tra thanh toán/kết quả · đã nối API | [PaymentController:137](../../Cinema_BE/BookingService/BookingService/Controllers/PaymentController.cs#L137) |
| Nhận webhook PayOS | POST | `/api/v1/payments/payos/webhook` | PayOS gọi server; không phải thao tác UI | [PaymentController:162](../../Cinema_BE/BookingService/BookingService/Controllers/PaymentController.cs#L162) |
| Xử lý thanh toán | POST | `/api/v1/payments/{id}/process` | Staff → Payment details → Verify with PayOS · đã nối API | [PaymentController:176](../../Cinema_BE/BookingService/BookingService/Controllers/PaymentController.cs#L176) |
| Yêu cầu hoàn tiền | POST | `/api/v1/payments/{id}/refund` | API ngoại lệ thủ công chỉ dành cho Admin; Staff không có quyền tạo yêu cầu qua endpoint này. Customer gửi yêu cầu qua POST `/api/v1/bookings/{id}/cancel`: booking chuyển REFUND_PENDING, giữ vé trong Active và giữ ghế. Staff hoàn tất thì mới hủy/nhả ghế; từ chối thì booking về CONFIRMED | [PaymentController:188](../../Cinema_BE/BookingService/BookingService/Controllers/PaymentController.cs#L188) |
| Hoàn tiền của giao dịch | GET | `/api/v1/payments/{id}/refund` | Customer → chi tiết vé; Staff → Payment details → View refund request · đã nối API | [PaymentController:198](../../Cinema_BE/BookingService/BookingService/Controllers/PaymentController.cs#L198) |
| Danh sách yêu cầu hoàn tiền | GET | `/api/v1/payments/refunds` | Staff → Operations → Refunds/Dashboard · đã nối API | [PaymentController:212](../../Cinema_BE/BookingService/BookingService/Controllers/PaymentController.cs#L212) |
| Chi tiết hoàn tiền | GET | `/api/v1/payments/refunds/{refundId}` | Staff → Refund details · đã nối API | [PaymentController:222](../../Cinema_BE/BookingService/BookingService/Controllers/PaymentController.cs#L222) |
| Từ chối hoàn tiền | POST | `/api/v1/payments/refunds/{refundId}/reject` | Staff → Refund details → Reject refund; bắt buộc lý do, chỉ PENDING. Customer thấy lý do từ chối trong chi tiết vé, booking về CONFIRMED và vẫn giữ ghế; nhận thông báo/email | [PaymentController](../../Cinema_BE/BookingService/BookingService/Controllers/PaymentController.cs) |
| Xác nhận đã hoàn tiền | POST | `/api/v1/payments/refunds/{refundId}/complete` | Staff → Refund details → Record completed transfer · ghi nhận hoàn tiền, booking chờ refund chuyển CANCELLED và nhả ghế qua event | [PaymentController:236](../../Cinema_BE/BookingService/BookingService/Controllers/PaymentController.cs#L236) |

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
5. **Quản trị:** quản lý user, role, phim, phòng, ghế, suất chiếu, xử lý hoàn tiền và gửi thông báo nằm trong trang quản trị web (`lib/main_admin.dart`), không có trong app khách.
6. **Thông báo còn thiếu:** DELETE `/api/v1/notifications/{id}` có ở backend nhưng chưa có thao tác xóa trên mobile. Backend chưa có endpoint đánh dấu đã đọc/chưa đọc hoặc số thông báo chưa đọc. `status` hiện là trạng thái gửi email, không phải trạng thái đọc.
7. **Thông báo trống:** thông báo được tạo từ sự kiện xác nhận/hủy/hết hạn vé, yêu cầu/hoàn tiền/từ chối hoàn tiền. Đăng ký, xác thực email và đặt lại mật khẩu chưa tạo bản ghi trong lịch sử này. Không có dữ liệu mẫu tự chèn cho tài khoản mới; kéo xuống để lấy dữ liệu mới. Chưa có cập nhật thời gian thực/push notification.

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
- [Trang quản trị: route và phân quyền](../lib/admin/admin_router.dart)
- [Khung trang quản trị](../lib/features/admin/widgets/admin_page.dart)
- [Quản lý phim](../lib/features/admin/screens/admin_movies_screen.dart)
- [Quản lý phòng](../lib/features/admin/screens/admin_rooms_screen.dart)
