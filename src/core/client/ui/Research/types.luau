export type RuntimeNode = {
	Id: string,
	Parent: RuntimeNode?,
	Children: { RuntimeNode },

	GridPosition: Vector2,
	Depth: number,
	Data: Node,
}

export type NodeLocation = "Top" | "Bottom" | "Left" | "Right" | "TopLeft" | "TopRight" | "BottomLeft" | "BottomRight"

export type Node = {
	Id: string,
	Label: string,
	Icon: string?,
	Description: string?,
	Location: string?,
	ConnectsFromId: NodeLocation?,
	RedirectsToPage: string?,
	IsBackButton: boolean?,
}

return {}
