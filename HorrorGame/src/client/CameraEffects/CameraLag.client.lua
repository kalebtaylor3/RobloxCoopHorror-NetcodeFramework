local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer
local camera = workspace.CurrentCamera

-- How strong the spring is.
-- Higher = snappier (less lag), lower = floatier (more lag).
local LAG_STIFFNESS = 13

local smoothedCFrame: CFrame? = nil

local function smoothFactor(dt, stiffness)
	if stiffness <= 0 then
		return 1
	end
	return 1 - math.exp(-stiffness * dt)
end

local function onRenderStepped(dt)
	camera = workspace.CurrentCamera
	if not camera then return end

	local targetCFrame = camera.CFrame

	if not smoothedCFrame then
		smoothedCFrame = targetCFrame
	end

	local alpha = smoothFactor(dt, LAG_STIFFNESS)
	smoothedCFrame = smoothedCFrame:Lerp(targetCFrame, alpha)

	camera.CFrame = smoothedCFrame
end

RunService:BindToRenderStep(
	"HorrorCameraLag",
	Enum.RenderPriority.Camera.Value + 1, -- AFTER default camera, BEFORE bob/breath
	onRenderStepped
)
