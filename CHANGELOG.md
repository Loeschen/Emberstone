# Changelog

## 1.13 (Beta)

- Neu: Glitzern (Optionen → Emberstone → Glitzern).
  - Quest-Gegenstände und Beute glitzern (ab Werk an). Emberstone schaltet dafür die Umriss-Darstellung aus und setzt die Werte beim Login, nach Grafikänderungen und nach einem Grafik-Neustart erneut. Im Kampf wird nichts geändert, sondern direkt danach. Beim Ausschalten kommen die vorherigen Werte zurück.
  - Kräuter, Erzadern und Questobjekte glitzern beim Näherkommen (ab Werk aus, drei Schalter). Eigene Glitzer-Grafik, schwach außer Reichweite, hell in Reichweite, grau ohne passenden Beruf. Über das Soft Targeting des Spiels, im Kampf aus. Die vorherigen Zielauswahl-Einstellungen kommen zurück, sobald alle drei Schalter aus sind.
  - Ist ForeverLootSparkles oder Lueur geladen, bleibt das Glitzern aus; die Optionen zeigen einen Hinweis.
- Neu: `/emberstone sparkle` (Status) und `/emberstone sparkle debug` (Erkennung am ausgewählten Objekt).
- Behoben (Forever-Test): Kräuter und Erzadern wurden nicht erkannt, weil das Spiel ausgewählte Spielobjekte nicht als „vorhanden“ meldet. Emberstone findet das Objekt jetzt wie Blizzards eigene Anzeige über dessen Namensplakette. `/emberstone sparkle debug` zeigt dazu mehr Angaben.
- Neues Aussehen (Forever-Test): ein einzelnes, großes, weich pulsierendes Leuchten (heller Kern, weicher Schein, feine Lichtstrahlen, additiv überblendet), tiefer am Objekt. Fünf Farben zur Auswahl unter Optionen → Glitzern (mit pulsierender Vorschau) oder per `/emberstone sparkle style`: Gold (Standard), Grün, Arkanblau, Weiß, Violett. Grafiken selbst erstellt; hell, schwach und grau gelten für alle Farben.
- Blizzards schwebendes Symbol wird ausgeblendet (`SoftTargetNameplateSize` 0, alter Wert gespeichert). Legt das Spiel ohne Symbol keine Markierung an, stellt Emberstone den alten Wert selbst wieder her, zeigt die Funken unter dem Symbol und meldet das einmal im Chat. `/emberstone sparkle debug` zeigt, welche Darstellung aktiv ist, `/emberstone sparkle retry` versucht es erneut.
- Konsolenvariablen, die der Client nicht kennt, werden übersprungen.
- Tests ergänzt; ein Test aus 1.12 hing von der Uhrzeit ab und ist jetzt stabil.

## 1.12 (Beta)

- Neu: Minimap-Symbol. Linksklick öffnet die Optionen, Rechtsklick zeigt eine Test-Benachrichtigung, Ziehen verschiebt das Symbol.
- Ausblendbar unter Optionen → Sonstiges („Minimap-Symbol anzeigen“) oder mit `/emberstone minimap`.
- Emberstone erscheint zusätzlich im Addon-Menü an der Minimap (Addon Compartment).
- `/emberstone minimap` versteht jetzt auch `on`/`show` und `off`/`hide`; ohne Zusatz wird weiter umgeschaltet.
- Im Kampf öffnen Minimap-Symbol, Addon-Menü und `/emberstone` die Optionen nicht mehr, sondern zeigen einen Hinweis (Blizzard schränkt das Öffnen des Optionsfensters ein).
- Gilden-Bildschirmmeldung nutzt jetzt `RaidWarningUtil.AddMessage`; das veraltete `RaidNotice_AddMessage` nur noch als Rückfall. Vorher konnte die Meldung ohne Hinweis ausbleiben.
- Namen mit Bindestrich (z. B. „Anne-Marie Schmidt“) werden nicht mehr beim ersten Bindestrich abgeschnitten. Abgeschnitten wird nur noch ein Realm-Anhang am Ende.
- Ignorierliste und Protokollsuche: Leerzeichen am Anfang und Ende werden entfernt.
- Deutsche Texte einheitlich mit echten Umlauten (ä, ö, ü, ß). Eigene gespeicherte Texte bleiben unverändert.
- Das Minimap-Symbol wird über den Addon-Namen gefunden statt über einen festen Ordnerpfad; Fehler beim Aufbau landen im normalen Fehlerfenster statt still zu verschwinden.
- Neu: automatische Tests (Lua 5.1 mit nachgebauter WoW-API) unter `tests/`.

## 1.11 (Beta)

- Neu: Eigener AFK-Text. Wer dich anflüstert, während du AFK bist, bekommt einen zufälligen Spruch aus deiner Liste statt „AFK“ (`/emberstone afk`). Standardmäßig aus.
- Der Listen-Editor der Glückwunsch-Sprüche wird jetzt auch für die AFK-Sprüche verwendet.
- Eigene Einstellungsseite „AFK-Text“.

## 1.9 – 1.10

- Screenshots bei Meilensteinen, Gilden-Glückwünsche, Unterstützung für WoW Forever und Retail.
