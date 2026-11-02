-- Ten sam interfejs Mudleta co w testach rol; osobny przebieg i katalog plikow.
local file=assert(io.open("tests/roles.lua","r"));local source=file:read("*a");file:close()
local header=assert(source:match('^(.-)test%("second line supports'))
local cases=[====[
local root=assert(os.getenv("KOZO_COMBAT_LOG_TEST_DIR"))
local caseIndex=0
local function setup(selfId,role)
  reset(role or "zaslony");caseIndex=caseIndex+1
  function getMudletHomeDir() return root end
  local e={}
  local players={{"L","Yarrim",1680,1900},{"M","Morrid",1900,1900},
    {"S","Yergo",1860,1860},{"G","Gror",1780,1780}}
  local members={}
  for _,p in ipairs(players) do
    local own=p[1]==(selfId or "L")
    e[#e+1]={id=p[1],name=p[2],hp=p[3],maxhp=p[4],kind="player",self=own and 1 or 0,
      relation=own and "self" or "group",group_role=p[1]=="L" and "leader" or "member",states={}}
    members[#members+1]={id=p[1],name=p[2],hp=p[3],maxhp=p[4],self=own and 1 or 0,here=1,stamina=100,maxstamina=150}
  end
  e[#e+1]={id="N1",name="Dlugoreki ciemnozielony ork",kind="npc",hp=484,maxhp=1200}
  e[#e+1]={id="N2",name="Brutalny smierdzacy ork",kind="npc",hp=1220,maxhp=1220}
  gmcp.Chimera.Room.Entities={room="room-a",entities=e}
  gmcp.Chimera.Group.State={leader="L",members=members}
  gmcp.Chimera.Combat.State={room="room-a",primary="N1",relations={{attacker="L",defender="N1"},
    {attacker="M",defender="N1"},{attacker="S",defender="N1"},{attacker="G",defender="N1"},
    {attacker="N2",defender="L"},{attacker="N1",defender="G"}},
    covers={{guard="M",guarded="L"},{guard="S",guarded="L"},{guard="G",guarded="S"},{guard="G",guarded="M"}}}
  gmcp.Char.Vitals={hp=(selfId==nil or selfId=="L") and 88 or 100,mana=100,fatigue=18}
  kozojeb.config.combatLogEnabled=true
  local l=kozojeb.combatLog
  l.path=root.."/case-"..caseIndex..".jsonl";l.backup=l.path..".1"
  return l,e
end
local function member(l,id)
  for _,m in ipairs(l.lastSnapshot.members) do if m.id==id then return m end end
end
local function read(path)
  local f=io.open(path,"rb");if not f then return "" end
  local data=f:read("*a");f:close();return data
end
test("recording defaults on for an existing profile without a previous setting",function()
  reset();kozojeb=nil;loadCore();assert(kozojeb.config.combatLogEnabled)
end)
test("the supplied GMCP shape retains all raw HP pools and separates percentage vitals",function()
  local l=setup();kozojeb.command("zapis teraz")
  assert(member(l,"L").hp==1680 and member(l,"L").maxhp==1900)
  assert(math.abs(member(l,"L").percent-88.4210526316)<.00001)
  assert(member(l,"M").hp==1900 and member(l,"S").hp==1860 and member(l,"G").hp==1780)
  assert(l.lastSnapshot.char_vitals.hp_percent==88 and not l.lastSnapshot.char_vitals.hp_points)
  assert(#l.lastSnapshot.covers==4 and l.lastSnapshot.primary=="N1")
  assert(member(l,"L").npc_count==1 and member(l,"G").npc_count==1)
  assert(member(l,"M").npc_count==0 and member(l,"S").npc_count==0)
  assert(#sends==0 and #aliases==0 and #read(l.path)>0)
end)
test("newer group HP wins without mixing the entity HP maximum",function()
  local l,e=setup();e[1].hp=1690
  kozojeb.onGmcp("gmcp.Chimera.Room.Entities");clock=1;kozojeb.onGmcp("gmcp.Chimera.Group.State")
  l.capture(true);assert(member(l,"L").hp==1680 and member(l,"L").hp_source=="group")
  assert(member(l,"L").entities_hp.hp==1690)
  clock=2;kozojeb.onGmcp("gmcp.Chimera.Room.Entities");l.capture(true)
  assert(member(l,"L").hp==1690 and member(l,"L").hp_source=="entities")
  assert(l.lastSnapshot.sources.group.received==1 and l.lastSnapshot.sources.group.age==1)
end)
test("an incomplete newer channel is labelled with the valid fallback source",function()
  local l=setup();gmcp.Chimera.Group.State.members[1].maxhp=nil
  kozojeb.onGmcp("gmcp.Chimera.Group.State");l.capture(true)
  assert(member(l,"L").hp==1680 and member(l,"L").hp_source=="entities")
end)
test("duplicate combat edges do not invent a second incoming NPC",function()
  local l=setup()
  gmcp.Chimera.Combat.State.relations[#gmcp.Chimera.Combat.State.relations+1]={attacker="N2",defender="L"}
  l.capture(true);assert(member(l,"L").npc_count==1)
end)
test("a zero HP or text confirmed dead NPC is not counted as a live attacker",function()
  local l,e=setup();e[6].hp=0;kozojeb.deadNpcIds.N1={at=clock}
  l.capture(true);assert(member(l,"L").npc_count==0 and member(l,"G").npc_count==0)
end)
test("unknown HP remains unknown instead of becoming zero or a hundred percent",function()
  local l,e=setup();e[2].hp=nil;gmcp.Chimera.Group.State.members[2].hp=nil
  l.capture(true);assert(member(l,"M").hp==nil and member(l,"M").percent==nil)
end)
test("ordinary static repeated packets coalesce to one changed snapshot",function()
  local l=setup("M","wsparcie");kozojeb.start()
  for i=1,2000 do kozojeb.onGmcp("gmcp.Chimera.Room.Entities") end
  advance(.21);assert(l.samples==1 and l.records==1)
  local written=l.records
  for i=1,20 do kozojeb.onGmcp("gmcp.Chimera.Room.Entities") end
  advance(1.01);assert(l.records==written)
  noMovement()
end)
test("a busy HP stream produces at most one automatic snapshot per second",function()
  local l,e=setup("M","wsparcie");kozojeb.start()
  for i=1,60 do e[1].hp=1680+i;kozojeb.onGmcp("gmcp.Chimera.Room.Entities");advance(.05) end
  assert(l.samples<=3 and l.records<=3 and l.lastSnapshot)
  assert(l.writes==0);advance(3);assert(l.writes>=1);noMovement()
end)
test("peaceful patrol data does not arm a permanent logging loop",function()
  local l=setup("M","wsparcie");gmcp.Chimera.Combat.State={primary="",relations={}}
  kozojeb.start();event();assert(not l.sampleTimer and not l.flushTimer and l.records==0)
end)
test("outgoing party combat is recorded even before the NPC returns an attack",function()
  local l=setup("M","wsparcie")
  gmcp.Chimera.Combat.State.relations={{attacker="L",defender="N1"}}
  kozojeb.start();advance(.21)
  assert(l.records==1 and l.lastSnapshot.primary=="N1" and member(l,"L").npc_count==0);noMovement()
end)
test("recording off removes pending logger work and survives reloading",function()
  local l=setup("M","wsparcie");kozojeb.start();event()
  kozojeb.command("zapis off");local before=l.records
  event();advance(10)
  assert(l.records==before and not l.sampleTimer and not l.flushTimer and not kozojeb.config.combatLogEnabled)
  loadCore();assert(not kozojeb.config.combatLogEnabled)
end)
test("status and manual snapshot work without the lua alias or a running bot",function()
  local l=setup();kozojeb.config.combatLogEnabled=false
  kozojeb.command("zapis teraz");assert(l.records==1 and not kozojeb.enabled)
  kozojeb.command("zapis status");assert(read(l.path):find('"kind":"state"',1,true))
  assert(#sends==0 and #aliases==0)
end)
test("a sent shield and result keep their own exact timestamps between snapshots",function()
  local l,e=setup("M");e[1].hp=1200;gmcp.Chimera.Group.State.members[1].hp=1200
  kozojeb.start();assert(count("zaslon yarrima")==1)
  advance(.04);kozojeb.onShieldResult("yarrima",false,"brutalnego smierdzacego orka")
  l.flush();local data=read(l.path)
  assert(data:find('"kind":"shield_sent"',1,true) and data:find('"kind":"shield_reply"',1,true))
  assert(data:find('"target_hp":1200',1,true) and data:find('"succeeded":false',1,true))
  assert(data:find('"time":0.04',1,true));noMovement()
end)
test("golem omission records the actual HP gap rejection",function()
  local l,e=setup("M");e[1].hp=1800;gmcp.Chimera.Group.State.members[1].hp=1800
  e[5].name="Kamienny golem";e[6].name="Zelazny golem";kozojeb.config.golemsEnabled=true
  kozojeb.start();advance(.21)
  local found=false
  for _,check in ipairs(l.lastSnapshot.shield.checks) do if check.target=="L" and check.code=="hp_gap" then found=true end end
  assert(found and count("zaslon yarrima przed zelaznym golemem")==0)
  noMovement()
end)
test("a normal shield held for formation readiness explains the actual block",function()
  local l,e=setup("M");e[1].hp=1200;gmcp.Chimera.Group.State.members[1].hp=1200
  kozojeb.shieldFormationReady=false;kozojeb.start();advance(.21)
  local found=false
  for _,check in ipairs(l.lastSnapshot.shield.checks) do if check.code=="formation_busy" then found=true end end
  assert(found and count("zaslon yarrima")==0);noMovement()
end)
test("ordinary combat explains both a high HP target and an unattacked teammate",function()
  local l=setup("M");kozojeb.start();advance(.21)
  local reasons={}
  for _,check in ipairs(l.lastSnapshot.shield.checks) do reasons[check.target]=check.code end
  assert(reasons.L=="hp_above_threshold" and reasons.S=="no_npc");noMovement()
end)
test("cover relationships do not alter the combat allocator or become incoming attacks",function()
  local l,e=setup("M","wsparcie");kozojeb.start();advance(.21)
  local before=count("wesprzyj")
  gmcp.Chimera.Combat.State.covers={{guard="M",guarded="L"},{guard="M",guarded="G"}}
  event("gmcp.Chimera.Combat.State");advance(1)
  assert(#l.lastSnapshot.covers==2 and member(l,"M").npc_count==0 and count("wesprzyj")==before)
  noMovement()
end)
test("room changes label old combat as unavailable instead of moving old attackers",function()
  local l=setup("M","wsparcie");kozojeb.start();event()
  room=1323;kozojeb.onRoomChanged("gmcp.Room.Info");l.capture(true)
  assert(not l.lastSnapshot.ready.entities and not l.lastSnapshot.ready.combat)
  assert(#l.lastSnapshot.relations==0 and member(l,"L").npc_count==0)
end)
test("disconnection flushes before teardown and no logger timer keeps running",function()
  local l=setup("M","wsparcie");kozojeb.start();advance(.21);assert(l.bufferBytes>0)
  kozojeb.onSessionEvent("sysDisconnectionEvent")
  assert(l.bufferBytes==0 and not l.sampleTimer and not l.flushTimer)
  local written=l.records;advance(2);assert(l.records==written and not kozojeb.enabled)
  assert(read(l.path):find('"kind":"sysDisconnectionEvent"',1,true))
end)
test("real reconnection resumes automatic recording with new source timestamps",function()
  local l=setup("M","wsparcie");kozojeb.start();advance(.21)
  kozojeb.onSessionEvent("sysDisconnectionEvent");local before=l.records
  advance(1);reconnectPackets();advance(11)
  assert(kozojeb.enabled and l.records>before and l.received.group>1)
  assert(l.lastSnapshot.sources.group.received==l.received.group);noMovement()
end)
test("manual stop flushes and cancels every pending logger callback",function()
  local l=setup("M","wsparcie");kozojeb.start();event();kozojeb.stop()
  local before=l.records;advance(20);assert(l.records==before and l.bufferBytes==0)
  assert(not l.sampleTimer and not l.flushTimer);noMovement()
end)
test("profile exit flushes pending data and still saves settings",function()
  local l=setup("M","wsparcie");kozojeb.start();event();kozojeb.onExit()
  assert(l.bufferBytes==0 and read(l.path):find('"kind":"exit"',1,true))
  assert(next(saved)~=nil)
end)
test("reloading closes the previous recorder before resetting its state",function()
  local l=setup("M","wsparcie");kozojeb.start();event();loadCore()
  assert(l.bufferBytes==0 and not l.sampleTimer and not l.flushTimer)
  assert(read(l.path):find('"kind":"reload"',1,true))
end)
test("rotation keeps exactly one previous file and never truncates a JSON record",function()
  local l=setup();l.capture(true);l.flush();local initial=read(l.path)
  l.maxBytes=#initial+1
  for i=1,3 do clock=clock+1;l.capture(true);l.flush() end
  assert(read(l.path)~="" and read(l.backup)~="" and read(l.path):sub(-1)=="\n" and read(l.backup):sub(-1)=="\n")
  assert(not io.open(l.backup..".1","rb"))
end)
test("a disk error is reported once and never stops combat or retries on every packet",function()
  local l=setup("M","wsparcie");l.path=root.."/missing/subdir/fail.jsonl";l.backup=l.path..".1"
  kozojeb.start();advance(.21);l.flush();assert(l.fault and kozojeb.enabled)
  local warnings=#output
  for i=1,30 do event() end
  assert(#output==warnings and not l.sampleTimer and not l.flushTimer);noMovement()
end)
test("an error from writing an opened file also closes it without stopping the bot",function()
  local l=setup("M","wsparcie");kozojeb.start();advance(.21)
  local realOpen,closed=io.open,false
  io.open=function(path,mode)
    if path==l.path and mode=="ab" then return {seek=function() return 0 end,
      write=function() error("simulated write failure") end,close=function() closed=true;return true end} end
    return realOpen(path,mode)
  end
  l.flush();io.open=realOpen
  assert(l.fault and closed and kozojeb.enabled and not l.flushTimer);noMovement()
end)
test("enabling again after a corrected file error restores recording",function()
  local l=setup("M","wsparcie");local valid=l.path;l.path=root.."/missing/subdir/fail.jsonl"
  kozojeb.start();advance(.21);l.flush();assert(l.fault)
  l.path=valid;l.backup=valid..".1";kozojeb.command("zapis on");advance(1.1);l.flush()
  assert(not l.fault and #read(valid)>0 and kozojeb.enabled);noMovement()
end)
test("source timestamps continue while recording is disabled without writing anything",function()
  local l=setup();kozojeb.config.combatLogEnabled=false
  clock=42;kozojeb.onGmcp("gmcp.Char.Vitals")
  assert(l.received.char==42 and l.records==0 and not l.sampleTimer and not l.flushTimer)
end)
test("diagnostic check storage stays bounded even with repeated rejected candidates",function()
  local l=setup("M","wsparcie");kozojeb.start();l.beginDecision()
  for i=1,2000 do l.reason("target"..i,"npc"..i,"hp_gap",true) end
  l.capture(true);assert(#l.lastSnapshot.shield.checks==64)
end)
test("large reported rooms are bounded while retaining the current profile",function()
  local l,e=setup()
  for i=1,40 do
    local id="npc-"..i;e[#e+1]={id=id,name="Dodatkowy ork",kind="npc",hp=100,maxhp=100}
    local player={id="player-"..i,name="Kolega"..i,kind="player",hp=100,maxhp=100}
    e[#e+1]=player;gmcp.Chimera.Group.State.members[#gmcp.Chimera.Group.State.members+1]=player
  end
  l.capture(true)
  assert(#l.lastSnapshot.members==24 and #l.lastSnapshot.npcs==32 and l.lastSnapshot.truncated)
  assert(member(l,"L") and l.lastSnapshot.profile=="Yarrim")
end)
test("recording has no effect on outgoing combat commands",function()
  local sequence
  for _,enabled in ipairs({false,true}) do
    local l,e=setup("M");e[1].hp=1200;gmcp.Chimera.Group.State.members[1].hp=1200
    kozojeb.config.combatLogEnabled=enabled;kozojeb.start();event();advance(2)
    local result=table.concat(sends,"|").."/"..table.concat(aliases,"|")
    if sequence then assert(result==sequence) else sequence=result end
  end
end)
test("unusual names and nonfinite numbers remain safe single line JSON",function()
  local l,e=setup();e[2].name='Mor"rid\n\\test';e[2].states={"stan\t1","polski żółć"}
  e[2].hp=math.huge;gmcp.Chimera.Group.State.members[2].hp=0/0
  l.capture(true);l.flush();local data=read(l.path)
  assert(data:find('Mor\\"rid\\u000a\\\\test',1,true))
  assert(not member(l,"M").hp and member(l,"M").states[2]=="polski żółć")
end)
test("long multibyte descriptions remain valid UTF-8 after bounded clipping",function()
  local l,e=setup();e[2].name="M"..string.rep("ż",120)
  l.capture(true);l.flush();assert(#member(l,"M").name<=160 and read(l.path)~="")
end)
test("ignored follower retreat requests are not logged as actual team retreats",function()
  local l=setup("M","wsparcie");kozojeb.start();advance(.21)
  kozojeb.escape("ignored follower retreat");l.flush()
  assert(not read(l.path):find('"kind":"retreat"',1,true));noMovement()
end)
print(string.format("%d combat recorder simulations passed",total))
]====]
assert((loadstring or load)(header..cases,"@tests/combat_log.lua"))()
