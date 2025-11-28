local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer
local camera = workspace.CurrentCamera


local BREATH_AMPLITUDE_Y = 1.09   -- vertical (chest rise)
local BREATH_AMPLITUDE_Z = 1.05   -- slight forward/back


local BREATH_PITCH_AMPLITUDE = math.rad(0.7)  -- tiny nod
local BREATH_ROLL_AMPLITUDE  = math.rad(0.45) -- tiny tilt


local BREATH_SPEED = 1.25

local INTENSITY_SMOOTHNESS = 6    -- higher = snappier


local MOVE_FADE = 0.9

local humanoid: Humanoid? = nil

local currentIntensity = 0

local lastBreathTransform = CFrame.new()

-- Optional: fade breathing a bit while leaning so the lean stays readable
local LEAN_ATTRIBUTE_NAME = "LeanAmount"
local LEAN_BREATH_DAMP = 0.7   -- at full lean, reduce breathing to ~30%

local function setupCharacter(char: Model)
	humanoid = char:WaitForChild("Humanoid")
	currentIntensity = 0
	lastBreathTransform = CFrame.new()
end

player.CharacterAdded:Connect(setupCharacter)
if player.Character then
	setupCharacter(player.Character)
end

local function smoothFactor(dt, sharpness)
	if sharpness <= 0 then
		return 1
	end
	return 1 - math.exp(-sharpness * dt)
end

local function onRenderStepped(dt)
	camera = workspace.CurrentCamera
	if not camera then return end

		local speed = 0
		local leanAmount = 0
		if humanoid and humanoid.Health > 0 then
			speed = humanoid.MoveDirection.Magnitude
			leanAmount = math.abs(humanoid:GetAttribute(LEAN_ATTRIBUTE_NAME) or 0)
		end
	
		local idleFactor = 1 - math.clamp(speed * MOVE_FADE, 0, 1)
		local leanDamp = 1 - math.clamp(leanAmount * LEAN_BREATH_DAMP, 0, 0.95)
		idleFactor = idleFactor * leanDamp

	-- Smooth intensity so it eases in/out
	local alpha = smoothFactor(dt, INTENSITY_SMOOTHNESS)
	currentIntensity = currentIntensity + (idleFactor - currentIntensity) * alpha

	if currentIntensity < 0.001 then
		if lastBreathTransform ~= CFrame.new() then
			camera.CFrame = camera.CFrame * lastBreathTransform:Inverse()
			lastBreathTransform = CFrame.new()
		end
		return
	end

	if lastBreathTransform ~= CFrame.new() then
		camera.CFrame = camera.CFrame * lastBreathTransform:Inverse()
	end

	local t = os.clock() * BREATH_SPEED


	local offsetY = math.sin(t) * BREATH_AMPLITUDE_Y * currentIntensity
	local offsetZ = math.cos(t) * BREATH_AMPLITUDE_Z * currentIntensity


	local pitch = math.sin(t + math.pi / 2) * BREATH_PITCH_AMPLITUDE * currentIntensity
	local roll  = math.sin(t * 0.8) * BREATH_ROLL_AMPLITUDE * currentIntensity

	local newTransform =
		CFrame.new(0, offsetY, offsetZ)
		* CFrame.Angles(pitch, 0, roll)

	camera.CFrame = camera.CFrame * newTransform


	lastBreathTransform = newTransform
end

RunService:BindToRenderStep(
	"HorrorBreathing",
	Enum.RenderPriority.Camera.Value + 4, -- after bob
	onRenderStepped
)
