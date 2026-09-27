--this is a game made by gemai cus i wanted 
--to see what is can do... not much lol.
-- KIMITH'S SECRET LIFE
-- A Text Adventure for ComputerCraft

local termW, termH = term.getSize()

-- Game State Variables
local day = 1
local hour = 8 -- Starts at 8 AM
local location = "Living Room"
local lastMessage = "Welcome back to another day, Kimith. Get the house in order."

-- Stats (0 to 100)
local energy = 100
local houseClean = 80
local maryAffection = 0
local husbandSuspicion = 0
local husbandHome = false

-- Dynamic Progression & Inventory
local activeQuestIndex = 1
local questCompleted = false
local inventory = { "Coffee", "House Keys" }

-- 30 Sequential Story & Life Quests
local questList = {
    -- Tier 1: Domestic Routine (1-10)
    { id = 1, title = "Morning Routine", desc = "Clean the messy Living Room." },
    { id = 2, title = "Breakfast Duty", desc = "Brew a hot fresh pot of coffee in the Kitchen." },
    { id = 3, title = "Laundry Run", desc = "Do the laundry to keep the house tidy." },
    { id = 4, title = "Greg's Request", desc = "Clean the Kitchen counters before noon." },
    { id = 5, title = "Garden Care", desc = "Water the wilted flowers out in the Front Yard." },
    { id = 6, title = "Dinner Prep", desc = "Prepare a warm home-cooked meal in the Kitchen." },
    { id = 7, title = "Dusting Sprint", desc = "Get House Cleanliness above 85%." },
    { id = 8, title = "Mailbox Drop", desc = "Check the mailbox in the Front Yard." },
    { id = 9, title = "Greg's Evening", desc = "Greet Greg warmly when he returns at 6 PM." },
    { id = 10, title = "Rest Up", desc = "Sleep through the night to reach Day 2." },

    -- Tier 2: Neighborly Spark (11-20)
    { id = 11, title = "Curious Eyes", desc = "Gaze over at Mary's yard from the Front Yard." },
    { id = 12, title = "First Hello", desc = "Wave and talk to Mary in the Front Yard." },
    { id = 13, title = "Borrowing Sugar", desc = "Ask Mary for baking ingredients." },
    { id = 14, title = "Coffee Date", desc = "Invite Mary inside the Kitchen for coffee." },
    { id = 15, title = "Personal Talk", desc = "Share a deep personal story with Mary." },
    { id = 16, title = "Innocent Touch", desc = "Hold Mary's hand briefly during conversation." },
    { id = 17, title = "Cover Tracks", desc = "Clean the Kitchen completely before Greg gets back." },
    { id = 18, title = "Garden Encounter", desc = "Meet Mary in the garden while Greg is away." },
    { id = 19, title = "Secret Gift", desc = "Give Mary a baked dish or special item." },
    { id = 20, title = "Flirty Text", desc = "Reach 40 Mary Affection." },

    -- Tier 3: High Stakes Infidelity (21-30)
    { id = 21, title = "The Secret Knock", desc = "Invite Mary into the house after Greg leaves." },
    { id = 22, title = "First Kiss", desc = "Share a passionate moment with Mary in the house." },
    { id = 23, title = "False Alibi", desc = "Lie smoothly to Greg to lower his Suspicion." },
    { id = 24, title = "Wine Evening", desc = "Share a bottle of wine with Mary in the Living Room." },
    { id = 25, title = "Close Call", desc = "Hide evidence before Greg walks through the door." },
    { id = 26, title = "Afternoon Escape", desc = "Sneak over to Mary's House." },
    { id = 27, title = "Double Life", desc = "Keep House Clean > 70% while Mary Affection > 70%." },
    { id = 28, title = "The Love Letter", desc = "Write a secret note and pass it to Mary." },
    { id = 29, title = "Deep Commitment", desc = "Reach 90 Mary Affection." },
    { id = 30, title = "Forever Kimith", desc = "Make your final choice about Greg and Mary." }
}

-- Utility Functions
local function hasItem(itemName)
    for _, item in ipairs(inventory) do
        if item == itemName then return true end
    end
    return false
end

local function addItem(itemName)
    if not hasItem(itemName) then
        table.insert(inventory, itemName)
    end
end

local function clampStats()
    energy = math.max(0, math.min(100, energy))
    houseClean = math.max(0, math.min(100, houseClean))
    maryAffection = math.max(0, math.min(100, maryAffection))
    husbandSuspicion = math.max(0, math.min(100, husbandSuspicion))
end

local function advanceTime(hoursSpent)
    hour = hour + hoursSpent
    houseClean = houseClean - (hoursSpent * 3)

    if hour >= 18 and hour < 22 then
        husbandHome = true
    else
        husbandHome = false
    end

    if hour >= 24 then
        hour = hour - 24
        day = day + 1
        lastMessage = "A new day dawns. Greg left for work."
    end

    clampStats()
end

-- Render GUI Layout
local function drawHUD()
    term.setBackgroundColor(colors.gray)
    term.setTextColor(colors.white)

    -- Line 13: Divider
    term.setCursorPos(1, 13)
    term.write(string.rep("=", termW))

    -- Line 14: Time & Location
    term.setCursorPos(1, 14)
    term.clearLine()
    local timeStr = string.format(" Day %d - %02d:00 | Loc: %s", day, hour, location)
    if husbandHome then timeStr = timeStr .. " [GREG IS HOME]" end
    term.write(timeStr)

    -- Line 15: Stats
    term.setCursorPos(1, 15)
    term.clearLine()
    term.write(string.format(" Energy:%d%% | Clean:%d%% | Mary:%d%% | Suspicion:", energy, houseClean, maryAffection))

    if husbandSuspicion > 60 then
        term.setTextColor(colors.red)
    elseif husbandSuspicion > 30 then
        term.setTextColor(colors.orange)
    else
        term.setTextColor(colors.green)
    end
    term.write(husbandSuspicion .. "%")
    term.setTextColor(colors.white)

    -- Line 16 & 17: Active Quest
    term.setCursorPos(1, 16)
    term.clearLine()
    local q = questList[activeQuestIndex]
    if q then
        term.write(string.format(" QUEST %d/%d: %s", q.id, #questList, q.title))
        term.setCursorPos(1, 17)
        term.clearLine()
        term.write(" " .. q.desc)
    else
        term.write(" QUEST: All Objectives Completed!")
        term.setCursorPos(1, 17)
        term.clearLine()
    end

    -- Line 18: Inventory
    term.setCursorPos(1, 18)
    term.clearLine()
    local invStr = " Inv: " .. table.concat(inventory, ", ")
    term.write(string.sub(invStr, 1, termW))
end

local function drawScreen(options)
    term.setBackgroundColor(colors.black)
    term.clear()

    -- Story / Narrative Area (Lines 1 to 6)
    term.setCursorPos(1, 1)
    term.setTextColor(colors.yellow)
    term.write("--- KIMITH'S HOUSEHOLD ---")

    term.setCursorPos(1, 3)
    term.setTextColor(colors.white)
    term.write(lastMessage)

    -- Choices Area (Lines 7 to 12)
    term.setCursorPos(1, 7)
    term.setTextColor(colors.cyan)
    term.write("ACTIONS:")

    for idx, opt in ipairs(options) do
        term.setCursorPos(1, 7 + idx)
        term.setTextColor(colors.lightBlue)
        term.write(string.format(" [%d] %s", idx, opt.text))
    end

    drawHUD()
end

-- Quest Checker
local function checkQuestProgress()
    local q = questList[activeQuestIndex]
    if not q then return end

    if q.id == 7 and houseClean >= 85 then questCompleted = true
    elseif q.id == 20 and maryAffection >= 40 then questCompleted = true
    elseif q.id == 27 and houseClean >= 70 and maryAffection >= 70 then questCompleted = true
    elseif q.id == 29 and maryAffection >= 90 then questCompleted = true
    end

    if questCompleted then
        activeQuestIndex = activeQuestIndex + 1
        questCompleted = false
        lastMessage = "QUEST COMPLETED! New objective unlocked."
    end
end

-- Main Game Logic
local function main()
    while true do
        clampStats()
        checkQuestProgress()

        -- Fail condition
        if husbandSuspicion >= 100 then
            term.clear()
            term.setCursorPos(1, 5)
            term.setTextColor(colors.red)
            term.write("GAME OVER: Greg caught on to your secrets!")
            term.setCursorPos(1, 7)
            term.setTextColor(colors.white)
            term.write("Your marriage exploded and Mary locked her door.")
            return
        end

        -- Dynamically build options based on Location
        local options = {}

        -- Common Navigation Options
        if location ~= "Living Room" then
            table.insert(options, { text = "Go to Living Room", action = function() location = "Living Room"; advanceTime(1) end })
        end
        if location ~= "Kitchen" then
            table.insert(options, { text = "Go to Kitchen", action = function() location = "Kitchen"; advanceTime(1) end })
        end
        if location ~= "Front Yard" then
            table.insert(options, { text = "Go to Front Yard", action = function() location = "Front Yard"; advanceTime(1) end })
        end

        -- Contextual Actions by Location
        if location == "Living Room" then
            table.insert(options, { text = "Clean Living Room (Energy -15, Clean +25)", action = function()
                energy = energy - 15
                houseClean = houseClean + 25
                lastMessage = "You scrubbed the lounge and vacuumed the rugs."
                if activeQuestIndex == 1 then questCompleted = true end
                advanceTime(1)
            end })

            if hasItem("Coffee") then
                table.insert(options, { text = "Drink Coffee (Energy +30)", action = function()
                    energy = energy + 30
                    lastMessage = "You drank a fresh hot coffee."
                    advanceTime(1)
                end })
            end

            if husbandHome then
                table.insert(options, { text = "Talk to Greg (Suspicion -10)", action = function()
                    husbandSuspicion = husbandSuspicion - 10
                    lastMessage = "You chatted politely with Greg about his workday."
                    if activeQuestIndex == 9 then questCompleted = true end
                    advanceTime(1)
                end })
            end

            if activeQuestIndex == 24 and not husbandHome then
                table.insert(options, { text = "Share Wine with Mary (Mary +15)", action = function()
                    maryAffection = maryAffection + 15
                    husbandSuspicion = husbandSuspicion + 10
                    lastMessage = "You and Mary drank wine together while laughing softly."
                    questCompleted = true
                    advanceTime(2)
                end })
            end

            table.insert(options, { text = "Rest / Sleep (Restores Energy, Advances Day)", action = function()
                energy = 100
                lastMessage = "You slept through the night."
                if activeQuestIndex == 10 then questCompleted = true end
                advanceTime(8)
            end })

        elseif location == "Kitchen" then
            table.insert(options, { text = "Brew Fresh Coffee", action = function()
                addItem("Coffee")
                lastMessage = "You brewed a rich pot of dark roast coffee."
                if activeQuestIndex == 2 then questCompleted = true end
                advanceTime(1)
            end })

            table.insert(options, { text = "Cook Dinner Meal", action = function()
                addItem("Warm Meal")
                energy = energy - 10
                lastMessage = "You prepped a lovely dinner for the evening."
                if activeQuestIndex == 6 then questCompleted = true end
                advanceTime(2)
            end })

            table.insert(options, { text = "Scrub Kitchen Counters (Clean +20)", action = function()
                houseClean = houseClean + 20
                energy = energy - 10
                lastMessage = "The kitchen counters sparkle."
                if activeQuestIndex == 4 or activeQuestIndex == 17 then questCompleted = true end
                advanceTime(1)
            end })

            if activeQuestIndex == 14 and not husbandHome then
                table.insert(options, { text = "Invite Mary inside for Coffee (Mary +10)", action = function()
                    maryAffection = maryAffection + 10
                    lastMessage = "Mary came inside and sat at the counter with you."
                    questCompleted = true
                    advanceTime(1)
                end })
            end

        elseif location == "Front Yard" then
            table.insert(options, { text = "Water Flowers (Clean +10)", action = function()
                energy = energy - 10
                lastMessage = "You watered the garden beds outside."
                if activeQuestIndex == 5 then questCompleted = true end
                advanceTime(1)
            end })

            table.insert(options, { text = "Check Mailbox", action = function()
                lastMessage = "You collected the daily mail."
                if activeQuestIndex == 8 then questCompleted = true end
                advanceTime(1)
            end })

            table.insert(options, { text = "Talk to Mary (Mary +10)", action = function()
                maryAffection = maryAffection + 10
                lastMessage = "You waved at Mary across the lawn and struck up a conversation."
                if activeQuestIndex == 11 or activeQuestIndex == 12 or activeQuestIndex == 18 then questCompleted = true end
                advanceTime(1)
            end })

            if activeQuestIndex == 22 and not husbandHome then
                table.insert(options, { text = "Kiss Mary secretly (Mary +20, Suspicion +15)", action = function()
                    maryAffection = maryAffection + 20
                    husbandSuspicion = husbandSuspicion + 15
                    lastMessage = "You pulled Mary behind the hedge and kissed her passionately."
                    questCompleted = true
                    advanceTime(1)
                end })
            end
        end

        -- Render UI and wait for player choice
        drawScreen(options)

        local event, char = os.pullEvent("char")
        local choice = tonumber(char)

        if choice and choice >= 1 and choice <= #options then
            options[choice].action()
        end
    end
end

main()
