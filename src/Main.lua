--// Очистка окружения
if getgenv().Files then getgenv().Files = nil end

--// 1. НАСТРОЙКА КОНФИГУРАЦИИ
-- Важно: мы создаем эту таблицу здесь, чтобы передать её во все скрипты
local MasterConfig = {
	UseWorkspace = false, 
	NoActors = false,
	FolderName = "Sigma Spy",
	RepoUrl = "https://raw.githubusercontent.com/Jsssiee/Sigma-Spy/main",
	ParserUrl = "https://raw.githubusercontent.com/depthso/Roblox-parser/refs/heads/main/dist/Main.luau",
	
	-- Добавляем параметры, чтобы избежать nil ошибок
	ForceUseCustomComm = false,
	DebugMode = false
}

local Parameters = {...}
local Overwrites = Parameters[1]
if typeof(Overwrites) == "table" then
	for Key, Value in Overwrites do
		MasterConfig[Key] = Value
	end
end

--// Сервисы
local Services = setmetatable({}, {
	__index = function(self, Name: string): Instance
		return cloneref(game:GetService(Name))
	end,
})

print("[Sigma Spy] Loading Files...")

--// 2. ЗАГРУЗКА FILES (ОСНОВА)
local FilesFunc = loadstring(game:HttpGet("https://raw.githubusercontent.com/Jsssiee/Sigma-Spy/main/src/lib/Files.lua"))
local FilesLib = FilesFunc()

-- Инициализируем Files
if FilesLib.Init then
    FilesLib:Init({ Services = Services })
end

-- ЖЕСТКО ЗАПИСЫВАЕМ КОНФИГ
FilesLib.Configuration = MasterConfig
FilesLib.Services = Services

-- Делаем Files глобальным
getgenv().Files = FilesLib
print("[Sigma Spy] Files loaded & Config applied.")

--// 3. НОВАЯ ФУНКЦИЯ ЗАГРУЗКИ (С ВНЕДРЕНИЕМ КОДА)
local function LoadLib(name)
    local url = "https://raw.githubusercontent.com/Jsssiee/Sigma-Spy/main/src/lib/"..name..".lua"
    local source = game:HttpGet(url)
    
    -- Мы добавляем эти строки в САМОЕ НАЧАЛО каждого скрипта.
    -- Это гарантирует, что переменные Files и Configuration будут существовать.
    local Injection = [[
        local Files = getgenv().Files
        local Configuration = Files.Configuration
        local Services = Files.Services
    ]]
    
    local finalSource = Injection .. "\n" .. source
    return loadstring(finalSource)()
end

--// 4. ЗАГРУЗКА ОСТАЛЬНЫХ СКРИПТОВ
local Scripts = {
    -- Теперь каждый из них получит Files и Configuration автоматически
    Config = LoadLib("Config"),
    ReturnSpoofs = LoadLib("Return%20spoofs"), 
    Configuration = MasterConfig,
    Files = FilesLib,

    Process = LoadLib("Process"),
    Hook = LoadLib("Hook"),
    Flags = LoadLib("Flags"),
    Ui = LoadLib("Ui"),
    Generation = LoadLib("Generation"),
    Communication = LoadLib("Communication")
}

local Modules = Scripts
local Process = Modules.Process
local Ui = Modules.Ui
local Config = Modules.Config
local Communication = Modules.Communication
local Generation = Modules.Generation
local Hook = Modules.Hook

--// Setup Font
local FontContent = FilesLib:GetAsset("ProggyClean.ttf", true)
local FontJsonFile = FilesLib:CreateFont("ProggyClean", FontContent)
if Ui then Ui:SetFontFile(FontJsonFile) end

print("[Sigma Spy] Checking config...")

--// ФИНАЛЬНАЯ ПРОВЕРКА
-- Если это упадет, значит проблема в самом файле Process.lua (но теперь вряд ли)
Process:CheckConfig(Config)

-- Загрузка модулей
FilesLib:LoadModules(Modules, {
	Modules = Modules,
	Services = Services
})

--// UI Создание
local Window = Ui:CreateMainWindow()

local Supported = Process:CheckIsSupported()
if not Supported then 
	Window:Close()
	return
end

local ChannelId, Event = Communication:CreateChannel()
Communication:AddCommCallback("QueueLog", function(...) Ui:QueueLog(...) end)
Communication:AddCommCallback("Print", function(...) Ui:ConsoleLog(...) end)

local LocalPlayer = Services.Players.LocalPlayer
Generation:SetSwapsCallback(function(self)
	self:AddSwap(LocalPlayer, {String = "LocalPlayer"})
	self:AddSwap(LocalPlayer.Character, {String = "Character", NextParent = LocalPlayer})
end)

Ui:CreateWindowContent(Window)
Ui:SetCommChannel(Event)
Ui:BeginLogService()

local ActorCode = FilesLib:MakeActorScript(Scripts, ChannelId)
Hook:LoadHooks(ActorCode, ChannelId)

local EnablePatches = Ui:AskUser({
	Title = "Enable function patches?",
	Content = { "Enable function patches?" },
	Options = {"Yes", "No"}
}) == "Yes"

Event:Fire("BeginHooks", {
	PatchFunctions = EnablePatches
})

print("[Sigma Spy] Success!")
