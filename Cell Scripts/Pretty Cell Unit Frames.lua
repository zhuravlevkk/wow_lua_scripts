-- Настройки (можно менять)
local FRAME_WIDTH_MULTIPLIER = 6
local OFFSET_MULTIPLIER = 0.1
local POSITION_ABOVE_BARS = true  -- true = над барами (BT4Button49/60), false = сбоку от баров

-- Конфигурация для разных панелей (только для бокового позиционирования)
local BUTTON_CONFIGS = {
    -- Bartender4 кнопки
    bartender = {
        player_priority = {"BT4Button49", "BT4Button61"},
        target_ranges = {{49, 60}, {61, 72}}
    },
    -- Стандартные панели Blizzard
    blizzard = {
        player_priority = {"MultiBarBottomRightButton1", "MultiBarBottomLeftButton1"},
        target_priority = {"MultiBarBottomRightButton12", "MultiBarBottomLeftButton12"}
    }
}

-- Флаг для предотвращения дублирования
local isConfigured = false

local function ForceFrameWidth(frameName, targetWidth)
    local frame = _G[frameName]
    if frame and frame.SetWidth then 
        local success = pcall(function() 
            frame:SetWidth(targetWidth) 
        end)
    end
end

-- Глобальные переменные для хранения таймеров
local powerBarTimers = {}

local function ForcePowerBarWidth(frameName, targetWidth)
    local powerBarName = frameName .. "_PowerBar"
    local powerBar = _G[powerBarName]
    local parentFrame = _G[frameName]
    
    if powerBar and powerBar.SetWidth and parentFrame then
        -- Устанавливаем ширину power bar равную ширине родителя
        local success = pcall(function() 
            powerBar:SetWidth(parentFrame:GetWidth())
        end)
        
        -- Останавливаем старый таймер если он есть
        if powerBarTimers[frameName] then
            powerBarTimers[frameName]:Cancel()
        end
        
        -- Создаем новый таймер который синхронизирует с родителем
        powerBarTimers[frameName] = C_Timer.NewTicker(1, function()
            if powerBar and powerBar.GetWidth and parentFrame and parentFrame.GetWidth then
                local parentWidth = parentFrame:GetWidth()
                local currentWidth = powerBar:GetWidth()
                -- Проверяем разницу больше 5 пикселей чтобы избежать моргания
                if parentWidth and currentWidth and math.abs(currentWidth - parentWidth) > 5 then
                    pcall(function() powerBar:SetWidth(parentWidth) end)
                end
            end
        end)
    end
end

local function SetupFrameTexts(frame, frameName)
    if not frame then return end
    
    local frameWidth = frame:GetWidth() or (45 * FRAME_WIDTH_MULTIPLIER)
    
    if not frame.customTexts then
        frame.customTexts = {}
        
        frame.customTexts.name = frame:CreateFontString(nil, "OVERLAY")
        frame.customTexts.name:SetFont("Interface\\AddOns\\Cell\\Media\\Font\\Oswald.ttf", 12, "OUTLINE")
        frame.customTexts.name:SetTextColor(1, 1, 1, 1)
        frame.customTexts.name:SetPoint("LEFT", frame, "LEFT", frameWidth * 0.05, 0)
        frame.customTexts.name:SetJustifyH("LEFT")
        
        frame.customTexts.percent = frame:CreateFontString(nil, "OVERLAY")
        frame.customTexts.percent:SetFont("Interface\\AddOns\\Cell\\Media\\Font\\Oswald.ttf", 12, "OUTLINE")
        frame.customTexts.percent:SetTextColor(1, 1, 1, 1)
        frame.customTexts.percent:SetPoint("CENTER", frame, "CENTER", 0, 0)
        frame.customTexts.percent:SetJustifyH("CENTER")
        
        frame.customTexts.numeric = frame:CreateFontString(nil, "OVERLAY")
        frame.customTexts.numeric:SetFont("Interface\\AddOns\\Cell\\Media\\Font\\Oswald.ttf", 12, "OUTLINE")
        frame.customTexts.numeric:SetTextColor(1, 1, 1, 1)
        frame.customTexts.numeric:SetPoint("RIGHT", frame, "RIGHT", frameWidth * -0.05, 0)
        frame.customTexts.numeric:SetJustifyH("RIGHT")
    end
    
    local function UpdateTexts()
        local unit = frame.unit
        if unit and UnitExists(unit) then
            local currentHP = UnitHealth(unit) or 0
            local maxHP = UnitHealthMax(unit) or 1
            local percent = math.floor((currentHP / maxHP) * 100)
            local name = UnitName(unit) or frameName
            
            frame.customTexts.name:SetText(name)
            frame.customTexts.percent:SetText(percent .. "%")
            frame.customTexts.numeric:SetText(currentHP .. "/" .. maxHP)
        end
    end
    
    UpdateTexts()
end

-- Проверка наличия Bartender4
local function IsBartenderActive()
    return _G["Bartender4"] ~= nil or _G["BT4Button1"] ~= nil
end

-- Поиск кнопки игрока в зависимости от активного аддона
local function FindPlayerButton()
    if IsBartenderActive() then
        for _, buttonName in ipairs(BUTTON_CONFIGS.bartender.player_priority) do
            local button = _G[buttonName]
            if button and button:IsVisible() then 
                return button 
            end
        end
    else
        for _, buttonName in ipairs(BUTTON_CONFIGS.blizzard.player_priority) do
            local button = _G[buttonName]
            if button and button:IsVisible() then 
                return button 
            end
        end
    end
    return nil
end

-- Поиск кнопки цели в зависимости от активного аддона
local function FindTargetButton()
    if IsBartenderActive() then
        for _, range in ipairs(BUTTON_CONFIGS.bartender.target_ranges) do
            for i = range[2], range[1], -1 do
                local button = _G["BT4Button" .. i]
                if button and button:IsVisible() then 
                    return button 
                end
            end
        end
    else
        for _, buttonName in ipairs(BUTTON_CONFIGS.blizzard.target_priority) do
            local button = _G[buttonName]
            if button and button:IsVisible() then 
                return button 
            end
        end
    end
    return nil
end

-- Временно отключаем сообщения в чат
local function SuppressChatMessages(func)
    local oldPrint = print
    local oldChatFrame_DisplayChatMessage = ChatFrame_DisplayChatMessage
    local oldChatFrame1AddMessage = ChatFrame1.AddMessage
    
    -- Временно заменяем функции вывода
    print = function() end
    if ChatFrame_DisplayChatMessage then
        ChatFrame_DisplayChatMessage = function() end
    end
    if ChatFrame1 and ChatFrame1.AddMessage then
        ChatFrame1.AddMessage = function() end
    end
    
    -- Выполняем функцию
    local success, result = pcall(func)
    
    -- Восстанавливаем функции
    print = oldPrint
    if oldChatFrame_DisplayChatMessage then
        ChatFrame_DisplayChatMessage = oldChatFrame_DisplayChatMessage
    end
    if ChatFrame1 and oldChatFrame1AddMessage then
        ChatFrame1.AddMessage = oldChatFrame1AddMessage
    end
    
    return success, result
end

local function ConfigureFrames()
    if isConfigured then return end
    
    local CUF = _G["CUF"]
    if not CUF or not CUF.API then return end
    
    if POSITION_ABOVE_BARS then
        -- Позиционирование над барами (к конкретным кнопкам BT4Button49 и BT4Button60)
        local button49 = _G["BT4Button49"]
        local button60 = _G["BT4Button60"]
        
        if button49 and button60 then
            local buttonWidth = button49:GetWidth() or 45
            local buttonHeight = button49:GetHeight() or 45
            local frameWidth = buttonWidth * FRAME_WIDTH_MULTIPLIER
            
            -- Player: левый нижний угол фрейма к левому верхнему углу BT4Button49
            CUF.API:SetCustomUnitFramePoint("CUF_Player", "BOTTOMLEFT", button49, "TOPLEFT", 0, 0)
            CUF.API:SetCustomUnitFrameSize("CUF_Player", frameWidth, buttonHeight)
            
            -- Target: правый нижний угол фрейма к правому верхнему углу BT4Button60
            CUF.API:SetCustomUnitFramePoint("CUF_Target", "BOTTOMRIGHT", button60, "TOPRIGHT", 0, 0)
            CUF.API:SetCustomUnitFrameSize("CUF_Target", frameWidth, buttonHeight)
            
            -- Pet слева от Player
            CUF.API:SetCustomUnitFramePoint("CUF_Pet", "RIGHT", _G["CUF_Player"], "LEFT", -2, 0)
            CUF.API:SetCustomUnitFrameSize("CUF_Pet", frameWidth, buttonHeight)
            
            -- TargetTarget справа от Target
            CUF.API:SetCustomUnitFramePoint("CUF_TargetTarget", "LEFT", _G["CUF_Target"], "RIGHT", 2, 0)
            CUF.API:SetCustomUnitFrameSize("CUF_TargetTarget", frameWidth, buttonHeight)
            
            -- Принудительно устанавливаем ширину frames и power bars сразу без задержки
            ForceFrameWidth("CUF_Pet", frameWidth)
            ForceFrameWidth("CUF_TargetTarget", frameWidth)
            ForcePowerBarWidth("CUF_Player", frameWidth)
            ForcePowerBarWidth("CUF_Pet", frameWidth)
            ForcePowerBarWidth("CUF_Target", frameWidth)
            ForcePowerBarWidth("CUF_TargetTarget", frameWidth)
            
            -- Дополнительная проверка через небольшую задержку
            C_Timer.After(0.1, function()
                ForcePowerBarWidth("CUF_Player", frameWidth)
                ForcePowerBarWidth("CUF_Pet", frameWidth)
                ForcePowerBarWidth("CUF_Target", frameWidth)
                ForcePowerBarWidth("CUF_TargetTarget", frameWidth)
            end)
        end
    else
        -- Оригинальное позиционирование сбоку от баров
        local playerButton = FindPlayerButton()
        local targetButton = FindTargetButton()
        
        if playerButton then
            local buttonWidth = playerButton:GetWidth() or 45
            local buttonHeight = playerButton:GetHeight() or 45
            local frameWidth = buttonWidth * FRAME_WIDTH_MULTIPLIER
            local offset = buttonWidth * OFFSET_MULTIPLIER
            
            SuppressChatMessages(function()
                CUF.API:SetCustomUnitFramePoint("CUF_Player", "RIGHT", playerButton, "LEFT", -offset, 0)
                CUF.API:SetCustomUnitFrameSize("CUF_Player", frameWidth, buttonHeight)
                
                CUF.API:SetCustomUnitFramePoint("CUF_Pet", "TOP", _G["CUF_Player"], "BOTTOM", 0, -2)
                CUF.API:SetCustomUnitFrameSize("CUF_Pet", frameWidth, buttonHeight)
            end)
            
            C_Timer.After(0.5, function()
                SuppressChatMessages(function()
                    ForceFrameWidth("CUF_Pet", frameWidth)
                    ForcePowerBarWidth("CUF_Player", frameWidth)
                    ForcePowerBarWidth("CUF_Pet", frameWidth)
                end)
            end)
        end
        
        if targetButton then
            local buttonWidth = targetButton:GetWidth() or 45
            local buttonHeight = targetButton:GetHeight() or 45
            local frameWidth = buttonWidth * FRAME_WIDTH_MULTIPLIER
            local offset = buttonWidth * OFFSET_MULTIPLIER
            
            SuppressChatMessages(function()
                CUF.API:SetCustomUnitFramePoint("CUF_Target", "LEFT", targetButton, "RIGHT", offset, 0)
                CUF.API:SetCustomUnitFrameSize("CUF_Target", frameWidth, buttonHeight)
                
                CUF.API:SetCustomUnitFramePoint("CUF_TargetTarget", "TOP", _G["CUF_Target"], "BOTTOM", 0, -2)
                CUF.API:SetCustomUnitFrameSize("CUF_TargetTarget", frameWidth, buttonHeight)
            end)
            
            C_Timer.After(0.5, function()
                SuppressChatMessages(function()
                    ForceFrameWidth("CUF_TargetTarget", frameWidth)
                    ForcePowerBarWidth("CUF_Target", frameWidth)
                    ForcePowerBarWidth("CUF_TargetTarget", frameWidth)
                end)
            end)
        end
    end
    
    C_Timer.After(1, function()
        local frames = {
            {_G["CUF_Player"], "Player"}, 
            {_G["CUF_Target"], "Target"},
            {_G["CUF_Pet"], "Pet"}, 
            {_G["CUF_TargetTarget"], "TargetTarget"}
        }
        
        for _, frameData in pairs(frames) do
            if frameData[1] then
                SetupFrameTexts(frameData[1], frameData[2])
            end
        end
    end)
    
    isConfigured = true
end

local function SafeExecute()
    if InCombatLockdown() then
        local frame = CreateFrame("Frame")
        frame:RegisterEvent("PLAYER_REGEN_ENABLED")
        frame:SetScript("OnEvent", function(self)
            self:UnregisterEvent("PLAYER_REGEN_ENABLED")
            C_Timer.After(0.5, ConfigureFrames)
        end)
    else
        ConfigureFrames()
    end
end

-- Регистрируем колбек Cell
Cell:RegisterCallback("CUF_FramesInitialized", "PermanentAnchor", SafeExecute)

-- Создаем event frame для различных событий
local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("ADDON_LOADED")
eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
eventFrame:RegisterEvent("PLAYER_LOGIN")
eventFrame:SetScript("OnEvent", function(self, event, addonName)
    if event == "ADDON_LOADED" then
        if addonName == "Cell_UnitFrames" or addonName == "Cell" then
            C_Timer.After(1, SafeExecute)
        elseif addonName == "Bartender4" then
            isConfigured = false
            C_Timer.After(2, SafeExecute)
        end
    elseif event == "PLAYER_ENTERING_WORLD" then
        C_Timer.After(2, SafeExecute)
    elseif event == "PLAYER_LOGIN" then
        C_Timer.After(3, SafeExecute)
    end
end)

-- Запускаем сразу
SafeExecute()