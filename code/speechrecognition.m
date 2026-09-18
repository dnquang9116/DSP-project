
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
    y = removeSilenceAutocorr(y, targetFs); % Sử dụng Autocorrelation cắt khoảng lặng
    
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

while true % (Hoặc while ishandle(carBody))
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
        
        peak_env = max(abs(corr_env));
        peak_zcr = max(abs(corr_zcr));
        
        % Tinh chỉnh trọng số (Nên test thử 0.5 - 0.5 cho tiếng Việt)
        peaks(k) = (0.5 * peak_env) + (0.5 * peak_zcr); 
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

% CÁC HÀM XỬ LÝ TÍN HIỆU & ĐỒ HỌA

% ==========================================================

function cleanAudio = processAudio(audio, Fs)

if size(audio, 2) > 1, audio = mean(audio, 2); end

[b, a] = butter(4, [300 3800] / (Fs/2), 'bandpass');

audio = filter(b, a, audio);


maxVal = max(abs(audio));

if maxVal > 0, audio = audio / maxVal; end


noiseFloor = mean(audio(1:min(1600, floor(length(audio)*0.1))).^2);

energy = audio.^2;

speechIdx = find(energy > max(noiseFloor * 4, 0.003));


if ~isempty(speechIdx)

startIdx = max(1, speechIdx(1) - 600);

endIdx = min(length(audio), speechIdx(end) + 600);

cleanAudio = audio(startIdx:endIdx);

else

cleanAudio = audio;

end


maxClean = max(abs(cleanAudio));

if maxClean > 0, cleanAudio = cleanAudio / maxClean; end

end

function features = extractRobustMFCC(audio, Fs)

coeffs = mfcc(audio, Fs);

features = (coeffs - mean(coeffs, 1)) ./ (std(coeffs, 0, 1) + eps);

end

function [body, front] = drawCar(x, y, angle, L, W)

points = [-L/2 -W/2; L/2 -W/2; L/2 W/2; -L/2 W/2];

R = [cosd(angle) -sind(angle); sind(angle) cosd(angle)];

rotated = (R * points')';

X = rotated(:, 1) + x; Y = rotated(:, 2) + y;

body = patch(X, Y, 'b', 'EdgeColor', 'k', 'LineWidth', 2);

frontX = x + cosd(angle) * L / 2; frontY = y + sind(angle) * L / 2;

front = plot([x frontX], [y frontY], 'r', 'LineWidth', 3);

end 