dofile "$MOD_DATA/Scripts/Config.lua"

RaycastCamera = class()

RaycastCamera.maxParentCount = -1
RaycastCamera.maxChildCount = 1
RaycastCamera.connectionInput = sm.interactable.connectionType.logic
RaycastCamera.connectionOutput = sm.interactable.connectionType.video
RaycastCamera.colorNormal = sm.color.new(0x673ec7ff)
RaycastCamera.colorHighlight = sm.color.new(0x845ae6ff)

---@type Interactable
RaycastCamera.interactable = {}

---@type Shape
RaycastCamera.shape = {}

---@param fov number number in 180deg range
function RaycastCamera:changeFov(fov)
    self.fov = fov
end

function RaycastCamera:initResolutionAndBuffers()
    local resolution = self.api:getResolution()
    self.resolutionX = resolution.x
    self.resolutionY = resolution.y

    self.rayBuffer = {}
    self.pixelBuffer = {}
    local rayBuffer = self.rayBuffer
    local pixelBuffer = self.pixelBuffer

    for i = 1, math.min(self.resolutionX * self.resolutionY, self.pixelsAtFrame) do
        rayBuffer[i] = {
            type = "ray",
            startPoint = 0,
            endPoint = 0
        }
    end

    local black = sm.color.new(0x000000ff)

    for i = 1, self.resolutionX * self.resolutionY do
        pixelBuffer[i] = black
    end
end

function RaycastCamera:renderToBuffer()
    local rX = self.resolutionX
    local rY = self.resolutionY
    local mxPixels = rX * rY
    local rMax = math.max(rX, rY)

    local baseColor = sm.color.new(0x000000ff)
    local groundColor = sm.color.new(0xffffffff)

    local position = self.shape.worldPosition
    local rotation = self.shape.worldRotation
    local fovDistance = 1 * self.distance -- TODO: convert from ged to this fov

    local bufferV = sm.vec3.new(0, 0, self.distance)

    local rayBuffer = self.rayBuffer

    local hX = (rMax - rX) * 0.5
    local hY = (rMax - rY) * 0.5

    local px = self.nextPixel
    self.nextPixel = (px + self.pixelsAtFrame) % mxPixels

    local floor = math.floor

    local step =  math.min(self.pixelsAtFrame, mxPixels)

    for i = 1, step do
        local iPx = (px + i - 1) % mxPixels + 1
        local x = iPx % rX + hX
        local y = floor(iPx / rX) + hY

        bufferV.x = (0.5 - x / rMax) * fovDistance
        bufferV.y = (0.5 - y / rMax) * fovDistance

        local rayDatum = rayBuffer[i]
        rayDatum.startPoint = position
        rayDatum.endPoint = position + rotation * bufferV
    end

    local pixelBuffer = self.pixelBuffer
    local results = sm.physics.multicast(rayBuffer)

    for i = 1, step do
        local iPx = (px + i - 1) % mxPixels + 1

        local r = results[i]
        local hasCollision = r[1]
        ---@type RaycastResult
        local info = r[2]

        if hasCollision then
            local shape = info:getShape()
            if shape then
                pixelBuffer[iPx] = shape.color * (1 - info.fraction)
            else
                pixelBuffer[iPx] = groundColor * (1 - info.fraction)
            end
        else
            pixelBuffer[iPx] = baseColor
        end
    end

    self.api:renderFullBuffer(pixelBuffer, 1)
end

function RaycastCamera:onDisplayConnected()
    local id = self.connectedDisplayId

    ---@type DisplayApi
    local api = sm.mod.ccd.displayApi[id]

    api:setRenderCallback(self.interactable, function() self:renderToBuffer() end)
    api:setResolutionCallback(self.interactable, function() self:initResolutionAndBuffers() end)

    self.api = api
    self:initResolutionAndBuffers()
end

function RaycastCamera:onDisplayDisconnected()
    self.pixelBuffer = {}
    self.rayBuffer = {}
    self.resolutionX = 0
    self.resolutionY = 0

    if sm.mod.ccd.displayApi[self.connectedDisplayId] then
        self.api:removeRenderCallback(self.interactable)
        self.api:removeResolutionCallback(self.interactable)
    end
    self.api = nil
end

function RaycastCamera:client_onCreate()
    self.fov = 90
    self.distance = 50
    self.connectedDisplayId = -1

    self.resolutionX = 0
    self.resolutionY = 0
    self.rayBuffer = {}
    self.pixelBuffer = {}

    self.pixelsAtFrame = 1024
    self.nextPixel = 0

    ---@type DisplayApi|nil
    self.api = nil
end

function RaycastCamera:client_onFixedUpdate()
    local display = self.interactable:getChildren()[1]
    if display then
        local displayId = display:getId()
        if displayId ~= self.connectedDisplayId then
            self.connectedDisplayId = displayId
            self:onDisplayConnected()
        end
    elseif self.connectedDisplayId ~= -1 then
        self:onDisplayDisconnected()
        self.connectedDisplayId = -1
    end
end