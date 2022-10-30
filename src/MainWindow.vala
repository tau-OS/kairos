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

public class MainWindow : He.ApplicationWindow {
    private Gtk.Stack stack;
    private GWeather.Location location;
    private GWeather.Info weather_info;
    public He.Application app {get; construct;}
    private Gtk.CssProvider provider;
    private string color_primary = "#58a8fa";
    private string color_secondary = "#fafafa";

    private Gtk.Label location_label;
    private Gtk.Image weather_icon;
    private Gtk.Label weather_label;
    private Gtk.Label temp_label;
    private Gtk.Label dew_label;
    private Gtk.Label wind_label;

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
        weather_info.set_enabled_providers (GWeather.Provider.ALL);
        weather_info.update ();

        weather_icon = new Gtk.Image.from_icon_name (weather_info.get_symbolic_icon_name ());
        weather_icon.pixel_size = 64;

        temp_label = new Gtk.Label (weather_info.get_temp ());
        temp_label.halign = Gtk.Align.START;
        temp_label.add_css_class ("display");

        weather_label = new Gtk.Label (weather_info.get_sky ());
        weather_label.halign = Gtk.Align.END;
        weather_label.hexpand = true;
        weather_label.add_css_class ("cb-title");

        location_label = new Gtk.Label ("");
        location_label.halign = Gtk.Align.END;
        location_label.add_css_class ("cb-subtitle");

        wind_label = new Gtk.Label (_("Wind:") + " " + weather_info.get_wind ());
        wind_label.halign = Gtk.Align.END;
        wind_label.add_css_class ("caption");

        dew_label = new Gtk.Label (_("Dew Point:") + " " + weather_info.get_dew ());
        dew_label.halign = Gtk.Align.END;
        dew_label.add_css_class ("caption");

        var grid = new Gtk.Grid ();
        grid.column_spacing = 6;
        grid.row_spacing = 12;
        grid.valign = Gtk.Align.CENTER;
        grid.margin_bottom = grid.margin_start = grid.margin_end = 18;
        grid.attach (weather_icon, 0, 0, 1, 2);
        grid.attach (temp_label, 1, 0, 1, 2);
        grid.attach (weather_label, 2, 0, 1, 1);
        grid.attach (location_label, 2, 1, 1, 1);
        grid.attach (wind_label, 2, 2, 1, 1);
        grid.attach (dew_label, 2, 3, 1, 1);

        var spinner = new Gtk.Spinner ();
        spinner.spinning = true;
        spinner.halign = spinner.valign = Gtk.Align.CENTER;
        spinner.vexpand = true;

        var alert_label = new He.EmptyPage ();
        alert_label.margin_bottom = alert_label.margin_start = alert_label.margin_end = 18;
        alert_label.title = _("Unable To Get Weather Info");
        alert_label.description = _("Refresh location to see weather info.");
        alert_label.icon = "location-services-disabled-symbolic";
        alert_label.button = _("Refresh Location");

        alert_label.action_button.clicked.connect(() => {
            set_style ();
            get_location.begin ();
            weather_info.update ();
        });

        stack = new Gtk.Stack () {
            transition_type = Gtk.StackTransitionType.CROSSFADE,
            vhomogeneous = true,
            vexpand = true
        };
        stack.add_named (spinner, "load");
        stack.add_named (grid, "weather");
        stack.add_named (alert_label, "alert");

        var appbar = new He.AppBar ();
        appbar.show_buttons = true;
        appbar.show_back = false;
        appbar.flat = true;

        var refresh_button = new He.IconicButton ("view-refresh-symbolic");
        appbar.append (refresh_button);

        var main_box = new Gtk.Box (Gtk.Orientation.VERTICAL, 0);
        main_box.append (appbar);
        main_box.append (stack);

        set_child (main_box);
        set_size_request (360, 150);

        refresh_button.clicked.connect (() => {
            set_style ();
            get_location.begin ();
            weather_info.update ();
        });

        weather_info.updated.connect (() => {
            set_style ();
        });

        this.add_css_class ("window-bg");
    }

    public async void get_location () {
        try {
            var simple = yield new GClue.Simple.with_thresholds.end(Config.APP_ID, GClue.AccuracyLevel.CITY, 0, 1000, null);

            if (simple.client != null && simple != null) {
                var client = simple.get_client();
                client.distance_threshold = 1000;

                simple.notify["location"].connect (() => {
                    on_location_updated (simple);
                });

                on_location_updated (simple);
            }
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

        wind_label.label = _("Wind:") + " " + weather_info.get_wind ();
        dew_label.label = _("Dew Point:") + " " + weather_info.get_dew ();

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
                color_primary = "#6a6a6f";
                color_secondary = "#fafafa";
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
}
