# Khu vực Staff

Staff local/demo: `nhanvien1@cinema.com` / `123456` (tài khoản seed). Staff làm việc trên **trang quản trị web** (`flutter run -d chrome -t lib/main_admin.dart`, build vào `/admin/`). Đăng nhập với ROLE_STAFF vào `/staff/dashboard`; nếu có ROLE_ADMIN thì ưu tiên dashboard Admin. Trong app khách, tài khoản Staff thấy hướng dẫn mở trang quản trị và nút **Check in tickets** để quét QR trên vé bằng camera điện thoại tại cửa rạp.

## Điều hướng và quyền

Thanh điều hướng bên trái **Dashboard / Operations / Check-in / Profile**; cửa sổ hẹp hơn 640 px thì mở bằng nút menu. Màn con giữ mục Operations và có nút Back; bấm Operations để về danh sách. Customer không được vào `/staff/*`; backend tiếp tục kiểm tra quyền từng endpoint. Staff không có quản lý người dùng, phân quyền, tạo/sửa/xóa phim hoặc phòng (Admin làm ở Movies, Rooms), xóa ghế.

## Nghiệp vụ đã nối API

| Nhóm | Thao tác |
|---|---|
| Dashboard | **Today**: vé tạo hôm nay, suất hôm nay có vé (x / tổng), vé của các suất hôm nay, đã check-in; bảng suất đang chiếu (đang xem = đã check-in, vé đã bán / sức chứa, thời gian còn lại), 3 suất tiếp theo (đã đặt, chờ thanh toán) và 3 suất vừa xong (vé đã bán, số khách đã vào), bấm suất mở sơ đồ ghế + danh sách khách; tự làm mới mỗi phút. **Needs attention**: vé PENDING, yêu cầu hoàn tiền PENDING; mở chi tiết vé. Góc trên có lối tắt **Sell tickets** và **Check in** |
| Bookings | Danh sách phân trang (ghi CHECKED IN cho vé đã dùng); lọc trạng thái hoặc ngày tạo; tra cứu bằng ID; **Sell tickets**: khách vãng lai (không cần tài khoản; email / số điện thoại tuỳ chọn) hoặc thành viên (ID + email), chọn phim → suất trong 7 ngày tới → ghế trên sơ đồ; **Take payment**: tiền mặt (tính tiền thối) hoặc chuyển khoản quét VietQR của PayOS; vé đã trả hiện QR, **Print ticket**, **Check in now**; xem giao dịch liên quan; check-in tại quầy; hủy kèm lý do |
| Check-in | Quét QR trên vé hoặc trong email xác nhận (camera điện thoại / webcam laptop / camera USB; trên web cần `localhost` hoặc HTTPS) hoặc nhập mã vé (máy quét cầm tay gõ mã rồi Enter); xem phim, giờ, phòng, ghế, tổng tiền; check-in vé đã thanh toán. Vé đã dùng, chưa trả tiền, đã huỷ hoặc chưa tới giờ bị từ chối kèm lý do |
| Showtimes | Danh sách/lọc khoảng ngày; tạo/sửa với phim và phòng từ API; chọn ngày/giờ, giá ghế thường (VIP +20%, sweetbox +30% do backend tính); mở/đóng bán; hủy suất; sơ đồ ghế của suất (trống / chờ thanh toán / đã bán / đã check-in), bấm ghế đã có người để mở vé, danh sách khách (email, ghế, mã vé, giờ check-in), tự làm mới mỗi 5 giây |
| Rooms | Danh sách/tìm tên; xem phòng và ghế; đổi loại từng ghế, hoặc tô hàng loạt (chọn Standard / VIP / Sweetbox rồi bấm, kéo qua ghế hay bấm chữ đầu hàng); sinh ghế NORMAL cho phòng trống |
| Payments | Danh sách/chi tiết; mở vé liên quan; xác minh giao dịch PayOS PENDING; tạo yêu cầu hoàn tiền cho SUCCESS |
| Refunds | Danh sách phân trang/lọc trạng thái; xem số tiền và thông tin ngân hàng nếu backend có; ghi nhận hoàn tiền với mã giao dịch chuyển khoản |
| Notifications | Soạn email từ chi tiết vé; tạo và gửi; nếu gửi lỗi thì giữ ID đã tạo và retry cùng thông báo khi còn trên màn |
| Profile | Hồ sơ Staff, đổi mật khẩu qua OTP chung và đăng xuất |

Bảng [MOBILE_UI_ENDPOINTS.md](MOBILE_UI_ENDPOINTS.md) là nguồn đối chiếu method + endpoint đã nối; các endpoint chưa có UI vẫn được giữ trong bảng.

## Quy trình và giới hạn backend

- Bán vé tại quầy: **khách vãng lai** không cần tài khoản (vé có `user_id` NULL), email và số điện thoại tuỳ chọn; **thành viên** cần ID và email của khách (Staff không được gọi API danh sách tài khoản của Admin để tìm khách). Suất phải OPEN và chưa bắt đầu; backend quyết định giá ghế và kiểm tra xung đột, giữ ghế 10 phút.
- Thu tiền (**Take payment**):
  - **Tiền mặt**: `POST /payments/cash` với số tiền khách đưa (phải đủ tổng tiền). Server ghi payment CASH `SUCCESS` (mã giao dịch `CASH-<mã vé>`), vé CONFIRMED, gửi email vé kèm QR nếu có email.
  - **Chuyển khoản**: tạo link PayOS và hiện VietQR, khách quét bằng app ngân hàng; màn hình tự hỏi PayOS mỗi 3 giây, tiền về thì vé được xác nhận (webhook cũng xác nhận được).
  - Đổi từ chuyển khoản sang tiền mặt: link PayOS bị huỷ trước khi ghi tiền mặt; khách đã chuyển khoản rồi thì bị từ chối (409) để không thu hai lần.
  - Cả hai cách đều có bản ghi thanh toán nên doanh thu Admin và hoàn tiền tính đúng. Khách không có email: **Print ticket** (trang web, khổ giấy in hoá đơn 80 mm) hoặc để khách chụp QR trên màn hình.
  - `POST /bookings/{id}/confirm` vẫn còn ở backend nhưng UI không dùng nữa vì nó không ghi thanh toán.
- Booking đã có payment PayOS dùng **Verify with PayOS** tại Payment details. API `/payments/{id}/process` kiểm tra PayOS thật; nếu chưa nhận tiền thì không thông báo thành công. Email nhận vé được nhập/xác nhận là email khách, không mặc định email nhân viên.
- Hủy vé đã thanh toán/tạo refund request **không tự chuyển tiền**. Staff kiểm tra người nhận, thực hiện chuyển khoản bên ngoài, rồi nhập mã giao dịch và xác nhận hoàn tất. Dữ liệu ngân hàng có thể thiếu; phải lấy thông tin khách trước khi chuyển.
- Backend khóa việc sinh ghế/đổi loại ghế khi phòng có suất chiếu. UI chỉ cho sinh sơ đồ ở phòng trống, tránh thêm trùng ghế. Không có chức năng xóa ghế/phòng cho Staff.
- Hủy suất chiếu chuyển trạng thái sang CANCELLED; endpoint hiện không điều phối hủy/hoàn tiền các vé đã tồn tại. Staff phải rà các booking liên quan riêng.
- Check-in: QR trên vé chứa mã vé (`bookingCode`). Chỉ vé CONFIRMED check-in được, mỗi vé một lần (hai quầy quét cùng lúc thì quầy sau nhận 409), từ 3 giờ trước đến 2 giờ sau giờ chiếu (`CheckIn` trong appsettings của BookingService). Vé chờ hoàn tiền không dùng được. Endpoint tạo payment chung, thông báo của bản thân và các bộ lọc API khác chưa có màn Staff riêng vẫn được ghi đúng trạng thái trong bảng endpoint.
- Retry thông báo giữ ID trong phiên màn hình; nếu rời màn sau khi lưu nhưng gửi lỗi, không tự tạo/gửi lại thông báo cũ. Không có quyền xem thông báo của toàn bộ khách vì API đó chỉ dành Admin.

## Kiểm tra hiện tại

Đã phân tích tĩnh và build web. Đã thử trên trang quản trị (Docker): bán vé khách vãng lai, hiện VietQR PayOS thật, đổi sang tiền mặt (link PayOS bị huỷ), in vé, check-in ngay. Chưa xác nhận thao tác thực tế trên điện thoại, chuyển khoản hoàn tiền hoặc khách trả tiền thật qua VietQR.
