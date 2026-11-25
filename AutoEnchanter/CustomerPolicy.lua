-- CustomerPolicy.lua: persistent restrictions; constant-time pre-invite query.
local _,ns=...
local P={}; ns.Policy=P
local MINUTE,DAY=60,86400
local function valid(n) return type(n)=="number" and n>=0 and n<1e14 end
local function num(n) return valid(n) and n or 0 end
local function now() return ns.Database:Now() end
local function day(t) local ok,v=pcall(date,"%Y-%m-%d",t); if ok and type(v)=="string" then return v end end
function P:Init(ledger)
    self.ledger=ledger; self.skipped={cooldown=0,declines=0,tips=0}; self.finalizing={}; self.settling={}
    if not ledger.ready then return end
    -- Rebuild lifetime totals once; schema-1 timeouts are not policy evidence.
    for _,c in pairs(ledger.ledger.customers) do
        if type(c)=="table" and type(c.visits)=="table" then
            local p=type(c.policy)=="table" and c.policy or {}; c.policy=p
            p.accepted,p.declines,p.tips,p.uncertain,p.grouped,p.busy,p.noTrade,p.freeEnchants=0,0,0,0,0,0,0,0
            p.offenses=num(p.offenses); p.history=type(p.history)=="table" and p.history or {}
            p.days=type(p.days)=="table" and p.days or {}; p.dayCount=0
            for _ in pairs(p.days) do p.dayCount=p.dayCount+1 end
            for _,v in ipairs(c.visits) do
                if type(v)=="table" and not v.identityUnverified then
                    if v.status=="accepted" then p.accepted=p.accepted+1 end
                    if v.status=="declined" or (v.status=="expired" and v.sentConfirmed==true) then p.declines=p.declines+1 end
                    if v.status=="already_grouped" then p.grouped=p.grouped+1 end
                    if v.status=="busy" then p.busy=p.busy+1 end
                    p.tips=p.tips+num(v.tipCopper); p.uncertain=p.uncertain+num(v.unverified)
                    p.noTrade=p.noTrade+(v.noTrade and 1 or 0); p.freeEnchants=p.freeEnchants+num(v.freeGuildEnchants)
                end
            end
            if p.accepted>0 then p.declineUntil=nil end
            if p.tips>0 then p.tipUntil=nil end
        end
    end
end
function P:Get(guid)
    local l=self.ledger
    local c=l and l.ready and l.ledger.customers[guid]
    if not c then return end
    if not c.policy then c.policy={accepted=0,declines=0,tips=0,uncertain=0,grouped=0,busy=0,noTrade=0,freeEnchants=0,offenses=0,history={},days={},dayCount=0} end
    return c.policy,c
end
function P:Restriction(guid,guild,t)
    if self.settling[guid] then return "cooldown",self.settling[guid].closed+5 end
    local p=self:Get(guid)
    if not p then return nil end
    t=t or now(); if not valid(t) then return nil end
    local untilTime,reason=0,nil
    local function consider(v,r) if num(v)>t and v>untilTime then untilTime,reason=v,r end end
    consider(p.cooldownUntil,"cooldown")
    if p.accepted==0 then consider(p.declineUntil,"declines") end
    -- Unknown membership: do not enforce a tip ban until nonmembership is established.
    if guild==false and p.tips==0 then consider(p.tipUntil,"tips") end
    return reason,untilTime
end
function P:Allow(guid,guild)
    local reason=self:Restriction(guid,guild)
    if reason then self.skipped[reason]=(self.skipped[reason] or 0)+1; return false,reason end
    return true
end
function P:Outcome(guid,v,status,t)
    local p=self:Get(guid)
    if not p then return end
    if status=="accepted" then p.accepted=p.accepted+1; p.declineUntil=nil
    elseif status=="already_grouped" then p.grouped=p.grouped+1
    elseif status=="busy" then p.busy=p.busy+1
    elseif status=="declined" or (status=="expired" and v.sentConfirmed==true) then
        p.declines=p.declines+1
        p.cooldownUntil=math.max(num(p.cooldownUntil),t+30*MINUTE)
        p.cooldownReason=status
        if p.accepted==0 and p.declines>=5 then
            local days=p.declineBans and p.declineBans>0 and 10 or 30
            p.declineBans=num(p.declineBans)+1
            p.declineUntil=math.max(num(p.declineUntil),t+days*DAY)
            p.history[#p.history+1]={kind="decline",at=t,untilTime=p.declineUntil,days=days,visit=v.id,declines=p.declines}
        end
    end
end
function P:Trade(guid,v,entry)
    local p=self:Get(guid)
    if not p then return end
    p.tips=p.tips+num(entry.copper)
    if p.tips>0 then p.tipUntil=nil; p.days={}; p.dayCount=0 end
    if entry.unverified then p.uncertain=p.uncertain+1; return end
    if entry.exchanged then v.exchanged=true end
    if num(entry.enchants)>0 then
        if entry.guild==true or v.guildAtInvite==true then
            v.freeGuildEnchants=num(v.freeGuildEnchants)+entry.enchants
            p.freeEnchants=p.freeEnchants+entry.enchants
        elseif entry.guild==false and v.guildAtInvite==false then
            local d=day(entry.at)
            if d then v.unpaidDays=v.unpaidDays or {}; v.unpaidDays[d]=true end
        end
    end
end
function P:Finalize(guid,v,t)
    if v.policyFinalized or not v.closed then return end
    v.policyFinalized=true
    local p,c=self:Get(guid)
    if not p then return end
    -- Avoid punishing incomplete historical/ambiguous sessions, including
    -- a trade which is still open when the grace period ends.
    local activeTrade=ns.Trade and ns.Trade.current
    if v.policyEligible~=true or v.closureUncertain or num(v.unverified)>0 or (activeTrade and activeTrade.visit==v) then self.ledger:Touch(); return end
    if not v.exchanged then
        v.noTrade=true; p.noTrade=p.noTrade+1
        p.cooldownUntil=math.max(num(p.cooldownUntil),v.closed+30*MINUTE); p.cooldownReason="left without trade"
    end
    if p.tips==0 and p.uncertain==0 and v.unpaidDays and next(v.unpaidDays)
        and not (ns.Guild and ns.Guild:Membership(guid)==true)
        and num(p.tipUntil)<=v.invited then
        for d in pairs(v.unpaidDays) do if not p.days[d] then p.days[d]=true; p.dayCount=p.dayCount+1 end end
        if p.dayCount>=(p.offenses==0 and 2 or 1) then
            p.offenses=p.offenses+1
            local days=p.offenses==1 and 30 or p.offenses==2 and 90 or 180
            p.tipUntil=t+days*DAY
            p.history[#p.history+1]={kind="non_tipping",at=t,untilTime=p.tipUntil,days=days,visit=v.id,offense=p.offenses}
            p.days={}; p.dayCount=0
        end
    end
    self.ledger:Touch()
end
function P:Close(guid,v,uncertain)
    if v.policyFinalized then return end
    if uncertain then v.closureUncertain=true end
    if self.finalizing[v.id] then return end
    self.finalizing[v.id]=true
    if not uncertain and v.policyEligible then self.settling[guid]=v end
    local function finish()
        self.finalizing[v.id]=nil
        if self.settling[guid]==v then self.settling[guid]=nil end
        local p,c=self:Get(guid)
        if not c then return end
        -- Deleted customer / reset / old callback: do not mutate a replacement record.
        local found=false
        for _,item in ipairs(c.visits) do if item==v then found=true; break end end
        if found then self:Finalize(guid,v,now() or v.closed) end
    end
    if C_Timer and type(C_Timer.After)=="function" then C_Timer.After(5,finish) else v.closureUncertain=true; finish() end
end
function P:Resume()
    if not self.ledger.ready then return end
    for guid,c in pairs(self.ledger.ledger.customers) do
        if type(c)=="table" and type(c.visits)=="table" then
            for _,v in ipairs(c.visits) do if v.closed and v.policyEligible and not v.policyFinalized then self:Close(guid,v,true) end end
        end
    end
end
function P:Remove(guid)
    local p=self:Get(guid); if not p then return end
    p.cooldownUntil,p.declineUntil,p.tipUntil=nil,nil,nil
    p.days={}; p.dayCount=0
    p.history[#p.history+1]={kind="manual removal",at=now()}
    self.ledger:Touch()
end
function P:Rows()
    local rows={}
    if not self.ledger or not self.ledger.ready then return rows end
    local t=now(); if not t then return rows end
    for guid,c in pairs(self.ledger.ledger.customers) do
        local p=self:Get(guid)
        if p then
            local guild=ns.Guild and ns.Guild:Membership(guid)
            local reason,expiry=self:Restriction(guid,guild,t)
            if reason or num(p.tipUntil)>t or p.offenses>0 or #p.history>0 then
                rows[#rows+1]={guid=guid,name=c.name or guid,reason=reason or (num(p.tipUntil)>t and "tip ban suspended" or "history"),expiry=reason and expiry or num(p.tipUntil),offenses=p.offenses,history=p.history,cooldownReason=p.cooldownReason or "",guild=guild}
            end
        end
    end
    return rows
end
function P:Status()
    self.ledger.log(("Policy skips: cooldown=%d decline ban=%d tip ban=%d"):format(self.skipped.cooldown,self.skipped.declines,self.skipped.tips))
end
