# Thanh toán PayOS

Key PayOS đặt ở đâu: [SETUP_SECRETS.md mục 6](SETUP_SECRETS.md#6-payos--smtp-tuỳ-chọn) (chạy bằng Visual Studio) hoặc `.env` (chạy bằng Docker).

## 1. Luồng đặt vé và thanh toán

1. `POST /api/v1/bookings`: booking `PENDING`, giữ ghế **10 phút** (`expiresAt`). Giờ chiếu và tên phim do server lấy từ MovieService, email nhận vé lấy từ token của khách.
2. `POST /api/v1/payments/payos/checkout`: trả `checkoutUrl`, app mở link này. Link PayOS **hết hạn cùng lúc** với thời gian giữ ghế.
3. Khách trả tiền, PayOS gọi **webhook** về BookingService. Chữ ký hợp lệ thì payment `SUCCESS`, booking `CONFIRMED` và email vé được gửi (qua RabbitMQ).
4. PayOS chuyển khách về `returnUrl`. App gọi `POST /api/v1/payments/payos/{orderCode}/verify` để lấy kết quả. Webhook xử lý trước rồi thì verify chỉ trả kết quả, không xác nhận lần hai. Payment `REFUND_PENDING` nghĩa là tiền đã nhận nhưng không giữ được ghế (mục 4).
   - Khách bấm **Huỷ** trên trang PayOS (về `cancelUrl`): verify chuyển payment `FAILED`, booking `CANCELLED` và nhả ghế ngay.

`orderCode` của PayOS chính là id của booking.

## 2. Trạng thái

| Booking | Ý nghĩa |
|---|---|
| `PENDING` | Đang giữ ghế, chờ thanh toán |
| `CONFIRMED` | Đã thanh toán, hoặc Staff xác nhận tại quầy |
| `EXPIRED` | Quá 10 phút chưa trả tiền. Job nền chuyển trạng thái (mỗi 30 giây, cấu hình `BookingExpiry`) và nhả ghế |
| `CANCELLED` | Khách hoặc Staff huỷ, hoặc khách huỷ trên trang PayOS |

| Payment | Ý nghĩa |
|---|---|
| `PENDING` | Đã tạo link, chưa trả tiền |
| `SUCCESS` | PayOS xác nhận đã nhận tiền |
| `FAILED` | Khách huỷ thanh toán, hoặc booking hết hạn trước khi trả |
| `REFUND_PENDING` | Đã ghi nhận yêu cầu hoàn tiền, chờ Staff chuyển khoản |
| `REFUNDED` | Staff đã chuyển khoản hoàn tiền |

**Trả tiền muộn** (booking đã `EXPIRED`):
- Ghế còn trống: hệ thống vẫn xác nhận vé.
- Ghế đã có người khác đặt: booking giữ `EXPIRED`, hệ thống **tự tạo yêu cầu hoàn 100%** (mục 4).

## 3. Webhook

- URL: `POST https://<địa chỉ public>/api/v1/payments/payos/webhook`. Không cần JWT; mỗi request được xác thực bằng chữ ký HMAC-SHA256 với **Checksum Key**.
- Đăng ký trên [my.payos.vn](https://my.payos.vn): chọn kênh thanh toán, mục cài đặt, ô **Webhook URL**. Khi lưu, PayOS gửi thử một đơn mẫu (`orderCode` 123). Hệ thống trả 200 để PayOS chấp nhận URL.
- PayOS phải gọi tới được máy chạy backend. Chạy trên máy cá nhân thì cần một tunnel, ví dụ `cloudflared tunnel --url http://localhost:5000` hoặc ngrok, rồi đăng ký URL mà tunnel cấp.
- Webhook trả về như sau:
  - Chữ ký sai: **400**, không dùng dữ liệu trong request.
  - Đơn không tồn tại hoặc sai số tiền: **200**, bỏ qua và ghi log.
  - PayOS gửi lại cùng một đơn: **200**, không xác nhận hay gửi email lần hai.
- Chưa đặt key PayOS thì webhook trả **503**.

## 4. Huỷ vé và hoàn tiền (FR-PAY-06)

**Chính sách**:
- Khách tự huỷ vé đã thanh toán khi còn **ít nhất 2 giờ** trước giờ chiếu, được hoàn **100%**. Số giờ cấu hình ở `RefundPolicy:CustomerCancelBeforeHours`. Muộn hơn thì API trả 409, khách liên hệ rạp.
- Staff/Admin huỷ được mọi lúc.
- Suất chiếu bị huỷ thì mọi vé của suất đó tự huỷ và được hoàn tiền.

**PayOS không có API hoàn tiền** cho đơn thanh toán. Hệ thống ghi nhận yêu cầu, còn Staff chuyển khoản trả khách:

1. Vé đã thanh toán bị huỷ, hoặc trả tiền muộn mà không giữ được ghế. Hệ thống tạo yêu cầu hoàn (`PENDING`), payment chuyển `REFUND_PENDING`, khách nhận email.
2. Staff xem danh sách cần hoàn bằng `GET /api/v1/payments/refunds?status=PENDING`. Mỗi yêu cầu có số tiền và tài khoản khách đã dùng để trả (`payerAccountNumber`, `payerAccountName`, `payerBankName` do PayOS gửi kèm webhook).
3. Staff chuyển khoản xong thì gọi `POST /api/v1/payments/refunds/{refundId}/complete` với body `{ "transactionRef": "<mã giao dịch>" }`. Payment chuyển `REFUNDED`, khách nhận email kèm mã giao dịch.

Staff hoàn tiền chủ động (ví dụ khách đến quầy) bằng `POST /api/v1/payments/{paymentId}/refund?reason=...`: booking còn hiệu lực thì được huỷ luôn, rồi tạo yêu cầu hoàn.

Khách xem trạng thái hoàn tiền: `GET /api/v1/payments/{paymentId}/refund`.

Email và yêu cầu hoàn tiền khi huỷ vé được xử lý qua RabbitMQ ([MESSAGING.md](MESSAGING.md)), thường xong sau 1–2 giây.

## 5. Test trên máy, không cần trả tiền thật

Tạo booking và link PayOS như bình thường, rồi giả lập PayOS báo đã thanh toán:

```powershell
.\scripts\payos-webhook.ps1 -OrderCode <bookingId> -Amount <totalAmount>
```

Script ký request bằng `PAYOS_CHECKSUM_KEY` trong `.env`, giống cách PayOS ký, rồi gọi webhook qua gateway (`http://localhost:5000`). Chạy BookingService bằng Visual Studio thì thêm `-BaseUrl http://localhost:5063 -ChecksumKey <key trong User Secrets>`.
