// *****************************************************
// *				 Hiver by Master_64				   *
// *		  Copyrighted (c) Master_64, 2024		   *
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
// 
// Todo:
// * Get actor by tag
// * RandRange
// * Simple conditionals
// * Event subscriptions
// * ScriptData saving
// * Math expressions
// * Add a majority of the CutScript actions


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
var array<string> Script, Actions;
var array<ScriptDataStruct> ScriptData;
var array<GotoStruct> Gotos;
var string sReturn, sLatentReturn, sLog, sLatentLog;
var bool bDebug, bSleeping, bSlept, bGoto, bEnd;
var int iCurrentLine, iCurrentAction, iActionTotal, iGotoLine;


function Init()
{
	ProcessGotos();
}

// Starts the script logic.
function StartScript(optional int iLine)
{
    iCurrentLine = iLine;

    GotoState('ScriptLogic');
}

// Prepares a goto for the provided line.
function PrepGoto(int iLine)
{
	bGoto = true;
	iGotoLine = iLine;
}

// Pauses the script logic.
function PauseScript()
{
    GotoState('ScriptPause');
}

// Resets the script logic.
function ResetScript(optional int iLine)
{
    iCurrentLine = iLine;
}

// Ends the script logic.
function EndScript()
{
    PauseScript();
    ResetScript();

    GotoState('ScriptEnd');
}

// Processes the current line in the script.
function string ProcessAction(string sAction, out string sLog)
{
    local string command;
    local array<string> args;

    // Split the action into command and arguments
    args = U.Split(sAction);

    if(args.Length < 1)
    {
    	class'HVersion'.static.DebugLog("Line/action not formatted correctly!");

    	return "";
    }

    command = args[0];
    args.Remove(0, 1);

    ParseQuotes(args, sAction);

    return ProcessCommand(command, args, sLog);
}

// Calculates all goto pointers.
function ProcessGotos()
{
	local int i;
	local string command;
	local array<string> args;

	Gotos.Remove(0, Gotos.Length);

	// Determine where all the labels
	// are at, then save their locations.
	for(i = 0; i < Script.Length; i++)
	{
		args.Remove(0, args.Length);
		args = U.Split(Script[i]);
		command = args[0];
		args.Remove(0, 1);

		if(Caps(command) == "LABEL")
		{
			if(args.Length != 1)
			{
				class'HVersion'.static.DebugLog("GOTO command on line" @ string(i) @ "not formatted correctly!");

				continue;
			}

			Gotos.Insert(Gotos.Length, 1);
			Gotos[Gotos.Length - 1].sLabel = Caps(args[0]);
			Gotos[Gotos.Length - 1].iLine = i;
		}
	}
}

// Returns the index within the script
// that points to the goto line linked
// with the label specified.
function int GetGotoLineByLabel(string sLabel)
{
	local int i;

	for(i = 0; i < Gotos.Length; i++)
	{
		if(Gotos[i].sLabel == Caps(sLabel))
		{
			return Gotos[i].iLine;
		}
	}

	return -1;
}

// Takes a batch of arguments, then determines
// where all the quotes are, and makes sure that
// spaces inside quotes are preserved.
// 
// Todo: make sure the quotes are removed
function ParseQuotes(out array<string> args, string sLine)
{
    local string currentArg;
    local array<string> newArgs;
    local int i, iStartQuoteIndex, iEndQuoteIndex, iSpaceIndex;

    for(i = 0; i < Len(sLine); i++)
    {
        // Check for the start of a quote
        if(InStr(Left(sLine, Len(sLine) - i + 1), chr(34)) != -1)
        {
            iStartQuoteIndex = i; // Found the start of a quote

            // Move to find the end quote
            iEndQuoteIndex = InStr(Right(sLine, Len(sLine) - iStartQuoteIndex + 1), chr(34));

            if(iEndQuoteIndex != -1) // Ensure it's a full quote
            {
                iEndQuoteIndex += iStartQuoteIndex - 1; // Adjust index to original string

                // Extract the quoted string
                currentArg = Mid(sLine, iStartQuoteIndex, iEndQuoteIndex - iStartQuoteIndex + 1);
                
                // Add the quoted string to newArgs
                newArgs.Insert(newArgs.Length, 1);
                newArgs[newArgs.Length - 1] = currentArg;

                // Move the index past the end quote
                i = iEndQuoteIndex + 1;
            }
            else
            {
            	// No valid end quote found, continue to next character
                continue;
            }
        }
        else
        {
            // Handle non-quoted arguments
            iSpaceIndex = InStr(Left(sLine, Len(sLine) - i + 1), " ");

            if(iSpaceIndex != -1) // Found a space
            {
                // Extract the argument
                currentArg = Mid(sLine, i, iSpaceIndex - 1);
                newArgs.Insert(newArgs.Length, 1);
                newArgs[newArgs.Length - 1] = currentArg;

                // Move past the space
                i += iSpaceIndex;
            }
            else
            {
                // If no more spaces, take the rest of the string
                currentArg = Mid(sLine, i);
                newArgs.Insert(newArgs.Length, 1);
                newArgs[newArgs.Length - 1] = currentArg;

                break;
            }
        }
    }

    args = newArgs;
}

// Takes a full line, parses it as action(s)
// (parentheses can nest actions), and queues
// them all up next in the action list.
function bool ParseActions(string sLine)
{
    local int i, j, iStartIndex, iEndIndex, iNestCount, iTotalNestCount;

    iCurrentAction = 0;

    // Get the total amount of nests
    for(i = 0; i < Len(sLine); i++)
    {
        if(Mid(sLine, i, 1) == "(")
        {
        	iTotalNestCount++;
        }
    }

    // Get each nested action, and parse
    for(i = iTotalNestCount; i >= 0; i--)
    {
    	iNestCount = 0;

	    for(j = 0; j < Len(sLine); j++)
	    {
	        switch(Mid(sLine, j, 1))
	        {
	            case "(":
	                if(iNestCount == i)
	                {
	                    iStartIndex = j; // Mark the start of the outermost parentheses
	                }

	                iNestCount++; // Increment for each '(' found

	                break;
	            case ")":
	                iNestCount--; // Decrement for each ')' found

	                if(iNestCount == i)
	                {
	                    iEndIndex = j; // Mark the end of the outermost parentheses

	                    Actions.Insert(Actions.Length, 1);
	                    Actions[Actions.Length - 1] = Mid(sLine, iStartIndex + 1, iEndIndex - iStartIndex - 1);
	                }

	                break;
	        }
	    }
	}

	iActionTotal = Max(Actions.Length, 1);
    
    return iNestCount != 0;
}

// Takes a command with arguments and
// processes all their custom script logic.
// Returns a string if the command does so.
function string ProcessCommand(string command, array<string> args, out string sLog)
{
	local int i, iTemp;
	local string sTemp;
	local Actor aTemp;
	local bool bTemp;

	// Cap all command input strings
	command = Caps(command);

	for(i = 0; i < args.Length; i++)
	{
		args[i] = Caps(args[i]);
	}

	// Clear the return value before starting
	sReturn = "";

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
					U.Announce(args[0]);

					break;
				case 2:
					U.Announce(args[0], float(args[1]));

					break;
			}

			sLog = "Announcing the text:" @ args[0] @ ".";

			break;
		case "SLEEP":
		case "WAIT":
		case "PAUSE":
			if(args.Length < 1)
			{
				sLog = "Wrong amount of arguments for SLEEP command!";

				break;
			}

			SetTimer(float(args[0]), false);

			sLog = "Sleeping for" @ float(args[0]) @ " seconds.";

			RegisterLatency(sLog, "");

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

			iTemp = GetGotoLineByLabel(args[0]);

			if(iTemp == -1)
			{
				sLog = "GOTO command failed to find label" @ args[0] $ "!";

				break;
			}

			PrepGoto(iTemp);

			sLog = "Going to label:" @ args[0] @ "on line" @ string(iTemp) $ ".";

			break;
		case "LABEL":
			break;
		case "END":
		case "STOP":
		case "BREAK":
			bEnd = true;

			sLog = "Ending script.";

			break;
		default:
			// We could end up here with array variable types, but it should be fine. Hmm...
			sLog = "Unknown command:" @ command $ ".";

			break;
	}

	if(sLog == "")
	{
		sLog = "Finished an action in line" @ string(iCurrentLine) @ "with no return value.";
	}

	return "";
}

// Only use in conjunction with latency
event Timer()
{
	if(bSleeping)
	{
		bSleeping = false;
	}
}

// Registers a latent moment in the script to begin
function RegisterLatency(string sLog, string sReturn)
{
	bSleeping = true;
	bSlept = true;
	sLatentLog = sLog;
	sLatentReturn = sReturn;
}

// Unregisters a latent moment in the script
function UnregisterLatency()
{
	bSleeping = false;
	bSlept = false;
	sLog = sLatentLog;
	sReturn = sLatentReturn;
}

// Registers a new variable with a name and value
function int RegisterVariable(string PropName, string PropValue)
{
    local int iIndex;

    // Find the index of the variable with the same name
    iIndex = GetVariableIndexByName(PropName);

    // If the variable isn't found, find the first available slot
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

    // Remember the data
    default.ScriptData[iIndex].sName = PropName;
    default.ScriptData[iIndex].sDataType = U.GuessArrayTypeFromString(PropValue);
    default.ScriptData[iIndex].Value = PropValue;

    return iIndex;
}

// Sets an existing variable's value by a slot
function SetVariableBySlot(int PropSlot, string PropValue)
{
    // Validate the slot and set the value
    if(!IsVariableSlotAvailable(PropSlot))
    {
        default.ScriptData[PropSlot].Value = PropValue;
    }
    else
    {
        class'HVersion'.static.DebugLog("Variable slot not allocated!");
    }
}

// Gets an existing variable's value by a slot
function string GetVariableBySlot(int PropSlot)
{
    // Validate the slot and return the value
    if(!IsVariableSlotAvailable(PropSlot))
    {
        return default.ScriptData[PropSlot].Value;
    }
    else
    {
        return "";
    }
}

// Gets an existing variable's index by a name
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

// Returns true if a variable slot is currently unused
function bool IsVariableSlotAvailable(int PropSlot)
{
	return PropSlot > default.ScriptData.Length - 1;
}

// Sets a variable value by variable name
function SetProperty(string PropName, string PropValue)
{
	SetVariableBySlot(RegisterVariable(PropName, PropValue), PropValue);
}

// Gets a variable value by variable name
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

// Takes a return value from the current action,
// then sets the value of that command in the
// nested actions to use that return value.
function ProcessReturnValue()
{
	local int i;

    for(i = iCurrentAction + 1; i < Actions.Length; i++)
    {
        if(i + 1 < Actions.Length)
        {
        	ReplaceText(Actions[i + 1], "(" $ Actions[iCurrentAction] $ ")", sReturn);
        }
    }
}


auto state ScriptLimbo
{}

state ScriptLogic
{
    Begin:

    while(iCurrentLine < Script.Length)
    {
	    ParseActions(Script[iCurrentLine]);

	    while(iCurrentAction < Actions.Length)
	    {
	    	sReturn = ProcessAction(Actions[iCurrentAction], sLog);

	    	// If command is latent, wait for it's true return value
	    	while(bSleeping)
	    	{
	    		Sleep(0.000001);
	    	}

	    	// If we got done sleeping, give us the return value
	    	if(bSlept)
	    	{
	    		UnregisterLatency();
	    	}

		    // DEBUG
		    if(bDebug)
		    {
		        class'HVersion'.static.DebugLog("HiverScriptLog [" $ string(iCurrentLine) $ "](" $ string(iCurrentAction) $ "/" $ string(iActionTotal) $ "):" @ sLog);
		    }

		    if(sReturn != "")
		    {
		        // Handle return value
		        // ...

		        ProcessReturnValue();
		    }

		    iCurrentAction++;

		    // Handle goto logic if applicable.
		    if(bGoto)
		    {
		    	bGoto = false;

		    	Actions.Remove(0, Actions.Length);
		    	
		    	iCurrentAction = iGotoLine;
		    }

		    // Handle end logic if applicable.
		    if(bEnd)
		    {
		    	bEnd = false;

		    	EndScript();
		    }
	    }

	    iCurrentLine++;
    }

    EndScript();
}

state ScriptPause
{}

state ScriptEnd
{}


defaultproperties
{
	bAlwaysTick=true
	bDebug=true
}