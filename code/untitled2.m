% =========================================================================
% KIỂM CHỨNG SO KHỚP 20% ĐOẠN ĐẦU (HEAD-SEGMENT MATCHING)
% =========================================================================
clear; clc; close all;

baseDir = fileparts(mfilename('fullpath'));
if isempty(baseDir), baseDir = pwd; end

fileTrai = fullfile(baseDir, 'trai.wav');
filePhai = fullfile(baseDir, 'phai.wav');

if ~exist(fileTrai, 'file') || ~exist(filePhai, 'file')
    error('Không tìm thấy file trai.wav hoặc phai.wav!');
end

targetFs = 8000;
targetCols = 64; % Chuẩn hóa về 64 khung thời gian

% 1. Đọc và tiền xử lý
[y_t, Fs_t] = audioread(fileTrai);
[y_p, Fs_p] = audioread(filePhai);
if size(y_t, 2) > 1, y_t = mean(y_t, 2); end
if size(y_p, 2) > 1, y_p = mean(y_p, 2); end
if Fs_t ~= targetFs, y_t = resample(y_t, targetFs, Fs_t); end
if Fs_p ~= targetFs, y_p = resample(y_p, targetFs, Fs_p); end

y_t = removeSilenceLocal(bandpassFilterLocal(y_t, targetFs), targetFs);
y_p = removeSilenceLocal(bandpassFilterLocal(y_p, targetFs), targetFs);

% 2. Trích xuất Spectrogram và chuẩn hóa kích thước về 64 cột
S_t = computeSpec64(y_t, targetFs, targetCols);
S_p = computeSpec64(y_p, targetFs, targetCols);

% 3. So sánh tương quan TOÀN BỘ TỪ (100% độ dài)
corr_full = corr2(S_t, S_p);

% 4. Cắt lấy đúng 20% ĐOẠN ĐẦU (13 khung đầu tiên)
headFrames = round(targetCols * 0.20); % 13 khung
S_t_head = S_t(:, 1:headFrames);
S_p_head = S_p(:, 1:headFrames);

% Tính tương quan chỉ trên 20% đoạn đầu
corr_head = corr2(S_t_head, S_p_head);

% In kết quả so sánh
fprintf('================ KẾT QUẢ ĐỐI CHIẾU ================\n');
fprintf('Tương quan toàn bộ từ (100%% độ dài): %.3f\n', corr_full);
fprintf('Tương quan chỉ xét 20%% đoạn đầu:      %.3f\n', corr_head);
fprintf('Độ lệch phân tách tăng thêm:          %.3f\n', corr_full - corr_head);
fprintf('===================================================\n');

% 5. Vẽ đồ thị minh họa vùng cắt 20%
figure('Name', 'Trích xuất 20% phụ âm đầu', 'Color', 'w', 'Position', [100, 150, 1000, 450]);

subplot(1, 2, 1);
imagesc(1:targetCols, 1:size(S_t,1), S_t); axis xy; colormap('jet');
hold on;
xline(headFrames, 'w--', 'Hết 20% đầu', 'LineWidth', 2);
rectangle('Position', [1, 1, headFrames, size(S_t,1)], 'EdgeColor', 'r', 'LineWidth', 2);
title('Spectrogram TRAI (Vùng đỏ: 20% phụ âm)', 'FontWeight', 'bold');
xlabel('Khung thời gian'); ylabel('Bins tần số');

subplot(1, 2, 2);
imagesc(1:targetCols, 1:size(S_p,1), S_p); axis xy; colormap('jet');
hold on;
xline(headFrames, 'w--', 'Hết 20% đầu', 'LineWidth', 2);
rectangle('Position', [1, 1, headFrames, size(S_p,1)], 'EdgeColor', 'r', 'LineWidth', 2);
title(sprintf('Spectrogram PHAI (Tương quan vùng đầu = %.3f)', corr_head), 'FontWeight', 'bold');
xlabel('Khung thời gian'); ylabel('Bins tần số');

% --- CÁC HÀM CỤC BỘ ---
function S_norm = computeSpec64(x, Fs, targetCols)
    winLen = round(Fs * 0.030); overlap = round(winLen * 0.75); nfft = 512;
    [S, ~, ~] = spectrogram(x, winLen, overlap, nfft, Fs);
    S_dB = 20 * log10(abs(S) + 1e-6);
    if size(S_dB, 2) ~= targetCols
        S_dB = imresize(S_dB, [size(S_dB, 1), targetCols], 'bilinear');
    end
    S_norm = (S_dB - mean(S_dB(:))) / (std(S_dB(:)) + 1e-6);
end

function x_clean = removeSilenceLocal(x, Fs)
    x = x(:); totalSamples = length(x);
    frameLen = round(Fs * 0.02); hopLen = round(Fs * 0.005);
    numFrames = floor((totalSamples - frameLen) / hopLen) + 1;
    if numFrames < 10, x_clean = x; return; end
    energy = zeros(1, numFrames);
    for i = 1:numFrames
        energy(i) = sum(x((i-1)*hopLen + 1 : (i-1)*hopLen + frameLen).^2);
    end
    maxE = max(energy);
    active = find(energy > 0.008 * maxE);
    if ~isempty(active)
        pad = round(Fs * 0.02);
        s1 = max(1, (active(1)-1)*hopLen + 1 - pad);
        s2 = min(totalSamples, (active(end)-1)*hopLen + frameLen + pad);
        x_clean = x(s1:s2);
    else
        x_clean = x;
    end
end

function x_filt = bandpassFilterLocal(x, Fs)
    Wn = [150 3400] / (Fs / 2);
    [b, a] = butter(2, Wn, 'bandpass');
    x_filt = filtfilt(b, a, x);
end