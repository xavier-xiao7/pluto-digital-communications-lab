function result=verifyFskMessages()
% A complete-looking mixture of two different messages must be rejected.
addpath(fileparts(mfilename('fullpath')),'-begin');
cfg=fskConfig();cfg.repetitions=1;
messageA=[repmat('A',1,64) repmat('a',1,64)];
messageB=[repmat('B',1,64) repmat('b',1,64)];
[~,a]=fskEncodeText(messageA,cfg);
[~,b]=fskEncodeText(messageB,cfg);
mixed=fskDecodeBits([a.frames{1};b.frames{2}],cfg);
assert(~mixed.complete,'FSK:MixedMessage', ...
    'Complementary valid segments from different messages were combined.');
intactA=fskDecodeBits(vertcat(a.frames{:}),cfg);
assert(intactA.complete&&strcmp(intactA.message,messageA),'The complete first message was lost.');
intactB=fskDecodeBits(vertcat(b.frames{:}),cfg);
assert(intactB.complete&&strcmp(intactB.message,messageB),'The complete second message was lost.');
interleaved=fskDecodeBits([a.frames{1};b.frames{1};a.frames{2};b.frames{2}],cfg);
assert(interleaved.complete&&strcmp(interleaved.message,messageA), ...
    'Independent messages were mixed or the first-observed complete group was lost.');
assert(numel(interleaved.allMessages)==2&&strcmp(interleaved.allMessages{1},messageA) ...
    &&strcmp(interleaved.allMessages{2},messageB),'The receiver did not preserve both complete messages.');
result=struct('mixedRejected',~mixed.complete,'intactA',intactA.complete, ...
    'intactB',intactB.complete,'interleavedFirstMessage',strcmp(interleaved.message,messageA));
disp(result);
end
