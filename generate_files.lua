#! /usr/bin/env luajit

-- creates scheme_list.lua
local cmd =
[[find schemes/ -name '*.json' -o -name '*.yaml'|sort]]
local gen_scheme_list_lua = function()
	local f = io.open('scheme_list.lua', 'w')
	f:write('-- This is an auto-generated file\n')
	f:write('return {\n')
    local pfile = io.popen(cmd)
    for filename in pfile:lines() do
        f:write("\t'" .. filename:gsub("^schemes/", "") .. "',\n")
    end
    pfile:close()
	f:write('}\n')
    f:close()
end

gen_scheme_list_lua()
