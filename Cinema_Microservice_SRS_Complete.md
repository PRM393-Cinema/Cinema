# SOFTWARE REQUIREMENTS SPECIFICATION
## CINEMA MANAGEMENT SYSTEM
**Microservice-based Cinema Booking Platform**  
**Version:** 1.0  
**Backend:** ASP.NET Core | **Frontend:** Flutter | **Database:** PostgreSQL  
**Architecture:** Microservices | API Gateway | RabbitMQ | JWT | PayOS  

---

## Document Control

| Item | Value |
| :--- | :--- |
| **Document** | Software Requirements Specification – Cinema Management System |
| **Version** | 1.0 |
| **System type** | Cinema management and online ticket booking platform |
| **Backend** | ASP.NET Core Web API |
| **Frontend** | Flutter |
| **Database** | PostgreSQL |
| **Architecture** | Microservices |
| **Authentication** | JWT + Role-Based Authorization |
| **Payment** | PayOS |
| **Messaging** | RabbitMQ |
| **Resilience** | Circuit Breaker / Retry using .NET resilience mechanisms |
| **Deployment** | Docker / Docker Compose |

---

## 1. Introduction

### 1.1 Purpose
Tài liệu này xác định phạm vi, nghiệp vụ, yêu cầu chức năng, yêu cầu phi chức năng, vai trò người dùng, luồng nghiệp vụ và các thành phần chính của **Cinema Management System**. SRS được dùng làm cơ sở thống nhất giữa nhóm phát triển Backend, Frontend, Database, QA và các bên liên quan trong quá trình thiết kế, triển khai và kiểm thử.

### 1.2 Product Vision
Xây dựng nền tảng quản lý rạp chiếu phim cho phép khách hàng xem phim, xem lịch chiếu, chọn ghế và đặt vé trực tuyến; nhân viên xử lý vận hành; quản trị viên quản lý toàn bộ dữ liệu và người dùng. Hệ thống được thiết kế theo microservice nhằm tách biệt nghiệp vụ, dễ mở rộng và tăng khả năng chịu lỗi.

---

## 2. Scope

### 2.1 In Scope
- Quản lý tài khoản, đăng ký, đăng nhập, JWT và phân quyền theo role.
- Quản lý phim: tạo, cập nhật, xóa/ẩn, tìm kiếm, xem phim đang hoạt động.
- Quản lý phòng chiếu và sơ đồ ghế.
- Quản lý suất chiếu theo phim, phòng, thời gian, giá và trạng thái.
- Đặt vé: tạo booking, kiểm tra ghế, xác nhận, hủy booking.
- Thanh toán online thông qua PayOS và quản lý trạng thái thanh toán.
- Gửi thông báo sau các sự kiện nghiệp vụ như đặt vé, thanh toán, hủy/refund.
- Tra cứu lịch sử booking và thanh toán của người dùng.
- Giao tiếp đồng bộ giữa service và bất đồng bộ qua RabbitMQ.
- Circuit Breaker/Retry cho các lời gọi service quan trọng.
- API Gateway làm điểm truy cập chính từ Flutter tới backend.
- Swagger/OpenAPI phục vụ phát triển và kiểm thử API.
- Docker hóa các thành phần và triển khai bằng Docker Compose.
- Health check, metrics và monitoring cho các service.

### 2.2 Out of Scope
- Quản lý nhân sự/chấm công của rạp.
- Kế toán doanh nghiệp và báo cáo tài chính chuyên sâu.
- Quản lý kho hàng hoặc chuỗi cung ứng.
- Hệ thống loyalty/điểm thưởng nâng cao nếu chưa được yêu cầu.
- AI recommendation hoặc machine learning.
- Tích hợp thiết bị POS/phần cứng rạp ở cấp độ production.
- Thanh toán ngoài các phương thức được nhóm lựa chọn trong phạm vi dự án.

---

## 3. Business Scope and Actors

| Actor | Mục tiêu chính | Quyền chính |
| :--- | :--- | :--- |
| **Customer** | Mua vé và quản lý giao dịch cá nhân | Xem phim/lịch chiếu, chọn ghế, booking, thanh toán, xem lịch sử, hủy theo chính sách |
| **Staff** | Vận hành rạp | Quản lý phòng/ghế/lịch chiếu theo quyền được cấp, hỗ trợ booking và xử lý nghiệp vụ tại rạp |
| **Admin** | Quản trị hệ thống | Quản lý user/role, phim, phòng, ghế, suất chiếu, booking, payment, notification và cấu hình |
| **System** | Tự động xử lý | JWT validation, service discovery/gateway routing, payment callback, event messaging, notification |

---

## 4. Business Rules

1. Mỗi tài khoản phải có thông tin định danh tối thiểu và được xác thực khi đăng nhập.
2. JWT là cơ chế xác thực cho các API yêu cầu đăng nhập.
3. Role được dùng để giới hạn API theo nghiệp vụ; Customer không được truy cập API quản trị.
4. Một ghế thuộc một phòng và không được trùng vị trí trong cùng phòng.
5. Một suất chiếu thuộc một phim và một phòng, có thời gian bắt đầu/kết thúc hợp lệ.
6. Không được tạo suất chiếu bị trùng thời gian trong cùng phòng nếu gây xung đột vận hành.
7. Ghế đã được booking/giữ hợp lệ không được bán cho booking khác.
8. Booking phải gắn với user, showtime và các ghế được chọn.
9. Thanh toán phải gắn với booking; trạng thái booking chỉ được chuyển theo các trạng thái hợp lệ.
10. Payment callback/webhook phải được kiểm tra trước khi cập nhật trạng thái thanh toán.
11. Các event quan trọng được phát sau khi transaction nghiệp vụ đã commit thành công.
12. Khi một downstream service lỗi, Circuit Breaker giúp tránh gọi liên tục và gây lan truyền lỗi.
13. Notification không được làm hỏng giao dịch booking/payment chính nếu notification service tạm thời unavailable.

---

## 5. System Architecture

Kiến trúc tổng thể gồm **Flutter Client** $ightarrow$ **API Gateway** $ightarrow$ **Các microservice**. Mỗi service sở hữu dữ liệu nghiệp vụ của mình. Các service giao tiếp đồng bộ khi cần response tức thời và dùng RabbitMQ cho các event không yêu cầu trả kết quả ngay.

| Component | Responsibility | Data / Integration |
| :--- | :--- | :--- |
| **Flutter** | UI, authentication state, movie browsing, booking, payment | HTTPS/REST qua Gateway |
| **API Gateway** | Routing, authentication/authorization, centralized entry point | Routes to services |
| **Auth Service** | User, role, login/register, JWT | PostgreSQL |
| **Movie Service** | Movie catalog | PostgreSQL |
| **Showtime Service** | Rooms, seats, showtimes | PostgreSQL |
| **Booking Service** | Booking, seat selection, booking status | PostgreSQL + service calls |
| **Payment Service** | Payment creation/process/refund | PostgreSQL + PayOS |
| **Notification Service** | Email/in-app notifications | PostgreSQL + RabbitMQ |
| **RabbitMQ** | Asynchronous domain events | Payment/Booking/Notification events |
| **Docker Compose** | Local orchestration | All infrastructure/services |
| **Monitoring** | Health/metrics/log observation | Prometheus + Grafana / OpenTelemetry |

---

## 6. Functional Requirements

### 6.1 Authentication & Authorization

| ID | Requirement | Priority |
| :--- | :--- | :--- |
| **FR-AUTH-01** | Customer/Staff/Admin đăng ký hoặc được tạo tài khoản theo chính sách. | High |
| **FR-AUTH-02** | Đăng nhập bằng credential hợp lệ và nhận JWT. | High |
| **FR-AUTH-03** | JWT chứa thông tin cần thiết để xác định user và role. | High |
| **FR-AUTH-04** | Gateway/service validate JWT trước API được bảo vệ. | High |
| **FR-AUTH-05** | Phân quyền API theo Customer/Staff/Admin. | High |
| **FR-AUTH-06** | API nhạy cảm trả 401 khi chưa xác thực và 403 khi không đủ quyền. | High |

### 6.2 Movie Management

| ID | Function | Actor | Expected behavior |
| :--- | :--- | :--- | :--- |
| **FR-MOV-01** | List movies | All | Trả danh sách phim, hỗ trợ pagination. |
| **FR-MOV-02** | Get movie detail | All | Trả thông tin chi tiết theo ID. |
| **FR-MOV-03** | Search movie | All | Tìm theo từ khóa và điều kiện hỗ trợ. |
| **FR-MOV-04** | List active movies | All | Chỉ trả phim đang hoạt động. |
| **FR-MOV-05** | Create movie | Admin | Tạo phim mới. |
| **FR-MOV-06** | Update movie | Admin | Cập nhật thông tin phim. |
| **FR-MOV-07** | Delete/deactivate movie | Admin | Ẩn/xóa logic theo chính sách. |

### 6.3 Room & Seat Management

| ID | Function | Actor | Expected behavior |
| :--- | :--- | :--- | :--- |
| **FR-ROOM-01** | List rooms | Staff/Admin | Xem danh sách phòng. |
| **FR-ROOM-02** | Room detail | Staff/Admin | Xem thông tin phòng. |
| **FR-ROOM-03** | Create room | Admin | Tạo phòng và số ghế theo thiết kế. |
| **FR-ROOM-04** | Update room | Admin | Cập nhật thông tin phòng. |
| **FR-ROOM-05** | Delete/deactivate room | Admin | Ngừng sử dụng phòng theo chính sách. |
| **FR-SEAT-01** | Generate seats | Admin/Staff | Sinh sơ đồ ghế theo cấu hình. |
| **FR-SEAT-02** | Get seat | Staff/Admin | Xem chi tiết ghế. |
| **FR-SEAT-03** | List seats by room | All authorized | Lấy sơ đồ ghế của phòng. |
| **FR-SEAT-04** | Delete/deactivate seat | Admin | Quản lý ghế. |

### 6.4 Showtime Management

| ID | Function | Actor | Expected behavior |
| :--- | :--- | :--- | :--- |
| **FR-SHOW-01** | List showtimes | All | Danh sách suất chiếu có pagination/filter. |
| **FR-SHOW-02** | Create showtime | Admin/Staff | Tạo suất chiếu với movie, room, time, price. |
| **FR-SHOW-03** | Get showtime detail | All | Xem chi tiết suất chiếu. |
| **FR-SHOW-04** | Update showtime | Admin/Staff | Cập nhật suất chiếu. |
| **FR-SHOW-05** | Delete/deactivate showtime | Admin/Staff | Đóng/hủy suất chiếu. |
| **FR-SHOW-06** | Open showtimes | All | Chỉ lấy suất chiếu đang mở. |
| **FR-SHOW-07** | Showtimes by movie | All | Lấy suất chiếu của phim. |
| **FR-SHOW-08** | Open showtimes by movie | All | Lấy suất chiếu có thể đặt. |
| **FR-SHOW-09** | Showtimes by date range | Staff/Admin | Tra cứu theo khoảng thời gian. |

### 6.5 Booking Management

| ID | Function | Actor | Expected behavior |
| :--- | :--- | :--- | :--- |
| **FR-BOOK-01** | Create booking | Customer | Tạo booking từ showtime và danh sách ghế. |
| **FR-BOOK-02** | Get booking detail | Customer/Staff/Admin | Xem chi tiết theo quyền. |
| **FR-BOOK-03** | List bookings | Staff/Admin | Tra cứu booking. |
| **FR-BOOK-04** | Bookings by user | Customer | Xem lịch sử booking của bản thân. |
| **FR-BOOK-05** | Confirm booking | System/Staff | Xác nhận booking theo workflow. |
| **FR-BOOK-06** | Cancel booking | Customer/Staff/Admin | Hủy booking nếu thỏa điều kiện. |
| **FR-BOOK-07** | Occupied seats | Customer/Staff | Lấy các ghế đã được giữ/đặt của suất chiếu. |

### 6.6 Payment Management

| ID | Function | Actor | Expected behavior |
| :--- | :--- | :--- | :--- |
| **FR-PAY-01** | Create payment | Customer/System | Tạo payment cho booking. |
| **FR-PAY-02** | Process payment | Customer/System | Khởi tạo/xử lý giao dịch PayOS. |
| **FR-PAY-03** | Get payment detail | Customer/Staff/Admin | Tra cứu giao dịch. |
| **FR-PAY-04** | Payments by user | Customer/Admin | Xem lịch sử thanh toán theo user. |
| **FR-PAY-05** | Payment by booking | Customer/Staff/Admin | Tra cứu payment của booking. |
| **FR-PAY-06** | Refund | Staff/Admin | Yêu cầu hoàn tiền theo chính sách. |
| **FR-PAY-07** | Webhook/callback | PayOS/System | Cập nhật trạng thái thanh toán sau khi xác minh callback. |

### 6.7 Notification

| ID | Function | Actor | Expected behavior |
| :--- | :--- | :--- | :--- |
| **FR-NOTI-01** | List notifications | Customer/Staff/Admin | Xem notification theo user/quyền. |
| **FR-NOTI-02** | Create notification | System/Staff/Admin | Tạo thông báo. |
| **FR-NOTI-03** | Send notification | System/Staff/Admin | Gửi email hoặc kênh hỗ trợ. |
| **FR-NOTI-04** | Get notification detail | Authorized user | Xem chi tiết. |
| **FR-NOTI-05** | Delete notification | Authorized | Xóa/ẩn notification theo chính sách. |
| **FR-NOTI-06** | Consume domain events | System | Nhận event từ RabbitMQ và gửi thông báo. |

---

## 7. API Scope

Các API cốt lõi dự kiến được tổ chức theo service như sau:

| Service | Endpoint group | Main operations |
| :--- | :--- | :--- |
| **Auth** | `/api/auth` | `register`, `login`, `current user/profile`, `role management` (nếu được triển khai) |
| **Movie** | `/api/movies` | `GET`/`POST`/`GET{id}`/`PATCH`/`DELETE`/`search`/`active` |
| **Showtime** | `/api/showtimes` | `CRUD`, `open`, `by movie`, `by date range` |
| **Room** | `/api/rooms` | `CRUD`, `search` |
| **Seat** | `/api/seats` | `generate`, `detail`, `delete`, `by room` |
| **Booking** | `/api/bookings` | `create`, `list`, `detail`, `confirm`, `cancel`, `by user`, `occupied seats` |
| **Payment** | `/api/payments` | `create`, `process`, `detail`, `refund`, `by user`, `by booking`, `webhook` |
| **Notification** | `/api/notifications` | `list`, `create`, `send`, `detail`, `delete`, `by user` |

---

## 8. Core Business Workflows

### 8.1 Customer Booking Flow
1. **Customer** đăng nhập $ightarrow$ **Auth Service** cấp JWT.
2. **Flutter** gửi request qua **API Gateway** kèm header `Authorization: Bearer <JWT>`.
3. **Customer** lấy danh sách phim $ightarrow$ chọn phim $ightarrow$ chọn suất chiếu.
4. **Booking Service** / **Showtime Service** kiểm tra thông tin suất chiếu và ghế đã được sử dụng.
5. **Customer** chọn ghế và gửi yêu cầu tạo booking.
6. **Booking Service** kiểm tra tính hợp lệ và tạo booking ở trạng thái phù hợp.
7. **Booking Service** gọi **Payment Service** để tạo payment.
8. **Payment Service** tạo giao dịch PayOS và trả thông tin thanh toán.
9. **Customer** hoàn tất thanh toán.
10. PayOS callback/webhook được **Payment Service** xác minh và cập nhật payment.
11. **Booking** được chuyển sang trạng thái đã thanh toán/xác nhận theo workflow.
12. **Payment/Booking** phát event qua **RabbitMQ**.
13. **Notification Service** consume event và gửi email/thông báo cho Customer.

### 8.2 Cancellation & Refund Flow
1. **Customer** hoặc **Staff** gửi yêu cầu cancel booking.
2. **Booking Service** kiểm tra quyền, trạng thái booking và chính sách hủy.
3. Nếu đã thanh toán và đủ điều kiện refund, **Booking Service** / **Payment Service** thực hiện quy trình refund.
4. **Payment Service** cập nhật trạng thái refund.
5. **Payment Service** phát `PaymentRefundedEvent` sau khi transaction commit thành công.
6. **Notification Service** nhận event và gửi thông báo kết quả.

### 8.3 Authorization Flow
1. **Flutter** lưu access token sau login.
2. Request đi qua **API Gateway**.
3. Gateway kiểm tra JWT signature, expiration và claims.
4. Gateway kiểm tra role/policy của route.
5. Nếu hợp lệ, request được forward tới service.
6. Service tiếp tục kiểm tra authorization cho các nghiệp vụ nhạy cảm nếu cần defense-in-depth.
7. `401 Unauthorized` = chưa xác thực/Token không hợp lệ; `403 Forbidden` = đã xác thực nhưng không đủ quyền.

---

## 9. Role & Permission Matrix

| Feature | Customer | Staff | Admin |
| :--- | :---: | :---: | :---: |
| View movies | ✓ | ✓ | ✓ |
| Search movies | ✓ | ✓ | ✓ |
| Create/update/delete movies | — | Theo policy | ✓ |
| View showtimes | ✓ | ✓ | ✓ |
| Create/update/delete showtimes | — | ✓ | ✓ |
| View rooms/seats | ✓ / theo API | ✓ | ✓ |
| Manage rooms/seats | — | ✓ / theo policy | ✓ |
| Create booking | ✓ | Theo nghiệp vụ | ✓ / support |
| View own bookings | ✓ | ✓ | ✓ |
| View all bookings | — | ✓ | ✓ |
| Cancel booking | ✓ / policy | ✓ | ✓ |
| Create/process payment | ✓ / System | ✓ / System | ✓ / System |
| Refund | — | ✓ / policy | ✓ |
| View notifications | ✓ own | ✓ own | ✓ |
| Manage/send notifications | — | Theo policy | ✓ |
| Manage users/roles | — | — | ✓ |

---

## 10. Data Model Scope

| Service | Main entities | Important relationships |
| :--- | :--- | :--- |
| **Auth** | User, Role | User $\leftrightarrow$ Role |
| **Movie** | Movie | Movie is referenced by `showtime_id`/`movie_id` logically across services |
| **Showtime** | Room, Seat, Showtime | Room $ightarrow$ Seats; Showtime $ightarrow$ Movie reference + Room |
| **Booking** | Booking, BookingSeat | Booking $ightarrow$ User, Showtime, Seats (logical references) |
| **Payment** | Payment, Refund/transaction data | Payment $ightarrow$ Booking, User |
| **Notification** | Notification | Notification $ightarrow$ User / event reference |

> **Nguyên tắc microservice:** không dùng foreign key xuyên database/service. Các ID tham chiếu giữa service được quản lý ở tầng ứng dụng/event và được validate qua API hoặc event.

---

## 11. Non-Functional Requirements

| Category | Requirement |
| :--- | :--- |
| **Performance** | API thông thường phải phản hồi nhanh; pagination bắt buộc cho collection lớn. |
| **Availability** | Service quan trọng phải có health check và xử lý downstream failure. |
| **Scalability** | Các service có thể scale độc lập. |
| **Security** | HTTPS, JWT, password hashing, role-based authorization, validate input. |
| **Resilience** | Retry có giới hạn và Circuit Breaker cho dependency có nguy cơ lỗi. |
| **Consistency** | Transaction nội bộ service; event-driven consistency giữa service. |
| **Observability** | Structured logs, health endpoints, metrics, tracing khi triển khai. |
| **Maintainability** | Controller $ightarrow$ Service $ightarrow$ Repository, DTO, validation, exception handling. |
| **API Documentation** | OpenAPI/Swagger cho các API. |
| **Deployment** | Docker Compose cho môi trường local/integration. |

---

## 12. Error Handling

| HTTP Code | Meaning | Example |
| :--- | :--- | :--- |
| **400** | Bad Request | Payload sai validation, tham số không hợp lệ |
| **401** | Unauthorized | Thiếu hoặc JWT không hợp lệ |
| **403** | Forbidden | Không có role/policy phù hợp |
| **404** | Not Found | Movie/booking/showtime không tồn tại |
| **409** | Conflict | Ghế đã được đặt hoặc trạng thái không cho phép thao tác |
| **422** | Unprocessable Entity | Business validation thất bại nếu API áp dụng mã này |
| **500** | Internal Server Error | Lỗi ngoài dự kiến |
| **503** | Service Unavailable | Downstream unavailable/circuit open |

---

## 13. Messaging & Resilience

### 13.1 RabbitMQ
- Dùng cho event không yêu cầu synchronous response.
- Các event tiêu biểu: `BookingCreated`, `PaymentCreated`, `PaymentSucceeded`, `PaymentFailed`, `PaymentRefunded`, `BookingCancelled`.
- Notification Service consume event để gửi email/thông báo.
- Publisher nên phát event sau khi transaction commit để tránh event mô tả dữ liệu chưa commit.
- Consumer cần xử lý idempotency để tránh gửi/ghi nhận trùng khi message được redeliver.

### 13.2 Circuit Breaker
- Áp dụng cho các lời gọi từ Booking $ightarrow$ Payment và các dependency bên ngoài có rủi ro.
- **Closed:** Request đi bình thường.
- **Open:** Khi lỗi vượt ngưỡng, request được chặn tạm thời để bảo vệ hệ thống.
- **Half-Open:** Thử một số request để xác định dependency đã hồi phục.
- **Fallback:** Phải trả trạng thái nghiệp vụ rõ ràng; không được âm thầm coi payment thất bại là thành công.

---

## 14. Payment – PayOS

1. Payment Service là nơi tích hợp PayOS, không để Flutter gọi trực tiếp logic nội bộ của Payment Service.
2. Booking Service tạo payment request thông qua Payment Service.
3. Payment Service tạo payment link/order và trả thông tin cần thiết cho Flutter.
4. Flutter mở/hiển thị luồng thanh toán.
5. PayOS callback/webhook là nguồn cập nhật trạng thái giao dịch sau khi xác minh.
6. Payment state và Booking state phải được thiết kế độc lập nhưng có mapping rõ ràng.
7. Refund phải kiểm tra booking/payment state và quyền Staff/Admin.

---

## 15. Frontend Requirements – Flutter

| Module | Main screens/functions |
| :--- | :--- |
| **Auth** | Login, Register, token storage, logout |
| **Home** | Movie list, active movies, search |
| **Movie** | Movie detail, showtimes |
| **Seat** | Room layout, available/occupied seat state, selection |
| **Booking** | Checkout summary, booking detail, history, cancellation |
| **Payment** | Payment information, PayOS flow/result |
| **Notification** | Notification list/detail |
| **Admin/Staff** | Movie, room, seat, showtime, booking, payment and notification management according to role |

---

## 16. Backend Project Structure

Mỗi service nên giữ cấu trúc nhất quán:
- **Api/Controllers** – HTTP endpoints.
- **Application/Services** – business logic.
- **Domain/Entities** – domain models.
- **Infrastructure/Repositories** – database access.
- **Contracts/DTOs** – request/response contracts.
- **Messaging** – RabbitMQ publishers/consumers.
- **Clients** – typed HTTP clients cho service-to-service calls.
- **Security** – JWT/policies khi service cần defense-in-depth.
- **Configuration** – options, resilience, Swagger, database.

---

## 17. API Gateway Requirements

1. Là entry point từ Flutter tới backend.
2. Route request tới đúng microservice.
3. Validate JWT và enforce route-level authorization.
4. Forward correlation/request ID để trace request.
5. Không chứa business logic của Movie/Booking/Payment.
6. Có thể áp dụng rate limiting, timeout và các policy chung khi cần.

---

## 18. Testing Scope

| Level | Scope |
| :--- | :--- |
| **Unit Test** | Service/domain logic, validation, state transition, mapping. |
| **Integration Test** | EF Core/PostgreSQL, RabbitMQ, API behavior. |
| **Contract/API Test** | Request/response, status code, authorization. |
| **End-to-End** | Login $ightarrow$ browse $ightarrow$ select seat $ightarrow$ booking $ightarrow$ payment $ightarrow$ notification. |
| **Failure Test** | Payment unavailable, RabbitMQ unavailable, timeout, circuit open. |
| **Security Test** | Invalid JWT, expired JWT, role escalation, unauthorized endpoints. |

---

## 19. Acceptance Criteria

1. Customer có thể đăng nhập và nhận JWT.
2. Customer chỉ truy cập được các API phù hợp với role.
3. Admin/Staff có thể quản lý dữ liệu đúng quyền.
4. Customer có thể xem phim, suất chiếu và ghế còn trống.
5. Customer không thể đặt cùng một ghế đã được xác nhận cho cùng suất chiếu.
6. Booking và payment có trạng thái rõ ràng và nhất quán.
7. PayOS callback được xác minh trước khi cập nhật payment.
8. Khi Payment Service lỗi, Circuit Breaker hoạt động và không làm hệ thống treo dây chuyền.
9. RabbitMQ event được publish/consume đúng và consumer có thể xử lý message trùng.
10. Notification được tạo/gửi sau các event nghiệp vụ tương ứng.
11. Các API collection có pagination khi dữ liệu có thể tăng lớn.
12. Toàn bộ service có Swagger và health check phục vụ kiểm thử.
13. Hệ thống có thể chạy bằng Docker Compose trong môi trường tích hợp.

---

## 20. Recommended Development Order

1. Thiết kế database và migration cho từng service.
2. Tạo solution/project ASP.NET Core cho các service.
3. Xây Auth Service + JWT + roles.
4. Xây API Gateway + authentication/authorization.
5. Xây Movie Service.
6. Xây Showtime Service gồm Room/Seat/Showtime.
7. Xây Booking Service và occupied-seat validation.
8. Xây Payment Service + PayOS.
9. Tích hợp RabbitMQ và Notification Service.
10. Bổ sung Circuit Breaker/Retry/Timeout.
11. Xây Flutter UI và kết nối Gateway.
12. Bổ sung Swagger, validation, exception handling, logging.
13. Docker Compose toàn hệ thống.
14. Prometheus/Grafana/OpenTelemetry và kiểm thử E2E.

---

## 21. Important Design Notes

- Không để Frontend gọi trực tiếp từng service; ưu tiên đi qua API Gateway.
- Không chia sẻ DbContext/entity giữa các service.
- Không dùng chung database schema cho tất cả service nếu mục tiêu là microservice đúng nghĩa.
- JWT secret phải được quản lý tập trung qua configuration/secret management, không hard-code trong source production.
- Các endpoint PATCH/DELETE phải kiểm tra authorization và trạng thái nghiệp vụ.
- Booking/payment cần thiết kế state machine rõ ràng để tránh các trạng thái không hợp lệ.
- Seat availability là vùng dễ xảy ra race condition; cần transaction/concurrency/unique constraint phù hợp.
- RabbitMQ delivery có thể lặp; consumer phải idempotent.
- Không trả stack trace hoặc thông tin nhạy cảm ra response production.
- Pagination nên dùng PageNumber/PageSize hoặc cursor tùy yêu cầu; giới hạn PageSize để tránh query quá lớn.

---

## 22. Conclusion

SRS này xác định phạm vi và bộ yêu cầu cốt lõi của **Cinema Management System** theo hướng microservice. Trọng tâm nghiệp vụ là quản lý phim – phòng/ghế – suất chiếu – booking – payment – notification, được bảo vệ bởi JWT/RBAC và kết nối qua API Gateway. RabbitMQ và cơ chế resilience được sử dụng để giảm coupling và tăng khả năng chịu lỗi. Flutter là client chính, PostgreSQL là nền tảng dữ liệu cho các service.
