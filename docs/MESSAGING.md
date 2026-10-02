# RabbitMQ: event giữa các service

Các việc không cần trả kết quả ngay được làm **bất đồng bộ qua RabbitMQ** (SRS §13.1): gửi email, hoàn tiền, huỷ booking khi suất chiếu bị huỷ. API đặt vé / thanh toán không phải chờ các việc này, và không bị lỗi theo khi RabbitMQ hay SMTP tạm dừng (BR-13).

## 1. Chạy RabbitMQ

| Cách chạy | Làm gì |
|---|---|
| Docker (`docker compose up -d --build`) | Có sẵn container `rabbitmq`, không cần làm gì thêm |
| Visual Studio | Bật riêng RabbitMQ: `docker compose up -d rabbitmq` (service kết nối `localhost:5672`, tài khoản `cinema` / `cinema` trong `appsettings.json`) |

Trang quản lý: http://localhost:15672 (`cinema` / `cinema`). Ở đây xem được exchange, queue, số message đang chờ, message lỗi.

## 2. Event

Exchange `cinema.events` (topic), routing key = tên event.

| Event | Ai phát | Khi nào |
|---|---|---|
| `booking.created` | BookingService | Khách giữ ghế |
| `booking.confirmed` | BookingService | Thanh toán xong / Staff xác nhận tại quầy |
| `booking.cancelled` | BookingService | Khách / Staff huỷ, khách huỷ trên trang PayOS, suất chiếu bị huỷ |
| `booking.expired` | BookingService | Quá 10 phút chưa thanh toán |
| `payment.created` / `payment.succeeded` / `payment.failed` | BookingService | Tạo link PayOS / PayOS báo đã trả / huỷ hoặc hết hạn |
| `payment.refund_requested` / `payment.refunded` | BookingService | Có yêu cầu hoàn tiền / Staff đã chuyển khoản hoàn |
| `showtime.cancelled` | MovieService | Staff huỷ suất chiếu (`DELETE /api/showtimes/{id}`) |

Nội dung message: `{ "eventId", "eventType", "occurredAt", "data": { ... } }`. `data` mang đủ thông tin để gửi email (mã đặt vé, phim, giờ chiếu, ghế, email khách) nên bên nhận không phải gọi ngược lại.

## 3. Ai nhận event

| Queue | Nhận | Làm gì |
|---|---|---|
| `booking-service.notifications` | `booking.*`, `payment.*` | Gửi email: vé, huỷ vé, hết hạn, đã ghi nhận hoàn tiền, đã hoàn tiền |
| `booking-service.payment-updates` | `booking.cancelled`, `booking.expired` | Payment chưa trả thì chuyển `FAILED` (huỷ luôn link PayOS); đã trả thì tạo yêu cầu hoàn 100% |
| `booking-service.showtime-cancelled` | `showtime.cancelled` | Huỷ mọi booking còn hiệu lực của suất chiếu |

## 4. Vì sao không mất event, không xử lý trùng

- **Outbox** (BR-11): event được ghi vào bảng `outbox_messages` **trong cùng transaction** với dữ liệu (đặt vé, đổi trạng thái payment...).
  - Dữ liệu rollback thì event cũng mất.
  - Dữ liệu commit rồi thì worker nền gửi event lên RabbitMQ sau đó, và chỉ đánh dấu `published_at` khi RabbitMQ xác nhận đã nhận.
  - Mỗi database có outbox riêng: `cinema_booking_db`, `cinema_payment_db`, `cinema_showtime_db`.
- **RabbitMQ dừng**: đặt vé, thanh toán vẫn chạy bình thường, event nằm chờ trong outbox. RabbitMQ chạy lại thì event được gửi bù.
  - `/health` của service báo `rabbitmq: Degraded` kèm số event đang chờ (`pendingBookingEvents`...).
- **Chưa có queue nhận event** (service nhận chưa khởi động lần nào trên RabbitMQ mới): RabbitMQ trả message về, event nằm lại trong outbox và gửi lại khi queue đã được tạo.
- **Message giao lại** (SRS §13.1): RabbitMQ có thể giao một message nhiều lần, nên mọi consumer đều idempotent.
  - Notification lưu theo `eventId` (unique), nên không gửi email lần hai.
  - Mỗi payment chỉ có một yêu cầu hoàn tiền.
  - Booking đã huỷ thì bỏ qua.
- **Message lỗi**: consumer thử lại 3 lần. Vẫn lỗi (hoặc message không đọc được) thì message chuyển sang queue `<tên queue>.dlq`.
  - Xem message lỗi trong trang quản lý, mục *Queues*, sau khi đã sửa nguyên nhân.
- **SMTP lỗi**: notification lưu `FAILED` kèm lỗi. Staff gửi lại bằng `POST /api/v1/notifications/{id}/send`.

## 5. Cấu hình (`RabbitMq` trong appsettings / biến môi trường)

| Key | Mặc định | Ghi chú |
|---|---|---|
| `RabbitMq:HostName` / `Port` | `localhost` / `5672` | Docker: `rabbitmq` |
| `RabbitMq:UserName` / `Password` | `cinema` / `cinema` | Docker lấy từ `RABBITMQ_USER` / `RABBITMQ_PASSWORD` trong `.env` (để trống = mặc định) |
| `RabbitMq:Enabled` | `true` | `false`: không kết nối RabbitMQ. Event vẫn ghi vào outbox nhưng email / hoàn tiền tự động không chạy |

RabbitMQ chỉ mở ở `127.0.0.1` (máy khác trong mạng không kết nối được), nên dùng tài khoản mặc định cho môi trường dev là được.
