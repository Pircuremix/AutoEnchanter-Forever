-- Run from repository root: lua5.1 tests/regression.lua
local passed = 0
local function check(label, condition)
    assert(condition, label)
    passed = passed + 1
    print('PASS '..label)
end
local now, logs, invites, menus, events = 0, {}, {}, {}, {}
local full, allowed, member, behavior = false, true, false, 'normal'
local secret = setmetatable({}, {__tostring=function() error('secret read') end})
function issecretvalue(v) return rawequal(v, secret) end
function canaccesstable(v) return not issecretvalue(v) end
function GetTime() return now end
function GetBuildInfo() return '1.60.1', '70790', '', 16001 end
function UnitFullName() return 'Sleepy', 'Smith' end
function UnitGUID() return 'Player-self' end
DEFAULT_CHAT_FRAME = {AddMessage=function(_, s) logs[#logs+1]=s end}
SlashCmdList = {}
Menu = {ModifyMenu=function(tag, cb) menus[tag]=cb end}
local frame = {RegisterEvent=function(_, e) events[e]=true end, UnregisterEvent=function(_, e) events[e]=nil end, SetScript=function(self, _, cb) self.cb=cb end}
function CreateFrame() return frame end
local function fire(event, ...) if events[event] then frame.cb(frame,event,...) end end
C_PartyInfo = {CanInvite=function() return allowed end, IsPartyFull=function() return full end, IsGUIDInGroup=function(guid) assert(type(guid)=='string'); return member end, InviteUnit=function(name)
    assert(type(name)=='string'); invites[#invites+1]=name
    if behavior=='error' then error('mock failure') end
    if behavior=='blocked' then fire('ADDON_ACTION_BLOCKED','AutoEnchanter','C_PartyInfo.InviteUnit') end
end}
AutoEnchanterDB = {whitelist={'LF enchanter 15 agility gloves', 'LF enchanter 15 agility gloves', false, {}, '  '}, debug=true, popupEnabled=true, enabled=true}
local ns = {}
assert(loadfile('AutoEnchanter/Group.lua'))('AutoEnchanter',ns)
assert(loadfile('AutoEnchanter/Settings.lua'))('AutoEnchanter',ns)
assert(loadfile('AutoEnchanter/AutoEnchanter.lua'))('AutoEnchanter',ns)
fire('ADDON_LOADED','Other'); fire('ADDON_LOADED','AutoEnchanter'); fire('PLAYER_LOGIN'); fire('PLAYER_ENTERING_WORLD')
local function cmd(s) SlashCmdList.AUTOENCHANTER(s); return logs[#logs] or '' end
local function test(s) return cmd('test '..s):find(']|r MATCH (no invite',1,true) end
local function chat(msg,name,guid,zone,index,event)
    fire(event or 'CHAT_MSG_CHANNEL',msg,name or 'Alice Stone','Common','Trade','','',zone or 2,index or 4,'Trade',1,1,guid or 'Player-alice')
end
local request='LF enchanter 15 agility gloves'
check('saved whitelist valid originals retained',#AutoEnchanterDB.whitelist==2)
check('exact normalized phrase',test(request))
for _, phrase in ipairs({'LF enchater 15agi glove','LF ench 15 agi gloves my mats','LF enchanter 15agi gloves 20g tip','LF enchanter 15agi gloves 2.5 gold tip','LF enchanter 15agi gloves 30gold','LF enchanter +15 AGI gloves!!!'}) do check('alias/price '..phrase,test(phrase)) end
for _, phrase in ipairs({'LF enchanter 7 agility gloves','LF enchanter 15 agility weapon','WTS enchanter 15 agility gloves','LF enchanter 15 agility gloves 15gems','LF enchanter 15 agility gloves plus crusader'}) do check('reject '..phrase,not test(phrase)) end
cmd('remove 1'); check('duplicate normalized entries remain functional',test(request)); cmd('add '..request); check('duplicate rejected',#AutoEnchanterDB.whitelist==1)
cmd('remove 1.5'); check('fractional remove rejected',#AutoEnchanterDB.whitelist==1)
cmd('add LF enchant shield tough shield'); check('link parsing',test('LF |cffffd000|Henchant:27944:0|h[Enchanting: Enchant Shield - Tough Shield]|h|r'))
chat(request); check('debug no live invite',#invites==0); check('debug output',logs[#logs]:find('would have invited',1,true))
cmd('debug off'); now=8; chat(request); check('real call uses full raw name',#invites==1 and invites[1]=='Alice Stone'); check('delivery not asserted',logs[#logs]:find('delivery unconfirmed',1,true))
chat(request,'Alice-Stone'); check('space/hyphen same cooldown',#invites==1)
chat(request,'Alice Oak','Player-oak'); check('same first name different surname',#invites==2)
chat(request,'Bob','Player-bob',0,2); check('custom slot 2 ignored',#invites==2)
chat(request,'Bob','Player-bob',1,9); check('General slot 9 accepted',#invites==3)
chat(request,'Sleepy-Smith','Player-self'); check('self excluded',#invites==3)
chat(secret,'Eve','Player-eve'); chat(request,secret,'Player-eve'); chat(request,'Eve',secret); check('restricted message/name/GUID skipped',#invites==3)
now=16; chat(request); check('cooldown expires',#invites==4)
full=true; chat(request,'Full Test','Player-full'); check('full party no invite',#invites==4); full=false
allowed=false; chat(request,'No Leader','Player-leader'); check('permission denied',#invites==4); allowed=true
member=true; chat(request,'Existing Member','Player-member'); check('existing member excluded',#invites==4); member=false
allowed=secret; chat(request,'Secret Permission','Player-perm'); check('secret eligibility fails closed',#invites==4); allowed=true
cmd('off'); chat('LF enchant crusader','Learn Me','Player-learn'); check('off means no invites',#invites==4)
local click
local root={CreateButton=function(_,_,cb) click=cb end}
menus.MENU_UNIT_PLAYER(nil,root,{name='Learn',surname='Me'}); check('menu adds cached full-name entry',type(click)=='function'); click(); check('menu phrase persisted',test('LF enchant crusader'))
click=nil; menus.MENU_UNIT_PLAYER(nil,root,{name='Learn',surname=secret}); check('restricted surname skipped',click==nil)
click=nil; menus.MENU_UNIT_CHAT_ROSTER(nil,root,{name='Learn',surname='Me'}); check('source-defined chat roster tag registered',type(click)=='function')
click=nil; menus.MENU_UNIT_PLAYER(nil,root,{name=secret,unit='player'}); check('restricted menu skipped',click==nil)
cmd('popup off'); menus.MENU_UNIT_PLAYER(nil,root,{name='Learn',surname='Me'}); check('popup disabled',click==nil); cmd('popup on')
now=1000; menus.MENU_UNIT_PLAYER(nil,root,{name='Learn',surname='Me'}); check('expired menu message ignored',click==nil)
cmd('on'); chat(request,'Say User','Player-say',0,0,'CHAT_MSG_SAY'); chat(request,'Yell User','Player-yell',0,0,'CHAT_MSG_YELL'); check('say and yell work',#invites==6)
local native=C_PartyInfo.InviteUnit; C_PartyInfo.InviteUnit=nil; chat(request,'No API','Player-noapi'); check('missing native API does not crash',#invites==6); C_PartyInfo.InviteUnit=native
behavior='error'; chat(request,'Error Test','Player-error'); check('call error caught',#invites==7 and logs[#logs]:find('call failed',1,true)); behavior='normal'
fire('ADDON_ACTION_BLOCKED','OtherAddon','C_PartyInfo.InviteUnit'); chat(request,'Other Block','Player-other'); check('unrelated block ignored',#invites==8)
behavior='blocked'; chat(request,'Blocked Test','Player-block'); check('own blocked action detected',#invites==9); behavior='normal'; chat(request,'After Block','Player-after'); check('no more native calls after block',#invites==9)
check('status records block',cmd('status'):find('blocked=true',1,true)); cmd('diag'); local found=false; for _,line in ipairs(logs) do if line:find('failed calls=1',1,true) then found=true end end; check('diagnostics record failure',found)
-- Nonmatching workload uses actual event handler, without calling any invite API.
local start=os.clock(); for i=1,10000 do chat('WTS unrelated item '..i,'Load '..i,'Player-load'..i) end
check('10000 unrelated messages no invites',#invites==9)
print(('PASS total=%d; workload CPU seconds=%.4f; runtime=%s'):format(passed,os.clock()-start,_VERSION))
