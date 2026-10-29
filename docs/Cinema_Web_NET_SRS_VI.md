# ĐẶC TẢ YÊU CẦU PHẦN MỀM

# Cinema — Web .NET

| Mục | Nội dung |
| --- | --- |
| Phiên bản | 3.0 |
| Ngày chốt | 2026-10-28 (Asia/Saigon) |
| Ngôn ngữ | Tiếng Việt |
| Trạng thái bằng chứng | Chốt theo code/tài liệu qua kiểm tra tĩnh; chưa kiểm chứng chạy |
| Tài liệu đối ứng | [Cinema_Web_NET_SRS_EN.md](Cinema_Web_NET_SRS_EN.md) |

## 1. Giới thiệu

CosmoQ Cinema là một hệ thống đặt vé và quản lý rạp có nhiều client. SRS theo môn này chi tiết hoá SRS tổng hợp 2.0 từ checkout hiện tại; không xác lập sản phẩm độc lập thứ hai. Route/controller/service/model thực thi ưu tiên hơn mô tả cũ. SRS 1.0 là ý định lịch sử.

H = bắt buộc; M = quan trọng; L = tuỳ chọn. Đã triển khai nghĩa là có mã nguồn, không có nghĩa test tích hợp đã đạt. Mỗi cặp EN/VI dùng cùng mã, phạm vi, ưu tiên và tiêu chí; không bản nào là tóm tắt.

## 2. Mục đích

Cung cấp hợp đồng cho phát triển, thiết kế ca kiểm thử, nghiệm thu và bảo vệ môn học. Mỗi FR xác định tác nhân, điều kiện, kích hoạt, luồng, ngoại lệ, kết quả và tiêu chí nghiệm thu, truy tới ca sử dụng, màn hình, API và bằng chứng code/test.

## 3. Phạm vi

Bao gồm màn khách trình duyệt, không gian nhân viên/quản trị viên trình duyệt và backend ASP.NET Core 8 dùng chung cho xác thực, danh mục, lịch, vé, thanh toán/hoàn tiền và thông báo. Web khách được tính vì main.dart được build cho trình duyệt lẫn native.

Ranh giới công nghệ: không có MVC .cshtml, Razor/Blazor .razor hoặc dự án UI .NET riêng. “Web .NET” là phạm vi môn: REST ASP.NET Core cùng client Flutter Web hiện có. Yêu cầu bắt buộc UI do .NET dựng là [CẦN XÁC NHẬN], không phải bằng chứng đã triển khai.

## 4. Mô tả tổng thể

```text
Flutter main.dart (customer web) + main_admin.dart (admin web)
                | REST/JSON + JWT
        ApiGateway / YARP :5000
          |           |             |
     AuthService  MovieService  BookingService
       :5100        :5168          :5063
          |           |             |
       PostgreSQL (6 databases) + RabbitMQ/outbox
                                | PayOS + SMTP
```

Ba service nghiệp vụ thay thiết kế sáu service ban đầu: AuthService sở hữu danh tính; MovieService sở hữu phim/phòng/ghế/suất; BookingService sở hữu vé, bắp nước, khuyến mãi, điểm, đánh giá, thanh toán/hoàn tiền và thông báo. Tham chiếu xuyên database là ID logic, không phải khoá ngoại.

## 5. Bối cảnh sản phẩm

| Phần | Trách nhiệm |
| --- | --- |
| Lõi chung | Danh tính/vai trò/sở hữu; giá; đồng thời ghế; trạng thái tài chính; xác minh PayOS; hoàn tiền; sự kiện và toàn vẹn dữ liệu |
| Không gian web | Quầy/tiền mặt/in; quản trị phim/phòng/suất/tài khoản/menu/khuyến mãi/thành viên; xử lý hoàn; vận hành/doanh thu |
| Hành vi native | Trailer ngoài, bảng chia sẻ thiết bị, check-in camera điện thoại, địa chỉ gateway emulator/LAN và xác minh khi trở lại |
| Trình bày chung | Khách web/native dùng chung widget và repository Dart; preview/in theo điều kiện nền tảng |

## 6. Nhóm người dùng / Tác nhân

| Tác nhân | Trách nhiệm |
| --- | --- |
| Khách chưa đăng nhập | Danh mục/suất công khai; bắt đầu luồng tài khoản |
| Khách hàng | Hồ sơ, vé, thanh toán, trạng thái hoàn, thông báo, đánh giá và điểm của mình |
| Nhân viên/quản trị viên | Nhân viên bán/lịch/cho vào/hoàn; quản trị viên còn quản lý dữ liệu nền/người dùng/doanh thu |
| Khách vãng lai | Người mua quầy qua nhân viên, không phải tác nhân điện thoại đã đăng nhập |
| PayOS / SMTP / tác vụ nền | Đối soát/thông điệp ngoài; hết hạn giữ ghế và trao đổi sự kiện đã commit |

## 7. Vai trò và phân quyền

| Thao tác | Chưa đăng nhập | Customer | Staff | Admin |
| --- | --- | --- | --- | --- |
| Xem phim/suất công khai | ✓ | ✓ | ✓ | ✓ |
| Vé/thanh toán/hồ sơ/đánh giá của mình | — | ✓ | Trang đầu theo vai trò | Trang đầu theo vai trò |
| Tra/check-in vé | — | — | ✓ | ✓ |
| Quầy/tiền mặt, lịch, loại ghế, xử lý hoàn | — | — | ✓ | ✓ |
| Phim, phòng, tài khoản, menu, khuyến mãi, thành viên, doanh thu | — | — | — | ✓ |

Bảo vệ UI kiểm soát điều hướng; policy controller và kiểm tra chủ bản ghi quyết định quyền. Tài khoản có thể có nhiều vai trò. Khách vào cổng quản trị thấy hướng dẫn về trang khách; quản lý vào cổng khách thấy hướng dẫn quản lý/check-in.

## 8. Quy tắc nghiệp vụ

| ID | Quy tắc |
| --- | --- |
| WEB-BR-01 | Tài khoản khách phải xác thực email bằng OTP trước khi đăng nhập. Tài khoản do Admin tạo không cần OTP. |
| WEB-BR-02 | Mọi API cần đăng nhập dùng JWT; gateway và service đều kiểm tra. |
| WEB-BR-03 | Quyền truy cập theo vai trò; Customer không dùng được API quản trị. |
| WEB-BR-04 | Mỗi ghế thuộc một phòng, không trùng vị trí (hàng + số) trong phòng. |
| WEB-BR-05 | Một suất chiếu thuộc một phim và một phòng, giờ bắt đầu phải trước giờ kết thúc. |
| WEB-BR-06 | Một phòng không có hai suất chiếu trùng thời gian (409). |
| WEB-BR-07 | Một ghế của một suất chiếu chỉ thuộc một booking còn hiệu lực (đang giữ hoặc đã bán). |
| WEB-BR-08 | Booking gắn với một suất chiếu và các ghế; gắn với tài khoản khách, trừ vé khách vãng lai bán tại quầy. |
| WEB-BR-09 | Một thanh toán thuộc một vé; chuyển trạng thái vé/thanh toán/hoàn tiền phải theo hợp đồng trạng thái ở mục 15. |
| WEB-BR-10 | Webhook PayOS phải đúng chữ ký HMAC-SHA256 trước khi dùng dữ liệu. |
| WEB-BR-11 | Event được ghi vào outbox trong cùng transaction với dữ liệu và chỉ gửi sau khi commit. |
| WEB-BR-12 | Lời gọi tới service khác hoặc PayOS có retry giới hạn và circuit breaker. |
| WEB-BR-13 | Lỗi gửi email hoặc RabbitMQ tạm dừng không làm hỏng giao dịch đặt vé / thanh toán. |
| WEB-BR-14 | Ghế được giữ 10 phút; quá hạn chưa thanh toán thì booking `EXPIRED` và ghế được nhả. |
| WEB-BR-15 | Giá ghế: giá suất chiếu là giá ghế thường; VIP +20%, sweetbox +30% mỗi ghế; phụ thu làm tròn tới 1.000đ. Server tự tính giá, không nhận giá từ client. |
| WEB-BR-16 | Sweetbox luôn được đặt, đổi loại và bán theo cặp. |
| WEB-BR-17 | Khách tự huỷ vé đã thanh toán khi còn ít nhất 2 giờ trước giờ chiếu và được hoàn 100%; muộn hơn phải liên hệ rạp. Staff/Admin huỷ được mọi lúc. |
| WEB-BR-18 | Mỗi payment có tối đa một yêu cầu hoàn tiền. Hoàn tiền được thực hiện bằng chuyển khoản thủ công và ghi nhận mã giao dịch. |
| WEB-BR-19 | Suất chiếu bị huỷ thì mọi vé còn hiệu lực của suất đó bị huỷ; vé đã thanh toán được tạo yêu cầu hoàn tiền. |
| WEB-BR-20 | Trả tiền muộn (booking đã hết hạn): ghế còn trống thì vẫn xác nhận vé; ghế đã bán cho người khác thì tự tạo yêu cầu hoàn 100%. |
| WEB-BR-21 | Check-in chỉ cho vé `CONFIRMED`, mỗi vé một lần, từ 3 giờ trước đến 2 giờ sau giờ chiếu. |
| WEB-BR-22 | Thu tiền mặt phải đủ tổng tiền vé. Vé đang có QR chuyển khoản chưa trả thì huỷ link PayOS trước khi ghi tiền mặt; khách đã chuyển khoản thì không thu tiền mặt. |
| WEB-BR-23 | Tiền mặt và chuyển khoản đều tạo bản ghi thanh toán, nên được tính vào doanh thu và hoàn tiền như nhau. |
| WEB-BR-24 | Khoá tài khoản hoặc đổi vai trò có hiệu lực ngay ở request tiếp theo, kể cả khi token cũ còn hạn. |
| WEB-BR-25 | Quên mật khẩu trả 200 dù email tồn tại hay không; email/mật khẩu đăng nhập sai có chung thông báo. Đăng ký/gửi lại có thể lộ trạng thái tài khoản nên không khẳng định chống dò trên toàn hệ thống. |
| WEB-BR-26 | Phim ngừng chiếu chỉ chuyển `INACTIVE`, không xoá; vé đã đặt giữ nguyên. Phòng có suất chiếu không xoá và không sửa sơ đồ ghế được. |
| WEB-BR-27 | Khuyến mãi chỉ giảm tiền vé, tối đa 90%, làm tròn xuống 1.000đ; dùng một ưu đãi tự động tốt nhất hoặc mã nhập đủ điều kiện. Đếm lượt khi thanh toán thành công. |
| WEB-BR-28 | Một điểm bằng 1.000đ; dùng tối đa 50% sau khuyến mãi; ngưỡng chi tiêu MEMBER/VIP/VVIP là 0/2.000.000/5.000.000đ và tỷ lệ tích 5/7/10%. Thu hồi/hoàn tác động điểm theo huỷ/hết hạn/hoàn vé. |
| WEB-BR-29 | Mỗi vé tối đa mười món bắp nước đang bán khác nhau, mỗi món 1–20; lưu tên và đơn giá lúc mua, tính vào tổng thanh toán và hoàn tiền. |
| WEB-BR-30 | Giá định dạng cộng 0/20.000/40.000đ cho 2D/3D/IMAX trước phụ thu loại ghế; giá NORMAL/VIP/SWEETBOX do server trả. |

Quy tắc người vận hành ngoài quy định tác động backend chung, không bổ sung màn điện thoại. Giới hạn giờ là mặc định hiện tại và có thể đổi cấu hình triển khai.

## 9. Yêu cầu chức năng

AC-01 kiểm tra đúng hành vi đã nêu; AC-02 kiểm tra nhánh từ chối/quyền áp dụng. Chỉ thực hiện thao tác FR riêng quy định; ca sử dụng rộng cung cấp ngữ cảnh. Tiêu chí là đặc tả, không phải kết quả chạy test.

### WEB-FR-AUTH-01 — Đăng ký

| Trường | Đặc tả |
| --- | --- |
| Tên | Đăng ký |
| Mô tả | Khách đăng ký bằng email, mật khẩu, họ tên, số điện thoại (không bắt buộc). Hệ thống gửi OTP xác thực, chưa cấp token. |
| Tác nhân | Khách chưa đăng nhập; người có tài khoản; hệ thống |
| Tiền điều kiện | Truy cập được biểu mẫu và đã cấu hình gateway/AuthService; đăng ký/đăng nhập/OTP/khôi phục không cần phiên đã đăng nhập. Gửi mã cần SMTP. |
| Kích hoạt | Thực hiện “Đăng ký” hoặc sự kiện/tác vụ backend tương ứng. |
| Luồng chính | 1. Đọc đầu vào/tài nguyên hiện tại và phiên áp dụng. 2. Thực hiện thao tác này: Khách đăng ký bằng email, mật khẩu, họ tên, số điện thoại (không bắt buộc). Hệ thống gửi OTP xác thực, chưa cấp token. 3. Trả/hiển thị kết quả chính thức và làm mới dữ liệu bị tác động sau thành công. |
| Luồng thay thế / ngoại lệ | Từ chối trường sai (400), thông tin đăng nhập sai (401), email chưa xác thực (403), OTP cũ/sai hoặc vượt giới hạn gửi/tần suất (429). Xoá phiên khi tài khoản bị khoá/quyền thay đổi; hiển thị lỗi SMTP/phụ thuộc (503). |
| Hậu điều kiện | Ghi nhận đăng ký chưa xác thực và kết quả gửi OTP; chưa cấp access/refresh token trước xác thực. |
| Ưu tiên | H |
| Tiêu chí nghiệm thu | **WEB-FR-AUTH-01-AC-01** — Với tiền điều kiện/kích hoạt, kiểm tra: Khách đăng ký bằng email, mật khẩu, họ tên, số điện thoại (không bắt buộc). Hệ thống gửi OTP xác thực, chưa cấp token. **WEB-FR-AUTH-01-AC-02** — Thử đầu vào sai/thiếu quyền/xung đột áp dụng và kiểm tra từ chối đã nêu, không đổi dữ liệu trái phép và không báo thành công sai. |
| Bằng chứng | [Cinema_BE/AuthService/AuthService/Controllers/AuthController.cs](../Cinema_BE/AuthService/AuthService/Controllers/AuthController.cs); [Cinema_Mobile/lib/features/auth/screens/register_screen.dart](../Cinema_Mobile/lib/features/auth/screens/register_screen.dart); [Cinema_BE/AuthService/AuthService/Service/AuthService.cs](../Cinema_BE/AuthService/AuthService/Service/AuthService.cs); [Cinema_BE/ApiGateway/ApiGateway/Program.cs](../Cinema_BE/ApiGateway/ApiGateway/Program.cs) |
| Quy tắc nghiệp vụ | WEB-BR-01, WEB-BR-02, WEB-BR-03, WEB-BR-24, WEB-BR-25 |
| Ca sử dụng / màn / API | UC-WEB-01; WEB-SCR-REGISTER; WEB-API-033 |

### WEB-FR-AUTH-02 — Đăng nhập

| Trường | Đặc tả |
| --- | --- |
| Tên | Đăng nhập |
| Mô tả | Đăng nhập bằng email + mật khẩu, nhận access token (JWT, 60 phút) và refresh token (7 ngày). Chưa xác thực email thì trả 403 `EMAIL_NOT_VERIFIED`. |
| Tác nhân | Khách chưa đăng nhập; người có tài khoản; hệ thống |
| Tiền điều kiện | Truy cập được biểu mẫu và đã cấu hình gateway/AuthService; đăng ký/đăng nhập/OTP/khôi phục không cần phiên đã đăng nhập. Gửi mã cần SMTP. |
| Kích hoạt | Thực hiện “Đăng nhập” hoặc sự kiện/tác vụ backend tương ứng. |
| Luồng chính | 1. Đọc đầu vào/tài nguyên hiện tại và phiên áp dụng. 2. Thực hiện thao tác này: Đăng nhập bằng email + mật khẩu, nhận access token (JWT, 60 phút) và refresh token (7 ngày). Chưa xác thực email thì trả 403 `EMAIL_NOT_VERIFIED`. 3. Trả/hiển thị kết quả chính thức và làm mới dữ liệu bị tác động sau thành công. |
| Luồng thay thế / ngoại lệ | Từ chối trường sai (400), thông tin đăng nhập sai (401), email chưa xác thực (403), OTP cũ/sai hoặc vượt giới hạn gửi/tần suất (429). Xoá phiên khi tài khoản bị khoá/quyền thay đổi; hiển thị lỗi SMTP/phụ thuộc (503). |
| Hậu điều kiện | Xác thực thành công lưu người/token trả về và chọn trang theo vai trò đủ quyền; lỗi không cấp phiên. |
| Ưu tiên | H |
| Tiêu chí nghiệm thu | **WEB-FR-AUTH-02-AC-01** — Với tiền điều kiện/kích hoạt, kiểm tra: Đăng nhập bằng email + mật khẩu, nhận access token (JWT, 60 phút) và refresh token (7 ngày). Chưa xác thực email thì trả 403 `EMAIL_NOT_VERIFIED`. **WEB-FR-AUTH-02-AC-02** — Thử đầu vào sai/thiếu quyền/xung đột áp dụng và kiểm tra từ chối đã nêu, không đổi dữ liệu trái phép và không báo thành công sai. |
| Bằng chứng | [Cinema_BE/AuthService/AuthService/Controllers/AuthController.cs](../Cinema_BE/AuthService/AuthService/Controllers/AuthController.cs); [Cinema_Mobile/lib/features/auth/screens/login_screen.dart](../Cinema_Mobile/lib/features/auth/screens/login_screen.dart); [Cinema_BE/AuthService/AuthService/Service/AuthService.cs](../Cinema_BE/AuthService/AuthService/Service/AuthService.cs); [Cinema_BE/ApiGateway/ApiGateway/Program.cs](../Cinema_BE/ApiGateway/ApiGateway/Program.cs) |
| Quy tắc nghiệp vụ | WEB-BR-01, WEB-BR-02, WEB-BR-03, WEB-BR-24, WEB-BR-25 |
| Ca sử dụng / màn / API | UC-WEB-01; WEB-SCR-LOGIN; WEB-API-027 |

### WEB-FR-AUTH-03 — Thông tin JWT

| Trường | Đặc tả |
| --- | --- |
| Tên | Thông tin JWT |
| Mô tả | JWT chứa userId, email và danh sách vai trò. |
| Tác nhân | Khách chưa đăng nhập; người có tài khoản; hệ thống |
| Tiền điều kiện | Gateway đã được cấu hình. Đăng ký/khôi phục cần SMTP; thao tác được bảo vệ cần phiên tài khoản hợp lệ. |
| Kích hoạt | Thực hiện “Thông tin JWT” hoặc sự kiện/tác vụ backend tương ứng. |
| Luồng chính | 1. Đọc đầu vào/tài nguyên hiện tại và phiên áp dụng. 2. Thực hiện thao tác này: JWT chứa userId, email và danh sách vai trò. 3. Trả/hiển thị kết quả chính thức và làm mới dữ liệu bị tác động sau thành công. |
| Luồng thay thế / ngoại lệ | Từ chối trường sai (400), thông tin đăng nhập sai (401), email chưa xác thực (403), OTP cũ/sai hoặc vượt giới hạn gửi/tần suất (429). Xoá phiên khi tài khoản bị khoá/quyền thay đổi; hiển thị lỗi SMTP/phụ thuộc (503). |
| Hậu điều kiện | Kết quả thành công quan sát được khớp yêu cầu này; chuyển trạng thái được chỉ định được lưu. Từ chối không cấp quyền hoặc để thay đổi dở dang trái phép. |
| Ưu tiên | H |
| Tiêu chí nghiệm thu | **WEB-FR-AUTH-03-AC-01** — Với tiền điều kiện/kích hoạt, kiểm tra: JWT chứa userId, email và danh sách vai trò. **WEB-FR-AUTH-03-AC-02** — Thử đầu vào sai/thiếu quyền/xung đột áp dụng và kiểm tra từ chối đã nêu, không đổi dữ liệu trái phép và không báo thành công sai. |
| Bằng chứng | [Cinema_BE/AuthService/AuthService/Controllers/AuthController.cs](../Cinema_BE/AuthService/AuthService/Controllers/AuthController.cs); [Cinema_Mobile/lib/features/auth/screens/login_screen.dart](../Cinema_Mobile/lib/features/auth/screens/login_screen.dart); [Cinema_BE/AuthService/AuthService/Service/AuthService.cs](../Cinema_BE/AuthService/AuthService/Service/AuthService.cs); [Cinema_BE/ApiGateway/ApiGateway/Program.cs](../Cinema_BE/ApiGateway/ApiGateway/Program.cs) |
| Quy tắc nghiệp vụ | WEB-BR-01, WEB-BR-02, WEB-BR-03, WEB-BR-24, WEB-BR-25 |
| Ca sử dụng / màn / API | UC-WEB-01; WEB-SCR-LOGIN; WEB-API-027, WEB-API-032 |

### WEB-FR-AUTH-04 — Kiểm tra JWT

| Trường | Đặc tả |
| --- | --- |
| Tên | Kiểm tra JWT |
| Mô tả | Gateway và service kiểm tra chữ ký, hạn, issuer, audience của JWT trước API cần đăng nhập. |
| Tác nhân | Khách chưa đăng nhập; người có tài khoản; hệ thống |
| Tiền điều kiện | Gateway đã được cấu hình. Đăng ký/khôi phục cần SMTP; thao tác được bảo vệ cần phiên tài khoản hợp lệ. |
| Kích hoạt | Thực hiện “Kiểm tra JWT” hoặc sự kiện/tác vụ backend tương ứng. |
| Luồng chính | 1. Đọc đầu vào/tài nguyên hiện tại và phiên áp dụng. 2. Thực hiện thao tác này: Gateway và service kiểm tra chữ ký, hạn, issuer, audience của JWT trước API cần đăng nhập. 3. Trả/hiển thị kết quả chính thức và làm mới dữ liệu bị tác động sau thành công. |
| Luồng thay thế / ngoại lệ | Từ chối trường sai (400), thông tin đăng nhập sai (401), email chưa xác thực (403), OTP cũ/sai hoặc vượt giới hạn gửi/tần suất (429). Xoá phiên khi tài khoản bị khoá/quyền thay đổi; hiển thị lỗi SMTP/phụ thuộc (503). |
| Hậu điều kiện | Dữ liệu/trạng thái đủ quyền được trả/hiển thị; đọc không đổi trạng thái vé/thanh toán. Dấu đã đọc thông báo chỉ đổi bằng thao tác ghi riêng. |
| Ưu tiên | H |
| Tiêu chí nghiệm thu | **WEB-FR-AUTH-04-AC-01** — Với tiền điều kiện/kích hoạt, kiểm tra: Gateway và service kiểm tra chữ ký, hạn, issuer, audience của JWT trước API cần đăng nhập. **WEB-FR-AUTH-04-AC-02** — Thử đầu vào sai/thiếu quyền/xung đột áp dụng và kiểm tra từ chối đã nêu, không đổi dữ liệu trái phép và không báo thành công sai. |
| Bằng chứng | [Cinema_BE/AuthService/AuthService/Controllers/AuthController.cs](../Cinema_BE/AuthService/AuthService/Controllers/AuthController.cs); [Cinema_BE/AuthService/AuthService/Service/AuthService.cs](../Cinema_BE/AuthService/AuthService/Service/AuthService.cs); [Cinema_BE/ApiGateway/ApiGateway/Program.cs](../Cinema_BE/ApiGateway/ApiGateway/Program.cs) |
| Quy tắc nghiệp vụ | WEB-BR-01, WEB-BR-02, WEB-BR-03, WEB-BR-24, WEB-BR-25 |
| Ca sử dụng / màn / API | UC-WEB-01; ; WEB-API-029 |

### WEB-FR-AUTH-05 — Phân quyền vai trò

| Trường | Đặc tả |
| --- | --- |
| Tên | Phân quyền vai trò |
| Mô tả | Phân quyền API theo vai trò Customer / Staff / Admin (policy `StaffOrAdmin`, `AdminOnly`, mặc định là đã đăng nhập). |
| Tác nhân | Khách chưa đăng nhập; người có tài khoản; hệ thống |
| Tiền điều kiện | Gateway đã được cấu hình. Đăng ký/khôi phục cần SMTP; thao tác được bảo vệ cần phiên tài khoản hợp lệ. |
| Kích hoạt | Thực hiện “Phân quyền vai trò” hoặc sự kiện/tác vụ backend tương ứng. |
| Luồng chính | 1. Đọc đầu vào/tài nguyên hiện tại và phiên áp dụng. 2. Thực hiện thao tác này: Phân quyền API theo vai trò Customer / Staff / Admin (policy `StaffOrAdmin`, `AdminOnly`, mặc định là đã đăng nhập). 3. Trả/hiển thị kết quả chính thức và làm mới dữ liệu bị tác động sau thành công. |
| Luồng thay thế / ngoại lệ | Từ chối trường sai (400), thông tin đăng nhập sai (401), email chưa xác thực (403), OTP cũ/sai hoặc vượt giới hạn gửi/tần suất (429). Xoá phiên khi tài khoản bị khoá/quyền thay đổi; hiển thị lỗi SMTP/phụ thuộc (503). |
| Hậu điều kiện | Dữ liệu/trạng thái đủ quyền được trả/hiển thị; đọc không đổi trạng thái vé/thanh toán. Dấu đã đọc thông báo chỉ đổi bằng thao tác ghi riêng. |
| Ưu tiên | H |
| Tiêu chí nghiệm thu | **WEB-FR-AUTH-05-AC-01** — Với tiền điều kiện/kích hoạt, kiểm tra: Phân quyền API theo vai trò Customer / Staff / Admin (policy `StaffOrAdmin`, `AdminOnly`, mặc định là đã đăng nhập). **WEB-FR-AUTH-05-AC-02** — Thử đầu vào sai/thiếu quyền/xung đột áp dụng và kiểm tra từ chối đã nêu, không đổi dữ liệu trái phép và không báo thành công sai. |
| Bằng chứng | [Cinema_BE/AuthService/AuthService/Controllers/AuthController.cs](../Cinema_BE/AuthService/AuthService/Controllers/AuthController.cs); [Cinema_Mobile/lib/features/admin/screens/staff_only_screen.dart](../Cinema_Mobile/lib/features/admin/screens/staff_only_screen.dart); [Cinema_BE/AuthService/AuthService/Service/AuthService.cs](../Cinema_BE/AuthService/AuthService/Service/AuthService.cs); [Cinema_BE/ApiGateway/ApiGateway/Program.cs](../Cinema_BE/ApiGateway/ApiGateway/Program.cs) |
| Quy tắc nghiệp vụ | WEB-BR-01, WEB-BR-02, WEB-BR-03, WEB-BR-24, WEB-BR-25 |
| Ca sử dụng / màn / API | UC-WEB-01; WEB-SCR-STAFF-ONLY; WEB-API-029 |

### WEB-FR-AUTH-06 — Phản hồi chưa xác thực và thiếu quyền

| Trường | Đặc tả |
| --- | --- |
| Tên | Phản hồi chưa xác thực và thiếu quyền |
| Mô tả | Chưa đăng nhập hoặc token sai trả 401; đủ đăng nhập nhưng thiếu quyền trả 403. |
| Tác nhân | Khách chưa đăng nhập; người có tài khoản; hệ thống |
| Tiền điều kiện | Gateway đã được cấu hình. Đăng ký/khôi phục cần SMTP; thao tác được bảo vệ cần phiên tài khoản hợp lệ. |
| Kích hoạt | Thực hiện “Phản hồi chưa xác thực và thiếu quyền” hoặc sự kiện/tác vụ backend tương ứng. |
| Luồng chính | 1. Đọc đầu vào/tài nguyên hiện tại và phiên áp dụng. 2. Thực hiện thao tác này: Chưa đăng nhập hoặc token sai trả 401; đủ đăng nhập nhưng thiếu quyền trả 403. 3. Trả/hiển thị kết quả chính thức và làm mới dữ liệu bị tác động sau thành công. |
| Luồng thay thế / ngoại lệ | Từ chối trường sai (400), thông tin đăng nhập sai (401), email chưa xác thực (403), OTP cũ/sai hoặc vượt giới hạn gửi/tần suất (429). Xoá phiên khi tài khoản bị khoá/quyền thay đổi; hiển thị lỗi SMTP/phụ thuộc (503). |
| Hậu điều kiện | Dữ liệu/trạng thái đủ quyền được trả/hiển thị; đọc không đổi trạng thái vé/thanh toán. Dấu đã đọc thông báo chỉ đổi bằng thao tác ghi riêng. |
| Ưu tiên | H |
| Tiêu chí nghiệm thu | **WEB-FR-AUTH-06-AC-01** — Với tiền điều kiện/kích hoạt, kiểm tra: Chưa đăng nhập hoặc token sai trả 401; đủ đăng nhập nhưng thiếu quyền trả 403. **WEB-FR-AUTH-06-AC-02** — Thử đầu vào sai/thiếu quyền/xung đột áp dụng và kiểm tra từ chối đã nêu, không đổi dữ liệu trái phép và không báo thành công sai. |
| Bằng chứng | [Cinema_BE/AuthService/AuthService/Controllers/AuthController.cs](../Cinema_BE/AuthService/AuthService/Controllers/AuthController.cs); [Cinema_Mobile/lib/features/auth/screens/login_screen.dart](../Cinema_Mobile/lib/features/auth/screens/login_screen.dart); [Cinema_BE/AuthService/AuthService/Service/AuthService.cs](../Cinema_BE/AuthService/AuthService/Service/AuthService.cs); [Cinema_BE/ApiGateway/ApiGateway/Program.cs](../Cinema_BE/ApiGateway/ApiGateway/Program.cs) |
| Quy tắc nghiệp vụ | WEB-BR-01, WEB-BR-02, WEB-BR-03, WEB-BR-24, WEB-BR-25 |
| Ca sử dụng / màn / API | UC-WEB-01; WEB-SCR-LOGIN; WEB-API-029 |

### WEB-FR-AUTH-07 — Xác thực OTP email

| Trường | Đặc tả |
| --- | --- |
| Tên | Xác thực OTP email |
| Mô tả | Xác thực email bằng OTP 6 số: hết hạn sau 5 phút, tối đa 5 lần nhập, chờ 60 giây giữa hai lần gửi, mã mới thay mã cũ. Khi xác thực phải gửi kèm mật khẩu đã đăng ký; thành công thì đăng nhập luôn và gửi email chào mừng. |
| Tác nhân | Khách chưa đăng nhập; người có tài khoản; hệ thống |
| Tiền điều kiện | Truy cập được biểu mẫu và đã cấu hình gateway/AuthService; đăng ký/đăng nhập/OTP/khôi phục không cần phiên đã đăng nhập. Gửi mã cần SMTP. |
| Kích hoạt | Thực hiện “Xác thực OTP email” hoặc sự kiện/tác vụ backend tương ứng. |
| Luồng chính | 1. Đọc đầu vào/tài nguyên hiện tại và phiên áp dụng. 2. Thực hiện thao tác này: Xác thực email bằng OTP 6 số: hết hạn sau 5 phút, tối đa 5 lần nhập, chờ 60 giây giữa hai lần gửi, mã mới thay mã cũ. Khi xác thực phải gửi kèm mật khẩu đã đăng ký; thành công thì đăng nhập luôn và gửi email chào mừng. 3. Trả/hiển thị kết quả chính thức và làm mới dữ liệu bị tác động sau thành công. |
| Luồng thay thế / ngoại lệ | Từ chối trường sai (400), thông tin đăng nhập sai (401), email chưa xác thực (403), OTP cũ/sai hoặc vượt giới hạn gửi/tần suất (429). Xoá phiên khi tài khoản bị khoá/quyền thay đổi; hiển thị lỗi SMTP/phụ thuộc (503). |
| Hậu điều kiện | Xác thực thành công lưu người/token trả về và chọn trang theo vai trò đủ quyền; lỗi không cấp phiên. |
| Ưu tiên | H |
| Tiêu chí nghiệm thu | **WEB-FR-AUTH-07-AC-01** — Với tiền điều kiện/kích hoạt, kiểm tra: Xác thực email bằng OTP 6 số: hết hạn sau 5 phút, tối đa 5 lần nhập, chờ 60 giây giữa hai lần gửi, mã mới thay mã cũ. Khi xác thực phải gửi kèm mật khẩu đã đăng ký; thành công thì đăng nhập luôn và gửi email chào mừng. **WEB-FR-AUTH-07-AC-02** — Thử đầu vào sai/thiếu quyền/xung đột áp dụng và kiểm tra từ chối đã nêu, không đổi dữ liệu trái phép và không báo thành công sai. |
| Bằng chứng | [Cinema_BE/AuthService/AuthService/Controllers/AuthController.cs](../Cinema_BE/AuthService/AuthService/Controllers/AuthController.cs); [Cinema_Mobile/lib/features/auth/screens/verify_email_screen.dart](../Cinema_Mobile/lib/features/auth/screens/verify_email_screen.dart); [Cinema_BE/AuthService/AuthService/Service/AuthService.cs](../Cinema_BE/AuthService/AuthService/Service/AuthService.cs); [Cinema_BE/ApiGateway/ApiGateway/Program.cs](../Cinema_BE/ApiGateway/ApiGateway/Program.cs) |
| Quy tắc nghiệp vụ | WEB-BR-01, WEB-BR-02, WEB-BR-03, WEB-BR-24, WEB-BR-25 |
| Ca sử dụng / màn / API | UC-WEB-01; WEB-SCR-VERIFY; WEB-API-034, WEB-API-042 |

### WEB-FR-AUTH-08 — Đăng ký lại email chưa xác thực

| Trường | Đặc tả |
| --- | --- |
| Tên | Đăng ký lại email chưa xác thực |
| Mô tả | Đăng ký lại một email chưa xác thực thì thông tin mới thay thông tin cũ và gửi mã mới. Email đã xác thực thì báo đã đăng ký. |
| Tác nhân | Khách chưa đăng nhập; người có tài khoản; hệ thống |
| Tiền điều kiện | Truy cập được biểu mẫu và đã cấu hình gateway/AuthService; đăng ký/đăng nhập/OTP/khôi phục không cần phiên đã đăng nhập. Gửi mã cần SMTP. |
| Kích hoạt | Thực hiện “Đăng ký lại email chưa xác thực” hoặc sự kiện/tác vụ backend tương ứng. |
| Luồng chính | 1. Đọc đầu vào/tài nguyên hiện tại và phiên áp dụng. 2. Thực hiện thao tác này: Đăng ký lại một email chưa xác thực thì thông tin mới thay thông tin cũ và gửi mã mới. Email đã xác thực thì báo đã đăng ký. 3. Trả/hiển thị kết quả chính thức và làm mới dữ liệu bị tác động sau thành công. |
| Luồng thay thế / ngoại lệ | Từ chối trường sai (400), thông tin đăng nhập sai (401), email chưa xác thực (403), OTP cũ/sai hoặc vượt giới hạn gửi/tần suất (429). Xoá phiên khi tài khoản bị khoá/quyền thay đổi; hiển thị lỗi SMTP/phụ thuộc (503). |
| Hậu điều kiện | Ghi nhận đăng ký chưa xác thực và kết quả gửi OTP; chưa cấp access/refresh token trước xác thực. |
| Ưu tiên | M |
| Tiêu chí nghiệm thu | **WEB-FR-AUTH-08-AC-01** — Với tiền điều kiện/kích hoạt, kiểm tra: Đăng ký lại một email chưa xác thực thì thông tin mới thay thông tin cũ và gửi mã mới. Email đã xác thực thì báo đã đăng ký. **WEB-FR-AUTH-08-AC-02** — Thử đầu vào sai/thiếu quyền/xung đột áp dụng và kiểm tra từ chối đã nêu, không đổi dữ liệu trái phép và không báo thành công sai. |
| Bằng chứng | [Cinema_BE/AuthService/AuthService/Controllers/AuthController.cs](../Cinema_BE/AuthService/AuthService/Controllers/AuthController.cs); [Cinema_Mobile/lib/features/auth/screens/register_screen.dart](../Cinema_Mobile/lib/features/auth/screens/register_screen.dart); [Cinema_Mobile/lib/features/auth/screens/verify_email_screen.dart](../Cinema_Mobile/lib/features/auth/screens/verify_email_screen.dart); [Cinema_BE/AuthService/AuthService/Service/AuthService.cs](../Cinema_BE/AuthService/AuthService/Service/AuthService.cs); [Cinema_BE/ApiGateway/ApiGateway/Program.cs](../Cinema_BE/ApiGateway/ApiGateway/Program.cs) |
| Quy tắc nghiệp vụ | WEB-BR-01, WEB-BR-02, WEB-BR-03, WEB-BR-24, WEB-BR-25 |
| Ca sử dụng / màn / API | UC-WEB-01; WEB-SCR-REGISTER, WEB-SCR-VERIFY; WEB-API-033 |

### WEB-FR-AUTH-09 — Khôi phục mật khẩu

| Trường | Đặc tả |
| --- | --- |
| Tên | Khôi phục mật khẩu |
| Mô tả | Quên mật khẩu: gửi OTP qua email (luôn trả 200); đặt mật khẩu mới bằng OTP thì mọi refresh token cũ bị thu hồi và email được coi là đã xác thực. |
| Tác nhân | Khách chưa đăng nhập; người có tài khoản; hệ thống |
| Tiền điều kiện | Truy cập được biểu mẫu và đã cấu hình gateway/AuthService; đăng ký/đăng nhập/OTP/khôi phục không cần phiên đã đăng nhập. Gửi mã cần SMTP. |
| Kích hoạt | Thực hiện “Khôi phục mật khẩu” hoặc sự kiện/tác vụ backend tương ứng. |
| Luồng chính | 1. Đọc đầu vào/tài nguyên hiện tại và phiên áp dụng. 2. Thực hiện thao tác này: Quên mật khẩu: gửi OTP qua email (luôn trả 200); đặt mật khẩu mới bằng OTP thì mọi refresh token cũ bị thu hồi và email được coi là đã xác thực. 3. Trả/hiển thị kết quả chính thức và làm mới dữ liệu bị tác động sau thành công. |
| Luồng thay thế / ngoại lệ | Từ chối trường sai (400), thông tin đăng nhập sai (401), email chưa xác thực (403), OTP cũ/sai hoặc vượt giới hạn gửi/tần suất (429). Xoá phiên khi tài khoản bị khoá/quyền thay đổi; hiển thị lỗi SMTP/phụ thuộc (503). |
| Hậu điều kiện | Kết quả thành công quan sát được khớp yêu cầu này; chuyển trạng thái được chỉ định được lưu. Từ chối không cấp quyền hoặc để thay đổi dở dang trái phép. |
| Ưu tiên | H |
| Tiêu chí nghiệm thu | **WEB-FR-AUTH-09-AC-01** — Với tiền điều kiện/kích hoạt, kiểm tra: Quên mật khẩu: gửi OTP qua email (luôn trả 200); đặt mật khẩu mới bằng OTP thì mọi refresh token cũ bị thu hồi và email được coi là đã xác thực. **WEB-FR-AUTH-09-AC-02** — Thử đầu vào sai/thiếu quyền/xung đột áp dụng và kiểm tra từ chối đã nêu, không đổi dữ liệu trái phép và không báo thành công sai. |
| Bằng chứng | [Cinema_BE/AuthService/AuthService/Controllers/AuthController.cs](../Cinema_BE/AuthService/AuthService/Controllers/AuthController.cs); [Cinema_Mobile/lib/features/auth/screens/forgot_password_screen.dart](../Cinema_Mobile/lib/features/auth/screens/forgot_password_screen.dart); [Cinema_Mobile/lib/features/auth/screens/reset_password_screen.dart](../Cinema_Mobile/lib/features/auth/screens/reset_password_screen.dart); [Cinema_BE/AuthService/AuthService/Service/AuthService.cs](../Cinema_BE/AuthService/AuthService/Service/AuthService.cs); [Cinema_BE/ApiGateway/ApiGateway/Program.cs](../Cinema_BE/ApiGateway/ApiGateway/Program.cs) |
| Quy tắc nghiệp vụ | WEB-BR-01, WEB-BR-02, WEB-BR-03, WEB-BR-24, WEB-BR-25 |
| Ca sử dụng / màn / API | UC-WEB-01; WEB-SCR-FORGOT, WEB-SCR-RESET; WEB-API-026, WEB-API-035 |

### WEB-FR-AUTH-10 — Làm mới và đăng xuất

| Trường | Đặc tả |
| --- | --- |
| Tên | Làm mới và đăng xuất |
| Mô tả | Làm mới phiên bằng refresh token (xoay vòng, token cũ hết hiệu lực); đăng xuất thu hồi refresh token. App tự làm mới khi access token hết hạn. |
| Tác nhân | Khách chưa đăng nhập; người có tài khoản; hệ thống |
| Tiền điều kiện | Gateway đã được cấu hình. Đăng ký/khôi phục cần SMTP; thao tác được bảo vệ cần phiên tài khoản hợp lệ. |
| Kích hoạt | Thực hiện “Làm mới và đăng xuất” hoặc sự kiện/tác vụ backend tương ứng. |
| Luồng chính | 1. Đọc đầu vào/tài nguyên hiện tại và phiên áp dụng. 2. Thực hiện thao tác này: Làm mới phiên bằng refresh token (xoay vòng, token cũ hết hiệu lực); đăng xuất thu hồi refresh token. App tự làm mới khi access token hết hạn. 3. Trả/hiển thị kết quả chính thức và làm mới dữ liệu bị tác động sau thành công. |
| Luồng thay thế / ngoại lệ | Từ chối trường sai (400), thông tin đăng nhập sai (401), email chưa xác thực (403), OTP cũ/sai hoặc vượt giới hạn gửi/tần suất (429). Xoá phiên khi tài khoản bị khoá/quyền thay đổi; hiển thị lỗi SMTP/phụ thuộc (503). |
| Hậu điều kiện | Kết quả thành công quan sát được khớp yêu cầu này; chuyển trạng thái được chỉ định được lưu. Từ chối không cấp quyền hoặc để thay đổi dở dang trái phép. |
| Ưu tiên | H |
| Tiêu chí nghiệm thu | **WEB-FR-AUTH-10-AC-01** — Với tiền điều kiện/kích hoạt, kiểm tra: Làm mới phiên bằng refresh token (xoay vòng, token cũ hết hiệu lực); đăng xuất thu hồi refresh token. App tự làm mới khi access token hết hạn. **WEB-FR-AUTH-10-AC-02** — Thử đầu vào sai/thiếu quyền/xung đột áp dụng và kiểm tra từ chối đã nêu, không đổi dữ liệu trái phép và không báo thành công sai. |
| Bằng chứng | [Cinema_BE/AuthService/AuthService/Controllers/AuthController.cs](../Cinema_BE/AuthService/AuthService/Controllers/AuthController.cs); [Cinema_Mobile/lib/features/profile/screens/profile_screen.dart](../Cinema_Mobile/lib/features/profile/screens/profile_screen.dart); [Cinema_BE/AuthService/AuthService/Service/AuthService.cs](../Cinema_BE/AuthService/AuthService/Service/AuthService.cs); [Cinema_BE/ApiGateway/ApiGateway/Program.cs](../Cinema_BE/ApiGateway/ApiGateway/Program.cs) |
| Quy tắc nghiệp vụ | WEB-BR-01, WEB-BR-02, WEB-BR-03, WEB-BR-24, WEB-BR-25 |
| Ca sử dụng / màn / API | UC-WEB-01; WEB-SCR-PROFILE, WEB-SCR-MGT-PROFILE; WEB-API-028, WEB-API-032 |

### WEB-FR-AUTH-11 — Tài khoản hiện tại

| Trường | Đặc tả |
| --- | --- |
| Tên | Tài khoản hiện tại |
| Mô tả | Xem hồ sơ tài khoản hiện tại (`GET /api/v1/auth/me`). |
| Tác nhân | Khách chưa đăng nhập; người có tài khoản; hệ thống |
| Tiền điều kiện | Gateway đã được cấu hình. Đăng ký/khôi phục cần SMTP; thao tác được bảo vệ cần phiên tài khoản hợp lệ. |
| Kích hoạt | Thực hiện “Tài khoản hiện tại” hoặc sự kiện/tác vụ backend tương ứng. |
| Luồng chính | 1. Đọc đầu vào/tài nguyên hiện tại và phiên áp dụng. 2. Thực hiện thao tác này: Xem hồ sơ tài khoản hiện tại (`GET /api/v1/auth/me`). 3. Trả/hiển thị kết quả chính thức và làm mới dữ liệu bị tác động sau thành công. |
| Luồng thay thế / ngoại lệ | Từ chối trường sai (400), thông tin đăng nhập sai (401), email chưa xác thực (403), OTP cũ/sai hoặc vượt giới hạn gửi/tần suất (429). Xoá phiên khi tài khoản bị khoá/quyền thay đổi; hiển thị lỗi SMTP/phụ thuộc (503). |
| Hậu điều kiện | Dữ liệu/trạng thái đủ quyền được trả/hiển thị; đọc không đổi trạng thái vé/thanh toán. Dấu đã đọc thông báo chỉ đổi bằng thao tác ghi riêng. |
| Ưu tiên | M |
| Tiêu chí nghiệm thu | **WEB-FR-AUTH-11-AC-01** — Với tiền điều kiện/kích hoạt, kiểm tra: Xem hồ sơ tài khoản hiện tại (`GET /api/v1/auth/me`). **WEB-FR-AUTH-11-AC-02** — Thử đầu vào sai/thiếu quyền/xung đột áp dụng và kiểm tra từ chối đã nêu, không đổi dữ liệu trái phép và không báo thành công sai. |
| Bằng chứng | [Cinema_BE/AuthService/AuthService/Controllers/AuthController.cs](../Cinema_BE/AuthService/AuthService/Controllers/AuthController.cs); [Cinema_Mobile/lib/features/profile/screens/profile_screen.dart](../Cinema_Mobile/lib/features/profile/screens/profile_screen.dart); [Cinema_BE/AuthService/AuthService/Service/AuthService.cs](../Cinema_BE/AuthService/AuthService/Service/AuthService.cs); [Cinema_BE/ApiGateway/ApiGateway/Program.cs](../Cinema_BE/ApiGateway/ApiGateway/Program.cs) |
| Quy tắc nghiệp vụ | WEB-BR-01, WEB-BR-02, WEB-BR-03, WEB-BR-24, WEB-BR-25 |
| Ca sử dụng / màn / API | UC-WEB-01; WEB-SCR-PROFILE, WEB-SCR-MGT-PROFILE; WEB-API-029 |

### WEB-FR-AUTH-12 — Áp dụng khoá và đổi quyền

| Trường | Đặc tả |
| --- | --- |
| Tên | Áp dụng khoá và đổi quyền |
| Mô tả | Gateway kiểm tra trạng thái tài khoản ở mỗi request cần đăng nhập: bị khoá trả 401 `ACCOUNT_LOCKED`; vai trò đã đổi trả 403 `ROLE_CHANGED`; AuthService không phản hồi trả 503. App khách hiện lý do và đưa về màn đăng nhập. |
| Tác nhân | Khách chưa đăng nhập; người có tài khoản; hệ thống |
| Tiền điều kiện | Gateway đã được cấu hình. Đăng ký/khôi phục cần SMTP; thao tác được bảo vệ cần phiên tài khoản hợp lệ. |
| Kích hoạt | Thực hiện “Áp dụng khoá và đổi quyền” hoặc sự kiện/tác vụ backend tương ứng. |
| Luồng chính | 1. Đọc đầu vào/tài nguyên hiện tại và phiên áp dụng. 2. Thực hiện thao tác này: Gateway kiểm tra trạng thái tài khoản ở mỗi request cần đăng nhập: bị khoá trả 401 `ACCOUNT_LOCKED`; vai trò đã đổi trả 403 `ROLE_CHANGED`; AuthService không phản hồi trả 503. App khách hiện lý do và đưa về màn đăng nhập. 3. Trả/hiển thị kết quả chính thức và làm mới dữ liệu bị tác động sau thành công. |
| Luồng thay thế / ngoại lệ | Từ chối trường sai (400), thông tin đăng nhập sai (401), email chưa xác thực (403), OTP cũ/sai hoặc vượt giới hạn gửi/tần suất (429). Xoá phiên khi tài khoản bị khoá/quyền thay đổi; hiển thị lỗi SMTP/phụ thuộc (503). |
| Hậu điều kiện | Dữ liệu/trạng thái đủ quyền được trả/hiển thị; đọc không đổi trạng thái vé/thanh toán. Dấu đã đọc thông báo chỉ đổi bằng thao tác ghi riêng. |
| Ưu tiên | H |
| Tiêu chí nghiệm thu | **WEB-FR-AUTH-12-AC-01** — Với tiền điều kiện/kích hoạt, kiểm tra: Gateway kiểm tra trạng thái tài khoản ở mỗi request cần đăng nhập: bị khoá trả 401 `ACCOUNT_LOCKED`; vai trò đã đổi trả 403 `ROLE_CHANGED`; AuthService không phản hồi trả 503. App khách hiện lý do và đưa về màn đăng nhập. **WEB-FR-AUTH-12-AC-02** — Thử đầu vào sai/thiếu quyền/xung đột áp dụng và kiểm tra từ chối đã nêu, không đổi dữ liệu trái phép và không báo thành công sai. |
| Bằng chứng | [Cinema_BE/AuthService/AuthService/Controllers/AuthController.cs](../Cinema_BE/AuthService/AuthService/Controllers/AuthController.cs); [Cinema_Mobile/lib/features/auth/screens/login_screen.dart](../Cinema_Mobile/lib/features/auth/screens/login_screen.dart); [Cinema_BE/AuthService/AuthService/Service/AuthService.cs](../Cinema_BE/AuthService/AuthService/Service/AuthService.cs); [Cinema_BE/ApiGateway/ApiGateway/Program.cs](../Cinema_BE/ApiGateway/ApiGateway/Program.cs) |
| Quy tắc nghiệp vụ | WEB-BR-01, WEB-BR-02, WEB-BR-03, WEB-BR-24, WEB-BR-25 |
| Ca sử dụng / màn / API | UC-WEB-01; WEB-SCR-LOGIN; WEB-API-029 |

### WEB-FR-AUTH-13 — Kiểm tra trường tài khoản

| Trường | Đặc tả |
| --- | --- |
| Tên | Kiểm tra trường tài khoản |
| Mô tả | Kiểm tra dữ liệu tài khoản giống nhau ở app và API (đăng ký, đăng nhập, quên / đặt lại mật khẩu, Admin tạo tài khoản): email bắt buộc, tối đa 150 ký tự, có tên miền và đuôi ≥ 2 chữ cái, không dấu cách; mật khẩu mới 6–72 ký tự tính theo byte UTF-8; họ tên bắt buộc, tối đa 150 ký tự; số điện thoại không bắt buộc, 8–15 chữ số, tối đa 20 ký tự. Sai thì 400 kèm lỗi theo từng trường. Form đăng ký có ô nhập lại mật khẩu. |
| Tác nhân | Khách chưa đăng nhập; người có tài khoản; hệ thống |
| Tiền điều kiện | Truy cập được biểu mẫu và đã cấu hình gateway/AuthService; đăng ký/đăng nhập/OTP/khôi phục không cần phiên đã đăng nhập. Gửi mã cần SMTP. |
| Kích hoạt | Thực hiện “Kiểm tra trường tài khoản” hoặc sự kiện/tác vụ backend tương ứng. |
| Luồng chính | 1. Đọc đầu vào/tài nguyên hiện tại và phiên áp dụng. 2. Thực hiện thao tác này: Kiểm tra dữ liệu tài khoản giống nhau ở app và API (đăng ký, đăng nhập, quên / đặt lại mật khẩu, Admin tạo tài khoản): email bắt buộc, tối đa 150 ký tự, có tên miền và đuôi ≥ 2 chữ cái, không dấu cách; mật khẩu mới 6–72 ký tự tính theo byte UTF-8; họ tên bắt buộc, tối đa 150 ký tự; số điện thoại không bắt buộc, 8–15 chữ số, tối đa 20 ký tự. Sai thì 400 kèm lỗi theo từng trường. Form đăng ký có ô nhập lại mật khẩu. 3. Trả/hiển thị kết quả chính thức và làm mới dữ liệu bị tác động sau thành công. |
| Luồng thay thế / ngoại lệ | Từ chối trường sai (400), thông tin đăng nhập sai (401), email chưa xác thực (403), OTP cũ/sai hoặc vượt giới hạn gửi/tần suất (429). Xoá phiên khi tài khoản bị khoá/quyền thay đổi; hiển thị lỗi SMTP/phụ thuộc (503). |
| Hậu điều kiện | Kết quả thành công quan sát được khớp yêu cầu này; chuyển trạng thái được chỉ định được lưu. Từ chối không cấp quyền hoặc để thay đổi dở dang trái phép. |
| Ưu tiên | H |
| Tiêu chí nghiệm thu | **WEB-FR-AUTH-13-AC-01** — Với tiền điều kiện/kích hoạt, kiểm tra: Kiểm tra dữ liệu tài khoản giống nhau ở app và API (đăng ký, đăng nhập, quên / đặt lại mật khẩu, Admin tạo tài khoản): email bắt buộc, tối đa 150 ký tự, có tên miền và đuôi ≥ 2 chữ cái, không dấu cách; mật khẩu mới 6–72 ký tự tính theo byte UTF-8; họ tên bắt buộc, tối đa 150 ký tự; số điện thoại không bắt buộc, 8–15 chữ số, tối đa 20 ký tự. Sai thì 400 kèm lỗi theo từng trường. Form đăng ký có ô nhập lại mật khẩu. **WEB-FR-AUTH-13-AC-02** — Thử đầu vào sai/thiếu quyền/xung đột áp dụng và kiểm tra từ chối đã nêu, không đổi dữ liệu trái phép và không báo thành công sai. |
| Bằng chứng | [Cinema_BE/AuthService/AuthService/Controllers/AuthController.cs](../Cinema_BE/AuthService/AuthService/Controllers/AuthController.cs); [Cinema_BE/AuthService/AuthService/Controllers/UsersController.cs](../Cinema_BE/AuthService/AuthService/Controllers/UsersController.cs); [Cinema_Mobile/lib/features/auth/screens/login_screen.dart](../Cinema_Mobile/lib/features/auth/screens/login_screen.dart); [Cinema_Mobile/lib/features/auth/screens/register_screen.dart](../Cinema_Mobile/lib/features/auth/screens/register_screen.dart); [Cinema_Mobile/lib/features/auth/screens/forgot_password_screen.dart](../Cinema_Mobile/lib/features/auth/screens/forgot_password_screen.dart); [Cinema_Mobile/lib/features/auth/screens/reset_password_screen.dart](../Cinema_Mobile/lib/features/auth/screens/reset_password_screen.dart); [Cinema_Mobile/lib/features/admin/screens/admin_users_screen.dart](../Cinema_Mobile/lib/features/admin/screens/admin_users_screen.dart); [Cinema_BE/AuthService/AuthService/Service/AuthService.cs](../Cinema_BE/AuthService/AuthService/Service/AuthService.cs); [Cinema_BE/ApiGateway/ApiGateway/Program.cs](../Cinema_BE/ApiGateway/ApiGateway/Program.cs) |
| Quy tắc nghiệp vụ | WEB-BR-01, WEB-BR-02, WEB-BR-03, WEB-BR-24, WEB-BR-25 |
| Ca sử dụng / màn / API | UC-WEB-01; WEB-SCR-LOGIN, WEB-SCR-REGISTER, WEB-SCR-FORGOT, WEB-SCR-RESET, WEB-SCR-USER-EDITOR; WEB-API-027, WEB-API-033, WEB-API-035, WEB-API-041 |

### WEB-FR-AUTH-14 — Giới hạn tần suất xác thực

| Trường | Đặc tả |
| --- | --- |
| Tên | Giới hạn tần suất xác thực |
| Mô tả | Giới hạn 10 request / phút / IP cho các API đăng ký, đăng nhập, OTP, làm mới, quên / đặt lại mật khẩu; vượt thì 429 kèm `Retry-After`. |
| Tác nhân | Khách chưa đăng nhập; người có tài khoản; hệ thống |
| Tiền điều kiện | Truy cập được biểu mẫu và đã cấu hình gateway/AuthService; đăng ký/đăng nhập/OTP/khôi phục không cần phiên đã đăng nhập. Gửi mã cần SMTP. |
| Kích hoạt | Thực hiện “Giới hạn tần suất xác thực” hoặc sự kiện/tác vụ backend tương ứng. |
| Luồng chính | 1. Đọc đầu vào/tài nguyên hiện tại và phiên áp dụng. 2. Thực hiện thao tác này: Giới hạn 10 request / phút / IP cho các API đăng ký, đăng nhập, OTP, làm mới, quên / đặt lại mật khẩu; vượt thì 429 kèm `Retry-After`. 3. Trả/hiển thị kết quả chính thức và làm mới dữ liệu bị tác động sau thành công. |
| Luồng thay thế / ngoại lệ | Từ chối trường sai (400), thông tin đăng nhập sai (401), email chưa xác thực (403), OTP cũ/sai hoặc vượt giới hạn gửi/tần suất (429). Xoá phiên khi tài khoản bị khoá/quyền thay đổi; hiển thị lỗi SMTP/phụ thuộc (503). |
| Hậu điều kiện | Kết quả thành công quan sát được khớp yêu cầu này; chuyển trạng thái được chỉ định được lưu. Từ chối không cấp quyền hoặc để thay đổi dở dang trái phép. |
| Ưu tiên | M |
| Tiêu chí nghiệm thu | **WEB-FR-AUTH-14-AC-01** — Với tiền điều kiện/kích hoạt, kiểm tra: Giới hạn 10 request / phút / IP cho các API đăng ký, đăng nhập, OTP, làm mới, quên / đặt lại mật khẩu; vượt thì 429 kèm `Retry-After`. **WEB-FR-AUTH-14-AC-02** — Thử đầu vào sai/thiếu quyền/xung đột áp dụng và kiểm tra từ chối đã nêu, không đổi dữ liệu trái phép và không báo thành công sai. |
| Bằng chứng | [Cinema_BE/AuthService/AuthService/Controllers/AuthController.cs](../Cinema_BE/AuthService/AuthService/Controllers/AuthController.cs); [Cinema_Mobile/lib/features/auth/screens/verify_email_screen.dart](../Cinema_Mobile/lib/features/auth/screens/verify_email_screen.dart); [Cinema_Mobile/lib/features/auth/screens/forgot_password_screen.dart](../Cinema_Mobile/lib/features/auth/screens/forgot_password_screen.dart); [Cinema_Mobile/lib/features/auth/screens/reset_password_screen.dart](../Cinema_Mobile/lib/features/auth/screens/reset_password_screen.dart); [Cinema_BE/AuthService/AuthService/Service/AuthService.cs](../Cinema_BE/AuthService/AuthService/Service/AuthService.cs); [Cinema_BE/ApiGateway/ApiGateway/Program.cs](../Cinema_BE/ApiGateway/ApiGateway/Program.cs) |
| Quy tắc nghiệp vụ | WEB-BR-01, WEB-BR-02, WEB-BR-03, WEB-BR-24, WEB-BR-25 |
| Ca sử dụng / màn / API | UC-WEB-01; WEB-SCR-VERIFY, WEB-SCR-FORGOT, WEB-SCR-RESET; WEB-API-027, WEB-API-032, WEB-API-034 |

### WEB-FR-AUTH-15 — Tìm thành viên theo điện thoại

| Trường | Đặc tả |
| --- | --- |
| Tên | Tìm thành viên theo điện thoại |
| Mô tả | Staff/Admin tìm tài khoản khách hàng theo số điện thoại (so theo chữ số, bỏ qua dấu cách / chấm / gạch) để bán vé và tích điểm tại quầy. Số điện thoại ít hơn 8 hoặc quá 15 chữ số bị 400; khách hàng gọi thì 403. |
| Tác nhân | Nhân viên/quản trị viên |
| Tiền điều kiện | Gateway đã được cấu hình. Đăng ký/khôi phục cần SMTP; thao tác được bảo vệ cần phiên tài khoản hợp lệ. |
| Kích hoạt | Thực hiện “Tìm thành viên theo điện thoại” hoặc sự kiện/tác vụ backend tương ứng. |
| Luồng chính | 1. Đọc đầu vào/tài nguyên hiện tại và phiên áp dụng. 2. Thực hiện thao tác này: Staff/Admin tìm tài khoản khách hàng theo số điện thoại (so theo chữ số, bỏ qua dấu cách / chấm / gạch) để bán vé và tích điểm tại quầy. Số điện thoại ít hơn 8 hoặc quá 15 chữ số bị 400; khách hàng gọi thì 403. 3. Trả/hiển thị kết quả chính thức và làm mới dữ liệu bị tác động sau thành công. |
| Luồng thay thế / ngoại lệ | Từ chối trường sai (400), thông tin đăng nhập sai (401), email chưa xác thực (403), OTP cũ/sai hoặc vượt giới hạn gửi/tần suất (429). Xoá phiên khi tài khoản bị khoá/quyền thay đổi; hiển thị lỗi SMTP/phụ thuộc (503). |
| Hậu điều kiện | Dữ liệu/trạng thái đủ quyền được trả/hiển thị; đọc không đổi trạng thái vé/thanh toán. Dấu đã đọc thông báo chỉ đổi bằng thao tác ghi riêng. |
| Ưu tiên | M |
| Tiêu chí nghiệm thu | **WEB-FR-AUTH-15-AC-01** — Với tiền điều kiện/kích hoạt, kiểm tra: Staff/Admin tìm tài khoản khách hàng theo số điện thoại (so theo chữ số, bỏ qua dấu cách / chấm / gạch) để bán vé và tích điểm tại quầy. Số điện thoại ít hơn 8 hoặc quá 15 chữ số bị 400; khách hàng gọi thì 403. **WEB-FR-AUTH-15-AC-02** — Thử đầu vào sai/thiếu quyền/xung đột áp dụng và kiểm tra từ chối đã nêu, không đổi dữ liệu trái phép và không báo thành công sai. |
| Bằng chứng | [Cinema_BE/AuthService/AuthService/Controllers/MembersController.cs](../Cinema_BE/AuthService/AuthService/Controllers/MembersController.cs); [Cinema_Mobile/lib/features/staff/screens/staff_create_booking_screen.dart](../Cinema_Mobile/lib/features/staff/screens/staff_create_booking_screen.dart); [Cinema_BE/AuthService/AuthService/Service/AuthService.cs](../Cinema_BE/AuthService/AuthService/Service/AuthService.cs); [Cinema_BE/ApiGateway/ApiGateway/Program.cs](../Cinema_BE/ApiGateway/ApiGateway/Program.cs) |
| Quy tắc nghiệp vụ | WEB-BR-01, WEB-BR-02, WEB-BR-03, WEB-BR-24, WEB-BR-25 |
| Ca sử dụng / màn / API | UC-WEB-01; WEB-SCR-COUNTER; WEB-API-030 |

### WEB-FR-AUTH-16 — Sửa hồ sơ

| Trường | Đặc tả |
| --- | --- |
| Tên | Sửa hồ sơ |
| Mô tả | Người dùng tự **sửa hồ sơ** (Account → Edit profile): họ tên (bắt buộc, tối đa 150 ký tự) và số điện thoại (không bắt buộc, cùng quy tắc với đăng ký; bỏ trống là xoá). Email là tên đăng nhập nên không đổi. |
| Tác nhân | Khách chưa đăng nhập; người có tài khoản; hệ thống |
| Tiền điều kiện | Gateway đã được cấu hình. Đăng ký/khôi phục cần SMTP; thao tác được bảo vệ cần phiên tài khoản hợp lệ. |
| Kích hoạt | Thực hiện “Sửa hồ sơ” hoặc sự kiện/tác vụ backend tương ứng. |
| Luồng chính | 1. Đọc đầu vào/tài nguyên hiện tại và phiên áp dụng. 2. Thực hiện thao tác này: Người dùng tự **sửa hồ sơ** (Account → Edit profile): họ tên (bắt buộc, tối đa 150 ký tự) và số điện thoại (không bắt buộc, cùng quy tắc với đăng ký; bỏ trống là xoá). Email là tên đăng nhập nên không đổi. 3. Trả/hiển thị kết quả chính thức và làm mới dữ liệu bị tác động sau thành công. |
| Luồng thay thế / ngoại lệ | Từ chối trường sai (400), thông tin đăng nhập sai (401), email chưa xác thực (403), OTP cũ/sai hoặc vượt giới hạn gửi/tần suất (429). Xoá phiên khi tài khoản bị khoá/quyền thay đổi; hiển thị lỗi SMTP/phụ thuộc (503). |
| Hậu điều kiện | Kết quả thành công quan sát được khớp yêu cầu này; chuyển trạng thái được chỉ định được lưu. Từ chối không cấp quyền hoặc để thay đổi dở dang trái phép. |
| Ưu tiên | M |
| Tiêu chí nghiệm thu | **WEB-FR-AUTH-16-AC-01** — Với tiền điều kiện/kích hoạt, kiểm tra: Người dùng tự **sửa hồ sơ** (Account → Edit profile): họ tên (bắt buộc, tối đa 150 ký tự) và số điện thoại (không bắt buộc, cùng quy tắc với đăng ký; bỏ trống là xoá). Email là tên đăng nhập nên không đổi. **WEB-FR-AUTH-16-AC-02** — Thử đầu vào sai/thiếu quyền/xung đột áp dụng và kiểm tra từ chối đã nêu, không đổi dữ liệu trái phép và không báo thành công sai. |
| Bằng chứng | [Cinema_BE/AuthService/AuthService/Controllers/AuthController.cs](../Cinema_BE/AuthService/AuthService/Controllers/AuthController.cs); [Cinema_Mobile/lib/features/profile/screens/profile_screen.dart](../Cinema_Mobile/lib/features/profile/screens/profile_screen.dart); [Cinema_BE/AuthService/AuthService/Service/AuthService.cs](../Cinema_BE/AuthService/AuthService/Service/AuthService.cs); [Cinema_BE/ApiGateway/ApiGateway/Program.cs](../Cinema_BE/ApiGateway/ApiGateway/Program.cs) |
| Quy tắc nghiệp vụ | WEB-BR-01, WEB-BR-02, WEB-BR-03, WEB-BR-24, WEB-BR-25 |
| Ca sử dụng / màn / API | UC-WEB-01; WEB-SCR-PROFILE, WEB-SCR-MGT-PROFILE; WEB-API-031 |

### WEB-FR-AUTH-17 — Đổi mật khẩu hiện tại

| Trường | Đặc tả |
| --- | --- |
| Tên | Đổi mật khẩu hiện tại |
| Mô tả | **Đổi mật khẩu bằng mật khẩu hiện tại** (Account → Change password): nhập mật khẩu hiện tại, mật khẩu mới hai lần. Sai mật khẩu hiện tại hoặc trùng mật khẩu cũ bị 400. Đổi xong các thiết bị khác bị đăng xuất (thu hồi refresh token), thiết bị đang dùng nhận token mới. Quên mật khẩu hiện tại thì chuyển sang luồng OTP email. Giới hạn 10 lần / phút như đăng nhập. |
| Tác nhân | Khách chưa đăng nhập; người có tài khoản; hệ thống |
| Tiền điều kiện | Gateway đã được cấu hình. Đăng ký/khôi phục cần SMTP; thao tác được bảo vệ cần phiên tài khoản hợp lệ. |
| Kích hoạt | Thực hiện “Đổi mật khẩu hiện tại” hoặc sự kiện/tác vụ backend tương ứng. |
| Luồng chính | 1. Đọc đầu vào/tài nguyên hiện tại và phiên áp dụng. 2. Thực hiện thao tác này: **Đổi mật khẩu bằng mật khẩu hiện tại** (Account → Change password): nhập mật khẩu hiện tại, mật khẩu mới hai lần. Sai mật khẩu hiện tại hoặc trùng mật khẩu cũ bị 400. Đổi xong các thiết bị khác bị đăng xuất (thu hồi refresh token), thiết bị đang dùng nhận token mới. Quên mật khẩu hiện tại thì chuyển sang luồng OTP email. Giới hạn 10 lần / phút như đăng nhập. 3. Trả/hiển thị kết quả chính thức và làm mới dữ liệu bị tác động sau thành công. |
| Luồng thay thế / ngoại lệ | Từ chối trường sai (400), thông tin đăng nhập sai (401), email chưa xác thực (403), OTP cũ/sai hoặc vượt giới hạn gửi/tần suất (429). Xoá phiên khi tài khoản bị khoá/quyền thay đổi; hiển thị lỗi SMTP/phụ thuộc (503). |
| Hậu điều kiện | Kết quả thành công quan sát được khớp yêu cầu này; chuyển trạng thái được chỉ định được lưu. Từ chối không cấp quyền hoặc để thay đổi dở dang trái phép. |
| Ưu tiên | M |
| Tiêu chí nghiệm thu | **WEB-FR-AUTH-17-AC-01** — Với tiền điều kiện/kích hoạt, kiểm tra: **Đổi mật khẩu bằng mật khẩu hiện tại** (Account → Change password): nhập mật khẩu hiện tại, mật khẩu mới hai lần. Sai mật khẩu hiện tại hoặc trùng mật khẩu cũ bị 400. Đổi xong các thiết bị khác bị đăng xuất (thu hồi refresh token), thiết bị đang dùng nhận token mới. Quên mật khẩu hiện tại thì chuyển sang luồng OTP email. Giới hạn 10 lần / phút như đăng nhập. **WEB-FR-AUTH-17-AC-02** — Thử đầu vào sai/thiếu quyền/xung đột áp dụng và kiểm tra từ chối đã nêu, không đổi dữ liệu trái phép và không báo thành công sai. |
| Bằng chứng | [Cinema_BE/AuthService/AuthService/Controllers/AuthController.cs](../Cinema_BE/AuthService/AuthService/Controllers/AuthController.cs); [Cinema_Mobile/lib/features/profile/screens/profile_screen.dart](../Cinema_Mobile/lib/features/profile/screens/profile_screen.dart); [Cinema_BE/AuthService/AuthService/Service/AuthService.cs](../Cinema_BE/AuthService/AuthService/Service/AuthService.cs); [Cinema_BE/ApiGateway/ApiGateway/Program.cs](../Cinema_BE/ApiGateway/ApiGateway/Program.cs) |
| Quy tắc nghiệp vụ | WEB-BR-01, WEB-BR-02, WEB-BR-03, WEB-BR-24, WEB-BR-25 |
| Ca sử dụng / màn / API | UC-WEB-01; WEB-SCR-PROFILE, WEB-SCR-MGT-PROFILE; WEB-API-025 |

### WEB-FR-USER-01 — Danh sách tài khoản

| Trường | Đặc tả |
| --- | --- |
| Tên | Danh sách tài khoản |
| Mô tả | Xem danh sách tài khoản: tìm kiếm, lọc theo vai trò và trạng thái, phân trang. |
| Tác nhân | Quản trị viên |
| Tiền điều kiện | Có phiên quản trị viên; bản ghi đích tồn tại khi sửa/dừng/điều chỉnh. |
| Kích hoạt | Thực hiện “Danh sách tài khoản” hoặc sự kiện/tác vụ backend tương ứng. |
| Luồng chính | 1. Đọc đầu vào/tài nguyên hiện tại và phiên áp dụng. 2. Thực hiện thao tác này: Xem danh sách tài khoản: tìm kiếm, lọc theo vai trò và trạng thái, phân trang. 3. Trả/hiển thị kết quả chính thức và làm mới dữ liệu bị tác động sau thành công. |
| Luồng thay thế / ngoại lệ | Từ chối người gọi không phải quản trị viên; từ chối trường sai, email trùng và tự khoá tài khoản. Lưu vai trò không đổi không được buộc đăng nhập lại. |
| Hậu điều kiện | Dữ liệu/trạng thái đủ quyền được trả/hiển thị; đọc không đổi trạng thái vé/thanh toán. Dấu đã đọc thông báo chỉ đổi bằng thao tác ghi riêng. |
| Ưu tiên | H |
| Tiêu chí nghiệm thu | **WEB-FR-USER-01-AC-01** — Với tiền điều kiện/kích hoạt, kiểm tra: Xem danh sách tài khoản: tìm kiếm, lọc theo vai trò và trạng thái, phân trang. **WEB-FR-USER-01-AC-02** — Thử đầu vào sai/thiếu quyền/xung đột áp dụng và kiểm tra từ chối đã nêu, không đổi dữ liệu trái phép và không báo thành công sai. |
| Bằng chứng | [Cinema_BE/AuthService/AuthService/Controllers/UsersController.cs](../Cinema_BE/AuthService/AuthService/Controllers/UsersController.cs); [Cinema_Mobile/lib/features/admin/screens/admin_users_screen.dart](../Cinema_Mobile/lib/features/admin/screens/admin_users_screen.dart) |
| Quy tắc nghiệp vụ | WEB-BR-03, WEB-BR-24 |
| Ca sử dụng / màn / API | UC-WEB-02; WEB-SCR-ADMIN-USERS; WEB-API-040 |

### WEB-FR-USER-02 — Chi tiết tài khoản

| Trường | Đặc tả |
| --- | --- |
| Tên | Chi tiết tài khoản |
| Mô tả | Xem chi tiết tài khoản. |
| Tác nhân | Quản trị viên |
| Tiền điều kiện | Có phiên quản trị viên; bản ghi đích tồn tại khi sửa/dừng/điều chỉnh. |
| Kích hoạt | Thực hiện “Chi tiết tài khoản” hoặc sự kiện/tác vụ backend tương ứng. |
| Luồng chính | 1. Đọc đầu vào/tài nguyên hiện tại và phiên áp dụng. 2. Thực hiện thao tác này: Xem chi tiết tài khoản. 3. Trả/hiển thị kết quả chính thức và làm mới dữ liệu bị tác động sau thành công. |
| Luồng thay thế / ngoại lệ | Từ chối người gọi không phải quản trị viên; từ chối trường sai, email trùng và tự khoá tài khoản. Lưu vai trò không đổi không được buộc đăng nhập lại. |
| Hậu điều kiện | Dữ liệu/trạng thái đủ quyền được trả/hiển thị; đọc không đổi trạng thái vé/thanh toán. Dấu đã đọc thông báo chỉ đổi bằng thao tác ghi riêng. |
| Ưu tiên | H |
| Tiêu chí nghiệm thu | **WEB-FR-USER-02-AC-01** — Với tiền điều kiện/kích hoạt, kiểm tra: Xem chi tiết tài khoản. **WEB-FR-USER-02-AC-02** — Thử đầu vào sai/thiếu quyền/xung đột áp dụng và kiểm tra từ chối đã nêu, không đổi dữ liệu trái phép và không báo thành công sai. |
| Bằng chứng | [Cinema_BE/AuthService/AuthService/Controllers/UsersController.cs](../Cinema_BE/AuthService/AuthService/Controllers/UsersController.cs); [Cinema_Mobile/lib/features/admin/screens/admin_users_screen.dart](../Cinema_Mobile/lib/features/admin/screens/admin_users_screen.dart) |
| Quy tắc nghiệp vụ | WEB-BR-03, WEB-BR-24 |
| Ca sử dụng / màn / API | UC-WEB-02; WEB-SCR-USER-EDITOR; WEB-API-039 |

### WEB-FR-USER-03 — Tạo tài khoản

| Trường | Đặc tả |
| --- | --- |
| Tên | Tạo tài khoản |
| Mô tả | Tạo tài khoản với một hoặc nhiều vai trò; không cần xác thực OTP. |
| Tác nhân | Quản trị viên |
| Tiền điều kiện | Có phiên quản trị viên; bản ghi đích tồn tại khi sửa/dừng/điều chỉnh. |
| Kích hoạt | Thực hiện “Tạo tài khoản” hoặc sự kiện/tác vụ backend tương ứng. |
| Luồng chính | 1. Đọc đầu vào/tài nguyên hiện tại và phiên áp dụng. 2. Thực hiện thao tác này: Tạo tài khoản với một hoặc nhiều vai trò; không cần xác thực OTP. 3. Trả/hiển thị kết quả chính thức và làm mới dữ liệu bị tác động sau thành công. |
| Luồng thay thế / ngoại lệ | Từ chối người gọi không phải quản trị viên; từ chối trường sai, email trùng và tự khoá tài khoản. Lưu vai trò không đổi không được buộc đăng nhập lại. |
| Hậu điều kiện | Kết quả thành công quan sát được khớp yêu cầu này; chuyển trạng thái được chỉ định được lưu. Từ chối không cấp quyền hoặc để thay đổi dở dang trái phép. |
| Ưu tiên | H |
| Tiêu chí nghiệm thu | **WEB-FR-USER-03-AC-01** — Với tiền điều kiện/kích hoạt, kiểm tra: Tạo tài khoản với một hoặc nhiều vai trò; không cần xác thực OTP. **WEB-FR-USER-03-AC-02** — Thử đầu vào sai/thiếu quyền/xung đột áp dụng và kiểm tra từ chối đã nêu, không đổi dữ liệu trái phép và không báo thành công sai. |
| Bằng chứng | [Cinema_BE/AuthService/AuthService/Controllers/UsersController.cs](../Cinema_BE/AuthService/AuthService/Controllers/UsersController.cs); [Cinema_Mobile/lib/features/admin/screens/admin_users_screen.dart](../Cinema_Mobile/lib/features/admin/screens/admin_users_screen.dart) |
| Quy tắc nghiệp vụ | WEB-BR-03, WEB-BR-24 |
| Ca sử dụng / màn / API | UC-WEB-02; WEB-SCR-USER-EDITOR; WEB-API-041 |

### WEB-FR-USER-04 — Đổi vai trò tài khoản

| Trường | Đặc tả |
| --- | --- |
| Tên | Đổi vai trò tài khoản |
| Mô tả | Đổi vai trò: refresh token cũ bị thu hồi, phiên cũ bị yêu cầu đăng nhập lại; lưu lại đúng vai trò cũ thì giữ phiên. |
| Tác nhân | Quản trị viên |
| Tiền điều kiện | Có phiên quản trị viên; bản ghi đích tồn tại khi sửa/dừng/điều chỉnh. |
| Kích hoạt | Thực hiện “Đổi vai trò tài khoản” hoặc sự kiện/tác vụ backend tương ứng. |
| Luồng chính | 1. Đọc đầu vào/tài nguyên hiện tại và phiên áp dụng. 2. Thực hiện thao tác này: Đổi vai trò: refresh token cũ bị thu hồi, phiên cũ bị yêu cầu đăng nhập lại; lưu lại đúng vai trò cũ thì giữ phiên. 3. Trả/hiển thị kết quả chính thức và làm mới dữ liệu bị tác động sau thành công. |
| Luồng thay thế / ngoại lệ | Từ chối người gọi không phải quản trị viên; từ chối trường sai, email trùng và tự khoá tài khoản. Lưu vai trò không đổi không được buộc đăng nhập lại. |
| Hậu điều kiện | Kết quả thành công quan sát được khớp yêu cầu này; chuyển trạng thái được chỉ định được lưu. Từ chối không cấp quyền hoặc để thay đổi dở dang trái phép. |
| Ưu tiên | H |
| Tiêu chí nghiệm thu | **WEB-FR-USER-04-AC-01** — Với tiền điều kiện/kích hoạt, kiểm tra: Đổi vai trò: refresh token cũ bị thu hồi, phiên cũ bị yêu cầu đăng nhập lại; lưu lại đúng vai trò cũ thì giữ phiên. **WEB-FR-USER-04-AC-02** — Thử đầu vào sai/thiếu quyền/xung đột áp dụng và kiểm tra từ chối đã nêu, không đổi dữ liệu trái phép và không báo thành công sai. |
| Bằng chứng | [Cinema_BE/AuthService/AuthService/Controllers/UsersController.cs](../Cinema_BE/AuthService/AuthService/Controllers/UsersController.cs); [Cinema_Mobile/lib/features/admin/screens/admin_users_screen.dart](../Cinema_Mobile/lib/features/admin/screens/admin_users_screen.dart) |
| Quy tắc nghiệp vụ | WEB-BR-03, WEB-BR-24 |
| Ca sử dụng / màn / API | UC-WEB-02; WEB-SCR-USER-EDITOR; WEB-API-037 |

### WEB-FR-USER-05 — Khoá và mở khoá

| Trường | Đặc tả |
| --- | --- |
| Tên | Khoá và mở khoá |
| Mô tả | Khoá / mở khoá tài khoản; Admin không tự khoá chính mình. |
| Tác nhân | Quản trị viên |
| Tiền điều kiện | Có phiên quản trị viên; bản ghi đích tồn tại khi sửa/dừng/điều chỉnh. |
| Kích hoạt | Thực hiện “Khoá và mở khoá” hoặc sự kiện/tác vụ backend tương ứng. |
| Luồng chính | 1. Đọc đầu vào/tài nguyên hiện tại và phiên áp dụng. 2. Thực hiện thao tác này: Khoá / mở khoá tài khoản; Admin không tự khoá chính mình. 3. Trả/hiển thị kết quả chính thức và làm mới dữ liệu bị tác động sau thành công. |
| Luồng thay thế / ngoại lệ | Từ chối người gọi không phải quản trị viên; từ chối trường sai, email trùng và tự khoá tài khoản. Lưu vai trò không đổi không được buộc đăng nhập lại. |
| Hậu điều kiện | Kết quả thành công quan sát được khớp yêu cầu này; chuyển trạng thái được chỉ định được lưu. Từ chối không cấp quyền hoặc để thay đổi dở dang trái phép. |
| Ưu tiên | H |
| Tiêu chí nghiệm thu | **WEB-FR-USER-05-AC-01** — Với tiền điều kiện/kích hoạt, kiểm tra: Khoá / mở khoá tài khoản; Admin không tự khoá chính mình. **WEB-FR-USER-05-AC-02** — Thử đầu vào sai/thiếu quyền/xung đột áp dụng và kiểm tra từ chối đã nêu, không đổi dữ liệu trái phép và không báo thành công sai. |
| Bằng chứng | [Cinema_BE/AuthService/AuthService/Controllers/UsersController.cs](../Cinema_BE/AuthService/AuthService/Controllers/UsersController.cs); [Cinema_Mobile/lib/features/admin/screens/admin_users_screen.dart](../Cinema_Mobile/lib/features/admin/screens/admin_users_screen.dart) |
| Quy tắc nghiệp vụ | WEB-BR-03, WEB-BR-24 |
| Ca sử dụng / màn / API | UC-WEB-02; WEB-SCR-USER-EDITOR; WEB-API-038 |

### WEB-FR-USER-06 — Danh sách vai trò

| Trường | Đặc tả |
| --- | --- |
| Tên | Danh sách vai trò |
| Mô tả | Xem danh sách vai trò (`ROLE_CUSTOMER`, `ROLE_STAFF`, `ROLE_ADMIN`). |
| Tác nhân | Quản trị viên |
| Tiền điều kiện | Có phiên quản trị viên; bản ghi đích tồn tại khi sửa/dừng/điều chỉnh. |
| Kích hoạt | Thực hiện “Danh sách vai trò” hoặc sự kiện/tác vụ backend tương ứng. |
| Luồng chính | 1. Đọc đầu vào/tài nguyên hiện tại và phiên áp dụng. 2. Thực hiện thao tác này: Xem danh sách vai trò (`ROLE_CUSTOMER`, `ROLE_STAFF`, `ROLE_ADMIN`). 3. Trả/hiển thị kết quả chính thức và làm mới dữ liệu bị tác động sau thành công. |
| Luồng thay thế / ngoại lệ | Từ chối người gọi không phải quản trị viên; từ chối trường sai, email trùng và tự khoá tài khoản. Lưu vai trò không đổi không được buộc đăng nhập lại. |
| Hậu điều kiện | Dữ liệu/trạng thái đủ quyền được trả/hiển thị; đọc không đổi trạng thái vé/thanh toán. Dấu đã đọc thông báo chỉ đổi bằng thao tác ghi riêng. |
| Ưu tiên | M |
| Tiêu chí nghiệm thu | **WEB-FR-USER-06-AC-01** — Với tiền điều kiện/kích hoạt, kiểm tra: Xem danh sách vai trò (`ROLE_CUSTOMER`, `ROLE_STAFF`, `ROLE_ADMIN`). **WEB-FR-USER-06-AC-02** — Thử đầu vào sai/thiếu quyền/xung đột áp dụng và kiểm tra từ chối đã nêu, không đổi dữ liệu trái phép và không báo thành công sai. |
| Bằng chứng | [Cinema_BE/AuthService/AuthService/Controllers/RolesController.cs](../Cinema_BE/AuthService/AuthService/Controllers/RolesController.cs); [Cinema_Mobile/lib/features/admin/screens/admin_users_screen.dart](../Cinema_Mobile/lib/features/admin/screens/admin_users_screen.dart); [Cinema_BE/AuthService/AuthService/Controllers/UsersController.cs](../Cinema_BE/AuthService/AuthService/Controllers/UsersController.cs) |
| Quy tắc nghiệp vụ | WEB-BR-03, WEB-BR-24 |
| Ca sử dụng / màn / API | UC-WEB-02; WEB-SCR-ADMIN-USERS, WEB-SCR-USER-EDITOR; WEB-API-036 |

### WEB-FR-MOV-01 — Danh mục phân trang

| Trường | Đặc tả |
| --- | --- |
| Tên | Danh mục phân trang |
| Mô tả | Danh sách phim có phân trang (Admin). |
| Tác nhân | Quản trị viên |
| Tiền điều kiện | Có phiên quản trị viên; bản ghi đích tồn tại khi sửa/dừng/điều chỉnh. |
| Kích hoạt | Thực hiện “Danh mục phân trang” hoặc sự kiện/tác vụ backend tương ứng. |
| Luồng chính | 1. Đọc đầu vào/tài nguyên hiện tại và phiên áp dụng. 2. Thực hiện thao tác này: Danh sách phim có phân trang (Admin). 3. Trả/hiển thị kết quả chính thức và làm mới dữ liệu bị tác động sau thành công. |
| Luồng thay thế / ngoại lệ | Hiện trạng thái rỗng khi không có phim/suất phù hợp. Đánh giá bằng vé người khác trả 404; vé chưa check-in trả 400. Media lỗi phải còn ảnh hoặc nội dung dự phòng. |
| Hậu điều kiện | Dữ liệu/trạng thái đủ quyền được trả/hiển thị; đọc không đổi trạng thái vé/thanh toán. Dấu đã đọc thông báo chỉ đổi bằng thao tác ghi riêng. |
| Ưu tiên | H |
| Tiêu chí nghiệm thu | **WEB-FR-MOV-01-AC-01** — Với tiền điều kiện/kích hoạt, kiểm tra: Danh sách phim có phân trang (Admin). **WEB-FR-MOV-01-AC-02** — Thử đầu vào sai/thiếu quyền/xung đột áp dụng và kiểm tra từ chối đã nêu, không đổi dữ liệu trái phép và không báo thành công sai. |
| Bằng chứng | [Cinema_BE/MovieService/MovieService/Controllers/MoviesController.cs](../Cinema_BE/MovieService/MovieService/Controllers/MoviesController.cs); [Cinema_Mobile/lib/features/admin/screens/admin_movies_screen.dart](../Cinema_Mobile/lib/features/admin/screens/admin_movies_screen.dart); [Cinema_BE/MovieService/MovieService/Service/Impl/MovieService.cs](../Cinema_BE/MovieService/MovieService/Service/Impl/MovieService.cs); [Cinema_BE/BookingService/BookingService/Services/Implementations/MovieReviewService.cs](../Cinema_BE/BookingService/BookingService/Services/Implementations/MovieReviewService.cs) |
| Quy tắc nghiệp vụ | WEB-BR-26 |
| Ca sử dụng / màn / API | UC-WEB-03; WEB-SCR-ADMIN-MOVIES; WEB-API-070 |

### WEB-FR-MOV-02 — Chi tiết phim

| Trường | Đặc tả |
| --- | --- |
| Tên | Chi tiết phim |
| Mô tả | Chi tiết phim: tên, mô tả, thời lượng, thể loại, ngôn ngữ, ngày phát hành, poster, trailer, trạng thái. |
| Tác nhân | Khách chưa đăng nhập/khách hàng xem phim; quản trị viên sửa danh mục và kiểm duyệt |
| Tiền điều kiện | Truy cập được danh mục công khai; phim tồn tại với thao tác chi tiết/trailer. Kết quả tìm rỗng là hợp lệ. |
| Kích hoạt | Thực hiện “Chi tiết phim” hoặc sự kiện/tác vụ backend tương ứng. |
| Luồng chính | 1. Đọc đầu vào/tài nguyên hiện tại và phiên áp dụng. 2. Thực hiện thao tác này: Chi tiết phim: tên, mô tả, thời lượng, thể loại, ngôn ngữ, ngày phát hành, poster, trailer, trạng thái. 3. Trả/hiển thị kết quả chính thức và làm mới dữ liệu bị tác động sau thành công. |
| Luồng thay thế / ngoại lệ | Hiện trạng thái rỗng khi không có phim/suất phù hợp. Đánh giá bằng vé người khác trả 404; vé chưa check-in trả 400. Media lỗi phải còn ảnh hoặc nội dung dự phòng. |
| Hậu điều kiện | Dữ liệu/trạng thái đủ quyền được trả/hiển thị; đọc không đổi trạng thái vé/thanh toán. Dấu đã đọc thông báo chỉ đổi bằng thao tác ghi riêng. |
| Ưu tiên | H |
| Tiêu chí nghiệm thu | **WEB-FR-MOV-02-AC-01** — Với tiền điều kiện/kích hoạt, kiểm tra: Chi tiết phim: tên, mô tả, thời lượng, thể loại, ngôn ngữ, ngày phát hành, poster, trailer, trạng thái. **WEB-FR-MOV-02-AC-02** — Thử đầu vào sai/thiếu quyền/xung đột áp dụng và kiểm tra từ chối đã nêu, không đổi dữ liệu trái phép và không báo thành công sai. |
| Bằng chứng | [Cinema_BE/MovieService/MovieService/Controllers/MoviesController.cs](../Cinema_BE/MovieService/MovieService/Controllers/MoviesController.cs); [Cinema_Mobile/lib/features/movie/screens/movie_detail_screen.dart](../Cinema_Mobile/lib/features/movie/screens/movie_detail_screen.dart); [Cinema_Mobile/lib/features/admin/screens/admin_movies_screen.dart](../Cinema_Mobile/lib/features/admin/screens/admin_movies_screen.dart); [Cinema_BE/MovieService/MovieService/Service/Impl/MovieService.cs](../Cinema_BE/MovieService/MovieService/Service/Impl/MovieService.cs); [Cinema_BE/BookingService/BookingService/Services/Implementations/MovieReviewService.cs](../Cinema_BE/BookingService/BookingService/Services/Implementations/MovieReviewService.cs) |
| Quy tắc nghiệp vụ | WEB-BR-26 |
| Ca sử dụng / màn / API | UC-WEB-03; WEB-SCR-MOVIE, WEB-SCR-ADMIN-MOVIES; WEB-API-064 |

### WEB-FR-MOV-03 — Tìm theo tên

| Trường | Đặc tả |
| --- | --- |
| Tên | Tìm theo tên |
| Mô tả | Tìm phim theo tên. |
| Tác nhân | Khách chưa đăng nhập/khách hàng xem phim; quản trị viên sửa danh mục và kiểm duyệt |
| Tiền điều kiện | Truy cập được danh mục công khai; phim tồn tại với thao tác chi tiết/trailer. Kết quả tìm rỗng là hợp lệ. |
| Kích hoạt | Thực hiện “Tìm theo tên” hoặc sự kiện/tác vụ backend tương ứng. |
| Luồng chính | 1. Đọc đầu vào/tài nguyên hiện tại và phiên áp dụng. 2. Thực hiện thao tác này: Tìm phim theo tên. 3. Trả/hiển thị kết quả chính thức và làm mới dữ liệu bị tác động sau thành công. |
| Luồng thay thế / ngoại lệ | Hiện trạng thái rỗng khi không có phim/suất phù hợp. Đánh giá bằng vé người khác trả 404; vé chưa check-in trả 400. Media lỗi phải còn ảnh hoặc nội dung dự phòng. |
| Hậu điều kiện | Dữ liệu/trạng thái đủ quyền được trả/hiển thị; đọc không đổi trạng thái vé/thanh toán. Dấu đã đọc thông báo chỉ đổi bằng thao tác ghi riêng. |
| Ưu tiên | M |
| Tiêu chí nghiệm thu | **WEB-FR-MOV-03-AC-01** — Với tiền điều kiện/kích hoạt, kiểm tra: Tìm phim theo tên. **WEB-FR-MOV-03-AC-02** — Thử đầu vào sai/thiếu quyền/xung đột áp dụng và kiểm tra từ chối đã nêu, không đổi dữ liệu trái phép và không báo thành công sai. |
| Bằng chứng | [Cinema_BE/MovieService/MovieService/Controllers/MoviesController.cs](../Cinema_BE/MovieService/MovieService/Controllers/MoviesController.cs); [Cinema_Mobile/lib/features/home/screens/home_screen.dart](../Cinema_Mobile/lib/features/home/screens/home_screen.dart); [Cinema_Mobile/lib/features/admin/screens/admin_movies_screen.dart](../Cinema_Mobile/lib/features/admin/screens/admin_movies_screen.dart); [Cinema_BE/MovieService/MovieService/Service/Impl/MovieService.cs](../Cinema_BE/MovieService/MovieService/Service/Impl/MovieService.cs); [Cinema_BE/BookingService/BookingService/Services/Implementations/MovieReviewService.cs](../Cinema_BE/BookingService/BookingService/Services/Implementations/MovieReviewService.cs) |
| Quy tắc nghiệp vụ | WEB-BR-26 |
| Ca sử dụng / màn / API | UC-WEB-03; WEB-SCR-HOME, WEB-SCR-ADMIN-MOVIES; WEB-API-066, WEB-API-068 |

### WEB-FR-MOV-04 — Danh mục đang hoạt động

| Trường | Đặc tả |
| --- | --- |
| Tên | Danh mục đang hoạt động |
| Mô tả | Lọc phim theo trạng thái; trang chủ app khách chỉ hiện phim `ACTIVE`. |
| Tác nhân | Khách chưa đăng nhập/khách hàng xem phim; quản trị viên sửa danh mục và kiểm duyệt |
| Tiền điều kiện | Truy cập được danh mục công khai; phim tồn tại với thao tác chi tiết/trailer. Kết quả tìm rỗng là hợp lệ. |
| Kích hoạt | Thực hiện “Danh mục đang hoạt động” hoặc sự kiện/tác vụ backend tương ứng. |
| Luồng chính | 1. Đọc đầu vào/tài nguyên hiện tại và phiên áp dụng. 2. Thực hiện thao tác này: Lọc phim theo trạng thái; trang chủ app khách chỉ hiện phim `ACTIVE`. 3. Trả/hiển thị kết quả chính thức và làm mới dữ liệu bị tác động sau thành công. |
| Luồng thay thế / ngoại lệ | Hiện trạng thái rỗng khi không có phim/suất phù hợp. Đánh giá bằng vé người khác trả 404; vé chưa check-in trả 400. Media lỗi phải còn ảnh hoặc nội dung dự phòng. |
| Hậu điều kiện | Dữ liệu/trạng thái đủ quyền được trả/hiển thị; đọc không đổi trạng thái vé/thanh toán. Dấu đã đọc thông báo chỉ đổi bằng thao tác ghi riêng. |
| Ưu tiên | H |
| Tiêu chí nghiệm thu | **WEB-FR-MOV-04-AC-01** — Với tiền điều kiện/kích hoạt, kiểm tra: Lọc phim theo trạng thái; trang chủ app khách chỉ hiện phim `ACTIVE`. **WEB-FR-MOV-04-AC-02** — Thử đầu vào sai/thiếu quyền/xung đột áp dụng và kiểm tra từ chối đã nêu, không đổi dữ liệu trái phép và không báo thành công sai. |
| Bằng chứng | [Cinema_BE/MovieService/MovieService/Controllers/MoviesController.cs](../Cinema_BE/MovieService/MovieService/Controllers/MoviesController.cs); [Cinema_Mobile/lib/features/home/screens/home_screen.dart](../Cinema_Mobile/lib/features/home/screens/home_screen.dart); [Cinema_Mobile/lib/features/admin/screens/admin_movies_screen.dart](../Cinema_Mobile/lib/features/admin/screens/admin_movies_screen.dart); [Cinema_BE/MovieService/MovieService/Service/Impl/MovieService.cs](../Cinema_BE/MovieService/MovieService/Service/Impl/MovieService.cs); [Cinema_BE/BookingService/BookingService/Services/Implementations/MovieReviewService.cs](../Cinema_BE/BookingService/BookingService/Services/Implementations/MovieReviewService.cs) |
| Quy tắc nghiệp vụ | WEB-BR-26 |
| Ca sử dụng / màn / API | UC-WEB-03; WEB-SCR-HOME, WEB-SCR-ADMIN-MOVIES; WEB-API-066, WEB-API-069 |

### WEB-FR-MOV-05 — Tạo phim

| Trường | Đặc tả |
| --- | --- |
| Tên | Tạo phim |
| Mô tả | Admin thêm phim. |
| Tác nhân | Quản trị viên |
| Tiền điều kiện | Có phiên quản trị viên; bản ghi đích tồn tại khi sửa/dừng/điều chỉnh. |
| Kích hoạt | Thực hiện “Tạo phim” hoặc sự kiện/tác vụ backend tương ứng. |
| Luồng chính | 1. Đọc đầu vào/tài nguyên hiện tại và phiên áp dụng. 2. Thực hiện thao tác này: Admin thêm phim. 3. Trả/hiển thị kết quả chính thức và làm mới dữ liệu bị tác động sau thành công. |
| Luồng thay thế / ngoại lệ | Hiện trạng thái rỗng khi không có phim/suất phù hợp. Đánh giá bằng vé người khác trả 404; vé chưa check-in trả 400. Media lỗi phải còn ảnh hoặc nội dung dự phòng. |
| Hậu điều kiện | Kết quả thành công quan sát được khớp yêu cầu này; chuyển trạng thái được chỉ định được lưu. Từ chối không cấp quyền hoặc để thay đổi dở dang trái phép. |
| Ưu tiên | H |
| Tiêu chí nghiệm thu | **WEB-FR-MOV-05-AC-01** — Với tiền điều kiện/kích hoạt, kiểm tra: Admin thêm phim. **WEB-FR-MOV-05-AC-02** — Thử đầu vào sai/thiếu quyền/xung đột áp dụng và kiểm tra từ chối đã nêu, không đổi dữ liệu trái phép và không báo thành công sai. |
| Bằng chứng | [Cinema_BE/MovieService/MovieService/Controllers/MoviesController.cs](../Cinema_BE/MovieService/MovieService/Controllers/MoviesController.cs); [Cinema_Mobile/lib/features/admin/screens/admin_movies_screen.dart](../Cinema_Mobile/lib/features/admin/screens/admin_movies_screen.dart); [Cinema_BE/MovieService/MovieService/Service/Impl/MovieService.cs](../Cinema_BE/MovieService/MovieService/Service/Impl/MovieService.cs); [Cinema_BE/BookingService/BookingService/Services/Implementations/MovieReviewService.cs](../Cinema_BE/BookingService/BookingService/Services/Implementations/MovieReviewService.cs) |
| Quy tắc nghiệp vụ | WEB-BR-26 |
| Ca sử dụng / màn / API | UC-WEB-03; WEB-SCR-ADMIN-MOVIES; WEB-API-071 |

### WEB-FR-MOV-06 — Sửa và chiếu lại phim

| Trường | Đặc tả |
| --- | --- |
| Tên | Sửa và chiếu lại phim |
| Mô tả | Admin sửa phim, kể cả cho phim đã ngừng chiếu chiếu lại (**Show again**). |
| Tác nhân | Quản trị viên |
| Tiền điều kiện | Có phiên quản trị viên; bản ghi đích tồn tại khi sửa/dừng/điều chỉnh. |
| Kích hoạt | Thực hiện “Sửa và chiếu lại phim” hoặc sự kiện/tác vụ backend tương ứng. |
| Luồng chính | 1. Đọc đầu vào/tài nguyên hiện tại và phiên áp dụng. 2. Thực hiện thao tác này: Admin sửa phim, kể cả cho phim đã ngừng chiếu chiếu lại (**Show again**). 3. Trả/hiển thị kết quả chính thức và làm mới dữ liệu bị tác động sau thành công. |
| Luồng thay thế / ngoại lệ | Hiện trạng thái rỗng khi không có phim/suất phù hợp. Đánh giá bằng vé người khác trả 404; vé chưa check-in trả 400. Media lỗi phải còn ảnh hoặc nội dung dự phòng. |
| Hậu điều kiện | Kết quả thành công quan sát được khớp yêu cầu này; chuyển trạng thái được chỉ định được lưu. Từ chối không cấp quyền hoặc để thay đổi dở dang trái phép. |
| Ưu tiên | H |
| Tiêu chí nghiệm thu | **WEB-FR-MOV-06-AC-01** — Với tiền điều kiện/kích hoạt, kiểm tra: Admin sửa phim, kể cả cho phim đã ngừng chiếu chiếu lại (**Show again**). **WEB-FR-MOV-06-AC-02** — Thử đầu vào sai/thiếu quyền/xung đột áp dụng và kiểm tra từ chối đã nêu, không đổi dữ liệu trái phép và không báo thành công sai. |
| Bằng chứng | [Cinema_BE/MovieService/MovieService/Controllers/MoviesController.cs](../Cinema_BE/MovieService/MovieService/Controllers/MoviesController.cs); [Cinema_Mobile/lib/features/admin/screens/admin_movies_screen.dart](../Cinema_Mobile/lib/features/admin/screens/admin_movies_screen.dart); [Cinema_BE/MovieService/MovieService/Service/Impl/MovieService.cs](../Cinema_BE/MovieService/MovieService/Service/Impl/MovieService.cs); [Cinema_BE/BookingService/BookingService/Services/Implementations/MovieReviewService.cs](../Cinema_BE/BookingService/BookingService/Services/Implementations/MovieReviewService.cs) |
| Quy tắc nghiệp vụ | WEB-BR-26 |
| Ca sử dụng / màn / API | UC-WEB-03; WEB-SCR-ADMIN-MOVIES; WEB-API-065 |

### WEB-FR-MOV-07 — Ngừng chiếu phim

| Trường | Đặc tả |
| --- | --- |
| Tên | Ngừng chiếu phim |
| Mô tả | Admin ngừng chiếu (**Stop showing**): phim chuyển `INACTIVE`, ẩn khỏi app khách, dữ liệu và vé cũ giữ nguyên. |
| Tác nhân | Quản trị viên |
| Tiền điều kiện | Có phiên quản trị viên; bản ghi đích tồn tại khi sửa/dừng/điều chỉnh. |
| Kích hoạt | Thực hiện “Ngừng chiếu phim” hoặc sự kiện/tác vụ backend tương ứng. |
| Luồng chính | 1. Đọc đầu vào/tài nguyên hiện tại và phiên áp dụng. 2. Thực hiện thao tác này: Admin ngừng chiếu (**Stop showing**): phim chuyển `INACTIVE`, ẩn khỏi app khách, dữ liệu và vé cũ giữ nguyên. 3. Trả/hiển thị kết quả chính thức và làm mới dữ liệu bị tác động sau thành công. |
| Luồng thay thế / ngoại lệ | Hiện trạng thái rỗng khi không có phim/suất phù hợp. Đánh giá bằng vé người khác trả 404; vé chưa check-in trả 400. Media lỗi phải còn ảnh hoặc nội dung dự phòng. |
| Hậu điều kiện | Kết quả thành công quan sát được khớp yêu cầu này; chuyển trạng thái được chỉ định được lưu. Từ chối không cấp quyền hoặc để thay đổi dở dang trái phép. |
| Ưu tiên | H |
| Tiêu chí nghiệm thu | **WEB-FR-MOV-07-AC-01** — Với tiền điều kiện/kích hoạt, kiểm tra: Admin ngừng chiếu (**Stop showing**): phim chuyển `INACTIVE`, ẩn khỏi app khách, dữ liệu và vé cũ giữ nguyên. **WEB-FR-MOV-07-AC-02** — Thử đầu vào sai/thiếu quyền/xung đột áp dụng và kiểm tra từ chối đã nêu, không đổi dữ liệu trái phép và không báo thành công sai. |
| Bằng chứng | [Cinema_BE/MovieService/MovieService/Controllers/MoviesController.cs](../Cinema_BE/MovieService/MovieService/Controllers/MoviesController.cs); [Cinema_Mobile/lib/features/admin/screens/admin_movies_screen.dart](../Cinema_Mobile/lib/features/admin/screens/admin_movies_screen.dart); [Cinema_BE/MovieService/MovieService/Service/Impl/MovieService.cs](../Cinema_BE/MovieService/MovieService/Service/Impl/MovieService.cs); [Cinema_BE/BookingService/BookingService/Services/Implementations/MovieReviewService.cs](../Cinema_BE/BookingService/BookingService/Services/Implementations/MovieReviewService.cs) |
| Quy tắc nghiệp vụ | WEB-BR-26 |
| Ca sử dụng / màn / API | UC-WEB-03; WEB-SCR-ADMIN-MOVIES; WEB-API-063 |

### WEB-FR-MOV-08 — Mở trailer

| Trường | Đặc tả |
| --- | --- |
| Tên | Mở trailer |
| Mô tả | App khách mở trailer của phim (`trailerUrl`). |
| Tác nhân | Khách chưa đăng nhập/khách hàng xem phim; quản trị viên sửa danh mục và kiểm duyệt |
| Tiền điều kiện | Truy cập được danh mục công khai; phim tồn tại với thao tác chi tiết/trailer. Kết quả tìm rỗng là hợp lệ. |
| Kích hoạt | Thực hiện “Mở trailer” hoặc sự kiện/tác vụ backend tương ứng. |
| Luồng chính | 1. Đọc đầu vào/tài nguyên hiện tại và phiên áp dụng. 2. Thực hiện thao tác này: App khách mở trailer của phim (`trailerUrl`). 3. Trả/hiển thị kết quả chính thức và làm mới dữ liệu bị tác động sau thành công. |
| Luồng thay thế / ngoại lệ | Hiện trạng thái rỗng khi không có phim/suất phù hợp. Đánh giá bằng vé người khác trả 404; vé chưa check-in trả 400. Media lỗi phải còn ảnh hoặc nội dung dự phòng. |
| Hậu điều kiện | Dữ liệu/trạng thái đủ quyền được trả/hiển thị; đọc không đổi trạng thái vé/thanh toán. Dấu đã đọc thông báo chỉ đổi bằng thao tác ghi riêng. |
| Ưu tiên | L |
| Tiêu chí nghiệm thu | **WEB-FR-MOV-08-AC-01** — Với tiền điều kiện/kích hoạt, kiểm tra: App khách mở trailer của phim (`trailerUrl`). **WEB-FR-MOV-08-AC-02** — Thử đầu vào sai/thiếu quyền/xung đột áp dụng và kiểm tra từ chối đã nêu, không đổi dữ liệu trái phép và không báo thành công sai. |
| Bằng chứng | [Cinema_BE/MovieService/MovieService/Controllers/MoviesController.cs](../Cinema_BE/MovieService/MovieService/Controllers/MoviesController.cs); [Cinema_Mobile/lib/features/movie/screens/movie_detail_screen.dart](../Cinema_Mobile/lib/features/movie/screens/movie_detail_screen.dart); [Cinema_BE/MovieService/MovieService/Service/Impl/MovieService.cs](../Cinema_BE/MovieService/MovieService/Service/Impl/MovieService.cs); [Cinema_BE/BookingService/BookingService/Services/Implementations/MovieReviewService.cs](../Cinema_BE/BookingService/BookingService/Services/Implementations/MovieReviewService.cs) |
| Quy tắc nghiệp vụ | WEB-BR-26 |
| Ca sử dụng / màn / API | UC-WEB-03; WEB-SCR-MOVIE; WEB-API-064 |

### WEB-FR-MOV-09 — Phân loại tuổi

| Trường | Đặc tả |
| --- | --- |
| Tên | Phân loại tuổi |
| Mô tả | Hỗ trợ phân loại P, K, T13, T16 và T18. Quản trị viên chọn loại (mặc định P); thẻ phim, chi tiết, xác nhận đặt vé, quầy và check-in hiển thị loại tuổi. Trước khi giữ ghế phim khác P, khách xác nhận điều kiện tuổi; nhân viên được nhắc kiểm tra danh tính khi vào rạp. Đây là đặc tả nhãn đã triển khai, không phải chứng nhận tuân thủ pháp luật. |
| Tác nhân | Khách chưa đăng nhập/khách hàng xem phim; quản trị viên sửa danh mục và kiểm duyệt |
| Tiền điều kiện | Có dữ liệu phim; cập nhật cần quản trị viên; đánh giá cần vé của chính khách đã được check-in. |
| Kích hoạt | Thực hiện “Phân loại tuổi” hoặc sự kiện/tác vụ backend tương ứng. |
| Luồng chính | 1. Đọc đầu vào/tài nguyên hiện tại và phiên áp dụng. 2. Thực hiện thao tác này: Hỗ trợ phân loại P, K, T13, T16 và T18. Quản trị viên chọn loại (mặc định P); thẻ phim, chi tiết, xác nhận đặt vé, quầy và check-in hiển thị loại tuổi. Trước khi giữ ghế phim khác P, khách xác nhận điều kiện tuổi; nhân viên được nhắc kiểm tra danh tính khi vào rạp. Đây là đặc tả nhãn đã triển khai, không phải chứng nhận tuân thủ pháp luật. 3. Trả/hiển thị kết quả chính thức và làm mới dữ liệu bị tác động sau thành công. |
| Luồng thay thế / ngoại lệ | Hiện trạng thái rỗng khi không có phim/suất phù hợp. Đánh giá bằng vé người khác trả 404; vé chưa check-in trả 400. Media lỗi phải còn ảnh hoặc nội dung dự phòng. |
| Hậu điều kiện | Kết quả thành công quan sát được khớp yêu cầu này; chuyển trạng thái được chỉ định được lưu. Từ chối không cấp quyền hoặc để thay đổi dở dang trái phép. |
| Ưu tiên | H |
| Tiêu chí nghiệm thu | **WEB-FR-MOV-09-AC-01** — Với tiền điều kiện/kích hoạt, kiểm tra: Hỗ trợ phân loại P, K, T13, T16 và T18. Quản trị viên chọn loại (mặc định P); thẻ phim, chi tiết, xác nhận đặt vé, quầy và check-in hiển thị loại tuổi. Trước khi giữ ghế phim khác P, khách xác nhận điều kiện tuổi; nhân viên được nhắc kiểm tra danh tính khi vào rạp. Đây là đặc tả nhãn đã triển khai, không phải chứng nhận tuân thủ pháp luật. **WEB-FR-MOV-09-AC-02** — Thử đầu vào sai/thiếu quyền/xung đột áp dụng và kiểm tra từ chối đã nêu, không đổi dữ liệu trái phép và không báo thành công sai. |
| Bằng chứng | [Cinema_BE/MovieService/MovieService/Controllers/MoviesController.cs](../Cinema_BE/MovieService/MovieService/Controllers/MoviesController.cs); [Cinema_Mobile/lib/features/movie/screens/movie_detail_screen.dart](../Cinema_Mobile/lib/features/movie/screens/movie_detail_screen.dart); [Cinema_Mobile/lib/features/booking/screens/booking_summary_screen.dart](../Cinema_Mobile/lib/features/booking/screens/booking_summary_screen.dart); [Cinema_Mobile/lib/features/staff/screens/staff_check_in_screen.dart](../Cinema_Mobile/lib/features/staff/screens/staff_check_in_screen.dart); [Cinema_Mobile/lib/features/admin/screens/admin_movies_screen.dart](../Cinema_Mobile/lib/features/admin/screens/admin_movies_screen.dart); [Cinema_BE/MovieService/MovieService/Service/Impl/MovieService.cs](../Cinema_BE/MovieService/MovieService/Service/Impl/MovieService.cs); [Cinema_BE/BookingService/BookingService/Services/Implementations/MovieReviewService.cs](../Cinema_BE/BookingService/BookingService/Services/Implementations/MovieReviewService.cs) |
| Quy tắc nghiệp vụ | WEB-BR-26 |
| Ca sử dụng / màn / API | UC-WEB-03; WEB-SCR-MOVIE, WEB-SCR-SUMMARY, WEB-SCR-CHECKIN, WEB-SCR-ADMIN-MOVIES; WEB-API-064, WEB-API-065, WEB-API-071 |

### WEB-FR-MOV-10 — Đang chiếu và sắp chiếu

| Trường | Đặc tả |
| --- | --- |
| Tên | Đang chiếu và sắp chiếu |
| Mô tả | Trang chủ của khách có hai tab **Đang chiếu** (phim ACTIVE đã khởi chiếu hoặc chưa có ngày khởi chiếu, mới thêm trước) và **Sắp chiếu** (phim ACTIVE có ngày khởi chiếu sau hôm nay, khởi chiếu sớm nhất trước, poster ghi ngày khởi chiếu). Lọc theo thể loại (chip lấy từ thể loại của các phim đang có) và tìm theo tên qua API, không phân biệt hoa thường. Chi tiết phim sắp chiếu ghi ngày khởi chiếu; chưa có suất thì báo suất chiếu sẽ được thêm gần ngày khởi chiếu. |
| Tác nhân | Khách chưa đăng nhập/khách hàng xem phim; quản trị viên sửa danh mục và kiểm duyệt |
| Tiền điều kiện | Truy cập được danh mục công khai; phim tồn tại với thao tác chi tiết/trailer. Kết quả tìm rỗng là hợp lệ. |
| Kích hoạt | Thực hiện “Đang chiếu và sắp chiếu” hoặc sự kiện/tác vụ backend tương ứng. |
| Luồng chính | 1. Đọc đầu vào/tài nguyên hiện tại và phiên áp dụng. 2. Thực hiện thao tác này: Trang chủ của khách có hai tab **Đang chiếu** (phim ACTIVE đã khởi chiếu hoặc chưa có ngày khởi chiếu, mới thêm trước) và **Sắp chiếu** (phim ACTIVE có ngày khởi chiếu sau hôm nay, khởi chiếu sớm nhất trước, poster ghi ngày khởi chiếu). Lọc theo thể loại (chip lấy từ thể loại của các phim đang có) và tìm theo tên qua API, không phân biệt hoa thường. Chi tiết phim sắp chiếu ghi ngày khởi chiếu; chưa có suất thì báo suất chiếu sẽ được thêm gần ngày khởi chiếu. 3. Trả/hiển thị kết quả chính thức và làm mới dữ liệu bị tác động sau thành công. |
| Luồng thay thế / ngoại lệ | Hiện trạng thái rỗng khi không có phim/suất phù hợp. Đánh giá bằng vé người khác trả 404; vé chưa check-in trả 400. Media lỗi phải còn ảnh hoặc nội dung dự phòng. |
| Hậu điều kiện | Dữ liệu/trạng thái đủ quyền được trả/hiển thị; đọc không đổi trạng thái vé/thanh toán. Dấu đã đọc thông báo chỉ đổi bằng thao tác ghi riêng. |
| Ưu tiên | M |
| Tiêu chí nghiệm thu | **WEB-FR-MOV-10-AC-01** — Với tiền điều kiện/kích hoạt, kiểm tra: Trang chủ của khách có hai tab **Đang chiếu** (phim ACTIVE đã khởi chiếu hoặc chưa có ngày khởi chiếu, mới thêm trước) và **Sắp chiếu** (phim ACTIVE có ngày khởi chiếu sau hôm nay, khởi chiếu sớm nhất trước, poster ghi ngày khởi chiếu). Lọc theo thể loại (chip lấy từ thể loại của các phim đang có) và tìm theo tên qua API, không phân biệt hoa thường. Chi tiết phim sắp chiếu ghi ngày khởi chiếu; chưa có suất thì báo suất chiếu sẽ được thêm gần ngày khởi chiếu. **WEB-FR-MOV-10-AC-02** — Thử đầu vào sai/thiếu quyền/xung đột áp dụng và kiểm tra từ chối đã nêu, không đổi dữ liệu trái phép và không báo thành công sai. |
| Bằng chứng | [Cinema_BE/MovieService/MovieService/Controllers/MoviesController.cs](../Cinema_BE/MovieService/MovieService/Controllers/MoviesController.cs); [Cinema_Mobile/lib/features/home/screens/home_screen.dart](../Cinema_Mobile/lib/features/home/screens/home_screen.dart); [Cinema_BE/MovieService/MovieService/Service/Impl/MovieService.cs](../Cinema_BE/MovieService/MovieService/Service/Impl/MovieService.cs); [Cinema_BE/BookingService/BookingService/Services/Implementations/MovieReviewService.cs](../Cinema_BE/BookingService/BookingService/Services/Implementations/MovieReviewService.cs) |
| Quy tắc nghiệp vụ | WEB-BR-26 |
| Ca sử dụng / màn / API | UC-WEB-03; WEB-SCR-HOME; WEB-API-066, WEB-API-067 |

### WEB-FR-MOV-11 — Đạo diễn và diễn viên

| Trường | Đặc tả |
| --- | --- |
| Tên | Đạo diễn và diễn viên |
| Mô tả | Phim có **đạo diễn** và **diễn viên chính** (không bắt buộc, tối đa 150 / 500 ký tự). Admin nhập khi thêm / sửa phim; chi tiết phim hiện ra. |
| Tác nhân | Khách chưa đăng nhập/khách hàng xem phim; quản trị viên sửa danh mục và kiểm duyệt |
| Tiền điều kiện | Truy cập được danh mục công khai; phim tồn tại với thao tác chi tiết/trailer. Kết quả tìm rỗng là hợp lệ. |
| Kích hoạt | Thực hiện “Đạo diễn và diễn viên” hoặc sự kiện/tác vụ backend tương ứng. |
| Luồng chính | 1. Đọc đầu vào/tài nguyên hiện tại và phiên áp dụng. 2. Thực hiện thao tác này: Phim có **đạo diễn** và **diễn viên chính** (không bắt buộc, tối đa 150 / 500 ký tự). Admin nhập khi thêm / sửa phim; chi tiết phim hiện ra. 3. Trả/hiển thị kết quả chính thức và làm mới dữ liệu bị tác động sau thành công. |
| Luồng thay thế / ngoại lệ | Hiện trạng thái rỗng khi không có phim/suất phù hợp. Đánh giá bằng vé người khác trả 404; vé chưa check-in trả 400. Media lỗi phải còn ảnh hoặc nội dung dự phòng. |
| Hậu điều kiện | Kết quả thành công quan sát được khớp yêu cầu này; chuyển trạng thái được chỉ định được lưu. Từ chối không cấp quyền hoặc để thay đổi dở dang trái phép. |
| Ưu tiên | L |
| Tiêu chí nghiệm thu | **WEB-FR-MOV-11-AC-01** — Với tiền điều kiện/kích hoạt, kiểm tra: Phim có **đạo diễn** và **diễn viên chính** (không bắt buộc, tối đa 150 / 500 ký tự). Admin nhập khi thêm / sửa phim; chi tiết phim hiện ra. **WEB-FR-MOV-11-AC-02** — Thử đầu vào sai/thiếu quyền/xung đột áp dụng và kiểm tra từ chối đã nêu, không đổi dữ liệu trái phép và không báo thành công sai. |
| Bằng chứng | [Cinema_BE/MovieService/MovieService/Controllers/MoviesController.cs](../Cinema_BE/MovieService/MovieService/Controllers/MoviesController.cs); [Cinema_Mobile/lib/features/movie/screens/movie_detail_screen.dart](../Cinema_Mobile/lib/features/movie/screens/movie_detail_screen.dart); [Cinema_Mobile/lib/features/admin/screens/admin_movies_screen.dart](../Cinema_Mobile/lib/features/admin/screens/admin_movies_screen.dart); [Cinema_BE/MovieService/MovieService/Service/Impl/MovieService.cs](../Cinema_BE/MovieService/MovieService/Service/Impl/MovieService.cs); [Cinema_BE/BookingService/BookingService/Services/Implementations/MovieReviewService.cs](../Cinema_BE/BookingService/BookingService/Services/Implementations/MovieReviewService.cs) |
| Quy tắc nghiệp vụ | WEB-BR-26 |
| Ca sử dụng / màn / API | UC-WEB-03; WEB-SCR-MOVIE, WEB-SCR-ADMIN-MOVIES; WEB-API-064, WEB-API-065, WEB-API-071 |

### WEB-FR-MOV-12 — Đánh giá phim

| Trường | Đặc tả |
| --- | --- |
| Tên | Đánh giá phim |
| Mô tả | **Đánh giá phim**: khách có vé đã check-in (đã xem phim) chấm 1–5 sao kèm bình luận (tối đa 1.000 ký tự) ngay trên chi tiết vé. Mỗi khách một đánh giá cho một phim: gửi lại là sửa, xoá được. Vé chưa check-in thì bị 400 kèm lý do; vé của người khác như không tồn tại (404). Chi tiết phim hiện cho mọi người điểm trung bình, số đánh giá theo từng mức sao và các đánh giá mới nhất; tên người đánh giá lấy họ tên trong tài khoản (không có thì email đã che bớt). Admin xoá đánh giá không phù hợp từ Admin → Movies → Reviews. |
| Tác nhân | Khách chưa đăng nhập/khách hàng xem phim; quản trị viên sửa danh mục và kiểm duyệt |
| Tiền điều kiện | Có dữ liệu phim; cập nhật cần quản trị viên; đánh giá cần vé của chính khách đã được check-in. |
| Kích hoạt | Thực hiện “Đánh giá phim” hoặc sự kiện/tác vụ backend tương ứng. |
| Luồng chính | 1. Đọc đầu vào/tài nguyên hiện tại và phiên áp dụng. 2. Thực hiện thao tác này: **Đánh giá phim**: khách có vé đã check-in (đã xem phim) chấm 1–5 sao kèm bình luận (tối đa 1.000 ký tự) ngay trên chi tiết vé. Mỗi khách một đánh giá cho một phim: gửi lại là sửa, xoá được. Vé chưa check-in thì bị 400 kèm lý do; vé của người khác như không tồn tại (404). Chi tiết phim hiện cho mọi người điểm trung bình, số đánh giá theo từng mức sao và các đánh giá mới nhất; tên người đánh giá lấy họ tên trong tài khoản (không có thì email đã che bớt). Admin xoá đánh giá không phù hợp từ Admin → Movies → Reviews. 3. Trả/hiển thị kết quả chính thức và làm mới dữ liệu bị tác động sau thành công. |
| Luồng thay thế / ngoại lệ | Hiện trạng thái rỗng khi không có phim/suất phù hợp. Đánh giá bằng vé người khác trả 404; vé chưa check-in trả 400. Media lỗi phải còn ảnh hoặc nội dung dự phòng. |
| Hậu điều kiện | Kết quả thành công quan sát được khớp yêu cầu này; chuyển trạng thái được chỉ định được lưu. Từ chối không cấp quyền hoặc để thay đổi dở dang trái phép. |
| Ưu tiên | M |
| Tiêu chí nghiệm thu | **WEB-FR-MOV-12-AC-01** — Với tiền điều kiện/kích hoạt, kiểm tra: **Đánh giá phim**: khách có vé đã check-in (đã xem phim) chấm 1–5 sao kèm bình luận (tối đa 1.000 ký tự) ngay trên chi tiết vé. Mỗi khách một đánh giá cho một phim: gửi lại là sửa, xoá được. Vé chưa check-in thì bị 400 kèm lý do; vé của người khác như không tồn tại (404). Chi tiết phim hiện cho mọi người điểm trung bình, số đánh giá theo từng mức sao và các đánh giá mới nhất; tên người đánh giá lấy họ tên trong tài khoản (không có thì email đã che bớt). Admin xoá đánh giá không phù hợp từ Admin → Movies → Reviews. **WEB-FR-MOV-12-AC-02** — Thử đầu vào sai/thiếu quyền/xung đột áp dụng và kiểm tra từ chối đã nêu, không đổi dữ liệu trái phép và không báo thành công sai. |
| Bằng chứng | [Cinema_BE/BookingService/BookingService/Controllers/MovieReviewController.cs](../Cinema_BE/BookingService/BookingService/Controllers/MovieReviewController.cs); [Cinema_Mobile/lib/features/movie/screens/movie_detail_screen.dart](../Cinema_Mobile/lib/features/movie/screens/movie_detail_screen.dart); [Cinema_Mobile/lib/features/booking/screens/booking_detail_screen.dart](../Cinema_Mobile/lib/features/booking/screens/booking_detail_screen.dart); [Cinema_Mobile/lib/features/admin/screens/admin_movies_screen.dart](../Cinema_Mobile/lib/features/admin/screens/admin_movies_screen.dart); [Cinema_BE/MovieService/MovieService/Service/Impl/MovieService.cs](../Cinema_BE/MovieService/MovieService/Service/Impl/MovieService.cs); [Cinema_BE/BookingService/BookingService/Services/Implementations/MovieReviewService.cs](../Cinema_BE/BookingService/BookingService/Services/Implementations/MovieReviewService.cs) |
| Quy tắc nghiệp vụ | WEB-BR-26 |
| Ca sử dụng / màn / API | UC-WEB-03; WEB-SCR-MOVIE, WEB-SCR-TICKET, WEB-SCR-ADMIN-MOVIES; WEB-API-102, WEB-API-103, WEB-API-105, WEB-API-106 |

### WEB-FR-ROOM-01 — Tìm phòng

| Trường | Đặc tả |
| --- | --- |
| Tên | Tìm phòng |
| Mô tả | Danh sách và tìm phòng theo tên (Staff/Admin). |
| Tác nhân | Nhân viên/quản trị viên xem; quản trị viên cập nhật |
| Tiền điều kiện | Phiên quản lý đang hoạt động; thay đổi sơ đồ cần phòng không có suất chiếu. |
| Kích hoạt | Thực hiện “Tìm phòng” hoặc sự kiện/tác vụ backend tương ứng. |
| Luồng chính | 1. Đọc đầu vào/tài nguyên hiện tại và phiên áp dụng. 2. Thực hiện thao tác này: Danh sách và tìm phòng theo tên (Staff/Admin). 3. Trả/hiển thị kết quả chính thức và làm mới dữ liệu bị tác động sau thành công. |
| Luồng thay thế / ngoại lệ | Từ chối sức chứa sai, phòng không tồn tại, thiếu quyền và xoá/đổi sơ đồ khi đã có suất chiếu tham chiếu. Tạo phòng và sinh ghế là hai lời gọi HTTP riêng; phải báo lỗi nếu lời gọi thứ hai thất bại. |
| Hậu điều kiện | Dữ liệu/trạng thái đủ quyền được trả/hiển thị; đọc không đổi trạng thái vé/thanh toán. Dấu đã đọc thông báo chỉ đổi bằng thao tác ghi riêng. |
| Ưu tiên | H |
| Tiêu chí nghiệm thu | **WEB-FR-ROOM-01-AC-01** — Với tiền điều kiện/kích hoạt, kiểm tra: Danh sách và tìm phòng theo tên (Staff/Admin). **WEB-FR-ROOM-01-AC-02** — Thử đầu vào sai/thiếu quyền/xung đột áp dụng và kiểm tra từ chối đã nêu, không đổi dữ liệu trái phép và không báo thành công sai. |
| Bằng chứng | [Cinema_BE/MovieService/MovieService/Controllers/RoomsController.cs](../Cinema_BE/MovieService/MovieService/Controllers/RoomsController.cs); [Cinema_Mobile/lib/features/staff/screens/staff_operations_screen.dart](../Cinema_Mobile/lib/features/staff/screens/staff_operations_screen.dart); [Cinema_Mobile/lib/features/admin/screens/admin_rooms_screen.dart](../Cinema_Mobile/lib/features/admin/screens/admin_rooms_screen.dart); [Cinema_BE/MovieService/MovieService/Service/Impl/RoomService.cs](../Cinema_BE/MovieService/MovieService/Service/Impl/RoomService.cs) |
| Quy tắc nghiệp vụ | WEB-BR-04, WEB-BR-26 |
| Ca sử dụng / màn / API | UC-WEB-04; WEB-SCR-OPERATIONS, WEB-SCR-ADMIN-ROOMS; WEB-API-004, WEB-API-005 |

### WEB-FR-ROOM-02 — Chi tiết phòng

| Trường | Đặc tả |
| --- | --- |
| Tên | Chi tiết phòng |
| Mô tả | Chi tiết phòng kèm sơ đồ ghế theo hàng, màu theo loại ghế. |
| Tác nhân | Nhân viên/quản trị viên xem; quản trị viên cập nhật |
| Tiền điều kiện | Phiên quản lý đang hoạt động; thay đổi sơ đồ cần phòng không có suất chiếu. |
| Kích hoạt | Thực hiện “Chi tiết phòng” hoặc sự kiện/tác vụ backend tương ứng. |
| Luồng chính | 1. Đọc đầu vào/tài nguyên hiện tại và phiên áp dụng. 2. Thực hiện thao tác này: Chi tiết phòng kèm sơ đồ ghế theo hàng, màu theo loại ghế. 3. Trả/hiển thị kết quả chính thức và làm mới dữ liệu bị tác động sau thành công. |
| Luồng thay thế / ngoại lệ | Từ chối sức chứa sai, phòng không tồn tại, thiếu quyền và xoá/đổi sơ đồ khi đã có suất chiếu tham chiếu. Tạo phòng và sinh ghế là hai lời gọi HTTP riêng; phải báo lỗi nếu lời gọi thứ hai thất bại. |
| Hậu điều kiện | Dữ liệu/trạng thái đủ quyền được trả/hiển thị; đọc không đổi trạng thái vé/thanh toán. Dấu đã đọc thông báo chỉ đổi bằng thao tác ghi riêng. |
| Ưu tiên | H |
| Tiêu chí nghiệm thu | **WEB-FR-ROOM-02-AC-01** — Với tiền điều kiện/kích hoạt, kiểm tra: Chi tiết phòng kèm sơ đồ ghế theo hàng, màu theo loại ghế. **WEB-FR-ROOM-02-AC-02** — Thử đầu vào sai/thiếu quyền/xung đột áp dụng và kiểm tra từ chối đã nêu, không đổi dữ liệu trái phép và không báo thành công sai. |
| Bằng chứng | [Cinema_BE/MovieService/MovieService/Controllers/RoomsController.cs](../Cinema_BE/MovieService/MovieService/Controllers/RoomsController.cs); [Cinema_BE/MovieService/MovieService/Controllers/SeatsController.cs](../Cinema_BE/MovieService/MovieService/Controllers/SeatsController.cs); [Cinema_Mobile/lib/features/staff/screens/staff_record_screen.dart](../Cinema_Mobile/lib/features/staff/screens/staff_record_screen.dart); [Cinema_Mobile/lib/features/admin/screens/admin_rooms_screen.dart](../Cinema_Mobile/lib/features/admin/screens/admin_rooms_screen.dart); [Cinema_BE/MovieService/MovieService/Service/Impl/RoomService.cs](../Cinema_BE/MovieService/MovieService/Service/Impl/RoomService.cs) |
| Quy tắc nghiệp vụ | WEB-BR-04, WEB-BR-26 |
| Ca sử dụng / màn / API | UC-WEB-04; WEB-SCR-RECORD-ROOMS, WEB-SCR-ADMIN-ROOMS; WEB-API-002, WEB-API-013 |

### WEB-FR-ROOM-03 — Tạo phòng và ghế

| Trường | Đặc tả |
| --- | --- |
| Tên | Tạo phòng và ghế |
| Mô tả | Admin tạo phòng bằng số hàng × số ghế mỗi hàng; ghế được tạo luôn. |
| Tác nhân | Nhân viên/quản trị viên xem; quản trị viên cập nhật |
| Tiền điều kiện | Phiên quản lý đang hoạt động; thay đổi sơ đồ cần phòng không có suất chiếu. |
| Kích hoạt | Thực hiện “Tạo phòng và ghế” hoặc sự kiện/tác vụ backend tương ứng. |
| Luồng chính | 1. Đọc đầu vào/tài nguyên hiện tại và phiên áp dụng. 2. Thực hiện thao tác này: Admin tạo phòng bằng số hàng × số ghế mỗi hàng; ghế được tạo luôn. 3. Trả/hiển thị kết quả chính thức và làm mới dữ liệu bị tác động sau thành công. |
| Luồng thay thế / ngoại lệ | Từ chối sức chứa sai, phòng không tồn tại, thiếu quyền và xoá/đổi sơ đồ khi đã có suất chiếu tham chiếu. Tạo phòng và sinh ghế là hai lời gọi HTTP riêng; phải báo lỗi nếu lời gọi thứ hai thất bại. |
| Hậu điều kiện | Kết quả thành công quan sát được khớp yêu cầu này; chuyển trạng thái được chỉ định được lưu. Từ chối không cấp quyền hoặc để thay đổi dở dang trái phép. |
| Ưu tiên | H |
| Tiêu chí nghiệm thu | **WEB-FR-ROOM-03-AC-01** — Với tiền điều kiện/kích hoạt, kiểm tra: Admin tạo phòng bằng số hàng × số ghế mỗi hàng; ghế được tạo luôn. **WEB-FR-ROOM-03-AC-02** — Thử đầu vào sai/thiếu quyền/xung đột áp dụng và kiểm tra từ chối đã nêu, không đổi dữ liệu trái phép và không báo thành công sai. |
| Bằng chứng | [Cinema_BE/MovieService/MovieService/Controllers/RoomsController.cs](../Cinema_BE/MovieService/MovieService/Controllers/RoomsController.cs); [Cinema_BE/MovieService/MovieService/Controllers/SeatsController.cs](../Cinema_BE/MovieService/MovieService/Controllers/SeatsController.cs); [Cinema_Mobile/lib/features/admin/screens/admin_rooms_screen.dart](../Cinema_Mobile/lib/features/admin/screens/admin_rooms_screen.dart); [Cinema_BE/MovieService/MovieService/Service/Impl/RoomService.cs](../Cinema_BE/MovieService/MovieService/Service/Impl/RoomService.cs) |
| Quy tắc nghiệp vụ | WEB-BR-04, WEB-BR-26 |
| Ca sử dụng / màn / API | UC-WEB-04; WEB-SCR-ADMIN-ROOMS; WEB-API-006, WEB-API-010 |

### WEB-FR-ROOM-04 — Đổi tên phòng

| Trường | Đặc tả |
| --- | --- |
| Tên | Đổi tên phòng |
| Mô tả | Admin đổi tên phòng, giữ nguyên ghế. |
| Tác nhân | Nhân viên/quản trị viên xem; quản trị viên cập nhật |
| Tiền điều kiện | Phiên quản lý đang hoạt động; thay đổi sơ đồ cần phòng không có suất chiếu. |
| Kích hoạt | Thực hiện “Đổi tên phòng” hoặc sự kiện/tác vụ backend tương ứng. |
| Luồng chính | 1. Đọc đầu vào/tài nguyên hiện tại và phiên áp dụng. 2. Thực hiện thao tác này: Admin đổi tên phòng, giữ nguyên ghế. 3. Trả/hiển thị kết quả chính thức và làm mới dữ liệu bị tác động sau thành công. |
| Luồng thay thế / ngoại lệ | Từ chối sức chứa sai, phòng không tồn tại, thiếu quyền và xoá/đổi sơ đồ khi đã có suất chiếu tham chiếu. Tạo phòng và sinh ghế là hai lời gọi HTTP riêng; phải báo lỗi nếu lời gọi thứ hai thất bại. |
| Hậu điều kiện | Kết quả thành công quan sát được khớp yêu cầu này; chuyển trạng thái được chỉ định được lưu. Từ chối không cấp quyền hoặc để thay đổi dở dang trái phép. |
| Ưu tiên | M |
| Tiêu chí nghiệm thu | **WEB-FR-ROOM-04-AC-01** — Với tiền điều kiện/kích hoạt, kiểm tra: Admin đổi tên phòng, giữ nguyên ghế. **WEB-FR-ROOM-04-AC-02** — Thử đầu vào sai/thiếu quyền/xung đột áp dụng và kiểm tra từ chối đã nêu, không đổi dữ liệu trái phép và không báo thành công sai. |
| Bằng chứng | [Cinema_BE/MovieService/MovieService/Controllers/RoomsController.cs](../Cinema_BE/MovieService/MovieService/Controllers/RoomsController.cs); [Cinema_Mobile/lib/features/admin/screens/admin_rooms_screen.dart](../Cinema_Mobile/lib/features/admin/screens/admin_rooms_screen.dart); [Cinema_BE/MovieService/MovieService/Service/Impl/RoomService.cs](../Cinema_BE/MovieService/MovieService/Service/Impl/RoomService.cs) |
| Quy tắc nghiệp vụ | WEB-BR-04, WEB-BR-26 |
| Ca sử dụng / màn / API | UC-WEB-04; WEB-SCR-ADMIN-ROOMS; WEB-API-003 |

### WEB-FR-ROOM-05 — Xoá phòng đủ điều kiện

| Trường | Đặc tả |
| --- | --- |
| Tên | Xoá phòng đủ điều kiện |
| Mô tả | Admin xoá phòng chưa có suất chiếu (xoá cả ghế); phòng đã có suất chiếu bị từ chối. |
| Tác nhân | Nhân viên/quản trị viên xem; quản trị viên cập nhật |
| Tiền điều kiện | Phiên quản lý đang hoạt động; thay đổi sơ đồ cần phòng không có suất chiếu. |
| Kích hoạt | Thực hiện “Xoá phòng đủ điều kiện” hoặc sự kiện/tác vụ backend tương ứng. |
| Luồng chính | 1. Đọc đầu vào/tài nguyên hiện tại và phiên áp dụng. 2. Thực hiện thao tác này: Admin xoá phòng chưa có suất chiếu (xoá cả ghế); phòng đã có suất chiếu bị từ chối. 3. Trả/hiển thị kết quả chính thức và làm mới dữ liệu bị tác động sau thành công. |
| Luồng thay thế / ngoại lệ | Từ chối sức chứa sai, phòng không tồn tại, thiếu quyền và xoá/đổi sơ đồ khi đã có suất chiếu tham chiếu. Tạo phòng và sinh ghế là hai lời gọi HTTP riêng; phải báo lỗi nếu lời gọi thứ hai thất bại. |
| Hậu điều kiện | Kết quả thành công quan sát được khớp yêu cầu này; chuyển trạng thái được chỉ định được lưu. Từ chối không cấp quyền hoặc để thay đổi dở dang trái phép. |
| Ưu tiên | M |
| Tiêu chí nghiệm thu | **WEB-FR-ROOM-05-AC-01** — Với tiền điều kiện/kích hoạt, kiểm tra: Admin xoá phòng chưa có suất chiếu (xoá cả ghế); phòng đã có suất chiếu bị từ chối. **WEB-FR-ROOM-05-AC-02** — Thử đầu vào sai/thiếu quyền/xung đột áp dụng và kiểm tra từ chối đã nêu, không đổi dữ liệu trái phép và không báo thành công sai. |
| Bằng chứng | [Cinema_BE/MovieService/MovieService/Controllers/RoomsController.cs](../Cinema_BE/MovieService/MovieService/Controllers/RoomsController.cs); [Cinema_Mobile/lib/features/admin/screens/admin_rooms_screen.dart](../Cinema_Mobile/lib/features/admin/screens/admin_rooms_screen.dart); [Cinema_BE/MovieService/MovieService/Service/Impl/RoomService.cs](../Cinema_BE/MovieService/MovieService/Service/Impl/RoomService.cs) |
| Quy tắc nghiệp vụ | WEB-BR-04, WEB-BR-26 |
| Ca sử dụng / màn / API | UC-WEB-04; WEB-SCR-ADMIN-ROOMS; WEB-API-001 |

### WEB-FR-SEAT-01 — Sinh ghế

| Trường | Đặc tả |
| --- | --- |
| Tên | Sinh ghế |
| Mô tả | Sinh sơ đồ ghế thường cho phòng trống (Staff/Admin). |
| Tác nhân | Nhân viên/quản trị viên |
| Tiền điều kiện | Phòng/suất tồn tại. Chọn ghế cần đăng nhập; sửa sơ đồ cần quyền quản lý và phòng không có suất chiếu. |
| Kích hoạt | Thực hiện “Sinh ghế” hoặc sự kiện/tác vụ backend tương ứng. |
| Luồng chính | 1. Đọc đầu vào/tài nguyên hiện tại và phiên áp dụng. 2. Thực hiện thao tác này: Sinh sơ đồ ghế thường cho phòng trống (Staff/Admin). 3. Trả/hiển thị kết quả chính thức và làm mới dữ liệu bị tác động sau thành công. |
| Luồng thay thế / ngoại lệ | Bỏ chọn ghế vừa bị đơn khác giữ và thông báo cho khách. Từ chối nửa cặp sweetbox, ghế sai phòng và sửa sơ đồ không đủ điều kiện. |
| Hậu điều kiện | Kết quả thành công quan sát được khớp yêu cầu này; chuyển trạng thái được chỉ định được lưu. Từ chối không cấp quyền hoặc để thay đổi dở dang trái phép. |
| Ưu tiên | H |
| Tiêu chí nghiệm thu | **WEB-FR-SEAT-01-AC-01** — Với tiền điều kiện/kích hoạt, kiểm tra: Sinh sơ đồ ghế thường cho phòng trống (Staff/Admin). **WEB-FR-SEAT-01-AC-02** — Thử đầu vào sai/thiếu quyền/xung đột áp dụng và kiểm tra từ chối đã nêu, không đổi dữ liệu trái phép và không báo thành công sai. |
| Bằng chứng | [Cinema_BE/MovieService/MovieService/Controllers/SeatsController.cs](../Cinema_BE/MovieService/MovieService/Controllers/SeatsController.cs); [Cinema_Mobile/lib/features/staff/screens/staff_record_screen.dart](../Cinema_Mobile/lib/features/staff/screens/staff_record_screen.dart); [Cinema_BE/MovieService/MovieService/Service/Impl/SeatService.cs](../Cinema_BE/MovieService/MovieService/Service/Impl/SeatService.cs); [Cinema_BE/MovieService/MovieService/Service/Impl/ShowtimeService.cs](../Cinema_BE/MovieService/MovieService/Service/Impl/ShowtimeService.cs) |
| Quy tắc nghiệp vụ | WEB-BR-04, WEB-BR-07, WEB-BR-15, WEB-BR-16, WEB-BR-26 |
| Ca sử dụng / màn / API | UC-WEB-05; WEB-SCR-RECORD-ROOMS; WEB-API-010 |

### WEB-FR-SEAT-02 — Chi tiết ghế

| Trường | Đặc tả |
| --- | --- |
| Tên | Chi tiết ghế |
| Mô tả | Xem chi tiết một ghế. |
| Tác nhân | Nhân viên/quản trị viên |
| Tiền điều kiện | Phòng/suất tồn tại. Chọn ghế cần đăng nhập; sửa sơ đồ cần quyền quản lý và phòng không có suất chiếu. |
| Kích hoạt | Thực hiện “Chi tiết ghế” hoặc sự kiện/tác vụ backend tương ứng. |
| Luồng chính | 1. Đọc đầu vào/tài nguyên hiện tại và phiên áp dụng. 2. Thực hiện thao tác này: Xem chi tiết một ghế. 3. Trả/hiển thị kết quả chính thức và làm mới dữ liệu bị tác động sau thành công. |
| Luồng thay thế / ngoại lệ | Bỏ chọn ghế vừa bị đơn khác giữ và thông báo cho khách. Từ chối nửa cặp sweetbox, ghế sai phòng và sửa sơ đồ không đủ điều kiện. |
| Hậu điều kiện | Dữ liệu/trạng thái đủ quyền được trả/hiển thị; đọc không đổi trạng thái vé/thanh toán. Dấu đã đọc thông báo chỉ đổi bằng thao tác ghi riêng. |
| Ưu tiên | L |
| Tiêu chí nghiệm thu | **WEB-FR-SEAT-02-AC-01** — Với tiền điều kiện/kích hoạt, kiểm tra: Xem chi tiết một ghế. **WEB-FR-SEAT-02-AC-02** — Thử đầu vào sai/thiếu quyền/xung đột áp dụng và kiểm tra từ chối đã nêu, không đổi dữ liệu trái phép và không báo thành công sai. |
| Bằng chứng | [Cinema_BE/MovieService/MovieService/Controllers/SeatsController.cs](../Cinema_BE/MovieService/MovieService/Controllers/SeatsController.cs); [Cinema_Mobile/lib/features/staff/screens/staff_record_screen.dart](../Cinema_Mobile/lib/features/staff/screens/staff_record_screen.dart); [Cinema_BE/MovieService/MovieService/Service/Impl/SeatService.cs](../Cinema_BE/MovieService/MovieService/Service/Impl/SeatService.cs); [Cinema_BE/MovieService/MovieService/Service/Impl/ShowtimeService.cs](../Cinema_BE/MovieService/MovieService/Service/Impl/ShowtimeService.cs) |
| Quy tắc nghiệp vụ | WEB-BR-04, WEB-BR-07, WEB-BR-15, WEB-BR-16, WEB-BR-26 |
| Ca sử dụng / màn / API | UC-WEB-05; WEB-SCR-RECORD-ROOMS; WEB-API-009 |

### WEB-FR-SEAT-03 — Xem sơ đồ phòng

| Trường | Đặc tả |
| --- | --- |
| Tên | Xem sơ đồ phòng |
| Mô tả | Lấy sơ đồ ghế của phòng (người dùng đã đăng nhập). |
| Tác nhân | Khách hàng đã đăng nhập xem/chọn; nhân viên/quản trị viên đổi loại; quản trị viên đổi sức chứa/xoá |
| Tiền điều kiện | Phòng/suất tồn tại. Chọn ghế cần đăng nhập; sửa sơ đồ cần quyền quản lý và phòng không có suất chiếu. |
| Kích hoạt | Thực hiện “Xem sơ đồ phòng” hoặc sự kiện/tác vụ backend tương ứng. |
| Luồng chính | 1. Đọc đầu vào/tài nguyên hiện tại và phiên áp dụng. 2. Thực hiện thao tác này: Lấy sơ đồ ghế của phòng (người dùng đã đăng nhập). 3. Trả/hiển thị kết quả chính thức và làm mới dữ liệu bị tác động sau thành công. |
| Luồng thay thế / ngoại lệ | Bỏ chọn ghế vừa bị đơn khác giữ và thông báo cho khách. Từ chối nửa cặp sweetbox, ghế sai phòng và sửa sơ đồ không đủ điều kiện. |
| Hậu điều kiện | Dữ liệu/trạng thái đủ quyền được trả/hiển thị; đọc không đổi trạng thái vé/thanh toán. Dấu đã đọc thông báo chỉ đổi bằng thao tác ghi riêng. |
| Ưu tiên | H |
| Tiêu chí nghiệm thu | **WEB-FR-SEAT-03-AC-01** — Với tiền điều kiện/kích hoạt, kiểm tra: Lấy sơ đồ ghế của phòng (người dùng đã đăng nhập). **WEB-FR-SEAT-03-AC-02** — Thử đầu vào sai/thiếu quyền/xung đột áp dụng và kiểm tra từ chối đã nêu, không đổi dữ liệu trái phép và không báo thành công sai. |
| Bằng chứng | [Cinema_BE/MovieService/MovieService/Controllers/SeatsController.cs](../Cinema_BE/MovieService/MovieService/Controllers/SeatsController.cs); [Cinema_Mobile/lib/features/seat/screens/seat_selection_screen.dart](../Cinema_Mobile/lib/features/seat/screens/seat_selection_screen.dart); [Cinema_Mobile/lib/features/staff/screens/staff_record_screen.dart](../Cinema_Mobile/lib/features/staff/screens/staff_record_screen.dart); [Cinema_BE/MovieService/MovieService/Service/Impl/SeatService.cs](../Cinema_BE/MovieService/MovieService/Service/Impl/SeatService.cs); [Cinema_BE/MovieService/MovieService/Service/Impl/ShowtimeService.cs](../Cinema_BE/MovieService/MovieService/Service/Impl/ShowtimeService.cs) |
| Quy tắc nghiệp vụ | WEB-BR-04, WEB-BR-07, WEB-BR-15, WEB-BR-16, WEB-BR-26 |
| Ca sử dụng / màn / API | UC-WEB-05; WEB-SCR-SEATS, WEB-SCR-RECORD-ROOMS; WEB-API-013 |

### WEB-FR-SEAT-04 — API xoá ghế

| Trường | Đặc tả |
| --- | --- |
| Tên | API xoá ghế |
| Mô tả | Admin xoá ghế (chỉ qua API). |
| Tác nhân | Quản trị viên |
| Tiền điều kiện | Phòng/suất tồn tại. Chọn ghế cần đăng nhập; sửa sơ đồ cần quyền quản lý và phòng không có suất chiếu. |
| Kích hoạt | Thực hiện “API xoá ghế” hoặc sự kiện/tác vụ backend tương ứng. |
| Luồng chính | 1. Đọc đầu vào/tài nguyên hiện tại và phiên áp dụng. 2. Thực hiện thao tác này: Admin xoá ghế (chỉ qua API). 3. Trả/hiển thị kết quả chính thức và làm mới dữ liệu bị tác động sau thành công. |
| Luồng thay thế / ngoại lệ | Bỏ chọn ghế vừa bị đơn khác giữ và thông báo cho khách. Từ chối nửa cặp sweetbox, ghế sai phòng và sửa sơ đồ không đủ điều kiện. |
| Hậu điều kiện | Kết quả thành công quan sát được khớp yêu cầu này; chuyển trạng thái được chỉ định được lưu. Từ chối không cấp quyền hoặc để thay đổi dở dang trái phép. |
| Ưu tiên | L |
| Tiêu chí nghiệm thu | **WEB-FR-SEAT-04-AC-01** — Với tiền điều kiện/kích hoạt, kiểm tra: Admin xoá ghế (chỉ qua API). **WEB-FR-SEAT-04-AC-02** — Thử đầu vào sai/thiếu quyền/xung đột áp dụng và kiểm tra từ chối đã nêu, không đổi dữ liệu trái phép và không báo thành công sai. |
| Bằng chứng | [Cinema_BE/MovieService/MovieService/Controllers/SeatsController.cs](../Cinema_BE/MovieService/MovieService/Controllers/SeatsController.cs); [Cinema_BE/MovieService/MovieService/Service/Impl/SeatService.cs](../Cinema_BE/MovieService/MovieService/Service/Impl/SeatService.cs); [Cinema_BE/MovieService/MovieService/Service/Impl/ShowtimeService.cs](../Cinema_BE/MovieService/MovieService/Service/Impl/ShowtimeService.cs) |
| Quy tắc nghiệp vụ | WEB-BR-04, WEB-BR-07, WEB-BR-15, WEB-BR-16, WEB-BR-26 |
| Ca sử dụng / màn / API | UC-WEB-05; ; WEB-API-008 |

### WEB-FR-SEAT-05 — Đổi loại ghế

| Trường | Đặc tả |
| --- | --- |
| Tên | Đổi loại ghế |
| Mô tả | Đổi loại một ghế: NORMAL / VIP / SWEETBOX. Sweetbox đổi cả cặp; ghế không có ghế cặp không thành sweetbox được. |
| Tác nhân | Nhân viên/quản trị viên |
| Tiền điều kiện | Phòng/suất tồn tại. Chọn ghế cần đăng nhập; sửa sơ đồ cần quyền quản lý và phòng không có suất chiếu. |
| Kích hoạt | Thực hiện “Đổi loại ghế” hoặc sự kiện/tác vụ backend tương ứng. |
| Luồng chính | 1. Đọc đầu vào/tài nguyên hiện tại và phiên áp dụng. 2. Thực hiện thao tác này: Đổi loại một ghế: NORMAL / VIP / SWEETBOX. Sweetbox đổi cả cặp; ghế không có ghế cặp không thành sweetbox được. 3. Trả/hiển thị kết quả chính thức và làm mới dữ liệu bị tác động sau thành công. |
| Luồng thay thế / ngoại lệ | Bỏ chọn ghế vừa bị đơn khác giữ và thông báo cho khách. Từ chối nửa cặp sweetbox, ghế sai phòng và sửa sơ đồ không đủ điều kiện. |
| Hậu điều kiện | Kết quả thành công quan sát được khớp yêu cầu này; chuyển trạng thái được chỉ định được lưu. Từ chối không cấp quyền hoặc để thay đổi dở dang trái phép. |
| Ưu tiên | H |
| Tiêu chí nghiệm thu | **WEB-FR-SEAT-05-AC-01** — Với tiền điều kiện/kích hoạt, kiểm tra: Đổi loại một ghế: NORMAL / VIP / SWEETBOX. Sweetbox đổi cả cặp; ghế không có ghế cặp không thành sweetbox được. **WEB-FR-SEAT-05-AC-02** — Thử đầu vào sai/thiếu quyền/xung đột áp dụng và kiểm tra từ chối đã nêu, không đổi dữ liệu trái phép và không báo thành công sai. |
| Bằng chứng | [Cinema_BE/MovieService/MovieService/Controllers/SeatsController.cs](../Cinema_BE/MovieService/MovieService/Controllers/SeatsController.cs); [Cinema_Mobile/lib/features/staff/screens/staff_record_screen.dart](../Cinema_Mobile/lib/features/staff/screens/staff_record_screen.dart); [Cinema_BE/MovieService/MovieService/Service/Impl/SeatService.cs](../Cinema_BE/MovieService/MovieService/Service/Impl/SeatService.cs); [Cinema_BE/MovieService/MovieService/Service/Impl/ShowtimeService.cs](../Cinema_BE/MovieService/MovieService/Service/Impl/ShowtimeService.cs) |
| Quy tắc nghiệp vụ | WEB-BR-04, WEB-BR-07, WEB-BR-15, WEB-BR-16, WEB-BR-26 |
| Ca sử dụng / màn / API | UC-WEB-05; WEB-SCR-RECORD-ROOMS; WEB-API-007 |

### WEB-FR-SEAT-06 — Đổi loại nhiều ghế

| Trường | Đặc tả |
| --- | --- |
| Tên | Đổi loại nhiều ghế |
| Mô tả | Đổi loại nhiều ghế một lần trên sơ đồ: chọn loại rồi bấm, kéo qua nhiều ghế, hoặc bấm chữ đầu hàng để đổi cả hàng. Hàng có ghế lẻ không đủ cặp thì 400. |
| Tác nhân | Nhân viên/quản trị viên |
| Tiền điều kiện | Phòng/suất tồn tại. Chọn ghế cần đăng nhập; sửa sơ đồ cần quyền quản lý và phòng không có suất chiếu. |
| Kích hoạt | Thực hiện “Đổi loại nhiều ghế” hoặc sự kiện/tác vụ backend tương ứng. |
| Luồng chính | 1. Đọc đầu vào/tài nguyên hiện tại và phiên áp dụng. 2. Thực hiện thao tác này: Đổi loại nhiều ghế một lần trên sơ đồ: chọn loại rồi bấm, kéo qua nhiều ghế, hoặc bấm chữ đầu hàng để đổi cả hàng. Hàng có ghế lẻ không đủ cặp thì 400. 3. Trả/hiển thị kết quả chính thức và làm mới dữ liệu bị tác động sau thành công. |
| Luồng thay thế / ngoại lệ | Bỏ chọn ghế vừa bị đơn khác giữ và thông báo cho khách. Từ chối nửa cặp sweetbox, ghế sai phòng và sửa sơ đồ không đủ điều kiện. |
| Hậu điều kiện | Kết quả thành công quan sát được khớp yêu cầu này; chuyển trạng thái được chỉ định được lưu. Từ chối không cấp quyền hoặc để thay đổi dở dang trái phép. |
| Ưu tiên | M |
| Tiêu chí nghiệm thu | **WEB-FR-SEAT-06-AC-01** — Với tiền điều kiện/kích hoạt, kiểm tra: Đổi loại nhiều ghế một lần trên sơ đồ: chọn loại rồi bấm, kéo qua nhiều ghế, hoặc bấm chữ đầu hàng để đổi cả hàng. Hàng có ghế lẻ không đủ cặp thì 400. **WEB-FR-SEAT-06-AC-02** — Thử đầu vào sai/thiếu quyền/xung đột áp dụng và kiểm tra từ chối đã nêu, không đổi dữ liệu trái phép và không báo thành công sai. |
| Bằng chứng | [Cinema_BE/MovieService/MovieService/Controllers/SeatsController.cs](../Cinema_BE/MovieService/MovieService/Controllers/SeatsController.cs); [Cinema_Mobile/lib/features/staff/screens/staff_record_screen.dart](../Cinema_Mobile/lib/features/staff/screens/staff_record_screen.dart); [Cinema_BE/MovieService/MovieService/Service/Impl/SeatService.cs](../Cinema_BE/MovieService/MovieService/Service/Impl/SeatService.cs); [Cinema_BE/MovieService/MovieService/Service/Impl/ShowtimeService.cs](../Cinema_BE/MovieService/MovieService/Service/Impl/ShowtimeService.cs) |
| Quy tắc nghiệp vụ | WEB-BR-04, WEB-BR-07, WEB-BR-15, WEB-BR-16, WEB-BR-26 |
| Ca sử dụng / màn / API | UC-WEB-05; WEB-SCR-RECORD-ROOMS; WEB-API-012 |

### WEB-FR-SEAT-07 — Đổi sức chứa

| Trường | Đặc tả |
| --- | --- |
| Tên | Đổi sức chứa |
| Mô tả | Admin đổi số ghế của phòng: thêm thì lấp hàng cuối rồi sang hàng mới (tối đa hàng Z), bớt thì bỏ từ ghế cuối; nửa sweetbox còn lại thành ghế thường. |
| Tác nhân | Quản trị viên |
| Tiền điều kiện | Phòng/suất tồn tại. Chọn ghế cần đăng nhập; sửa sơ đồ cần quyền quản lý và phòng không có suất chiếu. |
| Kích hoạt | Thực hiện “Đổi sức chứa” hoặc sự kiện/tác vụ backend tương ứng. |
| Luồng chính | 1. Đọc đầu vào/tài nguyên hiện tại và phiên áp dụng. 2. Thực hiện thao tác này: Admin đổi số ghế của phòng: thêm thì lấp hàng cuối rồi sang hàng mới (tối đa hàng Z), bớt thì bỏ từ ghế cuối; nửa sweetbox còn lại thành ghế thường. 3. Trả/hiển thị kết quả chính thức và làm mới dữ liệu bị tác động sau thành công. |
| Luồng thay thế / ngoại lệ | Bỏ chọn ghế vừa bị đơn khác giữ và thông báo cho khách. Từ chối nửa cặp sweetbox, ghế sai phòng và sửa sơ đồ không đủ điều kiện. |
| Hậu điều kiện | Kết quả thành công quan sát được khớp yêu cầu này; chuyển trạng thái được chỉ định được lưu. Từ chối không cấp quyền hoặc để thay đổi dở dang trái phép. |
| Ưu tiên | M |
| Tiêu chí nghiệm thu | **WEB-FR-SEAT-07-AC-01** — Với tiền điều kiện/kích hoạt, kiểm tra: Admin đổi số ghế của phòng: thêm thì lấp hàng cuối rồi sang hàng mới (tối đa hàng Z), bớt thì bỏ từ ghế cuối; nửa sweetbox còn lại thành ghế thường. **WEB-FR-SEAT-07-AC-02** — Thử đầu vào sai/thiếu quyền/xung đột áp dụng và kiểm tra từ chối đã nêu, không đổi dữ liệu trái phép và không báo thành công sai. |
| Bằng chứng | [Cinema_BE/MovieService/MovieService/Controllers/SeatsController.cs](../Cinema_BE/MovieService/MovieService/Controllers/SeatsController.cs); [Cinema_Mobile/lib/features/staff/screens/staff_record_screen.dart](../Cinema_Mobile/lib/features/staff/screens/staff_record_screen.dart); [Cinema_BE/MovieService/MovieService/Service/Impl/SeatService.cs](../Cinema_BE/MovieService/MovieService/Service/Impl/SeatService.cs); [Cinema_BE/MovieService/MovieService/Service/Impl/ShowtimeService.cs](../Cinema_BE/MovieService/MovieService/Service/Impl/ShowtimeService.cs) |
| Quy tắc nghiệp vụ | WEB-BR-04, WEB-BR-07, WEB-BR-15, WEB-BR-16, WEB-BR-26 |
| Ca sử dụng / màn / API | UC-WEB-05; WEB-SCR-RECORD-ROOMS; WEB-API-011 |

### WEB-FR-SEAT-08 — Bảo vệ phòng đã xếp lịch

| Trường | Đặc tả |
| --- | --- |
| Tên | Bảo vệ phòng đã xếp lịch |
| Mô tả | Phòng đã có suất chiếu thì không sinh, đổi loại hay đổi số ghế (giữ đúng vé đã bán). |
| Tác nhân | Nhân viên/quản trị viên |
| Tiền điều kiện | Phòng/suất tồn tại. Chọn ghế cần đăng nhập; sửa sơ đồ cần quyền quản lý và phòng không có suất chiếu. |
| Kích hoạt | Thực hiện “Bảo vệ phòng đã xếp lịch” hoặc sự kiện/tác vụ backend tương ứng. |
| Luồng chính | 1. Đọc đầu vào/tài nguyên hiện tại và phiên áp dụng. 2. Thực hiện thao tác này: Phòng đã có suất chiếu thì không sinh, đổi loại hay đổi số ghế (giữ đúng vé đã bán). 3. Trả/hiển thị kết quả chính thức và làm mới dữ liệu bị tác động sau thành công. |
| Luồng thay thế / ngoại lệ | Bỏ chọn ghế vừa bị đơn khác giữ và thông báo cho khách. Từ chối nửa cặp sweetbox, ghế sai phòng và sửa sơ đồ không đủ điều kiện. |
| Hậu điều kiện | Kết quả thành công quan sát được khớp yêu cầu này; chuyển trạng thái được chỉ định được lưu. Từ chối không cấp quyền hoặc để thay đổi dở dang trái phép. |
| Ưu tiên | H |
| Tiêu chí nghiệm thu | **WEB-FR-SEAT-08-AC-01** — Với tiền điều kiện/kích hoạt, kiểm tra: Phòng đã có suất chiếu thì không sinh, đổi loại hay đổi số ghế (giữ đúng vé đã bán). **WEB-FR-SEAT-08-AC-02** — Thử đầu vào sai/thiếu quyền/xung đột áp dụng và kiểm tra từ chối đã nêu, không đổi dữ liệu trái phép và không báo thành công sai. |
| Bằng chứng | [Cinema_BE/MovieService/MovieService/Controllers/SeatsController.cs](../Cinema_BE/MovieService/MovieService/Controllers/SeatsController.cs); [Cinema_Mobile/lib/features/staff/screens/staff_record_screen.dart](../Cinema_Mobile/lib/features/staff/screens/staff_record_screen.dart); [Cinema_BE/MovieService/MovieService/Service/Impl/SeatService.cs](../Cinema_BE/MovieService/MovieService/Service/Impl/SeatService.cs); [Cinema_BE/MovieService/MovieService/Service/Impl/ShowtimeService.cs](../Cinema_BE/MovieService/MovieService/Service/Impl/ShowtimeService.cs) |
| Quy tắc nghiệp vụ | WEB-BR-04, WEB-BR-07, WEB-BR-15, WEB-BR-16, WEB-BR-26 |
| Ca sử dụng / màn / API | UC-WEB-05; WEB-SCR-RECORD-ROOMS; WEB-API-007, WEB-API-010, WEB-API-011, WEB-API-012 |

### WEB-FR-SEAT-09 — Làm mới sơ đồ quản lý

| Trường | Đặc tả |
| --- | --- |
| Tên | Làm mới sơ đồ quản lý |
| Mô tả | Sơ đồ ghế ở trang quản trị tự làm mới mỗi 5 giây khi người khác đổi. |
| Tác nhân | Nhân viên/quản trị viên |
| Tiền điều kiện | Phòng/suất tồn tại. Chọn ghế cần đăng nhập; sửa sơ đồ cần quyền quản lý và phòng không có suất chiếu. |
| Kích hoạt | Thực hiện “Làm mới sơ đồ quản lý” hoặc sự kiện/tác vụ backend tương ứng. |
| Luồng chính | 1. Đọc đầu vào/tài nguyên hiện tại và phiên áp dụng. 2. Thực hiện thao tác này: Sơ đồ ghế ở trang quản trị tự làm mới mỗi 5 giây khi người khác đổi. 3. Trả/hiển thị kết quả chính thức và làm mới dữ liệu bị tác động sau thành công. |
| Luồng thay thế / ngoại lệ | Bỏ chọn ghế vừa bị đơn khác giữ và thông báo cho khách. Từ chối nửa cặp sweetbox, ghế sai phòng và sửa sơ đồ không đủ điều kiện. |
| Hậu điều kiện | Dữ liệu/trạng thái đủ quyền được trả/hiển thị; đọc không đổi trạng thái vé/thanh toán. Dấu đã đọc thông báo chỉ đổi bằng thao tác ghi riêng. |
| Ưu tiên | L |
| Tiêu chí nghiệm thu | **WEB-FR-SEAT-09-AC-01** — Với tiền điều kiện/kích hoạt, kiểm tra: Sơ đồ ghế ở trang quản trị tự làm mới mỗi 5 giây khi người khác đổi. **WEB-FR-SEAT-09-AC-02** — Thử đầu vào sai/thiếu quyền/xung đột áp dụng và kiểm tra từ chối đã nêu, không đổi dữ liệu trái phép và không báo thành công sai. |
| Bằng chứng | [Cinema_BE/MovieService/MovieService/Controllers/SeatsController.cs](../Cinema_BE/MovieService/MovieService/Controllers/SeatsController.cs); [Cinema_Mobile/lib/features/staff/screens/staff_record_screen.dart](../Cinema_Mobile/lib/features/staff/screens/staff_record_screen.dart); [Cinema_BE/MovieService/MovieService/Service/Impl/SeatService.cs](../Cinema_BE/MovieService/MovieService/Service/Impl/SeatService.cs); [Cinema_BE/MovieService/MovieService/Service/Impl/ShowtimeService.cs](../Cinema_BE/MovieService/MovieService/Service/Impl/ShowtimeService.cs) |
| Quy tắc nghiệp vụ | WEB-BR-04, WEB-BR-07, WEB-BR-15, WEB-BR-16, WEB-BR-26 |
| Ca sử dụng / màn / API | UC-WEB-05; WEB-SCR-RECORD-ROOMS; WEB-API-013 |

### WEB-FR-SHOW-01 — Danh sách suất

| Trường | Đặc tả |
| --- | --- |
| Tên | Danh sách suất |
| Mô tả | Danh sách suất chiếu có phân trang và lọc. |
| Tác nhân | Nhân viên/quản trị viên |
| Tiền điều kiện | Phim và phòng tồn tại; thay đổi quản lý cần nhân viên/quản trị viên. |
| Kích hoạt | Thực hiện “Danh sách suất” hoặc sự kiện/tác vụ backend tương ứng. |
| Luồng chính | 1. Đọc đầu vào/tài nguyên hiện tại và phiên áp dụng. 2. Thực hiện thao tác này: Danh sách suất chiếu có phân trang và lọc. 3. Trả/hiển thị kết quả chính thức và làm mới dữ liệu bị tác động sau thành công. |
| Luồng thay thế / ngoại lệ | Từ chối trùng lịch bằng 409 và giờ/định dạng sai bằng 400; suất đã huỷ là trạng thái cuối. Khách không chọn suất đóng bán hoặc đã bắt đầu. |
| Hậu điều kiện | Dữ liệu/trạng thái đủ quyền được trả/hiển thị; đọc không đổi trạng thái vé/thanh toán. Dấu đã đọc thông báo chỉ đổi bằng thao tác ghi riêng. |
| Ưu tiên | H |
| Tiêu chí nghiệm thu | **WEB-FR-SHOW-01-AC-01** — Với tiền điều kiện/kích hoạt, kiểm tra: Danh sách suất chiếu có phân trang và lọc. **WEB-FR-SHOW-01-AC-02** — Thử đầu vào sai/thiếu quyền/xung đột áp dụng và kiểm tra từ chối đã nêu, không đổi dữ liệu trái phép và không báo thành công sai. |
| Bằng chứng | [Cinema_BE/MovieService/MovieService/Controllers/ShowtimesController.cs](../Cinema_BE/MovieService/MovieService/Controllers/ShowtimesController.cs); [Cinema_Mobile/lib/features/staff/screens/staff_operations_screen.dart](../Cinema_Mobile/lib/features/staff/screens/staff_operations_screen.dart); [Cinema_BE/MovieService/MovieService/Service/Impl/ShowtimeService.cs](../Cinema_BE/MovieService/MovieService/Service/Impl/ShowtimeService.cs) |
| Quy tắc nghiệp vụ | WEB-BR-05, WEB-BR-06, WEB-BR-15, WEB-BR-19, WEB-BR-30 |
| Ca sử dụng / màn / API | UC-WEB-06; WEB-SCR-OPERATIONS; WEB-API-023 |

### WEB-FR-SHOW-02 — Tạo suất

| Trường | Đặc tả |
| --- | --- |
| Tên | Tạo suất |
| Mô tả | Staff/Admin tạo suất chiếu: phim, phòng, giờ bắt đầu, giờ kết thúc, giá ghế thường, trạng thái. |
| Tác nhân | Nhân viên/quản trị viên |
| Tiền điều kiện | Phim và phòng tồn tại; thay đổi quản lý cần nhân viên/quản trị viên. |
| Kích hoạt | Thực hiện “Tạo suất” hoặc sự kiện/tác vụ backend tương ứng. |
| Luồng chính | 1. Đọc đầu vào/tài nguyên hiện tại và phiên áp dụng. 2. Thực hiện thao tác này: Staff/Admin tạo suất chiếu: phim, phòng, giờ bắt đầu, giờ kết thúc, giá ghế thường, trạng thái. 3. Trả/hiển thị kết quả chính thức và làm mới dữ liệu bị tác động sau thành công. |
| Luồng thay thế / ngoại lệ | Từ chối trùng lịch bằng 409 và giờ/định dạng sai bằng 400; suất đã huỷ là trạng thái cuối. Khách không chọn suất đóng bán hoặc đã bắt đầu. |
| Hậu điều kiện | Kết quả thành công quan sát được khớp yêu cầu này; chuyển trạng thái được chỉ định được lưu. Từ chối không cấp quyền hoặc để thay đổi dở dang trái phép. |
| Ưu tiên | H |
| Tiêu chí nghiệm thu | **WEB-FR-SHOW-02-AC-01** — Với tiền điều kiện/kích hoạt, kiểm tra: Staff/Admin tạo suất chiếu: phim, phòng, giờ bắt đầu, giờ kết thúc, giá ghế thường, trạng thái. **WEB-FR-SHOW-02-AC-02** — Thử đầu vào sai/thiếu quyền/xung đột áp dụng và kiểm tra từ chối đã nêu, không đổi dữ liệu trái phép và không báo thành công sai. |
| Bằng chứng | [Cinema_BE/MovieService/MovieService/Controllers/ShowtimesController.cs](../Cinema_BE/MovieService/MovieService/Controllers/ShowtimesController.cs); [Cinema_Mobile/lib/features/staff/screens/staff_showtime_editor_screen.dart](../Cinema_Mobile/lib/features/staff/screens/staff_showtime_editor_screen.dart); [Cinema_BE/MovieService/MovieService/Service/Impl/ShowtimeService.cs](../Cinema_BE/MovieService/MovieService/Service/Impl/ShowtimeService.cs) |
| Quy tắc nghiệp vụ | WEB-BR-05, WEB-BR-06, WEB-BR-15, WEB-BR-19, WEB-BR-30 |
| Ca sử dụng / màn / API | UC-WEB-06; WEB-SCR-SHOW-EDITOR; WEB-API-024 |

### WEB-FR-SHOW-03 — Suất và giá

| Trường | Đặc tả |
| --- | --- |
| Tên | Suất và giá |
| Mô tả | Chi tiết suất chiếu kèm `seatPrices`: giá một ghế theo từng loại. |
| Tác nhân | Khách chưa đăng nhập/khách hàng xem suất công khai; nhân viên/quản trị viên quản lý |
| Tiền điều kiện | Phim và phòng tồn tại; thay đổi quản lý cần nhân viên/quản trị viên. |
| Kích hoạt | Thực hiện “Suất và giá” hoặc sự kiện/tác vụ backend tương ứng. |
| Luồng chính | 1. Đọc đầu vào/tài nguyên hiện tại và phiên áp dụng. 2. Thực hiện thao tác này: Chi tiết suất chiếu kèm `seatPrices`: giá một ghế theo từng loại. 3. Trả/hiển thị kết quả chính thức và làm mới dữ liệu bị tác động sau thành công. |
| Luồng thay thế / ngoại lệ | Từ chối trùng lịch bằng 409 và giờ/định dạng sai bằng 400; suất đã huỷ là trạng thái cuối. Khách không chọn suất đóng bán hoặc đã bắt đầu. |
| Hậu điều kiện | Dữ liệu/trạng thái đủ quyền được trả/hiển thị; đọc không đổi trạng thái vé/thanh toán. Dấu đã đọc thông báo chỉ đổi bằng thao tác ghi riêng. |
| Ưu tiên | H |
| Tiêu chí nghiệm thu | **WEB-FR-SHOW-03-AC-01** — Với tiền điều kiện/kích hoạt, kiểm tra: Chi tiết suất chiếu kèm `seatPrices`: giá một ghế theo từng loại. **WEB-FR-SHOW-03-AC-02** — Thử đầu vào sai/thiếu quyền/xung đột áp dụng và kiểm tra từ chối đã nêu, không đổi dữ liệu trái phép và không báo thành công sai. |
| Bằng chứng | [Cinema_BE/MovieService/MovieService/Controllers/ShowtimesController.cs](../Cinema_BE/MovieService/MovieService/Controllers/ShowtimesController.cs); [Cinema_Mobile/lib/features/movie/screens/movie_detail_screen.dart](../Cinema_Mobile/lib/features/movie/screens/movie_detail_screen.dart); [Cinema_Mobile/lib/features/seat/screens/seat_selection_screen.dart](../Cinema_Mobile/lib/features/seat/screens/seat_selection_screen.dart); [Cinema_Mobile/lib/features/staff/screens/staff_record_screen.dart](../Cinema_Mobile/lib/features/staff/screens/staff_record_screen.dart); [Cinema_BE/MovieService/MovieService/Service/Impl/ShowtimeService.cs](../Cinema_BE/MovieService/MovieService/Service/Impl/ShowtimeService.cs) |
| Quy tắc nghiệp vụ | WEB-BR-05, WEB-BR-06, WEB-BR-15, WEB-BR-19, WEB-BR-30 |
| Ca sử dụng / màn / API | UC-WEB-06; WEB-SCR-MOVIE, WEB-SCR-SEATS, WEB-SCR-RECORD-SHOWTIMES; WEB-API-017 |

### WEB-FR-SHOW-04 — Sửa suất

| Trường | Đặc tả |
| --- | --- |
| Tên | Sửa suất |
| Mô tả | Staff/Admin sửa suất chiếu; vẫn kiểm tra trùng lịch. |
| Tác nhân | Nhân viên/quản trị viên |
| Tiền điều kiện | Phim và phòng tồn tại; thay đổi quản lý cần nhân viên/quản trị viên. |
| Kích hoạt | Thực hiện “Sửa suất” hoặc sự kiện/tác vụ backend tương ứng. |
| Luồng chính | 1. Đọc đầu vào/tài nguyên hiện tại và phiên áp dụng. 2. Thực hiện thao tác này: Staff/Admin sửa suất chiếu; vẫn kiểm tra trùng lịch. 3. Trả/hiển thị kết quả chính thức và làm mới dữ liệu bị tác động sau thành công. |
| Luồng thay thế / ngoại lệ | Từ chối trùng lịch bằng 409 và giờ/định dạng sai bằng 400; suất đã huỷ là trạng thái cuối. Khách không chọn suất đóng bán hoặc đã bắt đầu. |
| Hậu điều kiện | Kết quả thành công quan sát được khớp yêu cầu này; chuyển trạng thái được chỉ định được lưu. Từ chối không cấp quyền hoặc để thay đổi dở dang trái phép. |
| Ưu tiên | H |
| Tiêu chí nghiệm thu | **WEB-FR-SHOW-04-AC-01** — Với tiền điều kiện/kích hoạt, kiểm tra: Staff/Admin sửa suất chiếu; vẫn kiểm tra trùng lịch. **WEB-FR-SHOW-04-AC-02** — Thử đầu vào sai/thiếu quyền/xung đột áp dụng và kiểm tra từ chối đã nêu, không đổi dữ liệu trái phép và không báo thành công sai. |
| Bằng chứng | [Cinema_BE/MovieService/MovieService/Controllers/ShowtimesController.cs](../Cinema_BE/MovieService/MovieService/Controllers/ShowtimesController.cs); [Cinema_Mobile/lib/features/staff/screens/staff_showtime_editor_screen.dart](../Cinema_Mobile/lib/features/staff/screens/staff_showtime_editor_screen.dart); [Cinema_BE/MovieService/MovieService/Service/Impl/ShowtimeService.cs](../Cinema_BE/MovieService/MovieService/Service/Impl/ShowtimeService.cs) |
| Quy tắc nghiệp vụ | WEB-BR-05, WEB-BR-06, WEB-BR-15, WEB-BR-19, WEB-BR-30 |
| Ca sử dụng / màn / API | UC-WEB-06; WEB-SCR-SHOW-EDITOR; WEB-API-018 |

### WEB-FR-SHOW-05 — Huỷ suất

| Trường | Đặc tả |
| --- | --- |
| Tên | Huỷ suất |
| Mô tả | Staff/Admin huỷ suất chiếu (chuyển `CANCELLED`, không xoá); hệ thống huỷ các vé và tạo hoàn tiền theo WEB-BR-19. |
| Tác nhân | Nhân viên/quản trị viên |
| Tiền điều kiện | Phim và phòng tồn tại; thay đổi quản lý cần nhân viên/quản trị viên. |
| Kích hoạt | Thực hiện “Huỷ suất” hoặc sự kiện/tác vụ backend tương ứng. |
| Luồng chính | 1. Đọc đầu vào/tài nguyên hiện tại và phiên áp dụng. 2. Thực hiện thao tác này: Staff/Admin huỷ suất chiếu (chuyển `CANCELLED`, không xoá); hệ thống huỷ các vé và tạo hoàn tiền theo WEB-BR-19. 3. Trả/hiển thị kết quả chính thức và làm mới dữ liệu bị tác động sau thành công. |
| Luồng thay thế / ngoại lệ | Từ chối trùng lịch bằng 409 và giờ/định dạng sai bằng 400; suất đã huỷ là trạng thái cuối. Khách không chọn suất đóng bán hoặc đã bắt đầu. |
| Hậu điều kiện | Kết quả thành công quan sát được khớp yêu cầu này; chuyển trạng thái được chỉ định được lưu. Từ chối không cấp quyền hoặc để thay đổi dở dang trái phép. |
| Ưu tiên | H |
| Tiêu chí nghiệm thu | **WEB-FR-SHOW-05-AC-01** — Với tiền điều kiện/kích hoạt, kiểm tra: Staff/Admin huỷ suất chiếu (chuyển `CANCELLED`, không xoá); hệ thống huỷ các vé và tạo hoàn tiền theo WEB-BR-19. **WEB-FR-SHOW-05-AC-02** — Thử đầu vào sai/thiếu quyền/xung đột áp dụng và kiểm tra từ chối đã nêu, không đổi dữ liệu trái phép và không báo thành công sai. |
| Bằng chứng | [Cinema_BE/MovieService/MovieService/Controllers/ShowtimesController.cs](../Cinema_BE/MovieService/MovieService/Controllers/ShowtimesController.cs); [Cinema_Mobile/lib/features/staff/screens/staff_record_screen.dart](../Cinema_Mobile/lib/features/staff/screens/staff_record_screen.dart); [Cinema_BE/MovieService/MovieService/Service/Impl/ShowtimeService.cs](../Cinema_BE/MovieService/MovieService/Service/Impl/ShowtimeService.cs) |
| Quy tắc nghiệp vụ | WEB-BR-05, WEB-BR-06, WEB-BR-15, WEB-BR-19, WEB-BR-30 |
| Ca sử dụng / màn / API | UC-WEB-06; WEB-SCR-RECORD-SHOWTIMES; WEB-API-016 |

### WEB-FR-SHOW-06 — Suất mở chưa bắt đầu

| Trường | Đặc tả |
| --- | --- |
| Tên | Suất mở chưa bắt đầu |
| Mô tả | Lấy các suất đang mở bán (`OPEN`, chưa bắt đầu). |
| Tác nhân | Khách chưa đăng nhập/khách hàng xem suất công khai; nhân viên/quản trị viên quản lý |
| Tiền điều kiện | Phim và phòng tồn tại; thay đổi quản lý cần nhân viên/quản trị viên. |
| Kích hoạt | Thực hiện “Suất mở chưa bắt đầu” hoặc sự kiện/tác vụ backend tương ứng. |
| Luồng chính | 1. Đọc đầu vào/tài nguyên hiện tại và phiên áp dụng. 2. Thực hiện thao tác này: Lấy các suất đang mở bán (`OPEN`, chưa bắt đầu). 3. Trả/hiển thị kết quả chính thức và làm mới dữ liệu bị tác động sau thành công. |
| Luồng thay thế / ngoại lệ | Từ chối trùng lịch bằng 409 và giờ/định dạng sai bằng 400; suất đã huỷ là trạng thái cuối. Khách không chọn suất đóng bán hoặc đã bắt đầu. |
| Hậu điều kiện | Dữ liệu/trạng thái đủ quyền được trả/hiển thị; đọc không đổi trạng thái vé/thanh toán. Dấu đã đọc thông báo chỉ đổi bằng thao tác ghi riêng. |
| Ưu tiên | H |
| Tiêu chí nghiệm thu | **WEB-FR-SHOW-06-AC-01** — Với tiền điều kiện/kích hoạt, kiểm tra: Lấy các suất đang mở bán (`OPEN`, chưa bắt đầu). **WEB-FR-SHOW-06-AC-02** — Thử đầu vào sai/thiếu quyền/xung đột áp dụng và kiểm tra từ chối đã nêu, không đổi dữ liệu trái phép và không báo thành công sai. |
| Bằng chứng | [Cinema_BE/MovieService/MovieService/Controllers/ShowtimesController.cs](../Cinema_BE/MovieService/MovieService/Controllers/ShowtimesController.cs); [Cinema_Mobile/lib/features/movie/screens/movie_detail_screen.dart](../Cinema_Mobile/lib/features/movie/screens/movie_detail_screen.dart); [Cinema_BE/MovieService/MovieService/Service/Impl/ShowtimeService.cs](../Cinema_BE/MovieService/MovieService/Service/Impl/ShowtimeService.cs) |
| Quy tắc nghiệp vụ | WEB-BR-05, WEB-BR-06, WEB-BR-15, WEB-BR-19, WEB-BR-30 |
| Ca sử dụng / màn / API | UC-WEB-06; WEB-SCR-MOVIE; WEB-API-022 |

### WEB-FR-SHOW-07 — Suất theo phim

| Trường | Đặc tả |
| --- | --- |
| Tên | Suất theo phim |
| Mô tả | Lấy suất chiếu theo phim. |
| Tác nhân | Khách chưa đăng nhập/khách hàng xem suất công khai; nhân viên/quản trị viên quản lý |
| Tiền điều kiện | Phim và phòng tồn tại; thay đổi quản lý cần nhân viên/quản trị viên. |
| Kích hoạt | Thực hiện “Suất theo phim” hoặc sự kiện/tác vụ backend tương ứng. |
| Luồng chính | 1. Đọc đầu vào/tài nguyên hiện tại và phiên áp dụng. 2. Thực hiện thao tác này: Lấy suất chiếu theo phim. 3. Trả/hiển thị kết quả chính thức và làm mới dữ liệu bị tác động sau thành công. |
| Luồng thay thế / ngoại lệ | Từ chối trùng lịch bằng 409 và giờ/định dạng sai bằng 400; suất đã huỷ là trạng thái cuối. Khách không chọn suất đóng bán hoặc đã bắt đầu. |
| Hậu điều kiện | Dữ liệu/trạng thái đủ quyền được trả/hiển thị; đọc không đổi trạng thái vé/thanh toán. Dấu đã đọc thông báo chỉ đổi bằng thao tác ghi riêng. |
| Ưu tiên | M |
| Tiêu chí nghiệm thu | **WEB-FR-SHOW-07-AC-01** — Với tiền điều kiện/kích hoạt, kiểm tra: Lấy suất chiếu theo phim. **WEB-FR-SHOW-07-AC-02** — Thử đầu vào sai/thiếu quyền/xung đột áp dụng và kiểm tra từ chối đã nêu, không đổi dữ liệu trái phép và không báo thành công sai. |
| Bằng chứng | [Cinema_BE/MovieService/MovieService/Controllers/ShowtimesController.cs](../Cinema_BE/MovieService/MovieService/Controllers/ShowtimesController.cs); [Cinema_Mobile/lib/features/movie/screens/movie_detail_screen.dart](../Cinema_Mobile/lib/features/movie/screens/movie_detail_screen.dart); [Cinema_BE/MovieService/MovieService/Service/Impl/ShowtimeService.cs](../Cinema_BE/MovieService/MovieService/Service/Impl/ShowtimeService.cs) |
| Quy tắc nghiệp vụ | WEB-BR-05, WEB-BR-06, WEB-BR-15, WEB-BR-19, WEB-BR-30 |
| Ca sử dụng / màn / API | UC-WEB-06; WEB-SCR-MOVIE; WEB-API-021 |

### WEB-FR-SHOW-08 — Suất phim còn đặt được

| Trường | Đặc tả |
| --- | --- |
| Tên | Suất phim còn đặt được |
| Mô tả | Lấy suất đang mở bán theo phim; app khách hiện các suất trong 7 ngày tới. |
| Tác nhân | Khách chưa đăng nhập/khách hàng xem suất công khai; nhân viên/quản trị viên quản lý |
| Tiền điều kiện | Phim và phòng tồn tại; thay đổi quản lý cần nhân viên/quản trị viên. |
| Kích hoạt | Thực hiện “Suất phim còn đặt được” hoặc sự kiện/tác vụ backend tương ứng. |
| Luồng chính | 1. Đọc đầu vào/tài nguyên hiện tại và phiên áp dụng. 2. Thực hiện thao tác này: Lấy suất đang mở bán theo phim; app khách hiện các suất trong 7 ngày tới. 3. Trả/hiển thị kết quả chính thức và làm mới dữ liệu bị tác động sau thành công. |
| Luồng thay thế / ngoại lệ | Từ chối trùng lịch bằng 409 và giờ/định dạng sai bằng 400; suất đã huỷ là trạng thái cuối. Khách không chọn suất đóng bán hoặc đã bắt đầu. |
| Hậu điều kiện | Dữ liệu/trạng thái đủ quyền được trả/hiển thị; đọc không đổi trạng thái vé/thanh toán. Dấu đã đọc thông báo chỉ đổi bằng thao tác ghi riêng. |
| Ưu tiên | H |
| Tiêu chí nghiệm thu | **WEB-FR-SHOW-08-AC-01** — Với tiền điều kiện/kích hoạt, kiểm tra: Lấy suất đang mở bán theo phim; app khách hiện các suất trong 7 ngày tới. **WEB-FR-SHOW-08-AC-02** — Thử đầu vào sai/thiếu quyền/xung đột áp dụng và kiểm tra từ chối đã nêu, không đổi dữ liệu trái phép và không báo thành công sai. |
| Bằng chứng | [Cinema_BE/MovieService/MovieService/Controllers/ShowtimesController.cs](../Cinema_BE/MovieService/MovieService/Controllers/ShowtimesController.cs); [Cinema_Mobile/lib/features/movie/screens/movie_detail_screen.dart](../Cinema_Mobile/lib/features/movie/screens/movie_detail_screen.dart); [Cinema_BE/MovieService/MovieService/Service/Impl/ShowtimeService.cs](../Cinema_BE/MovieService/MovieService/Service/Impl/ShowtimeService.cs) |
| Quy tắc nghiệp vụ | WEB-BR-05, WEB-BR-06, WEB-BR-15, WEB-BR-19, WEB-BR-30 |
| Ca sử dụng / màn / API | UC-WEB-06; WEB-SCR-MOVIE; WEB-API-020 |

### WEB-FR-SHOW-09 — Tìm theo khoảng ngày

| Trường | Đặc tả |
| --- | --- |
| Tên | Tìm theo khoảng ngày |
| Mô tả | Tra suất chiếu theo khoảng thời gian (Staff/Admin). |
| Tác nhân | Nhân viên/quản trị viên |
| Tiền điều kiện | Phim và phòng tồn tại; thay đổi quản lý cần nhân viên/quản trị viên. |
| Kích hoạt | Thực hiện “Tìm theo khoảng ngày” hoặc sự kiện/tác vụ backend tương ứng. |
| Luồng chính | 1. Đọc đầu vào/tài nguyên hiện tại và phiên áp dụng. 2. Thực hiện thao tác này: Tra suất chiếu theo khoảng thời gian (Staff/Admin). 3. Trả/hiển thị kết quả chính thức và làm mới dữ liệu bị tác động sau thành công. |
| Luồng thay thế / ngoại lệ | Từ chối trùng lịch bằng 409 và giờ/định dạng sai bằng 400; suất đã huỷ là trạng thái cuối. Khách không chọn suất đóng bán hoặc đã bắt đầu. |
| Hậu điều kiện | Dữ liệu/trạng thái đủ quyền được trả/hiển thị; đọc không đổi trạng thái vé/thanh toán. Dấu đã đọc thông báo chỉ đổi bằng thao tác ghi riêng. |
| Ưu tiên | H |
| Tiêu chí nghiệm thu | **WEB-FR-SHOW-09-AC-01** — Với tiền điều kiện/kích hoạt, kiểm tra: Tra suất chiếu theo khoảng thời gian (Staff/Admin). **WEB-FR-SHOW-09-AC-02** — Thử đầu vào sai/thiếu quyền/xung đột áp dụng và kiểm tra từ chối đã nêu, không đổi dữ liệu trái phép và không báo thành công sai. |
| Bằng chứng | [Cinema_BE/MovieService/MovieService/Controllers/ShowtimesController.cs](../Cinema_BE/MovieService/MovieService/Controllers/ShowtimesController.cs); [Cinema_Mobile/lib/features/staff/screens/staff_operations_screen.dart](../Cinema_Mobile/lib/features/staff/screens/staff_operations_screen.dart); [Cinema_BE/MovieService/MovieService/Service/Impl/ShowtimeService.cs](../Cinema_BE/MovieService/MovieService/Service/Impl/ShowtimeService.cs) |
| Quy tắc nghiệp vụ | WEB-BR-05, WEB-BR-06, WEB-BR-15, WEB-BR-19, WEB-BR-30 |
| Ca sử dụng / màn / API | UC-WEB-06; WEB-SCR-OPERATIONS; WEB-API-019 |

### WEB-FR-SHOW-10 — Mở và đóng bán

| Trường | Đặc tả |
| --- | --- |
| Tên | Mở và đóng bán |
| Mô tả | Mở / đóng bán suất chiếu (`OPEN` ↔ `CLOSED`). |
| Tác nhân | Nhân viên/quản trị viên |
| Tiền điều kiện | Phim và phòng tồn tại; thay đổi quản lý cần nhân viên/quản trị viên. |
| Kích hoạt | Thực hiện “Mở và đóng bán” hoặc sự kiện/tác vụ backend tương ứng. |
| Luồng chính | 1. Đọc đầu vào/tài nguyên hiện tại và phiên áp dụng. 2. Thực hiện thao tác này: Mở / đóng bán suất chiếu (`OPEN` ↔ `CLOSED`). 3. Trả/hiển thị kết quả chính thức và làm mới dữ liệu bị tác động sau thành công. |
| Luồng thay thế / ngoại lệ | Từ chối trùng lịch bằng 409 và giờ/định dạng sai bằng 400; suất đã huỷ là trạng thái cuối. Khách không chọn suất đóng bán hoặc đã bắt đầu. |
| Hậu điều kiện | Kết quả thành công quan sát được khớp yêu cầu này; chuyển trạng thái được chỉ định được lưu. Từ chối không cấp quyền hoặc để thay đổi dở dang trái phép. |
| Ưu tiên | M |
| Tiêu chí nghiệm thu | **WEB-FR-SHOW-10-AC-01** — Với tiền điều kiện/kích hoạt, kiểm tra: Mở / đóng bán suất chiếu (`OPEN` ↔ `CLOSED`). **WEB-FR-SHOW-10-AC-02** — Thử đầu vào sai/thiếu quyền/xung đột áp dụng và kiểm tra từ chối đã nêu, không đổi dữ liệu trái phép và không báo thành công sai. |
| Bằng chứng | [Cinema_BE/MovieService/MovieService/Controllers/ShowtimesController.cs](../Cinema_BE/MovieService/MovieService/Controllers/ShowtimesController.cs); [Cinema_Mobile/lib/features/staff/screens/staff_record_screen.dart](../Cinema_Mobile/lib/features/staff/screens/staff_record_screen.dart); [Cinema_BE/MovieService/MovieService/Service/Impl/ShowtimeService.cs](../Cinema_BE/MovieService/MovieService/Service/Impl/ShowtimeService.cs) |
| Quy tắc nghiệp vụ | WEB-BR-05, WEB-BR-06, WEB-BR-15, WEB-BR-19, WEB-BR-30 |
| Ca sử dụng / màn / API | UC-WEB-06; WEB-SCR-RECORD-SHOWTIMES; WEB-API-015 |

### WEB-FR-SHOW-11 — Từ chối trùng lịch

| Trường | Đặc tả |
| --- | --- |
| Tên | Từ chối trùng lịch |
| Mô tả | Trùng lịch trong cùng phòng trả 409. |
| Tác nhân | Nhân viên/quản trị viên |
| Tiền điều kiện | Phim và phòng tồn tại; thay đổi quản lý cần nhân viên/quản trị viên. |
| Kích hoạt | Thực hiện “Từ chối trùng lịch” hoặc sự kiện/tác vụ backend tương ứng. |
| Luồng chính | 1. Đọc đầu vào/tài nguyên hiện tại và phiên áp dụng. 2. Thực hiện thao tác này: Trùng lịch trong cùng phòng trả 409. 3. Trả/hiển thị kết quả chính thức và làm mới dữ liệu bị tác động sau thành công. |
| Luồng thay thế / ngoại lệ | Từ chối trùng lịch bằng 409 và giờ/định dạng sai bằng 400; suất đã huỷ là trạng thái cuối. Khách không chọn suất đóng bán hoặc đã bắt đầu. |
| Hậu điều kiện | Kết quả thành công quan sát được khớp yêu cầu này; chuyển trạng thái được chỉ định được lưu. Từ chối không cấp quyền hoặc để thay đổi dở dang trái phép. |
| Ưu tiên | H |
| Tiêu chí nghiệm thu | **WEB-FR-SHOW-11-AC-01** — Với tiền điều kiện/kích hoạt, kiểm tra: Trùng lịch trong cùng phòng trả 409. **WEB-FR-SHOW-11-AC-02** — Thử đầu vào sai/thiếu quyền/xung đột áp dụng và kiểm tra từ chối đã nêu, không đổi dữ liệu trái phép và không báo thành công sai. |
| Bằng chứng | [Cinema_BE/MovieService/MovieService/Controllers/ShowtimesController.cs](../Cinema_BE/MovieService/MovieService/Controllers/ShowtimesController.cs); [Cinema_Mobile/lib/features/staff/screens/staff_showtime_editor_screen.dart](../Cinema_Mobile/lib/features/staff/screens/staff_showtime_editor_screen.dart); [Cinema_BE/MovieService/MovieService/Service/Impl/ShowtimeService.cs](../Cinema_BE/MovieService/MovieService/Service/Impl/ShowtimeService.cs) |
| Quy tắc nghiệp vụ | WEB-BR-05, WEB-BR-06, WEB-BR-15, WEB-BR-19, WEB-BR-30 |
| Ca sử dụng / màn / API | UC-WEB-06; WEB-SCR-SHOW-EDITOR; WEB-API-018, WEB-API-024 |

### WEB-FR-SHOW-12 — Sơ đồ ghế/khách của suất

| Trường | Đặc tả |
| --- | --- |
| Tên | Sơ đồ ghế/khách của suất |
| Mô tả | Sơ đồ ghế của suất chiếu cho Staff: ghế trống / chờ thanh toán / đã bán / đã check-in, bấm ghế mở vé, kèm danh sách khách (email, ghế, mã vé, giờ check-in); tự làm mới mỗi 5 giây. |
| Tác nhân | Nhân viên/quản trị viên |
| Tiền điều kiện | Phim và phòng tồn tại; thay đổi quản lý cần nhân viên/quản trị viên. |
| Kích hoạt | Thực hiện “Sơ đồ ghế/khách của suất” hoặc sự kiện/tác vụ backend tương ứng. |
| Luồng chính | 1. Đọc đầu vào/tài nguyên hiện tại và phiên áp dụng. 2. Thực hiện thao tác này: Sơ đồ ghế của suất chiếu cho Staff: ghế trống / chờ thanh toán / đã bán / đã check-in, bấm ghế mở vé, kèm danh sách khách (email, ghế, mã vé, giờ check-in); tự làm mới mỗi 5 giây. 3. Trả/hiển thị kết quả chính thức và làm mới dữ liệu bị tác động sau thành công. |
| Luồng thay thế / ngoại lệ | Từ chối trùng lịch bằng 409 và giờ/định dạng sai bằng 400; suất đã huỷ là trạng thái cuối. Khách không chọn suất đóng bán hoặc đã bắt đầu. |
| Hậu điều kiện | Dữ liệu/trạng thái đủ quyền được trả/hiển thị; đọc không đổi trạng thái vé/thanh toán. Dấu đã đọc thông báo chỉ đổi bằng thao tác ghi riêng. |
| Ưu tiên | M |
| Tiêu chí nghiệm thu | **WEB-FR-SHOW-12-AC-01** — Với tiền điều kiện/kích hoạt, kiểm tra: Sơ đồ ghế của suất chiếu cho Staff: ghế trống / chờ thanh toán / đã bán / đã check-in, bấm ghế mở vé, kèm danh sách khách (email, ghế, mã vé, giờ check-in); tự làm mới mỗi 5 giây. **WEB-FR-SHOW-12-AC-02** — Thử đầu vào sai/thiếu quyền/xung đột áp dụng và kiểm tra từ chối đã nêu, không đổi dữ liệu trái phép và không báo thành công sai. |
| Bằng chứng | [Cinema_BE/MovieService/MovieService/Controllers/SeatsController.cs](../Cinema_BE/MovieService/MovieService/Controllers/SeatsController.cs); [Cinema_BE/MovieService/MovieService/Controllers/ShowtimesController.cs](../Cinema_BE/MovieService/MovieService/Controllers/ShowtimesController.cs); [Cinema_BE/BookingService/BookingService/Controllers/BookingController.cs](../Cinema_BE/BookingService/BookingService/Controllers/BookingController.cs); [Cinema_Mobile/lib/features/staff/screens/staff_record_screen.dart](../Cinema_Mobile/lib/features/staff/screens/staff_record_screen.dart); [Cinema_BE/MovieService/MovieService/Service/Impl/ShowtimeService.cs](../Cinema_BE/MovieService/MovieService/Service/Impl/ShowtimeService.cs) |
| Quy tắc nghiệp vụ | WEB-BR-05, WEB-BR-06, WEB-BR-15, WEB-BR-19, WEB-BR-30 |
| Ca sử dụng / màn / API | UC-WEB-06; WEB-SCR-RECORD-SHOWTIMES; WEB-API-013, WEB-API-017, WEB-API-050 |

### WEB-FR-SHOW-13 — Định dạng chiếu

| Trường | Đặc tả |
| --- | --- |
| Tên | Định dạng chiếu |
| Mô tả | Mỗi suất chiếu có **định dạng 2D / 3D / IMAX** (mặc định 2D, bỏ trống khi sửa thì giữ nguyên, định dạng khác bị 400). Giá suất lưu là giá ghế thường ở 2D; 3D cộng 20.000đ, IMAX cộng 40.000đ vào giá ghế thường rồi mới tính phụ thu VIP / sweetbox. Giá ghế khách thấy và giá BookingService tính tiền đều gồm phụ thu. App ghi định dạng cạnh số phòng (ví dụ "Room 1 · IMAX"). |
| Tác nhân | Khách chưa đăng nhập/khách hàng xem suất công khai; nhân viên/quản trị viên quản lý |
| Tiền điều kiện | Phim và phòng tồn tại; thay đổi quản lý cần nhân viên/quản trị viên. |
| Kích hoạt | Thực hiện “Định dạng chiếu” hoặc sự kiện/tác vụ backend tương ứng. |
| Luồng chính | 1. Đọc đầu vào/tài nguyên hiện tại và phiên áp dụng. 2. Thực hiện thao tác này: Mỗi suất chiếu có **định dạng 2D / 3D / IMAX** (mặc định 2D, bỏ trống khi sửa thì giữ nguyên, định dạng khác bị 400). Giá suất lưu là giá ghế thường ở 2D; 3D cộng 20.000đ, IMAX cộng 40.000đ vào giá ghế thường rồi mới tính phụ thu VIP / sweetbox. Giá ghế khách thấy và giá BookingService tính tiền đều gồm phụ thu. App ghi định dạng cạnh số phòng (ví dụ "Room 1 · IMAX"). 3. Trả/hiển thị kết quả chính thức và làm mới dữ liệu bị tác động sau thành công. |
| Luồng thay thế / ngoại lệ | Từ chối trùng lịch bằng 409 và giờ/định dạng sai bằng 400; suất đã huỷ là trạng thái cuối. Khách không chọn suất đóng bán hoặc đã bắt đầu. |
| Hậu điều kiện | Kết quả thành công quan sát được khớp yêu cầu này; chuyển trạng thái được chỉ định được lưu. Từ chối không cấp quyền hoặc để thay đổi dở dang trái phép. |
| Ưu tiên | M |
| Tiêu chí nghiệm thu | **WEB-FR-SHOW-13-AC-01** — Với tiền điều kiện/kích hoạt, kiểm tra: Mỗi suất chiếu có **định dạng 2D / 3D / IMAX** (mặc định 2D, bỏ trống khi sửa thì giữ nguyên, định dạng khác bị 400). Giá suất lưu là giá ghế thường ở 2D; 3D cộng 20.000đ, IMAX cộng 40.000đ vào giá ghế thường rồi mới tính phụ thu VIP / sweetbox. Giá ghế khách thấy và giá BookingService tính tiền đều gồm phụ thu. App ghi định dạng cạnh số phòng (ví dụ "Room 1 · IMAX"). **WEB-FR-SHOW-13-AC-02** — Thử đầu vào sai/thiếu quyền/xung đột áp dụng và kiểm tra từ chối đã nêu, không đổi dữ liệu trái phép và không báo thành công sai. |
| Bằng chứng | [Cinema_BE/MovieService/MovieService/Controllers/ShowtimesController.cs](../Cinema_BE/MovieService/MovieService/Controllers/ShowtimesController.cs); [Cinema_Mobile/lib/features/movie/screens/movie_detail_screen.dart](../Cinema_Mobile/lib/features/movie/screens/movie_detail_screen.dart); [Cinema_Mobile/lib/features/seat/screens/seat_selection_screen.dart](../Cinema_Mobile/lib/features/seat/screens/seat_selection_screen.dart); [Cinema_Mobile/lib/features/staff/screens/staff_showtime_editor_screen.dart](../Cinema_Mobile/lib/features/staff/screens/staff_showtime_editor_screen.dart); [Cinema_BE/MovieService/MovieService/Service/Impl/ShowtimeService.cs](../Cinema_BE/MovieService/MovieService/Service/Impl/ShowtimeService.cs) |
| Quy tắc nghiệp vụ | WEB-BR-05, WEB-BR-06, WEB-BR-15, WEB-BR-19, WEB-BR-30 |
| Ca sử dụng / màn / API | UC-WEB-06; WEB-SCR-MOVIE, WEB-SCR-SEATS, WEB-SCR-SHOW-EDITOR; WEB-API-017, WEB-API-018, WEB-API-024 |

### WEB-FR-BOOK-01 — Giữ chỗ đặt vé

| Trường | Đặc tả |
| --- | --- |
| Tên | Giữ chỗ đặt vé |
| Mô tả | Tạo booking từ suất chiếu và danh sách ghế: suất phải `OPEN` và chưa bắt đầu, ít nhất một ghế, không trùng ghế. Server lấy giờ chiếu, tên phim và giá từ MovieService. Booking `PENDING`, giữ ghế 10 phút. |
| Tác nhân | Khách hàng sở hữu vé trực tuyến; nhân viên/quản trị viên thực hiện nghiệp vụ quầy và quản lý |
| Tiền điều kiện | Khách đã đăng nhập chọn suất OPEN chưa bắt đầu và ghế; khách vãng lai tại quầy được nhân viên/quản trị viên thao tác thay. |
| Kích hoạt | Thực hiện “Giữ chỗ đặt vé” hoặc sự kiện/tác vụ backend tương ứng. |
| Luồng chính | 1. Đọc đầu vào/tài nguyên hiện tại và phiên áp dụng. 2. Thực hiện thao tác này: Tạo booking từ suất chiếu và danh sách ghế: suất phải `OPEN` và chưa bắt đầu, ít nhất một ghế, không trùng ghế. Server lấy giờ chiếu, tên phim và giá từ MovieService. Booking `PENDING`, giữ ghế 10 phút. 3. Trả/hiển thị kết quả chính thức và làm mới dữ liệu bị tác động sau thành công. |
| Luồng thay thế / ngoại lệ | Giữ chỗ đồng thời trả 409 và không được thu tiền hoặc để lại ghế/điểm dở dang. Bắp nước/mã/điểm sai trả lỗi kiểm tra. Hết hạn nhả ghế và trả điểm đã giữ. |
| Hậu điều kiện | Một vé PENDING có tổng tiền server và expiresAt được commit; ghế HELD mười phút. Giao dịch bị từ chối không để giữ ghế hoặc trừ điểm dở dang. |
| Ưu tiên | H |
| Tiêu chí nghiệm thu | **WEB-FR-BOOK-01-AC-01** — Với tiền điều kiện/kích hoạt, kiểm tra: Tạo booking từ suất chiếu và danh sách ghế: suất phải `OPEN` và chưa bắt đầu, ít nhất một ghế, không trùng ghế. Server lấy giờ chiếu, tên phim và giá từ MovieService. Booking `PENDING`, giữ ghế 10 phút. **WEB-FR-BOOK-01-AC-02** — Thử đầu vào sai/thiếu quyền/xung đột áp dụng và kiểm tra từ chối đã nêu, không đổi dữ liệu trái phép và không báo thành công sai. |
| Bằng chứng | [Cinema_BE/BookingService/BookingService/Controllers/BookingController.cs](../Cinema_BE/BookingService/BookingService/Controllers/BookingController.cs); [Cinema_Mobile/lib/features/booking/screens/booking_summary_screen.dart](../Cinema_Mobile/lib/features/booking/screens/booking_summary_screen.dart); [Cinema_BE/BookingService/BookingService/Services/Implementations/BookingService.cs](../Cinema_BE/BookingService/BookingService/Services/Implementations/BookingService.cs); [Cinema_BE/BookingService/BookingService/Helpers/PromotionRules.cs](../Cinema_BE/BookingService/BookingService/Helpers/PromotionRules.cs); [Cinema_BE/BookingService/BookingService/Helpers/LoyaltyRules.cs](../Cinema_BE/BookingService/BookingService/Helpers/LoyaltyRules.cs) |
| Quy tắc nghiệp vụ | WEB-BR-07, WEB-BR-08, WEB-BR-14, WEB-BR-15, WEB-BR-16, WEB-BR-17, WEB-BR-27, WEB-BR-28, WEB-BR-29 |
| Ca sử dụng / màn / API | UC-WEB-07; WEB-SCR-SUMMARY; WEB-API-055 |

### WEB-FR-BOOK-02 — Chi tiết vé

| Trường | Đặc tả |
| --- | --- |
| Tên | Chi tiết vé |
| Mô tả | Xem chi tiết booking: chủ vé hoặc Staff/Admin. |
| Tác nhân | Khách hàng sở hữu vé trực tuyến; nhân viên/quản trị viên thực hiện nghiệp vụ quầy và quản lý |
| Tiền điều kiện | Khách đã đăng nhập và sở hữu vé liên quan; thao tác phải được trạng thái và giờ vé cho phép. Quyền nhân viên chỉ áp dụng nơi đã nêu. |
| Kích hoạt | Thực hiện “Chi tiết vé” hoặc sự kiện/tác vụ backend tương ứng. |
| Luồng chính | 1. Đọc đầu vào/tài nguyên hiện tại và phiên áp dụng. 2. Thực hiện thao tác này: Xem chi tiết booking: chủ vé hoặc Staff/Admin. 3. Trả/hiển thị kết quả chính thức và làm mới dữ liệu bị tác động sau thành công. |
| Luồng thay thế / ngoại lệ | Giữ chỗ đồng thời trả 409 và không được thu tiền hoặc để lại ghế/điểm dở dang. Bắp nước/mã/điểm sai trả lỗi kiểm tra. Hết hạn nhả ghế và trả điểm đã giữ. |
| Hậu điều kiện | Dữ liệu/trạng thái đủ quyền được trả/hiển thị; đọc không đổi trạng thái vé/thanh toán. Dấu đã đọc thông báo chỉ đổi bằng thao tác ghi riêng. |
| Ưu tiên | H |
| Tiêu chí nghiệm thu | **WEB-FR-BOOK-02-AC-01** — Với tiền điều kiện/kích hoạt, kiểm tra: Xem chi tiết booking: chủ vé hoặc Staff/Admin. **WEB-FR-BOOK-02-AC-02** — Thử đầu vào sai/thiếu quyền/xung đột áp dụng và kiểm tra từ chối đã nêu, không đổi dữ liệu trái phép và không báo thành công sai. |
| Bằng chứng | [Cinema_BE/BookingService/BookingService/Controllers/BookingController.cs](../Cinema_BE/BookingService/BookingService/Controllers/BookingController.cs); [Cinema_Mobile/lib/features/payment/screens/payment_result_screen.dart](../Cinema_Mobile/lib/features/payment/screens/payment_result_screen.dart); [Cinema_Mobile/lib/features/booking/screens/booking_detail_screen.dart](../Cinema_Mobile/lib/features/booking/screens/booking_detail_screen.dart); [Cinema_Mobile/lib/features/staff/screens/staff_record_screen.dart](../Cinema_Mobile/lib/features/staff/screens/staff_record_screen.dart); [Cinema_BE/BookingService/BookingService/Services/Implementations/BookingService.cs](../Cinema_BE/BookingService/BookingService/Services/Implementations/BookingService.cs); [Cinema_BE/BookingService/BookingService/Helpers/PromotionRules.cs](../Cinema_BE/BookingService/BookingService/Helpers/PromotionRules.cs); [Cinema_BE/BookingService/BookingService/Helpers/LoyaltyRules.cs](../Cinema_BE/BookingService/BookingService/Helpers/LoyaltyRules.cs) |
| Quy tắc nghiệp vụ | WEB-BR-07, WEB-BR-08, WEB-BR-14, WEB-BR-15, WEB-BR-16, WEB-BR-17, WEB-BR-27, WEB-BR-28, WEB-BR-29 |
| Ca sử dụng / màn / API | UC-WEB-07; WEB-SCR-RESULT, WEB-SCR-TICKET, WEB-SCR-RECORD-BOOKINGS; WEB-API-046 |

### WEB-FR-BOOK-03 — Tra vé quản lý

| Trường | Đặc tả |
| --- | --- |
| Tên | Tra vé quản lý |
| Mô tả | Staff/Admin xem danh sách booking, lọc theo trạng thái và ngày tạo. |
| Tác nhân | Nhân viên/quản trị viên |
| Tiền điều kiện | Khách đã đăng nhập chọn suất OPEN chưa bắt đầu và ghế; khách vãng lai tại quầy được nhân viên/quản trị viên thao tác thay. |
| Kích hoạt | Thực hiện “Tra vé quản lý” hoặc sự kiện/tác vụ backend tương ứng. |
| Luồng chính | 1. Đọc đầu vào/tài nguyên hiện tại và phiên áp dụng. 2. Thực hiện thao tác này: Staff/Admin xem danh sách booking, lọc theo trạng thái và ngày tạo. 3. Trả/hiển thị kết quả chính thức và làm mới dữ liệu bị tác động sau thành công. |
| Luồng thay thế / ngoại lệ | Giữ chỗ đồng thời trả 409 và không được thu tiền hoặc để lại ghế/điểm dở dang. Bắp nước/mã/điểm sai trả lỗi kiểm tra. Hết hạn nhả ghế và trả điểm đã giữ. |
| Hậu điều kiện | Dữ liệu/trạng thái đủ quyền được trả/hiển thị; đọc không đổi trạng thái vé/thanh toán. Dấu đã đọc thông báo chỉ đổi bằng thao tác ghi riêng. |
| Ưu tiên | H |
| Tiêu chí nghiệm thu | **WEB-FR-BOOK-03-AC-01** — Với tiền điều kiện/kích hoạt, kiểm tra: Staff/Admin xem danh sách booking, lọc theo trạng thái và ngày tạo. **WEB-FR-BOOK-03-AC-02** — Thử đầu vào sai/thiếu quyền/xung đột áp dụng và kiểm tra từ chối đã nêu, không đổi dữ liệu trái phép và không báo thành công sai. |
| Bằng chứng | [Cinema_BE/BookingService/BookingService/Controllers/BookingController.cs](../Cinema_BE/BookingService/BookingService/Controllers/BookingController.cs); [Cinema_Mobile/lib/features/staff/screens/staff_operations_screen.dart](../Cinema_Mobile/lib/features/staff/screens/staff_operations_screen.dart); [Cinema_BE/BookingService/BookingService/Services/Implementations/BookingService.cs](../Cinema_BE/BookingService/BookingService/Services/Implementations/BookingService.cs); [Cinema_BE/BookingService/BookingService/Helpers/PromotionRules.cs](../Cinema_BE/BookingService/BookingService/Helpers/PromotionRules.cs); [Cinema_BE/BookingService/BookingService/Helpers/LoyaltyRules.cs](../Cinema_BE/BookingService/BookingService/Helpers/LoyaltyRules.cs) |
| Quy tắc nghiệp vụ | WEB-BR-07, WEB-BR-08, WEB-BR-14, WEB-BR-15, WEB-BR-16, WEB-BR-17, WEB-BR-27, WEB-BR-28, WEB-BR-29 |
| Ca sử dụng / màn / API | UC-WEB-07; WEB-SCR-OPERATIONS; WEB-API-048, WEB-API-052, WEB-API-054 |

### WEB-FR-BOOK-04 — Lịch sử vé của mình

| Trường | Đặc tả |
| --- | --- |
| Tên | Lịch sử vé của mình |
| Mô tả | Khách xem vé của mình, chia **Active** và **History**. |
| Tác nhân | Khách hàng sở hữu vé trực tuyến; nhân viên/quản trị viên thực hiện nghiệp vụ quầy và quản lý |
| Tiền điều kiện | Khách đã đăng nhập và sở hữu vé liên quan; thao tác phải được trạng thái và giờ vé cho phép. Quyền nhân viên chỉ áp dụng nơi đã nêu. |
| Kích hoạt | Thực hiện “Lịch sử vé của mình” hoặc sự kiện/tác vụ backend tương ứng. |
| Luồng chính | 1. Đọc đầu vào/tài nguyên hiện tại và phiên áp dụng. 2. Thực hiện thao tác này: Khách xem vé của mình, chia **Active** và **History**. 3. Trả/hiển thị kết quả chính thức và làm mới dữ liệu bị tác động sau thành công. |
| Luồng thay thế / ngoại lệ | Giữ chỗ đồng thời trả 409 và không được thu tiền hoặc để lại ghế/điểm dở dang. Bắp nước/mã/điểm sai trả lỗi kiểm tra. Hết hạn nhả ghế và trả điểm đã giữ. |
| Hậu điều kiện | Dữ liệu/trạng thái đủ quyền được trả/hiển thị; đọc không đổi trạng thái vé/thanh toán. Dấu đã đọc thông báo chỉ đổi bằng thao tác ghi riêng. |
| Ưu tiên | H |
| Tiêu chí nghiệm thu | **WEB-FR-BOOK-04-AC-01** — Với tiền điều kiện/kích hoạt, kiểm tra: Khách xem vé của mình, chia **Active** và **History**. **WEB-FR-BOOK-04-AC-02** — Thử đầu vào sai/thiếu quyền/xung đột áp dụng và kiểm tra từ chối đã nêu, không đổi dữ liệu trái phép và không báo thành công sai. |
| Bằng chứng | [Cinema_BE/BookingService/BookingService/Controllers/BookingController.cs](../Cinema_BE/BookingService/BookingService/Controllers/BookingController.cs); [Cinema_Mobile/lib/features/booking/screens/my_bookings_screen.dart](../Cinema_Mobile/lib/features/booking/screens/my_bookings_screen.dart); [Cinema_BE/BookingService/BookingService/Services/Implementations/BookingService.cs](../Cinema_BE/BookingService/BookingService/Services/Implementations/BookingService.cs); [Cinema_BE/BookingService/BookingService/Helpers/PromotionRules.cs](../Cinema_BE/BookingService/BookingService/Helpers/PromotionRules.cs); [Cinema_BE/BookingService/BookingService/Helpers/LoyaltyRules.cs](../Cinema_BE/BookingService/BookingService/Helpers/LoyaltyRules.cs) |
| Quy tắc nghiệp vụ | WEB-BR-07, WEB-BR-08, WEB-BR-14, WEB-BR-15, WEB-BR-16, WEB-BR-17, WEB-BR-27, WEB-BR-28, WEB-BR-29 |
| Ca sử dụng / màn / API | UC-WEB-07; WEB-SCR-TICKETS; WEB-API-053 |

### WEB-FR-BOOK-05 — Xác nhận vé đã trả

| Trường | Đặc tả |
| --- | --- |
| Tên | Xác nhận vé đã trả |
| Mô tả | Xác nhận booking sau khi thanh toán thành công (chi tiết ở PAY và POS). |
| Tác nhân | Hệ thống backend chung; khách nhận kết quả |
| Tiền điều kiện | Có sự kiện đã commit, kết quả PayOS tin cậy hoặc điều kiện tác vụ tương ứng; backend đã cấu hình xử lý. Tác vụ nền hoặc webhook chữ ký không cần phiên khách. |
| Kích hoạt | Thực hiện “Xác nhận vé đã trả” hoặc sự kiện/tác vụ backend tương ứng. |
| Luồng chính | 1. Đọc đầu vào/tài nguyên hiện tại và phiên áp dụng. 2. Thực hiện thao tác này: Xác nhận booking sau khi thanh toán thành công (chi tiết ở PAY và POS). 3. Trả/hiển thị kết quả chính thức và làm mới dữ liệu bị tác động sau thành công. |
| Luồng thay thế / ngoại lệ | Giữ chỗ đồng thời trả 409 và không được thu tiền hoặc để lại ghế/điểm dở dang. Bắp nước/mã/điểm sai trả lỗi kiểm tra. Hết hạn nhả ghế và trả điểm đã giữ. |
| Hậu điều kiện | Kết quả thành công quan sát được khớp yêu cầu này; chuyển trạng thái được chỉ định được lưu. Từ chối không cấp quyền hoặc để thay đổi dở dang trái phép. |
| Ưu tiên | H |
| Tiêu chí nghiệm thu | **WEB-FR-BOOK-05-AC-01** — Với tiền điều kiện/kích hoạt, kiểm tra: Xác nhận booking sau khi thanh toán thành công (chi tiết ở PAY và POS). **WEB-FR-BOOK-05-AC-02** — Thử đầu vào sai/thiếu quyền/xung đột áp dụng và kiểm tra từ chối đã nêu, không đổi dữ liệu trái phép và không báo thành công sai. |
| Bằng chứng | [Cinema_BE/BookingService/BookingService/Controllers/PaymentController.cs](../Cinema_BE/BookingService/BookingService/Controllers/PaymentController.cs); [Cinema_Mobile/lib/features/payment/screens/payment_screen.dart](../Cinema_Mobile/lib/features/payment/screens/payment_screen.dart); [Cinema_Mobile/lib/features/payment/screens/payment_result_screen.dart](../Cinema_Mobile/lib/features/payment/screens/payment_result_screen.dart); [Cinema_Mobile/lib/features/booking/screens/booking_detail_screen.dart](../Cinema_Mobile/lib/features/booking/screens/booking_detail_screen.dart); [Cinema_BE/BookingService/BookingService/Services/Implementations/BookingService.cs](../Cinema_BE/BookingService/BookingService/Services/Implementations/BookingService.cs); [Cinema_BE/BookingService/BookingService/Helpers/PromotionRules.cs](../Cinema_BE/BookingService/BookingService/Helpers/PromotionRules.cs); [Cinema_BE/BookingService/BookingService/Helpers/LoyaltyRules.cs](../Cinema_BE/BookingService/BookingService/Helpers/LoyaltyRules.cs) |
| Quy tắc nghiệp vụ | WEB-BR-07, WEB-BR-08, WEB-BR-14, WEB-BR-15, WEB-BR-16, WEB-BR-17, WEB-BR-27, WEB-BR-28, WEB-BR-29 |
| Ca sử dụng / màn / API | UC-WEB-07; WEB-SCR-PAYMENT, WEB-SCR-RESULT, WEB-SCR-TICKET; WEB-API-086, WEB-API-087, WEB-API-089 |

### WEB-FR-BOOK-06 — Huỷ vé

| Trường | Đặc tả |
| --- | --- |
| Tên | Huỷ vé |
| Mô tả | Huỷ booking: vé chờ thanh toán thì huỷ và nhả ghế; vé đã thanh toán thì theo WEB-BR-17. Khách huỷ vé đã thanh toán tạo yêu cầu hoàn tiền: booking `REFUND_PENDING` và vẫn giữ ghế cho tới khi Staff xử lý. |
| Tác nhân | Khách hàng sở hữu vé trực tuyến; nhân viên/quản trị viên thực hiện nghiệp vụ quầy và quản lý |
| Tiền điều kiện | Khách đã đăng nhập và sở hữu vé liên quan; thao tác phải được trạng thái và giờ vé cho phép. Quyền nhân viên chỉ áp dụng nơi đã nêu. |
| Kích hoạt | Thực hiện “Huỷ vé” hoặc sự kiện/tác vụ backend tương ứng. |
| Luồng chính | 1. Đọc đầu vào/tài nguyên hiện tại và phiên áp dụng. 2. Thực hiện thao tác này: Huỷ booking: vé chờ thanh toán thì huỷ và nhả ghế; vé đã thanh toán thì theo WEB-BR-17. Khách huỷ vé đã thanh toán tạo yêu cầu hoàn tiền: booking `REFUND_PENDING` và vẫn giữ ghế cho tới khi Staff xử lý. 3. Trả/hiển thị kết quả chính thức và làm mới dữ liệu bị tác động sau thành công. |
| Luồng thay thế / ngoại lệ | Giữ chỗ đồng thời trả 409 và không được thu tiền hoặc để lại ghế/điểm dở dang. Bắp nước/mã/điểm sai trả lỗi kiểm tra. Hết hạn nhả ghế và trả điểm đã giữ. |
| Hậu điều kiện | Kết quả thành công quan sát được khớp yêu cầu này; chuyển trạng thái được chỉ định được lưu. Từ chối không cấp quyền hoặc để thay đổi dở dang trái phép. |
| Ưu tiên | H |
| Tiêu chí nghiệm thu | **WEB-FR-BOOK-06-AC-01** — Với tiền điều kiện/kích hoạt, kiểm tra: Huỷ booking: vé chờ thanh toán thì huỷ và nhả ghế; vé đã thanh toán thì theo WEB-BR-17. Khách huỷ vé đã thanh toán tạo yêu cầu hoàn tiền: booking `REFUND_PENDING` và vẫn giữ ghế cho tới khi Staff xử lý. **WEB-FR-BOOK-06-AC-02** — Thử đầu vào sai/thiếu quyền/xung đột áp dụng và kiểm tra từ chối đã nêu, không đổi dữ liệu trái phép và không báo thành công sai. |
| Bằng chứng | [Cinema_BE/BookingService/BookingService/Controllers/BookingController.cs](../Cinema_BE/BookingService/BookingService/Controllers/BookingController.cs); [Cinema_Mobile/lib/features/booking/screens/booking_detail_screen.dart](../Cinema_Mobile/lib/features/booking/screens/booking_detail_screen.dart); [Cinema_Mobile/lib/features/staff/screens/staff_record_screen.dart](../Cinema_Mobile/lib/features/staff/screens/staff_record_screen.dart); [Cinema_BE/BookingService/BookingService/Services/Implementations/BookingService.cs](../Cinema_BE/BookingService/BookingService/Services/Implementations/BookingService.cs); [Cinema_BE/BookingService/BookingService/Helpers/PromotionRules.cs](../Cinema_BE/BookingService/BookingService/Helpers/PromotionRules.cs); [Cinema_BE/BookingService/BookingService/Helpers/LoyaltyRules.cs](../Cinema_BE/BookingService/BookingService/Helpers/LoyaltyRules.cs) |
| Quy tắc nghiệp vụ | WEB-BR-07, WEB-BR-08, WEB-BR-14, WEB-BR-15, WEB-BR-16, WEB-BR-17, WEB-BR-27, WEB-BR-28, WEB-BR-29 |
| Ca sử dụng / màn / API | UC-WEB-07; WEB-SCR-TICKET, WEB-SCR-RECORD-BOOKINGS; WEB-API-043 |

### WEB-FR-BOOK-07 — ID ghế đã chiếm

| Trường | Đặc tả |
| --- | --- |
| Tên | ID ghế đã chiếm |
| Mô tả | Lấy các ghế đã giữ / đã bán của một suất chiếu. |
| Tác nhân | Khách hàng sở hữu vé trực tuyến; nhân viên/quản trị viên thực hiện nghiệp vụ quầy và quản lý |
| Tiền điều kiện | Khách đã đăng nhập chọn suất OPEN chưa bắt đầu và ghế; khách vãng lai tại quầy được nhân viên/quản trị viên thao tác thay. |
| Kích hoạt | Thực hiện “ID ghế đã chiếm” hoặc sự kiện/tác vụ backend tương ứng. |
| Luồng chính | 1. Đọc đầu vào/tài nguyên hiện tại và phiên áp dụng. 2. Thực hiện thao tác này: Lấy các ghế đã giữ / đã bán của một suất chiếu. 3. Trả/hiển thị kết quả chính thức và làm mới dữ liệu bị tác động sau thành công. |
| Luồng thay thế / ngoại lệ | Giữ chỗ đồng thời trả 409 và không được thu tiền hoặc để lại ghế/điểm dở dang. Bắp nước/mã/điểm sai trả lỗi kiểm tra. Hết hạn nhả ghế và trả điểm đã giữ. |
| Hậu điều kiện | Dữ liệu/trạng thái đủ quyền được trả/hiển thị; đọc không đổi trạng thái vé/thanh toán. Dấu đã đọc thông báo chỉ đổi bằng thao tác ghi riêng. |
| Ưu tiên | H |
| Tiêu chí nghiệm thu | **WEB-FR-BOOK-07-AC-01** — Với tiền điều kiện/kích hoạt, kiểm tra: Lấy các ghế đã giữ / đã bán của một suất chiếu. **WEB-FR-BOOK-07-AC-02** — Thử đầu vào sai/thiếu quyền/xung đột áp dụng và kiểm tra từ chối đã nêu, không đổi dữ liệu trái phép và không báo thành công sai. |
| Bằng chứng | [Cinema_BE/BookingService/BookingService/Controllers/BookingController.cs](../Cinema_BE/BookingService/BookingService/Controllers/BookingController.cs); [Cinema_Mobile/lib/features/seat/screens/seat_selection_screen.dart](../Cinema_Mobile/lib/features/seat/screens/seat_selection_screen.dart); [Cinema_BE/BookingService/BookingService/Services/Implementations/BookingService.cs](../Cinema_BE/BookingService/BookingService/Services/Implementations/BookingService.cs); [Cinema_BE/BookingService/BookingService/Helpers/PromotionRules.cs](../Cinema_BE/BookingService/BookingService/Helpers/PromotionRules.cs); [Cinema_BE/BookingService/BookingService/Helpers/LoyaltyRules.cs](../Cinema_BE/BookingService/BookingService/Helpers/LoyaltyRules.cs) |
| Quy tắc nghiệp vụ | WEB-BR-07, WEB-BR-08, WEB-BR-14, WEB-BR-15, WEB-BR-16, WEB-BR-17, WEB-BR-27, WEB-BR-28, WEB-BR-29 |
| Ca sử dụng / màn / API | UC-WEB-07; WEB-SCR-SEATS; WEB-API-049 |

### WEB-FR-BOOK-08 — Xung đột ghế đồng thời

| Trường | Đặc tả |
| --- | --- |
| Tên | Xung đột ghế đồng thời |
| Mô tả | Ghế đang được booking khác giữ hoặc đã bán thì trả 409. |
| Tác nhân | Hệ thống backend chung; khách nhận kết quả |
| Tiền điều kiện | Khách đã đăng nhập chọn suất OPEN chưa bắt đầu và ghế; khách vãng lai tại quầy được nhân viên/quản trị viên thao tác thay. |
| Kích hoạt | Thực hiện “Xung đột ghế đồng thời” hoặc sự kiện/tác vụ backend tương ứng. |
| Luồng chính | 1. Đọc đầu vào/tài nguyên hiện tại và phiên áp dụng. 2. Thực hiện thao tác này: Ghế đang được booking khác giữ hoặc đã bán thì trả 409. 3. Trả/hiển thị kết quả chính thức và làm mới dữ liệu bị tác động sau thành công. |
| Luồng thay thế / ngoại lệ | Giữ chỗ đồng thời trả 409 và không được thu tiền hoặc để lại ghế/điểm dở dang. Bắp nước/mã/điểm sai trả lỗi kiểm tra. Hết hạn nhả ghế và trả điểm đã giữ. |
| Hậu điều kiện | Kết quả thành công quan sát được khớp yêu cầu này; chuyển trạng thái được chỉ định được lưu. Từ chối không cấp quyền hoặc để thay đổi dở dang trái phép. |
| Ưu tiên | H |
| Tiêu chí nghiệm thu | **WEB-FR-BOOK-08-AC-01** — Với tiền điều kiện/kích hoạt, kiểm tra: Ghế đang được booking khác giữ hoặc đã bán thì trả 409. **WEB-FR-BOOK-08-AC-02** — Thử đầu vào sai/thiếu quyền/xung đột áp dụng và kiểm tra từ chối đã nêu, không đổi dữ liệu trái phép và không báo thành công sai. |
| Bằng chứng | [Cinema_BE/BookingService/BookingService/Controllers/BookingController.cs](../Cinema_BE/BookingService/BookingService/Controllers/BookingController.cs); [Cinema_Mobile/lib/features/seat/screens/seat_selection_screen.dart](../Cinema_Mobile/lib/features/seat/screens/seat_selection_screen.dart); [Cinema_BE/BookingService/BookingService/Services/Implementations/BookingService.cs](../Cinema_BE/BookingService/BookingService/Services/Implementations/BookingService.cs); [Cinema_BE/BookingService/BookingService/Helpers/PromotionRules.cs](../Cinema_BE/BookingService/BookingService/Helpers/PromotionRules.cs); [Cinema_BE/BookingService/BookingService/Helpers/LoyaltyRules.cs](../Cinema_BE/BookingService/BookingService/Helpers/LoyaltyRules.cs) |
| Quy tắc nghiệp vụ | WEB-BR-07, WEB-BR-08, WEB-BR-14, WEB-BR-15, WEB-BR-16, WEB-BR-17, WEB-BR-27, WEB-BR-28, WEB-BR-29 |
| Ca sử dụng / màn / API | UC-WEB-07; WEB-SCR-SEATS; WEB-API-055 |

### WEB-FR-BOOK-09 — Cặp sweetbox

| Trường | Đặc tả |
| --- | --- |
| Tên | Cặp sweetbox |
| Mô tả | Sweetbox phải đặt đủ cặp (server từ chối nửa cặp). |
| Tác nhân | Hệ thống backend chung; khách nhận kết quả |
| Tiền điều kiện | Khách đã đăng nhập chọn suất OPEN chưa bắt đầu và ghế; khách vãng lai tại quầy được nhân viên/quản trị viên thao tác thay. |
| Kích hoạt | Thực hiện “Cặp sweetbox” hoặc sự kiện/tác vụ backend tương ứng. |
| Luồng chính | 1. Đọc đầu vào/tài nguyên hiện tại và phiên áp dụng. 2. Thực hiện thao tác này: Sweetbox phải đặt đủ cặp (server từ chối nửa cặp). 3. Trả/hiển thị kết quả chính thức và làm mới dữ liệu bị tác động sau thành công. |
| Luồng thay thế / ngoại lệ | Giữ chỗ đồng thời trả 409 và không được thu tiền hoặc để lại ghế/điểm dở dang. Bắp nước/mã/điểm sai trả lỗi kiểm tra. Hết hạn nhả ghế và trả điểm đã giữ. |
| Hậu điều kiện | Kết quả thành công quan sát được khớp yêu cầu này; chuyển trạng thái được chỉ định được lưu. Từ chối không cấp quyền hoặc để thay đổi dở dang trái phép. |
| Ưu tiên | H |
| Tiêu chí nghiệm thu | **WEB-FR-BOOK-09-AC-01** — Với tiền điều kiện/kích hoạt, kiểm tra: Sweetbox phải đặt đủ cặp (server từ chối nửa cặp). **WEB-FR-BOOK-09-AC-02** — Thử đầu vào sai/thiếu quyền/xung đột áp dụng và kiểm tra từ chối đã nêu, không đổi dữ liệu trái phép và không báo thành công sai. |
| Bằng chứng | [Cinema_BE/BookingService/BookingService/Controllers/BookingController.cs](../Cinema_BE/BookingService/BookingService/Controllers/BookingController.cs); [Cinema_Mobile/lib/features/seat/screens/seat_selection_screen.dart](../Cinema_Mobile/lib/features/seat/screens/seat_selection_screen.dart); [Cinema_Mobile/lib/features/booking/screens/booking_summary_screen.dart](../Cinema_Mobile/lib/features/booking/screens/booking_summary_screen.dart); [Cinema_BE/BookingService/BookingService/Services/Implementations/BookingService.cs](../Cinema_BE/BookingService/BookingService/Services/Implementations/BookingService.cs); [Cinema_BE/BookingService/BookingService/Helpers/PromotionRules.cs](../Cinema_BE/BookingService/BookingService/Helpers/PromotionRules.cs); [Cinema_BE/BookingService/BookingService/Helpers/LoyaltyRules.cs](../Cinema_BE/BookingService/BookingService/Helpers/LoyaltyRules.cs) |
| Quy tắc nghiệp vụ | WEB-BR-07, WEB-BR-08, WEB-BR-14, WEB-BR-15, WEB-BR-16, WEB-BR-17, WEB-BR-27, WEB-BR-28, WEB-BR-29 |
| Ca sử dụng / màn / API | UC-WEB-07; WEB-SCR-SEATS, WEB-SCR-SUMMARY; WEB-API-055 |

### WEB-FR-BOOK-10 — Hết hạn giữ chỗ chưa trả

| Trường | Đặc tả |
| --- | --- |
| Tên | Hết hạn giữ chỗ chưa trả |
| Mô tả | Job nền chạy mỗi 30 giây chuyển booking quá hạn giữ ghế sang `EXPIRED` và nhả ghế. |
| Tác nhân | Hệ thống backend chung; khách nhận kết quả |
| Tiền điều kiện | Khách đã đăng nhập chọn suất OPEN chưa bắt đầu và ghế; khách vãng lai tại quầy được nhân viên/quản trị viên thao tác thay. |
| Kích hoạt | Thực hiện “Hết hạn giữ chỗ chưa trả” hoặc sự kiện/tác vụ backend tương ứng. |
| Luồng chính | 1. Đọc đầu vào/tài nguyên hiện tại và phiên áp dụng. 2. Thực hiện thao tác này: Job nền chạy mỗi 30 giây chuyển booking quá hạn giữ ghế sang `EXPIRED` và nhả ghế. 3. Trả/hiển thị kết quả chính thức và làm mới dữ liệu bị tác động sau thành công. |
| Luồng thay thế / ngoại lệ | Giữ chỗ đồng thời trả 409 và không được thu tiền hoặc để lại ghế/điểm dở dang. Bắp nước/mã/điểm sai trả lỗi kiểm tra. Hết hạn nhả ghế và trả điểm đã giữ. |
| Hậu điều kiện | Dữ liệu/trạng thái đủ quyền được trả/hiển thị; đọc không đổi trạng thái vé/thanh toán. Dấu đã đọc thông báo chỉ đổi bằng thao tác ghi riêng. |
| Ưu tiên | H |
| Tiêu chí nghiệm thu | **WEB-FR-BOOK-10-AC-01** — Với tiền điều kiện/kích hoạt, kiểm tra: Job nền chạy mỗi 30 giây chuyển booking quá hạn giữ ghế sang `EXPIRED` và nhả ghế. **WEB-FR-BOOK-10-AC-02** — Thử đầu vào sai/thiếu quyền/xung đột áp dụng và kiểm tra từ chối đã nêu, không đổi dữ liệu trái phép và không báo thành công sai. |
| Bằng chứng | [Cinema_BE/BookingService/BookingService/Controllers/BookingController.cs](../Cinema_BE/BookingService/BookingService/Controllers/BookingController.cs); [Cinema_Mobile/lib/features/payment/screens/payment_screen.dart](../Cinema_Mobile/lib/features/payment/screens/payment_screen.dart); [Cinema_BE/BookingService/BookingService/Services/Implementations/BookingService.cs](../Cinema_BE/BookingService/BookingService/Services/Implementations/BookingService.cs); [Cinema_BE/BookingService/BookingService/Helpers/PromotionRules.cs](../Cinema_BE/BookingService/BookingService/Helpers/PromotionRules.cs); [Cinema_BE/BookingService/BookingService/Helpers/LoyaltyRules.cs](../Cinema_BE/BookingService/BookingService/Helpers/LoyaltyRules.cs) |
| Quy tắc nghiệp vụ | WEB-BR-07, WEB-BR-08, WEB-BR-14, WEB-BR-15, WEB-BR-16, WEB-BR-17, WEB-BR-27, WEB-BR-28, WEB-BR-29 |
| Ca sử dụng / màn / API | UC-WEB-07; WEB-SCR-PAYMENT; WEB-API-046 |

### WEB-FR-BOOK-11 — Làm mới sơ đồ khách

| Trường | Đặc tả |
| --- | --- |
| Tên | Làm mới sơ đồ khách |
| Mô tả | Màn chọn ghế tự làm mới mỗi 5 giây; ghế đang chọn bị người khác đặt thì bỏ chọn và báo cho khách. |
| Tác nhân | Khách hàng sở hữu vé trực tuyến; nhân viên/quản trị viên thực hiện nghiệp vụ quầy và quản lý |
| Tiền điều kiện | Khách đã đăng nhập chọn suất OPEN chưa bắt đầu và ghế; khách vãng lai tại quầy được nhân viên/quản trị viên thao tác thay. |
| Kích hoạt | Thực hiện “Làm mới sơ đồ khách” hoặc sự kiện/tác vụ backend tương ứng. |
| Luồng chính | 1. Đọc đầu vào/tài nguyên hiện tại và phiên áp dụng. 2. Thực hiện thao tác này: Màn chọn ghế tự làm mới mỗi 5 giây; ghế đang chọn bị người khác đặt thì bỏ chọn và báo cho khách. 3. Trả/hiển thị kết quả chính thức và làm mới dữ liệu bị tác động sau thành công. |
| Luồng thay thế / ngoại lệ | Giữ chỗ đồng thời trả 409 và không được thu tiền hoặc để lại ghế/điểm dở dang. Bắp nước/mã/điểm sai trả lỗi kiểm tra. Hết hạn nhả ghế và trả điểm đã giữ. |
| Hậu điều kiện | Dữ liệu/trạng thái đủ quyền được trả/hiển thị; đọc không đổi trạng thái vé/thanh toán. Dấu đã đọc thông báo chỉ đổi bằng thao tác ghi riêng. |
| Ưu tiên | M |
| Tiêu chí nghiệm thu | **WEB-FR-BOOK-11-AC-01** — Với tiền điều kiện/kích hoạt, kiểm tra: Màn chọn ghế tự làm mới mỗi 5 giây; ghế đang chọn bị người khác đặt thì bỏ chọn và báo cho khách. **WEB-FR-BOOK-11-AC-02** — Thử đầu vào sai/thiếu quyền/xung đột áp dụng và kiểm tra từ chối đã nêu, không đổi dữ liệu trái phép và không báo thành công sai. |
| Bằng chứng | [Cinema_BE/MovieService/MovieService/Controllers/SeatsController.cs](../Cinema_BE/MovieService/MovieService/Controllers/SeatsController.cs); [Cinema_BE/BookingService/BookingService/Controllers/BookingController.cs](../Cinema_BE/BookingService/BookingService/Controllers/BookingController.cs); [Cinema_Mobile/lib/features/seat/screens/seat_selection_screen.dart](../Cinema_Mobile/lib/features/seat/screens/seat_selection_screen.dart); [Cinema_BE/BookingService/BookingService/Services/Implementations/BookingService.cs](../Cinema_BE/BookingService/BookingService/Services/Implementations/BookingService.cs); [Cinema_BE/BookingService/BookingService/Helpers/PromotionRules.cs](../Cinema_BE/BookingService/BookingService/Helpers/PromotionRules.cs); [Cinema_BE/BookingService/BookingService/Helpers/LoyaltyRules.cs](../Cinema_BE/BookingService/BookingService/Helpers/LoyaltyRules.cs) |
| Quy tắc nghiệp vụ | WEB-BR-07, WEB-BR-08, WEB-BR-14, WEB-BR-15, WEB-BR-16, WEB-BR-17, WEB-BR-27, WEB-BR-28, WEB-BR-29 |
| Ca sử dụng / màn / API | UC-WEB-07; WEB-SCR-SEATS; WEB-API-013, WEB-API-049 |

### WEB-FR-BOOK-12 — Thống kê vé theo suất

| Trường | Đặc tả |
| --- | --- |
| Tên | Thống kê vé theo suất |
| Mô tả | Thống kê vé theo suất chiếu cho Staff/Admin: số đơn, ghế đã bán, đang giữ, đã check-in (theo danh sách id hoặc khoảng giờ chiếu, tối đa 31 ngày). |
| Tác nhân | Nhân viên/quản trị viên |
| Tiền điều kiện | Khách đã đăng nhập chọn suất OPEN chưa bắt đầu và ghế; khách vãng lai tại quầy được nhân viên/quản trị viên thao tác thay. |
| Kích hoạt | Thực hiện “Thống kê vé theo suất” hoặc sự kiện/tác vụ backend tương ứng. |
| Luồng chính | 1. Đọc đầu vào/tài nguyên hiện tại và phiên áp dụng. 2. Thực hiện thao tác này: Thống kê vé theo suất chiếu cho Staff/Admin: số đơn, ghế đã bán, đang giữ, đã check-in (theo danh sách id hoặc khoảng giờ chiếu, tối đa 31 ngày). 3. Trả/hiển thị kết quả chính thức và làm mới dữ liệu bị tác động sau thành công. |
| Luồng thay thế / ngoại lệ | Giữ chỗ đồng thời trả 409 và không được thu tiền hoặc để lại ghế/điểm dở dang. Bắp nước/mã/điểm sai trả lỗi kiểm tra. Hết hạn nhả ghế và trả điểm đã giữ. |
| Hậu điều kiện | Dữ liệu/trạng thái đủ quyền được trả/hiển thị; đọc không đổi trạng thái vé/thanh toán. Dấu đã đọc thông báo chỉ đổi bằng thao tác ghi riêng. |
| Ưu tiên | M |
| Tiêu chí nghiệm thu | **WEB-FR-BOOK-12-AC-01** — Với tiền điều kiện/kích hoạt, kiểm tra: Thống kê vé theo suất chiếu cho Staff/Admin: số đơn, ghế đã bán, đang giữ, đã check-in (theo danh sách id hoặc khoảng giờ chiếu, tối đa 31 ngày). **WEB-FR-BOOK-12-AC-02** — Thử đầu vào sai/thiếu quyền/xung đột áp dụng và kiểm tra từ chối đã nêu, không đổi dữ liệu trái phép và không báo thành công sai. |
| Bằng chứng | [Cinema_BE/BookingService/BookingService/Controllers/BookingController.cs](../Cinema_BE/BookingService/BookingService/Controllers/BookingController.cs); [Cinema_Mobile/lib/features/staff/screens/staff_operations_screen.dart](../Cinema_Mobile/lib/features/staff/screens/staff_operations_screen.dart); [Cinema_Mobile/lib/features/staff/screens/staff_record_screen.dart](../Cinema_Mobile/lib/features/staff/screens/staff_record_screen.dart); [Cinema_BE/BookingService/BookingService/Services/Implementations/BookingService.cs](../Cinema_BE/BookingService/BookingService/Services/Implementations/BookingService.cs); [Cinema_BE/BookingService/BookingService/Helpers/PromotionRules.cs](../Cinema_BE/BookingService/BookingService/Helpers/PromotionRules.cs); [Cinema_BE/BookingService/BookingService/Helpers/LoyaltyRules.cs](../Cinema_BE/BookingService/BookingService/Helpers/LoyaltyRules.cs) |
| Quy tắc nghiệp vụ | WEB-BR-07, WEB-BR-08, WEB-BR-14, WEB-BR-15, WEB-BR-16, WEB-BR-17, WEB-BR-27, WEB-BR-28, WEB-BR-29 |
| Ca sử dụng / màn / API | UC-WEB-07; WEB-SCR-OPERATIONS, WEB-SCR-RECORD-SHOWTIMES; WEB-API-051 |

### WEB-FR-BOOK-13 — Bắp nước kèm vé

| Trường | Đặc tả |
| --- | --- |
| Tên | Bắp nước kèm vé |
| Mô tả | **Bắp nước kèm vé**: khách (màn xác nhận đặt vé) và quầy (màn bán vé) chọn món trong menu, mỗi món 1–20, tối đa 10 món khác nhau. Giá lấy từ menu đang bán; tiền bắp nước nằm trong tổng tiền nên thanh toán, doanh thu và hoàn tiền tính luôn. Đơn lưu tên và giá lúc mua. Bắp nước hiện trên vé, trang thanh toán, email vé và vé in. Món đã ngừng bán bị từ chối (400). |
| Tác nhân | Khách hàng sở hữu vé trực tuyến; nhân viên/quản trị viên thực hiện nghiệp vụ quầy và quản lý |
| Tiền điều kiện | Khách đã đăng nhập chọn suất OPEN chưa bắt đầu và ghế; khách vãng lai tại quầy được nhân viên/quản trị viên thao tác thay. |
| Kích hoạt | Thực hiện “Bắp nước kèm vé” hoặc sự kiện/tác vụ backend tương ứng. |
| Luồng chính | 1. Đọc đầu vào/tài nguyên hiện tại và phiên áp dụng. 2. Thực hiện thao tác này: **Bắp nước kèm vé**: khách (màn xác nhận đặt vé) và quầy (màn bán vé) chọn món trong menu, mỗi món 1–20, tối đa 10 món khác nhau. Giá lấy từ menu đang bán; tiền bắp nước nằm trong tổng tiền nên thanh toán, doanh thu và hoàn tiền tính luôn. Đơn lưu tên và giá lúc mua. Bắp nước hiện trên vé, trang thanh toán, email vé và vé in. Món đã ngừng bán bị từ chối (400). 3. Trả/hiển thị kết quả chính thức và làm mới dữ liệu bị tác động sau thành công. |
| Luồng thay thế / ngoại lệ | Giữ chỗ đồng thời trả 409 và không được thu tiền hoặc để lại ghế/điểm dở dang. Bắp nước/mã/điểm sai trả lỗi kiểm tra. Hết hạn nhả ghế và trả điểm đã giữ. |
| Hậu điều kiện | Kết quả thành công quan sát được khớp yêu cầu này; chuyển trạng thái được chỉ định được lưu. Từ chối không cấp quyền hoặc để thay đổi dở dang trái phép. |
| Ưu tiên | M |
| Tiêu chí nghiệm thu | **WEB-FR-BOOK-13-AC-01** — Với tiền điều kiện/kích hoạt, kiểm tra: **Bắp nước kèm vé**: khách (màn xác nhận đặt vé) và quầy (màn bán vé) chọn món trong menu, mỗi món 1–20, tối đa 10 món khác nhau. Giá lấy từ menu đang bán; tiền bắp nước nằm trong tổng tiền nên thanh toán, doanh thu và hoàn tiền tính luôn. Đơn lưu tên và giá lúc mua. Bắp nước hiện trên vé, trang thanh toán, email vé và vé in. Món đã ngừng bán bị từ chối (400). **WEB-FR-BOOK-13-AC-02** — Thử đầu vào sai/thiếu quyền/xung đột áp dụng và kiểm tra từ chối đã nêu, không đổi dữ liệu trái phép và không báo thành công sai. |
| Bằng chứng | [Cinema_BE/BookingService/BookingService/Controllers/BookingController.cs](../Cinema_BE/BookingService/BookingService/Controllers/BookingController.cs); [Cinema_BE/BookingService/BookingService/Controllers/ConcessionController.cs](../Cinema_BE/BookingService/BookingService/Controllers/ConcessionController.cs); [Cinema_Mobile/lib/features/booking/screens/booking_summary_screen.dart](../Cinema_Mobile/lib/features/booking/screens/booking_summary_screen.dart); [Cinema_Mobile/lib/features/booking/screens/booking_detail_screen.dart](../Cinema_Mobile/lib/features/booking/screens/booking_detail_screen.dart); [Cinema_Mobile/lib/features/staff/screens/staff_create_booking_screen.dart](../Cinema_Mobile/lib/features/staff/screens/staff_create_booking_screen.dart); [Cinema_BE/BookingService/BookingService/Services/Implementations/BookingService.cs](../Cinema_BE/BookingService/BookingService/Services/Implementations/BookingService.cs); [Cinema_BE/BookingService/BookingService/Helpers/PromotionRules.cs](../Cinema_BE/BookingService/BookingService/Helpers/PromotionRules.cs); [Cinema_BE/BookingService/BookingService/Helpers/LoyaltyRules.cs](../Cinema_BE/BookingService/BookingService/Helpers/LoyaltyRules.cs) |
| Quy tắc nghiệp vụ | WEB-BR-07, WEB-BR-08, WEB-BR-14, WEB-BR-15, WEB-BR-16, WEB-BR-17, WEB-BR-27, WEB-BR-28, WEB-BR-29 |
| Ca sử dụng / màn / API | UC-WEB-07; WEB-SCR-SUMMARY, WEB-SCR-TICKET, WEB-SCR-COUNTER; WEB-API-055, WEB-API-057 |

### WEB-FR-BOOK-14 — Quản lý bắp nước

| Trường | Đặc tả |
| --- | --- |
| Tên | Quản lý bắp nước |
| Mô tả | Admin quản lý menu bắp nước (Admin → Snacks): thêm, sửa tên / giá / mô tả / ảnh / thứ tự, ngừng bán hoặc bán lại (không xoá món). Khách chỉ thấy món đang bán. |
| Tác nhân | Quản trị viên |
| Tiền điều kiện | Có phiên quản trị viên; bản ghi đích tồn tại khi sửa/dừng/điều chỉnh. |
| Kích hoạt | Thực hiện “Quản lý bắp nước” hoặc sự kiện/tác vụ backend tương ứng. |
| Luồng chính | 1. Đọc đầu vào/tài nguyên hiện tại và phiên áp dụng. 2. Thực hiện thao tác này: Admin quản lý menu bắp nước (Admin → Snacks): thêm, sửa tên / giá / mô tả / ảnh / thứ tự, ngừng bán hoặc bán lại (không xoá món). Khách chỉ thấy món đang bán. 3. Trả/hiển thị kết quả chính thức và làm mới dữ liệu bị tác động sau thành công. |
| Luồng thay thế / ngoại lệ | Giữ chỗ đồng thời trả 409 và không được thu tiền hoặc để lại ghế/điểm dở dang. Bắp nước/mã/điểm sai trả lỗi kiểm tra. Hết hạn nhả ghế và trả điểm đã giữ. |
| Hậu điều kiện | Kết quả thành công quan sát được khớp yêu cầu này; chuyển trạng thái được chỉ định được lưu. Từ chối không cấp quyền hoặc để thay đổi dở dang trái phép. |
| Ưu tiên | M |
| Tiêu chí nghiệm thu | **WEB-FR-BOOK-14-AC-01** — Với tiền điều kiện/kích hoạt, kiểm tra: Admin quản lý menu bắp nước (Admin → Snacks): thêm, sửa tên / giá / mô tả / ảnh / thứ tự, ngừng bán hoặc bán lại (không xoá món). Khách chỉ thấy món đang bán. **WEB-FR-BOOK-14-AC-02** — Thử đầu vào sai/thiếu quyền/xung đột áp dụng và kiểm tra từ chối đã nêu, không đổi dữ liệu trái phép và không báo thành công sai. |
| Bằng chứng | [Cinema_BE/BookingService/BookingService/Controllers/ConcessionController.cs](../Cinema_BE/BookingService/BookingService/Controllers/ConcessionController.cs); [Cinema_Mobile/lib/features/admin/screens/admin_snacks_screen.dart](../Cinema_Mobile/lib/features/admin/screens/admin_snacks_screen.dart); [Cinema_BE/BookingService/BookingService/Services/Implementations/BookingService.cs](../Cinema_BE/BookingService/BookingService/Services/Implementations/BookingService.cs); [Cinema_BE/BookingService/BookingService/Helpers/PromotionRules.cs](../Cinema_BE/BookingService/BookingService/Helpers/PromotionRules.cs); [Cinema_BE/BookingService/BookingService/Helpers/LoyaltyRules.cs](../Cinema_BE/BookingService/BookingService/Helpers/LoyaltyRules.cs); [Cinema_BE/BookingService/BookingService/Services/Implementations/ConcessionService.cs](../Cinema_BE/BookingService/BookingService/Services/Implementations/ConcessionService.cs) |
| Quy tắc nghiệp vụ | WEB-BR-07, WEB-BR-08, WEB-BR-14, WEB-BR-15, WEB-BR-16, WEB-BR-17, WEB-BR-27, WEB-BR-28, WEB-BR-29 |
| Ca sử dụng / màn / API | UC-WEB-07; WEB-SCR-ADMIN-SNACKS; WEB-API-056, WEB-API-057, WEB-API-058 |

### WEB-FR-BOOK-15 — Khuyến mãi và mã giảm giá

| Trường | Đặc tả |
| --- | --- |
| Tên | Khuyến mãi và mã giảm giá |
| Mô tả | **Khuyến mãi**: chỉ giảm tiền vé (không giảm bắp nước), theo % (có thể kèm mức giảm tối đa) hoặc số tiền, tối đa 90% tiền vé, làm tròn xuống 1.000đ. Điều kiện: thời gian chạy, thứ của ngày chiếu, số vé tối thiểu, số lượt tối đa. Khuyến mãi không có mã tự áp dụng (chọn cái giảm nhiều nhất); khách / quầy nhập mã voucher thì dùng mã thay cho khuyến mãi tự áp dụng — mỗi đơn một khuyến mãi. Mã sai hoặc không đủ điều kiện bị 400 kèm lý do. Server tính lại khi tạo đơn; lượt dùng chỉ được đếm khi vé đã thanh toán. Giảm giá hiện trên vé, trang thanh toán, email vé và vé in. |
| Tác nhân | Khách hàng sở hữu vé trực tuyến; nhân viên/quản trị viên thực hiện nghiệp vụ quầy và quản lý |
| Tiền điều kiện | Khách đã đăng nhập chọn suất OPEN chưa bắt đầu và ghế; khách vãng lai tại quầy được nhân viên/quản trị viên thao tác thay. |
| Kích hoạt | Thực hiện “Khuyến mãi và mã giảm giá” hoặc sự kiện/tác vụ backend tương ứng. |
| Luồng chính | 1. Đọc đầu vào/tài nguyên hiện tại và phiên áp dụng. 2. Thực hiện thao tác này: **Khuyến mãi**: chỉ giảm tiền vé (không giảm bắp nước), theo % (có thể kèm mức giảm tối đa) hoặc số tiền, tối đa 90% tiền vé, làm tròn xuống 1.000đ. Điều kiện: thời gian chạy, thứ của ngày chiếu, số vé tối thiểu, số lượt tối đa. Khuyến mãi không có mã tự áp dụng (chọn cái giảm nhiều nhất); khách / quầy nhập mã voucher thì dùng mã thay cho khuyến mãi tự áp dụng — mỗi đơn một khuyến mãi. Mã sai hoặc không đủ điều kiện bị 400 kèm lý do. Server tính lại khi tạo đơn; lượt dùng chỉ được đếm khi vé đã thanh toán. Giảm giá hiện trên vé, trang thanh toán, email vé và vé in. 3. Trả/hiển thị kết quả chính thức và làm mới dữ liệu bị tác động sau thành công. |
| Luồng thay thế / ngoại lệ | Giữ chỗ đồng thời trả 409 và không được thu tiền hoặc để lại ghế/điểm dở dang. Bắp nước/mã/điểm sai trả lỗi kiểm tra. Hết hạn nhả ghế và trả điểm đã giữ. |
| Hậu điều kiện | Kết quả thành công quan sát được khớp yêu cầu này; chuyển trạng thái được chỉ định được lưu. Từ chối không cấp quyền hoặc để thay đổi dở dang trái phép. |
| Ưu tiên | M |
| Tiêu chí nghiệm thu | **WEB-FR-BOOK-15-AC-01** — Với tiền điều kiện/kích hoạt, kiểm tra: **Khuyến mãi**: chỉ giảm tiền vé (không giảm bắp nước), theo % (có thể kèm mức giảm tối đa) hoặc số tiền, tối đa 90% tiền vé, làm tròn xuống 1.000đ. Điều kiện: thời gian chạy, thứ của ngày chiếu, số vé tối thiểu, số lượt tối đa. Khuyến mãi không có mã tự áp dụng (chọn cái giảm nhiều nhất); khách / quầy nhập mã voucher thì dùng mã thay cho khuyến mãi tự áp dụng — mỗi đơn một khuyến mãi. Mã sai hoặc không đủ điều kiện bị 400 kèm lý do. Server tính lại khi tạo đơn; lượt dùng chỉ được đếm khi vé đã thanh toán. Giảm giá hiện trên vé, trang thanh toán, email vé và vé in. **WEB-FR-BOOK-15-AC-02** — Thử đầu vào sai/thiếu quyền/xung đột áp dụng và kiểm tra từ chối đã nêu, không đổi dữ liệu trái phép và không báo thành công sai. |
| Bằng chứng | [Cinema_BE/BookingService/BookingService/Controllers/BookingController.cs](../Cinema_BE/BookingService/BookingService/Controllers/BookingController.cs); [Cinema_BE/BookingService/BookingService/Controllers/PromotionController.cs](../Cinema_BE/BookingService/BookingService/Controllers/PromotionController.cs); [Cinema_Mobile/lib/features/booking/screens/booking_summary_screen.dart](../Cinema_Mobile/lib/features/booking/screens/booking_summary_screen.dart); [Cinema_Mobile/lib/features/booking/screens/booking_detail_screen.dart](../Cinema_Mobile/lib/features/booking/screens/booking_detail_screen.dart); [Cinema_Mobile/lib/features/staff/screens/staff_create_booking_screen.dart](../Cinema_Mobile/lib/features/staff/screens/staff_create_booking_screen.dart); [Cinema_BE/BookingService/BookingService/Services/Implementations/BookingService.cs](../Cinema_BE/BookingService/BookingService/Services/Implementations/BookingService.cs); [Cinema_BE/BookingService/BookingService/Helpers/PromotionRules.cs](../Cinema_BE/BookingService/BookingService/Helpers/PromotionRules.cs); [Cinema_BE/BookingService/BookingService/Helpers/LoyaltyRules.cs](../Cinema_BE/BookingService/BookingService/Helpers/LoyaltyRules.cs) |
| Quy tắc nghiệp vụ | WEB-BR-07, WEB-BR-08, WEB-BR-14, WEB-BR-15, WEB-BR-16, WEB-BR-17, WEB-BR-27, WEB-BR-28, WEB-BR-29 |
| Ca sử dụng / màn / API | UC-WEB-07; WEB-SCR-SUMMARY, WEB-SCR-TICKET, WEB-SCR-COUNTER; WEB-API-055, WEB-API-099 |

### WEB-FR-BOOK-16 — Quản lý khuyến mãi

| Trường | Đặc tả |
| --- | --- |
| Tên | Quản lý khuyến mãi |
| Mô tả | Admin quản lý khuyến mãi (Admin → Promotions): thêm, sửa, tạm dừng / chạy lại (không xoá), xem số lượt đã dùng. Mã voucher không trùng nhau (409). Khách chưa đăng nhập chỉ xem được khuyến mãi tự áp dụng đang chạy. |
| Tác nhân | Quản trị viên |
| Tiền điều kiện | Có phiên quản trị viên; bản ghi đích tồn tại khi sửa/dừng/điều chỉnh. |
| Kích hoạt | Thực hiện “Quản lý khuyến mãi” hoặc sự kiện/tác vụ backend tương ứng. |
| Luồng chính | 1. Đọc đầu vào/tài nguyên hiện tại và phiên áp dụng. 2. Thực hiện thao tác này: Admin quản lý khuyến mãi (Admin → Promotions): thêm, sửa, tạm dừng / chạy lại (không xoá), xem số lượt đã dùng. Mã voucher không trùng nhau (409). Khách chưa đăng nhập chỉ xem được khuyến mãi tự áp dụng đang chạy. 3. Trả/hiển thị kết quả chính thức và làm mới dữ liệu bị tác động sau thành công. |
| Luồng thay thế / ngoại lệ | Giữ chỗ đồng thời trả 409 và không được thu tiền hoặc để lại ghế/điểm dở dang. Bắp nước/mã/điểm sai trả lỗi kiểm tra. Hết hạn nhả ghế và trả điểm đã giữ. |
| Hậu điều kiện | Kết quả thành công quan sát được khớp yêu cầu này; chuyển trạng thái được chỉ định được lưu. Từ chối không cấp quyền hoặc để thay đổi dở dang trái phép. |
| Ưu tiên | M |
| Tiêu chí nghiệm thu | **WEB-FR-BOOK-16-AC-01** — Với tiền điều kiện/kích hoạt, kiểm tra: Admin quản lý khuyến mãi (Admin → Promotions): thêm, sửa, tạm dừng / chạy lại (không xoá), xem số lượt đã dùng. Mã voucher không trùng nhau (409). Khách chưa đăng nhập chỉ xem được khuyến mãi tự áp dụng đang chạy. **WEB-FR-BOOK-16-AC-02** — Thử đầu vào sai/thiếu quyền/xung đột áp dụng và kiểm tra từ chối đã nêu, không đổi dữ liệu trái phép và không báo thành công sai. |
| Bằng chứng | [Cinema_BE/BookingService/BookingService/Controllers/PromotionController.cs](../Cinema_BE/BookingService/BookingService/Controllers/PromotionController.cs); [Cinema_Mobile/lib/features/admin/screens/admin_promotions_screen.dart](../Cinema_Mobile/lib/features/admin/screens/admin_promotions_screen.dart); [Cinema_BE/BookingService/BookingService/Services/Implementations/BookingService.cs](../Cinema_BE/BookingService/BookingService/Services/Implementations/BookingService.cs); [Cinema_BE/BookingService/BookingService/Helpers/PromotionRules.cs](../Cinema_BE/BookingService/BookingService/Helpers/PromotionRules.cs); [Cinema_BE/BookingService/BookingService/Helpers/LoyaltyRules.cs](../Cinema_BE/BookingService/BookingService/Helpers/LoyaltyRules.cs); [Cinema_BE/BookingService/BookingService/Services/Implementations/PromotionService.cs](../Cinema_BE/BookingService/BookingService/Services/Implementations/PromotionService.cs) |
| Quy tắc nghiệp vụ | WEB-BR-07, WEB-BR-08, WEB-BR-14, WEB-BR-15, WEB-BR-16, WEB-BR-17, WEB-BR-27, WEB-BR-28, WEB-BR-29 |
| Ca sử dụng / màn / API | UC-WEB-07; WEB-SCR-ADMIN-PROMOTIONS; WEB-API-098, WEB-API-100, WEB-API-101 |

### WEB-FR-BOOK-17 — Điểm thành viên

| Trường | Đặc tả |
| --- | --- |
| Tên | Điểm thành viên |
| Mô tả | **Điểm thành viên**: khách có tài khoản được cộng điểm khi vé đã thanh toán, theo số tiền thực trả và hạng: Member 5%, VIP (tổng chi tiêu từ 2.000.000đ) 7%, VVIP (từ 5.000.000đ) 10%; 1 điểm = 1.000đ. Khi đặt vé (app hoặc quầy) được dùng điểm, tối đa 50% số tiền phải trả (sau khuyến mãi). Vé giữ chỗ hết hạn / huỷ khi chưa trả thì trả lại điểm đã dùng; vé đã trả bị huỷ / hoàn tiền thì trả điểm đã dùng, thu hồi điểm đã cộng và trừ tổng chi tiêu. Khách vãng lai không có điểm. Khách xem thẻ thành viên (điểm, hạng, mức còn thiếu để lên hạng, lịch sử điểm) ở trang tài khoản. |
| Tác nhân | Khách hàng sở hữu vé trực tuyến; nhân viên/quản trị viên thực hiện nghiệp vụ quầy và quản lý |
| Tiền điều kiện | Khách đã đăng nhập chọn suất OPEN chưa bắt đầu và ghế; khách vãng lai tại quầy được nhân viên/quản trị viên thao tác thay. |
| Kích hoạt | Thực hiện “Điểm thành viên” hoặc sự kiện/tác vụ backend tương ứng. |
| Luồng chính | 1. Đọc đầu vào/tài nguyên hiện tại và phiên áp dụng. 2. Thực hiện thao tác này: **Điểm thành viên**: khách có tài khoản được cộng điểm khi vé đã thanh toán, theo số tiền thực trả và hạng: Member 5%, VIP (tổng chi tiêu từ 2.000.000đ) 7%, VVIP (từ 5.000.000đ) 10%; 1 điểm = 1.000đ. Khi đặt vé (app hoặc quầy) được dùng điểm, tối đa 50% số tiền phải trả (sau khuyến mãi). Vé giữ chỗ hết hạn / huỷ khi chưa trả thì trả lại điểm đã dùng; vé đã trả bị huỷ / hoàn tiền thì trả điểm đã dùng, thu hồi điểm đã cộng và trừ tổng chi tiêu. Khách vãng lai không có điểm. Khách xem thẻ thành viên (điểm, hạng, mức còn thiếu để lên hạng, lịch sử điểm) ở trang tài khoản. 3. Trả/hiển thị kết quả chính thức và làm mới dữ liệu bị tác động sau thành công. |
| Luồng thay thế / ngoại lệ | Giữ chỗ đồng thời trả 409 và không được thu tiền hoặc để lại ghế/điểm dở dang. Bắp nước/mã/điểm sai trả lỗi kiểm tra. Hết hạn nhả ghế và trả điểm đã giữ. |
| Hậu điều kiện | Kết quả thành công quan sát được khớp yêu cầu này; chuyển trạng thái được chỉ định được lưu. Từ chối không cấp quyền hoặc để thay đổi dở dang trái phép. |
| Ưu tiên | M |
| Tiêu chí nghiệm thu | **WEB-FR-BOOK-17-AC-01** — Với tiền điều kiện/kích hoạt, kiểm tra: **Điểm thành viên**: khách có tài khoản được cộng điểm khi vé đã thanh toán, theo số tiền thực trả và hạng: Member 5%, VIP (tổng chi tiêu từ 2.000.000đ) 7%, VVIP (từ 5.000.000đ) 10%; 1 điểm = 1.000đ. Khi đặt vé (app hoặc quầy) được dùng điểm, tối đa 50% số tiền phải trả (sau khuyến mãi). Vé giữ chỗ hết hạn / huỷ khi chưa trả thì trả lại điểm đã dùng; vé đã trả bị huỷ / hoàn tiền thì trả điểm đã dùng, thu hồi điểm đã cộng và trừ tổng chi tiêu. Khách vãng lai không có điểm. Khách xem thẻ thành viên (điểm, hạng, mức còn thiếu để lên hạng, lịch sử điểm) ở trang tài khoản. **WEB-FR-BOOK-17-AC-02** — Thử đầu vào sai/thiếu quyền/xung đột áp dụng và kiểm tra từ chối đã nêu, không đổi dữ liệu trái phép và không báo thành công sai. |
| Bằng chứng | [Cinema_BE/BookingService/BookingService/Controllers/BookingController.cs](../Cinema_BE/BookingService/BookingService/Controllers/BookingController.cs); [Cinema_BE/BookingService/BookingService/Controllers/LoyaltyController.cs](../Cinema_BE/BookingService/BookingService/Controllers/LoyaltyController.cs); [Cinema_Mobile/lib/features/booking/screens/booking_summary_screen.dart](../Cinema_Mobile/lib/features/booking/screens/booking_summary_screen.dart); [Cinema_Mobile/lib/features/booking/screens/booking_detail_screen.dart](../Cinema_Mobile/lib/features/booking/screens/booking_detail_screen.dart); [Cinema_Mobile/lib/features/profile/screens/profile_screen.dart](../Cinema_Mobile/lib/features/profile/screens/profile_screen.dart); [Cinema_Mobile/lib/features/staff/screens/staff_create_booking_screen.dart](../Cinema_Mobile/lib/features/staff/screens/staff_create_booking_screen.dart); [Cinema_BE/BookingService/BookingService/Services/Implementations/BookingService.cs](../Cinema_BE/BookingService/BookingService/Services/Implementations/BookingService.cs); [Cinema_BE/BookingService/BookingService/Helpers/PromotionRules.cs](../Cinema_BE/BookingService/BookingService/Helpers/PromotionRules.cs); [Cinema_BE/BookingService/BookingService/Helpers/LoyaltyRules.cs](../Cinema_BE/BookingService/BookingService/Helpers/LoyaltyRules.cs); [Cinema_BE/BookingService/BookingService/Services/Implementations/LoyaltyService.cs](../Cinema_BE/BookingService/BookingService/Services/Implementations/LoyaltyService.cs) |
| Quy tắc nghiệp vụ | WEB-BR-07, WEB-BR-08, WEB-BR-14, WEB-BR-15, WEB-BR-16, WEB-BR-17, WEB-BR-27, WEB-BR-28, WEB-BR-29 |
| Ca sử dụng / màn / API | UC-WEB-07; WEB-SCR-SUMMARY, WEB-SCR-TICKET, WEB-SCR-PROFILE, WEB-SCR-COUNTER; WEB-API-055, WEB-API-060 |

### WEB-FR-BOOK-18 — Quản lý thành viên

| Trường | Đặc tả |
| --- | --- |
| Tên | Quản lý thành viên |
| Mô tả | Admin xem khách hàng kèm điểm, hạng, tổng chi tiêu (Admin → Members), mở lịch sử điểm và cộng / trừ điểm kèm lý do (không để điểm âm). Quầy xem thẻ của khách tìm được theo số điện thoại. |
| Tác nhân | Quản trị viên |
| Tiền điều kiện | Có phiên quản trị viên; bản ghi đích tồn tại khi sửa/dừng/điều chỉnh. |
| Kích hoạt | Thực hiện “Quản lý thành viên” hoặc sự kiện/tác vụ backend tương ứng. |
| Luồng chính | 1. Đọc đầu vào/tài nguyên hiện tại và phiên áp dụng. 2. Thực hiện thao tác này: Admin xem khách hàng kèm điểm, hạng, tổng chi tiêu (Admin → Members), mở lịch sử điểm và cộng / trừ điểm kèm lý do (không để điểm âm). Quầy xem thẻ của khách tìm được theo số điện thoại. 3. Trả/hiển thị kết quả chính thức và làm mới dữ liệu bị tác động sau thành công. |
| Luồng thay thế / ngoại lệ | Giữ chỗ đồng thời trả 409 và không được thu tiền hoặc để lại ghế/điểm dở dang. Bắp nước/mã/điểm sai trả lỗi kiểm tra. Hết hạn nhả ghế và trả điểm đã giữ. |
| Hậu điều kiện | Kết quả thành công quan sát được khớp yêu cầu này; chuyển trạng thái được chỉ định được lưu. Từ chối không cấp quyền hoặc để thay đổi dở dang trái phép. |
| Ưu tiên | M |
| Tiêu chí nghiệm thu | **WEB-FR-BOOK-18-AC-01** — Với tiền điều kiện/kích hoạt, kiểm tra: Admin xem khách hàng kèm điểm, hạng, tổng chi tiêu (Admin → Members), mở lịch sử điểm và cộng / trừ điểm kèm lý do (không để điểm âm). Quầy xem thẻ của khách tìm được theo số điện thoại. **WEB-FR-BOOK-18-AC-02** — Thử đầu vào sai/thiếu quyền/xung đột áp dụng và kiểm tra từ chối đã nêu, không đổi dữ liệu trái phép và không báo thành công sai. |
| Bằng chứng | [Cinema_BE/AuthService/AuthService/Controllers/MembersController.cs](../Cinema_BE/AuthService/AuthService/Controllers/MembersController.cs); [Cinema_BE/BookingService/BookingService/Controllers/LoyaltyController.cs](../Cinema_BE/BookingService/BookingService/Controllers/LoyaltyController.cs); [Cinema_Mobile/lib/features/admin/screens/admin_members_screen.dart](../Cinema_Mobile/lib/features/admin/screens/admin_members_screen.dart); [Cinema_BE/BookingService/BookingService/Services/Implementations/BookingService.cs](../Cinema_BE/BookingService/BookingService/Services/Implementations/BookingService.cs); [Cinema_BE/BookingService/BookingService/Helpers/PromotionRules.cs](../Cinema_BE/BookingService/BookingService/Helpers/PromotionRules.cs); [Cinema_BE/BookingService/BookingService/Helpers/LoyaltyRules.cs](../Cinema_BE/BookingService/BookingService/Helpers/LoyaltyRules.cs); [Cinema_BE/BookingService/BookingService/Services/Implementations/LoyaltyService.cs](../Cinema_BE/BookingService/BookingService/Services/Implementations/LoyaltyService.cs) |
| Quy tắc nghiệp vụ | WEB-BR-07, WEB-BR-08, WEB-BR-14, WEB-BR-15, WEB-BR-16, WEB-BR-17, WEB-BR-27, WEB-BR-28, WEB-BR-29 |
| Ca sử dụng / màn / API | UC-WEB-07; WEB-SCR-ADMIN-MEMBERS; WEB-API-030, WEB-API-059, WEB-API-061, WEB-API-062 |

### WEB-FR-BOOK-19 — Chia sẻ và lịch

| Trường | Đặc tả |
| --- | --- |
| Tên | Chia sẻ và lịch |
| Mô tả | Vé đã thanh toán có nút **Share ticket** (chia sẻ tên phim, giờ chiếu, ghế và mã vé cho người đi cùng qua bảng chia sẻ của máy; trình duyệt không hỗ trợ thì chép vào clipboard) và **Add to calendar** (mở sự kiện Google Calendar theo giờ Việt Nam, kết thúc theo giờ kết thúc suất chiếu; chỉ hiện khi suất chưa chiếu). |
| Tác nhân | Khách hàng sở hữu vé trực tuyến; nhân viên/quản trị viên thực hiện nghiệp vụ quầy và quản lý |
| Tiền điều kiện | Khách đã đăng nhập và sở hữu vé liên quan; thao tác phải được trạng thái và giờ vé cho phép. Quyền nhân viên chỉ áp dụng nơi đã nêu. |
| Kích hoạt | Thực hiện “Chia sẻ và lịch” hoặc sự kiện/tác vụ backend tương ứng. |
| Luồng chính | 1. Đọc đầu vào/tài nguyên hiện tại và phiên áp dụng. 2. Thực hiện thao tác này: Vé đã thanh toán có nút **Share ticket** (chia sẻ tên phim, giờ chiếu, ghế và mã vé cho người đi cùng qua bảng chia sẻ của máy; trình duyệt không hỗ trợ thì chép vào clipboard) và **Add to calendar** (mở sự kiện Google Calendar theo giờ Việt Nam, kết thúc theo giờ kết thúc suất chiếu; chỉ hiện khi suất chưa chiếu). 3. Trả/hiển thị kết quả chính thức và làm mới dữ liệu bị tác động sau thành công. |
| Luồng thay thế / ngoại lệ | Giữ chỗ đồng thời trả 409 và không được thu tiền hoặc để lại ghế/điểm dở dang. Bắp nước/mã/điểm sai trả lỗi kiểm tra. Hết hạn nhả ghế và trả điểm đã giữ. |
| Hậu điều kiện | Dữ liệu/trạng thái đủ quyền được trả/hiển thị; đọc không đổi trạng thái vé/thanh toán. Dấu đã đọc thông báo chỉ đổi bằng thao tác ghi riêng. |
| Ưu tiên | L |
| Tiêu chí nghiệm thu | **WEB-FR-BOOK-19-AC-01** — Với tiền điều kiện/kích hoạt, kiểm tra: Vé đã thanh toán có nút **Share ticket** (chia sẻ tên phim, giờ chiếu, ghế và mã vé cho người đi cùng qua bảng chia sẻ của máy; trình duyệt không hỗ trợ thì chép vào clipboard) và **Add to calendar** (mở sự kiện Google Calendar theo giờ Việt Nam, kết thúc theo giờ kết thúc suất chiếu; chỉ hiện khi suất chưa chiếu). **WEB-FR-BOOK-19-AC-02** — Thử đầu vào sai/thiếu quyền/xung đột áp dụng và kiểm tra từ chối đã nêu, không đổi dữ liệu trái phép và không báo thành công sai. |
| Bằng chứng | [Cinema_BE/MovieService/MovieService/Controllers/ShowtimesController.cs](../Cinema_BE/MovieService/MovieService/Controllers/ShowtimesController.cs); [Cinema_Mobile/lib/features/booking/screens/booking_detail_screen.dart](../Cinema_Mobile/lib/features/booking/screens/booking_detail_screen.dart); [Cinema_BE/BookingService/BookingService/Services/Implementations/BookingService.cs](../Cinema_BE/BookingService/BookingService/Services/Implementations/BookingService.cs); [Cinema_BE/BookingService/BookingService/Helpers/PromotionRules.cs](../Cinema_BE/BookingService/BookingService/Helpers/PromotionRules.cs); [Cinema_BE/BookingService/BookingService/Helpers/LoyaltyRules.cs](../Cinema_BE/BookingService/BookingService/Helpers/LoyaltyRules.cs) |
| Quy tắc nghiệp vụ | WEB-BR-07, WEB-BR-08, WEB-BR-14, WEB-BR-15, WEB-BR-16, WEB-BR-17, WEB-BR-27, WEB-BR-28, WEB-BR-29 |
| Ca sử dụng / màn / API | UC-WEB-07; WEB-SCR-TICKET; WEB-API-017 |

### WEB-FR-PAY-01 — Tạo/dùng lại link PayOS

| Trường | Đặc tả |
| --- | --- |
| Tên | Tạo/dùng lại link PayOS |
| Mô tả | Tạo link thanh toán PayOS cho booking `PENDING`. Mỗi booking một payment; gọi lại thì trả link cũ, không tạo thêm. Mã đơn PayOS = id booking × 1.000.000 + 6 số ngẫu nhiên cuối mã vé: cố định cho mỗi booking và không trùng với đơn của môi trường khác trên tài khoản PayOS dùng chung. Link hết hạn cùng lúc với thời gian giữ ghế. |
| Tác nhân | Chủ vé; nhân viên/quản trị viên với thao tác được phép; PayOS/hệ thống |
| Tiền điều kiện | Có vé đủ điều kiện thanh toán; thông tin PayOS và callback/địa chỉ trở về được cấu hình để thanh toán thật. |
| Kích hoạt | Thực hiện “Tạo/dùng lại link PayOS” hoặc sự kiện/tác vụ backend tương ứng. |
| Luồng chính | 1. Đọc đầu vào/tài nguyên hiện tại và phiên áp dụng. 2. Thực hiện thao tác này: Tạo link thanh toán PayOS cho booking `PENDING`. Mỗi booking một payment; gọi lại thì trả link cũ, không tạo thêm. Mã đơn PayOS = id booking × 1.000.000 + 6 số ngẫu nhiên cuối mã vé: cố định cho mỗi booking và không trùng với đơn của môi trường khác trên tài khoản PayOS dùng chung. Link hết hạn cùng lúc với thời gian giữ ghế. 3. Trả/hiển thị kết quả chính thức và làm mới dữ liệu bị tác động sau thành công. |
| Luồng thay thế / ngoại lệ | Không dùng tham số chuyển hướng làm bằng chứng đã trả tiền. Xử lý huỷ, hết thời gian và 503 mà không báo thành công sai; trả muộn chỉ xác nhận nếu lấy lại được ghế, nếu không tạo hoàn tiền. |
| Hậu điều kiện | Kết quả thành công quan sát được khớp yêu cầu này; chuyển trạng thái được chỉ định được lưu. Từ chối không cấp quyền hoặc để thay đổi dở dang trái phép. |
| Ưu tiên | H |
| Tiêu chí nghiệm thu | **WEB-FR-PAY-01-AC-01** — Với tiền điều kiện/kích hoạt, kiểm tra: Tạo link thanh toán PayOS cho booking `PENDING`. Mỗi booking một payment; gọi lại thì trả link cũ, không tạo thêm. Mã đơn PayOS = id booking × 1.000.000 + 6 số ngẫu nhiên cuối mã vé: cố định cho mỗi booking và không trùng với đơn của môi trường khác trên tài khoản PayOS dùng chung. Link hết hạn cùng lúc với thời gian giữ ghế. **WEB-FR-PAY-01-AC-02** — Thử đầu vào sai/thiếu quyền/xung đột áp dụng và kiểm tra từ chối đã nêu, không đổi dữ liệu trái phép và không báo thành công sai. |
| Bằng chứng | [Cinema_BE/BookingService/BookingService/Controllers/PaymentController.cs](../Cinema_BE/BookingService/BookingService/Controllers/PaymentController.cs); [Cinema_Mobile/lib/features/payment/screens/payment_screen.dart](../Cinema_Mobile/lib/features/payment/screens/payment_screen.dart); [Cinema_Mobile/lib/features/staff/screens/staff_counter_checkout_screen.dart](../Cinema_Mobile/lib/features/staff/screens/staff_counter_checkout_screen.dart); [Cinema_BE/BookingService/BookingService/Services/Implementations/PaymentService.cs](../Cinema_BE/BookingService/BookingService/Services/Implementations/PaymentService.cs); [Cinema_BE/BookingService/BookingService/Helpers/PayOsSignature.cs](../Cinema_BE/BookingService/BookingService/Helpers/PayOsSignature.cs) |
| Quy tắc nghiệp vụ | WEB-BR-09, WEB-BR-10, WEB-BR-11, WEB-BR-12, WEB-BR-13, WEB-BR-14, WEB-BR-20 |
| Ca sử dụng / màn / API | UC-WEB-08; WEB-SCR-PAYMENT, WEB-SCR-CHECKOUT; WEB-API-088 |

### WEB-FR-PAY-02 — Xác minh PayOS

| Trường | Đặc tả |
| --- | --- |
| Tên | Xác minh PayOS |
| Mô tả | Xác minh thanh toán theo mã đơn (hoặc id booking): PayOS báo đã trả thì payment `SUCCESS` và booking `CONFIRMED`; khách huỷ trên trang PayOS thì payment `FAILED`, booking `CANCELLED` và nhả ghế ngay. Gọi lại nhiều lần vẫn an toàn. |
| Tác nhân | Chủ vé; nhân viên/quản trị viên với thao tác được phép; PayOS/hệ thống |
| Tiền điều kiện | Có vé đủ điều kiện thanh toán; thông tin PayOS và callback/địa chỉ trở về được cấu hình để thanh toán thật. |
| Kích hoạt | Thực hiện “Xác minh PayOS” hoặc sự kiện/tác vụ backend tương ứng. |
| Luồng chính | 1. Đọc đầu vào/tài nguyên hiện tại và phiên áp dụng. 2. Thực hiện thao tác này: Xác minh thanh toán theo mã đơn (hoặc id booking): PayOS báo đã trả thì payment `SUCCESS` và booking `CONFIRMED`; khách huỷ trên trang PayOS thì payment `FAILED`, booking `CANCELLED` và nhả ghế ngay. Gọi lại nhiều lần vẫn an toàn. 3. Trả/hiển thị kết quả chính thức và làm mới dữ liệu bị tác động sau thành công. |
| Luồng thay thế / ngoại lệ | Không dùng tham số chuyển hướng làm bằng chứng đã trả tiền. Xử lý huỷ, hết thời gian và 503 mà không báo thành công sai; trả muộn chỉ xác nhận nếu lấy lại được ghế, nếu không tạo hoàn tiền. |
| Hậu điều kiện | Kết quả thành công quan sát được khớp yêu cầu này; chuyển trạng thái được chỉ định được lưu. Từ chối không cấp quyền hoặc để thay đổi dở dang trái phép. |
| Ưu tiên | H |
| Tiêu chí nghiệm thu | **WEB-FR-PAY-02-AC-01** — Với tiền điều kiện/kích hoạt, kiểm tra: Xác minh thanh toán theo mã đơn (hoặc id booking): PayOS báo đã trả thì payment `SUCCESS` và booking `CONFIRMED`; khách huỷ trên trang PayOS thì payment `FAILED`, booking `CANCELLED` và nhả ghế ngay. Gọi lại nhiều lần vẫn an toàn. **WEB-FR-PAY-02-AC-02** — Thử đầu vào sai/thiếu quyền/xung đột áp dụng và kiểm tra từ chối đã nêu, không đổi dữ liệu trái phép và không báo thành công sai. |
| Bằng chứng | [Cinema_BE/BookingService/BookingService/Controllers/PaymentController.cs](../Cinema_BE/BookingService/BookingService/Controllers/PaymentController.cs); [Cinema_Mobile/lib/features/payment/screens/payment_screen.dart](../Cinema_Mobile/lib/features/payment/screens/payment_screen.dart); [Cinema_Mobile/lib/features/payment/screens/payment_result_screen.dart](../Cinema_Mobile/lib/features/payment/screens/payment_result_screen.dart); [Cinema_Mobile/lib/features/staff/screens/staff_counter_checkout_screen.dart](../Cinema_Mobile/lib/features/staff/screens/staff_counter_checkout_screen.dart); [Cinema_BE/BookingService/BookingService/Services/Implementations/PaymentService.cs](../Cinema_BE/BookingService/BookingService/Services/Implementations/PaymentService.cs); [Cinema_BE/BookingService/BookingService/Helpers/PayOsSignature.cs](../Cinema_BE/BookingService/BookingService/Helpers/PayOsSignature.cs) |
| Quy tắc nghiệp vụ | WEB-BR-09, WEB-BR-10, WEB-BR-11, WEB-BR-12, WEB-BR-13, WEB-BR-14, WEB-BR-20 |
| Ca sử dụng / màn / API | UC-WEB-08; WEB-SCR-PAYMENT, WEB-SCR-RESULT, WEB-SCR-CHECKOUT; WEB-API-087 |

### WEB-FR-PAY-03 — Chi tiết thanh toán

| Trường | Đặc tả |
| --- | --- |
| Tên | Chi tiết thanh toán |
| Mô tả | Xem chi tiết payment: chủ vé hoặc Staff/Admin. |
| Tác nhân | Chủ vé; nhân viên/quản trị viên với thao tác được phép; PayOS/hệ thống |
| Tiền điều kiện | Có vé đủ điều kiện thanh toán; thông tin PayOS và callback/địa chỉ trở về được cấu hình để thanh toán thật. |
| Kích hoạt | Thực hiện “Chi tiết thanh toán” hoặc sự kiện/tác vụ backend tương ứng. |
| Luồng chính | 1. Đọc đầu vào/tài nguyên hiện tại và phiên áp dụng. 2. Thực hiện thao tác này: Xem chi tiết payment: chủ vé hoặc Staff/Admin. 3. Trả/hiển thị kết quả chính thức và làm mới dữ liệu bị tác động sau thành công. |
| Luồng thay thế / ngoại lệ | Không dùng tham số chuyển hướng làm bằng chứng đã trả tiền. Xử lý huỷ, hết thời gian và 503 mà không báo thành công sai; trả muộn chỉ xác nhận nếu lấy lại được ghế, nếu không tạo hoàn tiền. |
| Hậu điều kiện | Dữ liệu/trạng thái đủ quyền được trả/hiển thị; đọc không đổi trạng thái vé/thanh toán. Dấu đã đọc thông báo chỉ đổi bằng thao tác ghi riêng. |
| Ưu tiên | H |
| Tiêu chí nghiệm thu | **WEB-FR-PAY-03-AC-01** — Với tiền điều kiện/kích hoạt, kiểm tra: Xem chi tiết payment: chủ vé hoặc Staff/Admin. **WEB-FR-PAY-03-AC-02** — Thử đầu vào sai/thiếu quyền/xung đột áp dụng và kiểm tra từ chối đã nêu, không đổi dữ liệu trái phép và không báo thành công sai. |
| Bằng chứng | [Cinema_BE/BookingService/BookingService/Controllers/PaymentController.cs](../Cinema_BE/BookingService/BookingService/Controllers/PaymentController.cs); [Cinema_Mobile/lib/features/booking/screens/booking_detail_screen.dart](../Cinema_Mobile/lib/features/booking/screens/booking_detail_screen.dart); [Cinema_Mobile/lib/features/payment/screens/payment_history_screen.dart](../Cinema_Mobile/lib/features/payment/screens/payment_history_screen.dart); [Cinema_Mobile/lib/features/staff/screens/staff_record_screen.dart](../Cinema_Mobile/lib/features/staff/screens/staff_record_screen.dart); [Cinema_BE/BookingService/BookingService/Services/Implementations/PaymentService.cs](../Cinema_BE/BookingService/BookingService/Services/Implementations/PaymentService.cs); [Cinema_BE/BookingService/BookingService/Helpers/PayOsSignature.cs](../Cinema_BE/BookingService/BookingService/Helpers/PayOsSignature.cs) |
| Quy tắc nghiệp vụ | WEB-BR-09, WEB-BR-10, WEB-BR-11, WEB-BR-12, WEB-BR-13, WEB-BR-14, WEB-BR-20 |
| Ca sử dụng / màn / API | UC-WEB-08; WEB-SCR-TICKET, WEB-SCR-PAYHISTORY, WEB-SCR-RECORD-PAYMENTS; WEB-API-084 |

### WEB-FR-PAY-04 — Lịch sử thanh toán của mình

| Trường | Đặc tả |
| --- | --- |
| Tên | Lịch sử thanh toán của mình |
| Mô tả | Khách xem lịch sử thanh toán của mình. |
| Tác nhân | Chủ vé; nhân viên/quản trị viên với thao tác được phép; PayOS/hệ thống |
| Tiền điều kiện | Có vé đủ điều kiện thanh toán; thông tin PayOS và callback/địa chỉ trở về được cấu hình để thanh toán thật. |
| Kích hoạt | Thực hiện “Lịch sử thanh toán của mình” hoặc sự kiện/tác vụ backend tương ứng. |
| Luồng chính | 1. Đọc đầu vào/tài nguyên hiện tại và phiên áp dụng. 2. Thực hiện thao tác này: Khách xem lịch sử thanh toán của mình. 3. Trả/hiển thị kết quả chính thức và làm mới dữ liệu bị tác động sau thành công. |
| Luồng thay thế / ngoại lệ | Không dùng tham số chuyển hướng làm bằng chứng đã trả tiền. Xử lý huỷ, hết thời gian và 503 mà không báo thành công sai; trả muộn chỉ xác nhận nếu lấy lại được ghế, nếu không tạo hoàn tiền. |
| Hậu điều kiện | Dữ liệu/trạng thái đủ quyền được trả/hiển thị; đọc không đổi trạng thái vé/thanh toán. Dấu đã đọc thông báo chỉ đổi bằng thao tác ghi riêng. |
| Ưu tiên | M |
| Tiêu chí nghiệm thu | **WEB-FR-PAY-04-AC-01** — Với tiền điều kiện/kích hoạt, kiểm tra: Khách xem lịch sử thanh toán của mình. **WEB-FR-PAY-04-AC-02** — Thử đầu vào sai/thiếu quyền/xung đột áp dụng và kiểm tra từ chối đã nêu, không đổi dữ liệu trái phép và không báo thành công sai. |
| Bằng chứng | [Cinema_BE/BookingService/BookingService/Controllers/PaymentController.cs](../Cinema_BE/BookingService/BookingService/Controllers/PaymentController.cs); [Cinema_Mobile/lib/features/payment/screens/payment_history_screen.dart](../Cinema_Mobile/lib/features/payment/screens/payment_history_screen.dart); [Cinema_BE/BookingService/BookingService/Services/Implementations/PaymentService.cs](../Cinema_BE/BookingService/BookingService/Services/Implementations/PaymentService.cs); [Cinema_BE/BookingService/BookingService/Helpers/PayOsSignature.cs](../Cinema_BE/BookingService/BookingService/Helpers/PayOsSignature.cs) |
| Quy tắc nghiệp vụ | WEB-BR-09, WEB-BR-10, WEB-BR-11, WEB-BR-12, WEB-BR-13, WEB-BR-14, WEB-BR-20 |
| Ca sử dụng / màn / API | UC-WEB-08; WEB-SCR-PAYHISTORY; WEB-API-095 |

### WEB-FR-PAY-05 — Thanh toán theo vé

| Trường | Đặc tả |
| --- | --- |
| Tên | Thanh toán theo vé |
| Mô tả | Xem các payment của một booking. |
| Tác nhân | Chủ vé; nhân viên/quản trị viên với thao tác được phép; PayOS/hệ thống |
| Tiền điều kiện | Có vé đủ điều kiện thanh toán; thông tin PayOS và callback/địa chỉ trở về được cấu hình để thanh toán thật. |
| Kích hoạt | Thực hiện “Thanh toán theo vé” hoặc sự kiện/tác vụ backend tương ứng. |
| Luồng chính | 1. Đọc đầu vào/tài nguyên hiện tại và phiên áp dụng. 2. Thực hiện thao tác này: Xem các payment của một booking. 3. Trả/hiển thị kết quả chính thức và làm mới dữ liệu bị tác động sau thành công. |
| Luồng thay thế / ngoại lệ | Không dùng tham số chuyển hướng làm bằng chứng đã trả tiền. Xử lý huỷ, hết thời gian và 503 mà không báo thành công sai; trả muộn chỉ xác nhận nếu lấy lại được ghế, nếu không tạo hoàn tiền. |
| Hậu điều kiện | Dữ liệu/trạng thái đủ quyền được trả/hiển thị; đọc không đổi trạng thái vé/thanh toán. Dấu đã đọc thông báo chỉ đổi bằng thao tác ghi riêng. |
| Ưu tiên | M |
| Tiêu chí nghiệm thu | **WEB-FR-PAY-05-AC-01** — Với tiền điều kiện/kích hoạt, kiểm tra: Xem các payment của một booking. **WEB-FR-PAY-05-AC-02** — Thử đầu vào sai/thiếu quyền/xung đột áp dụng và kiểm tra từ chối đã nêu, không đổi dữ liệu trái phép và không báo thành công sai. |
| Bằng chứng | [Cinema_BE/BookingService/BookingService/Controllers/PaymentController.cs](../Cinema_BE/BookingService/BookingService/Controllers/PaymentController.cs); [Cinema_Mobile/lib/features/staff/screens/staff_record_screen.dart](../Cinema_Mobile/lib/features/staff/screens/staff_record_screen.dart); [Cinema_BE/BookingService/BookingService/Services/Implementations/PaymentService.cs](../Cinema_BE/BookingService/BookingService/Services/Implementations/PaymentService.cs); [Cinema_BE/BookingService/BookingService/Helpers/PayOsSignature.cs](../Cinema_BE/BookingService/BookingService/Helpers/PayOsSignature.cs) |
| Quy tắc nghiệp vụ | WEB-BR-09, WEB-BR-10, WEB-BR-11, WEB-BR-12, WEB-BR-13, WEB-BR-14, WEB-BR-20 |
| Ca sử dụng / màn / API | UC-WEB-08; WEB-SCR-RECORD-PAYMENTS; WEB-API-085 |

### WEB-FR-PAY-06 — Truy cập hoàn tiền

| Trường | Đặc tả |
| --- | --- |
| Tên | Truy cập hoàn tiền |
| Mô tả | Chủ vé yêu cầu hoàn tiền bằng cách huỷ vé đã thanh toán đủ điều kiện; nhân viên/quản trị viên xem và hoàn tất hoặc từ chối quy trình hoàn tiền thủ công; quản trị viên có thể khởi tạo hoàn tiền thanh toán thủ công qua API. Quy tắc và trạng thái được quy định trong nhóm REF. |
| Tác nhân | Chủ vé; nhân viên/quản trị viên với thao tác được phép; PayOS/hệ thống |
| Tiền điều kiện | Có vé đủ điều kiện thanh toán; thông tin PayOS và callback/địa chỉ trở về được cấu hình để thanh toán thật. |
| Kích hoạt | Thực hiện “Truy cập hoàn tiền” hoặc sự kiện/tác vụ backend tương ứng. |
| Luồng chính | 1. Đọc đầu vào/tài nguyên hiện tại và phiên áp dụng. 2. Thực hiện thao tác này: Chủ vé yêu cầu hoàn tiền bằng cách huỷ vé đã thanh toán đủ điều kiện; nhân viên/quản trị viên xem và hoàn tất hoặc từ chối quy trình hoàn tiền thủ công; quản trị viên có thể khởi tạo hoàn tiền thanh toán thủ công qua API. Quy tắc và trạng thái được quy định trong nhóm REF. 3. Trả/hiển thị kết quả chính thức và làm mới dữ liệu bị tác động sau thành công. |
| Luồng thay thế / ngoại lệ | Không dùng tham số chuyển hướng làm bằng chứng đã trả tiền. Xử lý huỷ, hết thời gian và 503 mà không báo thành công sai; trả muộn chỉ xác nhận nếu lấy lại được ghế, nếu không tạo hoàn tiền. |
| Hậu điều kiện | Kết quả thành công quan sát được khớp yêu cầu này; chuyển trạng thái được chỉ định được lưu. Từ chối không cấp quyền hoặc để thay đổi dở dang trái phép. |
| Ưu tiên | H |
| Tiêu chí nghiệm thu | **WEB-FR-PAY-06-AC-01** — Với tiền điều kiện/kích hoạt, kiểm tra: Chủ vé yêu cầu hoàn tiền bằng cách huỷ vé đã thanh toán đủ điều kiện; nhân viên/quản trị viên xem và hoàn tất hoặc từ chối quy trình hoàn tiền thủ công; quản trị viên có thể khởi tạo hoàn tiền thanh toán thủ công qua API. Quy tắc và trạng thái được quy định trong nhóm REF. **WEB-FR-PAY-06-AC-02** — Thử đầu vào sai/thiếu quyền/xung đột áp dụng và kiểm tra từ chối đã nêu, không đổi dữ liệu trái phép và không báo thành công sai. |
| Bằng chứng | [Cinema_BE/BookingService/BookingService/Controllers/BookingController.cs](../Cinema_BE/BookingService/BookingService/Controllers/BookingController.cs); [Cinema_BE/BookingService/BookingService/Controllers/PaymentController.cs](../Cinema_BE/BookingService/BookingService/Controllers/PaymentController.cs); [Cinema_Mobile/lib/features/booking/screens/booking_detail_screen.dart](../Cinema_Mobile/lib/features/booking/screens/booking_detail_screen.dart); [Cinema_BE/BookingService/BookingService/Services/Implementations/PaymentService.cs](../Cinema_BE/BookingService/BookingService/Services/Implementations/PaymentService.cs); [Cinema_BE/BookingService/BookingService/Helpers/PayOsSignature.cs](../Cinema_BE/BookingService/BookingService/Helpers/PayOsSignature.cs) |
| Quy tắc nghiệp vụ | WEB-BR-09, WEB-BR-10, WEB-BR-11, WEB-BR-12, WEB-BR-13, WEB-BR-14, WEB-BR-20 |
| Ca sử dụng / màn / API | UC-WEB-08; WEB-SCR-TICKET; WEB-API-043, WEB-API-082, WEB-API-083 |

### WEB-FR-PAY-07 — Webhook có chữ ký

| Trường | Đặc tả |
| --- | --- |
| Tên | Webhook có chữ ký |
| Mô tả | Nhận webhook PayOS: kiểm tra chữ ký HMAC-SHA256 (sai thì 400); đơn không tồn tại hoặc sai số tiền thì 200 và bỏ qua; webhook lặp không xác nhận hay gửi email lần hai. Lưu tài khoản người trả (số tài khoản, tên, ngân hàng) để hoàn tiền. |
| Tác nhân | Hệ thống backend chung; khách nhận kết quả |
| Tiền điều kiện | Có sự kiện đã commit, kết quả PayOS tin cậy hoặc điều kiện tác vụ tương ứng; backend đã cấu hình xử lý. Tác vụ nền hoặc webhook chữ ký không cần phiên khách. |
| Kích hoạt | Thực hiện “Webhook có chữ ký” hoặc sự kiện/tác vụ backend tương ứng. |
| Luồng chính | 1. Đọc đầu vào/tài nguyên hiện tại và phiên áp dụng. 2. Thực hiện thao tác này: Nhận webhook PayOS: kiểm tra chữ ký HMAC-SHA256 (sai thì 400); đơn không tồn tại hoặc sai số tiền thì 200 và bỏ qua; webhook lặp không xác nhận hay gửi email lần hai. Lưu tài khoản người trả (số tài khoản, tên, ngân hàng) để hoàn tiền. 3. Trả/hiển thị kết quả chính thức và làm mới dữ liệu bị tác động sau thành công. |
| Luồng thay thế / ngoại lệ | Không dùng tham số chuyển hướng làm bằng chứng đã trả tiền. Xử lý huỷ, hết thời gian và 503 mà không báo thành công sai; trả muộn chỉ xác nhận nếu lấy lại được ghế, nếu không tạo hoàn tiền. |
| Hậu điều kiện | Kết quả thành công quan sát được khớp yêu cầu này; chuyển trạng thái được chỉ định được lưu. Từ chối không cấp quyền hoặc để thay đổi dở dang trái phép. |
| Ưu tiên | H |
| Tiêu chí nghiệm thu | **WEB-FR-PAY-07-AC-01** — Với tiền điều kiện/kích hoạt, kiểm tra: Nhận webhook PayOS: kiểm tra chữ ký HMAC-SHA256 (sai thì 400); đơn không tồn tại hoặc sai số tiền thì 200 và bỏ qua; webhook lặp không xác nhận hay gửi email lần hai. Lưu tài khoản người trả (số tài khoản, tên, ngân hàng) để hoàn tiền. **WEB-FR-PAY-07-AC-02** — Thử đầu vào sai/thiếu quyền/xung đột áp dụng và kiểm tra từ chối đã nêu, không đổi dữ liệu trái phép và không báo thành công sai. |
| Bằng chứng | [Cinema_BE/BookingService/BookingService/Controllers/PaymentController.cs](../Cinema_BE/BookingService/BookingService/Controllers/PaymentController.cs); [Cinema_BE/BookingService/BookingService/Services/Implementations/PaymentService.cs](../Cinema_BE/BookingService/BookingService/Services/Implementations/PaymentService.cs); [Cinema_BE/BookingService/BookingService/Helpers/PayOsSignature.cs](../Cinema_BE/BookingService/BookingService/Helpers/PayOsSignature.cs) |
| Quy tắc nghiệp vụ | WEB-BR-09, WEB-BR-10, WEB-BR-11, WEB-BR-12, WEB-BR-13, WEB-BR-14, WEB-BR-20 |
| Ca sử dụng / màn / API | UC-WEB-08; ; WEB-API-089 |

### WEB-FR-PAY-08 — Thanh toán muộn

| Trường | Đặc tả |
| --- | --- |
| Tên | Thanh toán muộn |
| Mô tả | Khi PayOS báo đã trả sau khi hết hạn giữ ghế, chỉ xác nhận vé nếu lấy lại được toàn bộ ghế; nếu không tạo yêu cầu hoàn toàn bộ tiền. Xác minh/webhook lặp không được lặp tác động tài chính. |
| Tác nhân | Hệ thống backend chung; khách nhận kết quả |
| Tiền điều kiện | Có sự kiện đã commit, kết quả PayOS tin cậy hoặc điều kiện tác vụ tương ứng; backend đã cấu hình xử lý. Tác vụ nền hoặc webhook chữ ký không cần phiên khách. |
| Kích hoạt | Thực hiện “Thanh toán muộn” hoặc sự kiện/tác vụ backend tương ứng. |
| Luồng chính | 1. Đọc đầu vào/tài nguyên hiện tại và phiên áp dụng. 2. Thực hiện thao tác này: Khi PayOS báo đã trả sau khi hết hạn giữ ghế, chỉ xác nhận vé nếu lấy lại được toàn bộ ghế; nếu không tạo yêu cầu hoàn toàn bộ tiền. Xác minh/webhook lặp không được lặp tác động tài chính. 3. Trả/hiển thị kết quả chính thức và làm mới dữ liệu bị tác động sau thành công. |
| Luồng thay thế / ngoại lệ | Không dùng tham số chuyển hướng làm bằng chứng đã trả tiền. Xử lý huỷ, hết thời gian và 503 mà không báo thành công sai; trả muộn chỉ xác nhận nếu lấy lại được ghế, nếu không tạo hoàn tiền. |
| Hậu điều kiện | Kết quả thành công quan sát được khớp yêu cầu này; chuyển trạng thái được chỉ định được lưu. Từ chối không cấp quyền hoặc để thay đổi dở dang trái phép. |
| Ưu tiên | M |
| Tiêu chí nghiệm thu | **WEB-FR-PAY-08-AC-01** — Với tiền điều kiện/kích hoạt, kiểm tra: Khi PayOS báo đã trả sau khi hết hạn giữ ghế, chỉ xác nhận vé nếu lấy lại được toàn bộ ghế; nếu không tạo yêu cầu hoàn toàn bộ tiền. Xác minh/webhook lặp không được lặp tác động tài chính. **WEB-FR-PAY-08-AC-02** — Thử đầu vào sai/thiếu quyền/xung đột áp dụng và kiểm tra từ chối đã nêu, không đổi dữ liệu trái phép và không báo thành công sai. |
| Bằng chứng | [Cinema_BE/BookingService/BookingService/Controllers/PaymentController.cs](../Cinema_BE/BookingService/BookingService/Controllers/PaymentController.cs); [Cinema_Mobile/lib/features/payment/screens/payment_result_screen.dart](../Cinema_Mobile/lib/features/payment/screens/payment_result_screen.dart); [Cinema_BE/BookingService/BookingService/Services/Implementations/PaymentService.cs](../Cinema_BE/BookingService/BookingService/Services/Implementations/PaymentService.cs); [Cinema_BE/BookingService/BookingService/Helpers/PayOsSignature.cs](../Cinema_BE/BookingService/BookingService/Helpers/PayOsSignature.cs) |
| Quy tắc nghiệp vụ | WEB-BR-09, WEB-BR-10, WEB-BR-11, WEB-BR-12, WEB-BR-13, WEB-BR-14, WEB-BR-20 |
| Ca sử dụng / màn / API | UC-WEB-08; WEB-SCR-RESULT; WEB-API-087, WEB-API-089 |

### WEB-FR-PAY-09 — Quản lý thanh toán

| Trường | Đặc tả |
| --- | --- |
| Tên | Quản lý thanh toán |
| Mô tả | Staff/Admin xem danh sách payment và xác minh lại một payment PayOS đang chờ. |
| Tác nhân | Chủ vé; nhân viên/quản trị viên với thao tác được phép; PayOS/hệ thống |
| Tiền điều kiện | Có vé đủ điều kiện thanh toán; thông tin PayOS và callback/địa chỉ trở về được cấu hình để thanh toán thật. |
| Kích hoạt | Thực hiện “Quản lý thanh toán” hoặc sự kiện/tác vụ backend tương ứng. |
| Luồng chính | 1. Đọc đầu vào/tài nguyên hiện tại và phiên áp dụng. 2. Thực hiện thao tác này: Staff/Admin xem danh sách payment và xác minh lại một payment PayOS đang chờ. 3. Trả/hiển thị kết quả chính thức và làm mới dữ liệu bị tác động sau thành công. |
| Luồng thay thế / ngoại lệ | Không dùng tham số chuyển hướng làm bằng chứng đã trả tiền. Xử lý huỷ, hết thời gian và 503 mà không báo thành công sai; trả muộn chỉ xác nhận nếu lấy lại được ghế, nếu không tạo hoàn tiền. |
| Hậu điều kiện | Kết quả thành công quan sát được khớp yêu cầu này; chuyển trạng thái được chỉ định được lưu. Từ chối không cấp quyền hoặc để thay đổi dở dang trái phép. |
| Ưu tiên | M |
| Tiêu chí nghiệm thu | **WEB-FR-PAY-09-AC-01** — Với tiền điều kiện/kích hoạt, kiểm tra: Staff/Admin xem danh sách payment và xác minh lại một payment PayOS đang chờ. **WEB-FR-PAY-09-AC-02** — Thử đầu vào sai/thiếu quyền/xung đột áp dụng và kiểm tra từ chối đã nêu, không đổi dữ liệu trái phép và không báo thành công sai. |
| Bằng chứng | [Cinema_BE/BookingService/BookingService/Controllers/PaymentController.cs](../Cinema_BE/BookingService/BookingService/Controllers/PaymentController.cs); [Cinema_Mobile/lib/features/staff/screens/staff_operations_screen.dart](../Cinema_Mobile/lib/features/staff/screens/staff_operations_screen.dart); [Cinema_Mobile/lib/features/staff/screens/staff_record_screen.dart](../Cinema_Mobile/lib/features/staff/screens/staff_record_screen.dart); [Cinema_BE/BookingService/BookingService/Services/Implementations/PaymentService.cs](../Cinema_BE/BookingService/BookingService/Services/Implementations/PaymentService.cs); [Cinema_BE/BookingService/BookingService/Helpers/PayOsSignature.cs](../Cinema_BE/BookingService/BookingService/Helpers/PayOsSignature.cs) |
| Quy tắc nghiệp vụ | WEB-BR-09, WEB-BR-10, WEB-BR-11, WEB-BR-12, WEB-BR-13, WEB-BR-14, WEB-BR-20 |
| Ca sử dụng / màn / API | UC-WEB-08; WEB-SCR-OPERATIONS, WEB-SCR-RECORD-PAYMENTS; WEB-API-087, WEB-API-096 |

### WEB-FR-PAY-10 — Tổng hợp doanh thu

| Trường | Đặc tả |
| --- | --- |
| Tên | Tổng hợp doanh thu |
| Mô tả | Admin xem doanh thu theo khoảng thời gian: số thanh toán đã nhận, doanh thu (`SUCCESS` + `REFUND_PENDING`), tiền đã hoàn (`REFUNDED`). |
| Tác nhân | Quản trị viên |
| Tiền điều kiện | Có vé đủ điều kiện thanh toán; thông tin PayOS và callback/địa chỉ trở về được cấu hình để thanh toán thật. |
| Kích hoạt | Thực hiện “Tổng hợp doanh thu” hoặc sự kiện/tác vụ backend tương ứng. |
| Luồng chính | 1. Đọc đầu vào/tài nguyên hiện tại và phiên áp dụng. 2. Thực hiện thao tác này: Admin xem doanh thu theo khoảng thời gian: số thanh toán đã nhận, doanh thu (`SUCCESS` + `REFUND_PENDING`), tiền đã hoàn (`REFUNDED`). 3. Trả/hiển thị kết quả chính thức và làm mới dữ liệu bị tác động sau thành công. |
| Luồng thay thế / ngoại lệ | Không dùng tham số chuyển hướng làm bằng chứng đã trả tiền. Xử lý huỷ, hết thời gian và 503 mà không báo thành công sai; trả muộn chỉ xác nhận nếu lấy lại được ghế, nếu không tạo hoàn tiền. |
| Hậu điều kiện | Dữ liệu/trạng thái đủ quyền được trả/hiển thị; đọc không đổi trạng thái vé/thanh toán. Dấu đã đọc thông báo chỉ đổi bằng thao tác ghi riêng. |
| Ưu tiên | M |
| Tiêu chí nghiệm thu | **WEB-FR-PAY-10-AC-01** — Với tiền điều kiện/kích hoạt, kiểm tra: Admin xem doanh thu theo khoảng thời gian: số thanh toán đã nhận, doanh thu (`SUCCESS` + `REFUND_PENDING`), tiền đã hoàn (`REFUNDED`). **WEB-FR-PAY-10-AC-02** — Thử đầu vào sai/thiếu quyền/xung đột áp dụng và kiểm tra từ chối đã nêu, không đổi dữ liệu trái phép và không báo thành công sai. |
| Bằng chứng | [Cinema_BE/BookingService/BookingService/Controllers/PaymentController.cs](../Cinema_BE/BookingService/BookingService/Controllers/PaymentController.cs); [Cinema_BE/BookingService/BookingService/Services/Implementations/PaymentService.cs](../Cinema_BE/BookingService/BookingService/Services/Implementations/PaymentService.cs); [Cinema_BE/BookingService/BookingService/Helpers/PayOsSignature.cs](../Cinema_BE/BookingService/BookingService/Helpers/PayOsSignature.cs) |
| Quy tắc nghiệp vụ | WEB-BR-09, WEB-BR-10, WEB-BR-11, WEB-BR-12, WEB-BR-13, WEB-BR-14, WEB-BR-20 |
| Ca sử dụng / màn / API | UC-WEB-08; ; WEB-API-094 |

### WEB-FR-PAY-11 — Tự kiểm tra thanh toán

| Trường | Đặc tả |
| --- | --- |
| Tên | Tự kiểm tra thanh toán |
| Mô tả | Trang thanh toán của app tự kiểm tra booking mỗi 5 giây và hỏi PayOS mỗi 30 giây khi đang mở; không có nút "Tôi đã trả tiền". |
| Tác nhân | Chủ vé; nhân viên/quản trị viên với thao tác được phép; PayOS/hệ thống |
| Tiền điều kiện | Có vé đủ điều kiện thanh toán; thông tin PayOS và callback/địa chỉ trở về được cấu hình để thanh toán thật. |
| Kích hoạt | Thực hiện “Tự kiểm tra thanh toán” hoặc sự kiện/tác vụ backend tương ứng. |
| Luồng chính | 1. Đọc đầu vào/tài nguyên hiện tại và phiên áp dụng. 2. Thực hiện thao tác này: Trang thanh toán của app tự kiểm tra booking mỗi 5 giây và hỏi PayOS mỗi 30 giây khi đang mở; không có nút "Tôi đã trả tiền". 3. Trả/hiển thị kết quả chính thức và làm mới dữ liệu bị tác động sau thành công. |
| Luồng thay thế / ngoại lệ | Không dùng tham số chuyển hướng làm bằng chứng đã trả tiền. Xử lý huỷ, hết thời gian và 503 mà không báo thành công sai; trả muộn chỉ xác nhận nếu lấy lại được ghế, nếu không tạo hoàn tiền. |
| Hậu điều kiện | Kết quả thành công quan sát được khớp yêu cầu này; chuyển trạng thái được chỉ định được lưu. Từ chối không cấp quyền hoặc để thay đổi dở dang trái phép. |
| Ưu tiên | M |
| Tiêu chí nghiệm thu | **WEB-FR-PAY-11-AC-01** — Với tiền điều kiện/kích hoạt, kiểm tra: Trang thanh toán của app tự kiểm tra booking mỗi 5 giây và hỏi PayOS mỗi 30 giây khi đang mở; không có nút "Tôi đã trả tiền". **WEB-FR-PAY-11-AC-02** — Thử đầu vào sai/thiếu quyền/xung đột áp dụng và kiểm tra từ chối đã nêu, không đổi dữ liệu trái phép và không báo thành công sai. |
| Bằng chứng | [Cinema_BE/BookingService/BookingService/Controllers/BookingController.cs](../Cinema_BE/BookingService/BookingService/Controllers/BookingController.cs); [Cinema_BE/BookingService/BookingService/Controllers/PaymentController.cs](../Cinema_BE/BookingService/BookingService/Controllers/PaymentController.cs); [Cinema_Mobile/lib/features/payment/screens/payment_screen.dart](../Cinema_Mobile/lib/features/payment/screens/payment_screen.dart); [Cinema_BE/BookingService/BookingService/Services/Implementations/PaymentService.cs](../Cinema_BE/BookingService/BookingService/Services/Implementations/PaymentService.cs); [Cinema_BE/BookingService/BookingService/Helpers/PayOsSignature.cs](../Cinema_BE/BookingService/BookingService/Helpers/PayOsSignature.cs) |
| Quy tắc nghiệp vụ | WEB-BR-09, WEB-BR-10, WEB-BR-11, WEB-BR-12, WEB-BR-13, WEB-BR-14, WEB-BR-20 |
| Ca sử dụng / màn / API | UC-WEB-08; WEB-SCR-PAYMENT; WEB-API-046, WEB-API-087 |

### WEB-FR-REF-01 — Tạo yêu cầu hoàn tiền

| Trường | Đặc tả |
| --- | --- |
| Tên | Tạo yêu cầu hoàn tiền |
| Mô tả | Yêu cầu hoàn tiền (`PENDING`) được tạo khi: khách huỷ vé đã thanh toán đúng hạn; Staff/Admin huỷ vé đã thanh toán; suất chiếu bị huỷ; trả tiền muộn mà mất ghế; Admin hoàn tiền thủ công cho một payment. Payment chuyển `REFUND_PENDING`, khách nhận email. |
| Tác nhân | Khách hàng yêu cầu/xem hoàn tiền của mình; nhân viên/quản trị viên xử lý; hệ thống tạo yêu cầu |
| Tiền điều kiện | Có sự kiện đã commit, kết quả PayOS tin cậy hoặc điều kiện tác vụ tương ứng; backend đã cấu hình xử lý. Tác vụ nền hoặc webhook chữ ký không cần phiên khách. |
| Kích hoạt | Thực hiện “Tạo yêu cầu hoàn tiền” hoặc sự kiện/tác vụ backend tương ứng. |
| Luồng chính | 1. Đọc đầu vào/tài nguyên hiện tại và phiên áp dụng. 2. Thực hiện thao tác này: Yêu cầu hoàn tiền (`PENDING`) được tạo khi: khách huỷ vé đã thanh toán đúng hạn; Staff/Admin huỷ vé đã thanh toán; suất chiếu bị huỷ; trả tiền muộn mà mất ghế; Admin hoàn tiền thủ công cho một payment. Payment chuyển `REFUND_PENDING`, khách nhận email. 3. Trả/hiển thị kết quả chính thức và làm mới dữ liệu bị tác động sau thành công. |
| Luồng thay thế / ngoại lệ | Từ chối khách huỷ quá muộn (409), hoàn tất thiếu mã chuyển tiền và từ chối thiếu lý do; không từ chối hoàn tiền do rạp huỷ. Sự kiện lặp không được tạo thêm yêu cầu. |
| Hậu điều kiện | Kết quả thành công quan sát được khớp yêu cầu này; chuyển trạng thái được chỉ định được lưu. Từ chối không cấp quyền hoặc để thay đổi dở dang trái phép. |
| Ưu tiên | H |
| Tiêu chí nghiệm thu | **WEB-FR-REF-01-AC-01** — Với tiền điều kiện/kích hoạt, kiểm tra: Yêu cầu hoàn tiền (`PENDING`) được tạo khi: khách huỷ vé đã thanh toán đúng hạn; Staff/Admin huỷ vé đã thanh toán; suất chiếu bị huỷ; trả tiền muộn mà mất ghế; Admin hoàn tiền thủ công cho một payment. Payment chuyển `REFUND_PENDING`, khách nhận email. **WEB-FR-REF-01-AC-02** — Thử đầu vào sai/thiếu quyền/xung đột áp dụng và kiểm tra từ chối đã nêu, không đổi dữ liệu trái phép và không báo thành công sai. |
| Bằng chứng | [Cinema_BE/BookingService/BookingService/Controllers/BookingController.cs](../Cinema_BE/BookingService/BookingService/Controllers/BookingController.cs); [Cinema_BE/BookingService/BookingService/Controllers/PaymentController.cs](../Cinema_BE/BookingService/BookingService/Controllers/PaymentController.cs); [Cinema_Mobile/lib/features/booking/screens/booking_detail_screen.dart](../Cinema_Mobile/lib/features/booking/screens/booking_detail_screen.dart); [Cinema_BE/BookingService/BookingService/Services/Implementations/RefundService.cs](../Cinema_BE/BookingService/BookingService/Services/Implementations/RefundService.cs); [Cinema_BE/BookingService/BookingService/Services/Implementations/BookingService.cs](../Cinema_BE/BookingService/BookingService/Services/Implementations/BookingService.cs) |
| Quy tắc nghiệp vụ | WEB-BR-17, WEB-BR-18, WEB-BR-19, WEB-BR-20 |
| Ca sử dụng / màn / API | UC-WEB-09; WEB-SCR-TICKET; WEB-API-043, WEB-API-083, WEB-API-089 |

### WEB-FR-REF-02 — Danh sách hoàn tiền quản lý

| Trường | Đặc tả |
| --- | --- |
| Tên | Danh sách hoàn tiền quản lý |
| Mô tả | Staff/Admin xem danh sách yêu cầu hoàn tiền (lọc theo trạng thái) và chi tiết: số tiền, lý do, tài khoản người trả. |
| Tác nhân | Nhân viên/quản trị viên |
| Tiền điều kiện | Có vé/thanh toán đã trả; khách tự huỷ phải còn ít nhất hai giờ trước suất; nhân viên xử lý cần yêu cầu đang chờ. |
| Kích hoạt | Thực hiện “Danh sách hoàn tiền quản lý” hoặc sự kiện/tác vụ backend tương ứng. |
| Luồng chính | 1. Đọc đầu vào/tài nguyên hiện tại và phiên áp dụng. 2. Thực hiện thao tác này: Staff/Admin xem danh sách yêu cầu hoàn tiền (lọc theo trạng thái) và chi tiết: số tiền, lý do, tài khoản người trả. 3. Trả/hiển thị kết quả chính thức và làm mới dữ liệu bị tác động sau thành công. |
| Luồng thay thế / ngoại lệ | Từ chối khách huỷ quá muộn (409), hoàn tất thiếu mã chuyển tiền và từ chối thiếu lý do; không từ chối hoàn tiền do rạp huỷ. Sự kiện lặp không được tạo thêm yêu cầu. |
| Hậu điều kiện | Dữ liệu/trạng thái đủ quyền được trả/hiển thị; đọc không đổi trạng thái vé/thanh toán. Dấu đã đọc thông báo chỉ đổi bằng thao tác ghi riêng. |
| Ưu tiên | H |
| Tiêu chí nghiệm thu | **WEB-FR-REF-02-AC-01** — Với tiền điều kiện/kích hoạt, kiểm tra: Staff/Admin xem danh sách yêu cầu hoàn tiền (lọc theo trạng thái) và chi tiết: số tiền, lý do, tài khoản người trả. **WEB-FR-REF-02-AC-02** — Thử đầu vào sai/thiếu quyền/xung đột áp dụng và kiểm tra từ chối đã nêu, không đổi dữ liệu trái phép và không báo thành công sai. |
| Bằng chứng | [Cinema_BE/BookingService/BookingService/Controllers/PaymentController.cs](../Cinema_BE/BookingService/BookingService/Controllers/PaymentController.cs); [Cinema_Mobile/lib/features/staff/screens/staff_operations_screen.dart](../Cinema_Mobile/lib/features/staff/screens/staff_operations_screen.dart); [Cinema_Mobile/lib/features/staff/screens/staff_record_screen.dart](../Cinema_Mobile/lib/features/staff/screens/staff_record_screen.dart); [Cinema_BE/BookingService/BookingService/Services/Implementations/RefundService.cs](../Cinema_BE/BookingService/BookingService/Services/Implementations/RefundService.cs); [Cinema_BE/BookingService/BookingService/Services/Implementations/BookingService.cs](../Cinema_BE/BookingService/BookingService/Services/Implementations/BookingService.cs) |
| Quy tắc nghiệp vụ | WEB-BR-17, WEB-BR-18, WEB-BR-19, WEB-BR-20 |
| Ca sử dụng / màn / API | UC-WEB-09; WEB-SCR-OPERATIONS, WEB-SCR-RECORD-REFUNDS; WEB-API-092, WEB-API-093 |

### WEB-FR-REF-03 — Ghi nhận chuyển tiền hoàn tất

| Trường | Đặc tả |
| --- | --- |
| Tên | Ghi nhận chuyển tiền hoàn tất |
| Mô tả | Staff chuyển khoản xong thì ghi nhận mã giao dịch: hoàn tiền `COMPLETED`, payment `REFUNDED`, booking `CANCELLED` và nhả ghế, khách nhận email kèm mã giao dịch. |
| Tác nhân | Nhân viên/quản trị viên |
| Tiền điều kiện | Có vé/thanh toán đã trả; khách tự huỷ phải còn ít nhất hai giờ trước suất; nhân viên xử lý cần yêu cầu đang chờ. |
| Kích hoạt | Thực hiện “Ghi nhận chuyển tiền hoàn tất” hoặc sự kiện/tác vụ backend tương ứng. |
| Luồng chính | 1. Đọc đầu vào/tài nguyên hiện tại và phiên áp dụng. 2. Thực hiện thao tác này: Staff chuyển khoản xong thì ghi nhận mã giao dịch: hoàn tiền `COMPLETED`, payment `REFUNDED`, booking `CANCELLED` và nhả ghế, khách nhận email kèm mã giao dịch. 3. Trả/hiển thị kết quả chính thức và làm mới dữ liệu bị tác động sau thành công. |
| Luồng thay thế / ngoại lệ | Từ chối khách huỷ quá muộn (409), hoàn tất thiếu mã chuyển tiền và từ chối thiếu lý do; không từ chối hoàn tiền do rạp huỷ. Sự kiện lặp không được tạo thêm yêu cầu. |
| Hậu điều kiện | Kết quả thành công quan sát được khớp yêu cầu này; chuyển trạng thái được chỉ định được lưu. Từ chối không cấp quyền hoặc để thay đổi dở dang trái phép. |
| Ưu tiên | H |
| Tiêu chí nghiệm thu | **WEB-FR-REF-03-AC-01** — Với tiền điều kiện/kích hoạt, kiểm tra: Staff chuyển khoản xong thì ghi nhận mã giao dịch: hoàn tiền `COMPLETED`, payment `REFUNDED`, booking `CANCELLED` và nhả ghế, khách nhận email kèm mã giao dịch. **WEB-FR-REF-03-AC-02** — Thử đầu vào sai/thiếu quyền/xung đột áp dụng và kiểm tra từ chối đã nêu, không đổi dữ liệu trái phép và không báo thành công sai. |
| Bằng chứng | [Cinema_BE/BookingService/BookingService/Controllers/PaymentController.cs](../Cinema_BE/BookingService/BookingService/Controllers/PaymentController.cs); [Cinema_Mobile/lib/features/staff/screens/staff_record_screen.dart](../Cinema_Mobile/lib/features/staff/screens/staff_record_screen.dart); [Cinema_BE/BookingService/BookingService/Services/Implementations/RefundService.cs](../Cinema_BE/BookingService/BookingService/Services/Implementations/RefundService.cs); [Cinema_BE/BookingService/BookingService/Services/Implementations/BookingService.cs](../Cinema_BE/BookingService/BookingService/Services/Implementations/BookingService.cs) |
| Quy tắc nghiệp vụ | WEB-BR-17, WEB-BR-18, WEB-BR-19, WEB-BR-20 |
| Ca sử dụng / màn / API | UC-WEB-09; WEB-SCR-RECORD-REFUNDS; WEB-API-090 |

### WEB-FR-REF-04 — Từ chối hoàn tiền

| Trường | Đặc tả |
| --- | --- |
| Tên | Từ chối hoàn tiền |
| Mô tả | Staff từ chối yêu cầu (bắt buộc lý do, chỉ khi `PENDING`): payment về `SUCCESS`, booking về `CONFIRMED` và giữ ghế; khách thấy lý do trong chi tiết vé và nhận email. Không từ chối được hoàn tiền của vé do rạp huỷ. |
| Tác nhân | Nhân viên/quản trị viên |
| Tiền điều kiện | Có vé/thanh toán đã trả; khách tự huỷ phải còn ít nhất hai giờ trước suất; nhân viên xử lý cần yêu cầu đang chờ. |
| Kích hoạt | Thực hiện “Từ chối hoàn tiền” hoặc sự kiện/tác vụ backend tương ứng. |
| Luồng chính | 1. Đọc đầu vào/tài nguyên hiện tại và phiên áp dụng. 2. Thực hiện thao tác này: Staff từ chối yêu cầu (bắt buộc lý do, chỉ khi `PENDING`): payment về `SUCCESS`, booking về `CONFIRMED` và giữ ghế; khách thấy lý do trong chi tiết vé và nhận email. Không từ chối được hoàn tiền của vé do rạp huỷ. 3. Trả/hiển thị kết quả chính thức và làm mới dữ liệu bị tác động sau thành công. |
| Luồng thay thế / ngoại lệ | Từ chối khách huỷ quá muộn (409), hoàn tất thiếu mã chuyển tiền và từ chối thiếu lý do; không từ chối hoàn tiền do rạp huỷ. Sự kiện lặp không được tạo thêm yêu cầu. |
| Hậu điều kiện | Kết quả thành công quan sát được khớp yêu cầu này; chuyển trạng thái được chỉ định được lưu. Từ chối không cấp quyền hoặc để thay đổi dở dang trái phép. |
| Ưu tiên | H |
| Tiêu chí nghiệm thu | **WEB-FR-REF-04-AC-01** — Với tiền điều kiện/kích hoạt, kiểm tra: Staff từ chối yêu cầu (bắt buộc lý do, chỉ khi `PENDING`): payment về `SUCCESS`, booking về `CONFIRMED` và giữ ghế; khách thấy lý do trong chi tiết vé và nhận email. Không từ chối được hoàn tiền của vé do rạp huỷ. **WEB-FR-REF-04-AC-02** — Thử đầu vào sai/thiếu quyền/xung đột áp dụng và kiểm tra từ chối đã nêu, không đổi dữ liệu trái phép và không báo thành công sai. |
| Bằng chứng | [Cinema_BE/BookingService/BookingService/Controllers/PaymentController.cs](../Cinema_BE/BookingService/BookingService/Controllers/PaymentController.cs); [Cinema_Mobile/lib/features/staff/screens/staff_record_screen.dart](../Cinema_Mobile/lib/features/staff/screens/staff_record_screen.dart); [Cinema_BE/BookingService/BookingService/Services/Implementations/RefundService.cs](../Cinema_BE/BookingService/BookingService/Services/Implementations/RefundService.cs); [Cinema_BE/BookingService/BookingService/Services/Implementations/BookingService.cs](../Cinema_BE/BookingService/BookingService/Services/Implementations/BookingService.cs) |
| Quy tắc nghiệp vụ | WEB-BR-17, WEB-BR-18, WEB-BR-19, WEB-BR-20 |
| Ca sử dụng / màn / API | UC-WEB-09; WEB-SCR-RECORD-REFUNDS; WEB-API-091 |

### WEB-FR-REF-05 — Mở lại hoàn tiền đã từ chối

| Trường | Đặc tả |
| --- | --- |
| Tên | Mở lại hoàn tiền đã từ chối |
| Mô tả | Yêu cầu đã bị từ chối được mở lại khi rạp huỷ vé hoặc suất chiếu sau đó. |
| Tác nhân | Hệ thống backend chung; khách nhận kết quả |
| Tiền điều kiện | Có sự kiện đã commit, kết quả PayOS tin cậy hoặc điều kiện tác vụ tương ứng; backend đã cấu hình xử lý. Tác vụ nền hoặc webhook chữ ký không cần phiên khách. |
| Kích hoạt | Thực hiện “Mở lại hoàn tiền đã từ chối” hoặc sự kiện/tác vụ backend tương ứng. |
| Luồng chính | 1. Đọc đầu vào/tài nguyên hiện tại và phiên áp dụng. 2. Thực hiện thao tác này: Yêu cầu đã bị từ chối được mở lại khi rạp huỷ vé hoặc suất chiếu sau đó. 3. Trả/hiển thị kết quả chính thức và làm mới dữ liệu bị tác động sau thành công. |
| Luồng thay thế / ngoại lệ | Từ chối khách huỷ quá muộn (409), hoàn tất thiếu mã chuyển tiền và từ chối thiếu lý do; không từ chối hoàn tiền do rạp huỷ. Sự kiện lặp không được tạo thêm yêu cầu. |
| Hậu điều kiện | Kết quả thành công quan sát được khớp yêu cầu này; chuyển trạng thái được chỉ định được lưu. Từ chối không cấp quyền hoặc để thay đổi dở dang trái phép. |
| Ưu tiên | M |
| Tiêu chí nghiệm thu | **WEB-FR-REF-05-AC-01** — Với tiền điều kiện/kích hoạt, kiểm tra: Yêu cầu đã bị từ chối được mở lại khi rạp huỷ vé hoặc suất chiếu sau đó. **WEB-FR-REF-05-AC-02** — Thử đầu vào sai/thiếu quyền/xung đột áp dụng và kiểm tra từ chối đã nêu, không đổi dữ liệu trái phép và không báo thành công sai. |
| Bằng chứng | [Cinema_BE/MovieService/MovieService/Controllers/ShowtimesController.cs](../Cinema_BE/MovieService/MovieService/Controllers/ShowtimesController.cs); [Cinema_BE/BookingService/BookingService/Controllers/BookingController.cs](../Cinema_BE/BookingService/BookingService/Controllers/BookingController.cs); [Cinema_Mobile/lib/features/booking/screens/booking_detail_screen.dart](../Cinema_Mobile/lib/features/booking/screens/booking_detail_screen.dart); [Cinema_Mobile/lib/features/staff/screens/staff_record_screen.dart](../Cinema_Mobile/lib/features/staff/screens/staff_record_screen.dart); [Cinema_BE/BookingService/BookingService/Services/Implementations/RefundService.cs](../Cinema_BE/BookingService/BookingService/Services/Implementations/RefundService.cs); [Cinema_BE/BookingService/BookingService/Services/Implementations/BookingService.cs](../Cinema_BE/BookingService/BookingService/Services/Implementations/BookingService.cs) |
| Quy tắc nghiệp vụ | WEB-BR-17, WEB-BR-18, WEB-BR-19, WEB-BR-20 |
| Ca sử dụng / màn / API | UC-WEB-09; WEB-SCR-TICKET, WEB-SCR-RECORD-REFUNDS; WEB-API-016, WEB-API-043 |

### WEB-FR-REF-06 — Trạng thái hoàn tiền của mình

| Trường | Đặc tả |
| --- | --- |
| Tên | Trạng thái hoàn tiền của mình |
| Mô tả | Khách xem trạng thái hoàn tiền của vé. |
| Tác nhân | Khách hàng yêu cầu/xem hoàn tiền của mình; nhân viên/quản trị viên xử lý; hệ thống tạo yêu cầu |
| Tiền điều kiện | Có vé/thanh toán đã trả; khách tự huỷ phải còn ít nhất hai giờ trước suất; nhân viên xử lý cần yêu cầu đang chờ. |
| Kích hoạt | Thực hiện “Trạng thái hoàn tiền của mình” hoặc sự kiện/tác vụ backend tương ứng. |
| Luồng chính | 1. Đọc đầu vào/tài nguyên hiện tại và phiên áp dụng. 2. Thực hiện thao tác này: Khách xem trạng thái hoàn tiền của vé. 3. Trả/hiển thị kết quả chính thức và làm mới dữ liệu bị tác động sau thành công. |
| Luồng thay thế / ngoại lệ | Từ chối khách huỷ quá muộn (409), hoàn tất thiếu mã chuyển tiền và từ chối thiếu lý do; không từ chối hoàn tiền do rạp huỷ. Sự kiện lặp không được tạo thêm yêu cầu. |
| Hậu điều kiện | Dữ liệu/trạng thái đủ quyền được trả/hiển thị; đọc không đổi trạng thái vé/thanh toán. Dấu đã đọc thông báo chỉ đổi bằng thao tác ghi riêng. |
| Ưu tiên | M |
| Tiêu chí nghiệm thu | **WEB-FR-REF-06-AC-01** — Với tiền điều kiện/kích hoạt, kiểm tra: Khách xem trạng thái hoàn tiền của vé. **WEB-FR-REF-06-AC-02** — Thử đầu vào sai/thiếu quyền/xung đột áp dụng và kiểm tra từ chối đã nêu, không đổi dữ liệu trái phép và không báo thành công sai. |
| Bằng chứng | [Cinema_BE/BookingService/BookingService/Controllers/PaymentController.cs](../Cinema_BE/BookingService/BookingService/Controllers/PaymentController.cs); [Cinema_Mobile/lib/features/booking/screens/booking_detail_screen.dart](../Cinema_Mobile/lib/features/booking/screens/booking_detail_screen.dart); [Cinema_Mobile/lib/features/staff/screens/staff_record_screen.dart](../Cinema_Mobile/lib/features/staff/screens/staff_record_screen.dart); [Cinema_BE/BookingService/BookingService/Services/Implementations/RefundService.cs](../Cinema_BE/BookingService/BookingService/Services/Implementations/RefundService.cs); [Cinema_BE/BookingService/BookingService/Services/Implementations/BookingService.cs](../Cinema_BE/BookingService/BookingService/Services/Implementations/BookingService.cs) |
| Quy tắc nghiệp vụ | WEB-BR-17, WEB-BR-18, WEB-BR-19, WEB-BR-20 |
| Ca sử dụng / màn / API | UC-WEB-09; WEB-SCR-TICKET, WEB-SCR-RECORD-PAYMENTS; WEB-API-082 |

### WEB-FR-REF-07 — Một hoàn tiền mỗi thanh toán

| Trường | Đặc tả |
| --- | --- |
| Tên | Một hoàn tiền mỗi thanh toán |
| Mô tả | Mỗi payment chỉ có một yêu cầu hoàn tiền, kể cả khi event bị giao lại. |
| Tác nhân | Hệ thống backend chung; khách nhận kết quả |
| Tiền điều kiện | Có sự kiện đã commit, kết quả PayOS tin cậy hoặc điều kiện tác vụ tương ứng; backend đã cấu hình xử lý. Tác vụ nền hoặc webhook chữ ký không cần phiên khách. |
| Kích hoạt | Thực hiện “Một hoàn tiền mỗi thanh toán” hoặc sự kiện/tác vụ backend tương ứng. |
| Luồng chính | 1. Đọc đầu vào/tài nguyên hiện tại và phiên áp dụng. 2. Thực hiện thao tác này: Mỗi payment chỉ có một yêu cầu hoàn tiền, kể cả khi event bị giao lại. 3. Trả/hiển thị kết quả chính thức và làm mới dữ liệu bị tác động sau thành công. |
| Luồng thay thế / ngoại lệ | Từ chối khách huỷ quá muộn (409), hoàn tất thiếu mã chuyển tiền và từ chối thiếu lý do; không từ chối hoàn tiền do rạp huỷ. Sự kiện lặp không được tạo thêm yêu cầu. |
| Hậu điều kiện | Kết quả thành công quan sát được khớp yêu cầu này; chuyển trạng thái được chỉ định được lưu. Từ chối không cấp quyền hoặc để thay đổi dở dang trái phép. |
| Ưu tiên | H |
| Tiêu chí nghiệm thu | **WEB-FR-REF-07-AC-01** — Với tiền điều kiện/kích hoạt, kiểm tra: Mỗi payment chỉ có một yêu cầu hoàn tiền, kể cả khi event bị giao lại. **WEB-FR-REF-07-AC-02** — Thử đầu vào sai/thiếu quyền/xung đột áp dụng và kiểm tra từ chối đã nêu, không đổi dữ liệu trái phép và không báo thành công sai. |
| Bằng chứng | [Cinema_BE/BookingService/BookingService/Controllers/BookingController.cs](../Cinema_BE/BookingService/BookingService/Controllers/BookingController.cs); [Cinema_BE/BookingService/BookingService/Controllers/PaymentController.cs](../Cinema_BE/BookingService/BookingService/Controllers/PaymentController.cs); [Cinema_Mobile/lib/features/staff/screens/staff_record_screen.dart](../Cinema_Mobile/lib/features/staff/screens/staff_record_screen.dart); [Cinema_BE/BookingService/BookingService/Services/Implementations/RefundService.cs](../Cinema_BE/BookingService/BookingService/Services/Implementations/RefundService.cs); [Cinema_BE/BookingService/BookingService/Services/Implementations/BookingService.cs](../Cinema_BE/BookingService/BookingService/Services/Implementations/BookingService.cs) |
| Quy tắc nghiệp vụ | WEB-BR-17, WEB-BR-18, WEB-BR-19, WEB-BR-20 |
| Ca sử dụng / màn / API | UC-WEB-09; WEB-SCR-RECORD-REFUNDS; WEB-API-043, WEB-API-082 |

### WEB-FR-POS-01 — Tạo vé tại quầy

| Trường | Đặc tả |
| --- | --- |
| Tên | Tạo vé tại quầy |
| Mô tả | Staff/Admin bán vé cho **khách vãng lai** (không tài khoản; email và số điện thoại không bắt buộc) hoặc **thành viên** (ID tài khoản + email, hoặc tìm theo số điện thoại; thành viên được dùng và tích điểm). Chọn phim, suất trong 7 ngày tới, ghế trên sơ đồ (sweetbox theo cặp, giá theo loại). |
| Tác nhân | Nhân viên/quản trị viên |
| Tiền điều kiện | Phiên quản lý đang hoạt động; suất OPEN chưa bắt đầu còn ghế. |
| Kích hoạt | Thực hiện “Tạo vé tại quầy” hoặc sự kiện/tác vụ backend tương ứng. |
| Luồng chính | 1. Đọc đầu vào/tài nguyên hiện tại và phiên áp dụng. 2. Thực hiện thao tác này: Staff/Admin bán vé cho **khách vãng lai** (không tài khoản; email và số điện thoại không bắt buộc) hoặc **thành viên** (ID tài khoản + email, hoặc tìm theo số điện thoại; thành viên được dùng và tích điểm). Chọn phim, suất trong 7 ngày tới, ghế trên sơ đồ (sweetbox theo cặp, giá theo loại). 3. Trả/hiển thị kết quả chính thức và làm mới dữ liệu bị tác động sau thành công. |
| Luồng thay thế / ngoại lệ | Từ chối thiếu tiền mặt; huỷ link PayOS chưa trả trước khi chuyển sang tiền mặt; nếu chuyển khoản đã thành công trả 409. Không có email thì in/hiện QR. |
| Hậu điều kiện | Kết quả thành công quan sát được khớp yêu cầu này; chuyển trạng thái được chỉ định được lưu. Từ chối không cấp quyền hoặc để thay đổi dở dang trái phép. |
| Ưu tiên | H |
| Tiêu chí nghiệm thu | **WEB-FR-POS-01-AC-01** — Với tiền điều kiện/kích hoạt, kiểm tra: Staff/Admin bán vé cho **khách vãng lai** (không tài khoản; email và số điện thoại không bắt buộc) hoặc **thành viên** (ID tài khoản + email, hoặc tìm theo số điện thoại; thành viên được dùng và tích điểm). Chọn phim, suất trong 7 ngày tới, ghế trên sơ đồ (sweetbox theo cặp, giá theo loại). **WEB-FR-POS-01-AC-02** — Thử đầu vào sai/thiếu quyền/xung đột áp dụng và kiểm tra từ chối đã nêu, không đổi dữ liệu trái phép và không báo thành công sai. |
| Bằng chứng | [Cinema_BE/MovieService/MovieService/Controllers/SeatsController.cs](../Cinema_BE/MovieService/MovieService/Controllers/SeatsController.cs); [Cinema_BE/MovieService/MovieService/Controllers/ShowtimesController.cs](../Cinema_BE/MovieService/MovieService/Controllers/ShowtimesController.cs); [Cinema_BE/AuthService/AuthService/Controllers/MembersController.cs](../Cinema_BE/AuthService/AuthService/Controllers/MembersController.cs); [Cinema_BE/BookingService/BookingService/Controllers/BookingController.cs](../Cinema_BE/BookingService/BookingService/Controllers/BookingController.cs); [Cinema_Mobile/lib/features/staff/screens/staff_create_booking_screen.dart](../Cinema_Mobile/lib/features/staff/screens/staff_create_booking_screen.dart) |
| Quy tắc nghiệp vụ | WEB-BR-08, WEB-BR-15, WEB-BR-16, WEB-BR-22, WEB-BR-23, WEB-BR-27, WEB-BR-28, WEB-BR-29 |
| Ca sử dụng / màn / API | UC-WEB-10; WEB-SCR-COUNTER; WEB-API-013, WEB-API-023, WEB-API-030, WEB-API-055 |

### WEB-FR-POS-02 — Thu tiền tại quầy

| Trường | Đặc tả |
| --- | --- |
| Tên | Thu tiền tại quầy |
| Mô tả | Giữ ghế xong chuyển sang màn **Take payment**: thông tin vé, khách, tổng tiền, đồng hồ giữ ghế, ô email nhận vé. |
| Tác nhân | Nhân viên/quản trị viên |
| Tiền điều kiện | Phiên quản lý đang hoạt động; suất OPEN chưa bắt đầu còn ghế. |
| Kích hoạt | Thực hiện “Thu tiền tại quầy” hoặc sự kiện/tác vụ backend tương ứng. |
| Luồng chính | 1. Đọc đầu vào/tài nguyên hiện tại và phiên áp dụng. 2. Thực hiện thao tác này: Giữ ghế xong chuyển sang màn **Take payment**: thông tin vé, khách, tổng tiền, đồng hồ giữ ghế, ô email nhận vé. 3. Trả/hiển thị kết quả chính thức và làm mới dữ liệu bị tác động sau thành công. |
| Luồng thay thế / ngoại lệ | Từ chối thiếu tiền mặt; huỷ link PayOS chưa trả trước khi chuyển sang tiền mặt; nếu chuyển khoản đã thành công trả 409. Không có email thì in/hiện QR. |
| Hậu điều kiện | Dữ liệu/trạng thái đủ quyền được trả/hiển thị; đọc không đổi trạng thái vé/thanh toán. Dấu đã đọc thông báo chỉ đổi bằng thao tác ghi riêng. |
| Ưu tiên | H |
| Tiêu chí nghiệm thu | **WEB-FR-POS-02-AC-01** — Với tiền điều kiện/kích hoạt, kiểm tra: Giữ ghế xong chuyển sang màn **Take payment**: thông tin vé, khách, tổng tiền, đồng hồ giữ ghế, ô email nhận vé. **WEB-FR-POS-02-AC-02** — Thử đầu vào sai/thiếu quyền/xung đột áp dụng và kiểm tra từ chối đã nêu, không đổi dữ liệu trái phép và không báo thành công sai. |
| Bằng chứng | [Cinema_BE/BookingService/BookingService/Controllers/BookingController.cs](../Cinema_BE/BookingService/BookingService/Controllers/BookingController.cs); [Cinema_Mobile/lib/features/staff/screens/staff_counter_checkout_screen.dart](../Cinema_Mobile/lib/features/staff/screens/staff_counter_checkout_screen.dart) |
| Quy tắc nghiệp vụ | WEB-BR-08, WEB-BR-15, WEB-BR-16, WEB-BR-22, WEB-BR-23, WEB-BR-27, WEB-BR-28, WEB-BR-29 |
| Ca sử dụng / màn / API | UC-WEB-10; WEB-SCR-CHECKOUT; WEB-API-046 |

### WEB-FR-POS-03 — Tiền mặt và tiền thối

| Trường | Đặc tả |
| --- | --- |
| Tên | Tiền mặt và tiền thối |
| Mô tả | **Tiền mặt**: nhập số tiền khách đưa (có nút số tiền chẵn), màn hình tính tiền thối; thiếu tiền thì không cho xác nhận. Server ghi payment `CASH` `SUCCESS` (mã giao dịch `CASH-<mã vé>`) và xác nhận vé. |
| Tác nhân | Nhân viên/quản trị viên |
| Tiền điều kiện | Phiên quản lý đang hoạt động; suất OPEN chưa bắt đầu còn ghế. |
| Kích hoạt | Thực hiện “Tiền mặt và tiền thối” hoặc sự kiện/tác vụ backend tương ứng. |
| Luồng chính | 1. Đọc đầu vào/tài nguyên hiện tại và phiên áp dụng. 2. Thực hiện thao tác này: **Tiền mặt**: nhập số tiền khách đưa (có nút số tiền chẵn), màn hình tính tiền thối; thiếu tiền thì không cho xác nhận. Server ghi payment `CASH` `SUCCESS` (mã giao dịch `CASH-<mã vé>`) và xác nhận vé. 3. Trả/hiển thị kết quả chính thức và làm mới dữ liệu bị tác động sau thành công. |
| Luồng thay thế / ngoại lệ | Từ chối thiếu tiền mặt; huỷ link PayOS chưa trả trước khi chuyển sang tiền mặt; nếu chuyển khoản đã thành công trả 409. Không có email thì in/hiện QR. |
| Hậu điều kiện | Kết quả thành công quan sát được khớp yêu cầu này; chuyển trạng thái được chỉ định được lưu. Từ chối không cấp quyền hoặc để thay đổi dở dang trái phép. |
| Ưu tiên | H |
| Tiêu chí nghiệm thu | **WEB-FR-POS-03-AC-01** — Với tiền điều kiện/kích hoạt, kiểm tra: **Tiền mặt**: nhập số tiền khách đưa (có nút số tiền chẵn), màn hình tính tiền thối; thiếu tiền thì không cho xác nhận. Server ghi payment `CASH` `SUCCESS` (mã giao dịch `CASH-<mã vé>`) và xác nhận vé. **WEB-FR-POS-03-AC-02** — Thử đầu vào sai/thiếu quyền/xung đột áp dụng và kiểm tra từ chối đã nêu, không đổi dữ liệu trái phép và không báo thành công sai. |
| Bằng chứng | [Cinema_BE/BookingService/BookingService/Controllers/PaymentController.cs](../Cinema_BE/BookingService/BookingService/Controllers/PaymentController.cs); [Cinema_Mobile/lib/features/staff/screens/staff_counter_checkout_screen.dart](../Cinema_Mobile/lib/features/staff/screens/staff_counter_checkout_screen.dart) |
| Quy tắc nghiệp vụ | WEB-BR-08, WEB-BR-15, WEB-BR-16, WEB-BR-22, WEB-BR-23, WEB-BR-27, WEB-BR-28, WEB-BR-29 |
| Ca sử dụng / màn / API | UC-WEB-10; WEB-SCR-CHECKOUT; WEB-API-086 |

### WEB-FR-POS-04 — QR chuyển khoản

| Trường | Đặc tả |
| --- | --- |
| Tên | QR chuyển khoản |
| Mô tả | **Chuyển khoản**: hiện VietQR của PayOS để khách quét bằng app ngân hàng (link tạo trước đó thì hiện QR của trang thanh toán); màn hình tự kiểm tra mỗi 3 giây và chuyển sang đã thanh toán khi tiền về. |
| Tác nhân | Nhân viên/quản trị viên |
| Tiền điều kiện | Phiên quản lý đang hoạt động; suất OPEN chưa bắt đầu còn ghế. |
| Kích hoạt | Thực hiện “QR chuyển khoản” hoặc sự kiện/tác vụ backend tương ứng. |
| Luồng chính | 1. Đọc đầu vào/tài nguyên hiện tại và phiên áp dụng. 2. Thực hiện thao tác này: **Chuyển khoản**: hiện VietQR của PayOS để khách quét bằng app ngân hàng (link tạo trước đó thì hiện QR của trang thanh toán); màn hình tự kiểm tra mỗi 3 giây và chuyển sang đã thanh toán khi tiền về. 3. Trả/hiển thị kết quả chính thức và làm mới dữ liệu bị tác động sau thành công. |
| Luồng thay thế / ngoại lệ | Từ chối thiếu tiền mặt; huỷ link PayOS chưa trả trước khi chuyển sang tiền mặt; nếu chuyển khoản đã thành công trả 409. Không có email thì in/hiện QR. |
| Hậu điều kiện | Kết quả thành công quan sát được khớp yêu cầu này; chuyển trạng thái được chỉ định được lưu. Từ chối không cấp quyền hoặc để thay đổi dở dang trái phép. |
| Ưu tiên | H |
| Tiêu chí nghiệm thu | **WEB-FR-POS-04-AC-01** — Với tiền điều kiện/kích hoạt, kiểm tra: **Chuyển khoản**: hiện VietQR của PayOS để khách quét bằng app ngân hàng (link tạo trước đó thì hiện QR của trang thanh toán); màn hình tự kiểm tra mỗi 3 giây và chuyển sang đã thanh toán khi tiền về. **WEB-FR-POS-04-AC-02** — Thử đầu vào sai/thiếu quyền/xung đột áp dụng và kiểm tra từ chối đã nêu, không đổi dữ liệu trái phép và không báo thành công sai. |
| Bằng chứng | [Cinema_BE/BookingService/BookingService/Controllers/PaymentController.cs](../Cinema_BE/BookingService/BookingService/Controllers/PaymentController.cs); [Cinema_Mobile/lib/features/staff/screens/staff_counter_checkout_screen.dart](../Cinema_Mobile/lib/features/staff/screens/staff_counter_checkout_screen.dart) |
| Quy tắc nghiệp vụ | WEB-BR-08, WEB-BR-15, WEB-BR-16, WEB-BR-22, WEB-BR-23, WEB-BR-27, WEB-BR-28, WEB-BR-29 |
| Ca sử dụng / màn / API | UC-WEB-10; WEB-SCR-CHECKOUT; WEB-API-087, WEB-API-088 |

### WEB-FR-POS-05 — Đổi chuyển khoản sang tiền mặt

| Trường | Đặc tả |
| --- | --- |
| Tên | Đổi chuyển khoản sang tiền mặt |
| Mô tả | Đổi từ chuyển khoản sang tiền mặt theo WEB-BR-22: link PayOS bị huỷ, payment PayOS `FAILED`; khách đã chuyển khoản thì 409. |
| Tác nhân | Nhân viên/quản trị viên |
| Tiền điều kiện | Phiên quản lý đang hoạt động; suất OPEN chưa bắt đầu còn ghế. |
| Kích hoạt | Thực hiện “Đổi chuyển khoản sang tiền mặt” hoặc sự kiện/tác vụ backend tương ứng. |
| Luồng chính | 1. Đọc đầu vào/tài nguyên hiện tại và phiên áp dụng. 2. Thực hiện thao tác này: Đổi từ chuyển khoản sang tiền mặt theo WEB-BR-22: link PayOS bị huỷ, payment PayOS `FAILED`; khách đã chuyển khoản thì 409. 3. Trả/hiển thị kết quả chính thức và làm mới dữ liệu bị tác động sau thành công. |
| Luồng thay thế / ngoại lệ | Từ chối thiếu tiền mặt; huỷ link PayOS chưa trả trước khi chuyển sang tiền mặt; nếu chuyển khoản đã thành công trả 409. Không có email thì in/hiện QR. |
| Hậu điều kiện | Kết quả thành công quan sát được khớp yêu cầu này; chuyển trạng thái được chỉ định được lưu. Từ chối không cấp quyền hoặc để thay đổi dở dang trái phép. |
| Ưu tiên | H |
| Tiêu chí nghiệm thu | **WEB-FR-POS-05-AC-01** — Với tiền điều kiện/kích hoạt, kiểm tra: Đổi từ chuyển khoản sang tiền mặt theo WEB-BR-22: link PayOS bị huỷ, payment PayOS `FAILED`; khách đã chuyển khoản thì 409. **WEB-FR-POS-05-AC-02** — Thử đầu vào sai/thiếu quyền/xung đột áp dụng và kiểm tra từ chối đã nêu, không đổi dữ liệu trái phép và không báo thành công sai. |
| Bằng chứng | [Cinema_BE/BookingService/BookingService/Controllers/PaymentController.cs](../Cinema_BE/BookingService/BookingService/Controllers/PaymentController.cs); [Cinema_Mobile/lib/features/staff/screens/staff_counter_checkout_screen.dart](../Cinema_Mobile/lib/features/staff/screens/staff_counter_checkout_screen.dart) |
| Quy tắc nghiệp vụ | WEB-BR-08, WEB-BR-15, WEB-BR-16, WEB-BR-22, WEB-BR-23, WEB-BR-27, WEB-BR-28, WEB-BR-29 |
| Ca sử dụng / màn / API | UC-WEB-10; WEB-SCR-CHECKOUT; WEB-API-086 |

### WEB-FR-POS-06 — Lưu email tại quầy

| Trường | Đặc tả |
| --- | --- |
| Tên | Lưu email tại quầy |
| Mô tả | Email khách cho ở quầy được lưu vào vé để các email huỷ / hoàn tiền sau đó cũng tới. |
| Tác nhân | Nhân viên/quản trị viên |
| Tiền điều kiện | Phiên quản lý đang hoạt động; suất OPEN chưa bắt đầu còn ghế. |
| Kích hoạt | Thực hiện “Lưu email tại quầy” hoặc sự kiện/tác vụ backend tương ứng. |
| Luồng chính | 1. Đọc đầu vào/tài nguyên hiện tại và phiên áp dụng. 2. Thực hiện thao tác này: Email khách cho ở quầy được lưu vào vé để các email huỷ / hoàn tiền sau đó cũng tới. 3. Trả/hiển thị kết quả chính thức và làm mới dữ liệu bị tác động sau thành công. |
| Luồng thay thế / ngoại lệ | Từ chối thiếu tiền mặt; huỷ link PayOS chưa trả trước khi chuyển sang tiền mặt; nếu chuyển khoản đã thành công trả 409. Không có email thì in/hiện QR. |
| Hậu điều kiện | Kết quả thành công quan sát được khớp yêu cầu này; chuyển trạng thái được chỉ định được lưu. Từ chối không cấp quyền hoặc để thay đổi dở dang trái phép. |
| Ưu tiên | M |
| Tiêu chí nghiệm thu | **WEB-FR-POS-06-AC-01** — Với tiền điều kiện/kích hoạt, kiểm tra: Email khách cho ở quầy được lưu vào vé để các email huỷ / hoàn tiền sau đó cũng tới. **WEB-FR-POS-06-AC-02** — Thử đầu vào sai/thiếu quyền/xung đột áp dụng và kiểm tra từ chối đã nêu, không đổi dữ liệu trái phép và không báo thành công sai. |
| Bằng chứng | [Cinema_BE/BookingService/BookingService/Controllers/BookingController.cs](../Cinema_BE/BookingService/BookingService/Controllers/BookingController.cs); [Cinema_BE/BookingService/BookingService/Controllers/PaymentController.cs](../Cinema_BE/BookingService/BookingService/Controllers/PaymentController.cs); [Cinema_Mobile/lib/features/staff/screens/staff_counter_checkout_screen.dart](../Cinema_Mobile/lib/features/staff/screens/staff_counter_checkout_screen.dart) |
| Quy tắc nghiệp vụ | WEB-BR-08, WEB-BR-15, WEB-BR-16, WEB-BR-22, WEB-BR-23, WEB-BR-27, WEB-BR-28, WEB-BR-29 |
| Ca sử dụng / màn / API | UC-WEB-10; WEB-SCR-CHECKOUT; WEB-API-055, WEB-API-086 |

### WEB-FR-POS-07 — In và cho vào

| Trường | Đặc tả |
| --- | --- |
| Tên | In và cho vào |
| Mô tả | Sau khi trả tiền: hiện QR vé; **Print ticket** (trên web, khổ giấy in hoá đơn 80 mm); **Check in now** khi suất bắt đầu trong 3 giờ; **Sell another ticket**. Không có email thì in vé hoặc để khách chụp QR. |
| Tác nhân | Nhân viên/quản trị viên |
| Tiền điều kiện | Phiên quản lý đang hoạt động; suất OPEN chưa bắt đầu còn ghế. |
| Kích hoạt | Thực hiện “In và cho vào” hoặc sự kiện/tác vụ backend tương ứng. |
| Luồng chính | 1. Đọc đầu vào/tài nguyên hiện tại và phiên áp dụng. 2. Thực hiện thao tác này: Sau khi trả tiền: hiện QR vé; **Print ticket** (trên web, khổ giấy in hoá đơn 80 mm); **Check in now** khi suất bắt đầu trong 3 giờ; **Sell another ticket**. Không có email thì in vé hoặc để khách chụp QR. 3. Trả/hiển thị kết quả chính thức và làm mới dữ liệu bị tác động sau thành công. |
| Luồng thay thế / ngoại lệ | Từ chối thiếu tiền mặt; huỷ link PayOS chưa trả trước khi chuyển sang tiền mặt; nếu chuyển khoản đã thành công trả 409. Không có email thì in/hiện QR. |
| Hậu điều kiện | Kết quả thành công quan sát được khớp yêu cầu này; chuyển trạng thái được chỉ định được lưu. Từ chối không cấp quyền hoặc để thay đổi dở dang trái phép. |
| Ưu tiên | H |
| Tiêu chí nghiệm thu | **WEB-FR-POS-07-AC-01** — Với tiền điều kiện/kích hoạt, kiểm tra: Sau khi trả tiền: hiện QR vé; **Print ticket** (trên web, khổ giấy in hoá đơn 80 mm); **Check in now** khi suất bắt đầu trong 3 giờ; **Sell another ticket**. Không có email thì in vé hoặc để khách chụp QR. **WEB-FR-POS-07-AC-02** — Thử đầu vào sai/thiếu quyền/xung đột áp dụng và kiểm tra từ chối đã nêu, không đổi dữ liệu trái phép và không báo thành công sai. |
| Bằng chứng | [Cinema_BE/BookingService/BookingService/Controllers/BookingController.cs](../Cinema_BE/BookingService/BookingService/Controllers/BookingController.cs); [Cinema_Mobile/lib/features/staff/screens/staff_counter_checkout_screen.dart](../Cinema_Mobile/lib/features/staff/screens/staff_counter_checkout_screen.dart) |
| Quy tắc nghiệp vụ | WEB-BR-08, WEB-BR-15, WEB-BR-16, WEB-BR-22, WEB-BR-23, WEB-BR-27, WEB-BR-28, WEB-BR-29 |
| Ca sử dụng / màn / API | UC-WEB-10; WEB-SCR-CHECKOUT; WEB-API-044, WEB-API-046 |

### WEB-FR-POS-08 — Mở lại vé đã trả

| Trường | Đặc tả |
| --- | --- |
| Tên | Mở lại vé đã trả |
| Mô tả | Vé đã trả có nút **Show ticket** ở chi tiết vé để in lại hoặc check-in. |
| Tác nhân | Nhân viên/quản trị viên |
| Tiền điều kiện | Phiên quản lý đang hoạt động; suất OPEN chưa bắt đầu còn ghế. |
| Kích hoạt | Thực hiện “Mở lại vé đã trả” hoặc sự kiện/tác vụ backend tương ứng. |
| Luồng chính | 1. Đọc đầu vào/tài nguyên hiện tại và phiên áp dụng. 2. Thực hiện thao tác này: Vé đã trả có nút **Show ticket** ở chi tiết vé để in lại hoặc check-in. 3. Trả/hiển thị kết quả chính thức và làm mới dữ liệu bị tác động sau thành công. |
| Luồng thay thế / ngoại lệ | Từ chối thiếu tiền mặt; huỷ link PayOS chưa trả trước khi chuyển sang tiền mặt; nếu chuyển khoản đã thành công trả 409. Không có email thì in/hiện QR. |
| Hậu điều kiện | Dữ liệu/trạng thái đủ quyền được trả/hiển thị; đọc không đổi trạng thái vé/thanh toán. Dấu đã đọc thông báo chỉ đổi bằng thao tác ghi riêng. |
| Ưu tiên | M |
| Tiêu chí nghiệm thu | **WEB-FR-POS-08-AC-01** — Với tiền điều kiện/kích hoạt, kiểm tra: Vé đã trả có nút **Show ticket** ở chi tiết vé để in lại hoặc check-in. **WEB-FR-POS-08-AC-02** — Thử đầu vào sai/thiếu quyền/xung đột áp dụng và kiểm tra từ chối đã nêu, không đổi dữ liệu trái phép và không báo thành công sai. |
| Bằng chứng | [Cinema_BE/BookingService/BookingService/Controllers/BookingController.cs](../Cinema_BE/BookingService/BookingService/Controllers/BookingController.cs); [Cinema_Mobile/lib/features/staff/screens/staff_counter_checkout_screen.dart](../Cinema_Mobile/lib/features/staff/screens/staff_counter_checkout_screen.dart); [Cinema_Mobile/lib/features/staff/screens/staff_record_screen.dart](../Cinema_Mobile/lib/features/staff/screens/staff_record_screen.dart) |
| Quy tắc nghiệp vụ | WEB-BR-08, WEB-BR-15, WEB-BR-16, WEB-BR-22, WEB-BR-23, WEB-BR-27, WEB-BR-28, WEB-BR-29 |
| Ca sử dụng / màn / API | UC-WEB-10; WEB-SCR-CHECKOUT, WEB-SCR-RECORD-BOOKINGS; WEB-API-046 |

### WEB-FR-CHK-01 — QR vé

| Trường | Đặc tả |
| --- | --- |
| Tên | QR vé |
| Mô tả | Vé đã thanh toán có mã QR chứa mã vé, hiện trong app khách, trong email xác nhận và trên vé in. |
| Tác nhân | Khách hàng |
| Tiền điều kiện | Nhân viên/quản trị viên đã đăng nhập; vé CONFIRMED, chưa dùng và trong khoảng 180 phút trước đến 120 phút sau giờ bắt đầu. |
| Kích hoạt | Thực hiện “QR vé” hoặc sự kiện/tác vụ backend tương ứng. |
| Luồng chính | 1. Đọc đầu vào/tài nguyên hiện tại và phiên áp dụng. 2. Thực hiện thao tác này: Vé đã thanh toán có mã QR chứa mã vé, hiện trong app khách, trong email xác nhận và trên vé in. 3. Trả/hiển thị kết quả chính thức và làm mới dữ liệu bị tác động sau thành công. |
| Luồng thay thế / ngoại lệ | Cho nhập tay khi camera không có/bị từ chối. Mã không tồn tại trả 404; vé chưa trả, đã huỷ, chờ hoàn tiền, ngoài khung giờ hoặc đã dùng trả 409. Lần check-in thứ hai đồng thời thất bại. Lỗi thông tin bổ sung không được che vé. |
| Hậu điều kiện | Dữ liệu/trạng thái đủ quyền được trả/hiển thị; đọc không đổi trạng thái vé/thanh toán. Dấu đã đọc thông báo chỉ đổi bằng thao tác ghi riêng. |
| Ưu tiên | H |
| Tiêu chí nghiệm thu | **WEB-FR-CHK-01-AC-01** — Với tiền điều kiện/kích hoạt, kiểm tra: Vé đã thanh toán có mã QR chứa mã vé, hiện trong app khách, trong email xác nhận và trên vé in. **WEB-FR-CHK-01-AC-02** — Thử đầu vào sai/thiếu quyền/xung đột áp dụng và kiểm tra từ chối đã nêu, không đổi dữ liệu trái phép và không báo thành công sai. |
| Bằng chứng | [Cinema_BE/BookingService/BookingService/Controllers/BookingController.cs](../Cinema_BE/BookingService/BookingService/Controllers/BookingController.cs); [Cinema_Mobile/lib/features/booking/screens/booking_detail_screen.dart](../Cinema_Mobile/lib/features/booking/screens/booking_detail_screen.dart); [Cinema_Mobile/lib/features/staff/screens/staff_counter_checkout_screen.dart](../Cinema_Mobile/lib/features/staff/screens/staff_counter_checkout_screen.dart); [Cinema_BE/BookingService/BookingService/Services/Implementations/BookingService.cs](../Cinema_BE/BookingService/BookingService/Services/Implementations/BookingService.cs); [Cinema_BE/BookingService/BookingService/Configuration/CheckInOptions.cs](../Cinema_BE/BookingService/BookingService/Configuration/CheckInOptions.cs) |
| Quy tắc nghiệp vụ | WEB-BR-21 |
| Ca sử dụng / màn / API | UC-WEB-11; WEB-SCR-TICKET, WEB-SCR-CHECKOUT; WEB-API-046 |

### WEB-FR-CHK-02 — Tra mã vé

| Trường | Đặc tả |
| --- | --- |
| Tên | Tra mã vé |
| Mô tả | Staff/Admin tra vé theo mã (không phân biệt hoa thường): phim, giờ, phòng, ghế, tổng tiền, trạng thái. |
| Tác nhân | Nhân viên/quản trị viên |
| Tiền điều kiện | Nhân viên/quản trị viên đã đăng nhập; vé CONFIRMED, chưa dùng và trong khoảng 180 phút trước đến 120 phút sau giờ bắt đầu. |
| Kích hoạt | Thực hiện “Tra mã vé” hoặc sự kiện/tác vụ backend tương ứng. |
| Luồng chính | 1. Đọc đầu vào/tài nguyên hiện tại và phiên áp dụng. 2. Thực hiện thao tác này: Staff/Admin tra vé theo mã (không phân biệt hoa thường): phim, giờ, phòng, ghế, tổng tiền, trạng thái. 3. Trả/hiển thị kết quả chính thức và làm mới dữ liệu bị tác động sau thành công. |
| Luồng thay thế / ngoại lệ | Cho nhập tay khi camera không có/bị từ chối. Mã không tồn tại trả 404; vé chưa trả, đã huỷ, chờ hoàn tiền, ngoài khung giờ hoặc đã dùng trả 409. Lần check-in thứ hai đồng thời thất bại. Lỗi thông tin bổ sung không được che vé. |
| Hậu điều kiện | Dữ liệu/trạng thái đủ quyền được trả/hiển thị; đọc không đổi trạng thái vé/thanh toán. Dấu đã đọc thông báo chỉ đổi bằng thao tác ghi riêng. |
| Ưu tiên | H |
| Tiêu chí nghiệm thu | **WEB-FR-CHK-02-AC-01** — Với tiền điều kiện/kích hoạt, kiểm tra: Staff/Admin tra vé theo mã (không phân biệt hoa thường): phim, giờ, phòng, ghế, tổng tiền, trạng thái. **WEB-FR-CHK-02-AC-02** — Thử đầu vào sai/thiếu quyền/xung đột áp dụng và kiểm tra từ chối đã nêu, không đổi dữ liệu trái phép và không báo thành công sai. |
| Bằng chứng | [Cinema_BE/BookingService/BookingService/Controllers/BookingController.cs](../Cinema_BE/BookingService/BookingService/Controllers/BookingController.cs); [Cinema_Mobile/lib/features/staff/screens/staff_check_in_screen.dart](../Cinema_Mobile/lib/features/staff/screens/staff_check_in_screen.dart); [Cinema_BE/BookingService/BookingService/Services/Implementations/BookingService.cs](../Cinema_BE/BookingService/BookingService/Services/Implementations/BookingService.cs); [Cinema_BE/BookingService/BookingService/Configuration/CheckInOptions.cs](../Cinema_BE/BookingService/BookingService/Configuration/CheckInOptions.cs) |
| Quy tắc nghiệp vụ | WEB-BR-21 |
| Ca sử dụng / màn / API | UC-WEB-11; WEB-SCR-CHECKIN; WEB-API-047 |

### WEB-FR-CHK-03 — Kiểm tra check-in

| Trường | Đặc tả |
| --- | --- |
| Tên | Kiểm tra check-in |
| Mô tả | Check-in theo WEB-BR-21; không hợp lệ thì 409 kèm lý do (chưa thanh toán, đã huỷ, chờ hoàn tiền, chưa tới giờ, quá giờ, đã check-in lúc mấy giờ). Hai quầy quét cùng lúc thì quầy sau nhận 409. |
| Tác nhân | Nhân viên/quản trị viên |
| Tiền điều kiện | Nhân viên/quản trị viên đã đăng nhập; vé CONFIRMED, chưa dùng và trong khoảng 180 phút trước đến 120 phút sau giờ bắt đầu. |
| Kích hoạt | Thực hiện “Kiểm tra check-in” hoặc sự kiện/tác vụ backend tương ứng. |
| Luồng chính | 1. Đọc đầu vào/tài nguyên hiện tại và phiên áp dụng. 2. Thực hiện thao tác này: Check-in theo WEB-BR-21; không hợp lệ thì 409 kèm lý do (chưa thanh toán, đã huỷ, chờ hoàn tiền, chưa tới giờ, quá giờ, đã check-in lúc mấy giờ). Hai quầy quét cùng lúc thì quầy sau nhận 409. 3. Trả/hiển thị kết quả chính thức và làm mới dữ liệu bị tác động sau thành công. |
| Luồng thay thế / ngoại lệ | Cho nhập tay khi camera không có/bị từ chối. Mã không tồn tại trả 404; vé chưa trả, đã huỷ, chờ hoàn tiền, ngoài khung giờ hoặc đã dùng trả 409. Lần check-in thứ hai đồng thời thất bại. Lỗi thông tin bổ sung không được che vé. |
| Hậu điều kiện | Chỉ lưu một thời điểm check-in; check-in là thuộc tính, không phải trạng thái vé khác. |
| Ưu tiên | H |
| Tiêu chí nghiệm thu | **WEB-FR-CHK-03-AC-01** — Với tiền điều kiện/kích hoạt, kiểm tra: Check-in theo WEB-BR-21; không hợp lệ thì 409 kèm lý do (chưa thanh toán, đã huỷ, chờ hoàn tiền, chưa tới giờ, quá giờ, đã check-in lúc mấy giờ). Hai quầy quét cùng lúc thì quầy sau nhận 409. **WEB-FR-CHK-03-AC-02** — Thử đầu vào sai/thiếu quyền/xung đột áp dụng và kiểm tra từ chối đã nêu, không đổi dữ liệu trái phép và không báo thành công sai. |
| Bằng chứng | [Cinema_BE/BookingService/BookingService/Controllers/BookingController.cs](../Cinema_BE/BookingService/BookingService/Controllers/BookingController.cs); [Cinema_Mobile/lib/features/staff/screens/staff_check_in_screen.dart](../Cinema_Mobile/lib/features/staff/screens/staff_check_in_screen.dart); [Cinema_Mobile/lib/features/staff/screens/staff_counter_checkout_screen.dart](../Cinema_Mobile/lib/features/staff/screens/staff_counter_checkout_screen.dart); [Cinema_BE/BookingService/BookingService/Services/Implementations/BookingService.cs](../Cinema_BE/BookingService/BookingService/Services/Implementations/BookingService.cs); [Cinema_BE/BookingService/BookingService/Configuration/CheckInOptions.cs](../Cinema_BE/BookingService/BookingService/Configuration/CheckInOptions.cs) |
| Quy tắc nghiệp vụ | WEB-BR-21 |
| Ca sử dụng / màn / API | UC-WEB-11; WEB-SCR-CHECKIN, WEB-SCR-CHECKOUT; WEB-API-044 |

### WEB-FR-CHK-04 — Camera/nhập mã

| Trường | Đặc tả |
| --- | --- |
| Tên | Camera/nhập mã |
| Mô tả | Quét QR bằng camera điện thoại (app), webcam laptop / camera USB (trang quản trị), hoặc gõ mã / máy quét cầm tay (gõ mã rồi Enter). |
| Tác nhân | Nhân viên/quản trị viên |
| Tiền điều kiện | Nhân viên/quản trị viên đã đăng nhập; vé CONFIRMED, chưa dùng và trong khoảng 180 phút trước đến 120 phút sau giờ bắt đầu. |
| Kích hoạt | Thực hiện “Camera/nhập mã” hoặc sự kiện/tác vụ backend tương ứng. |
| Luồng chính | 1. Đọc đầu vào/tài nguyên hiện tại và phiên áp dụng. 2. Thực hiện thao tác này: Quét QR bằng camera điện thoại (app), webcam laptop / camera USB (trang quản trị), hoặc gõ mã / máy quét cầm tay (gõ mã rồi Enter). 3. Trả/hiển thị kết quả chính thức và làm mới dữ liệu bị tác động sau thành công. |
| Luồng thay thế / ngoại lệ | Cho nhập tay khi camera không có/bị từ chối. Mã không tồn tại trả 404; vé chưa trả, đã huỷ, chờ hoàn tiền, ngoài khung giờ hoặc đã dùng trả 409. Lần check-in thứ hai đồng thời thất bại. Lỗi thông tin bổ sung không được che vé. |
| Hậu điều kiện | Chỉ lưu một thời điểm check-in; check-in là thuộc tính, không phải trạng thái vé khác. |
| Ưu tiên | H |
| Tiêu chí nghiệm thu | **WEB-FR-CHK-04-AC-01** — Với tiền điều kiện/kích hoạt, kiểm tra: Quét QR bằng camera điện thoại (app), webcam laptop / camera USB (trang quản trị), hoặc gõ mã / máy quét cầm tay (gõ mã rồi Enter). **WEB-FR-CHK-04-AC-02** — Thử đầu vào sai/thiếu quyền/xung đột áp dụng và kiểm tra từ chối đã nêu, không đổi dữ liệu trái phép và không báo thành công sai. |
| Bằng chứng | [Cinema_BE/BookingService/BookingService/Controllers/BookingController.cs](../Cinema_BE/BookingService/BookingService/Controllers/BookingController.cs); [Cinema_Mobile/lib/features/staff/screens/staff_check_in_screen.dart](../Cinema_Mobile/lib/features/staff/screens/staff_check_in_screen.dart); [Cinema_BE/BookingService/BookingService/Services/Implementations/BookingService.cs](../Cinema_BE/BookingService/BookingService/Services/Implementations/BookingService.cs); [Cinema_BE/BookingService/BookingService/Configuration/CheckInOptions.cs](../Cinema_BE/BookingService/BookingService/Configuration/CheckInOptions.cs) |
| Quy tắc nghiệp vụ | WEB-BR-21 |
| Ca sử dụng / màn / API | UC-WEB-11; WEB-SCR-CHECKIN; WEB-API-044, WEB-API-047 |

### WEB-FR-CHK-05 — Hiện giờ check-in

| Trường | Đặc tả |
| --- | --- |
| Tên | Hiện giờ check-in |
| Mô tả | Giờ check-in hiện trên vé của khách, chi tiết vé, sơ đồ ghế và danh sách khách của suất chiếu. |
| Tác nhân | Nhân viên/quản trị viên |
| Tiền điều kiện | Nhân viên/quản trị viên đã đăng nhập; vé CONFIRMED, chưa dùng và trong khoảng 180 phút trước đến 120 phút sau giờ bắt đầu. |
| Kích hoạt | Thực hiện “Hiện giờ check-in” hoặc sự kiện/tác vụ backend tương ứng. |
| Luồng chính | 1. Đọc đầu vào/tài nguyên hiện tại và phiên áp dụng. 2. Thực hiện thao tác này: Giờ check-in hiện trên vé của khách, chi tiết vé, sơ đồ ghế và danh sách khách của suất chiếu. 3. Trả/hiển thị kết quả chính thức và làm mới dữ liệu bị tác động sau thành công. |
| Luồng thay thế / ngoại lệ | Cho nhập tay khi camera không có/bị từ chối. Mã không tồn tại trả 404; vé chưa trả, đã huỷ, chờ hoàn tiền, ngoài khung giờ hoặc đã dùng trả 409. Lần check-in thứ hai đồng thời thất bại. Lỗi thông tin bổ sung không được che vé. |
| Hậu điều kiện | Dữ liệu/trạng thái đủ quyền được trả/hiển thị; đọc không đổi trạng thái vé/thanh toán. Dấu đã đọc thông báo chỉ đổi bằng thao tác ghi riêng. |
| Ưu tiên | M |
| Tiêu chí nghiệm thu | **WEB-FR-CHK-05-AC-01** — Với tiền điều kiện/kích hoạt, kiểm tra: Giờ check-in hiện trên vé của khách, chi tiết vé, sơ đồ ghế và danh sách khách của suất chiếu. **WEB-FR-CHK-05-AC-02** — Thử đầu vào sai/thiếu quyền/xung đột áp dụng và kiểm tra từ chối đã nêu, không đổi dữ liệu trái phép và không báo thành công sai. |
| Bằng chứng | [Cinema_BE/BookingService/BookingService/Controllers/BookingController.cs](../Cinema_BE/BookingService/BookingService/Controllers/BookingController.cs); [Cinema_Mobile/lib/features/booking/screens/booking_detail_screen.dart](../Cinema_Mobile/lib/features/booking/screens/booking_detail_screen.dart); [Cinema_Mobile/lib/features/staff/screens/staff_check_in_screen.dart](../Cinema_Mobile/lib/features/staff/screens/staff_check_in_screen.dart); [Cinema_Mobile/lib/features/staff/screens/staff_record_screen.dart](../Cinema_Mobile/lib/features/staff/screens/staff_record_screen.dart); [Cinema_BE/BookingService/BookingService/Services/Implementations/BookingService.cs](../Cinema_BE/BookingService/BookingService/Services/Implementations/BookingService.cs); [Cinema_BE/BookingService/BookingService/Configuration/CheckInOptions.cs](../Cinema_BE/BookingService/BookingService/Configuration/CheckInOptions.cs) |
| Quy tắc nghiệp vụ | WEB-BR-21 |
| Ca sử dụng / màn / API | UC-WEB-11; WEB-SCR-TICKET, WEB-SCR-CHECKIN, WEB-SCR-RECORD-BOOKINGS; WEB-API-046, WEB-API-050 |

### WEB-FR-NOTI-01 — Lịch sử thông báo

| Trường | Đặc tả |
| --- | --- |
| Tên | Lịch sử thông báo |
| Mô tả | Khách xem danh sách và chi tiết thông báo của mình, mở vé liên quan. Admin xem tất cả. |
| Tác nhân | Khách hàng xem của mình; nhân viên/quản trị viên gửi thông báo được phép; hệ thống gửi theo sự kiện |
| Tiền điều kiện | Có phiên tài khoản để xem lịch sử trong ứng dụng; cấu hình SMTP/xử lý sự kiện để gửi thật. |
| Kích hoạt | Thực hiện “Lịch sử thông báo” hoặc sự kiện/tác vụ backend tương ứng. |
| Luồng chính | 1. Đọc đầu vào/tài nguyên hiện tại và phiên áp dụng. 2. Thực hiện thao tác này: Khách xem danh sách và chi tiết thông báo của mình, mở vé liên quan. Admin xem tất cả. 3. Trả/hiển thị kết quả chính thức và làm mới dữ liệu bị tác động sau thành công. |
| Luồng thay thế / ngoại lệ | Kiểm tra chủ sở hữu từ chối dữ liệu người khác; có trạng thái tải/rỗng/lỗi-thử lại. Gửi lỗi giữ FAILED để thử lại và không hoàn tác thanh toán. Chống lặp sự kiện giảm gửi trùng nhưng SMTP cùng commit database không bảo đảm giao dịch đúng một lần tuyệt đối. |
| Hậu điều kiện | Dữ liệu/trạng thái đủ quyền được trả/hiển thị; đọc không đổi trạng thái vé/thanh toán. Dấu đã đọc thông báo chỉ đổi bằng thao tác ghi riêng. |
| Ưu tiên | M |
| Tiêu chí nghiệm thu | **WEB-FR-NOTI-01-AC-01** — Với tiền điều kiện/kích hoạt, kiểm tra: Khách xem danh sách và chi tiết thông báo của mình, mở vé liên quan. Admin xem tất cả. **WEB-FR-NOTI-01-AC-02** — Thử đầu vào sai/thiếu quyền/xung đột áp dụng và kiểm tra từ chối đã nêu, không đổi dữ liệu trái phép và không báo thành công sai. |
| Bằng chứng | [Cinema_BE/BookingService/BookingService/Controllers/NotificationController.cs](../Cinema_BE/BookingService/BookingService/Controllers/NotificationController.cs); [Cinema_Mobile/lib/features/notification/screens/notification_list_screen.dart](../Cinema_Mobile/lib/features/notification/screens/notification_list_screen.dart); [Cinema_BE/BookingService/BookingService/Services/Implementations/NotificationService.cs](../Cinema_BE/BookingService/BookingService/Services/Implementations/NotificationService.cs); [Cinema_BE/BookingService/BookingService/Workers/ShowtimeReminderWorker.cs](../Cinema_BE/BookingService/BookingService/Workers/ShowtimeReminderWorker.cs) |
| Quy tắc nghiệp vụ | WEB-BR-11, WEB-BR-13 |
| Ca sử dụng / màn / API | UC-WEB-12; WEB-SCR-NOTIFICATIONS; WEB-API-078, WEB-API-079 |

### WEB-FR-NOTI-02 — Soạn tin cho vé

| Trường | Đặc tả |
| --- | --- |
| Tên | Soạn tin cho vé |
| Mô tả | Staff/Admin soạn thông báo email cho khách của một vé (kể cả khách vãng lai có email). |
| Tác nhân | Nhân viên/quản trị viên |
| Tiền điều kiện | Có phiên tài khoản để xem lịch sử trong ứng dụng; cấu hình SMTP/xử lý sự kiện để gửi thật. |
| Kích hoạt | Thực hiện “Soạn tin cho vé” hoặc sự kiện/tác vụ backend tương ứng. |
| Luồng chính | 1. Đọc đầu vào/tài nguyên hiện tại và phiên áp dụng. 2. Thực hiện thao tác này: Staff/Admin soạn thông báo email cho khách của một vé (kể cả khách vãng lai có email). 3. Trả/hiển thị kết quả chính thức và làm mới dữ liệu bị tác động sau thành công. |
| Luồng thay thế / ngoại lệ | Kiểm tra chủ sở hữu từ chối dữ liệu người khác; có trạng thái tải/rỗng/lỗi-thử lại. Gửi lỗi giữ FAILED để thử lại và không hoàn tác thanh toán. Chống lặp sự kiện giảm gửi trùng nhưng SMTP cùng commit database không bảo đảm giao dịch đúng một lần tuyệt đối. |
| Hậu điều kiện | Kết quả thành công quan sát được khớp yêu cầu này; chuyển trạng thái được chỉ định được lưu. Từ chối không cấp quyền hoặc để thay đổi dở dang trái phép. |
| Ưu tiên | M |
| Tiêu chí nghiệm thu | **WEB-FR-NOTI-02-AC-01** — Với tiền điều kiện/kích hoạt, kiểm tra: Staff/Admin soạn thông báo email cho khách của một vé (kể cả khách vãng lai có email). **WEB-FR-NOTI-02-AC-02** — Thử đầu vào sai/thiếu quyền/xung đột áp dụng và kiểm tra từ chối đã nêu, không đổi dữ liệu trái phép và không báo thành công sai. |
| Bằng chứng | [Cinema_BE/BookingService/BookingService/Controllers/NotificationController.cs](../Cinema_BE/BookingService/BookingService/Controllers/NotificationController.cs); [Cinema_Mobile/lib/features/staff/screens/staff_notification_screen.dart](../Cinema_Mobile/lib/features/staff/screens/staff_notification_screen.dart); [Cinema_BE/BookingService/BookingService/Services/Implementations/NotificationService.cs](../Cinema_BE/BookingService/BookingService/Services/Implementations/NotificationService.cs); [Cinema_BE/BookingService/BookingService/Workers/ShowtimeReminderWorker.cs](../Cinema_BE/BookingService/BookingService/Workers/ShowtimeReminderWorker.cs) |
| Quy tắc nghiệp vụ | WEB-BR-11, WEB-BR-13 |
| Ca sử dụng / màn / API | UC-WEB-12; WEB-SCR-COMPOSE; WEB-API-080 |

### WEB-FR-NOTI-03 — Gửi/thử lại tin

| Trường | Đặc tả |
| --- | --- |
| Tên | Gửi/thử lại tin |
| Mô tả | Gửi thông báo; gửi lỗi thì lưu `FAILED` kèm lỗi và cho gửi lại cùng thông báo. |
| Tác nhân | Nhân viên/quản trị viên |
| Tiền điều kiện | Có phiên tài khoản để xem lịch sử trong ứng dụng; cấu hình SMTP/xử lý sự kiện để gửi thật. |
| Kích hoạt | Thực hiện “Gửi/thử lại tin” hoặc sự kiện/tác vụ backend tương ứng. |
| Luồng chính | 1. Đọc đầu vào/tài nguyên hiện tại và phiên áp dụng. 2. Thực hiện thao tác này: Gửi thông báo; gửi lỗi thì lưu `FAILED` kèm lỗi và cho gửi lại cùng thông báo. 3. Trả/hiển thị kết quả chính thức và làm mới dữ liệu bị tác động sau thành công. |
| Luồng thay thế / ngoại lệ | Kiểm tra chủ sở hữu từ chối dữ liệu người khác; có trạng thái tải/rỗng/lỗi-thử lại. Gửi lỗi giữ FAILED để thử lại và không hoàn tác thanh toán. Chống lặp sự kiện giảm gửi trùng nhưng SMTP cùng commit database không bảo đảm giao dịch đúng một lần tuyệt đối. |
| Hậu điều kiện | Kết quả thành công quan sát được khớp yêu cầu này; chuyển trạng thái được chỉ định được lưu. Từ chối không cấp quyền hoặc để thay đổi dở dang trái phép. |
| Ưu tiên | M |
| Tiêu chí nghiệm thu | **WEB-FR-NOTI-03-AC-01** — Với tiền điều kiện/kích hoạt, kiểm tra: Gửi thông báo; gửi lỗi thì lưu `FAILED` kèm lỗi và cho gửi lại cùng thông báo. **WEB-FR-NOTI-03-AC-02** — Thử đầu vào sai/thiếu quyền/xung đột áp dụng và kiểm tra từ chối đã nêu, không đổi dữ liệu trái phép và không báo thành công sai. |
| Bằng chứng | [Cinema_BE/BookingService/BookingService/Controllers/NotificationController.cs](../Cinema_BE/BookingService/BookingService/Controllers/NotificationController.cs); [Cinema_Mobile/lib/features/staff/screens/staff_notification_screen.dart](../Cinema_Mobile/lib/features/staff/screens/staff_notification_screen.dart); [Cinema_BE/BookingService/BookingService/Services/Implementations/NotificationService.cs](../Cinema_BE/BookingService/BookingService/Services/Implementations/NotificationService.cs); [Cinema_BE/BookingService/BookingService/Workers/ShowtimeReminderWorker.cs](../Cinema_BE/BookingService/BookingService/Workers/ShowtimeReminderWorker.cs) |
| Quy tắc nghiệp vụ | WEB-BR-11, WEB-BR-13 |
| Ca sử dụng / màn / API | UC-WEB-12; WEB-SCR-COMPOSE; WEB-API-073 |

### WEB-FR-NOTI-04 — Chi tiết thông báo

| Trường | Đặc tả |
| --- | --- |
| Tên | Chi tiết thông báo |
| Mô tả | Xem chi tiết thông báo. |
| Tác nhân | Khách hàng xem của mình; nhân viên/quản trị viên gửi thông báo được phép; hệ thống gửi theo sự kiện |
| Tiền điều kiện | Có phiên tài khoản để xem lịch sử trong ứng dụng; cấu hình SMTP/xử lý sự kiện để gửi thật. |
| Kích hoạt | Thực hiện “Chi tiết thông báo” hoặc sự kiện/tác vụ backend tương ứng. |
| Luồng chính | 1. Đọc đầu vào/tài nguyên hiện tại và phiên áp dụng. 2. Thực hiện thao tác này: Xem chi tiết thông báo. 3. Trả/hiển thị kết quả chính thức và làm mới dữ liệu bị tác động sau thành công. |
| Luồng thay thế / ngoại lệ | Kiểm tra chủ sở hữu từ chối dữ liệu người khác; có trạng thái tải/rỗng/lỗi-thử lại. Gửi lỗi giữ FAILED để thử lại và không hoàn tác thanh toán. Chống lặp sự kiện giảm gửi trùng nhưng SMTP cùng commit database không bảo đảm giao dịch đúng một lần tuyệt đối. |
| Hậu điều kiện | Dữ liệu/trạng thái đủ quyền được trả/hiển thị; đọc không đổi trạng thái vé/thanh toán. Dấu đã đọc thông báo chỉ đổi bằng thao tác ghi riêng. |
| Ưu tiên | M |
| Tiêu chí nghiệm thu | **WEB-FR-NOTI-04-AC-01** — Với tiền điều kiện/kích hoạt, kiểm tra: Xem chi tiết thông báo. **WEB-FR-NOTI-04-AC-02** — Thử đầu vào sai/thiếu quyền/xung đột áp dụng và kiểm tra từ chối đã nêu, không đổi dữ liệu trái phép và không báo thành công sai. |
| Bằng chứng | [Cinema_BE/BookingService/BookingService/Controllers/NotificationController.cs](../Cinema_BE/BookingService/BookingService/Controllers/NotificationController.cs); [Cinema_Mobile/lib/features/notification/screens/notification_detail_screen.dart](../Cinema_Mobile/lib/features/notification/screens/notification_detail_screen.dart); [Cinema_BE/BookingService/BookingService/Services/Implementations/NotificationService.cs](../Cinema_BE/BookingService/BookingService/Services/Implementations/NotificationService.cs); [Cinema_BE/BookingService/BookingService/Workers/ShowtimeReminderWorker.cs](../Cinema_BE/BookingService/BookingService/Workers/ShowtimeReminderWorker.cs) |
| Quy tắc nghiệp vụ | WEB-BR-11, WEB-BR-13 |
| Ca sử dụng / màn / API | UC-WEB-12; WEB-SCR-NOTIFICATION; WEB-API-075 |

### WEB-FR-NOTI-05 — API xoá thông báo

| Trường | Đặc tả |
| --- | --- |
| Tên | API xoá thông báo |
| Mô tả | Xoá thông báo: người nhận xoá của mình, Admin xoá mọi thông báo (qua API). |
| Tác nhân | Khách hàng xem của mình; nhân viên/quản trị viên gửi thông báo được phép; hệ thống gửi theo sự kiện |
| Tiền điều kiện | Có phiên tài khoản để xem lịch sử trong ứng dụng; cấu hình SMTP/xử lý sự kiện để gửi thật. |
| Kích hoạt | Thực hiện “API xoá thông báo” hoặc sự kiện/tác vụ backend tương ứng. |
| Luồng chính | 1. Đọc đầu vào/tài nguyên hiện tại và phiên áp dụng. 2. Thực hiện thao tác này: Xoá thông báo: người nhận xoá của mình, Admin xoá mọi thông báo (qua API). 3. Trả/hiển thị kết quả chính thức và làm mới dữ liệu bị tác động sau thành công. |
| Luồng thay thế / ngoại lệ | Kiểm tra chủ sở hữu từ chối dữ liệu người khác; có trạng thái tải/rỗng/lỗi-thử lại. Gửi lỗi giữ FAILED để thử lại và không hoàn tác thanh toán. Chống lặp sự kiện giảm gửi trùng nhưng SMTP cùng commit database không bảo đảm giao dịch đúng một lần tuyệt đối. |
| Hậu điều kiện | Kết quả thành công quan sát được khớp yêu cầu này; chuyển trạng thái được chỉ định được lưu. Từ chối không cấp quyền hoặc để thay đổi dở dang trái phép. |
| Ưu tiên | L |
| Tiêu chí nghiệm thu | **WEB-FR-NOTI-05-AC-01** — Với tiền điều kiện/kích hoạt, kiểm tra: Xoá thông báo: người nhận xoá của mình, Admin xoá mọi thông báo (qua API). **WEB-FR-NOTI-05-AC-02** — Thử đầu vào sai/thiếu quyền/xung đột áp dụng và kiểm tra từ chối đã nêu, không đổi dữ liệu trái phép và không báo thành công sai. |
| Bằng chứng | [Cinema_BE/BookingService/BookingService/Controllers/NotificationController.cs](../Cinema_BE/BookingService/BookingService/Controllers/NotificationController.cs); [Cinema_BE/BookingService/BookingService/Services/Implementations/NotificationService.cs](../Cinema_BE/BookingService/BookingService/Services/Implementations/NotificationService.cs); [Cinema_BE/BookingService/BookingService/Workers/ShowtimeReminderWorker.cs](../Cinema_BE/BookingService/BookingService/Workers/ShowtimeReminderWorker.cs) |
| Quy tắc nghiệp vụ | WEB-BR-11, WEB-BR-13 |
| Ca sử dụng / màn / API | UC-WEB-12; ; WEB-API-074 |

### WEB-FR-NOTI-06 — Email sự kiện

| Trường | Đặc tả |
| --- | --- |
| Tên | Email sự kiện |
| Mô tả | Nhận sự kiện vé/thanh toán đã commit để gửi email xác nhận kèm QR nhúng, huỷ, hết hạn và hoàn tiền. Chống lặp theo ID sự kiện và bỏ qua vé không có email. Có thể thử gửi lại; SMTP và commit database không bảo đảm gửi đúng một lần tuyệt đối khi xảy ra sự cố. |
| Tác nhân | Hệ thống backend chung; khách nhận kết quả |
| Tiền điều kiện | Có sự kiện đã commit, kết quả PayOS tin cậy hoặc điều kiện tác vụ tương ứng; backend đã cấu hình xử lý. Tác vụ nền hoặc webhook chữ ký không cần phiên khách. |
| Kích hoạt | Thực hiện “Email sự kiện” hoặc sự kiện/tác vụ backend tương ứng. |
| Luồng chính | 1. Đọc đầu vào/tài nguyên hiện tại và phiên áp dụng. 2. Thực hiện thao tác này: Nhận sự kiện vé/thanh toán đã commit để gửi email xác nhận kèm QR nhúng, huỷ, hết hạn và hoàn tiền. Chống lặp theo ID sự kiện và bỏ qua vé không có email. Có thể thử gửi lại; SMTP và commit database không bảo đảm gửi đúng một lần tuyệt đối khi xảy ra sự cố. 3. Trả/hiển thị kết quả chính thức và làm mới dữ liệu bị tác động sau thành công. |
| Luồng thay thế / ngoại lệ | Kiểm tra chủ sở hữu từ chối dữ liệu người khác; có trạng thái tải/rỗng/lỗi-thử lại. Gửi lỗi giữ FAILED để thử lại và không hoàn tác thanh toán. Chống lặp sự kiện giảm gửi trùng nhưng SMTP cùng commit database không bảo đảm giao dịch đúng một lần tuyệt đối. |
| Hậu điều kiện | Dữ liệu/trạng thái đủ quyền được trả/hiển thị; đọc không đổi trạng thái vé/thanh toán. Dấu đã đọc thông báo chỉ đổi bằng thao tác ghi riêng. |
| Ưu tiên | H |
| Tiêu chí nghiệm thu | **WEB-FR-NOTI-06-AC-01** — Với tiền điều kiện/kích hoạt, kiểm tra: Nhận sự kiện vé/thanh toán đã commit để gửi email xác nhận kèm QR nhúng, huỷ, hết hạn và hoàn tiền. Chống lặp theo ID sự kiện và bỏ qua vé không có email. Có thể thử gửi lại; SMTP và commit database không bảo đảm gửi đúng một lần tuyệt đối khi xảy ra sự cố. **WEB-FR-NOTI-06-AC-02** — Thử đầu vào sai/thiếu quyền/xung đột áp dụng và kiểm tra từ chối đã nêu, không đổi dữ liệu trái phép và không báo thành công sai. |
| Bằng chứng | [Cinema_BE/BookingService/BookingService/Controllers/NotificationController.cs](../Cinema_BE/BookingService/BookingService/Controllers/NotificationController.cs); [Cinema_BE/BookingService/BookingService/Services/Implementations/NotificationService.cs](../Cinema_BE/BookingService/BookingService/Services/Implementations/NotificationService.cs); [Cinema_BE/BookingService/BookingService/Workers/ShowtimeReminderWorker.cs](../Cinema_BE/BookingService/BookingService/Workers/ShowtimeReminderWorker.cs) |
| Quy tắc nghiệp vụ | WEB-BR-11, WEB-BR-13 |
| Ca sử dụng / màn / API | UC-WEB-12; ; WEB-API-078 |

### WEB-FR-NOTI-07 — Email OTP và chào mừng

| Trường | Đặc tả |
| --- | --- |
| Tên | Email OTP và chào mừng |
| Mô tả | AuthService gửi email OTP (xác thực, đặt lại mật khẩu) và email chào mừng. |
| Tác nhân | Hệ thống backend chung; khách nhận kết quả |
| Tiền điều kiện | Có sự kiện đã commit, kết quả PayOS tin cậy hoặc điều kiện tác vụ tương ứng; backend đã cấu hình xử lý. Tác vụ nền hoặc webhook chữ ký không cần phiên khách. |
| Kích hoạt | Thực hiện “Email OTP và chào mừng” hoặc sự kiện/tác vụ backend tương ứng. |
| Luồng chính | 1. Đọc đầu vào/tài nguyên hiện tại và phiên áp dụng. 2. Thực hiện thao tác này: AuthService gửi email OTP (xác thực, đặt lại mật khẩu) và email chào mừng. 3. Trả/hiển thị kết quả chính thức và làm mới dữ liệu bị tác động sau thành công. |
| Luồng thay thế / ngoại lệ | Kiểm tra chủ sở hữu từ chối dữ liệu người khác; có trạng thái tải/rỗng/lỗi-thử lại. Gửi lỗi giữ FAILED để thử lại và không hoàn tác thanh toán. Chống lặp sự kiện giảm gửi trùng nhưng SMTP cùng commit database không bảo đảm giao dịch đúng một lần tuyệt đối. |
| Hậu điều kiện | Kết quả thành công quan sát được khớp yêu cầu này; chuyển trạng thái được chỉ định được lưu. Từ chối không cấp quyền hoặc để thay đổi dở dang trái phép. |
| Ưu tiên | H |
| Tiêu chí nghiệm thu | **WEB-FR-NOTI-07-AC-01** — Với tiền điều kiện/kích hoạt, kiểm tra: AuthService gửi email OTP (xác thực, đặt lại mật khẩu) và email chào mừng. **WEB-FR-NOTI-07-AC-02** — Thử đầu vào sai/thiếu quyền/xung đột áp dụng và kiểm tra từ chối đã nêu, không đổi dữ liệu trái phép và không báo thành công sai. |
| Bằng chứng | [Cinema_BE/AuthService/AuthService/Controllers/AuthController.cs](../Cinema_BE/AuthService/AuthService/Controllers/AuthController.cs); [Cinema_BE/BookingService/BookingService/Services/Implementations/NotificationService.cs](../Cinema_BE/BookingService/BookingService/Services/Implementations/NotificationService.cs); [Cinema_BE/BookingService/BookingService/Workers/ShowtimeReminderWorker.cs](../Cinema_BE/BookingService/BookingService/Workers/ShowtimeReminderWorker.cs) |
| Quy tắc nghiệp vụ | WEB-BR-11, WEB-BR-13 |
| Ca sử dụng / màn / API | UC-WEB-12; ; WEB-API-026, WEB-API-033, WEB-API-042 |

### WEB-FR-NOTI-08 — Nhắc giờ chiếu

| Trường | Đặc tả |
| --- | --- |
| Tên | Nhắc giờ chiếu |
| Mô tả | **Nhắc giờ chiếu**: job nền (mỗi phút, cấu hình `ShowtimeReminder`) gửi email và ghi vào lịch sử thông báo cho vé đã thanh toán, chưa check-in, có giờ chiếu trong 2 giờ tới; mỗi vé nhắc một lần. Vé đặt khi đã vào khoảng nhắc thì bỏ qua (khách vừa nhận email xác nhận). |
| Tác nhân | Hệ thống backend chung; khách nhận kết quả |
| Tiền điều kiện | Có sự kiện đã commit, kết quả PayOS tin cậy hoặc điều kiện tác vụ tương ứng; backend đã cấu hình xử lý. Tác vụ nền hoặc webhook chữ ký không cần phiên khách. |
| Kích hoạt | Thực hiện “Nhắc giờ chiếu” hoặc sự kiện/tác vụ backend tương ứng. |
| Luồng chính | 1. Đọc đầu vào/tài nguyên hiện tại và phiên áp dụng. 2. Thực hiện thao tác này: **Nhắc giờ chiếu**: job nền (mỗi phút, cấu hình `ShowtimeReminder`) gửi email và ghi vào lịch sử thông báo cho vé đã thanh toán, chưa check-in, có giờ chiếu trong 2 giờ tới; mỗi vé nhắc một lần. Vé đặt khi đã vào khoảng nhắc thì bỏ qua (khách vừa nhận email xác nhận). 3. Trả/hiển thị kết quả chính thức và làm mới dữ liệu bị tác động sau thành công. |
| Luồng thay thế / ngoại lệ | Kiểm tra chủ sở hữu từ chối dữ liệu người khác; có trạng thái tải/rỗng/lỗi-thử lại. Gửi lỗi giữ FAILED để thử lại và không hoàn tác thanh toán. Chống lặp sự kiện giảm gửi trùng nhưng SMTP cùng commit database không bảo đảm giao dịch đúng một lần tuyệt đối. |
| Hậu điều kiện | Dữ liệu/trạng thái đủ quyền được trả/hiển thị; đọc không đổi trạng thái vé/thanh toán. Dấu đã đọc thông báo chỉ đổi bằng thao tác ghi riêng. |
| Ưu tiên | M |
| Tiêu chí nghiệm thu | **WEB-FR-NOTI-08-AC-01** — Với tiền điều kiện/kích hoạt, kiểm tra: **Nhắc giờ chiếu**: job nền (mỗi phút, cấu hình `ShowtimeReminder`) gửi email và ghi vào lịch sử thông báo cho vé đã thanh toán, chưa check-in, có giờ chiếu trong 2 giờ tới; mỗi vé nhắc một lần. Vé đặt khi đã vào khoảng nhắc thì bỏ qua (khách vừa nhận email xác nhận). **WEB-FR-NOTI-08-AC-02** — Thử đầu vào sai/thiếu quyền/xung đột áp dụng và kiểm tra từ chối đã nêu, không đổi dữ liệu trái phép và không báo thành công sai. |
| Bằng chứng | [Cinema_BE/BookingService/BookingService/Controllers/NotificationController.cs](../Cinema_BE/BookingService/BookingService/Controllers/NotificationController.cs); [Cinema_BE/BookingService/BookingService/Services/Implementations/NotificationService.cs](../Cinema_BE/BookingService/BookingService/Services/Implementations/NotificationService.cs); [Cinema_BE/BookingService/BookingService/Workers/ShowtimeReminderWorker.cs](../Cinema_BE/BookingService/BookingService/Workers/ShowtimeReminderWorker.cs) |
| Quy tắc nghiệp vụ | WEB-BR-11, WEB-BR-13 |
| Ca sử dụng / màn / API | UC-WEB-12; ; WEB-API-078 |

### WEB-FR-NOTI-09 — Thông báo đã/chưa đọc

| Trường | Đặc tả |
| --- | --- |
| Tên | Thông báo đã/chưa đọc |
| Mô tả | **Đã đọc / chưa đọc**: thông báo chưa mở có chấm và chữ đậm; mở chi tiết là đánh dấu đã đọc; nút **Mark all read**. Chuông trên app và mục Notifications trên web có số thông báo chưa đọc. Chỉ chủ thông báo được đánh dấu (403). |
| Tác nhân | Khách hàng xem của mình; nhân viên/quản trị viên gửi thông báo được phép; hệ thống gửi theo sự kiện |
| Tiền điều kiện | Có phiên tài khoản để xem lịch sử trong ứng dụng; cấu hình SMTP/xử lý sự kiện để gửi thật. |
| Kích hoạt | Thực hiện “Thông báo đã/chưa đọc” hoặc sự kiện/tác vụ backend tương ứng. |
| Luồng chính | 1. Đọc đầu vào/tài nguyên hiện tại và phiên áp dụng. 2. Thực hiện thao tác này: **Đã đọc / chưa đọc**: thông báo chưa mở có chấm và chữ đậm; mở chi tiết là đánh dấu đã đọc; nút **Mark all read**. Chuông trên app và mục Notifications trên web có số thông báo chưa đọc. Chỉ chủ thông báo được đánh dấu (403). 3. Trả/hiển thị kết quả chính thức và làm mới dữ liệu bị tác động sau thành công. |
| Luồng thay thế / ngoại lệ | Kiểm tra chủ sở hữu từ chối dữ liệu người khác; có trạng thái tải/rỗng/lỗi-thử lại. Gửi lỗi giữ FAILED để thử lại và không hoàn tác thanh toán. Chống lặp sự kiện giảm gửi trùng nhưng SMTP cùng commit database không bảo đảm giao dịch đúng một lần tuyệt đối. |
| Hậu điều kiện | Kết quả thành công quan sát được khớp yêu cầu này; chuyển trạng thái được chỉ định được lưu. Từ chối không cấp quyền hoặc để thay đổi dở dang trái phép. |
| Ưu tiên | M |
| Tiêu chí nghiệm thu | **WEB-FR-NOTI-09-AC-01** — Với tiền điều kiện/kích hoạt, kiểm tra: **Đã đọc / chưa đọc**: thông báo chưa mở có chấm và chữ đậm; mở chi tiết là đánh dấu đã đọc; nút **Mark all read**. Chuông trên app và mục Notifications trên web có số thông báo chưa đọc. Chỉ chủ thông báo được đánh dấu (403). **WEB-FR-NOTI-09-AC-02** — Thử đầu vào sai/thiếu quyền/xung đột áp dụng và kiểm tra từ chối đã nêu, không đổi dữ liệu trái phép và không báo thành công sai. |
| Bằng chứng | [Cinema_BE/BookingService/BookingService/Controllers/NotificationController.cs](../Cinema_BE/BookingService/BookingService/Controllers/NotificationController.cs); [Cinema_Mobile/lib/features/home/screens/home_screen.dart](../Cinema_Mobile/lib/features/home/screens/home_screen.dart); [Cinema_Mobile/lib/features/notification/screens/notification_list_screen.dart](../Cinema_Mobile/lib/features/notification/screens/notification_list_screen.dart); [Cinema_Mobile/lib/features/notification/screens/notification_detail_screen.dart](../Cinema_Mobile/lib/features/notification/screens/notification_detail_screen.dart); [Cinema_BE/BookingService/BookingService/Services/Implementations/NotificationService.cs](../Cinema_BE/BookingService/BookingService/Services/Implementations/NotificationService.cs); [Cinema_BE/BookingService/BookingService/Workers/ShowtimeReminderWorker.cs](../Cinema_BE/BookingService/BookingService/Workers/ShowtimeReminderWorker.cs) |
| Quy tắc nghiệp vụ | WEB-BR-11, WEB-BR-13 |
| Ca sử dụng / màn / API | UC-WEB-12; WEB-SCR-HOME, WEB-SCR-NOTIFICATIONS, WEB-SCR-NOTIFICATION; WEB-API-072, WEB-API-076, WEB-API-077 |

### WEB-FR-DASH-01 — Tổng hôm nay

| Trường | Đặc tả |
| --- | --- |
| Tên | Tổng hôm nay |
| Mô tả | Khối **Today** (Staff và Admin): vé tạo hôm nay; suất hôm nay có vé (x / tổng suất); vé của các suất hôm nay; số đã check-in. |
| Tác nhân | Nhân viên/quản trị viên |
| Tiền điều kiện | Có phiên quản lý và dữ liệu nguồn; khoảng ngày dùng giờ địa phương của rạp. |
| Kích hoạt | Thực hiện “Tổng hôm nay” hoặc sự kiện/tác vụ backend tương ứng. |
| Luồng chính | 1. Đọc đầu vào/tài nguyên hiện tại và phiên áp dụng. 2. Thực hiện thao tác này: Khối **Today** (Staff và Admin): vé tạo hôm nay; suất hôm nay có vé (x / tổng suất); vé của các suất hôm nay; số đã check-in. 3. Trả/hiển thị kết quả chính thức và làm mới dữ liệu bị tác động sau thành công. |
| Luồng thay thế / ngoại lệ | Hiển thị đúng kỳ bằng không/rỗng; mỗi thẻ có thể hiện lỗi và thử lại riêng. Nhân viên không được truy cập API doanh thu/tài khoản bằng cách đổi URL. |
| Hậu điều kiện | Dữ liệu/trạng thái đủ quyền được trả/hiển thị; đọc không đổi trạng thái vé/thanh toán. Dấu đã đọc thông báo chỉ đổi bằng thao tác ghi riêng. |
| Ưu tiên | M |
| Tiêu chí nghiệm thu | **WEB-FR-DASH-01-AC-01** — Với tiền điều kiện/kích hoạt, kiểm tra: Khối **Today** (Staff và Admin): vé tạo hôm nay; suất hôm nay có vé (x / tổng suất); vé của các suất hôm nay; số đã check-in. **WEB-FR-DASH-01-AC-02** — Thử đầu vào sai/thiếu quyền/xung đột áp dụng và kiểm tra từ chối đã nêu, không đổi dữ liệu trái phép và không báo thành công sai. |
| Bằng chứng | [Cinema_BE/MovieService/MovieService/Controllers/ShowtimesController.cs](../Cinema_BE/MovieService/MovieService/Controllers/ShowtimesController.cs); [Cinema_BE/BookingService/BookingService/Controllers/BookingController.cs](../Cinema_BE/BookingService/BookingService/Controllers/BookingController.cs); [Cinema_Mobile/lib/features/staff/screens/staff_dashboard_screen.dart](../Cinema_Mobile/lib/features/staff/screens/staff_dashboard_screen.dart); [Cinema_Mobile/lib/features/admin/screens/admin_dashboard_screen.dart](../Cinema_Mobile/lib/features/admin/screens/admin_dashboard_screen.dart) |
| Quy tắc nghiệp vụ | WEB-BR-09, WEB-BR-23 |
| Ca sử dụng / màn / API | UC-WEB-13; WEB-SCR-STAFF-DASH, WEB-SCR-ADMIN-DASH; WEB-API-019, WEB-API-048, WEB-API-051 |

### WEB-FR-DASH-02 — Bảng suất trực tiếp

| Trường | Đặc tả |
| --- | --- |
| Tên | Bảng suất trực tiếp |
| Mô tả | Bảng suất chiếu: **Now showing** (mọi suất đang chiếu, số khách đang xem = đã check-in, vé đã bán / sức chứa, thời gian còn lại); **Up next** (3 suất tiếp theo: đã đặt, chờ thanh toán, đã check-in sớm); **Just finished** (3 suất vừa xong: vé đã bán, số khách đã vào). Bấm suất mở sơ đồ ghế và danh sách khách. Tự làm mới mỗi phút. |
| Tác nhân | Nhân viên/quản trị viên |
| Tiền điều kiện | Có phiên quản lý và dữ liệu nguồn; khoảng ngày dùng giờ địa phương của rạp. |
| Kích hoạt | Thực hiện “Bảng suất trực tiếp” hoặc sự kiện/tác vụ backend tương ứng. |
| Luồng chính | 1. Đọc đầu vào/tài nguyên hiện tại và phiên áp dụng. 2. Thực hiện thao tác này: Bảng suất chiếu: **Now showing** (mọi suất đang chiếu, số khách đang xem = đã check-in, vé đã bán / sức chứa, thời gian còn lại); **Up next** (3 suất tiếp theo: đã đặt, chờ thanh toán, đã check-in sớm); **Just finished** (3 suất vừa xong: vé đã bán, số khách đã vào). Bấm suất mở sơ đồ ghế và danh sách khách. Tự làm mới mỗi phút. 3. Trả/hiển thị kết quả chính thức và làm mới dữ liệu bị tác động sau thành công. |
| Luồng thay thế / ngoại lệ | Hiển thị đúng kỳ bằng không/rỗng; mỗi thẻ có thể hiện lỗi và thử lại riêng. Nhân viên không được truy cập API doanh thu/tài khoản bằng cách đổi URL. |
| Hậu điều kiện | Dữ liệu/trạng thái đủ quyền được trả/hiển thị; đọc không đổi trạng thái vé/thanh toán. Dấu đã đọc thông báo chỉ đổi bằng thao tác ghi riêng. |
| Ưu tiên | M |
| Tiêu chí nghiệm thu | **WEB-FR-DASH-02-AC-01** — Với tiền điều kiện/kích hoạt, kiểm tra: Bảng suất chiếu: **Now showing** (mọi suất đang chiếu, số khách đang xem = đã check-in, vé đã bán / sức chứa, thời gian còn lại); **Up next** (3 suất tiếp theo: đã đặt, chờ thanh toán, đã check-in sớm); **Just finished** (3 suất vừa xong: vé đã bán, số khách đã vào). Bấm suất mở sơ đồ ghế và danh sách khách. Tự làm mới mỗi phút. **WEB-FR-DASH-02-AC-02** — Thử đầu vào sai/thiếu quyền/xung đột áp dụng và kiểm tra từ chối đã nêu, không đổi dữ liệu trái phép và không báo thành công sai. |
| Bằng chứng | [Cinema_BE/MovieService/MovieService/Controllers/ShowtimesController.cs](../Cinema_BE/MovieService/MovieService/Controllers/ShowtimesController.cs); [Cinema_BE/BookingService/BookingService/Controllers/BookingController.cs](../Cinema_BE/BookingService/BookingService/Controllers/BookingController.cs); [Cinema_Mobile/lib/features/staff/screens/staff_dashboard_screen.dart](../Cinema_Mobile/lib/features/staff/screens/staff_dashboard_screen.dart); [Cinema_Mobile/lib/features/admin/screens/admin_dashboard_screen.dart](../Cinema_Mobile/lib/features/admin/screens/admin_dashboard_screen.dart) |
| Quy tắc nghiệp vụ | WEB-BR-09, WEB-BR-23 |
| Ca sử dụng / màn / API | UC-WEB-13; WEB-SCR-STAFF-DASH, WEB-SCR-ADMIN-DASH; WEB-API-019, WEB-API-051 |

### WEB-FR-DASH-03 — Việc nhân viên cần xử lý

| Trường | Đặc tả |
| --- | --- |
| Tên | Việc nhân viên cần xử lý |
| Mô tả | Dashboard Staff có mục **Needs attention**: vé chờ thanh toán, yêu cầu hoàn tiền chờ xử lý; lối tắt **Sell tickets** và **Check in**. |
| Tác nhân | Nhân viên/quản trị viên |
| Tiền điều kiện | Có phiên quản lý và dữ liệu nguồn; khoảng ngày dùng giờ địa phương của rạp. |
| Kích hoạt | Thực hiện “Việc nhân viên cần xử lý” hoặc sự kiện/tác vụ backend tương ứng. |
| Luồng chính | 1. Đọc đầu vào/tài nguyên hiện tại và phiên áp dụng. 2. Thực hiện thao tác này: Dashboard Staff có mục **Needs attention**: vé chờ thanh toán, yêu cầu hoàn tiền chờ xử lý; lối tắt **Sell tickets** và **Check in**. 3. Trả/hiển thị kết quả chính thức và làm mới dữ liệu bị tác động sau thành công. |
| Luồng thay thế / ngoại lệ | Hiển thị đúng kỳ bằng không/rỗng; mỗi thẻ có thể hiện lỗi và thử lại riêng. Nhân viên không được truy cập API doanh thu/tài khoản bằng cách đổi URL. |
| Hậu điều kiện | Dữ liệu/trạng thái đủ quyền được trả/hiển thị; đọc không đổi trạng thái vé/thanh toán. Dấu đã đọc thông báo chỉ đổi bằng thao tác ghi riêng. |
| Ưu tiên | M |
| Tiêu chí nghiệm thu | **WEB-FR-DASH-03-AC-01** — Với tiền điều kiện/kích hoạt, kiểm tra: Dashboard Staff có mục **Needs attention**: vé chờ thanh toán, yêu cầu hoàn tiền chờ xử lý; lối tắt **Sell tickets** và **Check in**. **WEB-FR-DASH-03-AC-02** — Thử đầu vào sai/thiếu quyền/xung đột áp dụng và kiểm tra từ chối đã nêu, không đổi dữ liệu trái phép và không báo thành công sai. |
| Bằng chứng | [Cinema_BE/BookingService/BookingService/Controllers/BookingController.cs](../Cinema_BE/BookingService/BookingService/Controllers/BookingController.cs); [Cinema_BE/BookingService/BookingService/Controllers/PaymentController.cs](../Cinema_BE/BookingService/BookingService/Controllers/PaymentController.cs); [Cinema_Mobile/lib/features/staff/screens/staff_dashboard_screen.dart](../Cinema_Mobile/lib/features/staff/screens/staff_dashboard_screen.dart) |
| Quy tắc nghiệp vụ | WEB-BR-09, WEB-BR-23 |
| Ca sử dụng / màn / API | UC-WEB-13; WEB-SCR-STAFF-DASH; WEB-API-052, WEB-API-093 |

### WEB-FR-DASH-04 — Tổng quan tháng quản trị

| Trường | Đặc tả |
| --- | --- |
| Tên | Tổng quan tháng quản trị |
| Mô tả | Dashboard Admin: booking và doanh thu tháng này, tiền đã hoàn, phim đang chiếu, suất hôm nay, thống kê tài khoản (tổng, đang hoạt động, bị khoá). Các phần tải độc lập, một phần lỗi không làm hỏng phần khác. |
| Tác nhân | Nhân viên/quản trị viên |
| Tiền điều kiện | Có phiên quản lý và dữ liệu nguồn; khoảng ngày dùng giờ địa phương của rạp. |
| Kích hoạt | Thực hiện “Tổng quan tháng quản trị” hoặc sự kiện/tác vụ backend tương ứng. |
| Luồng chính | 1. Đọc đầu vào/tài nguyên hiện tại và phiên áp dụng. 2. Thực hiện thao tác này: Dashboard Admin: booking và doanh thu tháng này, tiền đã hoàn, phim đang chiếu, suất hôm nay, thống kê tài khoản (tổng, đang hoạt động, bị khoá). Các phần tải độc lập, một phần lỗi không làm hỏng phần khác. 3. Trả/hiển thị kết quả chính thức và làm mới dữ liệu bị tác động sau thành công. |
| Luồng thay thế / ngoại lệ | Hiển thị đúng kỳ bằng không/rỗng; mỗi thẻ có thể hiện lỗi và thử lại riêng. Nhân viên không được truy cập API doanh thu/tài khoản bằng cách đổi URL. |
| Hậu điều kiện | Dữ liệu/trạng thái đủ quyền được trả/hiển thị; đọc không đổi trạng thái vé/thanh toán. Dấu đã đọc thông báo chỉ đổi bằng thao tác ghi riêng. |
| Ưu tiên | M |
| Tiêu chí nghiệm thu | **WEB-FR-DASH-04-AC-01** — Với tiền điều kiện/kích hoạt, kiểm tra: Dashboard Admin: booking và doanh thu tháng này, tiền đã hoàn, phim đang chiếu, suất hôm nay, thống kê tài khoản (tổng, đang hoạt động, bị khoá). Các phần tải độc lập, một phần lỗi không làm hỏng phần khác. **WEB-FR-DASH-04-AC-02** — Thử đầu vào sai/thiếu quyền/xung đột áp dụng và kiểm tra từ chối đã nêu, không đổi dữ liệu trái phép và không báo thành công sai. |
| Bằng chứng | [Cinema_BE/AuthService/AuthService/Controllers/UsersController.cs](../Cinema_BE/AuthService/AuthService/Controllers/UsersController.cs); [Cinema_BE/BookingService/BookingService/Controllers/BookingController.cs](../Cinema_BE/BookingService/BookingService/Controllers/BookingController.cs); [Cinema_BE/MovieService/MovieService/Controllers/MoviesController.cs](../Cinema_BE/MovieService/MovieService/Controllers/MoviesController.cs); [Cinema_BE/BookingService/BookingService/Controllers/PaymentController.cs](../Cinema_BE/BookingService/BookingService/Controllers/PaymentController.cs); [Cinema_Mobile/lib/features/admin/screens/admin_dashboard_screen.dart](../Cinema_Mobile/lib/features/admin/screens/admin_dashboard_screen.dart) |
| Quy tắc nghiệp vụ | WEB-BR-09, WEB-BR-23 |
| Ca sử dụng / màn / API | UC-WEB-13; WEB-SCR-ADMIN-DASH; WEB-API-040, WEB-API-048, WEB-API-069, WEB-API-094 |

### WEB-FR-NAV-01 — Bảo vệ và khôi phục route

| Trường | Đặc tả |
| --- | --- |
| Tên | Bảo vệ và khôi phục route |
| Mô tả | Bảo vệ route có tên: đích cần quyền khi chưa đăng nhập mở đăng nhập và lưu route chờ; đăng nhập thành công tiếp tục đích đủ quyền. Route lạ về trang đầu theo vai trò. Trang xác nhận thiếu BookingDraft trong bộ nhớ quay về chọn ghế. |
| Tác nhân | Khách chưa đăng nhập; người có tài khoản; hệ thống |
| Tiền điều kiện | Truy cập được biểu mẫu và đã cấu hình gateway/AuthService; đăng ký/đăng nhập/OTP/khôi phục không cần phiên đã đăng nhập. Gửi mã cần SMTP. |
| Kích hoạt | Thực hiện “Bảo vệ và khôi phục route” hoặc sự kiện/tác vụ backend tương ứng. |
| Luồng chính | 1. Đọc đầu vào/tài nguyên hiện tại và phiên áp dụng. 2. Thực hiện thao tác này: Bảo vệ route có tên: đích cần quyền khi chưa đăng nhập mở đăng nhập và lưu route chờ; đăng nhập thành công tiếp tục đích đủ quyền. Route lạ về trang đầu theo vai trò. Trang xác nhận thiếu BookingDraft trong bộ nhớ quay về chọn ghế. 3. Trả/hiển thị kết quả chính thức và làm mới dữ liệu bị tác động sau thành công. |
| Luồng thay thế / ngoại lệ | Từ chối trường sai (400), thông tin đăng nhập sai (401), email chưa xác thực (403), OTP cũ/sai hoặc vượt giới hạn gửi/tần suất (429). Xoá phiên khi tài khoản bị khoá/quyền thay đổi; hiển thị lỗi SMTP/phụ thuộc (503). |
| Hậu điều kiện | Kết quả thành công quan sát được khớp yêu cầu này; chuyển trạng thái được chỉ định được lưu. Từ chối không cấp quyền hoặc để thay đổi dở dang trái phép. |
| Ưu tiên | H |
| Tiêu chí nghiệm thu | **WEB-FR-NAV-01-AC-01** — Với tiền điều kiện/kích hoạt, kiểm tra: Bảo vệ route có tên: đích cần quyền khi chưa đăng nhập mở đăng nhập và lưu route chờ; đăng nhập thành công tiếp tục đích đủ quyền. Route lạ về trang đầu theo vai trò. Trang xác nhận thiếu BookingDraft trong bộ nhớ quay về chọn ghế. **WEB-FR-NAV-01-AC-02** — Thử đầu vào sai/thiếu quyền/xung đột áp dụng và kiểm tra từ chối đã nêu, không đổi dữ liệu trái phép và không báo thành công sai. |
| Bằng chứng | [Cinema_Mobile/lib/features/auth/screens/login_screen.dart](../Cinema_Mobile/lib/features/auth/screens/login_screen.dart); [Cinema_Mobile/lib/features/admin/screens/staff_only_screen.dart](../Cinema_Mobile/lib/features/admin/screens/staff_only_screen.dart); [Cinema_BE/AuthService/AuthService/Service/AuthService.cs](../Cinema_BE/AuthService/AuthService/Service/AuthService.cs); [Cinema_BE/ApiGateway/ApiGateway/Program.cs](../Cinema_BE/ApiGateway/ApiGateway/Program.cs) |
| Quy tắc nghiệp vụ | WEB-BR-01, WEB-BR-02, WEB-BR-03, WEB-BR-24, WEB-BR-25 |
| Ca sử dụng / màn / API | UC-WEB-01; WEB-SCR-LOGIN, WEB-SCR-STAFF-ONLY; Hành vi client; không endpoint riêng |

### WEB-FR-STATE-01 — Trạng thái tải, lỗi và rỗng

| Trường | Đặc tả |
| --- | --- |
| Tên | Trạng thái tải, lỗi và rỗng |
| Mô tả | Có trạng thái tải, lỗi/thử lại và rỗng trên màn dữ liệu; chặn gửi lặp khi thao tác ghi đang chạy và giữ kết quả chờ/thất bại đúng thực tế khi lỗi mạng. |
| Tác nhân | Khách hàng sở hữu vé trực tuyến; nhân viên/quản trị viên thực hiện nghiệp vụ quầy và quản lý |
| Tiền điều kiện | Màn dữ liệu bắt đầu tải hoặc yêu cầu đang chạy. |
| Kích hoạt | Thực hiện “Trạng thái tải, lỗi và rỗng” hoặc sự kiện/tác vụ backend tương ứng. |
| Luồng chính | 1. Đọc đầu vào/tài nguyên hiện tại và phiên áp dụng. 2. Thực hiện thao tác này: Có trạng thái tải, lỗi/thử lại và rỗng trên màn dữ liệu; chặn gửi lặp khi thao tác ghi đang chạy và giữ kết quả chờ/thất bại đúng thực tế khi lỗi mạng. 3. Trả/hiển thị kết quả chính thức và làm mới dữ liệu bị tác động sau thành công. |
| Luồng thay thế / ngoại lệ | Giữ chỗ đồng thời trả 409 và không được thu tiền hoặc để lại ghế/điểm dở dang. Bắp nước/mã/điểm sai trả lỗi kiểm tra. Hết hạn nhả ghế và trả điểm đã giữ. |
| Hậu điều kiện | Kết quả thành công quan sát được khớp yêu cầu này; chuyển trạng thái được chỉ định được lưu. Từ chối không cấp quyền hoặc để thay đổi dở dang trái phép. |
| Ưu tiên | M |
| Tiêu chí nghiệm thu | **WEB-FR-STATE-01-AC-01** — Với tiền điều kiện/kích hoạt, kiểm tra: Có trạng thái tải, lỗi/thử lại và rỗng trên màn dữ liệu; chặn gửi lặp khi thao tác ghi đang chạy và giữ kết quả chờ/thất bại đúng thực tế khi lỗi mạng. **WEB-FR-STATE-01-AC-02** — Thử đầu vào sai/thiếu quyền/xung đột áp dụng và kiểm tra từ chối đã nêu, không đổi dữ liệu trái phép và không báo thành công sai. |
| Bằng chứng | [Cinema_BE/BookingService/BookingService/Services/Implementations/BookingService.cs](../Cinema_BE/BookingService/BookingService/Services/Implementations/BookingService.cs); [Cinema_BE/BookingService/BookingService/Helpers/PromotionRules.cs](../Cinema_BE/BookingService/BookingService/Helpers/PromotionRules.cs); [Cinema_BE/BookingService/BookingService/Helpers/LoyaltyRules.cs](../Cinema_BE/BookingService/BookingService/Helpers/LoyaltyRules.cs) |
| Quy tắc nghiệp vụ | WEB-BR-07, WEB-BR-08, WEB-BR-14, WEB-BR-15, WEB-BR-16, WEB-BR-17, WEB-BR-27, WEB-BR-28, WEB-BR-29 |
| Ca sử dụng / màn / API | UC-WEB-07; ; Hành vi client; không endpoint riêng |

### WEB-FR-MEDIA-01 — Media phim theo nền tảng

| Trường | Đặc tả |
| --- | --- |
| Tên | Media phim theo nền tảng |
| Mô tả | Thẻ phim web có thể xem trước MP4/WebM HTTP(S) trực tiếp sau rê chuột 450 ms; dừng khi rời chuột và trở về ảnh, có hạn 12 giây và hỗ trợ giảm chuyển động. Điện thoại native đặt supportsTrailerPreview=false và mở trailer đầy đủ bằng ứng dụng ngoài. |
| Tác nhân | Quản trị viên |
| Tiền điều kiện | Có phiên quản trị viên; bản ghi đích tồn tại khi sửa/dừng/điều chỉnh. |
| Kích hoạt | Thực hiện “Media phim theo nền tảng” hoặc sự kiện/tác vụ backend tương ứng. |
| Luồng chính | 1. Đọc đầu vào/tài nguyên hiện tại và phiên áp dụng. 2. Thực hiện thao tác này: Thẻ phim web có thể xem trước MP4/WebM HTTP(S) trực tiếp sau rê chuột 450 ms; dừng khi rời chuột và trở về ảnh, có hạn 12 giây và hỗ trợ giảm chuyển động. Điện thoại native đặt supportsTrailerPreview=false và mở trailer đầy đủ bằng ứng dụng ngoài. 3. Trả/hiển thị kết quả chính thức và làm mới dữ liệu bị tác động sau thành công. |
| Luồng thay thế / ngoại lệ | Hiện trạng thái rỗng khi không có phim/suất phù hợp. Đánh giá bằng vé người khác trả 404; vé chưa check-in trả 400. Media lỗi phải còn ảnh hoặc nội dung dự phòng. |
| Hậu điều kiện | Dữ liệu/trạng thái đủ quyền được trả/hiển thị; đọc không đổi trạng thái vé/thanh toán. Dấu đã đọc thông báo chỉ đổi bằng thao tác ghi riêng. |
| Ưu tiên | L |
| Tiêu chí nghiệm thu | **WEB-FR-MEDIA-01-AC-01** — Với tiền điều kiện/kích hoạt, kiểm tra: Thẻ phim web có thể xem trước MP4/WebM HTTP(S) trực tiếp sau rê chuột 450 ms; dừng khi rời chuột và trở về ảnh, có hạn 12 giây và hỗ trợ giảm chuyển động. Điện thoại native đặt supportsTrailerPreview=false và mở trailer đầy đủ bằng ứng dụng ngoài. **WEB-FR-MEDIA-01-AC-02** — Thử đầu vào sai/thiếu quyền/xung đột áp dụng và kiểm tra từ chối đã nêu, không đổi dữ liệu trái phép và không báo thành công sai. |
| Bằng chứng | [Cinema_BE/MovieService/MovieService/Controllers/MoviesController.cs](../Cinema_BE/MovieService/MovieService/Controllers/MoviesController.cs); [Cinema_Mobile/lib/features/home/screens/home_screen.dart](../Cinema_Mobile/lib/features/home/screens/home_screen.dart); [Cinema_BE/MovieService/MovieService/Service/Impl/MovieService.cs](../Cinema_BE/MovieService/MovieService/Service/Impl/MovieService.cs); [Cinema_BE/BookingService/BookingService/Services/Implementations/MovieReviewService.cs](../Cinema_BE/BookingService/BookingService/Services/Implementations/MovieReviewService.cs) |
| Quy tắc nghiệp vụ | WEB-BR-26 |
| Ca sử dụng / màn / API | UC-WEB-03; WEB-SCR-HOME; WEB-API-064 |

## 10. Đặc tả ca sử dụng

### UC-WEB-01 — Xác thực và phiên tài khoản

| Trường | Đặc tả ca sử dụng |
| --- | --- |
| Tác nhân | Khách chưa đăng nhập; người có tài khoản; hệ thống |
| Mục tiêu | Xác thực và phiên tài khoản |
| Tiền điều kiện | Gateway đã được cấu hình. Đăng ký/khôi phục cần SMTP; thao tác được bảo vệ cần phiên tài khoản hợp lệ. |
| Kích hoạt | Mở màn liên quan hoặc thực hiện thao tác/sự kiện đã nêu. |
| Luồng chính | 1. Nhập thông tin tài khoản hoặc yêu cầu thao tác phiên. 2. Kiểm tra trường dữ liệu; gửi đến AuthService qua gateway. 3. Với xác thực/khôi phục, nhập OTP từ email; với đăng nhập/làm mới, lưu token và người dùng trả về. 4. Điều hướng theo vai trò và tiếp tục trang đang chờ nếu đủ quyền. |
| Luồng thay thế / ngoại lệ | Từ chối trường sai (400), thông tin đăng nhập sai (401), email chưa xác thực (403), OTP cũ/sai hoặc vượt giới hạn gửi/tần suất (429). Xoá phiên khi tài khoản bị khoá/quyền thay đổi; hiển thị lỗi SMTP/phụ thuộc (503). |
| Hậu điều kiện | Chỉ thao tác cấp token thành công mới xác thực tài khoản; yêu cầu bị từ chối không cấp quyền truy cập. |
| Yêu cầu / ưu tiên | WEB-FR-AUTH-01 (H), WEB-FR-AUTH-02 (H), WEB-FR-AUTH-03 (H), WEB-FR-AUTH-04 (H), WEB-FR-AUTH-05 (H), WEB-FR-AUTH-06 (H), WEB-FR-AUTH-07 (H), WEB-FR-AUTH-08 (M), WEB-FR-AUTH-09 (H), WEB-FR-AUTH-10 (H), WEB-FR-AUTH-11 (M), WEB-FR-AUTH-12 (H), WEB-FR-AUTH-13 (H), WEB-FR-AUTH-14 (M), WEB-FR-AUTH-15 (M), WEB-FR-AUTH-16 (M), WEB-FR-AUTH-17 (M), WEB-FR-NAV-01 (H) |
| Nghiệm thu | Thực hiện AC-01/AC-02 cho mọi FR liên quan với tác nhân đủ quyền. |

### UC-WEB-02 — Quản trị tài khoản

| Trường | Đặc tả ca sử dụng |
| --- | --- |
| Tác nhân | Quản trị viên |
| Mục tiêu | Quản trị tài khoản |
| Tiền điều kiện | Phiên quản trị viên đang hoạt động; người dùng đích tồn tại khi cập nhật. |
| Kích hoạt | Mở màn liên quan hoặc thực hiện thao tác/sự kiện đã nêu. |
| Luồng chính | 1. Tìm/lọc tài khoản có phân trang hoặc mở bản ghi. 2. Tạo tài khoản, chọn vai trò hoặc đổi trạng thái hoạt động. 3. Kiểm tra và xác nhận thay đổi. 4. Tải lại tài khoản và thu hồi phiên khi cần. |
| Luồng thay thế / ngoại lệ | Từ chối người gọi không phải quản trị viên; từ chối trường sai, email trùng và tự khoá tài khoản. Lưu vai trò không đổi không được buộc đăng nhập lại. |
| Hậu điều kiện | Tài khoản/vai trò/trạng thái đã lưu được hiển thị; token của tài khoản bị khoá hoặc đổi vai trò không giữ quyền cũ. |
| Yêu cầu / ưu tiên | WEB-FR-USER-01 (H), WEB-FR-USER-02 (H), WEB-FR-USER-03 (H), WEB-FR-USER-04 (H), WEB-FR-USER-05 (H), WEB-FR-USER-06 (M) |
| Nghiệm thu | Thực hiện AC-01/AC-02 cho mọi FR liên quan với tác nhân đủ quyền. |

### UC-WEB-03 — Danh mục phim và đánh giá

| Trường | Đặc tả ca sử dụng |
| --- | --- |
| Tác nhân | Khách chưa đăng nhập/khách hàng xem phim; quản trị viên sửa danh mục và kiểm duyệt |
| Mục tiêu | Danh mục phim và đánh giá |
| Tiền điều kiện | Có dữ liệu phim; cập nhật cần quản trị viên; đánh giá cần vé của chính khách đã được check-in. |
| Kích hoạt | Mở màn liên quan hoặc thực hiện thao tác/sự kiện đã nêu. |
| Luồng chính | 1. Duyệt/tìm/lọc phim hoặc mở chi tiết. 2. Tải thông tin, trailer, đánh giá và suất mở bán; quản trị viên có thể lưu thông tin hoặc ngừng chiếu phim. 3. Khi đánh giá, lấy điều kiện từ vé, gửi 1–5 sao và tối đa 1.000 ký tự hoặc xoá đánh giá đã có. 4. Làm mới phần hiển thị liên quan. |
| Luồng thay thế / ngoại lệ | Hiện trạng thái rỗng khi không có phim/suất phù hợp. Đánh giá bằng vé người khác trả 404; vé chưa check-in trả 400. Media lỗi phải còn ảnh hoặc nội dung dự phòng. |
| Hậu điều kiện | Danh mục/đánh giá phản ánh phản hồi chính thức; ngừng chiếu vẫn giữ các vé đã có. |
| Yêu cầu / ưu tiên | WEB-FR-MOV-01 (H), WEB-FR-MOV-02 (H), WEB-FR-MOV-03 (M), WEB-FR-MOV-04 (H), WEB-FR-MOV-05 (H), WEB-FR-MOV-06 (H), WEB-FR-MOV-07 (H), WEB-FR-MOV-08 (L), WEB-FR-MOV-09 (H), WEB-FR-MOV-10 (M), WEB-FR-MOV-11 (L), WEB-FR-MOV-12 (M), WEB-FR-MEDIA-01 (L) |
| Nghiệm thu | Thực hiện AC-01/AC-02 cho mọi FR liên quan với tác nhân đủ quyền. |

### UC-WEB-04 — Quản lý phòng chiếu

| Trường | Đặc tả ca sử dụng |
| --- | --- |
| Tác nhân | Nhân viên/quản trị viên xem; quản trị viên cập nhật |
| Mục tiêu | Quản lý phòng chiếu |
| Tiền điều kiện | Phiên quản lý đang hoạt động; thay đổi sơ đồ cần phòng không có suất chiếu. |
| Kích hoạt | Mở màn liên quan hoặc thực hiện thao tác/sự kiện đã nêu. |
| Luồng chính | 1. Tìm/liệt kê phòng và mở sơ đồ. 2. Quản trị viên nhập tên và kích thước khi tạo hoặc đổi tên/xoá phòng đã chọn. 3. Tạo phòng rồi sinh ghế; làm mới phòng và số ghế. |
| Luồng thay thế / ngoại lệ | Từ chối sức chứa sai, phòng không tồn tại, thiếu quyền và xoá/đổi sơ đồ khi đã có suất chiếu tham chiếu. Tạo phòng và sinh ghế là hai lời gọi HTTP riêng; phải báo lỗi nếu lời gọi thứ hai thất bại. |
| Hậu điều kiện | Dữ liệu phòng được lưu hoặc phòng đủ điều kiện được xoá; đổi tên giữ nguyên nhãn ghế. |
| Yêu cầu / ưu tiên | WEB-FR-ROOM-01 (H), WEB-FR-ROOM-02 (H), WEB-FR-ROOM-03 (H), WEB-FR-ROOM-04 (M), WEB-FR-ROOM-05 (M) |
| Nghiệm thu | Thực hiện AC-01/AC-02 cho mọi FR liên quan với tác nhân đủ quyền. |

### UC-WEB-05 — Sơ đồ ghế và tình trạng chỗ

| Trường | Đặc tả ca sử dụng |
| --- | --- |
| Tác nhân | Khách hàng đã đăng nhập xem/chọn; nhân viên/quản trị viên đổi loại; quản trị viên đổi sức chứa/xoá |
| Mục tiêu | Sơ đồ ghế và tình trạng chỗ |
| Tiền điều kiện | Phòng/suất tồn tại. Chọn ghế cần đăng nhập; sửa sơ đồ cần quyền quản lý và phòng không có suất chiếu. |
| Kích hoạt | Mở màn liên quan hoặc thực hiện thao tác/sự kiện đã nêu. |
| Luồng chính | 1. Tải ghế phòng và danh sách ID đã giữ/bán riêng biệt. 2. Hiển thị hàng, chú giải loại và giá từ server; chọn ghế trống kèm cặp sweetbox. 3. Làm mới tình trạng mỗi năm giây; quản lý chỉ đổi loại/sức chứa qua API đủ quyền. |
| Luồng thay thế / ngoại lệ | Bỏ chọn ghế vừa bị đơn khác giữ và thông báo cho khách. Từ chối nửa cặp sweetbox, ghế sai phòng và sửa sơ đồ không đủ điều kiện. |
| Hậu điều kiện | Client hiển thị sơ đồ mới; chỉ chọn ghế chưa tạo giữ chỗ. |
| Yêu cầu / ưu tiên | WEB-FR-SEAT-01 (H), WEB-FR-SEAT-02 (L), WEB-FR-SEAT-03 (H), WEB-FR-SEAT-04 (L), WEB-FR-SEAT-05 (H), WEB-FR-SEAT-06 (M), WEB-FR-SEAT-07 (M), WEB-FR-SEAT-08 (H), WEB-FR-SEAT-09 (L) |
| Nghiệm thu | Thực hiện AC-01/AC-02 cho mọi FR liên quan với tác nhân đủ quyền. |

### UC-WEB-06 — Suất chiếu và giá vé

| Trường | Đặc tả ca sử dụng |
| --- | --- |
| Tác nhân | Khách chưa đăng nhập/khách hàng xem suất công khai; nhân viên/quản trị viên quản lý |
| Mục tiêu | Suất chiếu và giá vé |
| Tiền điều kiện | Phim và phòng tồn tại; thay đổi quản lý cần nhân viên/quản trị viên. |
| Kích hoạt | Mở màn liên quan hoặc thực hiện thao tác/sự kiện đã nêu. |
| Luồng chính | 1. Tải suất theo phim/ngày và chọn ngày. 2. Hiển thị phòng, định dạng, giờ bắt đầu/kết thúc và giá theo loại ghế. 3. Người quản lý lưu lịch hoặc mở/đóng/huỷ bán. 4. Kiểm tra trùng lịch và lưu; huỷ phát sự kiện qua outbox cho các vé liên quan. |
| Luồng thay thế / ngoại lệ | Từ chối trùng lịch bằng 409 và giờ/định dạng sai bằng 400; suất đã huỷ là trạng thái cuối. Khách không chọn suất đóng bán hoặc đã bắt đầu. |
| Hậu điều kiện | Lịch và giá theo loại ghế từ server là căn cứ chính thức; huỷ được lan truyền bất đồng bộ. |
| Yêu cầu / ưu tiên | WEB-FR-SHOW-01 (H), WEB-FR-SHOW-02 (H), WEB-FR-SHOW-03 (H), WEB-FR-SHOW-04 (H), WEB-FR-SHOW-05 (H), WEB-FR-SHOW-06 (H), WEB-FR-SHOW-07 (M), WEB-FR-SHOW-08 (H), WEB-FR-SHOW-09 (H), WEB-FR-SHOW-10 (M), WEB-FR-SHOW-11 (H), WEB-FR-SHOW-12 (M), WEB-FR-SHOW-13 (M) |
| Nghiệm thu | Thực hiện AC-01/AC-02 cho mọi FR liên quan với tác nhân đủ quyền. |

### UC-WEB-07 — Đặt vé, bắp nước, khuyến mãi và điểm thành viên

| Trường | Đặc tả ca sử dụng |
| --- | --- |
| Tác nhân | Khách hàng sở hữu vé trực tuyến; nhân viên/quản trị viên thực hiện nghiệp vụ quầy và quản lý |
| Mục tiêu | Đặt vé, bắp nước, khuyến mãi và điểm thành viên |
| Tiền điều kiện | Khách đã đăng nhập chọn suất OPEN chưa bắt đầu và ghế; khách vãng lai tại quầy được nhân viên/quản trị viên thao tác thay. |
| Kích hoạt | Mở màn liên quan hoặc thực hiện thao tác/sự kiện đã nêu. |
| Luồng chính | 1. Kiểm tra ghế; có thể chọn bắp nước đang bán, mã khuyến mãi và điểm được dùng. 2. Xác nhận điều kiện phân loại tuổi khi cần. 3. Gửi ID/số lượng; server tính lại toàn bộ giá, kiểm tra cặp, khoá giữ chỗ và tạo vé PENDING hết hạn sau mười phút. 4. Mở thanh toán hoặc xem/huỷ vé của mình theo trạng thái. |
| Luồng thay thế / ngoại lệ | Giữ chỗ đồng thời trả 409 và không được thu tiền hoặc để lại ghế/điểm dở dang. Bắp nước/mã/điểm sai trả lỗi kiểm tra. Hết hạn nhả ghế và trả điểm đã giữ. |
| Hậu điều kiện | Tạo thành công trả vé đã lưu, chi tiết tiền và hạn; tạo thất bại hoàn tác giao dịch. |
| Yêu cầu / ưu tiên | WEB-FR-BOOK-01 (H), WEB-FR-BOOK-02 (H), WEB-FR-BOOK-03 (H), WEB-FR-BOOK-04 (H), WEB-FR-BOOK-05 (H), WEB-FR-BOOK-06 (H), WEB-FR-BOOK-07 (H), WEB-FR-BOOK-08 (H), WEB-FR-BOOK-09 (H), WEB-FR-BOOK-10 (H), WEB-FR-BOOK-11 (M), WEB-FR-BOOK-12 (M), WEB-FR-BOOK-13 (M), WEB-FR-BOOK-14 (M), WEB-FR-BOOK-15 (M), WEB-FR-BOOK-16 (M), WEB-FR-BOOK-17 (M), WEB-FR-BOOK-18 (M), WEB-FR-BOOK-19 (L), WEB-FR-STATE-01 (M) |
| Nghiệm thu | Thực hiện AC-01/AC-02 cho mọi FR liên quan với tác nhân đủ quyền. |

### UC-WEB-08 — Thanh toán trực tuyến và đối soát

| Trường | Đặc tả ca sử dụng |
| --- | --- |
| Tác nhân | Chủ vé; nhân viên/quản trị viên với thao tác được phép; PayOS/hệ thống |
| Mục tiêu | Thanh toán trực tuyến và đối soát |
| Tiền điều kiện | Có vé đủ điều kiện thanh toán; thông tin PayOS và callback/địa chỉ trở về được cấu hình để thanh toán thật. |
| Kích hoạt | Mở màn liên quan hoặc thực hiện thao tác/sự kiện đã nêu. |
| Luồng chính | 1. Yêu cầu/dùng lại phiên PayOS cho vé. 2. Mở thanh toán và hiển thị đếm ngược giữ ghế. 3. Hỏi vé mỗi năm giây và xác minh PayOS mỗi ba mươi giây khi trang thanh toán khách đang hoạt động; đối soát khi trở lại ứng dụng. 4. Webhook có chữ ký hoặc dữ liệu PayOS đã xác minh cập nhật thanh toán và vé; tải kết quả từ server. |
| Luồng thay thế / ngoại lệ | Không dùng tham số chuyển hướng làm bằng chứng đã trả tiền. Xử lý huỷ, hết thời gian và 503 mà không báo thành công sai; trả muộn chỉ xác nhận nếu lấy lại được ghế, nếu không tạo hoàn tiền. |
| Hậu điều kiện | Trạng thái thanh toán từ server là chính thức; SUCCESS xác nhận vé và lên lịch thông báo mà không lặp tác động nghiệp vụ. |
| Yêu cầu / ưu tiên | WEB-FR-PAY-01 (H), WEB-FR-PAY-02 (H), WEB-FR-PAY-03 (H), WEB-FR-PAY-04 (M), WEB-FR-PAY-05 (M), WEB-FR-PAY-06 (H), WEB-FR-PAY-07 (H), WEB-FR-PAY-08 (M), WEB-FR-PAY-09 (M), WEB-FR-PAY-10 (M), WEB-FR-PAY-11 (M) |
| Nghiệm thu | Thực hiện AC-01/AC-02 cho mọi FR liên quan với tác nhân đủ quyền. |

### UC-WEB-09 — Huỷ vé và hoàn tiền thủ công

| Trường | Đặc tả ca sử dụng |
| --- | --- |
| Tác nhân | Khách hàng yêu cầu/xem hoàn tiền của mình; nhân viên/quản trị viên xử lý; hệ thống tạo yêu cầu |
| Mục tiêu | Huỷ vé và hoàn tiền thủ công |
| Tiền điều kiện | Có vé/thanh toán đã trả; khách tự huỷ phải còn ít nhất hai giờ trước suất; nhân viên xử lý cần yêu cầu đang chờ. |
| Kích hoạt | Mở màn liên quan hoặc thực hiện thao tác/sự kiện đã nêu. |
| Luồng chính | 1. Xác nhận huỷ và gửi lý do. 2. Backend tạo/dùng lại một yêu cầu hoàn tiền cho mỗi thanh toán và thông báo khách. 3. Nhân viên chuyển tiền ngoài ứng dụng rồi ghi mã giao dịch hoặc từ chối yêu cầu đủ điều kiện kèm lý do. 4. Khách tải lại trạng thái vé/hoàn tiền và lý do. |
| Luồng thay thế / ngoại lệ | Từ chối khách huỷ quá muộn (409), hoàn tất thiếu mã chuyển tiền và từ chối thiếu lý do; không từ chối hoàn tiền do rạp huỷ. Sự kiện lặp không được tạo thêm yêu cầu. |
| Hậu điều kiện | Hoàn tất đưa về COMPLETED/REFUNDED và nhả ghế vé bị huỷ; từ chối hợp lệ phục hồi SUCCESS/CONFIRMED; hoàn tiền đang chờ do khách yêu cầu vẫn giữ ghế. |
| Yêu cầu / ưu tiên | WEB-FR-REF-01 (H), WEB-FR-REF-02 (H), WEB-FR-REF-03 (H), WEB-FR-REF-04 (H), WEB-FR-REF-05 (M), WEB-FR-REF-06 (M), WEB-FR-REF-07 (H) |
| Nghiệm thu | Thực hiện AC-01/AC-02 cho mọi FR liên quan với tác nhân đủ quyền. |

### UC-WEB-10 — Bán vé tại quầy

| Trường | Đặc tả ca sử dụng |
| --- | --- |
| Tác nhân | Nhân viên/quản trị viên; khách vãng lai hoặc thành viên là người mua |
| Mục tiêu | Bán vé tại quầy |
| Tiền điều kiện | Phiên quản lý đang hoạt động; suất OPEN chưa bắt đầu còn ghế. |
| Kích hoạt | Mở màn liên quan hoặc thực hiện thao tác/sự kiện đã nêu. |
| Luồng chính | 1. Chọn khách vãng lai hoặc tìm thành viên qua điện thoại; chọn suất, ghế và bắp nước/khuyến mãi/điểm nếu cần. 2. Giữ ghế và mở thu tiền tại quầy. 3. Nhận đủ tiền mặt và hiện tiền thối hoặc hiện VietQR và xác minh mỗi ba giây. 4. Sau khi server xác nhận, hiện/in vé QR, có thể gửi email và check-in trong khung được phép. |
| Luồng thay thế / ngoại lệ | Từ chối thiếu tiền mặt; huỷ link PayOS chưa trả trước khi chuyển sang tiền mặt; nếu chuyển khoản đã thành công trả 409. Không có email thì in/hiện QR. |
| Hậu điều kiện | Một vé đã xác nhận và thanh toán thành công được ghi nhận và đưa vào báo cáo. |
| Yêu cầu / ưu tiên | WEB-FR-POS-01 (H), WEB-FR-POS-02 (H), WEB-FR-POS-03 (H), WEB-FR-POS-04 (H), WEB-FR-POS-05 (H), WEB-FR-POS-06 (M), WEB-FR-POS-07 (H), WEB-FR-POS-08 (M) |
| Nghiệm thu | Thực hiện AC-01/AC-02 cho mọi FR liên quan với tác nhân đủ quyền. |

### UC-WEB-11 — Tra vé và check-in

| Trường | Đặc tả ca sử dụng |
| --- | --- |
| Tác nhân | Nhân viên/quản trị viên quét và cho vào; khách hàng xuất trình vé của mình |
| Mục tiêu | Tra vé và check-in |
| Tiền điều kiện | Nhân viên/quản trị viên đã đăng nhập; vé CONFIRMED, chưa dùng và trong khoảng 180 phút trước đến 120 phút sau giờ bắt đầu. |
| Kích hoạt | Mở màn liên quan hoặc thực hiện thao tác/sự kiện đã nêu. |
| Luồng chính | 1. Quét QR hoặc nhập mã vé rồi nhấn Enter. 2. Tra vé; bổ sung phòng và phân loại tuổi khi lời gọi danh mục thành công. 3. Kiểm tra danh tính/tuổi theo nhắc nhở rồi xác nhận check-in. 4. Lưu checkedInAt, hiện xác nhận và sẵn sàng nhập mã tiếp theo. |
| Luồng thay thế / ngoại lệ | Cho nhập tay khi camera không có/bị từ chối. Mã không tồn tại trả 404; vé chưa trả, đã huỷ, chờ hoàn tiền, ngoài khung giờ hoặc đã dùng trả 409. Lần check-in thứ hai đồng thời thất bại. Lỗi thông tin bổ sung không được che vé. |
| Hậu điều kiện | Chỉ lưu một thời điểm check-in; check-in là thuộc tính, không phải trạng thái vé khác. |
| Yêu cầu / ưu tiên | WEB-FR-CHK-01 (H), WEB-FR-CHK-02 (H), WEB-FR-CHK-03 (H), WEB-FR-CHK-04 (H), WEB-FR-CHK-05 (M) |
| Nghiệm thu | Thực hiện AC-01/AC-02 cho mọi FR liên quan với tác nhân đủ quyền. |

### UC-WEB-12 — Thông báo và email giao dịch

| Trường | Đặc tả ca sử dụng |
| --- | --- |
| Tác nhân | Khách hàng xem của mình; nhân viên/quản trị viên gửi thông báo được phép; hệ thống gửi theo sự kiện |
| Mục tiêu | Thông báo và email giao dịch |
| Tiền điều kiện | Có phiên tài khoản để xem lịch sử trong ứng dụng; cấu hình SMTP/xử lý sự kiện để gửi thật. |
| Kích hoạt | Mở màn liên quan hoặc thực hiện thao tác/sự kiện đã nêu. |
| Luồng chính | 1. Tải thông báo và số chưa đọc hoặc tạo thông báo quản lý cho vé. 2. Mở chi tiết và đánh dấu đã đọc, đánh dấu tất cả hoặc mở vé liên quan. 3. Server gửi email giao dịch từ sự kiện đã commit và tác vụ nhắc lịch; lưu SENT/FAILED và lỗi gửi. |
| Luồng thay thế / ngoại lệ | Kiểm tra chủ sở hữu từ chối dữ liệu người khác; có trạng thái tải/rỗng/lỗi-thử lại. Gửi lỗi giữ FAILED để thử lại và không hoàn tác thanh toán. Chống lặp sự kiện giảm gửi trùng nhưng SMTP cùng commit database không bảo đảm giao dịch đúng một lần tuyệt đối. |
| Hậu điều kiện | Trạng thái đọc/số chưa đọc khớp phản hồi; gửi thành công được ghi riêng với trạng thái vé/thanh toán. |
| Yêu cầu / ưu tiên | WEB-FR-NOTI-01 (M), WEB-FR-NOTI-02 (M), WEB-FR-NOTI-03 (M), WEB-FR-NOTI-04 (M), WEB-FR-NOTI-05 (L), WEB-FR-NOTI-06 (H), WEB-FR-NOTI-07 (H), WEB-FR-NOTI-08 (M), WEB-FR-NOTI-09 (M) |
| Nghiệm thu | Thực hiện AC-01/AC-02 cho mọi FR liên quan với tác nhân đủ quyền. |

### UC-WEB-13 — Bảng tổng quan vận hành

| Trường | Đặc tả ca sử dụng |
| --- | --- |
| Tác nhân | Nhân viên/quản trị viên; doanh thu và thống kê tài khoản cần quản trị viên |
| Mục tiêu | Bảng tổng quan vận hành |
| Tiền điều kiện | Có phiên quản lý và dữ liệu nguồn; khoảng ngày dùng giờ địa phương của rạp. |
| Kích hoạt | Mở màn liên quan hoặc thực hiện thao tác/sự kiện đã nêu. |
| Luồng chính | 1. Tải vé, suất và thống kê check-in hôm nay. 2. Nhóm suất đang chiếu, ba suất sắp tới và ba suất vừa xong; làm mới mỗi phút. 3. Mở suất để xem ghế/khách. 4. Quản trị viên tải doanh thu/hoàn tiền/tài khoản tháng riêng để một thẻ lỗi không xoá thẻ khác. |
| Luồng thay thế / ngoại lệ | Hiển thị đúng kỳ bằng không/rỗng; mỗi thẻ có thể hiện lỗi và thử lại riêng. Nhân viên không được truy cập API doanh thu/tài khoản bằng cách đổi URL. |
| Hậu điều kiện | Tổng hiển thị dùng định nghĩa ngày và trạng thái đã quy định, có liên kết tới bản ghi vận hành. |
| Yêu cầu / ưu tiên | WEB-FR-DASH-01 (M), WEB-FR-DASH-02 (M), WEB-FR-DASH-03 (M), WEB-FR-DASH-04 (M) |
| Nghiệm thu | Thực hiện AC-01/AC-02 cho mọi FR liên quan với tác nhân đủ quyền. |

## 11. Yêu cầu giao diện bên ngoài

| Giao diện | Hợp đồng |
| --- | --- |
| Client/gateway | REST/JSON UTF-8; Accept application/json; Content-Type application/json khi có body; JWT Bearer cho lời gọi bảo vệ. Client không nối PostgreSQL hoặc cổng service riêng. |
| PayOS | URL thanh toán/VietQR qua backend; webhook có chữ ký; client xác minh server thay vì tin chuyển hướng. Client không thu thập dữ liệu thẻ. |
| SMTP / RabbitMQ | Chỉ server gửi OTP/vé/hoàn và sự kiện đã commit; client đọc API thông báo, không nhận broker. |
| Thiết bị/trình duyệt | Route hash/URL; camera HTTPS/localhost; chia sẻ/clipboard/lịch; in trình duyệt 80 mm; preview HTML dự phòng ảnh. |

## 12. Yêu cầu giao diện / Màn hình

Mã màn đại diện trang có route hoặc trang đầu vai trò. Lớp quét, sửa đánh giá, hộp hồ sơ/mật khẩu và đổi loại ghế là thành phần, không phải route tự thêm. Danh sách FR/API liên kết theo khu chức năng; mục 13 cung cấp hợp đồng endpoint chính xác.

### WEB-SCR-LOGIN — Đăng nhập

| Trường | Yêu cầu màn hình |
| --- | --- |
| Route | `/login` |
| Tác nhân | Khách chưa đăng nhập/mọi vai trò |
| Mục đích | Đăng nhập |
| Thành phần chính | Email, mật khẩu, lỗi trường, liên kết khôi phục/đăng ký |
| Thao tác | Đăng nhập; khôi phục mật khẩu; đăng ký trên trang khách |
| Điều hướng | Trang đầu theo vai trò hoặc đích chờ; /forgot-password; /register (chỉ trang khách) |
| FR liên quan | WEB-FR-AUTH-02, WEB-FR-AUTH-03, WEB-FR-AUTH-06, WEB-FR-AUTH-12, WEB-FR-AUTH-13, WEB-FR-NAV-01 |
| Khu API liên quan | WEB-API-027, WEB-API-029, WEB-API-032, WEB-API-033, WEB-API-035 |
| Nguồn | [Cinema_Mobile/lib/features/auth/screens/login_screen.dart](../Cinema_Mobile/lib/features/auth/screens/login_screen.dart) |

### WEB-SCR-REGISTER — Đăng ký

| Trường | Yêu cầu màn hình |
| --- | --- |
| Route | `/register` |
| Tác nhân | Khách chưa đăng nhập |
| Mục đích | Đăng ký |
| Thành phần chính | Tên, email, điện thoại, mật khẩu và xác nhận |
| Thao tác | Kiểm tra và đăng ký |
| Điều hướng | /login → /register → /verify-email |
| FR liên quan | WEB-FR-AUTH-01, WEB-FR-AUTH-08, WEB-FR-AUTH-13 |
| Khu API liên quan | WEB-API-027, WEB-API-033, WEB-API-035 |
| Nguồn | [Cinema_Mobile/lib/features/auth/screens/register_screen.dart](../Cinema_Mobile/lib/features/auth/screens/register_screen.dart) |

### WEB-SCR-VERIFY — Xác thực email

| Trường | Yêu cầu màn hình |
| --- | --- |
| Route | `/verify-email` |
| Tác nhân | Khách chưa đăng nhập |
| Mục đích | Xác thực email |
| Thành phần chính | Ô OTP; đếm ngược gửi lại; ngữ cảnh mật khẩu đã đăng ký |
| Thao tác | Xác thực hoặc gửi lại |
| Điều hướng | Đăng ký/đăng nhập → OTP → trang đầu theo vai trò |
| FR liên quan | WEB-FR-AUTH-07, WEB-FR-AUTH-08, WEB-FR-AUTH-14 |
| Khu API liên quan | WEB-API-027, WEB-API-032, WEB-API-033, WEB-API-034, WEB-API-042 |
| Nguồn | [Cinema_Mobile/lib/features/auth/screens/verify_email_screen.dart](../Cinema_Mobile/lib/features/auth/screens/verify_email_screen.dart) |

### WEB-SCR-FORGOT — Quên mật khẩu

| Trường | Yêu cầu màn hình |
| --- | --- |
| Route | `/forgot-password` |
| Tác nhân | Khách chưa đăng nhập/chủ tài khoản |
| Mục đích | Quên mật khẩu |
| Thành phần chính | Ô email và trạng thái gửi |
| Thao tác | Yêu cầu OTP đặt lại |
| Điều hướng | Đăng nhập/Hồ sơ → yêu cầu đặt lại → /reset-password |
| FR liên quan | WEB-FR-AUTH-09, WEB-FR-AUTH-13, WEB-FR-AUTH-14 |
| Khu API liên quan | WEB-API-026, WEB-API-027, WEB-API-032, WEB-API-033, WEB-API-034, WEB-API-035 |
| Nguồn | [Cinema_Mobile/lib/features/auth/screens/forgot_password_screen.dart](../Cinema_Mobile/lib/features/auth/screens/forgot_password_screen.dart) |

### WEB-SCR-RESET — Đặt lại mật khẩu

| Trường | Yêu cầu màn hình |
| --- | --- |
| Route | `/reset-password` |
| Tác nhân | Người nhận OTP |
| Mục đích | Đặt lại mật khẩu |
| Thành phần chính | OTP, mật khẩu mới và xác nhận |
| Thao tác | Đặt lại bằng mã email |
| Điều hướng | Quên mật khẩu → đặt lại → đăng nhập |
| FR liên quan | WEB-FR-AUTH-09, WEB-FR-AUTH-13, WEB-FR-AUTH-14 |
| Khu API liên quan | WEB-API-026, WEB-API-027, WEB-API-032, WEB-API-033, WEB-API-034, WEB-API-035 |
| Nguồn | [Cinema_Mobile/lib/features/auth/screens/reset_password_screen.dart](../Cinema_Mobile/lib/features/auth/screens/reset_password_screen.dart) |

### WEB-SCR-HOME — Trang chủ khách

| Trường | Yêu cầu màn hình |
| --- | --- |
| Route | `/home` |
| Tác nhân | Khách chưa đăng nhập/khách hàng |
| Mục đích | Trang chủ khách |
| Thành phần chính | Tab đang/sắp chiếu; tìm kiếm; lọc thể loại; thẻ phim; điều hướng tài khoản/thông báo |
| Thao tác | Tìm/lọc; mở phim |
| Điều hướng | /home → /movies/{id}; điều hướng khách tới vé, thanh toán, thông báo, hồ sơ |
| FR liên quan | WEB-FR-MOV-03, WEB-FR-MOV-04, WEB-FR-MOV-10, WEB-FR-NOTI-09, WEB-FR-MEDIA-01 |
| Khu API liên quan | WEB-API-064, WEB-API-066, WEB-API-067, WEB-API-069, WEB-API-072, WEB-API-076, WEB-API-077 |
| Nguồn | [Cinema_Mobile/lib/features/home/screens/home_screen.dart](../Cinema_Mobile/lib/features/home/screens/home_screen.dart) |

### WEB-SCR-MOVIE — Chi tiết phim

| Trường | Yêu cầu màn hình |
| --- | --- |
| Route | `/movies/{id}` |
| Tác nhân | Khách chưa đăng nhập/khách hàng |
| Mục đích | Chi tiết phim |
| Thành phần chính | Ảnh, tuổi, thông tin phim, diễn viên/đạo diễn, trailer, tổng hợp đánh giá, suất bảy ngày |
| Thao tác | Mở trailer; chọn suất; đọc đánh giá |
| Điều hướng | Trang chủ → phim → /showtimes/{id}/seats |
| FR liên quan | WEB-FR-MOV-02, WEB-FR-MOV-08, WEB-FR-MOV-09, WEB-FR-MOV-11, WEB-FR-MOV-12, WEB-FR-SHOW-03, WEB-FR-SHOW-06, WEB-FR-SHOW-07, WEB-FR-SHOW-08, WEB-FR-SHOW-13 |
| Khu API liên quan | WEB-API-017, WEB-API-020, WEB-API-064, WEB-API-102, WEB-API-103, WEB-API-105, WEB-API-106 |
| Nguồn | [Cinema_Mobile/lib/features/movie/screens/movie_detail_screen.dart](../Cinema_Mobile/lib/features/movie/screens/movie_detail_screen.dart) |

### WEB-SCR-SEATS — Chọn ghế

| Trường | Yêu cầu màn hình |
| --- | --- |
| Route | `/showtimes/{id}/seats` |
| Tác nhân | Khách hàng |
| Mục đích | Chọn ghế |
| Thành phần chính | Hàng, chú giải loại/đã chiếm, ghế chọn, giá cặp, tổng |
| Thao tác | Chọn/bỏ chọn ghế trống; làm mới |
| Điều hướng | Phim → ghế → /showtimes/{id}/summary |
| FR liên quan | WEB-FR-SEAT-03, WEB-FR-SHOW-03, WEB-FR-SHOW-13, WEB-FR-BOOK-07, WEB-FR-BOOK-08, WEB-FR-BOOK-09, WEB-FR-BOOK-11 |
| Khu API liên quan | WEB-API-013, WEB-API-017, WEB-API-049, WEB-API-055 |
| Nguồn | [Cinema_Mobile/lib/features/seat/screens/seat_selection_screen.dart](../Cinema_Mobile/lib/features/seat/screens/seat_selection_screen.dart) |

### WEB-SCR-SUMMARY — Xác nhận đặt vé

| Trường | Yêu cầu màn hình |
| --- | --- |
| Route | `/showtimes/{id}/summary` |
| Tác nhân | Khách hàng |
| Mục đích | Xác nhận đặt vé |
| Thành phần chính | BookingDraft, ghế, chọn bắp nước, báo giá khuyến mãi, điểm, xác nhận tuổi |
| Thao tác | Đổi phần thêm; giữ ghế |
| Điều hướng | Ghế → xác nhận → thanh toán vé; thiếu dữ liệu tạm → ghế |
| FR liên quan | WEB-FR-MOV-09, WEB-FR-BOOK-01, WEB-FR-BOOK-09, WEB-FR-BOOK-13, WEB-FR-BOOK-15, WEB-FR-BOOK-17 |
| Khu API liên quan | WEB-API-055, WEB-API-057, WEB-API-060, WEB-API-064, WEB-API-099 |
| Nguồn | [Cinema_Mobile/lib/features/booking/screens/booking_summary_screen.dart](../Cinema_Mobile/lib/features/booking/screens/booking_summary_screen.dart) |

### WEB-SCR-PAYMENT — Thanh toán

| Trường | Yêu cầu màn hình |
| --- | --- |
| Route | `/bookings/{id}/payment` |
| Tác nhân | Khách hàng |
| Mục đích | Thanh toán |
| Thành phần chính | Vé/chi tiết tiền; đếm ngược; link PayOS; tự kiểm tra |
| Thao tác | Mở/tiếp tục PayOS; trở về và đối soát |
| Điều hướng | Xác nhận/vé → thanh toán → PayOS ngoài → kết quả |
| FR liên quan | WEB-FR-BOOK-05, WEB-FR-BOOK-10, WEB-FR-PAY-01, WEB-FR-PAY-02, WEB-FR-PAY-11 |
| Khu API liên quan | WEB-API-046, WEB-API-087, WEB-API-088 |
| Nguồn | [Cinema_Mobile/lib/features/payment/screens/payment_screen.dart](../Cinema_Mobile/lib/features/payment/screens/payment_screen.dart) |

### WEB-SCR-RESULT — Kết quả thanh toán

| Trường | Yêu cầu màn hình |
| --- | --- |
| Route | `/bookings/{id}/result` |
| Tác nhân | Khách hàng |
| Mục đích | Kết quả thanh toán |
| Thành phần chính | Xác minh/đang tải, kết quả thành công/chờ/thất bại |
| Thao tác | Tải lại kết quả server; mở vé |
| Điều hướng | PayOS/thanh toán → kết quả → /bookings/{id} |
| FR liên quan | WEB-FR-BOOK-02, WEB-FR-BOOK-05, WEB-FR-PAY-02, WEB-FR-PAY-08 |
| Khu API liên quan | WEB-API-046, WEB-API-087 |
| Nguồn | [Cinema_Mobile/lib/features/payment/screens/payment_result_screen.dart](../Cinema_Mobile/lib/features/payment/screens/payment_result_screen.dart) |

### WEB-SCR-TICKETS — Vé của tôi

| Trường | Yêu cầu màn hình |
| --- | --- |
| Route | `/bookings` |
| Tác nhân | Khách hàng |
| Mục đích | Vé của tôi |
| Thành phần chính | Tab vé hiện tại/lịch sử, thẻ vé, làm mới và trạng thái rỗng/lỗi |
| Thao tác | Mở vé; làm mới |
| Điều hướng | Điều hướng khách → vé → /bookings/{id} |
| FR liên quan | WEB-FR-BOOK-04 |
| Khu API liên quan | WEB-API-053 |
| Nguồn | [Cinema_Mobile/lib/features/booking/screens/my_bookings_screen.dart](../Cinema_Mobile/lib/features/booking/screens/my_bookings_screen.dart) |

### WEB-SCR-TICKET — Chi tiết vé

| Trường | Yêu cầu màn hình |
| --- | --- |
| Route | `/bookings/{id}` |
| Tác nhân | Khách hàng |
| Mục đích | Chi tiết vé |
| Thành phần chính | Ghế, phần thêm, tiền, QR, checkedInAt, huỷ/hoàn, đánh giá và chia sẻ/lịch |
| Thao tác | Trả vé chờ; huỷ/yêu cầu hoàn; đánh giá sau check-in; chia sẻ/lịch |
| Điều hướng | Vé/thông báo → chi tiết → thanh toán hoặc quay lại |
| FR liên quan | WEB-FR-MOV-12, WEB-FR-BOOK-02, WEB-FR-BOOK-05, WEB-FR-BOOK-06, WEB-FR-BOOK-13, WEB-FR-BOOK-15, WEB-FR-BOOK-17, WEB-FR-BOOK-19, WEB-FR-PAY-03, WEB-FR-PAY-06, WEB-FR-REF-01, WEB-FR-REF-05, WEB-FR-REF-06, WEB-FR-CHK-01, WEB-FR-CHK-05 |
| Khu API liên quan | WEB-API-017, WEB-API-043, WEB-API-046, WEB-API-055, WEB-API-057, WEB-API-060, WEB-API-082, WEB-API-087, WEB-API-099, WEB-API-102, WEB-API-103, WEB-API-105, WEB-API-106 |
| Nguồn | [Cinema_Mobile/lib/features/booking/screens/booking_detail_screen.dart](../Cinema_Mobile/lib/features/booking/screens/booking_detail_screen.dart) |

### WEB-SCR-PAYHISTORY — Lịch sử thanh toán

| Trường | Yêu cầu màn hình |
| --- | --- |
| Route | `/payments` |
| Tác nhân | Khách hàng |
| Mục đích | Lịch sử thanh toán |
| Thành phần chính | Dòng giao dịch của mình, số tiền, trạng thái |
| Thao tác | Làm mới; xem vé liên quan khi có |
| Điều hướng | Điều hướng khách → thanh toán → vé liên quan |
| FR liên quan | WEB-FR-PAY-03, WEB-FR-PAY-04 |
| Khu API liên quan | WEB-API-095 |
| Nguồn | [Cinema_Mobile/lib/features/payment/screens/payment_history_screen.dart](../Cinema_Mobile/lib/features/payment/screens/payment_history_screen.dart) |

### WEB-SCR-NOTIFICATIONS — Thông báo

| Trường | Yêu cầu màn hình |
| --- | --- |
| Route | `/notifications` |
| Tác nhân | Khách hàng |
| Mục đích | Thông báo |
| Thành phần chính | Danh sách thông báo, số chưa đọc, đánh dấu tất cả |
| Thao tác | Mở thông báo; đánh dấu tất cả |
| Điều hướng | Chuông/điều hướng khách → /notifications/{id} |
| FR liên quan | WEB-FR-NOTI-01, WEB-FR-NOTI-09 |
| Khu API liên quan | WEB-API-072, WEB-API-076, WEB-API-077, WEB-API-078 |
| Nguồn | [Cinema_Mobile/lib/features/notification/screens/notification_list_screen.dart](../Cinema_Mobile/lib/features/notification/screens/notification_list_screen.dart) |

### WEB-SCR-NOTIFICATION — Chi tiết thông báo

| Trường | Yêu cầu màn hình |
| --- | --- |
| Route | `/notifications/{id}` |
| Tác nhân | Khách hàng |
| Mục đích | Chi tiết thông báo |
| Thành phần chính | Tiêu đề, nội dung, trạng thái đọc, vé liên quan |
| Thao tác | Đánh dấu khi mở; mở vé |
| Điều hướng | Thông báo → chi tiết → /bookings/{id} |
| FR liên quan | WEB-FR-NOTI-04, WEB-FR-NOTI-09 |
| Khu API liên quan | WEB-API-072, WEB-API-075, WEB-API-076, WEB-API-077 |
| Nguồn | [Cinema_Mobile/lib/features/notification/screens/notification_detail_screen.dart](../Cinema_Mobile/lib/features/notification/screens/notification_detail_screen.dart) |

### WEB-SCR-PROFILE — Tài khoản và thành viên

| Trường | Yêu cầu màn hình |
| --- | --- |
| Route | `/profile` |
| Tác nhân | Khách hàng |
| Mục đích | Tài khoản và thành viên |
| Thành phần chính | Danh tính, hộp sửa hồ sơ/mật khẩu, thẻ/lịch sử thành viên, đăng xuất |
| Thao tác | Sửa tên/điện thoại; đổi/khôi phục mật khẩu; đăng xuất |
| Điều hướng | Điều hướng khách → hồ sơ; khôi phục mật khẩu → quên/đặt lại |
| FR liên quan | WEB-FR-AUTH-10, WEB-FR-AUTH-11, WEB-FR-AUTH-16, WEB-FR-AUTH-17, WEB-FR-BOOK-17 |
| Khu API liên quan | WEB-API-025, WEB-API-028, WEB-API-029, WEB-API-031, WEB-API-032, WEB-API-055, WEB-API-060 |
| Nguồn | [Cinema_Mobile/lib/features/profile/screens/profile_screen.dart](../Cinema_Mobile/lib/features/profile/screens/profile_screen.dart) |

### WEB-SCR-CHECKIN — Check-in vé

| Trường | Yêu cầu màn hình |
| --- | --- |
| Route | `/staff/check-in` |
| Tác nhân | Nhân viên/quản trị viên |
| Mục đích | Check-in vé |
| Thành phần chính | Ô mã; lớp quét camera; chi tiết vé; nhắc tuổi; nút cho vào |
| Thao tác | Quét/nhập; tra vé; check-in một lần |
| Điều hướng | Trang đầu/điều hướng quản lý → check-in → vé kế tiếp |
| FR liên quan | WEB-FR-MOV-09, WEB-FR-CHK-02, WEB-FR-CHK-03, WEB-FR-CHK-04, WEB-FR-CHK-05 |
| Khu API liên quan | WEB-API-044, WEB-API-046, WEB-API-047, WEB-API-050, WEB-API-064, WEB-API-065, WEB-API-071 |
| Nguồn | [Cinema_Mobile/lib/features/staff/screens/staff_check_in_screen.dart](../Cinema_Mobile/lib/features/staff/screens/staff_check_in_screen.dart) |

### WEB-SCR-STAFF-DASH — Tổng quan nhân viên

| Trường | Yêu cầu màn hình |
| --- | --- |
| Route | `/staff/dashboard` |
| Tác nhân | Nhân viên/quản trị viên |
| Mục đích | Tổng quan nhân viên |
| Thành phần chính | Tổng hôm nay, bảng suất, vé/hoàn tiền chờ |
| Thao tác | Mở vận hành; bán vé; check-in |
| Điều hướng | Đăng nhập → tổng quan → vận hành/quầy/check-in |
| FR liên quan | WEB-FR-DASH-01, WEB-FR-DASH-02, WEB-FR-DASH-03 |
| Khu API liên quan | WEB-API-019, WEB-API-048, WEB-API-051, WEB-API-052, WEB-API-093 |
| Nguồn | [Cinema_Mobile/lib/features/staff/screens/staff_dashboard_screen.dart](../Cinema_Mobile/lib/features/staff/screens/staff_dashboard_screen.dart) |

### WEB-SCR-ADMIN-DASH — Tổng quan quản trị

| Trường | Yêu cầu màn hình |
| --- | --- |
| Route | `/admin/dashboard` |
| Tác nhân | Quản trị viên |
| Mục đích | Tổng quan quản trị |
| Thành phần chính | Doanh thu/hoàn tháng, hôm nay, thẻ phim và tài khoản |
| Thao tác | Mở khu quản lý liên quan |
| Điều hướng | Đăng nhập → tổng quan → quản trị/vận hành |
| FR liên quan | WEB-FR-DASH-01, WEB-FR-DASH-02, WEB-FR-DASH-04 |
| Khu API liên quan | WEB-API-019, WEB-API-040, WEB-API-048, WEB-API-051, WEB-API-069, WEB-API-094 |
| Nguồn | [Cinema_Mobile/lib/features/admin/screens/admin_dashboard_screen.dart](../Cinema_Mobile/lib/features/admin/screens/admin_dashboard_screen.dart) |

### WEB-SCR-OPERATIONS — Không gian vận hành

| Trường | Yêu cầu màn hình |
| --- | --- |
| Route | `/staff/operations` |
| Tác nhân | Nhân viên/quản trị viên |
| Mục đích | Không gian vận hành |
| Thành phần chính | Tab vé/suất/phòng/thanh toán/hoàn tiền; lọc; phân trang |
| Thao tác | Lọc; mở bản ghi; bán vé; tạo suất |
| Điều hướng | Điều hướng → vận hành → bản ghi/bán vé/tạo suất |
| FR liên quan | WEB-FR-ROOM-01, WEB-FR-SHOW-01, WEB-FR-SHOW-09, WEB-FR-BOOK-03, WEB-FR-BOOK-12, WEB-FR-PAY-09, WEB-FR-REF-02 |
| Khu API liên quan | WEB-API-004, WEB-API-005, WEB-API-019, WEB-API-023, WEB-API-048, WEB-API-051, WEB-API-052, WEB-API-054, WEB-API-087, WEB-API-092, WEB-API-093, WEB-API-096 |
| Nguồn | [Cinema_Mobile/lib/features/staff/screens/staff_operations_screen.dart](../Cinema_Mobile/lib/features/staff/screens/staff_operations_screen.dart) |

### WEB-SCR-COUNTER — Đặt vé quầy

| Trường | Yêu cầu màn hình |
| --- | --- |
| Route | `/staff/bookings/new` |
| Tác nhân | Nhân viên/quản trị viên |
| Mục đích | Đặt vé quầy |
| Thành phần chính | Chọn vãng lai/thành viên, tìm điện thoại, phim/ngày/suất/sơ đồ, phần thêm |
| Thao tác | Chọn người mua/ghế; báo giá; giữ chỗ |
| Điều hướng | Tổng quan/vận hành → quầy → thu tiền |
| FR liên quan | WEB-FR-AUTH-15, WEB-FR-BOOK-13, WEB-FR-BOOK-15, WEB-FR-BOOK-17, WEB-FR-POS-01 |
| Khu API liên quan | WEB-API-013, WEB-API-023, WEB-API-030, WEB-API-055, WEB-API-057, WEB-API-060, WEB-API-099 |
| Nguồn | [Cinema_Mobile/lib/features/staff/screens/staff_create_booking_screen.dart](../Cinema_Mobile/lib/features/staff/screens/staff_create_booking_screen.dart) |

### WEB-SCR-CHECKOUT — Thu tiền quầy

| Trường | Yêu cầu màn hình |
| --- | --- |
| Route | `/staff/bookings/{id}/checkout` |
| Tác nhân | Nhân viên/quản trị viên |
| Mục đích | Thu tiền quầy |
| Thành phần chính | Đếm ngược, email, tiền mặt/thối, VietQR, QR đã trả/in |
| Thao tác | Thu tiền mặt; xác minh chuyển khoản; in; cho vào; bán tiếp |
| Điều hướng | Quầy/chi tiết vé → thu tiền → in/check-in/bán tiếp |
| FR liên quan | WEB-FR-PAY-01, WEB-FR-PAY-02, WEB-FR-POS-02, WEB-FR-POS-03, WEB-FR-POS-04, WEB-FR-POS-05, WEB-FR-POS-06, WEB-FR-POS-07, WEB-FR-POS-08, WEB-FR-CHK-01, WEB-FR-CHK-03 |
| Khu API liên quan | WEB-API-044, WEB-API-046, WEB-API-055, WEB-API-086, WEB-API-087, WEB-API-088 |
| Nguồn | [Cinema_Mobile/lib/features/staff/screens/staff_counter_checkout_screen.dart](../Cinema_Mobile/lib/features/staff/screens/staff_counter_checkout_screen.dart) |

### WEB-SCR-RECORD-BOOKINGS — Bản ghi vé

| Trường | Yêu cầu màn hình |
| --- | --- |
| Route | `/staff/bookings/{id}` |
| Tác nhân | Nhân viên/quản trị viên |
| Mục đích | Bản ghi vé |
| Thành phần chính | Vé, thanh toán, khách và thao tác |
| Thao tác | Xem và thực hiện thao tác bản ghi đủ quyền |
| Điều hướng | Vận hành → bản ghi → bản ghi liên quan hoặc sửa |
| FR liên quan | WEB-FR-BOOK-02, WEB-FR-BOOK-06, WEB-FR-POS-08, WEB-FR-CHK-05 |
| Khu API liên quan | WEB-API-043, WEB-API-046, WEB-API-050 |
| Nguồn | [Cinema_Mobile/lib/features/staff/screens/staff_record_screen.dart](../Cinema_Mobile/lib/features/staff/screens/staff_record_screen.dart) |

### WEB-SCR-RECORD-PAYMENTS — Bản ghi thanh toán

| Trường | Yêu cầu màn hình |
| --- | --- |
| Route | `/staff/payments/{id}` |
| Tác nhân | Nhân viên/quản trị viên |
| Mục đích | Bản ghi thanh toán |
| Thành phần chính | Tiền, phương thức, trạng thái, xác minh và hoàn tiền |
| Thao tác | Xem và thực hiện thao tác bản ghi đủ quyền |
| Điều hướng | Vận hành → bản ghi → bản ghi liên quan hoặc sửa |
| FR liên quan | WEB-FR-PAY-03, WEB-FR-PAY-05, WEB-FR-PAY-09, WEB-FR-REF-06 |
| Khu API liên quan | WEB-API-082, WEB-API-084, WEB-API-085, WEB-API-087, WEB-API-096 |
| Nguồn | [Cinema_Mobile/lib/features/staff/screens/staff_record_screen.dart](../Cinema_Mobile/lib/features/staff/screens/staff_record_screen.dart) |

### WEB-SCR-RECORD-REFUNDS — Bản ghi hoàn tiền

| Trường | Yêu cầu màn hình |
| --- | --- |
| Route | `/staff/refunds/{id}` |
| Tác nhân | Nhân viên/quản trị viên |
| Mục đích | Bản ghi hoàn tiền |
| Thành phần chính | Ngân hàng người trả, lý do, trạng thái, mã chuyển |
| Thao tác | Xem và thực hiện thao tác bản ghi đủ quyền |
| Điều hướng | Vận hành → bản ghi → bản ghi liên quan hoặc sửa |
| FR liên quan | WEB-FR-REF-02, WEB-FR-REF-03, WEB-FR-REF-04, WEB-FR-REF-05, WEB-FR-REF-07 |
| Khu API liên quan | WEB-API-016, WEB-API-043, WEB-API-082, WEB-API-090, WEB-API-091, WEB-API-092, WEB-API-093 |
| Nguồn | [Cinema_Mobile/lib/features/staff/screens/staff_record_screen.dart](../Cinema_Mobile/lib/features/staff/screens/staff_record_screen.dart) |

### WEB-SCR-RECORD-SHOWTIMES — Bản ghi suất chiếu

| Trường | Yêu cầu màn hình |
| --- | --- |
| Route | `/staff/showtimes/{id}` |
| Tác nhân | Nhân viên/quản trị viên |
| Mục đích | Bản ghi suất chiếu |
| Thành phần chính | Lịch, sơ đồ tình trạng ghế, danh sách khách |
| Thao tác | Xem và thực hiện thao tác bản ghi đủ quyền |
| Điều hướng | Vận hành → bản ghi → bản ghi liên quan hoặc sửa |
| FR liên quan | WEB-FR-SHOW-03, WEB-FR-SHOW-05, WEB-FR-SHOW-10, WEB-FR-SHOW-12, WEB-FR-BOOK-12 |
| Khu API liên quan | WEB-API-013, WEB-API-015, WEB-API-016, WEB-API-017, WEB-API-050, WEB-API-051 |
| Nguồn | [Cinema_Mobile/lib/features/staff/screens/staff_record_screen.dart](../Cinema_Mobile/lib/features/staff/screens/staff_record_screen.dart) |

### WEB-SCR-RECORD-ROOMS — Bản ghi phòng

| Trường | Yêu cầu màn hình |
| --- | --- |
| Route | `/staff/rooms/{id}` |
| Tác nhân | Nhân viên/quản trị viên |
| Mục đích | Bản ghi phòng |
| Thành phần chính | Thông tin phòng, sơ đồ/đổi loại ghế và sức chứa |
| Thao tác | Xem và thực hiện thao tác bản ghi đủ quyền |
| Điều hướng | Vận hành → bản ghi → bản ghi liên quan hoặc sửa |
| FR liên quan | WEB-FR-ROOM-02, WEB-FR-SEAT-01, WEB-FR-SEAT-02, WEB-FR-SEAT-03, WEB-FR-SEAT-05, WEB-FR-SEAT-06, WEB-FR-SEAT-07, WEB-FR-SEAT-08, WEB-FR-SEAT-09 |
| Khu API liên quan | WEB-API-002, WEB-API-007, WEB-API-009, WEB-API-010, WEB-API-011, WEB-API-012, WEB-API-013 |
| Nguồn | [Cinema_Mobile/lib/features/staff/screens/staff_record_screen.dart](../Cinema_Mobile/lib/features/staff/screens/staff_record_screen.dart) |

### WEB-SCR-SHOW-EDITOR — Sửa suất chiếu

| Trường | Yêu cầu màn hình |
| --- | --- |
| Route | `/staff/showtimes/new; /staff/showtimes/{id}/edit` |
| Tác nhân | Nhân viên/quản trị viên |
| Mục đích | Sửa suất chiếu |
| Thành phần chính | Phim, phòng, giờ, định dạng, giá gốc, trạng thái |
| Thao tác | Kiểm tra và lưu |
| Điều hướng | Vận hành/bản ghi suất → sửa → bản ghi |
| FR liên quan | WEB-FR-SHOW-02, WEB-FR-SHOW-04, WEB-FR-SHOW-11, WEB-FR-SHOW-13 |
| Khu API liên quan | WEB-API-017, WEB-API-018, WEB-API-024 |
| Nguồn | [Cinema_Mobile/lib/features/staff/screens/staff_showtime_editor_screen.dart](../Cinema_Mobile/lib/features/staff/screens/staff_showtime_editor_screen.dart) |

### WEB-SCR-COMPOSE — Soạn email cho vé

| Trường | Yêu cầu màn hình |
| --- | --- |
| Route | `/staff/bookings/{id}/notify` |
| Tác nhân | Nhân viên/quản trị viên |
| Mục đích | Soạn email cho vé |
| Thành phần chính | Email người nhận, tiêu đề, nội dung, kết quả gửi |
| Thao tác | Tạo và gửi/thử lại |
| Điều hướng | Bản ghi vé → thông báo → bản ghi |
| FR liên quan | WEB-FR-NOTI-02, WEB-FR-NOTI-03 |
| Khu API liên quan | WEB-API-073, WEB-API-080 |
| Nguồn | [Cinema_Mobile/lib/features/staff/screens/staff_notification_screen.dart](../Cinema_Mobile/lib/features/staff/screens/staff_notification_screen.dart) |

### WEB-SCR-ADMIN-MOVIES — Phim

| Trường | Yêu cầu màn hình |
| --- | --- |
| Route | `/admin/movies` |
| Tác nhân | Quản trị viên |
| Mục đích | Phim |
| Thành phần chính | Tìm, trạng thái, sửa phim, hộp đánh giá |
| Thao tác | Tạo/sửa; dừng/chiếu lại; kiểm duyệt |
| Điều hướng | Điều hướng quản trị → danh sách → sửa/chi tiết |
| FR liên quan | WEB-FR-MOV-01, WEB-FR-MOV-02, WEB-FR-MOV-03, WEB-FR-MOV-04, WEB-FR-MOV-05, WEB-FR-MOV-06, WEB-FR-MOV-07, WEB-FR-MOV-09, WEB-FR-MOV-11, WEB-FR-MOV-12 |
| Khu API liên quan | WEB-API-063, WEB-API-064, WEB-API-065, WEB-API-066, WEB-API-068, WEB-API-069, WEB-API-070, WEB-API-071, WEB-API-102, WEB-API-103, WEB-API-105, WEB-API-106 |
| Nguồn | [Cinema_Mobile/lib/features/admin/screens/admin_movies_screen.dart](../Cinema_Mobile/lib/features/admin/screens/admin_movies_screen.dart) |

### WEB-SCR-ADMIN-ROOMS — Phòng

| Trường | Yêu cầu màn hình |
| --- | --- |
| Route | `/admin/rooms` |
| Tác nhân | Quản trị viên |
| Mục đích | Phòng |
| Thành phần chính | Danh sách, hộp tạo/đổi tên, liên kết sơ đồ |
| Thao tác | Tạo/đổi tên/xoá; mở sơ đồ |
| Điều hướng | Điều hướng quản trị → danh sách → sửa/chi tiết |
| FR liên quan | WEB-FR-ROOM-01, WEB-FR-ROOM-02, WEB-FR-ROOM-03, WEB-FR-ROOM-04, WEB-FR-ROOM-05 |
| Khu API liên quan | WEB-API-001, WEB-API-002, WEB-API-003, WEB-API-004, WEB-API-005, WEB-API-006, WEB-API-010, WEB-API-013 |
| Nguồn | [Cinema_Mobile/lib/features/admin/screens/admin_rooms_screen.dart](../Cinema_Mobile/lib/features/admin/screens/admin_rooms_screen.dart) |

### WEB-SCR-ADMIN-SNACKS — Bắp nước

| Trường | Yêu cầu màn hình |
| --- | --- |
| Route | `/admin/snacks` |
| Tác nhân | Quản trị viên |
| Mục đích | Bắp nước |
| Thành phần chính | Sửa món, giá, bật/tắt bán |
| Thao tác | Tạo/sửa; dừng/bán lại |
| Điều hướng | Điều hướng quản trị → danh sách → sửa/chi tiết |
| FR liên quan | WEB-FR-BOOK-14 |
| Khu API liên quan | WEB-API-056, WEB-API-057, WEB-API-058 |
| Nguồn | [Cinema_Mobile/lib/features/admin/screens/admin_snacks_screen.dart](../Cinema_Mobile/lib/features/admin/screens/admin_snacks_screen.dart) |

### WEB-SCR-ADMIN-PROMOTIONS — Khuyến mãi

| Trường | Yêu cầu màn hình |
| --- | --- |
| Route | `/admin/promotions` |
| Tác nhân | Quản trị viên |
| Mục đích | Khuyến mãi |
| Thành phần chính | Mã/tự áp dụng, thời gian, giới hạn, lượt dùng |
| Thao tác | Tạo/sửa; tạm dừng/chạy lại |
| Điều hướng | Điều hướng quản trị → danh sách → sửa/chi tiết |
| FR liên quan | WEB-FR-BOOK-16 |
| Khu API liên quan | WEB-API-098, WEB-API-100, WEB-API-101 |
| Nguồn | [Cinema_Mobile/lib/features/admin/screens/admin_promotions_screen.dart](../Cinema_Mobile/lib/features/admin/screens/admin_promotions_screen.dart) |

### WEB-SCR-ADMIN-MEMBERS — Thành viên

| Trường | Yêu cầu màn hình |
| --- | --- |
| Route | `/admin/members` |
| Tác nhân | Quản trị viên |
| Mục đích | Thành viên |
| Thành phần chính | Danh sách khách, điểm/hạng/chi tiêu, hộp lịch sử/điều chỉnh |
| Thao tác | Tìm thành viên; điều chỉnh kèm lý do |
| Điều hướng | Điều hướng quản trị → danh sách → sửa/chi tiết |
| FR liên quan | WEB-FR-BOOK-18 |
| Khu API liên quan | WEB-API-030, WEB-API-059, WEB-API-061, WEB-API-062 |
| Nguồn | [Cinema_Mobile/lib/features/admin/screens/admin_members_screen.dart](../Cinema_Mobile/lib/features/admin/screens/admin_members_screen.dart) |

### WEB-SCR-ADMIN-USERS — Tài khoản

| Trường | Yêu cầu màn hình |
| --- | --- |
| Route | `/admin/users` |
| Tác nhân | Quản trị viên |
| Mục đích | Tài khoản |
| Thành phần chính | Tìm, lọc vai trò/trạng thái, phân trang |
| Thao tác | Liệt kê; tạo; mở tài khoản |
| Điều hướng | Điều hướng quản trị → danh sách → sửa/chi tiết |
| FR liên quan | WEB-FR-USER-01, WEB-FR-USER-06 |
| Khu API liên quan | WEB-API-036, WEB-API-040 |
| Nguồn | [Cinema_Mobile/lib/features/admin/screens/admin_users_screen.dart](../Cinema_Mobile/lib/features/admin/screens/admin_users_screen.dart) |

### WEB-SCR-USER-EDITOR — Tạo/chi tiết tài khoản

| Trường | Yêu cầu màn hình |
| --- | --- |
| Route | `/admin/users/new; /admin/users/{id}` |
| Tác nhân | Quản trị viên |
| Mục đích | Tạo/chi tiết tài khoản |
| Thành phần chính | Trường danh tính, vai trò, trạng thái |
| Thao tác | Tạo; đổi vai trò; khoá/mở |
| Điều hướng | Tài khoản → tạo/chi tiết → tài khoản |
| FR liên quan | WEB-FR-AUTH-13, WEB-FR-USER-02, WEB-FR-USER-03, WEB-FR-USER-04, WEB-FR-USER-05, WEB-FR-USER-06 |
| Khu API liên quan | WEB-API-027, WEB-API-033, WEB-API-035, WEB-API-036, WEB-API-037, WEB-API-038, WEB-API-039, WEB-API-041 |
| Nguồn | [Cinema_Mobile/lib/features/admin/screens/admin_users_screen.dart](../Cinema_Mobile/lib/features/admin/screens/admin_users_screen.dart) |

### WEB-SCR-MGT-PROFILE — Hồ sơ quản lý

| Trường | Yêu cầu màn hình |
| --- | --- |
| Route | `/staff/profile; /admin/profile` |
| Tác nhân | Nhân viên/quản trị viên |
| Mục đích | Hồ sơ quản lý |
| Thành phần chính | Danh tính, hộp sửa/mật khẩu, đăng xuất |
| Thao tác | Sửa hồ sơ mình; đổi mật khẩu; đăng xuất |
| Điều hướng | Điều hướng → hồ sơ → xác thực |
| FR liên quan | WEB-FR-AUTH-10, WEB-FR-AUTH-11, WEB-FR-AUTH-16, WEB-FR-AUTH-17 |
| Khu API liên quan | WEB-API-025, WEB-API-028, WEB-API-029, WEB-API-031, WEB-API-032 |
| Nguồn | [Cinema_Mobile/lib/features/profile/screens/profile_screen.dart](../Cinema_Mobile/lib/features/profile/screens/profile_screen.dart) |

### WEB-SCR-STAFF-ONLY — Thông báo quyền quản lý

| Trường | Yêu cầu màn hình |
| --- | --- |
| Route | `/home (Customer in admin site)` |
| Tác nhân | Khách hàng |
| Mục đích | Thông báo quyền quản lý |
| Thành phần chính | Giải thích vai trò và liên kết trang khách |
| Thao tác | Mở trang khách; đăng xuất |
| Điều hướng | Khách đăng nhập cổng quản trị → thông báo → trang khách |
| FR liên quan | WEB-FR-AUTH-05, WEB-FR-NAV-01 |
| Khu API liên quan | WEB-API-029 |
| Nguồn | [Cinema_Mobile/lib/features/admin/screens/staff_only_screen.dart](../Cinema_Mobile/lib/features/admin/screens/staff_only_screen.dart) |

Màn xác thực web dùng lại giữa hai điểm vào nhưng đăng nhập quản trị tắt đăng ký. Sửa hồ sơ/đổi mật khẩu là hộp thoại. Trang đầu quản lý điện thoại chọn theo vai trò, không phải URL quản trị riêng.

## 13. Yêu cầu API

Endpoint được trích từ thuộc tính HTTP controller, chỉ bỏ ràng buộc :long trong ký hiệu tham số. Client gọi trực tiếp nghĩa là tìm thấy phương thức/đường dẫn khớp trong service Dart theo phạm vi; chỉ API/chung nghĩa là có controller nhưng chưa thấy lời gọi client riêng. Policy controller phải kết hợp gateway và chủ bản ghi.

| ID | Phương thức / endpoint | Policy controller | Hợp đồng đầu vào | Cách dùng / trạng thái | Bằng chứng |
| --- | --- | --- | --- | --- | --- |
| WEB-API-001 | `DELETE /api/rooms/{roomId}` | Policy = AuthorizationPolicies.AdminOnly | — | Client gọi trực tiếp; đã triển khai | [Cinema_BE/MovieService/MovieService/Controllers/RoomsController.cs:80](../Cinema_BE/MovieService/MovieService/Controllers/RoomsController.cs#L80) |
| WEB-API-002 | `GET /api/rooms/{roomId}` | Policy = AuthorizationPolicies.StaffOrAdmin | — | Client gọi trực tiếp; đã triển khai | [Cinema_BE/MovieService/MovieService/Controllers/RoomsController.cs:41](../Cinema_BE/MovieService/MovieService/Controllers/RoomsController.cs#L41) |
| WEB-API-003 | `PUT /api/rooms/{roomId}` | Policy = AuthorizationPolicies.AdminOnly | Body: RoomRequest request | Client gọi trực tiếp; đã triển khai | [Cinema_BE/MovieService/MovieService/Controllers/RoomsController.cs:67](../Cinema_BE/MovieService/MovieService/Controllers/RoomsController.cs#L67) |
| WEB-API-004 | `GET /api/rooms/search` | Policy = AuthorizationPolicies.StaffOrAdmin | Query: string keyword; Query: int pageNumber; Query: int pageSize; Query: string sortBy; Query: string sortDir | Backend chung/chỉ API; đã triển khai | [Cinema_BE/MovieService/MovieService/Controllers/RoomsController.cs:91](../Cinema_BE/MovieService/MovieService/Controllers/RoomsController.cs#L91) |
| WEB-API-005 | `GET /api/rooms` | Policy = AuthorizationPolicies.StaffOrAdmin | Query: int pageNumber; Query: int pageSize; Query: string sortBy; Query: string sortDir | Backend chung/chỉ API; đã triển khai | [Cinema_BE/MovieService/MovieService/Controllers/RoomsController.cs:24](../Cinema_BE/MovieService/MovieService/Controllers/RoomsController.cs#L24) |
| WEB-API-006 | `POST /api/rooms` | Policy = AuthorizationPolicies.AdminOnly | Body: RoomRequest request | Client gọi trực tiếp; đã triển khai | [Cinema_BE/MovieService/MovieService/Controllers/RoomsController.cs:52](../Cinema_BE/MovieService/MovieService/Controllers/RoomsController.cs#L52) |
| WEB-API-007 | `PUT /api/seats/{seatId}/type` | Policy = AuthorizationPolicies.StaffOrAdmin | Body: UpdateSeatTypeRequest request | Client gọi trực tiếp; đã triển khai | [Cinema_BE/MovieService/MovieService/Controllers/SeatsController.cs:60](../Cinema_BE/MovieService/MovieService/Controllers/SeatsController.cs#L60) |
| WEB-API-008 | `DELETE /api/seats/{seatId}` | Policy = AuthorizationPolicies.AdminOnly | — | Backend chung/chỉ API; đã triển khai | [Cinema_BE/MovieService/MovieService/Controllers/SeatsController.cs:101](../Cinema_BE/MovieService/MovieService/Controllers/SeatsController.cs#L101) |
| WEB-API-009 | `GET /api/seats/{seatId}` | Policy = AuthorizationPolicies.StaffOrAdmin | — | Client gọi trực tiếp; đã triển khai | [Cinema_BE/MovieService/MovieService/Controllers/SeatsController.cs:23](../Cinema_BE/MovieService/MovieService/Controllers/SeatsController.cs#L23) |
| WEB-API-010 | `POST /api/seats/generate` | Policy = AuthorizationPolicies.StaffOrAdmin | Body: GenerateSeatRequest request | Client gọi trực tiếp; đã triển khai | [Cinema_BE/MovieService/MovieService/Controllers/SeatsController.cs:48](../Cinema_BE/MovieService/MovieService/Controllers/SeatsController.cs#L48) |
| WEB-API-011 | `PUT /api/seats/room/{roomId}/capacity` | Policy = AuthorizationPolicies.AdminOnly | Body: UpdateRoomSeatsRequest request | Client gọi trực tiếp; đã triển khai | [Cinema_BE/MovieService/MovieService/Controllers/SeatsController.cs:88](../Cinema_BE/MovieService/MovieService/Controllers/SeatsController.cs#L88) |
| WEB-API-012 | `PUT /api/seats/room/{roomId}/types` | Policy = AuthorizationPolicies.StaffOrAdmin | Body: UpdateSeatTypeRequest request | Client gọi trực tiếp; đã triển khai | [Cinema_BE/MovieService/MovieService/Controllers/SeatsController.cs:74](../Cinema_BE/MovieService/MovieService/Controllers/SeatsController.cs#L74) |
| WEB-API-013 | `GET /api/seats/room/{roomId}` | authenticated | — | Client gọi trực tiếp; đã triển khai | [Cinema_BE/MovieService/MovieService/Controllers/SeatsController.cs:36](../Cinema_BE/MovieService/MovieService/Controllers/SeatsController.cs#L36) |
| WEB-API-014 | `POST /api/showtimes/{showtimeId}/seats` | authenticated | Body: List<long> seatIds | Backend chung/chỉ API; đã triển khai | [Cinema_BE/MovieService/MovieService/Controllers/ShowtimesController.cs:55](../Cinema_BE/MovieService/MovieService/Controllers/ShowtimesController.cs#L55) |
| WEB-API-015 | `PATCH /api/showtimes/{showtimeId}/status` | Policy = AuthorizationPolicies.StaffOrAdmin | Body: UpdateShowtimeStatusRequest request | Client gọi trực tiếp; đã triển khai | [Cinema_BE/MovieService/MovieService/Controllers/ShowtimesController.cs:108](../Cinema_BE/MovieService/MovieService/Controllers/ShowtimesController.cs#L108) |
| WEB-API-016 | `DELETE /api/showtimes/{showtimeId}` | Policy = AuthorizationPolicies.StaffOrAdmin | — | Client gọi trực tiếp; đã triển khai | [Cinema_BE/MovieService/MovieService/Controllers/ShowtimesController.cs:97](../Cinema_BE/MovieService/MovieService/Controllers/ShowtimesController.cs#L97) |
| WEB-API-017 | `GET /api/showtimes/{showtimeId}` | public | — | Client gọi trực tiếp; đã triển khai | [Cinema_BE/MovieService/MovieService/Controllers/ShowtimesController.cs:41](../Cinema_BE/MovieService/MovieService/Controllers/ShowtimesController.cs#L41) |
| WEB-API-018 | `PUT /api/showtimes/{showtimeId}` | Policy = AuthorizationPolicies.StaffOrAdmin | Body: ShowtimeRequest request | Client gọi trực tiếp; đã triển khai | [Cinema_BE/MovieService/MovieService/Controllers/ShowtimesController.cs:83](../Cinema_BE/MovieService/MovieService/Controllers/ShowtimesController.cs#L83) |
| WEB-API-019 | `GET /api/showtimes/date-range` | Policy = AuthorizationPolicies.StaffOrAdmin | Query: DateTime start; Query: DateTime end; Query: int pageNumber; Query: int pageSize; Query: string sortBy; Query: string sortDir | Backend chung/chỉ API; đã triển khai | [Cinema_BE/MovieService/MovieService/Controllers/ShowtimesController.cs:180](../Cinema_BE/MovieService/MovieService/Controllers/ShowtimesController.cs#L180) |
| WEB-API-020 | `GET /api/showtimes/movie/{movieId}/open` | public | Query: int pageNumber; Query: int pageSize; Query: string sortBy; Query: string sortDir | Client gọi trực tiếp; đã triển khai | [Cinema_BE/MovieService/MovieService/Controllers/ShowtimesController.cs:160](../Cinema_BE/MovieService/MovieService/Controllers/ShowtimesController.cs#L160) |
| WEB-API-021 | `GET /api/showtimes/movie/{movieId}` | public | Query: int pageNumber; Query: int pageSize; Query: string sortBy; Query: string sortDir | Backend chung/chỉ API; đã triển khai | [Cinema_BE/MovieService/MovieService/Controllers/ShowtimesController.cs:139](../Cinema_BE/MovieService/MovieService/Controllers/ShowtimesController.cs#L139) |
| WEB-API-022 | `GET /api/showtimes/open` | public | Query: int pageNumber; Query: int pageSize; Query: string sortBy; Query: string sortDir | Backend chung/chỉ API; đã triển khai | [Cinema_BE/MovieService/MovieService/Controllers/ShowtimesController.cs:121](../Cinema_BE/MovieService/MovieService/Controllers/ShowtimesController.cs#L121) |
| WEB-API-023 | `GET /api/showtimes` | public | Query: int pageNumber; Query: int pageSize; Query: string sortBy; Query: string sortDir | Backend chung/chỉ API; đã triển khai | [Cinema_BE/MovieService/MovieService/Controllers/ShowtimesController.cs:23](../Cinema_BE/MovieService/MovieService/Controllers/ShowtimesController.cs#L23) |
| WEB-API-024 | `POST /api/showtimes` | Policy = AuthorizationPolicies.StaffOrAdmin | Body: ShowtimeRequest request | Client gọi trực tiếp; đã triển khai | [Cinema_BE/MovieService/MovieService/Controllers/ShowtimesController.cs:68](../Cinema_BE/MovieService/MovieService/Controllers/ShowtimesController.cs#L68) |
| WEB-API-025 | `POST /api/v1/auth/change-password` | public | Body: ChangePasswordRequest request | Client gọi trực tiếp; đã triển khai | [Cinema_BE/AuthService/AuthService/Controllers/AuthController.cs:105](../Cinema_BE/AuthService/AuthService/Controllers/AuthController.cs#L105) |
| WEB-API-026 | `POST /api/v1/auth/forgot-password` | public | Body: EmailRequest request | Client gọi trực tiếp; đã triển khai | [Cinema_BE/AuthService/AuthService/Controllers/AuthController.cs:54](../Cinema_BE/AuthService/AuthService/Controllers/AuthController.cs#L54) |
| WEB-API-027 | `POST /api/v1/auth/login` | public | Body: LoginRequest request | Client gọi trực tiếp; đã triển khai | [Cinema_BE/AuthService/AuthService/Controllers/AuthController.cs:46](../Cinema_BE/AuthService/AuthService/Controllers/AuthController.cs#L46) |
| WEB-API-028 | `POST /api/v1/auth/logout` | public | Body: RefreshTokenRequest request | Client gọi trực tiếp; đã triển khai | [Cinema_BE/AuthService/AuthService/Controllers/AuthController.cs:79](../Cinema_BE/AuthService/AuthService/Controllers/AuthController.cs#L79) |
| WEB-API-029 | `GET /api/v1/auth/me` | public | — | Client gọi trực tiếp; đã triển khai | [Cinema_BE/AuthService/AuthService/Controllers/AuthController.cs:88](../Cinema_BE/AuthService/AuthService/Controllers/AuthController.cs#L88) |
| WEB-API-030 | `GET /api/v1/auth/members` | Roles = "ROLE_STAFF,ROLE_ADMIN" | Query: string? phone | Client gọi trực tiếp; đã triển khai | [Cinema_BE/AuthService/AuthService/Controllers/MembersController.cs:22](../Cinema_BE/AuthService/AuthService/Controllers/MembersController.cs#L22) |
| WEB-API-031 | `PUT /api/v1/auth/me` | public | Body: UpdateProfileRequest request | Client gọi trực tiếp; đã triển khai | [Cinema_BE/AuthService/AuthService/Controllers/AuthController.cs:97](../Cinema_BE/AuthService/AuthService/Controllers/AuthController.cs#L97) |
| WEB-API-032 | `POST /api/v1/auth/refresh` | public | Body: RefreshTokenRequest request | Client gọi trực tiếp; đã triển khai | [Cinema_BE/AuthService/AuthService/Controllers/AuthController.cs:70](../Cinema_BE/AuthService/AuthService/Controllers/AuthController.cs#L70) |
| WEB-API-033 | `POST /api/v1/auth/register` | public | Body: RegisterRequest request | Client gọi trực tiếp; đã triển khai | [Cinema_BE/AuthService/AuthService/Controllers/AuthController.cs:22](../Cinema_BE/AuthService/AuthService/Controllers/AuthController.cs#L22) |
| WEB-API-034 | `POST /api/v1/auth/resend-verification` | public | Body: EmailRequest request | Client gọi trực tiếp; đã triển khai | [Cinema_BE/AuthService/AuthService/Controllers/AuthController.cs:38](../Cinema_BE/AuthService/AuthService/Controllers/AuthController.cs#L38) |
| WEB-API-035 | `POST /api/v1/auth/reset-password` | public | Body: ResetPasswordRequest request | Client gọi trực tiếp; đã triển khai | [Cinema_BE/AuthService/AuthService/Controllers/AuthController.cs:62](../Cinema_BE/AuthService/AuthService/Controllers/AuthController.cs#L62) |
| WEB-API-036 | `GET /api/v1/auth/roles` | Roles = "ROLE_ADMIN" | — | Client gọi trực tiếp; đã triển khai | [Cinema_BE/AuthService/AuthService/Controllers/RolesController.cs:20](../Cinema_BE/AuthService/AuthService/Controllers/RolesController.cs#L20) |
| WEB-API-037 | `PUT /api/v1/auth/users/{id}/roles` | Roles = "ROLE_ADMIN" | Body: UpdateUserRolesRequest request | Client gọi trực tiếp; đã triển khai | [Cinema_BE/AuthService/AuthService/Controllers/UsersController.cs:51](../Cinema_BE/AuthService/AuthService/Controllers/UsersController.cs#L51) |
| WEB-API-038 | `PATCH /api/v1/auth/users/{id}/status` | Roles = "ROLE_ADMIN" | Body: UpdateUserStatusRequest request | Client gọi trực tiếp; đã triển khai | [Cinema_BE/AuthService/AuthService/Controllers/UsersController.cs:58](../Cinema_BE/AuthService/AuthService/Controllers/UsersController.cs#L58) |
| WEB-API-039 | `GET /api/v1/auth/users/{id}` | Roles = "ROLE_ADMIN" | — | Client gọi trực tiếp; đã triển khai | [Cinema_BE/AuthService/AuthService/Controllers/UsersController.cs:36](../Cinema_BE/AuthService/AuthService/Controllers/UsersController.cs#L36) |
| WEB-API-040 | `GET /api/v1/auth/users` | Roles = "ROLE_ADMIN" | Query: string? keyword; Query: string? role; Query: bool? enabled; Query: int page; Query: int size | Client gọi trực tiếp; đã triển khai | [Cinema_BE/AuthService/AuthService/Controllers/UsersController.cs:24](../Cinema_BE/AuthService/AuthService/Controllers/UsersController.cs#L24) |
| WEB-API-041 | `POST /api/v1/auth/users` | Roles = "ROLE_ADMIN" | Body: CreateUserRequest request | Client gọi trực tiếp; đã triển khai | [Cinema_BE/AuthService/AuthService/Controllers/UsersController.cs:43](../Cinema_BE/AuthService/AuthService/Controllers/UsersController.cs#L43) |
| WEB-API-042 | `POST /api/v1/auth/verify-email` | public | Body: VerifyEmailRequest request | Client gọi trực tiếp; đã triển khai | [Cinema_BE/AuthService/AuthService/Controllers/AuthController.cs:30](../Cinema_BE/AuthService/AuthService/Controllers/AuthController.cs#L30) |
| WEB-API-043 | `POST /api/v1/bookings/{id}/cancel` | Policy = AuthorizationPolicies.UserOrStaff | Query: string? reason | Client gọi trực tiếp; đã triển khai | [Cinema_BE/BookingService/BookingService/Controllers/BookingController.cs:201](../Cinema_BE/BookingService/BookingService/Controllers/BookingController.cs#L201) |
| WEB-API-044 | `POST /api/v1/bookings/{id}/check-in` | Policy = AuthorizationPolicies.StaffOrAdmin | — | Client gọi trực tiếp; đã triển khai | [Cinema_BE/BookingService/BookingService/Controllers/BookingController.cs:147](../Cinema_BE/BookingService/BookingService/Controllers/BookingController.cs#L147) |
| WEB-API-045 | `POST /api/v1/bookings/{id}/confirm` | Policy = AuthorizationPolicies.StaffOrAdmin | Query: string paymentMethod; Query: string? recipientEmail | Backend chung/chỉ API; đã triển khai | [Cinema_BE/BookingService/BookingService/Controllers/BookingController.cs:180](../Cinema_BE/BookingService/BookingService/Controllers/BookingController.cs#L180) |
| WEB-API-046 | `GET /api/v1/bookings/{id}` | Policy = AuthorizationPolicies.AnyRole | — | Client gọi trực tiếp; đã triển khai | [Cinema_BE/BookingService/BookingService/Controllers/BookingController.cs:37](../Cinema_BE/BookingService/BookingService/Controllers/BookingController.cs#L37) |
| WEB-API-047 | `GET /api/v1/bookings/code/{bookingCode}` | Policy = AuthorizationPolicies.StaffOrAdmin | — | Client gọi trực tiếp; đã triển khai | [Cinema_BE/BookingService/BookingService/Controllers/BookingController.cs:137](../Cinema_BE/BookingService/BookingService/Controllers/BookingController.cs#L137) |
| WEB-API-048 | `GET /api/v1/bookings/date-range` | Policy = AuthorizationPolicies.StaffOrAdmin | Query: DateTime start; Query: DateTime end; Query: int page; Query: int size; Query: string sortBy; Query: string sortDir | Backend chung/chỉ API; đã triển khai | [Cinema_BE/BookingService/BookingService/Controllers/BookingController.cs:84](../Cinema_BE/BookingService/BookingService/Controllers/BookingController.cs#L84) |
| WEB-API-049 | `GET /api/v1/bookings/showtime/{showtimeId}/occupied-seats` | Policy = AuthorizationPolicies.AnyRole | — | Client gọi trực tiếp; đã triển khai | [Cinema_BE/BookingService/BookingService/Controllers/BookingController.cs:100](../Cinema_BE/BookingService/BookingService/Controllers/BookingController.cs#L100) |
| WEB-API-050 | `GET /api/v1/bookings/showtime/{showtimeId}/seats` | Policy = AuthorizationPolicies.StaffOrAdmin | — | Client gọi trực tiếp; đã triển khai | [Cinema_BE/BookingService/BookingService/Controllers/BookingController.cs:111](../Cinema_BE/BookingService/BookingService/Controllers/BookingController.cs#L111) |
| WEB-API-051 | `GET /api/v1/bookings/showtimes/stats` | Policy = AuthorizationPolicies.StaffOrAdmin | Query: List<long>? showtimeIds; Query: DateTime? start; Query: DateTime? end | Client gọi trực tiếp; đã triển khai | [Cinema_BE/BookingService/BookingService/Controllers/BookingController.cs:123](../Cinema_BE/BookingService/BookingService/Controllers/BookingController.cs#L123) |
| WEB-API-052 | `GET /api/v1/bookings/status/{status}` | Policy = AuthorizationPolicies.StaffOrAdmin | Query: int page; Query: int size; Query: string sortBy; Query: string sortDir | Backend chung/chỉ API; đã triển khai | [Cinema_BE/BookingService/BookingService/Controllers/BookingController.cs:69](../Cinema_BE/BookingService/BookingService/Controllers/BookingController.cs#L69) |
| WEB-API-053 | `GET /api/v1/bookings/user/{userId}` | Policy = AuthorizationPolicies.AnyRole | Query: int page; Query: int size; Query: string sortBy; Query: string sortDir | Client gọi trực tiếp; đã triển khai | [Cinema_BE/BookingService/BookingService/Controllers/BookingController.cs:50](../Cinema_BE/BookingService/BookingService/Controllers/BookingController.cs#L50) |
| WEB-API-054 | `GET /api/v1/bookings` | Policy = AuthorizationPolicies.StaffOrAdmin | Query: int page; Query: int size; Query: string sortBy; Query: string sortDir | Backend chung/chỉ API; đã triển khai | [Cinema_BE/BookingService/BookingService/Controllers/BookingController.cs:23](../Cinema_BE/BookingService/BookingService/Controllers/BookingController.cs#L23) |
| WEB-API-055 | `POST /api/v1/bookings` | Policy = AuthorizationPolicies.AnyRole | Body: BookingRequest request | Client gọi trực tiếp; đã triển khai | [Cinema_BE/BookingService/BookingService/Controllers/BookingController.cs:156](../Cinema_BE/BookingService/BookingService/Controllers/BookingController.cs#L156) |
| WEB-API-056 | `PUT /api/v1/concessions/{id}` | Policy = AuthorizationPolicies.AdminOnly | Body: ConcessionItemRequest request | Client gọi trực tiếp; đã triển khai | [Cinema_BE/BookingService/BookingService/Controllers/ConcessionController.cs:41](../Cinema_BE/BookingService/BookingService/Controllers/ConcessionController.cs#L41) |
| WEB-API-057 | `GET /api/v1/concessions` | public | Query: bool includeInactive | Client gọi trực tiếp; đã triển khai | [Cinema_BE/BookingService/BookingService/Controllers/ConcessionController.cs:24](../Cinema_BE/BookingService/BookingService/Controllers/ConcessionController.cs#L24) |
| WEB-API-058 | `POST /api/v1/concessions` | Policy = AuthorizationPolicies.AdminOnly | Body: ConcessionItemRequest request | Client gọi trực tiếp; đã triển khai | [Cinema_BE/BookingService/BookingService/Controllers/ConcessionController.cs:33](../Cinema_BE/BookingService/BookingService/Controllers/ConcessionController.cs#L33) |
| WEB-API-059 | `GET /api/v1/loyalty/accounts` | Policy = AuthorizationPolicies.StaffOrAdmin | Query: string? userIds | Client gọi trực tiếp; đã triển khai | [Cinema_BE/BookingService/BookingService/Controllers/LoyaltyController.cs:38](../Cinema_BE/BookingService/BookingService/Controllers/LoyaltyController.cs#L38) |
| WEB-API-060 | `GET /api/v1/loyalty/me` | authenticated | — | Client gọi trực tiếp; đã triển khai | [Cinema_BE/BookingService/BookingService/Controllers/LoyaltyController.cs:24](../Cinema_BE/BookingService/BookingService/Controllers/LoyaltyController.cs#L24) |
| WEB-API-061 | `POST /api/v1/loyalty/users/{userId}/adjust` | Policy = AuthorizationPolicies.AdminOnly | Body: LoyaltyAdjustRequest request | Client gọi trực tiếp; đã triển khai | [Cinema_BE/BookingService/BookingService/Controllers/LoyaltyController.cs:49](../Cinema_BE/BookingService/BookingService/Controllers/LoyaltyController.cs#L49) |
| WEB-API-062 | `GET /api/v1/loyalty/users/{userId}` | Policy = AuthorizationPolicies.StaffOrAdmin | — | Client gọi trực tiếp; đã triển khai | [Cinema_BE/BookingService/BookingService/Controllers/LoyaltyController.cs:30](../Cinema_BE/BookingService/BookingService/Controllers/LoyaltyController.cs#L30) |
| WEB-API-063 | `DELETE /api/v1/movies/{id}` | Policy = AuthorizationPolicies.AdminOnly | — | Client gọi trực tiếp; đã triển khai | [Cinema_BE/MovieService/MovieService/Controllers/MoviesController.cs:107](../Cinema_BE/MovieService/MovieService/Controllers/MoviesController.cs#L107) |
| WEB-API-064 | `GET /api/v1/movies/{id}` | public | — | Client gọi trực tiếp; đã triển khai | [Cinema_BE/MovieService/MovieService/Controllers/MoviesController.cs:34](../Cinema_BE/MovieService/MovieService/Controllers/MoviesController.cs#L34) |
| WEB-API-065 | `PUT /api/v1/movies/{id}` | Policy = AuthorizationPolicies.AdminOnly | Body: MovieRequest request | Client gọi trực tiếp; đã triển khai | [Cinema_BE/MovieService/MovieService/Controllers/MoviesController.cs:99](../Cinema_BE/MovieService/MovieService/Controllers/MoviesController.cs#L99) |
| WEB-API-066 | `GET /api/v1/movies/browse` | public | Query: string? when; Query: string? genre; Query: string? keyword; Query: int page; Query: int size | Client gọi trực tiếp; đã triển khai | [Cinema_BE/MovieService/MovieService/Controllers/MoviesController.cs:57](../Cinema_BE/MovieService/MovieService/Controllers/MoviesController.cs#L57) |
| WEB-API-067 | `GET /api/v1/movies/genres` | public | — | Client gọi trực tiếp; đã triển khai | [Cinema_BE/MovieService/MovieService/Controllers/MoviesController.cs:70](../Cinema_BE/MovieService/MovieService/Controllers/MoviesController.cs#L70) |
| WEB-API-068 | `GET /api/v1/movies/search` | public | Query: string keyword; Query: int page; Query: int size; Query: string sortBy; Query: string sortDir | Backend chung/chỉ API; đã triển khai | [Cinema_BE/MovieService/MovieService/Controllers/MoviesController.cs:77](../Cinema_BE/MovieService/MovieService/Controllers/MoviesController.cs#L77) |
| WEB-API-069 | `GET /api/v1/movies/status/{status}` | public | Query: int page; Query: int size; Query: string sortBy; Query: string sortDir | Client gọi trực tiếp; đã triển khai | [Cinema_BE/MovieService/MovieService/Controllers/MoviesController.cs:42](../Cinema_BE/MovieService/MovieService/Controllers/MoviesController.cs#L42) |
| WEB-API-070 | `GET /api/v1/movies` | public | Query: int page; Query: int size; Query: string sortBy; Query: string sortDir | Client gọi trực tiếp; đã triển khai | [Cinema_BE/MovieService/MovieService/Controllers/MoviesController.cs:22](../Cinema_BE/MovieService/MovieService/Controllers/MoviesController.cs#L22) |
| WEB-API-071 | `POST /api/v1/movies` | Policy = AuthorizationPolicies.AdminOnly | Body: MovieRequest request | Client gọi trực tiếp; đã triển khai | [Cinema_BE/MovieService/MovieService/Controllers/MoviesController.cs:90](../Cinema_BE/MovieService/MovieService/Controllers/MoviesController.cs#L90) |
| WEB-API-072 | `PATCH /api/v1/notifications/{id}/read` | Policy = AuthorizationPolicies.AnyRole | — | Client gọi trực tiếp; đã triển khai | [Cinema_BE/BookingService/BookingService/Controllers/NotificationController.cs:77](../Cinema_BE/BookingService/BookingService/Controllers/NotificationController.cs#L77) |
| WEB-API-073 | `POST /api/v1/notifications/{id}/send` | Policy = AuthorizationPolicies.StaffOrAdmin | — | Client gọi trực tiếp; đã triển khai | [Cinema_BE/BookingService/BookingService/Controllers/NotificationController.cs:104](../Cinema_BE/BookingService/BookingService/Controllers/NotificationController.cs#L104) |
| WEB-API-074 | `DELETE /api/v1/notifications/{id}` | Policy = AuthorizationPolicies.AnyRole | — | Backend chung/chỉ API; đã triển khai | [Cinema_BE/BookingService/BookingService/Controllers/NotificationController.cs:112](../Cinema_BE/BookingService/BookingService/Controllers/NotificationController.cs#L112) |
| WEB-API-075 | `GET /api/v1/notifications/{id}` | Policy = AuthorizationPolicies.AnyRole | — | Client gọi trực tiếp; đã triển khai | [Cinema_BE/BookingService/BookingService/Controllers/NotificationController.cs:36](../Cinema_BE/BookingService/BookingService/Controllers/NotificationController.cs#L36) |
| WEB-API-076 | `POST /api/v1/notifications/read-all` | Policy = AuthorizationPolicies.AnyRole | — | Client gọi trực tiếp; đã triển khai | [Cinema_BE/BookingService/BookingService/Controllers/NotificationController.cs:89](../Cinema_BE/BookingService/BookingService/Controllers/NotificationController.cs#L89) |
| WEB-API-077 | `GET /api/v1/notifications/unread-count` | Policy = AuthorizationPolicies.AnyRole | — | Client gọi trực tiếp; đã triển khai | [Cinema_BE/BookingService/BookingService/Controllers/NotificationController.cs:67](../Cinema_BE/BookingService/BookingService/Controllers/NotificationController.cs#L67) |
| WEB-API-078 | `GET /api/v1/notifications/user/{userId}` | Policy = AuthorizationPolicies.AnyRole | Query: int page; Query: int size; Query: string sortBy; Query: string sortDir | Client gọi trực tiếp; đã triển khai | [Cinema_BE/BookingService/BookingService/Controllers/NotificationController.cs:49](../Cinema_BE/BookingService/BookingService/Controllers/NotificationController.cs#L49) |
| WEB-API-079 | `GET /api/v1/notifications` | Policy = AuthorizationPolicies.AdminOnly | Query: int page; Query: int size; Query: string sortBy; Query: string sortDir | Backend chung/chỉ API; đã triển khai | [Cinema_BE/BookingService/BookingService/Controllers/NotificationController.cs:24](../Cinema_BE/BookingService/BookingService/Controllers/NotificationController.cs#L24) |
| WEB-API-080 | `POST /api/v1/notifications` | Policy = AuthorizationPolicies.StaffOrAdmin | Body: NotificationRequest request | Client gọi trực tiếp; đã triển khai | [Cinema_BE/BookingService/BookingService/Controllers/NotificationController.cs:96](../Cinema_BE/BookingService/BookingService/Controllers/NotificationController.cs#L96) |
| WEB-API-081 | `POST /api/v1/payments/{id}/process` | Policy = AuthorizationPolicies.StaffOrAdmin | Query: string? recipientEmail | Client gọi trực tiếp; đã triển khai | [Cinema_BE/BookingService/BookingService/Controllers/PaymentController.cs:186](../Cinema_BE/BookingService/BookingService/Controllers/PaymentController.cs#L186) |
| WEB-API-082 | `GET /api/v1/payments/{id}/refund` | Policy = AuthorizationPolicies.AnyRole | — | Client gọi trực tiếp; đã triển khai | [Cinema_BE/BookingService/BookingService/Controllers/PaymentController.cs:208](../Cinema_BE/BookingService/BookingService/Controllers/PaymentController.cs#L208) |
| WEB-API-083 | `POST /api/v1/payments/{id}/refund` | Policy = AuthorizationPolicies.AdminOnly | Query: string? reason | Backend chung/chỉ API; đã triển khai | [Cinema_BE/BookingService/BookingService/Controllers/PaymentController.cs:198](../Cinema_BE/BookingService/BookingService/Controllers/PaymentController.cs#L198) |
| WEB-API-084 | `GET /api/v1/payments/{id}` | Policy = AuthorizationPolicies.AnyRole | — | Client gọi trực tiếp; đã triển khai | [Cinema_BE/BookingService/BookingService/Controllers/PaymentController.cs:57](../Cinema_BE/BookingService/BookingService/Controllers/PaymentController.cs#L57) |
| WEB-API-085 | `GET /api/v1/payments/booking/{bookingId}` | Policy = AuthorizationPolicies.AnyRole | Query: int page; Query: int size; Query: string sortBy; Query: string sortDir | Backend chung/chỉ API; đã triển khai | [Cinema_BE/BookingService/BookingService/Controllers/PaymentController.cs:88](../Cinema_BE/BookingService/BookingService/Controllers/PaymentController.cs#L88) |
| WEB-API-086 | `POST /api/v1/payments/cash` | Policy = AuthorizationPolicies.StaffOrAdmin | Body: CashPaymentRequest request | Client gọi trực tiếp; đã triển khai | [Cinema_BE/BookingService/BookingService/Controllers/PaymentController.cs:136](../Cinema_BE/BookingService/BookingService/Controllers/PaymentController.cs#L136) |
| WEB-API-087 | `POST /api/v1/payments/payos/{orderCode}/verify` | Policy = AuthorizationPolicies.AnyRole | Query: string? recipientEmail | Client gọi trực tiếp; đã triển khai | [Cinema_BE/BookingService/BookingService/Controllers/PaymentController.cs:147](../Cinema_BE/BookingService/BookingService/Controllers/PaymentController.cs#L147) |
| WEB-API-088 | `POST /api/v1/payments/payos/checkout` | Policy = AuthorizationPolicies.AnyRole | Body: PayOsCreateRequest request | Client gọi trực tiếp; đã triển khai | [Cinema_BE/BookingService/BookingService/Controllers/PaymentController.cs:122](../Cinema_BE/BookingService/BookingService/Controllers/PaymentController.cs#L122) |
| WEB-API-089 | `POST /api/v1/payments/payos/webhook` | public | Body: JsonElement body | Backend chung/chỉ API; đã triển khai | [Cinema_BE/BookingService/BookingService/Controllers/PaymentController.cs:172](../Cinema_BE/BookingService/BookingService/Controllers/PaymentController.cs#L172) |
| WEB-API-090 | `POST /api/v1/payments/refunds/{refundId}/complete` | Policy = AuthorizationPolicies.StaffOrAdmin | Body: CompleteRefundRequest request | Client gọi trực tiếp; đã triển khai | [Cinema_BE/BookingService/BookingService/Controllers/PaymentController.cs:255](../Cinema_BE/BookingService/BookingService/Controllers/PaymentController.cs#L255) |
| WEB-API-091 | `POST /api/v1/payments/refunds/{refundId}/reject` | Policy = AuthorizationPolicies.StaffOrAdmin | Body: RejectRefundRequest request | Client gọi trực tiếp; đã triển khai | [Cinema_BE/BookingService/BookingService/Controllers/PaymentController.cs:245](../Cinema_BE/BookingService/BookingService/Controllers/PaymentController.cs#L245) |
| WEB-API-092 | `GET /api/v1/payments/refunds/{refundId}` | Policy = AuthorizationPolicies.AnyRole | — | Client gọi trực tiếp; đã triển khai | [Cinema_BE/BookingService/BookingService/Controllers/PaymentController.cs:232](../Cinema_BE/BookingService/BookingService/Controllers/PaymentController.cs#L232) |
| WEB-API-093 | `GET /api/v1/payments/refunds` | Policy = AuthorizationPolicies.StaffOrAdmin | Query: string? status; Query: int page; Query: int size | Client gọi trực tiếp; đã triển khai | [Cinema_BE/BookingService/BookingService/Controllers/PaymentController.cs:222](../Cinema_BE/BookingService/BookingService/Controllers/PaymentController.cs#L222) |
| WEB-API-094 | `GET /api/v1/payments/summary` | Policy = AuthorizationPolicies.AdminOnly | Query: DateTime start; Query: DateTime end | Client gọi trực tiếp; đã triển khai | [Cinema_BE/BookingService/BookingService/Controllers/PaymentController.cs:46](../Cinema_BE/BookingService/BookingService/Controllers/PaymentController.cs#L46) |
| WEB-API-095 | `GET /api/v1/payments/user/{userId}` | Policy = AuthorizationPolicies.AnyRole | Query: int page; Query: int size; Query: string sortBy; Query: string sortDir | Client gọi trực tiếp; đã triển khai | [Cinema_BE/BookingService/BookingService/Controllers/PaymentController.cs:70](../Cinema_BE/BookingService/BookingService/Controllers/PaymentController.cs#L70) |
| WEB-API-096 | `GET /api/v1/payments` | Policy = AuthorizationPolicies.StaffOrAdmin | Query: int page; Query: int size; Query: string sortBy; Query: string sortDir | Backend chung/chỉ API; đã triển khai | [Cinema_BE/BookingService/BookingService/Controllers/PaymentController.cs:31](../Cinema_BE/BookingService/BookingService/Controllers/PaymentController.cs#L31) |
| WEB-API-097 | `POST /api/v1/payments` | Policy = AuthorizationPolicies.AnyRole | Body: PaymentRequest request | Backend chung/chỉ API; đã triển khai | [Cinema_BE/BookingService/BookingService/Controllers/PaymentController.cs:110](../Cinema_BE/BookingService/BookingService/Controllers/PaymentController.cs#L110) |
| WEB-API-098 | `PUT /api/v1/promotions/{id}` | Policy = AuthorizationPolicies.AdminOnly | Body: PromotionRequest request | Client gọi trực tiếp; đã triển khai | [Cinema_BE/BookingService/BookingService/Controllers/PromotionController.cs:47](../Cinema_BE/BookingService/BookingService/Controllers/PromotionController.cs#L47) |
| WEB-API-099 | `POST /api/v1/promotions/quote` | authenticated | Body: PromotionQuoteRequest request | Client gọi trực tiếp; đã triển khai | [Cinema_BE/BookingService/BookingService/Controllers/PromotionController.cs:33](../Cinema_BE/BookingService/BookingService/Controllers/PromotionController.cs#L33) |
| WEB-API-100 | `GET /api/v1/promotions` | public | Query: bool all | Client gọi trực tiếp; đã triển khai | [Cinema_BE/BookingService/BookingService/Controllers/PromotionController.cs:24](../Cinema_BE/BookingService/BookingService/Controllers/PromotionController.cs#L24) |
| WEB-API-101 | `POST /api/v1/promotions` | Policy = AuthorizationPolicies.AdminOnly | Body: PromotionRequest request | Client gọi trực tiếp; đã triển khai | [Cinema_BE/BookingService/BookingService/Controllers/PromotionController.cs:40](../Cinema_BE/BookingService/BookingService/Controllers/PromotionController.cs#L40) |
| WEB-API-102 | `DELETE /api/v1/reviews/{id}` | authenticated | — | Client gọi trực tiếp; đã triển khai | [Cinema_BE/BookingService/BookingService/Controllers/MovieReviewController.cs:58](../Cinema_BE/BookingService/BookingService/Controllers/MovieReviewController.cs#L58) |
| WEB-API-103 | `GET /api/v1/reviews/booking/{bookingId}` | authenticated | — | Client gọi trực tiếp; đã triển khai | [Cinema_BE/BookingService/BookingService/Controllers/MovieReviewController.cs:43](../Cinema_BE/BookingService/BookingService/Controllers/MovieReviewController.cs#L43) |
| WEB-API-104 | `GET /api/v1/reviews/mine` | authenticated | — | Backend chung/chỉ API; đã triển khai | [Cinema_BE/BookingService/BookingService/Controllers/MovieReviewController.cs:36](../Cinema_BE/BookingService/BookingService/Controllers/MovieReviewController.cs#L36) |
| WEB-API-105 | `GET /api/v1/reviews/movie/{movieId}` | public | Query: int page; Query: int size | Client gọi trực tiếp; đã triển khai | [Cinema_BE/BookingService/BookingService/Controllers/MovieReviewController.cs:25](../Cinema_BE/BookingService/BookingService/Controllers/MovieReviewController.cs#L25) |
| WEB-API-106 | `POST /api/v1/reviews` | authenticated | Body: MovieReviewRequest request | Client gọi trực tiếp; đã triển khai | [Cinema_BE/BookingService/BookingService/Controllers/MovieReviewController.cs:50](../Cinema_BE/BookingService/BookingService/Controllers/MovieReviewController.cs#L50) |

POST /api/showtimes/{showtimeId}/seats được BookingService gọi nội bộ với token chuyển tiếp. Controller cho người đã xác thực còn route ghi suất chung gateway cần StaffOrAdmin; không coi là lời gọi client khách hàng. Webhook PayOS công khai với JWT nhưng xác thực bằng HMAC. Lời gọi nội bộ và webhook là phụ thuộc, không phải màn điện thoại thêm.

Phân trang theo endpoint: page/size cho nhiều API danh mục/vé/thanh toán; pageNumber/pageSize cho API suất/phòng có khai báo. Kích thước phân trang bị chặn, thường 50; mảng thể loại/menu/ghế/điểm không phải đều phân trang. ApiClient dùng timeout 15 giây và phân tích JSON UTF-8/ProblemDetails. Dạng kết quả theo DTO controller hiện tại.

### Định nghĩa trường yêu cầu

| DTO | Trường / kiểu | Nguồn |
| --- | --- | --- |
| ChangePasswordRequest | CurrentPassword: string; NewPassword: string | [Cinema_BE/AuthService/AuthService/DTOs/Request/ChangePasswordRequest.cs](../Cinema_BE/AuthService/AuthService/DTOs/Request/ChangePasswordRequest.cs) |
| CreateUserRequest | Email: string; Password: string; FullName: string; Phone: string?; Roles: List<string> | [Cinema_BE/AuthService/AuthService/DTOs/Request/CreateUserRequest.cs](../Cinema_BE/AuthService/AuthService/DTOs/Request/CreateUserRequest.cs) |
| EmailRequest | Email: string | [Cinema_BE/AuthService/AuthService/DTOs/Request/EmailRequest.cs](../Cinema_BE/AuthService/AuthService/DTOs/Request/EmailRequest.cs) |
| LoginRequest | Email: string; Password: string | [Cinema_BE/AuthService/AuthService/DTOs/Request/LoginRequest.cs](../Cinema_BE/AuthService/AuthService/DTOs/Request/LoginRequest.cs) |
| RefreshTokenRequest | RefreshToken: string | [Cinema_BE/AuthService/AuthService/DTOs/Request/RefreshTokenRequest.cs](../Cinema_BE/AuthService/AuthService/DTOs/Request/RefreshTokenRequest.cs) |
| RegisterRequest | Email: string; Password: string; FullName: string; Phone: string? | [Cinema_BE/AuthService/AuthService/DTOs/Request/RegisterRequest.cs](../Cinema_BE/AuthService/AuthService/DTOs/Request/RegisterRequest.cs) |
| ResetPasswordRequest | Email: string; Otp: string; NewPassword: string | [Cinema_BE/AuthService/AuthService/DTOs/Request/ResetPasswordRequest.cs](../Cinema_BE/AuthService/AuthService/DTOs/Request/ResetPasswordRequest.cs) |
| UpdateProfileRequest | FullName: string; Phone: string? | [Cinema_BE/AuthService/AuthService/DTOs/Request/UpdateProfileRequest.cs](../Cinema_BE/AuthService/AuthService/DTOs/Request/UpdateProfileRequest.cs) |
| UpdateUserRolesRequest | Roles: List<string> | [Cinema_BE/AuthService/AuthService/DTOs/Request/UpdateUserRolesRequest.cs](../Cinema_BE/AuthService/AuthService/DTOs/Request/UpdateUserRolesRequest.cs) |
| UpdateUserStatusRequest | Enabled: bool? | [Cinema_BE/AuthService/AuthService/DTOs/Request/UpdateUserStatusRequest.cs](../Cinema_BE/AuthService/AuthService/DTOs/Request/UpdateUserStatusRequest.cs) |
| VerifyEmailRequest | Email: string; Otp: string; Password: string | [Cinema_BE/AuthService/AuthService/DTOs/Request/VerifyEmailRequest.cs](../Cinema_BE/AuthService/AuthService/DTOs/Request/VerifyEmailRequest.cs) |
| BookingRequest | UserId: long?; ShowtimeId: long?; MovieTitle: string?; CustomerEmail: string?; CustomerPhone: string?; ShowTime: DateTime?; Seats: List<SeatRequest>; PromotionCode: string?; UsePoints: int?; Concessions: List<BookingConcessionRequest> | [Cinema_BE/BookingService/BookingService/DTOs/Requests/BookingRequest.cs](../Cinema_BE/BookingService/BookingService/DTOs/Requests/BookingRequest.cs) |
| CashPaymentRequest | BookingId: long?; AmountReceived: decimal?; RecipientEmail: string? | [Cinema_BE/BookingService/BookingService/DTOs/Requests/CashPaymentRequest.cs](../Cinema_BE/BookingService/BookingService/DTOs/Requests/CashPaymentRequest.cs) |
| CompleteRefundRequest | TransactionRef: string?; Note: string? | [Cinema_BE/BookingService/BookingService/DTOs/Requests/CompleteRefundRequest.cs](../Cinema_BE/BookingService/BookingService/DTOs/Requests/CompleteRefundRequest.cs) |
| ConcessionItemRequest | Name: string?; Description: string?; Price: decimal?; ImageUrl: string?; Active: bool?; SortOrder: int? | [Cinema_BE/BookingService/BookingService/DTOs/Requests/ConcessionItemRequest.cs](../Cinema_BE/BookingService/BookingService/DTOs/Requests/ConcessionItemRequest.cs) |
| LoyaltyAdjustRequest | Points: int?; Note: string? | [Cinema_BE/BookingService/BookingService/DTOs/Requests/LoyaltyAdjustRequest.cs](../Cinema_BE/BookingService/BookingService/DTOs/Requests/LoyaltyAdjustRequest.cs) |
| MovieReviewRequest | BookingId: long?; Rating: int?; Comment: string? | [Cinema_BE/BookingService/BookingService/DTOs/Requests/MovieReviewRequest.cs](../Cinema_BE/BookingService/BookingService/DTOs/Requests/MovieReviewRequest.cs) |
| NotificationRequest | UserId: long?; BookingId: long?; RecipientEmail: string?; Subject: string?; Type: string?; Content: string? | [Cinema_BE/BookingService/BookingService/DTOs/Requests/NotificationRequest.cs](../Cinema_BE/BookingService/BookingService/DTOs/Requests/NotificationRequest.cs) |
| PaymentRequest | BookingId: long?; UserId: long?; RecipientEmail: string?; Amount: decimal?; Method: string? | [Cinema_BE/BookingService/BookingService/DTOs/Requests/PaymentRequest.cs](../Cinema_BE/BookingService/BookingService/DTOs/Requests/PaymentRequest.cs) |
| PayOsCreateRequest | BookingId: long?; UserId: long?; Amount: decimal?; Description: string?; ReturnUrl: string?; CancelUrl: string? | [Cinema_BE/BookingService/BookingService/DTOs/Requests/PayOsCreateRequest.cs](../Cinema_BE/BookingService/BookingService/DTOs/Requests/PayOsCreateRequest.cs) |
| PromotionQuoteRequest | ShowtimeId: long?; TicketAmount: decimal; Tickets: int; Code: string? | [Cinema_BE/BookingService/BookingService/DTOs/Requests/PromotionQuoteRequest.cs](../Cinema_BE/BookingService/BookingService/DTOs/Requests/PromotionQuoteRequest.cs) |
| PromotionRequest | Code: string?; Name: string?; Description: string?; DiscountType: string?; DiscountValue: decimal?; MaxDiscount: decimal?; MinTickets: int?; DaysOfWeek: List<int>?; StartsAt: DateTime?; EndsAt: DateTime?; UsageLimit: int?; Active: bool? | [Cinema_BE/BookingService/BookingService/DTOs/Requests/PromotionRequest.cs](../Cinema_BE/BookingService/BookingService/DTOs/Requests/PromotionRequest.cs) |
| RejectRefundRequest | Reason: string? | [Cinema_BE/BookingService/BookingService/DTOs/Requests/RejectRefundRequest.cs](../Cinema_BE/BookingService/BookingService/DTOs/Requests/RejectRefundRequest.cs) |
| GenerateSeatRequest | RoomId: long; Rows: int; SeatsPerRow: int; SeatType: string | [Cinema_BE/MovieService/MovieService/DTOs/Request/GenerateSeatRequest.cs](../Cinema_BE/MovieService/MovieService/DTOs/Request/GenerateSeatRequest.cs) |
| MovieRequest | Title: string?; Description: string?; DurationMinutes: int; Genre: string?; Language: string?; ReleaseDate: DateTime; PosterUrl: string?; TrailerUrl: string?; PreviewUrl: string?; AgeRating: string?; Director: string?; Cast: string?; Status: string? | [Cinema_BE/MovieService/MovieService/DTOs/Request/MovieRequest.cs](../Cinema_BE/MovieService/MovieService/DTOs/Request/MovieRequest.cs) |
| RoomRequest | Name: string; TotalSeats: int; Rows: int; SeatsPerRow: int | [Cinema_BE/MovieService/MovieService/DTOs/Request/RoomRequest.cs](../Cinema_BE/MovieService/MovieService/DTOs/Request/RoomRequest.cs) |
| ShowtimeRequest | MovieId: long; RoomId: long; StartTime: DateTime; EndTime: DateTime; Price: decimal; Status: string?; Format: string? | [Cinema_BE/MovieService/MovieService/DTOs/Request/ShowtimeRequest.cs](../Cinema_BE/MovieService/MovieService/DTOs/Request/ShowtimeRequest.cs) |
| UpdateRoomSeatsRequest | TotalSeats: int; SeatsPerRow: int?; SeatType: string? | [Cinema_BE/MovieService/MovieService/DTOs/Request/UpdateRoomSeatsRequest.cs](../Cinema_BE/MovieService/MovieService/DTOs/Request/UpdateRoomSeatsRequest.cs) |
| UpdateSeatTypeRequest | SeatIds: List<long>; SeatType: string | [Cinema_BE/MovieService/MovieService/DTOs/Request/UpdateSeatTypeRequest.cs](../Cinema_BE/MovieService/MovieService/DTOs/Request/UpdateSeatTypeRequest.cs) |
| UpdateShowtimeStatusRequest | Status: string | [Cinema_BE/MovieService/MovieService/DTOs/Request/UpdateShowtimeStatusRequest.cs](../Cinema_BE/MovieService/MovieService/DTOs/Request/UpdateShowtimeStatusRequest.cs) |

## 14. Yêu cầu dữ liệu

Project-Cinema-DB chưa được khởi tạo trong checkout (git submodule status bắt đầu bằng “-”). Không có dump/seed/migration SQL của submodule; DDL chính xác và trạng thái migrate thật là [CẦN XÁC NHẬN]. Hợp đồng dùng model/DbContext EF cục bộ và migration SQL backend sẵn có. Mapping không chứng minh DB thật đã migrate.

| Cơ sở dữ liệu | Thực thể / bảng | Toàn vẹn và trường |
| --- | --- | --- |
| cinema_auth_db | User/Role; users, roles, users_roles, refresh_tokens, otp_codes | Email/token duy nhất; băm BCrypt; liên kết vai trò; hạn OTP và thu hồi token |
| cinema_movie_db | Movie; movies | Tên/thời lượng/thể loại/ngôn ngữ/tuổi/đạo diễn/diễn viên; ảnh/trailer/preview; ACTIVE/INACTIVE |
| cinema_showtime_db | Room/Seat/Showtime; rooms, seats, showtimes, outbox_messages | Duy nhất phòng/hàng/số; định dạng, giờ, giá; khoá ngoại nội bộ phòng |
| cinema_booking_db | Booking, BookingSeat, SeatReservation, ConcessionItem, BookingConcession, Promotion, LoyaltyAccount, LoyaltyTransaction, MovieReview; bookings, booking_seats, seat_reservations, concession_items, booking_concessions, promotions, loyalty_accounts, loyalty_transactions, movie_reviews, outbox_messages | Mã vé duy nhất; giữ chỗ suất/ghế duy nhất; đánh giá người/phim duy nhất; bản chụp tiền; userId quầy có thể rỗng; checkedInAt/expiresAt/remindedAt |
| cinema_payment_db | Payment/Refund; payments, refunds, outbox_messages | Vé, tiền, phương thức/trạng thái, tham chiếu PayOS và ngân hàng trả; một hoàn mỗi thanh toán |
| cinema_notification_db | Notification; notifications | Người nhận/vé/sự kiện; chống lặp sự kiện; sentAt/readAt; trạng thái và lỗi |

Client lưu token/thông tin người qua flutter_secure_storage và dữ liệu vé tạm trong bộ nhớ, không có sáu DB cục bộ. Tiền decimal server lưu bản chụp ghế/bắp nước/giảm giá/điểm. Thời gian rạp dùng giờ Việt Nam và mapping timestamp without time zone. ID xuyên service là tham chiếu logic được ứng dụng/sự kiện kiểm tra.

## 15. Luồng nghiệp vụ

| ID | Luồng |
| --- | --- |
| WEB-WF-01 | Đăng ký → xác thực OTP → trang đầu theo vai trò; đăng nhập chưa xác thực sang OTP. Khôi phục lỗi không xác thực tài khoản. |
| WEB-WF-02 | Duyệt → phim → suất mở → ghế → xác nhận phần thêm/mã/điểm/tuổi → tạo giữ PENDING → PayOS → server xác minh → CONFIRMED + thông báo vé. |
| WEB-WF-03 | Tới expiresAt → tác vụ hết hạn (mặc định mỗi 30 giây) → EXPIRED và trả ghế/điểm. Trả muộn lấy lại ghế và xác nhận hoặc tạo hoàn toàn bộ. |
| WEB-WF-04 | Khách huỷ đã trả ≥2 giờ trước suất → REFUND_PENDING giữ ghế → nhân viên web chuyển thủ công/ghi nhận → REFUNDED/CANCELLED. Từ chối đủ điều kiện phục hồi SUCCESS/CONFIRMED. |
| WEB-WF-05 | 1. Quét QR hoặc nhập mã vé rồi nhấn Enter. 2. Tra vé; bổ sung phòng và phân loại tuổi khi lời gọi danh mục thành công. 3. Kiểm tra danh tính/tuổi theo nhắc nhở rồi xác nhận check-in. 4. Lưu checkedInAt, hiện xác nhận và sẵn sàng nhập mã tiếp theo. |
| WEB-WF-06 | 1. Chọn khách vãng lai hoặc tìm thành viên qua điện thoại; chọn suất, ghế và bắp nước/khuyến mãi/điểm nếu cần. 2. Giữ ghế và mở thu tiền tại quầy. 3. Nhận đủ tiền mặt và hiện tiền thối hoặc hiện VietQR và xác minh mỗi ba giây. 4. Sau khi server xác nhận, hiện/in vé QR, có thể gửi email và check-in trong khung được phép. |
| WEB-WF-07 | Huỷ suất → outbox MovieService → bộ nhận BookingService → huỷ vé/tạo hoàn vé đã trả → thông báo. Lan truyền nhất quán sau, không phải giao dịch xuyên DB. |

### Hợp đồng trạng thái

| Đối tượng | Chuyển trạng thái |
| --- | --- |
| Booking | PENDING → CONFIRMED / CANCELLED / EXPIRED; EXPIRED → CONFIRMED (xác minh trả muộn và còn ghế); CONFIRMED → REFUND_PENDING / CANCELLED; REFUND_PENDING → CONFIRMED / CANCELLED |
| Payment | PENDING → SUCCESS / FAILED; FAILED → SUCCESS (xác minh trả muộn); SUCCESS → REFUND_PENDING → REFUNDED; REFUND_PENDING → SUCCESS |
| Refund | PENDING → COMPLETED / REJECTED; REJECTED → PENDING (rạp huỷ sau) |
| Showtime | OPEN ↔ CLOSED; OPEN/CLOSED → CANCELLED |
| Notification | PENDING → SENT/FAILED; FAILED → SENT; readAt độc lập trạng thái gửi |

checkedInAt là thuộc tính vé đã xác nhận, không phải trạng thái vé riêng.

## 16. Xác thực và phân quyền

Gateway và service kiểm tra chữ ký/hạn/issuer/audience JWT. Mặc định: access 60 phút, refresh bảy ngày xoay khi dùng; OTP sáu số, năm phút, năm lần thử, chờ gửi lại 60 giây. Tài khoản do quản trị viên tạo bỏ OTP đăng ký. Mật khẩu và OTP băm BCrypt.

ApiClient gia hạn và thử lại yêu cầu bảo vệ một lần. Kiểm tra bảo vệ từ chối ACCOUNT_LOCKED (401), ROLE_CHANGED (403) hoặc AuthService lỗi (503). GET danh mục công khai không gắn bearer; client có phiên thăm /auth/me tối đa mỗi phút, bỏ qua lỗi sẵn sàng thông thường khi duyệt và xoá phiên khi khoá/đổi quyền. Đăng xuất xoá lưu trữ/thu hồi refresh; đặt lại/đổi mật khẩu thu hồi refresh cũ. Thu hồi refresh riêng không chứng nhận vô hiệu ngay mọi access token đã cấp.

## 17. Xử lý lỗi

| Mã / điều kiện | Xử lý |
| --- | --- |
| 400 | Hiện lỗi trường/nghiệp vụ; không đi tiếp |
| 401 | Gia hạn một lần nếu được; nếu không xoá phiên/đăng nhập; giữ lý do khoá/phiên |
| 403 | Từ chối vai trò/sở hữu; EMAIL_NOT_VERIFIED mở OTP; ROLE_CHANGED đăng nhập lại |
| 404 | Hiện thiếu bản ghi không lộ vé đánh giá của người khác |
| 409 | Giải thích xung đột ghế/trạng thái/giờ và tải lại trước thử |
| 429 | Tuân thủ Retry-After/đếm ngược; giữ đầu vào |
| 500 / 503 | Hiện lỗi dịch vụ có thể thử lại; không báo đặt/trả thành công sai |
| Timeout/mất mạng/JSON sai | Lỗi có giới hạn (timeout client 15 giây); thử lại và trạng thái chờ/lỗi đúng |
| Tải/rỗng/từ chối camera | Trạng thái rõ không dữ liệu giả; giữ nhập mã vé thủ công |

## 18. Yêu cầu phi chức năng

| ID | Yêu cầu | Phân bổ |
| --- | --- | --- |
| WEB-NFR-SEC-01 | Mật khẩu và OTP băm bằng BCrypt; không trả stack trace hay lỗi nội bộ ra response. | Web/backend |
| WEB-NFR-SEC-02 | JWT ký bằng secret ≥ 32 ký tự; access token 60 phút; refresh token 7 ngày, xoay vòng, thu hồi khi đăng xuất, đặt lại mật khẩu, đổi quyền. | Web/backend |
| WEB-NFR-SEC-03 | Kiểm tra quyền ở cả gateway (theo route) và service (theo dữ liệu, ví dụ chỉ xem vé của mình). | Web/backend |
| WEB-NFR-SEC-04 | Giới hạn tần suất: 100 request / phút / IP cho mọi API, 10 cho API xác thực. | Web/backend |
| WEB-NFR-SEC-05 | Chỉ gateway mở ra mạng; service, PostgreSQL, RabbitMQ, công cụ giám sát chỉ nghe `127.0.0.1`. | Web/backend |
| WEB-NFR-SEC-06 | Secret không nằm trong mã nguồn; chia sẻ bằng SOPS + age. | Web/backend |
| WEB-NFR-SEC-07 | Mọi input được kiểm tra ở server (DataAnnotations + validator); client kiểm tra trước để báo lỗi sớm. | Web/backend |
| WEB-NFR-PERF-01 | Endpoint phân trang giới hạn, thường 50; mảng thể loại/ghế/menu không áp dụng. UI vé chỉ tải trang đầu. SLA thời gian phản hồi/người đồng thời là [CẦN XÁC NHẬN], không phải bảo đảm đã đo. | Web/backend |
| WEB-NFR-PERF-02 | Giữ ghế, xác nhận vé và thu tiền khoá dòng booking (`SELECT … FOR UPDATE`) trong transaction để không bán trùng ghế hay thu tiền hai lần khi nhiều người thao tác cùng lúc. | Web/backend |
| WEB-NFR-REL-01 | Lời gọi MovieService / PayOS: thử lại tối đa 2 lần với lỗi tạm thời (riêng tạo link PayOS không thử lại); circuit breaker mở 15 giây khi lỗi liên tục và trả 503 ngay. | Web/backend |
| WEB-NFR-REL-02 | Outbox: event không mất khi RabbitMQ dừng, gửi bù khi RabbitMQ chạy lại. | Web/backend |
| WEB-NFR-REL-03 | Consumer idempotent; message lỗi thử lại 3 lần rồi chuyển sang DLQ. | Web/backend |
| WEB-NFR-REL-04 | Gateway kiểm tra `/health/live` của service mỗi 10 giây, service chết thì trả 503 ngay. | Web/backend |
| WEB-NFR-OBS-01 | Metrics Prometheus cho HTTP, runtime và nghiệp vụ (booking, payment, refund, outbox); dashboard Grafana "Cinema - Tổng quan". | Web/backend |
| WEB-NFR-OBS-02 | Trace OpenTelemetry → Jaeger, xuyên qua gateway, service, SQL, PayOS và RabbitMQ. | Web/backend |
| WEB-NFR-OBS-03 | Log có TraceId, SpanId, CorrelationId; header `X-Correlation-ID` trên mọi response. | Web/backend |
| WEB-NFR-MAINT-01 | Kiến trúc lớp, DTO, validator, global exception handler ở mọi service; tài liệu trong `docs/`. | Web/backend |
| WEB-NFR-MAINT-02 | CI khai báo test .NET, Flutter analyze/test và build web khách/quản trị. Workflow hiện ghim Flutter 3.47.4 thay mô tả cũ; không khẳng định CI hiện đã đạt. | Web/backend |
| WEB-NFR-DEP-01 | Một lệnh `docker compose up -d --build` chạy toàn bộ backend; giám sát qua profile `monitoring`. | Web/backend |
| WEB-NFR-USE-01 | App khách hỗ trợ Android, web, Windows; trang quản trị tối ưu cho máy tính và vẫn dùng được trên màn hình hẹp. | Web/backend |
| WEB-NFR-COMP-01 | Camera web cần `localhost` hoặc HTTPS; ứng dụng triển khai thật phải dùng HTTPS. | Web/backend |

Cơ chế NFR có thể có bằng chứng code; độ sẵn sàng, thông lượng, khả năng tiếp cận toàn diện và tương thích cần kiểm chứng khi chạy, không được xác lập qua kiểm tra tĩnh.

## 19. Yêu cầu bảo mật

| ID | Yêu cầu bảo mật và kiểm chứng |
| --- | --- |
| WEB-SEC-01 | Từ chối JWT giả/hết hạn/sai issuer và vai trò thiếu quyền tại gateway/service; thử đổi ID với kiểm tra sở hữu. |
| WEB-SEC-02 | Tính lại giá và kiểm tra cặp ghế/menu/mã/điểm trên server; không tin tổng client hoặc tham số chuyển hướng là đã trả. |
| WEB-SEC-03 | Xác minh HMAC PayOS trước tác động; thử webhook lặp, chữ ký sai, đơn lạ và lệch tiền. Giữ khoá nhà cung cấp trong backend. |
| WEB-SEC-04 | Dùng HTTPS triển khai và giới hạn CORS/phơi mạng service riêng. HTTP phát triển không chứng minh TLS production. |
| WEB-SEC-05 | Dùng lớp lưu bảo mật nền tảng; không nhúng secret backend vào client. Xoá/thu hồi thông tin khi đăng xuất/đặt lại và xử lý lưu trữ không đọc được như chưa đăng nhập. |
| WEB-SEC-06 | Mã hoá nội dung người trong email; không lộ stack trace/secret. Quên mật khẩu chung không có nghĩa mọi nơi chống dò email. |

## 20. Yêu cầu kiểm thử

Suy ra test từ AC-01/AC-02 từng FR. Tệp test hiện có chứng minh ý định bao phủ, không phải báo cáo vừa chạy. Fixture backend dùng PostgreSQL/RabbitMQ Testcontainers và giả lập phụ thuộc PayOS/SMTP/danh mục ngoài theo cấu hình. PayOS/SMTP thật, camera/chia sẻ/in cần nghiệm thu có kiểm soát riêng.

| ID | Kiểm thử bắt buộc |
| --- | --- |
| WEB-TEST-01 | Hạn/lần thử/gửi lại OTP; biên mật khẩu UTF-8; dùng lại refresh; khoá/đổi vai trò; sai chủ/vai trò. |
| WEB-TEST-02 | Hai giữ đồng thời một ghế: một thành công, một 409; không ghế/điểm dở dang. Từ chối nửa sweetbox. |
| WEB-TEST-03 | Trả thành công/huỷ/timeout, webhook chữ ký lặp, trả muộn còn/mất ghế; không UI báo đã trả sai. |
| WEB-TEST-04 | Huỷ đúng và quanh hai giờ; hoàn tất/từ chối/mở lại hoàn; một hoàn, giữ ghế đang chờ và đảo điểm. |
| WEB-TEST-05 | Check-in ngay trước/đúng/sau giới hạn giờ; hai quét đồng thời; tra tay sau từ chối camera. |
| WEB-TEST-06 | Khôi phục route, thiếu dữ liệu tạm, tải/rỗng/lỗi, timeout/thử lại, số chưa đọc và trở về từ app ngoài. |
| WEB-TEST-07 | Tiền mặt thiếu/thối, tranh chấp chuyển khoản-sang-tiền mặt, in 80 mm; trùng lịch; dữ liệu nền/doanh thu chỉ quản trị viên. |

### Bằng chứng test hiện có

| Khu / ca sử dụng | Tệp |
| --- | --- |
| UC-WEB-01 | [Cinema_BE/AuthService/AuthService.Tests/Integration/AccountValidationTests.cs](../Cinema_BE/AuthService/AuthService.Tests/Integration/AccountValidationTests.cs); [Cinema_BE/AuthService/AuthService.Tests/Integration/AuthFlowTests.cs](../Cinema_BE/AuthService/AuthService.Tests/Integration/AuthFlowTests.cs); [Cinema_Mobile/test/account_lock_flow_test.dart](../Cinema_Mobile/test/account_lock_flow_test.dart); [Cinema_Mobile/test/register_validation_test.dart](../Cinema_Mobile/test/register_validation_test.dart) |
| UC-WEB-02 | [Cinema_BE/AuthService/AuthService.Tests/Integration/UserManagementTests.cs](../Cinema_BE/AuthService/AuthService.Tests/Integration/UserManagementTests.cs); [Cinema_Mobile/test/admin_user_roles_test.dart](../Cinema_Mobile/test/admin_user_roles_test.dart) |
| UC-WEB-03 | [Cinema_BE/BookingService/BookingService.Tests/Integration/MovieReviewTests.cs](../Cinema_BE/BookingService/BookingService.Tests/Integration/MovieReviewTests.cs); [Cinema_Mobile/test/age_rating_test.dart](../Cinema_Mobile/test/age_rating_test.dart); [Cinema_Mobile/test/coming_soon_test.dart](../Cinema_Mobile/test/coming_soon_test.dart); [Cinema_Mobile/test/liquid_glass_responsive_preview_test.dart](../Cinema_Mobile/test/liquid_glass_responsive_preview_test.dart); [Cinema_Mobile/test/review_test.dart](../Cinema_Mobile/test/review_test.dart) |
| UC-WEB-04 | [Cinema_BE/BookingService/BookingService.Tests/Integration/ShowtimeReminderTests.cs](../Cinema_BE/BookingService/BookingService.Tests/Integration/ShowtimeReminderTests.cs); [Cinema_BE/MovieService/MovieService.Tests/Integration/SeatTests.cs](../Cinema_BE/MovieService/MovieService.Tests/Integration/SeatTests.cs); [Cinema_BE/MovieService/MovieService.Tests/Integration/ShowtimeFormatTests.cs](../Cinema_BE/MovieService/MovieService.Tests/Integration/ShowtimeFormatTests.cs); [Cinema_BE/MovieService/MovieService.Tests/Integration/ShowtimeTests.cs](../Cinema_BE/MovieService/MovieService.Tests/Integration/ShowtimeTests.cs); [Cinema_Mobile/test/seat_map_test.dart](../Cinema_Mobile/test/seat_map_test.dart); [Cinema_Mobile/test/showtime_format_test.dart](../Cinema_Mobile/test/showtime_format_test.dart) |
| UC-WEB-05 | [Cinema_BE/MovieService/MovieService.Tests/Integration/SeatTests.cs](../Cinema_BE/MovieService/MovieService.Tests/Integration/SeatTests.cs); [Cinema_Mobile/test/booking_flow_test.dart](../Cinema_Mobile/test/booking_flow_test.dart); [Cinema_Mobile/test/seat_map_test.dart](../Cinema_Mobile/test/seat_map_test.dart) |
| UC-WEB-06 | [Cinema_BE/BookingService/BookingService.Tests/Integration/ShowtimeReminderTests.cs](../Cinema_BE/BookingService/BookingService.Tests/Integration/ShowtimeReminderTests.cs); [Cinema_BE/MovieService/MovieService.Tests/Integration/ShowtimeFormatTests.cs](../Cinema_BE/MovieService/MovieService.Tests/Integration/ShowtimeFormatTests.cs); [Cinema_BE/MovieService/MovieService.Tests/Integration/ShowtimeTests.cs](../Cinema_BE/MovieService/MovieService.Tests/Integration/ShowtimeTests.cs); [Cinema_Mobile/test/showtime_format_test.dart](../Cinema_Mobile/test/showtime_format_test.dart) |
| UC-WEB-07 | [Cinema_BE/BookingService/BookingService.Tests/Integration/BookingFlowTests.cs](../Cinema_BE/BookingService/BookingService.Tests/Integration/BookingFlowTests.cs); [Cinema_BE/BookingService/BookingService.Tests/Integration/ConcessionTests.cs](../Cinema_BE/BookingService/BookingService.Tests/Integration/ConcessionTests.cs); [Cinema_BE/BookingService/BookingService.Tests/Integration/LoyaltyTests.cs](../Cinema_BE/BookingService/BookingService.Tests/Integration/LoyaltyTests.cs); [Cinema_BE/BookingService/BookingService.Tests/Integration/PromotionTests.cs](../Cinema_BE/BookingService/BookingService.Tests/Integration/PromotionTests.cs); [Cinema_Mobile/test/booking_flow_test.dart](../Cinema_Mobile/test/booking_flow_test.dart); [Cinema_Mobile/test/concession_test.dart](../Cinema_Mobile/test/concession_test.dart); [Cinema_Mobile/test/loyalty_test.dart](../Cinema_Mobile/test/loyalty_test.dart); [Cinema_Mobile/test/promotion_test.dart](../Cinema_Mobile/test/promotion_test.dart) |
| UC-WEB-08 | [Cinema_BE/BookingService/BookingService.Tests/Integration/BookingFlowTests.cs](../Cinema_BE/BookingService/BookingService.Tests/Integration/BookingFlowTests.cs); [Cinema_BE/BookingService/BookingService.Tests/Integration/PaymentSummaryTests.cs](../Cinema_BE/BookingService/BookingService.Tests/Integration/PaymentSummaryTests.cs); [Cinema_BE/BookingService/BookingService.Tests/Integration/PayOsOrderCodeTests.cs](../Cinema_BE/BookingService/BookingService.Tests/Integration/PayOsOrderCodeTests.cs); [Cinema_BE/BookingService/BookingService.Tests/Unit/PayOsSignatureTests.cs](../Cinema_BE/BookingService/BookingService.Tests/Unit/PayOsSignatureTests.cs); [Cinema_Mobile/test/booking_flow_test.dart](../Cinema_Mobile/test/booking_flow_test.dart) |
| UC-WEB-09 | [Cinema_BE/BookingService/BookingService.Tests/Integration/RefundTests.cs](../Cinema_BE/BookingService/BookingService.Tests/Integration/RefundTests.cs); [Cinema_Mobile/test/booking_details_ui_test.dart](../Cinema_Mobile/test/booking_details_ui_test.dart); [Cinema_Mobile/test/refund_details_ui_test.dart](../Cinema_Mobile/test/refund_details_ui_test.dart); [Cinema_Mobile/test/staff_booking_details_ui_test.dart](../Cinema_Mobile/test/staff_booking_details_ui_test.dart) |
| UC-WEB-10 | [Cinema_BE/BookingService/BookingService.Tests/Integration/CounterSaleTests.cs](../Cinema_BE/BookingService/BookingService.Tests/Integration/CounterSaleTests.cs); [Cinema_Mobile/test/counter_booking_test.dart](../Cinema_Mobile/test/counter_booking_test.dart) |
| UC-WEB-11 | [Cinema_BE/BookingService/BookingService.Tests/Integration/CheckInTests.cs](../Cinema_BE/BookingService/BookingService.Tests/Integration/CheckInTests.cs); [Cinema_Mobile/test/check_in_test.dart](../Cinema_Mobile/test/check_in_test.dart) |
| UC-WEB-12 | [Cinema_BE/BookingService/BookingService.Tests/Integration/ShowtimeReminderTests.cs](../Cinema_BE/BookingService/BookingService.Tests/Integration/ShowtimeReminderTests.cs); [Cinema_Mobile/test/notification_read_test.dart](../Cinema_Mobile/test/notification_read_test.dart) |
| UC-WEB-13 | [Cinema_BE/BookingService/BookingService.Tests/Integration/PaymentSummaryTests.cs](../Cinema_BE/BookingService/BookingService.Tests/Integration/PaymentSummaryTests.cs); [Cinema_Mobile/test/today_at_cinema_test.dart](../Cinema_Mobile/test/today_at_cinema_test.dart) |

## 21. Tiêu chí nghiệm thu

Mọi yêu cầu H phải đạt hai tiêu chí; test bảo mật, sở hữu, tài chính và đồng thời phải đạt. Công bố mọi thiếu sót M/L và khoảng trống triển khai. Tài liệu không chứng nhận lần chạy đạt.

| ID | Điều kiện nghiệm thu |
| --- | --- |
| WEB-ACC-01 | Chứng minh tài khoản → phim → suất → ghế → vé → trả → vé/thông báo với backend thật hoặc fixture có tài liệu. |
| WEB-ACC-02 | Từ chối truy cập trái phép tài khoản khác và tác động bán ghế/check-in/trả trùng đồng thời. |
| WEB-ACC-03 | Chứng minh kết quả hoàn và trả muộn với ghế/điểm đúng, không xác nhận vé sai. |
| WEB-ACC-04 | Kiểm tra điều hướng, tải/lỗi/rỗng và dự phòng thiết bị; công bố giới hạn mục 27. |

## 22. Ma trận truy vết yêu cầu

Ma trận FR đầy đủ. Mã nguồn yêu cầu cho phép truy ngược; NAV/STATE/MEDIA chi tiết hoá từ code. API liên kết theo khu chức năng, không khẳng định mỗi màn gọi mọi thao tác được liệt kê. Test hiện có là ứng viên bao phủ, không phải kết quả đo.

| Yêu cầu / nguồn | Quy tắc nghiệp vụ | Ca sử dụng | Màn hình | API | Tiêu chí / bằng chứng test |
| --- | --- | --- | --- | --- | --- |
| WEB-FR-AUTH-01 ← FR-AUTH-01 | WEB-BR-01, WEB-BR-02, WEB-BR-03, WEB-BR-24, WEB-BR-25 | UC-WEB-01 | WEB-SCR-REGISTER | WEB-API-033 | WEB-FR-AUTH-01-AC-01, WEB-FR-AUTH-01-AC-02; [Cinema_BE/AuthService/AuthService.Tests/Integration/AccountValidationTests.cs](../Cinema_BE/AuthService/AuthService.Tests/Integration/AccountValidationTests.cs); [Cinema_BE/AuthService/AuthService.Tests/Integration/AuthFlowTests.cs](../Cinema_BE/AuthService/AuthService.Tests/Integration/AuthFlowTests.cs); [Cinema_Mobile/test/account_lock_flow_test.dart](../Cinema_Mobile/test/account_lock_flow_test.dart) |
| WEB-FR-AUTH-02 ← FR-AUTH-02 | WEB-BR-01, WEB-BR-02, WEB-BR-03, WEB-BR-24, WEB-BR-25 | UC-WEB-01 | WEB-SCR-LOGIN | WEB-API-027 | WEB-FR-AUTH-02-AC-01, WEB-FR-AUTH-02-AC-02; [Cinema_BE/AuthService/AuthService.Tests/Integration/AccountValidationTests.cs](../Cinema_BE/AuthService/AuthService.Tests/Integration/AccountValidationTests.cs); [Cinema_BE/AuthService/AuthService.Tests/Integration/AuthFlowTests.cs](../Cinema_BE/AuthService/AuthService.Tests/Integration/AuthFlowTests.cs); [Cinema_Mobile/test/account_lock_flow_test.dart](../Cinema_Mobile/test/account_lock_flow_test.dart) |
| WEB-FR-AUTH-03 ← FR-AUTH-03 | WEB-BR-01, WEB-BR-02, WEB-BR-03, WEB-BR-24, WEB-BR-25 | UC-WEB-01 | WEB-SCR-LOGIN | WEB-API-027, WEB-API-032 | WEB-FR-AUTH-03-AC-01, WEB-FR-AUTH-03-AC-02; [Cinema_BE/AuthService/AuthService.Tests/Integration/AccountValidationTests.cs](../Cinema_BE/AuthService/AuthService.Tests/Integration/AccountValidationTests.cs); [Cinema_BE/AuthService/AuthService.Tests/Integration/AuthFlowTests.cs](../Cinema_BE/AuthService/AuthService.Tests/Integration/AuthFlowTests.cs); [Cinema_Mobile/test/account_lock_flow_test.dart](../Cinema_Mobile/test/account_lock_flow_test.dart) |
| WEB-FR-AUTH-04 ← FR-AUTH-04 | WEB-BR-01, WEB-BR-02, WEB-BR-03, WEB-BR-24, WEB-BR-25 | UC-WEB-01 |  | WEB-API-029 | WEB-FR-AUTH-04-AC-01, WEB-FR-AUTH-04-AC-02; [Cinema_BE/AuthService/AuthService.Tests/Integration/AccountValidationTests.cs](../Cinema_BE/AuthService/AuthService.Tests/Integration/AccountValidationTests.cs); [Cinema_BE/AuthService/AuthService.Tests/Integration/AuthFlowTests.cs](../Cinema_BE/AuthService/AuthService.Tests/Integration/AuthFlowTests.cs); [Cinema_Mobile/test/account_lock_flow_test.dart](../Cinema_Mobile/test/account_lock_flow_test.dart) |
| WEB-FR-AUTH-05 ← FR-AUTH-05 | WEB-BR-01, WEB-BR-02, WEB-BR-03, WEB-BR-24, WEB-BR-25 | UC-WEB-01 | WEB-SCR-STAFF-ONLY | WEB-API-029 | WEB-FR-AUTH-05-AC-01, WEB-FR-AUTH-05-AC-02; [Cinema_BE/AuthService/AuthService.Tests/Integration/AccountValidationTests.cs](../Cinema_BE/AuthService/AuthService.Tests/Integration/AccountValidationTests.cs); [Cinema_BE/AuthService/AuthService.Tests/Integration/AuthFlowTests.cs](../Cinema_BE/AuthService/AuthService.Tests/Integration/AuthFlowTests.cs); [Cinema_Mobile/test/account_lock_flow_test.dart](../Cinema_Mobile/test/account_lock_flow_test.dart) |
| WEB-FR-AUTH-06 ← FR-AUTH-06 | WEB-BR-01, WEB-BR-02, WEB-BR-03, WEB-BR-24, WEB-BR-25 | UC-WEB-01 | WEB-SCR-LOGIN | WEB-API-029 | WEB-FR-AUTH-06-AC-01, WEB-FR-AUTH-06-AC-02; [Cinema_BE/AuthService/AuthService.Tests/Integration/AccountValidationTests.cs](../Cinema_BE/AuthService/AuthService.Tests/Integration/AccountValidationTests.cs); [Cinema_BE/AuthService/AuthService.Tests/Integration/AuthFlowTests.cs](../Cinema_BE/AuthService/AuthService.Tests/Integration/AuthFlowTests.cs); [Cinema_Mobile/test/account_lock_flow_test.dart](../Cinema_Mobile/test/account_lock_flow_test.dart) |
| WEB-FR-AUTH-07 ← FR-AUTH-07 | WEB-BR-01, WEB-BR-02, WEB-BR-03, WEB-BR-24, WEB-BR-25 | UC-WEB-01 | WEB-SCR-VERIFY | WEB-API-034, WEB-API-042 | WEB-FR-AUTH-07-AC-01, WEB-FR-AUTH-07-AC-02; [Cinema_BE/AuthService/AuthService.Tests/Integration/AccountValidationTests.cs](../Cinema_BE/AuthService/AuthService.Tests/Integration/AccountValidationTests.cs); [Cinema_BE/AuthService/AuthService.Tests/Integration/AuthFlowTests.cs](../Cinema_BE/AuthService/AuthService.Tests/Integration/AuthFlowTests.cs); [Cinema_Mobile/test/account_lock_flow_test.dart](../Cinema_Mobile/test/account_lock_flow_test.dart) |
| WEB-FR-AUTH-08 ← FR-AUTH-08 | WEB-BR-01, WEB-BR-02, WEB-BR-03, WEB-BR-24, WEB-BR-25 | UC-WEB-01 | WEB-SCR-REGISTER, WEB-SCR-VERIFY | WEB-API-033 | WEB-FR-AUTH-08-AC-01, WEB-FR-AUTH-08-AC-02; [Cinema_BE/AuthService/AuthService.Tests/Integration/AccountValidationTests.cs](../Cinema_BE/AuthService/AuthService.Tests/Integration/AccountValidationTests.cs); [Cinema_BE/AuthService/AuthService.Tests/Integration/AuthFlowTests.cs](../Cinema_BE/AuthService/AuthService.Tests/Integration/AuthFlowTests.cs); [Cinema_Mobile/test/account_lock_flow_test.dart](../Cinema_Mobile/test/account_lock_flow_test.dart) |
| WEB-FR-AUTH-09 ← FR-AUTH-09 | WEB-BR-01, WEB-BR-02, WEB-BR-03, WEB-BR-24, WEB-BR-25 | UC-WEB-01 | WEB-SCR-FORGOT, WEB-SCR-RESET | WEB-API-026, WEB-API-035 | WEB-FR-AUTH-09-AC-01, WEB-FR-AUTH-09-AC-02; [Cinema_BE/AuthService/AuthService.Tests/Integration/AccountValidationTests.cs](../Cinema_BE/AuthService/AuthService.Tests/Integration/AccountValidationTests.cs); [Cinema_BE/AuthService/AuthService.Tests/Integration/AuthFlowTests.cs](../Cinema_BE/AuthService/AuthService.Tests/Integration/AuthFlowTests.cs); [Cinema_Mobile/test/account_lock_flow_test.dart](../Cinema_Mobile/test/account_lock_flow_test.dart) |
| WEB-FR-AUTH-10 ← FR-AUTH-10 | WEB-BR-01, WEB-BR-02, WEB-BR-03, WEB-BR-24, WEB-BR-25 | UC-WEB-01 | WEB-SCR-PROFILE, WEB-SCR-MGT-PROFILE | WEB-API-028, WEB-API-032 | WEB-FR-AUTH-10-AC-01, WEB-FR-AUTH-10-AC-02; [Cinema_BE/AuthService/AuthService.Tests/Integration/AccountValidationTests.cs](../Cinema_BE/AuthService/AuthService.Tests/Integration/AccountValidationTests.cs); [Cinema_BE/AuthService/AuthService.Tests/Integration/AuthFlowTests.cs](../Cinema_BE/AuthService/AuthService.Tests/Integration/AuthFlowTests.cs); [Cinema_Mobile/test/account_lock_flow_test.dart](../Cinema_Mobile/test/account_lock_flow_test.dart) |
| WEB-FR-AUTH-11 ← FR-AUTH-11 | WEB-BR-01, WEB-BR-02, WEB-BR-03, WEB-BR-24, WEB-BR-25 | UC-WEB-01 | WEB-SCR-PROFILE, WEB-SCR-MGT-PROFILE | WEB-API-029 | WEB-FR-AUTH-11-AC-01, WEB-FR-AUTH-11-AC-02; [Cinema_BE/AuthService/AuthService.Tests/Integration/AccountValidationTests.cs](../Cinema_BE/AuthService/AuthService.Tests/Integration/AccountValidationTests.cs); [Cinema_BE/AuthService/AuthService.Tests/Integration/AuthFlowTests.cs](../Cinema_BE/AuthService/AuthService.Tests/Integration/AuthFlowTests.cs); [Cinema_Mobile/test/account_lock_flow_test.dart](../Cinema_Mobile/test/account_lock_flow_test.dart) |
| WEB-FR-AUTH-12 ← FR-AUTH-12 | WEB-BR-01, WEB-BR-02, WEB-BR-03, WEB-BR-24, WEB-BR-25 | UC-WEB-01 | WEB-SCR-LOGIN | WEB-API-029 | WEB-FR-AUTH-12-AC-01, WEB-FR-AUTH-12-AC-02; [Cinema_BE/AuthService/AuthService.Tests/Integration/AccountValidationTests.cs](../Cinema_BE/AuthService/AuthService.Tests/Integration/AccountValidationTests.cs); [Cinema_BE/AuthService/AuthService.Tests/Integration/AuthFlowTests.cs](../Cinema_BE/AuthService/AuthService.Tests/Integration/AuthFlowTests.cs); [Cinema_Mobile/test/account_lock_flow_test.dart](../Cinema_Mobile/test/account_lock_flow_test.dart) |
| WEB-FR-AUTH-13 ← FR-AUTH-13 | WEB-BR-01, WEB-BR-02, WEB-BR-03, WEB-BR-24, WEB-BR-25 | UC-WEB-01 | WEB-SCR-LOGIN, WEB-SCR-REGISTER, WEB-SCR-FORGOT, WEB-SCR-RESET, WEB-SCR-USER-EDITOR | WEB-API-027, WEB-API-033, WEB-API-035, WEB-API-041 | WEB-FR-AUTH-13-AC-01, WEB-FR-AUTH-13-AC-02; [Cinema_BE/AuthService/AuthService.Tests/Integration/AccountValidationTests.cs](../Cinema_BE/AuthService/AuthService.Tests/Integration/AccountValidationTests.cs); [Cinema_BE/AuthService/AuthService.Tests/Integration/AuthFlowTests.cs](../Cinema_BE/AuthService/AuthService.Tests/Integration/AuthFlowTests.cs); [Cinema_Mobile/test/account_lock_flow_test.dart](../Cinema_Mobile/test/account_lock_flow_test.dart) |
| WEB-FR-AUTH-14 ← FR-AUTH-14 | WEB-BR-01, WEB-BR-02, WEB-BR-03, WEB-BR-24, WEB-BR-25 | UC-WEB-01 | WEB-SCR-VERIFY, WEB-SCR-FORGOT, WEB-SCR-RESET | WEB-API-027, WEB-API-032, WEB-API-034 | WEB-FR-AUTH-14-AC-01, WEB-FR-AUTH-14-AC-02; [Cinema_BE/AuthService/AuthService.Tests/Integration/AccountValidationTests.cs](../Cinema_BE/AuthService/AuthService.Tests/Integration/AccountValidationTests.cs); [Cinema_BE/AuthService/AuthService.Tests/Integration/AuthFlowTests.cs](../Cinema_BE/AuthService/AuthService.Tests/Integration/AuthFlowTests.cs); [Cinema_Mobile/test/account_lock_flow_test.dart](../Cinema_Mobile/test/account_lock_flow_test.dart) |
| WEB-FR-AUTH-15 ← FR-AUTH-15 | WEB-BR-01, WEB-BR-02, WEB-BR-03, WEB-BR-24, WEB-BR-25 | UC-WEB-01 | WEB-SCR-COUNTER | WEB-API-030 | WEB-FR-AUTH-15-AC-01, WEB-FR-AUTH-15-AC-02; [Cinema_BE/AuthService/AuthService.Tests/Integration/AccountValidationTests.cs](../Cinema_BE/AuthService/AuthService.Tests/Integration/AccountValidationTests.cs); [Cinema_BE/AuthService/AuthService.Tests/Integration/AuthFlowTests.cs](../Cinema_BE/AuthService/AuthService.Tests/Integration/AuthFlowTests.cs); [Cinema_Mobile/test/account_lock_flow_test.dart](../Cinema_Mobile/test/account_lock_flow_test.dart) |
| WEB-FR-AUTH-16 ← FR-AUTH-16 | WEB-BR-01, WEB-BR-02, WEB-BR-03, WEB-BR-24, WEB-BR-25 | UC-WEB-01 | WEB-SCR-PROFILE, WEB-SCR-MGT-PROFILE | WEB-API-031 | WEB-FR-AUTH-16-AC-01, WEB-FR-AUTH-16-AC-02; [Cinema_BE/AuthService/AuthService.Tests/Integration/AccountValidationTests.cs](../Cinema_BE/AuthService/AuthService.Tests/Integration/AccountValidationTests.cs); [Cinema_BE/AuthService/AuthService.Tests/Integration/AuthFlowTests.cs](../Cinema_BE/AuthService/AuthService.Tests/Integration/AuthFlowTests.cs); [Cinema_Mobile/test/account_lock_flow_test.dart](../Cinema_Mobile/test/account_lock_flow_test.dart) |
| WEB-FR-AUTH-17 ← FR-AUTH-17 | WEB-BR-01, WEB-BR-02, WEB-BR-03, WEB-BR-24, WEB-BR-25 | UC-WEB-01 | WEB-SCR-PROFILE, WEB-SCR-MGT-PROFILE | WEB-API-025 | WEB-FR-AUTH-17-AC-01, WEB-FR-AUTH-17-AC-02; [Cinema_BE/AuthService/AuthService.Tests/Integration/AccountValidationTests.cs](../Cinema_BE/AuthService/AuthService.Tests/Integration/AccountValidationTests.cs); [Cinema_BE/AuthService/AuthService.Tests/Integration/AuthFlowTests.cs](../Cinema_BE/AuthService/AuthService.Tests/Integration/AuthFlowTests.cs); [Cinema_Mobile/test/account_lock_flow_test.dart](../Cinema_Mobile/test/account_lock_flow_test.dart) |
| WEB-FR-USER-01 ← FR-USER-01 | WEB-BR-03, WEB-BR-24 | UC-WEB-02 | WEB-SCR-ADMIN-USERS | WEB-API-040 | WEB-FR-USER-01-AC-01, WEB-FR-USER-01-AC-02; [Cinema_BE/AuthService/AuthService.Tests/Integration/UserManagementTests.cs](../Cinema_BE/AuthService/AuthService.Tests/Integration/UserManagementTests.cs); [Cinema_Mobile/test/admin_user_roles_test.dart](../Cinema_Mobile/test/admin_user_roles_test.dart) |
| WEB-FR-USER-02 ← FR-USER-02 | WEB-BR-03, WEB-BR-24 | UC-WEB-02 | WEB-SCR-USER-EDITOR | WEB-API-039 | WEB-FR-USER-02-AC-01, WEB-FR-USER-02-AC-02; [Cinema_BE/AuthService/AuthService.Tests/Integration/UserManagementTests.cs](../Cinema_BE/AuthService/AuthService.Tests/Integration/UserManagementTests.cs); [Cinema_Mobile/test/admin_user_roles_test.dart](../Cinema_Mobile/test/admin_user_roles_test.dart) |
| WEB-FR-USER-03 ← FR-USER-03 | WEB-BR-03, WEB-BR-24 | UC-WEB-02 | WEB-SCR-USER-EDITOR | WEB-API-041 | WEB-FR-USER-03-AC-01, WEB-FR-USER-03-AC-02; [Cinema_BE/AuthService/AuthService.Tests/Integration/UserManagementTests.cs](../Cinema_BE/AuthService/AuthService.Tests/Integration/UserManagementTests.cs); [Cinema_Mobile/test/admin_user_roles_test.dart](../Cinema_Mobile/test/admin_user_roles_test.dart) |
| WEB-FR-USER-04 ← FR-USER-04 | WEB-BR-03, WEB-BR-24 | UC-WEB-02 | WEB-SCR-USER-EDITOR | WEB-API-037 | WEB-FR-USER-04-AC-01, WEB-FR-USER-04-AC-02; [Cinema_BE/AuthService/AuthService.Tests/Integration/UserManagementTests.cs](../Cinema_BE/AuthService/AuthService.Tests/Integration/UserManagementTests.cs); [Cinema_Mobile/test/admin_user_roles_test.dart](../Cinema_Mobile/test/admin_user_roles_test.dart) |
| WEB-FR-USER-05 ← FR-USER-05 | WEB-BR-03, WEB-BR-24 | UC-WEB-02 | WEB-SCR-USER-EDITOR | WEB-API-038 | WEB-FR-USER-05-AC-01, WEB-FR-USER-05-AC-02; [Cinema_BE/AuthService/AuthService.Tests/Integration/UserManagementTests.cs](../Cinema_BE/AuthService/AuthService.Tests/Integration/UserManagementTests.cs); [Cinema_Mobile/test/admin_user_roles_test.dart](../Cinema_Mobile/test/admin_user_roles_test.dart) |
| WEB-FR-USER-06 ← FR-USER-06 | WEB-BR-03, WEB-BR-24 | UC-WEB-02 | WEB-SCR-ADMIN-USERS, WEB-SCR-USER-EDITOR | WEB-API-036 | WEB-FR-USER-06-AC-01, WEB-FR-USER-06-AC-02; [Cinema_BE/AuthService/AuthService.Tests/Integration/UserManagementTests.cs](../Cinema_BE/AuthService/AuthService.Tests/Integration/UserManagementTests.cs); [Cinema_Mobile/test/admin_user_roles_test.dart](../Cinema_Mobile/test/admin_user_roles_test.dart) |
| WEB-FR-MOV-01 ← FR-MOV-01 | WEB-BR-26 | UC-WEB-03 | WEB-SCR-ADMIN-MOVIES | WEB-API-070 | WEB-FR-MOV-01-AC-01, WEB-FR-MOV-01-AC-02; [Cinema_BE/BookingService/BookingService.Tests/Integration/MovieReviewTests.cs](../Cinema_BE/BookingService/BookingService.Tests/Integration/MovieReviewTests.cs); [Cinema_Mobile/test/age_rating_test.dart](../Cinema_Mobile/test/age_rating_test.dart); [Cinema_Mobile/test/coming_soon_test.dart](../Cinema_Mobile/test/coming_soon_test.dart) |
| WEB-FR-MOV-02 ← FR-MOV-02 | WEB-BR-26 | UC-WEB-03 | WEB-SCR-MOVIE, WEB-SCR-ADMIN-MOVIES | WEB-API-064 | WEB-FR-MOV-02-AC-01, WEB-FR-MOV-02-AC-02; [Cinema_BE/BookingService/BookingService.Tests/Integration/MovieReviewTests.cs](../Cinema_BE/BookingService/BookingService.Tests/Integration/MovieReviewTests.cs); [Cinema_Mobile/test/age_rating_test.dart](../Cinema_Mobile/test/age_rating_test.dart); [Cinema_Mobile/test/coming_soon_test.dart](../Cinema_Mobile/test/coming_soon_test.dart) |
| WEB-FR-MOV-03 ← FR-MOV-03 | WEB-BR-26 | UC-WEB-03 | WEB-SCR-HOME, WEB-SCR-ADMIN-MOVIES | WEB-API-066, WEB-API-068 | WEB-FR-MOV-03-AC-01, WEB-FR-MOV-03-AC-02; [Cinema_BE/BookingService/BookingService.Tests/Integration/MovieReviewTests.cs](../Cinema_BE/BookingService/BookingService.Tests/Integration/MovieReviewTests.cs); [Cinema_Mobile/test/age_rating_test.dart](../Cinema_Mobile/test/age_rating_test.dart); [Cinema_Mobile/test/coming_soon_test.dart](../Cinema_Mobile/test/coming_soon_test.dart) |
| WEB-FR-MOV-04 ← FR-MOV-04 | WEB-BR-26 | UC-WEB-03 | WEB-SCR-HOME, WEB-SCR-ADMIN-MOVIES | WEB-API-066, WEB-API-069 | WEB-FR-MOV-04-AC-01, WEB-FR-MOV-04-AC-02; [Cinema_BE/BookingService/BookingService.Tests/Integration/MovieReviewTests.cs](../Cinema_BE/BookingService/BookingService.Tests/Integration/MovieReviewTests.cs); [Cinema_Mobile/test/age_rating_test.dart](../Cinema_Mobile/test/age_rating_test.dart); [Cinema_Mobile/test/coming_soon_test.dart](../Cinema_Mobile/test/coming_soon_test.dart) |
| WEB-FR-MOV-05 ← FR-MOV-05 | WEB-BR-26 | UC-WEB-03 | WEB-SCR-ADMIN-MOVIES | WEB-API-071 | WEB-FR-MOV-05-AC-01, WEB-FR-MOV-05-AC-02; [Cinema_BE/BookingService/BookingService.Tests/Integration/MovieReviewTests.cs](../Cinema_BE/BookingService/BookingService.Tests/Integration/MovieReviewTests.cs); [Cinema_Mobile/test/age_rating_test.dart](../Cinema_Mobile/test/age_rating_test.dart); [Cinema_Mobile/test/coming_soon_test.dart](../Cinema_Mobile/test/coming_soon_test.dart) |
| WEB-FR-MOV-06 ← FR-MOV-06 | WEB-BR-26 | UC-WEB-03 | WEB-SCR-ADMIN-MOVIES | WEB-API-065 | WEB-FR-MOV-06-AC-01, WEB-FR-MOV-06-AC-02; [Cinema_BE/BookingService/BookingService.Tests/Integration/MovieReviewTests.cs](../Cinema_BE/BookingService/BookingService.Tests/Integration/MovieReviewTests.cs); [Cinema_Mobile/test/age_rating_test.dart](../Cinema_Mobile/test/age_rating_test.dart); [Cinema_Mobile/test/coming_soon_test.dart](../Cinema_Mobile/test/coming_soon_test.dart) |
| WEB-FR-MOV-07 ← FR-MOV-07 | WEB-BR-26 | UC-WEB-03 | WEB-SCR-ADMIN-MOVIES | WEB-API-063 | WEB-FR-MOV-07-AC-01, WEB-FR-MOV-07-AC-02; [Cinema_BE/BookingService/BookingService.Tests/Integration/MovieReviewTests.cs](../Cinema_BE/BookingService/BookingService.Tests/Integration/MovieReviewTests.cs); [Cinema_Mobile/test/age_rating_test.dart](../Cinema_Mobile/test/age_rating_test.dart); [Cinema_Mobile/test/coming_soon_test.dart](../Cinema_Mobile/test/coming_soon_test.dart) |
| WEB-FR-MOV-08 ← FR-MOV-08 | WEB-BR-26 | UC-WEB-03 | WEB-SCR-MOVIE | WEB-API-064 | WEB-FR-MOV-08-AC-01, WEB-FR-MOV-08-AC-02; [Cinema_BE/BookingService/BookingService.Tests/Integration/MovieReviewTests.cs](../Cinema_BE/BookingService/BookingService.Tests/Integration/MovieReviewTests.cs); [Cinema_Mobile/test/age_rating_test.dart](../Cinema_Mobile/test/age_rating_test.dart); [Cinema_Mobile/test/coming_soon_test.dart](../Cinema_Mobile/test/coming_soon_test.dart) |
| WEB-FR-MOV-09 ← FR-MOV-09 | WEB-BR-26 | UC-WEB-03 | WEB-SCR-MOVIE, WEB-SCR-SUMMARY, WEB-SCR-CHECKIN, WEB-SCR-ADMIN-MOVIES | WEB-API-064, WEB-API-065, WEB-API-071 | WEB-FR-MOV-09-AC-01, WEB-FR-MOV-09-AC-02; [Cinema_BE/BookingService/BookingService.Tests/Integration/MovieReviewTests.cs](../Cinema_BE/BookingService/BookingService.Tests/Integration/MovieReviewTests.cs); [Cinema_Mobile/test/age_rating_test.dart](../Cinema_Mobile/test/age_rating_test.dart); [Cinema_Mobile/test/coming_soon_test.dart](../Cinema_Mobile/test/coming_soon_test.dart) |
| WEB-FR-MOV-10 ← FR-MOV-10 | WEB-BR-26 | UC-WEB-03 | WEB-SCR-HOME | WEB-API-066, WEB-API-067 | WEB-FR-MOV-10-AC-01, WEB-FR-MOV-10-AC-02; [Cinema_BE/BookingService/BookingService.Tests/Integration/MovieReviewTests.cs](../Cinema_BE/BookingService/BookingService.Tests/Integration/MovieReviewTests.cs); [Cinema_Mobile/test/age_rating_test.dart](../Cinema_Mobile/test/age_rating_test.dart); [Cinema_Mobile/test/coming_soon_test.dart](../Cinema_Mobile/test/coming_soon_test.dart) |
| WEB-FR-MOV-11 ← FR-MOV-11 | WEB-BR-26 | UC-WEB-03 | WEB-SCR-MOVIE, WEB-SCR-ADMIN-MOVIES | WEB-API-064, WEB-API-065, WEB-API-071 | WEB-FR-MOV-11-AC-01, WEB-FR-MOV-11-AC-02; [Cinema_BE/BookingService/BookingService.Tests/Integration/MovieReviewTests.cs](../Cinema_BE/BookingService/BookingService.Tests/Integration/MovieReviewTests.cs); [Cinema_Mobile/test/age_rating_test.dart](../Cinema_Mobile/test/age_rating_test.dart); [Cinema_Mobile/test/coming_soon_test.dart](../Cinema_Mobile/test/coming_soon_test.dart) |
| WEB-FR-MOV-12 ← FR-MOV-12 | WEB-BR-26 | UC-WEB-03 | WEB-SCR-MOVIE, WEB-SCR-TICKET, WEB-SCR-ADMIN-MOVIES | WEB-API-102, WEB-API-103, WEB-API-105, WEB-API-106 | WEB-FR-MOV-12-AC-01, WEB-FR-MOV-12-AC-02; [Cinema_BE/BookingService/BookingService.Tests/Integration/MovieReviewTests.cs](../Cinema_BE/BookingService/BookingService.Tests/Integration/MovieReviewTests.cs); [Cinema_Mobile/test/age_rating_test.dart](../Cinema_Mobile/test/age_rating_test.dart); [Cinema_Mobile/test/coming_soon_test.dart](../Cinema_Mobile/test/coming_soon_test.dart) |
| WEB-FR-ROOM-01 ← FR-ROOM-01 | WEB-BR-04, WEB-BR-26 | UC-WEB-04 | WEB-SCR-OPERATIONS, WEB-SCR-ADMIN-ROOMS | WEB-API-004, WEB-API-005 | WEB-FR-ROOM-01-AC-01, WEB-FR-ROOM-01-AC-02; [Cinema_BE/BookingService/BookingService.Tests/Integration/ShowtimeReminderTests.cs](../Cinema_BE/BookingService/BookingService.Tests/Integration/ShowtimeReminderTests.cs); [Cinema_BE/MovieService/MovieService.Tests/Integration/SeatTests.cs](../Cinema_BE/MovieService/MovieService.Tests/Integration/SeatTests.cs); [Cinema_BE/MovieService/MovieService.Tests/Integration/ShowtimeFormatTests.cs](../Cinema_BE/MovieService/MovieService.Tests/Integration/ShowtimeFormatTests.cs) |
| WEB-FR-ROOM-02 ← FR-ROOM-02 | WEB-BR-04, WEB-BR-26 | UC-WEB-04 | WEB-SCR-RECORD-ROOMS, WEB-SCR-ADMIN-ROOMS | WEB-API-002, WEB-API-013 | WEB-FR-ROOM-02-AC-01, WEB-FR-ROOM-02-AC-02; [Cinema_BE/BookingService/BookingService.Tests/Integration/ShowtimeReminderTests.cs](../Cinema_BE/BookingService/BookingService.Tests/Integration/ShowtimeReminderTests.cs); [Cinema_BE/MovieService/MovieService.Tests/Integration/SeatTests.cs](../Cinema_BE/MovieService/MovieService.Tests/Integration/SeatTests.cs); [Cinema_BE/MovieService/MovieService.Tests/Integration/ShowtimeFormatTests.cs](../Cinema_BE/MovieService/MovieService.Tests/Integration/ShowtimeFormatTests.cs) |
| WEB-FR-ROOM-03 ← FR-ROOM-03 | WEB-BR-04, WEB-BR-26 | UC-WEB-04 | WEB-SCR-ADMIN-ROOMS | WEB-API-006, WEB-API-010 | WEB-FR-ROOM-03-AC-01, WEB-FR-ROOM-03-AC-02; [Cinema_BE/BookingService/BookingService.Tests/Integration/ShowtimeReminderTests.cs](../Cinema_BE/BookingService/BookingService.Tests/Integration/ShowtimeReminderTests.cs); [Cinema_BE/MovieService/MovieService.Tests/Integration/SeatTests.cs](../Cinema_BE/MovieService/MovieService.Tests/Integration/SeatTests.cs); [Cinema_BE/MovieService/MovieService.Tests/Integration/ShowtimeFormatTests.cs](../Cinema_BE/MovieService/MovieService.Tests/Integration/ShowtimeFormatTests.cs) |
| WEB-FR-ROOM-04 ← FR-ROOM-04 | WEB-BR-04, WEB-BR-26 | UC-WEB-04 | WEB-SCR-ADMIN-ROOMS | WEB-API-003 | WEB-FR-ROOM-04-AC-01, WEB-FR-ROOM-04-AC-02; [Cinema_BE/BookingService/BookingService.Tests/Integration/ShowtimeReminderTests.cs](../Cinema_BE/BookingService/BookingService.Tests/Integration/ShowtimeReminderTests.cs); [Cinema_BE/MovieService/MovieService.Tests/Integration/SeatTests.cs](../Cinema_BE/MovieService/MovieService.Tests/Integration/SeatTests.cs); [Cinema_BE/MovieService/MovieService.Tests/Integration/ShowtimeFormatTests.cs](../Cinema_BE/MovieService/MovieService.Tests/Integration/ShowtimeFormatTests.cs) |
| WEB-FR-ROOM-05 ← FR-ROOM-05 | WEB-BR-04, WEB-BR-26 | UC-WEB-04 | WEB-SCR-ADMIN-ROOMS | WEB-API-001 | WEB-FR-ROOM-05-AC-01, WEB-FR-ROOM-05-AC-02; [Cinema_BE/BookingService/BookingService.Tests/Integration/ShowtimeReminderTests.cs](../Cinema_BE/BookingService/BookingService.Tests/Integration/ShowtimeReminderTests.cs); [Cinema_BE/MovieService/MovieService.Tests/Integration/SeatTests.cs](../Cinema_BE/MovieService/MovieService.Tests/Integration/SeatTests.cs); [Cinema_BE/MovieService/MovieService.Tests/Integration/ShowtimeFormatTests.cs](../Cinema_BE/MovieService/MovieService.Tests/Integration/ShowtimeFormatTests.cs) |
| WEB-FR-SEAT-01 ← FR-SEAT-01 | WEB-BR-04, WEB-BR-07, WEB-BR-15, WEB-BR-16, WEB-BR-26 | UC-WEB-05 | WEB-SCR-RECORD-ROOMS | WEB-API-010 | WEB-FR-SEAT-01-AC-01, WEB-FR-SEAT-01-AC-02; [Cinema_BE/MovieService/MovieService.Tests/Integration/SeatTests.cs](../Cinema_BE/MovieService/MovieService.Tests/Integration/SeatTests.cs); [Cinema_Mobile/test/booking_flow_test.dart](../Cinema_Mobile/test/booking_flow_test.dart); [Cinema_Mobile/test/seat_map_test.dart](../Cinema_Mobile/test/seat_map_test.dart) |
| WEB-FR-SEAT-02 ← FR-SEAT-02 | WEB-BR-04, WEB-BR-07, WEB-BR-15, WEB-BR-16, WEB-BR-26 | UC-WEB-05 | WEB-SCR-RECORD-ROOMS | WEB-API-009 | WEB-FR-SEAT-02-AC-01, WEB-FR-SEAT-02-AC-02; [Cinema_BE/MovieService/MovieService.Tests/Integration/SeatTests.cs](../Cinema_BE/MovieService/MovieService.Tests/Integration/SeatTests.cs); [Cinema_Mobile/test/booking_flow_test.dart](../Cinema_Mobile/test/booking_flow_test.dart); [Cinema_Mobile/test/seat_map_test.dart](../Cinema_Mobile/test/seat_map_test.dart) |
| WEB-FR-SEAT-03 ← FR-SEAT-03 | WEB-BR-04, WEB-BR-07, WEB-BR-15, WEB-BR-16, WEB-BR-26 | UC-WEB-05 | WEB-SCR-SEATS, WEB-SCR-RECORD-ROOMS | WEB-API-013 | WEB-FR-SEAT-03-AC-01, WEB-FR-SEAT-03-AC-02; [Cinema_BE/MovieService/MovieService.Tests/Integration/SeatTests.cs](../Cinema_BE/MovieService/MovieService.Tests/Integration/SeatTests.cs); [Cinema_Mobile/test/booking_flow_test.dart](../Cinema_Mobile/test/booking_flow_test.dart); [Cinema_Mobile/test/seat_map_test.dart](../Cinema_Mobile/test/seat_map_test.dart) |
| WEB-FR-SEAT-04 ← FR-SEAT-04 | WEB-BR-04, WEB-BR-07, WEB-BR-15, WEB-BR-16, WEB-BR-26 | UC-WEB-05 |  | WEB-API-008 | WEB-FR-SEAT-04-AC-01, WEB-FR-SEAT-04-AC-02; [Cinema_BE/MovieService/MovieService.Tests/Integration/SeatTests.cs](../Cinema_BE/MovieService/MovieService.Tests/Integration/SeatTests.cs); [Cinema_Mobile/test/booking_flow_test.dart](../Cinema_Mobile/test/booking_flow_test.dart); [Cinema_Mobile/test/seat_map_test.dart](../Cinema_Mobile/test/seat_map_test.dart) |
| WEB-FR-SEAT-05 ← FR-SEAT-05 | WEB-BR-04, WEB-BR-07, WEB-BR-15, WEB-BR-16, WEB-BR-26 | UC-WEB-05 | WEB-SCR-RECORD-ROOMS | WEB-API-007 | WEB-FR-SEAT-05-AC-01, WEB-FR-SEAT-05-AC-02; [Cinema_BE/MovieService/MovieService.Tests/Integration/SeatTests.cs](../Cinema_BE/MovieService/MovieService.Tests/Integration/SeatTests.cs); [Cinema_Mobile/test/booking_flow_test.dart](../Cinema_Mobile/test/booking_flow_test.dart); [Cinema_Mobile/test/seat_map_test.dart](../Cinema_Mobile/test/seat_map_test.dart) |
| WEB-FR-SEAT-06 ← FR-SEAT-06 | WEB-BR-04, WEB-BR-07, WEB-BR-15, WEB-BR-16, WEB-BR-26 | UC-WEB-05 | WEB-SCR-RECORD-ROOMS | WEB-API-012 | WEB-FR-SEAT-06-AC-01, WEB-FR-SEAT-06-AC-02; [Cinema_BE/MovieService/MovieService.Tests/Integration/SeatTests.cs](../Cinema_BE/MovieService/MovieService.Tests/Integration/SeatTests.cs); [Cinema_Mobile/test/booking_flow_test.dart](../Cinema_Mobile/test/booking_flow_test.dart); [Cinema_Mobile/test/seat_map_test.dart](../Cinema_Mobile/test/seat_map_test.dart) |
| WEB-FR-SEAT-07 ← FR-SEAT-07 | WEB-BR-04, WEB-BR-07, WEB-BR-15, WEB-BR-16, WEB-BR-26 | UC-WEB-05 | WEB-SCR-RECORD-ROOMS | WEB-API-011 | WEB-FR-SEAT-07-AC-01, WEB-FR-SEAT-07-AC-02; [Cinema_BE/MovieService/MovieService.Tests/Integration/SeatTests.cs](../Cinema_BE/MovieService/MovieService.Tests/Integration/SeatTests.cs); [Cinema_Mobile/test/booking_flow_test.dart](../Cinema_Mobile/test/booking_flow_test.dart); [Cinema_Mobile/test/seat_map_test.dart](../Cinema_Mobile/test/seat_map_test.dart) |
| WEB-FR-SEAT-08 ← FR-SEAT-08 | WEB-BR-04, WEB-BR-07, WEB-BR-15, WEB-BR-16, WEB-BR-26 | UC-WEB-05 | WEB-SCR-RECORD-ROOMS | WEB-API-007, WEB-API-010, WEB-API-011, WEB-API-012 | WEB-FR-SEAT-08-AC-01, WEB-FR-SEAT-08-AC-02; [Cinema_BE/MovieService/MovieService.Tests/Integration/SeatTests.cs](../Cinema_BE/MovieService/MovieService.Tests/Integration/SeatTests.cs); [Cinema_Mobile/test/booking_flow_test.dart](../Cinema_Mobile/test/booking_flow_test.dart); [Cinema_Mobile/test/seat_map_test.dart](../Cinema_Mobile/test/seat_map_test.dart) |
| WEB-FR-SEAT-09 ← FR-SEAT-09 | WEB-BR-04, WEB-BR-07, WEB-BR-15, WEB-BR-16, WEB-BR-26 | UC-WEB-05 | WEB-SCR-RECORD-ROOMS | WEB-API-013 | WEB-FR-SEAT-09-AC-01, WEB-FR-SEAT-09-AC-02; [Cinema_BE/MovieService/MovieService.Tests/Integration/SeatTests.cs](../Cinema_BE/MovieService/MovieService.Tests/Integration/SeatTests.cs); [Cinema_Mobile/test/booking_flow_test.dart](../Cinema_Mobile/test/booking_flow_test.dart); [Cinema_Mobile/test/seat_map_test.dart](../Cinema_Mobile/test/seat_map_test.dart) |
| WEB-FR-SHOW-01 ← FR-SHOW-01 | WEB-BR-05, WEB-BR-06, WEB-BR-15, WEB-BR-19, WEB-BR-30 | UC-WEB-06 | WEB-SCR-OPERATIONS | WEB-API-023 | WEB-FR-SHOW-01-AC-01, WEB-FR-SHOW-01-AC-02; [Cinema_BE/BookingService/BookingService.Tests/Integration/ShowtimeReminderTests.cs](../Cinema_BE/BookingService/BookingService.Tests/Integration/ShowtimeReminderTests.cs); [Cinema_BE/MovieService/MovieService.Tests/Integration/ShowtimeFormatTests.cs](../Cinema_BE/MovieService/MovieService.Tests/Integration/ShowtimeFormatTests.cs); [Cinema_BE/MovieService/MovieService.Tests/Integration/ShowtimeTests.cs](../Cinema_BE/MovieService/MovieService.Tests/Integration/ShowtimeTests.cs) |
| WEB-FR-SHOW-02 ← FR-SHOW-02 | WEB-BR-05, WEB-BR-06, WEB-BR-15, WEB-BR-19, WEB-BR-30 | UC-WEB-06 | WEB-SCR-SHOW-EDITOR | WEB-API-024 | WEB-FR-SHOW-02-AC-01, WEB-FR-SHOW-02-AC-02; [Cinema_BE/BookingService/BookingService.Tests/Integration/ShowtimeReminderTests.cs](../Cinema_BE/BookingService/BookingService.Tests/Integration/ShowtimeReminderTests.cs); [Cinema_BE/MovieService/MovieService.Tests/Integration/ShowtimeFormatTests.cs](../Cinema_BE/MovieService/MovieService.Tests/Integration/ShowtimeFormatTests.cs); [Cinema_BE/MovieService/MovieService.Tests/Integration/ShowtimeTests.cs](../Cinema_BE/MovieService/MovieService.Tests/Integration/ShowtimeTests.cs) |
| WEB-FR-SHOW-03 ← FR-SHOW-03 | WEB-BR-05, WEB-BR-06, WEB-BR-15, WEB-BR-19, WEB-BR-30 | UC-WEB-06 | WEB-SCR-MOVIE, WEB-SCR-SEATS, WEB-SCR-RECORD-SHOWTIMES | WEB-API-017 | WEB-FR-SHOW-03-AC-01, WEB-FR-SHOW-03-AC-02; [Cinema_BE/BookingService/BookingService.Tests/Integration/ShowtimeReminderTests.cs](../Cinema_BE/BookingService/BookingService.Tests/Integration/ShowtimeReminderTests.cs); [Cinema_BE/MovieService/MovieService.Tests/Integration/ShowtimeFormatTests.cs](../Cinema_BE/MovieService/MovieService.Tests/Integration/ShowtimeFormatTests.cs); [Cinema_BE/MovieService/MovieService.Tests/Integration/ShowtimeTests.cs](../Cinema_BE/MovieService/MovieService.Tests/Integration/ShowtimeTests.cs) |
| WEB-FR-SHOW-04 ← FR-SHOW-04 | WEB-BR-05, WEB-BR-06, WEB-BR-15, WEB-BR-19, WEB-BR-30 | UC-WEB-06 | WEB-SCR-SHOW-EDITOR | WEB-API-018 | WEB-FR-SHOW-04-AC-01, WEB-FR-SHOW-04-AC-02; [Cinema_BE/BookingService/BookingService.Tests/Integration/ShowtimeReminderTests.cs](../Cinema_BE/BookingService/BookingService.Tests/Integration/ShowtimeReminderTests.cs); [Cinema_BE/MovieService/MovieService.Tests/Integration/ShowtimeFormatTests.cs](../Cinema_BE/MovieService/MovieService.Tests/Integration/ShowtimeFormatTests.cs); [Cinema_BE/MovieService/MovieService.Tests/Integration/ShowtimeTests.cs](../Cinema_BE/MovieService/MovieService.Tests/Integration/ShowtimeTests.cs) |
| WEB-FR-SHOW-05 ← FR-SHOW-05 | WEB-BR-05, WEB-BR-06, WEB-BR-15, WEB-BR-19, WEB-BR-30 | UC-WEB-06 | WEB-SCR-RECORD-SHOWTIMES | WEB-API-016 | WEB-FR-SHOW-05-AC-01, WEB-FR-SHOW-05-AC-02; [Cinema_BE/BookingService/BookingService.Tests/Integration/ShowtimeReminderTests.cs](../Cinema_BE/BookingService/BookingService.Tests/Integration/ShowtimeReminderTests.cs); [Cinema_BE/MovieService/MovieService.Tests/Integration/ShowtimeFormatTests.cs](../Cinema_BE/MovieService/MovieService.Tests/Integration/ShowtimeFormatTests.cs); [Cinema_BE/MovieService/MovieService.Tests/Integration/ShowtimeTests.cs](../Cinema_BE/MovieService/MovieService.Tests/Integration/ShowtimeTests.cs) |
| WEB-FR-SHOW-06 ← FR-SHOW-06 | WEB-BR-05, WEB-BR-06, WEB-BR-15, WEB-BR-19, WEB-BR-30 | UC-WEB-06 | WEB-SCR-MOVIE | WEB-API-022 | WEB-FR-SHOW-06-AC-01, WEB-FR-SHOW-06-AC-02; [Cinema_BE/BookingService/BookingService.Tests/Integration/ShowtimeReminderTests.cs](../Cinema_BE/BookingService/BookingService.Tests/Integration/ShowtimeReminderTests.cs); [Cinema_BE/MovieService/MovieService.Tests/Integration/ShowtimeFormatTests.cs](../Cinema_BE/MovieService/MovieService.Tests/Integration/ShowtimeFormatTests.cs); [Cinema_BE/MovieService/MovieService.Tests/Integration/ShowtimeTests.cs](../Cinema_BE/MovieService/MovieService.Tests/Integration/ShowtimeTests.cs) |
| WEB-FR-SHOW-07 ← FR-SHOW-07 | WEB-BR-05, WEB-BR-06, WEB-BR-15, WEB-BR-19, WEB-BR-30 | UC-WEB-06 | WEB-SCR-MOVIE | WEB-API-021 | WEB-FR-SHOW-07-AC-01, WEB-FR-SHOW-07-AC-02; [Cinema_BE/BookingService/BookingService.Tests/Integration/ShowtimeReminderTests.cs](../Cinema_BE/BookingService/BookingService.Tests/Integration/ShowtimeReminderTests.cs); [Cinema_BE/MovieService/MovieService.Tests/Integration/ShowtimeFormatTests.cs](../Cinema_BE/MovieService/MovieService.Tests/Integration/ShowtimeFormatTests.cs); [Cinema_BE/MovieService/MovieService.Tests/Integration/ShowtimeTests.cs](../Cinema_BE/MovieService/MovieService.Tests/Integration/ShowtimeTests.cs) |
| WEB-FR-SHOW-08 ← FR-SHOW-08 | WEB-BR-05, WEB-BR-06, WEB-BR-15, WEB-BR-19, WEB-BR-30 | UC-WEB-06 | WEB-SCR-MOVIE | WEB-API-020 | WEB-FR-SHOW-08-AC-01, WEB-FR-SHOW-08-AC-02; [Cinema_BE/BookingService/BookingService.Tests/Integration/ShowtimeReminderTests.cs](../Cinema_BE/BookingService/BookingService.Tests/Integration/ShowtimeReminderTests.cs); [Cinema_BE/MovieService/MovieService.Tests/Integration/ShowtimeFormatTests.cs](../Cinema_BE/MovieService/MovieService.Tests/Integration/ShowtimeFormatTests.cs); [Cinema_BE/MovieService/MovieService.Tests/Integration/ShowtimeTests.cs](../Cinema_BE/MovieService/MovieService.Tests/Integration/ShowtimeTests.cs) |
| WEB-FR-SHOW-09 ← FR-SHOW-09 | WEB-BR-05, WEB-BR-06, WEB-BR-15, WEB-BR-19, WEB-BR-30 | UC-WEB-06 | WEB-SCR-OPERATIONS | WEB-API-019 | WEB-FR-SHOW-09-AC-01, WEB-FR-SHOW-09-AC-02; [Cinema_BE/BookingService/BookingService.Tests/Integration/ShowtimeReminderTests.cs](../Cinema_BE/BookingService/BookingService.Tests/Integration/ShowtimeReminderTests.cs); [Cinema_BE/MovieService/MovieService.Tests/Integration/ShowtimeFormatTests.cs](../Cinema_BE/MovieService/MovieService.Tests/Integration/ShowtimeFormatTests.cs); [Cinema_BE/MovieService/MovieService.Tests/Integration/ShowtimeTests.cs](../Cinema_BE/MovieService/MovieService.Tests/Integration/ShowtimeTests.cs) |
| WEB-FR-SHOW-10 ← FR-SHOW-10 | WEB-BR-05, WEB-BR-06, WEB-BR-15, WEB-BR-19, WEB-BR-30 | UC-WEB-06 | WEB-SCR-RECORD-SHOWTIMES | WEB-API-015 | WEB-FR-SHOW-10-AC-01, WEB-FR-SHOW-10-AC-02; [Cinema_BE/BookingService/BookingService.Tests/Integration/ShowtimeReminderTests.cs](../Cinema_BE/BookingService/BookingService.Tests/Integration/ShowtimeReminderTests.cs); [Cinema_BE/MovieService/MovieService.Tests/Integration/ShowtimeFormatTests.cs](../Cinema_BE/MovieService/MovieService.Tests/Integration/ShowtimeFormatTests.cs); [Cinema_BE/MovieService/MovieService.Tests/Integration/ShowtimeTests.cs](../Cinema_BE/MovieService/MovieService.Tests/Integration/ShowtimeTests.cs) |
| WEB-FR-SHOW-11 ← FR-SHOW-11 | WEB-BR-05, WEB-BR-06, WEB-BR-15, WEB-BR-19, WEB-BR-30 | UC-WEB-06 | WEB-SCR-SHOW-EDITOR | WEB-API-018, WEB-API-024 | WEB-FR-SHOW-11-AC-01, WEB-FR-SHOW-11-AC-02; [Cinema_BE/BookingService/BookingService.Tests/Integration/ShowtimeReminderTests.cs](../Cinema_BE/BookingService/BookingService.Tests/Integration/ShowtimeReminderTests.cs); [Cinema_BE/MovieService/MovieService.Tests/Integration/ShowtimeFormatTests.cs](../Cinema_BE/MovieService/MovieService.Tests/Integration/ShowtimeFormatTests.cs); [Cinema_BE/MovieService/MovieService.Tests/Integration/ShowtimeTests.cs](../Cinema_BE/MovieService/MovieService.Tests/Integration/ShowtimeTests.cs) |
| WEB-FR-SHOW-12 ← FR-SHOW-12 | WEB-BR-05, WEB-BR-06, WEB-BR-15, WEB-BR-19, WEB-BR-30 | UC-WEB-06 | WEB-SCR-RECORD-SHOWTIMES | WEB-API-013, WEB-API-017, WEB-API-050 | WEB-FR-SHOW-12-AC-01, WEB-FR-SHOW-12-AC-02; [Cinema_BE/BookingService/BookingService.Tests/Integration/ShowtimeReminderTests.cs](../Cinema_BE/BookingService/BookingService.Tests/Integration/ShowtimeReminderTests.cs); [Cinema_BE/MovieService/MovieService.Tests/Integration/ShowtimeFormatTests.cs](../Cinema_BE/MovieService/MovieService.Tests/Integration/ShowtimeFormatTests.cs); [Cinema_BE/MovieService/MovieService.Tests/Integration/ShowtimeTests.cs](../Cinema_BE/MovieService/MovieService.Tests/Integration/ShowtimeTests.cs) |
| WEB-FR-SHOW-13 ← FR-SHOW-13 | WEB-BR-05, WEB-BR-06, WEB-BR-15, WEB-BR-19, WEB-BR-30 | UC-WEB-06 | WEB-SCR-MOVIE, WEB-SCR-SEATS, WEB-SCR-SHOW-EDITOR | WEB-API-017, WEB-API-018, WEB-API-024 | WEB-FR-SHOW-13-AC-01, WEB-FR-SHOW-13-AC-02; [Cinema_BE/BookingService/BookingService.Tests/Integration/ShowtimeReminderTests.cs](../Cinema_BE/BookingService/BookingService.Tests/Integration/ShowtimeReminderTests.cs); [Cinema_BE/MovieService/MovieService.Tests/Integration/ShowtimeFormatTests.cs](../Cinema_BE/MovieService/MovieService.Tests/Integration/ShowtimeFormatTests.cs); [Cinema_BE/MovieService/MovieService.Tests/Integration/ShowtimeTests.cs](../Cinema_BE/MovieService/MovieService.Tests/Integration/ShowtimeTests.cs) |
| WEB-FR-BOOK-01 ← FR-BOOK-01 | WEB-BR-07, WEB-BR-08, WEB-BR-14, WEB-BR-15, WEB-BR-16, WEB-BR-17, WEB-BR-27, WEB-BR-28, WEB-BR-29 | UC-WEB-07 | WEB-SCR-SUMMARY | WEB-API-055 | WEB-FR-BOOK-01-AC-01, WEB-FR-BOOK-01-AC-02; [Cinema_BE/BookingService/BookingService.Tests/Integration/BookingFlowTests.cs](../Cinema_BE/BookingService/BookingService.Tests/Integration/BookingFlowTests.cs); [Cinema_BE/BookingService/BookingService.Tests/Integration/ConcessionTests.cs](../Cinema_BE/BookingService/BookingService.Tests/Integration/ConcessionTests.cs); [Cinema_BE/BookingService/BookingService.Tests/Integration/LoyaltyTests.cs](../Cinema_BE/BookingService/BookingService.Tests/Integration/LoyaltyTests.cs) |
| WEB-FR-BOOK-02 ← FR-BOOK-02 | WEB-BR-07, WEB-BR-08, WEB-BR-14, WEB-BR-15, WEB-BR-16, WEB-BR-17, WEB-BR-27, WEB-BR-28, WEB-BR-29 | UC-WEB-07 | WEB-SCR-RESULT, WEB-SCR-TICKET, WEB-SCR-RECORD-BOOKINGS | WEB-API-046 | WEB-FR-BOOK-02-AC-01, WEB-FR-BOOK-02-AC-02; [Cinema_BE/BookingService/BookingService.Tests/Integration/BookingFlowTests.cs](../Cinema_BE/BookingService/BookingService.Tests/Integration/BookingFlowTests.cs); [Cinema_BE/BookingService/BookingService.Tests/Integration/ConcessionTests.cs](../Cinema_BE/BookingService/BookingService.Tests/Integration/ConcessionTests.cs); [Cinema_BE/BookingService/BookingService.Tests/Integration/LoyaltyTests.cs](../Cinema_BE/BookingService/BookingService.Tests/Integration/LoyaltyTests.cs) |
| WEB-FR-BOOK-03 ← FR-BOOK-03 | WEB-BR-07, WEB-BR-08, WEB-BR-14, WEB-BR-15, WEB-BR-16, WEB-BR-17, WEB-BR-27, WEB-BR-28, WEB-BR-29 | UC-WEB-07 | WEB-SCR-OPERATIONS | WEB-API-048, WEB-API-052, WEB-API-054 | WEB-FR-BOOK-03-AC-01, WEB-FR-BOOK-03-AC-02; [Cinema_BE/BookingService/BookingService.Tests/Integration/BookingFlowTests.cs](../Cinema_BE/BookingService/BookingService.Tests/Integration/BookingFlowTests.cs); [Cinema_BE/BookingService/BookingService.Tests/Integration/ConcessionTests.cs](../Cinema_BE/BookingService/BookingService.Tests/Integration/ConcessionTests.cs); [Cinema_BE/BookingService/BookingService.Tests/Integration/LoyaltyTests.cs](../Cinema_BE/BookingService/BookingService.Tests/Integration/LoyaltyTests.cs) |
| WEB-FR-BOOK-04 ← FR-BOOK-04 | WEB-BR-07, WEB-BR-08, WEB-BR-14, WEB-BR-15, WEB-BR-16, WEB-BR-17, WEB-BR-27, WEB-BR-28, WEB-BR-29 | UC-WEB-07 | WEB-SCR-TICKETS | WEB-API-053 | WEB-FR-BOOK-04-AC-01, WEB-FR-BOOK-04-AC-02; [Cinema_BE/BookingService/BookingService.Tests/Integration/BookingFlowTests.cs](../Cinema_BE/BookingService/BookingService.Tests/Integration/BookingFlowTests.cs); [Cinema_BE/BookingService/BookingService.Tests/Integration/ConcessionTests.cs](../Cinema_BE/BookingService/BookingService.Tests/Integration/ConcessionTests.cs); [Cinema_BE/BookingService/BookingService.Tests/Integration/LoyaltyTests.cs](../Cinema_BE/BookingService/BookingService.Tests/Integration/LoyaltyTests.cs) |
| WEB-FR-BOOK-05 ← FR-BOOK-05 | WEB-BR-07, WEB-BR-08, WEB-BR-14, WEB-BR-15, WEB-BR-16, WEB-BR-17, WEB-BR-27, WEB-BR-28, WEB-BR-29 | UC-WEB-07 | WEB-SCR-PAYMENT, WEB-SCR-RESULT, WEB-SCR-TICKET | WEB-API-086, WEB-API-087, WEB-API-089 | WEB-FR-BOOK-05-AC-01, WEB-FR-BOOK-05-AC-02; [Cinema_BE/BookingService/BookingService.Tests/Integration/BookingFlowTests.cs](../Cinema_BE/BookingService/BookingService.Tests/Integration/BookingFlowTests.cs); [Cinema_BE/BookingService/BookingService.Tests/Integration/ConcessionTests.cs](../Cinema_BE/BookingService/BookingService.Tests/Integration/ConcessionTests.cs); [Cinema_BE/BookingService/BookingService.Tests/Integration/LoyaltyTests.cs](../Cinema_BE/BookingService/BookingService.Tests/Integration/LoyaltyTests.cs) |
| WEB-FR-BOOK-06 ← FR-BOOK-06 | WEB-BR-07, WEB-BR-08, WEB-BR-14, WEB-BR-15, WEB-BR-16, WEB-BR-17, WEB-BR-27, WEB-BR-28, WEB-BR-29 | UC-WEB-07 | WEB-SCR-TICKET, WEB-SCR-RECORD-BOOKINGS | WEB-API-043 | WEB-FR-BOOK-06-AC-01, WEB-FR-BOOK-06-AC-02; [Cinema_BE/BookingService/BookingService.Tests/Integration/BookingFlowTests.cs](../Cinema_BE/BookingService/BookingService.Tests/Integration/BookingFlowTests.cs); [Cinema_BE/BookingService/BookingService.Tests/Integration/ConcessionTests.cs](../Cinema_BE/BookingService/BookingService.Tests/Integration/ConcessionTests.cs); [Cinema_BE/BookingService/BookingService.Tests/Integration/LoyaltyTests.cs](../Cinema_BE/BookingService/BookingService.Tests/Integration/LoyaltyTests.cs) |
| WEB-FR-BOOK-07 ← FR-BOOK-07 | WEB-BR-07, WEB-BR-08, WEB-BR-14, WEB-BR-15, WEB-BR-16, WEB-BR-17, WEB-BR-27, WEB-BR-28, WEB-BR-29 | UC-WEB-07 | WEB-SCR-SEATS | WEB-API-049 | WEB-FR-BOOK-07-AC-01, WEB-FR-BOOK-07-AC-02; [Cinema_BE/BookingService/BookingService.Tests/Integration/BookingFlowTests.cs](../Cinema_BE/BookingService/BookingService.Tests/Integration/BookingFlowTests.cs); [Cinema_BE/BookingService/BookingService.Tests/Integration/ConcessionTests.cs](../Cinema_BE/BookingService/BookingService.Tests/Integration/ConcessionTests.cs); [Cinema_BE/BookingService/BookingService.Tests/Integration/LoyaltyTests.cs](../Cinema_BE/BookingService/BookingService.Tests/Integration/LoyaltyTests.cs) |
| WEB-FR-BOOK-08 ← FR-BOOK-08 | WEB-BR-07, WEB-BR-08, WEB-BR-14, WEB-BR-15, WEB-BR-16, WEB-BR-17, WEB-BR-27, WEB-BR-28, WEB-BR-29 | UC-WEB-07 | WEB-SCR-SEATS | WEB-API-055 | WEB-FR-BOOK-08-AC-01, WEB-FR-BOOK-08-AC-02; [Cinema_BE/BookingService/BookingService.Tests/Integration/BookingFlowTests.cs](../Cinema_BE/BookingService/BookingService.Tests/Integration/BookingFlowTests.cs); [Cinema_BE/BookingService/BookingService.Tests/Integration/ConcessionTests.cs](../Cinema_BE/BookingService/BookingService.Tests/Integration/ConcessionTests.cs); [Cinema_BE/BookingService/BookingService.Tests/Integration/LoyaltyTests.cs](../Cinema_BE/BookingService/BookingService.Tests/Integration/LoyaltyTests.cs) |
| WEB-FR-BOOK-09 ← FR-BOOK-09 | WEB-BR-07, WEB-BR-08, WEB-BR-14, WEB-BR-15, WEB-BR-16, WEB-BR-17, WEB-BR-27, WEB-BR-28, WEB-BR-29 | UC-WEB-07 | WEB-SCR-SEATS, WEB-SCR-SUMMARY | WEB-API-055 | WEB-FR-BOOK-09-AC-01, WEB-FR-BOOK-09-AC-02; [Cinema_BE/BookingService/BookingService.Tests/Integration/BookingFlowTests.cs](../Cinema_BE/BookingService/BookingService.Tests/Integration/BookingFlowTests.cs); [Cinema_BE/BookingService/BookingService.Tests/Integration/ConcessionTests.cs](../Cinema_BE/BookingService/BookingService.Tests/Integration/ConcessionTests.cs); [Cinema_BE/BookingService/BookingService.Tests/Integration/LoyaltyTests.cs](../Cinema_BE/BookingService/BookingService.Tests/Integration/LoyaltyTests.cs) |
| WEB-FR-BOOK-10 ← FR-BOOK-10 | WEB-BR-07, WEB-BR-08, WEB-BR-14, WEB-BR-15, WEB-BR-16, WEB-BR-17, WEB-BR-27, WEB-BR-28, WEB-BR-29 | UC-WEB-07 | WEB-SCR-PAYMENT | WEB-API-046 | WEB-FR-BOOK-10-AC-01, WEB-FR-BOOK-10-AC-02; [Cinema_BE/BookingService/BookingService.Tests/Integration/BookingFlowTests.cs](../Cinema_BE/BookingService/BookingService.Tests/Integration/BookingFlowTests.cs); [Cinema_BE/BookingService/BookingService.Tests/Integration/ConcessionTests.cs](../Cinema_BE/BookingService/BookingService.Tests/Integration/ConcessionTests.cs); [Cinema_BE/BookingService/BookingService.Tests/Integration/LoyaltyTests.cs](../Cinema_BE/BookingService/BookingService.Tests/Integration/LoyaltyTests.cs) |
| WEB-FR-BOOK-11 ← FR-BOOK-11 | WEB-BR-07, WEB-BR-08, WEB-BR-14, WEB-BR-15, WEB-BR-16, WEB-BR-17, WEB-BR-27, WEB-BR-28, WEB-BR-29 | UC-WEB-07 | WEB-SCR-SEATS | WEB-API-013, WEB-API-049 | WEB-FR-BOOK-11-AC-01, WEB-FR-BOOK-11-AC-02; [Cinema_BE/BookingService/BookingService.Tests/Integration/BookingFlowTests.cs](../Cinema_BE/BookingService/BookingService.Tests/Integration/BookingFlowTests.cs); [Cinema_BE/BookingService/BookingService.Tests/Integration/ConcessionTests.cs](../Cinema_BE/BookingService/BookingService.Tests/Integration/ConcessionTests.cs); [Cinema_BE/BookingService/BookingService.Tests/Integration/LoyaltyTests.cs](../Cinema_BE/BookingService/BookingService.Tests/Integration/LoyaltyTests.cs) |
| WEB-FR-BOOK-12 ← FR-BOOK-12 | WEB-BR-07, WEB-BR-08, WEB-BR-14, WEB-BR-15, WEB-BR-16, WEB-BR-17, WEB-BR-27, WEB-BR-28, WEB-BR-29 | UC-WEB-07 | WEB-SCR-OPERATIONS, WEB-SCR-RECORD-SHOWTIMES | WEB-API-051 | WEB-FR-BOOK-12-AC-01, WEB-FR-BOOK-12-AC-02; [Cinema_BE/BookingService/BookingService.Tests/Integration/BookingFlowTests.cs](../Cinema_BE/BookingService/BookingService.Tests/Integration/BookingFlowTests.cs); [Cinema_BE/BookingService/BookingService.Tests/Integration/ConcessionTests.cs](../Cinema_BE/BookingService/BookingService.Tests/Integration/ConcessionTests.cs); [Cinema_BE/BookingService/BookingService.Tests/Integration/LoyaltyTests.cs](../Cinema_BE/BookingService/BookingService.Tests/Integration/LoyaltyTests.cs) |
| WEB-FR-BOOK-13 ← FR-BOOK-13 | WEB-BR-07, WEB-BR-08, WEB-BR-14, WEB-BR-15, WEB-BR-16, WEB-BR-17, WEB-BR-27, WEB-BR-28, WEB-BR-29 | UC-WEB-07 | WEB-SCR-SUMMARY, WEB-SCR-TICKET, WEB-SCR-COUNTER | WEB-API-055, WEB-API-057 | WEB-FR-BOOK-13-AC-01, WEB-FR-BOOK-13-AC-02; [Cinema_BE/BookingService/BookingService.Tests/Integration/BookingFlowTests.cs](../Cinema_BE/BookingService/BookingService.Tests/Integration/BookingFlowTests.cs); [Cinema_BE/BookingService/BookingService.Tests/Integration/ConcessionTests.cs](../Cinema_BE/BookingService/BookingService.Tests/Integration/ConcessionTests.cs); [Cinema_BE/BookingService/BookingService.Tests/Integration/LoyaltyTests.cs](../Cinema_BE/BookingService/BookingService.Tests/Integration/LoyaltyTests.cs) |
| WEB-FR-BOOK-14 ← FR-BOOK-14 | WEB-BR-07, WEB-BR-08, WEB-BR-14, WEB-BR-15, WEB-BR-16, WEB-BR-17, WEB-BR-27, WEB-BR-28, WEB-BR-29 | UC-WEB-07 | WEB-SCR-ADMIN-SNACKS | WEB-API-056, WEB-API-057, WEB-API-058 | WEB-FR-BOOK-14-AC-01, WEB-FR-BOOK-14-AC-02; [Cinema_BE/BookingService/BookingService.Tests/Integration/BookingFlowTests.cs](../Cinema_BE/BookingService/BookingService.Tests/Integration/BookingFlowTests.cs); [Cinema_BE/BookingService/BookingService.Tests/Integration/ConcessionTests.cs](../Cinema_BE/BookingService/BookingService.Tests/Integration/ConcessionTests.cs); [Cinema_BE/BookingService/BookingService.Tests/Integration/LoyaltyTests.cs](../Cinema_BE/BookingService/BookingService.Tests/Integration/LoyaltyTests.cs) |
| WEB-FR-BOOK-15 ← FR-BOOK-15 | WEB-BR-07, WEB-BR-08, WEB-BR-14, WEB-BR-15, WEB-BR-16, WEB-BR-17, WEB-BR-27, WEB-BR-28, WEB-BR-29 | UC-WEB-07 | WEB-SCR-SUMMARY, WEB-SCR-TICKET, WEB-SCR-COUNTER | WEB-API-055, WEB-API-099 | WEB-FR-BOOK-15-AC-01, WEB-FR-BOOK-15-AC-02; [Cinema_BE/BookingService/BookingService.Tests/Integration/BookingFlowTests.cs](../Cinema_BE/BookingService/BookingService.Tests/Integration/BookingFlowTests.cs); [Cinema_BE/BookingService/BookingService.Tests/Integration/ConcessionTests.cs](../Cinema_BE/BookingService/BookingService.Tests/Integration/ConcessionTests.cs); [Cinema_BE/BookingService/BookingService.Tests/Integration/LoyaltyTests.cs](../Cinema_BE/BookingService/BookingService.Tests/Integration/LoyaltyTests.cs) |
| WEB-FR-BOOK-16 ← FR-BOOK-16 | WEB-BR-07, WEB-BR-08, WEB-BR-14, WEB-BR-15, WEB-BR-16, WEB-BR-17, WEB-BR-27, WEB-BR-28, WEB-BR-29 | UC-WEB-07 | WEB-SCR-ADMIN-PROMOTIONS | WEB-API-098, WEB-API-100, WEB-API-101 | WEB-FR-BOOK-16-AC-01, WEB-FR-BOOK-16-AC-02; [Cinema_BE/BookingService/BookingService.Tests/Integration/BookingFlowTests.cs](../Cinema_BE/BookingService/BookingService.Tests/Integration/BookingFlowTests.cs); [Cinema_BE/BookingService/BookingService.Tests/Integration/ConcessionTests.cs](../Cinema_BE/BookingService/BookingService.Tests/Integration/ConcessionTests.cs); [Cinema_BE/BookingService/BookingService.Tests/Integration/LoyaltyTests.cs](../Cinema_BE/BookingService/BookingService.Tests/Integration/LoyaltyTests.cs) |
| WEB-FR-BOOK-17 ← FR-BOOK-17 | WEB-BR-07, WEB-BR-08, WEB-BR-14, WEB-BR-15, WEB-BR-16, WEB-BR-17, WEB-BR-27, WEB-BR-28, WEB-BR-29 | UC-WEB-07 | WEB-SCR-SUMMARY, WEB-SCR-TICKET, WEB-SCR-PROFILE, WEB-SCR-COUNTER | WEB-API-055, WEB-API-060 | WEB-FR-BOOK-17-AC-01, WEB-FR-BOOK-17-AC-02; [Cinema_BE/BookingService/BookingService.Tests/Integration/BookingFlowTests.cs](../Cinema_BE/BookingService/BookingService.Tests/Integration/BookingFlowTests.cs); [Cinema_BE/BookingService/BookingService.Tests/Integration/ConcessionTests.cs](../Cinema_BE/BookingService/BookingService.Tests/Integration/ConcessionTests.cs); [Cinema_BE/BookingService/BookingService.Tests/Integration/LoyaltyTests.cs](../Cinema_BE/BookingService/BookingService.Tests/Integration/LoyaltyTests.cs) |
| WEB-FR-BOOK-18 ← FR-BOOK-18 | WEB-BR-07, WEB-BR-08, WEB-BR-14, WEB-BR-15, WEB-BR-16, WEB-BR-17, WEB-BR-27, WEB-BR-28, WEB-BR-29 | UC-WEB-07 | WEB-SCR-ADMIN-MEMBERS | WEB-API-030, WEB-API-059, WEB-API-061, WEB-API-062 | WEB-FR-BOOK-18-AC-01, WEB-FR-BOOK-18-AC-02; [Cinema_BE/BookingService/BookingService.Tests/Integration/BookingFlowTests.cs](../Cinema_BE/BookingService/BookingService.Tests/Integration/BookingFlowTests.cs); [Cinema_BE/BookingService/BookingService.Tests/Integration/ConcessionTests.cs](../Cinema_BE/BookingService/BookingService.Tests/Integration/ConcessionTests.cs); [Cinema_BE/BookingService/BookingService.Tests/Integration/LoyaltyTests.cs](../Cinema_BE/BookingService/BookingService.Tests/Integration/LoyaltyTests.cs) |
| WEB-FR-BOOK-19 ← FR-BOOK-19 | WEB-BR-07, WEB-BR-08, WEB-BR-14, WEB-BR-15, WEB-BR-16, WEB-BR-17, WEB-BR-27, WEB-BR-28, WEB-BR-29 | UC-WEB-07 | WEB-SCR-TICKET | WEB-API-017 | WEB-FR-BOOK-19-AC-01, WEB-FR-BOOK-19-AC-02; [Cinema_BE/BookingService/BookingService.Tests/Integration/BookingFlowTests.cs](../Cinema_BE/BookingService/BookingService.Tests/Integration/BookingFlowTests.cs); [Cinema_BE/BookingService/BookingService.Tests/Integration/ConcessionTests.cs](../Cinema_BE/BookingService/BookingService.Tests/Integration/ConcessionTests.cs); [Cinema_BE/BookingService/BookingService.Tests/Integration/LoyaltyTests.cs](../Cinema_BE/BookingService/BookingService.Tests/Integration/LoyaltyTests.cs) |
| WEB-FR-PAY-01 ← FR-PAY-01 | WEB-BR-09, WEB-BR-10, WEB-BR-11, WEB-BR-12, WEB-BR-13, WEB-BR-14, WEB-BR-20 | UC-WEB-08 | WEB-SCR-PAYMENT, WEB-SCR-CHECKOUT | WEB-API-088 | WEB-FR-PAY-01-AC-01, WEB-FR-PAY-01-AC-02; [Cinema_BE/BookingService/BookingService.Tests/Integration/BookingFlowTests.cs](../Cinema_BE/BookingService/BookingService.Tests/Integration/BookingFlowTests.cs); [Cinema_BE/BookingService/BookingService.Tests/Integration/PaymentSummaryTests.cs](../Cinema_BE/BookingService/BookingService.Tests/Integration/PaymentSummaryTests.cs); [Cinema_BE/BookingService/BookingService.Tests/Integration/PayOsOrderCodeTests.cs](../Cinema_BE/BookingService/BookingService.Tests/Integration/PayOsOrderCodeTests.cs) |
| WEB-FR-PAY-02 ← FR-PAY-02 | WEB-BR-09, WEB-BR-10, WEB-BR-11, WEB-BR-12, WEB-BR-13, WEB-BR-14, WEB-BR-20 | UC-WEB-08 | WEB-SCR-PAYMENT, WEB-SCR-RESULT, WEB-SCR-CHECKOUT | WEB-API-087 | WEB-FR-PAY-02-AC-01, WEB-FR-PAY-02-AC-02; [Cinema_BE/BookingService/BookingService.Tests/Integration/BookingFlowTests.cs](../Cinema_BE/BookingService/BookingService.Tests/Integration/BookingFlowTests.cs); [Cinema_BE/BookingService/BookingService.Tests/Integration/PaymentSummaryTests.cs](../Cinema_BE/BookingService/BookingService.Tests/Integration/PaymentSummaryTests.cs); [Cinema_BE/BookingService/BookingService.Tests/Integration/PayOsOrderCodeTests.cs](../Cinema_BE/BookingService/BookingService.Tests/Integration/PayOsOrderCodeTests.cs) |
| WEB-FR-PAY-03 ← FR-PAY-03 | WEB-BR-09, WEB-BR-10, WEB-BR-11, WEB-BR-12, WEB-BR-13, WEB-BR-14, WEB-BR-20 | UC-WEB-08 | WEB-SCR-TICKET, WEB-SCR-PAYHISTORY, WEB-SCR-RECORD-PAYMENTS | WEB-API-084 | WEB-FR-PAY-03-AC-01, WEB-FR-PAY-03-AC-02; [Cinema_BE/BookingService/BookingService.Tests/Integration/BookingFlowTests.cs](../Cinema_BE/BookingService/BookingService.Tests/Integration/BookingFlowTests.cs); [Cinema_BE/BookingService/BookingService.Tests/Integration/PaymentSummaryTests.cs](../Cinema_BE/BookingService/BookingService.Tests/Integration/PaymentSummaryTests.cs); [Cinema_BE/BookingService/BookingService.Tests/Integration/PayOsOrderCodeTests.cs](../Cinema_BE/BookingService/BookingService.Tests/Integration/PayOsOrderCodeTests.cs) |
| WEB-FR-PAY-04 ← FR-PAY-04 | WEB-BR-09, WEB-BR-10, WEB-BR-11, WEB-BR-12, WEB-BR-13, WEB-BR-14, WEB-BR-20 | UC-WEB-08 | WEB-SCR-PAYHISTORY | WEB-API-095 | WEB-FR-PAY-04-AC-01, WEB-FR-PAY-04-AC-02; [Cinema_BE/BookingService/BookingService.Tests/Integration/BookingFlowTests.cs](../Cinema_BE/BookingService/BookingService.Tests/Integration/BookingFlowTests.cs); [Cinema_BE/BookingService/BookingService.Tests/Integration/PaymentSummaryTests.cs](../Cinema_BE/BookingService/BookingService.Tests/Integration/PaymentSummaryTests.cs); [Cinema_BE/BookingService/BookingService.Tests/Integration/PayOsOrderCodeTests.cs](../Cinema_BE/BookingService/BookingService.Tests/Integration/PayOsOrderCodeTests.cs) |
| WEB-FR-PAY-05 ← FR-PAY-05 | WEB-BR-09, WEB-BR-10, WEB-BR-11, WEB-BR-12, WEB-BR-13, WEB-BR-14, WEB-BR-20 | UC-WEB-08 | WEB-SCR-RECORD-PAYMENTS | WEB-API-085 | WEB-FR-PAY-05-AC-01, WEB-FR-PAY-05-AC-02; [Cinema_BE/BookingService/BookingService.Tests/Integration/BookingFlowTests.cs](../Cinema_BE/BookingService/BookingService.Tests/Integration/BookingFlowTests.cs); [Cinema_BE/BookingService/BookingService.Tests/Integration/PaymentSummaryTests.cs](../Cinema_BE/BookingService/BookingService.Tests/Integration/PaymentSummaryTests.cs); [Cinema_BE/BookingService/BookingService.Tests/Integration/PayOsOrderCodeTests.cs](../Cinema_BE/BookingService/BookingService.Tests/Integration/PayOsOrderCodeTests.cs) |
| WEB-FR-PAY-06 ← FR-PAY-06 | WEB-BR-09, WEB-BR-10, WEB-BR-11, WEB-BR-12, WEB-BR-13, WEB-BR-14, WEB-BR-20 | UC-WEB-08 | WEB-SCR-TICKET | WEB-API-043, WEB-API-082, WEB-API-083 | WEB-FR-PAY-06-AC-01, WEB-FR-PAY-06-AC-02; [Cinema_BE/BookingService/BookingService.Tests/Integration/BookingFlowTests.cs](../Cinema_BE/BookingService/BookingService.Tests/Integration/BookingFlowTests.cs); [Cinema_BE/BookingService/BookingService.Tests/Integration/PaymentSummaryTests.cs](../Cinema_BE/BookingService/BookingService.Tests/Integration/PaymentSummaryTests.cs); [Cinema_BE/BookingService/BookingService.Tests/Integration/PayOsOrderCodeTests.cs](../Cinema_BE/BookingService/BookingService.Tests/Integration/PayOsOrderCodeTests.cs) |
| WEB-FR-PAY-07 ← FR-PAY-07 | WEB-BR-09, WEB-BR-10, WEB-BR-11, WEB-BR-12, WEB-BR-13, WEB-BR-14, WEB-BR-20 | UC-WEB-08 |  | WEB-API-089 | WEB-FR-PAY-07-AC-01, WEB-FR-PAY-07-AC-02; [Cinema_BE/BookingService/BookingService.Tests/Integration/BookingFlowTests.cs](../Cinema_BE/BookingService/BookingService.Tests/Integration/BookingFlowTests.cs); [Cinema_BE/BookingService/BookingService.Tests/Integration/PaymentSummaryTests.cs](../Cinema_BE/BookingService/BookingService.Tests/Integration/PaymentSummaryTests.cs); [Cinema_BE/BookingService/BookingService.Tests/Integration/PayOsOrderCodeTests.cs](../Cinema_BE/BookingService/BookingService.Tests/Integration/PayOsOrderCodeTests.cs) |
| WEB-FR-PAY-08 ← FR-PAY-08 | WEB-BR-09, WEB-BR-10, WEB-BR-11, WEB-BR-12, WEB-BR-13, WEB-BR-14, WEB-BR-20 | UC-WEB-08 | WEB-SCR-RESULT | WEB-API-087, WEB-API-089 | WEB-FR-PAY-08-AC-01, WEB-FR-PAY-08-AC-02; [Cinema_BE/BookingService/BookingService.Tests/Integration/BookingFlowTests.cs](../Cinema_BE/BookingService/BookingService.Tests/Integration/BookingFlowTests.cs); [Cinema_BE/BookingService/BookingService.Tests/Integration/PaymentSummaryTests.cs](../Cinema_BE/BookingService/BookingService.Tests/Integration/PaymentSummaryTests.cs); [Cinema_BE/BookingService/BookingService.Tests/Integration/PayOsOrderCodeTests.cs](../Cinema_BE/BookingService/BookingService.Tests/Integration/PayOsOrderCodeTests.cs) |
| WEB-FR-PAY-09 ← FR-PAY-09 | WEB-BR-09, WEB-BR-10, WEB-BR-11, WEB-BR-12, WEB-BR-13, WEB-BR-14, WEB-BR-20 | UC-WEB-08 | WEB-SCR-OPERATIONS, WEB-SCR-RECORD-PAYMENTS | WEB-API-087, WEB-API-096 | WEB-FR-PAY-09-AC-01, WEB-FR-PAY-09-AC-02; [Cinema_BE/BookingService/BookingService.Tests/Integration/BookingFlowTests.cs](../Cinema_BE/BookingService/BookingService.Tests/Integration/BookingFlowTests.cs); [Cinema_BE/BookingService/BookingService.Tests/Integration/PaymentSummaryTests.cs](../Cinema_BE/BookingService/BookingService.Tests/Integration/PaymentSummaryTests.cs); [Cinema_BE/BookingService/BookingService.Tests/Integration/PayOsOrderCodeTests.cs](../Cinema_BE/BookingService/BookingService.Tests/Integration/PayOsOrderCodeTests.cs) |
| WEB-FR-PAY-10 ← FR-PAY-10 | WEB-BR-09, WEB-BR-10, WEB-BR-11, WEB-BR-12, WEB-BR-13, WEB-BR-14, WEB-BR-20 | UC-WEB-08 |  | WEB-API-094 | WEB-FR-PAY-10-AC-01, WEB-FR-PAY-10-AC-02; [Cinema_BE/BookingService/BookingService.Tests/Integration/BookingFlowTests.cs](../Cinema_BE/BookingService/BookingService.Tests/Integration/BookingFlowTests.cs); [Cinema_BE/BookingService/BookingService.Tests/Integration/PaymentSummaryTests.cs](../Cinema_BE/BookingService/BookingService.Tests/Integration/PaymentSummaryTests.cs); [Cinema_BE/BookingService/BookingService.Tests/Integration/PayOsOrderCodeTests.cs](../Cinema_BE/BookingService/BookingService.Tests/Integration/PayOsOrderCodeTests.cs) |
| WEB-FR-PAY-11 ← FR-PAY-11 | WEB-BR-09, WEB-BR-10, WEB-BR-11, WEB-BR-12, WEB-BR-13, WEB-BR-14, WEB-BR-20 | UC-WEB-08 | WEB-SCR-PAYMENT | WEB-API-046, WEB-API-087 | WEB-FR-PAY-11-AC-01, WEB-FR-PAY-11-AC-02; [Cinema_BE/BookingService/BookingService.Tests/Integration/BookingFlowTests.cs](../Cinema_BE/BookingService/BookingService.Tests/Integration/BookingFlowTests.cs); [Cinema_BE/BookingService/BookingService.Tests/Integration/PaymentSummaryTests.cs](../Cinema_BE/BookingService/BookingService.Tests/Integration/PaymentSummaryTests.cs); [Cinema_BE/BookingService/BookingService.Tests/Integration/PayOsOrderCodeTests.cs](../Cinema_BE/BookingService/BookingService.Tests/Integration/PayOsOrderCodeTests.cs) |
| WEB-FR-REF-01 ← FR-REF-01 | WEB-BR-17, WEB-BR-18, WEB-BR-19, WEB-BR-20 | UC-WEB-09 | WEB-SCR-TICKET | WEB-API-043, WEB-API-083, WEB-API-089 | WEB-FR-REF-01-AC-01, WEB-FR-REF-01-AC-02; [Cinema_BE/BookingService/BookingService.Tests/Integration/RefundTests.cs](../Cinema_BE/BookingService/BookingService.Tests/Integration/RefundTests.cs); [Cinema_Mobile/test/booking_details_ui_test.dart](../Cinema_Mobile/test/booking_details_ui_test.dart); [Cinema_Mobile/test/refund_details_ui_test.dart](../Cinema_Mobile/test/refund_details_ui_test.dart) |
| WEB-FR-REF-02 ← FR-REF-02 | WEB-BR-17, WEB-BR-18, WEB-BR-19, WEB-BR-20 | UC-WEB-09 | WEB-SCR-OPERATIONS, WEB-SCR-RECORD-REFUNDS | WEB-API-092, WEB-API-093 | WEB-FR-REF-02-AC-01, WEB-FR-REF-02-AC-02; [Cinema_BE/BookingService/BookingService.Tests/Integration/RefundTests.cs](../Cinema_BE/BookingService/BookingService.Tests/Integration/RefundTests.cs); [Cinema_Mobile/test/booking_details_ui_test.dart](../Cinema_Mobile/test/booking_details_ui_test.dart); [Cinema_Mobile/test/refund_details_ui_test.dart](../Cinema_Mobile/test/refund_details_ui_test.dart) |
| WEB-FR-REF-03 ← FR-REF-03 | WEB-BR-17, WEB-BR-18, WEB-BR-19, WEB-BR-20 | UC-WEB-09 | WEB-SCR-RECORD-REFUNDS | WEB-API-090 | WEB-FR-REF-03-AC-01, WEB-FR-REF-03-AC-02; [Cinema_BE/BookingService/BookingService.Tests/Integration/RefundTests.cs](../Cinema_BE/BookingService/BookingService.Tests/Integration/RefundTests.cs); [Cinema_Mobile/test/booking_details_ui_test.dart](../Cinema_Mobile/test/booking_details_ui_test.dart); [Cinema_Mobile/test/refund_details_ui_test.dart](../Cinema_Mobile/test/refund_details_ui_test.dart) |
| WEB-FR-REF-04 ← FR-REF-04 | WEB-BR-17, WEB-BR-18, WEB-BR-19, WEB-BR-20 | UC-WEB-09 | WEB-SCR-RECORD-REFUNDS | WEB-API-091 | WEB-FR-REF-04-AC-01, WEB-FR-REF-04-AC-02; [Cinema_BE/BookingService/BookingService.Tests/Integration/RefundTests.cs](../Cinema_BE/BookingService/BookingService.Tests/Integration/RefundTests.cs); [Cinema_Mobile/test/booking_details_ui_test.dart](../Cinema_Mobile/test/booking_details_ui_test.dart); [Cinema_Mobile/test/refund_details_ui_test.dart](../Cinema_Mobile/test/refund_details_ui_test.dart) |
| WEB-FR-REF-05 ← FR-REF-05 | WEB-BR-17, WEB-BR-18, WEB-BR-19, WEB-BR-20 | UC-WEB-09 | WEB-SCR-TICKET, WEB-SCR-RECORD-REFUNDS | WEB-API-016, WEB-API-043 | WEB-FR-REF-05-AC-01, WEB-FR-REF-05-AC-02; [Cinema_BE/BookingService/BookingService.Tests/Integration/RefundTests.cs](../Cinema_BE/BookingService/BookingService.Tests/Integration/RefundTests.cs); [Cinema_Mobile/test/booking_details_ui_test.dart](../Cinema_Mobile/test/booking_details_ui_test.dart); [Cinema_Mobile/test/refund_details_ui_test.dart](../Cinema_Mobile/test/refund_details_ui_test.dart) |
| WEB-FR-REF-06 ← FR-REF-06 | WEB-BR-17, WEB-BR-18, WEB-BR-19, WEB-BR-20 | UC-WEB-09 | WEB-SCR-TICKET, WEB-SCR-RECORD-PAYMENTS | WEB-API-082 | WEB-FR-REF-06-AC-01, WEB-FR-REF-06-AC-02; [Cinema_BE/BookingService/BookingService.Tests/Integration/RefundTests.cs](../Cinema_BE/BookingService/BookingService.Tests/Integration/RefundTests.cs); [Cinema_Mobile/test/booking_details_ui_test.dart](../Cinema_Mobile/test/booking_details_ui_test.dart); [Cinema_Mobile/test/refund_details_ui_test.dart](../Cinema_Mobile/test/refund_details_ui_test.dart) |
| WEB-FR-REF-07 ← FR-REF-07 | WEB-BR-17, WEB-BR-18, WEB-BR-19, WEB-BR-20 | UC-WEB-09 | WEB-SCR-RECORD-REFUNDS | WEB-API-043, WEB-API-082 | WEB-FR-REF-07-AC-01, WEB-FR-REF-07-AC-02; [Cinema_BE/BookingService/BookingService.Tests/Integration/RefundTests.cs](../Cinema_BE/BookingService/BookingService.Tests/Integration/RefundTests.cs); [Cinema_Mobile/test/booking_details_ui_test.dart](../Cinema_Mobile/test/booking_details_ui_test.dart); [Cinema_Mobile/test/refund_details_ui_test.dart](../Cinema_Mobile/test/refund_details_ui_test.dart) |
| WEB-FR-POS-01 ← FR-POS-01 | WEB-BR-08, WEB-BR-15, WEB-BR-16, WEB-BR-22, WEB-BR-23, WEB-BR-27, WEB-BR-28, WEB-BR-29 | UC-WEB-10 | WEB-SCR-COUNTER | WEB-API-013, WEB-API-023, WEB-API-030, WEB-API-055 | WEB-FR-POS-01-AC-01, WEB-FR-POS-01-AC-02; [Cinema_BE/BookingService/BookingService.Tests/Integration/CounterSaleTests.cs](../Cinema_BE/BookingService/BookingService.Tests/Integration/CounterSaleTests.cs); [Cinema_Mobile/test/counter_booking_test.dart](../Cinema_Mobile/test/counter_booking_test.dart) |
| WEB-FR-POS-02 ← FR-POS-02 | WEB-BR-08, WEB-BR-15, WEB-BR-16, WEB-BR-22, WEB-BR-23, WEB-BR-27, WEB-BR-28, WEB-BR-29 | UC-WEB-10 | WEB-SCR-CHECKOUT | WEB-API-046 | WEB-FR-POS-02-AC-01, WEB-FR-POS-02-AC-02; [Cinema_BE/BookingService/BookingService.Tests/Integration/CounterSaleTests.cs](../Cinema_BE/BookingService/BookingService.Tests/Integration/CounterSaleTests.cs); [Cinema_Mobile/test/counter_booking_test.dart](../Cinema_Mobile/test/counter_booking_test.dart) |
| WEB-FR-POS-03 ← FR-POS-03 | WEB-BR-08, WEB-BR-15, WEB-BR-16, WEB-BR-22, WEB-BR-23, WEB-BR-27, WEB-BR-28, WEB-BR-29 | UC-WEB-10 | WEB-SCR-CHECKOUT | WEB-API-086 | WEB-FR-POS-03-AC-01, WEB-FR-POS-03-AC-02; [Cinema_BE/BookingService/BookingService.Tests/Integration/CounterSaleTests.cs](../Cinema_BE/BookingService/BookingService.Tests/Integration/CounterSaleTests.cs); [Cinema_Mobile/test/counter_booking_test.dart](../Cinema_Mobile/test/counter_booking_test.dart) |
| WEB-FR-POS-04 ← FR-POS-04 | WEB-BR-08, WEB-BR-15, WEB-BR-16, WEB-BR-22, WEB-BR-23, WEB-BR-27, WEB-BR-28, WEB-BR-29 | UC-WEB-10 | WEB-SCR-CHECKOUT | WEB-API-087, WEB-API-088 | WEB-FR-POS-04-AC-01, WEB-FR-POS-04-AC-02; [Cinema_BE/BookingService/BookingService.Tests/Integration/CounterSaleTests.cs](../Cinema_BE/BookingService/BookingService.Tests/Integration/CounterSaleTests.cs); [Cinema_Mobile/test/counter_booking_test.dart](../Cinema_Mobile/test/counter_booking_test.dart) |
| WEB-FR-POS-05 ← FR-POS-05 | WEB-BR-08, WEB-BR-15, WEB-BR-16, WEB-BR-22, WEB-BR-23, WEB-BR-27, WEB-BR-28, WEB-BR-29 | UC-WEB-10 | WEB-SCR-CHECKOUT | WEB-API-086 | WEB-FR-POS-05-AC-01, WEB-FR-POS-05-AC-02; [Cinema_BE/BookingService/BookingService.Tests/Integration/CounterSaleTests.cs](../Cinema_BE/BookingService/BookingService.Tests/Integration/CounterSaleTests.cs); [Cinema_Mobile/test/counter_booking_test.dart](../Cinema_Mobile/test/counter_booking_test.dart) |
| WEB-FR-POS-06 ← FR-POS-06 | WEB-BR-08, WEB-BR-15, WEB-BR-16, WEB-BR-22, WEB-BR-23, WEB-BR-27, WEB-BR-28, WEB-BR-29 | UC-WEB-10 | WEB-SCR-CHECKOUT | WEB-API-055, WEB-API-086 | WEB-FR-POS-06-AC-01, WEB-FR-POS-06-AC-02; [Cinema_BE/BookingService/BookingService.Tests/Integration/CounterSaleTests.cs](../Cinema_BE/BookingService/BookingService.Tests/Integration/CounterSaleTests.cs); [Cinema_Mobile/test/counter_booking_test.dart](../Cinema_Mobile/test/counter_booking_test.dart) |
| WEB-FR-POS-07 ← FR-POS-07 | WEB-BR-08, WEB-BR-15, WEB-BR-16, WEB-BR-22, WEB-BR-23, WEB-BR-27, WEB-BR-28, WEB-BR-29 | UC-WEB-10 | WEB-SCR-CHECKOUT | WEB-API-044, WEB-API-046 | WEB-FR-POS-07-AC-01, WEB-FR-POS-07-AC-02; [Cinema_BE/BookingService/BookingService.Tests/Integration/CounterSaleTests.cs](../Cinema_BE/BookingService/BookingService.Tests/Integration/CounterSaleTests.cs); [Cinema_Mobile/test/counter_booking_test.dart](../Cinema_Mobile/test/counter_booking_test.dart) |
| WEB-FR-POS-08 ← FR-POS-08 | WEB-BR-08, WEB-BR-15, WEB-BR-16, WEB-BR-22, WEB-BR-23, WEB-BR-27, WEB-BR-28, WEB-BR-29 | UC-WEB-10 | WEB-SCR-CHECKOUT, WEB-SCR-RECORD-BOOKINGS | WEB-API-046 | WEB-FR-POS-08-AC-01, WEB-FR-POS-08-AC-02; [Cinema_BE/BookingService/BookingService.Tests/Integration/CounterSaleTests.cs](../Cinema_BE/BookingService/BookingService.Tests/Integration/CounterSaleTests.cs); [Cinema_Mobile/test/counter_booking_test.dart](../Cinema_Mobile/test/counter_booking_test.dart) |
| WEB-FR-CHK-01 ← FR-CHK-01 | WEB-BR-21 | UC-WEB-11 | WEB-SCR-TICKET, WEB-SCR-CHECKOUT | WEB-API-046 | WEB-FR-CHK-01-AC-01, WEB-FR-CHK-01-AC-02; [Cinema_BE/BookingService/BookingService.Tests/Integration/CheckInTests.cs](../Cinema_BE/BookingService/BookingService.Tests/Integration/CheckInTests.cs); [Cinema_Mobile/test/check_in_test.dart](../Cinema_Mobile/test/check_in_test.dart) |
| WEB-FR-CHK-02 ← FR-CHK-02 | WEB-BR-21 | UC-WEB-11 | WEB-SCR-CHECKIN | WEB-API-047 | WEB-FR-CHK-02-AC-01, WEB-FR-CHK-02-AC-02; [Cinema_BE/BookingService/BookingService.Tests/Integration/CheckInTests.cs](../Cinema_BE/BookingService/BookingService.Tests/Integration/CheckInTests.cs); [Cinema_Mobile/test/check_in_test.dart](../Cinema_Mobile/test/check_in_test.dart) |
| WEB-FR-CHK-03 ← FR-CHK-03 | WEB-BR-21 | UC-WEB-11 | WEB-SCR-CHECKIN, WEB-SCR-CHECKOUT | WEB-API-044 | WEB-FR-CHK-03-AC-01, WEB-FR-CHK-03-AC-02; [Cinema_BE/BookingService/BookingService.Tests/Integration/CheckInTests.cs](../Cinema_BE/BookingService/BookingService.Tests/Integration/CheckInTests.cs); [Cinema_Mobile/test/check_in_test.dart](../Cinema_Mobile/test/check_in_test.dart) |
| WEB-FR-CHK-04 ← FR-CHK-04 | WEB-BR-21 | UC-WEB-11 | WEB-SCR-CHECKIN | WEB-API-044, WEB-API-047 | WEB-FR-CHK-04-AC-01, WEB-FR-CHK-04-AC-02; [Cinema_BE/BookingService/BookingService.Tests/Integration/CheckInTests.cs](../Cinema_BE/BookingService/BookingService.Tests/Integration/CheckInTests.cs); [Cinema_Mobile/test/check_in_test.dart](../Cinema_Mobile/test/check_in_test.dart) |
| WEB-FR-CHK-05 ← FR-CHK-05 | WEB-BR-21 | UC-WEB-11 | WEB-SCR-TICKET, WEB-SCR-CHECKIN, WEB-SCR-RECORD-BOOKINGS | WEB-API-046, WEB-API-050 | WEB-FR-CHK-05-AC-01, WEB-FR-CHK-05-AC-02; [Cinema_BE/BookingService/BookingService.Tests/Integration/CheckInTests.cs](../Cinema_BE/BookingService/BookingService.Tests/Integration/CheckInTests.cs); [Cinema_Mobile/test/check_in_test.dart](../Cinema_Mobile/test/check_in_test.dart) |
| WEB-FR-NOTI-01 ← FR-NOTI-01 | WEB-BR-11, WEB-BR-13 | UC-WEB-12 | WEB-SCR-NOTIFICATIONS | WEB-API-078, WEB-API-079 | WEB-FR-NOTI-01-AC-01, WEB-FR-NOTI-01-AC-02; [Cinema_BE/BookingService/BookingService.Tests/Integration/ShowtimeReminderTests.cs](../Cinema_BE/BookingService/BookingService.Tests/Integration/ShowtimeReminderTests.cs); [Cinema_Mobile/test/notification_read_test.dart](../Cinema_Mobile/test/notification_read_test.dart) |
| WEB-FR-NOTI-02 ← FR-NOTI-02 | WEB-BR-11, WEB-BR-13 | UC-WEB-12 | WEB-SCR-COMPOSE | WEB-API-080 | WEB-FR-NOTI-02-AC-01, WEB-FR-NOTI-02-AC-02; [Cinema_BE/BookingService/BookingService.Tests/Integration/ShowtimeReminderTests.cs](../Cinema_BE/BookingService/BookingService.Tests/Integration/ShowtimeReminderTests.cs); [Cinema_Mobile/test/notification_read_test.dart](../Cinema_Mobile/test/notification_read_test.dart) |
| WEB-FR-NOTI-03 ← FR-NOTI-03 | WEB-BR-11, WEB-BR-13 | UC-WEB-12 | WEB-SCR-COMPOSE | WEB-API-073 | WEB-FR-NOTI-03-AC-01, WEB-FR-NOTI-03-AC-02; [Cinema_BE/BookingService/BookingService.Tests/Integration/ShowtimeReminderTests.cs](../Cinema_BE/BookingService/BookingService.Tests/Integration/ShowtimeReminderTests.cs); [Cinema_Mobile/test/notification_read_test.dart](../Cinema_Mobile/test/notification_read_test.dart) |
| WEB-FR-NOTI-04 ← FR-NOTI-04 | WEB-BR-11, WEB-BR-13 | UC-WEB-12 | WEB-SCR-NOTIFICATION | WEB-API-075 | WEB-FR-NOTI-04-AC-01, WEB-FR-NOTI-04-AC-02; [Cinema_BE/BookingService/BookingService.Tests/Integration/ShowtimeReminderTests.cs](../Cinema_BE/BookingService/BookingService.Tests/Integration/ShowtimeReminderTests.cs); [Cinema_Mobile/test/notification_read_test.dart](../Cinema_Mobile/test/notification_read_test.dart) |
| WEB-FR-NOTI-05 ← FR-NOTI-05 | WEB-BR-11, WEB-BR-13 | UC-WEB-12 |  | WEB-API-074 | WEB-FR-NOTI-05-AC-01, WEB-FR-NOTI-05-AC-02; [Cinema_BE/BookingService/BookingService.Tests/Integration/ShowtimeReminderTests.cs](../Cinema_BE/BookingService/BookingService.Tests/Integration/ShowtimeReminderTests.cs); [Cinema_Mobile/test/notification_read_test.dart](../Cinema_Mobile/test/notification_read_test.dart) |
| WEB-FR-NOTI-06 ← FR-NOTI-06 | WEB-BR-11, WEB-BR-13 | UC-WEB-12 |  | WEB-API-078 | WEB-FR-NOTI-06-AC-01, WEB-FR-NOTI-06-AC-02; [Cinema_BE/BookingService/BookingService.Tests/Integration/ShowtimeReminderTests.cs](../Cinema_BE/BookingService/BookingService.Tests/Integration/ShowtimeReminderTests.cs); [Cinema_Mobile/test/notification_read_test.dart](../Cinema_Mobile/test/notification_read_test.dart) |
| WEB-FR-NOTI-07 ← FR-NOTI-07 | WEB-BR-11, WEB-BR-13 | UC-WEB-12 |  | WEB-API-026, WEB-API-033, WEB-API-042 | WEB-FR-NOTI-07-AC-01, WEB-FR-NOTI-07-AC-02; [Cinema_BE/BookingService/BookingService.Tests/Integration/ShowtimeReminderTests.cs](../Cinema_BE/BookingService/BookingService.Tests/Integration/ShowtimeReminderTests.cs); [Cinema_Mobile/test/notification_read_test.dart](../Cinema_Mobile/test/notification_read_test.dart) |
| WEB-FR-NOTI-08 ← FR-NOTI-08 | WEB-BR-11, WEB-BR-13 | UC-WEB-12 |  | WEB-API-078 | WEB-FR-NOTI-08-AC-01, WEB-FR-NOTI-08-AC-02; [Cinema_BE/BookingService/BookingService.Tests/Integration/ShowtimeReminderTests.cs](../Cinema_BE/BookingService/BookingService.Tests/Integration/ShowtimeReminderTests.cs); [Cinema_Mobile/test/notification_read_test.dart](../Cinema_Mobile/test/notification_read_test.dart) |
| WEB-FR-NOTI-09 ← FR-NOTI-09 | WEB-BR-11, WEB-BR-13 | UC-WEB-12 | WEB-SCR-HOME, WEB-SCR-NOTIFICATIONS, WEB-SCR-NOTIFICATION | WEB-API-072, WEB-API-076, WEB-API-077 | WEB-FR-NOTI-09-AC-01, WEB-FR-NOTI-09-AC-02; [Cinema_BE/BookingService/BookingService.Tests/Integration/ShowtimeReminderTests.cs](../Cinema_BE/BookingService/BookingService.Tests/Integration/ShowtimeReminderTests.cs); [Cinema_Mobile/test/notification_read_test.dart](../Cinema_Mobile/test/notification_read_test.dart) |
| WEB-FR-DASH-01 ← FR-DASH-01 | WEB-BR-09, WEB-BR-23 | UC-WEB-13 | WEB-SCR-STAFF-DASH, WEB-SCR-ADMIN-DASH | WEB-API-019, WEB-API-048, WEB-API-051 | WEB-FR-DASH-01-AC-01, WEB-FR-DASH-01-AC-02; [Cinema_BE/BookingService/BookingService.Tests/Integration/PaymentSummaryTests.cs](../Cinema_BE/BookingService/BookingService.Tests/Integration/PaymentSummaryTests.cs); [Cinema_Mobile/test/today_at_cinema_test.dart](../Cinema_Mobile/test/today_at_cinema_test.dart) |
| WEB-FR-DASH-02 ← FR-DASH-02 | WEB-BR-09, WEB-BR-23 | UC-WEB-13 | WEB-SCR-STAFF-DASH, WEB-SCR-ADMIN-DASH | WEB-API-019, WEB-API-051 | WEB-FR-DASH-02-AC-01, WEB-FR-DASH-02-AC-02; [Cinema_BE/BookingService/BookingService.Tests/Integration/PaymentSummaryTests.cs](../Cinema_BE/BookingService/BookingService.Tests/Integration/PaymentSummaryTests.cs); [Cinema_Mobile/test/today_at_cinema_test.dart](../Cinema_Mobile/test/today_at_cinema_test.dart) |
| WEB-FR-DASH-03 ← FR-DASH-03 | WEB-BR-09, WEB-BR-23 | UC-WEB-13 | WEB-SCR-STAFF-DASH | WEB-API-052, WEB-API-093 | WEB-FR-DASH-03-AC-01, WEB-FR-DASH-03-AC-02; [Cinema_BE/BookingService/BookingService.Tests/Integration/PaymentSummaryTests.cs](../Cinema_BE/BookingService/BookingService.Tests/Integration/PaymentSummaryTests.cs); [Cinema_Mobile/test/today_at_cinema_test.dart](../Cinema_Mobile/test/today_at_cinema_test.dart) |
| WEB-FR-DASH-04 ← FR-DASH-04 | WEB-BR-09, WEB-BR-23 | UC-WEB-13 | WEB-SCR-ADMIN-DASH | WEB-API-040, WEB-API-048, WEB-API-069, WEB-API-094 | WEB-FR-DASH-04-AC-01, WEB-FR-DASH-04-AC-02; [Cinema_BE/BookingService/BookingService.Tests/Integration/PaymentSummaryTests.cs](../Cinema_BE/BookingService/BookingService.Tests/Integration/PaymentSummaryTests.cs); [Cinema_Mobile/test/today_at_cinema_test.dart](../Cinema_Mobile/test/today_at_cinema_test.dart) |
| WEB-FR-NAV-01 ← Từ code | WEB-BR-01, WEB-BR-02, WEB-BR-03, WEB-BR-24, WEB-BR-25 | UC-WEB-01 | WEB-SCR-LOGIN, WEB-SCR-STAFF-ONLY | — | WEB-FR-NAV-01-AC-01, WEB-FR-NAV-01-AC-02; [Cinema_BE/AuthService/AuthService.Tests/Integration/AccountValidationTests.cs](../Cinema_BE/AuthService/AuthService.Tests/Integration/AccountValidationTests.cs); [Cinema_BE/AuthService/AuthService.Tests/Integration/AuthFlowTests.cs](../Cinema_BE/AuthService/AuthService.Tests/Integration/AuthFlowTests.cs); [Cinema_Mobile/test/account_lock_flow_test.dart](../Cinema_Mobile/test/account_lock_flow_test.dart) |
| WEB-FR-STATE-01 ← Từ code | WEB-BR-07, WEB-BR-08, WEB-BR-14, WEB-BR-15, WEB-BR-16, WEB-BR-17, WEB-BR-27, WEB-BR-28, WEB-BR-29 | UC-WEB-07 |  | — | WEB-FR-STATE-01-AC-01, WEB-FR-STATE-01-AC-02; [Cinema_BE/BookingService/BookingService.Tests/Integration/BookingFlowTests.cs](../Cinema_BE/BookingService/BookingService.Tests/Integration/BookingFlowTests.cs); [Cinema_BE/BookingService/BookingService.Tests/Integration/ConcessionTests.cs](../Cinema_BE/BookingService/BookingService.Tests/Integration/ConcessionTests.cs); [Cinema_BE/BookingService/BookingService.Tests/Integration/LoyaltyTests.cs](../Cinema_BE/BookingService/BookingService.Tests/Integration/LoyaltyTests.cs) |
| WEB-FR-MEDIA-01 ← Từ code | WEB-BR-26 | UC-WEB-03 | WEB-SCR-HOME | WEB-API-064 | WEB-FR-MEDIA-01-AC-01, WEB-FR-MEDIA-01-AC-02; [Cinema_BE/BookingService/BookingService.Tests/Integration/MovieReviewTests.cs](../Cinema_BE/BookingService/BookingService.Tests/Integration/MovieReviewTests.cs); [Cinema_Mobile/test/age_rating_test.dart](../Cinema_Mobile/test/age_rating_test.dart); [Cinema_Mobile/test/coming_soon_test.dart](../Cinema_Mobile/test/coming_soon_test.dart) |

## 23. Ràng buộc

| ID | Ràng buộc / mục chưa rõ |
| --- | --- |
| WEB-CON-01 | Triển khai .NET là backend API. UI môn học MVC/Razor/Blazor riêng là [CẦN XÁC NHẬN]. |
| WEB-CON-02 | Submodule DB vắng/chưa khởi tạo; DDL/seed SQL chính xác và migrate thật [CẦN XÁC NHẬN]. EF/migration cục bộ là bằng chứng sẵn có. |
| WEB-CON-03 | Khoá thật, webhook công khai, SMTP và URL triển khai là phụ thuộc môi trường. Không tạo giao dịch tài chính/email để viết tài liệu. |
| WEB-CON-04 | Nghiệm thu OS/thiết bị thật, ký/phát hành cửa hàng, SLA, lưu backup và mục tiêu tải [CẦN XÁC NHẬN]. Khung nền tảng không phải chứng nhận tương thích. |
| WEB-CON-05 | Gateway emulator Android mặc định http://10.0.2.2:5000; mục tiêu cục bộ khác http://localhost:5000. Điện thoại cần API_BASE_URL truy cập được; ADMIN_URL/CUSTOMER_URL/PAYMENT_RETURN_URL theo triển khai. |

## 24. Ngoài phạm vi

Loại công việc chỉ native, phát hành cửa hàng và UI .NET dựng giả định. Check-in native điện thoại thuộc Mobile; check-in camera trình duyệt thuộc tài liệu này.

Không khẳng định đã có FCM hoặc tích hợp hoàn ngân hàng tự động. Không bổ sung lương, kho hoặc gợi ý AI. Bắp nước, khuyến mãi/mã, thành viên/điểm và đánh giá hiện có giữ trong phạm vi nơi code thực sự cung cấp.

## 25. Cải tiến tương lai

| ID | Tương lai, không phải FR hiện tại | Lý do |
| --- | --- | --- |
| WEB-FUT-01 | Tải thêm trang vé của mình | Hiện chỉ trả 50 vé đầu cho UI |
| WEB-FUT-02 | FCM nếu được chấp thuận | Thông báo hiện là email/lịch sử API |
| WEB-FUT-03 | Hoàn tự động nếu chọn nhà cung cấp phù hợp | Luồng hiện ghi chuyển thủ công ngoài hệ thống |

## 26. Kết luận

Đặc tả phân bổ một hệ thống theo ranh giới môn/client, giữ tương ứng ngôn ngữ và nêu rõ chức năng chỉ API, phụ thuộc chung và khoảng trống chưa kiểm chứng. Tài liệu hỗ trợ thiết kế test và giải thích triển khai thật.

## 27. Đối chiếu yêu cầu và triển khai

Từ vựng trạng thái: Đã triển khai; Triển khai một phần; Chỉ giao diện; Dữ liệu giả; Chờ backend; Chưa triển khai; Cần xác nhận. Chỉ dùng trạng thái áp dụng. Phụ thuộc sản phẩm dùng AppDependencies.remote; giả lập test không phải dữ liệu giả sản phẩm.

| Chức năng | Yêu cầu SRS | Trạng thái code | Trạng thái API | Ghi chú |
| --- | --- | --- | --- | --- |
| Đăng ký | WEB-FR-AUTH-01 | Đã triển khai | Có controller; chưa kiểm chứng chạy | Có bằng chứng triển khai tĩnh; chưa chạy nghiệm thu thực tế. |
| Đăng nhập | WEB-FR-AUTH-02 | Đã triển khai | Có controller; chưa kiểm chứng chạy | Có bằng chứng triển khai tĩnh; chưa chạy nghiệm thu thực tế. |
| Thông tin JWT | WEB-FR-AUTH-03 | Đã triển khai | Có controller; chưa kiểm chứng chạy | Có bằng chứng triển khai tĩnh; chưa chạy nghiệm thu thực tế. |
| Kiểm tra JWT | WEB-FR-AUTH-04 | Đã triển khai | Có controller; chưa kiểm chứng chạy | Có bằng chứng triển khai tĩnh; chưa chạy nghiệm thu thực tế. |
| Phân quyền vai trò | WEB-FR-AUTH-05 | Đã triển khai | Có controller; chưa kiểm chứng chạy | Có bằng chứng triển khai tĩnh; chưa chạy nghiệm thu thực tế. |
| Phản hồi chưa xác thực và thiếu quyền | WEB-FR-AUTH-06 | Đã triển khai | Có controller; chưa kiểm chứng chạy | Có bằng chứng triển khai tĩnh; chưa chạy nghiệm thu thực tế. |
| Xác thực OTP email | WEB-FR-AUTH-07 | Đã triển khai | Có controller; chưa kiểm chứng chạy | Có bằng chứng triển khai tĩnh; chưa chạy nghiệm thu thực tế. |
| Đăng ký lại email chưa xác thực | WEB-FR-AUTH-08 | Đã triển khai | Có controller; chưa kiểm chứng chạy | Có bằng chứng triển khai tĩnh; chưa chạy nghiệm thu thực tế. |
| Khôi phục mật khẩu | WEB-FR-AUTH-09 | Đã triển khai | Có controller; chưa kiểm chứng chạy | Có bằng chứng triển khai tĩnh; chưa chạy nghiệm thu thực tế. |
| Làm mới và đăng xuất | WEB-FR-AUTH-10 | Đã triển khai | Có controller; chưa kiểm chứng chạy | Có bằng chứng triển khai tĩnh; chưa chạy nghiệm thu thực tế. |
| Tài khoản hiện tại | WEB-FR-AUTH-11 | Đã triển khai | Có controller; chưa kiểm chứng chạy | Có bằng chứng triển khai tĩnh; chưa chạy nghiệm thu thực tế. |
| Áp dụng khoá và đổi quyền | WEB-FR-AUTH-12 | Đã triển khai | Có controller; chưa kiểm chứng chạy | Có bằng chứng triển khai tĩnh; chưa chạy nghiệm thu thực tế. |
| Kiểm tra trường tài khoản | WEB-FR-AUTH-13 | Đã triển khai | Có controller; chưa kiểm chứng chạy | Có bằng chứng triển khai tĩnh; chưa chạy nghiệm thu thực tế. |
| Giới hạn tần suất xác thực | WEB-FR-AUTH-14 | Đã triển khai | Có controller; chưa kiểm chứng chạy | Có bằng chứng triển khai tĩnh; chưa chạy nghiệm thu thực tế. |
| Tìm thành viên theo điện thoại | WEB-FR-AUTH-15 | Đã triển khai | Có controller; chưa kiểm chứng chạy | Có bằng chứng triển khai tĩnh; chưa chạy nghiệm thu thực tế. |
| Sửa hồ sơ | WEB-FR-AUTH-16 | Đã triển khai | Có controller; chưa kiểm chứng chạy | Có bằng chứng triển khai tĩnh; chưa chạy nghiệm thu thực tế. |
| Đổi mật khẩu hiện tại | WEB-FR-AUTH-17 | Đã triển khai | Có controller; chưa kiểm chứng chạy | Có bằng chứng triển khai tĩnh; chưa chạy nghiệm thu thực tế. |
| Danh sách tài khoản | WEB-FR-USER-01 | Đã triển khai | Có controller; chưa kiểm chứng chạy | Có bằng chứng triển khai tĩnh; chưa chạy nghiệm thu thực tế. |
| Chi tiết tài khoản | WEB-FR-USER-02 | Đã triển khai | Có controller; chưa kiểm chứng chạy | Có bằng chứng triển khai tĩnh; chưa chạy nghiệm thu thực tế. |
| Tạo tài khoản | WEB-FR-USER-03 | Đã triển khai | Có controller; chưa kiểm chứng chạy | Có bằng chứng triển khai tĩnh; chưa chạy nghiệm thu thực tế. |
| Đổi vai trò tài khoản | WEB-FR-USER-04 | Đã triển khai | Có controller; chưa kiểm chứng chạy | Có bằng chứng triển khai tĩnh; chưa chạy nghiệm thu thực tế. |
| Khoá và mở khoá | WEB-FR-USER-05 | Đã triển khai | Có controller; chưa kiểm chứng chạy | Có bằng chứng triển khai tĩnh; chưa chạy nghiệm thu thực tế. |
| Danh sách vai trò | WEB-FR-USER-06 | Đã triển khai | Có controller; chưa kiểm chứng chạy | Có bằng chứng triển khai tĩnh; chưa chạy nghiệm thu thực tế. |
| Danh mục phân trang | WEB-FR-MOV-01 | Đã triển khai | Có controller; chưa kiểm chứng chạy | Có bằng chứng triển khai tĩnh; chưa chạy nghiệm thu thực tế. |
| Chi tiết phim | WEB-FR-MOV-02 | Đã triển khai | Có controller; chưa kiểm chứng chạy | Có bằng chứng triển khai tĩnh; chưa chạy nghiệm thu thực tế. |
| Tìm theo tên | WEB-FR-MOV-03 | Đã triển khai | Có controller; chưa kiểm chứng chạy | Có bằng chứng triển khai tĩnh; chưa chạy nghiệm thu thực tế. |
| Danh mục đang hoạt động | WEB-FR-MOV-04 | Đã triển khai | Có controller; chưa kiểm chứng chạy | Có bằng chứng triển khai tĩnh; chưa chạy nghiệm thu thực tế. |
| Tạo phim | WEB-FR-MOV-05 | Đã triển khai | Có controller; chưa kiểm chứng chạy | Có bằng chứng triển khai tĩnh; chưa chạy nghiệm thu thực tế. |
| Sửa và chiếu lại phim | WEB-FR-MOV-06 | Đã triển khai | Có controller; chưa kiểm chứng chạy | Có bằng chứng triển khai tĩnh; chưa chạy nghiệm thu thực tế. |
| Ngừng chiếu phim | WEB-FR-MOV-07 | Đã triển khai | Có controller; chưa kiểm chứng chạy | Có bằng chứng triển khai tĩnh; chưa chạy nghiệm thu thực tế. |
| Mở trailer | WEB-FR-MOV-08 | Đã triển khai | Có controller; chưa kiểm chứng chạy | Có bằng chứng triển khai tĩnh; chưa chạy nghiệm thu thực tế. |
| Phân loại tuổi | WEB-FR-MOV-09 | Đã triển khai | Có controller; chưa kiểm chứng chạy | Có bằng chứng triển khai tĩnh; chưa chạy nghiệm thu thực tế. |
| Đang chiếu và sắp chiếu | WEB-FR-MOV-10 | Đã triển khai | Có controller; chưa kiểm chứng chạy | Có bằng chứng triển khai tĩnh; chưa chạy nghiệm thu thực tế. |
| Đạo diễn và diễn viên | WEB-FR-MOV-11 | Đã triển khai | Có controller; chưa kiểm chứng chạy | Có bằng chứng triển khai tĩnh; chưa chạy nghiệm thu thực tế. |
| Đánh giá phim | WEB-FR-MOV-12 | Đã triển khai | Có controller; chưa kiểm chứng chạy | Có bằng chứng triển khai tĩnh; chưa chạy nghiệm thu thực tế. |
| Tìm phòng | WEB-FR-ROOM-01 | Đã triển khai | Có controller; chưa kiểm chứng chạy | Có bằng chứng triển khai tĩnh; chưa chạy nghiệm thu thực tế. |
| Chi tiết phòng | WEB-FR-ROOM-02 | Đã triển khai | Có controller; chưa kiểm chứng chạy | Có bằng chứng triển khai tĩnh; chưa chạy nghiệm thu thực tế. |
| Tạo phòng và ghế | WEB-FR-ROOM-03 | Đã triển khai | Có controller; chưa kiểm chứng chạy | Có bằng chứng triển khai tĩnh; chưa chạy nghiệm thu thực tế. |
| Đổi tên phòng | WEB-FR-ROOM-04 | Đã triển khai | Có controller; chưa kiểm chứng chạy | Có bằng chứng triển khai tĩnh; chưa chạy nghiệm thu thực tế. |
| Xoá phòng đủ điều kiện | WEB-FR-ROOM-05 | Đã triển khai | Có controller; chưa kiểm chứng chạy | Có bằng chứng triển khai tĩnh; chưa chạy nghiệm thu thực tế. |
| Sinh ghế | WEB-FR-SEAT-01 | Đã triển khai | Có controller; chưa kiểm chứng chạy | Có bằng chứng triển khai tĩnh; chưa chạy nghiệm thu thực tế. |
| Chi tiết ghế | WEB-FR-SEAT-02 | Đã triển khai | Có controller; chưa kiểm chứng chạy | Có bằng chứng triển khai tĩnh; chưa chạy nghiệm thu thực tế. |
| Xem sơ đồ phòng | WEB-FR-SEAT-03 | Đã triển khai | Có controller; chưa kiểm chứng chạy | Có bằng chứng triển khai tĩnh; chưa chạy nghiệm thu thực tế. |
| API xoá ghế | WEB-FR-SEAT-04 | Đã triển khai | Có controller; chưa kiểm chứng chạy | Chỉ API; chưa có thao tác UI riêng hiện tại. |
| Đổi loại ghế | WEB-FR-SEAT-05 | Đã triển khai | Có controller; chưa kiểm chứng chạy | Có bằng chứng triển khai tĩnh; chưa chạy nghiệm thu thực tế. |
| Đổi loại nhiều ghế | WEB-FR-SEAT-06 | Đã triển khai | Có controller; chưa kiểm chứng chạy | Có bằng chứng triển khai tĩnh; chưa chạy nghiệm thu thực tế. |
| Đổi sức chứa | WEB-FR-SEAT-07 | Đã triển khai | Có controller; chưa kiểm chứng chạy | Có bằng chứng triển khai tĩnh; chưa chạy nghiệm thu thực tế. |
| Bảo vệ phòng đã xếp lịch | WEB-FR-SEAT-08 | Đã triển khai | Có controller; chưa kiểm chứng chạy | Có bằng chứng triển khai tĩnh; chưa chạy nghiệm thu thực tế. |
| Làm mới sơ đồ quản lý | WEB-FR-SEAT-09 | Đã triển khai | Có controller; chưa kiểm chứng chạy | Có bằng chứng triển khai tĩnh; chưa chạy nghiệm thu thực tế. |
| Danh sách suất | WEB-FR-SHOW-01 | Đã triển khai | Có controller; chưa kiểm chứng chạy | Có bằng chứng triển khai tĩnh; chưa chạy nghiệm thu thực tế. |
| Tạo suất | WEB-FR-SHOW-02 | Đã triển khai | Có controller; chưa kiểm chứng chạy | Có bằng chứng triển khai tĩnh; chưa chạy nghiệm thu thực tế. |
| Suất và giá | WEB-FR-SHOW-03 | Đã triển khai | Có controller; chưa kiểm chứng chạy | Có bằng chứng triển khai tĩnh; chưa chạy nghiệm thu thực tế. |
| Sửa suất | WEB-FR-SHOW-04 | Đã triển khai | Có controller; chưa kiểm chứng chạy | Có bằng chứng triển khai tĩnh; chưa chạy nghiệm thu thực tế. |
| Huỷ suất | WEB-FR-SHOW-05 | Đã triển khai | Có controller; chưa kiểm chứng chạy | Có bằng chứng triển khai tĩnh; chưa chạy nghiệm thu thực tế. |
| Suất mở chưa bắt đầu | WEB-FR-SHOW-06 | Đã triển khai | Có controller; chưa kiểm chứng chạy | Có bằng chứng triển khai tĩnh; chưa chạy nghiệm thu thực tế. |
| Suất theo phim | WEB-FR-SHOW-07 | Đã triển khai | Có controller; chưa kiểm chứng chạy | Có bằng chứng triển khai tĩnh; chưa chạy nghiệm thu thực tế. |
| Suất phim còn đặt được | WEB-FR-SHOW-08 | Đã triển khai | Có controller; chưa kiểm chứng chạy | Có bằng chứng triển khai tĩnh; chưa chạy nghiệm thu thực tế. |
| Tìm theo khoảng ngày | WEB-FR-SHOW-09 | Đã triển khai | Có controller; chưa kiểm chứng chạy | Có bằng chứng triển khai tĩnh; chưa chạy nghiệm thu thực tế. |
| Mở và đóng bán | WEB-FR-SHOW-10 | Đã triển khai | Có controller; chưa kiểm chứng chạy | Có bằng chứng triển khai tĩnh; chưa chạy nghiệm thu thực tế. |
| Từ chối trùng lịch | WEB-FR-SHOW-11 | Đã triển khai | Có controller; chưa kiểm chứng chạy | Có bằng chứng triển khai tĩnh; chưa chạy nghiệm thu thực tế. |
| Sơ đồ ghế/khách của suất | WEB-FR-SHOW-12 | Đã triển khai | Có controller; chưa kiểm chứng chạy | Có bằng chứng triển khai tĩnh; chưa chạy nghiệm thu thực tế. |
| Định dạng chiếu | WEB-FR-SHOW-13 | Đã triển khai | Có controller; chưa kiểm chứng chạy | Có bằng chứng triển khai tĩnh; chưa chạy nghiệm thu thực tế. |
| Giữ chỗ đặt vé | WEB-FR-BOOK-01 | Đã triển khai | Có controller; chưa kiểm chứng chạy | Có bằng chứng triển khai tĩnh; chưa chạy nghiệm thu thực tế. |
| Chi tiết vé | WEB-FR-BOOK-02 | Đã triển khai | Có controller; chưa kiểm chứng chạy | Có bằng chứng triển khai tĩnh; chưa chạy nghiệm thu thực tế. |
| Tra vé quản lý | WEB-FR-BOOK-03 | Đã triển khai | Có controller; chưa kiểm chứng chạy | Có bằng chứng triển khai tĩnh; chưa chạy nghiệm thu thực tế. |
| Lịch sử vé của mình | WEB-FR-BOOK-04 | Triển khai một phần | Có controller; chưa kiểm chứng chạy | Chỉ tải 50 vé đầu; UI thiếu vé cũ hơn. |
| Xác nhận vé đã trả | WEB-FR-BOOK-05 | Đã triển khai | Có controller; chưa kiểm chứng chạy | Có bằng chứng triển khai tĩnh; chưa chạy nghiệm thu thực tế. |
| Huỷ vé | WEB-FR-BOOK-06 | Đã triển khai | Có controller; chưa kiểm chứng chạy | Có bằng chứng triển khai tĩnh; chưa chạy nghiệm thu thực tế. |
| ID ghế đã chiếm | WEB-FR-BOOK-07 | Đã triển khai | Có controller; chưa kiểm chứng chạy | Có bằng chứng triển khai tĩnh; chưa chạy nghiệm thu thực tế. |
| Xung đột ghế đồng thời | WEB-FR-BOOK-08 | Đã triển khai | Có controller; chưa kiểm chứng chạy | Có bằng chứng triển khai tĩnh; chưa chạy nghiệm thu thực tế. |
| Cặp sweetbox | WEB-FR-BOOK-09 | Đã triển khai | Có controller; chưa kiểm chứng chạy | Có bằng chứng triển khai tĩnh; chưa chạy nghiệm thu thực tế. |
| Hết hạn giữ chỗ chưa trả | WEB-FR-BOOK-10 | Đã triển khai | Có controller; chưa kiểm chứng chạy | Có bằng chứng triển khai tĩnh; chưa chạy nghiệm thu thực tế. |
| Làm mới sơ đồ khách | WEB-FR-BOOK-11 | Đã triển khai | Có controller; chưa kiểm chứng chạy | Có bằng chứng triển khai tĩnh; chưa chạy nghiệm thu thực tế. |
| Thống kê vé theo suất | WEB-FR-BOOK-12 | Đã triển khai | Có controller; chưa kiểm chứng chạy | Có bằng chứng triển khai tĩnh; chưa chạy nghiệm thu thực tế. |
| Bắp nước kèm vé | WEB-FR-BOOK-13 | Đã triển khai | Có controller; chưa kiểm chứng chạy | Có bằng chứng triển khai tĩnh; chưa chạy nghiệm thu thực tế. |
| Quản lý bắp nước | WEB-FR-BOOK-14 | Đã triển khai | Có controller; chưa kiểm chứng chạy | Có bằng chứng triển khai tĩnh; chưa chạy nghiệm thu thực tế. |
| Khuyến mãi và mã giảm giá | WEB-FR-BOOK-15 | Đã triển khai | Có controller; chưa kiểm chứng chạy | Có bằng chứng triển khai tĩnh; chưa chạy nghiệm thu thực tế. |
| Quản lý khuyến mãi | WEB-FR-BOOK-16 | Đã triển khai | Có controller; chưa kiểm chứng chạy | Có bằng chứng triển khai tĩnh; chưa chạy nghiệm thu thực tế. |
| Điểm thành viên | WEB-FR-BOOK-17 | Đã triển khai | Có controller; chưa kiểm chứng chạy | Có bằng chứng triển khai tĩnh; chưa chạy nghiệm thu thực tế. |
| Quản lý thành viên | WEB-FR-BOOK-18 | Đã triển khai | Có controller; chưa kiểm chứng chạy | Có bằng chứng triển khai tĩnh; chưa chạy nghiệm thu thực tế. |
| Chia sẻ và lịch | WEB-FR-BOOK-19 | Triển khai một phần | Có controller; chưa kiểm chứng chạy | Lịch dùng giờ kết thúc thật hoặc dự phòng 150 phút; chia sẻ dự phòng clipboard. |
| Tạo/dùng lại link PayOS | WEB-FR-PAY-01 | Đã triển khai | Có controller; chưa kiểm chứng chạy | Có bằng chứng triển khai tĩnh; chưa chạy nghiệm thu thực tế. |
| Xác minh PayOS | WEB-FR-PAY-02 | Đã triển khai | Có controller; chưa kiểm chứng chạy | Có bằng chứng triển khai tĩnh; chưa chạy nghiệm thu thực tế. |
| Chi tiết thanh toán | WEB-FR-PAY-03 | Đã triển khai | Có controller; chưa kiểm chứng chạy | Có bằng chứng triển khai tĩnh; chưa chạy nghiệm thu thực tế. |
| Lịch sử thanh toán của mình | WEB-FR-PAY-04 | Đã triển khai | Có controller; chưa kiểm chứng chạy | Có bằng chứng triển khai tĩnh; chưa chạy nghiệm thu thực tế. |
| Thanh toán theo vé | WEB-FR-PAY-05 | Đã triển khai | Có controller; chưa kiểm chứng chạy | Có bằng chứng triển khai tĩnh; chưa chạy nghiệm thu thực tế. |
| Truy cập hoàn tiền | WEB-FR-PAY-06 | Đã triển khai | Có controller; chưa kiểm chứng chạy | Có bằng chứng triển khai tĩnh; chưa chạy nghiệm thu thực tế. |
| Webhook có chữ ký | WEB-FR-PAY-07 | Đã triển khai | Có controller; chưa kiểm chứng chạy | Có bằng chứng triển khai tĩnh; chưa chạy nghiệm thu thực tế. |
| Thanh toán muộn | WEB-FR-PAY-08 | Đã triển khai | Có controller; chưa kiểm chứng chạy | Có bằng chứng triển khai tĩnh; chưa chạy nghiệm thu thực tế. |
| Quản lý thanh toán | WEB-FR-PAY-09 | Đã triển khai | Có controller; chưa kiểm chứng chạy | Có bằng chứng triển khai tĩnh; chưa chạy nghiệm thu thực tế. |
| Tổng hợp doanh thu | WEB-FR-PAY-10 | Đã triển khai | Có controller; chưa kiểm chứng chạy | Có bằng chứng triển khai tĩnh; chưa chạy nghiệm thu thực tế. |
| Tự kiểm tra thanh toán | WEB-FR-PAY-11 | Đã triển khai | Có controller; chưa kiểm chứng chạy | Có bằng chứng triển khai tĩnh; chưa chạy nghiệm thu thực tế. |
| Tạo yêu cầu hoàn tiền | WEB-FR-REF-01 | Đã triển khai | Có controller; chưa kiểm chứng chạy | Có bằng chứng triển khai tĩnh; chưa chạy nghiệm thu thực tế. |
| Danh sách hoàn tiền quản lý | WEB-FR-REF-02 | Đã triển khai | Có controller; chưa kiểm chứng chạy | Có bằng chứng triển khai tĩnh; chưa chạy nghiệm thu thực tế. |
| Ghi nhận chuyển tiền hoàn tất | WEB-FR-REF-03 | Đã triển khai | Có controller; chưa kiểm chứng chạy | Có bằng chứng triển khai tĩnh; chưa chạy nghiệm thu thực tế. |
| Từ chối hoàn tiền | WEB-FR-REF-04 | Đã triển khai | Có controller; chưa kiểm chứng chạy | Có bằng chứng triển khai tĩnh; chưa chạy nghiệm thu thực tế. |
| Mở lại hoàn tiền đã từ chối | WEB-FR-REF-05 | Đã triển khai | Có controller; chưa kiểm chứng chạy | Có bằng chứng triển khai tĩnh; chưa chạy nghiệm thu thực tế. |
| Trạng thái hoàn tiền của mình | WEB-FR-REF-06 | Đã triển khai | Có controller; chưa kiểm chứng chạy | Có bằng chứng triển khai tĩnh; chưa chạy nghiệm thu thực tế. |
| Một hoàn tiền mỗi thanh toán | WEB-FR-REF-07 | Đã triển khai | Có controller; chưa kiểm chứng chạy | Có bằng chứng triển khai tĩnh; chưa chạy nghiệm thu thực tế. |
| Tạo vé tại quầy | WEB-FR-POS-01 | Đã triển khai | Có controller; chưa kiểm chứng chạy | Có bằng chứng triển khai tĩnh; chưa chạy nghiệm thu thực tế. |
| Thu tiền tại quầy | WEB-FR-POS-02 | Đã triển khai | Có controller; chưa kiểm chứng chạy | Có bằng chứng triển khai tĩnh; chưa chạy nghiệm thu thực tế. |
| Tiền mặt và tiền thối | WEB-FR-POS-03 | Đã triển khai | Có controller; chưa kiểm chứng chạy | Có bằng chứng triển khai tĩnh; chưa chạy nghiệm thu thực tế. |
| QR chuyển khoản | WEB-FR-POS-04 | Đã triển khai | Có controller; chưa kiểm chứng chạy | Có bằng chứng triển khai tĩnh; chưa chạy nghiệm thu thực tế. |
| Đổi chuyển khoản sang tiền mặt | WEB-FR-POS-05 | Đã triển khai | Có controller; chưa kiểm chứng chạy | Có bằng chứng triển khai tĩnh; chưa chạy nghiệm thu thực tế. |
| Lưu email tại quầy | WEB-FR-POS-06 | Đã triển khai | Có controller; chưa kiểm chứng chạy | Có bằng chứng triển khai tĩnh; chưa chạy nghiệm thu thực tế. |
| In và cho vào | WEB-FR-POS-07 | Đã triển khai | Có controller; chưa kiểm chứng chạy | Có bằng chứng triển khai tĩnh; chưa chạy nghiệm thu thực tế. |
| Mở lại vé đã trả | WEB-FR-POS-08 | Đã triển khai | Có controller; chưa kiểm chứng chạy | Có bằng chứng triển khai tĩnh; chưa chạy nghiệm thu thực tế. |
| QR vé | WEB-FR-CHK-01 | Đã triển khai | Có controller; chưa kiểm chứng chạy | Có bằng chứng triển khai tĩnh; chưa chạy nghiệm thu thực tế. |
| Tra mã vé | WEB-FR-CHK-02 | Đã triển khai | Có controller; chưa kiểm chứng chạy | Có bằng chứng triển khai tĩnh; chưa chạy nghiệm thu thực tế. |
| Kiểm tra check-in | WEB-FR-CHK-03 | Đã triển khai | Có controller; chưa kiểm chứng chạy | Có bằng chứng triển khai tĩnh; chưa chạy nghiệm thu thực tế. |
| Camera/nhập mã | WEB-FR-CHK-04 | Đã triển khai | Có controller; chưa kiểm chứng chạy | Có bằng chứng triển khai tĩnh; chưa chạy nghiệm thu thực tế. |
| Hiện giờ check-in | WEB-FR-CHK-05 | Đã triển khai | Có controller; chưa kiểm chứng chạy | Có bằng chứng triển khai tĩnh; chưa chạy nghiệm thu thực tế. |
| Lịch sử thông báo | WEB-FR-NOTI-01 | Đã triển khai | Có controller; chưa kiểm chứng chạy | Có bằng chứng triển khai tĩnh; chưa chạy nghiệm thu thực tế. |
| Soạn tin cho vé | WEB-FR-NOTI-02 | Đã triển khai | Có controller; chưa kiểm chứng chạy | Có bằng chứng triển khai tĩnh; chưa chạy nghiệm thu thực tế. |
| Gửi/thử lại tin | WEB-FR-NOTI-03 | Đã triển khai | Có controller; chưa kiểm chứng chạy | Có bằng chứng triển khai tĩnh; chưa chạy nghiệm thu thực tế. |
| Chi tiết thông báo | WEB-FR-NOTI-04 | Đã triển khai | Có controller; chưa kiểm chứng chạy | Có bằng chứng triển khai tĩnh; chưa chạy nghiệm thu thực tế. |
| API xoá thông báo | WEB-FR-NOTI-05 | Đã triển khai | Có controller; chưa kiểm chứng chạy | Chỉ API; chưa có thao tác UI riêng hiện tại. |
| Email sự kiện | WEB-FR-NOTI-06 | Triển khai một phần | Có controller; chưa kiểm chứng chạy | Có chống lặp sự kiện; khoảng sự cố SMTP/DB không bảo đảm gửi đúng một lần tuyệt đối. |
| Email OTP và chào mừng | WEB-FR-NOTI-07 | Đã triển khai | Có controller; chưa kiểm chứng chạy | Có bằng chứng triển khai tĩnh; chưa chạy nghiệm thu thực tế. |
| Nhắc giờ chiếu | WEB-FR-NOTI-08 | Đã triển khai | Có controller; chưa kiểm chứng chạy | Có bằng chứng triển khai tĩnh; chưa chạy nghiệm thu thực tế. |
| Thông báo đã/chưa đọc | WEB-FR-NOTI-09 | Đã triển khai | Có controller; chưa kiểm chứng chạy | Có bằng chứng triển khai tĩnh; chưa chạy nghiệm thu thực tế. |
| Tổng hôm nay | WEB-FR-DASH-01 | Đã triển khai | Có controller; chưa kiểm chứng chạy | Có bằng chứng triển khai tĩnh; chưa chạy nghiệm thu thực tế. |
| Bảng suất trực tiếp | WEB-FR-DASH-02 | Đã triển khai | Có controller; chưa kiểm chứng chạy | Có bằng chứng triển khai tĩnh; chưa chạy nghiệm thu thực tế. |
| Việc nhân viên cần xử lý | WEB-FR-DASH-03 | Đã triển khai | Có controller; chưa kiểm chứng chạy | Có bằng chứng triển khai tĩnh; chưa chạy nghiệm thu thực tế. |
| Tổng quan tháng quản trị | WEB-FR-DASH-04 | Đã triển khai | Có controller; chưa kiểm chứng chạy | Có bằng chứng triển khai tĩnh; chưa chạy nghiệm thu thực tế. |
| Bảo vệ và khôi phục route | WEB-FR-NAV-01 | Đã triển khai | Client/nền tảng; không API riêng | Có bằng chứng triển khai tĩnh; chưa chạy nghiệm thu thực tế. |
| Trạng thái tải, lỗi và rỗng | WEB-FR-STATE-01 | Triển khai một phần | Client/nền tảng; không API riêng | Có widget trạng thái; chưa chạy kiểm tra toàn bộ thiết bị/nhánh lỗi. |
| Media phim theo nền tảng | WEB-FR-MEDIA-01 | Đã triển khai | Có controller; chưa kiểm chứng chạy | Có preview web và ảnh dự phòng; tự phát tuỳ trình duyệt. |

| Chức năng | Yêu cầu SRS | Trạng thái code | Trạng thái API | Ghi chú |
| --- | --- | --- | --- | --- |
| UI do .NET dựng | WEB-CON-01 | Chưa triển khai | Có API ASP.NET | Chỉ UI Flutter Web; yêu cầu môn [CẦN XÁC NHẬN] |
| Thông báo đẩy FCM | WEB-FUT-02 | Chưa triển khai | — | Tương lai, không phải FR hiện tại |
| Kiểm chứng SQL submodule DB | WEB-CON-02 | Cần xác nhận | Có mapping EF cục bộ | Submodule chưa khởi tạo; chưa kiểm tra DB thật |

## 28. Bằng chứng và đối chiếu nguồn

| Bằng chứng | Cách dùng / đối chiếu |
| --- | --- |
| [docs/SRS_EN.md](../docs/SRS_EN.md); [docs/SRS_VI.md](../docs/SRS_VI.md) | 125 FR cũ mỗi ngôn ngữ, tách phạm vi giữ hậu tố mã; NAV/STATE/MEDIA chi tiết hành vi code |
| [Cinema_BE/Cinema_Microservice_SRS_Complete.md](../Cinema_BE/Cinema_Microservice_SRS_Complete.md) | Ý định sáu service lịch sử; ba service hiện ưu tiên |
| [README.md](../README.md); [Cinema_Mobile/README.md](../Cinema_Mobile/README.md); [DEMO.md](../DEMO.md) | Điểm vào/cài đặt thật, không UI .NET riêng |
| [Cinema_Mobile/lib/app/routes/app_router.dart](../Cinema_Mobile/lib/app/routes/app_router.dart); [Cinema_Mobile/lib/admin/admin_router.dart](../Cinema_Mobile/lib/admin/admin_router.dart) | Route kênh/bảo vệ vai trò; quản lý native chỉ check-in |
| [Cinema_Mobile/lib/app/app_dependencies.dart](../Cinema_Mobile/lib/app/app_dependencies.dart); [Cinema_Mobile/lib/core/network/api_client.dart](../Cinema_Mobile/lib/core/network/api_client.dart) | Phụ thuộc thật, timeout 15 giây, gia hạn và thăm phiên công khai |
| [Cinema_BE/ApiGateway/ApiGateway/appsettings.json](../Cinema_BE/ApiGateway/ApiGateway/appsettings.json) | Policy/tần suất/health thật; số route mô tả cũ đã cũ |
| [.github/workflows/ci.yml](../.github/workflows/ci.yml); [.github/workflows/flutter.yml](../.github/workflows/flutter.yml) | CI khai báo; ghim Flutter 3.47.4 thay mô tả cũ; số test cũ chưa xác minh là tổng hiện tại |
| [Cinema_Mobile/lib/core/widgets/trailer_preview_stub.dart](../Cinema_Mobile/lib/core/widgets/trailer_preview_stub.dart); [Cinema_Mobile/lib/core/widgets/trailer_player_native.dart](../Cinema_Mobile/lib/core/widgets/trailer_player_native.dart) | Stub preview native rỗng; trailer đầy đủ mở ngoài |
| [Cinema_Mobile/lib/features/booking/widgets/ticket_share_actions.dart](../Cinema_Mobile/lib/features/booking/widgets/ticket_share_actions.dart) | Giờ kết thúc lịch dự phòng 150 phút, không luôn đúng giờ kết thúc suất |
| [Cinema_BE/BookingService/BookingService/Services/Implementations/NotificationService.cs](../Cinema_BE/BookingService/BookingService/Services/Implementations/NotificationService.cs) | Chống lặp sự kiện và gửi SMTP/DB không nguyên tử; không khẳng định đúng một lần tuyệt đối |

Kiểm kê rà soát: liệt kê 763 tệp; lập chỉ mục 594 tệp văn bản/code/cấu hình liên quan, gồm khoảng 64.397 dòng C#/Dart. Build/cache/vendor sinh tự động, media nhị phân, nội dung secret mã hoá và submodule DB thiếu không được dùng làm bằng chứng chức năng. Không chép giá trị secret.
