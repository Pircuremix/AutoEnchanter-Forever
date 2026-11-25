-- Performance.lua: bounded local chat-to-native-invite measurements.
local _,ns=...
local P={}; ns.Performance=P
function P:Init() self.samples={}; self.count=0; self.total=0; self.max=0; self.index=0 end
function P:Start() if type(debugprofilestop)=="function" then return debugprofilestop() end end
function P:Finish(start,stop)
    if type(start)~="number" or type(stop)~="number" or stop<start then return end
    local ms=stop-start
    self.count=self.count+1; self.total=self.total+ms; self.max=math.max(self.max,ms)
    self.index=self.index%1024+1; self.samples[self.index]=ms
end
function P:Status(log)
    if self.count==0 then log("Invite latency: no measured native calls yet."); return end
    local s={}; for i,v in ipairs(self.samples) do s[i]=v end; table.sort(s)
    log(("Local chat-to-invite ms: n=%d mean=%.3f max=%.3f p95=%.3f p99=%.3f (recent %d samples)"):format(self.count,self.total/self.count,self.max,s[math.ceil(#s*.95)],s[math.ceil(#s*.99)],#s))
end
