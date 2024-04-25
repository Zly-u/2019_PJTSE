local utils = require("utils")

local WSIZE = 180
local WSIZE_PROP = WSIZE * 0.7
local DIST_FROM_BORDERS = (WSIZE - WSIZE_PROP)/2

local GUI_P_START = 720 + DIST_FROM_BORDERS
local GUI_P_END = 900 - DIST_FROM_BORDERS
local GUI_P_END_OFF = 20

local gui = {
    guis = {},

    WSIZE = WSIZE,
    WSIZE_PROP = WSIZE_PROP,
    GUI_P_START = GUI_P_START,
    DIST_FROM_BORDERS = DIST_FROM_BORDERS,
    GUI_P_END = GUI_P_END,
    GUI_P_END_OFF = GUI_P_END_OFF,
}

local function dist(x1, y1, x2, y2, t)
    return (x1 - x2)^2 + (y1 - y2)^2 <= t^2 and true or false
end

function gui.newSlider(name, x, y, initVal, min, max, func)
    local slider = {
        name = name,
        pos = {x, y},
        w = 0,
        min = min,
        max = max,
        val = utils.clamp(initVal, min, max),
        func = func,

        circleSize = 7,
        circlePos = {0, 0},
        mouseLock = false
    }

    function slider:update()
        local LMBDown = love.mouse.isDown(1)
        local mx, my = love.mouse.getPosition()

        local propPos = GUI_P_START +((WSIZE_PROP-GUI_P_END_OFF)*(self.val/self.max))

        self.circlePos = {propPos, y}
        if LMBDown and dist(mx, my, self.circlePos[1], self.circlePos[2], self.circleSize*2) and not gui.isUsed() then
            self.mouseLock = true
        elseif self.mouseLock and not LMBDown then
            self.mouseLock = false
        end

        if self.mouseLock then
            self.val = utils.clamp(utils.invLerp(GUI_P_START, GUI_P_END-GUI_P_END_OFF, mx)*self.max, self.min, self.max)
            self.func(self.val)
        end
    end

    function slider:draw()

        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.line(
            self.pos[1],
            self.pos[2],
            self.pos[1]+WSIZE_PROP-GUI_P_END_OFF,
            self.pos[2]
        )
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.circle("fill", self.circlePos[1], self.circlePos[2], self.circleSize)

        local fontYOff = -8
        love.graphics.print(self.name, self.pos[1]-17, self.pos[2]+fontYOff)
        love.graphics.print(tostring(self.val), self.pos[1]+WSIZE_PROP+8-GUI_P_END_OFF, self.pos[2]+fontYOff)
    end
    table.insert(gui.guis, slider)
end

function gui.newButton(text, x, y, w, h, func)
    local button = {
        text = text,
        pos = {x-w/2, y-h/2},

        size = {w, h},
        func = func,

        mouseLock = false,
        mouseHover = false
    }

    function button:update()
        local LMBDown = love.mouse.isDown(1)
        local mx, my = love.mouse.getPosition()

        self.mouseHover = false
        if mx >= self.pos[1] and mx <= self.pos[1]+self.size[1] then
            if my >= self.pos[2] and my <= self.pos[2]+self.size[2] then
                self.mouseHover = true
                if LMBDown and not self.mouseLock then
                    self.mouseLock = true
                elseif not LMBDown and self.mouseLock then
                    self.func()
                    self.mouseLock = false
                end
            end
        end
    end

    function button:draw()
        love.graphics.setLineStyle("rough")
        love.graphics.setLineWidth(2)
        if not self.mouseLock then
            love.graphics.setColor(utils.HSVA(1, 0, 1, (not self.mouseHover and 0.5 or 0.7)))
        else
            love.graphics.setColor(utils.HSVA(120, 0.8, 1, (not self.mouseHover and 0.5 or 0.7)))
        end
        love.graphics.rectangle(
            "fill",
            self.pos[1],
            self.pos[2],
            self.size[1],
            self.size[2]
        )
        love.graphics.rectangle(
            "line",
            self.pos[1],
            self.pos[2],
            self.size[1],
            self.size[2]
        )
        love.graphics.setColor(utils.HSVA(1, 0, 0, 1))
        love.graphics.print(self.text, self.pos[1]+2, self.pos[2]+1)
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.setLineStyle("smooth")
        love.graphics.setLineWidth(3)
    end
    table.insert(gui.guis, button)
end

function gui.update()
    for _, guiElement in pairs(gui.guis) do
        guiElement:update()
    end
end

function gui.isUsed()
    for _, guiElement in pairs(gui.guis) do
        if guiElement.mouseLock then
            return true
        end
    end
end

function gui.draw()
    love.graphics.setColor(0.024, 0.09, 0.224, 0.5)
    love.graphics.rectangle("fill", 720, 0, WSIZE, 720)
    love.graphics.setColor(0.176, 0.267, 0.443, 1)
    love.graphics.rectangle("line", 720, 0, WSIZE, 720)

    for _, guiElement in pairs(gui.guis) do
        guiElement:draw()
    end

    love.graphics.setColor(1, 1, 1, 1)
end

return gui