--// Очищаем старые глобальные переменные
if getgenv().Files then getgenv().Files = nil end

--// 1. ПОЛНАЯ КОНФИГУРАЦИЯ (Добавил ForceUseCustomComm чтобы не было ошибок)
local Configuration = {
	UseWorkspace = false, 
	NoActors = false,
	FolderName = "Sigma Spy",
	RepoUrl = "https://raw.githubusercontent.com/Jsssiee/Sigma-Spy/main",
	ParserUrl = "https://raw.githubusercontent.com/depthso/Roblox-parser/refs/heads/main/dist/Main.luau",
	
	-- Добавлены важные параметры, которых не хватало
	ForceUseCustomComm = false,
	DebugMode = false
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
-- 2. ЗАГРУЖАЕМ FILES
---------------------------------------------------------------------
local FilesUrl = "https://raw.githubusercontent.com/Jsssiee/Sigma-Spy/main/src/lib/Files.lua"
local FilesFunc = loadstring(game:HttpGet(FilesUrl))
local FilesLib = FilesFunc()

if not FilesLib then
    return warn("[Sigma Spy] Error: Files.lua did not return a table!")
end

-- СНАЧАЛА делаем Init (он создает внутренние таблицы)
if FilesLib.Init then
    FilesLib:Init({ Services = Services })
end

-- И ТОЛЬКО ПОТОМ записываем наш конфиг (перезаписываем пустой)
FilesLib.Configuration = Configuration
FilesLib.Services = Services

-- Делаем Files глобальным
getgenv().Files = FilesLib
print("[Sigma Spy] Files initialized correctly.")

---------------------------------------------------------------------
-- 3. ФУНКЦИЯ ЗАГРУЗКИ
---------------------------------------------------------------------
local function LoadLib(path)
    local url = "https://raw.githubusercontent.com/Jsssiee/Sigma-Spy/main/src/lib/"..path..".lua"
    local func = loadstring(game:HttpGet(url))
    
    local env = getfenv(func)
    -- Внедряем готовую библиотеку Files во все скрипты
    env.Files = getgenv().Files 
    env.Configuration = Configuration 
    env.Services = Services   
    
    setfenv(func, env)
    return func()
end

---------------------------------------------------------------------
-- 4. ЗАГРУЗКА СКРИПТОВ
---------------------------------------------------------------------
local Scripts = {
    Config = LoadLib("Config"),
    ReturnSpoofs = LoadLib("Return%20spoofs"), 
    Configuration = Configuration,
    Files = getgenv().Files,

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

print("[Sigma Spy] Checking config...")

-- Еще раз на всякий случай обновляем ссылку на конфиг перед проверкой
getgenv().Files.Configuration = Configuration 

-- Теперь ошибки быть не должно, т.к. Files.Configuration существует и содержит ForceUseCustomComm
Process:CheckConfig(Config)

-- Загружаем модули
getgenv().Files:LoadModules(Modules, {
	Modules = Modules,
	Services = Services
})

--// Создаем окно
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
		"Enable function patches?",
	},
	Options = {"Yes", "No"}
}) == "Yes"

Event:Fire("BeginHooks", {
	PatchFunctions = EnablePatches
})

print("[Sigma Spy] Loaded successfully!")
