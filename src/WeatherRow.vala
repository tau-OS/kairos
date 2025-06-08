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

    public WeatherRow (GWeather.Info weather_info, string time, bool is_current_weather = false) {
        time_label.label = time;

        string icon_name = weather_info.get_icon_name ();
        if (icon_name != null && icon_name.length > 0) {
            image.icon_name = icon_name;
        } else {
            image.icon_name = "weather-clear-symbolic"; // Default icon
        }

        string temp_summary = weather_info.get_temp_summary ();
        if (temp_summary != null && temp_summary.length > 0 && temp_summary != "0") {
            forecast_label.label = "%s".printf (temp_summary);
        } else {
            forecast_label.label = "N/A";
        }

        if (is_current_weather) {
            // For "Now" entry, try to show daily high/low temperatures
            double min, max;
            var ok1 = weather_info.get_value_temp_min (GWeather.TemperatureUnit.DEFAULT, out min);
            var ok2 = weather_info.get_value_temp_max (GWeather.TemperatureUnit.DEFAULT, out max);

            if (ok1 && ok2 && min != 0.0 && max != 0.0 && min != max) {
                string templo = weather_info.get_temp_min ();
                string temphi = weather_info.get_temp_max ();

                if (templo != null && templo.length > 0 && templo != "0") {
                    loforecast_label.label = "%s".printf (templo);
                } else {
                    loforecast_label.label = temp_summary ?? "N/A";
                }

                if (temphi != null && temphi.length > 0 && temphi != "0") {
                    hiforecast_label.label = "%s".printf (temphi);
                } else {
                    hiforecast_label.label = temp_summary ?? "N/A";
                }
            } else {
                // No daily high/low available, hide these labels
                loforecast_label.label = "";
                hiforecast_label.label = "";
            }
        } else {
            // For hourly forecasts, don't show high/low (they don't make sense)
            // Just show the hourly temperature or leave blank
            loforecast_label.label = "";
            hiforecast_label.label = "";
        }

        string sky_condition = weather_info.get_sky ();
        if (sky_condition != null && sky_condition.length > 0) {
            cond_label.label = "%s".printf (sky_condition);
        } else {
            cond_label.label = "Clear"; // Default condition
        }
    }
}