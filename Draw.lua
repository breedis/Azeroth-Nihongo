-- Writing practice: draw kana and kanji stroke by stroke with the mouse, like a
-- practice sheet. The guide shows the strokes and a small number where each one starts.
-- Each stroke you draw is checked for its place, its shape, its direction and its order.
-- Stroke data: Strokes.lua (from KanjiVG, CC BY-SA 3.0).
local _, ns = ...

local SIZE = 300              -- drawing box in pixels
local BOX = 109               -- KanjiVG coordinates are 0..109
local PX = SIZE / BOX
local N = 24                  -- points compared per stroke
local MODES = { "trace", "hint", "memory" }
local MODE_LABEL = { trace = "Trace", hint = "Hints only", memory = "From memory" }
local MODE_HELP = {
  trace = "Draw over the grey strokes, starting at the numbers.",
  hint = "Only the start of the next stroke is shown.",
  memory = "Write it from memory. A hint comes after two misses.",
}
-- How far a stroke may be off, in box units (the box is 109 across).
local TOL = {
  trace = { shape = 13, offset = 12 },
  hint = { shape = 15, offset = 16 },
  memory = { shape = 17, offset = 24 },
}
local SETS = { "hira", "kata", "kanji" }
local SET_LABEL = { hira = "Hiragana", kata = "Katakana", kanji = "Kanji" }

local CIRCLE = "Interface\\CHARACTERFRAME\\TempPortraitAlphaMask"
local WHITE = "Interface\\Buttons\\WHITE8X8"
local DEFAULT_FONT = "Fonts\\FRIZQT__.TTF"

local COLOR = {
  guide = { 0.55, 0.55, 0.6, 0.35 },
  next = { 0.55, 0.75, 1, 0.55 },
  ink = { 0.96, 0.92, 0.82, 1 },
  live = { 0.5, 0.8, 1, 1 },
  bad = { 1, 0.3, 0.3, 1 },
  pen = { 1, 0.82, 0, 1 },
}

---------------------------------------------------------------------------
-- Stroke data
---------------------------------------------------------------------------
local ALPHA_INDEX = {}
do
  local i = 0
  for c = 35, 126 do
    if c ~= 92 then ALPHA_INDEX[c] = i; i = i + 1 end
  end
end
local function Coord(s, i) return ALPHA_INDEX[s:byte(i)] / 90 * BOX end

local cache = {}
-- Returns { strokes = { { {x,y}, ... }, ... }, nums = { {x,y}, ... } } or nil.
function ns.DecodeStrokes(ch)
  if cache[ch] ~= nil then return cache[ch] or nil end
  local raw = ns.STROKES and ns.STROKES[ch]
  if not raw then cache[ch] = false return nil end
  local body, numPart = raw:match("^(.-)!(.*)$")
  local d = { strokes = {}, nums = {} }
  for s in body:gmatch("%S+") do
    local pts = {}
    for i = 1, #s - 1, 2 do pts[#pts + 1] = { Coord(s, i), Coord(s, i + 1) } end
    d.strokes[#d.strokes + 1] = pts
  end
  for i = 1, #numPart - 1, 2 do d.nums[#d.nums + 1] = { Coord(numPart, i), Coord(numPart, i + 1) } end
  cache[ch] = d
  return d
end

function ns.CanWrite(ch) return ns.STROKES ~= nil and ns.STROKES[ch] ~= nil end

local CHAR = "[%z\1-\127\194-\244][\128-\191]*"
local function Chars(s)
  local out = {}
  for ch in s:gmatch(CHAR) do out[#out + 1] = ch end
  return out
end
local function IsKanji(ch) return (ch:byte(1) or 0) >= 0xE4 end

---------------------------------------------------------------------------
-- Comparing strokes
---------------------------------------------------------------------------
local function Dist(a, b) return math.sqrt((a[1] - b[1]) ^ 2 + (a[2] - b[2]) ^ 2) end

local function Length(pts)
  local L = 0
  for i = 2, #pts do L = L + Dist(pts[i - 1], pts[i]) end
  return L
end

-- n points spaced evenly along the line.
local function Resample(pts, n)
  local L = Length(pts)
  if #pts == 1 or L < 1e-6 then
    local out = {}
    for i = 1, n do out[i] = { pts[1][1], pts[1][2] } end
    return out
  end
  local step, out = L / (n - 1), { { pts[1][1], pts[1][2] } }
  local acc, i = 0, 2
  local prev = { pts[1][1], pts[1][2] }
  while i <= #pts and #out < n do
    local d = Dist(prev, pts[i])
    if acc + d >= step and d > 0 then
      local t = (step - acc) / d
      local q = { prev[1] + t * (pts[i][1] - prev[1]), prev[2] + t * (pts[i][2] - prev[2]) }
      out[#out + 1] = q
      prev, acc = q, 0
    else
      acc = acc + d
      prev = pts[i]
      i = i + 1
    end
  end
  while #out < n do out[#out + 1] = { pts[#pts][1], pts[#pts][2] } end
  return out
end

local function Centroid(p)
  local x, y = 0, 0
  for _, q in ipairs(p) do x, y = x + q[1], y + q[2] end
  return x / #p, y / #p
end

-- shape = how far the points are apart once both strokes are moved onto each other,
-- offset = how far apart the strokes are.
local function Compare(drawn, want, reverse)
  local a, b = Resample(drawn, N), Resample(want, N)
  if reverse then
    local r = {}
    for i = #b, 1, -1 do r[#r + 1] = b[i] end
    b = r
  end
  local ax, ay = Centroid(a)
  local bx, by = Centroid(b)
  local dx, dy = bx - ax, by - ay
  local sum = 0
  for i = 1, N do sum = sum + Dist({ a[i][1] + dx, a[i][2] + dy }, b[i]) end
  return sum / N, math.sqrt(dx * dx + dy * dy)
end

local function Reverse(p)
  local r = {}
  for i = #p, 1, -1 do r[#r + 1] = p[i] end
  return r
end

local function Fits(drawn, want, tol, reverse)
  if reverse then want = Reverse(want) end
  local shape, offset = Compare(drawn, want)
  -- Length, measured on smoothed points so a shaky hand does not count as longer.
  local a, b = Resample(drawn, 12), Resample(want, 12)
  local ld, lw = Length(a), Length(b)
  local lenOk = math.abs(ld - lw) < math.max(tol.shape * 1.5, lw * 0.6)
  -- Direction: the stroke must start at the start and end at the end
  -- (not checked for dots and strokes that end where they began).
  local dirOk = true
  if Dist(b[1], b[#b]) > 8 then
    local fwd = Dist(a[1], b[1]) + Dist(a[#a], b[#b])
    local bwd = Dist(a[1], b[#b]) + Dist(a[#a], b[1])
    dirOk = fwd <= bwd
  end
  return shape <= tol.shape and offset <= tol.offset and lenOk and dirOk, shape + offset
end

-- What the drawn stroke was: "ok", "reverse", "order" (with the stroke it matched) or "miss".
local function Verdict(pts, strokes, nxt, tol)
  local ok, score = Fits(pts, strokes[nxt], tol)
  -- A later stroke that fits much better means the strokes were drawn out of order.
  for j = nxt + 1, #strokes do
    local okj, sj = Fits(pts, strokes[j], tol)
    if okj and (not ok or sj < score * 0.6) then return "order", j end
  end
  if ok then return "ok" end
  if Fits(pts, strokes[nxt], tol, true) then return "reverse" end
  return "miss"
end
ns.StrokeFits, ns.StrokeVerdict = Fits, Verdict -- for tests

---------------------------------------------------------------------------
-- Window
---------------------------------------------------------------------------
local W = CreateFrame("Frame", "AzerothNihongoDraw", UIParent,
  BackdropTemplateMixin and "BackdropTemplate" or nil)
W:SetSize(420, 560)
W:SetPoint("CENTER", 0, 40)
W:SetFrameStrata("DIALOG")
W:SetClampedToScreen(true)
W:SetMovable(true)
W:EnableMouse(true)
W:RegisterForDrag("LeftButton")
W:SetScript("OnDragStart", W.StartMoving)
W:SetScript("OnDragStop", W.StopMovingOrSizing)
W:Hide()
if W.SetBackdrop then
  W:SetBackdrop({
    bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
    edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
    tile = true, tileSize = 32, edgeSize = 32,
    insets = { left = 11, right = 12, top = 12, bottom = 11 },
  })
end
tinsert(UISpecialFrames, "AzerothNihongoDraw") -- Esc closes

local closeBtn = CreateFrame("Button", nil, W, "UIPanelCloseButton")
closeBtn:SetPoint("TOPRIGHT", -6, -6)

local jpFonts = {}
local function SetJP(fs, size)
  if fs:SetFont(ns.fontPath or DEFAULT_FONT, size, "") == false then fs:SetFont(DEFAULT_FONT, size, "") end
end
local function Text(parent, size, justify, layer)
  local fs = parent:CreateFontString(nil, layer or "OVERLAY", "GameFontHighlight")
  jpFonts[#jpFonts + 1] = { fs, size }
  SetJP(fs, size)
  fs:SetJustifyH(justify or "LEFT")
  return fs
end

local title = Text(W, 18, "CENTER")
title:SetPoint("TOP", 0, -20)
title:SetText("書く  |cffccccccWriting practice|r")

local prompt = Text(W, 20, "CENTER")
prompt:SetPoint("TOP", 0, -48)
prompt:SetWidth(380)
local sub = Text(W, 12, "CENTER")
sub:SetPoint("TOP", prompt, "BOTTOM", 0, -4)
sub:SetWidth(380)

-- The drawing box
local canvas = CreateFrame("Frame", nil, W)
canvas:SetSize(SIZE, SIZE)
canvas:SetPoint("TOP", 0, -102)
canvas:EnableMouse(true)
local paper = canvas:CreateTexture(nil, "BACKGROUND")
paper:SetAllPoints()
paper:SetColorTexture(0.08, 0.07, 0.06, 0.92)
-- Practice-sheet guide lines: a frame and a dashed cross.
local function Rule(x1, y1, x2, y2)
  local t = canvas:CreateTexture(nil, "BORDER")
  t:SetColorTexture(0.6, 0.35, 0.3, 0.35)
  t:SetPoint("TOPLEFT", x1, -y1)
  t:SetSize(math.max(1, x2 - x1), math.max(1, y2 - y1))
end
Rule(0, 0, SIZE, 1); Rule(0, SIZE - 1, SIZE, SIZE); Rule(0, 0, 1, SIZE); Rule(SIZE - 1, 0, SIZE, SIZE)
for i = 0, SIZE - 1, 12 do
  Rule(i, SIZE / 2, i + 6, SIZE / 2 + 1)
  Rule(SIZE / 2, i, SIZE / 2 + 1, i + 6)
end

local status = Text(W, 13, "CENTER")
status:SetPoint("TOP", canvas, "BOTTOM", 0, -8)
status:SetWidth(380)
local help = Text(W, 11, "CENTER")
help:SetPoint("TOP", status, "BOTTOM", 0, -4)
help:SetWidth(380)

---------------------------------------------------------------------------
-- Drawing lines: Line objects where the game has them, else rows of dots.
---------------------------------------------------------------------------
local HAS_LINE = canvas.CreateLine ~= nil

local function NewPool(sublevel)
  return { lines = {}, dots = {}, nl = 0, nd = 0, sub = sublevel }
end

local function Dot(pool, x, y, size, c)
  pool.nd = pool.nd + 1
  local t = pool.dots[pool.nd]
  if not t then
    t = canvas:CreateTexture(nil, "ARTWORK", nil, pool.sub)
    t:SetTexture(CIRCLE)
    pool.dots[pool.nd] = t
  end
  t:SetVertexColor(c[1], c[2], c[3], c[4])
  t:SetSize(size, size)
  t:ClearAllPoints()
  t:SetPoint("CENTER", canvas, "TOPLEFT", x, -y)
  t:Show()
end

-- A segment between two points in box units.
local function Seg(pool, a, b, thick, c)
  local x1, y1, x2, y2 = a[1] * PX, a[2] * PX, b[1] * PX, b[2] * PX
  if HAS_LINE then
    pool.nl = pool.nl + 1
    local l = pool.lines[pool.nl]
    if not l then
      l = canvas:CreateLine(nil, "ARTWORK", nil, pool.sub)
      l:SetTexture(WHITE)
      pool.lines[pool.nl] = l
    end
    l:SetVertexColor(c[1], c[2], c[3], c[4])
    l:SetThickness(thick)
    l:SetStartPoint("TOPLEFT", canvas, x1, -y1)
    l:SetEndPoint("TOPLEFT", canvas, x2, -y2)
    l:Show()
    Dot(pool, x2, y2, thick, c) -- round joint
  else
    local len = math.sqrt((x2 - x1) ^ 2 + (y2 - y1) ^ 2)
    local n = math.max(1, math.ceil(len / (thick * 0.35)))
    for i = 1, n do
      local t = i / n
      Dot(pool, x1 + (x2 - x1) * t, y1 + (y2 - y1) * t, thick, c)
    end
  end
end

local function Stroke(pool, pts, thick, c, upto)
  if #pts == 0 then return end
  Dot(pool, pts[1][1] * PX, pts[1][2] * PX, thick, c)
  for i = 2, upto or #pts do Seg(pool, pts[i - 1], pts[i], thick, c) end
end

local function Clear(pool)
  for i = 1, pool.nl do pool.lines[i]:Hide() end
  for i = 1, pool.nd do pool.dots[i]:Hide() end
  pool.nl, pool.nd = 0, 0
end

local guidePool, inkPool, livePool = NewPool(0), NewPool(2), NewPool(4)

local numLabels = {}
local function NumLabel(i)
  local fs = numLabels[i]
  if not fs then
    fs = canvas:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    fs:SetFont(DEFAULT_FONT, 13, "OUTLINE")
    numLabels[i] = fs
  end
  return fs
end

---------------------------------------------------------------------------
-- State
---------------------------------------------------------------------------
local S = {
  mode = "trace",
  set = "hira",
  ch = nil,          -- character being written
  data = nil,        -- its strokes
  done = 0,          -- strokes finished
  misses = 0,        -- misses on this character
  strokeMisses = 0,  -- misses on the current stroke
  queue = nil,       -- { name =, list = {...}, i = } when writing a list
  last = nil,
  intro = nil,       -- function(done) to call when the new signs from the quiz are written
  pop = nil,         -- { total =, done = } during a writing pop quiz
}
local drawing, livePts, badUntil, anim = false, nil, nil, nil

local function Stats(ch)
  local w = ns.DB.write
  w[ch] = w[ch] or { r = 0, w = 0 }
  return w[ch]
end

function ns.WriteStatus(ch)
  local s = ns.DB and ns.DB.write[ch]
  if not s or (s.r or 0) + (s.w or 0) == 0 then return "new" end
  if s.last == false then return "wrong" end
  if (s.r or 0) >= 3 and s.r > (s.w or 0) then return "learned" end
  return "right"
end

local meaningCache = {}
local function KanjiMeaning(ch)
  if meaningCache[ch] ~= nil then return meaningCache[ch] or nil end
  local alone, example
  for k, e in pairs(ns.dict) do
    if e.kanji == ch then
      if not alone or k < alone then alone = k end
    elseif not example and e.kanji and e.kanji:find(ch, 1, true) then
      example = k
    end
  end
  local text
  if alone then
    text = ns.Label(alone)
  elseif example then
    local e = ns.dict[example]
    text = "as in " .. e.kanji .. " " .. e.kana .. " = " .. ns.Label(example)
  end
  meaningCache[ch] = text or false
  return text
end

local function SpeakText(ch)
  if IsKanji(ch) then return (ns.KanjiReadings(ch) or {})[1] end
  return ch
end

local function Prompt()
  local ch = S.ch
  if not ch then prompt:SetText("") sub:SetText("") return end
  local showChar = S.mode ~= "memory" or S.done >= #S.data.strokes
  if IsKanji(ch) then
    local reads = {}
    for i, r in ipairs(ns.KanjiReadings(ch) or {}) do
      if i > 3 then break end
      reads[#reads + 1] = "|cffffd100" .. r .. "|r |cff80c0ff[" .. ns.ToRomaji(r) .. "]|r"
    end
    prompt:SetText((showChar and ("|cffffffff" .. ch .. "|r   ") or "") .. table.concat(reads, ", "))
    local m = KanjiMeaning(ch)
    sub:SetText("|cffbbbbbbKanji" .. (m and (" - " .. m) or "") .. "  (" .. #S.data.strokes .. " strokes)|r")
  else
    local kind = ns.IsKatakana(ch) and "Katakana" or "Hiragana"
    prompt:SetText((showChar and ("|cffffffff" .. ch .. "|r   ") or "")
      .. "|cff80c0ff[" .. ns.KanaRomaji(ch) .. "]|r")
    sub:SetText("|cffbbbbbb" .. kind .. "  (" .. #S.data.strokes .. " strokes)|r")
  end
end

local function Render()
  Clear(guidePool); Clear(inkPool)
  for _, fs in ipairs(numLabels) do fs:Hide() end
  if not S.data then return end
  local strokes, nums = S.data.strokes, S.data.nums
  local total = #strokes
  local finished = S.done >= total
  for i = 1, S.done do Stroke(inkPool, strokes[i], 10, COLOR.ink) end
  if finished then return end
  local nxt = S.done + 1
  local showAll = S.mode == "trace"
  local showNext = S.mode ~= "memory" or S.strokeMisses >= 2
  for i = nxt, total do
    if showAll or (i == nxt and S.mode == "memory" and S.strokeMisses >= 2) then
      Stroke(guidePool, strokes[i], 9, i == nxt and COLOR.next or COLOR.guide)
    end
  end
  if showNext then
    local p = strokes[nxt][1]
    Dot(guidePool, p[1] * PX, p[2] * PX, 12, COLOR.pen)
  end
  for i = nxt, total do
    if showAll or (showNext and i == nxt) then
      local fs, pos = NumLabel(i), nums[i] or strokes[i][1]
      fs:ClearAllPoints()
      fs:SetPoint("CENTER", canvas, "TOPLEFT", pos[1] * PX, -pos[2] * PX)
      fs:SetText(i == nxt and ("|cffffd100" .. i .. "|r") or ("|cff999999" .. i .. "|r"))
      fs:Show()
    end
  end
end

local function SetStatus(msg) status:SetText(msg or "") end

local modeBtn, setBtn

local function UpdateTitle()
  if S.intro then
    title:SetText("|cffff9933New sign!|r  |cffccccccWrite it before the question|r")
  elseif S.pop then
    title:SetText(("|cffff9933Pop quiz!|r  書く  |cffcccccc%d / %d|r"):format(math.min(S.pop.done + 1, S.pop.total), S.pop.total))
  else
    title:SetText("書く  |cffccccccWriting practice|r")
  end
end

local function UpdateButtons()
  UpdateTitle()
  modeBtn:SetText("Mode: " .. MODE_LABEL[S.mode])
  if S.queue then
    setBtn:SetText(S.queue.name)
  else
    setBtn:SetText("Next from: " .. SET_LABEL[S.set])
  end
  help:SetText("|cff999999" .. MODE_HELP[S.mode] .. "  Hold the left mouse button and draw.|r")
end

local function Start(ch)
  local data = ns.DecodeStrokes(ch)
  if not data then
    ns.Print("no stroke data for " .. tostring(ch))
    return false
  end
  S.ch, S.data, S.done, S.misses, S.strokeMisses = ch, data, 0, 0, 0
  S.last = ch
  anim, drawing, livePts = nil, false, nil
  Clear(livePool)
  for _, f in ipairs(jpFonts) do SetJP(f[1], f[2]) end
  Prompt()
  Render()
  local s = ns.DB.write[ch]
  SetStatus(s and ("|cff999999Written before: |cff66ff66%d|r without misses, |cffff5959%d|r with misses|r")
    :format(s.r or 0, s.w or 0) or "|cff999999New character|r")
  UpdateButtons()
  return true
end

-- Weighted pick: characters you miss come back more often.
local function Pool()
  if S.set == "kanji" then
    if not S.kanjiPool then
      S.kanjiPool = {}
      for ch in pairs(ns.STROKES) do
        if IsKanji(ch) then S.kanjiPool[#S.kanjiPool + 1] = ch end
      end
      table.sort(S.kanjiPool)
    end
    return S.kanjiPool
  end
  return ns.KanaPool(S.set, ns.DB.quiz.kanaDakuten, false)
end

local function PickNext()
  if S.queue then
    local q = S.queue
    q.i = q.i % #q.list + 1
    return q.list[q.i]
  end
  local list, total, weights = Pool(), 0, {}
  for i, ch in ipairs(list) do
    local s = ns.DB.write[ch]
    local w = 2
    if s then w = math.max(1, 1 + 3 * (s.w or 0) - (s.r or 0)) end
    if ch == S.last and #list > 1 then w = 0 end
    weights[i] = w
    total = total + w
  end
  local r = math.random() * total
  for i, w in ipairs(weights) do
    r = r - w
    if r <= 0 then return list[i] end
  end
  return list[#list]
end

local function Next() Start(PickNext()) end

-- Ends the "write the new sign first" step and hands back to the quiz.
local function EndIntro(done)
  local cb = S.intro
  if not cb then return end
  S.intro, S.queue = nil, nil
  S.mode = ns.DB.writeMode or "trace"
  if W:IsShown() then W:Hide() end
  cb(done)
end

-- Moves on after a character is finished (or skipped) in an intro or pop quiz.
-- Returns true when it handled it.
local function Advance(ch)
  if S.intro then
    local q = S.queue
    if q and q.i < #q.list then
      q.i = q.i + 1
      Start(q.list[q.i])
    else
      EndIntro(true)
    end
    return true
  end
  if S.pop then
    if S.pop.done >= S.pop.total then
      W:Hide()
    else
      Next()
    end
    return true
  end
  return false
end

-- Calls Advance after a short pause, unless the player has moved on already.
local function AdvanceSoon(delay)
  local ch = S.ch
  if C_Timer then
    C_Timer.After(delay, function()
      if W:IsShown() and S.ch == ch and not anim then Advance(ch) end
    end)
  end
end

local function Finish()
  local s = Stats(S.ch)
  local clean = S.misses == 0
  if clean then s.r = s.r + 1 else s.w = s.w + 1 end
  s.last, s.t = clean, time()
  Prompt()
  Render()
  SetStatus(clean and "|cff66ff66Well written! No misses.|r"
    or ("|cffffd100Done, with %d miss%s. It will come back more often.|r"):format(S.misses, S.misses == 1 and "" or "es"))
  if ns.DB.quiz.speak then
    local t = SpeakText(S.ch)
    if t then ns.SpeakKana(t) end
  end
  if ns.RefreshLexicon then ns.RefreshLexicon() end
  if S.intro then
    AdvanceSoon(1.2)
    return
  end
  if S.pop then
    S.pop.done = S.pop.done + 1
    if S.pop.done >= S.pop.total then
      SetStatus(status:GetText() .. "\n|cffff9933Pop quiz done!|r")
      AdvanceSoon(2.5)
    else
      AdvanceSoon(1.5)
    end
    return
  end
  if clean and ns.DB.quiz.autoNext and C_Timer then
    local ch = S.ch
    C_Timer.After(1.2, function() if W:IsShown() and S.ch == ch and not anim then Next() end end)
  end
end

-- Checks the stroke that was just drawn.
local function Judge(pts)
  local strokes = S.data.strokes
  local nxt = S.done + 1
  if nxt > #strokes then return end
  local tol = TOL[S.mode]
  if #pts < 2 then pts = { pts[1], { pts[1][1] + 0.5, pts[1][2] + 0.5 } } end
  local verdict, other = Verdict(pts, strokes, nxt, tol)
  if verdict == "ok" then
    S.done, S.strokeMisses = nxt, 0
    Clear(livePool)
    Render()
    if S.done >= #strokes then
      Finish()
    else
      SetStatus(("|cff66ff66Good.|r Stroke %d of %d."):format(S.done + 1, #strokes))
    end
    return
  end
  S.misses, S.strokeMisses = S.misses + 1, S.strokeMisses + 1
  local msg
  if verdict == "reverse" then
    msg = ("Right line, wrong way round. Start stroke %d at its number."):format(nxt)
  elseif verdict == "order" then
    msg = ("That is stroke %d. Stroke %d comes first."):format(other, nxt)
  else
    msg = ("Not quite. Try stroke %d again."):format(nxt)
  end
  if S.mode == "memory" and S.strokeMisses == 2 then msg = msg .. " Here is a hint." end
  SetStatus("|cffff6060" .. msg .. "|r")
  -- Show the miss in red for a moment.
  Clear(livePool)
  Stroke(livePool, pts, 8, COLOR.bad)
  badUntil = GetTime() + 0.7
  Render()
end

local function CursorUnits()
  local x, y = GetCursorPosition()
  local s = canvas:GetEffectiveScale()
  local left, top = canvas:GetLeft(), canvas:GetTop()
  if not left then return nil end
  local u = (x / s - left) / PX
  local v = (top - y / s) / PX
  return { math.max(-5, math.min(BOX + 5, u)), math.max(-5, math.min(BOX + 5, v)) }
end

local function EndStroke()
  if not drawing then return end
  drawing = false
  local pts = livePts
  livePts = nil
  if pts and #pts > 0 and S.data and S.done < #S.data.strokes then Judge(pts) end
end

canvas:SetScript("OnMouseDown", function(_, button)
  if button ~= "LeftButton" or anim or not S.data or S.done >= #S.data.strokes then return end
  local p = CursorUnits()
  if not p then return end
  badUntil = nil
  Clear(livePool)
  drawing, livePts = true, { p }
  Dot(livePool, p[1] * PX, p[2] * PX, 8, COLOR.live)
end)
canvas:SetScript("OnMouseUp", function(_, button)
  if button == "LeftButton" then EndStroke() end
end)

-- "Show order": draws the strokes one after another.
local ANIM_STROKE = 0.55
local animBtn

local function StopAnim()
  anim = nil
  Clear(livePool)
  animBtn:SetText("Show order")
  Render()
end

canvas:SetScript("OnUpdate", function()
  if anim then
    local strokes = S.data.strokes
    local t = (GetTime() - anim.start) / ANIM_STROKE
    local k = math.floor(t) + 1
    if k > #strokes + 1 then StopAnim() return end
    Clear(livePool)
    for i = 1, math.min(k - 1, #strokes) do Stroke(livePool, strokes[i], 10, COLOR.live) end
    if k <= #strokes then
      local pts = Resample(strokes[k], 20)
      local upto = math.max(1, math.floor((t - (k - 1)) * 20))
      Stroke(livePool, pts, 10, COLOR.live, upto)
      Dot(livePool, pts[upto][1] * PX, pts[upto][2] * PX, 12, COLOR.pen)
    end
    return
  end
  if badUntil and GetTime() > badUntil then
    badUntil = nil
    Clear(livePool)
  end
  if not drawing then return end
  if IsMouseButtonDown and not IsMouseButtonDown("LeftButton") then EndStroke() return end
  local p = CursorUnits()
  if not p then return end
  local last = livePts[#livePts]
  if Dist(p, last) >= 1.2 then
    livePts[#livePts + 1] = p
    Seg(livePool, last, p, 8, COLOR.live)
  end
end)

---------------------------------------------------------------------------
-- Buttons
---------------------------------------------------------------------------
local function Btn(label, w)
  local b = CreateFrame("Button", nil, W, "UIPanelButtonTemplate")
  b:SetSize(w, 22)
  b:SetText(label)
  return b
end

modeBtn = Btn("Mode", 150)
modeBtn:SetPoint("BOTTOMLEFT", 22, 46)
modeBtn:SetScript("OnClick", function()
  for i, m in ipairs(MODES) do
    if m == S.mode then S.mode = MODES[i % #MODES + 1] break end
  end
  ns.DB.writeMode = S.mode
  if S.ch then Start(S.ch) end
  UpdateButtons()
end)

animBtn = Btn("Show order", 110)
animBtn:SetPoint("LEFT", modeBtn, "RIGHT", 6, 0)
animBtn:SetScript("OnClick", function(self)
  if not S.data then return end
  if anim then StopAnim() return end
  drawing, livePts, badUntil = false, nil, nil
  anim = { start = GetTime() }
  self:SetText("Stop")
end)

local againBtn = Btn("Again", 100)
againBtn:SetPoint("LEFT", animBtn, "RIGHT", 6, 0)
againBtn:SetScript("OnClick", function() if S.ch then Start(S.ch) end end)

setBtn = Btn("", 150)
setBtn:SetPoint("BOTTOMLEFT", 22, 18)
setBtn:SetScript("OnClick", function()
  if S.queue then
    S.queue = nil
  else
    for i, s in ipairs(SETS) do
      if s == S.set then S.set = SETS[i % #SETS + 1] break end
    end
    ns.DB.writeSet = S.set
  end
  Next()
end)

local sayBtn = Btn("Say", 110)
sayBtn:SetPoint("LEFT", setBtn, "RIGHT", 6, 0)
sayBtn:SetScript("OnClick", function()
  local t = S.ch and SpeakText(S.ch)
  if t then ns.SpeakKana(t) end
end)

local nextBtn = Btn("Next", 100)
nextBtn:SetPoint("LEFT", sayBtn, "RIGHT", 6, 0)
nextBtn:SetScript("OnClick", function()
  local finished = S.data and S.done >= #S.data.strokes
  -- Skipping a character in a pop quiz still counts it as one of the questions.
  if S.pop and not finished then S.pop.done = S.pop.done + 1 end
  if not Advance(S.ch) then Next() end
end)

W:SetScript("OnHide", function()
  drawing, livePts, anim = false, nil, nil
  Clear(livePool)
  S.pop = nil
  if S.intro then EndIntro(false) end
end)

---------------------------------------------------------------------------
-- Opening the window
---------------------------------------------------------------------------
local function Open()
  if not ns.DB then return false end
  ns.DB.write = ns.DB.write or {}
  S.mode = ns.DB.writeMode or S.mode
  S.set = ns.DB.writeSet or S.set
  W:Show()
  return true
end

-- Write one character, or each writable character of a word in turn.
function ns.WriteChar(text)
  if S.intro then EndIntro(false) end
  if not Open() then return end
  S.pop = nil
  local list = {}
  for _, ch in ipairs(Chars(text or "")) do
    if ns.CanWrite(ch) then list[#list + 1] = ch end
  end
  if #list == 0 then ns.Print("nothing to write in " .. tostring(text)) return end
  S.queue = #list > 1 and { name = "Word: " .. text, list = list, i = 1 } or nil
  Start(list[1])
end

-- Write a list in order (e.g. a lexicon page), starting at first if given.
function ns.StartWriting(name, items, first)
  if S.intro then EndIntro(false) end
  if not Open() then return end
  S.pop = nil
  local list, seen, start = {}, {}, 1
  for _, item in ipairs(items) do
    for _, ch in ipairs(Chars(item)) do
      if ns.CanWrite(ch) and not seen[ch] then
        seen[ch] = true
        list[#list + 1] = ch
        if ch == first then start = #list end
      end
    end
  end
  if #list == 0 then return end
  S.queue = { name = "List: " .. name, list = list, i = start }
  Start(list[start])
end

-- Before the quiz asks about signs for the first time: write them, in trace mode,
-- in a window next to the quiz. onDone(true) when written, onDone(false) if closed.
function ns.WriteIntro(chars, onDone)
  if S.intro then EndIntro(false) end
  if not Open() then return false end
  local list = {}
  for _, ch in ipairs(chars) do if ns.CanWrite(ch) then list[#list + 1] = ch end end
  if #list == 0 then return false end
  S.pop, S.intro = nil, onDone
  S.mode = "trace"
  S.queue = { name = "New signs", list = list, i = 1 }
  local quiz = _G.AzerothNihongoQuiz
  if quiz and quiz:IsShown() then
    W:ClearAllPoints()
    W:SetPoint("TOPLEFT", quiz, "TOPRIGHT", 8, 0)
  end
  Start(list[1])
  return true
end

function ns.WritingIsShown() return W:IsShown() end

-- Pop quiz that asks you to write n characters from the "Next from" set.
function ns.StartPopWriting(n)
  if not ns.DB or W:IsShown() then return false end
  Open()
  S.intro, S.queue = nil, nil
  S.pop = { total = n, done = 0 }
  Next()
  return true
end

function ns.ToggleWriting(set)
  if W:IsShown() and not set then W:Hide() return end
  if not Open() then return end
  if S.intro then EndIntro(false) Open() end
  S.pop = nil
  if set then S.set, S.queue = set, nil; ns.DB.writeSet = set end
  if set or not S.ch then Next() else UpdateButtons() end
end

ns.WriteState = S -- for tests
