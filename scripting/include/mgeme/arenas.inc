/**
 * =============================================================================
 * MGEME Arenas
 * A rewrite of MGEMOD for MGE.ME server. Arena information and definitions.
 *
 * (C) 2024 MGE.ME.  All rights reserved
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

#if defined _mgeme_arenas_included
        #endinput
#endif
#define _mgeme_arenas_included

#include <tf2>
#include <tf2_stocks>

#define MAX_ARENAS 65
#define MAX_SPAWNS 15

#define ARENA_NAME_LEN 64
#define ARENA_HUD_SIZE 255

int NumArenas;

enum struct Vec
{
        float x;
        float y;
        float z;
}

enum ClassType
{
        Class_Unknown  = 0,
        Class_Scout    = 1 << 0,
        Class_Soldier  = 1 << 1,
        Class_DemoMan  = 1 << 2,
        Class_Sniper   = 1 << 3,
        Class_Engineer = 1 << 4,
        Class_Heavy    = 1 << 5,
        Class_Spy      = 1 << 6,
        Class_Pyro     = 1 << 7,
        Class_Medic    = 1 << 8
};

enum
{       
        EmptyNode = -1,
        RootNode  = 0
};

methodmap LinkedList < Handle 
{
        public LinkedList() 
        {
                StringMap Node = CreateTrie();
                
                /**
                * A unique identifier for the client over the entire server uptime.
                */
                Node.SetValue("ClientSerial", RootNode, true);
        
                /**
                * Handle to the next node in the linked list.
                */
                //Node.SetValue("Next", EndNode, true);
                
                return view_as<LinkedList>(Node);
        }

        property int ClientSerial
        {
                public get() 
                { 
                        StringMap Current = view_as<StringMap>(this);
                        int Serial;

                        if (Current.GetValue("ClientSerial", Serial)) return Serial;
                        else return 0;
                }
        }

        property int Size
        {
                public get()
                {
                        StringMap Current = view_as<StringMap>(this);
                        int _Size = 0;

                        // Don't count the root node
                        while (Current.GetValue("Next", Current)) 
                        { 
                                _Size++; 
                        }

                        return _Size;
                }
        }

        public LinkedList Append(int serial) 
        {
                StringMap Current = view_as<StringMap>(this);
                StringMap Next;
                int ClientSerial;

                while (Current.GetValue("Next", Next)) 
                { 
                        if (ClientSerial == serial)
                        {
                                return view_as<LinkedList>(Current);
                        }

                        Current = Next; 
                }

                Current.GetValue("ClientSerial", ClientSerial);
                if (ClientSerial == serial)
                {
                        return view_as<LinkedList>(Current);
                }

                StringMap NewNode = CreateTrie();
                NewNode.SetValue("ClientSerial", serial, true);

                Current.SetValue("Next", NewNode, true);

                return view_as<LinkedList>(NewNode);
        }

        public bool Delete(int serial)
        {
                StringMap Current = view_as<StringMap>(this);
                StringMap Previous, Next;

                int ClientSerial;

                do
                {
                        Current.GetValue("ClientSerial", ClientSerial);

                        if (ClientSerial == serial)
                        {
                                if (Current.GetValue("Next", Next))
                                {
                                        Previous.SetValue("Next", Next, true);
                                }
                                else
                                {
                                        Previous.Remove("Next");
                                }

                                delete Current;
                                return true;
                        }

                        Previous = Current;
                }
                while (Current.GetValue("Next", Current))

                return false;
        }

        public void DeleteAll()
        {
                int ClientSerial = this.Head();

                while (ClientSerial != 0)
                {       
                        this.Delete(ClientSerial);
                        ClientSerial = this.Head();
                }
        }

        public bool Exists(int serial) 
        {
                StringMap Current = view_as<StringMap>(this);
                StringMap Next;

                int ClientSerial;
                bool cont;

                do
                { 
                        cont = Current.GetValue("Next", Next);
                        Current.GetValue("ClientSerial", ClientSerial);

                        if (ClientSerial == serial) 
                        {
                                return true;
                        }
                        else Current = Next; 
                } 
                while (cont);

                return false;
        }

        public int Head()
        {
                StringMap Current = view_as<StringMap>(this);
                StringMap Next;

                int ClientSerial;
                Current.GetValue("ClientSerial", ClientSerial);

                if (ClientSerial == RootNode && Current.GetValue("Next", Next))
                {
                        Next.GetValue("ClientSerial", ClientSerial);
                }

                return ClientSerial;
        }

        public LinkedList HeadNode()
        {
                StringMap Current = view_as<StringMap>(this);
                StringMap Next;

                if (Current.GetValue("Next", Next))
                {
                        return view_as<LinkedList>(Next);
                }

                return view_as<LinkedList>(EmptyNode);
        }

        public bool HasNext()
        {
                StringMap Current = view_as<StringMap>(this);
                StringMap Next;

                if (Current.GetValue("Next", Next))
                {
                        return true;
                }
                
                return false;
        }
}

enum ArenaState
{
        Arena_Empty = 0,
        Arena_PlayerChange,
        Arena_Ready,
        Arena_Started,
        Arena_Ended
};

enum struct ArenaInfo
{
        /**
         * Dynamic arena values.
         */

        // Player client index and team score.
        int REDPlayer[2];
        int BLUPlayer[2];

        int REDScore;
        int BLUScore;

        int REDElo;
        int BLUElo;

        bool EloEnabled;

        // Store the HUD to avoid redrawing.
        char HUD[ARENA_HUD_SIZE];

        // Character offsets for updating scores.
        int BluScoreOffset;
        int RedScoreOffset;

        // Player who might get replaced by someone
        // from the PlayerQueue on the next round.
        int ClientReplaced;

        LinkedList PlayerQueue;
        LinkedList SpectatorList;

        ArenaState State;

        int LastSpawnId;

        /**
         * Static arena specifications.
         */

        char Name[ARENA_NAME_LEN];

        int AllowedClasses;
        
        int FragLimit;
        int FragLimitDefault;
        int CDTime;
        int EarlyLeave;
        int RoundTimer;
        int NumSpawns;

        bool AmmoMod;
        bool MidAir;
        bool MGE;
        bool BBall;
        bool Endif;
        bool KOTH;
        bool Turris;
        bool FourPlayer;
        bool FourPlayerDefault;

        bool ShowHP;
        bool InfiniteAmmo;
        bool VISHoop;

        float MinDist;
        float HPRatio;
        float RespawnTime;

        float SpawnX[MAX_SPAWNS + 1]; // Indexing starts at 1.
        float SpawnY[MAX_SPAWNS + 1];
        float SpawnZ[MAX_SPAWNS + 1];
        float Angle1[MAX_SPAWNS + 1];
        float Angle2[MAX_SPAWNS + 1];
        float Angle3[MAX_SPAWNS + 1];
}

static ArenaInfo Arenas[MAX_ARENAS + 1]; // Indexing starts at 1.

// Interface for ArenaInfo structs.
methodmap Arena < Handle 
{
        // Register a new arena.
        //
        // @param idx           A running index for the arena.
        // @param name          Arena name.
        // @return              The index cast as an Arena object.
        //
        // @error               Arena with this index is already initialized.
        //
        public Arena(int index)
        {
                Arenas[index].State = Arena_Empty;
                Arenas[index].PlayerQueue = new LinkedList();
                Arenas[index].SpectatorList = new LinkedList();

                Arenas[index].BLUPlayer[0] = 0;
                Arenas[index].REDPlayer[1] = 0;
                Arenas[index].BLUPlayer[0] = 0;
                Arenas[index].REDPlayer[1] = 0;

                Arenas[index].FourPlayerDefault = Arenas[index].FourPlayer;
                Arenas[index].FragLimitDefault = Arenas[index].FragLimit;

                return view_as<Arena>(index);
        }

        //
        // Player and team accessors.
        //

        property int BLUPlayer1
        {
                public get()
                {
                        return Arenas[view_as<int>(this)].BLUPlayer[0];
                }

                public set(int client)
                {
                        Arenas[view_as<int>(this)].BLUPlayer[0] = client;
                }
        }

        property int BLUPlayer2
        {
                public get()
                {
                        return Arenas[view_as<int>(this)].BLUPlayer[1];
                }

                public set(int client)
                {
                        Arenas[view_as<int>(this)].BLUPlayer[1] = client;
                }
        }

        property int REDPlayer1
        {
                public get()
                {
                        return Arenas[view_as<int>(this)].REDPlayer[0];
                }
                
                public set(int client)
                {
                        Arenas[view_as<int>(this)].REDPlayer[0] = client;
                }
        }

        property int REDPlayer2
        {
                public get()
                {
                        return Arenas[view_as<int>(this)].REDPlayer[1];
                }

                public set(int client)
                {
                        Arenas[view_as<int>(this)].REDPlayer[1] = client;
                }
        }

        property int ClientReplaced
        {
                public get()
                {
                        return Arenas[view_as<int>(this)].ClientReplaced;
                }

                public set(int replaced)
                {
                        Arenas[view_as<int>(this)].ClientReplaced = replaced;
                }
        }

        public int Opponent1(int client)
        {
                if (client == this.BLUPlayer1 || client == this.BLUPlayer2)
                {
                        return this.REDPlayer1;
                }

                return this.BLUPlayer1;
        }

        public int Opponent2(int client)
        {
                if (client == this.BLUPlayer1 || client == this.BLUPlayer2)
                {
                        return this.REDPlayer2;
                }

                return this.BLUPlayer2;
        }

        public int Ally(int client)
        {
                if (this.OpponentTeam(client) == TFTeam_Red)
                {
                        if (this.BLUPlayer1 == client) return this.BLUPlayer2;
                        else return this.BLUPlayer1;
                }
                else
                {
                        if (this.REDPlayer1 == client) return this.REDPlayer2;
                        else return this.REDPlayer1;
                }
        }

        public void GetOtherPlayers(int player, int &opp1, int &opp2, int &ally)
        {
                Player Opp1 = view_as<Player>(this.Opponent1(player));
                Player Opp2 = view_as<Player>(this.Opponent2(player));
                Player Ally = view_as<Player>(this.Ally(player));

                opp1 = (Opp1.IsValid) ? this.Opponent1(player) : 0;
                opp2 = (Opp2.IsValid) ? this.Opponent2(player) : 0;
                ally = (Ally.IsValid) ? this.Ally(player) : 0;
        }

        public TFTeam OpponentTeam(int client)
        {
                if (client == this.BLUPlayer1 || client == this.BLUPlayer2)
                {
                        return TFTeam_Red;
                }

                return TFTeam_Blue;
        }

        property LinkedList PlayerQueue
        {
                public get()
                {
                        return Arenas[view_as<int>(this)].PlayerQueue;
                }
        }

        property LinkedList SpectatorList
        {
                public get()
                {
                        return Arenas[view_as<int>(this)].SpectatorList;
                }
        }

        //
        // Boolean flags.
        //

        property bool IsValid
        {
                public get()
                {
                        return view_as<int>(this) > 0 ? true : false;
                }
        }

        property bool FourPlayer
        {
                public get()
                {
                        return Arenas[view_as<int>(this)].FourPlayer;
                }

                public set(bool fourplayer)
                {
                        Arenas[view_as<int>(this)].FourPlayer = fourplayer;
                }
        }

        property bool FourPlayerDefault
        {
                public get()
                {
                        return Arenas[view_as<int>(this)].FourPlayerDefault;
                }
        }

        property bool BBall
        {
                public get()
                {
                        return Arenas[view_as<int>(this)].BBall;
                }
        }

        property bool Endif
        {
                public get()
                {
                        return Arenas[view_as<int>(this)].Endif;
                }
        }

        property bool KOTH
        {
                public get()
                {
                        return Arenas[view_as<int>(this)].KOTH;
                }
        }

        property bool Turris
        {
                public get()
                {
                        return Arenas[view_as<int>(this)].Turris;
                }
        }

        property bool EloEnabled
        {
                public get()
                {
                        return Arenas[view_as<int>(this)].EloEnabled;
                }

                public set(bool enabled)
                {
                        Arenas[view_as<int>(this)].EloEnabled = enabled;
                }

        }

        public bool IsPlaying(int client)
        {
                return client != 0 && (
                       client == this.BLUPlayer1 ||
                       client == this.REDPlayer1 ||
                       client == this.BLUPlayer2 ||
                       client == this.REDPlayer2 );
        }

        public bool IsEmpty()
        {
                return this.BLUPlayer1 == 0 &&
                       this.BLUPlayer2 == 0 &&
                       this.REDPlayer1 == 0 &&
                       this.REDPlayer2 == 0 ;
        }

        public bool IsClassAllowed(TFClassType class)
        {
                switch (class)
                {
                        case TFClass_Scout:    { return this.AllowedClasses & view_as<int>(Class_Scout)    != 0; }
                        case TFClass_Soldier:  { return this.AllowedClasses & view_as<int>(Class_Soldier)  != 0; }
                        case TFClass_DemoMan:  { return this.AllowedClasses & view_as<int>(Class_DemoMan)  != 0; }
                        case TFClass_Sniper:   { return this.AllowedClasses & view_as<int>(Class_Sniper)   != 0; }
                        case TFClass_Spy:      { return this.AllowedClasses & view_as<int>(Class_Spy)      != 0; }
                        case TFClass_Engineer: { return this.AllowedClasses & view_as<int>(Class_Engineer) != 0; }
                        case TFClass_Pyro:     { return this.AllowedClasses & view_as<int>(Class_Pyro)     != 0; }
                        case TFClass_Heavy:    { return this.AllowedClasses & view_as<int>(Class_Heavy)    != 0; }
                        case TFClass_Medic:    { return this.AllowedClasses & view_as<int>(Class_Medic)    != 0; }
                        case TFClass_Unknown:  { return false; }
                }

                return false;
        }

        public bool MatchOngoing()
        {
                return this.State == Arena_Started;
        }

        property int AllowedClasses
        {
                public get()
                {
                        return Arenas[view_as<int>(this)].AllowedClasses; 
                }
        }

        //
        // Integer variables.
        //

        property int BLUScore
        {
                public get()
                {
                        return Arenas[view_as<int>(this)].BLUScore;
                }

                public set(int newScore)
                {
                        Arenas[view_as<int>(this)].BLUScore = newScore;
                }
        }

        property int REDScore
        {
                public get()
                {
                        return Arenas[view_as<int>(this)].REDScore;
                }

                public set(int newScore)
                {
                        Arenas[view_as<int>(this)].REDScore = newScore;
                }
        }

        public int ClientScore(int client)
        {
                if (this.OpponentTeam(client) == TFTeam_Red)
                {
                        return this.BLUScore;
                }
                else
                {
                        return this.REDScore;
                }
        }

        public int OpponentScore(int client)
        {
                if (this.OpponentTeam(client) == TFTeam_Red)
                {
                        return this.REDScore;
                }
                else
                {
                        return this.BLUScore;
                }
        }

        property int REDElo
        {
                public get()
                {
                        return Arenas[view_as<int>(this)].REDElo;
                }

                public set(int newElo)
                {
                        Arenas[view_as<int>(this)].REDElo = newElo;
                }
        }

        property int BLUElo
        {
                public get()
                {
                        return Arenas[view_as<int>(this)].BLUElo;
                }

                public set(int newElo)
                {
                        Arenas[view_as<int>(this)].BLUElo = newElo;
                }
        }

        property int NumSpawns
        {
                public get()
                {
                        return Arenas[view_as<int>(this)].NumSpawns;
                }
        }

        property int NumPlayers
        {
                public get()
                {
                        return (this.BLUPlayer1 > 0 ? 1 : 0) +
                               (this.REDPlayer1 > 0 ? 1 : 0) +
                               (this.BLUPlayer2 > 0 ? 1 : 0) +
                               (this.REDPlayer2 > 0 ? 1 : 0) ;
                }
        }

        property int NumQueued
        {
                public get()
                {
                        return this.PlayerQueue.Size;
                }
        }

        property int NumSpectators
        {
                public get()
                {
                        return this.SpectatorList.Size;
                }
        }

        property int EarlyLeave
        {
                public get()
                {
                        return Arenas[view_as<int>(this)].EarlyLeave;
                }
        }

        property int FragLimit
        {
                public get()
                {
                        return Arenas[view_as<int>(this)].FragLimit;
                }

                public set(int fraglimit)
                {
                        Arenas[view_as<int>(this)].FragLimit = fraglimit;
                }
        }

        property int FragLimitDefault
        {
                public get()
                {
                        return Arenas[view_as<int>(this)].FragLimitDefault;
                }
        }

        property int CDTime
        {
                public get()
                {
                        return Arenas[view_as<int>(this)].CDTime;
                }
        }

        //
        // Floating variables.
        //

        property float RespawnTime
        {
                public get()
                {
                        return Arenas[view_as<int>(this)].RespawnTime;
                }
        }

        property float HPRatio
        {
                public get()
                {
                        return Arenas[view_as<int>(this)].HPRatio;
                }
        }

        //
        // Arena HUD.
        //
        
        property int HUD
        {
                public get()
                {
                        return strlen(Arenas[view_as<int>(this)].HUD);
                }
        }

        property int BluScoreOffset
        {
                public get()
                {
                        return Arenas[view_as<int>(this)].BluScoreOffset;
                }

                public set(int offset)
                {
                        Arenas[view_as<int>(this)].BluScoreOffset = offset;
                }
        }

        property int RedScoreOffset
        {
                public get()
                {
                        return Arenas[view_as<int>(this)].RedScoreOffset;
                }

                public set(int offset)
                {
                        Arenas[view_as<int>(this)].RedScoreOffset = offset;
                }
        }

        public void GetHUD(char[] buf, int ssize)
        {
                strcopy(buf, ssize, Arenas[view_as<int>(this)].HUD);
        }

        public void SetHUD(char[] buf)
        {
                strcopy(Arenas[view_as<int>(this)].HUD, ARENA_HUD_SIZE, buf);
        }

        public void GetName(char[] buf, int ssize)
        {
                strcopy(buf, ssize, Arenas[view_as<int>(this)].Name);
        }

        //
        // State and spawn operations.
        //

        property ArenaState State
        {
                public get()
                {
                        return Arenas[view_as<int>(this)].State;
                }

                public set(ArenaState _state)
                {
                        Arenas[view_as<int>(this)].State = _state;
                }
        }

        property int LastSpawnId
        {
                public get()
                {
                        return Arenas[view_as<int>(this)].LastSpawnId;
                }

                public set(int spawnId)
                {
                        Arenas[view_as<int>(this)].LastSpawnId = spawnId;
                }
        }

        public void GetSpawn(int spawnId, float coords[3], float angles[3])
        {
                if (spawnId > 0 && spawnId <= this.NumSpawns)
                {
                        int idx = view_as<int>(this);

                        coords[0] = Arenas[idx].SpawnX[spawnId];
                        coords[1] = Arenas[idx].SpawnY[spawnId];
                        coords[2] = Arenas[idx].SpawnZ[spawnId];
                        angles[0] = Arenas[idx].Angle1[spawnId];
                        angles[1] = Arenas[idx].Angle2[spawnId];
                        angles[2] = Arenas[idx].Angle3[spawnId];
                }
                else
                {
                        this.GetRandomSpawn(coords, angles);
                }
        }
        
        public int GetRandomSpawn(float coords[3], float angles[3])
        {
                SetRandomSeed(GetURandomInt());
                int SpawnId = GetRandomInt(1, this.NumSpawns);
                int idx = view_as<int>(this);

                if (SpawnId == this.LastSpawnId)
                {
                        SpawnId = ++SpawnId > this.NumSpawns ? 1 : SpawnId;
                }
                
                this.LastSpawnId = SpawnId;

                coords[0] = Arenas[idx].SpawnX[SpawnId];
                coords[1] = Arenas[idx].SpawnY[SpawnId];
                coords[2] = Arenas[idx].SpawnZ[SpawnId];
                angles[0] = Arenas[idx].Angle1[SpawnId];
                angles[1] = Arenas[idx].Angle2[SpawnId];
                angles[2] = Arenas[idx].Angle3[SpawnId];

                return SpawnId;
        }

        public int GetRandomSpawnWithout(int spawnId, float coords[3], float angles[3])
        {
                int SpawnId;

                do
                {
                        SpawnId = this.GetRandomSpawn(coords, angles);
                }
                while (SpawnId == spawnId);

                return SpawnId;
        }

        // Get a far away spawn point from the opponent.
        //
        // @param coords        The XYZ spawn coordinates.
        // @param angles        The facing angle.
        // @param opp           Opponent coordinates.
        //
        public void GetFarSpawn(float coords[3], float angles[3], const float opp[3])
        {
                // Start by getting a random spawn point.
                int SpawnId = this.GetRandomSpawn(coords, angles);

                float Distance = FloatAbs(coords[0]-opp[0]) + FloatAbs(coords[1]-opp[1]) + FloatAbs(coords[2]-opp[2]);
                if (Distance < 600.0) // Adjust this to stop players spawning next to opponents.
                {
                        // Attempt one more time.
                        this.GetRandomSpawnWithout(SpawnId, coords, angles);
                }

                /* 
                float MaxDist = 0.0;
                int SpawnId, MaxDistSpawnId = 1;

                while (SpawnId <= this.NumSpawns)
                {
                        Distance = FloatAbs(xyz[0]-opp[0]) + FloatAbs(xyz[1]-opp[1]) + FloatAbs(xyz[2]-opp[2]);
                        PrintToChatAll("dist: %0.1f", Distance);
                        
                        if (Distance > MaxDist)
                        {
                                MaxDist = Distance;
                                MaxDistSpawnId = SpawnId;
                        }

                        this.GetSpawn(++SpawnId, xyz, ang);
                }
                
                this.GetSpawn(MaxDistSpawnId, coords, angles);
                */
        }

        public void Add(int client)
        {
                TFTeam Team;
                bool IsPlaying = false;

                if (this.BLUPlayer1 == 0)
                {
                        this.BLUPlayer1 = client;
                        Team = TFTeam_Blue;
                        IsPlaying = true;
                }
                else if (this.REDPlayer1 == 0)
                {
                        this.REDPlayer1 = client;
                        Team = TFTeam_Red;
                        IsPlaying = true;
                }
                else if (this.FourPlayer)
                {
                        if (this.BLUPlayer2 == 0)
                        {
                                this.BLUPlayer2 = client;
                                Team = TFTeam_Blue;
                                IsPlaying = true;
                        }
                        else if (this.REDPlayer2 == 0)
                        {
                                this.REDPlayer2 = client;
                                Team = TFTeam_Red;
                                IsPlaying = true;
                        }
                        else
                        {
                                this.PlayerQueue.Append(GetClientSerial(client));
                                PrintToChat(client, "[MGEME] Added to 2v2 queue for arena %i", view_as<int>(this));
                                //Team = TFTeam_Spectator;
                        }
                }
                else
                {
                        this.PlayerQueue.Append(GetClientSerial(client));
                        PrintToChat(client, "[MGEME] Added to 1v1 queue for arena %i", view_as<int>(this));
                        //Team = TFTeam_Spectator;
                }

                TFClassType PlayerClass = TF2_GetPlayerClass(client);

                if (!this.IsClassAllowed(PlayerClass))
                {
                        // class = GetAllowedClass(this)...
                        TF2_SetPlayerClass(client, TFClass_Scout, _, true);
                }

                if (IsPlaying)
                {
                        TF2_ChangeClientTeam(client, Team);
                        this.State = UpdateState(this, Arena_PlayerChange);
                }
#if defined _DEBUG
                PrintToChat(client, "Added to arena %i", view_as<int>(this));
#endif
        }

        public void Remove(int client)
        {
                if (client == this.BLUPlayer1)
                {
                        this.BLUPlayer1 = 0;
                        this.State = UpdateState(this, Arena_PlayerChange);
                }
                else if (client == this.REDPlayer1)
                {
                        this.REDPlayer1 = 0;
                        this.State = UpdateState(this, Arena_PlayerChange);
                }
                else if (this.FourPlayer)
                {
                        if (client == this.BLUPlayer2)
                        {
                                this.BLUPlayer2 = 0;
                                this.State = UpdateState(this, Arena_PlayerChange);
                        }
                        else if (client == this.REDPlayer2)
                        {
                                this.REDPlayer2 = 0;
                                this.State = UpdateState(this, Arena_PlayerChange);
                        }
                }
                else
                {
                        this.PlayerQueue.Delete(GetClientSerial(client));
                        PrintToChat(client, "Removed from player queue.");
                }

                TF2_ChangeClientTeam(client, TFTeam_Spectator);
#if defined _DEBUG
                PrintToChat(client, "Removed from arena %i", view_as<int>(this));
#endif
        }

        public void AddSpectator(int client)
        {
#if defined _DEBUG
                PrintToChat(client, "Added to spectator list %i", view_as<int>(this));
#endif
                this.SpectatorList.Append(GetClientSerial(client));
        }

        public void RemoveSpectator(int client)
        {
#if defined _DEBUG
                PrintToChat(client, "Removed from spectator list %i", view_as<int>(this));
#endif
                this.SpectatorList.Delete(GetClientSerial(client));
        }
}

Arena ArenaList[MAX_ARENAS + 1]; // Indexing starts at 1.

/**
 * Load arena information for the specified map.
 *
 * @param file          Configuration file to parse.
 * @param mapname       Name of the current map.
 * @return              True if arena information was loaded, false otherwise.
 */
stock bool LoadMapConfig(const char[] file, const char[] mapname)
{
        char ConfigPath[255];
        BuildPath(Path_SM, ConfigPath, sizeof(ConfigPath), file);

        KeyValues kv = new KeyValues("SpawnConfigs");

        if (!kv.ImportFromFile(ConfigPath))
        {
                LogError("Missing SpawnConfigs file");
                delete kv;
                return false;
        }

        if (!kv.JumpToKey(mapname))
        {
                LogError("Wrong map name or name missing from config");
                delete kv;
                return false;
        }
        else 
        {
                kv.GotoFirstSubKey();

                int ArenaIndex = 1;

                do {
                        Arena parsed = ParseArena(kv, ArenaIndex);
                        if (parsed.IsValid) 
                        {
                                ArenaList[ArenaIndex] = parsed;
                                ArenaIndex++;
                        }
                } 
                while (kv.GotoNextKey())

                NumArenas = ArenaIndex;
        }

        delete kv;
        return true;
}

/** 
 * Parse a single arena entry from SpawnConfigs.
 *
 * @param kv            KeyValue that is set at the position of the next arena.
 * @param arenaIdx      A unique identifier for the arena.
 * @return              An Arena object handle to be stored.
 */
static Arena ParseArena(KeyValues kv, int arenaIdx)
{
        kv.GetSectionName(Arenas[arenaIdx].Name, ARENA_NAME_LEN);

        //Arena NewArena = new Arena(arenaIdx, buf);
        //if (!NewArena.IsValid) return NewArena;

        //PrintToServer("Loaded arena %i: %s", arenaIdx, buf);

        //
        // Parse spawn points
        //

        int KvId, SpawnId = 1;
        char IntStr[4], buf[255];
        IntToString(SpawnId, IntStr, sizeof(IntStr));

        while (kv.GetNameSymbol(IntStr, KvId))
        {
                kv.GetString(IntStr, buf, sizeof(buf));
                //PrintToServer("Got spawn %i: %s ", SpawnId, buf);

                char FloatStrings[6][32];
                int NumFloatStrings = ExplodeString(buf, " ", FloatStrings, 6, 32);
                //PrintToServer("NStrings: %i", NumFloatStrings);

                if (NumFloatStrings == 4)
                {
                        Format(FloatStrings[4], sizeof(FloatStrings[]), "%s", FloatStrings[3]);        
                        Format(FloatStrings[3], sizeof(FloatStrings[]), "0.0");        
                }

                Arenas[arenaIdx].SpawnX[SpawnId] = StringToFloat(FloatStrings[0]);
                Arenas[arenaIdx].SpawnY[SpawnId] = StringToFloat(FloatStrings[1]);
                Arenas[arenaIdx].SpawnZ[SpawnId] = StringToFloat(FloatStrings[2]);
                Arenas[arenaIdx].Angle1[SpawnId] = StringToFloat(FloatStrings[3]);
                Arenas[arenaIdx].Angle2[SpawnId] = StringToFloat(FloatStrings[4]);
                Arenas[arenaIdx].Angle3[SpawnId] = StringToFloat(FloatStrings[5]);

                SpawnId++;

                IntToString(SpawnId, IntStr, sizeof(IntStr));
        }

        Arenas[arenaIdx].NumSpawns = SpawnId - 1;

        //
        // Parse classes
        //

        char Classes[256];
        kv.GetString("classes", Classes, sizeof(Classes));
        
        Arenas[arenaIdx].AllowedClasses = ClassesToBinary(Classes);

        //
        // Parse bools
        //

        Arenas[arenaIdx].MGE = kv.GetNum("mge", 0) ? true : false;
        Arenas[arenaIdx].AmmoMod = kv.GetNum("ammomod", 0) ? true : false;
        Arenas[arenaIdx].MidAir = kv.GetNum("midair", 0) ? true : false;
        Arenas[arenaIdx].BBall = kv.GetNum("bball", 0) ? true : false;
        Arenas[arenaIdx].Endif = kv.GetNum("endif", 0) ? true : false;
        Arenas[arenaIdx].KOTH = kv.GetNum("koth", 0) ? true : false;
        Arenas[arenaIdx].Turris = kv.GetNum("turris", 0) ? true : false;
        Arenas[arenaIdx].FourPlayer = kv.GetNum("4player", 0) ? true : false;

        Arenas[arenaIdx].ShowHP = kv.GetNum("showhp", 1) ? true : false;
        Arenas[arenaIdx].InfiniteAmmo = kv.GetNum("infammo", 1) ? true : false;
        Arenas[arenaIdx].VISHoop = kv.GetNum("vishoop", 0) ? true : false;

        //
        // Parse ints
        //

        Arenas[arenaIdx].FragLimit = kv.GetNum("fraglimit", 20);
        Arenas[arenaIdx].CDTime = kv.GetNum("cdtime", 3);
        Arenas[arenaIdx].EarlyLeave = kv.GetNum("earlyleave", 0);
        Arenas[arenaIdx].RoundTimer = kv.GetNum("timer", 180);

        //
        // Parse floats
        //

        Arenas[arenaIdx].MinDist = kv.GetFloat("mindist", 100.0);
        Arenas[arenaIdx].HPRatio = kv.GetFloat("hpratio", 1.5);
        Arenas[arenaIdx].RespawnTime = kv.GetFloat("respawntime", 0.1);

        return new Arena(arenaIdx);
}

/** 
 * Parse allowed classes into a binary format.
 *
 * @param str           A string list of allowed classes.
 * @return              A binary representation of allowed classes.
 */
static int ClassesToBinary(const char[] str)
{
        char classes[9][16], delim[2];
        int i, NumOfClasses, ClassPrefs = 0;

        for (i = 0; IsCharAlpha(str[i]); i++) {}

        if (!str[i])
        {
                strcopy(classes[0], sizeof(classes[]), str);
                NumOfClasses = 1;
        }
        else
        {
                Format(delim, sizeof(delim), "%c", str[i]);
                NumOfClasses = ExplodeString(str, delim, classes, 9, 16);
        }

        for (i = 0; i < NumOfClasses; i++)
        {
                if (StrContains(classes[i], "sc", false) > -1)
                {
                        ClassPrefs |= view_as<int>(Class_Scout);
                }
                else if (StrContains(classes[i], "so", false) > -1)
                {
                        ClassPrefs |= view_as<int>(Class_Soldier);
                }
                else if (StrContains(classes[i], "de", false) > -1)
                {
                        ClassPrefs |= view_as<int>(Class_DemoMan);
                }
                else if (StrContains(classes[i], "me", false) > -1)
                {
                        ClassPrefs |= view_as<int>(Class_Medic);
                }
                else if (StrContains(classes[i], "sn", false) > -1)
                {
                        ClassPrefs |= view_as<int>(Class_Sniper);
                }
                else if (StrContains(classes[i], "eng", false) > -1)
                {
                        ClassPrefs |= view_as<int>(Class_Engineer);
                }
                else if (StrContains(classes[i], "pyro", false) > -1)
                {
                        ClassPrefs |= view_as<int>(Class_Pyro);
                }
                else if (StrContains(classes[i], "he", false) > -1)
                {
                        ClassPrefs |= view_as<int>(Class_Heavy);
                }
                else if (StrContains(classes[i], "sp", false) > -1)
                {
                        ClassPrefs |= view_as<int>(Class_Spy);
                }
        }

        return ClassPrefs;
}

/** 
 * Match arena name with its index.
 *
 * @param str           A string which should contain the arena name.
 * @return              An index to ArenaList.
 */
stock int StringToArenaIdx(const char[] str)
{
        for (int i = 1; i < NumArenas; i++)
        {
                char buf[64];
                ArenaList[i].GetName(buf, sizeof(buf));

                if (StrContains(buf, str, false) > -1)
                {
                        return i;
                }
        }

        return 0;
}

ArenaState UpdateState(Arena arena, ArenaState newState)
{
#if defined _DEBUG
        FrameIterator FrameIter = new FrameIterator();

        do
        {
                char name[64], file[64];
                FrameIter.GetFunctionName(name, sizeof(name));
                FrameIter.GetFilePath(file, sizeof(file));
                //PrintToChatAll("%s Line %i: %s", file, FrameIter.LineNumber, name);
        }
        while (FrameIter.Next());
#endif

        if (arena.State == Arena_Ended)
        {
                return Arena_Ended;
        }

        switch (newState)
        {
                case Arena_Empty:
                {
#if defined _DEBUG
                        PrintToChatAll("Arena_Empty");
#endif
                        arena.FragLimit = arena.FragLimitDefault;
                        arena.FourPlayer = arena.FourPlayerDefault;
                        arena.EloEnabled = true;

                        return Arena_Empty;
                }
                case Arena_PlayerChange:
                {
#if defined _DEBUG
                        PrintToChatAll("Arena_PlayerChange");
#endif
                        if ((arena.NumPlayers == 2 && !arena.FourPlayer) ||
                            (arena.NumPlayers == 4 && arena.FourPlayer))
                        {
                                return UpdateState(arena, Arena_Ready);
                        }
                        else if (arena.NumPlayers == 0)
                        {
                                return UpdateState(arena, Arena_Empty);
                        }

                        return Arena_PlayerChange;
                }
                case Arena_Ready:
                {
#if defined _DEBUG
                        PrintToChatAll("Arena_Ready");
#endif
                        arena.REDScore = 0;
                        arena.BLUScore = 0;
                        arena.SetHUD("");

                        Event ev = CreateEvent("teamplay_team_ready");
                        ev.SetInt("team", view_as<int>(arena));
                        ev.Fire();

                        return Arena_Ready;
                }
                case Arena_Started:
                {
#if defined _DEBUG
                        PrintToChatAll("Arena_Started");
#endif
                        arena.ClientReplaced = 0;

                        return Arena_Started;
                }
                case Arena_Ended:
                {
#if defined _DEBUG
                        PrintToChatAll("Arena_Ended");
#endif
                        Event ev = CreateEvent("teamplay_round_win");
                        ev.SetInt("full_round", view_as<int>(arena));
                        ev.Fire();
                        
                        CreateTimer(float(arena.CDTime), Timer_End_Cooldown, arena);
                        return Arena_Ended;
                }
        }

        return newState;
}

// Don't accept State changes during the CDTime period. This resets the state.
static Action Timer_End_Cooldown(Handle timer, Arena arena)
{
        arena.State = Arena_PlayerChange;
        arena.State = UpdateState(arena, Arena_PlayerChange);
        return Plugin_Stop;
}
