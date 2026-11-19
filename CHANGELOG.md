# Changelog

## 1.10.0
- New signs are written first: when the quiz is about to ask a kana you have never
  met, the writing window opens next to it (trace mode) and the question comes once
  you have written it. "Skip" goes straight to the question. The same can be turned
  on for the kanji of new words. Both are in the options.
- Pop quiz can ask you to write: "Pop quiz asks" has a new choice, "Writing". It uses
  the set and mode of the writing window.
- Fixed the settings pages being empty the first time they were opened after login
  or /reload.

## 1.9.1
- Fixed kana showing as boxes on the quiz buttons, mostly in the first pop quiz after
  starting the game. The font is now loaded at login, the buttons keep it when they
  are shown or hovered, and the quiz draws its text again a moment after each question.

## 1.9.0
- Writing practice: draw kana and kanji with the mouse, stroke by stroke. The box
  shows the strokes in grey with a number where each one starts. Every stroke is
  checked for its place, shape, direction and order, with a message when it is off.
  - Modes: trace, hints only (just the start of the next stroke) and from memory
    (a hint after two misses).
  - "Show order" draws the strokes one by one.
  - Characters you miss come back more often.
  - `/jp draw`, `/jp draw hira|kata|kanji`, `/jp draw 狼`, `/jp draw wolf`, "Write page"
    on the kana chart and "Write" for a kanji in the lexicon.
  - Stroke data for all kana and the 1165 kanji in the dictionary, from KanjiVG
    (CC BY-SA 3.0).

## 1.8.0
- Untranslated words: words in names you hover that have no Japanese yet are saved.
  `/jp missing` (or the button in the options) lists them with how often you saw them
  and an example name, ready to copy. Words that get added later drop off the list.
  You get one note in chat when 25 new ones have piled up. Can be turned off.

## 1.7.0
- Renamed from Japanese Hover to Azeroth Nihongo. `/jp` still works, and `/nihongo` is new.
- If you used Japanese Hover: key bindings must be set again under Azeroth Nihongo,
  and the old JapaneseHover folder in Interface\AddOns can be deleted.

## 1.6.1
- Speech no longer goes silent when you click quickly: the voice is never cut off
  (that left WoW's speech queue stuck), a click during a word waits for it to finish,
  and quick clicks only say the last word.
- `/jp ttsdebug` prints what the speech system does, to help find problems.

## 1.6.0
- Kana quiz: hiragana, katakana or both, optional dakuten and combos. Wrong answers
  include kana that look alike.
- Pop quizzes can ask kana only, or kana mixed with the normal quiz.
- Lexicon kana chart: colours show your quiz results, and "Practise page" quizzes the
  kana on the page.

## 1.5.1
- Removed two game fonts (2002.ttf, bLEI00D.ttf) that have no Japanese kana.

## 1.5.0
- Lexicon window with three tabs:
  - Kana: a kana chart.
  - Kanji: every kanji with its readings and words.
  - My words: right, wrong and undiscovered words, with search, sorting and practice.
- The quiz remembers your last answer to each word and when you were asked.

## 1.4.1
- Option to skip pop quizzes in dungeons, raids, battlegrounds and arenas.

## 1.4.0
- Words with more than one meaning; the context picks the right one.
- Clearer item questions that show the item type.

## 1.3.0 and earlier
- Hover translation, kanji breakdown, quiz, pop quiz, text-to-speech, bundled Japanese font.
