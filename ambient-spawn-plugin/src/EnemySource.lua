local ServerScriptService = game:GetService("ServerScriptService")

local Constants = require(script.Parent.Constants)
local Util = require(script.Parent.Util)

local EnemySource = {}

local cachedEnemyTypes = nil
local cachedFallbackPool = nil

local function parseEnemyNamesFromSource(sourceText)
	if type(sourceText) ~= "string" or sourceText == "" then
		return {}
	end

	local startPos, openBracePos = string.find(sourceText, "local%s+ENEMIES%s*=%s*{")
	if not startPos or not openBracePos then
		return {}
	end

	local depth = 0
	local closePos = nil
	for index = openBracePos, #sourceText do
		local currentChar = string.sub(sourceText, index, index)
		if currentChar == "{" then
			depth += 1
		elseif currentChar == "}" then
			depth -= 1
			if depth == 0 then
				closePos = index
				break
			end
		end
	end

	if not closePos then
		return {}
	end

	local blockText = string.sub(sourceText, openBracePos + 1, closePos - 1)
	local names = {}
	for line in string.gmatch(blockText, "[^\r\n]+") do
		local entryName = string.match(line, "^%s*([%a_][%w_]*)%s*=%s*{%s*$")
		if entryName then
			table.insert(names, entryName)
		end
	end

	return names
end

local function getCatalogModule()
	local modulesFolder = ServerScriptService:FindFirstChild("Modules")
	if not modulesFolder then
		return nil
	end
	local enemyFolder = modulesFolder:FindFirstChild("Enemy")
	if not enemyFolder then
		return nil
	end
	local catalog = enemyFolder:FindFirstChild("EnemyCatalog")
	if catalog and catalog:IsA("ModuleScript") then
		return catalog
	end
	return nil
end

local function loadFromCatalogModule()
	local catalogModule = getCatalogModule()
	if not catalogModule then
		return {}
	end

	local sourceText = nil
	local ok, resultOrErr = pcall(function()
		return catalogModule.Source
	end)
	if ok then
		sourceText = resultOrErr
	end

	local parsed = parseEnemyNamesFromSource(sourceText)
	if #parsed > 0 then
		table.sort(parsed)
		return Util.DedupeArray(parsed)
	end

	return {}
end

local function loadFallbackPool()
	if cachedFallbackPool then
		return Util.CloneArray(cachedFallbackPool)
	end

	local pool = Util.CloneArray(Constants.DEFAULT_ENEMY_POOL)
	local catalogModule = getCatalogModule()

	if catalogModule then
		local ok, catalogOrErr = pcall(function()
			return require(catalogModule)
		end)
		if ok and type(catalogOrErr) == "table" and type(catalogOrErr.GetPool) == "function" then
			local okPool, ambientPool = pcall(function()
				return catalogOrErr.GetPool("Ambient")
			end)
			if okPool and type(ambientPool) == "table" and #ambientPool > 0 then
				pool = Util.DedupeArray(ambientPool)
			end
		end
	end

	cachedFallbackPool = pool
	return Util.CloneArray(pool)
end

function EnemySource.GetFallbackEnemyTypes()
	local fallback = loadFallbackPool()
	table.sort(fallback)
	return fallback
end

function EnemySource.GetEnemyTypes(forceRefresh)
	if cachedEnemyTypes and forceRefresh ~= true then
		return Util.CloneArray(cachedEnemyTypes)
	end

	local names = loadFromCatalogModule()

	if #names <= 0 then
		local fallback = loadFallbackPool()
		names = Util.DedupeArray(fallback)
	end

	table.sort(names)
	cachedEnemyTypes = names
	return Util.CloneArray(names)
end

return EnemySource
