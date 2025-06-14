// *****************************************************
// *				 Hiver by Master_64					*
// *		  Copyrighted (c) Master_64, 2024			*
// *   May be modified but not without proper credit!  *
// *****************************************************


class HModLoader extends MInfo
	config(Hiver);


struct ModInfo
{
	var string ModDirectory, Name, Blurb, Description, Version, Langauge, Authors, Coauthors, Others, ModType, ModFileName, LaunchOptions, MutatorClassName, MapLoadWhiteList;
	var bool InstantiateOnMapLoad;
};

var MutHiver Hiver;
var config array<ModInfo> ModInfos;
var bool bReadyToPlay, bLoadHiver;

// Temporary variables.
var string sURL;
var bool bSkipMovies;


event PostLoadGame(bool bLoadFromSaveGame)
{
	GotoState('InitModLoader');
}

function ChainloadMods()
{
	local array<string> ModTypes, TokenArray;
	local string sMutators;
	local int i, j, k;
	
	class'HVersion'.static.DebugLog("Beginning to chainload all mods...");
	
	ModInfos.Remove(0, ModInfos.Length);
	
	// Get all mod infos.
	for(i = 0; i < 32767; i++)
	{
		// This will return true when all mods have been iterated through.
		if(InStr(Localize("Info", "Name", "..\\Mods\\Mod" $ string(i) $ "\\Mod"), "Mod.Info.Name") != -1)
		{
			class'HVersion'.static.DebugLog("A 'No localization' log should be above this log. This is expected.");
			
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
		
		ModTypes = U.Split(Caps(ModInfos[i].ModType), ",");
		
		for(j = 0; j < ModTypes.Length; j++)
		{
			switch(ModTypes[j])
			{
				case "CORE":
					TokenArray = U.Split(Caps(ModInfos[i].LaunchOptions), ",");
					
					for(k = 0; k < TokenArray.Length; k++)
					{
						if(TokenArray[k] == "NOVID")
						{
							bSkipMovies = true;
						}
					}
					
					break;
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
				default: break;
			}
		}
		
		class'HVersion'.static.DebugLog(ModInfos[i].Name @ ModInfos[i].Version @ "loaded...");
	}
	
	if(ModInfos.Length == 0)
	{
		class'HVersion'.static.DebugLog("No mods and no modloader found! Hiver's installation appears to be corrupt. Quitting...");
		
		Assert(false);
		
		return;
	}
	
	class'HVersion'.static.DebugLog("Prepared" @ string(i) @ "mods for loading.");
	
	SaveConfig();
	
	if(!U.IsShrek22())
	{
		sURL = "Book_FrontEnd";
	}
	else
	{
		sURL = "0_Storybook_Main_Menu";
	}
	
	if(sMutators != "")
	{
		sURL = sURL $ "?Mutator=" $ sMutators;
	}
	
	class'HVersion'.static.DebugLog("Chainloading process complete. Loading" @ string(i) @ "mods after map load...");
}

function bool IsMainMenu()
{
	return (Caps(U.GetCurrentMap()) == "SH2_PREAMBLE") || (U.IsShrek22() && Caps(U.GetCurrentMap()) == "0_PREAMBLE");
}

state InitModLoader
{
	Begin:
	
	bLoadHiver = Caps(Localize("General", "Modded", "Game")) == "TRUE";
	
	if(IsMainMenu())
	{
		if(bLoadHiver)
		{
			class'HVersion'.static.DebugLog("Starting up Hiver...");
			
			ChainloadMods();
			
			Hiver.ModLog.FlushLog();
		}
	}
	else
	{
		while(Hiver == none)
		{
			Sleep(0.000001);
		}
	}
	
	// Verify the status of Hiver.
	if(!bLoadHiver && !IsMainMenu())
	{
		class'HVersion'.static.DebugLog("Hiver is loaded when it is not supposed to be! Unloading Hiver...");
		
		U.UnloadMutators();
		
		GotoState('');
	}
	
	// Startup logic.
	if(!bReadyToPlay)
	{
		class'HVersion'.static.DebugLog("Hiver initialized...");
		
		bReadyToPlay = true;
	}
	
	if(IsMainMenu())
	{
		GotoState('IntroMovies');
	}
}

state IntroMovies
{
	Begin:
	
	U.GetHUD().bHideHud = true;
	
	if(!bSkipMovies)
	{
		if(!U.IsShrek22())
		{
			U.FancyPlayMovie("DW_LOGO", "1024x768,640x480,512x384",,, true);
			
			while(U.IsMoviePlaying())
			{
				Sleep(0.000001);
			}
			
			U.FancyPlayMovie("ACTIVSN", "1024x768,640x480,512x384",,, true);
			
			while(U.IsMoviePlaying())
			{
				Sleep(0.000001);
			}
			
			U.FancyPlayMovie("KWLOGO", "1024x768,640x480,512x384",,, true);
			
			while(U.IsMoviePlaying())
			{
				Sleep(0.000001);
			}
		}
		else
		{
			U.FancyPlayMovie("DW_Logo");
			
			while(U.IsMoviePlaying())
			{
				Sleep(0.000001);
			}
			
			U.FancyPlayMovie("ACT_Logo");
			
			while(U.IsMoviePlaying())
			{
				Sleep(0.000001);
			}
			
			U.FancyPlayMovie("1C_Logo");
			
			while(U.IsMoviePlaying())
			{
				Sleep(0.000001);
			}
			
			U.FancyPlayMovie("EG_Logo");
			
			while(U.IsMoviePlaying())
			{
				Sleep(0.000001);
			}
			
			U.FancyPlayMovie("KW_Logo");
			
			while(U.IsMoviePlaying())
			{
				Sleep(0.000001);
			}
			
			U.FancyPlayMovie("BK_Logo");
			
			while(U.IsMoviePlaying())
			{
				Sleep(0.000001);
			}
		}
		
		if(bLoadHiver)
		{
			U.FancyPlayMovie("Hiver_Logo");
			
			while(U.IsMoviePlaying())
			{
				Sleep(0.000001);
			}
		}
	}
	
	// Start the game.
	if(bLoadHiver)
	{
		U.CC("Open" @ sURL);
	}
	else // Master_64: Shouldn't be in Shrek 2.2 in this part of this class, so I won't add compatibility here.
	{
		U.CC("Open Book_FrontEnd");
	}
}