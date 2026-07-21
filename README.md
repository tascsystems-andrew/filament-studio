# Filament Studio

An interactive, browser-based designer for vacuum-tube guitar amplifiers. Whole-amp view with a full signal-chain editor — click any stage to dive in and see its schematic, load lines, operating point, live audio, and frequency response.

Single-file HTML app: no build, no dependencies, no server required. Just open `index.html` in a modern browser.

## What's in it

- **31 classic amp chains** built in — Fender / Marshall / Vox / Mesa / Hiwatt / Orange / Soldano / Bogner / Trainwreck / Ampeg / Gibson / Matchless / Selmer
- **50+ tubes** in the library — every common preamp, driver, and power triode/pentode/beam-tetrode, plus obscure output triode-pentodes (PCL86, ECL80/84/85, 11BM8, EL86, 6S4, 6360…) and RF pentodes/VHF triodes
- **Full-amp DC operating-point solver** — coupled cathode-KVL + plate load line + screen dropper (three residuals solved simultaneously; no shortcuts). Fixed and cathode bias, triode and pentode, preamp and power-amp.
- **Power supply model** — mains + rectifier + reservoir cap + multi-node B+ ladder (RC or LC filter stages), with per-tube B+ source picker. Sag, ripple, −3 dB corner per node, all live.
- **Tone stacks** — Fender FMV, Marshall TMB, Vox AC30 Top Boost, Bandmaster, Voigt, James, Baxandall, Tweed 1-knob — with real RC transfer functions (numerical MNA, not shelving approximations).
- **Output transformer** — click-to-edit primary Z, secondary taps, winding R, primary inductance, leakage L. Derived LF/HF −3 dB corners.
- **Click-to-edit everything** on the schematic — every resistor, every cap, every voltage. Values accept engineering suffixes (`22n`, `4.7u`, `470k`, `.68uF`…). Locked values from a preset stay locked until you unlock them.
- **Grid-stopper resistors** in series with every tube grid — editable, removable, models the HF roll-off with per-tube input-cap estimates (Miller-aware for triodes).
- **Live audio** — plays the current chain through the Web Audio API so you can hear what the settings sound like.
- **Full-amp JSON export** — dump every stage's tube model, resistors, caps, computed Q-point, PSU node voltages, ripple, load. Everything a builder needs to reproduce your design on the bench.
- **Tube Datasheet tracer** — datasheet-style plate curves for any tube in the library.

## Running it

Just open `index.html` in Chrome, Edge, or Safari.

For a local dev server (useful if you're editing and want live reload):

```bash
python3 -m http.server 8765
# open http://localhost:8765
```

Chrome / Edge get Web Serial support for hardware handoff; audio works everywhere.

## Structure

The whole app is one HTML file, ~8000 lines of vanilla JavaScript + inline CSS + SVG schematics. The state model is a chain of blocks (`Amp → Input → V1a → Tone → PI → Power → OPT → Speaker → Output`), each stored as a plain object in `localStorage`. Solvers, renderers, and the audio engine all read/write that state.

## Contributing

PRs welcome. If you fix a bug, add a preset, or improve a tube model, please push it back — the ShareAlike clause of the license makes this the expected pattern. Open an issue first if you're planning a bigger change.

## License

[**CC BY-NC-SA 4.0**](https://creativecommons.org/licenses/by-nc-sa/4.0/) — Attribution, NonCommercial, ShareAlike.

You can freely share and adapt this work for **non-commercial** purposes. If you build on it, you must credit the original and license your derivative under the same terms. For commercial use, please contact the maintainer.

See [`LICENSE`](LICENSE) for details.
