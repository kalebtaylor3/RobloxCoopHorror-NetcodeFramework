-- ULTRA-SIMPLE DEBUG CAMERA: this script *only* handles mouse look.
-- It ignores the character completely for now so we can prove it works.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer
local camera = workspace.CurrentCamera

local MOUSE_SENSITIVITY = 0.0009
local MIN_PITCH = math.rad(-80)
local MAX_PITCH = math.rad(80)

local yaw = 0
local pitch = 0
local initialized = false

local function initFromCurrentCamera()
	camera = workspace.CurrentCamera
	if not camera then return end

	local look = camera.CFrame.LookVector
	yaw = math.atan2(-look.X, -look.Z)
	pitch = math.asin(look.Y)
	initialized = true

	camera.CameraType = Enum.CameraType.Scriptable
	UserInputService.MouseIconEnabled = false
	UserInputService.MouseBehavior = Enum.MouseBehavior.LockCenter
end

local function onRenderStepped(dt)
	camera = workspace.CurrentCamera
	if not camera then return end

	if not initialized then
		initFromCurrentCamera()
	end

	local delta = UserInputService:GetMouseDelta()
	yaw   -= delta.X * MOUSE_SENSITIVITY
	pitch -= delta.Y * MOUSE_SENSITIVITY

	if pitch < MIN_PITCH then pitch = MIN_PITCH end
	if pitch > MAX_PITCH then pitch = MAX_PITCH end

	local pos = camera.CFrame.Position
	local rotation = CFrame.Angles(0, yaw, 0) * CFrame.Angles(pitch, 0, 0)
	camera.CFrame = CFrame.new(pos) * rotation
end

RunService:BindToRenderStep(
	"HorrorFirstPersonCamera",
	Enum.RenderPriority.Camera.Value, -- base camera step
	onRenderStepped
)
