-- Aktualizacje stabilnych wydan z GitHub Releases; bez wykonywania kodu z main.
-- Wartosc jest ustawiana przez tools/build.py przy budowie wydania.
local releaseRepository = "__KOZO_RELEASE_REPOSITORY__"
if releaseRepository:sub(1,2) == "__" then releaseRepository = "" end
local K = kozojeb
if not K or not K.initialized then return end
if K.updater and K.updater.cleanup then K.updater.cleanup() end
local U = {handlers={}, timers={}, status="gotowy", serial=0, retryAttempt=0}
K.updater = U
local profile = getMudletHomeDir()
local settings = profile .. "/chimera_kozojeb_updates.lua"
local function note(message, colour)
  cecho("\n<" .. (colour or "yellow") .. ">[KOZOJEB UPDATE] " .. message .. "<reset>\n")
end
local function repositoryValid(value)
  if type(value) ~= "string" or #value > 140 then return false end
  local owner, repo = value:match("^([%w%-]+)/([%w%._%-]+)$")
  return owner ~= nil and owner:sub(1,1) ~= "-" and repo ~= "." and repo ~= ".."
end
U.config = {repository=releaseRepository, automatic=true}
if type(table.load) == "function" then
  local saved={}
  pcall(table.load,settings,saved)
  if repositoryValid(saved.repository) then U.config.repository=saved.repository end
  if type(saved.automatic)=="boolean" then U.config.automatic=saved.automatic end
end
local function save()
  if type(table.save) ~= "function" then return end
  pcall(table.save,settings,U.config)
end
local function timer(name, delay, callback)
  if U.timers[name] then pcall(killTimer,U.timers[name]) end
  U.timers[name]=tempTimer(delay,function()
    U.timers[name]=nil
    if kozojeb and kozojeb.updater==U then callback() end
  end)
end
local function cancel(name)
  if U.timers[name] then pcall(killTimer,U.timers[name]); U.timers[name]=nil end
end
function U.cleanup()
  for _,id in ipairs(U.handlers) do pcall(killAnonymousEventHandler,id) end
  for _,id in pairs(U.timers) do pcall(killTimer,id) end
  U.handlers,U.timers={},{}
  U.pending=nil
end
local function read(path,limit)
  local file=io.open(path,"rb")
  if not file then return nil end
  local data=file:read(limit+1)
  file:close()
  if not data or #data>limit then return nil end
  return data
end
local function write(path,data)
  local file=io.open(path,"wb")
  if not file then return false end
  local ok=file:write(data)
  local closed=file:close()
  return ok~=nil and closed~=nil
end
local function version(value)
  if type(value)~="string" then return nil end
  local a,b,c=value:match("^(%d+)%.(%d+)%.(%d+)$")
  if not a then return nil end
  a,b,c=tonumber(a),tonumber(b),tonumber(c)
  if a>99999 or b>99999 or c>99999 then return nil end
  return {a,b,c}
end
local function newer(a,b)
  a,b=version(a),version(b)
  if not a or not b then return false end
  for i=1,3 do
    if a[i]~=b[i] then return a[i]>b[i] end
  end
  return false
end
local function errorDetail(message)
  return tostring(message or "nieznany blad"):gsub("\27%[[%d;]*m", "")
    :gsub("https?://%S+", "[adres]"):gsub("[<>]", ""):gsub("%s+", " "):sub(1,180)
end
local function fail(message, retryable)
  local pending=U.pending
  local candidate=U.candidate
  U.pending,U.candidate=nil,nil
  cancel("timeout"); cancel("hash"); cancel("apply")
  cancel("retry")
  if pending and pending.path then os.remove(pending.path) end
  if candidate and candidate.path then os.remove(candidate.path) end
  if retryable and pending and (pending.manual or U.config.automatic) and U.retryAttempt < 3 then
    U.retryAttempt=U.retryAttempt+1
    local delay=({60,300,900})[U.retryAttempt]
    message=message.." Ponowie za "..delay.." s ("..U.retryAttempt.."/3)."
    timer("retry",delay,function()
      if U.config.repository~=pending.repository or (not pending.manual and not U.config.automatic) then return end
      U.check(pending.manual,true)
    end)
  end
  U.status=message
  note(message,"red")
end
local function supported()
  if type(getMudletVersion)~="function" then return false end
  local ok,current=pcall(getMudletVersion,"string")
  current=ok and tostring(current):match("^(%d+%.%d+%.%d+)") or nil
  return current and (current=="4.20.0" or newer(current,"4.20.0"))
    and type(downloadFile)=="function" and type(installPackage)=="function"
    and type(uninstallPackage)=="function" and type(getScript)=="function"
    and type(yajl)=="table" and type(yajl.to_value)=="function"
    and type(kozojeb_sha256)=="table"
end
local function download(kind,url,manual,manifest)
  U.serial=U.serial+1
  local extension=kind=="manifest" and ".json" or ".mpackage"
  local path=profile .. "/kozojeb_download_" .. tostring(os.time()) .. "_" .. U.serial .. extension
  U.pending={kind=kind,path=path,repository=U.config.repository,manual=manual,manifest=manifest}
  timer("timeout",60,function() fail("Przekroczono czas pobierania. Dotychczasowa wersja pozostaje aktywna.",true) end)
  local ok,result=pcall(downloadFile,path,url)
  if not ok or result==false then
    fail("Nie mozna rozpoczac pobierania aktualizacji"..(not ok and (": "..errorDetail(result)) or "."),true)
  end
end
function U.check(manual,retrying)
  if not repositoryValid(U.config.repository) then
    if manual then note("Ustaw /kozojeb repo OWNER/REPO, wskazujac repozytorium publicznych wydan.") end
    return
  end
  if U.pending or U.candidate or U.installing then
    if manual then note("Aktualizacja jest juz pobierana albo czeka na instalacje.") end
    return
  end
  if not retrying then cancel("retry"); U.retryAttempt=0 end
  if not supported() then
    U.status="Aktualizator wymaga Mudleta 4.20+ i kompletu modulow paczki"
    if manual then note(U.status,"red") end
    return
  end
  U.status="sprawdzam wydanie"
  download("manifest","https://github.com/" .. U.config.repository
    .. "/releases/latest/download/update.json",manual)
end
local function xml(value)
  return value:gsub("&","&amp;"):gsub("<","&lt;"):gsub(">","&gt;")
end
local function backup()
  if type(lfs)~="table" or type(lfs.mkdir)~="function" then return nil end
  local directory=profile .. "/kozojeb_rollback"
  pcall(lfs.mkdir,directory)
  local parts={'<?xml version="1.0" encoding="UTF-8"?>\n<!DOCTYPE MudletPackage>\n',
    '<MudletPackage version="1.001"><ScriptPackage>',
    '<ScriptGroup isActive="yes" isFolder="yes"><name>Chimera_Kozojeb</name>',
    '<packageName>Chimera_Kozojeb</packageName><script></script><eventHandlerList/>'}
  for _,name in ipairs({"Kozojeb "..K.version,"Kozojeb SHA-256","Kozojeb updater"}) do
    local ok,code=pcall(getScript,name)
    if not ok or type(code)~="string" or code=="" then return nil end
    parts[#parts+1]='<Script isActive="yes" isFolder="no"><name>'..xml(name)..'</name>'
      ..'<packageName>Chimera_Kozojeb</packageName><script>'..xml(code)..'</script><eventHandlerList/></Script>'
  end
  parts[#parts+1]='</ScriptGroup></ScriptPackage></MudletPackage>'
  local path=directory.."/Chimera_Kozojeb.xml"
  return write(path,table.concat(parts)) and path or nil
end
function U.tryInstall()
  if not U.candidate or U.installing then return end
  if not U.candidate.manual and not U.config.automatic then return end
  if not K.isUpdateSafe() then
    U.status="pobrana "..U.candidate.version.."; czekam na stop i koniec walki"
    timer("apply",3,U.tryInstall)
    return
  end
  if not K.saveSettings() then fail("Nie mozna zapisac ustawien. Instalacja odlozona.") return end
  local previous=backup()
  if not previous then fail("Nie mozna utworzyc kopii poprzedniej wersji. Instalacja odlozona.") return end
  local configPath=profile.."/chimera_kozojeb_settings.lua"
  local previousConfig=read(configPath,2*1024*1024)
  if not previousConfig or not write(profile.."/kozojeb_rollback/settings.lua",previousConfig) then
    fail("Nie mozna zachowac konfiguracji poprzedniej wersji. Instalacja odlozona.") return
  end
  local candidate=U.candidate
  -- Kontrola pliku ponownie bezposrednio przed podmiana, bo mogl dlugo
  -- oczekiwac na stop. Przetwarzamy SHA-256 porcjami, tak jak po pobraniu.
  U.installing=true
  local data=read(candidate.path,2*1024*1024)
  if not data or #data~=candidate.size then U.installing=false; fail("Pobrana paczka zmienila sie przed instalacja.") return end
  U.verify(data,function(digest)
    if digest~=candidate.sha256 then U.installing=false; fail("Suma SHA-256 paczki nie zgadza sie.") return end
    if not candidate.manual and not U.config.automatic then U.installing=false; return end
    if not K.isUpdateSafe() then U.installing=false; timer("apply",3,U.tryInstall) return end
    if not write(candidate.path,data) then U.installing=false; fail("Nie mozna zapisac zweryfikowanej paczki.") return end
    local ok,removed=pcall(uninstallPackage,"Chimera_Kozojeb")
    if not ok or removed~=true then U.installing=false; fail("Nie mozna usunac poprzedniej paczki.") return end
    U.cleanup()
    local installed,result=pcall(installPackage,candidate.path)
    local loaded=kozojeb and kozojeb.initialized and kozojeb.version==candidate.version
      and kozojeb.updater and kozojeb.updater~=U and kozojeb.updater.initialized
    if installed and result==true and loaded then
      note("Zainstalowano "..candidate.version..". Ustawienia zachowane; bot pozostaje zatrzymany.","green")
      os.remove(candidate.path)
      return
    end
    pcall(uninstallPackage,"Chimera_Kozojeb")
    if not write(configPath,previousConfig) then
      note("Przywracanie konfiguracji nie powiodlo sie. Kopia jest w katalogu kozojeb_rollback.","red")
    end
    kozojeb=nil -- poprzedni kod musi ponownie wczytac zachowana konfiguracje
    local restored,restoreResult=pcall(installPackage,previous)
    if restored and restoreResult==true then
      note("Instalacja nie powiodla sie. Przywrocono poprzednia wersje; bot zatrzymany.","red")
    else
      note("Instalacja nie powiodla sie. Kopia do recznego przywrocenia: "..previous,"red")
    end
  end)
end
function U.verify(data,callback)
  local state=kozojeb_sha256.new(data)
  local function step()
    if kozojeb_sha256.step(state,16) then callback(kozojeb_sha256.finish(state))
    else timer("hash",0.001,step) end
  end
  step()
end
function U.onDownloaded(_,path)
  local job=U.pending
  if not job or path~=job.path or job.repository~=U.config.repository then return end
  cancel("timeout")
  if job.kind=="manifest" then
    local data=read(path,8192)
    local ok,manifest=false,nil
    if data then ok,manifest=pcall(yajl.to_value,data) end
    os.remove(path)
    if not ok or type(manifest)~="table" or manifest.schema~=1 or manifest.package~="Chimera_Kozojeb"
        or not version(manifest.version) or type(manifest.size)~="number"
        or manifest.size%1~=0 or manifest.size<32 or manifest.size>2*1024*1024
        or type(manifest.sha256)~="string" or #manifest.sha256~=64 or manifest.sha256:find("[^0-9a-f]") then
      fail("Nieprawidlowy opis wydania. Sprawdz repozytorium i jego dostepnosc.") return
    end
    local expected="https://github.com/"..U.config.repository.."/releases/download/v"
      ..manifest.version.."/Chimera_Kozojeb.mpackage"
    if manifest.url~=expected then fail("Adres paczki nie nalezy do wybranego wydania repozytorium.") return end
    local currentMudlet=tostring(getMudletVersion("string")):match("^(%d+%.%d+%.%d+)")
    if not version(manifest.min_mudlet) or newer(manifest.min_mudlet,currentMudlet) then
      fail("To wydanie wymaga nowszego Mudleta.") return
    end
    if not newer(manifest.version,K.version) then
      U.pending=nil
      U.retryAttempt=0
      U.status="wersja "..K.version.." jest aktualna"
      if job.manual then note(U.status,"green") end
      return
    end
    U.status="pobieram "..manifest.version
    download("package",expected,job.manual,manifest)
  else
    local data=read(path,2*1024*1024)
    if not data or #data~=job.manifest.size or data:sub(1,4)~="PK\3\4" then
      fail("Pobrana paczka jest niepelna lub nieprawidlowa.") return
    end
    U.status="sprawdzam SHA-256"
    U.verify(data,function(digest)
      if U.pending~=job then return end
      if digest~=job.manifest.sha256 then fail("Suma SHA-256 paczki nie zgadza sie.") return end
      U.candidate={path=path,version=job.manifest.version,manual=job.manual,
        sha256=job.manifest.sha256,size=job.manifest.size}
      U.pending=nil
      U.retryAttempt=0
      note("Pobrano "..job.manifest.version..". Instalacja po zatrzymaniu bota i zakonczeniu walki.","green")
      U.tryInstall()
    end)
  end
end
function U.onDownloadError(_,message,path)
  if U.pending and U.pending.path==path then
    fail("Nie udalo sie pobrac wydania: "..errorDetail(message)..".",true)
  end
end
function U.onBotStopped() if U.candidate then timer("apply",0.1,U.tryInstall) end end
function U.command(action,rest)
  if action=="aktualizuj" then U.check(true)
  elseif action=="repo" then
    if U.installing then note("Trwa weryfikacja instalacji; poczekaj na jej zakonczenie.") return end
    if rest=="" then note("Repozytorium: "..(U.config.repository~="" and U.config.repository or "nieustawione")) return end
    if not repositoryValid(rest) then note("Uzycie: /kozojeb repo OWNER/REPO","red") return end
    cancel("timeout");cancel("hash");cancel("apply");cancel("retry")
    U.retryAttempt=0
    if U.pending then os.remove(U.pending.path) end
    if U.candidate then os.remove(U.candidate.path) end
    U.pending,U.candidate=nil,nil
    U.config.repository=rest
    U.status="repozytorium ustawione"
    save()
    note("Repozytorium wydan: "..rest..". Wpisz /kozojeb aktualizuj.","green")
  elseif action=="autoaktualizacja" then
    if rest~="on" and rest~="off" then note("Uzycie: /kozojeb autoaktualizacja on/off") return end
    U.config.automatic=rest=="on"
    save()
    if U.config.automatic then U.check(false)
    else
      cancel("retry")
      if U.candidate and not U.candidate.manual then cancel("apply") end
    end
    note(U.config.automatic and "Automatyczne sprawdzanie wlaczone." or "Automatyczne sprawdzanie wylaczone.")
  end
end
local function periodic()
  if U.config.automatic and not U.timers.retry then U.check(false) end
  timer("periodic",21600,periodic)
end
U.handlers[#U.handlers+1]=registerAnonymousEventHandler("sysDownloadDone",U.onDownloaded)
U.handlers[#U.handlers+1]=registerAnonymousEventHandler("sysDownloadError",U.onDownloadError)
timer("periodic",30,periodic)
U.initialized=true
