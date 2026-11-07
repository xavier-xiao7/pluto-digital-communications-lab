function app=runPlutoTerminal(role)
% One radio per host. RX is the default; no transmission starts automatically.
if nargin==0,role='RX';end
demoInit();app=PlutoTerminal(role);waitfor(app.Figure);
end
