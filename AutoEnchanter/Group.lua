-- Group.lua: customer acceptance and optional group automation.
-- Private addon namespace; no saved session state and no polling.
local _, ns = ...
local Group = {}
ns.Group = Group
local TTL, LIMIT, CONVERT_WAIT = 120, 128, 5
local DEFAULT_MESSAGE = "Thanks for choosing me for your enchant!"
local function readable(v)
    return not (issecretvalue and issecretvalue(v))
end
local function safe(fn, ...)
    if type(fn) ~= "function" then return nil, false end
    local ok, value = pcall(fn, ...)
    if not ok or not readable(value) then return nil, false end
    return value, true
end
local function integer(v, lo, hi)
    return type(v) == "number" and v % 1 == 0 and v >= lo and v <= hi
end
local function validMessage(v)
    return type(v) == "string" and #v <= 255 and not v:find("[%z\1-\31\127]")
end
function Group:Init(db, log)
    self.db, self.log = db, log
    for _, k in ipairs({"welcomeEnabled", "autoMarkerEnabled", "autoRaidEnabled"}) do
        if type(db[k]) ~= "boolean" then db[k] = false end
    end
    if not validMessage(db.welcomeMessage) then db.welcomeMessage = DEFAULT_MESSAGE end
    if not integer(db.raidMarker, 1, 8) then db.raidMarker = 1 end
    if not integer(db.raidThreshold, 2, 5) then db.raidThreshold = 3 end
    self.pending, self.joined = {}, {}
    self.latch, self.simLatch, self.waiting, self.generation = false, false, false, 0
    self.chatBlocked, self.markerBlocked, self.raidBlocked = false, false, false
    self.stats = {tracked=0, accepted=0, expired=0, welcomes=0, chatSkipped=0,
        marks=0, markerSkipped=0, conversions=0, raidConfirmed=0, raidSimulated=0}
end
function Group:CancelWait()
    self.waiting = false
    self.generation = self.generation + 1
end
function Group:ClearPending()
    self.pending, self.joined = {}, {}
    self:CancelWait()
end
function Group:ConfigChanged()
    if not self.db.enabled or self.db.debug or
       not (self.db.welcomeEnabled or self.db.autoMarkerEnabled) then
        self.pending, self.joined = {}, {}
    end
    if not self.db.enabled or not self.db.autoRaidEnabled or self.db.debug then
        self:CancelWait()
    end
    if not self.db.debug then self.simLatch = false end
end
function Group:Set(key, value)
    if key == "welcomeMessage" then
        if not validMessage(value) then return false, "Message must be one line, at most 255 bytes." end
    elseif key == "raidMarker" then
        if not integer(value,1,8) then return false, "Choose marker 1-8." end
    elseif key == "raidThreshold" then
        if not integer(value,2,5) then return false, "Choose 2-5 total players." end
    elseif key == "welcomeEnabled" or key == "autoMarkerEnabled" or key == "autoRaidEnabled" then
        if type(value) ~= "boolean" then return false, "Expected on or off." end
    else return false, "Unknown setting." end
    self.db[key] = value
    self:ConfigChanged()
    return true
end
function Group:Prune(now)
    for guid, entry in pairs(self.pending) do
        if now >= entry.expires then
            self.pending[guid] = nil
            self.stats.expired = self.stats.expired + 1
        end
    end
end
function Group:TrackInvite(name, guid)
    local db = self.db
    if not db or not db.enabled or db.debug or not (db.welcomeEnabled or db.autoMarkerEnabled) then return end
    if not readable(guid) or type(guid) ~= "string" or guid == "" then return end
    local now = GetTime()
    self:Prune(now)
    if not self.pending[guid] then
        local n = 0
        for _ in pairs(self.pending) do n = n + 1 end
        if n >= LIMIT then return end
        self.stats.tracked = self.stats.tracked + 1
    end
    self.pending[guid] = {name=name, expires=now+TTL}
    -- A native call can theoretically trigger roster events synchronously.
    -- Reconcile after recording only if membership is already observable.
    local member = safe(C_PartyInfo and C_PartyInfo.IsGUIDInGroup, guid)
    if member == true then self:OnRoster() end
end
-- Ordinary home groups only; never use INSTANCE_CHAT or convert instance groups.
local function groupState()
    if LE_PARTY_CATEGORY_INSTANCE == nil then return nil end
    local instance, instanceOK = safe(IsInGroup, LE_PARTY_CATEGORY_INSTANCE)
    if not instanceOK or instance ~= false then return nil end
    local grouped, groupOK = safe(IsInGroup)
    if not groupOK then return nil end
    if grouped == false then return {count=0, units={}, members={}} end
    if grouped ~= true then return nil end
    local raid, raidOK = safe(IsInRaid)
    local count, countOK = safe(GetNumGroupMembers)
    if not raidOK or type(raid) ~= "boolean" or not countOK or not integer(count, 2, raid and 40 or 5) then return nil end
    local units, members = {}, {}
    if raid then
        for i=1,count do units[#units+1] = "raid"..i end
    else
        units[1] = "player"
        for i=1,count-1 do units[#units+1] = "party"..i end
    end
    local selfGUID, selfOK = safe(UnitGUID, "player")
    for _, unit in ipairs(units) do
        local guid, ok = safe(UnitGUID, unit)
        if ok and type(guid) == "string" and guid ~= "" and selfOK and type(selfGUID) == "string" and guid ~= selfGUID then
            members[guid] = unit
        end
    end
    return {count=count, raid=raid, units=units, members=members}
end
local function locked()
    local restricted, ok = safe(C_ChatInfo and C_ChatInfo.InChatMessagingLockdown)
    return not ok or restricted ~= false
end
local function inInstance()
    local value, ok = safe(IsInInstance)
    return not ok or value ~= false
end
function Group:SendWelcome(entry, state)
    local db, stats = self.db, self.stats
    if not db.welcomeEnabled or db.welcomeMessage:match("^%s*$") then return end
    if self.chatBlocked or locked() then stats.chatSkipped=stats.chatSkipped+1; return end
    local first, ok = safe(UnitName, "player")
    local zone = safe(GetZoneText)
    local values = {customer=entry.name, player=ok and type(first)=="string" and first or "me",
        zone=type(zone)=="string" and zone or "my location"}
    local msg = db.welcomeMessage:gsub("{(%a+)}", function(k) return values[k] or "{"..k.."}" end)
    if not validMessage(msg) then
        stats.chatSkipped=stats.chatSkipped+1
        self.log("Welcome skipped: expanded message exceeds 255 bytes or contains control characters.")
        return
    end
    local _, success = safe(C_ChatInfo and C_ChatInfo.SendChatMessage, msg, state.raid and "RAID" or "PARTY")
    if success and not self.chatBlocked then stats.welcomes=stats.welcomes+1
    else stats.chatSkipped=stats.chatSkipped+1; self.log("Welcome chat call unavailable or blocked; no retry.") end
end
function Group:MarkSelf(state)
    local db, stats = self.db, self.stats
    if not db.autoMarkerEnabled then return end
    local function skip() stats.markerSkipped=stats.markerSkipped+1 end
    if self.markerBlocked or locked() then skip(); return end
    local mark, ok = safe(GetRaidTargetIndex, "player")
    if not ok or (mark ~= nil and mark ~= 0) then skip(); return end
    if state.raid and safe(UnitIsGroupLeader,"player") ~= true and safe(UnitIsGroupAssistant,"player") ~= true then skip(); return end
    -- Do not steal the chosen marker from any observable group member.
    for _, unit in ipairs(state.units) do
        local guid, identityOK = safe(UnitGUID, unit)
        local current, markerOK = safe(GetRaidTargetIndex, unit)
        if not identityOK or type(guid) ~= "string" or guid == "" or not markerOK or current == db.raidMarker then skip(); return end
    end
    -- Recheck self immediately before the call. Never set 0 or toggle.
    local current, currentOK = safe(GetRaidTargetIndex, "player")
    if not currentOK or (current ~= nil and current ~= 0) then skip(); return end
    local _, success = safe(SetRaidTarget, "player", db.raidMarker)
    if success and not self.markerBlocked then stats.marks=stats.marks+1
    else skip(); self.log("Self-marker call unavailable or blocked; no retry.") end
end
function Group:Flush(state)
    local ready = self.joined
    self.joined = {}
    if not self.db.enabled or self.db.debug or not state or state.count == 0 then return end
    for guid, entry in pairs(ready) do
        if state.members[guid] then
            self:MarkSelf(state)
            -- Re-read group mode after marking, not the mode at invite time.
            local current = groupState()
            if current and current.members[guid] then self:SendWelcome(entry,current) end
        end
    end
end
function Group:RequestRaid()
    self.latch = true
    self.waiting = true
    self.generation = self.generation + 1
    local generation = self.generation
    self.stats.conversions = self.stats.conversions + 1
    local _, ok = safe(C_PartyInfo and C_PartyInfo.ConvertToRaid)
    if not ok or self.raidBlocked then
        self:CancelWait()
        self.log("Raid conversion unavailable or blocked; use the native group menu if desired.")
        return
    end
    -- Only one timer per conversion; it never retries the conversion.
    if self.waiting then
        if C_Timer and type(C_Timer.After) == "function" then
            C_Timer.After(CONVERT_WAIT, function()
                if self.waiting and self.generation == generation then
                    self:CancelWait()
                    local state = groupState()
                    if state and state.raid then self.stats.raidConfirmed=self.stats.raidConfirmed+1 end
                    self:Flush(state)
                end
            end)
        else self:CancelWait() end
    end
end
function Group:OnRoster()
    if not self.db then return end
    local db = self.db
    self:Prune(GetTime())
    if not db.enabled then self:ClearPending(); return end
    local state = groupState()
    if not state then return end
    if state.count == 0 then
        self.latch, self.simLatch = false,false
        self.joined = {}; self:CancelWait()
        return
    end
    if not state.raid and state.count < db.raidThreshold then
        self.latch, self.simLatch = false,false
        self:CancelWait()
    end
    if db.debug then
        self.pending,self.joined = {},{}
        if db.autoRaidEnabled and not state.raid and state.count>=db.raidThreshold and not self.simLatch
           and not inInstance() and safe(UnitIsGroupLeader,"player")==true then
            self.simLatch=true; self.stats.raidSimulated=self.stats.raidSimulated+1
            self.log("DEBUG: would convert party to raid.")
        end
        return
    end
    if db.welcomeEnabled or db.autoMarkerEnabled then
        for guid, entry in pairs(self.pending) do
            if state.members[guid] then
                self.pending[guid]=nil
                self.joined[guid]=entry
                self.stats.accepted=self.stats.accepted+1
            end
        end
    end
    if state.raid and self.waiting then
        self.stats.raidConfirmed=self.stats.raidConfirmed+1
        self:CancelWait()
    elseif db.autoRaidEnabled and not state.raid and state.count>=db.raidThreshold
       and not self.latch and not self.raidBlocked and not inInstance()
       and safe(UnitIsGroupLeader,"player")==true then
        self:RequestRaid()
        -- ConvertToRaid may complete before the next roster event.
        local current=groupState()
        if current and current.raid and self.waiting then
            self.stats.raidConfirmed=self.stats.raidConfirmed+1
            self:CancelWait()
        end
        state=current or state
    end
    if not self.waiting then self:Flush(state) end
end
function Group:Blocked(action)
    local lower=action:lower()
    if lower:find("sendchatmessage",1,true) then self.chatBlocked=true
    elseif lower:find("setraidtarget",1,true) then self.markerBlocked=true
    elseif lower:find("converttoraid",1,true) then self.raidBlocked=true
    elseif lower:find("invite",1,true) then self:ClearPending()
    end
end
function Group:Status()
    local n=0
    for _ in pairs(self.pending) do n=n+1 end
    local s,d=self.stats,self.db
    self.log(("Group: welcome=%s; marker=%s (%d); auto raid=%s (%d total); pending=%d; tracked=%d; accepted=%d; expired=%d"):format(tostring(d.welcomeEnabled),tostring(d.autoMarkerEnabled),d.raidMarker,tostring(d.autoRaidEnabled),d.raidThreshold,n,s.tracked,s.accepted,s.expired))
    self.log(("Group calls: chat=%d skipped=%d blocked=%s; marker=%d skipped=%d blocked=%s; conversion=%d observed=%d simulated=%d blocked=%s"):format(s.welcomes,s.chatSkipped,tostring(self.chatBlocked),s.marks,s.markerSkipped,tostring(self.markerBlocked),s.conversions,s.raidConfirmed,s.raidSimulated,tostring(self.raidBlocked)))
end
function Group:Command(cmd, rest)
    if cmd=="groupstatus" then self:Status(); return true end
    local key,value
    if cmd=="welcome" then key="welcomeEnabled"
    elseif cmd=="message" then key="welcomeMessage"; value=rest
    elseif cmd=="marker" then
        if rest=="off" or rest=="0" then key="autoMarkerEnabled"; value=false
        elseif rest=="on" then key="autoMarkerEnabled"; value=true
        else
            local n=tonumber(rest)
            if integer(n,1,8) then self:Set("raidMarker",n); key="autoMarkerEnabled"; value=true
            else self.log("Usage: /ae marker off | on | 1-8"); return true end
        end
    elseif cmd=="raid" then
        if rest=="off" then key="autoRaidEnabled"; value=false
        elseif rest=="on" then key="autoRaidEnabled"; value=true
        else
            local n=tonumber(rest)
            if integer(n,2,5) then self:Set("raidThreshold",n); key="autoRaidEnabled"; value=true
            else self.log("Usage: /ae raid off | on | 2-5"); return true end
        end
    else return false end
    if value==nil and key=="welcomeEnabled" then
        if rest=="on" then value=true elseif rest=="off" then value=false
        else self.log("Usage: /ae welcome on | off"); return true end
    end
    local ok,err=self:Set(key,value)
    self.log(ok and ("Saved "..key..".") or err)
    return true
end
