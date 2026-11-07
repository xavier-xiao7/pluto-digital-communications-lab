function [bounds,usable]=plutoFskContinuousSegments(valid,overflow)
% Entire overflow frames are unusable: their samples may be discontinuous.
assert(isvector(valid)&&isvector(overflow)&&numel(valid)==numel(overflow));
usable=logical(valid(:))&~logical(overflow(:));
edges=diff([false;usable;false]);bounds=[find(edges==1),find(edges==-1)-1];
end
