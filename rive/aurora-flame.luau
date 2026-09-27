-- Aurora Flame: soft, colour-cycling "flame tongues" rising from the bottom of
-- a poster. It is the Rive-native version of prototype/aurora-posters.html.
-- Rive scripts have no custom pixel shaders, so this uses heavily feathered
-- vector tongues and blend modes to stand in for the shader's warped fbm:
--   * feather = the shader's softness
--   * vertical linear gradient per tongue = the fade-out toward the flame front
--   * sum-of-sines sway = the domain-warp motion
--   * "screen" blend on the night poster = additive glow, plus white hot cores
--
-- INPUTS (node inputs, wire in the editor)
--   width, height   poster size in artboard units (node origin = top-left)
--   mode            0 pastel field, 1 light poster, 2 night poster
--   speed           animation speed multiplier (1 = reference pace)
--   tongues         number of flame tongues (8–20 looks right)
--   softness        feather as a fraction of width (0.12–0.3)
--   seed            varies the layout between posters
-- EVENTS        none
-- DEPENDENCIES  none

local msin = math.sin
local mcos = math.cos
local mfloor = math.floor
local mmax = math.max
local mmin = math.min

type Tongue = {
  x: number,        -- base position, 0–1 across the poster
  w: number,        -- base half-width, fraction of poster width
  h: number,        -- reach, fraction of poster height
  phase: number,
  hue: number,
  path: Path,
  paint: Paint,
}

type AuroraFlame = {
  width: Input<number>,
  height: Input<number>,
  mode: Input<number>,
  speed: Input<number>,
  tongues: Input<number>,
  softness: Input<number>,
  seed: Input<number>,

  time: number,
  items: { Tongue },
  cores: { Tongue },
  layoutHash: number,
  bgPath: Path,
  bgPaint: Paint,
  skyPaint: Paint,

  init: (self: AuroraFlame, context: Context) -> boolean,
  update: (self: AuroraFlame) -> (),
  advance: (self: AuroraFlame, seconds: number) -> boolean,
  draw: (self: AuroraFlame, renderer: Renderer) -> (),
}

-- Palette keys sampled from the reference: coral, gold, teal, sky, violet, pink.
local KEYS: { { number } } = {
  { 255, 107, 92 },
  { 255, 184, 71 },
  { 64, 204, 199 },
  { 115, 168, 255 },
  { 173, 115, 255 },
  { 255, 115, 173 },
}

-- Palette lookup around the loop, optionally washed toward white (pastels).
local function palette(h: number, wash: number, alpha: number): Color
  local x = (h - mfloor(h)) * 6
  local i = mfloor(x)
  local f = x - i
  f = f * f * (3 - 2 * f)
  local a = KEYS[i + 1]
  local b = KEYS[(i + 1) % 6 + 1]
  local r = a[1] + (b[1] - a[1]) * f
  local g = a[2] + (b[2] - a[2]) * f
  local bl = a[3] + (b[3] - a[3]) * f
  r = r + (255 - r) * wash
  g = g + (255 - g) * wash
  bl = bl + (255 - bl) * wash
  return Color.rgba(mfloor(r), mfloor(g), mfloor(bl), mfloor(alpha))
end

-- Cheap deterministic hash in [0, 1).
local function rand(n: number): number
  local s = msin(n * 127.1 + 311.7) * 43758.5453
  return s - mfloor(s)
end

-- Layered sines standing in for fbm noise.
local function sway(t: number, p: number): number
  return 0.55 * msin(t * 0.9 + p) + 0.3 * msin(t * 1.7 + p * 2.3) + 0.15 * msin(t * 3.1 + p * 4.1)
end

local function makeTongue(i: number, seed: number, core: boolean): Tongue
  local k = i + seed * 17
  return {
    x = if core then 0.15 + rand(k + 0.5) * 0.7 else rand(k) * 1.1 - 0.05,
    w = if core then 0.06 + rand(k + 2) * 0.06 else 0.1 + rand(k + 2) * 0.16,
    h = if core then 0.12 + rand(k + 3) * 0.14 else 0.35 + rand(k + 3) * 0.65,
    phase = rand(k + 4) * 6.283,
    hue = rand(k + 5),
    path = Path.new(),
    paint = Paint.with({ style = "fill", color = Color.rgba(255, 255, 255, 255) }),
  }
end

-- Teardrop tongue: wide soft base below the bottom edge, curling tip above.
local function buildTongue(path: Path, bx: number, by: number, hw: number, tipX: number, tipY: number, bend: number)
  path:reset()
  path:moveTo(Vector.xy(bx - hw, by))
  path:cubicTo(
    Vector.xy(bx - hw * 1.1 + bend * 0.3, by - (by - tipY) * 0.45),
    Vector.xy(tipX - hw * 0.35 + bend, tipY + (by - tipY) * 0.25),
    Vector.xy(tipX, tipY)
  )
  path:cubicTo(
    Vector.xy(tipX + hw * 0.35 + bend, tipY + (by - tipY) * 0.25),
    Vector.xy(bx + hw * 1.1 + bend * 0.3, by - (by - tipY) * 0.45),
    Vector.xy(bx + hw, by)
  )
  path:close()
end

local function rebuildLayout(self: AuroraFlame)
  local n = mmax(1, mfloor((self.tongues or 14) :: number))
  local seed = (self.seed or 0) :: number
  self.items = {}
  for i = 1, n do
    self.items[#self.items + 1] = makeTongue(i, seed, false)
  end
  self.cores = {}
  for i = 1, 4 do
    self.cores[#self.cores + 1] = makeTongue(100 + i, seed, true)
  end
end

local function init(self: AuroraFlame, _context: Context): boolean
  self.layoutHash = -1
  self.time = 0
  return true
end

local function update(self: AuroraFlame)
  -- Rebuild the tongue layout only when count or seed changes.
  local h = mfloor((self.tongues or 14) :: number) * 1000 + mfloor(((self.seed or 0) :: number) * 10)
  if h ~= self.layoutHash then
    rebuildLayout(self)
    self.layoutHash = h
  end
end

local function advance(self: AuroraFlame, seconds: number): boolean
  if seconds > 0.05 then seconds = 0.05 end
  self.time += seconds * ((self.speed or 1) :: number)
  return true
end

local function draw(self: AuroraFlame, renderer: Renderer)
  if self.layoutHash == -1 then update(self) end
  local W = (self.width or 336) :: number
  local H = (self.height or 476) :: number
  local mode = mfloor((self.mode or 2) :: number)
  local t = self.time
  local soft = ((self.softness or 0.2) :: number) * W

  -- Background + clip to the poster.
  local bg = self.bgPath
  bg:reset()
  bg:moveTo(Vector.xy(0, 0))
  bg:lineTo(Vector.xy(W, 0))
  bg:lineTo(Vector.xy(W, H))
  bg:lineTo(Vector.xy(0, H))
  bg:close()

  renderer:save()
  renderer:clipPath(bg)

  self.bgPaint.color = if mode == 2 then Color.rgb(22, 21, 24) else Color.rgb(255, 255, 255)
  renderer:drawPath(bg, self.bgPaint)

  if mode == 0 then
    -- Pastel field: sky-blue ceiling fading to white mist.
    self.skyPaint.gradient = Gradient.linear(Vector.xy(0, 0), Vector.xy(0, H * 0.55), {
      { position = 0, color = Color.rgba(178, 224, 250, 255) },
      { position = 1, color = Color.rgba(255, 255, 255, 0) },
    })
    renderer:drawPath(bg, self.skyPaint)
  end

  local reach = if mode == 0 then 0.95 else (if mode == 1 then 0.5 else 0.58)
  local wash = if mode == 0 then 0.35 else (if mode == 1 then 0.22 else 0)
  local baseAlpha = if mode == 2 then 230 else 205
  local blend: BlendMode = if mode == 2 then "screen" else "srcOver"

  for i = 1, #self.items do
    local it = self.items[i]
    local s = sway(t, it.phase)
    local pulse = 0.75 + 0.25 * msin(t * 0.8 + it.phase * 1.3)
    local bx = (it.x + 0.04 * s) * W
    local by = H + soft * 0.6
    local tipY = H - it.h * reach * H * pulse
    local tipX = bx + s * W * 0.12
    local hw = it.w * W
    buildTongue(it.path, bx, by, hw, tipX, tipY, mcos(t * 1.1 + it.phase) * hw * 0.6)

    local hue = t * 0.06 + it.hue * 0.35 + (bx / W) * 0.35
    local p = it.paint
    p.blendMode = blend
    p.feather = soft
    p.gradient = Gradient.linear(Vector.xy(0, by), Vector.xy(0, tipY), {
      { position = 0, color = palette(hue, wash, baseAlpha) },
      { position = 0.6, color = palette(hue + 0.08, wash, baseAlpha * 0.55) },
      { position = 1, color = palette(hue + 0.12, wash, 0) },
    })
    renderer:drawPath(it.path, p)
  end

  if mode == 2 then
    -- White-hot cores near the base, only on the night poster.
    for i = 1, #self.cores do
      local c = self.cores[i]
      local s = sway(t * 1.3, c.phase)
      local flicker = mmin(1, mmax(0, 0.55 + 0.6 * msin(t * 1.9 + c.phase)))
      local bx = (c.x + 0.05 * s) * W
      local by = H + soft * 0.3
      local tipY = H - c.h * H * (0.7 + 0.3 * flicker)
      local hw = c.w * W
      buildTongue(c.path, bx, by, hw, bx + s * hw, tipY, s * hw * 0.4)
      local p = c.paint
      p.blendMode = "screen"
      p.feather = soft * 0.6
      p.gradient = Gradient.linear(Vector.xy(0, by), Vector.xy(0, tipY), {
        { position = 0, color = Color.rgba(255, 246, 232, mfloor(235 * flicker)) },
        { position = 1, color = Color.rgba(255, 246, 232, 0) },
      })
      renderer:drawPath(c.path, p)
    end
  end

  renderer:restore()
end

return function(): Node<AuroraFlame>
  return {
    width = 336,
    height = 476,
    mode = 2,
    speed = 1,
    tongues = 14,
    softness = 0.2,
    seed = 0,

    time = 0,
    items = {},
    cores = {},
    layoutHash = -1,
    bgPath = Path.new(),
    bgPaint = Paint.with({ style = "fill", color = Color.rgb(255, 255, 255) }),
    skyPaint = Paint.with({ style = "fill", color = Color.rgb(255, 255, 255) }),

    init = init,
    update = update,
    advance = advance,
    draw = draw,
  }
end
