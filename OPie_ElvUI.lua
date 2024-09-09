local COMPAT, addonName, ns = select(4, GetBuildInfo()), ...
local FRAME_BUFFER_OK = COMPAT <= 11e4

local E = unpack(ElvUI)
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

local darken do
	local CSL = CreateFrame("ColorSelect")
	function darken(r,g,b, vf, sf)
		CSL:SetColorRGB(r,g,b)
		local h,s,v = CSL:GetColorHSV()
		CSL:SetColorHSV(h, s*(sf or 1), v*(vf or 1))
		return CSL:GetColorRGB()
	end
end
local function shortBindName(bind)
	return GetBindingText(bind, 1)
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
	local quadPoints, quadTemplate = {"BOTTOMRIGHT", "BOTTOMLEFT", "TOPLEFT", "TOPRIGHT"}, {__index={SetVertexColor=qf("SetVertexColor"), SetAlpha=qf("SetAlpha"), SetShown=qf("SetShown")}}
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
	ns.CreateQuadTexture = CreateQuadTexture
end
local qualAtlas = {} do
	for i=1,5 do
		qualAtlas[i] = "Professions-Icon-Quality-Tier" .. i .. "-Small"
	end
end

local function adjustIconAspect(self, aspect)
	if self.iconAspect ~= aspect then
		self.iconAspect = aspect
		local w, h = self.iconbg:GetSize()
		self.icon:SetSize(aspect < 1 and h*aspect or w, aspect > 1 and w/aspect or h)
	end
end

local indicatorAPI = {}
do -- inherit SetPoint, SetScale, GetScale, SetShown, SetParent
	local m = getmetatable(UIParent).__index
	for k in ("SetPoint SetScale GetScale SetShown SetParent"):gmatch("%S+") do
		local f = m[k]
		indicatorAPI[k] = function(self, ...)
			return f(self[0], ...)
		end
	end
end
function indicatorAPI:SetIcon(texture, aspect)
	self.icon:SetTexture(texture)
	self.icon:SetTexCoord(unpack(E.TexCoords))
	self.shadow:SetShown(ns.db.global.shadow)
	return adjustIconAspect(self, aspect)
end
function indicatorAPI:SetIconAtlas(atlas, aspect)
	self.icon:SetAtlas(atlas)
	self.shadow:SetShown(ns.db.global.shadow)
	return adjustIconAspect(self, aspect)
end
function indicatorAPI:SetIconTexCoord(a,b,c,d, e,f,g,h)
	if a and b and c and d then
		if e and f and g and h then
			self.icon:SetTexCoord(a,b,c,d, e,f,g,h)
		else
			self.icon:SetTexCoord(a,b,c,d)
		end
	end
end
function indicatorAPI:SetIconVertexColor(r,g,b)
	self.icon:SetVertexColor(r,g,b)
end
function indicatorAPI:SetUsable(usable, _usableCharge, _cd, nomana, norange)
	local state = usable and 0 or (norange and 1 or (nomana and 2 or 3))
	if self.ustate == state then return end
	self.ustate = state
	if not usable and (nomana or norange) then
		self.ribbon:Show()
		if norange then
			self.ribbon:SetVertexColor(1, 0.20, 0.15)
		else
			self.ribbon:SetVertexColor(0.15, 0.75, 1)
		end
	else
		self.ribbon:Hide()
	end
	self.veil:SetAlpha(usable and 0 or 0.40)
end
function indicatorAPI:SetDominantColor(r,g,b)
	r, g, b = r or 1, g or 1, b or 0.6
	self.hiEdge:SetVertexColor(r, g, b)
	self.iglow:SetVertexColor(r, g, b)
	self.oglow:SetVertexColor(r, g, b)
	self.edge:SetVertexColor(darken(r,g,b, 0.80))
end
function indicatorAPI:SetOverlayIcon(tex, w, h, ...)
	local oi = self.overIcon
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
function indicatorAPI:SetOverlayIconVertexColor(...)
	self.overIcon:SetVertexColor(...)
end
function indicatorAPI:SetCount(count)
	self.count:SetText(count or "")
end
function indicatorAPI:SetBinding(binding)
	self.key:SetText(binding and shortBindName(binding) or "")
end
function indicatorAPI:SetCooldown(remain, duration, usable)
	if duration and remain and duration > 0 and remain > 0 then
		local start = GetTime() + remain - duration
		if usable then
		   self.cd:SetDrawEdge(true)
		   self.cd:SetDrawSwipe(false)
		else
		   self.cd:SetDrawEdge(false)
		   self.cd:SetDrawSwipe(true)
		   self.cd:SetSwipeColor(0, 0, 0, 0.8)
		end
		self.cd:SetCooldown(start, duration)
		self.cd:Show()
	 else
		self.cd:Hide()
	 end
end
function indicatorAPI:SetHighlighted(highlight)
	self.hiEdge:SetShown(highlight)
end
function indicatorAPI:SetActive(active)
	self.iglow:SetShown(active)
end
function indicatorAPI:SetOuterGlow(shown)
	self.oglow:SetShown(shown)
end
function indicatorAPI:SetEquipState(isInContainer, isInInventory)
	local s, v, r, g, b = self.equipBanner, isInContainer or isInInventory, 0.1, 0.9, 0.15
	s:SetShown(v)
	if v then
		if not isInInventory then
			r, g, b = 1, 0.9, 0.2
		end
		s:SetVertexColor(r, g, b)
	end
end
function indicatorAPI:SetShortLabel(text)
	self.label:SetText(text)
end
function indicatorAPI:SetQualityOverlay(qual)
	local s, qa = self.qualityMark, qualAtlas[qual]
	s:SetAtlas(qa)
	s:SetShown(qa ~= nil)
end

local CreateIndicator do
	local apimeta = {__index=indicatorAPI}
	function CreateIndicator(name, parent, size, nested)
		local cf = CreateFrame("Frame", name, parent)
			cf:SetSize(size, size)
		local bf = CreateFrame("Frame", nil, cf)
			bf:SetAllPoints()
			bf:SetFlattensRenderLayers(true)
			bf:SetIsFrameBuffer(FRAME_BUFFER_OK)
		local ef = CreateFrame("Frame", nil, bf)
			ef:SetAllPoints()
		local uf = CreateFrame("Frame", nil, cf)
			uf:SetAllPoints()
			uf:SetFrameLevel(bf:GetFrameLevel()+5)
		local r, w = setmetatable({[0]=cf, cd=CreateFrame("Cooldown", nil, ef, "CooldownFrameTemplate"), bf=bf}, apimeta)
			r.cd:ClearAllPoints()
			r.cd:SetSize(size-4, size-4)
			r.cd:SetPoint("CENTER")
		w = ef:CreateTexture(nil, "OVERLAY")
			w:SetAllPoints()
			w:SetTexture(gx.BorderLow)
		w, r.edge = ef:CreateTexture(nil, "OVERLAY", nil, 1), w
			w:SetAllPoints()
			w:SetTexture(gx.BorderHigh)
		w, r.hiEdge = CreateQuadTexture("BACKGROUND", size*2, gx.OuterGlow, cf), w
			w:SetShown(false)
		w, r.oglow = ef:CreateTexture(nil, "ARTWORK", nil, 1), w
			w:SetAllPoints()
			w:SetTexture(gx.InnerGlow)
			w:SetAlpha(nested and 0.6 or 1)
		w, r.iglow = ef:CreateTexture(nil, "ARTWORK"), w
			w:SetPoint("CENTER")
			w:SetSize(60*size/64, 60*size/64)
		w, r.icon = ef:CreateTexture(nil, "ARTWORK", nil, -2), w
			w:SetPoint("CENTER")
			w:SetSize(60*size/64, 60*size/64)
			w:SetColorTexture(0.15, 0.15, 0.15, 0.85)
		w, r.iconbg = ef:CreateTexture(nil, "ARTWORK", nil, 2), w
			w:SetSize(60*size/64, 60*size/64)
			w:SetPoint("CENTER")
			w:SetColorTexture(0,0,0)
		w, r.veil = ef:CreateTexture(nil, "ARTWORK", nil, 3), w
			w:SetAllPoints()
			w:SetTexture(gx.Ribbon)
			w:Hide()
		w, r.ribbon = ef:CreateTexture(nil, "ARTWORK", nil, 4), w
			w:SetPoint("BOTTOMLEFT", 4, 4)
		w, r.overIcon = ef:CreateFontString(nil, "OVERLAY", "NumberFontNormal"), w
			w:SetJustifyH("RIGHT")
			w:SetPoint("BOTTOMRIGHT", -2, 1)
		w, r.count = ef:CreateFontString(nil, "OVERLAY", "NumberFontNormalSmallGray"), w
			w:SetJustifyH("RIGHT")
			w:SetPoint("TOPRIGHT", -2, -3)
		w, r.key = ef:CreateTexture(nil, "ARTWORK", nil, 2), w
			w:SetSize(size/5, size/4)
			w:SetTexture("Interface\\GuildFrame\\GuildDifficulty")
			w:SetTexCoord(0, 42/128, 6/64, 52/64)
			w:SetPoint("TOPLEFT", 6*size/64, -3*size/64)
		w, r.equipBanner = ef:CreateFontString(nil, "OVERLAY", "TextStatusBarText", -1), w
			w:SetSize(size-4, 12)
			w:SetJustifyH("CENTER")
			w:SetJustifyV("BOTTOM")
			w:SetMaxLines(1)
			w:SetPoint("BOTTOMLEFT", 3, 2)
			w:SetPoint("BOTTOMRIGHT", r.count, "BOTTOMLEFT", 2, 0)
		w, r.label = ef:CreateTexture(nil, "ARTWORK", nil, 3), w
			w:SetPoint("TOPLEFT", 4, -4)
			w:SetSize(14,14)
			w:Hide()
		w, r.qualityMark = ef:CreateShadow(nil, true), w
			w:ClearAllPoints()
			w:SetPoint("TOPLEFT", -2, 2)
			w:SetPoint("BOTTOMRIGHT", 2, -2)
			w:SetShown(ns.db.global.shadow)
		w, r.shadow = ef:CreateMaskTexture(), w
			w:SetTexture(gx.IconMask)
			w:SetAllPoints()
			r.icon:AddMaskTexture(w)
		r.cdText = r.cd.cdText
		r.iconAspect = 1
		E:RegisterCooldown(r.cd, "OPie")
		return r
	end
end

ns = LibStub("AceAddon-3.0"):NewAddon("OPie: ElvUI")
ns.defaultSettings = {
	global = {
		shadow = false
	}
}
ns.aceConfig = {
	type = "group",
	args = {
		shadow = {
			name = "Add a shadow under the buttons",
			type = "toggle",
			width = "full",
			set = function(_, val) ns.db.global.shadow = val end,
			get = function(_) return ns.db.global.shadow end
		}
	}
}
function ns:OnInitialize()
	ns.db = LibStub("AceDB-3.0"):New("OPieElvUIDB", ns.defaultSettings, true)
	LibStub("AceConfigRegistry-3.0"):RegisterOptionsTable("OPie: ElvUI", ns.aceConfig)
	LibStub("AceConfigDialog-3.0"):AddToBlizOptions("OPie: ElvUI", "OPie: |cff1784d1ElvUI|r")

	OPie.UI:RegisterIndicatorConstructor("elvui", {
		name="ElvUI",
		apiLevel=3,
		CreateIndicator=CreateIndicator,
		supportsCooldownNumbers=false,
		supportsShortLabels=true,
		fixedFrameBuffering=true,
		onParentAlphaChanged=FRAME_BUFFER_OK and function(self, pea) self.bf:SetAlpha(pea) end or nil
	})
end