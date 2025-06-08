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

[GtkTemplate (ui = "/com/fyralabs/Kairos/weatherpage.ui")]
public class Kairos.WeatherPage : He.Bin {
    public Bis.Carousel car { get; set; }
    public GWeather.Info weather_info;
    public GWeather.Location location { get; construct; }
    public MainWindow win { get; construct; }
    public string dew { get; set; }
    public string pressure { get; set; }
    public string temphilo { get; set; }
    public string wind { get; set; }

    private const int ONE_HOUR = 60 * 60 * 1000 * 1000;
    private const int TWENTY_FOUR_HOURS = 24 * ONE_HOUR;

    private GLib.SList<weak GWeather.Info> hourly_info = new GLib.SList<weak GWeather.Info> ();
    private bool has_forecast_info = false;

    [GtkChild]
    unowned Gtk.Image weather_icon;
    [GtkChild]
    unowned Gtk.Label weather_label;
    [GtkChild]
    unowned Gtk.Label temp_label;
    [GtkChild]
    unowned Gtk.Label kudos_label;
    [GtkChild]
    unowned Gtk.Box timeline;
    [GtkChild]
    unowned Gtk.Box humidity_timeline;
    [GtkChild]
    unowned Gtk.Box graph;
    [GtkChild]
    unowned Gtk.Box sunrise_sunset;
    [GtkChild]
    public unowned Gtk.DrawingArea da_sun;
    [GtkChild]
    unowned He.Button refresh_button;

    public WeatherPage (MainWindow win, GWeather.Location location) {
        Object (
                win: win,
                location: location
        );
    }

    construct {
        win.add_css_class ("side-window-bg");
        refresh_button.add_css_class ("block-button");
        win.menu_button.add_css_class ("block-button");
        win.listbox2.add_css_class ("block-row");
        win.sidebar.add_css_class ("block-sidebar");

        weather_info = new GWeather.Info (location) {
            contact_info = "https://raw.githubusercontent.com/tau-OS/kairos/main/com.fyralabs.Kairos.doap",
            enabled_providers = METAR | MET_NO
        };

        set_info (location);
        weather_info.update ();
        set_style (location);

        refresh_button.clicked.connect (() => {
            set_info (location);
            set_style (location);
            update_timeline (weather_info);
            weather_info.update ();
        });

        weather_info.updated.connect (() => {
            set_info (location);
            update_timeline (weather_info);
            weather_info.update ();
        });

        car = win.carousel;
        car.page_changed.connect ((page) => {
            set_info (location);
            set_style (location);
            update_timeline (weather_info);
            weather_info.update ();
        });

        has_forecast_info = false;
    }

    public GLib.SList<GWeather.Info> preprocess (GLib.DateTime now,
                                                 GWeather.Info forecast_info,
                                                 GLib.SList<weak GWeather.Info> infos) {
        GLib.SList<GWeather.Info> combo_info = new GLib.SList<GWeather.Info> ();
        combo_info.append (forecast_info);
        foreach (var ib in infos) {
            combo_info.append (ib);
        }
        return combo_info;
    }

    public void add_hour_entry (GWeather.Info info, bool now, bool is_current_weather = false) {
        string time_label; string time_format;
        long date; info.get_value_update (out date);
        var datetime = new GLib.DateTime.from_unix_utc (date).to_local ();

        if (now) {
            time_label = _("Now");
        } else {
            time_format = "%R";
            time_label = datetime.format (time_format);
        }

        var entry = new WeatherRow (info, time_label, is_current_weather);
        timeline.append (entry);
    }

    public void add_humidity_entry (GWeather.Info info, bool now) {
        string time_label; string time_format;
        long date; info.get_value_update (out date);
        var datetime = new GLib.DateTime.from_unix_utc (date).to_local ();

        if (now) {
            time_label = _("Now");
        } else {
            time_format = "%R";
            time_label = datetime.format (time_format);
        }

        var entry = new WeatherHumidityRow (info, time_label);
        humidity_timeline.append (entry);
    }

    public void add_graph (GLib.SList<GWeather.Info> hourlyinfo) {
        var entry = new WeatherGraph (hourlyinfo);
        graph.prepend (entry);
    }

    public void add_sun_graph (WeatherPage wp, DateTime sunrise, DateTime sunset) {
        var entry = new SunGraph (wp, sunrise, sunset);
        sunrise_sunset.prepend (entry);
    }

    public void update_timeline (GWeather.Info info) {
        var forecasts = info.get_forecast_list ().copy ();
        var now = new GLib.DateTime.now_local ();

        GLib.SList<GWeather.Info> hourlyinfo = preprocess (now, info, forecasts);
        uint length = hourlyinfo.length ();

        if (length > 1 && has_forecast_info == false) {
            // Safely iterate through available data with bounds checking
            uint max_items = uint.min (length, 25); // Don't exceed available data or 25 items

            for (var i = 0; i < max_items; i++) {
                var inf = hourlyinfo.nth_data (i);
                if (inf != null) {
                    // Index 0 is current weather ("Now"), rest are future forecasts
                    bool is_now = (i == 0);

                    // Only add if we have valid temperature data
                    var temp_str = inf.get_temp ();
                    if (temp_str != null && temp_str.length > 0 && temp_str != "0") {
                        add_hour_entry (inf, is_now, is_now); // Pass is_now as is_current_weather too
                        add_humidity_entry (inf, is_now);
                    }
                }
            }

            // Only add graph if we have sufficient data
            if (hourlyinfo.length () >= 3) {
                add_graph (hourlyinfo);
            }

            has_forecast_info = true;

            // Sunrise & Sunset with validation
            ulong sunrise;
            bool has_sunrise = info.get_value_sunrise (out sunrise);
            ulong sunset;
            bool has_sunset = info.get_value_sunset (out sunset);

            if (has_sunrise && has_sunset && sunrise > 0 && sunset > 0) {
                var sunrise_time = new GLib.DateTime.from_unix_local ((int64) sunrise);
                var sunset_time = new GLib.DateTime.from_unix_local ((int64) sunset);

                // Validate sunrise/sunset times are reasonable
                if (sunrise_time != null && sunset_time != null &&
                    sunset_time.compare (sunrise_time) > 0) {
                    add_sun_graph (this, sunrise_time, sunset_time);
                }
            }
        }

        this.hourly_info = hourlyinfo.copy ();
    }

    public void set_info (GWeather.Location? loc) {
        if (loc == null) {
            return;
        }

        weather_icon.icon_name = weather_info.get_symbolic_icon_name ().replace ("-symbolic", "");
        weather_label.label = dgettext ("libgweather", weather_info.get_sky ());

        temp_label.label = _("%s").printf (weather_info.get_temp_summary ());

        temphilo = weather_info.get_temp_summary ();

        wind = "%s".printf (weather_info.get_wind ());
        dew = "%s".printf (weather_info.get_dew ());
        pressure = _("%s").printf (weather_info.get_pressure ());

        kudos_label.label = weather_info.get_attribution ();
    }

    public void set_style (GWeather.Location? loc) {
        if (loc == null) {
            return;
        }

        switch (weather_info.get_symbolic_icon_name ()) {
        case "weather-clear-night-symbolic" :
        case "weather-few-clouds-night-symbolic" :
            css_classes = { "night" };
            break;
        case "weather-few-clouds-symbolic":
        case "weather-overcast-symbolic":
        case "weather-fog-symbolic":
            css_classes = { "cloudy" };
            break;
        case "weather-showers-symbolic":
        case "weather-showers-scattered-symbolic":
        case "weather-storm-symbolic":
            css_classes = { "showers" };
            break;
        case "weather-snow-symbolic":
            css_classes = { "snow" };
            break;
        default:
            css_classes = { "day" };
            break;
        }
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
        return (_("Feels like ")) + temphilo;
    }

    [GtkCallback]
    string get_pressure_label () {
        return pressure;
    }
}