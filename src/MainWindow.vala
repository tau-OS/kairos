/*
* Copyright (c) 2022 Fyra Labs
*
* This program is free software; you can redistribute it and/or
* modify it under the terms of the GNU General Public
* License as published by the Free Software Foundation; either
* version 3 of the License, or (at your option) any later version.
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
    private string graphic = "";

    public string wind {get; set;}
    public string dew {get; set;}
    public string temphilo {get; set;}

    public SimpleActionGroup actions { get; construct; }
    public const string ACTION_PREFIX = "win.";
    public const string ACTION_ABOUT = "action_about";

    private const GLib.ActionEntry[] ACTION_ENTRIES = {
          {ACTION_ABOUT, action_about }
    };
    public static Gee.MultiMap<string, string> action_accelerators = new Gee.HashMultiMap<string, string> ();

    [GtkChild]
    unowned Gtk.Label location_label;
    [GtkChild]
    unowned Gtk.Image weather_icon;
    [GtkChild]
    unowned Gtk.Label weather_label;
    [GtkChild]
    unowned Gtk.Label temp_label;
    [GtkChild]
    unowned Gtk.Label kudos_label;
    [GtkChild]
    unowned He.EmptyPage alert_label;
    [GtkChild]
    unowned Gtk.Button refresh_button;
    [GtkChild]
    unowned Gtk.Stack stack;
    [GtkChild]
    unowned Gtk.SearchEntry search_entry;

    public MainWindow (He.Application application) {
        Object (
            app: application,
            application: application,
            icon_name: Config.APP_ID,
            resizable: false,
            title: _("Kairos")
        );

        set_style ();
        get_location.begin ();
        weather_info.update ();
    }

    construct {
        // Actions
        actions = new SimpleActionGroup ();
        actions.add_action_entries (ACTION_ENTRIES, this);
        insert_action_group ("win", actions);

        foreach (var action in action_accelerators.get_keys ()) {
            var accels_array = action_accelerators[action].to_array ();
            accels_array += null;

            app.set_accels_for_action (ACTION_PREFIX + action, accels_array);
        }
        app.set_accels_for_action("app.quit", {"<Ctrl>q"});
        app.set_accels_for_action ("win.action_keys", {"<Ctrl>question"});

        var theme = Gtk.IconTheme.get_for_display (Gdk.Display.get_default ());
        theme.add_resource_path ("/co/tauos/Kairos/");

        provider = new Gtk.CssProvider ();

        weather_info = new GWeather.Info (location);
        weather_info.set_contact_info ("https://raw.githubusercontent.com/tau-OS/kairos/main/co.tauos.Kairos.doap");
        weather_info.set_enabled_providers (GWeather.Provider.METAR | GWeather.Provider.MET_NO | GWeather.Provider.OWM);
        set_style ();
        get_location.begin ();
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
            get_location.begin ();
        });

        search_entry.search_changed.connect (() => {

        });

        add_css_class ("window-bg");
        set_size_request (360, 150);
        stack.visible_child_name = "load";
    }

    public async void get_location () {
        try {
            var simple = yield new GClue.Simple.with_thresholds (Config.APP_ID, GClue.AccuracyLevel.CITY, 0, 100, null);

            if (simple.client != null && simple != null) {
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

        double appr;
        weather_info.get_value_apparent (GWeather.TemperatureUnit.DEFAULT, out appr);

        if (temphi != 0 && templo != 0) {
            temphilo = _("High: %.0f° / Low: %.0f°").printf (temphi, templo);
        } else {
            temphilo = _("Feels Like: %.0f°").printf (appr);
        }

        double win; GWeather.WindDirection windir;
        weather_info.get_value_wind (GWeather.SpeedUnit.DEFAULT, out win, out windir);
        wind = _("Wind:") + " " + "%.0f %s".printf(win, GWeather.SpeedUnit.DEFAULT.to_string ());
        double deew;
        weather_info.get_value_dew (GWeather.TemperatureUnit.DEFAULT, out deew);
        dew = _("Dew Point:") + " " + "%.0f°".printf(deew);

        kudos_label.label = weather_info.get_attribution ();

        switch (weather_icon.icon_name) {
            case "weather-clear-night-symbolic":
                color_primary = "#22262b";
                color_secondary = "#fafafa";
                graphic = "resource://co/tauos/Kairos/night.svg";
                break;
            case "weather-few-clouds-symbolic":
            case "weather-overcast-symbolic":
            case "weather-few-clouds-night-symbolic":
                color_primary = "#828292";
                color_secondary = "#fafafa";
                graphic = "resource://co/tauos/Kairos/cloudy.svg";
                break;
            case "weather-showers-symbolic":
            case "weather-showers-scattered-symbolic":
                color_primary = "#828292";
                color_secondary = "#fafafa";
                graphic = "resource://co/tauos/Kairos/rain.svg";
                break;
            case "weather-snow-symbolic":
                color_primary = "#fafcff";
                color_secondary = "#2d2d2d";
                graphic = "resource://co/tauos/Kairos/snow.svg";
                break;
            default:
                color_primary = "#58a8fa";
                color_secondary = "#fafafa";
                graphic = "resource://co/tauos/Kairos/sunny.svg";
                break;
        }

        string COLOR_PRIMARY = """
            .window-bg {
                background-image: url(%s);
                background-position: 50% 50%;
                background-repeat: repeat;
                background-color: %s;
                color: %s;
                transition: all 600ms ease-in-out;
            }
        """;

        var colored_css = COLOR_PRIMARY.printf (graphic, color_primary, color_secondary);
        provider.load_from_data ((uint8[])colored_css);
        this.get_style_context().add_provider(provider, 999);

        stack.visible_child_name = "weather";
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

    public void action_about () {
        var about = new He.AboutWindow (
            this,
            "Kairos",
            Config.APP_ID,
            Config.VERSION,
            Config.APP_ID,
            "https://github.com/tau-os/kairos/tree/main/po",
            "https://github.com/tau-os/kairos/issues/new",
            "https://github.com/tau-os/kairos",
            // TRANSLATORS: 'Name <email@domain.com>' or 'Name https://website.example'
            {},
            {"Lains"},
            2022,
            He.AboutWindow.Licenses.GPLv3,
            He.Colors.NONE
        );
        about.present ();
    }
}
