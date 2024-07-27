local enet = require("enet")
local host
local peer
local connected = false
local isServer = false
local lastReceived = 0
local checkInterval = 1 -- Check connection every 1 second
local timeoutDuration = 5 -- Consider disconnected after 5 seconds of no activity

local mouseX, mouseY = 0, 0
local remoteX, remoteY = 0, 0

local shaderCode = [[
    extern number time;
    vec4 effect(vec4 color, Image texture, vec2 texture_coords, vec2 screen_coords) {
        vec4 pixel = Texel(texture, texture_coords);
        float r = 0.5 + 0.5 * cos(screen_coords.x * 0.1 + time);
        float g = 0.5 + 0.5 * cos(screen_coords.y * 0.1 + time + 2.0);
        float b = 0.5 + 0.5 * cos((screen_coords.x + screen_coords.y) * 0.1 + time + 4.0);
        return vec4(r, g, b, 1.0) * pixel;
    }
]]
local shader
local clickSound
local bgMusic

function love.load(arg)
    if arg[1] == "server" then
        host = enet.host_create("localhost:6789")
        isServer = true
        print("Server started, waiting for connections...")
    else
        host = enet.host_create()
        peer = host:connect("localhost:6789")
        print("Client started, attempting to connect...")
    end

    -- Load shader
    shader = love.graphics.newShader(shaderCode)

    -- Load sounds
    clickSound = love.audio.newSource("happy.flac", "static")
    bgMusic = love.audio.newSource("sound.mp3", "stream")
    bgMusic:setLooping(true)
    bgMusic:play()
end

function love.update(dt)
    if host then
        local event = host:service(0)
        while event do
            if event.type == "connect" then
                print("Connected to", event.peer)
                connected = true
                peer = event.peer
                lastReceived = love.timer.getTime()
            elseif event.type == "disconnect" then
                print("Disconnected from", event.peer)
                connected = false
                peer = nil
            elseif event.type == "receive" then
                local receivedX, receivedY = event.data:match("(%d+),(%d+)")
                if receivedX and receivedY then
                    remoteX, remoteY = tonumber(receivedX), tonumber(receivedY)
                    lastReceived = love.timer.getTime()
                end
            end
            event = host:service(0)
        end
    end

    -- Update local mouse position
    mouseX, mouseY = love.mouse.getPosition()

    -- Send mouse position
    if connected then
        peer:send(string.format("%d,%d", mouseX, mouseY))
    end

    -- Check for timeout
    if connected and love.timer.getTime() - lastReceived > timeoutDuration then
        print("Connection timed out")
        connected = false
        if peer then
            peer:disconnect_now()
            peer = nil
        end
    end

    -- Update shader time
    shader:send("time", love.timer.getTime())
end

function love.draw()
    love.graphics.setShader(shader)
    love.graphics.rectangle("fill", 0, 0, love.graphics.getWidth(), love.graphics.getHeight())
    love.graphics.setShader()

    love.graphics.print(isServer and "Server" or "Client", 10, 10)
    love.graphics.print(connected and "Connected" or "Not connected", 10, 30)

    -- Draw local square
    love.graphics.setColor(isServer and 1 or 0, 0, isServer and 0 or 1)
    love.graphics.rectangle("fill", mouseX - 25, mouseY - 25, 50, 50)

    -- Draw remote square
    if connected then
        love.graphics.setColor(isServer and 0 or 1, 0, isServer and 1 or 0)
        love.graphics.rectangle("fill", remoteX - 25, remoteY - 25, 50, 50)
    end

    -- Reset color
    love.graphics.setColor(1, 1, 1)
end

function love.mousepressed(x, y, button, istouch, presses)
    if button == 1 then -- Left mouse button
        clickSound:play()
    end
end

function love.keypressed(key)
    if key == "d" and connected then
        peer:disconnect()
        print("Initiating disconnect...")
    end
end

function love.quit()
    if peer then
        peer:disconnect_now()
    end
    if host then
        host:flush()
    end
end
