function x_denoised = reduceGaussianNoise(x, Fs)
%REDUCEGAUSSIANNOISE Reduce broadband noise using short-time spectral subtraction.
    x = x(:);
    frameLen = round(Fs * 0.032);
    hopLen = round(frameLen / 4);
    if numel(x) < frameLen
        x_denoised = x;
        return;
    end

    nfft = 2^nextpow2(frameLen);
    window = sqrt(0.5 - 0.5 * cos(2 * pi * ((0:frameLen-1)' + 0.5) / frameLen));
    padded = [x; zeros(frameLen, 1)];
    nFrames = ceil((numel(padded) - frameLen) / hopLen) + 1;
    padded(end+1:(nFrames-1)*hopLen+frameLen) = 0;
    spectra = zeros(nfft, nFrames);
    frameEnergy = zeros(1, nFrames);

    for k = 1:nFrames
        startIdx = (k-1) * hopLen + 1;
        frame = padded(startIdx:startIdx+frameLen-1);
        spectra(:, k) = fft(frame .* window, nfft);
        frameEnergy(k) = sum((frame .* window).^2);
    end

    fullFrameCount = floor((numel(x) - frameLen) / hopLen) + 1;
    [~, order] = sort(frameEnergy(1:fullFrameCount), 'ascend');
    noiseFrameCount = max(1, ceil(0.25 * fullFrameCount));
    noisePower = mean(abs(spectra(:, order(1:noiseFrameCount))).^2, 2);

    power = abs(spectra).^2;
    estimatedSpeechPower = max(power - 1.2 * repmat(noisePower, 1, nFrames), ...
                               0.12^2 * power);
    gain = sqrt(estimatedSpeechPower ./ (power + eps));

    output = zeros((nFrames-1)*hopLen + frameLen, 1);
    normalization = zeros(size(output));
    for k = 1:nFrames
        startIdx = (k-1) * hopLen + 1;
        frame = real(ifft(spectra(:, k) .* gain(:, k), nfft));
        output(startIdx:startIdx+frameLen-1) = ...
            output(startIdx:startIdx+frameLen-1) + frame(1:frameLen) .* window;
        normalization(startIdx:startIdx+frameLen-1) = ...
            normalization(startIdx:startIdx+frameLen-1) + window.^2;
    end

    output = output ./ max(normalization, eps);
    x_denoised = output(1:numel(x));
end
