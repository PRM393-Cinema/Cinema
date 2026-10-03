# Giám sát: metrics, trace, log

Theo SRS §11 (Observability) và §5 (Monitoring: Prometheus + Grafana / OpenTelemetry):

- **Metrics**: mỗi service đếm request, độ trễ, lỗi và số liệu nghiệp vụ. Prometheus đọc, Grafana vẽ biểu đồ.
- **Trace**: Jaeger hiện một request đi qua gateway, các service, database và RabbitMQ mất bao lâu ở từng bước.
- **Log**: mỗi dòng log kèm TraceId và CorrelationId để tra sang trace.

## 1. Bật

```powershell
docker compose --profile monitoring up -d --build
```

| Công cụ | Địa chỉ | Dùng để |
|---|---|---|
| **Grafana** | http://localhost:3000 | Dashboard **Cinema - Tổng quan**, mở thẳng, không cần đăng nhập |
| Prometheus | http://localhost:9090 | *Status → Target health*: Prometheus có đọc được metrics của từng service không |
| **Jaeger** | http://localhost:16686 | Xem trace của từng request |

- Không thêm `--profile monitoring` thì chỉ chạy backend như cũ, không tải và không chạy 3 công cụ trên.
- Lần đầu tải 3 image, khoảng 520 MB.
- Tắt riêng phần giám sát: `docker compose --profile monitoring stop prometheus grafana jaeger`.
- Cả 3 chỉ mở cho máy này (`127.0.0.1`), máy khác trong mạng không vào được.

## 2. Dashboard Grafana

| Nhóm | Xem gì |
|---|---|
| Tình trạng chung | Service nào đang chạy (UP / DOWN). Số request / giây, tỉ lệ lỗi 5xx, độ trễ p95 đo ở gateway |
| HTTP | Request / giây và độ trễ p95 theo từng service. Lỗi theo mã trạng thái. Các lời gọi sang service khác và PayOS |
| Nghiệp vụ | Booking, thanh toán, hoàn tiền theo trạng thái, trong khoảng thời gian đang xem (góc phải trên) |
| RabbitMQ | Số event gửi lên mỗi phút và số lần gửi lỗi. Message đang chờ trong từng queue (queue `*.dlq` có message nghĩa là có event xử lý lỗi) |
| .NET runtime | Bộ nhớ, thread pool, số exception |

Sửa dashboard trên Grafana xong muốn giữ lại cho cả nhóm: chọn *Export → Export as JSON*, ghi đè file `docker/monitoring/grafana/dashboards/cinema-overview.json` rồi commit. Grafana chỉ đọc file này lúc khởi động: sửa file xong (hoặc pull bản mới) thì chạy `docker compose restart grafana`.

## 3. Metrics (`/metrics`)

Mỗi service có endpoint `/metrics` theo định dạng Prometheus, không cần token:
- **Có sẵn**:
  - `http_server_request_duration_seconds`: request theo route và mã trạng thái.
  - `http_client_request_duration_seconds`: gọi sang service khác và PayOS.
  - `process_runtime_dotnet_*`: số liệu .NET runtime.
- **Nghiệp vụ** (BookingService):

| Metric | Nhãn |
|---|---|
| `cinema_bookings_total` | `status`: `created` / `confirmed` / `cancelled` / `expired` |
| `cinema_payments_total` | `status`: `created` / `succeeded` / `failed` |
| `cinema_refunds_total` | `status`: `requested` / `completed` |
| `cinema_outbox_published_total`, `cinema_outbox_publish_failures_total` | `database`: event gửi lên RabbitMQ / số lần gửi lỗi |

Gateway là service duy nhất mở ra mạng LAN. Trong Docker, `/metrics` của gateway chỉ trả ở cổng nội bộ 9464, nơi Prometheus đọc. Gọi `http://<IP máy>:5000/metrics` sẽ nhận 404.

## 4. Trace (Jaeger)

Một trace cho thấy request đi qua những đâu và mất bao lâu ở từng bước: gateway, service, các câu SQL, lời gọi sang MovieService và PayOS.

**Event qua RabbitMQ cũng nằm trong cùng trace.** Ví dụ khách huỷ vé, trace gồm:
1. Request `POST /bookings/{id}/cancel` qua gateway rồi tới BookingService.
2. `outbox booking.cancelled`: worker gửi event lên RabbitMQ.
3. `deliver` ở consumer: tạo yêu cầu hoàn tiền, gửi email.

**Tìm trace của một request**:
- Mọi response từ gateway có header `X-Correlation-ID`.
- Trong Jaeger, chọn *Service* `api-gateway`, ô *Tags* nhập `correlation.id=<giá trị header>`, rồi bấm *Find Traces*.
- Hoặc vào Grafana, *Explore*, chọn nguồn *Jaeger*.

Ghi chú:
- Truy vấn chạy nền (quét outbox mỗi giây, job hết hạn booking, health check) không được ghi trace, để Jaeger không bị ngập.
- Jaeger lưu trace trong bộ nhớ, khởi động lại container là mất.

## 5. Log

- Mỗi dòng log có thêm `TraceId`, `SpanId` và `CorrelationId`. Lọc toàn bộ log của một request:
  ```powershell
  docker compose logs booking-service | Select-String "<TraceId hoặc CorrelationId>"
  ```
- Lỗi nghiệp vụ (4xx) ghi mức `warn` một dòng, không kèm stack trace. Lỗi hệ thống (5xx) ghi mức `fail`, kèm stack trace.
- Log dạng JSON (cho công cụ gom log): thêm biến môi trường `Logging__Console__FormatterName: json` cho service trong `docker-compose.yml`.

## 6. Chạy bằng Visual Studio

- `/metrics` có sẵn ở cổng của từng service, ví dụ http://localhost:5063/metrics.
- Muốn xem trace:
  1. Bật Jaeger: `docker compose --profile monitoring up -d jaeger`.
  2. Đặt nơi gửi trace cho service cần xem (làm một lần), rồi chạy lại service:
     ```powershell
     dotnet user-secrets set "Observability:OtlpTracesEndpoint" "http://localhost:4318/v1/traces" --project BookingService/BookingService
     ```
- Prometheus và Grafana trong Docker chỉ đọc metrics của các service chạy trong Docker, không đọc service chạy bằng Visual Studio.

## 7. Lỗi thường gặp

| Hiện tượng | Cách xử lý |
|---|---|
| Biểu đồ Grafana báo *No data* | Chờ 15–30 giây cho Prometheus đọc lần đầu. Mở http://localhost:9090/targets: các target phải `UP` |
| Một target `DOWN` | Service đó đang dừng hoặc khởi động lại: `docker compose ps`, `docker compose logs <service>` |
| Jaeger không có service nào | Gửi vài request qua gateway rồi chờ 5 giây. Kiểm tra `.env` không đặt `OTEL_TRACES_ENDPOINT=` (để trống là tắt gửi trace) |
| `Bind for 127.0.0.1:3000 failed: port is already allocated` | Cổng 3000 đang bị chương trình khác dùng: đổi `"127.0.0.1:3000:3000"` thành `"127.0.0.1:3001:3000"` trong `docker-compose.yml`, rồi mở http://localhost:3001 |
