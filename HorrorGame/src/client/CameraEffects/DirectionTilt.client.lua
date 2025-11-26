local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer
local camera = workspace.CurrentCamera


local MAX_PITCH_FORWARD = math.rad(3)   
local MAX_PITCH_BACK    = math.rad(4)    
local MAX_ROLL_SIDE     = math.rad(2.5) 


local TILT_SMOOTHNESS   = 10          
local MOVE_THRESHOLD    = 0.03  


local humanoid: Humanoid? = nil
local currentPitch = 0
local currentRoll  = 0


local prevForwardAmount = 0

local function smoothFactor(dt, sharpness)
	if sharpness <= 0 then
		return 1
	end
	return 1 - math.exp(-sharpness * dt)
end

local function setupCharacter(char: Model)
	humanoid = char:WaitForChild("Humanoid")
	currentPitch = 0
	currentRoll = 0
	prevForwardAmount = 0
end

player.CharacterAdded:Connect(setupCharacter)
if player.Character then
	setupCharacter(player.Character)
end

local function onRenderStepped(dt)
	camera = workspace.CurrentCamera
	if not camera then return end
	if not humanoid or humanoid.Health <= 0 then
		return
	end

	local moveDir = humanoid.MoveDirection
	local speed = moveDir.Magnitude

	local targetPitch = 0
	local targetRoll  = 0

	if speed > MOVE_THRESHOLD then
		local dir = moveDir.Unit

		local camCF   = camera.CFrame
		local camFwd  = camCF.LookVector
		local camRight = camCF.RightVector

		camFwd   = Vector3.new(camFwd.X, 0, camFwd.Z)
		camRight = Vector3.new(camRight.X, 0, camRight.Z)

		if camFwd.Magnitude > 0 then camFwd = camFwd.Unit end
		if camRight.Magnitude > 0 then camRight = camRight.Unit end

		local forwardDot = camFwd:Dot(dir)   
		local rightDot   = camRight:Dot(dir)

		--FORWARD / BACK IMPULSE TILT
		local deltaForward = forwardDot - prevForwardAmount

		local forwardGain = 6 
		local impulse = deltaForward * forwardGain

		if impulse > 0.02 then
			local n = math.clamp(impulse, 0, 1)
			targetPitch = -MAX_PITCH_FORWARD * n
		elseif impulse < -0.02 then
			local n = math.clamp(-impulse, 0, 1)
			targetPitch =  MAX_PITCH_BACK * n
		end

		--LEFT / RIGHT TILT
		if math.abs(rightDot) > 0.1 then
			targetRoll = -MAX_ROLL_SIDE * math.clamp(rightDot, -1, 1)
		end

		prevForwardAmount = forwardDot
	else
		prevForwardAmount = 0
	end

	-- Crouch dampening
	local isCrouched = humanoid:GetAttribute("IsCrouched") == true
	local tiltScale = isCrouched and 0.4 or 1.0
	targetPitch *= tiltScale
	targetRoll  *= tiltScale

	local alpha = smoothFactor(dt, TILT_SMOOTHNESS)
	currentPitch = currentPitch + (targetPitch - currentPitch) * alpha
	currentRoll  = currentRoll  + (targetRoll  - currentRoll)  * alpha

	local baseCFrame = camera.CFrame
	camera.CFrame = baseCFrame * CFrame.Angles(currentPitch, 0, currentRoll)
end

RunService:BindToRenderStep(
	"HorrorDirectionTilt",
	Enum.RenderPriority.Camera.Value + 3,
	onRenderStepped
)
