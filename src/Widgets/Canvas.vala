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

public class Simulator.Widgets.Canvas : Gtk.DrawingArea {
    private static const int PIXEL_PER_FIELD = 60;

    public Backend.Room room { private get; construct; }
    public Backend.Robot robot { private get; construct; }
    public Backend.MappingAlgorithm algorithm { private get; construct; }

    private double room_width;
    private double room_height;

    double canvas_width;
    double canvas_height;

    private double field_width;
    private double field_height;

    public Canvas (Backend.Room room, Backend.Robot robot, Backend.MappingAlgorithm algorithm) {
        Object (room: room, robot: robot, algorithm: algorithm);

        room_width = room.get_width ();
        room_height = room.get_height ();

        request_size ();
        connect_signals ();
    }

    private void request_size () {
        this.set_size_request (room.get_width () * PIXEL_PER_FIELD, room.get_height () * PIXEL_PER_FIELD);
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
        draw_last_scan (context);
        draw_last_detected_walls (context);
        draw_last_detected_marks (context);
        draw_last_orientation_marks (context);

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
        context.show_text ("x=%f, y=%f, r=%f".printf (robot.position_x, robot.position_y, robot.direction % (2 * Math.PI)));

        context.restore ();
    }

    private void draw_last_scan (Cairo.Context context) {
        if (robot.last_scan == null) {
            return;
        }

        context.translate (robot.position_x * field_width, robot.position_y * field_height);
        context.set_source_rgba (0, 0, 0, 0.3);

        robot.last_scan.@foreach ((entry) => {
            double angle = ((Math.PI / 180) * (entry.key - 90)) + robot.direction;
            double distance = entry.@value;

            double target_position_x = -Math.sin (angle) * distance * field_width;
            double target_position_y = Math.cos (angle) * distance * field_height;

            context.move_to (0, 0);
            context.line_to (target_position_x, target_position_y);
            context.stroke ();
            context.arc (target_position_x, target_position_y, 3, 0, 2 * Math.PI);
            context.fill ();

            return true;
        });

        context.restore ();
    }

    private void draw_last_detected_walls (Cairo.Context context) {
        if (algorithm.last_detected_walls == null) {
            return;
        }

        context.translate (robot.position_x * field_width, robot.position_y * field_height);
        context.rotate (robot.direction);
        context.set_source_rgba (1, 0, 0, 1);
        context.set_line_width (3);

        foreach (Backend.MappingAlgorithm.Wall wall in algorithm.last_detected_walls) {
            context.move_to (((double)wall.relative_start_x / 30) * field_width, ((double)wall.relative_start_y / 30) * field_width);
            context.line_to (((double)wall.relative_end_x / 30) * field_width, ((double)wall.relative_end_y / 30) * field_width);

            context.stroke ();
        }
    }

    private void draw_last_detected_marks (Cairo.Context context) {
        if (algorithm.last_detected_marks == null) {
            return;
        }

        foreach (Backend.MappingAlgorithm.Mark mark in algorithm.last_detected_marks) {
            double real_position_x = ((double)mark.position_x / 30) * field_width;
            double real_position_y = ((double)mark.position_y / 30) * field_width;

            context.set_line_width (1);
            context.set_source_rgba (0, 0, 1, 1);
            context.arc (real_position_x, real_position_y, 10, 0, 2 * Math.PI);
            context.stroke ();

            context.set_line_width (1);
            context.set_source_rgba (0, 1, 0, 1);
            context.move_to (real_position_x, real_position_y);
            context.line_to (real_position_x - Math.sin (mark.direction) * 20, real_position_y + Math.cos (mark.direction) * 20);
            context.stroke ();
        }
    }

    private void draw_last_orientation_marks (Cairo.Context context) {
        if (algorithm.compared_orientation_marks == null) {
            return;
        }

        for (int i = 0; i < 2; i++) {
            double real_position_x = ((double)algorithm.compared_orientation_marks[i].position_x / 30) * field_width;
            double real_position_y = ((double)algorithm.compared_orientation_marks[i].position_y / 30) * field_width;

            context.set_line_width (2);
            context.set_source_rgba (1, 0, 1, 1);
            context.arc (real_position_x, real_position_y, 10, 0, 2 * Math.PI);
            context.stroke ();

            context.set_line_width (2);
            context.set_source_rgba (1, 1, 0, 1);
            context.move_to (real_position_x, real_position_y);
            context.line_to (real_position_x - Math.sin (algorithm.compared_orientation_marks[i].direction) * 20, real_position_y + Math.cos (algorithm.compared_orientation_marks[i].direction) * 20);
            context.stroke ();
        }
    }
}