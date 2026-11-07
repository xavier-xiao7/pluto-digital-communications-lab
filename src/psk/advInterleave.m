function wire=advInterleave(encoded,depth)
% Block interleaving: depth x 8 matrix, codewords in rows, send columns.
validateattributes(depth,{'numeric'},{'scalar','integer','positive'});
assert(all(encoded(:)==0|encoded(:)==1)&&mod(numel(encoded),8)==0, ...
    'ADV:InterleaveInput','Use complete binary eight-bit codewords.');
encoded=double(encoded(:));block=8*depth;
encoded=[encoded;zeros(mod(-numel(encoded),block),1)];
matrix=reshape(encoded,8,depth,[]);matrix=permute(matrix,[2 1 3]);
wire=matrix(:);
end
