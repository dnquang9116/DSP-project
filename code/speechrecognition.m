function speechrecognition()
% GIAO DIỆN MÔ PHỎNG XE 2D ĐIỀU KHIỂN BẰNG GIỌNG NÓI 
% Sử dụng lõi 2D Spectrogram Cross-Correlation chống nhiễu pha và nhận diện phổ
% Cần: Signal Processing Toolbox (spectrogram, resample, bandpass) và
%      Image Processing Toolbox (normxcorr2). Lưu file ở dạng UTF-8.

    targetFs = 16000;   % Tần số lấy mẫu dùng chung cho ghi âm và nhận dạng

    % [SỬA 3] mfilename có thể rỗng (Run Section / dán vào Command Window)
    baseDir = fileparts(mfilename('fullpath'));
    if isempty(baseDir), baseDir = pwd; end

    % 1. Khởi tạo Cửa sổ Đồ họa (Figure & Axes)
    fig = figure('Name', 'Mô Phỏng Xe Điều Khiển Bằng Giọng Nói 2D (Spectrogram)', ...
                 'NumberTitle', 'off', 'Position', [150, 100, 900, 650], ...
                 'Color', [0.94 0.94 0.94]);

    ax = axes('Parent', fig, 'Position', [0.08, 0.1, 0.65, 0.82]);
    hold(ax, 'on'); grid(ax, 'on');
    axis(ax, 'equal');                 % [SỬA 3] Trục vuông tỉ lệ, xe và góc quay không bị méo
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
                        'BackgroundColor', [1 1 0.9]);

    % Nút ghi âm trực tiếp từ microphone (lưu handle để khóa/mở nút khi đang ghi)
    hRecBtn = uicontrol('Style', 'pushbutton', 'String', 'GHI ÂM GIỌNG NÓI', ...
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

    % Kiểm tra toolbox và nạp + tiền xử lý các template MỘT LẦN khi khởi động
    missingFcn = {};
    for fn = {'spectrogram', 'resample', 'normxcorr2'}
        if isempty(which(fn{1})), missingFcn{end+1} = fn{1}; end %#ok<AGROW>
    end
    templates = loadTemplates(baseDir, targetFs);
    if ~isempty(missingFcn)
        set(hStatus, 'String', [{'Thiếu hàm (toolbox):'}, missingFcn]);
    elseif ~isempty(templates.missing)
        set(hStatus, 'String', [{'Thiếu/lỗi file mẫu:'}, templates.missing]);
    end

    % --- HÀM THỰC THI DI CHUYỂN XE ---
    function executeCommand(cmd)
        stepSize = 1.5; % Khoảng dịch chuyển mỗi bước (m)
        rotAngle = 30;  % Góc quay mỗi bước (độ)
        mapLim = 9.5;   % [SỬA 3] Giới hạn bản đồ, xe không chạy ra ngoài

        newX = carState.x;
        newY = carState.y;

        switch lower(cmd)
            case 'tien'
                newX = carState.x + stepSize * cosd(carState.theta);
                newY = carState.y + stepSize * sind(carState.theta);
                statusText = 'Lệnh: TIẾN';
            case 'lui'
                newX = carState.x - stepSize * cosd(carState.theta);
                newY = carState.y - stepSize * sind(carState.theta);
                statusText = 'Lệnh: LÙI';
            case 'trai'
                carState.theta = mod(carState.theta + rotAngle, 360); % [SỬA 3] theta trong [0,360)
                statusText = 'Lệnh: RẼ TRÁI';
            case 'phai'
                carState.theta = mod(carState.theta - rotAngle, 360);
                statusText = 'Lệnh: RẼ PHẢI';
            case 'dung'
                statusText = 'Lệnh: DỪNG XE';
            otherwise
                set(hStatus, 'String', {'Lệnh không hợp lệ:', upper(char(cmd))});
                return;
        end

        % [SỬA 3] Chặn xe trong bản đồ
        clampX = min(max(newX, -mapLim), mapLim);
        clampY = min(max(newY, -mapLim), mapLim);
        hitWall = (clampX ~= newX) || (clampY ~= newY);
        carState.x = clampX;
        carState.y = clampY;

        % Cập nhật bảng trạng thái (cell array để xuống dòng)
        lines = { statusText; ...
            sprintf('(x=%.1f, y=%.1f, θ=%.0f°)', carState.x, carState.y, carState.theta)};
        if hitWall, lines{end+1} = 'Chạm biên bản đồ!'; end
        set(hStatus, 'String', lines);

        % Cập nhật quỹ đạo (lệnh DỪNG không thêm điểm trùng)
        if ~strcmpi(cmd, 'dung')
            trailX(end+1) = carState.x;
            trailY(end+1) = carState.y;
            set(hTrail, 'XData', trailX, 'YData', trailY);
        end

        % Cập nhật hình vẽ xe trên đồ thị
        updateCarPlot(hCar, carState);
    end

    % --- HÀM GHI ÂM & CHẠY THUẬT TOÁN DSP ---
    function testAudioCommand()
        % Khóa nút để tránh bấm chồng; tự mở lại khi hàm kết thúc
        set(hRecBtn, 'Enable', 'off');
        restoreBtn = onCleanup(@() set(hRecBtn, 'Enable', 'on')); %#ok<NASGU>

        % [SỬA 3] Không có template nào thì không cần ghi âm
        if all(cellfun(@isempty, templates.S))
            set(hStatus, 'String', {'Không có file mẫu hợp lệ!', 'Kiểm tra file mẫu trong thư mục code'});
            return;
        end

        set(hStatus, 'String', 'Chuẩn bị... (bỏ tay khỏi chuột)');
        drawnow;
        pause(0.6); % chờ tiếng click tắt hẳn

        try
            recorder = audiorecorder(targetFs, 16, 1);
        catch ME
            set(hStatus, 'String', {'Không mở được micro:', ME.message});
            return;
        end

        set(hStatus, 'String', 'NÓI NGAY! (đang ghi 2 giây)');
        drawnow;

        try
            recordblocking(recorder, 2);
            recordedAudio = getaudiodata(recorder);
        catch ME
            set(hStatus, 'String', {'Lỗi khi ghi âm:', ME.message});
            return;
        end

        % Gọi thuật toán nhận dạng lệnh DSP (Bản 2D Spectrogram)
        detectedCmd = speechDSPCore2D(recordedAudio, targetFs, templates);

        if ~strcmp(detectedCmd, 'UNKNOWN')
            executeCommand(detectedCmd);
        else
            set(hStatus, 'String', {'KHÔNG NHẬN DẠNG ĐƯỢC!', '(Điểm thấp hoặc hai lệnh quá sát nhau)'});
        end
    end
end

% =========================================================================
% HÀM VẼ VÀ CẬP NHẬT HÌNH DẠNG XE 2D
% =========================================================================
% [SỬA 3] Gộp phần hình học dùng chung cho drawCar và updateCarPlot
function [rotCar, rotArrow] = carPolygons(state)
    w = 0.8; l = 1.4; % Kích thước rộng/dài của xe
    carShape = [-w/2, -l/2; w/2, -l/2; w/2, l/2; -w/2, l/2]';
    arrowShape = [0, l/2; -w/3, 0; w/3, 0]'; % Mũi tên chỉ hướng xe

    R = [cosd(state.theta-90), -sind(state.theta-90); sind(state.theta-90), cosd(state.theta-90)];
    rotCar = R * carShape + [state.x; state.y];
    rotArrow = R * arrowShape + [state.x; state.y];
end

function hCar = drawCar(ax, state)
    [rotCar, rotArrow] = carPolygons(state);
    hCar.body = fill(ax, rotCar(1,:), rotCar(2,:), [0.2 0.4 0.8], 'FaceAlpha', 0.8);
    hCar.arrow = fill(ax, rotArrow(1,:), rotArrow(2,:), [1 0.8 0]);
end

function updateCarPlot(hCar, state)
    [rotCar, rotArrow] = carPolygons(state);
    set(hCar.body, 'XData', rotCar(1,:), 'YData', rotCar(2,:));
    set(hCar.arrow, 'XData', rotArrow(1,:), 'YData', rotArrow(2,:));
    drawnow;
end

% =========================================================================
% NẠP VÀ TIỀN XỬ LÝ TEMPLATE (CHỈ CHẠY MỘT LẦN)
% =========================================================================
function tpl = loadTemplates(baseDir, targetFs)
    tpl.cmdNames = {'tien', 'lui', 'trai', 'phai', 'dung'};
    templateAliases = {{'tien', 'tiến'}, {'lui', 'lùi'}, ...
                       {'trai', 'trái'}, {'phai', 'phải'}, {'dung', 'dừng'}};
    supportedExt = {'.wav', '.mp3', '.m4a'};
    tpl.Fs = targetFs;
    tpl.S = cell(1, numel(tpl.cmdNames));   % Mỗi lệnh chứa phổ của nhiều mẫu
    tpl.missing = {};
    minLen = round(targetFs * 0.12);
    files = dir(baseDir);

    for k = 1:numel(tpl.cmdNames)
        tpl.S{k} = {};
        matchedFiles = {};
        for fileIdx = 1:numel(files)
            if files(fileIdx).isdir, continue; end
            [~, fileName, fileExt] = fileparts(files(fileIdx).name);
            if ~any(strcmpi(fileExt, supportedExt)), continue; end
            for aliasIdx = 1:numel(templateAliases{k})
                alias = templateAliases{k}{aliasIdx};
                if startsWith(lower(fileName), lower(alias))
                    matchedFiles{end+1} = files(fileIdx).name; %#ok<AGROW>
                    break;
                end
            end
        end

        if isempty(matchedFiles)
            tpl.missing{end+1} = [tpl.cmdNames{k} ' (không có mẫu)']; %#ok<AGROW>
            continue;
        end

        for fileIdx = 1:numel(matchedFiles)
            fileName = matchedFiles{fileIdx};
            f = fullfile(baseDir, fileName);
            try
                [y, Fs_y] = audioread(f);
            catch
                tpl.missing{end+1} = [fileName ' (lỗi đọc)']; %#ok<AGROW>
                continue;
            end
            if size(y, 2) > 1, y = mean(y, 2); end
            if Fs_y ~= targetFs, y = resample(y, targetFs, Fs_y); end
            y = bandpassFilter(y, targetFs);
            y = removeSilenceAutocorr(y, targetFs);
            if length(y) < minLen
                tpl.missing{end+1} = [fileName ' (quá ngắn)']; %#ok<AGROW>
                continue;
            end
            tpl.S{k}{end+1} = computeSpectrogram2D(y, targetFs); %#ok<AGROW>
        end

        if isempty(tpl.S{k}) && ~any(startsWith(tpl.missing, tpl.cmdNames{k}))
            tpl.missing{end+1} = [tpl.cmdNames{k} ' (không có mẫu hợp lệ)']; %#ok<AGROW>
        end
    end
end

% =========================================================================
% LÕI THUẬT TOÁN NHẬN DẠNG 2D SPECTROGRAM
% =========================================================================
function cmd = speechDSPCore2D(audioInput, inputFs, templates)
    cmdNames = templates.cmdNames;
    targetFs = templates.Fs;
    minThresh = 0.45;                 % Ngưỡng tương quan 2D tối thiểu
    minMargin = 0.05;                 % Cách biệt tối thiểu giữa hạng 1 và hạng 2
    minLen = round(targetFs * 0.12);  % Độ dài tối thiểu (120 ms)

    x = audioInput;
    Fs = inputFs;
    if size(x, 2) > 1, x = mean(x, 2); end
    if Fs ~= targetFs, x = resample(x, targetFs, Fs); end

    % Tiền xử lý File Test
    x = bandpassFilter(x, targetFs);
    x = removeSilenceAutocorr(x, targetFs);

    if length(x) < minLen
        fprintf('Tín hiệu quá ngắn sau khi cắt khoảng lặng -> UNKNOWN\n');
        cmd = 'UNKNOWN';
        return;
    end
    S_test = computeSpectrogram2D(x, targetFs); % Trích xuất phổ 2D

    peaks = zeros(1, numel(cmdNames));

    for k = 1:numel(cmdNames)
        for templateIdx = 1:numel(templates.S{k})
            S_template = templates.S{k}{templateIdx};

            % Cái ngắn hơn (theo thời gian) làm template, cái dài hơn làm ảnh
            if size(S_test, 2) < size(S_template, 2)
                T = S_test;     A = S_template;
            else
                T = S_template; A = S_test;
            end
            C2D = normxcorr2(T, A);
            % Chỉ lấy vùng "valid": template nằm trọn trong ảnh
            C2D = C2D(size(T,1):size(A,1), size(T,2):size(A,2));

            peaks(k) = max(peaks(k), max(C2D(:)));
        end
    end

    % In điểm để chỉnh ngưỡng bằng dữ liệu thật
    fprintf('TIEN: %.2f | LUI: %.2f | TRAI: %.2f | PHAI: %.2f | DUNG: %.2f\n', peaks);

    % Quyết định: vượt ngưỡng VÀ hạng 1 hơn hạng 2 đủ xa
    [sortedPeaks, order] = sort(peaks, 'descend');
    if sortedPeaks(1) < minThresh
        cmd = 'UNKNOWN';
    elseif (sortedPeaks(1) - sortedPeaks(2)) < minMargin
        fprintf('Hạng 1 (%s) và hạng 2 (%s) quá sát nhau -> UNKNOWN\n', ...
                upper(cmdNames{order(1)}), upper(cmdNames{order(2)}));
        cmd = 'UNKNOWN';
    else
        cmd = cmdNames{order(1)};
    end
end

% --- HÀM PHỤ 1: TRÍCH XUẤT MA TRẬN PHỔ 2D ---
function S_norm = computeSpectrogram2D(x, Fs)
    winLen = round(Fs * 0.03);   % Cửa sổ 30 ms
    overlap = round(winLen * 0.7); % Độ chồng lấp 70%
    nfft = 512;                   % Số điểm FFT

    [S, F, ~] = spectrogram(x, winLen, overlap, nfft, Fs);

    % Chỉ giữ dải tần trong băng lọc, bỏ vùng ngoài băng thông
    S = S(F >= 150 & F <= 7000, :);
    S_dB = 20 * log10(abs(S) + 1e-6); % Chuyển đổi sang Logarit (dB)

    % Cắt dải động 45 dB (giống lúc vẽ) để nền nhiễu không chi phối z-score
    S_dB = max(S_dB, max(S_dB(:)) - 45);

    % Chuẩn hóa Ma trận Phổ (Zero-Mean & Unit Variance)
    S_norm = (S_dB - mean(S_dB(:))) / (std(S_dB(:)) + 1e-6);
end

% --- HÀM PHỤ 2: VAD AUTOCORRELATION ---
function x_clean = removeSilenceAutocorr(x, Fs)
    x = x(:);
    frameLen = max(1, round(Fs * 0.02));
    hopLen = round(frameLen / 2);
    numFrames = floor((length(x) - frameLen) / hopLen) + 1;
    if numFrames < 1, x_clean = x; return; end

    energy = zeros(1, numFrames);
    autocorrPeak = zeros(1, numFrames);
    minLag = round(Fs / 500);
    maxLag = min(round(Fs / 80), frameLen - 1);
    nfftA = 2^nextpow2(2 * frameLen);   % [SỬA 3] Tự tương quan bằng FFT, nhanh hơn xcorr

    for i = 1:numFrames
        startSample = (i-1)*hopLen + 1;
        frame = x(startSample : startSample + frameLen - 1);
        energy(i) = sum(frame.^2);

        if energy(i) > 0 && minLag < maxLag
            r = real(ifft(abs(fft(frame, nfftA)).^2));
            r = r / r(1);                                   % chuẩn hóa 'coeff' (lag 0 = 1)
            autocorrPeak(i) = max(r(minLag+1 : maxLag+1));  % lag L nằm ở chỉ số L+1
        end
    end

    maxE = max(energy);
    if maxE == 0, x_clean = x; return; end

    isVoiced = (autocorrPeak > 0.3) & (energy > 0.005 * maxE);
    isUnvoiced = (energy > 0.008 * maxE);
    activeFrames = find(isVoiced | isUnvoiced);

    if ~isempty(activeFrames)
        padSamples = round(Fs * 0.05); % Lề 50ms
        startIdx = max(1, (activeFrames(1)-1)*hopLen + 1 - padSamples);
        endIdx = min(length(x), (activeFrames(end)-1)*hopLen + frameLen + padSamples);
        x_clean = x(startIdx:endIdx);
    else
        x_clean = x;
    end
end

% --- HÀM PHỤ 3: BANDPASS FILTER ---
function x_filtered = bandpassFilter(x, Fs)
    % Băng thông 150-7000 Hz (cần Fs >= 16 kHz); nhánh catch dùng cùng dải
    try
        x_filtered = bandpass(x, [150 7000], Fs);
    catch
        [b, a] = butter(2, [150 7000] / (Fs/2), 'bandpass');
        x_filtered = filtfilt(b, a, x);
    end
end