-- Kozojeb dla Mudleta / Chimery
--
-- Najwazniejsze komendy:
--   /kozojeb obszar                  - pobierz pokoje zaznaczone na mapie
--   /kozojeb start                   - rozpocznij patrol
--   /kozojeb stop                    - zatrzymaj natychmiast
--   /kozojeb help                    - pokaz pelna pomoc
--   /kozojeb status                  - pokaz ustawienia i stan
--   /kozojeb rola prowadzacy         - patrol i ochrona calej druzyny
--   /kozojeb rola wsparcie           - druga linia: wsparcie i DPS
--   /kozojeb rola zaslony            - wsparcie i ochrona calej druzyny
--   /kozojeb lider auto              - wykrywaj prowadzacego przez GMCP
--   /kozojeb proglidera 70           - prog HP zaslony prowadzacego
--   /kozojeb minhpzaslony 50         - niezalezne minimalne HP zaslaniajacego
--   /kozojeb predkosc 0.7            - opoznienie ruchu podczas patrolu
--   /kozojeb bezczynnosc 20 1322     - reset po zastoju do podanego pokoju
--   /kozojeb cele snotling ork waz    - wybierz dowolne gatunki NPC do ataku
--   /kozojeb maxstworow 3             - pomijaj nowe pokoje patrolu z ponad 3 celami
--   /kozojeb ignoruj wszystko         - ignoruj wszystkie NPC poza wybranymi celami
--   /kozojeb ignoruj dodaj szaman     - zawsze ignoruj NPC z podana nazwa
--   /kozojeb baza                    - ustaw baze/start w obecnym pokoju
--   /kozojeb pauza 5                 - ustaw oczekiwanie po zabiciu
--   /kozojeb prog 50                 - odwrot przy podanym procencie HP
--   /kozojeb progdruzyny 50          - odwrot, gdy ktos z druzyny ma <= 50% HP
--   /kozojeb progzaslony 70          - zaslaniaj rannego czlonka druzyny
--   /kozojeb imie Pandjed pandjeda   - dodaj odmiane imienia do zaslony
--   /kozojeb druzyna auto            - wykrywaj druzyne z relacji GMCP
--   /kozojeb odpoczynek 25 55        - pauza/wznowienie wedlug procentu ruchu
--   /kozojeb powrothp 95             - HP calej druzyny przed powrotem z leczenia
--
-- Skrypt zaklada, ze istniejacy alias /idz prowadzi do pokoju mapy o podanym ID.

kozojeb = kozojeb or {}
local K = kozojeb
-- Import z oryginalnego KozoBota nie zmienia jego autorstwa ani przestrzeni nazw.
if not K.legacyImportTried and type(kozobot) == "table" then
  if kozobot.updater and type(kozobot.updater.cleanup) == "function" then pcall(kozobot.updater.cleanup) end
  kozobot.updater = nil
  if type(kozobot.stop) == "function" then pcall(kozobot.stop, "Przejscie na Kozojeb.") end
  for collection, killer in pairs({triggers=killTrigger, aliases=killAlias, events=killAnonymousEventHandler}) do
    for _, id in ipairs(kozobot.handlers and kozobot.handlers[collection] or {}) do pcall(killer, id) end
  end
  if kozobot.formationTimer then pcall(killTimer, kozobot.formationTimer) end
  kozobot.enabled = false
  local function copy(value)
    if type(value) ~= "table" then return value end
    local result = {}
    for key, item in pairs(value) do result[key] = copy(item) end
    return result
  end
  K.config = K.config or copy(kozobot.config)
  K.rooms = K.rooms or copy(kozobot.rooms)
end
K.legacyImportTried = true
K.initialized = false

K.version = "2.9.10"
K.config = K.config or {
  chaseDelay = 0.20,
  patrolDelay = 0.70,
  panicWait = 2.0,
  idleTimeout = 20.0,
  startRoom = 1322,
  actionDelay = 0.12,
  killPause = 5.0,
  herbSearchEnabled = false,
  herbSearchCommand = "szukaj ziol",
  herbSearchTimeout = 20.0,
  limitExitDelay = 0.20,
  targetLostDelay = 1.0,
  escapeRetryDelay = 12.0,
  escapeMaxAttempts = 3,
  escapeHp = 50,
  teamEscapeHp = 50,
  recoveryHp = 95,
  teamShieldHp = 70,
  teamShieldInterval = 2.0,
  shieldMaxAttackers = 2,
  shieldHold = 8,
  emptyPatrolMax = 3,
  maxCreatures = 0,
  restAtMoves = 25,
  resumeAtMoves = 55,
  attackCommand = "zabij",
  animals = {
    koza = true, kon = true, krowa = true, jelen = true, koziol = true,
    byk = true, zubr = true, szkielet = true, sarna = true, zajac = true,
    daniel = true, borsuk = true, wilk = true, kuna = true, troglodyta = true,
    reptilion = true, zombi = true, ogr = true, niedzwiedz = true, gnoll = true,
    ozywieniec = true, fimir = true, troll = true, linkantrop = true,
    zwierzoczlek = true, zolnierz = true, rycerz = true, bazant = true,
    ["krasnolud chaosu"] = true,
  },
  targets = {
    koza = true, kon = true, krowa = true, jelen = true, koziol = true,
    byk = true, zubr = true, szkielet = true, sarna = true, zajac = true,
    daniel = true, borsuk = true, wilk = true, kuna = true, troglodyta = true,
    reptilion = true, zombi = true, ogr = true, niedzwiedz = true, gnoll = true,
    ozywieniec = true, fimir = true, troll = true, linkantrop = true,
    zwierzoczlek = true, zolnierz = true, rycerz = true, bazant = true,
    ["krasnolud chaosu"] = true,
  },
  targetOrder = {
    "koza", "kon", "krowa", "jelen", "koziol", "byk", "zubr", "szkielet",
    "sarna", "zajac", "daniel", "borsuk", "wilk", "kuna", "troglodyta",
    "reptilion", "zombi", "ogr", "niedzwiedz", "gnoll", "ozywieniec",
    "fimir", "troll", "linkantrop", "zwierzoczlek", "zolnierz", "rycerz", "bazant",
    "krasnolud chaosu",
  },
  attackForms = {},
  zubrTargetInitialized = true,
  szkieletTargetInitialized = true,
  introducedTargets230 = {
    sarna = true, zajac = true, daniel = true, borsuk = true, wilk = true,
    kuna = true, troglodyta = true, reptilion = true, zombi = true,
    ogr = true, niedzwiedz = true, gnoll = true, ozywieniec = true, fimir = true,
    troll = true, linkantrop = true, zwierzoczlek = true,
    zolnierz = true, rycerz = true, bazant = true,
    ["krasnolud chaosu"] = true,
  },
  teamMembers = {},
  shieldNameForms = {},
  ignoreNonTargets = true,
  ignoredNames = {},
}

-- Konfiguracja i obszar pozostaja poza katalogiem instalowanej paczki.
-- Starszy plik ustawien rol jest nadal czytany przy pierwszej migracji.
local function settingsPath()
  if type(getMudletHomeDir) ~= "function" then return nil end
  local ok, profile = pcall(getMudletHomeDir)
  if ok and type(profile) == "string" and profile ~= "" then
    return profile .. "/chimera_kozojeb_settings.lua"
  end
end
local settingTypes = {
  chaseDelay="number", patrolDelay="number", panicWait="number", idleTimeout="number",
  startRoom="number", actionDelay="number", killPause="number", herbSearchEnabled="boolean",
  herbSearchCommand="string", herbSearchTimeout="number", limitExitDelay="number",
  targetLostDelay="number", escapeRetryDelay="number", escapeMaxAttempts="number",
  escapeHp="number", teamEscapeHp="number", teamShieldHp="number", teamShieldInterval="number",
  maxCreatures="number", restAtMoves="number", resumeAtMoves="number", attackCommand="string",
  targets="table", targetOrder="table", attackForms="table", teamMembers="table",
  shieldNameForms="table", ignoreNonTargets="boolean", ignoredNames="table",
  role="string", leaderName="string", leaderShieldHp="number", shieldSelfHp="number",
  zubrTargetInitialized="boolean", szkieletTargetInitialized="boolean", introducedTargets230="table",
  equipmentHold="string", recoveryHp="number",
  shieldMaxAttackers="number", shieldHold="number", emptyPatrolMax="number",
}
if not K.settingsLoaded then
  local saved, path = {}, settingsPath()
  if path and type(table.load) == "function" then pcall(table.load, path, saved) end
  if saved.schemaVersion ~= 1 and path and type(table.load) == "function" then
    pcall(table.load, path:gsub("kozojeb", "kozobot"), saved)
  end
  if saved.schemaVersion == 1 and type(saved.config) == "table" then
    for key, expectedType in pairs(settingTypes) do
      if type(saved.config[key]) == expectedType then K.config[key] = saved.config[key] end
    end
    if type(saved.rooms) == "table" then K.rooms = saved.rooms end
    K.roleSettingsLoaded = true
  end
  K.settingsLoaded = true
end

function K.saveSettings()
  local path = settingsPath()
  if not path or type(table.save) ~= "function" then return false end
  local config = {}
  for key, expectedType in pairs(settingTypes) do
    if type(K.config[key]) == expectedType then config[key] = K.config[key] end
  end
  local ok, result, err = pcall(table.save, path, {
    schemaVersion=1, config=config, rooms=K.rooms or {},
  })
  return ok and result ~= false and err == nil
end
-- Uzupelnienie ustawien przy przeladowaniu starszej wersji skryptu.
K.config.escapeTail = nil -- usuniete w 2.2.0
K.config.recoveryTail = nil -- usuniete w 2.2.1: powrot odbywa sie przez /idz
K.config.commandDelay = nil
K.config.chaseDelay = tonumber(K.config.chaseDelay) or 0.20
K.config.patrolDelay = tonumber(K.config.patrolDelay) or 0.70
K.config.panicWait = tonumber(K.config.panicWait) or 2.0
K.config.idleTimeout = tonumber(K.config.idleTimeout) or 20.0
K.config.actionDelay = tonumber(K.config.actionDelay) or 0.12
K.config.limitExitDelay = tonumber(K.config.limitExitDelay) or 0.20
K.config.targetLostDelay = tonumber(K.config.targetLostDelay) or 1.0
K.config.escapeRetryDelay = tonumber(K.config.escapeRetryDelay) or 12.0
K.config.escapeMaxAttempts = tonumber(K.config.escapeMaxAttempts) or 3
K.config.killPause = tonumber(K.config.killPause) or 5.0
if K.config.herbSearchEnabled == nil then K.config.herbSearchEnabled = false end
K.config.herbSearchCommand = tostring(K.config.herbSearchCommand or "szukaj ziol")
K.config.herbSearchTimeout = math.max(5.0, tonumber(K.config.herbSearchTimeout) or 20.0)
K.config.startRoom = tonumber(K.config.escapeRoom) or tonumber(K.config.startRoom) or 1322
K.config.escapeRoom = nil -- od 2.4.0 baza i pokoj startowy sa jednym miejscem
K.config.escapeHp = tonumber(K.config.escapeHp) or 50
K.config.teamEscapeHp = tonumber(K.config.teamEscapeHp) or K.config.escapeHp
K.config.recoveryHp = math.max(1, math.min(100, math.floor(tonumber(K.config.recoveryHp) or 95)))
K.config.teamShieldHp = tonumber(K.config.teamShieldHp) or 70
K.config.teamShieldInterval = tonumber(K.config.teamShieldInterval) or 2.0
K.config.teamShieldHp = math.max(0, math.min(100, K.config.teamShieldHp))
K.config.teamShieldInterval = math.max(0.5, K.config.teamShieldInterval)
K.config.shieldMaxAttackers = math.max(1, math.min(5, math.floor(tonumber(K.config.shieldMaxAttackers) or 2)))
K.config.shieldHold = math.max(2, math.min(30, tonumber(K.config.shieldHold) or 8))
K.config.emptyPatrolMax = math.max(0, math.min(10, tonumber(K.config.emptyPatrolMax) or 3))
do
  local escapeCeiling = math.max(K.config.escapeHp, K.config.teamEscapeHp)
  -- Prog zaslony zawsze musi byc wyzszy od obu progow odwrotu. Przy
  -- migracji starej konfiguracji poprawiamy go automatycznie; prog 0
  -- oznacza calkowicie wylaczona automatyczna zaslone.
  if K.config.teamShieldHp > 0 and K.config.teamShieldHp <= escapeCeiling then
    K.config.teamShieldHp = escapeCeiling < 100 and math.min(100, escapeCeiling + 10) or 0
  end
end
K.config.restAtMoves = tonumber(K.config.restAtMoves) or 25
K.config.resumeAtMoves = tonumber(K.config.resumeAtMoves) or 55
K.config.attackCommand = K.config.attackCommand or "zabij"
K.config.maxCreatures = tonumber(K.config.maxCreatures) or 0
K.config.targets = K.config.targets or K.config.animals or {
  koza = true, kon = true, krowa = true, jelen = true, koziol = true,
  byk = true, zubr = true, szkielet = true, sarna = true, zajac = true,
  daniel = true, borsuk = true, wilk = true, kuna = true, troglodyta = true,
  reptilion = true, zombi = true, ogr = true, niedzwiedz = true, gnoll = true,
  ozywieniec = true, fimir = true, troll = true, linkantrop = true,
  zwierzoczlek = true, zolnierz = true, rycerz = true, bazant = true,
  ["krasnolud chaosu"] = true,
}
K.config.targetOrder = K.config.targetOrder or {
  "koza", "kon", "krowa", "jelen", "koziol", "byk", "zubr", "szkielet",
  "sarna", "zajac", "daniel", "borsuk", "wilk", "kuna", "troglodyta",
  "reptilion", "zombi", "ogr", "niedzwiedz", "gnoll", "ozywieniec",
  "fimir", "troll", "linkantrop", "zwierzoczlek", "zolnierz", "rycerz", "bazant",
  "krasnolud chaosu",
}
K.config.attackForms = K.config.attackForms or {}
K.config.teamMembers = K.config.teamMembers or {}
local defaultShieldNameForms = {
  veesa = "veese",
  isill = "isilla",
  bug = "buga",
  rafgartael = "rafgartaela",
  morrid = "morrida",
  yarrim = "yarrima",
  gror = "grora",
  yergo = "yerga",
}
K.config.shieldNameForms = K.config.shieldNameForms or {}
for name, form in pairs(defaultShieldNameForms) do
  if K.config.shieldNameForms[name] == nil then K.config.shieldNameForms[name] = form end
end
-- Przy pierwszym zaladowaniu wersji z zubrem wlaczamy go jako cel. Znacznik
-- sprawia, ze pozniejsze reczne wylaczenie w panelu pozostanie zachowane.
if K.config.zubrTargetInitialized == nil then
  K.config.targets.zubr = true
  K.config.zubrTargetInitialized = true
end
if K.config.szkieletTargetInitialized == nil then
  K.config.targets.szkielet = true
  K.config.szkieletTargetInitialized = true
end
local targetsIntroduced230 = {
  "sarna", "zajac", "daniel", "borsuk", "wilk", "kuna", "troglodyta",
  "reptilion", "zombi", "ogr", "niedzwiedz", "gnoll", "ozywieniec",
  "fimir", "troll", "linkantrop", "zwierzoczlek", "zolnierz", "rycerz", "bazant",
  "krasnolud chaosu",
}
K.config.introducedTargets230 = K.config.introducedTargets230 or {}
for _, target in ipairs(targetsIntroduced230) do
  if not K.config.introducedTargets230[target] then
    K.config.targets[target] = true
    K.config.introducedTargets230[target] = true
  end
end
-- W 2.3.0 cel byl omylkowo nazwany "zombie", podczas gdy opisy Chimery
-- uzywaja formy "zombi". Usuwamy stary klucz i podmieniamy go w kolejnosci.
K.config.targets.zombie = nil
K.config.attackForms.zombie = nil
K.config.introducedTargets230.zombie = nil
do
  local migrated, seen = {}, {}
  for _, target in ipairs(K.config.targetOrder) do
    if target == "zombie" then target = "zombi" end
    if not seen[target] then
      migrated[#migrated + 1] = target
      seen[target] = true
    end
  end
  K.config.targetOrder = migrated
end
-- Migracja z wersji 2.0.x: usuwamy dawne rozkazywanie zaslon innym graczom.
-- Nowy modul 2.5.0 wykonuje wylacznie bezposrednie "zaslon <kogo>".
if K.shieldTimer then pcall(killTimer, K.shieldTimer) end
K.shieldTimer = nil
K.shieldLastTarget = nil
K.config.shieldPlayers = nil
K.config.shieldAuto = nil
K.config.shieldTarget = nil
K.config.shieldHp = nil
K.config.shieldInterval = nil
K.config.selfShieldMode = nil
if K.config.ignoreNonTargets == nil then K.config.ignoreNonTargets = true end
K.config.ignoredNames = K.config.ignoredNames or {}
-- Zachowujemy stara nazwe, jezeli inne fragmenty profilu jej uzywaja.
K.config.animals = K.config.targets

-- Domyslny obszar z listy przekazanej przy tworzeniu skryptu.
K.rooms = K.rooms or {
  1321, 1322, 1323, 1324, 1325, 1326, 1338, 1339, 1340, 1341, 1342, 1343,
  1344, 1345, 1346, 1348, 1349, 1350, 1351, 1352, 1354, 1355, 1356, 1357,
  1358, 1359, 1360, 1361, 1362, 1363, 1364, 1365, 1366, 1367, 1368, 1369,
  1420, 1423, 1424, 1425, 1426, 2212, 2213, 2214, 2767, 2768, 2769, 2770,
  2771, 2772, 2773, 2774, 2775, 2776, 2777, 2778, 2779, 2783, 2784, 2785,
  2786, 2787, 2789, 2790, 2791, 2792, 2793, 2794, 2795, 2796, 2797, 2798,
  2799, 2800, 2802, 2803, 2804, 2805, 2806, 2807, 2819, 2820, 2821, 2822,
  2823, 2824, 2825, 2831, 2832, 2833, 2834, 2835, 2836, 2837, 2838, 2839,
  2840, 2841, 2842, 2843, 2844, 2845, 2846, 2847, 2850, 2851, 2852, 2853,
  2854, 2855, 2856, 2857, 2858, 2859, 2860, 2861, 2862, 2863, 2864, 2865,
  2866, 2867, 2868, 2869, 2870, 2871, 2872, 2873, 2874, 2875, 2876, 2878,
  3201, 3379,
}

K.enabled = false
K.mode = "stop"
K.generation = (K.generation or 0) + 1
K.route = nil
K.routeIndex = 1
K.visited = {}
K.roomSet = {}
K.currentTargetId = nil
K.currentTargetName = nil
K.currentTargetAnimal = nil
K.currentTargetAmbiguous, K.pendingKill = false, nil
K.lastHp = 100
K.lastMoves = 100
K.teamLowestHp = 100
K.teamLowestName = "ty"
K.teamSeenCount = 1
K.teamHealth = {}
K.injuredTeamMember = nil
K.escapeTailSent = false
K.refugeRoom, K.recoveryEmergency, K.previousRoom = nil, nil, nil
K.combatRoomReady = true
K.roomCombatState = nil
K.lastRoom = nil
K.pursuitOriginRoom = nil
K.pursuitTrail = {}
K.pursuitLeftArea = false
K.returnCommands = nil
K.returnIndex = 1
K.returnSteps = 0
K.entitiesReady = true
K.patrolMovePending = false
K.chaseMovePending = false
K.panicCenter = nil
K.panicExits = nil
K.panicIndex = 1
K.panicPhase = nil
K.idleSteps = 0
K.limitNoticeRoom = nil
K.limitRoom, K.creatureCountCache = nil, nil
K.focusRetryPending = false
K.pendingFleeName = nil
K.failedTargetIds = {}
K.lastProgressFingerprint = nil
K.returnFallbackCommands = nil
K.returnFallbackIndex = 1
K.returnUsedMap = false
K.escapeAttempts = 0
K.idleAliasAttempts = 0
K.idleAliasActive = false
K.recoveryAttempts = 0
K.routeRecoveryAttempts = 0
K.herbSearchedRoom = nil
K.roomChangePending = false
K.failedExits = {}
K.recoveryRoster = nil
K.sessionBlocked = K.sessionBlocked == true
K.sessionFresh = K.sessionBlocked and {room=false, entities=false, combat=false, group=false}
  or {room=true, entities=true, combat=true, group=true}
K.sessionFresh.vitals = not K.sessionBlocked
K.reconnectTask = nil
K.reconnectWaitReason = nil
K.vitalsRevision = 0
K.vitalsSource = nil
K.statusPanelStart = nil
K.statusPanelEnd = nil
K.dataRevision, K.hpRevision = 0, 0
K.sourceRevisions = {entities=0, group=0, char=0}
K.groupContextCache, K.entityIndexCache, K.combatCache = nil, nil, nil
K.npcNameCounts = {}
K.npcNameEntities = {}
K.vitalsCacheRevision = nil
K.healthHistory, K.shieldTransfers = {}, {}
K.previousIncoming = nil
K.transferRevision, K.lastHealthObservationRevision = nil, nil
K.lastActivityAt = nil
K.lastGmcpAt, K.lastGmcpEvent, K.lastOwnCombatAt, K.lastDecisionAt = nil, nil, nil, nil
K.lastIdleDiagnostic = nil
K.shieldFailure, K.shieldBlockedReason = nil, nil
K.supportAttempt = nil
K.supportHintSerial = 0
K.supportDeathBarrier = nil
K.deadNpcIds = {}
K.recentTarget = nil
K.restartPending = nil
K.progressOwn, K.progressTeam = {}, {}
K.movementKnown, K.movementRevision = false, nil
K.teamMoves = {}
K.recoveryTired = {}
K.movementRest, K.moveSnapshot, K.teamStep = nil, nil, nil
K.regroupFailures = 0
K.emptyRounds, K.patrolRoundKills, K.emptyPatrolDelay = 0, 0, 0
K.metrics = {events=0, actions=0, scheduled=0, coalesced=0, health=0,
  combat=0, shields=0, shieldBlocked=0, support=0, index=0,
  attacks=0, attackRetries=0, idleResets=0, restartWaits=0,
  movementRests=0, regroups=0}

local knownTargets = {
  "koza", "kon", "krowa", "jelen", "koziol", "byk", "zubr", "szkielet",
  "sarna", "zajac", "daniel", "borsuk", "wilk", "kuna", "troglodyta",
  "reptilion", "zombi", "ogr", "niedzwiedz", "gnoll", "ozywieniec",
  "fimir", "troll", "linkantrop", "zwierzoczlek", "zolnierz", "rycerz", "bazant",
  "krasnolud chaosu",
  "snotling", "ork", "goblin", "hobgoblin", "waz",
}
local attackWords = {
  koza = "koze", kon = "konia", krowa = "krowe",
  jelen = "jelenia", koziol = "kozla", byk = "byka", zubr = "zubra", szkielet = "szkielet",
  sarna = "sarne", zajac = "zajaca", daniel = "daniela", borsuk = "borsuka",
  wilk = "wilka", kuna = "kune", troglodyta = "troglodyte",
  reptilion = "reptiliona", zombi = "zombiego", ogr = "ogra",
  niedzwiedz = "niedzwiedzia", gnoll = "gnolla", ozywieniec = "ozywienca",
  fimir = "fimira", troll = "trolla", linkantrop = "linkantropa",
  zwierzoczlek = "zwierzoczleka", zolnierz = "zolnierza", rycerz = "rycerza",
  bazant = "bazanta",
  ["krasnolud chaosu"] = "krasnoluda chaosu",
  snotling = "snotlinga", ork = "orka", goblin = "goblina",
  hobgoblin = "hobgoblina", waz = "weza",
}
local ignoreWordAliases = {
  kozy = "koza", konie = "kon", krowy = "krowa", jelenie = "jelen",
  kozly = "koziol", byki = "byk", zubry = "zubr", szkielety = "szkielet", snotlingi = "snotling", orki = "ork",
  sarny = "sarna", zajace = "zajac", daniele = "daniel", borsuki = "borsuk",
  wilki = "wilk", kuny = "kuna", troglodyci = "troglodyta",
  reptilioni = "reptilion", zombie = "zombi", zombi = "zombi", ogry = "ogr",
  niedzwiedzie = "niedzwiedz", gnolle = "gnoll", ozywiency = "ozywieniec",
  fimiry = "fimir", linkantropy = "linkantrop", zwierzoczleki = "zwierzoczlek",
  zolnierze = "zolnierz", rycerze = "rycerz", bazanty = "bazant",
  gobliny = "goblin", hobgobliny = "hobgoblin", weze = "waz", trolle = "troll",
}
do
  local present = {}
  for _, target in ipairs(K.config.targetOrder) do present[target] = true end
  for _, target in ipairs(knownTargets) do
    if not present[target] then
      K.config.targetOrder[#K.config.targetOrder + 1] = target
      present[target] = true
    end
  end
  for target, form in pairs(attackWords) do
    -- Naprawiamy tez forme zapisana przez starsza wersje, np. bledne
    -- "zabij ork" zamiast wymaganego przez serwer "zabij orka".
    K.config.attackForms[target] = form
  end
end
local animalOrder = K.config.targetOrder

local function attackForm(target)
  return K.config.attackForms[target] or attackWords[target] or target
end
local directionCommands = {
  -- Nazwy zwracane przez mape Mudleta.
  ["north"] = "n", ["south"] = "s", ["east"] = "e", ["west"] = "w",
  ["northeast"] = "ne", ["northwest"] = "nw",
  ["southeast"] = "se", ["southwest"] = "sw",
  ["north-east"] = "ne", ["north-west"] = "nw",
  ["south-east"] = "se", ["south-west"] = "sw",
  ["up"] = "u", ["down"] = "d",
  -- Kierunki przesylane w polskich komunikatach Chimery.
  ["polnoc"] = "n", ["poludnie"] = "s", ["wschod"] = "e", ["zachod"] = "w",
  ["polnocny-wschod"] = "ne", ["polnocny-zachod"] = "nw",
  ["poludniowy-wschod"] = "se", ["poludniowy-zachod"] = "sw",
  ["gora"] = "u", ["gore"] = "u", ["dol"] = "d",
}
local inverseDirections = {
  n = "s", s = "n", e = "w", w = "e",
  ne = "sw", sw = "ne", nw = "se", se = "nw",
  u = "d", d = "u",
}

local function note(message, colour)
  cecho(string.format("\n<%s>[KOZOJEB] <reset>%s\n", colour or "cyan", message))
end

local function cleanText(value)
  local text = tostring(value or "")
  -- Niektore pakiety GMCP zawieraja niewidoczny reset koloru ESC[0m.
  -- Usuwamy kody ANSI oraz ich pozostalosc "[0m" zanim nazwa trafi do stanu
  -- lub zostanie porownana z tekstem komunikatu o ucieczce.
  text = text:gsub("\27%[[%d;?]*[%a]", "")
  text = text:gsub("%[[%d;]+m", "")
  return text
end

local function trim(value)
  return cleanText(value):match("^%s*(.-)%s*$")
end

local function normal(value)
  return trim(value):lower()
end

local function now()
  -- Mudlet getEpoch: sekundy z czescia milisekundowa; bez aktywnego timera.
  return type(getEpoch) == "function" and getEpoch() or os.time()
end

local function invalidateState(health, eventName)
  K.dataRevision = K.dataRevision + 1
  if not eventName or eventName == "gmcp.Chimera.Room.Entities" then
    K.groupContextCache, K.entityIndexCache, K.combatCache = nil, nil, nil
    K.creatureCountCache = nil
  elseif eventName == "gmcp.Chimera.Group.State" then
    K.groupContextCache = nil
  elseif eventName == "gmcp.Chimera.Combat.State" then
    K.combatCache = nil
  end
  if health then K.hpRevision = K.hpRevision + 1 end
end

-- Ustawienia rol sa lokalne dla profilu Mudleta. Nie wymagaja polaczenia
-- miedzy profilami: sklad, prowadzacego i walke potwierdza serwer przez GMCP.
local roleLabels = {
  prowadzacy = "prowadzacy",
  wsparcie = "druga linia: wsparcie i DPS",
  zaslony = "wsparcie i zaslony calej druzyny",
}
local function roleSettingsPath()
  if type(getMudletHomeDir) ~= "function" then return nil end
  local ok, home = pcall(getMudletHomeDir)
  if ok and type(home) == "string" and home ~= "" then
    return home .. "/chimera_kozojeb_role.lua"
  end
end

if not K.roleSettingsLoaded then
  local path = roleSettingsPath()
  local saved = {}
  if path and type(table.load) == "function" then pcall(table.load, path, saved) end
  if next(saved) == nil and path and type(table.load) == "function" then
    pcall(table.load, path:gsub("kozojeb", "kozobot"), saved)
  end
  if roleLabels[saved.role] then K.config.role = saved.role end
  if type(saved.leaderName) == "string" and saved.leaderName:match("^[%a%-]*$") then
    K.config.leaderName = saved.leaderName
  end
  local hp = tonumber(saved.leaderShieldHp)
  if hp and hp >= 0 and hp <= 100 and hp % 1 == 0 then K.config.leaderShieldHp = hp end
  local selfHp = tonumber(saved.shieldSelfHp)
  if selfHp and selfHp >= 0 and selfHp <= 100 and selfHp % 1 == 0 then K.config.shieldSelfHp = selfHp end
  if type(saved.shieldNameForms) == "table" then
    for name, form in pairs(saved.shieldNameForms) do
      if type(name) == "string" and name:match("^[%a%-]+$")
          and (form == false or (type(form) == "string" and form:match("^[%a%-]+$"))) then
        K.config.shieldNameForms[normal(name)] = form
      end
    end
  end
  K.roleSettingsLoaded = true
end
if not roleLabels[K.config.role] then K.config.role = "prowadzacy" end
K.config.leaderName = K.config.leaderName or ""
K.config.leaderShieldHp = tonumber(K.config.leaderShieldHp) or 70
K.config.shieldSelfHp = math.max(0, math.min(100, tonumber(K.config.shieldSelfHp) or K.config.escapeHp or 50))
K.config.supportInterval = 2.0
K.supportCombatHint = nil
K.supportLastTarget = nil
K.leaderName = nil
K.leaderHp = nil
K.supportWaitReason = nil
K.shieldMissingForms = {}
K.shieldRejectedForms = {}
K.shieldPendingTarget = nil
K.shieldRescue, K.shieldTurn, K.teamShieldNotices = nil, nil, {}
K.shieldPositionUntil = {}
if K.shieldPositionTimer then pcall(killTimer, K.shieldPositionTimer) end
K.shieldPositionTimer, K.shieldPositionToken = nil, nil
K.sendingShield = nil
if K.shieldReplyTimer then pcall(killTimer, K.shieldReplyTimer) end
K.shieldReplyTimer, K.shieldReplyToken = nil, nil
K.shieldFormationReady = true
if K.formationTimer then pcall(killTimer, K.formationTimer) end
K.formationTimer = nil
K.formationToken = nil
K.combatRevision = 0
K.shieldAwaitCombatRevision = nil

local function saveRoleSettings()
  K.saveSettings()
  local path = roleSettingsPath()
  if not path or type(table.save) ~= "function" then
    note("Ustawienie dziala teraz; zapis na kolejna sesje jest niedostepny.", "yellow")
    return
  end
  local ok, result, err = pcall(table.save, path, {
    role = K.config.role,
    leaderName = K.config.leaderName,
    leaderShieldHp = K.config.leaderShieldHp,
    shieldSelfHp = K.config.shieldSelfHp,
    shieldNameForms = K.config.shieldNameForms,
  })
  if not ok or result == false or err then note("Nie udalo sie zapisac ustawien roli na kolejna sesje.", "red") end
end

local function isFollower()
  return K.config.role ~= "prowadzacy"
end

local function isSelf(entity)
  return entity and (entity.self == 1 or entity.self == true or entity.relation == "self")
end

local function copyArray(source)
  local result = {}
  for i, value in ipairs(source or {}) do result[i] = value end
  return result
end

local function cancelTimer(name)
  if K[name] then
    pcall(killTimer, K[name])
    K[name] = nil
  end
end

local function cancelAllTimers()
  for _, name in ipairs({
    "actionTimer", "moveTimer", "restTimer", "escapeTimer", "killTimer",
    "returnTimer", "healTimer", "recoveryTimer",
    "panicTimer",
    "idleTimer", "idleReturnTimer",
    "focusTimer", "pendingFleeTimer", "targetLostTimer",
    "killConfirmTimer", "escapeWatchTimer", "shieldTimer", "herbTimer",
    "supportTimer", "supportHintTimer", "shieldTurnTimer", "teamShieldTimer", "reconnectTimer",
    "movementRestTimer", "teamStepTimer",
  }) do
    cancelTimer(name)
  end
  K.patrolMovePending = false
  K.chaseMovePending = false
  K.pendingFleeName = nil
  K.idleAliasActive = false
  K.shieldLastTarget = nil
  K.supportCombatHint = nil
  K.supportDeathBarrier = nil
  K.supportLastTarget = nil
  K.shieldTurn, K.teamShieldNotices = nil, {}
  K.supportAttempt = nil
  K.limitRoom = nil
  -- Gotowosc szyku opisuje stan w grze; stop/start lub zmiana roli jej
  -- nie odnawia. Osobny formationTimer dziala tez podczas pauzy bota.
end

-- Lista encji z poprzedniego pokoju nie moze wywolac ataku po wyslaniu
-- kierunku. Dopiero Room.Info, a nastepnie nowa lista encji zwalnia blokade.
local function sendDirection(command, regroup)
  if K.prepareMovement and not K.prepareMovement(command, regroup) then return end
  K.recentTarget = nil
  K.roomChangePending = true
  K.entitiesReady = false
  K.sentDirection = command
  send(command)
  return true
end

local function later(name, seconds, callback)
  cancelTimer(name)
  local generation = K.generation
  K[name] = tempTimer(seconds, function()
    K[name] = nil
    if generation ~= K.generation then return end
    callback()
  end)
end

local function queueInspection(callback)
  if K.actionTimer then
    K.metrics.coalesced = K.metrics.coalesced + 1
    return
  end
  K.metrics.scheduled = K.metrics.scheduled + 1
  later("actionTimer", K.config.actionDelay, callback)
end

local function idleIsIntentional()
  return K.movementRest ~= nil or K.teamStep ~= nil
    or K.restartPending ~= nil or K.mode == "stop" or K.mode == "kill_pause"
    or K.mode == "escape" or K.mode == "heal_rest" or K.mode == "recovery_return"
    or K.mode == "herb_search" or K.mode == "leader_wait"
end

local function checkIdleDeadline()
  if not K.enabled or isFollower() then return end
  if idleIsIntentional() then K.lastActivityAt = now() end
  local remaining = K.config.idleTimeout - (now() - (K.lastActivityAt or now()))
  if remaining > 0.01 then
    later("idleTimer", remaining, checkIdleDeadline)
  else
    K.onIdleTimeout()
  end
end

local function touchActivity()
  if not K.enabled or isFollower() then return end
  K.lastActivityAt = now()
  -- Pakiety walki tylko przesuwaja termin; nie tworza nowego timera.
  if not K.idleTimer then later("idleTimer", K.config.idleTimeout, checkIdleDeadline) end
end

local function rebuildRoomSet()
  K.roomSet = {}
  local clean, seen = {}, {}
  for _, rawId in ipairs(K.rooms or {}) do
    local id = tonumber(rawId)
    if id and not seen[id] then
      clean[#clean + 1] = id
      seen[id] = true
      K.roomSet[id] = true
    end
  end
  K.rooms = clean
end

local function currentRoom()
  if type(getPlayerRoom) ~= "function" then return nil end
  local ok, room = pcall(getPlayerRoom)
  if ok then return tonumber(room) end
  return nil
end

local function entities()
  local node = gmcp and gmcp.Chimera and gmcp.Chimera.Room and gmcp.Chimera.Room.Entities
  return node and node.entities or {}
end

local function entityIndex()
  if K.entityIndexCache then return K.entityIndexCache end
  local index, names, byName = {}, {}, {}
  for _, entity in ipairs(entities()) do
    if entity.id ~= nil then index[tostring(entity.id)] = entity end
    if entity.kind == "npc" then
      local name = normal(entity.name)
      names[name] = (names[name] or 0) + 1
      byName[name] = entity
    end
  end
  K.npcNameCounts = names
  K.npcNameEntities = byName
  if K.currentTargetName and (names[normal(K.currentTargetName)] or 0) > 1 then
    K.currentTargetAmbiguous = true
  end
  K.metrics.index = K.metrics.index + 1
  K.entityIndexCache = index
  return index
end

local function combatState()
  if K.combatRoomReady and K.sessionFresh.combat then
    return gmcp and gmcp.Chimera and gmcp.Chimera.Combat and gmcp.Chimera.Combat.State or {}
  end
  -- Po Room.Info nie odtwarzamy relacji z poprzedniej lokacji. Przy braku
  -- nowego GMCP dopuszczamy tylko ataki widoczne juz w biezacym pokoju.
  local observed = K.roomCombatState
  return observed and observed.room == currentRoom() and observed or {}
end

local function groupState()
  if not K.sessionFresh.group then return {} end
  return gmcp and gmcp.Chimera and gmcp.Chimera.Group and gmcp.Chimera.Group.State or {}
end

local function leaderRole(value)
  local role = normal(value)
  return role == "leader" or role == "prowadzacy" or role == "lider"
end

local function healthPair(record)
  if type(record) ~= "table" then return nil end
  local hp, maximum = tonumber(record.hp), tonumber(record.maxhp or record.max_hp)
  if not hp or not maximum or hp ~= hp or maximum ~= maximum
      or maximum <= 0 or maximum == math.huge or hp < 0 or hp > maximum then return nil end
  return hp, maximum, math.floor(hp * 100 / maximum + 0.5)
end

local function healthPercent(record)
  local _, _, percent = healthPair(record)
  return percent
end

local function latestHealth(entity, member)
  local first, second, source = entity, member, "entities"
  if K.sourceRevisions.group > K.sourceRevisions.entities then
    first, second, source = member, entity, "group"
  end
  local hp, maximum, percent = healthPair(first)
  if not hp then
    hp, maximum, percent = healthPair(second)
    source = source == "group" and "entities" or "group"
  end
  if hp then return {hp=hp, maxhp=maximum, percent=percent, source=source} end
end

-- Chimera podaje fatigue (0 = wypoczety, 100 = wycienczony).
-- Progi odpoczynek nadal oznaczaja pozostala sile do ruchu.
local function movementPercent(record)
  if type(record) ~= "table" then return nil end
  local fatigue = tonumber(record.fatigue)
  if fatigue and fatigue == fatigue and fatigue >= 0 and fatigue <= 100 then
    return 100 - fatigue
  end
  local moves, maximum = tonumber(record.moves), tonumber(record.maxmoves)
  if moves and maximum and moves == moves and maximum == maximum
      and maximum > 0 and maximum < math.huge and moves >= 0 and moves <= maximum then
    return moves * 100 / maximum
  end
end

local function latestMovement(entity, member)
  local first, second, firstRev, secondRev = entity, member,
    K.sourceRevisions.entities, K.sourceRevisions.group
  if secondRev > firstRev then
    first, second, firstRev, secondRev = member, entity, secondRev, firstRev
  end
  local value = movementPercent(first)
  if value ~= nil then return value, firstRev end
  value = movementPercent(second)
  if value ~= nil then return value, secondRev end
end

-- Jawna lista members ma pierwszenstwo przed starszymi group_role encji.
-- Pusta lista po rozwiazaniu druzyny nie moze zostawic aktywnego wsparcia.
local function groupContext()
  if K.groupContextCache then return K.groupContextCache end
  local state = groupState()
  local ids, names, leaderRefs, memberVitals = {}, {}, {}, {}
  local rosterKnown = type(state.members) == "table"
  local rosterEmpty = rosterKnown and next(state.members) == nil
  local function remember(ref, key, isLeader)
    if type(ref) == "table" then
      local id = ref.id or ref.entity_id or ref.obname or ref.chimera_source_id
      local name = ref.name or ref.desc
      if id then
        ids[tostring(id)] = true
        memberVitals[tostring(id)] = ref
      end
      if name then
        names[normal(name)] = true
        memberVitals[normal(name)] = ref
      end
      if isLeader or leaderRole(ref.group_role or ref.role)
          or ref.is_leader == true or ref.is_leader == 1 then
        leaderRefs[#leaderRefs + 1] = { id = id, name = name }
      end
    elseif type(ref) == "string" or type(ref) == "number" then
      ids[tostring(ref)], names[normal(ref)] = true, true
      if type(key) == "string" then ids[key], names[normal(key)] = true, true end
      if isLeader then leaderRefs[#leaderRefs + 1] = { id = ref, name = ref } end
    end
  end
  for key, member in pairs(state.members or {}) do remember(member, key, false) end
  if not rosterEmpty then remember(state.leader_id or state.leader or state.leader_name, nil, true) end
  local context = { members = {}, actualLeader = nil, leader = nil, self = nil,
    memberVitals = memberVitals }
  for _, entity in ipairs(entities()) do
    if isSelf(entity) then context.self = entity end
    local role = normal(entity.group_role)
    local member = not rosterEmpty and (ids[tostring(entity.id)] or names[normal(entity.name)]
      or (not rosterKnown and role ~= "" and role ~= "none" and role ~= "self"))
    if member and entity.kind ~= "npc" then
      context.members[#context.members + 1] = entity
    end
  end
  -- Identyfikator leader w Group.State jest nadrzedny wobec group_role,
  -- ktory moze jeszcze opisywac poprzedniego prowadzacego po przekazaniu.
  for index = #leaderRefs, 1, -1 do
    local ref = leaderRefs[index]
    for _, entity in ipairs(context.members) do
      if (ref.id and tostring(ref.id) == tostring(entity.id))
          or (ref.name and normal(ref.name) == normal(entity.name)) then
        context.actualLeader = entity
        break
      end
    end
    if context.actualLeader then break end
  end
  if not context.actualLeader and #leaderRefs == 0 then
    for _, entity in ipairs(context.members) do
      if leaderRole(entity.group_role) then
        if context.actualLeader then context.actualLeader = nil break end
        context.actualLeader = entity
      end
    end
  end
  local wanted = normal(K.config.leaderName)
  if wanted == "" then
    context.leader = context.actualLeader
  else
    for _, entity in ipairs(context.members) do
      if normal(entity.name) == wanted then context.leader = entity break end
    end
    if context.actualLeader and context.leader
        and tostring(context.leader.id) ~= tostring(context.actualLeader.id) then
      context.leader = nil
      context.reason = "Wskazany gracz nie prowadzi juz druzyny (/kozojeb lider auto)."
    end
  end
  if isSelf(context.leader) then
    context.leader = nil
    context.reason = "Ten profil prowadzi druzyne; wybierz /kozojeb rola prowadzacy."
  end
  if not context.leader then
    context.reason = context.reason or (wanted ~= ""
      and "Wskazany lider nie jest widocznym czlonkiem druzyny."
      or "Czekam na widocznego prowadzacego druzyny (GMCP).")
  end
  if context.leader then
    local leader = context.leader
    context.leaderVitals = latestHealth(leader,
      memberVitals[tostring(leader.id)] or memberVitals[normal(leader.name)])
    context.leaderHp = context.leaderVitals and context.leaderVitals.percent
  end
  K.groupContextCache = context
  return context
end

-- Watchdog ma mierzyc rzeczywisty postep, a nie sam fakt nadejscia pakietu
-- GMCP. Identyczne pakiety nie odswiezaja czasu aktywnosci; zmiana pokoju,
-- celu walki albo HP widocznej postaci juz tak.
local function progressFingerprint()
  local parts = { tostring(currentRoom() or "?") }
  local state = combatState()
  parts[#parts + 1] = "p:" .. tostring(state.primary or "")
  local relations = {}
  for _, relation in ipairs(state.relations or {}) do
    relations[#relations + 1] = table.concat({
      tostring(relation.attacker or ""), tostring(relation.defender or "")
    }, ">")
  end
  table.sort(relations)
  parts[#parts + 1] = "r:" .. table.concat(relations, ",")

  local visible = {}
  for _, entity in ipairs(entities()) do
    visible[#visible + 1] = table.concat({
      tostring(entity.id or ""), tostring(entity.hp or ""),
      tostring(entity.maxhp or ""), tostring(entity.relation or ""),
      tostring(entity.group_role or "")
    }, ":")
  end
  table.sort(visible)
  parts[#parts + 1] = "e:" .. table.concat(visible, ",")
  return table.concat(parts, "|")
end

local function nameHasAnimal(name, animal)
  local value = normal(name)
  return value:match("%f[%a]" .. animal .. "%f[%A]") ~= nil
end

local function animalKind(name)
  for _, animal in ipairs(animalOrder) do
    if nameHasAnimal(name, animal) then return animal end
  end
  return nil
end

local function animalInName(name)
  for _, animal in ipairs(animalOrder) do
    if K.config.animals[animal] and nameHasAnimal(name, animal) then
      return animal
    end
  end
  return nil
end

local function nameHasPlainPhrase(name, phrase)
  local haystack = " " .. normal(name):gsub("[^%a%-]+", " ") .. " "
  phrase = normal(phrase):gsub("[^%a%-]+", " "):match("^%s*(.-)%s*$")
  return phrase ~= "" and haystack:find(" " .. phrase .. " ", 1, true) ~= nil
end

local function nameHasIgnoredPhrase(name)
  for key, displayName in pairs(K.config.ignoredNames or {}) do
    local phrase = displayName == true and key or displayName
    local words = {}
    for word in normal(phrase):gmatch("[%a%-]+") do words[#words + 1] = word end
    if #words > 0 and ignoreWordAliases[words[#words]] then
      words[#words] = ignoreWordAliases[words[#words]]
    end
    local canonicalPhrase = table.concat(words, " ")
    if nameHasPlainPhrase(name, phrase)
        or (canonicalPhrase ~= "" and nameHasPlainPhrase(name, canonicalPhrase)) then
      return normal(phrase)
    end
  end
  return nil
end

local function selectedTargetKindInAnyForm(name)
  for _, target in ipairs(animalOrder) do
    if K.config.animals[target]
        and (nameHasAnimal(name, target) or nameHasPlainPhrase(name, attackForm(target))) then
      return target
    end
  end
  return nil
end

local function ignoredNameList()
  local result = {}
  for key, displayName in pairs(K.config.ignoredNames or {}) do
    result[#result + 1] = tostring(displayName == true and key or displayName)
  end
  table.sort(result, function(a, b) return normal(a) < normal(b) end)
  return result
end

local function isCurrentTarget(entity)
  if not entity or not K.currentTargetName then return false end
  if K.currentTargetId and entity.id then return tostring(entity.id) == tostring(K.currentTargetId) end
  return normal(entity.name) == normal(K.currentTargetName)
end

local function targetNameAmbiguous(name)
  local key = normal(name)
  local recent = K.recentTarget
  return (normal(K.currentTargetName) == key and K.currentTargetAmbiguous)
    or (recent and normal(recent.name) == key and recent.ambiguous)
    or (K.npcNameCounts[key] or 0) > 1
end

local function liveNpc(entity)
  return entity and entity.kind == "npc" and not K.deadNpcIds[tostring(entity.id)]
    and (not tonumber(entity.hp) or tonumber(entity.hp) > 0)
end

local function combatTargetAllowed(entity, confirmedOutgoing)
  if not liveNpc(entity) or nameHasIgnoredPhrase(entity.name) then return false end
  if K.currentTargetName then
    if isCurrentTarget(entity) then return true end
    -- "zabij fimira" moze wybrac innego fimira niz pierwszy wpis w GMCP.
    -- Przyjmujemy tylko potwierdzony wlasny atak na dozwolony ten sam gatunek;
    -- sam primary, agresja lub walka innych postaci nie zmieniaja celu.
    return confirmedOutgoing and K.currentTargetAnimal ~= nil
      and animalInName(entity.name) == K.currentTargetAnimal
      and (not K.currentTargetId or liveNpc(entityIndex()[tostring(K.currentTargetId)]))
      and not K.failedTargetIds[tostring(entity.id)]
  end
  return not K.config.ignoreNonTargets or animalInName(entity.name) ~= nil
end

local function entityById(id)
  if not id then return nil end
  return entityIndex()[tostring(id)]
end

local function currentTargetEntity()
  local target = entityById(K.currentTargetId)
  if liveNpc(target) then return target end
  -- Znane ID w tym pokoju nie moze zostac zastapione zywa kopia opisu.
  -- Potwierdzony poscig ponownie wyszukuje nazwe dopiero po wyjsciu NPC.
  if K.currentTargetId then return nil end
  if not K.currentTargetName then return nil end
  for _, entity in ipairs(entities()) do
    if liveNpc(entity) and normal(entity.name) == normal(K.currentTargetName) then
      return entity
    end
  end
  return nil
end

local function activeCombatTarget()
  local state = combatState()
  local selfId
  for _, entity in ipairs(entities()) do
    if isSelf(entity) then selfId = tostring(entity.id) break end
  end
  -- Wlasny atak ma pierwszenstwo przed primary i napastnikami. Przy kilku
  -- relacjach zachowujemy obecny cel, potem primary, a na koncu stabilne ID.
  local outgoing
  if selfId then
    for _, relation in ipairs(state.relations or {}) do
      if tostring(relation.attacker) == selfId then
        local target = entityById(relation.defender)
        if liveNpc(target) then
          if tostring(target.id) == tostring(K.currentTargetId) then return target, true end
          if not outgoing or tostring(target.id) == tostring(state.primary)
              or (tostring(outgoing.id) ~= tostring(state.primary)
                and tostring(target.id) < tostring(outgoing.id)) then outgoing = target end
        end
      end
    end
  end
  if outgoing then return outgoing, true end
  local id = state.primary
  if id and id ~= "" then
    local entity = entityById(id)
    if liveNpc(entity) then return entity end
  end
  if not selfId then return nil end
  for _, relation in ipairs(state.relations or {}) do
    local opponent
    if tostring(relation.attacker) == selfId then opponent = relation.defender
    elseif tostring(relation.defender) == selfId then opponent = relation.attacker end
    local entity = opponent and entityById(opponent)
    if liveNpc(entity) then return entity end
  end
  return nil
end

local function hostileTarget()
  local combat, outgoing = activeCombatTarget()
  if combatTargetAllowed(combat, outgoing) then return combat end
  for _, entity in ipairs(entities()) do
    if entity.kind == "npc" and entity.self ~= 1 and entity.relation == "hostile"
        and combatTargetAllowed(entity) then
      return entity
    end
  end
  return nil
end

local function roomCreatureCount()
  local cached = K.creatureCountCache
  if cached then return cached.count, cached.bull, cached.maleGoat end
  local bullPresent = false
  local maleGoatPresent = false
  local creatureCount = 0
  for _, entity in ipairs(entities()) do
    if liveNpc(entity) and entity.self ~= 1 then
      if nameHasAnimal(entity.name, "byk") then bullPresent = true end
      if nameHasAnimal(entity.name, "koziol") then maleGoatPresent = true end
      local selected = animalInName(entity.name) ~= nil
      if not nameHasIgnoredPhrase(entity.name)
          and (not K.config.ignoreNonTargets or selected) then
        creatureCount = creatureCount + 1
      end
    end
  end
  K.creatureCountCache = {count=creatureCount, bull=bullPresent, maleGoat=maleGoatPresent}
  return creatureCount, bullPresent, maleGoatPresent
end

local function findTarget()
  local creatureCount, bullPresent, maleGoatPresent = roomCreatureCount()
  for _, animal in ipairs(animalOrder) do
    if K.config.animals[animal] then
      for _, entity in ipairs(entities()) do
        local cowBlocked = animal == "krowa" and bullPresent
        local goatBlocked = animal == "koza" and maleGoatPresent
        if not cowBlocked and not goatBlocked
            and liveNpc(entity) and entity.self ~= 1
            and not K.failedTargetIds[tostring(entity.id or "")]
            and not nameHasIgnoredPhrase(entity.name)
            and animalInName(entity.name) == animal then
          if K.config.maxCreatures > 0 and creatureCount > K.config.maxCreatures then
            return nil, nil, "limit", creatureCount
          end
          return entity, animal
        end
      end
    end
  end
  return nil, nil, nil, creatureCount
end

local function updateVitals()
  if K.vitalsCacheRevision == K.hpRevision then return end
  K.vitalsCacheRevision = K.hpRevision
  K.metrics.health = K.metrics.health + 1
  local previousMoves = K.lastMoves
  local roomHp, roomRecord
  local roomEntities = entities()
  for _, entity in ipairs(roomEntities) do
    if isSelf(entity) then
      roomHp = healthPercent(entity)
      roomRecord = entity
      break
    end
  end
  local vitals = gmcp and gmcp.Char and gmcp.Char.Vitals or {}
  local charHp = healthPercent(vitals)
  -- Kazde zrodlo musi dostarczyc wlasna kompletna pare hp/maxhp. Skale
  -- Char.Vitals i Room.Entities moga sie roznic. W trakcie ruchu encje sa
  -- niedostepne; niepelny pakiet nie zmienia ostatniego poprawnego HP.
  local hp = roomHp or charHp
  local ownRecord = roomHp and roomRecord or (charHp and vitals)
  local ownSource = roomHp and "entities" or "char"
  if K.vitalsSource == "char" then
    hp = charHp or roomHp
    ownRecord = charHp and vitals or roomRecord
    ownSource = charHp and "char" or "entities"
  end
  if hp then K.lastHp = hp end

  local context = groupContext()
  local state = groupState()
  local own = context.self
  local ownGroup = own and (context.memberVitals[tostring(own.id)] or context.memberVitals[normal(own.name)])
  local groupOwnHp = healthPercent(ownGroup)
  if groupOwnHp and K.sourceRevisions.group > math.max(K.sourceRevisions.entities, K.sourceRevisions.char) then
    K.lastHp = groupOwnHp
    ownRecord = ownGroup
    ownSource = "group"
  end
  local movement, movementRevision = latestMovement(K.entitiesReady and own or nil, ownGroup)
  local charMovement
  if K.sessionFresh.vitals then charMovement = movementPercent(vitals) end
  if charMovement ~= nil and (movement == nil or K.sourceRevisions.char >= movementRevision) then
    movement, movementRevision = charMovement, K.sourceRevisions.char
  end
  if movement ~= nil then
    K.lastMoves, K.movementKnown, K.movementRevision = math.floor(movement + 0.5), true, movementRevision
  end
  local teamMoves = {}
  local healthByName, rawByName, counted = {}, {}, {}
  local lowest, lowestName, seen = 101, nil, 0
  local function consider(entity, member, id, name)
    if isSelf(entity) or isSelf(member) or (own and id and tostring(id) == tostring(own.id)) then return end
    local key = normal(name or id)
    if key == "" or counted[key] then return end
    counted[key] = true
    local strength = latestMovement(K.entitiesReady and entity or nil, member)
    if strength ~= nil then teamMoves[key] = strength end
    local value = latestHealth(K.entitiesReady and entity or nil, member)
    if not value then return end
    healthByName[key], rawByName[key] = value.percent, value
    seen = seen + 1
    if value.percent < lowest then lowest, lowestName = value.percent, tostring(name or id) end
  end
  for _, member in ipairs(context.members) do
    consider(member, context.memberVitals[tostring(member.id)] or context.memberVitals[normal(member.name)],
      member.id, member.name)
  end
  -- Pelny odczyt czlonka nie musi zawierac widocznej encji (np. podczas ruchu).
  for _, member in pairs(state.members or {}) do
    if type(member) == "table" then
      local id = member.id or member.entity_id or member.obname or member.chimera_source_id
      local name = member.name or member.desc
      consider(entityById(id), member, id, name)
    end
  end
  for _, entity in ipairs(roomEntities) do
    if K.config.teamMembers[normal(entity.name)] and entity.kind ~= "npc" then
      consider(entity, context.memberVitals[tostring(entity.id)], entity.id, entity.name)
    end
  end
  local progressed = previousMoves ~= K.lastMoves
  local ownHp, ownMax = healthPair(ownRecord)
  K.ownHealth = ownHp and {hp=ownHp, maxhp=ownMax} or nil
  if ownHp then
    local previous = K.progressOwn[ownSource]
    if not previous or ownHp ~= previous.hp or ownMax ~= previous.maxhp then
      progressed = true
      K.progressOwn[ownSource] = {hp=ownHp, maxhp=ownMax}
    end
  end
  -- Kazdy kanal ma wlasna skale HP. Przelaczanie miedzy niezmienionymi
  -- odczytami 1000/1000 i 10/10 nie jest postepem. Zachowujemy male,
  -- rzeczywiste zmiany punktow, nawet gdy procent po zaokragleniu jest ten sam.
  local progressTeam = {}
  for name, value in pairs(rawByName) do
    local channels = K.progressTeam[name] or {}
    local previous = channels[value.source]
    if not previous or previous.hp ~= value.hp or previous.maxhp ~= value.maxhp then progressed = true end
    channels[value.source] = value
    progressTeam[name] = channels
  end
  K.progressTeam = progressTeam
  if progressed then touchActivity() end
  K.teamSeenCount = seen
  K.teamLowestHp = seen > 0 and lowest or 100
  K.teamLowestName = seen > 0 and lowestName or "brak wykrytej druzyny"
  K.teamHealth, K.teamVitals = healthByName, rawByName
  K.teamMoves = teamMoves
  if K.enabled and not isFollower() then
    for name, value in pairs(teamMoves) do
      if value <= K.config.restAtMoves then
        K.recoveryTired[name] = name
        for _, member in ipairs(context.members) do
          if normal(member.name) == name then K.recoveryTired[name] = trim(member.name) break end
        end
      end
    end
  end
  K.selfVitals = own and latestHealth(own,
    context.memberVitals[tostring(own.id)] or context.memberVitals[normal(own.name)]) or nil

  -- Stala pamiec na widocznego gracza, bez rejestratora wszystkich pakietow.
  -- Obrazenia obserwujemy tylko w jednej skali Room.Entities, nigdy po
  -- zmianie pokoju, maksimum HP ani przy przelaczaniu zrodla.
  if K.entitiesReady and K.lastHealthObservationRevision ~= K.sourceRevisions.entities then
    K.lastHealthObservationRevision = K.sourceRevisions.entities
    local history, time, room = {}, now(), currentRoom()
    for _, entity in ipairs(roomEntities) do
      if isSelf(entity) or healthByName[normal(entity.name)] then
        local hp, maximum = healthPair(entity)
        if hp and entity.id then
          local id, previous = tostring(entity.id), K.healthHistory[tostring(entity.id)]
          local value = {hp=hp, maxhp=maximum, at=time, room=room, debt=0, shock=0}
          if previous and previous.room == room and previous.maxhp == maximum then
            local elapsed = math.max(0, time - previous.at)
            local loss = math.max(0, previous.hp - hp)
            value.debt = previous.debt * math.exp(-math.min(60, elapsed) / 4) + loss
            if loss > 0 then
              value.shock, value.lossAt = loss, time
              if previous.lossAt and time - previous.lossAt < 8 and previous.shock > loss then
                value.shock, value.lossAt = previous.shock, previous.lossAt
              end
            elseif previous.lossAt and time - previous.lossAt < 8 then
              value.shock, value.lossAt = previous.shock, previous.lossAt
            end
          end
          history[id] = value
        end
      end
    end
    K.healthHistory = history
  end
end

local function mapExitList(roomId)
  local ok, exits = pcall(getRoomExits, roomId)
  local result = {}
  local seen = {}
  local function addExits(source)
    if type(source) ~= "table" then return end
    for direction, nextId in pairs(source) do
      nextId = tonumber(nextId)
      local key = tostring(direction) .. ":" .. tostring(nextId)
      local blocked = K.failedExits[tonumber(roomId)]
      local rejected = blocked and (blocked[normal(direction)] or blocked[directionCommands[normal(direction)]])
      if nextId and K.roomSet[nextId] and not seen[key] and not rejected then
        result[#result + 1] = { direction = tostring(direction), room = nextId }
        seen[key] = true
      end
    end
  end
  if ok then addExits(exits) end
  -- Dla obecnego pokoju pakiet GMCP bywa swiezszy niz zapis mapy Mudleta.
  -- Uzupelniamy nim chwilowo brakujace lub opoznione polaczenia.
  if tonumber(roomId) == currentRoom() then
    local live = gmcp and gmcp.Room and gmcp.Room.Info and gmcp.Room.Info.exits
    addExits(live)
  end
  -- Losowa kolejnosc daje losowy wybor sposrod jednakowo bliskich pokoi.
  for i = #result, 2, -1 do
    local j = math.random(i)
    result[i], result[j] = result[j], result[i]
  end
  return result
end

local function adjacentExitList(roomId)
  local ok, exits = pcall(getRoomExits, roomId)
  local result = {}
  if not ok or type(exits) ~= "table" then return result end
  for direction, nextId in pairs(exits) do
    local command = directionCommands[normal(direction)] or normal(direction)
    nextId = tonumber(nextId)
    if nextId and inverseDirections[command] then
      result[#result + 1] = { direction = command, room = nextId }
    end
  end
  for i = #result, 2, -1 do
    local j = math.random(i)
    result[i], result[j] = result[j], result[i]
  end
  return result
end

-- Najkrotsza trasa do najblizszego jeszcze nieodwiedzonego pokoju. BFS porusza
-- sie wylacznie po pokojach nalezacych do wybranego obszaru.
local function routeToNearestUnvisited(start)
  local queue, head = { start }, 1
  local previous = { [start] = false }
  local via = {}
  local destination

  while head <= #queue do
    local room = queue[head]
    head = head + 1
    if room ~= start and not K.visited[room] then
      destination = room
      break
    end
    for _, edge in ipairs(mapExitList(room)) do
      if previous[edge.room] == nil then
        previous[edge.room] = room
        via[edge.room] = edge.direction
        queue[#queue + 1] = edge.room
      end
    end
  end

  if not destination then return nil end
  local reverse = {}
  local cursor = destination
  while cursor ~= start do
    reverse[#reverse + 1] = { direction = via[cursor], room = cursor }
    cursor = previous[cursor]
  end
  local route = {}
  for i = #reverse, 1, -1 do route[#route + 1] = reverse[i] end
  return route
end

local function hasUnvisited()
  for _, id in ipairs(K.rooms) do
    if not K.visited[id] then return true end
  end
  return false
end

local function markCurrentRoom()
  local room = currentRoom()
  if room and K.roomSet[room] then K.visited[room] = true end
  K.lastRoom = room or K.lastRoom
  return room
end

local function clearTarget(keepRecent)
  cancelTimer("focusTimer")
  cancelTimer("targetLostTimer")
  cancelTimer("killConfirmTimer")
  K.focusRetryPending = false
  K.focusAttempts, K.focusEvidence = 0, nil
  K.currentTargetId = nil
  K.currentTargetName = nil
  K.currentTargetAnimal = nil
  K.currentTargetAmbiguous, K.pendingKill = false, nil
  if not keepRecent then K.recentTarget = nil end
end

local function resetPursuit()
  K.pursuitOriginRoom = nil
  K.pursuitTrail = {}
  K.pursuitLeftArea = false
  K.returnCommands = nil
  K.returnFallbackCommands = nil
  K.returnFallbackIndex = 1
  K.returnUsedMap = false
  K.returnIndex = 1
  K.returnSteps = 0
end

local function resetPanicSearch()
  K.panicCenter = nil
  K.panicExits = nil
  K.panicIndex = 1
  K.panicPhase = nil
  cancelTimer("panicTimer")
end

local function ensurePursuitOrigin()
  if not K.pursuitOriginRoom then
    K.pursuitOriginRoom = currentRoom()
    K.pursuitTrail = {}
    K.pursuitLeftArea = false
  end
end

local patrolStep
local inspectRoom
local sendRecoveryReturnAttempt
local finishEscapeTail
local needsBurstReserve

local function restartPatrolWhenReady(kind)
  if not K.enabled or isFollower() then return end
  local wasPending = K.restartPending
  K.restartPending = kind
  if K.sessionBlocked or not K.entitiesReady or K.roomChangePending
      or currentRoom() ~= tonumber(K.config.startRoom) then
    if not wasPending then K.metrics.restartWaits = K.metrics.restartWaits + 1 end
    return
  end
  local own = groupContext().self
  local vitals = gmcp and gmcp.Char and gmcp.Char.Vitals
  if not own or not (healthPercent(own) or (K.sessionFresh.vitals and healthPercent(vitals))) then
    if not wasPending then K.metrics.restartWaits = K.metrics.restartWaits + 1 end
    return
  end
  if kind == "recovery" then
    local arrival = K.recoveryArrival
    if not arrival or arrival.room ~= currentRoom() then
      arrival = {room=currentRoom()}
      K.recoveryArrival = arrival
      -- Encje i relacje walki moga nadejsc w osobnych pakietach. Jeden
      -- krotki timer zbiera ten sam pakiet przybycia przed wznowieniem.
      later("recoveryTimer", K.config.actionDelay, function()
        if K.recoveryArrival ~= arrival then return end
        arrival.ready = true
        restartPatrolWhenReady("recovery")
      end)
    end
    if not arrival.ready then return end
  end
  K.restartPending = nil
  cancelTimer("recoveryTimer")
  if kind == "recovery" then
    updateVitals()
    if not K.recoveryReadiness() then
      K.escapeTailSent = false
      note("Po powrocie druzyna wymaga dalszego odpoczynku. Sprawdzam bezpieczenstwo miejsca.", "yellow")
      finishEscapeTail()
      return
    end
  end
  resetPursuit()
  if kind == "idle" then
    note("Dotarlem do pokoju startowego " .. K.config.startRoom .. ". Wznawiam patrol ze swiezych danych.", "green")
  end
  K.start(kind == "recovery")
end

local function finishRecoveryReturn()
  restartPatrolWhenReady("recovery")
end

sendRecoveryReturnAttempt = function()
  if not K.enabled or isFollower() or K.mode ~= "recovery_return" then return end
  if currentRoom() == tonumber(K.config.startRoom) then
    finishRecoveryReturn()
    return
  end
  K.recoveryAttempts = (K.recoveryAttempts or 0) + 1
  if K.recoveryAttempts > K.config.escapeMaxAttempts then
    K.stop(string.format(
      "Nie udalo sie wrocic przez /idz do pokoju startowego %d po leczeniu.",
      K.config.startRoom
    ))
    return
  end
  note(string.format(
    "Powrot po leczeniu przez /idz %d: proba %d/%d.",
    K.config.startRoom, K.recoveryAttempts, K.config.escapeMaxAttempts
  ), "green")
  expandAlias("/idz " .. K.config.startRoom)
  later("recoveryTimer", K.config.escapeRetryDelay, sendRecoveryReturnAttempt)
end

local function escapeDestination()
  return K.refugeRoom or tonumber(K.config.startRoom)
end

local function scheduleHealingCheck()
  later("healTimer", 3.0, function()
    updateVitals()
    if not K.enabled or isFollower() or K.mode ~= "heal_rest" then return end
    if K.checkRecoveryThreat(false) then return end
    if K.recoveryReadiness() then
      K.recoveryEmergency = nil
      K.mode = "recovery_return"
      K.recoveryAttempts = 0
      note("Druzyna gotowa po odpoczynku. Wracam przez /idz do startu patrolu.", "green")
      sendRecoveryReturnAttempt()
    else
      -- GMCP wystarcza do biezacej kontroli. Pytamy tekstowo tylko wtedy,
      -- gdy przez 15 s nie otrzymalismy kolejnej aktualizacji HP.
      if K.healingVitalsRevision ~= K.vitalsRevision then
        K.healingVitalsRevision, K.healPollTicks = K.vitalsRevision, 0
      end
      K.healPollTicks = (K.healPollTicks or 0) + 1
      local ownTarget = K.recoveryOwnCritical and 100 or K.config.recoveryHp
      if K.healPollTicks >= 5 and (not K.ownHealth
          or K.ownHealth.hp * 100 < K.ownHealth.maxhp * ownTarget) then
        send("kondycja", false)
        K.healPollTicks = 0
      end
      scheduleHealingCheck()
    end
  end)
end

finishEscapeTail = function()
  if isFollower() then return end
  if K.escapeTailSent then return end
  cancelTimer("escapeWatchTimer")
  K.escapeTailSent = true
  K.recoveryArrival = nil
  K.mode = "heal_rest"
  K.healPollTicks = 0
  updateVitals()
  K.recoveryReadiness()
  note("Jestem w miejscu leczenia. Czekam na cala druzyne: co najmniej "
    .. K.config.recoveryHp .. "% HP; stan krytyczny wymaga 100%.", "yellow")
  if K.config.equipmentHold then
    note("Po uzupelnieniu ekwipunku wpisz /kozojeb ekwipunek gotowy.", "yellow")
  end
  if K.checkRecoveryThreat(false) then return end
  scheduleHealingCheck()
end

local function sendEscapeAttempt()
  if not K.enabled or isFollower() or K.mode ~= "escape" then return end
  if K.recoveryEmergency then K.recoveryEmergencyStep() return end
  if K.movementRest then K.armMovementRest() return end
  if currentRoom() == escapeDestination() then
    finishEscapeTail()
    return
  end
  -- Chodzik moze juz odpoczywac po drodze. Znane zmeczenie nie jest
  -- nieudana proba trasy; nie uruchamiamy ponownie /idz co 12 sekund.
  if (K.escapeAttempts or 0) > 0 and K.movementKnown and K.lastMoves <= K.config.restAtMoves then
    later("escapeWatchTimer", K.config.escapeRetryDelay, sendEscapeAttempt)
    return
  end
  K.escapeAttempts = (K.escapeAttempts or 0) + 1
  if K.escapeAttempts > K.config.escapeMaxAttempts then
    K.stop(string.format(
      "Nie udalo sie dotrzec przez /idz do bazy %d po %d probach.",
      escapeDestination(), K.config.escapeMaxAttempts
    ))
    return
  end
  note(string.format(
    "Proba dojscia do bazy %d: %d/%d.",
    escapeDestination(), K.escapeAttempts, K.config.escapeMaxAttempts
  ), "yellow")
  expandAlias("/idz " .. escapeDestination())
  later("escapeWatchTimer", K.config.escapeRetryDelay, sendEscapeAttempt)
end

function K.escape(reason, injuredTeamMember)
  -- Kazda droga do odwrotu, takze tekstowe triggery "ranny" i "niemoc",
  -- konczy sie tutaj. Wspierajacy nigdy nie uruchamiaja wlasnego /idz,
  -- leczenia ani powrotu. Decyzje dla druzyny podejmuje prowadzacy.
  if isFollower() then return end
  if K.mode == "escape" or K.mode == "heal_rest" or K.mode == "recovery_return" then
    K.checkRecoveryThreat(false)
    return
  end
  updateVitals()
  K.recoveryCritical, K.recoveryOwnCritical, K.recoveryWaiters = {}, false, nil
  K.recoveryRoster = {}
  for name, member in pairs(K.moveSnapshot and K.moveSnapshot.roster or K.teamStep and K.teamStep.roster or {}) do
    K.recoveryRoster[name] = member.name
  end
  for name, member in pairs(K.movementRest and K.movementRest.roster or {}) do
    K.recoveryRoster[name] = member.name
  end
  -- Pilny odwrot ma pierwszenstwo przed zbieraniem druzyny. Wlasna
  -- potwierdzona niemoc nadal wymaga swiezego odczytu sil do ruchu.
  if K.movementRest and not K.movementRest.ownRejected then K.movementRest = nil end
  for _, member in ipairs(groupContext().members) do
    if not isSelf(member) then K.recoveryRoster[normal(member.name)] = trim(member.name) end
  end
  K.enabled = true -- monitorujemy dojscie do bazy mimo zatrzymania patrolu
  K.mode = "escape"
  K.escapeOriginRoom = currentRoom()
  K.generation = K.generation + 1
  cancelAllTimers()
  K.moveSnapshot, K.teamStep = nil, nil
  K.route = nil
  clearTarget()
  resetPursuit()
  resetPanicSearch()
  K.escapeTailSent = false
  K.escapeAttempts = 0
  K.injuredTeamMember = injuredTeamMember and trim(injuredTeamMember) or nil
  K.rememberRecoveryWounds()
  if K.movementRest and K.armMovementRest then K.armMovementRest() end
  note((reason or "Awaryjny odwrot.") .. " Ide przez /idz " .. escapeDestination() .. ".", "red")
  if K.movementRest and K.tryResumeMovement then
    K.tryResumeMovement()
    if not K.movementRest then return end
  end
  if currentRoom() == escapeDestination() then
    finishEscapeTail()
    return
  end
  sendEscapeAttempt()
end

local function combatIsActive()
  local state = combatState()
  if state.primary and tostring(state.primary) ~= "" then return true end
  return type(state.relations) == "table" and next(state.relations) ~= nil
end

local function shieldNameForm(name)
  local lowered = normal(name)
  -- Mianownik nie jest poprawnym domyslnym biernikiem: np. morrid/morrida.
  -- Nie zgadujemy odmiany nowej postaci na podstawie koncowki imienia.
  return K.config.shieldNameForms[lowered] or nil
end

local function shieldDisplayName(name)
  local form = shieldNameForm(name)
  return form and form:gsub("^%l", string.upper) or ("gracza: " .. trim(name))
end

local function pressure(count)
  return count * (1 + math.max(0, count - 1) * 0.5)
end

local function combatSnapshot()
  if K.combatCache then return K.combatCache end
  local snapshot = {incoming={}, owners={}}
  local edges = {}
  local index = entityIndex()
  for _, relation in ipairs(combatState().relations or {}) do
    local attacker, defender = index[tostring(relation.attacker)], index[tostring(relation.defender)]
    if attacker and defender and (liveNpc(attacker) or liveNpc(defender)) then
      edges[tostring(relation.attacker) .. ">" .. tostring(relation.defender)] = true
    end
    if liveNpc(attacker) and defender and defender.kind ~= "npc" then
      local npc, player = tostring(attacker.id), tostring(defender.id)
      local incoming = snapshot.incoming[player] or {count=0, npcs={}}
      if not incoming.npcs[npc] then incoming.count = incoming.count + 1 end
      incoming.npcs[npc] = attacker
      snapshot.incoming[player] = incoming
      local owners = snapshot.owners[npc] or {}
      owners[player] = true
      snapshot.owners[npc] = owners
    end
  end
  local signature = {}
  for edge in pairs(edges) do signature[#signature + 1] = edge end
  table.sort(signature)
  snapshot.signature = tostring(combatState().primary or "") .. "|" .. table.concat(signature, ",")
  for id, transfer in pairs(K.shieldTransfers) do
    if not snapshot.owners[id] or transfer.untilTime <= now() then K.shieldTransfers[id] = nil end
  end
  -- Porownujemy rzeczywiste zmiany NPC -> gracz, nie opis/imie NPC.
  -- Wielu obroncow (np. atak obszarowy) nie jest pojedynczym przejeciem.
  if K.transferRevision ~= K.combatRevision then
    local time, transfers = now(), {}
    for npc, owners in pairs(snapshot.owners) do
      local previous = K.previousIncoming and K.previousIncoming[npc]
      local target = next(owners)
      local origin = previous and next(previous)
      local old = K.shieldTransfers[npc]
      if old and old.untilTime > time then transfers[npc] = old end
      if origin and target and origin ~= target
          and next(owners, target) == nil and next(previous, origin) == nil then
        transfers[npc] = {from=origin, to=target, untilTime=time + K.config.shieldHold}
      end
    end
    K.shieldTransfers = transfers
    K.previousIncoming, K.transferRevision = snapshot.owners, K.combatRevision
  end
  K.metrics.combat = K.metrics.combat + 1
  K.combatCache = snapshot
  return snapshot
end

local function incomingNpc(entity)
  if not entity or not entity.id or not K.entitiesReady then return nil end
  local incoming = combatSnapshot().incoming[tostring(entity.id)]
  if incoming then
    local _, npc = next(incoming.npcs)
    return npc
  end
end

local function shieldHealthPair(own, target)
  local context = groupContext()
  local ownGroup = context.memberVitals[tostring(own.id)] or context.memberVitals[normal(own.name)]
  local targetGroup = context.memberVitals[tostring(target.id)] or context.memberVitals[normal(target.name)]
  local ownRaw, targetRaw = own, target
  if K.sourceRevisions.group > K.sourceRevisions.entities
      and healthPair(ownGroup) and healthPair(targetGroup) then
    ownRaw, targetRaw = ownGroup, targetGroup
  end
  local ownHp, ownMax = healthPair(ownRaw)
  local targetHp, targetMax = healthPair(targetRaw)
  if not ownHp or not targetHp then
    ownRaw, targetRaw = ownGroup, targetGroup
    ownHp, ownMax = healthPair(ownRaw)
    targetHp, targetMax = healthPair(targetRaw)
  end
  if not ownHp or not targetHp then return nil end
  -- Obie pule punktow pochodza z tego samego kanalu. Char.Vitals moze
  -- miec inna skale; jego procent sluzy tylko do ostroznego obnizenia HP.
  local latestOwn, latestTarget = latestHealth(own, ownGroup), latestHealth(target, targetGroup)
  if latestOwn then ownHp = ownMax * latestOwn.hp / latestOwn.maxhp end
  if isSelf(own) then ownHp = math.min(ownHp, ownMax * K.lastHp / 100) end
  if latestTarget then targetHp = targetMax * latestTarget.hp / latestTarget.maxhp end
  local function reserve(entity, hp, maximum)
    local history = K.healthHistory[tostring(entity.id)]
    if history and history.maxhp == maximum and history.room == currentRoom() then
      local debt = history.debt * math.exp(-math.min(60, math.max(0, now() - history.at)) / 4)
      hp = hp - math.min(hp * 0.5, debt * 0.5)
    end
    return math.max(0.01, hp)
  end
  return reserve(own, ownHp, ownMax), reserve(target, targetHp, targetMax), ownHp, targetHp
end

local function shieldProjection(own, target, percent)
  if not own or not own.id or not target.id then return nil, "Brak identyfikatorow graczy" end
  local snapshot = combatSnapshot()
  local ownId, targetId = tostring(own.id), tostring(target.id)
  local ownIncoming = snapshot.incoming[ownId] or {count=0, npcs={}}
  local targetIncoming = snapshot.incoming[targetId]
  if not targetIncoming or targetIncoming.count == 0 then return nil, "Brak napastnika NPC" end
  local ownBudget, targetBudget, ownHp, targetHp = shieldHealthPair(own, target)
  if not ownBudget then return nil, "Brak porownywalnych HP w punktach" end
  local before = math.max(pressure(ownIncoming.count) / ownBudget,
    pressure(targetIncoming.count) / targetBudget)
  local afterCount, reverse = ownIncoming.count, false
  for id in pairs(targetIncoming.npcs) do
    if not ownIncoming.npcs[id] then afterCount = afterCount + 1 end
    local transfer = K.shieldTransfers[id]
    if transfer and transfer.untilTime > now() and transfer.from == ownId and transfer.to == targetId then
      reverse = true
    end
  end
  if afterCount > K.config.shieldMaxAttackers then
    return nil, "Limit napastnikow przy przejeciu wszystkich: " .. afterCount
  end
  -- Komenda wskazuje osobe, a wynik moze zaslonic przed "wrogami".
  -- Najwieksze obciazenie obroncy jest przy przejeciu wszystkich NPC;
  -- najwieksze pozostale obciazenie celu przy przejeciu jednego. Maksimum
  -- obu skrajnych wartosci obejmuje kazdy podzbior, bez jego enumeracji.
  local ownAfter = pressure(afterCount) / ownBudget
  local worstAfter = math.max(ownAfter, pressure(targetIncoming.count - 1) / targetBudget)
  if worstAfter > before * 0.85 then return nil, "Za maly zapas obrony po zaslonie" end
  if reverse and percent >= math.min(100, K.config.escapeHp + 15) and worstAfter > before * 0.60 then
    return nil, "Stabilizacja po przejeciu NPC"
  end
  return {ownHp=ownHp, targetHp=targetHp, ownAttackers=ownIncoming.count,
    targetAttackers=targetIncoming.count, maxOwnAttackers=afterCount,
    riskAfter=worstAfter, ownAfterRisk=ownAfter}
end

local function shieldImprovesSafety(target, percent)
  local decision, reason = shieldProjection(groupContext().self, target, percent)
  if not decision then return false, reason end
  K.shieldDecision = decision
  return true
end

local function waitForFormation()
  cancelTimer("formationTimer")
  K.shieldFormationReady = false
  local token = {}
  K.formationToken = token
  -- Ten timer nie nalezy do generacji patrolu: restart bota nie moze
  -- uznac wykorzystanej zmiany szyku za ponownie dostepna.
  K.formationTimer = tempTimer(10.0, function()
    if K.formationToken ~= token then return end
    K.formationTimer, K.formationToken = nil, nil
    K.shieldFormationReady = true
    if K.enabled then queueInspection(inspectRoom) end
  end)
end

local function clearShieldTurn()
  cancelTimer("shieldTurnTimer")
  K.shieldTurn = nil
end

local function armShieldReply(seconds, callback)
  cancelTimer("shieldReplyTimer")
  local token = {}
  K.shieldReplyToken = token
  -- Rezerwacja szyku, tak jak formationTimer, przezywa stop/start bota.
  -- Wygasniecie nigdy nie uruchamia zatrzymanego profilu.
  K.shieldReplyTimer = tempTimer(seconds, function()
    if K.shieldReplyToken ~= token then return end
    K.shieldReplyTimer, K.shieldReplyToken = nil, nil
    callback()
    if K.enabled then queueInspection(inspectRoom) end
  end)
end

local function shieldTargetRatio(entity)
  if not entity then return nil end
  local context = groupContext()
  local value = latestHealth(entity, context.memberVitals[tostring(entity.id)]
    or context.memberVitals[normal(entity.name)])
  return value and value.hp / value.maxhp
end

local function sameShieldIncoming(record)
  local incoming = combatSnapshot().incoming[record.id]
  if not incoming or incoming.count ~= record.count then return false end
  for id in pairs(incoming.npcs) do if not record.npcs[id] then return false end end
  return true
end

local function shieldRescueInFlight(entity, hp)
  if not entity then return false end
  local id = tostring(entity.id)
  local record = K.shieldRescue
  if not record or record.id ~= id then
    record = not isFollower() and K.teamShieldNotices[id] or nil
  end
  if not record or not record.ratio then return false end
  local ratio = shieldTargetRatio(entity)
  if record.room ~= currentRoom() or now() >= record.deadline
      or not hp or hp < K.config.teamEscapeHp or not ratio
      or (ratio < record.ratio - 0.000000001 and needsBurstReserve(entity, hp, K.config.teamEscapeHp, true))
      or not sameShieldIncoming(record) then
    if K.shieldRescue == record then K.shieldRescue = nil
    else K.teamShieldNotices[id] = nil end
    return false
  end
  return true
end

local function armShieldPosition()
  cancelTimer("shieldPositionTimer")
  local deadline
  for form, untilTime in pairs(K.shieldPositionUntil) do
    if untilTime <= now() then K.shieldPositionUntil[form] = nil
    else deadline = math.min(deadline or untilTime, untilTime) end
  end
  local token = {}
  K.shieldPositionToken = token
  if deadline then
    K.shieldPositionTimer = tempTimer(math.max(0, deadline - now()), function()
      if K.shieldPositionToken ~= token then return end
      K.shieldPositionTimer = nil
      armShieldPosition()
      if K.enabled then queueInspection(inspectRoom) end
    end)
  end
end

function K.onShieldPositionBlocked(form)
  form = normal(form)
  local pending = K.shieldPendingTarget
  if not pending or normal(pending.form) ~= form then return end
  -- Gra nie podaje terminu odzyskania pozycji. Stosujemy ograniczony
  -- 10-sekundowy odstep dla tej osoby, niezalezny od gotowosci szyku.
  if not K.shieldPositionUntil[form] or K.shieldPositionUntil[form] <= now() then
    K.shieldPositionUntil[form] = now() + 10
  end
  K.shieldPendingTarget, K.shieldRescue, K.shieldReplyToken = nil, nil, nil
  cancelTimer("shieldReplyTimer")
  if not pending.conflicted then
    K.shieldFormationReady, K.formationToken = true, nil
    cancelTimer("formationTimer")
  end
  clearShieldTurn()
  armShieldPosition()
  if K.enabled then queueInspection(inspectRoom) end
end

local function reserveShieldRequest(entity, form, external)
  clearShieldTurn()
  local incoming = entity and combatSnapshot().incoming[tostring(entity.id)]
  local record = {name=entity and trim(entity.name), form=form,
    id=entity and tostring(entity.id), room=currentRoom(), combatRevision=K.combatRevision,
    ratio=shieldTargetRatio(entity), count=incoming and incoming.count or 0,
    npcs=incoming and incoming.npcs or {}, deadline=now() + 2, external=external}
  K.shieldPendingTarget = record
  K.shieldRescue = record.ratio and record.count > 0 and record or nil
  waitForFormation()
  armShieldReply(2.0, function()
    if K.shieldPendingTarget == record then K.shieldPendingTarget = nil end
    if K.shieldRescue == record then K.shieldRescue = nil end
  end)
  return record
end

function K.onShieldCommand(_, command)
  -- Obserwujemy tylko zaslony; inne wysylane polecenia nie sa zapisywane.
  if K.sendingShield or type(command) ~= "string" or #command < 8 or #command > 128 then return end
  local form = command:match("^%s*[Zz][Aa][Ss][Ll][Oo][Nn]%s+([%a%-]+)%s*$")
  if not form or K.sessionBlocked then return end
  form = normal(form)
  clearShieldTurn()
  if K.shieldPendingTarget then
    -- Nie blokujemy recznych komend. Nakladajace sie zadania nie moga jednak
    -- przedluzac ochronnego oczekiwania ani zwalniac szyku automatu.
    K.shieldPendingTarget.conflicted = true
    K.shieldRescue = nil
    waitForFormation()
    return
  end
  local target
  if K.entitiesReady then
    for _, member in ipairs(groupContext().members) do
      if shieldNameForm(member.name) == form or normal(member.name) == form then target = member break end
    end
  end
  reserveShieldRequest(target, form, true)
end

local function deferShield(entity, kind, deadline)
  local turn = K.shieldTurn
  if turn and turn.id == tostring(entity.id) and turn.room == currentRoom()
      and turn.kind == kind and sameShieldIncoming(turn) then
    return now() < turn.deadline
  end
  clearShieldTurn()
  local incoming = combatSnapshot().incoming[tostring(entity.id)]
  turn = {id=tostring(entity.id), room=currentRoom(), kind=kind, deadline=deadline,
    count=incoming and incoming.count or 0, npcs=incoming and incoming.npcs or {}}
  K.shieldTurn = turn
  later("shieldTurnTimer", math.max(0, deadline - now()), function()
    if K.enabled and K.shieldTurn == turn and currentRoom() == turn.room then inspectRoom() end
  end)
  return true
end

local function shieldTurnRank(entity, percent)
  local context = groupContext()
  local own = context.self
  if not own then return 0 end
  local function score(member)
    local health = latestHealth(member, context.memberVitals[tostring(member.id)]
      or context.memberVitals[normal(member.name)])
    if not health or health.hp <= 0 or health.percent < K.config.shieldSelfHp then return nil end
    return shieldProjection(member, entity, percent)
  end
  local ownScore, rank = score(own), 0
  if not ownScore then return 0 end
  for _, member in ipairs(context.members) do
    if not isSelf(member) and tostring(member.id) ~= tostring(entity.id) then
      local other = score(member)
      local equalRisk = other and math.abs(other.riskAfter - ownScore.riskAfter) <= 0.000000000001
      if other and (other.riskAfter < ownScore.riskAfter - 0.000000000001
          or (equalRisk and other.ownAfterRisk < ownScore.ownAfterRisk - 0.000000000001)
          or (equalRisk and math.abs(other.ownAfterRisk - ownScore.ownAfterRisk) <= 0.000000000001
            and tostring(member.id) > tostring(own.id))) then
        rank = rank + 1
      end
    end
  end
  -- Prowadzacy i wspierajacy korzystaja z tej samej oceny. Nie zakladamy,
  -- ze inne profile maja role zaslon. Po ograniczonej kolejce
  -- ten profil moze dzialac sam, jesli nikt wczesniej nie przejal NPC.
  return math.min(3, rank)
end

local function armTeamShieldNotices()
  local deadline
  for id, notice in pairs(K.teamShieldNotices) do
    if notice.deadline <= now() or notice.room ~= currentRoom() then K.teamShieldNotices[id] = nil
    else deadline = math.min(deadline or notice.deadline, notice.deadline) end
  end
  if K.teamShieldTimer and K.teamShieldDeadline == deadline then return end
  cancelTimer("teamShieldTimer")
  K.teamShieldDeadline = deadline
  if deadline then
    later("teamShieldTimer", math.max(0, deadline - now()), function()
      armTeamShieldNotices()
      if K.enabled then queueInspection(inspectRoom) end
    end)
  end
end

function K.onTeamShield(actor, form)
  if not K.enabled or K.config.role == "wsparcie" or not K.entitiesReady then return end
  local context = groupContext()
  if isFollower() and not context.leader then return end
  local protector, target
  for _, member in ipairs(context.members) do
    if not isSelf(member) and normal(member.name) == normal(actor) then protector = member break end
  end
  if not protector then return end
  for _, member in ipairs(context.members) do
    if not isSelf(member) and (normal(member.name) == normal(form) or shieldNameForm(member.name) == normal(form)) then
      target = member break
    end
  end
  if not target or tostring(target.id) == tostring(protector.id) then return end
  local snapshot = combatSnapshot()
  local incoming = snapshot.incoming[tostring(target.id)]
  if not incoming then return end
  for _, transfer in pairs(K.shieldTransfers) do
    if transfer.from == tostring(target.id) and transfer.to == tostring(protector.id)
        and transfer.untilTime > now() + K.config.shieldHold - 0.5 then return end
  end
  for id, notice in pairs(K.teamShieldNotices) do
    if notice.deadline <= now() or notice.room ~= currentRoom() or not entityById(id) then K.teamShieldNotices[id] = nil end
  end
  local previous = K.teamShieldNotices[tostring(target.id)]
  local deadline = previous and sameShieldIncoming(previous) and previous.deadline or now() + 0.5
  K.teamShieldNotices[tostring(target.id)] = {id=tostring(target.id), count=incoming.count, npcs=incoming.npcs,
    ratio=shieldTargetRatio(target), room=currentRoom(), deadline=deadline}
  armTeamShieldNotices()
  queueInspection(inspectRoom)
end

local function tryShield(entity, hp, threshold)
  if not K.enabled or threshold <= 0 or K.shieldTimer or K.shieldPendingTarget
      or not K.shieldFormationReady then clearShieldTurn() return end
  if K.shieldAwaitCombatRevision == K.combatRevision then clearShieldTurn() return end
  if not hp or hp >= threshold or K.lastHp <= 0 or K.lastHp < K.config.shieldSelfHp then clearShieldTurn() return end
  if not incomingNpc(entity) then clearShieldTurn() return end
  local improves, reason = shieldImprovesSafety(entity, hp)
  if not improves then
    clearShieldTurn()
    K.shieldBlockedReason = reason
    K.metrics.shieldBlocked = K.metrics.shieldBlocked + 1
    return
  end
  local target = trim(entity.name)
  if target == "" or target == "ty" or target == "brak wykrytej druzyny" then return end
  local key = normal(target)
  local form = shieldNameForm(target)
  if not form then
    if not K.shieldMissingForms[key] then
      K.shieldMissingForms[key] = true
      note("Brak biernika imienia " .. target .. ". Ustaw /kozojeb imie " .. target .. " <biernik>.", "yellow")
    end
    return
  end
  if K.shieldRejectedForms[key] == form then return end
  if (K.shieldPositionUntil[form] or 0) > now() then
    clearShieldTurn()
    K.shieldBlockedReason = "Odzyskiwanie pozycji przed " .. form
    return
  end
  local notice = K.teamShieldNotices[tostring(entity.id)]
  local urgentHp = isFollower() and K.config.escapeHp or K.config.teamEscapeHp
  if hp > urgentHp and not needsBurstReserve(entity, hp, urgentHp, true) then
    if notice and notice.id == tostring(entity.id) and notice.room == currentRoom()
        and now() < notice.deadline and sameShieldIncoming(notice) then
      if deferShield(entity, "notice", notice.deadline) then return false, true end
    else
      K.teamShieldNotices[tostring(entity.id)] = nil
      if K.shieldTurn and K.shieldTurn.kind == "notice" then clearShieldTurn() end
    end
    local rank = shieldTurnRank(entity, hp)
    if rank > 0 then
      if deferShield(entity, "rank", now() + rank * 0.45) then return false, true end
    else clearShieldTurn() end
  else clearShieldTurn() end
  K.shieldLastTarget = target
  reserveShieldRequest(entity, form, false)
  K.shieldBlockedReason = nil
  local decision = K.shieldDecision
  note(string.format(
    "Zaslaniam %s (%d%% HP, prog %d%%; moje %.0f HP / %d napastnikow, cel %.0f HP / %d; po zaslonie do %d).",
    form:gsub("^%l", string.upper), hp, threshold,
    decision.ownHp, decision.ownAttackers, decision.targetHp, decision.targetAttackers, decision.maxOwnAttackers
  ), "yellow")
  -- Rezerwacja przed send chroni tez przed pakietami/odpowiedziami
  -- przychodzacymi bezposrednio podczas wykonania polecenia.
  later("shieldTimer", K.config.teamShieldInterval, function() end)
  K.sendingShield = true
  send("zaslon " .. form)
  K.sendingShield = nil
  K.metrics.shields = K.metrics.shields + 1
  touchActivity()
  return true
end

function K.onShieldRejected()
  local pending = K.shieldPendingTarget
  if not pending then return end
  if not pending.external then K.shieldRejectedForms[normal(pending.name)] = pending.form end
  K.shieldPendingTarget, K.shieldRescue, K.shieldReplyToken = nil, nil, nil
  cancelTimer("shieldReplyTimer")
  -- Odrzucona nazwa nie zuzywa zmiany szyku.
  if pending.conflicted then waitForFormation()
  else
    K.shieldFormationReady = true
    K.formationToken = nil
    cancelTimer("formationTimer")
  end
  if not pending.external then
    note("Gra nie rozpoznala 'zaslon " .. pending.form .. "'. Sprawdz /kozojeb imie "
      .. pending.name .. " <biernik>. Ta forma nie bedzie ponawiana do poprawki.", "red")
  end
end

function K.onShieldCooldown()
  K.shieldPendingTarget, K.shieldRescue, K.shieldReplyToken = nil, nil, nil
  cancelTimer("shieldReplyTimer")
  waitForFormation()
  if K.enabled then queueInspection(inspectRoom) end
end

function K.onShieldResult(form, succeeded)
  local pending = K.shieldPendingTarget
  local requestedRevision
  if pending and normal(pending.form) == normal(form) then
    requestedRevision = pending.combatRevision
    K.shieldPendingTarget = nil
    cancelTimer("shieldReplyTimer")
    K.shieldReplyToken = nil
    if succeeded and not pending.conflicted and pending.ratio and pending.count > 0 then
      pending.deadline = math.min(pending.deadline, now() + 0.5)
      K.shieldRescue = pending
      armShieldReply(math.max(0, pending.deadline - now()), function()
        if K.shieldRescue == pending then K.shieldRescue = nil end
      end)
    else K.shieldRescue = nil end
  elseif pending then
    K.shieldRescue = nil
  end
  waitForFormation()
  if succeeded then
    -- Nowy pakiet moze przyjsc zarowno przed, jak i po tekscie sukcesu.
    -- Liczymy od chwili wyslania polecenia, aby nie zgubic juz odebranej
    -- zmiany celu i moc zaslonic przed kolejnym NPC po odzyskaniu szyku.
    K.shieldAwaitCombatRevision = requestedRevision
    K.shieldFailure = nil
  elseif pending and pending.id and normal(pending.form) == normal(form) then
    K.shieldFailure = {id=pending.id, name=pending.name, at=now(), room=currentRoom()}
  end
  if K.enabled then queueInspection(inspectRoom) end
end

function K.onFormationReady()
  if K.shieldPendingTarget and now() < K.shieldPendingTarget.deadline then return end
  K.shieldFormationReady = true
  K.formationToken = nil
  cancelTimer("formationTimer")
  if K.enabled then queueInspection(inspectRoom) end
end

local function shieldPositionReady(entity)
  return (K.shieldPositionUntil[shieldNameForm(entity.name) or ""] or 0) <= now()
end

local function maybeShieldTeamMember(coverOnly)
  local follower = isFollower()
  if (follower and K.config.role ~= "zaslony") or not K.entitiesReady
      or not combatIsActive() or K.teamSeenCount <= 0 then return end
  local candidates = {}
  local context, snapshot = groupContext(), combatSnapshot()
  local own, leader = context.self, context.leader
  for _, entity in ipairs(context.members) do
    local hp = K.teamHealth[normal(entity.name)]
    local incoming = snapshot.incoming[tostring(entity.id)]
    local isLeader = leader and tostring(leader.id) == tostring(entity.id)
    local threshold = follower and isLeader and K.config.leaderShieldHp or K.config.teamShieldHp
    local blockedByDeath = follower and isLeader and K.supportDeathBarrier
    if own and not isSelf(entity) and hp and hp > 0 and hp < threshold and incoming and not blockedByDeath then
      local _, reserve = shieldHealthPair(own, entity)
      candidates[#candidates + 1] = {entity=entity, hp=hp, threshold=threshold,
        risk=reserve and pressure(incoming.count) / reserve or math.huge}
    end
  end
  table.sort(candidates, function(a, b)
    if a.risk ~= b.risk then return a.risk > b.risk end
    if a.hp ~= b.hp then return a.hp < b.hp end
    return tostring(a.entity.id) < tostring(b.entity.id)
  end)
  for _, candidate in ipairs(candidates) do
    if not shieldRescueInFlight(candidate.entity, candidate.hp) then
      local sent, waiting = tryShield(candidate.entity, candidate.hp, candidate.threshold)
      if sent or waiting then return end
      local guard = math.min(K.config.teamShieldHp - 1, K.config.teamEscapeHp + 15)
      if not coverOnly and K.config.teamEscapeHp > 0 and candidate.hp < guard then
        local safe = shieldImprovesSafety(candidate.entity, candidate.hp)
        if not K.shieldFormationReady or not shieldPositionReady(candidate.entity) or not safe then
          K.escape("Nie moge bezpiecznie oslonic " .. shieldDisplayName(candidate.entity.name)
            .. " (" .. candidate.hp .. "% HP).", candidate.entity.name)
          return
        end
      end
    end
  end
  clearShieldTurn()
end

local function recoveryThreat()
  if not K.entitiesReady then return false end
  local members, snapshot = {}, combatSnapshot()
  for _, member in ipairs(groupContext().members) do
    local id = tostring(member.id)
    members[id] = true
    if snapshot.incoming[id] then return true end
  end
  local own = groupContext().self
  if own then
    members[tostring(own.id)] = true
    if liveNpc(entityById(combatState().primary)) then return true end
  end
  for _, relation in ipairs(combatState().relations or {}) do
    if members[tostring(relation.attacker)] and liveNpc(entityById(relation.defender)) then return true end
  end
  return false
end

function K.recoveryEmergencyStep()
  local emergency = K.recoveryEmergency
  if not K.enabled or isFollower() or K.sessionBlocked or not emergency or K.mode ~= "escape" then return end
  local room, pending = currentRoom(), emergency.pending
  if (pending and room ~= pending.from) or (not pending and room ~= emergency.room) then
    emergency.pending = nil
    emergency.room = room
    K.refugeRoom = room
    K.escapeTailSent = false
    finishEscapeTail()
    return
  end
  if pending then
    if now() < pending.deadline then return end
    -- Niepotwierdzony krok nie moze blokowac wyjscia na zawsze. Nie
    -- wysylamy go ponownie ani nie kasujemy cudzej nowszej proby ruchu.
    emergency.pending = nil
    if K.sentDirection == pending.direction and K.roomChangePending then
      K.roomChangePending, K.sentDirection, K.moveSnapshot = false, nil, nil
      K.entitiesReady = true
      K.failedExits[room] = K.failedExits[room] or {}
      K.failedExits[room][pending.direction] = true
    end
  end
  if not K.entitiesReady or K.roomChangePending then return end
  if K.movementRest then K.armMovementRest() return end
  if emergency.waitUntil and now() < emergency.waitUntil then return end
  local limit = math.max(1, math.min(3, K.config.escapeMaxAttempts))
  if emergency.attempts >= limit or emergency.searches >= limit then
    if not emergency.blocked then
      emergency.blocked = true
      note("Awaryjne wyjscie z zagrozonego miejsca nie powiodlo sie. Nadal chronie druzyne; sprawdz droge na mapie.", "red")
    end
    return
  end
  emergency.unsafe[room] = true
  local exits, selected, score = adjacentExitList(room), nil, math.huge
  for _, exit in ipairs(exits) do
    local rejected = K.failedExits[room] and K.failedExits[room][exit.direction]
    if exit.room ~= room and not emergency.unsafe[exit.room] and not rejected then
      local value = (K.roomSet[exit.room] and 2 or 0) + (exit.room == K.previousRoom and 1 or 0)
      if value < score or (value == score and (not selected or exit.room < selected.room)) then
        selected, score = exit, value
      end
    end
  end
  if not selected then
    emergency.searches = emergency.searches + 1
    emergency.waitUntil = now() + 3
    if not emergency.noExitNotice then
      emergency.noExitNotice = true
      note("Brak dostepnego zwyklego wyjscia na mapie. Chronie druzyne i ponowie odczyt mapy najwyzej trzy razy.", "red")
    end
    later("escapeWatchTimer", 3, K.recoveryEmergencyStep)
    return
  end
  emergency.attempts = emergency.attempts + 1
  emergency.pending = {from=room, destination=selected.room, direction=selected.direction,
    deadline=now() + K.config.escapeRetryDelay}
  note("Atak podczas leczenia. Wyprowadzam druzyne: " .. selected.direction
    .. " do pokoju " .. selected.room .. "; sprawdze swieze dane po kroku.", "red")
  sendDirection(selected.direction)
  later("escapeWatchTimer", K.config.escapeRetryDelay, K.recoveryEmergencyStep)
end

function K.rememberRecoveryWounds()
  K.recoveryCritical = K.recoveryCritical or {}
  if K.ownHealth and K.ownHealth.hp * 100 < K.ownHealth.maxhp * K.config.escapeHp then
    K.recoveryOwnCritical = true
  end
  local emergency = K.recoveryEmergency
  if emergency then emergency.wounded = emergency.wounded or {} end
  if K.config.teamEscapeHp > 0 then
    for name, value in pairs(K.teamVitals) do
      if value.hp * 100 < value.maxhp * K.config.teamEscapeHp then
        K.recoveryCritical[name] = true
        if emergency then emergency.wounded[name] = true end
      end
    end
  end
end

function K.recoveryReadiness()
  updateVitals()
  local blockers = {}
  K.recoveryMissing = nil
  local function block(name, label)
    blockers[#blockers + 1] = {name=name, label=label}
  end
  if K.sessionBlocked or not K.entitiesReady or K.roomChangePending then
    block("", "Czekam na swieze dane pokoju i postaci")
  else
    K.rememberRecoveryWounds()
    local context, visible = groupContext(), {}
    K.recoveryRoster = K.recoveryRoster or {}
    for _, member in ipairs(context.members) do
      if not isSelf(member) then
        local name = normal(member.name)
        visible[name] = true
        K.recoveryRoster[name] = trim(member.name)
      end
    end
    if K.injuredTeamMember then
      K.recoveryRoster[normal(K.injuredTeamMember)] = K.injuredTeamMember
    end
    for name, displayName in pairs(K.recoveryTired) do
      K.recoveryRoster[name] = K.recoveryRoster[name] or displayName
    end
    for name in pairs(K.recoveryCritical) do
      K.recoveryRoster[name] = K.recoveryRoster[name] or name:gsub("^%l", string.upper)
    end
    for name in pairs(K.recoveryEmergency and K.recoveryEmergency.wounded or {}) do
      K.recoveryCritical[name] = true
      K.recoveryRoster[name] = K.recoveryRoster[name] or name:gsub("^%l", string.upper)
    end
    local function checkHp(name, value, target, own)
      if not value then block(name, name .. ": brak odczytu HP")
      elseif value.hp * 100 < value.maxhp * target or (own and K.lastHp < target) then
        block(name, string.format("%s: %.1f%% / %d%% HP", name,
          math.min(value.hp * 100 / value.maxhp, own and K.lastHp or 100), target))
      end
    end
    local ownName = context.self and trim(context.self.name) or "Moja postac"
    local ownTarget = K.recoveryOwnCritical and 100
      or math.max(K.config.recoveryHp, math.ceil(K.config.escapeHp))
    checkHp(ownName, K.ownHealth, ownTarget, true)
    local names = {}
    for name in pairs(K.recoveryRoster) do names[#names + 1] = name end
    table.sort(names)
    for _, name in ipairs(names) do
      local displayName = K.recoveryRoster[name]
      if not visible[name] then
        block(displayName, displayName .. ": brak w pokoju")
        K.recoveryMissing = K.recoveryMissing or displayName
      else
        local target = K.recoveryCritical[name] and 100
          or math.max(K.config.recoveryHp, K.config.teamEscapeHp > 0 and math.floor(K.config.teamEscapeHp) + 1 or 0)
        checkHp(displayName, K.teamVitals[name], target)
        if not K.teamVitals[name] then K.recoveryMissing = K.recoveryMissing or displayName end
      end
    end
    if K.lastMoves < K.config.resumeAtMoves then
      block(ownName, string.format("%s: ruch %d%% / %d%%", ownName, K.lastMoves, K.config.resumeAtMoves))
    end
    for _, name in ipairs(names) do
      if K.recoveryTired[name] and (not K.teamMoves[name] or K.teamMoves[name] < K.config.resumeAtMoves) then
        local label = K.teamMoves[name] and string.format("%.0f%% / %d%%", K.teamMoves[name], K.config.resumeAtMoves)
          or "brak odczytu"
        block(K.recoveryRoster[name], K.recoveryRoster[name] .. ": ruch " .. label)
        K.recoveryMissing = K.recoveryMissing or K.recoveryRoster[name]
      end
    end
    if context.actualLeader and not isSelf(context.actualLeader) then block("", "Prowadzenie druzyny przejal inny gracz") end
    if recoveryThreat() then block("", "Druzyna nadal jest zaangazowana w walke") end
    if K.config.equipmentHold then block("", K.config.equipmentHold) end
    if K.movementRest then block("", K.movementRest.reason or "Czekam na potwierdzony odpoczynek") end
  end
  K.recoveryWaiters = blockers
  -- Zachowanie pola diagnostycznego dla skryptow korzystajacych ze starszych wersji.
  if not K.recoveryMissing and blockers[1] and blockers[1].name ~= "" then
    K.recoveryMissing = blockers[1].name
  end
  return #blockers == 0, blockers
end

function K.checkRecoveryThreat(urgentOnly)
  if not K.enabled or isFollower() or K.sessionBlocked then return false end
  local recovery = K.mode == "escape" or K.mode == "heal_rest" or K.mode == "recovery_return"
  if not recovery then return false end
  K.rememberRecoveryWounds()
  if not recoveryThreat() then
    if K.mode == "escape" and K.recoveryEmergency and not K.recoveryEmergency.pending
        and K.entitiesReady and K.combatRoomReady and not K.roomChangePending then
      K.refugeRoom = currentRoom()
      K.recoveryEmergency.room = currentRoom()
      K.escapeTailSent = false
      finishEscapeTail()
      return true
    end
    return false
  end
  local critical = K.lastHp < K.config.escapeHp or (K.config.teamEscapeHp > 0
    and K.teamSeenCount > 0 and K.teamLowestHp < K.config.teamEscapeHp)
  -- Podczas zwyklego odwrotu chodzik juz prowadzi poza zagrozenie.
  -- Nie uruchamiamy nowej trasy po kazdym ataku mijanego NPC.
  if K.mode == "escape" and not K.recoveryEmergency and currentRoom() ~= escapeDestination() then
    if not urgentOnly then maybeShieldTeamMember(true) end
    return false
  end
  if K.mode == "recovery_return" and not critical then
    if not urgentOnly then maybeShieldTeamMember(true) end
    return false
  end
  if K.mode == "recovery_return" and currentRoom() ~= escapeDestination() then
    cancelTimer("recoveryTimer")
    K.mode, K.escapeAttempts, K.escapeTailSent = "escape", 0, false
    note("Zagrozenie podczas powrotu po leczeniu. Ponownie wycofuje druzyne.", "red")
    sendEscapeAttempt()
    return true
  end
  if not K.recoveryEmergency then
    K.recoveryEmergency = {room=currentRoom(), attempts=0, searches=0, unsafe={}}
    if K.escapeOriginRoom then K.recoveryEmergency.unsafe[K.escapeOriginRoom] = true end
    K.rememberRecoveryWounds()
  end
  if K.mode ~= "escape" then
    cancelTimer("healTimer")
    cancelTimer("recoveryTimer")
    K.mode, K.escapeTailSent = "escape", false
    K.teamStep = nil
    cancelTimer("teamStepTimer")
    -- Zmeczenie bez faktycznej odmowy nie blokuje pilnego wyjscia.
    if K.movementRest and not K.movementRest.ownRejected then
      K.movementRest = nil
      cancelTimer("movementRestTimer")
    end
  end
  if not urgentOnly then maybeShieldTeamMember(true) end
  K.recoveryEmergencyStep()
  if urgentOnly and K.entitiesReady then queueInspection(inspectRoom) end
  return true
end

needsBurstReserve = function(entity, percent, threshold, anyLoss)
  if not entity or not percent or threshold <= 0 or not K.entitiesReady then return false end
  local history = K.healthHistory[tostring(entity.id)]
  if not history or history.room ~= currentRoom() or not history.lossAt
      or now() - history.lossAt >= 8 or (not anyLoss and history.shock < history.maxhp * 0.15) then return false end
  -- Jedna ostatnio obserwowana duza strata HP ponad prog odwrotu.
  -- Stala pamiec na gracza, bez analizy tekstu obrazen i odpytywania gry.
  if history.maxhp * percent / 100 - history.shock >= history.maxhp * threshold / 100 then return false end
  return incomingNpc(entity) ~= nil
end

local function safetyCheck(urgentOnly, skipMovementWait)
  updateVitals()
  if K.enabled and K.lastHp <= 0 then
    K.stop("Brak HP postaci. Zadanie zatrzymane; sprawdz stan w grze.")
    return false
  end
  -- Wspierajacy zachowuje role nawet przy niskim HP i ruchu. Prowadzacy
  -- ocenia HP i stany druzyny dotychczasowym mechanizmem.
  if isFollower() then return true end
  if K.enabled and not isFollower() and K.entitiesReady then
    local actualLeader = groupContext().actualLeader
    if actualLeader and not isSelf(actualLeader) then
      if K.mode ~= "leader_wait" then
        K.generation = K.generation + 1
        cancelAllTimers()
        clearTarget()
        resetPursuit()
        resetPanicSearch()
        K.route = nil
        K.mode = "leader_wait"
        note("Druzyne prowadzi " .. tostring(actualLeader.name)
          .. ". Wstrzymuje patrol; ustaw role wspierajaca albo przekaz prowadzenie w grze.", "yellow")
      end
      return false
    elseif K.mode == "leader_wait" then
      K.mode = "patrol"
    end
  end
  local recovery = K.mode == "escape" or K.mode == "heal_rest" or K.mode == "recovery_return"
  if K.enabled and recovery and K.checkRecoveryThreat(urgentOnly) then return false end
  local injuredTeamMember
  if not isFollower() and K.config.teamEscapeHp > 0 and K.teamSeenCount > 0
      and K.teamLowestHp < K.config.teamEscapeHp then
    injuredTeamMember = K.teamLowestName
  end
  if K.enabled and not recovery and K.lastHp < K.config.escapeHp then
    K.escape(string.format("HP spadlo do %d%% (prog %d%%).", K.lastHp, K.config.escapeHp), injuredTeamMember)
    return false
  end
  if K.enabled and not recovery and injuredTeamMember then
    K.escape(string.format(
      "HP druzyny: %s ma %d%% (prog %d%%).",
      K.teamLowestName, K.teamLowestHp, K.config.teamEscapeHp
    ), injuredTeamMember)
    return false
  end
  if K.enabled and not recovery and K.entitiesReady then
    local context = groupContext()
    if needsBurstReserve(context.self, K.lastHp, K.config.escapeHp) then
      K.escape("Brak rezerwy HP na kolejny ostatnio obserwowany silny cios.")
      return false
    end
    if K.config.teamEscapeHp > 0 then
      for _, member in ipairs(context.members) do
        local hp = K.teamHealth[normal(member.name)]
        if not isSelf(member) and needsBurstReserve(member, hp, K.config.teamEscapeHp) then
          local pending = shieldRescueInFlight(member, hp)
          local canShield = hp < K.config.teamShieldHp and K.lastHp >= K.config.shieldSelfHp
            and K.shieldFormationReady and shieldPositionReady(member) and shieldImprovesSafety(member, hp)
          if not pending and not canShield then
            K.escape("Brak rezerwy HP na kolejny silny cios: " .. tostring(member.name) .. ".", member.name)
            return false
          end
        end
      end
    end
  end
  if K.enabled and not recovery and K.config.teamEscapeHp > 0 and K.shieldFailure
      and K.shieldFailure.room == currentRoom() and now() - K.shieldFailure.at < 8 then
    local failure = K.shieldFailure
    local hp = K.teamHealth[normal(failure.name)]
    local guard = math.min(K.config.teamShieldHp - 1, K.config.teamEscapeHp + 15)
    if hp and hp < guard and incomingNpc(entityById(failure.id)) then
      K.escape("Nieudana zaslona; " .. failure.name .. " ma " .. hp .. "% HP.", failure.name)
      return false
    end
  end
  if K.enabled and not recovery and not K.movementRest and K.lastMoves <= K.config.restAtMoves then
    K.escape(string.format(
      "Niemoc: ruch spadl do %d%% (prog %d%%).",
      K.lastMoves, K.config.restAtMoves
    ))
    return false
  end
  if K.enabled and not recovery and not K.movementRest then
    for name, displayName in pairs(K.recoveryTired) do
      local value = K.teamMoves[name]
      if value ~= nil and value <= K.config.restAtMoves then
        K.escape(string.format("Zmeczenie druzyny: %s ma %.0f%% sil do ruchu (prog %d%%).",
          displayName, value, K.config.restAtMoves))
        return false
      end
    end
  end
  if K.enabled and not recovery and not urgentOnly then maybeShieldTeamMember() end
  if K.enabled and not skipMovementWait and K.checkMovementState and not K.checkMovementState() then return false end
  return true
end

local function npcById(id)
  local entity = entityById(id)
  if liveNpc(entity) then
    return entity
  end
end

local function opponentOf(entity, outgoingOnly)
  if not entity or not entity.id then return nil end
  -- Relacja gracz -> NPC okresla jego cel; napastnik NPC jest dopiero
  -- alternatywa. Kolejnosc relacji nie moze przestawiac celu wsparcia.
  local outgoing
  for _, relation in ipairs(combatState().relations or {}) do
    if tostring(relation.attacker) == tostring(entity.id) then
      local npc = npcById(relation.defender)
      if npc and (not outgoing or tostring(npc.id) < tostring(outgoing.id)) then outgoing = npc end
    end
  end
  if outgoing then return outgoing end
  if outgoingOnly then return nil end
  for _, relation in ipairs(combatState().relations or {}) do
    if tostring(relation.attacker) == tostring(entity.id) then
      local npc = npcById(relation.defender)
      if npc then return npc end
    elseif tostring(relation.defender) == tostring(entity.id) then
      local npc = npcById(relation.attacker)
      if npc then return npc end
    end
  end
end

local function supportEvidence(leaderId, targetId)
  local edges, signature = {}, {}
  for _, relation in ipairs(combatState().relations or {}) do
    local attacker, defender = tostring(relation.attacker), tostring(relation.defender)
    if attacker == leaderId or defender == leaderId
        or (targetId and (attacker == targetId or defender == targetId)) then
      edges[attacker .. ">" .. defender] = true
    end
  end
  for edge in pairs(edges) do signature[#signature + 1] = edge end
  table.sort(signature)
  return table.concat(signature, ",")
end

local function liveSupportHint(hint, leader)
  if not hint or hint.leaderId ~= tostring(leader.id) or hint.room ~= currentRoom() then return false end
  for id in pairs(hint.targets or {}) do
    if npcById(id) then return true end
  end
  return false
end

local function supportTarget(leader)
  local target = opponentOf(leader, true)
  local barrier = K.supportDeathBarrier
  if barrier and target then
    -- Przy identycznych opisach nie zawsze da sie przypisac tekst zgonu
    -- do ID. Stary dodatni wpis i stare relacje tez nie potwierdzaja walki.
    if K.combatRevision <= barrier.combat and K.sourceRevisions.entities <= barrier.entities then return nil end
    K.supportDeathBarrier = nil
  end
  return target
end

local function inspectFollower()
  if not K.entitiesReady then return end
  local context = groupContext()
  local leader = context.leader
  K.leaderName = leader and trim(leader.name) or nil
  K.leaderHp = nil
  if not leader then
    clearShieldTurn()
    K.mode = "support_wait"
    K.supportWaitReason = context.reason
    K.supportCombatHint = nil
    clearTarget()
    return
  end
  K.supportWaitReason = nil
  if not safetyCheck() then return end
  K.leaderHp = context.leaderHp
  local target = supportTarget(leader)
  local hint = K.supportCombatHint
  local leaderFighting = target ~= nil or liveSupportHint(hint, leader)
  local selfTarget = npcById(combatState().primary) or opponentOf(context.self)
  K.mode = selfTarget and "support_combat" or "support_wait"
  if K.config.role == "zaslony" then
    maybeShieldTeamMember(true)
  else clearShieldTurn() end
  if not leaderFighting then K.supportAttempt = nil return end
  if selfTarget then
    if K.supportAttempt then
      K.supportAttempt.confirmed = true
      K.supportAttempt.selfCombatRevision = K.combatRevision
    end
    return
  end
  local key = tostring(leader.id) .. ":" .. tostring(target and target.id or "hint")
  local attempt = K.supportAttempt
  if attempt and attempt.selfCombatRevision and K.combatRevision > attempt.selfCombatRevision then
    -- Wlasna walka byla widoczna i rzeczywiscie zniknela w nowym stanie.
    -- To pozwala ponownie dolaczyc; sprzeczny tekst odpowiedzi nie wystarcza.
    attempt.confirmed, attempt.selfCombatRevision = nil, nil
    attempt.deniedEvidence, attempt.deniedHint = nil, nil
  end
  if attempt and attempt.leaderId == tostring(leader.id) and not attempt.targetId and target
      and now() - attempt.createdAt <= 3 then
    attempt.key, attempt.targetId = key, tostring(target.id)
    attempt.targetName = trim(target.name)
  end
  if attempt and attempt.key == key then
    if attempt.confirmed or now() < attempt.untilTime then return end
    if attempt.deniedEvidence == supportEvidence(tostring(leader.id), target and tostring(target.id))
        and attempt.deniedHint == K.supportHintSerial then return end
  end
  if K.supportTimer then return end
  local ambiguous = target and targetNameAmbiguous(target.name) or false
  K.currentTargetId = target and target.id or nil
  K.currentTargetName = target and trim(target.name) or nil
  K.currentTargetAnimal = nil
  K.currentTargetAmbiguous = ambiguous
  K.supportLastTarget = K.leaderName
  -- Rezerwacja przed send: odpowiedz serwera moze poprzedzic Combat.State.
  K.supportAttempt = {key=key, leaderId=tostring(leader.id), targetId=target and tostring(target.id),
    targetName=target and trim(target.name),
    createdAt=now(), untilTime=now() + K.config.supportInterval}
  note("Wspieram prowadzacego: " .. K.leaderName .. ".", "green")
  send("wesprzyj")
  K.metrics.support = K.metrics.support + 1
  later("supportTimer", K.config.supportInterval, function() end)
end

function K.onSupportResult(alreadyFighting)
  if not K.enabled or not isFollower() or not K.supportAttempt then return end
  if alreadyFighting then K.supportAttempt.confirmed = true
  elseif not K.supportAttempt.confirmed then
    K.supportAttempt.deniedEvidence = supportEvidence(K.supportAttempt.leaderId, K.supportAttempt.targetId)
    K.supportAttempt.deniedHint = K.supportHintSerial
  end
end

function K.onDeath()
  if K.enabled or K.reconnectTask then K.stop("Postac zginela. Anulowano zadanie i automatyczne wznowienie.") end
end

function K.onCoveredByLeader(actor)
  if not K.enabled or not K.entitiesReady then return end
  local context = groupContext()
  if not context.self then return end
  for _, member in ipairs(context.members) do
    if not isSelf(member) and normal(member.name) == normal(actor) then
      local incoming = combatSnapshot().incoming[tostring(member.id)]
      -- Jednoznaczny wynik tekstowy uzupelnia historie, gdy pierwszy
      -- Combat.State po logowaniu juz opisuje wykonana zaslone.
      if incoming and incoming.count == 1 then
        local id = next(incoming.npcs)
        K.shieldTransfers[id] = {from=tostring(context.self.id), to=tostring(member.id),
          untilTime=now() + K.config.shieldHold}
      end
      queueInspection(inspectRoom)
      return
    end
  end
end

function K.onEquipmentBroken(line)
  if not K.enabled or isFollower() or K.sessionBlocked then return end
  local _, owner = trim(line):match("^(.+) dzierzon[yae] przez (.+) peka!!!$")
  local person = "moja postac"
  if owner then
    person = nil
    for _, member in ipairs(groupContext().members) do
      if normal(owner) == normal(member.name) or normal(owner) == normal(shieldNameForm(member.name)) then
        person = trim(member.name)
        break
      end
    end
    if not person then return end
  end
  K.config.equipmentHold = "Uszkodzony ekwipunek: " .. person .. "."
  K.saveSettings()
  K.escape(K.config.equipmentHold)
  note("Wznowienie wymaga uzupelnienia ekwipunku i /kozojeb ekwipunek gotowy.", "red")
end

function K.observeRoomAttack(actor, defended)
  if not K.enabled or K.sessionBlocked or not K.sessionFresh.room
      or not K.entitiesReady or K.roomChangePending then return end
  if K.combatRoomReady and K.sessionFresh.combat then return end
  local context, victim = groupContext(), nil
  if normal(defended) == "cie" then victim = context.self
  else
    for _, member in ipairs(context.members) do
      if normal(member.name) == normal(defended) or shieldNameForm(member.name) == normal(defended) then
        victim = member break
      end
    end
  end
  if not victim then return end
  entityIndex()
  local name = normal(actor)
  -- Mapa nazw wspoldzieli indeks encji, zamiast skanowac pokoj po kazdym
  -- powtorzonym tekscie ataku. Niejednoznaczne opisy nie wskazuja ID.
  local npc = K.npcNameCounts[name] == 1 and K.npcNameEntities[name] or nil
  if not liveNpc(npc) then return end
  local state = K.roomCombatState or {room=currentRoom(), relations={}, edges={}}
  K.roomCombatState = state
  local key = tostring(npc.id) .. ">" .. tostring(victim.id)
  if state.edges[key] then return end
  state.edges[key] = true
  state.relations[#state.relations + 1] = {attacker=tostring(npc.id), defender=tostring(victim.id)}
  K.combatRevision, K.combatCache = K.combatRevision + 1, nil
  queueInspection(inspectRoom)
end

function K.onTeamCombat(actor, defended, isAttack)
  if not K.enabled or K.sessionBlocked or not K.sessionFresh.room
      or not K.entitiesReady or K.roomChangePending then return end
  if isAttack then K.observeRoomAttack(actor, defended) end
  if not isFollower()
      or K.mode == "escape" or K.mode == "heal_rest" or K.mode == "recovery_return" then return end
  local leader = groupContext().leader
  if not leader then return end
  -- Sam NPC -> lider nie jest decyzja prowadzacego o rozpoczeciu walki.
  if normal(actor) ~= normal(leader.name) then return end
  local target = supportTarget(leader)
  -- Po zgonie tekst z konczacej sie walki moze przyjsc pozniej niz GMCP.
  -- Kolejne wsparcie wymaga wtedy zywego celu prowadzacego w danych walki.
  if K.supportDeathBarrier and not target then return end
  local targets = {}
  if target then targets[tostring(target.id)] = true
  else
    for _, entity in ipairs(entities()) do
      if liveNpc(entity) then targets[tostring(entity.id)] = true end
    end
  end
  if not next(targets) then return end
  K.supportCombatHint = { leaderId = tostring(leader.id), room=currentRoom(), targets=targets }
  K.supportHintSerial = K.supportHintSerial + 1
  later("supportHintTimer", 3.0, function() K.supportCombatHint = nil end)
  queueInspection(inspectRoom)
end

local function beginHerbSearch()
  if not K.config.herbSearchEnabled or K.mode == "herb_search" then return false end
  local room = currentRoom()
  if not room or K.herbSearchedRoom == room or activeCombatTarget() then return false end
  K.lastRoom = room

  cancelTimer("moveTimer")
  K.patrolMovePending = false
  K.mode = "herb_search"
  local command = trim(K.config.herbSearchCommand)
  if command == "" then command = "szukaj ziol" end
  note("Szukam ziol; czekam na wynik przed kolejnym krokiem.", "cyan")
  later("herbTimer", K.config.herbSearchTimeout, function()
    if not K.enabled or K.mode ~= "herb_search" then return end
    K.herbSearchedRoom = currentRoom()
    K.mode = "patrol"
    note("Brak wyniku szukania ziol przez " .. K.config.herbSearchTimeout .. " s. Wznawiam patrol.", "yellow")
    touchActivity()
    inspectRoom()
  end)
  send(command)
  touchActivity()
  return true
end

function K.onHerbSearchStarted()
  if K.enabled and K.mode == "herb_search" then touchActivity() end
end

function K.onHerbSearchFinished()
  if not K.enabled or K.mode ~= "herb_search" then return end
  cancelTimer("herbTimer")
  K.herbSearchedRoom = currentRoom()
  K.mode = "patrol"
  touchActivity()
  queueInspection(inspectRoom)
end

local function attack(entity, animal)
  if not K.enabled or isFollower() or K.mode == "escape" or K.mode == "kill_pause" then return end
  K.emptyRounds, K.emptyPatrolDelay = 0, 0
  local sameTarget = K.currentTargetId
    and tostring(K.currentTargetId) == tostring(entity.id)
    and K.currentTargetName and normal(K.currentTargetName) == normal(entity.name)
  -- Najwyzej trzy niepotwierdzone proby na NPC w tym pokoju. Relacje
  -- innych uczestnikow ani przejecie NPC przez sojusznika nie odnawiaja
  -- budzetu. Potwierdzenie wlasnego ataku lub nowy pokoj zaczyna nowy cykl.
  if sameTarget and K.focusRetryPending then return end
  local evidence = currentRoom()
  if not sameTarget or K.focusEvidence ~= evidence then K.focusAttempts = 0 end
  if sameTarget and (K.focusAttempts or 0) >= 3 then return end
  cancelTimer("targetLostTimer")
  ensurePursuitOrigin()
  K.mode = "combat"
  K.route = nil
  cancelTimer("moveTimer")
  K.patrolMovePending = false
  K.chaseMovePending = false
  local ambiguous = targetNameAmbiguous(entity.name)
  K.currentTargetId = entity.id
  K.currentTargetName = trim(entity.name)
  K.currentTargetAnimal = animal or animalInName(entity.name)
  K.currentTargetAmbiguous = ambiguous
  if not sameTarget then K.pendingKill = nil end
  K.recentTarget = nil
  if not sameTarget then
    K.herbSearchedRoom = nil
    touchActivity()
    note("Atakuje: " .. K.currentTargetName, "green")
  end
  K.metrics.attacks = K.metrics.attacks + 1
  if sameTarget then K.metrics.attackRetries = K.metrics.attackRetries + 1 end
  K.focusAttempts, K.focusEvidence = (K.focusAttempts or 0) + 1, evidence
  K.focusRetryPending = K.focusAttempts < 3
  if K.focusRetryPending then
    later("focusTimer", 2 ^ (K.focusAttempts - 1), function()
      K.focusRetryPending = false
      if K.enabled and (K.mode == "combat" or K.mode == "chase") then inspectRoom() end
    end)
  end
  send(K.config.attackCommand .. " " .. tostring(attackForm(K.currentTargetAnimal)))
end

inspectRoom = function()
  if not K.enabled then return end
  K.metrics.actions = K.metrics.actions + 1
  K.lastDecisionAt = now()
  if K.entitiesReady and K.sessionFresh.combat then combatSnapshot() end
  if isFollower() then inspectFollower() return end
  local fingerprint = progressFingerprint()
  if fingerprint ~= K.lastProgressFingerprint then
    K.lastProgressFingerprint = fingerprint
    touchActivity()
  end
  if not safetyCheck() then return end
  local observedRoom = currentRoom()
  if K.pursuitOriginRoom and observedRoom and not K.roomSet[observedRoom] then K.pursuitLeftArea = true end
  if K.mode == "escape" then
    if K.recoveryEmergency then K.recoveryEmergencyStep()
    elseif currentRoom() == escapeDestination() then finishEscapeTail() end
    return
  end
  if K.mode == "heal_rest" or K.mode == "recovery_return" or K.mode == "returning"
      or K.mode == "panic_wait" or K.mode == "panic_search" or K.mode == "idle_return"
      or K.mode == "herb_search" then return end
  -- Po komunikacie o ucieczce przez 0.2 s moga jeszcze przychodzic stare
  -- pakiety Combat.State. Nie pozwalamy im anulowac oczekujacego ruchu.
  if K.chaseMovePending then return end

  -- Po zmianie pokoju Room.Info przychodzi przed nowa lista encji. Stare dane
  -- z poprzedniej lokacji nie moga uruchomic ataku ani oznaczyc celu jako
  -- zaginiony. Czekamy na Chimera.Room.Entities.
  if not K.entitiesReady then return end

  -- Po zabiciu zawsze czekamy pelny skonfigurowany czas. Obecnosc kolejnego
  -- celu ani aktualizacje GMCP nie moga skrocic tej pauzy.
  if K.mode == "kill_pause" then return end

  -- Limit jest decyzja patrolu o opuszczeniu pokoju. Agresja serwera nie
  -- moze jej zastapic przyjeciem walki ani anulowac oczekujacego kroku.
  if K.mode == "patrol" and not K.currentTargetName and not K.pursuitOriginRoom then
    local count = K.config.maxCreatures > 0 and roomCreatureCount() or 0
    if K.limitRoom or (K.config.maxCreatures > 0 and count > K.config.maxCreatures) then
      if not K.limitRoom then
        K.limitRoom = {room=currentRoom(), count=count, attempts=0}
        K.limitNoticeRoom = currentRoom()
        clearTarget()
        cancelTimer("pendingFleeTimer")
        K.pendingFleeName = nil
        -- Szybsze ominiecie ma pierwszenstwo przed wczesniej zaplanowanym
        -- wolnym krokiem, takze po opoznionym pojawieniu sie listy NPC.
        cancelTimer("moveTimer")
        K.patrolMovePending = false
        note(string.format("Pomijam pokoj: %d liczonych celow, limit %d. Agresja nie zatrzyma wyjscia.",
          count, K.config.maxCreatures), "yellow")
      end
      patrolStep(math.min(K.config.patrolDelay, K.config.limitExitDelay))
      return
    end
  end

  if K.recentTarget and (K.recentTarget.room ~= currentRoom() or now() - K.recentTarget.at > 3) then
    K.recentTarget = nil
  end
  local tracked = K.currentTargetId and entityById(K.currentTargetId)
  if tracked and tracked.kind == "npc" and tonumber(tracked.hp) == 0
      and not nameHasIgnoredPhrase(tracked.name) then
    K.onKill(tracked.name, false)
    return
  end
  local pending = K.pendingKill
  if pending and (pending.room ~= currentRoom() or now() - pending.at > 3
      or (tracked and tonumber(tracked.hp) and tonumber(tracked.hp) > 0
        and K.sourceRevisions.entities > pending.entities)) then
    K.pendingKill, pending = nil, nil
    cancelTimer("killConfirmTimer")
  end
  if pending and pending.room == currentRoom() and pending.id == tostring(K.currentTargetId)
      and now() - pending.at <= 3 and not tracked then
    K.onKill(pending.name, false)
    return
  end
  if pending then return end
  local combat, outgoing = activeCombatTarget()
  if combatTargetAllowed(combat, outgoing) then
    cancelTimer("focusTimer")
    K.focusRetryPending = false
    K.focusAttempts, K.focusEvidence = 0, nil
    local changedTarget = tostring(K.currentTargetId or "") ~= tostring(combat.id or "")
    local ambiguous = targetNameAmbiguous(combat.name)
    ensurePursuitOrigin()
    K.mode = "combat"
    K.currentTargetId = combat.id
    K.currentTargetName = trim(combat.name)
    K.currentTargetAnimal = animalInName(combat.name)
    K.currentTargetAmbiguous = ambiguous
    if changedTarget then K.pendingKill = nil end
    K.recentTarget = nil
    if changedTarget then
      K.route = nil
      K.herbSearchedRoom = nil
    end
    return
  end

  -- Wpis dodany do listy ignorowanych ma pierwszenstwo nawet przed celem,
  -- ktory byl juz scigany w chwili zmiany ustawien.
  if K.currentTargetName and nameHasIgnoredPhrase(K.currentTargetName) then
    note("Przestaje sledzic ignorowany cel: " .. tostring(K.currentTargetName) .. ".", "yellow")
    clearTarget()
    resetPursuit()
  end

  -- Cel juz scigany ma pierwszenstwo przed filtrem "krowa + byk". Dzieki
  -- temu krowa, ktora dopiero wbiegla w panice do pokoju z bykiem, nadal
  -- jest dobijana, zgodnie z wyjatkiem dla trwajacej pogoni.
  if K.currentTargetName then
    local pursued = currentTargetEntity()
    if pursued then
      attack(pursued, K.currentTargetAnimal or animalInName(pursued.name))
      return
    end
    -- Po ucieczce NPC znika z GMCP odrobine wczesniej niz przychodzi tekst
    -- z kierunkiem. Nie wolno w tym oknie kasowac celu i ruszac patrolem.
    if K.mode == "chase" or K.mode == "combat" then
      if K.entitiesReady and not K.targetLostTimer then
        later("targetLostTimer", K.config.targetLostDelay, function()
          K.onTargetLost()
        end)
      end
      return
    end
  end

  clearTarget(true)
  local target, animal, reason, creatureCount = findTarget()
  if target then
    K.limitNoticeRoom = nil
    attack(target, animal)
    return
  end
  if reason == "limit" then
    local room = currentRoom()
    if K.limitNoticeRoom ~= room then
      K.limitNoticeRoom = room
      note(string.format(
        "Pomijam atak: w pokoju jest %d wybranych celow, limit wynosi %d.",
        creatureCount, K.config.maxCreatures
      ), "yellow")
    end
  end
  if reason ~= "limit" and beginHerbSearch() then return end
  K.mode = "patrol"
  patrolStep(reason == "limit" and math.min(K.config.patrolDelay, K.config.limitExitDelay) or nil)
end

patrolStep = function(delayOverride)
  if not K.enabled or isFollower() or K.mode ~= "patrol" or not safetyCheck() then return end
  -- Room.Info zwykle przychodzi przed lista NPC. Nie wychodzimy z pokoju,
  -- dopoki Chimera.Room.Entities nie potwierdzi, ze pokoj zostal sprawdzony.
  if not K.entitiesReady then return end
  if K.patrolMovePending then return end
  local skipped = K.limitRoom
  if skipped and skipped.attempts >= K.config.escapeMaxAttempts and recoveryThreat() then
    K.escape("Nie udalo sie opuscic zatloczonego pokoju po " .. K.config.escapeMaxAttempts .. " probach.")
    return
  end
  local room = markCurrentRoom()
  if not room then
    K.stop("Nie potrafie odczytac biezacego pokoju mapy.")
    return
  end
  if not K.roomSet[room] then
    K.stop("Pokoj " .. room .. " nie nalezy do obszaru. Uzyj /idz do obszaru i ponow /kozojeb start.")
    return
  end
  if not hasUnvisited() then
    K.emptyRounds = K.patrolRoundKills == 0 and K.emptyRounds + 1 or 0
    K.patrolRoundKills = 0
    K.emptyPatrolDelay = K.config.emptyPatrolMax > 0 and K.emptyRounds > 0
      and math.min(K.config.emptyPatrolMax, K.config.patrolDelay * 2 ^ math.min(6, K.emptyRounds)) or 0
    K.visited = { [room] = true }
    note("Obejrzalem caly obszar; zaczynam kolejne losowe okrazenie.", "cyan")
  end
  if not K.route or K.routeIndex > #K.route then
    K.route = routeToNearestUnvisited(room)
    K.routeIndex = 1
  end
  if not K.route or not K.route[K.routeIndex] then
    if skipped and recoveryThreat() then
      K.escape("Brak drogi patrolu z zatloczonego pokoju podczas ataku.")
      return
    end
    if #K.rooms == 1 and K.rooms[1] == room then
      local retryDelay = skipped and math.max(1, K.config.patrolDelay)
        or delayOverride or math.max(K.config.patrolDelay, K.emptyPatrolDelay)
      later("moveTimer", retryDelay, function()
        if K.enabled and K.mode == "patrol" then inspectRoom() end
      end)
      return
    end
    -- Pozostale wpisy moga byc nieosiagalne z aktualnego miejsca z powodu
    -- jednokierunkowego albo chwilowo niepelnego polaczenia mapy. Reczny
    -- stop/start pomagal tylko dlatego, ze zerowal K.visited; robimy to
    -- teraz automatycznie, nie wylaczajac bota.
    K.visited = { [room] = true }
    K.route = routeToNearestUnvisited(room)
    K.routeIndex = 1
    if not K.route or not K.route[1] then
      K.routeRecoveryAttempts = (K.routeRecoveryAttempts or 0) + 1
      if K.routeRecoveryAttempts == 1 or K.routeRecoveryAttempts % 10 == 0 then
        note("Mapa chwilowo nie pokazuje polaczenia z tego pokoju. Ponawiam odczyt mapy.", "yellow")
      end
      later("moveTimer", math.max(1.0, delayOverride or K.config.patrolDelay), function()
        if K.enabled and K.mode == "patrol" then inspectRoom() end
      end)
      return
    end
    K.routeRecoveryAttempts = 0
    note("Nieosiagalne pokoje pozostaly w poprzednim okrazeniu; automatycznie zaczynam nowy obieg.", "yellow")
  end

  K.routeRecoveryAttempts = 0

  local edge = K.route[K.routeIndex]
  local command = directionCommands[normal(edge.direction)] or edge.direction
  K.patrolMovePending = true
  local delay = delayOverride or math.max(K.config.patrolDelay, K.emptyPatrolDelay)
  later("moveTimer", delay, function()
    if K.enabled and K.mode == "patrol" then
      if skipped then
        if K.limitRoom ~= skipped or currentRoom() ~= room or not K.entitiesReady or K.roomChangePending then
          K.patrolMovePending = false
          return
        end
        if not safetyCheck() then K.patrolMovePending = false return end
      end
      if sendDirection(command) and skipped then
        skipped.attempts = skipped.attempts + 1
        -- Jeden oczekujacy krok. Brak potwierdzenia nie generuje kolejnych
        -- kierunkow; po czasie przekazujemy ruch procedurze odwrotu /idz.
        later("moveTimer", K.config.escapeRetryDelay, function()
          if K.enabled and K.mode == "patrol" and K.limitRoom == skipped and K.roomChangePending then
            K.escape("Brak potwierdzenia wyjscia z zatloczonego pokoju.")
          end
        end)
      elseif skipped then K.patrolMovePending = false end
    else
      K.patrolMovePending = false
    end
  end)
end

local returnToPursuitOriginStep

local function finishPursuitReturn(room)
  note("Wrocilem do pokoju rozpoczecia pogoni: " .. tostring(room) .. ".", "green")
  resetPursuit()
  K.route = nil
  K.visited = room and { [room] = true } or {}
  K.mode = "patrol"
  inspectRoom()
end

-- Wyznaczamy tylko jeden nastepny krok z faktycznej pozycji. Po wejsciu do
-- kolejnego pokoju droga jest liczona ponownie. Reczne ruchy gracza nie moga
-- wiec zepsuc powrotu, a zadna czesc mechanizmu nie korzysta z /idz.
returnToPursuitOriginStep = function()
  if not K.enabled or K.mode ~= "returning" then return end
  local room = currentRoom()
  local destination = tonumber(K.pursuitOriginRoom)
  if not room or not destination then
    K.stop("Nie znam aktualnego pokoju albo punktu rozpoczecia pogoni.")
    return
  end
  if room == destination then
    finishPursuitReturn(room)
    return
  end
  K.returnSteps = (K.returnSteps or 0) + 1
  if K.returnSteps > 250 then
    K.stop("Przerwalem powrot po 250 krokach; mapa moze miec niespojne wyjscia.")
    return
  end

  speedWalkDir = nil
  speedWalkPath = nil
  local ok, found = pcall(getPath, room, destination)
  local command
  if ok and found ~= false and type(speedWalkDir) == "table" and #speedWalkDir > 0 then
    local raw = tostring(speedWalkDir[1])
    command = directionCommands[normal(raw)] or raw
    K.returnUsedMap = true
  elseif not K.returnUsedMap and K.returnFallbackCommands
      and K.returnFallbackCommands[K.returnFallbackIndex] then
    command = K.returnFallbackCommands[K.returnFallbackIndex]
    K.returnFallbackIndex = K.returnFallbackIndex + 1
    note("Mapa nie zna drogi; wracam odwrotnymi komendami zapisanej pogoni: " .. command .. ".", "yellow")
  else
    K.stop(string.format(
      "Nie potrafie wyznaczyc dalszego powrotu z pokoju %d do %d.", room, destination
    ))
    return
  end
  later("returnTimer", K.config.chaseDelay, function()
    if K.enabled and K.mode == "returning" then sendDirection(command) end
  end)
end

local function beginPursuitReturn()
  K.mode = "returning"
  K.returnSteps = 0
  K.returnUsedMap = false
  K.returnFallbackCommands = {}
  for index = #K.pursuitTrail, 1, -1 do
    local inverse = inverseDirections[K.pursuitTrail[index]]
    if inverse then K.returnFallbackCommands[#K.returnFallbackCommands + 1] = inverse end
  end
  K.returnFallbackIndex = 1
  note(string.format(
    "Wracam komendami z aktualnej pozycji do pokoju rozpoczecia pogoni (%s).",
    tostring(K.pursuitOriginRoom or "?")
  ), "cyan")
  returnToPursuitOriginStep()
end

function K.onTargetLost()
  if isFollower() then return end
  if not K.enabled or (K.mode ~= "combat" and K.mode ~= "chase") then return end
  local tracked = K.currentTargetId and entityById(K.currentTargetId)
  if tracked and tracked.kind == "npc" and tonumber(tracked.hp) == 0
      and not nameHasIgnoredPhrase(tracked.name) then
    K.onKill(tracked.name, false)
    return
  end
  if currentTargetEntity() then
    inspectRoom()
    return
  end
  local lostName = K.currentTargetName or "nieznany cel"
  local shouldReturn = K.pursuitLeftArea and #K.pursuitTrail > 0 and K.pursuitOriginRoom
  local recent = {id=K.currentTargetId, name=K.currentTargetName, animal=K.currentTargetAnimal,
    room=currentRoom(), at=now(), origin=K.pursuitOriginRoom,
    trail=copyArray(K.pursuitTrail), leftArea=K.pursuitLeftArea, ambiguous=K.currentTargetAmbiguous}
  note("Cel zniknal bez potwierdzenia smierci lub kierunku: " .. lostName .. ". Odblokowuje stan.", "yellow")
  clearTarget()
  K.recentTarget = recent
  K.route = nil
  if shouldReturn then
    beginPursuitReturn()
  else
    resetPursuit()
    K.mode = "patrol"
    inspectRoom()
  end
end

function K.onAttackRejected()
  if isFollower() then return end
  if not K.enabled or K.mode ~= "combat" or not K.currentTargetName or not K.focusRetryPending then return end
  local failedId = tostring(K.currentTargetId or "")
  local failedName = K.currentTargetName
  if failedId ~= "" then K.failedTargetIds[failedId] = true end
  note(
    "Serwer odrzucil atak na " .. failedName
      .. ". Pomijam ten konkretny wpis do czasu zmiany pokoju; sprawdz forme biernika celu.",
    "red"
  )
  clearTarget()
  resetPursuit()
  K.mode = "patrol"
  queueInspection(inspectRoom)
end

local idleReturnStep

local function finishIdleReset()
  restartPatrolWhenReady("idle")
end

local function fallbackIdleReset(room, destination)
  K.idleAliasAttempts = (K.idleAliasAttempts or 0) + 1
  if K.idleAliasAttempts > K.config.escapeMaxAttempts then
    K.stop(string.format(
      "Reset bezczynnosci: nie udalo sie dotrzec do pokoju startowego %d po %d probach.",
      destination, K.config.escapeMaxAttempts
    ))
    return
  end
  note(string.format(
    "Mapa nie ma drogi do %d. Awaryjna proba /idz: %d/%d.",
    destination, K.idleAliasAttempts, K.config.escapeMaxAttempts
  ), "yellow")
  pcall(expandAlias, "/idz " .. destination)
  K.idleAliasActive = true
  later("idleReturnTimer", 10.0, idleReturnStep)
end

idleReturnStep = function()
  if not K.enabled or K.mode ~= "idle_return" then return end
  K.idleAliasActive = false
  local room = currentRoom()
  local destination = tonumber(K.config.startRoom)
  if not room or not destination then
    K.stop("Reset bezczynnosci: nie znam aktualnego pokoju albo pokoju startowego.")
    return
  end
  if room == destination then
    finishIdleReset()
    return
  end
  K.idleSteps = (K.idleSteps or 0) + 1
  if K.idleSteps > 250 then
    fallbackIdleReset(room, destination)
    return
  end

  speedWalkDir = nil
  speedWalkPath = nil
  local ok, found = pcall(getPath, room, destination)
  if not ok or found == false or type(speedWalkDir) ~= "table" or #speedWalkDir == 0 then
    fallbackIdleReset(room, destination)
    return
  end
  local raw = tostring(speedWalkDir[1])
  local command = directionCommands[normal(raw)] or raw
  later("idleReturnTimer", K.config.chaseDelay, function()
    if K.enabled and K.mode == "idle_return" then sendDirection(command) end
  end)
end

function K.onIdleTimeout()
  if isFollower() then return end
  if not K.enabled or idleIsIntentional() or K.mode == "idle_return" then
    if K.enabled then touchActivity() end
    return
  end
  K.lastIdleDiagnostic = K.diagnostics("watchdog")
  K.generation = K.generation + 1
  cancelAllTimers()
  clearTarget()
  resetPursuit()
  resetPanicSearch()
  K.route = nil
  K.idleSteps = 0
  K.idleAliasAttempts = 0
  K.idleAliasActive = false
  K.mode = "idle_return"
  K.metrics.idleResets = K.metrics.idleResets + 1
  note(string.format(
    "Brak aktywnosci przez %.1f s. Wracam komendami do pokoju startowego %d.",
    K.config.idleTimeout, K.config.startRoom
  ), "red")
  idleReturnStep()
end

function K.onCombatProgress()
  if not K.enabled or K.sessionBlocked or not K.sessionFresh.room then return end
  K.lastOwnCombatAt = now()
  if not isFollower() and (K.mode == "combat" or K.mode == "chase") then touchActivity() end
end

local panicInspect

local function panicSearchFinished()
  local room = currentRoom()
  note("Nie znalazlem w sasiednich pokojach przeciwnika walczacego ze mna. Wracam do patrolu.", "yellow")
  resetPanicSearch()
  K.visited = room and { [room] = true } or {}
  K.route = nil
  K.mode = "patrol"
  inspectRoom()
end

local function panicGoToNextRoom()
  if not K.enabled or K.mode ~= "panic_search" then return end
  local edge = K.panicExits and K.panicExits[K.panicIndex]
  if not edge then
    panicSearchFinished()
    return
  end
  K.panicPhase = "to_neighbor"
  note(string.format("Po panice sprawdzam sasiedni pokoj %d przez %s.", edge.room, edge.direction), "cyan")
  later("panicTimer", K.config.chaseDelay, function()
    if K.enabled and K.mode == "panic_search" and K.panicPhase == "to_neighbor" then
      sendDirection(edge.direction)
    end
  end)
end

panicInspect = function()
  if not K.enabled or K.mode ~= "panic_search" then return end
  if not K.entitiesReady then
    later("panicTimer", 0.20, panicInspect)
    return
  end

  local target = hostileTarget()
  if target then
    local animal = animalKind(target.name)
    note("Odnalazlem przeciwnika po panice: " .. tostring(target.name) .. ".", "green")
    resetPanicSearch()
    resetPursuit()
    ensurePursuitOrigin()
    if animal then
      -- Samo wznowienie walki przez NPC nie ustawia fokusu postaci. Ponowne
      -- "zabij <gatunek>" koncentruje walke na odnalezionym przeciwniku.
      attack(target, animal)
    else
      K.mode = "combat"
      K.currentTargetId = target.id
      K.currentTargetName = trim(target.name)
    end
    return
  end

  if K.panicPhase == "center" then
    panicGoToNextRoom()
    return
  end
  if K.panicPhase == "inspect_neighbor" then
    local edge = K.panicExits[K.panicIndex]
    K.panicPhase = "return_to_center"
    later("panicTimer", K.config.chaseDelay, function()
      if K.enabled and K.mode == "panic_search" and K.panicPhase == "return_to_center" then
        sendDirection(inverseDirections[edge.direction])
      end
    end)
  end
end

local function beginPanicSearch()
  if not K.enabled or (K.mode ~= "panic_wait" and K.mode ~= "panic_search") then return end
  if K.panicCenter then return end
  K.panicCenter = currentRoom()
  if not K.panicCenter then
    K.stop("Po panice nie potrafie odczytac biezacego pokoju mapy.")
    return
  end
  K.panicExits = adjacentExitList(K.panicCenter)
  K.panicIndex = 1
  K.panicPhase = "center"
  K.mode = "panic_search"
  note(string.format(
    "Ucieczka zakonczona. Czekam %.1f s, potem sprawdze ten pokoj i %d sasiednich.",
    K.config.panicWait, #K.panicExits
  ), "yellow")
  later("panicTimer", K.config.panicWait, panicInspect)
end

function K.onPanic()
  if not K.enabled or K.mode == "escape" or K.mode == "heal_rest" or K.mode == "recovery_return" then return end
  cancelAllTimers()
  resetPanicSearch()
  resetPursuit()
  clearTarget()
  K.route = nil
  if isFollower() then
    K.mode = "support_wait"
    note("Panika wspierajacego: czekam na ponowne spotkanie z druzyna.", "red")
    return
  end
  K.mode = "panic_wait"
  touchActivity()
  note("Wpadlem w panike. Wstrzymuje patrol i czekam na miejsce ucieczki.", "red")
end

function K.onPanicLanded()
  if not K.enabled then return end
  if isFollower() then
    queueInspection(inspectRoom)
    return
  end
  -- "Uciekles <NPC>." pojawia sie takze przy zwyklym wyjsciu z pokoju,
  -- gdy agresywny NPC zdazyl zaatakowac. Bez poprzedniego komunikatu
  -- "Wpadasz w panike!" nie uruchamiamy procedury paniki.
  if K.mode ~= "panic_wait" then return end
  beginPanicSearch()
end

function K.onRoomChanged(eventName)
  if eventName == "gmcp.Room.Info" then K.lastGmcpAt, K.lastGmcpEvent = now(), eventName end
  invalidateState(true)
  local previousRoom = K.lastRoom
  if eventName == "gmcp.Room.Info" then
    if K.limitRoom and K.limitRoom.room == currentRoom() and K.roomChangePending then
      -- Powtorzony opis tego samego pokoju nie potwierdza przejscia i nie
      -- moze odblokowac drugiego kierunku przed wynikiem pierwszego.
      K.sessionFresh.room = true
      return
    end
    local step = K.moveSnapshot
    if K.limitRoom and K.limitRoom.room ~= currentRoom() then
      cancelTimer("moveTimer")
      K.limitRoom, K.limitNoticeRoom = nil, nil
    end
    if step and step.from ~= currentRoom() then
      if not step.regroup and next(step.roster)
          and (step.mode == "patrol" or step.mode == "combat" or step.mode == "chase") then
        K.teamStep = step
      end
      K.moveSnapshot = nil
    end
    K.sessionFresh.room = true
    K.sessionFresh.entities = false
    K.roomChangePending = false
    K.sentDirection = nil
    K.entitiesReady = false
    K.patrolMovePending = false
    K.chaseMovePending = false
    K.failedTargetIds = {}
    K.supportCombatHint = nil
    K.shieldRescue, K.teamShieldNotices = nil, {}
    cancelTimer("teamShieldTimer")
    clearShieldTurn()
    if previousRoom ~= currentRoom() then
      K.previousRoom = previousRoom
      K.combatRoomReady = false
      K.roomCombatState = nil
      K.shieldBlockedReason = nil
      K.recentTarget, K.supportDeathBarrier = nil, nil
      K.currentTargetAmbiguous, K.pendingKill = false, nil
      K.supportAttempt = nil
      cancelTimer("supportTimer")
      K.healthHistory, K.shieldTransfers = {}, {}
      K.previousIncoming, K.transferRevision = nil, nil
      K.deadNpcIds = {}
    end
  end
  if not K.enabled then return end
  if isFollower() then
    K.lastRoom = currentRoom()
    clearTarget()
    queueInspection(inspectRoom)
    return
  end
  local room = markCurrentRoom()
  local changedRoom = room and previousRoom and room ~= previousRoom
  if changedRoom then K.herbSearchedRoom = nil end
  if K.mode == "herb_search" and changedRoom then
    cancelTimer("herbTimer")
    K.mode = "patrol"
  end
  if K.mode == "idle_return" then
    if K.movementRest or K.teamStep then return end
    if K.idleAliasActive and room ~= tonumber(K.config.startRoom) then
      -- /idz nadal robi postep; nie uruchamiamy kolejnej kopii aliasu.
      later("idleReturnTimer", 10.0, idleReturnStep)
    else
      later("idleReturnTimer", K.config.actionDelay, idleReturnStep)
    end
    return
  end
  touchActivity()
  if K.pursuitOriginRoom and room and not K.roomSet[room] then K.pursuitLeftArea = true end
  if K.mode == "escape" then
    if K.recoveryEmergency then
      K.recoveryEmergencyStep()
    elseif room == escapeDestination() then
      finishEscapeTail()
    else
      -- Dopoki /idz robi postep, przesuwamy watchdog. Ponowienie nastepuje
      -- dopiero po pelnym okresie bez zmiany pokoju.
      later("escapeWatchTimer", K.config.escapeRetryDelay, sendEscapeAttempt)
    end
    return
  end
  if K.mode == "returning" then
    later("returnTimer", K.config.actionDelay, returnToPursuitOriginStep)
    return
  end
  if K.mode == "recovery_return" then
    if room == tonumber(K.config.startRoom) then finishRecoveryReturn() end
    return
  end
  if K.mode == "heal_rest" then return end
  if K.mode == "panic_wait" then
    beginPanicSearch()
    return
  end
  if K.mode == "panic_search" then
    if K.panicPhase == "to_neighbor" then
      K.panicPhase = "inspect_neighbor"
      later("panicTimer", 0.35, panicInspect)
    elseif K.panicPhase == "return_to_center" then
      if K.panicCenter and room ~= K.panicCenter then
        K.stop("Nie udalo sie wrocic do srodka poszukiwan po panice.")
        return
      end
      K.panicIndex = K.panicIndex + 1
      K.panicPhase = "center"
      later("panicTimer", K.config.chaseDelay, panicGoToNextRoom)
    end
    return
  end
  if K.mode == "patrol" and K.route and K.route[K.routeIndex] then
    if room == K.route[K.routeIndex].room then K.routeIndex = K.routeIndex + 1 else K.route = nil end
  end
  queueInspection(inspectRoom)
end

function K.onGmcp(eventName)
  K.lastGmcpAt, K.lastGmcpEvent = now(), eventName
  K.metrics.events = K.metrics.events + 1
  local healthEvent = eventName == "gmcp.Chimera.Room.Entities"
    or eventName == "gmcp.Char.Vitals" or eventName == "gmcp.Chimera.Group.State"
  invalidateState(healthEvent, eventName)
  if eventName == "gmcp.Chimera.Room.Entities" and not K.roomChangePending then
    K.entitiesReady = true
    K.sessionFresh.entities = true
    K.vitalsRevision = K.vitalsRevision + 1
    K.vitalsSource = "entities"
    K.sourceRevisions.entities = K.dataRevision
    for id, death in pairs(K.deadNpcIds) do
      local entity = entityById(id)
      if not entity then K.deadNpcIds[id] = nil
      elseif tonumber(entity.hp) and tonumber(entity.hp) <= 0 then death.zeroSeen = true
      elseif death.zeroSeen then K.deadNpcIds[id] = nil end
    end
    local observed = K.roomCombatState
    if observed then
      for i = #observed.relations, 1, -1 do
        local relation = observed.relations[i]
        if not liveNpc(entityById(relation.attacker)) or not entityById(relation.defender) then
          observed.edges[relation.attacker .. ">" .. relation.defender] = nil
          table.remove(observed.relations, i)
          K.combatRevision = K.combatRevision + 1
        end
      end
    end
  end
  if eventName == "gmcp.Char.Vitals" then
    K.vitalsRevision = K.vitalsRevision + 1
    K.vitalsSource = "char"
    K.sourceRevisions.char = K.dataRevision
  end
  if eventName == "gmcp.Chimera.Combat.State" then
    K.roomCombatState = nil
    K.sessionFresh.combat = true
    K.combatRoomReady = true
    K.combatRevision = K.combatRevision + 1
  end
  if eventName == "gmcp.Chimera.Group.State" then
    K.sessionFresh.group = true
    K.sourceRevisions.group = K.dataRevision
  end
  if K.sessionBlocked and K.sessionFresh.room and K.sessionFresh.entities then
    for _, entity in ipairs(entities()) do
      if isSelf(entity) then
        K.sessionBlocked = false
        if not K.reconnectTask then
          note("Odebralem swieze dane postaci. Bot pozostaje zatrzymany.", "green")
        end
        break
      end
    end
  end
  if eventName == "gmcp.Char.Vitals" then K.sessionFresh.vitals = true end
  if K.reconnectTask then K.tryResumeAfterReconnect() return end
  if not K.enabled then return end
  if K.movementRest and K.tryResumeMovement then
    K.tryResumeMovement()
    K.armMovementRest()
  end
  if K.restartPending then restartPatrolWhenReady(K.restartPending) return end
  if isFollower() then
    if eventName == "gmcp.Chimera.Group.State" then
      K.supportCombatHint = nil
    end
    queueInspection(inspectRoom)
    return
  end
  -- Pilne HP omijaja kolejke decyzji; same zmiany relacji nie powoduja
  -- wielokrotnego przeliczania zaslon i sortowania tego samego pakietu.
  if healthEvent and not safetyCheck(true) then return end
  if K.mode == "idle_return" then return end
  if K.mode == "herb_search" then
    local combat, outgoing = activeCombatTarget()
    local target = findTarget()
    if combatTargetAllowed(combat, outgoing) or target then
      cancelTimer("herbTimer")
      K.herbSearchedRoom = nil
      K.mode = "patrol"
      note("Przerywam szukanie ziol: pojawil sie cel walki.", "yellow")
      queueInspection(inspectRoom)
    end
    return
  end
  if K.mode == "panic_wait" then return end
  if K.mode == "panic_search" then
    if K.panicPhase == "center" or K.panicPhase == "inspect_neighbor" then
      later("panicTimer", 0.35, panicInspect)
    end
    return
  end
  if K.mode ~= "returning" and K.mode ~= "herb_search" then
    queueInspection(inspectRoom)
  end
end

function K.onFleeAnnounced(name)
  if not K.enabled or isFollower() or K.mode == "leader_wait" or K.limitRoom then return end
  cancelTimer("targetLostTimer")
  K.pendingFleeName = trim(name)
  later("pendingFleeTimer", 3.0, function()
    K.pendingFleeName = nil
    if K.enabled and (K.mode == "combat" or K.mode == "chase") then inspectRoom() end
  end)
end

function K.onFleeDirection(direction)
  if not K.enabled or isFollower() or K.mode == "leader_wait" or K.limitRoom then return end
  local name = K.pendingFleeName or K.currentTargetName
  cancelTimer("pendingFleeTimer")
  K.pendingFleeName = nil
  if not name or trim(name) == "" then
    note("Wykrylem kierunek ucieczki " .. tostring(direction) .. ", ale nie znam uciekajacego NPC.", "red")
    return
  end
  K.onFlee(name, direction)
end

function K.onFlee(name, direction)
  if isFollower() or K.mode == "leader_wait" or K.limitRoom then return end
  if not K.enabled then return end
  if K.mode == "patrol" and not K.currentTargetName and not K.pursuitOriginRoom
      and K.config.maxCreatures > 0
      and (not K.entitiesReady or roomCreatureCount() > K.config.maxCreatures) then
    queueInspection(inspectRoom)
    return
  end
  name, direction = trim(name), normal(direction)
  local selectedKind = animalInName(name)
  local protectedMode = K.mode == "escape" or K.mode == "heal_rest" or K.mode == "recovery_return"
    or K.mode == "returning" or K.mode == "panic_wait" or K.mode == "panic_search"
    or K.mode == "idle_return"
  if protectedMode then
    if selectedKind then note("Nie gonie " .. name .. ": tryb ochronny " .. K.mode .. ".", "yellow") end
    return
  end
  if nameHasIgnoredPhrase(name) then
    note("Nie gonie " .. tostring(name) .. ": pasuje do listy ignorowanych.", "yellow")
    if K.currentTargetName and normal(name) == normal(K.currentTargetName) then
      clearTarget()
      resetPursuit()
      K.mode = "patrol"
      queueInspection(inspectRoom)
    end
    return
  end
  -- Pauza po zabiciu jest bezwzgledna. Zgodnie z konfiguracja nie zaczynamy
  -- kolejnej pogoni ani walki przed uplywem pelnych killPause sekund.
  if K.mode == "kill_pause" then
    note("Nie gonie " .. name .. ": trwa pelna pauza po zabiciu.", "yellow")
    return
  end
  if K.currentTargetName then
    -- Podczas normalnej walki nie porzucamy konkretnego celu dla innego
    -- uciekajacego NPC, nawet jezeli jego gatunek tez jest na liscie celow.
    if normal(name) ~= normal(K.currentTargetName) then
      note("Nie gonie " .. name .. ": aktualnie sledze " .. tostring(K.currentTargetName) .. ".", "yellow")
      return
    end
  elseif K.mode ~= "combat" and K.mode ~= "chase" then
    if not selectedKind then
      note("Nie gonie " .. name .. ": ten gatunek nie jest na liscie celow.", "yellow")
      return
    end
  elseif not selectedKind then
    note("Nie gonie " .. name .. ": ten gatunek nie jest na liscie celow.", "yellow")
    return
  end
  local command = directionCommands[direction]
  if not command then
    note("Nie rozpoznaje kierunku ucieczki: " .. tostring(direction) .. ".", "red")
    return
  end
  cancelTimer("targetLostTimer")
  ensurePursuitOrigin()
  K.pursuitTrail[#K.pursuitTrail + 1] = command
  K.mode = "chase"
  K.patrolMovePending = false
  K.chaseMovePending = true
  touchActivity()
  K.currentTargetName = name
  K.currentTargetId, K.currentTargetAmbiguous, K.pendingKill = nil, false, nil
  cancelTimer("actionTimer")
  later("moveTimer", K.config.chaseDelay, function()
    if not K.enabled or not K.chaseMovePending or not safetyCheck() then return end
    K.mode = "chase"
    note("Gonie na " .. command .. ": " .. name, "yellow")
    sendDirection(command)
  end)
end

local function finishCurrentKill()
  if not K.enabled or K.mode == "kill_pause" or not K.currentTargetName then return end
  K.patrolRoundKills = K.patrolRoundKills + 1
  K.emptyRounds, K.emptyPatrolDelay = 0, 0
  local returnAfterPause = K.pursuitLeftArea and #K.pursuitTrail > 0
  clearTarget()
  K.route = nil
  K.mode = "kill_pause"
  cancelTimer("moveTimer")
  cancelTimer("returnTimer")
  K.patrolMovePending = false
  K.chaseMovePending = false
  touchActivity()
  note("Cel zabity. Czekam " .. K.config.killPause .. " sekund.", "green")
  later("killTimer", K.config.killPause, function()
    if not K.enabled or K.mode ~= "kill_pause" then return end
    if returnAfterPause then
      beginPursuitReturn()
      return
    end
    resetPursuit()
    K.mode = "patrol"
    inspectRoom()
  end)
end

function K.onKill(name, confirmedByServer)
  local matchesByName, dead = {}, nil
  if K.enabled then
    entityIndex()
    for _, entity in ipairs(entities()) do
      if entity.kind == "npc" and normal(entity.name) == normal(name) then
        matchesByName[#matchesByName + 1] = entity
        if tonumber(entity.hp) and tonumber(entity.hp) <= 0 then dead = entity end
      end
    end
    if #matchesByName == 1 and not dead then
      local only = matchesByName[1]
      -- Gdy poprzedni cel juz zniknal, jeden zywy NPC o tym samym opisie
      -- moze byc innym egzemplarzem. Nie przypisujemy mu cudzego zgonu.
      local expected = K.currentTargetId and {id=K.currentTargetId, name=K.currentTargetName,
        ambiguous=K.currentTargetAmbiguous}
        or K.recentTarget or (K.supportAttempt and {id=K.supportAttempt.targetId, name=K.supportAttempt.targetName})
      if not (expected and expected.ambiguous and normal(expected.name) == normal(name))
          and (not expected or not expected.id or normal(expected.name) ~= normal(name)
            or tostring(only.id) == tostring(expected.id)) then dead = only end
    end
    if dead then
      K.deadNpcIds[tostring(dead.id)] = {zeroSeen=tonumber(dead.hp) and tonumber(dead.hp) <= 0}
      K.combatCache = nil
      K.creatureCountCache = nil
    end
  end
  if K.enabled and isFollower() then
    K.supportCombatHint = nil
    K.supportDeathBarrier = {combat=K.combatRevision, entities=K.sourceRevisions.entities}
    cancelTimer("supportHintTimer")
    clearTarget()
    queueInspection(inspectRoom)
    return
  end
  if not K.enabled or K.mode == "kill_pause" then return end
  if K.limitRoom then return end
  if nameHasIgnoredPhrase(name) then return end
  local recent = K.recentTarget
  if not K.currentTargetName and recent and recent.name and recent.room == currentRoom()
      and now() - recent.at <= 3 and not K.roomChangePending
      and (K.mode == "patrol" or K.mode == "returning") then
    local exact = normal(name) == normal(recent.name)
    local kind = confirmedByServer and selectedTargetKindInAnyForm(name)
    local ambiguous = false
    for _, entity in ipairs(entities()) do
      if liveNpc(entity) and tostring(entity.id) ~= tostring(recent.id)
          and ((exact and normal(entity.name) == normal(recent.name))
            or (not exact and kind and animalInName(entity.name) == kind)) then ambiguous = true break end
    end
    local entity = recent.id and entityById(recent.id)
    if not ambiguous and (not entity or tonumber(entity.hp) == 0)
        and (exact or (kind and kind == recent.animal)) then
      K.currentTargetId, K.currentTargetName, K.currentTargetAnimal = recent.id, recent.name, recent.animal
      K.pursuitOriginRoom, K.pursuitTrail, K.pursuitLeftArea = recent.origin, recent.trail, recent.leftArea
      finishCurrentKill()
      return
    end
  end
  if not K.currentTargetName then return end
  local currentMatch = normal(name) == normal(K.currentTargetName)
  local tracked = K.currentTargetId and entityById(K.currentTargetId)
  if currentMatch and ((tracked and tonumber(tracked.hp) == 0)
      or (#matchesByName <= 1 and (not K.currentTargetAmbiguous or not tracked)
        and (not dead or tostring(dead.id) == tostring(K.currentTargetId)))) then
    finishCurrentKill()
    return
  end
  if currentMatch and dead and tostring(dead.id) ~= tostring(K.currentTargetId) then return end

  -- Linie z XP sa zwykle w bierniku, wiec nazwy nie da sie porownac 1:1.
  -- Sam zgodny gatunek nie wystarcza: w grupie moze wlasnie zginac drugi byk
  -- albo ork. Czekamy na znikniecie konkretnego ID aktualnego celu z GMCP.
  if not confirmedByServer and not currentMatch then return end
  local killedKind = selectedTargetKindInAnyForm(name)
  if not currentMatch and (not K.currentTargetAnimal or killedKind ~= K.currentTargetAnimal) then return end
  local expectedId = tostring(K.currentTargetId or "")
  local expectedName = K.currentTargetName
  if currentMatch and not dead then
    K.pendingKill = {id=expectedId, name=expectedName, room=currentRoom(), at=now(),
      entities=K.sourceRevisions.entities}
  end
  local pendingConfirmation = K.pendingKill
  later("killConfirmTimer", 0.35, function()
    if not K.enabled or (K.mode ~= "combat" and K.mode ~= "chase") then return end
    if currentMatch and K.pendingKill ~= pendingConfirmation then return end
    if tostring(K.currentTargetId or "") ~= expectedId or K.currentTargetName ~= expectedName then return end
    local entity = expectedId ~= "" and entityById(expectedId) or currentTargetEntity()
    if not entity or (tonumber(entity.hp) and tonumber(entity.hp) <= 0) then
      finishCurrentKill()
    end
  end)
end

function K.stop(reason)
  invalidateState(true)
  K.reconnectTask, K.reconnectWaitReason = nil, nil
  K.restartPending = nil
  K.refugeRoom, K.recoveryEmergency, K.escapeOriginRoom = nil, nil, nil
  K.recoveryCritical, K.recoveryOwnCritical, K.recoveryWaiters, K.recoveryArrival = nil, nil, nil, nil
  K.recoveryRoster, K.recoveryMissing, K.injuredTeamMember = nil, nil, nil
  K.movementRest, K.moveSnapshot, K.teamStep = nil, nil, nil
  K.enabled = false
  K.mode = "stop"
  K.generation = K.generation + 1
  cancelAllTimers()
  K.route = nil
  clearTarget()
  resetPursuit()
  resetPanicSearch()
  note(reason or "Zatrzymano.", "red")
  if K.updater and K.updater.onBotStopped then K.updater.onBotStopped() end
end

function K.isUpdateSafe()
  if K.enabled or K.reconnectTask or K.shieldPendingTarget or K.sessionBlocked or not K.entitiesReady or K.roomChangePending
      or not K.sessionFresh.combat then return false end
  local state = combatState()
  if state.primary and tostring(state.primary) ~= "" then return false end
  local selfId
  for _, entity in ipairs(entities()) do
    if isSelf(entity) then selfId = tostring(entity.id) break end
  end
  if not selfId then return false end
  for _, relation in ipairs(state.relations or {}) do
    if tostring(relation.attacker) == selfId or tostring(relation.defender) == selfId then return false end
  end
  return true
end

function K.tryResumeAfterReconnect()
  local task = K.reconnectTask
  if not task then return end
  local missing = {}
  if not K.sessionFresh.room then missing[#missing + 1] = "Room.Info" end
  if not K.sessionFresh.entities or not K.entitiesReady or K.roomChangePending then
    missing[#missing + 1] = "Room.Entities"
  end
  if #missing > 0 then
    K.reconnectWaitReason = "Czekam: " .. table.concat(missing, ", ")
    return
  end
  if task.role ~= K.config.role then
    K.stop("Rola zostala zmieniona; poprzednie zadanie anulowane.")
    return
  end
  local own
  for _, entity in ipairs(entities()) do
    if isSelf(entity) then own = entity break end
  end
  local room = currentRoom()
  local vitals = gmcp and gmcp.Char and gmcp.Char.Vitals or {}
  if not own or K.sessionBlocked then
    K.reconnectWaitReason = "Czekam na postac w Room.Entities"
    return
  end
  if not room then K.reconnectWaitReason = "Czekam na numer pokoju mapy" return end
  if not (healthPercent(own) or (K.sessionFresh.vitals and healthPercent(vitals))) then
    K.reconnectWaitReason = "Czekam na kompletne HP postaci"
    return
  end
  if task.name and task.name ~= normal(own.name) then
    K.stop("Zalogowano inna postac; poprzednie zadanie anulowane.")
    return
  end
  -- Room.Info i lista encji z wlasnym HP potwierdzaja powrot do gry.
  -- Group/Combat/Vitals nie zawsze sa ponownie wysylane, gdy stan sie nie
  -- zmienil. Ich stare kopie pozostaja odfiltrowane przez sessionFresh.
  -- Krotka pauza pozwala przetworzyc pozostale pakiety tego samego logowania.
  if not task.snapshotReady then
    K.reconnectWaitReason = "Odebrano pokoj i HP; uzgadniam stan"
    if not K.reconnectTimer then
      later("reconnectTimer", 0.5, function()
        if K.reconnectTask ~= task then return end
        task.snapshotReady = true
        K.tryResumeAfterReconnect()
      end)
    end
    return
  end
  updateVitals()
  local recovery = task.mode == "escape" or task.mode == "heal_rest"
    or task.mode == "recovery_return" or K.config.equipmentHold
  local emergency = K.lastHp < K.config.escapeHp or K.lastMoves <= K.config.restAtMoves
    or (K.config.teamEscapeHp > 0 and K.teamSeenCount > 0 and K.teamLowestHp < K.config.teamEscapeHp)
  local gathering = task.movementRest and task.movementRest.gatherFrom
    and room ~= task.movementRest.gatherFrom
  if not isFollower() and not recovery and not emergency and not gathering then
    local visible = {}
    for _, member in ipairs(groupContext().members) do visible[normal(member.name)] = true end
    for name, displayName in pairs(task.roster) do
      if not visible[name] or K.teamHealth[name] == nil then
        local reason = "Czekam na czlonka druzyny: " .. displayName
        if K.reconnectWaitReason ~= reason then note(reason .. ". Wznowie automatycznie.", "yellow") end
        K.reconnectWaitReason = reason
        return
      end
    end
  end
  K.reconnectTask, K.reconnectWaitReason = nil, nil
  K.enabled = true
  K.route, K.routeIndex = nil, 1
  K.lastRoom = room
  K.mode = isFollower() and "support_wait" or (recovery and "escape" or "patrol")
  if not isFollower() and task.movementRest then
    K.movementRest = task.movementRest
    K.movementRest.afterRevision = task.movementRevision
    K.movementRest.readyAt = now() + 10
    K.movementRest.gatherAttempted = false
    K.movementRest.resumeAfterReconnect = {mode=task.mode, returnRoom=task.returnRoom}
    K.armMovementRest()
  end
  K.lastProgressFingerprint = progressFingerprint()
  note("Polaczenie przywrocone. Automatycznie wznawiam zadanie; baza "
    .. tostring(K.config.startRoom) .. ".", "green")
  if isFollower() then inspectRoom() return end
  markCurrentRoom()
  touchActivity()
  local safe = safetyCheck()
  if recovery or K.mode == "escape" or K.mode == "heal_rest" then
    -- Brak wspierajacego nie blokuje pilnego odwrotu prowadzacego.
    -- Nadal musimy na niego zaczekac w bazie przed wznowieniem patrolu.
    K.recoveryRoster = K.recoveryRoster or {}
    for name, displayName in pairs(task.roster) do K.recoveryRoster[name] = displayName end
  end
  if not safe then return end
  if recovery then
    K.escapeAttempts, K.escapeTailSent = 0, false
    sendEscapeAttempt()
  elseif task.mode == "returning" and task.returnRoom then
    K.pursuitOriginRoom = task.returnRoom
    beginPursuitReturn()
  elseif task.mode == "idle_return" or not K.roomSet[room] then
    K.mode = "idle_return"
    K.idleSteps, K.idleAliasAttempts = 0, 0
    idleReturnStep()
  elseif task.mode == "panic_wait" or task.mode == "panic_search" then
    K.mode = "panic_wait"
    beginPanicSearch()
  elseif task.mode == "kill_pause" then
    K.mode = "kill_pause"
    later("killTimer", K.config.killPause, function()
      if not K.enabled or K.mode ~= "kill_pause" then return end
      K.mode = "patrol"
      inspectRoom()
    end)
  else
    -- Stare ID celu i kierunek oczekujacego ruchu zostaly uniewaznione.
    -- Walke lub dalszy patrol wybieramy na podstawie nowych danych.
    inspectRoom()
  end
end

function K.onSessionEvent(eventName)
  invalidateState(true)
  K.shieldPendingTarget, K.shieldRescue, K.shieldReplyToken = nil, nil, nil
  K.combatRoomReady = false
  K.roomCombatState = nil
  if K.recoveryEmergency then K.recoveryEmergency.pending = nil end
  cancelTimer("shieldReplyTimer")
  K.shieldPositionUntil, K.shieldPositionToken = {}, nil
  cancelTimer("shieldPositionTimer")
  K.progressOwn, K.progressTeam = {}, {}
  K.healthHistory, K.shieldTransfers = {}, {}
  K.previousIncoming, K.transferRevision = nil, nil
  K.shieldFailure = nil
  K.restartPending, K.deadNpcIds = nil, {}
  local wasEnabled = K.enabled
  if wasEnabled and not K.reconnectTask then
    local task = {mode=K.mode, role=K.config.role, roster={}, returnRoom=K.pursuitOriginRoom,
      movementRest=K.movementRest}
    for _, entity in ipairs(entities()) do
      if isSelf(entity) then task.name = normal(entity.name) break end
    end
    if not isFollower() then
      for name, member in pairs(K.moveSnapshot and K.moveSnapshot.roster or K.teamStep and K.teamStep.roster or {}) do
        task.roster[name] = member.name
      end
      for name, member in pairs(K.movementRest and K.movementRest.roster or {}) do
        task.roster[name] = member.name
      end
      for _, member in ipairs(groupContext().members) do
        if not isSelf(member) then task.roster[normal(member.name)] = trim(member.name) end
      end
    end
    K.reconnectTask = task
  end
  if K.reconnectTask then
    K.reconnectTask.snapshotReady = nil
    K.reconnectTask.movementRevision = K.dataRevision
  end
  K.movementRest, K.moveSnapshot, K.teamStep = nil, nil, nil
  K.movementRevision = nil
  K.enabled = false
  K.mode = K.reconnectTask and "reconnect_wait" or "stop"
  K.generation = K.generation + 1
  cancelAllTimers()
  clearTarget()
  resetPursuit()
  resetPanicSearch()
  K.route = nil
  K.roomChangePending = false
  K.entitiesReady = false
  K.sessionBlocked = true
  K.sessionFresh = {room=false, entities=false, combat=false, group=false, vitals=false}
  K.reconnectWaitReason = nil
  K.vitalsSource = nil
  K.shieldAwaitCombatRevision = nil
  if wasEnabled then
    note("Polaczenie z gra przerwane. Po zalogowaniu i odebraniu swiezych danych automatycznie wznowie zadanie.", "yellow")
  end
end

function K.onMoveRejected()
  if not K.enabled or isFollower() or not K.roomChangePending then return end
  local room = currentRoom()
  K.failedExits[room] = K.failedExits[room] or {}
  local direction = normal(K.sentDirection)
  K.failedExits[room][direction] = true
  K.roomChangePending, K.sentDirection = false, nil
  K.entitiesReady = true
  K.patrolMovePending, K.chaseMovePending = false, false
  K.route = nil
  K.moveSnapshot = nil
  if K.limitRoom then cancelTimer("moveTimer") end
  if K.recoveryEmergency then
    K.recoveryEmergency.pending = nil
    cancelTimer("escapeWatchTimer")
    K.recoveryEmergencyStep()
  end
  if K.mode == "patrol" then queueInspection(inspectRoom) end
end

-- Tylko prowadzacy zbiera druzyne. Brak ruchu wspierajacego jest widoczny
-- po przejsciu w aktualnych encjach, bez raportow miedzy profilami.
local function missingTravelMembers(roster)
  local visible, membership, state = {}, {}, groupState()
  for _, member in ipairs(groupContext().members) do visible[normal(member.name)] = true end
  for key, member in pairs(state.members or {}) do
    if type(member) == "table" then
      local id = member.id or member.entity_id or member.obname or member.chimera_source_id
      if id then membership[tostring(id)] = true end
      if member.name or member.desc then membership[normal(member.name or member.desc)] = true end
    else
      membership[tostring(member)] = true
      membership[normal(member)] = true
      if type(key) == "string" then membership[key] = true end
    end
  end
  local missing = {}
  for name, member in pairs(roster or {}) do
    if type(state.members) == "table" and not membership[member.id] and not membership[name] then
      roster[name] = nil -- gracz naprawde opuscil lub rozwiazal druzyne
    elseif not visible[name] then
      missing[#missing + 1] = member.name
    end
  end
  table.sort(missing)
  return missing
end

function K.prepareMovement(command, regroup)
  if isFollower() or K.sessionBlocked then return false end
  if not regroup and (K.movementRest or K.teamStep) then return false end
  local roster = {}
  for _, member in ipairs(groupContext().members) do
    if not isSelf(member) then
      roster[normal(member.name)] = {name=trim(member.name), id=tostring(member.id)}
    end
  end
  K.moveSnapshot = {from=currentRoom(), command=command, roster=roster, regroup=regroup, mode=K.mode}
  return true
end

function K.armMovementRest()
  if K.movementRestTimer or not K.movementRest or not K.enabled or isFollower() then return end
  later("movementRestTimer", 10, function()
    K.tryResumeMovement()
    local rest = K.movementRest
    if not rest then return end
    -- Tylko rzeczywista odmowa wlasnego ruchu, najwyzej raz na 10 s.
    -- Nie odpytujemy postaci wspierajacych ani nie wysylamy im polecen.
    if rest.ownRejected and rest.polledMovementRevision == K.movementRevision then send("stan", false) end
    rest.polledMovementRevision = K.movementRevision
    K.armMovementRest()
  end)
end

local function holdMovement(rest)
  K.movementRest = rest
  K.teamStep, K.route = nil, nil
  for _, timer in ipairs({"moveTimer", "returnTimer", "idleReturnTimer", "panicTimer",
      "escapeWatchTimer", "recoveryTimer", "teamStepTimer"}) do cancelTimer(timer) end
  K.patrolMovePending, K.chaseMovePending = false, false
  K.metrics.movementRests = K.metrics.movementRests + 1
  note(rest.reason .. " Wstrzymuje ruch; wznowie automatycznie po odpoczynku.", "yellow")
  K.armMovementRest()
end

local function gatherTravelTeam(rest)
  if rest.gatherAttempted or not rest.gatherFrom or rest.ownRejected then return end
  rest.gatherAttempted = true
  local ok, exits = pcall(getRoomExits, currentRoom())
  if ok and type(exits) == "table" then
    for direction, destination in pairs(exits) do
      if tonumber(destination) == rest.gatherFrom then
        K.metrics.regroups = K.metrics.regroups + 1
        note("Wracam o jeden pokoj, aby zebrac druzyne.", "yellow")
        sendDirection(directionCommands[normal(direction)] or direction, true)
        break
      end
    end
  end
end

function K.onMovementExhausted()
  if not K.enabled or isFollower() or K.sessionBlocked then return end
  local step = K.moveSnapshot
  -- Odmowa nie oznacza zmiany pokoju ani blednego wyjscia na mapie.
  if K.roomChangePending and step and step.from == currentRoom() then
    K.roomChangePending, K.sentDirection = false, nil
    K.entitiesReady = true
    K.moveSnapshot = nil
    if K.limitRoom then K.limitRoom.attempts = math.max(0, K.limitRoom.attempts - 1) end
    invalidateState(true)
    if K.recoveryEmergency and K.recoveryEmergency.pending then
      K.recoveryEmergency.pending = nil
      K.recoveryEmergency.attempts = math.max(0, K.recoveryEmergency.attempts - 1)
      cancelTimer("escapeWatchTimer")
    end
  end
  local rest = K.movementRest or {roster=step and step.roster or {}, readyAt=now() + 10}
  rest.ownRejected, rest.afterRevision = true, K.dataRevision
  rest.polledMovementRevision = K.movementRevision
  rest.reason = "Gra odmowila ruchu z powodu zmeczenia."
  holdMovement(rest)
end

function K.checkMovementState()
  if K.movementRest then return false end
  local step = K.teamStep
  if not step then return true end
  if not K.entitiesReady then return false end
  local missing = missingTravelMembers(step.roster)
  if #missing == 0 then
    cancelTimer("teamStepTimer")
    K.teamStep, K.regroupFailures = nil, 0
    return true
  end
  if not K.teamStepTimer then
    later("teamStepTimer", 1.0, function()
      if not K.enabled or K.teamStep ~= step or not K.entitiesReady then return end
      if not safetyCheck(true, true) then return end
      missing = missingTravelMembers(step.roster)
      if #missing == 0 then K.teamStep = nil queueInspection(inspectRoom) return end
      K.regroupFailures = math.min(3, K.regroupFailures + 1)
      local rest = {roster=step.roster, readyAt=now() + math.min(30, 10 * K.regroupFailures),
        gatherFrom=step.from, reason="Po przejsciu nie nadaza druzyna: " .. table.concat(missing, ", ") .. "."}
      holdMovement(rest)
      gatherTravelTeam(rest)
    end)
  end
  return false
end

function K.tryResumeMovement()
  local rest = K.movementRest
  if not rest or not K.enabled or isFollower() or K.sessionBlocked or not K.entitiesReady then return end
  updateVitals()
  local escaping = K.mode == "escape"
  if not escaping and now() < rest.readyAt then return end
  if K.movementKnown and K.lastMoves < (escaping and 1 or K.config.resumeAtMoves) then return end
  if rest.ownRejected and (not K.movementRevision or K.movementRevision <= rest.afterRevision) then return end
  if not escaping then
    if #missingTravelMembers(rest.roster) > 0 then gatherTravelTeam(rest) return end
    for name in pairs(rest.roster) do
      if K.teamMoves[name] ~= nil and K.teamMoves[name] < K.config.resumeAtMoves then return end
    end
  end
  K.movementRest = nil
  cancelTimer("movementRestTimer")
  touchActivity()
  note("Druzyna gotowa do ruchu. Automatycznie wznawiam zadanie.", "green")
  if not safetyCheck(true) then return end
  local resume = rest.resumeAfterReconnect
  if not escaping and resume then
    if resume.mode == "returning" and resume.returnRoom then
      K.pursuitOriginRoom = resume.returnRoom
      beginPursuitReturn()
      return
    elseif resume.mode == "idle_return" or not K.roomSet[currentRoom()] then
      K.mode = "idle_return"
    elseif resume.mode == "panic_wait" or resume.mode == "panic_search" then
      K.mode = "panic_wait"
    elseif resume.mode == "kill_pause" then
      K.mode = "kill_pause"
      later("killTimer", K.config.killPause, function()
        K.mode = "patrol"
        inspectRoom()
      end)
      return
    end
  end
  if K.mode == "escape" then sendEscapeAttempt()
  elseif K.mode == "heal_rest" then scheduleHealingCheck()
  elseif K.mode == "recovery_return" then sendRecoveryReturnAttempt()
  elseif K.mode == "idle_return" then idleReturnStep()
  elseif K.mode == "returning" then returnToPursuitOriginStep()
  elseif K.mode == "panic_wait" or K.mode == "panic_search" then
    resetPanicSearch()
    K.mode = "panic_wait"
    beginPanicSearch()
  else queueInspection(inspectRoom) end
end

function K.start(recovered)
  invalidateState(true)
  K.emptyRounds, K.patrolRoundKills, K.emptyPatrolDelay = 0, 0, 0
  if K.sessionBlocked or not K.entitiesReady or K.roomChangePending then
    note("Czekam na swieze dane pokoju i postaci po zalogowaniu lub ruchu.", "yellow")
    return
  end
  if K.reconnectTask then
    note("Czekam na swieze dane i druzyne; zadanie wznowi sie automatycznie.", "yellow")
    return
  end
  if not recovered and K.enabled and (K.mode == "heal_rest" or K.mode == "escape" or K.mode == "recovery_return") then
    note("Trwa wspolny odpoczynek lub powrot. Patrol wznowi sie automatycznie po sprawdzeniu calej druzyny.", "yellow")
    return
  end
  K.restartPending = nil
  if not K.enabled then K.refugeRoom, K.recoveryEmergency, K.escapeOriginRoom = nil, nil, nil end
  K.movementRest, K.moveSnapshot, K.teamStep = nil, nil, nil
  K.recoveryTired, K.regroupFailures = {}, 0
  if not isFollower() and K.config.equipmentHold then
    note(K.config.equipmentHold .. " Po uzupelnieniu wpisz /kozojeb ekwipunek gotowy.", "red")
    return
  end
  if isFollower() then
    K.generation = K.generation + 1
    cancelAllTimers()
    clearTarget()
    resetPursuit()
    resetPanicSearch()
    K.route = nil
    K.enabled = true
    K.mode = "support_wait"
    K.injuredTeamMember = nil
    K.lastRoom = currentRoom()
    note("Start roli: " .. roleLabels[K.config.role]
      .. ". Ruch za prowadzacym zapewnia druzyna w grze.", "green")
    inspectRoom()
    if K.supportWaitReason then note(K.supportWaitReason, "yellow") end
    return
  end
  rebuildRoomSet()
  if #K.rooms == 0 then
    K.enabled = false
    K.mode = "stop"
    cancelAllTimers()
    note("Brak obszaru. Zaznacz pokoje na mapie i wpisz /kozojeb obszar.", "red")
    return
  end
  local room = currentRoom()
  if not room or not K.roomSet[room] then
    K.enabled = false
    K.mode = "stop"
    cancelAllTimers()
    note("Najpierw wejdz do jednego z " .. #K.rooms .. " pokoi obszaru.", "red")
    return
  end
  -- Kazde uruchomienie ustala wspolna baze/reset w miejscu, w ktorym stoimy.
  K.config.startRoom = room
  K.enabled = true
  K.mode = "patrol"
  K.generation = K.generation + 1
  cancelAllTimers()
  K.visited = { [room] = true }
  K.route = nil
  K.entitiesReady = true
  K.idleSteps = 0
  K.routeRecoveryAttempts = 0
  K.herbSearchedRoom = nil
  K.escapeTailSent = false
  K.failedTargetIds = {}
  K.injuredTeamMember = nil
  K.recoveryRoster, K.recoveryMissing, K.recoveryWaiters = nil, nil, nil
  K.recoveryCritical, K.recoveryOwnCritical, K.recoveryArrival = nil, nil, nil
  K.failedExits = {}
  K.lastProgressFingerprint = progressFingerprint()
  clearTarget()
  resetPursuit()
  resetPanicSearch()
  K.saveSettings()
  math.randomseed(os.time())
  note(string.format(
    "Start: baza %d, %d pokoi, patrol %.2f s, pogon %.2f s.",
    K.config.startRoom, #K.rooms, K.config.patrolDelay, K.config.chaseDelay
  ), "green")
  touchActivity()
  -- W trwajacej walce najpierw obowiazuja dotychczasowe decyzje bojowe.
  -- Spokojny start nie moze ominac wspolnego progu regeneracji po aktualizacji.
  updateVitals()
  if K.lastHp <= 0 then safetyCheck() return end
  local actualLeader = groupContext().actualLeader
  if (not actualLeader or isSelf(actualLeader)) and not recoveryThreat() and not K.recoveryReadiness() then
    note("Start patrolu czeka na gotowosc calej druzyny.", "yellow")
    finishEscapeTail()
    return
  end
  K.recoveryRoster, K.recoveryMissing, K.recoveryWaiters = nil, nil, nil
  K.recoveryCritical, K.recoveryOwnCritical = nil, nil
  inspectRoom()
end

function K.setRooms(roomIds)
  K.rooms = copyArray(roomIds or {})
  rebuildRoomSet()
  K.visited = {}
  K.route = nil
  K.emptyRounds, K.patrolRoundKills, K.emptyPatrolDelay = 0, 0, 0
  K.saveSettings()
  note("Ustawiono obszar: " .. #K.rooms .. " pokoi.", #K.rooms > 0 and "green" or "red")
end

function K.roomsFromSelection()
  local selection = getMapSelection and getMapSelection() or nil
  if not selection or type(selection.rooms) ~= "table" or #selection.rooms == 0 then
    note("Brak zaznaczonych pokoi na mapie.", "red")
    return
  end
  K.setRooms(selection.rooms)
end

local STATUS_VALUE_WIDTH = 57

local function statusBorder(character)
  cecho("<cyan>+" .. string.rep(character or "-", 78) .. "+<reset>\n")
end

local function statusRow(label, value)
  value = tostring(value or "")
  if #value > STATUS_VALUE_WIDTH then value = value:sub(1, STATUS_VALUE_WIDTH - 3) .. "..." end
  cecho(string.format(
    "<cyan>|<reset> %-16s <cyan>|<reset> %-" .. STATUS_VALUE_WIDTH .. "s <cyan>|<reset>\n",
    tostring(label or ""), value
  ))
end

local function statusPrefix(label)
  cecho(string.format("<cyan>|<reset> %-16s <cyan>|<reset> ", tostring(label or "")))
end

local function statusLink(label, action, hint, colour, direct)
  local shown = string.format("<%s>%s<reset>", colour or "cyan", label)
  if type(cechoLink) == "function" then
    local code = direct and action or string.format("kozojeb.statusAction(%q)", action)
    cechoLink(shown, code, hint or action, true)
  else
    cecho(shown)
  end
end

local function statusEndRow()
  cecho("\n")
end

function K.clearStatusPanel()
  local first = tonumber(K.statusPanelStart)
  local last = tonumber(K.statusPanelEnd)
  K.statusPanelStart, K.statusPanelEnd = nil, nil
  if not first or not last or last < first then return false end
  if type(getLines) ~= "function" or type(moveCursor) ~= "function"
      or type(deleteLine) ~= "function" then return false end

  -- Numery linii moga sie przesunac po przycieciu bufora. Przed kasowaniem
  -- sprawdzamy podpis panelu, aby nigdy nie usunac przypadkowego logu walki.
  local ok, lines = pcall(getLines, first, math.min(last, first + 3))
  if not ok or type(lines) ~= "table" then return false end
  local signatureFound = false
  for _, line in pairs(lines) do
    if tostring(line):find("KOZOJEB", 1, true) then
      signatureFound = true
      break
    end
  end
  if not signatureFound then return false end

  for line = last, first, -1 do
    local moved, result = pcall(moveCursor, 0, line)
    if moved and result then pcall(deleteLine) end
  end
  if type(moveCursorEnd) == "function" then pcall(moveCursorEnd) end
  return true
end

function K.status()
  K.clearStatusPanel()
  updateVitals()
  local ignored = ignoredNameList()
  local maxCreatures = K.config.maxCreatures == 0 and "brak" or tostring(K.config.maxCreatures)
  local stateColour = K.enabled and "green" or "red"
  local shieldHp = tonumber(K.config.teamShieldHp) or 0
  local escapeCeiling = math.max(K.config.escapeHp, K.config.teamEscapeHp)
  local maxEscapeSetting = not isFollower() and shieldHp > 0 and shieldHp - 1 or 100
  local shieldForms = {}
  for name, form in pairs(K.config.shieldNameForms or {}) do
    if form then shieldForms[#shieldForms + 1] = name .. "->" .. form end
  end
  table.sort(shieldForms)

  if type(moveCursorEnd) == "function" then pcall(moveCursorEnd) end
  cecho("\n")
  local panelStart
  if type(getLineCount) == "function" then
    local ok, value = pcall(getLineCount)
    if ok then panelStart = tonumber(value) end
  end
  statusBorder("-")
  statusPrefix("KOZOJEB " .. K.version)
  cecho("stan: ")
  cecho(string.format("<%s>%s<reset>   pokoj: %s   cel: %s", stateColour, K.mode,
    tostring(currentRoom() or "?"), K.currentTargetName or "brak"))
  statusEndRow()
  statusBorder("=")
  if K.sessionBlocked then statusRow("Polaczenie", "Czekam na zalogowanie i swieze dane") end
  if K.reconnectTask then statusRow("Wznowienie", K.reconnectWaitReason or "Automatyczne po odebraniu swiezych danych") end
  if K.restartPending then statusRow("Wznowienie", "Czekam na swiezy pokoj i kompletne HP; wznowie automatycznie") end
  if K.config.equipmentHold then statusRow("Ekwipunek", K.config.equipmentHold) end
  if K.refugeRoom then statusRow("Miejsce leczenia", "Awaryjne: " .. K.refugeRoom .. "; start patrolu: " .. K.config.startRoom) end
  if K.recoveryEmergency and K.recoveryEmergency.blocked then statusRow("Awaryjny odwrot", "Brak potwierdzonej drogi; nadal chronie druzyne") end
  if K.limitRoom then statusRow("Pomijany pokoj", "Limit celow przekroczony; wyprowadzam druzyne mimo agresji") end
  if K.updater then statusRow("Aktualizacje", K.updater.status or "gotowy") end

  statusPrefix("Sterowanie")
  if K.enabled or K.reconnectTask then
    statusLink("[ STOP ]", "stop", "Zatrzymaj Kozojeba", "red")
  else
    statusLink("[ START ]", "start", "Uruchom Kozojeba", "green")
  end
  cecho("  ")
  statusLink("[ ODSWIEZ ]", "kozojeb.status()", "Odswiez panel", "cyan", true)
  cecho("  ")
  statusLink("[ HELP ]", "kozojeb.help()", "Pelna pomoc", "yellow", true)
  cecho("  ")
  statusLink("[ OBSZAR Z MAPY ]", "obszar", "Pobierz zaznaczenie mapy", "cyan")
  statusEndRow()

  statusPrefix("Rola profilu")
  statusLink("[ PROWADZACY ]", "rola prowadzacy", "Patrol, walka i ochrona druzyny", "cyan")
  cecho(" ")
  statusLink("[ WSPARCIE ]", "rola wsparcie", "Druga linia: wsparcie i DPS", "green")
  cecho(" ")
  statusLink("[ ZASLONY ]", "rola zaslony", "Wsparcie oraz zaslony calej druzyny", "yellow")
  statusEndRow()
  statusRow("Wybrana rola", roleLabels[K.config.role])
  local context = groupContext()
  local leader = context.leader
  local leaderHp = context.leaderHp
  statusPrefix("Lider wsparcia")
  statusLink("[ AUTO ]", "lider auto", "Wykrywaj prowadzacego z GMCP", "cyan")
  cecho("  " .. (K.config.leaderName ~= "" and K.config.leaderName or "auto"))
  cecho(" -> " .. (leader and trim(leader.name) or "brak widocznego"))
  if leaderHp then cecho(" (" .. leaderHp .. "%)") end
  statusEndRow()
  statusPrefix("Prog lidera")
  statusLink("[ - ]", "proglidera " .. math.max(0, K.config.leaderShieldHp - 5), "Zmniejsz prog zaslony lidera", "yellow")
  cecho("  " .. K.config.leaderShieldHp .. "%  ")
  statusLink("[ + ]", "proglidera " .. math.min(100, K.config.leaderShieldHp + 5), "Zwieksz prog zaslony lidera", "green")
  cecho("  (rola zaslony)")
  statusEndRow()
  if isFollower() and K.supportWaitReason then statusRow("Oczekiwanie", K.supportWaitReason) end

  if not isFollower() then
    statusPrefix("Prog HP")
    statusLink("[ - ]", "prog " .. math.max(1, K.config.escapeHp - 5), "Zmniejsz prog odwrotu HP", "yellow")
    cecho(string.format("  %d%% (teraz %d%%)  ", K.config.escapeHp, K.lastHp))
    statusLink("[ + ]", "prog " .. math.min(maxEscapeSetting, K.config.escapeHp + 5), "Zwieksz prog odwrotu HP", "green")
    statusEndRow()
  end
  statusPrefix("Min HP zaslony")
  statusLink("[ - ]", "minhpzaslony " .. math.max(0, K.config.shieldSelfHp - 5), "Zmniejsz minimalne HP zaslaniajacego", "yellow")
  cecho(string.format("  %d%% (ja: %d%%)  ", K.config.shieldSelfHp, K.lastHp))
  statusLink("[ + ]", "minhpzaslony " .. math.min(100, K.config.shieldSelfHp + 5), "Zwieksz minimalne HP zaslaniajacego", "green")
  statusEndRow()
  statusRow("Gotowosc szyku", K.shieldFormationReady and "gotowy" or "czekam na gotowosc z serwera")
  statusRow("Stan walki", K.combatRoomReady and K.sessionFresh.combat and "Aktualne dane pokoju"
    or (K.roomCombatState and #K.roomCombatState.relations > 0 and "Potwierdzony atak w tym pokoju"
      or "Czekam na stan walki biezacego pokoju"))
  if K.movementRest then statusRow("Ruch wstrzymany", K.movementRest.reason) end
  if K.teamStep then
    statusRow("Zebranie druzyny", "Czekam na encje druzyny po ostatnim kroku")
  end

  statusPrefix("Prog druzyny")
  statusLink("[ - ]", "progdruzyny " .. math.max(0, K.config.teamEscapeHp - 5), "Zmniejsz prog HP druzyny", "yellow")
  cecho(string.format("  %d%% (%s: %d%%, widocznych %d)  ",
    K.config.teamEscapeHp, K.teamLowestName, K.teamLowestHp, K.teamSeenCount))
  statusLink("[ + ]", "progdruzyny " .. math.min(maxEscapeSetting, K.config.teamEscapeHp + 5), "Zwieksz prog HP druzyny", "green")
  statusEndRow()
  if isFollower() then statusRow("Odwrot druzyny", "Prog druzyny obsluguje profil prowadzacego") end
  if not isFollower() then
    local minimumRecovery = math.floor(escapeCeiling) + 1
    statusPrefix("Powrot po HP")
    if K.config.recoveryHp > minimumRecovery then
      statusLink("[ - ]", "powrothp " .. math.max(minimumRecovery, K.config.recoveryHp - 5),
        "Zmniejsz prog regeneracji calej druzyny", "yellow")
    else cecho("[ - ]") end
    cecho("  " .. K.config.recoveryHp .. "%  ")
    if K.config.recoveryHp < 100 and minimumRecovery <= 100 then
      statusLink("[ + ]", "powrothp " .. math.max(minimumRecovery, math.min(100, K.config.recoveryHp + 5)),
        "Zwieksz prog regeneracji calej druzyny", "green")
    else cecho("[ + ]") end
    statusEndRow()
    if K.mode == "escape" or K.mode == "heal_rest" or K.mode == "recovery_return" then
      local _, waiters = K.recoveryReadiness()
      for _, waiter in ipairs(waiters) do statusRow("Czekam na powrot", waiter.label) end
    end
  end

  statusPrefix("Prog zaslony")
  if shieldHp <= 0 then
    if escapeCeiling < 100 then
      statusLink("[ WLACZ ]", "progzaslony " .. math.min(100, escapeCeiling + 10),
        "Wlacz automatyczna zaslone", "green")
      cecho("  wylaczony")
    else
      cecho("<red>wylaczony; prog ucieczki 100% nie pozwala go wlaczyc<reset>")
    end
  else
    statusLink("[ WYLACZ ]", "progzaslony 0", "Wylacz automatyczna zaslone", "red")
    cecho(string.format("  %d%% (ja: %d%%)  ", shieldHp, K.lastHp))
    statusLink("[ - ]", "progzaslony " .. math.max(escapeCeiling + 1, shieldHp - 5),
      "Zmniejsz prog zaslony", "yellow")
    cecho(" ")
    statusLink("[ + ]", "progzaslony " .. math.min(100, shieldHp + 5),
      "Zwieksz prog zaslony", "green")
    if K.shieldLastTarget then cecho("  cel: " .. K.shieldLastTarget) end
  end
  statusEndRow()
  if K.config.role == "zaslony" then statusRow("Zaslony druzyny", "Cala druzyna; lider ma osobny prog lidera")
  elseif isFollower() then statusRow("Zaslony druzyny", "Wylaczone w roli wsparcie") end
  statusRow("Odmiany zaslon", #shieldForms > 0 and table.concat(shieldForms, ", ") or "brak (/kozojeb imie)")
  statusRow("Limit zaslony", K.config.shieldMaxAttackers .. " napastnikow; stabilizacja " .. K.config.shieldHold .. " s")
  if K.selfVitals then
    local incoming = context.self and combatSnapshot().incoming[tostring(context.self.id)]
    statusRow("Moje HP / wrogowie", string.format("%.0f/%.0f HP; %d napastnikow",
      K.selfVitals.hp, K.selfVitals.maxhp, incoming and incoming.count or 0))
  end
  if K.shieldBlockedReason then statusRow("Zaslona wstrzymana", K.shieldBlockedReason) end
  if not isFollower() and K.emptyPatrolDelay > 0 then
    statusRow("Pusty patrol", string.format("%d pustych obiegow; ruch co %.1f s", K.emptyRounds, K.emptyPatrolDelay))
  end

  if isFollower() then
    statusRow("Ruch postaci", K.lastMoves .. "% (odwrotem kieruje prowadzacy)")
  else
  statusPrefix("Ruch: odwrot")
  statusLink("[ - ]", string.format("odpoczynek %d %d",
    math.max(0, K.config.restAtMoves - 5), K.config.resumeAtMoves), "Zmniejsz prog niemocy", "yellow")
  cecho(string.format("  %d%% (teraz %d%%)  ", K.config.restAtMoves, K.lastMoves))
  statusLink("[ + ]", string.format("odpoczynek %d %d",
    math.min(K.config.resumeAtMoves - 1, K.config.restAtMoves + 5), K.config.resumeAtMoves), "Zwieksz prog niemocy", "green")
  statusEndRow()

  statusPrefix("Ruch: wznowienie")
  statusLink("[ - ]", string.format("odpoczynek %d %d",
    K.config.restAtMoves, math.max(K.config.restAtMoves + 1, K.config.resumeAtMoves - 5)), "Zmniejsz prog wznowienia", "yellow")
  cecho(string.format("  %d%%  ", K.config.resumeAtMoves))
  statusLink("[ + ]", string.format("odpoczynek %d %d",
    K.config.restAtMoves, math.min(100, K.config.resumeAtMoves + 5)), "Zwieksz prog wznowienia", "green")
  statusEndRow()
  end

  statusPrefix("Tempo patrolu")
  statusLink("[ - ]", string.format("predkosc %.2f", math.max(0.10, K.config.patrolDelay - 0.10)), "Zwolnij patrol", "yellow")
  cecho(string.format("  %.2f s  ", K.config.patrolDelay))
  statusLink("[ + ]", string.format("predkosc %.2f", math.min(10, K.config.patrolDelay + 0.10)), "Przyspiesz patrol", "green")
  cecho(string.format("     pogon: %.2f s", K.config.chaseDelay))
  statusEndRow()

  statusPrefix("Pauza po zabiciu")
  statusLink("[ - ]", string.format("pauza %.1f", math.max(0, K.config.killPause - 1)),
    "Skroc pauze po zabiciu", "yellow")
  cecho(string.format("  %.1f s  ", K.config.killPause))
  statusLink("[ + ]", string.format("pauza %.1f", math.min(60, K.config.killPause + 1)),
    "Wydluz pauze po zabiciu", "green")
  statusEndRow()

  statusPrefix("Szukanie ziol")
  statusLink(
    K.config.herbSearchEnabled and "[ WLACZONE ]" or "[ WYLACZONE ]",
    K.config.herbSearchEnabled and "ziola off" or "ziola on",
    "Przelacz szukanie ziol co pokoj",
    K.config.herbSearchEnabled and "green" or "red"
  )
  cecho("  " .. tostring(K.config.herbSearchCommand))
  if K.config.herbSearchCommand ~= "szukaj ziol" then
    cecho("  ")
    statusLink("[ WSZYSTKIE ]", "ziola on", "Wroc do zwyklego szukania ziol", "cyan")
  end
  statusEndRow()

  statusPrefix("Limit celow")
  statusLink("[ - ]", "maxstworow " .. math.max(0, K.config.maxCreatures - 1), "Zmniejsz limit", "yellow")
  cecho("  " .. maxCreatures .. "  ")
  statusLink("[ + ]", "maxstworow " .. math.min(100, K.config.maxCreatures + 1), "Zwieksz limit", "green")
  cecho("     liczone: " .. (K.config.ignoreNonTargets and "wybrane cele" or "wszystkie NPC"))
  statusEndRow()

  statusPrefix("Ignoruj pozostale")
  statusLink(
    K.config.ignoreNonTargets and "[ WLACZONE ]" or "[ WYLACZONE ]",
    K.config.ignoreNonTargets and "ignoruj pozostale off" or "ignoruj pozostale on",
    "Przelacz ignorowanie NPC spoza listy celow",
    K.config.ignoreNonTargets and "green" or "red"
  )
  cecho("   lista: ")
  if #ignored == 0 then
    cecho("pusta")
  else
    for _, ignoredName in ipairs(ignored) do
      statusLink("[x] " .. ignoredName, "ignoruj usun " .. ignoredName,
        "Usun z ignorowanych: " .. ignoredName, "yellow")
      cecho(" ")
    end
    statusLink("[ WYCZYSC ]", "ignoruj wyczysc", "Wyczysc liste ignorowanych", "red")
  end
  statusEndRow()

  statusRow("Baza i start", "pokoj " .. K.config.startRoom .. " (ustaw: /kozojeb baza)")
  statusPrefix("Watchdog")
  statusLink("[ - ]", string.format("bezczynnosc %.1f %d",
    math.max(5, K.config.idleTimeout - 5), K.config.startRoom), "Skroc czas bezczynnosci", "yellow")
  cecho(string.format("  %.1f s -> pokoj %d  ", K.config.idleTimeout, K.config.startRoom))
  statusLink("[ + ]", string.format("bezczynnosc %.1f %d",
    math.min(600, K.config.idleTimeout + 5), K.config.startRoom), "Wydluz czas bezczynnosci", "green")
  cecho("   obszar: " .. #K.rooms .. " pokoi")
  statusEndRow()

  statusBorder("-")
  statusRow("Kliknij cele", "zielony = atakowany, czerwony = wylaczony")
  local column = 0
  for _, target in ipairs(animalOrder) do
    if column == 0 then statusPrefix("") end
    local active = K.config.animals[target] == true
    local label = string.format("[%s] %-22s", active and "x" or " ", target)
    statusLink(label, "celprzelacz " .. target, "Przelacz cel: " .. target, active and "green" or "red")
    cecho(" ")
    column = column + 1
    if column >= 2 then statusEndRow(); column = 0 end
  end
  if column ~= 0 then statusEndRow() end
  statusBorder("-")
  cecho("<yellow>Klikalne elementy sa w nawiasach [ ]. Dodatkowe ustawienia: /kozojeb help.<reset>\n")
  if panelStart and type(getLineCount) == "function" then
    local ok, value = pcall(getLineCount)
    local panelEnd = ok and tonumber(value) and (tonumber(value) - 1) or nil
    if panelEnd and panelEnd >= panelStart then
      K.statusPanelStart, K.statusPanelEnd = panelStart, panelEnd
    end
  end
end

function K.help()
  cecho([[
<cyan>+--------------------------------------------------------------+
|                       KOZOJEB ]] .. K.version .. [[                           |
+--------------------------------------------------------------+<reset>
<white>  Sterowanie<reset>
  <green>/kozojeb start<reset>                 uruchom wybrana role; prowadzacy
                              ustawia baze i rozpoczyna patrol
  <green>/kozojeb stop<reset>                  zatrzymaj wszystko
  <green>/kozojeb status<reset>                pokaz klikalny panel ustawien
  <green>/kozojeb help<reset>                  wyswietl te pomoc
  <green>/kozojeb repo OWNER/REPO<reset>       ustaw repozytorium wydan GitHub
  <green>/kozojeb aktualizuj<reset>            pobierz nowe wydanie; instalacja
                              po zatrzymaniu bota i zakonczeniu walki
  <green>/kozojeb autoaktualizacja on/off<reset> sprawdzanie wydan w tle
  <green>/kozojeb ekwipunek gotowy<reset>      potwierdz uzupelnienie ekwipunku

<white>  Role druzynowe (ustaw na kazdym profilu osobno)<reset>
  <green>/kozojeb rola prowadzacy<reset>       dotychczasowy patrol i walka;
                              zaslony i odwrot calej druzyny
  <green>/kozojeb rola wsparcie<reset>         druga linia: "wesprzyj" i DPS;
                              bez automatycznych zaslon
  <green>/kozojeb rola zaslony<reset>          wsparcie oraz "zaslon <biernik>"
                              na zagrozonych czlonkow druzyny
  <green>/kozojeb lider auto<reset>            ustal prowadzacego z GMCP (domyslnie)
  <green>/kozojeb lider Yarrim yarrima<reset>   opcjonalnie wskaz imie i biernik
  <green>/kozojeb proglidera 70<reset>          zaslona prowadzacego ponizej 70% HP;
                              0 = wylaczona; prog dotyczy tylko lidera
  <green>/kozojeb progzaslony 70<reset>        prog pozostalych czlonkow w roli zaslony;
                              prowadzacy stosuje go dla calej druzyny
  <green>/kozojeb minhpzaslony 50<reset>       wlasne minimum procentowe;
                              dodatkowo oceniam punkty HP i napastnikow
  <green>/kozojeb limitzaslony 2<reset>        maksymalnie 2 napastnikow po oslonie
  <green>/kozojeb stabilizacja 8<reset>        8 s ochrony przed oddaniem NPC
  <green>/kozojeb pustypatrol 3<reset>         pusty patrol zwalnia do 3 s/krok;
                              0 wylacza spowalnianie (zakres 0-10)
  <green>/kozojeb wydajnosc<reset>             liczniki GMCP, decyzji i komend
  <green>/kozojeb diagnostyka<reset>           stan i czas od GMCP, ciosu i postepu
  - Role, wybor lidera, oba progi zaslony i odmiany sa zapisywane na profilu.
  - Zmiana roli zatrzymuje bota. Po zmianie wpisz /kozojeb start.
  - Wsparcie dziala tylko przy widocznym prowadzacym nalezacym do druzyny.
    Bez druzyny czeka. Nie wymaga zaznaczenia obszaru na profilu wsparcia.
  - Ruch wspierajacych zapewnia podazanie w druzynie w grze; nie patroluja,
    nie gonia NPC i nie wracaja do bazy z powodu samej bezczynnosci.
  - Wspierajacy zawsze pozostaja w druzynie. Niskie HP, niemoc i komunikat
    "Jestes ranny" nie uruchamiaja u nich wlasnego odwrotu ani powrotu.
    Decyzje o odwrocie i wznowieniu podejmuje wylacznie prowadzacy,
    korzystajac z dotychczasowej kontroli HP i stanow druzyny.
  - Ustaw role prowadzacego na postaci, ktora naprawde prowadzi druzyne.
    Zmiana roli w bocie nie przekazuje prowadzenia w grze.

<white>  Obszar i cele<reset>
  <green>/kozojeb obszar<reset>                zapisz pokoje zaznaczone na mapie
  <green>/kozojeb predkosc 0.7<reset>          czekaj 0.7 s przed kolejnym
                              krokiem patrolu (pogon nadal 0.2 s)
  <green>/kozojeb bezczynnosc 20 1322<reset>   opcjonalnie ustaw wspolna baze
                              numerem ID i czas resetu po zastoju
  <green>/kozojeb baza<reset>                  ustaw tutaj wspolna baze/start
  <green>/kozojeb starttu<reset>               to samo co /kozojeb baza
  <green>/kozojeb startpokoj 7965<reset>       ustaw wspolna baze/start po ID
  <green>/kozojeb cele ork goblin waz<reset>    zastap liste atakowanych celow
                              gotowe: koza, kon, krowa, jelen,
                              koziol, byk, zubr, szkielet,
                              sarna, zajac, daniel, borsuk,
                              wilk, kuna, troglodyta, reptilion,
                              zombi, ogr, niedzwiedz, gnoll,
                              ozywieniec, fimir, troll, linkantrop,
                              zwierzoczlek, zolnierz, rycerz, bazant,
                              krasnolud chaosu,
                              snotling, ork,
                              goblin, hobgoblin, waz
  <green>/kozojeb dodajcel troll trolla<reset>  dodaj dowolny wlasny cel oraz
                              forme uzywana w komendzie "zabij"
  <green>/kozojeb usuncel troll<reset>          wylacz wybrany cel
  <green>/kozojeb maxstworow 3<reset>           nie zaczynaj nowej walki, gdy
                              w pokoju sa ponad 3 wybrane cele
                              podczas patrolu wyjdz takze po agresji NPC;
                              0 wylacza limit
  <green>/kozojeb pauza 5<reset>               czekaj 5 sekund po zabiciu
                              (zakres 0-60 sekund)
  <green>/kozojeb ziola on<reset>              po sprawdzeniu bezpiecznego pokoju
                              wykonuj "szukaj ziol" i czekaj na wynik
  <green>/kozojeb ziola off<reset>             wylacz szukanie ziol
  <green>/kozojeb ziola mandragory<reset>      szukaj konkretnego ziola komenda
                              "szukaj mandragory"; wpisany tekst jest
                              wysylany dokladnie po slowie "szukaj"
  <green>/kozojeb ziola szukaj ...<reset>      ustaw dowolna pelna komende
                              zaczynajaca sie od slowa "szukaj"
  <green>/kozojeb ignoruj wszystko<reset>        ignoruj kazdego NPC, ktory nie
                              jest wybranym celem (domyslnie)
  <green>/kozojeb ignoruj pozostale off<reset>   przywroc liczenie i reagowanie
                              na pozostale NPC
  <green>/kozojeb ignoruj dodaj szaman<reset>    zawsze ignoruj nazwy zawierajace
                              cale slowo lub fraze "szaman"
  <green>/kozojeb ignoruj usun szaman<reset>     usun wpis z listy ignorowanych
  <green>/kozojeb ignoruj wyczysc<reset>         wyczysc cala liste bezwzgledna
  <green>/kozojeb ignoruj lista<reset>           pokaz ustawienia ignorowania

<white>  Bezpieczenstwo<reset>
  <green>/kozojeb prog 50<reset>               odwrot przy 50% HP
  <green>/kozojeb progdruzyny 50<reset>        odwrot, gdy widoczny czlonek
                              druzyny spadnie ponizej 50% HP
  <green>/kozojeb progzaslony 70<reset>        wykonuj "zaslon <imie>", gdy
                              czlonek druzyny spadnie ponizej 70% HP
                              (0 = wylacz; prog musi byc wyzszy
                              od obu progow ucieczki)
  <green>/kozojeb imie Pandjed pandjeda<reset> zapisz odmiane uzywana przez
                              komende "zaslon pandjeda"
  <green>/kozojeb imie lista<reset>            pokaz zapisane odmiany
  <green>/kozojeb imie usun Pandjed<reset>     usun zapisana odmiane
  <green>/kozojeb druzyna auto<reset>          wykrywaj czlonkow przez GMCP
  <green>/kozojeb druzyna imie1 imie2<reset>   dodatkowe imiona do pilnowania
  <green>/kozojeb odpoczynek 25 55<reset>      przy 25% ruchu uciekaj do bazy,
                              wroc po regeneracji od 55%
  <green>/kozojeb powrothp 95<reset>           minimum HP kazdego czlonka po leczeniu;
                              stan krytyczny nadal wymaga 100%

<white>  Zasady dzialania<reset>
  - Krowa nie jest atakowana, jezeli w pokoju stoi byk.
  - Koza nie jest atakowana, jezeli w pokoju stoi koziol.
  - Za uciekajacym celem bot biegnie tak dlugo, az go zabije.
  - Po pogoni poza obszar wraca odwrotnymi komendami do miejsca ataku.
  - Po kazdym zabiciu czeka przez czas ustawiony komenda /kozojeb pauza.
  - Szukanie ziol odbywa sie dopiero po walce i przed kolejnym krokiem.
    Bot rusza po wyniku znalezienia/braku ziol albo po 20 s bez odpowiedzi.
  - Po odwrocie cala druzyna osiaga prog /kozojeb powrothp (domyslnie 95%).
  - Stan ponizej progu odwrotu w tej ewakuacji wymaga pelnych 100% HP.
  - Brak gracza, niepelne dane, zmeczenie i uszkodzony sprzet blokuja powrot.
  - Po drodze powrotnej sprawdza gotowosc ponownie przed wznowieniem patrolu.
  - Zaslona wymaga NPC faktycznie atakujacego chroniona osobe w relacjach
    GMCP. Sam atak gracza na NPC nie jest powodem do zaslony.
  - Po probie bot czeka na gotowosc szyku z serwera; dodatkowy odstep
    wynosi co najmniej 2 s. Awaryjne odblokowanie bez komunikatu: 10 s.
  - Wlasne minimum HP zaslaniajacego ustawia /kozojeb minhpzaslony.
  - Poprawne formy z logow: Morrid -> morrida, Yarrim -> yarrima,
    Gror -> grora, Yergo -> yerga. Dla innych graczy ustaw /kozojeb imie.
  - Brak biernika wstrzymuje tylko zaslone tej osoby. Odrzucona forma
    nie jest ponawiana do poprawki. Po komunikacie o odpoczynku w szyku
    bot czeka na gotowosc (awaryjnie do 10 s).
  - Przy niemocy lub niskim ruchu ucieka do tej samej bazy.
  - Po wlasnej panice sprawdza pokoj ucieczki i wszystkie pokoje obok.
  - Po bezczynnosci wraca do wspolnej bazy/startu i wykonuje pelny reset.
  - Gdy mapa nie zna powrotu po pogoni, uzywa odwrotnych komend pogoni.
  - Znikniecie celu bez komunikatu odblokowuje bota po krotkim oczekiwaniu.
  - Limit stworow dotyc nowych pokoi podczas patrolu. Przekroczenie limitu
    zachowuje decyzje o wyjsciu takze po samoczynnym ataku NPC.
  - W pomijanym pokoju nie zaczyna pogoni ani pauzy po przypadkowym zgonie.
    Wybrana wczesniej walka, pogon i pelna pauza po zabiciu pozostaja bez zmian.
  - Brak trasy do reszty nie zatrzymuje bota: rozpoczyna nowe okrazenie,
    a przy braku wyjsc ponawia odczyt mapy.
  - Po rozlaczeniu aktywne zadanie wznawia sie automatycznie po zalogowaniu,
    swiezych danych GMCP i zebraniu druzyny. Baza pozostaje bez zmian.
    /kozojeb stop anuluje rowniez oczekujace automatyczne wznowienie.
  - Prowadzacy reaguje na pekniecie wlasnego lub druzynowego ekwipunku.
    Po jego uzupelnieniu wymagane /kozojeb ekwipunek gotowy.
  - Obszar, cele i ustawienia sa zapisywane osobno dla kazdego profilu.
  - Domyslnie inne NPC nie sa celami, nie przejmuja fokusu i nie licza sie
    do limitu stworow. Lista ignorowanych ma pierwszenstwo przed lista celow.
  - HP druzyny jest czytane z Group.State i group_role encji GMCP.
<cyan>+--------------------------------------------------------------+<reset>
]])
end

local function setAnimals(text)
  local selected = {}
  local requested = normal(text)
  for _, animal in ipairs(animalOrder) do
    if nameHasPlainPhrase(requested, animal) then selected[animal] = true end
  end
  local count = 0
  for _, animal in ipairs(animalOrder) do if selected[animal] then count = count + 1 end end
  if count == 0 then
    note("Podaj co najmniej jeden znany cel. Lista: " .. table.concat(animalOrder, ", "), "red")
    return
  end
  K.config.animals = selected
  K.config.targets = selected
  note("Nowe cele zapisane.", "green")
  K.status()
end

local function addCustomTarget(text)
  local target, form = normal(text):match("^(%S+)%s*(%S*)$")
  if not target or target == "" then
    note("Uzycie: /kozojeb dodajcel troll trolla", "red")
    return
  end
  if not target:match("^[%a%-]+$") then
    note("Identyfikator celu moze zawierac tylko litery i myslnik.", "red")
    return
  end
  local exists = false
  for _, value in ipairs(animalOrder) do if value == target then exists = true break end end
  if not exists then animalOrder[#animalOrder + 1] = target end
  K.config.attackForms[target] = form ~= "" and form or attackWords[target] or target
  K.config.targets[target] = true
  K.config.animals = K.config.targets
  note(string.format("Dodano cel '%s'; komenda ataku: %s %s.", target, K.config.attackCommand, attackForm(target)), "green")
end

local function removeTarget(text)
  local target = normal(text):match("^(%S+)")
  if not target then note("Uzycie: /kozojeb usuncel troll", "red") return end
  K.config.targets[target] = false
  K.config.animals = K.config.targets
  note("Wylaczono cel: " .. target .. ".", "green")
end

local function configureIgnores(text)
  local subcommand, value = trim(text):match("^(%S+)%s*(.-)$")
  subcommand = normal(subcommand or "lista")
  value = trim(value)

  local function showIgnores()
    local ignored = ignoredNameList()
    note(string.format(
      "Ignoruje pozostale NPC: %s | lista bezwzgledna: %s.",
      K.config.ignoreNonTargets and "tak" or "nie",
      #ignored > 0 and table.concat(ignored, ", ") or "pusta"
    ), "cyan")
  end

  local function addName(name)
    name = trim(name)
    if name == "" then
      note("Uzycie: /kozojeb ignoruj dodaj szaman", "red")
      return
    end
    if #name > 80 or name:find("[%c]") then
      note("Nazwa ignorowana musi byc jedna krotka nazwa albo fraza.", "red")
      return
    end
    K.config.ignoredNames[normal(name)] = name
    note("Od teraz zawsze ignoruje NPC pasujacego do: " .. name .. ".", "green")
  end

  if subcommand == "wszystko" or subcommand == "cele" then
    K.config.ignoreNonTargets = true
    note("Ignoruje wszystkie NPC poza aktualnie wybranymi celami.", "green")
  elseif subcommand == "nic" then
    K.config.ignoreNonTargets = false
    note("Nie ignoruje automatycznie pozostalych NPC. Nadal obowiazuje lista bezwzgledna.", "yellow")
  elseif subcommand == "pozostale" then
    local setting = normal(value)
    if setting == "on" or setting == "wlacz" or setting == "tak" or setting == "1" then
      K.config.ignoreNonTargets = true
      note("Ignorowanie NPC innych niz wybrane cele: wlaczone.", "green")
    elseif setting == "off" or setting == "wylacz" or setting == "nie" or setting == "0" then
      K.config.ignoreNonTargets = false
      note("Ignorowanie NPC innych niz wybrane cele: wylaczone.", "yellow")
    else
      note("Uzycie: /kozojeb ignoruj pozostale on|off", "red")
    end
  elseif subcommand == "dodaj" then
    addName(value)
  elseif subcommand == "usun" then
    if value == "" then note("Uzycie: /kozojeb ignoruj usun szaman", "red") return end
    local key = normal(value)
    if K.config.ignoredNames[key] then
      K.config.ignoredNames[key] = nil
      note("Usunieto z listy ignorowanych: " .. value .. ".", "green")
    else
      note("Nie ma takiego wpisu na liscie ignorowanych: " .. value .. ".", "yellow")
    end
  elseif subcommand == "wyczysc" then
    K.config.ignoredNames = {}
    note("Wyczyszczono bezwzgledna liste ignorowanych.", "green")
  elseif subcommand == "lista" or subcommand == "status" then
    showIgnores()
  else
    -- Skrot: /kozojeb ignoruj szaman dziala tak samo jak "ignoruj dodaj".
    addName(trim(text))
  end
  if K.enabled then queueInspection(inspectRoom) end
end

function K.performance()
  local m = K.metrics
  note(string.format("Wydajnosc: GMCP %d; decyzje %d; timery decyzji %d; polaczone zdarzenia %d.",
    m.events, m.actions, m.scheduled, m.coalesced))
  note(string.format("Przeliczenia: HP %d; relacje walki %d; indeks encji %d. Komendy: zaslony %d, wsparcie %d; blokady zaslon %d.",
    m.health, m.combat, m.index, m.shields, m.support, m.shieldBlocked))
  note(string.format("Ataki %d; ponowienia ataku %d; powroty watchdogu %d; oczekiwania restartu %d.",
    m.attacks, m.attackRetries, m.idleResets, m.restartWaits))
  note(string.format("Odpoczynki po odmowie ruchu lub rozdzieleniu druzyny %d; powroty po druzyne %d.",
    m.movementRests, m.regroups))
end

function K.diagnostics(reason)
  local stamp = now()
  local function age(at) return at and string.format("%.1f s", math.max(0, stamp - at)) or "brak" end
  local record = {at=stamp, mode=K.mode, room=currentRoom(), target=K.currentTargetId,
    gmcpAge=K.lastGmcpAt and stamp-K.lastGmcpAt, combatAge=K.lastOwnCombatAt and stamp-K.lastOwnCombatAt,
    activityAge=K.lastActivityAt and stamp-K.lastActivityAt, decisionAge=K.lastDecisionAt and stamp-K.lastDecisionAt,
    combatSource=K.combatRoomReady and K.sessionFresh.combat and "GMCP"
      or (K.roomCombatState and #K.roomCombatState.relations > 0 and "tekst pokoju" or "brak potwierdzenia")}
  note(string.format("Diagnostyka [%s]: wersja %s; tryb=%s; rola=%s; pokoj=%s; cel=%s; encje=%s; ruch=%s; sesja=%s.",
    reason or "recznie", K.version, K.mode, K.config.role, tostring(record.room or "?"),
    tostring(K.currentTargetId or "brak"), tostring(K.entitiesReady), tostring(K.sentDirection or "brak"),
    K.sessionBlocked and "zablokowana" or "aktywna"))
  note(string.format("Czas od: GMCP %s (%s); wlasny cios %s; postep %s; decyzja %s. Pokoj swiezy=%s; walka=%s; ruch oczekuje=%s.",
    age(K.lastGmcpAt), tostring(K.lastGmcpEvent or "brak"), age(K.lastOwnCombatAt),
    age(K.lastActivityAt), age(K.lastDecisionAt), tostring(K.sessionFresh.room),
    record.combatSource, tostring(K.roomChangePending)))
  return record
end

local function executeCommand(arguments)
  local input = trim(arguments)
  local action, rest = input:match("^(%S+)%s*(.-)$")
  action = normal(action or "status")
  if action == "wydajnosc" then
    K.performance()
  elseif action == "diagnostyka" then
    K.performance()
    K.diagnostics()
  elseif action == "powrothp" then
    local value = tonumber(rest)
    if not value or value ~= value or value < 1 or value > 100 or value % 1 ~= 0
        or value <= math.max(K.config.escapeHp, K.config.teamEscapeHp) then
      note("Uzycie: /kozojeb powrothp <1-100>; prog musi byc wyzszy od progow odwrotu.", "red") return
    end
    K.config.recoveryHp = value
    note("Powrot po leczeniu: kazdy czlonek co najmniej " .. value
      .. "% HP; stan krytyczny nadal wymaga 100%. Decyduje profil prowadzacego.", "green")
  elseif action == "limitzaslony" or action == "stabilizacja" or action == "pustypatrol" then
    local value = tonumber(rest)
    local low = action == "limitzaslony" and 1 or (action == "stabilizacja" and 2 or 0)
    local high = action == "limitzaslony" and 5 or (action == "stabilizacja" and 30 or 10)
    if not value or value ~= value or value < low or value > high or value % 1 ~= 0 then
      note("Uzycie: /kozojeb " .. action .. " <" .. low .. "-" .. high .. ">.", "red") return
    end
    if action == "limitzaslony" then K.config.shieldMaxAttackers = value
    elseif action == "stabilizacja" then K.config.shieldHold = value
    else
      K.config.emptyPatrolMax = value
      K.emptyRounds, K.emptyPatrolDelay = 0, 0
    end
    note("Ustawiono " .. action .. ": " .. value .. ".", "green")
  elseif action == "aktualizuj" or action == "autoaktualizacja" or action == "repo" then
    if K.updater then K.updater.command(action, rest)
    else note("Modul aktualizacji nie jest zaladowany.", "yellow") end
  elseif action == "ekwipunek" then
    if normal(rest) ~= "gotowy" then
      note("Po uzupelnieniu uszkodzonego ekwipunku wpisz /kozojeb ekwipunek gotowy.", "yellow")
      return
    end
    K.config.equipmentHold = nil
    note("Potwierdzono gotowosc ekwipunku. Mozna wznowic dzialanie.", "green")
    if K.enabled and K.mode == "heal_rest" then scheduleHealingCheck() end
  elseif action == "rola" then
    local value = normal(rest)
    local aliases = { lider = "prowadzacy", leader = "prowadzacy", dps = "wsparcie",
      wspierajacy = "wsparcie", oslona = "zaslony" }
    value = aliases[value] or value
    if value == "" then note("Rola profilu: " .. roleLabels[K.config.role] .. ".", "cyan") return end
    if not roleLabels[value] then
      note("Uzycie: /kozojeb rola prowadzacy | wsparcie | zaslony", "red") return
    end
    if K.enabled or K.reconnectTask then K.stop("Zmiana roli; anulowano poprzednie dzialania.") end
    K.config.role = value
    saveRoleSettings()
    note("Rola profilu: " .. roleLabels[value] .. ". Uruchom /kozojeb start.", "green")
  elseif action == "lider" or action == "prowadzacy" then
    local name, form = trim(rest):match("^(%S+)%s*(%S*)$")
    if not name then
      note("Lider: " .. (K.config.leaderName ~= "" and K.config.leaderName or "auto (GMCP)") .. ".", "cyan") return
    end
    if not name:match("^[%a%-]+$") or #name > 40
        or (form ~= "" and (not form:match("^[%a%-]+$") or #form > 40))
        or (normal(name) == "auto" and form ~= "") then
      note("Uzycie: /kozojeb lider auto albo /kozojeb lider Yarrim yarrima", "red") return
    end
    K.config.leaderName = normal(name) == "auto" and "" or normal(name)
    if form ~= "" then
      K.config.shieldNameForms[normal(name)] = normal(form)
      K.shieldMissingForms[normal(name)], K.shieldRejectedForms[normal(name)] = nil, nil
    end
    K.supportCombatHint = nil
    K.leaderName, K.leaderHp = nil, nil
    cancelTimer("supportHintTimer")
    saveRoleSettings()
    note("Prowadzacy: " .. (K.config.leaderName ~= "" and name or "auto (GMCP)") .. ".", "green")
    if K.enabled and isFollower() then queueInspection(inspectRoom) end
  elseif action == "proglidera" or action == "zaslonalidera" then
    local value = tonumber(rest)
    if not value or value < 0 or value > 100 or value % 1 ~= 0 then
      note("Uzycie: /kozojeb proglidera 70 (0 wylacza zaslone lidera).", "red") return
    end
    K.config.leaderShieldHp = value
    cancelTimer("shieldTimer")
    K.shieldLastTarget = nil
    saveRoleSettings()
    note(value == 0 and "Zaslona prowadzacego wylaczona." or
      ("Zaslona prowadzacego ponizej " .. value .. "% HP; moje niezalezne minimum HP: "
        .. K.config.shieldSelfHp .. "%."), "green")
  elseif action == "minhpzaslony" or action == "hpzaslaniajacego" then
    local value = tonumber(rest)
    if not value or value < 0 or value > 100 or value % 1 ~= 0 then
      note("Uzycie: /kozojeb minhpzaslony 50 (zakres 0-100%).", "red") return
    end
    K.config.shieldSelfHp = value
    saveRoleSettings()
    note("Minimalne wlasne HP do zaslony: " .. value .. "%. Prog HP chronionej osoby pozostaje niezalezny.", "green")
  elseif action == "start" then K.start()
  elseif action == "stop" then K.stop("Zatrzymano recznie.")
  elseif action == "status" or action == "panel" or action == "config" then K.status()
  elseif action == "help" or action == "pomoc" or action == "?" then K.help()
  elseif action == "obszar" then K.roomsFromSelection()
  elseif action == "predkosc" or action == "tempo" then
    local cleaned = normal(rest):gsub(",", ".")
    local value = tonumber(cleaned)
    if not value or value < 0.10 or value > 10 then
      note("Uzycie: /kozojeb predkosc 0.7 (zakres 0.1-10 sekund).", "red")
      return
    end
    K.config.patrolDelay = value
    note(string.format("Predkosc patrolu: %.2f s miedzy sprawdzeniem pokoju a ruchem.", value), "green")
  elseif action == "pauza" or action == "pozabiciu" or action == "po-zabiciu" then
    -- string.gsub zwraca rowniez liczbe zamian; osobna zmienna zapobiega
    -- potraktowaniu jej przez tonumber jako podstawy systemu liczbowego.
    local cleaned = normal(rest):gsub(",", ".")
    local value = tonumber(cleaned)
    if not value or value < 0 or value > 60 then
      note("Uzycie: /kozojeb pauza 5 (zakres 0-60 sekund).", "red")
      return
    end
    K.config.killPause = value
    note(string.format("Pauza po zabiciu: %.1f s.", value), "green")
  elseif action == "ziola" or action == "szukanieziol" then
    local value = trim(rest)
    local setting = normal(value)
    if setting == "" or setting == "status" then
      note(string.format(
        "Szukanie ziol: %s; komenda: %s.",
        K.config.herbSearchEnabled and "wlaczone" or "wylaczone",
        K.config.herbSearchCommand
      ), "cyan")
      return
    elseif setting == "off" or setting == "wylacz" or setting == "nie" or setting == "0" then
      K.config.herbSearchEnabled = false
      cancelTimer("herbTimer")
      if K.mode == "herb_search" then
        K.herbSearchedRoom = currentRoom()
        K.mode = "patrol"
        queueInspection(inspectRoom)
      end
      note("Szukanie ziol wylaczone.", "yellow")
      return
    elseif setting == "on" or setting == "wlacz" or setting == "tak" or setting == "1"
        or setting == "wszystkie" or setting == "ziol" then
      K.config.herbSearchEnabled = true
      K.config.herbSearchCommand = "szukaj ziol"
    else
      if #value > 100 or value:find("[%c]") then
        note("Nazwa ziola lub komenda jest za dluga albo zawiera niedozwolone znaki.", "red")
        return
      end
      K.config.herbSearchEnabled = true
      if setting:match("^szukaj%s+") then
        K.config.herbSearchCommand = value
      else
        K.config.herbSearchCommand = "szukaj " .. value
      end
    end
    K.herbSearchedRoom = nil
    note("Szukanie ziol wlaczone; komenda: " .. K.config.herbSearchCommand .. ".", "green")
    if K.enabled and K.mode == "patrol" then queueInspection(inspectRoom) end
  elseif action == "bezczynnosc" then
    local timeText, roomText = trim(rest):match("^(%S+)%s*(%d*)$")
    local cleaned = normal(timeText):gsub(",", ".")
    local value = tonumber(cleaned)
    local room = roomText and roomText ~= "" and tonumber(roomText) or nil
    if not value or value < 5 or value > 600 then
      note("Uzycie: /kozojeb bezczynnosc 20 1322 (czas 5-600 s, ID opcjonalne).", "red")
      return
    end
    if roomText and roomText ~= "" and (not room or room < 1) then
      note("ID pokoju bezczynnosci musi byc dodatnia liczba calkowita.", "red")
      return
    end
    K.config.idleTimeout = value
    if room then K.config.startRoom, K.refugeRoom = room, nil end
    note(string.format("Reset bezczynnosci: %.1f s, wspolna baza/start: pokoj %d.", value, K.config.startRoom), "green")
    if K.enabled then touchActivity() end
  elseif action == "starttu" then
    local room = currentRoom()
    if not room then note("Nie potrafie odczytac obecnego pokoju mapy.", "red") return end
    K.config.startRoom, K.refugeRoom = room, nil
    note("Wspolna baza i pokoj startowy ustawione tutaj: " .. room .. ".", "green")
  elseif action == "startpokoj" then
    local room = tonumber(rest)
    if not room or room < 1 or room % 1 ~= 0 then note("Uzycie: /kozojeb startpokoj 7965", "red") return end
    K.config.startRoom, K.refugeRoom = room, nil
    note("Wspolna baza i pokoj startowy ustawione na: " .. room .. ".", "green")
  elseif action == "zwierzeta" or action == "cele" then setAnimals(rest)
  elseif action == "celprzelacz" then
    local target = normal(rest)
    local known = false
    for _, value in ipairs(animalOrder) do if value == target then known = true break end end
    if not known then note("Nieznany cel: " .. tostring(target or "") .. ".", "red") return end
    K.config.targets[target] = not K.config.targets[target]
    K.config.animals = K.config.targets
    note(string.format("Cel %s: %s.", target, K.config.targets[target] and "wlaczony" or "wylaczony"), "green")
  elseif action == "dodajcel" then addCustomTarget(rest)
  elseif action == "usuncel" then removeTarget(rest)
  elseif action == "ignoruj" then configureIgnores(rest)
  elseif action == "maxstworow" or action == "max" then
    local value = tonumber(rest)
    if not value or value < 0 or value > 100 or value % 1 ~= 0 then
      note("Uzycie: /kozojeb maxstworow 3 (0 oznacza brak limitu).", "red")
      return
    end
    K.config.maxCreatures = value
    if K.limitRoom and not K.roomChangePending then
      cancelTimer("moveTimer")
      K.limitRoom, K.patrolMovePending = nil, false
      if K.enabled then queueInspection(inspectRoom) end
    end
    note(value == 0 and "Limit stworow wylaczony." or ("Maksymalnie liczonych celow w nowym pokoju patrolu: " .. value .. "."), "green")
  elseif action == "progdruzyny" or action == "grupa" then
    local value = tonumber(rest)
    if not value or value < 0 or value > 100 then
      note("Uzycie: /kozojeb progdruzyny 50 (0 wylacza odwrot druzyny).", "red")
      return
    end
    if not isFollower() and K.config.teamShieldHp > 0 and value >= K.config.teamShieldHp then
      note(string.format(
        "Prog odwrotu druzyny musi byc nizszy niz prog zaslony %d%%.",
        K.config.teamShieldHp
      ), "red")
      return
    end
    K.config.teamEscapeHp = value
    note(value == 0 and "Pilnowanie HP druzyny wylaczone." or ("Prog odwrotu druzyny: " .. value .. "% HP."), "green")
  elseif action == "imie" or action == "odmiana" then
    local value = trim(rest)
    if value == "" or normal(value) == "lista" then
      local entries = {}
      for name, form in pairs(K.config.shieldNameForms) do
        if form then entries[#entries + 1] = name .. " -> " .. form end
      end
      table.sort(entries)
      note("Odmiany zaslon: " .. (#entries > 0 and table.concat(entries, ", ") or "brak") .. ".", "cyan")
      return
    end
    local removeName = value:match("^[Uu][Ss][Uu][Nn]%s+(%S+)$")
    if removeName then
      local key = normal(removeName)
      K.config.shieldNameForms[key] = false
      K.shieldMissingForms[key], K.shieldRejectedForms[key] = nil, nil
      saveRoleSettings()
      note("Usunieto odmiane imienia: " .. key .. ".", "yellow")
      return
    end
    local name, form = value:match("^(%S+)%s+(%S+)$")
    if not name or not form or #name > 40 or #form > 40
        or name:find("[%c]") or form:find("[%c]") then
      note("Uzycie: /kozojeb imie Pandjed pandjeda", "red")
      return
    end
    name, form = normal(name), normal(form)
    if not name:match("^[%a%-]+$") or not form:match("^[%a%-]+$") then
      note("Imie i biernik moga zawierac litery i myslnik.", "red") return
    end
    K.config.shieldNameForms[name] = form
    K.shieldMissingForms[name], K.shieldRejectedForms[name] = nil, nil
    cancelTimer("shieldTimer")
    saveRoleSettings()
    note("Odmiana zaslony zapisana: " .. name .. " -> " .. form .. " (zaslon " .. form .. ").", "green")
  elseif action == "progzaslony" or action == "zaslona" then
    local value = tonumber(rest)
    if not value or value < 0 or value > 100 or value % 1 ~= 0 then
      note("Uzycie: /kozojeb progzaslony 70 (0 wylacza zaslanianie).", "red")
      return
    end
    local escapeCeiling = math.max(K.config.escapeHp, K.config.teamEscapeHp)
    if value > 0 and value <= escapeCeiling then
      note(string.format(
        "Prog zaslony musi byc wyzszy niz oba progi ucieczki (obecnie maks. %d%%).",
        escapeCeiling
      ), "red")
      return
    end
    cancelTimer("shieldTimer")
    K.shieldLastTarget = nil
    K.config.teamShieldHp = value
    note(value == 0 and (K.config.role == "zaslony"
      and "Zaslony pozostalych czlonkow wylaczone; lider wedlug /kozojeb proglidera."
      or "Automatyczna zaslona wylaczona.") or string.format(
      "Prog zaslony druzyny: %d%%. Minimalne wlasne HP: %d%%.", value, K.config.shieldSelfHp
    ), "green")
  elseif action == "druzyna" then
    local value = normal(rest)
    K.config.teamMembers = {}
    if value ~= "" and value ~= "auto" then
      for name in value:gmatch("[%a%-]+") do K.config.teamMembers[name] = true end
      note("Dodatkowe imiona druzyny: " .. value .. ". Relacje GMCP nadal sa wykrywane automatycznie.", "green")
    else
      note("Automatyczne wykrywanie druzyny z GMCP wlaczone.", "green")
    end
  elseif action == "baza" then
    if trim(rest) ~= "" then note("Uzycie: /kozojeb baza (ustawia obecny pokoj).", "red") return end
    local room = currentRoom()
    if not room then note("Nie potrafie odczytac obecnego pokoju mapy.", "red") return end
    K.config.startRoom, K.refugeRoom = room, nil
    note("Wspolna baza i pokoj startowy ustawione tutaj: " .. room .. ".", "green")
  elseif action == "prog" then
    if isFollower() then
      -- Zgodnosc z 2.7.1: /kozojeb prog na wspierajacym nadal ustawia jego
      -- wlasny limit zaslony, bez zmieniania progow odwrotu prowadzacego.
      K.command("minhpzaslony " .. rest)
      return
    end
    local value = tonumber(rest)
    if not value or value < 1 or value > 100 then note("Prog musi byc liczba 1-100.", "red") return end
    if not isFollower() and K.config.teamShieldHp > 0 and value >= K.config.teamShieldHp then
      note(string.format(
        "Prog odwrotu musi byc nizszy niz prog zaslony %d%%.",
        K.config.teamShieldHp
      ), "red")
      return
    end
    K.config.escapeHp = value
    note("Prog odwrotu: " .. value .. "% HP.", "green")
  elseif action == "odpoczynek" then
    local low, high = rest:match("^(%d+)%s+(%d+)$")
    low, high = tonumber(low), tonumber(high)
    if not low or low < 0 or high > 100 or low >= high then
      note("Uzycie: /kozojeb odpoczynek 25 55", "red") return
    end
    K.config.restAtMoves, K.config.resumeAtMoves = low, high
    note(string.format("Niemoc: odwrot do bazy od %d%% ruchu; powrot od %d%%.", low, high), "green")
  else
    note("Nieznana komenda. Wpisz /kozojeb help.", "yellow")
  end
end

function K.command(arguments)
  invalidateState(true)
  executeCommand(arguments)
  invalidateState(true)
  local action = normal(arguments):match("^(%S+)") or "status"
  if action ~= "status" and action ~= "help" and action ~= "wydajnosc" and action ~= "diagnostyka" then K.saveSettings() end
end

function K.statusAction(action)
  if normal(action) == "status" then
    K.status()
    return
  end
  K.command(action)
  K.status()
end

-- Sprzatanie tymczasowych elementow po ponownym wklejeniu/uruchomieniu pliku.
if K.handlers then
  for _, id in ipairs(K.handlers.triggers or {}) do pcall(killTrigger, id) end
  for _, id in ipairs(K.handlers.aliases or {}) do pcall(killAlias, id) end
  for _, id in ipairs(K.handlers.events or {}) do pcall(killAnonymousEventHandler, id) end
end
K.handlers = { triggers = {}, aliases = {}, events = {} }

K.handlers.triggers[#K.handlers.triggers + 1] = tempRegexTrigger(
  "^([A-Za-z-]+)(?: zrecznie)? zaslania cie przed ciosami ", [[kozojeb.onCoveredByLeader(matches[2])]])
K.handlers.triggers[#K.handlers.triggers + 1] = tempRegexTrigger(
  "^([A-Za-z-]+)(?: zrecznie)? zaslania (.+) przed ciosami ", [[kozojeb.onTeamShield(matches[2], matches[3])]])
K.handlers.triggers[#K.handlers.triggers + 1] = tempRegexTrigger(
  "^Juz walczysz .+\\.$", [[kozojeb.onSupportResult(true)]])
K.handlers.triggers[#K.handlers.triggers + 1] = tempRegexTrigger(
  "^(?:Probujesz trafic |Nie udaje ci sie trafic |Ledwo muskasz |Lekko ranisz |Ranisz |Powaznie ranisz |Ciezko ranisz |Masakrujesz |Wyprowadzasz |Wykonujesz )",
  [[kozojeb.onCombatProgress()]])
K.handlers.triggers[#K.handlers.triggers + 1] = tempRegexTrigger(
  "^Nikt z twojej druzyny nie jest zaangazowany w walke\\.$", [[kozojeb.onSupportResult(false)]])
K.handlers.triggers[#K.handlers.triggers + 1] = tempRegexTrigger(
  "^Umierasz\\.$", [[kozojeb.onDeath()]])
K.handlers.triggers[#K.handlers.triggers + 1] = tempRegexTrigger(
  "^.+ peka!!!$", [[kozojeb.onEquipmentBroken(matches[1])]])
K.handlers.triggers[#K.handlers.triggers + 1] = tempRegexTrigger(
  "^Jestes tak zmeczony, ze nie mozesz isc(?: w tym kierunku)?\\.$",
  [[kozojeb.onMovementExhausted()]])
K.handlers.triggers[#K.handlers.triggers + 1] = tempRegexTrigger(
  "^Nie widzisz zadnego wyjscia prowadzacego na .+\\.$", [[kozojeb.onMoveRejected()]])
K.handlers.triggers[#K.handlers.triggers + 1] = tempRegexTrigger(
  "^(?:Podaj swoje imie:|Witaj, .+ Podaj haslo do konta:|Twoja postac jest juz w grze\\.).*",
  [[kozojeb.onSessionEvent("login")]])

K.handlers.aliases[#K.handlers.aliases + 1] = tempAlias("^/kozojeb(?:\\s+(.*))?$", [[kozojeb.command(matches[2] or "status")]])
K.handlers.triggers[#K.handlers.triggers + 1] = tempRegexTrigger(
  "^(.+) ATAKUJE (.+)\\.$", [[kozojeb.onTeamCombat(matches[2], matches[3], true)]])
K.handlers.triggers[#K.handlers.triggers + 1] = tempRegexTrigger(
  "^(.+) ATAKUJE CIE!$", [[kozojeb.onTeamCombat(matches[2], "cie", true)]])
K.handlers.triggers[#K.handlers.triggers + 1] = tempRegexTrigger(
  "^(.+) WSPIERA (.+) w walce z .+\\.$", [[kozojeb.onTeamCombat(matches[2], matches[3])]])
K.handlers.triggers[#K.handlers.triggers + 1] = tempRegexTrigger(
  "^Kogo chcesz zaslonic\\?$", [[kozojeb.onShieldRejected()]])
K.handlers.triggers[#K.handlers.triggers + 1] = tempRegexTrigger(
  "^Zaslaniasz (.+) przed ciosami ", [[kozojeb.onShieldResult(matches[2], true)]])
K.handlers.triggers[#K.handlers.triggers + 1] = tempRegexTrigger(
  "^Probujesz zaslonic (.+) przed ciosami ", [[kozojeb.onShieldResult(matches[2], false)]])
K.handlers.triggers[#K.handlers.triggers + 1] = tempRegexTrigger(
  "^Musisz chwile odpoczac po ostatniej zmianie w szyku\\.$", [[kozojeb.onShieldCooldown()]])
K.handlers.triggers[#K.handlers.triggers + 1] = tempRegexTrigger(
  "^Dopiero co zepchnieto cie sprzed ([^;]+);", [[kozojeb.onShieldPositionBlocked(matches[2])]])
K.handlers.triggers[#K.handlers.triggers + 1] = tempRegexTrigger(
  "^Jestes gotowy do zmiany w szyku\\.$", [[kozojeb.onFormationReady()]])
K.handlers.triggers[#K.handlers.triggers + 1] = tempRegexTrigger(
  "^([^\\.]+) uciekl[ao]? ci\\.$",
  [[kozojeb.onFleeAnnounced(matches[2])]])
K.handlers.triggers[#K.handlers.triggers + 1] = tempRegexTrigger(
  "w panice wybiega na (polnocny-wschod|polnocny-zachod|poludniowy-wschod|poludniowy-zachod|polnoc|poludnie|wschod|zachod|gore|gora|dol)\\.",
  [[kozojeb.onFleeDirection(matches[2])]])
K.handlers.triggers[#K.handlers.triggers + 1] = tempRegexTrigger(
  "\\[\\d+\\] ([^\\.]+) podaza na (polnoc|poludnie|wschod|zachod|polnocny-wschod|polnocny-zachod|poludniowy-wschod|poludniowy-zachod|gore|dol)\\.",
  [[kozojeb.onFlee(matches[2], matches[3])]])
K.handlers.triggers[#K.handlers.triggers + 1] = tempRegexTrigger("^(.+) polegl[ao]?\\.$", [[kozojeb.onKill(matches[2], false)]])
K.handlers.triggers[#K.handlers.triggers + 1] = tempRegexTrigger("^Zabiles (.+)\\. \\[", [[kozojeb.onKill(matches[2], true)]])
K.handlers.triggers[#K.handlers.triggers + 1] = tempRegexTrigger(
  "^.+ zabil[ao]? (.+)\\. \\[",
  [[kozojeb.onKill(matches[2], true)]])
K.handlers.triggers[#K.handlers.triggers + 1] = tempRegexTrigger(
  "^Nie widzisz zadnej takiej osoby\\.$",
  [[kozojeb.onAttackRejected()]])
K.handlers.triggers[#K.handlers.triggers + 1] = tempRegexTrigger(
  "^Zaczynasz szukac ziol\\.$",
  [[kozojeb.onHerbSearchStarted()]])
K.handlers.triggers[#K.handlers.triggers + 1] = tempRegexTrigger(
  "^(?:Znajdujesz .+\\.|Szukasz wszedzie, ale nie znajdujesz zadnych ziol\\.)$",
  [[kozojeb.onHerbSearchFinished()]])
K.handlers.triggers[#K.handlers.triggers + 1] = tempRegexTrigger("^Jestes rann[ya]\\.?$", [[if kozojeb.enabled then kozojeb.escape("Stan postaci: ranny.") end]])
K.handlers.triggers[#K.handlers.triggers + 1] = tempRegexTrigger("Wpadasz w panike!", [[kozojeb.onPanic()]])
K.handlers.triggers[#K.handlers.triggers + 1] = tempRegexTrigger("Uciekles [^\\.]+\\.", [[kozojeb.onPanicLanded()]])
K.handlers.triggers[#K.handlers.triggers + 1] = tempRegexTrigger(
  "(?:Jestes zbyt zmeczony|Ogarnia cie niemoc|Czujesz ogarniajaca cie niemoc|Nie masz dosc sil|Nie masz na to sily)",
  [[if kozojeb.enabled then kozojeb.escape("Serwer zglosil niemoc lub wyczerpanie.") end]])

for _, eventName in ipairs({
  "gmcp.Chimera.Room.Entities", "gmcp.Chimera.Combat.State",
  "gmcp.Chimera.Group.State", "gmcp.Char.Vitals",
}) do
  K.handlers.events[#K.handlers.events + 1] = registerAnonymousEventHandler(eventName, "kozojeb.onGmcp")
end
for _, eventName in ipairs({ "gmcp.Room.Info", "sysSpeedwalkFinished" }) do
  K.handlers.events[#K.handlers.events + 1] = registerAnonymousEventHandler(eventName, "kozojeb.onRoomChanged")
end
for _, eventName in ipairs({"sysDisconnectionEvent", "sysConnectionEvent"}) do
  K.handlers.events[#K.handlers.events + 1] = registerAnonymousEventHandler(eventName, "kozojeb.onSessionEvent")
end
K.handlers.events[#K.handlers.events + 1] = registerAnonymousEventHandler("sysDataSendRequest", "kozojeb.onShieldCommand")
K.handlers.events[#K.handlers.events + 1] = registerAnonymousEventHandler("sysExitEvent", "kozojeb.saveSettings")
function K.onUninstall(_, packageName)
  if packageName ~= "Chimera_Kozojeb" then return end
  K.saveSettings()
  K.stop("Usuwanie lub aktualizacja paczki.")
  cancelTimer("formationTimer")
  cancelTimer("shieldReplyTimer")
  cancelTimer("shieldPositionTimer")
  K.shieldPositionToken = nil
  K.shieldReplyToken = nil
  K.formationToken = nil
  for _, id in ipairs(K.handlers.triggers) do pcall(killTrigger, id) end
  for _, id in ipairs(K.handlers.aliases) do pcall(killAlias, id) end
  for _, id in ipairs(K.handlers.events) do pcall(killAnonymousEventHandler, id) end
  if K.updater and not K.updater.installing then K.updater.cleanup() end
end
K.handlers.events[#K.handlers.events + 1] = registerAnonymousEventHandler("sysUninstallPackage", "kozojeb.onUninstall")

rebuildRoomSet()
K.initialized = true
note("Wersja " .. K.version .. " zaladowana. Wpisz /kozojeb status, aby otworzyc klikalny panel.", "cyan")
