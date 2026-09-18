function speechrecognition(filename)
% Speech Recognition Using Cross-Correlation (Envelope + ZCR)
% Tích hợp ZCR Contour để phân biệt "Four" và "Five"

if nargin < 1 || isempty(filename)
    error('Cách dùng: speechrecognition(''test.wav'')');
end

    baseDir = fileparts(mfilename('fullpath'));
    if ~isfile(filename)
        filename = fullfile(baseDir, filename);
    end

targetFs = 8000;          
minThreshold = 0.35; % Có thể cần hạ nhẹ ngưỡng do tính điểm tổng hợp

% 1. Đọc và tiền xử lý file test
[x, Fs] = audioread(filename);
x = x(:,1); 
if Fs ~= targetFs
    x = resample(x, targetFs, Fs);
    Fs = targetFs;
end

x = bandpassFilter(x, Fs);               
x = removeSilenceAutocorr(x, Fs);        

% [MỚI CHỈNH SỬA] Trích xuất 2 đặc trưng chạy dọc theo thời gian
x_env = normalizeSignal(abs(hilbert(x)));      % Đặc trưng 1: Biên độ (Độ to)
x_zcr = normalizeSignal(getZCRContour(x, Fs)); % Đặc trưng 2: ZCR (Màu sắc/Tần số)

templateNames = {'tien.wav','lui.wav','trai.wav','phai.wav','dung.wav'};
templateFiles = fullfile(baseDir, templateNames);
n = numel(templateFiles);
peaks = zeros(1, n);

for k = 1:n
    [y, Fs_y] = audioread(templateFiles{k});
    y = y(:,1);
    
    if Fs_y ~= targetFs
        y = resample(y, targetFs, Fs_y);
    end
    
    y = bandpassFilter(y, targetFs);
    y = removeSilenceAutocorr(y, targetFs);
    
    % [MỚI CHỈNH SỬA] Trích xuất 2 đặc trưng cho file mẫu
    y_env = normalizeSignal(abs(hilbert(y)));
    y_zcr = normalizeSignal(getZCRContour(y, targetFs));
    
    % 2. Tính Tương quan chéo riêng biệt cho từng đặc trưng
    [corr_env, ~] = xcorr(x_env, y_env, 'none');
    [corr_zcr, ~] = xcorr(x_zcr, y_zcr, 'none');
    
    peak_env = max(abs(corr_env));
    peak_zcr = max(abs(corr_zcr));
    
    % [TRỌNG TÂM] Tổng hợp điểm với trọng số
    % Ưu tiên 60% cho hình dáng âm lượng, 40% cho hình dáng tần số (ZCR)
    % Bạn có thể tinh chỉnh tỷ lệ này (ví dụ 0.7 - 0.3) nếu muốn
    weight_env = 0.3; 
    weight_zcr = 0.7;
    
    final_score = (weight_env * peak_env) + (weight_zcr * peak_zcr);
    peaks(k) = final_score;
end

% 4. Xuất kết quả nhận dạng
[maxPeak, idx] = max(peaks);
fprintf('\n=========================================\n');
if maxPeak >= minThreshold
    fprintf('KẾT QUẢ NHẬN DẠNG: "%s" (Điểm tổng hợp: %.3f)\n', ...
        templateFiles{idx}, maxPeak);
    
    [y_match, Fs_m] = audioread(templateFiles{idx});
    soundsc(y_match(:,1), Fs_m);
else
    fprintf('KẾT QUẢ: KHÔNG NHẬN DẠNG ĐƯỢC (Đỉnh %.3f < Ngưỡng %.2f)\n', ...
        maxPeak, minThreshold);
end
fprintf('=========================================\n');
end

% =========================================================================
% CÁC HÀM PHỤ TRỢ (Giữ nguyên các hàm cũ và thêm hàm mới)
% =========================================================================

% [MỚI THÊM] HÀM PHỤ: Trích xuất đường bao ZCR liên tục
function zcr_contour = getZCRContour(x, Fs)
    winLen = round(Fs * 0.02); % Cửa sổ trượt 20ms
    % Đếm sự thay đổi dấu (zero-crossings)
    crossings = abs(diff(x > 0)); 
    crossings = [crossings; 0]; % Bù lại 1 mẫu bị mất do hàm diff
    
    % Dùng trung bình trượt (moving average) để làm mượt thành một đường bao
    zcr_contour = movmean(crossings, winLen);
end

% --- HÀM PHỤ: VAD CẮT KHOẢNG LẶNG (Giữ nguyên hàm đã nâng cấp ZCR trước đó) ---
function x_clean = removeSilenceAutocorr(x, Fs)
    frameLen = max(1, round(Fs * 0.02)); 
    hopLen = round(frameLen / 2);        
    numFrames = floor((length(x) - frameLen) / hopLen) + 1;
    
    if numFrames < 1, x_clean = x; return; end
    
    energy = zeros(1, numFrames);
    autocorrPeak = zeros(1, numFrames);
    zcr = zeros(1, numFrames); 
    
    minLag = round(Fs / 500); maxLag = round(Fs / 80);  
    
    for i = 1:numFrames
        startSample = (i-1)*hopLen + 1;
        frame = x(startSample : startSample + frameLen - 1);
        energy(i) = sum(frame.^2);
        
        [r, lags] = xcorr(frame, 'coeff');
        zeroLagIdx = find(lags == 0);
        searchWin = r(zeroLagIdx + minLag : zeroLagIdx + maxLag);
        if ~isempty(searchWin), autocorrPeak(i) = max(searchWin); end
        
        zcr(i) = sum(abs(diff(frame > 0))) / (frameLen - 1);
    end
    
    maxE = max(energy);
    if maxE == 0, x_clean = x; return; end
    
    isVoiced = (autocorrPeak > 0.22) & (energy > 0.005 * maxE);
    isUnvoiced = (energy > 0.002 * maxE) & (zcr > 0.25);
    activeFrames = find(isVoiced | isUnvoiced);
    
    if ~isempty(activeFrames)
        padSamples = round(Fs * 0.15); 
        startSample = (activeFrames(1)-1)*hopLen + 1;
        endSample = (activeFrames(end)-1)*hopLen + frameLen;
        startIdx = max(1, startSample - padSamples);
        endIdx = min(length(x), endSample + padSamples);
        x_clean = x(startIdx:endIdx);
    else
        x_clean = x;
    end
end

function y = normalizeSignal(x)
    n = norm(x);
    if n > 0, y = x / n; else, y = x; end
end

function x_filtered = bandpassFilter(x, Fs)
    try
        x_filtered = bandpass(x, [300 3400], Fs);
    catch
        [b, a] = butter(2, [300 3400] / (Fs/2), 'bandpass');
        x_filtered = filtfilt(b, a, x);
    end
end