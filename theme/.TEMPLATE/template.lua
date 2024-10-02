--[[______   __
  / ____/ | / / by: GNamimates, Discord: "@gn8.", Youtube: @GNamimates
 / / __/  |/ / Theme File
/ /_/ / /|  / Contains how to theme specific classes
\____/_/ |_/ Source: link]]

--[[ Layout --------
├Class
│├Default
│└AnotherVariant
└Class
 ├Default
 ├Variant
 └MoreVariant
-------------------]]
---GNUI.Button        ->    Button
---GNUI.Button.Slider ->    Slider


---@type GNUI.Theme
return {
  Button = {
    Default = function (box)
      box:setText("Hello WOrld")
    end
  }
}