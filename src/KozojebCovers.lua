-- Wspolny plan zaslon. Decyzje z GMCP i potwierdzen gry, bez IPC.
do
local K, A = kozojeb, kozojeb.golemApi
local C = {holds={}, confirmations={}, failures={}, rejected={}, forms={}, unavailable={}, formCount=0, combatEpoch=0}
K.C = C
local nouns={golem={"golemem","golema"},ork={"orkiem","orka"},goblin={"goblinem","goblina"},
  snotling={"snotlingiem","snotlinga"},troll={"trollem","trolla"},
  ozywieniec={"ozywiencem","ozywienca"},zombi={"zombim","zombiego"}}
local ordinal={"pierwszym","drugim","trzecim","czwartym","piatym"}
local function fresh()
  return K.enabled and not K.sessionBlocked and K.entitiesReady and not K.roomChangePending
    and K.sessionFresh.entities and K.combatRoomReady and K.sessionFresh.combat
end
local function forms(name)
  name=A.normal(name)
  if C.forms[name]~=nil then return C.forms[name] or nil end
  if C.formCount>=256 then return end
  C.formCount=C.formCount+1
  local words={};for word in name:gmatch("%S+") do words[#words+1]=word end
  local noun=nouns[words[#words]]
  if not noun or #words<2 or #words>6 then C.forms[name]=false;return end
  local instrument,genitive={},{}
  for i=1,#words-1 do
    local word=words[i]
    if not word:match("^[a-z%-]+$") then C.forms[name]=false;return end
    if word:match("y$") then
      instrument[i]=word:gsub("y$","ym");genitive[i]=word:gsub("y$","ego")
    elseif word:match("i$") then
      instrument[i]=word:gsub("i$","im");genitive[i]=word:gsub("i$","iego")
    else C.forms[name]=false;return end
  end
  instrument[#words],genitive[#words]=noun[1],noun[2]
  local result={instrument=table.concat(instrument," "),genitive=table.concat(genitive," ")}
  C.forms[name]=result;return result
end
local function cancel(name)
  if C[name] then pcall(killTimer, C[name]); C[name] = nil end
end
function C.reset()
  cancel("shieldTimer")
  cancel("coverTimer");C.coverDeadline=nil;C.confirmations={}
  C.holds,C.failures,C.rejected,C.wait,C.planCache={},{},{},nil,nil
  C.unavailable={}
  C.mappingWarning=nil
  C.forms={};C.formCount=0
  C.engaged,C.opening=nil,nil
  C.combatEpoch=C.combatEpoch+1
end
local function soleOwner(snapshot,id)
  local owners=snapshot.owners[id]
  local owner=owners and next(owners)
  if owner and next(owners,owner)==nil then return owner end
end
local function resolveCovers(snapshot)
  local time,changed=A.now(),false
  for key,pending in pairs(C.confirmations) do
    local resolved,alive=false,false
    for _,id in ipairs(pending.ids) do
      local transfer=K.shieldTransfers[id]
      if A.liveNpc(A.entity(id)) then alive=true end
      if soleOwner(snapshot,id)==pending.guard and transfer and transfer.from==pending.patient
          and transfer.to==pending.guard and (transfer.at or transfer.untilTime-K.config.shieldHold)>=pending.at-0.5 then
        C.holds[id]={untilTime=transfer.untilTime,patient=pending.patient,guard=pending.guard}
        resolved=true
      end
    end
    if resolved or not alive or pending.untilTime<=time then C.confirmations[key]=nil;changed=true end
  end
  if changed then C.planCache=nil;C.combatEpoch=C.combatEpoch+1 end
end
local function armCoverTimer()
  local deadline,time=nil,A.now()
  for _,pending in pairs(C.confirmations) do
    if pending.untilTime>time and (not deadline or pending.untilTime<deadline) then deadline=pending.untilTime end
  end
  for _,hold in pairs(C.holds) do
    if hold.pendingUntil and hold.pendingUntil>time and (not deadline or hold.pendingUntil<deadline) then deadline=hold.pendingUntil end
  end
  if not deadline then cancel("coverTimer");C.coverDeadline=nil;return end
  if C.coverTimer and C.coverDeadline<=deadline then return end
  cancel("coverTimer");C.coverDeadline=deadline
  local generation=K.generation
  C.coverTimer=tempTimer(math.max(0.01,deadline-time),function()
    C.coverTimer=nil;C.coverDeadline=nil
    if K.enabled and generation==K.generation and fresh() then
      C.planCache=nil;C.combatEpoch=C.combatEpoch+1;A.queue()
    end
  end)
end
local function reserveCover(ids,source,patient,general)
  if not source or not patient or #ids==0 then return false end
  local time,guard,target=A.now(),tostring(source.id),tostring(patient.id)
  if #ids==1 then
    local id=ids[1];local previous=C.holds[id]
    if previous and previous.guard==guard and previous.patient==target and (previous.pendingUntil or 0)>time then return false end
    C.holds[id]={untilTime=time+math.max(0.5,general and 0.5 or K.config.shieldHold),pendingUntil=time+0.5,
      patient=target,guard=guard,confirming=general or nil}
  elseif not general then
    table.sort(ids)
    local key=guard..":"..target..":"..table.concat(ids,",")
    if C.confirmations[key] and C.confirmations[key].untilTime>time then return false end
    local count=0
    for oldKey,pending in pairs(C.confirmations) do
      if pending.untilTime<=time then C.confirmations[oldKey]=nil else count=count+1 end
    end
    if count>=32 then return false end
    -- Opis wielu egzemplarzy nie rezerwuje kazdego na osiem sekund.
    -- Tylko faktyczne przejecie w GMCP rozstrzyga dluga stabilizacje ID.
    C.confirmations[key]={ids=ids,guard=guard,patient=target,at=time,untilTime=time+0.5}
    resolveCovers(A.snapshot())
  else return false end
  if C.opening and C.opening.patient == target then
    for _, id in ipairs(ids) do
      if id == C.opening.npcId then C.opening = nil; break end
    end
  end
  armCoverTimer()
  return true
end
local function describedNpc(npc, description)
  if not A.liveNpc(npc) or not description then return false end
  local value = forms(npc.name)
  local name = A.normal(description)
  return value and value.genitive == name or A.normal(npc.name) == name
end

local function attackers(snapshot)
  local relevant, result = {}, {}
  for _, member in ipairs(A.group().members) do
    local incoming = snapshot.incoming[tostring(member.id)]
    if incoming then
      for id in pairs(incoming.npcs) do relevant[id] = true end
    end
  end
  for _, npc in ipairs(A.entities()) do
    if relevant[tostring(npc.id)] and A.liveNpc(npc) then result[#result + 1] = npc end
  end
  return result
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
function C.selector(id,target)
  if not K.config.targetedShieldsEnabled then return end
  local npc=A.entity(id)
  if not A.liveNpc(npc) then return end
  local value=forms(npc.name)
  if not value then return end
  local peers=A.commandPeers(npc)
  local phrase,allowed=value.instrument,nil
  if #peers>1 then
    allowed={};local index
    local snapshot=A.snapshot()
    for i,peer in ipairs(peers) do
      local owners=snapshot.owners[tostring(peer.id)]
      local owner=owners and next(owners)
      if not target or owner~=tostring(target.id) or next(owners,owner)~=nil then return end
      allowed[tostring(peer.id)]=true
      if tostring(peer.id)==tostring(id) then index=i end
    end
    if not ordinal[index] then return end
    phrase=ordinal[index].." "..phrase
  end
  if (C.rejected[phrase] or 0)>A.now() then return end
  return phrase,allowed
end
local function pruneLocks()
  resolveCovers(A.snapshot())
  for id,hold in pairs(C.holds) do
    if not A.liveNpc(A.entity(id)) or hold.untilTime<=A.now() then C.holds[id]=nil end
  end
  for key,failure in pairs(C.failures) do
    if not A.liveNpc(A.entity(failure.npcId)) or failure.untilTime<=A.now() then C.failures[key]=nil end
  end
  for id,deadline in pairs(C.unavailable) do
    if deadline<=A.now() then C.unavailable[id]=nil end
  end
  for phrase,deadline in pairs(C.rejected) do
    if deadline<=A.now() then C.rejected[phrase]=nil end
  end
  armCoverTimer()
end
local function coverDeadline(id,target)
  local hold=C.holds[id]
  if hold and hold.patient==tostring(target.id) and (hold.pendingUntil or 0)>A.now() then return hold.pendingUntil end
  if hold and hold.confirming and hold.untilTime>A.now() then return hold.untilTime end
  for _,pending in pairs(C.confirmations) do
    if pending.patient==tostring(target.id) and pending.untilTime>A.now() then
      for _,candidateId in ipairs(pending.ids) do if candidateId==id then return pending.untilTime end end
    end
  end
end
local function selectedProjection(own, target, npc, rotation, opening)
  local function blocked(code,detail)
    if K.combatLog and A.isSelf(own) then K.combatLog.reason(target,npc.id,code,rotation,detail) end
  end
  if not A.canShield(own) or tostring(own.id)==tostring(target.id) then return blocked("role_or_self") end
  if A.isSelf(own) and A.threshold(target) <= 0 then return blocked("threshold_off") end
  if K.S and (K.S.isDead(target) or K.S.anonymous(target.name)) then return blocked("unavailable_target") end
  if not A.isSelf(own) and (C.unavailable[tostring(own.id)] or 0)>A.now() then return blocked("peer_formation_busy") end
  local snapshot=A.snapshot()
  local incoming=snapshot.incoming[tostring(target.id)]
  if opening then
    local ownIncoming = snapshot.incoming[tostring(own.id)]
    local first = C.opening
    if not first or first.patient ~= tostring(target.id) or first.npcId ~= tostring(npc.id)
        or not incoming or incoming.count ~= 1 or ownIncoming then return blocked("opening_changed") end
  end
  local generic=opening or not C.selector(npc.id,target)
  -- Ogolna komenda jest rownowazna wskazaniu ID tylko przy jednym
  -- napastniku. Przy kilku nadal nie zgadujemy podzbioru przejecia.
  if generic and (not incoming or incoming.count~=1) then return blocked("ambiguous_selector") end
  local hp, ownHp = health(target), health(own)
  if not hp or not ownHp or ownHp < math.max(K.config.shieldSelfHp, K.config.escapeHp + 15)
      or ownHp <= 0 or hp <= 0 then return blocked("unknown_or_low_hp") end
  if rotation then
    if ownHp - hp < K.config.shieldHpGap then return blocked("hp_gap") end
    local ownBudget, targetBudget = A.pair(own, target)
    local ownIncoming=snapshot.incoming[tostring(own.id)]
    local margin=not ownIncoming or ownIncoming.count==0
    margin=margin and 1.05 or 1.15
    if not ownBudget or ownBudget < targetBudget * margin then return blocked("hp_reserve") end
  elseif ownHp + K.config.shieldHpGap < hp then return blocked("own_hp_disadvantage") end
  local owners = snapshot.owners[tostring(npc.id)]
  local owner = owners and next(owners)
  if owner ~= tostring(target.id) or next(owners, owner) ~= nil then return blocked("npc_not_exclusive") end
  local id=tostring(npc.id)
  local hold=C.holds[id]
  -- Potwierdzenie sukcesu kolegi poprzedza czasem pakiet zmiany celu.
  -- Pilny HP omija dluga stabilizacje, ale nie to krotkie uzgodnienie.
  local confirming=coverDeadline(id,target)
  if confirming then return blocked("await_cover_confirmation",confirming) end
  if not urgent(target) then
    local transfer,failure=K.shieldTransfers[id],C.failures[id..":"..tostring(target.id)]
    if hold and hold.untilTime>A.now() then return blocked("cover_hold",hold.untilTime) end
    if transfer and transfer.untilTime>A.now() then return blocked("transfer_hold",transfer.untilTime) end
    if failure and failure.untilTime>A.now() then return blocked("previous_failure",failure.untilTime) end
  end
  if A.isSelf(own) and (K.shieldPositionUntil[A.form(target.name) or ""] or 0)>A.now() then return blocked("position_blocked") end
  local result,reason=A.projection(own, target, hp, tostring(npc.id), rotation, urgent(target), opening)
  if not result then blocked("unsafe_projection",reason) end
  return result,generic
end
local function candidate(own,target,npc,rotation,opening)
  local result,generic=selectedProjection(own,target,npc,rotation,opening)
  if result then
    return {own=own,target=target,npcId=tostring(npc.id),rotation=rotation,
      generic=generic,opening=opening,coordinated=true},result
  end
end
function C.validate(own,target,percent,plan)
  if not fresh() or not own or not target then return end
  local npc=A.entity(plan.npcId)
  if not A.liveNpc(npc) then return end
  local incoming=A.snapshot().incoming[tostring(target.id)]
  if plan.generic and (not incoming or incoming.count~=1 or not incoming.npcs[tostring(npc.id)]) then return end
  if not plan.coordinated then
    if not C.selector(plan.npcId,target) or coverDeadline(plan.npcId,target)
        or soleOwner(A.snapshot(),plan.npcId)~=tostring(target.id) then return end
    return A.projection(own,target,percent,plan.npcId)
  end
  local result,generic=selectedProjection(own,target,npc,plan.rotation,plan.opening)
  if generic and not plan.generic then return end
  return result
end
function C.project(own,target,percent)
  if not own or not target then return end
  local ownHp = health(own)
  if not ownHp or ownHp < K.config.shieldSelfHp then
    return nil,nil,"Za malo wlasnych HP"
  end
  percent = percent or health(target)
  if not percent then return nil,nil,"Brak HP oslanianego czlonka" end
  local generic,reason=A.projection(own,target,percent)
  if not K.config.targetedShieldsEnabled or not fresh() then return generic,nil,reason end
  local snapshot=A.snapshot()
  resolveCovers(snapshot)
  local incoming=snapshot.incoming[tostring(target.id)]
  if not incoming then return nil,nil,reason end
  local pending=false
  for id in pairs(incoming.npcs) do if coverDeadline(id,target) then pending=true end end
  if generic and not pending then return generic end
  if pending then reason="Oczekiwanie na potwierdzenie zaslony kolegi" end
  local list={}
  for id in pairs(incoming.npcs) do
    local npc=A.entity(id)
    if npc then list[#list+1]=npc end
  end
  table.sort(list,function(a,b)
    if A.normal(a.name)~=A.normal(b.name) then return A.normal(a.name)<A.normal(b.name) end
    return tostring(a.id)<tostring(b.id)
  end)
  for _,npc in ipairs(list) do
    local id=tostring(npc.id)
    local failure = C.failures[id..":"..tostring(target.id)]
    if soleOwner(snapshot,id)==tostring(target.id) and C.selector(id,target) and not coverDeadline(id,target)
        and (not failure or failure.untilTime<=A.now() or urgent(target)) then
      local decision=A.projection(own,target,percent,id)
      if decision then return decision,{npcId=id} end
    end
  end
  return nil,nil,reason
end
function C.observe(allowOpening)
  if not fresh() or K.config.role == "wsparcie" then return false end
  local snapshot = A.snapshot()
  local patient, npcId, attacked = nil, nil, 0
  for _, member in ipairs(A.group().members) do
    local id = tostring(member.id)
    local incoming = snapshot.incoming[id]
    if incoming then
      attacked = attacked + 1
      if incoming.count == 1 then patient, npcId = id, next(incoming.npcs) end
    end
  end
  if attacked == 0 then
    if C.engaged and not A.threat() then
      C.engaged, C.opening, C.planCache = nil, nil, nil
    end
    return false
  end
  local single = attacked == 1 and npcId and soleOwner(snapshot,npcId) == patient
  if not C.engaged and allowOpening and single then
    C.opening = {patient=patient,npcId=npcId}
    C.planCache = nil
  elseif C.opening and (not single or C.opening.patient ~= patient or C.opening.npcId ~= npcId) then
    C.opening = nil
    C.planCache = nil
  end
  local notice = patient and K.teamShieldNotices[patient]
  if C.opening and notice and notice.confirmed and notice.room == A.room()
      and notice.deadline > A.now() and notice.count == 1 and notice.npcs[npcId] then
    C.opening = nil
    C.planCache = nil
  end
  C.engaged = true
  return true
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
  local key = table.concat({table.concat(parts,"|"),C.combatEpoch,K.lastHp,K.config.shieldHpGap,
    K.config.shieldSelfHp, K.config.shieldMaxAttackers, K.config.escapeHp,K.config.teamEscapeHp,
    K.config.teamShieldHp,K.config.leaderShieldHp,
    math.floor(A.now() * 2)}, ":")
  if C.planCache and C.planCache.key == key then return C.planCache.value,C.planCache.opening end
  K.metrics.shieldPlans = (K.metrics.shieldPlans or 0) + 1
  local players, defenders, loads, npcs, assignments, assigned = {}, {}, {}, attackers(A.snapshot()), {}, {}
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
  local patient, attacked
  for _, member in ipairs(players) do
    if loads[tostring(member.id)] > 0 then
      patient, attacked = member, (attacked or 0) + 1
    end
  end
  local incoming = attacked == 1 and snapshot.incoming[tostring(patient.id)]
  if incoming and (incoming.count > 1 or C.opening) then
    local free,available={},{}
    for _,member in ipairs(defenders) do
      if tostring(member.id)~=tostring(patient.id)
          and loads[tostring(member.id)]==0 then free[#free+1]=member end
    end
    for _,npc in ipairs(npcs) do
      if incoming.npcs[tostring(npc.id)] then available[#available+1]=npc end
    end
    local opening = incoming.count == 1 and C.opening ~= nil
    if opening and #free > 0 and available[1] then
      local best, risk
      for _, guard in ipairs(free) do
        local plan, decision = candidate(guard,patient,available[1],false,true)
        if plan and (not best or decision.riskAfter <= risk) then
          best, risk = plan, decision.riskAfter
        end
      end
      if best then assignments[tostring(best.own.id)] = best end
      C.planCache = {key=key,value=assignments,opening=true}
      return assignments,true
    elseif #free>0 then
      -- Para nazw obronca/NPC jest wspolna takze przy innych lokalnych ID.
      -- Niedostepny obronca nie przesuwa natychmiast pozostalych przydzialow.
      local needed = math.min(#free,#available-1)
      -- Przy pelnej obsadzie utrzymujemy stala kolejnosc. Gdy czesc
      -- obroncow ma zostac wolna, pierwszenstwo ma wieksza rezerwa HP.
      if needed < #free then
        table.sort(free,function(a,b)
          local aReserve = A.pair(a,patient) or 0
          local bReserve = A.pair(b,patient) or 0
          if aReserve ~= bReserve then return aReserve > bReserve end
          return byName(b,a)
        end)
      end
      for i=1,needed do
        local own,npc=free[i],available[i]
        assignments[tostring(own.id)]=candidate(own,patient,npc,false)
      end
      if next(assignments) or next(C.unavailable) then
        C.planCache={key=key,value=assignments,opening=true}
        return assignments,true
      end
    end
  end
  -- After the first cover, an ordinary duel uses the configured rescue
  -- thresholds. A healthy team does not pass the same NPC back and forth.
  if #npcs == 1 then
    C.planCache = {key=key,value=assignments}
    return assignments
  end
  local used, evaluated = {}, {}
  -- Wirtualne przesuniecia rozdzielaja cele przed nadejsciem odpowiedzi gry.
  for _ = 1, #defenders do
    local best
    for _, target in ipairs(players) do
      local targetId = tostring(target.id)
      for _, own in ipairs(defenders) do
        local ownId = tostring(own.id)
        if ownId ~= targetId and not assigned[ownId] and loads[targetId] > loads[ownId] + 1 then
          for _, npc in ipairs(npcs) do
            local id = tostring(npc.id)
            local plan
            if not used[id] and snapshot.incoming[targetId] and snapshot.incoming[targetId].npcs[id] then
              local candidateKey = ownId .. ":" .. targetId .. ":" .. id
              plan = evaluated[candidateKey]
              if plan == nil then
                plan = candidate(own,target,npc,false) or false
                evaluated[candidateKey] = plan
              end
            end
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
  if next(assignments) then C.planCache={key=key,value=assignments}; return assignments end
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
  C.planCache={key=key,value=assignments}
  return assignments
end
function C.canRescue(target)
  if not fresh() or K.config.role == "wsparcie" or not A.form(target.name)
      or K.shieldPendingTarget or K.shieldTimer
      or K.shieldAwaitCombatRevision == K.combatRevision then return false end
  local own = A.group().self
  if not own then return false end
  local assignments = plans()
  local plan = assignments[tostring(own.id)]
  return plan and tostring(plan.target.id) == tostring(target.id)
    and C.validate(own,target,health(target),plan) ~= nil
end

function C.setGap(value)
  local gap = tonumber(value)
  if not gap or gap < 5 or gap > 30 or gap ~= math.floor(gap) then
    A.note("Uzycie: /kozojeb roznicahp <5-30> (punkty procentowe).", "yellow")
    return
  end
  K.config.shieldHpGap = gap
  C.planCache = nil
  A.note("Zaslony: prog rotacji " .. gap .. " punktow procentowych HP.", "cyan")
end
function C.shield()
  if not C.observe(false) then cancel("shieldTimer"); C.wait=nil; return false end
  local own = A.group().self
  local assignments,opening = plans()
  local plan = own and assignments[tostring(own.id)]
  if plan then
    cancel("shieldTimer"); C.wait=nil
    local sent, waiting = A.shield(plan.target, health(plan.target), 100, plan)
    return sent or waiting or false
  elseif (next(assignments) or opening) and own then
    -- Brak raportow o wlaczeniu innych profili: po krotkim czasie mozliwy
    -- jest lokalny plan awaryjny, ponownie oceniony na aktualnym GMCP.
    if not C.wait or C.wait.room~=A.room() then
      cancel("shieldTimer")
      local members={}
      for _,member in ipairs(A.group().members) do
        if A.canShield(member) then members[#members+1]=member end
      end
      local snapshot=A.snapshot()
      table.sort(members,function(a,b)
        local first,second=snapshot.incoming[tostring(a.id)],snapshot.incoming[tostring(b.id)]
        local freeA,freeB=not first or first.count==0,not second or second.count==0
        if freeA~=freeB then return freeA end
        return byName(a,b)
      end)
      local rank=0
      for i,member in ipairs(members) do if A.isSelf(member) then rank=i-1 break end end
      local emergency=next(C.unavailable)~=nil
      for _,member in ipairs(members) do if urgent(member) then emergency=true break end end
      local delay=emergency and (0.15+rank*0.15) or (0.9+rank*0.3)
      -- Damage and target packets can change the signature every fraction
      -- of a second. They must not restart the deadline for an absent/DPS
      -- defender. The eventual fallback is validated on the latest state.
      C.wait = {room=A.room(), at=A.now() + delay}
      if K.combatLog then K.combatLog.reason(nil,nil,"formation_fallback_wait",false,C.wait.at) end
      local wait, generation = C.wait, K.generation
      C.shieldTimer = tempTimer(delay, function()
        C.shieldTimer=nil
        if C.wait == wait and K.enabled and K.generation == generation then A.queue() end
      end)
    elseif A.now() >= C.wait.at then
      local list = attackers(A.snapshot())
      local targets={}
      for _,member in ipairs(A.group().members) do targets[#targets+1]=member end
      local snapshot=A.snapshot()
      local ownIncoming = snapshot.incoming[tostring(own.id)]
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
            local first = C.opening
            local opening = first and first.patient == tostring(target.id) and first.npcId == tostring(npc.id)
            local plan=candidate(own,target,npc,false,opening)
            -- Nie przejmuj drugiego wroga na podstawie samej roznicy HP
            -- tylko dlatego, ze wolny obronca nie wykonal przydzialu.
            local hold = C.holds[tostring(npc.id)]
            local stalledRescue = hold and hold.patient == tostring(target.id)
              and hold.guard ~= tostring(own.id) and urgent(target)
            if not plan and (not ownIncoming or stalledRescue) then
              plan=candidate(own,target,npc,true)
            end
            if plan then
              local sent, waiting = A.shield(target, health(target), 100, plan)
              return sent or waiting or false
            end
          end
        end
      end
      return false
    elseif K.combatLog then K.combatLog.reason(nil,nil,"formation_fallback_wait",false,C.wait.at)
    end
  else
    cancel("shieldTimer")
    C.wait = nil
    if K.combatLog then K.combatLog.reason(nil,nil,"formation_no_safe_assignment") end
    return false
  end
  return true
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
local function confirmSingle(patient,expectedId,source)
  local snapshot=A.snapshot()
  local incoming=patient and snapshot.incoming[tostring(patient.id)]
  if not incoming or incoming.count~=1 then return false end
  local id=next(incoming.npcs)
  local owners=snapshot.owners[id]
  if expectedId and id~=expectedId or not owners or next(owners)~=tostring(patient.id)
      or next(owners,next(owners))~=nil then return false end
  return reserveCover({id},source,patient,true)
end
function C.onTeamCover(actor,form,description)
  if not fresh() or K.config.role=="wsparcie" then return end
  local source,patient=coverMembers(actor,form)
  if not source or not patient or source==patient then return end
  C.unavailable[tostring(source.id)]=nil
  local found=false
  if A.normal(description)=="wrogow" then found=confirmSingle(patient,nil,source) end
  local ids={}
  for _,npc in ipairs(A.entities()) do
    if describedNpc(npc,description) then
      ids[#ids+1]=tostring(npc.id)
    end
  end
  if #ids>0 then found=reserveCover(ids,source,patient) end
  if found then
    if K.combatLog then K.combatLog.mark("peer_cover",{actor=actor,patient=tostring(patient.id),description=description}) end
    C.combatEpoch=C.combatEpoch+1; C.planCache=nil; A.queue()
  end
end
function C.onTeamFailure(actor,form,description)
  if K.config.role=="wsparcie" or not fresh() then return end
  local source,patient=coverMembers(actor,form)
  if not source or not patient or source==patient or A.isSelf(source) then return end
  local found=false
  for _,npc in ipairs(A.entities()) do
    if describedNpc(npc,description) then found=true break end
  end
  if not found or (C.unavailable[tostring(source.id)] or 0)>A.now() then return end
  -- Widoczna porazka zuzywa szyk tylko tej postaci. Nie rezerwuje NPC
  -- dla pozostalych i nie wymaga raportu ani dodatkowego odpytywania.
  C.unavailable[tostring(source.id)]=A.now()+10
  if K.combatLog then K.combatLog.mark("peer_failure",{actor=actor,patient=tostring(patient.id),description=description}) end
  C.combatEpoch=C.combatEpoch+1;C.planCache=nil;C.wait=nil;cancel("shieldTimer")
  A.queue()
end
function C.onResult(pending,succeeded,description)
  if not fresh() or not pending.npcId then return false end
  if pending.room and pending.room~=A.room() then return false end
  if pending.genericNpc and A.normal(description)=="wrogow" then
    if succeeded and pending.room==A.room() then confirmSingle(A.entity(pending.id),pending.npcId,A.group().self) end
    C.combatEpoch=C.combatEpoch+1;C.planCache=nil
    return true
  end
  local ids={}
  if description then
    for _,npc in ipairs(A.entities()) do
      if describedNpc(npc,description) then ids[#ids+1]=tostring(npc.id) end
    end
  else ids[1]=pending.npcId end
  local matched=false
  for _,id in ipairs(ids) do
    if id==pending.npcId or pending.allowedNpcIds and pending.allowedNpcIds[id] then matched=true end
    if not succeeded then C.failures[id..":"..tostring(pending.id)]={npcId=id,untilTime=A.now()+15} end
  end
  if succeeded then reserveCover(ids,A.group().self,A.entity(pending.id)) end
  if pending.npcSelector and not matched then
    C.rejected[pending.npcSelector] = A.now() + 15
  end
  if not matched then
    K.metrics.shieldTargetMismatches=(K.metrics.shieldTargetMismatches or 0)+1
    if not C.mappingWarning then
      C.mappingWarning=true
      A.note("Zaslony: odpowiedz gry wskazuje innego NPC (" .. tostring(description)
        .. "). Nie zapisuje zaslony dla planowanego ID.","yellow")
    end
  end
  C.combatEpoch=C.combatEpoch+1; C.planCache=nil
  return matched
end
K.handlers.triggers[#K.handlers.triggers + 1] = tempRegexTrigger(
  "^([A-Za-z-]+)(?: zrecznie)? zaslania (.+) przed ciosami ([^.,]+)[.,]",
  [[kozojeb.C.onTeamCover(matches[2],matches[3],matches[4])]])
K.handlers.triggers[#K.handlers.triggers + 1] = tempRegexTrigger(
  "^([A-Za-z-]+) probuje zaslonic (.+) przed ciosami ([^.,]+), lecz",
  [[kozojeb.C.onTeamFailure(matches[2],matches[3],matches[4])]])
K.handlers.triggers[#K.handlers.triggers + 1] = tempRegexTrigger(
  "^([A-Za-z-]+) probuje cie zaslonic przed ciosami ([^.,]+), lecz",
  [[kozojeb.C.onTeamFailure(matches[2],"cie",matches[3])]])
end
