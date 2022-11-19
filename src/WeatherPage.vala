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
    unowned He.MiniContentBlock temp_block;
    [GtkChild]
    unowned He.MiniContentBlock dew_block;
    [GtkChild]
    unowned He.MiniContentBlock wind_block;
    [GtkChild]
    unowned He.MiniContentBlock pressure_block;
    [GtkChild]
    unowned He.DisclosureButton refresh_button;
    
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
        
        ((Gtk.Box) wind_block.get_last_child ()).orientation = Gtk.Orientation.VERTICAL;
        ((Gtk.Box) temp_block.get_last_child ()).orientation = Gtk.Orientation.VERTICAL;
        ((Gtk.Box) dew_block.get_last_child ()).orientation = Gtk.Orientation.VERTICAL;
        ((Gtk.Box) pressure_block.get_last_child ()).orientation = Gtk.Orientation.VERTICAL;

        weather_info = new GWeather.Info (location);
        weather_info.set_contact_info ("https://raw.githubusercontent.com/tau-OS/kairos/main/co.tauos.Kairos.doap");
        weather_info.set_enabled_providers (GWeather.Provider.METAR | GWeather.Provider.MET_NO | GWeather.Provider.OWM);
        
        set_info (location);
        set_style (location);
        weather_info.update ();

        refresh_button.clicked.connect (() => {
            set_info (location);
            set_style (location);
            weather_info.update ();
        });
        
        weather_info.updated.connect (() => {
            set_info (location);
            this.notify["location"].connect (() => {
                set_style (location);
            });
            weather_info.update ();
        });

        car = win.carousel;
        win.carousel.page_changed.connect ((page) => {
            set_info (location);
            set_style (location);
            weather_info.update ();
        });
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
                color_primary = "#22262b";
                color_secondary = "#fafafa";
                graphic = "resource://co/tauos/Kairos/night.svg";
                break;
            case "weather-few-clouds-symbolic":
            case "weather-overcast-symbolic":
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
            background-size: cover;
            background-color: %s;
            color: %s;
            transition: all 600ms ease-in-out;
        }
        .block {
            background-color: alpha(%s, 0.1);
            color: %s;
            transition: all 600ms ease-in-out;
        }
        .side-window-bg {
            background-color: mix(@window_bg_color, %s, 0.02);
            transition: all 600ms ease-in-out;
        }
        """;
        
        var colored_css = COLOR_PRIMARY.printf (graphic, color_primary, color_secondary, color_secondary, color_secondary, color_primary);
        provider.load_from_data ((uint8[])colored_css);
        this.get_style_context().add_provider(provider, 999);
        temp_block.get_style_context().add_provider(provider, 999);
        wind_block.get_style_context().add_provider(provider, 999);
        dew_block.get_style_context().add_provider(provider, 999);
        pressure_block.get_style_context().add_provider(provider, 999);
        refresh_button.get_style_context().add_provider(provider, 999);
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
