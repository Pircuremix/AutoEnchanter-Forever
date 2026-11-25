-- InviteResults.lua: match localized named results, never guess an unnamed target.
local _,ns=...
local R={}; ns.InviteResults=R
local RULES={
    {"ERR_ALREADY_IN_GROUP_S","already_grouped"},
    {"ERR_ALREADY_INVITED_TO_GROUP_S","busy"},
    {"ERR_ALREADY_INVITED_TO_GROUP_SS","busy"},
    {"ERR_PLAYER_BUSY_S","busy"},
    {"ERR_INVITE_PLAYER_S","sent"},
    {"ERR_DECLINE_GROUP_S","declined"},
    {"ERR_BAD_PLAYER_NAME_S","failed"},
    {"ERR_PLAYER_NOT_FOUND_S","failed"},
    {"ERR_PLAYER_OFFLINE_S","failed"},
    {"ERR_INVITE_RESTRICTED_S","failed"},
}
local function readable(v) return not (issecretvalue and issecretvalue(v)) end
local function clean(s)
    return s:gsub("|c%x%x%x%x%x%x%x%x",""):gsub("|r",""):gsub("|H[^|]+|h%[?(.-)%]?|h","%1"):gsub("%[([^%]]+)%]","%1")
end
local function key(s) return clean(s):lower():gsub("%-"," "):gsub("%s+"," "):match("^%s*(.-)%s*$") end
local function pattern(template)
    -- Replace one/two localized %s fields (including positional placeholders).
    -- Remove player-link markup before compiling, preserving display placeholders.
    template=clean(template)
    local tokens,parts={},{}
    local i=1
    while i<=#template do
        local a,b=template:find("%%[%d]+%$s",i)
        local c,d=template:find("%%s",i)
        if c and (not a or c<a) then a,b=c,d end
        if not a then parts[#parts+1]=template:sub(i):gsub("([^%w])","%%%1"); break end
        parts[#parts+1]=template:sub(i,a-1):gsub("([^%w])","%%%1")
        parts[#parts+1]="(.+)"; tokens[#tokens+1]=true; i=b+1
    end
    if #tokens<1 or #tokens>2 then return nil end
    return "^"..table.concat(parts).."$"
end
function R:Init(ledger)
    self.ledger=ledger; self.rules={}; self.queue=nil; self.unknown=0; self.missedGrouped=0; self.missedBusy=0; self.lastResult=nil
    self.manualNotes={}; self.recentAuto={}; self.ignoredManual={}; self.manualGeneration=0; self.identities={}; self.identityRing={}; self.identityNext=0
    self.manualHookCount=0; self.manualObserved=0; self.manualFallback=0; self.manualErrors=0
    for _,rule in ipairs(RULES) do
        local v=_G[rule[1]]
        if readable(v) and type(v)=="string" then
            local pat=pattern(v)
            if pat then self.rules[#self.rules+1]={pat,rule[2]} end
        end
    end
end
local function safe(fn,...)
    if type(fn)~="function" then return nil end
    local ok,v=pcall(fn,...); if ok and readable(v) then return v end
end
local function validName(name)
    return readable(name) and type(name)=="string" and #name>0 and #name<=128 and not name:find("[%z\1-\31\127]")
end
function R:Enabled()
    return self.ledger and self.ledger.ready and self.ledger.db.enabled and not self.ledger.db.debug
end
function R:Remember(name,guid)
    if not self:Enabled() or not validName(name) or not readable(guid) or type(guid)~="string" or guid=="" then return end
    local k=key(name); local old=self.identities[k]
    if old then
        if old.guid~=guid then old.ambiguous=true end
        old.at=GetTime(); return
    end
    self.identityNext=self.identityNext%2048+1
    local evicted=self.identityRing[self.identityNext]
    if evicted then self.identities[evicted]=nil end
    self.identityRing[self.identityNext]=k
    self.identities[k]={guid=guid,at=GetTime()}
end
function R:Identity(name)
    local wanted=key(name)
    for _,unit in ipairs({"target","mouseover","focus"}) do
        if type(UnitFullName)=="function" then
            local ok,first,surname=pcall(UnitFullName,unit)
            if ok and validName(first) and readable(surname) then
                local full=first
                if validName(surname) and not first:find("[ %-]") then full=first.." "..surname end
                if key(full)==wanted then
                    local guid=safe(UnitGUID,unit)
                    if type(guid)=="string" and guid~="" then return guid end
                end
            end
        end
    end
    local rosterGUID=self.ledger:RosterIdentity(name)
    if rosterGUID then return rosterGUID end
    local cached=self.identities[wanted]
    if cached and not cached.ambiguous and GetTime()-cached.at<=900 then return cached.guid end
end
function R:Begin(name) self.queue={}; self.autoName=name end
function R:End(visit,guid)
    local queue=self.queue or {}; self.queue=nil
    local name=self.autoName; self.autoName=nil
    if validName(name) then
        local t=GetTime()
        -- Bounded automatic-result suppression; never treat late auto evidence as manual.
        if not self.autoPrune or t>=self.autoPrune then
            for k,at in pairs(self.recentAuto) do if t-at>120 then self.recentAuto[k]=nil end end
            self.autoPrune=t+30
        end
        self.recentAuto[key(name)]=t
    end
    self.replaying=true
    self.synchronousVisit,self.synchronousGUID=visit,guid
    for _,msg in ipairs(queue) do self:Handle(msg) end
    self.synchronousVisit,self.synchronousGUID=nil,nil
    self.replaying=false
end
function R:CancelManualActions()
    self.manualGeneration=self.manualGeneration+1
    self.manualNotes={}
end
function R:Observe(name,fallback)
    if self.queue or self.replaying or not self:Enabled() or not validName(name) then return end
    local k=key(name)
    if k=="" then return end
    local note=self.manualNotes[k]; self.manualNotes[k]=nil
    if note and GetTime()-note.at>2 then note=nil end
    if fallback and (not note or note.status~="sent") then return end
    local existing,ambiguous=self.ledger:FindPendingName(k,key)
    if existing or ambiguous then return end
    local guid=self:Identity(name)
    if guid==safe(UnitGUID,"player") or (guid and self.ledger:HasPending(guid)) then return end
    local status=note and note.status or "pending"
    local sent=status=="sent"; if sent then status="pending" end
    local member=guid and safe(C_PartyInfo and C_PartyInfo.IsGUIDInGroup,guid)
    if member==true and status=="pending" and (not sent or self.ledger:Active(guid)) then return end
    local guild=guid and ns.Guild:Membership(guid) or nil
    -- Preserve explicit false: Lua's and/or idiom would otherwise turn it into nil.
    if guid then guild=ns.Guild:Membership(guid) end
    local visit=self.ledger:Record(name,guid,status,member==false or sent and member==true,guild,nil,"manual",sent)
    if not visit then return end
    if note and note.message and note.status~="sent" then
        local t=self.ledger:Now()
        if t then self.lastResult={message=note.message,at=t} end
    end
    self.manualObserved=self.manualObserved+1
    if fallback then self.manualFallback=self.manualFallback+1 end
    if guid and (visit.status=="pending" or visit.status=="accepted") and guild==true then
        -- Post-hook runs after the native call. Do not send from a protected hook stack.
        -- One-shot callback uses only normal native chat restrictions and rechecks master state.
        if C_Timer and type(C_Timer.After)=="function" then
            local generation=self.manualGeneration
            C_Timer.After(0,function()
                if generation==self.manualGeneration and self:Enabled() and (visit.status=="pending" or visit.status=="accepted") then
                    visit.guildWhisper=ns.Guild:Whisper(name,guid,ns.Guild:Membership(guid))
                    self.ledger:Touch()
                end
            end)
        end
    end
end
function R:InstallManualHooks()
    if self.hooksInstalled then return end
    self.hooksInstalled=true
    if type(hooksecurefunc)~="function" or type(C_PartyInfo)~="table" then return end
    for _,method in ipairs({"InviteUnit","ConfirmInviteUnit"}) do
        if type(C_PartyInfo[method])=="function" then
            local ok=pcall(hooksecurefunc,C_PartyInfo,method,function(name)
                if self.queue or self.replaying then return end
                if not self:Enabled() then
                    if validName(name) then
                        local now=GetTime()
                        if not self.ignoredPrune or now>=self.ignoredPrune then
                            for k,t in pairs(self.ignoredManual) do if now-t>120 then self.ignoredManual[k]=nil end end
                            self.ignoredPrune=now+30
                        end
                        local k=key(name); self.ignoredManual[k]=now; self.manualNotes[k]=nil
                    end
                    return
                end
                self.inHook=true
                local success=pcall(self.Observe,self,name,false)
                self.inHook=false
                if not success then self.manualErrors=self.manualErrors+1 end
            end)
            if ok then self.manualHookCount=self.manualHookCount+1 end
        end
    end
end
function R:NoteManual(name,status,message)
    if self.replaying or not self:Enabled() or not validName(name) then return end
    local k=key(name); local t=GetTime()
    -- Recent unmatched auto results are not safe evidence for a new manual call.
    if (self.recentAuto[k] and t-self.recentAuto[k]<=120) or (self.ignoredManual[k] and t-self.ignoredManual[k]<=120) then return end
    if not self.notePrune or t>=self.notePrune then
        for n,v in pairs(self.manualNotes) do if t-v.at>2 then self.manualNotes[n]=nil end end
        self.notePrune=t+2
    end
    local note={status=status,at=t,message=message}; self.manualNotes[k]=note
    -- If no observable hook runs, an outgoing localized sent message is enough
    -- to start an attempt. An unmatched failure alone is never a manual attempt.
    if status=="sent" and not (self.recentAuto[k] and t-self.recentAuto[k]<=120) and C_Timer and type(C_Timer.After)=="function" then
        C_Timer.After(0,function()
            if self.manualNotes[k]==note then self:Observe(name,true) end
        end)
    end
end
function R:Handle(msg)
    if not readable(msg) or type(msg)~="string" or not self.ledger or not self.ledger.ready then return end
    if self.queue then if #self.queue<16 then self.queue[#self.queue+1]=msg end; return end
    local cleaned=clean(msg)
    for _,rule in ipairs(self.rules) do
        local a,b=cleaned:match(rule[1])
        if a and (not b or key(a)==key(b)) then
            local guid=self.ledger:NamedResult(key(a),rule[2],key)
            local t=self.ledger:Now()
            local repeated=self.lastResult and self.lastResult.message==cleaned and t and t-self.lastResult.at<=1
            if guid and rule[2]~="sent" and t then self.lastResult={message=cleaned,at=t} end
            if not guid and not repeated then self:NoteManual(a,rule[2],cleaned) end
            if not guid and not repeated and rule[2]=="already_grouped" then self.missedGrouped=self.missedGrouped+1; self.ledger:InvalidateSent()
            elseif not guid and not repeated and rule[2]=="busy" then self.missedBusy=self.missedBusy+1; self.ledger:InvalidateSent() end
            if guid and rule[2]~="sent" and ns.Group and ns.Group.pending and not self.ledger:HasPending(guid) then ns.Group.pending[guid]=nil end
            return guid
        end
    end
    -- A nameless busy result cannot be linked reliably; invalidate sent
    -- evidence rather than attributing a decline to a potentially unavailable player.
    for _,entry in ipairs({{"ERR_ALREADY_INVITED_TO_GROUP","busy"},{"ERR_ALREADY_IN_GROUP","already_grouped"},{"ERR_PLAYER_BUSY","busy"},{"ERR_GROUP_FULL","failed"},{"ERR_INVITE_PARTY_BUSY","failed"},{"ERR_NOT_LEADER","failed"},{"ERR_INVITE_IN_COMBAT","failed"}}) do
        local v=_G[entry[1]]
        if readable(v) and type(v)=="string" and cleaned==clean(v) then
            local visit,guid=self.synchronousVisit,self.synchronousGUID
            local p=visit and self.ledger.pending[visit.id]
            if p and p.guid==guid then self.ledger:Resolve(p,entry[2],self.ledger:Now(),"synchronous unnamed game result"); self.ledger:Schedule()
            else self.ledger:InvalidateSent(); self.unknown=self.unknown+1 end
            return guid
        end
    end
end

function R:Status(log)
    log(("Unattributed native results (events, may duplicate): grouped=%d busy=%d unnamed=%d"):format(self.missedGrouped,self.missedBusy,self.unknown))
    log(("Manual/external invite observer: hooks=%d observed=%d sent-message fallback=%d errors=%d"):format(self.manualHookCount,self.manualObserved,self.manualFallback,self.manualErrors))
end
