/**
 * =============================================================================
 * MGEME
 * A rewrite of MGEMOD for MGE.ME server. Player information and definitions.
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

#include <clientprefs>
               
Handle SettingsCki,
       FourPlayerCki, 
       EloCki, 
       FragLimitCki;

Panel FragLimitPanel;

#define MAX_PLAYERS 24
#define SPAWN_SOUND "items/spawn_item.wav"

enum struct PlayerInfo
{
        int Elo;
        int Wins;
        int Losses;

        int ArenaIdx;

        int Primary;
        int Secondary;
        int TypePrimary;
        int TypeSecondary;

        int AmmoPrimary;
        int AmmoSecondary;
        int ClipPrimary;
        int ClipSecondary;

        int MaxHP;
}

static PlayerInfo Players[MAX_PLAYERS + 1]; // Indexing starts at 1.

// Interface for PlayerInfo structs
methodmap Player < Handle
{
        // Initialize a new player.
        //
        // @param client        Client number.
        // @param elo           Player Elo.
        // @param wins          Player wins.
        // @param losses        Player losses.
        // @return              The client number cast as a handle.
        //
        public Player(int client, int elo = 1600, int wins = 0, int losses = 0)
        {
                if (client > 0 && client <= MAX_PLAYERS)
                {
                        Players[client].Elo = elo;
                        Players[client].Wins = wins;
                        Players[client].Losses = losses;

                        Players[client].ArenaIdx = 0;

                        return view_as<Player>(client);
                }

                return view_as<Player>(0);
        }

        property bool IsValid
        {
                public get()
                {
                        return (view_as<int>(this) > 0 && view_as<int>(this) <= MAX_PLAYERS) ? true : false;
                }
        }

        property bool IsAlive
        {
                public get()
                {
                        return IsPlayerAlive(view_as<int>(this));
                }
        }

        property int Primary
        {
                public get()
                {
                        return Players[view_as<int>(this)].Primary;
                }

                public set(int entIndex)
                {
                        Players[view_as<int>(this)].Primary = entIndex;
                }
        }

        property int Secondary
        {
                public get()
                {
                        return Players[view_as<int>(this)].Secondary;
                }

                public set(int entIndex)
                {
                        Players[view_as<int>(this)].Secondary = entIndex;
                }
        }

        property int AmmoPrimary
        {
                public get()
                {
                        return Players[view_as<int>(this)].AmmoPrimary;
                }

                public set(int maxAmmo)
                {
                        Players[view_as<int>(this)].AmmoPrimary = maxAmmo;
                }
        }

        property int AmmoSecondary
        {
                public get()
                {
                        return Players[view_as<int>(this)].AmmoSecondary;
                }

                public set(int maxAmmo)
                {
                        Players[view_as<int>(this)].AmmoSecondary = maxAmmo;
                }
        }

        property int ClipPrimary
        {
                public get()
                {
                        return Players[view_as<int>(this)].ClipPrimary;
                }

                public set(int maxClip)
                {
                        Players[view_as<int>(this)].ClipPrimary = maxClip;
                }
        }

        property int ClipSecondary
        {
                public get()
                {
                        return Players[view_as<int>(this)].ClipSecondary;
                }

                public set(int maxClip)
                {
                        Players[view_as<int>(this)].ClipSecondary = maxClip;
                }
        }

        property int TypePrimary
        {
                public get()
                {
                        return Players[view_as<int>(this)].TypePrimary;
                }

                public set(int ammoType)
                {
                        Players[view_as<int>(this)].TypePrimary = ammoType;
                }
        }

        property int TypeSecondary
        {
                public get()
                {
                        return Players[view_as<int>(this)].TypeSecondary;
                }

                public set(int ammoType)
                {
                        Players[view_as<int>(this)].TypeSecondary = ammoType;
                }
        }

        property int MaxHP
        {
                public get()
                {
                        return Players[view_as<int>(this)].MaxHP;
                }

                public set(int hp)
                {
                        Players[view_as<int>(this)].MaxHP = hp;
                }
        }

        property int ArenaIdx
        {
                public get()
                {
                        return Players[view_as<int>(this)].ArenaIdx;
                }
                
                public set(int arenaIdx)
                {
                        Players[view_as<int>(this)].ArenaIdx = arenaIdx;
                }
        }

        property int Elo
        {
                public get()
                {
                        return Players[view_as<int>(this)].Elo;
                }
               
                public set(int elo)
                {
                        Players[view_as<int>(this)].Elo = elo;
                }
        }

        property int Wins
        {
                public get()
                {
                        return Players[view_as<int>(this)].Wins;
                }
                
                public set(int wins)
                {
                        Players[view_as<int>(this)].Wins = wins;
                }
        }

        property int Losses
        {
                public get()
                {
                        return Players[view_as<int>(this)].Losses;
                }
                
                public set(int losses)
                {
                        Players[view_as<int>(this)].Losses = losses;
                }
        }

        public bool GetCookies(bool &settings, bool &fourPlayer, bool &elo, int &fraglimit)
        {
                int client = view_as<int>(this);

                if (AreClientCookiesCached(client))
                {
                        char buf[16];

                        GetClientCookie(client, SettingsCki, buf, sizeof(buf));
                        settings = strcmp(buf, "on") == 0 ? true : false;

                        if (!settings)
                        {
                                return false;
                        }

                        GetClientCookie(client, FourPlayerCki, buf, sizeof(buf));
                        fourPlayer = strcmp(buf, "yes") == 0 ? true : false;

                        GetClientCookie(client, EloCki, buf, sizeof(buf));
                        elo = strcmp(buf, "yes") == 0 ? true : false;

                        GetClientCookie(client, FragLimitCki, buf, sizeof(buf));
                        fraglimit = StringToInt(buf);

                        return true;
                }

                return false;
        }

        public void GetCoords(float xyz[3])
        {
                GetClientAbsOrigin(view_as<int>(this), xyz);
        }

        // Scale player health by hpRatio after spawning
        // or after scoring a kill.
        //
        // @param hpRatio       Arena specific HP multiplier.
        //
        public void RefreshHP(float hpRatio = 1.5)
        {
                int client = view_as<int>(this);
                
                if (IsPlayerAlive(client))
                {
                        int MaxHP = GetEntProp(client, Prop_Data, "m_iMaxHealth");
                        //SetEntProp(client, Prop_Data, "m_iHealth", RoundFloat(MaxHP * hpRatio));
                        SetEntityHealth(client, RoundFloat(MaxHP * hpRatio));
                }
        }

        // Replenish player ammo after a kill.
        public void RefreshAmmo()
        {
                int client = view_as<int>(this);
                
                if (this.Primary > 0)
                {
                        if (this.ClipPrimary > 0)
                        {
                                SetEntProp(this.Primary, Prop_Data, "m_iClip1", this.ClipPrimary);
                        }
                
                        if (this.AmmoPrimary > 0)
                        {
                                SetEntProp(client, Prop_Send, "m_iAmmo", this.AmmoPrimary, _, this.TypePrimary);
                        }
                }

                if (this.Secondary > 0)
                {
                        if (this.ClipSecondary > 0)
                        {
                                SetEntProp(this.Secondary, Prop_Data, "m_iClip1", this.ClipSecondary);
                        }
                
                        if (this.AmmoSecondary > 0)
                        {
                                SetEntProp(client, Prop_Send, "m_iAmmo", this.AmmoSecondary,_, this.TypeSecondary);
                        }
                }
        }

        public void DisableAttacks(float disableTime)
        {
                int NextAttack = FindSendPropInfo("CBaseCombatWeapon", "m_flNextPrimaryAttack");
                float GameTime = GetGameTime();
                int WeaponEnt;

                for (int i = 0; i < 3; i++)
                {
                        WeaponEnt = GetPlayerWeaponSlot(view_as<int>(this), i);

                        if (WeaponEnt > 0)
                        {
                                SetEntDataFloat(WeaponEnt, NextAttack, GameTime + disableTime, true);
                        }
                }
        }

        public void Teleport(const float xyz[3], const float ang[3])
        {
                TeleportEntity(view_as<int>(this), xyz, ang);
                EmitAmbientSound(SPAWN_SOUND, xyz, _, SNDLEVEL_NORMAL, _, 1.0);
        }
}

Player PlayerList[MAX_PLAYERS + 1]; // Indexing starts at 1.
