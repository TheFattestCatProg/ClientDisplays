dofile "$MOD_DATA/Scripts/Config.lua"

RaycastCamera = class()

RaycastCamera.maxParentCount = -1
RaycastCamera.maxChildCount = 1
RaycastCamera.connectionInput = sm.interactable.connectionType.logic
RaycastCamera.connectionOutput = sm.interactable.connectionType.video
RaycastCamera.colorNormal = sm.color.new(0x673ec7ff)
RaycastCamera.colorHighlight = sm.color.new(0x845ae6ff)

