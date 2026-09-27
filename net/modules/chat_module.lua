
local api = ...

local DATA_DIR = "net/site_data"
local CHAT_FILE = fs.combine(DATA_DIR, "chat_data.txt")

if not fs.exists(DATA_DIR) then fs.makeDir(DATA_DIR) end

local chatRooms = {
  ["general"] = { password = "", whitelist = nil, messages = {} }
}

local function loadChatData()
  if fs.exists(CHAT_FILE) then
    local file = fs.open(CHAT_FILE, "r")
    if file then
      local data = textutils.unserialize(file.readAll())
      file.close()
      if data then chatRooms = data end
    end
  end
end

local function saveChatData()
  local file = fs.open(CHAT_FILE, "w")
  if file then
    file.write(textutils.serialize(chatRooms))
    file.close()
  end
end

loadChatData()

local function isUserAllowed(room, username)
  if not room.whitelist then return true end
  if not username or username == "" then return false end
  return room.whitelist[username:lower()] == true
end

local function verifyAccess(room, username, password)
  if not isUserAllowed(room, username) then
    return false, "User not on room whitelist."
  end
  if room.password and room.password ~= "" then
    if password ~= room.password then
      return false, "Invalid password."
    end
  end
  return true, nil
end

--------------------------------------------------
-- REDNET PACKET HANDLERS
--------------------------------------------------
api.registerPacketHandler("CHAT_GET_ROOMS", function(senderID, packet)
  local username = packet.user or ""
  local visibleRooms = {}
  for rName, rData in pairs(chatRooms) do
    if isUserAllowed(rData, username) then
      table.insert(visibleRooms, {
        name = rName,
        hasPassword = (rData.password and rData.password ~= ""),
        isWhitelisted = (rData.whitelist ~= nil)
      })
    end
  end
  rednet.send(senderID, { type = "CHAT_ROOMS", rooms = visibleRooms }, "homeos_mesh")
end)

api.registerPacketHandler("CHAT_CREATE_ROOM", function(senderID, packet)
  local roomName = packet.roomName
  if not roomName or roomName == "" then
    rednet.send(senderID, { type = "CHAT_ERROR", msg = "Invalid room name." }, "homeos_mesh")
  elseif chatRooms[roomName] then
    rednet.send(senderID, { type = "CHAT_ERROR", msg = "Room already exists." }, "homeos_mesh")
  else
    local whitelistTable = nil
    if packet.whitelistUsernames and packet.whitelistUsernames ~= "" then
      whitelistTable = {}
      for user in packet.whitelistUsernames:gmatch("[^,%s]+") do
        whitelistTable[user:lower()] = true
      end
      if packet.user then
        whitelistTable[packet.user:lower()] = true
      end
    end

    chatRooms[roomName] = {
      password = packet.password or "",
      whitelist = whitelistTable,
      messages = {}
    }
    saveChatData()
    rednet.send(senderID, { type = "CHAT_SUCCESS", msg = "Room created." }, "homeos_mesh")
  end
end)

api.registerPacketHandler("CHAT_GET_MESSAGES", function(senderID, packet)
  local rData = chatRooms[packet.roomName]
  if not rData then
    rednet.send(senderID, { type = "CHAT_ERROR", msg = "Room not found." }, "homeos_mesh")
  else
    local ok, err = verifyAccess(rData, packet.user, packet.password)
    if ok then
      rednet.send(senderID, { type = "CHAT_MESSAGES", roomName = packet.roomName, messages = rData.messages }, "homeos_mesh")
    else
      rednet.send(senderID, { type = "CHAT_ERROR", msg = err }, "homeos_mesh")
    end
  end
end)

api.registerPacketHandler("CHAT_POST_MESSAGE", function(senderID, packet)
  local rData = chatRooms[packet.roomName]
  if not rData then
    rednet.send(senderID, { type = "CHAT_ERROR", msg = "Room not found." }, "homeos_mesh")
  else
    local ok, err = verifyAccess(rData, packet.user, packet.password)
    if ok then
      table.insert(rData.messages, {
        user = packet.user,
        text = packet.text,
        time = textutils.formatTime(os.time(), false)
      })
      if #rData.messages > 50 then table.remove(rData.messages, 1) end
      saveChatData()
      rednet.send(senderID, { type = "CHAT_SUCCESS" }, "homeos_mesh")
    else
      rednet.send(senderID, { type = "CHAT_ERROR", msg = err }, "homeos_mesh")
    end
  end
end)

--------------------------------------------------
-- TERMINAL COMMAND REGISTRATIONS
--------------------------------------------------
api.registerCommand("rooms", "List all active chat rooms", "rooms", function()
  for k, v in pairs(chatRooms) do
    local info = "Room: " .. k .. " (" .. #v.messages .. " msgs)"
    if v.password ~= "" then info = info .. " [Pass]" end
    if v.whitelist then
      local users = {}
      for u in pairs(v.whitelist) do table.insert(users, u) end
      info = info .. " [Whitelist: " .. table.concat(users, ", ") .. "]"
    end
    print("[CHAT] " .. info)
  end
end)

api.registerCommand("addroom", "Create a chat room", "addroom <name> [pass] [users_csv]", function(args)
  if not args[2] then print("[CHAT] Missing room name.") return end
  local pass = args[3] or ""
  local wl = nil
  if args[4] then
    wl = {}
    for u in args[4]:gmatch("[^,%s]+") do wl[u:lower()] = true end
  end
  chatRooms[args[2]] = { password = pass, whitelist = wl, messages = {} }
  saveChatData()
  print("[CHAT] Room '" .. args[2] .. "' created.")
end)

api.registerCommand("delroom", "Delete a chat room", "delroom <name>", function(args)
  if args[2] and chatRooms[args[2]] then
    chatRooms[args[2]] = nil
    saveChatData()
    print("[CHAT] Room '" .. args[2] .. "' deleted.")
  else
    print("[CHAT] Room not found.")
  end
end)

api.registerCommand("clearroom", "Clear message history for a room", "clearroom <name>", function(args)
  if args[2] and chatRooms[args[2]] then
    chatRooms[args[2]].messages = {}
    saveChatData()
    print("[CHAT] Room '" .. args[2] .. "' history cleared.")
  else
    print("[CHAT] Room not found.")
  end
end)

api.registerCommand("whitelist", "Manage room whitelist", "whitelist <add|remove|disable> <room> [user]", function(args)
  local action = args[2]
  local roomName = args[3]
  local user = args[4]

  if not action or not roomName or not chatRooms[roomName] then
    print("[CHAT] Usage: whitelist <add|remove|disable> <room> [user]")
    return
  end

  local room = chatRooms[roomName]

  if action == "add" and user then
    if not room.whitelist then room.whitelist = {} end
    room.whitelist[user:lower()] = true
    saveChatData()
    print("[CHAT] Added '" .. user .. "' to whitelist for '" .. roomName .. "'.")

  elseif action == "remove" and user then
    if room.whitelist then
      room.whitelist[user:lower()] = nil
      saveChatData()
      print("[CHAT] Removed '" .. user .. "' from whitelist for '" .. roomName .. "'.")
    end

  elseif action == "disable" then
    room.whitelist = nil
    saveChatData()
    print("[CHAT] Whitelist disabled for '" .. roomName .. "' (public access).")

  else
    print("[CHAT] Invalid parameters.")
  end
end)
