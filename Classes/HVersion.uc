// *****************************************************
// *				 Hiver by Master_64				   *
// *		  Copyrighted (c) Master_64, 2024		   *
// *   May be modified but not without proper credit!  *
// *****************************************************


class HVersion extends MInfo
	config(Hiver);


var() string Version, ModName;


static function DebugLog(string S)
{
	Log(default.ModName @ default.Version @ "--" @ S);
}


defaultproperties
{
	Version="v1.0"
	ModName="Hiver"
}