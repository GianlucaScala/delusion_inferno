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
| Springen / Haken lösen | Leertaste | A |
| Zielen | Rechte Maustaste | LT |
| Schießen | Linke Maustaste | RT |
| Enterhaken | Q oder mittlere Maustaste | RB |
| Klaue (Nahkampf) | F | B |
| Benutzen | E | X |
| Arm füttern (Attribute) | Tab | Back |
| Maus freigeben | Esc | Start |

## Was drin ist

- Third-Person-Controller mit Schulterkamera, Zielen, Überhitzungs-Waffe
- Enterhaken aus dem Techno-Arm: greift an jeder Fläche, zieht über Kanten
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
| `scripts/dev_shots.gd` | Automatischer Testlauf und Screenshots |

## Testen ohne Fenster

```bash
godot --headless -- --test
```

Spielt Haken, Kampf, Boss, Tor und Schacht automatisch durch und meldet PASS/FAIL.

Fahrplan zum vollen Spiel: [docs/ROADMAP.md](docs/ROADMAP.md)
