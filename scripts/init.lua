-- get current variant
local variant = Tracker.ActiveVariantUID
-- check variant info
IS_ITEMS_ONLY = variant:find("ItemsOnly")

-- Items
require("scripts/items_import")

-- Logic
require("scripts/logic/logic_helper")
require("scripts/logic/logic_main")

if not IS_ITEMS_ONLY then -- <--- use variant info to optimize loading
    -- Maps
    Tracker:AddMaps("maps/maps.json")    
    -- Locations
    Tracker:AddLocations("locations/R First Floor.json")
    Tracker:AddLocations("locations/R Second Floor.json")
    Tracker:AddLocations("locations/R Third Floor.json")
    Tracker:AddLocations("locations/UF Upper.json")
    Tracker:AddLocations("locations/UF Middle.json")
    Tracker:AddLocations("locations/UF Lower.json")
    Tracker:AddLocations("locations/R Basement.json")
    Tracker:AddLocations("locations/Outside RPD.json")
    Tracker:AddLocations("locations/S Entrance.json")
    Tracker:AddLocations("locations/S Upper.json")
    Tracker:AddLocations("locations/S Middle.json")
    Tracker:AddLocations("locations/S Lower.json")
    Tracker:AddLocations("locations/L B1.json")
    Tracker:AddLocations("locations/L B2 East.json")
    Tracker:AddLocations("locations/L B2 West.json")
    Tracker:AddLocations("locations/L B3.json")
end

-- Layout
require("scripts/layouts_import")

-- AutoTracking for Poptracker
if PopVersion and PopVersion >= "0.26.0" then
    require("scripts/autotracking")
end