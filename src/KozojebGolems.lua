-- Opt-in obsluga golemow. Zawsze dolaczana do glownego skryptu przez build.py.
-- Decyzje uzywaja GMCP i tekstu gry; nie komunikuja sie z innymi profilami.
do
local K = kozojeb
local A = K.golemApi
local G = {}
K.G = G
local ordinal = {"pierwszym", "drugim", "trzecim", "czwartym"}
local function enabled() return K.config.golemsEnabled == true end
local function fresh()
  return enabled() and K.enabled and not K.sessionBlocked and K.entitiesReady
    and not K.roomChangePending and K.sessionFresh.entities
end
local function golem(entity)
  return A.liveNpc(entity) and A.normal(entity.name):match("%f[%a]golem%f[%A]") ~= nil
end
local function golems()
  local result, others = {}, 0
  for _, entity in ipairs(A.entities()) do
    if golem(entity) then result[#result + 1] = entity
    elseif A.liveNpc(entity) then others = others + 1 end
  end
  return result, others
end
local function cancel(name)
  if G[name] then pcall(killTimer, G[name]); G[name] = nil end
end
function G.cancel() cancel("timer"); cancel("shieldTimer") end
function G.reset() G.cancel(); G.job, G.wait, G.planCache = nil, nil, nil end
local function later(seconds, callback)
  cancel("timer")
  local job, generation = G.job, K.generation
  G.timer = tempTimer(seconds, function()
    G.timer = nil
    if G.job ~= job or generation ~= K.generation or not K.enabled then return end
    callback(job)
    if K.enabled then A.queue() end
  end)
end
function G.fullHp() return enabled() end
function G.busy()
  return enabled() and G.job ~= nil and G.job.phase ~= "done"
    and A.room() == tonumber(K.config.startRoom)
end
function G.allowRoom(count)
  if not enabled() or not K.entitiesReady then return false end
  local list, others = golems()
  return others == 0 and #list > 0 and #list <= 4 and #list == count
    and #list <= #A.group().members
end
function G.encounter()
  if not fresh() or not K.combatRoomReady or not K.sessionFresh.combat then return false end
  local list, others = golems()
  if #list == 0 or #list > 4 or others > 0 then return false end
  local snapshot = A.snapshot()
  for _, member in ipairs(A.group().members) do
    local incoming = snapshot.incoming[tostring(member.id)]
    if incoming and incoming.count > 0 then return true end
  end
  return false
end
local function health(entity)
  local context = A.group()
  local value = A.health(entity, context.memberVitals[tostring(entity.id)]
    or context.memberVitals[A.normal(entity.name)])
  local percent = value and value.hp * 100 / value.maxhp or nil
  if percent and A.isSelf(entity) then percent = math.min(percent, K.lastHp) end
  return percent
end
local function selectedProjection(own, target, npc, rotation)
  local hp, ownHp = health(target), health(own)
  if not hp or not ownHp or ownHp < math.max(K.config.shieldSelfHp, K.config.escapeHp + 15)
      or ownHp <= 0 or hp <= 0 then return end
  if rotation then
    if ownHp - hp < K.config.golemHpGap then return end
    local ownBudget, targetBudget = A.pair(own, target)
    if not ownBudget or ownBudget < targetBudget * 1.15 then return end
  elseif ownHp + K.config.golemHpGap < hp then return end
  local owners = A.snapshot().owners[tostring(npc.id)]
  local owner = owners and next(owners)
  if owner ~= tostring(target.id) or next(owners, owner) ~= nil then return end
  return A.projection(own, target, hp, tostring(npc.id), rotation)
end
function G.project(own, target)
  if not own or not target then return end
  local incoming = A.snapshot().incoming[tostring(target.id)]
  local list = golems()
  for _, npc in ipairs(list) do
    if incoming and incoming.npcs[tostring(npc.id)] then
      local result = selectedProjection(own, target, npc, false)
        or selectedProjection(own, target, npc, true)
      if result then return result end
    end
  end
end
local function plans()
  local key = table.concat({K.combatRevision, K.dataRevision, K.config.golemHpGap,
    K.config.shieldSelfHp, K.config.shieldMaxAttackers, K.config.escapeHp,
    math.floor(A.now() * 2)}, ":")
  if G.planCache and G.planCache.key == key then return G.planCache.value end
  K.metrics.golemPlans = (K.metrics.golemPlans or 0) + 1
  local context, snapshot = A.group(), A.snapshot()
  local players, loads, npcs, order, assignments, assigned = {}, {}, golems(), {}, {}, {}
  for index, npc in ipairs(npcs) do order[tostring(npc.id)] = ordinal[index] end
  table.sort(npcs, function(a, b) return tostring(a.id) < tostring(b.id) end)
  for _, member in ipairs(context.members) do
    local id, hp = tostring(member.id), health(member)
    if hp and hp > 0 then
      players[#players + 1] = member
      loads[id] = snapshot.incoming[id] and snapshot.incoming[id].count or 0
    end
  end
  table.sort(players, function(a, b) return tostring(a.id) < tostring(b.id) end)
  local used = {}
  -- Wirtualny podzial daje kazdemu profilowi ten sam osobny cel juz przy
  -- pierwszym stanie 4 -> prowadzacy. Nie zakladamy wspolnego timera/IPC.
  for _ = 1, math.min(3, #players - 1) do
    local best
    for _, target in ipairs(players) do
      local targetId = tostring(target.id)
      for _, own in ipairs(players) do
        local ownId = tostring(own.id)
        if ownId ~= targetId and not assigned[ownId] and loads[targetId] > loads[ownId] + 1 then
          for _, npc in ipairs(npcs) do
            local id = tostring(npc.id)
            if not used[id] and snapshot.incoming[targetId] and snapshot.incoming[targetId].npcs[id]
                and selectedProjection(own, target, npc, false) then
              local score = (loads[targetId] - loads[ownId]) * 1000 + health(own) - health(target)
              if not best or score > best.score then
                best = {own=own, target=target, npcId=id, ordinal=order[id], score=score}
              end
            end
          end
        end
      end
    end
    if not best then break end
    local ownId, targetId = tostring(best.own.id), tostring(best.target.id)
    assignments[ownId], assigned[ownId], used[best.npcId] = best, true, true
    loads[ownId], loads[targetId] = loads[ownId] + 1, loads[targetId] - 1
  end
  if next(assignments) then G.planCache={key=key,value=assignments}; return assignments end
  -- Przy wyrownanej liczbie NPC tylko jedna rotacja ku wyzszemu % HP.
  -- Warunek porownywalnych surowych HP chroni postac o mniejszej puli zycia.
  local best
  for _, target in ipairs(players) do
    for _, own in ipairs(players) do
      if own ~= target then
        for _, npc in ipairs(npcs) do
          local incoming = snapshot.incoming[tostring(target.id)]
          if incoming and incoming.npcs[tostring(npc.id)]
              and selectedProjection(own, target, npc, true) then
            local score = health(own) - health(target)
            if not best or score > best.score then
              best = {own=own, target=target, npcId=tostring(npc.id),
                ordinal=order[tostring(npc.id)], rotation=true, score=score}
            end
          end
        end
      end
    end
  end
  if best then assignments[tostring(best.own.id)] = best end
  G.planCache={key=key,value=assignments}
  return assignments
end
function G.shield()
  if not G.encounter() then cancel("shieldTimer"); G.wait=nil; return false end
  if A.isFollower() and K.config.role ~= "zaslony" then return true end
  local own = A.group().self
  local assignments = plans()
  local plan = own and assignments[tostring(own.id)]
  if plan then
    cancel("shieldTimer"); G.wait=nil
    A.shield(plan.target, health(plan.target), 100, plan)
  elseif next(assignments) and own then
    -- Brak raportow o wlaczeniu innych profili: po krotkim czasie mozliwy
    -- jest lokalny plan awaryjny, ponownie oceniony na aktualnym GMCP.
    local key = A.snapshot().signature
    if not G.wait or G.wait.key ~= key then
      cancel("shieldTimer")
      G.wait = {key=key, at=A.now() + 0.9}
      local wait, generation = G.wait, K.generation
      G.shieldTimer = tempTimer(0.9, function()
        G.shieldTimer=nil
        if G.wait == wait and K.enabled and K.generation == generation then A.queue() end
      end)
    elseif A.now() >= G.wait.at then
      local list = golems()
      for _, target in ipairs(A.group().members) do
        if tostring(target.id) ~= tostring(own.id) then
          for index, npc in ipairs(list) do
            if selectedProjection(own, target, npc, false) then
              A.shield(target, health(target), 100, {npcId=tostring(npc.id), ordinal=ordinal[index]})
              return true
            end
          end
        end
      end
    end
  end
  return true
end
local function finishCargo(job)
  cancel("timer")
  job.phase = "done"
  A.note("Golemy: pancerze obsluzone. Czekam na 100% HP calej druzyny.", "green")
end
local amounts = {jeden=1,jedna=1,dwa=2,dwie=2,trzy=3,cztery=4,piec=5,szesc=6,
  siedem=7,osiem=8,dziewiec=9,dziesiec=10,jedenascie=11,dwanascie=12,trzynascie=13,
  czternascie=14,pietnascie=15,szesnascie=16,siedemnascie=17,osiemnascie=18,
  dziewietnascie=19,dwadziescia=20,trzydziesci=30,czterdziesci=40,piecdziesiat=50}
local function armorAmount(text)
  if not text:find("powyginan",1,true) then return nil end
  if text:find("pancerz plytowy",1,true) then return 1 end
  local first,second=text:match("^%S+%s+(%S+)%s+(%S+)")
  local amount=tonumber(first) or amounts[first]
  if amount and amount >= 20 and amounts[second] and amounts[second] < 10 then amount=amount+amounts[second] end
  if amount and amount >= 1 and amount <= 64 and amount == math.floor(amount) then return amount end
end
local function cargoWait(job, message)
  cancel("timer")
  job.phase="cargo_uncertain"
  A.note("Golemy: " .. message .. " Czekam z pancerzami; patrol pozostaje wstrzymany.","yellow")
end
local function returnHome(job)
  cancel("timer")
  job.phase = "return"
  if K.mode ~= "escape" and K.mode ~= "heal_rest" and K.mode ~= "recovery_return" then
    K.escape("Golemy: pokoj oczyszczony. Wracam z pancerzami do kozobazy.")
  end
end
function G.inspect()
  if not fresh() or A.isFollower() then return false end
  if K.mode == "panic_wait" or K.mode == "panic_search" or K.mode == "idle_return"
      or K.mode == "leader_wait" or K.mode == "returning" then return false end
  local list, others = golems()
  local job = G.job
  if not job and #list > 0 and #list <= 4 and others == 0
      and K.mode ~= "escape" and K.mode ~= "heal_rest" and K.mode ~= "recovery_return" then
    job = {room=A.room(), expected=#list, picked=0, remaining=0, bagged=0,
      extraCargo=0, attempts=0, phase="battle"}
    G.job = job
  end
  if not job or job.phase == "done" then return false end
  if #list > 0 and (not K.combatRoomReady or not K.sessionFresh.combat) then return false end
  if G.encounter() and A.room() == job.room then job.hadCombat=true end
  local atBase = A.room() == tonumber(K.config.startRoom)
  local recovery = K.mode == "escape" or K.mode == "heal_rest" or K.mode == "recovery_return"
  if (job.phase == "pickup" or job.phase == "settle" or job.phase == "collect")
      and (recovery or A.room() ~= job.room) then returnHome(job) end
  if (job.phase == "pickup" or job.phase == "settle") and not G.timer then job.phase="collect" end
  if (job.phase == "search_wait" or job.phase == "drop_wait") and not G.timer then job.phase="search" end
  if (job.phase == "bag_open" or job.phase == "bag_wait") and not G.timer then job.phase="search" end
  if job.phase == "battle" then
    if recovery or A.room() ~= job.room then returnHome(job)
    elseif job.hadCombat and #list == 0 and not A.threat() then
      job.phase="settle"
      K.mode="golem_loot"
      later(0.4, function(j) j.phase="collect" end)
    else return false end
  end
  if A.threat() then return false end
  if job.phase == "settle" or job.phase == "pickup" then return true end
  if job.phase == "collect" then
    if A.room() ~= job.room or recovery then returnHome(job)
    elseif job.picked >= job.expected or job.attempts >= job.expected + 1 then returnHome(job)
    else
      K.mode="golem_loot"
      job.phase, job.attempts, job.empty = "pickup", job.attempts + 1, nil
      later(1.6, function(j)
        -- Ujemny tekst moze pochodzic z cudzych triggerow lootu. Brak
        -- potwierdzenia ma ograniczony czas i najwyzej jedna powtorke.
        if j.retried then j.phase="return_requested"
        else j.retried=true; j.phase="collect" end
      end)
      send("wez pancerz")
      return true
    end
  end
  if job.phase == "return_requested" then returnHome(job) end
  if job.phase == "return" then
    if not atBase then
      if not recovery then returnHome(job) end
      return false
    end
    if K.mode ~= "heal_rest" then
      if not recovery then K.escape("Golemy: obsluga pancerzy i wspolny odpoczynek w kozobazie.") end
      return false
    end
    job.remaining, job.phase = job.picked + (job.uncertainPickup or 0) + (job.extraCargo or 0), "search"
    job.cargoReady=true
  end
  if atBase and job.cargoReady and not recovery then
    K.escape("Golemy: wracam do obslugi pozostalych pancerzy przed wznowieniem patrolu.")
    return true
  end
  if not atBase or K.mode ~= "heal_rest" then return false end
  if (job.phase == "search" or job.phase == "drop") and (job.bagged or 0) > 0 then
    job.phase="bag_open"
    later(0.3,function(j) j.phase="bag_take" end)
    send("otworz swoj plecak")
    return true
  elseif job.phase == "bag_take" then
    job.phase="bag_wait"
    later(3,function(j) cargoWait(j,"Brak potwierdzenia wyjecia pancerzy z plecaka.") end)
    send("wez pancerze z plecaka")
    return true
  end
  if job.phase == "search" then
    if job.remaining <= 0 then finishCargo(job); return false end
    job.phase = "search_wait"
    later(45, function(j)
      j.phase="search_uncertain"
      A.note("Golemy: brak potwierdzenia przeszukiwania. Czekam na odpowiedz; zadanie zachowane na ponowne polaczenie.", "yellow")
    end)
    send("przeszukaj pancerz")
  elseif job.phase == "drop" then
    job.phase="drop_wait"
    later(4, function(j)
      j.phase="drop_uncertain"
      A.note("Golemy: brak potwierdzenia odlozenia. Nie ponawiam komendy; zadanie zachowane na ponowne polaczenie.", "yellow")
    end)
    send("odloz pancerz")
  end
  return true
end
function G.onText(line)
  local job = G.job
  if not enabled() or not K.enabled or K.sessionBlocked or A.isFollower() or not job then return end
  local text = A.normal(line)
  local armor = text:find("pancerz", 1, true) ~= nil and text:find("powyginan",1,true) ~= nil
  local amount=armor and armorAmount(text)
  local fromBag=armor and text:match("^bierzesz ") and text:find("plecaka",1,true)
  if fromBag then
    if not amount then cargoWait(job,"Nieznana liczba pancerzy wyjmowanych z plecaka."); return end
    local known=math.min(job.bagged or 0,amount)
    job.bagged=math.max(0,(job.bagged or 0)-amount)
    local extra=amount-known
    if job.cargoReady then job.remaining=job.remaining+extra
    else job.extraCargo=(job.extraCargo or 0)+extra end
    if job.phase=="bag_open" or job.phase=="bag_take" or job.phase=="bag_wait"
        or job.phase=="cargo_uncertain" or job.phase=="done" then
      cancel("timer"); job.phase="search"
    end
  elseif armor and text:match("^wkladasz ") and text:find("plecaka",1,true) then
    if not amount then cargoWait(job,"Nieznana liczba pancerzy wkladanych do plecaka."); return end
    job.bagged=(job.bagged or 0)+amount
    if job.cargoReady and job.remaining < job.bagged then job.remaining=job.bagged end
    if job.phase=="done" then job.phase="search" end
  elseif armor and amount and text:match("^bierzesz ")
      and (A.room() == job.room or (job.cargoReady and A.room() == tonumber(K.config.startRoom))) then
    job.picked = job.picked + amount
    if job.cargoReady then job.remaining=job.remaining+amount end
    if job.phase == "pickup" then cancel("timer"); job.phase="collect"; job.retried=nil end
    if job.phase == "done" or job.phase == "cargo_uncertain" then job.phase="search" end
  elseif text == "wez co?" and job.phase == "pickup" then job.empty=true
  elseif (job.phase == "search_wait" or job.phase == "search_uncertain") and armor and text:match("^przestajesz przeszukiwac ") then
    cancel("timer"); job.phase="drop"
  elseif (job.phase == "search_wait" or job.phase == "search_uncertain") and text == "przeszukaj co?" then
    if (job.bagged or 0)>0 then cancel("timer"); job.phase="search"
    elseif job.remaining>0 then cargoWait(job,"Brakuje pancerza, ktory nadal jest zapisany w ladunku.")
    else finishCargo(job) end
  elseif (job.phase == "drop_wait" or job.phase == "drop_uncertain")
      and ((armor and text:match("^odkladasz ")) or text == "odloz co?") then
    if text=="odloz co?" then
      if (job.bagged or 0)>0 then cancel("timer"); job.phase="search"
      else cargoWait(job,"Brak potwierdzenia odlozenia pancerza.") end
    elseif amount then cancel("timer"); job.remaining,job.phase=math.max(0,job.remaining-amount),"search"
    else cargoWait(job,"Nieznana liczba odlozonych pancerzy.") end
  else return end
  A.queue()
end
function G.resume()
  local job = G.job
  if not enabled() or not job or A.isFollower() then return false end
  if job.phase == "pickup" or job.phase == "settle" then
    if job.phase == "pickup" then job.uncertainPickup = math.min(job.expected - job.picked, (job.uncertainPickup or 0) + 1) end
    job.phase = A.room() == job.room and "collect" or "return"
  elseif job.phase == "search_wait" or job.phase == "drop_wait"
      or job.phase == "search_uncertain" or job.phase == "drop_uncertain" then
    -- Nie powtarzamy niepotwierdzonego odlozenia: kolejny pancerz musi
    -- przejsc nowe przeszukanie nawet po zerwaniu polaczenia.
    job.phase="search"
  elseif job.phase == "bag_open" or job.phase == "bag_take" or job.phase == "bag_wait"
      or job.phase == "cargo_uncertain" then
    job.phase="search"
  end
  if A.room() == tonumber(K.config.startRoom) and job.phase ~= "battle" then
    if job.phase == "done" then return false end
    A.heal(); A.queue(); return true
  end
  return false
end
function G.started(recovered)
  if G.job and G.job.phase == "done" then G.reset()
  elseif not recovered and not K.enabled then G.reset() end
end
function G.status()
  if not enabled() then return "" end
  local labels={battle="walka",settle="zbieranie",collect="zbieranie",pickup="zbieranie",
    return_requested="powrot",["return"]="powrot",search="przeszukiwanie",search_wait="przeszukiwanie",
    drop="odkladanie",drop_wait="odkladanie",done="odpoczynek",
    bag_open="otwieranie plecaka",bag_take="wyjmowanie pancerzy",bag_wait="wyjmowanie pancerzy",
    cargo_uncertain="brak potwierdzenia pancerzy",
    search_uncertain="brak potwierdzenia przeszukania",drop_uncertain="brak potwierdzenia odlozenia"}
  return string.format("roznica HP %d pp; %s", K.config.golemHpGap,
    G.job and ((labels[G.job.phase] or "oczekiwanie") .. ", pozostalo " .. G.job.remaining
      .. ", w plecaku " .. (G.job.bagged or 0)) or "gotowy")
end
function G.command(rest)
  local action, value = A.normal(rest):match("^(%S*)%s*(.-)$")
  if action == "on" or action == "off" then
    local wanted = action == "on"
    if K.config.golemsEnabled == wanted then
      A.note("Golemy: " .. (wanted and G.status() or "wylaczone"),"cyan"); return
    end
    if K.config.golemsEnabled ~= wanted and K.enabled then K.stop("Zmiana trybu golemow. Uruchom ponownie /kozojeb start.") end
    G.reset()
    K.config.golemsEnabled=wanted
    if wanted then A.ensureTarget() end
    K.saveSettings()
    A.note("Golemy: " .. (wanted and "wlaczone; celowane zaslony, pancerze i odpoczynek calej druzyny do 100% HP." or "wylaczone."), "cyan")
  elseif action == "roznicahp" then
    local gap=tonumber(value)
    if not gap or gap < 5 or gap > 30 or gap ~= math.floor(gap) then
      A.note("Uzycie: /kozojeb golemy roznicahp <5-30> (punkty procentowe).", "yellow"); return
    end
    K.config.golemHpGap=gap; K.saveSettings()
    A.note("Golemy: prog rotacji " .. gap .. " punktow procentowych HP.", "cyan")
  elseif action == "" or action == "status" then
    A.note("Golemy: " .. (enabled() and G.status() or "wylaczone"), "cyan")
  else A.note("Uzycie: /kozojeb golemy on|off|status|roznicahp <5-30>.", "yellow") end
end
K.handlers.triggers[#K.handlers.triggers + 1] = tempRegexTrigger(
  "^(?:Bierzesz .*pancerz.*|Wkladasz .*pancerz.*plecaka\\.|Wez co\\?|Przestajesz przeszukiwac .*pancerz.*|Przeszukaj co\\?|Odkladasz .*pancerz.*|Odloz co\\?)$",
  [[kozojeb.G.onText(matches[1])]])
end
