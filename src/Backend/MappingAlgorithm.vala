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
    /* Klasse mit einigen Hilfsfunktionen zur Darstellung einer Karte mit unbekannten Ausmaßen in alle vier Richtungen */
    private class Map {
        /* Eine Struktur, die die Koordinate eines Feldes enthält */
        private struct FieldCoordinate {
            int x;
            int y;
        }

        /* Die drei verschiedene Zustände eines Feldes der Karte */
        public enum FieldState {
            UNKNOWN,
            FREE,
            WALL
        }

        /*
         * Das Koordinatensystem
         * Die Verwendung einer TreeMap stellt hier einen Workaround für einen Fehler in mehrdimensionalen Arrays dar.
         * Siehe https://bugzilla.gnome.org/show_bug.cgi?id=735159
         */
        private Gee.TreeMap<FieldCoordinate? , FieldState> map;

        /* Erstellt eine neue Umgebungskarte */
        public Map () {
            /* Koordinatenliste erstellen */
            map = new Gee.TreeMap<FieldCoordinate? , FieldState> ();
        }

        /* Setzt den Zustand eines Feldes */
        public void set_field_state (int x, int y, FieldState state) {
            /* Zustand speichern */
            map.@set ({ x, y }, state);
        }

        /* Ruft den Zustand eines Feldes ab */
        public FieldState get_field_state (int x, int y) {
            /* Koordinatenstruktur erstellen */
            FieldCoordinate coordinate = { x, y };

            /* Falls nicht gesetzt ist das Feld "Unbekannt" */
            if (!map.has_key (coordinate)) {
                return FieldState.UNKNOWN;
            }

            /* Zustand zurückgeben */
            return map.@get (coordinate);
        }
    }

    /* Der maximale erlaubte Abstand zwischen den Auftrittspunkten der Messwerte, damit eine Wand erkannt wird */
    private static const int WALL_MAX_DISTANCE_GAP = 60;

    /* Die maximale erlaubte Richtungsdifferenz zwischen den Auftrittspunkten der Messwerte, damit eine Wand erkannt wird */
    private static const double WALL_MAX_DIRECTION_GAP = (Math.PI / 180) * 40;

    /* Mindestlänge der Summe der rechtsliegenden Wände zur Überprüfung der Aussagekräftigkeit */
    private static const int MIN_RIGHT_WALL_LENGTH_SUM = 20;

    /* Konvertiert Grad in Bogemmaß */
    private static double deg_to_rad (uint8 degree) {
        return ((Math.PI / 180) * degree);
    }

    /* Berechnet den Durschnittswert aus einem Array aus Fließkommazahlen */
    private static double double_avg (double[] values) {
        /* Teilung durch null verhindern */
        if (values.length == 0) {
            return 0;
        }

        /* Die Summe aller Fließkommazahlen */
        double sum = 0;

        /* Alle Zahlen aufaddieren */
        foreach (double @value in values) {
            sum += @value;
        }

        /* Durchschnittswert berechnen */
        return sum / values.length;
    }

    /* Sucht in den Messwerten nach regelmäßigkeiten und interpretiert diese als Wände */
    private static Wall[] detect_walls (Gee.TreeMap<double? , uint16> distances) {
        /* Liste der erkannten Wände */
        Wall[] walls = {};

        /* Der Winkel des Startpunktes der Wand */
        double wall_start_angle = -1;

        /* Die Koordinaten des Startpunktes der Wand */
        int wall_start_position_x = 0;
        int wall_start_position_y = 0;

        /* Der letzte überprüfte Winkel */
        double last_angle = -1;

        /* Der Distanzwert zum letzten überprüften Winkel */
        uint16 last_distance = 0;

        /* Die Koordinaten des letzten überprüften Messwertes */
        int last_position_x = 0;
        int last_position_y = 0;

        /* Liste der letzten Wandrichtungen */
        double[] last_directions = {};

        /* Alle Messwerte durchlaufen */
        distances.@foreach ((entry) => {
            /* Infos zum Messwert abrufen */
            double angle = entry.key;
            uint16 distance = entry.@value;

            /* Auftrittspunkt des Messwertes bestimmen */
            int position_x = (int)(-Math.sin (angle - (Math.PI / 2)) * distance);
            int position_y = (int)(Math.cos (angle - (Math.PI / 2)) * distance);

            /* Prüfen, ob dies der erste Messwert ist */
            if (last_angle >= 0) {
                /* Den Abstand zu den Koordinaten des letzten Auftrittspunktes berechnen */
                int distance_gap = (int)(Math.sqrt (Math.pow (position_x - last_position_x, 2) + Math.pow (position_y - last_position_y, 2)));

                /* Bewegt sich der Abstand innerhalb der Parameter? */
                if (distance_gap < WALL_MAX_DISTANCE_GAP) {
                    /* Wurde bereits eine Wand begonnen? */
                    if (wall_start_angle < 0) {
                        /* Startwinkel der neuen Wand merken */
                        wall_start_angle = last_angle;

                        /* Startkoordinaten der neuen Wand merken */
                        wall_start_position_x = last_position_x;
                        wall_start_position_y = last_position_y;
                    } else {
                        /* Wurde bereits ein paar vorherige Wandrichtungen erfasst? */
                        if (last_directions.length > 2) {
                            /* Wandrichtung bezogen auf den vorherigen Punkt bestimmen */
                            double direction = Math.atan ((double)(position_y - last_position_y) / (double)(position_x - last_position_x));

                            /* Durchschnittswert der vorherigen paar Wandrichtungen berechnen */
                            double avg_direction = double_avg (last_directions[(last_directions.length > 8 ? last_directions.length - 8 : 0) : last_directions.length - 2]);

                            /* Falls die vorherige Wandrichtung bekannt ist, Differenz überprüfen */
                            if (Math.fabs (direction - avg_direction) > WALL_MAX_DIRECTION_GAP) {
                                /* Neue Struktur, die die Wand beschreibt, anlegen */
                                Wall wall = { wall_start_angle,
                                              wall_start_position_x,
                                              wall_start_position_y,
                                              last_angle,
                                              last_position_x,
                                              last_position_y,
                                              last_distance };

                                /* Weitere Angaben errechnen */
                                wall.enhance_data ();

                                /* Wand zur Liste hinzufügen */
                                walls += wall;

                                /* Die Wand ist hier zu Ende */
                                wall_start_angle = -1;

                                /* Liste der Wandrichtungen zurücksetzen */
                                last_directions = {};
                            } else {
                                /* Richtung merken */
                                last_directions += direction;
                            }
                        } else {
                            /* Richtung bezogen auf den Startpunkt merken */
                            last_directions += Math.atan ((double)(position_y - wall_start_position_y) / (double)(position_x - wall_start_position_x));
                        }
                    }
                } else {
                    /* Wurde bereits eine Wand begonnen? */
                    if (wall_start_angle >= 0) {
                        /* Neue Struktur, die die Wand beschreibt, anlegen */
                        Wall wall = { wall_start_angle,
                                      wall_start_position_x,
                                      wall_start_position_y,
                                      last_angle,
                                      last_position_x,
                                      last_position_y,
                                      last_distance };

                        /* Weitere Angaben errechnen */
                        wall.enhance_data ();

                        /* Wand zur Liste hinzufügen */
                        walls += wall;
                    }

                    /* Dies ist kein Startpunkt einer neuen Wand*/
                    wall_start_angle = -1;
                }
            }

            /* Winkel merken */
            last_angle = angle;

            /* Distanz merken */
            last_distance = distance;

            /* Koordinaten merken */
            last_position_x = position_x;
            last_position_y = position_y;

            /* Messwerte weiter durchlaufen */
            return true;
        });

        /* Wurde die letzte Wand schon beendet? */
        if (wall_start_angle >= 0) {
            /* Neue Struktur, die die Wand beschreibt, anlegen */
            Wall wall = { wall_start_angle,
                          wall_start_position_x,
                          wall_start_position_y,
                          last_angle,
                          last_position_x,
                          last_position_y,
                          last_distance };

            /* Weitere Angaben errechnen */
            wall.enhance_data ();

            /* Wand zur Liste hinzufügen */
            walls += wall;
        }

        /* Liste der Wände zurückgeben */
        return walls;
    }

    /* Stellt aus den Wanddaten Merkmale heraus und gibt diese zurück */
    private static Mark[] detect_marks (Wall[] walls) {
        /* Liste der erkannten Merkmale */
        Mark[] marks = {};

        /* Merkt sich die vorherige Wand */
        Wall? last_wall = null;

        /* Alle Wände durchlaufen */
        for (int i = 0; i < walls.length; i++) {
            /* Wandinformationen abrufen */
            Wall wall = walls[i];

            /* Mit der zweiten Wand beginnen */
            if (last_wall != null) {
                /* Differenz der Wandrichtungen berechnen */
                double direction_difference = Math.fabs (last_wall.relative_direction - wall.relative_direction);

                /* Differenz prüfen */
                if (direction_difference > Math.PI / 3 && direction_difference < Math.PI / 3 * 2) {
                    /*
                     * Berechnung orientiert an https://en.wikipedia.org/wiki/Line%E2%80%93line_intersection
                     * Für bessere Lesbarkeit Werte zwischenspeichern
                     */
                    double x1 = last_wall.relative_start_x;
                    double x2 = last_wall.relative_end_x;
                    double x3 = wall.relative_start_x;
                    double x4 = wall.relative_end_x;
                    double y1 = last_wall.relative_start_y;
                    double y2 = last_wall.relative_end_y;
                    double y3 = wall.relative_start_y;
                    double y4 = wall.relative_end_y;

                    /* Zaehler */
                    double zx = (x1 * y2 - y1 * x2) * (x3 - x4) - (x1 - x2) * (x3 * y4 - y3 * x4);
                    double zy = (x1 * y2 - y1 * x2) * (y3 - y4) - (y1 - y2) * (x3 * y4 - y3 * x4);

                    /* Nenner */
                    double n = (x1 - x2) * (y3 - y4) - (y1 - y2) * (x3 - x4);

                    /* Prüfen, ob die Wände einen Schittpunkt haben */
                    if (n != 0) {
                        /* Koordinaten des Schnittpunktes abrufen */
                        double mark_position_x = zx / n;
                        double mark_position_y = zy / n;

                        /* Merkmal erstellen */
                        Mark mark = {
                            mark_position_x,
                            mark_position_y,
                            wall.relative_direction,
                            MarkType.CORNER
                        };

                        /* Merkmal zur Liste hinzufügen */
                        marks += mark;
                    }
                }
            }

            /* Wand als vorherige Wand merken */
            last_wall = wall;
        }

        /* Merkmale zurückgeben */
        return marks;
    }

    /* Stellt eine automatisch erkannte Wand dar */
    public struct Wall {
        /* Winkel des Startpunktes im Messbereich des Roboters */
        double start_angle;

        /* Relative Koordinaten des Startpunktes */
        int relative_start_x;
        int relative_start_y;

        /* Winkel des Endpunktes im Messbereich des Roboters */
        double end_angle;

        /* Relative Koordinaten des Enpunktes */
        int relative_end_x;
        int relative_end_y;

        /* Die Distanz der Wand zum Roboter */
        uint16 distance;

        /* Länge der wand */
        int wall_length;

        /* Relative Richtung der Wand (bezogen auf die Drehrichtung des Roboters) */
        double relative_direction;

        /* Berechnet die fehlenden Angaben anhand der gegebenen Werte */
        public void enhance_data () {
            /* Länge der Wand mit dem Satz des Pythagoras berechnen */
            wall_length = (int)(Math.sqrt (Math.pow (relative_end_x - relative_start_x, 2) + Math.pow (relative_end_y - relative_start_y, 2)));

            /* Teilen durch Null verhindern */
            if (relative_end_x == relative_start_x) {
                return;
            }

            /* Relative Richtung der Wand in Bezug zum Roboter berechnen */
            relative_direction = Math.atan ((double)(relative_end_y - relative_start_y) / (double)(relative_end_x - relative_start_x));
        }
    }

    /* Stellt ein Wiedererkennungsmerkmal dar */
    public struct Mark {
        /* Relative Koordinaten des Merkmales */
        double position_x;
        double position_y;

        /* Die Richtung */
        double direction;

        /* Die Art des Merkmals */
        MarkType type;
    }

    /* Die verschiedenen Arten von Merkmalen */
    public enum MarkType {
        CORNER
    }

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

    /* Die Umgebungskarte die erstellt wird */
    private Map map;

    /* Zuletzt erkannte Wandliste */
    public Wall[]? last_detected_walls { get; private set; default = null; }

    /* Zuletzt erkannte Merkmalsliste */
    public Mark[]? last_detected_marks { get; private set; default = null; }

    /* Speichert die Distanzwerte des momentanen Scanvorganges */
    private Gee.TreeMap<double? , uint16> current_scan;

    /* Der Konstruktor der Klasse, hier sollten die nötigen Funktionen zur Kontrolle des Roboters übergeben werden */
    public MappingAlgorithm (MoveFunc move_func, TurnFunc turn_func, StartNewScanFunc start_new_scan_func) {
        /* Funktionen global zuweisen */
        this.move = move_func;
        this.turn = turn_func;
        this.start_new_scan = start_new_scan_func;

        /* Karte erstellen */
        map = new Map ();

        /* Erste Messreihe beginnen */
        current_scan = new Gee.TreeMap<double? , uint16> ();

        /* Zunächst einmal die momentane Umgebung scannen */
        start_new_scan ();
    }

    /* Sollte aufgerufen werden, wenn eine weitere durchschnittliche Distanz einer Karte erfasst wurde */
    public void handle_map_scan_continued (int map_id, uint8 angle, uint16 avg_distance) {
        /* Wir setzen hier vorraus, dass immer nur eine Map gleichzeitig aufgenommen wird. */

        /*
         * Distanzwert zum Scan hinzufügen
         * Winkel werden im weiteren Verlauf als Bogenmaß verwendet, daher schon hier konvertieren
         */
        current_scan.@set (deg_to_rad (angle), avg_distance);
    }

    /* Sollte aufgerufen werden, wenn der Scanvorgang einer Karte abgeschlossen wurde */
    public void handle_map_scan_finished (int map_id) {
        /* Wände anhand der Messdaten detektieren */
        Wall[] walls = detect_walls (current_scan);

        /* Wände speichern, damit sie extern abgerufen werden können */
        last_detected_walls = walls;

        /* Die Wände auf Merkmale untersuchen */
        Mark[] marks = detect_marks (walls);

        /* Merkmale speichern, damit sie extern abgerufen werden können */
        last_detected_marks = marks;

        /* Neue Messreihe beginnen */
        current_scan = new Gee.TreeMap<double? , uint16> ();

        /* Neuen Scanvorgang einleiten */
        start_new_scan ();
    }
}