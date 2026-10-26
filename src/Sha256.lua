-- SHA-256, Lua 5.1+. No external module and no dynamic code execution.
-- The asynchronous interface yields every 16 blocks to keep Mudlet responsive.
kozojeb_sha256 = {}
local S = kozojeb_sha256
local MOD = 4294967296
local floor = math.floor
local xor4, and4 = {}, {}
for a=0,15 do
  xor4[a], and4[a] = {}, {}
  for b=0,15 do
    local x, y, xor, band, place = a, b, 0, 0, 1
    for _=1,4 do
      local xb, yb = x%2, y%2
      if xb ~= yb then xor = xor + place end
      if xb == 1 and yb == 1 then band = band + place end
      x, y, place = floor(x/2), floor(y/2), place*2
    end
    xor4[a][b], and4[a][b] = xor, band
  end
end
local function op(a,b,lookup)
  local result, place = 0,1
  for _=1,8 do
    result = result + lookup[a%16][b%16]*place
    a,b,place = floor(a/16),floor(b/16),place*16
  end
  return result
end
local function bxor(a,b,c)
  local result = op(a,b,xor4)
  return c and op(result,c,xor4) or result
end
local function band(a,b) return op(a,b,and4) end
local function rshift(a,n) return floor(a/2^n) end
local function ror(a,n) return (rshift(a,n) + (a%2^n)*2^(32-n))%MOD end
local constants = {
  0x428a2f98,0x71374491,0xb5c0fbcf,0xe9b5dba5,0x3956c25b,0x59f111f1,0x923f82a4,0xab1c5ed5,
  0xd807aa98,0x12835b01,0x243185be,0x550c7dc3,0x72be5d74,0x80deb1fe,0x9bdc06a7,0xc19bf174,
  0xe49b69c1,0xefbe4786,0x0fc19dc6,0x240ca1cc,0x2de92c6f,0x4a7484aa,0x5cb0a9dc,0x76f988da,
  0x983e5152,0xa831c66d,0xb00327c8,0xbf597fc7,0xc6e00bf3,0xd5a79147,0x06ca6351,0x14292967,
  0x27b70a85,0x2e1b2138,0x4d2c6dfc,0x53380d13,0x650a7354,0x766a0abb,0x81c2c92e,0x92722c85,
  0xa2bfe8a1,0xa81a664b,0xc24b8b70,0xc76c51a3,0xd192e819,0xd6990624,0xf40e3585,0x106aa070,
  0x19a4c116,0x1e376c08,0x2748774c,0x34b0bcb5,0x391c0cb3,0x4ed8aa4a,0x5b9cca4f,0x682e6ff3,
  0x748f82ee,0x78a5636f,0x84c87814,0x8cc70208,0x90befffa,0xa4506ceb,0xbef9a3f7,0xc67178f2,
}
local function word(n)
  return string.char(floor(n/16777216)%256, floor(n/65536)%256, floor(n/256)%256, n%256)
end
function S.new(data)
  local bits = #data*8
  return {data=data .. "\128" .. string.rep("\0", (55-#data)%64)
    .. word(floor(bits/MOD)) .. word(bits%MOD), offset=1,
    h={0x6a09e667,0xbb67ae85,0x3c6ef372,0xa54ff53a,0x510e527f,0x9b05688c,0x1f83d9ab,0x5be0cd19}}
end
function S.step(state, blocks)
  for _=1,blocks or 16 do
    if state.offset > #state.data then return true end
    local w, hash, offset = {}, state.h, state.offset
    for j=0,15 do
      local a,b,c,d = state.data:byte(offset+j*4, offset+j*4+3)
      w[j] = a*16777216+b*65536+c*256+d
    end
    for j=16,63 do
      local a,b=w[j-15],w[j-2]
      local s0=bxor(ror(a,7),ror(a,18),rshift(a,3))
      local s1=bxor(ror(b,17),ror(b,19),rshift(b,10))
      w[j]=(w[j-16]+s0+w[j-7]+s1)%MOD
    end
    local a,b,c,d,e,f,g,h=hash[1],hash[2],hash[3],hash[4],hash[5],hash[6],hash[7],hash[8]
    for j=0,63 do
      local s1=bxor(ror(e,6),ror(e,11),ror(e,25))
      local choose=bxor(band(e,f),band(MOD-1-e,g))
      local t1=(h+s1+choose+constants[j+1]+w[j])%MOD
      local s0=bxor(ror(a,2),ror(a,13),ror(a,22))
      local majority=bxor(band(a,b),band(a,c),band(b,c))
      local t2=(s0+majority)%MOD
      h,g,f,e,d,c,b,a=g,f,e,(d+t1)%MOD,c,b,a,(t1+t2)%MOD
    end
    local values={a,b,c,d,e,f,g,h}
    for j=1,8 do hash[j]=(hash[j]+values[j])%MOD end
    state.offset=offset+64
  end
  return state.offset > #state.data
end
function S.finish(state)
  local result={}
  for _,value in ipairs(state.h) do result[#result+1]=string.format("%08x",value) end
  return table.concat(result)
end
function S.digest(data)
  local state=S.new(data)
  while not S.step(state,16) do end
  return S.finish(state)
end
