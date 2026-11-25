-- End-to-end mocked events: core -> group module -> native calls + settings controls.
local passed=0
local function check(label, value)
    assert(value,label)
    passed=passed+1; print("PASS "..label)
end
local now, roster, raid, instance, inside, leader, assistant, lockdown
local logs, invites, messages, marks, conversions, timers, frames, ns, behavior, markers, secret
LE_PARTY_CATEGORY_INSTANCE=2
function issecretvalue(v) return rawequal(v,secret) end
function canaccesstable(v) return not issecretvalue(v) end
function GetTime() return now end
function GetBuildInfo() return "1.60.1","70790","",16001 end
local function id(unit)
    if unit=="player" then return "self" end
    local p=unit:match("^party(%d+)$")
    local r=unit:match("^raid(%d+)$")
    return p and roster[tonumber(p)+1] or r and roster[tonumber(r)] or nil
end
function UnitGUID(unit) return id(unit) end
function UnitFullName(unit) if unit=="player" then return "Sleepy","Smith" end; return id(unit),"" end
function UnitName(unit) return UnitFullName(unit) end
function GetZoneText() return "Stormwind" end
function IsInGroup(category) if category==LE_PARTY_CATEGORY_INSTANCE then return instance end; return #roster>=2 end
function IsInRaid() return raid end
function GetNumGroupMembers() return #roster>=2 and #roster or 0 end
function IsInInstance() return inside end
function UnitIsGroupLeader() return leader end
function UnitIsGroupAssistant() return assistant end
function GetRaidTargetIndex(unit) return markers[id(unit)] end
function SetRaidTarget(unit,mark)
    assert(unit=="player" and mark>=1 and mark<=8,"only self positive markers")
    marks[#marks+1]=mark
    if behavior.marker=="error" then error("mock marker blocked") end
    if behavior.marker=="blocked" then frames[1].scripts.OnEvent(frames[1],"ADDON_ACTION_BLOCKED","AutoEnchanter","SetRaidTarget"); return end
    markers.self=mark
end
local function frame()
    local f={events={},scripts={},text="",checked=false}
    function f:RegisterEvent(e) self.events[e]=true end
    function f:UnregisterEvent(e) self.events[e]=nil end
    function f:SetScript(e,cb) self.scripts[e]=cb end
    function f:SetText(s) self.text=s end
    function f:GetText() return self.text end
    function f:SetChecked(v) self.checked=v end
    function f:GetChecked() return self.checked end
    function f:CreateFontString() return frame() end
    function f:CreateTexture() return frame() end
    for _,method in ipairs({"SetPoint","SetSize","SetAutoFocus","SetMaxLetters","ClearFocus","SetTexture","SetTexCoord"}) do f[method]=function() end end
    return f
end
function CreateFrame(kind, name, parent, template)
    local f=frame(); f.kind,f.template=kind,template; frames[#frames+1]=f; return f
end
local function fire(event,...)
    local f=frames[1]
    if f.events[event] then f.scripts.OnEvent(f,event,...) end
end
local function reset(saved)
    now,roster,raid,instance,inside,leader,assistant,lockdown=0,{"self"},false,false,false,true,false,false
    logs,invites,messages,marks,conversions,timers,frames,markers={},{},{},{},{},{},{},{}
    behavior={}; secret={}
    DEFAULT_CHAT_FRAME={AddMessage=function(_,s) logs[#logs+1]=s end}
    SlashCmdList={}; Menu={ModifyMenu=function() end}
    Settings={RegisterCanvasLayoutCategory=function(panel,name) return {panel=panel,GetID=function() return 42 end} end,
        RegisterAddOnCategory=function(category) Settings.category=category end,
        OpenToCategory=function(id) Settings.opened=id end}
    C_Timer={After=function(delay,cb) timers[#timers+1]={delay=delay,cb=cb} end}
    C_ChatInfo={InChatMessagingLockdown=function() return lockdown end, SendChatMessage=function(msg,channel)
        messages[#messages+1]={msg=msg,channel=channel}
        if behavior.chat=="error" then error("mock chat blocked") end
        if behavior.chat=="blocked" then fire("ADDON_ACTION_BLOCKED","AutoEnchanter","C_ChatInfo.SendChatMessage") end
    end}
    C_PartyInfo={CanInvite=function() return leader or assistant end, IsPartyFull=function() return false end,
        IsGUIDInGroup=function(guid) for _,g in ipairs(roster) do if g==guid then return true end end; return false end,
        InviteUnit=function(name)
            invites[#invites+1]=name
            if behavior.invite=="error" then error("mock failure") end
            if behavior.invite=="blocked" then fire("ADDON_ACTION_FORBIDDEN","AutoEnchanter","C_PartyInfo.InviteUnit") end
            if behavior.invite=="sync" then roster[#roster+1]="sync"; fire("GROUP_ROSTER_UPDATE") end
        end,
        ConvertToRaid=function()
            conversions[#conversions+1]=true
            if behavior.convert=="error" then error("mock convert denied") end
            if behavior.convert=="blocked" then fire("ADDON_ACTION_BLOCKED","AutoEnchanter","C_PartyInfo.ConvertToRaid"); return end
            if behavior.convert=="sync" then raid=true; fire("GROUP_ROSTER_UPDATE") end
        end}
    AutoEnchanterDB=saved or {whitelist={"LF enchant crusader"},enabled=true,debug=false,popupEnabled=true}
    ns={}
    for _,file in ipairs({"CustomerPolicy.lua","Guild.lua","InviteResults.lua","Performance.lua","Database.lua","Trade.lua","Group.lua","Settings.lua","Dashboard.lua","Minimap.lua","AutoEnchanter.lua"}) do assert(loadfile("AutoEnchanter/"..file))("AutoEnchanter",ns) end
    fire("ADDON_LOADED","AutoEnchanter"); fire("PLAYER_LOGIN"); fire("PLAYER_ENTERING_WORLD")
end
local function cmd(s) SlashCmdList.AUTOENCHANTER(s) end
local function invite(guid,name)
    fire("CHAT_MSG_CHANNEL","LF enchant crusader",name or guid,"Common","Trade","","",2,7,"Trade",1,1,guid)
end
local function join(guid) roster[#roster+1]=guid; fire("GROUP_ROSTER_UPDATE") end
local function setup()
    reset(); cmd("welcome on"); cmd("message Hi {customer} from {player} in {zone}!"); cmd("marker 4")
end
reset({whitelist={"LF enchant crusader"},enabled=true,debug=false,popupEnabled=true,raidThreshold=8,raidMarker=0,welcomeMessage="bad\nmessage"})
check("migration defaults off and valid values",not AutoEnchanterDB.welcomeEnabled and not AutoEnchanterDB.autoMarkerEnabled and not AutoEnchanterDB.autoRaidEnabled and AutoEnchanterDB.raidThreshold==3 and AutoEnchanterDB.raidMarker==1)
check("migration preserves whitelist",#AutoEnchanterDB.whitelist==1)
check("invalid message reset",AutoEnchanterDB.welcomeMessage=="Thanks for choosing me for your enchant!")
ns.Options:Open(); check("settings category registers and opens",Settings.opened==42)
local canvas=Settings.category.panel; canvas.scripts.OnShow(canvas)
local edit,save,firstCheck,star,threshold
for _,f in ipairs(frames) do
    if f.kind=="EditBox" then edit=f end
    if f.text=="Save" then save=f end
    if f.kind=="CheckButton" and not firstCheck then firstCheck=f end
    if f.text:find("Star",1,true) then star=f end
    if f.kind=="Button" and f.text=="5" then threshold=f end
end
edit:SetText("UI message"); save.scripts.OnClick(save)
check("UI message save persists",AutoEnchanterDB.welcomeMessage=="UI message")
firstCheck:SetChecked(true); firstCheck.scripts.OnClick(firstCheck)
check("UI checkbox persists",AutoEnchanterDB.welcomeEnabled==true)
threshold.scripts.OnClick(threshold); check("UI threshold persists",AutoEnchanterDB.raidThreshold==5)
star.scripts.OnClick(star); check("UI marker persists",AutoEnchanterDB.raidMarker==1)
cmd("message "..string.rep("x",256)); check("reject overlong message",AutoEnchanterDB.welcomeMessage=="UI message")
setup(); invite("a","Alice Stone"); check("invite alone no actions",#invites==1 and #messages==0 and #marks==0)
join("unrelated"); check("unrelated join ignored",#messages==0 and #marks==0)
join("a"); check("confirmed party welcome",#messages==1 and messages[1].channel=="PARTY" and messages[1].msg=="Hi Alice Stone from Sleepy in Stormwind!")
check("self marker applied",#marks==1 and marks[1]==4)
fire("GROUP_ROSTER_UPDATE"); check("duplicate event ignored",#messages==1 and #marks==1)
invite("b"); join("b"); check("existing same marker not re-applied",#marks==1 and #messages==2)
markers.self=8; invite("c"); join("c"); check("different existing marker preserved",markers.self==8 and #marks==1)
setup(); markers.other=4; join("other"); invite("a"); join("a"); check("occupied group marker preserved",#marks==0 and #messages==1)
setup(); markers.self=secret; invite("a"); join("a"); check("secret marker skips safely",#marks==0 and #messages==1)
setup(); invite("a"); now=120; join("a"); check("expired pending ignored",#messages==0 and ns.Group.stats.expired==1)
setup(); invite("a"); cmd("off"); cmd("on"); join("a"); check("master off clears pending",#messages==0)
setup(); invite("a"); cmd("debug on"); cmd("debug off"); join("a"); check("debug toggle clears pending",#messages==0)
setup(); cmd("debug on"); invite("a"); join("a"); check("dry run no chat marker or invite",#invites==0 and #messages==0 and #marks==0)
setup(); behavior.invite="error"; invite("a"); join("a"); check("failed invite not tracked",#messages==0)
setup(); behavior.invite="blocked"; invite("a"); join("a"); check("blocked invite not tracked",#messages==0)
setup(); behavior.invite="sync"; invite("sync"); check("synchronous acceptance reconciled",#messages==1)
setup(); cmd("raid 3"); invite("a"); join("a"); check("two total stay party",#conversions==0 and messages[1].channel=="PARTY")
invite("b"); join("b"); check("three total requests conversion, waits for confirmation",#conversions==1 and #messages==1 and #timers==1)
fire("GROUP_ROSTER_UPDATE"); check("pending conversion not retried",#conversions==1)
raid=true; fire("GROUP_ROSTER_UPDATE"); check("converted welcome via raid",#messages==2 and messages[2].channel=="RAID")
timers[1].cb(); check("stale timer no duplicate",#messages==2)
invite("c"); join("c"); check("existing raid welcomes via raid",messages[3].channel=="RAID" and #conversions==1)
roster={"self","c"}; fire("GROUP_ROSTER_UPDATE"); check("raid not auto reverted",raid and #conversions==1)
setup(); cmd("raid 3"); invite("a"); invite("b"); roster={"self","a","b"}; fire("GROUP_ROSTER_UPDATE"); check("multiple pending held",#messages==0 and #conversions==1)
timers[1].cb(); check("unconfirmed conversion falls back to current PARTY",#messages==2 and messages[1].channel=="PARTY" and messages[2].channel=="PARTY")
fire("GROUP_ROSTER_UPDATE"); check("no retry after timeout",#conversions==1 and #messages==2)
setup(); cmd("raid 3"); behavior.convert="sync"; invite("a"); join("a"); invite("b"); join("b"); check("synchronous conversion once",#conversions==1 and #messages==2 and messages[2].channel=="RAID")
setup(); cmd("raid 3"); behavior.convert="error"; join("x"); invite("a"); join("a"); check("conversion failure welcome still party",#messages==1 and messages[1].channel=="PARTY")
setup(); cmd("raid 3"); behavior.convert="blocked"; join("x"); invite("a"); join("a"); check("blocked conversion isolated",#messages==1 and ns.Group.raidBlocked and #conversions==1)
setup(); cmd("raid 3"); leader=false; roster={"self","x","y"}; fire("GROUP_ROSTER_UPDATE"); check("not leader no conversion",#conversions==0); leader=true; fire("PARTY_LEADER_CHANGED"); check("new leader eligible",#conversions==1)
setup(); cmd("raid 3"); instance=true; roster={"self","x","y"}; fire("GROUP_ROSTER_UPDATE"); check("instance group no conversion",#conversions==0)
setup(); cmd("raid 3"); inside=true; roster={"self","x","y"}; fire("GROUP_ROSTER_UPDATE"); check("inside instance no conversion",#conversions==0)
setup(); cmd("raid 4"); roster={"self","x","y"}; fire("GROUP_ROSTER_UPDATE"); check("custom threshold three insufficient",#conversions==0); join("z"); check("custom threshold four eligible",#conversions==1)
setup(); cmd("raid 3"); cmd("debug on"); roster={"self","x","y"}; fire("GROUP_ROSTER_UPDATE"); fire("GROUP_ROSTER_UPDATE"); check("debug conversion simulated once",#conversions==0 and ns.Group.stats.raidSimulated==1)
setup(); invite("a"); lockdown=true; join("a"); check("chat lockdown no send or marking",#messages==0 and #marks==0)
setup(); behavior.marker="error"; invite("a"); join("a"); check("marker failure independent of welcome",#messages==1 and ns.Group.stats.markerSkipped==1)
setup(); behavior.chat="blocked"; invite("a"); join("a"); invite("b"); join("b"); check("chat block isolated and no retry",#messages==1 and #marks==1 and ns.Group.chatBlocked)
setup(); behavior.marker="blocked"; invite("a"); join("a"); invite("b"); join("b"); check("marker block isolated and no retry",#marks==1 and #messages==2 and ns.Group.markerBlocked)
setup(); invite("a"); raid=true; leader=false; join("a"); check("raid nonleader can welcome but not mark",#messages==1 and messages[1].channel=="RAID" and #marks==0)
setup(); cmd("message "); invite("a"); join("a"); check("empty message still marks",#messages==0 and #marks==1)
setup(); invite("a"); local saved=AutoEnchanterDB; reset(saved); join("a"); check("settings persist but pending lost on reload",AutoEnchanterDB.raidMarker==4 and AutoEnchanterDB.welcomeEnabled and #messages==0)
print(("PASS group total=%d; runtime=%s"):format(passed,_VERSION))
