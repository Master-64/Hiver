// *****************************************************
// *				 Hiver by Master_64					*
// *		  Copyrighted (c) Master_64, 2024			*
// *   May be modified but not without proper credit!  *
// *****************************************************


class MutHiver extends MMutator
	config(Hiver);


var HModLoader ModLoader;
var HModLog ModLog;
var array<HScript> ScriptMods;


event PostLoadGame(bool bLoadFromSaveGame)
{
	if(!bLoadFromSaveGame)
	{
		ModLoader = Spawn(class'HModLoader');
		ModLoader.Hiver = self;
		
		GotoState('AwaitModLoader');
		
		// Process core mutator logic.
	}
}

event ServerTraveling(string URL, bool bItems)
{
	ModLoader.SaveConfig();
	ModLog.SaveConfig();
	
	if(NextMutator != none)
	{
		NextMutator.ServerTraveling(URL, bItems);
	}
}

function RegisterScriptMods()
{
	// Code to load and register all script mods goes here.
	local int i;
	local array<string> ScriptFile;
	
	class'HVersion'.static.DebugLog("Beginning to register all script mods...");
	
	// Get all mod infos.
	for(i = 0; i < class'HModLoader'.default.ModInfos.Length; i++)
	{
		ScriptMods.Insert(ScriptMods.Length, 1);
		ScriptMods[ScriptMods.Length - 1] = Spawn(class'HScript');
		ScriptMods[ScriptMods.Length - 1].Hiver = self;
		
		if(InStr(Caps(class'HModLoader'.default.ModInfos[i].ModType), "SCRIPT") != -1)
		{
			continue;
		}
		
		// Process script mods...
		
		U.LoadStringArray(ScriptFile, "..\\Mods\\Mod" $ string(i) $ "\\" $ class'HModLoader'.default.ModInfos[i].ModFileName $ ".hs");
		
		if(ScriptFile.Length == 0)
		{
			class'HVersion'.static.DebugLog("Did not find script file" @ class'HModLoader'.default.ModInfos[i].ModFileName $ ".hs.");
			
			continue;
		}
		
		ScriptMods[ScriptMods.Length - 1].Init(ScriptFile);
		
		class'HVersion'.static.DebugLog(class'HModLoader'.default.ModInfos[i].Name @ class'HModLoader'.default.ModInfos[i].Version @ "script loaded...");
	}
	
	class'HVersion'.static.DebugLog("All script mods registered.");
}

state AwaitModLoader
{
	Begin:
	
	while(!ModLoader.bReadyToPlay)
	{
		Sleep(0.000001);
	}
	
	RegisterScriptMods();
}


defaultproperties
{
	bAlwaysTick=true
}