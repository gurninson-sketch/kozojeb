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
function getEpoch() return clock end
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
local function reconnectPackets()
  kozojeb.onRoomChanged("gmcp.Room.Info")
  event("gmcp.Chimera.Room.Entities")
  event("gmcp.Chimera.Group.State")
  event("gmcp.Chimera.Combat.State")
  event("gmcp.Char.Vitals")
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
  kozojeb.onGmcp("gmcp.Chimera.Room.Entities")
  kozojeb.onGmcp("gmcp.Chimera.Combat.State")
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
    {id="S", name="Yergo", self=1, hp=400, maxhp=400},
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

test("100 percent shield setting still requires a useful defensive reserve", function()
  reset("zaslony", 99)
  kozojeb.command("proglidera 100")
  kozojeb.start()
  assert(count("zaslon yarrima") == 0, "one percent difference is not a useful transfer")
  reset("zaslony", 99)
  local own = gmcp.Chimera.Room.Entities.entities[1]
  own.hp, own.maxhp = 200, 200
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
  assert(count("zaslon yarrima") == 1, "reverse transfer ignored stabilization")
  advance(8.1)
  event()
  assert(count("zaslon yarrima") == 2, "shield did not resume after stabilization")
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
  gmcp.Chimera.Room.Entities.entities[1].hp = 100
  gmcp.Chimera.Room.Entities.entities[1].maxhp = 200
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
  entities[1].hp, entities[1].maxhp = 500, 500
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

test("disconnect cancels commands and resumes automatically after fresh login data", function()
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
  assert(not kozojeb.enabled and #sends == 0)
  event("gmcp.Char.Vitals")
  assert(kozojeb.enabled and count("zabij snotlinga") == 1)
  event("gmcp.Char.Vitals")
  assert(count("zabij snotlinga") == 1, "resume executed twice")
end)

test("automatic resume preserves the original base, area and patrol progress", function()
  reset(nil)
  gmcp.Chimera.Group.State.leader = "S"
  kozojeb.command("cele snotling")
  kozojeb.setRooms({1322,1323,1324})
  kozojeb.start()
  kozojeb.visited[1324] = true
  room = 1323
  kozojeb.onSessionEvent("sysDisconnectionEvent")
  sends, aliases = {}, {}
  kozojeb.onSessionEvent("sysConnectionEvent")
  kozojeb.onSessionEvent("login")
  kozojeb.onSessionEvent("login")
  reconnectPackets()
  assert(kozojeb.enabled and kozojeb.config.startRoom == 1322)
  assert(#kozojeb.rooms == 3 and kozojeb.visited[1324])
  assert(count("zabij snotlinga") == 1 and #aliases == 0)
end)

test("fresh room snapshot resumes a leader without requiring unchanged GMCP channels", function()
  reset(nil)
  gmcp.Chimera.Group.State.leader = "S"
  gmcp.Chimera.Combat.State = {primary="",relations={}}
  gmcp.Chimera.Room.Entities.entities[1].group_role = "leader"
  gmcp.Chimera.Room.Entities.entities[2].group_role = "member"
  kozojeb.command("cele snotling")
  kozojeb.start()
  room = 1323
  kozojeb.onSessionEvent("sysDisconnectionEvent")
  sends, aliases = {}, {}
  kozojeb.onSessionEvent("sysConnectionEvent")
  gmcp.Chimera.Group.State.leader = "M" -- stale cache must stay ignored
  kozojeb.onRoomChanged("gmcp.Room.Info")
  event()
  advance(0.51)
  assert(kozojeb.enabled and not kozojeb.reconnectTask)
  assert(not kozojeb.sessionFresh.group and not kozojeb.sessionFresh.combat)
  assert(not kozojeb.sessionFresh.vitals and kozojeb.config.startRoom == 1322)
  assert(count("zabij snotlinga") == 1)
end)

test("support resumes without a legacy Vitals event and ignores old combat until new evidence", function()
  reset("wsparcie")
  kozojeb.start()
  kozojeb.onSessionEvent("sysDisconnectionEvent")
  sends, aliases = {}, {}
  kozojeb.onSessionEvent("sysConnectionEvent")
  kozojeb.onRoomChanged("gmcp.Room.Info")
  event()
  advance(0.51)
  assert(kozojeb.enabled and kozojeb.mode == "support_wait")
  assert(#sends == 0, "stale Combat.State caused support")
  kozojeb.onTeamCombat("Yarrim", "malego glupkowatego snotlinga")
  advance(0.13)
  assert(count("wesprzyj") == 1)
  noMovement()
end)

test("reconnect status names missing required room data and incomplete own HP", function()
  reset("wsparcie")
  kozojeb.start()
  kozojeb.onSessionEvent("sysDisconnectionEvent")
  kozojeb.onSessionEvent("sysConnectionEvent")
  kozojeb.tryResumeAfterReconnect()
  assert(kozojeb.reconnectWaitReason:find("Room.Info",1,true))
  kozojeb.onRoomChanged("gmcp.Room.Info")
  kozojeb.tryResumeAfterReconnect()
  assert(kozojeb.reconnectWaitReason:find("Room.Entities",1,true))
  gmcp.Chimera.Room.Entities.entities[1].maxhp = nil
  event()
  assert(kozojeb.reconnectWaitReason:find("HP",1,true) and not kozojeb.enabled)
  gmcp.Chimera.Room.Entities.entities[1].maxhp = 100
  event()
  advance(0.51)
  assert(kozojeb.enabled and not kozojeb.reconnectWaitReason)
end)

test("manual stop cancels the short snapshot settling timer", function()
  reset("wsparcie")
  kozojeb.start()
  kozojeb.onSessionEvent("sysDisconnectionEvent")
  kozojeb.onSessionEvent("sysConnectionEvent")
  sends, aliases = {}, {}
  kozojeb.onRoomChanged("gmcp.Room.Info")
  event()
  assert(not kozojeb.enabled)
  kozojeb.command("stop")
  advance(2)
  assert(not kozojeb.enabled and not kozojeb.reconnectTask and #sends == 0)
end)

test("missing unchanged channels cannot leave support paused for ninety minutes", function()
  reset("wsparcie")
  kozojeb.start()
  kozojeb.onSessionEvent("sysDisconnectionEvent")
  kozojeb.onSessionEvent("sysConnectionEvent")
  sends, aliases = {}, {}
  kozojeb.onRoomChanged("gmcp.Room.Info")
  event()
  advance(5400)
  assert(kozojeb.enabled and not kozojeb.reconnectTask and #sends == 0)
  noMovement()
end)

test("reconnecting after the team heals resumes the interrupted recovery without extra GMCP events", function()
  reset(nil)
  gmcp.Chimera.Group.State.leader = "S"
  gmcp.Chimera.Room.Entities.entities[1].group_role = "leader"
  gmcp.Chimera.Room.Entities.entities[2].group_role = "member"
  gmcp.Chimera.Combat.State = {primary="",relations={}}
  kozojeb.start()
  room = 1323
  gmcp.Chimera.Room.Entities.entities[3].hp = 47
  event()
  room = 1322
  kozojeb.onRoomChanged("gmcp.Room.Info")
  event()
  assert(kozojeb.mode == "heal_rest" and kozojeb.injuredTeamMember == "Morrid")
  kozojeb.onSessionEvent("sysDisconnectionEvent")
  sends, aliases = {}, {}
  kozojeb.onSessionEvent("sysConnectionEvent")
  gmcp.Chimera.Room.Entities.entities[3].hp = 100
  kozojeb.onRoomChanged("gmcp.Room.Info")
  event()
  advance(3.6)
  assert(kozojeb.enabled and kozojeb.mode == "patrol" and not kozojeb.reconnectTask)
  assert(kozojeb.config.startRoom == 1322 and #aliases == 0)
end)

test("a manual stop during reconnect cancels automatic resume", function()
  reset("wsparcie")
  kozojeb.start()
  kozojeb.onSessionEvent("sysDisconnectionEvent")
  kozojeb.command("stop")
  sends, aliases = {}, {}
  kozojeb.onSessionEvent("sysConnectionEvent")
  reconnectPackets()
  advance(60)
  assert(not kozojeb.enabled and not kozojeb.reconnectTask)
  assert(#sends == 0 and #aliases == 0)
end)

test("a previously stopped bot never starts just because the session reconnects", function()
  reset("wsparcie")
  kozojeb.onSessionEvent("sysDisconnectionEvent")
  kozojeb.onSessionEvent("sysConnectionEvent")
  reconnectPackets()
  assert(not kozojeb.enabled and #sends == 0 and #aliases == 0)
end)

test("both supporting roles resume automatically without independent movement", function()
  for _, role in ipairs({"wsparcie", "zaslony"}) do
    reset(role, 60)
    kozojeb.start()
    kozojeb.onSessionEvent("sysDisconnectionEvent")
    sends, aliases = {}, {}
    gmcp.Chimera.Room.Entities.entities[1].hp = 20
    gmcp.Char.Vitals = {hp=20,maxhp=100,moves=0,maxmoves=100}
    room = 9999
    kozojeb.onSessionEvent("sysConnectionEvent")
    reconnectPackets()
    assert(kozojeb.enabled and kozojeb.config.role == role)
    assert(count("wesprzyj") == 1)
    noMovement()
  end
end)

test("a leader waits for previously visible teammates to reconnect", function()
  reset(nil)
  gmcp.Chimera.Group.State.leader = "S"
  kozojeb.command("cele snotling")
  kozojeb.start()
  kozojeb.onSessionEvent("sysDisconnectionEvent")
  sends, aliases = {}, {}
  local missing = table.remove(gmcp.Chimera.Room.Entities.entities, 3)
  kozojeb.onSessionEvent("sysConnectionEvent")
  reconnectPackets()
  assert(not kozojeb.enabled and kozojeb.reconnectTask)
  assert(#sends == 0 and #aliases == 0 and not kozojeb.isUpdateSafe())
  gmcp.Chimera.Room.Entities.entities[#gmcp.Chimera.Room.Entities.entities + 1] = missing
  event()
  assert(kozojeb.enabled and count("zabij snotlinga") == 1)
end)

test("a second disconnection invalidates partially received reconnect data", function()
  reset("wsparcie")
  kozojeb.start()
  kozojeb.onSessionEvent("sysDisconnectionEvent")
  sends, aliases = {}, {}
  kozojeb.onSessionEvent("sysConnectionEvent")
  kozojeb.onRoomChanged("gmcp.Room.Info")
  event()
  event("gmcp.Chimera.Group.State")
  kozojeb.onSessionEvent("sysDisconnectionEvent")
  kozojeb.onSessionEvent("sysConnectionEvent")
  event("gmcp.Chimera.Combat.State")
  event("gmcp.Char.Vitals")
  assert(not kozojeb.enabled and #sends == 0)
  kozojeb.onRoomChanged("gmcp.Room.Info")
  event()
  assert(not kozojeb.enabled)
  event("gmcp.Chimera.Group.State")
  advance(0.51)
  assert(kozojeb.enabled and count("wesprzyj") == 1)
end)

test("changing role while disconnected cancels the previous task", function()
  reset("wsparcie")
  kozojeb.start()
  kozojeb.onSessionEvent("sysDisconnectionEvent")
  kozojeb.command("rola prowadzacy")
  sends, aliases = {}, {}
  kozojeb.onSessionEvent("sysConnectionEvent")
  reconnectPackets()
  assert(not kozojeb.enabled and not kozojeb.reconnectTask)
  assert(#sends == 0 and #aliases == 0)
end)

test("healing resumes at the original base and still waits for the wounded teammate", function()
  reset(nil)
  gmcp.Chimera.Group.State.leader = "S"
  gmcp.Chimera.Combat.State = {primary="",relations={}}
  kozojeb.start()
  room = 1323
  gmcp.Chimera.Room.Entities.entities[3].hp = 40
  event()
  assert(kozojeb.mode == "escape" and kozojeb.injuredTeamMember == "Morrid")
  kozojeb.onSessionEvent("sysDisconnectionEvent")
  sends, aliases = {}, {}
  kozojeb.onSessionEvent("sysConnectionEvent")
  reconnectPackets()
  assert(kozojeb.mode == "escape" and aliases[1] == "/idz 1322")
  room = 1322
  kozojeb.onRoomChanged("gmcp.Room.Info")
  event()
  advance(3.1)
  assert(kozojeb.mode == "heal_rest" and kozojeb.injuredTeamMember == "Morrid")
  gmcp.Chimera.Room.Entities.entities[3].hp = 100
  event()
  advance(3.1)
  assert(kozojeb.mode ~= "heal_rest" and kozojeb.config.startRoom == 1322)
end)

test("fresh low movement after reconnect causes a collective retreat to the saved base", function()
  reset(nil)
  gmcp.Chimera.Group.State.leader = "S"
  kozojeb.start()
  room = 1323
  kozojeb.onSessionEvent("sysDisconnectionEvent")
  sends, aliases = {}, {}
  gmcp.Char.Vitals.moves = 0
  kozojeb.onSessionEvent("sysConnectionEvent")
  reconnectPackets()
  assert(kozojeb.mode == "escape" and aliases[1] == "/idz 1322")
end)

test("a missing teammate cannot block emergency retreat after reconnect", function()
  reset(nil)
  gmcp.Chimera.Group.State.leader = "S"
  gmcp.Chimera.Combat.State = {primary="",relations={}}
  kozojeb.start()
  room = 1323
  kozojeb.onSessionEvent("sysDisconnectionEvent")
  sends, aliases = {}, {}
  table.remove(gmcp.Chimera.Room.Entities.entities, 3)
  gmcp.Chimera.Room.Entities.entities[1].hp = 20
  gmcp.Char.Vitals.hp = 20
  kozojeb.onSessionEvent("sysConnectionEvent")
  reconnectPackets()
  assert(kozojeb.mode == "escape" and aliases[1] == "/idz 1322")
  assert(kozojeb.recoveryRoster.morrid == "Morrid")
  room = 1322
  kozojeb.onRoomChanged("gmcp.Room.Info")
  gmcp.Chimera.Room.Entities.entities[1].hp = 100
  gmcp.Char.Vitals.hp = 100
  event()
  advance(3.1)
  assert(kozojeb.mode == "heal_rest" and kozojeb.recoveryMissing == "Morrid")
end)

test("watchdog return resumes from fresh position without moving the saved base", function()
  reset(nil)
  gmcp.Chimera.Group.State.leader = "S"
  kozojeb.start()
  room = 1323
  kozojeb.onIdleTimeout()
  assert(kozojeb.mode == "idle_return")
  kozojeb.onSessionEvent("sysDisconnectionEvent")
  sends, aliases = {}, {}
  kozojeb.onSessionEvent("sysConnectionEvent")
  reconnectPackets()
  advance(0.21)
  assert(kozojeb.enabled and kozojeb.mode == "idle_return")
  assert(kozojeb.config.startRoom == 1322 and count("w") == 1)
end)

test("automatic resume chooses a fresh target instead of replaying an old entity ID", function()
  reset(nil)
  gmcp.Chimera.Group.State.leader = "S"
  gmcp.Chimera.Combat.State = {primary="",relations={}}
  kozojeb.command("cele snotling")
  kozojeb.start()
  assert(kozojeb.currentTargetId == "N")
  kozojeb.onSessionEvent("sysDisconnectionEvent")
  sends, aliases = {}, {}
  gmcp.Chimera.Room.Entities.entities[4] = {
    id="NEW",name="Niski dziecinny snotling",kind="npc",hp=100,maxhp=100,
  }
  kozojeb.onSessionEvent("sysConnectionEvent")
  reconnectPackets()
  assert(kozojeb.enabled and kozojeb.currentTargetId == "NEW")
  assert(count("zabij snotlinga") == 1)
end)

test("automatic resume waits for valid own HP rather than reusing health from before login", function()
  reset("wsparcie")
  kozojeb.start()
  kozojeb.onSessionEvent("sysDisconnectionEvent")
  sends, aliases = {}, {}
  local own = gmcp.Chimera.Room.Entities.entities[1]
  own.maxhp = nil
  gmcp.Char.Vitals = {hp=10,moves=100,maxmoves=100}
  kozojeb.onSessionEvent("sysConnectionEvent")
  reconnectPackets()
  assert(not kozojeb.enabled and kozojeb.reconnectTask and #sends == 0)
  own.maxhp = 100
  event()
  advance(0.51)
  assert(kozojeb.enabled and count("wesprzyj") == 1)
  noMovement()
end)

test("logging in as another character cancels the suspended task", function()
  reset("wsparcie")
  kozojeb.start()
  kozojeb.onSessionEvent("sysDisconnectionEvent")
  sends, aliases = {}, {}
  gmcp.Chimera.Room.Entities.entities[1].name = "InnaPostac"
  kozojeb.onSessionEvent("sysConnectionEvent")
  reconnectPackets()
  assert(not kozojeb.enabled and not kozojeb.reconnectTask and #sends == 0)
end)

test("reconnecting during an equipment hold resumes recovery without restarting the patrol", function()
  reset(nil)
  gmcp.Chimera.Group.State.leader = "S"
  gmcp.Chimera.Combat.State = {primary="",relations={}}
  kozojeb.start()
  kozojeb.onEquipmentBroken("Ciezki typowy mlot bojowy peka!!!")
  assert(kozojeb.mode == "heal_rest" and kozojeb.config.equipmentHold)
  kozojeb.onSessionEvent("sysDisconnectionEvent")
  sends, aliases = {}, {}
  kozojeb.onSessionEvent("sysConnectionEvent")
  reconnectPackets()
  advance(6.1)
  assert(kozojeb.enabled and kozojeb.mode == "heal_rest" and kozojeb.config.equipmentHold)
  assert(#aliases == 0)
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

test("partial Char.Vitals never borrows maximum HP from room entities", function()
  reset(nil)
  gmcp.Chimera.Group.State.leader = "S"
  gmcp.Chimera.Combat.State = {primary="", relations={}}
  kozojeb.start()
  room = 1323
  gmcp.Char.Vitals = {hp=10, moves=100, maxmoves=100}
  event("gmcp.Char.Vitals")
  assert(kozojeb.lastHp == 100 and kozojeb.mode == "patrol")
  assert(#aliases == 0, "incomplete HP caused a false retreat")
end)

test("partial room HP never borrows maximum HP from Char.Vitals", function()
  reset(nil)
  gmcp.Char.Vitals.hp, gmcp.Char.Vitals.maxhp = 1000, 1000
  local own = gmcp.Chimera.Room.Entities.entities[1]
  own.hp, own.maxhp = 100, nil
  event()
  kozojeb.command("status")
  assert(kozojeb.lastHp == 100, "mixed HP scales produced a false 10 percent")
end)

test("movement with partial HP does not repeat the retreat loop from the log", function()
  reset(nil)
  kozojeb.config.emptyPatrolMax = 0
  gmcp.Chimera.Group.State.leader = "S"
  gmcp.Chimera.Combat.State = {primary="", relations={}}
  table.remove(gmcp.Chimera.Room.Entities.entities, 4)
  kozojeb.setRooms({1322,1323})
  kozojeb.start()
  for step = 1, 8 do
    advance(0.71)
    assert(kozojeb.roomChangePending, "patrol did not issue a direction")
    gmcp.Char.Vitals = {hp=10, moves=100, maxmoves=100}
    event("gmcp.Char.Vitals")
    assert(kozojeb.lastHp == 100 and kozojeb.mode == "patrol" and #aliases == 0)
    room = room == 1322 and 1323 or 1322
    kozojeb.onRoomChanged("gmcp.Room.Info")
    event()
    assert(kozojeb.lastHp == 100 and kozojeb.mode == "patrol" and #aliases == 0)
  end
end)

test("complete Char.Vitals uses its own HP scale and still triggers real retreat", function()
  reset(nil)
  gmcp.Chimera.Group.State.leader = "S"
  gmcp.Chimera.Combat.State = {primary="", relations={}}
  kozojeb.start()
  room = 1323
  gmcp.Char.Vitals = {hp="10", maxhp="10", moves=100, maxmoves=100}
  event("gmcp.Char.Vitals")
  assert(kozojeb.lastHp == 100 and kozojeb.mode == "patrol")
  gmcp.Char.Vitals.hp = "3"
  event("gmcp.Char.Vitals")
  assert(kozojeb.lastHp == 30 and kozojeb.mode == "escape")
  assert(aliases[#aliases] == "/idz 1322")
end)

test("incomplete HP cannot declare full recovery and restart patrol", function()
  reset(nil)
  gmcp.Chimera.Group.State.leader = "S"
  gmcp.Chimera.Combat.State = {primary="", relations={}}
  kozojeb.start()
  room = 1323
  gmcp.Char.Vitals.hp = 20
  event("gmcp.Char.Vitals")
  assert(kozojeb.mode == "escape")
  local own = gmcp.Chimera.Room.Entities.entities[1]
  own.hp, own.maxhp = 100, nil
  gmcp.Char.Vitals = {hp=100, moves=100, maxmoves=100}
  room = 1322
  kozojeb.onRoomChanged("gmcp.Room.Info")
  event()
  advance(3.1)
  assert(kozojeb.lastHp == 20 and kozojeb.mode == "heal_rest")
  own.maxhp = 100
  event()
  advance(3.1)
  assert(kozojeb.lastHp == 100 and kozojeb.mode ~= "heal_rest")
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

test("reverse transfers use NPC stabilization rather than five percentage points", function()
  reset("zaslony", 80)
  kozojeb.command("proglidera 85")
  local own = gmcp.Chimera.Room.Entities.entities[1]
  own.hp, own.maxhp = 100, 150
  kozojeb.start()
  assert(count("zaslon yarrima") == 1)
  gmcp.Chimera.Combat.State.primary = "N"
  gmcp.Chimera.Combat.State.relations = {{attacker="N",defender="S"}}
  event("gmcp.Chimera.Combat.State")
  shieldReply("Zaslaniasz Yarrima przed ciosami malego snotlinga.")
  gmcp.Chimera.Combat.State.relations = {{attacker="N",defender="L"}}
  event("gmcp.Chimera.Combat.State")
  kozojeb.onCoveredByLeader("Yarrim")
  advance(3)
  kozojeb.onFormationReady()
  advance(0.13)
  assert(count("zaslon yarrima") == 1)
  own.hp = 127 -- 85%, wiecej niz dawny warunek 80 + 5 pp
  event()
  assert(count("zaslon yarrima") == 1, "percentage margin bypassed the hold")
  advance(8.1)
  event()
  assert(count("zaslon yarrima") == 2)
  noMovement()
end)

test("a bystander shield never changes the follower's shield policy", function()
  reset("zaslony", 60)
  kozojeb.start()
  kozojeb.onCoveredByLeader("Obcy")
  assert(next(kozojeb.shieldTransfers) == nil)
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


local function setupLeader()
  reset(nil)
  gmcp.Chimera.Group.State.leader = "S"
  gmcp.Chimera.Room.Entities.entities[1].group_role = "leader"
  gmcp.Chimera.Room.Entities.entities[2].group_role = "member"
  gmcp.Chimera.Combat.State.primary = "N"
  kozojeb.command("cele snotling")
end

test("fresh room team HP overrides an older complete group record", function()
  setupLeader()
  gmcp.Chimera.Group.State.members = {"S", "L", {entity_id="M", name="morrid", hp=100, maxhp=100}}
  kozojeb.start()
  room = 1323
  gmcp.Chimera.Room.Entities.entities[3].hp = 31
  event()
  assert(kozojeb.teamHealth.morrid == 31 and kozojeb.teamVitals.morrid.hp == 31)
  assert(kozojeb.teamSeenCount == 2 and kozojeb.mode == "escape")
  assert(aliases[#aliases] == "/idz 1322")
end)

test("a newer complete group HP update triggers retreat before room HP arrives", function()
  setupLeader()
  kozojeb.start()
  room = 1323
  gmcp.Chimera.Group.State.members = {"S", "L", {id="M", name="Morrid", hp=30, max_hp=100}}
  event("gmcp.Chimera.Group.State")
  assert(kozojeb.teamHealth.morrid == 30 and kozojeb.mode == "escape")
end)

test("fresh group healing is not overwritten by an older injured room snapshot", function()
  setupLeader()
  kozojeb.start()
  room = 1323
  gmcp.Chimera.Room.Entities.entities[3].hp = 30
  gmcp.Chimera.Group.State.members = {"S", "L", {id="M", name="Morrid", hp=90, maxhp=100}}
  event("gmcp.Chimera.Group.State")
  assert(kozojeb.teamHealth.morrid == 90 and kozojeb.mode == "combat" and #aliases == 0)
end)

test("invalid and incomplete group HP cannot displace a complete room pair", function()
  setupLeader()
  kozojeb.start()
  gmcp.Chimera.Group.State.members = {"S", "L", {id="M", name="Morrid", hp=1000, maxhp=100}}
  event("gmcp.Chimera.Group.State")
  assert(kozojeb.teamHealth.morrid == 100)
  gmcp.Chimera.Group.State.members[3] = {id="M", name="Morrid", hp=1}
  event("gmcp.Chimera.Group.State")
  assert(kozojeb.teamHealth.morrid == 100 and #aliases == 0)
end)

test("raw HP prevents a smaller healthy pool from replacing a larger injured pool", function()
  reset("zaslony", 70)
  local e = gmcp.Chimera.Room.Entities.entities
  e[1].hp, e[1].maxhp = 400, 500
  e[2].hp, e[2].maxhp = 1050, 1500
  kozojeb.command("proglidera 85")
  kozojeb.start()
  assert(count("zaslon yarrima") == 0 and kozojeb.shieldBlockedReason)
  noMovement()
end)

test("a lower percentage may protect safely when it has more real HP", function()
  reset("zaslony")
  local e = gmcp.Chimera.Room.Entities.entities
  e[1].hp, e[1].maxhp = 720, 1200
  e[2].hp, e[2].maxhp = 468, 600
  kozojeb.command("proglidera 85")
  kozojeb.start()
  assert(count("zaslon yarrima") == 1)
  assert(kozojeb.shieldDecision.ownHp == 720 and kozojeb.shieldDecision.targetHp == 468)
  noMovement()
end)

test("legacy Char.Vitals units are never compared as raw party HP", function()
  reset("zaslony")
  gmcp.Char.Vitals = {hp=10,maxhp=10,moves=100,maxmoves=100}
  local e = gmcp.Chimera.Room.Entities.entities
  e[1].hp,e[1].maxhp = 400,500
  e[2].hp,e[2].maxhp = 1050,1500
  kozojeb.command("proglidera 85")
  kozojeb.start()
  event("gmcp.Char.Vitals")
  assert(count("zaslon yarrima") == 0)
end)

test("a protector already facing two enemies cannot take a third", function()
  reset("zaslony", 85)
  kozojeb.command("proglidera 90")
  local e = gmcp.Chimera.Room.Entities.entities
  e[5] = {id="T",name="Drugi snotling",kind="npc",hp=100,maxhp=100}
  e[6] = {id="U",name="Trzeci snotling",kind="npc",hp=100,maxhp=100}
  gmcp.Chimera.Combat.State = {primary="T",relations={
    {attacker="N",defender="L"},{attacker="T",defender="S"},{attacker="U",defender="S"}}}
  kozojeb.start()
  assert(count("zaslon yarrima") == 0 and kozojeb.shieldBlockedReason:find("Limit",1,true))
  noMovement()
end)

test("two similar defenders keep one enemy each instead of accumulating both", function()
  reset("zaslony", 60)
  local e = gmcp.Chimera.Room.Entities.entities
  e[5] = {id="T",name="Drugi snotling",kind="npc",hp=100,maxhp=100}
  gmcp.Chimera.Combat.State.relations = {{attacker="N",defender="L"},{attacker="T",defender="L"}}
  kozojeb.start()
  assert(count("zaslon yarrima") == 1)
  gmcp.Chimera.Combat.State = {primary="N",relations={
    {attacker="N",defender="S"},{attacker="T",defender="L"}}}
  event("gmcp.Chimera.Combat.State")
  shieldReply("Zaslaniasz Yarrima przed ciosami malego snotlinga.")
  advance(3)
  kozojeb.onFormationReady()
  advance(0.13)
  assert(count("zaslon yarrima") == 1)
  noMovement()
end)

test("duplicate relations count one NPC and outgoing attacks do not add incoming load", function()
  reset("zaslony", 60)
  local e = gmcp.Chimera.Room.Entities.entities
  e[1].hp,e[1].maxhp = 1000,1000
  e[5] = {id="T",name="Drugi snotling",kind="npc",hp=100,maxhp=100}
  e[6] = {id="U",name="Trzeci snotling",kind="npc",hp=100,maxhp=100}
  gmcp.Chimera.Combat.State = {primary="T",relations={
    {attacker="N",defender="L"},{attacker="T",defender="S"},{attacker="T",defender="S"},
    {attacker="S",defender="U"},{attacker="S",defender="N"}}}
  kozojeb.start()
  assert(count("zaslon yarrima") == 1 and kozojeb.shieldDecision.ownAttackers == 1)
end)

test("identical NPC descriptions still represent separate attackers", function()
  reset("zaslony", 60)
  local e = gmcp.Chimera.Room.Entities.entities
  e[5] = {id="T",name=e[4].name,kind="npc",hp=100,maxhp=100}
  e[6] = {id="U",name=e[4].name,kind="npc",hp=100,maxhp=100}
  gmcp.Chimera.Combat.State = {primary="T",relations={
    {attacker="N",defender="L"},{attacker="T",defender="S"},{attacker="U",defender="S"}}}
  kozojeb.start()
  assert(count("zaslon yarrima") == 0)
end)

test("recent HP loss reduces the reserve until its observation decays", function()
  reset("zaslony", 80)
  kozojeb.command("proglidera 0")
  local own = gmcp.Chimera.Room.Entities.entities[1]
  own.hp,own.maxhp = 120,150
  kozojeb.start()
  own.hp = 100
  event()
  kozojeb.command("proglidera 85")
  event()
  assert(count("zaslon yarrima") == 0)
  advance(8.1)
  event()
  assert(count("zaslon yarrima") == 1)
end)

test("failed rescue at 63 percent makes the leader withdraw the whole team", function()
  setupLeader()
  gmcp.Chimera.Room.Entities.entities[3].hp = 63
  gmcp.Chimera.Combat.State.relations = {{attacker="N",defender="M"}}
  kozojeb.start()
  room = 1323
  assert(count("zaslon morrida") == 1)
  shieldReply("Probujesz zaslonic Morrida przed ciosami malego snotlinga, lecz nie jestes w stanie tego uczynic.")
  advance(0.13)
  assert(kozojeb.mode == "escape" and kozojeb.injuredTeamMember == "Morrid")
  assert(aliases[#aliases] == "/idz 1322")
end)

test("the same failed rescue cannot make a follower retreat or report", function()
  reset("zaslony", 63)
  kozojeb.start()
  shieldReply("Probujesz zaslonic Yarrima przed ciosami malego snotlinga, lecz nie jestes w stanie tego uczynic.")
  advance(3)
  event()
  assert(kozojeb.enabled and kozojeb.mode ~= "escape")
  noMovement()
end)

test("already fighting confirms support even before the self combat packet", function()
  reset("wsparcie", 60)
  kozojeb.start()
  kozojeb.onSupportResult(true)
  for i=1,10 do advance(2.1) event() end
  assert(count("wesprzyj") == 1)
  local e = gmcp.Chimera.Room.Entities.entities
  e[5] = {id="T",name="Drugi snotling",kind="npc",hp=100,maxhp=100}
  kozojeb.onGmcp("gmcp.Chimera.Room.Entities")
  gmcp.Chimera.Combat.State.relations = {{attacker="L",defender="T"},{attacker="T",defender="L"}}
  event("gmcp.Chimera.Combat.State")
  assert(count("wesprzyj") == 2)
  noMovement()
end)

test("rejected support waits for new combat evidence rather than every HP packet", function()
  reset("wsparcie", 60)
  kozojeb.start()
  kozojeb.onSupportResult(false)
  for i=1,10 do advance(2.1) event() end
  assert(count("wesprzyj") == 1)
  event("gmcp.Chimera.Combat.State")
  assert(count("wesprzyj") == 1)
  gmcp.Chimera.Combat.State.relations[#gmcp.Chimera.Combat.State.relations+1] = {attacker="M",defender="N"}
  event("gmcp.Chimera.Combat.State")
  assert(count("wesprzyj") == 2)
  noMovement()
end)

test("support is reserved before a synchronous already fighting reply", function()
  reset("wsparcie", 60)
  local original = send
  send = function(command)
    original(command)
    if command == "wesprzyj" then kozojeb.onSupportResult(true) end
  end
  kozojeb.start()
  send = original
  advance(3)
  event()
  assert(count("wesprzyj") == 1)
end)

test("two thousand combat packets coalesce into one decision timer", function()
  setupLeader()
  kozojeb.start()
  local beforeActions, beforeScheduled, beforeSerial = kozojeb.metrics.actions, kozojeb.metrics.scheduled, serial
  for i=1,2000 do kozojeb.onGmcp("gmcp.Chimera.Combat.State") end
  assert(kozojeb.metrics.scheduled - beforeScheduled == 1 and serial - beforeSerial == 1)
  advance(0.13)
  assert(kozojeb.metrics.actions - beforeActions == 1 and kozojeb.metrics.coalesced >= 1999)
  assert(#aliases == 0)
end)

test("urgent low HP bypasses a queued combat decision", function()
  setupLeader()
  kozojeb.start()
  room = 1323
  kozojeb.onGmcp("gmcp.Chimera.Combat.State")
  gmcp.Char.Vitals.hp = 30
  kozojeb.onGmcp("gmcp.Char.Vitals")
  assert(kozojeb.mode == "escape" and aliases[#aliases] == "/idz 1322")
end)

test("a stopped bot processes packets without timers, decisions or commands", function()
  reset("wsparcie")
  local beforeSerial = serial
  for i=1,2000 do kozojeb.onGmcp("gmcp.Chimera.Room.Entities") end
  assert(serial == beforeSerial and kozojeb.metrics.actions == 0 and #sends == 0)
end)

test("normal progress does not recreate the idle watchdog timer", function()
  setupLeader()
  kozojeb.start()
  local watchdog = kozojeb.idleTimer
  for i=1,10 do
    gmcp.Chimera.Room.Entities.entities[4].hp = 100-i
    event()
    assert(kozojeb.idleTimer == watchdog)
  end
  assert(kozojeb.enabled and #aliases == 0)
end)

test("empty patrols slow within a cap and a fresh target is attacked immediately", function()
  setupLeader()
  gmcp.Chimera.Combat.State = {primary="",relations={}}
  table.remove(gmcp.Chimera.Room.Entities.entities,4)
  kozojeb.setRooms({1322,1323})
  kozojeb.start()
  for i=1,12 do
    advance(3.3)
    assert(kozojeb.roomChangePending)
    room = room == 1322 and 1323 or 1322
    kozojeb.onRoomChanged("gmcp.Room.Info")
    event()
    assert(kozojeb.emptyPatrolDelay <= 3)
  end
  assert(kozojeb.emptyRounds >= 3 and kozojeb.emptyPatrolDelay == 3)
  gmcp.Chimera.Room.Entities.entities[4] = {id="N",name="Maly snotling",kind="npc",hp=100,maxhp=100}
  event()
  assert(count("zabij snotlinga") == 1 and kozojeb.mode == "combat")
  assert(kozojeb.emptyPatrolDelay == 0)
end)

test("shield transfers and damage observations clear when moving to a fresh room", function()
  reset("zaslony",60)
  kozojeb.start()
  gmcp.Chimera.Combat.State.relations = {{attacker="N",defender="S"}}
  event("gmcp.Chimera.Combat.State")
  assert(next(kozojeb.shieldTransfers))
  room=1323
  kozojeb.onRoomChanged("gmcp.Room.Info")
  assert(next(kozojeb.shieldTransfers)==nil and next(kozojeb.healthHistory)==nil)
end)

test("own death cancels both running support and automatic reconnect", function()
  reset("wsparcie")
  kozojeb.start()
  kozojeb.onSessionEvent("sysDisconnectionEvent")
  kozojeb.onDeath()
  assert(not kozojeb.enabled and not kozojeb.reconnectTask)
  kozojeb.onSessionEvent("sysConnectionEvent")
  reconnectPackets()
  assert(not kozojeb.enabled)
  noMovement()
end)

test("new safety and empty patrol settings persist and reject invalid values", function()
  reset("zaslony")
  kozojeb.command("limitzaslony 1")
  kozojeb.command("stabilizacja 12")
  kozojeb.command("pustypatrol 5")
  kozojeb.command("limitzaslony 0")
  kozojeb.command("stabilizacja 100")
  kozojeb.command("pustypatrol -1")
  kozojeb=nil
  dofile(source)
  assert(kozojeb.config.shieldMaxAttackers==1 and kozojeb.config.shieldHold==12 and kozojeb.config.emptyPatrolMax==5)
  sends,aliases={},{}
  kozojeb.command("wydajnosc")
  assert(#sends==0 and #aliases==0)
end)


test("HP bursts keep one queued timer while every critical sample is checked", function()
  setupLeader()
  kozojeb.start()
  local beforeSerial, beforeActions = serial,kozojeb.metrics.actions
  for i=1,2000 do
    gmcp.Chimera.Room.Entities.entities[4].hp = 100-(i%80)
    kozojeb.onGmcp("gmcp.Chimera.Room.Entities")
  end
  assert(serial-beforeSerial == 1)
  advance(0.13)
  assert(kozojeb.metrics.actions-beforeActions == 1 and #aliases==0)
end)

test("disabling team retreat also disables the additional failed shield retreat", function()
  setupLeader()
  kozojeb.command("progdruzyny 0")
  gmcp.Chimera.Room.Entities.entities[3].hp = 63
  gmcp.Chimera.Combat.State.relations = {{attacker="N",defender="M"}}
  kozojeb.start()
  room=1323
  shieldReply("Probujesz zaslonic Morrida przed ciosami malego snotlinga, lecz nie jestes w stanie tego uczynic.")
  advance(0.13)
  assert(kozojeb.mode=="combat" and #aliases==0)
end)

test("a fresh own group HP reading cannot be hidden by older personal channels", function()
  setupLeader()
  kozojeb.start()
  room=1323
  gmcp.Chimera.Group.State.members = {{id="S",name="Yergo",self=1,hp=30,maxhp=100},"L","M"}
  event("gmcp.Chimera.Group.State")
  assert(kozojeb.lastHp==30 and kozojeb.mode=="escape")
end)


test("leader rescue prioritizes raw reserve and attackers over the lowest percentage", function()
  setupLeader()
  kozojeb.command("progzaslony 80")
  local e=gmcp.Chimera.Room.Entities.entities
  e[1].hp,e[1].maxhp=2000,2000
  e[2].hp,e[2].maxhp=700,1000
  e[3].hp,e[3].maxhp=375,500
  e[5]={id="T",name="Drugi snotling",kind="npc",hp=100,maxhp=100}
  e[6]={id="U",name="Trzeci snotling",kind="npc",hp=100,maxhp=100}
  gmcp.Chimera.Combat.State.relations={
    {attacker="N",defender="L"},{attacker="T",defender="M"},{attacker="U",defender="M"}}
  kozojeb.start()
  assert(count("zaslon morrida")==1 and count("zaslon yarrima")==0)
end)

test("a failed shield against a dead opponent does not force another retreat", function()
  setupLeader()
  gmcp.Chimera.Room.Entities.entities[3].hp=63
  gmcp.Chimera.Combat.State.relations={{attacker="N",defender="M"}}
  kozojeb.start()
  room=1323
  shieldReply("Probujesz zaslonic Morrida przed ciosami malego snotlinga, lecz nie jestes w stanie tego uczynic.")
  gmcp.Chimera.Room.Entities.entities[4].hp=0
  gmcp.Chimera.Combat.State={primary="",relations={}}
  event("gmcp.Chimera.Combat.State")
  assert(kozojeb.mode~="escape" and #aliases==0)
end)

test("idle restart waits for fresh entities and resumes without manual start", function()
  setupLeader(); kozojeb.start(); room=1323; event()
  kozojeb.onIdleTimeout()
  room=1322; kozojeb.onRoomChanged("gmcp.Room.Info"); advance(.13)
  assert(kozojeb.enabled and kozojeb.restartPending=="idle")
  assert(not kozojeb.isUpdateSafe())
  event("gmcp.Chimera.Room.Entities")
  assert(kozojeb.enabled and not kozojeb.restartPending and kozojeb.mode~="stop")
  assert(kozojeb.config.startRoom==1322)
end)

test("incomplete restart HP waits without polling and manual stop cancels it", function()
  setupLeader(); kozojeb.start(); room=1323; event(); kozojeb.onIdleTimeout()
  room=1322; kozojeb.onRoomChanged("gmcp.Room.Info"); advance(.13)
  gmcp.Chimera.Room.Entities.entities[1].maxhp=nil
  gmcp.Char.Vitals.maxhp=nil
  event()
  assert(kozojeb.enabled and kozojeb.restartPending)
  local before=serial
  advance(2)
  assert(serial==before)
  kozojeb.stop()
  gmcp.Chimera.Room.Entities.entities[1].maxhp=100
  event()
  assert(not kozojeb.enabled and not kozojeb.restartPending)
end)

test("a disconnect during a pending idle restart preserves automatic continuation", function()
  setupLeader(); kozojeb.start(); room=1323; event(); kozojeb.onIdleTimeout()
  room=1322; kozojeb.onRoomChanged("gmcp.Room.Info"); advance(.13)
  kozojeb.onSessionEvent("sysDisconnectionEvent")
  assert(kozojeb.reconnectTask and not kozojeb.restartPending)
  reconnectPackets(); advance(.6)
  assert(kozojeb.enabled and not kozojeb.reconnectTask and kozojeb.mode~="stop")
end)

test("recovery return also waits for entities before restarting", function()
  setupLeader(); kozojeb.start()
  kozojeb.mode="recovery_return"
  kozojeb.onRoomChanged("gmcp.Room.Info")
  assert(kozojeb.restartPending=="recovery" and kozojeb.enabled)
  event()
  assert(kozojeb.enabled and not kozojeb.restartPending and kozojeb.mode~="recovery_return")
end)

test("fresh Char Vitals progress prevents a false idle return", function()
  setupLeader(); kozojeb.start(); room=1323; event()
  for i=1,8 do advance(3); gmcp.Char.Vitals.hp=100-i; event("gmcp.Char.Vitals") end
  assert(kozojeb.enabled and kozojeb.mode=="combat" and kozojeb.lastHp==92)
  assert(kozojeb.metrics.idleResets==0 and #aliases==0)
end)

test("raw HP progress smaller than a rounded percent still refreshes activity", function()
  setupLeader(); kozojeb.start(); room=1323; event()
  gmcp.Char.Vitals.hp,gmcp.Char.Vitals.maxhp=10000,10000
  for i=1,8 do advance(3); gmcp.Char.Vitals.hp=10000-i; event("gmcp.Char.Vitals") end
  assert(kozojeb.lastHp==100 and kozojeb.metrics.idleResets==0 and #aliases==0)
end)

test("fresh group HP progress prevents a false idle return", function()
  setupLeader(); kozojeb.start(); room=1323; event()
  gmcp.Chimera.Group.State.members={"S","L",{id="M",name="Morrid",hp=100,maxhp=100}}
  for i=1,8 do advance(3);gmcp.Chimera.Group.State.members[3].hp=100-i;event("gmcp.Chimera.Group.State") end
  assert(kozojeb.mode=="combat" and kozojeb.metrics.idleResets==0 and #aliases==0)
end)

test("real combat text refreshes one watchdog without recreating its timer", function()
  setupLeader(); kozojeb.start(); room=1323; event()
  local watchdog=kozojeb.idleTimer
  for i=1,6 do advance(3);kozojeb.onCombatProgress();assert(kozojeb.idleTimer==watchdog) end
  for i=1,3 do advance(3);kozojeb.onCombatProgress() end
  assert(kozojeb.mode=="combat" and kozojeb.metrics.idleResets==0)
  reset("wsparcie");kozojeb.start();kozojeb.onCombatProgress();noMovement()
end)

test("identical combat packets without progress cannot suppress the watchdog forever", function()
  setupLeader();kozojeb.start();room=1323;event()
  for i=1,8 do advance(3);event("gmcp.Chimera.Combat.State") end
  assert(kozojeb.mode=="idle_return" and kozojeb.metrics.idleResets==1)
end)

test("combat and personal packets reuse the unchanged room entity index", function()
  setupLeader();kozojeb.start()
  local before=kozojeb.metrics.index
  for i=1,20 do event("gmcp.Chimera.Combat.State");event("gmcp.Char.Vitals") end
  assert(kozojeb.metrics.index==before)
  gmcp.Chimera.Room.Entities.entities[5]={id="T",name="Drugi snotling",kind="npc",hp=100,maxhp=100}
  event("gmcp.Chimera.Room.Entities")
  assert(kozojeb.metrics.index==before+1)
end)

test("a group update invalidates leader context without rebuilding the room index", function()
  reset("wsparcie");kozojeb.start()
  local before=kozojeb.metrics.index
  gmcp.Chimera.Group.State.leader="M"
  event("gmcp.Chimera.Group.State")
  assert(kozojeb.leaderName=="Morrid" and kozojeb.metrics.index==before)
end)

test("confirmed hint promotion to an NPC retains support confirmation", function()
  reset("wsparcie",60);gmcp.Chimera.Combat.State={primary="",relations={}}
  kozojeb.start();kozojeb.onTeamCombat("Yarrim","malego snotlinga");advance(.13)
  kozojeb.onSupportResult(true);advance(2.1)
  gmcp.Chimera.Combat.State.relations={{attacker="L",defender="N"},{attacker="N",defender="L"}}
  event("gmcp.Chimera.Combat.State")
  assert(count("wesprzyj")==1 and kozojeb.supportAttempt.targetId=="N");noMovement()
end)

test("identical reordered or duplicated relations cannot retry denied support", function()
  reset("wsparcie",60);kozojeb.start();kozojeb.onSupportResult(false)
  for i=1,3 do advance(2.1);event("gmcp.Chimera.Combat.State") end
  gmcp.Chimera.Combat.State.relations={{attacker="N",defender="L"},{attacker="L",defender="N"},{attacker="L",defender="N"}}
  event("gmcp.Chimera.Combat.State")
  assert(count("wesprzyj")==1);noMovement()
end)

test("real new combat text can retry a rejected support after its interval", function()
  reset("wsparcie",60);kozojeb.start();kozojeb.onSupportResult(false);advance(2.1)
  kozojeb.onTeamCombat("Yarrim","malego snotlinga");advance(.13)
  assert(count("wesprzyj")==2);noMovement()
end)

test("a confirmed NPC death blocks support from stale combat and room data", function()
  reset("wsparcie",60);gmcp.Chimera.Combat.State.primary="N";kozojeb.start();advance(2.1)
  gmcp.Chimera.Combat.State.primary="";kozojeb.onGmcp("gmcp.Chimera.Combat.State")
  kozojeb.onKill("Maly glupkowaty snotling",false);advance(.13)
  for i=1,4 do event();event("gmcp.Chimera.Combat.State") end
  assert(count("wesprzyj")==0 and kozojeb.deadNpcIds.N);noMovement()
end)

test("NPC disappearance then respawn releases only its old death marker", function()
  reset("wsparcie",60);gmcp.Chimera.Combat.State.primary="N";kozojeb.start()
  kozojeb.onKill("Maly glupkowaty snotling",false)
  local npc=table.remove(gmcp.Chimera.Room.Entities.entities,4);event()
  assert(not kozojeb.deadNpcIds.N)
  gmcp.Chimera.Room.Entities.entities[4]=npc
  gmcp.Chimera.Combat.State.primary="";event()
  assert(count("wesprzyj")==1);noMovement()
end)

test("a death with duplicate NPC descriptions cannot blacklist both living IDs", function()
  reset("wsparcie",60)
  gmcp.Chimera.Room.Entities.entities[5]={id="T",name="Maly glupkowaty snotling",kind="npc",hp=100,maxhp=100}
  kozojeb.start();kozojeb.onKill("Maly glupkowaty snotling",false)
  assert(not kozojeb.deadNpcIds.N and not kozojeb.deadNpcIds.T)
end)

test("an outgoing attack confirms the target despite a different primary aggressor", function()
  setupLeader();gmcp.Chimera.Combat.State={primary="",relations={}}
  gmcp.Chimera.Room.Entities.entities[5]={id="T",name="Drugi snotling",kind="npc",hp=100,maxhp=100}
  kozojeb.start()
  gmcp.Chimera.Combat.State={primary="T",relations={{attacker="S",defender="N"},{attacker="N",defender="L"},{attacker="T",defender="S"}}}
  event("gmcp.Chimera.Combat.State");advance(5.5)
  assert(count("zabij snotlinga")==1 and kozojeb.currentTargetId=="N")
end)

test("unconfirmed attacks stop after three attempts until combat evidence changes", function()
  setupLeader();gmcp.Chimera.Combat.State={primary="",relations={}}
  kozojeb.start();advance(8)
  assert(count("zabij snotlinga")==3 and not kozojeb.focusTimer)
  gmcp.Chimera.Room.Entities.entities[4].hp=90;event()
  assert(count("zabij snotlinga")==3)
  gmcp.Chimera.Combat.State.relations={{attacker="N",defender="M"}};event("gmcp.Chimera.Combat.State")
  assert(count("zabij snotlinga")==4)
end)

test("support prefers the leader outgoing target over an earlier incoming aggressor", function()
  reset("wsparcie",60)
  gmcp.Chimera.Room.Entities.entities[5]={id="T",name="Drugi snotling",kind="npc",hp=100,maxhp=100}
  gmcp.Chimera.Combat.State.relations={{attacker="T",defender="L"},{attacker="L",defender="N"}}
  kozojeb.start()
  assert(kozojeb.currentTargetId=="N")
end)

test("a recent large own HP loss reserves another such hit above the normal floor", function()
  setupLeader();gmcp.Chimera.Combat.State.relations={{attacker="S",defender="N"},{attacker="N",defender="S"}}
  kozojeb.start();room=1323;event()
  gmcp.Chimera.Room.Entities.entities[1].hp=70;event()
  assert(kozojeb.mode=="escape" and kozojeb.lastHp==70 and aliases[#aliases]=="/idz 1322")
end)

test("a smaller subsequent hit retains the recent worst observed loss", function()
  setupLeader();gmcp.Chimera.Combat.State.relations={{attacker="S",defender="N"},{attacker="N",defender="S"}}
  kozojeb.start();room=1323;event()
  gmcp.Chimera.Room.Entities.entities[1].hp=75;event()
  assert(kozojeb.mode~="escape")
  gmcp.Chimera.Room.Entities.entities[1].hp=74;event()
  assert(kozojeb.mode=="escape")
end)

test("large teammate losses make only the leader retreat when no shield is available", function()
  setupLeader();kozojeb.command("progzaslony 0")
  gmcp.Chimera.Combat.State.relations={{attacker="S",defender="N"},{attacker="N",defender="M"}}
  kozojeb.start();room=1323;event()
  gmcp.Chimera.Room.Entities.entities[3].hp=70;event()
  assert(kozojeb.mode=="escape" and aliases[#aliases]=="/idz 1322")
  reset("wsparcie");kozojeb.start();gmcp.Chimera.Room.Entities.entities[2].hp=60;event();noMovement()
end)

test("disabling the team retreat floor disables its burst reserve too", function()
  setupLeader();kozojeb.command("progdruzyny 0");kozojeb.command("progzaslony 0")
  gmcp.Chimera.Combat.State.relations={{attacker="S",defender="N"},{attacker="N",defender="M"}}
  kozojeb.start();room=1323;event()
  gmcp.Chimera.Room.Entities.entities[3].hp=70;event()
  assert(kozojeb.mode~="escape" and #aliases==0)
end)

test("an expired large loss does not force a later retreat against a fresh threat", function()
  setupLeader();gmcp.Chimera.Combat.State.relations={{attacker="S",defender="N"}}
  kozojeb.start();room=1323;event()
  gmcp.Chimera.Room.Entities.entities[1].hp=70;event();advance(8.1)
  gmcp.Chimera.Combat.State.relations={{attacker="S",defender="N"},{attacker="N",defender="S"}}
  event("gmcp.Chimera.Combat.State")
  assert(kozojeb.mode~="escape" and #aliases==0)
end)

test("a safe available shield precedes the additional team burst retreat", function()
  setupLeader();kozojeb.command("progzaslony 80")
  gmcp.Chimera.Room.Entities.entities[1].hp=200;gmcp.Chimera.Room.Entities.entities[1].maxhp=200
  gmcp.Chimera.Combat.State.relations={{attacker="S",defender="N"},{attacker="N",defender="M"}}
  kozojeb.start();room=1323;event()
  gmcp.Chimera.Room.Entities.entities[3].hp=70;event()
  assert(kozojeb.mode~="escape" and count("zaslon morrida")==1)
  event();assert(kozojeb.mode~="escape")
end)

test("a complete fresh personal HP pair can finish an otherwise partial room restart", function()
  setupLeader();kozojeb.start();room=1323;event();kozojeb.onIdleTimeout()
  room=1322;kozojeb.onRoomChanged("gmcp.Room.Info");advance(.13)
  gmcp.Chimera.Room.Entities.entities[1].maxhp=nil
  event("gmcp.Char.Vitals");event("gmcp.Chimera.Room.Entities")
  assert(kozojeb.enabled and not kozojeb.restartPending and kozojeb.mode~="stop")
end)

test("a synchronous stop during attack cannot leave a retry timer behind", function()
  setupLeader();gmcp.Chimera.Combat.State={primary="",relations={}}
  local original=send
  send=function(command)
    original(command)
    if command=="zabij snotlinga" then kozojeb.stop() end
  end
  kozojeb.start();send=original
  advance(8)
  assert(count("zabij snotlinga")==1 and not kozojeb.focusTimer and not kozojeb.enabled)
end)

test("a new living HP snapshot after a zero HP snapshot releases a recycled NPC ID", function()
  reset("wsparcie",60);gmcp.Chimera.Combat.State.primary="N";kozojeb.start()
  kozojeb.onKill("Maly glupkowaty snotling",false)
  gmcp.Chimera.Room.Entities.entities[4].hp=0;event()
  assert(kozojeb.deadNpcIds.N)
  gmcp.Chimera.Room.Entities.entities[4].hp=100
  gmcp.Chimera.Combat.State.primary="";event()
  assert(not kozojeb.deadNpcIds.N and count("wesprzyj")==1)
end)

local function movementLeader()
  reset(nil)
  gmcp.Chimera.Group.State.leader = "S"
  gmcp.Chimera.Room.Entities.entities[1].group_role = "leader"
  gmcp.Chimera.Room.Entities.entities[2].group_role = "member"
  table.remove(gmcp.Chimera.Room.Entities.entities, 4)
  gmcp.Chimera.Combat.State = {primary="", relations={}}
  kozojeb.setRooms({1322,1323})
  kozojeb.command("pustypatrol 0")
  kozojeb.start()
end

test("native Chimera fatigue overrides stale full moves and triggers the leader retreat", function()
  movementLeader()
  room = 1323
  kozojeb.onRoomChanged("gmcp.Room.Info")
  gmcp.Char.Vitals.fatigue = 80
  event("gmcp.Char.Vitals")
  assert(kozojeb.lastMoves == 20 and kozojeb.mode == "escape")
  assert(aliases[1] == "/idz 1322")
end)

test("fatigue recovery retains the existing movement thresholds and full HP requirement", function()
  movementLeader()
  room = 1323
  kozojeb.onRoomChanged("gmcp.Room.Info")
  gmcp.Char.Vitals = {hp=100,maxhp=100,fatigue=80}
  event("gmcp.Char.Vitals")
  room = 1322;kozojeb.onRoomChanged("gmcp.Room.Info");event()
  gmcp.Char.Vitals.fatigue = 46
  event("gmcp.Char.Vitals");advance(3.1)
  assert(kozojeb.mode == "heal_rest")
  gmcp.Char.Vitals.fatigue = 45
  event("gmcp.Char.Vitals");advance(3.1)
  assert(kozojeb.enabled and kozojeb.mode == "patrol")
end)

test("fresh low teammate fatigue from Group State works even without a teammate HP field", function()
  movementLeader()
  room = 1323;kozojeb.onRoomChanged("gmcp.Room.Info");event()
  gmcp.Chimera.Group.State.members = {"S","L",{id="M",name="Morrid",fatigue=90}}
  event("gmcp.Chimera.Group.State")
  assert(kozojeb.mode == "escape" and kozojeb.teamMoves.morrid == 10)
  assert(kozojeb.recoveryTired.morrid == "Morrid" and aliases[1] == "/idz 1322")
end)

test("team movement recovery cannot use a missing or incomplete tired member reading", function()
  movementLeader()
  room = 1323;kozojeb.onRoomChanged("gmcp.Room.Info");event()
  local member = gmcp.Chimera.Room.Entities.entities[3]
  member.fatigue = 85;event()
  assert(kozojeb.mode == "escape" and kozojeb.recoveryTired.morrid == "Morrid")
  room = 1322;kozojeb.onRoomChanged("gmcp.Room.Info");event();advance(3.1)
  assert(kozojeb.mode == "heal_rest")
  member.fatigue = nil;event();advance(3.1)
  assert(kozojeb.mode == "heal_rest")
  member.fatigue = 46;event();advance(3.1)
  assert(kozojeb.mode == "heal_rest")
  member.fatigue = 45;event();advance(3.1)
  assert(kozojeb.mode == "patrol" and not next(kozojeb.recoveryTired))
end)

test("unrelated NPC fatigue cannot force a team rest", function()
  movementLeader()
  gmcp.Chimera.Room.Entities.entities[4] = {id="X",name="Obcy wilk",kind="npc",fatigue=100}
  kozojeb.command("cele snotling")
  event()
  assert(kozojeb.mode == "patrol" and not next(kozojeb.recoveryTired) and #aliases == 0)
end)

test("both supporting roles ignore personal fatigue and the new movement refusal trigger", function()
  for _, role in ipairs({"wsparcie","zaslony"}) do
    reset(role)
    gmcp.Char.Vitals.fatigue = 100
    kozojeb.start()
    local fired = 0
    for _, trigger in ipairs(triggers) do
      if trigger.handler:find("kozojeb.onMovementExhausted()",1,true) then
        assert(compile(trigger.handler))();fired = fired + 1
      end
    end
    assert(fired == 1 and kozojeb.enabled and not kozojeb.movementRest)
    advance(35)
    noMovement()
  end
end)

test("a refused own step releases room acknowledgement without blacklisting a valid exit", function()
  movementLeader();advance(.71)
  assert(count("e") == 1 and kozojeb.roomChangePending)
  kozojeb.onMovementExhausted()
  assert(not kozojeb.roomChangePending and kozojeb.entitiesReady and kozojeb.movementRest)
  assert(not kozojeb.failedExits[1322] and not kozojeb.moveSnapshot)
  advance(31)
  assert(count("e") == 1 and count("stan") == 3 and #aliases == 0)
  assert(kozojeb.metrics.idleResets == 0 and kozojeb.enabled)
end)

test("cached full movement and unrelated HP packets cannot end a refusal rest", function()
  movementLeader();advance(.71);kozojeb.onMovementExhausted()
  advance(11)
  for i=1,20 do event() end
  assert(kozojeb.movementRest and count("e") == 1)
  gmcp.Char.Vitals = {hp=100,maxhp=100};event("gmcp.Char.Vitals")
  assert(kozojeb.movementRest)
  gmcp.Char.Vitals.fatigue = 45;event("gmcp.Char.Vitals");advance(1)
  assert(not kozojeb.movementRest and count("e") == 2)
end)

test("GMCP bursts during a refusal reuse one rest timer and never send movement probes", function()
  movementLeader();advance(.71);kozojeb.onMovementExhausted()
  local timer = kozojeb.movementRestTimer
  for i=1,2000 do kozojeb.onGmcp("gmcp.Chimera.Room.Entities") end
  assert(kozojeb.movementRestTimer == timer and count("e") == 1 and count("stan") == 0)
end)

test("delayed room data cannot be restored from a refusal after Room Info", function()
  movementLeader();advance(.71)
  kozojeb.onRoomChanged("gmcp.Room.Info")
  assert(not kozojeb.entitiesReady)
  kozojeb.onMovementExhausted()
  assert(not kozojeb.entitiesReady and kozojeb.movementRest)
  advance(11)
  assert(count("e") == 1)
end)

test("a teammate arriving within the one second grace prevents a needless return", function()
  movementLeader();advance(.71)
  local member = table.remove(gmcp.Chimera.Room.Entities.entities,3)
  room=1323;kozojeb.onRoomChanged("gmcp.Room.Info");event()
  assert(kozojeb.teamStep and kozojeb.teamStepTimer and count("w") == 0)
  advance(.3)
  gmcp.Chimera.Room.Entities.entities[3]=member;event()
  assert(not kozojeb.teamStep and not kozojeb.movementRest and not kozojeb.teamStepTimer)
  assert(count("w") == 0 and kozojeb.metrics.regroups == 0)
end)

test("the leader returns one mapped room for a lagging teammate and rests before retrying", function()
  movementLeader();advance(.71)
  local member = table.remove(gmcp.Chimera.Room.Entities.entities,3)
  room=1323;kozojeb.onRoomChanged("gmcp.Room.Info");event();advance(1)
  assert(kozojeb.movementRest and count("w") == 1 and count("e") == 1)
  assert(#aliases == 0 and kozojeb.metrics.regroups == 1)
  room=1322;kozojeb.onRoomChanged("gmcp.Room.Info")
  gmcp.Chimera.Room.Entities.entities[3]=member;event()
  advance(5)
  assert(kozojeb.movementRest and count("e") == 1)
  advance(6)
  assert(not kozojeb.movementRest and count("e") == 2 and kozojeb.metrics.idleResets == 0)
end)

test("missing teammates block new attacks during the arrival grace", function()
  movementLeader();advance(.71)
  table.remove(gmcp.Chimera.Room.Entities.entities,3)
  gmcp.Chimera.Room.Entities.entities[3]={id="N",name="Maly glupkowaty snotling",kind="npc",hp=100,maxhp=100}
  room=1323;kozojeb.onRoomChanged("gmcp.Room.Info");event()
  assert(kozojeb.teamStep and count("zabij snotlinga") == 0)
end)

test("a dissolved team cannot cause permanent regroup waiting", function()
  movementLeader();advance(.71)
  gmcp.Chimera.Room.Entities.entities={gmcp.Chimera.Room.Entities.entities[1]}
  gmcp.Chimera.Group.State={members={}}
  room=1323;kozojeb.onRoomChanged("gmcp.Room.Info");event();advance(.2)
  assert(not kozojeb.teamStep and not kozojeb.movementRest and kozojeb.metrics.regroups == 0)
end)

test("unknown return exits do not invent a direction or repeatedly move the leader", function()
  movementLeader();advance(.71)
  local originalExits = getRoomExits
  getRoomExits = function(id) if id == 9999 then return {} end return originalExits(id) end
  table.remove(gmcp.Chimera.Room.Entities.entities,3)
  room=9999;kozojeb.onRoomChanged("gmcp.Room.Info");event();advance(1)
  assert(kozojeb.movementRest and #sends == 1 and #aliases == 0)
  advance(40)
  assert(#sends == 1 and kozojeb.enabled and kozojeb.metrics.idleResets == 0)
  getRoomExits = originalExits
end)

test("critical HP overrides the team arrival wait and preserves the absent recovery roster", function()
  movementLeader();advance(.71)
  table.remove(gmcp.Chimera.Room.Entities.entities,3)
  room=1323;kozojeb.onRoomChanged("gmcp.Room.Info")
  gmcp.Chimera.Room.Entities.entities[1].hp=20;gmcp.Char.Vitals.hp=20;event()
  assert(kozojeb.mode == "escape" and aliases[1] == "/idz 1322")
  assert(kozojeb.recoveryRoster.morrid == "Morrid" and not kozojeb.teamStep)
end)

test("a known tired walker does not exhaust three retreat attempts while resting", function()
  movementLeader()
  room=1323;kozojeb.onRoomChanged("gmcp.Room.Info")
  gmcp.Char.Vitals.fatigue=80;event("gmcp.Char.Vitals")
  advance(60)
  assert(kozojeb.enabled and kozojeb.mode == "escape" and #aliases == 1)
  assert(kozojeb.escapeAttempts == 1)
end)

test("manual stop, role change and death cancel movement rest permanently", function()
  for _, action in ipairs({"stop","rola wsparcie","death"}) do
    movementLeader();advance(.71);kozojeb.onMovementExhausted()
    if action == "death" then kozojeb.onDeath() else kozojeb.command(action) end
    sends,aliases={},{}
    gmcp.Char.Vitals.fatigue=0;event("gmcp.Char.Vitals");advance(60)
    assert(not kozojeb.enabled and not kozojeb.movementRest and not kozojeb.movementRestTimer)
    assert(#sends == 0 and #aliases == 0)
  end
end)

test("disconnect and fresh recovery retain an active refusal rest without manual start", function()
  movementLeader();advance(.71);kozojeb.onMovementExhausted()
  kozojeb.onSessionEvent("sysDisconnectionEvent")
  sends,aliases={},{}
  kozojeb.onSessionEvent("sysConnectionEvent")
  gmcp.Char.Vitals.fatigue=45
  reconnectPackets()
  assert(kozojeb.enabled and kozojeb.movementRest and not kozojeb.reconnectTask)
  advance(11)
  assert(kozojeb.enabled and not kozojeb.movementRest and count("e") == 1)
end)

test("repeated failed group steps back off for ten twenty and thirty seconds", function()
  movementLeader();advance(.71)
  for attempt=1,3 do
    local member=table.remove(gmcp.Chimera.Room.Entities.entities,3)
    room=1323;kozojeb.onRoomChanged("gmcp.Room.Info");event();advance(1)
    assert(kozojeb.movementRest and count("w") == attempt)
    room=1322;kozojeb.onRoomChanged("gmcp.Room.Info")
    gmcp.Chimera.Room.Entities.entities[3]=member;event()
    advance(attempt * 10 - 1)
    assert(kozojeb.movementRest and count("e") == attempt)
    advance(2)
    assert(not kozojeb.movementRest and count("e") == attempt + 1)
  end
end)

test("critical HP interrupts regroup rest without waiting for missing teammates", function()
  movementLeader();advance(.71)
  table.remove(gmcp.Chimera.Room.Entities.entities,3)
  room=1323;kozojeb.onRoomChanged("gmcp.Room.Info");event();advance(1)
  assert(kozojeb.movementRest)
  room=1322;kozojeb.onRoomChanged("gmcp.Room.Info");event()
  -- The leader reaches a different room before the late follower does.
  room=1323;kozojeb.onRoomChanged("gmcp.Room.Info")
  gmcp.Chimera.Room.Entities.entities[1].hp=20;gmcp.Char.Vitals.hp=20;event()
  assert(kozojeb.mode == "escape" and not kozojeb.movementRest and aliases[1] == "/idz 1322")
  assert(kozojeb.recoveryRoster.morrid == "Morrid")
end)

test("emergency escape after a refusal uses fresh usable movement without waiting for full rest", function()
  movementLeader()
  room=1323;kozojeb.onRoomChanged("gmcp.Room.Info");event();advance(.71)
  kozojeb.onMovementExhausted()
  gmcp.Char.Vitals.hp=20;gmcp.Chimera.Room.Entities.entities[1].hp=20;event()
  assert(kozojeb.mode == "escape" and kozojeb.movementRest and #aliases == 0)
  gmcp.Char.Vitals.fatigue=60;event("gmcp.Char.Vitals")
  assert(kozojeb.mode == "escape" and not kozojeb.movementRest and aliases[1] == "/idz 1322")
end)

test("invalid fatigue and incomplete movement pairs cannot confirm recovery after refusal", function()
  movementLeader();advance(.71);kozojeb.onMovementExhausted();advance(11)
  for _, fatigue in ipairs({-1,101,math.huge,0/0,"unknown"}) do
    gmcp.Char.Vitals={hp=100,maxhp=100,fatigue=fatigue,moves=100}
    event("gmcp.Char.Vitals")
    assert(kozojeb.movementRest and count("e") == 1)
  end
end)

test("a refusal rest reconnect continues the saved watchdog return instead of patrolling", function()
  movementLeader()
  room=1323;kozojeb.onRoomChanged("gmcp.Room.Info");event()
  kozojeb.onIdleTimeout();advance(.3);kozojeb.onMovementExhausted()
  assert(kozojeb.mode == "idle_return" and kozojeb.movementRest)
  kozojeb.onSessionEvent("sysDisconnectionEvent");sends,aliases={},{}
  kozojeb.onSessionEvent("sysConnectionEvent")
  gmcp.Char.Vitals.fatigue=0;reconnectPackets();advance(11)
  assert(kozojeb.enabled and kozojeb.mode == "idle_return" and count("w") == 1)
  assert(count("e") == 0 and #aliases == 0)
end)

test("a disconnect during the regroup return cannot leave the leader waiting ahead forever", function()
  movementLeader();advance(.71)
  table.remove(gmcp.Chimera.Room.Entities.entities,3)
  room=1323;kozojeb.onRoomChanged("gmcp.Room.Info");event();advance(1)
  assert(count("w") == 1 and kozojeb.movementRest)
  kozojeb.onSessionEvent("sysDisconnectionEvent");sends,aliases={},{}
  kozojeb.onSessionEvent("sysConnectionEvent");reconnectPackets()
  assert(kozojeb.enabled and not kozojeb.reconnectTask and kozojeb.movementRest)
  advance(11)
  assert(count("w") == 1 and kozojeb.movementRest and #aliases == 0)
end)

print(string.format("%d simulations passed", total))
