-- /startup.lua
local accountPath = "user_files/account.txt"
local homePath = "core/home.lua"

if not fs.exists("core") then
    fs.makeDir("core")
end

if not fs.exists("user_files") then
    fs.makeDir("user_files")
end

-- Bitwise DJB2 hash algorithm to avoid storing plain text
local function hashPassword(str)
    local hash = 5381
    for i = 1, #str do
        hash = bit32.band(bit32.lshift(hash, 5) + hash + string.byte(str, i), 0xFFFFFFFF)
    end
    return string.format("%08x", hash)
end

local function clearScreen()
    term.clear()
    term.setCursorPos(1, 1)
end

local function drawHeader(title)
    clearScreen()
    print("=== HomeOS - " .. title .. " ===")
    print("")
end

local currentUser = "Guest"

if not fs.exists(accountPath) then
    drawHeader("Setup")
    print("No account detected.")
    print("1. Create Account")
    print("2. Bypass as Guest")
    print("")
    write("Choice [1/2]: ")
    local choice = read()

    if choice == "1" then
        drawHeader("Create Account")
        write("Username: ")
        local username = read()
        while username == "" do
            write("Username cannot be empty: ")
            username = read()
        end

        write("Password: ")
        local password = read("*")
        while password == "" do
            write("Password cannot be empty: ")
            password = read("*")
        end

        local file = fs.open(accountPath, "w")
        if file then
            file.writeLine(username)
            file.writeLine(hashPassword(password))
            file.close()
        end

        currentUser = username
        drawHeader("Welcome")
        print("Account created successfully!")
        print("Welcome, " .. currentUser .. "!")
        sleep(1.5)
    else
        currentUser = "Guest"
        drawHeader("Guest Session")
        print("Logging in as Guest...")
        sleep(1)
    end
else
    local file = fs.open(accountPath, "r")
    local storedUser = file.readLine()
    local storedHash = file.readLine()
    file.close()

    local authenticated = false
    while not authenticated do
        drawHeader("Login")
        print("Account: " .. tostring(storedUser))
        write("Password: ")
        local inputPassword = read("*")

        if hashPassword(inputPassword) == storedHash then
            authenticated = true
            currentUser = storedUser
            drawHeader("Welcome")
            print("Welcome back, " .. currentUser .. "!")
            sleep(1.5)
        else
            print("")
            print("Incorrect password. Press key to retry.")
            os.pullEvent("key")
        end
    end
end

clearScreen()
if fs.exists(homePath) then
    shell.run(homePath, currentUser)
else
    print("HomeOS booted. Active user: " .. currentUser)
end
