--!nocheck
function gen()
	local ServerStorage = game:GetService("ServerStorage")
	local Workspace = game:GetService("Workspace")
	local Lighting = game:GetService("Lighting")
	local ReplicatedStorage = game:GetService("ReplicatedStorage")

	local Photobooth = require(ServerStorage.Photobooth.Bindings)

	local CAPTURE_SIZE = 500
	local SKY_HEIGHT = 10000
	local MODEL_Y_ROTATION = math.rad(150)

	-- Camera offset relative to PrimaryPart — tweak these two values
	local CAM_BACK = 8 -- how far behind the subject
	local CAM_ABOVE = 1 -- how far above the subject
	local CAM_LEFT = 0.333 -- how far left of the HRP to aim at

	local camera = Workspace.CurrentCamera
	local originalCameraType = camera.CameraType
	local originalCameraCFrame = camera.CFrame

	local atmosphere = Lighting:FindFirstChildOfClass("Atmosphere")
	if atmosphere then
		atmosphere.Parent = ReplicatedStorage
	end

	local assets = ServerStorage.Assets
	local result = game.StarterGui

	local function getCenteredRect(): Rect
		local vp = camera.ViewportSize
		local cx = math.floor(vp.X / 2)
		local cy = math.floor(vp.Y / 2)
		local half = CAPTURE_SIZE / 2
		return Rect.new(cx - half, cy - half, cx + half, cy + half)
	end

	local function frameModel(model: Model)
		local hrp = model:FindFirstChild("HumanoidRootPart") or model.PrimaryPart
		assert(hrp, model.Name .. " has no HumanoidRootPart or PrimaryPart")

		local base = Vector3.new(0, SKY_HEIGHT, 0)
		model:PivotTo(CFrame.new(base) * CFrame.Angles(0, MODEL_Y_ROTATION, 0))

		local subjectPos = hrp.Position
		local lookTarget = subjectPos + Vector3.new(-CAM_LEFT, 0, 0)
		local camPos = subjectPos + Vector3.new(0, CAM_ABOVE, CAM_BACK)

		camera.CameraType = Enum.CameraType.Scriptable
		camera.CFrame = CFrame.new(camPos, lookTarget)
	end

	local rect = getCenteredRect()

	for _, model in assets:GetChildren() do
		if not model:IsA("Model") then
			continue
		end

		model.Parent = Workspace
		frameModel(model)
		task.wait()

		local capture = Photobooth.captureViewport({
			rect = rect,
			type = "NoSkybox",
		})

		if not capture then
			warn("Capture returned nil for:", model.Name)
			model.Parent = assets
			continue
		end

		capture.Name = model.Name
		capture.Parent = result

		model.Parent = assets
		task.wait()
	end

	if atmosphere then
		atmosphere.Parent = Lighting
	end

	camera.CameraType = originalCameraType
	camera.CFrame = originalCameraCFrame

	print("Done")
end

gen()
