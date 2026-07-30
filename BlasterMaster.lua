-- BlasterMaster: NES Blaster Master-inspired retro combat HUD.
-- v0.1.0 scaffold: minimal load + slash command. HUD/sound features land in feat/ branches.

local ADDON_NAME = ...
local BlasterMaster = CreateFrame("Frame", "BlasterMasterFrame", UIParent)

local defaults = {
  enabled = true,
  muted = false,
  lowHpThreshold = 0.25,
  point = { "CENTER", "UIParent", "CENTER", 0, 200 },
}

local function InitDB()
  BlasterMasterDB = BlasterMasterDB or {}
  for k, v in pairs(defaults) do
    if BlasterMasterDB[k] == nil then BlasterMasterDB[k] = v end
  end
end

BlasterMaster:RegisterEvent("ADDON_LOADED")
BlasterMaster:RegisterEvent("PLAYER_LOGIN")
BlasterMaster:SetScript("OnEvent", function(self, event, arg1)
  if event == "ADDON_LOADED" and arg1 == ADDON_NAME then
    InitDB()
  elseif event == "PLAYER_LOGIN" then
    print("|cff1e5ab4[BlasterMaster]|r SOPHIA online. /blaster for commands.")
  end
end)

SLASH_BLASTERMASTER1 = "/blaster"
SLASH_BLASTERMASTER2 = "/bm"
SlashCmdList["BLASTERMASTER"] = function(msg)
  msg = (msg or ""):lower():match("^%s*(.-)%s*$")
  if msg == "toggle" then
    BlasterMasterDB.enabled = not BlasterMasterDB.enabled
    print("|cff1e5ab4[BlasterMaster]|r HUD " .. (BlasterMasterDB.enabled and "ON" or "OFF"))
  elseif msg == "mute" then
    BlasterMasterDB.muted = not BlasterMasterDB.muted
    print("|cff1e5ab4[BlasterMaster]|r sounds " .. (BlasterMasterDB.muted and "MUTED" or "ON"))
  elseif msg == "reset" then
    BlasterMasterDB.point = defaults.point
    print("|cff1e5ab4[BlasterMaster]|r HUD position reset.")
  else
    print("|cff1e5ab4[BlasterMaster]|r commands: /blaster toggle | mute | reset")
  end
end
