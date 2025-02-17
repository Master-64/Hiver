// *****************************************************
// *				 Hiver by Master_64				   *
// *		  Copyrighted (c) Master_64, 2024		   *
// *   May be modified but not without proper credit!  *
// *****************************************************


class HModLoader extends MInfo
	config(Hiver);


struct ModInfo
{
	var string ModDirectory, Name, Blurb, Description, Version, Langauge, Authors, Coauthors, Others, ModType, ModFileName, LaunchOptions, MutatorClassName, MapLoadWhiteList;
	var bool InstantiateOnMapLoad;
	var byte ScriptLoadPriority;
};

var MutHiver Hiver;
var config array<ModInfo> ModInfos;
var bool bReadyToPlay;

// Temp stuff
var string sURL;
var bool bSkipMovies;


event PostLoadGame(bool bLoadFromSaveGame)
{
	if(!bLoadFromSaveGame)
	{
		if(Caps(U.GetCurrentMap()) == "SH2_PREAMBLE")
		{
			class'HVersion'.static.DebugLog("Starting up Hiver...");

			ChainloadMods();

			Hiver.ModLog.FlushLog();
			
			GotoState('IntroMovies');

			return;
		}

		GotoState('InitModLoader');
	}
}

function ChainloadMods()
{
	local int i;
	local string sMutators;

	class'HVersion'.static.DebugLog("Beginning to chainload all mods...");

	ModInfos.Remove(0, ModInfos.Length);

	// Get all mod infos
	for(i = 0; i < 100000; i++)
	{
		// This will return true when all mods have been iterated through
		if(InStr(Localize("Info", "Name", "..\\Mods\\Mod" $ string(i) $ "\\Mod"), "Mod.Info.Name") != -1)
		{
			class'HVersion'.static.DebugLog("A 'No localization' log should be above this log. This is fine.");

			break;
		}

		ModInfos.Insert(ModInfos.Length, 1);

		ModInfos[i].ModDirectory = "..\\Mods\\Mod" $ string(i);
		ModInfos[i].Name = Localize("Info", "Name", "..\\Mods\\Mod" $ string(i) $ "\\Mod");
		ModInfos[i].Blurb = Localize("Info", "Blurb", "..\\Mods\\Mod" $ string(i) $ "\\Mod");
		ModInfos[i].Description = Localize("Info", "Description", "..\\Mods\\Mod" $ string(i) $ "\\Mod");
		ModInfos[i].Version = Localize("Info", "Version", "..\\Mods\\Mod" $ string(i) $ "\\Mod");
		ModInfos[i].Langauge = Localize("Info", "Langauge", "..\\Mods\\Mod" $ string(i) $ "\\Mod");
		ModInfos[i].Authors = Localize("Info", "Authors", "..\\Mods\\Mod" $ string(i) $ "\\Mod");
		ModInfos[i].Coauthors = Localize("Info", "Coauthors", "..\\Mods\\Mod" $ string(i) $ "\\Mod");
		ModInfos[i].Others = Localize("Info", "Others", "..\\Mods\\Mod" $ string(i) $ "\\Mod");
		ModInfos[i].ModType = Localize("ModLoader", "ModType", "..\\Mods\\Mod" $ string(i) $ "\\Mod");
		ModInfos[i].ModFileName = Localize("ModLoader", "ModFileName", "..\\Mods\\Mod" $ string(i) $ "\\Mod");
		ModInfos[i].MutatorClassName = Localize("ModLoader", "MutatorClassName", "..\\Mods\\Mod" $ string(i) $ "\\Mod");
		ModInfos[i].InstantiateOnMapLoad = bool(Localize("ModInstantiation", "InstantiateOnMapLoad", "..\\Mods\\Mod" $ string(i) $ "\\Mod"));
		ModInfos[i].MapLoadWhiteList = Localize("ModInstantiation", "MapLoadWhiteList", "..\\Mods\\Mod" $ string(i) $ "\\Mod");
		ModInfos[i].LaunchOptions = Localize("ModInstantiation", "LaunchOptions", "..\\Mods\\Mod" $ string(i) $ "\\Mod");
		ModInfos[i].ScriptLoadPriority = byte(Localize("ModScriptOptions", "ScriptLoadPriority", "..\\Mods\\Mod" $ string(i) $ "\\Mod"));
		
		switch(Caps(ModInfos[i].ModType))
		{
			case "CORE":
				if(Caps(ModInfos[i].LaunchOptions) == "NOVID")
				{
					bSkipMovies = true;
				}
			case "MUTATOR":
				if(Len(sMutators) == 0)
				{
					sMutators = ModInfos[i].ModFileName $ "." $ ModInfos[i].MutatorClassName;
				}
				else
				{
					sMutators = sMutators $ "," $ ModInfos[i].ModFileName $ "." $ ModInfos[i].MutatorClassName;
				}

				break;
			case "SCRIPT":
				break;
			default:
				break;
		}

		class'HVersion'.static.DebugLog(ModInfos[i].Name @ ModInfos[i].Version @ "loaded...");
	}

	if(ModInfos.Length == 0)
	{
		class'HVersion'.static.DebugLog("No mods and no modloader found! Hiver's installation appears to be corrupt. Quitting...");

		U.CC("Quit");

		return;
	}

	class'HVersion'.static.DebugLog("Prepared" @ string(i) @ "mods for loading.");

	SaveConfig();

	if(sMutators == "")
	{
		sURL = "Book_FrontEnd";
	}
	else
	{
		sURL = "Book_FrontEnd?Mutator=" $ sMutators;
	}

	class'HVersion'.static.DebugLog("Chainloading process complete. Loading" @ string(i) @ "mods after map load...");
}

state InitModLoader
{
	Begin:

	while(Hiver == none)
	{
		Sleep(0.000001);
	}

	class'HVersion'.static.DebugLog("Hiver initialized...");

	bReadyToPlay = true;
}

state IntroMovies
{
	Begin:

	U.GetHUD().bHideHud = true;

	if(!bSkipMovies)
	{
		U.FancyPlayMovie("DW_LOGO", true);

		while(U.IsMoviePlaying())
		{
			Sleep(0.000001);
		}

		U.FancyPlayMovie("ACTIVSN", true);

		while(U.IsMoviePlaying())
		{
			Sleep(0.000001);
		}

		U.FancyPlayMovie("KWLOGO", true);

		while(U.IsMoviePlaying())
		{
			Sleep(0.000001);
		}

		U.FancyPlayMovie("HiverLogo", true);

		while(U.IsMoviePlaying())
		{
			Sleep(0.000001);
		}
	}

	// Start the game
	U.CC("Open" @ sURL);
}