# theme16
theme manager for [rxi/lite](https://github.com/rxi/lite) and [lite-xl](https://github.com/lite-xl/lite-xl) with base16 themes

Note: Files in the schemes directory have their own licenses (mostly MIT)  
schemes/base16: https://github.com/chriskempson/base16#scheme-repositories  
schemes/daylerees: https://github.com/daylerees/colour-schemes  

# instructions
* place the repository in data/plugins (so you have data/plugins/theme16 folder)
* add initialization code to data/user/init.lua
* example code:  
```lua
-- the following 2 variables take a value between 0 and 2
-- values less than 1 decrease the saturation (at 0 it becomes 0, at 1 there is no change)
-- values greater than 1 increase the saturation (at 2 it becomes 1)
--config.theme_saturation = 0.95 -- overall saturation
--config.theme_lightness  = 0.90 -- overall lightness
config.theme_name = "edge-dark" -- name of the theme

-- It can also be a table. Then the first one is set and the list will be used to cycle through
--config.theme_name = {"edge dark", "edge light"}
-- Otherwise, if the following is true, config.theme_listfile will be used to cycle through
-- (config.theme_listfile defaults to "scheme_list.lua" in the plugin's directory)
--config.theme_usefile  = true 
-- Otherwise, a list will be generated from the files in config.theme_dir
-- (config.theme_dir defaults to "schemes/" in the plugin's directory)
-- And, if the following is true, generated list will be saved as config.theme_listfile
--config.theme_savefile = true

-- dynamically load a theme
keymap.add { ["alt+home"] = "theme:change" }
keymap.add { ["alt+pageup"] = "theme:prev" }
keymap.add { ["alt+pagedown"] = "theme:next" }
-- write current theme to file
keymap.add { ["alt+insert"] = "theme:write" } 

```
