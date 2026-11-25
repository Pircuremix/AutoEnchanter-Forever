-- InviteResults.lua: match localized named results, never guess an unnamed target.
local _,ns=...
local R={}; ns.InviteResults=R
local RULES={
    {"ERR_ALREADY_IN_GROUP_S","already_grouped"},
    {"ERR_ALREADY_INVITED_TO_GROUP_S","busy"},
    {"ERR_ALREADY_INVITED_TO_GROUP_SS","busy"},
    {"ERR_PLAYER_BUSY_S","busy"},
    {"ERR_INVITE_PLAYER_S","sent"},
    {"ERR_DECLINE_GROUP_S","declined"},
    {"ERR_BAD_PLAYER_NAME_S","failed"},
    {"ERR_PLAYER_NOT_FOUND_S","failed"},
    {"ERR_PLAYER_OFFLINE_S","failed"},
    {"ERR_INVITE_RESTRICTED_S","failed"},
}
local function readable(v) return not (issecretvalue and issecretvalue(v)) end
local function clean(s)
    return s:gsub("|c%x%x%x%x%x%x%x%x",""):gsub("|r",""):gsub("|H[^|]+|h%[?(.-)%]?|h","%1"):gsub("%[([^%]]+)%]","%1")
end
local function key(s) return clean(s):lower():gsub("%-"," "):gsub("%s+"," "):match("^%s*(.-)%s*$") end
local function pattern(template)
    -- Replace one/two localized %s fields (including positional placeholders).
    -- Remove player-link markup before compiling, preserving display placeholders.
    template=clean(template)
    local tokens,parts={},{}
    local i=1
    while i<=#template do
        local a,b=template:find("%%[%d]+%$s",i)
        local c,d=template:find("%%s",i)
        if c and (not a or c<a) then a,b=c,d end
        if not a then parts[#parts+1]=template:sub(i):gsub("([^%w])","%%%1"); break end
        parts[#parts+1]=template:sub(i,a-1):gsub("([^%w])","%%%1")
        parts[#parts+1]="(.+)"; tokens[#tokens+1]=true; i=b+1
    end
    if #tokens<1 or #tokens>2 then return nil end
    return "^"..table.concat(parts).."$"
end
function R:Init(ledger)
    self.ledger=ledger; self.rules={}; self.queue=nil
    for _,rule in ipairs(RULES) do
        local v=_G[rule[1]]
        if readable(v) and type(v)=="string" then
            local pat=pattern(v)
            if pat then self.rules[#self.rules+1]={pat,rule[2]} end
        end
    end
end
function R:Begin() self.queue={} end
function R:End(visit,guid)
    local queue=self.queue or {}; self.queue=nil
    self.synchronousVisit,self.synchronousGUID=visit,guid
    for _,msg in ipairs(queue) do self:Handle(msg) end
    self.synchronousVisit,self.synchronousGUID=nil,nil
end
function R:Handle(msg)
    if not readable(msg) or type(msg)~="string" or not self.ledger or not self.ledger.ready then return end
    if self.queue then if #self.queue<16 then self.queue[#self.queue+1]=msg end; return end
    local cleaned=clean(msg)
    for _,rule in ipairs(self.rules) do
        local a,b=cleaned:match(rule[1])
        if a and (not b or key(a)==key(b)) then
            local guid=self.ledger:NamedResult(key(a),rule[2],key)
            if guid and rule[2]~="sent" and ns.Group and ns.Group.pending and not self.ledger:HasPending(guid) then ns.Group.pending[guid]=nil end
            return guid
        end
    end
    -- A nameless busy result cannot be linked reliably; invalidate sent
    -- evidence rather than attributing a decline to a potentially unavailable player.
    for _,entry in ipairs({{"ERR_ALREADY_INVITED_TO_GROUP","busy"},{"ERR_ALREADY_IN_GROUP","already_grouped"},{"ERR_PLAYER_BUSY","busy"},{"ERR_GROUP_FULL","failed"}}) do
        local v=_G[entry[1]]
        if readable(v) and type(v)=="string" and cleaned==clean(v) then
            local visit,guid=self.synchronousVisit,self.synchronousGUID
            local p=visit and self.ledger.pending[visit.id]
            if p and p.guid==guid then self.ledger:Resolve(p,entry[2],self.ledger:Now(),"synchronous unnamed game result"); self.ledger:Schedule()
            else self.ledger:InvalidateSent() end
            return guid
        end
    end
end
