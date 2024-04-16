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
//#include <dhooks>
#include <morecolors>
#include <mgeme/players>
#include <mgeme/arenas>

#pragma newdecls required

#define PL_VER "0.8.9"
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

#define ADD_USAGE "!add <arenaid/name> [-fraglimit <num> -noelo -2v2]" 
#define ADD_FLAGS 3

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
        RegAdminCmd("refresh", Admin_Command_Refresh, 1);
#endif
        RegConsoleCmd("add", Command_Add, "Usage: add <arena number/arena name>. Join an arena.");
        RegConsoleCmd("remove", Command_Remove, "Leave the current arena or queue.");
        RegConsoleCmd("rank", Command_Rank, "View your rating and wins/losses.");
        RegConsoleCmd("settings", Command_Settings, "Arena preferences.");
        RegConsoleCmd("mgeme", Command_MGEME, "Display plugin information.");

        HookEvent("player_death", Event_PlayerDeath, EventHookMode_Pre);
        HookEvent("player_spawn", Event_PlayerSpawn_Post, EventHookMode_Post);
        HookEvent("player_team", Event_PlayerTeam, EventHookMode_Pre);
        HookEvent("player_team", Event_PlayerTeam_Post, EventHookMode_Post);
        //HookEvent("player_class", Event_PlayerClass_Post, EventHookMode_Post);
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

/*
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
*/
}

public void OnMapInit(const char[] mapName)
{
        LoadMapConfig(MGEME_CONFIG, mapName);
}

public void OnMapStart()
{
        PrecacheSound(SPAWN_SOUND, true);
        SetConVarInt(FindConVar("mp_autoteambalance"), 0);
}

public void OnClientPostAdminCheck(int client)
{
        PlayerList[client] = new Player(client);
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

        if (!args)
        {
                ShowArenaSelectMenu(client);
                return Plugin_Handled;
        }

        char arg[128];

        GetCmdArgString(arg, sizeof(arg));

        int HyphenIdx, NumFlags = 0;
        char ArenaString[64];

        char Flags[ADD_FLAGS][64];

        if ((HyphenIdx = FindCharInString(arg, '-')) > -1)
        {
                strcopy(ArenaString, HyphenIdx, arg);

                int NextHyphen;

                for (int i = 0; i < ADD_FLAGS; i++)
                {
                        NumFlags++;
                        NextHyphen = SplitString(arg[HyphenIdx + 1], "-", Flags[i], sizeof(Flags[]));

                        if (NextHyphen == -1)
                        {
                                strcopy(Flags[i], sizeof(Flags[]), arg[HyphenIdx + 1]);
                                break;
                        }

                        TrimString(Flags[i]);
                        HyphenIdx = HyphenIdx + NextHyphen;
                }
        }
        else
        {
                strcopy(ArenaString, sizeof(ArenaString), arg);
        }

        int ArenaIdx = StringToInt(ArenaString);

        if (!(ArenaIdx > 0 && ArenaIdx <= NumArenas))
        {
                TrimString(ArenaString);
                ArenaIdx = StringToArenaIdx(ArenaString);
        }

        if (ArenaIdx)
        {
#if defined _DEBUG
                PrintToChat(client, "arena: %s, flags: %i", ArenaString, NumFlags);
                for (int i = 0; i < NumFlags; i++)
                {
                        PrintToChat(client, "flags %i: %s", i, Flags[i]);
                }
#endif
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

                if (NumFlags > 0 && _Arena.IsEmpty())
                {
                        for (int i = 0; i < NumFlags; i++)
                        {
                                if (strcmp(Flags[i], "noelo") == 0)
                                {
                                        _Arena.EloEnabled = false;
                                }
                                else if (strcmp(Flags[i], "2v2") == 0)
                                {
                                        _Arena.FourPlayer = true;
                                }
                                else if (StrContains(Flags[i], "fraglimit", false) > -1)
                                {
                                        _Arena.FragLimit = StringToInt(Flags[i][10]); // "fraglimit " == 10
                                }
                        }
                }

                RemovePlayerFromArena(client, false);
                AddPlayerToArena(client, ArenaIdx);
        }
        else
        {
                ReplyToCommand(client, "Usage: %s", ADD_USAGE);
        }

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
        MC_PrintToChat(client, "{green}MGEME {olive}Version %s\n{default}%s", PL_VER, PL_DESC);
        MC_PrintToChat(client, "{green}Author: {olive}bzdmn");
        MC_PrintToChat(client, "{green}Website: {olive}%s", PL_URL);
        MC_PrintToChat(client, "{green}Commands: {olive}!add !remove !rank");
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
                ForcePlayerSuicide(client);
                CreateTimer(0.8, Timer_UpdateHUDAfterRespawn, client);
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

Action Admin_Command_Refresh(int client, int args)
{
        Player _Player = view_as<Player>(client);

        _Player.RefreshAmmo();
        _Player.RefreshHP(1.5);

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
                        MC_PrintToChat(arena.REDPlayer1, "{green}[MGE] {default}You gained {olive}%i {default}Elo", EloDiff);
                }
                
                if (Red2.IsValid) 
                {
                        Red2.Wins = Red2.Wins + 1;
                        Red2.Elo = Red2.Elo + EloDiff;
                        MC_PrintToChat(arena.REDPlayer2, "{green}[MGE] {default}You gained {olive}%i {default}Elo", EloDiff);
                }

                if (Blu1.IsValid) 
                {
                        Blu1.Losses = Blu1.Losses + 1;
                        Blu1.Elo = Blu1.Elo - EloDiff;
                        MC_PrintToChat(arena.BLUPlayer1, "{green}[MGE] {default}You lost {olive}%i {default}Elo", EloDiff);
                }

                if (Blu2.IsValid) 
                {
                        Blu2.Losses = Blu2.Losses + 1;
                        Blu2.Elo = Blu2.Elo - EloDiff;
                        MC_PrintToChat(arena.BLUPlayer2, "{green}[MGE] {default}You lost {olive}%i {default}Elo", EloDiff);
                }
        }
        else
        {
                if (Red1.IsValid) 
                {
                        Red1.Losses = Red1.Losses + 1;
                        Red1.Elo = Red1.Elo - EloDiff;
                        MC_PrintToChat(arena.REDPlayer1, "{green}[MGE] {default}You lost {olive}%i {default}Elo", EloDiff);
                }
                
                if (Red2.IsValid) 
                {
                        Red2.Losses = Red2.Losses + 1;
                        Red2.Elo = Red2.Elo - EloDiff;
                        MC_PrintToChat(arena.REDPlayer2, "{green}[MGE] {default}You lost {olive}%i {default}Elo", EloDiff);
                }

                if (Blu1.IsValid) 
                {
                        Blu1.Wins = Blu1.Wins + 1;
                        Blu1.Elo = Blu1.Elo + EloDiff;
                        MC_PrintToChat(arena.BLUPlayer1, "{green}[MGE] {default}You gained {olive}%i {default}Elo", EloDiff);
                }

                if (Blu2.IsValid) 
                {
                        Blu2.Wins = Blu2.Wins + 1;
                        Blu2.Elo = Blu2.Elo + EloDiff;
                        MC_PrintToChat(arena.BLUPlayer2, "{green}[MGE] {default}You gained {olive}%i {default}Elo", EloDiff);
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
                Serial = arena.PlayerQueue.NextValue();
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
                        char loser[32], winner[32], name[64];
                        GetClientName(arena.Opponent(client), winner, sizeof(winner));
                        GetClientName(client, loser, sizeof(loser));
                        arena.GetName(name, sizeof(name));

                        MC_PrintToChatAll("{lightgreen}%s {default}(Score:%i) defeats {lightgreen}%s \ 
                                          {default}(Score:%i) on {green}%s",
                                          winner, arena.WinnerScore, loser, arena.LoserScore, name);
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
        if (!client) 
        {
                return;
        }

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
#if defined _DEBUG
                        PrintToChat(client, "set hud %s", hud);
#endif
                }
                else
                {
                        arena.GetHUD(hud, sizeof(hud));
#if defined _DEBUG
                        PrintToChat(client, "got hud %s", hud);
#endif
                }

                if (updateScores) 
                {
                        int offset = arena.RedScoreOffset > arena.BluScoreOffset ?
                                     arena.RedScoreOffset : arena.BluScoreOffset ;
                
                        Format(scores, sizeof(scores), "\n %i\n %i", arena.BLUScore, arena.REDScore);
                        SetHudTextParams(float(offset) * 0.0093, 0.01, 120.0, 255, 255, 255, 125);
                }

                ShowSyncHudText(client, HUDScore, "%s", scores);
                //ShowHudText(client, 1, "%s", scores);
        }
        else
        {
                DrawHUD(arena, hud, sizeof(hud));
        }

        if (updateEverything)
        {
                SetHudTextParams(0.01, 0.01, 120.0, 255, 255, 255, 125);
                ShowSyncHudText(client, HUDArena, "%s", hud);
                //ShowHudText(client, 2, "%s", hud);
        }

        SetHudTextParams(0.65, 0.95, 120.0, 60, 238, 255, 255);
        ShowSyncHudText(client, HUDBanner, "mge.me");
        //ShowHudText(client, 3, "mge.me");
}

void UpdateSpectatorHUDs(Arena arena)
{
        LinkedList Node = arena.SpectatorList.Clone;

        while (Node.HasNext)
        {
                LinkedList Next = Node.Next;
                delete Node;
                Node = Next;

                int Serial = Node.Value;
                int Spectator = GetClientFromSerial(Serial);
                                
                if (!Spectator || !IsClientObserver(Spectator))
                {
                        arena.SpectatorList.Delete(Serial);
                }
                else
                {
                        UpdateHUD(arena, Spectator, true);
                }
        }

        delete Node;
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
                UpdateHUD(arena, arena.REDPlayer1, true, false);
        }
        
        if (Red2.IsValid)
        {
                UpdateHUD(arena, arena.REDPlayer2, true, false);
        }
        
        if (Blu1.IsValid)
        {
                UpdateHUD(arena, arena.BLUPlayer1, true, false);
        }

        if (Blu2.IsValid)
        {
                UpdateHUD(arena, arena.BLUPlayer2, true, false);
        }

        if (arena.NumSpectators > 0)
        {
                UpdateSpectatorHUDs(arena);
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

/*
void UpdateHUDNextFrame(int client)
{
        Player _Player = view_as<Player>(client);
        UpdateHUD(view_as<Arena>(_Player.ArenaIdx), client);
}
*/

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

public Action Timer_UpdateHUDAfterRespawn(Handle timer, int serial)
{
        int client = GetClientFromSerial(serial);

        if (client)
        {
                UpdateHUD(view_as<Arena>(view_as<Player>(client).ArenaIdx), client);
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
                MC_PrintToChat(client, "{olive}Type {green}%s {olive}to join", ADD_USAGE);
                CreateTimer(6.0, Timer_WelcomeMsg2, serial);
        }

        return Plugin_Stop;
}

public Action Timer_WelcomeMsg2(Handle timer, int serial)
{
        int client = GetClientFromSerial(serial);

        if (client)
        {
                MC_PrintToChat(client, "{olive}MGEME %s | {green}!mgeme {olive}for help", PL_VER);
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
                        MC_PrintToChat(client, "{green}[MGE] {default}Attacker had {lightgreen}%i {default}health left", HP);
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
/*
                if (Opp1.IsValid) UpdateHUD(_Arena, _Arena.Opponent1(client), false, true);
                if (Opp2.IsValid) UpdateHUD(_Arena, _Arena.Opponent2(client), false, true);
                if (Ally.IsValid) UpdateHUD(_Arena, _Arena.Ally(client), false, true);
*/
                if (Opp1.IsValid) UpdateHUD(_Arena, _Arena.Opponent1(client));
                if (Opp2.IsValid) UpdateHUD(_Arena, _Arena.Opponent2(client));
                if (Ally.IsValid) UpdateHUD(_Arena, _Arena.Ally(client));

                if (_Arena.REDScore >= _Arena.FragLimit || _Arena.BLUScore >= _Arena.FragLimit)
                {
                        MatchOver(_Arena, client);
                }
        }

        CreateTimer(_Arena.RespawnTime, Timer_Respawn, GetClientSerial(client));

        ClearHUD(client);
        
        return Plugin_Continue;
}

public Action Event_PlayerSpawn_Post(Event ev, const char[] name, bool dontBroadcast)
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

        int Slot0 = GetPlayerWeaponSlot(client, 0);
        int Slot1 = GetPlayerWeaponSlot(client, 1);

        _Player.ClipPrimary = Slot0 > -1 ? GetEntProp(Slot0, Prop_Data, "m_iClip1") : 0;
        _Player.ClipSecondary = Slot1 > -1 ? GetEntProp(Slot1, Prop_Data, "m_iClip1") : 0;
        
        CreateTimer(0.5, Timer_UpdateHUDAfterRespawn, client);
        //UpdateHUDNextFrame(client);
        //UpdateHUD(_Arena, client);

        return Plugin_Continue;
}

public Action Event_PlayerTeam(Event ev, const char[] name, bool dontBroadcast)
{
        ev.BroadcastDisabled = true;
        return Plugin_Continue;
}

public Action Event_PlayerTeam_Post(Event ev, const char[] name, bool dontBroadcast)
{
        int client = GetClientOfUserId(ev.GetInt("userid"));
#if defined _DEBUG
        PrintToChat(client, "Event_PlayerTeam");
#endif
        TFTeam NewTeam = view_as<TFTeam>(ev.GetInt("team"));

        Player _Player = view_as<Player>(client);
        Arena _Arena = view_as<Arena>(_Player.ArenaIdx);
        
        char arena[32], playerName[32];
        GetClientName(client, playerName, sizeof(playerName));
        _Arena.GetName(arena, sizeof(arena));

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

                MC_PrintToChatAll("{lightgreen}%s {default}joined arena {green}%s", playerName, arena);
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

                MC_PrintToChatAll("{lightgreen}%s {default}joined arena {green}%s", playerName, arena);
        }

        //UpdateHUD(_Arena, client, true, false);
        CreateTimer(0.5, Timer_UpdateHUDAfterRespawn, client);
       
        return Plugin_Continue;
}

public Action Event_PlayerClass_Post(Event ev, const char[] name, bool dontBroadcast)
{
        int client = GetClientOfUserId(ev.GetInt("userid"));
#if defined _DEBUG
        PrintToChat(client, "Event_PlayerClass_Post");
#endif
        //Player _Player = view_as<Player>(client);
        //Arena _Arena = view_as<Arena>(_Player.ArenaIdx);
 
        //UpdateHUD(_Arena, client);
        //CreateTimer(0.3, Timer_UpdateHUDAfterRespawn, client);

        return Plugin_Continue;
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

/*
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

// This hook is called every time just before a player is about to change an item
// in their loadout. Get the new clip size in the next frame when EntIndex != -1.
MRESReturn DHook_WeaponChange(Address pThis, Handle hReturn, Handle hParams)
{
        int client = view_as<int>(pThis);

        Player _Player = view_as<Player>(client);
        int Primary = GetPlayerWeaponSlot(client, 0);
        int Secondary = GetPlayerWeaponSlot(client, 1);

        if (Primary > -1)
        {
                _Player.ClipPrimary = GetEntProp(Primary, Prop_Data, "m_iClip1");
        }

        if (Secondary > -1)
        {
                _Player.ClipSecondary = GetEntProp(Secondary, Prop_Data, "m_iClip1");
        }

        int WeaponEnt = DHookGetReturn(hReturn); // :CBaseEntity
        int WeaponSlot = GetPlayerWeaponSlot(client, 0);
        int WeaponSlot2 = GetPlayerWeaponSlot(client, 1);
                        _Player.ClipPrimary = GetEntProp(WeaponEnt, Prop_Data, "m_iClip1");
 
        if (WeaponSlot != -1 && WeaponSlot2 != -1)
        {
                return MRES_Ignored;
        }
        
        WeaponSlot = WeaponSlot == -1 ? 0 : 1;

        Player _Player = view_as<Player>(client);

        if (HasEntProp(WeaponEnt, Prop_Data, "m_iClip1") && 
            HasEntProp(WeaponEnt, Prop_Data, "m_iPrimaryAmmoType") 
        )
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
*/
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
        LinkedList test = new LinkedList();
        PrintToServer("\nRunning LinkedList tests");
        AssertEq("Value is LLRoot", test.Value, LLRoot);
        AssertEq("HasNext is false", test.HasNext, false);
        AssertEq("Test size is 1", test.Size(), 1);
        test.Append(123);
        AssertEq("Test size is 2", test.Size(), 2);
        AssertEq("Value is LLRoot", test.Value, LLRoot);
        AssertEq("HasNext is true", test.HasNext, true);
        LinkedList next = test.Next;
        AssertEq("Next value is 123", next.Value, 123);
        AssertEq("Next HasNext is false", next.HasNext, false);
        AssertEq("test has value 123", test.HasValue(123), true);
        delete next;
        LinkedList next2 = test.Next;
        AssertEq("Next2 value is 123", next2.Value, 123);
        next2.Append(555);
        AssertEq("Test size is 3", test.Size(), 3);
        AssertEq("Next2 size is 2", next2.Size(), 2);
        LinkedList next3 = test.Next;
        LinkedList next4 = next3.Next;
        AssertEq("next4 value is 555", next4.Value, 555);
        test.Append(44);
        test.Append(93463);
        AssertEq("Test size is 5", test.Size(), 5);
        test.Delete(555);
        AssertEq("Test size is 4", test.Size(), 4);
        AssertEq("next4 size is 3", next4.Size(), 3);
        AssertEq("next4 value is 555", next4.Value, 555);
        AssertEq("test has value 44", test.HasValue(44), true);
        AssertEq("test doesn't have 555", test.HasValue(555), false);
        AssertEq("test can delete 123", test.Delete(123), true);
        AssertEq("Test size is 3", test.Size(), 3);
        AssertEq("can't delete 999", test.Delete(999), false);
        AssertEq("Test size is 3", test.Size(), 3);
        AssertEq("Can't delete LLRoot", test.Delete(LLRoot), false);
        delete next2;
        delete next3;
        delete next4;
        AssertEq("Test size is 3", test.Size(), 3);
        test.DeleteAll();
        AssertEq("Test size is 1", test.Size(), 1);
        PrintToServer("Test run complete\n");
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
