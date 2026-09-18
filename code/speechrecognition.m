clc; clear; close all;

%% =========================================================
targetFs = 8000;
baseDir = fileparts(mfilename('fullpath'));
templateNames = {'tien.wav', 'lui.wav', 'trai.wav', 'phai.wav', 'dung.wav'};
templateFiles = fullfile(baseDir, templateNames);
commands = {'TIEN', 'LUI', 'TRAI', 'PHAI', 'DUNG'};
n = numel(templateFiles);

% Khởi tạo mảng lưu đặc trưng
env_templates = cell(1, n);
zcr_templates = cell(1, n);

fprintf('Đang nạp file mẫu...\n');
for k = 1:n
    [y, Fs_y] = audioread(templateFiles{k});
    y = y(:,1);
    if Fs_y ~= targetFs, y = resample(y, targetFs, Fs_y); end
    
    y = bandpassFilter(y, targetFs);
    y = removeSilenceAutocorr(y, targetFs);
    
    % Trích xuất sẵn và lưu lại
    env_templates{k} = normalizeSignal(abs(hilbert(y)));
    zcr_templates{k} = normalizeSignal(getZCRContour(y, targetFs));
end
fprintf('Hoàn tất nạp mẫu!\n');

%% =========================================================

% 2. KHỞI TẠO BẢN ĐỒ MÔ PHỎNG XE

% ==========================================================

figure('Name', 'MO PHONG XE GIONG NOI', 'Color', 'w');

axis([0 100 0 100]); axis equal; grid on; hold on;

xlabel('X'); ylabel('Y'); title('XE DIEU KHIEN BANG GIONG NOI');

carX = 50; carY = 50; angle = 90;

carLength = 10; carWidth = 6;

speed = 5; turnAngle = 25;

[carBody, carFront] = drawCar(carX, carY, angle, carLength, carWidth);

%% =========================================================

% 3. VÒNG LẬP NHẬN DẠNG & ĐIỀU KHIỂN

minThreshold = 0.35; 

while ishandle(carBody)
    fprintf('\n>>> Đang nghe... (Nói lệnh của bạn)\n');
    
    % --- THU ÂM TỪ MICRO ---
    recorder = audiorecorder(targetFs, 16, 1);
    recordblocking(recorder, 2); % Thu 2 giây
    x = getaudiodata(recorder);
    x = x(:,1);
    
    % --- TIỀN XỬ LÝ TÍN HIỆU THU ĐƯỢC ---
    x = bandpassFilter(x, targetFs);
    x = removeSilenceAutocorr(x, targetFs);
    
    % Nếu tín hiệu quá ngắn (chỉ có tiếng ồn), bỏ qua
    if length(x) < targetFs * 0.1
        disp('Chưa nghe rõ!'); continue;
    end
    
    % --- TRÍCH XUẤT ĐẶC TRƯNG TÍN HIỆU THỬ ---
    x_env = normalizeSignal(abs(hilbert(x)));
    x_zcr = normalizeSignal(getZCRContour(x, targetFs));
    
    % --- SO SÁNH (CROSS-CORRELATION) ---
    peaks = zeros(1, n);
    for k = 1:n
        [corr_env, ~] = xcorr(x_env, env_templates{k}, 'none');
        [corr_zcr, ~] = xcorr(x_zcr, zcr_templates{k}, 'none');
        
        peak_env = max(corr_env);
        peak_zcr = max(corr_zcr);
        
        % Tinh chỉnh trọng số (Nên test thử 0.5 - 0.5 cho tiếng Việt)
        peaks(k) = (0.3 * peak_env) + (0.7 * peak_zcr);
    end
    
    % --- XUẤT KẾT QUẢ & ĐIỀU KHIỂN ---
    [maxPeak, idx] = max(peaks);
    
    if maxPeak >= minThreshold
        command = commands{idx};
        fprintf('>>> Lệnh: %s (Score: %.2f)\n', command, maxPeak);
% --- ĐIỀU KHIỂN XE ---

switch command

case 'TIEN'

carX = carX + speed * cosd(angle); carY = carY + speed * sind(angle);

case 'LUI'

carX = carX - speed * cosd(angle); carY = carY - speed * sind(angle);

case 'TRAI'

angle = angle + turnAngle;

case 'PHAI'

angle = angle - turnAngle;

case 'DUNG'

% Dừng xe

case 'TIEN_TRAI'

angle = angle + turnAngle; carX = carX + speed * cosd(angle); carY = carY + speed * sind(angle);

case 'TIEN_PHAI'

angle = angle - turnAngle; carX = carX + speed * cosd(angle); carY = carY + speed * sind(angle);

case 'LUI_TRAI'

angle = angle + turnAngle; carX = carX - speed * cosd(angle); carY = carY - speed * sind(angle);

case 'LUI_PHAI'

angle = angle - turnAngle; carX = carX - speed * cosd(angle); carY = carY - speed * sind(angle);

case 'QUAY_TRAI'

angle = angle + 90;

case 'QUAY_PHAI'

angle = angle - 90;

end


% Giới hạn xe trong biên độ 0-100

carX = max(8, min(92, carX)); carY = max(8, min(92, carY));


% Cập nhật đồ họa xe

if ishandle(carBody), delete(carBody); end

if ishandle(carFront), delete(carFront); end

[carBody, carFront] = drawCar(carX, carY, angle, carLength, carWidth);


title(sprintf('Đang chạy: %s | X = %.1f | Y = %.1f | Hướng = %.0f deg', command, carX, carY, angle));

drawnow;
else
        fprintf('>>> Không rõ lệnh (Score: %.2f < %.2f)\n', maxPeak, minThreshold);
    end

end

%% =========================================================
cd('C:\Users\GIGABYTE\OneDrive\Documents\GitHub\DSP-project\code')
speechrecognition
% CÁC HÀM XỬ LÝ TÍN HIỆU & ĐỒ HỌA

% ==========================================================

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
    x = x(:) - mean(x);
    n = norm(x);
    if n > 0, y = x / n; else, y = zeros(size(x)); end
end

function x_filtered = bandpassFilter(x, Fs)
    try
        x_filtered = bandpass(x, [300 3400], Fs);
    catch
        [b, a] = butter(2, [300 3400] / (Fs/2), 'bandpass');
        x_filtered = filtfilt(b, a, x);
    end
end

function [body, front] = drawCar(x, y, angle, carLength, carWidth)
    points = [-carLength/2, -carWidth/2; ...
               carLength/2, -carWidth/2; ...
               carLength/2,  carWidth/2; ...
              -carLength/2,  carWidth/2];
    rotation = [cosd(angle), -sind(angle); sind(angle), cosd(angle)];
    rotated = (rotation * points')';
    body = patch(rotated(:,1) + x, rotated(:,2) + y, 'b', ...
        'EdgeColor', 'k', 'LineWidth', 2);

    frontX = x + cosd(angle) * carLength / 2;
    frontY = y + sind(angle) * carLength / 2;
    front = plot([x, frontX], [y, frontY], 'r', 'LineWidth', 3);
end