# Cinema

Hệ thống đặt vé xem phim: backend microservice ASP.NET Core 8 và app Flutter cho khách hàng.

| Thư mục | Nội dung | Tài liệu |
|---|---|---|
| `Cinema_BE/` | AuthService, MovieService, BookingService, ApiGateway; chạy cả hệ thống bằng Docker Compose | [Cinema_BE/docs](Cinema_BE/docs) |
| `Cinema_Mobile/` | App Flutter (web, Android, Windows), gọi API Gateway ở cổng 5000 | [Cinema_Mobile/README.md](Cinema_Mobile/README.md) |

## Cài đặt

Database nằm ở repo riêng [Project-Cinema-DB](https://github.com/PRM393-Cinema/Project-Cinema-DB). Clone repo đó **cạnh** thư mục `Cinema` (Docker lấy file SQL từ đây):

```powershell
git clone https://github.com/PRM393-Cinema/Cinema.git
git clone https://github.com/PRM393-Cinema/Project-Cinema-DB.git
```

```text
<thư mục bất kỳ>/
├── Cinema/
│   ├── Cinema_BE/
│   └── Cinema_Mobile/
└── Project-Cinema-DB/
```

1. Backend: làm theo [Cinema_BE/docs/DOCKER.md](Cinema_BE/docs/DOCKER.md) (tạo `.env` rồi `docker compose up -d --build`).
2. App: làm theo [Cinema_Mobile/README.md](Cinema_Mobile/README.md) (`flutter run -d chrome`).

Lệnh trong `Cinema_BE/docs` chạy trong thư mục `Cinema_BE`; lệnh Flutter chạy trong `Cinema_Mobile`.

## CI

[`.github/workflows/ci.yml`](.github/workflows/ci.yml) build và chạy test backend cho pull request vào `dev` / `main` có thay đổi trong `Cinema_BE/` (xem [TESTING.md](Cinema_BE/docs/TESTING.md)).
