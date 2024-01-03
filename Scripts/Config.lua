if CCD_CONFIG_LOADED then return end
CCD_CONFIG_LOADED = true

sm.interactable.connectionType.video = sm.interactable.connectionType.video or 2097152

sm.mod = sm.mod or {}
sm.mod.ccd = {
    displayApi = {}
}



---Please use as usual `Color[]` (e.g. `buffer[i] = color`), don't use methods.
---Transparent color is `nil`. Starts since 1.
---@class DrawBuffer
DrawBuffer = class()

---@type function
DrawBuffer.FLOOR = nil
---@type function
DrawBuffer.COL_NEW = nil

---@type Color[]
DrawBuffer.pool = {}

---@type boolean[]
DrawBuffer.changedTable = {}
---@type integer
DrawBuffer.blockSize = 0
---@type integer
DrawBuffer.blocksPerX = 0

---@type integer
DrawBuffer.bitMode = 0

---@type integer
DrawBuffer.resolutionX = 0
---@type integer
DrawBuffer.resolutionY = 0

---@type number
DrawBuffer.bitMultiplier1 = 0
---@type number
DrawBuffer.bitMultiplier2 = 0

---@param changedTable boolean[]
---@param pool Color[]
---@param blockSize integer
---@return DrawBuffer
function DrawBuffer.new(changedTable, pool, blockSize)
    ---@type DrawBuffer
    local obj = DrawBuffer()
    obj.pool = pool
    obj.changedTable = changedTable
    obj.blockSize = blockSize
    obj.blocksPerX = 0

    obj.FLOOR = math.floor
    obj.COL_NEW = sm.color.new
    
    return obj
end

---@param x integer
---@param y integer
function DrawBuffer:setResolution(x, y)
    self.resolutionX = x
    self.resolutionY = y
    self.blocksPerX = x / self.blockSize
end

---@param pxPos integer since 0
---@param color Color|nil
function DrawBuffer:setColor(pxPos, color)
    local index = pxPos + 1
    local buffer = self.pool
    local floor = self.FLOOR
    local m1 = self.bitMultiplier1
    local m2 = self.bitMultiplier2

    if color then
        local c = self.COL_NEW(floor(color.r * m1) * m2, floor(color.g * m1) * m2, floor(color.b * m1) * m2)

        if c ~= buffer[index] then
            self:setChanged(pxPos)
            buffer[index] = c
        end
    else
        if buffer[index] then
            self:setChanged(pxPos)
            buffer[index] = nil
        end
    end
end

---@param pxPos integer since 0
---@return Color
function DrawBuffer:getColor(pxPos)
    return self.pool[pxPos + 1]
end

---@param pxPos integer
function DrawBuffer:setChanged(pxPos)
    local rX = self.resolutionX
    local blockSize = self.blockSize
    local floor = self.FLOOR

    local bX = floor(pxPos % rX / blockSize)
    local bY = floor(pxPos / rX / blockSize)

    self.changedTable[bX + bY * self.blocksPerX + 1] = true
end

function DrawBuffer:setChangedAll()
    local t = self.changedTable
    for i = 1, #t do
        t[i] = true
    end
end

---@param bits integer
function DrawBuffer:setBitMode(bits)
    self.bitMode = bits
    self.bitMultiplier1 = 255 / (2 ^ (8 - bits))
    self.bitMultiplier2 = 1 / (2 ^ bits - 1)

    self:setChangedAll()
end



---@class DisplayResolution
local DisplayResolution = {}

---@type integer
DisplayResolution.x = nil

---@type integer
DisplayResolution.y = nil



---@class DisplayApi
DisplayApi = class()

---Link to current display class
---@private
---@type Display
DisplayApi.display = {}

---@param display Display
function DisplayApi.new(display)
    local api = DisplayApi()
    api.display = display
    return api
end

---Gives the resolution of display
---@return DisplayResolution
function DisplayApi:getResolution()
    return { x = self.display.resolutionX, y = self.display.resolutionY }
end

---Creates buffer at z-index, where you need to set colors.
---If buffer at zIndex is already exists, it returns nil.
---Color `nil` means transparent.
---@param zIndex integer z-index >= 1
---@return DrawBuffer|nil
function DisplayApi:createBuffer(zIndex)
    return self.display:createLayer(zIndex)
end

---Destroys buffer at z-index
---@param zIndex integer
function DisplayApi:destroyBuffer(zIndex)
    self.display:destroyLayer(zIndex)
end

---Calls callback every render event (requests passing buffer).
---Its better to put [renderBuffer] call there
---@param thisInteractable Interactable
---@param callback function
function DisplayApi:setRenderCallback(thisInteractable, callback)
    self.display:addRenderCallback(thisInteractable, callback)
end

---Removes subscription for render events.
---@param thisInteractable Interactable
function DisplayApi:removeRenderCallback(thisInteractable)
    self.display:removeRenderCallback(thisInteractable)
end

---Calls callback every resolution change event.
---@param thisInteractable Interactable
---@param callback function
function DisplayApi:setResolutionCallback(thisInteractable, callback)
    self.display:addResolutionCallback(thisInteractable, callback)
end

---Removes subscription for resolution change events.
---@param thisInteractable Interactable
function DisplayApi:removeResolutionCallback(thisInteractable)
    self.display:removeResolutionCallback(thisInteractable)
end