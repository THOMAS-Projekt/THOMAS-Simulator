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

public class Simulator.Backend.Robot : Object {
    private static const short MAX_ACCELERATION = 15;
    private static const bool USE_INACCURACY = true;

    public Room room { private get; construct; }

    public double position_x { get; private set; default = 3; }
    public double position_y { get; private set; default = 3; }

    public double direction { get; private set; default = 0; }

    public short current_speed { get; private set; default = 0; }
    public short wanted_speed { get; private set; default = 0; }

    public double turning_speed { get; private set; default = 0; }

    public Gee.TreeMap<uint8, double? >? last_scan { get; private set; default = null; }

    private uint accelerate_timer_id = 0;

    private Timer last_recalculation_timer;

    public signal void changed ();

    public Robot (Room room) {
        Object (room : room);
        last_recalculation_timer = new Timer ();

        Timeout.add (40, () => {
            direction += turning_speed;

            double real_speed = ((double)current_speed / 256) * 0.05;
            position_x -= Math.sin (direction) * real_speed;
            position_y += Math.cos (direction) * real_speed;

            changed ();

            return true;
        });
    }

    public void set_motor_speed (short speed) {
        short new_speed = (speed > 255 ? 255 : speed < -255 ? -255 : speed);

        /* Künstliche Ungenauigkeit */
        if (USE_INACCURACY && new_speed.abs () > 50) {
            new_speed += (short)Random.int_range (-30, 10);
        }

        current_speed = wanted_speed = new_speed;
    }

    public void set_motor_turning_speed (short speed) {
        short new_speed = (speed > 255 ? 255 : speed < -255 ? -255 : speed);

        /* Künstliche Ungenauigkeit */
        if (USE_INACCURACY && new_speed.abs () > 50) {
            new_speed += (short)Random.int_range (-30, 10);
        }

        turning_speed = ((double)new_speed / 256) / 16;
    }

    public void accelerate_to_motor_speed (short speed) {
        if (accelerate_timer_id != 0) {
            Source.remove (accelerate_timer_id);
        }

        short new_speed = (speed > 255 ? 255 : speed < -255 ? -255 : speed);

        /* Künstliche Ungenauigkeit */
        if (USE_INACCURACY && new_speed.abs () > 50) {
            new_speed += (short)Random.int_range (-30, 10);
        }

        wanted_speed = new_speed;

        recalculate_motor_speed ();

        accelerate_timer_id = Timeout.add (100, recalculate_motor_speed);
    }

    public Gee.TreeMap<uint8, double? > do_scan () {
        Gee.TreeMap<uint8, double? > distances = new Gee.TreeMap<uint8, double? > ();

        for (uint8 angle = 0; angle < 180; angle += 2) {
            double distance = room.get_distance (position_x, position_y, ((Math.PI / 180) * (angle - 90)) + direction);

            /* Künstliche Ungenauigkeit */
            if (USE_INACCURACY) {
                distance += Random.double_range (-distance / 30, distance / 20);
            }

            if (distance < 0) {
                distance = 0;
            }

            distances.@set (angle, distance);
        }

        last_scan = distances;

        return distances;
    }

    private bool recalculate_motor_speed () {
        if (last_recalculation_timer.elapsed () < 0.09) {
            return true;
        }

        last_recalculation_timer.start ();

        short pending_difference = (wanted_speed - current_speed).abs ();

        if (pending_difference > 0) {
            short acceleration_sign = (wanted_speed > current_speed ? 1 : -1);

            current_speed += (pending_difference > MAX_ACCELERATION ? MAX_ACCELERATION : pending_difference) * acceleration_sign;

            return true;
        }

        accelerate_timer_id = 0;

        return false;
    }
}