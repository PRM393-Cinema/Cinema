# ĐẶC TẢ YÊU CẦU PHẦN MỀM

# Cinema — Ứng dụng điện thoại

| Mục | Nội dung |
| --- | --- |
| Phiên bản | 3.0 |
| Ngày chốt | 2026-10-28 (Asia/Saigon) |
| Ngôn ngữ | Tiếng Việt |
| Trạng thái bằng chứng | Chốt theo code/tài liệu qua kiểm tra tĩnh; chưa kiểm chứng chạy |
| Tài liệu đối ứng | [Cinema_Mobile_SRS_EN.md](Cinema_Mobile_SRS_EN.md) |

## 1. Giới thiệu

CosmoQ Cinema là một hệ thống đặt vé và quản lý rạp có nhiều client. SRS theo môn này chi tiết hoá SRS tổng hợp 2.0 từ checkout hiện tại; không xác lập sản phẩm độc lập thứ hai. Route/controller/service/model thực thi ưu tiên hơn mô tả cũ. SRS 1.0 là ý định lịch sử.

H = bắt buộc; M = quan trọng; L = tuỳ chọn. Đã triển khai nghĩa là có mã nguồn, không có nghĩa test tích hợp đã đạt. Mỗi cặp EN/VI dùng cùng mã, phạm vi, ưu tiên và tiêu chí; không bản nào là tóm tắt.

## 2. Mục đích

Cung cấp hợp đồng cho phát triển, thiết kế ca kiểm thử, nghiệm thu và bảo vệ môn học. Mỗi FR xác định tác nhân, điều kiện, kích hoạt, luồng, ngoại lệ, kết quả và tiêu chí nghiệm thu, truy tới ca sử dụng, màn hình, API và bằng chứng code/test.

## 3. Phạm vi

Bao gồm tài khoản/OTP/phiên/hồ sơ khách Flutter native, phim/đánh giá/trailer, suất mở/ghế, bắp nước/khuyến mãi/điểm khi đặt, PayOS, vé/thanh toán/hoàn tiền của mình, thông báo, chia sẻ/lịch và check-in điện thoại cho nhân viên/quản trị viên. Quy tắc backend chung không cấp quyền quản trị điện thoại. Loại trang quản trị web dù mã nằm trong Cinema_Mobile.

Ranh giới công nghệ: không có MVC .cshtml, Razor/Blazor .razor hoặc dự án UI .NET riêng. “Web .NET” là phạm vi môn: REST ASP.NET Core cùng client Flutter Web hiện có. Yêu cầu bắt buộc UI do .NET dựng là [CẦN XÁC NHẬN], không phải bằng chứng đã triển khai.

## 4. Mô tả tổng thể

```text
Flutter main.dart (Customer + phone check-in)
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
| Nhân viên/quản trị viên | Tra/check-in điện thoại; quản trị khác thuộc web |
| Khách vãng lai | Người mua quầy qua nhân viên, không phải tác nhân điện thoại đã đăng nhập |
| PayOS / SMTP / tác vụ nền | Đối soát/thông điệp ngoài; hết hạn giữ ghế và trao đổi sự kiện đã commit |

## 7. Vai trò và phân quyền

| Thao tác | Chưa đăng nhập | Customer | Staff | Admin |
| --- | --- | --- | --- | --- |
| Xem phim/suất công khai | ✓ | ✓ | ✓ | ✓ |
| Vé/thanh toán/hồ sơ/đánh giá của mình | — | ✓ | Trang đầu theo vai trò | Trang đầu theo vai trò |
| Tra/check-in vé | — | — | ✓ | ✓ |

Bảo vệ UI kiểm soát điều hướng; policy controller và kiểm tra chủ bản ghi quyết định quyền. Tài khoản có thể có nhiều vai trò. Khách vào cổng quản trị thấy hướng dẫn về trang khách; quản lý vào cổng khách thấy hướng dẫn quản lý/check-in.

## 8. Quy tắc nghiệp vụ

| ID | Quy tắc |
| --- | --- |
| MOB-BR-01 | Tài khoản khách phải xác thực email bằng OTP trước khi đăng nhập. Tài khoản do Admin tạo không cần OTP. |
| MOB-BR-02 | Mọi API cần đăng nhập dùng JWT; gateway và service đều kiểm tra. |
| MOB-BR-03 | Quyền truy cập theo vai trò; Customer không dùng được API quản trị. |
| MOB-BR-04 | Mỗi ghế thuộc một phòng, không trùng vị trí (hàng + số) trong phòng. |
| MOB-BR-05 | Một suất chiếu thuộc một phim và một phòng, giờ bắt đầu phải trước giờ kết thúc. |
| MOB-BR-06 | Một phòng không có hai suất chiếu trùng thời gian (409). |
| MOB-BR-07 | Một ghế của một suất chiếu chỉ thuộc một booking còn hiệu lực (đang giữ hoặc đã bán). |
| MOB-BR-08 | Booking gắn với một suất chiếu và các ghế; gắn với tài khoản khách, trừ vé khách vãng lai bán tại quầy. |
| MOB-BR-09 | Một thanh toán thuộc một vé; chuyển trạng thái vé/thanh toán/hoàn tiền phải theo hợp đồng trạng thái ở mục 15. |
| MOB-BR-10 | Webhook PayOS phải đúng chữ ký HMAC-SHA256 trước khi dùng dữ liệu. |
| MOB-BR-11 | Event được ghi vào outbox trong cùng transaction với dữ liệu và chỉ gửi sau khi commit. |
| MOB-BR-12 | Lời gọi tới service khác hoặc PayOS có retry giới hạn và circuit breaker. |
| MOB-BR-13 | Lỗi gửi email hoặc RabbitMQ tạm dừng không làm hỏng giao dịch đặt vé / thanh toán. |
| MOB-BR-14 | Ghế được giữ 10 phút; quá hạn chưa thanh toán thì booking `EXPIRED` và ghế được nhả. |
| MOB-BR-15 | Giá ghế: giá suất chiếu là giá ghế thường; VIP +20%, sweetbox +30% mỗi ghế; phụ thu làm tròn tới 1.000đ. Server tự tính giá, không nhận giá từ client. |
| MOB-BR-16 | Sweetbox luôn được đặt, đổi loại và bán theo cặp. |
| MOB-BR-17 | Khách tự huỷ vé đã thanh toán khi còn ít nhất 2 giờ trước giờ chiếu và được hoàn 100%; muộn hơn phải liên hệ rạp. Staff/Admin huỷ được mọi lúc. |
| MOB-BR-18 | Mỗi payment có tối đa một yêu cầu hoàn tiền. Hoàn tiền được thực hiện bằng chuyển khoản thủ công và ghi nhận mã giao dịch. |
| MOB-BR-19 | Suất chiếu bị huỷ thì mọi vé còn hiệu lực của suất đó bị huỷ; vé đã thanh toán được tạo yêu cầu hoàn tiền. |
| MOB-BR-20 | Trả tiền muộn (booking đã hết hạn): ghế còn trống thì vẫn xác nhận vé; ghế đã bán cho người khác thì tự tạo yêu cầu hoàn 100%. |
| MOB-BR-21 | Check-in chỉ cho vé `CONFIRMED`, mỗi vé một lần, từ 3 giờ trước đến 2 giờ sau giờ chiếu. |
| MOB-BR-24 | Khoá tài khoản hoặc đổi vai trò có hiệu lực ngay ở request tiếp theo, kể cả khi token cũ còn hạn. |
| MOB-BR-25 | Quên mật khẩu trả 200 dù email tồn tại hay không; email/mật khẩu đăng nhập sai có chung thông báo. Đăng ký/gửi lại có thể lộ trạng thái tài khoản nên không khẳng định chống dò trên toàn hệ thống. |
| MOB-BR-26 | Phim ngừng chiếu không hiện khi duyệt nhưng giữ vé cũ. Client điện thoại không sửa sơ đồ phòng. |
| MOB-BR-27 | Khuyến mãi chỉ giảm tiền vé, tối đa 90%, làm tròn xuống 1.000đ; dùng một ưu đãi tự động tốt nhất hoặc mã nhập đủ điều kiện. Đếm lượt khi thanh toán thành công. |
| MOB-BR-28 | Một điểm bằng 1.000đ; dùng tối đa 50% sau khuyến mãi; ngưỡng chi tiêu MEMBER/VIP/VVIP là 0/2.000.000/5.000.000đ và tỷ lệ tích 5/7/10%. Thu hồi/hoàn tác động điểm theo huỷ/hết hạn/hoàn vé. |
| MOB-BR-29 | Mỗi vé tối đa mười món bắp nước đang bán khác nhau, mỗi món 1–20; lưu tên và đơn giá lúc mua, tính vào tổng thanh toán và hoàn tiền. |
| MOB-BR-30 | Giá định dạng cộng 0/20.000/40.000đ cho 2D/3D/IMAX trước phụ thu loại ghế; giá NORMAL/VIP/SWEETBOX do server trả. |

Quy tắc người vận hành ngoài quy định tác động backend chung, không bổ sung màn điện thoại. Giới hạn giờ là mặc định hiện tại và có thể đổi cấu hình triển khai.

## 9. Yêu cầu chức năng

AC-01 kiểm tra đúng hành vi đã nêu; AC-02 kiểm tra nhánh từ chối/quyền áp dụng. Chỉ thực hiện thao tác FR riêng quy định; ca sử dụng rộng cung cấp ngữ cảnh. Tiêu chí là đặc tả, không phải kết quả chạy test.

### MOB-FR-AUTH-01 — Đăng ký

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
| Tiêu chí nghiệm thu | **MOB-FR-AUTH-01-AC-01** — Với tiền điều kiện/kích hoạt, kiểm tra: Khách đăng ký bằng email, mật khẩu, họ tên, số điện thoại (không bắt buộc). Hệ thống gửi OTP xác thực, chưa cấp token. **MOB-FR-AUTH-01-AC-02** — Thử đầu vào sai/thiếu quyền/xung đột áp dụng và kiểm tra từ chối đã nêu, không đổi dữ liệu trái phép và không báo thành công sai. |
| Bằng chứng | [Cinema_BE/AuthService/AuthService/Controllers/AuthController.cs](../Cinema_BE/AuthService/AuthService/Controllers/AuthController.cs); [Cinema_Mobile/lib/features/auth/screens/register_screen.dart](../Cinema_Mobile/lib/features/auth/screens/register_screen.dart); [Cinema_BE/AuthService/AuthService/Service/AuthService.cs](../Cinema_BE/AuthService/AuthService/Service/AuthService.cs); [Cinema_BE/ApiGateway/ApiGateway/Program.cs](../Cinema_BE/ApiGateway/ApiGateway/Program.cs) |
| Quy tắc nghiệp vụ | MOB-BR-01, MOB-BR-02, MOB-BR-03, MOB-BR-24, MOB-BR-25 |
| Ca sử dụng / màn / API | UC-MOB-01; MOB-SCR-REGISTER; MOB-API-011 |

### MOB-FR-AUTH-02 — Đăng nhập

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
| Tiêu chí nghiệm thu | **MOB-FR-AUTH-02-AC-01** — Với tiền điều kiện/kích hoạt, kiểm tra: Đăng nhập bằng email + mật khẩu, nhận access token (JWT, 60 phút) và refresh token (7 ngày). Chưa xác thực email thì trả 403 `EMAIL_NOT_VERIFIED`. **MOB-FR-AUTH-02-AC-02** — Thử đầu vào sai/thiếu quyền/xung đột áp dụng và kiểm tra từ chối đã nêu, không đổi dữ liệu trái phép và không báo thành công sai. |
| Bằng chứng | [Cinema_BE/AuthService/AuthService/Controllers/AuthController.cs](../Cinema_BE/AuthService/AuthService/Controllers/AuthController.cs); [Cinema_Mobile/lib/features/auth/screens/login_screen.dart](../Cinema_Mobile/lib/features/auth/screens/login_screen.dart); [Cinema_BE/AuthService/AuthService/Service/AuthService.cs](../Cinema_BE/AuthService/AuthService/Service/AuthService.cs); [Cinema_BE/ApiGateway/ApiGateway/Program.cs](../Cinema_BE/ApiGateway/ApiGateway/Program.cs) |
| Quy tắc nghiệp vụ | MOB-BR-01, MOB-BR-02, MOB-BR-03, MOB-BR-24, MOB-BR-25 |
| Ca sử dụng / màn / API | UC-MOB-01; MOB-SCR-LOGIN; MOB-API-006 |

### MOB-FR-AUTH-03 — Thông tin JWT

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
| Tiêu chí nghiệm thu | **MOB-FR-AUTH-03-AC-01** — Với tiền điều kiện/kích hoạt, kiểm tra: JWT chứa userId, email và danh sách vai trò. **MOB-FR-AUTH-03-AC-02** — Thử đầu vào sai/thiếu quyền/xung đột áp dụng và kiểm tra từ chối đã nêu, không đổi dữ liệu trái phép và không báo thành công sai. |
| Bằng chứng | [Cinema_BE/AuthService/AuthService/Controllers/AuthController.cs](../Cinema_BE/AuthService/AuthService/Controllers/AuthController.cs); [Cinema_Mobile/lib/features/auth/screens/login_screen.dart](../Cinema_Mobile/lib/features/auth/screens/login_screen.dart); [Cinema_BE/AuthService/AuthService/Service/AuthService.cs](../Cinema_BE/AuthService/AuthService/Service/AuthService.cs); [Cinema_BE/ApiGateway/ApiGateway/Program.cs](../Cinema_BE/ApiGateway/ApiGateway/Program.cs) |
| Quy tắc nghiệp vụ | MOB-BR-01, MOB-BR-02, MOB-BR-03, MOB-BR-24, MOB-BR-25 |
| Ca sử dụng / màn / API | UC-MOB-01; MOB-SCR-LOGIN; MOB-API-006, MOB-API-010 |

### MOB-FR-AUTH-04 — Kiểm tra JWT

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
| Tiêu chí nghiệm thu | **MOB-FR-AUTH-04-AC-01** — Với tiền điều kiện/kích hoạt, kiểm tra: Gateway và service kiểm tra chữ ký, hạn, issuer, audience của JWT trước API cần đăng nhập. **MOB-FR-AUTH-04-AC-02** — Thử đầu vào sai/thiếu quyền/xung đột áp dụng và kiểm tra từ chối đã nêu, không đổi dữ liệu trái phép và không báo thành công sai. |
| Bằng chứng | [Cinema_BE/AuthService/AuthService/Controllers/AuthController.cs](../Cinema_BE/AuthService/AuthService/Controllers/AuthController.cs); [Cinema_BE/AuthService/AuthService/Service/AuthService.cs](../Cinema_BE/AuthService/AuthService/Service/AuthService.cs); [Cinema_BE/ApiGateway/ApiGateway/Program.cs](../Cinema_BE/ApiGateway/ApiGateway/Program.cs) |
| Quy tắc nghiệp vụ | MOB-BR-01, MOB-BR-02, MOB-BR-03, MOB-BR-24, MOB-BR-25 |
| Ca sử dụng / màn / API | UC-MOB-01; ; MOB-API-008 |

### MOB-FR-AUTH-05 — Phân quyền vai trò

| Trường | Đặc tả |
| --- | --- |
| Tên | Phân quyền vai trò |
| Mô tả | Route ứng dụng phân biệt khách hàng và tài khoản quản lý. Khách hàng dùng dữ liệu của mình; nhân viên/quản trị viên chỉ có nghiệp vụ quản lý check-in trên điện thoại. Backend tiếp tục kiểm tra quyền endpoint và bản ghi. |
| Tác nhân | Khách chưa đăng nhập; người có tài khoản; hệ thống |
| Tiền điều kiện | Gateway đã được cấu hình. Đăng ký/khôi phục cần SMTP; thao tác được bảo vệ cần phiên tài khoản hợp lệ. |
| Kích hoạt | Thực hiện “Phân quyền vai trò” hoặc sự kiện/tác vụ backend tương ứng. |
| Luồng chính | 1. Đọc đầu vào/tài nguyên hiện tại và phiên áp dụng. 2. Thực hiện thao tác này: Route ứng dụng phân biệt khách hàng và tài khoản quản lý. Khách hàng dùng dữ liệu của mình; nhân viên/quản trị viên chỉ có nghiệp vụ quản lý check-in trên điện thoại. Backend tiếp tục kiểm tra quyền endpoint và bản ghi. 3. Trả/hiển thị kết quả chính thức và làm mới dữ liệu bị tác động sau thành công. |
| Luồng thay thế / ngoại lệ | Từ chối trường sai (400), thông tin đăng nhập sai (401), email chưa xác thực (403), OTP cũ/sai hoặc vượt giới hạn gửi/tần suất (429). Xoá phiên khi tài khoản bị khoá/quyền thay đổi; hiển thị lỗi SMTP/phụ thuộc (503). |
| Hậu điều kiện | Dữ liệu/trạng thái đủ quyền được trả/hiển thị; đọc không đổi trạng thái vé/thanh toán. Dấu đã đọc thông báo chỉ đổi bằng thao tác ghi riêng. |
| Ưu tiên | H |
| Tiêu chí nghiệm thu | **MOB-FR-AUTH-05-AC-01** — Với tiền điều kiện/kích hoạt, kiểm tra: Route ứng dụng phân biệt khách hàng và tài khoản quản lý. Khách hàng dùng dữ liệu của mình; nhân viên/quản trị viên chỉ có nghiệp vụ quản lý check-in trên điện thoại. Backend tiếp tục kiểm tra quyền endpoint và bản ghi. **MOB-FR-AUTH-05-AC-02** — Thử đầu vào sai/thiếu quyền/xung đột áp dụng và kiểm tra từ chối đã nêu, không đổi dữ liệu trái phép và không báo thành công sai. |
| Bằng chứng | [Cinema_BE/AuthService/AuthService/Controllers/AuthController.cs](../Cinema_BE/AuthService/AuthService/Controllers/AuthController.cs); [Cinema_Mobile/lib/features/profile/screens/management_account_screen.dart](../Cinema_Mobile/lib/features/profile/screens/management_account_screen.dart); [Cinema_BE/AuthService/AuthService/Service/AuthService.cs](../Cinema_BE/AuthService/AuthService/Service/AuthService.cs); [Cinema_BE/ApiGateway/ApiGateway/Program.cs](../Cinema_BE/ApiGateway/ApiGateway/Program.cs) |
| Quy tắc nghiệp vụ | MOB-BR-01, MOB-BR-02, MOB-BR-03, MOB-BR-24, MOB-BR-25 |
| Ca sử dụng / màn / API | UC-MOB-01; MOB-SCR-MGT-LANDING; MOB-API-008 |

### MOB-FR-AUTH-06 — Phản hồi chưa xác thực và thiếu quyền

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
| Tiêu chí nghiệm thu | **MOB-FR-AUTH-06-AC-01** — Với tiền điều kiện/kích hoạt, kiểm tra: Chưa đăng nhập hoặc token sai trả 401; đủ đăng nhập nhưng thiếu quyền trả 403. **MOB-FR-AUTH-06-AC-02** — Thử đầu vào sai/thiếu quyền/xung đột áp dụng và kiểm tra từ chối đã nêu, không đổi dữ liệu trái phép và không báo thành công sai. |
| Bằng chứng | [Cinema_BE/AuthService/AuthService/Controllers/AuthController.cs](../Cinema_BE/AuthService/AuthService/Controllers/AuthController.cs); [Cinema_Mobile/lib/features/auth/screens/login_screen.dart](../Cinema_Mobile/lib/features/auth/screens/login_screen.dart); [Cinema_BE/AuthService/AuthService/Service/AuthService.cs](../Cinema_BE/AuthService/AuthService/Service/AuthService.cs); [Cinema_BE/ApiGateway/ApiGateway/Program.cs](../Cinema_BE/ApiGateway/ApiGateway/Program.cs) |
| Quy tắc nghiệp vụ | MOB-BR-01, MOB-BR-02, MOB-BR-03, MOB-BR-24, MOB-BR-25 |
| Ca sử dụng / màn / API | UC-MOB-01; MOB-SCR-LOGIN; MOB-API-008 |

### MOB-FR-AUTH-07 — Xác thực OTP email

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
| Tiêu chí nghiệm thu | **MOB-FR-AUTH-07-AC-01** — Với tiền điều kiện/kích hoạt, kiểm tra: Xác thực email bằng OTP 6 số: hết hạn sau 5 phút, tối đa 5 lần nhập, chờ 60 giây giữa hai lần gửi, mã mới thay mã cũ. Khi xác thực phải gửi kèm mật khẩu đã đăng ký; thành công thì đăng nhập luôn và gửi email chào mừng. **MOB-FR-AUTH-07-AC-02** — Thử đầu vào sai/thiếu quyền/xung đột áp dụng và kiểm tra từ chối đã nêu, không đổi dữ liệu trái phép và không báo thành công sai. |
| Bằng chứng | [Cinema_BE/AuthService/AuthService/Controllers/AuthController.cs](../Cinema_BE/AuthService/AuthService/Controllers/AuthController.cs); [Cinema_Mobile/lib/features/auth/screens/verify_email_screen.dart](../Cinema_Mobile/lib/features/auth/screens/verify_email_screen.dart); [Cinema_BE/AuthService/AuthService/Service/AuthService.cs](../Cinema_BE/AuthService/AuthService/Service/AuthService.cs); [Cinema_BE/ApiGateway/ApiGateway/Program.cs](../Cinema_BE/ApiGateway/ApiGateway/Program.cs) |
| Quy tắc nghiệp vụ | MOB-BR-01, MOB-BR-02, MOB-BR-03, MOB-BR-24, MOB-BR-25 |
| Ca sử dụng / màn / API | UC-MOB-01; MOB-SCR-VERIFY; MOB-API-012, MOB-API-014 |

### MOB-FR-AUTH-08 — Đăng ký lại email chưa xác thực

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
| Tiêu chí nghiệm thu | **MOB-FR-AUTH-08-AC-01** — Với tiền điều kiện/kích hoạt, kiểm tra: Đăng ký lại một email chưa xác thực thì thông tin mới thay thông tin cũ và gửi mã mới. Email đã xác thực thì báo đã đăng ký. **MOB-FR-AUTH-08-AC-02** — Thử đầu vào sai/thiếu quyền/xung đột áp dụng và kiểm tra từ chối đã nêu, không đổi dữ liệu trái phép và không báo thành công sai. |
| Bằng chứng | [Cinema_BE/AuthService/AuthService/Controllers/AuthController.cs](../Cinema_BE/AuthService/AuthService/Controllers/AuthController.cs); [Cinema_Mobile/lib/features/auth/screens/register_screen.dart](../Cinema_Mobile/lib/features/auth/screens/register_screen.dart); [Cinema_Mobile/lib/features/auth/screens/verify_email_screen.dart](../Cinema_Mobile/lib/features/auth/screens/verify_email_screen.dart); [Cinema_BE/AuthService/AuthService/Service/AuthService.cs](../Cinema_BE/AuthService/AuthService/Service/AuthService.cs); [Cinema_BE/ApiGateway/ApiGateway/Program.cs](../Cinema_BE/ApiGateway/ApiGateway/Program.cs) |
| Quy tắc nghiệp vụ | MOB-BR-01, MOB-BR-02, MOB-BR-03, MOB-BR-24, MOB-BR-25 |
| Ca sử dụng / màn / API | UC-MOB-01; MOB-SCR-REGISTER, MOB-SCR-VERIFY; MOB-API-011 |

### MOB-FR-AUTH-09 — Khôi phục mật khẩu

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
| Tiêu chí nghiệm thu | **MOB-FR-AUTH-09-AC-01** — Với tiền điều kiện/kích hoạt, kiểm tra: Quên mật khẩu: gửi OTP qua email (luôn trả 200); đặt mật khẩu mới bằng OTP thì mọi refresh token cũ bị thu hồi và email được coi là đã xác thực. **MOB-FR-AUTH-09-AC-02** — Thử đầu vào sai/thiếu quyền/xung đột áp dụng và kiểm tra từ chối đã nêu, không đổi dữ liệu trái phép và không báo thành công sai. |
| Bằng chứng | [Cinema_BE/AuthService/AuthService/Controllers/AuthController.cs](../Cinema_BE/AuthService/AuthService/Controllers/AuthController.cs); [Cinema_Mobile/lib/features/auth/screens/forgot_password_screen.dart](../Cinema_Mobile/lib/features/auth/screens/forgot_password_screen.dart); [Cinema_Mobile/lib/features/auth/screens/reset_password_screen.dart](../Cinema_Mobile/lib/features/auth/screens/reset_password_screen.dart); [Cinema_BE/AuthService/AuthService/Service/AuthService.cs](../Cinema_BE/AuthService/AuthService/Service/AuthService.cs); [Cinema_BE/ApiGateway/ApiGateway/Program.cs](../Cinema_BE/ApiGateway/ApiGateway/Program.cs) |
| Quy tắc nghiệp vụ | MOB-BR-01, MOB-BR-02, MOB-BR-03, MOB-BR-24, MOB-BR-25 |
| Ca sử dụng / màn / API | UC-MOB-01; MOB-SCR-FORGOT, MOB-SCR-RESET; MOB-API-005, MOB-API-013 |

### MOB-FR-AUTH-10 — Làm mới và đăng xuất

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
| Tiêu chí nghiệm thu | **MOB-FR-AUTH-10-AC-01** — Với tiền điều kiện/kích hoạt, kiểm tra: Làm mới phiên bằng refresh token (xoay vòng, token cũ hết hiệu lực); đăng xuất thu hồi refresh token. App tự làm mới khi access token hết hạn. **MOB-FR-AUTH-10-AC-02** — Thử đầu vào sai/thiếu quyền/xung đột áp dụng và kiểm tra từ chối đã nêu, không đổi dữ liệu trái phép và không báo thành công sai. |
| Bằng chứng | [Cinema_BE/AuthService/AuthService/Controllers/AuthController.cs](../Cinema_BE/AuthService/AuthService/Controllers/AuthController.cs); [Cinema_Mobile/lib/features/profile/screens/profile_screen.dart](../Cinema_Mobile/lib/features/profile/screens/profile_screen.dart); [Cinema_Mobile/lib/features/profile/screens/management_account_screen.dart](../Cinema_Mobile/lib/features/profile/screens/management_account_screen.dart); [Cinema_BE/AuthService/AuthService/Service/AuthService.cs](../Cinema_BE/AuthService/AuthService/Service/AuthService.cs); [Cinema_BE/ApiGateway/ApiGateway/Program.cs](../Cinema_BE/ApiGateway/ApiGateway/Program.cs) |
| Quy tắc nghiệp vụ | MOB-BR-01, MOB-BR-02, MOB-BR-03, MOB-BR-24, MOB-BR-25 |
| Ca sử dụng / màn / API | UC-MOB-01; MOB-SCR-PROFILE, MOB-SCR-MGT-LANDING; MOB-API-007, MOB-API-010 |

### MOB-FR-AUTH-11 — Tài khoản hiện tại

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
| Tiêu chí nghiệm thu | **MOB-FR-AUTH-11-AC-01** — Với tiền điều kiện/kích hoạt, kiểm tra: Xem hồ sơ tài khoản hiện tại (`GET /api/v1/auth/me`). **MOB-FR-AUTH-11-AC-02** — Thử đầu vào sai/thiếu quyền/xung đột áp dụng và kiểm tra từ chối đã nêu, không đổi dữ liệu trái phép và không báo thành công sai. |
| Bằng chứng | [Cinema_BE/AuthService/AuthService/Controllers/AuthController.cs](../Cinema_BE/AuthService/AuthService/Controllers/AuthController.cs); [Cinema_Mobile/lib/features/profile/screens/profile_screen.dart](../Cinema_Mobile/lib/features/profile/screens/profile_screen.dart); [Cinema_BE/AuthService/AuthService/Service/AuthService.cs](../Cinema_BE/AuthService/AuthService/Service/AuthService.cs); [Cinema_BE/ApiGateway/ApiGateway/Program.cs](../Cinema_BE/ApiGateway/ApiGateway/Program.cs) |
| Quy tắc nghiệp vụ | MOB-BR-01, MOB-BR-02, MOB-BR-03, MOB-BR-24, MOB-BR-25 |
| Ca sử dụng / màn / API | UC-MOB-01; MOB-SCR-PROFILE; MOB-API-008 |

### MOB-FR-AUTH-12 — Áp dụng khoá và đổi quyền

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
| Tiêu chí nghiệm thu | **MOB-FR-AUTH-12-AC-01** — Với tiền điều kiện/kích hoạt, kiểm tra: Gateway kiểm tra trạng thái tài khoản ở mỗi request cần đăng nhập: bị khoá trả 401 `ACCOUNT_LOCKED`; vai trò đã đổi trả 403 `ROLE_CHANGED`; AuthService không phản hồi trả 503. App khách hiện lý do và đưa về màn đăng nhập. **MOB-FR-AUTH-12-AC-02** — Thử đầu vào sai/thiếu quyền/xung đột áp dụng và kiểm tra từ chối đã nêu, không đổi dữ liệu trái phép và không báo thành công sai. |
| Bằng chứng | [Cinema_BE/AuthService/AuthService/Controllers/AuthController.cs](../Cinema_BE/AuthService/AuthService/Controllers/AuthController.cs); [Cinema_Mobile/lib/features/auth/screens/login_screen.dart](../Cinema_Mobile/lib/features/auth/screens/login_screen.dart); [Cinema_BE/AuthService/AuthService/Service/AuthService.cs](../Cinema_BE/AuthService/AuthService/Service/AuthService.cs); [Cinema_BE/ApiGateway/ApiGateway/Program.cs](../Cinema_BE/ApiGateway/ApiGateway/Program.cs) |
| Quy tắc nghiệp vụ | MOB-BR-01, MOB-BR-02, MOB-BR-03, MOB-BR-24, MOB-BR-25 |
| Ca sử dụng / màn / API | UC-MOB-01; MOB-SCR-LOGIN; MOB-API-008 |

### MOB-FR-AUTH-13 — Kiểm tra trường tài khoản

| Trường | Đặc tả |
| --- | --- |
| Tên | Kiểm tra trường tài khoản |
| Mô tả | Ứng dụng kiểm tra email (bắt buộc, tối đa 150, không khoảng trắng, hậu tố tên miền ít nhất hai chữ cái), mật khẩu mới (6–72 byte UTF-8), tên (bắt buộc, tối đa 150) và điện thoại tuỳ chọn (8–15 chữ số, tối đa 20 ký tự). Biểu mẫu đăng ký/mật khẩu mới xác nhận lại mật khẩu; lỗi trường từ server trả 400 và được hiển thị. |
| Tác nhân | Khách chưa đăng nhập; người có tài khoản; hệ thống |
| Tiền điều kiện | Truy cập được biểu mẫu và đã cấu hình gateway/AuthService; đăng ký/đăng nhập/OTP/khôi phục không cần phiên đã đăng nhập. Gửi mã cần SMTP. |
| Kích hoạt | Thực hiện “Kiểm tra trường tài khoản” hoặc sự kiện/tác vụ backend tương ứng. |
| Luồng chính | 1. Đọc đầu vào/tài nguyên hiện tại và phiên áp dụng. 2. Thực hiện thao tác này: Ứng dụng kiểm tra email (bắt buộc, tối đa 150, không khoảng trắng, hậu tố tên miền ít nhất hai chữ cái), mật khẩu mới (6–72 byte UTF-8), tên (bắt buộc, tối đa 150) và điện thoại tuỳ chọn (8–15 chữ số, tối đa 20 ký tự). Biểu mẫu đăng ký/mật khẩu mới xác nhận lại mật khẩu; lỗi trường từ server trả 400 và được hiển thị. 3. Trả/hiển thị kết quả chính thức và làm mới dữ liệu bị tác động sau thành công. |
| Luồng thay thế / ngoại lệ | Từ chối trường sai (400), thông tin đăng nhập sai (401), email chưa xác thực (403), OTP cũ/sai hoặc vượt giới hạn gửi/tần suất (429). Xoá phiên khi tài khoản bị khoá/quyền thay đổi; hiển thị lỗi SMTP/phụ thuộc (503). |
| Hậu điều kiện | Kết quả thành công quan sát được khớp yêu cầu này; chuyển trạng thái được chỉ định được lưu. Từ chối không cấp quyền hoặc để thay đổi dở dang trái phép. |
| Ưu tiên | H |
| Tiêu chí nghiệm thu | **MOB-FR-AUTH-13-AC-01** — Với tiền điều kiện/kích hoạt, kiểm tra: Ứng dụng kiểm tra email (bắt buộc, tối đa 150, không khoảng trắng, hậu tố tên miền ít nhất hai chữ cái), mật khẩu mới (6–72 byte UTF-8), tên (bắt buộc, tối đa 150) và điện thoại tuỳ chọn (8–15 chữ số, tối đa 20 ký tự). Biểu mẫu đăng ký/mật khẩu mới xác nhận lại mật khẩu; lỗi trường từ server trả 400 và được hiển thị. **MOB-FR-AUTH-13-AC-02** — Thử đầu vào sai/thiếu quyền/xung đột áp dụng và kiểm tra từ chối đã nêu, không đổi dữ liệu trái phép và không báo thành công sai. |
| Bằng chứng | [Cinema_BE/AuthService/AuthService/Controllers/AuthController.cs](../Cinema_BE/AuthService/AuthService/Controllers/AuthController.cs); [Cinema_Mobile/lib/features/auth/screens/login_screen.dart](../Cinema_Mobile/lib/features/auth/screens/login_screen.dart); [Cinema_Mobile/lib/features/auth/screens/register_screen.dart](../Cinema_Mobile/lib/features/auth/screens/register_screen.dart); [Cinema_Mobile/lib/features/auth/screens/forgot_password_screen.dart](../Cinema_Mobile/lib/features/auth/screens/forgot_password_screen.dart); [Cinema_Mobile/lib/features/auth/screens/reset_password_screen.dart](../Cinema_Mobile/lib/features/auth/screens/reset_password_screen.dart); [Cinema_BE/AuthService/AuthService/Service/AuthService.cs](../Cinema_BE/AuthService/AuthService/Service/AuthService.cs); [Cinema_BE/ApiGateway/ApiGateway/Program.cs](../Cinema_BE/ApiGateway/ApiGateway/Program.cs) |
| Quy tắc nghiệp vụ | MOB-BR-01, MOB-BR-02, MOB-BR-03, MOB-BR-24, MOB-BR-25 |
| Ca sử dụng / màn / API | UC-MOB-01; MOB-SCR-LOGIN, MOB-SCR-REGISTER, MOB-SCR-FORGOT, MOB-SCR-RESET; MOB-API-006, MOB-API-011, MOB-API-013 |

### MOB-FR-AUTH-14 — Giới hạn tần suất xác thực

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
| Tiêu chí nghiệm thu | **MOB-FR-AUTH-14-AC-01** — Với tiền điều kiện/kích hoạt, kiểm tra: Giới hạn 10 request / phút / IP cho các API đăng ký, đăng nhập, OTP, làm mới, quên / đặt lại mật khẩu; vượt thì 429 kèm `Retry-After`. **MOB-FR-AUTH-14-AC-02** — Thử đầu vào sai/thiếu quyền/xung đột áp dụng và kiểm tra từ chối đã nêu, không đổi dữ liệu trái phép và không báo thành công sai. |
| Bằng chứng | [Cinema_BE/AuthService/AuthService/Controllers/AuthController.cs](../Cinema_BE/AuthService/AuthService/Controllers/AuthController.cs); [Cinema_Mobile/lib/features/auth/screens/verify_email_screen.dart](../Cinema_Mobile/lib/features/auth/screens/verify_email_screen.dart); [Cinema_Mobile/lib/features/auth/screens/forgot_password_screen.dart](../Cinema_Mobile/lib/features/auth/screens/forgot_password_screen.dart); [Cinema_Mobile/lib/features/auth/screens/reset_password_screen.dart](../Cinema_Mobile/lib/features/auth/screens/reset_password_screen.dart); [Cinema_BE/AuthService/AuthService/Service/AuthService.cs](../Cinema_BE/AuthService/AuthService/Service/AuthService.cs); [Cinema_BE/ApiGateway/ApiGateway/Program.cs](../Cinema_BE/ApiGateway/ApiGateway/Program.cs) |
| Quy tắc nghiệp vụ | MOB-BR-01, MOB-BR-02, MOB-BR-03, MOB-BR-24, MOB-BR-25 |
| Ca sử dụng / màn / API | UC-MOB-01; MOB-SCR-VERIFY, MOB-SCR-FORGOT, MOB-SCR-RESET; MOB-API-006, MOB-API-010, MOB-API-012 |

### MOB-FR-AUTH-16 — Sửa hồ sơ

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
| Tiêu chí nghiệm thu | **MOB-FR-AUTH-16-AC-01** — Với tiền điều kiện/kích hoạt, kiểm tra: Người dùng tự **sửa hồ sơ** (Account → Edit profile): họ tên (bắt buộc, tối đa 150 ký tự) và số điện thoại (không bắt buộc, cùng quy tắc với đăng ký; bỏ trống là xoá). Email là tên đăng nhập nên không đổi. **MOB-FR-AUTH-16-AC-02** — Thử đầu vào sai/thiếu quyền/xung đột áp dụng và kiểm tra từ chối đã nêu, không đổi dữ liệu trái phép và không báo thành công sai. |
| Bằng chứng | [Cinema_BE/AuthService/AuthService/Controllers/AuthController.cs](../Cinema_BE/AuthService/AuthService/Controllers/AuthController.cs); [Cinema_Mobile/lib/features/profile/screens/profile_screen.dart](../Cinema_Mobile/lib/features/profile/screens/profile_screen.dart); [Cinema_BE/AuthService/AuthService/Service/AuthService.cs](../Cinema_BE/AuthService/AuthService/Service/AuthService.cs); [Cinema_BE/ApiGateway/ApiGateway/Program.cs](../Cinema_BE/ApiGateway/ApiGateway/Program.cs) |
| Quy tắc nghiệp vụ | MOB-BR-01, MOB-BR-02, MOB-BR-03, MOB-BR-24, MOB-BR-25 |
| Ca sử dụng / màn / API | UC-MOB-01; MOB-SCR-PROFILE; MOB-API-009 |

### MOB-FR-AUTH-17 — Đổi mật khẩu hiện tại

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
| Tiêu chí nghiệm thu | **MOB-FR-AUTH-17-AC-01** — Với tiền điều kiện/kích hoạt, kiểm tra: **Đổi mật khẩu bằng mật khẩu hiện tại** (Account → Change password): nhập mật khẩu hiện tại, mật khẩu mới hai lần. Sai mật khẩu hiện tại hoặc trùng mật khẩu cũ bị 400. Đổi xong các thiết bị khác bị đăng xuất (thu hồi refresh token), thiết bị đang dùng nhận token mới. Quên mật khẩu hiện tại thì chuyển sang luồng OTP email. Giới hạn 10 lần / phút như đăng nhập. **MOB-FR-AUTH-17-AC-02** — Thử đầu vào sai/thiếu quyền/xung đột áp dụng và kiểm tra từ chối đã nêu, không đổi dữ liệu trái phép và không báo thành công sai. |
| Bằng chứng | [Cinema_BE/AuthService/AuthService/Controllers/AuthController.cs](../Cinema_BE/AuthService/AuthService/Controllers/AuthController.cs); [Cinema_Mobile/lib/features/profile/screens/profile_screen.dart](../Cinema_Mobile/lib/features/profile/screens/profile_screen.dart); [Cinema_BE/AuthService/AuthService/Service/AuthService.cs](../Cinema_BE/AuthService/AuthService/Service/AuthService.cs); [Cinema_BE/ApiGateway/ApiGateway/Program.cs](../Cinema_BE/ApiGateway/ApiGateway/Program.cs) |
| Quy tắc nghiệp vụ | MOB-BR-01, MOB-BR-02, MOB-BR-03, MOB-BR-24, MOB-BR-25 |
| Ca sử dụng / màn / API | UC-MOB-01; MOB-SCR-PROFILE; MOB-API-004 |

### MOB-FR-MOV-02 — Chi tiết phim

| Trường | Đặc tả |
| --- | --- |
| Tên | Chi tiết phim |
| Mô tả | Chi tiết phim: tên, mô tả, thời lượng, thể loại, ngôn ngữ, ngày phát hành, poster, trailer, trạng thái. |
| Tác nhân | Khách chưa đăng nhập/khách hàng |
| Tiền điều kiện | Truy cập được danh mục công khai; phim tồn tại với thao tác chi tiết/trailer. Kết quả tìm rỗng là hợp lệ. |
| Kích hoạt | Thực hiện “Chi tiết phim” hoặc sự kiện/tác vụ backend tương ứng. |
| Luồng chính | 1. Đọc đầu vào/tài nguyên hiện tại và phiên áp dụng. 2. Thực hiện thao tác này: Chi tiết phim: tên, mô tả, thời lượng, thể loại, ngôn ngữ, ngày phát hành, poster, trailer, trạng thái. 3. Trả/hiển thị kết quả chính thức và làm mới dữ liệu bị tác động sau thành công. |
| Luồng thay thế / ngoại lệ | Hiện trạng thái rỗng khi không có phim/suất phù hợp. Đánh giá bằng vé người khác trả 404; vé chưa check-in trả 400. Media lỗi phải còn ảnh hoặc nội dung dự phòng. |
| Hậu điều kiện | Dữ liệu/trạng thái đủ quyền được trả/hiển thị; đọc không đổi trạng thái vé/thanh toán. Dấu đã đọc thông báo chỉ đổi bằng thao tác ghi riêng. |
| Ưu tiên | H |
| Tiêu chí nghiệm thu | **MOB-FR-MOV-02-AC-01** — Với tiền điều kiện/kích hoạt, kiểm tra: Chi tiết phim: tên, mô tả, thời lượng, thể loại, ngôn ngữ, ngày phát hành, poster, trailer, trạng thái. **MOB-FR-MOV-02-AC-02** — Thử đầu vào sai/thiếu quyền/xung đột áp dụng và kiểm tra từ chối đã nêu, không đổi dữ liệu trái phép và không báo thành công sai. |
| Bằng chứng | [Cinema_BE/MovieService/MovieService/Controllers/MoviesController.cs](../Cinema_BE/MovieService/MovieService/Controllers/MoviesController.cs); [Cinema_Mobile/lib/features/movie/screens/movie_detail_screen.dart](../Cinema_Mobile/lib/features/movie/screens/movie_detail_screen.dart); [Cinema_BE/MovieService/MovieService/Service/Impl/MovieService.cs](../Cinema_BE/MovieService/MovieService/Service/Impl/MovieService.cs); [Cinema_BE/BookingService/BookingService/Services/Implementations/MovieReviewService.cs](../Cinema_BE/BookingService/BookingService/Services/Implementations/MovieReviewService.cs) |
| Quy tắc nghiệp vụ | MOB-BR-26 |
| Ca sử dụng / màn / API | UC-MOB-02; MOB-SCR-MOVIE; MOB-API-024 |

### MOB-FR-MOV-03 — Tìm theo tên

| Trường | Đặc tả |
| --- | --- |
| Tên | Tìm theo tên |
| Mô tả | Tìm phim theo tên. |
| Tác nhân | Khách chưa đăng nhập/khách hàng |
| Tiền điều kiện | Truy cập được danh mục công khai; phim tồn tại với thao tác chi tiết/trailer. Kết quả tìm rỗng là hợp lệ. |
| Kích hoạt | Thực hiện “Tìm theo tên” hoặc sự kiện/tác vụ backend tương ứng. |
| Luồng chính | 1. Đọc đầu vào/tài nguyên hiện tại và phiên áp dụng. 2. Thực hiện thao tác này: Tìm phim theo tên. 3. Trả/hiển thị kết quả chính thức và làm mới dữ liệu bị tác động sau thành công. |
| Luồng thay thế / ngoại lệ | Hiện trạng thái rỗng khi không có phim/suất phù hợp. Đánh giá bằng vé người khác trả 404; vé chưa check-in trả 400. Media lỗi phải còn ảnh hoặc nội dung dự phòng. |
| Hậu điều kiện | Dữ liệu/trạng thái đủ quyền được trả/hiển thị; đọc không đổi trạng thái vé/thanh toán. Dấu đã đọc thông báo chỉ đổi bằng thao tác ghi riêng. |
| Ưu tiên | M |
| Tiêu chí nghiệm thu | **MOB-FR-MOV-03-AC-01** — Với tiền điều kiện/kích hoạt, kiểm tra: Tìm phim theo tên. **MOB-FR-MOV-03-AC-02** — Thử đầu vào sai/thiếu quyền/xung đột áp dụng và kiểm tra từ chối đã nêu, không đổi dữ liệu trái phép và không báo thành công sai. |
| Bằng chứng | [Cinema_BE/MovieService/MovieService/Controllers/MoviesController.cs](../Cinema_BE/MovieService/MovieService/Controllers/MoviesController.cs); [Cinema_Mobile/lib/features/home/screens/home_screen.dart](../Cinema_Mobile/lib/features/home/screens/home_screen.dart); [Cinema_BE/MovieService/MovieService/Service/Impl/MovieService.cs](../Cinema_BE/MovieService/MovieService/Service/Impl/MovieService.cs); [Cinema_BE/BookingService/BookingService/Services/Implementations/MovieReviewService.cs](../Cinema_BE/BookingService/BookingService/Services/Implementations/MovieReviewService.cs) |
| Quy tắc nghiệp vụ | MOB-BR-26 |
| Ca sử dụng / màn / API | UC-MOB-02; MOB-SCR-HOME; MOB-API-025 |

### MOB-FR-MOV-04 — Danh mục đang hoạt động

| Trường | Đặc tả |
| --- | --- |
| Tên | Danh mục đang hoạt động |
| Mô tả | Danh mục khách chỉ hiện phim ACTIVE; phim INACTIVE không xuất hiện khi duyệt nhưng không xoá vé lịch sử. |
| Tác nhân | Khách chưa đăng nhập/khách hàng |
| Tiền điều kiện | Truy cập được danh mục công khai; phim tồn tại với thao tác chi tiết/trailer. Kết quả tìm rỗng là hợp lệ. |
| Kích hoạt | Thực hiện “Danh mục đang hoạt động” hoặc sự kiện/tác vụ backend tương ứng. |
| Luồng chính | 1. Đọc đầu vào/tài nguyên hiện tại và phiên áp dụng. 2. Thực hiện thao tác này: Danh mục khách chỉ hiện phim ACTIVE; phim INACTIVE không xuất hiện khi duyệt nhưng không xoá vé lịch sử. 3. Trả/hiển thị kết quả chính thức và làm mới dữ liệu bị tác động sau thành công. |
| Luồng thay thế / ngoại lệ | Hiện trạng thái rỗng khi không có phim/suất phù hợp. Đánh giá bằng vé người khác trả 404; vé chưa check-in trả 400. Media lỗi phải còn ảnh hoặc nội dung dự phòng. |
| Hậu điều kiện | Dữ liệu/trạng thái đủ quyền được trả/hiển thị; đọc không đổi trạng thái vé/thanh toán. Dấu đã đọc thông báo chỉ đổi bằng thao tác ghi riêng. |
| Ưu tiên | H |
| Tiêu chí nghiệm thu | **MOB-FR-MOV-04-AC-01** — Với tiền điều kiện/kích hoạt, kiểm tra: Danh mục khách chỉ hiện phim ACTIVE; phim INACTIVE không xuất hiện khi duyệt nhưng không xoá vé lịch sử. **MOB-FR-MOV-04-AC-02** — Thử đầu vào sai/thiếu quyền/xung đột áp dụng và kiểm tra từ chối đã nêu, không đổi dữ liệu trái phép và không báo thành công sai. |
| Bằng chứng | [Cinema_BE/MovieService/MovieService/Controllers/MoviesController.cs](../Cinema_BE/MovieService/MovieService/Controllers/MoviesController.cs); [Cinema_Mobile/lib/features/home/screens/home_screen.dart](../Cinema_Mobile/lib/features/home/screens/home_screen.dart); [Cinema_BE/MovieService/MovieService/Service/Impl/MovieService.cs](../Cinema_BE/MovieService/MovieService/Service/Impl/MovieService.cs); [Cinema_BE/BookingService/BookingService/Services/Implementations/MovieReviewService.cs](../Cinema_BE/BookingService/BookingService/Services/Implementations/MovieReviewService.cs) |
| Quy tắc nghiệp vụ | MOB-BR-26 |
| Ca sử dụng / màn / API | UC-MOB-02; MOB-SCR-HOME; MOB-API-025, MOB-API-027 |

### MOB-FR-MOV-08 — Mở trailer

| Trường | Đặc tả |
| --- | --- |
| Tên | Mở trailer |
| Mô tả | App khách mở trailer của phim (`trailerUrl`). |
| Tác nhân | Khách chưa đăng nhập/khách hàng |
| Tiền điều kiện | Truy cập được danh mục công khai; phim tồn tại với thao tác chi tiết/trailer. Kết quả tìm rỗng là hợp lệ. |
| Kích hoạt | Thực hiện “Mở trailer” hoặc sự kiện/tác vụ backend tương ứng. |
| Luồng chính | 1. Đọc đầu vào/tài nguyên hiện tại và phiên áp dụng. 2. Thực hiện thao tác này: App khách mở trailer của phim (`trailerUrl`). 3. Trả/hiển thị kết quả chính thức và làm mới dữ liệu bị tác động sau thành công. |
| Luồng thay thế / ngoại lệ | Hiện trạng thái rỗng khi không có phim/suất phù hợp. Đánh giá bằng vé người khác trả 404; vé chưa check-in trả 400. Media lỗi phải còn ảnh hoặc nội dung dự phòng. |
| Hậu điều kiện | Dữ liệu/trạng thái đủ quyền được trả/hiển thị; đọc không đổi trạng thái vé/thanh toán. Dấu đã đọc thông báo chỉ đổi bằng thao tác ghi riêng. |
| Ưu tiên | L |
| Tiêu chí nghiệm thu | **MOB-FR-MOV-08-AC-01** — Với tiền điều kiện/kích hoạt, kiểm tra: App khách mở trailer của phim (`trailerUrl`). **MOB-FR-MOV-08-AC-02** — Thử đầu vào sai/thiếu quyền/xung đột áp dụng và kiểm tra từ chối đã nêu, không đổi dữ liệu trái phép và không báo thành công sai. |
| Bằng chứng | [Cinema_BE/MovieService/MovieService/Controllers/MoviesController.cs](../Cinema_BE/MovieService/MovieService/Controllers/MoviesController.cs); [Cinema_Mobile/lib/features/movie/screens/movie_detail_screen.dart](../Cinema_Mobile/lib/features/movie/screens/movie_detail_screen.dart); [Cinema_BE/MovieService/MovieService/Service/Impl/MovieService.cs](../Cinema_BE/MovieService/MovieService/Service/Impl/MovieService.cs); [Cinema_BE/BookingService/BookingService/Services/Implementations/MovieReviewService.cs](../Cinema_BE/BookingService/BookingService/Services/Implementations/MovieReviewService.cs) |
| Quy tắc nghiệp vụ | MOB-BR-26 |
| Ca sử dụng / màn / API | UC-MOB-02; MOB-SCR-MOVIE; MOB-API-024 |

### MOB-FR-MOV-09 — Phân loại tuổi

| Trường | Đặc tả |
| --- | --- |
| Tên | Phân loại tuổi |
| Mô tả | Hiện P/K/T13/T16/T18 trên thẻ, chi tiết phim và xác nhận đặt vé. Với phim khác P, yêu cầu xác nhận điều kiện tuổi trước khi giữ ghế; check-in điện thoại nhắc nhân viên/quản trị viên kiểm tra danh tính khi có dữ liệu phân loại. |
| Tác nhân | Khách chưa đăng nhập/khách hàng |
| Tiền điều kiện | Có dữ liệu phim; cập nhật cần quản trị viên; đánh giá cần vé của chính khách đã được check-in. |
| Kích hoạt | Thực hiện “Phân loại tuổi” hoặc sự kiện/tác vụ backend tương ứng. |
| Luồng chính | 1. Đọc đầu vào/tài nguyên hiện tại và phiên áp dụng. 2. Thực hiện thao tác này: Hiện P/K/T13/T16/T18 trên thẻ, chi tiết phim và xác nhận đặt vé. Với phim khác P, yêu cầu xác nhận điều kiện tuổi trước khi giữ ghế; check-in điện thoại nhắc nhân viên/quản trị viên kiểm tra danh tính khi có dữ liệu phân loại. 3. Trả/hiển thị kết quả chính thức và làm mới dữ liệu bị tác động sau thành công. |
| Luồng thay thế / ngoại lệ | Hiện trạng thái rỗng khi không có phim/suất phù hợp. Đánh giá bằng vé người khác trả 404; vé chưa check-in trả 400. Media lỗi phải còn ảnh hoặc nội dung dự phòng. |
| Hậu điều kiện | Dữ liệu/trạng thái đủ quyền được trả/hiển thị; đọc không đổi trạng thái vé/thanh toán. Dấu đã đọc thông báo chỉ đổi bằng thao tác ghi riêng. |
| Ưu tiên | H |
| Tiêu chí nghiệm thu | **MOB-FR-MOV-09-AC-01** — Với tiền điều kiện/kích hoạt, kiểm tra: Hiện P/K/T13/T16/T18 trên thẻ, chi tiết phim và xác nhận đặt vé. Với phim khác P, yêu cầu xác nhận điều kiện tuổi trước khi giữ ghế; check-in điện thoại nhắc nhân viên/quản trị viên kiểm tra danh tính khi có dữ liệu phân loại. **MOB-FR-MOV-09-AC-02** — Thử đầu vào sai/thiếu quyền/xung đột áp dụng và kiểm tra từ chối đã nêu, không đổi dữ liệu trái phép và không báo thành công sai. |
| Bằng chứng | [Cinema_BE/MovieService/MovieService/Controllers/MoviesController.cs](../Cinema_BE/MovieService/MovieService/Controllers/MoviesController.cs); [Cinema_Mobile/lib/features/movie/screens/movie_detail_screen.dart](../Cinema_Mobile/lib/features/movie/screens/movie_detail_screen.dart); [Cinema_Mobile/lib/features/booking/screens/booking_summary_screen.dart](../Cinema_Mobile/lib/features/booking/screens/booking_summary_screen.dart); [Cinema_Mobile/lib/features/staff/screens/staff_check_in_screen.dart](../Cinema_Mobile/lib/features/staff/screens/staff_check_in_screen.dart); [Cinema_BE/MovieService/MovieService/Service/Impl/MovieService.cs](../Cinema_BE/MovieService/MovieService/Service/Impl/MovieService.cs); [Cinema_BE/BookingService/BookingService/Services/Implementations/MovieReviewService.cs](../Cinema_BE/BookingService/BookingService/Services/Implementations/MovieReviewService.cs) |
| Quy tắc nghiệp vụ | MOB-BR-26 |
| Ca sử dụng / màn / API | UC-MOB-02; MOB-SCR-MOVIE, MOB-SCR-SUMMARY, MOB-SCR-CHECKIN; MOB-API-024 |

### MOB-FR-MOV-10 — Đang chiếu và sắp chiếu

| Trường | Đặc tả |
| --- | --- |
| Tên | Đang chiếu và sắp chiếu |
| Mô tả | Trang chủ của khách có hai tab **Đang chiếu** (phim ACTIVE đã khởi chiếu hoặc chưa có ngày khởi chiếu, mới thêm trước) và **Sắp chiếu** (phim ACTIVE có ngày khởi chiếu sau hôm nay, khởi chiếu sớm nhất trước, poster ghi ngày khởi chiếu). Lọc theo thể loại (chip lấy từ thể loại của các phim đang có) và tìm theo tên qua API, không phân biệt hoa thường. Chi tiết phim sắp chiếu ghi ngày khởi chiếu; chưa có suất thì báo suất chiếu sẽ được thêm gần ngày khởi chiếu. |
| Tác nhân | Khách chưa đăng nhập/khách hàng |
| Tiền điều kiện | Truy cập được danh mục công khai; phim tồn tại với thao tác chi tiết/trailer. Kết quả tìm rỗng là hợp lệ. |
| Kích hoạt | Thực hiện “Đang chiếu và sắp chiếu” hoặc sự kiện/tác vụ backend tương ứng. |
| Luồng chính | 1. Đọc đầu vào/tài nguyên hiện tại và phiên áp dụng. 2. Thực hiện thao tác này: Trang chủ của khách có hai tab **Đang chiếu** (phim ACTIVE đã khởi chiếu hoặc chưa có ngày khởi chiếu, mới thêm trước) và **Sắp chiếu** (phim ACTIVE có ngày khởi chiếu sau hôm nay, khởi chiếu sớm nhất trước, poster ghi ngày khởi chiếu). Lọc theo thể loại (chip lấy từ thể loại của các phim đang có) và tìm theo tên qua API, không phân biệt hoa thường. Chi tiết phim sắp chiếu ghi ngày khởi chiếu; chưa có suất thì báo suất chiếu sẽ được thêm gần ngày khởi chiếu. 3. Trả/hiển thị kết quả chính thức và làm mới dữ liệu bị tác động sau thành công. |
| Luồng thay thế / ngoại lệ | Hiện trạng thái rỗng khi không có phim/suất phù hợp. Đánh giá bằng vé người khác trả 404; vé chưa check-in trả 400. Media lỗi phải còn ảnh hoặc nội dung dự phòng. |
| Hậu điều kiện | Dữ liệu/trạng thái đủ quyền được trả/hiển thị; đọc không đổi trạng thái vé/thanh toán. Dấu đã đọc thông báo chỉ đổi bằng thao tác ghi riêng. |
| Ưu tiên | M |
| Tiêu chí nghiệm thu | **MOB-FR-MOV-10-AC-01** — Với tiền điều kiện/kích hoạt, kiểm tra: Trang chủ của khách có hai tab **Đang chiếu** (phim ACTIVE đã khởi chiếu hoặc chưa có ngày khởi chiếu, mới thêm trước) và **Sắp chiếu** (phim ACTIVE có ngày khởi chiếu sau hôm nay, khởi chiếu sớm nhất trước, poster ghi ngày khởi chiếu). Lọc theo thể loại (chip lấy từ thể loại của các phim đang có) và tìm theo tên qua API, không phân biệt hoa thường. Chi tiết phim sắp chiếu ghi ngày khởi chiếu; chưa có suất thì báo suất chiếu sẽ được thêm gần ngày khởi chiếu. **MOB-FR-MOV-10-AC-02** — Thử đầu vào sai/thiếu quyền/xung đột áp dụng và kiểm tra từ chối đã nêu, không đổi dữ liệu trái phép và không báo thành công sai. |
| Bằng chứng | [Cinema_BE/MovieService/MovieService/Controllers/MoviesController.cs](../Cinema_BE/MovieService/MovieService/Controllers/MoviesController.cs); [Cinema_Mobile/lib/features/home/screens/home_screen.dart](../Cinema_Mobile/lib/features/home/screens/home_screen.dart); [Cinema_BE/MovieService/MovieService/Service/Impl/MovieService.cs](../Cinema_BE/MovieService/MovieService/Service/Impl/MovieService.cs); [Cinema_BE/BookingService/BookingService/Services/Implementations/MovieReviewService.cs](../Cinema_BE/BookingService/BookingService/Services/Implementations/MovieReviewService.cs) |
| Quy tắc nghiệp vụ | MOB-BR-26 |
| Ca sử dụng / màn / API | UC-MOB-02; MOB-SCR-HOME; MOB-API-025, MOB-API-026 |

### MOB-FR-MOV-11 — Đạo diễn và diễn viên

| Trường | Đặc tả |
| --- | --- |
| Tên | Đạo diễn và diễn viên |
| Mô tả | Hiển thị đạo diễn tuỳ chọn (tối đa 150 ký tự) và diễn viên chính (tối đa 500) từ dữ liệu phim. Ứng dụng điện thoại không chỉnh sửa các trường này. |
| Tác nhân | Khách chưa đăng nhập/khách hàng |
| Tiền điều kiện | Truy cập được danh mục công khai; phim tồn tại với thao tác chi tiết/trailer. Kết quả tìm rỗng là hợp lệ. |
| Kích hoạt | Thực hiện “Đạo diễn và diễn viên” hoặc sự kiện/tác vụ backend tương ứng. |
| Luồng chính | 1. Đọc đầu vào/tài nguyên hiện tại và phiên áp dụng. 2. Thực hiện thao tác này: Hiển thị đạo diễn tuỳ chọn (tối đa 150 ký tự) và diễn viên chính (tối đa 500) từ dữ liệu phim. Ứng dụng điện thoại không chỉnh sửa các trường này. 3. Trả/hiển thị kết quả chính thức và làm mới dữ liệu bị tác động sau thành công. |
| Luồng thay thế / ngoại lệ | Hiện trạng thái rỗng khi không có phim/suất phù hợp. Đánh giá bằng vé người khác trả 404; vé chưa check-in trả 400. Media lỗi phải còn ảnh hoặc nội dung dự phòng. |
| Hậu điều kiện | Dữ liệu/trạng thái đủ quyền được trả/hiển thị; đọc không đổi trạng thái vé/thanh toán. Dấu đã đọc thông báo chỉ đổi bằng thao tác ghi riêng. |
| Ưu tiên | L |
| Tiêu chí nghiệm thu | **MOB-FR-MOV-11-AC-01** — Với tiền điều kiện/kích hoạt, kiểm tra: Hiển thị đạo diễn tuỳ chọn (tối đa 150 ký tự) và diễn viên chính (tối đa 500) từ dữ liệu phim. Ứng dụng điện thoại không chỉnh sửa các trường này. **MOB-FR-MOV-11-AC-02** — Thử đầu vào sai/thiếu quyền/xung đột áp dụng và kiểm tra từ chối đã nêu, không đổi dữ liệu trái phép và không báo thành công sai. |
| Bằng chứng | [Cinema_BE/MovieService/MovieService/Controllers/MoviesController.cs](../Cinema_BE/MovieService/MovieService/Controllers/MoviesController.cs); [Cinema_Mobile/lib/features/movie/screens/movie_detail_screen.dart](../Cinema_Mobile/lib/features/movie/screens/movie_detail_screen.dart); [Cinema_BE/MovieService/MovieService/Service/Impl/MovieService.cs](../Cinema_BE/MovieService/MovieService/Service/Impl/MovieService.cs); [Cinema_BE/BookingService/BookingService/Services/Implementations/MovieReviewService.cs](../Cinema_BE/BookingService/BookingService/Services/Implementations/MovieReviewService.cs) |
| Quy tắc nghiệp vụ | MOB-BR-26 |
| Ca sử dụng / màn / API | UC-MOB-02; MOB-SCR-MOVIE; MOB-API-024 |

### MOB-FR-MOV-12 — Đánh giá phim

| Trường | Đặc tả |
| --- | --- |
| Tên | Đánh giá phim |
| Mô tả | Hiển thị điểm trung bình, phân bố sao và đánh giá mới nhất của phim. Khách tạo/sửa đánh giá 1–5 sao kèm tối đa 1.000 ký tự từ vé của mình đã check-in, một đánh giá mỗi khách mỗi phim, và xoá đánh giá của mình. Vé chưa check-in trả 400; vé người khác trả 404. Hiển thị họ tên hoặc email che bớt. |
| Tác nhân | Khách chưa đăng nhập/khách hàng |
| Tiền điều kiện | Có dữ liệu phim; cập nhật cần quản trị viên; đánh giá cần vé của chính khách đã được check-in. |
| Kích hoạt | Thực hiện “Đánh giá phim” hoặc sự kiện/tác vụ backend tương ứng. |
| Luồng chính | 1. Đọc đầu vào/tài nguyên hiện tại và phiên áp dụng. 2. Thực hiện thao tác này: Hiển thị điểm trung bình, phân bố sao và đánh giá mới nhất của phim. Khách tạo/sửa đánh giá 1–5 sao kèm tối đa 1.000 ký tự từ vé của mình đã check-in, một đánh giá mỗi khách mỗi phim, và xoá đánh giá của mình. Vé chưa check-in trả 400; vé người khác trả 404. Hiển thị họ tên hoặc email che bớt. 3. Trả/hiển thị kết quả chính thức và làm mới dữ liệu bị tác động sau thành công. |
| Luồng thay thế / ngoại lệ | Hiện trạng thái rỗng khi không có phim/suất phù hợp. Đánh giá bằng vé người khác trả 404; vé chưa check-in trả 400. Media lỗi phải còn ảnh hoặc nội dung dự phòng. |
| Hậu điều kiện | Kết quả thành công quan sát được khớp yêu cầu này; chuyển trạng thái được chỉ định được lưu. Từ chối không cấp quyền hoặc để thay đổi dở dang trái phép. |
| Ưu tiên | M |
| Tiêu chí nghiệm thu | **MOB-FR-MOV-12-AC-01** — Với tiền điều kiện/kích hoạt, kiểm tra: Hiển thị điểm trung bình, phân bố sao và đánh giá mới nhất của phim. Khách tạo/sửa đánh giá 1–5 sao kèm tối đa 1.000 ký tự từ vé của mình đã check-in, một đánh giá mỗi khách mỗi phim, và xoá đánh giá của mình. Vé chưa check-in trả 400; vé người khác trả 404. Hiển thị họ tên hoặc email che bớt. **MOB-FR-MOV-12-AC-02** — Thử đầu vào sai/thiếu quyền/xung đột áp dụng và kiểm tra từ chối đã nêu, không đổi dữ liệu trái phép và không báo thành công sai. |
| Bằng chứng | [Cinema_BE/BookingService/BookingService/Controllers/MovieReviewController.cs](../Cinema_BE/BookingService/BookingService/Controllers/MovieReviewController.cs); [Cinema_Mobile/lib/features/movie/screens/movie_detail_screen.dart](../Cinema_Mobile/lib/features/movie/screens/movie_detail_screen.dart); [Cinema_Mobile/lib/features/booking/screens/booking_detail_screen.dart](../Cinema_Mobile/lib/features/booking/screens/booking_detail_screen.dart); [Cinema_BE/MovieService/MovieService/Service/Impl/MovieService.cs](../Cinema_BE/MovieService/MovieService/Service/Impl/MovieService.cs); [Cinema_BE/BookingService/BookingService/Services/Implementations/MovieReviewService.cs](../Cinema_BE/BookingService/BookingService/Services/Implementations/MovieReviewService.cs) |
| Quy tắc nghiệp vụ | MOB-BR-26 |
| Ca sử dụng / màn / API | UC-MOB-02; MOB-SCR-MOVIE, MOB-SCR-TICKET; MOB-API-039, MOB-API-040, MOB-API-041, MOB-API-042 |

### MOB-FR-SEAT-03 — Xem sơ đồ phòng

| Trường | Đặc tả |
| --- | --- |
| Tên | Xem sơ đồ phòng |
| Mô tả | Lấy sơ đồ ghế của phòng (người dùng đã đăng nhập). |
| Tác nhân | Khách hàng |
| Tiền điều kiện | Khách đã đăng nhập và suất chưa bắt đầu/phòng đã chọn tồn tại. |
| Kích hoạt | Thực hiện “Xem sơ đồ phòng” hoặc sự kiện/tác vụ backend tương ứng. |
| Luồng chính | 1. Đọc đầu vào/tài nguyên hiện tại và phiên áp dụng. 2. Thực hiện thao tác này: Lấy sơ đồ ghế của phòng (người dùng đã đăng nhập). 3. Trả/hiển thị kết quả chính thức và làm mới dữ liệu bị tác động sau thành công. |
| Luồng thay thế / ngoại lệ | Bỏ chọn ghế vừa bị đơn khác giữ và thông báo cho khách. Từ chối nửa cặp sweetbox, ghế sai phòng và sửa sơ đồ không đủ điều kiện. |
| Hậu điều kiện | Dữ liệu/trạng thái đủ quyền được trả/hiển thị; đọc không đổi trạng thái vé/thanh toán. Dấu đã đọc thông báo chỉ đổi bằng thao tác ghi riêng. |
| Ưu tiên | H |
| Tiêu chí nghiệm thu | **MOB-FR-SEAT-03-AC-01** — Với tiền điều kiện/kích hoạt, kiểm tra: Lấy sơ đồ ghế của phòng (người dùng đã đăng nhập). **MOB-FR-SEAT-03-AC-02** — Thử đầu vào sai/thiếu quyền/xung đột áp dụng và kiểm tra từ chối đã nêu, không đổi dữ liệu trái phép và không báo thành công sai. |
| Bằng chứng | [Cinema_BE/MovieService/MovieService/Controllers/SeatsController.cs](../Cinema_BE/MovieService/MovieService/Controllers/SeatsController.cs); [Cinema_Mobile/lib/features/seat/screens/seat_selection_screen.dart](../Cinema_Mobile/lib/features/seat/screens/seat_selection_screen.dart); [Cinema_BE/MovieService/MovieService/Service/Impl/SeatService.cs](../Cinema_BE/MovieService/MovieService/Service/Impl/SeatService.cs); [Cinema_BE/MovieService/MovieService/Service/Impl/ShowtimeService.cs](../Cinema_BE/MovieService/MovieService/Service/Impl/ShowtimeService.cs) |
| Quy tắc nghiệp vụ | MOB-BR-04, MOB-BR-07, MOB-BR-15, MOB-BR-16, MOB-BR-26 |
| Ca sử dụng / màn / API | UC-MOB-03; MOB-SCR-SEATS; MOB-API-001 |

### MOB-FR-SHOW-03 — Suất và giá

| Trường | Đặc tả |
| --- | --- |
| Tên | Suất và giá |
| Mô tả | Chi tiết suất chiếu kèm `seatPrices`: giá một ghế theo từng loại. |
| Tác nhân | Khách chưa đăng nhập/khách hàng; nhân viên/quản trị viên chỉ xem chi tiết trong check-in |
| Tiền điều kiện | Phim và phòng tồn tại; thay đổi quản lý cần nhân viên/quản trị viên. |
| Kích hoạt | Thực hiện “Suất và giá” hoặc sự kiện/tác vụ backend tương ứng. |
| Luồng chính | 1. Đọc đầu vào/tài nguyên hiện tại và phiên áp dụng. 2. Thực hiện thao tác này: Chi tiết suất chiếu kèm `seatPrices`: giá một ghế theo từng loại. 3. Trả/hiển thị kết quả chính thức và làm mới dữ liệu bị tác động sau thành công. |
| Luồng thay thế / ngoại lệ | Từ chối trùng lịch bằng 409 và giờ/định dạng sai bằng 400; suất đã huỷ là trạng thái cuối. Khách không chọn suất đóng bán hoặc đã bắt đầu. |
| Hậu điều kiện | Dữ liệu/trạng thái đủ quyền được trả/hiển thị; đọc không đổi trạng thái vé/thanh toán. Dấu đã đọc thông báo chỉ đổi bằng thao tác ghi riêng. |
| Ưu tiên | H |
| Tiêu chí nghiệm thu | **MOB-FR-SHOW-03-AC-01** — Với tiền điều kiện/kích hoạt, kiểm tra: Chi tiết suất chiếu kèm `seatPrices`: giá một ghế theo từng loại. **MOB-FR-SHOW-03-AC-02** — Thử đầu vào sai/thiếu quyền/xung đột áp dụng và kiểm tra từ chối đã nêu, không đổi dữ liệu trái phép và không báo thành công sai. |
| Bằng chứng | [Cinema_BE/MovieService/MovieService/Controllers/ShowtimesController.cs](../Cinema_BE/MovieService/MovieService/Controllers/ShowtimesController.cs); [Cinema_Mobile/lib/features/movie/screens/movie_detail_screen.dart](../Cinema_Mobile/lib/features/movie/screens/movie_detail_screen.dart); [Cinema_Mobile/lib/features/seat/screens/seat_selection_screen.dart](../Cinema_Mobile/lib/features/seat/screens/seat_selection_screen.dart); [Cinema_BE/MovieService/MovieService/Service/Impl/ShowtimeService.cs](../Cinema_BE/MovieService/MovieService/Service/Impl/ShowtimeService.cs) |
| Quy tắc nghiệp vụ | MOB-BR-05, MOB-BR-06, MOB-BR-15, MOB-BR-19, MOB-BR-30 |
| Ca sử dụng / màn / API | UC-MOB-04; MOB-SCR-MOVIE, MOB-SCR-SEATS; MOB-API-002 |

### MOB-FR-SHOW-06 — Suất mở chưa bắt đầu

| Trường | Đặc tả |
| --- | --- |
| Tên | Suất mở chưa bắt đầu |
| Mô tả | Lấy các suất đang mở bán (`OPEN`, chưa bắt đầu). |
| Tác nhân | Khách chưa đăng nhập/khách hàng; nhân viên/quản trị viên chỉ xem chi tiết trong check-in |
| Tiền điều kiện | Phim và phòng tồn tại; thay đổi quản lý cần nhân viên/quản trị viên. |
| Kích hoạt | Thực hiện “Suất mở chưa bắt đầu” hoặc sự kiện/tác vụ backend tương ứng. |
| Luồng chính | 1. Đọc đầu vào/tài nguyên hiện tại và phiên áp dụng. 2. Thực hiện thao tác này: Lấy các suất đang mở bán (`OPEN`, chưa bắt đầu). 3. Trả/hiển thị kết quả chính thức và làm mới dữ liệu bị tác động sau thành công. |
| Luồng thay thế / ngoại lệ | Từ chối trùng lịch bằng 409 và giờ/định dạng sai bằng 400; suất đã huỷ là trạng thái cuối. Khách không chọn suất đóng bán hoặc đã bắt đầu. |
| Hậu điều kiện | Dữ liệu/trạng thái đủ quyền được trả/hiển thị; đọc không đổi trạng thái vé/thanh toán. Dấu đã đọc thông báo chỉ đổi bằng thao tác ghi riêng. |
| Ưu tiên | H |
| Tiêu chí nghiệm thu | **MOB-FR-SHOW-06-AC-01** — Với tiền điều kiện/kích hoạt, kiểm tra: Lấy các suất đang mở bán (`OPEN`, chưa bắt đầu). **MOB-FR-SHOW-06-AC-02** — Thử đầu vào sai/thiếu quyền/xung đột áp dụng và kiểm tra từ chối đã nêu, không đổi dữ liệu trái phép và không báo thành công sai. |
| Bằng chứng | [Cinema_BE/MovieService/MovieService/Controllers/ShowtimesController.cs](../Cinema_BE/MovieService/MovieService/Controllers/ShowtimesController.cs); [Cinema_Mobile/lib/features/movie/screens/movie_detail_screen.dart](../Cinema_Mobile/lib/features/movie/screens/movie_detail_screen.dart); [Cinema_BE/MovieService/MovieService/Service/Impl/ShowtimeService.cs](../Cinema_BE/MovieService/MovieService/Service/Impl/ShowtimeService.cs) |
| Quy tắc nghiệp vụ | MOB-BR-05, MOB-BR-06, MOB-BR-15, MOB-BR-19, MOB-BR-30 |
| Ca sử dụng / màn / API | UC-MOB-04; MOB-SCR-MOVIE; MOB-API-003 |

### MOB-FR-SHOW-07 — Suất theo phim

| Trường | Đặc tả |
| --- | --- |
| Tên | Suất theo phim |
| Mô tả | Lấy suất chiếu theo phim. |
| Tác nhân | Khách chưa đăng nhập/khách hàng; nhân viên/quản trị viên chỉ xem chi tiết trong check-in |
| Tiền điều kiện | Phim và phòng tồn tại; thay đổi quản lý cần nhân viên/quản trị viên. |
| Kích hoạt | Thực hiện “Suất theo phim” hoặc sự kiện/tác vụ backend tương ứng. |
| Luồng chính | 1. Đọc đầu vào/tài nguyên hiện tại và phiên áp dụng. 2. Thực hiện thao tác này: Lấy suất chiếu theo phim. 3. Trả/hiển thị kết quả chính thức và làm mới dữ liệu bị tác động sau thành công. |
| Luồng thay thế / ngoại lệ | Từ chối trùng lịch bằng 409 và giờ/định dạng sai bằng 400; suất đã huỷ là trạng thái cuối. Khách không chọn suất đóng bán hoặc đã bắt đầu. |
| Hậu điều kiện | Dữ liệu/trạng thái đủ quyền được trả/hiển thị; đọc không đổi trạng thái vé/thanh toán. Dấu đã đọc thông báo chỉ đổi bằng thao tác ghi riêng. |
| Ưu tiên | M |
| Tiêu chí nghiệm thu | **MOB-FR-SHOW-07-AC-01** — Với tiền điều kiện/kích hoạt, kiểm tra: Lấy suất chiếu theo phim. **MOB-FR-SHOW-07-AC-02** — Thử đầu vào sai/thiếu quyền/xung đột áp dụng và kiểm tra từ chối đã nêu, không đổi dữ liệu trái phép và không báo thành công sai. |
| Bằng chứng | [Cinema_BE/MovieService/MovieService/Controllers/ShowtimesController.cs](../Cinema_BE/MovieService/MovieService/Controllers/ShowtimesController.cs); [Cinema_Mobile/lib/features/movie/screens/movie_detail_screen.dart](../Cinema_Mobile/lib/features/movie/screens/movie_detail_screen.dart); [Cinema_BE/MovieService/MovieService/Service/Impl/ShowtimeService.cs](../Cinema_BE/MovieService/MovieService/Service/Impl/ShowtimeService.cs) |
| Quy tắc nghiệp vụ | MOB-BR-05, MOB-BR-06, MOB-BR-15, MOB-BR-19, MOB-BR-30 |
| Ca sử dụng / màn / API | UC-MOB-04; MOB-SCR-MOVIE; MOB-API-003 |

### MOB-FR-SHOW-08 — Suất phim còn đặt được

| Trường | Đặc tả |
| --- | --- |
| Tên | Suất phim còn đặt được |
| Mô tả | Lấy suất đang mở bán theo phim; app khách hiện các suất trong 7 ngày tới. |
| Tác nhân | Khách chưa đăng nhập/khách hàng; nhân viên/quản trị viên chỉ xem chi tiết trong check-in |
| Tiền điều kiện | Phim và phòng tồn tại; thay đổi quản lý cần nhân viên/quản trị viên. |
| Kích hoạt | Thực hiện “Suất phim còn đặt được” hoặc sự kiện/tác vụ backend tương ứng. |
| Luồng chính | 1. Đọc đầu vào/tài nguyên hiện tại và phiên áp dụng. 2. Thực hiện thao tác này: Lấy suất đang mở bán theo phim; app khách hiện các suất trong 7 ngày tới. 3. Trả/hiển thị kết quả chính thức và làm mới dữ liệu bị tác động sau thành công. |
| Luồng thay thế / ngoại lệ | Từ chối trùng lịch bằng 409 và giờ/định dạng sai bằng 400; suất đã huỷ là trạng thái cuối. Khách không chọn suất đóng bán hoặc đã bắt đầu. |
| Hậu điều kiện | Dữ liệu/trạng thái đủ quyền được trả/hiển thị; đọc không đổi trạng thái vé/thanh toán. Dấu đã đọc thông báo chỉ đổi bằng thao tác ghi riêng. |
| Ưu tiên | H |
| Tiêu chí nghiệm thu | **MOB-FR-SHOW-08-AC-01** — Với tiền điều kiện/kích hoạt, kiểm tra: Lấy suất đang mở bán theo phim; app khách hiện các suất trong 7 ngày tới. **MOB-FR-SHOW-08-AC-02** — Thử đầu vào sai/thiếu quyền/xung đột áp dụng và kiểm tra từ chối đã nêu, không đổi dữ liệu trái phép và không báo thành công sai. |
| Bằng chứng | [Cinema_BE/MovieService/MovieService/Controllers/ShowtimesController.cs](../Cinema_BE/MovieService/MovieService/Controllers/ShowtimesController.cs); [Cinema_Mobile/lib/features/movie/screens/movie_detail_screen.dart](../Cinema_Mobile/lib/features/movie/screens/movie_detail_screen.dart); [Cinema_BE/MovieService/MovieService/Service/Impl/ShowtimeService.cs](../Cinema_BE/MovieService/MovieService/Service/Impl/ShowtimeService.cs) |
| Quy tắc nghiệp vụ | MOB-BR-05, MOB-BR-06, MOB-BR-15, MOB-BR-19, MOB-BR-30 |
| Ca sử dụng / màn / API | UC-MOB-04; MOB-SCR-MOVIE; MOB-API-003 |

### MOB-FR-SHOW-13 — Định dạng chiếu

| Trường | Đặc tả |
| --- | --- |
| Tên | Định dạng chiếu |
| Mô tả | Hiển thị định dạng 2D/3D/IMAX cạnh phòng và dùng seatPrices từ server. Backend chung cộng 20.000đ cho 3D hoặc 40.000đ cho IMAX vào giá ghế thường 2D trước khi tính phụ thu VIP/sweetbox. Phạm vi không có màn sửa suất trên điện thoại. |
| Tác nhân | Khách chưa đăng nhập/khách hàng; nhân viên/quản trị viên chỉ xem chi tiết trong check-in |
| Tiền điều kiện | Phim và phòng tồn tại; thay đổi quản lý cần nhân viên/quản trị viên. |
| Kích hoạt | Thực hiện “Định dạng chiếu” hoặc sự kiện/tác vụ backend tương ứng. |
| Luồng chính | 1. Đọc đầu vào/tài nguyên hiện tại và phiên áp dụng. 2. Thực hiện thao tác này: Hiển thị định dạng 2D/3D/IMAX cạnh phòng và dùng seatPrices từ server. Backend chung cộng 20.000đ cho 3D hoặc 40.000đ cho IMAX vào giá ghế thường 2D trước khi tính phụ thu VIP/sweetbox. Phạm vi không có màn sửa suất trên điện thoại. 3. Trả/hiển thị kết quả chính thức và làm mới dữ liệu bị tác động sau thành công. |
| Luồng thay thế / ngoại lệ | Từ chối trùng lịch bằng 409 và giờ/định dạng sai bằng 400; suất đã huỷ là trạng thái cuối. Khách không chọn suất đóng bán hoặc đã bắt đầu. |
| Hậu điều kiện | Dữ liệu/trạng thái đủ quyền được trả/hiển thị; đọc không đổi trạng thái vé/thanh toán. Dấu đã đọc thông báo chỉ đổi bằng thao tác ghi riêng. |
| Ưu tiên | M |
| Tiêu chí nghiệm thu | **MOB-FR-SHOW-13-AC-01** — Với tiền điều kiện/kích hoạt, kiểm tra: Hiển thị định dạng 2D/3D/IMAX cạnh phòng và dùng seatPrices từ server. Backend chung cộng 20.000đ cho 3D hoặc 40.000đ cho IMAX vào giá ghế thường 2D trước khi tính phụ thu VIP/sweetbox. Phạm vi không có màn sửa suất trên điện thoại. **MOB-FR-SHOW-13-AC-02** — Thử đầu vào sai/thiếu quyền/xung đột áp dụng và kiểm tra từ chối đã nêu, không đổi dữ liệu trái phép và không báo thành công sai. |
| Bằng chứng | [Cinema_BE/MovieService/MovieService/Controllers/ShowtimesController.cs](../Cinema_BE/MovieService/MovieService/Controllers/ShowtimesController.cs); [Cinema_Mobile/lib/features/movie/screens/movie_detail_screen.dart](../Cinema_Mobile/lib/features/movie/screens/movie_detail_screen.dart); [Cinema_Mobile/lib/features/seat/screens/seat_selection_screen.dart](../Cinema_Mobile/lib/features/seat/screens/seat_selection_screen.dart); [Cinema_BE/MovieService/MovieService/Service/Impl/ShowtimeService.cs](../Cinema_BE/MovieService/MovieService/Service/Impl/ShowtimeService.cs) |
| Quy tắc nghiệp vụ | MOB-BR-05, MOB-BR-06, MOB-BR-15, MOB-BR-19, MOB-BR-30 |
| Ca sử dụng / màn / API | UC-MOB-04; MOB-SCR-MOVIE, MOB-SCR-SEATS; MOB-API-002 |

### MOB-FR-BOOK-01 — Giữ chỗ đặt vé

| Trường | Đặc tả |
| --- | --- |
| Tên | Giữ chỗ đặt vé |
| Mô tả | Tạo booking từ suất chiếu và danh sách ghế: suất phải `OPEN` và chưa bắt đầu, ít nhất một ghế, không trùng ghế. Server lấy giờ chiếu, tên phim và giá từ MovieService. Booking `PENDING`, giữ ghế 10 phút. |
| Tác nhân | Khách hàng |
| Tiền điều kiện | Khách đã đăng nhập chọn suất OPEN chưa bắt đầu và ghế; khách vãng lai tại quầy được nhân viên/quản trị viên thao tác thay. |
| Kích hoạt | Thực hiện “Giữ chỗ đặt vé” hoặc sự kiện/tác vụ backend tương ứng. |
| Luồng chính | 1. Đọc đầu vào/tài nguyên hiện tại và phiên áp dụng. 2. Thực hiện thao tác này: Tạo booking từ suất chiếu và danh sách ghế: suất phải `OPEN` và chưa bắt đầu, ít nhất một ghế, không trùng ghế. Server lấy giờ chiếu, tên phim và giá từ MovieService. Booking `PENDING`, giữ ghế 10 phút. 3. Trả/hiển thị kết quả chính thức và làm mới dữ liệu bị tác động sau thành công. |
| Luồng thay thế / ngoại lệ | Giữ chỗ đồng thời trả 409 và không được thu tiền hoặc để lại ghế/điểm dở dang. Bắp nước/mã/điểm sai trả lỗi kiểm tra. Hết hạn nhả ghế và trả điểm đã giữ. |
| Hậu điều kiện | Một vé PENDING có tổng tiền server và expiresAt được commit; ghế HELD mười phút. Giao dịch bị từ chối không để giữ ghế hoặc trừ điểm dở dang. |
| Ưu tiên | H |
| Tiêu chí nghiệm thu | **MOB-FR-BOOK-01-AC-01** — Với tiền điều kiện/kích hoạt, kiểm tra: Tạo booking từ suất chiếu và danh sách ghế: suất phải `OPEN` và chưa bắt đầu, ít nhất một ghế, không trùng ghế. Server lấy giờ chiếu, tên phim và giá từ MovieService. Booking `PENDING`, giữ ghế 10 phút. **MOB-FR-BOOK-01-AC-02** — Thử đầu vào sai/thiếu quyền/xung đột áp dụng và kiểm tra từ chối đã nêu, không đổi dữ liệu trái phép và không báo thành công sai. |
| Bằng chứng | [Cinema_BE/BookingService/BookingService/Controllers/BookingController.cs](../Cinema_BE/BookingService/BookingService/Controllers/BookingController.cs); [Cinema_Mobile/lib/features/booking/screens/booking_summary_screen.dart](../Cinema_Mobile/lib/features/booking/screens/booking_summary_screen.dart); [Cinema_BE/BookingService/BookingService/Services/Implementations/BookingService.cs](../Cinema_BE/BookingService/BookingService/Services/Implementations/BookingService.cs); [Cinema_BE/BookingService/BookingService/Helpers/PromotionRules.cs](../Cinema_BE/BookingService/BookingService/Helpers/PromotionRules.cs); [Cinema_BE/BookingService/BookingService/Helpers/LoyaltyRules.cs](../Cinema_BE/BookingService/BookingService/Helpers/LoyaltyRules.cs) |
| Quy tắc nghiệp vụ | MOB-BR-07, MOB-BR-08, MOB-BR-14, MOB-BR-15, MOB-BR-16, MOB-BR-17, MOB-BR-27, MOB-BR-28, MOB-BR-29 |
| Ca sử dụng / màn / API | UC-MOB-05; MOB-SCR-SUMMARY; MOB-API-021 |

### MOB-FR-BOOK-02 — Chi tiết vé

| Trường | Đặc tả |
| --- | --- |
| Tên | Chi tiết vé |
| Mô tả | Khách mở chi tiết vé của mình, gồm ghế, tiền, trạng thái, hạn, QR/check-in và hoàn tiền khi áp dụng từ server; nhân viên/quản trị viên chỉ tra vé trong luồng check-in. |
| Tác nhân | Khách hàng |
| Tiền điều kiện | Khách đã đăng nhập và sở hữu vé liên quan; thao tác phải được trạng thái và giờ vé cho phép. Quyền nhân viên chỉ áp dụng nơi đã nêu. |
| Kích hoạt | Thực hiện “Chi tiết vé” hoặc sự kiện/tác vụ backend tương ứng. |
| Luồng chính | 1. Đọc đầu vào/tài nguyên hiện tại và phiên áp dụng. 2. Thực hiện thao tác này: Khách mở chi tiết vé của mình, gồm ghế, tiền, trạng thái, hạn, QR/check-in và hoàn tiền khi áp dụng từ server; nhân viên/quản trị viên chỉ tra vé trong luồng check-in. 3. Trả/hiển thị kết quả chính thức và làm mới dữ liệu bị tác động sau thành công. |
| Luồng thay thế / ngoại lệ | Giữ chỗ đồng thời trả 409 và không được thu tiền hoặc để lại ghế/điểm dở dang. Bắp nước/mã/điểm sai trả lỗi kiểm tra. Hết hạn nhả ghế và trả điểm đã giữ. |
| Hậu điều kiện | Dữ liệu/trạng thái đủ quyền được trả/hiển thị; đọc không đổi trạng thái vé/thanh toán. Dấu đã đọc thông báo chỉ đổi bằng thao tác ghi riêng. |
| Ưu tiên | H |
| Tiêu chí nghiệm thu | **MOB-FR-BOOK-02-AC-01** — Với tiền điều kiện/kích hoạt, kiểm tra: Khách mở chi tiết vé của mình, gồm ghế, tiền, trạng thái, hạn, QR/check-in và hoàn tiền khi áp dụng từ server; nhân viên/quản trị viên chỉ tra vé trong luồng check-in. **MOB-FR-BOOK-02-AC-02** — Thử đầu vào sai/thiếu quyền/xung đột áp dụng và kiểm tra từ chối đã nêu, không đổi dữ liệu trái phép và không báo thành công sai. |
| Bằng chứng | [Cinema_BE/BookingService/BookingService/Controllers/BookingController.cs](../Cinema_BE/BookingService/BookingService/Controllers/BookingController.cs); [Cinema_Mobile/lib/features/payment/screens/payment_result_screen.dart](../Cinema_Mobile/lib/features/payment/screens/payment_result_screen.dart); [Cinema_Mobile/lib/features/booking/screens/booking_detail_screen.dart](../Cinema_Mobile/lib/features/booking/screens/booking_detail_screen.dart); [Cinema_BE/BookingService/BookingService/Services/Implementations/BookingService.cs](../Cinema_BE/BookingService/BookingService/Services/Implementations/BookingService.cs); [Cinema_BE/BookingService/BookingService/Helpers/PromotionRules.cs](../Cinema_BE/BookingService/BookingService/Helpers/PromotionRules.cs); [Cinema_BE/BookingService/BookingService/Helpers/LoyaltyRules.cs](../Cinema_BE/BookingService/BookingService/Helpers/LoyaltyRules.cs) |
| Quy tắc nghiệp vụ | MOB-BR-07, MOB-BR-08, MOB-BR-14, MOB-BR-15, MOB-BR-16, MOB-BR-17, MOB-BR-27, MOB-BR-28, MOB-BR-29 |
| Ca sử dụng / màn / API | UC-MOB-05; MOB-SCR-RESULT, MOB-SCR-TICKET; MOB-API-017 |

### MOB-FR-BOOK-04 — Lịch sử vé của mình

| Trường | Đặc tả |
| --- | --- |
| Tên | Lịch sử vé của mình |
| Mô tả | Khách xem vé của mình, chia **Active** và **History**. |
| Tác nhân | Khách hàng |
| Tiền điều kiện | Khách đã đăng nhập và sở hữu vé liên quan; thao tác phải được trạng thái và giờ vé cho phép. Quyền nhân viên chỉ áp dụng nơi đã nêu. |
| Kích hoạt | Thực hiện “Lịch sử vé của mình” hoặc sự kiện/tác vụ backend tương ứng. |
| Luồng chính | 1. Đọc đầu vào/tài nguyên hiện tại và phiên áp dụng. 2. Thực hiện thao tác này: Khách xem vé của mình, chia **Active** và **History**. 3. Trả/hiển thị kết quả chính thức và làm mới dữ liệu bị tác động sau thành công. |
| Luồng thay thế / ngoại lệ | Giữ chỗ đồng thời trả 409 và không được thu tiền hoặc để lại ghế/điểm dở dang. Bắp nước/mã/điểm sai trả lỗi kiểm tra. Hết hạn nhả ghế và trả điểm đã giữ. |
| Hậu điều kiện | Dữ liệu/trạng thái đủ quyền được trả/hiển thị; đọc không đổi trạng thái vé/thanh toán. Dấu đã đọc thông báo chỉ đổi bằng thao tác ghi riêng. |
| Ưu tiên | H |
| Tiêu chí nghiệm thu | **MOB-FR-BOOK-04-AC-01** — Với tiền điều kiện/kích hoạt, kiểm tra: Khách xem vé của mình, chia **Active** và **History**. **MOB-FR-BOOK-04-AC-02** — Thử đầu vào sai/thiếu quyền/xung đột áp dụng và kiểm tra từ chối đã nêu, không đổi dữ liệu trái phép và không báo thành công sai. |
| Bằng chứng | [Cinema_BE/BookingService/BookingService/Controllers/BookingController.cs](../Cinema_BE/BookingService/BookingService/Controllers/BookingController.cs); [Cinema_Mobile/lib/features/booking/screens/my_bookings_screen.dart](../Cinema_Mobile/lib/features/booking/screens/my_bookings_screen.dart); [Cinema_BE/BookingService/BookingService/Services/Implementations/BookingService.cs](../Cinema_BE/BookingService/BookingService/Services/Implementations/BookingService.cs); [Cinema_BE/BookingService/BookingService/Helpers/PromotionRules.cs](../Cinema_BE/BookingService/BookingService/Helpers/PromotionRules.cs); [Cinema_BE/BookingService/BookingService/Helpers/LoyaltyRules.cs](../Cinema_BE/BookingService/BookingService/Helpers/LoyaltyRules.cs) |
| Quy tắc nghiệp vụ | MOB-BR-07, MOB-BR-08, MOB-BR-14, MOB-BR-15, MOB-BR-16, MOB-BR-17, MOB-BR-27, MOB-BR-28, MOB-BR-29 |
| Ca sử dụng / màn / API | UC-MOB-05; MOB-SCR-TICKETS; MOB-API-020 |

### MOB-FR-BOOK-05 — Xác nhận vé đã trả

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
| Tiêu chí nghiệm thu | **MOB-FR-BOOK-05-AC-01** — Với tiền điều kiện/kích hoạt, kiểm tra: Xác nhận booking sau khi thanh toán thành công (chi tiết ở PAY và POS). **MOB-FR-BOOK-05-AC-02** — Thử đầu vào sai/thiếu quyền/xung đột áp dụng và kiểm tra từ chối đã nêu, không đổi dữ liệu trái phép và không báo thành công sai. |
| Bằng chứng | [Cinema_BE/BookingService/BookingService/Controllers/PaymentController.cs](../Cinema_BE/BookingService/BookingService/Controllers/PaymentController.cs); [Cinema_Mobile/lib/features/payment/screens/payment_screen.dart](../Cinema_Mobile/lib/features/payment/screens/payment_screen.dart); [Cinema_Mobile/lib/features/payment/screens/payment_result_screen.dart](../Cinema_Mobile/lib/features/payment/screens/payment_result_screen.dart); [Cinema_Mobile/lib/features/booking/screens/booking_detail_screen.dart](../Cinema_Mobile/lib/features/booking/screens/booking_detail_screen.dart); [Cinema_BE/BookingService/BookingService/Services/Implementations/BookingService.cs](../Cinema_BE/BookingService/BookingService/Services/Implementations/BookingService.cs); [Cinema_BE/BookingService/BookingService/Helpers/PromotionRules.cs](../Cinema_BE/BookingService/BookingService/Helpers/PromotionRules.cs); [Cinema_BE/BookingService/BookingService/Helpers/LoyaltyRules.cs](../Cinema_BE/BookingService/BookingService/Helpers/LoyaltyRules.cs) |
| Quy tắc nghiệp vụ | MOB-BR-07, MOB-BR-08, MOB-BR-14, MOB-BR-15, MOB-BR-16, MOB-BR-17, MOB-BR-27, MOB-BR-28, MOB-BR-29 |
| Ca sử dụng / màn / API | UC-MOB-05; MOB-SCR-PAYMENT, MOB-SCR-RESULT, MOB-SCR-TICKET; MOB-API-034, MOB-API-036 |

### MOB-FR-BOOK-06 — Huỷ vé

| Trường | Đặc tả |
| --- | --- |
| Tên | Huỷ vé |
| Mô tả | Huỷ booking: vé chờ thanh toán thì huỷ và nhả ghế; vé đã thanh toán thì theo MOB-BR-17. Khách huỷ vé đã thanh toán tạo yêu cầu hoàn tiền: booking `REFUND_PENDING` và vẫn giữ ghế cho tới khi Staff xử lý. |
| Tác nhân | Khách hàng |
| Tiền điều kiện | Khách đã đăng nhập và sở hữu vé liên quan; thao tác phải được trạng thái và giờ vé cho phép. Quyền nhân viên chỉ áp dụng nơi đã nêu. |
| Kích hoạt | Thực hiện “Huỷ vé” hoặc sự kiện/tác vụ backend tương ứng. |
| Luồng chính | 1. Đọc đầu vào/tài nguyên hiện tại và phiên áp dụng. 2. Thực hiện thao tác này: Huỷ booking: vé chờ thanh toán thì huỷ và nhả ghế; vé đã thanh toán thì theo MOB-BR-17. Khách huỷ vé đã thanh toán tạo yêu cầu hoàn tiền: booking `REFUND_PENDING` và vẫn giữ ghế cho tới khi Staff xử lý. 3. Trả/hiển thị kết quả chính thức và làm mới dữ liệu bị tác động sau thành công. |
| Luồng thay thế / ngoại lệ | Giữ chỗ đồng thời trả 409 và không được thu tiền hoặc để lại ghế/điểm dở dang. Bắp nước/mã/điểm sai trả lỗi kiểm tra. Hết hạn nhả ghế và trả điểm đã giữ. |
| Hậu điều kiện | Kết quả thành công quan sát được khớp yêu cầu này; chuyển trạng thái được chỉ định được lưu. Từ chối không cấp quyền hoặc để thay đổi dở dang trái phép. |
| Ưu tiên | H |
| Tiêu chí nghiệm thu | **MOB-FR-BOOK-06-AC-01** — Với tiền điều kiện/kích hoạt, kiểm tra: Huỷ booking: vé chờ thanh toán thì huỷ và nhả ghế; vé đã thanh toán thì theo MOB-BR-17. Khách huỷ vé đã thanh toán tạo yêu cầu hoàn tiền: booking `REFUND_PENDING` và vẫn giữ ghế cho tới khi Staff xử lý. **MOB-FR-BOOK-06-AC-02** — Thử đầu vào sai/thiếu quyền/xung đột áp dụng và kiểm tra từ chối đã nêu, không đổi dữ liệu trái phép và không báo thành công sai. |
| Bằng chứng | [Cinema_BE/BookingService/BookingService/Controllers/BookingController.cs](../Cinema_BE/BookingService/BookingService/Controllers/BookingController.cs); [Cinema_Mobile/lib/features/booking/screens/booking_detail_screen.dart](../Cinema_Mobile/lib/features/booking/screens/booking_detail_screen.dart); [Cinema_BE/BookingService/BookingService/Services/Implementations/BookingService.cs](../Cinema_BE/BookingService/BookingService/Services/Implementations/BookingService.cs); [Cinema_BE/BookingService/BookingService/Helpers/PromotionRules.cs](../Cinema_BE/BookingService/BookingService/Helpers/PromotionRules.cs); [Cinema_BE/BookingService/BookingService/Helpers/LoyaltyRules.cs](../Cinema_BE/BookingService/BookingService/Helpers/LoyaltyRules.cs) |
| Quy tắc nghiệp vụ | MOB-BR-07, MOB-BR-08, MOB-BR-14, MOB-BR-15, MOB-BR-16, MOB-BR-17, MOB-BR-27, MOB-BR-28, MOB-BR-29 |
| Ca sử dụng / màn / API | UC-MOB-05; MOB-SCR-TICKET; MOB-API-015 |

### MOB-FR-BOOK-07 — ID ghế đã chiếm

| Trường | Đặc tả |
| --- | --- |
| Tên | ID ghế đã chiếm |
| Mô tả | Lấy các ghế đã giữ / đã bán của một suất chiếu. |
| Tác nhân | Khách hàng |
| Tiền điều kiện | Khách đã đăng nhập chọn suất OPEN chưa bắt đầu và ghế; khách vãng lai tại quầy được nhân viên/quản trị viên thao tác thay. |
| Kích hoạt | Thực hiện “ID ghế đã chiếm” hoặc sự kiện/tác vụ backend tương ứng. |
| Luồng chính | 1. Đọc đầu vào/tài nguyên hiện tại và phiên áp dụng. 2. Thực hiện thao tác này: Lấy các ghế đã giữ / đã bán của một suất chiếu. 3. Trả/hiển thị kết quả chính thức và làm mới dữ liệu bị tác động sau thành công. |
| Luồng thay thế / ngoại lệ | Giữ chỗ đồng thời trả 409 và không được thu tiền hoặc để lại ghế/điểm dở dang. Bắp nước/mã/điểm sai trả lỗi kiểm tra. Hết hạn nhả ghế và trả điểm đã giữ. |
| Hậu điều kiện | Dữ liệu/trạng thái đủ quyền được trả/hiển thị; đọc không đổi trạng thái vé/thanh toán. Dấu đã đọc thông báo chỉ đổi bằng thao tác ghi riêng. |
| Ưu tiên | H |
| Tiêu chí nghiệm thu | **MOB-FR-BOOK-07-AC-01** — Với tiền điều kiện/kích hoạt, kiểm tra: Lấy các ghế đã giữ / đã bán của một suất chiếu. **MOB-FR-BOOK-07-AC-02** — Thử đầu vào sai/thiếu quyền/xung đột áp dụng và kiểm tra từ chối đã nêu, không đổi dữ liệu trái phép và không báo thành công sai. |
| Bằng chứng | [Cinema_BE/BookingService/BookingService/Controllers/BookingController.cs](../Cinema_BE/BookingService/BookingService/Controllers/BookingController.cs); [Cinema_Mobile/lib/features/seat/screens/seat_selection_screen.dart](../Cinema_Mobile/lib/features/seat/screens/seat_selection_screen.dart); [Cinema_BE/BookingService/BookingService/Services/Implementations/BookingService.cs](../Cinema_BE/BookingService/BookingService/Services/Implementations/BookingService.cs); [Cinema_BE/BookingService/BookingService/Helpers/PromotionRules.cs](../Cinema_BE/BookingService/BookingService/Helpers/PromotionRules.cs); [Cinema_BE/BookingService/BookingService/Helpers/LoyaltyRules.cs](../Cinema_BE/BookingService/BookingService/Helpers/LoyaltyRules.cs) |
| Quy tắc nghiệp vụ | MOB-BR-07, MOB-BR-08, MOB-BR-14, MOB-BR-15, MOB-BR-16, MOB-BR-17, MOB-BR-27, MOB-BR-28, MOB-BR-29 |
| Ca sử dụng / màn / API | UC-MOB-05; MOB-SCR-SEATS; MOB-API-019 |

### MOB-FR-BOOK-08 — Xung đột ghế đồng thời

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
| Tiêu chí nghiệm thu | **MOB-FR-BOOK-08-AC-01** — Với tiền điều kiện/kích hoạt, kiểm tra: Ghế đang được booking khác giữ hoặc đã bán thì trả 409. **MOB-FR-BOOK-08-AC-02** — Thử đầu vào sai/thiếu quyền/xung đột áp dụng và kiểm tra từ chối đã nêu, không đổi dữ liệu trái phép và không báo thành công sai. |
| Bằng chứng | [Cinema_BE/BookingService/BookingService/Controllers/BookingController.cs](../Cinema_BE/BookingService/BookingService/Controllers/BookingController.cs); [Cinema_Mobile/lib/features/seat/screens/seat_selection_screen.dart](../Cinema_Mobile/lib/features/seat/screens/seat_selection_screen.dart); [Cinema_BE/BookingService/BookingService/Services/Implementations/BookingService.cs](../Cinema_BE/BookingService/BookingService/Services/Implementations/BookingService.cs); [Cinema_BE/BookingService/BookingService/Helpers/PromotionRules.cs](../Cinema_BE/BookingService/BookingService/Helpers/PromotionRules.cs); [Cinema_BE/BookingService/BookingService/Helpers/LoyaltyRules.cs](../Cinema_BE/BookingService/BookingService/Helpers/LoyaltyRules.cs) |
| Quy tắc nghiệp vụ | MOB-BR-07, MOB-BR-08, MOB-BR-14, MOB-BR-15, MOB-BR-16, MOB-BR-17, MOB-BR-27, MOB-BR-28, MOB-BR-29 |
| Ca sử dụng / màn / API | UC-MOB-05; MOB-SCR-SEATS; MOB-API-021 |

### MOB-FR-BOOK-09 — Cặp sweetbox

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
| Tiêu chí nghiệm thu | **MOB-FR-BOOK-09-AC-01** — Với tiền điều kiện/kích hoạt, kiểm tra: Sweetbox phải đặt đủ cặp (server từ chối nửa cặp). **MOB-FR-BOOK-09-AC-02** — Thử đầu vào sai/thiếu quyền/xung đột áp dụng và kiểm tra từ chối đã nêu, không đổi dữ liệu trái phép và không báo thành công sai. |
| Bằng chứng | [Cinema_BE/BookingService/BookingService/Controllers/BookingController.cs](../Cinema_BE/BookingService/BookingService/Controllers/BookingController.cs); [Cinema_Mobile/lib/features/seat/screens/seat_selection_screen.dart](../Cinema_Mobile/lib/features/seat/screens/seat_selection_screen.dart); [Cinema_Mobile/lib/features/booking/screens/booking_summary_screen.dart](../Cinema_Mobile/lib/features/booking/screens/booking_summary_screen.dart); [Cinema_BE/BookingService/BookingService/Services/Implementations/BookingService.cs](../Cinema_BE/BookingService/BookingService/Services/Implementations/BookingService.cs); [Cinema_BE/BookingService/BookingService/Helpers/PromotionRules.cs](../Cinema_BE/BookingService/BookingService/Helpers/PromotionRules.cs); [Cinema_BE/BookingService/BookingService/Helpers/LoyaltyRules.cs](../Cinema_BE/BookingService/BookingService/Helpers/LoyaltyRules.cs) |
| Quy tắc nghiệp vụ | MOB-BR-07, MOB-BR-08, MOB-BR-14, MOB-BR-15, MOB-BR-16, MOB-BR-17, MOB-BR-27, MOB-BR-28, MOB-BR-29 |
| Ca sử dụng / màn / API | UC-MOB-05; MOB-SCR-SEATS, MOB-SCR-SUMMARY; MOB-API-021 |

### MOB-FR-BOOK-10 — Hết hạn giữ chỗ chưa trả

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
| Tiêu chí nghiệm thu | **MOB-FR-BOOK-10-AC-01** — Với tiền điều kiện/kích hoạt, kiểm tra: Job nền chạy mỗi 30 giây chuyển booking quá hạn giữ ghế sang `EXPIRED` và nhả ghế. **MOB-FR-BOOK-10-AC-02** — Thử đầu vào sai/thiếu quyền/xung đột áp dụng và kiểm tra từ chối đã nêu, không đổi dữ liệu trái phép và không báo thành công sai. |
| Bằng chứng | [Cinema_BE/BookingService/BookingService/Controllers/BookingController.cs](../Cinema_BE/BookingService/BookingService/Controllers/BookingController.cs); [Cinema_Mobile/lib/features/payment/screens/payment_screen.dart](../Cinema_Mobile/lib/features/payment/screens/payment_screen.dart); [Cinema_BE/BookingService/BookingService/Services/Implementations/BookingService.cs](../Cinema_BE/BookingService/BookingService/Services/Implementations/BookingService.cs); [Cinema_BE/BookingService/BookingService/Helpers/PromotionRules.cs](../Cinema_BE/BookingService/BookingService/Helpers/PromotionRules.cs); [Cinema_BE/BookingService/BookingService/Helpers/LoyaltyRules.cs](../Cinema_BE/BookingService/BookingService/Helpers/LoyaltyRules.cs) |
| Quy tắc nghiệp vụ | MOB-BR-07, MOB-BR-08, MOB-BR-14, MOB-BR-15, MOB-BR-16, MOB-BR-17, MOB-BR-27, MOB-BR-28, MOB-BR-29 |
| Ca sử dụng / màn / API | UC-MOB-05; MOB-SCR-PAYMENT; MOB-API-017 |

### MOB-FR-BOOK-11 — Làm mới sơ đồ khách

| Trường | Đặc tả |
| --- | --- |
| Tên | Làm mới sơ đồ khách |
| Mô tả | Màn chọn ghế tự làm mới mỗi 5 giây; ghế đang chọn bị người khác đặt thì bỏ chọn và báo cho khách. |
| Tác nhân | Khách hàng |
| Tiền điều kiện | Khách đã đăng nhập chọn suất OPEN chưa bắt đầu và ghế; khách vãng lai tại quầy được nhân viên/quản trị viên thao tác thay. |
| Kích hoạt | Thực hiện “Làm mới sơ đồ khách” hoặc sự kiện/tác vụ backend tương ứng. |
| Luồng chính | 1. Đọc đầu vào/tài nguyên hiện tại và phiên áp dụng. 2. Thực hiện thao tác này: Màn chọn ghế tự làm mới mỗi 5 giây; ghế đang chọn bị người khác đặt thì bỏ chọn và báo cho khách. 3. Trả/hiển thị kết quả chính thức và làm mới dữ liệu bị tác động sau thành công. |
| Luồng thay thế / ngoại lệ | Giữ chỗ đồng thời trả 409 và không được thu tiền hoặc để lại ghế/điểm dở dang. Bắp nước/mã/điểm sai trả lỗi kiểm tra. Hết hạn nhả ghế và trả điểm đã giữ. |
| Hậu điều kiện | Dữ liệu/trạng thái đủ quyền được trả/hiển thị; đọc không đổi trạng thái vé/thanh toán. Dấu đã đọc thông báo chỉ đổi bằng thao tác ghi riêng. |
| Ưu tiên | M |
| Tiêu chí nghiệm thu | **MOB-FR-BOOK-11-AC-01** — Với tiền điều kiện/kích hoạt, kiểm tra: Màn chọn ghế tự làm mới mỗi 5 giây; ghế đang chọn bị người khác đặt thì bỏ chọn và báo cho khách. **MOB-FR-BOOK-11-AC-02** — Thử đầu vào sai/thiếu quyền/xung đột áp dụng và kiểm tra từ chối đã nêu, không đổi dữ liệu trái phép và không báo thành công sai. |
| Bằng chứng | [Cinema_BE/MovieService/MovieService/Controllers/SeatsController.cs](../Cinema_BE/MovieService/MovieService/Controllers/SeatsController.cs); [Cinema_BE/BookingService/BookingService/Controllers/BookingController.cs](../Cinema_BE/BookingService/BookingService/Controllers/BookingController.cs); [Cinema_Mobile/lib/features/seat/screens/seat_selection_screen.dart](../Cinema_Mobile/lib/features/seat/screens/seat_selection_screen.dart); [Cinema_BE/BookingService/BookingService/Services/Implementations/BookingService.cs](../Cinema_BE/BookingService/BookingService/Services/Implementations/BookingService.cs); [Cinema_BE/BookingService/BookingService/Helpers/PromotionRules.cs](../Cinema_BE/BookingService/BookingService/Helpers/PromotionRules.cs); [Cinema_BE/BookingService/BookingService/Helpers/LoyaltyRules.cs](../Cinema_BE/BookingService/BookingService/Helpers/LoyaltyRules.cs) |
| Quy tắc nghiệp vụ | MOB-BR-07, MOB-BR-08, MOB-BR-14, MOB-BR-15, MOB-BR-16, MOB-BR-17, MOB-BR-27, MOB-BR-28, MOB-BR-29 |
| Ca sử dụng / màn / API | UC-MOB-05; MOB-SCR-SEATS; MOB-API-001, MOB-API-019 |

### MOB-FR-BOOK-13 — Bắp nước kèm vé

| Trường | Đặc tả |
| --- | --- |
| Tên | Bắp nước kèm vé |
| Mô tả | Tại xác nhận đặt vé chọn bắp nước đang bán, mỗi món 1–20 và tối đa mười món khác nhau. Server tính giá từ menu đang bán và lưu tên/giá lúc mua. Tính bắp nước vào tổng tiền, thanh toán/hoàn tiền và hiển thị vé; món ngừng bán bị 400. |
| Tác nhân | Khách hàng |
| Tiền điều kiện | Khách đã đăng nhập chọn suất OPEN chưa bắt đầu và ghế; khách vãng lai tại quầy được nhân viên/quản trị viên thao tác thay. |
| Kích hoạt | Thực hiện “Bắp nước kèm vé” hoặc sự kiện/tác vụ backend tương ứng. |
| Luồng chính | 1. Đọc đầu vào/tài nguyên hiện tại và phiên áp dụng. 2. Thực hiện thao tác này: Tại xác nhận đặt vé chọn bắp nước đang bán, mỗi món 1–20 và tối đa mười món khác nhau. Server tính giá từ menu đang bán và lưu tên/giá lúc mua. Tính bắp nước vào tổng tiền, thanh toán/hoàn tiền và hiển thị vé; món ngừng bán bị 400. 3. Trả/hiển thị kết quả chính thức và làm mới dữ liệu bị tác động sau thành công. |
| Luồng thay thế / ngoại lệ | Giữ chỗ đồng thời trả 409 và không được thu tiền hoặc để lại ghế/điểm dở dang. Bắp nước/mã/điểm sai trả lỗi kiểm tra. Hết hạn nhả ghế và trả điểm đã giữ. |
| Hậu điều kiện | Kết quả thành công quan sát được khớp yêu cầu này; chuyển trạng thái được chỉ định được lưu. Từ chối không cấp quyền hoặc để thay đổi dở dang trái phép. |
| Ưu tiên | M |
| Tiêu chí nghiệm thu | **MOB-FR-BOOK-13-AC-01** — Với tiền điều kiện/kích hoạt, kiểm tra: Tại xác nhận đặt vé chọn bắp nước đang bán, mỗi món 1–20 và tối đa mười món khác nhau. Server tính giá từ menu đang bán và lưu tên/giá lúc mua. Tính bắp nước vào tổng tiền, thanh toán/hoàn tiền và hiển thị vé; món ngừng bán bị 400. **MOB-FR-BOOK-13-AC-02** — Thử đầu vào sai/thiếu quyền/xung đột áp dụng và kiểm tra từ chối đã nêu, không đổi dữ liệu trái phép và không báo thành công sai. |
| Bằng chứng | [Cinema_BE/BookingService/BookingService/Controllers/BookingController.cs](../Cinema_BE/BookingService/BookingService/Controllers/BookingController.cs); [Cinema_BE/BookingService/BookingService/Controllers/ConcessionController.cs](../Cinema_BE/BookingService/BookingService/Controllers/ConcessionController.cs); [Cinema_Mobile/lib/features/booking/screens/booking_summary_screen.dart](../Cinema_Mobile/lib/features/booking/screens/booking_summary_screen.dart); [Cinema_Mobile/lib/features/booking/screens/booking_detail_screen.dart](../Cinema_Mobile/lib/features/booking/screens/booking_detail_screen.dart); [Cinema_BE/BookingService/BookingService/Services/Implementations/BookingService.cs](../Cinema_BE/BookingService/BookingService/Services/Implementations/BookingService.cs); [Cinema_BE/BookingService/BookingService/Helpers/PromotionRules.cs](../Cinema_BE/BookingService/BookingService/Helpers/PromotionRules.cs); [Cinema_BE/BookingService/BookingService/Helpers/LoyaltyRules.cs](../Cinema_BE/BookingService/BookingService/Helpers/LoyaltyRules.cs) |
| Quy tắc nghiệp vụ | MOB-BR-07, MOB-BR-08, MOB-BR-14, MOB-BR-15, MOB-BR-16, MOB-BR-17, MOB-BR-27, MOB-BR-28, MOB-BR-29 |
| Ca sử dụng / màn / API | UC-MOB-05; MOB-SCR-SUMMARY, MOB-SCR-TICKET; MOB-API-021, MOB-API-022 |

### MOB-FR-BOOK-15 — Khuyến mãi và mã giảm giá

| Trường | Đặc tả |
| --- | --- |
| Tên | Khuyến mãi và mã giảm giá |
| Mô tả | Áp dụng một mã nhập đủ điều kiện hoặc ưu đãi tự động tốt nhất chỉ cho tiền vé (không bắp nước), dùng giảm phần trăm/cố định và tối đa 90% tiền vé làm tròn xuống 1.000đ. Kiểm tra thời gian chạy, thứ của suất, số vé tối thiểu và giới hạn lượt. Hiện báo giá ở xác nhận và tiền giảm ở vé/thanh toán; server tính lại khi đặt và chỉ đếm lượt sau trả tiền. Mã sai/không đủ điều kiện trả 400 kèm lý do. |
| Tác nhân | Khách hàng |
| Tiền điều kiện | Khách đã đăng nhập chọn suất OPEN chưa bắt đầu và ghế; khách vãng lai tại quầy được nhân viên/quản trị viên thao tác thay. |
| Kích hoạt | Thực hiện “Khuyến mãi và mã giảm giá” hoặc sự kiện/tác vụ backend tương ứng. |
| Luồng chính | 1. Đọc đầu vào/tài nguyên hiện tại và phiên áp dụng. 2. Thực hiện thao tác này: Áp dụng một mã nhập đủ điều kiện hoặc ưu đãi tự động tốt nhất chỉ cho tiền vé (không bắp nước), dùng giảm phần trăm/cố định và tối đa 90% tiền vé làm tròn xuống 1.000đ. Kiểm tra thời gian chạy, thứ của suất, số vé tối thiểu và giới hạn lượt. Hiện báo giá ở xác nhận và tiền giảm ở vé/thanh toán; server tính lại khi đặt và chỉ đếm lượt sau trả tiền. Mã sai/không đủ điều kiện trả 400 kèm lý do. 3. Trả/hiển thị kết quả chính thức và làm mới dữ liệu bị tác động sau thành công. |
| Luồng thay thế / ngoại lệ | Giữ chỗ đồng thời trả 409 và không được thu tiền hoặc để lại ghế/điểm dở dang. Bắp nước/mã/điểm sai trả lỗi kiểm tra. Hết hạn nhả ghế và trả điểm đã giữ. |
| Hậu điều kiện | Kết quả thành công quan sát được khớp yêu cầu này; chuyển trạng thái được chỉ định được lưu. Từ chối không cấp quyền hoặc để thay đổi dở dang trái phép. |
| Ưu tiên | M |
| Tiêu chí nghiệm thu | **MOB-FR-BOOK-15-AC-01** — Với tiền điều kiện/kích hoạt, kiểm tra: Áp dụng một mã nhập đủ điều kiện hoặc ưu đãi tự động tốt nhất chỉ cho tiền vé (không bắp nước), dùng giảm phần trăm/cố định và tối đa 90% tiền vé làm tròn xuống 1.000đ. Kiểm tra thời gian chạy, thứ của suất, số vé tối thiểu và giới hạn lượt. Hiện báo giá ở xác nhận và tiền giảm ở vé/thanh toán; server tính lại khi đặt và chỉ đếm lượt sau trả tiền. Mã sai/không đủ điều kiện trả 400 kèm lý do. **MOB-FR-BOOK-15-AC-02** — Thử đầu vào sai/thiếu quyền/xung đột áp dụng và kiểm tra từ chối đã nêu, không đổi dữ liệu trái phép và không báo thành công sai. |
| Bằng chứng | [Cinema_BE/BookingService/BookingService/Controllers/BookingController.cs](../Cinema_BE/BookingService/BookingService/Controllers/BookingController.cs); [Cinema_BE/BookingService/BookingService/Controllers/PromotionController.cs](../Cinema_BE/BookingService/BookingService/Controllers/PromotionController.cs); [Cinema_Mobile/lib/features/booking/screens/booking_summary_screen.dart](../Cinema_Mobile/lib/features/booking/screens/booking_summary_screen.dart); [Cinema_Mobile/lib/features/booking/screens/booking_detail_screen.dart](../Cinema_Mobile/lib/features/booking/screens/booking_detail_screen.dart); [Cinema_BE/BookingService/BookingService/Services/Implementations/BookingService.cs](../Cinema_BE/BookingService/BookingService/Services/Implementations/BookingService.cs); [Cinema_BE/BookingService/BookingService/Helpers/PromotionRules.cs](../Cinema_BE/BookingService/BookingService/Helpers/PromotionRules.cs); [Cinema_BE/BookingService/BookingService/Helpers/LoyaltyRules.cs](../Cinema_BE/BookingService/BookingService/Helpers/LoyaltyRules.cs) |
| Quy tắc nghiệp vụ | MOB-BR-07, MOB-BR-08, MOB-BR-14, MOB-BR-15, MOB-BR-16, MOB-BR-17, MOB-BR-27, MOB-BR-28, MOB-BR-29 |
| Ca sử dụng / màn / API | UC-MOB-05; MOB-SCR-SUMMARY, MOB-SCR-TICKET; MOB-API-021, MOB-API-038 |

### MOB-FR-BOOK-17 — Điểm thành viên

| Trường | Đặc tả |
| --- | --- |
| Tên | Điểm thành viên |
| Mô tả | Hiện thẻ thành viên, điểm, hạng, tiến độ và lịch sử trong Hồ sơ. Tích theo tiền thực trả: MEMBER 5%, VIP 7% (chi tiêu ≥2.000.000đ), VVIP 10% (≥5.000.000đ); một điểm bằng 1.000đ. Dùng tối đa 50% số tiền sau khuyến mãi; hết hạn/huỷ chưa trả hoàn điểm đã dùng; huỷ/hoàn vé đã trả hoàn điểm đã dùng, thu hồi điểm đã tích và chi tiêu theo backend chung. Điện thoại không có màn điều chỉnh điểm thủ công. |
| Tác nhân | Khách hàng |
| Tiền điều kiện | Khách đã đăng nhập chọn suất OPEN chưa bắt đầu và ghế; khách vãng lai tại quầy được nhân viên/quản trị viên thao tác thay. |
| Kích hoạt | Thực hiện “Điểm thành viên” hoặc sự kiện/tác vụ backend tương ứng. |
| Luồng chính | 1. Đọc đầu vào/tài nguyên hiện tại và phiên áp dụng. 2. Thực hiện thao tác này: Hiện thẻ thành viên, điểm, hạng, tiến độ và lịch sử trong Hồ sơ. Tích theo tiền thực trả: MEMBER 5%, VIP 7% (chi tiêu ≥2.000.000đ), VVIP 10% (≥5.000.000đ); một điểm bằng 1.000đ. Dùng tối đa 50% số tiền sau khuyến mãi; hết hạn/huỷ chưa trả hoàn điểm đã dùng; huỷ/hoàn vé đã trả hoàn điểm đã dùng, thu hồi điểm đã tích và chi tiêu theo backend chung. Điện thoại không có màn điều chỉnh điểm thủ công. 3. Trả/hiển thị kết quả chính thức và làm mới dữ liệu bị tác động sau thành công. |
| Luồng thay thế / ngoại lệ | Giữ chỗ đồng thời trả 409 và không được thu tiền hoặc để lại ghế/điểm dở dang. Bắp nước/mã/điểm sai trả lỗi kiểm tra. Hết hạn nhả ghế và trả điểm đã giữ. |
| Hậu điều kiện | Kết quả thành công quan sát được khớp yêu cầu này; chuyển trạng thái được chỉ định được lưu. Từ chối không cấp quyền hoặc để thay đổi dở dang trái phép. |
| Ưu tiên | M |
| Tiêu chí nghiệm thu | **MOB-FR-BOOK-17-AC-01** — Với tiền điều kiện/kích hoạt, kiểm tra: Hiện thẻ thành viên, điểm, hạng, tiến độ và lịch sử trong Hồ sơ. Tích theo tiền thực trả: MEMBER 5%, VIP 7% (chi tiêu ≥2.000.000đ), VVIP 10% (≥5.000.000đ); một điểm bằng 1.000đ. Dùng tối đa 50% số tiền sau khuyến mãi; hết hạn/huỷ chưa trả hoàn điểm đã dùng; huỷ/hoàn vé đã trả hoàn điểm đã dùng, thu hồi điểm đã tích và chi tiêu theo backend chung. Điện thoại không có màn điều chỉnh điểm thủ công. **MOB-FR-BOOK-17-AC-02** — Thử đầu vào sai/thiếu quyền/xung đột áp dụng và kiểm tra từ chối đã nêu, không đổi dữ liệu trái phép và không báo thành công sai. |
| Bằng chứng | [Cinema_BE/BookingService/BookingService/Controllers/BookingController.cs](../Cinema_BE/BookingService/BookingService/Controllers/BookingController.cs); [Cinema_BE/BookingService/BookingService/Controllers/LoyaltyController.cs](../Cinema_BE/BookingService/BookingService/Controllers/LoyaltyController.cs); [Cinema_Mobile/lib/features/booking/screens/booking_summary_screen.dart](../Cinema_Mobile/lib/features/booking/screens/booking_summary_screen.dart); [Cinema_Mobile/lib/features/booking/screens/booking_detail_screen.dart](../Cinema_Mobile/lib/features/booking/screens/booking_detail_screen.dart); [Cinema_Mobile/lib/features/profile/screens/profile_screen.dart](../Cinema_Mobile/lib/features/profile/screens/profile_screen.dart); [Cinema_BE/BookingService/BookingService/Services/Implementations/BookingService.cs](../Cinema_BE/BookingService/BookingService/Services/Implementations/BookingService.cs); [Cinema_BE/BookingService/BookingService/Helpers/PromotionRules.cs](../Cinema_BE/BookingService/BookingService/Helpers/PromotionRules.cs); [Cinema_BE/BookingService/BookingService/Helpers/LoyaltyRules.cs](../Cinema_BE/BookingService/BookingService/Helpers/LoyaltyRules.cs); [Cinema_BE/BookingService/BookingService/Services/Implementations/LoyaltyService.cs](../Cinema_BE/BookingService/BookingService/Services/Implementations/LoyaltyService.cs) |
| Quy tắc nghiệp vụ | MOB-BR-07, MOB-BR-08, MOB-BR-14, MOB-BR-15, MOB-BR-16, MOB-BR-17, MOB-BR-27, MOB-BR-28, MOB-BR-29 |
| Ca sử dụng / màn / API | UC-MOB-05; MOB-SCR-SUMMARY, MOB-SCR-TICKET, MOB-SCR-PROFILE; MOB-API-021, MOB-API-023 |

### MOB-FR-BOOK-19 — Chia sẻ và lịch

| Trường | Đặc tả |
| --- | --- |
| Tên | Chia sẻ và lịch |
| Mô tả | Vé đã thanh toán có nút **Share ticket** (chia sẻ tên phim, giờ chiếu, ghế và mã vé cho người đi cùng qua bảng chia sẻ của máy; trình duyệt không hỗ trợ thì chép vào clipboard) và **Add to calendar** (mở sự kiện Google Calendar theo giờ Việt Nam, kết thúc theo giờ kết thúc suất chiếu; chỉ hiện khi suất chưa chiếu). |
| Tác nhân | Khách hàng |
| Tiền điều kiện | Khách đã đăng nhập và sở hữu vé liên quan; thao tác phải được trạng thái và giờ vé cho phép. Quyền nhân viên chỉ áp dụng nơi đã nêu. |
| Kích hoạt | Thực hiện “Chia sẻ và lịch” hoặc sự kiện/tác vụ backend tương ứng. |
| Luồng chính | 1. Đọc đầu vào/tài nguyên hiện tại và phiên áp dụng. 2. Thực hiện thao tác này: Vé đã thanh toán có nút **Share ticket** (chia sẻ tên phim, giờ chiếu, ghế và mã vé cho người đi cùng qua bảng chia sẻ của máy; trình duyệt không hỗ trợ thì chép vào clipboard) và **Add to calendar** (mở sự kiện Google Calendar theo giờ Việt Nam, kết thúc theo giờ kết thúc suất chiếu; chỉ hiện khi suất chưa chiếu). 3. Trả/hiển thị kết quả chính thức và làm mới dữ liệu bị tác động sau thành công. |
| Luồng thay thế / ngoại lệ | Giữ chỗ đồng thời trả 409 và không được thu tiền hoặc để lại ghế/điểm dở dang. Bắp nước/mã/điểm sai trả lỗi kiểm tra. Hết hạn nhả ghế và trả điểm đã giữ. |
| Hậu điều kiện | Dữ liệu/trạng thái đủ quyền được trả/hiển thị; đọc không đổi trạng thái vé/thanh toán. Dấu đã đọc thông báo chỉ đổi bằng thao tác ghi riêng. |
| Ưu tiên | L |
| Tiêu chí nghiệm thu | **MOB-FR-BOOK-19-AC-01** — Với tiền điều kiện/kích hoạt, kiểm tra: Vé đã thanh toán có nút **Share ticket** (chia sẻ tên phim, giờ chiếu, ghế và mã vé cho người đi cùng qua bảng chia sẻ của máy; trình duyệt không hỗ trợ thì chép vào clipboard) và **Add to calendar** (mở sự kiện Google Calendar theo giờ Việt Nam, kết thúc theo giờ kết thúc suất chiếu; chỉ hiện khi suất chưa chiếu). **MOB-FR-BOOK-19-AC-02** — Thử đầu vào sai/thiếu quyền/xung đột áp dụng và kiểm tra từ chối đã nêu, không đổi dữ liệu trái phép và không báo thành công sai. |
| Bằng chứng | [Cinema_BE/MovieService/MovieService/Controllers/ShowtimesController.cs](../Cinema_BE/MovieService/MovieService/Controllers/ShowtimesController.cs); [Cinema_Mobile/lib/features/booking/screens/booking_detail_screen.dart](../Cinema_Mobile/lib/features/booking/screens/booking_detail_screen.dart); [Cinema_BE/BookingService/BookingService/Services/Implementations/BookingService.cs](../Cinema_BE/BookingService/BookingService/Services/Implementations/BookingService.cs); [Cinema_BE/BookingService/BookingService/Helpers/PromotionRules.cs](../Cinema_BE/BookingService/BookingService/Helpers/PromotionRules.cs); [Cinema_BE/BookingService/BookingService/Helpers/LoyaltyRules.cs](../Cinema_BE/BookingService/BookingService/Helpers/LoyaltyRules.cs) |
| Quy tắc nghiệp vụ | MOB-BR-07, MOB-BR-08, MOB-BR-14, MOB-BR-15, MOB-BR-16, MOB-BR-17, MOB-BR-27, MOB-BR-28, MOB-BR-29 |
| Ca sử dụng / màn / API | UC-MOB-05; MOB-SCR-TICKET; MOB-API-002 |

### MOB-FR-PAY-01 — Tạo/dùng lại link PayOS

| Trường | Đặc tả |
| --- | --- |
| Tên | Tạo/dùng lại link PayOS |
| Mô tả | Tạo link thanh toán PayOS cho booking `PENDING`. Mỗi booking một payment; gọi lại thì trả link cũ, không tạo thêm. Mã đơn PayOS = id booking × 1.000.000 + 6 số ngẫu nhiên cuối mã vé: cố định cho mỗi booking và không trùng với đơn của môi trường khác trên tài khoản PayOS dùng chung. Link hết hạn cùng lúc với thời gian giữ ghế. |
| Tác nhân | Khách hàng; PayOS/hệ thống là phụ thuộc ngoài/dùng chung |
| Tiền điều kiện | Có vé đủ điều kiện thanh toán; thông tin PayOS và callback/địa chỉ trở về được cấu hình để thanh toán thật. |
| Kích hoạt | Thực hiện “Tạo/dùng lại link PayOS” hoặc sự kiện/tác vụ backend tương ứng. |
| Luồng chính | 1. Đọc đầu vào/tài nguyên hiện tại và phiên áp dụng. 2. Thực hiện thao tác này: Tạo link thanh toán PayOS cho booking `PENDING`. Mỗi booking một payment; gọi lại thì trả link cũ, không tạo thêm. Mã đơn PayOS = id booking × 1.000.000 + 6 số ngẫu nhiên cuối mã vé: cố định cho mỗi booking và không trùng với đơn của môi trường khác trên tài khoản PayOS dùng chung. Link hết hạn cùng lúc với thời gian giữ ghế. 3. Trả/hiển thị kết quả chính thức và làm mới dữ liệu bị tác động sau thành công. |
| Luồng thay thế / ngoại lệ | Không dùng tham số chuyển hướng làm bằng chứng đã trả tiền. Xử lý huỷ, hết thời gian và 503 mà không báo thành công sai; trả muộn chỉ xác nhận nếu lấy lại được ghế, nếu không tạo hoàn tiền. |
| Hậu điều kiện | Kết quả thành công quan sát được khớp yêu cầu này; chuyển trạng thái được chỉ định được lưu. Từ chối không cấp quyền hoặc để thay đổi dở dang trái phép. |
| Ưu tiên | H |
| Tiêu chí nghiệm thu | **MOB-FR-PAY-01-AC-01** — Với tiền điều kiện/kích hoạt, kiểm tra: Tạo link thanh toán PayOS cho booking `PENDING`. Mỗi booking một payment; gọi lại thì trả link cũ, không tạo thêm. Mã đơn PayOS = id booking × 1.000.000 + 6 số ngẫu nhiên cuối mã vé: cố định cho mỗi booking và không trùng với đơn của môi trường khác trên tài khoản PayOS dùng chung. Link hết hạn cùng lúc với thời gian giữ ghế. **MOB-FR-PAY-01-AC-02** — Thử đầu vào sai/thiếu quyền/xung đột áp dụng và kiểm tra từ chối đã nêu, không đổi dữ liệu trái phép và không báo thành công sai. |
| Bằng chứng | [Cinema_BE/BookingService/BookingService/Controllers/PaymentController.cs](../Cinema_BE/BookingService/BookingService/Controllers/PaymentController.cs); [Cinema_Mobile/lib/features/payment/screens/payment_screen.dart](../Cinema_Mobile/lib/features/payment/screens/payment_screen.dart); [Cinema_BE/BookingService/BookingService/Services/Implementations/PaymentService.cs](../Cinema_BE/BookingService/BookingService/Services/Implementations/PaymentService.cs); [Cinema_BE/BookingService/BookingService/Helpers/PayOsSignature.cs](../Cinema_BE/BookingService/BookingService/Helpers/PayOsSignature.cs) |
| Quy tắc nghiệp vụ | MOB-BR-09, MOB-BR-10, MOB-BR-11, MOB-BR-12, MOB-BR-13, MOB-BR-14, MOB-BR-20 |
| Ca sử dụng / màn / API | UC-MOB-06; MOB-SCR-PAYMENT; MOB-API-035 |

### MOB-FR-PAY-02 — Xác minh PayOS

| Trường | Đặc tả |
| --- | --- |
| Tên | Xác minh PayOS |
| Mô tả | Xác minh thanh toán theo mã đơn (hoặc id booking): PayOS báo đã trả thì payment `SUCCESS` và booking `CONFIRMED`; khách huỷ trên trang PayOS thì payment `FAILED`, booking `CANCELLED` và nhả ghế ngay. Gọi lại nhiều lần vẫn an toàn. |
| Tác nhân | Khách hàng; PayOS/hệ thống là phụ thuộc ngoài/dùng chung |
| Tiền điều kiện | Có vé đủ điều kiện thanh toán; thông tin PayOS và callback/địa chỉ trở về được cấu hình để thanh toán thật. |
| Kích hoạt | Thực hiện “Xác minh PayOS” hoặc sự kiện/tác vụ backend tương ứng. |
| Luồng chính | 1. Đọc đầu vào/tài nguyên hiện tại và phiên áp dụng. 2. Thực hiện thao tác này: Xác minh thanh toán theo mã đơn (hoặc id booking): PayOS báo đã trả thì payment `SUCCESS` và booking `CONFIRMED`; khách huỷ trên trang PayOS thì payment `FAILED`, booking `CANCELLED` và nhả ghế ngay. Gọi lại nhiều lần vẫn an toàn. 3. Trả/hiển thị kết quả chính thức và làm mới dữ liệu bị tác động sau thành công. |
| Luồng thay thế / ngoại lệ | Không dùng tham số chuyển hướng làm bằng chứng đã trả tiền. Xử lý huỷ, hết thời gian và 503 mà không báo thành công sai; trả muộn chỉ xác nhận nếu lấy lại được ghế, nếu không tạo hoàn tiền. |
| Hậu điều kiện | Kết quả thành công quan sát được khớp yêu cầu này; chuyển trạng thái được chỉ định được lưu. Từ chối không cấp quyền hoặc để thay đổi dở dang trái phép. |
| Ưu tiên | H |
| Tiêu chí nghiệm thu | **MOB-FR-PAY-02-AC-01** — Với tiền điều kiện/kích hoạt, kiểm tra: Xác minh thanh toán theo mã đơn (hoặc id booking): PayOS báo đã trả thì payment `SUCCESS` và booking `CONFIRMED`; khách huỷ trên trang PayOS thì payment `FAILED`, booking `CANCELLED` và nhả ghế ngay. Gọi lại nhiều lần vẫn an toàn. **MOB-FR-PAY-02-AC-02** — Thử đầu vào sai/thiếu quyền/xung đột áp dụng và kiểm tra từ chối đã nêu, không đổi dữ liệu trái phép và không báo thành công sai. |
| Bằng chứng | [Cinema_BE/BookingService/BookingService/Controllers/PaymentController.cs](../Cinema_BE/BookingService/BookingService/Controllers/PaymentController.cs); [Cinema_Mobile/lib/features/payment/screens/payment_screen.dart](../Cinema_Mobile/lib/features/payment/screens/payment_screen.dart); [Cinema_Mobile/lib/features/payment/screens/payment_result_screen.dart](../Cinema_Mobile/lib/features/payment/screens/payment_result_screen.dart); [Cinema_BE/BookingService/BookingService/Services/Implementations/PaymentService.cs](../Cinema_BE/BookingService/BookingService/Services/Implementations/PaymentService.cs); [Cinema_BE/BookingService/BookingService/Helpers/PayOsSignature.cs](../Cinema_BE/BookingService/BookingService/Helpers/PayOsSignature.cs) |
| Quy tắc nghiệp vụ | MOB-BR-09, MOB-BR-10, MOB-BR-11, MOB-BR-12, MOB-BR-13, MOB-BR-14, MOB-BR-20 |
| Ca sử dụng / màn / API | UC-MOB-06; MOB-SCR-PAYMENT, MOB-SCR-RESULT; MOB-API-034 |

### MOB-FR-PAY-03 — Chi tiết thanh toán

| Trường | Đặc tả |
| --- | --- |
| Tên | Chi tiết thanh toán |
| Mô tả | Hiện tiền, phương thức và trạng thái thanh toán của chính khách trong lịch sử và ngữ cảnh vé liên quan; chưa có route chi tiết thanh toán điện thoại riêng hoặc luồng quản trị thanh toán. |
| Tác nhân | Khách hàng; PayOS/hệ thống là phụ thuộc ngoài/dùng chung |
| Tiền điều kiện | Có vé đủ điều kiện thanh toán; thông tin PayOS và callback/địa chỉ trở về được cấu hình để thanh toán thật. |
| Kích hoạt | Thực hiện “Chi tiết thanh toán” hoặc sự kiện/tác vụ backend tương ứng. |
| Luồng chính | 1. Đọc đầu vào/tài nguyên hiện tại và phiên áp dụng. 2. Thực hiện thao tác này: Hiện tiền, phương thức và trạng thái thanh toán của chính khách trong lịch sử và ngữ cảnh vé liên quan; chưa có route chi tiết thanh toán điện thoại riêng hoặc luồng quản trị thanh toán. 3. Trả/hiển thị kết quả chính thức và làm mới dữ liệu bị tác động sau thành công. |
| Luồng thay thế / ngoại lệ | Không dùng tham số chuyển hướng làm bằng chứng đã trả tiền. Xử lý huỷ, hết thời gian và 503 mà không báo thành công sai; trả muộn chỉ xác nhận nếu lấy lại được ghế, nếu không tạo hoàn tiền. |
| Hậu điều kiện | Dữ liệu/trạng thái đủ quyền được trả/hiển thị; đọc không đổi trạng thái vé/thanh toán. Dấu đã đọc thông báo chỉ đổi bằng thao tác ghi riêng. |
| Ưu tiên | H |
| Tiêu chí nghiệm thu | **MOB-FR-PAY-03-AC-01** — Với tiền điều kiện/kích hoạt, kiểm tra: Hiện tiền, phương thức và trạng thái thanh toán của chính khách trong lịch sử và ngữ cảnh vé liên quan; chưa có route chi tiết thanh toán điện thoại riêng hoặc luồng quản trị thanh toán. **MOB-FR-PAY-03-AC-02** — Thử đầu vào sai/thiếu quyền/xung đột áp dụng và kiểm tra từ chối đã nêu, không đổi dữ liệu trái phép và không báo thành công sai. |
| Bằng chứng | [Cinema_BE/BookingService/BookingService/Controllers/PaymentController.cs](../Cinema_BE/BookingService/BookingService/Controllers/PaymentController.cs); [Cinema_Mobile/lib/features/booking/screens/booking_detail_screen.dart](../Cinema_Mobile/lib/features/booking/screens/booking_detail_screen.dart); [Cinema_Mobile/lib/features/payment/screens/payment_history_screen.dart](../Cinema_Mobile/lib/features/payment/screens/payment_history_screen.dart); [Cinema_BE/BookingService/BookingService/Services/Implementations/PaymentService.cs](../Cinema_BE/BookingService/BookingService/Services/Implementations/PaymentService.cs); [Cinema_BE/BookingService/BookingService/Helpers/PayOsSignature.cs](../Cinema_BE/BookingService/BookingService/Helpers/PayOsSignature.cs) |
| Quy tắc nghiệp vụ | MOB-BR-09, MOB-BR-10, MOB-BR-11, MOB-BR-12, MOB-BR-13, MOB-BR-14, MOB-BR-20 |
| Ca sử dụng / màn / API | UC-MOB-06; MOB-SCR-TICKET, MOB-SCR-PAYHISTORY; MOB-API-037 |

### MOB-FR-PAY-04 — Lịch sử thanh toán của mình

| Trường | Đặc tả |
| --- | --- |
| Tên | Lịch sử thanh toán của mình |
| Mô tả | Khách xem lịch sử thanh toán của mình. |
| Tác nhân | Khách hàng; PayOS/hệ thống là phụ thuộc ngoài/dùng chung |
| Tiền điều kiện | Có vé đủ điều kiện thanh toán; thông tin PayOS và callback/địa chỉ trở về được cấu hình để thanh toán thật. |
| Kích hoạt | Thực hiện “Lịch sử thanh toán của mình” hoặc sự kiện/tác vụ backend tương ứng. |
| Luồng chính | 1. Đọc đầu vào/tài nguyên hiện tại và phiên áp dụng. 2. Thực hiện thao tác này: Khách xem lịch sử thanh toán của mình. 3. Trả/hiển thị kết quả chính thức và làm mới dữ liệu bị tác động sau thành công. |
| Luồng thay thế / ngoại lệ | Không dùng tham số chuyển hướng làm bằng chứng đã trả tiền. Xử lý huỷ, hết thời gian và 503 mà không báo thành công sai; trả muộn chỉ xác nhận nếu lấy lại được ghế, nếu không tạo hoàn tiền. |
| Hậu điều kiện | Dữ liệu/trạng thái đủ quyền được trả/hiển thị; đọc không đổi trạng thái vé/thanh toán. Dấu đã đọc thông báo chỉ đổi bằng thao tác ghi riêng. |
| Ưu tiên | M |
| Tiêu chí nghiệm thu | **MOB-FR-PAY-04-AC-01** — Với tiền điều kiện/kích hoạt, kiểm tra: Khách xem lịch sử thanh toán của mình. **MOB-FR-PAY-04-AC-02** — Thử đầu vào sai/thiếu quyền/xung đột áp dụng và kiểm tra từ chối đã nêu, không đổi dữ liệu trái phép và không báo thành công sai. |
| Bằng chứng | [Cinema_BE/BookingService/BookingService/Controllers/PaymentController.cs](../Cinema_BE/BookingService/BookingService/Controllers/PaymentController.cs); [Cinema_Mobile/lib/features/payment/screens/payment_history_screen.dart](../Cinema_Mobile/lib/features/payment/screens/payment_history_screen.dart); [Cinema_BE/BookingService/BookingService/Services/Implementations/PaymentService.cs](../Cinema_BE/BookingService/BookingService/Services/Implementations/PaymentService.cs); [Cinema_BE/BookingService/BookingService/Helpers/PayOsSignature.cs](../Cinema_BE/BookingService/BookingService/Helpers/PayOsSignature.cs) |
| Quy tắc nghiệp vụ | MOB-BR-09, MOB-BR-10, MOB-BR-11, MOB-BR-12, MOB-BR-13, MOB-BR-14, MOB-BR-20 |
| Ca sử dụng / màn / API | UC-MOB-06; MOB-SCR-PAYHISTORY; MOB-API-037 |

### MOB-FR-PAY-06 — Truy cập hoàn tiền

| Trường | Đặc tả |
| --- | --- |
| Tên | Truy cập hoàn tiền |
| Mô tả | Khách yêu cầu hoàn tiền qua huỷ vé đã trả đủ điều kiện và xem kết quả/lý do từ chối. Duyệt, từ chối và ghi nhận chuyển khoản thuộc không gian web, không thuộc ứng dụng điện thoại. |
| Tác nhân | Khách hàng; PayOS/hệ thống là phụ thuộc ngoài/dùng chung |
| Tiền điều kiện | Có vé đủ điều kiện thanh toán; thông tin PayOS và callback/địa chỉ trở về được cấu hình để thanh toán thật. |
| Kích hoạt | Thực hiện “Truy cập hoàn tiền” hoặc sự kiện/tác vụ backend tương ứng. |
| Luồng chính | 1. Đọc đầu vào/tài nguyên hiện tại và phiên áp dụng. 2. Thực hiện thao tác này: Khách yêu cầu hoàn tiền qua huỷ vé đã trả đủ điều kiện và xem kết quả/lý do từ chối. Duyệt, từ chối và ghi nhận chuyển khoản thuộc không gian web, không thuộc ứng dụng điện thoại. 3. Trả/hiển thị kết quả chính thức và làm mới dữ liệu bị tác động sau thành công. |
| Luồng thay thế / ngoại lệ | Không dùng tham số chuyển hướng làm bằng chứng đã trả tiền. Xử lý huỷ, hết thời gian và 503 mà không báo thành công sai; trả muộn chỉ xác nhận nếu lấy lại được ghế, nếu không tạo hoàn tiền. |
| Hậu điều kiện | Kết quả thành công quan sát được khớp yêu cầu này; chuyển trạng thái được chỉ định được lưu. Từ chối không cấp quyền hoặc để thay đổi dở dang trái phép. |
| Ưu tiên | H |
| Tiêu chí nghiệm thu | **MOB-FR-PAY-06-AC-01** — Với tiền điều kiện/kích hoạt, kiểm tra: Khách yêu cầu hoàn tiền qua huỷ vé đã trả đủ điều kiện và xem kết quả/lý do từ chối. Duyệt, từ chối và ghi nhận chuyển khoản thuộc không gian web, không thuộc ứng dụng điện thoại. **MOB-FR-PAY-06-AC-02** — Thử đầu vào sai/thiếu quyền/xung đột áp dụng và kiểm tra từ chối đã nêu, không đổi dữ liệu trái phép và không báo thành công sai. |
| Bằng chứng | [Cinema_BE/BookingService/BookingService/Controllers/BookingController.cs](../Cinema_BE/BookingService/BookingService/Controllers/BookingController.cs); [Cinema_BE/BookingService/BookingService/Controllers/PaymentController.cs](../Cinema_BE/BookingService/BookingService/Controllers/PaymentController.cs); [Cinema_Mobile/lib/features/booking/screens/booking_detail_screen.dart](../Cinema_Mobile/lib/features/booking/screens/booking_detail_screen.dart); [Cinema_BE/BookingService/BookingService/Services/Implementations/PaymentService.cs](../Cinema_BE/BookingService/BookingService/Services/Implementations/PaymentService.cs); [Cinema_BE/BookingService/BookingService/Helpers/PayOsSignature.cs](../Cinema_BE/BookingService/BookingService/Helpers/PayOsSignature.cs) |
| Quy tắc nghiệp vụ | MOB-BR-09, MOB-BR-10, MOB-BR-11, MOB-BR-12, MOB-BR-13, MOB-BR-14, MOB-BR-20 |
| Ca sử dụng / màn / API | UC-MOB-06; MOB-SCR-TICKET; MOB-API-015, MOB-API-033 |

### MOB-FR-PAY-07 — Webhook có chữ ký

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
| Tiêu chí nghiệm thu | **MOB-FR-PAY-07-AC-01** — Với tiền điều kiện/kích hoạt, kiểm tra: Nhận webhook PayOS: kiểm tra chữ ký HMAC-SHA256 (sai thì 400); đơn không tồn tại hoặc sai số tiền thì 200 và bỏ qua; webhook lặp không xác nhận hay gửi email lần hai. Lưu tài khoản người trả (số tài khoản, tên, ngân hàng) để hoàn tiền. **MOB-FR-PAY-07-AC-02** — Thử đầu vào sai/thiếu quyền/xung đột áp dụng và kiểm tra từ chối đã nêu, không đổi dữ liệu trái phép và không báo thành công sai. |
| Bằng chứng | [Cinema_BE/BookingService/BookingService/Controllers/PaymentController.cs](../Cinema_BE/BookingService/BookingService/Controllers/PaymentController.cs); [Cinema_BE/BookingService/BookingService/Services/Implementations/PaymentService.cs](../Cinema_BE/BookingService/BookingService/Services/Implementations/PaymentService.cs); [Cinema_BE/BookingService/BookingService/Helpers/PayOsSignature.cs](../Cinema_BE/BookingService/BookingService/Helpers/PayOsSignature.cs) |
| Quy tắc nghiệp vụ | MOB-BR-09, MOB-BR-10, MOB-BR-11, MOB-BR-12, MOB-BR-13, MOB-BR-14, MOB-BR-20 |
| Ca sử dụng / màn / API | UC-MOB-06; ; MOB-API-036 |

### MOB-FR-PAY-08 — Thanh toán muộn

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
| Tiêu chí nghiệm thu | **MOB-FR-PAY-08-AC-01** — Với tiền điều kiện/kích hoạt, kiểm tra: Khi PayOS báo đã trả sau khi hết hạn giữ ghế, chỉ xác nhận vé nếu lấy lại được toàn bộ ghế; nếu không tạo yêu cầu hoàn toàn bộ tiền. Xác minh/webhook lặp không được lặp tác động tài chính. **MOB-FR-PAY-08-AC-02** — Thử đầu vào sai/thiếu quyền/xung đột áp dụng và kiểm tra từ chối đã nêu, không đổi dữ liệu trái phép và không báo thành công sai. |
| Bằng chứng | [Cinema_BE/BookingService/BookingService/Controllers/PaymentController.cs](../Cinema_BE/BookingService/BookingService/Controllers/PaymentController.cs); [Cinema_Mobile/lib/features/payment/screens/payment_result_screen.dart](../Cinema_Mobile/lib/features/payment/screens/payment_result_screen.dart); [Cinema_BE/BookingService/BookingService/Services/Implementations/PaymentService.cs](../Cinema_BE/BookingService/BookingService/Services/Implementations/PaymentService.cs); [Cinema_BE/BookingService/BookingService/Helpers/PayOsSignature.cs](../Cinema_BE/BookingService/BookingService/Helpers/PayOsSignature.cs) |
| Quy tắc nghiệp vụ | MOB-BR-09, MOB-BR-10, MOB-BR-11, MOB-BR-12, MOB-BR-13, MOB-BR-14, MOB-BR-20 |
| Ca sử dụng / màn / API | UC-MOB-06; MOB-SCR-RESULT; MOB-API-034, MOB-API-036 |

### MOB-FR-PAY-11 — Tự kiểm tra thanh toán

| Trường | Đặc tả |
| --- | --- |
| Tên | Tự kiểm tra thanh toán |
| Mô tả | Trang thanh toán của app tự kiểm tra booking mỗi 5 giây và hỏi PayOS mỗi 30 giây khi đang mở; không có nút "Tôi đã trả tiền". |
| Tác nhân | Khách hàng; PayOS/hệ thống là phụ thuộc ngoài/dùng chung |
| Tiền điều kiện | Có vé đủ điều kiện thanh toán; thông tin PayOS và callback/địa chỉ trở về được cấu hình để thanh toán thật. |
| Kích hoạt | Thực hiện “Tự kiểm tra thanh toán” hoặc sự kiện/tác vụ backend tương ứng. |
| Luồng chính | 1. Đọc đầu vào/tài nguyên hiện tại và phiên áp dụng. 2. Thực hiện thao tác này: Trang thanh toán của app tự kiểm tra booking mỗi 5 giây và hỏi PayOS mỗi 30 giây khi đang mở; không có nút "Tôi đã trả tiền". 3. Trả/hiển thị kết quả chính thức và làm mới dữ liệu bị tác động sau thành công. |
| Luồng thay thế / ngoại lệ | Không dùng tham số chuyển hướng làm bằng chứng đã trả tiền. Xử lý huỷ, hết thời gian và 503 mà không báo thành công sai; trả muộn chỉ xác nhận nếu lấy lại được ghế, nếu không tạo hoàn tiền. |
| Hậu điều kiện | Kết quả thành công quan sát được khớp yêu cầu này; chuyển trạng thái được chỉ định được lưu. Từ chối không cấp quyền hoặc để thay đổi dở dang trái phép. |
| Ưu tiên | M |
| Tiêu chí nghiệm thu | **MOB-FR-PAY-11-AC-01** — Với tiền điều kiện/kích hoạt, kiểm tra: Trang thanh toán của app tự kiểm tra booking mỗi 5 giây và hỏi PayOS mỗi 30 giây khi đang mở; không có nút "Tôi đã trả tiền". **MOB-FR-PAY-11-AC-02** — Thử đầu vào sai/thiếu quyền/xung đột áp dụng và kiểm tra từ chối đã nêu, không đổi dữ liệu trái phép và không báo thành công sai. |
| Bằng chứng | [Cinema_BE/BookingService/BookingService/Controllers/BookingController.cs](../Cinema_BE/BookingService/BookingService/Controllers/BookingController.cs); [Cinema_BE/BookingService/BookingService/Controllers/PaymentController.cs](../Cinema_BE/BookingService/BookingService/Controllers/PaymentController.cs); [Cinema_Mobile/lib/features/payment/screens/payment_screen.dart](../Cinema_Mobile/lib/features/payment/screens/payment_screen.dart); [Cinema_BE/BookingService/BookingService/Services/Implementations/PaymentService.cs](../Cinema_BE/BookingService/BookingService/Services/Implementations/PaymentService.cs); [Cinema_BE/BookingService/BookingService/Helpers/PayOsSignature.cs](../Cinema_BE/BookingService/BookingService/Helpers/PayOsSignature.cs) |
| Quy tắc nghiệp vụ | MOB-BR-09, MOB-BR-10, MOB-BR-11, MOB-BR-12, MOB-BR-13, MOB-BR-14, MOB-BR-20 |
| Ca sử dụng / màn / API | UC-MOB-06; MOB-SCR-PAYMENT; MOB-API-017, MOB-API-034 |

### MOB-FR-REF-01 — Tạo yêu cầu hoàn tiền

| Trường | Đặc tả |
| --- | --- |
| Tên | Tạo yêu cầu hoàn tiền |
| Mô tả | Backend chung tạo một yêu cầu PENDING và đặt thanh toán REFUND_PENDING khi khách huỷ đủ điều kiện, rạp huỷ hoặc trả muộn không lấy lại ghế. Khách trên điện thoại xem yêu cầu và thông báo; điện thoại không khởi tạo hoàn tiền quản trị. |
| Tác nhân | Khách hàng |
| Tiền điều kiện | Có sự kiện đã commit, kết quả PayOS tin cậy hoặc điều kiện tác vụ tương ứng; backend đã cấu hình xử lý. Tác vụ nền hoặc webhook chữ ký không cần phiên khách. |
| Kích hoạt | Thực hiện “Tạo yêu cầu hoàn tiền” hoặc sự kiện/tác vụ backend tương ứng. |
| Luồng chính | 1. Đọc đầu vào/tài nguyên hiện tại và phiên áp dụng. 2. Thực hiện thao tác này: Backend chung tạo một yêu cầu PENDING và đặt thanh toán REFUND_PENDING khi khách huỷ đủ điều kiện, rạp huỷ hoặc trả muộn không lấy lại ghế. Khách trên điện thoại xem yêu cầu và thông báo; điện thoại không khởi tạo hoàn tiền quản trị. 3. Trả/hiển thị kết quả chính thức và làm mới dữ liệu bị tác động sau thành công. |
| Luồng thay thế / ngoại lệ | Huỷ trong hai giờ bị từ chối bằng 409. Hiện trạng thái hoàn tiền/từ chối từ backend; điện thoại không có thao tác duyệt/từ chối/ghi chuyển tiền. |
| Hậu điều kiện | Kết quả thành công quan sát được khớp yêu cầu này; chuyển trạng thái được chỉ định được lưu. Từ chối không cấp quyền hoặc để thay đổi dở dang trái phép. |
| Ưu tiên | H |
| Tiêu chí nghiệm thu | **MOB-FR-REF-01-AC-01** — Với tiền điều kiện/kích hoạt, kiểm tra: Backend chung tạo một yêu cầu PENDING và đặt thanh toán REFUND_PENDING khi khách huỷ đủ điều kiện, rạp huỷ hoặc trả muộn không lấy lại ghế. Khách trên điện thoại xem yêu cầu và thông báo; điện thoại không khởi tạo hoàn tiền quản trị. **MOB-FR-REF-01-AC-02** — Thử đầu vào sai/thiếu quyền/xung đột áp dụng và kiểm tra từ chối đã nêu, không đổi dữ liệu trái phép và không báo thành công sai. |
| Bằng chứng | [Cinema_BE/BookingService/BookingService/Controllers/BookingController.cs](../Cinema_BE/BookingService/BookingService/Controllers/BookingController.cs); [Cinema_BE/BookingService/BookingService/Controllers/PaymentController.cs](../Cinema_BE/BookingService/BookingService/Controllers/PaymentController.cs); [Cinema_Mobile/lib/features/booking/screens/booking_detail_screen.dart](../Cinema_Mobile/lib/features/booking/screens/booking_detail_screen.dart); [Cinema_BE/BookingService/BookingService/Services/Implementations/RefundService.cs](../Cinema_BE/BookingService/BookingService/Services/Implementations/RefundService.cs); [Cinema_BE/BookingService/BookingService/Services/Implementations/BookingService.cs](../Cinema_BE/BookingService/BookingService/Services/Implementations/BookingService.cs) |
| Quy tắc nghiệp vụ | MOB-BR-17, MOB-BR-18, MOB-BR-19, MOB-BR-20 |
| Ca sử dụng / màn / API | UC-MOB-07; MOB-SCR-TICKET; MOB-API-015, MOB-API-036 |

### MOB-FR-REF-05 — Mở lại hoàn tiền đã từ chối

| Trường | Đặc tả |
| --- | --- |
| Tên | Mở lại hoàn tiền đã từ chối |
| Mô tả | Yêu cầu đã bị từ chối được mở lại khi rạp huỷ vé hoặc suất chiếu sau đó. |
| Tác nhân | Hệ thống backend chung; khách nhận kết quả |
| Tiền điều kiện | Có sự kiện đã commit, kết quả PayOS tin cậy hoặc điều kiện tác vụ tương ứng; backend đã cấu hình xử lý. Tác vụ nền hoặc webhook chữ ký không cần phiên khách. |
| Kích hoạt | Thực hiện “Mở lại hoàn tiền đã từ chối” hoặc sự kiện/tác vụ backend tương ứng. |
| Luồng chính | 1. Đọc đầu vào/tài nguyên hiện tại và phiên áp dụng. 2. Thực hiện thao tác này: Yêu cầu đã bị từ chối được mở lại khi rạp huỷ vé hoặc suất chiếu sau đó. 3. Trả/hiển thị kết quả chính thức và làm mới dữ liệu bị tác động sau thành công. |
| Luồng thay thế / ngoại lệ | Huỷ trong hai giờ bị từ chối bằng 409. Hiện trạng thái hoàn tiền/từ chối từ backend; điện thoại không có thao tác duyệt/từ chối/ghi chuyển tiền. |
| Hậu điều kiện | Kết quả thành công quan sát được khớp yêu cầu này; chuyển trạng thái được chỉ định được lưu. Từ chối không cấp quyền hoặc để thay đổi dở dang trái phép. |
| Ưu tiên | M |
| Tiêu chí nghiệm thu | **MOB-FR-REF-05-AC-01** — Với tiền điều kiện/kích hoạt, kiểm tra: Yêu cầu đã bị từ chối được mở lại khi rạp huỷ vé hoặc suất chiếu sau đó. **MOB-FR-REF-05-AC-02** — Thử đầu vào sai/thiếu quyền/xung đột áp dụng và kiểm tra từ chối đã nêu, không đổi dữ liệu trái phép và không báo thành công sai. |
| Bằng chứng | [Cinema_BE/BookingService/BookingService/Controllers/BookingController.cs](../Cinema_BE/BookingService/BookingService/Controllers/BookingController.cs); [Cinema_Mobile/lib/features/booking/screens/booking_detail_screen.dart](../Cinema_Mobile/lib/features/booking/screens/booking_detail_screen.dart); [Cinema_BE/BookingService/BookingService/Services/Implementations/RefundService.cs](../Cinema_BE/BookingService/BookingService/Services/Implementations/RefundService.cs); [Cinema_BE/BookingService/BookingService/Services/Implementations/BookingService.cs](../Cinema_BE/BookingService/BookingService/Services/Implementations/BookingService.cs) |
| Quy tắc nghiệp vụ | MOB-BR-17, MOB-BR-18, MOB-BR-19, MOB-BR-20 |
| Ca sử dụng / màn / API | UC-MOB-07; MOB-SCR-TICKET; MOB-API-015 |

### MOB-FR-REF-06 — Trạng thái hoàn tiền của mình

| Trường | Đặc tả |
| --- | --- |
| Tên | Trạng thái hoàn tiền của mình |
| Mô tả | Khách xem trạng thái hoàn tiền của vé. |
| Tác nhân | Khách hàng |
| Tiền điều kiện | Có vé của chính khách; huỷ vé đã trả phải còn ít nhất hai giờ trước suất. |
| Kích hoạt | Thực hiện “Trạng thái hoàn tiền của mình” hoặc sự kiện/tác vụ backend tương ứng. |
| Luồng chính | 1. Đọc đầu vào/tài nguyên hiện tại và phiên áp dụng. 2. Thực hiện thao tác này: Khách xem trạng thái hoàn tiền của vé. 3. Trả/hiển thị kết quả chính thức và làm mới dữ liệu bị tác động sau thành công. |
| Luồng thay thế / ngoại lệ | Huỷ trong hai giờ bị từ chối bằng 409. Hiện trạng thái hoàn tiền/từ chối từ backend; điện thoại không có thao tác duyệt/từ chối/ghi chuyển tiền. |
| Hậu điều kiện | Dữ liệu/trạng thái đủ quyền được trả/hiển thị; đọc không đổi trạng thái vé/thanh toán. Dấu đã đọc thông báo chỉ đổi bằng thao tác ghi riêng. |
| Ưu tiên | M |
| Tiêu chí nghiệm thu | **MOB-FR-REF-06-AC-01** — Với tiền điều kiện/kích hoạt, kiểm tra: Khách xem trạng thái hoàn tiền của vé. **MOB-FR-REF-06-AC-02** — Thử đầu vào sai/thiếu quyền/xung đột áp dụng và kiểm tra từ chối đã nêu, không đổi dữ liệu trái phép và không báo thành công sai. |
| Bằng chứng | [Cinema_BE/BookingService/BookingService/Controllers/PaymentController.cs](../Cinema_BE/BookingService/BookingService/Controllers/PaymentController.cs); [Cinema_Mobile/lib/features/booking/screens/booking_detail_screen.dart](../Cinema_Mobile/lib/features/booking/screens/booking_detail_screen.dart); [Cinema_BE/BookingService/BookingService/Services/Implementations/RefundService.cs](../Cinema_BE/BookingService/BookingService/Services/Implementations/RefundService.cs); [Cinema_BE/BookingService/BookingService/Services/Implementations/BookingService.cs](../Cinema_BE/BookingService/BookingService/Services/Implementations/BookingService.cs) |
| Quy tắc nghiệp vụ | MOB-BR-17, MOB-BR-18, MOB-BR-19, MOB-BR-20 |
| Ca sử dụng / màn / API | UC-MOB-07; MOB-SCR-TICKET; MOB-API-033 |

### MOB-FR-REF-07 — Một hoàn tiền mỗi thanh toán

| Trường | Đặc tả |
| --- | --- |
| Tên | Một hoàn tiền mỗi thanh toán |
| Mô tả | Mỗi payment chỉ có một yêu cầu hoàn tiền, kể cả khi event bị giao lại. |
| Tác nhân | Hệ thống backend chung; khách nhận kết quả |
| Tiền điều kiện | Có sự kiện đã commit, kết quả PayOS tin cậy hoặc điều kiện tác vụ tương ứng; backend đã cấu hình xử lý. Tác vụ nền hoặc webhook chữ ký không cần phiên khách. |
| Kích hoạt | Thực hiện “Một hoàn tiền mỗi thanh toán” hoặc sự kiện/tác vụ backend tương ứng. |
| Luồng chính | 1. Đọc đầu vào/tài nguyên hiện tại và phiên áp dụng. 2. Thực hiện thao tác này: Mỗi payment chỉ có một yêu cầu hoàn tiền, kể cả khi event bị giao lại. 3. Trả/hiển thị kết quả chính thức và làm mới dữ liệu bị tác động sau thành công. |
| Luồng thay thế / ngoại lệ | Huỷ trong hai giờ bị từ chối bằng 409. Hiện trạng thái hoàn tiền/từ chối từ backend; điện thoại không có thao tác duyệt/từ chối/ghi chuyển tiền. |
| Hậu điều kiện | Kết quả thành công quan sát được khớp yêu cầu này; chuyển trạng thái được chỉ định được lưu. Từ chối không cấp quyền hoặc để thay đổi dở dang trái phép. |
| Ưu tiên | H |
| Tiêu chí nghiệm thu | **MOB-FR-REF-07-AC-01** — Với tiền điều kiện/kích hoạt, kiểm tra: Mỗi payment chỉ có một yêu cầu hoàn tiền, kể cả khi event bị giao lại. **MOB-FR-REF-07-AC-02** — Thử đầu vào sai/thiếu quyền/xung đột áp dụng và kiểm tra từ chối đã nêu, không đổi dữ liệu trái phép và không báo thành công sai. |
| Bằng chứng | [Cinema_BE/BookingService/BookingService/Controllers/BookingController.cs](../Cinema_BE/BookingService/BookingService/Controllers/BookingController.cs); [Cinema_BE/BookingService/BookingService/Controllers/PaymentController.cs](../Cinema_BE/BookingService/BookingService/Controllers/PaymentController.cs); [Cinema_BE/BookingService/BookingService/Services/Implementations/RefundService.cs](../Cinema_BE/BookingService/BookingService/Services/Implementations/RefundService.cs); [Cinema_BE/BookingService/BookingService/Services/Implementations/BookingService.cs](../Cinema_BE/BookingService/BookingService/Services/Implementations/BookingService.cs) |
| Quy tắc nghiệp vụ | MOB-BR-17, MOB-BR-18, MOB-BR-19, MOB-BR-20 |
| Ca sử dụng / màn / API | UC-MOB-07; ; MOB-API-015, MOB-API-033 |

### MOB-FR-CHK-01 — QR vé

| Trường | Đặc tả |
| --- | --- |
| Tên | QR vé |
| Mô tả | Hiện vé khách đã trả với QR chứa mã vé để nhân viên tra cứu; email xác nhận là đầu ra backend chung. |
| Tác nhân | Khách hàng |
| Tiền điều kiện | Nhân viên/quản trị viên đã đăng nhập; vé CONFIRMED, chưa dùng và trong khoảng 180 phút trước đến 120 phút sau giờ bắt đầu. |
| Kích hoạt | Thực hiện “QR vé” hoặc sự kiện/tác vụ backend tương ứng. |
| Luồng chính | 1. Đọc đầu vào/tài nguyên hiện tại và phiên áp dụng. 2. Thực hiện thao tác này: Hiện vé khách đã trả với QR chứa mã vé để nhân viên tra cứu; email xác nhận là đầu ra backend chung. 3. Trả/hiển thị kết quả chính thức và làm mới dữ liệu bị tác động sau thành công. |
| Luồng thay thế / ngoại lệ | Cho nhập tay khi camera không có/bị từ chối. Mã không tồn tại trả 404; vé chưa trả, đã huỷ, chờ hoàn tiền, ngoài khung giờ hoặc đã dùng trả 409. Lần check-in thứ hai đồng thời thất bại. Lỗi thông tin bổ sung không được che vé. |
| Hậu điều kiện | Dữ liệu/trạng thái đủ quyền được trả/hiển thị; đọc không đổi trạng thái vé/thanh toán. Dấu đã đọc thông báo chỉ đổi bằng thao tác ghi riêng. |
| Ưu tiên | H |
| Tiêu chí nghiệm thu | **MOB-FR-CHK-01-AC-01** — Với tiền điều kiện/kích hoạt, kiểm tra: Hiện vé khách đã trả với QR chứa mã vé để nhân viên tra cứu; email xác nhận là đầu ra backend chung. **MOB-FR-CHK-01-AC-02** — Thử đầu vào sai/thiếu quyền/xung đột áp dụng và kiểm tra từ chối đã nêu, không đổi dữ liệu trái phép và không báo thành công sai. |
| Bằng chứng | [Cinema_BE/BookingService/BookingService/Controllers/BookingController.cs](../Cinema_BE/BookingService/BookingService/Controllers/BookingController.cs); [Cinema_Mobile/lib/features/booking/screens/booking_detail_screen.dart](../Cinema_Mobile/lib/features/booking/screens/booking_detail_screen.dart); [Cinema_BE/BookingService/BookingService/Services/Implementations/BookingService.cs](../Cinema_BE/BookingService/BookingService/Services/Implementations/BookingService.cs); [Cinema_BE/BookingService/BookingService/Configuration/CheckInOptions.cs](../Cinema_BE/BookingService/BookingService/Configuration/CheckInOptions.cs) |
| Quy tắc nghiệp vụ | MOB-BR-21 |
| Ca sử dụng / màn / API | UC-MOB-08; MOB-SCR-TICKET; MOB-API-017 |

### MOB-FR-CHK-02 — Tra mã vé

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
| Tiêu chí nghiệm thu | **MOB-FR-CHK-02-AC-01** — Với tiền điều kiện/kích hoạt, kiểm tra: Staff/Admin tra vé theo mã (không phân biệt hoa thường): phim, giờ, phòng, ghế, tổng tiền, trạng thái. **MOB-FR-CHK-02-AC-02** — Thử đầu vào sai/thiếu quyền/xung đột áp dụng và kiểm tra từ chối đã nêu, không đổi dữ liệu trái phép và không báo thành công sai. |
| Bằng chứng | [Cinema_BE/BookingService/BookingService/Controllers/BookingController.cs](../Cinema_BE/BookingService/BookingService/Controllers/BookingController.cs); [Cinema_Mobile/lib/features/staff/screens/staff_check_in_screen.dart](../Cinema_Mobile/lib/features/staff/screens/staff_check_in_screen.dart); [Cinema_BE/BookingService/BookingService/Services/Implementations/BookingService.cs](../Cinema_BE/BookingService/BookingService/Services/Implementations/BookingService.cs); [Cinema_BE/BookingService/BookingService/Configuration/CheckInOptions.cs](../Cinema_BE/BookingService/BookingService/Configuration/CheckInOptions.cs) |
| Quy tắc nghiệp vụ | MOB-BR-21 |
| Ca sử dụng / màn / API | UC-MOB-08; MOB-SCR-CHECKIN; MOB-API-018 |

### MOB-FR-CHK-03 — Kiểm tra check-in

| Trường | Đặc tả |
| --- | --- |
| Tên | Kiểm tra check-in |
| Mô tả | Check-in theo MOB-BR-21; không hợp lệ thì 409 kèm lý do (chưa thanh toán, đã huỷ, chờ hoàn tiền, chưa tới giờ, quá giờ, đã check-in lúc mấy giờ). Hai quầy quét cùng lúc thì quầy sau nhận 409. |
| Tác nhân | Nhân viên/quản trị viên |
| Tiền điều kiện | Nhân viên/quản trị viên đã đăng nhập; vé CONFIRMED, chưa dùng và trong khoảng 180 phút trước đến 120 phút sau giờ bắt đầu. |
| Kích hoạt | Thực hiện “Kiểm tra check-in” hoặc sự kiện/tác vụ backend tương ứng. |
| Luồng chính | 1. Đọc đầu vào/tài nguyên hiện tại và phiên áp dụng. 2. Thực hiện thao tác này: Check-in theo MOB-BR-21; không hợp lệ thì 409 kèm lý do (chưa thanh toán, đã huỷ, chờ hoàn tiền, chưa tới giờ, quá giờ, đã check-in lúc mấy giờ). Hai quầy quét cùng lúc thì quầy sau nhận 409. 3. Trả/hiển thị kết quả chính thức và làm mới dữ liệu bị tác động sau thành công. |
| Luồng thay thế / ngoại lệ | Cho nhập tay khi camera không có/bị từ chối. Mã không tồn tại trả 404; vé chưa trả, đã huỷ, chờ hoàn tiền, ngoài khung giờ hoặc đã dùng trả 409. Lần check-in thứ hai đồng thời thất bại. Lỗi thông tin bổ sung không được che vé. |
| Hậu điều kiện | Chỉ lưu một thời điểm check-in; check-in là thuộc tính, không phải trạng thái vé khác. |
| Ưu tiên | H |
| Tiêu chí nghiệm thu | **MOB-FR-CHK-03-AC-01** — Với tiền điều kiện/kích hoạt, kiểm tra: Check-in theo MOB-BR-21; không hợp lệ thì 409 kèm lý do (chưa thanh toán, đã huỷ, chờ hoàn tiền, chưa tới giờ, quá giờ, đã check-in lúc mấy giờ). Hai quầy quét cùng lúc thì quầy sau nhận 409. **MOB-FR-CHK-03-AC-02** — Thử đầu vào sai/thiếu quyền/xung đột áp dụng và kiểm tra từ chối đã nêu, không đổi dữ liệu trái phép và không báo thành công sai. |
| Bằng chứng | [Cinema_BE/BookingService/BookingService/Controllers/BookingController.cs](../Cinema_BE/BookingService/BookingService/Controllers/BookingController.cs); [Cinema_Mobile/lib/features/staff/screens/staff_check_in_screen.dart](../Cinema_Mobile/lib/features/staff/screens/staff_check_in_screen.dart); [Cinema_BE/BookingService/BookingService/Services/Implementations/BookingService.cs](../Cinema_BE/BookingService/BookingService/Services/Implementations/BookingService.cs); [Cinema_BE/BookingService/BookingService/Configuration/CheckInOptions.cs](../Cinema_BE/BookingService/BookingService/Configuration/CheckInOptions.cs) |
| Quy tắc nghiệp vụ | MOB-BR-21 |
| Ca sử dụng / màn / API | UC-MOB-08; MOB-SCR-CHECKIN; MOB-API-016 |

### MOB-FR-CHK-04 — Camera/nhập mã

| Trường | Đặc tả |
| --- | --- |
| Tên | Camera/nhập mã |
| Mô tả | Nhân viên/quản trị viên quét QR bằng camera điện thoại hoặc nhập/dán mã rồi gửi. Khi camera bị từ chối/không có, vẫn tra mã thủ công được. Chức năng này không mở các màn quầy hoặc quản trị web. |
| Tác nhân | Nhân viên/quản trị viên |
| Tiền điều kiện | Nhân viên/quản trị viên đã đăng nhập; vé CONFIRMED, chưa dùng và trong khoảng 180 phút trước đến 120 phút sau giờ bắt đầu. |
| Kích hoạt | Thực hiện “Camera/nhập mã” hoặc sự kiện/tác vụ backend tương ứng. |
| Luồng chính | 1. Đọc đầu vào/tài nguyên hiện tại và phiên áp dụng. 2. Thực hiện thao tác này: Nhân viên/quản trị viên quét QR bằng camera điện thoại hoặc nhập/dán mã rồi gửi. Khi camera bị từ chối/không có, vẫn tra mã thủ công được. Chức năng này không mở các màn quầy hoặc quản trị web. 3. Trả/hiển thị kết quả chính thức và làm mới dữ liệu bị tác động sau thành công. |
| Luồng thay thế / ngoại lệ | Cho nhập tay khi camera không có/bị từ chối. Mã không tồn tại trả 404; vé chưa trả, đã huỷ, chờ hoàn tiền, ngoài khung giờ hoặc đã dùng trả 409. Lần check-in thứ hai đồng thời thất bại. Lỗi thông tin bổ sung không được che vé. |
| Hậu điều kiện | Chỉ lưu một thời điểm check-in; check-in là thuộc tính, không phải trạng thái vé khác. |
| Ưu tiên | H |
| Tiêu chí nghiệm thu | **MOB-FR-CHK-04-AC-01** — Với tiền điều kiện/kích hoạt, kiểm tra: Nhân viên/quản trị viên quét QR bằng camera điện thoại hoặc nhập/dán mã rồi gửi. Khi camera bị từ chối/không có, vẫn tra mã thủ công được. Chức năng này không mở các màn quầy hoặc quản trị web. **MOB-FR-CHK-04-AC-02** — Thử đầu vào sai/thiếu quyền/xung đột áp dụng và kiểm tra từ chối đã nêu, không đổi dữ liệu trái phép và không báo thành công sai. |
| Bằng chứng | [Cinema_BE/BookingService/BookingService/Controllers/BookingController.cs](../Cinema_BE/BookingService/BookingService/Controllers/BookingController.cs); [Cinema_Mobile/lib/features/profile/screens/management_account_screen.dart](../Cinema_Mobile/lib/features/profile/screens/management_account_screen.dart); [Cinema_Mobile/lib/features/staff/screens/staff_check_in_screen.dart](../Cinema_Mobile/lib/features/staff/screens/staff_check_in_screen.dart); [Cinema_BE/BookingService/BookingService/Services/Implementations/BookingService.cs](../Cinema_BE/BookingService/BookingService/Services/Implementations/BookingService.cs); [Cinema_BE/BookingService/BookingService/Configuration/CheckInOptions.cs](../Cinema_BE/BookingService/BookingService/Configuration/CheckInOptions.cs) |
| Quy tắc nghiệp vụ | MOB-BR-21 |
| Ca sử dụng / màn / API | UC-MOB-08; MOB-SCR-MGT-LANDING, MOB-SCR-CHECKIN; MOB-API-016, MOB-API-018 |

### MOB-FR-CHK-05 — Hiện giờ check-in

| Trường | Đặc tả |
| --- | --- |
| Tên | Hiện giờ check-in |
| Mô tả | Hiển thị checkedInAt trên vé khách và kết quả check-in điện thoại; sau khi cho vào thành công chuẩn bị ô mã cho vé tiếp theo. |
| Tác nhân | Nhân viên/quản trị viên |
| Tiền điều kiện | Nhân viên/quản trị viên đã đăng nhập; vé CONFIRMED, chưa dùng và trong khoảng 180 phút trước đến 120 phút sau giờ bắt đầu. |
| Kích hoạt | Thực hiện “Hiện giờ check-in” hoặc sự kiện/tác vụ backend tương ứng. |
| Luồng chính | 1. Đọc đầu vào/tài nguyên hiện tại và phiên áp dụng. 2. Thực hiện thao tác này: Hiển thị checkedInAt trên vé khách và kết quả check-in điện thoại; sau khi cho vào thành công chuẩn bị ô mã cho vé tiếp theo. 3. Trả/hiển thị kết quả chính thức và làm mới dữ liệu bị tác động sau thành công. |
| Luồng thay thế / ngoại lệ | Cho nhập tay khi camera không có/bị từ chối. Mã không tồn tại trả 404; vé chưa trả, đã huỷ, chờ hoàn tiền, ngoài khung giờ hoặc đã dùng trả 409. Lần check-in thứ hai đồng thời thất bại. Lỗi thông tin bổ sung không được che vé. |
| Hậu điều kiện | Dữ liệu/trạng thái đủ quyền được trả/hiển thị; đọc không đổi trạng thái vé/thanh toán. Dấu đã đọc thông báo chỉ đổi bằng thao tác ghi riêng. |
| Ưu tiên | M |
| Tiêu chí nghiệm thu | **MOB-FR-CHK-05-AC-01** — Với tiền điều kiện/kích hoạt, kiểm tra: Hiển thị checkedInAt trên vé khách và kết quả check-in điện thoại; sau khi cho vào thành công chuẩn bị ô mã cho vé tiếp theo. **MOB-FR-CHK-05-AC-02** — Thử đầu vào sai/thiếu quyền/xung đột áp dụng và kiểm tra từ chối đã nêu, không đổi dữ liệu trái phép và không báo thành công sai. |
| Bằng chứng | [Cinema_BE/BookingService/BookingService/Controllers/BookingController.cs](../Cinema_BE/BookingService/BookingService/Controllers/BookingController.cs); [Cinema_Mobile/lib/features/booking/screens/booking_detail_screen.dart](../Cinema_Mobile/lib/features/booking/screens/booking_detail_screen.dart); [Cinema_Mobile/lib/features/staff/screens/staff_check_in_screen.dart](../Cinema_Mobile/lib/features/staff/screens/staff_check_in_screen.dart); [Cinema_BE/BookingService/BookingService/Services/Implementations/BookingService.cs](../Cinema_BE/BookingService/BookingService/Services/Implementations/BookingService.cs); [Cinema_BE/BookingService/BookingService/Configuration/CheckInOptions.cs](../Cinema_BE/BookingService/BookingService/Configuration/CheckInOptions.cs) |
| Quy tắc nghiệp vụ | MOB-BR-21 |
| Ca sử dụng / màn / API | UC-MOB-08; MOB-SCR-TICKET, MOB-SCR-CHECKIN; MOB-API-017, MOB-API-018 |

### MOB-FR-NOTI-01 — Lịch sử thông báo

| Trường | Đặc tả |
| --- | --- |
| Tên | Lịch sử thông báo |
| Mô tả | Khách liệt kê và mở thông báo của mình, điều hướng tới vé liên quan. Điện thoại không liệt kê thông báo toàn bộ người dùng. |
| Tác nhân | Khách hàng; hệ thống backend tạo email/nhắc lịch |
| Tiền điều kiện | Có phiên tài khoản để xem lịch sử trong ứng dụng; cấu hình SMTP/xử lý sự kiện để gửi thật. |
| Kích hoạt | Thực hiện “Lịch sử thông báo” hoặc sự kiện/tác vụ backend tương ứng. |
| Luồng chính | 1. Đọc đầu vào/tài nguyên hiện tại và phiên áp dụng. 2. Thực hiện thao tác này: Khách liệt kê và mở thông báo của mình, điều hướng tới vé liên quan. Điện thoại không liệt kê thông báo toàn bộ người dùng. 3. Trả/hiển thị kết quả chính thức và làm mới dữ liệu bị tác động sau thành công. |
| Luồng thay thế / ngoại lệ | Kiểm tra chủ sở hữu từ chối dữ liệu người khác; có trạng thái tải/rỗng/lỗi-thử lại. Gửi lỗi giữ FAILED để thử lại và không hoàn tác thanh toán. Chống lặp sự kiện giảm gửi trùng nhưng SMTP cùng commit database không bảo đảm giao dịch đúng một lần tuyệt đối. |
| Hậu điều kiện | Dữ liệu/trạng thái đủ quyền được trả/hiển thị; đọc không đổi trạng thái vé/thanh toán. Dấu đã đọc thông báo chỉ đổi bằng thao tác ghi riêng. |
| Ưu tiên | M |
| Tiêu chí nghiệm thu | **MOB-FR-NOTI-01-AC-01** — Với tiền điều kiện/kích hoạt, kiểm tra: Khách liệt kê và mở thông báo của mình, điều hướng tới vé liên quan. Điện thoại không liệt kê thông báo toàn bộ người dùng. **MOB-FR-NOTI-01-AC-02** — Thử đầu vào sai/thiếu quyền/xung đột áp dụng và kiểm tra từ chối đã nêu, không đổi dữ liệu trái phép và không báo thành công sai. |
| Bằng chứng | [Cinema_BE/BookingService/BookingService/Controllers/NotificationController.cs](../Cinema_BE/BookingService/BookingService/Controllers/NotificationController.cs); [Cinema_Mobile/lib/features/notification/screens/notification_list_screen.dart](../Cinema_Mobile/lib/features/notification/screens/notification_list_screen.dart); [Cinema_BE/BookingService/BookingService/Services/Implementations/NotificationService.cs](../Cinema_BE/BookingService/BookingService/Services/Implementations/NotificationService.cs); [Cinema_BE/BookingService/BookingService/Workers/ShowtimeReminderWorker.cs](../Cinema_BE/BookingService/BookingService/Workers/ShowtimeReminderWorker.cs) |
| Quy tắc nghiệp vụ | MOB-BR-11, MOB-BR-13 |
| Ca sử dụng / màn / API | UC-MOB-09; MOB-SCR-NOTIFICATIONS; MOB-API-032 |

### MOB-FR-NOTI-04 — Chi tiết thông báo

| Trường | Đặc tả |
| --- | --- |
| Tên | Chi tiết thông báo |
| Mô tả | Xem chi tiết thông báo. |
| Tác nhân | Khách hàng; hệ thống backend tạo email/nhắc lịch |
| Tiền điều kiện | Có phiên tài khoản để xem lịch sử trong ứng dụng; cấu hình SMTP/xử lý sự kiện để gửi thật. |
| Kích hoạt | Thực hiện “Chi tiết thông báo” hoặc sự kiện/tác vụ backend tương ứng. |
| Luồng chính | 1. Đọc đầu vào/tài nguyên hiện tại và phiên áp dụng. 2. Thực hiện thao tác này: Xem chi tiết thông báo. 3. Trả/hiển thị kết quả chính thức và làm mới dữ liệu bị tác động sau thành công. |
| Luồng thay thế / ngoại lệ | Kiểm tra chủ sở hữu từ chối dữ liệu người khác; có trạng thái tải/rỗng/lỗi-thử lại. Gửi lỗi giữ FAILED để thử lại và không hoàn tác thanh toán. Chống lặp sự kiện giảm gửi trùng nhưng SMTP cùng commit database không bảo đảm giao dịch đúng một lần tuyệt đối. |
| Hậu điều kiện | Dữ liệu/trạng thái đủ quyền được trả/hiển thị; đọc không đổi trạng thái vé/thanh toán. Dấu đã đọc thông báo chỉ đổi bằng thao tác ghi riêng. |
| Ưu tiên | M |
| Tiêu chí nghiệm thu | **MOB-FR-NOTI-04-AC-01** — Với tiền điều kiện/kích hoạt, kiểm tra: Xem chi tiết thông báo. **MOB-FR-NOTI-04-AC-02** — Thử đầu vào sai/thiếu quyền/xung đột áp dụng và kiểm tra từ chối đã nêu, không đổi dữ liệu trái phép và không báo thành công sai. |
| Bằng chứng | [Cinema_BE/BookingService/BookingService/Controllers/NotificationController.cs](../Cinema_BE/BookingService/BookingService/Controllers/NotificationController.cs); [Cinema_Mobile/lib/features/notification/screens/notification_detail_screen.dart](../Cinema_Mobile/lib/features/notification/screens/notification_detail_screen.dart); [Cinema_BE/BookingService/BookingService/Services/Implementations/NotificationService.cs](../Cinema_BE/BookingService/BookingService/Services/Implementations/NotificationService.cs); [Cinema_BE/BookingService/BookingService/Workers/ShowtimeReminderWorker.cs](../Cinema_BE/BookingService/BookingService/Workers/ShowtimeReminderWorker.cs) |
| Quy tắc nghiệp vụ | MOB-BR-11, MOB-BR-13 |
| Ca sử dụng / màn / API | UC-MOB-09; MOB-SCR-NOTIFICATION; MOB-API-029 |

### MOB-FR-NOTI-06 — Email sự kiện

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
| Tiêu chí nghiệm thu | **MOB-FR-NOTI-06-AC-01** — Với tiền điều kiện/kích hoạt, kiểm tra: Nhận sự kiện vé/thanh toán đã commit để gửi email xác nhận kèm QR nhúng, huỷ, hết hạn và hoàn tiền. Chống lặp theo ID sự kiện và bỏ qua vé không có email. Có thể thử gửi lại; SMTP và commit database không bảo đảm gửi đúng một lần tuyệt đối khi xảy ra sự cố. **MOB-FR-NOTI-06-AC-02** — Thử đầu vào sai/thiếu quyền/xung đột áp dụng và kiểm tra từ chối đã nêu, không đổi dữ liệu trái phép và không báo thành công sai. |
| Bằng chứng | [Cinema_BE/BookingService/BookingService/Controllers/NotificationController.cs](../Cinema_BE/BookingService/BookingService/Controllers/NotificationController.cs); [Cinema_BE/BookingService/BookingService/Services/Implementations/NotificationService.cs](../Cinema_BE/BookingService/BookingService/Services/Implementations/NotificationService.cs); [Cinema_BE/BookingService/BookingService/Workers/ShowtimeReminderWorker.cs](../Cinema_BE/BookingService/BookingService/Workers/ShowtimeReminderWorker.cs) |
| Quy tắc nghiệp vụ | MOB-BR-11, MOB-BR-13 |
| Ca sử dụng / màn / API | UC-MOB-09; ; MOB-API-032 |

### MOB-FR-NOTI-07 — Email OTP và chào mừng

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
| Tiêu chí nghiệm thu | **MOB-FR-NOTI-07-AC-01** — Với tiền điều kiện/kích hoạt, kiểm tra: AuthService gửi email OTP (xác thực, đặt lại mật khẩu) và email chào mừng. **MOB-FR-NOTI-07-AC-02** — Thử đầu vào sai/thiếu quyền/xung đột áp dụng và kiểm tra từ chối đã nêu, không đổi dữ liệu trái phép và không báo thành công sai. |
| Bằng chứng | [Cinema_BE/AuthService/AuthService/Controllers/AuthController.cs](../Cinema_BE/AuthService/AuthService/Controllers/AuthController.cs); [Cinema_BE/BookingService/BookingService/Services/Implementations/NotificationService.cs](../Cinema_BE/BookingService/BookingService/Services/Implementations/NotificationService.cs); [Cinema_BE/BookingService/BookingService/Workers/ShowtimeReminderWorker.cs](../Cinema_BE/BookingService/BookingService/Workers/ShowtimeReminderWorker.cs) |
| Quy tắc nghiệp vụ | MOB-BR-11, MOB-BR-13 |
| Ca sử dụng / màn / API | UC-MOB-09; ; MOB-API-005, MOB-API-011, MOB-API-014 |

### MOB-FR-NOTI-08 — Nhắc giờ chiếu

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
| Tiêu chí nghiệm thu | **MOB-FR-NOTI-08-AC-01** — Với tiền điều kiện/kích hoạt, kiểm tra: **Nhắc giờ chiếu**: job nền (mỗi phút, cấu hình `ShowtimeReminder`) gửi email và ghi vào lịch sử thông báo cho vé đã thanh toán, chưa check-in, có giờ chiếu trong 2 giờ tới; mỗi vé nhắc một lần. Vé đặt khi đã vào khoảng nhắc thì bỏ qua (khách vừa nhận email xác nhận). **MOB-FR-NOTI-08-AC-02** — Thử đầu vào sai/thiếu quyền/xung đột áp dụng và kiểm tra từ chối đã nêu, không đổi dữ liệu trái phép và không báo thành công sai. |
| Bằng chứng | [Cinema_BE/BookingService/BookingService/Controllers/NotificationController.cs](../Cinema_BE/BookingService/BookingService/Controllers/NotificationController.cs); [Cinema_BE/BookingService/BookingService/Services/Implementations/NotificationService.cs](../Cinema_BE/BookingService/BookingService/Services/Implementations/NotificationService.cs); [Cinema_BE/BookingService/BookingService/Workers/ShowtimeReminderWorker.cs](../Cinema_BE/BookingService/BookingService/Workers/ShowtimeReminderWorker.cs) |
| Quy tắc nghiệp vụ | MOB-BR-11, MOB-BR-13 |
| Ca sử dụng / màn / API | UC-MOB-09; ; MOB-API-032 |

### MOB-FR-NOTI-09 — Thông báo đã/chưa đọc

| Trường | Đặc tả |
| --- | --- |
| Tên | Thông báo đã/chưa đọc |
| Mô tả | Hiện chấm/chữ đậm cho thông báo chưa đọc và huy hiệu số chưa đọc; mở chi tiết đánh dấu đã đọc, Đánh dấu tất cả cập nhật thông báo của khách. Chỉ người nhận được đánh dấu (khác thì 403). |
| Tác nhân | Khách hàng; hệ thống backend tạo email/nhắc lịch |
| Tiền điều kiện | Có phiên tài khoản để xem lịch sử trong ứng dụng; cấu hình SMTP/xử lý sự kiện để gửi thật. |
| Kích hoạt | Thực hiện “Thông báo đã/chưa đọc” hoặc sự kiện/tác vụ backend tương ứng. |
| Luồng chính | 1. Đọc đầu vào/tài nguyên hiện tại và phiên áp dụng. 2. Thực hiện thao tác này: Hiện chấm/chữ đậm cho thông báo chưa đọc và huy hiệu số chưa đọc; mở chi tiết đánh dấu đã đọc, Đánh dấu tất cả cập nhật thông báo của khách. Chỉ người nhận được đánh dấu (khác thì 403). 3. Trả/hiển thị kết quả chính thức và làm mới dữ liệu bị tác động sau thành công. |
| Luồng thay thế / ngoại lệ | Kiểm tra chủ sở hữu từ chối dữ liệu người khác; có trạng thái tải/rỗng/lỗi-thử lại. Gửi lỗi giữ FAILED để thử lại và không hoàn tác thanh toán. Chống lặp sự kiện giảm gửi trùng nhưng SMTP cùng commit database không bảo đảm giao dịch đúng một lần tuyệt đối. |
| Hậu điều kiện | Kết quả thành công quan sát được khớp yêu cầu này; chuyển trạng thái được chỉ định được lưu. Từ chối không cấp quyền hoặc để thay đổi dở dang trái phép. |
| Ưu tiên | M |
| Tiêu chí nghiệm thu | **MOB-FR-NOTI-09-AC-01** — Với tiền điều kiện/kích hoạt, kiểm tra: Hiện chấm/chữ đậm cho thông báo chưa đọc và huy hiệu số chưa đọc; mở chi tiết đánh dấu đã đọc, Đánh dấu tất cả cập nhật thông báo của khách. Chỉ người nhận được đánh dấu (khác thì 403). **MOB-FR-NOTI-09-AC-02** — Thử đầu vào sai/thiếu quyền/xung đột áp dụng và kiểm tra từ chối đã nêu, không đổi dữ liệu trái phép và không báo thành công sai. |
| Bằng chứng | [Cinema_BE/BookingService/BookingService/Controllers/NotificationController.cs](../Cinema_BE/BookingService/BookingService/Controllers/NotificationController.cs); [Cinema_Mobile/lib/features/home/screens/home_screen.dart](../Cinema_Mobile/lib/features/home/screens/home_screen.dart); [Cinema_Mobile/lib/features/notification/screens/notification_list_screen.dart](../Cinema_Mobile/lib/features/notification/screens/notification_list_screen.dart); [Cinema_Mobile/lib/features/notification/screens/notification_detail_screen.dart](../Cinema_Mobile/lib/features/notification/screens/notification_detail_screen.dart); [Cinema_BE/BookingService/BookingService/Services/Implementations/NotificationService.cs](../Cinema_BE/BookingService/BookingService/Services/Implementations/NotificationService.cs); [Cinema_BE/BookingService/BookingService/Workers/ShowtimeReminderWorker.cs](../Cinema_BE/BookingService/BookingService/Workers/ShowtimeReminderWorker.cs) |
| Quy tắc nghiệp vụ | MOB-BR-11, MOB-BR-13 |
| Ca sử dụng / màn / API | UC-MOB-09; MOB-SCR-HOME, MOB-SCR-NOTIFICATIONS, MOB-SCR-NOTIFICATION; MOB-API-028, MOB-API-030, MOB-API-031 |

### MOB-FR-NAV-01 — Bảo vệ và khôi phục route

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
| Tiêu chí nghiệm thu | **MOB-FR-NAV-01-AC-01** — Với tiền điều kiện/kích hoạt, kiểm tra: Bảo vệ route có tên: đích cần quyền khi chưa đăng nhập mở đăng nhập và lưu route chờ; đăng nhập thành công tiếp tục đích đủ quyền. Route lạ về trang đầu theo vai trò. Trang xác nhận thiếu BookingDraft trong bộ nhớ quay về chọn ghế. **MOB-FR-NAV-01-AC-02** — Thử đầu vào sai/thiếu quyền/xung đột áp dụng và kiểm tra từ chối đã nêu, không đổi dữ liệu trái phép và không báo thành công sai. |
| Bằng chứng | [Cinema_Mobile/lib/features/auth/screens/login_screen.dart](../Cinema_Mobile/lib/features/auth/screens/login_screen.dart); [Cinema_BE/AuthService/AuthService/Service/AuthService.cs](../Cinema_BE/AuthService/AuthService/Service/AuthService.cs); [Cinema_BE/ApiGateway/ApiGateway/Program.cs](../Cinema_BE/ApiGateway/ApiGateway/Program.cs) |
| Quy tắc nghiệp vụ | MOB-BR-01, MOB-BR-02, MOB-BR-03, MOB-BR-24, MOB-BR-25 |
| Ca sử dụng / màn / API | UC-MOB-01; MOB-SCR-LOGIN; Hành vi client; không endpoint riêng |

### MOB-FR-STATE-01 — Trạng thái tải, lỗi và rỗng

| Trường | Đặc tả |
| --- | --- |
| Tên | Trạng thái tải, lỗi và rỗng |
| Mô tả | Có trạng thái tải, lỗi/thử lại và rỗng trên màn dữ liệu; chặn gửi lặp khi thao tác ghi đang chạy và giữ kết quả chờ/thất bại đúng thực tế khi lỗi mạng. |
| Tác nhân | Khách hàng |
| Tiền điều kiện | Màn dữ liệu bắt đầu tải hoặc yêu cầu đang chạy. |
| Kích hoạt | Thực hiện “Trạng thái tải, lỗi và rỗng” hoặc sự kiện/tác vụ backend tương ứng. |
| Luồng chính | 1. Đọc đầu vào/tài nguyên hiện tại và phiên áp dụng. 2. Thực hiện thao tác này: Có trạng thái tải, lỗi/thử lại và rỗng trên màn dữ liệu; chặn gửi lặp khi thao tác ghi đang chạy và giữ kết quả chờ/thất bại đúng thực tế khi lỗi mạng. 3. Trả/hiển thị kết quả chính thức và làm mới dữ liệu bị tác động sau thành công. |
| Luồng thay thế / ngoại lệ | Giữ chỗ đồng thời trả 409 và không được thu tiền hoặc để lại ghế/điểm dở dang. Bắp nước/mã/điểm sai trả lỗi kiểm tra. Hết hạn nhả ghế và trả điểm đã giữ. |
| Hậu điều kiện | Kết quả thành công quan sát được khớp yêu cầu này; chuyển trạng thái được chỉ định được lưu. Từ chối không cấp quyền hoặc để thay đổi dở dang trái phép. |
| Ưu tiên | M |
| Tiêu chí nghiệm thu | **MOB-FR-STATE-01-AC-01** — Với tiền điều kiện/kích hoạt, kiểm tra: Có trạng thái tải, lỗi/thử lại và rỗng trên màn dữ liệu; chặn gửi lặp khi thao tác ghi đang chạy và giữ kết quả chờ/thất bại đúng thực tế khi lỗi mạng. **MOB-FR-STATE-01-AC-02** — Thử đầu vào sai/thiếu quyền/xung đột áp dụng và kiểm tra từ chối đã nêu, không đổi dữ liệu trái phép và không báo thành công sai. |
| Bằng chứng | [Cinema_BE/BookingService/BookingService/Services/Implementations/BookingService.cs](../Cinema_BE/BookingService/BookingService/Services/Implementations/BookingService.cs); [Cinema_BE/BookingService/BookingService/Helpers/PromotionRules.cs](../Cinema_BE/BookingService/BookingService/Helpers/PromotionRules.cs); [Cinema_BE/BookingService/BookingService/Helpers/LoyaltyRules.cs](../Cinema_BE/BookingService/BookingService/Helpers/LoyaltyRules.cs) |
| Quy tắc nghiệp vụ | MOB-BR-07, MOB-BR-08, MOB-BR-14, MOB-BR-15, MOB-BR-16, MOB-BR-17, MOB-BR-27, MOB-BR-28, MOB-BR-29 |
| Ca sử dụng / màn / API | UC-MOB-05; ; Hành vi client; không endpoint riêng |

### MOB-FR-MEDIA-01 — Media phim theo nền tảng

| Trường | Đặc tả |
| --- | --- |
| Tên | Media phim theo nền tảng |
| Mô tả | Trên điện thoại native giữ ảnh phim và mở trailerUrl bằng ứng dụng ngoài qua url_launcher; preview tự phát/rê chuột web chưa được triển khai trên native (supportsTrailerPreview=false). |
| Tác nhân | Quản trị viên |
| Tiền điều kiện | Có phiên quản trị viên; bản ghi đích tồn tại khi sửa/dừng/điều chỉnh. |
| Kích hoạt | Thực hiện “Media phim theo nền tảng” hoặc sự kiện/tác vụ backend tương ứng. |
| Luồng chính | 1. Đọc đầu vào/tài nguyên hiện tại và phiên áp dụng. 2. Thực hiện thao tác này: Trên điện thoại native giữ ảnh phim và mở trailerUrl bằng ứng dụng ngoài qua url_launcher; preview tự phát/rê chuột web chưa được triển khai trên native (supportsTrailerPreview=false). 3. Trả/hiển thị kết quả chính thức và làm mới dữ liệu bị tác động sau thành công. |
| Luồng thay thế / ngoại lệ | Hiện trạng thái rỗng khi không có phim/suất phù hợp. Đánh giá bằng vé người khác trả 404; vé chưa check-in trả 400. Media lỗi phải còn ảnh hoặc nội dung dự phòng. |
| Hậu điều kiện | Dữ liệu/trạng thái đủ quyền được trả/hiển thị; đọc không đổi trạng thái vé/thanh toán. Dấu đã đọc thông báo chỉ đổi bằng thao tác ghi riêng. |
| Ưu tiên | L |
| Tiêu chí nghiệm thu | **MOB-FR-MEDIA-01-AC-01** — Với tiền điều kiện/kích hoạt, kiểm tra: Trên điện thoại native giữ ảnh phim và mở trailerUrl bằng ứng dụng ngoài qua url_launcher; preview tự phát/rê chuột web chưa được triển khai trên native (supportsTrailerPreview=false). **MOB-FR-MEDIA-01-AC-02** — Thử đầu vào sai/thiếu quyền/xung đột áp dụng và kiểm tra từ chối đã nêu, không đổi dữ liệu trái phép và không báo thành công sai. |
| Bằng chứng | [Cinema_BE/MovieService/MovieService/Controllers/MoviesController.cs](../Cinema_BE/MovieService/MovieService/Controllers/MoviesController.cs); [Cinema_Mobile/lib/features/home/screens/home_screen.dart](../Cinema_Mobile/lib/features/home/screens/home_screen.dart); [Cinema_BE/MovieService/MovieService/Service/Impl/MovieService.cs](../Cinema_BE/MovieService/MovieService/Service/Impl/MovieService.cs); [Cinema_BE/BookingService/BookingService/Services/Implementations/MovieReviewService.cs](../Cinema_BE/BookingService/BookingService/Services/Implementations/MovieReviewService.cs) |
| Quy tắc nghiệp vụ | MOB-BR-26 |
| Ca sử dụng / màn / API | UC-MOB-02; MOB-SCR-HOME; MOB-API-024 |

## 10. Đặc tả ca sử dụng

### UC-MOB-01 — Xác thực và phiên tài khoản

| Trường | Đặc tả ca sử dụng |
| --- | --- |
| Tác nhân | Khách chưa đăng nhập; người có tài khoản; hệ thống |
| Mục tiêu | Xác thực và phiên tài khoản |
| Tiền điều kiện | Gateway đã được cấu hình. Đăng ký/khôi phục cần SMTP; thao tác được bảo vệ cần phiên tài khoản hợp lệ. |
| Kích hoạt | Mở màn liên quan hoặc thực hiện thao tác/sự kiện đã nêu. |
| Luồng chính | 1. Nhập thông tin tài khoản hoặc yêu cầu thao tác phiên. 2. Kiểm tra trường dữ liệu; gửi đến AuthService qua gateway. 3. Với xác thực/khôi phục, nhập OTP từ email; với đăng nhập/làm mới, lưu token và người dùng trả về. 4. Điều hướng theo vai trò và tiếp tục trang đang chờ nếu đủ quyền. |
| Luồng thay thế / ngoại lệ | Từ chối trường sai (400), thông tin đăng nhập sai (401), email chưa xác thực (403), OTP cũ/sai hoặc vượt giới hạn gửi/tần suất (429). Xoá phiên khi tài khoản bị khoá/quyền thay đổi; hiển thị lỗi SMTP/phụ thuộc (503). |
| Hậu điều kiện | Chỉ thao tác cấp token thành công mới xác thực tài khoản; yêu cầu bị từ chối không cấp quyền truy cập. |
| Yêu cầu / ưu tiên | MOB-FR-AUTH-01 (H), MOB-FR-AUTH-02 (H), MOB-FR-AUTH-03 (H), MOB-FR-AUTH-04 (H), MOB-FR-AUTH-05 (H), MOB-FR-AUTH-06 (H), MOB-FR-AUTH-07 (H), MOB-FR-AUTH-08 (M), MOB-FR-AUTH-09 (H), MOB-FR-AUTH-10 (H), MOB-FR-AUTH-11 (M), MOB-FR-AUTH-12 (H), MOB-FR-AUTH-13 (H), MOB-FR-AUTH-14 (M), MOB-FR-AUTH-16 (M), MOB-FR-AUTH-17 (M), MOB-FR-NAV-01 (H) |
| Nghiệm thu | Thực hiện AC-01/AC-02 cho mọi FR liên quan với tác nhân đủ quyền. |

### UC-MOB-02 — Danh mục phim và đánh giá

| Trường | Đặc tả ca sử dụng |
| --- | --- |
| Tác nhân | Khách chưa đăng nhập/khách hàng |
| Mục tiêu | Danh mục phim và đánh giá |
| Tiền điều kiện | Có dữ liệu phim; cập nhật cần quản trị viên; đánh giá cần vé của chính khách đã được check-in. |
| Kích hoạt | Mở màn liên quan hoặc thực hiện thao tác/sự kiện đã nêu. |
| Luồng chính | 1. Duyệt đang/sắp chiếu, tìm tên và lọc thể loại. 2. Mở thông tin, trailer ngoài và suất bảy ngày; đọc tổng hợp đánh giá. 3. Từ vé của mình đã check-in, gửi/sửa 1–5 sao (tối đa 1.000 ký tự) hoặc xoá. 4. Làm mới dữ liệu liên quan. |
| Luồng thay thế / ngoại lệ | Hiện trạng thái rỗng khi không có phim/suất phù hợp. Đánh giá bằng vé người khác trả 404; vé chưa check-in trả 400. Media lỗi phải còn ảnh hoặc nội dung dự phòng. |
| Hậu điều kiện | Danh mục/đánh giá phản ánh phản hồi chính thức; ngừng chiếu vẫn giữ các vé đã có. |
| Yêu cầu / ưu tiên | MOB-FR-MOV-02 (H), MOB-FR-MOV-03 (M), MOB-FR-MOV-04 (H), MOB-FR-MOV-08 (L), MOB-FR-MOV-09 (H), MOB-FR-MOV-10 (M), MOB-FR-MOV-11 (L), MOB-FR-MOV-12 (M), MOB-FR-MEDIA-01 (L) |
| Nghiệm thu | Thực hiện AC-01/AC-02 cho mọi FR liên quan với tác nhân đủ quyền. |

### UC-MOB-03 — Sơ đồ ghế và tình trạng chỗ

| Trường | Đặc tả ca sử dụng |
| --- | --- |
| Tác nhân | Khách hàng |
| Mục tiêu | Sơ đồ ghế và tình trạng chỗ |
| Tiền điều kiện | Khách đã đăng nhập và suất chưa bắt đầu/phòng đã chọn tồn tại. |
| Kích hoạt | Mở màn liên quan hoặc thực hiện thao tác/sự kiện đã nêu. |
| Luồng chính | 1. Tải ghế phòng, giá suất và ID đã chiếm. 2. Chọn ghế trống, thêm/bỏ hai ghế sweetbox cùng nhau. 3. Làm mới mỗi năm giây và bỏ ghế bị người khác giữ. 4. Tiếp tục với dữ liệu đặt vé tạm; lúc này ghế chưa được giữ. |
| Luồng thay thế / ngoại lệ | Bỏ chọn ghế vừa bị đơn khác giữ và thông báo cho khách. Từ chối nửa cặp sweetbox, ghế sai phòng và sửa sơ đồ không đủ điều kiện. |
| Hậu điều kiện | Client hiển thị sơ đồ mới; chỉ chọn ghế chưa tạo giữ chỗ. |
| Yêu cầu / ưu tiên | MOB-FR-SEAT-03 (H) |
| Nghiệm thu | Thực hiện AC-01/AC-02 cho mọi FR liên quan với tác nhân đủ quyền. |

### UC-MOB-04 — Suất chiếu và giá vé

| Trường | Đặc tả ca sử dụng |
| --- | --- |
| Tác nhân | Khách chưa đăng nhập/khách hàng; nhân viên/quản trị viên chỉ xem chi tiết trong check-in |
| Mục tiêu | Suất chiếu và giá vé |
| Tiền điều kiện | Phim và phòng tồn tại; thay đổi quản lý cần nhân viên/quản trị viên. |
| Kích hoạt | Mở màn liên quan hoặc thực hiện thao tác/sự kiện đã nêu. |
| Luồng chính | 1. Mở chi tiết phim và chọn ngày trong bảy ngày tới. 2. Tải suất OPEN chưa bắt đầu. 3. Hiện phòng, định dạng, giờ và giá theo loại ghế. 4. Chọn suất và mở chọn ghế sau đăng nhập. |
| Luồng thay thế / ngoại lệ | Từ chối trùng lịch bằng 409 và giờ/định dạng sai bằng 400; suất đã huỷ là trạng thái cuối. Khách không chọn suất đóng bán hoặc đã bắt đầu. |
| Hậu điều kiện | Lịch và giá theo loại ghế từ server là căn cứ chính thức; huỷ được lan truyền bất đồng bộ. |
| Yêu cầu / ưu tiên | MOB-FR-SHOW-03 (H), MOB-FR-SHOW-06 (H), MOB-FR-SHOW-07 (M), MOB-FR-SHOW-08 (H), MOB-FR-SHOW-13 (M) |
| Nghiệm thu | Thực hiện AC-01/AC-02 cho mọi FR liên quan với tác nhân đủ quyền. |

### UC-MOB-05 — Đặt vé, bắp nước, khuyến mãi và điểm thành viên

| Trường | Đặc tả ca sử dụng |
| --- | --- |
| Tác nhân | Khách hàng |
| Mục tiêu | Đặt vé, bắp nước, khuyến mãi và điểm thành viên |
| Tiền điều kiện | Khách đã đăng nhập chọn suất OPEN chưa bắt đầu và ghế; khách vãng lai tại quầy được nhân viên/quản trị viên thao tác thay. |
| Kích hoạt | Mở màn liên quan hoặc thực hiện thao tác/sự kiện đã nêu. |
| Luồng chính | 1. Kiểm tra ghế; có thể chọn bắp nước đang bán, mã khuyến mãi và điểm được dùng. 2. Xác nhận điều kiện phân loại tuổi khi cần. 3. Gửi ID/số lượng; server tính lại toàn bộ giá, kiểm tra cặp, khoá giữ chỗ và tạo vé PENDING hết hạn sau mười phút. 4. Mở thanh toán hoặc xem/huỷ vé của mình theo trạng thái. |
| Luồng thay thế / ngoại lệ | Giữ chỗ đồng thời trả 409 và không được thu tiền hoặc để lại ghế/điểm dở dang. Bắp nước/mã/điểm sai trả lỗi kiểm tra. Hết hạn nhả ghế và trả điểm đã giữ. |
| Hậu điều kiện | Tạo thành công trả vé đã lưu, chi tiết tiền và hạn; tạo thất bại hoàn tác giao dịch. |
| Yêu cầu / ưu tiên | MOB-FR-BOOK-01 (H), MOB-FR-BOOK-02 (H), MOB-FR-BOOK-04 (H), MOB-FR-BOOK-05 (H), MOB-FR-BOOK-06 (H), MOB-FR-BOOK-07 (H), MOB-FR-BOOK-08 (H), MOB-FR-BOOK-09 (H), MOB-FR-BOOK-10 (H), MOB-FR-BOOK-11 (M), MOB-FR-BOOK-13 (M), MOB-FR-BOOK-15 (M), MOB-FR-BOOK-17 (M), MOB-FR-BOOK-19 (L), MOB-FR-STATE-01 (M) |
| Nghiệm thu | Thực hiện AC-01/AC-02 cho mọi FR liên quan với tác nhân đủ quyền. |

### UC-MOB-06 — Thanh toán trực tuyến và đối soát

| Trường | Đặc tả ca sử dụng |
| --- | --- |
| Tác nhân | Khách hàng; PayOS/hệ thống là phụ thuộc ngoài/dùng chung |
| Mục tiêu | Thanh toán trực tuyến và đối soát |
| Tiền điều kiện | Có vé đủ điều kiện thanh toán; thông tin PayOS và callback/địa chỉ trở về được cấu hình để thanh toán thật. |
| Kích hoạt | Mở màn liên quan hoặc thực hiện thao tác/sự kiện đã nêu. |
| Luồng chính | 1. Yêu cầu/dùng lại phiên PayOS cho vé. 2. Mở thanh toán và hiển thị đếm ngược giữ ghế. 3. Hỏi vé mỗi năm giây và xác minh PayOS mỗi ba mươi giây khi trang thanh toán khách đang hoạt động; đối soát khi trở lại ứng dụng. 4. Webhook có chữ ký hoặc dữ liệu PayOS đã xác minh cập nhật thanh toán và vé; tải kết quả từ server. |
| Luồng thay thế / ngoại lệ | Không dùng tham số chuyển hướng làm bằng chứng đã trả tiền. Xử lý huỷ, hết thời gian và 503 mà không báo thành công sai; trả muộn chỉ xác nhận nếu lấy lại được ghế, nếu không tạo hoàn tiền. |
| Hậu điều kiện | Trạng thái thanh toán từ server là chính thức; SUCCESS xác nhận vé và lên lịch thông báo mà không lặp tác động nghiệp vụ. |
| Yêu cầu / ưu tiên | MOB-FR-PAY-01 (H), MOB-FR-PAY-02 (H), MOB-FR-PAY-03 (H), MOB-FR-PAY-04 (M), MOB-FR-PAY-06 (H), MOB-FR-PAY-07 (H), MOB-FR-PAY-08 (M), MOB-FR-PAY-11 (M) |
| Nghiệm thu | Thực hiện AC-01/AC-02 cho mọi FR liên quan với tác nhân đủ quyền. |

### UC-MOB-07 — Huỷ vé và hoàn tiền thủ công

| Trường | Đặc tả ca sử dụng |
| --- | --- |
| Tác nhân | Khách hàng |
| Mục tiêu | Huỷ vé và hoàn tiền thủ công |
| Tiền điều kiện | Có vé của chính khách; huỷ vé đã trả phải còn ít nhất hai giờ trước suất. |
| Kích hoạt | Mở màn liên quan hoặc thực hiện thao tác/sự kiện đã nêu. |
| Luồng chính | 1. Mở vé đã trả của mình và xác nhận huỷ. 2. Backend kiểm tra mốc hai giờ, tạo/dùng lại yêu cầu và giữ ghế khi yêu cầu khách đang chờ. 3. Hiện kết quả chờ/hoàn tất/từ chối và lý do sau khi nhân viên xử lý trên web. 4. Tải lại vé và thông báo. |
| Luồng thay thế / ngoại lệ | Huỷ trong hai giờ bị từ chối bằng 409. Hiện trạng thái hoàn tiền/từ chối từ backend; điện thoại không có thao tác duyệt/từ chối/ghi chuyển tiền. |
| Hậu điều kiện | Hoàn tất đưa về COMPLETED/REFUNDED và nhả ghế vé bị huỷ; từ chối hợp lệ phục hồi SUCCESS/CONFIRMED; hoàn tiền đang chờ do khách yêu cầu vẫn giữ ghế. |
| Yêu cầu / ưu tiên | MOB-FR-REF-01 (H), MOB-FR-REF-05 (M), MOB-FR-REF-06 (M), MOB-FR-REF-07 (H) |
| Nghiệm thu | Thực hiện AC-01/AC-02 cho mọi FR liên quan với tác nhân đủ quyền. |

### UC-MOB-08 — Tra vé và check-in

| Trường | Đặc tả ca sử dụng |
| --- | --- |
| Tác nhân | Nhân viên/quản trị viên quét và cho vào; khách hàng xuất trình vé của mình |
| Mục tiêu | Tra vé và check-in |
| Tiền điều kiện | Nhân viên/quản trị viên đã đăng nhập; vé CONFIRMED, chưa dùng và trong khoảng 180 phút trước đến 120 phút sau giờ bắt đầu. |
| Kích hoạt | Mở màn liên quan hoặc thực hiện thao tác/sự kiện đã nêu. |
| Luồng chính | 1. Quét QR hoặc nhập mã vé rồi nhấn Enter. 2. Tra vé; bổ sung phòng và phân loại tuổi khi lời gọi danh mục thành công. 3. Kiểm tra danh tính/tuổi theo nhắc nhở rồi xác nhận check-in. 4. Lưu checkedInAt, hiện xác nhận và sẵn sàng nhập mã tiếp theo. |
| Luồng thay thế / ngoại lệ | Cho nhập tay khi camera không có/bị từ chối. Mã không tồn tại trả 404; vé chưa trả, đã huỷ, chờ hoàn tiền, ngoài khung giờ hoặc đã dùng trả 409. Lần check-in thứ hai đồng thời thất bại. Lỗi thông tin bổ sung không được che vé. |
| Hậu điều kiện | Chỉ lưu một thời điểm check-in; check-in là thuộc tính, không phải trạng thái vé khác. |
| Yêu cầu / ưu tiên | MOB-FR-CHK-01 (H), MOB-FR-CHK-02 (H), MOB-FR-CHK-03 (H), MOB-FR-CHK-04 (H), MOB-FR-CHK-05 (M) |
| Nghiệm thu | Thực hiện AC-01/AC-02 cho mọi FR liên quan với tác nhân đủ quyền. |

### UC-MOB-09 — Thông báo và email giao dịch

| Trường | Đặc tả ca sử dụng |
| --- | --- |
| Tác nhân | Khách hàng; hệ thống backend tạo email/nhắc lịch |
| Mục tiêu | Thông báo và email giao dịch |
| Tiền điều kiện | Có phiên tài khoản để xem lịch sử trong ứng dụng; cấu hình SMTP/xử lý sự kiện để gửi thật. |
| Kích hoạt | Mở màn liên quan hoặc thực hiện thao tác/sự kiện đã nêu. |
| Luồng chính | 1. Tải danh sách thông báo và số chưa đọc của khách. 2. Mở chi tiết, đánh dấu đã đọc hoặc đánh dấu tất cả thông báo của mình. 3. Mở vé liên quan thuộc mình. 4. Nhận email và lịch sử trong ứng dụng do sự kiện/nhắc lịch backend tạo; chưa có tích hợp thông báo đẩy điện thoại. |
| Luồng thay thế / ngoại lệ | Kiểm tra chủ sở hữu từ chối dữ liệu người khác; có trạng thái tải/rỗng/lỗi-thử lại. Gửi lỗi giữ FAILED để thử lại và không hoàn tác thanh toán. Chống lặp sự kiện giảm gửi trùng nhưng SMTP cùng commit database không bảo đảm giao dịch đúng một lần tuyệt đối. |
| Hậu điều kiện | Trạng thái đọc/số chưa đọc khớp phản hồi; gửi thành công được ghi riêng với trạng thái vé/thanh toán. |
| Yêu cầu / ưu tiên | MOB-FR-NOTI-01 (M), MOB-FR-NOTI-04 (M), MOB-FR-NOTI-06 (H), MOB-FR-NOTI-07 (H), MOB-FR-NOTI-08 (M), MOB-FR-NOTI-09 (M) |
| Nghiệm thu | Thực hiện AC-01/AC-02 cho mọi FR liên quan với tác nhân đủ quyền. |

## 11. Yêu cầu giao diện bên ngoài

| Giao diện | Hợp đồng |
| --- | --- |
| Client/gateway | REST/JSON UTF-8; Accept application/json; Content-Type application/json khi có body; JWT Bearer cho lời gọi bảo vệ. Client không nối PostgreSQL hoặc cổng service riêng. |
| PayOS | URL thanh toán/VietQR qua backend; webhook có chữ ký; client xác minh server thay vì tin chuyển hướng. Client không thu thập dữ liệu thẻ. |
| SMTP / RabbitMQ | Chỉ server gửi OTP/vé/hoàn và sự kiện đã commit; client đọc API thông báo, không nhận broker. |
| Thiết bị/trình duyệt | Camera mobile_scanner; ứng dụng ngoài url_launcher; share_plus/clipboard; plugin lưu bảo mật. Giữ nhập mã sau từ chối camera. |

## 12. Yêu cầu giao diện / Màn hình

Mã màn đại diện trang có route hoặc trang đầu vai trò. Lớp quét, sửa đánh giá, hộp hồ sơ/mật khẩu và đổi loại ghế là thành phần, không phải route tự thêm. Danh sách FR/API liên kết theo khu chức năng; mục 13 cung cấp hợp đồng endpoint chính xác.

### MOB-SCR-LOGIN — Đăng nhập

| Trường | Yêu cầu màn hình |
| --- | --- |
| Route | `/login` |
| Tác nhân | Khách chưa đăng nhập/mọi vai trò |
| Mục đích | Đăng nhập |
| Thành phần chính | Email, mật khẩu, lỗi trường, liên kết khôi phục/đăng ký |
| Thao tác | Đăng nhập; khôi phục mật khẩu; đăng ký trên trang khách |
| Điều hướng | Trang đầu theo vai trò hoặc đích chờ; /forgot-password; /register (chỉ trang khách) |
| FR liên quan | MOB-FR-AUTH-02, MOB-FR-AUTH-03, MOB-FR-AUTH-06, MOB-FR-AUTH-12, MOB-FR-AUTH-13, MOB-FR-NAV-01 |
| Khu API liên quan | MOB-API-006, MOB-API-008, MOB-API-010, MOB-API-011, MOB-API-013 |
| Nguồn | [Cinema_Mobile/lib/features/auth/screens/login_screen.dart](../Cinema_Mobile/lib/features/auth/screens/login_screen.dart) |

### MOB-SCR-REGISTER — Đăng ký

| Trường | Yêu cầu màn hình |
| --- | --- |
| Route | `/register` |
| Tác nhân | Khách chưa đăng nhập |
| Mục đích | Đăng ký |
| Thành phần chính | Tên, email, điện thoại, mật khẩu và xác nhận |
| Thao tác | Kiểm tra và đăng ký |
| Điều hướng | /login → /register → /verify-email |
| FR liên quan | MOB-FR-AUTH-01, MOB-FR-AUTH-08, MOB-FR-AUTH-13 |
| Khu API liên quan | MOB-API-006, MOB-API-011, MOB-API-013 |
| Nguồn | [Cinema_Mobile/lib/features/auth/screens/register_screen.dart](../Cinema_Mobile/lib/features/auth/screens/register_screen.dart) |

### MOB-SCR-VERIFY — Xác thực email

| Trường | Yêu cầu màn hình |
| --- | --- |
| Route | `/verify-email` |
| Tác nhân | Khách chưa đăng nhập |
| Mục đích | Xác thực email |
| Thành phần chính | Ô OTP; đếm ngược gửi lại; ngữ cảnh mật khẩu đã đăng ký |
| Thao tác | Xác thực hoặc gửi lại |
| Điều hướng | Đăng ký/đăng nhập → OTP → trang đầu theo vai trò |
| FR liên quan | MOB-FR-AUTH-07, MOB-FR-AUTH-08, MOB-FR-AUTH-14 |
| Khu API liên quan | MOB-API-006, MOB-API-010, MOB-API-011, MOB-API-012, MOB-API-014 |
| Nguồn | [Cinema_Mobile/lib/features/auth/screens/verify_email_screen.dart](../Cinema_Mobile/lib/features/auth/screens/verify_email_screen.dart) |

### MOB-SCR-FORGOT — Quên mật khẩu

| Trường | Yêu cầu màn hình |
| --- | --- |
| Route | `/forgot-password` |
| Tác nhân | Khách chưa đăng nhập/chủ tài khoản |
| Mục đích | Quên mật khẩu |
| Thành phần chính | Ô email và trạng thái gửi |
| Thao tác | Yêu cầu OTP đặt lại |
| Điều hướng | Đăng nhập/Hồ sơ → yêu cầu đặt lại → /reset-password |
| FR liên quan | MOB-FR-AUTH-09, MOB-FR-AUTH-13, MOB-FR-AUTH-14 |
| Khu API liên quan | MOB-API-005, MOB-API-006, MOB-API-010, MOB-API-011, MOB-API-012, MOB-API-013 |
| Nguồn | [Cinema_Mobile/lib/features/auth/screens/forgot_password_screen.dart](../Cinema_Mobile/lib/features/auth/screens/forgot_password_screen.dart) |

### MOB-SCR-RESET — Đặt lại mật khẩu

| Trường | Yêu cầu màn hình |
| --- | --- |
| Route | `/reset-password` |
| Tác nhân | Người nhận OTP |
| Mục đích | Đặt lại mật khẩu |
| Thành phần chính | OTP, mật khẩu mới và xác nhận |
| Thao tác | Đặt lại bằng mã email |
| Điều hướng | Quên mật khẩu → đặt lại → đăng nhập |
| FR liên quan | MOB-FR-AUTH-09, MOB-FR-AUTH-13, MOB-FR-AUTH-14 |
| Khu API liên quan | MOB-API-005, MOB-API-006, MOB-API-010, MOB-API-011, MOB-API-012, MOB-API-013 |
| Nguồn | [Cinema_Mobile/lib/features/auth/screens/reset_password_screen.dart](../Cinema_Mobile/lib/features/auth/screens/reset_password_screen.dart) |

### MOB-SCR-HOME — Trang chủ khách

| Trường | Yêu cầu màn hình |
| --- | --- |
| Route | `/home` |
| Tác nhân | Khách chưa đăng nhập/khách hàng |
| Mục đích | Trang chủ khách |
| Thành phần chính | Tab đang/sắp chiếu; tìm kiếm; lọc thể loại; thẻ phim; điều hướng tài khoản/thông báo |
| Thao tác | Tìm/lọc; mở phim |
| Điều hướng | /home → /movies/{id}; điều hướng khách tới vé, thanh toán, thông báo, hồ sơ |
| FR liên quan | MOB-FR-MOV-03, MOB-FR-MOV-04, MOB-FR-MOV-10, MOB-FR-NOTI-09, MOB-FR-MEDIA-01 |
| Khu API liên quan | MOB-API-024, MOB-API-025, MOB-API-026, MOB-API-027, MOB-API-028, MOB-API-030, MOB-API-031 |
| Nguồn | [Cinema_Mobile/lib/features/home/screens/home_screen.dart](../Cinema_Mobile/lib/features/home/screens/home_screen.dart) |

### MOB-SCR-MOVIE — Chi tiết phim

| Trường | Yêu cầu màn hình |
| --- | --- |
| Route | `/movies/{id}` |
| Tác nhân | Khách chưa đăng nhập/khách hàng |
| Mục đích | Chi tiết phim |
| Thành phần chính | Ảnh, tuổi, thông tin phim, diễn viên/đạo diễn, trailer, tổng hợp đánh giá, suất bảy ngày |
| Thao tác | Mở trailer; chọn suất; đọc đánh giá |
| Điều hướng | Trang chủ → phim → /showtimes/{id}/seats |
| FR liên quan | MOB-FR-MOV-02, MOB-FR-MOV-08, MOB-FR-MOV-09, MOB-FR-MOV-11, MOB-FR-MOV-12, MOB-FR-SHOW-03, MOB-FR-SHOW-06, MOB-FR-SHOW-07, MOB-FR-SHOW-08, MOB-FR-SHOW-13 |
| Khu API liên quan | MOB-API-002, MOB-API-003, MOB-API-024, MOB-API-039, MOB-API-040, MOB-API-041, MOB-API-042 |
| Nguồn | [Cinema_Mobile/lib/features/movie/screens/movie_detail_screen.dart](../Cinema_Mobile/lib/features/movie/screens/movie_detail_screen.dart) |

### MOB-SCR-SEATS — Chọn ghế

| Trường | Yêu cầu màn hình |
| --- | --- |
| Route | `/showtimes/{id}/seats` |
| Tác nhân | Khách hàng |
| Mục đích | Chọn ghế |
| Thành phần chính | Hàng, chú giải loại/đã chiếm, ghế chọn, giá cặp, tổng |
| Thao tác | Chọn/bỏ chọn ghế trống; làm mới |
| Điều hướng | Phim → ghế → /showtimes/{id}/summary |
| FR liên quan | MOB-FR-SEAT-03, MOB-FR-SHOW-03, MOB-FR-SHOW-13, MOB-FR-BOOK-07, MOB-FR-BOOK-08, MOB-FR-BOOK-09, MOB-FR-BOOK-11 |
| Khu API liên quan | MOB-API-001, MOB-API-002, MOB-API-019, MOB-API-021 |
| Nguồn | [Cinema_Mobile/lib/features/seat/screens/seat_selection_screen.dart](../Cinema_Mobile/lib/features/seat/screens/seat_selection_screen.dart) |

### MOB-SCR-SUMMARY — Xác nhận đặt vé

| Trường | Yêu cầu màn hình |
| --- | --- |
| Route | `/showtimes/{id}/summary` |
| Tác nhân | Khách hàng |
| Mục đích | Xác nhận đặt vé |
| Thành phần chính | BookingDraft, ghế, chọn bắp nước, báo giá khuyến mãi, điểm, xác nhận tuổi |
| Thao tác | Đổi phần thêm; giữ ghế |
| Điều hướng | Ghế → xác nhận → thanh toán vé; thiếu dữ liệu tạm → ghế |
| FR liên quan | MOB-FR-MOV-09, MOB-FR-BOOK-01, MOB-FR-BOOK-09, MOB-FR-BOOK-13, MOB-FR-BOOK-15, MOB-FR-BOOK-17 |
| Khu API liên quan | MOB-API-021, MOB-API-022, MOB-API-023, MOB-API-024, MOB-API-038 |
| Nguồn | [Cinema_Mobile/lib/features/booking/screens/booking_summary_screen.dart](../Cinema_Mobile/lib/features/booking/screens/booking_summary_screen.dart) |

### MOB-SCR-PAYMENT — Thanh toán

| Trường | Yêu cầu màn hình |
| --- | --- |
| Route | `/bookings/{id}/payment` |
| Tác nhân | Khách hàng |
| Mục đích | Thanh toán |
| Thành phần chính | Vé/chi tiết tiền; đếm ngược; link PayOS; tự kiểm tra |
| Thao tác | Mở/tiếp tục PayOS; trở về và đối soát |
| Điều hướng | Xác nhận/vé → thanh toán → PayOS ngoài → kết quả |
| FR liên quan | MOB-FR-BOOK-05, MOB-FR-BOOK-10, MOB-FR-PAY-01, MOB-FR-PAY-02, MOB-FR-PAY-11 |
| Khu API liên quan | MOB-API-017, MOB-API-034, MOB-API-035 |
| Nguồn | [Cinema_Mobile/lib/features/payment/screens/payment_screen.dart](../Cinema_Mobile/lib/features/payment/screens/payment_screen.dart) |

### MOB-SCR-RESULT — Kết quả thanh toán

| Trường | Yêu cầu màn hình |
| --- | --- |
| Route | `/bookings/{id}/result` |
| Tác nhân | Khách hàng |
| Mục đích | Kết quả thanh toán |
| Thành phần chính | Xác minh/đang tải, kết quả thành công/chờ/thất bại |
| Thao tác | Tải lại kết quả server; mở vé |
| Điều hướng | PayOS/thanh toán → kết quả → /bookings/{id} |
| FR liên quan | MOB-FR-BOOK-02, MOB-FR-BOOK-05, MOB-FR-PAY-02, MOB-FR-PAY-08 |
| Khu API liên quan | MOB-API-017, MOB-API-034 |
| Nguồn | [Cinema_Mobile/lib/features/payment/screens/payment_result_screen.dart](../Cinema_Mobile/lib/features/payment/screens/payment_result_screen.dart) |

### MOB-SCR-TICKETS — Vé của tôi

| Trường | Yêu cầu màn hình |
| --- | --- |
| Route | `/bookings` |
| Tác nhân | Khách hàng |
| Mục đích | Vé của tôi |
| Thành phần chính | Tab vé hiện tại/lịch sử, thẻ vé, làm mới và trạng thái rỗng/lỗi |
| Thao tác | Mở vé; làm mới |
| Điều hướng | Điều hướng khách → vé → /bookings/{id} |
| FR liên quan | MOB-FR-BOOK-04 |
| Khu API liên quan | MOB-API-020 |
| Nguồn | [Cinema_Mobile/lib/features/booking/screens/my_bookings_screen.dart](../Cinema_Mobile/lib/features/booking/screens/my_bookings_screen.dart) |

### MOB-SCR-TICKET — Chi tiết vé

| Trường | Yêu cầu màn hình |
| --- | --- |
| Route | `/bookings/{id}` |
| Tác nhân | Khách hàng |
| Mục đích | Chi tiết vé |
| Thành phần chính | Ghế, phần thêm, tiền, QR, checkedInAt, huỷ/hoàn, đánh giá và chia sẻ/lịch |
| Thao tác | Trả vé chờ; huỷ/yêu cầu hoàn; đánh giá sau check-in; chia sẻ/lịch |
| Điều hướng | Vé/thông báo → chi tiết → thanh toán hoặc quay lại |
| FR liên quan | MOB-FR-MOV-12, MOB-FR-BOOK-02, MOB-FR-BOOK-05, MOB-FR-BOOK-06, MOB-FR-BOOK-13, MOB-FR-BOOK-15, MOB-FR-BOOK-17, MOB-FR-BOOK-19, MOB-FR-PAY-03, MOB-FR-PAY-06, MOB-FR-REF-01, MOB-FR-REF-05, MOB-FR-REF-06, MOB-FR-CHK-01, MOB-FR-CHK-05 |
| Khu API liên quan | MOB-API-002, MOB-API-015, MOB-API-017, MOB-API-018, MOB-API-021, MOB-API-022, MOB-API-023, MOB-API-033, MOB-API-034, MOB-API-037, MOB-API-038, MOB-API-039, MOB-API-040, MOB-API-041, MOB-API-042 |
| Nguồn | [Cinema_Mobile/lib/features/booking/screens/booking_detail_screen.dart](../Cinema_Mobile/lib/features/booking/screens/booking_detail_screen.dart) |

### MOB-SCR-PAYHISTORY — Lịch sử thanh toán

| Trường | Yêu cầu màn hình |
| --- | --- |
| Route | `/payments` |
| Tác nhân | Khách hàng |
| Mục đích | Lịch sử thanh toán |
| Thành phần chính | Dòng giao dịch của mình, số tiền, trạng thái |
| Thao tác | Làm mới; xem vé liên quan khi có |
| Điều hướng | Điều hướng khách → thanh toán → vé liên quan |
| FR liên quan | MOB-FR-PAY-03, MOB-FR-PAY-04 |
| Khu API liên quan | MOB-API-037 |
| Nguồn | [Cinema_Mobile/lib/features/payment/screens/payment_history_screen.dart](../Cinema_Mobile/lib/features/payment/screens/payment_history_screen.dart) |

### MOB-SCR-NOTIFICATIONS — Thông báo

| Trường | Yêu cầu màn hình |
| --- | --- |
| Route | `/notifications` |
| Tác nhân | Khách hàng |
| Mục đích | Thông báo |
| Thành phần chính | Danh sách thông báo, số chưa đọc, đánh dấu tất cả |
| Thao tác | Mở thông báo; đánh dấu tất cả |
| Điều hướng | Chuông/điều hướng khách → /notifications/{id} |
| FR liên quan | MOB-FR-NOTI-01, MOB-FR-NOTI-09 |
| Khu API liên quan | MOB-API-028, MOB-API-030, MOB-API-031, MOB-API-032 |
| Nguồn | [Cinema_Mobile/lib/features/notification/screens/notification_list_screen.dart](../Cinema_Mobile/lib/features/notification/screens/notification_list_screen.dart) |

### MOB-SCR-NOTIFICATION — Chi tiết thông báo

| Trường | Yêu cầu màn hình |
| --- | --- |
| Route | `/notifications/{id}` |
| Tác nhân | Khách hàng |
| Mục đích | Chi tiết thông báo |
| Thành phần chính | Tiêu đề, nội dung, trạng thái đọc, vé liên quan |
| Thao tác | Đánh dấu khi mở; mở vé |
| Điều hướng | Thông báo → chi tiết → /bookings/{id} |
| FR liên quan | MOB-FR-NOTI-04, MOB-FR-NOTI-09 |
| Khu API liên quan | MOB-API-028, MOB-API-029, MOB-API-030, MOB-API-031 |
| Nguồn | [Cinema_Mobile/lib/features/notification/screens/notification_detail_screen.dart](../Cinema_Mobile/lib/features/notification/screens/notification_detail_screen.dart) |

### MOB-SCR-PROFILE — Tài khoản và thành viên

| Trường | Yêu cầu màn hình |
| --- | --- |
| Route | `/profile` |
| Tác nhân | Khách hàng |
| Mục đích | Tài khoản và thành viên |
| Thành phần chính | Danh tính, hộp sửa hồ sơ/mật khẩu, thẻ/lịch sử thành viên, đăng xuất |
| Thao tác | Sửa tên/điện thoại; đổi/khôi phục mật khẩu; đăng xuất |
| Điều hướng | Điều hướng khách → hồ sơ; khôi phục mật khẩu → quên/đặt lại |
| FR liên quan | MOB-FR-AUTH-10, MOB-FR-AUTH-11, MOB-FR-AUTH-16, MOB-FR-AUTH-17, MOB-FR-BOOK-17 |
| Khu API liên quan | MOB-API-004, MOB-API-007, MOB-API-008, MOB-API-009, MOB-API-010, MOB-API-021, MOB-API-023 |
| Nguồn | [Cinema_Mobile/lib/features/profile/screens/profile_screen.dart](../Cinema_Mobile/lib/features/profile/screens/profile_screen.dart) |

### MOB-SCR-MGT-LANDING — Trang đầu tài khoản quản lý

| Trường | Yêu cầu màn hình |
| --- | --- |
| Route | `/home (management account)` |
| Tác nhân | Nhân viên/quản trị viên |
| Mục đích | Trang đầu tài khoản quản lý |
| Thành phần chính | Giải thích vai trò; liên kết web quản trị đã cấu hình; check-in vé; đăng xuất |
| Thao tác | Mở web đã cấu hình hoặc check-in điện thoại |
| Điều hướng | Đăng nhập quản lý → trang đầu → /staff/check-in |
| FR liên quan | MOB-FR-AUTH-05, MOB-FR-AUTH-10, MOB-FR-CHK-04 |
| Khu API liên quan | MOB-API-007, MOB-API-008, MOB-API-010, MOB-API-016, MOB-API-018 |
| Nguồn | [Cinema_Mobile/lib/features/profile/screens/management_account_screen.dart](../Cinema_Mobile/lib/features/profile/screens/management_account_screen.dart) |

### MOB-SCR-CHECKIN — Check-in vé

| Trường | Yêu cầu màn hình |
| --- | --- |
| Route | `/staff/check-in` |
| Tác nhân | Nhân viên/quản trị viên |
| Mục đích | Check-in vé |
| Thành phần chính | Ô mã; lớp quét camera; chi tiết vé; nhắc tuổi; nút cho vào |
| Thao tác | Quét/nhập; tra vé; check-in một lần |
| Điều hướng | Trang đầu/điều hướng quản lý → check-in → vé kế tiếp |
| FR liên quan | MOB-FR-MOV-09, MOB-FR-CHK-02, MOB-FR-CHK-03, MOB-FR-CHK-04, MOB-FR-CHK-05 |
| Khu API liên quan | MOB-API-016, MOB-API-017, MOB-API-018, MOB-API-024 |
| Nguồn | [Cinema_Mobile/lib/features/staff/screens/staff_check_in_screen.dart](../Cinema_Mobile/lib/features/staff/screens/staff_check_in_screen.dart) |

Màn xác thực web dùng lại giữa hai điểm vào nhưng đăng nhập quản trị tắt đăng ký. Sửa hồ sơ/đổi mật khẩu là hộp thoại. Trang đầu quản lý điện thoại chọn theo vai trò, không phải URL quản trị riêng.

## 13. Yêu cầu API

Endpoint được trích từ thuộc tính HTTP controller, chỉ bỏ ràng buộc :long trong ký hiệu tham số. Client gọi trực tiếp nghĩa là tìm thấy phương thức/đường dẫn khớp trong service Dart theo phạm vi; chỉ API/chung nghĩa là có controller nhưng chưa thấy lời gọi client riêng. Policy controller phải kết hợp gateway và chủ bản ghi.

| ID | Phương thức / endpoint | Policy controller | Hợp đồng đầu vào | Cách dùng / trạng thái | Bằng chứng |
| --- | --- | --- | --- | --- | --- |
| MOB-API-001 | `GET /api/seats/room/{roomId}` | authenticated | — | Client gọi trực tiếp; đã triển khai | [Cinema_BE/MovieService/MovieService/Controllers/SeatsController.cs:36](../Cinema_BE/MovieService/MovieService/Controllers/SeatsController.cs#L36) |
| MOB-API-002 | `GET /api/showtimes/{showtimeId}` | public | — | Client gọi trực tiếp; đã triển khai | [Cinema_BE/MovieService/MovieService/Controllers/ShowtimesController.cs:41](../Cinema_BE/MovieService/MovieService/Controllers/ShowtimesController.cs#L41) |
| MOB-API-003 | `GET /api/showtimes/movie/{movieId}/open` | public | Query: int pageNumber; Query: int pageSize; Query: string sortBy; Query: string sortDir | Client gọi trực tiếp; đã triển khai | [Cinema_BE/MovieService/MovieService/Controllers/ShowtimesController.cs:160](../Cinema_BE/MovieService/MovieService/Controllers/ShowtimesController.cs#L160) |
| MOB-API-004 | `POST /api/v1/auth/change-password` | public | Body: ChangePasswordRequest request | Client gọi trực tiếp; đã triển khai | [Cinema_BE/AuthService/AuthService/Controllers/AuthController.cs:105](../Cinema_BE/AuthService/AuthService/Controllers/AuthController.cs#L105) |
| MOB-API-005 | `POST /api/v1/auth/forgot-password` | public | Body: EmailRequest request | Client gọi trực tiếp; đã triển khai | [Cinema_BE/AuthService/AuthService/Controllers/AuthController.cs:54](../Cinema_BE/AuthService/AuthService/Controllers/AuthController.cs#L54) |
| MOB-API-006 | `POST /api/v1/auth/login` | public | Body: LoginRequest request | Client gọi trực tiếp; đã triển khai | [Cinema_BE/AuthService/AuthService/Controllers/AuthController.cs:46](../Cinema_BE/AuthService/AuthService/Controllers/AuthController.cs#L46) |
| MOB-API-007 | `POST /api/v1/auth/logout` | public | Body: RefreshTokenRequest request | Client gọi trực tiếp; đã triển khai | [Cinema_BE/AuthService/AuthService/Controllers/AuthController.cs:79](../Cinema_BE/AuthService/AuthService/Controllers/AuthController.cs#L79) |
| MOB-API-008 | `GET /api/v1/auth/me` | public | — | Client gọi trực tiếp; đã triển khai | [Cinema_BE/AuthService/AuthService/Controllers/AuthController.cs:88](../Cinema_BE/AuthService/AuthService/Controllers/AuthController.cs#L88) |
| MOB-API-009 | `PUT /api/v1/auth/me` | public | Body: UpdateProfileRequest request | Client gọi trực tiếp; đã triển khai | [Cinema_BE/AuthService/AuthService/Controllers/AuthController.cs:97](../Cinema_BE/AuthService/AuthService/Controllers/AuthController.cs#L97) |
| MOB-API-010 | `POST /api/v1/auth/refresh` | public | Body: RefreshTokenRequest request | Client gọi trực tiếp; đã triển khai | [Cinema_BE/AuthService/AuthService/Controllers/AuthController.cs:70](../Cinema_BE/AuthService/AuthService/Controllers/AuthController.cs#L70) |
| MOB-API-011 | `POST /api/v1/auth/register` | public | Body: RegisterRequest request | Client gọi trực tiếp; đã triển khai | [Cinema_BE/AuthService/AuthService/Controllers/AuthController.cs:22](../Cinema_BE/AuthService/AuthService/Controllers/AuthController.cs#L22) |
| MOB-API-012 | `POST /api/v1/auth/resend-verification` | public | Body: EmailRequest request | Client gọi trực tiếp; đã triển khai | [Cinema_BE/AuthService/AuthService/Controllers/AuthController.cs:38](../Cinema_BE/AuthService/AuthService/Controllers/AuthController.cs#L38) |
| MOB-API-013 | `POST /api/v1/auth/reset-password` | public | Body: ResetPasswordRequest request | Client gọi trực tiếp; đã triển khai | [Cinema_BE/AuthService/AuthService/Controllers/AuthController.cs:62](../Cinema_BE/AuthService/AuthService/Controllers/AuthController.cs#L62) |
| MOB-API-014 | `POST /api/v1/auth/verify-email` | public | Body: VerifyEmailRequest request | Client gọi trực tiếp; đã triển khai | [Cinema_BE/AuthService/AuthService/Controllers/AuthController.cs:30](../Cinema_BE/AuthService/AuthService/Controllers/AuthController.cs#L30) |
| MOB-API-015 | `POST /api/v1/bookings/{id}/cancel` | Policy = AuthorizationPolicies.UserOrStaff | Query: string? reason | Client gọi trực tiếp; đã triển khai | [Cinema_BE/BookingService/BookingService/Controllers/BookingController.cs:201](../Cinema_BE/BookingService/BookingService/Controllers/BookingController.cs#L201) |
| MOB-API-016 | `POST /api/v1/bookings/{id}/check-in` | Policy = AuthorizationPolicies.StaffOrAdmin | — | Client gọi trực tiếp; đã triển khai | [Cinema_BE/BookingService/BookingService/Controllers/BookingController.cs:147](../Cinema_BE/BookingService/BookingService/Controllers/BookingController.cs#L147) |
| MOB-API-017 | `GET /api/v1/bookings/{id}` | Policy = AuthorizationPolicies.AnyRole | — | Client gọi trực tiếp; đã triển khai | [Cinema_BE/BookingService/BookingService/Controllers/BookingController.cs:37](../Cinema_BE/BookingService/BookingService/Controllers/BookingController.cs#L37) |
| MOB-API-018 | `GET /api/v1/bookings/code/{bookingCode}` | Policy = AuthorizationPolicies.StaffOrAdmin | — | Client gọi trực tiếp; đã triển khai | [Cinema_BE/BookingService/BookingService/Controllers/BookingController.cs:137](../Cinema_BE/BookingService/BookingService/Controllers/BookingController.cs#L137) |
| MOB-API-019 | `GET /api/v1/bookings/showtime/{showtimeId}/occupied-seats` | Policy = AuthorizationPolicies.AnyRole | — | Client gọi trực tiếp; đã triển khai | [Cinema_BE/BookingService/BookingService/Controllers/BookingController.cs:100](../Cinema_BE/BookingService/BookingService/Controllers/BookingController.cs#L100) |
| MOB-API-020 | `GET /api/v1/bookings/user/{userId}` | Policy = AuthorizationPolicies.AnyRole | Query: int page; Query: int size; Query: string sortBy; Query: string sortDir | Client gọi trực tiếp; đã triển khai | [Cinema_BE/BookingService/BookingService/Controllers/BookingController.cs:50](../Cinema_BE/BookingService/BookingService/Controllers/BookingController.cs#L50) |
| MOB-API-021 | `POST /api/v1/bookings` | Policy = AuthorizationPolicies.AnyRole | Body: BookingRequest request | Client gọi trực tiếp; đã triển khai | [Cinema_BE/BookingService/BookingService/Controllers/BookingController.cs:156](../Cinema_BE/BookingService/BookingService/Controllers/BookingController.cs#L156) |
| MOB-API-022 | `GET /api/v1/concessions` | public | Query: bool includeInactive | Client gọi trực tiếp; đã triển khai | [Cinema_BE/BookingService/BookingService/Controllers/ConcessionController.cs:24](../Cinema_BE/BookingService/BookingService/Controllers/ConcessionController.cs#L24) |
| MOB-API-023 | `GET /api/v1/loyalty/me` | authenticated | — | Client gọi trực tiếp; đã triển khai | [Cinema_BE/BookingService/BookingService/Controllers/LoyaltyController.cs:24](../Cinema_BE/BookingService/BookingService/Controllers/LoyaltyController.cs#L24) |
| MOB-API-024 | `GET /api/v1/movies/{id}` | public | — | Client gọi trực tiếp; đã triển khai | [Cinema_BE/MovieService/MovieService/Controllers/MoviesController.cs:34](../Cinema_BE/MovieService/MovieService/Controllers/MoviesController.cs#L34) |
| MOB-API-025 | `GET /api/v1/movies/browse` | public | Query: string? when; Query: string? genre; Query: string? keyword; Query: int page; Query: int size | Client gọi trực tiếp; đã triển khai | [Cinema_BE/MovieService/MovieService/Controllers/MoviesController.cs:57](../Cinema_BE/MovieService/MovieService/Controllers/MoviesController.cs#L57) |
| MOB-API-026 | `GET /api/v1/movies/genres` | public | — | Client gọi trực tiếp; đã triển khai | [Cinema_BE/MovieService/MovieService/Controllers/MoviesController.cs:70](../Cinema_BE/MovieService/MovieService/Controllers/MoviesController.cs#L70) |
| MOB-API-027 | `GET /api/v1/movies/status/{status}` | public | Query: int page; Query: int size; Query: string sortBy; Query: string sortDir | Client gọi trực tiếp; đã triển khai | [Cinema_BE/MovieService/MovieService/Controllers/MoviesController.cs:42](../Cinema_BE/MovieService/MovieService/Controllers/MoviesController.cs#L42) |
| MOB-API-028 | `PATCH /api/v1/notifications/{id}/read` | Policy = AuthorizationPolicies.AnyRole | — | Client gọi trực tiếp; đã triển khai | [Cinema_BE/BookingService/BookingService/Controllers/NotificationController.cs:77](../Cinema_BE/BookingService/BookingService/Controllers/NotificationController.cs#L77) |
| MOB-API-029 | `GET /api/v1/notifications/{id}` | Policy = AuthorizationPolicies.AnyRole | — | Client gọi trực tiếp; đã triển khai | [Cinema_BE/BookingService/BookingService/Controllers/NotificationController.cs:36](../Cinema_BE/BookingService/BookingService/Controllers/NotificationController.cs#L36) |
| MOB-API-030 | `POST /api/v1/notifications/read-all` | Policy = AuthorizationPolicies.AnyRole | — | Client gọi trực tiếp; đã triển khai | [Cinema_BE/BookingService/BookingService/Controllers/NotificationController.cs:89](../Cinema_BE/BookingService/BookingService/Controllers/NotificationController.cs#L89) |
| MOB-API-031 | `GET /api/v1/notifications/unread-count` | Policy = AuthorizationPolicies.AnyRole | — | Client gọi trực tiếp; đã triển khai | [Cinema_BE/BookingService/BookingService/Controllers/NotificationController.cs:67](../Cinema_BE/BookingService/BookingService/Controllers/NotificationController.cs#L67) |
| MOB-API-032 | `GET /api/v1/notifications/user/{userId}` | Policy = AuthorizationPolicies.AnyRole | Query: int page; Query: int size; Query: string sortBy; Query: string sortDir | Client gọi trực tiếp; đã triển khai | [Cinema_BE/BookingService/BookingService/Controllers/NotificationController.cs:49](../Cinema_BE/BookingService/BookingService/Controllers/NotificationController.cs#L49) |
| MOB-API-033 | `GET /api/v1/payments/{id}/refund` | Policy = AuthorizationPolicies.AnyRole | — | Client gọi trực tiếp; đã triển khai | [Cinema_BE/BookingService/BookingService/Controllers/PaymentController.cs:208](../Cinema_BE/BookingService/BookingService/Controllers/PaymentController.cs#L208) |
| MOB-API-034 | `POST /api/v1/payments/payos/{orderCode}/verify` | Policy = AuthorizationPolicies.AnyRole | Query: string? recipientEmail | Client gọi trực tiếp; đã triển khai | [Cinema_BE/BookingService/BookingService/Controllers/PaymentController.cs:147](../Cinema_BE/BookingService/BookingService/Controllers/PaymentController.cs#L147) |
| MOB-API-035 | `POST /api/v1/payments/payos/checkout` | Policy = AuthorizationPolicies.AnyRole | Body: PayOsCreateRequest request | Client gọi trực tiếp; đã triển khai | [Cinema_BE/BookingService/BookingService/Controllers/PaymentController.cs:122](../Cinema_BE/BookingService/BookingService/Controllers/PaymentController.cs#L122) |
| MOB-API-036 | `POST /api/v1/payments/payos/webhook` | public | Body: JsonElement body | Backend chung/chỉ API; đã triển khai | [Cinema_BE/BookingService/BookingService/Controllers/PaymentController.cs:172](../Cinema_BE/BookingService/BookingService/Controllers/PaymentController.cs#L172) |
| MOB-API-037 | `GET /api/v1/payments/user/{userId}` | Policy = AuthorizationPolicies.AnyRole | Query: int page; Query: int size; Query: string sortBy; Query: string sortDir | Client gọi trực tiếp; đã triển khai | [Cinema_BE/BookingService/BookingService/Controllers/PaymentController.cs:70](../Cinema_BE/BookingService/BookingService/Controllers/PaymentController.cs#L70) |
| MOB-API-038 | `POST /api/v1/promotions/quote` | authenticated | Body: PromotionQuoteRequest request | Client gọi trực tiếp; đã triển khai | [Cinema_BE/BookingService/BookingService/Controllers/PromotionController.cs:33](../Cinema_BE/BookingService/BookingService/Controllers/PromotionController.cs#L33) |
| MOB-API-039 | `DELETE /api/v1/reviews/{id}` | authenticated | — | Client gọi trực tiếp; đã triển khai | [Cinema_BE/BookingService/BookingService/Controllers/MovieReviewController.cs:58](../Cinema_BE/BookingService/BookingService/Controllers/MovieReviewController.cs#L58) |
| MOB-API-040 | `GET /api/v1/reviews/booking/{bookingId}` | authenticated | — | Client gọi trực tiếp; đã triển khai | [Cinema_BE/BookingService/BookingService/Controllers/MovieReviewController.cs:43](../Cinema_BE/BookingService/BookingService/Controllers/MovieReviewController.cs#L43) |
| MOB-API-041 | `GET /api/v1/reviews/movie/{movieId}` | public | Query: int page; Query: int size | Client gọi trực tiếp; đã triển khai | [Cinema_BE/BookingService/BookingService/Controllers/MovieReviewController.cs:25](../Cinema_BE/BookingService/BookingService/Controllers/MovieReviewController.cs#L25) |
| MOB-API-042 | `POST /api/v1/reviews` | authenticated | Body: MovieReviewRequest request | Client gọi trực tiếp; đã triển khai | [Cinema_BE/BookingService/BookingService/Controllers/MovieReviewController.cs:50](../Cinema_BE/BookingService/BookingService/Controllers/MovieReviewController.cs#L50) |

POST /api/showtimes/{showtimeId}/seats được BookingService gọi nội bộ với token chuyển tiếp. Controller cho người đã xác thực còn route ghi suất chung gateway cần StaffOrAdmin; không coi là lời gọi client khách hàng. Webhook PayOS công khai với JWT nhưng xác thực bằng HMAC. Lời gọi nội bộ và webhook là phụ thuộc, không phải màn điện thoại thêm.

Phân trang theo endpoint: page/size cho nhiều API danh mục/vé/thanh toán; pageNumber/pageSize cho API suất/phòng có khai báo. Kích thước phân trang bị chặn, thường 50; mảng thể loại/menu/ghế/điểm không phải đều phân trang. ApiClient dùng timeout 15 giây và phân tích JSON UTF-8/ProblemDetails. Dạng kết quả theo DTO controller hiện tại.

### Định nghĩa trường yêu cầu

| DTO | Trường / kiểu | Nguồn |
| --- | --- | --- |
| ChangePasswordRequest | CurrentPassword: string; NewPassword: string | [Cinema_BE/AuthService/AuthService/DTOs/Request/ChangePasswordRequest.cs](../Cinema_BE/AuthService/AuthService/DTOs/Request/ChangePasswordRequest.cs) |
| EmailRequest | Email: string | [Cinema_BE/AuthService/AuthService/DTOs/Request/EmailRequest.cs](../Cinema_BE/AuthService/AuthService/DTOs/Request/EmailRequest.cs) |
| LoginRequest | Email: string; Password: string | [Cinema_BE/AuthService/AuthService/DTOs/Request/LoginRequest.cs](../Cinema_BE/AuthService/AuthService/DTOs/Request/LoginRequest.cs) |
| RefreshTokenRequest | RefreshToken: string | [Cinema_BE/AuthService/AuthService/DTOs/Request/RefreshTokenRequest.cs](../Cinema_BE/AuthService/AuthService/DTOs/Request/RefreshTokenRequest.cs) |
| RegisterRequest | Email: string; Password: string; FullName: string; Phone: string? | [Cinema_BE/AuthService/AuthService/DTOs/Request/RegisterRequest.cs](../Cinema_BE/AuthService/AuthService/DTOs/Request/RegisterRequest.cs) |
| ResetPasswordRequest | Email: string; Otp: string; NewPassword: string | [Cinema_BE/AuthService/AuthService/DTOs/Request/ResetPasswordRequest.cs](../Cinema_BE/AuthService/AuthService/DTOs/Request/ResetPasswordRequest.cs) |
| UpdateProfileRequest | FullName: string; Phone: string? | [Cinema_BE/AuthService/AuthService/DTOs/Request/UpdateProfileRequest.cs](../Cinema_BE/AuthService/AuthService/DTOs/Request/UpdateProfileRequest.cs) |
| VerifyEmailRequest | Email: string; Otp: string; Password: string | [Cinema_BE/AuthService/AuthService/DTOs/Request/VerifyEmailRequest.cs](../Cinema_BE/AuthService/AuthService/DTOs/Request/VerifyEmailRequest.cs) |
| BookingRequest | UserId: long?; ShowtimeId: long?; MovieTitle: string?; CustomerEmail: string?; CustomerPhone: string?; ShowTime: DateTime?; Seats: List<SeatRequest>; PromotionCode: string?; UsePoints: int?; Concessions: List<BookingConcessionRequest> | [Cinema_BE/BookingService/BookingService/DTOs/Requests/BookingRequest.cs](../Cinema_BE/BookingService/BookingService/DTOs/Requests/BookingRequest.cs) |
| MovieReviewRequest | BookingId: long?; Rating: int?; Comment: string? | [Cinema_BE/BookingService/BookingService/DTOs/Requests/MovieReviewRequest.cs](../Cinema_BE/BookingService/BookingService/DTOs/Requests/MovieReviewRequest.cs) |
| PayOsCreateRequest | BookingId: long?; UserId: long?; Amount: decimal?; Description: string?; ReturnUrl: string?; CancelUrl: string? | [Cinema_BE/BookingService/BookingService/DTOs/Requests/PayOsCreateRequest.cs](../Cinema_BE/BookingService/BookingService/DTOs/Requests/PayOsCreateRequest.cs) |
| PromotionQuoteRequest | ShowtimeId: long?; TicketAmount: decimal; Tickets: int; Code: string? | [Cinema_BE/BookingService/BookingService/DTOs/Requests/PromotionQuoteRequest.cs](../Cinema_BE/BookingService/BookingService/DTOs/Requests/PromotionQuoteRequest.cs) |

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
| MOB-WF-01 | Đăng ký → xác thực OTP → trang đầu theo vai trò; đăng nhập chưa xác thực sang OTP. Khôi phục lỗi không xác thực tài khoản. |
| MOB-WF-02 | Duyệt → phim → suất mở → ghế → xác nhận phần thêm/mã/điểm/tuổi → tạo giữ PENDING → PayOS → server xác minh → CONFIRMED + thông báo vé. |
| MOB-WF-03 | Tới expiresAt → tác vụ hết hạn (mặc định mỗi 30 giây) → EXPIRED và trả ghế/điểm. Trả muộn lấy lại ghế và xác nhận hoặc tạo hoàn toàn bộ. |
| MOB-WF-04 | Khách huỷ đã trả ≥2 giờ trước suất → REFUND_PENDING giữ ghế → nhân viên web chuyển thủ công/ghi nhận → REFUNDED/CANCELLED. Từ chối đủ điều kiện phục hồi SUCCESS/CONFIRMED. |
| MOB-WF-05 | 1. Quét QR hoặc nhập mã vé rồi nhấn Enter. 2. Tra vé; bổ sung phòng và phân loại tuổi khi lời gọi danh mục thành công. 3. Kiểm tra danh tính/tuổi theo nhắc nhở rồi xác nhận check-in. 4. Lưu checkedInAt, hiện xác nhận và sẵn sàng nhập mã tiếp theo. |

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
| MOB-NFR-SEC-01 | Mật khẩu và OTP băm bằng BCrypt; không trả stack trace hay lỗi nội bộ ra response. | Client hoặc phụ thuộc backend chung |
| MOB-NFR-SEC-02 | JWT ký bằng secret ≥ 32 ký tự; access token 60 phút; refresh token 7 ngày, xoay vòng, thu hồi khi đăng xuất, đặt lại mật khẩu, đổi quyền. | Client hoặc phụ thuộc backend chung |
| MOB-NFR-SEC-03 | Kiểm tra quyền ở cả gateway (theo route) và service (theo dữ liệu, ví dụ chỉ xem vé của mình). | Client hoặc phụ thuộc backend chung |
| MOB-NFR-SEC-04 | Giới hạn tần suất: 100 request / phút / IP cho mọi API, 10 cho API xác thực. | Client hoặc phụ thuộc backend chung |
| MOB-NFR-SEC-05 | Chỉ gateway mở ra mạng; service, PostgreSQL, RabbitMQ, công cụ giám sát chỉ nghe `127.0.0.1`. | Client hoặc phụ thuộc backend chung |
| MOB-NFR-SEC-06 | Secret không nằm trong mã nguồn; chia sẻ bằng SOPS + age. | Client hoặc phụ thuộc backend chung |
| MOB-NFR-SEC-07 | Mọi input được kiểm tra ở server (DataAnnotations + validator); client kiểm tra trước để báo lỗi sớm. | Client hoặc phụ thuộc backend chung |
| MOB-NFR-PERF-01 | Endpoint phân trang giới hạn, thường 50; mảng thể loại/ghế/menu không áp dụng. UI vé chỉ tải trang đầu. SLA thời gian phản hồi/người đồng thời là [CẦN XÁC NHẬN], không phải bảo đảm đã đo. | Client hoặc phụ thuộc backend chung |
| MOB-NFR-PERF-02 | Giữ ghế, xác nhận vé và thu tiền khoá dòng booking (`SELECT … FOR UPDATE`) trong transaction để không bán trùng ghế hay thu tiền hai lần khi nhiều người thao tác cùng lúc. | Client hoặc phụ thuộc backend chung |
| MOB-NFR-REL-01 | Lời gọi MovieService / PayOS: thử lại tối đa 2 lần với lỗi tạm thời (riêng tạo link PayOS không thử lại); circuit breaker mở 15 giây khi lỗi liên tục và trả 503 ngay. | Client hoặc phụ thuộc backend chung |
| MOB-NFR-REL-02 | Outbox: event không mất khi RabbitMQ dừng, gửi bù khi RabbitMQ chạy lại. | Client hoặc phụ thuộc backend chung |
| MOB-NFR-REL-03 | Consumer idempotent; message lỗi thử lại 3 lần rồi chuyển sang DLQ. | Client hoặc phụ thuộc backend chung |
| MOB-NFR-REL-04 | Gateway kiểm tra `/health/live` của service mỗi 10 giây, service chết thì trả 503 ngay. | Client hoặc phụ thuộc backend chung |
| MOB-NFR-OBS-01 | Metrics Prometheus cho HTTP, runtime và nghiệp vụ (booking, payment, refund, outbox); dashboard Grafana "Cinema - Tổng quan". | Client hoặc phụ thuộc backend chung |
| MOB-NFR-OBS-02 | Trace OpenTelemetry → Jaeger, xuyên qua gateway, service, SQL, PayOS và RabbitMQ. | Client hoặc phụ thuộc backend chung |
| MOB-NFR-OBS-03 | Log có TraceId, SpanId, CorrelationId; header `X-Correlation-ID` trên mọi response. | Client hoặc phụ thuộc backend chung |
| MOB-NFR-MAINT-01 | Kiến trúc lớp, DTO, validator, global exception handler ở mọi service; tài liệu trong `docs/`. | Client hoặc phụ thuộc backend chung |
| MOB-NFR-MAINT-02 | CI khai báo test .NET, Flutter analyze/test và build web khách/quản trị. Workflow hiện ghim Flutter 3.47.4 thay mô tả cũ; không khẳng định CI hiện đã đạt. | Client hoặc phụ thuộc backend chung |
| MOB-NFR-DEP-01 | Một lệnh `docker compose up -d --build` chạy toàn bộ backend; giám sát qua profile `monitoring`. | Client hoặc phụ thuộc backend chung |
| MOB-NFR-USE-01 | App khách hỗ trợ Android, web, Windows; trang quản trị tối ưu cho máy tính và vẫn dùng được trên màn hình hẹp. | Client hoặc phụ thuộc backend chung |
| MOB-NFR-COMP-01 | Camera web cần `localhost` hoặc HTTPS; ứng dụng triển khai thật phải dùng HTTPS. | Client hoặc phụ thuộc backend chung |

Cơ chế NFR có thể có bằng chứng code; độ sẵn sàng, thông lượng, khả năng tiếp cận toàn diện và tương thích cần kiểm chứng khi chạy, không được xác lập qua kiểm tra tĩnh.

## 19. Yêu cầu bảo mật

| ID | Yêu cầu bảo mật và kiểm chứng |
| --- | --- |
| MOB-SEC-01 | Từ chối JWT giả/hết hạn/sai issuer và vai trò thiếu quyền tại gateway/service; thử đổi ID với kiểm tra sở hữu. |
| MOB-SEC-02 | Tính lại giá và kiểm tra cặp ghế/menu/mã/điểm trên server; không tin tổng client hoặc tham số chuyển hướng là đã trả. |
| MOB-SEC-03 | Xác minh HMAC PayOS trước tác động; thử webhook lặp, chữ ký sai, đơn lạ và lệch tiền. Giữ khoá nhà cung cấp trong backend. |
| MOB-SEC-04 | Dùng HTTPS triển khai và giới hạn CORS/phơi mạng service riêng. HTTP phát triển không chứng minh TLS production. |
| MOB-SEC-05 | Dùng lớp lưu bảo mật nền tảng; không nhúng secret backend vào client. Xoá/thu hồi thông tin khi đăng xuất/đặt lại và xử lý lưu trữ không đọc được như chưa đăng nhập. |
| MOB-SEC-06 | Mã hoá nội dung người trong email; không lộ stack trace/secret. Quên mật khẩu chung không có nghĩa mọi nơi chống dò email. |

## 20. Yêu cầu kiểm thử

Suy ra test từ AC-01/AC-02 từng FR. Tệp test hiện có chứng minh ý định bao phủ, không phải báo cáo vừa chạy. Fixture backend dùng PostgreSQL/RabbitMQ Testcontainers và giả lập phụ thuộc PayOS/SMTP/danh mục ngoài theo cấu hình. PayOS/SMTP thật, camera/chia sẻ/in cần nghiệm thu có kiểm soát riêng.

| ID | Kiểm thử bắt buộc |
| --- | --- |
| MOB-TEST-01 | Hạn/lần thử/gửi lại OTP; biên mật khẩu UTF-8; dùng lại refresh; khoá/đổi vai trò; sai chủ/vai trò. |
| MOB-TEST-02 | Hai giữ đồng thời một ghế: một thành công, một 409; không ghế/điểm dở dang. Từ chối nửa sweetbox. |
| MOB-TEST-03 | Trả thành công/huỷ/timeout, webhook chữ ký lặp, trả muộn còn/mất ghế; không UI báo đã trả sai. |
| MOB-TEST-04 | Huỷ đúng và quanh hai giờ; hoàn tất/từ chối/mở lại hoàn; một hoàn, giữ ghế đang chờ và đảo điểm. |
| MOB-TEST-05 | Check-in ngay trước/đúng/sau giới hạn giờ; hai quét đồng thời; tra tay sau từ chối camera. |
| MOB-TEST-06 | Khôi phục route, thiếu dữ liệu tạm, tải/rỗng/lỗi, timeout/thử lại, số chưa đọc và trở về từ app ngoài. |

### Bằng chứng test hiện có

| Khu / ca sử dụng | Tệp |
| --- | --- |
| UC-MOB-01 | [Cinema_BE/AuthService/AuthService.Tests/Integration/AccountValidationTests.cs](../Cinema_BE/AuthService/AuthService.Tests/Integration/AccountValidationTests.cs); [Cinema_BE/AuthService/AuthService.Tests/Integration/AuthFlowTests.cs](../Cinema_BE/AuthService/AuthService.Tests/Integration/AuthFlowTests.cs); [Cinema_Mobile/test/account_lock_flow_test.dart](../Cinema_Mobile/test/account_lock_flow_test.dart); [Cinema_Mobile/test/register_validation_test.dart](../Cinema_Mobile/test/register_validation_test.dart) |
| UC-MOB-02 | [Cinema_BE/BookingService/BookingService.Tests/Integration/MovieReviewTests.cs](../Cinema_BE/BookingService/BookingService.Tests/Integration/MovieReviewTests.cs); [Cinema_Mobile/test/age_rating_test.dart](../Cinema_Mobile/test/age_rating_test.dart); [Cinema_Mobile/test/coming_soon_test.dart](../Cinema_Mobile/test/coming_soon_test.dart); [Cinema_Mobile/test/liquid_glass_responsive_preview_test.dart](../Cinema_Mobile/test/liquid_glass_responsive_preview_test.dart); [Cinema_Mobile/test/review_test.dart](../Cinema_Mobile/test/review_test.dart) |
| UC-MOB-03 | [Cinema_BE/MovieService/MovieService.Tests/Integration/SeatTests.cs](../Cinema_BE/MovieService/MovieService.Tests/Integration/SeatTests.cs); [Cinema_Mobile/test/booking_flow_test.dart](../Cinema_Mobile/test/booking_flow_test.dart); [Cinema_Mobile/test/seat_map_test.dart](../Cinema_Mobile/test/seat_map_test.dart) |
| UC-MOB-04 | [Cinema_BE/BookingService/BookingService.Tests/Integration/ShowtimeReminderTests.cs](../Cinema_BE/BookingService/BookingService.Tests/Integration/ShowtimeReminderTests.cs); [Cinema_BE/MovieService/MovieService.Tests/Integration/ShowtimeFormatTests.cs](../Cinema_BE/MovieService/MovieService.Tests/Integration/ShowtimeFormatTests.cs); [Cinema_BE/MovieService/MovieService.Tests/Integration/ShowtimeTests.cs](../Cinema_BE/MovieService/MovieService.Tests/Integration/ShowtimeTests.cs); [Cinema_Mobile/test/showtime_format_test.dart](../Cinema_Mobile/test/showtime_format_test.dart) |
| UC-MOB-05 | [Cinema_BE/BookingService/BookingService.Tests/Integration/BookingFlowTests.cs](../Cinema_BE/BookingService/BookingService.Tests/Integration/BookingFlowTests.cs); [Cinema_BE/BookingService/BookingService.Tests/Integration/ConcessionTests.cs](../Cinema_BE/BookingService/BookingService.Tests/Integration/ConcessionTests.cs); [Cinema_BE/BookingService/BookingService.Tests/Integration/LoyaltyTests.cs](../Cinema_BE/BookingService/BookingService.Tests/Integration/LoyaltyTests.cs); [Cinema_BE/BookingService/BookingService.Tests/Integration/PromotionTests.cs](../Cinema_BE/BookingService/BookingService.Tests/Integration/PromotionTests.cs); [Cinema_Mobile/test/booking_flow_test.dart](../Cinema_Mobile/test/booking_flow_test.dart); [Cinema_Mobile/test/concession_test.dart](../Cinema_Mobile/test/concession_test.dart); [Cinema_Mobile/test/loyalty_test.dart](../Cinema_Mobile/test/loyalty_test.dart); [Cinema_Mobile/test/promotion_test.dart](../Cinema_Mobile/test/promotion_test.dart) |
| UC-MOB-06 | [Cinema_BE/BookingService/BookingService.Tests/Integration/BookingFlowTests.cs](../Cinema_BE/BookingService/BookingService.Tests/Integration/BookingFlowTests.cs); [Cinema_BE/BookingService/BookingService.Tests/Integration/PaymentSummaryTests.cs](../Cinema_BE/BookingService/BookingService.Tests/Integration/PaymentSummaryTests.cs); [Cinema_BE/BookingService/BookingService.Tests/Integration/PayOsOrderCodeTests.cs](../Cinema_BE/BookingService/BookingService.Tests/Integration/PayOsOrderCodeTests.cs); [Cinema_BE/BookingService/BookingService.Tests/Unit/PayOsSignatureTests.cs](../Cinema_BE/BookingService/BookingService.Tests/Unit/PayOsSignatureTests.cs); [Cinema_Mobile/test/booking_flow_test.dart](../Cinema_Mobile/test/booking_flow_test.dart) |
| UC-MOB-07 | [Cinema_BE/BookingService/BookingService.Tests/Integration/RefundTests.cs](../Cinema_BE/BookingService/BookingService.Tests/Integration/RefundTests.cs); [Cinema_Mobile/test/booking_details_ui_test.dart](../Cinema_Mobile/test/booking_details_ui_test.dart); [Cinema_Mobile/test/refund_details_ui_test.dart](../Cinema_Mobile/test/refund_details_ui_test.dart); [Cinema_Mobile/test/staff_booking_details_ui_test.dart](../Cinema_Mobile/test/staff_booking_details_ui_test.dart) |
| UC-MOB-08 | [Cinema_BE/BookingService/BookingService.Tests/Integration/CheckInTests.cs](../Cinema_BE/BookingService/BookingService.Tests/Integration/CheckInTests.cs); [Cinema_Mobile/test/check_in_test.dart](../Cinema_Mobile/test/check_in_test.dart) |
| UC-MOB-09 | [Cinema_BE/BookingService/BookingService.Tests/Integration/ShowtimeReminderTests.cs](../Cinema_BE/BookingService/BookingService.Tests/Integration/ShowtimeReminderTests.cs); [Cinema_Mobile/test/notification_read_test.dart](../Cinema_Mobile/test/notification_read_test.dart) |

## 21. Tiêu chí nghiệm thu

Mọi yêu cầu H phải đạt hai tiêu chí; test bảo mật, sở hữu, tài chính và đồng thời phải đạt. Công bố mọi thiếu sót M/L và khoảng trống triển khai. Tài liệu không chứng nhận lần chạy đạt.

| ID | Điều kiện nghiệm thu |
| --- | --- |
| MOB-ACC-01 | Chứng minh tài khoản → phim → suất → ghế → vé → trả → vé/thông báo với backend thật hoặc fixture có tài liệu. |
| MOB-ACC-02 | Từ chối truy cập trái phép tài khoản khác và tác động bán ghế/check-in/trả trùng đồng thời. |
| MOB-ACC-03 | Chứng minh kết quả hoàn và trả muộn với ghế/điểm đúng, không xác nhận vé sai. |
| MOB-ACC-04 | Kiểm tra điều hướng, tải/lỗi/rỗng và dự phòng thiết bị; công bố giới hạn mục 27. |

## 22. Ma trận truy vết yêu cầu

Ma trận FR đầy đủ. Mã nguồn yêu cầu cho phép truy ngược; NAV/STATE/MEDIA chi tiết hoá từ code. API liên kết theo khu chức năng, không khẳng định mỗi màn gọi mọi thao tác được liệt kê. Test hiện có là ứng viên bao phủ, không phải kết quả đo.

| Yêu cầu / nguồn | Quy tắc nghiệp vụ | Ca sử dụng | Màn hình | API | Tiêu chí / bằng chứng test |
| --- | --- | --- | --- | --- | --- |
| MOB-FR-AUTH-01 ← FR-AUTH-01 | MOB-BR-01, MOB-BR-02, MOB-BR-03, MOB-BR-24, MOB-BR-25 | UC-MOB-01 | MOB-SCR-REGISTER | MOB-API-011 | MOB-FR-AUTH-01-AC-01, MOB-FR-AUTH-01-AC-02; [Cinema_BE/AuthService/AuthService.Tests/Integration/AccountValidationTests.cs](../Cinema_BE/AuthService/AuthService.Tests/Integration/AccountValidationTests.cs); [Cinema_BE/AuthService/AuthService.Tests/Integration/AuthFlowTests.cs](../Cinema_BE/AuthService/AuthService.Tests/Integration/AuthFlowTests.cs); [Cinema_Mobile/test/account_lock_flow_test.dart](../Cinema_Mobile/test/account_lock_flow_test.dart) |
| MOB-FR-AUTH-02 ← FR-AUTH-02 | MOB-BR-01, MOB-BR-02, MOB-BR-03, MOB-BR-24, MOB-BR-25 | UC-MOB-01 | MOB-SCR-LOGIN | MOB-API-006 | MOB-FR-AUTH-02-AC-01, MOB-FR-AUTH-02-AC-02; [Cinema_BE/AuthService/AuthService.Tests/Integration/AccountValidationTests.cs](../Cinema_BE/AuthService/AuthService.Tests/Integration/AccountValidationTests.cs); [Cinema_BE/AuthService/AuthService.Tests/Integration/AuthFlowTests.cs](../Cinema_BE/AuthService/AuthService.Tests/Integration/AuthFlowTests.cs); [Cinema_Mobile/test/account_lock_flow_test.dart](../Cinema_Mobile/test/account_lock_flow_test.dart) |
| MOB-FR-AUTH-03 ← FR-AUTH-03 | MOB-BR-01, MOB-BR-02, MOB-BR-03, MOB-BR-24, MOB-BR-25 | UC-MOB-01 | MOB-SCR-LOGIN | MOB-API-006, MOB-API-010 | MOB-FR-AUTH-03-AC-01, MOB-FR-AUTH-03-AC-02; [Cinema_BE/AuthService/AuthService.Tests/Integration/AccountValidationTests.cs](../Cinema_BE/AuthService/AuthService.Tests/Integration/AccountValidationTests.cs); [Cinema_BE/AuthService/AuthService.Tests/Integration/AuthFlowTests.cs](../Cinema_BE/AuthService/AuthService.Tests/Integration/AuthFlowTests.cs); [Cinema_Mobile/test/account_lock_flow_test.dart](../Cinema_Mobile/test/account_lock_flow_test.dart) |
| MOB-FR-AUTH-04 ← FR-AUTH-04 | MOB-BR-01, MOB-BR-02, MOB-BR-03, MOB-BR-24, MOB-BR-25 | UC-MOB-01 |  | MOB-API-008 | MOB-FR-AUTH-04-AC-01, MOB-FR-AUTH-04-AC-02; [Cinema_BE/AuthService/AuthService.Tests/Integration/AccountValidationTests.cs](../Cinema_BE/AuthService/AuthService.Tests/Integration/AccountValidationTests.cs); [Cinema_BE/AuthService/AuthService.Tests/Integration/AuthFlowTests.cs](../Cinema_BE/AuthService/AuthService.Tests/Integration/AuthFlowTests.cs); [Cinema_Mobile/test/account_lock_flow_test.dart](../Cinema_Mobile/test/account_lock_flow_test.dart) |
| MOB-FR-AUTH-05 ← FR-AUTH-05 | MOB-BR-01, MOB-BR-02, MOB-BR-03, MOB-BR-24, MOB-BR-25 | UC-MOB-01 | MOB-SCR-MGT-LANDING | MOB-API-008 | MOB-FR-AUTH-05-AC-01, MOB-FR-AUTH-05-AC-02; [Cinema_BE/AuthService/AuthService.Tests/Integration/AccountValidationTests.cs](../Cinema_BE/AuthService/AuthService.Tests/Integration/AccountValidationTests.cs); [Cinema_BE/AuthService/AuthService.Tests/Integration/AuthFlowTests.cs](../Cinema_BE/AuthService/AuthService.Tests/Integration/AuthFlowTests.cs); [Cinema_Mobile/test/account_lock_flow_test.dart](../Cinema_Mobile/test/account_lock_flow_test.dart) |
| MOB-FR-AUTH-06 ← FR-AUTH-06 | MOB-BR-01, MOB-BR-02, MOB-BR-03, MOB-BR-24, MOB-BR-25 | UC-MOB-01 | MOB-SCR-LOGIN | MOB-API-008 | MOB-FR-AUTH-06-AC-01, MOB-FR-AUTH-06-AC-02; [Cinema_BE/AuthService/AuthService.Tests/Integration/AccountValidationTests.cs](../Cinema_BE/AuthService/AuthService.Tests/Integration/AccountValidationTests.cs); [Cinema_BE/AuthService/AuthService.Tests/Integration/AuthFlowTests.cs](../Cinema_BE/AuthService/AuthService.Tests/Integration/AuthFlowTests.cs); [Cinema_Mobile/test/account_lock_flow_test.dart](../Cinema_Mobile/test/account_lock_flow_test.dart) |
| MOB-FR-AUTH-07 ← FR-AUTH-07 | MOB-BR-01, MOB-BR-02, MOB-BR-03, MOB-BR-24, MOB-BR-25 | UC-MOB-01 | MOB-SCR-VERIFY | MOB-API-012, MOB-API-014 | MOB-FR-AUTH-07-AC-01, MOB-FR-AUTH-07-AC-02; [Cinema_BE/AuthService/AuthService.Tests/Integration/AccountValidationTests.cs](../Cinema_BE/AuthService/AuthService.Tests/Integration/AccountValidationTests.cs); [Cinema_BE/AuthService/AuthService.Tests/Integration/AuthFlowTests.cs](../Cinema_BE/AuthService/AuthService.Tests/Integration/AuthFlowTests.cs); [Cinema_Mobile/test/account_lock_flow_test.dart](../Cinema_Mobile/test/account_lock_flow_test.dart) |
| MOB-FR-AUTH-08 ← FR-AUTH-08 | MOB-BR-01, MOB-BR-02, MOB-BR-03, MOB-BR-24, MOB-BR-25 | UC-MOB-01 | MOB-SCR-REGISTER, MOB-SCR-VERIFY | MOB-API-011 | MOB-FR-AUTH-08-AC-01, MOB-FR-AUTH-08-AC-02; [Cinema_BE/AuthService/AuthService.Tests/Integration/AccountValidationTests.cs](../Cinema_BE/AuthService/AuthService.Tests/Integration/AccountValidationTests.cs); [Cinema_BE/AuthService/AuthService.Tests/Integration/AuthFlowTests.cs](../Cinema_BE/AuthService/AuthService.Tests/Integration/AuthFlowTests.cs); [Cinema_Mobile/test/account_lock_flow_test.dart](../Cinema_Mobile/test/account_lock_flow_test.dart) |
| MOB-FR-AUTH-09 ← FR-AUTH-09 | MOB-BR-01, MOB-BR-02, MOB-BR-03, MOB-BR-24, MOB-BR-25 | UC-MOB-01 | MOB-SCR-FORGOT, MOB-SCR-RESET | MOB-API-005, MOB-API-013 | MOB-FR-AUTH-09-AC-01, MOB-FR-AUTH-09-AC-02; [Cinema_BE/AuthService/AuthService.Tests/Integration/AccountValidationTests.cs](../Cinema_BE/AuthService/AuthService.Tests/Integration/AccountValidationTests.cs); [Cinema_BE/AuthService/AuthService.Tests/Integration/AuthFlowTests.cs](../Cinema_BE/AuthService/AuthService.Tests/Integration/AuthFlowTests.cs); [Cinema_Mobile/test/account_lock_flow_test.dart](../Cinema_Mobile/test/account_lock_flow_test.dart) |
| MOB-FR-AUTH-10 ← FR-AUTH-10 | MOB-BR-01, MOB-BR-02, MOB-BR-03, MOB-BR-24, MOB-BR-25 | UC-MOB-01 | MOB-SCR-PROFILE, MOB-SCR-MGT-LANDING | MOB-API-007, MOB-API-010 | MOB-FR-AUTH-10-AC-01, MOB-FR-AUTH-10-AC-02; [Cinema_BE/AuthService/AuthService.Tests/Integration/AccountValidationTests.cs](../Cinema_BE/AuthService/AuthService.Tests/Integration/AccountValidationTests.cs); [Cinema_BE/AuthService/AuthService.Tests/Integration/AuthFlowTests.cs](../Cinema_BE/AuthService/AuthService.Tests/Integration/AuthFlowTests.cs); [Cinema_Mobile/test/account_lock_flow_test.dart](../Cinema_Mobile/test/account_lock_flow_test.dart) |
| MOB-FR-AUTH-11 ← FR-AUTH-11 | MOB-BR-01, MOB-BR-02, MOB-BR-03, MOB-BR-24, MOB-BR-25 | UC-MOB-01 | MOB-SCR-PROFILE | MOB-API-008 | MOB-FR-AUTH-11-AC-01, MOB-FR-AUTH-11-AC-02; [Cinema_BE/AuthService/AuthService.Tests/Integration/AccountValidationTests.cs](../Cinema_BE/AuthService/AuthService.Tests/Integration/AccountValidationTests.cs); [Cinema_BE/AuthService/AuthService.Tests/Integration/AuthFlowTests.cs](../Cinema_BE/AuthService/AuthService.Tests/Integration/AuthFlowTests.cs); [Cinema_Mobile/test/account_lock_flow_test.dart](../Cinema_Mobile/test/account_lock_flow_test.dart) |
| MOB-FR-AUTH-12 ← FR-AUTH-12 | MOB-BR-01, MOB-BR-02, MOB-BR-03, MOB-BR-24, MOB-BR-25 | UC-MOB-01 | MOB-SCR-LOGIN | MOB-API-008 | MOB-FR-AUTH-12-AC-01, MOB-FR-AUTH-12-AC-02; [Cinema_BE/AuthService/AuthService.Tests/Integration/AccountValidationTests.cs](../Cinema_BE/AuthService/AuthService.Tests/Integration/AccountValidationTests.cs); [Cinema_BE/AuthService/AuthService.Tests/Integration/AuthFlowTests.cs](../Cinema_BE/AuthService/AuthService.Tests/Integration/AuthFlowTests.cs); [Cinema_Mobile/test/account_lock_flow_test.dart](../Cinema_Mobile/test/account_lock_flow_test.dart) |
| MOB-FR-AUTH-13 ← FR-AUTH-13 | MOB-BR-01, MOB-BR-02, MOB-BR-03, MOB-BR-24, MOB-BR-25 | UC-MOB-01 | MOB-SCR-LOGIN, MOB-SCR-REGISTER, MOB-SCR-FORGOT, MOB-SCR-RESET | MOB-API-006, MOB-API-011, MOB-API-013 | MOB-FR-AUTH-13-AC-01, MOB-FR-AUTH-13-AC-02; [Cinema_BE/AuthService/AuthService.Tests/Integration/AccountValidationTests.cs](../Cinema_BE/AuthService/AuthService.Tests/Integration/AccountValidationTests.cs); [Cinema_BE/AuthService/AuthService.Tests/Integration/AuthFlowTests.cs](../Cinema_BE/AuthService/AuthService.Tests/Integration/AuthFlowTests.cs); [Cinema_Mobile/test/account_lock_flow_test.dart](../Cinema_Mobile/test/account_lock_flow_test.dart) |
| MOB-FR-AUTH-14 ← FR-AUTH-14 | MOB-BR-01, MOB-BR-02, MOB-BR-03, MOB-BR-24, MOB-BR-25 | UC-MOB-01 | MOB-SCR-VERIFY, MOB-SCR-FORGOT, MOB-SCR-RESET | MOB-API-006, MOB-API-010, MOB-API-012 | MOB-FR-AUTH-14-AC-01, MOB-FR-AUTH-14-AC-02; [Cinema_BE/AuthService/AuthService.Tests/Integration/AccountValidationTests.cs](../Cinema_BE/AuthService/AuthService.Tests/Integration/AccountValidationTests.cs); [Cinema_BE/AuthService/AuthService.Tests/Integration/AuthFlowTests.cs](../Cinema_BE/AuthService/AuthService.Tests/Integration/AuthFlowTests.cs); [Cinema_Mobile/test/account_lock_flow_test.dart](../Cinema_Mobile/test/account_lock_flow_test.dart) |
| MOB-FR-AUTH-16 ← FR-AUTH-16 | MOB-BR-01, MOB-BR-02, MOB-BR-03, MOB-BR-24, MOB-BR-25 | UC-MOB-01 | MOB-SCR-PROFILE | MOB-API-009 | MOB-FR-AUTH-16-AC-01, MOB-FR-AUTH-16-AC-02; [Cinema_BE/AuthService/AuthService.Tests/Integration/AccountValidationTests.cs](../Cinema_BE/AuthService/AuthService.Tests/Integration/AccountValidationTests.cs); [Cinema_BE/AuthService/AuthService.Tests/Integration/AuthFlowTests.cs](../Cinema_BE/AuthService/AuthService.Tests/Integration/AuthFlowTests.cs); [Cinema_Mobile/test/account_lock_flow_test.dart](../Cinema_Mobile/test/account_lock_flow_test.dart) |
| MOB-FR-AUTH-17 ← FR-AUTH-17 | MOB-BR-01, MOB-BR-02, MOB-BR-03, MOB-BR-24, MOB-BR-25 | UC-MOB-01 | MOB-SCR-PROFILE | MOB-API-004 | MOB-FR-AUTH-17-AC-01, MOB-FR-AUTH-17-AC-02; [Cinema_BE/AuthService/AuthService.Tests/Integration/AccountValidationTests.cs](../Cinema_BE/AuthService/AuthService.Tests/Integration/AccountValidationTests.cs); [Cinema_BE/AuthService/AuthService.Tests/Integration/AuthFlowTests.cs](../Cinema_BE/AuthService/AuthService.Tests/Integration/AuthFlowTests.cs); [Cinema_Mobile/test/account_lock_flow_test.dart](../Cinema_Mobile/test/account_lock_flow_test.dart) |
| MOB-FR-MOV-02 ← FR-MOV-02 | MOB-BR-26 | UC-MOB-02 | MOB-SCR-MOVIE | MOB-API-024 | MOB-FR-MOV-02-AC-01, MOB-FR-MOV-02-AC-02; [Cinema_BE/BookingService/BookingService.Tests/Integration/MovieReviewTests.cs](../Cinema_BE/BookingService/BookingService.Tests/Integration/MovieReviewTests.cs); [Cinema_Mobile/test/age_rating_test.dart](../Cinema_Mobile/test/age_rating_test.dart); [Cinema_Mobile/test/coming_soon_test.dart](../Cinema_Mobile/test/coming_soon_test.dart) |
| MOB-FR-MOV-03 ← FR-MOV-03 | MOB-BR-26 | UC-MOB-02 | MOB-SCR-HOME | MOB-API-025 | MOB-FR-MOV-03-AC-01, MOB-FR-MOV-03-AC-02; [Cinema_BE/BookingService/BookingService.Tests/Integration/MovieReviewTests.cs](../Cinema_BE/BookingService/BookingService.Tests/Integration/MovieReviewTests.cs); [Cinema_Mobile/test/age_rating_test.dart](../Cinema_Mobile/test/age_rating_test.dart); [Cinema_Mobile/test/coming_soon_test.dart](../Cinema_Mobile/test/coming_soon_test.dart) |
| MOB-FR-MOV-04 ← FR-MOV-04 | MOB-BR-26 | UC-MOB-02 | MOB-SCR-HOME | MOB-API-025, MOB-API-027 | MOB-FR-MOV-04-AC-01, MOB-FR-MOV-04-AC-02; [Cinema_BE/BookingService/BookingService.Tests/Integration/MovieReviewTests.cs](../Cinema_BE/BookingService/BookingService.Tests/Integration/MovieReviewTests.cs); [Cinema_Mobile/test/age_rating_test.dart](../Cinema_Mobile/test/age_rating_test.dart); [Cinema_Mobile/test/coming_soon_test.dart](../Cinema_Mobile/test/coming_soon_test.dart) |
| MOB-FR-MOV-08 ← FR-MOV-08 | MOB-BR-26 | UC-MOB-02 | MOB-SCR-MOVIE | MOB-API-024 | MOB-FR-MOV-08-AC-01, MOB-FR-MOV-08-AC-02; [Cinema_BE/BookingService/BookingService.Tests/Integration/MovieReviewTests.cs](../Cinema_BE/BookingService/BookingService.Tests/Integration/MovieReviewTests.cs); [Cinema_Mobile/test/age_rating_test.dart](../Cinema_Mobile/test/age_rating_test.dart); [Cinema_Mobile/test/coming_soon_test.dart](../Cinema_Mobile/test/coming_soon_test.dart) |
| MOB-FR-MOV-09 ← FR-MOV-09 | MOB-BR-26 | UC-MOB-02 | MOB-SCR-MOVIE, MOB-SCR-SUMMARY, MOB-SCR-CHECKIN | MOB-API-024 | MOB-FR-MOV-09-AC-01, MOB-FR-MOV-09-AC-02; [Cinema_BE/BookingService/BookingService.Tests/Integration/MovieReviewTests.cs](../Cinema_BE/BookingService/BookingService.Tests/Integration/MovieReviewTests.cs); [Cinema_Mobile/test/age_rating_test.dart](../Cinema_Mobile/test/age_rating_test.dart); [Cinema_Mobile/test/coming_soon_test.dart](../Cinema_Mobile/test/coming_soon_test.dart) |
| MOB-FR-MOV-10 ← FR-MOV-10 | MOB-BR-26 | UC-MOB-02 | MOB-SCR-HOME | MOB-API-025, MOB-API-026 | MOB-FR-MOV-10-AC-01, MOB-FR-MOV-10-AC-02; [Cinema_BE/BookingService/BookingService.Tests/Integration/MovieReviewTests.cs](../Cinema_BE/BookingService/BookingService.Tests/Integration/MovieReviewTests.cs); [Cinema_Mobile/test/age_rating_test.dart](../Cinema_Mobile/test/age_rating_test.dart); [Cinema_Mobile/test/coming_soon_test.dart](../Cinema_Mobile/test/coming_soon_test.dart) |
| MOB-FR-MOV-11 ← FR-MOV-11 | MOB-BR-26 | UC-MOB-02 | MOB-SCR-MOVIE | MOB-API-024 | MOB-FR-MOV-11-AC-01, MOB-FR-MOV-11-AC-02; [Cinema_BE/BookingService/BookingService.Tests/Integration/MovieReviewTests.cs](../Cinema_BE/BookingService/BookingService.Tests/Integration/MovieReviewTests.cs); [Cinema_Mobile/test/age_rating_test.dart](../Cinema_Mobile/test/age_rating_test.dart); [Cinema_Mobile/test/coming_soon_test.dart](../Cinema_Mobile/test/coming_soon_test.dart) |
| MOB-FR-MOV-12 ← FR-MOV-12 | MOB-BR-26 | UC-MOB-02 | MOB-SCR-MOVIE, MOB-SCR-TICKET | MOB-API-039, MOB-API-040, MOB-API-041, MOB-API-042 | MOB-FR-MOV-12-AC-01, MOB-FR-MOV-12-AC-02; [Cinema_BE/BookingService/BookingService.Tests/Integration/MovieReviewTests.cs](../Cinema_BE/BookingService/BookingService.Tests/Integration/MovieReviewTests.cs); [Cinema_Mobile/test/age_rating_test.dart](../Cinema_Mobile/test/age_rating_test.dart); [Cinema_Mobile/test/coming_soon_test.dart](../Cinema_Mobile/test/coming_soon_test.dart) |
| MOB-FR-SEAT-03 ← FR-SEAT-03 | MOB-BR-04, MOB-BR-07, MOB-BR-15, MOB-BR-16, MOB-BR-26 | UC-MOB-03 | MOB-SCR-SEATS | MOB-API-001 | MOB-FR-SEAT-03-AC-01, MOB-FR-SEAT-03-AC-02; [Cinema_BE/MovieService/MovieService.Tests/Integration/SeatTests.cs](../Cinema_BE/MovieService/MovieService.Tests/Integration/SeatTests.cs); [Cinema_Mobile/test/booking_flow_test.dart](../Cinema_Mobile/test/booking_flow_test.dart); [Cinema_Mobile/test/seat_map_test.dart](../Cinema_Mobile/test/seat_map_test.dart) |
| MOB-FR-SHOW-03 ← FR-SHOW-03 | MOB-BR-05, MOB-BR-06, MOB-BR-15, MOB-BR-19, MOB-BR-30 | UC-MOB-04 | MOB-SCR-MOVIE, MOB-SCR-SEATS | MOB-API-002 | MOB-FR-SHOW-03-AC-01, MOB-FR-SHOW-03-AC-02; [Cinema_BE/BookingService/BookingService.Tests/Integration/ShowtimeReminderTests.cs](../Cinema_BE/BookingService/BookingService.Tests/Integration/ShowtimeReminderTests.cs); [Cinema_BE/MovieService/MovieService.Tests/Integration/ShowtimeFormatTests.cs](../Cinema_BE/MovieService/MovieService.Tests/Integration/ShowtimeFormatTests.cs); [Cinema_BE/MovieService/MovieService.Tests/Integration/ShowtimeTests.cs](../Cinema_BE/MovieService/MovieService.Tests/Integration/ShowtimeTests.cs) |
| MOB-FR-SHOW-06 ← FR-SHOW-06 | MOB-BR-05, MOB-BR-06, MOB-BR-15, MOB-BR-19, MOB-BR-30 | UC-MOB-04 | MOB-SCR-MOVIE | MOB-API-003 | MOB-FR-SHOW-06-AC-01, MOB-FR-SHOW-06-AC-02; [Cinema_BE/BookingService/BookingService.Tests/Integration/ShowtimeReminderTests.cs](../Cinema_BE/BookingService/BookingService.Tests/Integration/ShowtimeReminderTests.cs); [Cinema_BE/MovieService/MovieService.Tests/Integration/ShowtimeFormatTests.cs](../Cinema_BE/MovieService/MovieService.Tests/Integration/ShowtimeFormatTests.cs); [Cinema_BE/MovieService/MovieService.Tests/Integration/ShowtimeTests.cs](../Cinema_BE/MovieService/MovieService.Tests/Integration/ShowtimeTests.cs) |
| MOB-FR-SHOW-07 ← FR-SHOW-07 | MOB-BR-05, MOB-BR-06, MOB-BR-15, MOB-BR-19, MOB-BR-30 | UC-MOB-04 | MOB-SCR-MOVIE | MOB-API-003 | MOB-FR-SHOW-07-AC-01, MOB-FR-SHOW-07-AC-02; [Cinema_BE/BookingService/BookingService.Tests/Integration/ShowtimeReminderTests.cs](../Cinema_BE/BookingService/BookingService.Tests/Integration/ShowtimeReminderTests.cs); [Cinema_BE/MovieService/MovieService.Tests/Integration/ShowtimeFormatTests.cs](../Cinema_BE/MovieService/MovieService.Tests/Integration/ShowtimeFormatTests.cs); [Cinema_BE/MovieService/MovieService.Tests/Integration/ShowtimeTests.cs](../Cinema_BE/MovieService/MovieService.Tests/Integration/ShowtimeTests.cs) |
| MOB-FR-SHOW-08 ← FR-SHOW-08 | MOB-BR-05, MOB-BR-06, MOB-BR-15, MOB-BR-19, MOB-BR-30 | UC-MOB-04 | MOB-SCR-MOVIE | MOB-API-003 | MOB-FR-SHOW-08-AC-01, MOB-FR-SHOW-08-AC-02; [Cinema_BE/BookingService/BookingService.Tests/Integration/ShowtimeReminderTests.cs](../Cinema_BE/BookingService/BookingService.Tests/Integration/ShowtimeReminderTests.cs); [Cinema_BE/MovieService/MovieService.Tests/Integration/ShowtimeFormatTests.cs](../Cinema_BE/MovieService/MovieService.Tests/Integration/ShowtimeFormatTests.cs); [Cinema_BE/MovieService/MovieService.Tests/Integration/ShowtimeTests.cs](../Cinema_BE/MovieService/MovieService.Tests/Integration/ShowtimeTests.cs) |
| MOB-FR-SHOW-13 ← FR-SHOW-13 | MOB-BR-05, MOB-BR-06, MOB-BR-15, MOB-BR-19, MOB-BR-30 | UC-MOB-04 | MOB-SCR-MOVIE, MOB-SCR-SEATS | MOB-API-002 | MOB-FR-SHOW-13-AC-01, MOB-FR-SHOW-13-AC-02; [Cinema_BE/BookingService/BookingService.Tests/Integration/ShowtimeReminderTests.cs](../Cinema_BE/BookingService/BookingService.Tests/Integration/ShowtimeReminderTests.cs); [Cinema_BE/MovieService/MovieService.Tests/Integration/ShowtimeFormatTests.cs](../Cinema_BE/MovieService/MovieService.Tests/Integration/ShowtimeFormatTests.cs); [Cinema_BE/MovieService/MovieService.Tests/Integration/ShowtimeTests.cs](../Cinema_BE/MovieService/MovieService.Tests/Integration/ShowtimeTests.cs) |
| MOB-FR-BOOK-01 ← FR-BOOK-01 | MOB-BR-07, MOB-BR-08, MOB-BR-14, MOB-BR-15, MOB-BR-16, MOB-BR-17, MOB-BR-27, MOB-BR-28, MOB-BR-29 | UC-MOB-05 | MOB-SCR-SUMMARY | MOB-API-021 | MOB-FR-BOOK-01-AC-01, MOB-FR-BOOK-01-AC-02; [Cinema_BE/BookingService/BookingService.Tests/Integration/BookingFlowTests.cs](../Cinema_BE/BookingService/BookingService.Tests/Integration/BookingFlowTests.cs); [Cinema_BE/BookingService/BookingService.Tests/Integration/ConcessionTests.cs](../Cinema_BE/BookingService/BookingService.Tests/Integration/ConcessionTests.cs); [Cinema_BE/BookingService/BookingService.Tests/Integration/LoyaltyTests.cs](../Cinema_BE/BookingService/BookingService.Tests/Integration/LoyaltyTests.cs) |
| MOB-FR-BOOK-02 ← FR-BOOK-02 | MOB-BR-07, MOB-BR-08, MOB-BR-14, MOB-BR-15, MOB-BR-16, MOB-BR-17, MOB-BR-27, MOB-BR-28, MOB-BR-29 | UC-MOB-05 | MOB-SCR-RESULT, MOB-SCR-TICKET | MOB-API-017 | MOB-FR-BOOK-02-AC-01, MOB-FR-BOOK-02-AC-02; [Cinema_BE/BookingService/BookingService.Tests/Integration/BookingFlowTests.cs](../Cinema_BE/BookingService/BookingService.Tests/Integration/BookingFlowTests.cs); [Cinema_BE/BookingService/BookingService.Tests/Integration/ConcessionTests.cs](../Cinema_BE/BookingService/BookingService.Tests/Integration/ConcessionTests.cs); [Cinema_BE/BookingService/BookingService.Tests/Integration/LoyaltyTests.cs](../Cinema_BE/BookingService/BookingService.Tests/Integration/LoyaltyTests.cs) |
| MOB-FR-BOOK-04 ← FR-BOOK-04 | MOB-BR-07, MOB-BR-08, MOB-BR-14, MOB-BR-15, MOB-BR-16, MOB-BR-17, MOB-BR-27, MOB-BR-28, MOB-BR-29 | UC-MOB-05 | MOB-SCR-TICKETS | MOB-API-020 | MOB-FR-BOOK-04-AC-01, MOB-FR-BOOK-04-AC-02; [Cinema_BE/BookingService/BookingService.Tests/Integration/BookingFlowTests.cs](../Cinema_BE/BookingService/BookingService.Tests/Integration/BookingFlowTests.cs); [Cinema_BE/BookingService/BookingService.Tests/Integration/ConcessionTests.cs](../Cinema_BE/BookingService/BookingService.Tests/Integration/ConcessionTests.cs); [Cinema_BE/BookingService/BookingService.Tests/Integration/LoyaltyTests.cs](../Cinema_BE/BookingService/BookingService.Tests/Integration/LoyaltyTests.cs) |
| MOB-FR-BOOK-05 ← FR-BOOK-05 | MOB-BR-07, MOB-BR-08, MOB-BR-14, MOB-BR-15, MOB-BR-16, MOB-BR-17, MOB-BR-27, MOB-BR-28, MOB-BR-29 | UC-MOB-05 | MOB-SCR-PAYMENT, MOB-SCR-RESULT, MOB-SCR-TICKET | MOB-API-034, MOB-API-036 | MOB-FR-BOOK-05-AC-01, MOB-FR-BOOK-05-AC-02; [Cinema_BE/BookingService/BookingService.Tests/Integration/BookingFlowTests.cs](../Cinema_BE/BookingService/BookingService.Tests/Integration/BookingFlowTests.cs); [Cinema_BE/BookingService/BookingService.Tests/Integration/ConcessionTests.cs](../Cinema_BE/BookingService/BookingService.Tests/Integration/ConcessionTests.cs); [Cinema_BE/BookingService/BookingService.Tests/Integration/LoyaltyTests.cs](../Cinema_BE/BookingService/BookingService.Tests/Integration/LoyaltyTests.cs) |
| MOB-FR-BOOK-06 ← FR-BOOK-06 | MOB-BR-07, MOB-BR-08, MOB-BR-14, MOB-BR-15, MOB-BR-16, MOB-BR-17, MOB-BR-27, MOB-BR-28, MOB-BR-29 | UC-MOB-05 | MOB-SCR-TICKET | MOB-API-015 | MOB-FR-BOOK-06-AC-01, MOB-FR-BOOK-06-AC-02; [Cinema_BE/BookingService/BookingService.Tests/Integration/BookingFlowTests.cs](../Cinema_BE/BookingService/BookingService.Tests/Integration/BookingFlowTests.cs); [Cinema_BE/BookingService/BookingService.Tests/Integration/ConcessionTests.cs](../Cinema_BE/BookingService/BookingService.Tests/Integration/ConcessionTests.cs); [Cinema_BE/BookingService/BookingService.Tests/Integration/LoyaltyTests.cs](../Cinema_BE/BookingService/BookingService.Tests/Integration/LoyaltyTests.cs) |
| MOB-FR-BOOK-07 ← FR-BOOK-07 | MOB-BR-07, MOB-BR-08, MOB-BR-14, MOB-BR-15, MOB-BR-16, MOB-BR-17, MOB-BR-27, MOB-BR-28, MOB-BR-29 | UC-MOB-05 | MOB-SCR-SEATS | MOB-API-019 | MOB-FR-BOOK-07-AC-01, MOB-FR-BOOK-07-AC-02; [Cinema_BE/BookingService/BookingService.Tests/Integration/BookingFlowTests.cs](../Cinema_BE/BookingService/BookingService.Tests/Integration/BookingFlowTests.cs); [Cinema_BE/BookingService/BookingService.Tests/Integration/ConcessionTests.cs](../Cinema_BE/BookingService/BookingService.Tests/Integration/ConcessionTests.cs); [Cinema_BE/BookingService/BookingService.Tests/Integration/LoyaltyTests.cs](../Cinema_BE/BookingService/BookingService.Tests/Integration/LoyaltyTests.cs) |
| MOB-FR-BOOK-08 ← FR-BOOK-08 | MOB-BR-07, MOB-BR-08, MOB-BR-14, MOB-BR-15, MOB-BR-16, MOB-BR-17, MOB-BR-27, MOB-BR-28, MOB-BR-29 | UC-MOB-05 | MOB-SCR-SEATS | MOB-API-021 | MOB-FR-BOOK-08-AC-01, MOB-FR-BOOK-08-AC-02; [Cinema_BE/BookingService/BookingService.Tests/Integration/BookingFlowTests.cs](../Cinema_BE/BookingService/BookingService.Tests/Integration/BookingFlowTests.cs); [Cinema_BE/BookingService/BookingService.Tests/Integration/ConcessionTests.cs](../Cinema_BE/BookingService/BookingService.Tests/Integration/ConcessionTests.cs); [Cinema_BE/BookingService/BookingService.Tests/Integration/LoyaltyTests.cs](../Cinema_BE/BookingService/BookingService.Tests/Integration/LoyaltyTests.cs) |
| MOB-FR-BOOK-09 ← FR-BOOK-09 | MOB-BR-07, MOB-BR-08, MOB-BR-14, MOB-BR-15, MOB-BR-16, MOB-BR-17, MOB-BR-27, MOB-BR-28, MOB-BR-29 | UC-MOB-05 | MOB-SCR-SEATS, MOB-SCR-SUMMARY | MOB-API-021 | MOB-FR-BOOK-09-AC-01, MOB-FR-BOOK-09-AC-02; [Cinema_BE/BookingService/BookingService.Tests/Integration/BookingFlowTests.cs](../Cinema_BE/BookingService/BookingService.Tests/Integration/BookingFlowTests.cs); [Cinema_BE/BookingService/BookingService.Tests/Integration/ConcessionTests.cs](../Cinema_BE/BookingService/BookingService.Tests/Integration/ConcessionTests.cs); [Cinema_BE/BookingService/BookingService.Tests/Integration/LoyaltyTests.cs](../Cinema_BE/BookingService/BookingService.Tests/Integration/LoyaltyTests.cs) |
| MOB-FR-BOOK-10 ← FR-BOOK-10 | MOB-BR-07, MOB-BR-08, MOB-BR-14, MOB-BR-15, MOB-BR-16, MOB-BR-17, MOB-BR-27, MOB-BR-28, MOB-BR-29 | UC-MOB-05 | MOB-SCR-PAYMENT | MOB-API-017 | MOB-FR-BOOK-10-AC-01, MOB-FR-BOOK-10-AC-02; [Cinema_BE/BookingService/BookingService.Tests/Integration/BookingFlowTests.cs](../Cinema_BE/BookingService/BookingService.Tests/Integration/BookingFlowTests.cs); [Cinema_BE/BookingService/BookingService.Tests/Integration/ConcessionTests.cs](../Cinema_BE/BookingService/BookingService.Tests/Integration/ConcessionTests.cs); [Cinema_BE/BookingService/BookingService.Tests/Integration/LoyaltyTests.cs](../Cinema_BE/BookingService/BookingService.Tests/Integration/LoyaltyTests.cs) |
| MOB-FR-BOOK-11 ← FR-BOOK-11 | MOB-BR-07, MOB-BR-08, MOB-BR-14, MOB-BR-15, MOB-BR-16, MOB-BR-17, MOB-BR-27, MOB-BR-28, MOB-BR-29 | UC-MOB-05 | MOB-SCR-SEATS | MOB-API-001, MOB-API-019 | MOB-FR-BOOK-11-AC-01, MOB-FR-BOOK-11-AC-02; [Cinema_BE/BookingService/BookingService.Tests/Integration/BookingFlowTests.cs](../Cinema_BE/BookingService/BookingService.Tests/Integration/BookingFlowTests.cs); [Cinema_BE/BookingService/BookingService.Tests/Integration/ConcessionTests.cs](../Cinema_BE/BookingService/BookingService.Tests/Integration/ConcessionTests.cs); [Cinema_BE/BookingService/BookingService.Tests/Integration/LoyaltyTests.cs](../Cinema_BE/BookingService/BookingService.Tests/Integration/LoyaltyTests.cs) |
| MOB-FR-BOOK-13 ← FR-BOOK-13 | MOB-BR-07, MOB-BR-08, MOB-BR-14, MOB-BR-15, MOB-BR-16, MOB-BR-17, MOB-BR-27, MOB-BR-28, MOB-BR-29 | UC-MOB-05 | MOB-SCR-SUMMARY, MOB-SCR-TICKET | MOB-API-021, MOB-API-022 | MOB-FR-BOOK-13-AC-01, MOB-FR-BOOK-13-AC-02; [Cinema_BE/BookingService/BookingService.Tests/Integration/BookingFlowTests.cs](../Cinema_BE/BookingService/BookingService.Tests/Integration/BookingFlowTests.cs); [Cinema_BE/BookingService/BookingService.Tests/Integration/ConcessionTests.cs](../Cinema_BE/BookingService/BookingService.Tests/Integration/ConcessionTests.cs); [Cinema_BE/BookingService/BookingService.Tests/Integration/LoyaltyTests.cs](../Cinema_BE/BookingService/BookingService.Tests/Integration/LoyaltyTests.cs) |
| MOB-FR-BOOK-15 ← FR-BOOK-15 | MOB-BR-07, MOB-BR-08, MOB-BR-14, MOB-BR-15, MOB-BR-16, MOB-BR-17, MOB-BR-27, MOB-BR-28, MOB-BR-29 | UC-MOB-05 | MOB-SCR-SUMMARY, MOB-SCR-TICKET | MOB-API-021, MOB-API-038 | MOB-FR-BOOK-15-AC-01, MOB-FR-BOOK-15-AC-02; [Cinema_BE/BookingService/BookingService.Tests/Integration/BookingFlowTests.cs](../Cinema_BE/BookingService/BookingService.Tests/Integration/BookingFlowTests.cs); [Cinema_BE/BookingService/BookingService.Tests/Integration/ConcessionTests.cs](../Cinema_BE/BookingService/BookingService.Tests/Integration/ConcessionTests.cs); [Cinema_BE/BookingService/BookingService.Tests/Integration/LoyaltyTests.cs](../Cinema_BE/BookingService/BookingService.Tests/Integration/LoyaltyTests.cs) |
| MOB-FR-BOOK-17 ← FR-BOOK-17 | MOB-BR-07, MOB-BR-08, MOB-BR-14, MOB-BR-15, MOB-BR-16, MOB-BR-17, MOB-BR-27, MOB-BR-28, MOB-BR-29 | UC-MOB-05 | MOB-SCR-SUMMARY, MOB-SCR-TICKET, MOB-SCR-PROFILE | MOB-API-021, MOB-API-023 | MOB-FR-BOOK-17-AC-01, MOB-FR-BOOK-17-AC-02; [Cinema_BE/BookingService/BookingService.Tests/Integration/BookingFlowTests.cs](../Cinema_BE/BookingService/BookingService.Tests/Integration/BookingFlowTests.cs); [Cinema_BE/BookingService/BookingService.Tests/Integration/ConcessionTests.cs](../Cinema_BE/BookingService/BookingService.Tests/Integration/ConcessionTests.cs); [Cinema_BE/BookingService/BookingService.Tests/Integration/LoyaltyTests.cs](../Cinema_BE/BookingService/BookingService.Tests/Integration/LoyaltyTests.cs) |
| MOB-FR-BOOK-19 ← FR-BOOK-19 | MOB-BR-07, MOB-BR-08, MOB-BR-14, MOB-BR-15, MOB-BR-16, MOB-BR-17, MOB-BR-27, MOB-BR-28, MOB-BR-29 | UC-MOB-05 | MOB-SCR-TICKET | MOB-API-002 | MOB-FR-BOOK-19-AC-01, MOB-FR-BOOK-19-AC-02; [Cinema_BE/BookingService/BookingService.Tests/Integration/BookingFlowTests.cs](../Cinema_BE/BookingService/BookingService.Tests/Integration/BookingFlowTests.cs); [Cinema_BE/BookingService/BookingService.Tests/Integration/ConcessionTests.cs](../Cinema_BE/BookingService/BookingService.Tests/Integration/ConcessionTests.cs); [Cinema_BE/BookingService/BookingService.Tests/Integration/LoyaltyTests.cs](../Cinema_BE/BookingService/BookingService.Tests/Integration/LoyaltyTests.cs) |
| MOB-FR-PAY-01 ← FR-PAY-01 | MOB-BR-09, MOB-BR-10, MOB-BR-11, MOB-BR-12, MOB-BR-13, MOB-BR-14, MOB-BR-20 | UC-MOB-06 | MOB-SCR-PAYMENT | MOB-API-035 | MOB-FR-PAY-01-AC-01, MOB-FR-PAY-01-AC-02; [Cinema_BE/BookingService/BookingService.Tests/Integration/BookingFlowTests.cs](../Cinema_BE/BookingService/BookingService.Tests/Integration/BookingFlowTests.cs); [Cinema_BE/BookingService/BookingService.Tests/Integration/PaymentSummaryTests.cs](../Cinema_BE/BookingService/BookingService.Tests/Integration/PaymentSummaryTests.cs); [Cinema_BE/BookingService/BookingService.Tests/Integration/PayOsOrderCodeTests.cs](../Cinema_BE/BookingService/BookingService.Tests/Integration/PayOsOrderCodeTests.cs) |
| MOB-FR-PAY-02 ← FR-PAY-02 | MOB-BR-09, MOB-BR-10, MOB-BR-11, MOB-BR-12, MOB-BR-13, MOB-BR-14, MOB-BR-20 | UC-MOB-06 | MOB-SCR-PAYMENT, MOB-SCR-RESULT | MOB-API-034 | MOB-FR-PAY-02-AC-01, MOB-FR-PAY-02-AC-02; [Cinema_BE/BookingService/BookingService.Tests/Integration/BookingFlowTests.cs](../Cinema_BE/BookingService/BookingService.Tests/Integration/BookingFlowTests.cs); [Cinema_BE/BookingService/BookingService.Tests/Integration/PaymentSummaryTests.cs](../Cinema_BE/BookingService/BookingService.Tests/Integration/PaymentSummaryTests.cs); [Cinema_BE/BookingService/BookingService.Tests/Integration/PayOsOrderCodeTests.cs](../Cinema_BE/BookingService/BookingService.Tests/Integration/PayOsOrderCodeTests.cs) |
| MOB-FR-PAY-03 ← FR-PAY-03 | MOB-BR-09, MOB-BR-10, MOB-BR-11, MOB-BR-12, MOB-BR-13, MOB-BR-14, MOB-BR-20 | UC-MOB-06 | MOB-SCR-TICKET, MOB-SCR-PAYHISTORY | MOB-API-037 | MOB-FR-PAY-03-AC-01, MOB-FR-PAY-03-AC-02; [Cinema_BE/BookingService/BookingService.Tests/Integration/BookingFlowTests.cs](../Cinema_BE/BookingService/BookingService.Tests/Integration/BookingFlowTests.cs); [Cinema_BE/BookingService/BookingService.Tests/Integration/PaymentSummaryTests.cs](../Cinema_BE/BookingService/BookingService.Tests/Integration/PaymentSummaryTests.cs); [Cinema_BE/BookingService/BookingService.Tests/Integration/PayOsOrderCodeTests.cs](../Cinema_BE/BookingService/BookingService.Tests/Integration/PayOsOrderCodeTests.cs) |
| MOB-FR-PAY-04 ← FR-PAY-04 | MOB-BR-09, MOB-BR-10, MOB-BR-11, MOB-BR-12, MOB-BR-13, MOB-BR-14, MOB-BR-20 | UC-MOB-06 | MOB-SCR-PAYHISTORY | MOB-API-037 | MOB-FR-PAY-04-AC-01, MOB-FR-PAY-04-AC-02; [Cinema_BE/BookingService/BookingService.Tests/Integration/BookingFlowTests.cs](../Cinema_BE/BookingService/BookingService.Tests/Integration/BookingFlowTests.cs); [Cinema_BE/BookingService/BookingService.Tests/Integration/PaymentSummaryTests.cs](../Cinema_BE/BookingService/BookingService.Tests/Integration/PaymentSummaryTests.cs); [Cinema_BE/BookingService/BookingService.Tests/Integration/PayOsOrderCodeTests.cs](../Cinema_BE/BookingService/BookingService.Tests/Integration/PayOsOrderCodeTests.cs) |
| MOB-FR-PAY-06 ← FR-PAY-06 | MOB-BR-09, MOB-BR-10, MOB-BR-11, MOB-BR-12, MOB-BR-13, MOB-BR-14, MOB-BR-20 | UC-MOB-06 | MOB-SCR-TICKET | MOB-API-015, MOB-API-033 | MOB-FR-PAY-06-AC-01, MOB-FR-PAY-06-AC-02; [Cinema_BE/BookingService/BookingService.Tests/Integration/BookingFlowTests.cs](../Cinema_BE/BookingService/BookingService.Tests/Integration/BookingFlowTests.cs); [Cinema_BE/BookingService/BookingService.Tests/Integration/PaymentSummaryTests.cs](../Cinema_BE/BookingService/BookingService.Tests/Integration/PaymentSummaryTests.cs); [Cinema_BE/BookingService/BookingService.Tests/Integration/PayOsOrderCodeTests.cs](../Cinema_BE/BookingService/BookingService.Tests/Integration/PayOsOrderCodeTests.cs) |
| MOB-FR-PAY-07 ← FR-PAY-07 | MOB-BR-09, MOB-BR-10, MOB-BR-11, MOB-BR-12, MOB-BR-13, MOB-BR-14, MOB-BR-20 | UC-MOB-06 |  | MOB-API-036 | MOB-FR-PAY-07-AC-01, MOB-FR-PAY-07-AC-02; [Cinema_BE/BookingService/BookingService.Tests/Integration/BookingFlowTests.cs](../Cinema_BE/BookingService/BookingService.Tests/Integration/BookingFlowTests.cs); [Cinema_BE/BookingService/BookingService.Tests/Integration/PaymentSummaryTests.cs](../Cinema_BE/BookingService/BookingService.Tests/Integration/PaymentSummaryTests.cs); [Cinema_BE/BookingService/BookingService.Tests/Integration/PayOsOrderCodeTests.cs](../Cinema_BE/BookingService/BookingService.Tests/Integration/PayOsOrderCodeTests.cs) |
| MOB-FR-PAY-08 ← FR-PAY-08 | MOB-BR-09, MOB-BR-10, MOB-BR-11, MOB-BR-12, MOB-BR-13, MOB-BR-14, MOB-BR-20 | UC-MOB-06 | MOB-SCR-RESULT | MOB-API-034, MOB-API-036 | MOB-FR-PAY-08-AC-01, MOB-FR-PAY-08-AC-02; [Cinema_BE/BookingService/BookingService.Tests/Integration/BookingFlowTests.cs](../Cinema_BE/BookingService/BookingService.Tests/Integration/BookingFlowTests.cs); [Cinema_BE/BookingService/BookingService.Tests/Integration/PaymentSummaryTests.cs](../Cinema_BE/BookingService/BookingService.Tests/Integration/PaymentSummaryTests.cs); [Cinema_BE/BookingService/BookingService.Tests/Integration/PayOsOrderCodeTests.cs](../Cinema_BE/BookingService/BookingService.Tests/Integration/PayOsOrderCodeTests.cs) |
| MOB-FR-PAY-11 ← FR-PAY-11 | MOB-BR-09, MOB-BR-10, MOB-BR-11, MOB-BR-12, MOB-BR-13, MOB-BR-14, MOB-BR-20 | UC-MOB-06 | MOB-SCR-PAYMENT | MOB-API-017, MOB-API-034 | MOB-FR-PAY-11-AC-01, MOB-FR-PAY-11-AC-02; [Cinema_BE/BookingService/BookingService.Tests/Integration/BookingFlowTests.cs](../Cinema_BE/BookingService/BookingService.Tests/Integration/BookingFlowTests.cs); [Cinema_BE/BookingService/BookingService.Tests/Integration/PaymentSummaryTests.cs](../Cinema_BE/BookingService/BookingService.Tests/Integration/PaymentSummaryTests.cs); [Cinema_BE/BookingService/BookingService.Tests/Integration/PayOsOrderCodeTests.cs](../Cinema_BE/BookingService/BookingService.Tests/Integration/PayOsOrderCodeTests.cs) |
| MOB-FR-REF-01 ← FR-REF-01 | MOB-BR-17, MOB-BR-18, MOB-BR-19, MOB-BR-20 | UC-MOB-07 | MOB-SCR-TICKET | MOB-API-015, MOB-API-036 | MOB-FR-REF-01-AC-01, MOB-FR-REF-01-AC-02; [Cinema_BE/BookingService/BookingService.Tests/Integration/RefundTests.cs](../Cinema_BE/BookingService/BookingService.Tests/Integration/RefundTests.cs); [Cinema_Mobile/test/booking_details_ui_test.dart](../Cinema_Mobile/test/booking_details_ui_test.dart); [Cinema_Mobile/test/refund_details_ui_test.dart](../Cinema_Mobile/test/refund_details_ui_test.dart) |
| MOB-FR-REF-05 ← FR-REF-05 | MOB-BR-17, MOB-BR-18, MOB-BR-19, MOB-BR-20 | UC-MOB-07 | MOB-SCR-TICKET | MOB-API-015 | MOB-FR-REF-05-AC-01, MOB-FR-REF-05-AC-02; [Cinema_BE/BookingService/BookingService.Tests/Integration/RefundTests.cs](../Cinema_BE/BookingService/BookingService.Tests/Integration/RefundTests.cs); [Cinema_Mobile/test/booking_details_ui_test.dart](../Cinema_Mobile/test/booking_details_ui_test.dart); [Cinema_Mobile/test/refund_details_ui_test.dart](../Cinema_Mobile/test/refund_details_ui_test.dart) |
| MOB-FR-REF-06 ← FR-REF-06 | MOB-BR-17, MOB-BR-18, MOB-BR-19, MOB-BR-20 | UC-MOB-07 | MOB-SCR-TICKET | MOB-API-033 | MOB-FR-REF-06-AC-01, MOB-FR-REF-06-AC-02; [Cinema_BE/BookingService/BookingService.Tests/Integration/RefundTests.cs](../Cinema_BE/BookingService/BookingService.Tests/Integration/RefundTests.cs); [Cinema_Mobile/test/booking_details_ui_test.dart](../Cinema_Mobile/test/booking_details_ui_test.dart); [Cinema_Mobile/test/refund_details_ui_test.dart](../Cinema_Mobile/test/refund_details_ui_test.dart) |
| MOB-FR-REF-07 ← FR-REF-07 | MOB-BR-17, MOB-BR-18, MOB-BR-19, MOB-BR-20 | UC-MOB-07 |  | MOB-API-015, MOB-API-033 | MOB-FR-REF-07-AC-01, MOB-FR-REF-07-AC-02; [Cinema_BE/BookingService/BookingService.Tests/Integration/RefundTests.cs](../Cinema_BE/BookingService/BookingService.Tests/Integration/RefundTests.cs); [Cinema_Mobile/test/booking_details_ui_test.dart](../Cinema_Mobile/test/booking_details_ui_test.dart); [Cinema_Mobile/test/refund_details_ui_test.dart](../Cinema_Mobile/test/refund_details_ui_test.dart) |
| MOB-FR-CHK-01 ← FR-CHK-01 | MOB-BR-21 | UC-MOB-08 | MOB-SCR-TICKET | MOB-API-017 | MOB-FR-CHK-01-AC-01, MOB-FR-CHK-01-AC-02; [Cinema_BE/BookingService/BookingService.Tests/Integration/CheckInTests.cs](../Cinema_BE/BookingService/BookingService.Tests/Integration/CheckInTests.cs); [Cinema_Mobile/test/check_in_test.dart](../Cinema_Mobile/test/check_in_test.dart) |
| MOB-FR-CHK-02 ← FR-CHK-02 | MOB-BR-21 | UC-MOB-08 | MOB-SCR-CHECKIN | MOB-API-018 | MOB-FR-CHK-02-AC-01, MOB-FR-CHK-02-AC-02; [Cinema_BE/BookingService/BookingService.Tests/Integration/CheckInTests.cs](../Cinema_BE/BookingService/BookingService.Tests/Integration/CheckInTests.cs); [Cinema_Mobile/test/check_in_test.dart](../Cinema_Mobile/test/check_in_test.dart) |
| MOB-FR-CHK-03 ← FR-CHK-03 | MOB-BR-21 | UC-MOB-08 | MOB-SCR-CHECKIN | MOB-API-016 | MOB-FR-CHK-03-AC-01, MOB-FR-CHK-03-AC-02; [Cinema_BE/BookingService/BookingService.Tests/Integration/CheckInTests.cs](../Cinema_BE/BookingService/BookingService.Tests/Integration/CheckInTests.cs); [Cinema_Mobile/test/check_in_test.dart](../Cinema_Mobile/test/check_in_test.dart) |
| MOB-FR-CHK-04 ← FR-CHK-04 | MOB-BR-21 | UC-MOB-08 | MOB-SCR-MGT-LANDING, MOB-SCR-CHECKIN | MOB-API-016, MOB-API-018 | MOB-FR-CHK-04-AC-01, MOB-FR-CHK-04-AC-02; [Cinema_BE/BookingService/BookingService.Tests/Integration/CheckInTests.cs](../Cinema_BE/BookingService/BookingService.Tests/Integration/CheckInTests.cs); [Cinema_Mobile/test/check_in_test.dart](../Cinema_Mobile/test/check_in_test.dart) |
| MOB-FR-CHK-05 ← FR-CHK-05 | MOB-BR-21 | UC-MOB-08 | MOB-SCR-TICKET, MOB-SCR-CHECKIN | MOB-API-017, MOB-API-018 | MOB-FR-CHK-05-AC-01, MOB-FR-CHK-05-AC-02; [Cinema_BE/BookingService/BookingService.Tests/Integration/CheckInTests.cs](../Cinema_BE/BookingService/BookingService.Tests/Integration/CheckInTests.cs); [Cinema_Mobile/test/check_in_test.dart](../Cinema_Mobile/test/check_in_test.dart) |
| MOB-FR-NOTI-01 ← FR-NOTI-01 | MOB-BR-11, MOB-BR-13 | UC-MOB-09 | MOB-SCR-NOTIFICATIONS | MOB-API-032 | MOB-FR-NOTI-01-AC-01, MOB-FR-NOTI-01-AC-02; [Cinema_BE/BookingService/BookingService.Tests/Integration/ShowtimeReminderTests.cs](../Cinema_BE/BookingService/BookingService.Tests/Integration/ShowtimeReminderTests.cs); [Cinema_Mobile/test/notification_read_test.dart](../Cinema_Mobile/test/notification_read_test.dart) |
| MOB-FR-NOTI-04 ← FR-NOTI-04 | MOB-BR-11, MOB-BR-13 | UC-MOB-09 | MOB-SCR-NOTIFICATION | MOB-API-029 | MOB-FR-NOTI-04-AC-01, MOB-FR-NOTI-04-AC-02; [Cinema_BE/BookingService/BookingService.Tests/Integration/ShowtimeReminderTests.cs](../Cinema_BE/BookingService/BookingService.Tests/Integration/ShowtimeReminderTests.cs); [Cinema_Mobile/test/notification_read_test.dart](../Cinema_Mobile/test/notification_read_test.dart) |
| MOB-FR-NOTI-06 ← FR-NOTI-06 | MOB-BR-11, MOB-BR-13 | UC-MOB-09 |  | MOB-API-032 | MOB-FR-NOTI-06-AC-01, MOB-FR-NOTI-06-AC-02; [Cinema_BE/BookingService/BookingService.Tests/Integration/ShowtimeReminderTests.cs](../Cinema_BE/BookingService/BookingService.Tests/Integration/ShowtimeReminderTests.cs); [Cinema_Mobile/test/notification_read_test.dart](../Cinema_Mobile/test/notification_read_test.dart) |
| MOB-FR-NOTI-07 ← FR-NOTI-07 | MOB-BR-11, MOB-BR-13 | UC-MOB-09 |  | MOB-API-005, MOB-API-011, MOB-API-014 | MOB-FR-NOTI-07-AC-01, MOB-FR-NOTI-07-AC-02; [Cinema_BE/BookingService/BookingService.Tests/Integration/ShowtimeReminderTests.cs](../Cinema_BE/BookingService/BookingService.Tests/Integration/ShowtimeReminderTests.cs); [Cinema_Mobile/test/notification_read_test.dart](../Cinema_Mobile/test/notification_read_test.dart) |
| MOB-FR-NOTI-08 ← FR-NOTI-08 | MOB-BR-11, MOB-BR-13 | UC-MOB-09 |  | MOB-API-032 | MOB-FR-NOTI-08-AC-01, MOB-FR-NOTI-08-AC-02; [Cinema_BE/BookingService/BookingService.Tests/Integration/ShowtimeReminderTests.cs](../Cinema_BE/BookingService/BookingService.Tests/Integration/ShowtimeReminderTests.cs); [Cinema_Mobile/test/notification_read_test.dart](../Cinema_Mobile/test/notification_read_test.dart) |
| MOB-FR-NOTI-09 ← FR-NOTI-09 | MOB-BR-11, MOB-BR-13 | UC-MOB-09 | MOB-SCR-HOME, MOB-SCR-NOTIFICATIONS, MOB-SCR-NOTIFICATION | MOB-API-028, MOB-API-030, MOB-API-031 | MOB-FR-NOTI-09-AC-01, MOB-FR-NOTI-09-AC-02; [Cinema_BE/BookingService/BookingService.Tests/Integration/ShowtimeReminderTests.cs](../Cinema_BE/BookingService/BookingService.Tests/Integration/ShowtimeReminderTests.cs); [Cinema_Mobile/test/notification_read_test.dart](../Cinema_Mobile/test/notification_read_test.dart) |
| MOB-FR-NAV-01 ← Từ code | MOB-BR-01, MOB-BR-02, MOB-BR-03, MOB-BR-24, MOB-BR-25 | UC-MOB-01 | MOB-SCR-LOGIN | — | MOB-FR-NAV-01-AC-01, MOB-FR-NAV-01-AC-02; [Cinema_BE/AuthService/AuthService.Tests/Integration/AccountValidationTests.cs](../Cinema_BE/AuthService/AuthService.Tests/Integration/AccountValidationTests.cs); [Cinema_BE/AuthService/AuthService.Tests/Integration/AuthFlowTests.cs](../Cinema_BE/AuthService/AuthService.Tests/Integration/AuthFlowTests.cs); [Cinema_Mobile/test/account_lock_flow_test.dart](../Cinema_Mobile/test/account_lock_flow_test.dart) |
| MOB-FR-STATE-01 ← Từ code | MOB-BR-07, MOB-BR-08, MOB-BR-14, MOB-BR-15, MOB-BR-16, MOB-BR-17, MOB-BR-27, MOB-BR-28, MOB-BR-29 | UC-MOB-05 |  | — | MOB-FR-STATE-01-AC-01, MOB-FR-STATE-01-AC-02; [Cinema_BE/BookingService/BookingService.Tests/Integration/BookingFlowTests.cs](../Cinema_BE/BookingService/BookingService.Tests/Integration/BookingFlowTests.cs); [Cinema_BE/BookingService/BookingService.Tests/Integration/ConcessionTests.cs](../Cinema_BE/BookingService/BookingService.Tests/Integration/ConcessionTests.cs); [Cinema_BE/BookingService/BookingService.Tests/Integration/LoyaltyTests.cs](../Cinema_BE/BookingService/BookingService.Tests/Integration/LoyaltyTests.cs) |
| MOB-FR-MEDIA-01 ← Từ code | MOB-BR-26 | UC-MOB-02 | MOB-SCR-HOME | MOB-API-024 | MOB-FR-MEDIA-01-AC-01, MOB-FR-MEDIA-01-AC-02; [Cinema_BE/BookingService/BookingService.Tests/Integration/MovieReviewTests.cs](../Cinema_BE/BookingService/BookingService.Tests/Integration/MovieReviewTests.cs); [Cinema_Mobile/test/age_rating_test.dart](../Cinema_Mobile/test/age_rating_test.dart); [Cinema_Mobile/test/coming_soon_test.dart](../Cinema_Mobile/test/coming_soon_test.dart) |

## 23. Ràng buộc

| ID | Ràng buộc / mục chưa rõ |
| --- | --- |
| MOB-CON-01 | Triển khai .NET là backend API. UI môn học MVC/Razor/Blazor riêng là [CẦN XÁC NHẬN]. |
| MOB-CON-02 | Submodule DB vắng/chưa khởi tạo; DDL/seed SQL chính xác và migrate thật [CẦN XÁC NHẬN]. EF/migration cục bộ là bằng chứng sẵn có. |
| MOB-CON-03 | Khoá thật, webhook công khai, SMTP và URL triển khai là phụ thuộc môi trường. Không tạo giao dịch tài chính/email để viết tài liệu. |
| MOB-CON-04 | Nghiệm thu OS/thiết bị thật, ký/phát hành cửa hàng, SLA, lưu backup và mục tiêu tải [CẦN XÁC NHẬN]. Khung nền tảng không phải chứng nhận tương thích. |
| MOB-CON-05 | Gateway emulator Android mặc định http://10.0.2.2:5000; mục tiêu cục bộ khác http://localhost:5000. Điện thoại cần API_BASE_URL truy cập được; ADMIN_URL/CUSTOMER_URL/PAYMENT_RETURN_URL theo triển khai. |

## 24. Ngoài phạm vi

Loại CRUD điện thoại cho phim, phòng, sơ đồ ghế, suất, tài khoản, menu, khuyến mãi hoặc thành viên; bán quầy/tiền mặt, in hoá đơn, tổng quan vận hành/doanh thu và duyệt/từ chối/ghi chuyển tiền hoàn. Các màn Dart đó chỉ thuộc web dù chung repository.

Không khẳng định đã có FCM hoặc tích hợp hoàn ngân hàng tự động. Không bổ sung lương, kho hoặc gợi ý AI. Bắp nước, khuyến mãi/mã, thành viên/điểm và đánh giá hiện có giữ trong phạm vi nơi code thực sự cung cấp.

## 25. Cải tiến tương lai

| ID | Tương lai, không phải FR hiện tại | Lý do |
| --- | --- | --- |
| MOB-FUT-01 | Tải thêm trang vé của mình | Hiện chỉ trả 50 vé đầu cho UI |
| MOB-FUT-02 | FCM nếu được chấp thuận | Thông báo hiện là email/lịch sử API |
| MOB-FUT-03 | Hoàn tự động nếu chọn nhà cung cấp phù hợp | Luồng hiện ghi chuyển thủ công ngoài hệ thống |

## 26. Kết luận

Đặc tả phân bổ một hệ thống theo ranh giới môn/client, giữ tương ứng ngôn ngữ và nêu rõ chức năng chỉ API, phụ thuộc chung và khoảng trống chưa kiểm chứng. Tài liệu hỗ trợ thiết kế test và giải thích triển khai thật.

## 27. Đối chiếu yêu cầu và triển khai

Từ vựng trạng thái: Đã triển khai; Triển khai một phần; Chỉ giao diện; Dữ liệu giả; Chờ backend; Chưa triển khai; Cần xác nhận. Chỉ dùng trạng thái áp dụng. Phụ thuộc sản phẩm dùng AppDependencies.remote; giả lập test không phải dữ liệu giả sản phẩm.

| Chức năng | Yêu cầu SRS | Trạng thái code | Trạng thái API | Ghi chú |
| --- | --- | --- | --- | --- |
| Đăng ký | MOB-FR-AUTH-01 | Đã triển khai | Có controller; chưa kiểm chứng chạy | Có bằng chứng triển khai tĩnh; chưa chạy nghiệm thu thực tế. |
| Đăng nhập | MOB-FR-AUTH-02 | Đã triển khai | Có controller; chưa kiểm chứng chạy | Có bằng chứng triển khai tĩnh; chưa chạy nghiệm thu thực tế. |
| Thông tin JWT | MOB-FR-AUTH-03 | Đã triển khai | Có controller; chưa kiểm chứng chạy | Có bằng chứng triển khai tĩnh; chưa chạy nghiệm thu thực tế. |
| Kiểm tra JWT | MOB-FR-AUTH-04 | Đã triển khai | Có controller; chưa kiểm chứng chạy | Có bằng chứng triển khai tĩnh; chưa chạy nghiệm thu thực tế. |
| Phân quyền vai trò | MOB-FR-AUTH-05 | Đã triển khai | Có controller; chưa kiểm chứng chạy | Có bằng chứng triển khai tĩnh; chưa chạy nghiệm thu thực tế. |
| Phản hồi chưa xác thực và thiếu quyền | MOB-FR-AUTH-06 | Đã triển khai | Có controller; chưa kiểm chứng chạy | Có bằng chứng triển khai tĩnh; chưa chạy nghiệm thu thực tế. |
| Xác thực OTP email | MOB-FR-AUTH-07 | Đã triển khai | Có controller; chưa kiểm chứng chạy | Có bằng chứng triển khai tĩnh; chưa chạy nghiệm thu thực tế. |
| Đăng ký lại email chưa xác thực | MOB-FR-AUTH-08 | Đã triển khai | Có controller; chưa kiểm chứng chạy | Có bằng chứng triển khai tĩnh; chưa chạy nghiệm thu thực tế. |
| Khôi phục mật khẩu | MOB-FR-AUTH-09 | Đã triển khai | Có controller; chưa kiểm chứng chạy | Có bằng chứng triển khai tĩnh; chưa chạy nghiệm thu thực tế. |
| Làm mới và đăng xuất | MOB-FR-AUTH-10 | Đã triển khai | Có controller; chưa kiểm chứng chạy | Có bằng chứng triển khai tĩnh; chưa chạy nghiệm thu thực tế. |
| Tài khoản hiện tại | MOB-FR-AUTH-11 | Đã triển khai | Có controller; chưa kiểm chứng chạy | Có bằng chứng triển khai tĩnh; chưa chạy nghiệm thu thực tế. |
| Áp dụng khoá và đổi quyền | MOB-FR-AUTH-12 | Đã triển khai | Có controller; chưa kiểm chứng chạy | Có bằng chứng triển khai tĩnh; chưa chạy nghiệm thu thực tế. |
| Kiểm tra trường tài khoản | MOB-FR-AUTH-13 | Đã triển khai | Có controller; chưa kiểm chứng chạy | Có bằng chứng triển khai tĩnh; chưa chạy nghiệm thu thực tế. |
| Giới hạn tần suất xác thực | MOB-FR-AUTH-14 | Đã triển khai | Có controller; chưa kiểm chứng chạy | Có bằng chứng triển khai tĩnh; chưa chạy nghiệm thu thực tế. |
| Sửa hồ sơ | MOB-FR-AUTH-16 | Đã triển khai | Có controller; chưa kiểm chứng chạy | Có bằng chứng triển khai tĩnh; chưa chạy nghiệm thu thực tế. |
| Đổi mật khẩu hiện tại | MOB-FR-AUTH-17 | Đã triển khai | Có controller; chưa kiểm chứng chạy | Có bằng chứng triển khai tĩnh; chưa chạy nghiệm thu thực tế. |
| Chi tiết phim | MOB-FR-MOV-02 | Đã triển khai | Có controller; chưa kiểm chứng chạy | Có bằng chứng triển khai tĩnh; chưa chạy nghiệm thu thực tế. |
| Tìm theo tên | MOB-FR-MOV-03 | Đã triển khai | Có controller; chưa kiểm chứng chạy | Có bằng chứng triển khai tĩnh; chưa chạy nghiệm thu thực tế. |
| Danh mục đang hoạt động | MOB-FR-MOV-04 | Đã triển khai | Có controller; chưa kiểm chứng chạy | Có bằng chứng triển khai tĩnh; chưa chạy nghiệm thu thực tế. |
| Mở trailer | MOB-FR-MOV-08 | Đã triển khai | Có controller; chưa kiểm chứng chạy | Có bằng chứng triển khai tĩnh; chưa chạy nghiệm thu thực tế. |
| Phân loại tuổi | MOB-FR-MOV-09 | Đã triển khai | Có controller; chưa kiểm chứng chạy | Có bằng chứng triển khai tĩnh; chưa chạy nghiệm thu thực tế. |
| Đang chiếu và sắp chiếu | MOB-FR-MOV-10 | Đã triển khai | Có controller; chưa kiểm chứng chạy | Có bằng chứng triển khai tĩnh; chưa chạy nghiệm thu thực tế. |
| Đạo diễn và diễn viên | MOB-FR-MOV-11 | Đã triển khai | Có controller; chưa kiểm chứng chạy | Có bằng chứng triển khai tĩnh; chưa chạy nghiệm thu thực tế. |
| Đánh giá phim | MOB-FR-MOV-12 | Đã triển khai | Có controller; chưa kiểm chứng chạy | Có bằng chứng triển khai tĩnh; chưa chạy nghiệm thu thực tế. |
| Xem sơ đồ phòng | MOB-FR-SEAT-03 | Đã triển khai | Có controller; chưa kiểm chứng chạy | Có bằng chứng triển khai tĩnh; chưa chạy nghiệm thu thực tế. |
| Suất và giá | MOB-FR-SHOW-03 | Đã triển khai | Có controller; chưa kiểm chứng chạy | Có bằng chứng triển khai tĩnh; chưa chạy nghiệm thu thực tế. |
| Suất mở chưa bắt đầu | MOB-FR-SHOW-06 | Đã triển khai | Có controller; chưa kiểm chứng chạy | Có bằng chứng triển khai tĩnh; chưa chạy nghiệm thu thực tế. |
| Suất theo phim | MOB-FR-SHOW-07 | Đã triển khai | Có controller; chưa kiểm chứng chạy | Có bằng chứng triển khai tĩnh; chưa chạy nghiệm thu thực tế. |
| Suất phim còn đặt được | MOB-FR-SHOW-08 | Đã triển khai | Có controller; chưa kiểm chứng chạy | Có bằng chứng triển khai tĩnh; chưa chạy nghiệm thu thực tế. |
| Định dạng chiếu | MOB-FR-SHOW-13 | Đã triển khai | Có controller; chưa kiểm chứng chạy | Có bằng chứng triển khai tĩnh; chưa chạy nghiệm thu thực tế. |
| Giữ chỗ đặt vé | MOB-FR-BOOK-01 | Đã triển khai | Có controller; chưa kiểm chứng chạy | Có bằng chứng triển khai tĩnh; chưa chạy nghiệm thu thực tế. |
| Chi tiết vé | MOB-FR-BOOK-02 | Đã triển khai | Có controller; chưa kiểm chứng chạy | Có bằng chứng triển khai tĩnh; chưa chạy nghiệm thu thực tế. |
| Lịch sử vé của mình | MOB-FR-BOOK-04 | Triển khai một phần | Có controller; chưa kiểm chứng chạy | Chỉ tải 50 vé đầu; UI thiếu vé cũ hơn. |
| Xác nhận vé đã trả | MOB-FR-BOOK-05 | Đã triển khai | Có controller; chưa kiểm chứng chạy | Có bằng chứng triển khai tĩnh; chưa chạy nghiệm thu thực tế. |
| Huỷ vé | MOB-FR-BOOK-06 | Đã triển khai | Có controller; chưa kiểm chứng chạy | Có bằng chứng triển khai tĩnh; chưa chạy nghiệm thu thực tế. |
| ID ghế đã chiếm | MOB-FR-BOOK-07 | Đã triển khai | Có controller; chưa kiểm chứng chạy | Có bằng chứng triển khai tĩnh; chưa chạy nghiệm thu thực tế. |
| Xung đột ghế đồng thời | MOB-FR-BOOK-08 | Đã triển khai | Có controller; chưa kiểm chứng chạy | Có bằng chứng triển khai tĩnh; chưa chạy nghiệm thu thực tế. |
| Cặp sweetbox | MOB-FR-BOOK-09 | Đã triển khai | Có controller; chưa kiểm chứng chạy | Có bằng chứng triển khai tĩnh; chưa chạy nghiệm thu thực tế. |
| Hết hạn giữ chỗ chưa trả | MOB-FR-BOOK-10 | Đã triển khai | Có controller; chưa kiểm chứng chạy | Có bằng chứng triển khai tĩnh; chưa chạy nghiệm thu thực tế. |
| Làm mới sơ đồ khách | MOB-FR-BOOK-11 | Đã triển khai | Có controller; chưa kiểm chứng chạy | Có bằng chứng triển khai tĩnh; chưa chạy nghiệm thu thực tế. |
| Bắp nước kèm vé | MOB-FR-BOOK-13 | Đã triển khai | Có controller; chưa kiểm chứng chạy | Có bằng chứng triển khai tĩnh; chưa chạy nghiệm thu thực tế. |
| Khuyến mãi và mã giảm giá | MOB-FR-BOOK-15 | Đã triển khai | Có controller; chưa kiểm chứng chạy | Có bằng chứng triển khai tĩnh; chưa chạy nghiệm thu thực tế. |
| Điểm thành viên | MOB-FR-BOOK-17 | Đã triển khai | Có controller; chưa kiểm chứng chạy | Có bằng chứng triển khai tĩnh; chưa chạy nghiệm thu thực tế. |
| Chia sẻ và lịch | MOB-FR-BOOK-19 | Triển khai một phần | Có controller; chưa kiểm chứng chạy | Lịch dùng giờ kết thúc thật hoặc dự phòng 150 phút; chia sẻ dự phòng clipboard. |
| Tạo/dùng lại link PayOS | MOB-FR-PAY-01 | Đã triển khai | Có controller; chưa kiểm chứng chạy | Có bằng chứng triển khai tĩnh; chưa chạy nghiệm thu thực tế. |
| Xác minh PayOS | MOB-FR-PAY-02 | Đã triển khai | Có controller; chưa kiểm chứng chạy | Có bằng chứng triển khai tĩnh; chưa chạy nghiệm thu thực tế. |
| Chi tiết thanh toán | MOB-FR-PAY-03 | Đã triển khai | Có controller; chưa kiểm chứng chạy | Có bằng chứng triển khai tĩnh; chưa chạy nghiệm thu thực tế. |
| Lịch sử thanh toán của mình | MOB-FR-PAY-04 | Đã triển khai | Có controller; chưa kiểm chứng chạy | Có bằng chứng triển khai tĩnh; chưa chạy nghiệm thu thực tế. |
| Truy cập hoàn tiền | MOB-FR-PAY-06 | Đã triển khai | Có controller; chưa kiểm chứng chạy | Có bằng chứng triển khai tĩnh; chưa chạy nghiệm thu thực tế. |
| Webhook có chữ ký | MOB-FR-PAY-07 | Đã triển khai | Có controller; chưa kiểm chứng chạy | Có bằng chứng triển khai tĩnh; chưa chạy nghiệm thu thực tế. |
| Thanh toán muộn | MOB-FR-PAY-08 | Đã triển khai | Có controller; chưa kiểm chứng chạy | Có bằng chứng triển khai tĩnh; chưa chạy nghiệm thu thực tế. |
| Tự kiểm tra thanh toán | MOB-FR-PAY-11 | Đã triển khai | Có controller; chưa kiểm chứng chạy | Có bằng chứng triển khai tĩnh; chưa chạy nghiệm thu thực tế. |
| Tạo yêu cầu hoàn tiền | MOB-FR-REF-01 | Đã triển khai | Có controller; chưa kiểm chứng chạy | Có bằng chứng triển khai tĩnh; chưa chạy nghiệm thu thực tế. |
| Mở lại hoàn tiền đã từ chối | MOB-FR-REF-05 | Đã triển khai | Có controller; chưa kiểm chứng chạy | Có bằng chứng triển khai tĩnh; chưa chạy nghiệm thu thực tế. |
| Trạng thái hoàn tiền của mình | MOB-FR-REF-06 | Đã triển khai | Có controller; chưa kiểm chứng chạy | Có bằng chứng triển khai tĩnh; chưa chạy nghiệm thu thực tế. |
| Một hoàn tiền mỗi thanh toán | MOB-FR-REF-07 | Đã triển khai | Có controller; chưa kiểm chứng chạy | Có bằng chứng triển khai tĩnh; chưa chạy nghiệm thu thực tế. |
| QR vé | MOB-FR-CHK-01 | Đã triển khai | Có controller; chưa kiểm chứng chạy | Có bằng chứng triển khai tĩnh; chưa chạy nghiệm thu thực tế. |
| Tra mã vé | MOB-FR-CHK-02 | Đã triển khai | Có controller; chưa kiểm chứng chạy | Có bằng chứng triển khai tĩnh; chưa chạy nghiệm thu thực tế. |
| Kiểm tra check-in | MOB-FR-CHK-03 | Đã triển khai | Có controller; chưa kiểm chứng chạy | Có bằng chứng triển khai tĩnh; chưa chạy nghiệm thu thực tế. |
| Camera/nhập mã | MOB-FR-CHK-04 | Đã triển khai | Có controller; chưa kiểm chứng chạy | Có bằng chứng triển khai tĩnh; chưa chạy nghiệm thu thực tế. |
| Hiện giờ check-in | MOB-FR-CHK-05 | Đã triển khai | Có controller; chưa kiểm chứng chạy | Có bằng chứng triển khai tĩnh; chưa chạy nghiệm thu thực tế. |
| Lịch sử thông báo | MOB-FR-NOTI-01 | Đã triển khai | Có controller; chưa kiểm chứng chạy | Có bằng chứng triển khai tĩnh; chưa chạy nghiệm thu thực tế. |
| Chi tiết thông báo | MOB-FR-NOTI-04 | Đã triển khai | Có controller; chưa kiểm chứng chạy | Có bằng chứng triển khai tĩnh; chưa chạy nghiệm thu thực tế. |
| Email sự kiện | MOB-FR-NOTI-06 | Triển khai một phần | Có controller; chưa kiểm chứng chạy | Có chống lặp sự kiện; khoảng sự cố SMTP/DB không bảo đảm gửi đúng một lần tuyệt đối. |
| Email OTP và chào mừng | MOB-FR-NOTI-07 | Đã triển khai | Có controller; chưa kiểm chứng chạy | Có bằng chứng triển khai tĩnh; chưa chạy nghiệm thu thực tế. |
| Nhắc giờ chiếu | MOB-FR-NOTI-08 | Đã triển khai | Có controller; chưa kiểm chứng chạy | Có bằng chứng triển khai tĩnh; chưa chạy nghiệm thu thực tế. |
| Thông báo đã/chưa đọc | MOB-FR-NOTI-09 | Đã triển khai | Có controller; chưa kiểm chứng chạy | Có bằng chứng triển khai tĩnh; chưa chạy nghiệm thu thực tế. |
| Bảo vệ và khôi phục route | MOB-FR-NAV-01 | Đã triển khai | Client/nền tảng; không API riêng | Có bằng chứng triển khai tĩnh; chưa chạy nghiệm thu thực tế. |
| Trạng thái tải, lỗi và rỗng | MOB-FR-STATE-01 | Triển khai một phần | Client/nền tảng; không API riêng | Có widget trạng thái; chưa chạy kiểm tra toàn bộ thiết bị/nhánh lỗi. |
| Media phim theo nền tảng | MOB-FR-MEDIA-01 | Triển khai một phần | Có controller; chưa kiểm chứng chạy | Trailer native mở ngoài; preview web có stub native rỗng. |

| Chức năng | Yêu cầu SRS | Trạng thái code | Trạng thái API | Ghi chú |
| --- | --- | --- | --- | --- |
| UI do .NET dựng | MOB-CON-01 | Chưa triển khai | Có API ASP.NET | Chỉ UI Flutter Web; yêu cầu môn [CẦN XÁC NHẬN] |
| Thông báo đẩy FCM | MOB-FUT-02 | Chưa triển khai | — | Tương lai, không phải FR hiện tại |
| Kiểm chứng SQL submodule DB | MOB-CON-02 | Cần xác nhận | Có mapping EF cục bộ | Submodule chưa khởi tạo; chưa kiểm tra DB thật |

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
