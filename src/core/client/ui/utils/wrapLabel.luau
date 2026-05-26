return function(text: string, maxLineLength: number?): string
	maxLineLength = maxLineLength or 10

	-- Already short enough
	if #text <= maxLineLength then
		return text
	end

	local words = string.split(text, " ")

	-- Single word (like "Housing") -> don't split awkwardly
	if #words == 1 then
		return text
	end

	local lines: { string } = {}
	local current = ""

	for _, word in words do
		local candidate = if current == "" then word else current .. " " .. word

		if #candidate > maxLineLength then
			table.insert(lines, current)
			current = word
		else
			current = candidate
		end
	end

	if current ~= "" then
		table.insert(lines, current)
	end

	return table.concat(lines, "\n")
end
