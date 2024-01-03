dofile "$MOD_DATA/Scripts/Config.lua"

---@class EffectStorage
local EffectStorage = class()

EffectStorage.PIXEL_SHAPE_UUID = sm.uuid.new("031397e3-e039-4b21-89f0-3316baf6ccff")

---@type Interactable
EffectStorage.displayInteractable = {}

---@type Effect[]
EffectStorage.pool = {}

---@type integer
EffectStorage.size = 0

---@param displayInteractable Interactable
---@return EffectStorage
function EffectStorage.new(displayInteractable)
    ---@type EffectStorage
    local obj = EffectStorage()
    obj.pool = {}
    obj.size = 0
    obj.displayInteractable = displayInteractable
    return obj
end

---@return Effect
function EffectStorage:getEffect()
    local size = self.size

    if size >= 1 then
        self.size = size - 1
        return self.pool[size]
    end

    local effect = sm.effect.createEffect("ShapeRenderable", self.displayInteractable)
	effect:setParameter("uuid", self.PIXEL_SHAPE_UUID)
	effect:start()

    return effect
end

---@param effect Effect
function EffectStorage:putEffect(effect)
    local size = self.size + 1
    self.pool[size] = effect
    self.size = size
end

function EffectStorage:destroyEffects()
    local pool = self.pool
    for i = 1, self.size do
        pool[i]:destroy()
    end

    self.pool = {}
    self.size = 0
end


---@class LayerBlock
local LayerBlock = class()

---@type integer
LayerBlock.BLOCK_SIZE = 8

---@type Vec3
LayerBlock.VEC_ZERO = sm.vec3.zero()

---@type Vec3
LayerBlock.bufferVector = {}

---@type integer
LayerBlock.positionX = 0
---@type integer
LayerBlock.positionY = 0

---@type integer
LayerBlock.resolutionX = 0
---@type integer
LayerBlock.resolutionY = 0
---@type integer
LayerBlock.resolutionXHalf = 0
---@type integer
LayerBlock.resolutionYHalf = 0
---@type number
LayerBlock.pixelSize = 0

---@type number
LayerBlock.effectOffsetX = 0

---Link to layer drawBuffer.
---@type Color[]
LayerBlock.pixelBuffer = {}

---Effects on screen.
---@type Effect[]
LayerBlock.effectBuffer = {}
---@type integer
LayerBlock.effectBufferSize = 0

---Old buffer.
---@type Effect[]
LayerBlock.effectBufferOld = {}
---@type integer
LayerBlock.effectBufferOldSize = 0

---Link to display effectStorage.
---@type EffectStorage
LayerBlock.effectStorage = {}

---@return LayerBlock
---@param effectStorage EffectStorage
---@param pixelBuffer Color[]
---@param posX integer
---@param posY integer
---@param resX integer
---@param resY integer
---@param offsetX number
---@param pixelSize number
function LayerBlock.new(effectStorage, pixelBuffer, posX, posY, resX, resY, offsetX, pixelSize)
    ---@type LayerBlock
    local obj = LayerBlock()

    obj.effectOffsetX = offsetX
    obj.positionX = posX
    obj.positionY = posY

    obj.resolutionX = resX
    obj.resolutionY = resY
    obj.resolutionXHalf = resX * 0.5
    obj.resolutionYHalf = resY * 0.5

    obj.bufferVector = sm.vec3.zero()

    obj.effectBuffer = {}
    obj.effectBufferOld = {}
    obj.effectStorage = effectStorage

    obj.pixelBuffer = pixelBuffer
    obj.pixelSize = pixelSize
    return obj
end

---@return Effect
function LayerBlock:getEffect()
    local size = self.effectBufferOldSize
    if size >= 1 then
        self.effectBufferOldSize = size - 1
        return self.effectBufferOld[size]
    end

    return self.effectStorage:getEffect()
end

function LayerBlock:swapEffectBuffers()
    local b = self.effectBufferOld
    self.effectBufferOld = self.effectBuffer
    self.effectBuffer = b

    self.effectBufferOldSize = self.effectBufferSize
    self.effectBufferSize = 0
end

---@param posX integer
---@param posY integer
---@param quadSize integer
---@param color Color
function LayerBlock:putEffectOnDisplay(posX, posY, quadSize, color)
    local effect = self:getEffect()

    local bv = self.bufferVector
    local pixelSize = self.pixelSize

    local s = pixelSize * quadSize + 1e-4

    -- no memory allocation
    bv.x = s
    bv.y = s
    bv.z = s

    effect:setScale(bv)

    local quadSizeHalf = quadSize * 0.5

    bv.x = self.effectOffsetX
    bv.y = (posY - self.resolutionYHalf + quadSizeHalf) * pixelSize
    bv.z = (self.resolutionXHalf - posX - quadSizeHalf) * pixelSize

    effect:setOffsetPosition(bv)

    effect:setParameter("color", color)

    local edn = self.effectBufferSize + 1
    self.effectBuffer[edn] = effect
    self.effectBufferSize = edn
end

---Puts effects on the screen.
---@param posX integer
---@param posY integer
---@param quadSize integer
---@return Color|nil
function LayerBlock:recursiveQuadTraversal(resX, posX, posY, quadSize)
    if quadSize == 1 then
        return self.pixelBuffer[posX + posY * resX + 1]
    end
    local halfSize = quadSize * 0.5
    local posX2 = posX + halfSize
    local posY2 = posY + halfSize

    local c1 = self:recursiveQuadTraversal(resX, posX, posY, halfSize)
    local c2 = self:recursiveQuadTraversal(resX, posX, posY2, halfSize)
    local c3 = self:recursiveQuadTraversal(resX, posX2, posY, halfSize)
    local c4 = self:recursiveQuadTraversal(resX, posX2, posY2, halfSize)

    if c1 ~= nil then
        if c1 == c2 and c1 == c3 and c1 == c4 then return c1 end
        self:putEffectOnDisplay(posX, posY, halfSize, c1)
    end
    if c2 ~= nil then self:putEffectOnDisplay(posX, posY2, halfSize, c2) end
    if c3 ~= nil then self:putEffectOnDisplay(posX2, posY, halfSize, c3) end
    if c4 ~= nil then self:putEffectOnDisplay(posX2, posY2, halfSize, c4) end
end

function LayerBlock:clearEffectBufferOld()
    local storage = self.effectStorage
    local buffer = self.effectBufferOld
    for i = 1, self.effectBufferOldSize do
        storage:putEffect(buffer[i])
    end

    self.effectBufferOldSize = 0
end

function LayerBlock:clearEffectBuffer()
    local storage = self.effectStorage
    local buffer = self.effectBuffer
    for i = 1, self.effectBufferSize do
        storage:putEffect(buffer[i])
    end

    self.effectBufferSize = 0
end

function LayerBlock:render()
    self:swapEffectBuffers()

    local color = self:recursiveQuadTraversal(self.resolutionX, self.positionX, self.positionY, self.BLOCK_SIZE)
    if color then
        self:putEffectOnDisplay(self.positionX, self.positionY, self.BLOCK_SIZE, color)
    end

    local buffer = self.effectBufferOld
    for i = 1, self.effectBufferOldSize do
        buffer[i]:setOffsetPosition(self.VEC_ZERO)
    end
    self:clearEffectBufferOld()
end

function LayerBlock:destroy()
    local buffer = self.effectBuffer
    for i = 1, self.effectBufferSize do
        buffer[i]:setOffsetPosition(self.VEC_ZERO)
    end

    self:clearEffectBuffer()
end



---@class Layer
local Layer = class()

---@type Color[]
Layer.pixelBuffer = {}

---@type DrawBuffer
Layer.drawBuffer = {}

---@type boolean[]
Layer.changedBlocks = {}

---@type LayerBlock[]
Layer.blocks = {}

---@type number
Layer.effectOffsetX = 0

---Link to display effectStorage.
---@type EffectStorage
Layer.effectStorage = {}

---@param effectStorage EffectStorage
---@param offsetX number
---@return Layer
function Layer.new(effectStorage, offsetX)
    ---@type Layer
    local obj = Layer()

    obj.effectOffsetX = offsetX
    obj.changedBlocks = {}
    obj.effectStorage = effectStorage
    obj.blocks = {}

    obj.pixelBuffer = {}
    obj.drawBuffer = DrawBuffer.new(obj.changedBlocks, obj.pixelBuffer, LayerBlock.BLOCK_SIZE)
    return obj
end

---@param x integer
---@param y integer
---@param pixelSize number
function Layer:setResolution(x, y, pixelSize)
    self.resolutionX = x
    self.resolutionY = y
    self.resolutionXHalf = x * 0.5
    self.resolutionYHalf = y * 0.5
    self.pixelSize = pixelSize

    local blocksX = x / LayerBlock.BLOCK_SIZE
    local blocksY = y / LayerBlock.BLOCK_SIZE
    local blocksNo = blocksX * blocksY

    self:destroy()

    --self.changedBlocks = {} it is linked in metatable so it cannot be changed
    self.blocks = {}
    local cb = self.changedBlocks
    local b = self.blocks

    local floor = math.floor
    local blockSize = LayerBlock.BLOCK_SIZE

    for i = 1, blocksNo do
        local iPos = i - 1
        local xPos = iPos % blocksX * blockSize
        local yPos = floor(iPos / blocksX) * blockSize

        cb[i] = true
        b[i] = LayerBlock.new(self.effectStorage, self.pixelBuffer, xPos, yPos, x, y, self.effectOffsetX, pixelSize)
    end

    for i = blocksNo+1, #cb do
        cb[i] = nil
    end

    self.drawBuffer:setResolution(x, y)
end

function Layer:setNeedRender()
    local blocks = self.changedBlocks
    for i = 1, #blocks do
        blocks[i] = true
    end
end

function Layer:render()
    local changed = self.changedBlocks
    for i, block in ipairs(self.blocks) do
        if changed[i] then
            block:render()
            changed[i] = false
        end
    end
end

function Layer:clearBuffers()
    for i, block in ipairs(self.blocks) do
        block:clearEffectBuffer()
    end
end

---@param bits integer
function Layer:setBitMode(bits)
    self.drawBuffer:setBitMode(bits)
end

---@return DrawBuffer
function Layer:getDrawBuffer()
    return self.drawBuffer
end

function Layer:destroy()
    for i, block in ipairs(self.blocks) do
        block:destroy()
    end
end



---@class Display
Display = class()

Display.maxParentCount = -1
Display.maxChildCount = 0
Display.connectionInput = sm.interactable.connectionType.video + sm.interactable.connectionType.logic
Display.connectionOutput = sm.interactable.connectionType.none
Display.colorNormal = sm.color.new(0x673ec7ff)
Display.colorHighlight = sm.color.new(0x845ae6ff)

---@type Interactable
Display.interactable = {}

---@type Shape
Display.shape = {}

---@type Network
Display.network = {}

---@type Storage
Display.storage = {}

Display.DISPLAY_OFFSET_X = -0.117
Display.BETWEEN_LAYER_DISTANCE = 0.0001
Display.MIN_Z_INDEX = 1
Display.MAX_Z_INDEX = 16
Display.PIXEL_SCALE = 0.0072
Display.RENDER_DISTANCE = 8
Display.DISPLAY_FORWARD = sm.vec3.new(1, 0, 0)
Display.GUI_LAYOUT = "$CONTENT_DATA/Gui/Layouts/Display.layout"

Display.COLOR_BITS_MIN = 1
Display.COLOR_BITS_MAX = 8

Display.MIN_RESOLUTION = 16
Display.RESOLUTION_STEP = 16

assert(Display.MIN_RESOLUTION % Display.RESOLUTION_STEP == 0)
assert(Display.RESOLUTION_STEP % LayerBlock.BLOCK_SIZE == 0)

---@return DisplayApi
function Display:getApi()
    return DisplayApi.new(self)
end

---@return number
function Display:getPixelSize()
    return Display.PIXEL_SCALE * self.maxResolutionX / self.resolutionX / self.maxResolutionScaler
end

---Changes the resolution of display. Also recreates buffers.
---@param x integer
---@param y integer
function Display:changeResolution(x, y)
    self.resolutionX = x
    self.resolutionY = y

    local maxSize = math.max(x, y)
    local pxSize = self:getPixelSize()

    for zIndex, layer in pairs(self.layers) do
        layer:setResolution(x, y, pxSize)
    end
    self:emitResolutionEvent()
end

---@param bits integer
function Display:changeBitMode(bits)
    self.bitMode = bits
    
    for zIndex, layer in pairs(self.layers) do
        layer:setBitMode(bits)
    end
end

function Display:createBlackScreenEffect()
    local effect = self.effectStorage:getEffect()
    effect:setParameter("color", sm.color.new(0x000000ff))
    effect:setOffsetPosition(sm.vec3.new(self.DISPLAY_OFFSET_X, 0, 0))

    local sX = self.PIXEL_SCALE * self.maxResolutionX / self.maxResolutionScaler
    local sY = self.PIXEL_SCALE * self.maxResolutionY / self.maxResolutionScaler
    effect:setScale(sm.vec3.new(1, sY, sX))

    self.blackScreenEffect = effect
end

---@param interactable Interactable
---@param callback function
function Display:addRenderCallback(interactable, callback)
    self.renderCallbacks[interactable:getId()] = callback
end

---@param interactable Interactable
function Display:removeRenderCallback(interactable)
    local id = interactable:getId()
    if self.renderCallbacks[id] then
        self.renderCallbacks[id] = nil
    end
end

---@param interactable Interactable
---@param callback function
function Display:addResolutionCallback(interactable, callback)
    self.resolutionCallbacks[interactable:getId()] = callback
end

---@param interactable Interactable
function Display:removeResolutionCallback(interactable)
    local id = interactable:getId()
    if self.resolutionCallbacks[id] then
        self.resolutionCallbacks[id] = nil
    end
end

function Display:emitRenderEvent()
    for i, value in ipairs(self.interactable:getParents(sm.interactable.connectionType.video)) do
        local value = self.renderCallbacks[value:getId()]
        if value then value() end
    end
end

function Display:emitResolutionEvent()
    for i, value in ipairs(self.interactable:getParents(sm.interactable.connectionType.video)) do
        local value = self.resolutionCallbacks[value:getId()]
        if value then value() end
    end
end

---Checks if there some conditions to render image
---@return boolean
function Display:needToRender()
    if not self.interactable.active then return false end

    local displayForward = self.shape.worldRotation * self.DISPLAY_FORWARD
    local cameraPosition = sm.camera.getPosition()

    local posDelta = self.shape.worldPosition - cameraPosition
    local distance = posDelta:length()
    if distance > self.RENDER_DISTANCE then return false end

    -- player behind the display
    if displayForward:dot(posDelta) <= 0 then return false end

    -- TODO: if player cannot see display
    return true
end

---Returns `nil` if layer is already exists of bad value of `zIndex`.
---@param zIndex integer in [MIN_Z_INDEX; MAX_Z_INDEX]
---@return DrawBuffer|nil
function Display:createLayer(zIndex)
    zIndex = math.floor(zIndex)
    if zIndex < self.MIN_Z_INDEX or zIndex > self.MAX_Z_INDEX then return nil end
    if self.layers[zIndex] then return nil end

    local layer = Layer.new(self.effectStorage, self.DISPLAY_OFFSET_X - self.BETWEEN_LAYER_DISTANCE * zIndex)
    layer:setResolution(self.resolutionX, self.resolutionY, self:getPixelSize())
    layer:setBitMode(self.bitMode)
    self.layers[zIndex] = layer
    return layer:getDrawBuffer()
end

---@param zIndex integer in [MIN_Z_INDEX; MAX_Z_INDEX]
function Display:destroyLayer(zIndex)
    zIndex = math.floor(zIndex)
    local layer = self.layers[zIndex]
    if layer then
        layer:destroy()
    end
    self.layers[zIndex] = nil
end

function Display:recreateEffects()
    for zIndex, layer in pairs(self.layers) do
        layer:setNeedRender()
    end
end

function Display:destroyEffects()
    for zIndex, layer in pairs(self.layers) do
        layer:clearBuffers()
    end
    self.effectStorage:destroyEffects()
end

function Display:bindApi()
    sm.mod.ccd.displayApi[self.interactable:getId()] = self:getApi()
end

function Display:unbindApi()
    sm.mod.ccd.displayApi[self.interactable:getId()] = nil
end

function Display:createGui()
    self.gui = sm.gui.createGuiFromLayout(self.GUI_LAYOUT, false, { backgroundAlpha = 0.5 })
    
    self.gui:setButtonCallback("DoneButton", "guiCallback_Done")
    self.gui:setButtonCallback("CloseButton", "guiCallback_Close")

    self.gui:setButtonCallback("CB_left", "guiCallback_CBLeft")
    self.gui:setButtonCallback("CB_right", "guiCallback_CBRight")
    self.gui:setButtonCallback("DR_left", "guiCallback_DRLeft")
    self.gui:setButtonCallback("DR_right", "guiCallback_DRRight")
end

function Display:guiOpen()
    if not self.gui then
        self:createGui()
    end

    self.gui:setText("CB_value", tostring(self.bitMode))
    self.gui:setText("DR_value", table.concat({self.resolutionX, self.resolutionY}, 'x'))

    self.guiState.colorBits = self.bitMode
    self.guiState.resolutionX = self.resolutionX
    self.guiState.resolutionY = self.resolutionY

    self.gui:open()
end

function Display:destroyGui()
    self.gui:destroy()
end

function Display:guiCallback_Done()
    self.network:sendToServer("sv_changeState", self.guiState)
    self.gui:close()
end

function Display:guiCallback_Close()
    self.gui:close()
end

function Display:guiCallback_CBLeft()
    local newColorBits = math.max(self.guiState.colorBits - 1, self.COLOR_BITS_MIN)

    self.gui:setText("CB_value", tostring(newColorBits))
    self.guiState.colorBits = newColorBits
end

function Display:guiCallback_CBRight()
    local newColorBits = math.min(self.guiState.colorBits + 1, self.COLOR_BITS_MAX)

    self.gui:setText("CB_value", tostring(newColorBits))
    self.guiState.colorBits = newColorBits
end

function Display:guiCallback_DRLeft()
    local rX = self.guiState.resolutionX
    local rY = self.guiState.resolutionY

    if rX < rY then
        local ratio = rY / rX
        rX = math.max(rX - self.RESOLUTION_STEP, self.MIN_RESOLUTION)
        rY = rX * ratio
    else
        local ratio = rX / rY
        rY = math.max(rY - self.RESOLUTION_STEP, self.MIN_RESOLUTION)
        rX = rY * ratio
    end

    self.gui:setText("DR_value", table.concat({rX, rY}, 'x'))
    self.guiState.resolutionX = rX
    self.guiState.resolutionY = rY
end

function Display:guiCallback_DRRight()
    local rX = self.guiState.resolutionX
    local rY = self.guiState.resolutionY

    if rX < rY then
        local ratio = rY / rX
        rX = math.min(rX + self.RESOLUTION_STEP, self.maxResolutionX)
        rY = rX * ratio
    else
        local ratio = rX / rY
        rY = math.min(rY + self.RESOLUTION_STEP, self.maxResolutionY)
        rX = rY * ratio
    end

    self.gui:setText("DR_value", table.concat({rX, rY}, 'x'))
    self.guiState.resolutionX = rX
    self.guiState.resolutionY = rY
end

function Display:client_onCreate()
    local boundingBox = self.shape:getBoundingBox() * 4 * 32
    local currentResolutionX = boundingBox.z
    local currentResolutionY = boundingBox.y

    local mxResolutionScaler = 2

    ---@type Effect
    self.blackScreenEffect = nil

    self.effectStorage = EffectStorage.new(self.interactable)
    ---@type Layer[]
    self.layers = {}

    self.maxResolutionX = currentResolutionX * mxResolutionScaler
    self.maxResolutionY = currentResolutionY * mxResolutionScaler

    self.resolutionX = 0
    self.resolutionY = 0
    self.maxResolutionScaler = mxResolutionScaler

    self.bitMode = 5
    self.effectsShowing = false

    --- could be some trash because game has no event onDisconnect for logic, but it doesn't matter
    self.renderCallbacks = {}
    self.resolutionCallbacks = {}

    self.gui = nil
    self.guiState = {
        colorBits = self.bitMode,
        resolutionX = currentResolutionY,
        resolutionY = currentResolutionY
    }

    self:createBlackScreenEffect()
    self:changeResolution(currentResolutionX, currentResolutionY)
    self:changeBitMode(self.bitMode)
    self:bindApi()
end

function Display:client_onDestroy()
    self.blackScreenEffect:destroy()
    if self.gui then
        self:destroyGui()
    end
    self:unbindApi()
end

function Display:client_onFixedUpdate()
    if not self:needToRender() then
        if self.effectsShowing then
            self:destroyEffects()
            self.effectsShowing = false
        end
        return
    else
        if not self.effectsShowing then
            self:recreateEffects()
            self.effectsShowing = true
        end
    end

    self:emitRenderEvent()
end

function Display:client_onUpdate()
    if not self.effectsShowing then return end

    for zIndex, layer in pairs(self.layers) do
        layer:render()
    end
end

function Display:client_onInteract(char, state)
    if state then
        self:guiOpen()
    end
end

function Display:client_onClientDataUpdate(state, channel)
    local rX = state.resolutionX
    local rY = state.resolutionY
    local colorBits = state.colorBits

    if self.resolutionX ~= rX then
        self:changeResolution(rX, rY)
    end
    if self.bitMode ~= colorBits then
        self:changeBitMode(colorBits)
    end
end

function Display:server_onCreate()
    local state = self.storage:load()
    if state then
        self.network:setClientData(state)
    end
end

function Display:server_onFixedUpdate()
    local interactable = self.interactable
    local active = false
    for i, value in ipairs(interactable:getParents(sm.interactable.connectionType.logic)) do
        if value.active then 
            active = true
            break
        end
    end
    if interactable.active ~= active then
        interactable.active = active
    end
end

function Display:sv_changeState(state)
    self.network:setClientData(state)
    self.storage:save(state)
end