local repo = "https://raw.githubusercontent.com/mix.moo2/homeos/main/"

local files = {
  "startup.lua",
  "user_guide.txt",
  "zreadmeMain.text",
  "core/LICENSE",
  "core/READMEplay.md",
  "core/ServerHost.lua",
  "core/WebViewer.lua",
  "core/betterblittle.lua",
  "core/bfg.lua",
  "core/calculator.lua",
  "core/home.lua",
  "core/imagecopy.lua",
  "core/nbsTunes.lua",
  "core/play.lua",
  "core/print.lua",
  "core/super.lua",
  "games/kimith.lua",
  "net/config.txt",
  "net/read_me_to_program_the_web.txt",
  "net/modules/chat_module.lua",
  "net/share/chat.lua",
  "net/share/tower.lua"
}

local dirs = {
  "net/cookies",
  "net/site_data/tower",
  "user_files/calcprograms"
}

print("Installing HomeOS...")

for _, dir in ipairs(dirs) do
  if not fs.exists(dir) then
    fs.makeDir(dir)
  end
end

for _, path in ipairs(files) do
  print("Downloading: " .. path)
  local dir = fs.getDir(path)
  if dir ~= "" and not fs.exists(dir) then
    fs.makeDir(dir)
  end
  
  sleep(0.1)
  local response = http.get(repo .. path)
  if response then
    local file = fs.open(path, "w")
    file.write(response.readAll())
    file.close()
    response.close()
  else
    print("Error downloading: " .. path)
  end
end

print("Installation complete! Run 'reboot' or 'startup.lua' to launch.")
