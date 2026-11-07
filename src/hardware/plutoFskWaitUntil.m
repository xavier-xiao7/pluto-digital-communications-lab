function plutoFskWaitUntil(stamp)
% Optional two-computer start coordination; maximum waiting time 120 seconds.
if isempty(stamp),return;end
target=datetime(stamp,'InputFormat',"yyyy-MM-dd'T'HH:mm:ss'Z'",'TimeZone','UTC');
remaining=seconds(target-datetime('now','TimeZone','UTC'));
assert(isfinite(remaining)&&remaining<=120&&remaining>=-5,'PLUTO:StartTime', ...
    'Scheduled UTC time must be from 5 seconds ago to 120 seconds in the future.');
while datetime('now','TimeZone','UTC')<target,pause(0.05);end
end
