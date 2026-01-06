local netcfg = KIRCHEN_NET

net.Receive(netcfg.RequestInvite, function()
    local seq = net.ReadUInt(16)
    local inviterName = net.ReadString()
    local contribution = net.ReadUInt(16)
    local interval = net.ReadUInt(16)

    local frame = vgui.Create("DFrame")
    frame:SetSize(400, 180)
    frame:Center()
    frame:SetTitle("Kirchenbeitritt")
    frame:MakePopup()

    local label = vgui.Create("DLabel", frame)
    label:SetPos(20, 40)
    label:SetSize(360, 60)
    label:SetWrap(true)
    label:SetText(inviterName .. " lädt dich in die Kirche ein.\nBeitrag: " .. contribution .. "$ alle " .. interval .. " Sekunden.\nMöchtest du beitreten?")

    local yesBtn = vgui.Create("DButton", frame)
    yesBtn:SetSize(160, 30)
    yesBtn:SetPos(30, 120)
    yesBtn:SetText("Ja, beitreten")
    yesBtn.DoClick = function()
        net.Start(netcfg.RequestResponse)
        net.WriteUInt(seq, 16)
        net.WriteBool(true)
        net.SendToServer()
        frame:Close()
    end

    local noBtn = vgui.Create("DButton", frame)
    noBtn:SetSize(160, 30)
    noBtn:SetPos(210, 120)
    noBtn:SetText("Nein")
    noBtn.DoClick = function()
        net.Start(netcfg.RequestResponse)
        net.WriteUInt(seq, 16)
        net.WriteBool(false)
        net.SendToServer()
        frame:Close()
    end
end)

net.Receive(netcfg.BishopOpen, function()
    -- Wird vom Server genutzt, um die UI vorzubereiten (no-op auf Client)
end)
