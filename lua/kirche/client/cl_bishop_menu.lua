local netcfg = KIRCHEN_NET
local cfg = KIRCHEN_CFG

local panel
local memberList = {}
local textColor = Color(30, 30, 30)
local headerColor = Color(20, 20, 20)

local function sendContributionUpdate(sid, value)
    net.Start(netcfg.BishopUpdateContribution)
    net.WriteString(sid)
    net.WriteInt(value, 32)
    net.SendToServer()
end

local function sendRemove(sid)
    net.Start(netcfg.BishopRemoveMember)
    net.WriteString(sid)
    net.SendToServer()
end

local function sendResetDebt(sid)
    net.Start(netcfg.BishopResetDebt)
    net.WriteString(sid)
    net.SendToServer()
end

local function populateList(listPanel, rows)
    listPanel:Clear()
    for _, row in ipairs(rows) do
        local line = listPanel:AddLine(row.rpname, row.steamid64, row.contribution, row.debt, row.last_charge_at or "")
        line.Member = row
        for _, col in ipairs(line.Columns or {}) do
            col:SetTextColor(textColor)
        end
    end
end

local function buildMenu()
    if IsValid(panel) then panel:Remove() end
    panel = vgui.Create("DFrame")
    panel:SetSize(800, 500)
    panel:Center()
    panel:SetTitle("Kirchenverwaltung")
    panel:MakePopup()

    local search = vgui.Create("DTextEntry", panel)
    search:SetPos(10, 30)
    search:SetSize(300, 25)
    search:SetPlaceholderText("Suche nach Name oder SteamID64...")

    local list = vgui.Create("DListView", panel)
    list:SetPos(10, 60)
    list:SetSize(500, 430)
    list:SetMultiSelect(false)
    list:AddColumn("Name")
    list:AddColumn("SteamID64")
    list:AddColumn("Beitrag")
    list:AddColumn("Schulden")
    list:AddColumn("Letzter Einzug")
    for _, col in ipairs(list.Columns) do
        if IsValid(col.Header) then
            col.Header:SetTextColor(headerColor)
        end
    end

    local detail = vgui.Create("DPanel", panel)
    detail:SetPos(520, 60)
    detail:SetSize(270, 430)

    local nameLabel = vgui.Create("DLabel", detail)
    nameLabel:SetPos(10, 10)
    nameLabel:SetSize(250, 20)
    nameLabel:SetTextColor(textColor)

    local steamLabel = vgui.Create("DLabel", detail)
    steamLabel:SetPos(10, 30)
    steamLabel:SetSize(250, 20)
    steamLabel:SetTextColor(textColor)

    local contribSlider = vgui.Create("DNumSlider", detail)
    contribSlider:SetPos(10, 60)
    contribSlider:SetSize(250, 60)
    contribSlider:SetText("Beitrag")
    contribSlider:SetMinMax(cfg.ContributionMin, cfg.ContributionMax)
    contribSlider:SetDecimals(0)
    if contribSlider.Label then
        contribSlider.Label:SetTextColor(textColor)
    end

    local saveBtn = vgui.Create("DButton", detail)
    saveBtn:SetPos(10, 130)
    saveBtn:SetSize(250, 30)
    saveBtn:SetText("Beitrag speichern")

    local debtLabel = vgui.Create("DLabel", detail)
    debtLabel:SetPos(10, 170)
    debtLabel:SetSize(250, 20)
    debtLabel:SetTextColor(textColor)

    local kickBtn = vgui.Create("DButton", detail)
    kickBtn:SetPos(10, 200)
    kickBtn:SetSize(250, 30)
    kickBtn:SetText("Mitglied entfernen")

    local resetBtn = vgui.Create("DButton", detail)
    resetBtn:SetPos(10, 240)
    resetBtn:SetSize(250, 30)
    resetBtn:SetText("Schulden zurücksetzen")
    resetBtn:SetEnabled(cfg.AllowDebtReset)

    local function updateDetail(row)
        if not row then
            nameLabel:SetText("Kein Mitglied gewählt")
            steamLabel:SetText("")
            debtLabel:SetText("")
            return
        end
        nameLabel:SetText("Name: " .. (row.rpname or ""))
        steamLabel:SetText("SteamID64: " .. (row.steamid64 or ""))
        contribSlider:SetValue(tonumber(row.contribution) or cfg.DefaultContribution)
        debtLabel:SetText("Schulden: " .. (row.debt or 0) .. "$")

        saveBtn.DoClick = function()
            sendContributionUpdate(row.steamid64, contribSlider:GetValue())
        end

        kickBtn.DoClick = function()
            Derma_Query("Mitglied wirklich entfernen?", "Bestätigen",
                "Ja", function() sendRemove(row.steamid64) panel:Close() end,
                "Nein"
            )
        end

        resetBtn.DoClick = function()
            if not cfg.AllowDebtReset then return end
            Derma_Query("Schulden wirklich zurücksetzen?", "Bestätigen",
                "Ja", function() sendResetDebt(row.steamid64) end,
                "Nein"
            )
        end
    end

    list.OnRowSelected = function(_, _, line)
        updateDetail(line.Member)
    end

    search.OnValueChange = function(_, text)
        local filtered = {}
        local lower = string.lower(text or "")
        for _, row in ipairs(memberList) do
            if lower == "" or string.find(string.lower(row.rpname or ""), lower, 1, true) or string.find(row.steamid64 or "", lower, 1, true) then
                table.insert(filtered, row)
            end
        end
        populateList(list, filtered)
    end

    populateList(list, memberList)
end

net.Receive(netcfg.BishopData, function()
    memberList = {}
    local count = net.ReadUInt(16)
    for i = 1, count do
        memberList[i] = {
            steamid64 = net.ReadString(),
            rpname = net.ReadString(),
            contribution = net.ReadInt(32),
            debt = net.ReadInt(32),
            joined_at = net.ReadString(),
            last_charge_at = net.ReadString()
        }
    end
    buildMenu()
end)
