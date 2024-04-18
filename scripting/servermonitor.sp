/**
 * =============================================================================
 * MGEME
 * A rewrite of MGEMOD for MGE.ME server. Server monitoring tool.
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

#include <sourcemod>
#include <signals>
#include <mgeme/database>

#define PLUGIN_VERSION "2.1.1"

public Plugin myinfo = 
{
        name = "Server Monitor",
        author = "bzdmn",
        description = "Monitor server usage",
        version = PLUGIN_VERSION,
        url = "https://mge.me"
};

#define MAX_PLAYER_SLOTS 25

int JoinTime[MAX_PLAYER_SLOTS];

int ActiveTime,
    ActiveStart,
    MaxPlayers;

bool HasDB;

public void OnPluginStart()
{
        RegAdminCmd("serverstats", Admin_Command_ServerStats, 1, "Dump server stats and drop table.");
        
        CreateHandler(USR1, DumpStats);

        ActiveTime = 0;
        ActiveStart = 0;
        MaxPlayers = 0;
}

public void OnConfigsExecuted()
{
        if ((HasDB = DBConnect()))
        {
                DBInitServerStats();
        }
        else
        {
                SetFailState("Couldn't connect to database");
        }
        
        char FilePath[256];
        BuildPath(Path_SM, FilePath, sizeof(FilePath), "data/servermonitor.dat");

        File file;

        if (FileExists(FilePath))
        {
                file = OpenFile(FilePath, "r");
        }

        if (file)
        {
                int timestamp;
                char Date[32], FileDate[32];

                file.ReadInt32(timestamp);

                FormatTime(Date, sizeof(Date), "%D", GetTime());
                FormatTime(FileDate, sizeof(Date), "%D", timestamp);

                if (strcmp(Date, FileDate) == 0)
                {
                        file.ReadInt32(MaxPlayers);
                        file.ReadInt32(ActiveTime);
                }
        }
        
        delete file;
        DeleteFile(FilePath);
}

public void OnClientConnected(int client)
{
        if (ActiveStart == 0)
        {
                ActiveStart = GetTime();
        }

        if (GetClientCount(false) > MaxPlayers)
        {
                MaxPlayers = GetClientCount(false);
        }

        JoinTime[client] = GetTime();
}

public void OnClientDisconnect(int client)
{
        if (HasDB && IsClientAuthorized(client))
        {
                UpdatePlayer(client);
        }
}

public void OnClientDisconnect_Post(int client)
{
        if (GetClientCount() == 0)
        {
                ActiveTime += (GetTime() - ActiveStart);
                ActiveStart = 0;
        }

        JoinTime[client] = 0;
}

public void OnPluginEnd()
{
        if (HasDB)
        {
                for (int i = 1; i <= MaxClients; i++)
                {
                        if (IsClientConnected(i) && IsClientAuthorized(i))
                        {
                                UpdatePlayer(i);
                        }
                }
        }

        char FilePath[256];
        BuildPath(Path_SM, FilePath, sizeof(FilePath), "data/servermonitor.dat");
        File file = OpenFile(FilePath, "w");

        if (file)
        {
                file.WriteInt32(GetTime());
                file.WriteInt32(MaxPlayers);
                file.WriteInt32(ActiveTime);
        }
        
        delete file;
}

void UpdatePlayer(int client)
{
        char Query[256], SteamId[32];
        
        GetClientAuthId(client, AuthId_Steam2, SteamId, sizeof(SteamId));

        DataPack pack = new DataPack();
        pack.WriteString(SteamId);
        pack.WriteCell(GetTime() - JoinTime[client]);

        Format(Query, sizeof(Query), "SELECT playtime, playtime_total, connections \
                                      FROM mgeme_server \
                                      WHERE steamid='%s' LIMIT 1", SteamId);

        gDB.Query(SQLQueryUpdateServerStats, Query, pack);
}

void SQLQueryUpdateServerStats(Database db, DBResultSet result, const char[] error, any data)
{
        if (db == null || result == null || strlen(error) > 0)
        {
                LogError("SQLQueryUpdateServerStats error: %s", error);
                return;
        }

        char Query[256], SteamId[32], Date[32];

        DataPack pack = data;
        pack.Reset();
        
        pack.ReadString(SteamId, sizeof(SteamId));

        int playtime = pack.ReadCell();
        int playtime_total = playtime;
        int connections = 1;

        delete pack;

        FormatTime(Date, sizeof(Date), "%D", GetTime());

        if (result.FetchRow())
        {
                playtime += result.FetchInt(0);
                playtime_total += result.FetchInt(1);                
                connections += result.FetchInt(2);

                Format(Query, sizeof(Query), "UPDATE mgeme_server \
                                              SET date='%s', playtime=%i, playtime_total=%i, connections=%i \
                                              WHERE steamid='%s'",
                                              Date, playtime, playtime_total, connections, SteamId);

                gDB.Query(SQLQueryErrorCheck, Query);
        }
        else
        {
                Format(Query, sizeof(Query), "INSERT INTO mgeme_server VALUES('%s', '%s', %i, %i, %i)",
                                              SteamId, Date, playtime, playtime_total, connections);

                gDB.Query(SQLQueryErrorCheck, Query);
        }
}

Action Admin_Command_ServerStats(int client, int args)
{
        if (HasDB)
        {
                DumpStats();
        }

        return Plugin_Continue;
}

Action DumpStats()
{
        char FilePath[256], FileName[64], Date[32];

        int UniqueConnections, Playtime = 0, Connections = 0;

        FormatTime(Date, sizeof(Date), "%D", GetTime());
        FormatTime(FileName, sizeof(FileName), "L%G%m%d", GetTime());
        
        BuildPath(Path_SM, FilePath, sizeof(FilePath), "logs/%s.stats", FileName);

        if (HasDB)
        {
                for (int i = 1; i <= MaxClients; i++)
                {
                        if (IsClientConnected(i) && IsClientAuthorized(i))
                        {
                                UpdatePlayer(i);
                        }
                }
        }

        File file = OpenFile(FilePath, "a");

        if (file)
        {
                char Query[256];

                Format(Query, sizeof(Query), "SELECT playtime, connections FROM mgeme_server \
                                              WHERE date='%s'", Date);

                SQL_LockDatabase(gDB);

                DBResultSet Q = SQL_Query(gDB, Query);

                if (Q == null)
                {
                        char error[256];
                        SQL_GetError(Q, error, sizeof(error))
                        LogError("DumpStats error: %s", error);
                        
                        SQL_UnlockDatabase(gDB);
                        
                        return Plugin_Continue;
                }

                UniqueConnections = Q.RowCount;
                
                while (Q.FetchRow())
                {
                        Playtime += Q.FetchInt(0);
                        Connections += Q.FetchInt(1);
                }

                if (SQL_FastQuery(gDB, "DROP TABLE mgeme_server"))
                {
                        SQL_FastQuery(gDB, "CREATE TABLE mgeme_server (steamid TEXT, date TEXT, \
                                            playtime INTEGER, playtime_total INTEGER, connections INTEGER)");
                }

                SQL_UnlockDatabase(gDB);

                delete Q;

                if (ActiveStart > 0)
                {
                        ActiveTime += (GetTime() - ActiveStart);
                }

                file.WriteLine("MANHOURS %i", Playtime);
                file.WriteLine("ACTIVEHOURS %i", ActiveTime);
                file.WriteLine("MAXCLIENTS %i", MaxPlayers);
                file.WriteLine("UNIQUECLIENTS %i", UniqueConnections);
                file.WriteLine("CONNECTIONS %i", Connections);
        }

        delete file;

        ActiveTime = 0;
        MaxPlayers = GetClientCount();

        if (MaxPlayers > 0)
        {
                ActiveStart = GetTime();
        }
        else
        {
                ActiveStart = 0;
        }

        return Plugin_Continue;
}
