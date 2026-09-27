===============================================================================
                    HOMEOS WEB FRAMEWORK DEVELOPER GUIDE
===============================================================================

Hay so full disclosusre im bad at documentation so i fed my code to gemini and
described how this all works and tihs is what came out....
This document covers how to create frontend web applications and optional
backend server modules for the HomeOS Rednet web system.


-------------------------------------------------------------------------------
1. FILE STRUCTURE OVERVIEW
-------------------------------------------------------------------------------

/
├── WebViewer.lua          -- Client browser program
├── ServerHost.lua         -- Server daemon & Rednet host
└── net/
    ├── share/             -- Frontend webapp scripts (served to WebViewer)
    │   ├── tower.lua
    │   └── myapp.lua
    ├── modules/           -- Backend server modules (loaded by ServerHost)
    │   └── myapp.lua      -- (Or myapp_module.lua)
    └── site_data/         -- Server-side persistent storage


-------------------------------------------------------------------------------
2. WRITING FRONTEND WEBAPPS (net/share/<appname>.lua)
-------------------------------------------------------------------------------

Frontend scripts are fetched by WebViewer.lua over Rednet and executed locally
in a sandbox canvas window.

RUNTIME ENVIRONMENT & UI CONSTRAINTS:
- Screen Coordinates: Top bar is reserved by the browser. Drawing space (term)
  starts at row 1 of the local canvas window. Mouse events (mouse_click,
  mouse_scroll, etc.) are automatically re-indexed so Y=1 corresponds to the
  top row of your canvas.
- Global API (net): Every site script has access to the injected 'net' API.

FRONTEND NET API REFERENCE:
- net.navigate(url)  : Navigates browser to 'url' (e.g. "7/chat" or "tower").
                       Fires 'webview_navigate'.
- net.addBookmark()  : Adds current URL to browser bookmarks.
- net.host           : Returns Host Computer ID serving the current site.

MINIMAL FRONTEND EXAMPLE (net/share/example.lua):

local w, h = term.getSize()
term.setBackgroundColor(colors.black)
term.clear()

term.setCursorPos(2, 2)
term.setTextColor(colors.yellow)
term.write("Welcome to My App!")

term.setCursorPos(2, 4)
term.setTextColor(colors.white)
term.write("[ Click Here to Go Home ]")

while true do
  local event, button, x, y = os.pullEvent()
  if event == "mouse_click" and button == 1 then
    if y == 4 then
      net.navigate("tower")
      return
    end
  end
end


-------------------------------------------------------------------------------
3. WRITING BACKEND SERVER MODULES (net/modules/<appname>.lua)
-------------------------------------------------------------------------------

Backend modules provide Rednet request handling and custom terminal commands.
They are ONLY loaded when the corresponding site is active in ServerHost.lua.

NAMING RULE:
If your site is net/share/chat.lua, place your module at net/modules/chat.lua
or net/modules/chat_module.lua.

MODULE ENTRY:
ServerHost loads the file with loadfile() and passes 'serverAPI' as '...'.

BACKEND SERVERAPI REFERENCE:
- api.registerPacketHandler(type, func) : Registers a handler for Rednet packets
                                           matching packetType.
- api.registerCommand(name, desc, usage, func) : Registers a terminal command
                                                 executed via ServerHost console.
- api.activeSites                      : Table containing all active sites.

CALLBACK SIGNATURES:
- Packet Handler:  function(senderID, packet)
- Command Handler: function(args)

MINIMAL BACKEND MODULE EXAMPLE (net/modules/example.lua):

local api = ...

api.registerPacketHandler("EXAMPLE_PING", function(senderID, packet)
  rednet.send(senderID, {
    type = "EXAMPLE_PONG",
    message = "Hello from backend module!"
  }, "homeos_mesh")
end)

api.registerCommand("pingtest", "Sends log to server console", "pingtest <msg>", function(args)
  local msg = args[2] or "No message"
  print("[EXAMPLE MODULE] Executed pingtest with: " .. msg)
end)


-------------------------------------------------------------------------------
4. COMMUNICATION PROTOCOL STANDARDS
-------------------------------------------------------------------------------

All mesh communication operates over protocol "homeos_mesh".

RESERVED PACKET TYPES (SYSTEM CORE):
- PING_DISCOVERY  : Client -> Broadcast
                    Payload: { type = "PING_DISCOVERY" }
- DISCOVERY_REPLY : Host -> Client
                    Payload: { type = "DISCOVERY_REPLY", hostID = <id>, hostLabel = <str>, sites = <table> }
- GET_SITE         : Client -> Host
                    Payload: { type = "GET_SITE", targetSite = <str> }
- SITE_RESPONSE    : Host -> Client
                    Payload: { type = "SITE_RESPONSE", status = 200|403|404, body = <str> }

CUSTOM WEBAPP PACKETS:
Webapps can define custom packet types using upper-case prefixes
(e.g., CHAT_GET_ROOMS, STORE_BUY_ITEM). Standardize return responses with
status or specific packet return type identifiers.
