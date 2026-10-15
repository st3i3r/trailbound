-- Trailbound ground painter — Eastward grammar, deterministic.
-- aseprite -b --script tools/tb_paint_ground.lua <mask.txt> <out.ase> <out.png>
-- Layers: zones(hidden) | water | shore | rim | grass | dirt | shade | detail
local mask_path, ase_out, png_out = app.params["mask"], app.params["ase"], app.params["png"]
if app.scriptArgs and #app.scriptArgs >= 3 then
  mask_path, ase_out, png_out = app.scriptArgs[1], app.scriptArgs[2], app.scriptArgs[3]
end

local MASK = {}
for line in io.lines(mask_path) do MASK[#MASK+1] = line end
local GH, GW = #MASK, #MASK[1]
local T = 32
local W, H = GW*T, GH*T

-- deterministic hash noise -> organic dab edges
local function h2(x, y, s)
  local n = (x*374761393 + y*668265263 + s*2246822519) % 4294967296
  n = (n ~ (n >> 13)) * 1274126177 % 4294967296
  return ((n ~ (n >> 16)) % 1000) / 1000.0
end

local function zone_at_raw(x, y)                -- px -> mask char
  local c, r = math.floor(x/T)+1, math.floor(y/T)+1
  if c < 1 or c > GW or r < 1 or r > GH then return 'G' end
  return MASK[r]:sub(c, c)
end
-- organic edges: jitter lookups near boundaries so zone borders
-- billow instead of stepping on the 32px grid
local function zone_at(x, y)
  local c = math.floor(x/T)+1
  local r = math.floor(y/T)+1
  local fx, fy = x - (c-1)*T, y - (r-1)*T       -- pos inside cell
  local m = math.min(fx, T-fx, fy, T-fy)         -- dist to cell edge
  if m < 10 then
    local jx = (h2(x, y, 41)-0.5) * 26
    local jy = (h2(x, y, 42)-0.5) * 26
    return zone_at_raw(x + jx*m/10, y + jy*m/10)
  end
  return zone_at_raw(x, y)
end

-- distance-to-water (BFS on cell grid, then per-px cell dist approx)
local dwt = {}
for r = 0, GH-1 do for c = 0, GW-1 do
  dwt[r*GW+c] = (MASK[r+1]:sub(c+1,c+1) == 'W') and 0 or 999
end end
local DC = {-1, 1, 0, 0}
local DR = {0, 0, -1, 1}
for pass = 1, 40 do
  for r = 0, GH-1 do for c = 0, GW-1 do
    local d = dwt[r*GW+c]
    if d > 0 then
      local m = d
      for i = 1, 4 do
        local nc, nr = c + DC[i], r + DR[i]
        if nc>=0 and nc<GW and nr>=0 and nr<GH
            and dwt[nr*GW+nc]+1 < m then
          m = dwt[nr*GW+nc]+1
        end
      end
      dwt[r*GW+c] = m
    end
  end end
end
local function water_dist(x, y)
  local c, r = math.floor(x/T), math.floor(y/T)
  if c<0 or c>=GW or r<0 or r>=GH then return 999 end
  return dwt[r*GW+c]
end


local spr = Sprite(W, H, ColorMode.RGB)
local IMGS = {}
local function new_layer(name)
  local l = spr:newLayer(); l.name = name
  IMGS[l] = Image(W, H, ColorMode.RGBA)
  return l
end
local zones = spr.layers[1]; zones.name = "zones"; zones.isVisible = false
local water  = new_layer("water")     -- bottom-most art layer
local grass  = new_layer("grass")
local dirt   = new_layer("dirt")
local shore  = new_layer("shore")     -- ring over grass edge
local rim    = new_layer("rim")       -- stones straddle the waterline
local shade  = new_layer("shade")
local detail = new_layer("detail")

local function px(img, x, y, r, g, b, a)
  if x>=0 and x<W and y>=0 and y<H then img:putPixel(x, y, app.pixelColor.rgba(r,g,b,a or 255)) end
end

-- ---------- palette (measured from the ref) ----------
local WATER_DEEP   = {30, 108, 92}    -- v0.42 south/deep mass (blue-shifted to survive warm grade)
local WATER_MID    = {38, 150, 130}   -- v0.59 body — bluer than ref raw, matches post-grade
local WATER_BANK   = {32, 118, 100}   -- bank shadow at north edge
local WATER_LIT    = {74, 185, 152}   -- foam-adjacent light
local WATER_SPARK  = {88, 190, 160}   -- sparse sparkle dots
local FOAM         = {205, 240, 218}
local SHORE_OLIVE  = {166, 206, 85}   -- ring outside rim
local SHORE_DARK   = {128, 168, 66}   -- ring inner edge
local RIM_LIT      = {168, 196, 150}  -- stone top faces
local RIM_MID      = {118, 150, 128}
local RIM_DARK     = {62, 92, 82}     -- stone undersides
-- grass bands: measured means from the ref — mids are GREENER than
-- sunpools (h rises with shade), deep pockets go grey-olive (s drops).
local GRASS_MID    = {161, 197, 102}  -- ref mid band mean EXACT h0.229 s0.48
local GRASS_LIT    = {192, 227, 108}  -- ref lit band mean EXACT h0.215 s0.53
local SUNPOOL      = {226, 253, 106}  -- ref sun band mean EXACT h0.198 s0.58
local SUNLIT       = {209, 240, 107}  -- ramp midpoint lit<->sunpool
local POCKET       = {132, 153, 104}  -- ref deep band mean EXACT h0.237 s0.32 grey-olive
local POCKET_DEEP  = {106, 128, 90}   -- canopy-contact shade, deeper grey-olive
local DIRT_BASE    = {178, 190, 92}   -- v0.75 worn earth — below grass lit (0.89)
local DIRT_LIT     = {200, 214, 104}
local DIRT_DASH    = {150, 165, 75}   -- worn strokes, darker
local DIRT_EDGE    = {140, 158, 72}   -- trampled border tone
local SHADE        = {104, 146, 58}   -- vignette bands
local MOSS_A       = {178, 214, 96}
local MOSS_B       = {150, 190, 82}

-- ---------- grass: base + sun pools + moss dabs ----------
-- AUTHORED composition, not a noise field — each sun pool is a placed
-- soft blob (the Eastward read is a *painted composition*, per Pixpil's
-- own pipeline: whole-scene paint, tilemap only the base). Pool
-- placement avoids pads/road/court; shapes are horizontal ellipses.
local POOLS = {   -- {cx, cy, rx, ry}  authored — large overlapping
                  -- washes (~55% field coverage), not isolated spots
  {300, 140, 95, 42}, {430, 130, 85, 38}, {240, 200, 70, 36},
  {520, 130, 60, 34}, {380, 240, 90, 40}, {270, 300, 70, 34},
  {170, 150, 55, 30}, {560, 340, 60, 32}, {450,  70, 80, 30},
  {120, 345, 60, 32}, {600, 160, 45, 28}, {340, 350, 75, 34},
  {200, 350, 55, 30}, {490, 300, 60, 30},
}
local function pool_val(x, y)
  local best = 0
  for _, p in ipairs(POOLS) do
    local dx = (x - p[1]) / p[3]
    local dy = (y - p[2]) / p[4]
    local d = dx*dx + dy*dy
    if d < 1.6 then
      local v = 1.0 - d/1.6                    -- 1 at centre -> 0 edge
      v = v*v*(3-2*v)                          -- smoothstep falloff
      if v > best then best = v end
    end
  end
  -- billow the boundary: two octaves of wobble so pool edges read as
  -- irregular cloud-masses, not clean ellipses (ref pool shapes)
  local wob = (h2(math.floor(x/11), math.floor(y/8), 7)-0.5)*0.45
           + (h2(math.floor(x/4),  math.floor(y/4), 13)-0.5)*0.22
  return best + wob
end
for y = 0, H-1 do for x = 0, W-1 do
  local z = zone_at(x, y)
  if z == 'G' then
    -- noise at 3px grain: ref has zero isolated specks; per-pixel salt
    -- was our 'noisy' look. Blocky hash => multi-px patches only.
    local pv = pool_val(x, y) + (h2(math.floor(x/3), math.floor(y/3), 3)-0.5)*0.10
    -- canopy shadow rule (measured): deep pockets only exist within
    -- ~120px of the treeline or in corners; open field floors at POCKET
    -- canopy shadows: authored blobs under each treeline tree foot
    -- (treeline trunks at y~76; shadow falls south-east ~18px down)
    local SHADOWS = { {158,96,34,13},{246,92,36,14},{336,96,32,13},
                      {416,94,36,14},{476,92,32,13},{60,368,60,18},
                      {590,368,55,18},{18,60,45,16} }
    local near_shade = (math.min(x, W-1-x) + math.min(y, H-1-y) < 90)
    for _, s in ipairs(SHADOWS) do
      local dx = (x - s[1]) / s[3]
      local dy = (y - s[2]) / s[4]
      if dx*dx + dy*dy < 1.0 then near_shade = true break end
    end
    -- authored pools: lit/sunpool inside the blobs; mid elsewhere;
    -- pockets only under the treeline/corners (canopy shadow rule)
    -- dominance (measured): sun-drenched is the DEFAULT — base = lit.
    -- mid-green only appears as scattered cool washes (~20%).
    local cool = (h2(math.floor(x/9), math.floor(y/9), 12)-0.5) * 2
    -- graded bands so pool edges RAMP (lit->sunlit->sunpool), not step
    local c = GRASS_LIT                          -- base = sun-drenched
    if     pv > 0.62 then c = SUNPOOL
    elseif pv > 0.40 then c = SUNLIT             -- transition band
    elseif pv > 0.20 then c = GRASS_LIT
    elseif cool > 0.55 then c = GRASS_MID
    elseif near_shade then c = POCKET
    else                  c = GRASS_LIT end
    if pv <= 0.10 and near_shade and h2(x, y, 8) < 0.45 then
      c = POCKET_DEEP
    end
    px(IMGS[grass], x, y, c[1], c[2], c[3])
  end
end end
-- moss dabs: measured — they are an EDGE treatment (107/1000px at pool
-- borders, ~0 inside), 4px horizontal smudges. Paint them only where
-- the pool field crosses a band boundary.
local rng_i = 0
local function nrand() rng_i = rng_i + 1; return h2(rng_i, 17, 99) end
for y = 0, H-1 do for x = 0, W-1 do
  if zone_at(x, y) == 'G' then
    local pv = pool_val(x, y)
    local edge = math.min(math.abs(pv-0.62), math.abs(pv-0.40), math.abs(pv-0.20))
    if edge < 0.03 and h2(math.floor(x/3), math.floor(y/3), 31) < 0.22
        and h2(x, y, 35) < 0.6 then
      -- dab: horizontal smudge 3-5px wide, 1-2px tall, one tone off
      local len = 3 + math.floor(h2(x, y, 32)*3)
      local down = (h2(x, y, 33) < 0.5)   -- dab the darker side
      for j = 0, len-1 do
        if zone_at(x+j, y) == 'G' then
          local c = down and MOSS_B or MOSS_A
          px(IMGS[grass], x+j, y, c[1], c[2], c[3])
          if h2(x+j, y, 34) < 0.4 then
            px(IMGS[grass], x+j, y+1, c[1]-12, c[2]-12, c[3]-5)
          end
        end
      end
    end
  end
end end

-- despeckle: kill isolated <=2px flecks — any grass px whose 8
-- neighbours are ALL a different flat tone adopts the majority tone.
-- (ref has clusters of strokes, never salt)
local function despeckle(img)
  local src = img:clone()
  for y = 1, H-2 do for x = 1, W-2 do
    local c = src:getPixel(x, y)
    local same = 0
    for dy=-1,1 do for dx=-1,1 do
      if (dx~=0 or dy~=0) and src:getPixel(x+dx, y+dy) == c then same = same + 1 end
    end end
    if same == 0 then
      img:putPixel(x, y, src:getPixel(x, y-1))   -- copy north neighbour
    end
  end end
end
-- ---------- dirt: worn-grass base + dry dashes ----------
for y = 0, H-1 do for x = 0, W-1 do
  if zone_at(x,y) == 'D' then
    local v = pool_val(x, y)
    local c = (v > 0.55) and DIRT_LIT or DIRT_BASE
    -- trampled border: dirt px within 3px of grass edge get the edge tone
    for dx = -3, 3 do
      if zone_at_raw(x+dx, y) == 'G' then c = DIRT_EDGE break end
    end
    px(IMGS[dirt], x, y, c[1], c[2], c[3])
  end
end end
-- worn dashes, denser + direction-aware: dashes follow the dirt run's
-- long axis (road runs E-W => horizontal strokes; court/yard => mixed)
for i = 1, 900 do
  local cx, cy = math.floor(nrand()*W), math.floor(nrand()*H)
  if zone_at(cx, cy) == 'D' then
    local len = 3 + math.floor(nrand()*5)
    -- horizontal run? count dirt extent left/right
    local span = 0
    for dx = -24, 24 do if zone_at_raw(cx+dx, cy) == 'D' then span = span + 1 end end
    local horiz = span > 20 or nrand() < 0.6
    for j = 0, len do
      local dx, dy = horiz and j or 0, horiz and 0 or j
      if zone_at(cx+dx, cy+dy) == 'D' then
        local c = (nrand() < 0.55) and DIRT_DASH or DIRT_LIT
        px(IMGS[dirt], cx+dx, cy+dy, c[1], c[2], c[3])
      end
    end
  end
end

-- ---------- water: depth gradient + foam at the inlet ----------
for y = 0, H-1 do for x = 0, W-1 do
  if zone_at(x,y) == 'W' then
    local t = y / H                                 -- deeper south
    local c = WATER_MID
    if t > 0.55 then c = WATER_DEEP end
    -- bank shadow: water px with dry land within 9px ABOVE is darker
    -- (measured: north edge rgb(45,132,103) vs body (45,157,128))
    local bank = false
    for dy = -9, -3, 3 do
      if zone_at_raw(x, y+dy) ~= 'W' then bank = true break end
    end
    if bank then c = WATER_BANK end
    if h2(x,y,5) < 0.015 then c = WATER_SPARK end  -- sparse sparkle (ref v-std)
    px(IMGS[water], x, y, c[1], c[2], c[3])
  end
end end
-- ---------- waterfall: cascade streaks where the stream enters top ----------
-- find the stream's top-entry span (W cells touching y<8)
local inlet_x0, inlet_x1 = W, 0
for x = 0, W-1 do
  if zone_at_raw(x, 4) == 'W' then
    if x < inlet_x0 then inlet_x0 = x end
    if x > inlet_x1 then inlet_x1 = x end
  end
end
if inlet_x1 > inlet_x0 then
  -- falls face: vertical foam+light streaks filling the entry for ~26px down
  for x = inlet_x0, inlet_x1 do
    for y = 2, 28 do
      if zone_at(x, y) == 'W' then
        local streak = h2(x, math.floor(y/3), 21)
        if streak < 0.35 then
          px(IMGS[water], x, y, FOAM[1], FOAM[2], FOAM[3])
        elseif streak < 0.7 then
          px(IMGS[water], x, y, WATER_LIT[1], WATER_LIT[2], WATER_LIT[3])
        end
      end
    end
  end
  -- plunge pool: bright foam ring + churn where the falls land (~y 26-40)
  local midx = math.floor((inlet_x0 + inlet_x1) / 2)
  for i = 1, 120 do
    local cx = midx + math.floor((nrand()-0.5) * (inlet_x1-inlet_x0+24))
    local cy = 26 + math.floor(nrand()*16)
    if zone_at(cx, cy) == 'W' then
      px(IMGS[water], cx, cy, math.floor(FOAM[1]-nrand()*30), math.floor(FOAM[2]-nrand()*15), math.floor(FOAM[3]-nrand()*20))
      if nrand() < 0.4 then px(IMGS[water], cx+1, cy, FOAM[1]-40, FOAM[2]-20, FOAM[3]-30) end
    end
  end
end
-- scattered inlet foam downstream (sparser than before)
for i = 1, 30 do
  local cx, cy = math.floor(nrand()*90), math.floor(nrand()*120)
  if zone_at(cx,cy) == 'W' and water_dist(cx,cy) <= 1 then
    px(IMGS[water], cx, cy, FOAM[1], FOAM[2], FOAM[3])
  end
end

-- ---------- shore ring: olive band 1-2 cells outside water ----------
for y = 0, H-1 do for x = 0, W-1 do
  local z = zone_at(x,y)
  if z ~= 'W' then
    local d = water_dist(x,y)
    if d == 1 then
      local c = (h2(x,y,11) < 0.4) and SHORE_DARK or SHORE_OLIVE
      px(IMGS[shore], x, y, c[1], c[2], c[3])
    end
  end
end end

-- ---------- rim stones: packed pebbles straddling the waterline ----------
-- a px qualifies if it sits within ~10px of a water cell on the dry side
local function near_water_px(x, y)
  for dx=-10,10,5 do for dy=-10,10,5 do
    if zone_at_raw(x+dx, y+dy) == 'W' then return true end
  end end
  return false
end
for y = 0, H-1 do for x = 0, W-1 do
  if zone_at_raw(x,y) ~= 'W' and near_water_px(x, y) and h2(x, y, 21) < 0.38 then
      -- stone: 3px wide, lit top / dark base
      px(IMGS[rim], x-1, y-1, RIM_MID[1], RIM_MID[2], RIM_MID[3])
      px(IMGS[rim], x,   y-1, RIM_LIT[1], RIM_LIT[2], RIM_LIT[3])
      px(IMGS[rim], x+1, y-1, RIM_MID[1], RIM_MID[2], RIM_MID[3])
      px(IMGS[rim], x-1, y,   RIM_MID[1], RIM_MID[2], RIM_MID[3])
      px(IMGS[rim], x,   y,   RIM_LIT[1], RIM_LIT[2], RIM_LIT[3])
      px(IMGS[rim], x+1, y,   RIM_MID[1], RIM_MID[2], RIM_MID[3])
      px(IMGS[rim], x,   y+1, RIM_DARK[1], RIM_DARK[2], RIM_DARK[3])
  end
end end

-- ---------- shade vignette: treeline foot + map corners ----------
for y = 0, H-1 do for x = 0, W-1 do
  if zone_at(x,y) == 'G' then
    local d_top = y
    local corner = math.min(x, W-1-x) + math.min(y, H-1-y)*0.6
    local a = 0
    if d_top < 64 then a = math.floor((64 - d_top) * 1.6) end
    if corner < 90 then a = math.max(a, math.floor((90 - corner) * 0.8)) end
    if a > 0 then px(IMGS[shade], x, y, SHADE[1], SHADE[2], SHADE[3], math.min(a, 110)) end
  end
end end

despeckle(IMGS[grass])
despeckle(IMGS[dirt])

-- ---------- bake cels, flatten, save ----------
for _, l in ipairs({water, grass, dirt, shore, rim, shade, detail}) do
  spr:newCel(l, 1, IMGS[l], Point(0, 0))
end
spr:saveAs(ase_out)
zones.isVisible = false
spr:flatten()
spr:saveCopyAs(png_out)
print("PAINT OK -> " .. ase_out)
