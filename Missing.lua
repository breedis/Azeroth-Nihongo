-- Untranslated words: English words in tooltip names that the dictionary does not
-- have. They are saved (AzerothNihongoDB.missing) so the dictionary can be filled in
-- later, and the window lists them as text that can be copied.
local _, ns = ...

local MAX_WORDS = 1500        -- stop collecting new words after this many
local NOTIFY_AT = 25          -- tell the player once per session when this many are new

-- Small words that never need their own translation.
local SKIP = {}
for w in ([[a an the of and or to in on at by for from with into onto upon over under
  is are was be it its this that these those as but not no yes vs de la le el du von van
  ii iii iv vi vii viii ix xi xii]]):gmatch("%S+") do SKIP[w] = true end

local notified = false

local function Kind()
  local ok, kind = pcall(function()
    local _, unit = GameTooltip:GetUnit()
    if unit then
      if UnitIsPlayer(unit) then return "player" end
      return "unit"
    end
    if GameTooltip.GetItem and GameTooltip:GetItem() then return "item" end
    if GameTooltip.GetSpell and GameTooltip:GetSpell() then return "spell" end
    return "other"
  end)
  return ok and kind or "other"
end

local function NewCount()
  local n = 0
  for _, e in pairs(ns.DB.missing) do if e.new then n = n + 1 end end
  return n
end

local function Total()
  local n = 0
  for _ in pairs(ns.DB.missing) do n = n + 1 end
  return n
end

local function Notify()
  if notified then return end
  local n = NewCount()
  if n < NOTIFY_AT then return end
  notified = true
  ns.Print(n .. " words you have seen have no Japanese yet. Type |cffffd100/jp missing|r to see them.")
end

-- Called from the tooltip reader with the words of the name line that had no match.
function ns.NoteMissing(words, name)
  local kind = Kind()
  if kind == "player" then return end -- player names are not words
  local list, total = ns.DB.missing, nil
  for _, w in ipairs(words) do
    if #w >= 3 and not SKIP[w] then
      local e = list[w]
      if e then
        e.n = e.n + 1
        e.t = time()
      else
        total = total or Total()
        if total < MAX_WORDS then
          list[w] = { n = 1, ex = name:sub(1, 60), k = kind, t = time(), new = true }
          total = total + 1
        end
      end
    end
  end
  Notify()
  if ns.RefreshMissing then ns.RefreshMissing() end
end

-- At login: forget words that the dictionary has learned since, then maybe notify.
function ns.MissingLoaded()
  for w in pairs(ns.DB.missing) do
    if ns.KnowsWord(w) then ns.DB.missing[w] = nil end
  end
  Notify()
end

---------------------------------------------------------------------------
-- Window
---------------------------------------------------------------------------
local KIND_LABEL = { unit = "mob/NPC", item = "item", spell = "spell", other = "other" }
local SORTS = { "count", "recent", "az" }
local SORT_LABEL = { count = "Most seen", recent = "Newest", az = "A-Z" }
local FILTERS = { "all", "unit", "item", "spell", "other" }
local FILTER_LABEL = { all = "All", unit = "Mobs/NPCs", item = "Items", spell = "Spells", other = "Other" }

local sortBy, filter = "count", "all"
local W -- the frame, made on first open

local function Lines()
  local rows = {}
  for w, e in pairs(ns.DB.missing) do
    if filter == "all" or e.k == filter then rows[#rows + 1] = { w = w, e = e } end
  end
  table.sort(rows, function(a, b)
    if sortBy == "count" and a.e.n ~= b.e.n then return a.e.n > b.e.n end
    if sortBy == "recent" and a.e.t ~= b.e.t then return a.e.t > b.e.t end
    return a.w < b.w
  end)
  local out = {}
  for _, r in ipairs(rows) do
    out[#out + 1] = r.w .. " | " .. r.e.n .. " | " .. (KIND_LABEL[r.e.k] or r.e.k) .. " | " .. r.e.ex
  end
  return out, #rows
end

local function Cycle(list, cur)
  for i, v in ipairs(list) do
    if v == cur then return list[i % #list + 1] end
  end
  return list[1]
end

local function Refresh()
  if not W or not W:IsShown() then return end
  local lines, n = Lines()
  W.text = #lines > 0 and table.concat(lines, "\n")
    or "(nothing yet - hover over monsters, NPCs and items)"
  W.edit:SetText(W.text)
  W.edit:SetCursorPosition(0)
  W.count:SetText(n .. " words" .. (filter ~= "all" and (" (" .. FILTER_LABEL[filter] .. ")") or "")
    .. ", " .. Total() .. " in all. Columns: word | times seen | kind | example name")
  W.sortBtn:SetText("Sort: " .. SORT_LABEL[sortBy])
  W.filterBtn:SetText("Show: " .. FILTER_LABEL[filter])
  W.collect:SetChecked(ns.DB.collectMissing)
  W.clearBtn:SetText("Clear list")
  W.clearArmed = false
end
ns.RefreshMissing = Refresh

local function Make()
  W = CreateFrame("Frame", "AzerothNihongoMissing", UIParent,
    BackdropTemplateMixin and "BackdropTemplate" or nil)
  W:SetSize(600, 460)
  W:SetPoint("CENTER", 0, 40)
  W:SetFrameStrata("DIALOG")
  W:SetClampedToScreen(true)
  W:SetMovable(true)
  W:EnableMouse(true)
  W:RegisterForDrag("LeftButton")
  W:SetScript("OnDragStart", W.StartMoving)
  W:SetScript("OnDragStop", W.StopMovingOrSizing)
  if W.SetBackdrop then
    W:SetBackdrop({
      bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
      edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
      tile = true, tileSize = 32, edgeSize = 32,
      insets = { left = 11, right = 12, top = 12, bottom = 11 },
    })
  end
  tinsert(UISpecialFrames, "AzerothNihongoMissing") -- Esc closes

  local close = CreateFrame("Button", nil, W, "UIPanelCloseButton")
  close:SetPoint("TOPRIGHT", -6, -6)

  local title = W:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
  title:SetPoint("TOP", 0, -20)
  title:SetText("Untranslated words")

  local help = W:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  help:SetPoint("TOPLEFT", 24, -46)
  help:SetPoint("RIGHT", -24, 0)
  help:SetJustifyH("LEFT")
  help:SetText("Words in names you have hovered that the dictionary does not know yet. "
    .. "Click \"Select all\", press Ctrl+C and paste the list wherever you collect them, "
    .. "so they can be added in a later version. Words that get added drop off the list by themselves.")

  W.count = W:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
  W.count:SetPoint("TOPLEFT", 24, -84)

  local scroll = CreateFrame("ScrollFrame", "AzerothNihongoMissingScroll", W, "UIPanelScrollFrameTemplate")
  scroll:SetPoint("TOPLEFT", 22, -102)
  scroll:SetPoint("BOTTOMRIGHT", -40, 76)
  local bg = scroll:CreateTexture(nil, "BACKGROUND")
  bg:SetPoint("TOPLEFT", -4, 4)
  bg:SetPoint("BOTTOMRIGHT", 4, -4)
  bg:SetColorTexture(0, 0, 0, 0.4)

  local edit = CreateFrame("EditBox", nil, scroll)
  edit:SetMultiLine(true)
  edit:SetAutoFocus(false)
  edit:SetFontObject(ChatFontNormal)
  edit:SetWidth(530)
  edit:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
  -- Read only: typing puts the list back.
  edit:SetScript("OnTextChanged", function(self, user)
    if user and W.text then self:SetText(W.text) self:HighlightText() end
  end)
  scroll:SetScrollChild(edit)
  W.edit = edit

  local function Btn(label, w)
    local b = CreateFrame("Button", nil, W, "UIPanelButtonTemplate")
    b:SetSize(w, 22)
    b:SetText(label)
    return b
  end

  local selectBtn = Btn("Select all", 100)
  selectBtn:SetPoint("BOTTOMLEFT", 22, 44)
  selectBtn:SetScript("OnClick", function()
    edit:SetFocus()
    edit:HighlightText()
  end)

  W.sortBtn = Btn("Sort", 130)
  W.sortBtn:SetPoint("LEFT", selectBtn, "RIGHT", 8, 0)
  W.sortBtn:SetScript("OnClick", function() sortBy = Cycle(SORTS, sortBy) Refresh() end)

  W.filterBtn = Btn("Show", 150)
  W.filterBtn:SetPoint("LEFT", W.sortBtn, "RIGHT", 8, 0)
  W.filterBtn:SetScript("OnClick", function() filter = Cycle(FILTERS, filter) Refresh() end)

  W.clearBtn = Btn("Clear list", 130)
  W.clearBtn:SetPoint("LEFT", W.filterBtn, "RIGHT", 8, 0)
  W.clearBtn:SetScript("OnClick", function(self)
    if not W.clearArmed then
      W.clearArmed = true
      self:SetText("|cffff6060Click again|r")
      return
    end
    wipe(ns.DB.missing)
    Refresh()
  end)

  W.collect = CreateFrame("CheckButton", nil, W, "UICheckButtonTemplate")
  W.collect:SetSize(26, 26)
  W.collect:SetPoint("BOTTOMLEFT", 20, 16)
  W.collect:SetScript("OnClick", function(self)
    ns.DB.collectMissing = self:GetChecked() and true or false
    if ns.RefreshOptions then ns.RefreshOptions() end
  end)
  local cl = W:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
  cl:SetPoint("LEFT", W.collect, "RIGHT", 4, 0)
  cl:SetText("Collect untranslated words while I play")

  W:SetScript("OnShow", function()
    for _, e in pairs(ns.DB.missing) do e.new = nil end
    Refresh()
  end)
end

function ns.ToggleMissing()
  if not ns.DB then return end
  if not W then Make() W:Hide() end
  if W:IsShown() then W:Hide() else W:Show() end
end
