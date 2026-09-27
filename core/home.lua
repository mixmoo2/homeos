--this is the main program for homeOs by mixmoo2
online, openport = nil, nil
hasspeakers, hasp, haswether = nil, nil, nil
modem = peripheral.find("modem") or printError("No modem attached, starting offline")

local function ensureSettingsFile()
    if not fs.exists("/user_files") then
        fs.makeDir("/user_files")
    end
    if not fs.exists("/user_files/homesetings.text") then
        local handle = fs.open("/user_files/homesetings.text", "w")
        if handle then
            handle.writeLine("loadingScreen=gray def")
            handle.writeLine("homeColor=magenta de")
            handle.writeLine("taskbarColor=gray d")
            handle.writeLine("pointerColor=yellow de")
            handle.writeLine("comModem=1 d")
            handle.close()
        end
    end
end

function box(...) return paintutils.drawFilledBox(...) end
function line(...) return paintutils.drawLine(...) end
function bCol(c) return term.setBackgroundColor(c) end
function tCol(c) return term.setTextColor(c) end
function cls() return term.clear() end
function pos(px, py) return term.setCursorPos(px, py) end

x, y = term.getSize()
diaR = false
diaInput = ""

local function hashPassword(str)
    local hash = 5381
    for i = 1, #str do
        hash = bit32.band(bit32.lshift(hash, 5) + hash + string.byte(str, i), 0xFFFFFFFF)
    end
    return string.format("%08x", hash)
end

function import(file, pre, en)
if not fs.exists(file) then
return nil, "Error: File '" .. tostring(file) .. "' does not exist."
end
local handle = fs.open(file, "r")
if not handle then
return nil, "Error: Could not open file '" .. tostring(file) .. "'"
end
local content = handle.readAll()
handle.close()

local function escapePattern(str)
return str:gsub("([%^%$%(%)%%%.%[%]%*%+%-%?])", "%%%1")
end

local safePre = escapePattern(pre)
local safeEn = escapePattern(en)
local pattern = safePre .. "(.-)" .. safeEn
local target = content:match(pattern)

if target then
return target
else
return nil, "Error: Target string not found."
end
end

function isonline()
if modem then online = true else online = false end
end

function loding()
cls()
local result, err = import("/user_files/homesetings.text", "loadingScreen=", " def")
bCol(colors[result] or colors.gray)
cls()
box(x/2-7, y/2-1, x/2+7, y/2+2, colors.black)
pos(x/2-4, y/2)
tCol(colors.green)
write("{loading}")
pos(x/2-6, y/2+1)
write("just a moment")
end

function diaS()
diaR = false
parentTerm = term.current()
dialogWidth = math.floor(x / 2)
dialogHeight = y - 2
dialogX = x - dialogWidth + 1
dialogY = 1
dia = window.create(parentTerm, dialogX, dialogY, dialogWidth, dialogHeight)
end

local function startscreen()
bCol(colors.blue)
tCol(colors.white)
cls()
pos(1, 1)
if os.getComputerLabel() ~= nil then
print(os.getComputerLabel())
end
if online then
print("you are online on port " .. tostring(openport))
else
print("you are offline")
end
if hasspeakers then print("speakers detected") end
if hasp then print("printer detected") end
if haswether then print("weather box detected") end

print("everything loaded")
print("press key to continue")
os.pullEvent("key")
end

local function homescreen()
local result = import("/user_files/homesetings.text", "homeColor=", " de")
local homeC = colors[result] or colors.magenta

result = import("/user_files/homesetings.text", "taskbarColor=", " d")
local taskbarC = colors[result] or colors.gray
local horizontalScroll = 0
local currentDir = "/core"
diaS()

local function getDisplayDir(dir)
if dir == "/core" then
return "/"
elseif dir:sub(1, 6) == "/core/" then
return "/" .. dir:sub(7)
end
return dir
end

local function getSavedPos(appName, defaultX, defaultY)
local savedX = import("/user_files/homesetings.text", appName .. "_x=", " d")
local savedY = import("/user_files/homesetings.text", appName .. "_y=", " d")
return tonumber(savedX) or defaultX, tonumber(savedY) or defaultY
end

local superX, superY = getSavedPos("super", 2, 2)
local printX, printY = getSavedPos("printApp", 2, 6)
local musicX, musicY = getSavedPos("musicApp", 2, 10)

local apps = {
super = { x = superX, y = superY, w = 13, h = 3, label = "super edit!", bg = colors.blue, path = "/core/super.lua" },
printApp = { x = printX, y = printY, w = 13, h = 3, label = "print      ", bg = colors.red, path = "/core/print.lua" },
musicApp = { x = musicX, y = musicY, w = 13, h = 3, label = "music      ", bg = colors.brown, path = "/core/play.lua" }
}

local function loadCustomButtons()
local handle = fs.open("/user_files/homesetings.text", "r")
if not handle then return end
local content = handle.readAll()
handle.close()

for id, label, bg, path, xPos, yPos in content:gmatch("btn_([%w_]+)={label=\"(.-)\",bg=(%d+),path=\"(.-)\",x=(%d+),y=(%d+)} d") do
apps[id] = {
x = tonumber(xPos),
y = tonumber(yPos),
w = 13,
h = 3,
label = label,
bg = tonumber(bg) or colors.gray,
path = path
}
end
end

loadCustomButtons()

local function saveAppPosition(appName, appX, appY)
local configPath = "/user_files/homesetings.text"
if not fs.exists(configPath) then return end

local handle = fs.open(configPath, "r")
local content = handle and handle.readAll() or ""
if handle then handle.close() end

local function setKey(text, key, val)
local pattern = key .. "=.- d"
local newValue = key .. "=" .. tostring(val) .. " d"
if text:find(pattern) then
return text:gsub(pattern, newValue)
else
return text .. "\n" .. newValue
end
end

content = setKey(content, appName .. "_x", appX)
content = setKey(content, appName .. "_y", appY)

handle = fs.open(configPath, "w")
if handle then
handle.write(content)
handle.close()
end
end

local function saveCustomButton(id, label, bg, path, appX, appY)
local configPath = "/user_files/homesetings.text"
local handle = fs.open(configPath, "r")
local content = handle and handle.readAll() or ""
if handle then handle.close() end

local entryPattern = "btn_" .. id .. "=.- d"
local entryLine = string.format('btn_%s={label="%s",bg=%d,path="%s",x=%d,y=%d} d', id, label, bg, path, appX, appY)

if content:find(entryPattern) then
content = content:gsub(entryPattern, entryLine)
else
content = content .. "\n" .. entryLine
end

handle = fs.open(configPath, "w")
if handle then
handle.write(content)
handle.close()
end
end

local function removeCustomButton(id)
local configPath = "/user_files/homesetings.text"
local handle = fs.open(configPath, "r")
if not handle then return end
local content = handle.readAll()
handle.close()

local entryPattern = "\n?btn_" .. id .. "=.- d"
content = content:gsub(entryPattern, "")

handle = fs.open(configPath, "w")
if handle then
handle.write(content)
handle.close()
end
end

local envVars = {}
local function loadEnvVars()
envVars = {}
if not fs.exists("/core/envconfig.text") then return end
local handle = fs.open("/core/envconfig.text", "r")
if handle then
local line = handle.readLine()
while line do
local k, v = line:match("^([%w_]+)%s*=%s*(.*)$")
if k and v then envVars[k] = v end
line = handle.readLine()
end
handle.close()
end
end

local function saveEnvVars()
local handle = fs.open("/core/envconfig.text", "w")
if handle then
for k, v in pairs(envVars) do
handle.writeLine(k .. "=" .. v)
end
handle.close()
end
end

loadEnvVars()

local cmdHistory = {}
local historyIndex = 0
if fs.exists("/user_files/.cmd_history") then
local hFile = fs.open("/user_files/.cmd_history", "r")
if hFile then
local line = hFile.readLine()
while line do
table.insert(cmdHistory, line)
line = hFile.readLine()
end
hFile.close()
historyIndex = #cmdHistory + 1
end
end

local function saveHistory(cmd)
table.insert(cmdHistory, cmd)
historyIndex = #cmdHistory + 1
local hFile = fs.open("/user_files/.cmd_history", "a")
if hFile then
hFile.writeLine(cmd)
hFile.close()
end
end

local aliases = {
c = "clear",
h = "help",
l = "ls",
e = "edit",
r = "run",
md = "mkdir",
del = "rm"
}

local draggingTarget = nil
local dragOffsetX, dragOffsetY = 0, 0
local isMoved = false

local history = {}
local scrollOffset = 0
local currentInput = ""
local isFocused = false

local function drawTime()
local timeStr = textutils.formatTime(os.time("local"))
local timeX = x - #timeStr + 1

local ct = term.redirect(parentTerm)
box(x-9, y-1, x, y-1, colors.black)
pos(timeX, y-1)
tCol(colors.white)
bCol(colors.black)
write(timeStr)
term.redirect(ct)
end

local function renderDesktop()
bCol(homeC)
cls()

tCol(colors.white)
bCol(colors.black)
pos(1, 1)
write("*homeos.v1*")

box(1, y-1, x, y, taskbarC)
box(x-9, y-1, x, y-1, colors.black)
box(1, y-1, 1, y, colors.red)
tCol(colors.black)
pos(1, y-1)
write("p")

bCol(colors.blue)
tCol(colors.white)
pos(3, y-1)
write("setings")

bCol(colors.cyan)
tCol(colors.black)
pos(11, y-1)
write("bfg")

box(1, y, x, y, colors.black)
pos(1, y)
tCol(colors.white)
bCol(colors.black)
write("###################################################")

drawTime()

for _, app in pairs(apps) do
box(app.x, app.y, app.x + app.w - 1, app.y + app.h - 1, colors.black)
bCol(app.bg)
pos(app.x + 1, app.y + 1)
tCol(colors.white)
write(app.label)
end
end

local function renderTerminal()
local winW, winH = dia.getSize()
local oldTerm = term.redirect(dia)
dia.setBackgroundColor(colors.black)
dia.clear()

dia.setCursorPos(1, 1)
dia.setBackgroundColor(isFocused and colors.blue or colors.gray)
dia.setTextColor(colors.white)
dia.write(isFocused and " [ TERMINAL - ACTIVE ]" or " [ CLICK TO INTERACT ]")

dia.setBackgroundColor(colors.black)

local maxVisibleLines = winH - 3
local totalLines = #history
local startLine = math.max(1, totalLines - maxVisibleLines + 1 - scrollOffset)
local endLine = math.min(totalLines, startLine + maxVisibleLines - 1)

local lineY = 2
for i = startLine, endLine do
dia.setCursorPos(1, lineY)
dia.setTextColor(history[i].color or colors.white)
local visibleText = string.sub(history[i].text, 1 + horizontalScroll, winW + horizontalScroll)
dia.write(visibleText)
lineY = lineY + 1
end

local pRes = import("/user_files/homesetings.text", "pointerColor=", " de")
local pointerColor = colors[pRes] or colors.yellow
dia.setCursorPos(1, winH)
dia.setTextColor(pointerColor)

local displayDir = getDisplayDir(currentDir)
local fullInputLine = displayDir .. "> " .. currentInput
local visibleInput = string.sub(fullInputLine, 1 + horizontalScroll, winW + horizontalScroll)
dia.write(visibleInput)

dia.setCursorBlink(isFocused)
if isFocused then
local prefixLen = #displayDir + 2
local cursorX = (prefixLen + #currentInput + 1) - horizontalScroll
if cursorX >= 1 and cursorX <= winW then
dia.setCursorPos(cursorX, winH)
else
dia.setCursorBlink(false)
end
end

term.redirect(oldTerm)
end

local function printToDia(text, col)
table.insert(history, { text = tostring(text), color = col or colors.white })
scrollOffset = 0
end

local function executeCommand(cmd)
if cmd == "" then return end
horizontalScroll = 0

saveHistory(cmd)

local args = {}
for match in cmd:gmatch('%b""') do
cmd = cmd:gsub('%b""', "___QSTR___", 1)
table.insert(args, match:sub(2, -2))
end
local idx = 1
for word in cmd:gmatch("%S+") do
if word == "___QSTR___" then
else
table.insert(args, idx, word)
idx = idx + 1
end
end

local mainCmd = args[1] and args[1]:lower() or ""

if aliases[mainCmd] then
mainCmd = aliases[mainCmd]
end

if mainCmd == "clear" or mainCmd == "cls" then
history = {}

elseif mainCmd == "clearhistory" or mainCmd == "clearhist" or mainCmd == "clrhist" then
cmdHistory = {}
historyIndex = 0
if fs.exists("/user_files/.cmd_history") then
fs.delete("/user_files/.cmd_history")
end
printToDia("Command history cleared.", colors.lime)

elseif mainCmd == "help" then
local subCmd = args[2] and args[2]:lower()

if not subCmd then
printToDia("=== HomeOS Terminal Help ===", colors.yellow)
printToDia("Type 'help <cmd>' for detailed info.", colors.lightGray)
printToDia("Nav: ls, cd, pwd, tree, find, grep", colors.cyan)
printToDia("Files: cat, touch, mkdir, rm/delete", colors.cyan)
printToDia("Util: cp, mv, size, df, echo, alias, export, clearhist", colors.cyan)
printToDia("Apps: edit, run/exec, music, refresh, bfg, apps", colors.cyan)
printToDia("Buttons: addbtn, rmbtn, lsbtn, editbtn, setbg", colors.cyan)
printToDia("System: time, ping, whoami, label, passwd, reboot", colors.cyan)
elseif subCmd == "clearhist" or subCmd == "clearhistory" then
printToDia("clearhist : Clear saved command history file.", colors.yellow)
elseif subCmd == "tree" then
printToDia("tree [folder] : Visual folder hierarchy tree.", colors.yellow)
elseif subCmd == "find" then
printToDia("find <name> : Search for files recursively.", colors.yellow)
elseif subCmd == "grep" then
printToDia("grep <text> <file> : Search text in file.", colors.yellow)
elseif subCmd == "size" then
printToDia("size <path> : Check size of file/folder.", colors.yellow)
elseif subCmd == "df" then
printToDia("df : Display available storage disk space.", colors.yellow)
elseif subCmd == "refresh" then
printToDia("refresh : Reload desktop configuration & icons.", colors.yellow)
elseif subCmd == "alias" then
printToDia("alias [name=cmd] : Set or view command aliases.", colors.yellow)
elseif subCmd == "export" then
printToDia("export [var=val] : Set environment variables.", colors.yellow)
elseif subCmd == "apps" then
printToDia("apps : List all .lua apps in core and user_files folders.", colors.yellow)
elseif subCmd == "passwd" then
printToDia("passwd <old> <new> : Change your account password.", colors.yellow)
else
printToDia("No detailed entry found for '" .. subCmd .. "'", colors.red)
end

elseif mainCmd == "passwd" or mainCmd == "chpasswd" then
local oldPass = args[2]
local newPass = args[3]
local accountPath = "/core/account.txt"

if not fs.exists(accountPath) then
printToDia("No account configured at /core/account.txt", colors.red)
elseif not oldPass or not newPass then
printToDia("Usage: passwd <old_password> <new_password>", colors.yellow)
else
local file = fs.open(accountPath, "r")
if file then
local username = file.readLine()
local storedHash = file.readLine()
file.close()

if hashPassword(oldPass) == storedHash then
local wFile = fs.open(accountPath, "w")
if wFile then
wFile.writeLine(username)
wFile.writeLine(hashPassword(newPass))
wFile.close()
printToDia("Password changed successfully for " .. tostring(username) .. ".", colors.lime)
else
printToDia("Failed to write to account file.", colors.red)
end
else
printToDia("Incorrect current password.", colors.red)
end
end
end

elseif mainCmd == "apps" then
printToDia("=== Installed Apps (.lua) ===", colors.yellow)
local function scanFolder(folder)
if fs.exists(folder) and fs.isDir(folder) then
local list = fs.list(folder)
for _, file in ipairs(list) do
local fullPath = fs.combine(folder, file)
if fs.isDir(fullPath) then
scanFolder(fullPath)
elseif file:match("%.lua$") then
printToDia(fullPath, colors.lime)
end
end
end
end
scanFolder("/core")
scanFolder("/user_files")
scanFolder("/net/share")
elseif mainCmd == "bfg" then
local tabID = shell.openTab("/core/bfg.lua")
multishell.setFocus(tabID)

elseif mainCmd == "refresh" then
loadCustomButtons()
loadEnvVars()
renderDesktop()
dia.redraw()
printToDia("Desktop & environment reloaded.", colors.lime)

elseif mainCmd == "pwd" then
printToDia(getDisplayDir(currentDir), colors.lime)

elseif mainCmd == "whoami" then
local lbl = envVars["USER"] or os.getComputerLabel() or ("Computer #" .. os.getComputerID())
printToDia(lbl, colors.lime)

elseif mainCmd == "find" then
local query = args[2]
if not query then
printToDia("Usage: find <pattern>", colors.yellow)
else
local matches = 0
local function searchDir(dir)
local list = fs.list(dir)
for _, item in ipairs(list) do
local fullPath = fs.combine(dir, item)
if item:lower():find(query:lower(), 1, true) then
printToDia(getDisplayDir(fullPath), fs.isDir(fullPath) and colors.yellow or colors.lime)
matches = matches + 1
end
if fs.isDir(fullPath) then searchDir(fullPath) end
end
end
searchDir(currentDir)
if matches == 0 then printToDia("No matches found.", colors.gray) end
end

elseif mainCmd == "grep" then
local query = args[2]
local file = args[3]
if not query or not file then
printToDia("Usage: grep <text> <file>", colors.yellow)
else
local targetPath = fs.combine(currentDir, file)
if not fs.exists(targetPath) or fs.isDir(targetPath) then
printToDia("File not found: " .. file, colors.red)
else
local handle = fs.open(targetPath, "r")
if handle then
local lineNum = 1
local found = false
local line = handle.readLine()
while line do
if line:lower():find(query:lower(), 1, true) then
printToDia("[" .. lineNum .. "] " .. line, colors.lime)
found = true
end
lineNum = lineNum + 1
line = handle.readLine()
end
handle.close()
if not found then printToDia("Text not found in file.", colors.gray) end
end
end
end

elseif mainCmd == "tree" then
local targetDir = args[2] and fs.combine(currentDir, args[2]) or currentDir
if not fs.exists(targetDir) or not fs.isDir(targetDir) then
printToDia("Invalid directory: " .. (args[2] or ""), colors.red)
else
printToDia(getDisplayDir(targetDir), colors.yellow)
local function drawTree(dir, prefix)
local list = fs.list(dir)
for i, item in ipairs(list) do
local fullPath = fs.combine(dir, item)
local isLast = (i == #list)
local connector = isLast and "`-- " or "|-- "
if fs.isDir(fullPath) then
printToDia(prefix .. connector .. item .. "/", colors.cyan)
drawTree(fullPath, prefix .. (isLast and "    " or "|   "))
else
printToDia(prefix .. connector .. item, colors.white)
end
end
end
drawTree(targetDir, "")
end

elseif mainCmd == "size" then
local target = args[2] or ""
local targetPath = fs.combine(currentDir, target)
if not fs.exists(targetPath) then
printToDia("Path not found: " .. target, colors.red)
else
local function calculateSize(p)
if not fs.isDir(p) then return fs.getSize(p) end
local sz = 0
for _, f in ipairs(fs.list(p)) do
sz = sz + calculateSize(fs.combine(p, f))
end
return sz
end
local totalBytes = calculateSize(targetPath)
if totalBytes >= 1024 then
printToDia(string.format("%.2f KB (%d bytes)", totalBytes / 1024, totalBytes), colors.lime)
else
printToDia(totalBytes .. " bytes", colors.lime)
end
end

elseif mainCmd == "df" then
local freeBytes = fs.getFreeSpace(currentDir)
if freeBytes >= 1024 * 1024 then
printToDia(string.format("Free Space: %.2f MB", freeBytes / (1024 * 1024)), colors.lime)
elseif freeBytes >= 1024 then
printToDia(string.format("Free Space: %.2f KB", freeBytes / 1024), colors.lime)
else
printToDia("Free Space: " .. freeBytes .. " bytes", colors.lime)
end

elseif mainCmd == "alias" then
local expr = args[2]
if not expr then
printToDia("--- Current Aliases ---", colors.yellow)
for k, v in pairs(aliases) do
printToDia(k .. " => " .. v, colors.lime)
end
else
local k, v = expr:match("^([%w_]+)=(.*)$")
if k and v then
aliases[k] = v
printToDia("Alias set: " .. k .. " -> " .. v, colors.lime)
else
printToDia("Usage: alias <name>=<command>", colors.yellow)
end
end

elseif mainCmd == "export" then
local expr = args[2]
if not expr then
printToDia("--- Environment Variables ---", colors.yellow)
for k, v in pairs(envVars) do
printToDia(k .. " = " .. v, colors.lime)
end
else
local k, v = expr:match("^([%w_]+)=(.*)$")
if k and v then
envVars[k] = v
saveEnvVars()
printToDia("Exported: " .. k .. " = " .. v, colors.lime)
else
printToDia("Usage: export <VAR>=<VAL>", colors.yellow)
end
end

elseif mainCmd == "echo" then
local text = cmd:sub(#args[1] + 2)
for k, v in pairs(envVars) do
text = text:gsub("%$" .. k, v)
end
printToDia(text, colors.white)

elseif mainCmd == "touch" then
local file = args[2]
if not file then
printToDia("Usage: touch <file>", colors.yellow)
else
local targetPath = fs.combine(currentDir, file)
if fs.exists(targetPath) then
printToDia("File already exists.", colors.yellow)
else
local h = fs.open(targetPath, "w")
if h then h.close() end
printToDia("Created empty file: " .. file, colors.lime)
end
end

elseif mainCmd == "mkdir" then
local dirName = args[2]
if not dirName then
printToDia("Usage: mkdir <folder>", colors.yellow)
else
local targetPath = fs.combine(currentDir, dirName)
if fs.exists(targetPath) then
printToDia("Directory already exists.", colors.yellow)
else
fs.makeDir(targetPath)
printToDia("Created directory: " .. dirName, colors.lime)
end
end

elseif mainCmd == "rm" or mainCmd == "delete" then
local path = args[2]
if not path then
printToDia("Usage: " .. mainCmd .. " <file/dir>", colors.yellow)
else
local targetPath = fs.combine(currentDir, path)
if not fs.exists(targetPath) then
printToDia("Path does not exist: " .. path, colors.red)
else
fs.delete(targetPath)
printToDia("Deleted: " .. path, colors.lime)
end
end

elseif mainCmd == "cp" then
local src = args[2]
local dest = args[3]
if not src or not dest then
printToDia("Usage: cp <source> <destination>", colors.yellow)
else
local srcPath = fs.combine(currentDir, src)
local destPath = fs.combine(currentDir, dest)
if not fs.exists(srcPath) then
printToDia("Source file not found: " .. src, colors.red)
elseif fs.exists(destPath) then
printToDia("Destination already exists: " .. dest, colors.yellow)
else
fs.copy(srcPath, destPath)
printToDia("Copied " .. src .. " -> " .. dest, colors.lime)
end
end

elseif mainCmd == "mv" then
local src = args[2]
local dest = args[3]
if not src or not dest then
printToDia("Usage: mv <source> <destination>", colors.yellow)
else
local srcPath = fs.combine(currentDir, src)
local destPath = fs.combine(currentDir, dest)

if not fs.exists(srcPath) then
printToDia("Source not found: " .. src, colors.red)
else
if fs.exists(destPath) and fs.isDir(destPath) then
local fileName = fs.getName(srcPath)
destPath = fs.combine(destPath, fileName)
end

if fs.exists(destPath) then
printToDia("Destination already exists: " .. dest, colors.yellow)
else
fs.move(srcPath, destPath)
printToDia("Moved " .. src .. " -> " .. getDisplayDir(destPath), colors.lime)
end
end
end

elseif mainCmd == "edit" then
local filePath = args[2]
if not filePath then
printToDia("Usage: edit <file>", colors.yellow)
else
local fullPath = fs.combine(currentDir, filePath)
local tabID = shell.openTab("/core/super.lua", fullPath)
multishell.setFocus(tabID)
end

elseif mainCmd == "run" or mainCmd == "exec" then
local scriptPath = args[2]
if not scriptPath then
printToDia("Usage: " .. mainCmd .. " <script>", colors.yellow)
else
local fullPath = fs.combine(currentDir, scriptPath)
if not fs.exists(fullPath) then
printToDia("Script not found: " .. scriptPath, colors.red)
else
local runArgs = {}
for i = 3, #args do table.insert(runArgs, args[i]) end
local tabID = shell.openTab(fullPath, table.unpack(runArgs))
multishell.setFocus(tabID)
end
end

elseif mainCmd == "lsbtn" or mainCmd == "btns" then
printToDia("--- Desktop Buttons ---", colors.yellow)
for id, app in pairs(apps) do
local cleanLabel = app.label:match("^%s*(.-)%s*$")
printToDia("ID: " .. id .. " | Label: " .. cleanLabel, colors.lime)
printToDia("  Path: " .. app.path, colors.gray)
end

elseif mainCmd == "addbtn" then
local id = args[2]
local label = args[3]
local path = args[4]
local clrName = args[5] or "gray"

if not id or not label or not path then
printToDia("Usage: addbtn <id> <label> <path> [color]", colors.yellow)
else
local bgClr = colors[clrName:lower()] or colors.gray
local formattedLabel = string.sub(label .. string.rep(" ", 11), 1, 11)

local nextY = 2
for _, app in pairs(apps) do
if app.y >= nextY then nextY = app.y + 4 end
end

apps[id] = {
x = 2,
y = math.min(nextY, y - 4),
w = 13,
h = 3,
label = formattedLabel,
bg = bgClr,
path = path
}

saveCustomButton(id, formattedLabel, bgClr, path, apps[id].x, apps[id].y)
renderDesktop()
dia.redraw()
printToDia("Added button: " .. id, colors.lime)
end

elseif mainCmd == "rmbtn" then
local id = args[2]

if not id then
printToDia("Usage: rmbtn <id>", colors.yellow)
elseif id == "super" or id == "printApp" or id == "musicApp" then
printToDia("Cannot remove core system app: " .. id, colors.red)
elseif not apps[id] then
printToDia("Button ID not found: " .. id, colors.yellow)
else
apps[id] = nil
removeCustomButton(id)
renderDesktop()
dia.redraw()
printToDia("Removed button: " .. id, colors.lime)
end

elseif mainCmd == "editbtn" then
local id = args[2]
local prop = args[3]
local val = args[4]
if not id or not prop or not val then
printToDia("Usage: editbtn <id> <label/color> <value>", colors.yellow)
elseif not apps[id] then
printToDia("Button ID not found: " .. id, colors.red)
else
if prop == "label" then
apps[id].label = string.sub(val .. string.rep(" ", 11), 1, 11)
elseif prop == "color" then
if colors[val:lower()] then
apps[id].bg = colors[val:lower()]
else
printToDia("Invalid color.", colors.red)
return
end
else
printToDia("Property must be 'label' or 'color'.", colors.red)
return
end

if id:sub(1,4) == "btn_" then
saveCustomButton(id:sub(5), apps[id].label, apps[id].bg, apps[id].path, apps[id].x, apps[id].y)
end

renderDesktop()
dia.redraw()
printToDia("Button '" .. id .. "' updated.", colors.lime)
end

elseif mainCmd == "setbg" then
local val = args[2]
if not val or not colors[val:lower()] then
printToDia("Usage: setbg <color>", colors.yellow)
else
homeC = colors[val:lower()]
local configPath = "/user_files/homesetings.text"
local handle = fs.open(configPath, "r")
local content = handle and handle.readAll() or ""
if handle then handle.close() end

local pattern = "homeColor=.- d"
local newValue = "homeColor=" .. tostring(homeC) .. " d"
if content:find(pattern) then
content = content:gsub(pattern, newValue)
else
content = content .. "\n" .. newValue
end
handle = fs.open(configPath, "w")
if handle then
handle.write(content)
handle.close()
end
renderDesktop()
dia.redraw()
printToDia("Background color updated.", colors.lime)
end

elseif mainCmd == "cat" then
local filePath = args[2]

if not filePath or filePath == "" then
printToDia("Usage: cat <file>", colors.yellow)
else
local fullPath = fs.combine(currentDir, filePath)

if not fs.exists(fullPath) then
printToDia("File not found: " .. filePath, colors.red)
elseif fs.isDir(fullPath) then
printToDia("Cannot cat a directory.", colors.yellow)
else
local handle = fs.open(fullPath, "r")
if handle then
local line = handle.readLine()
if not line then
printToDia("[File is empty]", colors.gray)
else
while line do
printToDia(line, colors.white)
line = handle.readLine()
end
end
handle.close()
end
end
end

elseif mainCmd == "cd" then
local target = args[2]

if not target or target == "" then
currentDir = "/core"
printToDia("Directory: " .. getDisplayDir(currentDir), colors.lime)

elseif target == ".." then
if currentDir ~= "/core" and currentDir ~= "" then
currentDir = fs.getDir(currentDir)
if currentDir == "" or currentDir == "/" then currentDir = "/core" end
printToDia("Directory: " .. getDisplayDir(currentDir), colors.lime)
else
printToDia("Already at root directory.", colors.yellow)
end

else
local newPath = fs.combine(currentDir, target)

if not fs.exists(newPath) then
printToDia("Directory does not exist: " .. target, colors.red)
elseif not fs.isDir(newPath) then
printToDia("Not a directory: " .. target, colors.yellow)
else
currentDir = newPath
printToDia("Directory: " .. getDisplayDir(currentDir), colors.lime)
end
end

elseif mainCmd == "ls" then
local targetDir = args[2] and fs.combine(currentDir, args[2]) or currentDir

if not fs.exists(targetDir) then
printToDia("Directory does not exist: " .. targetDir, colors.red)
elseif not fs.isDir(targetDir) then
printToDia("Not a directory: " .. targetDir, colors.yellow)
else
local files = fs.list(targetDir)
if #files == 0 then
printToDia("Directory is empty.", colors.gray)
else
for _, name in ipairs(files) do
local fullPath = fs.combine(targetDir, name)
if fs.isDir(fullPath) then
printToDia(name .. "/", colors.yellow)
else
printToDia(name, colors.white)
end
end
end
end

elseif mainCmd == "label" then
local name = args[2]
if name == nil then
printToDia("Usage: label <name>", colors.yellow)
else
os.setComputerLabel(name)
printToDia(name .. " applied", colors.white)
end

elseif mainCmd == "music" then
local tabID = shell.openTab("/core/play.lua")
multishell.setFocus(tabID)
elseif mainCmd == "reboot" then
os.reboot()
elseif mainCmd == "stop" then
error("stoped")
elseif mainCmd == "ping" then
printToDia("pong!", colors.lime)
elseif mainCmd == "time" then
printToDia("Time: " .. textutils.formatTime(os.time("local")), colors.lime)
else
printToDia("Unknown command: " .. cmd, colors.red)
end
end

local function focusAndReadDialog()
isFocused = true
renderTerminal()

while isFocused do
local event, p1, p2, p3 = os.pullEvent()

if event == "char" then
currentInput = currentInput .. p1
renderTerminal()

elseif event == "key" then
if p1 == keys.enter then
local cmd = currentInput
currentInput = ""
executeCommand(cmd)
renderTerminal()
elseif p1 == keys.backspace then
currentInput = string.sub(currentInput, 1, #currentInput - 1)
renderTerminal()
elseif p1 == keys.tab then
local lastWord = currentInput:match("%S+$") or ""
local matches = fs.complete(lastWord, currentDir)
if #matches > 0 then
currentInput = currentInput .. matches[1]
renderTerminal()
end
elseif p1 == keys.left then
if horizontalScroll > 0 then
horizontalScroll = horizontalScroll - 1
renderTerminal()
end
elseif p1 == keys.right then
horizontalScroll = horizontalScroll + 1
renderTerminal()
elseif p1 == keys.up then
if #cmdHistory > 0 and historyIndex > 1 then
historyIndex = historyIndex - 1
currentInput = cmdHistory[historyIndex]
renderTerminal()
end
elseif p1 == keys.down then
if #cmdHistory > 0 and historyIndex < #cmdHistory then
historyIndex = historyIndex + 1
currentInput = cmdHistory[historyIndex]
renderTerminal()
elseif historyIndex == #cmdHistory then
historyIndex = #cmdHistory + 1
currentInput = ""
renderTerminal()
end
end

elseif event == "mouse_scroll" then
local winW, winH = dia.getSize()
if p1 == -1 and (#history - scrollOffset > winH - 3) then
scrollOffset = scrollOffset + 1
elseif p1 == 1 and scrollOffset > 0 then
scrollOffset = scrollOffset - 1
end
renderTerminal()

elseif event == "mouse_click" or event == "mouse_drag" then
local mx, my = p2, p3
local winX, winY = dia.getPosition()
local winW, winH = dia.getSize()

if mx < winX or mx >= winX + winW or my < winY or my >= winY + winH then
isFocused = false
renderTerminal()
return event, p1, p2, p3
end
end
end
end

local function drawMenuAndGetAction(cx, cy, options)
local w = 12
for _, opt in ipairs(options) do
w = math.max(w, #opt.text + 2)
end
local h = #options
if cx + w > (x / 2) then cx = (x / 2) - w end
if cy + h > y - 2 then cy = y - h - 2 end

for i, opt in ipairs(options) do
pos(cx, cy + i - 1)
bCol(colors.lightGray)
tCol(colors.black)
write(string.rep(" ", w))
pos(cx + 1, cy + i - 1)
write(opt.text)
end

while true do
local e, p1, p2, p3 = os.pullEvent()
if e == "mouse_click" then
if p2 >= cx and p2 < cx + w and p3 >= cy and p3 < cy + h then
return options[p3 - cy + 1].action
else
return nil
end
end
end
end

renderDesktop()
printToDia("Terminal Initialized.", colors.lightGray)
printToDia("Type 'help' for commands.", colors.lightGray)
renderTerminal()

local timerID = os.startTimer(0.5)

while true do
local event, p1, p2, p3 = os.pullEvent()

if event == "timer" then
drawTime()
os.cancelTimer(timerID)
timerID = os.startTimer(0.5)

elseif event == "mouse_click" and p1 == 2 then
local mx, my = p2, p3
local winX, winY = dia.getPosition()
local winW, winH = dia.getSize()

if mx >= winX and mx < winX + winW and my >= winY and my < winY + winH then
else
local clickedAppId, clickedApp = nil, nil
for id, app in pairs(apps) do
if mx >= app.x and mx < app.x + app.w and my >= app.y and my < app.y + app.h then
clickedAppId = id
clickedApp = app
break
end
end

if clickedApp then
local action = drawMenuAndGetAction(mx, my, {
{text = "Change Label", action = "label"},
{text = "Change Color", action = "color"},
{text = "Delete", action = "delete"}
})

if action == "delete" then
executeCommand("rmbtn " .. clickedAppId)
elseif action == "label" then
printToDia("Enter new label for " .. clickedAppId .. ":", colors.yellow)
printToDia("(Format: editbtn " .. clickedAppId .. " label <name>)", colors.gray)
currentInput = "editbtn " .. clickedAppId .. " label "
isFocused = true
renderTerminal()
elseif action == "color" then
printToDia("Enter new color for " .. clickedAppId .. ":", colors.yellow)
printToDia("(Format: editbtn " .. clickedAppId .. " color <color>)", colors.gray)
currentInput = "editbtn " .. clickedAppId .. " color "
isFocused = true
renderTerminal()
end
renderDesktop()
dia.redraw()
else
local action = drawMenuAndGetAction(mx, my, {
{text = "BG Color", action = "bgcolor"},
{text = "New Button", action = "newbtn"}
})
if action == "newbtn" then
printToDia("Add a new button using this format:", colors.yellow)
printToDia("addbtn <id> <label> <path> [color]", colors.gray)
currentInput = "addbtn "
isFocused = true
renderTerminal()
elseif action == "bgcolor" then
printToDia("Enter new background color name:", colors.yellow)
printToDia("(Format: setbg <color>)", colors.gray)
currentInput = "setbg "
isFocused = true
renderTerminal()
end
renderDesktop()
dia.redraw()
end
end

elseif event == "mouse_click" and p1 == 1 then
local mx, my = p2, p3
local winX, winY = dia.getPosition()
local winW, winH = dia.getSize()

isMoved = false

if mx >= winX and mx < winX + winW and my >= winY and my < winY + winH then
local passEv, passP1, passP2, passP3 = focusAndReadDialog()
if passEv then event, p1, p2, p3 = passEv, passP1, passP2, passP3 end

else
for _, app in pairs(apps) do
if mx >= app.x and mx < app.x + app.w and my >= app.y and my < app.y + app.h then
draggingTarget = app
dragOffsetX = mx - app.x
dragOffsetY = my - app.y
end
end

if mx == 1 and my == y-1 then
error("exit code 0", 0)

elseif mx >= 3 and mx <= 9 and my == y-1 then
local tabID = shell.openTab("/core/super.lua", "/user_files/homesetings.text")
multishell.setFocus(tabID)

elseif mx >= 11 and mx <= 13 and my == y-1 then
local tabID = shell.openTab("/core/bfg.lua")
multishell.setFocus(tabID)
end
end

elseif event == "mouse_drag" and p1 == 1 then
local mx, my = p2, p3
isMoved = true

if type(draggingTarget) == "table" then
draggingTarget.x = math.max(1, math.min(x/2 - draggingTarget.w, mx - dragOffsetX))
draggingTarget.y = math.max(1, math.min(y - 3, my - dragOffsetY))
renderDesktop()
dia.redraw()
end

elseif event == "mouse_up" then
if type(draggingTarget) == "table" then
if isMoved then
for name, app in pairs(apps) do
if app == draggingTarget then
if name:sub(1, 4) == "btn_" then
saveCustomButton(name:sub(5), app.label, app.bg, app.path, app.x, app.y)
else
saveAppPosition(name, app.x, app.y)
end
end
end
else
local tabID = shell.openTab(draggingTarget.path)
multishell.setFocus(tabID)
end
end
draggingTarget = nil
isMoved = false
end
end
end

ensureSettingsFile()
loding()

multishell.setTitle(multishell.getCurrent(), "home")
isonline()

if online then
local result = import("/user_files/homesetings.text", "comModem=", " d")
openport = tonumber(result) or 1
modem.open(openport)
end

hasspeakers = peripheral.find("speaker") ~= nil
hasp = peripheral.find("printer") ~= nil
haswether = peripheral.find("weather_machine") ~= nil

startscreen()
homescreen()
