-- VC CRAFT Biome Definitions and Generation
local BiomeData = {}
local BT = require(script.Parent.BlockTypes)
local B = BT.B
local Noise = require(script.Parent.Noise)

-- Biome IDs
local BI = {
	OC = 0, BE = 1, SA_PLAINS = 2, NICSHADE = 3, CAMGROVE = 4,
	WATCHER = 5, VC_SUBURB = 6, VC_BADLANDS = 7, MO = 8, DRY_COAST = 9,
	RIO_LAGOON = 10, GARFBOT_CITY = 11, DISCORD_DEEP = 12, TAIGA = 13,
	SNOWY = 14, PROPS_ISLAND = 15, VCLANTIS = 16, VOLCANO = 17,
	PLAINS = 18, REDWOOD = 19
}
BiomeData.BI = BI

-- Biome definitions
-- bH=base height, a=amplitude, sf=surface block, su=subsurface block
-- tr=tree type, tc=tree chance, structs=possible structures, ca=cactus chance
local BDt = {
	[BI.OC]          = {n="Ocean",             bH=82,  a=20, sf=B.SAND,         su=B.SAND},
	[BI.BE]          = {n="Beach",             bH=128, a=4,  sf=B.SAND,         su=B.SAND},
	[BI.SA_PLAINS]   = {n="San Antonio Plains",bH=140, a=10, sf=B.DRY_GRASS,    su=B.DIRT,    tr="acacia", tc=0.003, structs={"condo","statue","waffle","broken_tower","house","restaurant","stadium"}},
	[BI.NICSHADE]    = {n="Nicshade Forest",   bH=146, a=12, sf=B.GRASS,        su=B.DIRT,    tr="nicshade",tc=0.055,structs={"shrine","cabin","watchtower"}},
	[BI.CAMGROVE]    = {n="Camgrove",          bH=150, a=14, sf=B.GRASS,        su=B.DIRT,    tr="spruce", tc=0.04, structs={"cabin","watchtower","chapel","shrine","temple"}},
	[BI.WATCHER]     = {n="Watcher Desert",    bH=144, a=12, sf=B.WATCHER_SAND, su=B.SSTON,   ca=0.003,  structs={"tower_ruin","broken_tower","shrine","monument","temple"}},
	[BI.VC_SUBURB]   = {n="VC Suburbia",       bH=140, a=8,  sf=B.GRASS,        su=B.DIRT,    structs={"house","house","house","waffle","restaurant","mall","arcade","school","gomp"}},
	[BI.VC_BADLANDS] = {n="VC Badlands",       bH=160, a=36, sf=B.CANYON_STONE, su=B.RSAND,   structs={"monument","broken_tower","shrine","tower_ruin"}},
	[BI.MO]          = {n="Mountains",         bH=180, a=50, sf=B.STONE,        su=B.STONE,   tr="spruce",tc=0.005},
	[BI.DRY_COAST]   = {n="Dry Coast",         bH=132, a=6,  sf=B.SAND,         su=B.SSTON,   structs={"boardwalk","condo","restaurant"}},
	[BI.RIO_LAGOON]  = {n="Rio Lagoon",        bH=126, a=4,  sf=B.GRASS,        su=B.MUD,     tr="jungle",tc=0.09, structs={"boardwalk"}},
	[BI.GARFBOT_CITY]= {n="Garfbot City",      bH=140, a=4,  sf=B.ASPHALT,      su=B.CONCRETE,structs={"tower","gomp"}},
	[BI.DISCORD_DEEP]= {n="Discord Depths",    bH=100, a=8,  sf=B.DARK_PANEL,   su=B.DEEP,    structs={"shrine","broken_tower"}},
	[BI.TAIGA]       = {n="Taiga",             bH=148, a=16, sf=B.GRASS,        su=B.DIRT,    tr="spruce",tc=0.035},
	[BI.SNOWY]       = {n="Snowy Plains",      bH=140, a=6,  sf=B.SNOW,         su=B.DIRT,    tr="spruce",tc=0.004},
	[BI.PROPS_ISLAND]= {n="Props Island",      bH=132, a=8,  sf=B.SAND,         su=B.SAND,    tr="jungle",tc=0.02, structs={"boardwalk","shrine","arcade"}},
	[BI.VCLANTIS]    = {n="VCLANTIS",          bH=76,  a=6,  sf=B.MARBLE,       su=B.SEA_MARBLE},
	[BI.VOLCANO]     = {n="Volcanic Wastes",   bH=170, a=55, sf=B.BASALT,       su=B.SCORCHED},
	[BI.PLAINS]      = {n="Plains",            bH=138, a=5,  sf=B.GRASS,        su=B.DIRT,    tr="oak",   tc=0.003,structs={"house","waffle","cabin"}},
	[BI.REDWOOD]     = {n="Redwood Forest",    bH=152, a=18, sf=B.GRASS,        su=B.DIRT,    tr="redwood",tc=0.045,structs={"cabin","shrine"}},
}
BiomeData.BDt = BDt

-- Noise instances (initialized per world seed)
local nT, nM, nE, nC, nD, nR, nS, nB

function BiomeData.initNoise(seed)
	nT = Noise.new(seed)
	nM = Noise.new(seed + 1)
	nE = Noise.new(seed + 2)
	nC = Noise.new(seed + 3)
	nD = Noise.new(seed + 4)
	nR = Noise.new(seed + 5)
	nS = Noise.new(seed + 6)
	nB = Noise.new(seed + 7)
end

BiomeData.getNoise = function()
	return nT, nM, nE, nC, nD, nR, nS, nB
end

-- Get biome for world coordinates
function BiomeData.bio(x, z)
	local t = nT:n2(x * 0.0004, z * 0.0004)
	local m = nM:n2(x * 0.0005 + 500, z * 0.0005 + 500)
	local c = nE:n2(x * 0.0003, z * 0.0003)
	local e = nE:n2(x * 0.0006, z * 0.0006)
	local s = nS:n2(x * 0.0002, z * 0.0002)

	-- Ocean / coast
	if c < -0.25 then
		local pi = nB:n2(x * 0.003, z * 0.003)
		if pi > 0.65 then return BI.PROPS_ISLAND end
		local vl = nS:n2(x * 0.002 + 999, z * 0.002 + 999)
		if vl > 0.8 and c < -0.35 then return BI.VCLANTIS end
		return BI.OC
	end
	if c < -0.15 then return BI.BE end

	-- Volcano
	if e > 0.55 and t > 0.2 and s > 0.7 then return BI.VOLCANO end
	-- Mountains
	if e > 0.5 then return BI.MO end
	-- Discord Depths
	if s < -0.6 and m < -0.1 and math.abs(t) < 0.35 and c > -0.15 and e < 0.3 then return BI.DISCORD_DEEP end
	-- Garfbot City
	if s > 0.75 and math.abs(t) < 0.15 and math.abs(m) < 0.2 then return BI.GARFBOT_CITY end

	if t > 0.35 then
		if m < -0.2 then return BI.VC_BADLANDS end
		if m < 0.15 then return BI.WATCHER end
		return BI.SA_PLAINS
	end
	if t > 0.1 then
		if c < -0.05 then return BI.DRY_COAST end
		if m > 0.35 then return BI.RIO_LAGOON end
		return BI.SA_PLAINS
	end
	if t < -0.3 then
		return m > 0.1 and BI.TAIGA or BI.SNOWY
	end
	if m < -0.3 then return BI.VC_SUBURB end
	if m < -0.15 then return BI.PLAINS end
	if m < -0.05 then return BI.CAMGROVE end
	if m < 0.1 then return BI.NICSHADE end
	if m < 0.25 and e > 0.2 then return BI.REDWOOD end
	if m < 0.25 then return BI.NICSHADE end
	return BI.RIO_LAGOON
end

-- Get terrain height for coordinates and biome
function BiomeData.htA(x, z, bi)
	local d = BDt[bi]
	local fl = math.floor
	local mn = math.min
	local abs = math.abs
	local WL = 124

	local h = d.bH + nE:n2(x*0.008, z*0.008)*d.a
		+ nD:n2(x*0.03, z*0.03)*(d.a*0.3)
		+ nD:n2(x*0.06, z*0.06)*(d.a*0.1)

	if bi == BI.GARFBOT_CITY then
		h = d.bH + nD:n2(x*0.02, z*0.02)*(d.a*0.15)
	elseif bi == BI.VC_SUBURB then
		h = d.bH + nD:n2(x*0.012, z*0.012)*(d.a*0.6)
			+ nE:n2(x*0.035, z*0.035)*(d.a*0.3)
			+ nD:n2(x*0.07, z*0.07)*(d.a*0.15)
	elseif bi == BI.MO then
		local ridge = abs(nR:n2(x*0.012, z*0.012))
		if ridge < 0.08 then h = h + 30*(1 - ridge/0.08) end
		h = h + nE:n2(x*0.025, z*0.025)*18 + abs(nD:n2(x*0.05, z*0.05))*12
	elseif bi == BI.VOLCANO then
		local coneDist = abs(nR:n2(x*0.003, z*0.003))
		if coneDist < 0.15 then h = h + 100*(1 - coneDist/0.15)
		elseif coneDist < 0.3 then h = h + 45*(1 - (coneDist-0.15)/0.15) end
		local ridge = abs(nR:n2(x*0.01, z*0.01))
		if ridge < 0.08 then h = h + 35*(1 - ridge/0.08) end
		h = h + abs(nE:n2(x*0.02, z*0.02))*20
		local craterN = nD:n2(x*0.006, z*0.006)
		if craterN > 0.6 and h > 220 then h = h - 40*(craterN-0.6)/0.4 end
		local cd = abs(nR:n2(x*0.003, z*0.003))
		if cd > 0.2 then h = h - (cd-0.2)*60 end
	elseif bi == BI.PLAINS then
		h = d.bH + nE:n2(x*0.006, z*0.006)*(d.a*0.8) + nD:n2(x*0.025, z*0.025)*(d.a*0.4)
	end

	local rv = abs(nR:n2(x*0.005, z*0.005))
	if rv < 0.03 and bi ~= BI.OC and bi ~= BI.BE then
		h = mn(h, WL - 1 + rv*30)
	end
	return fl(h)
end

return BiomeData
