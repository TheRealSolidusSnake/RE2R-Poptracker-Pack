-- zone codes pushed by the RE2 client (AutoTab.lua) -> PopTracker tab titles
-- ActivateTab is called for each entry in order (parent, then child).
AUTOTAB_MAPPING = {
    ["rpd_1f"] = { "RPD", "First Floor" },
    ["rpd_2f"] = { "RPD", "Second Floor" },
    ["rpd_3f"] = { "RPD", "Third/Fourth Floor" },
    ["rpd_basement"] = { "RPD", "Basement" },
    ["rpd_outside"] = { "RPD", "Streets" },

    -- Claire orphanage zones fall back to Streets on Leon tracker
    ["orphanage_1f"] = { "RPD", "Streets" },
    ["orphanage_2f"] = { "RPD", "Streets" },
    ["orphanage_b1"] = { "RPD", "Streets" },

    ["uf_upper"] = { "Underground Facility", "UF Upper" },
    ["uf_middle"] = { "Underground Facility", "UF Middle" },
    ["uf_lower"] = { "Underground Facility", "UF Lower" },

    ["sewers_entrance"] = { "Sewers", "Entrance" },
    ["sewers_upper"] = { "Sewers", "S Upper" },
    ["sewers_middle"] = { "Sewers", "S Middle" },
    ["sewers_lower"] = { "Sewers", "S Lower" },

    ["lab_b1"] = { "Laboratory", "B1" },
    ["lab_b2_east"] = { "Laboratory", "B2 East" },
    ["lab_b2_west"] = { "Laboratory", "B2 West" },
    ["lab_b3"] = { "Laboratory", "B3" },
    ["lab_b4"] = { "Laboratory", "Train"},
}
