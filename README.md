# Azeroth Nihongo

*日本語 (nihongo) = Japanese. Formerly called Japanese Hover.*

Learn Japanese while you play World of Warcraft. Hover over a monster, NPC, item or
spell and a small box next to the tooltip shows its name in Japanese:

```
狼   おおかみ   [ookami]   = wolf
```

Instead of turning the whole game Japanese, you pick up words one at a time from the
things you already look at. About 1,900 words cover the creatures, items, food,
materials, places and spells of the game.

## Features

- **Hover translation:** kanji, hiragana/katakana, romaji and the English meaning.
  Each part can be shown or hidden.
- **Kanji breakdown:** shows which kana each kanji is read as, e.g. 宿(やど) 屋(や).
- **Words with more than one meaning:** "Light Leather" gives 軽い (not heavy) and
  "Holy Light" gives 光 (brightness). The item type and the other words decide.
- **Quiz:**
  - dictionary words, words from random WoW items or from your bags, or kana;
  - Japanese → English or English → Japanese;
  - words you get wrong come back more often.
- **Kana quiz:**
  - hiragana, katakana or both, with or without dakuten and combos;
  - wrong answers include kana that look alike (ぬ/め, シ/ツ, ソ/ン) so you learn the difference.
- **Pop quiz:**
  - the quiz opens by itself on a timer, after quest turn-ins or on level up;
  - it can ask words, kana or both;
  - never in combat, and optionally never in dungeons, raids or battlegrounds.
- **Lexicon:**
  - a kana chart with notes and example words;
  - every kanji with its readings and words;
  - your words sorted into right, wrong and undiscovered, with practice for any list.
- **Writing practice:** draw kana and kanji with the mouse, stroke by stroke, like on a practice sheet: grey strokes with a number where each one starts. Every stroke is checked for its place, shape, direction and order. Trace, hints only or from memory (`/jp draw`, or "Write" in the lexicon). New kana are written once before the quiz first asks them, and pop quizzes can ask you to write.
- **Untranslated words:** names with words the dictionary does not know are noted, so they can be added later (`/jp missing`).
- **Pronunciation:** uses the Japanese text-to-speech voice in Windows, if you have one installed.

## Install

Copy the `AzerothNihongo` folder into `World of Warcraft\<version>\Interface\AddOns\`
(for example `_retail_`, `_classic_era_` or `_forever_`), then **start the game
again** completely. `/reload` does not load new font files.

Works in Retail, Classic Era, the other Classic versions and WoW Forever.

## How to use it

The **JP** button on screen:

| Click | Does |
|---|---|
| Left-click | turn the translation on or off |
| Right-click | quiz |
| Alt-click or middle-click | lexicon |
| Ctrl-click | options |
| Shift-drag | move the button |

You can set keys for all of this under Key Bindings → AddOns → Azeroth Nihongo.

## Commands

| Command | Does |
|---|---|
| `/jp` or `/nihongo` | on/off |
| `/jp kanji` · `kana` · `romaji` · `english` · `breakdown` | show/hide a part |
| `/jp all` | read every tooltip line, not just the name |
| `/jp shift` | only show while Shift is held |
| `/jp below` | put the box below the tooltip |
| `/jp size 18` | text size |
| `/jp font` | next font (if kanji show as boxes) |
| `/jp say` · `/jp voice` · `/jp speak` | say the hovered word · next voice · say words on hover |
| `/jp quiz` · `/jp kq` | quiz · kana quiz |
| `/jp pop` · `/jp pop on\|off\|status` | pop quiz now · the pop quiz timer |
| `/jp lex` · `/jp chart` · `/jp kanjilist` · `/jp words` | lexicon and its tabs |
| `/jp draw` · `/jp draw hira\|kata\|kanji` · `/jp draw 狼` · `/jp draw wolf` | writing practice |
| `/jp missing` | words you have seen that have no translation yet |
| `/jp button` | show/hide the JP button |
| `/jp config` | options |

## Pronunciation

The addon speaks through WoW's text-to-speech, which uses the voices installed in
Windows. To add a Japanese voice:

1. Go to Settings → Time & language → Speech → Add voices → Japanese.
2. Restart WoW.

## Adding words

Words are in `Dictionary.lua` and `Dictionary_Items.lua`, one line per word:

```lua
W("sword", "剣", "けん")         -- kanji + reading
W("murloc", nil, "マーロック")   -- kana only
```

Romaji is worked out from the kana. Words with several meanings are in
`Dictionary_Senses.lua`.

## License

The addon's code is MIT licensed (see `LICENSE.txt`). The bundled font
`Fonts/japanese.ttf` is IPA UI Gothic under the IPA Font License Agreement v1.0
(see `Fonts/IPA_Font_License_Agreement_v1.0.txt`).
The stroke order data in `Strokes.lua` comes from [KanjiVG](https://kanjivg.tagaini.net)
by Ulrich Apel and contributors, under CC BY-SA 3.0; that file is under the same license.
