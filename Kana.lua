-- Kana -> romaji (Hepburn). Romaji räknas ut automatiskt från kana,
-- så ordboken behöver bara kanji + kana.
local _, ns = ...

-- Avkodar ett 3-byte UTF-8-tecken (allt kana ligger där) till en kodpunkt.
local function decode(ch)
  local b1, b2, b3 = ch:byte(1, 3)
  if not b3 or b1 < 0xE0 or b1 > 0xEF then return nil end
  return (b1 - 0xE0) * 4096 + (b2 - 0x80) * 64 + (b3 - 0x80)
end

-- Hiragana; katakana ligger exakt 0x60 högre i Unicode.
local BASE = {
  "あ","a",  "い","i",  "う","u",  "え","e",  "お","o",
  "か","ka", "き","ki", "く","ku", "け","ke", "こ","ko",
  "さ","sa", "し","shi","す","su", "せ","se", "そ","so",
  "た","ta", "ち","chi","つ","tsu","て","te", "と","to",
  "な","na", "に","ni", "ぬ","nu", "ね","ne", "の","no",
  "は","ha", "ひ","hi", "ふ","fu", "へ","he", "ほ","ho",
  "ま","ma", "み","mi", "む","mu", "め","me", "も","mo",
  "や","ya", "ゆ","yu", "よ","yo",
  "ら","ra", "り","ri", "る","ru", "れ","re", "ろ","ro",
  "わ","wa", "ゐ","i",  "ゑ","e",  "を","o",  "ん","n",
  "が","ga", "ぎ","gi", "ぐ","gu", "げ","ge", "ご","go",
  "ざ","za", "じ","ji", "ず","zu", "ぜ","ze", "ぞ","zo",
  "だ","da", "ぢ","ji", "づ","zu", "で","de", "ど","do",
  "ば","ba", "び","bi", "ぶ","bu", "べ","be", "ぼ","bo",
  "ぱ","pa", "ぴ","pi", "ぷ","pu", "ぺ","pe", "ぽ","po",
  "ゔ","vu",
}

local ROMA, SMALL_Y, SMALL_V = {}, {}, {}
local function both(t, kana, value)
  local cp = decode(kana)
  t[cp] = value
  t[cp + 0x60] = value
end

for i = 1, #BASE, 2 do both(ROMA, BASE[i], BASE[i + 1]) end
both(SMALL_Y, "ゃ", "a"); both(SMALL_Y, "ゅ", "u"); both(SMALL_Y, "ょ", "o")
both(SMALL_V, "ぁ", "a"); both(SMALL_V, "ぃ", "i"); both(SMALL_V, "ぅ", "u")
both(SMALL_V, "ぇ", "e"); both(SMALL_V, "ぉ", "o")

local SOKUON = decode("っ")   -- liten tsu: dubblar nästa konsonant
local CHOON = 0x30FC          -- ー: förlänger förra vokalen

function ns.ToRomaji(s)
  if not s then return "" end
  local chars = {}
  for ch in s:gmatch("[%z\1-\127\194-\244][\128-\191]*") do chars[#chars + 1] = ch end

  local out, double, i = {}, false, 1
  while i <= #chars do
    local ch = chars[i]
    local cp = decode(ch)
    if cp == CHOON then
      local prev = out[#out]
      local v = prev and prev:match("[aeiou]$")
      if v then out[#out] = prev .. v end
    elseif cp == SOKUON or cp == (SOKUON + 0x60) then
      double = true
    elseif cp and ROMA[cp] then
      local r = ROMA[cp]
      local nxt = chars[i + 1] and decode(chars[i + 1])
      if nxt and SMALL_Y[nxt] and #r > 1 and r:sub(-1) == "i" then
        -- きゃ -> kya, しゃ -> sha, ちゃ -> cha, じゃ -> ja
        local stem = r:sub(1, -2)
        if stem == "sh" or stem == "ch" or stem == "j" then
          r = stem .. SMALL_Y[nxt]
        else
          r = stem .. "y" .. SMALL_Y[nxt]
        end
        i = i + 1
      elseif nxt and SMALL_V[nxt] then
        -- ファ -> fa, ティ -> ti, ウィ -> wi, シェ -> she
        local stem
        if r == "u" then stem = "w"
        elseif r == "tsu" then stem = "ts"
        else stem = (r:gsub("[aeiou]$", "")) end
        r = stem .. SMALL_V[nxt]
        i = i + 1
      end
      if double then
        r = (r:sub(1, 2) == "ch" and "t" or r:sub(1, 1)) .. r
        double = false
      end
      if out[#out] == "n" and r:match("^[aeiouy]") then out[#out] = "n'" end
      out[#out + 1] = r
    elseif cp and SMALL_Y[cp] then
      out[#out + 1] = "y" .. SMALL_Y[cp]
    elseif cp and SMALL_V[cp] then
      out[#out + 1] = SMALL_V[cp]
    else
      out[#out + 1] = ch
    end
    i = i + 1
  end
  return table.concat(out)
end

---------------------------------------------------------------------------
-- Kana lists for the kana quiz and the chart
---------------------------------------------------------------------------
local function Split(s)
  local t = {}
  for ch in s:gmatch("[%z\1-\127\194-\244][\128-\191]*") do t[#t + 1] = ch end
  return t
end

local function Enc(c)
  return string.char(0xE0 + math.floor(c / 4096), 0x80 + math.floor(c / 64) % 64, 0x80 + c % 64)
end

-- Hiragana -> katakana (other characters are left as they are).
function ns.ToKata(s)
  local out = {}
  for _, ch in ipairs(Split(s)) do
    local c = decode(ch)
    if c and c >= 0x3041 and c <= 0x3096 then ch = Enc(c + 0x60) end
    out[#out + 1] = ch
  end
  return table.concat(out)
end

-- Katakana -> hiragana.
function ns.ToHira(s)
  local out = {}
  for _, ch in ipairs(Split(s)) do
    local c = decode(ch)
    if c and c >= 0x30A1 and c <= 0x30F6 then ch = Enc(c - 0x60) end
    out[#out + 1] = ch
  end
  return table.concat(out)
end

local KANA_BASIC = Split("あいうえおかきくけこさしすせそたちつてとなにぬねのはひふへほまみむめもやゆよらりるれろわをん")
local KANA_DAKUTEN = Split("がぎぐげござじずぜぞだぢづでどばびぶべぼぱぴぷぺぽ")
local KANA_COMBOS = {}
for _, s in ipairs(Split("きしちにひみりぎじびぴ")) do
  for _, y in ipairs(Split("ゃゅょ")) do KANA_COMBOS[#KANA_COMBOS + 1] = s .. y end
end
ns.KANA_BASIC, ns.KANA_DAKUTEN, ns.KANA_COMBOS = KANA_BASIC, KANA_DAKUTEN, KANA_COMBOS

-- All kana the kana quiz can ask, for a set ("hira", "kata" or "both").
function ns.KanaPool(set, dakuten, combos)
  local hira = {}
  for _, k in ipairs(KANA_BASIC) do hira[#hira + 1] = k end
  if dakuten then for _, k in ipairs(KANA_DAKUTEN) do hira[#hira + 1] = k end end
  if combos then for _, k in ipairs(KANA_COMBOS) do hira[#hira + 1] = k end end
  local out = {}
  if set ~= "kata" then for _, k in ipairs(hira) do out[#out + 1] = k end end
  if set ~= "hira" then for _, k in ipairs(hira) do out[#out + 1] = ns.ToKata(k) end end
  return out
end

function ns.IsKatakana(s)
  local c = decode(s:match("^[%z\1-\127\194-\244][\128-\191]*") or "")
  return c ~= nil and c >= 0x30A0 and c <= 0x30FF
end

-- Romaji as shown in the kana quiz (を is written wo even though it is said o).
local KANA_ROMA = { ["を"] = "wo", ["ヲ"] = "wo" }
function ns.KanaRomaji(k)
  return KANA_ROMA[k] or ns.ToRomaji(k)
end

-- Kana that are easy to mix up. Used as wrong answers, so the quiz trains the difference.
local SIMILAR_GROUPS = {
  "あお", "いり", "さちき", "ぬめ", "ねれわ", "るろ", "はほけ", "たな", "こい", "くへ", "うら", "まも",
  "シツ", "ソン", "クケタ", "ワウフ", "ヌスメ", "チテ", "コユ", "アマ", "ルレ", "セヤ", "ナメ", "シン",
}
local SIMILAR = {}
for _, g in ipairs(SIMILAR_GROUPS) do
  local chars = Split(g)
  for _, a in ipairs(chars) do
    SIMILAR[a] = SIMILAR[a] or {}
    for _, b in ipairs(chars) do if a ~= b then table.insert(SIMILAR[a], b) end end
  end
end
function ns.SimilarKana(k) return SIMILAR[k] or {} end

-- A short dictionary word that starts with this kana (nil if none).
function ns.KanaExample(prefix)
  local best, bestLen
  for k, e in pairs(ns.dict) do
    if not k:find("[# ]") and e.kana:sub(1, #prefix) == prefix then
      local n = #e.kana
      if n > #prefix and (not bestLen or n < bestLen or (n == bestLen and k < best)) then
        best, bestLen = k, n
      end
    end
  end
  return best
end
