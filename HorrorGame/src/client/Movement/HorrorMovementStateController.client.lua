local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer


-- Speeds
local SPRINT_SPEED_MULTIPLIER = 1.6   -- 1.5–1.8 feels good
local CROUCH_SPEED_MULTIPLIER = 0.45  -- slower creep

local CROUCH_HEIGHT = 1.2
-- Extra camera drop while sliding compared to normal crouch.
local SLIDE_EXTRA_DROP = 0.35

local BASE_FOV = 70
local SPRINT_FOV = 75                -- how wide it gets while sprinting
local FOV_SMOOTHNESS = 10            -- higher = snappier

-- Smoothing
local CAMERA_SMOOTHNESS = 10         -- crouch up/down
local SPEED_SMOOTHNESS = 12          -- blend between walk / crouch / sprint
local MOVE_ACCEL_SHARPNESS = 4       -- how quickly you speed up (lower = heavier)
local MOVE_DECEL_SHARPNESS = 4      -- how quickly you slow down

local humanoid: Humanoid? = nil
local camera = workspace.CurrentCamera

local isCrouched = false
local isSprinting = false
local isSliding = false

-- Whether the crouch key is currently held down.
local isCrouchHeld = false

-- Direction the player was moving when the slide started (horizontal).
local slideDirection: Vector3? = nil
-- Our own slide speed (studs/second), independent of Roblox friction.
local slideSpeed = 0

local baseWalkSpeed = 16
local crouchSpeed = 7
local sprintSpeed = 20

-- Smoothed state speed (walk / crouch / sprint)
local currentStateSpeed = baseWalkSpeed

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

	if isSliding then
		-- Sliding: slightly lower than crouch to really sell the slide.
		targetCameraOffset = Vector3.new(0, -(CROUCH_HEIGHT + SLIDE_EXTRA_DROP), 0)
		targetSpeed = sprintSpeed
	elseif isCrouched then
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
	humanoid:SetAttribute("IsSliding", isSliding)
end

local function setupCharacter(char: Model)
	humanoid = char:WaitForChild("Humanoid")

	baseWalkSpeed = humanoid.WalkSpeed
	crouchSpeed = baseWalkSpeed * CROUCH_SPEED_MULTIPLIER
	sprintSpeed = baseWalkSpeed * SPRINT_SPEED_MULTIPLIER

	isCrouched = false
	isSprinting = false
	isSliding = false

	currentCameraOffset = humanoid.CameraOffset
	targetCameraOffset = Vector3.new(0, 0, 0)
	targetSpeed = baseWalkSpeed
	currentStateSpeed = baseWalkSpeed
	humanoid.WalkSpeed = 0 -- start fully stopped so we can accelerate into motion

	humanoid:SetAttribute("IsCrouched", false)
	humanoid:SetAttribute("IsSprinting", false)
	humanoid:SetAttribute("IsSliding", false)
end

local function getRootPart(): BasePart?
	if not humanoid then return nil end
	local rootPart = humanoid.RootPart
	if rootPart == nil then
		local char = humanoid.Parent
		if char and char:IsA("Model") then
			rootPart = char:FindFirstChild("HumanoidRootPart") :: BasePart
		end
	end
	return rootPart
end

-- How fast the slide starts and how quickly it slows down.
local SLIDE_START_SPEED = 32      -- starting horizontal speed for a slide
local SLIDE_DECEL_RATE = 18      -- how many studs/sec of slideSpeed we lose per second

local function startSlide()
	if not humanoid then return end
	if isSliding then return end

	isSliding = true
	isCrouched = true
	isSprinting = false

	updateTargets()

	local rootPart = getRootPart()
	if not rootPart then return end

	-- Use current movement / facing to define slide direction.
	local moveDir = humanoid.MoveDirection
	if moveDir.Magnitude > 0.1 then
		moveDir = Vector3.new(moveDir.X, 0, moveDir.Z).Unit
	else
		moveDir = rootPart.CFrame.LookVector
		moveDir = Vector3.new(moveDir.X, 0, moveDir.Z)
		if moveDir.Magnitude <= 0 then
			return
		end
		moveDir = moveDir.Unit
	end

	slideDirection = moveDir
	slideSpeed = SLIDE_START_SPEED
end

player.CharacterAdded:Connect(setupCharacter)
if player.Character then
	setupCharacter(player.Character)
end

UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed then return end
	if not humanoid or humanoid.Health <= 0 then return end

	if input.KeyCode == Enum.KeyCode.C or input.KeyCode == Enum.KeyCode.LeftControl then
		-- Hold-to-crouch behavior.
		isCrouchHeld = true
		if not isCrouched then
			-- If we're sprinting and actually moving, start a slide.
			if isSprinting and humanoid.MoveDirection.Magnitude > 0.05 then
				startSlide()
			else
				isCrouched = true
				isSprinting = false
				isSliding = false
				updateTargets()
			end
		end
	elseif input.KeyCode == Enum.KeyCode.LeftShift then
		-- Start sprint (only if not crouched or sliding)
		if not isCrouched and not isSliding then
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
	elseif input.KeyCode == Enum.KeyCode.C or input.KeyCode == Enum.KeyCode.LeftControl then
			-- Release crouch.
			isCrouchHeld = false
			-- If we're not currently sliding, stand up immediately.
			-- If we *are* sliding, we stay in crouch until the slide naturally ends.
			if not isSliding then
				isCrouched = false
				updateTargets()
			end
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
		
			local moveMag = humanoid.MoveDirection.Magnitude
			
				if isSliding then
					-- While sliding, fully commit: no walking control, we drive motion.
					humanoid.WalkSpeed = 0
					local rootPart = getRootPart()
					if rootPart and slideDirection and slideDirection.Magnitude > 0 then
						local vel = rootPart.AssemblyLinearVelocity
						-- Decay our custom slide speed over time for a smooth slow-down.
						slideSpeed = math.max(0, slideSpeed - SLIDE_DECEL_RATE * dt)
						if slideSpeed <= 0.1 then
							-- Slide has naturally ended; decide if we remain crouched.
							isSliding = false
							slideDirection = nil
							if not isCrouchHeld then
								isCrouched = false
							end
							updateTargets()
						else
							local dir = slideDirection.Unit
							local horizVel = dir * slideSpeed
							-- Preserve current vertical velocity, override horizontal.
							rootPart.AssemblyLinearVelocity = Vector3.new(horizVel.X, vel.Y, horizVel.Z)
						end
					else
						-- Fallback: no root or direction, just end slide.
						isSliding = false
						slideDirection = nil
						updateTargets()
					end
				else
			-- Normal speed smoothing (walk / crouch / sprint).
			if targetSpeed then
				local alphaState = smoothFactor(dt, SPEED_SMOOTHNESS)
				currentStateSpeed = currentStateSpeed
					+ (targetSpeed - currentStateSpeed) * alphaState
			else
				currentStateSpeed = humanoid.WalkSpeed
			end
		
			-- Then apply acceleration / deceleration based on whether the
			-- player is actually trying to move.
			local desiredSpeed = 0
			if moveMag > 0.05 then
				desiredSpeed = currentStateSpeed
			end
		
			local sharpness
			if desiredSpeed > humanoid.WalkSpeed then
				sharpness = MOVE_ACCEL_SHARPNESS
			else
				sharpness = MOVE_DECEL_SHARPNESS
			end
		
			local alphaMove = smoothFactor(dt, sharpness)
			humanoid.WalkSpeed = humanoid.WalkSpeed
				+ (desiredSpeed - humanoid.WalkSpeed) * alphaMove
		end
		
		-- FOV: sprinting or sliding widen FOV.
		local desiredFov = BASE_FOV
		if (isSprinting and not isCrouched and moveMag > 0.1) or isSliding then
			desiredFov = SPRINT_FOV
		end
		
		local alphaFov = smoothFactor(dt, FOV_SMOOTHNESS)
		camera.FieldOfView = camera.FieldOfView
			+ (desiredFov - camera.FieldOfView) * alphaFov
end)
