-- Database.lua: durable invitation ledger; GUID and enchanter scoped active visits.
local _, ns = ...
local D = {}
ns.Database = D
local TTL=120
local policy=ns.Policy
local function readable(v) return not (issecretvalue and issecretvalue(v)) end
local function safe(fn,...)
    if type(fn)~="function" then return nil end
    local ok,v=pcall(fn,...)
    if ok and readable(v) then return v end
end
local function clock() return safe(GetServerTime) or safe(time) end
local function namekey(s)
    if type(s)~="string" then return nil end
    return s:lower():gsub("%-"," "):gsub("%s+"," "):match("^%s*(.-)%s*$")
end
local function integer(v) return type(v)=="number" and v>=0 and v<1e14 and v%1==0 end
local function text(v) return readable(v) and type(v)=="string" and v~="" end
local function owner() return safe(UnitGUID,"player") end
local function localstamp(t) return safe(date,"%Y-%m-%d %H:%M:%S",t) or tostring(t) end
function D:Init(db,log)
    self.db,self.log=db,log
    if db.customerLedger==nil then db.customerLedger={schema=2,nextID=1,customers={}} end
    local l=db.customerLedger
    if type(l)=="table" and l.schema==1 and type(l.customers)=="table" then l.schema=2 end
    self.ready=type(l)=="table" and l.schema==2 and type(l.customers)=="table" and integer(l.nextID) and l.nextID>=1
    self.ledger=self.ready and l or nil
    self.pending,self.active,self.pendingKeys={},{},{}
    self.activeOwner=nil
    self.revision=0; self.timerGeneration=0; self.timerAt=nil
    if not self.ready then log("Customer ledger schema unsupported; preserved without modification."); policy:Init(self); return end
    -- Rebuild session indexes from records; never rewrite historical outcomes.
    for guid,c in pairs(l.customers) do
        if type(guid)=="string" and type(c)=="table" and type(c.visits)=="table" then
            for _,v in ipairs(c.visits) do
                if type(v)=="table" and integer(v.id) and integer(v.invited) and text(v.owner) then
                    l.nextID=math.max(l.nextID,v.id+1)
                    if v.status=="pending" then self.pending[v.id]={guid=guid,visit=v}; local k=v.owner..":"..guid; self.pendingKeys[k]=(self.pendingKeys[k] or 0)+1
                    end
                end
            end
        end
    end
    policy:Init(self)
    self:Expire(); policy:Resume()
end
function D:Touch()
    self.revision=self.revision+1
    if ns.Dashboard and ns.Dashboard.QueueRefresh then ns.Dashboard:QueueRefresh() end
end
function D:Schedule()
    if not self.ready or not C_Timer or type(C_Timer.After)~="function" then return end
    local now=clock()
    if not now then return end
    local earliest
    for _,p in pairs(self.pending) do
        local deadline=p.visit.invited+TTL
        if not earliest or deadline<earliest then earliest=deadline end
    end
    if self.timerAt==earliest then return end
    self.timerGeneration=self.timerGeneration+1; self.timerAt=earliest
    if not earliest then return end
    local generation=self.timerGeneration
    C_Timer.After(math.max(0.1,earliest-now),function()
        if self.timerGeneration==generation then self.timerAt=nil; self:Expire() end
    end)
end
function D:Resolve(p,status,now,reason)
    local v=p.visit
    if v.status~="pending" then return end
    v.status,v.resolved,v.reason=status,now,reason
    self.pending[v.id]=nil
    local key=v.owner..":"..p.guid; local count=(self.pendingKeys[key] or 1)-1
    self.pendingKeys[key]=count>0 and count or nil
    policy:Outcome(p.guid,v,status,now)
    self:Touch()
end
function D:Expire()
    if not self.ready then return end
    local now=clock()
    if not now then return end
    for _,p in pairs(self.pending) do
        if now>=p.visit.invited+TTL then
            local confirmed=p.visit.sentConfirmed==true
            self:Resolve(p,confirmed and "expired" or "unverified",p.visit.invited+TTL,confirmed and "confirmed sent; 120s timeout" or "delivery not confirmed; timeout")
        end
    end
    self:Schedule()
end
function D:Record(name,guid,status,trackable,guild,whisper)
    if not self.ready or not self.db.enabled or self.db.debug then return end
    local now,own=clock(),owner()
    if not integer(now) or not text(own) or not text(name) then return end
    local validGUID=text(guid)
    -- Unknown identity is recorded separately, never used to attach trades.
    local key=validGUID and guid or ("unknown:"..namekey(name))
    local c=self.ledger.customers[key]
    if not c then c={name=name,visits={}}; self.ledger.customers[key]=c end
    if type(c)~="table" or type(c.visits)~="table" then return end
    c.name=name
    local first,realm
    if type(UnitFullName)=="function" then
        local ok,a,b=pcall(UnitFullName,"player")
        if ok and text(a) then first=a; if text(b) then realm=b end end
    end
    local v={id=self.ledger.nextID,name=name,owner=own,enchanter=first and (realm and first.." "..realm or first) or own,
        invited=now,localTime=localstamp(now),status=status or "pending",tipCopper=0,enchants=0,trades={},unverified=0,
        policyEligible=true,guildAtInvite=guild,guildWhisper=whisper}
    self.ledger.nextID=v.id+1
    c.visits[#c.visits+1]=v
    if v.status=="pending" and (not validGUID or not trackable) then v.status="unverified"; v.reason="identity or prior membership unavailable" end
    if v.status=="pending" then
        self.pending[v.id]={guid=guid,visit=v}
        local pk=own..":"..guid; self.pendingKeys[pk]=(self.pendingKeys[pk] or 0)+1
        -- Only the latest outstanding request can receive one acceptance.
        self:Expire()
        if safe(C_PartyInfo and C_PartyInfo.IsGUIDInGroup,guid)==true then self:OnRoster() end
    else v.resolved=now; policy:Outcome(key,v,v.status,now) end
    self:Touch()
    return v
end
function D:OnRoster()
    if not self.ready then return end
    local now,own=clock(),owner()
    if not integer(now) or not text(own) then return end
    self:Expire()
    local restoring=self.activeOwner~=own
    if restoring then
        self.activeOwner=own; self.active={}
        for guid,c in pairs(self.ledger.customers) do
            if type(c)=="table" and type(c.visits)=="table" then
                for _,v in ipairs(c.visits) do
                    if type(v)=="table" and v.status=="accepted" and not v.closed and v.owner==own then
                        local old=self.active[guid]
                        if not old or old.id<v.id then self.active[guid]=v end
                    end
                end
            end
        end
    end
    local check=C_PartyInfo and C_PartyInfo.IsGUIDInGroup
    local newest={}
    for _,p in pairs(self.pending) do
        if p.visit.owner==own and safe(check,p.guid)==true then
            local old=newest[p.guid]
            if not old or old.visit.id<p.visit.id then newest[p.guid]=p end
        end
    end
    for guid,p in pairs(newest) do
        local old=self.active[guid]
        if old and not old.closed then old.closed=now; policy:Close(guid,old,true) end
        self:Resolve(p,"accepted",now)
        self.active[guid]=p.visit
        -- Earlier overlapping requests cannot be independently resolved.
        -- Do not inflate declines; explicitly label them superseded.
        for _,other in pairs(self.pending) do
            if other.guid==guid and other.visit.owner==own then self:Resolve(other,"superseded",now,"overlapping invite; acceptance attributed to latest") end
        end
    end
    for guid,v in pairs(self.active) do
        if v.owner~=own or safe(check,guid)==false then
            v.closed=now; self.active[guid]=nil; policy:Close(guid,v,restoring or v.owner~=own); self:Touch()
        end
    end
    self:Schedule()
end
function D:NamedResult(name,status,normalize)
    if not self.ready then return end
    local now,own=clock(),owner()
    if not integer(now) or not text(own) then return end
    self:Expire()
    local match,guid
    for _,p in pairs(self.pending) do
        if p.visit.owner==own and normalize(p.visit.name)==name then
            if guid and guid~=p.guid then return end
            guid=p.guid
            if not match or match.visit.id<p.visit.id then match=p end
        end
    end
    if not match then return end
    if status=="sent" then
        match.visit.sentConfirmed=true; self:Touch()
    else
        self:Resolve(match,status,now,"localized named game result")
        for _,other in pairs(self.pending) do
            if other.guid==guid and other.visit.owner==own then
                self:Resolve(other,"superseded",now,"overlapping request; result assigned once")
            end
        end
        self:Schedule()
    end
    return guid
end
function D:InvalidateSent()
    local own=owner()
    for _,p in pairs(self.pending) do
        if p.visit.owner==own then p.visit.sentConfirmed=nil end
    end
end
function D:Decline(message)
    -- Compatibility entry point used by earlier tests; classifier handles all results.
    return ns.InviteResults:Handle(message)
end
function D:FailRecent()
    if not self.ready then return end
    local now,own=clock(),owner()
    if not integer(now) then return end
    local match
    for _,p in pairs(self.pending) do
        if p.visit.owner==own and now-p.visit.invited<=10 and now>=p.visit.invited then
            if match then return end -- ambiguous block; do not misattribute
            match=p
        end
    end
    if match then self:Resolve(match,"failed",now,"native invite block"); self:Schedule() end
end
function D:HasPending(guid)
    local own=owner()
    return type(guid)=="string" and type(own)=="string" and (self.pendingKeys[own..":"..guid] or 0)>0 or false
end
function D:Active(guid)
    if not self.ready or not text(guid) then return end
    local v=self.active[guid]
    if v and v.owner==owner() and not v.closed and safe(C_PartyInfo and C_PartyInfo.IsGUIDInGroup,guid)==true then return v end
end
function D:AddTrade(guid,visit,entry)
    if not self.ready or not visit or visit.status~="accepted" or visit.owner~=owner() then return false end
    -- Trade captured while active; can close just before roster changes.
    local c=self.ledger.customers[guid]
    if not c then return false end
    local found=false
    for _,v in ipairs(c.visits) do if v==visit then found=true; break end end
    if not found then return false end
    if not integer(entry.copper) or not integer(entry.enchants) or entry.enchants>1 then return false end
    visit.trades[#visit.trades+1]=entry
    visit.tipCopper=visit.tipCopper+entry.copper; visit.enchants=visit.enchants+entry.enchants
    if entry.unverified then visit.unverified=visit.unverified+1 end
    policy:Trade(guid,visit,entry)
    self:Touch()
    return true
end
function D:Rows(since)
    local rows={}
    if not self.ready then return rows end
    self:Expire()
    for guid,c in pairs(self.ledger.customers) do
        if type(c)=="table" and type(c.visits)=="table" then
            local r={guid=guid,name=c.name or guid,accepted=0,declined=0,pending=0,other=0,grouped=0,busy=0,noTrade=0,tip=0,enchants=0,last=0,visits={}}
            for _,v in ipairs(c.visits) do
                if type(v)=="table" and integer(v.invited) and (not since or v.invited>=since) then
                    r.visits[#r.visits+1]=v
                    if v.status=="accepted" then r.accepted=r.accepted+1
                    elseif v.status=="declined" or (v.status=="expired" and v.sentConfirmed==true) then r.declined=r.declined+1
                    elseif v.status=="already_grouped" then r.grouped=r.grouped+1
                    elseif v.status=="busy" then r.busy=r.busy+1
                    elseif v.status=="pending" then r.pending=r.pending+1
                    else r.other=r.other+1 end
                    if v.noTrade then r.noTrade=r.noTrade+1 end
                    r.tip=r.tip+(integer(v.tipCopper) and v.tipCopper or 0)
                    r.enchants=r.enchants+(integer(v.enchants) and v.enchants or 0)
                    r.last=math.max(r.last,v.invited)
                end
            end
            if #r.visits>0 then
                local p=policy:Get(guid); r.offenses=p and p.offenses or 0
                r.freeEnchants=p and p.freeEnchants or 0
                r.avg=r.enchants>0 and r.tip/r.enchants or -1
                r.rate=r.accepted+r.declined>0 and r.accepted/(r.accepted+r.declined) or -1
                rows[#rows+1]=r
            end
        end
    end
    return rows
end
function D:Delete(guid)
    if not self.ready or not self.ledger.customers[guid] then return end
    for id,p in pairs(self.pending) do if p.guid==guid then self.pendingKeys[p.visit.owner..":"..guid]=nil; self.pending[id]=nil end end
    self.active[guid]=nil; self.ledger.customers[guid]=nil; self:Touch(); self:Schedule()
end
function D:Reset()
    if not self.ready then return end
    self.ledger.customers={}; self.pending,self.active,self.pendingKeys={},{},{}; self:Touch(); self:Schedule()
end
function D:Now() return clock() end
function D:Stamp(t) return localstamp(t) end
function D:Status()
    local rows=self:Rows(); local visits=0
    for _,r in ipairs(rows) do visits=visits+#r.visits end
    self.log(("Ledger: %d customers; %d invitations; schema=%s"):format(#rows,visits,self.ready and "2" or "unavailable"))
end
