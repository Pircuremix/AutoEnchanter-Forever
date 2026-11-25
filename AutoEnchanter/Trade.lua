-- Trade.lua: read-only trade observation; never accept or manipulate a trade.
local _,ns=...
local T={}
ns.Trade=T
local function readable(v) return not (issecretvalue and issecretvalue(v)) end
local function capture(fn,...)
    if type(fn)~="function" then return nil end
    local r={pcall(fn,...)}
    if not r[1] then return nil end
    for i=2,9 do if not readable(r[i]) then return nil end end
    return r
end
local function value(fn,...)
    local r=capture(fn,...)
    return r and r[2]
end
local function money(v) return type(v)=="number" and v>=0 and v<1e14 and v%1==0 end
local function present(v) return v~=nil and v~=false and v~="" and v~=0 end
function T:Init(ledger,log)
    self.ledger,self.log=ledger,log; self.current=nil; self.debug=false; self.trace={}; self.stats={confirmed=0,unverified=0,canceled=0}
end
function T:Trace(event)
    if not self.debug then return end
    local s=self.current
    self.trace[#self.trace+1]=("%s %s active=%s accepted=%s snapshot=%s"):format(tostring(GetTime()),event,tostring(s~=nil),tostring(s and s.accepted or false),tostring(s and s.snapshot~=nil or false))
    if #self.trace>80 then table.remove(self.trace,1) end
end
function T:Snapshot(s)
    if not s or s.closed then return end
    local incoming,outgoing=value(GetTargetTradeMoney),value(GetPlayerTradeMoney)
    if not money(incoming) or not money(outgoing) then s.snapshot=nil; return end
    local itemsIn,itemsOut=false,false
    for i=1,6 do
        local p,t=capture(GetTradePlayerItemInfo,i),capture(GetTradeTargetItemInfo,i)
        if not p or not t then s.snapshot=nil; return end
        itemsOut=itemsOut or present(p[2]) or present(p[3]) or present(p[4]) or present(p[9])
        itemsIn=itemsIn or present(t[2]) or present(t[3]) or present(t[4]) or present(t[8])
    end
    local p,t=capture(GetTradePlayerItemInfo,7),capture(GetTradeTargetItemInfo,7)
    if not p or not t then s.snapshot=nil; return end
    -- WoW's native TradeFrame: player enchant return #5, target enchant #6.
    local givenEnchant=type(t[7])=="string" and t[7]~="" and present(t[2])
    local receivedEnchant=present(p[6])
    local currency=false
    for _,fn in ipairs({GetPlayerTradeCurrency or false,GetTargetTradeCurrency or false}) do
        if fn then
            local r=capture(fn)
            if not r then s.snapshot=nil; return end
            for i=2,9 do if present(r[i]) then currency=true end end
        end
    end
    s.snapshot={incoming=incoming,outgoing=outgoing,itemsIn=itemsIn,itemsOut=itemsOut,
        givenEnchant=not not givenEnchant,receivedEnchant=receivedEnchant,currency=currency}
end
function T:Finish(s,confirmed,reason)
    if not s or s.done then return end
    s.done=true
    if self.current==s then self.current=nil end
    local x=s.snapshot
    if confirmed and s.accepted and x and not s.ambiguous then
        local tip=0
        if x.incoming>0 and x.outgoing==0 and not x.itemsIn and not x.itemsOut and not x.receivedEnchant and not x.currency then tip=x.incoming end
        self.ledger:AddTrade(s.guid,s.visit,{at=self.ledger:Now(),copper=tip,enchants=x.givenEnchant and 1 or 0,
            incoming=x.incoming,outgoing=x.outgoing,reason="explicit trade completion",unverified=false})
        self.stats.confirmed=self.stats.confirmed+1
    else
        self.stats.unverified=self.stats.unverified+1
        self.ledger:AddTrade(s.guid,s.visit,{at=self.ledger:Now(),copper=0,enchants=0,reason=reason or "completion or snapshot unverified",unverified=true})
    end
end
function T:Cancel()
    local s=self.current
    if s then s.done=true; self.current=nil; self.stats.canceled=self.stats.canceled+1 end
end
function T:Event(event,...)
    if event=="UNIT_SPELLCAST_SUCCEEDED" then
        local unit=(...)
        if not readable(unit) or unit~="player" or not self.debug then return end
    end
    self:Trace(event)
    if event=="TRADE_SHOW" then
        local ambiguous=self.current~=nil
        if self.current then self:Finish(self.current,false,"new trade before completion evidence") end
        local guid=value(UnitGUID,"npc")
        local v=self.ledger:Active(guid)
        if not v then return end
        self.current={guid=guid,visit=v,accepted=false,closed=false,ambiguous=ambiguous}
        self:Snapshot(self.current)
        return
    end
    local s=self.current
    if not s then return end
    if event=="TRADE_ACCEPT_UPDATE" and not s.closed then
        local a,b=...
        s.accepted=readable(a) and readable(b) and (a==1 or a==true) and (b==1 or b==true) or false
        self:Snapshot(s)
    elseif event=="TRADE_CLOSED" then
        if s.closed then return end
        s.closed=true
        if C_Timer and type(C_Timer.After)=="function" then
            C_Timer.After(2,function() if not s.done then self:Finish(s,false,"trade closed without explicit completion") end end)
        else self:Finish(s,false,"no completion evidence") end
    elseif event=="TRADE_REQUEST_CANCEL" then self:Cancel()
    elseif event=="UI_INFO_MESSAGE" or event=="UI_ERROR_MESSAGE" or event=="CHAT_MSG_SYSTEM" then
        local a,b=...
        local msg=event=="CHAT_MSG_SYSTEM" and a or b
        if not readable(msg) or type(msg)~="string" then return end
        if readable(ERR_TRADE_COMPLETE) and type(ERR_TRADE_COMPLETE)=="string" and msg==ERR_TRADE_COMPLETE then
            self:Finish(s,true,"incomplete final snapshot")
        elseif (readable(ERR_TRADE_CANCELLED) and type(ERR_TRADE_CANCELLED)=="string" and msg==ERR_TRADE_CANCELLED)
            or (readable(ERR_TRADE_CANCELED) and type(ERR_TRADE_CANCELED)=="string" and msg==ERR_TRADE_CANCELED) then self:Cancel() end
    elseif event=="ENCHANT_SPELL_COMPLETED" or event=="UNIT_SPELLCAST_SUCCEEDED" then
        -- Diagnostic only: successful cast alone is not a delivered enchant.
    elseif not s.closed then
        -- Offer changes invalidate the both-accepted snapshot; TRADE_UPDATE may
        -- occur with no offer change, so preserve it only if snapshot identical.
        local old=s.snapshot
        self:Snapshot(s)
        local x=s.snapshot
        local same=old and x
        if same then for k,v in pairs(old) do if x[k]~=v then same=false; break end end end
        if not same or event=="TRADE_PLAYER_ITEM_CHANGED" or event=="TRADE_TARGET_ITEM_CHANGED" or event=="TRADE_MONEY_CHANGED" or event=="TRADE_CURRENCY_CHANGED" then s.accepted=false end
    end
end
function T:Status()
    self.log(("Trade evidence: confirmed=%d; unverified=%d; canceled=%d; trace=%s"):format(self.stats.confirmed,self.stats.unverified,self.stats.canceled,tostring(self.debug)))
end
function T:Command(rest)
    if rest=="on" then self.debug=true
    elseif rest=="off" then self.debug=false
    elseif rest=="clear" then self.trace={}
    elseif rest=="dump" then for _,line in ipairs(self.trace) do self.log(line) end
    else self.log("Usage: /ae tradetrace on|off|dump|clear") end
end
