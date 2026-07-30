-- BlasterMaster/Options.lua
-- In-game Interface Options panel: per-alert sound picker, HUD toggles, low-HP slider.
-- TBC Classic 2.5.6 API: InterfaceOptions_AddCategory.

local ADDON_NAME = "BlasterMaster"

-- Static enumeration of shipped SFX files (Lua can't ls a dir).
local AUDIO_DIR = "Interface\\AddOns\\BlasterMaster\\Media\\Audio\\"
local AUDIO_FILES = {}
for i = 1, 37 do
  AUDIO_FILES[i] = string.format("Blaster Master SFX (%d).wav", i)
end

-- Roles in display order.
local ROLES = {
  { key = "laser",      label = "Enter Combat"    },
  { key = "siren",      label = "Low HP Alarm"    },
  { key = "oneUp",      label = "Kill Jingle"     },
  { key = "fanfare",    label = "Level Up"        },
  { key = "crit",       label = "Crit"            },
}

-- Defaults (must match the SFX table in BlasterMaster.lua).
local DEFAULT_SFX_MAP = {
  laser      = "Blaster Master SFX (1).wav",
  siren      = "Blaster Master SFX (14).wav",
  oneUp      = "Blaster Master SFX (29).wav",
  fanfare    = "Blaster Master SFX (33).wav",
  crit       = "Blaster Master SFX (9).wav",
}

-- Public accessor: called by BlasterMaster.lua's playSFX() to resolve the current mapping.
function BlasterMaster_GetSfxPath(roleKey)
  local db = BlasterMasterDB or {}
  local mapping = (db.sfxMap and db.sfxMap[roleKey]) or DEFAULT_SFX_MAP[roleKey]
  if not mapping then return nil end
  return AUDIO_DIR .. mapping
end

local function ensureDBDefaults()
  BlasterMasterDB = BlasterMasterDB or {}
  BlasterMasterDB.sfxMap = BlasterMasterDB.sfxMap or {}
  for k, v in pairs(DEFAULT_SFX_MAP) do
    if not BlasterMasterDB.sfxMap[k] then BlasterMasterDB.sfxMap[k] = v end
  end
end

-- ---------- panel construction ----------

local panel -- the frame we register
local settingsCategory

local function registerPanel(optionsPanel)
  if Settings and Settings.RegisterCanvasLayoutCategory and Settings.RegisterAddOnCategory then
    settingsCategory = Settings.RegisterCanvasLayoutCategory(optionsPanel, ADDON_NAME)
    Settings.RegisterAddOnCategory(settingsCategory)
  elseif InterfaceOptions_AddCategory then
    InterfaceOptions_AddCategory(optionsPanel)
  end
end

local function makeCheckbox(parent, label, x, y, getter, setter)
  local cb = CreateFrame("CheckButton", nil, parent, "InterfaceOptionsCheckButtonTemplate")
  cb:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
  cb.Text:SetText(label)
  cb:SetScript("OnShow", function(self) self:SetChecked(getter()) end)
  cb:SetScript("OnClick", function(self) setter(self:GetChecked() and true or false) end)
  return cb
end

local function makeDropdown(parent, roleKey, roleLabel, x, y)
  local label = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  label:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
  label:SetText(roleLabel)

  local dd = CreateFrame("Frame", "BlasterMasterDropdown_" .. roleKey, parent, "UIDropDownMenuTemplate")
  dd:SetPoint("TOPLEFT", parent, "TOPLEFT", x - 16, y - 18)
  UIDropDownMenu_SetWidth(dd, 200)

  local function setValue(idx)
    local fname = AUDIO_FILES[idx]
    ensureDBDefaults()
    BlasterMasterDB.sfxMap[roleKey] = fname
    UIDropDownMenu_SetSelectedValue(dd, idx)
    UIDropDownMenu_SetText(dd, string.format("SFX %d", idx))
  end

  UIDropDownMenu_Initialize(dd, function(self, level)
    for i = 1, #AUDIO_FILES do
      local info = UIDropDownMenu_CreateInfo()
      info.text = string.format("SFX %d", i)
      info.value = i
      info.func = function() setValue(i) end
      info.checked = (BlasterMasterDB and BlasterMasterDB.sfxMap and
                      BlasterMasterDB.sfxMap[roleKey] == AUDIO_FILES[i])
      UIDropDownMenu_AddButton(info, level)
    end
  end)

  -- initial selection
  dd:SetScript("OnShow", function(self)
    ensureDBDefaults()
    local current = BlasterMasterDB.sfxMap[roleKey]
    for i = 1, #AUDIO_FILES do
      if AUDIO_FILES[i] == current then
        UIDropDownMenu_SetSelectedValue(dd, i)
        UIDropDownMenu_SetText(dd, string.format("SFX %d", i))
        return
      end
    end
    UIDropDownMenu_SetText(dd, "SFX ?")
  end)

  -- preview button
  local preview = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
  preview:SetSize(72, 22)
  preview:SetPoint("LEFT", dd, "RIGHT", -8, 3)
  preview:SetText("Preview")
  preview:SetScript("OnClick", function()
    local path = BlasterMaster_GetSfxPath(roleKey)
    if path then PlaySoundFile(path, "Master") end
  end)

  return dd, preview
end

local function makeSlider(parent, label, x, y, minV, maxV, step, getter, setter)
  local s = CreateFrame("Slider", "BlasterMasterSlider_" .. label:gsub("%s+", ""), parent,
                        "OptionsSliderTemplate")
  s:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
  s:SetMinMaxValues(minV, maxV)
  s:SetValueStep(step)
  s:SetObeyStepOnDrag(true)
  s:SetWidth(200)
  _G[s:GetName() .. "Text"]:SetText(label)
  _G[s:GetName() .. "Low"]:SetText(tostring(minV))
  _G[s:GetName() .. "High"]:SetText(tostring(maxV))
  local val = _G[s:GetName() .. "Text"]
  s:SetScript("OnShow", function(self) self:SetValue(getter()) end)
  s:SetScript("OnValueChanged", function(self, v)
    setter(v)
    val:SetText(string.format("%s: %d%%", label, math.floor(v * 100)))
  end)
  return s
end

local function buildPanel()
  if panel then return panel end
  panel = CreateFrame("Frame", "BlasterMasterOptionsPanel", UIParent)
  panel.name = ADDON_NAME

  local title = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
  title:SetPoint("TOPLEFT", 16, -16)
  title:SetText("BlasterMaster")

  local subtitle = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  subtitle:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -8)
  subtitle:SetJustifyH("LEFT")
  subtitle:SetWidth(500)
  subtitle:SetText("NES Blaster Master-inspired retro combat HUD. Pick a sound for each alert; hit Preview to audition.")

  -- toggles
  local cbEnabled = makeCheckbox(panel, "HUD enabled", 16, -70,
    function() return BlasterMasterDB and BlasterMasterDB.enabled end,
    function(v) BlasterMasterDB.enabled = v end)

  local cbMuted = makeCheckbox(panel, "Mute all sounds", 16, -95,
    function() return BlasterMasterDB and BlasterMasterDB.muted end,
    function(v) BlasterMasterDB.muted = v end)

  local cbCrit = makeCheckbox(panel, "Crit audio enabled", 16, -120,
    function() return BlasterMasterDB and BlasterMasterDB.critAudioEnabled end,
    function(v) BlasterMasterDB.critAudioEnabled = v end)

  -- low HP slider
  makeSlider(panel, "Low HP Threshold", 16, -160, 0.05, 0.95, 0.05,
    function() return (BlasterMasterDB and BlasterMasterDB.lowHpThreshold) or 0.25 end,
    function(v) BlasterMasterDB.lowHpThreshold = v end)

  -- dropdowns
  local header = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
  header:SetPoint("TOPLEFT", 16, -220)
  header:SetText("Alert Sounds")

  local y = -250
  for _, role in ipairs(ROLES) do
    makeDropdown(panel, role.key, role.label, 32, y)
    y = y - 50
  end

  -- default button
  local resetBtn = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
  resetBtn:SetSize(140, 22)
  resetBtn:SetPoint("TOPLEFT", 16, y - 20)
  resetBtn:SetText("Reset sounds")
  resetBtn:SetScript("OnClick", function()
    ensureDBDefaults()
    for k, v in pairs(DEFAULT_SFX_MAP) do BlasterMasterDB.sfxMap[k] = v end
    -- refresh open dropdowns
    for _, role in ipairs(ROLES) do
      local dd = _G["BlasterMasterDropdown_" .. role.key]
      if dd and dd:IsShown() then dd:GetScript("OnShow")(dd) end
    end
    print("|cff1e5ab4[BlasterMaster]|r sound mappings reset to defaults.")
  end)

  panel.okay    = function() end
  panel.cancel  = function() end
  panel.default = function() resetBtn:GetScript("OnClick")(resetBtn) end
  panel.refresh = function() end

  registerPanel(panel)
  return panel
end

-- Open the panel programmatically. TBC-classic calls this twice to work around
-- the classic "first-open focuses parent" bug.
function BlasterMaster_OpenOptions()
  buildPanel()
  if settingsCategory and Settings and Settings.OpenToCategory then
    Settings.OpenToCategory(settingsCategory:GetID())
  elseif InterfaceOptionsFrame_OpenToCategory then
    InterfaceOptionsFrame_OpenToCategory(panel)
    InterfaceOptionsFrame_OpenToCategory(panel)
  end
end

-- Build panel on PLAYER_LOGIN so all globals are available.
local f = CreateFrame("Frame")
f:RegisterEvent("PLAYER_LOGIN")
f:SetScript("OnEvent", function()
  ensureDBDefaults()
  buildPanel()
end)
