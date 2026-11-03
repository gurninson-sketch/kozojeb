-- Celowane zaslony poza golemami. Tylko sprawdzalne selektory i swieze relacje.
do
local K,A=kozojeb,kozojeb.golemApi
local C={pending={},forms={},rejected={},formCount=0}
K.C=C
local nouns={ork={"orkiem","orka"},goblin={"goblinem","goblina"},
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
    if not word:match("^[a-z]+$") then C.forms[name]=false;return end
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
function C.reset()
  if C.timer then pcall(killTimer,C.timer) end
  C.timer=nil;C.pending={};C.forms={};C.rejected={};C.formCount=0
end
local function resolve()
  local snapshot,time=A.snapshot(),A.now()
  for key,pending in pairs(C.pending) do
    local changed,alive=false,false
    for id in pairs(pending.ids) do
      if A.liveNpc(A.entity(id)) then alive=true end
      local transfer=K.shieldTransfers[id]
      if transfer and transfer.from==pending.patient and transfer.to==pending.guard
          and (transfer.at or transfer.untilTime-K.config.shieldHold)>=pending.at-0.5 then changed=true end
    end
    if changed or not alive or pending.deadline<=time then C.pending[key]=nil end
  end
  return snapshot
end
local function blocked(id)
  resolve()
  for _,pending in pairs(C.pending) do if pending.ids[id] then return true end end
  return false
end
local function arm()
  if C.timer then pcall(killTimer,C.timer);C.timer=nil end
  local deadline
  for _,pending in pairs(C.pending) do deadline=math.min(deadline or pending.deadline,pending.deadline) end
  if not deadline then return end
  local generation=K.generation
  C.timer=tempTimer(math.max(.01,deadline-A.now()),function()
    C.timer=nil
    if generation==K.generation and fresh() then resolve();A.queue() end
  end)
end
function C.selector(id,target)
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
function C.project(own,target,percent)
  local generic,reason=A.projection(own,target,percent)
  if not K.config.targetedShieldsEnabled or not fresh() then return generic,nil,reason end
  local incoming=A.snapshot().incoming[tostring(target.id)]
  if not incoming then return nil,nil,reason end
  local pending=false
  for id in pairs(incoming.npcs) do if blocked(id) then pending=true end end
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
    if C.selector(id,target) and not blocked(id) then
      local decision=A.projection(own,target,percent,id)
      if decision then return decision,{general=true,npcId=id} end
    end
  end
  return nil,nil,reason
end
function C.validate(own,target,percent,plan)
  if not fresh() or not K.config.targetedShieldsEnabled or not C.selector(plan.npcId,target)
      or blocked(plan.npcId) then return nil,"Oczekiwanie na potwierdzenie lub niejednoznaczny NPC" end
  return A.projection(own,target,percent,plan.npcId)
end
local function reserve(guard,patient,ids)
  if not guard or not patient or not next(ids) then return end
  resolve()
  local key=tostring(guard.id)..":"..tostring(patient.id)
  if C.pending[key] then return end
  local count=0;for _ in pairs(C.pending) do count=count+1 end
  if count>=32 then return end
  C.pending[key]={guard=tostring(guard.id),patient=tostring(patient.id),ids=ids,at=A.now(),deadline=A.now()+.5}
  resolve();arm()
end
local function described(description)
  local ids={}
  for _,npc in ipairs(A.entities()) do
    if A.liveNpc(npc) then
      local value=forms(npc.name)
      if value and value.genitive==A.normal(description) then ids[tostring(npc.id)]=true end
    end
  end
  return ids
end
function C.onResult(pending,succeeded,description)
  if not pending.generalPlan then return true end
  if pending.room~=A.room() or not fresh() then return false end
  local ids=described(description)
  local matched=ids[tostring(pending.golemNpcId)] or false
  if not matched and pending.golemAllowedIds then
    for id in pairs(ids) do if pending.golemAllowedIds[id] then matched=true end end
  end
  if succeeded then reserve(A.group().self,A.entity(pending.id),ids) end
  if not succeeded or not matched then
    local count=0
    for phrase,deadline in pairs(C.rejected) do
      if deadline<=A.now() then C.rejected[phrase]=nil else count=count+1 end
    end
    if pending.golemSelector and count<32 then C.rejected[pending.golemSelector]=A.now()+15 end
  end
  return matched
end
function C.onTeamCover(actor,form,description)
  if not fresh() or not K.config.targetedShieldsEnabled then return end
  local guard,patient
  for _,member in ipairs(A.group().members) do
    if A.normal(member.name)==A.normal(actor) then guard=member end
    if (A.normal(form)=="cie" and A.isSelf(member)) or A.normal(member.name)==A.normal(form)
        or A.form(member.name)==A.normal(form) then patient=member end
  end
  if guard and patient and not A.isSelf(guard) then reserve(guard,patient,described(description)) end
end
K.handlers.triggers[#K.handlers.triggers+1]=tempRegexTrigger(
  "^([A-Za-z-]+)(?: zrecznie)? zaslania (.+) przed ciosami ([^.,]+)[.,]",
  [[kozojeb.C.onTeamCover(matches[2],matches[3],matches[4])]])
end
