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
                             Cairo.Context cr, int x, int y) {
        var now = new DateTime.now_local ();

        draw (cr, sunrise, sunset, now);
    }

    private void draw (Cairo.Context cr, DateTime sunrise, DateTime sunset, DateTime current_time) {
        int center_x = 140;
        int center_y = 100;
        int radius = 90;

        double start_angle = Math.PI;
        double end_angle = 0;
        double total_seconds = sunset.to_unix() - sunrise.to_unix();
        double elapsed_seconds = current_time.to_unix() - sunrise.to_unix();
        double angle = start_angle + (elapsed_seconds / total_seconds) * (end_angle - start_angle);
        
        cr.arc(center_x, center_y, radius, start_angle, end_angle);
        cr.set_source_rgba(1, 1, 1, 0.80);
        cr.stroke();

        if (current_time.get_hour () >= sunrise.get_hour () && current_time.get_hour () <= sunset.get_hour ()) {
            double dot_x = center_x + radius * Math.cos(angle);
            double dot_y = center_y - radius * Math.sin(angle);

            cr.arc(dot_x, dot_y, 10, 0, 2 * Math.PI);
            cr.set_source_rgba(1, 1, 1, 0.95);
            cr.fill();
        } else {
            double dot_x = center_x + radius * Math.sin(angle);
            double dot_y = center_y - radius * Math.cos(angle);

            cr.arc(-dot_x, -dot_y, 10, 0, 2 * Math.PI);
            cr.set_source_rgba(1, 1, 1, 0.95);
            cr.fill();
        }

        double label_margin = 5;

        cr.move_to(center_x - radius * Math.cos(start_angle) - 3*label_margin, center_y - radius * Math.sin(start_angle) + 3*label_margin);
        cr.set_source_rgba(1, 1, 1, 0.95);
        cr.set_antialias (Cairo.Antialias.GRAY);
        cr.select_font_face("Manrope", Cairo.FontSlant.NORMAL, Cairo.FontWeight.BOLD);
        cr.set_font_size (14);
        cr.show_text(sunset.format("%H:%M"));

        cr.move_to(center_x - radius * Math.cos(end_angle) - 3*label_margin, center_y - radius * Math.sin(end_angle) + 3*label_margin);
        cr.show_text(sunrise.format("%H:%M"));
    }
}