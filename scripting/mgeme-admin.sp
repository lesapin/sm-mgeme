#pragma semicolon 1

#include <sourcemod>
#include <sdktools>
#include <signals>
#include <morecolors>

#pragma newdecls required

#define PLUGIN_VERSION "1.6.8"

public Plugin myinfo = 
{
    name = "MGEME Admin",
    author = "bzdmn",
    description = "Server tools",
    version = PLUGIN_VERSION,
    url = "https://mge.me"
};

#define SHUTDOWNDELAY 60
#define MGE_MAP "mge_training_v8_beta4b"

public void OnPluginStart()
{
    // Handle SIGINT (Ctrl-C in terminal) gracefully.
    SetSignalCallback(INT, GracefulShutdown);
    
    // ... but leave a way to shutdown the server instantly. 
    SetSignalCallback(TERM, InstantShutdown);

    // Start and stop profiling.
    //SetSignalCallback(USR1, StartVProf);
    //SetSignalCallback(USR2, StopVProf);

    // Fix jittering issues on long-running maps by reloading the map.
    // SIGWINCH is ignored by default so we can repurpose it. 
    SetSignalCallback(WINCH, ReloadMap);
}

void SetSignalCallback(SIG signal, SignalCallbackType cb)
{
    int err = CreateHandler(signal, cb);
    if (err == view_as<int>(FuncCountError)) // Callback already exists probably because of a plugin reload. 
    {
        LogMessage("Resetting handler for signal %i", signal);

        // Remove the previous handler and try again
        RemoveHandler(signal);
        err = CreateHandler(signal, cb);
    }
    else if (err == view_as<int>(SAHandlerError))
    {
        // Signal handler was set, not neccessarily by this extension but by the process.
        // This error is like a confirmation that we really want to replace the handler.
        LogError("A handler set by another process was replaced");

        // Ignore the previous handler. Someone else should deal with it.
        RemoveHandler(signal);
        err = CreateHandler(signal, cb);
    }

    if (err != view_as<int>(NoError))
    {
        LogError("Critical error, code %i", err);
        SetFailState("ERR: %i. Failed to attach callback for signal %i", err, signal);
    }

    LogMessage("Hooked signal %i", signal);
}

/****** CALLBACK FUNCTIONS ******/

Action GracefulShutdown()
{
    LogMessage("Server shutting down in ~%i seconds", SHUTDOWNDELAY);

    if (!GetClientCount(true)) // zero clients in-game
    {
        //LogMessage("No clients in-game, shutting down instantly");
        ServerCommand("exit");
    }
    else
    {
        // sv_shutdown shuts down the server after sv_shutdown_timeout_minutes,
        // or after every player has left/gets kicked from the server.
        // Set it to a whole number that's greater than SHUTDOWNDELAY;
        ServerCommand("sv_shutdown");
    }

    ForceRoundTimer(SHUTDOWNDELAY);

    CreateTimer(SHUTDOWNDELAY + 1.0, GameEnd);
    CreateTimer(SHUTDOWNDELAY + 10.0, ShutdownServer);

    PrintToChatAll("[SERVER] Shutting down in %i seconds for maintenance", SHUTDOWNDELAY);

    return Plugin_Continue;
}

Action InstantShutdown()
{
    // https://github.com/ValveSoftware/Source-1-Games/issues/1726
    LogMessage("Server shutting down");
    ServerCommand("sv_shutdown");
    ////////////////////////////////// 

    for (int client = 1; client < MaxClients; client++)
    {
        if (IsClientConnected(client) || IsClientAuthorized(client))
        {
            // Send a user-friendly shutdown message
            KickClient(client, "Shutting down for maintenance");
        }
    }

    return Plugin_Continue;
}

Action ReloadMap()
{
    LogMessage("Reloading the map in %i seconds", SHUTDOWNDELAY);

    if (!GetClientCount(true)) // Zero players in server
    {
        //LogMessage("No clients in-game, reloading instantly");
        ForceChangeLevel(MGE_MAP, "Map reload for maintenance");

        return Plugin_Continue;
    }

    ForceRoundTimer(SHUTDOWNDELAY);

    CreateTimer(SHUTDOWNDELAY + 1.0, GameEnd);
    CreateTimer(SHUTDOWNDELAY + 10.0, ChangeLevel);

    PrintToChatAll("[SERVER] Reloading the map in %i seconds for maintenance", SHUTDOWNDELAY);

    return Plugin_Continue;
}

/****** HELPER FUNCTIONS ******/

void ForceRoundTimer(int seconds)
{
    char buf[4];
    if (GetCurrentMap(buf, sizeof(buf)) > 0) // a map is running
    {
        int TimerEnt = -1,
            TimerEntKothRed = -1,
            TimerEntKothBlu = -1;

        TimerEnt = FindEntityByClassname(TimerEnt, "team_round_timer");
        TimerEntKothRed = FindEntityByClassname(TimerEntKothRed, "zz_red_koth_timer");
        TimerEntKothBlu = FindEntityByClassname(TimerEntKothBlu, "zz_blue_koth_timer");

        if (TimerEnt >= 1) // Delete all previous round timers
        {
            RemoveEntity(TimerEnt);    
        }
        else if (TimerEntKothBlu >= 1 || TimerEntKothRed >= 1)
        {
            RemoveEntity(TimerEntKothBlu);
            RemoveEntity(TimerEntKothRed);
        }
    
        int NewTimer = CreateEntityByName("team_round_timer");
        if (!IsValidEntity(NewTimer)) // Try to create a new timer entity
        {
            // Doesn't really matter as it's only for user-friendliness
            LogError("Couldn't create team_round_timer entity");
        }
        else
        {
            DispatchSpawn(NewTimer);
    
            SetVariantInt(seconds);
            AcceptEntityInput(NewTimer, "SetTime");
            SetVariantInt(seconds);
            AcceptEntityInput(NewTimer, "SetMaxTime");
            SetVariantInt(0);
            AcceptEntityInput(NewTimer, "SetSetupTime");
            SetVariantInt(1);
            AcceptEntityInput(NewTimer, "ShowInHud");
            SetVariantInt(1);
            AcceptEntityInput(NewTimer, "AutoCountdown");
            AcceptEntityInput(NewTimer, "Enable");
        }
    }
}

Action GameEnd(Handle timer)
{
    int EndGameEnt = -1;
    EndGameEnt = FindEntityByClassname(EndGameEnt, "game_end");

    if (EndGameEnt < 1)
        EndGameEnt = CreateEntityByName("game_end");

    if (IsValidEntity(EndGameEnt))
    {
        AcceptEntityInput(EndGameEnt, "EndGame");
    }
    else // Just shutdown instantly
    {
        LogError("Couldn't create game_end entity. Shutting down");
        InstantShutdown();
    }

    return Plugin_Continue;
}

Action ShutdownServer(Handle timer)
{
    return InstantShutdown(); // compiler warnings
}

Action ChangeLevel(Handle timer)
{
    ForceChangeLevel(MGE_MAP, "Map reload for maintenance");
    return Plugin_Continue;
}
