-- Pop quiz: opens the quiz by itself on a timer, after quest turn-ins or on level up.
-- Never during combat: a pop quiz that comes due in combat waits until combat ends.
local _, ns = ...

local due = {}         -- GetTime() values when timed pop quizzes are due
local periodEnd        -- when the current period ends and a new one is planned
local waiting          -- a pop quiz that is waiting for combat to end
local lastPop = -1e9
local MIN_GAP = 60     -- seconds between two pop quizzes

local function P() return ns.DB.pop end

local function InCombat()
  return (InCombatLockdown and InCombatLockdown()) or (UnitAffectingCombat and UnitAffectingCombat("player"))
end

-- Plans the pop quizzes for one period starting now.
local function Plan(now)
  local p = P()
  local length = p.interval * 60
  periodEnd = now + length
  due = {}
  for i = 1, p.count do
    if p.random then
      due[#due + 1] = now + math.random() * length
    else
      due[#due + 1] = now + length * i / p.count
    end
  end
  table.sort(due)
end

function ns.ReplanPop()
  periodEnd = nil
  due = {}
end

local function PlaySoundSafe()
  if not P().sound or not PlaySound then return end
  local kit = SOUNDKIT and (SOUNDKIT.READY_CHECK or SOUNDKIT.IG_QUEST_LIST_OPEN)
  pcall(PlaySound, kit or 8960)
end

-- True inside a dungeon, raid, scenario, battleground or arena.
local function InInstance()
  if not IsInInstance then return false end
  local inside, kind = IsInInstance()
  return inside and kind ~= "none" and kind ~= nil
end

-- reason: "timer", "quest", "level" or "manual". Returns true if it opened (or will open).
function ns.PopQuiz(reason)
  if not ns.DB then return false end
  local now = GetTime()
  if reason ~= "manual" and now - lastPop < MIN_GAP then return false end
  -- In an instance: quest/level pops are skipped, timed ones wait until you leave.
  if reason ~= "manual" and P().noInstance and InInstance() then return false end
  if InCombat() then
    waiting = reason
    return true
  end
  if ns.QuizIsShown and ns.QuizIsShown() then return false end
  if ns.StartPopQuiz(P().questions) then
    lastPop = now
    PlaySoundSafe()
    return true
  end
  return false
end

function ns.NextPopIn()
  if not ns.DB or not P().enabled then return nil end
  if due[1] then return math.max(0, due[1] - GetTime()) end
  if periodEnd then return math.max(0, periodEnd - GetTime()) end
end

---------------------------------------------------------------------------
-- Timer
---------------------------------------------------------------------------
local ticker = CreateFrame("Frame")
local acc = 0
ticker:SetScript("OnUpdate", function(_, dt)
  acc = acc + dt
  if acc < 1 or not ns.DB then return end
  acc = 0
  local p = P()
  local now = GetTime()
  if not p.enabled then
    due, periodEnd = {}, nil
    return
  end
  if not periodEnd then Plan(now) end
  if due[1] and due[1] <= now then
    table.remove(due, 1)
    if not ns.PopQuiz("timer") then
      -- busy (quiz open, one just ran, or inside an instance): try again in a minute
      table.insert(due, 1, now + MIN_GAP)
    end
  end
  if now >= periodEnd and not due[1] then Plan(now) end
end)

---------------------------------------------------------------------------
-- Events
---------------------------------------------------------------------------
local ev = CreateFrame("Frame")
ev:RegisterEvent("QUEST_TURNED_IN")
ev:RegisterEvent("PLAYER_LEVEL_UP")
ev:RegisterEvent("PLAYER_REGEN_ENABLED")
ev:SetScript("OnEvent", function(_, event)
  if not ns.DB then return end
  local p = P()
  local function later(reason)
    -- give the quest/level-up windows a moment to close first
    if C_Timer then C_Timer.After(2.5, function() ns.PopQuiz(reason) end) else ns.PopQuiz(reason) end
  end
  if event == "QUEST_TURNED_IN" then
    if p.onQuest and math.random(100) <= p.questChance then later("quest") end
  elseif event == "PLAYER_LEVEL_UP" then
    if p.onLevel then later("level") end
  elseif event == "PLAYER_REGEN_ENABLED" and waiting then
    local reason = waiting
    waiting = nil
    if C_Timer then C_Timer.After(3, function() ns.PopQuiz(reason) end) else ns.PopQuiz(reason) end
  end
end)

---------------------------------------------------------------------------
-- Settings page ("Azeroth Nihongo > Pop quiz")
---------------------------------------------------------------------------
local panel = CreateFrame("Frame")
panel.name = "Pop quiz"
panel.parent = "Azeroth Nihongo"

local title = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
title:SetPoint("TOPLEFT", 16, -16)
title:SetText("Pop quiz")

local sub = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
sub:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -8)
sub:SetText("The quiz opens by itself now and then. It always waits until you are out of combat.")

local widgets = {}
local y = -60

local function Check(key, label)
  local cb = CreateFrame("CheckButton", nil, panel, "UICheckButtonTemplate")
  cb:SetSize(26, 26)
  cb:SetPoint("TOPLEFT", 16, y)
  local fs = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
  fs:SetPoint("LEFT", cb, "RIGHT", 4, 0)
  fs:SetText(label)
  cb:SetScript("OnClick", function(self)
    P()[key] = self:GetChecked() and true or false
    ns.ReplanPop()
    ns.RefreshPopOptions()
  end)
  cb.sync = function() cb:SetChecked(P()[key]) end
  widgets[#widgets + 1] = cb
  y = y - 28
end

local function Stepper(key, label, min, max, step, fmt)
  local fs = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
  fs:SetPoint("TOPLEFT", 22, y - 4)
  fs:SetText(label)
  local minus = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
  minus:SetSize(26, 22)
  minus:SetText("-")
  minus:SetPoint("TOPLEFT", 300, y)
  local value = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
  value:SetPoint("LEFT", minus, "RIGHT", 4, 0)
  value:SetWidth(70)
  value:SetJustifyH("CENTER")
  local plus = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
  plus:SetSize(26, 22)
  plus:SetText("+")
  plus:SetPoint("LEFT", value, "RIGHT", 4, 0)
  local function change(d)
    local v = P()[key] + d
    if IsShiftKeyDown() then v = P()[key] + d * 5 end
    P()[key] = math.max(min, math.min(max, v))
    ns.ReplanPop()
    ns.RefreshPopOptions()
  end
  minus:SetScript("OnClick", function() change(-step) end)
  plus:SetScript("OnClick", function() change(step) end)
  local holder = { sync = function() value:SetText(fmt(P()[key])) end }
  widgets[#widgets + 1] = holder
  y = y - 30
end

local function Minutes(v) return v .. " min" end
local function Times(v) return v .. (v == 1 and " time" or " times") end
local function Number(v) return tostring(v) end
local function Percent(v) return v .. "%" end

Check("enabled", "Pop quiz on a timer")
Stepper("interval", "Period length", 1, 240, 5, Minutes)
Stepper("count", "Pop quizzes per period", 1, 20, 1, Times)
Check("random", "Random times in the period (off = evenly spaced)")
y = y - 8
Stepper("questions", "Questions per pop quiz", 1, 20, 1, Number)

-- What a pop quiz asks
do
  local KINDS = { "quiz", "kana", "both" }
  local KIND_NAME = {
    quiz = "Same as the quiz window",
    kana = "Kana only (hiragana practice)",
    both = "Kana and quiz mode mixed",
  }
  local fs = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
  fs:SetPoint("TOPLEFT", 22, y - 4)
  fs:SetText("Pop quiz asks")
  local b = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
  b:SetSize(230, 22)
  b:SetPoint("TOPLEFT", 300, y)
  b:SetScript("OnClick", function()
    local p = P()
    for i, k in ipairs(KINDS) do
      if k == p.kind then p.kind = KINDS[i % #KINDS + 1]; break end
    end
    if not KIND_NAME[p.kind] then p.kind = "quiz" end
    ns.RefreshPopOptions()
  end)
  widgets[#widgets + 1] = { sync = function() b:SetText(KIND_NAME[P().kind] or KIND_NAME.quiz) end }
  y = y - 30
  local note = panel:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
  note:SetPoint("TOPLEFT", 22, y)
  note:SetText("Kana pop quizzes use the kana settings from the quiz (hiragana/katakana, dakuten, combos).")
  y = y - 18
end
y = y - 8
Check("onQuest", "Pop quiz after turning in a quest")
Stepper("questChance", "Chance after a quest", 10, 100, 10, Percent)
Check("onLevel", "Pop quiz when you level up")
Check("noInstance", "No pop quiz in dungeons, raids, battlegrounds or arenas")
Check("sound", "Play a sound when a pop quiz opens")

y = y - 10
local testBtn = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
testBtn:SetSize(140, 22)
testBtn:SetText("Pop quiz now")
testBtn:SetPoint("TOPLEFT", 16, y)
testBtn:SetScript("OnClick", function() ns.PopQuiz("manual") end)

local status = panel:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
status:SetPoint("TOPLEFT", 20, y - 34)
status:SetJustifyH("LEFT")

local hint = panel:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
hint:SetPoint("TOPLEFT", status, "BOTTOMLEFT", 0, -6)
hint:SetText("Shift-click + or - to change by 5 steps.")

local function StatusText()
  local p = P()
  local parts = {}
  if p.enabled then
    parts[#parts + 1] = ("%s every %d min (%s)."):format(Times(p.count), p.interval,
      p.random and "random times" or "evenly spaced")
    local n = ns.NextPopIn()
    if n then parts[#parts + 1] = ("Next timed pop quiz in about %d min."):format(math.ceil(n / 60)) end
  else
    parts[#parts + 1] = "Timer is off."
  end
  return table.concat(parts, " ")
end

function ns.RefreshPopOptions()
  if not ns.DB then return end
  for _, w in ipairs(widgets) do w.sync() end
  status:SetText(StatusText())
end

panel:SetScript("OnShow", ns.RefreshPopOptions)

function ns.RegisterPopOptions(parentCategory)
  if parentCategory and Settings and Settings.RegisterCanvasLayoutSubcategory then
    Settings.RegisterCanvasLayoutSubcategory(parentCategory, panel, panel.name)
  elseif InterfaceOptions_AddCategory then
    InterfaceOptions_AddCategory(panel)
  end
end

function ns.PopStatus()
  return StatusText()
end
