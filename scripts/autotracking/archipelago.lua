
require("scripts/autotracking/item_mapping")
require("scripts/autotracking/location_mapping")
require("scripts/autotracking/hints_mapping")
require("scripts/autotracking/autotab_mapping")

CUR_INDEX = -1
--SLOT_DATA = nil

SLOT_DATA = {}
AUTOTAB_KEY = nil

local highlight_lvl= {
    [0] = Highlight.Unspecified,
    [10] = Highlight.NoPriority,
    [20] = Highlight.Avoid,
    [30] = Highlight.Priority,
    [40] = Highlight.None,
}

function has_value (t, val)
    for i, v in ipairs(t) do
        if v == val then return 1 end
    end
    return 0
end

function dump_table(o, depth)
    if depth == nil then
        depth = 0
    end
    if type(o) == 'table' then
        local tabs = ('\t'):rep(depth)
        local tabs2 = ('\t'):rep(depth + 1)
        local s = '{'
        for k, v in pairs(o) do
            if type(k) ~= 'number' then
                k = '"' .. k .. '"'
            end
            s = s .. tabs2 .. '[' .. k .. '] = ' .. dump_table(v, depth + 1) .. ','
        end
        return s .. tabs .. '}'
    else
        return tostring(o)
    end
end

function forceUpdate()
    local update = Tracker:FindObjectForCode("update")
    if update then
        update.Active = not update.Active
    end
end

-- Watched by onClearHandler; keep a real function so AddWatchForCode never errors.
function StateChange(code)
end

local function resetMappedItem(item_code)
    local item_obj = Tracker:FindObjectForCode(item_code)
    if not item_obj then
        return
    end
    if item_obj.Type == "toggle" then
        item_obj.Active = false
    elseif item_obj.Type == "progressive" then
        item_obj.CurrentStage = 0
        item_obj.CurrentStage = item_obj.CurrentStage + 1
    elseif item_obj.Type == "consumable" then
        if item_obj.MinCount then
            item_obj.AcquiredCount = item_obj.MinCount
        else
            item_obj.AcquiredCount = 0
        end
    elseif item_obj.Type == "progressive_toggle" then
        item_obj.CurrentStage = 0
        item_obj.Active = false
    end
end

local function optionEnabled(value)
    if value == nil then
        return false
    end
    if type(value) == "boolean" then
        return value
    end
    if type(value) == "number" then
        return value ~= 0
    end
    local s = string.lower(tostring(value))
    return s ~= "" and s ~= "none" and s ~= "false" and s ~= "0" and s ~= "off"
end

local function setToggleActive(code, active)
    local item = Tracker:FindObjectForCode(code)
    if item then
        item.Active = active and true or false
    else
        print(string.format("applySlotDataSettings: missing toggle '%s'", tostring(code)))
    end
end

-- Fill difficulty / kill-check toggles from AP slot_data.
function applySlotDataSettings(slot_data)
    if not slot_data then
        return
    end

    local difficulty = string.lower(tostring(slot_data.difficulty or ""))
    local hardcore = difficulty == "hardcore"
    -- Assisted uses the standard location set.
    local standard = (not hardcore) and (
        difficulty == "standard" or difficulty == "assisted" or difficulty == ""
    )
    local killsOn = optionEnabled(slot_data.add_enemy_kills_as_locations)
        or optionEnabled(slot_data.enemy_kills)

    setToggleActive("standard", standard)
    setToggleActive("hardcore", hardcore)
    setToggleActive("killchecks", killsOn)

    print(string.format(
        "slot_data settings: difficulty=%s standard=%s hardcore=%s killchecks=%s (raw kills=%s)",
        tostring(slot_data.difficulty),
        tostring(standard),
        tostring(hardcore),
        tostring(killsOn),
        tostring(slot_data.add_enemy_kills_as_locations or slot_data.enemy_kills)
    ))
end

function onClearHandler(slot_data)
    local clear_timer = os.clock()
    
    ScriptHost:RemoveWatchForCode("StateChange")
    -- Disable tracker updates.
    Tracker.BulkUpdate = true
    -- Use a protected call so that tracker updates always get enabled again, even if an error occurred.
    local ok, err = pcall(onClear, slot_data)
    -- Enable tracker updates again.
    if ok then
        -- Defer re-enabling tracker updates until the next frame, which doesn't happen until all received items/cleared
        -- locations from AP have been processed.
        local handlerName = "AP onClearHandler"
        local function frameCallback()
            ScriptHost:RemoveOnFrameHandler(handlerName)
            pcall(function()
                ScriptHost:AddWatchForCode("StateChange", "*", StateChange)
            end)
            Tracker.BulkUpdate = false
            -- Re-apply after bulk update so visibility_rules refresh reliably.
            applySlotDataSettings(SLOT_DATA)
            forceUpdate()
            if _G.AUTOTAB_PENDING_ZONE then
                applyAutoTab(_G.AUTOTAB_PENDING_ZONE)
            end
            if _G.AUTOTAB_NEED_REFRESH and AUTOTAB_KEY then
                _G.AUTOTAB_NEED_REFRESH = false
                Archipelago:Get({AUTOTAB_KEY})
            end
            print(string.format("Time taken total: %.2f", os.clock() - clear_timer))
        end
        ScriptHost:AddOnFrameHandler(handlerName, frameCallback)
    else
        Tracker.BulkUpdate = false
        print("Error: onClear failed:")
        print(err)
        -- Still try to apply settings even if clear partially failed.
        SLOT_DATA = slot_data or SLOT_DATA
        applySlotDataSettings(SLOT_DATA)
        forceUpdate()
    end
end

function onClear(slot_data)
    --SLOT_DATA = slot_data
    CUR_INDEX = -1
    -- reset locations
    for _, location_array in pairs(LOCATION_MAPPING) do
        for _, location in pairs(location_array) do
            if location then
                local location_obj = Tracker:FindObjectForCode(location)
                if location_obj then
                    if location:sub(1, 1) == "@" then
                        location_obj.AvailableChestCount = location_obj.ChestCount
                    else
                        location_obj.Active = false
                    end
                end
            end
        end
    end
    -- reset items
    -- ITEM_MAPPING entries look like: [id] = { {"code", "type"} }
    for _, item_entry in pairs(ITEM_MAPPING) do
        if type(item_entry[1]) == "string" then
            resetMappedItem(item_entry[1])
        else
            for _, mapping in ipairs(item_entry) do
                if type(mapping) == "table" and type(mapping[1]) == "string" then
                    resetMappedItem(mapping[1])
                end
            end
        end
    end
    PLAYER_ID = Archipelago.PlayerNumber or -1
    TEAM_NUMBER = Archipelago.TeamNumber or 0
    SLOT_DATA = slot_data
    applySlotDataSettings(slot_data)
    -- print(PLAYER_ID, TEAM_NUMBER)
    if Archipelago.PlayerNumber > -1 then
        -- Enable Auto Tab BEFORE Get/SetNotify. Retrieved can fire synchronously
        -- during Get(); if the toggle is still off, applyAutoTab no-ops and a
        -- later SetReply may never arrive if the zone hasn't changed.
        local autotabItem = Tracker:FindObjectForCode("autotab")
        if autotabItem then
            autotabItem.Active = true
        end

        HINTS_ID = "_read_hints_"..TEAM_NUMBER.."_"..PLAYER_ID
        AUTOTAB_KEY = PLAYER_ID .. "-re2r-currentMap"
        Archipelago:SetNotify({HINTS_ID, AUTOTAB_KEY})
        Archipelago:Get({HINTS_ID, AUTOTAB_KEY})
        -- ActivateTab during BulkUpdate is unreliable; re-Get after the frame callback.
        _G.AUTOTAB_NEED_REFRESH = true
    end
end

function onItem(index, item_id, item_name, player_number)
    if index <= CUR_INDEX then
        return
    end
    local is_local = player_number == Archipelago.PlayerNumber
    CUR_INDEX = index;
    local item = ITEM_MAPPING[item_id]
    if not item or not item[1] then
        --print(string.format("onItem: could not find item mapping for id %s", item_id))
        return
    end
    for _, item_pair in pairs(item) do
        item_code = item_pair[1]
        item_type = item_pair[2]
        local item_obj = Tracker:FindObjectForCode(item_code)
        if item_obj then
            if item_obj.Type == "toggle" then
                -- print("toggle")
                item_obj.Active = true
            elseif item_obj.Type == "progressive" then
                -- print("progressive")
                item_obj.Active = true
            elseif item_obj.Type == "consumable" then
                -- print("consumable")
                item_obj.AcquiredCount = item_obj.AcquiredCount + item_obj.Increment * (tonumber(item_pair[3]) or 1)
            elseif item_obj.Type == "progressive_toggle" then
                -- print("progressive_toggle")
                if item_obj.Active then
                    item_obj.CurrentStage = item_obj.CurrentStage + 1
                else
                    item_obj.Active = true
                end
            end
        else
            print(string.format("onItem: could not find object for code %s", item_code[1]))
        end
    end
end

--called when a location gets cleared
function onLocation(location_id, location_name)
    local location_array = LOCATION_MAPPING[location_id]
    if not location_array or not location_array[1] then
        print(string.format("onLocation: could not find location mapping for id %s", location_id))
        return
    end

    for _, location in pairs(location_array) do
        local location_obj = Tracker:FindObjectForCode(location)
        -- print(location, location_obj)
        if location_obj then
            if location:sub(1, 1) == "@" then
                location_obj.AvailableChestCount = location_obj.AvailableChestCount - 1
            else
                location_obj.Active = true
            end
        else
            print(string.format("onLocation: could not find location_object for code %s", location))
        end
    end
end

function onEvent(key, value, old_value)
    updateEvents(value)
end

function onEventsLaunch(key, value)
    updateEvents(value)
end

-- this Autofill function is meant as an example on how to do the reading from slotdata and mapping the values to 
-- your own settings
-- function autoFill()
--     if SLOT_DATA == nil  then
--         print("its fucked")
--         return
--     end
--     -- print(dump_table(SLOT_DATA))

--     mapToggle={[0]=0,[1]=1,[2]=1,[3]=1,[4]=1}
--     mapToggleReverse={[0]=1,[1]=0,[2]=0,[3]=0,[4]=0}
--     mapTripleReverse={[0]=2,[1]=1,[2]=0}

--     slotCodes = {
--         map_name = {code="", mapping=mapToggle...}
--     }
--     -- print(dump_table(SLOT_DATA))
--     -- print(Tracker:FindObjectForCode("autofill_settings").Active)
--     if Tracker:FindObjectForCode("autofill_settings").Active == true then
--         for settings_name , settings_value in pairs(SLOT_DATA) do
--             -- print(k, v)
--             if slotCodes[settings_name] then
--                 item = Tracker:FindObjectForCode(slotCodes[settings_name].code)
--                 if item.Type == "toggle" then
--                     item.Active = slotCodes[settings_name].mapping[settings_value]
--                 else 
--                     -- print(k,v,Tracker:FindObjectForCode(slotCodes[k].code).CurrentStage, slotCodes[k].mapping[v])
--                     item.CurrentStage = slotCodes[settings_name].mapping[settings_value]
--                 end
--             end
--         end
--     end
-- end

function onNotify(key, value, old_value)
    print("onNotify", key, value, old_value)
    if value ~= old_value and key == HINTS_ID then
        for _, hint in ipairs(value) do
            if hint.finding_player == Archipelago.PlayerNumber then
                updateHints(hint.location, hint.status)
            end
        end
    end

    if key == AUTOTAB_KEY then
        applyAutoTab(value)
    end
end

function onNotifyLaunch(key, value)
    print("onNotifyLaunch", key, value)
    if key == HINTS_ID then
        for _, hint in ipairs(value) do
            -- print("hint", hint, hint.found)
            -- print(dump_table(hint))
            if hint.finding_player == Archipelago.PlayerNumber then
                updateHints(hint.location, hint.status)
            end
        end
    end

    if key == AUTOTAB_KEY then
        applyAutoTab(value)
    end
end

-- Game client Bounce({ re2r_map = "lab_b1", ... }) — same channel family as DeathLink.
function onBounce(message)
    print("onBounce", dump_table(message))
    if type(message) ~= "table" then
        return
    end
    local data = message.data
    if type(data) ~= "table" then
        data = message
    end
    if type(data) == "table" and data.re2r_map then
        print("autotab: bounce zone=" .. tostring(data.re2r_map))
        applyAutoTab(data.re2r_map)
    end
end

function applyAutoTab(zone)
    if zone == nil or zone == "" then
        return
    end

    -- SetReply sometimes wraps the value; unwrap common shapes.
    if type(zone) == "table" then
        zone = zone.value or zone[1] or zone
    end
    zone = tostring(zone)
    -- Client may send "lab_b1#12" so re-pushes always change storage.
    zone = zone:match("^([^#]+)") or zone

    local autotabItem = Tracker:FindObjectForCode("autotab")
    if autotabItem and not autotabItem.Active then
        print("autotab: skipped (toggle off)")
        return
    end

    if Tracker.BulkUpdate then
        print("autotab: defer during BulkUpdate zone=" .. zone)
        _G.AUTOTAB_PENDING_ZONE = zone
        return
    end

    local tabs = AUTOTAB_MAPPING[zone]
    if not tabs then
        print("autotab: unknown zone " .. zone)
        return
    end

    for _, tabName in ipairs(tabs) do
        print("autotab: ActivateTab " .. tabName)
        Tracker:UiHint("ActivateTab", tabName)
    end
    _G.AUTOTAB_PENDING_ZONE = nil
end

-- Poll DataStorage every few seconds in case SetReply was missed.
local _autotabPollAt = 0
local function autotabFrameHandler()
    if not AUTOTAB_KEY or Archipelago.PlayerNumber == nil or Archipelago.PlayerNumber < 0 then
        return
    end
    local now = os.clock()
    if now - _autotabPollAt < 2.5 then
        return
    end
    _autotabPollAt = now
    if _G.AUTOTAB_PENDING_ZONE and not Tracker.BulkUpdate then
        applyAutoTab(_G.AUTOTAB_PENDING_ZONE)
    end
    Archipelago:Get({AUTOTAB_KEY})
end

function updateHints(locationID, status) -->
    local location_table = LOCATION_MAPPING[locationID]
    for _, location in ipairs(location_table) do
        local obj = Tracker:FindObjectForCode(location)
        if obj then
            obj.Highlight = highlight_lvl[status]
        else
            print(string.format("No object found for code: %s", location))
        end
    end
    local item_codes = HINTS_MAPPING[locationID]
    
    for _, item_table in ipairs(item_codes, clear) do
        for _, item_code in ipairs(item_table) do
            local obj = Tracker:FindObjectForCode(item_code)
            if obj then
                if not clear then
                    obj.Active = true
                else
                    obj.Active = false
                end
            else
                print(string.format("No object found for code: %s", item_code))
            end
        end
    end
end


-- ScriptHost:AddWatchForCode("settings autofill handler", "autofill_settings", autoFill)
Archipelago:AddClearHandler("clear handler", onClearHandler)
Archipelago:AddItemHandler("item handler", onItem)
Archipelago:AddLocationHandler("location handler", onLocation)

Archipelago:AddSetReplyHandler("notify handler", onNotify)
Archipelago:AddRetrievedHandler("notify launch handler", onNotifyLaunch)
Archipelago:AddBouncedHandler("autotab bounce handler", onBounce)
ScriptHost:AddOnFrameHandler("autotab poll", autotabFrameHandler)
print("autotab: handlers registered (SetReply + Bounce + poll)")



--doc
--hint layout
-- {
--     ["receiving_player"] = 1,
--     ["class"] = Hint,
--     ["finding_player"] = 1,
--     ["location"] = 67361,
--     ["found"] = false,
--     ["item_flags"] = 2,
--     ["entrance"] = ,
--     ["item"] = 66062,
-- } 
