function report=verifyProtocol()
% Behavioral protocol tests. Run from the central MATLAB R2025a worker.
% A missing implementation is an intentional RED assertion, not an import error.
assert(exist('advProtocolConfig','file')==2,'ADV:MissingProtocol', ...
    'RED: binary protocol implementation does not exist yet.');
checks={};
cfg=advProtocolConfig();
assert(advCrc16(uint8('123456789'))==hex2dec('29B1'));
[~,hash]=advSha256(uint8('abc'));
assert(strcmp(hash,'ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad'));
checks{end+1}='CRC16 and SHA256 independent known vectors';

% Removing correction or failing to mark a double error breaks these tests.
singleCount=0;doubleCount=0;
for value=0:15
    data=double(bitget(uint8(value),4:-1:1)).';
    encoded=advHammingEncode(data);
    [decoded,s]=advHammingDecode(encoded);
    assert(isequal(decoded,data)&&s.correctedErrors==0&&s.detectedDoubleErrors==0);
    for k=1:8
        corrupt=encoded;corrupt(k)=1-corrupt(k);
        [decoded,s]=advHammingDecode(corrupt);
        assert(isequal(decoded,data)&&s.correctedErrors==1&&s.detectedDoubleErrors==0);
        singleCount=singleCount+1;
    end
    for a=1:7
        for b=a+1:8
            corrupt=encoded;corrupt([a b])=1-corrupt([a b]);
            [~,s]=advHammingDecode(corrupt);
            assert(s.detectedDoubleErrors==1);
            doubleCount=doubleCount+1;
        end
    end
end
assert(singleCount==128&&doubleCount==448);
checks{end+1}='All 128 single-bit corrections and 448 double-bit detections';

% Interleaving must disperse a 16-bit physical burst across codewords.
source=repmat([1;0;1;1;0;1;0;0],12,1);
encoded=advHammingEncode(source);
wire=advInterleave(encoded,16);wire(1:16)=1-wire(1:16);
decodedWire=advDeinterleave(wire,16,numel(encoded));
[decoded,s]=advHammingDecode(decodedWire);
assert(isequal(source,decoded)&&s.correctedErrors==16);
plain=encoded;plain(1:16)=1-plain(1:16);
[decoded,~]=advHammingDecode(plain);
assert(~isequal(source,decoded));
checks{end+1}='16-bit burst recovered by block interleaving';

bytes=uint8((0:255).');
for fec=[false true]
    for interleave=[false true]
        for lineCode={'NRZ','Manchester'}
            txcfg=cfg;txcfg.fec=fec;txcfg.interleave=interleave;
            txcfg.lineCode=lineCode{1};txcfg.payloadType=2;
            [bits,truth]=advEncodeBytes(bytes,txcfg);
            rx=advDecodeBits([zeros(11,1);bits;ones(9,1)],cfg);
            assert(rx.complete&&isequal(rx.bytes,bytes)&&rx.payloadType==2);
            assert(rx.validFrameCount==1&&truth.frameCount==1);
        end
    end
end
checks{end+1}='Every byte 0..255, all FEC/interleaver/line-code modes, public RX config';

[bits,truth]=advEncodeBytes(uint8([]),cfg);
rx=advDecodeBits(bits,cfg);
assert(rx.complete&&isempty(rx.bytes)&&truth.frameCount==1);
checks{end+1}='Empty payload has a valid complete frame';

bytes=uint8(mod((0:768).',251));
txcfg=cfg;txcfg.repetitions=2;
[bits,truth]=advEncodeBytes(bytes,txcfg);
rx=advDecodeBits(bits,cfg);
assert(rx.complete&&isequal(rx.bytes,bytes)&&rx.validFrameCount==8);
rx=advDecodeBits(vertcat(truth.frames{4:-1:1}),cfg);
assert(rx.complete&&isequal(rx.bytes,bytes));
rx=advDecodeBits(vertcat(truth.frames{[1 2 4]}),cfg);
assert(~rx.complete&&isempty(rx.bytes)&&isequal(rx.missingFrames,3));
rx=advDecodeBits(truth.frames{1}(1:end-64),cfg);
assert(~rx.complete&&isempty(rx.bytes));
checks{end+1}='Duplicates and reordering accepted; missing and truncated payload rejected';

a=uint8(repmat((0:255).',2,1));b=uint8(255-a);
[~,ta]=advEncodeBytes(a,cfg);[~,tb]=advEncodeBytes(b,cfg);
rx=advDecodeBits([ta.frames{1};tb.frames{2}],cfg);
assert(~rx.complete&&isempty(rx.bytes)&&numel(rx.messageGroups)==2);
assert(~any([rx.messageGroups.complete]));
checks{end+1}='Complementary fragments from different messages never splice';

[bits,truth]=advEncodeBytes(uint8((1:100).'),cfg);
wire=bits;start=truth.bodyBitStarts(1);wire(start:start+15)=1-wire(start:start+15);
rx=advDecodeBits(wire,cfg);
assert(rx.complete&&isequal(rx.bytes,uint8((1:100).'))&&rx.correctedErrors>=16);
headerStart=numel(cfg.preamble)+numel(cfg.sync)+1;
wire=bits;wire(headerStart:headerStart+15)=1-wire(headerStart:headerStart+15);
rx=advDecodeBits(wire,cfg);assert(rx.complete&&rx.correctedErrors>=16);
wire=bits;wire([headerStart headerStart+16])=1-wire([headerStart headerStart+16]);
rx=advDecodeBits(wire,cfg);assert(~rx.complete&&rx.headerRejected>=1);
checks{end+1}='Protected header and body correct bursts; double header error rejects';

txcfg=cfg;txcfg.fec=false;txcfg.interleave=false;
[bits,truth]=advEncodeBytes(uint8((1:100).'),txcfg);
wire=bits;wire(truth.bodyBitStarts(1)+7)=1-wire(truth.bodyBitStarts(1)+7);
rx=advDecodeBits(wire,cfg);assert(~rx.complete&&rx.crcRejected>=1);
txcfg.lineCode='Manchester';[bits,truth]=advEncodeBytes(uint8((1:100).'),txcfg);
wire=bits;wire(truth.bodyBitStarts(1))=1-wire(truth.bodyBitStarts(1));
rx=advDecodeBits(wire,cfg);assert(~rx.complete&&rx.lineCodeRejected>=1);
checks{end+1}='CRC catches uncoded corruption; Manchester invalid pairs reject';

% A self-consistent frame CRC is insufficient: whole-message hash must pass.
txcfg.lineCode='NRZ';[bits,truth]=advEncodeBytes(uint8((1:100).'),txcfg);
header=truth.headers{1};forged=uint8((1:100).');forged(1)=199;
crc=advCrc16([header(1:51);forged]);
body=[forged;uint8(bitshift(crc,-8));uint8(bitand(crc,255))];
wire=bits;start=truth.bodyBitStarts(1);
wire(start:start+8*numel(body)-1)=advBytesToBits(body);
rx=advDecodeBits(wire,cfg);
assert(rx.validFrameCount==1&&~rx.complete&&isempty(rx.bytes));
assert(~rx.messageGroups(1).messageChecksumOK);
rx=advDecodeBits([bits;wire],cfg);
assert(~rx.complete&&rx.conflictingCopies==1);
checks{end+1}='Recomputed frame CRC cannot bypass whole-message hash or duplicate conflict';

% 65537 bytes needs 257 fragments: catches an 8-bit sequence regression.
longBytes=uint8(mod((0:65536).',251));
[bits,truth]=advEncodeBytes(longBytes,cfg);
rx=advDecodeBits(bits,cfg);
assert(truth.frameCount==257&&rx.complete&&isequal(rx.bytes,longBytes));
assert(max([rx.frames.sequence])==257);
checks{end+1}='65537-byte message crosses old 255-frame and 16-bit length limits';
oversize=false;
try
    advEncodeBytes(zeros(65535*256+1,1,'uint8'),cfg);
catch exception
    oversize=strcmp(exception.identifier,'ADV:MessageTooLong');
end
assert(oversize,'Messages beyond the 16-bit frame count must reject before encoding.');
checks{end+1}='Maximum 16-bit frame-count boundary rejects overflow';

repo=fileparts(fileparts(fileparts(fileparts(mfilename('fullpath')))));
out=fullfile(repo,'results','protocol_payload_fixture');
assets=createExtensionPayloads(out);
assert(numel(assets)==3&&isequal([assets.payloadType],[1 2 3]));
for k=1:numel(assets)
    txcfg=cfg;txcfg.payloadType=assets(k).payloadType;
    [bits,~]=advEncodeBytes(assets(k).bytes,txcfg);
    rx=advDecodeBits(bits,cfg);
    assert(rx.complete&&isequal(rx.bytes,assets(k).bytes));
    [~,actualHash]=advSha256(rx.bytes);assert(strcmp(actualHash,assets(k).sha256Hex));
end
assert(isequal(assets(2).bytes(1:8).',uint8([137 80 78 71 13 10 26 10])));
assert(strcmp(char(assets(3).bytes(1:4).'),'RIFF'));
checks{end+1}='Synthetic UTF-8, PNG, PCM WAV through protocol with byte and hash equality';

report=struct('passed',true,'checkCount',numel(checks),'checks',{checks}, ...
    'singleBitCases',singleCount,'doubleBitCases',doubleCount,'longMessageBytes',65537);
disp(report);
end
