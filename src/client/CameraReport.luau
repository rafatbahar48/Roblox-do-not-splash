-- Tells the server which way this screen's camera points, a few times a
-- second while it changes, so the creature can come at you from where you are
-- looking (server/Lurker.luau). Only the direction across the ground is sent.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = require(ReplicatedStorage.Shared.Remotes)

local INTERVAL = 0.25

local CameraReport = {}

function CameraReport.start()
	task.spawn(function()
		local sent = Vector3.zero
		while true do
			task.wait(INTERVAL)
			local look = workspace.CurrentCamera.CFrame.LookVector
			local flat = Vector3.new(look.X, 0, look.Z)
			if flat.Magnitude > 0.1 then
				flat = flat.Unit
				if flat:Dot(sent) < 0.98 then
					sent = flat
					Remotes.CameraLook:FireServer(flat)
				end
			end
		end
	end)
end

return CameraReport
