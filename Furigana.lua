-- Kanji breakdown: works out which part of the kana reading belongs to which kanji,
-- e.g. 宿屋 (やどや) -> 宿=やど 屋=や, 味付けした -> 味=あじ 付=つ + けした.
-- Uses a seed list of common kanji readings and learns more from the dictionary itself.
local _, ns = ...

local function Chars(s)
  local t = {}
  for ch in s:gmatch("[%z\1-\127\194-\244][\128-\191]*") do t[#t + 1] = ch end
  return t
end

local function CP(ch)
  local b1, b2, b3 = ch:byte(1, 3)
  if b1 and b3 and b1 >= 0xE0 and b1 <= 0xEF then
    return (b1 - 0xE0) * 4096 + (b2 - 0x80) * 64 + (b3 - 0x80)
  end
end

local function Enc(c)
  return string.char(0xE0 + math.floor(c / 4096), 0x80 + math.floor(c / 64) % 64, 0x80 + c % 64)
end

local function IsKana(ch)
  local c = CP(ch)
  return c and ((c >= 0x3041 and c <= 0x309F) or (c >= 0x30A0 and c <= 0x30FF)) or false
end

local function ToHira(ch)
  local c = CP(ch)
  if c and c >= 0x30A1 and c <= 0x30F6 then return Enc(c - 0x60) end
  return ch
end

-- Common readings (on'yomi and kun'yomi stems).
local SEED = [[
大:だい,おお,たい;小:しょう,こ,ちい,お;人:じん,にん,ひと,と;子:こ,し,す;山:やま,さん,ざん;水:みず,すい;
火:ひ,か,び;金:きん,かね,こん;木:き,もく,ぼく,こ;石:いし,せき,しゃく;土:つち,ど,と;日:ひ,にち,じつ,び,か;
月:つき,げつ,がつ;王:おう;魔:ま;法:ほう;術:じゅつ;師:し;者:しゃ,もの;物:もの,ぶつ,もつ;生:せい,い,なま,う,しょう;
死:し;聖:せい;神:かみ,しん,じん;霊:れい;天:てん;地:ち,じ;海:うみ,かい;森:もり,しん;道:みち,どう;具:ぐ;
長:ちょう,なが;中:ちゅう,なか;上:じょう,うえ,うわ;下:か,した,げ;前:ぜん,まえ;後:ご,こう,うし,あと;手:て,しゅ;
足:あし,そく;目:め,もく;口:くち,こう;心:こころ,しん;力:ちから,りょく,りき;気:き;年:ねん,とし;時:じ,とき;
間:かん,ま,あいだ;分:ふん,ぶん;本:ほん,もと;国:こく,くに;家:か,いえ,け,や;場:じょう,ば;所:しょ,ところ,じょ;
院:いん;堂:どう;館:かん;室:しつ;屋:や,おく;店:てん,みせ;品:ひん,しな;鉄:てつ;銀:ぎん;銅:どう;宝:ほう,たから;
戦:せん,たたか;士:し;兵:へい;騎:き;鬼:き,おに;竜:りゅう;獣:じゅう,けもの;鳥:ちょう,とり;魚:ぎょ,さかな,うお;
肉:にく;草:そう,くさ;花:か,はな;葉:よう,は;根:こん,ね;樹:じゅ;林:りん,はやし;光:こう,ひかり,ひか;闇:あん,やみ;
影:えい,かげ;風:ふう,かぜ;雷:らい,かみなり;氷:ひょう,こおり;炎:えん,ほのお;毒:どく;薬:やく,くすり;酒:しゅ,さけ,さか;
茶:ちゃ;食:しょく,た;料:りょう;理:り;学:がく;校:こう;書:しょ,か;図:ず,と;記:き;文:ぶん,もん;字:じ;
語:ご;言:げん,こと;色:しょく,いろ;白:はく,しろ;黒:こく,くろ;赤:せき,あか;青:せい,あお;緑:りょく,みどり;
紫:し,むらさき;黄:き,おう;灰:かい,はい;毛:もう,け;皮:ひ,かわ;革:かく,かわ;骨:こつ,ほね;血:けつ,ち;
体:たい,からだ;頭:とう,あたま,ず;首:しゅ,くび;腕:わん,うで;胸:きょう,むね;背:はい,せ;腰:よう,こし;歯:し,は;
爪:つめ;角:かく,つの;羽:う,はね,は;翼:よく,つばさ;古:こ,ふる;新:しん,あたら;高:こう,たか;低:てい,ひく;
強:きょう,つよ;弱:じゃく,よわ;重:じゅう,おも;軽:けい,かる;深:しん,ふか;速:そく,はや;守:しゅ,まも;護:ご;
破:は,やぶ;壊:かい,こわ;防:ぼう,ふせ;衛:えい;攻:こう;撃:げき;剣:けん;弓:きゅう,ゆみ;矢:し,や;槍:そう,やり;
盾:じゅん,たて;鎧:がい,よろい;布:ふ,ぬの;糸:し,いと;針:しん,はり;箱:はこ;袋:たい,ふくろ;瓶:びん;
薄:はく,うす;厚:こう,あつ;熱:ねつ,あつ;冷:れい,つめ,ひ;寒:かん,さむ;暗:あん,くら;明:めい,あか,みょう;美:び,うつく;
悪:あく,わる;善:ぜん;正:せい,しょう,ただ;義:ぎ;真:しん,ま;実:じつ,み;夜:や,よる,よ;朝:ちょう,あさ;夕:ゆう;
星:せい,ほし;空:くう,そら,から;雲:うん,くも;雪:せつ,ゆき;雨:う,あめ;川:せん,かわ;湖:こ,みずうみ;島:とう,しま;
谷:こく,たに;岩:がん,いわ;砂:さ,すな,しゃ;泥:でい,どろ;村:そん,むら;町:ちょう,まち;市:し,いち;城:じょう,しろ;
塔:とう;門:もん;橋:きょう,はし;港:こう,みなと;墓:ぼ,はか;遺:い;跡:せき,あと;牢:ろう;獄:ごく;帝:てい;皇:こう,おう;
女:じょ,おんな,め;男:だん,おとこ;父:ふ,ちち;母:ぼ,はは;兄:きょう,けい,あに;弟:てい,だい,おとうと,で;姉:し,あね;
妹:まい,いもうと;友:ゆう,とも;敵:てき;主:しゅ,ぬし;族:ぞく;民:みん;商:しょう;職:しょく;工:こう;鍛:たん,きた;
冶:や;採:さい;掘:くつ;裁:さい;縫:ほう,ぬ;錬:れん;細:さい,ほそ;復:ふく;回:かい;治:ち,じ;療:りょう;癒:ゆ,いや;
召:しょう,め;喚:かん;瞬:しゅん;移:い;動:どう,うご;運:うん;命:めい,いのち;魂:こん,たましい;精:せい;髄:ずい;
怒:ど,いか,おこ;恐:きょう,おそ;怖:ふ;希:き;望:ぼう,のぞ;勇:ゆう;英:えい;雄:ゆう,お;栄:えい;誉:よ;名:めい,な;
祝:しゅく;福:ふく;祈:き,いの;呪:じゅ,のろ;封:ふう;印:いん,しるし;儀:ぎ;式:しき;秘:ひ;密:みつ;静:せい,しず;
寂:じゃく;調:ちょう;和:わ;均:きん;衡:こう;絶:ぜつ;苦:く,くる,にが;痛:つう,いた;悲:ひ,かな;幸:こう,しあわ;
夢:む,ゆめ;犬:けん,いぬ;猫:びょう,ねこ;馬:ば,うま;牛:ぎゅう,うし;豚:とん,ぶた;羊:よう,ひつじ;鶏:けい,にわとり;
鹿:しか;熊:くま;狼:おおかみ;狐:きつね;虎:とら;猿:さる;鼠:ねずみ;兎:うさぎ;亀:かめ;蟹:かに;蛇:じゃ,へび;
麦:ばく,むぎ;米:べい,こめ;豆:とう,まめ;芽:が,め;粉:ふん,こな;塩:えん,しお;糖:とう;油:ゆ,あぶら;蜜:みつ;果:か;
菜:さい,な;野:や,の;原:げん,はら;平:へい,たい,ひら;半:はん;一:いち,ひと,いっ;二:に,ふた;三:さん,み;四:し,よん,よ;
五:ご;六:ろく;七:しち,なな;八:はち;九:きゅう,く;十:じゅう;百:ひゃく;千:せん;万:まん;鍵:かぎ;包:ほう;帯:たい,おび;
製:せい;造:ぞう;作:さく,さ,つく;用:よう;器:き;機:き;装:そう;備:び;武:ぶ;置:ち;部:ぶ;車:しゃ,くるま;
船:せん,ふね;舟:しゅう,ふね;荷:か,に;貨:か;積:せき,つ;宴:えん,うたげ;杯:はい,さかずき;鍋:なべ;皿:さら;鉢:はち;
桶:おけ;壺:つぼ;籠:かご,こ;鞍:くら;鞭:むち;網:もう,あみ;竿:さお;釣:ちょう,つ;餌:じ,えさ;西:せい,さい,にし;
東:とう,ひがし;南:なん,みなみ;北:ほく,きた;付:ふ,つ;味:み,あじ;入:にゅう,い,はい;出:しゅつ,で,だ;切:せつ,き;
焼:しょう,や;干:かん,ほ;漬:つ;刻:こく,きざ;潰:かい,つぶ;砕:さい,くだ;割:かつ,わ;燃:ねん,も;凍:とう,こお;
腐:ふ,くさ;壊:かい,こわ;曲:きょく,ま;磨:ま,みが;彫:ちょう,ほ;織:しょく,お;編:へん,あ;紡:ぼう,つむ;縫:ほう,ぬ;
飾:しょく,かざ;詰:きつ,つ;強:きょう,つよ;化:か,け;印:いん;刷:さつ;使:し,つか;唱:しょう,とな;集:しゅう,あつ;
見:けん,み;知:ち,し;探:たん,さが;求:きゅう,もと;監:かん;視:し;番:ばん;守:しゅ,まも;殺:さつ,ころ;屋:や;
飲:いん,の;着:ちゃく,き;服:ふく;衣:い,ころも;帽:ぼう;靴:か,くつ;指:し,ゆび;輪:りん,わ;冠:かん,かんむり;
肩:けん,かた;脛:けい,すね;当:とう,あ;甲:こう;鎖:さ,くさり;帷:い,かたびら;板:はん,ばん,いた;盤:ばん;
長:ちょう,なが;短:たん,みじか;投:とう,な;擲:てき;斧:ふ,おの;槌:つい,つち;杖:じょう,つえ;刀:とう,かたな;
鎌:れん,かま;棒:ぼう;拳:けん,こぶし;筒:とう,つつ,づつ;証:しょう,あかし;紋:もん;章:しょう;像:ぞう;偶:ぐう;
典:てん;報:ほう;告:こく;契:けい;約:やく;設:せつ;計:けい;帳:ちょう;簿:ぼ;写:しゃ;導:どう;詩:し;歌:か,うた;
語:ご,がた;伝:でん,つた;説:せつ;歴:れき;史:し;承:しょう;資:し;貨:か;見:けん,み;標:ひょう;体:たい;骸:がい;
残:ざん,のこ;呪:じゅ;形:けい,ぎょう,かた;操:そう,あやつ;碑:ひ;柱:ちゅう,はしら;祭:さい,まつ;壇:だん;鉢:はち;
床:しょう,とこ,ゆか;炉:ろ;噴:ふん;池:ち,いけ;湾:わん;江:こう,え;波:は,なみ;止:し,と;桟:さん;灯:とう,ひ;
台:だい,たい;粉:ふん,こな;挽:ばん,ひ;風:ふう,かぜ,ふ;尖:せん;哨:しょう;拠:きょ;隊:たい;域:いき;避:ひ;難:なん;
息:そく,いき;立:りつ,た,だち;空:くう,あ,から;牧:ぼく;草:そう;平:へい;荒:こう,あ,あら;凍:とう;峠:とうげ;
尾:び,お;根:こん,ね;渓:けい;峡:きょう;裂:れつ,さ;淵:えん;窪:わ,くぼ;頂:ちょう;丘:きゅう,おか;下:げ,か,した;
水:すい,みず;道:どう;採:さい;材:ざい;製:せい;果:か;樹:じゅ;園:えん;修:しゅう;院:いん;闘:とう;技:ぎ;宮:きゅう;
殿:でん;敷:しき;室:しつ;民:みん;難:なん;孤:こ;児:じ;未:み;亡:ぼう;祖:そ;叔:しゅく;指:し;揮:き;官:かん;
副:ふく;軍:ぐん;曹:そう;帥:すい;爵:しゃく;公:こう;伯:はく;督:とく;親:しん,おや;方:ほう,かた;信:しん;狂:きょう,くる;
暗:あん;略:りゃく;奪:だつ;猟:りょう;輸:ゆ;囚:しゅう;熟:じゅく;練:れん;古:こ;参:さん;追:つい,お;剥:は;傭:よう;
剣:けん;闘:とう;蛮:ばん;遊:ゆう;牧:ぼく;巡:じゅん;礼:れい;賢:けん;預:よ;託:たく;司:し;教:きょう,おし;尼:に;僧:そう;
喚:かん;錬:れん;技:ぎ;仕:し;立:た;宝:ほう;石:せき;商:しょう;大:だい;工:く;肉:にく;銀:ぎん;行:こう,い;員:いん;
看:かん;歩:ほ,ある;哨:しょう;張:は;元:げん;帥:すい;
応:おう;急:きゅう;当:とう,あ,あて;冒:ぼう;険:けん;競:きょう;売:ばい,う;郵:ゆう;便:びん,べん;受:じゅ,う;
]]

local READ = {}       -- kanji -> { reading = true }
local VARIANTS = {}   -- kanji -> { variant = true } (cache)

local VOICED = {
  ["か"]="が",["き"]="ぎ",["く"]="ぐ",["け"]="げ",["こ"]="ご",["さ"]="ざ",["し"]="じ",["す"]="ず",["せ"]="ぜ",["そ"]="ぞ",
  ["た"]="だ",["ち"]="ぢ",["つ"]="づ",["て"]="で",["と"]="ど",["は"]="ば",["ひ"]="び",["ふ"]="ぶ",["へ"]="べ",["ほ"]="ぼ",
}
local SEMI = { ["は"]="ぱ",["ひ"]="ぴ",["ふ"]="ぷ",["へ"]="ぺ",["ほ"]="ぽ" }
local GEMINATE = { ["つ"]=true, ["く"]=true, ["ち"]=true, ["き"]=true }

local function AddReading(k, r)
  READ[k] = READ[k] or {}
  if not READ[k][r] then
    READ[k][r] = true
    VARIANTS[k] = nil
    return true
  end
end

for entry in SEED:gmatch("[^;\n]+") do
  local k, list = entry:match("^%s*([^:]+):(.+)$")
  if k then
    for r in list:gmatch("[^,%s]+") do AddReading(k, r) end
  end
end

local function Variants(k)
  if VARIANTS[k] then return VARIANTS[k] end
  local set = {}
  for r in pairs(READ[k] or {}) do
    set[r] = true
    local c = Chars(r)
    local first, rest = c[1], table.concat(c, "", 2)
    local firsts = { first }
    if VOICED[first] then firsts[#firsts + 1] = VOICED[first] end
    if SEMI[first] then firsts[#firsts + 1] = SEMI[first] end
    for _, f in ipairs(firsts) do
      set[f .. rest] = true
      if #c > 1 and GEMINATE[c[#c]] then
        set[f .. table.concat(c, "", 2, #c - 1) .. "っ"] = true
      end
    end
  end
  VARIANTS[k] = set
  return set
end

-- true = known reading matches, false = known kanji but no match, nil = kanji unknown
local function Fits(k, part)
  if not READ[k] then return nil end
  return Variants(k)[part] and true or false
end

-- Splits the reading of a run of kanji into one part per kanji.
local function SplitRun(kchars, rchars, learn)
  local n = #kchars
  if n == 1 then return { table.concat(rchars) } end
  local best, bestMiss, count = nil, 99, 0
  local parts = {}
  local function rec(ki, ri, miss)
    if miss > 1 or miss > bestMiss then return end
    if ki > n then
      if ri > #rchars then
        if miss < bestMiss then best, bestMiss, count = { unpack(parts) }, miss, 1
        elseif miss == bestMiss then count = count + 1 end
      end
      return
    end
    local left = n - ki
    for len = 1, math.min(4, #rchars - ri + 1 - left) do
      local part = table.concat(rchars, "", ri, ri + len - 1)
      parts[ki] = part
      rec(ki + 1, ri + len, miss + (Fits(kchars[ki], part) and 0 or 1))
    end
  end
  rec(1, 1, 0)
  if best and count == 1 then
    if learn and bestMiss > 0 then
      for i, k in ipairs(kchars) do
        if not Fits(k, best[i]) then AddReading(k, best[i]) end
      end
    end
    return best
  end
end

-- Lines up the written form with the reading: kana in the written form must match the
-- reading exactly, each run of kanji takes what is left in between.
local function Align(written, reading)
  local runs = {}
  for _, ch in ipairs(Chars(written)) do
    local kana = IsKana(ch)
    local last = runs[#runs]
    if last and last.kana == kana then
      last.chars[#last.chars + 1] = ch
    else
      runs[#runs + 1] = { kana = kana, chars = { ch } }
    end
  end
  local rd = {}
  for _, ch in ipairs(Chars(reading)) do rd[#rd + 1] = ToHira(ch) end

  local spans = {}
  local function rec(i, ri)
    if i > #runs then return ri > #rd end
    local run = runs[i]
    if run.kana then
      for j, ch in ipairs(run.chars) do
        if rd[ri + j - 1] ~= ToHira(ch) then return false end
      end
      return rec(i + 1, ri + #run.chars)
    end
    for len = 1, #rd - ri + 1 do
      if rec(i + 1, ri + len) then
        spans[i] = { ri, ri + len - 1 }
        return true
      end
    end
    return false
  end
  if not rec(1, 1) then return nil end
  for i, run in ipairs(runs) do
    if not run.kana then
      local s = spans[i]
      run.rchars = {}
      for j = s[1], s[2] do run.rchars[#run.rchars + 1] = rd[j] end
    end
  end
  return runs
end

local cache = {}
local built = false

local function Segments(e, learn)
  local runs = Align(e.kanji, e.kana)
  if not runs then return nil end
  local segs = {}
  for _, run in ipairs(runs) do
    if run.kana then
      segs[#segs + 1] = { text = table.concat(run.chars) }
    else
      local split = SplitRun(run.chars, run.rchars, learn)
      if split then
        for i, k in ipairs(run.chars) do segs[#segs + 1] = { text = k, reading = split[i] } end
        if learn and #run.chars == 1 then AddReading(run.chars[1], split[1]) end
      else
        segs[#segs + 1] = { text = table.concat(run.chars), reading = table.concat(run.rchars), whole = true }
      end
    end
  end
  return segs
end

local function Build()
  built = true
  -- A few passes so readings learned from one word help split the next.
  for _ = 1, 3 do
    for _, e in pairs(ns.dict) do
      if e.kanji then Segments(e, true) end
    end
  end
end

-- Returns a list of { text, reading } segments, or nil when there is nothing to show.
function ns.Breakdown(key)
  local e = ns.dict[key]
  if not e or not e.kanji then return nil end
  if cache[key] ~= nil then return cache[key] or nil end
  if not built then Build() end
  local segs = Segments(e, false)
  -- Only worth showing for more than one kanji, or kanji mixed with kana.
  if segs and #segs < 2 then segs = nil end
  cache[key] = segs or false
  return segs
end

-- Known readings of one kanji (from the seed list and learned from the dictionary).
function ns.KanjiReadings(k)
  if not built then Build() end
  local out = {}
  for r in pairs(READ[k] or {}) do out[#out + 1] = r end
  table.sort(out, function(a, b)
    if #a ~= #b then return #a < #b end
    return a < b
  end)
  return out
end

-- The kanji (non-kana characters above U+3000) in a written word, in order, no repeats.
function ns.KanjiIn(s)
  local out, seen = {}, {}
  for _, ch in ipairs(Chars(s or "")) do
    local c = CP(ch)
    if c and c >= 0x3400 and not IsKana(ch) and not seen[ch] then
      seen[ch] = true
      out[#out + 1] = ch
    end
  end
  return out
end

-- "宿(やど) 屋(や)" style text with colours.
function ns.BreakdownText(key)
  local segs = ns.Breakdown(key)
  if not segs then return nil end
  local out = {}
  for _, s in ipairs(segs) do
    if s.reading then
      out[#out + 1] = "|cffffffff" .. s.text .. "|r|cff7fd4ff(" .. s.reading .. ")|r"
    else
      out[#out + 1] = "|cffffd100" .. s.text .. "|r"
    end
  end
  return table.concat(out, " ")
end
