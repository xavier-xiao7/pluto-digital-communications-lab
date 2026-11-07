function [iBits,qBits,activeSymbols,meta] = advPskFrameBits(frames,cfg)
%ADVPSKFRAMEBITS Add public PHY pilots; modulation/filtering stay in SLX.
% Each tile has 127 public training symbols followed by 256 data symbols.
% Every protocol frame is padded only at its end. The packet decoder ignores
% this trailing padding and the zero-power gaps between protocol frames.
if ~iscell(frames), frames={frames}; end
tileDataBits=cfg.dataSymbolsPerTile*cfg.bitsPerSymbol;
tileCounts=cellfun(@(b)ceil(numel(b)/tileDataBits),frames);
tileSymbols=cfg.trainingLength+cfg.dataSymbolsPerTile;
totalSymbols=sum(tileCounts)*tileSymbols+(numel(frames)+1)*cfg.guardSymbols;
iBits=zeros(totalSymbols,1); qBits=zeros(totalSymbols,1);
activeSymbols=zeros(totalSymbols,1);
cursor=cfg.guardSymbols+1; tileStarts=zeros(sum(tileCounts),1); tile=0;
frameStarts=zeros(numel(frames),1);
for f=1:numel(frames)
    bits=double(frames{f}(:));
    assert(all(bits==0|bits==1),'PSK:Bits','Input must contain binary values only.');
    bits(end+1:tileCounts(f)*tileDataBits,1)=0;
    frameStarts(f)=cursor;
    for j=1:tileCounts(f)
        tile=tile+1; tileStarts(tile)=cursor;
        idx=cursor:cursor+cfg.trainingLength-1;
        iBits(idx)=cfg.trainingIBits; qBits(idx)=cfg.trainingQBits;
        cursor=cursor+cfg.trainingLength;
        data=bits((j-1)*tileDataBits+(1:tileDataBits));
        idx=cursor:cursor+cfg.dataSymbolsPerTile-1;
        if cfg.bitsPerSymbol==1
            iBits(idx)=data;
        else
            iBits(idx)=data(1:2:end); qBits(idx)=data(2:2:end);
        end
        activeSymbols(tileStarts(tile):idx(end))=1;
        cursor=cursor+cfg.dataSymbolsPerTile;
    end
    cursor=cursor+cfg.guardSymbols;
end
meta.tileCount=tile; meta.tileStarts=tileStarts; meta.frameStarts=frameStarts;
meta.tileCountsPerFrame=tileCounts; meta.symbolCount=totalSymbols;
meta.paddingBits=sum(tileCounts)*tileDataBits-sum(cellfun(@numel,frames));
meta.trainingSymbols=tile*cfg.trainingLength;
meta.description='Public periodic PN training; actual I/Q mapping and RRC filters are Simulink blocks.';
end
