-- VC CRAFT Simplex Noise
local Noise = {}

local floor = math.floor
local abs = math.abs

-- Seeded RNG
function Noise.sRng(s)
	local rng = {s = s % 2147483647}
	if rng.s <= 0 then rng.s = 1 end
	function rng:n()
		self.s = (self.s * 16807) % 2147483647
		return (self.s - 1) / 2147483646
	end
	return rng
end

-- Deterministic hash
function Noise.dh(x, z)
	local h = bit32.bxor(bit32.band(x * 2654435761, 0xFFFFFFFF), bit32.band(z * 2246822519, 0xFFFFFFFF))
	h = bit32.band(bit32.bxor(bit32.rshift(h, 16), h) * 0x45d9f3b, 0xFFFFFFFF)
	h = bit32.band(bit32.bxor(bit32.rshift(h, 16), h) * 0x45d9f3b, 0xFFFFFFFF)
	return bit32.bxor(bit32.rshift(h, 16), h)
end

function Noise.dh01(x, z)
	return (Noise.dh(x, z) % 65536) / 65535
end

-- Noise class
local NoiseInst = {}
NoiseInst.__index = NoiseInst

function Noise.new(seed)
	local self = setmetatable({}, NoiseInst)
	local p = {}
	for i = 0, 255 do p[i] = i end
	local rng = Noise.sRng(seed or 1)
	for i = 255, 1, -1 do
		local j = floor(rng:n() * (i + 1))
		p[i], p[j] = p[j], p[i]
	end
	self.p = {}
	for i = 0, 511 do
		self.p[i] = p[i % 256]
	end
	return self
end

local G2 = {}
G2[0]={1,1} G2[1]={-1,1} G2[2]={1,-1} G2[3]={-1,-1}
G2[4]={1,0} G2[5]={-1,0} G2[6]={0,1} G2[7]={0,-1}
G2[8]={1,1} G2[9]={-1,1} G2[10]={1,-1} G2[11]={-1,-1}

function NoiseInst:n2(x, y)
	local F = 0.366025
	local G = 0.211325
	local s = (x + y) * F
	local i = floor(x + s)
	local j = floor(y + s)
	local t = (i + j) * G
	local x0 = x - (i - t)
	local y0 = y - (j - t)
	local i1, j1
	if x0 > y0 then i1 = 1; j1 = 0
	else i1 = 0; j1 = 1 end
	local x1 = x0 - i1 + G
	local y1 = y0 - j1 + G
	local x2 = x0 - 1 + 2 * G
	local y2 = y0 - 1 + 2 * G
	local ii = i % 256
	local jj = j % 256
	if ii < 0 then ii = ii + 256 end
	if jj < 0 then jj = jj + 256 end
	local gi0 = self.p[ii + self.p[jj]] % 12
	local gi1 = self.p[ii + i1 + self.p[jj + j1]] % 12
	local gi2 = self.p[ii + 1 + self.p[jj + 1]] % 12
	local n0, n1, n2 = 0, 0, 0
	local t0 = 0.5 - x0*x0 - y0*y0
	if t0 > 0 then t0 = t0 * t0; n0 = t0 * t0 * (G2[gi0][1]*x0 + G2[gi0][2]*y0) end
	local t1 = 0.5 - x1*x1 - y1*y1
	if t1 > 0 then t1 = t1 * t1; n1 = t1 * t1 * (G2[gi1][1]*x1 + G2[gi1][2]*y1) end
	local t2 = 0.5 - x2*x2 - y2*y2
	if t2 > 0 then t2 = t2 * t2; n2 = t2 * t2 * (G2[gi2][1]*x2 + G2[gi2][2]*y2) end
	return 70 * (n0 + n1 + n2)
end

local G3 = {
	{1,1,0},{-1,1,0},{1,-1,0},{-1,-1,0},
	{1,0,1},{-1,0,1},{1,0,-1},{-1,0,-1},
	{0,1,1},{0,-1,1},{0,1,-1},{0,-1,-1}
}

function NoiseInst:n3(x, y, z)
	local F = 1/3
	local G = 1/6
	local s = (x + y + z) * F
	local i = floor(x + s)
	local j = floor(y + s)
	local k = floor(z + s)
	local t = (i + j + k) * G
	local x0 = x - (i - t)
	local y0 = y - (j - t)
	local z0 = z - (k - t)
	local i1, j1, k1, i2, j2, k2
	if x0 >= y0 then
		if y0 >= z0 then i1=1;j1=0;k1=0; i2=1;j2=1;k2=0
		elseif x0 >= z0 then i1=1;j1=0;k1=0; i2=1;j2=0;k2=1
		else i1=0;j1=0;k1=1; i2=1;j2=0;k2=1 end
	else
		if y0 < z0 then i1=0;j1=0;k1=1; i2=0;j2=1;k2=1
		elseif x0 < z0 then i1=0;j1=1;k1=0; i2=0;j2=1;k2=1
		else i1=0;j1=1;k1=0; i2=1;j2=1;k2=0 end
	end
	local x1=x0-i1+G; local y1=y0-j1+G; local z1=z0-k1+G
	local x2=x0-i2+2*G; local y2=y0-j2+2*G; local z2=z0-k2+2*G
	local x3=x0-1+0.5; local y3=y0-1+0.5; local z3=z0-1+0.5
	local ii = i % 256; local jj = j % 256; local kk = k % 256
	if ii < 0 then ii = ii + 256 end
	if jj < 0 then jj = jj + 256 end
	if kk < 0 then kk = kk + 256 end
	local p = self.p
	local gi0 = p[ii + p[jj + p[kk]]] % 12
	local gi1 = p[ii+i1 + p[jj+j1 + p[kk+k1]]] % 12
	local gi2 = p[ii+i2 + p[jj+j2 + p[kk+k2]]] % 12
	local gi3 = p[ii+1  + p[jj+1  + p[kk+1 ]]] % 12
	local n0,n1,n2,n3 = 0,0,0,0
	local t0 = 0.6-x0*x0-y0*y0-z0*z0
	if t0>0 then t0=t0*t0; n0=t0*t0*(G3[gi0+1][1]*x0+G3[gi0+1][2]*y0+G3[gi0+1][3]*z0) end
	local t1 = 0.6-x1*x1-y1*y1-z1*z1
	if t1>0 then t1=t1*t1; n1=t1*t1*(G3[gi1+1][1]*x1+G3[gi1+1][2]*y1+G3[gi1+1][3]*z1) end
	local t2 = 0.6-x2*x2-y2*y2-z2*z2
	if t2>0 then t2=t2*t2; n2=t2*t2*(G3[gi2+1][1]*x2+G3[gi2+1][2]*y2+G3[gi2+1][3]*z2) end
	local t3 = 0.6-x3*x3-y3*y3-z3*z3
	if t3>0 then t3=t3*t3; n3=t3*t3*(G3[gi3+1][1]*x3+G3[gi3+1][2]*y3+G3[gi3+1][3]*z3) end
	return 32 * (n0 + n1 + n2 + n3)
end

Noise.NoiseInst = NoiseInst

return Noise
