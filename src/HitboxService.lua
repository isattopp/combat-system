local HitboxService = {}

function HitboxService:CreateHitbox(character, size, offset)
	if not character then
		return {}
	end

	local root = character:FindFirstChild("HumanoidRootPart")

	if not root then
		return {}
	end

	local hitboxCFrame = root.CFrame * offset

	local overlapParams = OverlapParams.new()
	overlapParams.FilterType = Enum.RaycastFilterType.Exclude
	overlapParams.FilterDescendantsInstances = { character }

	return workspace:GetPartBoundsInBox(
		hitboxCFrame,
		size,
		overlapParams
	)
end

return HitboxService
