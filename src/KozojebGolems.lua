-- Opt-in obsluga golemow. Zawsze dolaczana do glownego skryptu przez build.py.
-- Decyzje uzywaja GMCP i tekstu gry; nie komunikuja sie z innymi profilami.
do
local K = kozojeb
local A = K.golemApi
local G = {holds={}, failures={}, selectors={}, forms={}, unavailable={}, combatEpoch=0}
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
function G.cancel() cancel("timer"); cancel("shieldTimer"); cancel("lootTimer") end
function G.resetCombat()
  cancel("shieldTimer")
  G.holds,G.failures,G.selectors,G.wait,G.planCache,G.combatRoom={},{},{},nil,nil,nil
  G.unavailable={}
  G.mappingWarning=nil
  G.forms={}
  G.combatEpoch=G.combatEpoch+1
end
function G.reset() G.cancel(); G.job=nil; G.resetCombat() end
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
  if G.combatRoom~=A.room() then G.resetCombat(); G.combatRoom=A.room() end
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
local function byName(a,b)
  local first,second=A.normal(a.name),A.normal(b.name)
  if first~=second then return first<second end
  return tostring(a.id)<tostring(b.id)
end
local function urgent(target)
  local hp=health(target)
  return hp and hp<=math.max(K.config.escapeHp,K.config.teamEscapeHp)+15
end
local function instrument(name)
  if G.forms[name]~=nil then return G.forms[name] or nil end
  local words={}
  for word in A.normal(name):gmatch("%S+") do
    if not word:match("^[a-z%-]+$") then return end
    if word=="golem" then words[#words+1]="golemem"
    elseif word:match("y$") then words[#words+1]=word:gsub("y$","ym")
    elseif word:match("i$") then words[#words+1]=word:gsub("i$","im")
    else return end
  end
  if #words<2 or #words>6 or words[#words]~="golemem" then return end
  local result=table.concat(words," ")
  G.forms[name]=result
  return result
end
function G.selector(id,target)
  local list=golems()
  local selected
  for _,npc in ipairs(list) do if tostring(npc.id)==tostring(id) then selected=npc break end end
  if not selected then return end
  local name=A.normal(selected.name)
  local phrase=instrument(name)
  if not phrase then return end
  local same=A.commandPeers(selected)
  local count,index,allowed=#same,nil,nil
  for position,npc in ipairs(same) do
    if tostring(npc.id)==tostring(id) then index=position end
  end
  if count>1 then
    -- Rowniez przestawione przymiotniki moga wskazywac ten sam zbior NPC.
    -- Dopuszczamy go tylko, gdy wszystkie egzemplarze atakuja te osobe;
    -- odpowiedz gry nadal rozstrzyga faktyczne ID zaslonietego napastnika.
    if not index or not ordinal[index] then return end
    allowed={}
    for _,npc in ipairs(same) do
      local owners=A.snapshot().owners[tostring(npc.id)]
      local owner=owners and next(owners)
      if not target or owner~=tostring(target.id) or next(owners,owner)~=nil then return end
      allowed[tostring(npc.id)]=true
    end
    phrase=ordinal[index] .. " " .. phrase
  end
  if (G.selectors[phrase] or 0)>A.now() then return end
  return phrase,allowed
end
local function pruneLocks()
  local active={}
  for _,npc in ipairs(golems()) do active[tostring(npc.id)]=true end
  for id,hold in pairs(G.holds) do
    if not active[id] or hold.untilTime<=A.now() then G.holds[id]=nil end
  end
  for key,failure in pairs(G.failures) do
    if not active[failure.npcId] or failure.untilTime<=A.now() then G.failures[key]=nil end
  end
  for id,deadline in pairs(G.unavailable) do
    if deadline<=A.now() then G.unavailable[id]=nil end
  end
end
local function selectedProjection(own, target, npc, rotation)
  local function blocked(code,detail)
    if K.combatLog and A.isSelf(own) then K.combatLog.reason(target,npc.id,code,rotation,detail) end
  end
  if not A.canShield(own) or tostring(own.id)==tostring(target.id) then return blocked("role_or_self") end
  if not A.isSelf(own) and (G.unavailable[tostring(own.id)] or 0)>A.now() then return blocked("peer_formation_busy") end
  local snapshot=A.snapshot()
  local incoming=snapshot.incoming[tostring(target.id)]
  local generic=not G.selector(npc.id,target)
  -- Ogolna komenda jest rownowazna wskazaniu ID tylko przy jednym
  -- napastniku. Przy kilku nadal nie zgadujemy podzbioru przejecia.
  if generic and (not incoming or incoming.count~=1) then return blocked("ambiguous_selector") end
  local hp, ownHp = health(target), health(own)
  if not hp or not ownHp or ownHp < math.max(K.config.shieldSelfHp, K.config.escapeHp + 15)
      or ownHp <= 0 or hp <= 0 then return blocked("unknown_or_low_hp") end
  if rotation then
    if ownHp - hp < K.config.golemHpGap then return blocked("hp_gap") end
    local ownBudget, targetBudget = A.pair(own, target)
    local ownIncoming=snapshot.incoming[tostring(own.id)]
    local margin=not ownIncoming or ownIncoming.count==0
    margin=margin and 1.05 or 1.15
    if not ownBudget or ownBudget < targetBudget * margin then return blocked("hp_reserve") end
  elseif ownHp + K.config.golemHpGap < hp then return blocked("own_hp_disadvantage") end
  local owners = snapshot.owners[tostring(npc.id)]
  local owner = owners and next(owners)
  if owner ~= tostring(target.id) or next(owners, owner) ~= nil then return blocked("npc_not_exclusive") end
  local id=tostring(npc.id)
  local hold=G.holds[id]
  if hold and hold.confirming and hold.untilTime>A.now() then return blocked("await_cover_confirmation",hold.untilTime) end
  if not urgent(target) then
    local transfer,failure=K.shieldTransfers[id],G.failures[id..":"..tostring(target.id)]
    if hold and hold.untilTime>A.now() then return blocked("cover_hold",hold.untilTime) end
    if transfer and transfer.untilTime>A.now() then return blocked("transfer_hold",transfer.untilTime) end
    if failure and failure.untilTime>A.now() then return blocked("previous_failure",failure.untilTime) end
  end
  if A.isSelf(own) and (K.shieldPositionUntil[A.form(target.name) or ""] or 0)>A.now() then return blocked("position_blocked") end
  local result,reason=A.projection(own, target, hp, tostring(npc.id), rotation, urgent(target))
  if not result then blocked("unsafe_projection",reason) end
  return result,generic
end
local function candidate(own,target,npc,rotation)
  local result,generic=selectedProjection(own,target,npc,rotation)
  if result then
    return {own=own,target=target,npcId=tostring(npc.id),rotation=rotation,generic=generic},result
  end
end
function G.validatePlan(own,target,plan)
  if not G.encounter() or not own or not target then return end
  local npc=A.entity(plan.npcId)
  if not npc or not golem(npc) then return end
  local incoming=A.snapshot().incoming[tostring(target.id)]
  if plan.generic and (not incoming or incoming.count~=1 or not incoming.npcs[tostring(npc.id)]) then return end
  local result,generic=selectedProjection(own,target,npc,plan.rotation)
  if generic and not plan.generic then return end
  return result
end
function G.project(own, target)
  if not own or not target then return end
  local incoming = A.snapshot().incoming[tostring(target.id)]
  local list = golems()
  for _, npc in ipairs(list) do
    if incoming and incoming.npcs[tostring(npc.id)] then
      local plan,result=candidate(own,target,npc,false)
      if not plan then plan,result=candidate(own,target,npc,true) end
      if plan then return result,plan end
    end
  end
  -- Niejednoznaczne egzemplarze nie uzasadniaja oceny pojedynczego NPC
  -- przy ogolnej komendzie: wowczas liczymy mozliwe przejecie wszystkich.
  if A.canShield(own) then return A.projection(own,target,health(target)) end
end
local function plans()
  pruneLocks()
  local context,snapshot=A.group(),A.snapshot()
  local parts={snapshot.signature}
  for _,member in ipairs(context.members) do
    local value=A.health(member,context.memberVitals[tostring(member.id)] or context.memberVitals[A.normal(member.name)])
    local history=K.healthHistory[tostring(member.id)]
    parts[#parts+1]=table.concat({tostring(member.id),A.normal(member.name),value and value.hp or "?",
      value and value.maxhp or "?",history and history.debt or 0},"/")
  end
  table.sort(parts)
  local key = table.concat({table.concat(parts,"|"),G.combatEpoch,K.lastHp,K.config.golemHpGap,
    K.config.shieldSelfHp, K.config.shieldMaxAttackers, K.config.escapeHp,K.config.teamEscapeHp,
    math.floor(A.now() * 2)}, ":")
  if G.planCache and G.planCache.key == key then return G.planCache.value,G.planCache.opening end
  K.metrics.golemPlans = (K.metrics.golemPlans or 0) + 1
  local players, defenders, loads, npcs, assignments, assigned = {}, {}, {}, golems(), {}, {}
  local localOrder={}
  for index,npc in ipairs(npcs) do localOrder[tostring(npc.id)]=index end
  table.sort(npcs,function(a,b)
    if A.normal(a.name)~=A.normal(b.name) then return A.normal(a.name)<A.normal(b.name) end
    return localOrder[tostring(a.id)]<localOrder[tostring(b.id)]
  end)
  for _, member in ipairs(context.members) do
    local id, hp = tostring(member.id), health(member)
    if hp and hp > 0 then
      players[#players + 1] = member
      loads[id] = snapshot.incoming[id] and snapshot.incoming[id].count or 0
    end
  end
  table.sort(players,byName)
  for _,member in ipairs(players) do if A.canShield(member) then defenders[#defenders+1]=member end end
  local leader=context.actualLeader
  local incoming=leader and snapshot.incoming[tostring(leader.id)]
  if incoming and incoming.count>1 then
    local free,available={},{}
    for _,member in ipairs(defenders) do
      if tostring(member.id)~=tostring(leader.id)
          and loads[tostring(member.id)]==0 then free[#free+1]=member end
    end
    for _,npc in ipairs(npcs) do
      if incoming.npcs[tostring(npc.id)] then available[#available+1]=npc end
    end
    if #free>0 then
      -- Para nazw obronca/NPC jest wspolna takze przy innych lokalnych ID.
      -- Niedostepny obronca nie przesuwa natychmiast pozostalych przydzialow.
      for i=1,math.min(#free,#available-1) do
        local own,npc=free[i],available[i]
        assignments[tostring(own.id)]=candidate(own,leader,npc,false)
      end
      G.planCache={key=key,value=assignments,opening=true}
      return assignments,true
    end
  end
  local used = {}
  -- Wirtualny podzial daje kazdemu profilowi ten sam osobny cel juz przy
  -- pierwszym stanie 4 -> prowadzacy. Nie zakladamy wspolnego timera/IPC.
  for _ = 1, math.min(3, #players - 1) do
    local best
    for _, target in ipairs(players) do
      local targetId = tostring(target.id)
      for _, own in ipairs(defenders) do
        local ownId = tostring(own.id)
        if ownId ~= targetId and not assigned[ownId] and loads[targetId] > loads[ownId] + 1 then
          for _, npc in ipairs(npcs) do
            local id = tostring(npc.id)
            local plan=not used[id] and snapshot.incoming[targetId] and snapshot.incoming[targetId].npcs[id]
              and candidate(own,target,npc,false)
            if plan then
              local score = (loads[targetId] - loads[ownId]) * 1000 + health(own) - health(target)
              if not best or score > best.score then
                plan.score=score;best=plan
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
    for _, own in ipairs(defenders) do
      if own ~= target then
        for _, npc in ipairs(npcs) do
          local incoming = snapshot.incoming[tostring(target.id)]
          local plan,result
          if incoming and incoming.npcs[tostring(npc.id)] then plan,result=candidate(own,target,npc,true) end
          if plan then
            local score = health(own) - health(target)
            local free=result.ownAttackers==0
            if not best or free and not best.free or free==best.free
                and (score>best.score or score==best.score and result.riskAfter<best.riskAfter) then
              plan.score,plan.free,plan.riskAfter=score,free,result.riskAfter;best=plan
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
  if A.isFollower() and K.config.role ~= "zaslony" then
    if K.combatLog then K.combatLog.reason(nil,nil,"support_role") end
    return true
  end
  local own = A.group().self
  local assignments,opening = plans()
  local plan = own and assignments[tostring(own.id)]
  if plan then
    cancel("shieldTimer"); G.wait=nil
    A.shield(plan.target, health(plan.target), 100, plan)
  elseif (next(assignments) or opening) and own then
    -- Brak raportow o wlaczeniu innych profili: po krotkim czasie mozliwy
    -- jest lokalny plan awaryjny, ponownie oceniony na aktualnym GMCP.
    local key = A.snapshot().signature
    if not G.wait or G.wait.key ~= key then
      cancel("shieldTimer")
      local members={}
      for _,member in ipairs(A.group().members) do
        if A.canShield(member) then members[#members+1]=member end
      end
      table.sort(members,byName)
      local rank=0
      for i,member in ipairs(members) do if A.isSelf(member) then rank=i-1 break end end
      local emergency=next(G.unavailable)~=nil
      for _,member in ipairs(members) do if urgent(member) then emergency=true break end end
      local delay=emergency and (0.15+rank*0.15) or (0.9+rank*0.3)
      G.wait = {key=key, at=A.now() + delay}
      if K.combatLog then K.combatLog.reason(nil,nil,"golem_fallback_wait",false,G.wait.at) end
      local wait, generation = G.wait, K.generation
      G.shieldTimer = tempTimer(delay, function()
        G.shieldTimer=nil
        if G.wait == wait and K.enabled and K.generation == generation then A.queue() end
      end)
    elseif A.now() >= G.wait.at then
      local list = golems()
      local targets={}
      for _,member in ipairs(A.group().members) do targets[#targets+1]=member end
      local snapshot=A.snapshot()
      table.sort(targets,function(a,b)
        local first=snapshot.incoming[tostring(a.id)]
        local second=snapshot.incoming[tostring(b.id)]
        local aCount,bCount=first and first.count or 0,second and second.count or 0
        if aCount~=bCount then return aCount>bCount end
        if health(a)~=health(b) then return (health(a) or 100) < (health(b) or 100) end
        return byName(a,b)
      end)
      for _, target in ipairs(targets) do
        if tostring(target.id) ~= tostring(own.id) then
          for _, npc in ipairs(list) do
            local plan=candidate(own,target,npc,false) or candidate(own,target,npc,true)
            if plan then
              A.shield(target, health(target), 100, plan)
              return true
            end
          end
        end
      end
    elseif K.combatLog then K.combatLog.reason(nil,nil,"golem_fallback_wait",false,G.wait.at)
    end
  elseif K.combatLog then K.combatLog.reason(nil,nil,"golem_no_safe_assignment")
  end
  return true
end
local function accusative(name)
  local words={}
  for word in A.normal(name):gmatch("%S+") do
    words[#words+1]=word=="golem" and "golema" or word:gsub("y$","ego"):gsub("i$","iego")
  end
  return table.concat(words," ")
end
local function coverMembers(actor,form)
  local source,patient
  for _,member in ipairs(A.group().members) do
    if A.normal(member.name)==A.normal(actor) then source=member end
    if A.normal(member.name)==A.normal(form) or A.form(member.name)==A.normal(form)
        or (A.normal(form)=="cie" and A.isSelf(member)) then patient=member end
  end
  return source,patient
end
local function confirmSingle(patient,expectedId)
  local snapshot=A.snapshot()
  local incoming=patient and snapshot.incoming[tostring(patient.id)]
  if not incoming or incoming.count~=1 then return false end
  local id=next(incoming.npcs)
  local owners=snapshot.owners[id]
  if expectedId and id~=expectedId or not owners or next(owners)~=tostring(patient.id)
      or next(owners,next(owners))~=nil then return false end
  local previous=G.holds[id]
  if not previous or previous.untilTime<=A.now() then
    -- "wrogow" nie identyfikuje NPC. To tylko krotkie okno na GMCP,
    -- nie potwierdzenie przejecia ani osiem sekund stabilizacji ID.
    G.holds[id]={untilTime=A.now()+0.5,confirming=true}
  end
  return true
end
function G.onTeamCover(actor,form,description)
  if not fresh() or K.config.role=="wsparcie" then return end
  if G.combatRoom~=A.room() then G.resetCombat();G.combatRoom=A.room() end
  local source,patient=coverMembers(actor,form)
  if not source or not patient or source==patient then return end
  G.unavailable[tostring(source.id)]=nil
  local found=false
  if A.normal(description)=="wrogow" then found=confirmSingle(patient) end
  for _,npc in ipairs(golems()) do
    if accusative(npc.name)==A.normal(description) or A.normal(npc.name)==A.normal(description) then
      G.holds[tostring(npc.id)]={untilTime=A.now()+K.config.shieldHold}
      found=true
    end
  end
  if found then
    if K.combatLog then K.combatLog.mark("peer_cover",{actor=actor,patient=tostring(patient.id),description=description}) end
    G.combatEpoch=G.combatEpoch+1; G.planCache=nil; A.queue()
  end
end
function G.onTeamFailure(actor,form,description)
  if K.config.role=="wsparcie" or not G.encounter() then return end
  local source,patient=coverMembers(actor,form)
  if not source or not patient or source==patient or A.isSelf(source) then return end
  local found=false
  for _,npc in ipairs(golems()) do
    if accusative(npc.name)==A.normal(description) then found=true break end
  end
  if not found or (G.unavailable[tostring(source.id)] or 0)>A.now() then return end
  -- Widoczna porazka zuzywa szyk tylko tej postaci. Nie rezerwuje NPC
  -- dla pozostalych i nie wymaga raportu ani dodatkowego odpytywania.
  G.unavailable[tostring(source.id)]=A.now()+10
  if K.combatLog then K.combatLog.mark("peer_failure",{actor=actor,patient=tostring(patient.id),description=description}) end
  G.combatEpoch=G.combatEpoch+1;G.planCache=nil;G.wait=nil;cancel("shieldTimer")
  A.queue()
end
function G.onShieldResult(pending,succeeded,description)
  if not enabled() or not pending.golemNpcId then return end
  if pending.room and pending.room~=A.room() then return false end
  if pending.golemGeneric and A.normal(description)=="wrogow" then
    if succeeded and pending.room==A.room() then confirmSingle(A.entity(pending.id),pending.golemNpcId) end
    G.combatEpoch=G.combatEpoch+1;G.planCache=nil
    return true
  end
  local ids={}
  if description then
    for _,npc in ipairs(golems()) do
      if accusative(npc.name)==A.normal(description) then ids[#ids+1]=tostring(npc.id) end
    end
  else ids[1]=pending.golemNpcId end
  local matched=false
  for _,id in ipairs(ids) do
    if id==pending.golemNpcId or pending.golemAllowedIds and pending.golemAllowedIds[id] then matched=true end
    if succeeded then G.holds[id]={untilTime=A.now()+K.config.shieldHold}
    else G.failures[id..":"..tostring(pending.id)]={npcId=id,untilTime=A.now()+15} end
  end
  if not matched then
    K.metrics.golemTargetMismatches=(K.metrics.golemTargetMismatches or 0)+1
    if pending.golemSelector then G.selectors[pending.golemSelector]=A.now()+15 end
    if not G.mappingWarning then
      G.mappingWarning=true
      A.note("Golemy: odpowiedz gry wskazuje innego NPC (" .. tostring(description)
        .. "). Nie zapisuje zaslony dla planowanego ID.","yellow")
    end
  end
  G.combatEpoch=G.combatEpoch+1; G.planCache=nil
  return matched
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
  if not fresh() or A.isFollower() or not job or A.room()~=job.room or K.movementRest
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
  if not job or job.phase~="battle" or A.room()~=job.room or K.mode=="escape"
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
  local engaged=job and job.hadCombat or G.encounter()
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
  return enabled() and (phase=="search_wait" or phase=="search_uncertain")
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
  if G.encounter() and A.room() == job.room then job.hadCombat=true end
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
    elseif job.picked+(job.consumed or 0)+(job.unavailable or 0) >= job.expected
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
  return string.format("roznica HP %d pp; %s", K.config.golemHpGap,
    G.job and ((labels[G.job.phase] or "oczekiwanie") .. ", pozostalo "
      .. (G.job.cargoReady and G.job.remaining or G.job.picked+(G.job.extraCargo or 0))
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
K.handlers.triggers[#K.handlers.triggers + 1] = tempRegexTrigger(
  "^([A-Za-z-]+)(?: zrecznie)? zaslania (.+) przed ciosami ([^.,]+)[.,]",
  [[kozojeb.G.onTeamCover(matches[2],matches[3],matches[4])]])
K.handlers.triggers[#K.handlers.triggers + 1] = tempRegexTrigger(
  "^([A-Za-z-]+) probuje zaslonic (.+) przed ciosami ([^.,]+), lecz",
  [[kozojeb.G.onTeamFailure(matches[2],matches[3],matches[4])]])
K.handlers.triggers[#K.handlers.triggers + 1] = tempRegexTrigger(
  "^(.+) zbliza sie do powyginanego pancerza plytowego, podnosi go i wciska do",
  [[kozojeb.G.onConsumed(matches[2])]])
end
