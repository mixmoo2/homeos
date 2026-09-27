local driveName = nil
local modemName = nil

for _, name in ipairs(peripheral.getNames()) do
    if peripheral.getType(name) == "drive" and disk.hasData(name) then
        driveName = name
    elseif peripheral.getType(name) == "modem" then
        modemName = name
    end
end

if not driveName then error("No disk found in attached drive.") end
if not modemName then error("A modem is required to bypass floppy size limits.") end

local mountPath = disk.getMountPath(driveName)
local diskStartup = fs.combine(mountPath, "startup.lua")

term.clear()
term.setCursorPos(1, 1)
print("Formatting disk...")
term.setTextColor(colors.yellow)
print("The imgecopycofig is a list of files you dont want tranferd.")
print("The target computer needs to be empty.")
term.setTextColor(colors.white)
for _, file in ipairs(fs.list(mountPath)) do
    fs.delete(fs.combine(mountPath, file))
end

print("Writing network bootloader to floppy...")
local file = fs.open(diskStartup, "w")
file.write([[
local runningPath = shell.getRunningProgram()
local diskDir = fs.getDir(runningPath)
local tempPath = fs.combine(diskDir, "temp.lua")

if fs.exists(tempPath) then fs.delete(tempPath) end
fs.move(runningPath, tempPath)

local modemName = nil
for _, name in ipairs(peripheral.getNames()) do
    if peripheral.getType(name) == "modem" then
        modemName = name
        break
    end
end
if not modemName then error("Modem required to install.") end
rednet.open(modemName)

print("Wiping target drive...")
for _, item in ipairs(fs.list("/")) do
    if item ~= "disk" and item ~= "rom" and item ~= "temp.lua" then
        pcall(fs.delete, item)
    end
end

print("Target free space: " .. tostring(fs.getFreeSpace("/")) .. " bytes")
print("Connecting to host...")

local hostID = nil
local fileList = nil

while not fileList do
    rednet.broadcast("REQUEST_FILE_LIST", "HOMEOS_INSTALL")
    local id, msg = rednet.receive("HOMEOS_INSTALL", 3)
    if type(msg) == "table" then
        hostID = id
        fileList = msg
    else
        print("Retrying connection...")
    end
end

print("Receiving files...")
for _, item in ipairs(fileList) do
    local path = type(item) == "table" and item.path or item
    local isDir = type(item) == "table" and item.isDir or false

    if isDir then
        local dest = fs.combine("/", path)
        if not fs.exists(dest) then
            pcall(fs.makeDir, dest)
        end
        print("Created dir: " .. path)
    else
        rednet.send(hostID, { cmd = "GET_FILE", file = path }, "HOMEOS_INSTALL")
        local _, content = rednet.receive("HOMEOS_INSTALL", 5)
        if type(content) == "string" then
            local freeSpace = fs.getFreeSpace("/")
            if freeSpace < #content then
                print("Skipped (No space: " .. #content .. "b > " .. freeSpace .. "b): " .. path)
            else
                local dest = fs.combine("/", path)
                local dir = fs.getDir(dest)
                local okDir = true
                if dir ~= "" and dir ~= "." and not fs.exists(dir) then
                    local ok, err = pcall(fs.makeDir, dir)
                    if not ok or not fs.isDir(dir) then okDir = false end
                end
                if okDir then
                    local okWrite = pcall(function()
                        local f = fs.open(dest, "w")
                        if f then
                            f.write(content)
                            f.close()
                        else
                            error("open failed")
                        end
                    end)
                    if okWrite then
                        print("Installed: " .. path)
                    else
                        print("Skipped (Write failed): " .. path)
                    end
                else
                    print("Skipped (Dir failed): " .. path)
                end
            end
        end
    end
end

if fs.exists(tempPath) then
    fs.delete(tempPath)
end

print("Install complete. Remove disk and reboot.")
]])
file.close()

local configFile = "user_files/imigecopyconfig.text"
local excludedPaths = {}
local emptyPaths = {}

if not fs.exists("user_files") then
    fs.makeDir("user_files")
end

if not fs.exists(configFile) then
    local f = fs.open(configFile, "w")
    if f then
        f.writeLine("user_files")
        f.writeLine("*rom")
        f.writeLine("net/site_data")
        f.writeLine("net/cookies")
        f.writeLine("net/config.txt")
        f.writeLine("net/history.txt")
        f.writeLine("net/bookmakrks.txt")
        f.writeLine("net/share")
        f.writeLine("songs")
        f.writeLine("meta")
        f.writeLine("imagecopy.lua")
        f.writeLine("imigecopyconfig.text")
        f.writeLine("account.txt")
        f.writeLine("core/.cmd_history.text")
        f.close()
    end
end

local function cleanPath(p)
    if not p then return "" end
    return p:gsub("\\", "/"):gsub("^/+", ""):gsub("/+$", "")
end

if fs.exists(configFile) then
    local f = fs.open(configFile, "r")
    if f then
        local line = f.readLine()
        while line do
            line = line:match("^%s*(.-)%s*$")
            if line ~= "" and not line:match("^#") then
                if line:sub(1, 1) == "*" then
                    local p = cleanPath(line:sub(2))
                    if p ~= "" then excludedPaths[p] = true end
                else
                    local p = cleanPath(line)
                    if p ~= "" then emptyPaths[p] = true end
                end
            end
            line = f.readLine()
        end
        f.close()
    end
end

print("Disk prepared. Insert into target computer.")
print("Starting host server. Do not close this terminal, until transfer complete")
print("Disk is only good for 1 transfer.")

rednet.open(modemName)

local function matchesConfig(path, targetMap)
    local clean = cleanPath(path)
    local name = fs.getName(clean)

    if targetMap[clean] or targetMap[name] then
        return true
    end

    for pattern, _ in pairs(targetMap) do
        if clean == pattern
           or name == pattern
           or clean:sub(1, #pattern + 1) == pattern .. "/"
        then
            return true
        end
    end
    return false
end

local function isExcluded(path)
    return matchesConfig(path, excludedPaths)
end

local function isEmptyFolder(path)
    return matchesConfig(path, emptyPaths)
end

local function getFileList(dir, list)
    for _, file in ipairs(fs.list(dir)) do
        local path = fs.combine(dir, file)
        local clean = cleanPath(path)
        local fileName = fs.getName(clean)

        local isDisk = (clean == "disk" or clean:sub(1, 5) == "disk/")
        local isDotFile = (fileName:sub(1, 1) == ".")

        if not isExcluded(clean) and not isDisk and not isDotFile then
            if fs.isDir(clean) then
                if isEmptyFolder(clean) then
                    table.insert(list, { path = clean, isDir = true })
                else
                    getFileList(clean, list)
                end
            else
                if not isEmptyFolder(clean) then
                    local isNetShare = (clean:sub(1, 9) == "net/share")
                    local isLua = (clean:sub(-4) == ".lua")

                    if not (isNetShare and not isLua) then
                        table.insert(list, { path = clean, isDir = false })
                    end
                end
            end
        end
    end
end

local osFileList = {}
getFileList("", osFileList)

print("Filtered OS package size: " .. #osFileList .. " items queued.")
print("Waiting for installation requests...")

while true do
    local id, msg, protocol = rednet.receive("HOMEOS_INSTALL")
    if msg == "REQUEST_FILE_LIST" then
        print("Sending file list to computer ID: " .. tostring(id))
        rednet.send(id, osFileList, "HOMEOS_INSTALL")
    elseif type(msg) == "table" and msg.cmd == "GET_FILE" then
        local reqPath = cleanPath(msg.file)
        if isExcluded(reqPath) or isEmptyFolder(reqPath) then
            rednet.send(id, "", "HOMEOS_INSTALL")
        elseif fs.exists(reqPath) and not fs.isDir(reqPath) then
            local f = fs.open(reqPath, "r")
            if f then
                local content = f.readAll()
                f.close()
                rednet.send(id, content, "HOMEOS_INSTALL")
            end
        end
    end
end
