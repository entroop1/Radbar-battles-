# Aurora Posters (Rive CLI project)

Three posters with soft, colour-cycling flames rising from the bottom edge,
rendered by one WGSL shader through Rive's GPU Canvas.

| File | Role |
|---|---|
| `scene.rml` | 1280×720 artboard, three `ScriptedDrawable` posters, each configured by `ScriptInputNumber`s (`mode` 0 pastel / 1 light / 2 night, `seed`, `speed`, `reach`, `resolution`) |
| `AuroraPoster.luau` | Node script: creates a `GPUCanvas`, feeds the uniforms each frame, draws the canvas image at poster size |
| `AuroraFlame.wgsl` | Fullscreen-triangle shader: domain-warped fbm flame tongues, six-key palette loop |

The browser prototype with the same shader in GLSL is `prototype/aurora-posters.html`.

## Build and preview

```bash
curl -fsSL https://releases.rive.app/cli/install.sh | sh   # once
rive rive/aurora-posters                    # live preview, rebuilds on save
rive rive/aurora-posters --verify           # compile RML, Luau and WGSL only
rive rive/aurora-posters --screenshot=out.png --advance=6s
rive rive/aurora-posters --once             # writes build/aurora-posters.riv
```

Scripts in a `.riv` for the web must be signed: build with `--publish` after
`rive login`.
