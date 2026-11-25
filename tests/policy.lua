-- Actual core + ledger + guild + group + policy, deterministic fake clock.
local count=0
local function check(name,v) assert(v,name); count=count+1; print("PASS "..name) end
local epoch,elapsed,roster,timers,invites,messages,order,logs,guildMembers,guilded,requests,behavior,ns,frame,secret
local D,P,G,R
local DAY=86400
date=os.date; time=os.time
function GetServerTime() return epoch end
function GetTime() return elapsed end
function debugprofilestop() return os.clock()*1000 end
function issecretvalue(v) return rawequal(v,secret) end
function canaccesstable(v) return not issecretvalue(v) end
function GetBuildInfo() return "1.60.1","70790","",16001 end
function UnitGUID(unit)
    if unit=="player" then return "self" end
    if unit=="npc" then return "a" end
    local n=unit:match("^party(%d+)$")
    if n then return roster[tonumber(n)+1] end
end
function UnitFullName(unit) if unit=="player" then return "Sleepy","Smith" end; return UnitGUID(unit),"" end
function UnitName(unit) return UnitFullName(unit) end
function GetZoneText() return "Stormwind" end
LE_PARTY_CATEGORY_INSTANCE=2
function IsInGroup(category) if category==2 then return false end; return #roster>1 end
function IsInRaid() return false end
function GetNumGroupMembers() return #roster>1 and #roster or 0 end
function UnitIsGroupLeader() return true end
function IsInInstance() return false end
function IsInGuild() return guilded end
function GetNumGuildMembers() return #guildMembers end
function GetGuildRosterInfo(i)
    local g=guildMembers[i]
    return g,"Rank",1,60,"Mage","Zone","","",true,0,"MAGE",0,0,false,false,0,g
end
ERR_DECLINE_GROUP_S="%s declines your group invitation."
ERR_INVITE_PLAYER_S="You have invited %s to join your group."
ERR_ALREADY_IN_GROUP_S="%s is already in a group."
ERR_PLAYER_BUSY_S="%s is busy right now."
ERR_BAD_PLAYER_NAME_S="Cannot find player '%s'."
ERR_ALREADY_INVITED_TO_GROUP="Already invited."
ERR_GUILD_LEAVE_S="%s has left the guild."
local function fire(e,...)
    if frame.events[e] then frame.cb(frame,e,...) end
end
local function reset(saved)
    epoch,elapsed=1700000000,0
    roster,timers,invites,messages,order,logs={"self"},{},{},{},{},{}
    guildMembers,guilded,requests,behavior,secret={"self"},false,0,"sent",{}
    frame={events={},RegisterEvent=function(self,e) self.events[e]=true end,UnregisterEvent=function(self,e) self.events[e]=nil end,SetScript=function(self,_,cb) self.cb=cb end}
    CreateFrame=function() return frame end
    Settings=nil; Minimap=nil; Menu={ModifyMenu=function() end}; SlashCmdList={}
    DEFAULT_CHAT_FRAME={AddMessage=function(_,s) logs[#logs+1]=s end}
    C_GuildInfo={GuildRoster=function() requests=requests+1 end}
    C_Timer={After=function(delay,fn) timers[#timers+1]={at=elapsed+delay,fn=fn} end}
    C_ChatInfo={InChatMessagingLockdown=function() return false end,SendChatMessage=function(msg,channel,_,target)
        order[#order+1]="chat"; messages[#messages+1]={msg=msg,channel=channel,target=target}
        if behavior=="whisperblock" and channel=="WHISPER" then fire("ADDON_ACTION_BLOCKED","AutoEnchanter","C_ChatInfo.SendChatMessage") end
    end}
    C_PartyInfo={CanInvite=function() return true end,IsPartyFull=function() return false end,IsGUIDInGroup=function(guid) for _,g in ipairs(roster) do if g==guid then return true end end; return false end,
        InviteUnit=function(name)
            order[#order+1]="invite"; invites[#invites+1]=name
            if behavior=="grouped" then fire("UI_ERROR_MESSAGE",80,name.." is already in a group.")
            elseif behavior=="busy" then fire("UI_ERROR_MESSAGE",82,name.." is busy right now.")
            elseif behavior=="unnamed" then fire("UI_ERROR_MESSAGE",82,ERR_ALREADY_INVITED_TO_GROUP)
            elseif behavior=="unknown" then
            else fire("CHAT_MSG_SYSTEM","You have invited "..name.." to join your group.") end
        end}
    -- Mock secure post-hook (not a runtime replacement in the addon).
    hooksecurefunc=function(obj,method,callback)
        local original=obj[method]
        obj[method]=function(...) original(...); callback(...) end
    end
    C_PartyInfo.ConfirmInviteUnit=function(name) C_PartyInfo.InviteUnit(name) end
    AutoEnchanterDB=saved or {whitelist={"LF enchant crusader"},enabled=true,debug=false,popupEnabled=true,welcomeEnabled=true,welcomeMessage="Normal welcome"}
    ns={}
    for _,file in ipairs({"CustomerPolicy.lua","Guild.lua","InviteResults.lua","Performance.lua","Database.lua","Trade.lua","Group.lua","Settings.lua","Dashboard.lua","Minimap.lua","AutoEnchanter.lua"}) do assert(loadfile("AutoEnchanter/"..file))("AutoEnchanter",ns) end
    D,P,G,R=ns.Database,ns.Policy,ns.Guild,ns.InviteResults
    fire("ADDON_LOADED","AutoEnchanter"); fire("PLAYER_LOGIN"); fire("PLAYER_ENTERING_WORLD")
end
local function advance(s)
    local endTime=elapsed+s
    while true do
        local idx,at
        for i,t in ipairs(timers) do if t.at<=endTime and (not at or t.at<at) then idx,at=i,t.at end end
        if not idx then break end
        local t=table.remove(timers,idx); epoch=epoch+(at-elapsed); elapsed=at; t.fn()
    end
    epoch=epoch+(endTime-elapsed); elapsed=endTime
end
local function chat(guid,name) fire("CHAT_MSG_CHANNEL","LF enchant crusader",name or guid,"Common","Trade","","",2,7,"Trade",1,1,guid) end
local function visit(guid) local c=D.ledger.customers[guid]; return c and c.visits[#c.visits] end
local function decline(guid,name) fire("CHAT_MSG_SYSTEM",(name or guid).." declines your group invitation.") end
local function join(guid) roster={"self",guid}; fire("GROUP_ROSTER_UPDATE") end
local function leave() roster={"self"}; fire("GROUP_ROSTER_UPDATE"); advance(5) end
local function service(guid,copper,enchants,exchanged,guild)
    local v=visit(guid)
    assert(D:AddTrade(guid,v,{at=epoch,copper=copper or 0,enchants=enchants or 0,exchanged=exchanged~=false,guild=guild,unverified=false}))
end
reset(); chat("a"); check("sent evidence captured synchronously",visit("a").sentConfirmed==true)
decline("a"); local p=P:Get("a"); check("decline 30 minute exact cooldown",p.declines==1 and p.cooldownUntil==epoch+1800)
advance(1799); chat("a"); check("decline cooldown suppresses invite",#invites==1)
advance(8); chat("a"); check("decline cooldown expires",#invites==2)
decline("a"); advance(1801)
for i=3,5 do chat("a"); decline("a"); if i<5 then advance(1801) end end
check("fifth decline thirty day ban",p.declines==5 and p.declineUntil==epoch+30*DAY)
advance(30*DAY-1); chat("a"); check("30 day ban suppresses",#invites==5)
advance(8); chat("a"); decline("a"); check("sixth decline ten day ban",p.declines==6 and p.declineUntil==epoch+10*DAY)
advance(10*DAY+1); chat("a"); decline("a"); check("seventh decline ten day ban",p.declines==7 and p.declineUntil==epoch+10*DAY)
advance(10*DAY+1); chat("a"); join("a"); check("acceptance ends decline escalation",p.accepted==1 and not p.declineUntil)
service("a",1,0,true,false); leave(); advance(8); chat("a"); decline("a"); check("after acceptance normal decline cooldown",not p.declineUntil and p.cooldownUntil==epoch+1800)
reset(); behavior="grouped"; chat("a"); check("already grouped is not a decline",visit("a").status=="already_grouped" and P:Get("a").declines==0 and P:Get("a").grouped==1)
advance(8); behavior="busy"; chat("a"); check("busy classified separately",visit("a").status=="busy" and P:Get("a").busy==1)
advance(8); behavior="unnamed"; chat("a"); check("synchronous unnamed busy attributable",visit("a").status=="busy" and P:Get("a").busy==2)
advance(8); behavior="unknown"; chat("a"); advance(120); check("unconfirmed timeout no decline",visit("a").status=="unverified" and P:Get("a").declines==0)
advance(8); behavior="sent"; chat("a"); advance(120); check("confirmed timeout counts",visit("a").status=="expired" and P:Get("a").declines==1)
reset(); chat("a"); fire("UI_ERROR_MESSAGE",80,"a is already in a group."); advance(120); check("async grouped overrides sent proof",visit("a").status=="already_grouped" and P:Get("a").declines==0)
reset(); chat("a"); fire("UI_ERROR_MESSAGE",82,ERR_ALREADY_INVITED_TO_GROUP); advance(120); check("ambiguous async busy invalidates sent",visit("a").status=="unverified")
reset(); chat("a"); advance(8); chat("a"); check("own pending avoids duplicate request",#invites==1)
join("a"); leave(); p=P:Get("a"); check("departure without trade cooldown",p.noTrade==1 and p.cooldownUntil==epoch-5+1800)
advance(8); chat("a"); check("no trade cooldown suppresses",#invites==1)
reset(); chat("a"); join("a"); service("a",0,0,true,false); leave(); check("materials exchange avoids no trade cooldown",P:Get("a").noTrade==0 and not P:Get("a").cooldownUntil)
reset(); chat("a"); join("a"); D:AddTrade("a",visit("a"),{at=epoch,copper=0,enchants=0,unverified=true}); leave()
check("uncertain trade prevents penalties",not P:Get("a").cooldownUntil)
reset(); chat("a"); join("a"); service("a",0,1,true,false); leave(); p=P:Get("a"); check("first unpaid date no ban",p.dayCount==1 and p.offenses==0)
advance(8); chat("a"); join("a"); service("a",0,1,true,false); leave(); check("same local day still one",p.dayCount==1)
advance(DAY); chat("a"); join("a"); service("a",0,1,true,false); leave(); check("second separate day 30-day ban",p.offenses==1 and p.tipUntil==epoch+30*DAY)
advance(30*DAY+1); chat("a"); join("a"); service("a",0,1,true,false); leave(); check("second offense 90 days",p.offenses==2 and p.tipUntil==epoch+90*DAY)
advance(90*DAY+1); chat("a"); join("a"); service("a",0,1,true,false); leave(); check("third offense 180 days",p.offenses==3 and p.tipUntil==epoch+180*DAY)
advance(180*DAY+1); chat("a"); join("a"); service("a",0,1,true,false); leave(); check("fourth offense repeats 180 days",p.offenses==4 and p.tipUntil==epoch+180*DAY)
P:Remove("a"); check("manual unban keeps offense history",p.offenses==4 and not p.tipUntil and #p.history==5)
advance(8); chat("a"); join("a"); service("a",10000,1,true,false); leave(); check("positive tip lifetime immunity",p.tips==10000 and not p.tipUntil)
advance(DAY); chat("a"); join("a"); service("a",0,1,true,false); leave(); check("later unpaid visit with tip history not penalized",p.offenses==4)
reset(); chat("a"); join("a"); service("a",0,1,true,false); leave(); advance(DAY); chat("a"); join("a"); service("a",0,1,true,false); service("a",1,0,true,false); leave()
check("separate tip before departure prevents offense",P:Get("a").offenses==0)
reset(); guilded=true; guildMembers={"self","a"}; fire("PLAYER_GUILD_UPDATE")
check("guild refresh requested and cache invalidated",requests==1 and not G.ready)
fire("GUILD_ROSTER_UPDATE"); check("full roster GUID cache",G:Membership("a")==true and G:Membership("b")==false)
chat("a","Alice Stone"); check("native invite before exact guild whisper",order[1]=="invite" and order[2]=="chat" and messages[1].msg=="yo, I'm your guildie I can enchant you for free. Don't tip me" and messages[1].channel=="WHISPER" and messages[1].target=="Alice Stone")
join("a"); check("normal welcome remains separate",messages[2].channel=="PARTY" and messages[2].msg=="Normal welcome")
service("a",0,1,true,true); leave(); check("guild enchant exempt",P:Get("a").freeEnchants==1 and P:Get("a").dayCount==0)
advance(DAY); G:SetMessage(""); chat("a","Alice Stone"); check("empty guild message suppresses whisper",#messages==2)
join("a"); service("a",0,1,true,true); leave(); check("exemption persists when empty",P:Get("a").dayCount==0 and P:Get("a").freeEnchants==2)
advance(DAY); guildMembers={"self"}; fire("GUILD_ROSTER_UPDATE"); check("former guild member removed",G:Membership("a")==false)
chat("a","Alice Stone"); join("a"); service("a",0,1,true,false); leave(); check("past guild services not retroactive",P:Get("a").dayCount==1 and P:Get("a").offenses==0)
advance(DAY); chat("a","Alice Stone"); join("a"); service("a",0,1,true,false); leave(); p=P:Get("a"); check("former guild member second unpaid day banned",p.offenses==1)
guildMembers={"self","a"}; fire("GUILD_ROSTER_UPDATE"); check("guild membership suspends active tip ban",P:Allow("a",true))
guildMembers={"self"}; fire("GUILD_ROSTER_UPDATE"); check("leaving guild re-enables active tip ban",not P:Allow("a",false))
check("unknown guild not punished by tip ban",P:Allow("a",nil))
reset(); guilded=true; guildMembers={"self","a"}; fire("PLAYER_GUILD_UPDATE"); fire("GUILD_ROSTER_UPDATE"); G:SetMessage("   "); chat("a"); check("whitespace suppresses whisper",#messages==0)
reset(); guilded=true; guildMembers={"self","a"}; fire("PLAYER_GUILD_UPDATE"); fire("GUILD_ROSTER_UPDATE"); G:SetMessage("New custom message"); behavior="whisperblock"; chat("a"); join("a")
check("blocked guild whisper independent of welcome",G.failures==1 and messages[2].msg=="Normal welcome" and ns.Group.chatBlocked==false)
reset(); local saved=AutoEnchanterDB; saved.customerLedger={schema=1,nextID=3,customers={a={name="a",visits={{id=1,owner="self",invited=1700000000,status="expired",tipCopper=0,enchants=0},{id=2,owner="self",invited=1700000000,status="accepted",tipCopper=100,enchants=1,closed=1700000001}}}}}
reset(saved); p=P:Get("a"); check("schema migration preserves history and excludes legacy expiration",saved.customerLedger.schema==2 and p.declines==0 and p.accepted==1 and p.tips==100)
-- Manual native invitations; the same policy ledger handles accepted service.
reset(); C_PartyInfo.InviteUnit("a")
check("manual invite observed before roster",D.ledger.customers["manual:a"].visits[1].source=="manual" and D.ledger.customers["manual:a"].visits[1].status=="pending")
check("manual invite does not add auto performance call",ns.Performance.count==0)
join("a")
check("manual name bound to observed GUID and accepted once",visit("a").status=="accepted" and visit("a").source=="manual" and not D.ledger.customers["manual:a"] and P:Get("a").accepted==1)
check("manual customer normal welcome exactly once",#messages==1 and messages[1].msg=="Normal welcome")
fire("GROUP_ROSTER_UPDATE"); check("manual roster duplicate ignored",#messages==1 and #D.ledger.customers.a.visits==1)
service("a",10000,1,true,false); leave()
check("manual trade tip and enchant counted",visit("a").tipCopper==10000 and visit("a").enchants==1 and P:Get("a").tips==10000)
reset(); C_PartyInfo.InviteUnit("a"); chat("a")
check("auto suppressed while name-only manual invite pending",#invites==1)
decline("a"); check("manual name-only decline counted without ban",D.ledger.customers["manual:a"].visits[1].status=="declined" and not P:Restriction("manual:a",false))
reset(); fire("CHAT_MSG_CHANNEL","Unmatched message","a","Common","Trade","","",2,7,"Trade",1,1,"a"); C_PartyInfo.InviteUnit("a"); decline("a")
check("manual known GUID decline same protection",visit("a").source=="manual" and visit("a").status=="declined" and P:Get("a").cooldownUntil==epoch+1800)
reset(); behavior="grouped"; C_PartyInfo.InviteUnit("a")
check("manual grouped result distinct",D.ledger.customers["manual:a"].visits[1].status=="already_grouped")
reset(); behavior="busy"; C_PartyInfo.InviteUnit("a")
check("manual busy result distinct",D.ledger.customers["manual:a"].visits[1].status=="busy")
reset(); C_PartyInfo.InviteUnit("a"); C_PartyInfo.ConfirmInviteUnit("a"); advance(0)
check("confirmation and duplicate sent event do not duplicate visit",#D.ledger.customers["manual:a"].visits==1)
reset(); chat("a"); advance(0); join("a")
check("auto hook never creates manual duplicate",visit("a").source=="auto" and #D.ledger.customers.a.visits==1 and not D.ledger.customers["manual:a"])
reset(); SlashCmdList.AUTOENCHANTER("off"); C_PartyInfo.InviteUnit("a"); advance(0); join("a")
check("manual invite while disabled not tracked",not next(D.ledger.customers))
reset(); SlashCmdList.AUTOENCHANTER("debug on"); C_PartyInfo.InviteUnit("a"); advance(0); join("a")
check("manual invite while debug not tracked",not next(D.ledger.customers))
reset(); join("a"); check("unrelated roster member not a customer",not next(D.ledger.customers))
reset(); fire("CHAT_MSG_SYSTEM","You have invited a to join your group."); advance(0); join("a")
check("sent message fallback without hook observation",visit("a").source=="manual" and visit("a").status=="accepted" and R.manualFallback==1)
reset(); C_PartyInfo.InviteUnit("a"); advance(120)
check("confirmed name-only expiry recorded, no policy penalty",D.ledger.customers["manual:a"].visits[1].status=="expired" and not P:Restriction("manual:a",false))
reset(); C_PartyInfo.InviteUnit("a"); join("a"); leave()
check("manual no-trade departure receives same cooldown",P:Get("a").noTrade==1 and P:Get("a").cooldownUntil==epoch-5+1800)
reset(); guilded=true; guildMembers={"self","a"}; fire("PLAYER_GUILD_UPDATE"); fire("GUILD_ROSTER_UPDATE"); fire("CHAT_MSG_CHANNEL","Unmatched message","a","Common","Trade","","",2,7,"Trade",1,1,"a")
C_PartyInfo.InviteUnit("a"); advance(0); join("a"); service("a",0,1,true,true); leave()
check("known guild manual invite whisper and exemption",messages[1].channel=="WHISPER" and messages[2].channel=="PARTY" and P:Get("a").freeEnchants==1 and P:Get("a").dayCount==0)
reset(); C_PartyInfo.InviteUnit("a"); local saved=AutoEnchanterDB; reset(saved); join("a")
check("saved manual pending reconciled after reload",visit("a").source=="manual" and visit("a").status=="accepted" and #messages==0)
reset(); C_PartyInfo.InviteUnit("a"); join("a"); fire("CHAT_MSG_SYSTEM","You have invited a to join your group."); advance(0)
check("late duplicate sent evidence for active manual customer ignored",#D.ledger.customers.a.visits==1 and #messages==1)
reset(); join("a"); behavior="unknown"; C_PartyInfo.InviteUnit("a")
check("unconfirmed manual request to existing group member not accepted",not next(D.ledger.customers))
reset(); C_PartyInfo.InviteUnit("a"); SlashCmdList.AUTOENCHANTER("off"); SlashCmdList.AUTOENCHANTER("on"); join("a")
check("master off clears manual pending welcome but preserves acceptance",visit("a").status=="accepted" and #messages==0)
reset(); C_PartyInfo.InviteUnit("a"); SlashCmdList.AUTOENCHANTER("debug on"); SlashCmdList.AUTOENCHANTER("debug off"); join("a")
check("debug clears manual pending welcome but preserves acceptance",visit("a").status=="accepted" and #messages==0)
reset(); behavior="grouped"; C_PartyInfo.InviteUnit("a"); fire("CHAT_MSG_SYSTEM","a is already in a group."); behavior="unknown"; C_PartyInfo.InviteUnit("a")
check("duplicate named error not recycled onto next manual invite",D.ledger.customers["manual:a"].visits[2].status=="pending")
-- Actual hot-path benchmark, mock native API. Preexisting history lookup by GUID;
-- synchronous grouped result avoids building thousands of active requests.
for _,n in ipairs({1000,10000,50000}) do
    local saved={enabled=true,debug=false,popupEnabled=false,whitelist={"LF enchant crusader"},customerLedger={schema=2,nextID=1,customers={}}}
    for i=1,n do local id="bench"..i; saved.customerLedger.customers[id]={name=id,visits={}} end
    reset(saved); behavior="grouped"
    local start=os.clock()
    for i=1,300 do local id="bench"..i; chat(id) end
    local wall=(os.clock()-start)*1000
    local perf=ns.Performance
    check("benchmark "..n.." records: 300 actual native calls",#invites==300 and perf.count==300)
    local values={}; for i,v in ipairs(perf.samples) do values[i]=v end; table.sort(values)
    print(("BENCH customers=%d calls=%d mean_ms=%.4f p95_ms=%.4f p99_ms=%.4f max_ms=%.4f total_event_ms=%.2f"):format(n,perf.count,perf.total/perf.count,values[math.ceil(#values*.95)],values[math.ceil(#values*.99)],perf.max,wall))
end
print(("PASS policy total=%d; runtime=%s"):format(count,_VERSION))
