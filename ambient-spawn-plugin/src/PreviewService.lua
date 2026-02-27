local Constants = require(script.Parent.Constants)

local PreviewService = {
	ShowRadius = true,
	ShowMarkers = true,
	PreviewFolder = nil,
}

local GOLDEN_ANGLE = 2.399963229728653

local function ensurePreviewFolder()
	if PreviewService.PreviewFolder and PreviewService.PreviewFolder.Parent then
		return PreviewService.PreviewFolder
	end

	local existing = workspace:FindFirstChild(Constants.PREVIEW_FOLDER_NAME)
	if existing then
		existing:Destroy()
	end

	local folder = Instance.new("Folder")
	folder.Name = Constants.PREVIEW_FOLDER_NAME
	folder.Archivable = false
	folder.Parent = workspace
	PreviewService.PreviewFolder = folder
	return folder
end

local function clearPreviewObjects()
	local folder = PreviewService.PreviewFolder
	if not folder then
		return
	end
	for _, child in ipairs(folder:GetChildren()) do
		child:Destroy()
	end
end

local function getEnemyColor(enemyName)
	local hash = 0
	for index = 1, #enemyName do
		hash += string.byte(enemyName, index) * index
	end
	local hue = (hash % 360) / 360
	return Color3.fromHSV(hue, 0.55, 0.98)
end

local function getGroundedPosition(rawPosition, ignoreList)
	local rayParams = RaycastParams.new()
	rayParams.FilterType = Enum.RaycastFilterType.Exclude
	rayParams.FilterDescendantsInstances = ignoreList
	rayParams.IgnoreWater = true

	local rayOrigin = rawPosition + Vector3.new(0, 64, 0)
	local result = workspace:Raycast(rayOrigin, Vector3.new(0, -320, 0), rayParams)
	if result then
		return result.Position + Vector3.new(0, 3.5, 0)
	end
	return rawPosition + Vector3.new(0, 3.5, 0)
end

local function createRadiusAdornment(folder, worldPosition, radius)
	local sphere = Instance.new("SphereHandleAdornment")
	sphere.Name = "RadiusPreview"
	sphere.Adornee = workspace.Terrain
	sphere.AlwaysOnTop = false
	sphere.ZIndex = 1
	sphere.Color3 = Color3.fromRGB(82, 165, 255)
	sphere.Transparency = 0.83
	sphere.Radius = radius
	sphere.CFrame = CFrame.new(worldPosition)
	sphere.Parent = folder

	local centerDot = Instance.new("SphereHandleAdornment")
	centerDot.Name = "CenterPreview"
	centerDot.Adornee = workspace.Terrain
	centerDot.AlwaysOnTop = true
	centerDot.ZIndex = 2
	centerDot.Color3 = Color3.fromRGB(253, 220, 122)
	centerDot.Transparency = 0.1
	centerDot.Radius = 1.25
	centerDot.CFrame = CFrame.new(worldPosition)
	centerDot.Parent = folder
end

local function createEnemyMarker(folder, worldPosition, enemyName)
	local markerPart = Instance.new("Part")
	markerPart.Name = "EnemyMarkerAnchor"
	markerPart.Size = Vector3.new(0.2, 0.2, 0.2)
	markerPart.Transparency = 1
	markerPart.Anchored = true
	markerPart.Locked = true
	markerPart.CanCollide = false
	markerPart.CanTouch = false
	markerPart.CanQuery = false
	markerPart.Archivable = false
	markerPart.Position = worldPosition
	markerPart.Parent = folder

	local billboard = Instance.new("BillboardGui")
	billboard.Name = "EnemyMarkerBillboard"
	billboard.Adornee = markerPart
	billboard.AlwaysOnTop = true
	billboard.LightInfluence = 0
	billboard.Size = UDim2.fromOffset(92, 24)
	billboard.StudsOffset = Vector3.new(0, 2, 0)
	billboard.Parent = markerPart

	local label = Instance.new("TextLabel")
	label.Name = "Text"
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundColor3 = getEnemyColor(enemyName)
	label.BackgroundTransparency = 0.2
	label.BorderSizePixel = 0
	label.Font = Enum.Font.GothamSemibold
	label.TextSize = 11
	label.TextColor3 = Color3.fromRGB(26, 26, 26)
	label.Text = enemyName
	label.Parent = billboard

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 5)
	corner.Parent = label

	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.fromRGB(255, 255, 255)
	stroke.Thickness = 1
	stroke.Transparency = 0.5
	stroke.Parent = label
end

function PreviewService.SetOptions(showRadius, showMarkers)
	PreviewService.ShowRadius = showRadius == true
	PreviewService.ShowMarkers = showMarkers == true
end

function PreviewService.Render(records)
	local folder = ensurePreviewFolder()
	clearPreviewObjects()

	if not records or #records <= 0 then
		return
	end

	for _, record in ipairs(records) do
		if record.Node == nil or record.Node.Parent == nil then
			continue
		end

		local center = record.Position
		local radius = math.max(1, tonumber(record.Radius) or 1)
		local maxAlive = math.max(0, math.floor(tonumber(record.MaxAlive) or 0))
		local enemyPool = record.EnemyPool or {}
		if #enemyPool <= 0 then
			enemyPool = Constants.DEFAULT_ENEMY_POOL
		end

		if PreviewService.ShowRadius then
			createRadiusAdornment(folder, center, radius)
		end

		if PreviewService.ShowMarkers and maxAlive > 0 then
			local ignoreList = { folder }
			for index = 1, maxAlive do
				local distance = radius * math.sqrt((index - 0.5) / maxAlive) * 0.9
				local angle = GOLDEN_ANGLE * index
				local planarOffset = Vector3.new(math.cos(angle) * distance, 0, math.sin(angle) * distance)
				local basePosition = center + planarOffset
				local markerPosition = getGroundedPosition(basePosition, ignoreList)

				local enemyName = enemyPool[((index - 1) % #enemyPool) + 1]
				createEnemyMarker(folder, markerPosition, enemyName)
			end
		end
	end
end

function PreviewService.Destroy()
	if PreviewService.PreviewFolder and PreviewService.PreviewFolder.Parent then
		PreviewService.PreviewFolder:Destroy()
	end
	PreviewService.PreviewFolder = nil
end

return PreviewService
