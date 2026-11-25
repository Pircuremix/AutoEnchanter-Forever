-- AutoEnchanter Forever 1.6.0 (release candidate)
-- Normalized matching: ignores filler words, punctuation, spaces, and "Xg" / "X gold" patterns
local ADDON = "Auto Enchanter"
local addonName, ns = ...
local group, options = ns.Group, ns.Options
local ledger, trade, dashboard, minimap = ns.Database, ns.Trade, ns.Dashboard, ns.Minimap
local policy,guild,results,performance=ns.Policy,ns.Guild,ns.InviteResults,ns.Performance
local function readable(v)
    return not (issecretvalue and issecretvalue(v))
end

-- Localize frequently used globals for speed
local strlower = string.lower
local strmatch = string.match
local tonumber = tonumber
local tostring = tostring
local table_insert = table.insert
local table_remove = table.remove
local ipairs = ipairs
local pairs = pairs
local GetTime = GetTime

-- SavedVariables defaults (bound at ADDON_LOADED)
local defaults = {
    whitelist = {},
    debug = true,
    popupEnabled = true,
    enabled = true, -- master on/off switch
}
local db -- bound to AutoEnchanterDB at ADDON_LOADED

local whitelistLookup = {}     -- normalized phrase -> true (fast O(1) membership)
local lastMessageByPlayer = {} -- normalized player -> last raw message
local recentInvites = {}       -- playerShort -> last invite time
local RECENT_COOLDOWN = 7      -- seconds cooldown to avoid spam

-- Filler words to ignore (lowercase). Add/remove words here as you want.
-- Note: normalization strips punctuation, so "w/" becomes "w" before tokenization.
local fillerWords = {
    "with", "w", "pst", "whisper", "msg", "my", "mats", "my mats",
    "for", "any", "got", "to", "will", "tip", "bot", "bots", "in", "org",
    "please", "pls", "plz", "at", "some", "have", "have mats", "ofc", "will",
}
local fillerLookup = {}
for _, w in ipairs(fillerWords) do
    fillerLookup[w] = true
end

-- Token-level alias map.
-- These only normalize obvious shorthand / misspellings / same-slot wording.
-- They do NOT collapse different enchants together.
local tokenAliases = {
    -- enchant / enchanter family
    enchant = "enchant",
    enchants = "enchant",
    enchanting = "enchant",
    enchantment = "enchant",
    enchanter = "enchant",
    enchanters = "enchant",
    ench = "enchant",
    enc = "enchant",
    enchan = "enchant",
    chant = "enchant",
    chanter = "enchant",
    enchater = "enchant",
    enchantr = "enchant",
    enchanrr = "enchant",
    enchantrr = "enchant",
    enchaner = "enchant",
    enhcanter = "enchant",
    enhanter = "enchant",
    enchanater = "enchant",
    enchancter = "enchant",
    enchnater = "enchant",
    enchnanter = "enchant",
    encahnter = "enchant",
    encahnt = "enchant",
    enchantor = "enchant",
    enchent = "enchant",
    enchat = "enchant",
    echanter = "enchant",
    encanter = "enchant",
    enchabt = "enchant",
    enchante = "enchant",
    enchanteur = "enchant",
    encahanter = "enchant",
    ehcnahtner = "enchant",
    enhant = "enchant",

    -- weapon slot
    weapon = "weapon",
    wep = "weapon",
    wpn = "weapon",
    weapom = "weapon",
    weapoins = "weapon",
    weaspn = "weapon",

    -- bracer slot
    bracer = "bracer",
    bracers = "bracer",
    wrist = "bracer",
    wrists = "bracer",
    bracesr = "bracer",

    -- cloak slot
    cloak = "cloak",
    cape = "cloak",
    back = "cloak",
    claok = "cloak",
    cloack = "cloak",
    claokc = "cloak",
    cloacke = "cloak",

    -- boots slot
    boot = "boots",
    boots = "boots",
    shoe = "boots",
    shoes = "boots",
    nboots = "boots",
    boosts = "boots",

    -- gloves slot
    glove = "gloves",
    gloves = "gloves",
    hand = "gloves",
    hands = "gloves",

    -- agility stat
    agi = "agility",
    agil = "agility",
    agl = "agility",
    agility = "agility",
    agilitiy = "agility",

    -- strength stat
    str = "strength",
    strength = "strength",

    -- stamina stat
    stam = "stamina",
    sta = "stamina",
    stamina = "stamina",

    -- intellect stat
    int = "intellect",
    intel = "intellect",
    intellect = "intellect",

    -- spirit stat
    spirit = "spirit",
    spi = "spirit",

    -- health wording
    hp = "health",
    health = "health",

    -- fiery typo family (only typo/noise cleanup; not raw "fire")
    fiery = "fiery",
    firey = "fiery",
    fireyt = "fiery",
    feiry = "fiery",

    -- crusader typo family
    crusader = "crusader",
    cursader = "crusader",
    cusader = "crusader",
    crusder = "crusader",

    -- lifestealing typo family
    lifestealing = "lifestealing",
    lifesteal = "lifestealing",
    lifeteal = "lifestealing",

    -- single-word typo cleanup used in multi-word enchant names
    icey = "icy",
    chil = "chill",
}

-- Small helpers
local function trim(s)
    return (s:gsub("^%s*(.-)%s*$", "%1"))
end

-- Forever uses first name + surname. A dash and a space can represent
-- the same identity; never fall back to a first name alone.
local function normalizeName(name)
    if not readable(name) or type(name) ~= "string" then return nil end
    local key = strlower(trim(name)):gsub("%-", " "):gsub("%s+", " ")
    if key ~= "" then return key end
end

local function UnitIdentity(unit)
    local fn = UnitFullName or UnitName
    if not fn then return nil end
    local first, surname = fn(unit)
    if not readable(first) or not readable(surname) then return nil end
    if type(first) ~= "string" or first == "" then return nil end
    if type(surname) == "string" and surname ~= "" and not first:find("[ %-]") then
        return first .. "-" .. surname
    end
    return first
end

local ownKey, ownGUID
local CACHE_TTL = 900
local CACHE_LIMIT = 2048
local cacheCount = 0
local nextPrune = 0
local stats = { seen = 0, matches = 0, attempted = 0, skipped = 0, restricted = 0, simulated = 0, failed = 0, ineligible = 0 }
local function PruneCaches(now)
    if now < nextPrune then return end
    nextPrune = now + 60
    for key, entry in pairs(lastMessageByPlayer) do
        if now - entry.time > CACHE_TTL then lastMessageByPlayer[key] = nil; cacheCount = cacheCount - 1 end
    end
    for key, time in pairs(recentInvites) do
        if now - time > RECENT_COOLDOWN then recentInvites[key] = nil end
    end
end

-- Printing helpers
local function printSys(msg)
    if DEFAULT_CHAT_FRAME and DEFAULT_CHAT_FRAME.AddMessage then
        DEFAULT_CHAT_FRAME:AddMessage("|cff00ff99[" .. ADDON .. "]|r " .. tostring(msg))
    else
        print("[" .. ADDON .. "] " .. tostring(msg))
    end
end

local function AE_Debug(msg)
    if db and db.debug then
        if DEFAULT_CHAT_FRAME and DEFAULT_CHAT_FRAME.AddMessage then
            DEFAULT_CHAT_FRAME:AddMessage("|cff66cc66[AE DEBUG]|r " .. tostring(msg))
        else
            print("[AE DEBUG] " .. tostring(msg))
        end
    end
end

-- Expand WoW Henchant links into readable text before normalization.
-- Example:
-- |cffffd000|Henchant:27944|h[Enchanting: Enchant Shield - Tough Shield]|h|r
-- becomes:
-- Enchanting: Enchant Shield - Tough Shield
local function ExpandEnchantLinks(s)
    if not s or s == "" then return s or "" end
    local t = tostring(s)

    -- Allow additional link payload fields used by newer clients.
    t = t:gsub("|Henchant:[^|]+|h%[(.-)%]|h", function(text)
        text = text:gsub("^[Ee]nchanting:%s*", "")
        return " " .. text .. " "
    end)
    t = t:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")

    return t
end

-- Normalize message/whitelist text for matching.
-- This is intentionally conservative:
-- * keeps distinct enchants distinct
-- * fixes obvious noise / typos / shorthand
-- * does NOT collapse raw numbers or semantic enchant families together
local function NormalizeForMatch(s)
    if not readable(s) or type(s) ~= "string" then return "" end
    local t = tostring(s)

    -- Expand linked enchants into readable text first
    t = ExpandEnchantLinks(t)

    t = strlower(t)
    t = trim(t)

    -- Remove complete gold amounts, including decimal tips, but never "15gems".
    t = t:gsub("%f[%d]%d+%.%d+%s*gold%f[^%w]", " ")
    t = t:gsub("%f[%d]%d+%.%d+%s*g%f[^%w]", " ")
    t = t:gsub("%f[%d]%d+%s*gold%f[^%w]", " ")
    t = t:gsub("%f[%d]%d+%s*g%f[^%w]", " ")

    -- split glued number+word forms safely:
    -- 100hp   -> 100 hp
    -- 15agi   -> 15 agi
    -- 7intel  -> 7 intel
    -- keeps short forms like 2h intact because suffix/prefix must be 2+ letters
    t = t:gsub("(%d+)(%a%a+)", "%1 %2")
    t = t:gsub("(%a%a+)(%d+)", "%1 %2")

    -- Replace any non-letter/digit with space.
    t = t:gsub("[^%a%d]", " ")

    -- Tokenize on contiguous letters/digits
    local parts = {}
    for w in t:gmatch("[%a%d]+") do
        local alias = tokenAliases[w]
        if alias then
            w = alias
        end

        if not fillerLookup[w] then
            table_insert(parts, w)
        end
    end

    -- Join without spaces to ignore spaces completely for matching
    return table.concat(parts, "")
end

-- Fast lookup rebuild (call after binding db and after any add/remove)
local function RebuildWhitelistLookup()
    whitelistLookup = {}
    if db and db.whitelist then
        for _, phrase in ipairs(db.whitelist) do
            local key = NormalizeForMatch(phrase)
            if key ~= "" then
                whitelistLookup[key] = true
            end
        end
    end
end

-- Whitelist mutators (keeps array for persistence + lookup for speed)
local function AddWhitelistEntry(phrase)
    phrase = trim(tostring(phrase or ""))
    if phrase == "" then return false, "empty phrase" end
    if not db.whitelist then db.whitelist = {} end

    local normalized = NormalizeForMatch(phrase)
    if normalized == "" then
        return false, "phrase normalizes to empty (nothing to match)"
    end
    if whitelistLookup[normalized] then
        return false, "already present"
    end

    table_insert(db.whitelist, phrase)
    whitelistLookup[normalized] = true
    AE_Debug(("AddWhitelistEntry: %q -> normalized=%q"):format(phrase, normalized))
    return true
end

local function RemoveWhitelistByIndex(idx)
    if not db.whitelist then return false, "empty" end
    if type(idx) ~= "number" or idx % 1 ~= 0 or idx < 1 or idx > #db.whitelist then
        return false, "invalid index"
    end

    local removed = table_remove(db.whitelist, idx)
    if removed then
        local key = NormalizeForMatch(removed)
        if key ~= "" then
            RebuildWhitelistLookup()
        end
        AE_Debug(("RemoveWhitelistByIndex: removed %q (norm=%q)"):format(removed, key))
        return true
    end
    return false, "remove failed"
end

local function RemoveWhitelistByValue(val)
    if not db.whitelist then return false, "empty" end
    local key = NormalizeForMatch(tostring(val or ""))

    for i, v in ipairs(db.whitelist) do
        if NormalizeForMatch(v) == key then
            table_remove(db.whitelist, i)
            RebuildWhitelistLookup()
            AE_Debug(("RemoveWhitelistByValue: removed %q (norm=%q)"):format(v, key))
            return true
        end
    end
    return false, "not found"
end

local function ListWhitelist()
    if not db or not db.whitelist or #db.whitelist == 0 then
        printSys("Whitelist is empty.")
        return
    end

    printSys("Whitelist entries (original text):")
    for i, v in ipairs(db.whitelist) do
        local norm = NormalizeForMatch(v)
        printSys(("  %d) %s  ->  %s"):format(i, v, (norm ~= "" and norm or "(empty)")))
    end
end

-- Cooldown check
local function CanInviteNow(playerShort)
    local t = GetTime()
    local last = recentInvites[playerShort]
    if not last or (t - last) > RECENT_COOLDOWN then
        recentInvites[playerShort] = t
        return true
    end
    return false
end

-- Native invite only. A successful Lua call is not server confirmation.
local lastAttempt, lastAttemptTime, inviteBlocked, inviteInFlight
local function DoInvite(playerName, guid, start)
    if db.debug then
        stats.simulated = stats.simulated + 1
        printSys("DEBUG: would have invited " .. playerName)
        return
    end
    if inviteBlocked then
        stats.ineligible = stats.ineligible + 1
        printSys("Match: " .. playerName .. ". Automatic invites blocked this session. Use the native player menu or /invite.")
        return
    end
    local memberGuild=guild:Membership(guid)
    if not policy:Allow(guid,memberGuild) or ledger:HasPending(guid) then stats.skipped=stats.skipped+1; return end
    local party = C_PartyInfo
    local trackable = false
    if party and party.IsGUIDInGroup and readable(guid) and type(guid) == "string" and guid ~= "" then
        local ok, member = pcall(party.IsGUIDInGroup, guid)
        if not ok or not readable(member) or member == true then
            stats.ineligible = stats.ineligible + 1
            return
        end
        trackable = member == false
    end
    if party and party.CanInvite then
        local ok, allowed = pcall(party.CanInvite)
        if not ok or not readable(allowed) or allowed ~= true then
            stats.ineligible = stats.ineligible + 1
            printSys("Match: " .. playerName .. "; game says you cannot invite right now.")
            return
        end
    end
    if party and party.IsPartyFull then
        local ok, full = pcall(party.IsPartyFull)
        if not ok or not readable(full) or full ~= false then
            stats.ineligible = stats.ineligible + 1
            printSys("Match: " .. playerName .. "; party is full.")
            return
        end
    end
    local invite = party and party.InviteUnit
    if type(invite) ~= "function" then
        stats.ineligible = stats.ineligible + 1
        printSys("Invite API unavailable. Use /invite " .. playerName)
        return
    end
    lastAttempt, lastAttemptTime = playerName, GetTime()
    stats.attempted = stats.attempted + 1
    results:Begin()
    inviteInFlight = true
    local stop=performance:Start()
    local ok, result = pcall(invite, playerName)
    inviteInFlight = false
    performance:Finish(start,stop)
    if inviteBlocked then ledger:Record(playerName,guid,"failed",false,memberGuild); results:End(); return end
    if not ok or not readable(result) or result == false then
        stats.failed = stats.failed + 1
        ledger:Record(playerName,guid,"failed",false,memberGuild); results:End()
        printSys("Invite call failed. Use /invite " .. playerName)
    else
        local whisper=guild:Whisper(playerName,guid,memberGuild)
        local visit=ledger:Record(playerName,guid,"pending",trackable,memberGuild,whisper)
        results:End(visit,guid)
        printSys("Invite API called for " .. playerName .. " (delivery unconfirmed)")
        if trackable and (not visit or visit.status=="pending" or visit.status=="accepted") then group:TrackInvite(playerName, guid) end
    end
end

local function FastChatHandler(event, ...)
    if not db then return end
    local start=performance:Start()
    local msg, author = ...
    if not readable(msg) or not readable(author) then
        stats.restricted = stats.restricted + 1
        return
    end
    if type(msg) ~= "string" or type(author) ~= "string" or author == "" then return end
    if event == "CHAT_MSG_CHANNEL" then
        -- Argument 7 is the stable channel ID, not the user's channel slot.
        local zoneChannelID = select(7, ...)
        if not readable(zoneChannelID) then return end
        if zoneChannelID ~= 1 and zoneChannelID ~= 2 then return end
    end
    local key = normalizeName(author)
    if not key then return end
    local guid = select(12, ...)
    if not readable(guid) then
        stats.restricted = stats.restricted + 1
        return
    end
    if (ownGUID and readable(guid) and guid == ownGUID) or (ownKey and key == ownKey) then return end
    local now = GetTime()
    if db.enabled and next(whitelistLookup) ~= nil then
    stats.seen = stats.seen + 1
    local normalizedMsg = NormalizeForMatch(msg)
    if normalizedMsg ~= "" then
    if whitelistLookup[normalizedMsg] then
        stats.matches = stats.matches + 1
        if CanInviteNow(key) then
            DoInvite(author, guid, start)
        else
            stats.skipped = stats.skipped + 1
            if db.debug then AE_Debug("Invite suppressed by cooldown for " .. author) end
        end
    elseif db.debug then
        AE_Debug(("No whitelist match: normalized=%q"):format(normalizedMsg))
    end
    end
    end
    PruneCaches(now)
    -- Learning remains available while invites are disabled.
    if db.popupEnabled then
        if not lastMessageByPlayer[key] then
            if cacheCount >= CACHE_LIMIT then
                local oldestKey, oldestTime
                for k, entry in pairs(lastMessageByPlayer) do
                    if not oldestTime or entry.time < oldestTime then oldestKey, oldestTime = k, entry.time end
                end
                if oldestKey then lastMessageByPlayer[oldestKey] = nil; cacheCount = cacheCount - 1 end
            end
            cacheCount = cacheCount + 1
        end
        lastMessageByPlayer[key] = { text = msg, time = now }
    end
end

-- Modern Menu API integration (adds "Add to Auto Enchanter whitelist" button)
local function ResolveMenuName(contextData)
    if not readable(contextData) then return nil end
    if type(contextData) == "string" then return contextData end
    if type(contextData) ~= "table" or (canaccesstable and not canaccesstable(contextData)) then return nil end
    local name, surname, unit = contextData.name, contextData.surname, contextData.unit
    if not readable(name) or not readable(surname) or not readable(unit) then return nil end
    -- Forever UnitPopupShared populates surname, not server.
    local server = surname
    if not server or server == "" then server = contextData.server end
    if not readable(server) then return nil end
    if readable(name) and type(name) == "string" and name ~= "" then
        if readable(server) and type(server) == "string" and server ~= "" and not name:find("[ %-]") then
            name = name .. "-" .. server
        end
        if lastMessageByPlayer[normalizeName(name)] then return name end
    end
    if readable(unit) and type(unit) == "string" then
        local full = UnitIdentity(unit)
        if full then return full end
    end
    local player = contextData.player
    if readable(player) and type(player) == "string" then return player end
    return readable(name) and type(name) == "string" and name or nil
end

local function InitModernMenus()
    if type(Menu) ~= "table" or type(Menu.ModifyMenu) ~= "function" then
        printSys("Right-click menu API unavailable; use /ae add instead.")
        return
    end
    local function modify(_, root, contextData)
        if not db or not db.popupEnabled then return end
        if not root or type(root.CreateButton) ~= "function" then return end
        local name = ResolveMenuName(contextData)
        local key = normalizeName(name)
        local entry = key and lastMessageByPlayer[key]
        if not entry or GetTime() - entry.time > CACHE_TTL then return end
        -- Capture this exact cached message when the menu opens.
        local text = entry.text
        root:CreateButton("Add to Auto Enchanter whitelist", function()
            local ok, err = AddWhitelistEntry(text)
            if ok then printSys(("Added from %s: %q"):format(name, text))
            else printSys("Couldn't add to whitelist: " .. (err or "unknown")) end
        end)
    end
    for _, tag in ipairs({"MENU_UNIT_PLAYER", "MENU_UNIT_PARTY", "MENU_UNIT_RAID", "MENU_UNIT_RAID_PLAYER", "MENU_UNIT_FRIEND", "MENU_UNIT_ENEMY_PLAYER", "MENU_UNIT_CHAT_ROSTER", "MENU_UNIT_TARGET", "MENU_UNIT_FOCUS"}) do
        local ok, err = pcall(Menu.ModifyMenu, tag, modify)
        if not ok and db.debug then AE_Debug("Menu unavailable: " .. tag .. " (" .. tostring(err) .. ")") end
    end
end

-- Slash commands (use fast mutators)
SLASH_AUTOENCHANTER1 = "/autoenchanter"
SLASH_AUTOENCHANTER2 = "/ae"
SlashCmdList["AUTOENCHANTER"] = function(msg)
    local cmd, rest = msg:match("^(%S*)%s*(.-)$")
    cmd = (cmd or ""):lower()
    rest = rest or ""
    if db then
        if cmd == "settings" or cmd == "config" then dashboard:Open("Settings"); return end
        if cmd == "database" or cmd == "dashboard" then dashboard:Open("Customers"); return end
        if cmd == "ledgerstatus" then ledger:Status(); trade:Status(); policy:Status(); guild:Status(); return end
        if cmd == "blacklist" then dashboard:Open("Blacklist"); return end
        if cmd == "performance" then performance:Status(printSys); return end
        if guild:Command(cmd,rest) then return end
        if cmd == "tradetrace" then trade:Command(rest); return end
        if cmd == "minimap" and (rest=="show" or rest=="hide") then minimap:SetHidden(rest=="hide"); return end
        if group:Command(cmd, rest) then return end
    end

    if cmd == "test" and rest ~= "" then
        if not db then return end
        local key = NormalizeForMatch(rest)
        printSys(("%s (no invite sent); normalized=%q"):format(whitelistLookup[key] and "MATCH" or "NO MATCH", key))
        return
    end
    if cmd == "diagnostics" or cmd == "diag" then
        local version, build, _, interface = GetBuildInfo()
        printSys(("Version 1.6.0; client=%s build=%s interface=%s"):format(tostring(version), tostring(build), tostring(interface)))
        local party = C_PartyInfo or {}
        printSys(("InviteUnit=%s CanInvite=%s IsPartyFull=%s IsGUIDInGroup=%s"):format(type(party.InviteUnit), type(party.CanInvite), type(party.IsPartyFull), type(party.IsGUIDInGroup)))
        printSys(("Menu.ModifyMenu=%s issecretvalue=%s; automatic invites blocked=%s"):format(type(Menu and Menu.ModifyMenu), type(issecretvalue), tostring(inviteBlocked == true)))
        printSys(("Simulated=%d; failed calls=%d; ineligible=%d; API calls are not delivery confirmations"):format(stats.simulated, stats.failed, stats.ineligible))
        group:Status()
        ledger:Status(); trade:Status(); policy:Status(); guild:Status(); performance:Status(printSys)
        return
    end
    if cmd == "status" then
        if not db then return end
        printSys(("Enabled=%s; debug=%s; whitelist=%d; scanned=%d; matches=%d; invite API calls=%d; cooldown skips=%d; restricted=%d; blocked=%s"):format(tostring(db.enabled), tostring(db.debug), #db.whitelist, stats.seen, stats.matches, stats.attempted, stats.skipped, stats.restricted, tostring(inviteBlocked == true)))
        return
    end

    if cmd == "on" or cmd == "enable" then
        if not db then
            printSys("Saved vars not initialized yet")
            return
        end
        db.enabled = true
        minimap:Refresh(); dashboard:Refresh()
        printSys("Auto Enchanter -> ENABLED")
        AE_Debug("Addon enabled via slash")
        return
    end

    if cmd == "off" or cmd == "disable" then
        if not db then
            printSys("Saved vars not initialized yet")
            return
        end
        db.enabled = false
        minimap:Refresh(); dashboard:Refresh()
        group:ClearPending()
        group:ConfigChanged()
        printSys("Auto Enchanter -> DISABLED")
        AE_Debug("Addon disabled via slash")
        return
    end

    if cmd == "debug" then
        if not db then
            printSys("Saved vars not initialized yet")
            return
        end
        local r = rest:lower()
        if r == "on" then
            db.debug = true
        elseif r == "off" then
            db.debug = false
        else
            db.debug = not db.debug
        end
        group:ConfigChanged()
        printSys("DEBUG -> " .. (db.debug and "ON" or "OFF"))
        return
    end

    if cmd == "popup" then
        if not db then
            printSys("Saved vars not initialized yet")
            return
        end
        local r = rest:lower()
        if r == "on" then
            db.popupEnabled = true
        elseif r == "off" then
            db.popupEnabled = false
        else
            db.popupEnabled = not db.popupEnabled
        end
        printSys("POPUP -> " .. (db.popupEnabled and "ON" or "OFF"))
        return
    end

    if cmd == "add" and rest ~= "" then
        if not db then
            printSys("Saved vars not initialized yet")
            return
        end
        local ok, err = AddWhitelistEntry(rest)
        if ok then
            printSys(("Added whitelist entry: %q"):format(rest))
        else
            printSys(("Couldn't add: %s"):format(err or "unknown"))
        end
        return
    end

    if cmd == "remove" and rest ~= "" then
        if not db then
            printSys("Saved vars not initialized yet")
            return
        end

        local n = tonumber(rest)
        if n then
            local ok, err = RemoveWhitelistByIndex(n)
            if ok then
                printSys(("Removed whitelist index %d"):format(n))
            else
                printSys(("Couldn't remove: %s"):format(err or "unknown"))
            end
        else
            local ok, err = RemoveWhitelistByValue(rest)
            if ok then
                printSys(("Removed whitelist phrase: %q"):format(rest))
            else
                printSys(("Couldn't remove: %s"):format(err or "unknown"))
            end
        end
        return
    end

    if cmd == "list" then
        ListWhitelist()
        return
    end

    printSys("Usage: /ae on | off | add <phrase> | remove <index|phrase> | list | debug [on|off] | popup [on|off] | test <phrase> | status | diagnostics | settings | groupstatus | welcome | message | marker | raid | database | ledgerstatus | tradetrace | minimap | blacklist | performance | guildmessage | guildwhisper | guildrefresh")
end

-- SavedVariables: preserve valid phrases and existing boolean settings.
local function InitDB()
    if type(AutoEnchanterDB) ~= "table" then AutoEnchanterDB = {} end
    db = AutoEnchanterDB
    local cleaned = {}
    if type(db.whitelist) == "table" then
        for _, phrase in ipairs(db.whitelist) do
            if type(phrase) == "string" and NormalizeForMatch(phrase) ~= "" then
                cleaned[#cleaned + 1] = phrase
            end
        end
    end
    db.whitelist = cleaned
    for _, k in ipairs({"debug", "popupEnabled", "enabled"}) do
        if type(db[k]) ~= "boolean" then db[k] = defaults[k] end
    end
    RebuildWhitelistLookup()
    group:Init(db, printSys)
    guild:Init(db,printSys); performance:Init()
    ledger:Init(db, printSys); results:Init(ledger); trade:Init(ledger, printSys); dashboard:Init(db,ledger,options,printSys)
end

local function RefreshIdentity()
    ownKey = normalizeName(UnitIdentity("player"))
    local guid = UnitGUID and UnitGUID("player")
    ownGUID = readable(guid) and type(guid) == "string" and guid or nil
end

-- Event/frame
local frame = CreateFrame("Frame", "AutoEnchanterFrame")
for _, event in ipairs({"ADDON_LOADED", "PLAYER_LOGIN", "PLAYER_ENTERING_WORLD", "CHAT_MSG_SAY", "CHAT_MSG_YELL", "CHAT_MSG_CHANNEL", "GROUP_ROSTER_UPDATE", "PARTY_LEADER_CHANGED", "ADDON_ACTION_BLOCKED", "ADDON_ACTION_FORBIDDEN"}) do
    frame:RegisterEvent(event)
end
for _,event in ipairs({"GUILD_ROSTER_UPDATE","PLAYER_GUILD_UPDATE","CHAT_MSG_SYSTEM","TRADE_SHOW","TRADE_CLOSED","TRADE_ACCEPT_UPDATE","TRADE_PLAYER_ITEM_CHANGED","TRADE_TARGET_ITEM_CHANGED","TRADE_MONEY_CHANGED","TRADE_CURRENCY_CHANGED","TRADE_UPDATE","TRADE_REQUEST_CANCEL","PLAYER_TRADE_MONEY","PLAYER_TRADE_CURRENCY","UI_INFO_MESSAGE","UI_ERROR_MESSAGE","ENCHANT_SPELL_COMPLETED","UNIT_SPELLCAST_SUCCEEDED"}) do
    pcall(frame.RegisterEvent,frame,event)
end
frame:SetScript("OnEvent", function(self, event, ...)
    if event == "ADDON_ACTION_BLOCKED" or event == "ADDON_ACTION_FORBIDDEN" then
        local source, action = ...
        if db and readable(source) and readable(action) and (source == addonName or source == "AutoEnchanter") and type(action) == "string" then
            if not guild:Blocked(action) then group:Blocked(action) end
        end
        if readable(source) and readable(action) and (source == addonName or source == "AutoEnchanter") and type(action) == "string" and action:lower():find("invite", 1, true) and not inviteBlocked then
            inviteBlocked = true
            if db and not inviteInFlight then ledger:FailRecent() end
            printSys("Game blocked automatic invites. No further attempts this session; use the native player menu or /invite.")
            if lastAttempt and GetTime() - lastAttemptTime < 10 then printSys("Last matching customer: " .. lastAttempt) end
        end
        return
    end
    if event == "ADDON_LOADED" then
        if (...) == addonName then InitDB(); self:UnregisterEvent("ADDON_LOADED") end
    elseif event == "PLAYER_LOGIN" then
        if not db then InitDB() end
        RefreshIdentity()
        printSys("Loaded 1.6.0. ENABLED=" .. (db.enabled and "ON" or "OFF") .. "; DEBUG=" .. (db.debug and "ON" or "OFF") .. "; popup=" .. (db.popupEnabled and "ON" or "OFF"))
        InitModernMenus()
        options:Init(group, printSys)
        minimap:Init(db,dashboard,printSys)
        guild:Request()
        self:UnregisterEvent("PLAYER_LOGIN")
    elseif event == "PLAYER_ENTERING_WORLD" then
        RefreshIdentity()
        ledger:OnRoster(); group:OnRoster()
    elseif event == "GROUP_ROSTER_UPDATE" or event == "PARTY_LEADER_CHANGED" then
        ledger:OnRoster(); group:OnRoster(); dashboard:Refresh()
    elseif event=="GUILD_ROSTER_UPDATE" then
        guild:Refresh(); dashboard:QueueRefresh()
    elseif event=="PLAYER_GUILD_UPDATE" then
        guild:Request(); dashboard:QueueRefresh()
    elseif event=="CHAT_MSG_SYSTEM" then
        results:Handle((...)); trade:Event(event,...)
    elseif event:find("^TRADE_") or event=="UI_INFO_MESSAGE" or event=="UI_ERROR_MESSAGE" or event=="ENCHANT_SPELL_COMPLETED" or event=="UNIT_SPELLCAST_SUCCEEDED" or event=="PLAYER_TRADE_MONEY" or event=="PLAYER_TRADE_CURRENCY" then
        if event=="UI_INFO_MESSAGE" or event=="UI_ERROR_MESSAGE" then results:Handle(select(2,...)) end
        trade:Event(event,...)
    else
        FastChatHandler(event, ...)
    end
end)
