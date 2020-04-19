# theme16
theme manager for rxi/lite with base16 themes

Note: Files in the schemes directory have their own licenses (mostly MIT)
schemes/base16: https://github.com/chriskempson/base16#scheme-repositories
schemes/daylerees: https://github.com/daylerees/colour-schemes

# instructions
* place the repository in data/plugins (so you have data/plugins/theme16 folder)
* add initialization code to data/user/init.lua
* example code:  
```lua
local theme = require "plugins.theme16"
-- the following 2 take a value between 0 and 2
-- values less than 1 decrease the saturation (at 0 it becomes 0, at 1 there is no change)
-- values greater than 1 increase the saturation (at 2 it becomes 1)
--theme.saturation = 0.95 -- overall saturation
--theme.lightness  = 0.90 -- overall lightness
theme.name = "edge-dark" -- name of the theme
theme.apply() -- this loads the theme

-- dynamically load a theme
keymap.add { ["alt+home"] = "theme:change" }
keymap.add { ["alt+pageup"] = "theme:prev" }
keymap.add { ["alt+pagedown"] = "theme:next" }
```
