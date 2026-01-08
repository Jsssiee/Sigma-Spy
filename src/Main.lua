--// Очистка окружения
if getgenv().Files then getgenv().Files = nil end

--// 1. НАСТРОЙКИ
local MasterConfig = {
	UseWorkspace = false, 
	NoActors = false,
	FolderName = "Sigma Spy",
	RepoUrl = "https://raw.githubusercontent.com/Jsssiee/Sigma-Spy/main",
	ParserUrl = "https://raw.githubusercontent.com/depthso/Roblox-parser/refs/heads/main/dist/Main.luau",
	ForceUseCustomComm = true,
	DebugMode = false
}

local Parameters = {...}
local Overwrites = Parameters[1]
if typeof(Overwrites) == "table" then
	for Key, Value in Overwrites do
		MasterConfig[Key] = Value
	end
end

local Services = setmetatable({}, {
	__index = function(self, Name: string): Instance
		return cloneref(game:GetService(Name))
	end,
})

print("[Sigma Spy] Loading libs...")

--// 2. ЗАГРУЗКА FILES
local FilesFunc = loadstring(game:HttpGet("https://raw.githubusercontent.com/Jsssiee/Sigma-Spy/main/src/lib/Files.lua"))
local FilesLib = FilesFunc()

if FilesLib.Init then
    FilesLib:Init({ Services = Services })
end

-- Принудительно ставим конфиг
FilesLib.Configuration = MasterConfig
FilesLib.Services = Services
getgenv().Files = FilesLib

--// 3. ФУНКЦИЯ ЗАГРУЗКИ (С FIX-ом)
local function LoadLib(name)
    local url = "https://raw.githubusercontent.com/Jsssiee/Sigma-Spy/main/src/lib/"..name..".lua"
    local source = game:HttpGet(url)
    
    -- Вставляем переменные в начало каждого скрипта
    local Injection = [[
        local Files = getgenv().Files
        local Configuration = Files.Configuration
        local Services = Files.Services
    ]]
    
    return loadstring(Injection .. "\n" .. source)()
end

--// 4. ЗАГРУЗКА СКРИПТОВ
local Scripts = {
    -- Если Config не загрузится, используем MasterConfig
    Config = LoadLib("Config") or MasterConfig, 
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

--// Шрифты
local FontContent = FilesLib:GetAsset("ProggyClean.ttf", true)
local FontJsonFile = FilesLib:CreateFont("ProggyClean", FontContent)
if Ui then Ui:SetFontFile(FontJsonFile) end

print("[Sigma Spy] Skipping config check to prevent crash...")

-- !!! Я УДАЛИЛ Process:CheckConfig(Config) И ЗАМЕНИЛ НА ЭТО: !!!
-- Просто объединяем таблицы вручную, если нужно
for k, v in pairs(MasterConfig) do
    if Config[k] == nil then
        Config[k] = v
    end
end

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
