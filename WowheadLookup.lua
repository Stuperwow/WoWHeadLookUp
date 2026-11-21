-- WowheadLookup
-- WoW addons can't open a browser, so this gets the Wowhead link ready to copy:
--   * A small "Wowhead" chat-style window: type a search (or shift-click an item/spell/quest
--     link into it) and press Enter.
--   * /wh <search or link> does the same from any chat box.
--   * Keybind "Look up what's under the mouse" for items, spells and NPCs.
-- A box pops up with the link selected: Ctrl+C, then paste it into your browser.

local ADDON_NAME = ...
local DEFAULT_BASE = "https://www.wowhead.com/"
local MAX_HISTORY = 40

BINDING_HEADER_WOWHEADLOOKUP = "WowheadLookup"
BINDING_NAME_WOWHEADLOOKUP_MOUSEOVER = "Look up what's under the mouse"
BINDING_NAME_WOWHEADLOOKUP_TOGGLE = "Show/hide the Wowhead window"

local db
local window, history, input, copyFrame, copyBox

local function Print(msg)
	print("|cffff7f3fWowhead|r: " .. msg)
end

local function IsSecret(v)
	return issecretvalue and issecretvalue(v)
end

------------------------------------------------------------------------
-- Building URLs
------------------------------------------------------------------------

local function UrlEncode(s)
	s = s:gsub("([^%w%-%._~ ])", function(c) return ("%%%02X"):format(c:byte()) end)
	return (s:gsub(" ", "+"))
end

local function Base()
	local b = db.base or DEFAULT_BASE
	if not b:match("/$") then b = b .. "/" end
	return b
end

-- Links WoW puts in chat look like |cffxxxxxx|Hitem:12345:...|h[Name]|h|r
local LINK_TYPES = {
	item = "item", spell = "spell", quest = "quest", achievement = "achievement",
	currency = "currency", mount = "spell", battlepet = "npc", talent = "spell",
	enchant = "spell", trade = "spell",
}

-- Returns url, label
local function UrlFor(text)
	text = strtrim(text or "")
	if text == "" then return nil end

	local ltype, id = text:match("|H(%a+):(%d+)")
	local name = text:match("|h%[(.-)%]|h")
	if ltype and LINK_TYPES[ltype] then
		return Base() .. LINK_TYPES[ltype] .. "=" .. id, name or (ltype .. " " .. id)
	end

	-- Plain text: strip any leftover color codes / brackets and search.
	local clean = text:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""):gsub("|H.-|h", ""):gsub("|h", "")
	clean = strtrim((clean:gsub("[%[%]]", "")))
	if clean == "" then return nil end
	return Base() .. "search?q=" .. UrlEncode(clean), clean
end

------------------------------------------------------------------------
-- Copy box
------------------------------------------------------------------------

local function CreateCopyFrame()
	copyFrame = CreateFrame("Frame", "WowheadLookupCopyFrame", UIParent, "BasicFrameTemplateWithInset")
	copyFrame:SetSize(460, 88)
	copyFrame:SetPoint("TOP", UIParent, "TOP", 0, -140)
	copyFrame:SetFrameStrata("DIALOG")
	copyFrame:SetClampedToScreen(true)
	copyFrame:EnableMouse(true)
	copyFrame:SetMovable(true)
	copyFrame:RegisterForDrag("LeftButton")
	copyFrame:SetScript("OnDragStart", copyFrame.StartMoving)
	copyFrame:SetScript("OnDragStop", copyFrame.StopMovingOrSizing)
	if copyFrame.TitleText then copyFrame.TitleText:SetText("Wowhead") end
	copyFrame:Hide()
	tinsert(UISpecialFrames, "WowheadLookupCopyFrame") -- Esc closes it

	copyFrame.label = copyFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	copyFrame.label:SetPoint("TOPLEFT", 16, -30)
	copyFrame.label:SetPoint("RIGHT", -16, 0)
	copyFrame.label:SetJustifyH("LEFT")

	copyBox = CreateFrame("EditBox", nil, copyFrame, "InputBoxTemplate")
	copyBox:SetSize(420, 22)
	copyBox:SetPoint("TOPLEFT", 20, -50)
	copyBox:SetAutoFocus(false)
	-- Keep the text read-only: put it back if it's edited.
	copyBox:SetScript("OnTextChanged", function(self, userInput)
		if userInput and self.url then
			self:SetText(self.url)
			self:HighlightText()
		end
	end)
	copyBox:SetScript("OnEditFocusGained", function(self) self:HighlightText() end)
	copyBox:SetScript("OnMouseUp", function(self) self:HighlightText() end)
	copyBox:SetScript("OnEscapePressed", function() copyFrame:Hide() end)
	copyBox:SetScript("OnEnterPressed", function() copyFrame:Hide() end)
	copyBox:SetScript("OnKeyDown", function(self, key)
		if (key == "C" or key == "X") and IsControlKeyDown() then
			C_Timer.After(0.15, function()
				copyFrame:Hide()
				Print("Copied - paste it into your browser.")
			end)
		end
	end)
end

local function ShowCopy(url, label)
	if not copyFrame then CreateCopyFrame() end
	copyFrame.label:SetText(("|cffffd100%s|r  -  press |cff00ff00Ctrl+C|r, then paste in your browser"):format(label or "Link"))
	copyBox.url = url
	copyBox:SetText(url)
	copyFrame:Show()
	copyBox:SetFocus()
	copyBox:HighlightText()
	copyBox:SetCursorPosition(0)
	copyBox:HighlightText()
end

------------------------------------------------------------------------
-- History window
------------------------------------------------------------------------

local function HistoryLine(i, entry)
	return ("|cff888888%s|r  |cff71d5ff|Hwowheadlookup:%d|h[%s]|h|r"):format(entry.time or "", i, entry.label)
end

local function RedrawHistory()
	if not history then return end
	history:Clear()
	if #db.history == 0 then
		history:AddMessage("|cff888888Type a search below, or shift-click an item into the box, and press Enter.|r")
		history:AddMessage("|cff888888Click any past lookup to copy its link again.|r")
		return
	end
	for i, entry in ipairs(db.history) do
		history:AddMessage(HistoryLine(i, entry))
	end
end

local function Remember(url, label)
	-- Move repeats to the bottom instead of duplicating.
	for i = #db.history, 1, -1 do
		if db.history[i].url == url then table.remove(db.history, i) end
	end
	db.history[#db.history + 1] = { url = url, label = label, time = date("%H:%M") }
	while #db.history > MAX_HISTORY do table.remove(db.history, 1) end
	RedrawHistory()
end

local function Lookup(text)
	local url, label = UrlFor(text)
	if not url then
		Print("Nothing to look up. Type a name or shift-click a link.")
		return
	end
	Remember(url, label)
	ShowCopy(url, label)
end

local function CreateWindow()
	window = CreateFrame("Frame", "WowheadLookupWindow", UIParent, "BasicFrameTemplateWithInset")
	window:SetSize(380, 230)
	window:SetClampedToScreen(true)
	window:SetMovable(true)
	window:SetResizable(true)
	if window.SetResizeBounds then window:SetResizeBounds(260, 140, 800, 600) end
	window:EnableMouse(true)
	window:RegisterForDrag("LeftButton")
	window:SetScript("OnDragStart", window.StartMoving)
	window:SetScript("OnDragStop", function(self)
		self:StopMovingOrSizing()
		local p, _, rp, x, y = self:GetPoint()
		db.pos = { p, rp, x, y, self:GetWidth(), self:GetHeight() }
	end)
	if window.TitleText then window.TitleText:SetText("Wowhead") end
	if window.CloseButton then
		window.CloseButton:SetScript("OnClick", function() window:Hide(); db.shown = false end)
	end

	local p = db.pos
	if p then
		window:SetPoint(p[1], UIParent, p[2], p[3], p[4])
		if p[5] then window:SetSize(p[5], p[6]) end
	else
		window:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", 20, 300)
	end

	-- Resize grip
	local grip = CreateFrame("Button", nil, window)
	grip:SetSize(16, 16)
	grip:SetPoint("BOTTOMRIGHT", -2, 2)
	grip:SetNormalTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up")
	grip:SetHighlightTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Highlight")
	grip:SetPushedTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Down")
	grip:SetScript("OnMouseDown", function() window:StartSizing("BOTTOMRIGHT") end)
	grip:SetScript("OnMouseUp", function() window:GetScript("OnDragStop")(window) end)

	-- Input box
	input = CreateFrame("EditBox", "WowheadLookupInput", window, "InputBoxTemplate")
	input:SetHeight(22)
	input:SetPoint("BOTTOMLEFT", 16, 10)
	input:SetPoint("BOTTOMRIGHT", -24, 10)
	input:SetAutoFocus(false)
	input:SetMaxLetters(255)
	input:SetScript("OnEnterPressed", function(self)
		local text = self:GetText()
		self:SetText("")
		if strtrim(text) ~= "" then Lookup(text) end
		self:ClearFocus()
	end)
	input:SetScript("OnEscapePressed", function(self) self:SetText(""); self:ClearFocus() end)
	input.hint = input:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
	input.hint:SetPoint("LEFT", 2, 0)
	input.hint:SetText("Search Wowhead...")
	input:SetScript("OnEditFocusGained", function(self) self.hint:Hide() end)
	input:SetScript("OnEditFocusLost", function(self) self.hint:SetShown(self:GetText() == "") end)

	-- History
	history = CreateFrame("ScrollingMessageFrame", nil, window)
	history:SetPoint("TOPLEFT", 12, -30)
	history:SetPoint("BOTTOMRIGHT", input, "TOPRIGHT", 4, 8)
	history:SetFontObject(ChatFontNormal)
	history:SetJustifyH("LEFT")
	history:SetFading(false)
	history:SetMaxLines(MAX_HISTORY + 5)
	history:SetInsertMode(SCROLLING_MESSAGE_FRAME_INSERT_MODE_BOTTOM or "BOTTOM")
	history:SetHyperlinksEnabled(true)
	history:EnableMouseWheel(true)
	history:SetScript("OnMouseWheel", function(self, delta)
		if delta > 0 then self:ScrollUp() else self:ScrollDown() end
	end)
	history:SetScript("OnHyperlinkClick", function(_, link)
		local i = tonumber(link:match("^wowheadlookup:(%d+)"))
		local entry = i and db.history[i]
		if entry then ShowCopy(entry.url, entry.label) end
	end)

	RedrawHistory()
	window:SetShown(db.shown)
end

function WowheadLookup_Toggle()
	if not window then return end
	db.shown = not window:IsShown()
	window:SetShown(db.shown)
	if db.shown then input:SetFocus() end
end

------------------------------------------------------------------------
-- Shift-clicking links into our box
------------------------------------------------------------------------

local function OnInsertLink(link)
	if input and input:HasFocus() and link then
		input:Insert(link)
	end
end

-- Blizzard routes shift-clicked links through one of these (name depends on client version).
if ChatFrameUtil and ChatFrameUtil.InsertLink then
	hooksecurefunc(ChatFrameUtil, "InsertLink", OnInsertLink)
end
if ChatEdit_InsertLink then
	hooksecurefunc("ChatEdit_InsertLink", OnInsertLink)
end

------------------------------------------------------------------------
-- Mouseover lookup
------------------------------------------------------------------------

local function Safe(fn, ...)
	if not fn then return nil end
	local ok, a, b = pcall(fn, ...)
	if not ok or IsSecret(a) or IsSecret(b) then return nil end
	return a, b
end

local function NpcFromGUID(guid)
	if not guid then return nil end
	local kind, id = guid:match("^(%a+)%-%d+%-%d+%-%d+%-%d+%-(%d+)")
	if kind == "Creature" or kind == "Vehicle" or kind == "Pet" then return "npc", id end
	if kind == "GameObject" then return "object", id end
	return nil
end

function WowheadLookup_Mouseover()
	if not db then return end
	if GameTooltip:IsShown() then
		-- Item in the tooltip?
		local _, itemLink = Safe(GameTooltip.GetItem, GameTooltip)
		if itemLink then return Lookup(itemLink) end
		-- Spell in the tooltip?
		local spellName, spellID = Safe(GameTooltip.GetSpell, GameTooltip)
		if spellID then
			local url = Base() .. "spell=" .. spellID
			Remember(url, spellName or ("spell " .. spellID))
			return ShowCopy(url, spellName)
		end
	end
	-- NPC under the mouse, or your target.
	for _, unit in ipairs({ "mouseover", "target" }) do
		if Safe(UnitExists, unit) and not Safe(UnitIsPlayer, unit) then
			local kind, id = NpcFromGUID(Safe(UnitGUID, unit))
			if kind then
				local name = Safe(UnitName, unit) or (kind .. " " .. id)
				local url = Base() .. kind .. "=" .. id
				Remember(url, name)
				return ShowCopy(url, name)
			end
		end
	end
	Print("Nothing to look up - hover an item, spell, or NPC (or target an NPC).")
end

------------------------------------------------------------------------
-- Slash command & events
------------------------------------------------------------------------

SLASH_WOWHEADLOOKUP1 = "/wh"
SLASH_WOWHEADLOOKUP2 = "/wowhead"
SlashCmdList.WOWHEADLOOKUP = function(msg)
	msg = strtrim(msg or "")
	local cmd, rest = msg:match("^(%S*)%s*(.-)$")
	local lower = (cmd or ""):lower()

	if msg == "" then
		WowheadLookup_Toggle()
	elseif lower == "base" then
		if rest == "" then
			Print("Links start with: " .. Base() .. "   (/wh base reset to go back to default)")
		elseif rest:lower() == "reset" then
			db.base = nil
			Print("Back to " .. DEFAULT_BASE)
		elseif rest:match("^https?://") then
			db.base = rest
			Print("Links now start with: " .. Base())
		else
			Print("Usage: /wh base https://www.wowhead.com/   (or /wh base reset)")
		end
	elseif lower == "clear" and rest == "" then
		wipe(db.history)
		RedrawHistory()
		Print("History cleared.")
	elseif lower == "help" and rest == "" then
		Print("/wh - show/hide the Wowhead window")
		Print("/wh <search or shift-clicked link> - get a Wowhead link")
		Print("/wh base <url> - change the site address (for a different game version)")
		Print("/wh clear - clear history")
		Print("Keybinds: Options > Keybindings > AddOns > WowheadLookup")
	else
		Lookup(msg)
	end
end

local events = CreateFrame("Frame")
events:RegisterEvent("ADDON_LOADED")
events:SetScript("OnEvent", function(self, event, arg1)
	if arg1 ~= ADDON_NAME then return end
	WowheadLookupDB = WowheadLookupDB or {}
	db = WowheadLookupDB
	db.history = db.history or {}
	if db.shown == nil then db.shown = true end
	CreateWindow()
	self:UnregisterEvent("ADDON_LOADED")
end)
