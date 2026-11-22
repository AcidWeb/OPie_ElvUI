local COMPAT, addonName = select(4, GetBuildInfo()), ...
local SECRETS = COMPAT > 12e4 or COMPAT > 160e2 and COMPAT < 2e4 or nil
local E, _, _, P = unpack(ElvUI)

local mod = E:NewModule(addonName)

local gx do
	local b = ([[Interface\AddOns\%s\Media\]]):format(addonName)
	gx = {
		BorderLow = b .. "borderlo",
		BorderHigh = b .. "borderhi",
		OuterGlow = b .. "oglow",
		InnerGlow = b .. "iglow",
		Ribbon = b .. "ribbon",
		IconMask = b .. "iconmask",
	}
end

local COOLDOWN_CATEGORY = "opie"
P.opie = {
	shadow = false,
}
do
	local defaults = E:CopyTable({}, P.cooldown.global)
	defaults.colors.edge = E:CopyTable({}, defaults.colors.edgeCharge)
	defaults.colors.swipe.a = 0.8
	P.cooldown[COOLDOWN_CATEGORY] = defaults
end

local IndicatorData, Indicator = {}, {}
local IndicatorProps = {
	iconAspect=1,
	ustate=-1,
}

local darken do
	local CSL = CreateFrame("ColorSelect")
	function darken(r,g,b, vf, sf)
		CSL:SetColorRGB(r,g,b)
		local h,s,v = CSL:GetColorHSV()
		CSL:SetColorHSV(h, s*(sf or 1), v*(vf or 1))
		return CSL:GetColorRGB()
	end
end

local CreateQuadTexture do
	local function qf(f)
		return function (self, ...)
			for i=1,4 do
				local v = self[i]
				v[f](v, ...)
			end
		end
	end
	local quadPoints, quadTemplate = {"BOTTOMRIGHT", "BOTTOMLEFT", "TOPLEFT", "TOPRIGHT"}, {__index={SetVertexColor=qf("SetVertexColor"), SetAlpha=qf("SetAlpha"), SetShown=qf("SetShown"), SetAlphaFromBoolean=SECRETS and qf("SetAlphaFromBoolean")}}
	function CreateQuadTexture(layer, size, file, parent, qparent)
		local group, size = setmetatable({}, quadTemplate), size/2
		for i=1,4 do
			local tex, d, l = (parent or qparent[i]):CreateTexture(nil, layer), i > 2, 2 > i or i > 3
			tex:SetSize(size,size)
			tex:SetTexture(file)
			tex:SetTexCoord(l and 0 or 1, l and 1 or 0, d and 1 or 0, d and 0 or 1)
			tex:SetTexelSnappingBias(0)
			tex:SetSnapToPixelGrid(false)
			tex:SetPoint(quadPoints[i], parent or qparent[i], parent and "CENTER" or quadPoints[i])
			group[i] = tex
		end
		return group
	end
end

local newIndicatorData do
	local IndicatorMeta
	function newIndicatorData(self)
		if not IndicatorMeta then
			setmetatable(Indicator, {__index=getmetatable(self).__index})
			IndicatorMeta = {__index=Indicator}
		end
		local d = {self=self}
		for k,v in pairs(IndicatorProps) do
			d[k] = v
		end
		IndicatorData[self] = d
		setmetatable(self, IndicatorMeta)
		return d
	end
end

local function adjustIconAspect(d, aspect)
	if d.iconAspect ~= aspect then
		d.iconAspect = aspect
		local w, h = d.iconbg:GetSize()
		d.icon:SetSize(aspect < 1 and h*aspect or w, aspect > 1 and w/aspect or h)
	end
end
local function setCooldownStyle(cd, usable)
	if usable then
		cd:SetDrawEdge(true)
		cd:SetDrawSwipe(false)
	else
		cd:SetDrawEdge(false)
		cd:SetDrawSwipe(true)
	end
	E:CooldownBling(cd, cd:GetEffectiveAlpha())
end

function Indicator:SetIcon(texture, aspect)
	local d = IndicatorData[self]
	d.icon:SetTexture(texture)
	d.icon:SetTexCoord(unpack(E.TexCoords))
	d.shadow:SetShown(E.db.opie.shadow)
	return adjustIconAspect(d, aspect)
end
function Indicator:SetIconAtlas(atlas, aspect)
	local d = IndicatorData[self]
	d.icon:SetAtlas(atlas)
	d.shadow:SetShown(E.db.opie.shadow)
	return adjustIconAspect(d, aspect)
end
function Indicator:SetIconTexCoord(a,b,c,dc, e,f,g,h)
	if a and b and c and dc then
		local d = IndicatorData[self]
		if e and f and g and h then
			d.icon:SetTexCoord(a,b,c,dc, e,f,g,h)
		else
			d.icon:SetTexCoord(a,b,c,dc)
		end
	end
end
function Indicator:SetIconVertexColor(r,g,b)
	IndicatorData[self].icon:SetVertexColor(r,g,b)
end
function Indicator:SetUsable(usable, _usableCharge, _cd, nomana, norange)
	local d = IndicatorData[self]
	local state = usable and 0 or (norange and 1 or (nomana and 2 or 3))
	d.veil:SetAlpha(usable and 0 or 0.40)
	if d.ustate == state then return end
	d.ustate = state
	if not usable and (nomana or norange) then
		d.ribbon:Show()
		if norange then
			d.ribbon:SetVertexColor(1, 0.20, 0.15)
		else
			d.ribbon:SetVertexColor(0.15, 0.75, 1)
		end
	else
		d.ribbon:Hide()
	end
end
function Indicator:SetDominantColor(r,g,b)
	local d = IndicatorData[self]
	r, g, b = r or 1, g or 1, b or 0.6
	d.hiEdge:SetVertexColor(r, g, b)
	d.iglow:SetVertexColor(r, g, b)
	d.oglow:SetVertexColor(r, g, b)
	d.edge:SetVertexColor(darken(r,g,b, 0.80))
end
function Indicator:SetOverlayIcon(tex, w, h, ...)
	local oi = IndicatorData[self].overIcon
	if not tex then
		return oi:Hide()
	end
	oi:Show()
	oi:SetTexture(tex)
	oi:SetSize(w, h)
	if ... then
		oi:SetTexCoord(...)
	else
		oi:SetTexCoord(0,1, 0,1)
	end
end
function Indicator:SetOverlayIconVertexColor(...)
	IndicatorData[self].overIcon:SetVertexColor(...)
end
function Indicator:SetCount(count)
	IndicatorData[self].count:SetText(count or "")
end
function Indicator:SetBinding(binding)
	binding = binding and GetBindingText(binding, 1) or ""
	IndicatorData[self].key:SetText(binding)
end
function Indicator:SetCooldown(remain, duration, usableCharge)
	local d = IndicatorData[self]
	local cd = d.cd
	if (duration or 0) <= 0 or (remain or 0) <= 0 then
		d.cdExpire, d.cdLength = nil, nil
		cd:Clear()
		return
	end
	setCooldownStyle(cd, usableCharge)
	local expire = GetTime() + remain
	local td = expire - (d.cdExpire or 0)
	if td < -0.05 or td > 0.05 or d.cdLength ~= duration then
		d.cdExpire, d.cdLength = expire, duration
		cd:SetCooldown(expire - duration, duration)
	end
end
function Indicator:SetCooldownDuration(duration, isRecharge)
	local d = IndicatorData[self]
	local cd = d.cd
	d.cdExpire, d.cdLength = nil, nil
	if duration and cd.SetCooldownFromDurationObject then
		setCooldownStyle(cd, isRecharge)
		cd:SetCooldownFromDurationObject(duration)
	else
		cd:Clear()
	end
end
if SECRETS then
	function Indicator:SetActive(active)
		local d = IndicatorData[self]
		d.iglow:SetAlphaFromBoolean(active, d.fullInnerGlowAlpha, 0)
	end
	function Indicator:SetHighlighted(highlight)
		IndicatorData[self].hiEdge:SetAlphaFromBoolean(highlight, 1, 0)
	end
	function Indicator:SetOuterGlow(shown)
		IndicatorData[self].oglow:SetAlphaFromBoolean(shown, 1, 0)
	end
else
	function Indicator:SetActive(active)
		IndicatorData[self].iglow:SetShown(active)
	end
	function Indicator:SetHighlighted(highlight)
		IndicatorData[self].hiEdge:SetShown(highlight)
	end
	function Indicator:SetOuterGlow(shown)
		IndicatorData[self].oglow:SetShown(shown)
	end
end
function Indicator:SetEquipState(isInContainer, isInInventory)
	local s = IndicatorData[self].equipBanner
	local v, r, g, b = isInContainer or isInInventory, 0.1, 0.9, 0.15
	s:SetShown(v)
	if v then
		if not isInInventory then
			r, g, b = 1, 0.9, 0.2
		end
		s:SetVertexColor(r, g, b)
	end
end
function Indicator:SetShortLabel(text)
	IndicatorData[self].label:SetText(text)
end
function Indicator:SetQualityOverlay(_qualID, qualAtlas)
	local s = IndicatorData[self].qualityMark
	if qualAtlas then
		s:SetAtlas(qualAtlas)
	end
	s:SetShown(qualAtlas ~= nil)
end

local function CreateIndicator(name, parent, size, nested)
	local cf, d, w, ef = CreateFrame("Frame", name, parent)
		cf:SetSize(size, size)
	d = newIndicatorData(cf)
	ef = CreateFrame("Frame", nil, cf)
		ef:SetAllPoints()
	w = ef:CreateTexture(nil, "OVERLAY")
		w:SetAllPoints()
		w:SetTexture(gx.BorderLow)
	w, d.edge = ef:CreateTexture(nil, "OVERLAY", nil, 1), w
		w:SetAllPoints()
		w:SetTexture(gx.BorderHigh)
	w, d.hiEdge = CreateQuadTexture("BACKGROUND", size*2, gx.OuterGlow, cf), w
	w, d.oglow = ef:CreateTexture(nil, "ARTWORK", nil, 1), w
		w:SetAllPoints()
		w:SetTexture(gx.InnerGlow)
		d.fullInnerGlowAlpha = nested and 0.6 or 1
		w:SetAlpha(d.fullInnerGlowAlpha)
	w, d.iglow = ef:CreateTexture(nil, "ARTWORK"), w
		w:SetPoint("CENTER")
		w:SetSize(60*size/64, 60*size/64)
	w, d.icon = ef:CreateTexture(nil, "ARTWORK", nil, -2), w
		w:SetPoint("CENTER")
		w:SetSize(60*size/64, 60*size/64)
		w:SetColorTexture(0.15, 0.15, 0.15, 0.85)
	w, d.iconbg = ef:CreateMaskTexture(), w
		w:SetTexture(gx.IconMask)
		w:SetAllPoints()
		d.icon:AddMaskTexture(w)
	w, d.iconmask = CreateFrame("Cooldown", nil, ef, "CooldownFrameTemplate"), w
		w:ClearAllPoints()
		w:SetSize(size-4, size-4)
		w:SetPoint("CENTER")
	w, d.cd = ef:CreateTexture(nil, "ARTWORK", nil, 2), w
		w:SetSize(60*size/64, 60*size/64)
		w:SetPoint("CENTER")
		w:SetColorTexture(0,0,0)
	w, d.veil = ef:CreateTexture(nil, "ARTWORK", nil, 3), w
		w:SetAllPoints()
		w:SetTexture(gx.Ribbon)
		w:Hide()
	w, d.ribbon = ef:CreateTexture(nil, "ARTWORK", nil, 4), w
		w:SetPoint("BOTTOMLEFT", 4, 4)
	w, d.overIcon = ef:CreateFontString(nil, "OVERLAY", "NumberFontNormal"), w
		w:SetJustifyH("RIGHT")
		w:SetPoint("BOTTOMRIGHT", -2, 2)
	w, d.count = ef:CreateFontString(nil, "OVERLAY", "NumberFontNormalSmallGray"), w
		w:SetJustifyH("RIGHT")
		w:SetPoint("TOPRIGHT", -2, -3)
	w, d.key = ef:CreateTexture(nil, "ARTWORK", nil, 2), w
		w:SetSize(size/5, size/4)
		w:SetTexture("Interface\\GuildFrame\\GuildDifficulty")
		w:SetTexCoord(0, 42/128, 6/64, 52/64)
		w:SetPoint("TOPLEFT", 6*size/64, -3*size/64)
	w, d.equipBanner = ef:CreateFontString(nil, "OVERLAY", "TextStatusBarText", -1), w
		w:SetSize(size-4, 12)
		w:SetJustifyH("CENTER")
		w:SetJustifyV("BOTTOM")
		w:SetMaxLines(1)
		w:SetPoint("BOTTOMLEFT", 3, 2)
		w:SetPoint("BOTTOMRIGHT", d.count, "BOTTOMLEFT", 2, 0)
	w, d.label = ef:CreateTexture(nil, "ARTWORK", nil, 3), w
		w:SetPoint("TOPLEFT", 0, 0)
		w:SetSize(18,18)
		w:Hide()
	w, d.qualityMark = ef:CreateShadow(nil, true), w
		w:ClearAllPoints()
		w:SetPoint("TOPLEFT", -2, 2)
		w:SetPoint("BOTTOMRIGHT", 2, -2)
		w:SetShown(E.db.opie.shadow)
	d.shadow = w
	E:RegisterCooldown(d.cd, COOLDOWN_CATEGORY)
	cf:SetActive(false)
	cf:SetHighlighted(false)
	cf:SetOuterGlow(false)
	return cf
end

local function InsertOptions()
	local C, L = unpack(E.Config)
	local ACH, key = E.Libs.ACH, COOLDOWN_CATEGORY

	local opie = ACH:Group("OPie", nil, nil, nil, function(info) return E.db.opie[info[#info]] end, function(info, value) E.db.opie[info[#info]] = value end)
	opie.args.shadow = ACH:Toggle("Add a shadow under the buttons", nil, 1, nil, nil, "full")
	opie.args.cooldownShortcut = ACH:Execute(L["Cooldown & Duration"], nil, 2, function() E.Libs.AceConfigDialog:SelectGroup("ElvUI", "cooldown", key) end, nil, nil, 160)
	E.Options.args.opie = opie

	local main = ACH:Group("OPie", nil, 22, nil, function(info) return E.db.cooldown[key][info[#info]] end, function(info, value) E.db.cooldown[key][info[#info]] = value; E:CooldownSettings(key) end)
	local general = E:CopyTable({}, E.Options.args.cooldown.args.global.args.generalGroup)
	general.args.minDuration.get = function() return E.db.cooldown[key].minDuration * 0.001 end
	general.args.minDuration.set = function(_, value) E.db.cooldown[key].minDuration = value * 1000; E:CooldownSettings(key) end
	main.args.generalGroup = general
	local _, textGroup, thresholdGroup, colorGroup = C:GetCooldownConfig(key, E.db.cooldown[key], P.cooldown[key], true, true)
	main.args.textGroup = textGroup
	main.args.thresholdGroup = thresholdGroup
	main.args.colorGroup = colorGroup
	E.Options.args.cooldown.args[key] = main
end

function mod:Initialize()
	E.Libs.EP:RegisterPlugin(addonName, InsertOptions)
	hooksecurefunc(E, "UpdateAll", function()
		E:CooldownSettings(COOLDOWN_CATEGORY)
	end)

	OPie.UI:RegisterIndicatorConstructor("elvui", {
		name="ElvUI",
		apiLevel=5,
		CreateIndicator=CreateIndicator,
		supportsCooldownNumbers=false,
		supportsShortLabels=true,
	})
end

E:RegisterModule(mod:GetName())
