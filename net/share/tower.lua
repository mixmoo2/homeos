local w, h = term.getSize()

-- Quick discovery pass
rednet.broadcast({ type = "PING_DISCOVERY" }, "homeos_mesh")

local activeNodes = {}
local timer = os.startTimer(0.3)

while true do
  local event, p1, p2, p3 = os.pullEvent()
  if event == "rednet_message" and p3 == "homeos_mesh" then
    if type(p2) == "table" and p2.type == "DISCOVERY_REPLY" then
      local exists = false
      for _, n in ipairs(activeNodes) do
        if n.hostID == p2.hostID then exists = true break end
      end
      if not exists then
        table.insert(activeNodes, {
          hostID = p2.hostID,
          hostLabel = p2.hostLabel or ("Host #" .. p2.hostID),
          sites = p2.sites or {}
        })
      end
    end
  elseif event == "timer" and p1 == timer then
    break
  end
end

table.sort(activeNodes, function(a, b) return a.hostID < b.hostID end)

local scrollOffset = 0
local siteEntries = {}

for _, node in ipairs(activeNodes) do
  for _, siteName in ipairs(node.sites) do
    table.insert(siteEntries, {
      url = node.hostID .. "/" .. siteName,
      siteName = siteName,
      hostID = node.hostID,
      hostLabel = node.hostLabel
    })
  end
end

local function drawDirectory()
  term.setBackgroundColor(colors.black)
  term.clear()

  -- Top Header (Canvas Row 1)
  term.setCursorPos(1, 1)
  term.setBackgroundColor(colors.blue)
  term.setTextColor(colors.white)
  term.clearLine()
  term.write(" TOWER NETWORK INDEX (" .. #siteEntries .. " sites)")

  local maxVisible = h - 1

  if #siteEntries == 0 then
    term.setCursorPos(2, 2)
    term.setBackgroundColor(colors.black)
    term.setTextColor(colors.lightGray)
    term.write("No active sites reachable on local mesh.")
    return
  end

  -- Draw Sites starting directly at Canvas Row 2
  local yPos = 2
  for i = 1 + scrollOffset, math.min(#siteEntries, scrollOffset + maxVisible) do
    local entry = siteEntries[i]

    term.setCursorPos(2, yPos)
    term.setBackgroundColor(colors.black)

    term.setTextColor(colors.yellow)
    term.write("* ")

    term.setTextColor(colors.cyan)
    term.write(entry.siteName)

    term.setTextColor(colors.gray)
    local metaText = " [Host #" .. entry.hostID .. " - " .. entry.hostLabel .. "]"
    term.write(metaText:sub(1, w - #entry.siteName - 5))

    yPos = yPos + 1
  end
end

drawDirectory()

while true do
  local event, p1, p2, p3 = os.pullEvent()

  if event == "mouse_click" and p1 == 1 then
    local x, y = p2, p3
    local maxVisible = math.min(#siteEntries - scrollOffset, h - 1)

    -- Row 1: Header
    -- Row 2+: Item list mapping
    if y >= 2 and y < 2 + maxVisible then
      local index = (y - 1) + scrollOffset
      if siteEntries[index] then
        local clickedEntry = siteEntries[index]

        term.setCursorPos(2, y)
        term.setBackgroundColor(colors.blue)
        term.setTextColor(colors.white)
        term.clearLine()
        term.write("* Opening " .. clickedEntry.url .. "...")

        if net and type(net.navigate) == "function" then
          net.navigate(clickedEntry.url)
          return
        end
      end
    end
  elseif event == "mouse_scroll" then
    local dir = p1
    if dir > 0 and scrollOffset < #siteEntries - (h - 1) then
      scrollOffset = scrollOffset + 1
      drawDirectory()
    elseif dir < 0 and scrollOffset > 0 then
      scrollOffset = scrollOffset - 1
      drawDirectory()
    end
  end
end
