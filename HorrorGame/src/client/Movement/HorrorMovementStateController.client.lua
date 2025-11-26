local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer


-- Speeds
local SPRINT_SPEED_MULTIPLIER = 1.6   -- 1.5–1.8 feels good
local CROUCH_SPEED_MULTIPLIER = 0.45  -- slower creep

local CROUCH_HEIGHT = 1.2

local BASE_FOV = 70
local SPRINT_FOV = 75                -- how wide it gets while sprinting
local FOV_SMOOTHNESS = 10            -- higher = snappier

-- Smoothing
local CAMERA_SMOOTHNESS = 10         -- crouch up/down
local SPEED_SMOOTHNESS = 12          -- speed blending

local humanoid: Humanoid? = nil
local camera = workspace.CurrentCamera

local isCrouched = false
local isSprinting = false

local baseWalkSpeed = 16
local crouchSpeed = 7
local sprintSpeed = 20

local targetCameraOffset = Vector3.new(0, 0, 0)
local currentCameraOffset = Vector3.new(0, 0, 0)

local targetSpeed = nil

local function smoothFactor(dt, sharpness)
	if sharpness <= 0 then
		return 1
	end
	return 1 - math.exp(-sharpness * dt)
end

local function updateTargets()
	if not humanoid then return end

	if isCrouched then
		targetCameraOffset = Vector3.new(0, -CROUCH_HEIGHT, 0)
		targetSpeed = crouchSpeed
	elseif isSprinting then
		targetCameraOffset = Vector3.new(0, 0, 0)
		targetSpeed = sprintSpeed
	else
		targetCameraOffset = Vector3.new(0, 0, 0)
		targetSpeed = baseWalkSpeed
	end

	-- Expose state for other scripts (head bob, etc.)
	humanoid:SetAttribute("IsCrouched", isCrouched)
	humanoid:SetAttribute("IsSprinting", isSprinting)
end

local function setupCharacter(char: Model)
	humanoid = char:WaitForChild("Humanoid")

	baseWalkSpeed = humanoid.WalkSpeed
	crouchSpeed = baseWalkSpeed * CROUCH_SPEED_MULTIPLIER
	sprintSpeed = baseWalkSpeed * SPRINT_SPEED_MULTIPLIER

	isCrouched = false
	isSprinting = false

	currentCameraOffset = humanoid.CameraOffset
	targetCameraOffset = Vector3.new(0, 0, 0)
	targetSpeed = baseWalkSpeed

	humanoid:SetAttribute("IsCrouched", false)
	humanoid:SetAttribute("IsSprinting", false)
end

player.CharacterAdded:Connect(setupCharacter)
if player.Character then
	setupCharacter(player.Character)
end

UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed then return end
	if not humanoid or humanoid.Health <= 0 then return end

	if input.KeyCode == Enum.KeyCode.C or input.KeyCode == Enum.KeyCode.LeftControl then
		isCrouched = not isCrouched
		if isCrouched then
			-- Can't sprint while crouched
			isSprinting = false
		end
		updateTargets()
	elseif input.KeyCode == Enum.KeyCode.LeftShift then
		-- Start sprint (only if not crouched)
		if not isCrouched then
			isSprinting = true
			updateTargets()
		end
	end
end)

UserInputService.InputEnded:Connect(function(input, gameProcessed)
	if gameProcessed then return end
	if not humanoid or humanoid.Health <= 0 then return end

	if input.KeyCode == Enum.KeyCode.LeftShift then
		isSprinting = false
		updateTargets()
	end
end)

RunService.RenderStepped:Connect(function(dt)
	if not humanoid or humanoid.Health <= 0 then
		return
	end

	camera = workspace.CurrentCamera
	if not camera then return end

	local alphaCam = smoothFactor(dt, CAMERA_SMOOTHNESS)
	currentCameraOffset = currentCameraOffset:Lerp(targetCameraOffset, alphaCam)
	humanoid.CameraOffset = currentCameraOffset

	if targetSpeed then
		local alphaSpeed = smoothFactor(dt, SPEED_SMOOTHNESS)
		humanoid.WalkSpeed = humanoid.WalkSpeed
			+ (targetSpeed - humanoid.WalkSpeed) * alphaSpeed
	end

	local moveMag = humanoid.MoveDirection.Magnitude
	local desiredFov = BASE_FOV

	if isSprinting and not isCrouched and moveMag > 0.1 then
		desiredFov = SPRINT_FOV
	end

	local alphaFov = smoothFactor(dt, FOV_SMOOTHNESS)
	camera.FieldOfView = camera.FieldOfView
		+ (desiredFov - camera.FieldOfView) * alphaFov
end)
