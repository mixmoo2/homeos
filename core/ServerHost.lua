-- ServerHost.lua
local SHARE_DIR = "net/share"
local MODULES_DIR = "net/modules"
local SITE_DATA_DIR = "net/site_data"

if not fs.exists(SHARE_DIR) then fs.makeDir(SHARE_DIR) end
if not fs.exists(MODULES_DIR) then fs.makeDir(MODULES_DIR) end
if not fs.exists(SITE_DATA_DIR) then fs.makeDir(SITE_DATA_DIR) end

local modemSide = nil
for _, side in ipairs(peripheral.getNames()) do
  if peripheral.getType(side) == "modem" then
    modemSide = side
    break
  end
end

if not modemSide then
  term.setTextColor(colors.red)
  print("Error: No modem found! Attach a modem to host sites.")
  return
end

rednet.open(modemSide)
rednet.host("homeos_mesh", "host_" .. os.getComputerID())

local function updateHostInfo()
  local infoPath = fs.combine(SHARE_DIR, "host_info.txt")
  local file = fs.open(infoPath, "w")
  if file then
    file.writeLine("Host ID: " .. os.getComputerID())
    file.writeLine("Label: " .. (os.getComputerLabel() or "Unnamed Host"))
    file.writeLine("Share Directory: /" .. SHARE_DIR)
    file.close()
  end
end

local function getHostedSitesList()
  local sites = {}
  if fs.exists(SHARE_DIR) and fs.isDir(SHARE_DIR) then
    for _, f in ipairs(fs.list(SHARE_DIR)) do
      if not fs.isDir(fs.combine(SHARE_DIR, f)) and f:sub(-4) == ".lua" then
        table.insert(sites, f:sub(1, -5))
      end
    end
  end
  return sites
end

updateHostInfo()

--------------------------------------------------
-- STEP 1: INTERACTIVE MENU & FILE SELECTION
--------------------------------------------------
local hosted = getHostedSitesList()

term.setBackgroundColor(colors.black)
term.clear()
term.setCursorPos(1, 1)

term.setTextColor(colors.yellow)
print("==================================================")
print("             HOME OS SERVER HOST v1.4             ")
print("==================================================")
term.setTextColor(colors.white)
print("Host ID: #" .. os.getComputerID())
print("Directory: /" .. SHARE_DIR)
print("--------------------------------------------------")

if #hosted == 0 then
  term.setTextColor(colors.red)
  print("No .lua files found in /" .. SHARE_DIR .. "/")
  print("Place your site scripts (e.g. tower.lua) inside /" .. SHARE_DIR .. "/")
  return
end

term.setTextColor(colors.cyan)
print("Available Site Files Found:")
for i, siteName in ipairs(hosted) do
  term.setTextColor(colors.white)
  print("  [" .. i .. "] " .. siteName .. ".lua")
end

print("--------------------------------------------------")
term.setTextColor(colors.yellow)
write("Select a site [1-" .. #hosted .. "] or press ENTER for ALL: ")

local input = read()
local activeSites = {}

if input ~= "" and tonumber(input) then
  local choice = tonumber(input)
  if hosted[choice] then
    activeSites[hosted[choice]:gsub("%.lua$", "")] = true
  end
else
  for _, site in ipairs(hosted) do
    activeSites[site] = true
  end
end

--------------------------------------------------
-- DYNAMIC MODULE REGISTRY (BASED ON HOSTED SITES)
--------------------------------------------------
local packetHandlers = {}
local customCommands = {}

local serverAPI = {
  activeSites = activeSites,
  registerPacketHandler = function(packetType, handlerFunc)
    packetHandlers[packetType] = handlerFunc
  end,
  registerCommand = function(cmdName, description, usage, handlerFunc)
    customCommands[cmdName] = {
      desc = description,
      usage = usage,
      run = handlerFunc
    }
  end
}

local function reloadActiveModules()
  packetHandlers = {}
  customCommands = {}

  for siteName, isActive in pairs(activeSites) do
    if isActive then
      local candidatePaths = {
        fs.combine(MODULES_DIR, siteName .. "_module.lua"),
        fs.combine(MODULES_DIR, siteName .. ".lua")
      }
      for _, path in ipairs(candidatePaths) do
        if fs.exists(path) and not fs.isDir(path) then
          local fn, err = loadfile(path)
          if fn then
            local ok, execErr = pcall(fn, serverAPI)
            if not ok then
              term.setTextColor(colors.red)
              print("[MODULE RUN ERROR] " .. siteName .. ": " .. tostring(execErr))
            end
          else
            term.setTextColor(colors.red)
            print("[MODULE LOAD ERROR] " .. siteName .. ": " .. tostring(err))
          end
          break
        end
      end
    end
  end
end

reloadActiveModules()

--------------------------------------------------
-- STEP 2: SERVER LISTENER & CLICK CONSOLE
--------------------------------------------------
term.setBackgroundColor(colors.black)
term.clear()
term.setCursorPos(1, 1)

term.setTextColor(colors.yellow)
print("==================================================")
print("             HOME OS SERVER LISTENER              ")
print("==================================================")
term.setTextColor(colors.white)
print("[SYS] Host ID: #" .. os.getComputerID())
print("[SYS] Share Path: /" .. SHARE_DIR)
print("[SYS] Click anywhere on the screen to open console.")
print("--------------------------------------------------")
term.setTextColor(colors.lime)
print("[NET] Server Online & Listening on Rednet...")
term.setTextColor(colors.white)

local function serverListener()
  while true do
    local senderID, packet = rednet.receive("homeos_mesh")

    if type(packet) == "table" and packet.type then
      if packet.type == "PING_DISCOVERY" then
        local siteList = {}
        for k, v in pairs(activeSites) do
          if v then table.insert(siteList, k) end
        end
        rednet.send(senderID, {
          type = "DISCOVERY_REPLY",
          hostID = os.getComputerID(),
          hostLabel = os.getComputerLabel() or ("Host #" .. os.getComputerID()),
          sites = siteList
        }, "homeos_mesh")

      elseif packet.type == "GET_SITE" then
        local requestedSite = packet.targetSite
        term.setTextColor(colors.white)
        write("[LOG] Request for '" .. tostring(requestedSite) .. "' from #" .. senderID .. " -> ")

        if activeSites[requestedSite] then
          local filePath = fs.combine(SHARE_DIR, requestedSite .. ".lua")
          if fs.exists(filePath) and not fs.isDir(filePath) then
            local file = fs.open(filePath, "r")
            local code = file.readAll()
            file.close()
            rednet.send(senderID, { type = "SITE_RESPONSE", status = 200, targetSite = requestedSite, body = code }, "homeos_mesh")
            term.setTextColor(colors.green)
            print("200 OK")
          else
            rednet.send(senderID, { type = "SITE_RESPONSE", status = 404, targetSite = requestedSite, errorMessage = "File missing" }, "homeos_mesh")
            term.setTextColor(colors.red)
            print("404 Not Found")
          end
        else
          rednet.send(senderID, { type = "SITE_RESPONSE", status = 403, targetSite = requestedSite, errorMessage = "Site not actively hosted" }, "homeos_mesh")
          term.setTextColor(colors.orange)
          print("403 Forbidden (Not active)")
        end
        term.setTextColor(colors.white)

      elseif packetHandlers[packet.type] then
        packetHandlers[packet.type](senderID, packet)
      end
    end
  end
end

local function clickConsole()
  local w, h = term.getSize()
  while true do
    os.pullEvent("mouse_click")

    local curX, curY = term.getCursorPos()
    term.setCursorPos(1, h)
    term.setTextColor(colors.yellow)
    term.clearLine()
    write("CMD> ")
    term.setTextColor(colors.white)

    local input = read()
    term.setCursorPos(1, h)
    term.clearLine()
    term.setCursorPos(curX, curY)

    local args = {}
    for word in input:gmatch("%S+") do table.insert(args, word) end
    local cmd = args[1]

    if cmd then
      term.setTextColor(colors.magenta)

      if cmd == "help" then
        print("[SYS] Core Commands: help, run <site>, kill <site>")
        local hasCustom = false
        for name, data in pairs(customCommands) do
          hasCustom = true
          print("[HOSTED CMD] " .. name .. " - " .. data.desc .. " | Usage: " .. data.usage)
        end
        if not hasCustom then
          print("[SYS] No additional commands available for currently hosted programs.")
        end

      elseif cmd == "run" and args[2] then
        activeSites[args[2]] = true
        reloadActiveModules()
        print("[SYS] Added '" .. args[2] .. "' to active list and loaded commands.")

      elseif cmd == "kill" and args[2] then
        activeSites[args[2]] = nil
        reloadActiveModules()
        print("[SYS] Removed '" .. args[2] .. "' from active list and unloaded commands.")

      elseif customCommands[cmd] then
        customCommands[cmd].run(args)

      else
        term.setTextColor(colors.red)
        print("[SYS] Unknown command or program not actively hosted.")
      end
      term.setTextColor(colors.white)
    end
  end
end

parallel.waitForAny(serverListener, clickConsole)
