# Emberstone

**Automatische Screenshots bei Meilensteinen und gildenweite Levelup-Glückwünsche (WoW Forever & Retail).**
*Automatic milestone screenshots and guild-wide level-up congratulations (WoW Forever & Retail).*

> Status: **Beta**. Fehler bitte über die [Issues](../../issues) melden.

---

## Deutsch

### Funktionen

- **Screenshots bei Meilensteinen:** Erfolge, Bosse, abgeschlossene Tiefen (Delves), Levelaufstiege, Mythic+ und neue Mythic+-Rekorde, seltene Gegner und Weltbosse, gewonnene Arenen und Schlachtfelder. Jedes Ereignis einzeln ein- und ausschaltbar, mit einstellbarer Verzögerung.
- **Gilden-Glückwünsche:** Wenn ein Gildenmitglied aufsteigt, kann Emberstone automatisch gratulieren. Die Sprüche kommen zufällig aus einer eigenen, bearbeitbaren Liste.
- **Eigener AFK-Text (neu in 1.11):** Statt „AFK“ bekommen Leute, die dich anflüstern, einen zufälligen Spruch aus deiner Liste, z. B. „Ich nehme meine jährliche Dusche zu mir“. Standardmäßig aus.
- **Minimap-Symbol (neu in 1.12):** Linksklick öffnet die Einstellungen, Rechtsklick zeigt eine Test-Benachrichtigung, Ziehen verschiebt das Symbol am Rand der Minimap. Ausblendbar unter Optionen → Sonstiges („Minimap-Symbol anzeigen“) oder per Befehl. Emberstone steht außerdem im Addon-Menü an der Minimap.

### Installation

Den Ordner nach `World of Warcraft/_retail_/Interface/AddOns/` kopieren. **Der Ordner muss genau `Emberstone` heißen** – ein ZIP von GitHub heißt z. B. `Emberstone-v1.12` und muss umbenannt werden, sonst fehlt das Addon-Symbol in der Addon-Liste.

### Befehle

- `/emberstone` oder `/ding` öffnet die Einstellungen (im Kampf nicht möglich, dann erscheint ein Hinweis).
- `/emberstone minimap` blendet das Minimap-Symbol ein oder aus; `/emberstone minimap on|show` bzw. `off|hide` setzt es gezielt.
- `/emberstone afk on|off|edit|add|list|test` – eigener AFK-Text.
- `/emberstone gzmsg …` – Glückwunsch-Sprüche.
- `/emberstone test` – Test der Levelup-Benachrichtigung (nur bei dir sichtbar).

### Hinweis zu WoW Forever (Beta)

Im aktuellen Forever-Beta-Client lädt ein `/reload` manchmal den vorherigen Stand der gespeicherten Einstellungen. Das betrifft alle Addons. Zum Sichern der Einstellungen lieber ausloggen statt `/reload`.

---

## English

### Features

- **Milestone screenshots:** achievements, boss kills, completed delves, level-ups, Mythic+ runs and new Mythic+ records, rares and world bosses, arena and battleground wins. Each event can be toggled separately, with a configurable delay.
- **Guild congratulations:** when a guild member levels up, Emberstone can congratulate them automatically with a random line from your own editable list.
- **Custom AFK text (new in 1.11):** instead of "AFK", people who whisper you get a random line from your list. Off by default.
- **Minimap button (new in 1.12):** left click opens the settings, right click shows a test notification, drag to move the button around the minimap. Can be hidden under Options → Miscellaneous ("Show minimap button") or with a command. Emberstone is also listed in the addon menu at the minimap.

### Installation

Copy the folder to `World of Warcraft/_retail_/Interface/AddOns/`. **The folder must be named exactly `Emberstone`** – a GitHub ZIP is named e.g. `Emberstone-v1.12` and has to be renamed, otherwise the addon icon is missing in the addon list.

### Commands

- `/emberstone` or `/ding` opens the settings (not possible in combat; a hint is shown instead).
- `/emberstone minimap` shows or hides the minimap button; `/emberstone minimap on|show` or `off|hide` sets it explicitly.
- `/emberstone afk on|off|edit|add|list|test` – custom AFK text.
- `/emberstone gzmsg …` – congratulation messages.
- `/emberstone test` – test the level-up notification (only visible to you).

---

## Lizenz / License

© 2026 Bobcation. All Rights Reserved. Siehe / see [LICENSE](LICENSE).
Free to use in game; redistribution and re-uploads only with permission.
