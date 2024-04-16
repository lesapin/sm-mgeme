/**
 * =============================================================================
 * MGEME
 * A rewrite of MGEMOD for MGE.ME server. A linked list implementation.
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

#if defined _mgeme_linkedlist_included
        #endinput
#endif
#define _mgeme_linkedlist_included

#include <adt_trie>

enum
{
        LLEmpty = -1,
        LLRoot = 0
};

methodmap LinkedList < StringMap
{
        public LinkedList()
        {
                StringMap root = new StringMap();
                root.SetValue("value", LLRoot);
                return view_as<LinkedList>(root);
        }

        property LinkedList Clone
        {
                public get()
                {
                        return view_as<LinkedList>(CloneHandle(this));
                }
        }

        property bool HasNext
        {
                public get()
                {
                        int next;
                        return this.GetValue("next", next);
                }
        }

        property int Value
        {
                public get()
                {
                        int value;
                        if (this.GetValue("value", value))
                        {       
                                return value;
                        }
                        
                        return view_as<int>(LLEmpty);
                }
        }

        property LinkedList Next
        {
                public get()
                {
                        int next;
                        this.GetValue("next", next);
                        return view_as<LinkedList>(next).Clone;
                }
        }

        public void Append(int val)
        {
                LinkedList node = this.Clone;

                while (node.HasNext)
                {
                        LinkedList next = node.Next;
                        delete node;
                        node = next;
                }

                StringMap next = new StringMap();
                next.SetValue("value", val);
                node.SetValue("next", next);
                delete node;
        }

        public bool Delete(int val)
        {
                LinkedList node = this.Clone;

                while (node.HasNext)
                {
                        LinkedList next = node.Next;
                        LinkedList prev = node.Clone;
                        delete node;
                        node = next;

                        if (node.Value == val)
                        {
                                int deleted, replaced;
                                prev.GetValue("next", deleted);

                                if (node.GetValue("next", replaced))
                                {
                                        prev.SetValue("next", replaced, true);
                                }

                                delete view_as<StringMap>(deleted);
                                delete node;
                                delete prev;
                                return true;
                        }
                               
                        delete prev;
                }

                delete node;
                return false;
        }

        public bool HasValue(int val)
        {
                LinkedList node = this.Clone;

                while (node.HasNext)
                {
                        LinkedList next = node.Next;
                        delete node;
                        node = next;

                        if (node.Value == val)
                        {
                                delete node;
                                return true;
                        }
                }

                delete node;
                return false;
        }

        public int Size()
        {
                LinkedList node = this.Clone;
                int size = 1;

                while (node.HasNext)
                {
                        LinkedList next = node.Next;
                        delete node;
                        node = next;
                        size++;
                }
        
                delete node;
                return size;
        }
}
