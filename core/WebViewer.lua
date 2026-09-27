-- WebViewer.lua
local SYS_DIR = "disk/net"
local BOOKMARKS_FILE = fs.combine(SYS_DIR, "bookmarks.txt")
local HISTORY_FILE = fs.combine(SYS_DIR, "history.txt")

if not fs.exists(SYS_DIR) then fs.makeDir(SYS_DIR) end
if not fs.exists(fs.combine(SYS_DIR, "cookies")) then fs.makeDir(fs.combine(SYS_DIR, "cookies")) end
if not fs.exists(fs.combine(SYS_DIR, "site_data")) then fs.makeDir(fs.combine(SYS_DIR, "site_data")) end

local modemSide = nil
for _, side in ipairs(peripheral.getNames()) do
  if peripheral.getType(side) == "modem" then
    modemSide = side
    break
  end
end

if not modemSide then
  term.setTextColor(colors.red)
  print("Error: WebViewer requires a Rednet modem attached!")
  return
end
rednet.open(modemSide)

local currentUrl = ""
local currentHostID = nil
local currentSiteName = ""
local showBookmarks = false
local pendingNavigation = "tower"
local mainTerm = term.current()
local screenW, screenH = mainTerm.getSize()

-- Dedicated site canvas (Rows 2 to screenH)
local siteCanvas = window.create(mainTerm, 1, 2, screenW, screenH - 1, true)

local function readLines(path)
  if not fs.exists(path) then return {} end
  local file = fs.open(path, "r")
  local lines = {}
  local line = file.readLine()
  while line do
    if line ~= "" then table.insert(lines, line) end
    line = file.readLine()
  end
  file.close()
  return lines
end

local function appendLine(path, text)
  local file = fs.open(path, "a")
  if file then
    file.writeLine(text)
    file.close()
  end
end

local function addBookmark(url)
  local bookmarks = readLines(BOOKMARKS_FILE)
  for _, b in ipairs(bookmarks) do
    if b == url then return end
  end
  appendLine(BOOKMARKS_FILE, url)
end

local function drawHeader()
  mainTerm.setCursorPos(1, 1)
  mainTerm.setBackgroundColor(colors.gray)
  mainTerm.clearLine()

  -- HOME
  mainTerm.setCursorPos(2, 1)
  mainTerm.setBackgroundColor(colors.blue)
  mainTerm.setTextColor(colors.white)
  mainTerm.write(" HOME ")

  -- BOOKMK
  mainTerm.setCursorPos(9, 1)
  mainTerm.setBackgroundColor(colors.cyan)
  mainTerm.setTextColor(colors.black)
  mainTerm.write(" BOOKMK ")

  -- REFRSH
  mainTerm.setCursorPos(18, 1)
  mainTerm.setBackgroundColor(colors.yellow)
  mainTerm.setTextColor(colors.black)
  mainTerm.write(" REFRSH ")

  -- URL BAR
  mainTerm.setCursorPos(27, 1)
  mainTerm.setBackgroundColor(colors.black)
  mainTerm.setTextColor(colors.lime)
  local urlSpace = screenW - 30
  local displayUrl = currentUrl == "" and "[ Type URL ]" or currentUrl
  if #displayUrl > urlSpace then
    displayUrl = displayUrl:sub(1, urlSpace)
  else
    displayUrl = displayUrl .. string.rep(" ", urlSpace - #displayUrl)
  end
  mainTerm.write(displayUrl)

  -- EXIT
  mainTerm.setCursorPos(screenW - 2, 1)
  mainTerm.setBackgroundColor(colors.red)
  mainTerm.setTextColor(colors.white)
  mainTerm.write(" X ")
end

local function openBookmarksModal()
  while true do
    local bookmarks = readLines(BOOKMARKS_FILE)
    local popupW = 34
    local popupH = math.max(6, math.min(#bookmarks + 4, 12))
    local startX = 6
    local startY = 3

    -- Draw Modal Header
    mainTerm.setCursorPos(startX, startY)
    mainTerm.setBackgroundColor(colors.blue)
    mainTerm.setTextColor(colors.white)
    mainTerm.write(" Bookmarks " .. string.rep(" ", popupW - 19))

    -- [+ADD]
    mainTerm.setBackgroundColor(colors.lime)
    mainTerm.setTextColor(colors.black)
    mainTerm.write("[+ADD]")

    -- [X]
    mainTerm.setBackgroundColor(colors.blue)
    mainTerm.setTextColor(colors.red)
    mainTerm.write(" [X] ")

    -- Fill Body
    for row = 1, popupH - 1 do
      mainTerm.setCursorPos(startX, startY + row)
      mainTerm.setBackgroundColor(colors.lightGray)
      mainTerm.write(string.rep(" ", popupW))
    end

    if #bookmarks == 0 then
      mainTerm.setCursorPos(startX + 2, startY + 2)
      mainTerm.setBackgroundColor(colors.lightGray)
      mainTerm.setTextColor(colors.gray)
      mainTerm.write("No bookmarks! Click [+ADD]")
    else
      for i = 1, math.min(#bookmarks, popupH - 2) do
        mainTerm.setCursorPos(startX + 2, startY + 1 + i)
        mainTerm.setTextColor(colors.black)
        mainTerm.setBackgroundColor(colors.lightGray)
        mainTerm.write(i .. ". " .. bookmarks[i]:sub(1, popupW - 5))
      end
    end

    -- Event Trap Loop for Modal
    local event, button, x, y = os.pullEvent()
    if event == "mouse_click" and button == 1 then
      local inModalX = x >= startX and x <= startX + popupW - 1
      local inModalY = y >= startY and y <= startY + popupH - 1

      if inModalX and inModalY then
        -- Top row of modal
        if y == startY then
          local closeXStart = startX + popupW - 5
          local addXStart = startX + popupW - 12
          local addXEnd = startX + popupW - 7

          if x >= closeXStart then
            break -- Close Modal
          elseif x >= addXStart and x <= addXEnd then
            if currentUrl ~= "" then addBookmark(currentUrl) end
          end
        else
          -- Clicked Bookmark Line
          local idx = y - startY - 1
          if bookmarks[idx] then
            pendingNavigation = bookmarks[idx]
            break
          end
        end
      else
        break -- Clicked outside modal: close
      end
    end
  end

  showBookmarks = false
  siteCanvas.redraw()
end

local function createSiteAPI(siteName)
  local siteDir = fs.combine(SYS_DIR, "site_data/" .. siteName)
  if not fs.exists(siteDir) then fs.makeDir(siteDir) end

  return {
    currentHost = currentHostID,
    host = currentHostID,
    navigate = function(targetUrl)
      os.queueEvent("webview_navigate", targetUrl)
    end,
    addBookmark = function()
      if currentUrl ~= "" then addBookmark(currentUrl) end
    end
  }
end

local function discoverHostsForSite(siteName)
  rednet.broadcast({ type = "PING_DISCOVERY" }, "homeos_mesh")
  local matchingHosts = {}
  local timer = os.startTimer(0.8)

  while true do
    local event, p1, p2, p3 = os.pullEvent()
    if event == "rednet_message" and p3 == "homeos_mesh" then
      if type(p2) == "table" and p2.type == "DISCOVERY_REPLY" then
        for _, s in ipairs(p2.sites or {}) do
          if s == siteName then
            table.insert(matchingHosts, { id = p2.hostID, label = p2.hostLabel })
          end
        end
      end
    elseif event == "timer" and p1 == timer then
      break
    end
  end
  return matchingHosts
end

local function fetchSiteCode(targetUrl)
  if not targetUrl or targetUrl == "" then targetUrl = "tower" end

  term.redirect(siteCanvas)
  siteCanvas.setBackgroundColor(colors.black)
  siteCanvas.clear()
  siteCanvas.setCursorPos(2, 2)
  siteCanvas.setTextColor(colors.cyan)
  siteCanvas.write("Connecting to network...")

  local parsedHostID = targetUrl:match("^(%d+)/")
  local parsedSiteName = targetUrl:match("/(.+)$") or targetUrl

  if not parsedHostID then
    local availableHosts = discoverHostsForSite(parsedSiteName)
    if #availableHosts == 0 then
      siteCanvas.clear()
      siteCanvas.setCursorPos(2, 2)
      siteCanvas.setTextColor(colors.red)
      siteCanvas.write("404: Site '" .. parsedSiteName .. "' not found.")
      term.redirect(mainTerm)
      return nil
    else
      currentHostID = availableHosts[1].id
    end
  else
    currentHostID = tonumber(parsedHostID)
  end

  currentSiteName = parsedSiteName
  currentUrl = currentHostID .. "/" .. currentSiteName

  term.redirect(mainTerm)
  drawHeader()
  term.redirect(siteCanvas)

  rednet.send(currentHostID, { type = "GET_SITE", targetSite = currentSiteName }, "homeos_mesh")

  local timer = os.startTimer(3.0)
  local responseCode = nil

  while true do
    local event, p1, p2, p3 = os.pullEvent()
    if event == "rednet_message" and p3 == "homeos_mesh" then
      if type(p2) == "table" and p2.type == "SITE_RESPONSE" then
        if p2.status == 200 then responseCode = p2.body end
        break
      end
    elseif event == "timer" and p1 == timer then
      break
    end
  end

  if responseCode then
    appendLine(HISTORY_FILE, currentUrl)
    siteCanvas.clear()
    siteCanvas.setCursorPos(1, 1)
    term.redirect(siteCanvas)
    return responseCode
  else
    siteCanvas.clear()
    siteCanvas.setCursorPos(2, 2)
    siteCanvas.setTextColor(colors.red)
    siteCanvas.write("Error: Host #" .. currentHostID .. " failed to respond.")
    term.redirect(mainTerm)
    return nil
  end
end

local function browserUIThread()
  drawHeader()

  while true do
    local event, p1, p2, p3 = os.pullEvent()

    if event == "webview_navigate" then
      pendingNavigation = p1
      return

    elseif event == "mouse_click" and p1 == 1 then
      local x, y = p2, p3

      -- Top Bar Clicked (Row 1)
      if y == 1 then
        if x >= 2 and x <= 7 then -- HOME
          pendingNavigation = "tower"
          return

        elseif x >= 9 and x <= 16 then -- BOOKMK
          openBookmarksModal()
          if pendingNavigation then return end

        elseif x >= 18 and x <= 25 then -- REFRSH
          if currentUrl ~= "" then
            pendingNavigation = currentUrl
            return
          end

        elseif x >= 27 and x <= screenW - 4 then -- URL
          mainTerm.setCursorPos(27, 1)
          mainTerm.setBackgroundColor(colors.black)
          mainTerm.setTextColor(colors.white)
          mainTerm.write(string.rep(" ", screenW - 30))
          mainTerm.setCursorPos(27, 1)
          mainTerm.setCursorBlink(true)
          local input = read()
          mainTerm.setCursorBlink(false)
          if input ~= "" then
            pendingNavigation = input
            return
          end

        elseif x >= screenW - 2 then -- EXIT
          term.redirect(mainTerm)
          term.setBackgroundColor(colors.black)
          term.clear()
          term.setCursorPos(1, 1)
          error("WebViewer Closed", 0)
        end
      end
    end
  end
end

-- MAIN EXECUTIVE LOOP
drawHeader()
while true do
  local target = pendingNavigation or "tower"
  pendingNavigation = nil
  local siteCode = fetchSiteCode(target)

  if siteCode then
    local siteApi = createSiteAPI(currentSiteName)
    _G.net = siteApi

    -- Calculate canvas Y offset
    local _, canvasTopY = siteCanvas.getPosition()
    local yOffset = canvasTopY - 1

    -- Environment sandbox
    local siteEnv = setmetatable({ net = siteApi }, { __index = _G })
    siteEnv.os = setmetatable({}, { __index = _G.os })

    local function wrapPull(pullFunc, filter)
      while true do
        local eventData = { pullFunc(filter) }
        local eType = eventData[1]

        if eType == "mouse_click" or eType == "mouse_up" or eType == "mouse_drag" or eType == "mouse_scroll" then
          if type(eventData[4]) == "number" then
            eventData[4] = eventData[4] - yOffset
          end
        end

        return table.unpack(eventData)
      end
    end

    siteEnv.os.pullEvent = function(filter)
      return wrapPull(_G.os.pullEvent, filter)
    end

    siteEnv.os.pullEventRaw = function(filter)
      return wrapPull(_G.os.pullEventRaw, filter)
    end

    local fn, err = load(siteCode, currentSiteName, "t", siteEnv)

    if fn then
      local siteError = nil
      local function runSite()
        term.redirect(siteCanvas)
        local ok, runErr = pcall(fn)
        if not ok then
          siteError = runErr
        end
        term.redirect(mainTerm)
      end

      local ok, err = pcall(function()
        parallel.waitForAny(runSite, browserUIThread)
      end)

      if err and (err == "WebViewer Closed" or err:find("WebViewer Closed")) then
        break
      end

      if siteError then
        term.redirect(siteCanvas)
        siteCanvas.setBackgroundColor(colors.black)
        siteCanvas.clear()
        siteCanvas.setCursorPos(2, 2)
        siteCanvas.setTextColor(colors.red)
        siteCanvas.write("Runtime Error in " .. currentSiteName .. ":")
        siteCanvas.setCursorPos(2, 4)
        siteCanvas.setTextColor(colors.white)
        siteCanvas.write(tostring(siteError))
        term.redirect(mainTerm)
        browserUIThread()
      elseif not pendingNavigation then
        browserUIThread()
      end
    else
      siteCanvas.setTextColor(colors.red)
      siteCanvas.write("Syntax Error in Site Code:\n" .. tostring(err))
      term.redirect(mainTerm)
      browserUIThread()
    end
  else
    browserUIThread()
  end
end
