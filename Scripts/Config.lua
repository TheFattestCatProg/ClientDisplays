if CCD_CONFIG_LOADED then return end
CCD_CONFIG_LOADED = true

sm.interactable.connectionType.video = sm.interactable.connectionType.video or 2097152

sm.mod = sm.mod or {}
sm.mod.ccd = {
    displayApi = {}
}



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
---@return Color[]|nil
function DisplayApi:createBuffer(zIndex)
    local buffer = self.display:createLayer(zIndex)
    if not buffer then return nil end

    local mt = {
        __index = function (self, key)
            return buffer:getColor(key)
        end,
        __newindex = function (self, key, value)
            buffer:setColor(key, value)
        end
    }

    return class(mt)()
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