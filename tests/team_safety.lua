local file=assert(io.open("tests/roles.lua","r"));local source=file:read("*a");file:close()
local header=assert(source:match('^(.-)test%("second line supports'))
local cases=[====[
local function withoutLeader(role,ownHp,patientHp)
  reset(role or "zaslony");kozojeb.start();sends={}
  local e=gmcp.Chimera.Room.Entities.entities
  e[1].hp=ownHp or 100;e[3].hp=patientHp or 40
  gmcp.Char.Vitals.hp=e[1].hp
  table.remove(e,2)
  gmcp.Chimera.Combat.State={primary="N",relations={{attacker="N",defender="M"},{attacker="M",defender="N"}}}
  event();event("gmcp.Chimera.Combat.State");event("gmcp.Char.Vitals")
  return e
end
local function leader()
  reset("prowadzacy")
  local e=gmcp.Chimera.Room.Entities.entities
  e[1].group_role="leader";e[2].group_role="member"
  gmcp.Chimera.Group.State={leader="S",members={}}
  for i=1,3 do
    local m=e[i];gmcp.Chimera.Group.State.members[i]={id=m.id,name=m.name,hp=m.hp,maxhp=m.maxhp,self=i==1 and 1 or 0,here=1}
  end
  gmcp.Chimera.Combat.State={primary="",relations={}}
  kozojeb.setRooms({1322,1323});kozojeb.start()
  return e
end
local function shields()
  local result={};for _,command in ipairs(sends) do if command:match("^zaslon ") then result[#result+1]=command end end
  return result
end
local function multiple(number)
  reset("zaslony")
  local e=gmcp.Chimera.Room.Entities.entities
  e[1].hp=1000;e[1].maxhp=1000;e[2].hp=600;e[2].maxhp=1000;e[3].hp=1000;e[3].maxhp=1000
  gmcp.Char.Vitals={hp=1000,maxhp=1000,moves=100,maxmoves=100}
  e[4].name="Maly glupkowaty snotling"
  local names={"Brutalny smierdzacy ork","Blady zwinny ozywieniec","Niezgrabny powolny zombi","Wielki grozny troll"}
  local rel={{attacker="N",defender="L"}}
  for i=2,number do
    e[#e+1]={id="N"..i,name=names[i-1],kind="npc",hp=100,maxhp=100}
    rel[#rel+1]={attacker="N"..i,defender="L"}
  end
  gmcp.Chimera.Combat.State={primary="",relations=rel}
  return e
end

test("visible wounded members remain protected while the leader is absent",function()
  withoutLeader();assert(count("zaslon morrida")==1 and kozojeb.mode=="support_wait")
  assert(kozojeb.supportWaitReason and count("wesprzyj")==0);noMovement()
end)
test("loss of the leader cannot freeze the follower's own HP at a hundred percent",function()
  withoutLeader("zaslony",10,40)
  assert(kozojeb.lastHp==10 and kozojeb.ownHealth.hp==10 and #shields()==0);noMovement()
end)
test("zero HP without a visible leader stops the profile",function()
  withoutLeader("zaslony",0,40);assert(not kozojeb.enabled and kozojeb.mode=="stop");noMovement()
end)
test("a DPS follower never shields or leaves the party after leader loss",function()
  withoutLeader("wsparcie");assert(#shields()==0 and kozojeb.enabled);noMovement()
end)
test("leader loss does not allow defending an unrelated bystander",function()
  reset("zaslony");kozojeb.start();sends={}
  local e=gmcp.Chimera.Room.Entities.entities;table.remove(e,2)
  e[#e+1]={id="X",name="Obcy",kind="player",hp=10,maxhp=100}
  gmcp.Chimera.Combat.State={primary="N",relations={{attacker="N",defender="X"}}}
  event();assert(#shields()==0);noMovement()
end)
test("a fresh disband prevents former member shields even without the leader",function()
  withoutLeader("wsparcie");kozojeb.command("rola zaslony")
  gmcp.Chimera.Group.State={members={}};kozojeb.start();event("gmcp.Chimera.Group.State")
  assert(#shields()==0);noMovement()
end)
test("remaining golem defenders can protect a teammate after the leader disappears",function()
  reset("zaslony")
  local e=gmcp.Chimera.Room.Entities.entities
  table.remove(e,2);e[1].hp=1000;e[1].maxhp=1000;e[2].hp=600;e[2].maxhp=1000
  gmcp.Char.Vitals={hp=1000,maxhp=1000,moves=100,maxmoves=100}
  table.remove(e,3)
  local rel={}
  for i,name in ipairs({"Pekaty skrzypiacy golem","Nieforemny porysowany golem","Kanciasty zgrzytajacy golem","Zelazny golem"}) do
    e[#e+1]={id="N"..i,name=name,kind="npc",hp=100,maxhp=100}
    rel[#rel+1]={attacker="N"..i,defender="M"}
  end
  gmcp.Chimera.Combat.State={primary="N1",relations=rel}
  kozojeb.command("golemy on");kozojeb.start();advance(2)
  assert(#shields()>0 and kozojeb.shieldDecision.maxOwnAttackers<=2);noMovement()
end)
test("new profiles have an empty name independent team role model",function()
  reset();assert(next(kozojeb.config.teamRoles)==nil and kozojeb.config.teamRoleRulesVersion==1)
end)
test("only the unchanged legacy default role set is migrated once",function()
  reset();kozojeb.config.teamRoles={brix="wsparcie",gunz="wsparcie",rodrick="wsparcie"}
  kozojeb.config.teamRoleRulesVersion=nil;kozojeb.saveSettings();kozojeb=nil;loadCore()
  assert(next(kozojeb.config.teamRoles)==nil and kozojeb.config.teamRoleRulesVersion==1)
end)
test("a custom legacy team model survives migration",function()
  reset();kozojeb.config.teamRoles={aldor="wsparcie",beren="zaslony"}
  kozojeb.config.teamRoleRulesVersion=nil;kozojeb.saveSettings();kozojeb=nil;loadCore()
  assert(kozojeb.config.teamRoles.aldor=="wsparcie" and kozojeb.config.teamRoles.beren=="zaslony")
end)
test("new explicit rules matching old names are user configuration and survive reloading",function()
  reset();for _,name in ipairs({"Brix","Gunz","Rodrick"}) do kozojeb.command("druzyna rola "..name.." wsparcie") end
  kozojeb=nil;loadCore();assert(kozojeb.config.teamRoles.brix=="wsparcie" and kozojeb.config.teamRoles.gunz=="wsparcie")
end)
test("the generic team model reset removes only explicit role rules",function()
  reset();kozojeb.config.teamMembers.aldor=true;kozojeb.command("druzyna rola Aldor wsparcie")
  kozojeb.command("druzyna role reset");kozojeb=nil;loadCore()
  assert(next(kozojeb.config.teamRoles)==nil and kozojeb.config.teamMembers.aldor)
end)
test("a targeted cover can split three attackers without stacking them all on the defender",function()
  multiple(3);kozojeb.start();assert(#shields()==1 and shields()[1]:find(" przed ",1,true))
  assert(kozojeb.shieldDecision.maxOwnAttackers==1 and kozojeb.shieldDecision.targetAttackers==3);noMovement()
end)
test("disabling targeted covers retains the conservative full transfer limit",function()
  multiple(3);kozojeb.command("celowanezaslony off");kozojeb.start();assert(#shields()==0);noMovement()
end)
test("targeted covers retain the actual HP minimum",function()
  local e=multiple(3);e[1].hp=490;gmcp.Char.Vitals.hp=490
  kozojeb.start();assert(#shields()==0);noMovement()
end)
test("an unrecognized NPC noun cannot produce a guessed targeted selector",function()
  local e=multiple(3);for i=4,#e do e[i].name="Nieznana istota "..i end
  kozojeb.start();assert(#shields()==0);noMovement()
end)
test("the received NPC death invalidates a targeted plan before it can be sent",function()
  local e=multiple(3);kozojeb.shieldFormationReady=false;kozojeb.start()
  local _,plan=kozojeb.C.project(e[1],e[2],60);assert(plan)
  kozojeb.deadNpcIds[plan.npcId]={at=clock}
  assert(not kozojeb.C.validate(e[1],e[2],60,plan));noMovement()
end)
test("mixed owners of the same description do not allow ordinal guessing",function()
  local e=multiple(3);e[4].name="Blady zwinny ozywieniec";e[5].name=e[4].name
  gmcp.Chimera.Combat.State.relations={{attacker="N",defender="L"},{attacker="N2",defender="M"},{attacker="N3",defender="L"}}
  kozojeb.start();assert(not kozojeb.C.selector("N",e[2]));noMovement()
end)
test("identical NPCs with the same patient use an ordinal inside their description only",function()
  local e=multiple(3);for i=4,#e do e[i].name="Blady zwinny ozywieniec" end
  kozojeb.start();assert(shields()[1]=="zaslon yarrima przed pierwszym bladym zwinnym ozywiencem");noMovement()
end)
test("general cover confirmation never assigns the planned NPC from a different reply",function()
  local e=multiple(3);kozojeb.start();local pending=kozojeb.shieldPendingTarget
  assert(pending and pending.generalPlan)
  kozojeb.onShieldResult("Yarrima",true,"niezgrabnego powolnego zombiego")
  assert(not kozojeb.shieldRescue and kozojeb.C.rejected[pending.golemSelector]);noMovement()
end)
test("a named peer cover can briefly reserve a general NPC before its GMCP transfer",function()
  local e=multiple(3);kozojeb.shieldFormationReady=false;kozojeb.start()
  kozojeb.C.onTeamCover("Morrid","Yarrima","bladego zwinnego ozywienca")
  local _,plan=kozojeb.C.project(e[1],e[2],60)
  assert(plan and plan.npcId~="N3")
  local deadline=kozojeb.C.pending["M:L"].deadline
  for i=1,2000 do kozojeb.C.onTeamCover("Morrid","Yarrima","bladego zwinnego ozywienca") end
  assert(kozojeb.C.pending["M:L"].deadline==deadline);noMovement()
end)
test("general cover reservations are cleared on stop and session boundaries",function()
  for _,boundary in ipairs({"stop","disconnect"}) do
    multiple(3);kozojeb.shieldFormationReady=false;kozojeb.start()
    kozojeb.C.onTeamCover("Morrid","Yarrima","bladego zwinnego ozywienca");assert(kozojeb.C.timer)
    if boundary=="stop" then kozojeb.stop() else kozojeb.onSessionEvent("sysDisconnectionEvent") end
    assert(not kozojeb.C.timer and next(kozojeb.C.pending)==nil);advance(1);noMovement()
  end
end)
test("a teammate death holds patrol even while the remaining party has full HP",function()
  leader();kozojeb.onKill("Morrid",false);advance(.13)
  assert(kozojeb.config.teamDeaths.morrid and kozojeb.mode=="heal_rest")
  assert(not kozojeb.recoveryReadiness())
end)
test("NPC deaths cannot create player death holds",function()
  leader();kozojeb.onKill("Maly glupkowaty snotling",false)
  assert(next(kozojeb.config.teamDeaths)==nil)
end)
test("a ghost observed in the team marks the original player as dead",function()
  local e=leader();gmcp.Chimera.Group.State.members[3].name="Duch Morrida"
  gmcp.Chimera.Group.State.members[3].hp=13;e[3].name="Duch Morrida";e[3].hp=13
  event("gmcp.Chimera.Group.State");event()
  assert(kozojeb.config.teamDeaths.morrid and not kozojeb.golemApi.canShield(e[3]))
end)
test("a complete fresh zero HP team record creates a persistent death hold",function()
  leader();gmcp.Chimera.Group.State.members[3].hp=0
  event("gmcp.Chimera.Group.State")
  assert(kozojeb.config.teamDeaths.morrid and not kozojeb.recoveryReadiness())
end)
test("a server dead state is sufficient without a ghost name",function()
  local e=leader();e[3].states={"dead"};event();event("gmcp.Chimera.Group.State");event()
  assert(kozojeb.config.teamDeaths.morrid)
end)
test("an incomplete zero HP pair cannot invent a confirmed death",function()
  local e=leader();e[3].hp=0;e[3].maxhp=nil
  gmcp.Chimera.Group.State.members[3].hp=0;gmcp.Chimera.Group.State.members[3].maxhp=nil
  event();event("gmcp.Chimera.Group.State")
  assert(not kozojeb.S.firstDeath())
end)
test("own zero HP stops the bot without becoming a teammate death hold",function()
  local e=leader();e[1].hp=0;gmcp.Chimera.Group.State.members[1].hp=0
  event();event("gmcp.Chimera.Group.State")
  assert(not kozojeb.enabled and not kozojeb.S.firstDeath())
end)
test("a fresh group packet alone cannot revive a dead player from stale room entities",function()
  leader();kozojeb.onKill("Morrid",false);event("gmcp.Chimera.Group.State")
  assert(kozojeb.config.teamDeaths.morrid)
end)
test("a living returning teammate needs both fresh channels and then a full recovery",function()
  local e=leader();kozojeb.onKill("Morrid",false)
  e[3].hp=40;gmcp.Chimera.Group.State.members[3].hp=40
  event("gmcp.Chimera.Group.State");event()
  assert(not kozojeb.config.teamDeaths.morrid and kozojeb.recoveryCritical.morrid)
  assert(not kozojeb.recoveryReadiness())
  e[3].hp=100;gmcp.Chimera.Group.State.members[3].hp=100;event();event("gmcp.Chimera.Group.State")
  assert(kozojeb.recoveryReadiness())
end)
test("team death holds survive a package reload",function()
  leader();kozojeb.onKill("Morrid",false);kozojeb.saveSettings();kozojeb=nil;loadCore()
  assert(kozojeb.config.teamDeaths.morrid and kozojeb.S.firstDeath())
end)
test("the actual leader can explicitly confirm a smaller living party outside combat",function()
  local e=leader();kozojeb.onKill("Morrid",false);advance(.13)
  table.remove(e,3);table.remove(gmcp.Chimera.Group.State.members,3)
  event();event("gmcp.Chimera.Group.State");kozojeb.command("druzyna gotowa")
  assert(next(kozojeb.config.teamDeaths)==nil)
end)
test("confirming the party cannot bypass a ghost or ongoing combat",function()
  local e=leader();kozojeb.onKill("Morrid",false);advance(.13)
  e[3].name="Duch Morrida";gmcp.Chimera.Group.State.members[3].name="Duch Morrida"
  event();kozojeb.command("druzyna gotowa");assert(kozojeb.config.teamDeaths.morrid)
end)
test("followers record a teammate death without retreat or leaving the party",function()
  reset("zaslony");kozojeb.start();kozojeb.onKill("Morrid",false);advance(.13)
  assert(kozojeb.config.teamDeaths.morrid and kozojeb.mode~="escape");noMovement()
end)
test("a new party cannot be confirmed during unresolved combat",function()
  leader();kozojeb.onKill("Morrid",true);advance(.13)
  table.remove(gmcp.Chimera.Room.Entities.entities,3);table.remove(gmcp.Chimera.Group.State.members,3)
  event();event("gmcp.Chimera.Group.State")
  gmcp.Chimera.Combat.State={relations={{attacker="unknown",defender="S"}}}
  event("gmcp.Chimera.Combat.State");kozojeb.command("druzyna gotowa")
  assert(kozojeb.S.firstDeath())
end)
test("darkness blocks both recovery readiness and confirming a reduced party",function()
  leader();kozojeb.onKill("Morrid",true);advance(.13)
  table.remove(gmcp.Chimera.Room.Entities.entities,3);table.remove(gmcp.Chimera.Group.State.members,3)
  event();event("gmcp.Chimera.Group.State");kozojeb.onTeamCombat("Ktos","cie",true)
  kozojeb.command("druzyna gotowa");assert(kozojeb.S.firstDeath())
  assert(not kozojeb.recoveryReadiness())
end)
test("full HP alone cannot restart patrol while visibility is lost",function()
  leader();assert(kozojeb.recoveryReadiness())
  kozojeb.onTeamCombat("Ktos","cie",true)
  assert(not kozojeb.recoveryReadiness())
end)
test("ambiguous leadership cannot confirm a reduced party",function()
  local e=leader();kozojeb.onKill("Morrid",true);advance(.13)
  table.remove(e,3);table.remove(gmcp.Chimera.Group.State.members,3)
  e[2].group_role="leader";gmcp.Chimera.Group.State.leader=nil
  event();event("gmcp.Chimera.Group.State");kozojeb.command("druzyna gotowa")
  assert(kozojeb.S.firstDeath())
end)
test("a former teammate's death after a fresh disband cannot hold solo patrol",function()
  leader();gmcp.Chimera.Group.State={members={}}
  event("gmcp.Chimera.Group.State");kozojeb.onKill("Morrid",true)
  assert(not kozojeb.S.firstDeath())
end)
test("remembered team identities are bounded in an unusually large roster",function()
  local e=leader()
  for i=1,100 do
    local m={id="friend"..i,name="Kolega"..i,kind="player",hp=100,maxhp=100,group_role="member"}
    e[#e+1]=m;gmcp.Chimera.Group.State.members[#gmcp.Chimera.Group.State.members+1]=m
  end
  event();event("gmcp.Chimera.Group.State")
  local count=0;for _ in pairs(kozojeb.S.known) do count=count+1 end
  assert(count<=32)
end)
test("targeted covers never take a third NPC on an already loaded defender",function()
  local e=multiple(5)
  gmcp.Chimera.Combat.State.relations[4].defender="S"
  gmcp.Chimera.Combat.State.relations[5].defender="S"
  kozojeb.start();advance(2);assert(#shields()==0);noMovement()
end)
test("light handling is configurable and defaults off",function()
  reset("wsparcie");kozojeb.start();assert(not kozojeb.config.lightEnabled and count("zapal lampe")==0);noMovement()
end)
test("enabled light handling tries the profile's own lamp once on start",function()
  reset("wsparcie");kozojeb.command("swiatlo on");kozojeb.start()
  assert(count("zapal lampe")==1 and kozojeb.S.lightPending)
  kozojeb.S.onLight();kozojeb.start();assert(count("zapal lampe")==1 and kozojeb.S.lightConfirmed)
end)
test("missing light acknowledgement does not create a retry loop",function()
  reset("wsparcie");kozojeb.command("swiatlo on");kozojeb.start();advance(60)
  assert(count("zapal lampe")==1 and not kozojeb.S.lightTimer and not kozojeb.S.lightPending)
  local notices=0;for _,line in ipairs(output) do if line:find("brak potwierdzenia zapalenia",1,true) then notices=notices+1 end end
  assert(notices==1)
end)
test("a stop cancels unacknowledged light work",function()
  reset("wsparcie");kozojeb.command("swiatlo on");kozojeb.start();kozojeb.stop();local before=#output;advance(20)
  assert(not kozojeb.S.lightTimer and #output==before and count("zapal lampe")==1)
end)
test("repeated anonymous attacks do not flood lamp commands or visibility notices",function()
  reset("wsparcie");kozojeb.command("swiatlo on");kozojeb.start()
  for i=1,2000 do kozojeb.onTeamCombat("Ktos","cie",true) end
  assert(count("zapal lampe")==1 and kozojeb.S.blind)
  local notices=0;for _,line in ipairs(output) do if line:find("Atak bez rozpoznanego",1,true) then notices=notices+1 end end
  assert(notices==1 and #aliases==0)
end)
test("an anonymous attack cancels a queued patrol step and cannot trigger an idle return",function()
  leader();kozojeb.onTeamCombat("Ktos","cie",true);advance(21)
  assert(kozojeb.S.blind and not kozojeb.moveTimer and count("e")==0 and #aliases==0)
end)
test("light acknowledgement waits for fresh visible room data before releasing the hold",function()
  reset("wsparcie");kozojeb.command("swiatlo on");kozojeb.start()
  local own=gmcp.Chimera.Room.Entities.entities[1]
  gmcp.Chimera.Room.Entities.entities={own};own.name="Ktos";event()
  kozojeb.onTeamCombat("Ktos","cie",true);kozojeb.S.onLight();assert(kozojeb.S.blind)
  own.name="Yergo";event();assert(not kozojeb.S.blind)
end)
test("light commands are one bounded configurable game command",function()
  reset();kozojeb.command("swiatlo komenda zapal pochodnie")
  assert(kozojeb.config.lightCommand=="zapal pochodnie")
  kozojeb.command("swiatlo komenda zapal lampe;w")
  assert(kozojeb.config.lightCommand=="zapal pochodnie")
  kozojeb.command("swiatlo on");kozojeb.saveSettings();kozojeb=nil;loadCore()
  assert(kozojeb.config.lightEnabled and kozojeb.config.lightCommand=="zapal pochodnie")
end)
test("a reconnect clears old lamp confirmation",function()
  reset("wsparcie");kozojeb.command("swiatlo on");kozojeb.start();kozojeb.S.onLight()
  kozojeb.onSessionEvent("sysDisconnectionEvent")
  assert(not kozojeb.S.lightConfirmed and not kozojeb.S.lightTimer)
end)
print(string.format("%d team safety simulations passed",total))
]====]
assert((loadstring or load)(header..cases,"@tests/team_safety.lua"))()
