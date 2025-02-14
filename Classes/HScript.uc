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


class HScript extends MInfo
	config(Hiver);


struct ScriptDataStruct
{
	var config string Value, sName, sDataType;
};

var MutHiver Hiver;
var array<string> Script, Actions;
var config array<ScriptDataStruct> ScriptData;
var string sReturn, sLatentReturn, sLog, sLatentLog;
var bool bDebug, bSleeping, bSlept;
var int iCurrentLine, iCurrentAction, iActionTotal;


// Starts the script logic.
function StartScript()
{
    iCurrentLine = 0;
    GotoState('ScriptLogic');
}

// Pauses the script logic.
function PauseScript()
{
    GotoState('');
}

// Resets the script logic.
function ResetScript()
{
    iCurrentLine = 0;
}

// Ends the script logic.
function EndScript()
{
    PauseScript();
    ResetScript();
}

// Processes the current line in the script.
function string ProcessAction(string sAction, out string sLog)
{
    local string command;
    local array<string> args;

    // Split the action into command and arguments
    args = U.Split(sAction);
    command = args[0];
    args.Remove(0, 1);

    ParseQuotes(args, sAction);

    return ProcessCommand(command, args, sLog);
}

// Takes a batch of arguments, then determines
// where all the quotes are, and makes sure that
// spaces inside quotes are preserved.
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
                continue; // No valid end quote found, continue to next character
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

                i += iSpaceIndex; // Move past the space
            }
            else
            {
                // If no more spaces, take the rest of the string
                currentArg = Mid(sLine, i);
                newArgs.Insert(newArgs.Length, 1);
                newArgs[newArgs.Length - 1] = currentArg;

                break; // Exit loop as we've processed the entire string
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
	local int i;
	local array<string> TokenArray;
	local string sTemp;

	// Cap all command input strings
	command = Caps(command);

	for(i = 0; i < args.Length; i++)
	{
		args[i] = Caps(args[i]);
	}

	switch(command)
	{
		case "SETVAR":
			if(args.Length != 1)
			{
				sLog = "Wrong amount of arguments for SETVAR command!";

				break;
			}

			TokenArray = U.Split(args[0], "=");

			if(TokenArray.Length != 2)
			{
				sLog = "SETVAR declaration is invalid!";

				break;
			}

			SetProperty(TokenArray[0], TokenArray[1]);

			sLog = "Variable" @ TokenArray[0] @ "set to" @ TokenArray[1] $ ".";

			break;
		case "GETVAR":
			if(args.Length != 1)
			{
				sLog = "Wrong amount of arguments for GETVAR command!";

				break;
			}

			sTemp = GetProperty(args[0]);

			sLog = "Variable" @ args[0] @ "is equal to" @ sTemp $ ".";

			return sTemp;
		default:
			sLog = "Unknown command:" @ command;

			break;
	}

	if(sLog == "")
	{
		sLog = "Finished line" @ string(iCurrentLine) @ "with no return value";
	}

	return "";
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
	    }

	    iCurrentLine++;
    }

    GotoState('ScriptEnd');
}

state ScriptEnd
{}


defaultproperties
{
	bAlwaysTick=true
	bDebug=true
}