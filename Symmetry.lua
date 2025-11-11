local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RigUtil = require(ReplicatedStorage.Flux.Client.AvatarCreationSystem.UI.Categories.Shaping:WaitForChild("RigUtil"))

local Sym = {}

local CENTRAL_BONE_PATTERNS = {
	"^Mid_", "^MidNoseShape$", "^NoseBridge", "^Chin$", "^Chin_", "^Up_LIP$", "^Lo_LIP$",
	"^Tongue", "^Up_LIPShape$", "^Lo_LIPShape$", "^Mid_Nose$", "^NoseBridge%d+$"
}

function Sym.IsCentral(boneName: string): boolean
	for _, pat in ipairs(CENTRAL_BONE_PATTERNS) do
		if string.match(boneName, pat) then return true end
	end
	return false
end

function Sym.MirrorName(name: string): string?
	if name:sub(1,5) == "Left_" then
		return "Right_" .. name:sub(6)
	elseif name:sub(1,6) == "Right_" then
		return "Left_" .. name:sub(7)
	end
	return nil
end

function Sym.ResolveMirrorBone(boneName: string, presetBones: table, gender: string?): string?
	if Sym.IsCentral(boneName) then return nil end
	local m = Sym.MirrorName(boneName)
	if not m then return nil end
	if gender and presetBones and (presetBones.Minned[gender][m] or presetBones.Midded[gender][m] or presetBones.Maxxed[gender][m]) then
		return m
	end
	local root = RigUtil.GetBoneRoot()
	if root and root:FindFirstChild(m, true) then
		return m
	end
	return nil
end

return Sym
