# Conway's Game of Life på DE0-CV

VHDL-implementation av Conway's Game of Life på Terasic DE0-CV med VGA-utgång,
80×60 cell-rutnät, 8 klassiska preset-mönster och interaktiv styrning.

## Funktioner

- 640×480 @ 60 Hz VGA-output, cellerna renderas som 8×8 pixel-block i grönt mot
  svart bakgrund
- 8 förinitierade mönster valbara via switchar:
  Glider, Blinker, R-pentomino, Gosper-gun, LWSS, Acorn, Toad, Diehard
- Paus/stega/auto-run-kontroller med justerbar hastighet (1-60 generationer/sek)
- Toroidal eller finit kantbeteende
- Generationsräknare på HEX0-3
- Logaritmisk population-VU-meter på LEDR[9:0]

## Bygg och flasha

```bash
# Kompilera (~30-60s)
/home/ed/altera_lite/25.1std/quartus/bin/quartus_sh --flow compile gol

# Flasha till kort via JTAG (kortets RUN/PROG-switch i RUN)
/home/ed/altera_lite/25.1std/quartus/bin/quartus_pgm -m jtag -o "p;output_files/gol.sof"
```

## Användning

| Kontroll | Funktion |
|---|---|
| `SW[2:0]` | Välj startmönster (0-7) |
| `SW[5:3]` | Hastighet: 0=1 gen/sek, 7=60 gen/sek |
| `SW[9]` | Kantmode: ner=toroidal (wrap), upp=finit (dö) |
| `KEY[3]` | Ladda valt mönster och pausa |
| `KEY[2]` | Pause/run-toggla |
| `KEY[1]` | Stega en generation (i pausläge) |
| `KEY[0]` | Reserv |
| `HEX0-3` | Generationsräknare (0-9999, wrappar) |
| `HEX4` | "P" när pausad |
| `HEX5` | Avsiktligt släckt |
| `LEDR[9:0]` | Populations-VU-meter (logaritmisk: 2, 4, 8, ..., 1024 celler) |

## Mönster

| Index (SW[2:0]) | Namn | Beteende |
|---|---|---|
| 0 | Glider | Förflyttar sig diagonalt evigt |
| 1 | Blinker | Oscillerar period 2 |
| 2 | R-pentomino | Methusalem - kaotisk i ~1100 generationer |
| 3 | Gosper-gun | Producerar oändligt med glidare |
| 4 | LWSS | Lättviktigt rymdskepp |
| 5 | Acorn | Methusalem - växer till 633 celler över ~5206 gen |
| 6 | Toad | Oscillator period 2 |
| 7 | Diehard | Försvinner helt efter exakt 130 generationer |

## Simulering

```bash
make tb_<modname>    # kör en testbänk (ex. tb_gol_engine)
make wave_<modname>  # öppna VCD i GTKWave
make clean
```

Testbänkar: `tb_clk25_div`, `tb_vga_timing`, `tb_grid_bram`, `tb_vga_renderer`,
`tb_pattern_rom`, `tb_pattern_loader`, `tb_gol_engine`, `tb_gol_engine_glider`,
`tb_gol_engine_pop`, `tb_control_fsm`.

## Arkitektur

```
50MHz ──► clk25_div ──► clk25 ──┬─► vga_renderer ──► VGA (R/G/B/HS/VS)
                                ├─► vga_timing
                                ├─► control_fsm ◄── debouncad KEY
                                ├─► pattern_loader (KEY[3] trigger)
                                │       │
                                │       ▼
                                │   pattern_rom
                                │       │
                                │       ▼
                                └─► gol_engine ──► grid_bram (ping-pong M10K)
                                                       │
                                                       ▼
                                                   vga_renderer
```

Detaljerad spec: `docs/superpowers/specs/2026-05-23-game-of-life-vga-design.md`
Implementationsplan: `docs/superpowers/plans/2026-05-23-game-of-life-vga.md`

## Pinout-källa

Alla pin-assignments verifierade mot DE0-CV golden top-referens:
`/home/ed/altera_lite/25.1std/quartus/common/devplatforms/DE0_CV_golden_top/DE0_CV_golden_top.qar`

Extrahera med `quartus_sh --restore` - pinnarna ligger i `platform_setup.tcl`.

## Anteckningar om hårdvaran

Detta projekt körs på det DE0-CV-kort som har **HEX5 segment d och e döda**.
Designen undviker HEX5 (alltid släckt). Om du flyttar designen till ett annat kort,
kan du lägga information på HEX5 också.
