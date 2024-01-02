local FiGUI = require("libraries.FiGUI")
local appManager = require("TV.appManager")

local DPI = 1
local ALIVE = vec(1,1,1,1)
local DEAD = vec(0,0,0,1)

local lookup = {
    [0] = {},
    [1] = {}
}
for i = 0, 8 do
    lookup[1][i] = (i == 2 or i == 3) and ALIVE or DEAD
    lookup[0][i] = (i == 3) and ALIVE or DEAD
end

local function rules(texture_old, texture_new, size_x, size_y)
    local pixels = {}
    for x = -1, size_x + 1 do
        for y = -1, size_y + 1 do
            pixels[x * size_y + y] = 0
        end
    end
    texture_old:applyFunc(0, 0, size_x, size_y, function(clr, x, y)
        pixels[x * size_y + y] = (clr == ALIVE) and 1 or 0
    end)
    texture_new:applyFunc(0, 0, size_x, size_y, function(clr, x, y)
        return lookup[pixels[x * size_y + y]][
        (pixels[(x-1) * size_y + (y-1)]) +
        (pixels[(x-1) * size_y + (y  )]) +
        (pixels[(x-1) * size_y + (y+1)]) +
        (pixels[(x  ) * size_y + (y-1)]) +
        (pixels[(x  ) * size_y + (y+1)]) +
        (pixels[(x+1) * size_y + (y-1)]) +
        (pixels[(x+1) * size_y + (y  )]) +
        (pixels[(x+1) * size_y + (y+1)])]
    end)
end
local function uuid()
    ---@diagnostic disable-next-line: undefined-field
    return client.intUUIDToString(client.generateUUID())
end

local factory = function (window,tv)
    ---@type Application
    local app = {}
    app.capture_keyboard = false



    local rect = window.ContainmentRect
    local size = ((rect.zw - rect.xy).xy / DPI):floor() --[[@as Vector2]]

    local sprite = FiGUI.newSprite()
    window:setSprite(sprite)

    app.data = {
        size = size,
        texture_new = textures:newTexture("life" .. uuid(), size.x, size.y),
        texture_old = textures:newTexture("life" .. uuid(), size.x, size.y),
        sprite = sprite,
        modified = {}
    }

    math.randomseed(1)
    app.data.texture_old:applyFunc(0, 0, size.x, size.y, function(_, x, y)
        return math.random() > 0.5 and ALIVE or DEAD
    end)

    sprite:setTexture(app.data.texture_old)

    local close = FiGUI.newLabel()
    close:setText("X"):setFontScale(0.3)
    close:setSize(3,3)
    close:setAlign(0.5,0.5)
    close:setAnchor(1,0,1,0)
    close:setPos(-3,0)
    close.PRESSED:register(function ()
        tv:setApp(tv.default_app)
    end)
    window:addChild(close)
    

    function app.TICK()
        if world.getTime() % 1 ~= 0 then return end

        local data = app.data

        rules(data.texture_old, data.texture_new, data.size.x, data.size.y)
        data.texture_new:update()
        data.texture_old, data.texture_new = data.texture_new, data.texture_old

        data.sprite:setTexture(data.texture_old)
    end


    return app
end
local icon = FiGUI.newSprite()
math.randomseed(8)
local texture = textures:newTexture("life" .. uuid(), 16, 16)
texture:applyFunc(0, 0, 16, 16, function(_, x, y)
    return math.random() > 0.5 and ALIVE or DEAD
end)
for _ = 1, 5 do
    rules(texture, texture, 16, 16)
end
texture:update()
icon:setTexture(texture)
appManager:registerApp(factory,"Life", icon)
