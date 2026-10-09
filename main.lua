-- Состояния игры: "menu", "levels", "shop", "playing", "pause", "gameover_delay"
local gameState = "menu"

-- Данные профиля игрока (деньги, открытые скины)
local playerData = {
    coins = 0,
    currentSkin = "red",
    unlockedSkins = { red = true, yellow = false, glitch = false, black = false, square = false }
}

-- Настройки магазина
local shopItems = {
    { id = "yellow", name = "Жёлтый скин", price = 15, color = {1, 0.9, 0} },
    { id = "glitch", name = "Глитч скин", price = 30, color = {0.7, 0, 1} },
    { id = "black",  name = "Чёрный скин", price = 40, color = {0.1, 0.1, 0.1} },
    { id = "square", name = "Квадрат-скин", price = 60, color = {1, 0.2, 0.2} }
}

-- Настройки уровней
local currentLevel = 1
local maxLevels = 30
local levelTimer = 0
local levelDuration = 15

-- Настройки орбит
local screenCenterX, screenCenterY
local orbits = { 90, 140, 190, 240 }

-- Данные игрока на поле
local player = {
    angle = 0,
    speed = 2.5,
    currentOrbitIndex = 2,
    radius = 12,
    x = 0, y = 0
}

-- Списки объектов
local stars, bgSquares, enemies = {}, {}, {}
local spawnTimer = 0
local buttons = {}
local gameFont
local backgroundMusic

-- Система взрыва (частицы)
local particles = {}
local gameOverTimer = 0
local gameOverDuration = 1.0 -- задержка перед выходом в меню после смерти (1 секунда)

-- ФУНКЦИЯ СОХРАНЕНИЯ ИГРЫ
local function saveGame()
    local saveString = string.format("%d,%s,%s,%s,%s,%s", 
        playerData.coins,
        playerData.currentSkin,
        playerData.unlockedSkins.yellow and "true" or "false",
        playerData.unlockedSkins.glitch and "true" or "false",
        playerData.unlockedSkins.black and "true" or "false",
        playerData.unlockedSkins.square and "true" or "false"
    )
    love.filesystem.write("savegame.txt", saveString)
end

-- ФУНКЦИЯ ЗАГРУЗКИ ИГРЫ
local function loadGame()
    if love.filesystem.getInfo("savegame.txt") then
        local data, size = love.filesystem.read("savegame.txt")
        if data then
            local values = {}
            for val in string.gmatch(data, "[^,]+") do
                table.insert(values, val)
            end
            if #values >= 6 then
                playerData.coins = tonumber(values) or 0
                playerData.currentSkin = values
                playerData.unlockedSkins.yellow = (values == "true")
                playerData.unlockedSkins.glitch = (values == "true")
                playerData.unlockedSkins.black = (values == "true")
                playerData.unlockedSkins.square = (values == "true")
            end
        end
    end
end

-- Вспомогательная функция для создания кнопок
local function drawButton(id, text, x, y, w, h, r, g, b)
    buttons[id] = {x = x, y = y, w = w, h = h}
    love.graphics.setColor(r, g, b, 0.3)
    love.graphics.rectangle("fill", x, y, w, h, 6, 6)
    love.graphics.setColor(r, g, b, 1)
    love.graphics.rectangle("line", x, y, w, h, 6, 6)
    love.graphics.setColor(1, 1, 1, 0.9)
    love.graphics.printf(text, x, y + h/2 - 8, w, "center")
end

-- Функция запуска конкретного уровня
local function startLevel(lvl)
    currentLevel = lvl
    gameState = "playing"
    levelTimer = 0
    spawnTimer = 0
    enemies = {}
    particles = {}
    player.currentOrbitIndex = 2
    player.angle = 0
end

-- Функция генерации взрыва из частиц
local function triggerExplosion(x, y)
    particles = {}
    -- Создаем 40 частиц, летящих в разные стороны
    for i = 1, 40 do
        local angle = math.random() * math.pi * 2
        local speed = math.random(80, 240)
        table.insert(particles, {
            x = x,
            y = y,
            vx = math.cos(angle) * speed,
            vy = math.sin(angle) * speed,
            size = math.random(3, 6),
            alpha = 1.0,
            fadeSpeed = math.random(15, 25) / 10 -- скорость затухания
        })
    end
end

-- Функция создания врагов
local function spawnEnemy()
    local baseSpeed = 150 + (currentLevel * 12)
    table.insert(enemies, {
        x = 850, y = math.random(100, 500),
        speedX = -math.random(baseSpeed - 30, baseSpeed + 30),
        size = 20, rotation = math.random()*math.pi, rotSpeed = math.random(-2, 2),
        isGlitch = (math.random(1, 10) > 7), glitchTimer = 0, glitchInterval = math.random(1, 2), isGlitchingVisible = false
    })
end

function love.load()
    love.window.setTitle("Red Orbit 2: Full System")
    love.window.setMode(800, 600)
    screenCenterX, screenCenterY = 400, 300
    
    -- Загрузка шрифта
    local fontName = "impact.ttf"
    if love.filesystem.getInfo(fontName) then
        gameFont = love.graphics.newFont(fontName, 16)
        love.graphics.setFont(gameFont)
    end
    
    -- Музыка
    local musicFile = "bg_music.mp3"
    if love.filesystem.getInfo(musicFile) then
        backgroundMusic = love.audio.newSource(musicFile, "stream")
        backgroundMusic:setLooping(true)
        backgroundMusic:setVolume(0.4)
        backgroundMusic:play()
    end
    
    -- Генерация космического фона
    for i = 1, 60 do table.insert(stars, { angle = math.random()*math.pi*2, distance = math.random(10, 500), speed = math.random(40, 120), size = math.random(1, 2) }) end
    for i = 1, 10 do table.insert(bgSquares, { x = math.random(0, 800), y = math.random(0, 600), size = math.random(20, 50), speed = math.random(15, 30), alpha = math.random(3, 10)/100, rotation = math.random()*math.pi }) end

    loadGame()
end

function love.update(dt)
    -- Обновление фонового космоса
    for i = 1, #stars do
        local s = stars[i]
        s.distance = s.distance + s.speed * dt
        if s.distance > 600 then s.distance = 10 s.angle = math.random()*math.pi*2 end
    end
    for i = 1, #bgSquares do
        local sq = bgSquares[i]
        sq.y = sq.y - sq.speed * dt
        sq.rotation = sq.rotation + 0.2 * dt
        if sq.y < -sq.size then sq.y = 600 + sq.size sq.x = math.random(0, 800) end
    end

    -- Обновление физики частиц взрыва (если они есть)
    for i = #particles, 1, -1 do
        local p = particles[i]
        p.x = p.x + p.vx * dt
        p.y = p.y + p.vy * dt
        p.alpha = p.alpha - p.fadeSpeed * dt
        if p.alpha <= 0 then
            table.remove(particles, i)
        end
    end

    -- Режим задержки после смерти (пока разлетаются частицы)
    if gameState == "gameover_delay" then
        gameOverTimer = gameOverTimer + dt
        if gameOverTimer >= gameOverDuration then
            enemies = {}
            gameState = "levels" -- возвращаемся в меню уровней
        end
        return
    end

    -- Обновление активного геймплея
    if gameState == "playing" then
        levelTimer = levelTimer + dt
        
        -- ПОБЕДА НА УРОВНЕ
        if levelTimer >= levelDuration then
            playerData.coins = playerData.coins + 15
            saveGame()
            gameState = "levels"
            enemies = {}
            return
        end

        player.angle = player.angle + player.speed * dt
        player.x = screenCenterX + math.cos(player.angle) * orbits[player.currentOrbitIndex]
        player.y = screenCenterY + math.sin(player.angle) * orbits[player.currentOrbitIndex]
        
        local currentSpawnInterval = math.max(1.0 - (currentLevel * 0.02), 0.4)
        spawnTimer = spawnTimer + dt
        if spawnTimer >= currentSpawnInterval then spawnTimer = 0 spawnEnemy() end
        
        for i = #enemies, 1, -1 do
            local e = enemies[i]
            e.x = e.x + e.speedX * dt
            e.rotation = e.rotation + e.rotSpeed * dt
            
            if e.isGlitch then
                e.glitchTimer = e.glitchTimer + dt
                e.isGlitchingVisible = (e.glitchTimer >= e.glitchInterval - 0.3) and (math.random() > 0.5)
                if e.glitchTimer >= e.glitchInterval then e.glitchTimer = 0 e.x = e.x - 80 end
            end
            
            local dist = math.sqrt((player.x - e.x)^2 + (player.y - e.y)^2)
            
            -- СТОЛКНОВЕНИЕ (ИГРОК УМЕР)
            if dist < (player.radius + e.size / 2) then
                triggerExplosion(player.x, player.y) -- запускаем взрыв на месте игрока!
                gameState = "gameover_delay"       -- включаем таймер задержки
                gameOverTimer = 0
                return
            end
            if e.x < -50 then table.remove(enemies, i) end
        end
    end
end

function love.draw()
    love.graphics.clear(0.02, 0.02, 0.05)
    
    -- Отрисовка фона
    for i = 1, #bgSquares do
        local sq = bgSquares[i]
        love.graphics.setColor(0, 0.6, 1, sq.alpha)
        love.graphics.push() love.graphics.translate(sq.x, sq.y) love.graphics.rotate(sq.rotation)
        love.graphics.rectangle("line", -sq.size/2, -sq.size/2, sq.size, sq.size)
        love.graphics.pop()
    end
    love.graphics.setColor(1, 1, 1, 0.6)
    for i = 1, #stars do
        local s = stars[i]
        love.graphics.circle("fill", screenCenterX + math.cos(s.angle)*s.distance, screenCenterY + math.sin(s.angle)*s.distance, s.size)
    end

    buttons = {} 

    if gameState == "menu" then
        love.graphics.setColor(0, 0.9, 1, 1)
        love.graphics.printf("RED ORBIT 2", 0, 100, 800, "center")
        drawButton("btn_levels", "ВЫБОР УРОВНЕЙ", 280, 240, 240, 50, 0, 0.8, 1)
        drawButton("btn_shop", "МАГАЗИН СКИНОВ", 280, 310, 240, 50, 1, 0.6, 0)
        love.graphics.setColor(1, 1, 1, 0.5)
        love.graphics.printf("Монет: " .. playerData.coins, 0, 400, 800, "center")

    elseif gameState == "levels" then
        love.graphics.setColor(0, 0.9, 1, 1)
        love.graphics.printf("ВЫБОР СЕКТОРА (1-30)", 0, 40, 800, "center")
        
        local startX, startY, btnW, btnH, spacing = 110, 100, 50, 40, 12
        for i = 1, maxLevels do
            local col = (i - 1) % 10
            local row = math.floor((i - 1) / 10)
            local bx = startX + col * (btnW + spacing)
local by = startY + row * (btnH + spacing)
drawButton("lvl_" .. i, tostring(i), bx, by, btnW, btnH, 0, 0.5, 0.9)
end
drawButton("btn_back", "НАЗАД", 20, 530, 120, 40, 1, 0.3, 0.3)
love.graphics.setColor(1, 1, 1, 0.6)
love.graphics.print("Баланс: " .. playerData.coins .. " $", 630, 545)
elseif gameState == "shop" then
love.graphics.setColor(1, 0.7, 0, 1)
love.graphics.printf("СИСТЕМНЫЙ МАГАЗИН СКИНОВ", 0, 40, 800, "center")
love.graphics.printf("Твой баланс: " .. playerData.coins .. " монет", 0, 70, 800, "center")
for i, item in ipairs(shopItems) do
local yOffset = 130 + (i - 1) * 85
love.graphics.setColor(item.color)
if item.id == "square" then love.graphics.rectangle("fill", 100, yOffset + 10, 24, 24) else love.graphics.circle("fill", 112, yOffset + 22, 12) end
love.graphics.setColor(1, 1, 1)
love.graphics.print(item.name .. " — Цена: " .. item.price, 150, yOffset + 15)
if playerData.currentSkin == item.id then
drawButton("equip_" .. item.id, "АКТИВЕН", 540, yOffset, 160, 40, 0, 0.9, 0.4)
elseif playerData.unlockedSkins[item.id] then
drawButton("equip_" .. item.id, "НАДЕТЬ", 540, yOffset, 160, 40, 0.2, 0.6, 1)
else
if playerData.coins >= item.price then
drawButton("buy_" .. item.id, "КУПИТЬ", 540, yOffset, 160, 40, 1, 0.4, 0)
else
drawButton("buy_" .. item.id, "НЕДОСТАТУЧНО", 540, yOffset, 160, 40, 0.4, 0.4, 0.4)
end
end
end
drawButton("btn_back", "В МЕНЮ", 20, 530, 140, 40, 1, 0.3, 0.3)
-- ОТРИСОВКА ИГРЫ ИЛИ ЗАДЕРЖКИ СМЕРТИ
elseif gameState == "playing" or gameState == "gameover_delay" then
-- Орбиты
for i, radius in ipairs(orbits) do
love.graphics.setColor(i == player.currentOrbitIndex and {0, 0.9, 1, 0.9} or {0, 0.4, 0.6, 0.2})
love.graphics.circle("line", screenCenterX, screenCenterY, radius)
end
-- Враги
for i = 1, #enemies do
local e = enemies[i]
love.graphics.push() love.graphics.translate(e.x, e.y) love.graphics.rotate(e.rotation)
love.graphics.setColor(e.isGlitch and (e.isGlitchingVisible and {0.9, 0, 0.9} or {0.5, 0, 0.8}) or {1, 0.5, 0})
love.graphics.rectangle("fill", -e.size/2, -e.size/2, e.size, e.size)
love.graphics.pop()
end
-- Отрендерить игрока (только если он ещё жив)
if gameState == "playing" then
local s = playerData.currentSkin
if s == "red" then love.graphics.setColor(1, 0.2, 0.2)
elseif s == "yellow" then love.graphics.setColor(1, 0.9, 0)
elseif s == "black" then love.graphics.setColor(0.1, 0.1, 0.1)
elseif s == "glitch" then love.graphics.setColor(math.random()>0.5 and {0.7,0,1} or {0,0.9,1}) end
if s == "square" then
love.graphics.setColor(1, 0.2, 0.2) love.graphics.rectangle("fill", player.x - 12, player.y - 12, 24, 24)
else
love.graphics.circle("fill", player.x, player.y, player.radius)
end
end
-- ОТРИСОВКА ЭФФЕКТА ЧАСТИЦ ВЗРЫВА
for i = 1, #particles do
local p = particles[i]
-- Частицы красятся под цвет активного скина игрока
local s = playerData.currentSkin
if s == "yellow" then love.graphics.setColor(1, 0.9, 0, p.alpha)
elseif s == "black" then love.graphics.setColor(0.3, 0.3, 0.3, p.alpha)
elseif s == "glitch" then love.graphics.setColor(0.7, 0, 1, p.alpha)
else love.graphics.setColor(1, 0.2, 0.2, p.alpha) end -- стандартный красный взрыв
love.graphics.rectangle("fill", p.x - p.size/2, p.y - p.size/2, p.size, p.size)
end
love.graphics.setColor(1, 1, 1, 0.8)
love.graphics.print("УРОВЕНЬ: " .. currentLevel, 20, 20)
love.graphics.print("СТАБИЛИЗАЦИЯ: " .. string.format("%.1f", math.max(0, levelDuration - levelTimer)) .. "с", 20, 45)
if gameState == "playing" then
drawButton("btn_pause", "ПАУЗА", 680, 20, 100, 35, 1, 0.2, 0.2)
end
elseif gameState == "pause" then
love.graphics.setColor(0, 0, 0, 0.7)
love.graphics.rectangle("fill", 0, 0, 800, 600)
love.graphics.setColor(1, 0.3, 0.3, 1)
love.graphics.printf("СИСТЕМА НА ПАУЗЕ", 0, 180, 800, "center")
drawButton("btn_resume", "ПРОДОЛЖИТЬ", 280, 260, 240, 50, 0, 0.8, 1)
drawButton("btn_exit", "ВЫЙТИ В МЕНЮ", 280, 330, 240, 50, 1, 0.3, 0.3)
end
end
function love.mousepressed(x, y, button, istouch, presses)
if button == 1 then
for id, btn in pairs(buttons) do
if x >= btn.x and x <= btn.x + btn.w and y >= btn.y and y <= btn.y + btn.h then
if id == "btn_levels" then gameState = "levels"
elseif id == "btn_shop" then gameState = "shop"
elseif id == "btn_back" or id == "btn_exit" then gameState = "menu"
elseif id == "btn_pause" then gameState = "pause"
elseif id == "btn_resume" then gameState = "playing"
elseif string.sub(id, 1, 4) == "lvl_" then startLevel(tonumber(string.sub(id, 5)))
elseif string.sub(id, 1, 4) == "buy_" then
local skinId = string.sub(id, 5)
for i = 1, #shopItems do
local shopItem = shopItems[i]
if shopItem.id == skinId then
if playerData.coins >= shopItem.price then
playerData.coins = playerData.coins - shopItem.price
playerData.unlockedSkins[skinId] = true
playerData.currentSkin = skinId
saveGame()
end
end
end
elseif string.sub(id, 1, 6) == "equip_" then
playerData.currentSkin = string.sub(id, 7)
saveGame()
end
return
end
end
if gameState == "playing" then
player.currentOrbitIndex = player.currentOrbitIndex + 1
if player.currentOrbitIndex > #orbits then player.currentOrbitIndex = 1 end
end
end
end