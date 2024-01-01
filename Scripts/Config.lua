if CCD_CONFIG_LOADED then return end
CCD_CONFIG_LOADED = true

sm.interactable.connectionType.video = sm.interactable.connectionType.video or 2097152

CCD_API_DISPLAYS = {}

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

---Renders buffer at given z-index. The buffer must contain all elements.
---Also it's not necessary to constantly create a new buffer when passing to this function.
---Also buffer starts since 1, because lua optimization 💀.
---@param buffer Color[]
---@param zIndex integer
function DisplayApi:renderFullBuffer(buffer, zIndex)
    self.display:appendToRenderQueue(buffer, zIndex, false)
end

---Renders buffer at given z-index. The buffer doesn't need to contain all elements.
---Also it's not necessary to constantly create a new buffer when passing to this function.
---Also buffer starts since 1, because lua optimization 💀.
---@param buffer Color[]
---@param zIndex integer
function DisplayApi:renderParticialBuffer(buffer, zIndex)
    self.display:appendToRenderQueue(buffer, zIndex, true)
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