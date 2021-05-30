-- lite-xl 1.16
local modname, mpath = ...
mpath = mpath:gsub("init.lua$", "")

local current_theme

local core    = require "core"
local style   = require "core.style"
local common  = require "core.common"
local command = require "core.command"
local config  = require "core.config"

local _fmt = string.format

local function _get_files(path, subpath, t)
	t = t or {}
	subpath = subpath or ""
	local currentpath = _fmt("%s/%s", path, subpath)
	local size_limit = 8192
	local all = system.list_dir(currentpath)

	for _, file in ipairs(all) do
		if not file:find("^%.") then
			local info = system.get_file_info(currentpath .. file)
			if info then
				if info.type == "dir" then
					_get_files(path, _fmt("%s%s/", subpath, file), t)
				elseif file:match("%.yaml$") or file:match("%.json$") then
					if info.size < size_limit then
						table.insert(t, subpath .. file)
					end
				end
			end
		end
	end
	return t
end

local function get_files(path)
	return _get_files(path, "", {})
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

local FF = function(a) return math.floor(a * 0xFF) end

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
			return nil, _fmt('missing %s field', id)
		end
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
	sdim = sdim or 0.75 --config.theme_dimsaturation
	ldim = ldim or 0.75 --config.theme_dimlightness
	local r, g, b = to_rgb(c[1], adj(sdim, c[2]),
		adjmix(ldim, c[3], t.back[3], t.fore[3]))
	return {r, g, b, 0xFF}
end
]]

local isfile = function(fname)
	local info = system.get_file_info(fname)
	return info and info.type == "file"
end

local locate_scheme = function(pdir, name)
	local path = pdir .. name
	if isfile(path) then return name, path end

	local search = {'%s.yaml', 'base16/%s', 'base16/%s.yaml',
		'%s.json', 'daylerees/%s', 'daylerees/%s.json'}

	local s
	for i, fmt in ipairs(search) do
		s = string.format(fmt, name)
		path = pdir .. s
		if isfile(path) then return s, path end
	end
end

local apply_scheme = function(name)
	local sadj = config.theme_saturation or 1.00
	local ladj = config.theme_lightness  or 1.00
	local wadj = config.theme_whitespace or 0.65

	local scheme_name, scheme_path = locate_scheme(config.theme_dir, name)
	if not scheme_path then
		return nil, _fmt('Theme "%s" cannot be found', name)
	end

	local filetype = scheme_path:sub(-5)
	local vars, err_msg = parse_scheme(scheme_path, filetype)
	if vars == nil then
		return nil, _fmt('File "%s" is not supported (%s)', name, err_msg)
	end

	adjust_colors(vars, sadj, ladj)

	style.background     = toRGB(vars["back"])
	style.background2    = toRGB(vars["back"])
	style.background3    = toRGB(vars["lnback"])
	style.text           = toRGB(vars["fore"])
	style.caret          = toRGB(vars["lnfore"])
	style.accent         = toRGB(vars["variable"])
	style.dim            = toRGB(vars["comment"])
	style.divider        = toRGB(vars["whitespace"])
	style.selection      = toRGB(vars["fore"], 0x30)
	style.line_number    = toRGB(vars["lnfore"], 0x80)
	style.line_number2   = toRGB(vars["lnfore"])
	style.line_highlight = toRGB(vars["class"], 0x10)
	style.scrollbar      = toRGB(vars["whitespace"])
	style.scrollbar2     = toRGB(vars["variable"])

	style.syntax["normal"]   = toRGB(vars["operator"])
	style.syntax["symbol"]   = toRGB(vars["fore"])
	style.syntax["comment"]  = toRGB(vars["comment"])
	style.syntax["keyword"]  = toRGB(vars["keyword"])
	style.syntax["keyword2"] = toRGB(vars["variable"])
	style.syntax["number"]   = toRGB(vars["number"])
	style.syntax["literal"]  = toRGB(vars["support"])
	style.syntax["string"]   = toRGB(vars["string"])
	style.syntax["operator"] = toRGB(vars["operator"])
	style.syntax["function"] = toRGB(vars["function"])
	
	local ws = vars.whitespace
	ws = {ws[1], ws[2], adjmix(wadj, ws[3], vars.back[3], vars.fore[3])}
	--style.syntax["whitespace"] = toRGB(ws)
	style.guide = toRGB(ws)
	style.syntax["whitespace"] = common.lerp(style.syntax["comment"], style.background, 0.5)
	

	current_theme = scheme_name
	return true
end

local change_theme = function(init)
	local name = config.theme_name
	if not name then
		if not init then core.error('config.theme_name is not set') end
		return 
	end
	
	name = name:lower():gsub(' ','-'):gsub('[,]','')
	local ok, err_msg = apply_scheme(name)
	if not ok then
		core.error(err_msg)
	else
		core.log('Using "%s"', current_theme)
	end
end

local cycle_theme = function(step)
	local name = current_theme
	local list = config.theme_list
	local list_len = #list
	local list_cur = 1
	if name then
		for i, v in ipairs(list) do
			if v == name then
				list_cur = i
				break
			end
		end
		list_cur = 1 + ((list_cur + step - 1) % list_len)
	else
		list_cur = step >= 0 and 1 or list_len
	end
	name = list[list_cur]
	
	local ok, err_msg = apply_scheme(name)
	if not ok then
		table.remove(list, list_cur)
		core.error(err_msg)
	else
		core.log('Using %i/%i: "%s"', list_cur, list_len, current_theme)
	end
end

local modinit = function()
	if not config.theme_dir then config.theme_dir = mpath .. "schemes/" end
	if not config.theme_listfile then config.theme_listfile = mpath .. "scheme_list.lua" end

	local list
	if type(config.theme_name) == "table" then -- use the user defined list
		list = {}
		for i, name in ipairs(config.theme_name) do
			name = name:lower():gsub(' ','-'):gsub('[,]','')
			name = locate_scheme(config.theme_dir, name)
			if name then table.insert(list, name) end
		end
		config.theme_name = list[1]
	elseif config.theme_usefile then -- OR use a list file
		list = dofile(config.theme_listfile)
	else -- OR scan the theme directory
		list = get_files(config.theme_dir)
		table.sort(list)
		if config.theme_savefile then -- save the list file
			local f = io.open(config.theme_listfile, "w")
			f:write("-- This is an auto-generated file\nreturn {\n")
			for i, name in ipairs(list) do
				f:write("\t'") f:write(name) f:write("',\n")
			end
			f:write("}\n")
			f:close()
		end
	end
	config.theme_list = list
	
	change_theme(true)
	core.redraw = true
end

core.add_thread(modinit)


local C2S = function(content, name, t)
	if not t then return end
	local r, g, b, a = t[1], t[2], t[3], t[4]
	local s
	if not a or a == 255 then s = _fmt("%s = {%i, %i, %i}", name, r, g, b)
	else s = _fmt("%s = {%i, %i, %i, %i}", name, r, g, b, a) end
	table.insert(content, s)
end


local write_theme = function()
	local name = current_theme
	local sadj = config.theme_saturation
	local ladj = config.theme_lightness
	local wadj = config.theme_whitespace

	local content = {"-- This is an auto-generated file"}
	if name then table.insert(content, _fmt("-- theme: %s", name)) end
	if sadj then table.insert(content, _fmt("-- saturation: %s", sadj)) end
	if ladj then table.insert(content, _fmt("-- lightness: %s" , ladj)) end
	if wadj then table.insert(content, _fmt("-- whitespace: %s", wadj)) end

	table.insert(content, "")
	C2S(content, "style.background"    , style.background    )
	C2S(content, "style.background2"   , style.background2   )
	C2S(content, "style.background3"   , style.background3   )
	C2S(content, "style.text"          , style.text          )
	C2S(content, "style.caret"         , style.caret         )
	C2S(content, "style.accent"        , style.accent        )
	C2S(content, "style.dim"           , style.dim           )
	C2S(content, "style.divider"       , style.divider       )
	C2S(content, "style.selection"     , style.selection     )
	C2S(content, "style.line_number"   , style.line_number   )
	C2S(content, "style.line_number2"  , style.line_number2  )
	C2S(content, "style.line_highlight", style.line_highlight)
	C2S(content, "style.scrollbar"     , style.scrollbar     )
	C2S(content, "style.scrollbar2"    , style.scrollbar2    )
	table.insert(content, "")
	C2S(content, 'style.syntax["normal"]'  , style.syntax["normal"]  )
	C2S(content, 'style.syntax["symbol"]'  , style.syntax["symbol"]  )
	C2S(content, 'style.syntax["comment"]' , style.syntax["comment"] )
	C2S(content, 'style.syntax["keyword"]' , style.syntax["keyword"] )
	C2S(content, 'style.syntax["keyword2"]', style.syntax["keyword2"])
	C2S(content, 'style.syntax["number"]'  , style.syntax["number"]  )
	C2S(content, 'style.syntax["literal"]' , style.syntax["literal"] )
	C2S(content, 'style.syntax["string"]'  , style.syntax["string"]  )
	C2S(content, 'style.syntax["operator"]', style.syntax["operator"])
	C2S(content, 'style.syntax["function"]', style.syntax["function"])
	
	C2S(content, 'style.syntax["whitespace"]', style.syntax["whitespace"])
	C2S(content, 'style.guide', style.guide)

	--local savefile = name:gsub("%.json$", ""):gsub("%.yaml$", ""):gsub("/", "_")
	local savefile = "saved_scheme.lua"
	
	local f = io.open(mpath .. savefile, "w")
	for i, line in ipairs(content) do
		f:write(line) f:write("\n")
	end
	f:close()
	
	return
end

command.add(nil, {
	["theme:change"] = change_theme,
	["theme:next"] = function() cycle_theme( 1) end,
	["theme:prev"] = function() cycle_theme(-1) end,

	["theme:write"] = write_theme,

})
