# Khu vực Staff

Staff local/demo: `nhanvien1@cinema.com` / `123456` (tài khoản seed). Đăng nhập với ROLE_STAFF vào `/staff/dashboard`; nếu có ROLE_ADMIN thì ưu tiên dashboard Admin.

## Điều hướng và quyền

Nav liquid glass **Dashboard / Operations / Profile** dùng component Cinema chung. Màn con giữ tab Operations, bấm Operations để về danh sách. Customer không được vào `/staff/*`; backend tiếp tục kiểm tra quyền từng endpoint. Staff không có quản lý người dùng, phân quyền, tạo/sửa/xóa phim hoặc phòng, xóa ghế.

## Nghiệp vụ đã nối API

| Nhóm | Thao tác |
|---|---|
| Dashboard | Tổng vé tạo hôm nay, vé PENDING, yêu cầu hoàn tiền PENDING, suất chiếu hôm nay; mở chi tiết vé |
| Bookings | Danh sách phân trang; lọc trạng thái hoặc ngày tạo; tra cứu bằng ID; đặt hộ bằng ID/email khách và chọn ghế thật; xem giao dịch liên quan; xác nhận tại quầy; hủy kèm lý do |
| Showtimes | Danh sách/lọc khoảng ngày; tạo/sửa với phim và phòng từ API; chọn ngày/giờ, giá; mở/đóng bán; hủy suất |
| Rooms | Danh sách/tìm tên; xem phòng và ghế; đổi NORMAL/VIP; sinh ghế NORMAL cho phòng trống |
| Payments | Danh sách/chi tiết; mở vé liên quan; xác minh giao dịch PayOS PENDING; tạo yêu cầu hoàn tiền cho SUCCESS |
| Refunds | Danh sách phân trang/lọc trạng thái; xem số tiền và thông tin ngân hàng nếu backend có; ghi nhận hoàn tiền với mã giao dịch chuyển khoản |
| Notifications | Soạn email từ chi tiết vé; tạo và gửi; nếu gửi lỗi thì giữ ID đã tạo và retry cùng thông báo khi còn trên màn |
| Profile | Hồ sơ Staff, đổi mật khẩu qua OTP chung và đăng xuất |

Bảng [MOBILE_UI_ENDPOINTS.md](MOBILE_UI_ENDPOINTS.md) là nguồn đối chiếu method + endpoint đã nối; các endpoint chưa có UI vẫn được giữ trong bảng.

## Quy trình và giới hạn backend

- Đặt hộ cần **ID và email của khách**. Staff không được gọi API danh sách tài khoản của Admin để tìm khách. Suất phải OPEN và chưa bắt đầu; backend quyết định giá ghế và kiểm tra xung đột, giữ ghế 10 phút.
- `POST /bookings/{id}/confirm` chỉ xác nhận vé bằng tay sau khi thu tiền tại quầy; **backend hiện không tạo/cập nhật bản ghi thanh toán tiền mặt**, dù query truyền `paymentMethod=CASH`. UI chỉ hiển thị thao tác này cho booking PENDING còn hạn và chưa gắn payment. Không coi endpoint này là hệ thống quản lý thu/hoàn tiền mặt.
- Booking đã có payment PayOS dùng **Verify with PayOS** tại Payment details. API `/payments/{id}/process` kiểm tra PayOS thật; nếu chưa nhận tiền thì không thông báo thành công. Email nhận vé được nhập/xác nhận là email khách, không mặc định email nhân viên.
- Hủy vé đã thanh toán/tạo refund request **không tự chuyển tiền**. Staff kiểm tra người nhận, thực hiện chuyển khoản bên ngoài, rồi nhập mã giao dịch và xác nhận hoàn tất. Dữ liệu ngân hàng có thể thiếu; phải lấy thông tin khách trước khi chuyển.
- Backend khóa việc sinh ghế/đổi loại ghế khi phòng có suất chiếu. UI chỉ cho sinh sơ đồ ở phòng trống, tránh thêm trùng ghế. Không có chức năng xóa ghế/phòng cho Staff.
- Hủy suất chiếu chuyển trạng thái sang CANCELLED; endpoint hiện không điều phối hủy/hoàn tiền các vé đã tồn tại. Staff phải rà các booking liên quan riêng.
- Chưa có API check-in/đánh dấu vé đã sử dụng hoặc xác thực QR tại cửa rạp, nên UI hiện chỉ tra cứu vé. Endpoint tạo payment chung, thông báo của bản thân và các bộ lọc API khác chưa có màn Staff riêng vẫn được ghi đúng trạng thái trong bảng endpoint.
- Retry thông báo giữ ID trong phiên màn hình; nếu rời màn sau khi lưu nhưng gửi lỗi, không tự tạo/gửi lại thông báo cũ. Không có quyền xem thông báo của toàn bộ khách vì API đó chỉ dành Admin.

## Kiểm tra hiện tại

Đã phân tích tĩnh và build web. Chưa xác nhận thao tác thực tế trên điện thoại, thu tiền mặt, chuyển khoản hoàn tiền hoặc gửi SMTP/PayOS từ tài khoản Staff.
