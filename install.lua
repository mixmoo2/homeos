local repo = "https://raw.githubusercontent.com/mixmoo2/homeos/main/"

local files = {
  "startup.lua",
  "core/home.lua",
  "core/super.lua",
  "core/bfg.lua",
  "core/calculator.lua",
  "core/imagecopy.lua",
  "core/play.lua",
  "core/nbsTunes.lua",
  "core/print.lua",
  "core/betterblittle.lua",
  "core/ServerHost.lua",
  "core/WebViewer.lua",
  "net/config.txt",
  "net/read_me_to_program_the_web.txt",
  "net/share/tower.lua",
  "net/share/chat.lua",
  "net/share/host_info.txt",
  "net/modules/chat_module.lua"
}

print("Installing HomeOS...")

for _, path in ipairs(files) do
  print("Downloading: " .. path)
  local dir = fs.getDir(path)
  if dir ~= "" and not fs.exists(dir) then
    fs.makeDir(dir)
  end
  
  sleep(0.2)
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
