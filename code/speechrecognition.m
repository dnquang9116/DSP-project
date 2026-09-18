function speechrecognition()
% GIAO DIỆN MÔ PHỎNG XE 2D ĐIỀU KHIỂN BẰNG GIỌNG NÓI 
% Sử dụng lõi 2D Spectrogram Cross-Correlation chống nhiễu pha và nhận diện phổ

    % 1. Khởi tạo Cửa sổ Đồ họa (Figure & Axes)
    fig = figure('Name', 'Mô Phỏng Xe Điều Khiển Bằng Giọng Nói 2D (Spectrogram)', ...
                 'NumberTitle', 'off', 'Position', [150, 100, 900, 650], ...
                 'Color', [0.94 0.94 0.94]);

    ax = axes('Parent', fig, 'Position', [0.08, 0.1, 0.65, 0.82]);
    hold(ax, 'on'); grid(ax, 'on');
    axis(ax, [-10 10 -10 10]);
    xlabel(ax, 'Tọa độ X (m)', 'FontWeight', 'bold'); 
    ylabel(ax, 'Tọa độ Y (m)', 'FontWeight', 'bold');
    title(ax, 'BẢN ĐỒ MÔ PHỎNG DI CHUYỂN CỦA XE', 'FontSize', 12, 'Color', [0 0.3 0.6]);

    % Trạng thái ban đầu của xe: x=0, y=0, theta = 90 độ (hướng lên trên)
    carState = struct('x', 0, 'y', 0, 'theta', 90);

    % Vẽ xe và đường vết di chuyển (Trajectory)
    hCar = drawCar(ax, carState);
    hTrail = plot(ax, carState.x, carState.y, 'r--', 'LineWidth', 1.5);
    trailX = [carState.x];
    trailY = [carState.y];

    % 2. Khung Bảng Điều Khiển & Trạng Thái (Bên phải)
    uicontrol('Style', 'text', 'Position', [680, 520, 200, 30], ...
              'String', 'BẢNG ĐIỀU KHIỂN', 'FontSize', 11, 'FontWeight', 'bold', ...
              'BackgroundColor', [0.94 0.94 0.94]);

    hStatus = uicontrol('Style', 'text', 'Position', [670, 440, 210, 60], ...
                        'FontSize', 10, 'FontWeight', 'bold', 'ForegroundColor', [0.8 0 0], ...
                        'String', 'Trạng thái: Đang chờ lệnh...', ...
                        'BackgroundColor', [1 1 0.9], 'Style', 'text');

    % Nút ghi âm trực tiếp từ microphone
    uicontrol('Style', 'pushbutton', 'String', 'GHI AM GIONG NOI', ...
              'Position', [680, 370, 190, 45], 'FontSize', 10, 'FontWeight', 'bold', ...
              'BackgroundColor', [0.1 0.6 0.2], 'ForegroundColor', 'w', ...
              'Callback', @(~,~) testAudioCommand());

    % Các nút phím bấm mô phỏng nhanh (dùng để test giao diện)
    uicontrol('Style', 'text', 'Position', [680, 310, 190, 20], 'String', '--- Test Nhanh Phím ---');
    uicontrol('Style', 'pushbutton', 'String', 'TIẾN', 'Position', [740, 260, 70, 30], 'Callback', @(~,~) executeCommand('tien'));
    uicontrol('Style', 'pushbutton', 'String', 'LÙI',  'Position', [740, 180, 70, 30], 'Callback', @(~,~) executeCommand('lui'));
    uicontrol('Style', 'pushbutton', 'String', 'TRÁI', 'Position', [665, 220, 70, 30], 'Callback', @(~,~) executeCommand('trai'));
    uicontrol('Style', 'pushbutton', 'String', 'PHẢI', 'Position', [815, 220, 70, 30], 'Callback', @(~,~) executeCommand('phai'));
    uicontrol('Style', 'pushbutton', 'String', 'DỪNG', 'Position', [740, 220, 70, 30], 'BackgroundColor', [0.8 0.2 0.2], 'ForegroundColor', 'w', 'Callback', @(~,~) executeCommand('dung'));

    % --- HÀM THỰC THI DI CHUYỂN XE ---
    function executeCommand(cmd)
        stepSize = 1.5; % Khoảng dịch chuyển mỗi bước (m)
        rotAngle = 30;  % Góc quay mỗi bước (độ)

        switch lower(cmd)
            case 'tien'
                carState.x = carState.x + stepSize * cosd(carState.theta);
                carState.y = carState.y + stepSize * sind(carState.theta);
                statusText = 'Lệnh: TIẾN ⬆️';
            case 'lui'
                carState.x = carState.x - stepSize * cosd(carState.theta);
                carState.y = carState.y - stepSize * sind(carState.theta);
                statusText = 'Lệnh: LÙI ⬇️';
            case 'trai'
                carState.theta = carState.theta + rotAngle;
                statusText = 'Lệnh: RẼ TRÁI ↩️';
            case 'phai'
                carState.theta = carState.theta - rotAngle;
                statusText = 'Lệnh: RẼ PHẢI ↪️';
            case 'dung'
                statusText = 'Lệnh: DỪNG XE 🛑';
        end

        % Cập nhật bảng trạng thái
        set(hStatus, 'String', sprintf('Đã nhận dạng: "%s"\n(x=%.1f, y=%.1f, θ=%.0f°)', ...
            upper(cmd), carState.x, carState.y, carState.theta));

        % Cập nhật quỹ đạo di chuyển
        trailX(end+1) = carState.x;
        trailY(end+1) = carState.y;
        set(hTrail, 'XData', trailX, 'YData', trailY);

        % Cập nhật hình vẽ xe trên đồ thị
        updateCarPlot(hCar, carState);
    end

    % --- HÀM ĐỌC FILE ÂM THANH & CHẠY THUẬT TOÁN DSP ---
    function testAudioCommand()
        set(hStatus, 'String', 'Dang ghi am trong 2 giay...');
        drawnow;
        recorder = audiorecorder(8000, 16, 1);
        recordblocking(recorder, 2);
        recordedAudio = getaudiodata(recorder);
        recordedFs = 8000;
        % Gọi thuật toán nhận dạng lệnh DSP (Bản 2D Spectrogram)
        detectedCmd = speechDSPCore2D(recordedAudio, recordedFs);

        if ~strcmp(detectedCmd, 'UNKNOWN')
            executeCommand(detectedCmd);
        else
            set(hStatus, 'String', 'KHÔNG NHẬN DẠNG ĐƯỢC!\n(Đỉnh tương quan 2D quá thấp)');
        end
    end
end

% =========================================================================
% HÀM VẼ VÀ CẬP NHẬT HÌNH DẠNG XE 2D
% =========================================================================
function hCar = drawCar(ax, state)
    w = 0.8; l = 1.4; % Kích thước rộng/dài của xe
    carShape = [-w/2, -l/2; w/2, -l/2; w/2, l/2; -w/2, l/2]';
    arrowShape = [0, l/2; -w/3, 0; w/3, 0]'; % Mũi tên chỉ hướng xe

    R = [cosd(state.theta-90), -sind(state.theta-90); sind(state.theta-90), cosd(state.theta-90)];
    rotCar = R * carShape + [state.x; state.y];
    rotArrow = R * arrowShape + [state.x; state.y];

    hCar.body = fill(ax, rotCar(1,:), rotCar(2,:), [0.2 0.4 0.8], 'FaceAlpha', 0.8);
    hCar.arrow = fill(ax, rotArrow(1,:), rotArrow(2,:), [1 0.8 0]);
end

function updateCarPlot(hCar, state)
    w = 0.8; l = 1.4;
    carShape = [-w/2, -l/2; w/2, -l/2; w/2, l/2; -w/2, l/2]';
    arrowShape = [0, l/2; -w/3, 0; w/3, 0]';

    R = [cosd(state.theta-90), -sind(state.theta-90); sind(state.theta-90), cosd(state.theta-90)];
    rotCar = R * carShape + [state.x; state.y];
    rotArrow = R * arrowShape + [state.x; state.y];

    set(hCar.body, 'XData', rotCar(1,:), 'YData', rotCar(2,:));
    set(hCar.arrow, 'XData', rotArrow(1,:), 'YData', rotArrow(2,:));
    drawnow;
end

% =========================================================================
% LÕI THUẬT TOÁN NHẬN DẠNG 2D SPECTROGRAM
% =========================================================================
function cmd = speechDSPCore2D(audioInput, inputFs)
    baseDir = fileparts(mfilename('fullpath'));
    templateNames = {'tien.wav', 'lui.wav', 'trai.wav', 'phai.wav', 'dung.wav'};
    templateFiles = fullfile(baseDir, templateNames);
    cmdNames = {'tien', 'lui', 'trai', 'phai', 'dung'};
    targetFs = 8000;
    minThresh = 0.45; % Ngưỡng tương quan 2D tối thiểu

    x = audioInput;
    Fs = inputFs;
    if size(x, 2) > 1, x = mean(x, 2); end
    if Fs ~= targetFs, x = resample(x, targetFs, Fs); end

    % Tiền xử lý File Test
    x = bandpassFilter(x, targetFs);
    x = removeSilenceAutocorr(x, targetFs);
    S_test = computeSpectrogram2D(x, targetFs); % Trích xuất phổ 2D

    peaks = zeros(1, numel(templateFiles));
    
    for k = 1:numel(templateFiles)
        if ~exist(templateFiles{k}, 'file'), continue; end
        
        [y, Fs_y] = audioread(templateFiles{k});
        y = y(:,1);
        if Fs_y ~= targetFs, y = resample(y, targetFs, Fs_y); end

        % Tiền xử lý File Template
        y = bandpassFilter(y, targetFs);
        y = removeSilenceAutocorr(y, targetFs);
        S_template = computeSpectrogram2D(y, targetFs); % Trích xuất phổ 2D

        % Tính 2D Cross-Correlation với điều kiện chống lỗi size
        if size(S_test, 2) < size(S_template, 2)
            C2D = normxcorr2(S_test, S_template);
        else
            C2D = normxcorr2(S_template, S_test);
        end
        
        peaks(k) = max(C2D(:)); % Lưu lại đỉnh tương quan cực đại
    end

    [maxVal, idx] = max(peaks);
    if maxVal >= minThresh
        cmd = cmdNames{idx};
    else
        cmd = 'UNKNOWN';
    end
end

% --- HÀM PHỤ 1: TRÍCH XUẤT MA TRẬN PHỔ 2D ---
function S_norm = computeSpectrogram2D(x, Fs)
    winLen = round(Fs * 0.030);   % Cửa sổ 30 ms
    overlap = round(winLen * 0.7); % Độ chồng lấp 70%
    nfft = 512;                   % Số điểm FFT

    [S, ~, ~] = spectrogram(x, winLen, overlap, nfft, Fs);
    S_dB = 20 * log10(abs(S) + 1e-6); % Chuyển đổi sang Logarit (dB)

    % Chuẩn hóa Ma trận Phổ (Zero-Mean & Unit Variance)
    S_norm = (S_dB - mean(S_dB(:))) / (std(S_dB(:)) + 1e-6);
end

% --- HÀM PHỤ 2: VAD AUTOCORRELATION ---
function x_clean = removeSilenceAutocorr(x, Fs)
    frameLen = max(1, round(Fs * 0.02));
    hopLen = round(frameLen / 2);
    numFrames = floor((length(x) - frameLen) / hopLen) + 1;
    if numFrames < 1, x_clean = x; return; end

    energy = zeros(1, numFrames);
    autocorrPeak = zeros(1, numFrames);
    minLag = round(Fs / 500); maxLag = round(Fs / 80);

    for i = 1:numFrames
        startSample = (i-1)*hopLen + 1;
        frame = x(startSample : startSample + frameLen - 1);
        energy(i) = sum(frame.^2);

        [r, lags] = xcorr(frame, 'coeff');
        zeroIdx = find(lags == 0);
        searchWin = r(zeroIdx + minLag : zeroIdx + maxLag);
        if ~isempty(searchWin), autocorrPeak(i) = max(searchWin); end
    end

    maxE = max(energy);
    if maxE == 0, x_clean = x; return; end

    isVoiced = (autocorrPeak > 0.3) & (energy > 0.005 * maxE);
    isUnvoiced = (energy > 0.008 * maxE);
    activeFrames = find(isVoiced | isUnvoiced);

    if ~isempty(activeFrames)
        padSamples = round(Fs * 0.05); % Lề 150ms
        startIdx = max(1, (activeFrames(1)-1)*hopLen + 1 - padSamples);
        endIdx = min(length(x), (activeFrames(end)-1)*hopLen + frameLen + padSamples);
        x_clean = x(startIdx:endIdx);
    else
        x_clean = x;
    end
end

% --- HÀM PHỤ 3: BANDPASS FILTER ---
function x_filtered = bandpassFilter(x, Fs)
    try
        x_filtered = bandpass(x, [300 3400], Fs);
    catch
        [b, a] = butter(2, [300 3400] / (Fs/2), 'bandpass');
        x_filtered = filtfilt(b, a, x);
    end
end