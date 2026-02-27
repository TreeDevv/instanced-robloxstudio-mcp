local Selection = game:GetService("Selection")
local ChangeHistoryService = game:GetService("ChangeHistoryService")

local Source = script:WaitForChild("src")

local Constants = require(Source:WaitForChild("Constants"))
local State = require(Source:WaitForChild("State"))
local EnemySource = require(Source:WaitForChild("EnemySource"))
local NodeService = require(Source:WaitForChild("NodeService"))
local PreviewService = require(Source:WaitForChild("PreviewService"))
local UI = require(Source:WaitForChild("UI"))

local toolbar = plugin:CreateToolbar(Constants.TOOLBAR_NAME)
local toolbarButton = toolbar:CreateButton(
	Constants.TOOLBAR_BUTTON_NAME,
	Constants.TOOLBAR_BUTTON_TOOLTIP,
	Constants.TOOLBAR_BUTTON_ICON
)

local enemyTypes = EnemySource.GetEnemyTypes(false)
if #enemyTypes <= 0 then
	enemyTypes = EnemySource.GetFallbackEnemyTypes()
end
State.SetEnemyTypes(enemyTypes)

local ui = nil
local selectionChangedConnection = nil
local onUndoConnection = nil
local onRedoConnection = nil

local function getSelectedNodes()
	return NodeService.GetSelectedNodes()
end

local function updatePreview()
	local records = NodeService.BuildPreviewRecords(State.GetSelectedNodes())
	PreviewService.SetOptions(State.GetShowRadiusPreview(), State.GetShowMarkerPreview())
	PreviewService.Render(records)
end

local function refreshSelectionModel()
	local nodes = getSelectedNodes()
	State.SetSelectedNodes(nodes)
	local model = NodeService.BuildSelectionModel(nodes, State.GetEnemyTypes())
	if ui then
		ui:UpdateFromSelection(model)
	end
	updatePreview()
end

local function showActionResult(prefix, changedCount)
	if not ui then
		return
	end
	local suffix = if changedCount == 1 then "node" else "nodes"
	ui:ShowToast(string.format("%s %d %s", prefix, changedCount, suffix))
end

ui = UI.new(plugin, State.GetEnemyTypes(), {
	CreateNode = function()
		local createdPart, err = NodeService.CreateNode()
		if createdPart then
			ui:ShowToast("Created ambient spawn node")
			refreshSelectionModel()
		else
			ui:ShowToast("Create failed: " .. tostring(err), Constants.COLOR_ERROR)
		end
	end,
	TagSelection = function()
		local changedCount = NodeService.TagSelection()
		showActionResult("Tagged", changedCount)
		refreshSelectionModel()
	end,
	UntagSelection = function()
		local changedCount = NodeService.UntagSelection()
		showActionResult("Untagged", changedCount)
		refreshSelectionModel()
	end,
	SetEnabled = function(enabledValue)
		local changedCount = NodeService.ApplyAttribute(State.GetSelectedNodes(), "Enabled", enabledValue, {
			SkipWaypoint = false,
			WaypointName = "Ambient Spawn: Enabled",
		})
		if changedCount > 0 then
			refreshSelectionModel()
		end
	end,
	SetNumber = function(attributeName, numberValue, isLive)
		local changedCount = NodeService.ApplyAttribute(State.GetSelectedNodes(), attributeName, numberValue, {
			SkipWaypoint = isLive == true,
			WaypointName = "Ambient Spawn: " .. tostring(attributeName),
		})
		if changedCount > 0 then
			refreshSelectionModel()
		end
	end,
	StepNumber = function(attributeName, deltaValue)
		local changedCount = NodeService.StepAttribute(State.GetSelectedNodes(), attributeName, deltaValue)
		if changedCount > 0 then
			refreshSelectionModel()
		end
	end,
	ToggleEnemy = function(enemyName, shouldEnable)
		local changedCount = NodeService.ToggleEnemy(State.GetSelectedNodes(), enemyName, shouldEnable)
		if changedCount > 0 then
			refreshSelectionModel()
		end
	end,
	ApplyPreset = function(presetName)
		local changedCount = NodeService.ApplyPreset(State.GetSelectedNodes(), presetName)
		if changedCount > 0 then
			ui:ShowToast("Applied preset: " .. tostring(presetName))
			refreshSelectionModel()
		end
	end,
	SetRadiusPreview = function(enabledValue)
		State.SetShowRadiusPreview(enabledValue)
		updatePreview()
	end,
	SetMarkerPreview = function(enabledValue)
		State.SetShowMarkerPreview(enabledValue)
		updatePreview()
	end,
	ReloadEnemyTypes = function()
		local loaded = EnemySource.GetEnemyTypes(true)
		if #loaded <= 0 then
			loaded = EnemySource.GetFallbackEnemyTypes()
		end
		State.SetEnemyTypes(loaded)
		ui:SetEnemyTypes(loaded)
		ui:ShowToast("Reloaded enemy types")
		refreshSelectionModel()
	end,
	RequestRefresh = function()
		refreshSelectionModel()
	end,
})

ui:SetPreviewState(State.GetShowRadiusPreview(), State.GetShowMarkerPreview())
refreshSelectionModel()

selectionChangedConnection = Selection.SelectionChanged:Connect(function()
	refreshSelectionModel()
end)

do
	local okUndo, undoOrErr = pcall(function()
		return ChangeHistoryService.OnUndo:Connect(function()
			refreshSelectionModel()
		end)
	end)
	if okUndo then
		onUndoConnection = undoOrErr
	end
end

do
	local okRedo, redoOrErr = pcall(function()
		return ChangeHistoryService.OnRedo:Connect(function()
			refreshSelectionModel()
		end)
	end)
	if okRedo then
		onRedoConnection = redoOrErr
	end
end

toolbarButton.Click:Connect(function()
	if ui then
		ui:SetWidgetEnabled(not ui:GetWidgetEnabled())
	end
end)

plugin.Unloading:Connect(function()
	if selectionChangedConnection then
		selectionChangedConnection:Disconnect()
		selectionChangedConnection = nil
	end
	if onUndoConnection then
		onUndoConnection:Disconnect()
		onUndoConnection = nil
	end
	if onRedoConnection then
		onRedoConnection:Disconnect()
		onRedoConnection = nil
	end

	PreviewService.Destroy()

	if ui then
		ui:Destroy()
		ui = nil
	end
end)
