public class Kairos.WeatherGraph : He.Bin {
    private int[] data = {};
    private int margin = 0;
    private int curr_time_x = 0;
    private int curr_time_y = 0;
    private bool use_fahrenheit = false;

    private Gtk.DrawingArea draw_area;

    public WeatherGraph (GLib.SList<GWeather.Info> info, bool fahrenheit = false) {
        use_fahrenheit = fahrenheit;

        // Safely extract temperature data with proper validation
        uint info_length = info.length ();
        for (var i = 0; i < info_length && i < 13; i++) {
            var inf = info.nth_data (i);
            if (inf != null) {
                var temp_str = inf.get_temp ();
                if (temp_str != null && temp_str.length > 0 && temp_str != "0") {
                    // Remove any degree symbols and extra characters for parsing
                    string clean_temp = temp_str.replace ("°C", "").replace ("°F", "").replace ("°", "").strip ();

                    if (clean_temp.length > 0) {
                        double temp_double = double.parse (clean_temp);
                        int temp = (int) Math.floor (temp_double);

                        // Validate temperature is within reasonable range
                        if (use_fahrenheit) {
                            if (temp >= -50 && temp <= 130) {     // Reasonable Fahrenheit range
                                data += temp;
                            }
                        } else {
                            if (temp >= -40 && temp <= 60) {     // Reasonable Celsius range
                                data += temp;
                            }
                        }
                    }
                }
            }
        }

        // Ensure we have at least some data to prevent crashes
        if (data.length == 0) {
            warning ("No valid temperature data found, using placeholder");
            data += use_fahrenheit ? 70 : 20; // Reasonable default temperature
        }
    }

    construct {
        draw_area = new Gtk.DrawingArea ();
        draw_area.set_draw_func (on_draw);
        draw_area.vexpand = true;
        draw_area.hexpand = true; // Allow horizontal expansion
        draw_area.set_size_request (300, 200); // Minimum size

        var motion_controller = new Gtk.EventControllerMotion ();
        motion_controller.set_propagation_phase (Gtk.PropagationPhase.CAPTURE);
        motion_controller.motion.connect (on_mouse_motion);
        draw_area.add_controller (motion_controller);

        child = draw_area;
    }

    private void on_mouse_motion (Gtk.EventControllerMotion controller, double x, double y) {
        curr_time_x = (int) x;
        curr_time_y = (int) y;
        draw_area.queue_draw ();
    }

    private void on_draw (Gtk.DrawingArea draw_area,
                          Cairo.Context cr,
                          int width,
                          int height) {

        // Early return if no data
        if (data.length == 0) {
            return;
        }

        cr.set_source_rgba (0, 0, 0, 0);
        cr.paint ();
        cr.set_source_rgba (0.98, 0.98, 0.98, 1);

        int graph_height = height - margin;

        // Dynamic scaling based on actual width and data points
        var x_scale = (double) (width - margin * 2) / (double) (data.length - 1);

        // Use sensible fixed temperature ranges for consistent positioning
        int scale_min, scale_max;
        if (use_fahrenheit) {
            scale_min = 10; // 10°F
            scale_max = 100; // 100°F
        } else {
            scale_min = -10; // -10°C
            scale_max = 40; // 40°C
        }

        int temp_range = scale_max - scale_min;
        var y_scale = (double) graph_height / (double) temp_range;

        // Draw filled area
        cr.move_to (margin, height);

        for (int i = 0; i < data.length; i++) {
            double x = margin + i * x_scale;
            double y = height - (data[i] - scale_min) * y_scale;
            cr.line_to (x, y);
        }

        cr.line_to (margin + (data.length - 1) * x_scale, height);
        cr.close_path ();

        var gradient = new Cairo.Pattern.linear (0, 0, 0, height);
        gradient.add_color_stop_rgba (0, 0.98, 0.98, 0.98, 0.5);
        gradient.add_color_stop_rgba (1, 0.98, 0.98, 0.98, 0.0);

        cr.set_source (gradient);
        cr.fill_preserve ();
        cr.stroke ();

        // Draw line graph
        cr.set_source_rgba (0.98, 0.98, 0.98, 1);
        cr.move_to (margin, height - (data[0] - scale_min) * y_scale);

        for (int i = 1; i < data.length; i++) {
            double x = margin + i * x_scale;
            double y = height - (data[i] - scale_min) * y_scale;
            cr.line_to (x, y);
        }
        cr.stroke ();

        // Draw labels
        cr.select_font_face ("Geist", Cairo.FontSlant.NORMAL, Cairo.FontWeight.BOLD);
        cr.set_font_size (14);
        cr.set_source_rgba (0.98, 0.98, 0.98, 1);

        int max_index = get_max_index (data);
        int min_index = get_min_index (data);

        string unit_suffix = use_fahrenheit ? "°F" : "°C";
        string max_text = "%s%s".printf (get_max_value (data).to_string (), unit_suffix);
        string min_text = "%s%s".printf (get_min_value (data).to_string (), unit_suffix);

        double max_y = Math.fmax (height - (data[max_index] - scale_min) * y_scale - margin, 18);
        double min_y = Math.fmax (height - (data[min_index] - scale_min) * y_scale - margin, 18);
        double max_x = Math.fmax (margin + max_index * x_scale - max_index * 2, 18);
        double min_x = Math.fmax (margin + min_index * x_scale - min_index * 2, 18);

        if (max_index == min_index) {
            string label = "%s / %s".printf (min_text, max_text);
            cr.move_to (min_x, max_y);
            cr.show_text (label);
        } else {
            cr.move_to (max_x, max_y);
            cr.show_text (max_text);

            cr.move_to (min_x, min_y);
            cr.show_text (min_text);
        }

        // Draw cursor line with bounds checking
        if (curr_time_x >= margin && curr_time_x <= width - margin) {
            cr.set_dash (new double[] { 4.0, 4.0 }, 2.0);
            cr.set_source_rgba (0.78, 0.78, 0.78, 1);
            cr.new_path ();
            cr.move_to (curr_time_x, 0);
            cr.line_to (curr_time_x, height);
            cr.stroke ();
            cr.set_dash (new double[] {}, 0);
            cr.new_path ();

            // Safe data index calculation with bounds checking
            int data_index = (int) Math.floor ((curr_time_x - margin) / x_scale);
            if (data_index >= 0 && data_index < data.length) {
                cr.select_font_face ("Geist", Cairo.FontSlant.NORMAL, Cairo.FontWeight.BOLD);
                cr.set_font_size (12);
                cr.set_source_rgba (0.98, 0.98, 0.98, 1);

                string data_value = "%s%s".printf (data[data_index].to_string (), unit_suffix);

                Cairo.TextExtents text_extents;
                cr.text_extents (data_value, out text_extents);

                double text_x = curr_time_x + margin;
                double text_y = curr_time_y - text_extents.height / 2;

                // Improved overlap detection
                bool overlaps_min = (text_x + text_extents.width + margin >= min_x - margin &&
                                     text_x - margin <= min_x + margin);
                bool overlaps_max = (text_x + text_extents.width + margin >= max_x - margin &&
                                     text_x - margin <= max_x + margin);

                if (!overlaps_min && !overlaps_max) {
                    // Keep text within bounds
                    if (text_x + text_extents.width > width - margin) {
                        text_x = width - margin - text_extents.width;
                    }
                    if (text_x < margin) {
                        text_x = margin;
                    }

                    cr.move_to (text_x, text_y);
                    cr.show_text (data_value);
                }
            }
        }
    }

    private int get_max_value (int[] arr) {
        if (arr.length == 0)return 0;

        int max_value = arr[0];
        foreach (int value in arr) {
            if (value >= max_value)
                max_value = value;
        }
        return max_value;
    }

    private int get_min_value (int[] arr) {
        if (arr.length == 0)return 0;

        int min_value = arr[0];
        foreach (int value in arr) {
            if (value <= min_value)
                min_value = value;
        }
        return min_value;
    }

    private int get_max_index (int[] arr) {
        if (arr.length == 0)return 0;

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
        if (arr.length == 0)return 0;

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