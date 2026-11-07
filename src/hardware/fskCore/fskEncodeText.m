function [txWave,truth]=fskEncodeText(message,cfg)
% ASCII in 8-bit MSB-first bytes -> protocol frames -> rectangular NRZ.
% NRZ 0/1 selects the 8/12 kHz tones in the Simulink modulator.
% truth is for the experiment evaluator only; never supply it to the RX.
validateattributes(cfg.sps,{'numeric'},{'scalar','integer','>=',4});
assert(cfg.sps==cfg.fs/cfg.baud,'FSK:RateMismatch','Use integer samples per symbol.');
assert(ischar(message)||(isstring(message)&&isscalar(message)), ...
    'FSK:TextType','Message must be one character vector or string scalar.');
message=char(message);
assert(isrow(message)&&~isempty(message),'FSK:EmptyText','Use nonempty text.');
assert(all(double(message)<=127),'FSK:ASCII','Only ASCII values 0 through 127 are supported.');
assert(numel(message)<=255*cfg.maxPayload,'FSK:TextLength','Message exceeds 255 protocol frames.');
validateattributes(cfg.repetitions,{'numeric'},{'scalar','integer','positive'});
validateattributes(cfg.leadSamples,{'numeric'},{'scalar','integer','nonnegative'});
payload=uint8(message);count=ceil(numel(payload)/cfg.maxPayload);
assert(cfg.headerBytes==6,'FSK:HeaderFormat','This protocol requires a six-byte header.');
messageId=fskCrc16(payload);
frames=cell(count,1);starts=zeros(count,1);offset=1;
for n=1:count
    part=payload((n-1)*cfg.maxPayload+1:min(n*cfg.maxPayload,end));
    header=uint8([floor(numel(part)/256),mod(numel(part),256),n,count, ...
        double(bitshift(messageId,-8)),double(bitand(messageId,255))]);
    crc=fskCrc16([header part]);
    protected=[header part uint8(bitshift(crc,-8)) uint8(bitand(crc,255))];
    frames{n}=[cfg.preamble;cfg.sync;fskBytesToBits(protected);zeros(cfg.guardSymbols,1)];
    starts(n)=offset;offset=offset+numel(frames{n});
end
oneCopy=vertcat(frames{:});bits=repmat(oneCopy,cfg.repetitions,1);
frameBitStarts=reshape(starts+(0:cfg.repetitions-1)*numel(oneCopy),[],1);
txWave=[zeros(cfg.leadSamples,1);repelem(bits,cfg.sps);zeros(3*cfg.sps,1)];
txWave=[txWave;zeros(mod(-numel(txWave),cfg.frameSamples),1)];
truth=struct('message',message,'bits',bits,'frames',{frames}, ...
    'frameCount',count,'expectedCopies',count*cfg.repetitions, ...
    'messageId',messageId, ...
    'frameBitStarts',frameBitStarts, ...
    'symbolStartSamples',cfg.leadSamples+(0:numel(bits)-1).'*cfg.sps+1);
end
