# iNFERNO;

Third-Person-Shooter-RPG in einer absteigenden, verfallenen Megastruktur.
Konzept: Rico & Robin (Delusion Studios). Engine: Godot 4.7, GDScript.

Stand: spielbar sind **Layer I** (Limbus, Boss „Der Pförtner“) und **Layer II** (Die Hänge,
Siedlung Naht) – zusammen etwa 20–30 Minuten. Der Fortschritt wird gespeichert.

## Starten

Projektordner in Godot 4.7 (oder neuer) öffnen und `F5` drücken.
Renderer: Forward+ (für den volumetrischen Nebel).

## Steuerung

| Aktion | Tastatur / Maus | Gamepad |
| --- | --- | --- |
| Bewegen | WASD | Linker Stick |
| Rennen | Shift | L3 |
| Springen | Leertaste | A |
| Vom Seil abspringen (Schwung bleibt) | Leertaste am Seil | A |
| Gasstoß (2 Ladungen, in der Luft) | Leertaste in der Luft | A |
| Zielen | Rechte Maustaste | LT |
| Schießen | Linke Maustaste | RT |
| Enterhaken auswerfen / loslassen | Q oder mittlere Maustaste | RB |
| Am Seil lenken | A / D / W | Linker Stick |
| Seil halten (reines Pendel) | S am Seil | Stick zurück |
| Klaue (Nahkampf) | F | B |
| Benutzen / Reden / Gespräch weiter | E | X |
| Antwort im Gespräch wählen | 1–4 oder Klick | – |
| Arm füttern (Attribute) | Tab | Back |
| Maus freigeben | Esc | Start |

## Was drin ist

- Third-Person-Controller mit Schulterkamera, Zielen, Überhitzungs-Waffe
- Enterhaken aus dem Techno-Arm: Winde mit echtem Seil. Schwerkraft und Schwung wirken
  weiter, daraus werden Bögen. Wer nichts drückt, wird sicher hingezogen und über den
  Anker hinausgeworfen; wer lenkt, abspringt und neu einhakt, fliegt
- Gasstoß in der Luft, Kamera öffnet sich und legt sich bei Tempo in die Kurve
- Ton: 37 synthetische Platzhalter-Sounds, Ambiente-Loop und Boss-Musik
- Nahkampf mit der Klaue
- XP, Stufen und drei Attribute (Fleisch, Dienstwaffe, Arm)
- Gegner „Fugenläufer“ (Fernkampf) und „Kriecher“ (Rudel, Nahkampf), Boss „Der Pförtner“ mit zwei Phasen
- Funk-Untertitel (Fisher), lesbare Terminals, Aufträge, Checkpoints
- Gespräche mit Antworten und Folgen (Fisher, Vesper, Krämer, die Alte)
- Schrott als Währung, Krämer mit drei Ausbauten
- Speichern an jedem Checkpoint, Startmenü mit Fortsetzen / Neues Spiel
- Layer-Wechsel: Der Schacht am Ende von Layer I führt nach Layer II
- Megastruktur wird komplett im Code aus Boxen erzeugt (`scripts/megastructure.gd`)

## Aufbau

| Datei | Zweck |
| --- | --- |
| `scripts/game.gd` | Autoload: Eingaben, Untertitel, Auftrag, RPG-Werte |
| `scripts/main.gd` | Atmosphäre (Nebel, Licht), setzt alles zusammen |
| `scripts/megastructure.gd` | Baukasten: Boxen → MultiMesh + Kollision |
| `scripts/level_base.gd` | Gemeinsame Bausteine aller Layer (Brücken, Portale, Trigger, NPCs) |
| `scripts/level_01.gd` | Layer I: Limbus |
| `scripts/level_02.gd` | Layer II: Die Hänge und die Siedlung Naht |
| `scripts/story.gd` | Alle Gesprächstexte und Figurennamen an einem Ort |
| `scripts/npc.gd` | Figuren, mit denen man reden kann |
| `scripts/start_menu.gd` | Startmenü |
| `scripts/player.gd` | Mainy: Bewegung, Kamera, Waffe, Haken, Klaue |
| `scripts/enemy.gd`, `scripts/crawler.gd`, `scripts/boss.gd` | Gegner und Boss |
| `scripts/hud.gd` | HUD und Attribut-Menü |
| `scripts/sfx.gd` | Autoload: spielt Sounds, Dauertöne und Musik |
| `audio/*.wav` | Platzhalter-Sounds (ersetzbar, siehe unten) |
| `tools/gen_audio.py` | Erzeugt alle Sounds neu |
| `scripts/dev_shots.gd` | Automatischer Testlauf und Screenshots |

## Testen ohne Fenster

```bash
godot --headless -- --test
```

Spielt Layer I automatisch durch (Haken, Kampf, Boss, Tor, Schacht) und meldet PASS/FAIL.

```bash
godot --headless -- --test --layer=2
```

Dasselbe für Layer II (Gespräche, Sprünge, Auftrag, Krämer, Finale, Spielstand).
Die Tests fassen den echten Spielstand nicht an.

## Story schreiben

Gespräche stehen als Daten in `scripts/story.gd`. Ein Knoten hat Sprecher, Text und
entweder `next` oder `choices`. Antworten können Flags setzen (`set`), nur unter
Bedingungen erscheinen (`if` / `unless`), Schrott kosten (`cost` + `buy`) oder ein
Ereignis im Level auslösen (`event`). Das Format ist oben in `scripts/game.gd` erklärt.

Die Namen „Vesper“ (im Pitch: Bestgirl), „Naht“ (die Siedlung), „Die Hänge“ und
„zweiter Stuhl“ (Fishers Bruder) sind Arbeitstitel und stehen als Konstanten am
Anfang von `scripts/story.gd`.

Der Spielstand liegt in Godots Benutzerordner als `inferno_save.json`
(Windows: `%APPDATA%\inferno`, Linux: `~/.local/share/inferno`).

## Ton ersetzen

Alle Sounds in `audio/` sind per Skript erzeugte Platzhalter. Eine eigene Aufnahme
bekommt einfach denselben Dateinamen (z. B. `audio/shot.wav`), danach in Godot neu
importieren. Lautstärken pro Sound stehen in der Tabelle `GAIN` in `scripts/sfx.gd`.
Dateien mit `_loop` im Namen werden automatisch als Schleife gespielt.

```bash
python3 tools/gen_audio.py
```

erzeugt die Platzhalter neu (braucht `numpy`).

## Haken abstimmen

Die Stellschrauben stehen oben in `scripts/player.gd`: `REEL_SPEED` (Windentempo),
`REEL_ACCEL`, `SWING_STEER` (Lenkkraft am Seil), `GAS_IMPULSE`, `ARRIVE_FLING`
(Wurf über den Anker) und `MAX_SPEED`.

Fahrplan zum vollen Spiel: [docs/ROADMAP.md](docs/ROADMAP.md)
