
-- Made by hand with love by Xella
-- Definitely open for pull requests :)

local nbsTunes = require("nbsTunes")
local betterblittle = require("betterblittle")

if not fs.exists("songs") then
	fs.makeDir("songs")
end
if not fs.exists("meta") then
	fs.makeDir("meta")
end

local SEMITONE_COUNT = 25
local backgroundEffectBuffer = {}
local function initBuffer()
	local width, height = term.getSize()

	local bufferHeight = math.ceil(height * 3)
	local bufferWidth = SEMITONE_COUNT * 2
	if width > 100 then
		bufferWidth = bufferWidth * 2
	end
	backgroundEffectBuffer = {}
	for y = 1, bufferHeight do
		backgroundEffectBuffer[y] = {}
		for x = 1, bufferWidth do
			backgroundEffectBuffer[y][x] = colors.black
		end
	end
end
initBuffer()

local freeSpace = 0
local function updateFreeSpace()
	freeSpace = fs.getFreeSpace("/")
end
updateFreeSpace()
local function formatBytes(bytes)
	if bytes < 1024 then
		return bytes .. " B"
	end
	local kb = bytes / 1024
	if kb < 1024 then
		return math.floor(kb) .. " KiB"
	end
	local mb = kb / 1024
	if mb < 1024 then
		return math.floor(mb) .. " MiB"
	end
	local gb = mb / 1024
	if gb < 1024 then
		return math.floor(gb) .. " GiB"
	end
	local tb = gb / 1024
	return math.floor(tb) .. " TiB"
end

local songsAll = {}

local filepathToMeta = {}

local function loadSongMeta(filename)
	local metaPath = "meta/" .. filename .. ".json"
	local meta = {}
	if fs.exists(metaPath) then
		local file = fs.open(metaPath, "r")
		local raw = file.readAll()
		file.close()
		meta = textutils.unserialiseJSON(raw)
		songsAll[#songsAll+1] = meta
		filepathToMeta[meta.filepath] = meta
		return
	end

	local parsed = nbsTunes.parseRaw("songs/" .. filename)
	if not parsed then
		print("Failed to parse " .. filename)
		return
	end
	meta = parsed.meta
	meta.filepath = "songs/" .. filename
	meta.delay = parsed.delay

	if not meta.name or #meta.name <= 0 then
		local name = filename
		if name:find(" %- ") then
			local from, to = name:find(" %- ")
			local author = name:sub(1, from-1)
			if not meta.author or #meta.author <= 0 then
				meta.author = author
			end
			if not meta.ogauthor or #meta.ogauthor <= 0 then
				meta.ogauthor = author
			end
			name = name:sub(to+1, -1)
		end
		name = name:sub(1, -5)
		meta.name = name
	end

	local file = fs.open(metaPath, "w")
	file.write(textutils.serialiseJSON(meta))
	file.close()
	songsAll[#songsAll+1] = meta

	filepathToMeta[meta.filepath] = meta
end

for _, filename in pairs(fs.list("songs")) do
	loadSongMeta(filename)
end

print("Loaded meta for " .. #songsAll .. " songs!")

-- String indexed playlists: playlists["All"] = { id: string, filepath: "Ruins by Toby fox.nbs" }
local playlists = {}
local selectedPlaylist = "All"
local playingIndex = 1

local function loadPlaylistData()
	-- load main data
	playlists = {}
	if fs.exists("playlists.json") then
		local file = fs.open("playlists.json", "r")
		local playlistDataJSON = file.readAll()
		file.close()

		if playlistDataJSON then
			local playlistData = textutils.unserialiseJSON(playlistDataJSON)
			if playlistData then
				for name, songs in pairs(playlistData) do
					playlists[name] = songs
				end
			end
		end
	end

	-- load playlist "All"
	local playlistAll = {}
	for i = 1, #songsAll do
		local song = songsAll[i]
		playlistAll[#playlistAll+1] = {
			id = song.id,
			filepath = song.filepath,
		}
	end
	playlists["All"] = playlistAll
end
loadPlaylistData()

local function savePlaylistData()
	local playlistData = {}
	for name, songs in pairs(playlists) do
		if name ~= "All" then
			local songsNew = {}
			for i = 1, #songs do
				songsNew[i] = {
					filepath = songs[i].filepath
				}
			end
			playlistData[name] = songsNew
		end
	end

	local playlistDataJSON = textutils.serializeJSON(playlistData)

	local file = fs.open("playlists.json", "w")
	file.write(playlistDataJSON)
	file.close()
end

local themeColor = colors.yellow
local function updateThemeColor(selectedOption)
	local colorMap = {
		Red = colors.red,
		Orange = colors.orange,
		Yellow = colors.yellow,
		Lime = colors.lime,
		Green = colors.green,
		Blue = colors.blue,
		Purple = colors.purple,
		Magenta = colors.magenta,
		Pink = colors.pink,
	}
	themeColor = colorMap[selectedOption] or colors.yellow
end

local music = nil

local settingsOptions = {
	{ id = "themeColor", label = "Theme Color", options = {"Red", "Orange", "Yellow", "Lime", "Blue", "Purple", "Magenta"}, selected = 3,
		onUpdate = function(self)
			updateThemeColor(self.options[self.selected])
		end },
	{ id = "displayHalfSteps", label = "Display half steps for progress bar", value = true, onUpdate = function(self) end },
	{ id = "shuffle", label = "Shuffle playlists", value = false, onUpdate = function(self) end },

	{ filler = true },
	{ id = "globalVolume", label = "Global volume (0.0 - 3.0)", options = {"0.0", "0.01", "0.02", "0.03", "0.05", "0.1", "0.2", "0.3", "0.4", "0.5", "0.6", "0.7", "0.8", "0.9", "1.0", "1.1", "1.2", "1.3", "1.4", "1.5", "1.6", "1.7", "1.8", "1.9", "2.0", "2.1", "2.2", "2.3", "2.4", "2.5", "2.6", "2.7", "2.8", "2.9", "3.0"}, selected = 10,
		onUpdate = function(self)
			local newVolume = tonumber(self.options[self.selected]) or 1
			if not music then return end
			music:updateConfig({ volumeMultiplier = newVolume })
		end },
	{ id = "normalizeVolume", label = "Normalize peak volume to 1", value = true,
		onUpdate = function(self)
			if not music then return end
			music:updateConfig({ normalizeVolume = self.value })
		end },
	{ id = "roundToNearestTick", label = "Round delay to nearest tick", value = true,
		onUpdate = function(self)
			if not music then return end
			music:updateConfig({ roundToNearestTick = self.value })
		end },

	{ filler = true },
	{ id = "experimentalVisualizeNotes", label = "Visualizer", value = true,
		onUpdate = function(self)
			if self.value then
				initBuffer()
			end
		end },
	{ id = "visualizerThickness", label = "Note thickness", options = {"1", "2", "3", "4"}, selected = 2, onUpdate = function(self) end },
	{ id = "visualizerSpeed", label = "Scroll speed", options = {"1", "2", "3", "4", "5", "6"}, selected = 3, onUpdate = function(self) end },
}
local selectedOptionsIndex = 1
local settingValues = {}
for _, option in pairs(settingsOptions) do
	if not option.filler then
		settingValues[option.id] = option
	end
end

local function loadSettings()
	if fs.exists("settings.json") then
		local file = fs.open("settings.json", "r")
		local raw = file.readAll()
		file.close()
		local data = textutils.unserialiseJSON(raw)
		for k, option in pairs(settingsOptions) do
			if data[option.id] ~= nil then
				if option.value ~= nil then
					option.value = data[option.id]
				elseif option.options and option.selected then
					for i, opt in pairs(option.options) do
						if opt == data[option.id] then
							option.selected = i
							break
						end
					end
				end
			end
		end

		local themeSetting = settingValues["themeColor"]
		updateThemeColor(themeSetting.options[themeSetting.selected])
	end
end
loadSettings()

local function saveSettings()
	local data = {}
	for k, option in pairs(settingsOptions) do
		if option.value ~= nil then
			data[option.id] = option.value
		elseif option.options and option.selected then
			data[option.id] = option.options[option.selected]
		end
	end
	local file = fs.open("settings.json", "w")
	file.write(textutils.serialiseJSON(data))
	file.close()
end

local noteColors = {
	colors.yellow,
	colors.lime,
	colors.orange,
	colors.lightBlue,
	colors.pink,
	colors.magenta,
	colors.red,
	colors.blue,
	colors.green,
	colors.cyan,
	colors.purple,
	colors.brown,
	colors.lightGray,
	colors.gray,
}

local lastNoteTime = os.epoch("utc")
local function onPlayNote(instrumentId, velocity, note)
	if not settingValues["experimentalVisualizeNotes"].value then return end

	lastNoteTime = os.epoch("utc")

	local bufferWidth = #backgroundEffectBuffer[1]

	local semitone = note % 25
	local instrument = nbsTunes.instrumentsReverse[instrumentId] or 1
	local color = noteColors[instrument % #noteColors + 1]
	local x = semitone * 2 * (bufferWidth > SEMITONE_COUNT*2 and 2 or 1) + 1
	local thicknessSetting = settingValues["visualizerThickness"]
	local height = tonumber(thicknessSetting.options[thicknessSetting.selected])
	local width = 2 * (bufferWidth > SEMITONE_COUNT*2 and 2 or 1)
	for y = #backgroundEffectBuffer, #backgroundEffectBuffer - height + 1, -1 do
		for subX = x, x + width - 1 do
			backgroundEffectBuffer[y][subX] = color
		end
	end
end

---Scrolls up the placed pixels on the buffer
local function updateBackgroundEffect()
	local now = os.epoch("utc")
	if now - lastNoteTime > 30000 then
		return -- waste less CPU if no note has been played in 30 seconds
	end

	local moveUpBy = 1
	local bufferHeight = #backgroundEffectBuffer
	for y = 1, bufferHeight - moveUpBy do
		backgroundEffectBuffer[y] = backgroundEffectBuffer[y+moveUpBy]
	end
	for y = bufferHeight - moveUpBy + 1, bufferHeight do
		local newRow = {}
		for x = 1, #backgroundEffectBuffer[1] do
			newRow[x] = colors.black
		end
		backgroundEffectBuffer[y] = newRow
	end
end

local function loadCurrentSelected()
	local songs = playlists[selectedPlaylist]
	local song = songs[playingIndex]
	if not song then
		if music then
			music:stop()
			music = nil
		end
		return
	end
	music = nbsTunes.load(song.filepath)
	music:updateConfig({
		normalizeVolume = settingValues["normalizeVolume"].value,
		roundToNearestTick = settingValues["roundToNearestTick"].value,
		volumeMultiplier = tonumber(settingValues["globalVolume"].options[settingValues["globalVolume"].selected]) or 1,
	})
	music:onPlayNote(onPlayNote)
	os.queueEvent("musicPlay")
end
loadCurrentSelected()

local function saveSelectedPlaylist()
	local file = fs.open("selectedPlaylist.json", "w")
	file.write(textutils.serialiseJSON({
		name = selectedPlaylist,
	}))
	file.close()
end

local function loadSelectedPlaylist()
	if fs.exists("selectedPlaylist.json") then
		local file = fs.open("selectedPlaylist.json", "r")
		local raw = file.readAll()
		file.close()
		local data = textutils.unserialiseJSON(raw)

		selectedPlaylist = data.name
		playingIndex = 1
		if music then
			music:stop()
		end
		loadCurrentSelected()
	end
end

local function musicPausePlay()
	if not music then return end

	if music.playing then
		music:pause()
	else
		os.queueEvent("musicPlay")
	end
end

local function musicNextRandom()
	local oldIndex = playingIndex
	local songs = playlists[selectedPlaylist]
	playingIndex = math.random(1, #songs)
	while playingIndex == oldIndex and #songs > 1 do
		playingIndex = math.random(1, #songs)
	end
	if not music then return end
	music:stop()
	loadCurrentSelected()
end

local function musicNext()
	local songs = playlists[selectedPlaylist]
	playingIndex = (playingIndex % #songs) + 1
	if not music then return end
	music:stop()
	loadCurrentSelected()
end

local function musicPrevious()
	local songs = playlists[selectedPlaylist]
	playingIndex = ((playingIndex - 2) % #songs) + 1
	if not music then return end
	music:stop()
	loadCurrentSelected()
end

local buttonsMedia = {
	{ text = "< Prev", action = musicPrevious },
	{ text = function() return music and music.playing and "Pause" or "Play " end, action = musicPausePlay },
	{ text = "Next >", action = musicNext },
}

local function renderScrollingText(text, x, y, width, centered)
	local now = os.epoch("utc")
	local scrollSpeed = 4 -- characters per second

	-- only scroll when text doesn't fit
	if #text <= width then
		if centered then
			local startX = math.ceil(x + width/2 - #text/2)
			term.setCursorPos(startX, y)
		else
			term.setCursorPos(x, y)
		end
		term.write(text)
		return
	end

	-- scrolling text
	local offset = math.floor((now / 1000) * scrollSpeed) % (#text + 3) -- +3 for spacing between loops
	local displayText = text .. "   " .. text -- add some spacing between loops
	displayText = displayText:sub(offset + 1, offset + width)
	term.setCursorPos(x, y)
	term.write(displayText)
end

local function renderTopNowPlaying()
	local width, height = term.getSize()

	term.setBackgroundColor(colors.white)
	term.setCursorPos(1, 1)
	term.clearLine()

	term.setTextColor(themeColor)
	term.setCursorPos(1, 1)
	term.write("Playing: ")
	term.setTextColor(colors.black)

	local text = "-"

	local songs = playlists[selectedPlaylist]
	local song = songs[playingIndex]
	if song then
		local meta = filepathToMeta[song.filepath]
		local title = meta.name or "UNKNOWN TITLE"
		local author = meta.ogauthor and #meta.ogauthor > 0 and meta.ogauthor or "UNKNOWN AUTHOR"
		text = title .. " by " .. author
	end

	renderScrollingText(text, 10, 1, width - 10, false)
end

local openedMenu = nil
local currentExplorePage = 1
local currentExplorePageData = nil
local exploreSelectedIndex = 1
local exploreScroll = 0

local function loadExploreSongs(page)
	local response = http.get("https://nbw.flwc.cc/api/songs?search=&sort=recent&page=" .. page .. "&limit=20")
	if response then
		local data = textutils.unserialiseJSON(response.readAll())
		response.close()
		currentExplorePageData = data.songs
		return
	end
	currentExplorePageData = {}

	exploreSelectedIndex = 1
	exploreScroll = 0
end

local function openExploreMenu()
	openedMenu = "explore"
	currentExplorePageData = nil
	loadExploreSongs(currentExplorePage)
end

local downloadedPaths = {}
local function checkDownloaded(path)
	local cached = downloadedPaths[path]
	if cached ~= nil then return cached end
	local downloaded = fs.exists(path)
	downloadedPaths[path] = downloaded
end

local function renderExploreMenu()
	local width, height = term.getSize()

	renderTopNowPlaying()

	term.setBackgroundColor(colors.black)
	term.setTextColor(themeColor)
	term.setCursorPos(2, 3)
	term.write("Explore")
	term.setTextColor(colors.white)

	term.setTextColor(colors.gray)
	local pageText = "< Page: " .. currentExplorePage .. " >"
	term.setCursorPos(width - #pageText, 3)
	term.write(pageText)

	local freeSpaceText = formatBytes(freeSpace) .. " free"
	term.setCursorPos(width - #pageText - #freeSpaceText - 2, 3)
	term.setTextColor(colors.gray)
	term.write(freeSpaceText)

	term.setCursorPos(2, 5)
	if currentExplorePageData == nil then
		term.write("Loading...")
	elseif #currentExplorePageData == 0 then
		term.write("Failed to load songs from noteblock.world :(")
	else
		for i, song in pairs(currentExplorePageData) do
			local startY = 5 + (i - 1 - exploreScroll)*3

			if startY >= 5 and startY <= height then
				if i == exploreSelectedIndex then
					term.setTextColor(themeColor)
					term.setCursorPos(2, startY)
					term.write(">")
				end

				local title = song.title or "UNKNOWN TITLE"
				local ogAuthor = #song.originalAuthor > 0 and song.originalAuthor or "UNKNOWN AUTHOR"
				local durationSeconds = song.duration or 0
				local durationText = string.format("%d:%02d", math.floor(durationSeconds / 60), math.floor(durationSeconds % 60))
				local publicId = song.publicId or "unknown"
				local fileSize = song.nbsFileSize or 0
				local fileSizeText = string.format("%.2f", fileSize / 1024) .. " KiB" -- format as KiB with 2 decimals

				local checkPath = "songs/" .. song.nbs
				local alreadyDownloaded = checkDownloaded(checkPath)

				if alreadyDownloaded then
					term.setTextColor(colors.lightGray)
				else
					term.setTextColor(themeColor)
				end
				term.setCursorPos(4, startY)
				term.write(title)
				if alreadyDownloaded then
					term.setTextColor(colors.gray)
				else
					term.setTextColor(colors.white)
				end
				term.write(" by " .. ogAuthor)

				term.setTextColor(colors.lightGray)
				term.setCursorPos(4, startY + 1)
				term.write(durationText)
				term.setTextColor(colors.gray)
				term.write(" | " .. fileSizeText)
				term.write(" | ID: " .. publicId)
			end
		end
	end
end

local function handleEventExploreMenu(event, key, x, y)
	local width, height = term.getSize()
	local itemsVisibleOnScreenCount = math.floor((height - 4) / 3)

	local function scrollUp()
		exploreSelectedIndex = math.max(1, exploreSelectedIndex - 1)
		if itemsVisibleOnScreenCount > 0 and exploreSelectedIndex < exploreScroll + 1 then
			exploreScroll = math.max(0, exploreScroll - 1)
		end
	end
	local function scrollDown()
		exploreSelectedIndex = math.min(currentExplorePageData and #currentExplorePageData or 1, exploreSelectedIndex + 1)
		if itemsVisibleOnScreenCount > 0 and exploreSelectedIndex > exploreScroll + itemsVisibleOnScreenCount - 1 then
			exploreScroll = exploreSelectedIndex - itemsVisibleOnScreenCount + 1
		end
	end
	local function downloadSelected()
		if not currentExplorePageData then return end
		local song = currentExplorePageData[exploreSelectedIndex]
		if not song or not song.publicId then return end

		local url = song.nbsUrl
		local response = http.get(url, {}, true)
		if not response then return end
		local data = response.readAll()
		response.close()

		local filename = song.nbs
		local newPath = "songs/" .. filename
		local handle = fs.open(newPath, "wb")
		downloadedPaths[newPath] = true
		handle.write(data)
		handle.close()

		loadSongMeta(filename)
		loadPlaylistData() -- fixes allSongs being loaded into the all playlist

		selectedPlaylist = "All"
		saveSelectedPlaylist()
		local songs = playlists[selectedPlaylist]
		playingIndex = #songs
		if music then
			music:stop()
		end
		loadCurrentSelected()
		updateFreeSpace()
	end

	if event == "key" then
		if key == keys.enter or key == keys.space then
			downloadSelected()
		elseif key == keys.up then
			scrollUp()
		elseif key == keys.down then
			scrollDown()
		elseif key == keys.left then
			if currentExplorePage > 1 then
				currentExplorePage = currentExplorePage - 1
				loadExploreSongs(currentExplorePage)
				exploreScroll = 0
				exploreSelectedIndex = 1
			end
		elseif key == keys.right then
			currentExplorePage = currentExplorePage + 1
			loadExploreSongs(currentExplorePage)
			exploreScroll = 0
			exploreSelectedIndex = 1
		elseif key == keys.backspace or key == keys.tab or key == keys.grave then
			openedMenu = nil
		end
	elseif event == "mouse_scroll" then
		if key < 0 then
			scrollUp()
		elseif key > 0 then
			scrollDown()
		end
	elseif event == "mouse_click" then
		if key == 2 or key == 4 then
			openedMenu = nil
			return
		end

		if y == 3 and x >= width - 5 then
			currentExplorePage = currentExplorePage + 1
			loadExploreSongs(currentExplorePage)
			exploreScroll = 0
			exploreSelectedIndex = 1
		elseif y == 3 and x >= width - 12 then
			if currentExplorePage > 1 then
				currentExplorePage = currentExplorePage - 1
				loadExploreSongs(currentExplorePage)
				exploreScroll = 0
				exploreSelectedIndex = 1
			end
		else
			-- check if clicked on a song
			local clickedIndex = math.floor((y - 5 + 1) / 3) + 1 + exploreScroll
			if clickedIndex >= 1 and clickedIndex <= (currentExplorePageData and #currentExplorePageData or 0) then
				exploreSelectedIndex = clickedIndex
				downloadSelected()
			end
		end
	end
end

local buttonsSide = {
	{ text = "Playlists", action = function() openedMenu = "playlist" end },
	{ text = "Add to...", action = function() openedMenu = "playlistadd" end },
	{ text = "Explore", action = openExploreMenu },
	{ text = "Settings", action = function() openedMenu = "settings" end },
	{ text = "Exit", action = function() os.queueEvent("terminate") end },
}
local selectedSideButton = 1

local selectingSong = true
local playlistSongScroll = 0
local typingPlaylistName = ""
local typingNewPlaylistName = false
local renamePlaylist = false
local deletePlaylistConfirmation = false
local function renderPlaylistMenu()
	local width, height = term.getSize()

	renderTopNowPlaying()

	term.setBackgroundColor(colors.black)
	term.setTextColor(themeColor)
	term.setCursorPos(2, 3)
	term.write("Playlists")

	-- display all playlists on the left as tabs
	local playlistNameWidth = 5 + math.min(15, math.max(0, (width - 25)/4))

	local i = 1
	for name, _ in pairs(playlists) do
		term.setCursorPos(2, 4 + i)
		if selectedPlaylist == name then
			if not selectingSong then
				term.setTextColor(themeColor)
			else
				term.setTextColor(colors.white)
			end
			term.write("> ")
		else
			term.setTextColor(colors.white)
			term.write("  ")
		end

		renderScrollingText(name, 4, 4+i, playlistNameWidth, false)

		i = i + 1
	end

	local songs = playlists[selectedPlaylist]
	for j = 1, #songs do
		local y = 4 + j - playlistSongScroll

		if y >= 5 and y <= height - 1 then
			local song = songs[j]
			term.setCursorPos(5 + playlistNameWidth, y)

			local selected = playingIndex == j
			if selected then
				if selectingSong then
					term.setTextColor(themeColor)
				else
					term.setTextColor(colors.white)
				end
				term.write("> ")
			else
				term.write("  ")
			end

			local meta = filepathToMeta[song.filepath]

			local totalSeconds = (meta.length * (meta.delay or 0)) or 0
			local timeText = string.format("%d:%02d", math.floor(totalSeconds / 60), math.floor(totalSeconds % 60))

			term.setTextColor(colors.gray)
			term.write("[")
			term.setTextColor(colors.white)
			term.write(timeText)
			term.setTextColor(colors.gray)
			term.write("] ")

			term.setTextColor(themeColor)
			term.write(meta.name)

			local author = meta.ogauthor and #meta.ogauthor > 0 and meta.ogauthor or "UNKNOWN"
			term.setTextColor(colors.lightGray)
			term.write(" by " .. author)
		end
	end

	term.setTextColor(colors.white)
	if deletePlaylistConfirmation or typingNewPlaylistName then
		for y = height - 3, height do
			term.setCursorPos(1, y)
			term.clearLine()
		end
	end
	if selectedPlaylist ~= "All" then
		term.setCursorPos(2, height - 3)
		if typingNewPlaylistName or renamePlaylist then
			term.setTextColor(colors.gray)
		else
			term.setTextColor(colors.white)
		end
		if deletePlaylistConfirmation then
			term.write("Delete " .. selectedPlaylist .. "? [Y/N]")
		else
			term.write("[Del] Delete")
		end

		term.setCursorPos(2, height - 2)
		if typingNewPlaylistName or deletePlaylistConfirmation then
			term.setTextColor(colors.gray)
		else
			term.setTextColor(colors.white)
		end
		if renamePlaylist then
			term.write("Rename: " .. typingPlaylistName)
		else
			term.write("[R] Rename")
		end
	end
	term.setCursorPos(2, height - 1)
	if deletePlaylistConfirmation or renamePlaylist then
		term.setTextColor(colors.gray)
	else
		term.setTextColor(colors.white)
	end
	if typingNewPlaylistName then
		term.write("Name: " .. typingPlaylistName)
	else
		term.write("[N] New")
	end

	local freeSpaceText = formatBytes(freeSpace) .. " free"
	local selectedSong = songs[playingIndex]
	if selectedSong then
		local attributes = fs.attributes(selectedSong.filepath)
		local selectedFileSize = attributes.size
		freeSpaceText = formatBytes(selectedFileSize) .. " | " .. freeSpaceText
	end
	term.setCursorPos(width - #freeSpaceText, 3)
	term.setTextColor(colors.gray)
	term.write(freeSpaceText)
end

local function scrollPlaylist(up)
	local playlistNames = {}
	local selectedIndex = 1
	for name, _ in pairs(playlists) do
		playlistNames[#playlistNames+1] = name
		if name == selectedPlaylist then
			selectedIndex = #playlistNames
		end
	end

	if up then
		selectedIndex = math.max(1, selectedIndex - 1)
	else
		selectedIndex = math.min(#playlistNames, selectedIndex + 1)
	end

	local newSelectedPlaylist = playlistNames[selectedIndex]
	if newSelectedPlaylist ~= selectedPlaylist then
		selectedPlaylist = newSelectedPlaylist
		playingIndex = 1
		if music then
			music:stop()
		end
		loadCurrentSelected()
		saveSelectedPlaylist()
	end
end

local function handleEventPlaylistMenu(event, key, x, y)
	local songs = playlists[selectedPlaylist]
	local width, height = term.getSize()

	if typingNewPlaylistName or renamePlaylist then
		if event == "char" then
			typingPlaylistName = typingPlaylistName .. key
		elseif event == "key" then
			if key == keys.backspace then
				if #typingPlaylistName <= 0 then
					typingNewPlaylistName = false
					renamePlaylist = false
				end
				typingPlaylistName = typingPlaylistName:sub(1, -2)
			elseif key == keys.enter then
				if typingNewPlaylistName then
					typingNewPlaylistName = false
					playlists[typingPlaylistName] = {}
					playingIndex = 1
					if music then
						music:stop()
					end
				else
					-- renaming instead of new one
					renamePlaylist = false
					local songs = playlists[selectedPlaylist]
					playlists[selectedPlaylist] = nil
					playlists[typingPlaylistName] = songs
				end

				selectedPlaylist = typingPlaylistName
				savePlaylistData()
				saveSelectedPlaylist()
			end
		end
	else
		if event == "key" then
			if key == keys.backspace or key == keys.tab or key == keys.grave then
				openedMenu = nil
				return
			elseif key == keys.delete then
				if not selectingSong then
					deletePlaylistConfirmation = true
				else
					-- remove song from playlist, or if All playlist, delete it completely
					local songs = playlists[selectedPlaylist]
					if selectedPlaylist == "All" then
						local songToDelete = songs[playingIndex]
						local mainPath = songToDelete.filepath
						local metaPath = "meta/" .. mainPath:sub(7, #mainPath) .. ".json"
						for playlistName, playlistSongs in pairs(playlists) do
							for i = #playlistSongs, 1, -1 do
								local playlistSong = playlistSongs[i]
								if playlistSong.filepath == mainPath then
									table.remove(playlists[playlistName], i)
								end
							end
						end
						fs.delete(mainPath)
						if fs.exists(metaPath) then
							fs.delete(metaPath)
						end
						playingIndex = math.min(#songs, playingIndex)
						if music then
							music:stop()
						end
						loadCurrentSelected()
						savePlaylistData()
						updateFreeSpace()
					else
						table.remove(songs, playingIndex)
						playingIndex = math.min(#songs, playingIndex)
						loadCurrentSelected()
						savePlaylistData()
					end
				end
			end
		elseif event == "char" then
			if deletePlaylistConfirmation then
				if key:lower() == "y" then
					playlists[selectedPlaylist] = nil
					selectedPlaylist = "All"
					deletePlaylistConfirmation = false
					savePlaylistData()
					saveSelectedPlaylist()
				elseif key:lower() == "n" then
					deletePlaylistConfirmation = false
					return
				end
			else
				if key == "n" then
					typingNewPlaylistName = true
					typingPlaylistName = ""
					selectingSong = false
				elseif key == "r" then
					renamePlaylist = true
					typingPlaylistName = selectedPlaylist
					selectingSong = false
				end
			end
		end
	end

	if deletePlaylistConfirmation then
		return
	end

	local playingIndexBefore = playingIndex
	if event == "key" then
		if key == keys.left then
			selectingSong = false
		elseif key == keys.right then
			selectingSong = true
		end

		if selectingSong then
			if key == keys.up then
				playingIndex = math.max(1, playingIndex - 1)
			elseif key == keys.down then
				playingIndex = math.min(#songs, playingIndex + 1)
			end
		else
			if key == keys.up then
				scrollPlaylist(true)
			elseif key == keys.down then
				scrollPlaylist(false)
			end
		end
	elseif event == "mouse_scroll" then
		if selectingSong then
			if key < 0 then
				playingIndex = math.max(1, playingIndex - 1)
			else
				playingIndex = math.min(#songs, playingIndex + 1)
			end
		else
			scrollPlaylist(key < 0)
		end
	elseif event == "mouse_click" then
		if key == 2 or key == 4 then
			openedMenu = nil
			return
		end
	end

	if playingIndex ~= playingIndexBefore then
		-- changed songs
		if music then
			music:stop()
		end
		loadCurrentSelected()
	end

	local selectedSongScreenY = 4 + playingIndex - playlistSongScroll
	if selectedSongScreenY < 6 then
		playlistSongScroll = math.max(0, playingIndex - 2)
	elseif selectedSongScreenY > height - 2 then
		playlistSongScroll = playingIndex - height + 6
	end
end

local addToPlaylistIndex = 1
local function renderPlaylistAddMenu()
	local width, height = term.getSize()

	renderTopNowPlaying()

	term.setBackgroundColor(colors.black)
	term.setTextColor(themeColor)
	term.setCursorPos(2, 3)
	term.write("Playlists")

	local i = 1
	for name, songs in pairs(playlists) do
		if name ~= "All" then
			term.setCursorPos(2, 4 + i)
			if addToPlaylistIndex == i then
				term.setTextColor(themeColor)
				term.write("> ")
			else
				term.setTextColor(colors.white)
				term.write("  ")
			end

			term.write(name)
			term.setTextColor(colors.lightGray)
			term.write(" (" .. (#songs) ..  " songs)")

			local songsCurrent = playlists[selectedPlaylist]
			local currentSong = songsCurrent[playingIndex]
			local foundAt = nil
			if currentSong then
				for songPos, song in pairs(songs) do
					if song.filepath == currentSong.filepath then
						foundAt = songPos
						break
					end
				end
			end
			if foundAt then
				term.setCursorPos(width - 2, 4+i)
				term.setTextColor(themeColor)
				term.write("<<")
			end

			i = i + 1
		end
	end
end

local function handleEventPlaylistAddMenu(event, key, x, y)
	local i = 1
	local positions = {}
	for name, _ in pairs(playlists) do
		if name ~= "All" then
			positions[i] = name
			i = i + 1
		end
	end

	if event == "key" then
		if key == keys.backspace or key == keys.tab or key == keys.grave then
			openedMenu = nil
		elseif key == keys.up then
			addToPlaylistIndex = math.max(1, addToPlaylistIndex - 1)
		elseif key == keys.down then
			addToPlaylistIndex = math.min(i-1, addToPlaylistIndex + 1)
		elseif key == keys.enter then
			local addToPlaylistName = positions[addToPlaylistIndex]
			local playlistSongs = playlists[addToPlaylistName]

			local songs = playlists[selectedPlaylist]
			local currentSong = songs[playingIndex]
			if not currentSong then
				return
			end

			local foundAt = nil
			for songPos, song in pairs(playlistSongs) do
				if song.filepath == currentSong.filepath then
					foundAt = songPos
					break
				end
			end

			if not foundAt then
				playlistSongs[#playlistSongs+1] = currentSong
				savePlaylistData()
			else
				-- remove from playlist
				table.remove(playlistSongs, foundAt)
				savePlaylistData()
				if music then
					music:stop()
				end
			end
		end
	elseif event == "mouse_click" then
		if key == 2 or key == 4 then
			openedMenu = nil
			return
		end
	end
end

local function renderSettingsMenu()
	local width, height = term.getSize()

	term.setTextColor(themeColor)
	term.setCursorPos(2, 2)
	term.write("Settings")
	term.setTextColor(colors.white)

	for k, option in pairs(settingsOptions) do
		term.setCursorPos(2, 4 + k - 1)

		if not option.filler then
			if k == selectedOptionsIndex then
				term.setTextColor(themeColor)
				term.write("> ")
			else
				term.setTextColor(colors.white)
				term.write("  ")
			end

			if option.value ~= nil then
				term.write(option.label .. ": " .. (option.value and "ON" or "OFF"))
			elseif option.options and option.selected then
				term.write(option.label .. ": " .. option.options[option.selected])
			-- elseif option.text then
			-- 	local text = type(option.text) == "function" and option.text() or option.text
			-- 	term.write(option.label .. ": " .. text)
			end
		end
	end

	term.setCursorPos(2, height-1)
	term.setTextColor(colors.gray)
	term.write("Tip: drag + drop .nbs files to install")
end

local function handleEventSettingsMenu(event, key, x, y)
	if event == "key" then
		if key == keys.left then
			local option = settingsOptions[selectedOptionsIndex]
			if option.options and option.selected then
				option.selected = ((option.selected - 2) % #option.options) + 1
			elseif option.value ~= nil then
				option.value = not option.value
			end
			option:onUpdate()
			saveSettings()
		elseif key == keys.right or key == keys.enter or key == keys.space then
			local option = settingsOptions[selectedOptionsIndex]
			if option.options and option.selected then
				option.selected = (option.selected % #option.options) + 1
			elseif option.value ~= nil then
				option.value = not option.value
			end
			option:onUpdate()
			saveSettings()
		elseif key == keys.up then
			selectedOptionsIndex = math.max(1, selectedOptionsIndex - 1)
			if settingsOptions[selectedOptionsIndex].filler then
				selectedOptionsIndex = math.max(1, selectedOptionsIndex - 1)
			end
		elseif key == keys.down then
			selectedOptionsIndex = math.min(#settingsOptions, selectedOptionsIndex + 1)
			if settingsOptions[selectedOptionsIndex].filler then
				selectedOptionsIndex = math.min(#settingsOptions, selectedOptionsIndex + 1)
			end
		elseif key == keys.backspace or key == keys.tab or key == keys.grave then
			openedMenu = nil
		end
	elseif event == "mouse_click" then
		if key == 2 or key == 4 then
			openedMenu = nil
			return
		end
	end
end

local lastUpdatedVolume = 0
local function renderMain()
	local width, height = term.getSize()

	-- Background effect

	if settingValues["experimentalVisualizeNotes"].value then
		local bufferWidth = #backgroundEffectBuffer[1]
		betterblittle.drawBuffer(backgroundEffectBuffer, term, math.floor(width * 0.5 - bufferWidth*0.5 * 0.5) + 1, 1)
	end

	local songs = playlists[selectedPlaylist]
	local song = songs[playingIndex]
	local meta = song and filepathToMeta[song.filepath] or {
		name = "no songs in playlist",
		author = "",
		ogauthor = "-",
	}
	term.setTextColor(colors.white)

	local name = meta.name
	name = #name > 0 and name or "UNKNOWN TITLE"
	local ogauthor = meta.ogauthor
	ogauthor = #ogauthor > 0 and ogauthor or "UNKNOWN"

	local author = meta.author
	author = #author > 0 and author or nil

	term.setTextColor(themeColor)
	renderScrollingText(name, 2, 2, width - 2, true)

	term.setTextColor(colors.white)
	renderScrollingText("by " .. ogauthor, 2, 3, width - 2, true)

	if author then
		term.setTextColor(colors.gray)
		renderScrollingText(".nbs by " .. author, 2, 4, width - 2, true)
	end

	local buttonY = height - 2
	local totalButtonWidth = 0
	for k, button in pairs(buttonsMedia) do
		local buttonText = type(button.text) == "function" and button.text() or button.text
		totalButtonWidth = totalButtonWidth + #buttonText + 3
	end

	local currentX = math.ceil(width/2 - totalButtonWidth/2 + 1.5)
	for k, button in pairs(buttonsMedia) do
		local buttonText = type(button.text) == "function" and button.text() or button.text
		term.setCursorPos(currentX, buttonY)
		term.setTextColor(colors.white)
		term.setBackgroundColor(colors.gray)
		term.write(" " .. buttonText .. " ")
		currentX = currentX + #buttonText + 3
	end

	-- Progress bar
	local currentTick = music and music.currentTick or 0
	local totalTicks = music and music.length or 0
	local progress = totalTicks > 0 and currentTick / totalTicks or 0
	local filledWidth = width * progress + 0.5

	term.setCursorPos(1, height)
	term.setBackgroundColor(colors.gray)
	term.clearLine()

	term.setBackgroundColor(themeColor)
	term.setCursorPos(1, height)
	term.write(string.rep(" ", math.floor(filledWidth)))
	if filledWidth % 1 >= 0.5 and settingValues["displayHalfSteps"].value then
		term.setBackgroundColor(colors.gray)
		term.setTextColor(themeColor)
		term.write(string.char(149))
	end

	local totalSeconds = (totalTicks * (music and music.data.delay or 0)) or 0
	local currentSeconds = (currentTick * (music and music.data.delay or 0)) or 0
	local timeText = string.format("%d:%02d / %d:%02d", math.floor(currentSeconds / 60), math.floor(currentSeconds % 60), math.floor(totalSeconds / 60), math.floor(totalSeconds % 60))
	local startX = width - #timeText
	local yellowCharCount = math.floor(filledWidth) - startX + 1

	local textYellowBG = timeText:sub(1, math.max(0, yellowCharCount))
	local textGrayBG = timeText:sub(math.max(1, yellowCharCount + 1), #timeText)
	term.setCursorPos(startX, height)

	term.setBackgroundColor(themeColor)
	term.setTextColor(colors.black)
	term.write(textYellowBG)

	term.setBackgroundColor(colors.gray)
	term.setTextColor(colors.white)
	term.write(textGrayBG)

	-- Side buttons

	local sideButtonYStart = 7
	for k, button in pairs(buttonsSide) do
		local buttonText = type(button.text) == "function" and button.text() or button.text
		term.setCursorPos(2, sideButtonYStart + k - 1)
		term.setBackgroundColor(colors.black)
		if k == selectedSideButton then
			term.write(">")
			term.setTextColor(colors.white)
		else
			term.write(" ")
			term.setTextColor(colors.lightGray)
		end
		term.write(" " .. buttonText)
	end

	-- shuffle button

	local shuffleText = " Shuffle "
	if settingValues["shuffle"].value then
		term.setBackgroundColor(themeColor)
		term.setTextColor(colors.black)
	else
		term.setBackgroundColor(colors.gray)
		term.setTextColor(colors.lightGray)
	end
	term.setCursorPos(width - #shuffleText, height-2)
	term.write(shuffleText)

	-- volume

	local now = os.epoch("utc")
	local volumeUpdateDT = now - lastUpdatedVolume
	if volumeUpdateDT < 2000 then
		local volumeSetting = settingValues["globalVolume"]
		local selectedOption = volumeSetting.options[volumeSetting.selected]
		local volumeMultiplier = tonumber(selectedOption)

		local filledRatio = volumeMultiplier / 3
		local percentText = volumeMultiplier * 100 .. "%"

		local startY = 6
		local endY = height - 4

		local function easeOutExpo(x)
			if x >= 1 then return 1 end
			return 1 - math.pow(2, -10 * x)
		end

		local barHeight = endY - startY + 1
		local easingMultiplier = 0
		if volumeUpdateDT < 1000 then
			easingMultiplier = easeOutExpo(volumeUpdateDT / 500)
		else
			easingMultiplier = easeOutExpo((2000 - volumeUpdateDT) / 500)
		end
		startY = endY - math.ceil(barHeight * easingMultiplier) + 1

		for y = startY, endY do
			local yRatio1 = 1 - (y - startY+1) / (endY - startY+1)
			local yRatio2 = 1 - (y-1/3 - startY+1) / (endY - startY+1)
			local yRatio3 = 1 - (y-2/3 - startY+1) / (endY - startY+1)
			term.setCursorPos(width - 2, y)

			if yRatio3 < filledRatio then
				term.setBackgroundColor(themeColor)
				term.write("  ")
			elseif yRatio2 < filledRatio then
				term.setBackgroundColor(themeColor)
				term.setTextColor(colors.gray)
				term.write(string.char(0x83):rep(2))
			elseif yRatio1 < filledRatio then
				term.setBackgroundColor(themeColor)
				term.setTextColor(colors.gray)
				term.write(string.char(0x8F):rep(2))
			else
				term.setBackgroundColor(colors.gray)
				term.write("  ")
			end
		end

		if easingMultiplier > 0.75 then
			term.setTextColor(colors.white)
		elseif easingMultiplier > 0.5 then
			term.setTextColor(colors.lightGray)
		elseif easingMultiplier > 0.2 then
			term.setTextColor(colors.gray)
		else
			return
		end

		term.setBackgroundColor(colors.black)
		term.setCursorPos(width - 3 - #percentText, endY)
		term.write(percentText)
	end
end

local dragging = false
local function handleEventMain(event, key, x, y)
	local width, height = term.getSize()

	if event == "key" then
		if key == keys.left then
			musicPrevious()
		elseif key == keys.right then
			musicNext()
		elseif key == keys.space then
			musicPausePlay()
		elseif key == keys.s then
			settingValues["shuffle"].value = not settingValues["shuffle"].value
			saveSettings()
		elseif key == keys.up then
			selectedSideButton = math.max(1, selectedSideButton - 1)
		elseif key == keys.down then
			selectedSideButton = math.min(#buttonsSide, selectedSideButton + 1)
		elseif key == keys.enter then
			local button = buttonsSide[selectedSideButton]
			if button then
				button.action()
			end
		end
	elseif event == "mouse_click" then
		local buttonY = height - 2
		if y == buttonY then
			local totalButtonWidth = 0
			for k, button in pairs(buttonsMedia) do
				local buttonText = type(button.text) == "function" and button.text() or button.text
				totalButtonWidth = totalButtonWidth + #buttonText + 3
			end

			local currentX = math.ceil(term.getSize() / 2 - totalButtonWidth / 2 + 0.5)
			for k, button in pairs(buttonsMedia) do
				local buttonText = type(button.text) == "function" and button.text() or button.text
				if x >= currentX + 1 and x <= currentX + #buttonText + 2 then
					button.action()
					break
				end
				currentX = currentX + #buttonText + 3
			end

			if x >= width - 9 then
				settingValues["shuffle"].value = not settingValues["shuffle"].value
				saveSettings()
			end
		elseif y == height and music then
			local totalTicks = music.length or 0
			local clickProgress = x / width
			local newTick = math.floor(clickProgress * totalTicks + 0.5)
			music.currentTick = newTick
			dragging = true
		else
			if x <= 12 then
				local sideButtonYStart = 7 
				local buttonClicked = buttonsSide[y - sideButtonYStart + 1]
				if buttonClicked then
					buttonClicked.action()
				end
			end
		end
	elseif event == "mouse_drag" then
		if dragging and music then
			local totalTicks = music.length or 0
			local dragProgress = x / width
			local newTick = math.floor(dragProgress * totalTicks + 0.5)
			music.currentTick = newTick
		end
	elseif event == "mouse_up" then
		dragging = false
	elseif event == "mouse_scroll" then
		-- change volume
		local volumeSetting = settingValues["globalVolume"]
		if key < 0 then
			volumeSetting.selected = math.min(#volumeSetting.options, volumeSetting.selected + 1)
		elseif key > 0 then
			volumeSetting.selected = math.max(1, volumeSetting.selected - 1)
		end

		volumeSetting:onUpdate()
		saveSettings()

		local now = os.epoch("utc")
		local dt = now - lastUpdatedVolume
		if dt < 750 then
			lastUpdatedVolume = now - 250
		else
			lastUpdatedVolume = now
		end
	end
end

local win = window.create(term.current(), 1, 1, term.getSize())
local originalTerm = term.redirect(win)
local function render()
	local w1, h1 = originalTerm.getSize()
	local w2, h2 = win.getSize()
	if w1 ~= w2 or h1 ~= h2 then
		win.reposition(1, 1, w1, h1)
		initBuffer()
	end

	term.setBackgroundColor(colors.black)
	term.clear()

	if openedMenu == "playlist" then
		renderPlaylistMenu()
	elseif openedMenu == "playlistadd" then
		renderPlaylistAddMenu()
	elseif openedMenu == "settings" then
		renderSettingsMenu()
	elseif openedMenu == "explore" then
		renderExploreMenu()
	else
		renderMain()
	end

	win.setVisible(true)
	win.setVisible(false)
end

local function handleUI()
	render()
	while true do
		local event, key, x, y = os.pullEvent()

		if openedMenu == "playlist" then
			handleEventPlaylistMenu(event, key, x, y)
		elseif openedMenu == "playlistadd" then
			handleEventPlaylistAddMenu(event, key, x, y)
		elseif openedMenu == "settings" then
			handleEventSettingsMenu(event, key, x, y)
		elseif openedMenu == "explore" then
			handleEventExploreMenu(event, key, x, y)
		else
			handleEventMain(event, key, x, y)
		end

		if event == "file_transfer" then
			local files = key
			local filesTable = files.getFiles()

			if #filesTable == 0 then
				error("No files received, likely no more space left on device")
			else
				for _, file in ipairs(filesTable) do
					local filename = file.getName()
					local handle = fs.open("songs/" .. filename, "wb")
					handle.write(file.readAll())

					handle.close()
					file.close()

					loadSongMeta(filename)
				end

				selectedPlaylist = "All"
				local songs = playlists[selectedPlaylist]
				playingIndex = #songs
				music:stop()
				loadCurrentSelected()
				saveSelectedPlaylist()
			end
		end
		render()
	end
end

local function handleMusic()
	while true do
		if music then
			music:play({
				noLoops = true
			})
		end
		if music and music.finished then
			if settingValues["shuffle"].value then
				musicNextRandom()
			else
				musicNext()
			end
			sleep(0.5)
		else
			os.pullEvent("musicPlay")
		end
	end
end

local function realTimeRender()
	while true do
		render()
		if settingValues["experimentalVisualizeNotes"].value then
			updateBackgroundEffect()

			local speedSetting = settingValues["visualizerSpeed"]
			local speedMultiplier = tonumber(speedSetting.options[speedSetting.selected])
			sleep(music and music.data.delay / speedMultiplier or 0.05)
		else
			sleep(0.25)
		end
	end
end

loadSelectedPlaylist()
local function run()
	parallel.waitForAny(handleUI, handleMusic, realTimeRender)
end
local success, err = pcall(run)
term.redirect(originalTerm)

term.setBackgroundColor(colors.black)
term.clear()
term.setCursorPos(1, 1)
if success or err == "Terminated" then
	term.setTextColor(themeColor)
	print("Thanks for using NBSPlayer!")
else
	term.setTextColor(colors.red)
	print("Error:\n")
	print(err)
end
