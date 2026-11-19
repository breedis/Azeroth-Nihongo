-- KanjiVG SVG -> compact stroke strings for Strokes.lua
local LEVELS = 90
local ALPHA = {}
for c = 35, 126 do if c ~= 92 then ALPHA[#ALPHA + 1] = string.char(c) end end
assert(#ALPHA == 91)
local function enc(v)
  local i = math.floor(v / 109 * LEVELS + 0.5)
  if i < 0 then i = 0 elseif i > LEVELS then i = LEVELS end
  return ALPHA[i + 1]
end
local function utf8char(c)
  if c < 0x800 then return string.char(0xC0 + math.floor(c/64), 0x80 + c%64) end
  return string.char(0xE0 + math.floor(c/4096), 0x80 + math.floor(c/64)%64, 0x80 + c%64)
end

local function parsePath(d)
  local toks = {}
  for cmd, args in d:gmatch("([MmCcSsLlZzHhVv])([^MmCcSsLlZzHhVv]*)") do
    local nums = {}
    for n in args:gmatch("[-+]?%d*%.?%d+") do nums[#nums + 1] = tonumber(n) end
    toks[#toks + 1] = { cmd, nums }
  end
  local pts = {}
  local x, y, sx, sy = 0, 0, 0, 0
  local lcx, lcy -- last control point for S
  local function add(px, py) pts[#pts + 1] = { px, py } end
  local function cubic(x1, y1, x2, y2, x3, y3)
    for i = 1, 10 do
      local t = i / 10; local u = 1 - t
      add(u*u*u*x + 3*u*u*t*x1 + 3*u*t*t*x2 + t*t*t*x3, u*u*u*y + 3*u*u*t*y1 + 3*u*t*t*y2 + t*t*t*y3)
    end
    lcx, lcy = x2, y2; x, y = x3, y3
  end
  for _, tk in ipairs(toks) do
    local c, n = tk[1], tk[2]
    local rel = c:lower() == c
    local C = c:upper()
    if C == "M" then
      local i = 1
      while i + 1 <= #n do
        if rel then x, y = x + n[i], y + n[i+1] else x, y = n[i], n[i+1] end
        if i == 1 then sx, sy = x, y end
        add(x, y); i = i + 2
      end
      lcx = nil
    elseif C == "L" then
      for i = 1, #n - 1, 2 do
        if rel then x, y = x + n[i], y + n[i+1] else x, y = n[i], n[i+1] end
        add(x, y)
      end
      lcx = nil
    elseif C == "H" then for i = 1, #n do x = rel and x + n[i] or n[i]; add(x, y) end; lcx = nil
    elseif C == "V" then for i = 1, #n do y = rel and y + n[i] or n[i]; add(x, y) end; lcx = nil
    elseif C == "C" then
      for i = 1, #n - 5, 6 do
        local ox, oy = rel and x or 0, rel and y or 0
        cubic(ox + n[i], oy + n[i+1], ox + n[i+2], oy + n[i+3], ox + n[i+4], oy + n[i+5])
      end
    elseif C == "S" then
      for i = 1, #n - 3, 4 do
        local ox, oy = rel and x or 0, rel and y or 0
        local x1, y1 = x, y
        if lcx then x1, y1 = 2*x - lcx, 2*y - lcy end
        cubic(x1, y1, ox + n[i], oy + n[i+1], ox + n[i+2], oy + n[i+3])
      end
    elseif C == "Z" then x, y = sx, sy; add(x, y); lcx = nil
    end
  end
  return pts
end

local function dp(pts, tol)
  if #pts <= 2 then return pts end
  local keep = { [1] = true, [#pts] = true }
  local function rec(a, b)
    local ax, ay, bx, by = pts[a][1], pts[a][2], pts[b][1], pts[b][2]
    local dx, dy = bx - ax, by - ay
    local L = math.sqrt(dx*dx + dy*dy)
    local best, bi = 0, nil
    for i = a + 1, b - 1 do
      local px, py = pts[i][1], pts[i][2]
      local d
      if L < 1e-6 then d = math.sqrt((px-ax)^2 + (py-ay)^2)
      else d = math.abs(dx*(ay-py) - dy*(ax-px)) / L end
      if d > best then best, bi = d, i end
    end
    if bi and best > tol then keep[bi] = true; rec(a, bi); rec(bi, b) end
  end
  rec(1, #pts)
  local out = {}
  for i = 1, #pts do if keep[i] then out[#out+1] = pts[i] end end
  return out
end

local out = { "-- Stroke order data for the writing practice.",
  "-- From KanjiVG (https://kanjivg.tagaini.net) by Ulrich Apel and contributors,",
  "-- licensed CC BY-SA 3.0 (https://creativecommons.org/licenses/by-sa/3.0/).",
  "-- Converted and simplified for Azeroth Nihongo; this file is under the same licence.",
  "-- Each entry: strokes separated by spaces, then \"!\" and the stroke number positions.",
  "-- Every coordinate is one character (see ns.DecodeStrokes in Draw.lua), 109x109 box.",
  "local _, ns = ...", "ns.STROKES = {" }
local total, nstrokes, npts = 0, 0, 0
for hex in io.lines("/s/chars.txt") do
  local f = assert(io.open("/s/kvg/kanji/" .. hex .. ".svg"))
  local svg = f:read("*a"); f:close()
  local strokes = {}
  for id, d in svg:gmatch('<path id="kvg:' .. hex .. '%-s(%d+)"[^>]-d="([^"]+)"') do
    strokes[#strokes + 1] = { tonumber(id), d }
  end
  table.sort(strokes, function(a, b) return a[1] < b[1] end)
  local nums = {}
  for x, y, n in svg:gmatch('<text transform="matrix%(1 0 0 1 ([%d%.%-]+) ([%d%.%-]+)%)">(%d+)</text>') do
    nums[tonumber(n)] = { tonumber(x) + 2.5, tonumber(y) - 3 }
  end
  local parts = {}
  for _, s in ipairs(strokes) do
    local pts = dp(parsePath(s[2]), 0.6)
    local enc1 = {}
    for _, p in ipairs(pts) do enc1[#enc1+1] = enc(p[1]) .. enc(p[2]) end
    -- drop repeated identical points after rounding
    local dedup, last = {}, nil
    for _, e in ipairs(enc1) do if e ~= last then dedup[#dedup+1] = e; last = e end end
    if #dedup == 1 then dedup[2] = dedup[1] end
    parts[#parts + 1] = table.concat(dedup)
    nstrokes = nstrokes + 1; npts = npts + #dedup
  end
  local ns = {}
  for i = 1, #strokes do
    local p = nums[i]
    if p then ns[#ns+1] = enc(p[1]) .. enc(p[2]) else ns[#ns+1] = parts[i]:sub(1, 2) end
  end
  out[#out + 1] = string.format('["%s"]="%s!%s",', utf8char(tonumber(hex, 16)), table.concat(parts, " "), table.concat(ns))
  total = total + 1
end
out[#out + 1] = "}"
local f = io.open("/a/Strokes.lua", "w"); f:write(table.concat(out, "\n"), "\n"); f:close()
print("chars", total, "strokes", nstrokes, "points", npts)
