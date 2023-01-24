local _G = _G
local addonName, ns = ...

local E = unpack(_G.ElvUI)
local gfxBase = ([[Interface\AddOns\%s\Media\]]):format(addonName)

local function cc(m, f, ...)
	f[m](f, ...)
	return f
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
			local tex, d, l = cc("SetSize", cc("SetTexture", (parent or qparent[i]):CreateTexture(nil, layer), file), size, size), i > 2, 2 > i or i > 3
			tex:SetTexCoord(l and 0 or 1, l and 1 or 0, d and 1 or 0, d and 0 or 1)
			tex:SetTexelSnappingBias(0)
			tex:SetSnapToPixelGrid(false)
			group[i] = cc("SetPoint", tex, quadPoints[i], parent or qparent[i], parent and "CENTER" or quadPoints[i])
		end
		return group
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
function indicatorAPI:SetIcon(texture)
	self.icon:SetTexture(texture)
	self.icon:SetTexCoord(unpack(E.TexCoords))
	self.shadow:SetShown(ns.db.global.shadow)
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
function indicatorAPI:SetOverlayIcon(texture, w, h, ...)
	if not texture then
		self.overIcon:Hide()
	else
		self.overIcon:Show()
		self.overIcon:SetTexture(texture)
		self.overIcon:SetSize(w, h)
		if ... then
			self.overIcon:SetTexCoord(...)
		else
			self.overIcon:SetTexCoord(0,1, 0,1)
		end
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

local CreateIndicator do
	local apimeta = {__index=indicatorAPI}
	local function Indicator_ApplyParentAlpha(self)
		local p = self:GetParent()
		if p then
			self:SetAlpha(p:GetEffectiveAlpha())
		end
	end
	function CreateIndicator(name, parent, size, nested)
		local b = cc("SetSize", CreateFrame("Frame", name, parent), size, size)
		cc(b.SetIsFrameBuffer and "SetIsFrameBuffer" or "SetFrameBuffer", cc("SetFlattensRenderLayers", b, true), true)
		local e = cc("SetAllPoints", CreateFrame("Frame", nil, b))
		local r = setmetatable({[0]=b,
			cd = cc("SetPoint", cc("SetSize", cc("ClearAllPoints", CreateFrame("Cooldown", nil, e, "CooldownFrameTemplate")), size-4, size-4), "CENTER"),
			edge = cc("SetAllPoints", cc("SetTexture", e:CreateTexture(nil, "OVERLAY"), gfxBase .. "borderlo")),
			hiEdge = cc("SetAllPoints", cc("SetTexture", e:CreateTexture(nil, "OVERLAY", nil, 1), gfxBase .. "borderhi")),
			oglow = cc("SetShown", CreateQuadTexture("BACKGROUND", size*2, gfxBase .. "oglow", e), false),
			iglow = cc("SetAllPoints", cc("SetAlpha", cc("SetTexture", e:CreateTexture(nil, "ARTWORK", nil, 1), gfxBase .. "iglow"), nested and 0.60 or 1)),
			icon = cc("SetPoint", cc("SetSize", e:CreateTexture(nil, "ARTWORK"), 60*size/64, 60*size/64), "CENTER"),
			veil = cc("SetColorTexture", cc("SetPoint", cc("SetSize", e:CreateTexture(nil, "ARTWORK", nil, 2), 60*size/64, 60*size/64), "CENTER"), 0, 0, 0),
			ribbon = cc("SetShown", cc("SetTexture", cc("SetAllPoints", e:CreateTexture(nil, "ARTWORK", nil, 3)), gfxBase .. "ribbon"), false),
			overIcon = cc("SetPoint", e:CreateTexture(nil, "ARTWORK", nil, 4), "BOTTOMLEFT", e, "BOTTOMLEFT", 4, 4),
			count = cc("SetPoint", cc("SetJustifyH", e:CreateFontString(nil, "OVERLAY", "NumberFontNormal"), "RIGHT"), "BOTTOMRIGHT", -2, 2),
			key = cc("SetPoint", cc("SetJustifyH", e:CreateFontString(nil, "OVERLAY", "NumberFontNormalSmallGray"), "RIGHT"), "TOPRIGHT", -2, -3),
			equipBanner = cc("SetPoint", cc("SetTexCoord", cc("SetTexture", cc("SetSize", e:CreateTexture(nil, "ARTWORK", nil, 2), size/5, size/4), "Interface\\GuildFrame\\GuildDifficulty"), 0, 42/128, 6/64, 52/64), "TOPLEFT", 6*size/64, -3*size/64),
			label = cc("SetPoint", cc("SetMaxLines", cc("SetJustifyV", cc("SetJustifyH", cc("SetSize", e:CreateFontString(nil, "OVERLAY", "TextStatusBarText", -1), size-4, 12), "CENTER"), "BOTTOM"), 1), "BOTTOMLEFT", 3, 4),
			shadow = cc("SetPoint", cc("SetPoint", cc("ClearAllPoints", e:CreateShadow(nil, true)), "TOPLEFT", -2, 2), "BOTTOMRIGHT", 2, -2)
		}, apimeta)
		b:SetScript("OnUpdate", Indicator_ApplyParentAlpha)
		b:SetScript("OnShow", Indicator_ApplyParentAlpha)
		r.label:SetPoint("BOTTOMRIGHT", r.count, "BOTTOMLEFT", 2, 0)
		r.shadow:Hide()
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

	_G.OPie.UI:RegisterIndicatorConstructor("elvui", {
		name="ElvUI",
		apiLevel=1,
		CreateIndicator=CreateIndicator,
		supportsCooldownNumbers=false,
		supportsShortLabels=true,
		_CreateQuadTexture=CreateQuadTexture,
	})
end