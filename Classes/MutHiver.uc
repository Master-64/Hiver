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

		// Process core mutator logic
		// ...
	}
}

event ServerTraveling(string URL, bool bItems)
{
	// local int i;

	ModLoader.SaveConfig();
	ModLog.SaveConfig();

	// for(i = 0; i < ScriptMods.Length; i++)
	// {
	// 	ScriptMods[i].SaveConfig();
	// }

	if(NextMutator != none)
	{
		NextMutator.ServerTraveling(URL, bItems);
	}
}

function RegisterScriptMods()
{
	// Code to load and register all script mods goes here
	local int i;

	class'HVersion'.static.DebugLog("Beginning to register all script mods...");

	// Get all mod infos
	for(i = 0; i < class'HModLoader'.default.ModInfos.Length; i++)
	{
		ScriptMods.Insert(ScriptMods.Length, 1);
		// Todo: support event subscriptions here
		ScriptMods[ScriptMods.Length - 1] = Spawn(class'HScript');
		ScriptMods[ScriptMods.Length - 1].Hiver = self;
		ScriptMods[ScriptMods.Length - 1].Init();

		if(class'HModLoader'.default.ModInfos[i].ModType != "Script")
		{
			continue;
		}

		U.LoadStringArray(ScriptMods[ScriptMods.Length - 1].Script, "..\\Mods\\Mod\\" $ class'HModLoader'.default.ModInfos[i].ModFileName $ ".hs");

		ScriptMods[ScriptMods.Length - 1].StartScript();

		class'HVersion'.static.DebugLog(class'HModLoader'.default.ModInfos[i].Name @ class'HModLoader'.default.ModInfos[i].Version @ "script loaded...");
	}

	class'HVersion'.static.DebugLog("All scripts registered.");
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