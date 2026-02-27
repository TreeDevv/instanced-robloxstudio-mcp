local CollectionService = game:GetService("CollectionService")
local Selection = game:GetService("Selection")
local ChangeHistoryService = game:GetService("ChangeHistoryService")

local Constants = require(script.Parent.Constants)
local Util = require(script.Parent.Util)

local NodeService = {}

local function normalizeNumberAttribute(attributeName, rawValue)
	local config = Constants.NUMERIC_FIELDS[attributeName]
	local defaultValue = Constants.DEFAULT_ATTRIBUTES[attributeName]
	local value = tonumber(rawValue)
	if value == nil then
		value = defaultValue
	end

	if config then
		value = Util.Clamp(value, config.Min, config.Max)
		value = Util.ApplyStep(value, config.Step)
		value = Util.Round(value, config.Precision or 0)
	end

	return value
end

local function collectBasePartsFromSelection(instances, includeTaggedOnly)
	local results = {}
	local seen = {}

	local function tryAdd(instance)
		if not instance:IsA("BasePart") then
			return
		end
		if includeTaggedOnly and not CollectionService:HasTag(instance, Constants.NODE_TAG) then
			return
		end
		if seen[instance] then
			return
		end
		seen[instance] = true
		table.insert(results, instance)
	end

	for _, selected in ipairs(instances) do
		tryAdd(selected)
		for _, desc in ipairs(selected:GetDescendants()) do
			tryAdd(desc)
		end
	end

	return results
end

local function setWaypointIfNeeded(options, fallbackName)
	if options and options.SkipWaypoint then
		return
	end
	local waypointName = fallbackName
	if options and type(options.WaypointName) == "string" and options.WaypointName ~= "" then
		waypointName = options.WaypointName
	end
	ChangeHistoryService:SetWaypoint(waypointName)
end

local function sanitizeAttributeValue(attributeName, value)
	if attributeName == "Enabled" then
		return value == true
	end

	if Constants.NUMERIC_FIELDS[attributeName] then
		return normalizeNumberAttribute(attributeName, value)
	end

	if attributeName == "IslandName" then
		return Util.Trim(tostring(value or ""))
	end

	if attributeName == "EnemyPool" then
		local poolList = Util.SplitCsv(tostring(value or ""))
		return Util.JoinCsv(poolList)
	end

	return value
end

local function ensureDefaultAttributes(node)
	for attributeName, defaultValue in pairs(Constants.DEFAULT_ATTRIBUTES) do
		if node:GetAttribute(attributeName) == nil then
			node:SetAttribute(attributeName, defaultValue)
		end
	end
end

local function sanitizeNodeAttributes(node)
	for _, attributeName in ipairs(Constants.NUMERIC_FIELD_ORDER) do
		local current = node:GetAttribute(attributeName)
		local sanitized = sanitizeAttributeValue(attributeName, current)
		node:SetAttribute(attributeName, sanitized)
	end

	local enabledValue = node:GetAttribute("Enabled")
	if type(enabledValue) ~= "boolean" then
		node:SetAttribute("Enabled", Constants.DEFAULT_ATTRIBUTES.Enabled)
	end

	local islandName = node:GetAttribute("IslandName")
	if type(islandName) ~= "string" then
		node:SetAttribute("IslandName", Constants.DEFAULT_ATTRIBUTES.IslandName)
	end

	local csvPool = node:GetAttribute("EnemyPool")
	if type(csvPool) ~= "string" then
		node:SetAttribute("EnemyPool", Constants.DEFAULT_ATTRIBUTES.EnemyPool)
	end
end

local function applyDependentConstraints(node)
	local radius = sanitizeAttributeValue("Radius", node:GetAttribute("Radius"))
	local activationDistance = sanitizeAttributeValue("ActivationDistance", node:GetAttribute("ActivationDistance"))
	local respawnMin = sanitizeAttributeValue("RespawnMin", node:GetAttribute("RespawnMin"))
	local respawnMax = sanitizeAttributeValue("RespawnMax", node:GetAttribute("RespawnMax"))

	if activationDistance < (radius + 8) then
		activationDistance = radius + 8
	end
	if respawnMax < respawnMin then
		respawnMax = respawnMin
	end

	node:SetAttribute("Radius", radius)
	node:SetAttribute("ActivationDistance", activationDistance)
	node:SetAttribute("RespawnMin", respawnMin)
	node:SetAttribute("RespawnMax", respawnMax)
end

local function getNodeEnemyPool(node)
	local csvText = node:GetAttribute("EnemyPool")
	local parsed = Util.SplitCsv(tostring(csvText or ""))
	if #parsed <= 0 then
		return Util.CloneArray(Constants.DEFAULT_ENEMY_POOL)
	end
	return parsed
end

local function buildNumericState(nodes, attributeName)
	local firstValue = nil
	local mixed = false

	for _, node in ipairs(nodes) do
		local currentValue = sanitizeAttributeValue(attributeName, node:GetAttribute(attributeName))
		if firstValue == nil then
			firstValue = currentValue
		elseif currentValue ~= firstValue then
			mixed = true
			break
		end
	end

	return {
		mixed = mixed,
		value = firstValue,
	}
end

local function buildBooleanState(nodes, attributeName)
	local firstValue = nil
	local mixed = false

	for _, node in ipairs(nodes) do
		local current = node:GetAttribute(attributeName)
		local value = current == true
		if firstValue == nil then
			firstValue = value
		elseif firstValue ~= value then
			mixed = true
			break
		end
	end

	return {
		mixed = mixed,
		value = firstValue == true,
	}
end

local function buildEnemyStates(nodes, enemyTypes)
	local states = {}
	if #nodes <= 0 then
		for _, enemyName in ipairs(enemyTypes) do
			states[enemyName] = "none"
		end
		return states
	end

	for _, enemyName in ipairs(enemyTypes) do
		local count = 0
		for _, node in ipairs(nodes) do
			local pool = getNodeEnemyPool(node)
			if Util.ArrayContains(pool, enemyName) then
				count += 1
			end
		end

		if count == #nodes then
			states[enemyName] = "all"
		elseif count > 0 then
			states[enemyName] = "some"
		else
			states[enemyName] = "none"
		end
	end

	return states
end

function NodeService.GetSelectedNodes()
	local selected = Selection:Get()
	local nodes = collectBasePartsFromSelection(selected, true)
	table.sort(nodes, function(left, right)
		return left:GetFullName() < right:GetFullName()
	end)
	return nodes
end

function NodeService.ApplyAttribute(nodes, attributeName, value, options)
	if #nodes <= 0 then
		return 0
	end

	local sanitized = sanitizeAttributeValue(attributeName, value)
	if sanitized == nil then
		return 0
	end

	local changed = 0
	for _, node in ipairs(nodes) do
		local current = node:GetAttribute(attributeName)
		if current ~= sanitized then
			node:SetAttribute(attributeName, sanitized)
			changed += 1
		end
		applyDependentConstraints(node)
	end

	if changed > 0 then
		setWaypointIfNeeded(options, "Ambient Spawn: " .. tostring(attributeName))
	end

	return changed
end

function NodeService.StepAttribute(nodes, attributeName, deltaValue)
	if #nodes <= 0 then
		return 0
	end

	local config = Constants.NUMERIC_FIELDS[attributeName]
	if not config then
		return 0
	end

	local changed = 0
	for _, node in ipairs(nodes) do
		local current = sanitizeAttributeValue(attributeName, node:GetAttribute(attributeName))
		local nextValue = current + deltaValue

		if attributeName == "RespawnMax" then
			local respawnMin = sanitizeAttributeValue("RespawnMin", node:GetAttribute("RespawnMin"))
			nextValue = math.max(nextValue, respawnMin)
		elseif attributeName == "RespawnMin" then
			local respawnMax = sanitizeAttributeValue("RespawnMax", node:GetAttribute("RespawnMax"))
			if nextValue > respawnMax then
				node:SetAttribute("RespawnMax", nextValue)
			end
		end

		nextValue = sanitizeAttributeValue(attributeName, nextValue)
		if current ~= nextValue then
			node:SetAttribute(attributeName, nextValue)
			changed += 1
		end
		applyDependentConstraints(node)
	end

	if changed > 0 then
		ChangeHistoryService:SetWaypoint("Ambient Spawn: " .. tostring(attributeName))
	end

	return changed
end

function NodeService.ToggleEnemy(nodes, enemyName, shouldEnable)
	if #nodes <= 0 then
		return 0
	end

	local changed = 0
	for _, node in ipairs(nodes) do
		local pool = getNodeEnemyPool(node)
		local hasEnemy = Util.ArrayContains(pool, enemyName)
		if shouldEnable and not hasEnemy then
			table.insert(pool, enemyName)
		elseif (not shouldEnable) and hasEnemy then
			pool = Util.ArrayWithout(pool, enemyName)
		end

		local csvText = Util.JoinCsv(pool)
		local current = node:GetAttribute("EnemyPool")
		if current ~= csvText then
			node:SetAttribute("EnemyPool", csvText)
			changed += 1
		end
	end

	if changed > 0 then
		ChangeHistoryService:SetWaypoint("Ambient Spawn: EnemyPool")
	end

	return changed
end

function NodeService.ApplyPreset(nodes, presetName)
	if #nodes <= 0 then
		return 0
	end

	local preset = Constants.PRESETS[presetName]
	if not preset then
		return 0
	end

	local changed = 0
	for attributeName, presetValue in pairs(preset) do
		changed += NodeService.ApplyAttribute(nodes, attributeName, presetValue, { SkipWaypoint = true })
	end

	if changed > 0 then
		ChangeHistoryService:SetWaypoint("Ambient Spawn: Preset " .. tostring(presetName))
	end

	return changed
end

function NodeService.CreateNode()
	local parentFolder, err = Util.EnsureFolderPath(Constants.NODE_PARENT_PATH)
	if not parentFolder then
		return nil, err or "Unable to resolve node parent path"
	end

	local node = Instance.new("Part")
	node.Name = Constants.NODE_NAME
	node.Shape = Enum.PartType.Block
	node.Size = Vector3.new(4, 1, 4)
	node.Color = Color3.fromRGB(79, 143, 246)
	node.Material = Enum.Material.SmoothPlastic
	node.Anchored = true
	node.CanCollide = false
	node.CanTouch = false
	node.Transparency = 0.15
	node.TopSurface = Enum.SurfaceType.Smooth
	node.BottomSurface = Enum.SurfaceType.Smooth

	local newPosition = Vector3.new(0, 8, 0)
	for _, selected in ipairs(Selection:Get()) do
		if selected:IsA("BasePart") then
			newPosition = selected.Position + Vector3.new(0, 4, 0)
			break
		end
	end
	if newPosition == Vector3.new(0, 8, 0) and workspace.CurrentCamera then
		newPosition = workspace.CurrentCamera.CFrame.Position + (workspace.CurrentCamera.CFrame.LookVector * 24)
	end

	node.Position = newPosition
	node.Parent = parentFolder

	ensureDefaultAttributes(node)
	sanitizeNodeAttributes(node)
	applyDependentConstraints(node)

	if node:GetAttribute("IslandName") == "" then
		local inferredIsland = Util.InferIslandName(node)
		if inferredIsland then
			node:SetAttribute("IslandName", inferredIsland)
		end
	end

	CollectionService:AddTag(node, Constants.NODE_TAG)
	Selection:Set({ node })
	ChangeHistoryService:SetWaypoint("Ambient Spawn: Create Node")

	return node
end

function NodeService.TagSelection()
	local selected = Selection:Get()
	local parts = collectBasePartsFromSelection(selected, false)

	local changed = 0
	for _, part in ipairs(parts) do
		if not CollectionService:HasTag(part, Constants.NODE_TAG) then
			CollectionService:AddTag(part, Constants.NODE_TAG)
			changed += 1
		end
		ensureDefaultAttributes(part)
		sanitizeNodeAttributes(part)
		applyDependentConstraints(part)
	end

	if changed > 0 then
		ChangeHistoryService:SetWaypoint("Ambient Spawn: Tag Selection")
	end

	return changed
end

function NodeService.UntagSelection()
	local selectedNodes = NodeService.GetSelectedNodes()
	local changed = 0

	for _, node in ipairs(selectedNodes) do
		if CollectionService:HasTag(node, Constants.NODE_TAG) then
			CollectionService:RemoveTag(node, Constants.NODE_TAG)
			changed += 1
		end
	end

	if changed > 0 then
		ChangeHistoryService:SetWaypoint("Ambient Spawn: Untag Selection")
	end

	return changed
end

function NodeService.BuildPreviewRecords(nodes)
	local records = {}
	for _, node in ipairs(nodes) do
		local radius = sanitizeAttributeValue("Radius", node:GetAttribute("Radius"))
		local maxAlive = sanitizeAttributeValue("MaxAlive", node:GetAttribute("MaxAlive"))
		local enemyPool = getNodeEnemyPool(node)
		table.insert(records, {
			Node = node,
			Position = node.Position,
			Radius = radius,
			MaxAlive = maxAlive,
			EnemyPool = enemyPool,
		})
	end
	return records
end

function NodeService.BuildSelectionModel(nodes, enemyTypes)
	local hasSelection = #nodes > 0
	local model = {
		count = #nodes,
		hasSelection = hasSelection,
		values = {},
		enemyStates = buildEnemyStates(nodes, enemyTypes or {}),
	}

	if hasSelection then
		model.values.Enabled = buildBooleanState(nodes, "Enabled")
		for _, attributeName in ipairs(Constants.NUMERIC_FIELD_ORDER) do
			model.values[attributeName] = buildNumericState(nodes, attributeName)
		end
	else
		model.values.Enabled = { mixed = false, value = Constants.DEFAULT_ATTRIBUTES.Enabled }
		for _, attributeName in ipairs(Constants.NUMERIC_FIELD_ORDER) do
			model.values[attributeName] = {
				mixed = false,
				value = Constants.DEFAULT_ATTRIBUTES[attributeName],
			}
		end
	end

	return model
end

return NodeService
