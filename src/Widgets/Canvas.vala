/*
 * Copyright (c) 2011-2015 THOMAS-Projekt (https://thomas-projekt.de)
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

public class Simulator.Widgets.Canvas : Gtk.DrawingArea {
    public Backend.Room room { private get; construct; }
    public Backend.Robot robot { private get; construct; }

    private double room_width;
    private double room_height;

    double canvas_width;
    double canvas_height;

    private double field_width;
    private double field_height;

    public Canvas (Backend.Room room, Backend.Robot robot) {
        Object (room: room, robot: robot);

        room_width = room.get_width ();
        room_height = room.get_height ();

        request_size ();
        connect_signals ();
    }

    private void request_size () {
        this.set_size_request (room.get_width () * 60, room.get_height () * 60);
    }

    private void connect_signals () {
        this.size_allocate.connect (update_sizes);
        this.draw.connect (redraw);

        robot.changed.connect (this.queue_draw);
    }

    private void update_sizes (Gtk.Allocation allocation) {
        canvas_width = allocation.width;
        canvas_height = allocation.height;

        field_width = canvas_width / room_width;
        field_height = canvas_height / room_height;
    }

    private bool redraw (Cairo.Context context) {
        Gtk.StyleContext style_context = this.get_style_context ();
        Gdk.RGBA color = style_context.get_color (Gtk.StateFlags.NORMAL);

        Gdk.cairo_set_source_rgba (context, color);

        draw_room (context);
        draw_robot (context);

        return true;
    }

    private void draw_room (Cairo.Context context) {
        uint8[, ] wall_grid = room.get_wall_grid ();

        for (int y = 0; y < room_height; y++) {
            for (int x = 0; x < room_width; x++) {
                if (wall_grid[y, x] == 1) {
                    context.rectangle (Math.ceil (x * field_width),
                                       Math.ceil (y * field_height),
                                       Math.ceil (field_width),
                                       Math.ceil (field_height));
                    context.fill ();
                }
            }
        }
    }

    private void draw_robot (Cairo.Context context) {
        context.translate (robot.position_x * field_width, robot.position_y * field_height);
        context.rotate (robot.direction);

        context.arc (0, 0, field_width * 0.9, 0, 2 * Math.PI);
        context.move_to (-10, -10);
        context.line_to (0, 10);
        context.line_to (10, -10);
        context.stroke ();

        context.rotate (-robot.direction);

        context.move_to (field_width * 0.8, field_width * 0.8);
        context.show_text ("x=%f, y=%f, r=%f".printf (robot.position_x, robot.position_y, robot.direction));

        context.restore ();
    }
}