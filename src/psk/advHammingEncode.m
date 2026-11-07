function encoded=advHammingEncode(bits)
% Extended Hamming(8,4): SECDED; data at 3,5,6,7, overall parity at 8.
assert(all(bits(:)==0|bits(:)==1)&&mod(numel(bits),4)==0, ...
    'ADV:HammingInput','Use a multiple of four binary data bits.');
d=reshape(double(bits(:)),4,[]);c=zeros(8,size(d,2));
c([3 5 6 7],:)=d;
c(1,:)=mod(d(1,:)+d(2,:)+d(4,:),2);
c(2,:)=mod(d(1,:)+d(3,:)+d(4,:),2);
c(4,:)=mod(d(2,:)+d(3,:)+d(4,:),2);
c(8,:)=mod(sum(c(1:7,:),1),2);
encoded=c(:);
end
