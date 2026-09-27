local PRGM_DIR = "user_files/calcprograms"
if not fs.exists("user_files") then fs.makeDir("user_files") end
if not fs.exists(PRGM_DIR) then fs.makeDir(PRGM_DIR) end

local termW, termH = term.getSize()

-- Helper function to convert number to binary representation
local function toBin(n)
  n = math.floor(n)
  if n == 0 then return "0b0" end
  local t = {}
  local neg = false
  if n < 0 then neg = true; n = math.abs(n) end
  while n > 0 do
    table.insert(t, 1, n % 2)
    n = math.floor(n / 2)
  end
  return (neg and "-" or "") .. "0b" .. table.concat(t)
end

-- Environment for math evaluation and variables
local mathEnv = {
  sin = function(x) return math.sin(math.rad(x)) end,
  cos = function(x) return math.cos(math.rad(x)) end,
  tan = function(x) return math.tan(math.rad(x)) end,
  asin = function(x) return math.deg(math.asin(x)) end,
  acos = function(x) return math.deg(math.acos(x)) end,
  atan = function(x) return math.deg(math.atan(x)) end,
  sqrt = math.sqrt,
  log = function(x) return math.log10(x) end,
  ln = math.log,
  abs = math.abs,
  pi = math.pi,
  e = math.exp(1),
  ans = 0,
  x = 0,

  -- Coordinate Tools
  nether = function(x, z)
    if not z then return x / 8 end
    return string.format("N[X:%d Z:%d]", math.floor(x / 8), math.floor(z / 8))
  end,
  overworld = function(x, z)
    if not z then return x * 8 end
    return string.format("OW[X:%d Z:%d]", math.floor(x * 8), math.floor(z * 8))
  end,
  dist = function(a, b, c, d, e, f)
    if f then
      return math.sqrt((d - a)^2 + (e - b)^2 + (f - c)^2)
    elseif d then
      return math.sqrt((c - a)^2 + (d - b)^2)
    end
    return 0
  end
}

local currentMode = "BASE10" -- BASE10, HEX, BIN, STK64, STK16, Y_EDIT, GRAPH, HELP
local currentExpr = ""

-- Multi-function storage
local yExprs = { "sin(x)", "cos(x)", "" }
local selectedY = 1
local yColors = { colors.lime, colors.cyan, colors.magenta, colors.orange, colors.yellow }

local history = {}
local inputHistory = {}
local historyIdx = 0
local scrollOffset = 0
local helpPage = 1

-- Graph Pan & Scale variables
local graphZoom = 10
local graphCenterX = 0
local graphCenterY = 0

-- Button Layout Definition
local buttons = {
  -- Row 1: Function Keys & Modes
  { label = "Y=",     x = 1,  y = 9,  w = 5, h = 1, bg = colors.blue, fg = colors.white, action = "Y_EDIT" },
  { label = "GRAPH",  x = 7,  y = 9,  w = 7, h = 1, bg = colors.blue, fg = colors.white, action = "GRAPH" },
  { label = "PRGM",   x = 15, y = 9,  w = 6, h = 1, bg = colors.purple, fg = colors.white, action = "PRGM" },
  { label = "MODE",   x = 22, y = 9,  w = 5, h = 1, bg = colors.lime, fg = colors.black, action = "TOGGLE_MODE" },
  { label = "HELP",   x = 28, y = 9,  w = 6, h = 1, bg = colors.yellow, fg = colors.black, action = "HELP" },
  { label = "DEL",    x = 35, y = 9,  w = 5, h = 1, bg = colors.red, fg = colors.white, action = "DEL" },
  { label = "CLR",    x = 41, y = 9,  w = 5, h = 1, bg = colors.red, fg = colors.white, action = "CLEAR" },

  -- Row 2: Trig, Powers & Stack Notation
  { label = "SIN",    x = 1,  y = 11, w = 5, h = 1, bg = colors.gray, fg = colors.white, action = "sin(" },
  { label = "COS",    x = 7,  y = 11, w = 5, h = 1, bg = colors.gray, fg = colors.white, action = "cos(" },
  { label = "TAN",    x = 13, y = 11, w = 5, h = 1, bg = colors.gray, fg = colors.white, action = "tan(" },
  { label = "s",      x = 19, y = 11, w = 4, h = 1, bg = colors.lime, fg = colors.black, action = "s" },
  { label = "^",      x = 24, y = 11, w = 4, h = 1, bg = colors.gray, fg = colors.white, action = "^" },
  { label = "(",      x = 29, y = 11, w = 4, h = 1, bg = colors.gray, fg = colors.white, action = "(" },
  { label = ")",      x = 34, y = 11, w = 4, h = 1, bg = colors.gray, fg = colors.white, action = ")" },

  -- Row 3: Numbers 7-9 & Div / Vars
  { label = "7",      x = 1,  y = 13, w = 5, h = 1, bg = colors.lightGray, fg = colors.black, action = "7" },
  { label = "8",      x = 7,  y = 13, w = 5, h = 1, bg = colors.lightGray, fg = colors.black, action = "8" },
  { label = "9",      x = 13, y = 13, w = 5, h = 1, bg = colors.lightGray, fg = colors.black, action = "9" },
  { label = "/",      x = 19, y = 13, w = 4, h = 1, bg = colors.orange, fg = colors.white, action = "/" },
  { label = "X",      x = 24, y = 13, w = 4, h = 1, bg = colors.cyan, fg = colors.black, action = "X" },
  { label = "SQRT",   x = 29, y = 13, w = 6, h = 1, bg = colors.gray, fg = colors.white, action = "sqrt(" },

  -- Row 4: Numbers 4-6 & Mult
  { label = "4",      x = 1,  y = 15, w = 5, h = 1, bg = colors.lightGray, fg = colors.black, action = "4" },
  { label = "5",      x = 7,  y = 15, w = 5, h = 1, bg = colors.lightGray, fg = colors.black, action = "5" },
  { label = "6",      x = 13, y = 15, w = 5, h = 1, bg = colors.lightGray, fg = colors.black, action = "6" },
  { label = "*",      x = 19, y = 15, w = 4, h = 1, bg = colors.orange, fg = colors.white, action = "*" },
  { label = "LN",     x = 24, y = 15, w = 4, h = 1, bg = colors.gray, fg = colors.white, action = "ln(" },
  { label = "LOG",    x = 29, y = 15, w = 5, h = 1, bg = colors.gray, fg = colors.white, action = "log(" },

  -- Row 5: Numbers 1-3 & Sub
  { label = "1",      x = 1,  y = 17, w = 5, h = 1, bg = colors.lightGray, fg = colors.black, action = "1" },
  { label = "2",      x = 7,  y = 17, w = 5, h = 1, bg = colors.lightGray, fg = colors.black, action = "2" },
  { label = "3",      x = 13, y = 17, w = 5, h = 1, bg = colors.lightGray, fg = colors.black, action = "3" },
  { label = "-",      x = 19, y = 17, w = 4, h = 1, bg = colors.orange, fg = colors.white, action = "-" },
  { label = "ANS",    x = 24, y = 17, w = 5, h = 1, bg = colors.gray, fg = colors.white, action = "ans" },

  -- Row 6: Zero, Dec, Add, Enter
  { label = "0",      x = 1,  y = 19, w = 5, h = 1, bg = colors.lightGray, fg = colors.black, action = "0" },
  { label = ".",      x = 7,  y = 19, w = 5, h = 1, bg = colors.lightGray, fg = colors.black, action = "." },
  { label = "+",      x = 13, y = 19, w = 5, h = 1, bg = colors.orange, fg = colors.white, action = "+" },
  { label = "ENTER",  x = 19, y = 19, w = 26, h = 1, bg = colors.green, fg = colors.white, action = "ENTER" }
}

local function formatStorageScaler(totalItems, base)
  base = base or 64
  local totalStacks = math.floor(totalItems / base)
  local remItems = totalItems % base

  local sb = math.floor(totalStacks / 27)
  local remStacksSB = totalStacks % 27

  local dc = math.floor(totalStacks / 54)
  local remStacksDC = totalStacks % 54

  local resStr = string.format("%ds %di", totalStacks, remItems)
  if sb > 0 or dc > 0 then
    resStr = resStr .. string.format(" | %dSB+%ds | %dDC+%ds", sb, remStacksSB, dc, remStacksDC)
  end
  return resStr .. " (" .. totalItems .. ")"
end

local function evaluateExpr(exprStr, customX)
  if exprStr == "" then return "" end

  local varName, varValExpr = exprStr:match("^([A-Za-z]%w*)%s*=%s*(.+)$")
  if varName and varValExpr then
    local val = evaluateExpr(varValExpr, customX)
    if type(val) == "number" then
      mathEnv[varName] = val
      return varName .. " = " .. val
    elseif type(val) == "string" then
      return "ERR:ASSIGN"
    end
  end

  local env = {}
  for k, v in pairs(mathEnv) do env[k] = v end
  if customX then env.x = customX end

  local sanitized = exprStr:gsub("X", "x")

  local stackBase = (currentMode == "STK16") and 16 or 64
  sanitized = sanitized:gsub("(%d+)s(%d+)", "(%1*" .. stackBase .. "+%2)")
  sanitized = sanitized:gsub("(%d+)s", "(%1*" .. stackBase .. ")")

  local fn, err = load("return " .. sanitized, "calc", "t", env)
  if not fn then return "ERR:SYNTAX" end

  local ok, res = pcall(fn)
  if not ok then return "ERR:DOMAIN" end

  if type(res) == "number" then
    if not customX then mathEnv.ans = res end
    if currentMode == "STK64" or currentMode == "STK16" then
      return formatStorageScaler(math.floor(res), stackBase)
    elseif currentMode == "HEX" then
      local intVal = math.floor(res)
      return string.format("0x%X (%d)", intVal, intVal)
    elseif currentMode == "BIN" then
      local intVal = math.floor(res)
      return toBin(intVal) .. " (" .. intVal .. ")"
    end
  end
  return res
end

local function drawDisplayArea()
  term.setBackgroundColor(colors.gray)
  term.setTextColor(colors.white)
  term.setCursorPos(1, 1)
  term.clearLine()
  term.write(" craftCalc | MODE: " .. currentMode)

  term.setBackgroundColor(colors.black)
  for r = 2, 8 do
    term.setCursorPos(1, r)
    term.clearLine()
  end

  if currentMode == "BASE10" or currentMode == "HEX" or currentMode == "BIN" or currentMode == "STK64" or currentMode == "STK16" then
    local startY = 2
    local historySpace = 5
    local displayList = {}

    for _, item in ipairs(history) do
      table.insert(displayList, { text = item.expr, align = "left", color = colors.white })
      table.insert(displayList, { text = tostring(item.result), align = "right", color = colors.lime })
    end

    local totalLines = #displayList
    local maxOffset = math.max(0, totalLines - historySpace)
    scrollOffset = math.max(0, math.min(scrollOffset, maxOffset))

    local endIdx = totalLines - scrollOffset
    local startIdx = math.max(1, endIdx - historySpace + 1)
    local y = startY

    for i = startIdx, math.min(endIdx, totalLines) do
      if i >= 1 then
        local line = displayList[i]
        term.setCursorPos(1, y)
        term.setTextColor(line.color)
        if line.align == "right" then
          local str = tostring(line.text)
          term.setCursorPos(termW - #str + 1, y)
          term.write(str)
        else
          term.write(line.text:sub(1, termW))
        end
        y = y + 1
      end
    end

    term.setCursorPos(1, 7)
    term.setTextColor(colors.yellow)
    term.write("> " .. currentExpr)

  elseif currentMode == "HELP" then
    term.setCursorPos(2, 2)
    term.setTextColor(colors.cyan)
    term.write("===CALCULATOR HELP (Pg " .. helpPage .. "/2) ===")

    if helpPage == 1 then
      term.setCursorPos(2, 3)
      term.setTextColor(colors.yellow)
      term.write("BASES & STACK MODES (MODE button):")
      term.setCursorPos(2, 4)
      term.setTextColor(colors.white)
      term.write("BASE10, HEX (Base 16), BIN (Base 2), STK64, STK16.")
      term.setCursorPos(2, 5)
      term.write("Use 's' for stack input (e.g., 3s12 = 3 stacks + 12).")
      term.setCursorPos(2, 6)
      term.write("GRAPH CONTROLS: Scroll=Zoom, Arrows=Pan.")
      term.setCursorPos(2, 7)
      term.setTextColor(colors.gray)
      term.write("Press HELP again for Page 2 or CLR to exit.")
    else
      term.setCursorPos(2, 3)
      term.setTextColor(colors.yellow)
      term.write("VARIABLES & COORD TOOLS:")
      term.setCursorPos(2, 4)
      term.setTextColor(colors.white)
      term.write("Assign vars: A=100 or B=2s64 -> Use in math: A+B")
      term.setCursorPos(2, 5)
      term.write("nether(x,z) / overworld(x,z) -> Dimension scaling.")
      term.setCursorPos(2, 6)
      term.write("dist(x1,y1,z1, x2,y2,z2) -> 3D Euclidean distance.")
      term.setCursorPos(2, 7)
      term.setTextColor(colors.gray)
      term.write("Up/Down Arrow keys cycle input history.")
    end

  elseif currentMode == "Y_EDIT" then
    term.setCursorPos(2, 2)
    term.setTextColor(colors.cyan)
    term.write("Function Plotter (Up/Down to switch slots)")

    for i = 1, 3 do
      term.setCursorPos(2, 3 + i)
      if i == selectedY then
        term.setTextColor(colors.yellow)
        term.write("> Y" .. i .. " = " .. (yExprs[i] or ""))
      else
        term.setTextColor(yColors[i] or colors.white)
        term.write("  Y" .. i .. " = " .. (yExprs[i] or ""))
      end
    end

    term.setCursorPos(2, 8)
    term.setTextColor(colors.lightGray)
    term.write("Use keypad/keyboard to edit active line.")

  elseif currentMode == "GRAPH" then
    local graphW = termW
    local graphH = 7
    local startY = 2

    local xMin = graphCenterX - graphZoom
    local xMax = graphCenterX + graphZoom
    local yMin = graphCenterY - graphZoom
    local yMax = graphCenterY + graphZoom

    -- Calculate origin screen coordinates
    local originX = math.floor((0 - xMin) / (xMax - xMin) * (graphW - 1) + 1)
    local originY = startY + math.floor((yMax - 0) / (yMax - yMin) * (graphH - 1))

    -- Draw Axes
    term.setTextColor(colors.gray)
    if originX >= 1 and originX <= graphW then
      for y = startY, startY + graphH - 1 do
        term.setCursorPos(originX, y)
        term.write("|")
      end
    end

    if originY >= startY and originY < startY + graphH then
      term.setCursorPos(1, originY)
      term.write(string.rep("-", graphW))
    end

    if originX >= 1 and originX <= graphW and originY >= startY and originY < startY + graphH then
      term.setCursorPos(originX, originY)
      term.write("+")
    end

    -- Plot all defined functions
    for idx, expr in ipairs(yExprs) do
      if expr and expr ~= "" then
        term.setTextColor(yColors[idx] or colors.lime)
        for screenX = 1, graphW do
          local mathX = xMin + (screenX - 1) * ((xMax - xMin) / (graphW - 1))
          local mathY = evaluateExpr(expr, mathX)

          if type(mathY) == "number" and mathY >= yMin and mathY <= yMax then
            local screenY = startY + math.floor((yMax - mathY) / (yMax - yMin) * (graphH - 1))
            if screenY >= startY and screenY < startY + graphH then
              term.setCursorPos(screenX, screenY)
              term.write("*")
            end
          end
        end
      end
    end

    -- Scale Overlay Banner
    term.setCursorPos(1, 2)
    term.setTextColor(colors.yellow)
    term.setBackgroundColor(colors.gray)
    term.write(string.format(" Scale: +-%.1f | Ctr: (%.1f,%.1f) ", graphZoom, graphCenterX, graphCenterY))
    term.setBackgroundColor(colors.black)
  end
end

local function drawKeypad()
  for _, btn in ipairs(buttons) do
    term.setCursorPos(btn.x, btn.y)
    term.setBackgroundColor(btn.bg)
    term.setTextColor(btn.fg)
    local padding = btn.w - #btn.label
    local leftPad = math.floor(padding / 2)
    local rightPad = padding - leftPad
    term.write(string.rep(" ", leftPad) .. btn.label .. string.rep(" ", rightPad))
  end
end

local function runProgram(prgmName)
  local path = fs.combine(PRGM_DIR, prgmName)
  if not fs.exists(path) then return end

  local file = fs.open(path, "r")
  local code = file.readAll()
  file.close()

  local fn, err = load(code, prgmName, "t", _G)
  if not fn then return end

  term.setBackgroundColor(colors.black)
  term.clear()
  term.setCursorPos(1, 1)
  pcall(fn)

  term.setTextColor(colors.yellow)
  print("\nProgram finished. Press Enter...")
  read()
end

local function openProgramMenu()
  term.setBackgroundColor(colors.black)
  term.clear()
  term.setCursorPos(1, 1)
  term.setTextColor(colors.cyan)
  print("=== CALC PROGRAMS (" .. PRGM_DIR .. ") ===")

  local files = fs.list(PRGM_DIR)
  local prgms = {}
  for _, f in ipairs(files) do
    if not fs.isDir(fs.combine(PRGM_DIR, f)) then
      table.insert(prgms, f)
    end
  end

  if #prgms == 0 then
    term.setTextColor(colors.gray)
    print("\nNo programs found in " .. PRGM_DIR)
    print("Press Enter to back...")
    read()
    return
  end

  for i, p in ipairs(prgms) do
    term.setTextColor(colors.white)
    print(" [" .. i .. "] " .. p)
  end

  term.setTextColor(colors.yellow)
  write("\nSelect Program (or 'q'): ")
  local choice = read()
  if choice:lower() ~= "q" then
    local idx = tonumber(choice)
    if idx and prgms[idx] then
      runProgram(prgms[idx])
    end
  end
end

local function handleButtonAction(action)
  if action == "Y_EDIT" then
    currentMode = "Y_EDIT"
  elseif action == "GRAPH" then
    currentMode = "GRAPH"
  elseif action == "PRGM" then
    openProgramMenu()
  elseif action == "HELP" then
    if currentMode == "HELP" then
      helpPage = (helpPage == 1) and 2 or 1
    else
      currentMode = "HELP"
      helpPage = 1
    end
  elseif action == "TOGGLE_MODE" then
    if currentMode == "BASE10" then
      currentMode = "HEX"
    elseif currentMode == "HEX" then
      currentMode = "BIN"
    elseif currentMode == "BIN" then
      currentMode = "STK64"
    elseif currentMode == "STK64" then
      currentMode = "STK16"
    else
      currentMode = "BASE10"
    end
  elseif action == "CLEAR" then
    if currentMode == "Y_EDIT" then
      yExprs[selectedY] = ""
    elseif currentMode == "HELP" then
      currentMode = "BASE10"
    elseif currentMode == "GRAPH" then
      graphZoom = 10
      graphCenterX = 0
      graphCenterY = 0
    else
      currentExpr = ""
      scrollOffset = 0
      if currentMode ~= "HEX" and currentMode ~= "BIN" and currentMode ~= "STK64" and currentMode ~= "STK16" then
        currentMode = "BASE10"
      end
    end
  elseif action == "DEL" then
    if currentMode == "Y_EDIT" then
      yExprs[selectedY] = yExprs[selectedY]:sub(1, -2)
    else
      currentExpr = currentExpr:sub(1, -2)
    end
  elseif action == "ENTER" then
    if currentMode == "Y_EDIT" then
      currentMode = "GRAPH"
    elseif (currentMode == "BASE10" or currentMode == "HEX" or currentMode == "BIN" or currentMode == "STK64" or currentMode == "STK16") and currentExpr ~= "" then
      table.insert(inputHistory, currentExpr)
      historyIdx = 0
      scrollOffset = 0
      local res = evaluateExpr(currentExpr)
      table.insert(history, { expr = currentExpr, result = res })
      currentExpr = ""
    end
  else
    if currentMode == "Y_EDIT" then
      yExprs[selectedY] = yExprs[selectedY] .. action
    elseif currentMode == "HELP" then
      currentMode = "BASE10"
      currentExpr = currentExpr .. action
    else
      currentExpr = currentExpr .. action
    end
  end
end

-- Main Application Loop
while true do
  term.setBackgroundColor(colors.black)
  drawDisplayArea()
  drawKeypad()

  local event, p1, p2, p3 = os.pullEvent()

  if event == "mouse_click" and p1 == 1 then
    local cx, cy = p2, p3
    for _, btn in ipairs(buttons) do
      if cx >= btn.x and cx <= btn.x + btn.w - 1 and cy == btn.y then
        handleButtonAction(btn.action)
        break
      end
    end
  elseif event == "mouse_scroll" then
    if currentMode == "GRAPH" then
      if p1 > 0 then
        graphZoom = graphZoom * 1.25
      else
        graphZoom = math.max(0.1, graphZoom / 1.25)
      end
    else
      scrollOffset = scrollOffset - p1
    end
  elseif event == "char" then
    if currentMode == "Y_EDIT" then
      yExprs[selectedY] = yExprs[selectedY] .. p1
    elseif currentMode == "HELP" then
      currentMode = "BASE10"
      currentExpr = currentExpr .. p1
    elseif currentMode == "GRAPH" then
      if p1 == "+" then
        graphZoom = math.max(0.1, graphZoom / 1.25)
      elseif p1 == "-" then
        graphZoom = graphZoom * 1.25
      end
    else
      currentExpr = currentExpr .. p1
    end
  elseif event == "key" then
    local isEnterKey = (p1 == keys.enter or p1 == keys.numPadEnter or p1 == keys.numpadEnter)

    if isEnterKey then
      handleButtonAction("ENTER")
    elseif p1 == keys.backspace then
      handleButtonAction("DEL")
    elseif p1 == keys.up then
      if currentMode == "Y_EDIT" then
        selectedY = math.max(1, selectedY - 1)
      elseif currentMode == "GRAPH" then
        graphCenterY = graphCenterY + (graphZoom / 4)
      elseif #inputHistory > 0 then
        if historyIdx == 0 then
          historyIdx = #inputHistory
        else
          historyIdx = math.max(1, historyIdx - 1)
        end
        currentExpr = inputHistory[historyIdx]
      end
    elseif p1 == keys.down then
      if currentMode == "Y_EDIT" then
        selectedY = math.min(#yExprs, selectedY + 1)
      elseif currentMode == "GRAPH" then
        graphCenterY = graphCenterY - (graphZoom / 4)
      elseif historyIdx > 0 then
        historyIdx = historyIdx + 1
        if historyIdx > #inputHistory then
          historyIdx = 0
          currentExpr = ""
        else
          currentExpr = inputHistory[historyIdx]
        end
      end
    elseif p1 == keys.left and currentMode == "GRAPH" then
      graphCenterX = graphCenterX - (graphZoom / 4)
    elseif p1 == keys.right and currentMode == "GRAPH" then
      graphCenterX = graphCenterX + (graphZoom / 4)
    end
  end
end
