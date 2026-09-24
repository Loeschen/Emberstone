# Changelog

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
