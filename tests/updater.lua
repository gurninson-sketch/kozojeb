local files, saved, requests, timers, serial, clock, messages, installs, removals
local safe, decoder, scriptMissing, saveFails, installFails, mudletVersion, U
local realOpen, realRemove = io.open, os.remove
local function clone(value)
  if type(value)~="table" then return value end
  local result={}
  for key,item in pairs(value) do result[key]=clone(item) end
  return result
end
function io.open(path,mode)
  if path:sub(1,8)~="/profile" then return realOpen(path,mode) end
  if mode=="rb" then
    if not files[path] then return nil end
    return {read=function(_,limit) return files[path]:sub(1,limit) end,close=function() return true end}
  end
  return {write=function(_,data) files[path]=data; return true end,close=function() return true end}
end
function os.remove(path)
  if path:sub(1,8)~="/profile" then return realRemove(path) end
  files[path]=nil
  return true
end
function getMudletHomeDir() return "/profile" end
function cecho(text) messages[#messages+1]=text end
function table.save(path,value)
  if saveFails then return false end
  saved[path]=clone(value)
  return true
end
function table.load(path,target)
  for key,value in pairs(saved[path] or {}) do target[key]=clone(value) end
end
function tempTimer(delay,callback)
  serial=serial+1
  timers[serial]={at=clock+delay,callback=callback}
  return serial
end
function killTimer(id) timers[id]=nil end
function registerAnonymousEventHandler() serial=serial+1 return serial end
function killAnonymousEventHandler() end
function downloadFile(path,url) requests[#requests+1]={path=path,url=url}; return true end
function getMudletVersion() return mudletVersion end
function getScript(name) return not scriptMissing and "-- backup of "..name or -1 end
lfs={mkdir=function() return true end}
yajl={to_value=function(data) return clone(assert(decoder[data],"Invalid JSON")) end}
function uninstallPackage(name)
  assert(name=="Chimera_Kozojeb")
  removals=removals+1
  return true
end
function installPackage(path)
  installs[#installs+1]=path
  if installFails and not path:find("rollback",1,true) then return nil end
  kozojeb=kozojeb or {}
  kozojeb.version=path:find("rollback",1,true) and "2.8.0" or "2.10.0"
  kozojeb.initialized=true
  kozojeb.updater={initialized=true}
  return true
end
local function advance(seconds)
  local endTime=clock+seconds
  for _=1,20000 do
    local at,id=math.huge,nil
    for candidate,timer in pairs(timers) do
      if timer.at<at then at,id=timer.at,candidate end
    end
    if not id or at>endTime then clock=endTime; return end
    clock=at
    local callback=timers[id].callback
    timers[id]=nil
    callback()
  end
  error("Timer loop")
end
local payload="PK\3\4"..string.rep("verified package content",90)
local function reset()
  files,saved,requests,timers,messages,installs={},{},{},{},{},{}
  serial,clock,removals=0,0,0
  safe,scriptMissing,saveFails,installFails=true,false,false,false
  mudletVersion="4.20.0"
  kozojeb={version="2.8.0",initialized=true,
    isUpdateSafe=function() return safe end,
    saveSettings=function()
      if saveFails then return false end
      files["/profile/chimera_kozojeb_settings.lua"]="original serialized profile settings"
      return true
    end}
  dofile("src/Sha256.lua")
  decoder={good={schema=1,package="Chimera_Kozojeb",version="2.10.0",min_mudlet="4.20.0",
    size=#payload,sha256=kozojeb_sha256.digest(payload),
    url="https://github.com/example/kozojeb/releases/download/v2.10.0/Chimera_Kozojeb.mpackage"}}
  dofile("src/KozojebUpdater.lua")
  U=kozojeb.updater
  U.command("repo","example/kozojeb")
end
local function reply(data)
  local request=requests[#requests]
  assert(request,"No pending download")
  files[request.path]=data
  U.onDownloaded("sysDownloadDone",request.path)
end
local function stage(manual)
  U.check(manual~=false)
  reply("good")
  assert(#requests==2)
  reply(payload)
  advance(0.2)
end
local total=0
local function test(name,fn)
  reset()
  fn()
  total=total+1
  print("PASS updater "..name)
end

test("new version is verified, backed up and installed while stopped",function()
  stage()
  assert(removals==1 and #installs==1 and kozojeb.version=="2.10.0")
  local backup=files["/profile/kozojeb_rollback/Chimera_Kozojeb.xml"]
  assert(backup and backup:find("Kozojeb 2.8.0",1,true))
end)
test("installation waits during combat or an enabled bot",function()
  safe=false
  stage()
  assert(U.candidate and removals==0 and #installs==0)
  advance(4)
  assert(removals==0)
  safe=true
  U.onBotStopped()
  advance(0.2)
  assert(removals==1 and #installs==1)
end)
test("checksum mismatch never uninstalls the current package",function()
  decoder.good.sha256=string.rep("0",64)
  U.check(true);reply("good");reply(payload);advance(0.2)
  assert(removals==0 and #installs==0 and not U.candidate and not U.pending)
end)
test("truncated or non-ZIP package is rejected",function()
  U.check(true);reply("good");reply(payload:sub(2));advance(0.2)
  assert(removals==0 and not U.candidate)
end)
test("unrelated download events are ignored",function()
  U.check(true)
  U.onDownloaded("sysDownloadDone","/other/file.mpackage")
  U.onDownloadError("sysDownloadError","error","/other/file.mpackage")
  assert(U.pending and #requests==1 and removals==0)
end)
test("timeout and late completion leave the current package intact",function()
  U.check(true)
  local path=requests[1].path
  advance(61)
  files[path]="good"
  U.onDownloaded("sysDownloadDone",path)
  assert(removals==0 and not U.pending and #requests==1)
end)
test("foreign repository and arbitrary URLs are rejected",function()
  decoder.good.url="https://example.org/execute.mpackage"
  U.check(true);reply("good")
  assert(#requests==1 and not U.pending and removals==0)
end)
test("malformed manifest is rejected without code execution",function()
  U.check(true);reply("os.execute('anything')")
  assert(removals==0 and not U.pending)
end)
test("same and older versions do not download or reinstall",function()
  decoder.good.version="2.8.0"
  decoder.good.url="https://github.com/example/kozojeb/releases/download/v2.8.0/Chimera_Kozojeb.mpackage"
  U.check(true);reply("good")
  assert(#requests==1 and removals==0 and not U.pending)
end)
test("an incomplete backup blocks uninstall",function()
  scriptMissing=true
  stage()
  assert(removals==0 and #installs==0)
end)
test("settings save failure blocks uninstall",function()
  saveFails=true
  stage()
  assert(removals==0 and #installs==0)
end)
test("failed installation restores the previous package",function()
  installFails=true
  stage()
  assert(removals==2 and #installs==2 and kozojeb.version=="2.8.0")
  assert(installs[2]=="/profile/kozojeb_rollback/Chimera_Kozojeb.xml")
  assert(files["/profile/chimera_kozojeb_settings.lua"]=="original serialized profile settings")
end)
test("changed package is rechecked after waiting for a stop",function()
  safe=false
  stage()
  files[U.candidate.path]="PK\3\4"..string.rep("x",#payload-4)
  safe=true
  U.tryInstall()
  advance(0.2)
  assert(removals==0 and #installs==0)
end)
test("repository changes invalidate an earlier download",function()
  U.check(true)
  local old=requests[1].path
  U.command("repo","other/kozojeb")
  files[old]="good";U.onDownloaded("sysDownloadDone",old)
  assert(not U.pending and #requests==1 and removals==0)
end)
test("unsupported Mudlet versions cannot begin automatic updates",function()
  mudletVersion="4.19.1"
  U.check(true)
  assert(#requests==0)
end)
test("release minimum Mudlet version is enforced",function()
  decoder.good.min_mudlet="4.21.0"
  U.check(true);reply("good")
  assert(#requests==1 and removals==0)
end)
test("automatic updates can be disabled while an update waits",function()
  safe=false
  stage(false)
  U.command("autoaktualizacja","off")
  safe=true;U.tryInstall();advance(5)
  assert(removals==0 and U.candidate)
end)
test("manual request remains usable with automatic checking disabled",function()
  U.command("autoaktualizacja","off")
  stage()
  assert(removals==1)
end)
test("invalid repository input never reaches the network",function()
  U.command("repo","https://github.com/example/repo;anything")
  assert(U.config.repository=="example/kozojeb" and #requests==0)
end)
test("checking in the background does not send game commands",function()
  function send() error("Updater sent a game command") end
  function expandAlias() error("Updater ran a game alias") end
  advance(31)
  assert(#requests==1)
end)
local function networkFailure(message)
  local request=requests[#requests]
  assert(U.pending and request)
  U.onDownloadError("sysDownloadError",message or "Host not found",request.path)
end

test("network retries wait one five and fifteen minutes then stop",function()
  U.check(true); networkFailure()
  assert(U.retryAttempt==1 and U.timers.retry and not U.pending)
  advance(59); assert(#requests==1)
  advance(1); assert(#requests==2 and U.pending)
  networkFailure(); advance(299); assert(#requests==2)
  advance(1); assert(#requests==3)
  networkFailure(); advance(899); assert(#requests==3)
  advance(1); assert(#requests==4)
  networkFailure(); advance(1000)
  assert(#requests==4 and U.retryAttempt==3 and not U.timers.retry and removals==0)
end)

test("a timeout schedules a bounded retry and ignores the previous late file",function()
  U.check(true); local old=requests[1].path
  advance(60)
  assert(U.timers.retry and not U.pending)
  files[old]="good"; U.onDownloaded("sysDownloadDone",old)
  advance(59); assert(#requests==1 and removals==0)
  advance(1); assert(#requests==2 and requests[2].path~=old)
end)

test("a package network error restarts manifest validation before a successful retry",function()
  U.check(true); reply("good")
  local old=requests[2].path; files[old]="partial"
  networkFailure(); assert(not files[old])
  advance(60)
  assert(#requests==3 and requests[3].url:find("/releases/latest/download/update.json",1,true))
  reply("good"); reply(payload); advance(.2)
  assert(removals==1 and #installs==1 and U.retryAttempt==0)
end)

test("checksum failures are not automatically retried",function()
  U.command("autoaktualizacja","off")
  decoder.good.sha256=string.rep("0",64)
  U.check(true); reply("good"); reply(payload); advance(.2)
  assert(not U.timers.retry and removals==0)
  advance(1000); assert(#requests==2 and removals==0)
end)

test("disabling automatic checks cancels a scheduled background retry",function()
  U.check(false); networkFailure()
  assert(U.timers.retry)
  U.command("autoaktualizacja","off"); advance(1000)
  assert(#requests==1 and not U.timers.retry)
end)

test("an explicit manual check replaces the earlier retry without overlapping requests",function()
  U.check(true); networkFailure(); advance(10)
  U.check(true)
  assert(#requests==2 and not U.timers.retry and U.retryAttempt==0)
  reply("good"); reply(payload); advance(.2)
  assert(removals==1 and #installs==1)
end)

test("repository changes cancel retries for the previous release source",function()
  U.command("autoaktualizacja","off")
  U.check(true); networkFailure()
  U.command("repo","other/kozojeb"); advance(1000)
  assert(#requests==1 and not U.timers.retry and U.retryAttempt==0)
end)

test("updater cleanup removes both retry and periodic timers",function()
  U.check(true); networkFailure(); U.cleanup(); advance(30000)
  assert(#requests==1 and next(U.timers)==nil)
end)

test("download reasons are short single line text without redirected URL secrets",function()
  U.check(true)
  networkFailure("Host not found\n<red>https://assets.example/file?token=private123 "..string.rep("x",300))
  assert(U.status:find("Host not found",1,true))
  assert(not U.status:find("private123",1,true) and not U.status:find("https://",1,true))
  assert(not U.status:find("\n",1,true) and not U.status:find("<red>",1,true) and #U.status<300)
end)

test("a failure to start downloading is retried without exceeding the retry budget",function()
  local original=downloadFile
  downloadFile=function(path,url) original(path,url); return false end
  U.check(true); advance(1261)
  downloadFile=original
  assert(#requests==4 and not U.timers.retry and not U.pending and removals==0)
end)

print(string.format("%d updater simulations passed",total))
