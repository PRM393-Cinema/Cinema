# Đặc tả giao diện CosmoQ Cinema

Tài liệu mô tả giao diện hiện có của ứng dụng Angular theo các template, stylesheet và route trong `src/`. Đây là đặc tả trạng thái đang triển khai, không phải thiết kế mới. Nội dung mô tả cả cấu trúc, kiểu hiển thị, màu sắc, responsive và trạng thái tương tác để làm căn cứ bảo trì hoặc đồng bộ UI.

## 1. Tổng quan

CosmoQ Cinema là giao diện đặt vé rạp phim, có hai vùng sử dụng:

- **Khách hàng:** xem phim, chọn suất và ghế, thanh toán, tra cứu vé và thông tin tài khoản.
- **Quản trị/nhân viên:** dashboard và công cụ quản lý phim, phòng, suất chiếu, booking, thanh toán; quản lý user chỉ dành cho admin.

Ứng dụng dùng Angular standalone components, Angular Router và Tailwind CSS. Phong cách chung là nền tối kiểu cinematic, lớp kính mờ, viền mảnh, điểm sáng neon cyan/cam và hiệu ứng glow nhẹ. Phần nội dung thường nằm trong container giới hạn chiều rộng; admin ưu tiên bảng và mật độ dữ liệu, khách hàng ưu tiên poster, thẻ nội dung và các bước đặt vé.

## 2. Design tokens

### Bảng màu

| Vai trò          | Màu                                               | Cách dùng hiện tại                                                             |
| ---------------- | ------------------------------------------------- | ------------------------------------------------------------------------------ |
| Nền chính        | `#0c0f16` (`deep-black`)                          | Nền body, trang khách hàng, admin và auth                                      |
| Nền bề mặt       | `#101623`                                         | Nội dung avatar, poster fallback, input và một số bề mặt phụ                   |
| Bề mặt tối       | `#020617` (`slate-950`) / `#0f172a` (`slate-900`) | Input, bảng, vùng nội dung tương phản                                          |
| Trắng            | `#ffffff`                                         | Tiêu đề, nội dung chính và biểu tượng                                          |
| Cyan neon        | `#00f0ff` (`glow-cyan`)                           | Brand, liên kết đang chọn, focus, tổng tiền/nhãn chính và trạng thái đang chọn |
| Cam              | `#f97316` (`glow-orange`)                         | CTA mua vé, doanh thu/giá, vai trò admin và điểm nhấn cảnh báo nhẹ             |
| Xanh dương       | `#2563eb` / `blue-400`                            | Đầu chuyển sắc cùng cyan trong CTA và tiêu đề                                  |
| Xanh thành công  | `#22c55e` / emerald                               | Vé/ghế chọn, hoàn tất, trạng thái thành công                                   |
| Hồng SweetBox    | `#ff007f`                                         | Loại ghế đôi trên sơ đồ ghế                                                    |
| Đỏ lỗi/nguy hiểm | `red-400`–`red-600`                               | Lỗi, xóa, hủy và xác nhận nguy hiểm                                            |
| Vàng/cam chờ     | `amber-400`–`amber-500`                           | Giá, trạng thái pending/cảnh báo                                               |
| Trung tính       | `slate-300`–`slate-600`, `white/5`–`white/15`     | Nội dung phụ, đường phân cách, viền và bề mặt hover                            |

Màu cyan/cam thường được dùng với alpha thấp cho nền/viền (khoảng 5–30%) và shadow phát sáng. Nền hiệu ứng trang thường có vùng blur cyan và cam; trang home có thêm một glow tím. Trạng thái phải có nhãn/chữ đi kèm màu, không chỉ dựa vào màu sắc.

### Typography

- `src/index.html` tải **Inter** (300–700) và **Outfit** (400–800); body dùng `font-sans` của Tailwind.
- Home đặt Inter làm font nội dung và Outfit cho tiêu đề/điểm nhấn. Navbar dùng Outfit cho logo; một số màn admin/profile đặt Outfit. Phần còn lại chủ yếu kế thừa font sans của Tailwind.
- Tiêu đề trang phổ biến: `text-3xl`, đậm/extra-bold; tiêu đề phần: `text-xl`–`text-2xl`; nội dung: `text-sm`; nhãn bảng/form: `text-xs`, thường uppercase và tracking rộng.
- Mã vé, ngày giờ, ID và số liệu thường dùng kiểu mono.
- Nội dung giao diện hiện trộn tiếng Việt và tiếng Anh; các trang giao dịch/profile thiên về tiếng Việt, nhiều nhãn auth/admin/home vẫn là tiếng Anh.

### Bề mặt, viền và hiệu ứng

- `.glass-panel`: nền `rgba(12, 15, 22, 0.6)`, blur nền 12px, viền trắng 10%.
- Thành phần kính thường phối với nền trong suốt/trắng 1–5%, viền trắng 5–15%, shadow mờ; modal dùng lớp phủ đen 60–75% và backdrop blur.
- Bo góc đang dùng nhiều cấp: `rounded-lg/xl/2xl/3xl` (xấp xỉ 8–24px). Thẻ phim, panel đặt vé và modal lớn thường bo tròn hơn bảng hoặc input.
- Hover/focus thường đổi viền sang cyan, nâng sáng nền và thêm glow; CTA có gradient cyan→blue hoặc cam→amber. Một số thẻ poster có overlay gradient khi hover.
- Chuyển động hiện có: spinner tải, ping ở trạng thái hệ thống, fade-in modal/panel, hover scale nhẹ, glow/pulse và scan line trên mã vé.

## 3. Khung ứng dụng và điều hướng

### Navbar khách hàng

- Thanh cao 64px, sticky trên đầu trang, `z-index` cao; nền glass/blur và nội dung căn giữa trong container tối đa `max-w-7xl`.
- Logo COSMOQ bên trái: chữ cyan, ký tự Q trắng. Ở giữa là liên kết “Now Showing” trên desktop.
- Bên phải: khách chưa đăng nhập thấy “Sign In” và nút “Register”; người đã đăng nhập thấy avatar gradient cyan→cam và menu tài khoản. Admin/staff có thêm liên kết panel màu cam.
- Menu tài khoản hiển thị tên, email/vai trò, liên kết cài đặt và đăng xuất; dropdown mở dưới avatar.
- Ẩn navbar trên `/admin/**`, `/auth/**` và `/reset-password`; admin dùng sidebar riêng. Không có footer toàn cục trong shell hiện tại.

### Admin shell

- Chiếm toàn viewport, nền `deep-black`, chữ trắng; sidebar rộng 256px trên desktop và vùng nội dung chính cuộn độc lập.
- Sidebar có logo “Cinema”, role badge cam, avatar/tên/vai trò, điều hướng Dashboard, Movies, Bookings, Rooms, Showtimes, Payments; Users chỉ hiển thị với admin. Nút đăng xuất ở đáy.
- Mục đang chọn có chữ/viền trái cyan và nền cyan mờ; mục thường xám, hover sáng hơn.
- Dưới breakpoint `md` (768px), sidebar chuyển thành drawer phủ từ trái; header cố định có nút hamburger và overlay nền tối. Chọn liên kết sẽ đóng drawer.

### Settings shell

- Nền `#0c0f16`, nội dung giữa trang tối đa `max-w-6xl`, có glow cyan/cam và liên kết quay về trang chủ.
- Tiêu đề “Cài đặt tài khoản” nằm trên grid 4/12 + 8/12 ở desktop. Cột trái là panel user mini, avatar, email, menu Hồ sơ/Mật khẩu/Lịch sử vé/Lịch sử thanh toán và đăng xuất; cột phải là nội dung con.
- Trên màn nhỏ, grid thành một cột; menu điều hướng chuyển thành hàng ngang cuộn được.

## 4. Màn hình khách hàng

### Trang chủ `/`

- Navbar khách hàng phía trên, sau đó hero căn giữa trong `max-w-7xl`: nhãn “Experience Premium Cinema”, tiêu đề lớn “Step Into CosmoQ Cinema”, mô tả ngắn và gạch nhấn cyan.
- Phần “Now Screening” đặt dưới hero. Tiêu đề/mô tả bên trái, ô search có icon ở bên phải trên desktop; trên mobile xếp thành cột.
- Danh sách phim là grid 1 cột ở màn rất nhỏ, 2 cột từ `sm`, 3 từ `md`, 4 từ `lg`; poster tỷ lệ 2:3, nội dung nằm trong glass card. Hover poster phủ mô tả và CTA “Book Tickets”.
- Mỗi phim có tên, badge thể loại/language, thời lượng, ngày phát hành. Lỗi ảnh poster dùng fallback nền tối và icon.
- Có trạng thái loading spinner, lỗi kèm nút thử lại, danh sách rỗng có thông báo; không có phân trang ở phần template đang xem.

### Chi tiết phim `/movies/:id`

- Container tối đa `max-w-6xl`, nút quay lại, nền glow cyan/cam. Desktop chia 3 cột: poster chiếm 1/3; metadata, synopsis, trailer và lịch chiếu chiếm 2/3. Mobile xếp dọc.
- Poster đứng tỷ lệ 2:3. Khối metadata gồm tên phim, thể loại, ngôn ngữ, thời lượng, ngày phát hành và mô tả. CTA trailer màu cam mở modal video 16:9.
- Suất chiếu nhóm theo ngày; từng lựa chọn là nút hiển thị giờ, phòng và giá. Suất đã chọn có trạng thái nổi bật. Khi có lựa chọn, xuất hiện panel xác nhận cùng CTA “Select Seats” màu cam.
- Có loading, lỗi với nút thử tải lại, và empty state khi chưa có suất.

### Chọn ghế `/seats/:showtimeId`

- Chỉ truy cập sau đăng nhập. Trên desktop chia vùng bản đồ ghế 2/3 và panel tổng kết 1/3; mobile xếp dọc.
- Header tóm tắt có poster nhỏ, phim, phòng, ngày và giờ. Bản đồ ghế nằm trong glass panel: màn chiếu là vạch cyan phát sáng; hàng ghế có nhãn hàng hai bên và có thể cuộn ngang.
- Ghế đơn kích thước khoảng 36×36px; SweetBox hiển thị thành cặp rộng hơn. Quy ước: thường là nền/viền cyan rất nhẹ, VIP cam, SweetBox hồng, đang chọn xanh lá, đã đặt slate tối/mờ và không tương tác được.
- Legend nằm dưới sơ đồ. Panel “Vé Đã Chọn” cho biết ghế, loại và giá, số lượng/đơn giá/tổng tiền; sticky ở desktop. Nút sang thanh toán màu cam bị vô hiệu hóa khi chưa chọn ghế.
- Có loading, lỗi tải sơ đồ và nút thử lại.

### Checkout `/checkout`

- Chỉ truy cập sau đăng nhập. Container `max-w-6xl`, bố cục desktop 2/3 review vé và phương thức thanh toán + 1/3 tóm tắt hóa đơn sticky; mobile xếp dọc.
- Khối review có poster, thông tin phim/phòng/suất/giờ. Khối phương thức trình bày 4 lựa chọn dạng lưới: PayOS, thẻ tín dụng, QR và ví điện tử; mục chọn có trạng thái active.
- Nội dung thay đổi theo phương thức: hướng dẫn PayOS thật, form thẻ điền sẵn chỉ giả lập, QR mockup và thông tin ví mock. Nội dung này cần được hiểu là mô tả trạng thái hiện tại, không phải cam kết tất cả phương thức đều xử lý thật.
- Panel hóa đơn liệt kê ghế/giá, số vé, tạm tính, VAT 5% và tổng tiền. CTA xác nhận màu cam; khi xử lý, overlay toàn trang yêu cầu không đóng/tải lại trang. Có loading và error state.

### Kết quả thanh toán `/payment/result`

- Panel hẹp `max-w-lg` giữa trang; giao diện thay đổi theo state:
  - Đang xác thực: spinner cyan và lời nhắc chờ.
  - Thành công: biểu tượng/viền emerald, mã vé, phim, giờ, ghế, tổng tiền và CTA tới vé của tôi/trang chủ.
  - Đã hủy: amber, giải thích ghế được nhả và CTA về trang chủ.
  - Thất bại: đỏ, thông báo lỗi, nút thử lại và liên kết vé của tôi.

### Vé điện tử `/receipt`

- Trạng thái thành công căn giữa trên nền tối; headline xác nhận màu trắng với biểu tượng xanh lá.
- Vé dạng coupon: desktop chia ngang thành phần thông tin phim/suất/ghế/giá và cột QR/mã vé; đường đứt/perforation mô phỏng vé giấy. Mobile chuyển thành xếp dọc với đường đứt ngang.
- CTA xanh lá quay về trang chủ. Có loading xuất vé và lỗi tải hóa đơn.

## 5. Đăng nhập và tài khoản

Các trang auth không dùng navbar. Nền toàn màn hình tối, glow cyan/cam và form card glass căn giữa.

### Đăng nhập `/auth/login`

- Card tối đa khoảng 448px, padding lớn, heading căn giữa. Form email/mật khẩu theo cột; liên kết quên mật khẩu ở cạnh nhãn mật khẩu; CTA đăng nhập gradient cyan→blue.
- Có validation inline đỏ, banner lỗi API, trạng thái đang gửi, lớp thông báo thành công và modal quên mật khẩu nhập email.
- Cuối card có liên kết đăng ký.

### Đăng ký `/auth/register`

- Card rộng hơn, tối đa khoảng 512px; form gồm họ tên, email, số điện thoại tùy chọn và mật khẩu. CTA cyan→blue, liên kết quay lại đăng nhập.
- Dùng validation inline, banner lỗi và overlay xác nhận tạo tài khoản.

### Đặt lại mật khẩu `/reset-password`

- Card tối đa khoảng 448px, giao diện tiếng Việt. Form mật khẩu mới/xác nhận; các trạng thái thiếu token, lỗi, thành công được hiển thị trong cùng card. Accent cyan; thành công emerald, lỗi đỏ.

### Cài đặt `/settings/**`

- **Hồ sơ `/settings/profile`:** avatar gradient, thông tin tên/email/điện thoại/vai trò/ngày tạo trong các ô 1–2 cột.
- **Mật khẩu `/settings/password`:** form tối đa `max-w-xl` gồm mật khẩu hiện tại, mật khẩu mới và xác nhận; lỗi đỏ, thành công emerald, nút lưu toàn chiều rộng màu cyan.
- **Lịch sử vé `/settings/bookings`:** danh sách card theo booking; mã, badge trạng thái, phim, giờ, phòng, ghế, tổng tiền và ngày đặt. Có thể hủy vé nếu đủ điều kiện; modal xác nhận hiển thị thông tin đơn và nút giữ/hủy. Mobile card chuyển thành cột.
- **Lịch sử thanh toán `/settings/payments`:** bảng giao dịch cuộn ngang, gồm mã giao dịch, booking, phương thức, thời gian, số tiền và status badge. Có loading, lỗi, empty state.

## 6. Màn hình quản trị

Các trang admin dùng chung nền `deep-black`, padding khoảng 24px mobile/40px từ `md`, glow cyan/cam mờ ở nền, tiêu đề uppercase 30px và mô tả phụ. Nút tạo mới thường là gradient cyan→blue; form/filter nằm trong glass panel. Bảng có header nền slate tối, chữ nhãn uppercase nhỏ, hàng phân cách mảnh, hover sáng nhẹ và vùng cuộn ngang. Modal dùng overlay đen blur, panel glass và form nền tối. Trạng thái phổ biến là loading spinner, error banner đỏ, empty row/card và success overlay.

### Dashboard `/admin/dashboard`

- Header “Admin/Staff Dashboard”, mô tả theo vai trò và badge hệ thống đang chạy màu cyan.
- Lưới 4 metric cards; mobile 1 cột, tablet 2 cột, desktop 4 cột.
- Admin thấy tổng người dùng, booking tháng, phim đang chiếu, doanh thu tháng. Staff thấy vé bán, suất chiếu, booking và doanh thu hôm nay. Doanh thu nhấn bằng cam; số liệu khác trắng.
- Có loading và lỗi kèm nút thử lại. Template hiện tại tập trung vào KPI cards, không thể hiện biểu đồ.

### Phim `/admin/movies`

- Header “Movie Catalog” và nút “Add New Movie”. Bảng cuộn ngang gồm poster, tên, thể loại, thời lượng, ngôn ngữ, ngày phát hành, trạng thái và thao tác sửa/xóa.
- Trạng thái ACTIVE xanh lá, trạng thái khác đỏ. Footer phân trang đặt trong nền slate.
- Modal tạo/sửa tối đa khoảng 672px; desktop chia hai cột, trường title/URL/trailer/description trải hết hàng. Trường gồm tên, thể loại, thời lượng, ngôn ngữ, ngày phát hành, poster URL, trailer URL, synopsis, trạng thái.
- Xóa dùng modal xác nhận đỏ; tạo/sửa thành công dùng overlay thông báo. Có loading, lỗi và empty state với CTA thêm phim.

### Người dùng `/admin/users`

- Admin-only. Bảng gồm ID, tên, email, điện thoại, role, trạng thái và thao tác. Role badge phân màu: ADMIN cam, STAFF cyan, CUSTOMER trung tính; enabled emerald, disabled đỏ.
- Hành động: sửa, bật/tắt trạng thái, xóa. Modal tạo/sửa nhập tên, email, điện thoại, mật khẩu, role và enabled; modal xóa xác nhận riêng. Lỗi/đang tải và empty row hiển thị trong trang.

### Phòng chiếu `/admin/rooms`

- Desktop chia 4/12 danh sách phòng và 8/12 cấu hình sơ đồ ghế; mobile xếp dọc. Danh sách chọn phòng hiển thị tên/sức chứa và trạng thái selected cyan.
- Khu sơ đồ có màn chiếu, hàng ghế và toolbar chọn loại NORMAL/VIP/SWEETBOX. Màu tương ứng cyan/cam/hồng; có chọn/kéo để đổi hàng loạt. SweetBox phải ghép cặp.
- Nút sửa/xóa phòng nằm cạnh tiêu đề sơ đồ. Modal tạo/sửa nhập tên, số hàng, số ghế mỗi hàng và tính sức chứa tức thời; có cảnh báo khi thay đổi sơ đồ. Xóa có modal xác nhận; thay đổi loại ghế hiển thị được lưu tự động.

### Suất chiếu `/admin/showtimes`

- Bảng gồm phim, phòng, giờ bắt đầu/kết thúc, giá, trạng thái OPEN/CLOSE và thao tác sửa/xóa.
- Bộ modal tạo/sửa gồm chọn phim/phòng, thời gian bắt đầu/kết thúc, giá VND, trạng thái. Validation hiển thị dưới trường, bao gồm kiểm tra thời gian kết thúc sau bắt đầu.
- Có empty state, lỗi, xác nhận xóa và success overlay.

### Booking `/admin/bookings`

- Phần đầu có nút tạo đặt vé. Filter panel gồm trạng thái, từ ngày, đến ngày; bảng rộng cuộn ngang.
- Bảng hiện mã vé, người đặt, phim, suất, thời điểm tạo, ghế, tổng tiền, trạng thái, check-in và thao tác.
- Trạng thái dùng emerald (confirmed), đỏ (canceled), amber (pending), slate (expired); check-in hiển thị checked/not yet. Tùy trạng thái có thể thanh toán tại quầy, check-in hoặc hủy.
- Có modal tạo booking, modal xác nhận hủy, success overlay, lỗi và loading.

### Thanh toán `/admin/payments`

- Filter panel gồm trạng thái và booking ID. Bảng cuộn ngang gồm mã giao dịch, booking, khách hàng, phương thức, thời gian, số tiền, trạng thái.
- Status badge: SUCCESS emerald, FAILED đỏ, PENDING amber. Footer phân trang có số trang hiện tại và tổng giao dịch.
- Có loading, error banner và empty state.

## 7. Responsive và hành vi tương tác

Các breakpoint dùng theo Tailwind mặc định: `sm` 640px, `md` 768px, `lg` 1024px, `xl` 1280px.

- Bố cục grid dùng 1 cột nhỏ, tăng thành 2–4 cột từ `sm`/`md`/`lg`; các khối thông tin có `flex-col` trên mobile và chuyển hàng/cột ở desktop.
- Navbar chỉ hiện liên kết chính từ `md`; admin sidebar chuyển thành drawer dưới `md`.
- Bảng giao dịch và sơ đồ ghế cho phép cuộn ngang khi nội dung rộng; settings menu cũng cuộn ngang trên màn nhỏ.
- Panel tóm tắt ghế/hóa đơn dùng sticky ở desktop; modal có overlay và padding viewport.
- Focus input chuyển viền sang cyan; validation dùng đỏ; disabled giảm opacity, khóa thao tác và bỏ glow chính.
- Tương tác quan trọng dùng nút/anchor có trạng thái hover/disabled; thông báo thành công/lỗi thường ở dạng overlay hoặc banner.

## 8. Các điểm cần lưu ý khi dùng đặc tả

- Màu brand hiện được khai báo ở Tailwind, nhưng một số template dùng trực tiếp mã hex và một số dùng tên màu Tailwind; cập nhật palette cần rà cả hai dạng.
- Font Inter/Outfit được tải toàn cục nhưng việc áp dụng Outfit chưa đồng đều giữa các trang.
- Ngôn ngữ label chưa nhất quán Việt/Anh. Nên giữ nguyên nội dung hiện tại khi chỉ chỉnh bố cục, và tách một yêu cầu localization nếu muốn đồng bộ ngôn ngữ.
- Phương thức thẻ/QR/ví trên checkout được đánh dấu giả lập trong giao diện; PayOS được mô tả là tích hợp thật.
- Responsive đang dựa chủ yếu vào breakpoint Tailwind và overflow; các bảng admin nhiều cột cần kiểm tra trên thiết bị hẹp.
- Thành phần `glass-panel` dùng blur; khi giảm hiệu ứng vì hiệu năng hoặc accessibility cần giữ đủ tương phản giữa nền, viền và chữ.

## 9. Vị trí mã nguồn tham chiếu

- Global tokens/base: `tailwind.config.js`, `src/styles.css`, `src/index.html`.
- Root shell/routes: `src/app/app.component.html`, `src/app/app.component.ts`, `src/app/app.routes.ts`.
- Navbar: `src/app/shared/components/navbar/`.
- UI khách hàng: `src/app/features/client/`.
- Auth: `src/app/features/auth/`.
- Settings/profile: `src/app/features/profile/`.
- Admin: `src/app/features/admin/`.
