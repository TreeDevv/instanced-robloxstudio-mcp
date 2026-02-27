local Constants = {}

Constants.TOOLBAR_NAME = "Ambient Tools"
Constants.TOOLBAR_BUTTON_NAME = "Ambient Spawns"
Constants.TOOLBAR_BUTTON_TOOLTIP = "Create and tune ambient enemy spawn nodes"
Constants.TOOLBAR_BUTTON_ICON = "rbxassetid://10734944444"

Constants.WIDGET_ID = "AmbientSpawnAuthoringWidget"
Constants.WIDGET_TITLE = "Ambient Spawn Authoring"

Constants.NODE_TAG = "EnemySpawnNode"
Constants.NODE_NAME = "EnemySpawnNode"
Constants.NODE_PARENT_PATH = "Workspace.Map.Islands.EnemyNodes"
Constants.PREVIEW_FOLDER_NAME = "__AmbientSpawnPreview"

Constants.DEFAULT_ENEMY_POOL = { "Guard", "Thieve" }

Constants.DEFAULT_ATTRIBUTES = {
	Enabled = true,
	Radius = 45,
	EnemyWeight = 1,
	MaxAlive = 4,
	RespawnMin = 6,
	RespawnMax = 12,
	ActivationDistance = 220,
	MinSpawnDistanceFromPlayer = 25,
	IslandName = "",
	EnemyPool = "Guard,Thieve",
}

Constants.NUMERIC_FIELD_ORDER = {
	"Radius",
	"EnemyWeight",
	"MaxAlive",
	"RespawnMin",
	"RespawnMax",
	"ActivationDistance",
	"MinSpawnDistanceFromPlayer",
}

Constants.NUMERIC_FIELDS = {
	Radius = { Min = 8, Max = 1024, Step = 1, Precision = 0 },
	EnemyWeight = { Min = 0.25, Max = 3, Step = 0.05, Precision = 2 },
	MaxAlive = { Min = 1, Max = 40, Step = 1, Precision = 0 },
	RespawnMin = { Min = 0.5, Max = 120, Step = 0.5, Precision = 2 },
	RespawnMax = { Min = 0.5, Max = 180, Step = 0.5, Precision = 2 },
	ActivationDistance = { Min = 16, Max = 2048, Step = 4, Precision = 0 },
	MinSpawnDistanceFromPlayer = { Min = 0, Max = 300, Step = 1, Precision = 0 },
}

Constants.PRESETS = {
	Scout = {
		Radius = 35,
		EnemyWeight = 0.8,
		MaxAlive = 2,
		RespawnMin = 7,
		RespawnMax = 12,
		ActivationDistance = 180,
		MinSpawnDistanceFromPlayer = 24,
	},
	Standard = {
		Radius = 45,
		EnemyWeight = 1,
		MaxAlive = 4,
		RespawnMin = 6,
		RespawnMax = 12,
		ActivationDistance = 220,
		MinSpawnDistanceFromPlayer = 25,
	},
	Heavy = {
		Radius = 60,
		EnemyWeight = 1.8,
		MaxAlive = 6,
		RespawnMin = 3,
		RespawnMax = 7,
		ActivationDistance = 280,
		MinSpawnDistanceFromPlayer = 28,
	},
}

Constants.COLOR_SUCCESS = Color3.fromRGB(70, 205, 125)
Constants.COLOR_WARNING = Color3.fromRGB(246, 186, 65)
Constants.COLOR_ERROR = Color3.fromRGB(235, 104, 104)

return Constants
