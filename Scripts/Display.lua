dofile "$MOD_DATA/Scripts/Config.lua"

---@class Display
Display = class()

Display.maxParentCount = -1
Display.maxChildCount = 0
Display.connectionInput = sm.interactable.connectionType.video
Display.connectionOutput = sm.interactable.connectionType.none
Display.colorNormal = sm.color.new(0x673ec7ff)
Display.colorHighlight = sm.color.new(0x845ae6ff)

---@type Interactable
Display.interactable = {}

---@type Shape
Display.shape = {}

Display.PIXEL_SHAPE_UUID = sm.uuid.new("031397e3-e039-4b21-89f0-3316baf6ccff")
Display.PIXEL_SCALE = 0.0072
Display.RENDER_DISTANCE = 8
Display.DISPLAY_FORWARD = sm.vec3.new(1, 0, 0)

---@return DisplayApi
function Display:getApi()
    return DisplayApi.new(self)
end

---This function must be called always when resolution has changed.
function Display:initPixelBuffer()
    local colNew = sm.color.new

    self.pixelBuffer = {}
    for i = 1, self.resolutionX * self.resolutionY do
        self.pixelBuffer[i] = colNew(0x000000ff)
    end
end

---Changes the resolution of display. Also recreates buffers.
---@param x integer
---@param y integer
function Display:changeResolution(x, y)
    self.resolutionX = x
    self.resolutionY = y

    self.resolutionXHalf = x * 0.5
    self.resolutionYHalf = y * 0.5

    local maxSize = math.max(x, y)
    self.maxQuadSize = 2 ^ math.ceil(math.log(maxSize, 2)) -- math. there doesn't matter

    self:initPixelBuffer()
    self:emitResolutionEvent()
end

---@param s number
function Display:setPixelScale(s)
    self.pixelSize = s * self.PIXEL_SCALE
end

---@param bits integer
function Display:changeColorBits(bits)
    self.colorBits = bits
    self.colorBitsMultiplier1 = 255 / (2 ^ (8 - bits))
    self.colorBitsMultiplier2 = 1 / (2 ^ bits - 1)
end

---@param buffer Color[]
---@param zIndex integer
---@param isParticial boolean
function Display:appendToRenderQueue(buffer, zIndex, isParticial)
    if not self.renderQueue[zIndex] then
        self.renderQueue[zIndex] = {}
    end

    local zQueue = self.renderQueue[zIndex]

    zQueue[#zQueue+1] = {buffer, isParticial}
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
    for i, value in ipairs(self.interactable:getParents()) do
        local value = self.renderCallbacks[value:getId()]
        if value then value() end
    end
end

function Display:emitResolutionEvent()
    for i, value in ipairs(self.interactable:getParents()) do
        local value = self.resolutionCallbacks[value:getId()]
        if value then value() end
    end
end

---Checks if there some conditions to render image
---@return boolean
function Display:needToRender()
    local displayForward = self.shape.worldRotation * self.DISPLAY_FORWARD
    local character = sm.localPlayer.getPlayer().character
    if not character then return false end

    local posDelta = self.shape.worldPosition - character.worldPosition
    local distance = posDelta:length()
    if distance > self.RENDER_DISTANCE then return false end

    -- player behind the display
    if displayForward:dot(posDelta) <= 0 then return false end

    -- TODO: if player cannot see display

    return true
end

function Display:getEffect()
    local size = self.effectBufferOldSize -- first try get from old buffer
    if size > 0 then
        self.effectBufferOldSize = size - 1
        return self.effectBufferOld[size]
    end

    size = self.effectStorageSize -- if that buffer empty, get from storage
    if size > 0 then
        self.effectStorageSize = size - 1
        return self.effectStorage[size]
    end

    local effect = sm.effect.createEffect("ShapeRenderable", self.interactable)
	effect:setParameter("uuid", self.PIXEL_SHAPE_UUID)
	effect:start()

    return effect
end

---@param effect Effect
function Display:ungetEffect(effect)
    local size = self.effectStorageSize + 1
    self.effectStorage[size] = effect
    self.effectStorageSize = size
end

function Display:swapEffectBuffers()
    local b = self.effectBuffer
    self.effectBuffer = self.effectBufferOld
    self.effectBufferOld = b

    self.effectBufferOldSize = self.effectBufferSize
    self.effectBufferSize = 0
end

---@param buffer Color[]
function Display:renderParticialBuffer(buffer)
    -- TODO: pairs instead of full cycle if #buffer less 20%?
    local floor = math.floor -- this doesn't matter
    local m1 = self.colorBitsMultiplier1
    local m2 = self.colorBitsMultiplier2
    local pixelBuffer = self.pixelBuffer

    for i = 1, self.resolutionX * self.resolutionY do
        local color = buffer[i]
        local bufferColor = pixelBuffer[i]
        if color ~= nil then
            bufferColor.r = floor(color.r * m1) * m2 -- optimize somehow
            bufferColor.g = floor(color.g * m1) * m2
            bufferColor.b = floor(color.b * m1) * m2
        end
    end
end

---@param buffer Color[]
function Display:renderFullBuffer(buffer)
    local floor = math.floor
    local m1 = self.colorBitsMultiplier1
    local m2 = self.colorBitsMultiplier2
    local pixelBuffer = self.pixelBuffer

    for i = 1, self.resolutionX * self.resolutionY do
        local color = buffer[i]
        local bufferColor = pixelBuffer[i]

        bufferColor.r = floor(color.r * m1) * m2
        bufferColor.g = floor(color.g * m1) * m2
        bufferColor.b = floor(color.b * m1) * m2
    end
end

function Display:renderQueueToPixelBuffer()
    for i, zIndexTable in ipairs(self.renderQueue) do
        for z, value in ipairs(zIndexTable) do
            print(value)
            if value[2] then
                self:renderParticialBuffer(value[1])
            else
                self:renderFullBuffer(value[1])
            end
        end
    end
end


---Position from left top corner
---@param posX integer
---@param posY integer
---@param quadSize integer
---@param color Color
function Display:putEffectOnDisplay(posX, posY, quadSize, color)
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

    bv.x = self.DISPLAY_OFFSET_X
    bv.y = (posY - self.resolutionYHalf + quadSizeHalf) * pixelSize
    bv.z = (self.resolutionXHalf - posX - quadSizeHalf) * pixelSize

    effect:setOffsetPosition(bv)

    effect:setParameter("color", color)

    local edn = self.effectBufferSize + 1
    self.effectBuffer[edn] = effect
    self.effectBufferSize = edn
end

function Display:clearEffectBuffer()
    local effects = self.effectBuffer

    for i = 1, self.effectBufferSize do
        local effect = effects[i]
        effect:setOffsetPosition(self.ZERO_VECTOR)
        self:ungetEffect(effect)
    end

    self.effectBufferSize = 0
end

function Display:clearEffectBufferOld()
    local effects = self.effectBufferOld

    for i = 1, self.effectBufferOldSize do
        local effect = effects[i]
        effect:setOffsetPosition(self.ZERO_VECTOR)
        self:ungetEffect(effect)
    end

    self.effectBufferOldSize = 0
end

function Display:startEffects()
    local storage = self.effectStorage

    for i = 1, self.effectStorageSize do
        storage[i]:start()
    end
end

function Display:stopEffects()
    self:clearEffectBuffer()
    local storage = self.effectStorage

    for i = 1, self.effectStorageSize do
        storage[i]:stop()
    end
end

---@param posX integer
---@param posY integer
---@param quadSize integer
---@return Color|nil
function Display:recursiveQuadTraversal(posX, posY, quadSize) --quadSize >= 1
    if quadSize == 1 then
        return self.pixelBuffer[posX + posY * self.resolutionX + 1]
    end
    local halfSize = quadSize * 0.5
    local posX2 = posX + halfSize
    local posY2 = posY + halfSize

    local c1 = self:recursiveQuadTraversal(posX, posY, halfSize)
    local c2, c3, c4

    if posY2 < self.resolutionY then
        c2 = self:recursiveQuadTraversal(posX, posY2, halfSize)
        if posX2 < self.resolutionX then
            c3 = self:recursiveQuadTraversal(posX2, posY, halfSize)
            c4 = self:recursiveQuadTraversal(posX2, posY2, halfSize)
        end
    else
        if posX2 < self.resolutionX then
            c3 = self:recursiveQuadTraversal(posX2, posY, halfSize)
        end
    end

    if c1 ~= nil then
        if c1 == c2 and c1 == c3 and c1 == c4 then return c1 end
        self:putEffectOnDisplay(posX, posY, halfSize, c1)
    end
    if c2 ~= nil then self:putEffectOnDisplay(posX, posY2, halfSize, c2) end
    if c3 ~= nil then self:putEffectOnDisplay(posX2, posY, halfSize, c3) end
    if c4 ~= nil then self:putEffectOnDisplay(posX2, posY2, halfSize, c4) end
end

function Display:client_onCreate()
    -- for speed optimization:
    self.ZERO_VECTOR = sm.vec3.zero()
    self.DISPLAY_OFFSET_X = -0.117
    self.bufferVector = sm.vec3.zero()

    self.resolutionX = 0
    self.resolutionXHalf = 0
    self.resolutionY = 0
    self.resolutionYHalf = 0
    self.maxQuadSize = 0

    self.effectsShowing = false

    ---@type Color[]
    self.pixelBuffer = {}

    self:changeResolution(32, 32)

    self.pixelSize = 0
    self:setPixelScale(32 / 32)

    self.colorBits = 8
    self.colorBitsMultiplier1 = 0
    self.colorBitsMultiplier2 = 0
    self:changeColorBits(self.colorBits)

    self.renderQueue = {}

    --- could be some trash because game has no event onDisconnect for logic, but it doesn't matter
    self.renderCallbacks = {}
    self.resolutionCallbacks = {}

    ---@type Effect[]
    self.effectStorage = {}
    self.effectStorageSize = 0

    ---@type Effect[]
    self.effectBuffer = {} -- effects on display
    self.effectBufferSize = 0
    ---@type Effect[]
    self.effectBufferOld = {}
    self.effectBufferOldSize = 0

    sm.mod.ccd.displayApi[self.interactable:getId()] = self:getApi()
end

function Display:client_onDestroy()
    sm.mod.ccd.displayApi[self.interactable:getId()] = nil
end

function Display:client_onFixedUpdate()
    if not self:needToRender() then
        if self.effectsShowing then
            self:stopEffects()
            self.effectsShowing = false
        end
        return
    else
        if not self.effectsShowing then
            self:startEffects()
            self.effectsShowing = true
        end
    end

    self:emitRenderEvent()
    self:renderQueueToPixelBuffer()
    self.renderQueue = {}
end

function Display:client_onUpdate()
    if not self.effectsShowing then return end

    self:swapEffectBuffers()
    local color = self:recursiveQuadTraversal(0, 0, self.maxQuadSize)
    if color ~= nil then
        self:putEffectOnDisplay(0, 0, self.maxQuadSize, color)
    end

    self:clearEffectBufferOld()
end