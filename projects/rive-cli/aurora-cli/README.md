# Aurora CLI (Rive CLI project)

Three posters with soft, colour-cycling flames rising from the bottom edge,
rendered by one WGSL shader through Rive's GPU Canvas.

| File | Role |
|---|---|
| `scene.rml` | 1280×720 artboard, three `ScriptedDrawable` posters, each configured by `ScriptInputNumber`s (`mode` 0 pastel / 1 light / 2 night, `seed`, `speed`, `reach`, `resolution`) |
| `AuroraPoster.luau` | Node script: creates a `GPUCanvas`, feeds the uniforms each frame, draws the canvas image at poster size |
| `AuroraFlame.wgsl` | Fullscreen-triangle shader: domain-warped fbm flame tongues, six-key palette loop |

The browser prototype with the same shader in GLSL is `web-prototype/aurora-posters.html` (excluded from the Rive build in `rive.yaml`).

## Build and preview

```bash
curl -fsSL https://releases.rive.app/cli/install.sh | sh   # once
rive projects/rive-cli/aurora-cli                    # live preview, rebuilds on save
rive projects/rive-cli/aurora-cli --verify           # compile RML, Luau and WGSL only
rive projects/rive-cli/aurora-cli --screenshot=out.png --advance=6s
rive projects/rive-cli/aurora-cli --once             # writes build/aurora-cli.riv
```

Scripts in a `.riv` for the web must be signed: build with `--publish` after
`rive login`.
