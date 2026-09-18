function [audio, sampleRate] = recordVoice(durationSeconds, sampleRate)
% Thu am truc tiep tu microphone va tra ve tin hieu dang cot.

if nargin < 1 || isempty(durationSeconds)
    durationSeconds = 2;
end
if nargin < 2 || isempty(sampleRate)
    sampleRate = 8000;
end

recorder = audiorecorder(sampleRate, 16, 1);
recordblocking(recorder, durationSeconds);
audio = getaudiodata(recorder, 'double');
audio = audio(:);
end
