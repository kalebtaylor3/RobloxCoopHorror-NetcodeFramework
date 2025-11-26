local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer
local camera = workspace.CurrentCamera

-- Base walking bob
local BOB_FREQUENCY = 7            -- higher = faster bob
local BOB_AMPLITUDE_X = 0.055      -- left/right sway
local BOB_AMPLITUDE_Y = 0.095      -- up/down bounce

-- Sprint modifiers (multiplied on top of base)
local SPRINT_FREQ_MULT = 1.6       -- faster bob when sprinting
local SPRINT_AMP_MULT  = 1.5       -- stronger bob when sprinting

-- Crouch modifiers
local CROUCH_FREQ_MULT = 0.7       -- slower bob when crouched
local CROUCH_AMP_MULT  = 0.4       -- smaller bob when crouched

local BOB_SMOOTHNESS = 10          -- higher = snappier, lower = floatier

-- Minimum movement magnitude before bob kicks in
local MOVE_THRESHOLD = 0.05

local humanoid: Humanoid? = nil
local bobTime = 0
local currentOffset = Vector3.new(0, 0, 0)

local function smoothFactor(dt, sharpness)
	if sharpness <= 0 then
		return 1
	end
	return 1 - math.exp(-sharpness * dt)
end

local function setupCharacter(char: Model)
	humanoid = char:WaitForChild("Humanoid")

	player.CameraMode = Enum.CameraMode.LockFirstPerson

	-- Reset state
	bobTime = 0
	currentOffset = Vector3.new(0, 0, 0)

	local UIS = game:GetService("UserInputService")
	UIS.MouseIconEnabled = false
	UIS.MouseBehavior = Enum.MouseBehavior.LockCenter
end

player.CharacterAdded:Connect(setupCharacter)
if player.Character then
	setupCharacter(player.Character)
end

local function onRenderStepped(dt)
	if not humanoid or humanoid.Health <= 0 then
		return
	end

	local moveDir = humanoid.MoveDirection
	local speed = moveDir.Magnitude
	local moving = speed > MOVE_THRESHOLD

	local isSprinting = humanoid:GetAttribute("IsSprinting") == true
	local isCrouched  = humanoid:GetAttribute("IsCrouched") == true

	-- Decide effective frequency & amplitude based on state
	local freq    = BOB_FREQUENCY
	local ampX    = BOB_AMPLITUDE_X
	local ampY    = BOB_AMPLITUDE_Y

	if isCrouched then
		freq = freq * CROUCH_FREQ_MULT
		ampX = ampX * CROUCH_AMP_MULT
		ampY = ampY * CROUCH_AMP_MULT
	elseif isSprinting then
		freq = freq * SPRINT_FREQ_MULT
		ampX = ampX * SPRINT_AMP_MULT
		ampY = ampY * SPRINT_AMP_MULT
	end

	--only bob when moving
	if moving then
		bobTime += dt * freq * (0.5 + 0.5 * speed)
	end

	local targetOffset: Vector3

	if moving then
		local x = math.sin(bobTime) * ampX
		local y = math.cos(bobTime * 2) * ampY
		targetOffset = Vector3.new(x, y, 0)
	else
		-- When not moving, we want to drift back to perfectly zero
		targetOffset = Vector3.new(0, 0, 0)
	end

	local alpha = smoothFactor(dt, BOB_SMOOTHNESS)
	currentOffset = currentOffset:Lerp(targetOffset, alpha)

	local baseCFrame = camera.CFrame
	camera.CFrame = baseCFrame * CFrame.new(currentOffset)
end

RunService:BindToRenderStep(
	"HorrorHeadBob",
	Enum.RenderPriority.Camera.Value + 2, -- after lag
	onRenderStepped
)
