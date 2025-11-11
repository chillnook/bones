local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace        = game:GetService("Workspace")

local RigUtil = {}

function RigUtil.CurrentCamera()
	return Workspace.CurrentCamera
end

function RigUtil.GetStageClone()
	local ok, bridge = pcall(function()
		return require(ReplicatedStorage.Flux.Client.AvatarCreationSystem.UI:WaitForChild("AvatarUISessionBridge"))
	end)
	if not ok or not bridge then return nil end
	return bridge:GetStageClone()
end

function RigUtil.GetBoneRoot()
	local clone = RigUtil.GetStageClone()
	if not clone then return nil end
	local hrp = clone:FindFirstChild("HumanoidRootPart")
	if not hrp then return nil end
	local lower = hrp:FindFirstChild("LowerTorso")
	local upper = lower and lower:FindFirstChild("UpperTorso")
	local neck  = upper and upper:FindFirstChild("Neck")
	return neck
end

function RigUtil.GetHeadPart()
	local clone = RigUtil.GetStageClone()
	if not clone then return nil end
	local head = clone:FindFirstChild("Head") or clone:FindFirstChild("Head", true)
	return (head and head:IsA("BasePart")) and head or nil
end

function RigUtil.WorldAxisVector(axis: string, headCF: CFrame): Vector3
	if axis == "X" then
		return Vector3.new(1,0,0)
	elseif axis == "Y" then
		return Vector3.new(0,1,0)
	else
		local f = headCF.LookVector
		local flat = Vector3.new(f.X, 0, f.Z)
		if flat.Magnitude < 1e-6 then flat = Vector3.new(0,0,-1) end
		return flat.Unit
	end
end

function RigUtil.GetParentBasisCFrame(bone: Instance, head: BasePart?): CFrame
	if bone and bone.Parent and (bone.Parent:IsA("Bone") or bone.Parent:IsA("Attachment") or bone.Parent:IsA("BasePart")) then
		local parent = bone.Parent :: any
		if parent.WorldCFrame then
			return parent.WorldCFrame
		end
	end
	local h = head or RigUtil.GetHeadPart()
	return h and h.CFrame or CFrame.new()
end

function RigUtil.ToLocalPixels(frame: Frame, viewportPos: Vector3): Vector2
	local ap = frame.AbsolutePosition
	return Vector2.new(viewportPos.X - ap.X, viewportPos.Y - ap.Y)
end

return RigUtil
