local Constants = require(script.Parent.Constants)
local Theme = require(script.Parent.Theme)
local Util = require(script.Parent.Util)

local UI = {}

local function applyCorner(instance, cornerRadius)
	local corner = Instance.new("UICorner")
	corner.CornerRadius = cornerRadius or Theme.Corner
	corner.Parent = instance
	return corner
end

local function applyStroke(instance, color, transparency)
	local stroke = Instance.new("UIStroke")
	stroke.Color = color or Theme.Border
	stroke.Transparency = transparency or 0
	stroke.Thickness = 1
	stroke.Parent = instance
	return stroke
end

local function createTextButton(parent, text, width)
	local button = Instance.new("TextButton")
	button.Size = UDim2.new(0, width or 100, 0, 26)
	button.BackgroundColor3 = Theme.Surface2
	button.TextColor3 = Theme.Text
	button.TextSize = 11
	button.Font = Theme.FontSemibold
	button.AutoButtonColor = true
	button.Text = text
	button.Parent = parent
	applyCorner(button)
	applyStroke(button)
	return button
end

local function createLabel(parent, text, size)
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.TextYAlignment = Enum.TextYAlignment.Center
	label.TextColor3 = Theme.Text
	label.TextSize = 12
	label.Font = Theme.Font
	label.Text = text
	label.Size = size or UDim2.new(1, 0, 0, 18)
	label.Parent = parent
	return label
end

function UI.new(plugin, enemyTypes, callbacks)
	local self = {
		Widget = nil,
		Root = nil,
		StatusLabel = nil,
		SelectionLabel = nil,
		EnabledButton = nil,
		RadiusPreviewButton = nil,
		MarkerPreviewButton = nil,
		EnemySearchBox = nil,
		EnemyListFrame = nil,
		EnemyRows = {},
		NumberRows = {},
		Connections = {},
		HasSelection = false,
		SuppressNumericSignal = false,
		LatestModel = nil,
		ToastToken = 0,
	}

	local widgetInfo = DockWidgetPluginGuiInfo.new(
		Enum.InitialDockState.Right,
		false,
		true,
		410,
		680,
		320,
		460
	)

	local widget = plugin:CreateDockWidgetPluginGui(Constants.WIDGET_ID, widgetInfo)
	widget.Title = Constants.WIDGET_TITLE
	widget.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	widget.Enabled = false
	self.Widget = widget

	local root = Instance.new("Frame")
	root.Name = "Root"
	root.Size = UDim2.fromScale(1, 1)
	root.BackgroundColor3 = Theme.Background
	root.BorderSizePixel = 0
	root.Parent = widget
	self.Root = root

	local rootPadding = Instance.new("UIPadding")
	rootPadding.PaddingTop = UDim.new(0, 10)
	rootPadding.PaddingBottom = UDim.new(0, 10)
	rootPadding.PaddingLeft = UDim.new(0, 10)
	rootPadding.PaddingRight = UDim.new(0, 10)
	rootPadding.Parent = root

	local content = Instance.new("ScrollingFrame")
	content.Name = "Content"
	content.Size = UDim2.fromScale(1, 1)
	content.BackgroundTransparency = 1
	content.BorderSizePixel = 0
	content.ScrollBarThickness = 4
	content.CanvasSize = UDim2.new(0, 0, 0, 0)
	content.AutomaticCanvasSize = Enum.AutomaticSize.Y
	content.Parent = root

	local contentLayout = Instance.new("UIListLayout")
	contentLayout.Padding = UDim.new(0, 8)
	contentLayout.FillDirection = Enum.FillDirection.Vertical
	contentLayout.SortOrder = Enum.SortOrder.LayoutOrder
	contentLayout.Parent = content

	local status = createLabel(content, "Ready", UDim2.new(1, 0, 0, 20))
	status.TextColor3 = Theme.TextMuted
	status.TextSize = 11
	status.LayoutOrder = 1
	self.StatusLabel = status

	local actionRow = Instance.new("Frame")
	actionRow.Name = "ActionRow"
	actionRow.Size = UDim2.new(1, 0, 0, 28)
	actionRow.BackgroundTransparency = 1
	actionRow.LayoutOrder = 2
	actionRow.Parent = content

	local actionLayout = Instance.new("UIListLayout")
	actionLayout.FillDirection = Enum.FillDirection.Horizontal
	actionLayout.Padding = UDim.new(0, 6)
	actionLayout.VerticalAlignment = Enum.VerticalAlignment.Center
	actionLayout.Parent = actionRow

	local createButton = createTextButton(actionRow, "Create Node", 112)
	local tagButton = createTextButton(actionRow, "Tag Selected", 100)
	local untagButton = createTextButton(actionRow, "Untag Selected", 110)

	table.insert(self.Connections, createButton.Activated:Connect(function()
		if callbacks.CreateNode then
			callbacks.CreateNode()
		end
	end))
	table.insert(self.Connections, tagButton.Activated:Connect(function()
		if callbacks.TagSelection then
			callbacks.TagSelection()
		end
	end))
	table.insert(self.Connections, untagButton.Activated:Connect(function()
		if callbacks.UntagSelection then
			callbacks.UntagSelection()
		end
	end))

	local selectionLabel = createLabel(content, "No ambient spawn nodes selected", UDim2.new(1, 0, 0, 20))
	selectionLabel.TextColor3 = Theme.TextDim
	selectionLabel.TextSize = 11
	selectionLabel.LayoutOrder = 3
	self.SelectionLabel = selectionLabel

	local previewRow = Instance.new("Frame")
	previewRow.Name = "PreviewRow"
	previewRow.Size = UDim2.new(1, 0, 0, 28)
	previewRow.BackgroundTransparency = 1
	previewRow.LayoutOrder = 4
	previewRow.Parent = content

	local previewLayout = Instance.new("UIListLayout")
	previewLayout.FillDirection = Enum.FillDirection.Horizontal
	previewLayout.Padding = UDim.new(0, 6)
	previewLayout.Parent = previewRow

	local radiusToggle = createTextButton(previewRow, "Radius: On", 96)
	local markerToggle = createTextButton(previewRow, "Max Preview: On", 118)
	local reloadEnemiesButton = createTextButton(previewRow, "Reload Enemy Types", 150)

	self.RadiusPreviewButton = radiusToggle
	self.MarkerPreviewButton = markerToggle

	local function setPreviewButtonState(button, enabledValue, prefix)
		if enabledValue then
			button.Text = prefix .. ": On"
			button.BackgroundColor3 = Theme.Blue
			button.TextColor3 = Color3.fromRGB(18, 20, 24)
		else
			button.Text = prefix .. ": Off"
			button.BackgroundColor3 = Theme.Surface2
			button.TextColor3 = Theme.Text
		end
	end

	table.insert(self.Connections, radiusToggle.Activated:Connect(function()
		local turningOn = radiusToggle.Text:find(": Off", 1, true) ~= nil
		setPreviewButtonState(radiusToggle, turningOn, "Radius")
		if callbacks.SetRadiusPreview then
			callbacks.SetRadiusPreview(turningOn)
		end
	end))

	table.insert(self.Connections, markerToggle.Activated:Connect(function()
		local turningOn = markerToggle.Text:find(": Off", 1, true) ~= nil
		setPreviewButtonState(markerToggle, turningOn, "Max Preview")
		if callbacks.SetMarkerPreview then
			callbacks.SetMarkerPreview(turningOn)
		end
	end))

	table.insert(self.Connections, reloadEnemiesButton.Activated:Connect(function()
		if callbacks.ReloadEnemyTypes then
			callbacks.ReloadEnemyTypes()
		end
	end))

	local enabledRow = Instance.new("Frame")
	enabledRow.Name = "EnabledRow"
	enabledRow.Size = UDim2.new(1, 0, 0, 28)
	enabledRow.BackgroundTransparency = 1
	enabledRow.LayoutOrder = 5
	enabledRow.Parent = content

	local enabledLabel = createLabel(enabledRow, "Enabled", UDim2.new(0, 130, 1, 0))
	enabledLabel.Position = UDim2.new(0, 0, 0, 0)
	enabledLabel.TextSize = 11

	local enabledButton = createTextButton(enabledRow, "Enabled: On", 140)
	enabledButton.Position = UDim2.new(1, -140, 0, 0)
	enabledButton.AnchorPoint = Vector2.new(0, 0)
	self.EnabledButton = enabledButton

	local function setEnabledVisual(valueState)
		if valueState.mixed then
			enabledButton.Text = "Enabled: Mixed"
			enabledButton.BackgroundColor3 = Theme.Yellow
			enabledButton.TextColor3 = Color3.fromRGB(25, 22, 18)
			return
		end
		if valueState.value then
			enabledButton.Text = "Enabled: On"
			enabledButton.BackgroundColor3 = Theme.Green
			enabledButton.TextColor3 = Color3.fromRGB(18, 24, 19)
		else
			enabledButton.Text = "Enabled: Off"
			enabledButton.BackgroundColor3 = Theme.Red
			enabledButton.TextColor3 = Color3.fromRGB(34, 20, 20)
		end
	end

	table.insert(self.Connections, enabledButton.Activated:Connect(function()
		if not self.HasSelection then
			return
		end
		if callbacks.SetEnabled then
			local model = self.LatestModel
			local currentState = model and model.values and model.values.Enabled or { mixed = false, value = true }
			local nextValue = true
			if currentState.mixed then
				nextValue = true
			else
				nextValue = not currentState.value
			end
			callbacks.SetEnabled(nextValue)
		end
	end))

	local numbersCard = Instance.new("Frame")
	numbersCard.Name = "NumbersCard"
	numbersCard.Size = UDim2.new(1, 0, 0, 0)
	numbersCard.AutomaticSize = Enum.AutomaticSize.Y
	numbersCard.BackgroundColor3 = Theme.Surface
	numbersCard.BorderSizePixel = 0
	numbersCard.LayoutOrder = 6
	numbersCard.Parent = content
	applyCorner(numbersCard)
	applyStroke(numbersCard)

	local numbersPadding = Instance.new("UIPadding")
	numbersPadding.PaddingTop = UDim.new(0, 8)
	numbersPadding.PaddingBottom = UDim.new(0, 8)
	numbersPadding.PaddingLeft = UDim.new(0, 8)
	numbersPadding.PaddingRight = UDim.new(0, 8)
	numbersPadding.Parent = numbersCard

	local numbersLayout = Instance.new("UIListLayout")
	numbersLayout.FillDirection = Enum.FillDirection.Vertical
	numbersLayout.Padding = UDim.new(0, 6)
	numbersLayout.Parent = numbersCard

	local numbersTitle = createLabel(numbersCard, "Spawn Tuning", UDim2.new(1, 0, 0, 18))
	numbersTitle.Font = Theme.FontBold
	numbersTitle.TextSize = 12

	local function createNumberRow(attributeName)
		local config = Constants.NUMERIC_FIELDS[attributeName]

		local row = Instance.new("Frame")
		row.Name = attributeName .. "Row"
		row.Size = UDim2.new(1, 0, 0, 26)
		row.BackgroundTransparency = 1
		row.Parent = numbersCard

		local label = createLabel(row, attributeName, UDim2.new(0, 170, 1, 0))
		label.TextSize = 11

		local minusButton = createTextButton(row, "-", 24)
		minusButton.Position = UDim2.new(0, 178, 0, 0)
		minusButton.TextSize = 15

		local valueBox = Instance.new("TextBox")
		valueBox.Name = attributeName .. "Box"
		valueBox.Size = UDim2.new(0, 90, 1, 0)
		valueBox.Position = UDim2.new(0, 208, 0, 0)
		valueBox.BackgroundColor3 = Theme.Background
		valueBox.BorderSizePixel = 0
		valueBox.TextColor3 = Theme.Text
		valueBox.TextSize = 11
		valueBox.Font = Theme.FontSemibold
		valueBox.PlaceholderText = "Value"
		valueBox.PlaceholderColor3 = Theme.TextDim
		valueBox.Text = Util.FormatNumber(Constants.DEFAULT_ATTRIBUTES[attributeName], config.Precision)
		valueBox.ClearTextOnFocus = false
		valueBox.Parent = row
		applyCorner(valueBox)
		applyStroke(valueBox)

		local plusButton = createTextButton(row, "+", 24)
		plusButton.Position = UDim2.new(0, 304, 0, 0)
		plusButton.TextSize = 14

		table.insert(self.Connections, minusButton.Activated:Connect(function()
			if not self.HasSelection then
				return
			end
			if callbacks.StepNumber then
				callbacks.StepNumber(attributeName, -config.Step)
			end
		end))

		table.insert(self.Connections, plusButton.Activated:Connect(function()
			if not self.HasSelection then
				return
			end
			if callbacks.StepNumber then
				callbacks.StepNumber(attributeName, config.Step)
			end
		end))

		table.insert(self.Connections, valueBox:GetPropertyChangedSignal("Text"):Connect(function()
			if self.SuppressNumericSignal or not self.HasSelection then
				return
			end
			local parsed = tonumber(valueBox.Text)
			if parsed and callbacks.SetNumber then
				callbacks.SetNumber(attributeName, parsed, true)
			end
		end))

		table.insert(self.Connections, valueBox.FocusLost:Connect(function()
			if self.SuppressNumericSignal or not self.HasSelection then
				return
			end
			local parsed = tonumber(valueBox.Text)
			if parsed and callbacks.SetNumber then
				callbacks.SetNumber(attributeName, parsed, false)
			elseif callbacks.RequestRefresh then
				callbacks.RequestRefresh()
			end
		end))

		self.NumberRows[attributeName] = {
			Row = row,
			Label = label,
			MinusButton = minusButton,
			ValueBox = valueBox,
			PlusButton = plusButton,
		}
	end

	for _, attributeName in ipairs(Constants.NUMERIC_FIELD_ORDER) do
		createNumberRow(attributeName)
	end

	local presetRow = Instance.new("Frame")
	presetRow.Name = "PresetRow"
	presetRow.Size = UDim2.new(1, 0, 0, 28)
	presetRow.BackgroundTransparency = 1
	presetRow.LayoutOrder = 7
	presetRow.Parent = content

	local presetLayout = Instance.new("UIListLayout")
	presetLayout.FillDirection = Enum.FillDirection.Horizontal
	presetLayout.Padding = UDim.new(0, 6)
	presetLayout.Parent = presetRow

	createLabel(presetRow, "Presets:", UDim2.new(0, 62, 1, 0)).TextSize = 11
	local scoutPreset = createTextButton(presetRow, "Scout", 72)
	local standardPreset = createTextButton(presetRow, "Standard", 80)
	local heavyPreset = createTextButton(presetRow, "Heavy", 72)

	table.insert(self.Connections, scoutPreset.Activated:Connect(function()
		if self.HasSelection and callbacks.ApplyPreset then
			callbacks.ApplyPreset("Scout")
		end
	end))
	table.insert(self.Connections, standardPreset.Activated:Connect(function()
		if self.HasSelection and callbacks.ApplyPreset then
			callbacks.ApplyPreset("Standard")
		end
	end))
	table.insert(self.Connections, heavyPreset.Activated:Connect(function()
		if self.HasSelection and callbacks.ApplyPreset then
			callbacks.ApplyPreset("Heavy")
		end
	end))

	local enemyCard = Instance.new("Frame")
	enemyCard.Name = "EnemyCard"
	enemyCard.Size = UDim2.new(1, 0, 0, 0)
	enemyCard.AutomaticSize = Enum.AutomaticSize.Y
	enemyCard.BackgroundColor3 = Theme.Surface
	enemyCard.BorderSizePixel = 0
	enemyCard.LayoutOrder = 8
	enemyCard.Parent = content
	applyCorner(enemyCard)
	applyStroke(enemyCard)

	local enemyPadding = Instance.new("UIPadding")
	enemyPadding.PaddingTop = UDim.new(0, 8)
	enemyPadding.PaddingBottom = UDim.new(0, 8)
	enemyPadding.PaddingLeft = UDim.new(0, 8)
	enemyPadding.PaddingRight = UDim.new(0, 8)
	enemyPadding.Parent = enemyCard

	local enemyLayout = Instance.new("UIListLayout")
	enemyLayout.FillDirection = Enum.FillDirection.Vertical
	enemyLayout.Padding = UDim.new(0, 6)
	enemyLayout.Parent = enemyCard

	local enemyTitle = createLabel(enemyCard, "Enemy Types", UDim2.new(1, 0, 0, 18))
	enemyTitle.Font = Theme.FontBold
	enemyTitle.TextSize = 12

	local searchBox = Instance.new("TextBox")
	searchBox.Name = "EnemySearch"
	searchBox.Size = UDim2.new(1, 0, 0, 24)
	searchBox.BackgroundColor3 = Theme.Background
	searchBox.BorderSizePixel = 0
	searchBox.ClearTextOnFocus = false
	searchBox.PlaceholderText = "Search enemy types..."
	searchBox.PlaceholderColor3 = Theme.TextDim
	searchBox.TextColor3 = Theme.Text
	searchBox.TextSize = 11
	searchBox.Font = Theme.Font
	searchBox.Text = ""
	searchBox.Parent = enemyCard
	applyCorner(searchBox)
	applyStroke(searchBox)
	self.EnemySearchBox = searchBox

	local enemyListFrame = Instance.new("ScrollingFrame")
	enemyListFrame.Name = "EnemyList"
	enemyListFrame.Size = UDim2.new(1, 0, 0, 190)
	enemyListFrame.BackgroundColor3 = Theme.Background
	enemyListFrame.BorderSizePixel = 0
	enemyListFrame.ScrollBarThickness = 3
	enemyListFrame.CanvasSize = UDim2.new(0, 0, 0, 0)
	enemyListFrame.Parent = enemyCard
	applyCorner(enemyListFrame)
	applyStroke(enemyListFrame, Theme.Border, 0.4)
	self.EnemyListFrame = enemyListFrame

	local enemyListPadding = Instance.new("UIPadding")
	enemyListPadding.PaddingTop = UDim.new(0, 6)
	enemyListPadding.PaddingBottom = UDim.new(0, 6)
	enemyListPadding.PaddingLeft = UDim.new(0, 6)
	enemyListPadding.PaddingRight = UDim.new(0, 6)
	enemyListPadding.Parent = enemyListFrame

	local enemyListLayout = Instance.new("UIListLayout")
	enemyListLayout.FillDirection = Enum.FillDirection.Vertical
	enemyListLayout.Padding = UDim.new(0, 4)
	enemyListLayout.SortOrder = Enum.SortOrder.LayoutOrder
	enemyListLayout.Parent = enemyListFrame

	table.insert(self.Connections, enemyListLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
		enemyListFrame.CanvasSize = UDim2.new(0, 0, 0, enemyListLayout.AbsoluteContentSize.Y + 12)
	end))

	function self:_applyEnemySearch()
		local query = string.lower(self.EnemySearchBox.Text or "")
		for enemyName, row in pairs(self.EnemyRows) do
			local visible = true
			if query ~= "" then
				visible = string.find(string.lower(enemyName), query, 1, true) ~= nil
			end
			row.Frame.Visible = visible
		end
	end

	table.insert(self.Connections, searchBox:GetPropertyChangedSignal("Text"):Connect(function()
		self:_applyEnemySearch()
	end))

	function self:_setEnemyRowState(enemyName, stateValue)
		local row = self.EnemyRows[enemyName]
		if not row then
			return
		end
		row.State = stateValue

		if stateValue == "all" then
			row.StateDot.BackgroundColor3 = Theme.Green
			row.StateText.Text = "✓"
			row.StateText.TextColor3 = Color3.fromRGB(16, 33, 21)
			row.StateText.BackgroundColor3 = Theme.Green
		elseif stateValue == "some" then
			row.StateDot.BackgroundColor3 = Theme.Yellow
			row.StateText.Text = "~"
			row.StateText.TextColor3 = Color3.fromRGB(39, 30, 15)
			row.StateText.BackgroundColor3 = Theme.Yellow
		else
			row.StateDot.BackgroundColor3 = Theme.Gray
			row.StateText.Text = ""
			row.StateText.BackgroundColor3 = Theme.Surface2
		end
	end

	function self:_createEnemyRow(enemyName, order)
		local rowFrame = Instance.new("Frame")
		rowFrame.Name = enemyName .. "Row"
		rowFrame.Size = UDim2.new(1, 0, 0, 24)
		rowFrame.BackgroundTransparency = 1
		rowFrame.LayoutOrder = order
		rowFrame.Parent = enemyListFrame

		local clickButton = Instance.new("TextButton")
		clickButton.Name = "ClickButton"
		clickButton.Size = UDim2.fromScale(1, 1)
		clickButton.BackgroundColor3 = Theme.Surface2
		clickButton.BorderSizePixel = 0
		clickButton.TextColor3 = Theme.Text
		clickButton.TextXAlignment = Enum.TextXAlignment.Left
		clickButton.TextSize = 11
		clickButton.Font = Theme.FontSemibold
		clickButton.Text = "      " .. enemyName
		clickButton.Parent = rowFrame
		applyCorner(clickButton)
		applyStroke(clickButton, Theme.Border, 0.2)

		local stateDot = Instance.new("Frame")
		stateDot.Size = UDim2.new(0, 10, 0, 10)
		stateDot.Position = UDim2.new(0, 8, 0.5, -5)
		stateDot.BackgroundColor3 = Theme.Gray
		stateDot.BorderSizePixel = 0
		stateDot.Parent = clickButton
		applyCorner(stateDot, UDim.new(1, 0))

		local stateText = Instance.new("TextLabel")
		stateText.Size = UDim2.new(0, 24, 0, 16)
		stateText.Position = UDim2.new(1, -28, 0.5, -8)
		stateText.BackgroundColor3 = Theme.Surface2
		stateText.BackgroundTransparency = 0.15
		stateText.Text = ""
		stateText.TextColor3 = Theme.Text
		stateText.TextSize = 11
		stateText.Font = Theme.FontBold
		stateText.Parent = clickButton
		applyCorner(stateText, UDim.new(0, 4))

		self.EnemyRows[enemyName] = {
			Frame = rowFrame,
			Button = clickButton,
			StateDot = stateDot,
			StateText = stateText,
			State = "none",
		}

		table.insert(self.Connections, clickButton.Activated:Connect(function()
			if not self.HasSelection or not callbacks.ToggleEnemy then
				return
			end
			local currentState = self.EnemyRows[enemyName].State
			local shouldEnable = currentState ~= "all"
			callbacks.ToggleEnemy(enemyName, shouldEnable)
		end))
	end

	function self:SetEnemyTypes(enemyTypeList)
		for _, row in pairs(self.EnemyRows) do
			if row.Frame then
				row.Frame:Destroy()
			end
		end
		self.EnemyRows = {}

		local sorted = Util.CloneArray(enemyTypeList)
		table.sort(sorted)
		for index, enemyName in ipairs(sorted) do
			self:_createEnemyRow(enemyName, index)
		end
		self:_applyEnemySearch()
	end

	function self:SetPreviewState(showRadius, showMarkers)
		setPreviewButtonState(self.RadiusPreviewButton, showRadius == true, "Radius")
		setPreviewButtonState(self.MarkerPreviewButton, showMarkers == true, "Max Preview")
	end

	function self:ShowToast(message, color)
		self.ToastToken += 1
		local token = self.ToastToken
		self.StatusLabel.Text = tostring(message)
		self.StatusLabel.TextColor3 = color or Theme.TextMuted
		task.delay(2.3, function()
			if self.ToastToken ~= token then
				return
			end
			self.StatusLabel.Text = "Ready"
			self.StatusLabel.TextColor3 = Theme.TextMuted
		end)
	end

	function self:UpdateFromSelection(model)
		self.LatestModel = model
		self.HasSelection = model and model.hasSelection == true
		local count = if model then model.count else 0
		if self.HasSelection then
			local labelSuffix = if count == 1 then "node" else "nodes"
			self.SelectionLabel.Text = string.format("Selected %d %s", count, labelSuffix)
			self.SelectionLabel.TextColor3 = Theme.Text
		else
			self.SelectionLabel.Text = "No ambient spawn nodes selected"
			self.SelectionLabel.TextColor3 = Theme.TextDim
		end

		local enabledState = if model and model.values then model.values.Enabled else { mixed = false, value = Constants.DEFAULT_ATTRIBUTES.Enabled }
		setEnabledVisual(enabledState)

		self.SuppressNumericSignal = true
		for _, attributeName in ipairs(Constants.NUMERIC_FIELD_ORDER) do
			local row = self.NumberRows[attributeName]
			local valueState = if model and model.values then model.values[attributeName] else nil
			local config = Constants.NUMERIC_FIELDS[attributeName]

			if valueState and valueState.mixed then
				row.ValueBox.Text = "Mixed"
				row.ValueBox.TextColor3 = Theme.Yellow
			elseif valueState then
				row.ValueBox.Text = Util.FormatNumber(valueState.value, config.Precision)
				row.ValueBox.TextColor3 = Theme.Text
			else
				row.ValueBox.Text = Util.FormatNumber(Constants.DEFAULT_ATTRIBUTES[attributeName], config.Precision)
				row.ValueBox.TextColor3 = Theme.TextDim
			end
		end
		self.SuppressNumericSignal = false

		local enemyStates = if model then model.enemyStates else {}
		for enemyName, row in pairs(self.EnemyRows) do
			local stateValue = enemyStates[enemyName] or "none"
			self:_setEnemyRowState(enemyName, stateValue)
			row.Button.TextColor3 = if self.HasSelection then Theme.Text else Theme.TextDim
		end
	end

	function self:SetWidgetEnabled(enabledValue)
		self.Widget.Enabled = enabledValue == true
	end

	function self:GetWidgetEnabled()
		return self.Widget.Enabled
	end

	function self:Destroy()
		for _, connection in ipairs(self.Connections) do
			if connection and connection.Connected then
				connection:Disconnect()
			end
		end
		self.Connections = {}
		if self.Widget then
			self.Widget:Destroy()
			self.Widget = nil
		end
	end

	self:SetEnemyTypes(enemyTypes or {})
	self:SetPreviewState(true, true)
	self:UpdateFromSelection({
		count = 0,
		hasSelection = false,
		values = {},
		enemyStates = {},
	})

	return self
end

return UI
