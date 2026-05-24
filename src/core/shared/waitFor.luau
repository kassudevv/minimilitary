local PromiseTyped = require("../../../Packages/PromiseTyped")

function Descendant(parent: Instance, descendantName: string, timeout: number?)
	local descendant = parent:FindFirstChild(descendantName, true)
	if descendant then
		return PromiseTyped.resolve(descendant)
	end
	return PromiseTyped.fromEvent(parent.DescendantAdded, function(d: Instance)
		return d.Name == descendantName
	end):timeout(timeout or 3)
end

function Descendants(parent: Instance, descendantNames: { string }, timeout: number?): PromiseTyped.Class
	local promises: { PromiseTyped.Class } = {}

	for index, descendantName in descendantNames do
		promises[index] = Descendant(parent, descendantName, timeout)
	end

	return PromiseTyped.all(promises):andThen(function(descendants: { Instance })
		for _, descendant in descendants do
			if not descendant:IsDescendantOf(parent) then
				return PromiseTyped.reject("ParentChanged")
			end
		end

		return descendants
	end) :: PromiseTyped.Class
end

return {
	Descendant = Descendant,
	Descendants = Descendants,
}
