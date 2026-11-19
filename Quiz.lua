-- Quiz: practise words from the dictionary and words in random WoW items.
local _, ns = ...

local GetItemInfo = (C_Item and C_Item.GetItemInfo) or GetItemInfo
local RequestLoadItem = C_Item and C_Item.RequestLoadItemDataByID
local GetContainerNumSlots = (C_Container and C_Container.GetContainerNumSlots) or GetContainerNumSlots
local GetContainerItemID = (C_Container and C_Container.GetContainerItemID) or GetContainerItemID

local MAX_ITEM_ID = 24300   -- vanilla items
local POOL_MAX = 60
local DEFAULT_FONT = "Fonts\\FRIZQT__.TTF"
local LEARNED = 3           -- right answers before a word counts as learned

local Q            -- DB.quiz
local cur          -- current question
local popTotal, popDone  -- set while a pop quiz is running
local practice     -- { name, keys, kana } while practising a list from the lexicon
local popMode      -- what the running pop quiz asks ("kana" or "both"), nil = the quiz mode
local lastTarget
local dictKeys

---------------------------------------------------------------------------
-- Window
---------------------------------------------------------------------------
local F = CreateFrame("Frame", "AzerothNihongoQuiz", UIParent,
  BackdropTemplateMixin and "BackdropTemplate" or nil)
F:SetSize(470, 460)
F:SetPoint("CENTER", 0, 60)
F:SetFrameStrata("DIALOG")
F:SetClampedToScreen(true)
F:SetMovable(true)
F:EnableMouse(true)
F:RegisterForDrag("LeftButton")
F:SetScript("OnDragStart", F.StartMoving)
F:SetScript("OnDragStop", F.StopMovingOrSizing)
F:Hide()
if F.SetBackdrop then
  F:SetBackdrop({
    bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
    edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
    tile = true, tileSize = 32, edgeSize = 32,
    insets = { left = 11, right = 12, top = 12, bottom = 11 },
  })
end
tinsert(UISpecialFrames, "AzerothNihongoQuiz") -- Esc closes

local close = CreateFrame("Button", nil, F, "UIPanelCloseButton")
close:SetPoint("TOPRIGHT", -6, -6)

-- jpSize set = uses the Japanese font at that size
local function FS(template, jpSize)
  local fs = F:CreateFontString(nil, "OVERLAY", template or "GameFontHighlight")
  fs.jpSize = jpSize
  return fs
end

local title = FS("GameFontNormalLarge", 18)
title:SetPoint("TOP", 0, -20)

local function Button(label, w, h)
  local b = CreateFrame("Button", nil, F, "UIPanelButtonTemplate")
  b:SetSize(w, h)
  b:SetText(label)
  return b
end

local modeBtn = Button("", 136, 22)
modeBtn:SetPoint("TOPLEFT", 22, -48)
local dirBtn = Button("", 136, 22)
dirBtn:SetPoint("LEFT", modeBtn, "RIGHT", 6, 0)
local labelBtn = Button("", 148, 22)
labelBtn:SetPoint("LEFT", dirBtn, "RIGHT", 6, 0)

local score = FS("GameFontHighlightSmall")
score:SetPoint("TOP", 0, -78)

local icon = F:CreateTexture(nil, "ARTWORK")
icon:SetSize(32, 32)
icon:SetPoint("TOPLEFT", 26, -96)

local itemName = FS("GameFontHighlight", 15)
itemName:SetPoint("LEFT", icon, "RIGHT", 8, 0)
itemName:SetPoint("RIGHT", F, "RIGHT", -24, 0)
itemName:SetJustifyH("LEFT")

local prompt = FS("GameFontNormal")
prompt:SetPoint("TOP", 0, -132)

local question = FS("GameFontHighlightLarge", 30)
question:SetPoint("TOP", 0, -168)

local sub = FS("GameFontHighlight", 16)
sub:SetPoint("TOP", 0, -206)

local answers = {}
for i = 1, 4 do
  local b = Button("", 206, 48)
  local col, row = (i - 1) % 2, math.floor((i - 1) / 2)
  b:SetPoint("TOPLEFT", 24 + col * 216, -234 - row * 56)
  b:SetScript("OnClick", function() ns.QuizAnswer(i) end)
  answers[i] = b
end

local feedback = FS("GameFontHighlight", 15)
feedback:SetPoint("TOP", 0, -350)
feedback:SetWidth(420)
if feedback.SetSpacing then feedback:SetSpacing(4) end

local hintBtn = Button("Hint", 100, 22)
hintBtn:SetPoint("BOTTOMLEFT", 24, 18)
local sayBtn = Button("Say it", 100, 22)
sayBtn:SetPoint("BOTTOM", 0, 18)
local nextBtn = Button("Next  >", 100, 22)
nextBtn:SetPoint("BOTTOMRIGHT", -24, 18)

local function JPFont(fs, size)
  local path = ns.fontPath or DEFAULT_FONT
  if fs:SetFont(path, size, "") == false then fs:SetFont(DEFAULT_FONT, size, "") end
end

-- Answer buttons get the Japanese font through font objects. A button puts its own
-- font objects back on its text when it is shown or hovered, which used to undo
-- SetFont and show kana as boxes.
local fontObjs = {}
local function JPFontObject(size)
  local o = fontObjs[size]
  if not o then
    o = CreateFont("AzerothNihongoQuizFont" .. size)
    fontObjs[size] = o
  end
  local path = ns.fontPath or DEFAULT_FONT
  if o:SetFont(path, size, "") == false then o:SetFont(DEFAULT_FONT, size, "") end
  o:SetTextColor(1, 0.82, 0)
  return o
end

local function ButtonFont(b, size)
  b.jpSize = size
  local o = JPFontObject(size)
  b:SetNormalFontObject(o)
  b:SetHighlightFontObject(o)
  b:SetDisabledFontObject(o)
  JPFont(b:GetFontString(), size)
end

local function ApplyFonts()
  for _, fs in ipairs({ title, itemName, question, sub, feedback }) do
    JPFont(fs, fs.jpSize)
  end
  for _, b in ipairs(answers) do ButtonFont(b, 15) end
end

-- The first time a font file is used after login the game may still be loading it,
-- and text drawn before that shows as boxes. Setting the font and text again a moment
-- later draws it properly.
local function Redraw()
  if not F:IsShown() then return end
  for _, fs in ipairs({ title, itemName, question, sub, feedback }) do
    JPFont(fs, fs.jpSize)
    local t = fs:GetText()
    if t then fs:SetText(t) end
  end
  for _, b in ipairs(answers) do
    if b:IsShown() then
      local fs = b:GetFontString()
      local r, g, bl = fs:GetTextColor()
      ButtonFont(b, b.jpSize or 15)
      local t = b:GetText()
      if t then b:SetText(t) end
      fs:SetTextColor(r, g, bl)
    end
  end
end
local function RedrawSoon()
  if C_Timer then
    C_Timer.After(0.1, Redraw)
    C_Timer.After(0.6, Redraw)
  end
end

---------------------------------------------------------------------------
-- Helpers
---------------------------------------------------------------------------
local function Keys()
  if not dictKeys then
    dictKeys = {}
    for k in pairs(ns.dict) do dictKeys[#dictKeys + 1] = k end
    table.sort(dictKeys)
  end
  return dictKeys
end

local function Stats(k) return Q.words[k] or {} end

local function Learned(k)
  local s = Stats(k)
  return (s.r or 0) >= LEARNED and (s.r or 0) > (s.w or 0)
end

-- "new" (never in a quiz), "wrong" (last answer wrong), "right" or "learned"
-- (right at least 3 times, more right than wrong, last answer right).
local function StatusOf(s)
  if not s or ((s.r or 0) + (s.w or 0)) == 0 then return "new" end
  local last = s.last
  if last == nil then last = (s.r or 0) >= (s.w or 0) end
  if not last then return "wrong" end
  if (s.r or 0) >= LEARNED and (s.r or 0) > (s.w or 0) then return "learned" end
  return "right"
end

function ns.WordStatus(k) return StatusOf(ns.DB and ns.DB.quiz.words[k]) end
function ns.KanaStatus(k) return StatusOf(ns.DB and ns.DB.quiz.kana[k]) end
function ns.KanaStats(k) return ns.DB and ns.DB.quiz.kana[k] end

local function Weight(k, stats)
  local s = (stats or Q.words)[k]
  if not s then return 3 end
  return math.max(0.5, 2 + 3 * (s.w or 0) - (s.r or 0))
end

local function WeightedPick(list, getKey, stats)
  local total = 0
  for _, v in ipairs(list) do total = total + Weight(getKey and getKey(v) or v, stats) end
  local r = math.random() * total
  for _, v in ipairs(list) do
    r = r - Weight(getKey and getKey(v) or v, stats)
    if r <= 0 then return v end
  end
  return list[#list]
end

-- Should this word be shown with kana next to the kanji?
local function WithKana(k)
  if Q.labels == "both" then return true end
  if Q.labels == "adaptive" then return not Learned(k) end
  return false
end

-- How a word is written in the quiz (answer buttons and the question).
local function Written(k, twoLines)
  local e = ns.dict[k]
  local DB = ns.DB
  if not (DB.showKanji or DB.showKana) then return ns.Romaji(k) end
  if not e.kanji or not DB.showKanji or Q.labels == "kana" then return e.kana end
  if WithKana(k) then
    return e.kanji .. (twoLines and "\n" or "  ") .. "|cffffd100" .. e.kana .. "|r"
  end
  return e.kanji
end

local function ShortJP(k)
  local e = ns.dict[k]
  if e.kanji and ns.DB.showKanji and Q.labels ~= "kana" then return e.kanji end
  return e.kana
end

local function FirstChar(s)
  return s:match("^[%z\1-\127\194-\244][\128-\191]*") or ""
end

local function Distractors(target, dir)
  local keys = Keys()
  local t = ns.dict[target]
  local used = { [t.kana] = true }
  if t.kanji then used[t.kanji] = true end
  local out, tries = {}, 0
  while #out < 3 and tries < 400 do
    tries = tries + 1
    local k = keys[math.random(#keys)]
    local e = ns.dict[k]
    if k ~= target and ns.Group(k) ~= ns.Group(target)
      and not used[e.kana] and not (e.kanji and used[e.kanji])
      and (not k:find(" ")) == (not target:find(" ")) then
      used[e.kana] = true
      if e.kanji then used[e.kanji] = true end
      out[#out + 1] = k
    end
  end
  return out
end

local function Shuffle(t)
  for i = #t, 2, -1 do
    local j = math.random(i)
    t[i], t[j] = t[j], t[i]
  end
end

---------------------------------------------------------------------------
-- Items: a pool of random items with at least one known word
---------------------------------------------------------------------------
local pool, pending, poolSeen = {}, {}, {}

-- Item info + the dictionary words in its name, each resolved to the meaning that
-- fits the item (the other words in the name and the item type are the context).
local function MakeItem(id)
  local name, _, quality, _, _, class, subclass, _, _, tex = GetItemInfo(id)
  if not name then return nil, false end
  local m = ns.Match(name)
  if #m == 0 then return nil, true end
  local ctx = ns.Context(name, class, subclass)
  for _, x in ipairs(m) do x.key, x.certain = ns.ResolveSense(x.key, ctx) end
  local kind
  if class and subclass and subclass ~= class then kind = class .. " - " .. subclass else kind = class end
  return { id = id, name = name, quality = quality, icon = tex, matches = m, kind = kind }, true
end

local function Consider(id)
  if poolSeen[id] then return true end
  local item, known = MakeItem(id)
  if not known then return false end
  poolSeen[id] = true
  if item and #pool < POOL_MAX then pool[#pool + 1] = item end
  return true
end

local function Prefetch(n)
  for _ = 1, n do
    local id = math.random(1, MAX_ITEM_ID)
    if not poolSeen[id] and not pending[id] then
      if not Consider(id) then
        pending[id] = true
        if RequestLoadItem then RequestLoadItem(id) end
      end
    end
  end
end

local function BagItem()
  if not GetContainerNumSlots or not GetContainerItemID then return end
  local found = {}
  for bag = 0, 4 do
    for slot = 1, (GetContainerNumSlots(bag) or 0) do
      local id = GetContainerItemID(bag, slot)
      if id then
        local item = MakeItem(id)
        if item then
          item.bag = true
          found[#found + 1] = item
        end
      end
    end
  end
  if #found > 0 then return found[math.random(#found)] end
end

local ev = CreateFrame("Frame")
ev:RegisterEvent("GET_ITEM_INFO_RECEIVED")
ev:SetScript("OnEvent", function(_, _, id, success)
  if id and pending[id] then
    pending[id] = nil
    if success then Consider(id) else poolSeen[id] = true end
  end
end)

---------------------------------------------------------------------------
-- Questions
---------------------------------------------------------------------------
local MODE_LABEL = { words = "Mode: Words", items = "Mode: Items", mixed = "Mode: Mixed", kana = "Mode: Kana" }
local DIR_LABEL = { jp = "JP -> English", en = "English -> JP", mixed = "Direction: Mixed" }
local LABELS_LABEL = { adaptive = "Answers: Adaptive", both = "Answers: Kanji + kana", kana = "Answers: Kana only" }
local KANASET_LABEL = { hira = "Kana: Hiragana", kata = "Kana: Katakana", both = "Kana: Both" }
local NEXT_MODE = { words = "items", items = "mixed", mixed = "kana", kana = "words" }
local NEXT_DIR = { jp = "en", en = "mixed", mixed = "jp" }
local NEXT_LABELS = { adaptive = "both", both = "kana", kana = "adaptive" }
local NEXT_KANASET = { hira = "kata", kata = "both", both = "hira" }

local function KanaPoolNow()
  return ns.KanaPool(Q.kanaSet, Q.kanaDakuten, Q.kanaCombos)
end

local function UpdateScore()
  local pct = Q.total > 0 and math.floor(Q.right / Q.total * 100 + 0.5) or 0
  local text = ("Correct: %d / %d  (%d%%)     Streak: %d     Best: %d"):format(
    Q.right, Q.total, pct, Q.streak, Q.best)
  if Q.mode == "kana" then
    local poolNow, learned = KanaPoolNow(), 0
    for _, k in ipairs(poolNow) do if ns.KanaStatus(k) == "learned" then learned = learned + 1 end end
    text = text .. ("     Kana learned: %d / %d"):format(learned, #poolNow)
  end
  score:SetText(text)
  modeBtn:SetText(MODE_LABEL[Q.mode] or MODE_LABEL.mixed)
  dirBtn:SetText(DIR_LABEL[Q.direction])
  if Q.mode == "kana" then
    labelBtn:SetText(KANASET_LABEL[Q.kanaSet] or KANASET_LABEL.hira)
  else
    labelBtn:SetText(LABELS_LABEL[Q.labels] or LABELS_LABEL.adaptive)
  end
end

-- Three wrong answers for a kana question: one that looks alike when there is one,
-- the rest of the same script and kind (single kana or combo), never the same sound.
local function KanaDistractors(target, list)
  local used = { [ns.ToRomaji(target)] = true }
  local out = {}
  local function try(k)
    local r = ns.ToRomaji(k)
    if #out < 3 and k ~= target and not used[r] then
      used[r] = true
      out[#out + 1] = k
    end
  end
  local sim = ns.SimilarKana(target)
  if #sim > 0 then try(sim[math.random(#sim)]) end
  local kata, combo = ns.IsKatakana(target), #target > 3
  local function Same(src)
    local t = {}
    for _, k in ipairs(src) do
      if ns.IsKatakana(k) == kata and (#k > 3) == combo then t[#t + 1] = k end
    end
    return t
  end
  local cands = Same(list)
  if #cands < 8 then cands = Same(ns.KanaPool(kata and "kata" or "hira", true, true)) end
  for _ = 1, 200 do
    if #out >= 3 then break end
    try(cands[math.random(#cands)])
  end
  return out
end

local function BuildKanaQuestion(q, list)
  q.kana = true
  local target
  for _ = 1, 5 do
    target = WeightedPick(list, nil, Q.kana)
    if target ~= lastTarget or #list == 1 then break end
  end
  q.target = target
  lastTarget = target
  q.options = KanaDistractors(target, list)
  q.options[#q.options + 1] = target
  Shuffle(q.options)
  for i, k in ipairs(q.options) do
    if k == target then q.correct = i end
  end
  return q
end

local function ItemNameWithMark(item, m, dir)
  local hex = "|cffffffff"
  local qc = ITEM_QUALITY_COLORS and ITEM_QUALITY_COLORS[item.quality]
  if qc and qc.hex then hex = qc.hex end
  local name = item.name
  local before, word, after = name:sub(1, m.s - 1), name:sub(m.s, m.e), name:sub(m.e + 1)
  local mark = "|cff40ff40[" .. (dir == "jp" and ShortJP(m.key) or word) .. "]|r"
  return hex .. before .. "|r" .. mark .. hex .. after .. "|r"
end

local function BuildQuestion()
  local dir = Q.direction
  if dir == "mixed" then dir = (math.random(2) == 1) and "jp" or "en" end
  local mode = popMode or Q.mode
  if mode == "both" then mode = (math.random(2) == 1) and "kana" or Q.mode end
  if mode == "mixed" then mode = (math.random(2) == 1) and "items" or "words" end

  local q = { dir = dir }
  if practice and practice.kana then
    return BuildKanaQuestion(q, practice.keys)
  elseif not practice and mode == "kana" then
    return BuildKanaQuestion(q, KanaPoolNow())
  end
  if practice then
    local target
    for _ = 1, 5 do
      target = WeightedPick(practice.keys)
      if target ~= lastTarget or #practice.keys == 1 then break end
    end
    q.target = target
  elseif mode == "items" then
    local item
    if math.random(100) <= 30 then item = BagItem() end
    if not item and #pool > 0 then item = table.remove(pool, math.random(#pool)) end
    if not item then item = BagItem() end
    Prefetch(10)
    if item then
      -- Prefer words whose meaning is clear from the item.
      local sure = {}
      for _, x in ipairs(item.matches) do if x.certain then sure[#sure + 1] = x end end
      local m = WeightedPick(#sure > 0 and sure or item.matches, function(x) return x.key end)
      q.item, q.match, q.target = item, m, m.key
    else
      q.loading = true
    end
  end
  if not q.target then
    local target
    for _ = 1, 5 do
      target = WeightedPick(Keys())
      if target ~= lastTarget then break end
    end
    q.target = target
  end
  lastTarget = q.target

  q.options = Distractors(q.target, dir)
  q.options[#q.options + 1] = q.target
  Shuffle(q.options)
  for i, k in ipairs(q.options) do
    if k == q.target then q.correct = i end
  end
  return q
end

local function ShowQuestion(q)
  cur = q
  ApplyFonts()
  UpdateScore()
  if popTotal then
    title:SetText(("|cffff9933Pop quiz!|r  |cffcccccc%d / %d|r"):format(popDone + 1, popTotal))
  elseif practice then
    title:SetText("|cff80c0ffPractice:|r " .. practice.name .. ("  |cffcccccc(%d %s)|r"):format(
      #practice.keys, practice.kana and "kana" or "words"))
  else
    title:SetText("日本語クイズ  |cffccccccJapanese Quiz|r")
  end
  nextBtn:SetText("Next  >")
  feedback:SetText(q.loading and "|cff999999(Loading items from the server - word question for now)|r" or "")
  sub:SetText("")

  if q.item then
    icon:SetTexture(q.item.icon)
    icon:Show()
    local extra = {}
    if q.item.kind then extra[#extra + 1] = q.item.kind end
    if q.item.bag then extra[#extra + 1] = "from your bags" end
    itemName:SetText("|cff999999Item:|r " .. ItemNameWithMark(q.item, q.match, q.dir)
      .. (#extra > 0 and ("  |cff999999(" .. table.concat(extra, ", ") .. ")|r") or ""))
    itemName:Show()
  else
    icon:Hide()
    itemName:Hide()
  end

  if q.kana then
    local script = ns.IsKatakana(q.target) and "katakana" or "hiragana"
    if q.dir == "jp" then
      prompt:SetText("How do you read this " .. script .. "?")
      question:SetText(q.target)
    else
      prompt:SetText("Which " .. script .. " is this sound?")
      question:SetText("|cff80c0ff" .. ns.KanaRomaji(q.target) .. "|r")
    end
    for i, b in ipairs(answers) do
      local k = q.options[i]
      if k then
        b:SetText(q.dir == "jp" and ns.KanaRomaji(k) or k)
        ButtonFont(b, q.dir == "jp" and 16 or 24)
        b:GetFontString():SetTextColor(1, 0.82, 0)
        b:Show()
      else
        b:Hide()
      end
    end
    return
  end

  local e = ns.dict[q.target]
  local hasSenses = #ns.OtherSenses(q.target) > 0
  if q.dir == "jp" then
    if q.item then
      prompt:SetText("One word in this item's name is written in Japanese.\nWhich English word is it?")
    else
      prompt:SetText("What does this Japanese word mean?")
    end
    question:SetText(ShortJP(q.target))
    if e.kanji and ShortJP(q.target) == e.kanji and WithKana(q.target) then
      sub:SetText("|cffffd100" .. e.kana .. "|r")
    end
  else
    if q.item then
      prompt:SetText("One word in this item's name is marked.\nHow is that word written in Japanese?")
      local word = q.item.name:sub(q.match.s, q.match.e):lower()
      question:SetText(hasSenses and ns.Label(q.target) or word)
    else
      prompt:SetText("How is this English word written in Japanese?")
      question:SetText(ns.Label(q.target))
    end
  end

  for i, b in ipairs(answers) do
    local k = q.options[i]
    if k then
      b:SetText(q.dir == "jp" and ns.Label(k) or Written(k, true))
      b:GetFontString():SetTextColor(1, 0.82, 0)
      b:Show()
    else
      b:Hide()
    end
  end
end

-- Signs in the question that you have never met: never asked and never written.
local function NewSigns(q)
  local out = {}
  local w = ns.DB.write or {}
  if q.kana then
    if Q.writeNewKana and not Q.kana[q.target] then
      for ch in q.target:gmatch("[%z\1-\127\194-\244][\128-\191]*") do
        if not w[ch] and ns.CanWrite and ns.CanWrite(ch) then out[#out + 1] = ch end
      end
    end
  elseif Q.writeNewKanji and not Q.words[q.target] then
    local e = ns.dict[q.target]
    if e and e.kanji then
      for _, ch in ipairs(ns.KanjiIn(e.kanji)) do
        if not w[ch] and ns.CanWrite and ns.CanWrite(ch) then out[#out + 1] = ch end
      end
    end
  end
  return out
end

-- Shows the question with its answers hidden while the new signs are written.
local function ShowIntro(q, chars)
  ShowQuestion(q)
  q.intro = true
  for _, b in ipairs(answers) do b:Hide() end
  local reads = {}
  for _, ch in ipairs(chars) do
    if ch:byte(1) == 0xE3 then -- kana (kanji start with a higher byte)
      reads[#reads + 1] = "|cffffffff" .. ch .. "|r |cff80c0ff[" .. ns.KanaRomaji(ch) .. "]|r"
    else
      reads[#reads + 1] = "|cffffffff" .. ch .. "|r"
    end
  end
  prompt:SetText("|cffff9933New sign!|r Write it in the window on the right first.")
  sub:SetText(table.concat(reads, "   "))
  feedback:SetText("|cff999999The question comes when you have written it. \"Skip\" goes straight to it.|r")
  nextBtn:SetText("Skip  >")
  local ok = ns.WriteIntro(chars, function()
    if cur == q and q.intro and F:IsShown() then
      q.intro = nil
      ShowQuestion(q)
      RedrawSoon()
    end
  end)
  if not ok then
    q.intro = nil
    ShowQuestion(q)
  end
end

function ns.QuizNext()
  local q = BuildQuestion()
  local chars = ns.WriteIntro and NewSigns(q) or {}
  if #chars > 0 then ShowIntro(q, chars) else ShowQuestion(q) end
  RedrawSoon()
end

function ns.QuizAnswer(i)
  local q = cur
  if not q or q.answered or q.intro then return end
  q.answered = true
  local ok = (i == q.correct)
  local stats = q.kana and Q.kana or Q.words
  local s = stats[q.target] or {}
  stats[q.target] = s
  Q.total = Q.total + 1
  if ok then
    Q.right = Q.right + 1
    Q.streak = Q.streak + 1
    if Q.streak > Q.best then Q.best = Q.streak end
    s.r = (s.r or 0) + 1
  else
    Q.streak = 0
    s.w = (s.w or 0) + 1
  end
  s.last = ok
  if time then s.t = time() end

  for j, b in ipairs(answers) do
    local fs = b:GetFontString()
    if j == q.correct then fs:SetTextColor(0.3, 1, 0.3)
    elseif j == i then fs:SetTextColor(1, 0.3, 0.3)
    else fs:SetTextColor(0.5, 0.5, 0.5) end
  end

  if q.kana then
    local t = q.target
    local other = ns.IsKatakana(t) and ns.ToHira(t) or ns.ToKata(t)
    local lines = {
      (ok and "|cff40ff40Correct!|r  " or "|cffff5050Wrong.|r  ") .. "|cffffffff" .. t .. "|r = |cff80c0ff"
        .. ns.KanaRomaji(t) .. "|r   |cff999999(" .. (ns.IsKatakana(t) and "hiragana " or "katakana ")
        .. "|r|cffffd100" .. other .. "|r|cff999999)|r",
    }
    if not ok and q.options[i] then
      lines[#lines + 1] = "|cff999999You picked|r " .. q.options[i] .. " |cff999999=|r "
        .. ns.KanaRomaji(q.options[i])
    end
    local ex = ns.KanaExample(t)
    if ex then
      local e = ns.dict[ex]
      lines[#lines + 1] = "|cff999999e.g.|r " .. (e.kanji and (e.kanji .. " ") or "") .. "|cffffd100"
        .. e.kana .. "|r |cff80c0ff[" .. ns.Romaji(ex) .. "]|r = " .. ns.Label(ex)
    end
    feedback:SetText(table.concat(lines, "\n"))
  else
    local e = ns.dict[q.target]
    local full = (e.kanji and ("|cffffffff" .. e.kanji .. "|r  ") or "") .. "|cffffd100" .. e.kana .. "|r  "
      .. "|cff80c0ff[" .. ns.Romaji(q.target) .. "]|r  = " .. ns.Label(q.target)
    local b = ns.BreakdownText and ns.BreakdownText(q.target)
    feedback:SetText((ok and "|cff40ff40Correct!|r  " or "|cffff5050Wrong.|r  ") .. full
      .. (b and ("\n" .. b) or ""))
  end
  UpdateScore()
  if ns.RefreshLexicon then ns.RefreshLexicon() end
  if Q.speak then
    if q.kana then ns.SpeakKana(q.target) else ns.Speak(q.target) end
  end

  if popTotal then
    popDone = popDone + 1
    if popDone >= popTotal then nextBtn:SetText("Done") end
  end

  if ok and Q.autoNext and not popTotal and C_Timer then
    C_Timer.After(2, function()
      if cur == q and F:IsShown() then ns.QuizNext() end
    end)
  end
end

hintBtn:SetScript("OnClick", function()
  local q = cur
  if not q then return end
  if q.kana then
    -- A word that starts with it, without the romaji.
    local ex = ns.KanaExample(q.target)
    if ex then
      sub:SetText("|cff999999As in|r |cffffd100" .. ns.dict[ex].kana .. "|r = " .. ns.Label(ex))
    else
      sub:SetText("|cff999999(no example word)|r")
    end
    return
  end
  local e = ns.dict[q.target]
  if q.dir == "jp" then
    local parts = {}
    if e.kanji then parts[#parts + 1] = "|cffffd100" .. e.kana .. "|r" end
    parts[#parts + 1] = "|cff80c0ff[" .. ns.Romaji(q.target) .. "]|r"
    sub:SetText(table.concat(parts, "   "))
  else
    sub:SetText("Starts with: |cffffd100" .. FirstChar(e.kana) .. "|r  [" .. ns.Romaji(q.target):sub(1, 2) .. "...]")
  end
end)

sayBtn:SetScript("OnClick", function()
  if not cur then return end
  if cur.kana then ns.SpeakKana(cur.target) else ns.Speak(cur.target) end
end)
nextBtn:SetScript("OnClick", function()
  if cur and cur.intro then
    -- Skip the writing: closing the writing window shows the question.
    local q = cur
    if ns.WritingIsShown() then _G.AzerothNihongoDraw:Hide() end
    if cur == q and q.intro then
      q.intro = nil
      ShowQuestion(q)
    end
    return
  end
  if popTotal and popDone >= popTotal then
    F:Hide()
  else
    ns.QuizNext()
  end
end)

modeBtn:SetScript("OnClick", function()
  Q.mode = NEXT_MODE[Q.mode] or "mixed"
  if Q.mode ~= "words" then Prefetch(40) end
  ns.QuizNext()
end)
dirBtn:SetScript("OnClick", function()
  Q.direction = NEXT_DIR[Q.direction] or "mixed"
  ns.QuizNext()
end)
labelBtn:SetScript("OnClick", function()
  if Q.mode == "kana" then
    Q.kanaSet = NEXT_KANASET[Q.kanaSet] or "hira"
  else
    Q.labels = NEXT_LABELS[Q.labels] or "adaptive"
  end
  ns.QuizNext()
end)

local function LabelTip(self, lines)
  self:SetScript("OnEnter", function()
    GameTooltip:SetOwner(self, "ANCHOR_TOP")
    for i, l in ipairs(lines) do
      if i == 1 then GameTooltip:AddLine(l) else GameTooltip:AddLine(l, 1, 1, 1, true) end
    end
    GameTooltip:Show()
  end)
  self:SetScript("OnLeave", function() GameTooltip:Hide() end)
end
LabelTip(modeBtn, { "Mode", "Words: random dictionary words.", "Items: a word from a random WoW item or something in your bags.", "Mixed: both.", "Kana: learn hiragana and katakana one character at a time." })
LabelTip(dirBtn, { "Direction", "JP -> English: read the Japanese, pick the meaning (kana: pick the romaji).", "English -> JP: pick the Japanese spelling (kana: pick the character)." })
LabelTip(labelBtn, { "How Japanese is shown", "Adaptive: kanji with kana under it until you have got the word right 3 times, then kanji only.", "Kanji + kana: always both.", "Kana only: no kanji.", " ", "In Kana mode this button picks hiragana, katakana or both." })

F:SetScript("OnShow", function()
  Q = ns.DB.quiz
  Prefetch(40)
  ns.QuizNext()
end)
F:SetScript("OnHide", function()
  popTotal, popDone, practice, popMode = nil, nil, nil, nil
  if cur and cur.intro then
    cur.intro = nil
    if ns.WritingIsShown and ns.WritingIsShown() then _G.AzerothNihongoDraw:Hide() end
  end
  if ns.RefreshLexicon then ns.RefreshLexicon() end
end)

function ns.ToggleQuiz()
  if not ns.DB then return end
  if F:IsShown() then
    F:Hide()
  else
    popTotal, popDone, practice, popMode = nil, nil, nil, nil
    F:Show()
  end
end

function ns.QuizIsShown() return F:IsShown() end

-- Starts a pop quiz with n questions; returns false if the quiz is already open.
function ns.StartPopQuiz(n)
  if not ns.DB or F:IsShown() then return false end
  popTotal, popDone, practice = n, 0, nil
  local kind = ns.DB.pop.kind
  popMode = (kind == "kana" or kind == "both") and kind or nil
  F:Show()
  return true
end

-- Quiz only these dictionary keys (from the lexicon) until the quiz is closed.
function ns.StartPractice(name, keys)
  if not ns.DB or #keys == 0 then return end
  popTotal, popDone, popMode = nil, nil, nil
  practice = { name = name, keys = keys }
  if F:IsShown() then ns.QuizNext() else F:Show() end
end

-- Same for a list of kana characters.
function ns.StartKanaPractice(name, list)
  if not ns.DB or #list == 0 then return end
  popTotal, popDone, popMode = nil, nil, nil
  practice = { name = name, keys = list, kana = true }
  if F:IsShown() then ns.QuizNext() else F:Show() end
end
AzerothNihongo_ToggleQuiz = ns.ToggleQuiz
