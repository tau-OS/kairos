/*
* Copyright (c) 2017-2019 Daniel Foré (http://danielfore.com)
*
* This program is free software; you can redistribute it and/or
* modify it under the terms of the GNU General Public
* License as published by the Free Software Foundation; either
* version 2 of the License, or (at your option) any later version.
*
* This program is distributed in the hope that it will be useful,
* but WITHOUT ANY WARRANTY; without even the implied warranty of
* MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
* General Public License for more details.
*
* You should have received a copy of the GNU General Public
* License along with this program; if not, write to the
* Free Software Foundation, Inc., 51 Franklin Street, Fifth Floor,
* Boston, MA 02110-1301 USA
*/

[GtkTemplate (ui = "/co/tauos/Kairos/mainwindow.ui")]
public class MainWindow : He.ApplicationWindow {
    private GWeather.Location location;
    private GWeather.Info weather_info;
    public He.Application app {get; construct;}
    private Gtk.CssProvider provider;
    private string color_primary = "#58a8fa";
    private string color_secondary = "#fafafa";

    public string wind {get; set;}
    public string dew {get; set;}
    public string temphilo {get; set;}

    [GtkChild]
    unowned Gtk.Label location_label;
    [GtkChild]
    unowned Gtk.Image weather_icon;
    [GtkChild]
    unowned Gtk.Label weather_label;
    [GtkChild]
    unowned Gtk.Label temp_label;
    [GtkChild]
    unowned He.EmptyPage alert_label;
    [GtkChild]
    unowned Gtk.Button refresh_button;
    [GtkChild]
    unowned Gtk.Stack stack;

    public MainWindow (He.Application application) {
        Object (
            app: application,
            application: application,
            icon_name: Config.APP_ID,
            resizable: false,
            title: _("Kairos")
        );
    }

    construct {
        var theme = Gtk.IconTheme.get_for_display (Gdk.Display.get_default ());
        theme.add_resource_path ("/co/tauos/Kairos/");

        provider = new Gtk.CssProvider ();
        set_style ();

        get_location.begin ();
        weather_info = new GWeather.Info (location);
        weather_info.set_contact_info ("https://raw.githubusercontent.com/tau-OS/kairos/main/co.tauos.Kairos.doap");
        weather_info.set_enabled_providers (GWeather.Provider.METAR | GWeather.Provider.MET_NO | GWeather.Provider.OWM);
        weather_info.update ();

        alert_label.action_button.clicked.connect(() => {
            set_style ();
            get_location.begin ();
            weather_info.update ();
        });

        refresh_button.clicked.connect (() => {
            set_style ();
            get_location.begin ();
            weather_info.update ();
        });

        weather_info.updated.connect (() => {
            set_style ();
        });

        add_css_class ("window-bg");
        set_size_request (360, 150);
    }

    public async void get_location () {
        try {
            var simple = yield new GClue.Simple (Config.APP_ID, GClue.AccuracyLevel.CITY, null);

            if (simple.client != null && simple != null) {
                var client = simple.get_client();

                simple.notify["location"].connect (() => {
                    on_location_updated (simple);
                });

                on_location_updated (simple);
            }

            simple.notify["location"].connect (() => {
                on_location_updated (simple);
            });

            on_location_updated (simple);
        } catch (Error e) {
            warning ("Failed to connect to GeoClue2 service: %s, fallbacking to (0,0) coords.", e.message);
            location = GWeather.Location.get_world().find_nearest_city(0.0, 0.0);
            weather_info.location = location;
            weather_info.update ();
            stack.visible_child_name = "weather";
            set_style ();
            return;
        }
    }

    public void on_location_updated (GClue.Simple simple) {
        var geoclueLocation = simple.get_location ();
        location = GWeather.Location.get_world().find_nearest_city(geoclueLocation.latitude, geoclueLocation.longitude);
        weather_info.location = location;
        weather_info.update ();
        stack.visible_child_name = "weather";
        set_style ();
    }

    public void set_style () {
        if (location == null) {
            return;
        }

        location_label.label = dgettext ("libgweather-locations", location.get_city_name ());

        weather_icon.icon_name = weather_info.get_symbolic_icon_name ();
        weather_label.label = dgettext ("libgweather", weather_info.get_sky ());

        double temp;
        weather_info.get_value_temp (GWeather.TemperatureUnit.DEFAULT, out temp);
        temp_label.label = _("%i°").printf ((int) temp);

        double temphi; double templo;
        weather_info.get_value_temp_max (GWeather.TemperatureUnit.DEFAULT, out temphi);
        weather_info.get_value_temp_min (GWeather.TemperatureUnit.DEFAULT, out templo);

        if (temphi != 0 && templo != 0) {
            temphilo = _("High: %s° / Low: %s°").printf (weather_info.get_temp_max (), weather_info.get_temp_min ());
        } else {
            temphilo = _("Feels Like: %s°").printf (weather_info.get_apparent ().replace("°F", "").replace("°C", "").replace("°K", ""));
        }

        double win; GWeather.WindDirection windir;
        weather_info.get_value_wind (GWeather.SpeedUnit.DEFAULT, out win, out windir);
        wind = _("Wind:") + " " + "%.0f %s".printf(win, GWeather.SpeedUnit.DEFAULT.to_string ());
        double deew;
        weather_info.get_value_dew (GWeather.TemperatureUnit.DEFAULT, out deew);
        dew = _("Dew Point:") + " " + "%.0f°".printf(deew);

        switch (weather_icon.icon_name) {
            case "weather-clear-night-symbolic":
            case "weather-few-clouds-night-symbolic":
                color_primary = "#1b07a2";
                color_secondary = "#fafafa";
                break;
            case "weather-few-clouds-symbolic":
            case "weather-overcast-symbolic":
            case "weather-showers-symbolic":
            case "weather-showers-scattered-symbolic":
                color_primary = "#828292";
                color_secondary = "#fafafa";
                break;
            case "weather-snow-symbolic":
                color_primary = "#fafcff";
                color_secondary = "#2d2d2d";
                break;
            default:
                color_primary = "#58a8fa";
                color_secondary = "#fafafa";
                break;
        }

        string COLOR_PRIMARY = """
            .window-bg {
                background: %s;
                color: %s;
                transition: all 600ms ease-in-out;
            }
        """;

        var colored_css = COLOR_PRIMARY.printf (color_primary, color_secondary);
        provider.load_from_data ((uint8[])colored_css);
        this.get_style_context().add_provider(provider, 999);
    }

    [GtkCallback]
    string get_wind_label () {
        return wind;
    }
    [GtkCallback]
    string get_dew_label () {
        return dew;
    }
    [GtkCallback]
    string get_temphilo_label () {
        return temphilo;
    }
}
