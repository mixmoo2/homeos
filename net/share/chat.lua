local w, h = term.getSize()
local hostID = net and net.currentHost

if not hostID then
  term.setTextColor(colors.red)
  print("Error: WebViewer context missing!")
  return
end

local DATA_DIR = "disk/net/site_data/chat"
if not fs.exists(DATA_DIR) then fs.makeDir(DATA_DIR) end
local USER_FILE = fs.combine(DATA_DIR, "username.txt")

local function getSavedUser()
  if fs.exists(USER_FILE) then
    local f = fs.open(USER_FILE, "r")
    local u = f.readLine()
    f.close()
    if u and u ~= "" then return u end
  end
  return nil
end

local function saveUser(u)
  local f = fs.open(USER_FILE, "w")
  f.writeLine(u)
  f.close()
end

local username = getSavedUser()

if not username then
  term.setBackgroundColor(colors.black)
  term.clear()
  term.setCursorPos(2, 2)
  term.setTextColor(colors.yellow)
  term.write("=== HOMEOS CHAT INITIAL SETUP ===")
  term.setCursorPos(2, 4)
  term.setTextColor(colors.white)
  term.write("Enter display username: ")
  username = read()
  if username == "" then username = "Guest_" .. math.random(100, 999) end
  saveUser(username)
end

local currentRoom = nil
local roomPassword = ""
local messages = {}

local function sendReq(payload)
  rednet.send(hostID, payload, "homeos_mesh")
  local timer = os.startTimer(2.0)
  while true do
    local event, p1, p2, p3 = os.pullEvent()
    if event == "rednet_message" and p3 == "homeos_mesh" and type(p2) == "table" then
      return p2
    elseif event == "timer" and p1 == timer then
      return { type = "CHAT_ERROR", msg = "Server timeout." }
    end
  end
end

local function fetchRooms()
  local res = sendReq({ type = "CHAT_GET_ROOMS", user = username })
  if res.type == "CHAT_ROOMS" then return res.rooms end
  return {}
end

local function fetchMessages()
  if not currentRoom then return end
  local res = sendReq({
    type = "CHAT_GET_MESSAGES",
    roomName = currentRoom,
    user = username,
    password = roomPassword
  })
  if res.type == "CHAT_MESSAGES" then
    messages = res.messages
  end
end

local function drawRoomsMenu(rooms)
  term.setBackgroundColor(colors.black)
  term.clear()
  term.setCursorPos(1, 1)
  term.setBackgroundColor(colors.blue)
  term.setTextColor(colors.white)
  term.clearLine()
  term.write(" CHAT LOBBY | User: " .. username)

  term.setCursorPos(w - 11, 1)
  term.setBackgroundColor(colors.lime)
  term.setTextColor(colors.black)
  term.write(" [+CREATE] ")

  term.setBackgroundColor(colors.black)
  if #rooms == 0 then
    term.setCursorPos(2, 3)
    term.setTextColor(colors.gray)
    term.write("No visible rooms available.")
  else
    for i, r in ipairs(rooms) do
      if i + 1 > h - 1 then break end
      term.setCursorPos(2, 1 + i)
      term.setTextColor(colors.cyan)
      term.write("# " .. r.name)

      term.setTextColor(colors.gray)
      local tags = ""
      if r.hasPassword then tags = tags .. " [PASS]" end
      if r.isWhitelisted then tags = tags .. " [PRIVATE]" end
      term.write(tags)
    end
  end
end

local function createRoomUI()
  term.setBackgroundColor(colors.black)
  term.clear()
  term.setCursorPos(2, 2)
  term.setTextColor(colors.yellow)
  term.write("=== CREATE NEW ROOM ===")

  term.setCursorPos(2, 4)
  term.setTextColor(colors.white)
  term.write("Room Name: ")
  local rName = read()
  if rName == "" then return end

  term.setCursorPos(2, 6)
  term.write("Password (Optional): ")
  local rPass = read()

  term.setCursorPos(2, 8)
  term.write("Whitelist Users (csv, optional): ")
  local rWhite = read()

  local res = sendReq({
    type = "CHAT_CREATE_ROOM",
    roomName = rName,
    password = rPass,
    whitelistUsernames = rWhite,
    user = username
  })

  if res.type == "CHAT_SUCCESS" then
    currentRoom = rName
    roomPassword = rPass
  else
    term.setCursorPos(2, 11)
    term.setTextColor(colors.red)
    term.write("Error: " .. (res.msg or "Failed to create."))
    sleep(1.5)
  end
end

local function drawChatRoom()
  term.setBackgroundColor(colors.black)
  term.clear()

  term.setCursorPos(1, 1)
  term.setBackgroundColor(colors.blue)
  term.setTextColor(colors.white)
  term.clearLine()
  term.write(" ROOM: #" .. currentRoom .. " | " .. username)
  term.setCursorPos(w - 7, 1)
  term.setBackgroundColor(colors.red)
  term.write(" [LEAVE] ")

  local displayH = h - 3
  local startIdx = math.max(1, #messages - displayH + 1)
  local y = 2

  for i = startIdx, #messages do
    local msg = messages[i]
    term.setCursorPos(2, y)
    term.setBackgroundColor(colors.black)
    term.setTextColor(colors.gray)
    term.write("[" .. (msg.time or "--:--") .. "] ")

    term.setTextColor(msg.user == username and colors.lime or colors.yellow)
    term.write(msg.user .. ": ")

    term.setTextColor(colors.white)
    term.write(msg.text)
    y = y + 1
  end

  term.setCursorPos(1, h)
  term.setBackgroundColor(colors.gray)
  term.clearLine()
  term.setTextColor(colors.white)
  term.write("> ")
end

while true do
  if not currentRoom then
    local rooms = fetchRooms()
    drawRoomsMenu(rooms)

    local event, b, x, y = os.pullEvent()
    if event == "mouse_click" and b == 1 then
      if y == 1 and x >= w - 11 then
        createRoomUI()
      elseif y >= 2 and y < 2 + #rooms then
        local clickedRoom = rooms[y - 1]
        if clickedRoom then
          if clickedRoom.hasPassword then
            term.setCursorPos(2, h)
            term.setBackgroundColor(colors.black)
            term.setTextColor(colors.yellow)
            term.clearLine()
            term.write("Enter Password: ")
            roomPassword = read()
          else
            roomPassword = ""
          end

          currentRoom = clickedRoom.name
          fetchMessages()
        end
      end
    end
  else
    drawChatRoom()

    local timer = os.startTimer(1.5)
    local event, p1, p2, p3 = os.pullEvent()

    if event == "timer" and p1 == timer then
      fetchMessages()

    elseif event == "mouse_click" and p1 == 1 then
      local clickX, clickY = p2, p3

      if clickY == 1 and clickX >= w - 7 then
        currentRoom = nil
        roomPassword = ""
        messages = {}
      elseif clickY == h then
        term.setCursorPos(3, h)
        term.setBackgroundColor(colors.gray)
        term.setTextColor(colors.white)
        local input = read()
        if input and input ~= "" then
          sendReq({
            type = "CHAT_POST_MESSAGE",
            roomName = currentRoom,
            user = username,
            password = roomPassword,
            text = input
          })
          fetchMessages()
        end
      end
    end
  end
end
