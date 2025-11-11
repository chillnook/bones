local UserInputService = game:GetService("UserInputService")

local SliderUI = {}

local function valueToScale(v: number): number
	return math.clamp((v + 1) * 0.5, 0, 1)
end
local function scaleToValue(t: number): number
	return math.clamp(t * 2 - 1, -1, 1)
end

function SliderUI.Build(panelFrame: Frame, sliderSpecs: {any}, state: table, callbacks: table)
	local _dragMoveConnection: RBXScriptConnection?
	local _dragEndConnection: RBXScriptConnection?
	local _isDraggingSlider = false

	local container = panelFrame:FindFirstChild("SlidersContainerFrame")
	if not (container and container:IsA("Frame")) then return end
	local template = container:FindFirstChild("SliderTemplateContainer")
	if not template then return end
	template.Visible = false

	for _, spec in ipairs(sliderSpecs) do
		local clone = template:Clone()
		clone.Name = spec.key .. "_Container"
		clone:SetAttribute("IsSliderClone", true)
		clone.Visible = true
		clone.Parent = container

		local bar   = clone:FindFirstChild("SliderTemplate")
		local label = clone:FindFirstChild("SliderTextTemplate")
		if label and label:IsA("TextLabel") then label.Text = spec.label end

		if not (bar and bar:IsA("ImageLabel")) then clone:Destroy() continue end
		local knob = bar:FindFirstChild("SliderKnob")
		if not (knob and knob:IsA("ImageButton")) then clone:Destroy() continue end

		knob.AnchorPoint = Vector2.new(0.5, 0.5)

		local function setKnobByRawValue(v: number)
			state.sliderRawValues[spec.key] = math.clamp(v, -1, 1)
			knob.Position = UDim2.fromScale(valueToScale(state.sliderRawValues[spec.key]), 0.5)
		end

		setKnobByRawValue(state.sliderRawValues[spec.key] or 0)

		bar:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
			setKnobByRawValue(state.sliderRawValues[spec.key] or 0)
		end)

		local function finalizeDrag()
			_isDraggingSlider = false
			if _dragMoveConnection then _dragMoveConnection:Disconnect() _dragMoveConnection = nil end
			if _dragEndConnection then _dragEndConnection:Disconnect() _dragEndConnection = nil end
		end

		local function updateFromMouse()
			local mouse = UserInputService:GetMouseLocation()
			local x0 = bar.AbsolutePosition.X
			local w  = math.max(bar.AbsoluteSize.X, 1)
			local rel = math.clamp((mouse.X - x0) / w, 0, 1)
			local raw = scaleToValue(rel)

			if UserInputService:IsKeyDown(Enum.KeyCode.LeftAlt) or UserInputService:IsKeyDown(Enum.KeyCode.RightAlt) then
				raw = (state.sliderRawValues[spec.key] or 0) + (raw - (state.sliderRawValues[spec.key] or 0)) * 0.35
			elseif UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) or UserInputService:IsKeyDown(Enum.KeyCode.RightShift) then
				raw = (state.sliderRawValues[spec.key] or 0) + (raw - (state.sliderRawValues[spec.key] or 0)) * 1.5
			end

			setKnobByRawValue(raw)
			local bone = state.getActiveBoneName()
			if bone then callbacks.recomputeDerived(bone) end
			callbacks.onUserAdjust()
		end

		local function startDrag(input: InputObject)
			if input.UserInputType ~= Enum.UserInputType.MouseButton1 or input.UserInputState ~= Enum.UserInputState.Begin then return end
			if _isDraggingSlider then finalizeDrag() end
			_isDraggingSlider = true
			callbacks.onUserAdjust()
			updateFromMouse()

			_dragMoveConnection = UserInputService.InputChanged:Connect(function(changed)
				if changed.UserInputType == Enum.UserInputType.MouseMovement and _isDraggingSlider then
					updateFromMouse()
				end
			end)
			_dragEndConnection = UserInputService.InputEnded:Connect(function(ended)
				if ended.UserInputType == Enum.UserInputType.MouseButton1 then
					finalizeDrag()
				end
			end)
		end

		knob.InputBegan:Connect(startDrag)
		bar.InputBegan:Connect(function(io)
			if io.UserInputType == Enum.UserInputType.MouseButton1 and io.UserInputState == Enum.UserInputState.Begin then
				callbacks.onUserAdjust()
				updateFromMouse()
				startDrag(io)
			end
		end)

		state.sliders[spec.key] = {
			container = clone,
			bar = bar,
			knob = knob,
			label = label,
			setValue = function(v: number)
				setKnobByRawValue(v)
				local bone = state.getActiveBoneName()
				if bone then callbacks.recomputeDerived(bone) end
			end
		}
	end
end

return SliderUI
