-- Minimap.lua: standard named button, discoverable by EllesmereUI.
local _,ns=...
local M={}; ns.Minimap=M
function M:Init(db,dashboard,log)
    self.db,self.dashboard,self.log=db,dashboard,log
    if type(db.minimapHidden)~="boolean" then db.minimapHidden=false end
    if not Minimap then return end
    local ok,err=pcall(function()
        local b=CreateFrame("Button","AutoEnchanterMinimapButton",Minimap)
        self.button=b
        b:SetSize(30,30); b:SetPoint("TOPLEFT",Minimap,"TOPLEFT",-3,-30); b:SetFrameLevel(Minimap:GetFrameLevel()+5)
        b:RegisterForClicks("LeftButtonUp","RightButtonUp")
        local icon=b:CreateTexture(nil,"ARTWORK"); icon:SetPoint("CENTER"); icon:SetSize(24,24); icon:SetTexture("Interface\\AddOns\\AutoEnchanter\\AutoEnchanterIcon"); icon:SetTexCoord(.08,.92,.08,.92)
        local border=b:CreateTexture(nil,"OVERLAY"); border:SetAllPoints(); border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
        self.dot=b:CreateTexture(nil,"OVERLAY"); self.dot:SetSize(6,6); self.dot:SetPoint("BOTTOMRIGHT",-3,3)
        b:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")
        b:SetScript("OnClick",function(_,mouse) self:Click(mouse) end)
        b:SetScript("OnEnter",function(frame)
            if not GameTooltip then return end
            GameTooltip:SetOwner(frame,"ANCHOR_LEFT"); GameTooltip:SetText("AutoEnchanter")
            GameTooltip:AddLine(db.enabled and "AE ON" or "AE OFF",db.enabled and .3 or 1,db.enabled and 1 or .3,.3)
            GameTooltip:AddLine("Left: dashboard | Shift-left: toggle | Right: menu",1,1,1); GameTooltip:Show()
        end)
        b:SetScript("OnLeave",function() if GameTooltip then GameTooltip:Hide() end end)
        self:Refresh(); self:SetHidden(db.minimapHidden)
    end)
    if not ok then log("Minimap button unavailable: "..tostring(err)) end
end
function M:Refresh()
    if self.dot then self.dot:SetColorTexture(self.db.enabled and .2 or .9,self.db.enabled and .9 or .15,.2,1) end
end
function M:SetHidden(hide)
    self.db.minimapHidden=not not hide
    if self.button then self.button:SetShown(not hide) end
end
function M:ToggleAE() SlashCmdList.AUTOENCHANTER(self.db.enabled and "off" or "on"); self:Refresh(); self.dashboard:Refresh() end
function M:Click(mouse)
    if mouse=="LeftButton" then
        if IsShiftKeyDown and IsShiftKeyDown() then self:ToggleAE() else self.dashboard:Toggle() end
    elseif mouse=="RightButton" then
        if MenuUtil and type(MenuUtil.CreateContextMenu)=="function" then
            MenuUtil.CreateContextMenu(self.button,function(_,root)
                root:CreateButton(self.db.enabled and "Turn AutoEnchanter OFF" or "Turn AutoEnchanter ON",function() self:ToggleAE() end)
                root:CreateButton("Open configuration / database",function() self.dashboard:Open() end)
            end)
        else
            if not self.menu then
                local f=CreateFrame("Frame",nil,UIParent); self.menu=f; f:SetSize(235,61); f:SetFrameStrata("DIALOG"); f:SetClampedToScreen(true)
                local bg=f:CreateTexture(nil,"BACKGROUND"); bg:SetAllPoints(); bg:SetColorTexture(.1,.1,.14,.98)
                self.toggle=CreateFrame("Button",nil,f,"UIPanelButtonTemplate"); self.toggle:SetSize(225,25); self.toggle:SetPoint("TOP",0,-3); self.toggle:SetScript("OnClick",function() f:Hide(); self:ToggleAE() end)
                local open=CreateFrame("Button",nil,f,"UIPanelButtonTemplate"); open:SetSize(225,25); open:SetPoint("BOTTOM",0,3); open:SetText("Open configuration / database"); open:SetScript("OnClick",function() f:Hide(); self.dashboard:Open() end)
                f:Hide()
            end
            self.menu:ClearAllPoints(); self.menu:SetPoint("TOPRIGHT",self.button,"BOTTOMLEFT"); self.toggle:SetText(self.db.enabled and "Turn AutoEnchanter OFF" or "Turn AutoEnchanter ON"); self.menu:SetShown(not self.menu:IsShown())
        end
    end
end
