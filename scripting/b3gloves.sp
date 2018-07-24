#include <sourcemod>

#pragma semicolon 1
#pragma newdecls required

#define PREFIX "[\x04B3Gloves\x01]"

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
    PrintToClient(client, "%s Gloves command.", PREFIX);
}