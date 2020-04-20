local _, mpath = ...
local M = {dir = mpath:gsub("init.lua$", "")}

local core    = require "core"
local style   = require "core.style"
local common  = require "core.common"
local command = require "core.command"


local _sf = string.format
local _mf = math.floor

local split = function(s)
	local args = {}
	for a in string.gmatch(s, "%S+") do
	   table.insert(args, a)
	end
	return args
end

local clamp = function(x, min, max)
	if x > max then return max end
	if x < min then return min end
	return x
end

-- from a (m=0) to b (m=1) ; a, b in [0, 1]
local mix = function(m, a, b)
	if m == 0 then return a end
	if m == 1 then return b end
	return clamp((1 - m) * a + m * b, 0, 1)
end

local adjmix = function(m, x, min, max)
	if m > 1 then return mix(m - 1, x, max) end
	return mix(m, min, x)
end

-- from 0 (m=0) to a (m=1) to 1 (m=2); a in [0, 1]
local adj = function(m, a)
	if m == 1 then return a end
	m = clamp(m, 0, 2)
	if m < 1 then
		return m * a
	else
		return (2 - m) * a + (m - 1)
	end
end

-- r, g, b in [0, 255]
local to_hsl = function(r, g, b)
	--r, g, b = clamp(r, 0, 255), clamp(g, 0, 255), clamp(b, 0, 255)
	r, g, b = r / 0xFF, g / 0xFF, b / 0xFF
	local max, min = math.max(r, g, b), math.min(r, g, b)
	if max == min then return 0, 0, min end

	local l, d = max + min, max - min
	local s, h = d / (l > 1 and (2 - l) or l)
	l = l / 2
	if max == r then
		h = (g - b) / d
		if g < b then h = h + 6 end
	elseif max == g then
		h = (b - r) / d + 2
	else
		h = (r - g) / d + 4
	end
	return h, s, l
end

local FF = function(a) return _mf(a * 0xFF) end

-- h in [0, 6], s in [0, 1], l in [0,1]
local to_rgb = function(h, s, l)
	--h, s, l = h % 6, clamp(s, 0, 1), clamp(l, 0, 1)
	if s == 0 then l = FF(l) return l,l,l end

	local c, m
	if l > 0.5 then c = (2 - 2 * l) * s
	else c = (2 * l) * s end
	m = l - c / 2

	local r, g, b
	if     h < 1 then b, r, g = 0, c, c * h
	elseif h < 2 then b, g, r = 0, c, c * (2 - h)
	elseif h < 3 then r, g, b = 0, c, c * (h - 2)
	elseif h < 4 then r, b, g = 0, c, c * (4 - h)
	elseif h < 5 then g, b, r = 0, c, c * (h - 4)
	else              g, r, b = 0, c, c * (6 - h)
	end
	return FF(r + m), FF(g + m), FF(b + m)
end

local toRGB = function(t, alpha)
	local r, g, b = to_rgb(t[1], t[2], t[3])
	return {r, g, b, alpha or 0xFF}
end

local rgbstr_to_hsl = function(s)
	local r, g, b = string.match(s, '#?(%x%x)(%x%x)(%x%x)')
	if r == nil then return end
	return to_hsl(tonumber(r, 16), tonumber(g, 16), tonumber(b, 16))
end

local hsl_to_rgbstr = function(h, s, l)
	return _sf('#%02x%02x%02x', to_rgb(h, s, l))
end

local remapper = {}

remapper['.yaml'] = {
	entry = '^%s*([%w]+)%s*:%s*"([^"]-)"',
	map   = {
		scheme = 'name',
		author = 'author',
		base00 = 'back',
		base01 = 'lnback',
		base02 = 'whitespace',
		base03 = 'comment',
		base04 = 'lnfore',
		base05 = 'fore',
		base06 = 'operator',
		base07 = 'highlight',
		base08 = 'variable',
		base09 = 'number',
		base0A = 'class',
		base0B = 'string',
		base0C = 'support',
		base0D = 'function',
		base0E = 'keyword',
		base0F = 'embed',
	},
}

remapper['.json']  = {
	entry = '^%s*"([%w_]+)"%s*:%s*"#?([^"]-)"',
	map   = {
		name           = 'name',
		author         = 'author',
		background     = 'back',
		line_highlight = 'lnback',
		invisibles     = 'whitespace',
		comment        = 'comment',
		docblock       = 'lnfore',
		foreground     = 'fore',
		caret          = 'operator',
		selection_foreground = 'highlight',
		fifth          = 'variable',
		number         = 'number',
		second         = 'class',
		['string']     = 'string',
		first          = 'support',
		third          = 'function',
		fourth         = 'keyword',
		brackets       = 'embed',
	},
}

local parse_scheme = function(path, ext)
	if remapper[ext] == nil then return end;
	local map, entry = remapper[ext].map, remapper[ext].entry
	local vars = {}
	local key, value
	local h, s, l
	for line in io.lines(path) do
		key, value = string.match(line, entry)
		key = key and map[key]
		if key ~= nil then
			h, s, l = rgbstr_to_hsl(value)
			if h ~= nil then  vars[key] = {h, s, l}
			else vars[key] = value end
		end
	end
	for id, k in pairs(map) do
		if vars[k] == nil then
		core.error('missing value %s in %s', id, path) return end
	end
	return vars
end

local adjust_colors = function(t, sm, lm)
	local h, s, l
	for k, v in pairs(t) do
		if type(v) == 'table' then
			v[2] = adj(sm, v[2])
			v[3] = adj(lm, v[3])
		end
	end
end

--[[
local dim_color = function(t, name, sdim, ldim)
	local c = t[name]
	sdim = sdim or 0.75 --M.dimSaturation
	ldim = ldim or 0.75 --M.dimLightness
	local r, g, b = to_rgb(c[1], adj(sdim, c[2]),
		adjmix(ldim, c[3], t.back[3], t.fore[3]))
	return {r, g, b, 0xFF}
end
]]

local isfile = function(fname)
	local f = io.open(fname, 'r')
	if f then io.close(f) return true end
	return false
end

local locate_scheme = function(pdir, name)
	if isfile(pdir .. name) then return name end

	local search = {'%s.yaml', 'base16/%s', 'base16/%s.yaml',
		'%s.json', 'daylerees/%s', 'daylerees/%s.json'}

	local s
	for i, fmt in ipairs(search) do
		s = _sf(fmt, name)
		if isfile(pdir .. s) then return s end
	end
end

local apply_scheme = function(name)
	local schemedir = M.dir .. 'schemes/'

	local sadj = M.saturation or 1.0
	local ladj = M.lightness  or 1.0
	--local wadj = M.whitespace or 0.5

	local scheme_path = locate_scheme(schemedir, name)
	if not scheme_path then
		core.error('File "%s" cannot be found', name)
		return
	end

	name = scheme_path
	scheme_path = schemedir .. scheme_path

	local filetype = scheme_path:sub(-5)
	local vars = parse_scheme(scheme_path, filetype)
	if vars == nil then
		core.error('Filetype "%s" is not supported', filetype)
		return
	end

	adjust_colors(vars, sadj, ladj)
	--local ws = vars.whitespace
	--vars.whitespace = {ws[1], ws[2], adjmix(wadj, ws[3], vars.back[3], vars.fore[3])}

	style.background     = toRGB(vars["back"])
	style.background2    = toRGB(vars["back"])
	style.background3    = toRGB(vars["lnback"])
	style.text           = toRGB(vars["fore"])
	style.caret          = toRGB(vars["fore"])
	style.accent         = toRGB(vars["variable"])
	style.dim            = toRGB(vars["comment"])
	style.divider        = toRGB(vars["whitespace"])
	style.selection      = toRGB(vars["fore"], 0x30)
	style.line_number    = toRGB(vars["lnfore"], 0x80)
	style.line_number2   = toRGB(vars["lnfore"])
	style.line_highlight = toRGB(vars["class"], 0x10)
	style.scrollbar      = toRGB(vars["lnback"])
	style.scrollbar2     = toRGB(vars["variable"])

	style.syntax["normal"]   = toRGB(vars["operator"])
	style.syntax["symbol"]   = toRGB(vars["fore"])
	style.syntax["comment"]  = toRGB(vars["comment"])
	style.syntax["keyword"]  = toRGB(vars["keyword"])
	style.syntax["keyword2"] = toRGB(vars["variable"])
	style.syntax["number"]   = toRGB(vars["number"])
	style.syntax["literal"]  = toRGB(vars["class"])
	style.syntax["string"]   = toRGB(vars["string"])
	style.syntax["operator"] = toRGB(vars["operator"])
	style.syntax["function"] = toRGB(vars["function"])

	M.current = name
end

local change_theme = function()
	local name = M.name:lower():gsub(' ','-'):gsub('[,]','')
	apply_scheme(name)
	core.log_quiet('Using "%s"', M.current)
end

local cycle_theme = function(step)
	local name = M.current
	local list = dofile(M.dir..'scheme_list.lua')
	local list_len = #list
	local list_cur = 0
	for i, v in ipairs(list) do
		if v == name then
			list_cur = i
			break
		end
	end
	if list_cur == 0 then
		list_cur = 1
	end
	list_cur = 1 + ((list_cur + step - 1) % list_len)
	name = list[list_cur]
	apply_scheme(name)
	core.log('Using "%s" %i/%i', M.current, list_cur, list_len)
end

M.apply = change_theme


command.add(nil, {
	["theme:change"] = change_theme,
	["theme:next"] = function() cycle_theme( 1) end,
	["theme:prev"] = function() cycle_theme(-1) end,

})

return M
