-- BlasterMaster: NES Blaster Master-inspired retro combat HUD.
-- MVP: ARMOR/AMMO bars, BOSS ROOM alert, 8-bit sound cues, /blaster slash.

local ADDON_NAME = ...

local defaults = {
  enabled = true,
  muted = false,
  lowHpThreshold = 0.25,
  point = { "CENTER", "UIParent", "CENTER", 0, 200 },
  critAudioEnabled = true,
}

local BM = CreateFrame("Frame", "BlasterMasterFrame", UIParent)
BM:Hide()

-- ---------- state ----------
local hud, armorBar, ammoBar, pilotLabel, bossBanner
local bossCooldown = {} -- guid -> expiry time
local lastSirenAt = 0
local wasLowHp = false
local lastActionAt = {}
local playerGUID = nil

-- ---------- helpers ----------
local WHITE_TEX = "Interface\\Buttons\\WHITE8x8"

local POWER_COLORS = {
  MANA        = { 0.2, 0.4, 1.0 },
  RAGE        = { 1.0, 0.1, 0.1 },
  ENERGY      = { 1.0, 0.9, 0.2 },
  FOCUS       = { 1.0, 0.6, 0.2 },
  RUNIC_POWER = { 0.3, 0.9, 1.0 },
  RUNES       = { 0.6, 0.6, 0.9 },
}

local SFX = {
  -- Mapped to user-provided Blaster Master SFX pack (Media/Audio/).
  -- Size-based guesses; remap via a follow-up PR once we know which sound is which.
  combatStart = "Interface\\AddOns\\BlasterMaster\\Media\\Audio\\Blaster Master SFX (1).wav",
  lowHp       = "Interface\\AddOns\\BlasterMaster\\Media\\Audio\\Blaster Master SFX (14).wav",
  kill        = "Interface\\AddOns\\BlasterMaster\\Media\\Audio\\Blaster Master SFX (29).wav",
  levelUp     = "Interface\\AddOns\\BlasterMaster\\Media\\Audio\\Blaster Master SFX (33).wav",
  crit        = "Interface\\AddOns\\BlasterMaster\\Media\\Audio\\Blaster Master SFX (9).wav",
  boss        = "Interface\\AddOns\\BlasterMaster\\Media\\Audio\\Blaster Master SFX (1).wav",
}

local function playSFX(key)
  if BlasterMasterDB and BlasterMasterDB.muted then return end
  local path
  if _G.BlasterMaster_GetSfxPath then
    path = BlasterMaster_GetSfxPath(key)
  else
    path = SFX[key]
  end
  if path then
    PlaySoundFile(path, "Master")
    return true
  end
end

local function playAction(key, cooldown)
  local now = GetTime()
  if cooldown and now - (lastActionAt[key] or 0) < cooldown then return end
  if playSFX(key) then lastActionAt[key] = now end
end

local function pixelBar(parent, w, h, r, g, b)
  local bar = CreateFrame("StatusBar", nil, parent)
  bar:SetSize(w, h)
  bar:SetStatusBarTexture(WHITE_TEX)
  bar:GetStatusBarTexture():SetHorizTile(true)
  bar:SetStatusBarColor(r, g, b, 1)
  bar:SetMinMaxValues(0, 1)
  bar:SetValue(1)

  local bg = bar:CreateTexture(nil, "BACKGROUND")
  bg:SetAllPoints(bar)
  bg:SetTexture(WHITE_TEX)
  bg:SetVertexColor(0.05, 0.05, 0.1, 0.9)

  -- 2px black border
  local function edge(a, b, c, d, ox, oy, ex, ey)
    local t = bar:CreateTexture(nil, "OVERLAY")
    t:SetTexture(WHITE_TEX)
    t:SetVertexColor(0, 0, 0, 1)
    t:SetPoint(a, bar, b, ox, oy)
    t:SetPoint(c, bar, d, ex, ey)
    return t
  end
  edge("TOPLEFT","TOPLEFT","TOPRIGHT","TOPRIGHT",0,0,0,-2)
  edge("BOTTOMLEFT","BOTTOMLEFT","BOTTOMRIGHT","BOTTOMRIGHT",0,2,0,0)
  edge("TOPLEFT","TOPLEFT","BOTTOMLEFT","BOTTOMLEFT",0,0,2,0)
  edge("TOPRIGHT","TOPRIGHT","BOTTOMRIGHT","BOTTOMRIGHT",-2,0,0,0)

  return bar
end

-- ---------- HUD build ----------
local function BuildHUD()
  if hud and armorBar and ammoBar and pilotLabel and bossBanner then return end

  local builtHud = _G.BlasterMasterHUD or CreateFrame("Frame", "BlasterMasterHUD", UIParent)
  builtHud:SetSize(240, 96)
  builtHud:SetMovable(true)
  builtHud:EnableMouse(true)
  builtHud:RegisterForDrag("LeftButton")
  builtHud:SetScript("OnDragStart", function(self) self:StartMoving() end)
  builtHud:SetScript("OnDragStop", function(self)
    self:StopMovingOrSizing()
    local p, _, rp, x, y = self:GetPoint()
    BlasterMasterDB.point = { p, "UIParent", rp, x, y }
  end)

  local bg = builtHud:CreateTexture(nil, "BACKGROUND")
  bg:SetAllPoints(builtHud)
  bg:SetTexture(WHITE_TEX)
  bg:SetVertexColor(0.02, 0.02, 0.06, 0.85)

  -- NOTE: TBC Classic 2.5.6 does not have the retail NumberFont_Outline_* font
  -- templates. Use classic-compatible NumberFontNormal* templates instead.
  local builtPilotLabel = builtHud:CreateFontString(nil, "OVERLAY", "NumberFontNormal")
  if not builtPilotLabel then
    print("|cffff5555[BlasterMaster]|r HUD build failed: pilot label unavailable.")
    return
  end
  builtPilotLabel:SetPoint("TOP", builtHud, "TOP", 0, -6)
  builtPilotLabel:SetText("PILOT")

  -- ARMOR label + bar
  local armorLbl = builtHud:CreateFontString(nil, "OVERLAY", "NumberFontNormalSmall")
  if not armorLbl then
    print("|cffff5555[BlasterMaster]|r HUD build failed: armor label unavailable.")
    return
  end
  armorLbl:SetPoint("TOPLEFT", builtHud, "TOPLEFT", 8, -30)
  armorLbl:SetText("ARMOR")

  local builtArmorBar = pixelBar(builtHud, 180, 14, 0.2, 0.9, 0.2)
  if not builtArmorBar then
    print("|cffff5555[BlasterMaster]|r HUD build failed: armor bar unavailable.")
    return
  end
  builtArmorBar:SetPoint("LEFT", armorLbl, "RIGHT", 6, 0)

  -- AMMO label + bar
  local ammoLbl = builtHud:CreateFontString(nil, "OVERLAY", "NumberFontNormalSmall")
  if not ammoLbl then
    print("|cffff5555[BlasterMaster]|r HUD build failed: ammo label unavailable.")
    return
  end
  ammoLbl:SetPoint("TOPLEFT", builtHud, "TOPLEFT", 8, -54)
  ammoLbl:SetText("AMMO ")

  local builtAmmoBar = pixelBar(builtHud, 180, 14, 0.2, 0.4, 1.0)
  if not builtAmmoBar then
    print("|cffff5555[BlasterMaster]|r HUD build failed: ammo bar unavailable.")
    return
  end
  builtAmmoBar:SetPoint("LEFT", ammoLbl, "RIGHT", 6, 0)

  -- BOSS ROOM banner (child of UIParent so it can be wider)
  local builtBossBanner = _G.BlasterMasterBossBanner or
                          CreateFrame("Frame", "BlasterMasterBossBanner", UIParent)
  builtBossBanner:SetSize(UIParent:GetWidth(), 48)
  builtBossBanner:SetPoint("TOP", UIParent, "TOP", 0, -80)
  builtBossBanner:Hide()
  local bbg = builtBossBanner:CreateTexture(nil, "BACKGROUND")
  bbg:SetAllPoints(builtBossBanner)
  bbg:SetTexture(WHITE_TEX)
  bbg:SetVertexColor(0.7, 0.05, 0.05, 0.9)
  builtBossBanner.text = builtBossBanner.text or
                         builtBossBanner:CreateFontString(nil, "OVERLAY", "NumberFontNormalHuge")
  if not builtBossBanner.text then
    print("|cffff5555[BlasterMaster]|r HUD build failed: boss banner text unavailable.")
    return
  end
  builtBossBanner.text:SetPoint("CENTER", builtBossBanner, "CENTER", 0, 0)
  builtBossBanner.text:SetText("!! BOSS ROOM !!")

  hud = builtHud
  armorBar = builtArmorBar
  ammoBar = builtAmmoBar
  pilotLabel = builtPilotLabel
  bossBanner = builtBossBanner
end

local function ApplyPoint()
  if not hud then return end
  hud:ClearAllPoints()
  local p = BlasterMasterDB.point or defaults.point
  hud:SetPoint(p[1], p[2] or "UIParent", p[3], p[4] or 0, p[5] or 0)
end

local function SetVisible(show)
  if not hud then return end
  if show then hud:Show() else hud:Hide() end
end

-- ---------- updates ----------
local function UpdateArmor()
  if not hud or not armorBar or not hud:IsShown() then return end
  local hp, hpMax = UnitHealth("player"), UnitHealthMax("player")
  if hpMax <= 0 then return end
  local pct = hp / hpMax
  armorBar:SetValue(pct)
  if pct > 0.66 then armorBar:SetStatusBarColor(0.2, 0.9, 0.2)
  elseif pct > 0.33 then armorBar:SetStatusBarColor(0.95, 0.8, 0.1)
  else armorBar:SetStatusBarColor(1.0, 0.15, 0.15) end

  -- low HP siren edge trigger
  local threshold = BlasterMasterDB.lowHpThreshold or defaults.lowHpThreshold
  if pct <= threshold and not wasLowHp then
    local now = GetTime()
    if now - lastSirenAt >= 5 then
      playSFX("lowHp")
      lastSirenAt = now
    end
    wasLowHp = true
  elseif pct > threshold + 0.05 then
    wasLowHp = false
  end
end

local function UpdateAmmo()
  if not hud or not ammoBar or not hud:IsShown() then return end
  local pType, pToken = UnitPowerType("player")
  local p, pMax = UnitPower("player"), UnitPowerMax("player")
  if pMax and pMax > 0 then
    ammoBar:SetValue(p / pMax)
  else
    ammoBar:SetValue(0)
  end
  local c = POWER_COLORS[pToken or ""] or { 0.7, 0.7, 0.9 }
  ammoBar:SetStatusBarColor(c[1], c[2], c[3])
end

local function UpdatePilot()
  if not pilotLabel then return end
  pilotLabel:SetText(string.format("PILOT: %s  LV %d", UnitName("player") or "?", UnitLevel("player") or 0))
end

-- ---------- boss detection ----------
local BOSSY = { worldboss = true, rareelite = true, elite = true, rare = true }

local function FlashBossBanner(name)
  if not bossBanner then return end
  bossBanner.text:SetText(string.format("!! BOSS ROOM !!  %s", name or ""))
  bossBanner:SetSize(UIParent:GetWidth(), 48)
  bossBanner:Show()
  playSFX("boss")
  C_Timer.After(2.0, function() if bossBanner then bossBanner:Hide() end end)
end

local function CheckTarget()
  if not UnitExists("target") or UnitIsDead("target") then return end
  local cls = UnitClassification("target")
  if not BOSSY[cls or ""] then return end
  local guid = UnitGUID("target")
  if not guid then return end
  local now = GetTime()
  if (bossCooldown[guid] or 0) > now then return end
  bossCooldown[guid] = now + 10
  FlashBossBanner(UnitName("target"))
end

-- ---------- init + events ----------
local function InitDB()
  BlasterMasterDB = BlasterMasterDB or {}
  for k, v in pairs(defaults) do
    if BlasterMasterDB[k] == nil then BlasterMasterDB[k] = v end
  end
end

BM:RegisterEvent("ADDON_LOADED")
BM:RegisterEvent("PLAYER_LOGIN")
BM:RegisterEvent("PLAYER_ENTERING_WORLD")
BM:RegisterEvent("UNIT_HEALTH")
BM:RegisterEvent("UNIT_MAXHEALTH")
BM:RegisterEvent("UNIT_POWER_UPDATE")
BM:RegisterEvent("UNIT_MAXPOWER")
BM:RegisterEvent("UNIT_DISPLAYPOWER")
BM:RegisterEvent("PLAYER_LEVEL_UP")
BM:RegisterEvent("PLAYER_REGEN_DISABLED")
BM:RegisterEvent("PLAYER_REGEN_ENABLED")
BM:RegisterEvent("PARTY_KILL")
BM:RegisterEvent("PLAYER_TARGET_CHANGED")
BM:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")

BM:SetScript("OnEvent", function(self, event, arg1, arg2)
  if event == "ADDON_LOADED" then
    if arg1 == ADDON_NAME then InitDB() end
    return
  end
  if event == "PLAYER_LOGIN" then
    playerGUID = UnitGUID("player")
    BuildHUD()
    ApplyPoint()
    SetVisible(BlasterMasterDB.enabled)
    UpdatePilot(); UpdateArmor(); UpdateAmmo()
    print("|cff1e5ab4[BlasterMaster]|r SOPHIA online. /blaster for commands.")
    return
  end
  if event == "PLAYER_ENTERING_WORLD" then
    BuildHUD()
    UpdatePilot(); UpdateArmor(); UpdateAmmo()
    return
  end
  if event == "UNIT_HEALTH" or event == "UNIT_MAXHEALTH" then
    if arg1 == "player" then UpdateArmor() end
    return
  end
  if event == "UNIT_POWER_UPDATE" or event == "UNIT_MAXPOWER" or event == "UNIT_DISPLAYPOWER" then
    if arg1 == "player" then UpdateAmmo() end
    return
  end
  if event == "PLAYER_LEVEL_UP" then
    UpdatePilot()
    playSFX("levelUp")
    return
  end
  if event == "PLAYER_REGEN_DISABLED" then
    playSFX("combatStart")
    return
  end
  if event == "PLAYER_REGEN_ENABLED" then
    playSFX("combatEnd")
    return
  end
  if event == "PARTY_KILL" then
    playSFX("kill")
    return
  end
  if event == "PLAYER_TARGET_CHANGED" then
    CheckTarget()
    return
  end
  if event == "COMBAT_LOG_EVENT_UNFILTERED" then
    if not playerGUID then playerGUID = UnitGUID("player") end
    if not playerGUID then return end

    -- CombatLogGetCurrentEventInfo returns:
    -- timestamp, subevent, hideCaster, sourceGUID, sourceName, sourceFlags, sourceRaidFlags,
    -- destGUID, destName, destFlags, destRaidFlags, [prefix...], [suffix...]
    local info = { CombatLogGetCurrentEventInfo() }
    local subevent  = info[2]
    local sourceGUID= info[4]
    if sourceGUID ~= playerGUID then return end

    if subevent == "SPELL_AURA_APPLIED" or subevent == "SPELL_AURA_REFRESH" then
      if info[15] == "DEBUFF" then playAction("dotApplied", 0.2) end
      return
    end

    if subevent == "SPELL_PERIODIC_DAMAGE" then
      playAction("dotHit", 0.15)
      return
    end

    local actionKey
    local critical
    if subevent == "SWING_DAMAGE" then
      actionKey = "meleeHit"
      critical = info[18]
    elseif subevent == "SPELL_DAMAGE" or subevent == "RANGE_DAMAGE" then
      actionKey = "spellHit"
      critical = info[21]
    else
      return
    end

    if critical and (not BlasterMasterDB or BlasterMasterDB.critAudioEnabled ~= false) then
      playAction("crit", 0.4)
    else
      playAction(actionKey, 0.1)
    end
    return
  end
end)

-- ---------- slash ----------
SLASH_BLASTERMASTER1 = "/blaster"
SLASH_BLASTERMASTER2 = "/bm"
SlashCmdList["BLASTERMASTER"] = function(msg)
  msg = (msg or ""):lower():match("^%s*(.-)%s*$") or ""
  local cmd, rest = msg:match("^(%S+)%s*(.*)$")
  cmd = cmd or ""
  if cmd == "toggle" then
    BlasterMasterDB.enabled = not BlasterMasterDB.enabled
    SetVisible(BlasterMasterDB.enabled)
    print("|cff1e5ab4[BlasterMaster]|r HUD " .. (BlasterMasterDB.enabled and "ON" or "OFF"))
  elseif cmd == "mute" then
    BlasterMasterDB.muted = not BlasterMasterDB.muted
    print("|cff1e5ab4[BlasterMaster]|r sounds " .. (BlasterMasterDB.muted and "MUTED" or "ON"))
  elseif cmd == "reset" then
    BlasterMasterDB.point = defaults.point
    ApplyPoint()
    print("|cff1e5ab4[BlasterMaster]|r HUD position reset.")
  elseif cmd == "options" or cmd == "config" then
    if _G.BlasterMaster_OpenOptions then
      BlasterMaster_OpenOptions()
    else
      print("|cff1e5ab4[BlasterMaster]|r options panel unavailable.")
    end
  elseif cmd == "crit" then
    BlasterMasterDB.critAudioEnabled = not BlasterMasterDB.critAudioEnabled
    print("|cff1e5ab4[BlasterMaster]|r crit audio " .. (BlasterMasterDB.critAudioEnabled and "ON" or "OFF"))
  elseif cmd == "hp" then
    local n = tonumber(rest)
    if n and n > 0 and n < 1 then
      BlasterMasterDB.lowHpThreshold = n
      print(string.format("|cff1e5ab4[BlasterMaster]|r low-HP threshold set to %d%%.", math.floor(n * 100)))
    else
      print("|cff1e5ab4[BlasterMaster]|r usage: /blaster hp <0..1>  (e.g. 0.3)")
    end
  else
    print("|cff1e5ab4[BlasterMaster]|r commands: /blaster toggle | mute | crit | reset | hp <0..1> | options")
  end
end
