# Chia sẻ `.env` an toàn bằng SOPS + age

> **TL;DR**
> - `secrets.enc.env` trong repo là file `.env` **đã mã hoá**. Commit được, vì ai không có key mở ra chỉ thấy chuỗi `ENC[...]`.
> - Mỗi người có **một private key riêng** nằm trên máy mình, không bao giờ gửi đi. Muốn được cấp quyền thì chỉ cần gửi **public key** (`age1...`).
> - Sau khi pull: chạy `.\scripts\secrets.ps1 decrypt` là có `.env` đầy đủ, rồi `docker compose up -d --build`.

---

## 1. Cài công cụ (mỗi máy một lần)

**age** cài bằng winget:
```powershell
winget install --id FiloSottile.age -e
```

**SOPS** không còn trên winget, nên tải bản chính thức từ [github.com/getsops/sops/releases](https://github.com/getsops/sops/releases). Đoạn dưới tải `sops.exe` (khoảng 51 MB), **kiểm tra checksum** với file `checksums.txt` của bản phát hành, cài vào `%LOCALAPPDATA%\Programs\sops` rồi thêm thư mục đó vào PATH của user. Có bản mới hơn thì đổi `$ver`.
```powershell
$ver = "3.13.3"
$dir = "$env:LOCALAPPDATA\Programs\sops"
$base = "https://github.com/getsops/sops/releases/download/v$ver"
$ProgressPreference = "SilentlyContinue"
New-Item -ItemType Directory -Force $dir | Out-Null
Invoke-WebRequest "$base/sops-v$ver.amd64.exe" -OutFile "$dir\sops.exe" -UseBasicParsing
Invoke-WebRequest "$base/sops-v$ver.checksums.txt" -OutFile "$dir\checksums.txt" -UseBasicParsing
$expected = ((Select-String -Path "$dir\checksums.txt" -Pattern "sops-v$ver\.amd64\.exe$").Line -split '\s+')[0]
$actual = (Get-FileHash "$dir\sops.exe" -Algorithm SHA256).Hash.ToLower()
if ($actual -ne $expected) { Remove-Item "$dir\sops.exe"; throw "Checksum KHONG khop - da xoa file tai ve" }
$userPath = [Environment]::GetEnvironmentVariable("Path", "User")
if (($userPath -split ';') -notcontains $dir) { [Environment]::SetEnvironmentVariable("Path", "$userPath;$dir", "User") }
"Da cai sops $ver (checksum OK). Mo terminal moi de dung lenh sops."
```

Mở **terminal mới** rồi kiểm tra: `sops --version` và `age --version` đều in ra số phiên bản là được.

## 2. Tạo key của bạn (mỗi máy một lần)

```powershell
New-Item -ItemType Directory -Force "$env:APPDATA\sops\age" | Out-Null
age-keygen -o "$env:APPDATA\sops\age\keys.txt"
```

- Lệnh in ra dòng `Public key: age1...`. Gửi dòng này cho một người đã có quyền. Public key không phải bí mật, gửi vào group cũng được.
- `keys.txt` là **private key**: không gửi cho ai, không commit, nên sao lưu một bản. Lỡ mất thì tạo key mới và xin cấp quyền lại.
- SOPS tự tìm key ở đúng đường dẫn trên, không cần cấu hình thêm.

## 3. Lấy `.env` sau khi được cấp quyền

```powershell
git pull
.\scripts\secrets.ps1 decrypt
docker compose up -d --build
```

- Nếu `.env` đang có khác bản mã hoá, script sao lưu bản cũ thành `.env.bak` trước khi ghi đè.
- Báo `Khong giai ma duoc`: máy chưa được cấp quyền, hoặc `keys.txt` không nằm đúng chỗ ở mục 2.
- **Chưa được cấp quyền vẫn dev được**: tạo `.env` từ `.env.example` như trong [DOCKER.md](DOCKER.md). Không có SMTP thì mã OTP được in ra log.

## 4. Cấp quyền cho thành viên mới (người đã có quyền làm)

```powershell
.\scripts\secrets.ps1 add-key age1...   # public key của thành viên mới
git add .sops.yaml secrets.enc.env
git commit -m "chore: grant secrets access to <ten>"
```

Sau đó push lên và tạo PR như bình thường. Thành viên mới pull về rồi chạy `decrypt`.

## 5. Sửa secret (vd: đổi App Password, thêm key PayOS)

1. Sửa `.env` trên máy bạn.
2. Chạy `.\scripts\secrets.ps1 encrypt` để cập nhật `secrets.enc.env`.
3. Commit `secrets.enc.env` (**không** commit `.env`) rồi tạo PR. Mọi người pull về và chạy `decrypt`.

Muốn biết `.env` của mình có khớp bản trong repo không: `.\scripts\secrets.ps1 check`. Lệnh chỉ in tên các biến khác nhau, không in giá trị.

## 6. Có người rời nhóm hoặc lộ key

1. Xoá public key của người đó khỏi `.sops.yaml`, rồi chạy `sops updatekeys --yes secrets.enc.env`.
2. **Bắt buộc đổi secret thật**: tạo App Password mới, đổi JWT key… rồi chạy `encrypt` và commit. Lịch sử git vẫn giữ bản mã hoá cũ, người đó vẫn giải mã được bản cũ bằng key của họ.

## 7. Lưu ý

- File mã hoá chứa **toàn bộ `.env` cho Docker**: `POSTGRES_PASSWORD`, `JWT_SECRET_KEY`, PayOS, SMTP. Chỉ dùng cho môi trường dev/local.
- Chạy bằng Visual Studio thì service đọc User Secrets chứ không đọc `.env`, nên vẫn phải đặt secrets theo [SETUP_SECRETS.md](SETUP_SECRETS.md). Có thể lấy giá trị từ `.env` sau khi giải mã.
- Mỗi lần `encrypt` thì toàn bộ nội dung file mã hoá đổi theo, đó là bình thường. Nếu `.env` không thay đổi gì, script giữ nguyên file cũ.

## 8. Lỗi thường gặp

| Lỗi | Nguyên nhân | Cách sửa |
|---|---|---|
| `Chua cai sops` / `sops is not recognized` | Chưa cài, hoặc terminal mở từ trước khi cài | Cài theo mục 1 rồi mở terminal mới |
| `winget install --id Mozilla.SOPS` báo `No package found` | Gói SOPS đã bị gỡ khỏi winget | Dùng đoạn tải từ GitHub ở mục 1 |
| `running scripts is disabled on this system` | Windows đang chặn chạy file `.ps1` | Chạy một lần: `Set-ExecutionPolicy -Scope CurrentUser RemoteSigned`, hoặc chạy kiểu `powershell -ExecutionPolicy Bypass -File .\scripts\secrets.ps1 decrypt` |
| `Khong giai ma duoc` | Public key của bạn chưa có trong `.sops.yaml`, hoặc `keys.txt` sai chỗ | Gửi public key xin cấp quyền; kiểm tra file `%APPDATA%\sops\age\keys.txt` |
| `updatekeys that bai` khi chạy `add-key` | Máy bạn chưa được cấp quyền | Nhờ người đã có quyền chạy `add-key` |
| `no matching creation rules found` | Chạy lệnh `sops` ở ngoài thư mục `Cinema_BE` | Chạy script từ thư mục `Cinema_BE` |
