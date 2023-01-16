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

[GtkTemplate (ui = "/co/tauos/Kairos/weatherpage.ui")]
public class Kairos.WeatherPage : He.Bin {
    private Gtk.CssProvider provider;
    private string color_primary = "";
    private string color_secondary = "";
    private string graphic = "";

    public Bis.Carousel car {get; set;}
    public GWeather.Info weather_info;
    public GWeather.Location location {get; construct;}
    public MainWindow win {get; construct;}
    public string dew {get; set;}
    public string pressure {get; set;}
    public string temphilo {get; set;}
    public string wind {get; set;}

    private const int ONE_HOUR = 60 * 60 * 1000 * 1000;
    private const int TWENTY_FOUR_HOURS = 24 * ONE_HOUR;

    private GLib.SList<weak GWeather.Info> hourly_info = new GLib.SList<weak GWeather.Info>();
    private bool has_forecast_info = false;
    
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
    unowned Gtk.Box timeline;
    [GtkChild]
    unowned He.MiniContentBlock temp_block;
    [GtkChild]
    unowned He.MiniContentBlock dew_block;
    [GtkChild]
    unowned He.MiniContentBlock wind_block;
    [GtkChild]
    unowned He.MiniContentBlock pressure_block;
    [GtkChild]
    unowned He.DisclosureButton refresh_button;
    [GtkChild]
    public unowned Bis.CarouselIndicatorDots lines;
    [GtkChild]
    unowned Gtk.Button search_button;
    [GtkChild]
    unowned Gtk.MenuButton menu_button;
    
    public WeatherPage (MainWindow win, GWeather.Location location) {
        Object (
            win: win,
            location: location
        );
    }
    
    construct {
        provider = new Gtk.CssProvider ();
        this.add_css_class ("window-bg");
        wind_block.add_css_class ("block");
        temp_block.add_css_class ("block");
        dew_block.add_css_class ("block");
        pressure_block.add_css_class ("block");
        refresh_button.add_css_class ("block");
        search_button.add_css_class ("block");
        menu_button.add_css_class ("block");
        
        ((Gtk.Box) wind_block.get_last_child ()).orientation = Gtk.Orientation.VERTICAL;
        ((Gtk.Box) temp_block.get_last_child ()).orientation = Gtk.Orientation.VERTICAL;
        ((Gtk.Box) dew_block.get_last_child ()).orientation = Gtk.Orientation.VERTICAL;
        ((Gtk.Box) pressure_block.get_last_child ()).orientation = Gtk.Orientation.VERTICAL;

        weather_info = new GWeather.Info (location);
        weather_info.set_contact_info ("https://raw.githubusercontent.com/tau-OS/kairos/main/co.tauos.Kairos.doap");
        weather_info.set_enabled_providers (GWeather.Provider.METAR | GWeather.Provider.MET_NO | GWeather.Provider.OWM);

        set_info (location);
        set_style (location);
        update_timeline (weather_info);
        weather_info.update ();

        refresh_button.clicked.connect (() => {
            set_info (location);
            set_style (location);
            update_timeline (weather_info);
            weather_info.update ();
        });
        
        weather_info.updated.connect (() => {
            set_info (location);
            set_style (location);
            update_timeline (weather_info);
            weather_info.update ();
        });

        car = win.carousel;
        win.carousel.page_changed.connect ((page) => {
            weather_info.update ();
        });

        search_button.clicked.connect (() => {
            win.stack.visible_child_name = "list";
            win.titlebar.show_back = true;
            win.titlebar.remove_css_class ("scrim");
        });

        has_forecast_info = false;
    }

    public GLib.SList<GWeather.Info> preprocess(GLib.DateTime now, GWeather.Info forecast_info, GLib.SList<weak GWeather.Info> infos) {
        GLib.SList<GWeather.Info> combo_info = new GLib.SList<GWeather.Info>();
        combo_info.append (forecast_info);
        foreach (var ib in infos) {
            combo_info.append (ib);
        }
        return combo_info;
    }
    public void add_hour_entry(GWeather.Info info, GLib.TimeZone tz, bool now) {
        string time_label; string time_format;
        long date; info.get_value_update(out date);
        var datetime = new GLib.DateTime.from_unix_utc(date).to_timezone(tz);

        if (now) {
            time_label = _("Now");
        } else {
            time_format = "%R";
            time_label = datetime.format(time_format);
        }

        var entry = new WeatherRow (info, time_label);
        timeline.append(entry);
    }

    public void update_timeline (GWeather.Info info) {
        var forecasts = info.get_forecast_list().copy ();
        var tz = location.get_timezone();
        var now = new GLib.DateTime.now(tz);

        GLib.SList<GWeather.Info> hourlyinfo = preprocess(now, info, forecasts);
        uint length = hourlyinfo.length ();
        if (length > 0 && has_forecast_info == false) {
            for (var i = 0; i < length; i++) {
                var inf = hourlyinfo.nth (i).data;
                var is_now = hourlyinfo.index(inf) == 0;
                if (hourlyinfo.index(inf) >= 12)
                    add_hour_entry (inf, tz, is_now);
                    has_forecast_info = true;
            }
        }

        this.hourly_info = hourlyinfo.copy ();
    }

    public void set_info (GWeather.Location? loc) {
        if (loc == null) {
            return;
        }
        
        location_label.label = dgettext ("libgweather-locations", loc.get_city_name ());
        
        weather_icon.icon_name = weather_info.get_symbolic_icon_name ();
        weather_label.label = dgettext ("libgweather", weather_info.get_sky ());
        
        double temp;
        weather_info.get_value_temp (GWeather.TemperatureUnit.DEFAULT, out temp);
        temp_label.label = _("%i°").printf ((int) temp);
        
        string appr = weather_info.get_temp_summary ();
        temphilo = _("%s").printf (appr);
        
        double windd; GWeather.WindDirection windir;
        weather_info.get_value_wind (GWeather.SpeedUnit.DEFAULT, out windd, out windir);
        wind = "%.0f %s".printf(windd, GWeather.SpeedUnit.DEFAULT.to_string ());
        string deew = weather_info.get_dew ();
        dew = "%s".printf(deew);
        
        string pres = weather_info.get_pressure ();
        pressure = _("%s").printf (pres);
        
        kudos_label.label = weather_info.get_attribution ();
    }

    public void set_style (GWeather.Location? loc) {
        switch (weather_info.get_symbolic_icon_name ()) {
            case "weather-clear-night-symbolic":
            case "weather-few-clouds-night-symbolic":
                color_primary = "#2d2d2d";
                color_secondary = "#fafafa";
                graphic = "resource://co/tauos/Kairos/night.svg";
                break;
            case "weather-few-clouds-symbolic":
            case "weather-overcast-symbolic":
            case "weather-fog-symbolic":
                color_primary = "#828292";
                color_secondary = "#fafafa";
                graphic = "resource://co/tauos/Kairos/cloudy.svg";
                break;
            case "weather-showers-symbolic":
            case "weather-showers-scattered-symbolic":
            case "weather-storm-symbolic":
                color_primary = "#828292";
                color_secondary = "#fafafa";
                graphic = "resource://co/tauos/Kairos/rain.svg";
                break;
            case "weather-snow-symbolic":
                color_primary = "#efefef";
                color_secondary = "#2d2d2d";
                graphic = "resource://co/tauos/Kairos/snow.svg";
                break;
            case "weather-clear-symbolic":
                color_primary = "#268ef9";
                color_secondary = "#f0f0f2";
                graphic = "resource://co/tauos/Kairos/sunny.svg";
                break;
            default:
                color_primary = "#f0f0f2";
                color_secondary = "#2d2d2d";
                graphic = "";
                break;
        }
        
        string COLOR_PRIMARY = """
        .window-bg {
            background-image: url(%s);
            background-position: 50% 50%;
            background-repeat: repeat;
            background-size: cover;
            background-color: %s;
            color: %s;
            transition: all 600ms ease-in-out;
        }
        .block {
            background: alpha(%s, 0.1);
            background-color: alpha(%s, 0.1);
            color: %s;
            transition: all 600ms ease-in-out;
        }
        .side-window-bg {
            background-color: mix(@window_bg_color, %s, 0.02);
            transition: all 600ms ease-in-out;
        }
        """;
        
        var colored_css = COLOR_PRIMARY.printf (graphic, color_primary, color_secondary, color_secondary, color_secondary, color_secondary, color_primary);
        provider.load_from_data ((uint8[])colored_css);
        this.get_style_context().add_provider(provider, 999);
        temp_block.get_style_context().add_provider(provider, 999);
        wind_block.get_style_context().add_provider(provider, 999);
        dew_block.get_style_context().add_provider(provider, 999);
        pressure_block.get_style_context().add_provider(provider, 999);
        refresh_button.get_style_context().add_provider(provider, 999);
        search_button.get_style_context().add_provider(provider, 999);
        menu_button.get_style_context().add_provider(provider, 999);
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
    [GtkCallback]
    string get_pressure_label () {
        return pressure;
    }
}
