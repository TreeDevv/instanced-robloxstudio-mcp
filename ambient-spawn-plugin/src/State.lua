local State = {
	SelectedNodes = {},
	EnemyTypes = {},
	ShowRadiusPreview = true,
	ShowMarkerPreview = true,
}

function State.SetSelectedNodes(nodes)
	State.SelectedNodes = nodes or {}
end

function State.GetSelectedNodes()
	return State.SelectedNodes
end

function State.SetEnemyTypes(enemyTypes)
	State.EnemyTypes = enemyTypes or {}
end

function State.GetEnemyTypes()
	return State.EnemyTypes
end

function State.SetShowRadiusPreview(enabledValue)
	State.ShowRadiusPreview = enabledValue == true
end

function State.GetShowRadiusPreview()
	return State.ShowRadiusPreview
end

function State.SetShowMarkerPreview(enabledValue)
	State.ShowMarkerPreview = enabledValue == true
end

function State.GetShowMarkerPreview()
	return State.ShowMarkerPreview
end

return State
