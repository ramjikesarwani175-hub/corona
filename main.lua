-- main.lua
display.setStatusBar(display.HiddenStatusBar)
local physics = require("physics")
physics.start()
physics.setGravity(0,0)

local Player = require("player")
local Enemy  = require("enemy")

local centerX, centerY = display.contentCenterX, display.contentCenterY
local w,h = display.contentWidth, display.contentHeight

-- background (simple)
local bg = display.newRect(centerX, centerY, w, h)
bg:setFillColor(0.08,0.08,0.1)

-- HUD
local score = 0
local scoreText = display.newText({text="Score: 0", x=60, y=30, fontSize=20, align="left"})

-- create player
local player = Player.new(centerX, centerY)

-- group for bullets/enemies
local bulletsGroup = display.newGroup()
local enemiesGroup = display.newGroup()

-- spawn enemies periodically
local spawnTimer = timer.performWithDelay(1500, function()
    local ex = math.random(50, w-50)
    local ey = math.random(50, h-50)
    local e = Enemy.new(ex,ey)
    enemiesGroup:insert(e.view)
    e:startAI(player)
end, 0)

-- bullet handling
local function onBulletHit(self, event)
    if event.other.type == "enemy" then
        -- remove enemy
        display.remove(event.other)
        display.remove(self)
        score = score + 10
        scoreText.text = "Score: "..score
    end
    return true
end

-- attach bullet creation to player.fire()
player.onFire = function(bx,by, vx,vy)
    local bullet = display.newCircle(bulletsGroup, bx, by, 6)
    bullet:setFillColor(1,0.8,0)
    physics.addBody(bullet, "dynamic", {isSensor=true})
    bullet.isBullet = true
    bullet.gravityScale = 0
    bullet.type = "bullet"
    bullet:setLinearVelocity(vx*700, vy*700)
    bullet.collision = onBulletHit
    bullet:addEventListener("collision")
    timer.performWithDelay(2000, function() display.remove(bullet) end)
end

-- touch joystick: left half move, right half tap to shoot
local touchId = nil
local moveRadius = 70
local joystick = display.newCircle(80, h-100, 40)
joystick.alpha = 0.15

local knob = display.newCircle(joystick.x, joystick.y, 20)
knob.alpha = 0.35

local function onTouch(event)
    if event.phase == "began" or event.phase == "moved" then
        if event.x <= w*0.5 then
            -- move area
            local dx = event.x - joystick.x
            local dy = event.y - joystick.y
            local dist = math.sqrt(dx*dx+dy*dy)
            if dist > moveRadius then
                dx = dx / dist * moveRadius
                dy = dy / dist * moveRadius
            end
            knob.x = joystick.x + dx
            knob.y = joystick.y + dy
            local nx, ny = dx / moveRadius, dy / moveRadius
            player:setMove(nx, ny)
        else
            -- right half: shoot towards touch
            local px,py = player:getPos()
            local dx = event.x - px
            local dy = event.y - py
            local len = math.max(1, math.sqrt(dx*dx + dy*dy))
            player:fire(px,py, dx/len, dy/len)
        end
    elseif event.phase == "ended" or event.phase == "cancelled" then
        if event.x <= w*0.5 then
            knob.x = joystick.x
            knob.y = joystick.y
            player:setMove(0,0)
        end
    end
    return true
end

Runtime:addEventListener("touch", onTouch)

-- enemy vs player collision
local function onPlayerCollision(self, event)
    if event.phase == "began" and event.other.type == "enemy" then
        -- simple hit: decrease score and remove enemy
        score = math.max(0, score - 5)
        scoreText.text = "Score: "..score
        display.remove(event.other)
    end
    return true
end
player.view.collision = onPlayerCollision
player.view:addEventListener("collision")
-- player.lua
local physics = require("physics")
local M = {}

local PLAYER_SPEED = 180

function M.new(x,y)
    local view = display.newCircle(x,y,18)
    view:setFillColor(0.2,0.6,1)
    physics.addBody(view, "dynamic", {radius=18})
    view.gravityScale = 0
    view.isFixedRotation = true
    view.type = "player"

    local vx, vy = 0,0

    local obj = { view = view, vx = 0, vy = 0 }

    function obj:setMove(nx, ny)
        self.vx = nx * PLAYER_SPEED
        self.vy = ny * PLAYER_SPEED
    end

    function obj:getPos()
        return self.view.x, self.view.y
    end

    function obj:fire(bx,by, dx,dy)
        if self.onFire then
            self.onFire(bx + dx*30, by + dy*30, dx, dy)
        end
    end

    local function enterFrame()
        if view.removeSelf == nil then
            Runtime:removeEventListener("enterFrame", enterFrame)
            return
        end
        view:setLinearVelocity(obj.vx, obj.vy)
        -- clamp to screen
        local w,h = display.contentWidth, display.contentHeight
        view.x = math.max(20, math.min(w-20, view.x))
        view.y = math.max(20, math.min(h-20, view.y))
    end
    Runtime:addEventListener("enterFrame", enterFrame)

    return obj
end

return M
-- enemy.lua
local physics = require("physics")
local M = {}

function M.new(x,y)
    local rect = display.newRect(x,y,28,28)
    rect:setFillColor(1,0.3,0.3)
    physics.addBody(rect, "dynamic", {isSensor=false})
    rect.gravityScale = 0
    rect.type = "enemy"
    rect.isFixedRotation = true
    rect:setLinearVelocity(0,0)

    local obj = { view = rect }

    function obj:startAI(target)
        -- simple homing movement
        local function ai()
            if rect.removeSelf == nil or target.view.removeSelf == nil then
                Runtime:removeEventListener("enterFrame", ai)
                return
            end
            local dx = target.view.x - rect.x
            local dy = target.view.y - rect.y
            local dist = math.sqrt(dx*dx+dy*dy)
            if dist > 1 then
                local nx, ny = dx/dist, dy/dist
                rect:setLinearVelocity(nx*90, ny*90)
            end
        end
        Runtime:addEventListener("enterFrame", ai)
    end

    return obj
end

return M
