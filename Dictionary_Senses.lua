-- English words with more than one meaning. Each meaning gets its own Japanese word
-- and a label that says which meaning it is. Context words (from the item name, the
-- item type or the other tooltip lines) decide which meaning is used.
--
-- Base("word", "label", "context words")  -- the usual meaning (already in the dictionary)
-- Sense("word", n, "label", kanji, kana, "context words")  -- another meaning
local _, ns = ...
local D = ns.dict

local function Set(words)
  local t = {}
  for w in (words or ""):gmatch("%S+") do t[w] = true end
  return t
end

local function Base(en, label, ctx)
  local e = D[en]
  e.label = label
  e.ctx = Set(ctx)
  e.senses = e.senses or { en }
end

local function Sense(en, n, label, kanji, kana, ctx)
  local key = en .. "#" .. n
  D[key] = { kanji = kanji, kana = kana, label = label, base = en, ctx = Set(ctx) }
  local base = D[en]
  base.senses = base.senses or { en }
  base.senses[#base.senses + 1] = key
end

Base("light", "light (brightness)", "holy flash heal healing beam lantern sun bright shine radiant")
Sense("light", 2, "light (not heavy)", "軽い", "かるい",
  "leather hide armor cloth mail shot arrow bullet boots boot gloves glove belt vest pants shirt robe tunic feather projectile quiver pouch")

Base("shot", "shot (shooting)", "aimed arcane multi multishot hunter ability")
Sense("shot", 2, "shot (ammunition)", "弾", "たま", "projectile bullet ammo ammunition light heavy solid accurate crude")

Base("spring", "spring (water source)", "water")
Sense("spring", 2, "spring (season)", "春", "はる", "season summer winter autumn festival blossom flower")
Sense("spring", 3, "spring (metal coil)", nil, "ばね", "gear gizmo device mechanical engineering bronze steel coil")

Base("bar", "bar (metal ingot)", "copper tin bronze iron steel silver gold mithril thorium truesilver arcanite metal")
Sense("bar", 2, "bar (pub)", "酒場", "さかば", "tavern drink ale beer barkeep bartender")

Base("seal", "seal (magic seal / stamp)", "of ward magic wax")
Sense("seal", 2, "seal (the animal)", nil, "アザラシ", "pup flipper blubber beast fur pelt")

Base("hide", "hide (animal skin)", "leather light medium heavy thick rugged skinning tanned cured")
Sense("hide", 2, "hide (to conceal)", "隠す", "かくす", "stealth shadow behind away quickly yourself")

Base("ring", "ring (finger ring)", "finger band gold silver")
Sense("ring", 2, "ring (circle)", "輪", "わ", "frost fire flame ice stone circle")

Base("chest", "chest (body part)", "armor plate mail leather cloth")
Sense("chest", 2, "chest (box)", "宝箱", "たからばこ", "battered solid sturdy locked treasure footlocker strongbox box trunk")

Base("mail", "mail (chain armor)", "chain armor plate scale")
Sense("mail", 2, "mail (letters)", "郵便", "ゆうびん", "letter send post mailbox inbox package parcel")

Base("plate", "plate (plate armor)", "armor mail chain breastplate gauntlet helm")
Sense("plate", 2, "plate (dish)", "皿", "さら", "food dish meal dinner fork spoon cooking")

Base("bolt", "bolt (roll of cloth)", "cloth linen wool woolen silk mageweave runecloth felcloth tailoring")
Sense("bolt", 2, "bolt (metal fastener)", nil, "ボルト", "copper bronze iron steel mithril thorium handful engineering")
Sense("bolt", 3, "bolt (magic missile)", "矢", "や", "frost fire shadow arcane chaos holy lightning spell")

Base("bark", "bark (of a tree)", "tree wood oak willow ironwood")
Sense("bark", 2, "bark (dog sound)", "吠える", "ほえる", "dog hound howl growl")

Base("shell", "shell (sea shell)", "sea clam crab turtle beach")
Sense("shell", 2, "shell (ammunition)", "砲弾", "ほうだん", "gun cannon explosive ammo")

Base("band", "band (finger ring)", "finger gold silver ring")
Sense("band", 2, "band (group of people)", "一団", "いちだん", "bandit mercenary outlaw brother member")

Base("spirit", "spirit (ghost)", "ghost undead restless wisp")
Sense("spirit", 2, "spirit (mind / stat)", "精神", "せいしん", "increase intellect stamina strength agility regeneration armor weapon")

Base("fly", "fly (to fly)", "wing wings sky air")
Sense("fly", 2, "fly (insect)", "蠅", "はえ", "swarm insect bug buzzing maggot")

Base("count", "count (noble title)", "lord baron duke noble")
Sense("count", 2, "count (to count)", "数える", "かぞえる", "number time many")

Base("mine", "mine (place to dig)", "ore copper iron gold silver mining tunnel")
Sense("mine", 2, "mine (belongs to me)", "私の", "わたしの", "is it that this")

Base("sage", "sage (wise person)", "wise old elder")
Sense("sage", 2, "sage (herb)", nil, "セージ", "herb mountain silversage leaf")

Base("lead", "lead (metal)", "leaded metal ore")
Sense("lead", 2, "lead (to guide)", "導く", "みちびく", "to way army us")

Base("kind", "kind (friendly)", "friendly gentle")
Sense("kind", 2, "kind (type)", "種類", "しゅるい", "of this that")

Base("tear", "tear (from crying)", "cry crying sorrow eye")
Sense("tear", 2, "tear (to rip)", "裂く", "さく", "flesh apart rip")

Base("fine", "fine (high quality)", "thread cloth leather")
Base("staff", "staff (weapon)", "weapon wooden quarterstaff mage")
Base("bow", "bow (weapon)", "arrow ranged weapon")
Base("cast", "cast (a spell)", "spell")
Base("wing", "wing", "")

-- Picks the meaning that fits the context. ctx is a set of lowercase words.
-- Returns the dictionary key and whether the meaning is certain.
function ns.ResolveSense(key, ctx)
  local e = D[key]
  if not e or not e.senses then return key, true end
  if ctx then
    for i = 2, #e.senses do
      for w in pairs(D[e.senses[i]].ctx) do
        if ctx[w] then return e.senses[i], true end
      end
    end
    for w in pairs(e.ctx or {}) do
      if ctx[w] then return key, true end
    end
  end
  if #e.senses == 1 then return key, true end
  return key, false
end

-- The other meanings of the same English word.
function ns.OtherSenses(key)
  local e = D[key]
  local base = D[e.base or key]
  local out = {}
  if base.senses then
    for _, k in ipairs(base.senses) do
      if k ~= key then out[#out + 1] = k end
    end
  end
  return out
end

function ns.Label(key)
  local e = D[key]
  return e and e.label or key
end

-- Which English word a key belongs to (light#2 -> light).
function ns.Group(key)
  local e = D[key]
  return e and e.base or key
end

-- Builds a context set from one or more texts.
function ns.Context(...)
  local ctx = {}
  for i = 1, select("#", ...) do
    local s = select(i, ...)
    if type(s) == "string" then
      for w in s:lower():gmatch("%a+") do
        ctx[w] = true
        if #w > 3 and w:sub(-1) == "s" then ctx[w:sub(1, -2)] = true end
      end
    end
  end
  return ctx
end
