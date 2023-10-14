[GtkTemplate (ui = "/com/fyralabs/Kairos/weatherrow.ui")]
public class Kairos.WeatherRow : He.Bin {
    [GtkChild]
    unowned Gtk.Label time_label;
    [GtkChild]
    unowned Gtk.Image image;
    [GtkChild]
    unowned Gtk.Label forecast_label;
    [GtkChild]
    unowned Gtk.Label hiforecast_label;
    [GtkChild]
    unowned Gtk.Label loforecast_label;
    [GtkChild]
    unowned Gtk.Label cond_label;

    public WeatherRow (GWeather.Info weather_info, string time) {
        time_label.label = time;

        image.icon_name = weather_info.get_icon_name ();

        forecast_label.label = _("%s").printf (weather_info.get_temp_summary ());

        double min, max;
        var ok1 = weather_info.get_value_temp_min (GWeather.TemperatureUnit.DEFAULT, out min);
        var ok2 = weather_info.get_value_temp_max (GWeather.TemperatureUnit.DEFAULT, out max);
        if (ok1 && ok2) {
            string templo = weather_info.get_temp_min ();
            loforecast_label.label = _("%s").printf ( templo);

            string temphi = weather_info.get_temp_max ();
            hiforecast_label.label = _("%s").printf ( temphi);
        } else {
            string templo = weather_info.get_temp_summary ();
            loforecast_label.label = _("%s").printf ( templo);

            string temphi = weather_info.get_temp_summary ();
            hiforecast_label.label = _("%s").printf ( temphi);
        }

        cond_label.label = _("%s").printf (weather_info.get_sky ());
    }
}
