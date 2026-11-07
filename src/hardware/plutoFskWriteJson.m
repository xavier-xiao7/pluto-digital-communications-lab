function plutoFskWriteJson(file,data)
fid=fopen(file,'w','n','UTF-8');assert(fid>=0,'PLUTO:Write','Cannot write result JSON.');
guard=onCleanup(@()fclose(fid));fprintf(fid,'%s',jsonencode(data,PrettyPrint=true));
end
