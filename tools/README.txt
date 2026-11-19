Rebuilding Strokes.lua (only needed when kanji are added to the dictionary)

1. Download kanjivg-<date>-main.zip from https://github.com/KanjiVG/kanjivg/releases
   and unpack it so the SVG files are in <work>/kvg/kanji/.
2. In <work>, make a Lua file that stubs the WoW API and loads the addon's .lua files
   into a global `ns` (the test harness does this), then runs strokes_chars.lua.
   That writes <work>/chars.txt.
3. Run strokes_convert.lua. It reads /s/chars.txt and /s/kvg/kanji/*.svg and writes
   /a/Strokes.lua.

Paths are for Docker:
  docker run --rm -v "<work>:/s" -v "<addon folder>:/a" nickblah/lua:5.1 lua /s/<script>.lua
(on Git Bash, set MSYS_NO_PATHCONV=1 and pass Windows paths via cygpath -w).
