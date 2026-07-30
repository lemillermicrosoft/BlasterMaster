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

local VOLUME_LEVELS = { 0.25, 0.50, 0.75, 1, 2, 3 }

local function getVolumeIndex(volume)
  local closestIndex = 1
  local closestDistance = math.huge
  for index, level in ipairs(VOLUME_LEVELS) do
    local distance = math.abs(level - volume)
    if distance < closestDistance then
      closestIndex = index
      closestDistance = distance
    end
  end
  return closestIndex
end

-- Roles in display order.
local ROLES = {
  { key = "combatStart", label = "Enter Combat"            },
  { key = "combatEnd",   label = "Leave Combat"            },
  { key = "meleeHit",    label = "Melee Hit"               },
  { key = "spellHit",    label = "Spell / Ability Hit"     },
  { key = "dotApplied",  label = "DoT / Debuff Applied"    },
  { key = "dotHit",      label = "DoT Tick"                 },
  { key = "crit",        label = "Critical Hit"             },
  { key = "lowHp",       label = "Low HP Alarm"             },
  { key = "kill",        label = "Kill Jingle"              },
  { key = "levelUp",     label = "Level Up"                 },
  { key = "boss",        label = "Boss / Elite Targeted"    },
}

-- False defaults keep new high-frequency alerts silent until configured.
local DEFAULT_SFX_MAP = {
  combatStart = "Blaster Master SFX (1).wav",
  combatEnd   = false,
  meleeHit    = false,
  spellHit    = false,
  dotApplied  = false,
  dotHit      = false,
  crit        = "Blaster Master SFX (9).wav",
  lowHp       = "Blaster Master SFX (14).wav",
  kill        = "Blaster Master SFX (29).wav",
  levelUp     = "Blaster Master SFX (33).wav",
  boss        = "Blaster Master SFX (1).wav",
}

local LEGACY_SFX_KEYS = {
  combatStart = "laser",
  lowHp = "siren",
  kill = "oneUp",
  levelUp = "fanfare",
}

-- Public accessor: called by BlasterMaster.lua's playSFX() to resolve the current mapping.
function BlasterMaster_GetSfxPath(roleKey)
  local db = BlasterMasterDB or {}
  local mapping = db.sfxMap and db.sfxMap[roleKey]
  if mapping == nil then mapping = DEFAULT_SFX_MAP[roleKey] end
  if not mapping or mapping == "none" then return nil end

  local volume = (db.sfxVolume and db.sfxVolume[roleKey]) or 1
  local volumeLevel = VOLUME_LEVELS[getVolumeIndex(volume)]
  if volumeLevel ~= 1 then
    return AUDIO_DIR .. "Volume\\" .. (volumeLevel * 100) .. "\\" .. mapping
  end
  return AUDIO_DIR .. mapping
end

local function ensureDBDefaults()
  BlasterMasterDB = BlasterMasterDB or {}
  BlasterMasterDB.sfxMap = BlasterMasterDB.sfxMap or {}
  BlasterMasterDB.sfxVolume = BlasterMasterDB.sfxVolume or {}

  for newKey, oldKey in pairs(LEGACY_SFX_KEYS) do
    if BlasterMasterDB.sfxMap[newKey] == nil and BlasterMasterDB.sfxMap[oldKey] ~= nil then
      BlasterMasterDB.sfxMap[newKey] = BlasterMasterDB.sfxMap[oldKey]
    end
  end

  for k, v in pairs(DEFAULT_SFX_MAP) do
    if BlasterMasterDB.sfxMap[k] == nil then BlasterMasterDB.sfxMap[k] = v end
    if BlasterMasterDB.sfxVolume[k] == nil then BlasterMasterDB.sfxVolume[k] = 1 end
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
    ensureDBDefaults()
    if idx then
      BlasterMasterDB.sfxMap[roleKey] = AUDIO_FILES[idx]
      UIDropDownMenu_SetSelectedValue(dd, idx)
      UIDropDownMenu_SetText(dd, string.format("SFX %d", idx))
    else
      BlasterMasterDB.sfxMap[roleKey] = false
      UIDropDownMenu_SetSelectedValue(dd, "none")
      UIDropDownMenu_SetText(dd, "None")
    end
  end

  UIDropDownMenu_Initialize(dd, function(self, level)
    local noneInfo = UIDropDownMenu_CreateInfo()
    noneInfo.text = "None"
    noneInfo.value = "none"
    noneInfo.func = function() setValue(nil) end
    noneInfo.checked = BlasterMasterDB and BlasterMasterDB.sfxMap and
                       not BlasterMasterDB.sfxMap[roleKey]
    UIDropDownMenu_AddButton(noneInfo, level)

    for i = 1, #AUDIO_FILES do
      local soundIndex = i
      local info = UIDropDownMenu_CreateInfo()
      info.text = string.format("SFX %d", i)
      info.value = i
      info.func = function() setValue(soundIndex) end
      info.checked = (BlasterMasterDB and BlasterMasterDB.sfxMap and
                      BlasterMasterDB.sfxMap[roleKey] == AUDIO_FILES[i])
      UIDropDownMenu_AddButton(info, level)
    end
  end)

  -- initial selection
  dd:SetScript("OnShow", function(self)
    ensureDBDefaults()
    local current = BlasterMasterDB.sfxMap[roleKey]
    if not current then
      UIDropDownMenu_SetSelectedValue(dd, "none")
      UIDropDownMenu_SetText(dd, "None")
      return
    end
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
  preview:SetText("Play")
  preview:SetScript("OnClick", function()
    local path = BlasterMaster_GetSfxPath(roleKey)
    if path then PlaySoundFile(path, "Master") end
  end)

  return dd, preview
end

local function makeVolumeSlider(parent, roleKey, x, y)
  local name = "BlasterMasterVolumeSlider_" .. roleKey
  local slider = CreateFrame("Slider", name, parent, "OptionsSliderTemplate")
  slider:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
  slider:SetMinMaxValues(1, #VOLUME_LEVELS)
  slider:SetValueStep(1)
  slider:SetObeyStepOnDrag(true)
  slider:SetWidth(180)
  _G[name .. "Low"]:SetText("25%")
  _G[name .. "High"]:SetText("300%")

  local label = _G[name .. "Text"]
  slider:SetScript("OnShow", function(self)
    ensureDBDefaults()
    self:SetValue(getVolumeIndex(BlasterMasterDB.sfxVolume[roleKey]))
  end)
  slider:SetScript("OnValueChanged", function(self, index)
    ensureDBDefaults()
    local volume = VOLUME_LEVELS[math.floor(index + 0.5)]
    BlasterMasterDB.sfxVolume[roleKey] = volume
    label:SetText(string.format("Volume: %d%%", volume * 100))
  end)
  return slider
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
  subtitle:SetText("Pick a sound and volume for each action. Choose None to disable an action; hit Play to audition it.")

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

  -- sound action rows
  local header = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
  header:SetPoint("TOPLEFT", 16, -220)
  header:SetText("Action Sounds")

  local scroll = CreateFrame("ScrollFrame", "BlasterMasterSoundScrollFrame", panel,
                             "UIPanelScrollFrameTemplate")
  scroll:SetPoint("TOPLEFT", panel, "TOPLEFT", 16, -245)
  scroll:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", -30, 16)

  local content = CreateFrame("Frame", nil, scroll)
  content:SetSize(620, (#ROLES * 64) + 48)
  scroll:SetScrollChild(content)

  local y = -8
  for _, role in ipairs(ROLES) do
    makeDropdown(content, role.key, role.label, 8, y)
    makeVolumeSlider(content, role.key, 330, y - 20)
    y = y - 64
  end

  -- default button
  local resetBtn = CreateFrame("Button", nil, content, "UIPanelButtonTemplate")
  resetBtn:SetSize(180, 22)
  resetBtn:SetPoint("TOPLEFT", content, "TOPLEFT", 8, y)
  resetBtn:SetText("Reset sounds and volumes")
  resetBtn:SetScript("OnClick", function()
    ensureDBDefaults()
    for k, v in pairs(DEFAULT_SFX_MAP) do
      BlasterMasterDB.sfxMap[k] = v
      BlasterMasterDB.sfxVolume[k] = 1
    end
    -- refresh open dropdowns
    for _, role in ipairs(ROLES) do
      local dd = _G["BlasterMasterDropdown_" .. role.key]
      if dd and dd:IsShown() then dd:GetScript("OnShow")(dd) end
      local slider = _G["BlasterMasterVolumeSlider_" .. role.key]
      if slider then slider:SetValue(getVolumeIndex(1)) end
    end
    print("|cff1e5ab4[BlasterMaster]|r sound mappings and volumes reset to defaults.")
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
