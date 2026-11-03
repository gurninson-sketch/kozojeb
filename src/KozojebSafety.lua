-- Ochrona przy utracie widocznosci, prowadzacego i czlonka druzyny.
-- Zdarzenia korzystaja z istniejacej kolejki; bez stalego odpytywania.
do
local K,A=kozojeb,kozojeb.golemApi
local S={known={},deathRevisions={},lightStatus="brak potwierdzonej ciemnosci"}
K.S=S
function S.anonymous(name)
  local value=A.normal(name)
  return value=="" or value=="ktos" or value=="cos" or value=="nieznany"
end
local function deadState(member)
  for _,state in ipairs(member.states or {}) do
    if state=="dead" or state=="ghost" then return true end
  end
  return false
end
function S.isDead(member)
  if not member then return false end
  if A.normal(member.name):match("^duch%s+") or deadState(member) then return true end
  return K.config.teamDeaths[A.normal(member.name)]~=nil
end
function S.cancel()
  if S.lightTimer then pcall(killTimer,S.lightTimer) end
  S.lightTimer=nil;S.lightPending=nil
end
local function mark(kind,detail)
  if K.combatLog then K.combatLog.mark(kind,detail) end
end
local function remember(member)
  if not member or not member.id or S.anonymous(member.name) or S.isDead(member) then return end
  if not S.known[tostring(member.id)] then
    local count=0;for _ in pairs(S.known) do count=count+1 end
    if count>=32 then return end
  end
  S.known[tostring(member.id)]={name=member.name,id=tostring(member.id)}
end
local function death(name,id)
  local key=A.normal(name)
  if S.anonymous(key) or K.config.teamDeaths[key] then return end
  K.config.teamDeaths[key]={name=name,id=id,at=A.now()}
  S.deathRevisions[key]=K.dataRevision
  K.recoveryCritical=K.recoveryCritical or {};K.recoveryCritical[key]=true
  A.note("Zgon czlonka druzyny: "..name..". Patrol poczeka na zywa druzyne lub potwierdzony nowy sklad.","red")
  mark("team_death",{name=name,id=id});K.saveSettings();A.queue()
end
function S.onTeamDeath(name)
  if not K.enabled or K.sessionBlocked or S.anonymous(name) then return false end
  for id,member in pairs(S.known) do
    if A.normal(member.name)==A.normal(name) then
      local own=A.group().self
      if not own or tostring(own.id)~=id then death(member.name,id);return true end
    end
  end
  for _,member in ipairs(A.group().members) do
    if not A.isSelf(member) and A.normal(member.name)==A.normal(name) then death(member.name,tostring(member.id));return true end
  end
  return false
end
function S.lightAttempt()
  if not K.config.lightEnabled or not K.enabled or K.sessionBlocked or S.lightPending
      or not S.blind or S.blind.room~=A.room() then return end
  if S.lightAt and A.now()-S.lightAt<30 then return end
  local token={}
  S.lightAt=A.now();S.lightPending=token;S.lightStatus="czekam na potwierdzenie"
  mark("light_attempt",{command=K.config.lightCommand})
  send(K.config.lightCommand)
  if not S.lightPending then return end
  S.lightTimer=tempTimer(3,function()
    S.lightTimer=nil
    if not K.enabled or K.sessionBlocked or S.lightPending~=token then return end
    S.lightPending=nil;S.lightStatus="brak potwierdzenia"
    A.note("Swiatlo: brak potwierdzenia zapalenia. Sprawdz wlasna lampe i paliwo; bez ponawiania komend w petli.","red")
    mark("light_unconfirmed",{});A.queue()
  end)
end
function S.onLight()
  if not K.enabled and not S.lightPending then return end
  S.cancel();S.lightConfirmed=true;S.lightStatus="potwierdzone"
  S.lightRevision=K.sourceRevisions.entities
  mark("light_confirmed",{});if K.enabled then A.queue() end
end
-- Same braki danych albo anonimowy napastnik nie dowodza ciemnosci.
-- Reagujemy, gdy swieze encje nie pozwalaja rozpoznac zadnej postaci/NPC.
local function visibility()
  local hidden=false
  for _,entity in ipairs(A.entities()) do
    if entity.kind=="player" or entity.kind=="npc" then
      if not S.anonymous(entity.name) then return true,false end
      hidden=true
    end
  end
  return false,hidden
end
local function lostVisibility()
  if not S.blind then
    S.blind={room=A.room(),at=A.now()};S.lightConfirmed=false;S.lightStatus="utrata widocznosci"
    A.note("Brak widocznosci w tym pokoju. /kozojeb swiatlo on pozwala zapalic wlasne swiatlo.","red")
    mark("visibility_lost",{})
    if not A.isFollower() and not K.roomChangePending
        and (K.mode=="patrol" or K.mode=="combat" or K.mode=="chase") then
      if K.moveTimer then pcall(killTimer,K.moveTimer);K.moveTimer=nil end
      K.patrolMovePending=false;K.chaseMovePending=false
    end
    A.queue()
  end
  S.lightAttempt()
end
function S.onAttack(actor,defended)
  if not K.enabled or K.sessionBlocked or not S.anonymous(actor) then return end
  if A.normal(defended)~="cie" or not A.group().self then return end
  local _,hidden=visibility()
  if hidden then lostVisibility() end
  if K.combatLog then K.combatLog.request() end
end
function S.onLinkdead(name)
  if not K.enabled or K.sessionBlocked then return end
  for _,member in ipairs(A.group().members) do
    if A.normal(member.name)==A.normal(name) then
      if S.lastLinkdead~=tostring(member.id) or A.now()-(S.lastLinkdeadAt or 0)>5 then
        S.lastLinkdead=tostring(member.id);S.lastLinkdeadAt=A.now()
        mark("member_linkdead",{name=member.name,id=tostring(member.id)})
      end
      return
    end
  end
end
function S.observe(event)
  if K.sessionBlocked or not K.entitiesReady or K.roomChangePending then return end
  local context=A.group()
  local own=context.self
  if own and not S.anonymous(own.name) and not S.isDead(own) then S.profile=own.name end
  if event=="gmcp.Chimera.Group.State" then S.groupAt=A.now() end
  if event=="gmcp.Chimera.Room.Entities" then S.entitiesAt=A.now() end
  local raw=gmcp and gmcp.Chimera and gmcp.Chimera.Group and gmcp.Chimera.Group.State or {}
  local members={}
  for _,member in ipairs(context.members) do members[#members+1]=member end
  if K.sessionFresh.group then
    for _,member in pairs(raw.members or {}) do if type(member)=="table" then members[#members+1]=member end end
  end
  local currentIds={}
  for _,member in ipairs(members) do
    if member.id then currentIds[tostring(member.id)]=true end
    local value=A.health(member,context.memberVitals[tostring(member.id)])
    local ghost=A.normal(member.name):match("^duch%s+(.+)$")
    if ghost and not A.isSelf(member) and (not own or tostring(member.id)~=tostring(own.id)) and K.enabled then
      local previous=S.known[tostring(member.id)]
      if previous then death(previous.name,tostring(member.id))
      else
        for _,known in pairs(S.known) do
          if A.form(known.name)==ghost then death(known.name,known.id);break end
        end
      end
    elseif K.enabled and not A.isSelf(member) and (not own or tostring(member.id)~=tostring(own.id))
        and (deadState(member) or value and value.hp==0) then
      local previous=S.known[tostring(member.id)]
      death(previous and previous.name or member.name,tostring(member.id))
    elseif not S.anonymous(member.name) and member.id then
      local key=A.normal(member.name)
      local held=K.config.teamDeaths[key]
      local visible=A.entity(member.id)
      local groupMember=context.memberVitals[tostring(member.id)]
      local revision=S.deathRevisions[key] or 0
      if held and value and value.hp>0 and visible and A.normal(visible.name)==key
          and groupMember and A.normal(groupMember.name)==key
          and not deadState(visible) and not deadState(groupMember)
          and K.sourceRevisions.group>revision and K.sourceRevisions.entities>revision then
        K.config.teamDeaths[key]=nil
        S.deathRevisions[key]=nil
        K.recoveryCritical=K.recoveryCritical or {};K.recoveryCritical[key]=true
        A.note("Potwierdzono zywego czlonka druzyny: "..member.name..". Przed patrolem wymagane 100% HP.","green")
        mark("team_member_alive",{name=member.name,id=tostring(member.id)});K.saveSettings()
      end
      remember(member)
    end
  end
  local count=0;for _ in pairs(S.known) do count=count+1 end
  if count>=32 or event=="gmcp.Chimera.Group.State" then
    for id in pairs(S.known) do if not currentIds[id] then S.known[id]=nil end end
  end
  if K.enabled and (event=="gmcp.Chimera.Room.Entities" or event==nil) then
    local visible,hidden=visibility()
    if hidden then lostVisibility()
    elseif visible then
      local wasBlind=S.blind~=nil
      S.cancel();S.blind=nil;S.visibilityWait=nil;S.lightStatus="widocznosc dostepna"
      if wasBlind then mark("visibility_restored",{});A.queue() end
    end
  end
end
function S.roomChanged()
  if S.blind and S.blind.room~=A.room() then
    S.cancel();S.blind=nil;S.visibilityWait=nil;S.lightStatus="brak potwierdzonej ciemnosci"
  end
  if K.entitiesReady then S.observe("gmcp.Chimera.Room.Entities") end
end
function S.firstDeath()
  local names={};for name in pairs(K.config.teamDeaths) do names[#names+1]=name end
  table.sort(names);return names[1] and K.config.teamDeaths[names[1]]
end
function S.check()
  local held=S.firstDeath()
  if not held or A.isFollower() or K.mode=="escape" or K.mode=="heal_rest" or K.mode=="recovery_return" then return true end
  K.escape("Zgon czlonka druzyny: "..held.name..".",held.name);return false
end
function S.inspect()
  if not S.blind or A.isFollower() or K.mode=="escape" or K.mode=="heal_rest" or K.mode=="recovery_return" then return true end
  S.visibilityWait="Brak rozpoznania otoczenia; sprawdz swiatlo"
  return false
end
function S.session()
  S.cancel();S.known={};S.deathRevisions={};S.profile=nil;S.lightConfirmed=nil;S.lightAt=nil
  S.lightStatus="brak potwierdzonej ciemnosci";S.blind=nil;S.visibilityWait=nil
  S.groupAt=nil;S.entitiesAt=nil;S.lastLinkdead=nil
end
function S.started()
  S.observe();S.lightAttempt()
end
function S.ready()
  if A.isFollower() then A.note("Nowy sklad potwierdza profil prowadzacego.","yellow");return end
  if not K.entitiesReady or K.sessionBlocked or K.roomChangePending or not K.sessionFresh.group or S.blind or A.threat() then
    A.note("Potwierdzenie skladu wymaga swiezej druzyny poza walka.","red");return
  end
  local context=A.group()
  if context.actualLeader and not A.isSelf(context.actualLeader) then return end
  if not context.actualLeader and #context.members>1 then
    A.note("Czekam na jednoznaczne prowadzenie druzyny w GMCP.","red");return
  end
  local involved={}
  for _,member in ipairs(context.members) do involved[tostring(member.id)]=true end
  if context.self then involved[tostring(context.self.id)]=true end
  local combat=K.combatLogApi.combat()
  for _,relation in ipairs(combat.relations or {}) do
    if involved[tostring(relation.attacker)] or involved[tostring(relation.defender)] then
      A.note("Nie mozna potwierdzic skladu podczas walki druzyny.","red");return
    end
  end
  if combat.primary and tostring(combat.primary)~="" and not A.entity(combat.primary) then
    A.note("Czekam na rozpoznanie celu walki.","red");return
  end
  for _,member in ipairs(context.members) do
    if S.isDead(member) or S.anonymous(member.name) then A.note("W skladzie nadal widoczna jest martwa lub nierozpoznana postac.","red");return end
  end
  local raw=gmcp and gmcp.Chimera and gmcp.Chimera.Group and gmcp.Chimera.Group.State or {}
  for _,member in pairs(raw.members or {}) do
    if type(member)~="table" or not A.entity(member.id) or S.isDead(member) then
      A.note("Czekam na kompletny, zywy sklad w pokoju.","red");return
    end
  end
  K.config.teamDeaths={};K.recoveryRoster=nil;K.recoveryCritical={}
  A.note("Potwierdzono obecny zywy sklad druzyny.","green");K.saveSettings();if K.enabled then A.queue() end
end
function S.command(rest)
  local value=A.normal(rest)
  if value=="on" or value=="off" then
    K.config.lightEnabled=value=="on"
    S.cancel();S.lightAt=nil
    A.note("Automatyczne swiatlo w ciemnosci: "..(K.config.lightEnabled and "wlaczone" or "wylaczone").."; "..K.config.lightCommand..".","green")
    if K.config.lightEnabled then S.lightAttempt() end
  elseif value:match("^komenda%s+") then
    local command=rest:match("^%S+%s+(.+)$")
    if not command or #command>100 or command:find("[%c;|]") then A.note("Podaj jedna komende zapalenia swiatla (do 100 znakow).","red");return end
    K.config.lightCommand=command;S.lightConfirmed=nil;S.lightAt=nil
    A.note("Komenda wlasnego swiatla: "..command..".","green")
  else A.note("Swiatlo: "..(K.config.lightEnabled and "on" or "off").."; "..S.lightStatus.."; komenda "..K.config.lightCommand..".","cyan") end
end
K.handlers.triggers[#K.handlers.triggers+1]=tempRegexTrigger("^Zapalasz (?:.* )?(?:lampe|pochodnie|latarnie)\\.$",[[kozojeb.S.onLight()]])
K.handlers.triggers[#K.handlers.triggers+1]=tempRegexTrigger("^.*lampa jest juz zapalona\\.$",[[kozojeb.S.onLight()]])
K.handlers.triggers[#K.handlers.triggers+1]=tempRegexTrigger("^([A-Za-z-]+) traci kontakt z rzeczywistoscia\\.$",[[kozojeb.S.onLinkdead(matches[2])]])
end
