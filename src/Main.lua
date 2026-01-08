--// Base Configuration
local Configuration = {
	UseWorkspace = false, 
	NoActors = false,
	FolderName = "Sigma Spy",
	RepoUrl = "https://raw.githubusercontent.com/Jsssiee/Sigma-Spy/main",
	ParserUrl = "https://raw.githubusercontent.com/depthso/Roblox-parser/refs/heads/main/dist/Main.luau"
}

--// Load overwrites
local Parameters = {...}
local Overwrites = Parameters[1]
if typeof(Overwrites) == "table" then
	for Key, Value in Overwrites do
		Configuration[Key] = Value
	end
end

--// Service handler
local Services = setmetatable({}, {
	__index = function(self, Name: string): Instance
		local Service = game:GetService(Name)
		return cloneref(Service)
	end,
})

---------------------------------------------------------------------
-- 1. СНАЧАЛА ЗАГРУЖАЕМ FILES И НАСТРАИВАЕМ ЕГО (ЭТО САМОЕ ВАЖНОЕ) --
---------------------------------------------------------------------
local Files = loadstring(game:HttpGet("https://raw.githubusercontent.com/Jsssiee/Sigma-Spy/main/src/lib/Files.lua"))()

-- Передаем конфиг, чтобы не было ошибки ForceUseCustomComm
Files:PushConfig(Configuration)

-- Инициализируем сервисы внутри Files
Files:Init({
	Services = Services
})

---------------------------------------------------------------------
-- 2. ТЕПЕРЬ ФУНКЦИЯ ЗАГРУЗКИ (Она уже видит переменную Files)     --
---------------------------------------------------------------------
local function LoadLib(path)
    -- Загружаем код
    local url = "https://raw.githubusercontent.com/Jsssiee/Sigma-Spy/main/src/lib/"..path..".lua"
    local func = loadstring(game:HttpGet(url))
    
    -- Создаем поддельное окружение для скрипта
    local env = getfenv(func)
    
    -- ВАЖНО: Тут мы кладем уже созданный выше Files внутрь загружаемого скрипта
    env.Files = Files         
    env.Configuration = Configuration 
    env.Services = Services   
    
    -- Применяем окружение и запускаем
    setfenv(func, env)
    return func()
end

---------------------------------------------------------------------
-- 3. ЗАГРУЖАЕМ ОСТАЛЬНЫЕ СКРИПТЫ                                  --
---------------------------------------------------------------------
local Scripts = {
    --// User configurations
    Config = LoadLib("Config"),
    ReturnSpoofs = LoadLib("Return%20spoofs"), 
    Configuration = Configuration,
    Files = Files,

    --// Libraries
    Process = LoadLib("Process"),
    Hook = LoadLib("Hook"),
    Flags = LoadLib("Flags"),
    Ui = LoadLib("Ui"),
    Generation = LoadLib("Generation"),
    Communication = LoadLib("Communication")
}

--// Services
local Players: Players = Services.Players

--// Dependencies
local Modules = Scripts
local Process = Modules.Process
local Hook = Modules.Hook
local Ui = Modules.Ui
local Generation = Modules.Generation
local Communication = Modules.Communication
local Config = Modules.Config

--// Use custom font (optional)
-- Files уже загружен, так что это сработает
local FontContent = Files:GetAsset("ProggyClean.ttf", true)
local FontJsonFile = Files:CreateFont("ProggyClean", FontContent)

-- У Ui есть доступ к методам, если Ui.lua загрузился правильно
if Ui then
    Ui:SetFontFile(FontJsonFile)
end

--// Load modules
-- Проверка конфига теперь пройдет, т.к. Files знает про Configuration
Process:CheckConfig(Config)

-- Вместо старого LoadLibraries используем ручную загрузку
Files:LoadModules(Modules, {
	Modules = Modules,
	Services = Services
})

--// ReGui Create window
local Window = Ui:CreateMainWindow()

--// Check if Sigma spy is supported
local Supported = Process:CheckIsSupported()
if not Supported then 
	Window:Close()
	return
end

--// Create communication channel
local ChannelId, Event = Communication:CreateChannel()
Communication:AddCommCallback("QueueLog", function(...)
	Ui:QueueLog(...)
end)
Communication:AddCommCallback("Print", function(...)
	Ui:ConsoleLog(...)
end)

--// Generation swaps
local LocalPlayer = Players.LocalPlayer
Generation:SetSwapsCallback(function(self)
	self:AddSwap(LocalPlayer, {
		String = "LocalPlayer",
	})
	self:AddSwap(LocalPlayer.Character, {
		String = "Character",
		NextParent = LocalPlayer
	})
end)

--// Create window content
Ui:CreateWindowContent(Window)

--// Begin the Log queue 
Ui:SetCommChannel(Event)
Ui:BeginLogService()

--// Load hooks
local ActorCode = Files:MakeActorScript(Scripts, ChannelId)
Hook:LoadHooks(ActorCode, ChannelId)

local EnablePatches = Ui:AskUser({
	Title = "Enable function patches?",
	Content = {
		"On some executors, function patches can prevent common detections that executor has",
		"By enabling this, it MAY trigger hook detections in some games, this is why you are asked.",
		"If it doesn't work, rejoin and press 'No'",
		"",
		"(This does not affect game functionality)"
	},
	Options = {"Yes", "No"}
}) == "Yes"

--// Begin hooks
Event:Fire("BeginHooks", {
	PatchFunctions = EnablePatches
})
