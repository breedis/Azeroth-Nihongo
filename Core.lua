local ADDON, ns = ...

BINDING_HEADER_AZEROTHNIHONGO = "Azeroth Nihongo"
BINDING_NAME_AZEROTHNIHONGO_TOGGLE = "Toggle Japanese words on/off"
BINDING_NAME_AZEROTHNIHONGO_QUIZ = "Open/close the quiz"
BINDING_NAME_AZEROTHNIHONGO_SPEAK = "Say the hovered word"
BINDING_NAME_AZEROTHNIHONGO_LEXICON = "Open/close the lexicon"

local PREFIX = "|cffff7f7fAzeroth Nihongo|r: "
local function Print(msg) DEFAULT_CHAT_FRAME:AddMessage(PREFIX .. msg) end
ns.Print = Print

local DEFAULTS = {
  enabled = true,
  showKanji = true,
  showKana = true,
  showRomaji = true,
  showEnglish = true,
  showBreakdown = true,  -- which kana each kanji reads, e.g. 宿(やど) 屋(や)
  scanAllLines = false,  -- false = only the name (first line) of the tooltip
  requireShift = false,  -- only show while Shift is held
  below = false,         -- popup below the tooltip instead of above
  showButton = true,
  speakOnHover = false,  -- say each new hovered word out loud
  voiceIndex = 1,
  collectMissing = true, -- note words in tooltip names that have no translation
  missing = {},          -- per word: { n = times seen, ex = example name, k = kind, t = time, new = true }
  write = {},            -- writing practice per character: { r = clean, w = with misses, last, t }
  writeMode = "trace",   -- "trace", "hint" or "memory"
  writeSet = "hira",     -- what "Next" picks from: "hira", "kata" or "kanji"
  fontSize = 16,
  maxWords = 8,
  fontIndex = 1,
  button = { point = "CENTER", x = 0, y = 250 },
  quiz = {
    mode = "mixed",        -- "words", "items" or "mixed"
    direction = "mixed",   -- "jp" (JP -> EN), "en" (EN -> JP) or "mixed"
    labels = "adaptive",   -- "kana", "both" or "adaptive" (kanji + kana until learned)
    speak = true,          -- say the word after answering
    autoNext = false,      -- go on by itself after a correct answer
    right = 0, total = 0, streak = 0, best = 0,
    words = {},            -- per word: { r = right, w = wrong, last = right?, t = time }
    kana = {},             -- per kana character, same as words
    kanaSet = "hira",      -- kana quiz: "hira", "kata" or "both"
    kanaDakuten = true,    -- kana quiz: include が, ぱ ...
    kanaCombos = false,    -- kana quiz: include きゃ, しゃ ...
  },
  pop = {
    enabled = true,        -- timed pop quizzes
    interval = 30,         -- minutes per period
    count = 2,             -- pop quizzes per period
    random = true,         -- random times in the period (false = evenly spaced)
    questions = 3,         -- questions per pop quiz
    onQuest = true,        -- may pop after turning in a quest
    questChance = 50,      -- percent
    onLevel = true,        -- pop after levelling up
    noInstance = true,     -- no pop quiz in dungeons, raids, battlegrounds or arenas
    kind = "quiz",         -- what a pop quiz asks: "quiz" (same as the quiz window), "kana" or "both"
    sound = true,
  },
}

local FONTS = {
  "Interface\\AddOns\\" .. ADDON .. "\\Fonts\\japanese.ttf",          -- IPA UI Gothic
  "Interface\\AddOns\\WoWForeverJapanese\\Fonts\\ipagui.ttf",          -- same font, other addon
  -- Fallbacks (Chinese), missing some Japanese characters. The Korean (2002.ttf) and
  -- Taiwanese (bLEI00D.ttf) game fonts have no kana at all, so they are not listed.
  "Fonts\\ARKai_T.ttf",
  "Fonts\\ARHei.ttf",
}
ns.FONTS = FONTS

local DB
local settingsVersion = 0
local lastKey
local testUntil = 0
local errorShown = false
ns.currentKeys = {}

---------------------------------------------------------------------------
-- Popup
---------------------------------------------------------------------------
local popup = CreateFrame("Frame", "AzerothNihongoPopup", UIParent,
  BackdropTemplateMixin and "BackdropTemplate" or nil)
popup:SetFrameStrata("TOOLTIP")
popup:SetClampedToScreen(true)
popup:Hide()
if popup.SetBackdrop then
  popup:SetBackdrop({
    bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    tile = true, tileSize = 16, edgeSize = 16,
    insets = { left = 4, right = 4, top = 4, bottom = 4 },
  })
  popup:SetBackdropColor(0.05, 0.05, 0.1, 0.92)
  popup:SetBackdropBorderColor(0.9, 0.45, 0.45, 1)
end

local text = popup:CreateFontString(nil, "OVERLAY")
text:SetFontObject(GameFontHighlight)
text:SetJustifyH("LEFT")
text:SetPoint("TOPLEFT", 10, -9)
if text.SetSpacing then text:SetSpacing(3) end

local function TrySetFont(path, size)
  local ok = text:SetFont(path, size, "")
  if ok == nil then -- older clients return nothing
    local cur = text:GetFont()
    ok = cur ~= nil and (cur:lower():gsub("/", "\\")) == path:lower()
  end
  return ok
end

function ns.ApplyFont()
  local start = DB.fontIndex or 1
  for n = 0, #FONTS - 1 do
    local idx = ((start - 1 + n) % #FONTS) + 1
    if TrySetFont(FONTS[idx], DB.fontSize) then
      ns.fontIdx = idx
      ns.fontPath = FONTS[idx]
      return
    end
  end
  text:SetFontObject(GameFontHighlight)
  ns.fontIdx, ns.fontPath = nil, nil
end

-- Draws some Japanese text with the font at login, out of sight, so the font file is
-- loaded before the first quiz or popup needs it.
local preload
function ns.PreloadFont()
  if not ns.fontPath then return end
  if not preload then
    preload = CreateFrame("Frame", nil, UIParent)
    preload:SetSize(1, 1)
    preload:SetPoint("TOPLEFT", UIParent, "BOTTOMRIGHT", 100, -100)
    preload:SetAlpha(0.01)
    preload.texts = {}
  end
  for i, size in ipairs({ 12, 13, 15, 16, 18, 20, 24, 40, DB.fontSize }) do
    local fs = preload.texts[i] or preload:CreateFontString(nil, "OVERLAY")
    preload.texts[i] = fs
    fs:SetFont(ns.fontPath, size, "")
    fs:SetPoint("TOPLEFT", 0, -i * 30)
    fs:SetText("あいうえお アイウエオ ガギグ 日本語 漢字 ー")
  end
  preload:Show()
  if C_Timer then C_Timer.After(5, function() preload:Hide() end) end
end

function ns.CycleFont()
  DB.fontIndex = ((ns.fontIdx or 1) % #FONTS) + 1
  ns.ApplyFont()
  ns.Refresh()
  Print("Font: " .. (ns.fontPath or "default"))
end

---------------------------------------------------------------------------
-- Speech (Windows text-to-speech through WoW)
---------------------------------------------------------------------------
local JP_VOICE_NAMES = { "japan", "haruka", "ayumi", "ichiro", "sayaka", "nanami", "keita", "ja%-jp" }

function ns.JapaneseVoices()
  local list = {}
  if not (C_VoiceChat and C_VoiceChat.GetTtsVoices) then return list end
  local ok, voices = pcall(C_VoiceChat.GetTtsVoices)
  if not ok or type(voices) ~= "table" then return list end
  for _, v in ipairs(voices) do
    local n = (v.name or ""):lower()
    for _, pat in ipairs(JP_VOICE_NAMES) do
      if n:find(pat) then list[#list + 1] = v; break end
    end
  end
  return list
end

function ns.CurrentVoice()
  local voices = ns.JapaneseVoices()
  if #voices == 0 then return nil end
  return voices[((DB.voiceIndex or 1) - 1) % #voices + 1], #voices
end

function ns.CycleVoice()
  local voices = ns.JapaneseVoices()
  if #voices == 0 then
    Print("No Japanese text-to-speech voice found. In Windows: Settings > Time & language > "
      .. "Speech > Add voices > Japanese, then restart WoW.")
    return
  end
  DB.voiceIndex = (DB.voiceIndex or 1) % #voices + 1
  local v = ns.CurrentVoice()
  Print("Voice: " .. (v.name or "?"))
  ns.Speak("dragon")
  if ns.RefreshOptions then ns.RefreshOptions() end
end

local voiceWarned = false
function ns.Speak(key)
  local e = ns.dict[key]
  if not e then return end
  ns.SpeakKana(e.kana)  -- kana, so the voice always uses the right reading
end

-- Speech state. Blizzard's TextToSpeech_Speak queues lines and sends the next one only
-- when it hears that the last one FINISHED. Stopping the voice means that event never
-- comes, and the queue then waits forever (silent until /reload). So:
--  * never stop the voice; a click while a word is being said waits for it to finish;
--  * quick clicks only say the last word;
--  * if a line never starts, switch to calling the speech engine directly.
local tts = {
  playing = false,  -- between PLAYBACK_STARTED and FINISHED/FAILED
  playStart = 0,
  asked = nil,      -- GetTime() of the last request that has not started yet
  pending = nil,    -- the word to say next
  timer = false,
  direct = false,   -- skip Blizzard's queue (after it got stuck)
}
local STALL = 3     -- seconds without a start event = the queue is stuck
local MAX_LINE = 6  -- a word never takes longer than this; after that, stop waiting

-- Debug lines go to a chat tab called "JP" when there is one, else the main chat.
local function DebugFrame()
  if GetChatWindowInfo then
    for i = 1, (NUM_CHAT_WINDOWS or 10) do
      local name = GetChatWindowInfo(i)
      local frame = _G["ChatFrame" .. i]
      if name and name:upper() == "JP" and frame then return frame end
    end
  end
  return DEFAULT_CHAT_FRAME
end

local function TTSDebug(...)
  if not (DB and DB.ttsDebug) then return end
  local parts = {}
  for i = 1, select("#", ...) do parts[#parts + 1] = tostring((select(i, ...))) end
  local t = date and date("%H:%M:%S ") or ""
  DebugFrame():AddMessage("|cff999999" .. t .. "TTS: " .. table.concat(parts, " ") .. "|r")
end

local function SpeakDirect(voice, say)
  local rate = (C_TTSSettings and C_TTSSettings.GetSpeechRate and C_TTSSettings.GetSpeechRate()) or 0
  local volume = (C_TTSSettings and C_TTSSettings.GetSpeechVolume and C_TTSSettings.GetSpeechVolume()) or 100
  local dest = Enum and Enum.VoiceTtsDestination
  if dest and dest.LocalPlayback
    and pcall(C_VoiceChat.SpeakText, voice.voiceID, say, dest.LocalPlayback, rate, volume) then
    TTSDebug("speak (SpeakText, local playback)", say)
    return true
  end
  if pcall(C_VoiceChat.SpeakText, voice.voiceID, say, rate, volume) then
    TTSDebug("speak (SpeakText)", say)
    return true
  end
end

local function SpeakNow(say)
  local voice = ns.CurrentVoice()
  if not voice then
    if not voiceWarned then
      voiceWarned = true
      Print("No Japanese text-to-speech voice found. In Windows: Settings > Time & language > "
        .. "Speech > Add voices > Japanese, then restart WoW.")
    end
    return
  end
  tts.asked = GetTime()
  if tts.direct and SpeakDirect(voice, say) then return end
  -- Blizzard's own wrapper knows this client's SpeakText arguments.
  if TextToSpeech_Speak and pcall(TextToSpeech_Speak, say, voice) then
    TTSDebug("speak (TextToSpeech_Speak)", say, voice.name)
    return
  end
  if not SpeakDirect(voice, say) then TTSDebug("speak FAILED: no speech function worked", say) end
end

-- Is a word being said (or asked for and about to start)?
local function Busy()
  local now = GetTime()
  if tts.playing and now - tts.playStart < MAX_LINE then return true end
  if tts.asked and now - tts.asked < STALL then return true end
  return false
end

local function Flush()
  tts.timer = false
  if not tts.pending or Busy() then return end -- the FINISHED event flushes it later
  local say = tts.pending
  tts.pending = nil
  SpeakNow(say)
end

local function FlushSoon(delay)
  if tts.timer then return end
  if not C_Timer then Flush(); return end
  tts.timer = true
  C_Timer.After(delay, Flush)
end

-- Says any Japanese text (kana is safest: the voice cannot pick a wrong reading).
function ns.SpeakKana(say)
  if not say or say == "" or not DB or not C_VoiceChat then return end
  if tts.asked and GetTime() - tts.asked >= STALL then
    -- The last line was asked for but never started: Blizzard's queue is stuck.
    TTSDebug("last line never started - talking to the speech engine directly from now on")
    tts.direct, tts.asked = true, nil
  end
  tts.pending = say
  if Busy() then
    TTSDebug("busy - will say", say, "when the current word is done")
    return
  end
  FlushSoon(0.05)
end

local ttsEvents = CreateFrame("Frame")
for _, e in ipairs({ "VOICE_CHAT_TTS_PLAYBACK_STARTED", "VOICE_CHAT_TTS_PLAYBACK_FINISHED",
  "VOICE_CHAT_TTS_PLAYBACK_FAILED", "VOICE_CHAT_TTS_SPEAK_TEXT_UPDATE" }) do
  pcall(ttsEvents.RegisterEvent, ttsEvents, e) -- older clients may not have all of them
end
ttsEvents:SetScript("OnEvent", function(_, event, ...)
  if event == "VOICE_CHAT_TTS_PLAYBACK_STARTED" then
    tts.playing, tts.playStart, tts.asked = true, GetTime(), nil
  elseif event == "VOICE_CHAT_TTS_PLAYBACK_FINISHED" or event == "VOICE_CHAT_TTS_PLAYBACK_FAILED" then
    tts.playing, tts.asked = false, nil
    if tts.pending then FlushSoon(0.15) end
  end
  TTSDebug((event:gsub("VOICE_CHAT_TTS_", "")), ...)
end)

function ns.SpeakHovered()
  if ns.currentKeys[1] then ns.Speak(ns.currentKeys[1]) end
end
AzerothNihongo_SpeakHovered = ns.SpeakHovered

---------------------------------------------------------------------------
-- Word lookup
---------------------------------------------------------------------------
local IRREGULAR = {
  men = "man", women = "woman", children = "child", feet = "foot",
  teeth = "tooth", mice = "mouse", people = "person",
}

local function LookupWord(w)
  local d = ns.dict
  if d[w] then return w end
  local ir = IRREGULAR[w]
  if ir and d[ir] then return ir end
  local cands = {}
  if w:sub(-3) == "ves" then
    cands[#cands + 1] = w:sub(1, -4) .. "f"   -- wolves -> wolf
    cands[#cands + 1] = w:sub(1, -4) .. "fe"  -- knives -> knife
  end
  if w:sub(-3) == "ies" then cands[#cands + 1] = w:sub(1, -4) .. "y" end
  if w:sub(-2) == "es" then cands[#cands + 1] = w:sub(1, -3) end
  if w:sub(-1) == "s" then cands[#cands + 1] = w:sub(1, -2) end
  for _, c in ipairs(cands) do
    if d[c] then return c end
  end
end
ns.LookupWord = LookupWord

-- Compound words: "silverleaf" -> silver + leaf, "runecloth" -> rune + cloth.
-- Both parts must be at least 4 letters to avoid false hits.
local function SplitCompound(w)
  if #w < 8 then return end
  for i = #w - 4, 4, -1 do
    local left = LookupWord(w:sub(1, i))
    if left then
      local right = LookupWord(w:sub(i + 1))
      if right then return left, right end
    end
  end
end

local function CleanText(s)
  s = s:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
  s = s:gsub("|T.-|t", ""):gsub("|A.-|a", ""):gsub("|H.-|h", ""):gsub("|h", "")
  return s
end

-- True if the dictionary knows the word, alone or as a compound.
function ns.KnowsWord(w)
  return LookupWord(w) ~= nil or SplitCompound(w) ~= nil
end

-- Finds dictionary words in a text. Returns { {key=, s=, e=}, ... } where s/e are
-- positions in the text. out/seen can be passed in to collect over several lines.
-- missed (optional) gets the words that were not found.
function ns.Match(s, out, seen, limit, missed)
  out, seen, limit = out or {}, seen or {}, limit or 99
  local toks = {}
  for st, w, en in s:gmatch("()([%a']+)()") do
    local lw = w:lower()
    if lw:sub(-2) == "'s" then lw = lw:sub(1, -3) end
    lw = lw:gsub("'", "")
    if lw ~= "" then toks[#toks + 1] = { w = lw, s = st, e = en - 1 } end
  end
  local function add(key, s1, e1)
    if not seen[key] then
      seen[key] = true
      out[#out + 1] = { key = key, s = s1, e = e1 }
    end
  end
  local i = 1
  while i <= #toks and #out < limit do
    local step, hit = 1, false
    for n = math.min(3, #toks - i + 1), 1, -1 do
      local parts = {}
      for j = i, i + n - 1 do parts[#parts + 1] = toks[j].w end
      local key = LookupWord(table.concat(parts, " "))
      if key then
        add(key, toks[i].s, toks[i + n - 1].e)
        step, hit = n, true
        break
      end
    end
    if not hit then
      local a, b = SplitCompound(toks[i].w)
      if a then
        add(a, toks[i].s, toks[i].e)
        add(b, toks[i].s, toks[i].e)
      elseif missed then
        missed[#missed + 1] = toks[i].w
      end
    end
    i = i + step
  end
  return out
end

function ns.Romaji(key)
  local e = ns.dict[key]
  e.romaji = e.romaji or ns.ToRomaji(e.kana)
  return e.romaji
end

local function FormatEntry(key)
  local e = ns.dict[key]
  local parts = {}
  if e.kanji then
    if DB.showKanji then parts[#parts + 1] = "|cffffffff" .. e.kanji .. "|r" end
    if DB.showKana then parts[#parts + 1] = "|cffffd100" .. e.kana .. "|r" end
  elseif DB.showKanji or DB.showKana then
    parts[#parts + 1] = "|cffffd100" .. e.kana .. "|r"
  end
  if DB.showRomaji then parts[#parts + 1] = "|cff80c0ff[" .. ns.Romaji(key) .. "]|r" end
  if #parts == 0 then return nil end
  if DB.showEnglish then parts[#parts + 1] = "|cff909090= " .. ns.Label(key) .. "|r" end
  local line = table.concat(parts, "   ")
  if DB.showBreakdown and DB.showKanji and ns.BreakdownText then
    local b = ns.BreakdownText(key)
    if b then line = line .. "\n    " .. b end
  end
  -- Other meanings of the same English word
  for _, other in ipairs(ns.OtherSenses(key)) do
    local o = ns.dict[other]
    line = line .. "\n    |cff808080also: " .. (o.kanji and (o.kanji .. " ") or "") .. o.kana
      .. "  = " .. ns.Label(other) .. "|r"
  end
  return line
end
ns.FormatEntry = FormatEntry

local function ShowEntries(keys)
  local lines = {}
  for _, k in ipairs(keys) do
    local l = FormatEntry(k)
    if l then lines[#lines + 1] = l end
  end
  if #lines == 0 then popup:Hide() return false end
  text:SetText(table.concat(lines, "\n"))
  popup:SetSize(text:GetStringWidth() + 20, text:GetStringHeight() + 18)
  popup:Show()
  return true
end

---------------------------------------------------------------------------
-- Reads the tooltip a few times per second
---------------------------------------------------------------------------
local function IsSecret(v)
  return issecretvalue and issecretvalue(v)
end

local function Update()
  if GetTime() < testUntil then
    if lastKey ~= "TEST" .. settingsVersion then
      lastKey = "TEST" .. settingsVersion
      popup:ClearAllPoints()
      popup:SetPoint("CENTER", UIParent, "CENTER", 0, 120)
      ShowEntries({ "wolf", "sword", "inn", "potion", "seasoned", "first aid" })
    end
    return
  end

  if not DB.enabled or not GameTooltip:IsShown()
    or (DB.requireShift and not IsShiftKeyDown()) then
    popup:Hide()
    lastKey = nil
    return
  end

  -- All lines are read for context (which meaning of a word fits); only the name,
  -- or every line with "read every tooltip line", is translated.
  local texts, all = {}, {}
  for i = 1, GameTooltip:NumLines() or 1 do
    local fs = _G["GameTooltipTextLeft" .. i]
    local t = fs and fs:GetText()
    if t and not IsSecret(t) then
      all[#all + 1] = CleanText(t)
      if i == 1 or DB.scanAllLines then texts[#texts + 1] = t end
    end
  end
  local key = table.concat(texts, "\n") .. "#" .. settingsVersion
  if key == lastKey then return end
  lastKey = key

  local matches, seen, missed = {}, {}, {}
  for i, t in ipairs(texts) do
    ns.Match(CleanText(t), matches, seen, DB.maxWords, i == 1 and missed or nil)
  end
  if #missed > 0 and DB.collectMissing and ns.NoteMissing then
    ns.NoteMissing(missed, CleanText(texts[1]))
  end
  if #matches == 0 then
    popup:Hide()
    ns.currentKeys = {}
    return
  end
  local ctx = ns.Context(unpack(all))
  local found = {}
  for i, m in ipairs(matches) do found[i] = ns.ResolveSense(m.key, ctx) end
  local first = found[1] ~= ns.currentKeys[1]
  ns.currentKeys = found

  popup:ClearAllPoints()
  if DB.below then
    popup:SetPoint("TOPLEFT", GameTooltip, "BOTTOMLEFT", 0, -2)
  else
    popup:SetPoint("BOTTOMLEFT", GameTooltip, "TOPLEFT", 0, 2)
  end
  ShowEntries(found)
  if DB.speakOnHover and first then ns.Speak(found[1]) end
end

local driver = CreateFrame("Frame")
local elapsed = 0
driver:SetScript("OnUpdate", function(_, dt)
  elapsed = elapsed + dt
  if elapsed < 0.05 or not DB then return end
  elapsed = 0
  local ok, err = pcall(Update)
  if not ok then
    popup:Hide()
    if not errorShown then
      errorShown = true
      Print("error: " .. tostring(err))
    end
  end
end)

---------------------------------------------------------------------------
-- On-screen button
---------------------------------------------------------------------------
local button

local function UpdateButton()
  if not button then return end
  button:SetShown(DB.showButton)
  if DB.enabled then
    button.label:SetText("|cff80ff80JP|r")
    if button.SetBackdropBorderColor then button:SetBackdropBorderColor(0.3, 0.9, 0.3, 1) end
  else
    button.label:SetText("|cff808080JP|r")
    if button.SetBackdropBorderColor then button:SetBackdropBorderColor(0.5, 0.5, 0.5, 1) end
  end
end

local function PlaceButton()
  local b = DB.button
  button:ClearAllPoints()
  button:SetPoint(b.point, UIParent, b.point, b.x, b.y)
end

local function CreateButton()
  button = CreateFrame("Button", "AzerothNihongoButton", UIParent,
    BackdropTemplateMixin and "BackdropTemplate" or nil)
  button:SetSize(40, 22)
  button:SetFrameStrata("MEDIUM")
  button:SetClampedToScreen(true)
  button:SetMovable(true)
  button:EnableMouse(true)
  button:RegisterForClicks("LeftButtonUp", "RightButtonUp", "MiddleButtonUp")
  button:RegisterForDrag("LeftButton")
  if button.SetBackdrop then
    button:SetBackdrop({
      bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
      edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
      tile = true, tileSize = 16, edgeSize = 12,
      insets = { left = 3, right = 3, top = 3, bottom = 3 },
    })
    button:SetBackdropColor(0, 0, 0, 0.8)
  end
  button.label = button:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  button.label:SetPoint("CENTER")

  button:SetScript("OnClick", function(_, mouse)
    if IsShiftKeyDown() then return end
    if mouse == "MiddleButton" or IsAltKeyDown() then
      ns.ToggleLexicon()
    elseif mouse == "RightButton" then
      ns.ToggleQuiz()
    elseif IsControlKeyDown() then
      ns.OpenOptions()
    else
      ns.Toggle()
    end
  end)
  button:SetScript("OnDragStart", function(self)
    if IsShiftKeyDown() then self:StartMoving() end
  end)
  button:SetScript("OnDragStop", function(self)
    self:StopMovingOrSizing()
    local point, _, _, x, y = self:GetPoint()
    DB.button = { point = point, x = x, y = y }
  end)
  button:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
    GameTooltip:AddLine("Azeroth Nihongo")
    GameTooltip:AddLine("Left-click: on/off", 1, 1, 1)
    GameTooltip:AddLine("Right-click: quiz", 1, 1, 1)
    GameTooltip:AddLine("Alt-click or middle-click: lexicon", 1, 1, 1)
    GameTooltip:AddLine("Ctrl-click: options", 1, 1, 1)
    GameTooltip:AddLine("Shift-drag: move", 1, 1, 1)
    GameTooltip:Show()
  end)
  button:SetScript("OnLeave", function() GameTooltip:Hide() end)

  PlaceButton()
  UpdateButton()
end

function ns.ResetButton()
  DB.button = { point = DEFAULTS.button.point, x = DEFAULTS.button.x, y = DEFAULTS.button.y }
  PlaceButton()
end

---------------------------------------------------------------------------
-- Shared
---------------------------------------------------------------------------
function ns.Refresh()
  settingsVersion = settingsVersion + 1
  lastKey = nil
  ns.ApplyFont()
  UpdateButton()
  if ns.RefreshOptions then ns.RefreshOptions() end
end

local function OnOff(v) return v and "|cff80ff80on|r" or "|cffff8080off|r" end

function ns.Toggle()
  DB.enabled = not DB.enabled
  ns.Refresh()
  Print(OnOff(DB.enabled))
end
AzerothNihongo_Toggle = ns.Toggle

function ns.Test()
  testUntil = GetTime() + 6
  lastKey = nil
end

local function CopyDefaults(src, dst)
  for k, v in pairs(src) do
    if type(v) == "table" then
      if type(dst[k]) ~= "table" then dst[k] = {} end
      CopyDefaults(v, dst[k])
    elseif dst[k] == nil then
      dst[k] = v
    end
  end
end

local events = CreateFrame("Frame")
events:RegisterEvent("ADDON_LOADED")
events:SetScript("OnEvent", function(self, _, name)
  if name ~= ADDON then return end
  self:UnregisterEvent("ADDON_LOADED")
  AzerothNihongoDB = AzerothNihongoDB or {}
  DB = AzerothNihongoDB
  CopyDefaults(DEFAULTS, DB)
  -- The font list changed (1.0.1, 1.5.1): start again from the Japanese font.
  if DB.fontListVersion ~= 3 then
    DB.fontListVersion = 3
    DB.fontIndex = 1
  end
  ns.DB = DB
  ns.ApplyFont()
  ns.PreloadFont()
  if not ns.fontIdx or ns.fontIdx > 2 then
    Print("|cffff8080Japanese font not found|r - some characters may show as boxes. "
      .. "Quit the game completely and start it again (/reload does not pick up new files).")
  end
  CreateButton()
  if ns.RegisterOptions then ns.RegisterOptions() end
  if ns.MissingLoaded then ns.MissingLoaded() end
end)

---------------------------------------------------------------------------
-- Slash commands
---------------------------------------------------------------------------
local TOGGLES = {
  kanji = { "showKanji", "Kanji" },
  kana = { "showKana", "Hiragana/katakana" },
  romaji = { "showRomaji", "Romaji" },
  english = { "showEnglish", "English word" },
  breakdown = { "showBreakdown", "Kanji breakdown" },
  all = { "scanAllLines", "Read every tooltip line" },
  shift = { "requireShift", "Only while Shift is held" },
  below = { "below", "Popup below the tooltip" },
  button = { "showButton", "On-screen button" },
  speak = { "speakOnHover", "Say hovered words" },
}

SLASH_AZEROTHNIHONGO1 = "/jp"
SLASH_AZEROTHNIHONGO2 = "/nihongo"
SlashCmdList.AZEROTHNIHONGO = function(msg)
  if not DB then return end
  local cmd, arg = (msg or ""):lower():match("^%s*(%S*)%s*(.-)%s*$")
  if cmd == "" or cmd == "toggle" then
    ns.Toggle()
  elseif cmd == "on" or cmd == "off" then
    DB.enabled = (cmd == "on"); ns.Refresh(); Print(OnOff(DB.enabled))
  elseif TOGGLES[cmd] then
    local key, label = TOGGLES[cmd][1], TOGGLES[cmd][2]
    DB[key] = not DB[key]; ns.Refresh()
    Print(label .. ": " .. OnOff(DB[key]))
  elseif cmd == "size" then
    local n = tonumber(arg)
    if n and n >= 8 and n <= 40 then
      DB.fontSize = n; ns.Refresh(); Print("Text size: " .. n)
    else
      Print("Give a size between 8 and 40, e.g. /jp size 18")
    end
  elseif cmd == "font" then
    ns.CycleFont(); ns.Test()
  elseif cmd == "voice" then
    ns.CycleVoice()
  elseif cmd == "ttsdebug" then
    DB.ttsDebug = not DB.ttsDebug
    Print("Speech debug messages: " .. OnOff(DB.ttsDebug)
      .. (DB.ttsDebug and " (to a chat tab named JP if you have one)" or ""))
  elseif cmd == "say" then
    if arg ~= "" and ns.LookupWord(arg) then ns.Speak(ns.LookupWord(arg)) else ns.SpeakHovered() end
  elseif cmd == "quiz" or cmd == "q" then
    ns.ToggleQuiz()
  elseif cmd == "kanaquiz" or cmd == "kq" then
    DB.quiz.mode = "kana"
    if ns.QuizIsShown() then ns.QuizNext() else ns.ToggleQuiz() end
  elseif cmd == "lex" or cmd == "lexicon" or cmd == "dict" then
    ns.ToggleLexicon()
  elseif cmd == "kanatable" or cmd == "chart" then
    ns.ToggleLexicon("kana")
  elseif cmd == "kanjilist" then
    ns.ToggleLexicon("kanji")
  elseif cmd == "words" then
    ns.ToggleLexicon("words")
  elseif cmd == "draw" or cmd == "write" then
    local raw = (msg or ""):match("^%s*%S+%s*(.-)%s*$") or ""
    if arg == "" then ns.ToggleWriting()
    elseif arg == "hira" or arg == "hiragana" then ns.ToggleWriting("hira")
    elseif arg == "kata" or arg == "katakana" then ns.ToggleWriting("kata")
    elseif arg == "kanji" then ns.ToggleWriting("kanji")
    elseif ns.LookupWord(arg) and ns.dict[ns.LookupWord(arg)].kanji then
      ns.WriteChar(ns.dict[ns.LookupWord(arg)].kanji)
    else ns.WriteChar(raw) end
  elseif cmd == "missing" or cmd == "untranslated" then
    ns.ToggleMissing()
  elseif cmd == "pop" then
    if arg == "on" or arg == "off" then
      DB.pop.enabled = (arg == "on"); ns.ReplanPop()
      Print("Pop quiz timer: " .. OnOff(DB.pop.enabled))
    elseif arg == "status" then
      Print(ns.PopStatus())
    else
      ns.PopQuiz("manual")
    end
  elseif cmd == "test" then
    ns.Test()
  elseif cmd == "config" or cmd == "options" or cmd == "opt" then
    ns.OpenOptions()
  else
    Print("commands:")
    Print("/jp - on/off")
    Print("/jp kanji | kana | romaji | english | breakdown - show/hide a field")
    Print("/jp all - read every tooltip line (not just the name)")
    Print("/jp shift - only show while Shift is held")
    Print("/jp below - popup below/above the tooltip")
    Print("/jp size 18 - text size")
    Print("/jp font - next font (if kanji show as boxes)")
    Print("/jp say [word] - say the hovered word (or a given English word)")
    Print("/jp voice - next Japanese voice")
    Print("/jp speak - say hovered words automatically")
    Print("/jp test - show an example")
    Print("/jp quiz - open the quiz  |  /jp kq - kana quiz (hiragana/katakana)")
    Print("/jp lex - lexicon  |  /jp chart - kana chart  |  /jp kanjilist  |  /jp words - your quiz words")
    Print("/jp pop - pop quiz now  |  /jp pop on|off|status - the timer")
    Print("/jp draw - writing practice  |  /jp draw hira|kata|kanji  |  /jp draw あ  |  /jp draw wolf")
    Print("/jp missing - words seen that have no translation yet")
    Print("/jp button - show/hide the button")
    Print("/jp config - options")
  end
end
