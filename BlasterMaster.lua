-- BlasterMaster: NES Blaster Master-inspired retro combat HUD.
-- MVP: ARMOR/AMMO bars, BOSS ROOM alert, 8-bit sound cues, /blaster slash.

local ADDON_NAME = ...

local defaults = {
  enabled = true,
  muted = false,
  lowHpThreshold = 0.25,
  point = { "CENTER", "UIParent", "CENTER", 0, 200 },
}

local BM = CreateFrame("Frame", "BlasterMasterFrame", UIParent)
BM:Hide()

-- ---------- state ----------
local hud, armorBar, ammoBar, pilotLabel, bossBanner
local bossCooldown = {} -- guid -> expiry time
local lastSirenAt = 0
local wasLowHp = false

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
  laser     = "Interface\\AddOns\\BlasterMaster\\Media\\Audio\\Blaster Master SFX (1).wav",
  siren     = "Interface\\AddOns\\BlasterMaster\\Media\\Audio\\Blaster Master SFX (14).wav",
  oneUp     = "Interface\\AddOns\\BlasterMaster\\Media\\Audio\\Blaster Master SFX (29).wav",
  fanfare   = "Interface\\AddOns\\BlasterMaster\\Media\\Audio\\Blaster Master SFX (33).wav",
}

local function playSFX(key)
  if BlasterMasterDB and BlasterMasterDB.muted then return end
  local path = SFX[key]
  if path then PlaySoundFile(path, "Master") end
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
  if hud then return end
  hud = CreateFrame("Frame", "BlasterMasterHUD", UIParent)
  hud:SetSize(240, 96)
  hud:SetMovable(true)
  hud:EnableMouse(true)
  hud:RegisterForDrag("LeftButton")
  hud:SetScript("OnDragStart", function(self) self:StartMoving() end)
  hud:SetScript("OnDragStop", function(self)
    self:StopMovingOrSizing()
    local p, _, rp, x, y = self:GetPoint()
    BlasterMasterDB.point = { p, "UIParent", rp, x, y }
  end)

  local bg = hud:CreateTexture(nil, "BACKGROUND")
  bg:SetAllPoints(hud)
  bg:SetTexture(WHITE_TEX)
  bg:SetVertexColor(0.02, 0.02, 0.06, 0.85)

  pilotLabel = hud:CreateFontString(nil, "OVERLAY", "NumberFont_Outline_Med")
  pilotLabel:SetPoint("TOP", hud, "TOP", 0, -6)
  pilotLabel:SetText("PILOT")

  -- ARMOR label + bar
  local armorLbl = hud:CreateFontString(nil, "OVERLAY", "NumberFont_Outline_Small")
  armorLbl:SetPoint("TOPLEFT", hud, "TOPLEFT", 8, -30)
  armorLbl:SetText("ARMOR")

  armorBar = pixelBar(hud, 180, 14, 0.2, 0.9, 0.2)
  armorBar:SetPoint("LEFT", armorLbl, "RIGHT", 6, 0)

  -- AMMO label + bar
  local ammoLbl = hud:CreateFontString(nil, "OVERLAY", "NumberFont_Outline_Small")
  ammoLbl:SetPoint("TOPLEFT", hud, "TOPLEFT", 8, -54)
  ammoLbl:SetText("AMMO ")

  ammoBar = pixelBar(hud, 180, 14, 0.2, 0.4, 1.0)
  ammoBar:SetPoint("LEFT", ammoLbl, "RIGHT", 6, 0)

  -- BOSS ROOM banner (child of UIParent so it can be wider)
  bossBanner = CreateFrame("Frame", "BlasterMasterBossBanner", UIParent)
  bossBanner:SetSize(UIParent:GetWidth(), 48)
  bossBanner:SetPoint("TOP", UIParent, "TOP", 0, -80)
  bossBanner:Hide()
  local bbg = bossBanner:CreateTexture(nil, "BACKGROUND")
  bbg:SetAllPoints(bossBanner)
  bbg:SetTexture(WHITE_TEX)
  bbg:SetVertexColor(0.7, 0.05, 0.05, 0.9)
  bossBanner.text = bossBanner:CreateFontString(nil, "OVERLAY", "NumberFont_Outline_Huge")
  bossBanner.text:SetPoint("CENTER", bossBanner, "CENTER", 0, 0)
  bossBanner.text:SetText("!! BOSS ROOM !!")
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
  if not hud or not hud:IsShown() then return end
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
      playSFX("siren")
      lastSirenAt = now
    end
    wasLowHp = true
  elseif pct > threshold + 0.05 then
    wasLowHp = false
  end
end

local function UpdateAmmo()
  if not hud or not hud:IsShown() then return end
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
  playSFX("laser")
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
BM:RegisterEvent("PARTY_KILL")
BM:RegisterEvent("PLAYER_TARGET_CHANGED")

BM:SetScript("OnEvent", function(self, event, arg1, arg2)
  if event == "ADDON_LOADED" then
    if arg1 == ADDON_NAME then InitDB() end
    return
  end
  if event == "PLAYER_LOGIN" then
    BuildHUD()
    ApplyPoint()
    SetVisible(BlasterMasterDB.enabled)
    UpdatePilot(); UpdateArmor(); UpdateAmmo()
    print("|cff1e5ab4[BlasterMaster]|r SOPHIA online. /blaster for commands.")
    return
  end
  if event == "PLAYER_ENTERING_WORLD" then
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
    playSFX("fanfare")
    return
  end
  if event == "PLAYER_REGEN_DISABLED" then
    playSFX("laser")
    return
  end
  if event == "PARTY_KILL" then
    playSFX("oneUp")
    return
  end
  if event == "PLAYER_TARGET_CHANGED" then
    CheckTarget()
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
  elseif cmd == "hp" then
    local n = tonumber(rest)
    if n and n > 0 and n < 1 then
      BlasterMasterDB.lowHpThreshold = n
      print(string.format("|cff1e5ab4[BlasterMaster]|r low-HP threshold set to %d%%.", math.floor(n * 100)))
    else
      print("|cff1e5ab4[BlasterMaster]|r usage: /blaster hp <0..1>  (e.g. 0.3)")
    end
  else
    print("|cff1e5ab4[BlasterMaster]|r commands: /blaster toggle | mute | reset | hp <0..1>")
  end
end
