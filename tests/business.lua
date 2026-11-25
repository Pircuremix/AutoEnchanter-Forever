-- Business regression: real ledger, trade, dashboard and minimap modules with mocked client.
local count=0
local function check(n,v) assert(v,n); count=count+1; print("PASS "..n) end
local epoch,own,roster,timers,secret,partner,incoming,outgoing,playerItems,targetItems,currency,logs
function GetServerTime() return epoch end
function GetTime() return epoch end
date=os.date; time=os.time
function issecretvalue(v) return rawequal(v,secret) end
function UnitGUID(unit) if unit=="player" then return own elseif unit=="npc" then return partner end end
function UnitFullName() return "Sleepy","Smith" end
C_PartyInfo={IsGUIDInGroup=function(guid) return roster[guid] or false end}
C_Timer={After=function(delay,cb) timers[#timers+1]={delay=delay,cb=cb} end}
ERR_DECLINE_GROUP_S="%s declines your group invitation."
ERR_TRADE_COMPLETE="Trade complete."; ERR_TRADE_CANCELLED="Trade canceled."
function GetTargetTradeMoney() return incoming end
function GetPlayerTradeMoney() return outgoing end
function GetPlayerTradeItemInfo(i) local x=playerItems[i] or {}; return x.name,x.name and 123,x.name and 1,nil,x.enchant,nil,nil,x.name and 42 end
function GetTradeTargetItemInfo(i) local x=targetItems[i] or {}; return x.name,x.name and 123,x.name and 1,nil,true,x.enchant,x.name and 42 end
GetTradePlayerItemInfo=GetPlayerTradeItemInfo; GetTradeTargetItemInfo=GetTradeTargetItemInfo
function GetTargetTradeCurrency() return currency end
local ns={}
for _,f in ipairs({"Database.lua","Trade.lua","Dashboard.lua","Minimap.lua"}) do assert(loadfile("AutoEnchanter/"..f))("AutoEnchanter",ns) end
local D,T,U,M=ns.Database,ns.Trade,ns.Dashboard,ns.Minimap
local db
local function reset(saved)
    epoch,own,roster,timers,secret,partner=1700000000,"self",{}, {},{},"a"
    incoming,outgoing,playerItems,targetItems,currency,logs=0,0,{},{},0,{}
    db=saved or {enabled=true,debug=false,whitelist={}}
    D:Init(db,function(s) logs[#logs+1]=s end); T:Init(D,function(s) logs[#logs+1]=s end)
    D:OnRoster()
end
local function add(guid,name,ok) return D:Record(name or guid,guid,"pending",ok~=false) end
local function join(guid) roster[guid]=true; D:OnRoster() end
local function row(guid) for _,r in ipairs(D:Rows()) do if r.guid==guid then return r end end end
local function accept() T:Event("TRADE_ACCEPT_UPDATE",1,1) end
local function finish() T:Event("UI_INFO_MESSAGE",1,ERR_TRADE_COMPLETE) end
local function start(guid) partner=guid or "a"; T:Event("TRADE_SHOW") end
local function pay(gold) incoming=gold*10000; outgoing=0; playerItems={}; targetItems={}; currency=0; start(); accept(); finish() end
reset(); local a=add("a","Alice Stone")
check("full date and unique invite id",a.localTime==os.date("%Y-%m-%d %H:%M:%S",epoch) and a.id==1)
check("pending not declined",row("a").pending==1 and row("a").declined==0)
join("a"); D:OnRoster(); check("accept once",a.status=="accepted" and row("a").accepted==1)
check("records independent of welcome settings",D:Active("a")==a)
local b=add("b","Bob Oak"); D:Decline("Bob Oak declines your group invitation.")
check("localized decline",b.status=="declined" and row("b").declined==1)
local c=add("c"); epoch=epoch+120; D:Expire(); check("expiry included in declines",c.status=="expired" and row("c").declined==1)
local x=add("d"); epoch=epoch+8; local y=add("d"); join("d")
check("overlap accepted once, prior superseded",x.status=="superseded" and y.status=="accepted" and row("d").accepted==1 and row("d").other==1)
local f=D:Record("Failed","failed","failed",false); check("failure excluded from declined",f.status=="failed" and row("failed").declined==0)
local un=add("u","Uncertain",false); check("unverified prior membership",un.status=="unverified")
local unknown=D:Record("Unknown",nil,"pending",true); check("no GUID never accepted",unknown.status=="unverified")
db.debug=true; check("debug no fabricated visit",add("sim")==nil); db.debug=false
db.enabled=false; check("off no new visit",add("off")==nil); db.enabled=true
local p=add("p"); local saved=db; D:Init(saved,function() end); roster.p=true; D:OnRoster()
check("reload reconciles pending",p.status=="accepted")
check("reload keeps active accepted",D:Active("a")==a)
roster.a=nil; D:OnRoster(); check("leaving closes visit",a.closed~=nil and D:Active("a")==nil)
local nextA=add("a","Alice Stone"); join("a"); check("repeat visit",row("a").accepted==2 and D:Active("a")==nextA)
local q=add("q","Same Name"); local z=add("z","Same Name"); D:Decline("Same Name declines your group invitation.")
check("ambiguous name decline ignored",q.status=="pending" and z.status=="pending")
D:Delete("q"); check("delete removes pending and row",not row("q") and not D:HasPending("q"))
reset(); a=add("a"); join("a")
pay(10); finish(); check("completed gold only counted once",a.tipCopper==100000 and #a.trades==1)
incoming=50000; targetItems={[7]={name="Boots",enchant="Stamina"}}; start(); accept(); finish()
check("gold plus outgoing enchant service",a.tipCopper==150000 and a.enchants==1)
incoming=0; targetItems={[7]={name="Gloves",enchant="Agility"}}; start(); accept(); finish()
check("unpaid enchant counts",a.enchants==2 and a.tipCopper==150000)
pay(3); check("separate payment",a.tipCopper==180000 and a.enchants==2 and row("a").avg==90000)
incoming=10000; playerItems={[1]={name="Dust"}}; targetItems={}; start(); accept(); finish(); check("outgoing item excludes tip",a.tipCopper==180000)
playerItems={}; targetItems={[1]={name="Dust"}}; start(); accept(); finish(); check("incoming mats excludes tip",a.tipCopper==180000)
targetItems={}; outgoing=1; start(); accept(); finish(); check("outgoing money excludes tip",a.tipCopper==180000)
outgoing=0; currency=1; start(); accept(); finish(); check("currency excludes tip",a.tipCopper==180000); currency=0
playerItems={[7]={name="Own boots",enchant="Stamina"}}; start(); accept(); finish(); check("incoming enchant excludes tip",a.tipCopper==180000 and a.enchants==2); playerItems={}
start(); accept(); T:Event("UI_ERROR_MESSAGE",1,ERR_TRADE_CANCELLED); finish(); check("canceled trade no record",a.tipCopper==180000)
start(); accept(); T:Event("TRADE_CLOSED"); finish(); check("close before explicit completion",a.tipCopper==190000)
start(); accept(); T:Event("TRADE_CLOSED"); timers[#timers].cb(); finish(); check("closed without proof unverified",a.tipCopper==190000 and a.unverified==1)
start(); accept(); incoming=20000; T:Event("TRADE_MONEY_CHANGED"); finish(); check("changed offer invalidates final acceptance",a.tipCopper==190000 and a.unverified==2)
incoming=secret; start(); accept(); finish(); check("secret money fails closed",a.tipCopper==190000 and a.unverified==3)
incoming=10000; start("unrelated"); accept(); finish(); check("untracked trade ignored",a.tipCopper==190000)
start(); T:Event("ENCHANT_SPELL_COMPLETED",true); T:Event("UNIT_SPELLCAST_SUCCEEDED","player","cast",1); check("cast alone no enchant",a.enchants==2); T:Cancel()
incoming=0; targetItems={[7]={name="Boots",enchant="Stamina"}}; start(); accept(); finish(); check("each completed enchant slot counts once",a.enchants==3)
local b=add("b","Beta"); join("b"); incoming=90000; targetItems={}; start("b"); accept(); finish(); check("second customer independently attributed",b.tipCopper==90000 and a.tipCopper==190000)
-- Model-level UI sorting, filtering, export, weighted totals and destructive confirmation.
U:Init(db,D,{Open=function() end},function() end)
U.sort="tip"; U.desc=true; local rows=U:Rows(); check("sort tips descending",rows[1].guid=="a")
U.sort="name"; U.desc=false; U.query="beta"; check("case-insensitive customer search",#U:Rows()==1 and U:Rows()[1].guid=="b")
check("TSV includes filtered record",U:Export():find("Beta",1,true)~=nil and not U:Export():find("Alice",1,true))
U.query=""; local s=U:Summary(U:Rows()); check("overview weighted totals",s.tip==280000 and s.enchants==3 and s.accepted==2)
U:Confirm("b"); check("delete requires confirmation",row("b")~=nil); U:Confirm("b"); check("confirmed delete",not row("b"))
-- Minimap dispatch and two-option menu.
local toggles,opens,shift,buttons=0,0,false,{}
SlashCmdList={AUTOENCHANTER=function(cmd) db.enabled=cmd=="on"; toggles=toggles+1 end}
function IsShiftKeyDown() return shift end
local dash={Toggle=function() opens=opens+1 end,Open=function() opens=opens+1 end,Refresh=function() end}
MenuUtil={CreateContextMenu=function(_,cb) buttons={}; cb(nil,{CreateButton=function(_,name,fn) buttons[#buttons+1]={name,fn} end}) end}
M:Init(db,dash,function() end); M.button={}
M:Click("LeftButton"); check("minimap left opens",opens==1)
shift=true; M:Click("LeftButton"); check("shift left toggles off",not db.enabled and toggles==1)
M:Click("RightButton"); check("two dynamic menu buttons",#buttons==2 and buttons[1][1]=="Turn AutoEnchanter ON")
buttons[1][2](); check("menu toggles on",db.enabled)
M:Click("RightButton"); check("menu now offers off",buttons[1][1]=="Turn AutoEnchanter OFF"); buttons[2][2](); check("menu opens config database",opens==2)
-- Future schema is preserved, not reset.
local future={enabled=true,debug=false,customerLedger={schema=99,customers={},nextID=1}}
reset(future); check("future schema preserved read-only",not D.ready and future.customerLedger.schema==99)
print(("PASS business total=%d; runtime=%s"):format(count,_VERSION))
