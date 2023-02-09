[GtkTemplate (ui = "/com/fyralabs/Kairos/weatherrow.ui")]
public class Kairos.WeatherRow : He.Bin {
    [GtkChild]
    unowned Gtk.Label time_label;
    [GtkChild]
    unowned Gtk.Image image;
    [GtkChild]
    unowned Gtk.Label forecast_label;

    public WeatherRow (GWeather.Info weather_info, string time) {
        time_label.label = time;

        image.icon_name = weather_info.get_icon_name();

        double temp;
        weather_info.get_value_temp (GWeather.TemperatureUnit.DEFAULT, out temp);
        forecast_label.label = _("%i°").printf ((int) temp);
    }
}