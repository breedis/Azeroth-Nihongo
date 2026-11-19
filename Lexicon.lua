-- Lexicon: a kana chart, every kanji in the dictionary and the words you have met in
-- the quiz (right, wrong or not quizzed yet).
-- Japanese text never goes in GameTooltip (its font has no kana), so every tab has its
-- own info area instead.
local _, ns = ...

local DEFAULT_FONT = "Fonts\\FRIZQT__.TTF"
local CHAR = "[%z\1-\127\194-\244][\128-\191]*"

local STATUS_COLOR = { new = "ff8c8c8c", right = "ff66ff66", learned = "ffffd100", wrong = "ffff5959" }
local STATUS_NAME = { new = "not quizzed", right = "right", learned = "learned", wrong = "wrong" }
local DOT = "●"

local function Colored(status, text) return "|c" .. STATUS_COLOR[status] .. text .. "|r" end

---------------------------------------------------------------------------
-- Window
---------------------------------------------------------------------------
local L = CreateFrame("Frame", "AzerothNihongoLexicon", UIParent,
  BackdropTemplateMixin and "BackdropTemplate" or nil)
L:SetSize(660, 560)
L:SetPoint("CENTER", 0, 40)
L:SetFrameStrata("DIALOG")
L:SetClampedToScreen(true)
L:SetMovable(true)
L:EnableMouse(true)
L:RegisterForDrag("LeftButton")
L:SetScript("OnDragStart", L.StartMoving)
L:SetScript("OnDragStop", L.StopMovingOrSizing)
L:Hide()
if L.SetBackdrop then
  L:SetBackdrop({
    bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
    edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
    tile = true, tileSize = 32, edgeSize = 32,
    insets = { left = 11, right = 12, top = 12, bottom = 11 },
  })
end
tinsert(UISpecialFrames, "AzerothNihongoLexicon") -- Esc closes

local close = CreateFrame("Button", nil, L, "UIPanelCloseButton")
close:SetPoint("TOPRIGHT", -6, -6)

local fonts = {} -- { fontString, size } for everything that uses the Japanese font

local function SetJP(fs, size)
  if fs:SetFont(ns.fontPath or DEFAULT_FONT, size, "") == false then fs:SetFont(DEFAULT_FONT, size, "") end
end

local function Text(parent, size, justify)
  local fs = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
  fonts[#fonts + 1] = { fs, size }
  SetJP(fs, size)
  fs:SetJustifyH(justify or "LEFT")
  return fs
end

local function ApplyFonts()
  for _, f in ipairs(fonts) do SetJP(f[1], f[2]) end
end

local function Button(parent, label, w, h)
  local b = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
  b:SetSize(w, h or 22)
  b:SetText(label)
  return b
end

local function Cell(parent)
  local c = CreateFrame("Button", nil, parent)
  c.bg = c:CreateTexture(nil, "BACKGROUND")
  c.bg:SetAllPoints()
  c.bg:SetColorTexture(1, 1, 1, 0.04)
  c:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight", "ADD")
  return c
end

local title = Text(L, 18, "CENTER")
title:SetPoint("TOP", 0, -20)
title:SetText("辞書  |cffccccccLexicon|r")

local pages, tabs, order = {}, {}, {}
local current

local function NewPage(name, label)
  local p = CreateFrame("Frame", nil, L)
  p:SetPoint("TOPLEFT", 16, -80)
  p:SetPoint("BOTTOMRIGHT", -16, 16)
  p:Hide()
  pages[name] = p
  local b = Button(L, label, 130, 24)
  b:SetPoint("TOPLEFT", 22 + #order * 136, -46)
  b:SetScript("OnClick", function() ns.ShowLexiconTab(name) end)
  tabs[name] = b
  order[#order + 1] = name
  return p
end

---------------------------------------------------------------------------
-- Kana chart
---------------------------------------------------------------------------
local function CP(ch)
  local b1, b2, b3 = ch:byte(1, 3)
  if b1 and b3 and b1 >= 0xE0 and b1 <= 0xEF then
    return (b1 - 0xE0) * 4096 + (b2 - 0x80) * 64 + (b3 - 0x80)
  end
end

local function Enc(c)
  return string.char(0xE0 + math.floor(c / 4096), 0x80 + math.floor(c / 64) % 64, 0x80 + c % 64)
end

local function ToKata(s)
  local out = {}
  for ch in s:gmatch(CHAR) do
    local c = CP(ch)
    if c and c >= 0x3041 and c <= 0x3096 then ch = Enc(c + 0x60) end
    out[#out + 1] = ch
  end
  return table.concat(out)
end

local ROMA = { ["を"] = "wo", ["ぢ"] = "ji", ["づ"] = "zu" }

local NOTES = {
  ["し"] = "Written shi, not si.",
  ["ち"] = "Written chi, not ti.",
  ["つ"] = "Written tsu, not tu.",
  ["ふ"] = "Written fu: a soft sound between f and h.",
  ["は"] = "As the particle (topic marker) it is read wa.",
  ["へ"] = "As the particle (direction) it is read e.",
  ["を"] = "Written wo but said o. Only used as the object particle.",
  ["ん"] = "The only kana that is just a consonant. Before b, p and m it sounds like m.",
  ["ら"] = "The r sounds are between r and l.",
  ["じ"] = "じ and ぢ sound the same; じ is far more common.",
  ["ぢ"] = "Sounds like じ. Mostly used when ち gets voiced, e.g. はなぢ (nosebleed).",
  ["ず"] = "ず and づ sound the same; ず is far more common.",
  ["づ"] = "Sounds like ず. Mostly used when つ gets voiced.",
  ["ゆ"] = "There is no yi or ye in modern Japanese.",
  ["わ"] = "wi and we are old kana that are not used any more.",
}

local function Kana(h, extra)
  local t = { h = h, k = ToKata(h), r = ROMA[h] or ns.ToRomaji(h), note = NOTES[h] }
  if extra then for k, v in pairs(extra) do t[k] = v end end
  return t
end

local function Rows(list)
  local rows = {}
  for _, row in ipairs(list) do
    local r = {}
    for i, h in ipairs(row) do r[i] = h and Kana(h) or false end
    rows[#rows + 1] = r
  end
  return rows
end

local function KataOnly(k, r, note)
  return { k = k, r = r, note = note or "Katakana only: used for sounds from other languages." }
end

local SECTIONS = {
  {
    name = "Basic", cols = { "a", "i", "u", "e", "o" }, w = 96,
    rows = function() return Rows({
      { "あ", "い", "う", "え", "お" }, { "か", "き", "く", "け", "こ" },
      { "さ", "し", "す", "せ", "そ" }, { "た", "ち", "つ", "て", "と" },
      { "な", "に", "ぬ", "ね", "の" }, { "は", "ひ", "ふ", "へ", "ほ" },
      { "ま", "み", "む", "め", "も" }, { "や", false, "ゆ", false, "よ" },
      { "ら", "り", "る", "れ", "ろ" }, { "わ", false, false, false, "を" },
      { "ん", false, false, false, false },
    }) end,
  },
  {
    name = "Dakuten", cols = { "a", "i", "u", "e", "o" }, w = 96,
    intro = "The marks ゛ (dakuten) and ゜ (handakuten) change the sound: か ka -> が ga, は ha -> ば ba / ぱ pa.",
    rows = function() return Rows({
      { "が", "ぎ", "ぐ", "げ", "ご" }, { "ざ", "じ", "ず", "ぜ", "ぞ" },
      { "だ", "ぢ", "づ", "で", "ど" }, { "ば", "び", "ぶ", "べ", "ぼ" },
      { "ぱ", "ぴ", "ぷ", "ぺ", "ぽ" },
    }) end,
  },
  {
    name = "Combos", cols = { "ya", "yu", "yo" }, w = 150,
    intro = "An i-kana plus a small ゃ ゅ ょ makes one sound: き ki + ゃ = きゃ kya.",
    rows = function()
      local out = {}
      for _, s in ipairs({ "き", "し", "ち", "に", "ひ", "み", "り", "ぎ", "じ", "び", "ぴ" }) do
        out[#out + 1] = { s .. "ゃ", s .. "ゅ", s .. "ょ" }
      end
      return Rows(out)
    end,
  },
  {
    name = "Extras", cols = {}, w = 116,
    rows = function() return {
      {
        Kana("っ", { r = "(double)", note = "Small tsu: doubles the next consonant and makes a short pause. きって = kitte (stamp)." }),
        { k = "ー", r = "(long)", note = "Makes the vowel before it long. ケーキ = keeki (cake). Mostly used in katakana." },
        Kana("ぁ", { r = "small a", note = "Small vowels are mostly used in katakana to make new sounds: ファ = fa." }),
        Kana("ゃ", { r = "small ya", note = "Small ya/yu/yo join the kana before them: きゃ = kya. See Combos." }),
      },
      { KataOnly("ファ", "fa"), KataOnly("フィ", "fi"), KataOnly("フェ", "fe"), KataOnly("フォ", "fo") },
      { KataOnly("ティ", "ti"), KataOnly("ディ", "di"), KataOnly("トゥ", "tu"), KataOnly("ドゥ", "du") },
      { KataOnly("ウィ", "wi"), KataOnly("ウェ", "we"), KataOnly("ウォ", "wo"), KataOnly("ツァ", "tsa") },
      { KataOnly("ヴァ", "va"), KataOnly("ヴィ", "vi"), KataOnly("ヴ", "vu"), KataOnly("ヴェ", "ve") },
      { KataOnly("シェ", "she"), KataOnly("ジェ", "je"), KataOnly("チェ", "che"), KataOnly("ヴォ", "vo") },
    } end,
  },
}

local kanaPage = NewPage("kana", "Kana")
local kanaSection = 1
local kanaCells, kanaHeads, sectionBtns = {}, {}, {}

local kanaIntro = Text(kanaPage, 12)
kanaIntro:SetPoint("TOPLEFT", 4, -30)
kanaIntro:SetWidth(470)

-- Info area on the right
local INFO_X = 500
local kiBig = Text(kanaPage, 40)
kiBig:SetPoint("TOPLEFT", INFO_X, -36)
local kiRoma = Text(kanaPage, 18)
kiRoma:SetPoint("TOPLEFT", INFO_X, -90)
local kiNote = Text(kanaPage, 12)
kiNote:SetPoint("TOPLEFT", INFO_X, -120)
kiNote:SetWidth(126)
kiNote:SetJustifyV("TOP")
local kiHelp = Text(kanaPage, 11)
kiHelp:SetPoint("BOTTOMLEFT", INFO_X, 4)
kiHelp:SetWidth(126)
kiHelp:SetText("|cff999999White = hiragana\nGold = katakana\nClick to hear it.\nBackground: green = right,\ngold = learned, red = wrong|r")
local kanaPractise = Button(kanaPage, "Practise page", 126)
kanaPractise:SetPoint("BOTTOMLEFT", kiHelp, "TOPLEFT", 0, 8)
local kanaWrite = Button(kanaPage, "Write page", 126)
kanaWrite:SetPoint("BOTTOMLEFT", kanaPractise, "TOPLEFT", 0, 4)

local Example = ns.KanaExample

-- Can this chart entry be asked in the kana quiz? (not っ, ー or the small kana)
local function Quizzable(c) return not (c.r:find("^%(") or c.r:find("^small")) end

local function KanaQuizLine(ch)
  local s = ns.KanaStats(ch)
  local st = ns.KanaStatus(ch)
  if not s then return ch .. " " .. Colored(st, STATUS_NAME[st]) end
  return ch .. " " .. Colored(st, STATUS_NAME[st]) .. (" |cff66ff66%d|r/|cffff5959%d|r"):format(s.r or 0, s.w or 0)
end

local kanaInfo -- the entry shown in the info area

local function ShowKanaInfo(c)
  kanaInfo = c
  kiBig:SetText((c.h and ("|cffffffff" .. c.h .. "|r  ") or "") .. "|cffffd100" .. c.k .. "|r")
  kiRoma:SetText("|cff80c0ff" .. c.r .. "|r")
  local lines = {}
  if c.note then lines[#lines + 1] = c.note end
  if Quizzable(c) then
    local q = {}
    if c.h then q[#q + 1] = KanaQuizLine(c.h) end
    q[#q + 1] = KanaQuizLine(c.k)
    lines[#lines + 1] = "|cff999999Quiz:|r " .. table.concat(q, "\n")
  end
  -- One example word (hiragana first, else katakana).
  local ex = (c.h and Example(c.h)) or Example(c.k)
  if ex then
    local e = ns.dict[ex]
    lines[#lines + 1] = "|cff999999e.g.|r " .. (e.kanji and (e.kanji .. " ") or "")
      .. "|cffffd100" .. e.kana .. "|r |cff80c0ff[" .. ns.Romaji(ex) .. "]|r = " .. ns.Label(ex)
  end
  kiNote:SetText(table.concat(lines, "\n\n"))
end

local function GetKanaCell(i)
  local c = kanaCells[i]
  if c then return c end
  c = Cell(kanaPage)
  c.hira = Text(c, 20)
  c.hira:SetPoint("LEFT", 6, 0)
  c.kata = Text(c, 20)
  c.kata:SetPoint("LEFT", c.hira, "RIGHT", 4, 0)
  c.roma = Text(c, 13)
  c.roma:SetPoint("RIGHT", -6, 0)
  c:SetScript("OnEnter", function(self) ShowKanaInfo(self.data) end)
  c:SetScript("OnClick", function(self)
    ShowKanaInfo(self.data)
    ns.SpeakKana(self.data.h or self.data.k)
  end)
  kanaCells[i] = c
  return c
end

local function DrawKana()
  local sec = SECTIONS[kanaSection]
  for i, b in ipairs(sectionBtns) do
    if i == kanaSection then b:LockHighlight() else b:UnlockHighlight() end
  end
  for _, c in ipairs(kanaCells) do c:Hide() end
  for _, h in ipairs(kanaHeads) do h:Hide() end
  kanaIntro:SetText(sec.intro and ("|cffbbbbbb" .. sec.intro .. "|r") or "")
  local top = sec.intro and -62 or -34
  for i, label in ipairs(sec.cols) do
    local h = kanaHeads[i]
    if not h then
      h = Text(kanaPage, 12, "CENTER")
      kanaHeads[i] = h
    end
    h:SetWidth(sec.w)
    h:ClearAllPoints()
    h:SetPoint("TOPLEFT", 4 + (i - 1) * sec.w, top)
    h:SetText("|cff999999" .. label .. "|r")
    h:Show()
  end
  if #sec.cols > 0 then top = top - 18 end
  sec.cache = sec.cache or sec.rows()
  local n, first = 0, nil
  for r, row in ipairs(sec.cache) do
    for col, data in ipairs(row) do
      if data then
        n = n + 1
        local c = GetKanaCell(n)
        c:SetSize(sec.w - 4, 30)
        c:ClearAllPoints()
        c:SetPoint("TOPLEFT", 4 + (col - 1) * sec.w, top - (r - 1) * 32)
        c.data = data
        local worst
        if Quizzable(data) then
          for _, ch in ipairs({ data.k, data.h }) do -- k first: h is nil for katakana-only
            local st = ns.KanaStatus(ch)
            if st == "wrong" then worst = "wrong"
            elseif st == "right" and worst ~= "wrong" then worst = "right"
            elseif st == "learned" and not worst then worst = "learned" end
          end
        end
        if worst == "wrong" then c.bg:SetColorTexture(1, 0.25, 0.25, 0.22)
        elseif worst == "right" then c.bg:SetColorTexture(0.3, 1, 0.3, 0.14)
        elseif worst == "learned" then c.bg:SetColorTexture(1, 0.82, 0, 0.16)
        else c.bg:SetColorTexture(1, 1, 1, 0.04) end
        c.hira:SetText(data.h and ("|cffffffff" .. data.h .. "|r") or "")
        c.kata:SetText("|cffffd100" .. data.k .. "|r")
        c.roma:SetText("|cff80c0ff" .. data.r .. "|r")
        c:Show()
        first = first or data
      end
    end
  end
  local keep = false
  for _, row in ipairs(sec.cache) do
    for _, data in ipairs(row) do if data and data == kanaInfo then keep = true end end
  end
  if keep then ShowKanaInfo(kanaInfo) elseif first then ShowKanaInfo(first) end
end

-- The kana on the current page, as the kana quiz setting picks them (hiragana, katakana or both).
kanaPractise:SetScript("OnClick", function()
  local sec = SECTIONS[kanaSection]
  sec.cache = sec.cache or sec.rows()
  local set = ns.DB.quiz.kanaSet
  local list = {}
  for _, row in ipairs(sec.cache) do
    for _, data in ipairs(row) do
      if data and Quizzable(data) then
        if data.h and set ~= "kata" then list[#list + 1] = data.h end
        if data.k and (set ~= "hira" or not data.h) then list[#list + 1] = data.k end
      end
    end
  end
  local setName = ({ hira = "hiragana", kata = "katakana", both = "kana" })[set] or "kana"
  ns.StartKanaPractice(sec.name .. " " .. setName, list)
end)

-- Writing practice for the page, starting with the kana shown in the info area.
kanaWrite:SetScript("OnClick", function()
  local sec = SECTIONS[kanaSection]
  sec.cache = sec.cache or sec.rows()
  local set = ns.DB.quiz.kanaSet
  local list = {}
  for _, row in ipairs(sec.cache) do
    for _, data in ipairs(row) do
      if data then
        if data.h and set ~= "kata" then list[#list + 1] = data.h end
        if data.k and (set ~= "hira" or not data.h) then list[#list + 1] = data.k end
      end
    end
  end
  local first = kanaInfo and ((set == "kata" or not kanaInfo.h) and kanaInfo.k or kanaInfo.h)
  ns.StartWriting(sec.name, list, first)
end)

for i, sec in ipairs(SECTIONS) do
  local b = Button(kanaPage, sec.name, 110)
  b:SetPoint("TOPLEFT", 4 + (i - 1) * 116, 0)
  b:SetScript("OnClick", function() kanaSection = i; DrawKana() end)
  sectionBtns[i] = b
end
kanaPage.refresh = DrawKana

---------------------------------------------------------------------------
-- Shared word helpers
---------------------------------------------------------------------------
local FILTERS = { "all", "right", "wrong", "new" }
local FILTER_NAME = { all = "All", right = "Right", wrong = "Wrong", new = "Undiscovered" }

local function Passes(filter, status)
  if filter == "all" then return true end
  if filter == "right" then return status == "right" or status == "learned" end
  return filter == status
end

local function JPWord(k)
  local e = ns.dict[k]
  return (e.kanji and ("|cffffffff" .. e.kanji .. "|r  ") or "") .. "|cffffd100" .. e.kana .. "|r"
end

local function Stats(k) return ns.DB.quiz.words[k] end

local function Ago(t)
  if not t or not time then return nil end
  local d = time() - t
  if d < 3600 then return "just now" end
  if d < 86400 then return math.floor(d / 3600) .. " h ago" end
  local days = math.floor(d / 86400)
  return days .. (days == 1 and " day ago" or " days ago")
end

---------------------------------------------------------------------------
-- Kanji
---------------------------------------------------------------------------
local kanjiPage = NewPage("kanji", "Kanji")
local kanjiList, kanjiIdx      -- built the first time the tab opens
local kanjiFilter, kanjiOffset, kanjiSel = "all", 0, nil
local COLS, ROWS, KSIZE = 10, 11, 36
local kanjiCells, kanjiFilterBtns = {}, {}
local shownKanji = {}

local function BuildKanji()
  kanjiIdx, kanjiList = {}, {}
  local keys = {}
  for k in pairs(ns.dict) do keys[#keys + 1] = k end
  table.sort(keys)
  for _, k in ipairs(keys) do
    local e = ns.dict[k]
    if e.kanji then
      for _, ch in ipairs(ns.KanjiIn(e.kanji)) do
        local x = kanjiIdx[ch]
        if not x then
          x = { ch = ch, words = {}, meanings = {} }
          kanjiIdx[ch] = x
          kanjiList[#kanjiList + 1] = x
        end
        x.words[#x.words + 1] = k
        if e.kanji == ch then x.meanings[#x.meanings + 1] = ns.Label(k) end
      end
    end
  end
  table.sort(kanjiList, function(a, b)
    if #a.words ~= #b.words then return #a.words > #b.words end
    return a.ch < b.ch
  end)
end

local function KanjiStatus(x)
  local n = { new = 0, right = 0, learned = 0, wrong = 0 }
  for _, k in ipairs(x.words) do
    local s = ns.WordStatus(k)
    n[s] = n[s] + 1
  end
  local st
  if n.wrong > 0 then st = "wrong"
  elseif n.new == #x.words then st = "new"
  elseif n.learned == #x.words then st = "learned"
  else st = "right" end
  return st, n
end

-- Detail area on the right
local DX = 384
local kdBig = Text(kanjiPage, 56)
kdBig:SetPoint("TOPLEFT", DX, -30)
local kdStatus = Text(kanjiPage, 12)
kdStatus:SetPoint("TOPLEFT", DX + 76, -36)
kdStatus:SetWidth(168)
kdStatus:SetJustifyV("TOP")
local kdRead = Text(kanjiPage, 13)
kdRead:SetPoint("TOPLEFT", DX, -100)
kdRead:SetWidth(244)
kdRead:SetJustifyV("TOP")
local kdMean = Text(kanjiPage, 13)
kdMean:SetPoint("TOPLEFT", DX, -150)
kdMean:SetWidth(244)
kdMean:SetJustifyV("TOP")
local kdHead = Text(kanjiPage, 12)
kdHead:SetPoint("TOPLEFT", DX, -192)
local kdLines = {}
for i = 1, 11 do
  local fs = Text(kanjiPage, 13)
  fs:SetPoint("TOPLEFT", DX, -192 - i * 19)
  fs:SetWidth(244)
  fs:SetWordWrap(false)
  kdLines[i] = fs
end
local kdSay = Button(kanjiPage, "Say", 60)
kdSay:SetPoint("BOTTOMLEFT", DX, 4)
local kdPractise = Button(kanjiPage, "Practise words", 112)
kdPractise:SetPoint("LEFT", kdSay, "RIGHT", 6, 0)
local kdWrite = Button(kanjiPage, "Write", 60)
kdWrite:SetPoint("LEFT", kdPractise, "RIGHT", 6, 0)

local function ShowKanjiDetail(x)
  kanjiSel = x
  if not x then
    kdBig:SetText(""); kdStatus:SetText(""); kdRead:SetText(""); kdMean:SetText(""); kdHead:SetText("")
    for _, fs in ipairs(kdLines) do fs:SetText("") end
    return
  end
  local st, n = KanjiStatus(x)
  kdBig:SetText(Colored(st, x.ch))
  kdStatus:SetText(("%s\n\n|cff66ff66%d right|r  |cffff5959%d wrong|r\n|cff8c8c8c%d not quizzed|r"):format(
    Colored(st, STATUS_NAME[st]), n.right + n.learned, n.wrong, n.new))
  local reads = {}
  for i, r in ipairs(ns.KanjiReadings(x.ch)) do
    if i > 6 then break end
    reads[#reads + 1] = "|cffffd100" .. r .. "|r |cff80c0ff[" .. ns.ToRomaji(r) .. "]|r"
  end
  kdRead:SetText("|cff999999Readings:|r " .. (#reads > 0 and table.concat(reads, ", ") or "?"))
  kdMean:SetText("|cff999999Meaning:|r " .. (#x.meanings > 0 and table.concat(x.meanings, ", ")
    or "|cffbbbbbbsee the words below|r"))
  kdHead:SetText(("|cff999999Words with %s (%d):|r"):format(x.ch, #x.words))
  for i, fs in ipairs(kdLines) do
    local k = x.words[i]
    if i == #kdLines and #x.words > #kdLines then
      fs:SetText(("|cff999999+ %d more (see My words)|r"):format(#x.words - #kdLines + 1))
    elseif k then
      local s = ns.WordStatus(k)
      fs:SetText(Colored(s, DOT) .. " " .. JPWord(k) .. "  |cffbbbbbb= " .. ns.Label(k) .. "|r")
    else
      fs:SetText("")
    end
  end
end

kdSay:SetScript("OnClick", function()
  if kanjiSel then ns.SpeakKana(table.concat(ns.KanjiReadings(kanjiSel.ch), "、")) end
end)
kdPractise:SetScript("OnClick", function()
  if kanjiSel then ns.StartPractice(kanjiSel.ch .. " words", { unpack(kanjiSel.words) }) end
end)
kdWrite:SetScript("OnClick", function()
  if kanjiSel then ns.WriteChar(kanjiSel.ch) end
end)

local kPageText = Text(kanjiPage, 12, "CENTER")
local kPrev = Button(kanjiPage, "<", 30)
kPrev:SetPoint("TOPLEFT", 4, -36 - ROWS * KSIZE - 8)
local kNext = Button(kanjiPage, ">", 30)
kNext:SetPoint("TOPLEFT", 4 + COLS * KSIZE - 30, -36 - ROWS * KSIZE - 8)
kPageText:SetPoint("LEFT", kPrev, "RIGHT", 0, 0)
kPageText:SetPoint("RIGHT", kNext, "LEFT", 0, 0)

local function DrawKanji()
  if not kanjiList then BuildKanji() end
  local counts = { all = 0, right = 0, wrong = 0, new = 0 }
  shownKanji = {}
  for _, x in ipairs(kanjiList) do
    x.status = KanjiStatus(x)
    counts.all = counts.all + 1
    for _, f in ipairs({ "right", "wrong", "new" }) do
      if Passes(f, x.status) then counts[f] = counts[f] + 1 end
    end
    if Passes(kanjiFilter, x.status) then shownKanji[#shownKanji + 1] = x end
  end
  for _, f in ipairs(FILTERS) do
    local b = kanjiFilterBtns[f]
    b:SetText(FILTER_NAME[f] .. " (" .. counts[f] .. ")")
    if f == kanjiFilter then b:LockHighlight() else b:UnlockHighlight() end
  end
  local per = COLS * ROWS
  local pagesN = math.max(1, math.ceil(#shownKanji / per))
  kanjiOffset = math.max(0, math.min(kanjiOffset, (pagesN - 1) * per))
  kPageText:SetText(("Page %d / %d"):format(kanjiOffset / per + 1, pagesN))
  if not kanjiSel or not Passes(kanjiFilter, kanjiSel.status) then kanjiSel = shownKanji[kanjiOffset + 1] end
  for i = 1, per do
    local c = kanjiCells[i]
    local x = shownKanji[kanjiOffset + i]
    if x then
      c.x = x
      c.label:SetText(Colored(x.status, x.ch))
      if x == kanjiSel then c.bg:SetColorTexture(1, 1, 1, 0.25) else c.bg:SetColorTexture(1, 1, 1, 0.04) end
      c:Show()
    else
      c:Hide()
    end
  end
  ShowKanjiDetail(kanjiSel)
end

for i = 1, COLS * ROWS do
  local c = Cell(kanjiPage)
  c:SetSize(KSIZE - 2, KSIZE - 2)
  local col, row = (i - 1) % COLS, math.floor((i - 1) / COLS)
  c:SetPoint("TOPLEFT", 4 + col * KSIZE, -36 - row * KSIZE)
  c.label = Text(c, 22, "CENTER")
  c.label:SetPoint("CENTER")
  c:SetScript("OnClick", function(self)
    kanjiSel = self.x
    DrawKanji()
  end)
  kanjiCells[i] = c
end

for i, f in ipairs(FILTERS) do
  local b = Button(kanjiPage, "", 118)
  b:SetPoint("TOPLEFT", 4 + (i - 1) * 122, 0)
  b:SetScript("OnClick", function() kanjiFilter = f; kanjiOffset = 0; DrawKanji() end)
  kanjiFilterBtns[f] = b
end

local function KanjiPageBy(d)
  kanjiOffset = kanjiOffset + d * COLS * ROWS
  DrawKanji()
end
kPrev:SetScript("OnClick", function() KanjiPageBy(-1) end)
kNext:SetScript("OnClick", function() KanjiPageBy(1) end)
kanjiPage:EnableMouseWheel(true)
kanjiPage:SetScript("OnMouseWheel", function(_, delta) KanjiPageBy(delta > 0 and -1 or 1) end)
kanjiPage.refresh = DrawKanji

---------------------------------------------------------------------------
-- My words
---------------------------------------------------------------------------
local wordsPage = NewPage("words", "My words")
local wordFilter, wordSort, search = "all", "az", ""
local wordList = {}
local offset = 0
local LROWS, ROWH = 15, 22
local wordFilterBtns, rows = {}, {}
local SORTS = { "az", "recent", "wrong" }
local SORT_NAME = { az = "Sort: A-Z", recent = "Sort: Recent", wrong = "Sort: Most wrong" }

for i, f in ipairs(FILTERS) do
  local b = Button(wordsPage, "", 118)
  b:SetPoint("TOPLEFT", 4 + (i - 1) * 122, 0)
  b:SetScript("OnClick", function() wordFilter = f; offset = 0; wordsPage.refresh() end)
  wordFilterBtns[f] = b
end
local practise = Button(wordsPage, "Practise list", 120)
practise:SetPoint("TOPRIGHT", -2, 0)

local searchLabel = Text(wordsPage, 12)
searchLabel:SetPoint("TOPLEFT", 6, -34)
searchLabel:SetText("|cff999999Search:|r")
local box = CreateFrame("EditBox", nil, wordsPage, "InputBoxTemplate")
box:SetSize(150, 20)
box:SetPoint("LEFT", searchLabel, "RIGHT", 10, 0)
box:SetAutoFocus(false)
box:SetScript("OnEscapePressed", box.ClearFocus)
box:SetScript("OnEnterPressed", box.ClearFocus)
box:SetScript("OnTextChanged", function(self)
  search = (self:GetText() or ""):lower()
  offset = 0
  wordsPage.refresh()
end)
local sortBtn = Button(wordsPage, "", 130)
sortBtn:SetPoint("LEFT", box, "RIGHT", 12, 0)
local summary = Text(wordsPage, 12, "RIGHT")
summary:SetPoint("TOPRIGHT", -4, -36)

local heads = {
  { "Japanese", 20 }, { "Romaji", 232 }, { "English", 372 }, { "Right / wrong", 528 },
}
for _, h in ipairs(heads) do
  local fs = Text(wordsPage, 11)
  fs:SetPoint("TOPLEFT", h[2], -62)
  fs:SetText("|cff999999" .. h[1] .. "|r")
end

local detail = Text(wordsPage, 13)
detail:SetPoint("TOPLEFT", 4, -84 - LROWS * ROWH - 8)
detail:SetWidth(600)
detail:SetJustifyV("TOP")

local function ShowWordDetail(k)
  if not k then detail:SetText(""); return end
  local s = Stats(k)
  local st = ns.WordStatus(k)
  local line1 = JPWord(k) .. "  |cff80c0ff[" .. ns.Romaji(k) .. "]|r  = " .. ns.Label(k)
  local b = ns.BreakdownText and ns.BreakdownText(k)
  if b then line1 = line1 .. "     " .. b end
  local line2 = Colored(st, STATUS_NAME[st])
  if s then
    line2 = line2 .. ("   |cff66ff66%d right|r  |cffff5959%d wrong|r"):format(s.r or 0, s.w or 0)
    local ago = Ago(s.t)
    if ago then line2 = line2 .. "   |cff999999last quizzed " .. ago .. "|r" end
  end
  detail:SetText(line1 .. "\n" .. line2 .. "   |cff999999(click a word to hear it)|r")
end

local slider = CreateFrame("Slider", nil, wordsPage, BackdropTemplateMixin and "BackdropTemplate" or nil)
slider:SetOrientation("VERTICAL")
slider:SetSize(16, LROWS * ROWH)
slider:SetPoint("TOPRIGHT", -2, -82)
if slider.SetBackdrop then
  slider:SetBackdrop({
    bgFile = "Interface\\Buttons\\UI-SliderBar-Background",
    edgeFile = "Interface\\Buttons\\UI-SliderBar-Border",
    tile = true, tileSize = 8, edgeSize = 8,
    insets = { left = 3, right = 3, top = 6, bottom = 6 },
  })
end
slider:SetThumbTexture("Interface\\Buttons\\UI-ScrollBar-Knob")
local thumb = slider:GetThumbTexture()
if thumb then thumb:SetSize(18, 24) end
slider:SetValueStep(1)
if slider.SetObeyStepOnDrag then slider:SetObeyStepOnDrag(true) end
slider:SetMinMaxValues(0, 0)
slider:SetValue(0)

local function DrawRows()
  for i, row in ipairs(rows) do
    local k = wordList[offset + i]
    row.key = k
    if k then
      local s = Stats(k)
      local st = ns.WordStatus(k)
      row.dot:SetText(Colored(st, st == "learned" and "★" or DOT))
      row.jp:SetText(JPWord(k))
      row.roma:SetText("|cff80c0ff" .. ns.Romaji(k) .. "|r")
      row.en:SetText(ns.Label(k))
      row.score:SetText(s and ("|cff66ff66%d|r / |cffff5959%d|r"):format(s.r or 0, s.w or 0) or "|cff8c8c8c-|r")
      row:Show()
    else
      row:Hide()
    end
  end
end

slider:SetScript("OnValueChanged", function(_, v)
  v = math.floor(v + 0.5)
  if v ~= offset then
    offset = v
    DrawRows()
  end
end)

for i = 1, LROWS do
  local row = Cell(wordsPage)
  row:SetSize(588, ROWH - 2)
  row:SetPoint("TOPLEFT", 4, -80 - (i - 1) * ROWH)
  if i % 2 == 0 then row.bg:SetColorTexture(1, 1, 1, 0.07) else row.bg:SetColorTexture(1, 1, 1, 0.02) end
  row.dot = Text(row, 12)
  row.dot:SetPoint("LEFT", 2, 0)
  row.jp = Text(row, 15)
  row.jp:SetPoint("LEFT", 16, 0)
  row.jp:SetWidth(208)
  row.roma = Text(row, 13)
  row.roma:SetPoint("LEFT", 228, 0)
  row.roma:SetWidth(136)
  row.en = Text(row, 13)
  row.en:SetPoint("LEFT", 368, 0)
  row.en:SetWidth(150)
  row.score = Text(row, 13)
  row.score:SetPoint("LEFT", 524, 0)
  for _, fs in ipairs({ row.jp, row.roma, row.en }) do fs:SetWordWrap(false) end
  row:SetScript("OnEnter", function(self) ShowWordDetail(self.key) end)
  row:SetScript("OnClick", function(self)
    ShowWordDetail(self.key)
    if self.key then ns.Speak(self.key) end
  end)
  rows[i] = row
end

wordsPage:EnableMouseWheel(true)
wordsPage:SetScript("OnMouseWheel", function(_, delta)
  slider:SetValue(math.max(0, offset - delta * 3))
end)

local function Matches(k)
  if search == "" then return true end
  local e = ns.dict[k]
  return ns.Label(k):lower():find(search, 1, true) or ns.Romaji(k):find(search, 1, true)
    or e.kana:find(search, 1, true) or (e.kanji and e.kanji:find(search, 1, true))
end

local function SortWords(list)
  local label = {}
  for _, k in ipairs(list) do label[k] = ns.Label(k):lower() end
  local function az(a, b)
    if label[a] ~= label[b] then return label[a] < label[b] end
    return a < b
  end
  if wordSort == "recent" then
    table.sort(list, function(a, b)
      local ta, tb = (Stats(a) or {}).t or 0, (Stats(b) or {}).t or 0
      if ta ~= tb then return ta > tb end
      return az(a, b)
    end)
  elseif wordSort == "wrong" then
    table.sort(list, function(a, b)
      local sa, sb = Stats(a) or {}, Stats(b) or {}
      if (sa.w or 0) ~= (sb.w or 0) then return (sa.w or 0) > (sb.w or 0) end
      if (sa.r or 0) ~= (sb.r or 0) then return (sa.r or 0) < (sb.r or 0) end
      return az(a, b)
    end)
  else
    table.sort(list, az)
  end
end

function wordsPage.refresh()
  local counts = { all = 0, right = 0, wrong = 0, new = 0, learned = 0 }
  wordList = {}
  for k in pairs(ns.dict) do
    local st = ns.WordStatus(k)
    counts.all = counts.all + 1
    if st == "learned" then counts.learned = counts.learned + 1 end
    for _, f in ipairs({ "right", "wrong", "new" }) do
      if Passes(f, st) then counts[f] = counts[f] + 1 end
    end
    if Passes(wordFilter, st) and Matches(k) then wordList[#wordList + 1] = k end
  end
  SortWords(wordList)
  for _, f in ipairs(FILTERS) do
    local b = wordFilterBtns[f]
    b:SetText(FILTER_NAME[f] .. " (" .. counts[f] .. ")")
    if f == wordFilter then b:LockHighlight() else b:UnlockHighlight() end
  end
  sortBtn:SetText(SORT_NAME[wordSort])
  summary:SetText(("|cffffd100★ %d learned|r   |cff999999showing %d|r"):format(counts.learned, #wordList))
  local maxOff = math.max(0, #wordList - LROWS)
  offset = math.min(offset, maxOff)
  slider:SetMinMaxValues(0, maxOff)
  slider:SetValue(offset)
  DrawRows()
  ShowWordDetail(wordList[offset + 1])
end

sortBtn:SetScript("OnClick", function()
  for i, s in ipairs(SORTS) do
    if s == wordSort then wordSort = SORTS[i % #SORTS + 1]; break end
  end
  offset = 0
  wordsPage.refresh()
end)

practise:SetScript("OnClick", function()
  if #wordList == 0 then return end
  local name = FILTER_NAME[wordFilter] .. " words"
  if search ~= "" then name = name .. " \"" .. search .. "\"" end
  local keys = {}
  for i, k in ipairs(wordList) do keys[i] = k end
  ns.StartPractice(name, keys)
end)

---------------------------------------------------------------------------
-- Public
---------------------------------------------------------------------------
function ns.ShowLexiconTab(name)
  if not pages[name] then name = "kana" end
  current = name
  if ns.DB then ns.DB.lexTab = name end
  for n, p in pairs(pages) do
    if n == name then p:Show() else p:Hide() end
    if n == name then tabs[n]:LockHighlight() else tabs[n]:UnlockHighlight() end
  end
  pages[name].refresh()
end

function ns.RefreshLexicon()
  if L:IsShown() and current and pages[current].refresh then pages[current].refresh() end
end

function ns.ToggleLexicon(tab)
  if not ns.DB then return end
  if L:IsShown() and (not tab or tab == current) then
    L:Hide()
    return
  end
  L:Show()
  ApplyFonts()
  ns.ShowLexiconTab(tab or ns.DB.lexTab or "kana")
end

AzerothNihongo_ToggleLexicon = function() ns.ToggleLexicon() end
