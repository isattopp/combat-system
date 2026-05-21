local DamageService = {}

function DamageService:ApplyDamage(humanoid, damage, options)
	if not humanoid then
		return false
	end

	if humanoid.Health <= 0 then
		return false
	end

	if typeof(damage) ~= "number" or damage <= 0 then
		return false
	end

	options = options or {}

	if humanoid:GetAttribute("Invincible") then
		return false
	end

	local iframeEnd = humanoid:GetAttribute("IFrameEnd")
	if iframeEnd and os.clock() < iframeEnd then
		return false
	end

	local finalDamage = damage

	if humanoid:GetAttribute("Blocking") then
		local blockMultiplier = options.BlockMultiplier or 0.25
		finalDamage *= blockMultiplier
	end

	if options.MinDamage then
		finalDamage = math.max(finalDamage, options.MinDamage)
	end

	humanoid:TakeDamage(finalDamage)

	return true, finalDamage
end

return DamageService
