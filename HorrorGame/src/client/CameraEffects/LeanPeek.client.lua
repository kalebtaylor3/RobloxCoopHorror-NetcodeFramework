local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer
local camera = workspace.CurrentCamera

-- Camera CFrame before lean is applied (captured each frame just before we lean)
local baseNoLeanCFrame: CFrame? = nil

-- How far / how much we lean
local MAX_LEAN_OFFSET_X = 2.4                 -- side shift (studs) – bigger so it feels like a real peek
local MAX_LEAN_OFFSET_Y = -0.3                -- slight dip down when leaning
local MAX_LEAN_YAW     = math.rad(-10)          -- disable yaw for now (avoid spin while we debug camera)
local MAX_LEAN_ROLL    = math.rad(25)         -- tilt head with the lean

local LEAN_SMOOTHNESS  = 7                   -- higher = snappier, lower = floatier

local humanoid: Humanoid? = nil

local LEAN_ATTRIBUTE_NAME = "LeanAmount"      -- so other effects (breathing, etc.) can react

-- -1 = full left, 0 = neutral, 1 = full right
local targetLean = 0
local currentLean = 0

local function smoothFactor(dt, sharpness)
	if sharpness <= 0 then
		return 1
	end
	return 1 - math.exp(-sharpness * dt)
end

local function setupCharacter(char: Model)
	humanoid = char:WaitForChild("Humanoid")
	targetLean = 0
	currentLean = 0

	if humanoid then
		humanoid:SetAttribute(LEAN_ATTRIBUTE_NAME, 0)
	end
end

player.CharacterAdded:Connect(setupCharacter)
if player.Character then
	setupCharacter(player.Character)
end

local function onRenderStepped(dt)
	camera = workspace.CurrentCamera
	if not camera then return end
	if not baseNoLeanCFrame then
		-- We haven't captured a base CFrame yet this frame; bail out safely.
		return
	end

	-- Decide what we WANT the lean to be this frame, based on
	-- whether Q/E are currently held down.
	local qDown = UserInputService:IsKeyDown(Enum.KeyCode.Q)
	local eDown = UserInputService:IsKeyDown(Enum.KeyCode.E)
		local dir = 0
		if eDown and not qDown then
			dir = 1
		elseif qDown and not eDown then
			dir = -1
		end
		targetLean = dir

		if not humanoid or humanoid.Health <= 0 then
			if humanoid then
				humanoid:SetAttribute(LEAN_ATTRIBUTE_NAME, 0)
			end
			currentLean = 0
			targetLean = 0
			return
		end

		-- Smoothly follow the desired lean amount (-1..1)
		local alpha = smoothFactor(dt, LEAN_SMOOTHNESS)
		currentLean = currentLean + (targetLean - currentLean) * alpha

		-- Crouching can soften the lean a bit
		local isCrouched = humanoid:GetAttribute("IsCrouched") == true
		local leanScale = isCrouched and 0.7 or 1.0

		local leanAmount = currentLean * leanScale
		humanoid:SetAttribute(LEAN_ATTRIBUTE_NAME, leanAmount)

		-- If we're effectively not leaning, don't modify the camera
		if math.abs(leanAmount) < 0.001 then
			return
		end

		-- Take the camera CFrame captured right before this step as the base
		local baseCFrame = baseNoLeanCFrame

		-- Build the full lean transform for this frame
		local offsetX = MAX_LEAN_OFFSET_X * leanAmount
		local offsetY = MAX_LEAN_OFFSET_Y * math.abs(leanAmount)
		local yaw     = -MAX_LEAN_YAW * leanAmount
		local roll    = -MAX_LEAN_ROLL * leanAmount

		local leanTransform =
			CFrame.new(offsetX, offsetY, 0)
			* CFrame.Angles(0, yaw, roll)

		camera.CFrame = baseCFrame * leanTransform
end

-- Capture the camera CFrame after all other effects (lag, bob, tilt, breathing)
-- but BEFORE we apply lean, so lean never compounds on itself.
RunService:BindToRenderStep(
	"HorrorLeanPeekBase",
	Enum.RenderPriority.Camera.Value + 4,
	function(dt)
		camera = workspace.CurrentCamera
		if not camera then return end
		baseNoLeanCFrame = camera.CFrame
	end
)

RunService:BindToRenderStep(
	"HorrorLeanPeek",
	Enum.RenderPriority.Camera.Value + 5, -- after other camera effects
	onRenderStepped
)

