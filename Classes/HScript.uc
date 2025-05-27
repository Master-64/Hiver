// *****************************************************
// *				 Hiver by Master_64					*
// *		  Copyrighted (c) Master_64, 2024			*
// *   May be modified but not without proper credit!  *
// *****************************************************
// 
// Supports:
// * Commands w/ arguments per-line
// * In-line parentheses for nested commands on the same line
// * Commands with return values
// * Variable registers
// * Command latency
// * Goto & labels
// * Script ending
// * Random number generation
// * Get actor by tag
// * Events
// * Math expressions
// 
// Future Todo:
// * ScriptData saving -- So much work for so little.
// * Add a majority of the CutScript actions -- Again, a lot of work for something that may not be used.
// * Simple conditionals -- Same as above, where I can't see this being used much.
// * Add an event for OnModLoaded -- I can't see anyone realistically needing this, so I'm not adding it yet.


class HScript extends MInfo
	config(Hiver);


struct ScriptDataStruct
{
	var string Value, sName, sDataType;
};

struct GotoStruct
{
	var string sLabel;
	var int iLine;
};

var MutHiver Hiver;
var array<HScriptProcessor> Threads;
var array<string> ThreadEvents;
var array<ScriptDataStruct> ScriptData;
var bool bDebug, bEventTick, bHasTicked, bWasInCutscene, bAwaitingAttack, bAwaitingSpotting;
var float fOldfLastLandedTime;


function Init(array<string> ScriptFile)
{
	local int i, j;
	local HScriptProcessor P;
	
	// Make threads for each sequence in the file.
	
	for(i = 0; i < ScriptFile.Length; i++)
	{
		// Find a sequence.
		if(Left(ScriptFile[i], 1) == "[")
		{
			Threads.Insert(Threads.Length, 1);
			Threads[Threads.Length - 1] = Spawn(class'HScriptProcessor');
			P = Threads[Threads.Length - 1];
			P.HScript = self;
			
			P.sProcessorName = Caps(Mid(ScriptFile[i], 1, Len(ScriptFile[i]) - 2));
			
			i++;
			
			// Get all script lines.
			for(j = i; j < ScriptFile.Length; j++)
			{
				if(Left(ScriptFile[j], 1) == "[" || ScriptFile[j] == "")
				{
					break;
				}
				
				P.Script.Insert(P.Script.Length, 1);
				P.Script[P.Script.Length - 1] = ScriptFile[j];
			}
			
			i = j;
			
			// Any additional logic.
			
			P.ProcessGotos();
			
			// Repeat.
		}
	}
}

event Tick(float DeltaTime)
{
	local bool bInCutscene;
	local float fLastLandedTime;
	
	if(!bEventTick)
	{
		ProcessThreadEvents();
		
		return;
	}
	
	QueueThreadEvent("OnTick");
	
	if(!bHasTicked)
	{
		// First tick logic.
		
		bHasTicked = true;
		
		QueueThreadEvent("OnMapLoaded");
	}
	
	bInCutscene = U.GetPC().bInCutScene();
	
	if(bInCutscene && !bWasInCutscene)
	{
		QueueThreadEvent("OnCinematicCutscenePlay");
	}
	else if(!bInCutscene && bWasInCutscene)
	{
		QueueThreadEvent("OnCinematicCutsceneEnd");
	}
	
	bWasInCutscene = bInCutscene;
	
	fLastLandedTime = KWPawn(U.GetHP()).fLastLandedTime;
	
	if(fOldfLastLandedTime < fLastLandedTime)
	{
		QueueThreadEvent("OnPlayerLand");
	}
	
	fOldfLastLandedTime = fLastLandedTime;
	
	if(U.GetPC().bPressedJump)
	{
		QueueThreadEvent("OnPlayerJump");
	}
	
	if(U.PlayerIsAttacking(SHHeroPawn(U.GetHP())) && bAwaitingAttack)
	{
		bAwaitingAttack = false;
		
		switch(U.GetHP().GetStateName())
		{
			case 'stateStartAttack':
			case 'stateAttack1':
			case 'stateAttack1End':
			case 'stateAttack2':
			case 'stateAttack2End':
			case 'stateAttack3':
			case 'stateAttack3Attack1':
			case 'stateSpecialAttack':
			case 'stateBossPibAttack':
				QueueThreadEvent("OnPlayerAttack");
				
				break;
			case 'stateRunAttack':
				QueueThreadEvent("OnPlayerChargeAttack");
				
				break;
			case 'stateStartAirAttack':
			case 'stateContinueAirAttack':
				QueueThreadEvent("OnPlayerJumpAttack");
				
				break;
			default:
				break;
		}
	}
	else if(!U.PlayerIsAttacking(SHHeroPawn(U.GetHP())) && !bAwaitingAttack)
	{
		bAwaitingAttack = true;
	}
	
	if(SHHeroPawn(U.GetHP()).numCombatants > 0 && bAwaitingSpotting)
	{
		bAwaitingSpotting = false;
		
		QueueThreadEvent("OnPlayerSpottedByEnemy");
	}
	else if(SHHeroPawn(U.GetHP()).numCombatants <= 0 && !bAwaitingSpotting)
	{
		bAwaitingSpotting = true;
	}
	
	ProcessThreadEvents();
}

event PostLoadGame(bool bLoadFromSaveGame)
{
	if(bLoadFromSaveGame)
	{
		QueueThreadEvent("OnLoadGame");
	}
}

event PostSaveGame()
{
	QueueThreadEvent("OnSaveGame");
}

// Starts the script logic.
function StartScript(HScriptProcessor P, optional int iLine)
{
	P.iCurrentLine = iLine;
	
	P.GotoState('ScriptLogic');
}

// Prepares a goto for the provided line.
function PrepGoto(HScriptProcessor P, int iLine)
{
	P.bGoto = true;
	P.iGotoLine = iLine;
}

// Pauses the script logic.
function PauseScript(HScriptProcessor P)
{
	P.GotoState('ScriptPause');
}

// Resets the script logic.
function ResetScript(HScriptProcessor P, optional int iLine)
{
	P.iCurrentLine = iLine;
}

// Restarts the script logic.
function RestartScript(HScriptProcessor P, optional int iLine)
{
	P.iCurrentLine = iLine;
	
	P.GotoState('ScriptLogic');
}

// Ends the script logic.
function EndScript(HScriptProcessor P)
{
	PauseScript(P);
	ResetScript(P);
	
	P.GotoState('ScriptEnd');
}

// Processes the current line in the script.
function string ProcessAction(HScriptProcessor P, string sAction, out string sLog)
{
	local string command, sActionTemp;
	local array<string> args, TokenArray;
	
	TokenArray = U.Split(sAction);
	command = TokenArray[0];
	
	sActionTemp = sAction;
	U.RemoveText(sActionTemp, command);
	args = QuoteSplit(sActionTemp);
	
	if(args.Length < 1)
	{
		class'HVersion'.static.DebugLog("Line/action not formatted correctly!");
		
		return "";
	}
	
	return ProcessCommand(P, command, args, sLog);
}

// Works identically to the Split() function, but it does NOT split data that is inside quotes.
function array<string> QuoteSplit(string sLine, optional string delimiter)
{
	local array<string> parts;
	local int i;
	local bool isInQuote;
	local string currentPart;
	
	if(delimiter == "")
	{
		delimiter = " ";
	}
	
	for(i = 0; i < Len(sLine); i++)
	{
		if(Mid(sLine, i, 1) == chr(34))
		{
			isInQuote = !isInQuote;
			
			continue;
		}
		else if(Mid(sLine, i, 1) == delimiter && !isInQuote)
		{
			if(currentPart != "")
			{
				parts.Insert(parts.Length, 1);
				parts[parts.Length - 1] = currentPart;
			}
			
			currentPart = "";
		}
		else
		{
			currentPart = currentPart $ Mid(sLine, i, 1);
		}
	}
	
	if(currentPart != "")
	{
		parts.Insert(parts.Length, 1);
		parts[parts.Length - 1] = currentPart;
	}
	
	return parts;
}

// Calculates all goto pointers.
function ProcessGotos(HScriptProcessor P)
{
	local string command, sActionTemp;
	local int i;
	local array<string> args, TokenArray;
	
	P.Gotos.Remove(0, P.Gotos.Length);
	
	// Determine where all the labels are at, then save their locations.
	for(i = 0; i < P.Script.Length; i++)
	{
		TokenArray = U.Split(P.Script[i]);
		command = TokenArray[0];
		
		sActionTemp = P.Script[i];
		U.RemoveText(sActionTemp, command);
		args = QuoteSplit(sActionTemp);
		
		if(Caps(command) == "LABEL")
		{
			if(args.Length != 1)
			{
				class'HVersion'.static.DebugLog("GOTO command on line" @ string(i) @ "not formatted correctly!");
				
				continue;
			}
			
			P.Gotos.Insert(P.Gotos.Length, 1);
			P.Gotos[P.Gotos.Length - 1].sLabel = Caps(args[0]);
			P.Gotos[P.Gotos.Length - 1].iLine = i;
		}
	}
}

// Returns the index within the script that points to the goto line linked with the label specified.
function int GetGotoLineByLabel(HScriptProcessor P, string sLabel)
{
	local int i;
	
	for(i = 0; i < P.Gotos.Length; i++)
	{
		if(P.Gotos[i].sLabel == Caps(sLabel))
		{
			return P.Gotos[i].iLine;
		}
	}
	
	return -1;
}

// Takes a full line, parses it as action(s) (parentheses can nest actions), and queues them all up next in the action list.
function bool ParseActions(HScriptProcessor P, string sLine)
{
	local int i, j, k, iParDepth;
	local bool bInString;
	
	P.Actions.Remove(0, P.Actions.Length);
	P.iCurrentAction = 0;
	
	for(i = 0; i < Len(sLine); i++)
	{
		if(Mid(sLine, i, 1) == "(" && !bInString)
		{
			iParDepth++;
		}
		else if(Mid(sLine, i, 1) == ")")
		{
			if(!bInString)
			{
				iParDepth--;
				
				for(j = i; j > -1; j--)
				{
					if(Mid(sLine, j, 1) == "(")
					{
						k++;
						
						if(iParDepth + 1 == k)
						{
							P.Actions.Insert(P.Actions.Length, 1);
							P.Actions[P.Actions.Length - 1] = Mid(sLine, j + 1, i - j - 1);
							P.iActionTotal++;
							
							break;
						}
					}
				}
			}
		}
		if(Mid(sLine, i, 1) == chr(34))
		{
			bInString = !bInString;
		}
	}
	
	if(bInString || iParDepth != 0)
	{
		class'HVersion'.static.DebugLog("Error: Quote or parenthesis not properly closed!");
	}
	
	P.Actions.Insert(P.Actions.Length, 1);
	P.Actions[P.Actions.Length - 1] = sLine;
	P.iActionTotal++;
	
	return false;
}

// Takes a command with arguments and processes all their custom script logic. Returns a string if the command does so.
function string ProcessCommand(HScriptProcessor P, string command, array<string> args, out string sLog)
{
	local int i, iTemp;
	local string sTemp;
	local Actor aTemp;
	local bool bTemp;
	
	// Cap all command input strings.
	command = Caps(command);
	
	for(i = 0; i < args.Length; i++)
	{
		args[i] = Caps(args[i]);
	}
	
	// Clear the return value before starting.
	P.sReturn = "";
	
	class'HVersion'.static.DebugLog("Processing a" @ command @ "command!");
	
	for(i = 0; i < args.Length; i++)
	{
		class'HVersion'.static.DebugLog(args[i]);
	}
	
	switch(command)
	{
		case "SETVARIABLE":
		case "SETVAR":
			if(args.Length != 2)
			{
				sLog = "Wrong amount of arguments for SETVARIABLE command!";
				
				break;
			}
			
			SetProperty(args[0], args[1]);
			
			sLog = "Variable" @ args[0] @ "set to" @ args[1] $ ".";
			
			break;
		case "GETVARIABLE":
		case "GETVAR":
			if(args.Length != 1)
			{
				sLog = "Wrong amount of arguments for GETVARIABLE command!";
				
				break;
			}
			
			sTemp = GetProperty(args[0]);
			
			sLog = "Variable" @ args[0] @ "is equal to" @ sTemp $ ".";
			
			return sTemp;
		case "CONSOLECOMMAND":
		case "CC":
			if(args.Length != 1)
			{
				sLog = "Wrong amount of arguments for CONSOLECOMMAND command!";
				
				break;
			}
			
			sLog = "Running console command:" @ args[0] $ ".";
			
			return U.CC(args[0]);
		case "GETHEROPAWN":
		case "GETHP":
			sTemp = string(U.GetHP());
			
			sLog = "Getting hero pawn. It is currently:" @ sTemp $ ".";
			
			return sTemp;
		case "GETINVENTORYCARRIERPAWN":
		case "GETICP":
			sTemp = string(U.GetICP());
			
			sLog = "Getting inventory carrier pawn. It is currently:" @ sTemp $ ".";
			
			return sTemp;
		case "SETACTOR":
			if(args.Length != 3)
			{
				sLog = "Wrong amount of arguments for SETACTOR command!";
				
				break;
			}
			
			aTemp = Actor(FindObject(args[0], class'Actor'));
			
			if(aTemp == none)
			{
				sLog = "SETACTOR cannot find actor" @ args[0] $ "!";
				
				break;
			}
			
			aTemp.SetPropertyText(args[1], args[2]);
			
			sLog = "Variable" @ args[1] @ "on actor" @ args[0] @ "set to" @ args[2] $ ".";
			
			break;
		case "GETACTOR":
			if(args.Length != 2)
			{
				sLog = "Wrong amount of arguments for GETACTOR command!";
				
				break;
			}
			
			aTemp = Actor(FindObject(args[0], class'Actor'));
			
			if(aTemp == none)
			{
				sLog = "SETACTOR cannot find actor" @ args[0] $ "!";
				
				break;
			}
			
			sTemp = aTemp.GetPropertyText(args[1]);
			
			sLog = "Variable" @ args[1] @ "on actor" @ args[0] @ "is equal to" @ sTemp $ ".";
			
			return sTemp;
		case "ANNOUNCE":
		case "ANN":
			if(args.Length < 1)
			{
				sLog = "Wrong amount of arguments for ANNOUNCE command!";
				
				break;
			}
			
			switch(args.Length)
			{
				case 1:
					U.Announce(args[0],, U.MakeColor(255, 255, 255, 255));
					
					break;
				case 2:
					U.Announce(args[0], float(args[1]), U.MakeColor(255, 255, 255, 255));
					
					break;
			}
			
			sLog = "Announcing the text:" @ args[0] $ ".";
			
			break;
		case "SLEEP":
		case "WAIT":
		case "PAUSE":
			if(args.Length < 1)
			{
				sLog = "Wrong amount of arguments for SLEEP command!";
				
				break;
			}
			
			P.SetTimer(float(args[0]), false);
			
			sLog = "Sleeping for" @ float(args[0]) @ " seconds.";
			
			P.RegisterLatency(sLog, "");
			
			break;
		case "GOTOSTATE":
			if(args.Length != 2)
			{
				sLog = "Wrong amount of arguments for GOTOSTATE command!";
				
				break;
			}
			
			aTemp = Actor(FindObject(args[0], class'Actor'));
			
			if(aTemp == none)
			{
				sLog = "GOTOSTATE cannot find actor" @ args[0] $ "!";
				
				break;
			}
			
			sTemp = string(aTemp.GetStateName());
			
			aTemp.GotoState(U.SName(args[1]));
			
			sLog = "State" @ sTemp @ "on actor" @ args[0] @ "is now equal to" @ args[1] $ ".";
			
			break;
		case "ISINSTATE":
		case "IFINSTATE":
			if(args.Length != 2)
			{
				sLog = "Wrong amount of arguments for ISINSTATE command!";
				
				break;
			}
			
			aTemp = Actor(FindObject(args[0], class'Actor'));
			
			if(aTemp == none)
			{
				sLog = "ISINSTATE cannot find actor" @ args[0] $ "!";
				
				break;
			}
			
			bTemp = aTemp.IsInState(U.SName(args[1]));
			
			sLog = "State on actor" @ args[0] @ "is equal to" @ args[1] $ ":" @ U.BoolToString(bTemp) $ ".";
			
			return U.BoolToString(bTemp);
		case "LOG":
			if(args.Length < 1)
			{
				sLog = "Wrong amount of arguments for LOG command!";
				
				break;
			}
			
			for(i = 0; i < args.Length; i++)
			{
				if(sTemp == "")
				{
					sTemp = args[i];
				}
				else
				{
					sTemp = sTemp @ args[i];
				}
			}
			
			Log(sTemp);
			
			sLog = "Logging...";
			
			break;
		case "GOTO":
		case "GOTOLABEL":
			if(args.Length != 1)
			{
				sLog = "Wrong amount of arguments for GOTO command!";
				
				break;
			}
			
			iTemp = GetGotoLineByLabel(P, args[0]);
			
			if(iTemp == -1)
			{
				sLog = "GOTO command failed to find label" @ args[0] $ "!";
				
				break;
			}
			
			P.PrepGoto(iTemp);
			
			sLog = "Going to label:" @ args[0] @ "on line" @ string(iTemp) $ ".";
			
			break;
		case "LABEL":
			break;
		case "END":
		case "STOP":
		case "BREAK":
			P.bEnd = true;
			
			sLog = "Ending script.";
			
			break;
		case "RANDOMNUMBER":
		case "RANDNUM":
			if(args.Length != 2)
			{
				sLog = "Wrong amount of arguments for RANDOMNUMBER command!";
				
				break;
			}
			
			sLog = "Returning random number between" @ args[0] @ "and" @ args[1] $ ".";
			
			return string(U.RandRangeInt(int(args[0]), int(args[1])));
		case "RANDOMFLOAT":
		case "RANDFLOAT":
			if(args.Length != 2)
			{
				sLog = "Wrong amount of arguments for RANDOMFLOAT command!";
				
				break;
			}
			
			sLog = "Returning random float between" @ args[0] @ "and" @ args[1] $ ".";
			
			return string(U.RandRangeFloat(float(args[0]), float(args[1])));
		case "LOCATEACTOR":
			if(args.Length != 1)
			{
				sLog = "Wrong amount of arguments for LOCATEACTOR command!";
				
				break;
			}
			
			foreach AllActors(class'Actor', aTemp, U.SName(args[0]))
			{
				break;
			}
			
			if(aTemp == none)
			{
				sLog = "Failed to find actor with tag '" @ args[0] $ "'.";
				
				break;
			}
			
			sLog = "Returning actor pointer" @ string(aTemp) @ "with tag '" @ args[0] $ "'.";
			
			return string(aTemp);
		case "EVALUATEEXPRESSION":
		case "EVAL":
			if(args.Length != 1)
			{
				sLog = "Wrong amount of arguments for EVALUATEEXPRESSION command!";
				
				break;
			}
			
			sTemp = U.Eval(args[0]);
			
			if(sTemp == "")
			{
				sLog = "EVALUATEEXPRESSION command returned none!";
				
				break;
			}
			
			sLog = "Returning value" @ sTemp $ ".";
			
			return sTemp;
		default:
			// We could end up here with array variable types, but it should be fine. Hmm...
			sLog = "Unknown command:" @ command $ ".";
			
			break;
	}
	
	if(sLog == "")
	{
		sLog = "Finished an action in line" @ string(P.iCurrentLine) @ "with no return value.";
	}
	
	return "";
}

// Registers a latent moment in the script to begin.
function RegisterLatency(HScriptProcessor P, string sLog, string sReturn)
{
	P.bSleeping = true;
	P.bSlept = true;
	P.sLatentLog = sLog;
	P.sLatentReturn = sReturn;
}

// Unregisters a latent moment in the script.
function UnregisterLatency(HScriptProcessor P)
{
	P.bSleeping = false;
	P.bSlept = false;
	P.sLog = P.sLatentLog;
	P.sReturn = P.sLatentReturn;
}

// Registers a new variable with a name and value.
function int RegisterVariable(string PropName, string PropValue)
{
	local int iIndex;
	
	// Find the index of the variable with the same name.
	iIndex = GetVariableIndexByName(PropName);
	
	// If the variable isn't found, find the first available slot.
	if(iIndex == -1)
	{
		default.ScriptData.Insert(default.ScriptData.Length, 1);
		
		iIndex = default.ScriptData.Length - 1;
	}
	else
	{
		// Variable already declared, move on...
		return iIndex;
	}
	
	// Store the data.
	default.ScriptData[iIndex].sName = PropName;
	default.ScriptData[iIndex].sDataType = U.GuessArrayTypeFromString(PropValue);
	default.ScriptData[iIndex].Value = PropValue;
	
	return iIndex;
}

// Sets an existing variable's value by a slot.
function SetVariableBySlot(int PropSlot, string PropValue)
{
	// Validate the slot and set the value.
	if(!IsVariableSlotAvailable(PropSlot))
	{
		default.ScriptData[PropSlot].Value = PropValue;
	}
	else
	{
		class'HVersion'.static.DebugLog("Variable slot not allocated!");
	}
}

// Gets an existing variable's value by a slot.
function string GetVariableBySlot(int PropSlot)
{
	// Validate the slot and return the value.
	if(!IsVariableSlotAvailable(PropSlot))
	{
		return default.ScriptData[PropSlot].Value;
	}
	else
	{
		return "";
	}
}

// Gets an existing variable's index by a name.
function int GetVariableIndexByName(string PropName)
{
	local int i;
	
	PropName = Caps(PropName);
	
	for(i = 0; i < default.ScriptData.Length; i++)
	{
		if(default.ScriptData[i].sName == PropName)
		{
			return i;
		}
	}
	
	return -1;
}

// Returns true if a variable slot is currently unused.
function bool IsVariableSlotAvailable(int PropSlot)
{
	return PropSlot > default.ScriptData.Length - 1;
}

// Sets a variable value by variable name.
function SetProperty(string PropName, string PropValue)
{
	SetVariableBySlot(RegisterVariable(PropName, PropValue), PropValue);
}

// Gets a variable value by variable name.
function string GetProperty(string PropName)
{
	local int iIndex;
	
	iIndex = GetVariableIndexByName(PropName);
	
	if(iIndex != -1)
	{
		return GetVariableBySlot(iIndex);
	}
	else
	{
		return "";
	}
}

// Returns a thread by its' processor name.
function HScriptProcessor GetThreadByName(string sName)
{
	local int i;
	
	sName = Caps(sName);
	
	for(i = 0; i < Threads.Length; i++)
	{
		if(Threads[i].sProcessorName == sName)
		{
			return Threads[i];
		}
	}
}

// Queues a thread event by processor name.
function QueueThreadEvent(string sName)
{
	ThreadEvents.Insert(ThreadEvents.Length, 1);
	ThreadEvents[ThreadEvents.Length - 1] = Caps(sName);
}

// Processes all thread events. Uses two loops to respect the order of sequences in the script file.
function ProcessThreadEvents()
{
	local int i, j;
	
	if(ThreadEvents.Length > 0)
	{
		for(i = 0; i < Threads.Length; i++)
		{
			for(j = 0; j < ThreadEvents.Length; j++)
			{
				if(Threads[i].sProcessorName == ThreadEvents[j])
				{
					Threads[i].RestartScript();
					
					ThreadEvents.Remove(j, 1);
					j--;
					
					break;
				}
			}
		}
		
		ThreadEvents.Remove(0, ThreadEvents.Length);
	}
}


defaultproperties
{
	bEventTick=true
	bAlwaysTick=true
	bDebug=true
	bAwaitingAttack=true
	bAwaitingSpotting=true
}