// *****************************************************
// *				 Hiver by Master_64					*
// *		  Copyrighted (c) Master_64, 2024			*
// *   May be modified but not without proper credit!  *
// *****************************************************


class HModLog extends MInfo
	config(Hiver);


var config array<string> Log;
var bool bUpdateOnLog;


function FlushLog()
{
	local array<string> sTemp;

	default.Log = sTemp;

	SaveConfig();

	class'HVersion'.static.DebugLog("Mod log flushed.");
}

function UpdateLog()
{
	SaveConfig();
}

function ModLog(string sMod, string sString)
{
	default.Log.Insert(default.Log.Length, 1);
	default.Log[default.Log.Length - 1] = sMod @ sString;

	if(bUpdateOnLog)
	{
		UpdateLog();
	}
}