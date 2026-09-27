local printer = peripheral.find("printer") or printError("no printer detected")
shell.aliases(shell.getRunningProgram(),"print")
F = nil
repeat 
if printer.getPaperLevel() == 0 then 
printError("printer needs paper")
end
if printer.getInkLevel() == 0 then
printError("printer needs ink")
end
print("what file wuld you like to print?")
F = read()
if fs.exists(F) then
print("title?")
local ti = read()
print("file printing")
local file = fs.open(F,"r")
local lineC = 1
printer.newPage()
printer.setPageTitle(ti .. " page1")
local line = file.readLine()
local P = 2
while line do
if lineC > 21 then
printer.newPage()
lineC = 1
printer.setPageTitle(ti.." page:"..P)
P = P+1
os.sleep(.5)
end
printer.setCursorPos(1,lineC)
printer.write(line)
lineC = lineC +1
line = file.readLine()
end
file.close()
printer.endPage()
print("complet")
else 
print("no file fond")
end
until oror == "stop"
