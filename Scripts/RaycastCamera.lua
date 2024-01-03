dofile "$MOD_DATA/Scripts/Config.lua"

RaycastCamera = class()

RaycastCamera.maxParentCount = -1
RaycastCamera.maxChildCount = 1
RaycastCamera.connectionInput = sm.interactable.connectionType.logic
RaycastCamera.connectionOutput = sm.interactable.connectionType.video
RaycastCamera.colorNormal = sm.color.new(0x673ec7ff)
RaycastCamera.colorHighlight = sm.color.new(0x845ae6ff)

RaycastCamera.GUI_LAYOUT = "$CONTENT_DATA/Gui/Layouts/RaycastCamera.layout"

---@type Interactable
RaycastCamera.interactable = {}

---@type Shape
RaycastCamera.shape = {}

---@type Network
RaycastCamera.network = {}

---@type Storage
RaycastCamera.storage = {}

---@param fov number number in 180deg range
function RaycastCamera:changeFov(fov)
    self.fov = fov
end

function RaycastCamera:initResolutionAndBuffers()
    local resolution = self.api:getResolution()
    self.resolutionX = resolution.x
    self.resolutionY = resolution.y

    self.pixelBuffer = {}
    local pixelBuffer = self.pixelBuffer

    local black = sm.color.new(0x000000ff)

    for i = 1, self.resolutionX * self.resolutionY do
        pixelBuffer[i] = black
    end

    self:changePixelsPerFrame(self.pixelsPerFrame)
end


---@param value integer
function RaycastCamera:changePixelsPerFrame(value)
    self.rayBuffer = {}
    local rayBuffer = self.rayBuffer
    local filter = sm.physics.filter
    local mask = filter.default

    for i = 1, math.min(self.resolutionX * self.resolutionY, value) do
        rayBuffer[i] = {
            type = "ray",
            startPoint = 0,
            endPoint = 0,
            mask = mask
        }
    end

    self.pixelsPerFrame = value
end

function RaycastCamera:renderToBuffer()
    if not self.interactable.active then return end

    local rX = self.resolutionX
    local rY = self.resolutionY
    local mxPixels = rX * rY
    local rMax = math.max(rX, rY)

    local baseColor = sm.color.new(0x000000ff)
    local groundColor = sm.color.new(0xffffffff)

    local position = self.shape.worldPosition
    local rotation = self.shape.worldRotation
    local fovMultiplier = 2 * math.tan(self.fov / 360 * math.pi) * self.distance -- TODO: convert from ged to this fov

    local bufferV = sm.vec3.new(0, 0, self.distance)

    local rayBuffer = self.rayBuffer

    local hX = (rMax - rX) * 0.5
    local hY = (rMax - rY) * 0.5

    local px = self.nextPixel
    self.nextPixel = (px + self.pixelsPerFrame) % mxPixels

    local floor = math.floor

    local step =  math.min(self.pixelsPerFrame, mxPixels)

    for i = 1, step do
        local iPx = (px + i - 1) % mxPixels
        local x = iPx % rX + hX
        local y = floor(iPx / rX) + hY

        bufferV.x = (0.5 - x / rMax) * fovMultiplier
        bufferV.y = (0.5 - y / rMax) * fovMultiplier

        local rayDatum = rayBuffer[i]
        rayDatum.startPoint = position
        rayDatum.endPoint = position + rotation * bufferV
    end

    local pixelBuffer = self.pixelBuffer
    local results = sm.physics.multicast(rayBuffer)
    local exp = math.exp

    for i = 1, step do
        local iPx = (px + i - 1) % mxPixels + 1

        local r = results[i]
        local hasCollision = r[1]
        ---@type RaycastResult
        local info = r[2]

        if hasCollision then
            if info.type ~= "limiter" then
                local dir = info.directionWorld
                local d = -dir:dot(info.normalWorld)
                if d > 0 then
                    pixelBuffer[iPx] = groundColor * exp(-(d / dir:length() - 2) ^ 2)
                else
                    pixelBuffer[iPx] = baseColor
                end
            else
                pixelBuffer[iPx] = baseColor
            end
            --[[if shape then
                pixelBuffer[iPx] = shape.color * (1 - info.fraction)
            else
                pixelBuffer[iPx] = groundColor * (1 - info.fraction)
            end]]
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

function RaycastCamera:createGui()
    self.gui = sm.gui.createGuiFromLayout(self.GUI_LAYOUT, false, { backgroundAlpha = 0.5 })

    self.gui:setButtonCallback("DoneButton", "guiCallback_Done")
    self.gui:setButtonCallback("CloseButton", "guiCallback_Close")
end

function RaycastCamera:openGui()
    if not self.gui then
        self:createGui()
    end

    self.gui:setText("FV_value", tostring(self.fov))
    self.gui:setText("PF_value", tostring(self.pixelsPerFrame))
    self.gui:setText("D_value", tostring(self.distance))

    self.gui:setTextChangedCallback("PF_value", "guiCallback_EditBox_Changed")
    self.gui:setTextChangedCallback("FV_value", "guiCallback_EditBox_Changed")
    self.gui:setTextChangedCallback("D_value", "guiCallback_EditBox_Changed")

    self.guiState.fov = self.fov
    self.guiState.distance = self.distance
    self.guiState.pixelsPerFrame = self.pixelsPerFrame

    self.gui:open()
end

function RaycastCamera:guiCallback_Done()
    self.network:sendToServer("sv_changeState", self.guiState)
    self.gui:close()
end

function RaycastCamera:guiCallback_Close()
    self.gui:close()
end

function RaycastCamera:guiCallback_EditBox_Changed(wName, text)
    local n = tonumber(text)
    local guiState = self.guiState

    if not n then return end

    if wName == "PF_value" then
        if n < 1 then return end
        n = math.floor(n)
        guiState.pixelsPerFrame = n
    elseif wName == "FV_value" then
        if n <= 0 or n > 150 then return end
        guiState.fov = n
    elseif wName == "D_value" then
        if n <= 0 then return end
        guiState.distance = n or guiState.distance
    end
end

function RaycastCamera:client_onCreate()
    self.fov = 90
    self.distance = 50
    self.connectedDisplayId = -1

    self.resolutionX = 0
    self.resolutionY = 0
    self.rayBuffer = {}
    self.pixelBuffer = {}

    self.pixelsPerFrame = 1024
    self.nextPixel = 0

    ---@type DisplayApi|nil
    self.api = nil

    self.gui = nil
    self.guiState = {
        fov = self.fov,
        pixelsPerFrame = self.pixelsPerFrame,
        distance = self.distance
    }
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

function RaycastCamera:client_onInteract(char, state)
    if state then
        self:openGui()
    end
end

function RaycastCamera:client_onClientDataUpdate(state, channel)
    self.fov = state.fov
    self.distance = state.distance

    if self.pixelsPerFrame ~= state.pixelsPerFrame then
        self:changePixelsPerFrame(state.pixelsPerFrame)
    end
end

function RaycastCamera:server_onCreate()
    local state = self.storage:load()
    if state then
        self.network:setClientData(state)
    end
end

function RaycastCamera:server_onFixedUpdate()
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

function RaycastCamera:sv_changeState(state)
    self.storage:save(state)
    self.network:setClientData(state)
end