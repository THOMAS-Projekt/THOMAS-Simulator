/*
 * Copyright (c) 2011-2016 THOMAS-Projekt (https://thomas-projekt.de)
 *
 * This program is free software; you can redistribute it and/or
 * modify it under the terms of the GNU General Public
 * License as published by the Free Software Foundation; either
 * version 2 of the License, or (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
 * General Public License for more details.
 *
 * You should have received a copy of the GNU General Public
 * License along with this program; if not, write to the
 * Free Software Foundation, Inc., 59 Temple Place - Suite 330,
 * Boston, MA 02111-1307, USA.
 *
 * Authored by: Marcus Wichelmann <marcus.wichelmann@hotmail.de>
 */

/*
 * Stellt den Algorithmus zur Autonomen Kartierung der Umgebung dar.
 * Dieser Klasse müssen im Konstruktor einige Funktionen zur Kontrolle des Roboters übergeben werden,
 * die als Schnittstelle dienen. Ereignisse und Fortschritte werden der Klasse über die jeweiligen
 * "handle"-Funktionen mitgeteilt.
 *
 * Dieser Algorithmus wurde im Rahmen der Facharbeit von Marcus Wichelmann entwickelt und dokumentiert.
 */
public class Simulator.Backend.MappingAlgorithm : Object {
    /* Spiegelt die Funktionen zum Steuern des Roboters wieder */
    public delegate void MoveFunc (short speed, uint duration);
    public delegate void TurnFunc (short speed, uint duration);
    public delegate int StartNewScanFunc ();

    /* Zeigt auf eine Funktion zum Einleiten einer definierten Vorwärts- oder Rückwärtsbewegung */
    public unowned MoveFunc move { private get; private set; }

    /* Zeigt auf eine Funktion zum Auführen einer Drehung */
    public unowned TurnFunc turn { private get; private set; }

    /* Zeit auf eine Funktion zum Beginn eines neuen Scanvorganges */
    public unowned StartNewScanFunc start_new_scan { private get; private set; }

    /* Der Konstruktor der Klasse, hier sollten die nötigen Funktionen zur Kontrolle des Roboters übergeben werden */
    public MappingAlgorithm (MoveFunc move_func, TurnFunc turn_func, StartNewScanFunc start_new_scan_func) {
        /* Funktionen global zuweisen */
        this.move = move_func;
        this.turn = turn_func;
        this.start_new_scan = start_new_scan_func;
    }

    /* Sollte aufgerufen werden, wenn eine weitere durchschnittliche Distanz einer Karte erfasst wurde */
    public void handle_map_scan_continued (int map_id, uint8 angle, uint16 avg_distance) {
    }

    /* Sollte aufgerufen werden, wenn der Scanvorgang einer Karte abgeschlossen wurde */
    public void handle_map_scan_finished (int map_id) {
    }
}