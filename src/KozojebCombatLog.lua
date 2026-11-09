-- Lokalna diagnostyka. Bez komend do gry, IPC i zmiany decyzji bojowych.
do
local K,A=kozojeb,kozojeb.combatLogApi
local L={received={},buffer={},bufferBytes=0,records=0,samples=0,writes=0,dropped=0,
  maxBytes=8*1024*1024,interval=1,flushDelay=5,session=A.now(),timing={}}
K.combatLog=L
local arrayMeta={}
local function array() return setmetatable({},arrayMeta) end
local function tab(value) return type(value)=="table" and value or {} end
local function number(value)
  local n=tonumber(value)
  if n and n==n and n~=math.huge and n~=-math.huge then return n end
end
local function measured(kind,cpu,wall)
  local stat=L.timing[kind]
  if not stat then stat={count=0,cpu=0,wall=0,maxCpu=0,maxWall=0,cpuWindow={},wallWindow={}};L.timing[kind]=stat end
  cpu,wall=math.max(0,cpu),math.max(0,wall)
  stat.count=stat.count+1;stat.cpu=stat.cpu+cpu;stat.wall=stat.wall+wall
  stat.maxCpu=math.max(stat.maxCpu,cpu);stat.maxWall=math.max(stat.maxWall,wall)
  local slot=(stat.count-1)%128+1
  stat.cpuWindow[slot],stat.wallWindow[slot]=cpu,wall
end
function L.performance(percentiles)
  local result={window=128}
  local function p95(values)
    local copy={};for i,value in ipairs(values) do copy[i]=value end
    table.sort(copy);return copy[math.ceil(#copy*0.95)] or 0
  end
  for _,kind in ipairs({"capture","flush"}) do
    local stat=L.timing[kind]
    local row={count=stat and stat.count or 0,cpu_avg_ms=0,wall_avg_ms=0,cpu_max_ms=0,wall_max_ms=0}
    if stat then
      row.cpu_avg_ms=stat.cpu/stat.count;row.wall_avg_ms=stat.wall/stat.count
      row.cpu_max_ms=stat.maxCpu;row.wall_max_ms=stat.maxWall
    end
    if percentiles then
      row.cpu_p95_ms=stat and p95(stat.cpuWindow) or 0;row.wall_p95_ms=stat and p95(stat.wallWindow) or 0
    end
    result[kind]=row
  end
  return result
end
function L.showPerformance()
  local report=L.performance(true)
  for _,kind in ipairs({"capture","flush"}) do
    local s=report[kind]
    A.note(string.format("Zapis walki - %s (%d): CPU sr./p95/max %.3f/%.3f/%.3f ms; czas sr./p95/max %.3f/%.3f/%.3f ms.",
      kind=="capture" and "przygotowanie" or "plik",s.count,s.cpu_avg_ms,s.cpu_p95_ms,s.cpu_max_ms,
      s.wall_avg_ms,s.wall_p95_ms,s.wall_max_ms),"cyan")
  end
end
local function text(value,limit)
  if value==nil then return nil end
  local s=tostring(value)
  local cut=limit or 160
  if #s<=cut then return s end
  while s:byte(cut+1) and s:byte(cut+1)>=128 and s:byte(cut+1)<192 do cut=cut-1 end
  return s:sub(1,cut)
end
local function encode(value)
  local kind=type(value)
  if kind=="nil" then return "null"
  elseif kind=="boolean" then return value and "true" or "false"
  elseif kind=="number" then return number(value) and tostring(value) or "null"
  elseif kind=="string" then
    return '"'..value:gsub('[%z\1-\31\\"]',function(c)
      if c=='"' then return '\\"' elseif c=='\\' then return '\\\\' end
      return string.format("\\u%04x",c:byte())
    end)..'"'
  end
  local pieces={}
  if getmetatable(value)==arrayMeta then
    for _,item in ipairs(value) do pieces[#pieces+1]=encode(item) end
    return "["..table.concat(pieces,",").."]"
  end
  local keys={}
  for key in pairs(value) do if type(key)=="string" then keys[#keys+1]=key end end
  table.sort(keys)
  for _,key in ipairs(keys) do pieces[#pieces+1]=encode(key)..":"..encode(value[key]) end
  return "{"..table.concat(pieces,",").."}"
end
local function cancel(name)
  if L[name] then pcall(killTimer,L[name]);L[name]=nil end
end
local function recording() return K.config.combatLogEnabled and not L.fault end
local function paths()
  if not L.path then
    local ok,home=pcall(getMudletHomeDir)
    if not ok or type(home)~="string" or home=="" then error("brak katalogu profilu") end
    L.path=home.."/kozojeb-walka.jsonl"
    L.backup=L.path..".1"
  end
  return L.path,L.backup
end
local function failed()
  L.fault=true;L.dropped=L.dropped+#L.buffer;L.buffer={};L.bufferBytes=0
  cancel("sampleTimer");cancel("flushTimer")
  A.note("Zapis walki wstrzymany: nie udalo sie zapisac pliku. Bot dziala dalej. Sprawdz /kozojeb zapis status.","yellow")
end
function L.flush()
  cancel("flushTimer")
  if #L.buffer==0 or L.fault then return end
  local cpu,wall=os.clock(),A.now()
  local file
  local ok=pcall(function()
    local path,backup=paths()
    file=assert(io.open(path,"ab"))
    local size=assert(file:seek("end"))
    if size>0 and size+L.bufferBytes>L.maxBytes then
      assert(file:close());file=nil
      os.remove(backup)
      assert(os.rename(path,backup))
      file=assert(io.open(path,"wb"))
    end
    assert(file:write(table.concat(L.buffer)))
    assert(file:close());file=nil
  end)
  if file then pcall(function() file:close() end) end
  measured("flush",(os.clock()-cpu)*1000,(A.now()-wall)*1000)
  if not ok then failed();return end
  L.writes=L.writes+1;L.buffer={};L.bufferBytes=0
end
local function append(record)
  record.schema=1;record.version=K.version;record.session=L.session
  record.time=math.floor(A.now()*1000+0.5)/1000
  record.seq=L.records+1
  record.dropped=L.dropped
  local line=encode(record).."\n"
  if #line>65536 then L.dropped=L.dropped+1;return false end
  L.records=L.records+1;L.buffer[#L.buffer+1]=line;L.bufferBytes=L.bufferBytes+#line
  if L.bufferBytes>=32768 then L.flush()
  elseif not L.flushTimer then L.flushTimer=tempTimer(L.flushDelay,function() L.flushTimer=nil;L.flush() end) end
  return true
end
local function health(raw)
  raw=tab(raw)
  local hp,maximum=number(raw.hp),number(raw.maxhp or raw.max_hp)
  if hp and maximum and maximum>0 and hp>=0 and hp<=maximum then
    return {hp=hp,maxhp=maximum,percent=hp*100/maximum}
  end
end
local function ordered(rows,key)
  table.sort(rows,function(a,b) return tostring(a[key] or "")<tostring(b[key] or "") end)
  return rows
end
local function snapshot()
  local gm=tab(gmcp);local ch=tab(gm.Chimera)
  local group=tab(tab(ch.Group).State)
  local entities=tab(tab(ch.Room).Entities)
  local rawCombat=tab(tab(ch.Combat).State)
  local combat=tab(A.combat())
  local index,groupVitals,roster={}, {}, {}
  local members,npcs,covers,relations=array(),array(),array(),array()
  local truncated=false
  for i,entity in ipairs(tab(entities.entities)) do
    if i>256 then truncated=true;break end
    if type(entity)=="table" and entity.id then index[tostring(entity.id)]=entity end
  end
  local groupCount=0
  for key,member in pairs(tab(group.members)) do
    groupCount=groupCount+1;if groupCount>256 then truncated=true;break end
    if type(member)=="table" then
      local id=member.id or member.entity_id or member.obname or member.chimera_source_id
      if id then groupVitals[tostring(id)]=member;roster[tostring(id)]=true end
    elseif type(member)=="string" or type(member)=="number" then roster[tostring(member)]=true end
  end
  local cached=K.groupContextCache
  if cached then
    for _,member in ipairs(cached.members) do roster[tostring(member.id)]=true end
  end
  for id,entity in pairs(index) do
    if A.isSelf(entity) or (group.members==nil and (entity.group_role=="leader" or entity.group_role=="member")) then roster[id]=true end
  end
  local ownId,rosterIds=nil,{}
  for id in pairs(roster) do rosterIds[#rosterIds+1]=id end
  table.sort(rosterIds,function(a,b)
    local first=A.isSelf(index[a]) or A.isSelf(groupVitals[a])
    local second=A.isSelf(index[b]) or A.isSelf(groupVitals[b])
    if first and not second then return true end
    if second and not first then return false end
    return a<b
  end)
  for _,id in ipairs(rosterIds) do
    if #members>=24 then truncated=true;break end
    local entity,raw=index[id] or {},groupVitals[id] or {}
    local fromEntity,fromGroup=health(entity),health(raw)
    local source=K.sourceRevisions.group>K.sourceRevisions.entities and "group" or "entities"
    local value
    if source=="group" then value=fromGroup else value=fromEntity end
    if not value then source=source=="group" and "entities" or "group";value=source=="group" and fromGroup or fromEntity end
    local states=array()
    for i,state in ipairs(tab(entity.states)) do if i<=16 then states[#states+1]=text(state) else truncated=true;break end end
    local own=A.isSelf(entity) or A.isSelf(raw)
    if own then ownId=id end
    local row={id=text(id),name=text(entity.name or raw.name or raw.desc or id),self=own or false,
      here=raw.here,visible=index[id]~=nil,hp=value and value.hp,maxhp=value and value.maxhp,
      percent=value and value.percent,hp_source=value and source,group_hp=fromGroup,entities_hp=fromEntity,
      stamina=number(raw.stamina),maxstamina=number(raw.maxstamina),states=states,incoming=array(),unresolved_incoming=array()}
    members[#members+1]=row
  end
  ordered(members,"id")
  local byMember={}
  for _,member in ipairs(members) do byMember[member.id]=member end
  local incomingSeen={}
  local active=A.liveNpc(index[tostring(combat.primary)]) and true or false
  if combat.primary and tostring(combat.primary)~="" and not index[tostring(combat.primary)] then active=true end
  local unresolved=0
  for i,relation in ipairs(tab(combat.relations)) do
    if i>128 then truncated=true;break end
    local attacker,defender=text(relation.attacker),text(relation.defender)
    relations[#relations+1]={attacker=attacker,defender=defender}
    local npc=index[tostring(relation.attacker)]
    local target=byMember[tostring(relation.defender)]
    local edge=tostring(attacker)..">"..tostring(defender)
    if byMember[tostring(relation.attacker)] and A.liveNpc(index[tostring(relation.defender)]) then active=true end
    if A.liveNpc(npc) and target and not incomingSeen[edge] then
      incomingSeen[edge]=true;target.incoming[#target.incoming+1]=text(npc.id)
    elseif target and not index[tostring(relation.attacker)] and attacker and attacker~=""
        and not byMember[tostring(relation.attacker)] and not incomingSeen[edge] then
      incomingSeen[edge]=true;target.unresolved_incoming[#target.unresolved_incoming+1]=attacker
      unresolved=unresolved+1;active=true
    end
    if byMember[tostring(relation.attacker)] and defender and defender~="" and not index[tostring(relation.defender)] then active=true end
  end
  for _,member in ipairs(members) do
    table.sort(member.incoming);member.npc_count=#member.incoming
    table.sort(member.unresolved_incoming)
    if member.npc_count>0 then active=true end
  end
  local npcIds={}
  for id,entity in pairs(index) do if entity.kind=="npc" then npcIds[#npcIds+1]=id end end
  table.sort(npcIds)
  for i,id in ipairs(npcIds) do
    if i>32 then truncated=true;break end
    local entity=index[id];local value=health(entity)
    npcs[#npcs+1]={id=text(id),name=text(entity.name),hp=value and value.hp,maxhp=value and value.maxhp,
      percent=value and value.percent}
  end
  for i,cover in ipairs(tab(rawCombat.covers)) do
    if i>128 then truncated=true;break end
    covers[#covers+1]={guard=text(cover.guard),guarded=text(cover.guarded)}
  end
  table.sort(covers,function(a,b) return (a.guard or "")..":"..(a.guarded or "")<(b.guard or "")..":"..(b.guarded or "") end)
  table.sort(relations,function(a,b) return (a.attacker or "")..":"..(a.defender or "")<(b.attacker or "")..":"..(b.defender or "") end)
  local checks=array()
  for _,check in pairs(L.checks or {}) do checks[#checks+1]=check end
  ordered(checks,"key")
  local vitals=tab(tab(gm.Char).Vitals)
  local charHealth=health(vitals)
  local charPercent=not vitals.maxhp and not vitals.max_hp and number(vitals.hp) or nil
  if charPercent and (charPercent<0 or charPercent>100) then charPercent=nil end
  local pending=K.shieldPendingTarget
  local own=ownId and byMember[ownId]
  local state={kind="state",role=K.config.role,enabled=K.enabled,mode=K.mode,map_room=A.room(),
    entities_room=text(entities.room),combat_room=text(rawCombat.room),leader=text(cached and cached.actualLeader and cached.actualLeader.id or group.leader),
    primary=text(combat.primary),selected_target=text(K.currentTargetId),profile=K.S and K.S.profile or own and own.name,
    cargo_phase=K.G and K.G.job and K.G.job.phase,
    members=members,npcs=npcs,relations=relations,covers=covers,truncated=truncated or L.checksTruncated or false,
    ready={entities=K.entitiesReady,combat=K.combatRoomReady,session_blocked=K.sessionBlocked,
      room_pending=K.roomChangePending,combat_source=K.combatRoomReady and K.sessionFresh.combat and "GMCP" or "text_or_unknown"},
    movement={from=K.moveSnapshot and K.moveSnapshot.from,direction=text(K.sentDirection),
      limit_room=K.limitRoom and K.limitRoom.room,limit_count=K.limitRoom and K.limitRoom.count,
      limit_attempts=K.limitRoom and K.limitRoom.attempts,walker_stopped=K.escapeWalkerStop~=nil},
    safety={unresolved_incoming=unresolved,visibility_lost=K.S and K.S.blind~=nil or false,
      leader_present=cached and cached.actualLeader~=nil or false,wait_reason=text(K.supportWaitReason),
      death_hold=K.S and K.S.firstDeath()~=nil or false,light_enabled=K.config.lightEnabled,
      light_status=K.S and text(K.S.lightStatus)},
    char_vitals={hp_points=charHealth,hp_percent=charPercent,fatigue=number(vitals.fatigue)},
    shield={formation_ready=K.shieldFormationReady,self_control_percent=K.lastHp,pending=pending and text(pending.id),
      pending_until=pending and pending.deadline,await_combat_revision=K.shieldAwaitCombatRevision,
      last_block=text(K.shieldBlockedReason),checks=checks,status=L.decisionStatus or "no_shield_selected",
      role_enabled=K.config.role~="wsparcie"},
    settings={own_min=K.config.shieldSelfHp,team_shield=K.config.teamShieldHp,leader_shield=K.config.leaderShieldHp,
      own_retreat=K.config.escapeHp,team_retreat=K.config.teamEscapeHp,max_npc=K.config.shieldMaxAttackers,
      hold=K.config.shieldHold,golems=K.config.golemsEnabled,hp_gap=K.config.shieldHpGap}}
  local wounded=(charPercent and charPercent<100) or (charHealth and charHealth.percent<100) or false
  for _,member in ipairs(members) do if member.percent and member.percent<100 then wounded=true end end
  return state,active or wounded or (K.S and K.S.blind~=nil) or false
end
function L.capture(force,cause)
  if L.fault or not force and not recording() then return end
  local cpu,wall=os.clock(),A.now()
  local flushCpu=L.timing.flush and L.timing.flush.cpu or 0
  local flushWall=L.timing.flush and L.timing.flush.wall or 0
  local written=false
  local ok=pcall(function()
    L.samples=L.samples+1;L.lastSampleAt=A.now()
    local state,active=snapshot()
    local recovery=K.mode=="heal_rest" or K.mode=="escape" or K.mode=="recovery_return" or K.mode=="golem_loot"
    if not force and not active and not L.active and not recovery then return end
    L.active=active or recovery
    local fingerprint=encode(state)
    if not force and fingerprint==L.fingerprint then return end
    L.fingerprint=fingerprint
    state.decision_time=L.decisionAt;state.cause=cause or "change"
    state.sources={}
    for _,name in ipairs({"entities","group","combat","char","room"}) do
      local at=L.received[name]
      local freshKey=name=="char" and "vitals" or name
      local age=at and math.max(0,A.now()-at)
      state.sources[name]={received=at,seen=at~=nil,fresh=K.sessionFresh[freshKey]==true,age=age,recent=age~=nil and age<=15,
        revision=name=="combat" and K.combatRevision or K.sourceRevisions[name]}
    end
    -- Metryki z zakonczonych operacji nie zmieniaja odcisku stanu gry.
    state.recorder_performance=L.performance(false)
    written=append(state)
    if written then L.lastSnapshot=state end
  end)
  -- Flush moze wystapic wewnatrz append; jego czasu nie liczymy drugi raz
  -- jako przygotowania probki. Nie obejmuje to calego procesu Mudleta.
  measured("capture",(os.clock()-cpu)*1000-((L.timing.flush and L.timing.flush.cpu or 0)-flushCpu),
    (A.now()-wall)*1000-((L.timing.flush and L.timing.flush.wall or 0)-flushWall))
  if not ok then failed() end
  return ok and written
end
local packetNames={["gmcp.Chimera.Room.Entities"]="entities",["gmcp.Chimera.Group.State"]="group",
  ["gmcp.Chimera.Combat.State"]="combat",["gmcp.Char.Vitals"]="char",["gmcp.Room.Info"]="room"}
function L.request()
  if not recording() or not K.enabled or L.sampleTimer then return end
  local combat=tab(A.combat())
  local vitals=tab(tab(tab(gmcp).Char).Vitals)
  local percent=not vitals.maxhp and not vitals.max_hp and number(vitals.hp)
  local woundedPercent=percent and percent>=0 and percent<100
  if not L.active and not next(tab(combat.relations)) and (not combat.primary or combat.primary=="")
      and K.mode~="heal_rest" and K.mode~="escape" and K.mode~="recovery_return" and K.mode~="golem_loot"
      and not (K.S and K.S.blind) and not woundedPercent
      and not (K.lastHp<100 or K.teamSeenCount>0 and K.teamLowestHp<100) then return end
  local delay=math.max(0.2,L.interval-(A.now()-(L.lastSampleAt or -L.interval)))
  L.sampleTimer=tempTimer(delay,function()
    L.sampleTimer=nil
    if recording() and K.enabled then L.capture(false) end
  end)
end
function L.packet(event)
  local source=packetNames[event]
  if source then L.received[source]=A.now() end
  L.request()
end
function L.beginDecision()
  if not recording() then return end
  L.decisionAt=A.now();L.decisionStatus="no_shield_selected";L.checks={};L.checkCount=0;L.checksTruncated=false
  L.request()
end
function L.reason(target,npc,code,rotation,detail)
  if not recording() or not K.enabled then return end
  local id=type(target)=="table" and target.id or target
  local key=tostring(id or "*")..":"..tostring(npc or "*")..":"..tostring(rotation or false)
  L.checks=L.checks or {};L.checkCount=L.checkCount or 0
  if not L.checks[key] then
    if L.checkCount>=64 then L.checksTruncated=true;return end
    L.checkCount=L.checkCount+1
  end
  L.checks[key]={key=text(key,240),target=text(id),npc=text(npc),code=text(code),rotation=rotation or false,detail=text(detail,240)}
end
function L.mark(kind,detail)
  if not recording() or not (K.enabled or L.active) then return end
  if kind=="shield_sent" then L.decisionStatus="sent" end
  local ok=pcall(append,{kind=kind,map_room=A.room(),role=K.config.role,detail=detail})
  if not ok then failed() end
  L.request()
end
function L.close(kind,detail)
  if recording() and (K.enabled or L.active) then L.capture(true,kind);L.mark(kind,{reason=text(detail,240)}) end
  cancel("sampleTimer");L.flush();L.active=false
  L.fingerprint=nil;L.checks={};L.checkCount=0;L.checksTruncated=false
end
function L.boundary(kind)
  L.close(kind)
  L.received={};L.session=A.now();L.lastSampleAt=nil
end
function L.command(rest)
  local action=A.normal(rest)
  if action=="on" then
    K.config.combatLogEnabled=true;L.fault=nil;L.fingerprint=nil;K.saveSettings();L.request()
    A.note("Zapis walki wlaczony; maksymalnie jeden zmieniony stan na sekunde, zdarzenia zaslon osobno.","green")
  elseif action=="off" then
    L.close("recording_off");K.config.combatLogEnabled=false;K.saveSettings()
    A.note("Automatyczny zapis walki wylaczony.","cyan")
  elseif action=="teraz" then
    L.fault=nil;local written=L.capture(true,"manual");L.flush()
    if not L.fault and written then A.note("Zapisano stan GMCP do "..paths(),"green")
    elseif not L.fault then A.note("Stan przekroczyl limit pojedynczego rekordu. Sprawdz /kozojeb zapis status.","yellow") end
  elseif action=="" or action=="status" then
    local ok,path,backup=pcall(paths)
    A.note("Zapis walki: "..(L.fault and "blad zapisu" or K.config.combatLogEnabled and "wlaczony" or "wylaczony")
      .."; rekordy "..L.records..", partie zapisu "..L.writes..", pominiete "..L.dropped..".","cyan")
    if ok then A.note("Pliki: "..path.." oraz "..backup.." (po rotacji). Limit 8 MiB na plik.","cyan") end
    L.showPerformance()
  else A.note("Uzycie: /kozojeb zapis on|off|status|teraz.","yellow") end
end
end
