public class Kairos.WeatherGraph : He.Bin {
    private int[] data = { };
    private int margin = 18;

    public WeatherGraph (GLib.SList<GWeather.Info> info) {
        for (var i = 0; i <= 12; i++) {
            var inf = info.nth (i).data;
            if (info.index (inf) >= 0)
                data += int.parse (inf.get_temp ());
        }
    }

    construct{
        var draw_area = new Gtk.DrawingArea();
        draw_area.set_draw_func (on_draw);
        draw_area.vexpand = true;
        draw_area.set_size_request (504, 200);

        child = draw_area;
    }

    private void on_draw (Gtk.DrawingArea draw_area,
                         Cairo.Context cr,
                         int height,
                         int width) {
        cr.set_source_rgba (0, 0, 0, 0);
        cr.paint ();
        cr.set_source_rgba (1, 1, 1, 0.88);

        int graph_height = height - margin * 1;

        var x_scale = (double) 42.75; // For some reason this fills up the graph perfectly
        var y_scale = (double) graph_height / (40.0 - (-40.0));

        cr.move_to (0, height);

        for (int i = 0; i < data.length; i++)
            cr.line_to (i * x_scale, height - (data[i] - (-40)) * y_scale);

        cr.line_to (data.length * x_scale, height);
        cr.close_path ();

        var gradient = new Cairo.Pattern.linear (0,
                                                0,
                                                0,
                                                height);
        gradient.add_color_stop_rgba (0,
                                     1,
                                     1,
                                     1,
                                     0.5); // More opaque at top
        gradient.add_color_stop_rgba (1,
                                     1,
                                     1,
                                     1,
                                     0.0); // Fully transparent at bottom

        cr.set_source (gradient);
        cr.fill_preserve ();
        cr.stroke ();

        cr.set_source_rgba (1, 1, 1, 0.88);
        cr.move_to (0, height);
        for (int i = 0; i < data.length; i++)
            cr.line_to (i * x_scale, height - (data[i] - (-40)) * y_scale);

        cr.select_font_face("Manrope", Cairo.FontSlant.NORMAL, Cairo.FontWeight.BOLD);
        cr.set_font_size (14);
        cr.set_source_rgba (1, 1, 1, 0.88);

        int max_index = get_max_index(data);
        int min_index = get_min_index(data);

        string max_text = """%s""".printf(get_max_value(data).to_string());
        string min_text = """%s""".printf(get_min_value(data).to_string());

        double max_y = Math.fmax((height) - (data[max_index] - (-40)) * y_scale - margin, 18);
        double min_y = Math.fmax((height) - (data[min_index] - (-40)) * y_scale - margin, 18);
        double max_x = Math.fmax(max_index * x_scale - max_index * 2, 18);
        double min_x = Math.fmax(min_index * x_scale - min_index * 2, 18);

        if (max_index == min_index) {
            // If max and min are equal, display a single label "min / max"
            string label = "%s / %s".printf(min_text, max_text);
            cr.move_to(min_x, max_y);
            cr.show_text(label);
        } else {
            // Display separate labels for max and min
            cr.move_to(max_x, max_y);
            cr.show_text(max_text);

            cr.move_to(min_x, min_y);
            cr.show_text(min_text);
        }

    }

    private int get_max_value (int[] arr) {
        int max_value = arr[0];
        foreach (int value in arr) {
            if (value >= max_value)
                max_value = value;
        }
        return max_value;
    }

    private int get_min_value (int[] arr) {
        int min_value = arr[0];
        foreach (int value in arr) {
            if (value <= min_value)
                min_value = value;
        }
        return min_value;
    }

    private int get_max_index (int[] arr) {
        int max_index = 0;
        int max_value = arr[0];
        for (int i = 1; i < arr.length; i++) {
            if (arr[i] > max_value) {
                max_value = arr[i];
                max_index = i;
            }
        }
        return max_index;
    }

    private int get_min_index (int[] arr) {
        int min_index = 0;
        int min_value = arr[0];
        for (int i = 1; i < arr.length; i++) {
            if (arr[i] < min_value) {
                min_value = arr[i];
                min_index = i;
            }
        }
        return min_index;
    }
}