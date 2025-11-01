public class Kairos.SunGraph : He.Bin {
    private DateTime sunrise { get; set; }
    private DateTime sunset { get; set; }
    private WeatherPage? weather_page { get; set; }

    public SunGraph (WeatherPage weather_page, DateTime sunrise, DateTime sunset) {
        this.weather_page = weather_page;
        this.sunrise = sunrise;
        this.sunset = sunset;

        weather_page.da_sun.content_height = 200;
        weather_page.da_sun.content_width = 400;
        weather_page.da_sun.vexpand = true;
        weather_page.da_sun.halign = Gtk.Align.CENTER;
        weather_page.da_sun.valign = Gtk.Align.CENTER;
        weather_page.da_sun.set_size_request (400, 200);
        weather_page.da_sun.set_draw_func (draw_stuff);
    }

    private void draw_stuff (Gtk.DrawingArea da_sun,
                             Cairo.Context cr, int width, int height) {
        var now = new DateTime.now_local ();
        draw (cr, sunrise, sunset, now, width, height);
    }

    private void draw (Cairo.Context cr, DateTime sunrise, DateTime sunset, DateTime current_time, int width, int height) {
        int margin = 20;
        int graph_width = width - margin * 2;
        int graph_height = height - margin * 2;
        double center_y = margin + graph_height / 2.0;
        double amplitude = graph_height / 3.0; // Height of the wave

        // Calculate sunrise and sunset as hours of day (0-24)
        double sunrise_hour = sunrise.get_hour () + sunrise.get_minute () / 60.0;
        double sunset_hour = sunset.get_hour () + sunset.get_minute () / 60.0;
        double current_hour = current_time.get_hour () + current_time.get_minute () / 60.0;

        // Calculate day duration
        double day_duration = sunset_hour - sunrise_hour;
        if (day_duration < 0) day_duration += 24.0;
        
        // Calculate mid-day point (peak of the wave)
        double mid_day_hour = (sunrise_hour + sunset_hour) / 2.0;
        if (mid_day_hour < 0) mid_day_hour += 24.0;
        if (mid_day_hour >= 24.0) mid_day_hour -= 24.0;

        // Draw grid line (zero line / horizon)
        cr.set_source_rgba (1, 1, 1, 0.3);
        cr.set_line_width (1);
        cr.move_to (margin, center_y);
        cr.line_to (width - margin, center_y);
        cr.stroke ();

        // Draw sinusoidal wave representing day/night cycle
        cr.set_source_rgba (1, 1, 1, 0.85);
        cr.set_line_width (2);
        
        int num_points = graph_width;
        for (int i = 0; i <= num_points; i++) {
            double x = margin + (i * graph_width) / (double) num_points;
            
            // Map x position to hour of day (0-24)
            double hour = (i / (double) num_points) * 24.0;
            
            // Normalize hour to handle wrap-around
            double normalized_hour = hour;
            if (normalized_hour >= 24.0) normalized_hour -= 24.0;
            
            // Determine if we're in day or night period
            bool is_day_period = false;
            if (sunrise_hour <= sunset_hour) {
                is_day_period = (normalized_hour >= sunrise_hour && normalized_hour <= sunset_hour);
            } else {
                // Handles case where sunset is next day (polar regions)
                is_day_period = (normalized_hour >= sunrise_hour || normalized_hour <= sunset_hour);
            }
            
            // Calculate smooth sinusoidal value
            double value;
            if (is_day_period) {
                // During day: smooth curve from 0 (sunrise) to peak (mid-day) to 0 (sunset)
                double day_progress = (normalized_hour - sunrise_hour);
                if (day_progress < 0) day_progress += 24.0;
                double t = day_progress / day_duration; // 0 at sunrise, 1 at sunset
                // Use half-sine wave: sin(π * t) gives 0 at t=0, 1 at t=0.5, 0 at t=1
                value = Math.sin (Math.PI * t);
            } else {
                // During night: smooth curve from 0 (sunset) down to minimum (mid-night) back to 0 (sunrise)
                double night_progress;
                if (normalized_hour < sunrise_hour) {
                    // Before sunrise
                    night_progress = normalized_hour + (24.0 - sunset_hour);
                } else {
                    // After sunset
                    night_progress = normalized_hour - sunset_hour;
                }
                double night_duration = 24.0 - day_duration;
                if (night_duration <= 0) night_duration = 0.1; // Prevent division by zero
                double t = night_progress / night_duration;
                // Use half-sine wave (inverted): -sin(π * t) gives 0 at t=0, -1 at t=0.5, 0 at t=1
                value = -Math.sin (Math.PI * t);
            }
            
            double y = center_y - value * amplitude;
            y = Math.fmax (margin, Math.fmin (height - margin, y));
            
            if (i == 0) {
                cr.move_to (x, y);
            } else {
                cr.line_to (x, y);
            }
        }
        cr.stroke ();

        // Fill area above zero (day) and below zero (night)
        // Fill day area (positive/above center)
        cr.set_source_rgba (1, 1, 1, 0.15);
        cr.move_to (margin, center_y);
        for (int i = 0; i <= num_points; i++) {
            double x = margin + (i * graph_width) / (double) num_points;
            double hour = (i / (double) num_points) * 24.0;
            double normalized_hour = hour;
            if (normalized_hour >= 24.0) normalized_hour -= 24.0;
            
            bool is_day_period = false;
            if (sunrise_hour <= sunset_hour) {
                is_day_period = (normalized_hour >= sunrise_hour && normalized_hour <= sunset_hour);
            } else {
                is_day_period = (normalized_hour >= sunrise_hour || normalized_hour <= sunset_hour);
            }
            
            double value;
            if (is_day_period) {
                double day_progress = (normalized_hour - sunrise_hour);
                if (day_progress < 0) day_progress += 24.0;
                double t = day_progress / day_duration;
                value = Math.sin (Math.PI * t);
            } else {
                double night_progress;
                if (normalized_hour < sunrise_hour) {
                    night_progress = normalized_hour + (24.0 - sunset_hour);
                } else {
                    night_progress = normalized_hour - sunset_hour;
                }
                double night_duration = 24.0 - day_duration;
                if (night_duration <= 0) night_duration = 0.1;
                double t = night_progress / night_duration;
                value = -Math.sin (Math.PI * t);
            }
            
            double y = center_y - value * amplitude;
            y = Math.fmax (margin, Math.fmin (height - margin, y));
            cr.line_to (x, Math.fmin (y, center_y)); // Clamp to center for fill
        }
        cr.line_to (width - margin, center_y);
        cr.close_path ();
        cr.fill ();

        // Draw current time indicator
        double normalized_current_hour = current_hour;
        if (normalized_current_hour >= 24.0) normalized_current_hour -= 24.0;
        
        double current_x = margin + (normalized_current_hour / 24.0) * graph_width;
        
        bool is_daytime = false;
        if (sunrise_hour <= sunset_hour) {
            is_daytime = (normalized_current_hour >= sunrise_hour && normalized_current_hour <= sunset_hour);
        } else {
            is_daytime = (normalized_current_hour >= sunrise_hour || normalized_current_hour <= sunset_hour);
        }
        
        double current_value;
        if (is_daytime) {
            double day_progress = (normalized_current_hour - sunrise_hour);
            if (day_progress < 0) day_progress += 24.0;
            double t = day_progress / day_duration;
            current_value = Math.sin (Math.PI * t);
        } else {
            double night_progress;
            if (normalized_current_hour < sunrise_hour) {
                night_progress = normalized_current_hour + (24.0 - sunset_hour);
            } else {
                night_progress = normalized_current_hour - sunset_hour;
            }
            double night_duration = 24.0 - day_duration;
            if (night_duration <= 0) night_duration = 0.1;
            double t = night_progress / night_duration;
            current_value = -Math.sin (Math.PI * t);
        }
        
        double current_y = center_y - current_value * amplitude;
        current_y = Math.fmax (margin, Math.fmin (height - margin, current_y));

        // Draw indicator dot
        cr.set_source_rgba (1, 1, 1, 1.0);
        cr.arc (current_x, current_y, 6, 0, 2 * Math.PI);
        cr.fill ();
        
        // Draw indicator line
        cr.set_source_rgba (1, 1, 1, 0.6);
        cr.set_line_width (1.5);
        cr.move_to (current_x, margin);
        cr.line_to (current_x, height - margin);
        cr.stroke ();

        // Draw time labels - always use white since drawn on colored weather backgrounds
        cr.select_font_face ("Natrium", Cairo.FontSlant.NORMAL, Cairo.FontWeight.BOLD);
        cr.set_font_size (12);
        cr.set_source_rgba (1, 1, 1, 0.95); // White for contrast on colored backgrounds

        // Sunrise label (left side)
        string sunrise_text = sunrise.format ("%H:%M");
        Cairo.TextExtents sunrise_extents;
        cr.text_extents (sunrise_text, out sunrise_extents);

        double sunrise_x = margin + (sunrise_hour / 24.0) * graph_width;
        double sunrise_label_x = sunrise_x - sunrise_extents.width / 2;
        double sunrise_label_y = center_y + amplitude + 20;
        sunrise_label_x = Math.fmax (margin, Math.fmin (width - margin - sunrise_extents.width, sunrise_label_x));
        cr.move_to (sunrise_label_x, sunrise_label_y);
        cr.show_text (sunrise_text);

        // Sunset label (right side)
        string sunset_text = sunset.format ("%H:%M");
        Cairo.TextExtents sunset_extents;
        cr.text_extents (sunset_text, out sunset_extents);

        double sunset_x = margin + (sunset_hour / 24.0) * graph_width;
        double sunset_label_x = sunset_x - sunset_extents.width / 2;
        double sunset_label_y = center_y + amplitude + 20;
        sunset_label_x = Math.fmax (margin, Math.fmin (width - margin - sunset_extents.width, sunset_label_x));
        cr.move_to (sunset_label_x, sunset_label_y);
        cr.show_text (sunset_text);

        // Current time label above/below the indicator dot
        string current_text = current_time.format ("%H:%M");
        Cairo.TextExtents current_extents;
        cr.text_extents (current_text, out current_extents);

        double label_x = current_x - current_extents.width / 2;
        double label_y = is_daytime ? current_y - 15 : current_y + current_extents.height + 15;

        // Keep label within bounds
        label_x = Math.fmax (margin, Math.fmin (width - margin - current_extents.width, label_x));
        label_y = Math.fmax (margin + current_extents.height, Math.fmin (height - margin, label_y));

        cr.move_to (label_x, label_y);
        cr.show_text (current_text);
    }
}