public class Kairos.SunGraph : He.Bin {
    private DateTime sunrise { get; set; }
    private DateTime sunset { get; set; }
    private WeatherPage? weather_page { get; set; }

    public SunGraph (WeatherPage weather_page, DateTime sunrise, DateTime sunset) {
        this.weather_page = weather_page;
        this.sunrise = sunrise;
        this.sunset = sunset;

        weather_page.da_sun.content_height = 120;
        weather_page.da_sun.content_width = 200;
        weather_page.da_sun.vexpand = true;
        weather_page.da_sun.halign = Gtk.Align.CENTER;
        weather_page.da_sun.valign = Gtk.Align.CENTER;
        weather_page.da_sun.set_size_request (360, 180);
        weather_page.da_sun.set_draw_func (draw_stuff);
    }

    private void draw_stuff (Gtk.DrawingArea da_sun,
                             Cairo.Context cr, int width, int height) {
        var now = new DateTime.now_local ();
        draw (cr, sunrise, sunset, now, width, height);
    }

    private void draw (Cairo.Context cr, DateTime sunrise, DateTime sunset, DateTime current_time, int width, int height) {
        int center_x = width / 4;
        int center_y = (height + 18) / 4;
        int radius = height / 4;

        // Draw day arc (above horizon)
        double start_angle = Math.PI; // Left side
        double end_angle = 0; // Right side

        cr.arc (center_x, center_y, radius, start_angle, end_angle);
        cr.set_source_rgba (1, 1, 1, 0.80);
        cr.set_line_width (2);
        cr.stroke ();

        // Draw night arc (below horizon) - dotted line
        cr.arc (center_x, center_y, radius, 0, Math.PI);
        cr.set_source_rgba (1, 1, 1, 0.40);
        cr.set_dash (new double[] { 3.0, 3.0 }, 2.0);
        cr.stroke ();
        cr.set_dash (new double[] {}, 0); // Reset dash

        // Calculate current position
        int64 sunrise_unix = sunrise.to_unix ();
        int64 sunset_unix = sunset.to_unix ();
        int64 current_unix = current_time.to_unix ();

        // Check if it's daytime (proper time comparison)
        bool is_daytime = (current_unix >= sunrise_unix && current_unix <= sunset_unix);

        double dot_x, dot_y;

        if (is_daytime) {
            // Daytime: position on upper arc
            double total_day_seconds = sunset_unix - sunrise_unix;
            double elapsed_seconds = current_unix - sunrise_unix;
            double progress = elapsed_seconds / total_day_seconds;

            // Clamp progress to valid range
            progress = Math.fmax (0.0, Math.fmin (1.0, progress));

            double angle = start_angle + progress * (end_angle - start_angle);
            dot_x = center_x + radius * Math.cos (angle);
            dot_y = center_y - radius * Math.sin (angle);
        } else {
            // Nighttime: position on lower arc
            int64 next_sunrise_unix, prev_sunset_unix;

            if (current_unix < sunrise_unix) {
                // Before sunrise - calculate from previous sunset
                var prev_day = current_time.add_days (-1);
                var prev_sunset = new DateTime.local (
                                                      prev_day.get_year (),
                                                      prev_day.get_month (),
                                                      prev_day.get_day_of_month (),
                                                      sunset.get_hour (),
                                                      sunset.get_minute (),
                                                      sunset.get_second ()
                );
                prev_sunset_unix = prev_sunset.to_unix ();
                next_sunrise_unix = sunrise_unix;
            } else {
                // After sunset - calculate to next sunrise
                var next_day = current_time.add_days (1);
                var next_sunrise = new DateTime.local (
                                                       next_day.get_year (),
                                                       next_day.get_month (),
                                                       next_day.get_day_of_month (),
                                                       sunrise.get_hour (),
                                                       sunrise.get_minute (),
                                                       sunrise.get_second ()
                );
                prev_sunset_unix = sunset_unix;
                next_sunrise_unix = next_sunrise.to_unix ();
            }

            double total_night_seconds = next_sunrise_unix - prev_sunset_unix;
            double elapsed_night_seconds = current_unix - prev_sunset_unix;
            double progress = elapsed_night_seconds / total_night_seconds;

            // Clamp progress to valid range
            progress = Math.fmax (0.0, Math.fmin (1.0, progress));

            // Night arc goes from 0 to PI (right to left on bottom)
            double angle = progress * Math.PI;
            dot_x = center_x + radius * Math.cos (angle);
            dot_y = center_y + radius * Math.sin (angle);
        }

        // Draw sun/moon indicator
        cr.arc (dot_x, dot_y, 8, 0, 2 * Math.PI);
        if (is_daytime) {
            cr.set_source_rgba (1, 1, 1, 0.80); // Sun color
        } else {
            cr.set_source_rgba (1, 1, 1, 0.40); // Moon color
        }
        cr.fill ();

        // Draw time labels
        cr.select_font_face ("Geist", Cairo.FontSlant.NORMAL, Cairo.FontWeight.BOLD);
        cr.set_font_size (12);
        cr.set_source_rgba (1, 1, 1, 0.95);

        // Sunrise label (left side)
        string sunrise_text = sunrise.format ("%H:%M");
        Cairo.TextExtents sunrise_extents;
        cr.text_extents (sunrise_text, out sunrise_extents);

        double sunrise_x = center_x - radius - sunrise_extents.width - 10;
        double sunrise_y = center_y + 5;
        cr.move_to (sunrise_x, sunrise_y);
        cr.show_text (sunrise_text);

        // Sunset label (right side)
        string sunset_text = sunset.format ("%H:%M");
        Cairo.TextExtents sunset_extents;
        cr.text_extents (sunset_text, out sunset_extents);

        double sunset_x = center_x + radius + 10;
        double sunset_y = center_y + 5;
        cr.move_to (sunset_x, sunset_y);
        cr.show_text (sunset_text);

        // Current time label above/below the dot
        string current_text = current_time.format ("%H:%M");
        Cairo.TextExtents current_extents;
        cr.text_extents (current_text, out current_extents);

        double label_x = dot_x - current_extents.width / 2;
        double label_y = is_daytime ? dot_y - 15 : dot_y + current_extents.height + 15;

        // Keep label within bounds
        label_x = Math.fmax (5, Math.fmin (width - current_extents.width - 5, label_x));

        cr.move_to (label_x, label_y);
        cr.show_text (current_text);
    }
}