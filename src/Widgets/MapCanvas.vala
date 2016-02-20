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

public class Simulator.Widgets.MapCanvas : Gtk.DrawingArea {
    public Backend.MappingAlgorithm algorithm { private get; construct; }

    private Backend.MappingAlgorithm.Map? room_map = null;

    double canvas_width;
    double canvas_height;

    public MapCanvas (Backend.MappingAlgorithm algorithm) {
        Object (algorithm : algorithm);

        connect_signals ();
    }

    private void connect_signals () {
        this.size_allocate.connect (update_sizes);
        this.draw.connect (redraw);

        algorithm.map_changed.connect ((map) => {
            room_map = map;

            this.queue_draw ();
        });
    }

    private void update_sizes (Gtk.Allocation allocation) {
        canvas_width = allocation.width;
        canvas_height = allocation.height;
    }

    private bool redraw (Cairo.Context context) {
        Gtk.StyleContext style_context = this.get_style_context ();
        Gdk.RGBA wall_color = style_context.get_color (Gtk.StateFlags.NORMAL);
        Gdk.RGBA free_color = { wall_color.red + 0.5, wall_color.green + 0.5, wall_color.blue + 0.5, wall_color.alpha };

        if (room_map != null) {
            int count_x = room_map.max_x - room_map.min_x + 1;
            int count_y = room_map.max_y - room_map.min_y + 1;

            if (count_x <= 0 || count_y <= 0) {
                return true;
            }

            int center_x = room_map.min_x.abs ();
            int center_y = room_map.min_y.abs ();

            double field_width = canvas_width / count_x;
            double field_height = canvas_height / count_y;

            foreach (Backend.MappingAlgorithm.Map.Field field in room_map.map) {
                if (field.state == Backend.MappingAlgorithm.Map.FieldState.UNKNOWN) {
                    continue;
                }

                Gdk.cairo_set_source_rgba (context, (field.state == Backend.MappingAlgorithm.Map.FieldState.WALL ? wall_color : free_color));

                context.rectangle (Math.ceil ((center_x + field.x) * field_width),
                                   Math.ceil ((center_y + field.y) * field_height),
                                   Math.ceil (field_width),
                                   Math.ceil (field_height));
                context.fill ();
            }
        }

        return true;
    }
}