function assets=createExtensionPayloads(outputDir)
% Deterministic SYNTHETIC ALGORITHM TEST fixtures, not photos/recordings.
% Reads bytes back from the real PNG/WAV files for subsequent channel coding.
if nargin<1,outputDir=fullfile(pwd,'synthetic_payloads');end
if ~isfolder(outputDir),mkdir(outputDir);end
message=sprintf(['SYNTHETIC COMMUNICATION TEST / 合成通信测试\n' ...
    'Public test payload | UTF-8 text, binary PNG and PCM WAV.\n' ...
    'This file is generated test data; no photograph or microphone recording.\n']);
textPath=fullfile(outputDir,'synthetic_text_utf8.txt');
fid=fopen(textPath,'wb');assert(fid>=0,'ADV:AssetWrite','Cannot create text fixture.');
closer=onCleanup(@() fclose(fid));fwrite(fid,unicode2native(message,'UTF-8'),'uint8');clear closer

[x,y]=meshgrid(0:31,0:31);
rgb=cat(3,uint8(8*x),uint8(8*y),uint8(255*mod(floor(x/4)+floor(y/4),2)));
imagePath=fullfile(outputDir,'synthetic_pattern_32x32.png');imwrite(rgb,imagePath);
sampleRate=8000;t=(0:1199).'/sampleRate;
envelope=sin(pi*(0:1199).'/1199).^2;
wave=envelope.*(0.42*sin(2*pi*(440*t+600*t.^2))+0.18*sin(2*pi*880*t));
audioPath=fullfile(outputDir,'synthetic_tones_8k_pcm16.wav');
audiowrite(audioPath,wave,sampleRate,'BitsPerSample',16);
paths={textPath,imagePath,audioPath};
names={'Synthetic UTF-8 text','Synthetic 32x32 RGB pattern','Synthetic 0.15 s PCM tones'};
mimes={'text/plain; charset=utf-8','image/png','audio/wav'};
assets=struct('name',{},'path',{},'payloadType',{},'bytes',{},'sha256Hex',{}, ...
    'mimeType',{},'description',{});
for k=1:3
    fid=fopen(paths{k},'rb');assert(fid>=0,'ADV:AssetRead','Cannot read generated fixture.');
    closer=onCleanup(@() fclose(fid));bytes=fread(fid,Inf,'*uint8');clear closer
    [~,hash]=advSha256(bytes);
    assets(k)=struct('name',names{k},'path',paths{k},'payloadType',k,'bytes',bytes, ...
        'sha256Hex',hash,'mimeType',mimes{k}, ...
        'description','程序合成的算法测试素材；不是拍摄照片或麦克风录音。');
end
end
