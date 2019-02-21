#include <sourcemod>
#include <sdktools>
#include <clientprefs>

#define MENU_TEXT 50
#define ARRAY_SIZE 96
#define MENUACTIONS MenuAction_Display|MenuAction_DisplayItem|MenuAction_DrawItem
#define MESSAGE_PREFIX "[\x02Gloves\x01]"

#pragma semicolon 1
#pragma newdecls required

public Plugin myinfo = {
    name = "[SM] Gloves",
    author = "B3none",
    description = "gloves plugin.",
    version = "1.3.0",
    url = "https://github.com/b3none"
};

char tag1[16];
ArrayList alModels;
Menu ModelMenu, QualityMenu;
int	clr, random, show_thirdperson, skip_custom_arms,
team_divided, t_default_model, t_default_skin,
ct_default_model, ct_default_skin,gloves[MAXPLAYERS + 1] = {-1, ...},
glove_Type[MAXPLAYERS + 1][2],
glove_Skin[MAXPLAYERS + 1][2],
glove_Quality[MAXPLAYERS + 1] =  { -1, ... };
Handle	ck_Glove_Type[2] = INVALID_HANDLE,
ck_Glove_Skin[2] = INVALID_HANDLE,
ck_Glove_Quality = INVALID_HANDLE;

Handle g_hCookieDefaultGloves = INVALID_HANDLE;
Handle g_hCookieEnabled = INVALID_HANDLE;
bool b_IsEnabled[MAXPLAYERS + 1];

public void OnPluginStart() 
{
    alModels = new ArrayList(ARRAY_SIZE);
    LoadKV();
    CreateMenus();

    g_hCookieDefaultGloves = RegClientCookie("has_default_gloves", "Have we given people default gloves?", CookieAccess_Private);
    g_hCookieEnabled = RegClientCookie("gloves_enabled", "", CookieAccess_Private);
    ck_Glove_Type[0] = RegClientCookie("AcGloveType10", "", CookieAccess_Private);
    ck_Glove_Skin[0] = RegClientCookie("AcGloveSkin10", "", CookieAccess_Private);
    if (team_divided)
    {
        ck_Glove_Type[1] = RegClientCookie("AcGloveType10_CT", "", CookieAccess_Private);
        ck_Glove_Skin[1] = RegClientCookie("AcGloveSkin10_CT", "", CookieAccess_Private);
    }
    ck_Glove_Quality = RegClientCookie("AcGloveQuality9", "", CookieAccess_Private);

    for(int i = 1; i <= MaxClients; i++)
    if (IsClientInGame(i) && !IsFakeClient(i) && AreClientCookiesCached(i))
    OnClientCookiesCached(i);

    HookEvent("player_spawn", Event_PlayerSpawn, EventHookMode_Pre);

    RegConsoleCmd("sm_gloves", Cmd_ModelsMenu);
    RegConsoleCmd("sm_glove", Cmd_ModelsMenu);
    RegConsoleCmd("sm_gl", Cmd_ModelsMenu);
}

public Action Cmd_Gl3(int client, int args)
{
    char buff[12];
    int type[2], skin[2], quality;
    GetClientCookie(client, ck_Glove_Type[0], buff, sizeof(buff));
    type[0] = StringToInt(buff);
    GetClientCookie(client, ck_Glove_Skin[0], buff, sizeof(buff));
    skin[0] = StringToInt(buff);
    GetClientCookie(client, ck_Glove_Quality, buff, sizeof(buff));
    quality = StringToInt(buff);
    if (team_divided) {
        GetClientCookie(client, ck_Glove_Type[1], buff, sizeof(buff));
        type[1] = StringToInt(buff);
        GetClientCookie(client, ck_Glove_Skin[1], buff, sizeof(buff));
        skin[1] = StringToInt(buff);
    }

    if (quality < 0 || quality > 100) {
        glove_Quality[client] = 100;
    }
    return Plugin_Handled;
}

public void OnPluginEnd()
{
    for (int i = 1; i <= MaxClients; i++) {
        if (gloves[i] != -1 && IsWearable(gloves[i])) {
            if (IsClientConnected(i) && IsPlayerAlive(i)) {
                SetEntPropEnt(i, Prop_Send, "m_hMyWearables", -1);
                SetEntProp(i, Prop_Send, "m_nBody", 0);
            }
            AcceptEntityInput(gloves[i], "Kill");
        }
    }
}

public void OnClientCookiesCached(int client)
{
    char strCookie[8];

    GetClientCookie(client, g_hCookieDefaultGloves, strCookie, sizeof(strCookie));

    if (StringToInt(strCookie) == 0) {
        SetCookie(client, g_hCookieDefaultGloves, true);
        SetCookie(client, g_hCookieEnabled, true);

        SetClientCookie(client, ck_Glove_Quality, "100");
        SetClientCookie(client, ck_Glove_Type[0], "4");
        SetClientCookie(client, ck_Glove_Skin[0], "1");
    }

    GetClientCookie(client, g_hCookieDefaultGloves, strCookie, sizeof(strCookie));
    b_IsEnabled[client] = !!strCookie;

    char buff[12];
    int type[2], skin[2], quality;
    GetClientCookie(client, ck_Glove_Type[0], buff, sizeof(buff));
    type[0] = StringToInt(buff);
    GetClientCookie(client, ck_Glove_Skin[0], buff, sizeof(buff));
    skin[0] = StringToInt(buff);
    GetClientCookie(client, ck_Glove_Quality, buff, sizeof(buff));
    quality = StringToInt(buff);
    if (team_divided) {
        GetClientCookie(client, ck_Glove_Type[1], buff, sizeof(buff));
        type[1] = StringToInt(buff);
        GetClientCookie(client, ck_Glove_Skin[1], buff, sizeof(buff));
        skin[1] = StringToInt(buff);
    }

    if (quality < 0 || quality > 100) {
        glove_Quality[client] = 100;
    } else {
        glove_Quality[client] = quality;
    }

    if (skin[0] == 0) {
        glove_Type[client][0] = -1;
        glove_Skin[client][0] = -1;
        glove_Quality[client] = -1;
    } else {
        glove_Type[client][0] = type[0];
        glove_Skin[client][0] = skin[0];
    }

    if (team_divided) {
        if (skin[1] == 0) {
            glove_Type[client][1] = -1;
            glove_Skin[client][1] = -1;
        } else {
            glove_Type[client][1] = type[1];
            glove_Skin[client][1] = skin[1];

        }
    }

    if ((skin[0] != 0 || (team_divided && skin[1] != 0)) && IsClientInGame(client) && IsPlayerAlive(client)) {
        SetGlove(client);
        PrintToChat(client, "%s %t", MESSAGE_PREFIX, "Restored");
    }
}

public void SetCookie(int client, Handle cookie, bool value)
{
	char strCookie[64];
	IntToString(value, strCookie, sizeof(strCookie));
	SetClientCookie(client, cookie, strCookie);
}

public void OnClientDisconnect(int client)
{
    if (IsClientConnected(client) && IsClientInGame(client) && !IsFakeClient(client)) {
        int wear = GetEntPropEnt(client, Prop_Send, "m_hMyWearables");
        if (wear != -1 && IsWearable(wear)) {
            AcceptEntityInput(wear, "Kill");
            if (wear == gloves[client]) {
                gloves[client] = -1;
            }
        }
    }

    if (gloves[client] != -1 && IsWearable(gloves[client])) {
        AcceptEntityInput(gloves[client], "Kill");
    }

    gloves[client] = -1;
    glove_Type[client][0] = -1;
    glove_Skin[client][0] = -1;
    glove_Quality[client] = -1;

    if (team_divided) {
        glove_Type[client][1] = -1;
        glove_Skin[client][1] = -1;
    }
}

public void LoadKV()
{
    KeyValues kv = new KeyValues("Gloves");
    char confPath[256];
    BuildPath(Path_SM, confPath, sizeof(confPath), "/configs/sm-gloves.txt");
    if (kv.ImportFromFile(confPath)) {
        kv.Rewind();
        kv.GetString("tag", tag1, sizeof(tag1), "GL");
        clr = kv.GetNum("color", 11);
        if (clr < 1 || clr > 16) clr = 11;
        Format(tag1, sizeof(tag1), "[%s%s\x01]", clr, tag1);
        random = kv.GetNum("random", 1);
        team_divided = kv.GetNum("team_divided", 1);
        skip_custom_arms = kv.GetNum("skip_custom_arms", 0);
        show_thirdperson = kv.GetNum("show_thirdperson", 1);
        t_default_model = kv.GetNum("t_default_model", -1);
        t_default_skin = kv.GetNum("t_default_skin", -1);
        ct_default_model = kv.GetNum("ct_default_model", -1);
        ct_default_skin = kv.GetNum("ct_default_skin", -1);
        if (kv.JumpToKey("Models", false)) {
            alModels.Push(0);
            if (kv.GotoFirstSubKey(true)) {
                char buff[96];
                do {
                    int num = GetModelsCount()+1;
                    alModels.Set(0, num);
                    kv.GetSectionName(buff, sizeof(buff));
                    alModels.Push(StringToInt(buff));
                    kv.GetString("name", buff, sizeof(buff));
                    alModels.PushString(buff);
                    kv.GetString("icon", buff, 8);
                    alModels.PushString(buff);
                    kv.GetString("model", buff, sizeof(buff));
                    alModels.PushString(buff);
                    alModels.Push(0);
                    if (kv.JumpToKey("skins", false)) {
                        if (kv.GotoFirstSubKey(true)) {
                            char buff2[96];
                            do {
                                alModels.Set(GetModelPos(num)+4, alModels.Get(GetModelPos(num)+4)+1);
                                kv.GetSectionName(buff2, sizeof(buff2));
                                alModels.Push(StringToInt(buff2));
                                kv.GetString("name", buff2, sizeof(buff2));
                                alModels.PushString(buff2);
                                int limit = kv.GetNum("limit", -1);
                                if (limit < -1 || limit > 99) limit = -1;
                                alModels.Push(limit);
                            } while (kv.GotoNextKey(true));
                            kv.GoBack();
                        } else {
                            SetFailState("Failed to load config file: No skins found for %d's model!", alModels.Get(GetModelPos(num)+1));
                        }
                        kv.GoBack();
                    } else {
                        SetFailState("Failed to load config file: No skins setting for %d's model!", alModels.Get(GetModelPos(num)+1));
                    }
                } while (kv.GotoNextKey(true));
            } else {
                SetFailState("Failed to load config file: No models found!");
            }
        } else {
            SetFailState("Failed to load config file: No models setting!");
        }
    } else {
        SetFailState("Failed to load config file!");
    }

    /* Translation load */
    LoadTranslations("sm-gloves.phrases.txt");
    PrintToServer("[gloves] %d models loaded!", GetModelsCount());
    delete kv;

}

public void CreateMenus()
{
    char buff[8], buff2[MENU_TEXT], buff3[8];

    ModelMenu = CreateMenu(ModelMenuHandler, MENUACTIONS);
    ModelMenu.SetTitle("Glove Menu:");
    int count = GetModelsCount();
    for (int i = 1; i <= count; i++) {
        IntToString(i, buff, sizeof(buff));
        GetModelName(i, buff2);
        GetModelIcon(i, buff3);
        if (buff3[0]) {
            Format(buff2, sizeof(buff2), "%s %s%s", buff3, buff2, (i==count)?"\n ":"");
        }
        ModelMenu.AddItem(buff, buff2);
    }

    ModelMenu.AddItem("_reset", "Reset");
    ModelMenu.AddItem("_quality", "Quality");
    ModelMenu.AddItem("_toggle", "Toggle");
    ModelMenu.ExitButton = true;

    QualityMenu = CreateMenu(QualityMenuHandler, MENUACTIONS);
    QualityMenu.SetTitle("Quality:");
    QualityMenu.AddItem("100", "100%");
    QualityMenu.AddItem("75", "75%");
    QualityMenu.AddItem("50", "50%");
    QualityMenu.AddItem("25", "25%");
    QualityMenu.AddItem("0", "0%");
    QualityMenu.ExitButton = true;
}

public int ModelMenuHandler(Menu menu, MenuAction action, int client, int item)
{
    switch (action) {
        case MenuAction_Select: {
            char buff[8], buff2[MENU_TEXT];
            menu.GetItem(item, buff, sizeof(buff));
            if (buff[0] == '_') {
                switch (buff[1]) {
                    case 'r': {
                        ResetGlove(client);
                        menu.Display(client, 40);
                    }

                    case 't': {
                        b_IsEnabled[client] = !b_IsEnabled[client];
                        SetClientCookie(client, g_hCookieEnabled, b_IsEnabled[client] ? "1":"0");
                    }

                    case 'q': {
                        QualityMenu.Display(client, 20);
                    }
                }
            } else {
                int model = StringToInt(buff);
                GetModelName(model, buff2);
                int skins = GetSkinsCount(model);
                Menu SkinMenu = CreateMenu(SkinMenuHandler, MENUACTIONS);
                SkinMenu.SetTitle(buff2);
                if (random) {
                    Format(buff, sizeof(buff), "_r:%d", model);
                    SkinMenu.AddItem(buff, "Menu Random");
                }

                for (int i = 1; i <= skins; i++) {
                    Format(buff, sizeof(buff), "%d:%d", model, i);
                    GetSkinName(model, i, buff2);
                    if (i == skins) {
                        Format(buff2, sizeof(buff2), "%s\n ", buff2);
                    }
                    SkinMenu.AddItem(buff, buff2);
                }
                SkinMenu.ExitButton = true;
                SkinMenu.Display(client, 40);
            }
        }

        case MenuAction_DisplayItem: {
            static char buff[16], display[64];
            menu.GetItem(item, buff, sizeof(buff), _, display, sizeof(display));
            if (buff[0] == '_') {
                switch (buff[1]) {
                    case 'r': {
                        Format(display, sizeof(display), "%T", "Menu_Standart", client);
                    }

                    case 'q': {
                        Format(display, sizeof(display), "%T", "Menu_Quality", client);
                    }

                    case 'c': {
                        Format(display, sizeof(display), "%T", "Menu_Close", client);
                    }
                }
                return RedrawMenuItem(display);
            } else {
                int team = GetClientTeam(client);
                if (team < 2 || team_divided == 0) {
                    team = 0;
                } else {
                    team -= 2;
                }

                if (StringToInt(buff) == glove_Type[client][team]) {
                    Format(display, sizeof(display), "%s", display);
                    return RedrawMenuItem(display);
                }
            }
        }

        case MenuAction_DrawItem: {
            static char buff[3];
            menu.GetItem(item, buff, sizeof(buff));
            if (team_divided && GetClientTeam(client) < 2) {
                if (buff[0] != '_' || buff[1] == 'r') {
                    return ITEMDRAW_RAWLINE;
                }
            }
        }

        case MenuAction_Display: {
            static char title[128], buff[64];
            if (team_divided) {
                int team = GetClientTeam(client);
                if (team < 2) {
                    Format(buff, sizeof(buff), "%T", "Menu_Title", client);
                    Format(title, sizeof(title), "%T", "Menu_NoTeamTitle", client);
                    Format(title, sizeof(title), "%s%s", buff, title);
                    ReplaceString(title, sizeof(title), "\\n", "\n");
                } else {
                    switch (team) {
                        case 2: {
                            Format(title, MENU_TEXT, "%T", "Menu_Title_T", client);
                        }

                        case 3: {
                            Format(title, MENU_TEXT, "%T", "Menu_Title_CT", client);
                        }
                    }
                }
            } else {
                Format(title, MENU_TEXT, "%T", "Menu_Title", client);
            }
            menu.SetTitle(title);
        }
    }
    return 0;
}

public int SkinMenuHandler(Menu menu, MenuAction action, int client, int item)
{
    switch (action) {
        case MenuAction_Select: {
            char buff[16];
            menu.GetItem(item, buff, sizeof(buff));
            if (team_divided && (buff[1] != 'q' || buff[1] != 'c')) {
                if (GetClientTeam(client) < 2 ) {
                    PrintToChat(client, "%s %t", MESSAGE_PREFIX, "Menu_NoTeamWarning");
                    ModelMenu.Display(client, 20);
                    delete menu;
                    return 0;
                }
            }

            if (buff[0] == '_') {
                if (buff[1] == 'r') {
                    SaveGlove(client, StringToInt(buff[3]), -2);
                    SetGlove(client);
                    menu.Display(client, 40);
                } else if (buff[1] == 'b') {
                    ModelMenu.Display(client, 40);
                    delete menu;
                } else {

                    delete menu;
                }
            } else {
                char buffs[2][8];
                ExplodeString(buff, ":", buffs, 2, 8);
                int model = StringToInt(buffs[0]);
                int skin = StringToInt(buffs[1]);
                SaveGlove(client, model, skin, _, true);
                SetGlove(client);
                menu.Display(client, 40);
            }
        }

        case MenuAction_End: {
            if (client != MenuEnd_Selected && menu != INVALID_HANDLE) {
                delete menu;
            }
        }

        case MenuAction_DrawItem: {
            static char buff[16];
            menu.GetItem(item, buff, sizeof(buff));
            if (buff[0] != '_') {
                static char buffs[2][8];
                ExplodeString(buff, ":", buffs, 2, 8);
                int model = StringToInt(buffs[0]);
                int skin = StringToInt(buffs[1]);
                if (!GloveAccess(client, model, skin))
                return ITEMDRAW_DISABLED;
            }
        }

        case MenuAction_DisplayItem: {
            char buff[16], title[MENU_TEXT];
            menu.GetItem(item, buff, sizeof(buff), _, title, sizeof(title));
            if (buff[0] != '_') {
                static char buffs[2][8];
                ExplodeString(buff, ":", buffs, 2, 8);
                int model = StringToInt(buffs[0]);
                int skin = StringToInt(buffs[1]);
                int limit = GloveAccess(client, model, skin);

                if (title[strlen(title) - 2] == '\n') {
                    title[strlen(title) - 2] = '\0';
                    Format(title, sizeof(title), "%s (%d%%)\n ", title, limit);
                } else {
                    Format(title, sizeof(title), "%s (%d%%)", title, limit);
                }

                int team = GetClientTeam(client);

                if (team < 2 || team_divided == 0) {
                    team = 0;
                } else {
                    team -= 2;
                }

                if (model == glove_Type[client][team] && skin == glove_Skin[client][team]) {
                    if (title[strlen(title) - 2] == '\n') {
                        title[strlen(title) - 2] = '\0';
                        Format(title, sizeof(title), "%s\n ", title, limit);
                    } else {
                        Format(title, sizeof(title), "%s", title, limit);
                    }
                }
                return RedrawMenuItem(title);
            } else {
                switch (buff[1]) {
                    case 'r': {
                        Format(title, 24, "%T", "Menu_Random", client);
                    }

                    case 'b': {
                        Format(title, 24, "%T", "Menu_Back", client);
                    }

                    case 'c': {
                        Format(title, 24, "%T", "Menu_Close", client);
                    }
                }
                return RedrawMenuItem(title);
            }
        }

        case MenuAction_Display: {
            static char title[MENU_TEXT];
            if (team_divided) {
                int team = GetClientTeam(client);
                menu.GetTitle(title, sizeof(title));
                if (title[strlen(title) - 1] == ')') {
                    return 0;
                }
                if (team == 2) {
                    Format(title, sizeof(title), "%s (T)", title);
                } else {
                    Format(title, sizeof(title), "%s (CT)", title);
                }
                menu.SetTitle(title);
            }
        }
    }
    return 0;
}

public int QualityMenuHandler(Menu menu, MenuAction action, int client, int item)
{
    switch (action) {
        case MenuAction_Select: {
            if (item < 5) {
                SaveGlove(client, _, _, 100-25*item);
                SetGlove(client);
                QualityMenu.Display(client, 20);
            } else {
                char buff[8];
                menu.GetItem(item, buff, sizeof(buff));
                if (buff[1] == 'b') {
                    ModelMenu.Display(client, 40);
                }
            }
        }

        case MenuAction_DisplayItem: {
            static char buff[16], display[64];
            menu.GetItem(item, buff, sizeof(buff), _, display, sizeof(display));
            if (buff[0] == '_') {
                switch (buff[1]) {
                    case 'b': {
                        Format(display, sizeof(display), "%T", "Menu_Back", client);
                    }

                    case 'c': {
                        Format(display, sizeof(display), "%T", "Menu_Close", client);
                    }
                }
            } else {
                int num = StringToInt(buff);
                switch (num) {
                    case 0: {
                        Format(display, sizeof(display), "%T", "Menu_Quality0", client);
                    }

                    case 25: {
                        Format(display, sizeof(display), "%T", "Menu_Quality25", client);
                    }

                    case 50: {
                        Format(display, sizeof(display), "%T", "Menu_Quality50", client);
                    }

                    case 75: {
                        Format(display, sizeof(display), "%T", "Menu_Quality75", client);
                    }

                    case 100: {
                        Format(display, sizeof(display), "%T", "Menu_Quality100", client);
                    }
                }
            }
            return RedrawMenuItem(display);
        }

        case MenuAction_Display: {
            char title[MENU_TEXT];
            Format(title, MENU_TEXT, "%T:", "Menu_QualityTitle", client);
            menu.SetTitle(title);
        }
    }
    return 0;
}

public void Event_PlayerSpawn(Event event, const char[] name, bool dontBroadcast)
{
    int client = GetClientOfUserId(event.GetInt("userid"));
    if (!IsFakeClient(client) && GetEntProp(client, Prop_Send, "m_bIsControllingBot") != 1) {
        if (skip_custom_arms) {
            static char buff[3]; static bool informed_to_server = false;
            GetEntPropString(client, Prop_Send, "m_szArmsModel", buff, sizeof(buff));
            if (buff[0]) {
                if (!informed_to_server) {
                    PrintToServer("[GLOVES] Custom arms found on %N!", client);
                    PrintToServer("[GLOVES] Players with custom arms will be skipped!");
                    informed_to_server = true;
                }
                return;
            }
        }
        int wear = GetEntPropEnt(client, Prop_Send, "m_hMyWearables");
        if (wear == -1) {
            SetGlove(client);
        } else {
            if (show_thirdperson) {
                SetEntProp(client, Prop_Send, "m_nBody", 1);
            }
        }
    }
}

public Action FakeTimer(Handle timer, int client)
{
    if (client < 0) {
        CreateTimer(0.0, FakeTimer, client + 100);
    } else {
        SetGlove(client);
    }
    return Plugin_Stop;
}

public Action Cmd_ModelsMenu(int client, int args)
{
    ModelMenu.Display(client, 40);

    return Plugin_Handled;
}

stock void SaveGlove(int client, int model = -1, int skin = -1, int quality = -1, bool inform = false)
{
    if (!IsClientConnected(client) && !IsClientInGame(client)) {
        return;
    }

    int team = 0;
    if (team_divided) {
        team = GetClientTeam(client);
        if (team < 2 && quality == -1) {
            return;
        }
        team -= 2;
    }

    char buff[8], buff2[MENU_TEXT];
    if (model > 0 && model <= GetModelsCount()) {
        IntToString(model, buff, sizeof(buff));
        SetClientCookie(client, ck_Glove_Type[team], buff);
        glove_Type[client][team] = model;
        if (skin != -1 && skin != -2) {
            int limit = GloveAccess(client, model, skin);
            if (limit == 0) {
                ResetGlove(client, false);
                PrintToChat(client, "%s %t", MESSAGE_PREFIX, "NoAccess", clr, 1);
            } else {
                char buff3[MENU_TEXT];
                IntToString(skin, buff, sizeof(buff));
                SetClientCookie(client, ck_Glove_Skin[team], buff);
                glove_Skin[client][team] = skin;
                if (quality == -1 && glove_Quality[client] == -1) {
                    glove_Quality[client] = 100;
                }

                GetModelName(model, buff2);
                GetSkinName(model, skin, buff3);

                if (inform) {
                    PrintToChat(client, "%s %t", MESSAGE_PREFIX, "GloveSave", clr, buff2, buff3, 1);
                }

                if (limit > 0 && limit != 100) {
                    PrintToChat(client, "%s %t", MESSAGE_PREFIX, "LimitQuality", clr, 1, clr, limit, 1);
                }
            }
        } else if (skin == -2) {
            GetModelName(model, buff2);
            PrintToChat(client, "%s %t", MESSAGE_PREFIX, "RandomSet", clr, buff2, 1);
            IntToString(skin, buff, sizeof(buff));
            SetClientCookie(client, ck_Glove_Skin[team], buff);
            glove_Skin[client][team] = skin;
        } else {
            PrintToServer("[GLOVES] Invalid data save! Parameters: %d %d %d %d %d", client, model, skin, quality, inform);
        }
    } if (quality != -1) {
        glove_Quality[client] = quality;
        IntToString(quality, buff, sizeof(buff));
        SetClientCookie(client, ck_Glove_Quality, buff);
        PrintToChat(client, "%s %t", MESSAGE_PREFIX, "QualitySave", clr, quality, 1);
        if (skin > 0) {
            int limit = GloveAccess(client, glove_Type[client][team], glove_Skin[client][team]);
            if (limit == 0) {
                PrintToChat(client, "%s %t", MESSAGE_PREFIX, "RestrictQuality");
            } else if (limit > 0) {
                if (quality>limit) {
                    PrintToChat(client, "%s %t", MESSAGE_PREFIX, "LimitQuality2", clr, 1, clr, limit, 1);
                }
            }
        }
    }
}

stock void SetGlove(int client, int model = -1, int skin = -1, int wear = -1)
{
    if (!b_IsEnabled[client])
    {
        return;
    }

    int team = 0;
    if (!IsClientConnected(client) || !IsClientInGame(client) || IsFakeClient(client)) {
        return;
    }

    if (team_divided) {
        team = GetClientTeam(client);
        if (team < 2) {
            return;
        }

        team -= 2;
    }

    if (model != -3) {
        if ((model == -1 || skin == -1)) {
            if (glove_Type[client][team] != -1 && glove_Skin[client][team] != -1) {
                model = glove_Type[client][team];
                skin = glove_Skin[client][team];
            } else {
                switch (GetClientTeam(client)) {
                    case 2: {
                        model = t_default_model;
                        skin = t_default_skin;
                    }

                    case 3: {
                        model = ct_default_model;
                        skin = ct_default_skin;
                    }
                }
            }
        }

        if (model != -3) {
            int limit = (skin < 1) ? 100 : GloveAccess(client, model, skin);
            if (skin == -2) {
                static int tries = 0;
                do {
                    skin = GetRandomSkin(model);
                    limit = GloveAccess(client, model, skin);
                } while (tries++ < 10 && (limit == 0));

                if (tries > 9 && limit == 0) {
                    PrintToChat(client, "%s %t", MESSAGE_PREFIX, "NoAccess", clr, 1);
                    ResetGlove(client);
                    SetGlove(client);
                    return;
                }
                tries = 0;
            }

            if (wear == -1) {
                if (glove_Quality[client] != -1) {
                    wear = glove_Quality[client];
                } else {
                    wear = 100;
                }

                if (limit == 0) {
                    PrintToChat(client, "%s %t", MESSAGE_PREFIX, "NoAccess", clr, 1);
                    ResetGlove(client);
                    SetGlove(client);
                    return;
                } else if (limit > 0 && wear > limit) {
                    wear = limit;
                }
            }
        }
    }

    int current = GetEntPropEnt(client, Prop_Send, "m_hMyWearables");
    if (current != -1 && IsWearable(current)) {
        AcceptEntityInput(current, "Kill");
        if (current == gloves[client]) {
            gloves[client] = -1;
        }
    }

    if (gloves[client] != -1 && IsWearable(gloves[client])) {
        AcceptEntityInput(gloves[client], "Kill");
        gloves[client] = -1;
    }

    if (model > 0 && skin > 0) {
        int ent = CreateEntityByName("wearable_item");
        if (ent != -1) {
            gloves[client] = ent;
            SetEntPropEnt(client, Prop_Send, "m_hMyWearables", ent);
            SetEntProp(ent, Prop_Send, "m_iItemDefinitionIndex", GetModelIndex(model));
            SetEntProp(ent, Prop_Send,  "m_nFallbackPaintKit", GetSkinIndex(model, skin));
            SetEntPropFloat(ent, Prop_Send, "m_flFallbackWear", 1.0-wear*0.01);
            SetEntProp(ent, Prop_Send, "m_iItemIDLow", 2048);
            SetEntProp(ent, Prop_Send, "m_bInitialized", 1);
            SetEntPropEnt(ent, Prop_Data, "m_hParent", client);
            SetEntPropEnt(ent, Prop_Data, "m_hOwnerEntity", client);
            if (show_thirdperson) {
                SetEntPropEnt(ent, Prop_Data, "m_hMoveParent", client);
                SetEntProp(client, Prop_Send, "m_nBody", 1);
            }
            DispatchSpawn(ent);
        }
    } else {
        SetEntProp(client, Prop_Send, "m_nBody", 0);
    }

    int item = GetEntPropEnt(client, Prop_Send, "m_hActiveWeapon");
    SetEntPropEnt(client, Prop_Send, "m_hActiveWeapon", -1);
    DataPack ph = new DataPack();
    WritePackCell(ph, EntIndexToEntRef(client));
    if (IsValidEntity(item)) {
        WritePackCell(ph, EntIndexToEntRef(item));
    } else {
        WritePackCell(ph, -1);
    }

    CreateTimer(0.0, AddItemTimer, ph, TIMER_FLAG_NO_MAPCHANGE);
}

public Action AddItemTimer(Handle timer, DataPack ph)
{
    int client, item;
    ResetPack(ph);
    client = EntRefToEntIndex(ReadPackCell(ph));
    item = EntRefToEntIndex(ReadPackCell(ph));
    if (client != INVALID_ENT_REFERENCE && item != INVALID_ENT_REFERENCE) {
        SetEntPropEnt(client, Prop_Send, "m_hActiveWeapon", item);
    }
    CloseHandle(ph);
    return Plugin_Stop;
}

stock bool IsWearable(int ent)
{
    static char weaponclass[32];

    return !IsValidEdict(ent)
        && GetEdictClassname(ent, weaponclass, sizeof(weaponclass))
        && StrContains(weaponclass, "wearable", false) != -1;
}

stock int GloveAccess(int client, int model, int skin)
{
    if (model < 0)ThrowError("Wrong model index %d, check code!", model);
    if (skin < 0)ThrowError("Wrong skin index %d, check code!", skin);
    if (model == t_default_model && skin == t_default_skin)return 100;
    if (model == ct_default_model && skin == ct_default_skin)return 100;
    int limit = GetSkinLimit(model, skin);
    if (limit == -1) return 100;
    else return limit;
}

stock void ResetGlove(int client, bool inform = true)
{
    int team = 0;
    if (team_divided) {
        team = GetClientTeam(client);
        if (team < 2) {
            return;
        }

        team -= 2;
    }

    char buff2[MENU_TEXT], buff3[MENU_TEXT];
    glove_Type[client][team] = -3;
    glove_Skin[client][team] = -1;
    glove_Quality[client] = -1;
    SetClientCookie(client, ck_Glove_Type[team], "-3");
    SetClientCookie(client, ck_Glove_Skin[team], "-1");
    SetClientCookie(client, ck_Glove_Quality, "-1");
    SetGlove(client);
    if (inform) {
        team = GetClientTeam(client);
        if (team == 2) {
            if (t_default_model != -3) {
                GetModelName(t_default_model, buff2);
                GetSkinName(t_default_model, t_default_skin, buff3);
                PrintToChat(client, "%s %t", MESSAGE_PREFIX, "ResetTeam", clr, buff2, buff3, 1);
            } else {
                PrintToChat(client, "%s %t", MESSAGE_PREFIX, "Reset");
            }
        } else if (team == 3) {
            if (ct_default_model != -3) {
                GetModelName(ct_default_model, buff2);
                GetSkinName(ct_default_model, ct_default_skin, buff3);
                PrintToChat(client, "%s %t", MESSAGE_PREFIX, "ResetTeam", clr, buff2, buff3, 1);
            } else {
                PrintToChat(client, "%s %t", MESSAGE_PREFIX, "Reset");
            }
        } else {
            PrintToChat(client, "%s %t", MESSAGE_PREFIX, "Reset");
        }
    }
}

stock int GetModelPos(int model)
{
    if (model < 0) {
        ThrowError("Wrong model index %d, check code!", model);
    }

    if (model<=GetModelsCount()) {
        int temp = 1;
        int position = 1;
        while(model != temp++) {
            int skins = alModels.Get(position + 4);
            position += skins*3+5;
        }
        return position;
    }
    return -1;
}

stock int GetSkinPos(int model, int skin)
{
    if (model < 0)ThrowError("Wrong model index %d, check code!", model);
    if (skin < 0)ThrowError("Wrong skin index %d, check code!", skin);
    int position = GetModelPos(model);
    if (skin<=alModels.Get(position + 4))
    {
        return position+5+((skin>1)?(skin-1)*3:0);
    }
    return -1;
}

stock int GetRandomModel()
{
    return GetRandomInt(1, GetModelsCount());
}

stock int GetRandomSkin(int model)
{
    return GetRandomInt(1, GetSkinsCount(model));
}

stock int GetModelsCount()
{
    return alModels.Get(0);
}

stock int GetSkinsCount(int model)
{
    return alModels.Get(GetModelPos(model) + 4);
}

stock int GetModelIndex(int model)
{
    return alModels.Get(GetModelPos(model));
}

stock void GetModelName(int model, char buffer[MENU_TEXT])
{
    alModels.GetString(GetModelPos(model) + 1, buffer, sizeof(buffer));
}

stock void GetModelIcon(int model, char buffer[8])
{
    alModels.GetString(GetModelPos(model) + 2, buffer, sizeof(buffer));
}

stock int GetSkinIndex(int model, int skin)
{
    return alModels.Get(GetSkinPos(model, skin));
}

stock void GetSkinName(int model, int skin, char buffer[MENU_TEXT])
{
    alModels.GetString(GetSkinPos(model, skin) + 1, buffer, sizeof(buffer));
}

stock int GetSkinLimit(int model, int skin)
{
    return alModels.Get(GetSkinPos(model, skin) + 2);
}
