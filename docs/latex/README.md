# SRS LaTeX / PDF

Bốn bản chuyển định dạng từ Markdown hiện có, không biên tập lại nội dung nghiệp vụ.

| Bản | Nguồn LaTeX độc lập | PDF |
|---|---|---|
| Web EN | [web-en/main.tex](web-en/main.tex) | [Cinema_Web_NET_SRS_EN.pdf](web-en/Cinema_Web_NET_SRS_EN.pdf) |
| Web VI | [web-vi/main.tex](web-vi/main.tex) | [Cinema_Web_NET_SRS_VI.pdf](web-vi/Cinema_Web_NET_SRS_VI.pdf) |
| Mobile EN | [mobile-en/main.tex](mobile-en/main.tex) | [Cinema_Mobile_SRS_EN.pdf](mobile-en/Cinema_Mobile_SRS_EN.pdf) |
| Mobile VI | [mobile-vi/main.tex](mobile-vi/main.tex) | [Cinema_Mobile_SRS_VI.pdf](mobile-vi/Cinema_Mobile_SRS_VI.pdf) |

## Biên dịch

Cần XeLaTeX từ TeX Live hoặc MiKTeX. Chạy trong thư mục chứa `main.tex` tương ứng; lặp mỗi lệnh **ba lần** để ổn định mục lục, danh mục bảng và số trang:

```powershell
# Trong web-en/
xelatex -no-shell-escape -interaction=nonstopmode -halt-on-error -file-line-error -jobname=Cinema_Web_NET_SRS_EN main.tex

# Trong web-vi/
xelatex -no-shell-escape -interaction=nonstopmode -halt-on-error -file-line-error -jobname=Cinema_Web_NET_SRS_VI main.tex

# Trong mobile-en/
xelatex -no-shell-escape -interaction=nonstopmode -halt-on-error -file-line-error -jobname=Cinema_Mobile_SRS_EN main.tex

# Trong mobile-vi/
xelatex -no-shell-escape -interaction=nonstopmode -halt-on-error -file-line-error -jobname=Cinema_Mobile_SRS_VI main.tex
```

Hoặc chạy cả bốn bản, ba lượt mỗi bản, từ thư mục này:

```powershell
./build.ps1
# Có thể truyền đường dẫn đến XeLaTeX portable:
./build.ps1 -XeLaTeX 'C:/path/to/texlive/bin/windows/xelatex.exe'
```

Mỗi `main.tex` chỉ nạp các tệp trong `sections/` của chính thư mục đó. Không cần Python, Markdown gốc, mạng hoặc thư mục của bản SRS khác để biên dịch. Liên kết đến source code/Markdown vẫn cần repository tại vị trí tương ứng khi người đọc mở liên kết.

## Trình bày

- A4, lề 22 mm, bìa học thuật, mục lục, danh mục bảng; phần đầu dùng số La Mã và nội dung dùng số Ả Rập.
- Header/footer, đánh số mục và mục con; giữ nguyên 28 mục chính.
- `longtable`, `array`, `booktabs`, `tabularx` cho bảng; hàng tiêu đề lặp lại khi qua trang. Phần API và ma trận truy vết dùng A4 ngang qua `pdflscape`.
- Unicode qua `fontspec`; ưu tiên Times New Roman, Arial, Consolas nếu có; dự phòng TeX Gyre Termes, TeX Gyre Heros, Latin Modern Mono.
- Các mã/endpoint/path giữ nguyên ký tự với `\texttt{}` và điểm ngắt dòng không in ra ký tự mới. Ký tự đặc biệt được escape. Liên kết source giữ nguyên nhãn, điều chỉnh đường dẫn tương đối theo vị trí mới.
- Gói chính khác: `geometry`, `fancyhdr`, `titlesec`, `needspace`, `hyperref`, `bookmark`, `fancyvrb`, `amsmath`, `amssymb`, `fix-cm`, `xcolor`, `graphicx`.

Nguồn không có ảnh nhúng hoặc hệ thống trích dẫn học thuật. Sơ đồ kiến trúc ASCII được giữ nguyên trong môi trường verbatim. Vì vậy không tạo thư mục ảnh, danh mục hình rỗng hoặc bibliography không cần thiết.

## Đối chiếu và kiểm tra

- `conversion-manifest.json` trong mỗi thư mục lưu SHA-256 Markdown gốc, danh mục tiêu đề và dấu kiểm từng bảng.
- [validation-report.json](validation-report.json) ghi kết quả kiểm tra PDF, 28 mục, ID kỹ thuật, liên kết, log LaTeX và đối chiếu văn bản từng ô/đoạn nguồn.
- `convert_srs.py` là bộ chuyển định dạng tái lập; chỉ đọc Markdown và ghi LaTeX/manifest. `validate_srs.py` dùng `pypdf` để kiểm tra kết quả sau biên dịch.
- Không thay đổi hoặc nâng cấp các ghi chú về Flutter Web, ASP.NET Core 8, database submodule chưa đầy đủ, nghiệm thu hệ thống chưa chạy và PayOS production chưa kiểm chứng.

Bản PDF được kiểm tra dàn trang riêng với nội dung nghiệp vụ: việc biên dịch PDF thành công không chứng nhận hệ thống Cinema đã đạt nghiệm thu hoặc giao dịch production.
