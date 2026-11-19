-- Lists the characters Strokes.lua needs: every kanji in the dictionary plus all kana.
-- Writes chars.txt (5-digit hex codepoints, the KanjiVG file names).
-- Run from a folder that has a stub WoW environment loading the addon as `ns`
-- (see tools/README.txt).
local function cp(s)
  local a, b, c = s:byte(1, 3)
  return (a - 0xE0) * 4096 + (b - 0x80) * 64 + (c - 0x80)
end
local set = {}
for _, e in pairs(ns.dict) do
  if e.kanji then for _, ch in ipairs(ns.KanjiIn(e.kanji)) do set[ch] = true end end
end
local list = {}
for ch in pairs(set) do list[#list + 1] = string.format("%05x", cp(ch)) end
for c = 0x3041, 0x3096 do list[#list + 1] = string.format("%05x", c) end
for c = 0x30A1, 0x30FA do list[#list + 1] = string.format("%05x", c) end
list[#list + 1] = "030fc"
table.sort(list)
local f = io.open("/s/chars.txt", "w"); f:write(table.concat(list, "\n"), "\n"); f:close()
print("characters", #list)
