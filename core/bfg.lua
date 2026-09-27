-- BFG (Big File Guy) - File Manager for HomeOS
if multishell and multishell.setTitle then
multishell.setTitle(multishell.getCurrent(), "bfg")
end

local currentDir = "/"
local selectedFile = nil
local scrollOffset = 0

local function getDisplayDir(dir)
return dir
end

local function drawUI()
term.setBackgroundColor(colors.gray)
term.clear()

local w, h = term.getSize()

paintutils.drawFilledBox(1, 1, w, 1, colors.blue)
term.setCursorPos(2, 1)
term.setTextColor(colors.white)
term.write("BFG File Manager - " .. getDisplayDir(currentDir))

paintutils.drawFilledBox(w - 7, 1, w - 1, 1, colors.lightGray)
term.setCursorPos(w - 6, 1)
term.setTextColor(colors.black)
term.write("[UP..]")

paintutils.drawFilledBox(2, 3, w - 3, h - 3, colors.black)

paintutils.drawFilledBox(w - 2, 3, w - 1, h - 3, colors.gray)

term.setCursorPos(w - 2, 3)
term.setBackgroundColor(colors.lightGray)
term.setTextColor(colors.black)
term.write("[^]")

term.setCursorPos(w - 2, h - 3)
term.setBackgroundColor(colors.lightGray)
term.setTextColor(colors.black)
term.write("[v]")

local items = fs.list(currentDir)
local maxVisible = (h - 3) - 4 + 1

if scrollOffset > #items - maxVisible then
scrollOffset = math.max(0, #items - maxVisible)
end
if scrollOffset < 0 then scrollOffset = 0 end

if #items == 0 then
term.setCursorPos(4, 4)
term.setBackgroundColor(colors.black)
term.setTextColor(colors.gray)
term.write("(Directory is empty)")
end

local yPos = 4
for i = 1 + scrollOffset, math.min(#items, scrollOffset + maxVisible) do
local name = items[i]
local fullPath = fs.combine(currentDir, name)
local isFolder = fs.isDir(fullPath)

term.setCursorPos(4, yPos)
if selectedFile == name then
term.setBackgroundColor(colors.lightBlue)
term.setTextColor(colors.black)
else
term.setBackgroundColor(colors.black)
term.setTextColor(isFolder and colors.yellow or colors.white)
end

local prefix = isFolder and "[D] " or "    "
local label = prefix .. name
term.write(label .. string.rep(" ", math.max(0, w - 9 - #label)))
yPos = yPos + 1
end

paintutils.drawFilledBox(1, h - 1, w, h, colors.gray)

paintutils.drawFilledBox(2, h - 1, 8, h - 1, colors.green)
term.setCursorPos(3, h - 1)
term.setTextColor(colors.black)
term.write("[NEW]")

paintutils.drawFilledBox(10, h - 1, 17, h - 1, colors.cyan)
term.setCursorPos(11, h - 1)
term.setTextColor(colors.black)
term.write("[EDIT]")

paintutils.drawFilledBox(19, h - 1, 25, h - 1, colors.lime)
term.setCursorPos(20, h - 1)
term.setTextColor(colors.black)
term.write("[RUN]")

paintutils.drawFilledBox(27, h - 1, 36, h - 1, colors.red)
term.setCursorPos(28, h - 1)
term.setTextColor(colors.white)
term.write("[DELETE]")

paintutils.drawFilledBox(38, h - 1, 48, h - 1, colors.yellow)
term.setCursorPos(39, h - 1)
term.setTextColor(colors.black)
term.write("[REFRESH]")
end

local function promptInput(promptText)
local w, h = term.getSize()
term.setCursorPos(1, h)
term.setBackgroundColor(colors.blue)
term.setTextColor(colors.white)
term.clearLine()
term.write(" " .. promptText .. ": ")
term.setCursorBlink(true)
local input = read()
term.setCursorBlink(false)
return input
end

local function createFile(fileName)
if fileName and fileName ~= "" then
local fullPath = fs.combine(currentDir, fileName)
local file = fs.open(fullPath, "w")
if file then
file.writeLine("")
file.close()
selectedFile = fileName
end
end
end

drawUI()

while true do
local event, p1, p2, p3 = os.pullEvent()
local w, h = term.getSize()
local items = fs.list(currentDir)
local maxVisible = (h - 3) - 4 + 1

if event == "mouse_scroll" then
local direction = p1
if direction == -1 and scrollOffset > 0 then
scrollOffset = scrollOffset - 1
drawUI()
elseif direction == 1 and scrollOffset < #items - maxVisible then
scrollOffset = scrollOffset + 1
drawUI()
end

elseif event == "mouse_click" and p1 == 1 then
local x, y = p2, p3

if x >= w - 2 and x <= w - 1 and y == 3 then
if scrollOffset > 0 then
scrollOffset = scrollOffset - 1
end

elseif x >= w - 2 and x <= w - 1 and y == h - 3 then
if scrollOffset < #items - maxVisible then
scrollOffset = scrollOffset + 1
end

elseif y == 1 and x >= w - 7 and x <= w - 1 then
if currentDir ~= "/" then
currentDir = fs.getDir(currentDir)
selectedFile = nil
scrollOffset = 0
end

elseif y == h - 1 then
if x >= 2 and x <= 8 then
local input = promptInput("Enter Name (no type for Folder)")
if input:sub(1, 2) == "d " then
local folderName = input:sub(3)
if folderName ~= "" then fs.makeDir(fs.combine(currentDir, folderName)) end
elseif input == "d" or input == "folder" or input == "dir" then
local folderName = promptInput("Enter New Folder Name")
if folderName ~= "" then fs.makeDir(fs.combine(currentDir, folderName)) end
elseif input:sub(1, 2) == "f " then
createFile(input:sub(3))
elseif input == "f" or input == "file" then
local fileName = promptInput("Enter New File Name")
createFile(fileName)
else
createFile(input)
end

elseif x >= 10 and x <= 17 and selectedFile then
local fullPath = fs.combine(currentDir, selectedFile)
if not fs.isDir(fullPath) then
local editorPath = fs.exists("/core/super.lua") and "/core/super.lua" or "/super.lua"
if shell and shell.openTab then
local tabID = shell.openTab(editorPath, fullPath)
if tabID and multishell and multishell.setFocus then
multishell.setFocus(tabID)
end
else
shell.run(editorPath, fullPath)
end
end

elseif x >= 19 and x <= 25 and selectedFile then
local fullPath = fs.combine(currentDir, selectedFile)
if not fs.isDir(fullPath) then
if shell and shell.openTab then
local tabID = shell.openTab(fullPath)
if tabID and multishell and multishell.setFocus then
multishell.setFocus(tabID)
end
else
shell.run(fullPath)
end
end

elseif x >= 27 and x <= 36 and selectedFile then
local fullPath = fs.combine(currentDir, selectedFile)
fs.delete(fullPath)
selectedFile = nil

elseif x >= 38 and x <= 48 then
selectedFile = nil
scrollOffset = 0
end

elseif y >= 4 and y <= h - 4 and x < w - 2 then
local index = (y - 3) + scrollOffset
if items[index] then
local clickedItem = items[index]
local fullPath = fs.combine(currentDir, clickedItem)

if selectedFile == clickedItem and fs.isDir(fullPath) then
currentDir = fullPath
selectedFile = nil
scrollOffset = 0
else
selectedFile = clickedItem
end
end
end

drawUI()
end
end
