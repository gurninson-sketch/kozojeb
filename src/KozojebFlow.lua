-- Bounded outgoing-command filters and configurable map hazards. No IPC,
-- input history, movement from followers or changes to Mudlet's global map.
do
local K,A=kozojeb,kozojeb.golemApi
local F={}
K.F=F
K.config.dangerousRooms=type(K.config.dangerousRooms)=="table" and K.config.dangerousRooms or {}
K.config.dangerousExits=type(K.config.dangerousExits)=="table" and K.config.dangerousExits or {}
K.config.golemLootIgnored=type(K.config.golemLootIgnored)=="table" and K.config.golemLootIgnored or {}
if K.config.trapAutoLearn==nil then K.config.trapAutoLearn=true end
if K.config.golemLootFilter==nil then K.config.golemLootFilter=true end
local directions=A.directions
local short={n=true,s=true,e=true,w=true,ne=true,nw=true,se=true,sw=true,u=true,d=true}
local function direction(command)
  local value=A.normal(command)
  return short[value] and value or directions[value]
end
local function exitKey(room,command) return tostring(tonumber(room))..":"..tostring(direction(command) or A.normal(command)) end
local function validRoom(value)
  value=tonumber(value)
  return value and value>0 and value<1000000000 and value==math.floor(value) and value
end
function F.hasHazards() return next(K.config.dangerousRooms)~=nil or next(K.config.dangerousExits)~=nil end
function F.allowed(room,command,destination)
  if not F.hasHazards() then return true end
  return not (K.config.dangerousRooms[tostring(tonumber(room))]
    or K.config.dangerousRooms[tostring(tonumber(destination))]
    or K.config.dangerousExits[exitKey(room,command)])
end
function F.stepAllowed(room,command)
  if not F.hasHazards() then return true end
  local destination
  if type(getRoomExits)=="function" then
    local ok,exits=pcall(getRoomExits,room)
    if ok and type(exits)=="table" then
      for name,id in pairs(exits) do
        if (direction(name) or A.normal(name))==(direction(command) or A.normal(command)) then destination=tonumber(id);break end
      end
    end
  end
  return F.allowed(room,command,destination)
end
function F.validatePath(from)
  if not F.hasHazards() then return true end
  if type(speedWalkDir)~="table" then return false end
  for i,command in ipairs(speedWalkDir) do
    if i>250 then return false end
    local destination=type(speedWalkPath)=="table" and tonumber(speedWalkPath[i])
    if not destination and type(getRoomExits)=="function" then
      local ok,exits=pcall(getRoomExits,from)
      if ok and type(exits)=="table" then
        for name,id in pairs(exits) do
          if (direction(name) or A.normal(name))==(direction(command) or A.normal(command)) then destination=tonumber(id);break end
        end
      end
    end
    if not destination or not F.allowed(from,command,destination) then return false end
    from=destination
  end
  return true
end
function F.walk(destination)
  if F.hasHazards() then
    if not F.allowed(A.room(),"",destination) then
      K.stop("Trasa prowadzi przez pokoj z zapisana pulapka: "..tostring(destination)..".")
      return false
    end
    local ok,found=K.findPath(A.room(),destination)
    if not ok or found==false or type(speedWalkDir)~="table" or not F.validatePath(A.room()) then
      K.stop("Nie ma potwierdzonej trasy omijajacej zapisane pulapki do "..tostring(destination)..".")
      return false
    end
  end
  expandAlias("/idz "..destination)
  return true
end
function F.session() F.batch=nil;F.lastMove=nil;F.supportNotice=nil;F.filterNotice=nil end
function F.onTrap()
  local move=F.lastMove
  if not K.config.trapAutoLearn or not move or A.now()-move.at>3 or not validRoom(move.from) then return end
  if move.uncertain then
    if not F.uncertainNotice or A.now()-F.uncertainNotice>=5 then
      F.uncertainNotice=A.now();A.note("Pulapka: niejednoznaczna pozycja po kilku ruchach. Sprawdz mape i dodaj pokoj przez /kozojeb pulapki blokuj.","red")
    end
    return
  end
  local key=tostring(move.from)
  if not K.config.dangerousRooms[key] then
    local count=0;for _ in pairs(K.config.dangerousRooms) do count=count+1 end
    if count>=128 then return end
    K.config.dangerousRooms[key]=true;K.saveSettings()
    A.note("Pulapka przy przejsciu z pokoju "..key..". Automatyczne trasy beda go omijac; recznym ruchem nadal kierujesz sam.","red")
    if K.combatLog then K.combatLog.mark("map_hazard",{room=move.from,direction=move.command}) end
  end
  K.route=nil
end
local function golemContext()
  if not K.enabled or K.config.role~="prowadzacy" or not K.config.golemsEnabled
      or K.sessionBlocked or not K.entitiesReady or K.roomChangePending then return false end
  if K.mode~="combat" and K.mode~="kill_pause" and K.mode~="patrol" then return false end
  local found=false
  for _,entity in ipairs(A.entities()) do
    if entity.kind=="npc" then
      if not A.normal(entity.name):match("%f[%a]golem%f[%A]") then return false end
      found=true
    end
  end
  local job=K.G and K.G.job
  return found or job and job.room==A.room() and (job.phase=="battle" or job.phase=="settle" or job.phase=="collect")
end
local function deny(kind)
  if type(denyCurrentSend)~="function" then return false end
  denyCurrentSend()
  K.metrics[kind]=(K.metrics[kind] or 0)+1
  return true
end
local lootTail={"ocen kamienie","otworz swoj plecak","wloz kamienie do swojego plecaka","zamknij swoj plecak"}
local function loot(command)
  if command~="wez kamienie z ciala" and not F.batch and not K.config.golemLootIgnored[command] then return false end
  if not K.config.golemLootFilter or not golemContext() or type(denyCurrentSend)~="function" then F.batch=nil;return false end
  if command=="wez kamienie z ciala" then
    F.batch={room=A.room(),at=A.now(),index=1}
    if F.filterNotice~=A.room() then
      F.filterNotice=A.room()
      A.note("Golemy: filtruje pusta serie kamieni z ciala; kamienie zbieram z pancerzy w bazie. /kozojeb golemy filtr off wylacza filtr.","cyan")
    end
    return deny("lootFiltered")
  end
  local batch=F.batch
  if batch and batch.room==A.room() and A.now()-batch.at<=0.25 and command==lootTail[batch.index] then
    batch.index=batch.index+1
    if batch.index>#lootTail then F.batch=nil end
    return deny("lootFiltered")
  end
  F.batch=nil
  if K.config.golemLootIgnored[command] then return deny("lootFiltered") end
  return false
end
local function redundantSupport()
  if not K.enabled or not A.isFollower() or K.sessionBlocked or not K.entitiesReady
      or K.roomChangePending or not K.combatRoomReady or not K.sessionFresh.combat then return false end
  if K.supportDeathBarrier or K.lastGmcpAt and A.now()-K.lastGmcpAt>2 then return false end
  local group=A.group()
  if not group.self or not group.leader or A.isSelf(group.leader) then return false end
  local own,leader={},{}
  for _,edge in ipairs(K.combatLogApi.combat().relations or {}) do
    local npc=A.entity(edge.defender)
    if npc and A.liveNpc(npc) then
      if tostring(edge.attacker)==tostring(group.self.id) then own[tostring(edge.defender)]=true end
      if tostring(edge.attacker)==tostring(group.leader.id) then leader[tostring(edge.defender)]=true end
    end
  end
  -- Multiple outgoing targets are ambiguous; never prevent a real retarget.
  local id=next(own)
  local leaderId=next(leader)
  if id and not next(own,id) and leaderId==id and not next(leader,leaderId) and not K.deadNpcIds[id] then
    if not deny("supportFiltered") then return false end
    if F.supportNotice~=A.room() then
      F.supportNotice=A.room();A.note("Pomijam powtorne wsparcie tego samego, potwierdzonego celu walki.","cyan")
    end
    return true
  end
  return false
end
function F.outgoing(raw)
  if type(raw)~="string" or #raw>160 or K.sessionBlocked or not K.enabled then return false end
  local command=A.normal(raw):gsub("%s+"," ")
  local step=direction(command)
  if step then
    local previous=F.lastMove
    local uncertain=previous and previous.from==A.room() and previous.revision==(F.roomRevision or 0)
      and A.now()-previous.at<3
    F.lastMove={from=A.room(),command=step,at=A.now(),revision=F.roomRevision or 0,uncertain=uncertain}
    if not F.stepAllowed(A.room(),step) and (not F.hazardNotice or A.now()-F.hazardNotice>=5) then
      F.hazardNotice=A.now();A.note("Uwaga: reczny ruch przy zapisanej pulapce w pokoju "..tostring(A.room())..".","red")
    end
  end
  if command=="wesprzyj" and redundantSupport() then return true end
  return loot(command)
end
function F.lootCommand(rest)
  local action,value=A.normal(rest):match("^(%S*)%s*(.-)$")
  if action=="on" or action=="off" then
    K.config.golemLootFilter=action=="on";F.batch=nil;K.saveSettings()
  elseif action=="dodaj" or action=="usun" then
    if not value:match("^wez [%a%s%-]+$") or #value>120 or value:find("pancerz",1,true) then
      A.note("Filtr dodatkowy przyjmuje jedna komende wez <przedmiot>, bez pancerzy.","yellow");return
    end
    K.config.golemLootIgnored[value]=action=="dodaj" and true or nil;K.saveSettings()
  elseif action~="" and action~="status" then
    A.note("/kozojeb golemy filtr on|off|status; filtr dodaj|usun wez <przedmiot>.","yellow");return
  end
  A.note("Filtr pustego lupu golemow: "..(K.config.golemLootFilter and "on" or "off")
    .."; pominieto "..tostring(K.metrics.lootFiltered or 0).." komend.","cyan")
end
function F.command(rest)
  local action,room,command=A.normal(rest):match("^(%S*)%s*(%S*)%s*(.-)$")
  if action=="on" or action=="off" then K.config.trapAutoLearn=action=="on";K.saveSettings()
  elseif action=="blokuj" or action=="usun" then
    local id=validRoom(room)
    if not id or command~="" and not direction(command) then
      A.note("/kozojeb pulapki blokuj|usun <pokoj> [kierunek].","yellow");return
    end
    if command=="" then K.config.dangerousRooms[tostring(id)]=action=="blokuj" and true or nil
    else K.config.dangerousExits[exitKey(id,command)]=action=="blokuj" and true or nil end
    K.route=nil;K.saveSettings()
  elseif action~="" and action~="status" then
    A.note("/kozojeb pulapki status|on|off|blokuj|usun <pokoj> [kierunek].","yellow");return
  end
  local entries={}
  for id in pairs(K.config.dangerousRooms) do entries[#entries+1]="pokoj "..id end
  for id in pairs(K.config.dangerousExits) do entries[#entries+1]="wyjscie "..id end
  table.sort(entries)
  A.note("Pulapki: wykrywanie "..(K.config.trapAutoLearn and "on" or "off").."; "
    ..(#entries>0 and table.concat(entries,", ") or "brak zapisanych przejsc")..".","cyan")
end
K.handlers.triggers[#K.handlers.triggers+1]=tempRegexTrigger(
  "^(?:Nagle z boku.*(?:Straszliwe ciecie|straszliwego ciecia).*|kociej wrecz zrecznosci .*straszliwego ciecia.*otchlani\\.|lalke\\. Tracisz rownowage i spadasz w otchlan\\.)$",[[kozojeb.F.onTrap()]])
end
