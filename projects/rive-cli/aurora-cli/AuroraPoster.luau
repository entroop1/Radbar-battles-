-- AuroraPoster: renders the AuroraFlame WGSL shader into a GPU canvas and
-- draws it as a poster-sized image, animated every frame.
--
-- INPUTS (ScriptInput* children of the ScriptedDrawable in scene.rml)
--   width, height  poster size in artboard units; the node origin is its top-left
--   mode           0 pastel field, 1 light poster, 2 night poster
--   seed           offsets the noise so each poster has its own layout
--   speed          time multiplier (1 = reference pace)
--   reach          scales how high the flames climb (1 = reference)
--   resolution     canvas pixels per artboard unit (the image is soft, 0.75 is plenty)
-- DEPENDENCIES   AuroraFlame.wgsl

type AuroraPoster = {
  width: Input<number>,
  height: Input<number>,
  mode: Input<number>,
  seed: Input<number>,
  speed: Input<number>,
  reach: Input<number>,
  resolution: Input<number>,

  time: number,
  canvas: GPUCanvas?,
  pipeline: GPUPipeline?,
  uniforms: GPUBuffer?,
  bindGroup: GPUBindGroup?,
  staging: buffer,
  sampler: ImageSampler?,

  init: (self: AuroraPoster, context: Context) -> boolean,
  advance: (self: AuroraPoster, seconds: number) -> boolean,
  draw: (self: AuroraPoster, renderer: Renderer) -> (),
}

-- Two vec4<f32> in the shader's Uniforms struct = 32 bytes.
local UNIFORM_BYTES = 32

local function canvasSize(self: AuroraPoster): (number, number)
  local res = (self.resolution or 0.75) :: number
  local w = math.max(1, math.floor(((self.width or 336) :: number) * res))
  local h = math.max(1, math.floor(((self.height or 476) :: number) * res))
  return w, h
end

local function init(self: AuroraPoster, context: Context): boolean
  local w, h = canvasSize(self)
  local canvas = context:gpuCanvas({ width = w, height = h })
  self.canvas = canvas

  local shader = context:shader('AuroraFlame')
  if shader == nil then
    print('AuroraPoster: shader AuroraFlame not found')
    return true
  end

  local pipeline = GPUPipeline.new({
    vertex = shader,
    fragment = shader,
    vertexLayout = {},   -- fullscreen triangle comes from vertex_index
    colorTargets = { { format = canvas.format } },
  })
  self.pipeline = pipeline

  local uniforms = GPUBuffer.new({ size = UNIFORM_BYTES, usage = 'uniform', label = 'aurora-uniforms' })
  self.uniforms = uniforms
  self.staging = buffer.create(UNIFORM_BYTES)

  -- Auto layout: the pipeline derives @group(0) from the shader.
  self.bindGroup = GPUBindGroup.new({
    layout = pipeline:getBindGroupLayout(0),
    ubos = { { slot = 0, buffer = uniforms } },
  })

  self.sampler = ImageSampler('clamp', 'clamp', 'bilinear')
  return true
end

local function advance(self: AuroraPoster, seconds: number): boolean
  if seconds > 0.05 then seconds = 0.05 end   -- avoid jumps after a stall
  self.time += seconds * ((self.speed or 1) :: number)
  return true   -- keep advancing: the effect never settles
end

local function draw(self: AuroraPoster, renderer: Renderer)
  local canvas = self.canvas
  local pipeline = self.pipeline
  local uniforms = self.uniforms
  local bindGroup = self.bindGroup
  if not (canvas and pipeline and uniforms and bindGroup) then return end

  -- Follow input changes to width/height/resolution.
  local w, h = canvasSize(self)
  if canvas.width ~= w or canvas.height ~= h then
    canvas:resize(w, h)
  end

  local s = self.staging
  buffer.writef32(s, 0, w)
  buffer.writef32(s, 4, h)
  buffer.writef32(s, 8, self.time)
  buffer.writef32(s, 12, (self.mode or 2) :: number)
  buffer.writef32(s, 16, (self.seed or 0) :: number)
  buffer.writef32(s, 20, (self.reach or 1) :: number)
  buffer.writef32(s, 24, 0)
  buffer.writef32(s, 28, 0)
  uniforms:write(s)

  local pass = canvas:beginRenderPass({
    color = {
      { loadOp = 'clear', storeOp = 'store', clearColor = { 0, 0, 0, 1 } },
    },
  })
  pass:setPipeline(pipeline)
  pass:setBindGroup(0, bindGroup)
  pass:draw(3)
  pass:finish()

  -- The canvas image draws at its pixel size from the node origin;
  -- scale it back up to the poster's artboard size.
  local pw = (self.width or 336) :: number
  local ph = (self.height or 476) :: number
  renderer:save()
  renderer:transform(Mat2D.values(pw / w, 0, 0, ph / h, 0, 0))
  renderer:drawImage(canvas.image, self.sampler :: ImageSampler, 'srcOver', 1)
  renderer:restore()
end

return function(): Node<AuroraPoster>
  return {
    width = 336,
    height = 476,
    mode = 2,
    seed = 0,
    speed = 1,
    reach = 1,
    resolution = 0.75,

    time = 0,
    canvas = nil,
    pipeline = nil,
    uniforms = nil,
    bindGroup = nil,
    staging = buffer.create(UNIFORM_BYTES),
    sampler = nil,

    init = init,
    advance = advance,
    draw = draw,
  }
end
