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

        string humidity_str = weather_info.get_humidity ();
        if (humidity_str != null && humidity_str.length > 0) {
            // Extract numeric value from humidity string (e.g., "75%" -> "75")
            string numeric_part = humidity_str.replace ("%", "").strip ();

            int humidity_val = int.parse (numeric_part);

            // Set icon based on humidity level with proper bounds checking
            if (humidity_val >= 0 && humidity_val < 25) {
                image.set_from_icon_name ("humidity-0-symbolic");
            } else if (humidity_val >= 25 && humidity_val < 50) {
                image.set_from_icon_name ("humidity-25-symbolic");
            } else if (humidity_val >= 50 && humidity_val < 75) {
                image.set_from_icon_name ("humidity-50-symbolic");
            } else if (humidity_val >= 75 && humidity_val < 100) {
                image.set_from_icon_name ("humidity-75-symbolic");
            } else if (humidity_val >= 100) {
                image.set_from_icon_name ("humidity-100-symbolic");
            } else {
                // Default icon for invalid values
                image.set_from_icon_name ("humidity-50-symbolic");
            }

            humidity_label.label = "%s".printf (humidity_str);
        } else {
            // No humidity data available
            image.set_from_icon_name ("humidity-50-symbolic");
            humidity_label.label = "N/A";
        }
    }
}