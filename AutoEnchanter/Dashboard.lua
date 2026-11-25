-- Dashboard.lua: paginated, sortable customer ledger and configuration.
local _,ns=...
local D={}; ns.Dashboard=D
local COLS={{"Character","name",220},{"Accepted","accepted",75},{"Declined","declined",75},{"Pending","pending",68},{"Tips","tip",100},{"Items","enchants",60},{"Avg/item","avg",100},{"Accept %","rate",80},{"Last invite","last",145}}
local function gold(n)
    if not n or n<0 then return "—" end
    return ("%0.2fg"):format(n/10000)
end
local function rate(n) return n and n>=0 and ("%0.1f%%"):format(n*100) or "—" end
local function fmt(v) return tostring(v or "") end
local function tint(f,r,g,b,a)
    local t=f:CreateTexture(nil,"BACKGROUND"); t:SetAllPoints(f); t:SetColorTexture(r,g,b,a or 1); return t
end
local function label(f,x,y,w,value,style)
    local s=f:CreateFontString(nil,"OVERLAY",style or "GameFontHighlightSmall")
    s:SetPoint("TOPLEFT",f,"TOPLEFT",x,y); s:SetWidth(w); s:SetJustifyH("LEFT"); s:SetText(value or ""); return s
end
local function button(f,x,y,w,title,callback)
    local b=CreateFrame("Button",nil,f,"UIPanelButtonTemplate")
    b:SetSize(w,25); b:SetPoint("TOPLEFT",f,"TOPLEFT",x,y); b:SetText(title); b:SetScript("OnClick",callback); return b
end
local function edit(f,x,y,w)
    local b=CreateFrame("EditBox",nil,f,"InputBoxTemplate")
    b:SetSize(w,25); b:SetPoint("TOPLEFT",f,"TOPLEFT",x,y); b:SetAutoFocus(false); return b
end
function D:Init(db,ledger,options,log)
    self.db,self.ledger,self.options,self.log=db,ledger,options,log
    self.tab,self.sort,self.desc,self.page,self.visitPage,self.period,self.filter="Customers","tip",true,1,1,0,"all"
    self.query=""; self.selected=nil; self.confirm=nil
    if type(db.dashboardPosition)~="table" then db.dashboardPosition={} end
end
function D:Rows()
    local now=self.ledger:Now()
    local since
    if now and self.period==-1 then
        local ok,t=pcall(date,"*t",now)
        if ok and type(t)=="table" then t.hour,t.min,t.sec=0,0,0; since=time(t) end
    elseif now and self.period>0 then since=now-self.period*86400 end
    local rows=self.ledger:Rows(since)
    local out={}
    for _,r in ipairs(rows) do
        if r.name:lower():find(self.query:lower(),1,true) and
            (self.filter=="all" or self.filter=="accepted" and r.accepted>0 or self.filter=="repeat" and r.accepted>1 or self.filter=="never" and r.accepted==0) then out[#out+1]=r end
    end
    local k,desc=self.sort,self.desc
    table.sort(out,function(a,b)
        local x,y=a[k],b[k]
        if x==y then return a.guid<b.guid end
        if desc then return x>y end
        return x<y
    end)
    return out
end
function D:Select(guid) self.selected=guid; self.visitPage=1; self.confirm=nil; self:Refresh() end
function D:Sort(k) if self.sort==k then self.desc=not self.desc else self.sort=k; self.desc=k~="name" end; self.page=1; self:Refresh() end
function D:Summary(rows)
    local s={tip=0,enchants=0,accepted=0,declined=0,pending=0,other=0,repeatCustomers=0}
    for _,r in ipairs(rows) do
        for _,k in ipairs({"tip","enchants","accepted","declined","pending","other"}) do s[k]=s[k]+r[k] end
        if r.accepted>1 then s.repeatCustomers=s.repeatCustomers+1 end
    end
    return s
end
function D:Export()
    local rows=self:Rows()
    local lines={"Character\tInvite ID\tLocal invite time\tEnchanter\tOutcome\tItems\tTip copper\tAverage copper per item\tUnverified trades"}
    local function field(v) return fmt(v):gsub("[\t\r\n]"," ") end
    for _,r in ipairs(rows) do
        for _,v in ipairs(r.visits) do
            lines[#lines+1]=table.concat({field(v.name or r.name),field(v.id),field(v.localTime),field(v.enchanter),field(v.status),field(v.enchants),field(v.tipCopper),field(v.enchants>0 and v.tipCopper/v.enchants or ""),field(v.unverified)},"\t")
        end
    end
    return table.concat(lines,"\n")
end
function D:Confirm(action)
    -- Explicit two-click confirmation, reset whenever selection/tab changes.
    if self.confirm~=action then self.confirm=action; self:Refresh(); return end
    if action=="reset" then self.ledger:Reset() else self.ledger:Delete(action) end
    self.selected=nil; self.confirm=nil; self:Refresh()
end
function D:Build()
    local f=CreateFrame("Frame","AutoEnchanterDashboard",UIParent)
    self.frame=f
    f:SetSize(1020,690); f:SetPoint("CENTER"); f:SetFrameStrata("DIALOG")
    f:SetMovable(true); f:SetClampedToScreen(true); f:EnableMouse(true)
    -- Scale to fit smaller UI canvases; fixed logical grid keeps rows aligned.
    if UIParent and UIParent.GetWidth and UIParent.GetHeight then
        f:SetScale(math.min(1,UIParent:GetWidth()/1040,UIParent:GetHeight()/710))
    end
    local pos=self.db.dashboardPosition
    if type(pos.x)=="number" and type(pos.y)=="number" then f:ClearAllPoints(); f:SetPoint("CENTER",UIParent,"CENTER",pos.x,pos.y) end
    tint(f,.075,.08,.10,.99)
    local header=CreateFrame("Frame",nil,f); header:SetSize(1020,54); header:SetPoint("TOPLEFT"); tint(header,.12,.12,.16,1)
    header:EnableMouse(true); header:RegisterForDrag("LeftButton")
    header:SetScript("OnDragStart",function() f:StartMoving() end)
    header:SetScript("OnDragStop",function()
        f:StopMovingOrSizing()
        local x,y=f:GetCenter(); local px,py=UIParent:GetCenter()
        if x and y and px and py then
            local scale=f:GetEffectiveScale()/UIParent:GetEffectiveScale()
            pos.x,pos.y=x-px/scale,y-py/scale
        end
    end)
    label(header,18,-12,500,"AutoEnchanter  |  Business Manager","GameFontNormalLarge")
    self.status=button(header,820,-14,130,"AE ON",function() SlashCmdList.AUTOENCHANTER(self.db.enabled and "off" or "on"); self:Refresh() end)
    button(header,967,-14,38,"X",function() f:Hide() end)
    self.tabs={}
    for i,name in ipairs({"Overview","Customers","Settings"}) do
        self.tabs[name]=button(f,18+(i-1)*130,-65,124,name,function() self.tab=name; self.confirm=nil; self:Refresh() end)
    end
    self.summary=label(f,18,-103,980,"","GameFontHighlight")
    self.customerPanel=CreateFrame("Frame",nil,f); self.customerPanel:SetAllPoints(f)
    local p=self.customerPanel
    self.search=edit(p,20,-132,230); self.search:SetMaxLetters(80)
    self.search:SetScript("OnTextChanged",function(e) self.query=e:GetText(); self.page=1; self:Refresh() end)
    self.search:SetScript("OnEscapePressed",function(e) e:ClearFocus() end)
    self.periodButton=button(p,264,-132,125,"Lifetime",function()
        local values={0,-1,7,30}; local i=1
        for j,v in ipairs(values) do if self.period==v then i=j end end
        self.period=values[i%#values+1]; self.page=1; self.visitPage=1; self:Refresh()
    end)
    self.filterButton=button(p,397,-132,138,"All customers",function()
        local vals={"all","accepted","repeat","never"}; local i=1
        for j,v in ipairs(vals) do if self.filter==v then i=j end end
        self.filter=vals[i%#vals+1]; self.page=1; self:Refresh()
    end)
    button(p,545,-132,112,"Export TSV",function()
        self.exportBox:SetText(self:Export()); self.exportPanel:Show(); self.exportBox:HighlightText(); self.exportBox:SetFocus()
    end)
    self.deleteButton=button(p,665,-132,160,"Delete selected",function() if self.selected then self:Confirm(self.selected) end end)
    self.resetButton=button(p,835,-132,165,"Reset database",function() self:Confirm("reset") end)
    self.headers={}; local x=18
    for _,col in ipairs(COLS) do
        local key=col[2]
        self.headers[key]=button(p,x,-170,col[3]-3,col[1],function() self:Sort(key) end); x=x+col[3]
    end
    self.rows={}
    for i=1,8 do
        local row=CreateFrame("Button",nil,p); row:SetSize(982,23); row:SetPoint("TOPLEFT",p,"TOPLEFT",18,-200-(i-1)*24)
        row.bg=tint(row,.13,.14,.18,1); row.cells={}; x=4
        for j,col in ipairs(COLS) do row.cells[j]=label(row,x,-4,col[3]-7,""); x=x+col[3] end
        row:SetScript("OnClick",function(b) if b.guid then self:Select(b.guid) end end)
        self.rows[i]=row
    end
    button(p,18,-397,65,"Prev",function() self.page=math.max(1,self.page-1); self:Refresh() end)
    self.pageLabel=label(p,90,-404,340,"")
    button(p,415,-397,65,"Next",function() self.page=self.page+1; self:Refresh() end)
    self.detail=label(p,18,-432,980,"Select a customer","GameFontNormal")
    self.historyHeader=label(p,18,-460,980,"Local invitation time                    Outcome                 Enchanter                 Items          Tips          Avg/item       Review")
    self.history={}
    for i=1,6 do self.history[i]=label(p,20,-481-(i-1)*24,980,"","GameFontHighlightSmall") end
    button(p,18,-631,65,"Prev",function() self.visitPage=math.max(1,self.visitPage-1); self:Refresh() end)
    self.visitLabel=label(p,90,-638,340,"")
    button(p,415,-631,65,"Next",function() self.visitPage=self.visitPage+1; self:Refresh() end)
    self.overview=CreateFrame("Frame",nil,f); self.overview:SetAllPoints(f)
    self.overviewText=label(self.overview,24,-150,955,"","GameFontHighlight")
    self.overviewText:SetSpacing(12)
    self.config=CreateFrame("Frame",nil,f); self.config:SetAllPoints(f)
    label(self.config,24,-145,950,"Customer automation, whitelist and minimap","GameFontNormalLarge")
    -- Reuse the existing native settings controls through a dedicated panel builder.
    if self.options.Build then self.options:Build(self.config,24,-170) end
    button(self.config,660,-181,310,"Open Blizzard addon settings",function() self.options:Open() end)
    button(self.config,660,-220,310,"Toggle minimap button",function() if ns.Minimap then ns.Minimap:SetHidden(not self.db.minimapHidden) end; self:Refresh() end)
    self.configState=label(self.config,660,-260,320,"")
    button(self.config,660,-285,310,"Toggle debug mode",function() SlashCmdList.AUTOENCHANTER("debug"); self:Refresh() end)
    self.whitelistText=label(self.config,660,-330,320,"Whitelist (first 10 entries)")
    local add=edit(self.config,660,-570,235)
    button(self.config,900,-570,70,"Add",function() SlashCmdList.AUTOENCHANTER("add "..add:GetText()); add:SetText(""); self:Refresh() end)
    local rem=edit(self.config,660,-604,235)
    button(self.config,900,-604,70,"Remove",function() SlashCmdList.AUTOENCHANTER("remove "..rem:GetText()); rem:SetText(""); self:Refresh() end)
    self.exportPanel=CreateFrame("Frame",nil,f); self.exportPanel:SetSize(900,510); self.exportPanel:SetPoint("CENTER"); self.exportPanel:SetFrameLevel(f:GetFrameLevel()+30); tint(self.exportPanel,.08,.09,.12,1); self.exportPanel:EnableMouse(true)
    label(self.exportPanel,18,-18,840,"Export (selected filters) — Ctrl+A, Ctrl+C; data stays local","GameFontNormal")
    button(self.exportPanel,810,-12,70,"Close",function() self.exportPanel:Hide() end)
    local scroll=CreateFrame("ScrollFrame",nil,self.exportPanel,"UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT",18,-50); scroll:SetSize(840,430)
    self.exportBox=CreateFrame("EditBox",nil,scroll); self.exportBox:SetMultiLine(true); self.exportBox:SetAutoFocus(false); self.exportBox:SetFontObject(ChatFontNormal); self.exportBox:SetWidth(820); self.exportBox:SetHeight(430); scroll:SetScrollChild(self.exportBox)
    self.exportPanel:Hide()
    f:SetScript("OnShow",function() self:Refresh() end)
    f:SetScript("OnHide",function() self.confirm=nil; self.exportPanel:Hide() end)
    if UISpecialFrames then UISpecialFrames[#UISpecialFrames+1]="AutoEnchanterDashboard" end
    f:Hide()
end
function D:Refresh()
    if not self.frame or not self.frame:IsShown() then return end
    self.status:SetText(self.db.enabled and "AE ON" or "AE OFF")
    self.customerPanel:SetShown(self.tab=="Customers"); self.overview:SetShown(self.tab=="Overview"); self.config:SetShown(self.tab=="Settings")
    for name,b in pairs(self.tabs) do b:SetText((self.tab==name and "* " or "")..name) end
    local rows=self:Rows(); local s=self:Summary(rows)
    self.summary:SetText(("%d customers   |   %s tips   |   %d items   |   %s / item   |   %d accepted / %d declined   |   %d pending"):format(#rows,gold(s.tip),s.enchants,gold(s.enchants>0 and s.tip/s.enchants or -1),s.accepted,s.declined,s.pending))
    self.overviewText:SetText(("Lifetime / selected filters\n\nTotal tips: %s\nItems enchanted: %d\nAverage per item: %s\nInvite acceptance: %s\nRepeat customers: %d\nPending invitations: %d\nFailed / ambiguous / superseded: %d\n\nTrade evidence is conservative. Unverified trades are excluded."):format(gold(s.tip),s.enchants,gold(s.enchants>0 and s.tip/s.enchants or -1),rate(s.accepted+s.declined>0 and s.accepted/(s.accepted+s.declined) or -1),s.repeatCustomers,s.pending,s.other))
    self.periodButton:SetText(({[0]="Lifetime",[-1]="Today",[7]="Last 7 days",[30]="Last 30 days"})[self.period])
    self.filterButton:SetText(({all="All customers",accepted="Accepted",["repeat"]="Repeat",never="Never accepted"})[self.filter])
    for _,col in ipairs(COLS) do self.headers[col[2]]:SetText(col[1]..(self.sort==col[2] and (self.desc and " v" or " ^") or "")) end
    local pages=math.max(1,math.ceil(#rows/8)); self.page=math.min(self.page,pages)
    self.pageLabel:SetText(("Page %d / %d · %d customers"):format(self.page,pages,#rows))
    local selected
    for _,r in ipairs(rows) do if r.guid==self.selected then selected=r; break end end
    for i,row in ipairs(self.rows) do
        local r=rows[(self.page-1)*8+i]
        row:SetShown(r~=nil); row.guid=r and r.guid
        if r then
            row.bg:SetColorTexture(r.guid==self.selected and .27 or .13,.14,.18,1)
            local vals={r.name,r.accepted,r.declined,r.pending,gold(r.tip),r.enchants,gold(r.avg),rate(r.rate),self.ledger:Stamp(r.last)}
            for j,v in ipairs(vals) do row.cells[j]:SetText(fmt(v)); row.cells[j]:SetTextColor(j==2 and .35 or 1,j==3 and .45 or 1,(j==5 or j==7) and .45 or 1) end
        end
    end
    self.deleteButton:SetText(self.confirm==self.selected and self.selected and "Confirm delete" or "Delete selected")
    self.resetButton:SetText(self.confirm=="reset" and "Confirm RESET" or "Reset database")
    local visits={}
    if selected then
        self.detail:SetText(("%s  |  %d invites  |  %s tips  |  %d items"):format(selected.name,#selected.visits,gold(selected.tip),selected.enchants))
        for _,v in ipairs(selected.visits) do visits[#visits+1]=v end
        table.sort(visits,function(a,b) return a.id>b.id end)
    else self.detail:SetText("Select a customer to view individual invitations") end
    local vp=math.max(1,math.ceil(#visits/6)); self.visitPage=math.min(self.visitPage,vp)
    self.visitLabel:SetText(("History %d / %d"):format(self.visitPage,vp))
    for i,fs in ipairs(self.history) do
        local v=visits[(self.visitPage-1)*6+i]
        fs:SetText(v and ("%s    |    %s    |    %s    |    %d items    |    %s    |    %s    |    %d unverified"):format(v.localTime or self.ledger:Stamp(v.invited),v.status,v.enchanter or "?",v.enchants or 0,gold(v.tipCopper),gold(v.enchants>0 and v.tipCopper/v.enchants or -1),v.unverified or 0) or "")
    end
    self.configState:SetText(("Minimap: %s\nDebug: %s"):format(self.db.minimapHidden and "hidden" or "shown",self.db.debug and "on" or "off"))
    local lines={"Whitelist (first 10 entries; /ae list for all)"}
    for i=1,math.min(10,#self.db.whitelist) do lines[#lines+1]=i..". "..self.db.whitelist[i] end
    self.whitelistText:SetText(table.concat(lines,"\n"))
end
function D:Open(tab)
    if tab then self.tab=tab end
    if not self.frame then
        local ok,err=pcall(function() self:Build() end)
        if not ok then if self.frame then self.frame:Hide(); self.frame=nil end; self.log("Dashboard unavailable: "..tostring(err)); self.options:Open(); return end
    end
    self.frame:Show(); self:Refresh()
end
function D:Toggle() if self.frame and self.frame:IsShown() then self.frame:Hide() else self:Open() end end
