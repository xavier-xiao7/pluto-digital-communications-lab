function encoded=advDeinterleave(wire,depth,originalLength)
validateattributes(depth,{'numeric'},{'scalar','integer','positive'});
assert(all(wire(:)==0|wire(:)==1)&&mod(numel(wire),8*depth)==0, ...
    'ADV:InterleaveInput','Use complete interleaver blocks.');
if nargin<3,originalLength=numel(wire);end
validateattributes(originalLength,{'numeric'},{'scalar','integer','nonnegative','<=',numel(wire)});
matrix=reshape(double(wire(:)),depth,8,[]);matrix=permute(matrix,[2 1 3]);
encoded=matrix(:);encoded=encoded(1:originalLength);
end
