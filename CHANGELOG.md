# Changelog

## 1.3
- Partyline-Befehle `.bistro add`, `.bistro del` und `.bistro rip` zum Bearbeiten der Liste
- Vor jeder Änderung wird eine Sicherung `*.bak` angelegt
- Encoding der Datei (Latin-1/UTF-8) bleibt beim Speichern erhalten

## 1.2
- Standard für `ircenc` ist jetzt leer (verhindert doppelt kodierte Umlaute wie „Ã¼")
- Leerzeichen am Ende der alten Topic werden vor dem Trenner entfernt

## 1.1
- Änderungen an der Liste wirken sofort, auch am selben Tag
- Zusatz wird entfernt, wenn der Eintrag aus der Liste gelöscht wird
- Punkt hinter dem Monat ist optional

## 1.0
- Erste Version: Geburtstage und Todestage im Topic, Wiederherstellung am Folgetag,
  Meldung in einem zweiten Channel, Zustand übersteht Neustarts
