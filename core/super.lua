--supereddit by mix.moo2
--this is for my os but if you care enough to grab it you can have it. use this for whatever its like my 5th program and is porbs hot garbo
local tArgs = { ... }
local currentFilePath = nil
local isModified = false
local lines = { "" }
local cursorX, cursorY = 1, 1
local scrollX, scrollY = 0, 0
local termW, termH = term.getSize()
local syntaxEnabled = true
local foldEnabled = true
local textColor = colors.white
local editorBg = colors.black
local editorFg = colors.white
local bookmarks = {}
local collapsedBlocks = {}
local showHelpModal = false
local suppressNextChar = false
local isAltDown = false
local selStart = nil
local selEnd = nil
local isSelecting = false
local clipboard = ""
local history = {}
local historyIndex = 0
local activeMenu = nil
local menuOptions = {
  File = { "New", "Open", "Save", "Save As", "Exit" },
  Edit = { "Undo (Alt+Z)", "Redo (Alt+Y)", "Copy (Alt+C)", "Paste (Alt+V)", "Select All (Alt+A)" },
  View = { "Toggle Syntax", "Text Color", "Theme Color", "Toggle Folding" },
  Tools = { "Error Check (F5)", "Toggle Bookmark (Alt+B)", "Next Bookmark (F3)" },
  Help = { "Keyboard Shortcuts (F1)", "About Super Edit" }
}

local colorNameMap = {
  white = colors.white, orange = colors.orange, magenta = colors.magenta,
  lightgreen = colors.lightGreen, yellow = colors.yellow, lime = colors.lime,
  pink = colors.pink, gray = colors.gray, grey = colors.gray,
  lightgray = colors.lightGray, lightgrey = colors.lightGray, cyan = colors.cyan,
  purple = colors.purple, blue = colors.blue, brown = colors.brown,
  green = colors.green, red = colors.red, black = colors.black
}

local luaKeywords = {
  ["local"] = colors.yellow, ["function"] = colors.yellow, ["end"] = colors.yellow,
  ["if"] = colors.magenta, ["then"] = colors.magenta, ["else"] = colors.magenta,
  ["elseif"] = colors.magenta, ["return"] = colors.magenta, ["while"] = colors.magenta,
  ["for"] = colors.magenta, ["do"] = colors.magenta, ["in"] = colors.magenta,
  ["true"] = colors.orange, ["false"] = colors.orange, ["nil"] = colors.orange,
  ["and"] = colors.purple, ["or"] = colors.purple, ["not"] = colors.purple
}

local function autoDetectFileType(path)
  if not path or path == "" then return end
  local ext = path:match("^.+(%..+)$")
  if ext then
    ext = ext:lower()
    if ext == ".lua" then
      syntaxEnabled = true
    elseif ext == ".txt" or ext == ".text" or ext == ".log" then
      syntaxEnabled = false
    end
  else
    syntaxEnabled = false
  end
end

local function saveHistoryState()
  if historyIndex > 0 then
    local lastState = history[historyIndex]
    local isSame = (#lastState.lines == #lines)
    if isSame then
      for i = 1, #lines do
        if lastState.lines[i] ~= lines[i] then isSame = false; break end
      end
    end
    if isSame then return end
  end

  if historyIndex < #history then
    for i = #history, historyIndex + 1, -1 do
      table.remove(history, i)
    end
  end

  local copyLines = {}
  for i, l in ipairs(lines) do copyLines[i] = l end

  table.insert(history, {
    lines = copyLines,
    cx = cursorX,
    cy = cursorY
  })
  historyIndex = #history
end

local function undo()
  if historyIndex > 1 then
    historyIndex = historyIndex - 1
    local state = history[historyIndex]
    lines = {}
    for i, l in ipairs(state.lines) do lines[i] = l end
    cursorX = state.cx
    cursorY = state.cy
    isModified = true
  end
end

local function redo()
  if historyIndex < #history then
    historyIndex = historyIndex + 1
    local state = history[historyIndex]
    lines = {}
    for i, l in ipairs(state.lines) do lines[i] = l end
    cursorX = state.cx
    cursorY = state.cy
    isModified = true
  end
end

local function resolveDiskPath(path)
  if not path or path == "" then return nil end
  if shell then
    return shell.resolve(path)
  end
  return fs.combine("", path)
end

local function clampCursor()
  cursorY = math.max(1, math.min(#lines, cursorY))
  local lineLen = #(lines[cursorY] or "")
  cursorX = math.max(1, math.min(lineLen + 1, cursorX))
end

local function scrollToCursor()
  local editH = termH - 2
  local editW = termW - 6

  if cursorY - 1 < scrollY then scrollY = cursorY - 1 end
  if cursorY - 1 >= scrollY + editH then scrollY = cursorY - editH end
  if cursorX - 1 < scrollX then scrollX = cursorX - 1 end
  if cursorX - 1 >= scrollX + editW then scrollX = cursorX - editW + 1 end
end

local function setStatus(msg)
  term.setCursorPos(1, termH)
  term.setBackgroundColor(colors.gray)
  term.setTextColor(colors.white)
  term.clearLine()
  term.write(" " .. string.sub(msg, 1, termW - 15))
  local posStr = "Ln " .. cursorY .. ", Col " .. cursorX
  term.setCursorPos(termW - #posStr + 1, termH)
  term.write(posStr)
end

local function getDefinedFunctions()
  local customFuncs = {}
  for _, line in ipairs(lines) do
    local cleanLine = line:gsub("%-%-.*", "")
    local fnName = cleanLine:match("%f[%a]function%s+([%a_][%w_]*)")
    if fnName then
      customFuncs[fnName] = true
    end
  end
  return customFuncs
end

local function getSyntaxColors(lineStr, customFuncs)
  local fgColors = {}
  local bgColors = {}
  for i = 1, #lineStr do
    fgColors[i] = syntaxEnabled and textColor or editorFg
    bgColors[i] = editorBg
  end

  if not syntaxEnabled then return fgColors, bgColors end

  local inString = nil
  for i = 1, #lineStr do
    local c = lineStr:sub(i, i)
    if (c == '"' or c == "'") and not inString then
      inString = c
      fgColors[i] = colors.green
    elseif c == inString then
      fgColors[i] = colors.green
      inString = nil
    elseif inString then
      fgColors[i] = colors.green
    end
  end

  local commentStart = lineStr:find("%-%-")
  if commentStart then
    for i = commentStart, #lineStr do
      fgColors[i] = colors.gray
    end
  end

  for word in lineStr:gmatch("[%a_][%w_]*") do
    local startIdx = 1
    while true do
      local s, e = lineStr:find("%f[%a_]" .. word .. "%f[%A_]", startIdx)
      if not s then break end

      if not (commentStart and s >= commentStart) and fgColors[s] ~= colors.green then
        if luaKeywords[word] then
          for i = s, e do fgColors[i] = luaKeywords[word] end
        elseif customFuncs[word] then
          for i = s, e do fgColors[i] = colors.lightBlue end
        end
      end
      startIdx = e + 1
    end
  end

  local searchIdx = 1
  while true do
    local s, e, colorWord = lineStr:find("colors%.([%a_][%w_]*)", searchIdx)
    if not s then break end

    local colorVal = colorNameMap[colorWord:lower()]
    if colorVal and not (commentStart and s >= commentStart) then
      local wordStart = e - #colorWord + 1
      for i = wordStart, e do
        if fgColors[i] ~= colors.green then
          fgColors[i] = colorVal
        end
      end
    end
    searchIdx = e + 1
  end

  return fgColors, bgColors
end

local function findFoldPairs()
  local blockStarts = {}
  local folds = {}

  for i, line in ipairs(lines) do
    local cleanLine = line:gsub("%-%-.*", "")
    if cleanLine:match("%f[%a]function%f[%A]") or cleanLine:match("%f[%a]if%f[%A]") or cleanLine:match("%f[%a]for%f[%A]") or cleanLine:match("%f[%a]while%f[%A]") then
      table.insert(blockStarts, i)
    elseif cleanLine:match("%f[%a]end%f[%A]") then
      if #blockStarts > 0 then
        local startL = table.remove(blockStarts)
        if i - startL >= 1 then
          folds[startL] = i
        end
      end
    end
  end
  return folds
end

local function jumpToNextBookmark()
  local found = false
  for i = cursorY + 1, #lines do
    if bookmarks[i] then
      cursorY = i
      found = true
      break
    end
  end
  if not found then
    for i = 1, cursorY do
      if bookmarks[i] then
        cursorY = i
        found = true
        break
      end
    end
  end
  clampCursor()
  scrollToCursor()
end

local function isPosSelected(lx, ly)
  if not selStart or not selEnd then return false end
  local sY, sX = selStart.y, selStart.x
  local eY, eX = selEnd.y, selEnd.x

  if sY > eY or (sY == eY and sX > eX) then
    sY, eY = eY, sY
    sX, eX = eX, sX
  end

  if ly < sY or ly > eY then return false end
  if ly == sY and ly == eY then return lx >= sX and lx < eX end
  if ly == sY then return lx >= sX end
  if ly == eY then return lx < eX end
  return true
end

local function getSelectedText()
  if not selStart or not selEnd then return "" end
  local sY, sX = selStart.y, selStart.x
  local eY, eX = selEnd.y, selEnd.x

  if sY > eY or (sY == eY and sX > eX) then
    sY, eY = eY, sY
    sX, eX = eX, sX
  end

  local result = {}
  for ly = sY, eY do
    local line = lines[ly] or ""
    if ly == sY and ly == eY then
      table.insert(result, line:sub(sX, eX - 1))
    elseif ly == sY then
      table.insert(result, line:sub(sX))
    elseif ly == eY then
      table.insert(result, line:sub(1, eX - 1))
    else
      table.insert(result, line)
    end
  end
  return table.concat(result, "\n")
end

local function pasteMultilineText(pastedText)
  saveHistoryState()
  local splitLines = {}
  for sub in pastedText:gmatch("[^\r\n]+") do
    table.insert(splitLines, sub)
  end
  if #splitLines == 0 then splitLines = { pastedText } end

  local currentLine = lines[cursorY] or ""
  local leftStr = currentLine:sub(1, cursorX - 1)
  local rightStr = currentLine:sub(cursorX)

  if #splitLines == 1 then
    lines[cursorY] = leftStr .. splitLines[1] .. rightStr
    cursorX = cursorX + #splitLines[1]
  else
    lines[cursorY] = leftStr .. splitLines[1]
    for i = 2, #splitLines - 1 do
      table.insert(lines, cursorY + i - 1, splitLines[i])
    end
    table.insert(lines, cursorY + #splitLines - 1, splitLines[#splitLines] .. rightStr)
    cursorY = cursorY + #splitLines - 1
    cursorX = #splitLines[#splitLines] + 1
  end

  isModified = true
  saveHistoryState()
  clampCursor()
  scrollToCursor()
end

local function loadFile(rawPath)
  local path = resolveDiskPath(rawPath)
  if not path then return false end

  if not fs.exists(path) then
    lines = { "" }
    currentFilePath = path
    isModified = false
    cursorX, cursorY = 1, 1
    history = {}
    historyIndex = 0
    autoDetectFileType(path)
    saveHistoryState()
    return true
  end

  local file = fs.open(path, "r")
  if not file then return false end

  lines = {}
  local line = file.readLine()
  while line do
    table.insert(lines, line)
    line = file.readLine()
  end
  file.close()

  if #lines == 0 then lines = { "" } end
  currentFilePath = path
  isModified = false
  cursorX, cursorY = 1, 1
  history = {}
  historyIndex = 0
  autoDetectFileType(path)
  saveHistoryState()
  return true
end

local function saveFile(rawPath)
  local path = resolveDiskPath(rawPath)
  if not path then return false end
  local file = fs.open(path, "w")
  if not file then return false end

  for _, line in ipairs(lines) do
    file.writeLine(line)
  end
  file.close()
  currentFilePath = path
  isModified = false
  autoDetectFileType(path)
  return true
end

local function promptInput(promptText)
  term.setCursorPos(1, termH)
  term.setBackgroundColor(colors.blue)
  term.setTextColor(colors.white)
  term.clearLine()
  term.write(" " .. promptText .. ": ")
  term.setCursorBlink(true)
  local input = read()
  term.setCursorBlink(false)
  return input
end

local function runErrorCheck()
  local codeText = table.concat(lines, "\n")
  local fn, err = load(codeText, "editor_check")

  term.setCursorPos(1, termH - 1)
  if fn then
    term.setBackgroundColor(colors.green)
    term.setTextColor(colors.black)
    term.clearLine()
    term.write(" Syntax Check Passed! No errors found.")
  else
    term.setBackgroundColor(colors.red)
    term.setTextColor(colors.white)
    term.clearLine()
    local cleanErr = err:gsub("%[string \"editor_check\"%]:", "Line ")
    term.write(" Syntax Error: " .. cleanErr)
  end
  sleep(2)
end

local function drawHeader()
  term.setCursorPos(1, 1)
  term.setBackgroundColor(colors.gray)
  term.setTextColor(colors.white)
  term.clearLine()

  local menus = { "File", "Edit", "View", "Tools", "Help" }
  local xPos = 2
  for _, name in ipairs(menus) do
    term.setCursorPos(xPos, 1)
    if activeMenu == name then
      term.setBackgroundColor(colors.blue)
      term.setTextColor(colors.yellow)
    else
      term.setBackgroundColor(colors.gray)
      term.setTextColor(colors.white)
    end
    term.write(" " .. name .. " ")
    xPos = xPos + #name + 2
  end
end

local function drawDropdown()
  if not activeMenu or not menuOptions[activeMenu] then return end

  local xPos = 2
  local items = menuOptions[activeMenu]
  for idx, item in ipairs(items) do
    term.setCursorPos(xPos, idx + 1)
    term.setBackgroundColor(colors.blue)
    term.setTextColor(colors.white)
    term.write(" " .. item .. string.rep(" ", 25 - #item))
  end
end

local function drawHelpDialog()
  local boxW, boxH = math.min(42, termW - 4), math.min(14, termH - 4)
  local startX = math.floor((termW - boxW) / 2)
  local startY = math.floor((termH - boxH) / 2)

  for y = startY, startY + boxH - 1 do
    term.setCursorPos(startX, y)
    term.setBackgroundColor(colors.gray)
    term.write(string.rep(" ", boxW))
  end

  term.setCursorPos(startX, startY)
  term.setBackgroundColor(colors.blue)
  term.setTextColor(colors.yellow)
  term.write(" --- HOTKEYS & HELP --- " .. string.rep(" ", boxW - 24))

  local helpLines = {
    " F1 : Open/Close Help Menu",
    " F3 : Jump to Next Bookmark",
    " F5 : Run Lua Syntax Error Check",
    " Alt+Z / Y : Undo / Redo Actions",
    " Alt+B : Toggle Line Bookmark",
    " Alt+C/V/A : Copy / Paste / Select All",
    " Drag Mouse: Select Text Region",
    " Gutter : Click Margin for Bookmarks",
    " [-] / [+] : Click to Fold Code Block"
  }

  term.setBackgroundColor(colors.gray)
  term.setTextColor(colors.white)
  for i, line in ipairs(helpLines) do
    if startY + i < startY + boxH then
      term.setCursorPos(startX + 1, startY + i)
      if i == #helpLines then
        term.setTextColor(colors.yellow)
      end
      term.write(line)
    end
  end
end

local function drawEditor()
  termW, termH = term.getSize()
  local foldPairs = findFoldPairs()
  local customFuncs = getDefinedFunctions()
  local activeHiddenUntil = 0

  local lineIdx = scrollY + 1
  local screenY = 2

  while screenY <= termH - 1 do
    term.setCursorPos(1, screenY)
    term.setBackgroundColor(editorBg)
    term.clearLine()

    if lineIdx <= #lines then
      if foldEnabled and lineIdx <= activeHiddenUntil then
        lineIdx = lineIdx + 1
      else
        term.setBackgroundColor(colors.gray)
        term.setTextColor(bookmarks[lineIdx] and colors.yellow or colors.white)
        local mark = bookmarks[lineIdx] and "★" or " "
        local numStr = string.format("%2d%s|", lineIdx % 100, mark)
        term.write(numStr)

        term.setBackgroundColor(editorBg)
        if foldEnabled and foldPairs[lineIdx] then
          term.setTextColor(colors.cyan)
          term.write(collapsedBlocks[lineIdx] and "[+]" or "[-]")
        else
          term.write("   ")
        end

        local lineText = lines[lineIdx]
        local fgColors, bgColors = getSyntaxColors(lineText, customFuncs)

        for charIdx = scrollX + 1, math.min(#lineText + 1, scrollX + termW - 6) do
          local char = lineText:sub(charIdx, charIdx)
          if char == "" then char = " " end

          local isSel = isPosSelected(charIdx, lineIdx)
          term.setTextColor(isSel and colors.white or (fgColors[charIdx] or editorFg))
          term.setBackgroundColor(isSel and colors.blue or (bgColors[charIdx] or editorBg))
          term.write(char)
        end

        if foldEnabled and collapsedBlocks[lineIdx] and foldPairs[lineIdx] then
          activeHiddenUntil = foldPairs[lineIdx]
        end

        lineIdx = lineIdx + 1
        screenY = screenY + 1
      end
    else
      screenY = screenY + 1
    end
  end
end

local function render()
  drawEditor()
  drawHeader()
  drawDropdown()

  if showHelpModal then
    drawHelpDialog()
    term.setCursorBlink(false)
  else
    setStatus(currentFilePath or "New File")
    term.setBackgroundColor(editorBg)
    term.setTextColor(editorFg)
    term.setCursorPos((cursorX - scrollX) + 6, (cursorY - scrollY) + 1)
    term.setCursorBlink(true)
  end
end

local function main()
  term.clear()

  if tArgs[1] then
    loadFile(tArgs[1])
  else
    saveHistoryState()
  end

  while true do
    termW, termH = term.getSize()
    render()

    if not showHelpModal then
      term.setCursorPos((cursorX - scrollX) + 6, (cursorY - scrollY) + 1)
      term.setCursorBlink(true)
    end

    local event, p1, p2, p3 = os.pullEvent()

    if event == "key_up" then
      if p1 == keys.leftAlt or p1 == keys.rightAlt then
        isAltDown = false
      end
    elseif showHelpModal then
      if event == "key" or event == "mouse_click" then
        showHelpModal = false
      end
    else
      if event == "key" then
        local key = p1

        if key == keys.leftAlt or key == keys.rightAlt then
          isAltDown = true
        elseif key == keys.up then
          cursorY = cursorY - 1
        elseif key == keys.down then
          cursorY = cursorY + 1
        elseif key == keys.left then
          cursorX = cursorX - 1
        elseif key == keys.right then
          cursorX = cursorX + 1
        elseif key == keys.enter then
          saveHistoryState()
          local currentLine = lines[cursorY] or ""
          local indent = currentLine:match("^%s*") or ""
          local remaining = currentLine:sub(cursorX)
          lines[cursorY] = currentLine:sub(1, cursorX - 1)
          table.insert(lines, cursorY + 1, indent .. remaining)
          cursorY = cursorY + 1
          cursorX = #indent + 1
          isModified = true
          saveHistoryState()
        elseif key == keys.backspace then
          saveHistoryState()
          if cursorX > 1 then
            local line = lines[cursorY]
            lines[cursorY] = line:sub(1, cursorX - 2) .. line:sub(cursorX)
            cursorX = cursorX - 1
            isModified = true
          elseif cursorY > 1 then
            local prevLen = #(lines[cursorY - 1] or "")
            lines[cursorY - 1] = lines[cursorY - 1] .. lines[cursorY]
            table.remove(lines, cursorY)
            cursorY = cursorY - 1
            cursorX = prevLen + 1
            isModified = true
          end
          saveHistoryState()
        elseif key == keys.f1 then
          showHelpModal = true
        elseif key == keys.f3 then
          jumpToNextBookmark()
        elseif key == keys.f5 then
          runErrorCheck()
        elseif isAltDown and key == keys.z then
          undo()
          suppressNextChar = true
        elseif isAltDown and key == keys.y then
          redo()
          suppressNextChar = true
        elseif isAltDown and key == keys.b then
          bookmarks[cursorY] = not bookmarks[cursorY]
          suppressNextChar = true
        elseif isAltDown and key == keys.c then
          clipboard = getSelectedText()
          setStatus("Copied to clipboard")
          suppressNextChar = true
        elseif isAltDown and key == keys.v then
          if clipboard ~= "" then pasteMultilineText(clipboard) end
          suppressNextChar = true
        elseif isAltDown and key == keys.a then
          selStart = { x = 1, y = 1 }
          selEnd = { x = #(lines[#lines] or "") + 1, y = #lines }
          suppressNextChar = true
        end

        clampCursor()
        scrollToCursor()

      elseif event == "char" then
        if suppressNextChar or isAltDown then
          suppressNextChar = false
        elseif not activeMenu then
          saveHistoryState()
          local line = lines[cursorY] or ""
          lines[cursorY] = line:sub(1, cursorX - 1) .. p1 .. line:sub(cursorX)
          cursorX = cursorX + 1
          isModified = true
          saveHistoryState()
          clampCursor()
          scrollToCursor()
        end

      elseif event == "paste" then
        pasteMultilineText(p1)

      elseif event == "mouse_click" and p1 == 1 then
        local mx, my = p2, p3

        if my == 1 then
          if mx >= 2 and mx <= 7 then activeMenu = (activeMenu == "File") and nil or "File"
          elseif mx >= 8 and mx <= 13 then activeMenu = (activeMenu == "Edit") and nil or "Edit"
          elseif mx >= 14 and mx <= 19 then activeMenu = (activeMenu == "View") and nil or "View"
          elseif mx >= 20 and mx <= 26 then activeMenu = (activeMenu == "Tools") and nil or "Tools"
          elseif mx >= 27 and mx <= 32 then activeMenu = (activeMenu == "Help") and nil or "Help"
          else activeMenu = nil
          end

        elseif activeMenu and my >= 2 and my <= #menuOptions[activeMenu] + 1 and mx >= 2 and mx <= 27 then
          local choice = menuOptions[activeMenu][my - 1]
          activeMenu = nil

          if choice == "New" then
            lines = { "" }; currentFilePath = nil; isModified = false; cursorX, cursorY = 1, 1
            history = {}; historyIndex = 0
            saveHistoryState()
          elseif choice == "Open" then
            local path = promptInput("Open Path (e.g. myfile)")
            if path and path ~= "" then
              if not loadFile(path) then
                setStatus("File not found: " .. path)
                sleep(1)
              end
            end
          elseif choice == "Save" then
            if currentFilePath then saveFile(currentFilePath) else saveFile(promptInput("Save Path")) end
          elseif choice == "Save As" then
            saveFile(promptInput("Save As Path"))
          elseif choice == "Exit" then
            term.clear(); term.setCursorPos(1, 1); return
          elseif choice == "Undo (Alt+Z)" then
            undo()
          elseif choice == "Redo (Alt+Y)" then
            redo()
          elseif choice == "Copy (Alt+C)" then
            clipboard = getSelectedText()
            setStatus("Copied to clipboard")
          elseif choice == "Paste (Alt+V)" then
            if clipboard ~= "" then
              pasteMultilineText(clipboard)
            end
          elseif choice == "Select All (Alt+A)" then
            selStart = { x = 1, y = 1 }
            selEnd = { x = #(lines[#lines] or "") + 1, y = #lines }
          elseif choice == "Toggle Syntax" then
            syntaxEnabled = not syntaxEnabled
          elseif choice == "Text Color" then
            local inputClr = promptInput("Text Color (e.g. yellow, cyan, white)")
            if inputClr and colorNameMap[inputClr:lower()] then
              textColor = colorNameMap[inputClr:lower()]
              editorFg = textColor
            end
          elseif choice == "Theme Color" then
            local inputBg = promptInput("Theme Color (e.g. black, blue, gray)")
            if inputBg and colorNameMap[inputBg:lower()] then
              editorBg = colorNameMap[inputBg:lower()]
            end
          elseif choice == "Toggle Folding" then
            foldEnabled = not foldEnabled
          elseif choice == "Error Check (F5)" then
            runErrorCheck()
          elseif choice == "Toggle Bookmark (Alt+B)" then
            bookmarks[cursorY] = not bookmarks[cursorY]
          elseif choice == "Next Bookmark (F3)" then
            jumpToNextBookmark()
          elseif choice == "Keyboard Shortcuts (F1)" or choice == "About Super Edit" then
            showHelpModal = true
          end

        else
          activeMenu = nil
          if my >= 2 and my <= termH - 1 then
            local clickedLine = my - 1 + scrollY
            if clickedLine <= #lines then
              cursorY = clickedLine
              cursorX = math.max(1, mx - 6 + scrollX)

              if mx <= 3 then
                bookmarks[cursorY] = not bookmarks[cursorY]
              elseif foldEnabled and mx >= 4 and mx <= 6 then
                local foldPairs = findFoldPairs()
                if foldPairs[cursorY] then
                  collapsedBlocks[cursorY] = not collapsedBlocks[cursorY]
                end
              else
                isSelecting = true
                selStart = { x = cursorX, y = cursorY }
                selEnd = { x = cursorX, y = cursorY }
              end
            end
          end
          clampCursor()
        end

      elseif event == "mouse_drag" and isSelecting then
        local mx, my = p2, p3
        if my >= 2 and my <= termH - 1 then
          local dragLine = my - 1 + scrollY
          if dragLine <= #lines then
            selEnd = {
              x = math.max(1, mx - 6 + scrollX),
              y = dragLine
            }
          end
        end

      elseif event == "mouse_up" then
        isSelecting = false

      elseif event == "mouse_scroll" then
        if p1 == -1 and scrollY > 0 then
          scrollY = scrollY - 1
        elseif p1 == 1 and scrollY < #lines - 1 then
          scrollY = scrollY + 1
        end
      end
    end
  end
end

main()
