--// Base Configuration
local Configuration = {
	UseWorkspace = false, 
	NoActors = false,
	FolderName = "Sigma Spy",
	RepoUrl = "https://raw.githubusercontent.com/Jsssiee/Sigma-Spy/refs/heads/main",
	ParserUrl = "https://raw.githubusercontent.com/Jsssiee/Roblox-parser/refs/heads/main/dist/Main.luau"
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

--// Files module
local Files = (function()
	type table = {
	[any]: any
}

--// Module
local Files = {
	UseWorkspace = false,
	Folder = "Sigma spy",
	RepoUrl = nil,
	FolderStructure = {
		["Sigma Spy"] = {
			"assets",
		}
	}
}

--// Services
local HttpService: HttpService

function Files:Init(Data)
	local FolderStructure = self.FolderStructure
    local Services = Data.Services
    HttpService = Services.HttpService

	--// Check if the folders need to be created
	self:CheckFolders(FolderStructure)
end

function Files:PushConfig(Config: table)
	for Key, Value in next, Config do
		self[Key] = Value
	end
end

function Files:UrlFetch(Url: string): string
	--// Request data
    local Final = {
        Url = Url:gsub(" ", "%%20"), 
        Method = 'GET'
    }

	 --// Send HTTP request
    local Success, Responce = pcall(request, Final)

    --// Error check
    if not Success then 
        warn("[!] HTTP request error! Check console (F9)")
        warn("> Url:", Url)
        error(Responce)
        return ""
    end

    local Body = Responce.Body
    local StatusCode = Responce.StatusCode

	--// Status code check
    if StatusCode == 404 then
        warn("[!] The file requested has moved or been deleted.")
        warn(" >", Url)
        return ""
    end

    return Body, Responce
end

function Files:MakePath(Path: string)
	local Folder = self.Folder
	return `{Folder}/{Path}`
end

function Files:LoadCustomasset(Path: string)
	if not getcustomasset then return end

	--// Check if the file has content
	local Content = readfile(Path)
	if Content == "" then return end

	--// Load custom AssetId
	return getcustomasset(Path)
end

function Files:GetFile(Path: string, CustomAsset: boolean?): string?
	local RepoUrl = self.RepoUrl
	local UseWorkspace = self.UseWorkspace

	local LocalPath = self:MakePath(Path)
	local Content = ""

	--// Check if the files should be fetched from the workspace instead
	if UseWorkspace then
		Content = readfile(LocalPath)
	else
		Content = self:UrlFetch(`{RepoUrl}/{Path}`)
	end

	--// Custom asset
	if CustomAsset then
		--// Check if the file should be written to
		self:FileCheck(LocalPath, function()
			return Content
		end)

		return self:LoadCustomasset(LocalPath)
	end

	--// Download with a HTTP request
	return Content
end

function Files:GetTemplate(Name: string): string
    return self:GetFile(`templates/{Name}.lua`)
end

function Files:FileCheck(Path: string, Callback)
	if isfile(Path) then return end

	--// Create and write the template to the missing file
	local Template = Callback()
	writefile(Path, Template)
end

function Files:FolderCheck(Path: string)
	if isfolder(Path) then return end
	makefolder(Path)
end

function Files:CheckPath(Parent: string, Child: string)
	return Parent and `{Parent}/{Child}` or Child
end

function Files:CheckFolders(Structure: table, Path: string?)
	for ParentName, Name in next, Structure do
		--// Check existance of the parent folder
		if typeof(Name) == "table" then
			local NewPath = self:CheckPath(Path, ParentName)
			self:FolderCheck(NewPath)
			self:CheckFolders(Name, NewPath)
			continue
		end

		--// Check existance of child folder
		local FolderPath = self:CheckPath(Path, Name)
		self:FolderCheck(FolderPath)
	end
end

function Files:TemplateCheck(Path: string, TemplateName: string)
	self:FileCheck(Path, function()
		return self:GetTemplate(TemplateName)
	end)
end

function Files:GetAsset(Name: string, CustomAsset: boolean?): string
    return self:GetFile(`assets/{Name}`, CustomAsset)
end

function Files:GetModule(Name: string, TemplateName: string): string
	local Path = `{Name}.lua`

	--// The file will be declared local if the template argument is provided
	if TemplateName then
		self:TemplateCheck(Path, TemplateName)
		return readfile(Path)
	end

	return self:GetFile(Path)
end

function Files:LoadLibraries(Scripts: table, ...): table
	local Modules = {}
	for Name, Content in next, Scripts do
		local Closure = loadstring(Content, Name)
		assert(Closure, `Failed to load {Name}`)
		Modules[Name] = Closure(...)
	end
	return Modules
end

function Files:LoadModules(Modules: {}, Data: {})
    for Name, Module in next, Modules do
        local Init = Module.Init
        if not Init then continue end

		--// Invoke :Init function 
        Module:Init(Data)
    end
end

function Files:CreateFont(Name: string, AssetId: string): string?
	if not AssetId then return end

	--// Custom font Json
	local FileName = `assets/{Name}.json`
	local JsonPath = self:MakePath(FileName)
	local Data = {
		name = Name,
		faces = {
			{
				name = "Regular",
				weight = 400,
				style = "Normal",
				assetId = AssetId
			}
		}
	}

	--// Write Json
	local Json = HttpService:JSONEncode(Data)
	writefile(JsonPath, Json)

	return JsonPath
end

function Files:CompileModule(Scripts): string
    local Out = "local Libraries = {"
    for Name, Content in Scripts do
        Out ..= `	{Name} = (function()\n{Content}\nend)(),\n`
    end
	Out ..= "}"
    return Out
end

return Files
end)()
Files:PushConfig(Configuration)
Files:Init({
	Services = Services
})

local Folder = Files.FolderName
local Scripts = {
	--// User configurations
	Config = Files:GetModule(`{Folder}/Config`, "Config"),
	ReturnSpoofs = Files:GetModule(`{Folder}/Return spoofs`, "Return Spoofs"),
	Configuration = Configuration,
	Files = Files,

	--// Libraries
	Process = {"base64", (function()
local Process = {
    --// Remote classes
    RemoteClassData = {
        ["RemoteEvent"] = {
            Send = {
                "FireServer",
                "fireServer",
            },
            Receive = {
                "OnClientEvent",
            }
        },
        ["RemoteFunction"] = {
            IsRemoteFunction = true,
            Send = {
                "InvokeServer",
                "invokeServer",
            },
            Receive = {
                "OnClientInvoke",
            }
        },
        ["UnreliableRemoteEvent"] = {
            Send = {
                "FireServer",
                "fireServer",
            },
            Receive = {
                "OnClientEvent",
            }
        },
        ["BindableEvent"] = {
            Send = {
                "Fire",
            },
            Receive = {
                "Event",
            }
        },
        ["BindableFunction"] = {
            IsRemoteFunction = true,
            Send = {
                "Invoke",
            },
            Receive = {
                "OnInvoke",
            }
        }
    },
    RemoteOptions = {}
}

type table = {
	[any]: any
}

--// Modules
local Hook
local Communication
local ReturnSpoofs
local Ui

--// Communication channel
local Channel

local function Merge(Base: table, New: table)
	for Key, Value in next, New do
		Base[Key] = Value
	end
end

--// Communication
function Process:SetChannelId(ChannelId: number)
    Channel = Communication:GetChannel(ChannelId)
end

function Process:Init(Data)
    local Modules = Data.Modules
    Ui = Modules.Ui
    Hook = Modules.Hook
    Communication = Modules.Communication
    ReturnSpoofs = Modules.ReturnSpoofs
end

function Process:PushConfig(Overwrites)
    Merge(self, Overwrites)
end

function Process:FuncExists(Name: string)
	return getfenv(1)[Name]
end

function Process:CheckIsSupported(): boolean
    local CoreFunctions = {
        "create_comm_channel",
        "get_comm_channel",
        "hookmetamethod",
        "getrawmetatable",
        "setreadonly"
    }

    --// Check if the functions exist in the ENV
    for _, Name in CoreFunctions do
        local Func = self:FuncExists(Name)
        if Func then continue end

        --// Function missing!
        Ui:ShowUnsupported(Name)
        return false
    end

    return true
end

function Process:GetClassData(Remote: Instance): table?
    local RemoteClassData = self.RemoteClassData
    local ClassName = Hook:Index(Remote, "ClassName")

    return RemoteClassData[ClassName]
end

function Process:RemoteAllowed(Remote: Instance, TransferType: string, Method: string?): boolean?
    if typeof(Remote) ~= 'Instance' then return end
    
    if Remote == Communication.DebugIdRemote then return end
    if Remote == Channel then return end

    --// Fetch class table
	local ClassData = self:GetClassData(Remote)
	if not ClassData then return end

    --// Check if the transfer type has data
	local Allowed = ClassData[TransferType]
	if not Allowed then return warn("TransferType not Allowed") end

    --// Check if the method is allowed
	if Method then
		return table.find(Allowed, Method) ~= nil
	end

	return true
end

function Process:SetExtraData(Data: table)
    if not Data then return end
    self.ExtraData = Data
end

function Process:GetRemoteSpoof(Remote: Instance, Method: string)
    local Spoof = ReturnSpoofs[Remote]

    if not Spoof then return end
    if Spoof.Method ~= Method then return end

	Communication:Warn("Spoofed", Method)
	return {Spoof.Return}
end

function Process:FindCallingLClosure(Offset: number)
    Offset += 1

    while true do
        Offset += 1

        --// Check if the stack level is valid
        local IsValid = debug.info(Offset, "l") ~= -1
        if not IsValid then continue end

        --// Check if the function is valud
        local Function = debug.info(Offset, "f")
        if not Function then return end

        return Function
    end
end

function Process:ProcessRemote(Data)
    local OriginalFunc = Data.OriginalFunc
    local Remote = Data.Remote
	local Method = Data.Method
    local Args = Data.Args
    local TransferType = Data.TransferType

	--// Check if the transfertype method is allowed
	if TransferType and not self:RemoteAllowed(Remote, TransferType, Method) then return end

    local Id = Communication:GetDebugId(Remote)
    local RemoteData = self:GetRemoteData(Id)
    local ClassData = self:GetClassData(Remote)

    --// Add extra data into the log if needed
    local ExtraData = self.ExtraData
    if ExtraData then
        Merge(Data, ExtraData)
    end

    --// Add to queue
    Merge(Data, {
		CallingScript = getcallingscript(),
		CallingFunction = self:FindCallingLClosure(5),
        Id = Id,
		ClassData = ClassData
    })

    --// Queue log
    Communication:QueueLog(Data)

    --// Blocked
    if RemoteData.Blocked then return {} end

    --// Check for a spoof
	local Spoof = self:GetRemoteSpoof(Remote, Method)
    if Spoof then return Spoof end

    --// Call original function
    if not OriginalFunc then return end

    local ArgsLength = table.maxn(Args)
    local ReturnValues = {OriginalFunc(Remote, unpack(Args, 1, ArgsLength))}

    --// Log return values
    Data.ReturnValues = ReturnValues

    return ReturnValues
end

function Process:UpdateAllRemoteData(Key: string, Value)
    local RemoteOptions = self.RemoteOptions
	for RemoteID, Data in next, RemoteOptions do
		Data[Key] = Value
	end
end

function Process:GetRemoteData(Id: string)
    local RemoteOptions = self.RemoteOptions

    --// Check for existing remote data
	local Existing = RemoteOptions[Id]
	if Existing then return Existing end
	
    --// Base remote data
	local Data = {
		Excluded = false,
		Blocked = false
	}

	RemoteOptions[Id] = Data
	return Data
end

--// The communication creates a different table address
--// Recived tables will not be the same
function Process:SetRemoteData(Id: string, RemoteData: table)
    local RemoteOptions = self.RemoteOptions
    RemoteOptions[Id] = RemoteData
end

function Process:UpdateRemoteData(Id: string, RemoteData: table)
    Communication:Communicate("RemoteData", Id, RemoteData)
end

return Process
end)()},
	Hook = {"base64", (function()
local Hook = {
	OrignalNamecall = nil,
	OrignalIndex = nil,
}

type table = {
	[any]: any
}

type MetaCallback = (Instance, ...any)->...any

--// Modules
local Process

--// This is a custom hookmetamethod function, feel free to replace with your own
--// The callback is expected to return a nil value sometimes which should be ingored
local function HookMetaMethod(self, Call: string, Callback: MetaCallback): MetaCallback
	local OriginalFunc
	OriginalFunc = hookmetamethod(self, Call, function(...)
		--// Invoke callback and check for a reponce otherwise ignored
		local ReturnValues = Callback(...)
		if ReturnValues then
			local Length = table.maxn(ReturnValues)
			return unpack(ReturnValues, 1, Length)
		end

		--// Invoke orignal function
		return OriginalFunc(...)
	end)
	return OriginalFunc
end

--// Replace metatable function method, this can be a workaround on some games if hookmetamethod is detected
--// To use this, just uncomment it and comment out the method above
--//
-- local function HookMetaMethod(self, Call: string, Callback: MetaCallback): MetaCallback
-- 	local Metatable = getrawmetatable(self)
-- 	local OriginalFunc = rawget(Metatable, Call)
	
-- 	--// Replace function
-- 	setreadonly(Metatable, false)
-- 	rawset(Metatable, Call, function(...)
-- 		--// Invoke callback and check for a reponce otherwise ignored
-- 		local ReturnValues = Callback(...)
-- 		if ReturnValues then
-- 			local Length = table.maxn(ReturnValues)
-- 			return unpack(ReturnValues, 1, Length)
-- 		end

-- 		return OriginalFunc(...)
-- 	end)
-- 	setreadonly(Metatable, true)

-- 	return OriginalFunc
-- end

local function Merge(Base: table, New: table)
	for Key, Value in next, New do
		Base[Key] = Value
	end
end

function Hook:RunOnActors(Code: string, ChannelId: number)
	if not getactors then return end
	for _, Actor in getactors() do 
		run_on_actor(Actor, Code, ChannelId)
	end
end

local function ProcessRemote(OriginalFunc, MetaMethod: string, self, Method: string, ...)
	return Process:ProcessRemote({
		Remote = self,
		Method = Method,
		OriginalFunc = OriginalFunc,
		MetaMethod = MetaMethod,
		TransferType = "Send",
		Args = {...}
	})
end

local function __IndexCallback(OriginalIndex, self, Method: string)
	--// Check if the orignal value is a function
	local OriginalFunc = OriginalIndex(self, Method)
	if typeof(OriginalFunc) ~= "function" then return end

	--// Check if the Object is allowed 
	if not Process:RemoteAllowed(self, "Send", Method) then return end

	--// Process the remote data
	return {function(self, ...) -- Possible detection?
		return ProcessRemote(OriginalFunc, "__index", self, Method, ...)
	end}
end

function Hook:HookMeta()
	--// Namecall hook
	local On; On = HookMetaMethod(game, "__namecall", function(self, ...)
		local Method = getnamecallmethod()
		return ProcessRemote(On, "__namecall", self, Method, ...)
	end)
	--// Index call hook
	local Oi; Oi = HookMetaMethod(game, "__index", function(...)
		return __IndexCallback(Oi, ...)
	end)

	Merge(self, {
		OrignalNamecall = On,
		OrignalIndex = Oi,
	})
end

function Hook:Index(Object: Instance, Key: string)
	local OrignalIndex = self.OrignalIndex
	if OrignalIndex then
		return OrignalIndex(Object, Key)
	end

	return Object[Key]
end

function Hook:Init(Data)
    local Modules = Data.Modules
	Process = Modules.Process
end

function Hook:PushConfig(Overwrites)
    Merge(self, Overwrites)
end

function Hook:HookClientInvoke(Remote, Method, Callback): ((...any) -> ...any)?
	local PreviousFunction = getcallbackvalue(Remote, Method)
	Remote[Method] = Callback

	return PreviousFunction
end

function Hook:MultiConnect(Remotes)
	for _, Remote in next, Remotes do
		Hook:ConnectClientRecive(Remote)
	end
end

function Hook:ConnectClientRecive(Remote)
	--// Check if the Remote class is allowed for receiving
	local Allowed = Process:RemoteAllowed(Remote, "Receive")
	if not Allowed then return end

	--// Check if the Object has Remote class data
    local ClassData = Process:GetClassData(Remote)
    if not ClassData then return end

    local IsRemoteFunction = ClassData.IsRemoteFunction
    local Method = ClassData.Receive[1]
	local PreviousFunction = nil

	--// New callback function
	local function Callback(...)
        return Process:ProcessRemote({
            Remote = Remote,
            Method = Method,
            OriginalFunc = PreviousFunction,
            IsReceive = true,
            MetaMethod = "Connect",
            Args = {...}
        })
	end

	--// Connect remote
	if not IsRemoteFunction then
   		Remote[Method]:Connect(Callback)
	else -- Remote functions
		pcall(function()
			self:HookClientInvoke(Remote, Method, Callback)
		end)
	end
end

function Hook:BeginService(Libraries, ExtraData, ChannelId: number)
	local ReturnSpoofs = Libraries.ReturnSpoofs
	local ProcessLib = Libraries.Process
	local Communication = Libraries.Communication

	local InitData = {
		Modules = {
			ReturnSpoofs = ReturnSpoofs,
			Communication = Communication,
			Process = ProcessLib,
			Hook = self
		}
	}
	
	--// Communication configuration
	local Channel = Communication:GetChannel(ChannelId)
	Communication:Init(InitData)
	Communication:SetChannel(Channel)
	Communication:AddConnection(function(Type: string, Id: string, RemoteData)
		if Type ~= "RemoteData" then return end
		ProcessLib:SetRemoteData(Id, RemoteData)
	end)
	
	--// Process configuration
	ProcessLib:Init(InitData)
	ProcessLib:SetChannelId(ChannelId)
	ProcessLib:SetExtraData(ExtraData)

	--// Hook configuration
	self:Init(InitData)
	self:HookMeta()
end

return Hook
end)()},
	Flags = {"base64", (function()
type FlagValue = boolean|number|any
type Flag = {
    Value: FlagValue,
    Label: string,
    Category: string
}
type Flags = {
    [string]: Flag
}

local Module = {
    Flags = {
        PreventRenaming = {
            Value = false,
            Label = "No renaming",
        },
        PreventParenting = {
            Value = false,
            Label = "No parenting",
        },
        IgnoreNil = {
            Value = true,
            Label = "Ignore nil parents",
        },
        CheckCaller = {
            Value = false,
            Label = "Ignore exploit calls",
        },
        LogRecives = {
            Value = true,
            Label = "Log receives",
        },
        Paused = {
            Value = false,
            Label = "Paused",
            Keybind = Enum.KeyCode.Q
        },
        KeybindsEnabled = {
            Value = true,
            Label = "Keybinds Enabled"
        },
        FindStringForName = {
            Value = true,
            Label = "Find arg for name"
        },
        UiVisible = {
            Value = true,
            Label = "UI Visible",
            Keybind = Enum.KeyCode.P
        },
        NoTreeNodes = {
            Value = false,
            Label = "No grouping"
        },
    }
}

function Module:GetFlagValue(Name: string): FlagValue
    local Flag = self:GetFlag(Name)
    return Flag.Value
end

function Module:SetFlagValue(Name: string, Value: FlagValue)
    local Flag = self:GetFlag(Name)
    Flag.Value = Value
end

function Module:SetFlagCallback(Name: string, Callback: (...any) -> ...any)
    local Flag = self:GetFlag(Name)
    Flag.Callback = Callback
end

function Module:SetFlagCallbacks(Dict: {})
    for Name, Callback: (...any) -> ...any in next, Dict do 
        self:SetFlagCallback(Name, Callback)
    end
end

function Module:GetFlag(Name: string): Flag
    local AllFlags = self:GetFlags()
    local Flag = AllFlags[Name]
    assert(Flag, "Flag does not exist!")
    return Flag
end

function Module:AddFlag(Name: string, Flag: Flag)
    local AllFlags = self:GetFlags()
    AllFlags[Name] = Flag
end

function Module:GetFlags(): Flags
    return self.Flags
end

return Module
end)()},
	Ui = {"base64", (function()
local Ui = {
	DefaultEditorContent = "--Welcome to Sigma Spy",

    SeasonLabels = { 
        January = "⛄%s⛄", 
        February = "🌨️%s🏂", 
        March = "🌹%s🌺", 
        April = "🐣%s✝️", 
        May = "🐝%s🌞", 
        June = "🪴%s🥕", 
        July = "🌊%s🏖️", 
        August = "☀️%s🌞", 
        September = "🍁%s🍁", 
        October = "🎃%s🎃", 
        November = "🍂%s🍂", 
        December = "🎄%s🎁"
    },
    BaseConfig = {
        Theme = "SigmaSpy",
        Size = UDim2.fromOffset(600, 400),
        NoScroll = true,
    },
	OptionTypes = {
		boolean = "Checkbox",
	},

    Window = nil,
    RandomSeed = Random.new(tick()),
	Logs = setmetatable({}, {__mode = "k"}),
	LogQueue = setmetatable({}, {__mode = "v"}),
} 

type table = {
	[any]: any
}

type Log = {
	Remote: Instance,
	Method: string,
	Args: table,
	IsReceive: boolean?,
	MetaMethod: string?,
	OrignalFunc: ((...any) -> ...any)?,
	CallingScript: Instance?,
	CallingFunction: ((...any) -> ...any)?,
	ClassData: table?,
	ReturnValues: table?,
	RemoteData: table?,
	Id: string,
	Selectable: table,
	HeaderData: table
}

--// Compatibility
local SetClipboard = setclipboard or toclipboard or set_clipboard

--// Libraries
local ReGui = loadstring(game:HttpGet('https://raw.githubusercontent.com/Jsssiee/Dear-ReGui/refs/heads/main/ReGui.lua'))()
local IDEModule = loadstring(game:HttpGet('https://raw.githubusercontent.com/Jsssiee/Dear-ReGui/refs/heads/main/lib/ide.lua'))()

--// Services
local InsertService: InsertService

--// Modules
local Flags
local Generation
local Process
local Hook 
local Config

local ActiveData = nil
local RemotesCount = 0

local TextFont = Font.fromEnum(Enum.Font.Code)
local FontSuccess = false

local function DeepCloneTable(Table)
	local New = {}
	for Key, Value in next, Table do
		New[Key] = typeof(Value) == "table" and DeepCloneTable(Value) or Value
	end
	return New
end

function Ui:SetClipboard(Content: string)
	SetClipboard(Content)
end

function Ui:TurnSeasonal(Text: string): string
    local SeasonLabels = self.SeasonLabels
    local Month = os.date("%B")
    local Base = SeasonLabels[Month]

    return Base:format(Text)
end

function Ui:SetFont(FontJsonFile: string, FontContent: string)
	if not FontJsonFile then return end

	--// Check if the font downloaded successfully
	FontSuccess = FontContent ~= ""
	if not FontSuccess then return end

	--// Load fontface
	local AssetId = getcustomasset(FontJsonFile, false)
	local NewFont = Font.new(AssetId)
	TextFont = NewFont
end

function Ui:FontWasSuccessful()
	if FontSuccess then return end

	--// Switch to DarkTheme instead of the ImGui theme
	local Window = self.Window
	Window:SetTheme("DarkTheme")

	self:ShowModal({
		"Unfortunately your executor was unable to download the font and therefore switched to the Dark theme",
		"\nIf you would like to use the ImGui theme, \nplease download the font (assets/ProggyClean.ttf)",
		"and put put it in your workspace folder\n(Sigma Spy/assets)"
	})
end

function Ui:LoadReGui()
	local ThemeConfig = Config.ThemeConfig
	ThemeConfig.TextFont = TextFont

	--// ReGui
	local PrefabsId = "rbxassetid://" .. ReGui.PrefabsId
	ReGui:DefineTheme("SigmaSpy", ThemeConfig)
	ReGui:Init({
		Prefabs = InsertService:LoadLocalAsset(PrefabsId)
	})
end

function Ui:Init(Data)
    local Modules = Data.Modules
	local Services = Data.Services

	--// Services
	InsertService = Services.InsertService

	--// Modules
	Flags = Modules.Flags
	Generation = Modules.Generation
	Process = Modules.Process
	Hook = Modules.Hook
	Config = Modules.Config

	self:LoadReGui()
end

type CreateButtons = {
	Base: table,
	Buttons: table,
	NoTable: boolean?
}
function Ui:CreateButtons(Parent, Data: CreateButtons)
	local Base = Data.Base
	local Buttons = Data.Buttons
	local NoTable = Data.NoTable

	--// Create table layout
	if not NoTable then
		Parent = Parent:Table({
			MaxColumns = 3
		}):NextRow()
	end

	--// Create buttons
	for _, Button in next, Buttons do
		local Container = Parent
		if not NoTable then
			Container = Parent:NextColumn()
		end

		ReGui:CheckConfig(Button, Base)
		Container:Button(Button)
	end
end

function Ui:CreateWindow()
    local BaseConfig = self.BaseConfig

	--// Create Window
    local Window = ReGui:Window(BaseConfig)
    self.Window = Window
    self:AuraCounterService()

	--// Check if the font was successfully downloaded
	self:FontWasSuccessful()

	--// UiVisible flag callback
	Flags:SetFlagCallback("UiVisible", function(self, Visible)
		Window:SetVisible(Visible)
	end)

	return Window
end

function Ui:ShowModal(Lines: table)
	local Window = self.Window
	local Message = table.concat(Lines, "\n")

	local ModalWindow = Window:PopupModal({
		Title = "Sigma Spy"
	})
	ModalWindow:Label({
		Text = Message,
		RichText = true,
		TextWrapped = true
	})
	ModalWindow:Button({
		Text = "Okay",
		Callback = function()
			ModalWindow:ClosePopup()
		end,
	})
end

function Ui:ShowUnsupported(FuncName: string)
	Ui:ShowModal({
		"Unfortunately Sigma Spy is not supported on your executor",
		`\n\nMissing function: {FuncName}`
	})
end

function Ui:CreateOptionsForDict(Parent, Dict: table, Callback)
	local Options = {}

	--// Dictonary wrap
	for Key, Value in next, Dict do
		Options[Key] = {
			Value = Value,
			Label = Key,
			Callback = function(_, Value)
				Dict[Key] = Value

				--// Invoke callback
				if not Callback then return end
				Callback()
			end
		}
	end

	--// Create elements
	self:CreateElements(Parent, Options)
end

function Ui:CheckKeybindLayout(Container, KeyCode: Enum.KeyCode, Callback)
	if not KeyCode then return Container end

	--// Create Row layout
	Container = Container:Row({
		HorizontalFlex = Enum.UIFlexAlignment.SpaceBetween
	})

	--// Add Keybind element
	Container:Keybind({
		Label = "",
		Value = KeyCode,
		LayoutOrder = 2,
		Callback = function()
			--// Check if keybinds are enabled
			local Enabled = Flags:GetFlagValue("KeybindsEnabled")
			if not Enabled then return end

			--// Invoke callback
			Callback()
		end,
	})

	return Container
end

function Ui:CreateElements(Parent, Options)
	local OptionTypes = self.OptionTypes
	
	--// Create table layout
	local Table = Parent:Table({
		MaxColumns = 3
	}):NextRow()

	for Name, Data in next, Options do
		local Value = Data.Value
		local Type = typeof(Value)

		--// Add missing values into options table
		ReGui:CheckConfig(Data, {
			Class = OptionTypes[Type],
			Label = Name,
		})
		
		--// Check if a element type exists for value type
		local Class = Data.Class
		assert(Class, `No {Type} type exists for option`)

		local Container = Table:NextColumn()
		local Checkbox = nil

		--// Check for a keybind layout
		local Keybind = Data.Keybind
		Container = self:CheckKeybindLayout(Container, Keybind, function()
			Checkbox:Toggle()
		end)
		
		--// Create column and element
		Checkbox = Container[Class](Container, Data)
	end
end

--// Boiiii what did you say about Sigma Spy 💀💀
function Ui:DisplayAura()
    local Window = self.Window
    local Rand = self.RandomSeed

    local AURA = Rand:NextInteger(1, 9999999)
    local AURADELAY = Rand:NextInteger(1, 5)

	local Title = ` Sigma Spy - Depso | AURA: {AURA} `
	local Seasonal = self:TurnSeasonal(Title)
    Window:SetTitle(Seasonal)

    wait(AURADELAY)
end

function Ui:AuraCounterService()
    task.spawn(function()
        while true do
            self:DisplayAura()
        end
    end)
end

function Ui:CreateWindowContent(Window)
    --// Window group
    local Layout = Window:List({
        UiPadding = 2,
        HorizontalFlex = Enum.UIFlexAlignment.Fill,
        VerticalFlex = Enum.UIFlexAlignment.Fill,
        FillDirection = Enum.FillDirection.Vertical,
        Fill = true
    })

    self.RemotesList = Layout:Canvas({
        Scroll = true,
        UiPadding = 5,
        AutomaticSize = Enum.AutomaticSize.None,
        FlexMode = Enum.UIFlexMode.None,
        Size = UDim2.new(0, 130, 1, 0)
    })

	local InfoSelector = Layout:TabSelector({
        NoAnimation = true,
        Size = UDim2.new(1, -130, 0.4, 0),
    })

	self:MakeEditorTab(InfoSelector, Window)
	self:MakeOptionsTab(InfoSelector)
	self.InfoSelector = InfoSelector
	self.CanvasLayout = Layout
end

function Ui:MakeOptionsTab(InfoSelector)
	--// TabSelector
	local OptionsTab = InfoSelector:CreateTab({
		Name = "Options"
	})

	--// Add global options
	OptionsTab:Separator({Text="Logs"})
	self:CreateButtons(OptionsTab, {
		Base = {
			Size = UDim2.new(1, 0, 0, 20),
			AutomaticSize = Enum.AutomaticSize.Y,
		},
		Buttons = {
			{
				Text = "Clear logs",
				Callback = function()
					local Tab = ActiveData and ActiveData.Tab or nil

					--// Remove the Remote tab
					if Tab then
						InfoSelector:RemoveTab(Tab)
					end

					--// Clear all log elements
					ActiveData = nil
					self:ClearLogs()
				end,
			},
			{
				Text = "Clear blocks",
				Callback = function()
					Process:UpdateAllRemoteData("Blocked", false)
				end,
			},
			{
				Text = "Clear excludes",
				Callback = function()
					Process:UpdateAllRemoteData("Excluded", false)
				end,
			}
		}
	})

	--// Flag options
	OptionsTab:Separator({Text="Settings"})
	self:CreateElements(OptionsTab, Flags:GetFlags())

	self:AddDetailsSection(OptionsTab)
end

function Ui:AddDetailsSection(OptionsTab)
	OptionsTab:Separator({Text="Infomation"})
	OptionsTab:BulletText({
		Rows = {
			"Sigma spy - Created by depso!",
			"Thank you to syn for your suggestions and testing",
			"I wish potassium wasn't so crudely produced",
			"Boiiiiii what did you say about Sigma Spy 💀💀 (+999999 AURA)"
		}
	})
end

local function MakeActiveDataCallback(Func: string)
	return function()
		if not ActiveData then return end
		return ActiveData[Func](ActiveData)
	end
end

function Ui:MakeEditorTab(InfoSelector, Window)
	local SyntaxColors = Config.SyntaxColors
	local Default = self.DefaultEditorContent

	--// IDE
	local CodeEditor = IDEModule.CodeFrame.new({
		Editable = false,
		FontSize = 13,
		Colors = SyntaxColors,
		FontFace = TextFont,
		Text = Default
	})
	
	local EditorTab = InfoSelector:CreateTab({
		Name = "Editor"
	})

	--// Configure IDE frame
	ReGui:ApplyFlags({
		Object = CodeEditor.Gui,
		WindowClass = Window,
		Class = {
			--Border = true,
			--Size = UDim2.fromScale(0.75, 0.4)
			Fill = true,
			Active = true,
			Parent = EditorTab:GetObject(),
			BackgroundTransparency = 1,
		}
	})

	--// Buttons
	local ButtonsRow = EditorTab:Row()
	self:CreateButtons(ButtonsRow, {
		Base = {},
		NoTable = true,
		Buttons = {
			{
				Text = "Copy",
				Callback = function()
					local Script = CodeEditor:GetText()
					Ui:SetClipboard(Script)
				end
			},
			{
				Text = "Repeat call",
				Callback = MakeActiveDataCallback("RepeatCall")
			},
			{
				Text = "Get return",
				Callback = MakeActiveDataCallback("GetReturn")
			},
			{
				Text = "Generate info",
				Callback = MakeActiveDataCallback("GenerateInfo")
			},
			{
				Text = "Decompile script",
				Callback = MakeActiveDataCallback("Decompile")
			}
		}
	})
	
	self.CodeEditor = CodeEditor
end

function Ui:SetFocusedRemote(Data)
	--// To display in the table
	local Display = {
		"MetaMethod",
		"Method",
		"Remote",
		"CallingScript",
		"CallingActor",
		"IsActor",
		"Id"
	}
	
	--// Unpack remote data
	local Remote = Data.Remote
	local Method = Data.Method
	local MetaMethod = Data.MetaMethod
	local IsReceive = Data.IsReceive
	local Script = Data.CallingScript
	local Function = Data.CallingFunction
	local ClassData = Data.ClassData
	local HeaderData = Data.HeaderData
	local Args = Data.Args
	local Id = Data.Id

	--// Unpack info
	local RemoteData = Process:GetRemoteData(Id)
	local SourceScript = rawget(getfenv(Function), "script")
	local IsRemoteFunction = ClassData.IsRemoteFunction

	--// UI data
	local InfoSelector = self.InfoSelector
	local CodeEditor = self.CodeEditor
	local TabFocused = false
	
	--// Remote previous remote tab
	if ActiveData then
		local Tab = ActiveData.Tab
		local Selectable = ActiveData.Selectable
		local ActiveTab = InfoSelector.ActiveTab

		TabFocused = InfoSelector:CompareTabs(ActiveTab, Tab)
		InfoSelector:RemoveTab(Tab)
		Selectable:SetSelected(false)
	end

	--// Set this log to be selected
	ActiveData = Data
	Data.Selectable:SetSelected(true)

	local function SetIDEText(...)
		CodeEditor:SetText(...)
	end

	--// Functions
	function Data:RepeatCall()
		local Signal = Hook:Index(Remote, Method)
		if IsReceive then
			firesignal(Signal, unpack(Args))
		else
			Signal(Remote, unpack(Args))
		end
	end
	function Data:GetReturn()
		local ReturnValues = Data.ReturnValues

		if not IsRemoteFunction then
			SetIDEText("-- Remote is not a function bozo (-9999999 AURA)")
			return
		end
		if not ReturnValues then
			SetIDEText("-- No return values (-9999999 AURA)")
			return
		end

		--// Generate script
		local Script = Generation:TableScript(ReturnValues)
		SetIDEText(Script)
	end
	function Data:GenerateInfo()
		--// Reject client events
		if IsReceive then 
			local Script = "-- Boiiiii what did you say about IsReceive (-9999999 AURA)\n"
			Script ..= "\n-- Voice message: ▶ .ılıılıılıılıılıılı. 0:69\n"

			SetIDEText(Script)
			return 
		end
		
		local Connections = {}
		local FunctionInfo = {
			["Script"] = {
				["SourceScript"] = SourceScript,
				["CallingScript"] = Script
			},
			["Remote"] = {
				["Remote"] = Remote,
				["RemoteID"] = Id,
				["Method"] = Method
			},
			["MetaMethod"] = MetaMethod,
			["IsActor"] = Data.IsActor,
			["CallingFunction"] = Function,
			["Connections"] = Connections
		}

		--// Some closures may not be lua
		if islclosure(Function) then
			FunctionInfo["UpValues"] = debug.getupvalues(Function)
			FunctionInfo["Constants"] = debug.getconstants(Function)
		end
		
		--// Get remote connections
		local ReceiveMethods = ClassData.Receive
		for _, Method: string in next, ReceiveMethods do
			pcall(function() --TODO GETCALLBACKVALUE
				local Signal = Hook:Index(Remote, Method)
				Connections[Method] = Generation:ConnectionsTable(Signal)
			end)
		end

		--// Generate script
		local Script = Generation:TableScript(FunctionInfo)
		SetIDEText(Script)
	end
	function Data:Decompile()
		--// Check if decompile function exists
		if not decompile then 
			SetIDEText("--Exploit is missing 'decompile' function (-9999999 AURA)")
			return 
		end

		--// Check if script exists
		if not Script then 
			SetIDEText("--Script is missing (-9999999 AURA)")
			return
		end

		SetIDEText("--Decompiling... +9999999 AURA (mango phonk)")

		--// Decompile script
		local Decompiled = decompile(Script)
		local Source = "--BOOIIII THIS IS SO TUFF FLIPPY SKIBIDI AURA (SIGMA SPY)\n"
		Source ..=  Decompiled

		SetIDEText(Source)
	end

	--// Create remote details tab
	local Tab = InfoSelector:CreateTab({
		Name = `Remote: {Remote}`,
		Focused = TabFocused
	})
	Data.Tab = Tab
	
	--// Create new parser
	local Module = Generation:NewParser()
	local Parser = Module.Parser
	
	--// RemoteOptions
	self:CreateOptionsForDict(Tab, RemoteData, function()
		Process:UpdateRemoteData(Id, RemoteData)
	end)

	--// Instance options
	self:CreateButtons(Tab, {
		Base = {
			Size = UDim2.new(1, 0, 0, 20),
			AutomaticSize = Enum.AutomaticSize.Y,
		},
		Buttons = {
			{
				Text = "Copy script path",
				Callback = function()
					SetClipboard(Parser:MakePathString({
						Object = Script,
						NoVariables = true
					}))
				end,
			},
			{
				Text = "Copy remote path",
				Callback = function()
					SetClipboard(Parser:MakePathString({
						Object = Remote,
						NoVariables = true
					}))
				end,
			},
			{
				Text = "Remove log",
				Callback = function()
					InfoSelector:RemoveTab(Tab)
					Data.Selectable:Remove()
					HeaderData:Remove()
					ActiveData = nil
				end,
			}
		}
	})

	--// Remote infomation
	local Rows = {"Name", "Value"}
	local DataTable = Tab:Table({
		Border = true,
		RowBackground = true,
		MaxColumns = 2
	})

	--// Table headers
	local HeaderRow = DataTable:HeaderRow()
	for _, Catagory in Rows do
		local Column = HeaderRow:NextColumn()
		Column:Label({Text=Catagory})
	end

	--// Table layout
	for RowIndex, Name in Display do
		local Row = DataTable:Row()
		
		--// Create Columns
		for Count, Catagory in Rows do
			local Column = Row:NextColumn()
			
			--// Value text
			local Value = Catagory == "Name" and Name or Data[Name]
			if not Value then continue end

			Column:Label({Text=`{Value}`})
		end
	end
	
	--// Generate script
	local Parsed = Generation:RemoteScript(Module, Data)
	SetIDEText(Parsed)
end

function Ui:GetRemoteHeader(Data: Log)
	--// UI data
	local Logs = self.Logs
	local RemotesList = self.RemotesList

	--// Remote info
	local Id = Data.Id
	local Remote = Data.Remote

	--// NoTreeNodes
	local NoTreeNodes = Flags:GetFlagValue("NoTreeNodes")

	--// Check for existing TreeNode
	local Existing = Logs[Id]
	if Existing then return Existing end

	--// Header data
	local HeaderData = {	
		LogCount = 0
	}

	--// Increment treenode count
	RemotesCount += 1

	--// Create new treenode element
	if not NoTreeNodes then
		HeaderData.TreeNode = RemotesList:TreeNode({
			LayoutOrder = -1 * RemotesCount,
			Title = `{Remote}`
		})
	end

	function HeaderData:LogAdded()
		--// Increment log count
		self.LogCount += 1
		return self
	end

	function HeaderData:Remove()
		--// Remove TreeNode
		local TreeNode = self.TreeNode
		if TreeNode then
			TreeNode:Remove()
		end

		--// Clear tables from memory
		Logs[Id] = nil
		table.clear(HeaderData)
	end

	Logs[Id] = HeaderData
	return HeaderData
end

function Ui:ClearLogs()
	local Logs = self.Logs
	local RemotesList = self.RemotesList

	--// Clear all elements
	RemotesCount = 0
	RemotesList:ClearChildElements()

	--// Clear logs from memory
	table.clear(Logs)
end

function Ui:QueueLog(Data)
	local LogQueue = self.LogQueue
    table.insert(LogQueue, Data)
end

function Ui:ProcessLogQueue()
	local Queue = self.LogQueue
    if #Queue <= 0 then return end

	--// Create a log element for each in the Queue
    for Index, Data in next, Queue do
        self:CreateLog(Data)
        table.remove(Queue, Index)
    end
end

function Ui:BeginLogService()
	coroutine.wrap(function()
		while true do
			Ui:ProcessLogQueue()
			wait()
		end
	end)()
end

function Ui:CreateLog(Data: Log)
	--// Unpack log data
    local Remote = Data.Remote
	local Method = Data.Method
    local Args = Data.Args
    local IsReceive = Data.IsReceive
	local Id = Data.Id
	
	local IsNilParent = Hook:Index(Remote, "Parent") == nil
	local RemoteData = Process:GetRemoteData(Id)

	--// Paused
	local Paused = Flags:GetFlagValue("Paused")
	if Paused then return end

	--// Check caller (Ignore exploit calls)
	local CheckCaller = Flags:GetFlagValue("CheckCaller")
	if CheckCaller and not checkcaller() then return end

	--// IgnoreNil
	local IgnoreNil = Flags:GetFlagValue("IgnoreNil")
	if IgnoreNil and IsNilParent then return end

    --// LogRecives check
	local LogRecives = Flags:GetFlagValue("LogRecives")
	if not LogRecives and IsReceive then return end

	--// NoTreeNodes
	local NoTreeNodes = Flags:GetFlagValue("NoTreeNodes")

    --// Excluded check
    if RemoteData.Excluded then return end

	--// Deep clone data
	local ClonedArgs = DeepCloneTable({unpack(Args)})
	Data.Args = ClonedArgs

	local Color = Config.MethodColors[Method:lower()]
	local Text = NoTreeNodes and `{Remote} | {Method}` or Method

	--// FindStringForName check
	local FindString = Flags:GetFlagValue("FindStringForName")
	if FindString then
		for _, Arg in next, ClonedArgs do
			if typeof(Arg) == "string" then
				Text = `{Arg:sub(1,15)} | {Text}`
				break
			end
		end
	end

	--// HeaderData
	local HeaderData = self:GetRemoteHeader(Data):LogAdded()
	local RemotesList = self.RemotesList

	local LogCount = HeaderData.LogCount
	local TreeNode = HeaderData.TreeNode 
	local Parent = TreeNode or RemotesList

	--// Increase log count - TreeNodes are in GetRemoteHeader function
	if NoTreeNodes then
		RemotesCount += 1
		LogCount = RemotesCount
	end

    local function SetFocused()
		self:SetFocusedRemote(Data)
    end

    --// Create focus button
	Data.HeaderData = HeaderData
	Data.Selectable = Parent:Selectable({
		Text = Text,
        LayoutOrder = -1 * LogCount,
        Callback = SetFocused,
		TextColor3 = Color,
		TextXAlignment = Enum.TextXAlignment.Left
    })
end

return Ui
end)()},
	Generation = {"base64", (function()
local Generation = {}

type table = {
	[any]: any
}

--// Libraries
local ParserModule = loadstring(game:HttpGet('https://raw.githubusercontent.com/Leon1324765s/Roblox-parser/refs/heads/main/main.lua'))()

--// Parser
function ParserModule:Import(Name: string)
	local Url = `{self.ImportUrl}/{Name}.lua`
	return loadstring(game:HttpGet(Url))()
end
ParserModule:Load()

--// Modules
local Config
local Hook

local ThisScript = script

function Generation:Init(Configuration: table)
    local Modules = Configuration.Modules

	--// Modules
	Config = Modules.Config
	Hook = Modules.Hook
end

function Generation:SetSwapsCallback(Callback: (Interface: table) -> ())
	self.SwapsCallback = Callback
end

function Generation:GetBase(Module): string
	local Code = "-- Generated with sigma spy BOIIIIIIIII (+9999999 AURA)\n\n"

	--// Generate variables code
	Code ..= Module.Parser:MakeVariableCode({
		"Services", "Variables", "Remote"
	})

	return Code
end

function Generation:GetSwaps()
	local Func = self.SwapsCallback
	local Swaps = {}

	local Interface = {}
	function Interface:AddSwap(Object: Instance, Data: table)
		if not Object then return end
		Swaps[Object] = Data
	end

	--// Invoke GetSwaps function
	Func(Interface)

	return Swaps
end

function Generation:PickVariableName()
	local Names = Config.VariableNames
	return Names[math.random(1, #Names)]
end

function Generation:NewParser()
	local VariableName = self:PickVariableName()

	--// Swaps
	local Swaps = self:GetSwaps()

	--// Load parser module
	local Module = ParserModule:New({
		VariableBase = VariableName,
		Swaps = Swaps,
		IndexFunc = function(...)
			return Hook:Index(...)
		end,
	})

	return Module
end

type RemoteScript = {
	Remote: Instance,
	IsReceive: boolean?,
	Args: table,
	Method: string
}
function Generation:RemoteScript(Module, Data: RemoteScript): string
	local Remote = Data.Remote
	local IsReceive = Data.IsReceive
	local Args = Data.Args
	local Method = Data.Method

	local ClassName = Hook:Index(Remote, "ClassName")
	local IsNilParent = Hook:Index(Remote, "Parent") == nil
	
	local Variables = Module.Variables
	local Formatter = Module.Formatter
	local Parser = Module.Parser
	
	--// Pre-render variables
	Variables:PrerenderVariables(Args, {"Instance"})

	--// Parse arguments
	local ParsedArgs, ItemsCount = Parser:ParseTableIntoString({
		NoBrackets = true,
		Table = Args
	})

	--// Create remote variable
	local RemoteVariable = Variables:MakeVariable({
		Value = Formatter:Format(Remote, {
			NoVariableCreate = true
		}),
		Comment = IsNilParent and "Remote parent is nil" or ClassName,
		Lookup = Remote,
		Name = Formatter:MakeName(Remote), --ClassName,
		Class = "Remote"
	})

	--// Make code
	local Code = self:GetBase(Module)
	
	--// Firesignal script for client recieves
	if IsReceive then
		local Second = ItemsCount == 0 and "" or `, {ParsedArgs}`
		local Signal = `{RemoteVariable}.{Method}`

		Code ..= `\n-- This data was received from the server`
		Code ..= `\nfiresignal({Signal}{Second})`
		return Code
	end
	
	--// Remote invoke script
	Code ..= `\n{RemoteVariable}:{Method}({ParsedArgs})`
	return Code
end

function Generation:ConnectionsTable(Signal: RBXScriptSignal): table
	local Connections = getconnections(Signal)
	local DataArray = {}

	for _, Connection in next, Connections do
		local Function = Connection.Function
		local Script = rawget(getfenv(Function), "script")

		--// Skip if self
		if Script == ThisScript then continue end

		--// Connection data
		local Data = {
			Function = Function,
			State = Connection.State,
			Script = Script
		}

		table.insert(DataArray, Data)
	end

	return DataArray
end

function Generation:TableScript(Table: table)
	local Module = self:NewParser()

	--// Pre-render variables
	Module.Variables:PrerenderVariables(Table, {"Instance"})

	--// Parse arguments
	local ParsedTable = Module.Parser:ParseTableIntoString({
		Table = Table
	})

	--// Generate script
	local Code = self:GetBase(Module)
	Code ..= `\nreturn {ParsedTable}`

	return Code
end

return Generation
end)()},
	Communication = {"base64", (function()
--// Debug ID interface
local DebugIdRemote = Instance.new("BindableFunction")

--// Module
local Module = {
    CommCallbacks = {},
    DebugIdRemote = DebugIdRemote,
}

--// Modules
local Hook

local Channel

local InvokeGetDebugId = DebugIdRemote.Invoke
function DebugIdRemote.OnInvoke(Object: Instance): string
	return Object:GetDebugId()
end

function Module:Init(Data)
    local Modules = Data.Modules
    Hook = Modules.Hook
end

function Module:SetChannel(NewChannel: number)
    Channel = NewChannel
end

function Module:Warn(...)
    self:Communicate("Warn", ...)
end

function Module:QueueLog(Data)
    self:Communicate("QueueLog", Data)
end

function Module:GetDebugId(Object: Instance): string
	return InvokeGetDebugId(DebugIdRemote, Object)
end

function Module:AddCommCallback(Type: string, Callback: (...any) -> ...any)
    local CommCallbacks = self.CommCallbacks
    CommCallbacks[Type] = Callback
end

function Module:GetCommCallback(Type: string): (...any) -> ...any
    local CommCallbacks = self.CommCallbacks
    return CommCallbacks[Type]
end

function Module:Communicate(...)
    local Fire = Hook:Index(Channel, "Fire")
    Fire(Channel, ...)
end

function Module:AddConnection(Callback): RBXScriptConnection
    local Event = Hook:Index(Channel, "Event")
    return Event:Connect(Callback)
end

function Module:AddDefaultCallbacks(Event: BindableEvent)
    self:AddCommCallback("Warn", function(...)
        warn(...)
    end)
end

function Module:CreateChannel(): number
    local ChannelID, Event = create_comm_channel()

    --// Connect GetCommCallback function
    Event.Event:Connect(function(Type: string, ...)
        local Callback = self:GetCommCallback(Type)
        if Callback then
            Callback(...)
        end
    end)

    --// Add default communication callbacks
    self:AddDefaultCallbacks(Event)

    return ChannelID, Event
end

function Module:GetChannel(ChannelId: number)
    return get_comm_channel(ChannelId)
end

function Module:WaitFor(For)
    local Args
    local Callback = function(Type: string, ...)
        if Type ~= For then return end
        Args = {...}
    end

    --// Connection
    local Connection = self:AddConnection(Callback)

    --// Wait for arguments
    while not Args do task.wait() end

    --// Success
    Connection:Disconnect()
    return Args
end

function Module:Request(Type, WaitFor, ...)
    self:Communicate(Type, WaitFor, ...)
    return self:WaitFor(WaitFor)
end

return Module
end)()}
}

--// Services
local Players: Players = Services.Players

--// Dependencies
local Modules = Files:LoadLibraries(Scripts)
local Process = Modules.Process
local Hook = Modules.Hook
local Ui = Modules.Ui
local Generation = Modules.Generation
local Communication = Modules.Communication
local Config = Modules.Config

--// Use custom font (optional)
local FontContent = Files:GetAsset("ProggyClean.ttf", true)
local FontJsonFile = Files:CreateFont("ProggyClean", FontContent)
Ui:SetFontFile(FontJsonFile)

--// Load modules
Process:CheckConfig(Config)
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
