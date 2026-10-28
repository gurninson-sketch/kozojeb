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
--   /kozojeb rola zaslony            - wsparcie i ochrona prowadzacego
--   /kozojeb lider auto              - wykrywaj prowadzacego przez GMCP
--   /kozojeb proglidera 70           - prog HP zaslony prowadzacego
--   /kozojeb minhpzaslony 50         - niezalezne minimalne HP zaslaniajacego
--   /kozojeb predkosc 0.7            - opoznienie ruchu podczas patrolu
--   /kozojeb bezczynnosc 20 1322     - reset po zastoju do podanego pokoju
--   /kozojeb cele snotling ork waz    - wybierz dowolne gatunki NPC do ataku
--   /kozojeb maxstworow 3             - nie zaczynaj ataku przy wiecej niz 3 NPC
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

K.version = "2.9.0"
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
  equipmentHold="string",
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
K.lastHp = 100
K.lastMoves = 100
K.teamLowestHp = 100
K.teamLowestName = "ty"
K.teamSeenCount = 1
K.teamHealth = {}
K.injuredTeamMember = nil
K.escapeTailSent = false
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
K.vitalsCacheRevision = nil
K.healthHistory, K.shieldTransfers = {}, {}
K.previousIncoming = nil
K.transferRevision, K.lastHealthObservationRevision = nil, nil
K.lastActivityAt = nil
K.shieldFailure, K.shieldBlockedReason = nil, nil
K.supportAttempt = nil
K.emptyRounds, K.patrolRoundKills, K.emptyPatrolDelay = 0, 0, 0
K.metrics = {events=0, actions=0, scheduled=0, coalesced=0, health=0,
  combat=0, shields=0, shieldBlocked=0, support=0, index=0}

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

local function invalidateState(health)
  K.dataRevision = K.dataRevision + 1
  K.groupContextCache, K.entityIndexCache, K.combatCache = nil, nil, nil
  if health then K.hpRevision = K.hpRevision + 1 end
end

-- Ustawienia rol sa lokalne dla profilu Mudleta. Nie wymagaja polaczenia
-- miedzy profilami: sklad, prowadzacego i walke potwierdza serwer przez GMCP.
local roleLabels = {
  prowadzacy = "prowadzacy",
  wsparcie = "druga linia: wsparcie i DPS",
  zaslony = "wsparcie i zaslony prowadzacego",
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
    "supportTimer", "supportHintTimer", "shieldReplyTimer", "reconnectTimer",
  }) do
    cancelTimer(name)
  end
  K.patrolMovePending = false
  K.chaseMovePending = false
  K.pendingFleeName = nil
  K.idleAliasActive = false
  K.shieldLastTarget = nil
  K.supportCombatHint = nil
  K.supportLastTarget = nil
  K.shieldPendingTarget = nil
  K.supportAttempt = nil
  -- Gotowosc szyku opisuje stan w grze; stop/start lub zmiana roli jej
  -- nie odnawia. Osobny formationTimer dziala tez podczas pauzy bota.
end

-- Lista encji z poprzedniego pokoju nie moze wywolac ataku po wyslaniu
-- kierunku. Dopiero Room.Info, a nastepnie nowa lista encji zwalnia blokade.
local function sendDirection(command)
  K.roomChangePending = true
  K.entitiesReady = false
  K.sentDirection = command
  send(command)
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
  return K.mode == "stop" or K.mode == "kill_pause"
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
  local index = {}
  for _, entity in ipairs(entities()) do
    if entity.id ~= nil then index[tostring(entity.id)] = entity end
  end
  K.metrics.index = K.metrics.index + 1
  K.entityIndexCache = index
  return index
end

local function combatState()
  if not K.sessionFresh.combat then return {} end
  return gmcp and gmcp.Chimera and gmcp.Chimera.Combat and gmcp.Chimera.Combat.State or {}
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
        if ref.hp ~= nil then memberVitals[tostring(id)] = ref end
      end
      if name then
        names[normal(name)] = true
        if ref.hp ~= nil then memberVitals[normal(name)] = ref end
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
  if K.currentTargetId and tostring(entity.id or "") == tostring(K.currentTargetId) then return true end
  return normal(entity.name) == normal(K.currentTargetName)
end

local function combatTargetAllowed(entity)
  if not entity or nameHasIgnoredPhrase(entity.name) then return false end
  -- Podczas walki/pogoni tylko juz wybrany, konkretny NPC moze przejac fokus.
  -- Inne cele tego samego gatunku rowniez sa wtedy ignorowane.
  if K.currentTargetName then return isCurrentTarget(entity) end
  return not K.config.ignoreNonTargets or animalInName(entity.name) ~= nil
end

local function entityById(id)
  if not id then return nil end
  return entityIndex()[tostring(id)]
end

local function currentTargetEntity()
  local target = entityById(K.currentTargetId)
  if target then return target end
  if not K.currentTargetName then return nil end
  for _, entity in ipairs(entities()) do
    if entity.kind == "npc" and normal(entity.name) == normal(K.currentTargetName) then
      return entity
    end
  end
  return nil
end

local function activeCombatTarget()
  local state = combatState()
  local id = state.primary
  if id and id ~= "" then
    local entity = entityById(id)
    if entity and entity.kind == "npc" and (not tonumber(entity.hp) or tonumber(entity.hp) > 0) then return entity end
  end
  local selfId
  for _, entity in ipairs(entities()) do
    if isSelf(entity) then selfId = tostring(entity.id) break end
  end
  if not selfId then return nil end
  for _, relation in ipairs(state.relations or {}) do
    local opponent
    if tostring(relation.attacker) == selfId then opponent = relation.defender
    elseif tostring(relation.defender) == selfId then opponent = relation.attacker end
    local entity = opponent and entityById(opponent)
    if entity and entity.kind == "npc" and (not tonumber(entity.hp) or tonumber(entity.hp) > 0) then return entity end
  end
  return nil
end

local function hostileTarget()
  local combat = activeCombatTarget()
  if combatTargetAllowed(combat) then return combat end
  for _, entity in ipairs(entities()) do
    if entity.kind == "npc" and entity.self ~= 1 and entity.relation == "hostile"
        and combatTargetAllowed(entity) then
      return entity
    end
  end
  return nil
end

local function findTarget()
  local bullPresent = false
  local maleGoatPresent = false
  local creatureCount = 0
  for _, entity in ipairs(entities()) do
    if entity.kind == "npc" and entity.self ~= 1 then
      if nameHasAnimal(entity.name, "byk") then bullPresent = true end
      if nameHasAnimal(entity.name, "koziol") then maleGoatPresent = true end
      local selected = animalInName(entity.name) ~= nil
      if not nameHasIgnoredPhrase(entity.name)
          and (not K.config.ignoreNonTargets or selected) then
        creatureCount = creatureCount + 1
      end
    end
  end
  for _, animal in ipairs(animalOrder) do
    if K.config.animals[animal] then
      for _, entity in ipairs(entities()) do
        local cowBlocked = animal == "krowa" and bullPresent
        local goatBlocked = animal == "koza" and maleGoatPresent
        if not cowBlocked and not goatBlocked
            and entity.kind == "npc" and entity.self ~= 1
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
  local roomHp
  local roomEntities = entities()
  for _, entity in ipairs(roomEntities) do
    if isSelf(entity) then
      roomHp = healthPercent(entity)
      break
    end
  end
  local vitals = gmcp and gmcp.Char and gmcp.Char.Vitals or {}
  local charHp = healthPercent(vitals)
  -- Kazde zrodlo musi dostarczyc wlasna kompletna pare hp/maxhp. Skale
  -- Char.Vitals i Room.Entities moga sie roznic. W trakcie ruchu encje sa
  -- niedostepne; niepelny pakiet nie zmienia ostatniego poprawnego HP.
  local hp = roomHp or charHp
  if K.vitalsSource == "char" then
    hp = charHp or roomHp
  end
  local moves = tonumber(vitals.moves)
  local maxmoves = tonumber(vitals.maxmoves)
  if hp then K.lastHp = hp end
  if moves and maxmoves and maxmoves > 0 then K.lastMoves = math.floor(moves * 100 / maxmoves + 0.5) end

  local context = groupContext()
  local state = groupState()
  local own = context.self
  local ownGroup = own and (context.memberVitals[tostring(own.id)] or context.memberVitals[normal(own.name)])
  local groupOwnHp = healthPercent(ownGroup)
  if groupOwnHp and K.sourceRevisions.group > math.max(K.sourceRevisions.entities, K.sourceRevisions.char) then
    K.lastHp = groupOwnHp
  end
  local healthByName, rawByName, counted = {}, {}, {}
  local lowest, lowestName, seen = 101, nil, 0
  local function consider(entity, member, id, name)
    if isSelf(entity) or isSelf(member) or (own and id and tostring(id) == tostring(own.id)) then return end
    local key = normal(name or id)
    if key == "" or counted[key] then return end
    local value = latestHealth(K.entitiesReady and entity or nil, member)
    if not value then return end
    counted[key] = true
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
  K.teamSeenCount = seen
  K.teamLowestHp = seen > 0 and lowest or 100
  K.teamLowestName = seen > 0 and lowestName or "brak wykrytej druzyny"
  K.teamHealth, K.teamVitals = healthByName, rawByName
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
            if loss > 0 then value.shock, value.lossAt = loss, time
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

local function clearTarget()
  cancelTimer("focusTimer")
  cancelTimer("targetLostTimer")
  cancelTimer("killConfirmTimer")
  K.focusRetryPending = false
  K.currentTargetId = nil
  K.currentTargetName = nil
  K.currentTargetAnimal = nil
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

local function finishRecoveryReturn()
  if isFollower() then return end
  cancelTimer("recoveryTimer")
  resetPursuit()
  K.start()
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

local function scheduleHealingCheck()
  later("healTimer", 3.0, function()
    updateVitals()
    if not K.enabled or isFollower() or K.mode ~= "heal_rest" then return end
    local currentTeamSafe = K.teamSeenCount == 0 or K.config.teamEscapeHp <= 0
      or K.teamLowestHp > K.config.teamEscapeHp
    local trackedReady = true
    if K.injuredTeamMember then
      local trackedHp = K.teamHealth[normal(K.injuredTeamMember)]
      -- Brak gracza w aktualnym GMCP nie oznacza wyzdrowienia. Czekamy, az
      -- ponownie go zobaczymy i serwer potwierdzi pelne 100% HP.
      trackedReady = trackedHp ~= nil and trackedHp >= 100
    end
    local teamReady = currentTeamSafe and trackedReady
    K.recoveryMissing = nil
    local visible = {}
    if K.entitiesReady then
      for _, member in ipairs(groupContext().members) do visible[normal(member.name)] = true end
    end
    for name, displayName in pairs(K.recoveryRoster or {}) do
      if not visible[name] or K.teamHealth[name] == nil then
        teamReady = false
        K.recoveryMissing = displayName
        break
      end
    end
    if K.lastHp >= 100 and K.lastMoves >= K.config.resumeAtMoves and teamReady
        and not K.config.equipmentHold then
      K.mode = "recovery_return"
      K.recoveryAttempts = 0
      note("HP wrocilo do pelni. Wracam przez /idz do startu patrolu.", "green")
      sendRecoveryReturnAttempt()
    else
      -- GMCP wystarcza do biezacej kontroli. Pytamy tekstowo tylko wtedy,
      -- gdy przez 15 s nie otrzymalismy kolejnej aktualizacji HP.
      if K.healingVitalsRevision ~= K.vitalsRevision then
        K.healingVitalsRevision, K.healPollTicks = K.vitalsRevision, 0
      end
      K.healPollTicks = (K.healPollTicks or 0) + 1
      if K.healPollTicks >= 5 and K.lastHp < 100 then
        send("kondycja", false)
        K.healPollTicks = 0
      end
      scheduleHealingCheck()
    end
  end)
end

local function finishEscapeTail()
  if isFollower() then return end
  if K.escapeTailSent then return end
  cancelTimer("escapeWatchTimer")
  K.escapeTailSent = true
  K.mode = "heal_rest"
  K.healPollTicks = 0
  updateVitals()
  local waitingFor = K.injuredTeamMember and (" oraz na 100% HP " .. K.injuredTeamMember) or ""
  note("Jestem w bazie. Czekam na swoje 100% HP" .. waitingFor .. ".", "yellow")
  if K.config.equipmentHold then
    note("Po uzupelnieniu ekwipunku wpisz /kozojeb ekwipunek gotowy.", "yellow")
  end
  scheduleHealingCheck()
end

local function sendEscapeAttempt()
  if not K.enabled or isFollower() or K.mode ~= "escape" then return end
  if currentRoom() == tonumber(K.config.startRoom) then
    finishEscapeTail()
    return
  end
  K.escapeAttempts = (K.escapeAttempts or 0) + 1
  if K.escapeAttempts > K.config.escapeMaxAttempts then
    K.stop(string.format(
      "Nie udalo sie dotrzec przez /idz do bazy %d po %d probach.",
      K.config.startRoom, K.config.escapeMaxAttempts
    ))
    return
  end
  note(string.format(
    "Proba dojscia do bazy %d: %d/%d.",
    K.config.startRoom, K.escapeAttempts, K.config.escapeMaxAttempts
  ), "yellow")
  expandAlias("/idz " .. K.config.startRoom)
  later("escapeWatchTimer", K.config.escapeRetryDelay, sendEscapeAttempt)
end

function K.escape(reason, injuredTeamMember)
  -- Kazda droga do odwrotu, takze tekstowe triggery "ranny" i "niemoc",
  -- konczy sie tutaj. Wspierajacy nigdy nie uruchamiaja wlasnego /idz,
  -- leczenia ani powrotu. Decyzje dla druzyny podejmuje prowadzacy.
  if isFollower() then return end
  if K.mode == "escape" or K.mode == "heal_rest" or K.mode == "recovery_return" then return end
  K.recoveryRoster = {}
  for _, member in ipairs(groupContext().members) do
    if not isSelf(member) then K.recoveryRoster[normal(member.name)] = trim(member.name) end
  end
  K.enabled = true -- monitorujemy dojscie do bazy mimo zatrzymania patrolu
  K.mode = "escape"
  K.generation = K.generation + 1
  cancelAllTimers()
  K.route = nil
  clearTarget()
  resetPursuit()
  resetPanicSearch()
  K.escapeTailSent = false
  K.escapeAttempts = 0
  K.injuredTeamMember = injuredTeamMember and trim(injuredTeamMember) or nil
  note((reason or "Awaryjny odwrot.") .. " Ide przez /idz " .. K.config.startRoom .. ".", "red")
  if currentRoom() == tonumber(K.config.startRoom) then
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

local function pressure(count)
  return count * (1 + math.max(0, count - 1) * 0.5)
end

local function combatSnapshot()
  if K.combatCache then return K.combatCache end
  local snapshot = {incoming={}, owners={}}
  local index = entityIndex()
  for _, relation in ipairs(combatState().relations or {}) do
    local attacker, defender = index[tostring(relation.attacker)], index[tostring(relation.defender)]
    if attacker and attacker.kind == "npc" and defender and defender.kind ~= "npc"
        and (not tonumber(attacker.hp) or tonumber(attacker.hp) > 0) then
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
  ownHp = math.min(ownHp, ownMax * K.lastHp / 100)
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

local function shieldImprovesSafety(target, percent)
  local own = groupContext().self
  if not own or not own.id or not target.id then return false, "Brak identyfikatorow graczy" end
  local snapshot = combatSnapshot()
  local ownId, targetId = tostring(own.id), tostring(target.id)
  local ownIncoming = snapshot.incoming[ownId] or {count=0, npcs={}}
  local targetIncoming = snapshot.incoming[targetId]
  if not targetIncoming or targetIncoming.count == 0 then return false, "Brak napastnika NPC" end
  local ownBudget, targetBudget, ownHp, targetHp = shieldHealthPair(own, target)
  if not ownBudget then return false, "Brak porownywalnych HP w punktach" end
  local before = math.max(pressure(ownIncoming.count) / ownBudget,
    pressure(targetIncoming.count) / targetBudget)
  local worstAfter, reverse = 0, false
  for id in pairs(targetIncoming.npcs) do
    local afterCount = ownIncoming.count + (ownIncoming.npcs[id] and 0 or 1)
    if afterCount > K.config.shieldMaxAttackers then
      return false, "Limit napastnikow po zaslonie: " .. afterCount
    end
    local after = math.max(pressure(afterCount) / ownBudget,
      pressure(targetIncoming.count - 1) / targetBudget)
    worstAfter = math.max(worstAfter, after)
    local transfer = K.shieldTransfers[id]
    if transfer and transfer.untilTime > now() and transfer.from == ownId and transfer.to == targetId then
      reverse = true
    end
  end
  if worstAfter > before * 0.85 then return false, "Za maly zapas obrony po zaslonie" end
  if reverse and percent >= math.min(100, K.config.escapeHp + 15) and worstAfter > before * 0.60 then
    return false, "Stabilizacja po przejeciu NPC"
  end
  K.shieldDecision = {ownHp=ownHp, targetHp=targetHp, ownAttackers=ownIncoming.count,
    targetAttackers=targetIncoming.count}
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

local function tryShield(entity, hp, threshold)
  if not K.enabled or threshold <= 0 or K.shieldTimer or not K.shieldFormationReady then return end
  if K.shieldAwaitCombatRevision == K.combatRevision then return end
  if not hp or hp >= threshold or K.lastHp <= 0 or K.lastHp < K.config.shieldSelfHp then return end
  if not incomingNpc(entity) then return end
  local improves, reason = shieldImprovesSafety(entity, hp)
  if not improves then
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
  K.shieldLastTarget = target
  K.shieldPendingTarget = { name = target, form = form, id=tostring(entity.id), hp=hp,
    combatRevision = K.combatRevision }
  K.shieldBlockedReason = nil
  note(string.format(
    "Zaslaniam %s (%d%% HP, prog %d%%).",
    form:gsub("^%l", string.upper), hp, threshold
  ), "yellow")
  -- Rezerwacja przed send chroni tez przed pakietami/odpowiedziami
  -- przychodzacymi bezposrednio podczas wykonania polecenia.
  waitForFormation()
  later("shieldTimer", K.config.teamShieldInterval, function() end)
  later("shieldReplyTimer", 2.0, function() K.shieldPendingTarget = nil end)
  send("zaslon " .. form)
  K.metrics.shields = K.metrics.shields + 1
  touchActivity()
  return true
end

function K.onShieldRejected()
  local pending = K.shieldPendingTarget
  if not K.enabled or not pending then return end
  K.shieldRejectedForms[normal(pending.name)] = pending.form
  K.shieldPendingTarget = nil
  cancelTimer("shieldReplyTimer")
  -- Odrzucona nazwa nie zuzywa zmiany szyku.
  K.shieldFormationReady = true
  K.formationToken = nil
  cancelTimer("formationTimer")
  note("Gra nie rozpoznala 'zaslon " .. pending.form .. "'. Sprawdz /kozojeb imie "
    .. pending.name .. " <biernik>. Ta forma nie bedzie ponawiana do poprawki.", "red")
end

function K.onShieldCooldown()
  if not K.enabled then return end
  waitForFormation()
end

function K.onShieldResult(form, succeeded)
  if not K.enabled then return end
  local pending = K.shieldPendingTarget
  local requestedRevision
  if pending and normal(pending.form) == normal(form) then
    requestedRevision = pending.combatRevision
    K.shieldPendingTarget = nil
    cancelTimer("shieldReplyTimer")
  end
  waitForFormation()
  if succeeded then
    -- Nowy pakiet moze przyjsc zarowno przed, jak i po tekscie sukcesu.
    -- Liczymy od chwili wyslania polecenia, aby nie zgubic juz odebranej
    -- zmiany celu i moc zaslonic przed kolejnym NPC po odzyskaniu szyku.
    K.shieldAwaitCombatRevision = requestedRevision
    K.shieldFailure = nil
  elseif pending and normal(pending.form) == normal(form) then
    K.shieldFailure = {id=pending.id, name=pending.name, at=now(), room=currentRoom()}
  end
  queueInspection(inspectRoom)
end

function K.onFormationReady()
  K.shieldFormationReady = true
  K.formationToken = nil
  cancelTimer("formationTimer")
  if K.enabled then queueInspection(inspectRoom) end
end

local function maybeShieldTeamMember()
  if isFollower() or not K.entitiesReady or not combatIsActive() or K.teamSeenCount <= 0 then return end
  local candidates = {}
  local own, snapshot = groupContext().self, combatSnapshot()
  for _, entity in ipairs(entities()) do
    local hp = K.teamHealth[normal(entity.name)]
    local incoming = snapshot.incoming[tostring(entity.id)]
    if own and not isSelf(entity) and hp and hp < K.config.teamShieldHp and incoming then
      local _, reserve = shieldHealthPair(own, entity)
      candidates[#candidates + 1] = {entity=entity, hp=hp,
        risk=reserve and pressure(incoming.count) / reserve or math.huge}
    end
  end
  table.sort(candidates, function(a, b)
    if a.risk ~= b.risk then return a.risk > b.risk end
    if a.hp ~= b.hp then return a.hp < b.hp end
    return tostring(a.entity.id) < tostring(b.entity.id)
  end)
  for _, candidate in ipairs(candidates) do
    if tryShield(candidate.entity, candidate.hp, K.config.teamShieldHp) then return end
    local guard = math.min(K.config.teamShieldHp - 1, K.config.teamEscapeHp + 15)
    if K.config.teamEscapeHp > 0 and candidate.hp < guard then
      local safe = shieldImprovesSafety(candidate.entity, candidate.hp)
      if not K.shieldFormationReady or not safe then
        K.escape("Nie moge bezpiecznie oslonic " .. tostring(candidate.entity.name)
          .. " (" .. candidate.hp .. "% HP).", candidate.entity.name)
        return
      end
    end
  end
end

local function safetyCheck(urgentOnly)
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
  if K.enabled and not recovery and K.lastMoves <= K.config.restAtMoves then
    K.escape(string.format(
      "Niemoc: ruch spadl do %d%% (prog %d%%).",
      K.lastMoves, K.config.restAtMoves
    ))
    return false
  end
  if K.enabled and not recovery and not urgentOnly then maybeShieldTeamMember() end
  return true
end

local function npcById(id)
  local entity = entityById(id)
  if entity and entity.kind == "npc" and (not tonumber(entity.hp) or tonumber(entity.hp) > 0) then
    return entity
  end
end

local function opponentOf(entity)
  if not entity or not entity.id then return nil end
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

local function inspectFollower()
  if not K.entitiesReady then return end
  local context = groupContext()
  local leader = context.leader
  K.leaderName = leader and trim(leader.name) or nil
  K.leaderHp = nil
  if not leader then
    K.mode = "support_wait"
    K.supportWaitReason = context.reason
    K.supportCombatHint = nil
    clearTarget()
    return
  end
  K.supportWaitReason = nil
  if not safetyCheck() then return end
  K.leaderHp = context.leaderHp
  local target = opponentOf(leader)
  local hint = K.supportCombatHint
  local leaderFighting = target ~= nil or (hint and hint.leaderId == tostring(leader.id))
  local selfTarget = npcById(combatState().primary) or opponentOf(context.self)
  K.mode = selfTarget and "support_combat" or "support_wait"
  if K.config.role == "zaslony" and (leaderFighting or selfTarget) then
    tryShield(leader, K.leaderHp, K.config.leaderShieldHp)
  end
  if not leaderFighting then K.supportAttempt = nil return end
  if selfTarget then
    if K.supportAttempt then K.supportAttempt.confirmed = true end
    return
  end
  local key = tostring(leader.id) .. ":" .. tostring(target and target.id or "hint")
  local attempt = K.supportAttempt
  if attempt and attempt.key == key then
    if attempt.confirmed or now() < attempt.untilTime then return end
    if attempt.deniedRevision and K.combatRevision <= attempt.deniedRevision then return end
  end
  if K.supportTimer then return end
  K.currentTargetId = target and target.id or nil
  K.currentTargetName = target and trim(target.name) or nil
  K.currentTargetAnimal = nil
  K.supportLastTarget = K.leaderName
  -- Rezerwacja przed send: odpowiedz serwera moze poprzedzic Combat.State.
  K.supportAttempt = {key=key, untilTime=now() + K.config.supportInterval}
  note("Wspieram prowadzacego: " .. K.leaderName .. ".", "green")
  send("wesprzyj")
  K.metrics.support = K.metrics.support + 1
  later("supportTimer", K.config.supportInterval, function() end)
end

function K.onSupportResult(alreadyFighting)
  if not K.enabled or not isFollower() or not K.supportAttempt then return end
  if alreadyFighting then K.supportAttempt.confirmed = true
  else
    K.supportAttempt.confirmed = nil
    K.supportAttempt.deniedRevision = K.combatRevision
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

function K.onTeamCombat(actor, defended)
  if not K.enabled or not isFollower() or not K.entitiesReady
      or K.mode == "escape" or K.mode == "heal_rest" or K.mode == "recovery_return" then return end
  local leader = groupContext().leader
  if not leader then return end
  local name, form = normal(leader.name), shieldNameForm(leader.name)
  if normal(actor) ~= name and normal(defended) ~= name
      and (not form or normal(defended) ~= form) then return end
  K.supportCombatHint = { leaderId = tostring(leader.id) }
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
  -- Gdy Combat.State nadal wskazuje ignorowanego agresora, ponawiamy fokus
  -- wybranego celu najwyzej raz na sekunde, zamiast po kazdym pakiecie GMCP.
  if sameTarget and K.focusRetryPending then return end
  cancelTimer("targetLostTimer")
  ensurePursuitOrigin()
  K.mode = "combat"
  K.route = nil
  cancelTimer("moveTimer")
  K.patrolMovePending = false
  K.chaseMovePending = false
  K.currentTargetId = entity.id
  K.currentTargetName = trim(entity.name)
  K.currentTargetAnimal = animal or animalInName(entity.name)
  if not sameTarget then
    K.herbSearchedRoom = nil
    touchActivity()
    note("Atakuje: " .. K.currentTargetName, "green")
  end
  send(K.config.attackCommand .. " " .. tostring(attackForm(K.currentTargetAnimal)))
  K.focusRetryPending = true
  later("focusTimer", 1.0, function()
    K.focusRetryPending = false
    if K.enabled and (K.mode == "combat" or K.mode == "chase") then inspectRoom() end
  end)
end

inspectRoom = function()
  if not K.enabled then return end
  K.metrics.actions = K.metrics.actions + 1
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
    if currentRoom() == tonumber(K.config.startRoom) then finishEscapeTail() end
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

  local combat = activeCombatTarget()
  if combatTargetAllowed(combat) then
    cancelTimer("focusTimer")
    K.focusRetryPending = false
    local changedTarget = tostring(K.currentTargetId or "") ~= tostring(combat.id or "")
    ensurePursuitOrigin()
    K.mode = "combat"
    K.currentTargetId = combat.id
    K.currentTargetName = trim(combat.name)
    K.currentTargetAnimal = animalInName(combat.name)
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

  clearTarget()
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
    if #K.rooms == 1 and K.rooms[1] == room then
      later("moveTimer", delayOverride or math.max(K.config.patrolDelay, K.emptyPatrolDelay), function()
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
      sendDirection(command)
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
  if currentTargetEntity() then
    inspectRoom()
    return
  end
  local lostName = K.currentTargetName or "nieznany cel"
  local shouldReturn = K.pursuitLeftArea and #K.pursuitTrail > 0 and K.pursuitOriginRoom
  note("Cel zniknal bez potwierdzenia smierci lub kierunku: " .. lostName .. ". Odblokowuje stan.", "yellow")
  clearTarget()
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
  note("Dotarlem do pokoju startowego " .. K.config.startRoom .. ". Uruchamiam wszystko od nowa.", "green")
  K.stop("Pelny reset po bezczynnosci.")
  K.start()
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
  note(string.format(
    "Brak aktywnosci przez %.1f s. Wracam komendami do pokoju startowego %d.",
    K.config.idleTimeout, K.config.startRoom
  ), "red")
  idleReturnStep()
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
  invalidateState(true)
  local previousRoom = K.lastRoom
  if eventName == "gmcp.Room.Info" then
    K.sessionFresh.room = true
    K.sessionFresh.entities = false
    K.roomChangePending = false
    K.sentDirection = nil
    K.entitiesReady = false
    K.patrolMovePending = false
    K.chaseMovePending = false
    K.failedTargetIds = {}
    K.supportCombatHint = nil
    K.shieldPendingTarget = nil
    if previousRoom ~= currentRoom() then
      K.supportAttempt = nil
      cancelTimer("supportTimer")
      K.healthHistory, K.shieldTransfers = {}, {}
      K.previousIncoming, K.transferRevision = nil, nil
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
    if room == tonumber(K.config.startRoom) then
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
  K.metrics.events = K.metrics.events + 1
  local healthEvent = eventName == "gmcp.Chimera.Room.Entities"
    or eventName == "gmcp.Char.Vitals" or eventName == "gmcp.Chimera.Group.State"
  invalidateState(healthEvent)
  if eventName == "gmcp.Chimera.Room.Entities" and not K.roomChangePending then
    K.entitiesReady = true
    K.sessionFresh.entities = true
    K.vitalsRevision = K.vitalsRevision + 1
    K.vitalsSource = "entities"
    K.sourceRevisions.entities = K.dataRevision
  end
  if eventName == "gmcp.Char.Vitals" then
    K.vitalsRevision = K.vitalsRevision + 1
    K.vitalsSource = "char"
    K.sourceRevisions.char = K.dataRevision
  end
  if eventName == "gmcp.Chimera.Combat.State" then
    K.sessionFresh.combat = true
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
    local combat = activeCombatTarget()
    local target = findTarget()
    if combatTargetAllowed(combat) or target then
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
  if K.mode ~= "escape" and K.mode ~= "heal_rest" and K.mode ~= "recovery_return"
      and K.mode ~= "returning" and K.mode ~= "herb_search" then
    queueInspection(inspectRoom)
  end
end

function K.onFleeAnnounced(name)
  if not K.enabled or isFollower() or K.mode == "leader_wait" then return end
  cancelTimer("targetLostTimer")
  K.pendingFleeName = trim(name)
  later("pendingFleeTimer", 3.0, function()
    K.pendingFleeName = nil
    if K.enabled and (K.mode == "combat" or K.mode == "chase") then inspectRoom() end
  end)
end

function K.onFleeDirection(direction)
  if not K.enabled or isFollower() or K.mode == "leader_wait" then return end
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
  if isFollower() or K.mode == "leader_wait" then return end
  if not K.enabled then return end
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
  if K.enabled and isFollower() then
    K.supportCombatHint = nil
    clearTarget()
    queueInspection(inspectRoom)
    return
  end
  if not K.enabled or K.mode == "kill_pause" or not K.currentTargetName then return end
  if nameHasIgnoredPhrase(name) then return end
  local currentMatch = normal(name) == normal(K.currentTargetName)
  if currentMatch then
    finishCurrentKill()
    return
  end

  -- Linie z XP sa zwykle w bierniku, wiec nazwy nie da sie porownac 1:1.
  -- Sam zgodny gatunek nie wystarcza: w grupie moze wlasnie zginac drugi byk
  -- albo ork. Czekamy na znikniecie konkretnego ID aktualnego celu z GMCP.
  if not confirmedByServer then return end
  local killedKind = selectedTargetKindInAnyForm(name)
  if not K.currentTargetAnimal or killedKind ~= K.currentTargetAnimal then return end
  local expectedId = tostring(K.currentTargetId or "")
  local expectedName = K.currentTargetName
  later("killConfirmTimer", 0.35, function()
    if not K.enabled or (K.mode ~= "combat" and K.mode ~= "chase") then return end
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
  if K.enabled or K.reconnectTask or K.sessionBlocked or not K.entitiesReady or K.roomChangePending
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
  if not isFollower() and not recovery and not emergency then
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
  K.healthHistory, K.shieldTransfers = {}, {}
  K.previousIncoming, K.transferRevision = nil, nil
  K.shieldFailure = nil
  local wasEnabled = K.enabled
  if wasEnabled and not K.reconnectTask then
    local task = {mode=K.mode, role=K.config.role, roster={}, returnRoom=K.pursuitOriginRoom}
    for _, entity in ipairs(entities()) do
      if isSelf(entity) then task.name = normal(entity.name) break end
    end
    if not isFollower() then
      for _, member in ipairs(groupContext().members) do
        if not isSelf(member) then task.roster[normal(member.name)] = trim(member.name) end
      end
    end
    K.reconnectTask = task
  end
  if K.reconnectTask then K.reconnectTask.snapshotReady = nil end
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
  if K.mode == "patrol" then queueInspection(inspectRoom) end
end

function K.start()
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
  K.recoveryRoster, K.recoveryMissing = nil, nil
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
  if K.config.equipmentHold then statusRow("Ekwipunek", K.config.equipmentHold) end
  if K.recoveryMissing then statusRow("Brak w druzynie", K.recoveryMissing) end
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
  statusLink("[ ZASLONY ]", "rola zaslony", "Wsparcie oraz zaslony prowadzacego", "yellow")
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

  statusPrefix("Prog druzyny")
  statusLink("[ - ]", "progdruzyny " .. math.max(0, K.config.teamEscapeHp - 5), "Zmniejsz prog HP druzyny", "yellow")
  cecho(string.format("  %d%% (%s: %d%%, widocznych %d)  ",
    K.config.teamEscapeHp, K.teamLowestName, K.teamLowestHp, K.teamSeenCount))
  statusLink("[ + ]", "progdruzyny " .. math.min(maxEscapeSetting, K.config.teamEscapeHp + 5), "Zwieksz prog HP druzyny", "green")
  statusEndRow()
  if isFollower() then statusRow("Odwrot druzyny", "Prog druzyny obsluguje profil prowadzacego") end
  if K.injuredTeamMember then
    statusRow("Czekam na gracza", K.injuredTeamMember .. " do 100% HP")
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
  if isFollower() then statusRow("Zaslony druzyny", "Tylko prowadzacy; wspierajacy ma osobny prog lidera") end
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
|                       KOZOJEB 2.9.0                           |
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
                              tylko na prowadzacego ponizej progu
  <green>/kozojeb lider auto<reset>            ustal prowadzacego z GMCP (domyslnie)
  <green>/kozojeb lider Yarrim yarrima<reset>   opcjonalnie wskaz imie i biernik
  <green>/kozojeb proglidera 70<reset>          zaslona prowadzacego ponizej 70% HP;
                              0 = wylaczona; prog dotyczy tylko lidera
  <green>/kozojeb minhpzaslony 50<reset>       wlasne minimum procentowe;
                              dodatkowo oceniam punkty HP i napastnikow
  <green>/kozojeb limitzaslony 2<reset>        maksymalnie 2 napastnikow po oslonie
  <green>/kozojeb stabilizacja 8<reset>        8 s ochrony przed oddaniem NPC
  <green>/kozojeb pustypatrol 3<reset>         pusty patrol zwalnia do 3 s/krok;
                              0 wylacza spowalnianie (zakres 0-10)
  <green>/kozojeb wydajnosc<reset>             liczniki GMCP, decyzji i komend
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
                              (0 = bez limitu; wychodzi szybciej)
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

<white>  Zasady dzialania<reset>
  - Krowa nie jest atakowana, jezeli w pokoju stoi byk.
  - Koza nie jest atakowana, jezeli w pokoju stoi koziol.
  - Za uciekajacym celem bot biegnie tak dlugo, az go zabije.
  - Po pogoni poza obszar wraca odwrotnymi komendami do miejsca ataku.
  - Po kazdym zabiciu czeka przez czas ustawiony komenda /kozojeb pauza.
  - Szukanie ziol odbywa sie dopiero po walce i przed kolejnym krokiem.
    Bot rusza po wyniku znalezienia/braku ziol albo po 20 s bez odpowiedzi.
  - Przy niskim HP ucieka, leczy sie do 100%, wraca przez /idz i startuje.
  - Gdy odwrot wywolal ranny gracz, czeka na potwierdzone 100% jego HP.
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
  - Limit stworow dotyc tylko nowej walki; po przekroczeniu bot wychodzi
    z pokoju szybciej, ale nie przerywa trwajacej pogoni.
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
end

local function executeCommand(arguments)
  local input = trim(arguments)
  local action, rest = input:match("^(%S+)%s*(.-)$")
  action = normal(action or "status")
  if action == "wydajnosc" then
    K.performance()
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
    if room then K.config.startRoom = room end
    note(string.format("Reset bezczynnosci: %.1f s, wspolna baza/start: pokoj %d.", value, K.config.startRoom), "green")
    if K.enabled then touchActivity() end
  elseif action == "starttu" then
    local room = currentRoom()
    if not room then note("Nie potrafie odczytac obecnego pokoju mapy.", "red") return end
    K.config.startRoom = room
    note("Wspolna baza i pokoj startowy ustawione tutaj: " .. room .. ".", "green")
  elseif action == "startpokoj" then
    local room = tonumber(rest)
    if not room or room < 1 or room % 1 ~= 0 then note("Uzycie: /kozojeb startpokoj 7965", "red") return end
    K.config.startRoom = room
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
    note(value == 0 and "Limit stworow wylaczony." or ("Maksymalnie wybranych celow przy rozpoczeciu ataku: " .. value .. "."), "green")
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
    note(value == 0 and "Automatyczna zaslona wylaczona." or string.format(
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
    K.config.startRoom = room
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
  if action ~= "status" and action ~= "help" and action ~= "wydajnosc" then K.saveSettings() end
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
  "^(.+) zaslania cie przed ciosami ", [[kozojeb.onCoveredByLeader(matches[2])]])
K.handlers.triggers[#K.handlers.triggers + 1] = tempRegexTrigger(
  "^Juz walczysz .+\\.$", [[kozojeb.onSupportResult(true)]])
K.handlers.triggers[#K.handlers.triggers + 1] = tempRegexTrigger(
  "^Nikt z twojej druzyny nie jest zaangazowany w walke\\.$", [[kozojeb.onSupportResult(false)]])
K.handlers.triggers[#K.handlers.triggers + 1] = tempRegexTrigger(
  "^Umierasz\\.$", [[kozojeb.onDeath()]])
K.handlers.triggers[#K.handlers.triggers + 1] = tempRegexTrigger(
  "^.+ peka!!!$", [[kozojeb.onEquipmentBroken(matches[1])]])
K.handlers.triggers[#K.handlers.triggers + 1] = tempRegexTrigger(
  "^Nie widzisz zadnego wyjscia prowadzacego na .+\\.$", [[kozojeb.onMoveRejected()]])
K.handlers.triggers[#K.handlers.triggers + 1] = tempRegexTrigger(
  "^(?:Podaj swoje imie:|Witaj, .+ Podaj haslo do konta:|Twoja postac jest juz w grze\\.).*",
  [[kozojeb.onSessionEvent("login")]])

K.handlers.aliases[#K.handlers.aliases + 1] = tempAlias("^/kozojeb(?:\\s+(.*))?$", [[kozojeb.command(matches[2] or "status")]])
K.handlers.triggers[#K.handlers.triggers + 1] = tempRegexTrigger(
  "^(.+) ATAKUJE (.+)\\.$", [[kozojeb.onTeamCombat(matches[2], matches[3])]])
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
K.handlers.events[#K.handlers.events + 1] = registerAnonymousEventHandler("sysExitEvent", "kozojeb.saveSettings")
function K.onUninstall(_, packageName)
  if packageName ~= "Chimera_Kozojeb" then return end
  K.saveSettings()
  K.stop("Usuwanie lub aktualizacja paczki.")
  cancelTimer("formationTimer")
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
