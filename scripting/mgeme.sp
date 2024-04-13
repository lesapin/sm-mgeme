/**
 * =============================================================================
 * MGEME
 * A rewrite of MGEMOD for MGE.ME server.
 *
 * (C) 2024 MGE.ME.  All rights reserved.
 * =============================================================================
 *
 * This program is free software; you can redistribute it and/or modify it under
 * the terms of the GNU General Public License, version 3.0, as published by the
 * Free Software Foundation.
 * 
 * This program is distributed in the hope that it will be useful, but WITHOUT
 * ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
 * FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more
 * details.
 *
 * You should have received a copy of the GNU General Public License along with
 * this program.  If not, see <http://www.gnu.org/licenses/>.
 *
 */

#pragma semicolon 1

#include <sourcemod>
#include <dhooks>
#include <morecolors>
#include <mgeme/players>
#include <mgeme/arenas>

#pragma newdecls required

#define PL_VER "0.8.5"
#define PL_DESC "A complete rewrite of MGEMod by Lange"
#define PL_URL "https://mge.me"

public Plugin myinfo =
{
        name = "MGEME",
        author = "bzdmn",
        description = PL_DESC,
        version = PL_VER,
        url = PL_URL
};

#define MGEME_CONFIG "configs/mgemod_spawns.cfg"
#define GAMEDATA "mgeme.plugin"
#define NAMED_ITEM "CTFPlayer::GiveNamedItem"

#define ADD_USAGE "Usage: add < arenaid > < fraglimit > < 1/2 : 1v1/2v2 > < 1/0 : Elo/NoElo >" 

Handle HUDScore,
       HUDArena,
       HUDBanner;

/**
 * =============================================================================
 * On-FUNCTIONS
 * =============================================================================
 */

public void OnPluginStart()
{
        if (MaxClients > MAX_PLAYERS)
        {
                SetFailState("MaxClients is %i. See 'players.inc'", MAX_PLAYERS);
        }

#if defined _DEBUG
        RegAdminCmd("runtests", Admin_Command_RunTests, 1, "Run test set.");
        RegAdminCmd("fakeclients", Admin_Command_CreateFakeClients, 1, "Spawn fake clients.");
#endif
        RegConsoleCmd("add", Command_Add, "Usage: add <arena number/arena name>. Join an arena.");
        RegConsoleCmd("remove", Command_Remove, "Leave the current arena or queue.");
        RegConsoleCmd("rank", Command_Rank, "View your rating and wins/losses.");
        RegConsoleCmd("settings", Command_Settings, "Arena preferences.");
        RegConsoleCmd("mgeme", Command_MGEME, "Display plugin information.");

        HookEvent("player_death", Event_PlayerDeath, EventHookMode_Pre);
        HookEvent("player_spawn", Event_PlayerSpawn, EventHookMode_Pre);
        HookEvent("player_team", Event_PlayerTeam, EventHookMode_Pre);
        HookEvent("teamplay_round_start", Event_RoundStart_Post, EventHookMode_Post);
        HookEvent("teamplay_team_ready", Event_TeamReady_Post, EventHookMode_Post);
        HookEvent("teamplay_round_win", Event_RoundWin_Post, EventHookMode_Post);

        AddCommandListener(Command_JoinTeam, "jointeam");
        AddCommandListener(Command_JoinClass, "joinclass");
        AddCommandListener(Command_Spectate, "spec_next");
        AddCommandListener(Command_Spectate, "spec_prev");

        HUDScore = CreateHudSynchronizer();
        HUDArena = CreateHudSynchronizer();
        HUDBanner = CreateHudSynchronizer();

        SettingsCki = RegClientCookie("Settings", "Use settings", CookieAccess_Public);
        FourPlayerCki = RegClientCookie("2v2", "Enable 2v2 mode", CookieAccess_Public);
        EloCki = RegClientCookie("Elo", "Enable Elo", CookieAccess_Public);
        FragLimitCki = RegClientCookie("FragLimit", "Use custom fraglimit", CookieAccess_Public);
        
        SetCookiePrefabMenu(SettingsCki, CookieMenu_OnOff, "Use Settings");
        SetCookiePrefabMenu(FourPlayerCki, CookieMenu_YesNo, "Enable 2v2 Mode");
        SetCookiePrefabMenu(EloCki, CookieMenu_YesNo, "Enable Elo");
        SetCookieMenuItem(SettingsCookieMenuHandler, 20, "Set Fraglimit");

        FragLimitPanel = new Panel();
        FragLimitPanel.SetTitle("Select a Fraglimit");
        FragLimitPanel.DrawItem("10");
        FragLimitPanel.DrawItem("20");
        FragLimitPanel.DrawItem("30");
        FragLimitPanel.DrawItem("40");
        FragLimitPanel.DrawItem("50");

        DHookInit();
}

public void OnMapInit(const char[] mapName)
{
        LoadMapConfig(MGEME_CONFIG, mapName);
}

public void OnMapStart()
{
        PrecacheSound(SPAWN_SOUND, true);
        //SetConVarInt(FindConVar("mp_disable_respawn_times"), 1);
        SetConVarInt(FindConVar("mp_autoteambalance"), 0);
}

public void OnClientConnected(int client)
{
        PlayerList[client] = new Player(client);
}

public void OnClientPutInServer(int client)
{
        TF2_ChangeClientTeam(client, TFTeam_Spectator);
        CreateTimer(10.0, Timer_WelcomeMsg1, GetClientSerial(client));
        CreateTimer(7.0, Timer_Warning, GetClientSerial(client));
}

public void OnClientDisconnect(int client)
{
        RemovePlayerFromArena(client, false);
}

/**
 * =============================================================================
 * PLAYER COMMANDS
 * =============================================================================
 */

Action Command_Add(int _client, int args)
{
        int client = _client;

        if (args > 0)
        {
                int FourPlayer = 0, FragLimit = 0;
                bool EloEnabled = true;

                int ArenaIdx = GetCmdArgInt(1);

                if (ArenaIdx > 0 && ArenaIdx <= NumArenas)
                {
#if defined _DEBUG
                        if (args == 2)
                        {
                                client = GetCmdArgInt(2);
                        }
#else
                        if (args > 1)
                        {
                                FragLimit = GetCmdArgInt(2);

                                if (!FragLimit)
                                {
                                        ReplyToCommand(client, ADD_USAGE);
                                        return Plugin_Handled;
                                }
                        }
#endif
                        if (args > 2)
                        {
                                FourPlayer = GetCmdArgInt(3);
                        }

                        if (args > 3)
                        {
                                EloEnabled = GetCmdArgInt(4) == 1 ? true : false;
                        }
                }
                else
                {
                        char arg[32];
                        GetCmdArgString(arg, sizeof(arg));
                        ArenaIdx = StringToArenaIdx(arg);
                }
                    
                if (ArenaIdx)
                {
                        Player _Player = view_as<Player>(client);

                        if (ArenaIdx == _Player.ArenaIdx)
                        {
                                return Plugin_Handled;
                        }

                        Arena _Arena = view_as<Arena>(ArenaIdx);

                        if (_Arena.BBall || _Arena.Endif || _Arena.KOTH || _Arena.Turris)
                        {
                                ReplyToCommand(client, "This mode is not supported");
                                return Plugin_Handled;
                        }

                        if (_Arena.IsEmpty())
                        {
                                _Arena.EloEnabled = EloEnabled;
                                _Arena.FourPlayer = FourPlayer > 1 ? true : false;
                                _Arena.FragLimit = FragLimit > 0 ? FragLimit : _Arena.FragLimit;
                        }
                        else if (args > 1)
                        {
                                ReplyToCommand(client, "Arena is not empty");
                                return Plugin_Handled;
                        }

                        RemovePlayerFromArena(client, false);
                        AddPlayerToArena(client, ArenaIdx);

                        return Plugin_Handled;
                }
        }
        
        ReplyToCommand(client, ADD_USAGE);
        ShowArenaSelectMenu(client);

        return Plugin_Handled;
}

Action Command_Remove(int _client, int args)
{
        int client = _client;
#if defined _DEBUG
        if (args == 1)
        {
                client = GetCmdArgInt(1);
        }
#endif
        RemovePlayerFromArena(client, false);
        RequestFrame(SpectateNextFrame, client);

        return Plugin_Handled;
}

Action Command_Rank(int client, int args)
{
        Player _Player = view_as<Player>(client);

        PrintToChat(client, "Your Elo is %i, with %i wins and %i losses", 
                    _Player.Elo, _Player.Wins, _Player.Losses);
        
        return Plugin_Handled;
}

Action Command_Settings(int client, int args)
{
        if (args == 0)
        {
                ShowCookieMenu(client);
        }

        return Plugin_Handled;
}

Action Command_MGEME(int client, int args)
{
        MC_PrintToChat(client, "{green}MGEME {default}Version %s\n%s", PL_VER, PL_DESC);
        MC_PrintToChat(client, "{default}-----------------------------------------");
        MC_PrintToChat(client, "{green}Author: {default}bzdmn");
        MC_PrintToChat(client, "{green}Website: {default}%s", PL_URL);
        MC_PrintToChat(client, "{green}Commands: {default}!add !remove !rank !settings");
        return Plugin_Handled;
}

Action Command_JoinTeam(int client, const char[] cmd, int args)
{
        char buf[16];
        GetCmdArgString(buf, sizeof(buf));

        if (strcmp(buf, "spectate") == 0)
        {
                TF2_ChangeClientTeam(client, TFTeam_Spectator);

                RemovePlayerFromArena(client, false);
                RequestFrame(SpectateNextFrame, client);

                return Plugin_Handled;
        } 

        return Plugin_Handled;
}

Action Command_JoinClass(int client, const char[] cmd, int args)
{
        char buf[16];
        GetCmdArgString(buf, sizeof(buf));
#if defined _DEBUG
        PrintToChat(client, "Changed class to %s", buf);
#endif
        Player _Player = view_as<Player>(client);
        Arena _Arena = view_as<Arena>(_Player.ArenaIdx);

        if (!_Arena.IsClassAllowed(StringToTFClass(buf)))
        {
                MC_PrintToChat(client, "{olive}%s {default}is not allowed in this arena", buf);
        }
        else
        {
                //TF2_SetPlayerClass(client, StringToTFClass(buf));
                //ForcePlayerSuicide(client);
                return Plugin_Continue;
        }

        return Plugin_Handled;
}

Action Command_Spectate(int client, const char[] cmd, int args)
{
        int PrevTarget = GetEntPropEnt(client, Prop_Send, "m_hObserverTarget");
        Player PrevSpectated = view_as<Player>(PrevTarget);

        if (PrevSpectated.IsValid)
        {
                Arena SpecArena = view_as<Arena>(PrevSpectated.ArenaIdx);
                SpecArena.RemoveSpectator(client);
        }

        RequestFrame(SpectateNextFrame, client);

        return Plugin_Continue;
}

#if defined _DEBUG
Action Admin_Command_RunTests(int client, int args)
{
        RunTests();
        return Plugin_Handled;
}

Action Admin_Command_CreateFakeClients(int client, int args)
{
        if (args != 1)
        {
                return Plugin_Handled;
        }

        int NumClients = GetCmdArgInt(1);

        ReplyToCommand(client, "Creating %i fake clients", NumClients);

        char name[32];
        for (int i = 0; i < NumClients; i++)
        {
                Format(name, sizeof(name), "FakeClient%i", i);
                PrintToChatAll("Created fake client %i", CreateFakeClient(name));
        }

        return Plugin_Handled;
}
#endif

/**
 * =============================================================================
 * HELPER FUNCTIONS
 * =============================================================================
 */

void ShowArenaSelectMenu(int client)
{
        Menu menu = new Menu(ArenaSelectMenuHandler, MENU_ACTIONS_ALL);
        menu.SetTitle("Select an Arena");

        char buf[128];
        char name[64];
        char intstr[4];

        for (int i = 1; i <= NumArenas; i++)
        {
                Arena _Arena = view_as<Arena>(i); 
                _Arena.GetName(name, sizeof(name));

                if (_Arena.NumPlayers)
                {
                        if (_Arena.NumQueued)
                        {
                                Format(buf, sizeof(buf), "%s (%i) (%i)",
                                       name, _Arena.NumPlayers, _Arena.NumQueued);
                        }
                        else
                        {
                                Format(buf, sizeof(buf), "%s (%i)", 
                                       name, _Arena.NumPlayers);
                        }
                }
                else
                {
                        Format(buf, sizeof(buf), "%s ", name);
                }

                IntToString(i, intstr, sizeof(intstr));
                menu.AddItem(intstr, buf);
        }

        menu.Display(client, MENU_TIME_FOREVER);
}

void AddPlayerToArena(int client, int arenaIdx)
{
        Player _Player = view_as<Player>(client);
        Arena _Arena = view_as<Arena>(arenaIdx);

        if (arenaIdx != _Player.ArenaIdx)
        {
                _Player.ArenaIdx = arenaIdx;
                _Arena.Add(client);
                
                if (_Arena.IsPlaying(client))
                {
                        UpdateArenaHUDs(_Arena);
                }        
        }
}

void RemovePlayerFromArena(int client, bool forceSuicide = true)
{
        Player _Player = view_as<Player>(client);
        Arena _Arena = view_as<Arena>(_Player.ArenaIdx);

        if (_Arena.IsValid)
        {
                TFTeam OppTeam = TFTeam_Unassigned;
                bool IsPlaying = _Arena.IsPlaying(client);

                if (IsPlaying) // Is the player in-game or in-queue.
                {
                        if (_Arena.MatchOngoing())
                        {
                                MatchOver(_Arena, client);
                        }

                        if (forceSuicide)
                        {
                                ForcePlayerSuicide(client);
                        }

                        OppTeam = _Arena.OpponentTeam(client);
                }

                _Player.ArenaIdx = 0;
                _Arena.Remove(client);

                //
                // Update arena Elo.
                //

                if (OppTeam == TFTeam_Red)
                {
                        if (_Arena.BLUPlayer1 > 0)
                        {
                                _Arena.BLUElo = view_as<Player>(_Arena.BLUPlayer1).Elo;
                        }
                        else if (_Arena.BLUPlayer2 > 0)
                        {
                                _Arena.BLUElo = view_as<Player>(_Arena.BLUPlayer2).Elo;
                        }
                        else
                        {
                                _Arena.BLUElo = 0;
                        }
                }
                else if (OppTeam == TFTeam_Blue)
                {
                        if (_Arena.REDPlayer1 > 0)
                        {
                                _Arena.REDElo = view_as<Player>(_Arena.REDPlayer1).Elo;
                        }
                        else if (_Arena.REDPlayer2 > 0)
                        {
                                _Arena.REDElo = view_as<Player>(_Arena.REDPlayer2).Elo;
                        }
                        else
                        {
                                _Arena.REDElo = 0;
                        }
                }
                
                int Opp1, Opp2, Ally;
                _Arena.GetOtherPlayers(client, Opp1, Opp2, Ally);

                UpdateHUD(_Arena, Opp1, true, false);
                UpdateHUD(_Arena, Opp2, true, false);
                UpdateHUD(_Arena, Ally, true, false);
        }
}

/**
 * Calculate the Elo gain/loss between RED and BLU from
 * the current state of the arena and update Player info.
 *
 * @param arena         Arena to consider.
 *
 * @return              Elo rating change.
 */
int CalcEloChange(Arena arena)
{
        float TwiceStdDeviation = 400.0;
        float QRed = Pow(10.0, float(arena.REDElo) / TwiceStdDeviation);
        float QBlu = Pow(10.0, float(arena.BLUElo) / TwiceStdDeviation);

        float RedExpectedScore = (QRed / (QRed + QBlu));
        float BluExpectedScore = (QBlu / (QRed + QBlu));
#if defined _DEBUG
        PrintToChatAll("Red expected score: %0.2f", RedExpectedScore);
        PrintToChatAll("Blu expected score: %0.2f", BluExpectedScore);
#endif
        float RedKFactor, BluKFactor;   // Variable K-factor.

        if (arena.REDElo < 2100) RedKFactor = 16.0;
        else if (arena.REDElo <  2400) RedKFactor = 12.0;
        else RedKFactor = 8.0;

        if (arena.BLUElo < 2100) BluKFactor = 16.0;
        else if (arena.BLUElo < 2400) BluKFactor = 12.0;
        else BluKFactor = 8.0;

        //float KFactor = 16.0;           // Universal K-factor.
        float KFactor = BluKFactor < RedKFactor ? BluKFactor : RedKFactor;

        // Handle early leavers.
        int RedFrags = arena.REDScore, BluFrags = arena.BLUScore;

        if (arena.REDScore > arena.BLUScore && arena.REDScore < arena.FragLimit)
        {
                RedFrags = arena.FragLimit;
        }
        else if (arena.BLUScore > arena.REDScore && arena.BLUScore < arena.FragLimit)
        {
                BluFrags = arena.FragLimit;
        }

        float NumRounds = (float(arena.REDScore) + float(arena.BLUScore)) / 1.5;
        float RedScore = float(RedFrags) / NumRounds;
        float BluScore = float(BluFrags) / NumRounds;
           
        // A negative rating change doesn't mean losing, it just means that
        // the player under-performed relative to their expected score.
        return RoundToCeil(KFactor * FloatAbs(RedScore > BluScore ? 
                                             (RedScore - RedExpectedScore) :
                                             (BluScore - BluExpectedScore)
        ));
}

/**
 * Update player wins, losses and Elo.
 *
 * @param winninTeam    The winning team.
 * @param arena         Arena to consider.
 */
void ScoreWinners(TFTeam winningTeam, Arena arena)
{
        Player Red1 = view_as<Player>(arena.REDPlayer1);
        Player Red2 = view_as<Player>(arena.REDPlayer2);
        Player Blu1 = view_as<Player>(arena.BLUPlayer1);
        Player Blu2 = view_as<Player>(arena.BLUPlayer2);

        int EloDiff;
        if (arena.EloEnabled)
        {
                EloDiff = CalcEloChange(arena);
        }
        else
        {
                EloDiff = 0;
        }

        if (winningTeam == TFTeam_Red)
        {
                if (Red1.IsValid) 
                {
                        Red1.Wins = Red1.Wins + 1;
                        Red1.Elo = Red1.Elo + EloDiff;
                        MC_PrintToChat(arena.REDPlayer1, "{olive}You gained %i Elo", EloDiff);
                }
                
                if (Red2.IsValid) 
                {
                        Red2.Wins = Red2.Wins + 1;
                        Red2.Elo = Red2.Elo + EloDiff;
                        MC_PrintToChat(arena.REDPlayer2, "{olive}You gained %i Elo", EloDiff);
                }

                if (Blu1.IsValid) 
                {
                        Blu1.Losses = Blu1.Losses + 1;
                        Blu1.Elo = Blu1.Elo - EloDiff;
                        MC_PrintToChat(arena.BLUPlayer1, "{olive}You lost %i Elo", EloDiff);
                }

                if (Blu2.IsValid) 
                {
                        Blu2.Losses = Blu2.Losses + 1;
                        Blu2.Elo = Blu2.Elo - EloDiff;
                        MC_PrintToChat(arena.BLUPlayer2, "{olive}You lost %i Elo", EloDiff);
                }
        }
        else
        {
                if (Red1.IsValid) 
                {
                        Red1.Losses = Red1.Losses + 1;
                        Red1.Elo = Red1.Elo - EloDiff;
                        MC_PrintToChat(arena.REDPlayer1, "{olive}You lost %i Elo", EloDiff);
                }
                
                if (Red2.IsValid) 
                {
                        Red2.Losses = Red2.Losses + 1;
                        Red2.Elo = Red2.Elo - EloDiff;
                        MC_PrintToChat(arena.REDPlayer2, "{olive}You lost %i Elo", EloDiff);
                }

                if (Blu1.IsValid) 
                {
                        Blu1.Wins = Blu1.Wins + 1;
                        Blu1.Elo = Blu1.Elo + EloDiff;
                        MC_PrintToChat(arena.BLUPlayer1, "{olive}You gained %i Elo", EloDiff);
                }

                if (Blu2.IsValid) 
                {
                        Blu2.Wins = Blu2.Wins + 1;
                        Blu2.Elo = Blu2.Elo + EloDiff;
                        MC_PrintToChat(arena.BLUPlayer2, "{olive}You gained %i Elo", EloDiff);
                }
        }
}

/**
 * Take the first connected player from PlayerQueue.
 *
 * @param arena         Arena to consider.
 *
 * @return              Client index or 0 if no valid clients.
 */
int TakeFromQueue(Arena arena)
{
        int Serial, NewClient = 0;

        while (NewClient == 0 && arena.NumQueued > 0)
        {
                Serial = arena.PlayerQueue.Head();
                NewClient = GetClientFromSerial(Serial);
                arena.PlayerQueue.Delete(Serial);
        }

        return NewClient;
}

/**
 * Handle game state when the match ends either by
 * reaching FragLimit or client disconnecting.
 *
 * @param winner        The winnning team.
 * @param arena         The arena to consider.
 * @param client        The client who died last or disconnected.
 */
void MatchOver(Arena arena, int client)
{
        arena.ClientReplaced = client;

        if (arena.OpponentScore(client) > arena.EarlyLeave)
        {
                if (!arena.FourPlayer)
                {
                        char loser[32], winner[32];
                        GetClientName(arena.Opponent(client), winner, sizeof(winner));
                        GetClientName(client, loser, sizeof(loser));

                        MC_PrintToChatAll("{olive}%s {default}defeats {olive}%s \
                                           {default}in {olive}%i {default}to {olive}%i",
                                          winner, loser, arena.WinnerScore, arena.LoserScore);
                }

                ScoreWinners(arena.OpponentTeam(client), arena);
        }

        arena.State = UpdateState(arena, Arena_Ended);
}

/**
 * Display the arena HUD with updated scores to a player/spectator
 * and avoid redrawing the whole HUD if possible.
 *
 * @param arena                 Arena to consider.
 * @param client                Client to draw to.
 * @param updateEverything      Update every part of the HUD.
 */
void UpdateHUD(Arena arena, int client, bool updateEverything = true, bool updateScores = true)
{
        if (!client) return;

        if (!arena.IsValid)
        {
                ClearHUD(client);
                return;
        }

        char hud[ARENA_HUD_SIZE];
        char scores[32] = "";
        
        if (arena.MatchOngoing())
        {
                if (!arena.HUD)
                {
                        DrawHUD(arena, hud, sizeof(hud));
                        arena.SetHUD(hud);
                }
                else
                {
                        arena.GetHUD(hud, sizeof(hud));
                }

                if (updateScores) 
                {
                        int offset = arena.RedScoreOffset > arena.BluScoreOffset ?
                                     arena.RedScoreOffset : arena.BluScoreOffset ;
                
                        Format(scores, sizeof(scores), "\n %i\n %i", arena.BLUScore, arena.REDScore);
                        SetHudTextParams(float(offset) * 0.0093, 0.01, 99999.9, 255, 255, 255, 125);
                }

                ShowSyncHudText(client, HUDScore, "%s", scores);
        }
        else
        {
                DrawHUD(arena, hud, sizeof(hud));
        }

        if (updateEverything)
        {
                SetHudTextParams(0.01, 0.01, 99999.9, 255, 255, 255, 125);
                ShowSyncHudText(client, HUDArena, "%s", hud);
        }

        SetHudTextParams(0.65, 0.95, 99999.9, 60, 238, 255, 255);
        ShowSyncHudText(client, HUDBanner, "mge.me");
}

void UpdateSpectatorHUDs(Arena arena, bool updateEverything = false)
{
        LinkedList Node = arena.SpectatorList.HeadNode();

        while (Node != view_as<LinkedList>(EmptyNode))
        {
                int Serial = Node.ClientSerial;
                int Spectator = GetClientFromSerial(Serial);
                Node = Node.HeadNode();
                                
                if (!Spectator || !IsClientObserver(Spectator))
                {
                        arena.SpectatorList.Delete(Serial);
                }
                else
                {
                        UpdateHUD(arena, Spectator, true);
                }
        }
}

/**
 * Update the whole HUD for everyone currently playing and
 * spectating in an arena.
 *
 * @param arena         Arena to consider.
 */
void UpdateArenaHUDs(Arena arena)
{
        Player Red1 = view_as<Player>(arena.REDPlayer1);
        Player Red2 = view_as<Player>(arena.REDPlayer2);
        Player Blu1 = view_as<Player>(arena.BLUPlayer1);
        Player Blu2 = view_as<Player>(arena.BLUPlayer2);

        if (Red1.IsValid)
        {
                UpdateHUD(arena, arena.REDPlayer1);
        }
        
        if (Red2.IsValid)
        {
                UpdateHUD(arena, arena.REDPlayer2);
        }
        
        if (Blu1.IsValid)
        {
                UpdateHUD(arena, arena.BLUPlayer1);
        }

        if (Blu2.IsValid)
        {
                UpdateHUD(arena, arena.BLUPlayer2);
        }

        if (arena.NumSpectators > 0)
        {
                UpdateSpectatorHUDs(arena, true);
        }
}

/**
 * Format the arena HUD in a buffer.
 *
 * @param arena         Arena to consider.
 * @param hud           Location to store the HUD.
 * @param ssize         Buffer size.
 */
void DrawHUD(Arena arena, char[] hud, int ssize)
{
        char name[128], name2[128], buf[255], arenaName[128];

        arena.GetName(arenaName, sizeof(arenaName));

        if (arena.FourPlayer)
        {
                StrCat(arenaName, sizeof(arenaName), " [2v2]");
        }
        else
        {
                StrCat(arenaName, sizeof(arenaName), " [1v1]");
        }

        if (!arena.EloEnabled)
        {
                StrCat(arenaName, sizeof(arenaName), " NoElo");
        }

        Format(buf, sizeof(buf), "Arena %s FragLimit(%i)\n", arenaName, arena.FragLimit);
        StrCat(hud, ssize, buf);

        Player Blu1 = view_as<Player>(arena.BLUPlayer1);
        Player Blu2 = view_as<Player>(arena.BLUPlayer2);
        Player Red1 = view_as<Player>(arena.REDPlayer1);
        Player Red2 = view_as<Player>(arena.REDPlayer2);

        int BluOffset = 0, RedOffset = 0;

        if (Blu1.IsValid)
        {
                GetClientName(arena.BLUPlayer1, name, sizeof(name));
                BluOffset += Format(buf, sizeof(buf), "%s ", name);
                StrCat(hud, ssize, buf);
        }

        if (Blu2.IsValid)
        {
                GetClientName(arena.BLUPlayer2, name2, sizeof(name2));
                BluOffset += Format(buf, sizeof(buf), "%s ", name2);
                StrCat(hud, ssize, buf);
        }
        
        if (Blu1.IsValid || Blu2.IsValid)
        {
                BluOffset += Format(buf, sizeof(buf), "(%i)\n", arena.BLUElo);
                StrCat(hud, ssize, buf);
        }

        if (Red1.IsValid)
        {
                GetClientName(arena.REDPlayer1, name, sizeof(name));
                RedOffset += Format(buf, sizeof(buf), "%s ", name);
                StrCat(hud, ssize, buf);
        }

        if (Red2.IsValid)
        {
                GetClientName(arena.REDPlayer2, name2, sizeof(name2));
                RedOffset += Format(buf, sizeof(buf), "%s ", name2);
                StrCat(hud, ssize, buf);
        }

        if (Red1.IsValid || Red2.IsValid)
        {
                RedOffset += Format(buf, sizeof(buf), "(%i)\n", arena.REDElo);
                StrCat(hud, ssize, buf);
        }

        arena.BluScoreOffset = BluOffset;
        arena.RedScoreOffset = RedOffset;
}

void ClearHUD(int client)
{
        ClearSyncHud(client, HUDScore);
        ClearSyncHud(client, HUDArena);
}

TFClassType StringToTFClass(const char[] str)
{
        if (strcmp(str, "scout") == 0)        return TFClass_Scout;
        if (strcmp(str, "soldier") == 0)      return TFClass_Soldier;
        if (strcmp(str, "demoman") == 0)      return TFClass_DemoMan;
        if (strcmp(str, "sniper") == 0)       return TFClass_Sniper;
        if (strcmp(str, "medic") == 0)        return TFClass_Medic;
        if (strcmp(str, "engineer") == 0)     return TFClass_Engineer;
        if (strcmp(str, "heavyweapons") == 0) return TFClass_Heavy;
        if (strcmp(str, "pyro") == 0)         return TFClass_Pyro;
        if (strcmp(str, "spy") == 0)          return TFClass_Spy;

        return TFClass_Unknown;
}

void SpawnNextFrame(int client)
{
        TF2_RespawnPlayer(client);
}

void SpectateNextFrame(int client)
{
        int Target = GetEntPropEnt(client, Prop_Send, "m_hObserverTarget");
#if defined _DEBUG
        PrintToChat(client, "Command_Spectate, target: %i", Target);
#endif
        Player Spectated = view_as<Player>(Target);

        if (Spectated.IsValid)
        {
                Arena SpecArena = view_as<Arena>(Spectated.ArenaIdx);
                SpecArena.AddSpectator(client);
                UpdateHUD(SpecArena, client);
        }
        else
        {
                ClearHUD(client);
        }
}

/**
 * =============================================================================
 * MENU FUNCTIONS
 * =============================================================================
 */

int ArenaSelectMenuHandler(Menu menu, MenuAction action, int param1, int param2)
{
        switch (action)
        {
                // Nothing passed.
                case MenuAction_Start:
                {


                }
                // param1 = client, param2 = MenuPanel handle.
                case MenuAction_Display:
                {


                }
                // param1 = client, param2 = selected item.
                case MenuAction_Select:
                {
                        char param[32];
                        menu.GetItem(param2, param, sizeof(param));

                        RemovePlayerFromArena(param1, false);
                        AddPlayerToArena(param1, StringToInt(param));
                }
                // param1 = client, param2 = reason.
                case MenuAction_Cancel:
                {


                }
                // param1 = client, param2 = item.
                case MenuAction_DrawItem:
                {
                        int style;
                        char param[16];
                        menu.GetItem(param2, param, sizeof(param), style);

                        Arena _Arena = view_as<Arena>(StringToInt(param));

                        if (_Arena.BBall || _Arena.Endif || _Arena.KOTH || _Arena.Turris)
                        {
                                return ITEMDRAW_DISABLED;
                        }

                        return style;
                }
                // param1 = client, param2 = item.
                case MenuAction_DisplayItem:
                {


                }
                // param1 = MenuEnd reason, param2 = MenuCancel reason.
                case MenuAction_End:
                {
                        delete menu;
                }
        }

        return 0;
}

void SettingsCookieMenuHandler(int client, CookieMenuAction action, any info, char[] buf, int maxlen)
{
        switch (action)
        {
                case CookieMenuAction_DisplayOption:
                {
                        //PrintToChat(client, "Display %s", buf);
                }

                case CookieMenuAction_SelectOption:
                {
                        //PrintToChat(client, "Selected %i", info);
                        FragLimitPanel.Send(client, FragLimitPanelHandler, MENU_TIME_FOREVER);
                }
        }
}

int FragLimitPanelHandler(Menu menu, MenuAction action, int param1, int param2)
{
        switch (action)
        {
                case MenuAction_Select:
                {
                        //PrintToChat(param1, "Selected item %i", param2);
                        char buf[8];
                        IntToString(param2 * 10, buf, sizeof(buf));
                        SetClientCookie(param1, FragLimitCki, buf);
                }

                case MenuAction_Cancel:
                {
                        ShowCookieMenu(param1);
                }
        }

        return 0;
}

/**
 * =============================================================================
 * TIMER FUNCTIONS
 * =============================================================================
 */
/*
public Action Timer_Teleport(Handle timer, int serial)
{
        int client = GetClientFromSerial(serial);

        if (client > 0)
        {
#if defined _DEBUG
                PrintToChat(client, "Timer_Teleport");
#endif
                Player _Player = view_as<Player>(client);
                Arena _Arena = view_as<Arena>(_Player.ArenaIdx);

                float xyz[3], angles[3];

                if (_Arena.MatchOngoing())
                {
                        float Coords[3];
                        Player Opp1 = view_as<Player>(_Arena.Opponent1(client));
                        Player Opp2 = view_as<Player>(_Arena.Opponent2(client));

                        if (Opp1.IsValid)
                        {       
                                Opp1.GetCoords(Coords); 
                        }
                        else
                        {
                                Opp2.GetCoords(Coords);
                        }

                        _Arena.GetFarSpawn(xyz, angles, Coords);
                }
                else
                {
                        _Arena.GetRandomSpawn(xyz, angles);
                }

                _Player.Teleport(xyz, angles);

                UpdateHUD(_Arena, client);
        }

        return Plugin_Stop;
}
*/
public Action Timer_Respawn(Handle timer, int serial)
{
        int client = GetClientFromSerial(serial);

        if (client > 0)
        {
                TF2_RespawnPlayer(client);
                //RequestFrame(SpawnNextFrame, client);
        }

        return Plugin_Stop;
}

public Action Timer_Match_Start(Handle timer, Arena arena)
{
#if defined _DEBUG
        PrintToChatAll("Timer_Match_Start");
#endif
        if (arena.State != Arena_Ready)
        {
                return Plugin_Handled;
        }
        
        arena.State = UpdateState(arena, Arena_Started);
        
        Player Red1 = view_as<Player>(arena.REDPlayer1);
        Player Red2 = view_as<Player>(arena.REDPlayer2);
        Player Blu1 = view_as<Player>(arena.BLUPlayer1);
        Player Blu2 = view_as<Player>(arena.BLUPlayer2);

        if (Red1.IsValid)
        {
                PrintCenterText(arena.REDPlayer1, " ");
                UpdateHUD(arena, arena.REDPlayer1);
        }
                
        if (Red2.IsValid) 
        {
                PrintCenterText(arena.REDPlayer2, " ");
                UpdateHUD(arena, arena.REDPlayer2);
        }
                
        if (Blu1.IsValid)
        {
                PrintCenterText(arena.BLUPlayer1, " ");
                UpdateHUD(arena, arena.BLUPlayer1);
        }

        if (Blu2.IsValid) 
        {
                PrintCenterText(arena.BLUPlayer2, " ");
                UpdateHUD(arena, arena.BLUPlayer2);
        }

        if (arena.NumSpectators > 0)
        {
                UpdateSpectatorHUDs(arena);
        }

        return Plugin_Stop;
}

public Action Timer_Match_End(Handle timer, Arena arena)
{
        if (arena.NumQueued > 0)
        {
                int NewClient = TakeFromQueue(arena);

                if (NewClient)
                {
                        bool IsPlaying = arena.IsPlaying(arena.ClientReplaced);
                        
                        if (IsPlaying)
                        {
                                // Remove the previous player.
                                RemovePlayerFromArena(arena.ClientReplaced); 
                        }

                        RemovePlayerFromArena(NewClient); // Remove new player from player queue.
                        AddPlayerToArena(NewClient, view_as<int>(arena)); // Add them in the arena.

                        if (IsPlaying)
                        {
                                // Add the old player in the queue.
                                AddPlayerToArena(arena.ClientReplaced, view_as<int>(arena));
                        }
                }
        }
        else
        {
                arena.State = UpdateState(arena, Arena_PlayerChange);
        }

        return Plugin_Stop;
}

public Action Timer_WelcomeMsg1(Handle timer, int serial)
{       
        int client = GetClientFromSerial(serial);

        if (client)
        {
                MC_PrintToChat(client, "{olive}To join an arena, type {default}!add <arenaid/name>");
                CreateTimer(6.0, Timer_WelcomeMsg2, serial);
        }

        return Plugin_Stop;
}

public Action Timer_WelcomeMsg2(Handle timer, int serial)
{
        int client = GetClientFromSerial(serial);

        if (client)
        {
                MC_PrintToChat(client, "{olive}MGEME %s {default}| {green}!mgeme {default}for help", PL_VER);
        }

        return Plugin_Stop;
}

public Action Timer_Warning(Handle timer, int serial)
{
        int client = GetClientFromSerial(serial);

        if (client)
        {
                MC_PrintToChat(client, "{yellow}[SERVER] We are testing a new MGE plugin over the \
                                        weekend. If you have any feedback, please comment in the \
                                        chat and I will look through it in the logs later on.");
        }

        return Plugin_Stop;
}

/**
 * =============================================================================
 * EVENT HANDLERS
 * =============================================================================
 */

public Action Event_PlayerDeath(Event ev, const char[] name, bool dontBroadcast)
{
        int client = GetClientOfUserId(ev.GetInt("userid"));
        int attacker = GetClientOfUserId(ev.GetInt("attacker"));
#if defined _DEBUG
        PrintToChat(client, "Event_PlayerDeath");
#endif
        Player _Player = view_as<Player>(client);
        Arena _Arena = view_as<Arena>(_Player.ArenaIdx);

        if (_Arena.MatchOngoing())
        {
                if (_Arena.OpponentTeam(client) == TFTeam_Red)
                {
                        _Arena.REDScore = _Arena.REDScore + 1;
                }
                else
                {
                        _Arena.BLUScore = _Arena.BLUScore + 1;
                }

                UpdateSpectatorHUDs(_Arena);
                
                Player Opp1 = view_as<Player>(_Arena.Opponent1(client)),
                       Opp2 = view_as<Player>(_Arena.Opponent2(client)),
                       Ally = view_as<Player>(_Arena.Ally(client));
        
                // Replenish only the attacker in 2v2 (and 1v1).
                if (client != attacker && _Arena.IsPlaying(attacker))
                {
                        int HP = GetEntProp(attacker, Prop_Data, "m_iHealth");
                        HP = HP > 0 ? HP : 0;
                        MC_PrintToChat(client, "{green}[MGE] {default}Attacker had %i health left", HP);

                        view_as<Player>(attacker).RefreshHP(_Arena.HPRatio);
                        view_as<Player>(attacker).RefreshAmmo();
                }
                // If a player killbinds in 2v2, don't replenish opponents.
                else if (!_Arena.FourPlayer)
                {
                        if (Opp1.IsValid)
                        {
                                Opp1.RefreshHP(_Arena.HPRatio);
                                Opp1.RefreshAmmo();
                        }
                        else
                        {
                                Opp2.RefreshHP(_Arena.HPRatio);
                                Opp2.RefreshAmmo();
                        }
                }

                if (Opp1.IsValid) UpdateHUD(_Arena, _Arena.Opponent1(client), false, true);
                if (Opp2.IsValid) UpdateHUD(_Arena, _Arena.Opponent2(client), false, true);
                if (Ally.IsValid) UpdateHUD(_Arena, _Arena.Ally(client), false, true);

                if (_Arena.REDScore >= _Arena.FragLimit || _Arena.BLUScore >= _Arena.FragLimit)
                {
                        MatchOver(_Arena, client);
                }
        }

        CreateTimer(_Arena.RespawnTime, Timer_Respawn, GetClientSerial(client));
        
        return Plugin_Continue;
}

public Action Event_PlayerSpawn(Event ev, const char[] name, bool dontBroadcast)
{
        int client = GetClientOfUserId(ev.GetInt("userid"));
#if defined _DEBUG
        PrintToChat(client, "Event_PlayerSpawn");
#endif
        Player _Player = view_as<Player>(client);
        Arena _Arena = view_as<Arena>(_Player.ArenaIdx);

        float xyz[3], angles[3];

        if (_Arena.MatchOngoing())
        {
                float Coords[3];
                Player Opp1 = view_as<Player>(_Arena.Opponent1(client));
                Player Opp2 = view_as<Player>(_Arena.Opponent2(client));

                if (Opp1.IsValid)
                {       
                        Opp1.GetCoords(Coords); 
                }
                else
                {
                        Opp2.GetCoords(Coords);
                }

                _Arena.GetFarSpawn(xyz, angles, Coords);
        }
        else
        {
                _Arena.GetRandomSpawn(xyz, angles);
        }

        _Player.RefreshHP(_Arena.HPRatio);
        _Player.Teleport(xyz, angles);
        
        UpdateHUD(_Arena, client);

        return Plugin_Continue;
}

public Action Event_PlayerTeam(Event ev, const char[] name, bool dontBroadcast)
{
        int client = GetClientOfUserId(ev.GetInt("userid"));
#if defined _DEBUG
        PrintToChat(client, "Event_PlayerTeam");
#endif
        TFTeam NewTeam = view_as<TFTeam>(ev.GetInt("team"));

        Player _Player = view_as<Player>(client);
        Arena _Arena = view_as<Arena>(_Player.ArenaIdx);

        // Initialize the arena for player.
        if (NewTeam == TFTeam_Red)
        {
                if (_Arena.REDElo > 0)
                {
                        _Arena.REDElo = RoundFloat(float(_Arena.REDElo + _Player.Elo) / 2.0);
                }
                else
                {
                        _Arena.REDElo = _Player.Elo;
                }
                
                if (!_Player.IsAlive)
                {
                        RequestFrame(SpawnNextFrame, client);
                }
        }
        else if (NewTeam == TFTeam_Blue)
        {
                if (_Arena.BLUElo > 0)
                {
                        _Arena.BLUElo = RoundFloat(float(_Arena.BLUElo + _Player.Elo) / 2.0);
                }
                else
                {
                        _Arena.BLUElo = _Player.Elo;
                }
                
                if (!_Player.IsAlive)
                {
                        RequestFrame(SpawnNextFrame, client);
                }
        }
        
        UpdateHUD(_Arena, client, true, false);
       
        return Plugin_Handled;
}

public Action Event_RoundStart_Post(Event ev, const char[] name, bool dontBroadcast)
{
        SetConVarInt(FindConVar("mp_waitingforplayers_cancel"), 1);
        return Plugin_Handled;
}

public Action Event_TeamReady_Post(Event ev, const char[] name, bool dontBroadcast)
{
#if defined _DEBUG
        PrintToChatAll("Event_TeamReady");
#endif
        Arena arena = view_as<Arena>(ev.GetInt("team"));

        if (arena.IsValid)
        {
                Player Red1 = view_as<Player>(arena.REDPlayer1);
                Player Red2 = view_as<Player>(arena.REDPlayer2);
                Player Blu1 = view_as<Player>(arena.BLUPlayer1);
                Player Blu2 = view_as<Player>(arena.BLUPlayer2);

                if (Red1.IsValid)
                {
                        TF2_RespawnPlayer(arena.REDPlayer1);
                        Red1.DisableAttacks(float(arena.CDTime));
                        PrintCenterText(arena.REDPlayer1, "Match starting in %i seconds", arena.CDTime);
                }
                
                if (Red2.IsValid) 
                {
                        TF2_RespawnPlayer(arena.REDPlayer2);
                        Red2.DisableAttacks(float(arena.CDTime));
                        PrintCenterText(arena.REDPlayer2, "Match starting in %i seconds", arena.CDTime);
                }
                
                if (Blu1.IsValid)
                {
                        TF2_RespawnPlayer(arena.BLUPlayer1);
                        Blu1.DisableAttacks(float(arena.CDTime));
                        PrintCenterText(arena.BLUPlayer1, "Match starting in %i seconds", arena.CDTime);
                }

                if (Blu2.IsValid) 
                {
                        TF2_RespawnPlayer(arena.BLUPlayer2);
                        Blu2.DisableAttacks(float(arena.CDTime));
                        PrintCenterText(arena.BLUPlayer2, "Match starting in %i seconds", arena.CDTime);
                }
        
                CreateTimer(float(arena.CDTime), Timer_Match_Start, arena);
        }

        return Plugin_Handled;
}

public Action Event_RoundWin_Post(Event ev, const char[] name, bool dontBroadcast)
{
        Arena arena = view_as<Arena>(ev.GetInt("full_round"));

        Player Red1 = view_as<Player>(arena.REDPlayer1);
        Player Red2 = view_as<Player>(arena.REDPlayer2);
        Player Blu1 = view_as<Player>(arena.BLUPlayer1);
        Player Blu2 = view_as<Player>(arena.BLUPlayer2);
#if defined _DEBUG
        if (Red1.IsValid) PrintToChat(arena.REDPlayer1, "Event_RoundWin_Post");
        if (Red2.IsValid) PrintToChat(arena.REDPlayer2, "Event_RoundWin_Post");
        if (Blu1.IsValid) PrintToChat(arena.BLUPlayer1, "Event_RoundWin_Post");
        if (Blu2.IsValid) PrintToChat(arena.BLUPlayer2, "Event_RoundWin_Post");
#endif

        //
        // Update arena Elos.
        //

        arena.REDElo = 0;
        arena.BLUElo = 0;

        if (Red1.IsValid)
        {
                arena.REDElo += Red1.Elo;
        }

        if (Red2.IsValid)
        {
                arena.REDElo += Red2.Elo;
        }

        if (Red1.IsValid && Red2.IsValid)
        {
                arena.REDElo = arena.REDElo / 2;
        }

        if (Blu1.IsValid)
        {
                arena.BLUElo += Blu1.Elo;
        }

        if (Blu2.IsValid)
        {
                arena.BLUElo += Blu2.Elo;
        }

        if (Blu1.IsValid && Blu2.IsValid)
        {
                arena.BLUElo = arena.BLUElo / 2;
        }

        CreateTimer(float(arena.CDTime), Timer_Match_End, arena);

        return Plugin_Handled;
}

/**
 * =============================================================================
 * SDKHook / DHook FUNCTIONS
 * =============================================================================
 */

bool DHookInit()
{
        Handle hGameData = LoadGameConfigFile(GAMEDATA);

        if (!hGameData)
        {
                LogError("Couldn't load gamedata %s", GAMEDATA);
                delete hGameData;
                return false;
        }

        //
        // Initialize DHooks
        //

        Handle Hook = DHookCreateDetour(Address_Null, CallConv_THISCALL, ReturnType_CBaseEntity,
                                        ThisPointer_CBaseEntity);

        if (!Hook)
        {
                LogError("Couldn't detour %s", NAMED_ITEM);
                delete hGameData;
                return false;
        }

        if (DHookSetFromConf(Hook, hGameData, SDKConf_Signature, NAMED_ITEM))
        {
                DHookAddParam(Hook, HookParamType_CharPtr);
                DHookAddParam(Hook, HookParamType_Int);
                DHookAddParam(Hook, HookParamType_ObjectPtr);

                if (!DHookEnableDetour(Hook, true, DHook_WeaponChange))
                {
                        LogError("Couldn't enable detour for %s", NAMED_ITEM);
                        delete hGameData;
                        delete Hook;
                        return false;
                }
        }
        else
        {
                LogError("Failed to read %s signature", NAMED_ITEM);
                delete hGameData;
                delete Hook;
                return false;
        }

        delete Hook;
        delete hGameData;
        return true;
}

/**
 * This hook is called every time just before a player is about to change an item
 * in their loadout. During this time, the item entindex will be invalid (-1).
 * Figure out which slot got changed (0 or 1, every other slot is misc/melee),
 * and update the weapon type/clip/ammo counts.
 */
MRESReturn DHook_WeaponChange(Address pThis, Handle hReturn, Handle hParams)
{
        int client = view_as<int>(pThis);
        int WeaponEnt = DHookGetReturn(hReturn); // :CBaseEntity
        int WeaponSlot = GetPlayerWeaponSlot(client, 0);
        int WeaponSlot2 = GetPlayerWeaponSlot(client, 1);
 
        if (WeaponSlot != -1 && WeaponSlot2 != -1)
        {
                return MRES_Ignored;
        }
        
        WeaponSlot = WeaponSlot == -1 ? 0 : 1;

        Player _Player = view_as<Player>(client);

        if (HasEntProp(WeaponEnt, Prop_Data, "m_iClip1"))
        {
                if (WeaponSlot == 0)
                {
                        _Player.Primary = WeaponEnt;        
                        _Player.ClipPrimary = GetEntProp(WeaponEnt, Prop_Data, "m_iClip1");
                        _Player.TypePrimary = GetEntProp(WeaponEnt, Prop_Send, "m_iPrimaryAmmoType");
                        _Player.AmmoPrimary = _Player.TypePrimary > 0 ? 
                                      GetEntProp(client, Prop_Send, "m_iAmmo", _, _Player.TypePrimary) : 0;
                }
                else if (WeaponSlot == 1)
                {
                        _Player.Secondary = WeaponEnt;
                        _Player.ClipSecondary = GetEntProp(WeaponEnt, Prop_Data, "m_iClip1");
                        _Player.TypeSecondary = GetEntProp(WeaponEnt, Prop_Send, "m_iPrimaryAmmoType");
                        _Player.AmmoSecondary = _Player.TypeSecondary > 0 ? 
                                        GetEntProp(client, Prop_Send, "m_iAmmo", _, _Player.TypeSecondary) : 0;
                }
        }
        else
        {
                if (WeaponSlot == 0)
                {
                        _Player.Primary = -1;
                }
                else if (WeaponSlot ==  1)
                {
                        _Player.Secondary = -1;
                }
        }
#if defined _DEBUG
        PrintToChat(client, "DHook_WeaponChange %i %i", WeaponEnt, WeaponSlot);
#endif
        return MRES_Ignored;
}

/**
 * =============================================================================
 * TESTING
 * =============================================================================
 */

#if defined _DEBUG
#include <testing>

void RunTests()
{
        PrintToServer("\nRunning MGEME plugin tests\n_______________");
        LinkedListTests();
        ArenaTests();
        PlayerTests();
        PrintToServer("Tests finished\n");
}

void LinkedListTests()
{
        PrintToServer("LinkedListTests()");

        LinkedList test = new LinkedList();
        
        AssertEq("Size is 0", test.Size, 0);
        AssertEq("Head is empty", test.Head(), 0);
        test.Append(123);
        test.Append(333);
        test.Append(64634);
        AssertEq("Size is 3", test.Size, 3);
        AssertEq("333 exists", test.Exists(333), true);
        AssertEq("123 is head", test.Head(), 123);
        AssertEq("666 can't be deleted", test.Delete(666), false);
        AssertEq("123 was deleted", test.Delete(123), true);
        AssertEq("Size is 2", test.Size, 2);
        AssertEq("Head is 333", test.Head(), 333);
        AssertEq("64634 exists", test.Exists(64634), true);
        test.Append(765);
        test.Append(945);
        AssertEq("Size is 4", test.Size, 4);
        AssertEq("765 exists", test.Exists(765), true);
        test.DeleteAll();
        AssertEq("Size is 0", test.Size, 0);

        delete test;
}

void ArenaTests()
{
        /*
        LoadMapConfig(MGEME_CONFIG, "mge_training_v8_beta4b");

        Arena TestArena = ArenaList[15];

        if (TestArena.IsValid) 
        {
                float xyz[3], angles[3];
                TestArena.GetSpawn(xyz, angles);

                PrintToServer("spawnid 2, arenaidx 1: %f %f %f %f %f %f", xyz[0], xyz[1], xyz[2],
                               angles[0], angles[1], angles[2]);
        }

        PrintToServer("allowed classes: %i", TestArena.AllowedClasses);
        */
}

void PlayerTests()
{


}


#endif
