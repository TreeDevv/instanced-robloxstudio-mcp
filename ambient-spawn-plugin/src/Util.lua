local Util = {}

function Util.Trim(text)
	if type(text) ~= "string" then
		return ""
	end
	return (string.gsub(text, "^%s*(.-)%s*$", "%1"))
end

function Util.CloneArray(list)
	local copy = {}
	for index, value in ipairs(list or {}) do
		copy[index] = value
	end
	return copy
end

function Util.Round(value, precision)
	local power = math.pow(10, precision or 0)
	return math.floor(value * power + 0.5) / power
end

function Util.Clamp(value, minValue, maxValue)
	if value < minValue then
		return minValue
	end
	if value > maxValue then
		return maxValue
	end
	return value
end

function Util.ApplyStep(value, step)
	if not step or step <= 0 then
		return value
	end
	return math.floor((value / step) + 0.5) * step
end

function Util.SplitCsv(csvText)
	local result = {}
	local seen = {}
	if type(csvText) ~= "string" then
		return result
	end

	for token in string.gmatch(csvText, "[^,]+") do
		local trimmed = Util.Trim(token)
		if trimmed ~= "" and not seen[trimmed] then
			seen[trimmed] = true
			table.insert(result, trimmed)
		end
	end

	return result
end

function Util.JoinCsv(values)
	local result = {}
	local seen = {}

	for _, value in ipairs(values or {}) do
		local text = Util.Trim(tostring(value))
		if text ~= "" and not seen[text] then
			seen[text] = true
			table.insert(result, text)
		end
	end

	return table.concat(result, ",")
end

function Util.ArrayContains(list, target)
	for _, value in ipairs(list or {}) do
		if value == target then
			return true
		end
	end
	return false
end

function Util.ArrayWithout(list, target)
	local result = {}
	for _, value in ipairs(list or {}) do
		if value ~= target then
			table.insert(result, value)
		end
	end
	return result
end

function Util.DedupeArray(list)
	local result = {}
	local seen = {}
	for _, value in ipairs(list or {}) do
		if not seen[value] then
			seen[value] = true
			table.insert(result, value)
		end
	end
	return result
end

function Util.ResolvePath(pathText)
	if type(pathText) ~= "string" or pathText == "" then
		return nil
	end

	local normalized = pathText
	normalized = normalized:gsub("^game%.", "")
	normalized = normalized:gsub("^Game%.", "")

	local current = game
	for token in string.gmatch(normalized, "[^%.]+") do
		local nextInstance = nil
		if current == game then
			local ok, serviceOrErr = pcall(function()
				return game:GetService(token)
			end)
			if ok and serviceOrErr then
				nextInstance = serviceOrErr
			end
		end

		if not nextInstance then
			nextInstance = current:FindFirstChild(token)
		end

		if not nextInstance then
			return nil
		end

		current = nextInstance
	end

	return current
end

function Util.EnsureFolderPath(pathText)
	if type(pathText) ~= "string" or pathText == "" then
		return nil, "Invalid folder path"
	end

	local normalized = pathText
	normalized = normalized:gsub("^game%.", "")
	normalized = normalized:gsub("^Game%.", "")

	local current = game
	for token in string.gmatch(normalized, "[^%.]+") do
		local nextInstance = nil

		if current == game then
			local ok, serviceOrErr = pcall(function()
				return game:GetService(token)
			end)
			if ok and serviceOrErr then
				nextInstance = serviceOrErr
			end
		end

		if not nextInstance then
			nextInstance = current:FindFirstChild(token)
		end

		if not nextInstance then
			local createdFolder = Instance.new("Folder")
			createdFolder.Name = token
			createdFolder.Parent = current
			nextInstance = createdFolder
		end

		current = nextInstance
	end

	return current
end

function Util.InferIslandName(instance)
	local map = workspace:FindFirstChild("Map")
	if not map then
		return nil
	end

	local islands = map:FindFirstChild("Islands")
	if not islands then
		return nil
	end

	local current = instance
	while current and current ~= workspace do
		if current.Parent == islands then
			return current.Name
		end
		current = current.Parent
	end

	return nil
end

function Util.FormatNumber(value, precision)
	local safePrecision = precision or 0
	if safePrecision <= 0 then
		return tostring(math.floor(value + 0.5))
	end
	local rounded = Util.Round(value, safePrecision)
	return string.format("%." .. tostring(safePrecision) .. "f", rounded)
end

return Util
