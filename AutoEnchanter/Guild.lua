-- Guild.lua: complete roster replacement, no requests on the invite hot path.
local _,ns=...
local G={}; ns.Guild=G
local DEFAULT="yo, I'm your guildie I can enchant you for free. Don't tip me"
local function readable(v) return not (issecretvalue and issecretvalue(v)) end
local function safe(fn,...)
    if type(fn)~="function" then return nil end
    local ok,v=pcall(fn,...)
    if ok and readable(v) then return v end
end
local function valid(v) return type(v)=="string" and #v<=255 and not v:find("[%z\1-\31\127]") end
function G:Init(db,log)
    self.db,self.log=db,log; self.members={}; self.ready=false; self.inGuild=nil; self.requested=false
    self.blocked=false; self.inFlight=false; self.attempts=0; self.calls=0; self.failures=0; self.skips=0
    if type(db.guildWhisperEnabled)~="boolean" then db.guildWhisperEnabled=true end
    if not valid(db.guildWhisperMessage) then db.guildWhisperMessage=DEFAULT end
end
function G:SetMessage(msg)
    if not valid(msg) then return false,"Message must be one line, maximum 255 bytes." end
    self.db.guildWhisperMessage=msg; return true
end
function G:Request()
    if not self.db then return end
    self.inGuild=safe(IsInGuild); self.ready=false; self.members={}
    if self.inGuild==false then self.ready=true; return end
    if self.inGuild~=true then return end
    local fn=(C_GuildInfo and C_GuildInfo.GuildRoster) or GuildRoster
    if type(fn)=="function" then pcall(fn) end
end
function G:Refresh()
    if not self.db then return end
    self.inGuild=safe(IsInGuild); self.ready=false; self.members={}
    if self.inGuild==false then self.ready=true; return end
    if self.inGuild~=true then return end
    local n=safe(GetNumGuildMembers)
    local own=safe(UnitGUID,"player")
    if type(n)~="number" or n<1 or n>10000 or n%1~=0 or type(own)~="string" or type(GetGuildRosterInfo)~="function" then return end
    local nextMembers={}
    for i=1,n do
        local ok,name,_,_,_,_,_,_,_,_,_,_,_,_,_,_,_,guid=pcall(GetGuildRosterInfo,i)
        if not ok or not readable(name) or not readable(guid) or type(name)~="string" or type(guid)~="string" or guid=="" then return end
        nextMembers[guid]=true
    end
    -- Require our own GUID as evidence this is the current guild's roster.
    if not nextMembers[own] then return end
    self.members=nextMembers; self.ready=true
end
function G:Membership(guid)
    if not self.ready or not readable(guid) or type(guid)~="string" or guid=="" then return nil end
    return self.members[guid]==true
end
function G:Whisper(name,guid,knownGuild)
    local d=self.db
    if not d or not d.enabled or d.debug or not d.guildWhisperEnabled or not valid(d.guildWhisperMessage) or d.guildWhisperMessage:match("^%s*$") or knownGuild~=true then return nil end
    if self.blocked or safe(C_ChatInfo and C_ChatInfo.InChatMessagingLockdown)~=false then self.skips=self.skips+1; return "restricted" end
    local fn=C_ChatInfo and C_ChatInfo.SendChatMessage
    if type(fn)~="function" then self.skips=self.skips+1; return "unavailable" end
    self.attempts=self.attempts+1; self.inFlight=true
    local ok,v=pcall(fn,d.guildWhisperMessage,"WHISPER",nil,name)
    self.inFlight=false
    if not ok or not readable(v) or v==false or self.blocked then self.failures=self.failures+1; return "failed" end
    self.calls=self.calls+1; return "called; delivery unconfirmed"
end
function G:Blocked(action)
    if self.inFlight and action:lower():find("sendchatmessage",1,true) then self.blocked=true; return true end
end
function G:Status()
    self.log(("Guild roster ready=%s; whisper attempts=%d calls=%d failed=%d skipped=%d; delivery unconfirmed"):format(tostring(self.ready),self.attempts,self.calls,self.failures,self.skips))
end
function G:Command(cmd,rest)
    if cmd=="guildmessage" then local ok,msg=self:SetMessage(rest); self.log(ok and "Guild whisper saved." or msg); return true end
    if cmd=="guildwhisper" then
        if rest=="on" or rest=="off" then self.db.guildWhisperEnabled=rest=="on"; self.log("Guild whisper "..rest)
        else self.log("Usage: /ae guildwhisper on|off") end
        return true
    end
    if cmd=="guildrefresh" then self:Request(); return true end
end
