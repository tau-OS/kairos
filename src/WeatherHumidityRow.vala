[GtkTemplate (ui = "/com/fyralabs/Kairos/weatherhumidityrow.ui")]
public class Kairos.WeatherHumidityRow : He.Bin {
    [GtkChild]
    unowned Gtk.Label time_label;
    [GtkChild]
    unowned Gtk.Image image;
    [GtkChild]
    unowned Gtk.Label humidity_label;

    public WeatherHumidityRow (GWeather.Info weather_info, string time) {
        time_label.label = time;

        if (weather_info.get_humidity () >= "0%" && weather_info.get_humidity () < "24%") {
            image.set_from_icon_name ("humidity-0-symbolic");
        } else if (weather_info.get_humidity () >= "25%" && weather_info.get_humidity () < "49%") {
            image.set_from_icon_name ("humidity-25-symbolic");
        } else if (weather_info.get_humidity () >= "50%" && weather_info.get_humidity () < "74%") {
            image.set_from_icon_name ("humidity-50-symbolic");
        } else if (weather_info.get_humidity () >= "75%" && weather_info.get_humidity () < "99%") {
            image.set_from_icon_name ("humidity-75-symbolic");
        } else if (weather_info.get_humidity () >= "100%") {
            image.set_from_icon_name ("humidity-100-symbolic");
        }

        humidity_label.label = _("%s").printf (weather_info.get_humidity ());
    }
}