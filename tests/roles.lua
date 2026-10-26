local source = "src/Chimera_Kozojeb.lua"
local compile = loadstring or load
local clock, serial, timers, sends, aliases, output, saved, room, triggers
local function clone(value)
  if type(value) ~= "table" then return value end
  local result = {}
  for k, v in pairs(value) do result[k] = clone(v) end
  return result
end
function cecho(value) output[#output + 1] = value end
function cechoLink(label, action) output[#output + 1] = label end
function send(command) sends[#sends + 1] = command end
function expandAlias(command) aliases[#aliases + 1] = command end
function getPlayerRoom() return room end
function getMudletHomeDir() return "/profile-under-test" end
function table.save(path, value) saved[path] = clone(value) end
function table.load(path, target)
  for k, v in pairs(saved[path] or {}) do target[k] = clone(v) end
end
function tempTimer(delay, callback)
  serial = serial + 1
  timers[serial] = {at = clock + delay, callback = callback}
  return serial
end
function killTimer(id) timers[id] = nil end
function tempAlias() serial = serial + 1 return serial end
function tempRegexTrigger(pattern, handler)
  serial = serial + 1
  triggers[#triggers + 1] = { pattern = pattern, handler = handler }
  return serial
end
function raiseGlobalEvent() error("Unexpected cross-profile communication") end
function registerAnonymousEventHandler() serial = serial + 1 return serial end
function killTrigger() end
function killAlias() end
function killAnonymousEventHandler() end
function getRoomExits(id) return id == 1322 and {east = 1323} or {west = 1322} end
function getPath() speedWalkDir = {"west"} speedWalkPath = {1322} return true end
local function advance(seconds)
  local deadline, steps = clock + seconds, 0
  while true do
    local earliest, selected = math.huge, nil
    for id, timer in pairs(timers) do
      if timer.at < earliest or (timer.at == earliest and (not selected or id < selected)) then
        earliest, selected = timer.at, id
      end
    end
    if not selected or earliest > deadline then break end
    steps = steps + 1 assert(steps < 1000, "timer loop")
    local callback = timers[selected].callback
    timers[selected], clock = nil, earliest
    callback()
  end
  clock = deadline
end
local function count(command)
  local total = 0
  for _, value in ipairs(sends) do if value == command then total = total + 1 end end
  return total
end
local function reset(role, leaderHp)
  clock, serial, timers, sends, aliases, output, saved, room = 0, 0, {}, {}, {}, {}, {}, 1322
  triggers = {}
  kozojeb = nil
  kozobot = nil
  gmcp = {
    Char = {Vitals = {hp=100, maxhp=100, moves=100, maxmoves=100}},
    Chimera = {
      Room = {Entities = {entities = {
        {id="S", name="Yergo", kind="player", self=1, relation="self", group_role="member", hp=100, maxhp=100},
        {id="L", name="Yarrim", kind="player", group_role="leader", hp=leaderHp or 100, maxhp=100},
        {id="M", name="Morrid", kind="player", group_role="member", hp=100, maxhp=100},
        {id="N", name="Maly glupkowaty snotling", kind="npc", hp=100, maxhp=100},
      }}},
      Group = {State = {leader="L", members={"S", "L", "M"}}},
      Combat = {State = {primary="", relations={{attacker="L", defender="N"}, {attacker="N", defender="L"}}}},
    },
  }
  dofile(source)
  if role then kozojeb.command("rola " .. role) end
  sends, aliases = {}, {}
end
local function event(name)
  kozojeb.onGmcp(name or "gmcp.Chimera.Room.Entities")
  advance(0.13)
end
local function noMovement()
  for _, value in ipairs(sends) do
    assert(value == "wesprzyj" or value:match("^zaslon ") or value == "kondycja", "unexpected command: " .. value)
  end
  assert(#aliases == 0, "unexpected alias: " .. tostring(aliases[1]))
end
local function shieldReply(line)
  for _, trigger in ipairs(triggers) do
    if trigger.handler:find("kozojeb.onShieldResult", 1, true) then
      local form = line:match(trigger.pattern)
      if form then
        matches = {line, form}
        assert(compile(trigger.handler))()
        return
      end
    end
  end
  error("No shield result trigger matched: " .. line)
end
local total = 0
local function test(name, callback)
  callback()
  total = total + 1
  print("PASS " .. name)
end

test("second line supports without own attack, shield, patrol or idle reset", function()
  reset("wsparcie", 60)
  gmcp.Chimera.Room.Entities.entities[3].hp = 10
  kozojeb.start()
  assert(count("wesprzyj") == 1)
  assert(count("zaslon yarrima") == 0)
  gmcp.Chimera.Combat.State.primary = "N"
  for i=1,30 do event() end
  assert(count("wesprzyj") == 1)
  kozojeb.onFlee("Maly glupkowaty snotling", "wschod")
  kozojeb.onIdleTimeout()
  advance(60)
  noMovement()
end)

test("shielding role protects only leader below its independent threshold", function()
  reset("zaslony", 69)
  gmcp.Chimera.Room.Entities.entities[3].hp = 5
  kozojeb.start()
  assert(count("zaslon yarrima") == 1)
  assert(count("zaslon morrida") == 0)
  assert(kozojeb.mode ~= "escape")
  event()
  assert(count("zaslon yarrima") == 1)
  advance(2)
  event()
  assert(count("zaslon yarrima") == 1)
  kozojeb.onFormationReady()
  advance(0.13)
  assert(count("zaslon yarrima") == 2)
  noMovement()
end)

test("shield threshold equality, off, unknown HP and own low HP", function()
  reset("zaslony", 70)
  kozojeb.start()
  assert(count("zaslon yarrima") == 0)
  gmcp.Chimera.Room.Entities.entities[2].hp = 69
  kozojeb.command("proglidera 0")
  event()
  assert(count("zaslon yarrima") == 0)
  kozojeb.command("proglidera 70")
  gmcp.Chimera.Room.Entities.entities[2].hp = nil
  event()
  assert(count("zaslon yarrima") == 0)
  gmcp.Chimera.Room.Entities.entities[2].hp = 69
  gmcp.Chimera.Room.Entities.entities[1].hp = 49
  event()
  assert(count("zaslon yarrima") == 0)
end)

test("no team suppresses actions despite stale entity roles and manual names", function()
  reset("zaslony", 60)
  gmcp.Chimera.Group.State = {members={}}
  kozojeb.command("druzyna Yarrim Morrid")
  kozojeb.start()
  kozojeb.onTeamCombat("Yarrim", "malego snotlinga")
  advance(30)
  assert(#sends == 0)
  noMovement()
end)

test("room change waits for fresh entities and does not pursue", function()
  reset("zaslony", 60)
  kozojeb.start()
  sends = {}
  room = 9000
  kozojeb.onRoomChanged("gmcp.Room.Info")
  kozojeb.onGmcp("gmcp.Char.Vitals")
  advance(3)
  assert(#sends == 0)
  kozojeb.onFleeAnnounced("Maly glupkowaty snotling")
  kozojeb.onFleeDirection("wschod")
  advance(3)
  assert(#sends == 0)
  event()
  assert(count("wesprzyj") == 1)
  noMovement()
end)

test("loss of leader, disband and leader transfer stop old target actions", function()
  reset("zaslony", 60)
  kozojeb.start()
  sends = {}
  table.remove(gmcp.Chimera.Room.Entities.entities, 2)
  event()
  assert(#sends == 0 and kozojeb.mode == "support_wait")
  reset("zaslony", 60)
  kozojeb.start()
  sends = {}
  gmcp.Chimera.Group.State.leader = "M"
  gmcp.Chimera.Combat.State.relations = {{attacker="N", defender="M"}}
  gmcp.Chimera.Room.Entities.entities[3].hp = 65
  advance(2.1)
  kozojeb.onFormationReady()
  event("gmcp.Chimera.Group.State")
  assert(count("zaslon morrida") == 1)
  assert(count("zaslon yarrima") == 0)
  noMovement()
end)

test("explicit leader is a real visible team member, manual bystander is rejected", function()
  reset("wsparcie")
  kozojeb.command("lider Morrid morrida")
  kozojeb.start()
  assert(#sends == 0)
  kozojeb.command("lider Yarrim yarrima")
  event()
  assert(count("wesprzyj") == 1)
  noMovement()
end)

test("text combat event supports when combat relations have not arrived", function()
  reset("wsparcie")
  gmcp.Chimera.Combat.State.relations = {}
  kozojeb.start()
  assert(#sends == 0)
  kozojeb.onTeamCombat("Yarrim", "malego glupkowatego snotlinga")
  advance(0.13)
  assert(count("wesprzyj") == 1)
  noMovement()
end)

test("death and panic in supporting role do not start patrol or search", function()
  reset("wsparcie")
  kozojeb.start()
  kozojeb.onKill("Maly glupkowaty snotling", false)
  gmcp.Chimera.Combat.State = {primary="", relations={}}
  kozojeb.onPanic()
  room = 1323
  kozojeb.onRoomChanged("gmcp.Room.Info")
  kozojeb.onPanicLanded()
  event()
  advance(30)
  assert(kozojeb.mode == "support_wait")
  noMovement()
end)

test("wrong nominative Morrid is fixed for the original leader role", function()
  reset(nil)
  gmcp.Chimera.Group.State.leader = "S"
  gmcp.Chimera.Room.Entities.entities[1].group_role = "leader"
  gmcp.Chimera.Room.Entities.entities[2].group_role = "member"
  gmcp.Chimera.Room.Entities.entities[3].hp = 68
  gmcp.Chimera.Combat.State.relations = {{attacker="N", defender="M"}}
  gmcp.Chimera.Combat.State.primary = "N"
  kozojeb.start()
  assert(count("zaslon morrida") == 1)
  assert(count("zaslon morrid") == 0)
end)

test("unknown name never falls back to nominative and explicit correction works", function()
  reset("zaslony", 60)
  gmcp.Chimera.Room.Entities.entities[2].name = "Pandjed"
  kozojeb.start()
  assert(count("zaslon pandjed") == 0 and count("zaslon pandjeda") == 0)
  kozojeb.command("imie Pandjed pandjeda")
  event()
  assert(count("zaslon pandjeda") == 1)
  noMovement()
end)

test("server rejection blocks repeated invalid form until corrected", function()
  reset("zaslony", 60)
  kozojeb.command("imie Yarrim yarrim")
  kozojeb.start()
  assert(count("zaslon yarrim") == 1)
  kozojeb.onShieldRejected()
  advance(3)
  for i=1,10 do event() end
  assert(count("zaslon yarrim") == 1)
  kozojeb.command("imie Yarrim yarrima")
  event()
  assert(count("zaslon yarrima") == 1)
end)

test("formation cooldown suppresses shields until server readiness", function()
  reset("zaslony", 60)
  kozojeb.start()
  kozojeb.onShieldCooldown()
  advance(3)
  event()
  assert(count("zaslon yarrima") == 1)
  kozojeb.onFormationReady()
  advance(0.13)
  assert(count("zaslon yarrima") == 2)
end)

test("role switch cancels pending movement and requires explicit start", function()
  reset(nil)
  gmcp.Chimera.Group.State = {members={}}
  gmcp.Chimera.Combat.State = {primary="", relations={}}
  gmcp.Chimera.Room.Entities.entities = {gmcp.Chimera.Room.Entities.entities[1]}
  kozojeb.start()
  assert(kozojeb.moveTimer)
  kozojeb.command("rola wsparcie")
  sends, aliases = {}, {}
  advance(30)
  assert(not kozojeb.enabled and kozojeb.mode == "stop" and #sends == 0)
  noMovement()
end)

test("role, leader, threshold and custom declension survive new Lua session", function()
  reset("zaslony")
  kozojeb.command("lider Pandjed pandjeda")
  kozojeb.command("proglidera 65")
  kozojeb.command("minhpzaslony 55")
  kozojeb = nil
  dofile(source)
  assert(kozojeb.config.role == "zaslony")
  assert(kozojeb.config.leaderName == "pandjed")
  assert(kozojeb.config.leaderShieldHp == 65)
  assert(kozojeb.config.shieldSelfHp == 55)
  assert(kozojeb.config.shieldNameForms.pandjed == "pandjeda")
end)

test("support starts outside patrol area with no map area selected", function()
  reset("wsparcie")
  kozojeb.rooms, room = {}, 99999
  kozojeb.start()
  assert(kozojeb.enabled and count("wesprzyj") == 1)
  noMovement()
end)

test("any profile can lead and nonleader profile cannot run the patrol", function()
  reset(nil)
  kozojeb.command("cele snotling")
  kozojeb.start()
  assert(kozojeb.mode == "leader_wait")
  assert(#sends == 0)
  gmcp.Chimera.Group.State.leader = "S"
  gmcp.Chimera.Combat.State.primary = "N"
  event("gmcp.Chimera.Group.State")
  assert(kozojeb.mode == "combat")
end)

test("original solo patrol, configured NPC attack and stop remain functional", function()
  reset(nil)
  gmcp.Chimera.Group.State = {members={}}
  gmcp.Chimera.Room.Entities.entities = {
    gmcp.Chimera.Room.Entities.entities[1],
    {id="G", name="Biala koza", kind="npc", hp=100, maxhp=100},
  }
  gmcp.Chimera.Combat.State = {primary="", relations={}}
  kozojeb.start()
  assert(count("zabij koze") == 1)
  kozojeb.stop()
  advance(30)
  assert(count("zabij koze") == 1)
end)

test("both supporting roles keep formation at low HP and low movement", function()
  for _, role in ipairs({"wsparcie", "zaslony"}) do
    reset(role)
    kozojeb.start()
    room = 1323
    kozojeb.onRoomChanged("gmcp.Room.Info")
    gmcp.Chimera.Room.Entities.entities[1].hp = 20
    gmcp.Char.Vitals.moves = 5
    gmcp.Chimera.Combat.State.primary = "N"
    event()
    advance(30)
    assert(kozojeb.enabled and kozojeb.mode == "support_combat")
    assert(not kozojeb.moveTimer and not kozojeb.escapeWatchTimer and not kozojeb.healTimer)
    assert(gmcp.Chimera.Group.State.leader == "L" and #gmcp.Chimera.Group.State.members == 3)
    noMovement()
  end
end)

test("actual wounded and exhaustion triggers cannot move either supporting role", function()
  for _, role in ipairs({"wsparcie", "zaslony"}) do
    reset(role)
    kozojeb.start()
    room = 1323
    local fired = 0
    for _, trigger in ipairs(triggers) do
      if trigger.handler:find("Stan postaci: ranny.", 1, true)
          or trigger.handler:find("Serwer zglosil niemoc lub wyczerpanie.", 1, true) then
        assert(compile(trigger.handler))()
        fired = fired + 1
      end
    end
    assert(fired == 2)
    kozojeb.escape("Wywolanie odwrotu z innego skryptu")
    advance(30)
    assert(kozojeb.mode ~= "escape" and kozojeb.mode ~= "heal_rest" and kozojeb.mode ~= "recovery_return")
    assert(not kozojeb.escapeWatchTimer and not kozojeb.healTimer and not kozojeb.recoveryTimer)
    noMovement()
  end
end)

test("support without a visible team never performs a personal emergency retreat", function()
  reset("wsparcie")
  gmcp.Chimera.Group.State = {members={}}
  gmcp.Chimera.Room.Entities.entities[1].hp = 5
  gmcp.Char.Vitals.moves = 0
  kozojeb.start()
  kozojeb.escape("Stan postaci: ranny.")
  advance(30)
  assert(kozojeb.enabled and kozojeb.mode == "support_wait" and #sends == 0)
  noMovement()
end)

test("leader retains original team HP retreat and waits for that member to heal", function()
  reset(nil)
  gmcp.Chimera.Group.State.leader = "S"
  gmcp.Chimera.Combat.State.primary = "N"
  kozojeb.command("cele snotling")
  kozojeb.start()
  aliases = {}
  room = 1323
  kozojeb.onRoomChanged("gmcp.Room.Info")
  gmcp.Chimera.Room.Entities.entities[3].hp = 40
  event()
  assert(kozojeb.mode == "escape" and aliases[1] == "/idz 1322")
  assert(kozojeb.injuredTeamMember == "Morrid")
  room = 1322
  kozojeb.onRoomChanged("gmcp.Room.Info")
  event()
  advance(3.1)
  assert(kozojeb.mode == "heal_rest")
  gmcp.Chimera.Room.Entities.entities[3].hp = 100
  event()
  advance(3.1)
  assert(kozojeb.enabled and kozojeb.mode == "combat")
end)

test("leader retains original personal exhaustion retreat", function()
  reset(nil)
  gmcp.Chimera.Group.State.leader = "S"
  gmcp.Chimera.Combat.State.primary = "N"
  kozojeb.command("cele snotling")
  kozojeb.start()
  aliases = {}
  room = 1323
  kozojeb.onRoomChanged("gmcp.Room.Info")
  gmcp.Char.Vitals.moves = 5
  event()
  assert(kozojeb.mode == "escape" and aliases[1] == "/idz 1322")
end)

test("status panel and help render with all three roles", function()
  reset("zaslony")
  kozojeb.status()
  kozojeb.help()
  local text = table.concat(output, "\n")
  assert(text:find("Rola profilu", 1, true))
  assert(text:find("proglidera", 1, true))
end)

test("entity group roles alone can identify the leader", function()
  reset("zaslony", 60)
  gmcp.Chimera.Group.State = {}
  kozojeb.start()
  assert(count("wesprzyj") == 1 and count("zaslon yarrima") == 1)
  noMovement()
end)

test("table group members supply leader role and missing visible HP", function()
  reset("zaslony")
  gmcp.Chimera.Room.Entities.entities[2].group_role = "member"
  gmcp.Chimera.Room.Entities.entities[2].hp = nil
  gmcp.Chimera.Group.State = {members={
    {id="S", name="Yergo", self=1},
    {id="L", name="Yarrim", role="leader", hp=200, maxhp=300},
    {id="M", name="Morrid"},
  }}
  kozojeb.start()
  assert(kozojeb.leaderHp == 67 and count("zaslon yarrima") == 1)
  noMovement()
end)

test("formation readiness timeout recovers without a server ready line", function()
  reset("zaslony", 60)
  kozojeb.start()
  kozojeb.onShieldCooldown()
  advance(9)
  event()
  assert(count("zaslon yarrima") == 1)
  advance(1.1)
  event()
  assert(count("zaslon yarrima") == 2)
end)

test("100 percent shield setting works for a supporter at full health", function()
  reset("zaslony", 99)
  kozojeb.command("proglidera 100")
  kozojeb.start()
  assert(count("zaslon yarrima") == 1)
end)

test("invalid role, threshold and command separators cannot change settings", function()
  reset("wsparcie")
  kozojeb.command("rola invalid")
  kozojeb.command("proglidera -1")
  kozojeb.command("proglidera 101")
  kozojeb.command("lider Yarrim;zabij")
  kozojeb.command("imie Yarrim yarrima;zabij")
  assert(kozojeb.config.role == "wsparcie" and kozojeb.config.leaderShieldHp == 70)
  assert(kozojeb.config.leaderName == "" and kozojeb.config.shieldNameForms.yarrim == "yarrima")
  assert(#sends == 0)
end)

test("shield immediately reserves formation before any server response", function()
  reset("zaslony", 60)
  kozojeb.start()
  assert(count("zaslon yarrima") == 1 and not kozojeb.shieldFormationReady)
  advance(2.1)
  for i=1,10 do event() end
  assert(count("zaslon yarrima") == 1)
  kozojeb.command("proglidera 85")
  event()
  assert(count("zaslon yarrima") == 1)
  noMovement()
end)

test("successful shield waits for readiness and a fresh combat state", function()
  reset("zaslony", 80)
  kozojeb.command("proglidera 85")
  kozojeb.start()
  shieldReply("Zaslaniasz Yarrima przed ciosami mokrego malego fimira.")
  assert(not kozojeb.shieldPendingTarget)
  advance(3)
  event()
  assert(count("zaslon yarrima") == 1)
  kozojeb.onFormationReady()
  advance(0.13)
  assert(count("zaslon yarrima") == 1, "stale combat state used after shield")
  gmcp.Chimera.Combat.State.relations = {{attacker="L", defender="N"}, {attacker="N", defender="S"}}
  event("gmcp.Chimera.Combat.State")
  assert(count("zaslon yarrima") == 1, "shield repeated while NPC hits supporter")
  gmcp.Chimera.Combat.State.relations = {{attacker="L", defender="N"}, {attacker="N", defender="L"}}
  event("gmcp.Chimera.Combat.State")
  assert(count("zaslon yarrima") == 2, "new actual attack did not permit shielding")
  noMovement()
end)

test("failed shield skill also consumes formation until readiness", function()
  reset("zaslony", 60)
  kozojeb.start()
  shieldReply("Probujesz zaslonic Yarrima przed ciosami mokrego malego fimira, lecz nie jestes w stanie tego ")
  advance(3)
  event("gmcp.Chimera.Combat.State")
  assert(count("zaslon yarrima") == 1)
  kozojeb.onFormationReady()
  advance(0.13)
  assert(count("zaslon yarrima") == 2)
end)

test("leader attacking an NPC does not by itself justify a shield", function()
  reset("zaslony", 60)
  gmcp.Chimera.Combat.State.relations = {{attacker="L", defender="N"}}
  kozojeb.start()
  assert(count("wesprzyj") == 1 and count("zaslon yarrima") == 0)
  noMovement()
end)

test("NPC hitting protector or unrelated teammate is not a threat to leader", function()
  for _, defender in ipairs({"S", "M"}) do
    reset("zaslony", 60)
    gmcp.Chimera.Combat.State.relations = {{attacker="L", defender="N"}, {attacker="N", defender=defender}}
    kozojeb.start()
    assert(count("zaslon yarrima") == 0)
    noMovement()
  end
end)

test("leader protects an attacked teammate despite a lower unthreatened teammate", function()
  reset(nil)
  gmcp.Chimera.Group.State.leader = "S"
  gmcp.Chimera.Room.Entities.entities[2].hp = 65
  gmcp.Chimera.Room.Entities.entities[3].hp = 60
  gmcp.Chimera.Combat.State.primary = "N"
  kozojeb.command("cele snotling")
  kozojeb.start()
  assert(kozojeb.teamLowestName == "Morrid")
  assert(count("zaslon yarrima") == 1 and count("zaslon morrida") == 0)
end)

test("dead NPCs and player opponents do not trigger an automatic NPC shield", function()
  reset("zaslony", 60)
  gmcp.Chimera.Room.Entities.entities[4].hp = 0
  kozojeb.start()
  assert(count("zaslon yarrima") == 0)
  reset("zaslony", 60)
  gmcp.Chimera.Combat.State.relations = {{attacker="M", defender="L"}}
  kozojeb.start()
  assert(count("zaslon yarrima") == 0)
end)

test("leader HP threshold is independent from own minimum and includes its boundary", function()
  reset("zaslony", 80)
  kozojeb.command("proglidera 85")
  kozojeb.command("minhpzaslony 50")
  gmcp.Chimera.Room.Entities.entities[1].hp = 50
  kozojeb.start()
  assert(count("zaslon yarrima") == 1, "independent minimum 50 should permit own 50")
  reset("zaslony", 80)
  kozojeb.command("proglidera 85")
  kozojeb.command("minhpzaslony 50")
  gmcp.Chimera.Room.Entities.entities[1].hp = 49
  kozojeb.start()
  assert(count("zaslon yarrima") == 0 and kozojeb.enabled)
  noMovement()
end)

test("support prog alias updates only saved shield minimum", function()
  reset("zaslony")
  kozojeb.command("proglidera 85")
  kozojeb.command("prog 60")
  assert(kozojeb.config.shieldSelfHp == 60)
  assert(kozojeb.config.leaderShieldHp == 85 and kozojeb.config.escapeHp == 50)
  kozojeb.command("minhpzaslony -1")
  kozojeb.command("minhpzaslony 101")
  kozojeb.command("minhpzaslony 50.5")
  assert(kozojeb.config.shieldSelfHp == 60)
end)

test("stop and restart cannot bypass a consumed formation change", function()
  reset("zaslony", 60)
  kozojeb.start()
  kozojeb.stop()
  advance(2.1)
  kozojeb.start()
  assert(count("zaslon yarrima") == 1 and not kozojeb.shieldFormationReady)
  kozojeb.onFormationReady()
  advance(0.13)
  assert(count("zaslon yarrima") == 2)
end)

test("formation timeout while stopped never restarts the bot", function()
  reset("zaslony", 60)
  kozojeb.start()
  kozojeb.stop()
  advance(20)
  assert(count("zaslon yarrima") == 1 and not kozojeb.enabled)
  assert(kozojeb.shieldFormationReady and kozojeb.mode == "stop")
  noMovement()
end)

test("combat update before shield success allows protecting against the next NPC", function()
  reset("zaslony", 60)
  local entities = gmcp.Chimera.Room.Entities.entities
  entities[#entities + 1] = {id="T", name="Niski snotling", kind="npc", hp=100, maxhp=100}
  gmcp.Chimera.Combat.State.relations = {{attacker="N", defender="L"}, {attacker="T", defender="L"}}
  kozojeb.start()
  gmcp.Chimera.Combat.State.relations = {{attacker="N", defender="S"}, {attacker="T", defender="L"}}
  event("gmcp.Chimera.Combat.State")
  shieldReply("Zaslaniasz Yarrima przed ciosami malego snotlinga.")
  advance(3)
  kozojeb.onFormationReady()
  advance(0.13)
  assert(count("zaslon yarrima") == 2)
  noMovement()
end)

test("disconnect cancels attacks and requires new room data plus an explicit start", function()
  reset(nil)
  gmcp.Chimera.Group.State.leader = "S"
  gmcp.Chimera.Combat.State = {primary="", relations={}}
  kozojeb.command("cele snotling")
  kozojeb.start()
  kozojeb.onSessionEvent("sysDisconnectionEvent")
  sends, aliases = {}, {}
  advance(70)
  kozojeb.start()
  assert(not kozojeb.enabled and #sends == 0 and #aliases == 0)
  kozojeb.onSessionEvent("sysConnectionEvent")
  event()
  assert(kozojeb.sessionBlocked)
  kozojeb.onRoomChanged("gmcp.Room.Info")
  event()
  assert(not kozojeb.sessionBlocked and not kozojeb.enabled)
  assert(#sends == 0)
  event("gmcp.Chimera.Group.State")
  event("gmcp.Chimera.Combat.State")
  kozojeb.start()
  assert(count("zabij snotlinga") == 1)
end)

test("new Char.Vitals overrides cached own HP when deciding retreat", function()
  reset(nil)
  gmcp.Chimera.Group.State.leader = "S"
  gmcp.Chimera.Combat.State.primary = "N"
  kozojeb.start()
  room = 1323
  gmcp.Char.Vitals.hp = 30
  event("gmcp.Char.Vitals")
  assert(kozojeb.mode == "escape" and aliases[#aliases] == "/idz 1322")
end)

test("issued patrol movement blocks stale room targets until fresh room confirmation", function()
  reset(nil)
  kozojeb.command("cele snotling")
  gmcp.Chimera.Group.State.leader = "S"
  gmcp.Chimera.Combat.State = {primary="", relations={}}
  local npc = table.remove(gmcp.Chimera.Room.Entities.entities, 4)
  kozojeb.setRooms({1322,1323})
  kozojeb.start()
  advance(0.71)
  assert(count("e") == 1 and kozojeb.roomChangePending)
  gmcp.Chimera.Room.Entities.entities[4] = npc
  event()
  assert(count("zabij snotlinga") == 0 and not kozojeb.entitiesReady)
  room = 1323
  kozojeb.onRoomChanged("gmcp.Room.Info")
  event()
  assert(count("zabij snotlinga") == 1)
end)

test("a rejected exit does not keep the room locked or repeat the same bad edge", function()
  reset(nil)
  gmcp.Chimera.Group.State.leader = "S"
  gmcp.Chimera.Combat.State = {primary="", relations={}}
  table.remove(gmcp.Chimera.Room.Entities.entities, 4)
  kozojeb.setRooms({1322,1323})
  kozojeb.start()
  advance(0.71)
  kozojeb.onMoveRejected()
  advance(3)
  assert(count("e") == 1 and not kozojeb.roomChangePending)
end)

test("unrelated NPC combat never replaces the leader's own attack", function()
  reset(nil)
  kozojeb.command("cele snotling")
  gmcp.Chimera.Group.State.leader = "S"
  gmcp.Chimera.Room.Entities.entities[5] = {id="X",name="Tepy jaszczuroczlek",kind="npc",hp=100,maxhp=100}
  gmcp.Chimera.Combat.State = {primary="",relations={{attacker="X",defender="N"}}}
  kozojeb.start()
  assert(count("zabij snotlinga") == 1)
end)

test("recovery waits for every previously present teammate", function()
  reset(nil)
  gmcp.Chimera.Group.State.leader = "S"
  gmcp.Chimera.Combat.State.primary = "N"
  kozojeb.start()
  gmcp.Chimera.Room.Entities.entities[1].hp = 40
  event()
  assert(kozojeb.mode == "heal_rest")
  local team = gmcp.Chimera.Room.Entities.entities
  gmcp.Chimera.Room.Entities.entities = {team[1]}
  team[1].hp = 100
  gmcp.Chimera.Group.State = {members={}}
  gmcp.Chimera.Combat.State = {primary="",relations={}}
  event("gmcp.Chimera.Group.State")
  advance(3.1)
  assert(kozojeb.mode == "heal_rest" and kozojeb.recoveryMissing)
  gmcp.Chimera.Room.Entities.entities = team
  gmcp.Chimera.Group.State = {leader="S",members={"S","L","M"}}
  event("gmcp.Chimera.Group.State")
  advance(3.1)
  assert(kozojeb.mode ~= "heal_rest")
end)

test("leader rescue prevents reciprocal shields until own health has a margin", function()
  reset("zaslony", 80)
  kozojeb.command("proglidera 85")
  gmcp.Chimera.Room.Entities.entities[1].hp = 64
  kozojeb.start()
  gmcp.Chimera.Combat.State.primary = "N"
  gmcp.Chimera.Combat.State.relations = {{attacker="N",defender="S"}}
  event("gmcp.Chimera.Combat.State")
  shieldReply("Zaslaniasz Yarrima przed ciosami malego snotlinga.")
  kozojeb.onCoveredByLeader("Yarrim")
  gmcp.Chimera.Combat.State.relations = {{attacker="N",defender="L"}}
  event("gmcp.Chimera.Combat.State")
  advance(3)
  kozojeb.onFormationReady()
  advance(0.13)
  assert(kozojeb.leaderRescue and count("zaslon yarrima") == 1)
  gmcp.Chimera.Room.Entities.entities[1].hp = 84
  event()
  assert(count("zaslon yarrima") == 1)
  gmcp.Chimera.Room.Entities.entities[1].hp = 85
  event()
  assert(not kozojeb.leaderRescue and count("zaslon yarrima") == 2)
  noMovement()
end)

test("a bystander shield never changes the follower's shield policy", function()
  reset("zaslony", 60)
  kozojeb.start()
  kozojeb.onCoveredByLeader("Morrid")
  assert(not kozojeb.leaderRescue)
end)

test("broken party weapon triggers the leader retreat and blocks automatic restart", function()
  reset(nil)
  gmcp.Chimera.Group.State.leader = "S"
  gmcp.Chimera.Combat.State.primary = "N"
  kozojeb.start()
  room = 1323
  kozojeb.onEquipmentBroken("Nulnijski dlugi ronkon dzierzony przez Yarrima peka!!!")
  assert(kozojeb.mode == "escape" and aliases[#aliases] == "/idz 1322")
  room = 1322
  kozojeb.onRoomChanged("gmcp.Room.Info")
  event()
  advance(4)
  assert(kozojeb.config.equipmentHold and kozojeb.mode == "heal_rest")
  kozojeb.command("ekwipunek gotowy")
  advance(3.1)
  assert(not kozojeb.config.equipmentHold and kozojeb.mode ~= "heal_rest")
end)

test("supporters never retreat or report a broken weapon", function()
  for _, role in ipairs({"wsparcie", "zaslony"}) do
    reset(role)
    kozojeb.start()
    kozojeb.onEquipmentBroken("Ciezki typowy mlot bojowy peka!!!")
    kozojeb.onEquipmentBroken("Nulnijski dlugi ronkon dzierzony przez Yarrima peka!!!")
    assert(not kozojeb.config.equipmentHold)
    noMovement()
  end
end)

test("unknown weapon owner is ignored by the leader", function()
  reset(nil)
  gmcp.Chimera.Group.State.leader = "S"
  kozojeb.start()
  kozojeb.onEquipmentBroken("Krzywy noz dzierzony przez obcego mezczyzne peka!!!")
  assert(not kozojeb.config.equipmentHold and kozojeb.mode ~= "escape")
end)

test("full profile settings survive a fresh core session", function()
  reset("zaslony")
  kozojeb.command("cele snotling")
  kozojeb.command("predkosc 0.4")
  kozojeb.command("pauza 1")
  kozojeb.command("minhpzaslony 75")
  kozojeb.command("maxstworow 4")
  kozojeb.setRooms({1322,1323})
  kozojeb = nil
  dofile(source)
  assert(kozojeb.config.role == "zaslony" and kozojeb.config.shieldSelfHp == 75)
  assert(kozojeb.config.patrolDelay == 0.4 and kozojeb.config.killPause == 1)
  assert(kozojeb.config.targets.snotling and not kozojeb.config.targets.koza)
  assert(kozojeb.config.maxCreatures == 4 and #kozojeb.rooms == 2)
  assert(not kozojeb.enabled)
end)

test("a stopped bot in combat cannot install an update", function()
  reset("wsparcie")
  kozojeb.start()
  gmcp.Chimera.Combat.State.primary = "N"
  kozojeb.stop()
  assert(not kozojeb.isUpdateSafe())
  gmcp.Chimera.Combat.State = {primary="",relations={}}
  assert(kozojeb.isUpdateSafe())
  kozojeb.onSessionEvent("sysDisconnectionEvent")
  assert(not kozojeb.isUpdateSafe())
end)

test("all package scripts initialize together and uninstall cleans up the updater", function()
  reset("wsparcie")
  dofile("src/Sha256.lua")
  dofile("src/KozojebUpdater.lua")
  assert(kozojeb.initialized and kozojeb.updater.initialized)
  kozojeb.command("aktualizuj")
  kozojeb.onUninstall("sysUninstallPackage", "Chimera_Kozojeb")
  advance(60)
  assert(not kozojeb.enabled)
end)

test("update gate rejects unknown targets and player combat", function()
  reset("wsparcie")
  gmcp.Chimera.Combat.State = {primary="missing target", relations={}}
  assert(not kozojeb.isUpdateSafe())
  gmcp.Chimera.Combat.State = {primary="", relations={{attacker="M",defender="S"}}}
  assert(not kozojeb.isUpdateSafe())
  gmcp.Chimera.Combat.State = {primary="", relations={{attacker="M",defender="L"}}}
  assert(kozojeb.isUpdateSafe())
end)

test("KozoBot profile settings migrate to the new project without losing the area", function()
  reset("zaslony")
  kozojeb.command("cele snotling")
  kozojeb.command("proglidera 85")
  kozojeb.setRooms({1322,1323})
  saved["/profile-under-test/chimera_kozobot_settings.lua"] = saved["/profile-under-test/chimera_kozojeb_settings.lua"]
  saved["/profile-under-test/chimera_kozojeb_settings.lua"] = nil
  kozojeb = nil
  dofile(source)
  assert(kozojeb.config.role == "zaslony" and kozojeb.config.leaderShieldHp == 85)
  assert(kozojeb.config.targets.snotling and not kozojeb.config.targets.koza and #kozojeb.rooms == 2)
  kozojeb.command("minhpzaslony 75")
  assert(saved["/profile-under-test/chimera_kozojeb_settings.lua"].config.shieldSelfHp == 75)
end)

test("in-memory KozoBot settings are copied and the former bot is stopped", function()
  reset(nil)
  local previous = kozojeb
  previous.command("cele snotling")
  saved = {}
  kozobot, kozojeb = previous, nil
  dofile(source)
  assert(kozojeb.config.targets.snotling and not kozojeb.config.targets.koza)
  assert(kozojeb.config ~= previous.config and not previous.enabled)
  kozobot = nil
end)

print(string.format("%d simulations passed", total))
