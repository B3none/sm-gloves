#include <sourcemod>
#include <sdktools>

#pragma semicolon 1
#pragma newdecls required

#define PREFIX "[\x04B3Gloves\x01]"

int gloves[MAXPLAYERS + 1];
int skin[MAXPLAYERS + 1];

public Plugin myinfo = {
    name = "B3 Gloves",
    author = "B3none",
    description = "This is my version of the gloves plugin.",
    version = "0.1.0",
    url = "https://github.com/b3none"
};

public void OnPluginStart()
{
    RegConsoleCmd("sm_gloves", GlovesCommand);
}

public Action GlovesCommand(int client, int args)
{
	gloves[client] = 5032;
	skin[client] = 10053;

	GivePlayerGloves(client);
}

public void GivePlayerGloves(int client)
{
	if (gloves[client] && skin[client]) {
		int ent = GetEntPropEnt(client, Prop_Send, "m_hMyWearables");
		if (ent != -1) {
			AcceptEntityInput(ent, "KillHierarchy");
		}

		ent = CreateEntityByName("wearable_item");
		if (ent != -1) {
			SetEntProp(ent, Prop_Send, "m_iItemIDLow", -1);

			SetEntProp(ent, Prop_Send, "m_iItemDefinitionIndex", gloves[client]);
			SetEntProp(ent, Prop_Send, "m_nFallbackPaintKit", skin[client]);

			SetEntPropFloat(ent, Prop_Send, "m_flFallbackWear", 0.0000001);
			SetEntPropEnt(ent, Prop_Data, "m_hOwnerEntity", client);
			SetEntPropEnt(ent, Prop_Data, "m_hParent", client);
			SetEntPropEnt(ent, Prop_Data, "m_hMoveParent", client);
			SetEntProp(ent, Prop_Send, "m_bInitialized", 1);

			DispatchSpawn(ent);

			SetEntPropEnt(client, Prop_Send, "m_hMyWearables", ent);
			SetEntProp(client, Prop_Send, "m_nBody", 1);
		}
	}
}