# eggdrop-bistro-topic

Ein Eggdrop-Script, das an Geburtstagen und Todestagen einen Gruß an die Channel-Topic anhängt und am Folgetag die vorherige Topic wiederherstellt.

```
Willkommen im #irc-bistro | Das Bistro-Team wünscht Carol und Dave alles Gute zum Geburtstag!
Willkommen im #irc-bistro | R.I.P. Bob (Robert) - Todestag: 08.10.2021
```

Geschrieben für den Channel #irc-bistro im IRCnet, lässt sich aber für jeden Channel einstellen.

## Funktionen

- Hängt am Geburtstag bzw. Todestag ` | <Text>` an die bestehende Topic an und stellt die alte Topic am nächsten Tag wieder her.
- Mehrere Geburtstage am selben Tag werden zusammengefasst („Carol und Dave").
- Am Geburtstag Verstorbener kann ein Gedenktext erscheinen (abschaltbar).
- Geburtstage am 29.02. werden in Nicht-Schaltjahren am 28.02. gefeiert.
- Meldet das Setzen der Topic in einem zweiten Channel.
- Die Liste ist eine einfache Textdatei. Änderungen daran wirken sofort, ohne `.rehash`.
- Einträge lassen sich über die Partyline hinzufügen, entfernen und ändern.
- Ändert jemand die Topic zwischendurch von Hand, wird am Folgetag nur der Zusatz entfernt und die neue Topic bleibt erhalten.
- Der Zustand wird gespeichert und übersteht Neustarts des Bots.
- Ist der Bot kein Op, versucht er es jede Minute erneut.
- Liest Listen in UTF-8 und Latin-1 und erkennt das Format automatisch.

## Voraussetzungen

- Eggdrop 1.8 oder neuer (Tcl 8.5/8.6)
- Der Bot braucht Op oder Halfop im Channel, sofern dieser +t gesetzt hat.

## Installation

1. `bistro-topic.tcl` in das Verzeichnis `scripts/` des Eggdrops kopieren.
2. `Bistro-Geburtstage.example.txt` nach `scripts/Bistro-Geburtstage.txt` kopieren und mit den eigenen Einträgen füllen.
3. In der `eggdrop.conf` folgende Zeile ergänzen:
   ```
   source scripts/bistro-topic.tcl
   ```
4. In der Partyline `.rehash` ausführen.

## Datenformat

```
Name                TT.MM.[JJJJ]     [+ TT.MM.JJJJ]
Alice               03.01.
Bob (Robert)        07.01.           + 08.10.2021
Grace               15.03.1980
```

Alles vor dem ersten Datum ist der Name, er darf also Leerzeichen und Klammern enthalten. Das Geburtsjahr ist optional. Ein Todesdatum wird mit `+` angegeben. Zwischen den Spalten dürfen beliebig viele Leerzeichen oder Tabs stehen. Zeilen, die mit `#` beginnen, sowie Zeilen ohne Datum (etwa Überschriften) werden ignoriert.

## Einstellungen

Alle Einstellungen stehen oben im Script im Abschnitt `KONFIGURATION`.

| Variable | Standard | Bedeutung |
|---|---|---|
| `chan` | `#irc-bistro` | Channel, dessen Topic erweitert wird |
| `talkchan` | `#bistro-talk` | Channel für die Info-Meldung (`""` = keine) |
| `datafile` | `scripts/Bistro-Geburtstage.txt` | Pfad zur Liste |
| `statefile` | `scripts/bistro-topic.state` | Hier wird die alte Topic gespeichert |
| `fileenc` | `auto` | Zeichensatz der Liste: `auto`, `utf-8` oder `iso8859-1` |
| `ircenc` | `""` | Umwandlung für IRC. Nur auf `utf-8` stellen, wenn Umlaute kaputt ankommen |
| `sep` | `" \| "` | Trenner zwischen alter Topic und Zusatz |
| `maxlen` | `300` | Maximale Topic-Länge (TOPICLEN des Netzwerks) |
| `deadbday` | `1` | Gedenktext am Geburtstag Verstorbener (`0` = aus) |
| `txt_bday`, `txt_death`, `txt_deadbday`, `txt_talk`, `txt_restore` | | Die Texte, mit Platzhaltern `%names%`, `%name%`, `%date%`, `%years%`, `%chan%`, `%msg%` |

Umlaute in den Texten sollten als `\u00fc` usw. geschrieben werden, damit das Script unabhängig vom Zeichensatz der Datei funktioniert.

## Partyline-Befehle

Alle Befehle brauchen das Flag `+m`.

| Befehl | Wirkung |
|---|---|
| `.bistro` | Status und was heute ansteht |
| `.bistro test TT.MM.[JJJJ]` | Zeigt den Text für ein Datum, ohne etwas zu ändern |
| `.bistro list` | Alle eingelesenen Einträge |
| `.bistro add <Name> TT.MM.[JJJJ] [+ TT.MM.JJJJ]` | Eintrag hinzufügen (wird nach Datum einsortiert) |
| `.bistro del <Name>` | Eintrag entfernen (der erste Teil des Namens reicht) |
| `.bistro rip <Name> TT.MM.JJJJ` | Todesdatum setzen oder ändern, `-` statt Datum entfernt es |
| `.bistro check` | Prüfung sofort ausführen |
| `.bistro reload` | Liste neu einlesen |
| `.bistro reset` | Gespeicherten Zustand verwerfen (die Topic bleibt unverändert) |

Vor jeder Änderung durch `add`, `del` oder `rip` wird eine Sicherung `Bistro-Geburtstage.txt.bak` angelegt.

## Datenschutz

Die echte Liste enthält Nicknames, Geburtstage und teils Namen und Todesdaten realer Personen. Sie sollte deshalb nicht ins Repository. Die `.gitignore` schließt `Bistro-Geburtstage.txt`, Sicherungen und die Zustandsdatei aus. Im Repository liegt nur die Beispieldatei mit erfundenen Namen.

## Tests

Die Tests simulieren die Eggdrop-Befehle und brauchen nur `tclsh`:

```
tclsh tests/run.tcl
```

Auf GitHub laufen sie bei jedem Push automatisch (siehe `.github/workflows/test.yml`).

## Lizenz

MIT, siehe [LICENSE](LICENSE).
