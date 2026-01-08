--// Очищаем старые глобальные переменные, если они были
if getgenv().Files then getgenv().Files = nil end

--// Base Configuration
local Configuration = {
	UseWorkspace = false, 
	NoActors = false,
	FolderName = "Sigma Spy",
	RepoUrl = "https://raw.githubusercontent.com/Jsssiee/Sigma-Spy/main",
	ParserUrl = "https://raw.githubusercontent.com/depthso/Roblox-parser/refs/heads/main/dist/Main.luau"
}

local Parameters = {...}
local Overwrites = Parameters[1]
if typeof(Overwrites) == "table" then
	for Key, Value in Overwrites do
		Configuration[Key] = Value
	end
end

local Services = setmetatable({}, {
	__index = function(self, Name: string): Instance
		return cloneref(game:GetService(Name))
	end,
})

print("[Sigma Spy] Starting manual loading...")

---------------------------------------------------------------------
-- 1. ЗАГРУЖАЕМ FILES И ДЕЛАЕМ ЕГО ГЛОБАЛЬНЫМ
---------------------------------------------------------------------
local FilesUrl = "https://raw.githubusercontent.com/Jsssiee/Sigma-Spy/main/src/lib/Files.lua"
-- Загружаем сам скрипт
local FilesFunc = loadstring(game:HttpGet(FilesUrl))
-- Получаем таблицу
local FilesLib = FilesFunc()

if not FilesLib then
    return warn("[Sigma Spy] Error: Files.lua did not return a table!")
end

-- ВРУЧНУЮ устанавливаем конфигурацию (самый надежный способ)
FilesLib.Configuration = Configuration
FilesLib.Services = Services

-- Делаем Files глобальным, чтобы все модули видели именно ЭТУ копию
getgenv().Files = FilesLib

print("[Sigma Spy] Files loaded and Config set.")

-- Инициализация (если есть метод Init)
if FilesLib.Init then
    FilesLib:Init({ Services = Services })
end

---------------------------------------------------------------------
-- 2. ФУНКЦИЯ ЗАГРУЗКИ (Использует глобальный Files)
---------------------------------------------------------------------
local function LoadLib(path)
    local url = "https://raw.githubusercontent.com/Jsssiee/Sigma-Spy/main/src/lib/"..path..".lua"
    local func = loadstring(game:HttpGet(url))
    
    local env = getfenv(func)
    
    -- Жестко привязываем наши глобальные переменные
    env.Files = getgenv().Files 
    env.Configuration = Configuration 
    env.Services = Services   
    
    setfenv(func, env)
    return func()
end

---------------------------------------------------------------------
-- 3. ЗАГРУЗКА ОСТАЛЬНЫХ СКРИПТОВ
---------------------------------------------------------------------
local Scripts = {
    Config = LoadLib("Config"),
    ReturnSpoofs = LoadLib("Return%20spoofs"), 
    Configuration = Configuration,
    Files = getgenv().Files, -- Используем глобальную версию

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
local FontContent = getgenv().Files:GetAsset("ProggyClean.ttf", true)
local FontJsonFile = getgenv().Files:CreateFont("ProggyClean", FontContent)
if Ui then Ui:SetFontFile(FontJsonFile) end

--// ПРОВЕРКА ПЕРЕД ЗАПУСКОМ
-- Еще раз принудительно обновляем конфиг перед проверкой
getgenv().Files.Configuration = Configuration 

print("[Sigma Spy] Checking config...")
-- Если ошибка тут, значит Process.lua не видит таблицу Files.Configuration
Process:CheckConfig(Config)
print("[Sigma Spy] Config checked successfully.")

-- Вместо LoadLibraries
getgenv().Files:LoadModules(Modules, {
	Modules = Modules,
	Services = Services
})

--// UI Creation
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

local ActorCode = getgenv().Files:MakeActorScript(Scripts, ChannelId)
Hook:LoadHooks(ActorCode, ChannelId)

local EnablePatches = Ui:AskUser({
	Title = "Enable function patches?",
	Content = {
		"Enable function patches? (May prevent detection on some executors)",
	},
	Options = {"Yes", "No"}
}) == "Yes"

Event:Fire("BeginHooks", {
	PatchFunctions = EnablePatches
})

print("[Sigma Spy] Loaded successfully!")
