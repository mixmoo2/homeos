
-- Made by Xella
-- Based on the following repo:
-- https://github.com/rphsoftware/oc-nbs-player/blob/master/standalone/nbs_play.lua

local customInstrumentMapping = {}
local function setCustomInstrument(filename, soundId)
	customInstrumentMapping[filename] = soundId
end

local function parse(path)
	local file = fs.open(path, "rb")
	if not file then
		error("Could not find music file: " .. path)
	end

	local nbsRaw = file:readAll()
	-- nbsRaw = string.gsub(nbsRaw, "\r", "")
	file.close()

	local seekPos = 1

	local byte = string.byte
	local blshift = bit.blshift

	local function readInteger()
		local buffer = nbsRaw:sub(seekPos, seekPos+3)
		seekPos = seekPos + 4

		if not buffer or #buffer < 4 then return nil end

		local byte1 = byte(buffer, 1)
		local byte2 = byte(buffer, 2)
		local byte3 = byte(buffer, 3)
		local byte4 = byte(buffer, 4)

		return byte1 + blshift(byte2, 8) + blshift(byte3, 16) + blshift(byte4, 24)
	end

	local function readShort()
		local buffer = nbsRaw:sub(seekPos, seekPos+1)
		seekPos = seekPos + 2

		if not buffer or #buffer < 2 then return end

		local byte1 = byte(buffer, 1)
		local byte2 = byte(buffer, 2)

		return byte1 + blshift(byte2, 8)
	end

	local function readByte()
		local buffer = nbsRaw:sub(seekPos, seekPos)
		seekPos = seekPos + 1

		if not buffer then return end

		return byte(buffer, 1)
	end

	local function readString()
		local length = readInteger()
		if length then
			local txt = nbsRaw:sub(seekPos, seekPos + length - 1)
			seekPos = seekPos + length
			txt = string.gsub(txt, "\r\n", "\n")
			return txt
		end
	end

	-- Metadata
	local song = {}
	song.zeros = readShort() -- new in version 1
	local legacy = song.zeros ~= 0
	local version = 0

	if legacy then
		song.length = song.zeros -- zeros don't exist in v0, so use those bytes for length
		song.zeros = nil
	else
		version = readByte()
		song.nbs_version = version
		song.vanilla_instrument_count = readByte()

		if version >= 3 then -- zeros replaced song length, but was added back in in v3
			song.length = readShort()
		end
	end
	song.layer_count = readShort() --- called height in legacy
	song.name = readString()
	song.author = readString()
	song.ogauthor = readString()
	song.desc = readString()
	song.tempo = readShort() or 1000
	-- if song.tempo > 10000 then song.tempo = 1000 end -- sanity check, some files have really weird tempos that cause issues
	song.auto_save = readByte()
	if not song.auto_save or song.auto_save > 1 then
		-- Auto save can only be 0 or 1, error parsing
		-- return
	end
	song.auto_save_duration = readByte()
	song.time_signature = readByte()
	song.minutes_spent = readInteger()
	song.left_clicks = readInteger()
	song.right_clicks = readInteger()
	song.note_blocks_added = readInteger()
	song.note_blocks_removed = readInteger()
	song.import_name = readString()
	if version >= 4 then
		song.loop = readByte()
		song.max_loops = readByte()
		song.loop_start_tick = readShort()
	end



	-- song.tempo is 100 * the t/s, we compute the delay (or seconds per tick) to use when playing the audio
	local ticksPerSecond = song.tempo / 100
	local delay = 1 / ticksPerSecond

	local ticks = {}
	local currenttick = -1

	local highestVelocity = 0
	local velocityCount = 0
	local velocitySum = 0

	while true do
		-- We skip by step layers ahead
		local step = readShort()

		-- A zero step means we go to the next part (which we don't need so we just ignore that)
		if step == 0 then
			break
		end

		currenttick = currenttick + step

		-- lpos is the current layer (in the internal structure, we ignore NBS's editor layers for convenience)
		local lpos = 1
		ticks[currenttick] = {}

		local currentLayer = -1
		while true do
			-- Check how big the jump from this note to the next one is
			local jump = readShort()
			currentLayer = currentLayer + jump

			-- If its zero, we should go to the next tick
			if jump == 0 then
				break
			end

			-- But if its not, we read the instrument and note number
			local inst = readByte() + 1 -- +1 so it starts at 1
			local note = readByte()
			local velocity, panning, note_block_pitch
			if not legacy then
				if version >= 4 then -- note panning, velocity and note block fine pitch added in v4
					velocity = readByte() / 100
					panning = readByte() - 100
					note_block_pitch = readShort()
				end
			end

			highestVelocity = math.max(highestVelocity, velocity or 1)
			velocityCount = velocityCount + 1
			velocitySum = velocitySum + (velocity or 1)

			-- And add them to the internal structure
			ticks[currenttick][lpos] = {
				inst = inst,
				note = note,
				velocity = velocity or 1,
				panning = panning or 0,
				fine_pitch = note_block_pitch,
				layer = currentLayer+1,
			}
			lpos = lpos + 1
		end
	end

	-- we now parse the headers
	local layers = {}
	for i = 1, song.layer_count do
		local name = readString()
		local locked, velocity, panning
		if version > 0 then
			locked = readByte()
			velocity = readByte() / 100
			panning = readByte() - 100
		end
		local layer = {
			name = name,
			locked = locked,
			velocity = velocity or 1,
			panning = panning or 0,
		}
		layers[i] = layer
	end

	for i = 0, currenttick do
		local tick = ticks[i]
		if tick then
			for j = 1, #tick do
				local sound = tick[j]
				local layerNr = sound.layer
				local layer = layers[layerNr]
				-- if not layer then return nil end
				if layer then
					sound.velocity_layer = layer.velocity
					sound.panning_layer = layer.panning
					-- print("Layer " .. layerNr .. ": " .. textutils.serialize(layer))
					-- sleep(0.05)
				else
					sound.velocity_layer = 1
					sound.panning_layer = 0
					-- print("Layer " .. layerNr .. ": " .. textutils.serialize(layer))
					-- sleep(0.5)
				end
			end
		end
	end

	-- parse custom instruments
	local customInstrumentCount = readByte()
	local customInstruments = {}
	if customInstrumentCount then
		for i = 1, customInstrumentCount do
			local name = readString()
			local file = readString()
			local pitch = readByte()
			local press_key = readByte()

			local instrument = {
				name = name,
				file = file,
				sound_id = customInstrumentMapping[file],
				pitch = pitch,
				press_key = press_key,
			}
			customInstruments[i] = instrument
		end
	end

	return {
		meta = song,
		delay = delay,
		ticks = ticks,
		finalTick = currenttick,
		layers = layers,
		customInstruments = customInstruments,
		velocity = {
			highest = highestVelocity,
			average = velocityCount > 0 and velocitySum / velocityCount or 0,
		},
	}
end

local instruments = {
	"harp", --0 = Piano (Air)
	"bass", --1 = Double Bass (Wood)
	"basedrum", --2 = Bass Drum (Stone)
	"snare", --3 = Snare Drum (Sand)
	"hat", --4 = Click (Glass)
	"guitar", --5 = Guitar (Wool)
	"flute", --6 = Flute (Clay)
	"bell", --7 = Bell (Block of Gold)
	"chime", --8 = Chime (Packed Ice)
	"xylophone", --9 = Xylophone (Bone Block)
	"iron_xylophone", --10 = Iron Xylophone (Iron Block)
	"cow_bell", --11 = Cow Bell (Soul Sand)
	"didgeridoo", --12 = Didgeridoo (Pumpkin)
	"bit", --13 = Bit (Block of Emerald)
	"banjo", --14 = Banjo (Hay)
	"pling", --15 = Pling (Glowstone)
}
local instrumentsReverse = {}
for i = 1, #instruments do
	instrumentsReverse[instruments[i]] = i
end

local octavesOffset = {
	1, --0 = Piano (Air)
	1, --1 = Double Bass (Wood)
	0, --2 = Bass Drum (Stone)
	0, --3 = Snare Drum (Sand)
	0, --4 = Click (Glass)
	2, --5 = Guitar (Wool)
	4, --6 = Flute (Clay)
	5, --7 = Bell (Block of Gold)
	5, --8 = Chime (Packed Ice)
	5, --9 = Xylophone (Bone Block)
	3, --10 = Iron Xylophone (Iron Block)
	4, --11 = Cow Bell (Soul Sand)
	1, --12 = Didgeridoo (Pumpkin)
	3, --13 = Bit (Block of Emerald)
	3, --14 = Banjo (Hay)
	3, --15 = Pling (Glowstone)
}

local function loadMusic(path, speakers)
	if not speakers then
		local found = peripheral.getNames()
		speakers = {}
		for i = 1, #found do
			if peripheral.getType(found[i]) == "speaker" then
				speakers[#speakers+1] = peripheral.wrap(found[i])
			end
		end

		if periphemu then
			local addSides = {"top"}
			for i = 1, #addSides do
				local side = addSides[i]
				local found = peripheral.wrap(side)
				if not found then
					periphemu.create(side, "speaker")
					speakers[#speakers+1] = peripheral.wrap(side)
				end
			end
		end

		if not speakers[1] then
			error("No speakers found")
		end
	end

	local rawData = parse(path)

	local music = {
		speakers = speakers,
		data = rawData,
		length = rawData.finalTick,
		playing = false,
		finished = false,
		currentTick = 0,
		loopCounter = 0,
		playDelay = rawData.delay,
	}

	local ticks = rawData.ticks

	local velocityNormalizingMultiplier = 1
	local volumeMultiplier = 1
	function music:updateConfig(config)
		if config.roundToNearestTick ~= nil then
			if config.roundToNearestTick then
				-- TODO?: Fix round better for speed (ex. 0.075 is not the middle between 0.05 and 0.1, but 0.0625, since this is the speed inverse)
				local roundedToNearestTickDelay = math.floor(self.data.delay * 20 + 0.5) / 20
				self.playDelay = roundedToNearestTickDelay
			else
				self.playDelay = self.data.delay
			end
		end
		if config.normalizeVolume ~= nil then
			if config.normalizeVolume then
				velocityNormalizingMultiplier = 1 / rawData.velocity.highest
			else
				velocityNormalizingMultiplier = 1
			end
		end
		if config.volumeMultiplier ~= nil then
			volumeMultiplier = config.volumeMultiplier
		end
	end

	local function onPlayNote(instrument, velocity, note) end

	---Set the onPlayNote callback
	---@param func fun(instrumentId: number, velocity: number, note: number)
	function music:onPlayNote(func)
		onPlayNote = func
	end

	---Plays music
	---@param settings { noLoops: boolean }
	function music:play(settings)
		self.playing = true

		local allowLooping = not (settings and settings.noLoops)

		local function playNote(instrument, velocity, note)
			for i = 1, #self.speakers do
				self.speakers[i].playNote(instrument, velocity, note)
			end
			onPlayNote(instrument, velocity, note)
		end

		local function playSound(soundId, velocity, note)
			for i = 1, #self.speakers do
				self.speakers[i].playSound(soundId, velocity, note)
			end
		end

		local function playTick(tick)
			for j = 1, #tick do
				local sound = tick[j]
				local inst = sound.inst
				local octOffset = octavesOffset[inst] or 4
				local velocity = sound.velocity * sound.velocity_layer * velocityNormalizingMultiplier * volumeMultiplier

				local note = (sound.note - 9 - (octOffset-1)*12)
				if note > 24 then
					if note % 12 == 0 then
						note = 24
					else
						note = note % 12 + 12
					end
				elseif note < 0 then
					note = note % 12
				end

				if inst <= 16 then
					local instrument = instruments[inst]
					playNote(instrument, velocity, note)
				else
					local instrument = rawData.customInstruments[inst - 16].sound_id
					if instrument then
						playSound(instrument, velocity, note)
					end
				end
			end
		end

		local length = self.length
		local function playMusic()
			while true do
				local tick = ticks[self.currentTick]
				if tick then playTick(tick) end

				local found = false
				local waitTicks = 0
				for j = self.currentTick+1, length do
					if ticks[j] then
						found = true
						waitTicks = j - self.currentTick
						self.currentTick = j
						break
					end
				end
				if not found then
					-- music ends
					if rawData.meta.loop == 1 and allowLooping then
						-- figure out loop stuff
						if rawData.meta.max_loops > 0 and self.loopCounter >= rawData.meta.max_loops then
							-- looped enough, so stop
							self.loopCounter = 0
							self.currentTick = 0
							break
						else
							-- loop another time
							self.currentTick = rawData.meta.loop_start_tick
							self.loopCounter = self.loopCounter + 1
						end
					else
						music.finished = true
						return -- stop playing
					end
				end

				sleep(music.playDelay * waitTicks)
			end
		end

		parallel.waitForAny(playMusic, function()
			os.pullEvent("musicPause")
		end)

		-- music stopped playing
		self.playing = false
	end

	function music:pause()
		self.playing = false
		os.queueEvent("musicPause")
	end

	function music:reset()
		self.currentTick = 0
		self.loopCounter = 0
	end

	function music:stop()
		self:pause()
		self:reset()
	end

	return music
end

return {
	parseRaw = parse,
	load = loadMusic,
	setCustomInstrument = setCustomInstrument,
	instruments = instruments,
	instrumentsReverse = instrumentsReverse,
}
