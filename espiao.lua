--[[
    99NS22 - ESPIAO MOBILE (Delta e outros)
    1) Execute ESTE primeiro e toque em INICIAR
    2) Execute o OUTRO script e use as funcoes dele por 1-2 minutos
    3) Toque em COPIAR RESUMO e cole no chat
    So observa: nao muda nada no jogo nem no outro script.
]]
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UIS = game:GetService("UserInputService")
local LP = Players.LocalPlayer
local G = (getgenv and getgenv()) or _G
if G.ESPIAO99_STOP then pcall(G.ESPIAO99_STOP) end

local on = false
local t0 = tick()
local conns = {}
local function con(sig, fn) local ok, c = pcall(function() return sig:Connect(fn) end) if ok then table.insert(conns, c) end end

-- ================= DADOS =================
-- resumo agrupado (o que importa) + linha do tempo curta
local R
local function reset()
    R = {
        urls = {}, sent = {}, prompts = {}, touches = {}, clicks = {}, props = {}, physics = {},
        tools = {}, guis = {}, hooks = {}, loads = {}, files = {}, warnings = {}, server = {},
        tp = {n = 0, max = 0, sample = nil}, speed = {max = 0, ws = {}}, timeline = {},
    }
    t0 = tick()
end
reset()
local function stamp() return ("%6.1fs"):format(tick() - t0) end
local function tl(kind, text)
    if #R.timeline < 600 then table.insert(R.timeline, stamp() .. " [" .. kind .. "] " .. text) end
end
local function bump(tbl, key, sample)
    local e = tbl[key]
    if not e then
        e = {n = 0, first = sample, at = stamp()}
        tbl[key] = e
    end
    e.n = e.n + 1
    e.last = sample
    return e.n
end
local function warnOnce(msg)
    if not R.warnings[msg] then R.warnings[msg] = true; tl("ALERTA", msg) end
end

local function fmt(v, depth)
    depth = depth or 0
    local t = typeof(v)
    if t == "Instance" then
        local ok, n = pcall(function() return v:GetFullName() end)
        return "<" .. v.ClassName .. ">" .. (ok and n or "?")
    elseif t == "string" then return '"' .. v:sub(1, 120) .. (#v > 120 and "..." or "") .. '"'
    elseif t == "number" then return tostring(math.floor(v * 100 + 0.5) / 100)
    elseif t == "Vector3" then return ("V3(%.1f,%.1f,%.1f)"):format(v.X, v.Y, v.Z)
    elseif t == "CFrame" then local p = v.Position return ("CF(%.1f,%.1f,%.1f)"):format(p.X, p.Y, p.Z)
    elseif t == "table" then
        if depth > 2 then return "{...}" end
        local parts, n = {}, 0
        for k, val in pairs(v) do
            n = n + 1
            if n > 12 then parts[#parts + 1] = "..." break end
            parts[#parts + 1] = tostring(k) .. "=" .. fmt(val, depth + 1)
        end
        return "{" .. table.concat(parts, ", ") .. "}"
    end
    return tostring(v)
end
local function argsStr(a)
    local o = {}
    for i = 1, a.n do o[i] = fmt(a[i]) end
    return table.concat(o, ", ")
end
local function checkUrl(url)
    url = tostring(url)
    local low = url:lower()
    if low:find("discord.com/api/webhooks") or low:find("discordapp.com/api/webhooks") then
        warnOnce("⚠️ ENVIA DADOS PRA UM WEBHOOK DO DISCORD: " .. url:sub(1, 60) .. "...")
    end
    if low:find("ipify") or low:find("ip%-api") or low:find("ipinfo") then
        warnOnce("⚠️ CONSULTA O SEU IP: " .. url:sub(1, 80))
    end
end

-- ================= 1) GANCHOS: o que o outro script CHAMA =================
local hookStatus = {}
local function addStatus(t) table.insert(hookStatus, t) end
local NAMECALL = {FireServer = "ENVIA", InvokeServer = "PEDE", HttpGet = "BAIXA", HttpGetAsync = "BAIXA",
    HttpPost = "POSTA", HttpPostAsync = "POSTA", Kick = "KICK", Teleport = "TELEPORTA", TeleportToPlaceInstance = "TELEPORTA"}
local function onNamecall(self, m, a, fromExec)
    local name = (typeof(self) == "Instance") and (pcall(function() return self.Name end) and self.Name or "?") or tostring(self)
    local kind = NAMECALL[m]
    if kind == "BAIXA" or kind == "POSTA" then
        local url = a[1]
        checkUrl(url)
        if bump(R.urls, m .. " " .. tostring(url), argsStr(a)) == 1 then tl(kind, tostring(url)) end
    elseif kind == "KICK" then
        warnOnce("chamou :Kick() em " .. name)
    elseif kind == "TELEPORTA" then
        warnOnce("TeleportService:" .. m .. " (" .. argsStr(a) .. ")")
    elseif fromExec then
        local key = m .. " " .. name
        if bump(R.sent, key, argsStr(a)) == 1 then tl(kind, key .. " (" .. argsStr(a):sub(1, 200) .. ")") end
    end
end
if hookmetamethod and getnamecallmethod then
    local ok, err = pcall(function()
        G.ESPIAO99_NC = function(self, m, a, fromExec) if on then pcall(onNamecall, self, m, a, fromExec) end end
        if G.ESPIAO99_HOOKED then return end
        local old
        local function h(self, ...)
            local m = getnamecallmethod()
            if NAMECALL[m] then
                local f = G.ESPIAO99_NC
                if f then f(self, m, table.pack(...), checkcaller and checkcaller() or false) end
            end
            return old(self, ...)
        end
        old = hookmetamethod(game, "__namecall", newcclosure and newcclosure(h) or h)
        G.ESPIAO99_HOOKED = true
    end)
    addStatus("chamadas ao servidor: " .. (ok and "SIM" or ("falhou " .. tostring(err))))
else
    addStatus("chamadas ao servidor: NAO (executor sem hookmetamethod)")
end

-- funcoes do executor que o outro script usa
-- o gancho e instalado UMA vez; cada execucao do espiao so troca a funcao que anota (G.ESPIAO99_CBS)
G.ESPIAO99_CBS = {}
G.ESPIAO99_DONE = G.ESPIAO99_DONE or {}
local function hookFn(label, fname, onCall)
    G.ESPIAO99_CBS[fname] = function(a) if on then pcall(onCall, a) end end
    if G.ESPIAO99_DONE[fname] then table.insert(hookStatus, "  + " .. label) return end
    local f = G[fname]
    if type(f) ~= "function" or not hookfunction then return end
    local ok = pcall(function()
        local old
        local function spy(...)
            local cb = G.ESPIAO99_CBS and G.ESPIAO99_CBS[fname]
            if cb then cb(table.pack(...)) end
            return old(...)
        end
        old = hookfunction(f, newcclosure and newcclosure(spy) or spy)
    end)
    if ok then G.ESPIAO99_DONE[fname] = true; table.insert(hookStatus, "  + " .. label) end
end
if hookfunction then
    addStatus("funcoes do executor: SIM")
    for _, fname in ipairs({"request", "http_request", "syn_request"}) do
        hookFn(fname, fname, function(a)
            local o = a[1]
            if type(o) == "table" then
                checkUrl(o.Url)
                if bump(R.urls, tostring(o.Method or "GET") .. " " .. tostring(o.Url), fmt(o.Body or "")) == 1 then
                    tl("BAIXA", tostring(o.Method or "GET") .. " " .. tostring(o.Url))
                end
            end
        end)
    end
    hookFn("fireproximityprompt", "fireproximityprompt", function(a)
        local p = a[1]
        local key = (typeof(p) == "Instance" and (p.ActionText .. " @ " .. (p.Parent and p.Parent:GetFullName() or "?"))) or fmt(p)
        if bump(R.prompts, key, argsStr(a)) == 1 then tl("PROMPT", key) end
    end)
    hookFn("firetouchinterest", "firetouchinterest", function(a)
        local key = fmt(a[2])
        if bump(R.touches, key, argsStr(a)) == 1 then tl("TOQUE", "encostou em " .. key) end
    end)
    hookFn("fireclickdetector", "fireclickdetector", function(a)
        local key = fmt(a[1])
        if bump(R.clicks, key, argsStr(a)) == 1 then tl("CLIQUE", key) end
    end)
    hookFn("loadstring", "loadstring", function(a)
        local src = tostring(a[1] or "")
        R.loadN = (R.loadN or 0) + 1
        bump(R.loads, ("codigo %d (%d letras)"):format(R.loadN, #src), src:sub(1, 100))
        tl("CODIGO", ("carregou codigo com %d letras"):format(#src))
        if R.loadN <= 5 then pcall(writefile, "espiao_codigo_" .. R.loadN .. ".lua", src) end
    end)
    for _, fname in ipairs({"hookmetamethod", "hookfunction"}) do
        hookFn(fname, fname, function(a)
            local what = fname == "hookmetamethod" and (fmt(a[1]) .. " " .. tostring(a[2])) or tostring(a[1])
            if bump(R.hooks, fname .. " " .. what, "") == 1 then tl("GANCHO", fname .. " " .. what) end
        end)
    end
    hookFn("setclipboard", "setclipboard", function(a) bump(R.files, "copiou pra area de transferencia", tostring(a[1]):sub(1, 80)) end)
    hookFn("writefile", "writefile", function(a) bump(R.files, "gravou arquivo " .. tostring(a[1]), "") end)
    hookFn("readfile", "readfile", function(a) bump(R.files, "leu arquivo " .. tostring(a[1]), "") end)
    hookFn("queue_on_teleport", "queue_on_teleport", function(a) warnOnce("roda codigo ao trocar de servidor (queue_on_teleport)") end)
else
    addStatus("funcoes do executor: NAO (sem hookfunction)")
end

-- ================= 2) EFEITOS: o que muda no jogo (funciona em qualquer executor) =================
local NOISY = {["RE/Leaderboards/Updated"] = true, ["RE/ProfileMirror/ProfileDelta"] = true, ["RE/RigSync/Refresh"] = true}
pcall(function()
    for _, r in ipairs(RS.Packages.Networking:GetChildren()) do
        if r:IsA("RemoteEvent") and not NOISY[r.Name] then
            con(r.OnClientEvent, function(...)
                if not on then return end
                if bump(R.server, r.Name, argsStr(table.pack(...)):sub(1, 200)) == 1 then tl("SERVIDOR", r.Name) end
            end)
        end
    end
end)
pcall(function()
    con(game:GetService("ProximityPromptService").PromptTriggered, function(p, plr)
        if on and plr == LP then
            local key = "acionou " .. p.ActionText .. " @ " .. (p.Parent and p.Parent:GetFullName() or "?")
            if bump(R.prompts, key, "") == 1 then tl("PROMPT", key) end
        end
    end)
end)
local function watchChar(c)
    local hum = c:WaitForChild("Humanoid", 10)
    local root = c:WaitForChild("HumanoidRootPart", 10)
    if hum then
        for _, prop in ipairs({"WalkSpeed", "JumpPower", "JumpHeight", "HipHeight", "PlatformStand", "Sit", "Health", "MaxHealth"}) do
            con(hum:GetPropertyChangedSignal(prop), function()
                if not on then return end
                local v = tostring(hum[prop])
                if prop == "WalkSpeed" then R.speed.ws[v] = true end
                if bump(R.props, prop, v) <= 3 then tl("PERSONAGEM", prop .. " -> " .. v) end
            end)
        end
    end
    con(c.DescendantAdded, function(d)
        if not on then return end
        if d:IsA("BodyMover") or d:IsA("Constraint") or d:IsA("AlignPosition") or d:IsA("LinearVelocity") then
            if bump(R.physics, d.ClassName .. " '" .. d.Name .. "'", "") == 1 then tl("FISICA", "criou " .. d.ClassName .. " " .. d.Name) end
        elseif d:IsA("Tool") and d.Parent == c then
            if bump(R.tools, d.Name, "") == 1 then tl("FERRAMENTA", "equipou " .. d.Name) end
        end
    end)
    if root then
        con(root:GetPropertyChangedSignal("Anchored"), function()
            if on then bump(R.props, "HRP ancorado", tostring(root.Anchored)) end
        end)
        local last = root.Position
        local acc, dist = 0, 0
        con(RunService.Heartbeat, function(dt)
            if not root.Parent then return end
            local p = root.Position
            local d = (p - last).Magnitude
            if on then
                if d > 25 then
                    R.tp.n = R.tp.n + 1
                    if d > R.tp.max then R.tp.max = d; R.tp.sample = fmt(last) .. " -> " .. fmt(p) end
                    if R.tp.n <= 5 then tl("TELEPORTE", ("%.0f studs em 1 frame: %s -> %s"):format(d, fmt(last), fmt(p))) end
                else
                    dist = dist + Vector3.new(p.X - last.X, 0, p.Z - last.Z).Magnitude
                end
                acc = acc + dt
                if acc >= 1 then
                    local v = dist / acc
                    if v > R.speed.max then R.speed.max = v end
                    acc, dist = 0, 0
                end
            end
            last = p
        end)
    end
end
if LP.Character then task.spawn(watchChar, LP.Character) end
con(LP.CharacterAdded, watchChar)
con(workspace:GetPropertyChangedSignal("Gravity"), function() if on then bump(R.props, "Gravity", tostring(workspace.Gravity)) end end)
pcall(function()
    local cam = workspace.CurrentCamera
    con(cam:GetPropertyChangedSignal("FieldOfView"), function() if on then bump(R.props, "Camera FOV", tostring(math.floor(cam.FieldOfView))) end end)
end)
pcall(function()
    local L = game:GetService("Lighting")
    for _, prop in ipairs({"ClockTime", "Brightness", "FogEnd", "GlobalShadows"}) do
        con(L:GetPropertyChangedSignal(prop), function() if on then bump(R.props, "Lighting." .. prop, tostring(L[prop])) end end)
    end
end)
local function watchGuiRoot(rootObj, label)
    pcall(function()
        con(rootObj.ChildAdded, function(g)
            if on and g:IsA("ScreenGui") and g.Name ~= "Espiao99" then
                if bump(R.guis, label .. ": " .. g.Name, "") == 1 then tl("TELA", "criou tela '" .. g.Name .. "' em " .. label) end
            end
        end)
    end)
end
pcall(function() watchGuiRoot(gethui(), "gethui") end)
pcall(function() watchGuiRoot(game:GetService("CoreGui"), "CoreGui") end)
pcall(function() watchGuiRoot(LP:WaitForChild("PlayerGui"), "PlayerGui") end)
con(workspace.DescendantAdded, function(d)
    if not on then return end
    if d:IsA("Highlight") or d:IsA("BillboardGui") then bump(R.guis, "criou " .. d.ClassName .. " no mapa", "") end
end)

-- ================= RESUMO =================
local function section(out, title, tbl, limit)
    local list = {}
    for k, e in pairs(tbl) do table.insert(list, {k, e}) end
    if #list == 0 then return end
    table.sort(list, function(a, b) return a[2].n > b[2].n end)
    table.insert(out, "")
    table.insert(out, "== " .. title .. " (" .. #list .. ") ==")
    for i = 1, math.min(limit or 25, #list) do
        local k, e = list[i][1], list[i][2]
        local line = ("x%-4d %s"):format(e.n, k)
        if e.first and e.first ~= "" then line = line .. "\n        ex: " .. tostring(e.first):sub(1, 220) end
        table.insert(out, line)
    end
end
local function buildSummary(withTimeline)
    local out = {
        "ESPIAO 99NS22 MOBILE - " .. os.date("%d/%m %H:%M:%S"),
        "executor: " .. tostring(identifyexecutor and identifyexecutor() or "?") .. " | jogo: " .. game.PlaceId,
        ("tempo espionando: %.0fs"):format(tick() - t0),
    }
    for _, h in ipairs(hookStatus) do table.insert(out, h) end
    local w = {}
    for k in pairs(R.warnings) do table.insert(w, k) end
    if #w > 0 then table.insert(out, ""); table.insert(out, "== ALERTAS =="); for _, x in ipairs(w) do table.insert(out, x) end end
    section(out, "LINKS QUE ELE BAIXA/ENVIA", R.urls, 15)
    section(out, "COMANDOS QUE ELE MANDA AO SERVIDOR", R.sent, 30)
    section(out, "PROMPTS (segurar E)", R.prompts, 15)
    section(out, "ENCOSTOU (firetouchinterest)", R.touches, 10)
    section(out, "CLIQUES (fireclickdetector)", R.clicks, 10)
    section(out, "GANCHOS QUE ELE INSTALA", R.hooks, 15)
    section(out, "CODIGO CARREGADO (loadstring)", R.loads, 8)
    section(out, "PERSONAGEM / MUNDO MUDADO", R.props, 20)
    section(out, "FISICA CRIADA NO PERSONAGEM", R.physics, 10)
    section(out, "FERRAMENTAS", R.tools, 10)
    section(out, "TELAS E VISUAIS", R.guis, 10)
    section(out, "ARQUIVOS / AREA DE TRANSFERENCIA", R.files, 10)
    section(out, "RESPOSTAS DO SERVIDOR", R.server, 25)
    table.insert(out, "")
    local ws = {}
    for k in pairs(R.speed.ws) do table.insert(ws, k) end
    table.insert(out, ("MOVIMENTO: velocidade maxima medida %.0f studs/s | WalkSpeed vistos: %s"):format(R.speed.max, table.concat(ws, ", ")))
    table.insert(out, ("TELEPORTES: %d (maior %.0f studs %s)"):format(R.tp.n, R.tp.max, R.tp.sample or ""))
    if withTimeline then
        table.insert(out, "")
        table.insert(out, "== LINHA DO TEMPO ==")
        for _, l in ipairs(R.timeline) do table.insert(out, l) end
    end
    return table.concat(out, "\n")
end

-- ================= PAINEL (feito pro toque) =================
local gui = Instance.new("ScreenGui")
gui.Name = "Espiao99"; gui.ResetOnSpawn = false; gui.DisplayOrder = 999
if not pcall(function() gui.Parent = (gethui and gethui()) or game:GetService("CoreGui") end) or not gui.Parent then
    gui.Parent = LP:WaitForChild("PlayerGui")
end
local f = Instance.new("Frame", gui)
f.Size = UDim2.fromOffset(230, 236); f.Position = UDim2.new(1, -245, 0, 70)
f.BackgroundColor3 = Color3.fromRGB(14, 14, 24); f.Active = true
Instance.new("UICorner", f).CornerRadius = UDim.new(0, 12)
local st = Instance.new("UIStroke", f); st.Color = Color3.fromRGB(255, 60, 172); st.Thickness = 2
local title = Instance.new("TextLabel", f)
title.Size = UDim2.new(1, -36, 0, 30); title.Position = UDim2.fromOffset(8, 0); title.BackgroundTransparency = 1
title.Font = Enum.Font.GothamBlack; title.TextSize = 14; title.TextXAlignment = Enum.TextXAlignment.Left
title.TextColor3 = Color3.fromRGB(255, 60, 172); title.Text = "🕵️ ESPIAO 99NS22"
local status = Instance.new("TextLabel", f)
status.Size = UDim2.new(1, -16, 0, 74); status.Position = UDim2.fromOffset(8, 156); status.BackgroundTransparency = 1
status.Font = Enum.Font.Gotham; status.TextSize = 11; status.TextWrapped = true
status.TextYAlignment = Enum.TextYAlignment.Top; status.TextXAlignment = Enum.TextXAlignment.Left
status.TextColor3 = Color3.fromRGB(190, 190, 210)
local function btn(y, txt, col, cb)
    local b = Instance.new("TextButton", f)
    b.Size = UDim2.new(1, -16, 0, 36); b.Position = UDim2.fromOffset(8, y)
    b.BackgroundColor3 = col; b.TextColor3 = Color3.new(1, 1, 1); b.Font = Enum.Font.GothamBold; b.TextSize = 13
    b.TextWrapped = true; b.Text = txt
    Instance.new("UICorner", b).CornerRadius = UDim.new(0, 8)
    b.MouseButton1Click:Connect(function() task.spawn(cb, b) end)
    return b
end
local close = Instance.new("TextButton", f)
close.Size = UDim2.fromOffset(26, 26); close.Position = UDim2.new(1, -32, 0, 3)
close.BackgroundColor3 = Color3.fromRGB(150, 30, 60); close.Text = "X"; close.TextColor3 = Color3.new(1, 1, 1)
close.Font = Enum.Font.GothamBold; close.TextSize = 13
Instance.new("UICorner", close).CornerRadius = UDim.new(0, 6)
close.MouseButton1Click:Connect(function() G.ESPIAO99_STOP() end)

btn(32, "▶ INICIAR", Color3.fromRGB(30, 150, 90), function(b)
    if not on then
        reset(); on = true
        b.Text = "⏺ espionando... rode o outro script"
    else
        on = false
        b.Text = "▶ CONTINUAR"
    end
end)
btn(73, "📋 COPIAR RESUMO", Color3.fromRGB(110, 40, 200), function(b)
    local txt = buildSummary(false)
    if #txt > 60000 then txt = txt:sub(1, 60000) .. "\n...(cortado)" end
    local ok = pcall(function() (setclipboard or toclipboard)(txt) end)
    b.Text = ok and "✅ copiado! cole no chat" or "❌ sem setclipboard: use SALVAR"
    task.delay(2.5, function() b.Text = "📋 COPIAR RESUMO" end)
end)
btn(114, "💾 SALVAR completo", Color3.fromRGB(200, 120, 30), function(b)
    local ok = pcall(function() writefile("modvip_espiao_mobile.txt", buildSummary(true)) end)
    b.Text = ok and "✅ salvo: modvip_espiao_mobile.txt" or "❌ erro ao salvar"
    task.delay(2.5, function() b.Text = "💾 SALVAR completo" end)
end)

-- arrastar pelo titulo (toque e mouse)
local dragging, dragStart, startPos
title.Active = true
title.InputBegan:Connect(function(i)
    if i.UserInputType == Enum.UserInputType.Touch or i.UserInputType == Enum.UserInputType.MouseButton1 then
        dragging, dragStart, startPos = true, i.Position, f.Position
    end
end)
con(UIS.InputChanged, function(i)
    if dragging and (i.UserInputType == Enum.UserInputType.Touch or i.UserInputType == Enum.UserInputType.MouseMovement) then
        local d = i.Position - dragStart
        f.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + d.X, startPos.Y.Scale, startPos.Y.Offset + d.Y)
    end
end)
con(UIS.InputEnded, function(i)
    if i.UserInputType == Enum.UserInputType.Touch or i.UserInputType == Enum.UserInputType.MouseButton1 then dragging = false end
end)

local function count(t) local n = 0 for _ in pairs(t) do n = n + 1 end return n end
task.spawn(function()
    while gui.Parent do
        status.Text = (on and "🔴 espionando " or "⚪ parado ") .. ("%.0fs"):format(on and (tick() - t0) or 0)
            .. ("\nlinks %d | comandos %d | prompts %d\nteleportes %d | vel max %.0f"):format(
                count(R.urls), count(R.sent), count(R.prompts), R.tp.n, R.speed.max)
            .. "\n" .. table.concat(hookStatus, " | "):sub(1, 120)
        task.wait(0.5)
    end
end)

G.ESPIAO99_STOP = function()
    on = false
    G.ESPIAO99_NC = nil
    G.ESPIAO99_CBS = nil
    for _, c in ipairs(conns) do pcall(function() c:Disconnect() end) end
    pcall(function() gui:Destroy() end)
end
print("[99NS22] espiao mobile carregado")
