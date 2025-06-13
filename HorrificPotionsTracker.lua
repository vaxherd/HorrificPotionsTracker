local module_name, module = ...

local class = module.class
local Frame = module.Frame

local band = bit.band
local function clamp(x, l, h)
    if x < l then return l elseif x > h then return h else return x end
end
local floor = math.floor
local max = math.max
local strformat = string.format
local strlen = string.len
local strsub = string.sub
local tinsert = tinsert

------------------------------------------------------------------------

local SPELL_DRINKING_MYSTERIOUS_VIAL = 317910
local SPELL_NOXIOUS_MIXTURE = 315807
local SPELL_FERMENTED_MIXTURE = 315814
local SPELL_SPICY_POTION = 315817
local SPELL_SPICY_BREATH = 315819
local SPELL_SLUGGISH_POTION = 315845
local SPELL_SICKENING_POTION = 315849

local SPELL_TEXT = {
    [SPELL_NOXIOUS_MIXTURE] = "Poison",
    [SPELL_FERMENTED_MIXTURE] = "Sanity",
    [SPELL_SPICY_POTION] = "Spicy",
    [SPELL_SLUGGISH_POTION] = "Sluggish",
    [SPELL_SICKENING_POTION] = "Sickening",
}

local SPICY_BREATH_INTERVAL = 13  -- In seconds.


-- Combat log event bitfield constants:
local AFFILIATION_MINE = 0x00000001
local TYPE_PLAYER = 0x00000400


local HORRIFIC_POTION_COLORS = {
    -- These must be capitalized to match the "Vial of Mysterious X Liquid"
    -- spell name.  Obviously not l10n-safe.
    Red = {1, 0.3, 0.3},
    Green = {0.3, 1, 0.3},
    Blue = {0.2, 0.6, 1},
    Purple = {0.7, 0.4, 0.85},
    Black = {0.6, 0.6, 0.6},
}
local HORRIFIC_POTION_COLOR_ORDER = {"Red", "Green", "Blue", "Purple", "Black"}
local HORRIFIC_POTION_TIMER_WIDTH = 40  -- Width of the time bars.

-- Mapping from color names to object IDs.  Not currently used; would
-- probably be useful in localization.
local HORRIFIC_POTION_OBJECTS = {
    Red = 341341,
    Green = 341339,
    Blue = 341338,
    Purple = 341340,
    Black = 341337,
}

------------------------------------------------------------------------

-- Pass the color name and tracker frame to the constructor.
local HorrificPotion = class(Frame)

function HorrificPotion.__allocator(thisclass, color, tracker)
    return Frame.__allocator("Frame", "HorrificPotion"..color, tracker)
end

function HorrificPotion:__constructor(color, tracker)
    local rgb = HORRIFIC_POTION_COLORS[color]
    assert(rgb)

    self.color = color
    self.tracker = tracker
    self.spell = nil  -- Spell ID associated with this potion.
    self.aura = nil  -- Active aura instance for this potion's spell, or nil.
    self.last_ts = nil  -- GetTime() timestamp at last update call.
    self.remaining = nil  -- Remaining time (seconds) at last update call.
    self.time_color = nil  -- Current time text color (*_FONT_COLOR reference).
    self.breath_timer = nil  -- Spicy breath cooldown (manually tracked).

    self:SetScript("OnMouseDown", self.OnMouseDown)

    local name_label = self:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    self.name_label = name_label
    name_label:SetTextColor(unpack(rgb))
    name_label:SetTextScale(1.25)
    name_label:SetText("???")
    name_label:SetPoint("TOP")

    local w = HORRIFIC_POTION_TIMER_WIDTH

    local bar_holder = CreateFrame("Frame", nil, self)
    self.bar_holder = bar_holder
    bar_holder:SetSize(w, 10)  -- Width is time bar width; height is arbitrary.
    bar_holder:SetPoint("TOP", name_label, "BOTTOM", 0, -2)

    local time_bar = bar_holder:CreateTexture(nil, "ARTWORK")
    self.time_bar = time_bar
    time_bar:SetSize(w, 2)
    time_bar:SetPoint("TOPRIGHT")

    local time_label = bar_holder:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    self.time_label = time_label
    time_label:SetWidth(w)
    time_label:SetJustifyH("CENTER")
    time_label:SetTextScale(1.0)
    time_label:SetText("0:00")
    time_label:SetPoint("TOPRIGHT", time_bar, "BOTTOMRIGHT", 0, -1)

    local breath_bar = bar_holder:CreateTexture(nil, "ARTWORK")
    self.breath_bar = breath_bar
    breath_bar:SetSize(w, 2)
    breath_bar:SetPoint("TOPRIGHT", time_label, "BOTTOMRIGHT", 0, -1)
    breath_bar:SetColorTexture(1, 0.5, 0)

    -- The frame's own height doesn't matter except for bottom-relative
    -- positioning, but _some_ value has to be set or the frame isn't
    -- rendered at all. We might as well make a good approximation.
    self:SetHeight(name_label:GetHeight() + 3 + time_label:GetHeight() + 3)

    self:SetSpell(nil)
end

function HorrificPotion:OnMouseDown(button)
    if button == "LeftButton" then
        self.tracker:RecordColor(self.color, SPELL_NOXIOUS_MIXTURE, true)
    end
end

-- Pass nil to reset the instance to its initial state (spell unknown).
-- Pass force=true to suppress mismatch error (for explicit user actions).
function HorrificPotion:SetSpell(spell, force)
    assert(force or not spell or not self.spell or spell == self.spell)
    self.spell = spell
    if spell then
        self.name_label:SetText(SPELL_TEXT[spell] or "!!!")
    else
        self.name_label:SetText("???")
    end
    self:SetWidth(max(self.name_label:GetWidth(), HORRIFIC_POTION_TIMER_WIDTH))
    self:Update(true)
end

-- Call when a spicy breath attack occurs.
function HorrificPotion:NotifyBreath()
    self.breath_timer = SPICY_BREATH_INTERVAL
end

-- Call once per frame (or other desired update interval)
function HorrificPotion:Update(force_refresh)
    local spell = self.spell
    local aura = spell and C_UnitAuras.GetPlayerAuraBySpellID(spell)
    local aura_instance = aura and aura.auraInstanceID
    if force_refresh or aura_instance ~= self.aura then
        local is_new = not self.aura
        self.aura = aura_instance
        self.remaining = nil
        self.time_color = nil
        if aura_instance then
            self.time_bar:Show()
            self.time_label:Show()
            if spell == SPELL_SPICY_POTION then
                self.breath_bar:Show()
                if is_new then
                    self:NotifyBreath()
                end
            else
            end
        else
            self.time_bar:Hide()
            self.time_label:Hide()
            self.breath_bar:Hide()
        end
    end

    if not aura then
        self.last_ts = nil
        self.breath_timer = nil
    else
        local WIDTH = HORRIFIC_POTION_TIMER_WIDTH
        local now = GetTime()
        local dt = now - (self.last_ts or now)
        self.last_ts = now
        assert(aura.expirationTime)
        local timeMod = aura.timeMod
        local remaining = floor((aura.expirationTime - now) / timeMod)
        local minutes = floor(remaining/60)
        if remaining < 0 then remaining = 0 end
        if remaining ~= self.remaining then
            self.remaining = remaining
            local rel_width = clamp(remaining / (5*60-1), 0, 1)
            self.time_bar:SetWidth(WIDTH * rel_width)
            local time_text
            if minutes >= 10 then
                time_text = strformat("%dm", minutes)
            else
                time_text = strformat("%d:%02d", minutes, remaining%60)
            end
            self.time_label:SetText(time_text)
            local color
            if minutes >= 5 then
                color = GREEN_FONT_COLOR
            elseif minutes >= 1 then
                color = YELLOW_FONT_COLOR
            else
                color = RED_FONT_COLOR
            end
            if color ~= self.time_color then
                self.time_color = color
                local r, g, b = color:GetRGB()
                self.time_bar:SetColorTexture(r, g, b)
                self.time_label:SetTextColor(r, g, b)
            end
        end
        local breath_timer = self.breath_timer
        if breath_timer then
            breath_timer = breath_timer - (dt / timeMod)
            self.breath_timer = breath_timer
            local rel_w = clamp(breath_timer / SPICY_BREATH_INTERVAL, 0, 1)
            self.breath_bar:SetWidth(WIDTH * rel_w)
        end
    end
end

------------------------------------------------------------------------

local HorrificPotionsTracker = class(Frame)

function HorrificPotionsTracker.__allocator(thisclass)
    return Frame.__allocator("Frame", "HorrificPotionsTrackerFrame", UIParent)
end

function HorrificPotionsTracker:__constructor()
    self.cast_id = nil
    self.cast_color = nil
    self.spicy_color = nil
    self.labels = {}

    -- It turns out the "randomization" of potion colors is just a
    -- randomized starting point in a fixed order, so if we know one
    -- we can set them all.  This lookup table is used by RecordColor()
    -- to find the potion mapping.
    local SPELL_ORDER = {SPELL_NOXIOUS_MIXTURE,
                         SPELL_FERMENTED_MIXTURE,
                         SPELL_SICKENING_POTION,
                         SPELL_SLUGGISH_POTION,
                         SPELL_SPICY_POTION}
    local SPELL_COLOR_ORDER = {"Green", "Red", "Blue", "Purple", "Black"}
    self.POTION_MAP = {}
    for i, color in ipairs(SPELL_COLOR_ORDER) do
        local spell_table = {}
        for j, spell in ipairs(SPELL_ORDER) do
            local map = {}
            for k = 0, 4 do
                tinsert(map, {SPELL_COLOR_ORDER[((i-1)+k)%5+1],
                              SPELL_ORDER[((j-1)+k)%5+1]})
            end
            spell_table[spell] = map
        end
        self.POTION_MAP[color] = spell_table
    end

    -- These values are arbitrary, but this call is required for the frame
    -- to show.  The size will be set correctly in Recenter().
    self:SetSize(1, 1)

    self:SetPoint("BOTTOM", 0, 2)
    self:RegisterEvent("PLAYER_ENTERING_WORLD")
    self:RegisterEvent("ZONE_CHANGED")
    self:RegisterEvent("ZONE_CHANGED_INDOORS")
    self:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
    self:RegisterEvent("SPELL_UPDATE_COOLDOWN")
    self:RegisterUnitEvent("UNIT_AURA", "player")
    self:RegisterEvent("UNIT_SPELLCAST_SENT")
    self:RegisterEvent("UNIT_SPELLCAST_STOP")
    self:RegisterEvent("UNIT_SPELLCAST_SUCCEEDED")
    self:SetScript("OnEvent", self.OnEvent)

    local last
    for _, color in ipairs(HORRIFIC_POTION_COLOR_ORDER) do
        local label = HorrificPotion(color, self)
        self.labels[color] = label
        if last then
            label:SetPoint("LEFT", last, "RIGHT", 20, 0)
        else
            label:SetPoint("LEFT")
        end
        last = label
    end

    self:Recenter()
    self:Update()
end

function HorrificPotionsTracker:OnEvent(event, ...)
    if event == "PLAYER_ENTERING_WORLD" then
        self:ClearCast()
        for _, label in pairs(self.labels) do
            label:SetSpell(nil)
        end
        self:Recenter()
        self.spicy_color = nil
        self:CheckMap()
    elseif event == "ZONE_CHANGED" or event == "ZONE_CHANGED_INDOORS" then
        self:CheckMap()
    elseif event == "SPELL_UPDATE_COOLDOWN" then
        local spell = ...
        if spell == SPELL_SPICY_BREATH then
            if self.spicy_color then
                self.labels[self.spicy_color]:NotifyBreath()
            end
        end
    elseif event == "UNIT_SPELLCAST_SENT" then
        local unit, name, id, spell = ...
        if unit == "player" and spell == SPELL_DRINKING_MYSTERIOUS_VIAL then
            local s1 = "Vial of Mysterious "
            local s2 = " Liquid"
            if strsub(name, 1, strlen(s1)) == s1 and strsub(name, -strlen(s2)) == s2 then
                self.cast_id = id
                self.cast_state = "sent"
                self.cast_color =
                    strsub(name, strlen(s1)+1, strlen(name)-strlen(s2))
            end
        end
    elseif not self.cast_id then
        return
    elseif event == "UNIT_SPELLCAST_STOP" then
        local unit, id, spell = ...
        if unit == "player" and id == self.cast_id then
            if self.cast_state == "sent" then  -- i.e. not "succeeded"
                self:ClearCast()
            end
        end
    elseif event == "UNIT_SPELLCAST_SUCCEEDED" then
        local unit, id, spell = ...
        if unit == "player" and id == self.cast_id then
            assert(self.cast_state == "sent")
            self.cast_state = "succeeded"
        end
    elseif event == "COMBAT_LOG_EVENT_UNFILTERED" then
        local timestamp, type, hidden_source, source, source_name,
              source_flags, source_raid_flags, dest, dest_name, dest_flags,
              dest_raid_flags, spell = CombatLogGetCurrentEventInfo()
        if band(source_flags, AFFILIATION_MINE) ~= 0 and band(source_flags, TYPE_PLAYER) ~= 0 then
            if spell == SPELL_FERMENTED_MIXTURE or spell == SPELL_NOXIOUS_MIXTURE then
                local color = self.cast_color
                self:ClearCast()
                self:RecordColor(color, spell)
            end
        end
    elseif event == "UNIT_AURA" then
        local unit, info = ...
        if unit == "player" and self.cast_state == "succeeded" then
            local color = self.cast_color
            self:ClearCast()
            assert(info)
            assert(not info.isFullUpdate)
            -- The potion aura could still get merged with other aura
            -- updates, so we have to explicitly search for it.
            local spell
            if info.addedAuras then
                for _, aura in ipairs(info.addedAuras) do
                    if SPELL_TEXT[aura.spellId] then  -- i.e. if a potion
                        spell = aura.spellId
                        break
                    end
                end
            end
            if not spell and info.updatedAuraInstanceIDs then
                for _, instance in ipairs(info.updatedAuraInstanceIDs) do
                    local aura =
                        C_UnitAuras.GetAuraDataByAuraInstanceID(unit, instance)
                    assert(aura)
                    if SPELL_TEXT[aura.spellId] then
                        spell = aura.spellId
                        break
                    end
                end
            end
            assert(spell)
            self:RecordColor(color, spell)
        end
    end
end

function HorrificPotionsTracker:CheckMap()
    local map = C_Map.GetBestMapForUnit("player")
    if map == 1469  -- Orgrimmar (original)
    or map == 1470  -- Stormwind (original)
    or map == 2403  -- Orgrimmar (11.1 revisit)
    or map == 2404  -- Stormwind (11.1 revisit)
    then
        self:Toggle(true)
        self:Show()
        self:Update()
    else
        self:Toggle(false)
        self:Hide()
    end
end

function HorrificPotionsTracker:ClearCast()
    self.cast_id = nil
    self.cast_state = nil
    self.cast_color = nil
end

-- Pass force=true to suppress mismatch error (for explicit user actions).
function HorrificPotionsTracker:RecordColor(color, spell, force)
    for _, pair in ipairs(self.POTION_MAP[color][spell]) do
        local c, s = unpack(pair)
        self.labels[c]:SetSpell(s, force)
        if s == SPELL_SPICY_POTION then
            self.spicy_color = c
        end
    end
    self:Recenter()
end

function HorrificPotionsTracker:Recenter()
    local order = HORRIFIC_POTION_COLOR_ORDER
    local first = self.labels[order[1]]
    local last = self.labels[order[#order]]
    self:SetSize(last:GetRight() - first:GetLeft(),
                 first:GetTop() - first:GetBottom())
end

function HorrificPotionsTracker:Update()
    if not self:IsShown() then return end

    -- Use a frequency that's just fast enough for smooth bar updates.
    C_Timer.After(0.1, function() self:Update() end)

    for _, label in pairs(self.labels) do
        label:Update()
    end
end

-- Pass state=true to force the window on, false to force it off,
-- nil to toggle the current state.
function HorrificPotionsTracker:Toggle(state)
    if state == nil then
        state = not self:IsShown()
    end
    if state then
        self:Show()
        self:Update()
    else
        self:Hide()
    end
end

------------------------------------------------------------------------

local tracker

local function SlashCmdHandler(arg)
    if not arg or arg == "" then
        tracker:Toggle()
    end
end

local function init()
    tracker = HorrificPotionsTracker()

    SLASH_HPT1 = "/hpt"
    SlashCmdList["HPT"] = SlashCmdHandler
    SlashCmdHelp = SlashCmdHelp or {}
    SlashCmdHelp["HPT"] = {
        help = "Toggle the Horrific Potions Tracker display on or off."}
end

local frame = CreateFrame("Frame")
frame:RegisterEvent("ADDON_LOADED")
frame:SetScript("OnEvent", function(self, event, arg1, ...)
    if event == "ADDON_LOADED" and arg1 == module_name then init() end
end)
