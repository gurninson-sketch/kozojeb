-- Opt-in obsluga golemow. Zawsze dolaczana do glownego skryptu przez build.py.
-- Decyzje uzywaja GMCP i tekstu gry; nie komunikuja sie z innymi profilami.
do
local K = kozojeb
local A = K.golemApi
local G = {gemShares={}, gemRetryAt={}}
K.G = G
if K.config.golemGemSharing == nil then K.config.golemGemSharing = true end
if type(K.config.golemGemForms) ~= "table" then K.config.golemGemForms = {} end
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
function G.cancel()
  cancel("timer"); cancel("lootTimer")
  if G.job then
    -- A gift may already have reached the server. Never replay it on reconnect.
    G.job.gemDelivery, G.job.gemContinuation = nil, nil
  end
end
function G.reset() G.cancel(); G.job=nil end
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
local function golemCombat()
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
local function finishCargo(job)
  cancel("timer")
  job.phase = "done"
  A.note("Golemy: pancerze obsluzone. Czekam na 100% HP calej druzyny.", "green")
end
local function validName(name)
  return type(name) == "string" and #name <= 40 and name:match("^[a-z][a-z%-]*$")
end
local function giftForm(name)
  if not validName(name) then return nil end
  local form = K.config.golemGemForms[name]
  if validName(form) then return form end
  if name:sub(-1) == "o" then return name:sub(1,-2) .. "owi" end
  if name:match("[bcdfghjklmnpqrstvwxyz]$") then return name .. "owi" end
end
local function gemRecipient()
  local group = A.group()
  if not group.actualLeader or not A.isSelf(group.actualLeader) then return nil end
  local first, nextRecipient
  for _, member in ipairs(group.members) do
    local name = A.normal(member.name)
    local form = giftForm(name)
    if form and member.kind == "player" and not A.isSelf(member)
        and (tonumber(member.hp) or 0) > 0 and not (K.S and K.S.isDead(member))
        and (G.gemRetryAt[name] or 0) <= A.now() then
      local recipient = {name=name, form=form}
      if not first or name < first.name then first = recipient end
      if G.lastGemRecipient and name > G.lastGemRecipient
          and (not nextRecipient or name < nextRecipient.name) then
        nextRecipient = recipient
      end
    end
  end
  return nextRecipient or first
end
local function shareGem(job)
  local item = job.foundGem
  job.foundGem = nil
  if not item or not K.config.golemGemSharing then return false end
  local recipient = gemRecipient()
  if not recipient then return false end
  recipient.item = item
  job.gemDelivery = recipient
  later(3, function(j)
    j.gemDelivery = nil
    G.gemRetryAt[recipient.name] = A.now() + 30
    A.note("Golemy: brak potwierdzenia przekazania kamienia do " .. recipient.name
      .. ". Pomijam tego odbiorce przez 30 s.", "yellow")
  end)
  send("daj kamien " .. recipient.form)
  return true
end
local gemPrefix = "udaje ci sie otworzyc ukryta na piersi zgruchotanego golema klapke i zabierasz znajdujace sie pod"
local gemDescription = "nia zrodlo mocy konstruktu, ([a-z][a-z %-]+)%."
local gemNouns = {
  agat=true, apatyt=true, awenturyn=true, azuryt=true, cyrkon=true, cytryn=true,
  diament=true, diopsyd=true, fluoryt=true, gagat=true, granat=true, hematyt=true,
  jaspis=true, kamien=true, karneol=true, kwarc=true, malachit=true, obsydian=true,
  oliwin=true, onyks=true, ortoklaz=true, turmalin=true, tytanit=true, zoisyt=true,
}
local function confirmedGem(text, delivery)
  local item, recipient = text:match("^dajesz ([a-z][a-z %-]*) ([a-z][a-z%-]*)%.$")
  if not item or recipient ~= delivery.form then return false end
  -- The generic selector can give a previously carried stone.
  if item == delivery.item then return true end
  return not item:find(" i ", 1, true) and gemNouns[item:match("([a-z]+)$")] == true
end
function G.onGemText(line)
  local job = G.job
  if not fresh() or A.isFollower() or not job or A.room() ~= tonumber(K.config.startRoom)
      or K.mode ~= "heal_rest" then return end
  local text = A.normal(line)
  local delivery = job.gemDelivery
  if delivery and confirmedGem(text, delivery) then
    cancel("timer")
    job.gemDelivery = nil
    G.lastGemRecipient = delivery.name
    G.gemShares[delivery.name] = (G.gemShares[delivery.name] or 0) + 1
    A.queue()
    return
  end
  if not K.config.golemGemSharing or job.foundGem
      or (job.phase ~= "search_wait" and job.phase ~= "search_uncertain") then return end
  if text == gemPrefix then
    job.gemContinuation = true
    return
  end
  local item = text:match("^" .. gemPrefix .. " " .. gemDescription .. "$")
  if not item and job.gemContinuation then item = text:match("^" .. gemDescription .. "$") end
  job.gemContinuation = nil
  if item and #item <= 96 then job.foundGem = item end
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
local function rememberPopulation(job,dead)
  job.population=job.population or {}
  for _,npc in ipairs(A.entities()) do
    if npc.kind=="npc" and A.normal(npc.name):match("%f[%a]golem%f[%A]") then
      job.population[tostring(npc.id)]=A.normal(npc.name)
    end
  end
  if dead and dead.id then job.population[tostring(dead.id)]=A.normal(dead.name) end
  local count=0
  for _ in pairs(job.population) do count=count+1 end
  job.expected=math.max(job.expected,count)
end
local function newJob(expected)
  local job={room=A.room(),expected=expected,picked=0,remaining=0,bagged=0,extraCargo=0,
    attempts=0,phase="battle",deaths={},deathRecords={},ambiguousDeaths={},deathCount=0,lootQueue={},consumed=0,unavailable=0}
  rememberPopulation(job)
  return job
end
local function lootLater(seconds,callback)
  cancel("lootTimer")
  local job,generation=G.job,K.generation
  G.lootTimer=tempTimer(seconds,function()
    G.lootTimer=nil
    if G.job~=job or not K.enabled or generation~=K.generation then return end
    callback(job)
    A.queue()
  end)
end
local function finishFast(job)
  if job.lootPending then job.lootPending.done=true;job.lootPending=nil end
  cancel("lootTimer")
end
local function awaitFast(job,pending,external)
  pending.scheduled=nil
  pending.external=external
  pending.waiting=true;pending.tries=(pending.tries or 0)+1
  if external then K.metrics.golemObservedLoot=(K.metrics.golemObservedLoot or 0)+1 end
  lootLater(1.6,function(j)
    if j.lootPending~=pending then return end
    if not pending.lost then j.uncertainPickup=(j.uncertainPickup or 0)+1 end
    finishFast(j)
  end)
end
local function consumeExternal(job)
  local list=job.externalPickups or {}
  while list[1] do
    local at=table.remove(list,1)
    if A.now()-at<=0.25 then return true end
  end
  return false
end
function G.pumpLoot()
  local job=G.job
  if not fresh() or A.isFollower() or not job or job.pickupBlocked or A.room()~=job.room or K.movementRest
      or K.mode=="escape" or K.mode=="heal_rest" or K.mode=="recovery_return" then return end
  while job.lootQueue and job.lootQueue[1] and job.lootQueue[1].done do table.remove(job.lootQueue,1) end
  local pending=job.lootPending
  if not pending then pending=job.lootQueue and job.lootQueue[1];job.lootPending=pending end
  if not pending or pending.waiting or pending.scheduled
      or pending.retryAt and A.now()<pending.retryAt then return end
  if pending.lost then finishFast(job);A.queue();return end
  if consumeExternal(job) then awaitFast(job,pending,true);return end
  -- Dajemy zakonczyc sie triggerom tej samej linii zgonu. Wyslane juz
  -- przez nie wez pancerz przejmuje nasze potwierdzenie zamiast duplikatu.
  pending.scheduled=true
  lootLater(0.05,function(j)
    pending.scheduled=nil
    if j.lootPending~=pending or not fresh() or A.room()~=j.room or K.movementRest
        or K.mode=="escape" or K.mode=="heal_rest" or K.mode=="recovery_return" then return end
    if pending.lost then finishFast(j);return end
    if not A.safety() then return end
    awaitFast(j,pending,false)
    G.sendingLoot=true
    send("wez pancerz")
    G.sendingLoot=nil
  end)
end
function G.onLootCommand(command)
  if G.sendingLoot or type(command)~="string" or #command>64
      or not command:lower():match("^%s*wez%s+pancerz%s*$")
      or not fresh() or A.isFollower() then return end
  local job=G.job
  if not job or job.pickupBlocked or job.phase~="battle" or A.room()~=job.room or K.mode=="escape"
      or K.mode=="heal_rest" or K.mode=="recovery_return" then return end
  local pending=job.lootPending
  if pending and not pending.waiting then
    awaitFast(job,pending,true)
  elseif not pending or pending.external then
    job.externalPickups=job.externalPickups or {}
    if #job.externalPickups<16 then job.externalPickups[#job.externalPickups+1]=A.now() end
  end
end
function G.onKill(name,dead,confirmed,observedId)
  if confirmed or not fresh() or A.isFollower() or K.limitRoom or K.movementRest
      or K.mode=="escape" or K.mode=="heal_rest" or K.mode=="recovery_return"
      or not A.normal(name):match("%f[%a]golem%f[%A]") then return end
  local job=G.job
  local engaged=job and job.hadCombat or golemCombat()
    or (dead and tostring(K.currentTargetId)==tostring(dead.id))
  if not engaged then return end
  if not job then
    local list,others=golems()
    if others>0 or #list>4 then return end
    job=newJob(#list);G.job=job
  end
  if job.room~=A.room() or job.cargoReady or job.phase=="done" then return end
  local id=observedId and tostring(observedId) or dead and tostring(dead.id)
  if id and not dead then dead={id=id,name=name} end
  rememberPopulation(job,dead)
  local key=A.normal(name)
  local record=id and job.deaths[id]
  if not record then
    for _,previous in ipairs(job.deathRecords) do
      if previous.name==key and ((id and not previous.id)
          or (not id and not observedId and not previous.textSeen)) then record=previous break end
    end
  end
  if record then
    if id then record.id=id;job.deaths[id]=record end
    if not observedId then record.textSeen=true end
    return
  end
  if not id then
    local anchored,unbound=false,false
    for _,previous in ipairs(job.deathRecords) do
      if previous.name==key then
        if previous.id then anchored=true else unbound=true end
      end
    end
    if anchored and not unbound then
      local missing={}
      for candidate,populationName in pairs(job.population) do
        if populationName==key and not job.deaths[candidate]
            and not A.liveNpc(A.entity(candidate)) then missing[#missing+1]=candidate end
      end
      if #missing==1 then id=missing[1]
      elseif #missing==0 then
        -- Powtorka opisu po usunieciu znanego ID nie dowodzi drugiego
        -- zgonu. Niejednoznaczna zapowiedz czeka na nowe zerowe HP.
        job.ambiguousDeaths[key]=true
        return
      end
    end
  end
  -- Tekst i GMCP sa dwoma potwierdzeniami tego samego zgonu. Nie tworzymy
  -- klucza z zegara ani nie dodajemy tekstowego zgonu do nadal widocznego
  -- egzemplarza. Kolejne rzeczywiste NPC rozszerzaja zapamietana populacje.
  local capacity,anonymous=0,0
  for _,populationName in pairs(job.population) do if populationName==key then capacity=capacity+1 end end
  for _,previous in ipairs(job.deathRecords) do
    if previous.name==key then anonymous=anonymous+1 end
  end
  if capacity==0 then
    if anonymous>0 then return end
    job.expected=job.expected+1
  elseif anonymous>=capacity then return end
  if job.deathCount>=job.expected then return end
  record={id=id,name=key,textSeen=not observedId or job.ambiguousDeaths[key],key=id or "death:"..tostring(job.deathCount+1)}
  job.ambiguousDeaths[key]=nil
  job.deathRecords[#job.deathRecords+1]=record
  if id then job.deaths[id]=record end
  job.deathCount=job.deathCount+1
  job.hadCombat=true;job.lootQueue=job.lootQueue or {}
  if #job.lootQueue<16 then job.lootQueue[#job.lootQueue+1]=record end
  -- Jedna szybka reakcja na rzeczywisty zgon; bez dodatkowej petli walki.
  if A.safety() then G.pumpLoot() end
end
function G.onConsumed(actor)
  local job=G.job
  if not fresh() or A.isFollower() or not job or job.cargoReady or A.room()~=job.room then return end
  local present=false
  for _,npc in ipairs(golems()) do if A.normal(npc.name)==A.normal(actor) then present=true break end end
  if not present or (job.deathCount or 0)<=job.picked+(job.consumed or 0) then return end
  local key=A.normal(actor)..":"..tostring(job.deathCount)
  if job.lastConsumed==key then return end
  job.lastConsumed=key;job.consumed=(job.consumed or 0)+1
  if job.lootPending then job.lootPending.lost=true end
  A.note("Golemy: zywy golem spalil pancerz z ziemi; nie doliczam go do zebranego ladunku.","yellow")
  A.queue()
end
function G.actionBusy()
  local phase=G.job and G.job.phase
  return enabled() and (phase=="search_wait" or phase=="search_uncertain" or G.job and G.job.gemDelivery ~= nil)
end
function G.inspect()
  if not fresh() or A.isFollower() then return false end
  if K.mode == "panic_wait" or K.mode == "panic_search" or K.mode == "idle_return"
      or K.mode == "leader_wait" or K.mode == "returning" then return false end
  local list, others = golems()
  local job = G.job
  if not job and #list > 0 and #list <= 4 and others == 0
      and K.mode ~= "escape" and K.mode ~= "heal_rest" and K.mode ~= "recovery_return" then
    job = newJob(#list)
    G.job = job
  end
  if not job or job.phase == "done" then return false end
  if A.room()==job.room and job.phase=="battle" then
    rememberPopulation(job)
    if next(job.ambiguousDeaths) then
      for id,name in pairs(job.population) do
        local npc=A.entity(id)
        if job.ambiguousDeaths[name] and not job.deaths[id] and npc and tonumber(npc.hp)==0 then
          G.onKill(name,npc,false,id)
        end
      end
    end
  end
  if #list > 0 and (not K.combatRoomReady or not K.sessionFresh.combat) then return false end
  if golemCombat() and A.room() == job.room then job.hadCombat=true end
  local atBase = A.room() == tonumber(K.config.startRoom)
  local recovery = K.mode == "escape" or K.mode == "heal_rest" or K.mode == "recovery_return"
  if not recovery and A.room()==job.room then
    G.pumpLoot()
    if job.lootPending and #list==0 and not A.threat() then return true end
  end
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
    elseif job.pickupBlocked or job.picked+(job.consumed or 0)+(job.unavailable or 0) >= job.expected
        or job.attempts >= job.expected + 1 then returnHome(job)
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
    job.remaining, job.phase = math.max(job.bagged or 0,
      job.picked + (job.uncertainPickup or 0) + (job.extraCargo or 0)), "search"
    job.cargoReady=true
  end
  if atBase and job.cargoReady and not recovery then
    K.escape("Golemy: wracam do obslugi pozostalych pancerzy przed wznowieniem patrolu.")
    return true
  end
  if not atBase or K.mode ~= "heal_rest" then return false end
  if job.gemDelivery then return true end
  if job.phase == "drop" and shareGem(job) then return true end
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
    job.gemContinuation = nil
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
  if armor and text:match(" jest zbyt ciezki%.$") then
    if job.phase == "bag_wait" and A.room() == tonumber(K.config.startRoom) then
      cargoWait(job,"Pancerz w plecaku jest zbyt ciezki do wyjecia.")
      A.queue()
    elseif A.room() == job.room and not job.pickupBlocked
        and (job.phase == "battle" or job.phase == "pickup") then
      job.pickupBlocked = true
      finishFast(job)
      if job.phase == "pickup" then cancel("timer"); job.phase="return_requested" end
      A.note("Golemy: pancerz jest zbyt ciezki. Po walce wracam z dotychczas zebranymi pancerzami.", "yellow")
      A.queue()
    end
    return
  end
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
    if job.lootPending then finishFast(job) end
    if job.cargoReady then job.remaining=job.remaining+amount end
    if job.phase == "pickup" then cancel("timer"); job.phase="collect"; job.retried=nil end
    if job.phase == "done" or job.phase == "cargo_uncertain" then job.phase="search" end
    if job.phase=="battle" then G.pumpLoot() end
  elseif text=="wez co?" and job.lootPending then
    local pending=job.lootPending
    if not pending.waiting then return end
    cancel("lootTimer")
    if pending.lost or pending.tries>=2 then
      if not pending.lost then job.unavailable=(job.unavailable or 0)+1 end
      finishFast(job)
    else
      pending.waiting=false;pending.retryAt=A.now()+0.3
      lootLater(0.3,function() end)
    end
  elseif text == "wez co?" and job.phase == "pickup" then job.empty=true
  elseif (job.phase == "search_wait" or job.phase == "search_uncertain") and armor and text:match("^przestajesz przeszukiwac ") then
    cancel("timer"); job.phase="drop"; job.gemContinuation=nil
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
  if job.lootPending then
    if job.lootPending.waiting then
      if not job.lootPending.lost then job.uncertainPickup=(job.uncertainPickup or 0)+1 end
      finishFast(job)
    else
      job.lootPending.scheduled=nil;job.lootPending.retryAt=nil;job.lootPending=nil
    end
  end
  job.externalPickups=nil
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
  if job.phase=="battle" and A.room()==job.room then G.pumpLoot() end
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
  return G.job and ((labels[G.job.phase] or "oczekiwanie") .. ", pozostalo "
      .. (G.job.cargoReady and G.job.remaining or G.job.picked+(G.job.extraCargo or 0))
      .. ", w plecaku " .. (G.job.bagged or 0)) or "gotowy"
end
local function gemCommand(value)
  local action, rest = value:match("^(%S*)%s*(.-)$")
  if action == "on" or action == "off" then
    K.config.golemGemSharing = action == "on"
  elseif action == "odmiana" then
    local name, form = rest:match("^(%S+)%s+(%S+)$")
    if not validName(name) or not validName(form) then
      A.note("Uzycie: /kozojeb golemy kamienie odmiana <imie> <celownik>.", "yellow")
      return
    end
    K.config.golemGemForms[name] = form
  elseif action ~= "" and action ~= "status" then
    A.note("Uzycie: /kozojeb golemy kamienie on|off|status|odmiana <imie> <celownik>.", "yellow")
    return
  end
  local shares = {}
  for name, count in pairs(G.gemShares) do shares[#shares + 1] = name .. " " .. count end
  table.sort(shares)
  A.note("Golemy: podzial kamieni " .. (K.config.golemGemSharing and "on" or "off")
    .. "; przekazano " .. (#shares > 0 and table.concat(shares, ", ") or "0") .. ".", "cyan")
end
function G.command(rest)
  local action, value = A.normal(rest):match("^(%S*)%s*(.-)$")
  if action=="filtr" and K.F then
    K.F.lootCommand(value)
  elseif action == "kamienie" then
    gemCommand(value)
  elseif action == "on" or action == "off" then
    local wanted = action == "on"
    if K.config.golemsEnabled == wanted then
      A.note("Golemy: " .. (wanted and G.status() or "wylaczone"),"cyan"); return
    end
    if K.config.golemsEnabled ~= wanted and K.enabled then K.stop("Zmiana trybu golemow. Uruchom ponownie /kozojeb start.") end
    G.reset()
    K.config.golemsEnabled=wanted
    if wanted then A.ensureTarget() end
    K.saveSettings()
    A.note("Golemy: " .. (wanted and "wlaczone. Pancerze, kamienie i odpoczynek druzyny w bazie." or "wylaczone."), "cyan")
  elseif action == "roznicahp" and K.C then
    K.C.setGap(value)
  elseif action == "" or action == "status" then
    A.note("Golemy: " .. (enabled() and G.status() or "wylaczone"), "cyan")
  else A.note("Uzycie: /kozojeb golemy on|off|status|kamienie|filtr.", "yellow") end
end
K.handlers.triggers[#K.handlers.triggers + 1] = tempRegexTrigger(
  "^(?:Bierzesz .*pancerz.*|Wkladasz .*pancerz.*plecaka\\.|Wez co\\?|Przestajesz przeszukiwac .*pancerz.*|Przeszukaj co\\?|Odkladasz .*pancerz.*|Odloz co\\?|\\s*(?:Zniszczony )?[Pp]owyginany pancerz plytowy jest zbyt ciezki\\.\\s*)$",
  [[kozojeb.G.onText(matches[1])]])
K.handlers.triggers[#K.handlers.triggers + 1] = tempRegexTrigger(
  "^(?:Udaje ci sie otworzyc ukryta na piersi zgruchotanego golema klapke i zabierasz znajdujace sie pod.*|nia zrodlo mocy konstruktu, [a-z -]+\\.|Dajesz [a-zA-Z -]+\\.)\\s*$",
  [[kozojeb.G.onGemText(matches[1])]])
K.handlers.triggers[#K.handlers.triggers + 1] = tempRegexTrigger(
  "^(.+) zbliza sie do powyginanego pancerza plytowego, podnosi go i wciska do",
  [[kozojeb.G.onConsumed(matches[2])]])
end
