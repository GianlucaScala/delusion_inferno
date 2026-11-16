# iNFERNO;

Third-Person-Shooter-RPG in einer absteigenden, verfallenen Megastruktur.
Konzept: Rico & Robin (Delusion Studios). Engine: Godot 4.7, GDScript.

Stand: spielbarer Prototyp von **Layer I** (ca. 5–10 Minuten).

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
| Benutzen | E | X |
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
- Gegner "Fugenläufer", Boss "Der Pförtner" mit zwei Phasen
- Funk-Untertitel (Fisher), lesbare Terminals, Aufträge, Checkpoints
- Megastruktur wird komplett im Code aus Boxen erzeugt (`scripts/megastructure.gd`)

## Aufbau

| Datei | Zweck |
| --- | --- |
| `scripts/game.gd` | Autoload: Eingaben, Untertitel, Auftrag, RPG-Werte |
| `scripts/main.gd` | Atmosphäre (Nebel, Licht), setzt alles zusammen |
| `scripts/megastructure.gd` | Baukasten: Boxen → MultiMesh + Kollision |
| `scripts/level_01.gd` | Layer I: Geometrie, Gegner, Story-Trigger |
| `scripts/player.gd` | Mainy: Bewegung, Kamera, Waffe, Haken, Klaue |
| `scripts/enemy.gd`, `scripts/boss.gd` | Gegner und Boss |
| `scripts/hud.gd` | HUD und Attribut-Menü |
| `scripts/sfx.gd` | Autoload: spielt Sounds, Dauertöne und Musik |
| `audio/*.wav` | Platzhalter-Sounds (ersetzbar, siehe unten) |
| `tools/gen_audio.py` | Erzeugt alle Sounds neu |
| `scripts/dev_shots.gd` | Automatischer Testlauf und Screenshots |

## Testen ohne Fenster

```bash
godot --headless -- --test
```

Spielt Haken, Kampf, Boss, Tor und Schacht automatisch durch und meldet PASS/FAIL.

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
