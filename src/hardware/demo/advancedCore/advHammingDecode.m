function [bits,stats]=advHammingDecode(encoded)
% Correct all single-bit errors; flag every double-bit error per codeword.
% Higher-weight errors can miscorrect: callers must check frame/message CRC.
assert(all(encoded(:)==0|encoded(:)==1)&&mod(numel(encoded),8)==0, ...
    'ADV:HammingInput','Use a multiple of eight binary encoded bits.');
c=reshape(double(encoded(:)),8,[]);
syndrome=mod(sum(c([1 3 5 7],:),1),2) ...
    +2*mod(sum(c([2 3 6 7],:),1),2) ...
    +4*mod(sum(c([4 5 6 7],:),1),2);
odd=mod(sum(c,1),2)==1;
doubleError=syndrome~=0&~odd;columns=find(odd);
positions=syndrome(columns);positions(positions==0)=8;
indices=positions+8*(columns-1);c(indices)=1-c(indices);
d=c([3 5 6 7],:);bits=d(:);
stats=struct('correctedErrors',numel(columns), ...
    'detectedDoubleErrors',sum(doubleError),'codewordCount',size(c,2));
end
