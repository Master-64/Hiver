// *****************************************************
// *				 Hiver by Master_64					*
// *		  Copyrighted (c) Master_64, 2024			*
// *   May be modified but not without proper credit!  *
// *****************************************************


class HScriptProcessor extends MInfo
	config(Hiver);


var HScript HScript;
var string sProcessorName;
var array<string> Script, Actions;
var array<HScript.GotoStruct> Gotos;
var string sReturn, sLatentReturn, sLog, sLatentLog;
var bool bDebug, bSleeping, bSlept, bGoto, bEnd;
var int iCurrentLine, iCurrentAction, iActionTotal, iGotoLine;


function StartScript(optional int iLine)
{
	HScript.StartScript(self, iLine);
}

function PrepGoto(int iLine)
{
	HScript.PrepGoto(self, iLine);
}

function PauseScript()
{
	HScript.PauseScript(self);
}

function ResetScript(optional int iLine)
{
	HScript.ResetScript(self, iLine);
}

function RestartScript(optional int iLine)
{
	HScript.RestartScript(self, iLine);
}

function EndScript()
{
	HScript.EndScript(self);
}

function string ProcessAction(string sAction, out string sLog)
{
	return HScript.ProcessAction(self, sAction, sLog);
}

function ProcessGotos()
{
	HScript.ProcessGotos(self);
}

function int GetGotoLineByLabel(string sLabel)
{
	return HScript.GetGotoLineByLabel(self, sLabel);
}

function bool ParseActions(string sLine)
{
	return HScript.ParseActions(self, sLine);
}

function string ProcessCommand(string command, array<string> args, out string sLog)
{
	return HScript.ProcessCommand(self, command, args, sLog);
}

function RegisterLatency(string sLog, string sReturn)
{
	HScript.RegisterLatency(self, sLog, sReturn);
}

function UnregisterLatency()
{
	HScript.UnregisterLatency(self);
}

function SetProperty(string PropName, string PropValue)
{
	HScript.SetProperty(PropName, PropValue);
}

function string GetProperty(string PropName)
{
	return HScript.GetProperty(PropName);
}

// Only use in conjunction with latency.
event Timer()
{
	if(bSleeping)
	{
		bSleeping = false;
	}
}


auto state ScriptLimbo
{}

state ScriptLogic
{
	// Takes a return value from the current action, then sets the value of that command in the nested actions to use that return value.
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
	
	Begin:
	
	while(iCurrentLine < Script.Length)
	{
		ParseActions(Script[iCurrentLine]);
		
		while(iCurrentAction < Actions.Length)
		{
			sReturn = ProcessAction(Actions[iCurrentAction], sLog);
			
			// If command is latent, wait for it's true return value.
			while(bSleeping)
			{
				Sleep(0.000001);
			}
			
			// If we got done sleeping, give us the return value.
			if(bSlept)
			{
				UnregisterLatency();
			}
			
			// DEBUG!
			if(bDebug)
			{
				class'HVersion'.static.DebugLog("HiverScriptLog [" $ string(iCurrentLine) $ "](" $ string(iCurrentAction) $ "/" $ string(iActionTotal) $ "):" @ sLog);
			}
			
			if(sReturn != "")
			{
				// Handle return value.
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
}