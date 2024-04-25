local utils = require("utils")
local gui = require("gui")
--[[
linedata = {
    { --polygons
        color = {r, g, b, a},
        verts = {{x, y}, {x, y}, ...}
    },
    { --lines
        color = {r, g, b, a},
        verts = {{x, y}, {x, y}}
    },
}
--]]

--[[GUI ELEMENTS]]--
-----------------------------
local color
local HSVA = {1, 1, 1, 1}
local slidersYOff = 80
gui.newSlider("H", gui.GUI_P_START, 20+slidersYOff,1, 1, 360, function(val)
    HSVA[1] = val
end)
gui.newSlider("S", gui.GUI_P_START, 40+slidersYOff,0.8, 0, 1, function(val)
    HSVA[2] = val
end)
gui.newSlider("V", gui.GUI_P_START, 60+slidersYOff,1, 0, 1,function(val)
    HSVA[3] = val
end)
gui.newSlider("A", gui.GUI_P_START, 80+slidersYOff,1, 0, 1,function(val)
    HSVA[4] = val
end)





local function updateSliders(_HSVA)
    for i, gui in pairs(gui.guis) do
        gui.val = _HSVA[i]
    end
    HSVA = utils.deepcopy(_HSVA)
end
-----------------------------



local function DrawPolygonList(linedata, x, y, sx, sy, rot, ox, oy)
    x   = x   or 0  -- in px
    y   = y   or 0  --
    sx  = sx  or 1  -- in times (1x = original scale)
    sy  = sy  or sx --
    rot = rot or 0  -- in radians
    ox  = ox  or 0  -- in times (coordinate offset, processed before rotation and scale)
    oy  = oy  or 0  --
    local prevColour = {love.graphics.getColor()}

    for _, polygon in ipairs(linedata) do
        local r, g, b, a, verts = unpack(polygon)
        local v2 = {}
        for _, vert in ipairs(verts) do
            local i, j = unpack(vert)
            i, j = i + ox, j + oy
            table.insert(v2, x+(i*math.cos(rot) - j*math.sin(rot))*sx)
            table.insert(v2, y+(j*math.cos(rot) + i*math.sin(rot))*sy)
        end
        love.graphics.setColor(r, g, b, a)
        love.graphics.polygon("line", v2)
    end
    love.graphics.setColor(prevColour)
end


local function drawCheckerboard(w, h, segments)
    local ws, hs = w/segments, h/segments
    local a = 0.6
    local greys = {{1, 1, 1, a}, {0.75, 0.75, 0.75, a}}

    for y = 0, segments do
        for x = 0, segments do
            love.graphics.setColor(greys[1+(x+y)%2])

            love.graphics.rectangle("fill", x*ws, y*hs, ws, hs)
        end
    end
    love.graphics.setColor(0,0,1,0.5)
    love.graphics.line(720/2, 0, 720/2, 720)
    love.graphics.line(0, 720/2, 720, 720/2)
    love.graphics.setColor(1,1,1,1)
end

local function checkIfNearVert(mx, my, vert, threshold)
    local d = (vert[1] - mx)^2 + (vert[2] - my)^2
    return d <= threshold^2 and true or false
end

local function isNearLine(mx, my, linePoints, threshold)
    local lx1, ly1, lx2, ly2 = unpack(linePoints)

    local lvx, lvy = lx2-lx1, ly2-ly1
    local vp1xm, vp1ym = mx-lx1, my-ly1
    local dotP1M = lvx*vp1xm + lvy*vp1ym
    local llen = (lx2 - lx1)^2 + (ly2 - ly1)^2
    local T = math.min(math.max(dotP1M / llen, 0), 1)
    local projx, projy = lx1 + T*(lx2-lx1), ly1 + T*(ly2-ly1)
    local d = ((projx-mx)^2 + (projy-my)^2)

    return d <= threshold^2 and true or false
end

local nearLineThreshold = 10
local function getPointsIDsOnALine(mx, my, polygon)
    for id = 1, #polygon, 2 do
        local line = {}
        line = {
            polygon[1+(id-1)   % #polygon],
            polygon[1+(id)     % #polygon],
            polygon[1+(id+1)   % #polygon],
            polygon[1+(id+2)   % #polygon]
        }

        if isNearLine(mx, my, line, nearLineThreshold) then
            return id
        end
    end
end

local drawnPolygons = {}
local activePoygon  = {}
local previewAP     = {}

local function passInActivePolygon()
    for _, v in pairs(previewAP) do
        table.insert(activePoygon, v)
    end
end

--[[UNDO/REDO]]--
------------------------------------------------------------------------------------
local undoHistory = {
    prevDrawnPolygonsStates   = {},
    prevActivePoygonStates    = {},

    undoAPStatePos = 0,
    undoDPStatePos = 0,
}

function undoHistory:update()
    if #activePoygon ~= 0 then -- History for active polygon

        while self.undoAPStatePos ~= #self.prevActivePoygonStates do
            table.remove(self.prevActivePoygonStates)
        end
        table.insert(self.prevActivePoygonStates, utils.deepcopy(activePoygon))
        self.undoAPStatePos = #self.prevActivePoygonStates

    else

        while self.undoDPStatePos ~= #self.prevDrawnPolygonsStates do
            table.remove(self.prevDrawnPolygonsStates)
        end
        table.insert(self.prevDrawnPolygonsStates, utils.deepcopy(drawnPolygons))
        self.undoDPStatePos = #self.prevDrawnPolygonsStates
    end
end

function undoHistory:undo()
    if #activePoygon ~= 0 then
        self.undoAPStatePos = math.max(self.undoAPStatePos - 1, 1)
        activePoygon        = utils.deepcopy(self.prevActivePoygonStates[self.undoAPStatePos])
        previewAP           = utils.deepcopy(self.prevActivePoygonStates[self.undoAPStatePos])
    else
        self.undoDPStatePos = math.max(self.undoDPStatePos - 1, 0)
        drawnPolygons       = self.undoDPStatePos > 0 and utils.deepcopy(self.prevDrawnPolygonsStates[self.undoDPStatePos]) or {}
    end
end

function undoHistory:redo()
    if #activePoygon ~= 0 then
        self.undoAPStatePos = math.min(self.undoAPStatePos + 1, #self.prevActivePoygonStates)
        activePoygon        = utils.deepcopy(self.prevActivePoygonStates[self.undoAPStatePos])
        previewAP           = utils.deepcopy(self.prevActivePoygonStates[self.undoAPStatePos])
    else
        self.undoDPStatePos = math.min(self.undoDPStatePos + 1, #self.prevDrawnPolygonsStates)
        drawnPolygons       = utils.deepcopy(self.prevDrawnPolygonsStates[self.undoDPStatePos])
    end
end

function undoHistory:deleteActivePolygonHistory()
    self.prevActivePoygonStates = {}
end

function undoHistory:resetStatePos()
    self.undoAPStatePos = 0
end


function undoHistory:controls()
    local lCtrlDown = love.keyboard.isDown("lctrl")

    local keyZ = love.keyboard.isDown("z")
    local keyY = love.keyboard.isDown("y")

    if lCtrlDown then
        if keyZ then
            self:undo()
        elseif keyY then
            self:redo()
        end
    end
end
------------------------------------------------------------------------------------

--[[Snap to vertex]]--
------------------------------------------------------------------------------------
local function findNearVertToSnap(mx, my, threshold)
    for _, shape in pairs(drawnPolygons) do
        for _, vert in pairs(shape.verts) do
            local isFound = checkIfNearVert(mx, my, vert, threshold)
            if isFound then
                return vert
            end
        end
    end
end

local vertSnapDown = true
local function vertSnap(mx, my, keyX, _isNearVertID)
    if keyX then
        if #drawnPolygons ~= 0 then
            local vert = findNearVertToSnap(mx, my, 15)
            if vert then
                previewAP[_isNearVertID]     = vert[1]
                previewAP[_isNearVertID+1]   = vert[2]
            end
        end

        vertSnapDown = true
        return true
    elseif not keyX and vertSnapDown then

        vertSnapDown = false
    end
end
------------------------------------------------------------------------------------

--[[GRID/SNAP TO GRID]]--
------------------------------------------------------------------------------------
local grid = {
    segments = {
        w = 32,
        h = 32,
    },
    canvas = love.graphics.newCanvas(720,720),

    state = false,

    scaleMult = 2,
}

local lineWidth = 3

function grid:set(w, h)
    self.segments.w = math.max(math.min(w or 32, 128), 32)
    self.segments.h = math.max(math.min(h or 32, 128), 32)

    love.graphics.setCanvas(self.canvas) do
        love.graphics.clear()
        love.graphics.setColor(1,1,1,0.8)
        love.graphics.setLineStyle("rough")
        love.graphics.setLineWidth(1)
        for y = 1, self.segments.h do
            love.graphics.line(
                0, (720/self.segments.h)*y,
                720, (720/self.segments.h)*y
            )
        end
        for x = 1, self.segments.w do
            love.graphics.line(
                (720/self.segments.w)*x, 0,
                (720/self.segments.w)*x, 720
            )
        end
        love.graphics.setLineStyle("smooth")
        love.graphics.setLineWidth(lineWidth)
        love.graphics.setColor(1,1,1,1)
    end love.graphics.setCanvas()

end

function grid:control(key)
    if key == "g" then
        self.state = not self.state
    elseif key == "kp-" then
        grid:set(self.segments.w*self.scaleMult, self.segments.h*self.scaleMult)
    elseif key == "kp+" then
        grid:set(self.segments.w/self.scaleMult, self.segments.h/self.scaleMult)
    end
end

function grid:getSnapPos(mx, my)
    local smx = math.floor(0.5+mx/(720/self.segments.w))*(720/self.segments.w)
    local smy = math.floor(0.5+my/(720/self.segments.h))*(720/self.segments.h)
    return smx, smy
end

function grid:draw()
    if self.state then
        love.graphics.draw(self.canvas)
    end
end

------------------------------------------------------------------------------------
local function tableWrite(var, vTable, vTab)
    local tab = vTab or ""
    if not vTab then
        var[1] = var[1].."return {\n"
        tab = tab.."\t"
    end
    for i, v in pairs(vTable) do
        if type(v) == "table" and v ~= vTable then
            var[1] = var[1]..tab..(type(i) ~= "number" and tostring(i).." = {\n" or "{\n")
            tableWrite(var, v, tab.."\t")
            var[1] = var[1]..tab..(tab ~= "" and "},\n" or "}\n")
        else
            var[1] = var[1]..tab..(type(i) ~= "number" and tostring(i).." = " or "")..v..",\n"
        end
    end
    var[1] = not vTab and var[1].."}" or var[1]
end
local function save()
    local tableData = {""}
    tableWrite(tableData, drawnPolygons)
    --local file = love.filesystem.newFile("drawingXd.blomkExtensionFormat", "w")
    local file = love.filesystem.newFile("sprite.pjts", "w")
    file:write(tableData[1])
    file:flush()
end

gui.newButton("save", 720+gui.WSIZE/2, 720-50, 60, 20, save)

---------------------------------------------------------------------------------------



local checkerBoardSprite = love.graphics.newCanvas(720, 720)
function love.load()
    love.graphics.setPointSize(5)
    love.graphics.setLineStyle("smooth")
    love.graphics.setLineJoin("none")
    love.graphics.setLineWidth(lineWidth)

    love.graphics.setCanvas(checkerBoardSprite) do
        drawCheckerboard(720, 720, 32)
    end love.graphics.setCanvas()
    grid:set()

end

local autoSafeTime = 30
local timerStart = os.clock()
function love.update(_) --useless boi
    if gui.isUsed() or not color then
        color = utils.HSVA(unpack(HSVA))
    end
    if math.floor((os.clock() - timerStart) * 1000) / 1000 >= autoSafeTime then
        save()
        timerStart = os.clock()
    end
    gui.update()
end --who even use that

local canvas                  = love.graphics.newCanvas(720, 720)

local LMBIsDown               = false
local isCreatingAPolygon      = false
local isCreatingPoint         = false
local RMBIsDown               = false

local nearVertThreshold       = 15
local nearVertLock            = false
local isNearVertID

local edgeId
local isAddingAPoint          = false

local isMovingAPolygon        = false
local pmx, pmy

local hoveredPastedPolygonId
function love.draw()
    local hoveredPastedPolygon

    --vert manipulation
    local LMBDown = love.mouse.isDown(1)
    --paste the shape
    local RMBDown = love.mouse.isDown(2)
    --add a vert on a line
    local lShiftDown = love.keyboard.isDown("lshift")
    --delete a vert
    local lCtrlDown = love.keyboard.isDown("lctrl")
    --move polygon
    local lAltDown = love.keyboard.isDown("lalt")

    --vert snap
    local keyX = love.keyboard.isDown("x")

    local mx, my = love.mouse.getPosition()
    local isNearAVert = false

    local _mx, _my = mx, my
    if grid.state then
        _mx, _my = grid:getSnapPos(mx, my)
    end
    --[[MANIPULATIONS WITH ACTIVE SHAPE]]--
    ---------------------------------
    if mx <= 720 and not gui.isUsed() then
        --Checking if the mouse near a vert and not at the moment when point is created
        if not LMBDown or (not nearVertLock and not isCreatingPoint) then
            for i = 1, #activePoygon, 2 do
                local vert = {activePoygon[i], activePoygon[i+1]}
                isNearAVert = checkIfNearVert(mx, my, vert, nearVertThreshold)

                if isNearAVert then
                    isNearVertID = i
                    break
                end
                isNearVertID = nil
            end
        end

        --moving pasted polygons into active modes
        if lAltDown and #activePoygon == 0 and #drawnPolygons ~= 0 then

            for id, polygon in pairs(drawnPolygons) do
                --highlighting a selected polygon
                local polygonPoints = {}
                for _, vert in pairs(polygon.verts) do
                    table.insert(polygonPoints, vert[1])
                    table.insert(polygonPoints, vert[2])
                end
                for i = 1, #polygonPoints, 2 do
                    local line = {
                        polygonPoints[1+(i-1)   % #polygonPoints],
                        polygonPoints[1+(i-0)   % #polygonPoints],
                        polygonPoints[1+(i+1)   % #polygonPoints],
                        polygonPoints[1+(i+2)   % #polygonPoints],
                    }

                    if isNearLine(mx, my, line, nearLineThreshold) then
                        hoveredPastedPolygon = polygonPoints
                        hoveredPastedPolygonId = id
                        break
                    end
                end
                if hoveredPastedPolygonId then
                    --break
                end
            end

            --Translating the pasted polygon into an active state
            if hoveredPastedPolygon then
                if LMBDown and not LMBIsDown then
                    LMBIsDown = true
                elseif not LMBDown and LMBIsDown then
                    local removedPoly = table.remove(drawnPolygons, hoveredPastedPolygonId)
                    color = utils.deepcopy(removedPoly.color)

                    updateSliders(utils.RGBA2HSVA(unpack(color)))

                    previewAP = hoveredPastedPolygon
                    activePoygon = {}
                    passInActivePolygon()

                    hoveredPastedPolygonId = nil

                    undoHistory:update()
                    LMBIsDown = false
                end
            end
        else
            hoveredPastedPolygonId = nil
        end

        if not hoveredPastedPolygonId then
            if lAltDown then
                if LMBDown then
                    edgeId = getPointsIDsOnALine(mx, my, previewAP)
                    if isNearAVert or edgeId or isMovingAPolygon then
                        if not pmx then
                            pmx, pmy = _mx, _my
                        end
                        previewAP = {}
                        for i, v in pairs(activePoygon) do
                            previewAP[i] = i % 2 == 0 and v+(_my-pmy) or v+(_mx-pmx)
                        end

                        isMovingAPolygon = true
                    end
                    LMBIsDown = true
                elseif not LMBDown and LMBIsDown then
                    if isMovingAPolygon then
                        pmx, pmy = nil, nil
                        activePoygon = {}
                        passInActivePolygon()
                        undoHistory:update()

                        isMovingAPolygon = false
                    end

                    LMBIsDown = false
                end
            else
                if lShiftDown or isAddingAPoint then --vert add mode on line
                    if not (isCreatingPoint or nearVertLock) then
                        if LMBDown and not edgeId then
                            edgeId = getPointsIDsOnALine(mx, my, previewAP)
                        elseif LMBDown then
                            previewAP = {}
                            for i, v in pairs(activePoygon) do
                                previewAP[i] = v
                            end

                            table.insert(previewAP, edgeId+2, _my)
                            table.insert(previewAP, edgeId+2, _mx)

                            isAddingAPoint = true
                            LMBIsDown = true
                        elseif not LMBDown and LMBIsDown and edgeId then
                            activePoygon = {}
                            passInActivePolygon()

                            undoHistory:update()
                            edgeId = nil
                            isAddingAPoint = false
                            LMBIsDown = false
                        end
                    end
                elseif lCtrlDown and isNearVertID then --delete vert
                    if LMBDown and not LMBIsDown then
                        table.remove(previewAP, isNearVertID)
                        table.remove(previewAP, isNearVertID)
                        LMBIsDown = true
                    elseif not LMBDown and LMBIsDown then
                        activePoygon = {}
                        passInActivePolygon()

                        undoHistory:update()
                        LMBIsDown = false
                    end
                else
                    if not isNearAVert and not nearVertLock then --Pasting a new vert if the cursor is not near any verts
                        if LMBDown then
                            if not isCreatingAPolygon then
                                undoHistory:resetStatePos()
                                isCreatingAPolygon = true
                            end

                            previewAP = {}
                            for i, v in pairs(activePoygon) do
                                previewAP[i] = v
                            end

                            table.insert(previewAP, _mx)
                            table.insert(previewAP, _my)

                            vertSnap(mx, my, keyX, #previewAP-1)

                            isCreatingPoint = true
                            LMBIsDown = true
                        elseif not LMBDown and LMBIsDown then
                            activePoygon = {}
                            passInActivePolygon()

                            undoHistory:update()
                            isCreatingPoint = false
                            LMBIsDown = false
                        end
                    else --Moving/Editing an already existing vert if the cursor is near any vert
                        if LMBDown then

                            previewAP[isNearVertID] = _mx
                            previewAP[isNearVertID+1] = _my

                            vertSnap(mx, my, keyX, isNearVertID)

                            nearVertLock = true
                            LMBIsDown = true
                        elseif not LMBDown and LMBIsDown then
                            activePoygon = {}
                            passInActivePolygon()

                            undoHistory:update()
                            nearVertLock = false
                            LMBIsDown = false
                        end
                    end
                end
            end
        end


        ---------------------------------
        --Paste the active polygon in a needed data type
        if RMBDown and not RMBIsDown then
            if #activePoygon > 2 then
                local polygonData = {
                    color = utils.deepcopy(color)
                }
                local _verts = {}
                for i = 1, #activePoygon, 2 do
                    table.insert(_verts, {activePoygon[i], activePoygon[i+1]})
                end
                polygonData.verts = _verts
                table.insert(drawnPolygons, polygonData)
                activePoygon = {}
                previewAP = {}

                undoHistory:resetStatePos()
                undoHistory:deleteActivePolygonHistory()
                undoHistory:update()

                isCreatingAPolygon = false
                RMBIsDown = true
            end
        elseif not RMBDown and RMBIsDown then
            RMBIsDown = false
        end
    end

    --Main canvas for drawing
    love.graphics.setCanvas(canvas) do
        love.graphics.clear()

        --Draw all pasted polygons
        for _, polygon in pairs(drawnPolygons) do
            local verts = {}
            for _, vert in pairs(polygon.verts) do
                table.insert(verts, vert[1])
                table.insert(verts, vert[2])
            end
            love.graphics.setColor(polygon.color)
            if #verts > 4 then
                love.graphics.polygon("line", verts)
            else
                love.graphics.line(verts)
            end
            love.graphics.setColor(1, 1, 1, 1)
        end

        --Highlight a Polygon you hover at
        if hoveredPastedPolygon then
            love.graphics.setColor(0,1,0,1)
            if #hoveredPastedPolygon > 4 then
                love.graphics.polygon("line", hoveredPastedPolygon)
            else
                love.graphics.line(hoveredPastedPolygon)
            end
            love.graphics.setColor(1, 1, 1, 1)
        end

        --Active polygon draw
        local currentPolygon = not LMBDown and activePoygon or previewAP
        if #currentPolygon >= 2 then
            love.graphics.setColor(color)
            if #currentPolygon == 4 then
                love.graphics.line(currentPolygon)
            elseif #currentPolygon >= 6 then
                love.graphics.polygon("line", currentPolygon)
            end

            --highlighting a selected line
            if lShiftDown and #currentPolygon > 4 and not LMBDown then
                for id = 1, #currentPolygon, 2 do
                    local line = {}
                    line = {
                        currentPolygon[1+(id-1)   % #currentPolygon],
                        currentPolygon[1+(id)     % #currentPolygon],
                        currentPolygon[1+(id+1)   % #currentPolygon],
                        currentPolygon[1+(id+2)   % #currentPolygon]
                    }

                    if isNearLine(mx, my, line, nearLineThreshold) then
                        love.graphics.setColor(0,1,0,1)
                        love.graphics.line(line)
                        break
                    end
                end
            end

            --Draw Active plygon's verts
            for i = 1, #currentPolygon, 2 do
                local vert = {currentPolygon[i], currentPolygon[i+1]}
                love.graphics.setColor(checkIfNearVert(mx, my, vert, nearVertThreshold) and (not lCtrlDown and {0, 1, 0, 1} or {1, 1, 0, 1}) or {1, 0, 0, 1})
                love.graphics.points(vert)
            end
            love.graphics.setColor(1,1,1,1)
        end
    end love.graphics.setCanvas()

    --Draw this entire thing idfk
    love.graphics.draw(checkerBoardSprite)
    grid:draw()
    love.graphics.draw(canvas)
    gui.draw()
    love.graphics.setColor(color)
    love.graphics.rectangle("fill", 720+60, 15, 60, 60)
    love.graphics.setColor(utils.HSVA(HSVA[1]*0.3, HSVA[2]*0.3, HSVA[3]*0.3, HSVA[4]))
    love.graphics.rectangle("line", 720+60, 15, 60, 60)
    love.graphics.setColor(1,1,1,1)
end

local function offsetEverything(x, y)
    if #drawnPolygons ~= 0 then
        for _, polygon in pairs(drawnPolygons) do
            for _, vert in pairs(polygon.verts) do
                vert[1] = vert[1] + x
                vert[2] = vert[2] + y
            end
        end

        undoHistory:update()
    end
end

local function scaleEverything(scale)
    if #drawnPolygons ~= 0 then
        for _, polygon in pairs(drawnPolygons) do
            for _, vert in pairs(polygon.verts) do
                vert[1] = vert[1]*scale
                vert[2] = vert[2]*scale
            end
        end

        undoHistory:update()
    end
end

function love.keypressed(key)
    grid:control(key)
    undoHistory:controls()
    if key == "escape" then
        previewAP = {}
        activePoygon = {}
    end

    if key == "pageup" then
        scaleEverything(1/0.8)
    end

    if key == "pagedown" then
        scaleEverything(0.8)
    end

    if key == "up" then
        offsetEverything(0, -10)
    end

    if key == "down" then
        offsetEverything(0, 10)
    end

    if key == "right" then
        offsetEverything(10, 0)
    end

    if key == "left" then
        offsetEverything(-10, 0)
    end

end

function love.filedropped(file)
    file:open("r")
    local data = file:read()
    drawnPolygons = {}
    drawnPolygons = loadstring(data)()
end

























