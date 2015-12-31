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

public class Simulator.MainWindow : Gtk.Window {
    private Backend.Room room;
    private Backend.Robot robot;

    private Gtk.HeaderBar header_bar;

    private Gtk.Box main_box;

    private Widgets.Canvas canvas;

    public MainWindow (Simulator.Application application) {
        this.set_application (application);

        room = new Backend.Room ();
        robot = new Backend.Robot ();

        build_ui ();
        connect_signals ();
    }

    private void build_ui () {
        header_bar = new Gtk.HeaderBar ();
        header_bar.show_close_button = true;
        header_bar.title = "THOMAS-Simulator";
        header_bar.get_style_context ().add_class ("compact");

        this.set_titlebar (header_bar);

        main_box = new Gtk.Box (Gtk.Orientation.VERTICAL, 0);

        canvas = new Widgets.Canvas (room, robot);

        main_box.pack_start (canvas);

        this.add (main_box);
    }

    private void connect_signals () {
    }
}