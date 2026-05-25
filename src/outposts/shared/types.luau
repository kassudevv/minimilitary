export type Status = "uncontested" | "contested" | "claimed"

export type Outpost = {
	read owner: string,
	read status: Status,
}

export type OutpostSnapshot = {
	guid: string,
	root: Folder,
	colliders: { BasePart },
}

local outpostTemplate: Outpost = {
	owner = "",
	status = "uncontested",
}

return { outpostTemplate = outpostTemplate }
