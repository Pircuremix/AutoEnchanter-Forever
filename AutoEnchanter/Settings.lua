-- Settings.lua: native settings canvas with immediate-save controls.
local _, ns = ...
local UI = {}
ns.Options = UI
local labels = {"Star","Circle","Diamond","Triangle","Moon","Square","Cross","Skull"}
function UI:Init(group, log)
    self.group,self.log=group,log
    if not Settings or type(Settings.RegisterCanvasLayoutCategory)~="function" or
       type(Settings.RegisterAddOnCategory)~="function" then return end
    local ok,err=pcall(function()
        local panel=CreateFrame("Frame")
        self:Build(panel,0,0)
        local category=Settings.RegisterCanvasLayoutCategory(panel,"Auto Enchanter")
        Settings.RegisterAddOnCategory(category)
        self.category=category
    end)
    if not ok then log("Settings panel unavailable; use /ae welcome, message, marker, raid. "..tostring(err)) end
end
function UI:Build(parent,x,y)
    local group=self.group
    local panel=parent
    if x~=0 or y~=0 then
        panel=CreateFrame("Frame",nil,parent); panel:SetSize(620,470); panel:SetPoint("TOPLEFT",parent,"TOPLEFT",x,y)
    end
        local refresh
        local function text(x,y,value,template)
            local fs=panel:CreateFontString(nil,"ARTWORK",template or "GameFontNormal")
            fs:SetPoint("TOPLEFT",panel,"TOPLEFT",x,y); fs:SetText(value); return fs
        end
        local function checkbox(x,y,label,key)
            local b=CreateFrame("CheckButton",nil,panel,"UICheckButtonTemplate")
            b:SetPoint("TOPLEFT",panel,"TOPLEFT",x,y)
            text(x+32,y-7,label,"GameFontHighlight")
            b:SetScript("OnClick",function(self) group:Set(key,self:GetChecked() and true or false) end)
            return b
        end
        text(16,-16,"Auto Enchanter — Customer & Group Settings","GameFontNormalLarge")
        text(16,-46,"Settings are account-wide. New features start off. /ae debug on suppresses live actions.","GameFontHighlightSmall")
        local welcome=checkbox(16,-72,"Send welcome after an addon-invited customer joins","welcomeEnabled")
        text(16,-111,"Welcome message (one line, max 255 bytes)","GameFontNormal")
        local edit=CreateFrame("EditBox",nil,panel,"InputBoxTemplate")
        edit:SetSize(440,26); edit:SetPoint("TOPLEFT",panel,"TOPLEFT",20,-136)
        edit:SetAutoFocus(false); edit:SetMaxLetters(255)
        local note=text(16,-170,"{customer}  {player}  {zone}  |  Channel: automatic PARTY / RAID","GameFontHighlightSmall")
        local save=CreateFrame("Button",nil,panel,"UIPanelButtonTemplate")
        save:SetSize(90,26); save:SetPoint("LEFT",edit,"RIGHT",8,0); save:SetText("Save")
        local function saveMessage()
            local success,reason=group:Set("welcomeMessage",edit:GetText())
            note:SetText(success and "Message saved. Channel: automatic PARTY / RAID." or reason)
            edit:ClearFocus()
        end
        save:SetScript("OnClick",saveMessage)
        edit:SetScript("OnEnterPressed",saveMessage)
        edit:SetScript("OnEscapePressed",function(self) self:SetText(group.db.welcomeMessage); self:ClearFocus() end)
        local marker=checkbox(16,-205,"Mark my character after a customer joins","autoMarkerEnabled")
        text(16,-245,"Choose a marker (existing markers are always preserved).","GameFontHighlightSmall")
        local markerButtons={}
        for i=1,8 do
            local index=i
            local b=CreateFrame("Button",nil,panel,"UIPanelButtonTemplate")
            b:SetSize(114,28); b:SetPoint("TOPLEFT",panel,"TOPLEFT",16+((i-1)%4)*122,-268-math.floor((i-1)/4)*33)
            local icon=b:CreateTexture(nil,"ARTWORK")
            icon:SetSize(18,18); icon:SetPoint("LEFT",b,"LEFT",6,0)
            icon:SetTexture("Interface\\TargetingFrame\\UI-RaidTargetingIcons")
            local col,row=(i-1)%4,math.floor((i-1)/4)
            if type(SetRaidTargetIconTexture)=="function" then SetRaidTargetIconTexture(icon,i)
            else icon:SetTexCoord(col/4,(col+1)/4,row/4,(row+1)/4) end
            b:SetText("    "..labels[i]); markerButtons[i]=b
            b:SetScript("OnClick",function() group:Set("raidMarker",index); refresh() end)
        end
        local raid=checkbox(16,-343,"Automatically convert ordinary parties to raids","autoRaidEnabled")
        text(16,-382,"Convert at this many total players (including yourself).","GameFontHighlightSmall")
        local thresholdButtons={}
        for i=2,5 do
            local count=i
            local b=CreateFrame("Button",nil,panel,"UIPanelButtonTemplate")
            b:SetSize(72,28); b:SetPoint("TOPLEFT",panel,"TOPLEFT",16+(i-2)*82,-406)
            b:SetText(tostring(i)); thresholdButtons[i]=b
            b:SetScript("OnClick",function() group:Set("raidThreshold",count); refresh() end)
        end
        text(16,-448,"Leader only; no instance groups. Conversion may interrupt normal quest progress.","GameFontHighlightSmall")
        refresh=function()
            local d=group.db
            welcome:SetChecked(d.welcomeEnabled); marker:SetChecked(d.autoMarkerEnabled); raid:SetChecked(d.autoRaidEnabled)
            for i,b in ipairs(markerButtons) do b:SetText((i==d.raidMarker and "*   " or "    ")..labels[i]) end
            for i,b in pairs(thresholdButtons) do b:SetText((i==d.raidThreshold and "* " or "")..i) end
        end
        panel:SetScript("OnShow",function() refresh(); edit:SetText(group.db.welcomeMessage); note:SetText("{customer}  {player}  {zone}  |  Channel: automatic PARTY / RAID") end)
        refresh(); edit:SetText(group.db.welcomeMessage)
end
function UI:Open()
    if self.category and Settings and type(Settings.OpenToCategory)=="function" then
        local ok=pcall(function() Settings.OpenToCategory(self.category:GetID()) end)
        if ok then return end
    end
    self.log("Settings unavailable. Use /ae welcome on|off; /ae message <text>; /ae marker off|on|1-8; /ae raid off|on|2-5.")
end
