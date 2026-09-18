# DSP Project

Đồ án xây dựng hệ thống điều khiển xe 2D bằng giọng nói. Người dùng nói một trong năm lệnh tiếng Việt, hệ thống xử lý tín hiệu âm thanh và điều khiển xe trên giao diện mô phỏng:

- `tien`: xe đi tới.
- `lui`: xe đi lùi.
- `trai`: xe quay trái.
- `phai`: xe quay phải.
- `dung`: xe dừng.

## 1. Cấu trúc thư mục

```text
DSP-project/
|-- README.md
`-- code/
    |-- speechrecognition.m   % Giao diện xe và lõi nhận dạng
    |-- recordVoice.m         % Module thu âm microphone
    |-- tien.wav              % Template lệnh TIẾN
    |-- lui.wav               % Template lệnh LÙI
    |-- trai.wav              % Template lệnh TRÁI
    |-- phai.wav              % Template lệnh PHẢI
    `-- dung.wav              % Template lệnh DỪNG
```

Các file WAV như `test.wav`, `test2.wav` và `test3.wav` là dữ liệu kiểm thử tham khảo. Chương trình chính hiện nhận tín hiệu trực tiếp từ microphone; các file `tien.wav` đến `dung.wav` chỉ được dùng làm mẫu so sánh.

## 2. Yêu cầu môi trường

- MATLAB có hỗ trợ `audiorecorder`, `audioread`, `resample` và `spectrogram`.
- Signal Processing Toolbox cho các hàm xử lý tín hiệu.
- Image Processing Toolbox cho hàm `normxcorr2`.
- Microphone hoạt động và được Windows cấp quyền cho MATLAB.
- MATLAB có quyền đọc các file WAV trong thư mục `code`.

## 3. Chạy chương trình

Mở MATLAB chính thức, sau đó nhập trong **Command Window**:

```matlab
cd('C:\Users\GIGABYTE\OneDrive\Documents\GitHub\DSP-project\code')
clear functions
rehash
which speechrecognition
speechrecognition
```

Kết quả của `which speechrecognition` phải trỏ tới:

```text
...\DSP-project\code\speechrecognition.m
```

Khi giao diện xuất hiện:

1. Bấm nút **GHI ÂM GIỌNG NÓI**.
2. Nói một lệnh trong khoảng 2 giây.
3. Chờ hệ thống xử lý và cập nhật trạng thái xe.
4. Bấm lại nút để thực hiện lệnh tiếp theo.

Module `recordVoice.m` đảm nhiệm việc tạo `audiorecorder`, thu âm 2 giây và trả về tín hiệu cùng tần số lấy mẫu 8 kHz.

## 4. Luồng xử lý DSP

```text
Microphone
    |
recordVoice.m
    |
Đưa về mono và resample về 8 kHz
    |
Bộ lọc thông dải 300-3400 Hz
    |
VAD bằng năng lượng và autocorrelation
    |
Tạo spectrogram: cửa sổ 30 ms, overlap 70%, FFT 512 điểm
    |
Chuyển phổ sang dB và chuẩn hóa zero-mean/unit-variance
    |
2D normalized cross-correlation với 5 template
    |
Chọn điểm tương quan lớn nhất
    |
Điều khiển xe 2D
```

Ngưỡng nhận dạng hiện tại là `0.45` trong hàm `speechDSPCore2D`. Nếu điểm cao nhất thấp hơn ngưỡng, hệ thống trả về `UNKNOWN` và không điều khiển xe.

## 5. Thêm hoặc thay template

Để thay giọng mẫu cho một lệnh:

1. Thu một file WAV mono, rõ tiếng và ít tạp âm.
2. Đặt file vào thư mục `code`.
3. Giữ đúng tên tương ứng: `tien.wav`, `lui.wav`, `trai.wav`, `phai.wav` hoặc `dung.wav`.
4. Chạy lại `speechrecognition`.

Khi thêm một lệnh mới, cần cập nhật đồng thời các mảng trong `speechDSPCore2D`:

```matlab
templateNames = {...};
templateFiles = fullfile(baseDir, templateNames);
cmdNames = {...};
```

Sau đó thêm nhánh xử lý lệnh mới trong hàm `executeCommand`.

## 6. Kiểm thử

Nên kiểm thử từng lệnh nhiều lần trong cùng điều kiện:

- Cùng microphone và khoảng cách tới microphone.
- Cùng mức âm lượng và tốc độ nói.
- Không nói đồng thời nhiều lệnh.
- Kiểm thử cả trường hợp im lặng và tiếng ồn để đánh giá nhận dạng nhầm.

Kết quả mong đợi là trạng thái giao diện hiển thị đúng lệnh và xe cập nhật đúng vị trí hoặc hướng. Có thể điều chỉnh `minThresh` nếu hệ thống nhận nhầm quá nhiều hoặc bỏ sót lệnh, nhưng nên kiểm tra dữ liệu và tiền xử lý trước khi thay đổi ngưỡng.

## 7. Xử lý lỗi thường gặp

### MATLAB không tìm thấy `speechrecognition`

Đặt Current Folder về thư mục `code` hoặc chạy:

```matlab
addpath('C:\Users\GIGABYTE\OneDrive\Documents\GitHub\DSP-project\code')
rehash
which speechrecognition
```

### Không tìm thấy file mẫu

Kiểm tra năm file sau có nằm cùng thư mục với `speechrecognition.m` không:

```text
tien.wav
lui.wav
trai.wav
phai.wav
dung.wav
```

### Không ghi âm được

- Kiểm tra quyền microphone của MATLAB trong Windows.
- Kiểm tra microphone trong Sound Settings.
- Đóng ứng dụng khác đang sử dụng microphone.
- Thử gọi riêng module:

```matlab
[audio, Fs] = recordVoice(2, 8000);
sound(audio, Fs)
```

### Nhận dạng sai

- Thu lại template trong cùng môi trường với lúc demo.
- Nói rõ một lệnh trong toàn bộ khoảng thu.
- Giảm tiếng ồn nền và tiếng vang.
- Kiểm tra ngưỡng `minThresh` và các tham số VAD.

## 8. Quy trình Git đề xuất

Sau khi sửa code hoặc thay template:

```powershell
git status
git add README.md code
git commit -m "Update voice control project"
git push
```

Không commit file tạm, file cache MATLAB hoặc dữ liệu chứa thông tin cá nhân.
