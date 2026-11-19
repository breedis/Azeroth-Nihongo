# Azeroth Nihongo – projektanteckningar

Egna anteckningar om projektet (följer inte med i CurseForge-zippen).
Senast uppdaterad: 2026-11-18, version 1.9.1.

## Vad addonen är
WoW-addon för att öva japanska medan man spelar. Hovra över mobs, NPC:er, föremål,
spells m.m. och se namnet i kanji, kana och romaji, med kanji-uppdelning och uttal.
Hette tidigare **Japanese Hover** (bytt namn i 1.7.0).

## Mappar och filer
- Installerad i spelet: `<spelmapp>\_forever_\Interface\AddOns\AzerothNihongo`
- Sparad data: `<spelmapp>\_forever_\WTF\Account\<konto>\SavedVariables\AzerothNihongo.lua`
  (variabel `AzerothNihongoDB`).

| Fil | Innehåll |
|---|---|
| `AzerothNihongo.toc` | Interface-versioner, titel, version, laddordning |
| `Kana.lua` | Kana↔romaji, kanatabeller, look-alike-grupper för kanaquizet |
| `Dictionary*.lua` | Ordlistan (namn, föremål, betydelser per sammanhang) |
| `Furigana.lua` | Kanjiläsningar och uppdelning |
| `Core.lua` | Hover-tooltips, typsnitt, tal (TTS), JP-knappen, `/jp`-kommandon |
| `Options.lua` | Inställningssidan |
| `Quiz.lua` | Ordquiz, föremålsquiz, kanaquiz, övningslägen |
| `PopQuiz.lua` | Pop-up-quiz (timer, quest, level-up), avstängt i instanser som standard |
| `Lexicon.lua` | Lexikonfönstret: flikarna Kana, Kanji och My words |
| `Missing.lua` | Samlar ord utan översättning (`/jp missing`), sparas i `DB.missing` |
| `Strokes.lua` | Streckordning för alla kana + ordlistans 1165 kanji (från KanjiVG, CC BY-SA 3.0) |
| `Draw.lua` | Ritövningen (`/jp draw`): rita med musen, kontroll av varje streck |
| `Bindings.xml` | Tangentbindningar |
| `Fonts/` | IPA-typsnitt + licens |
| `build.ps1` | Bygger zip för CurseForge och kan installera i spelet |
| `.pkgmeta` | För BigWigs-packagern när det ligger på GitHub |
| `CURSEFORGE.md` | Texter att klistra in på CurseForge-sidan |

## Funktioner (kort)
- Hover-översättning med kanji, kana, romaji och kanji-uppdelning.
- Ord med flera betydelser väljs efter sammanhang (t.ex. Light Leather vs Holy Light).
- Quiz: ord, föremål, blandat, kana (hiragana/katakana/båda, dakuten, kombinationer).
  Fel svar i kanaquizet innehåller kana som liknar varandra (ぬ/め osv.).
- Upprepning med vikter: ord man svarat fel på kommer oftare.
- Pop-quiz kan fråga kana, vanligt quiz eller blandat; av i dungeons/raids/BG/arenor.
- Lexikon: kanatabell med ljud och färg efter resultat, kanjilista med läsningar och ord,
  "My words" med rätt/fel/oupptäckta, sök, sortering och övning.
- Uttal med Windows-rösten (Microsoft Haruka Desktop är den enda japanska rösten i Windows 10).

## Kommandon
`/jp` eller `/nihongo`, plus t.ex. `lex`, `kanatable`, `kanjilist`, `words`, `kanaquiz`
(`kq`), `ttsdebug`. `/jp` utan argument visar hjälpen.
Mittenklick eller Alt-klick på JP-knappen öppnar lexikonet.

## Bygga och installera
```powershell
powershell -ExecutionPolicy Bypass -File build.ps1
powershell -ExecutionPolicy Bypass -File build.ps1 -Install "<spelmapp>\_forever_"
```
Ger `publish\AzerothNihongo\` och `publish\AzerothNihongo-<version>.zip`.
Vid ny version: ändra `## Version` i `.toc`, skriv i `CHANGELOG.md`, bygg, testa i spelet.

## Testning
Lua 5.1 i Docker (`nickblah/lua:5.1`) med stubbar för WoW-API:t. Docker Desktop
måste vara igång. Layout, typsnitt och ljud kan bara testas i spelet.

## Ritövningen
- `Strokes.lua` byggs av skripten i `tools/` (se tools/README.txt) från KanjiVG-releasen: bara kana + kanji
  som finns i ordlistan. Läggs nya kanji till i ordlistan måste skriptet köras om
  (ladda ner KanjiVG main.zip, lista tecknen, kör conv.lua i Docker).
- Varje koordinat är ett tecken (91 nivåer i en 109x109-ruta).
- Kontrollen: form (efter att strecken flyttats ovanpå varandra), avstånd, längd,
  riktning och ordning. Toleranser i `TOL` i Draw.lua. Om det känns för strängt eller
  för snällt i spelet är det där man ändrar.
- Resultat sparas i `DB.write`.

## Lärdomar / fallgropar
- WoW:s vanliga tooltip-typsnitt kan inte visa kana → egna textfält med IPA-typsnittet.
- Typsnitten 2002.ttf och bLEI00D.ttf saknar kana (visar rutor) – borttagna.
- **Anropa aldrig `C_VoiceChat.StopSpeakingText`**: då kommer inget FINISHED-event och
  Blizzards talkö fastnar för alltid. Lösning: vänta tills ordet är klart, säg bara
  sista klicket, och byt till direkt `C_VoiceChat.SpeakText` om kön fastnar.
- Bara SAPI5 "Desktop"-röster syns i WoW.
- Zippen måste ha snedstreck framåt (`/`) i sökvägarna – därför bygger `build.ps1`
  med System.IO.Compression.

## Publicering
- CurseForge (inte gjort än): skapa projekt "Azeroth Nihongo", kategori Miscellaneous,
  licens MIT, ladda upp zippen från `publish\`. Texter finns i `CURSEFORGE.md`.
- GitHub: https://github.com/breedis/Azeroth-Nihongo. `.pkgmeta` är klar för BigWigs-packagern.
- Licens: MIT (se LICENSE.txt), typsnittet under IPA-licensen, streckdatan under CC BY-SA 3.0.

## Att göra / idéer
- Fylla på ordlistan: läs `missing` i SavedVariables-filen (efter utloggning) och lägg
  till orden i `Dictionary*.lua`. Orden försvinner då själva från listan.
- Testa i spelet: tal-fixen (1.6.1), lexikonets layout, kanaquizet.
- Trailer och skärmbilder: jag behöver klipp (OBS/Win+Alt+R, 1080p, 3–8 s per scen)
  och PNG-skärmdumpar (`/console screenshotFormat png`). Klipplista:
  hover mob → föremål med uppdelning → Light Leather/Holy Light → quiz rätt/fel →
  kanaquiz → pop-quiz efter quest → lexikon kana med ljud → kanji/My words → options.
- Möjligt tillägg: `/jp demo` som döljer chatten, fyller exempelprogress (och sparar
  den riktiga) och öppnar fönstren i tur och ordning, för enklare inspelning.
- Radera gamla `JapaneseHover`-mappen och `JapaneseHover.lua` i SavedVariables när
  allt funkar.
