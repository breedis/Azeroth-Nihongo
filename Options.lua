local _, ns = ...

local panel = CreateFrame("Frame")
panel.name = "Azeroth Nihongo"
panel:Hide() -- so OnShow runs the first time the settings show it

local title = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
title:SetPoint("TOPLEFT", 16, -16)
title:SetText("Azeroth Nihongo")

local sub = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
sub:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -8)
sub:SetText("Hover over monsters, NPCs, items and spells to see the words in Japanese.")

local checks = {}
local y = -60

local function AddCheck(key, label, getTable)
  local cb = CreateFrame("CheckButton", nil, panel, "UICheckButtonTemplate")
  cb:SetSize(26, 26)
  cb:SetPoint("TOPLEFT", 16, y)
  local fs = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
  fs:SetPoint("LEFT", cb, "RIGHT", 4, 0)
  fs:SetText(label)
  cb.key = key
  cb.getTable = getTable or function() return ns.DB end
  cb:SetScript("OnClick", function(self)
    self.getTable()[key] = self:GetChecked() and true or false
    ns.Refresh()
  end)
  checks[#checks + 1] = cb
  y = y - 24
end

AddCheck("enabled", "Enabled (also: /jp, the JP button or a key binding)")
y = y - 6
AddCheck("showKanji", "Show kanji")
AddCheck("showKana", "Show hiragana / katakana")
AddCheck("showRomaji", "Show romaji")
AddCheck("showEnglish", "Show the English word")
AddCheck("showBreakdown", "Show kanji breakdown (which kana each kanji is read as)")
y = y - 6
AddCheck("scanAllLines", "Read every tooltip line (not just the name)")
AddCheck("requireShift", "Only show while Shift is held")
AddCheck("below", "Put the popup below the tooltip")
AddCheck("showButton", "Show the JP button on screen")
AddCheck("speakOnHover", "Say hovered words out loud")
AddCheck("collectMissing", "Collect words that have no translation yet (/jp missing)")
AddCheck("speak", "Quiz: say the word after answering", function() return ns.DB.quiz end)
AddCheck("autoNext", "Quiz: go to the next question by itself after a correct answer", function() return ns.DB.quiz end)
AddCheck("writeNewKana", "Quiz: write a new kana before it is asked the first time", function() return ns.DB.quiz end)
AddCheck("writeNewKanji", "Quiz: write the kanji of a new word before it is asked the first time", function() return ns.DB.quiz end)
AddCheck("kanaDakuten", "Kana quiz: include dakuten (ga, za, da, ba, pa ...)", function() return ns.DB.quiz end)
AddCheck("kanaCombos", "Kana quiz: include combos (kya, sha, cho ...)", function() return ns.DB.quiz end)

y = y - 10
local function SmallButton(label, width, onClick)
  local b = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
  b:SetSize(width, 22)
  b:SetText(label)
  b:SetScript("OnClick", onClick)
  return b
end

local sizeLabel = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
sizeLabel:SetPoint("TOPLEFT", 20, y - 4)
local minus = SmallButton("-", 26, function()
  ns.DB.fontSize = math.max(8, ns.DB.fontSize - 1); ns.Refresh(); ns.Test()
end)
minus:SetPoint("TOPLEFT", 130, y)
local plus = SmallButton("+", 26, function()
  ns.DB.fontSize = math.min(40, ns.DB.fontSize + 1); ns.Refresh(); ns.Test()
end)
plus:SetPoint("LEFT", minus, "RIGHT", 4, 0)

y = y - 32
local testBtn = SmallButton("Show example", 120, function() ns.Test() end)
testBtn:SetPoint("TOPLEFT", 16, y)
local fontBtn = SmallButton("Next font", 100, function() ns.CycleFont(); ns.Test() end)
fontBtn:SetPoint("LEFT", testBtn, "RIGHT", 8, 0)
local voiceBtn = SmallButton("Next voice", 100, function() ns.CycleVoice() end)
voiceBtn:SetPoint("LEFT", fontBtn, "RIGHT", 8, 0)
local quizBtn = SmallButton("Open quiz", 100, function() ns.ToggleQuiz() end)
quizBtn:SetPoint("LEFT", voiceBtn, "RIGHT", 8, 0)
local lexBtn = SmallButton("Open lexicon", 110, function() ns.ToggleLexicon() end)
lexBtn:SetPoint("LEFT", quizBtn, "RIGHT", 8, 0)
y = y - 28
local resetBtn = SmallButton("Reset button position", 170, function() ns.ResetButton() end)
resetBtn:SetPoint("TOPLEFT", 16, y)
local missBtn = SmallButton("Untranslated words", 160, function() ns.ToggleMissing() end)
missBtn:SetPoint("LEFT", resetBtn, "RIGHT", 8, 0)
local writeBtn = SmallButton("Writing practice", 140, function() ns.ToggleWriting() end)
writeBtn:SetPoint("LEFT", missBtn, "RIGHT", 8, 0)

local info = panel:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
info:SetPoint("TOPLEFT", 20, y - 32)
info:SetJustifyH("LEFT")

local function Sync()
  if not ns.DB then return end
  for _, cb in ipairs(checks) do cb:SetChecked(cb.getTable()[cb.key]) end
  sizeLabel:SetText("Text size: " .. ns.DB.fontSize)
  local v = ns.CurrentVoice and ns.CurrentVoice()
  info:SetText("Font: " .. (ns.fontPath or "default")
    .. "\nVoice: " .. (v and v.name or "no Japanese voice found (Windows: Settings > Time & language > Speech)")
    .. "\nKanji showing as boxes? Press \"Next font\"."
    .. "\nPop quiz settings: see \"Pop quiz\" under Azeroth Nihongo in the list on the left.")
end
panel:SetScript("OnShow", Sync)

function ns.RefreshOptions()
  if panel:IsShown() then Sync() end
end

function ns.RegisterOptions()
  if Settings and Settings.RegisterCanvasLayoutCategory then
    local category = Settings.RegisterCanvasLayoutCategory(panel, panel.name)
    Settings.RegisterAddOnCategory(category)
    ns.settingsCategory = category
    if ns.RegisterPopOptions then ns.RegisterPopOptions(category) end
  elseif InterfaceOptions_AddCategory then
    InterfaceOptions_AddCategory(panel)
    if ns.RegisterPopOptions then ns.RegisterPopOptions(nil) end
  end
end

function ns.OpenOptions()
  if ns.settingsCategory and Settings and Settings.OpenToCategory then
    Settings.OpenToCategory(ns.settingsCategory:GetID())
  elseif InterfaceOptionsFrame_OpenToCategory then
    InterfaceOptionsFrame_OpenToCategory(panel)
    InterfaceOptionsFrame_OpenToCategory(panel) -- twice: known Blizzard bug
  end
end
