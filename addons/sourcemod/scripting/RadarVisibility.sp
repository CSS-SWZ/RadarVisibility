#include <sourcemod>
#include <sdkhooks>
#include <sdktools_functions>

#undef REQUIRE_PLUGIN
#tryinclude <zombiereloaded>
#define REQUIRE_PLUGIN

#pragma newdecls required

public Plugin myinfo =
{
	name 			= "RadarVisibility",
	author 			= "hEl",
	description 	= "Adds hiding humans/motherzombies on the radar.",
	version 		= "1.0",
	url 			= "https://github.com/CSS-SWZ/RadarVisibility"
};

int RadarMode;

int m_bPlayerSpotted;
int SpottedPlayers[MAXPLAYERS + 1];

bool MapStarted;
bool CachedToggle;
bool ToggleIsCached;

public void OnPluginStart()
{
	m_bPlayerSpotted = FindSendPropInfo("CCSPlayerResource", "m_bPlayerSpotted");
	if(m_bPlayerSpotted == -1)
		SetFailState("Couldn't find CCSPlayerResource::m_bPlayerSpotted");

	ConVar cvar = CreateConVar("sm_radar_mode", "0", "RadarSpotAll mode: 0 = Default, 1 = Show all, 2 = No Humans, 3 = No MotherZombies", FCVAR_NONE, true, 0.0, true, 3.0);
	cvar.AddChangeHook(RadarModeChanged);
	RadarModeChanged(cvar, "", "");
	AutoExecConfig(true, "plugin.RadarVisibility");

	HookEvent("player_spawn", Event_Spawn, EventHookMode_Post);
	HookEvent("player_team", Event_Team, EventHookMode_Post);
}

public void RadarModeChanged(ConVar cvar, const char[] sOldVal, const char[] sNewVal)
{
	RadarMode = cvar.IntValue;
	bool toggle = (RadarMode > 0) ? true:false;
	ToggleRadarHook(toggle);

	for(int client = 1; client < MaxClients; client++)
	{
		if(!IsClientInGame(client))
			continue;

		DefineClientSpot(client, GetClientTeam(client));
	}
}

public void OnMapStart()
{
	MapStarted = true;
	if(ToggleIsCached)
	{
		ToggleIsCached = false;
		ToggleRadarHook(CachedToggle);
	}
}

public void OnConfigsExecuted()
{
	bool toggle = (RadarMode > 0) ? true:false;
	ToggleRadarHook(toggle);
}

public void OnMapEnd()
{
	ToggleRadarHook(false);
	MapStarted = false;
}

void ToggleRadarHook(bool toggle)
{
	static bool isEnable;

	if(isEnable == toggle)
		return;

	if(!MapStarted)
	{
		ToggleIsCached = true;
		CachedToggle = toggle;
		return;
	}

	isEnable = toggle;

	int entity = FindEntityByClassname(-1, "cs_player_manager");
	if(entity != -1)
	{
		switch(toggle)
		{
			case true:	SDKHook(entity, SDKHook_ThinkPost, OnThinkPost);
			case false:	SDKUnhook(entity, SDKHook_ThinkPost, OnThinkPost);
		}
	}
}

public void OnThinkPost(int entity)
{
	switch(RadarMode)
	{
		case 1:	SetEntDataArray(entity, m_bPlayerSpotted, SpottedPlayers, MaxClients + 1, 1, true);

		case 2, 3:
		{
			for(int i = 1; i <= MaxClients; i++)
			{
				if(!SpottedPlayers[i])
				{
					SetEntData(entity, m_bPlayerSpotted + i, 0, 1, true);
				}
			}
		}
	}
	
}

public void Event_Spawn(Event event, const char[] name, bool dontBroadcast)
{
	if(RadarMode == 0)
		return;

	int client = GetClientOfUserId(GetEventInt(event, "userid"));
	if(!client)
		return;

	DefineClientSpot(client, GetClientTeam(client));
}

public void Event_Team(Event event, const char[] name, bool dontBroadcast)
{
	if(RadarMode == 0)
		return;

	DefineClientSpot(GetClientOfUserId(GetEventInt(event, "userid")), event.GetInt("team"));
}

void DefineClientSpot(int client, int team, bool mother = false)
{
	switch(RadarMode)
	{
		case 1:
		{
			SpottedPlayers[client] = 1;
		}
		case 2:
		{
			switch(team)
			{
				case 3: SpottedPlayers[client] = 0;
				default: SpottedPlayers[client] = 1;
			}
		}
		case 3:
		{
			switch(team)
			{
				case 2:
				{
					switch(mother)
					{
						case true: SpottedPlayers[client] = 0;
						case false: SpottedPlayers[client] = 1;
					}
				}
				default: SpottedPlayers[client] = 1;
			}

		}
	}
}

public void ZR_OnClientInfected(int client, int attacker, bool motherInfect, bool respawnOverride, bool respawn)
{
	if(!motherInfect)
		return;

	DefineClientSpot(client, 2, true);
}