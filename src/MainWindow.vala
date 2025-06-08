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


public class Kairos.AddedLocationRow : Gtk.ListBoxRow {
    public Utils.ContentItem data { get; construct set; }
    public string? lname { get; set; default = null; }
    public string? location { get; set; default = null; }

    private GWeather.Location? current_geo_location = null;
    private bool geo_location_found = false;

    public Gtk.Box main_box;
    public He.Button loc_delete_button;
    public Gtk.Image loc_geo_icon;

    public AddedLocationRow (Utils.ContentItem data) {
        Object (data : data);

        lname = data.location.get_city_name ();
        location = data.location.get_country_name ();

        var loc_label = new Gtk.Label (lname);
        loc_label.halign = Gtk.Align.START;
        loc_label.add_css_class ("cb-title");
        var loc_ct_label = new Gtk.Label (location);
        loc_ct_label.halign = Gtk.Align.START;
        loc_ct_label.add_css_class ("cb-subtitle");
        loc_ct_label.add_css_class ("location-display");

        loc_geo_icon = new Gtk.Image.from_icon_name ("location-active-symbolic");
        loc_geo_icon.valign = Gtk.Align.START;
        loc_geo_icon.halign = Gtk.Align.START;
        loc_geo_icon.margin_end = 12;
        loc_geo_icon.visible = false; // Start hidden

        // Check if this is already marked as a geo location
        if (data.geo) {
            loc_geo_icon.visible = true;
            geo_location_found = true;
        } else {
            get_glocation ();
        }

        loc_delete_button = new He.Button ("user-trash-symbolic", "") {
            is_iconic = true
        };
        loc_delete_button.add_css_class ("block");
        loc_delete_button.add_css_class ("block-button");
        loc_delete_button.halign = Gtk.Align.END;
        loc_delete_button.hexpand = true;

        var loc_box = new Gtk.Box (Gtk.Orientation.VERTICAL, 0);
        loc_box.append (loc_label);
        loc_box.append (loc_ct_label);

        main_box = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 0);
        main_box.add_css_class ("mini-content-block");
        main_box.add_css_class ("block-row-child");
        main_box.append (loc_geo_icon);
        main_box.append (loc_box);
        main_box.append (loc_delete_button);

        this.set_child (main_box);
    }

    private void get_glocation () {
        get_gclue_simple.begin ((obj, res) => {
            var simple = get_gclue_simple.end (res);
            if (simple != null) {
                simple.notify["location"].connect (() => {
                    check_location_match (simple);
                });

                // Check immediately if location is already available
                if (simple.location != null) {
                    check_location_match (simple);
                }
            } else {
                warning ("Make sure location access is turned on in settings");
            }
        });
    }

    private void check_location_match (GClue.Simple simple) {
        if (simple.location == null)return;

        // Find nearest city to current GPS coordinates
        var world_loc = GWeather.Location.get_world ();
        if (world_loc == null)return;

        var nearest_city = world_loc.find_nearest_city (
                                                        simple.location.latitude,
                                                        simple.location.longitude
        );

        if (nearest_city != null) {
            current_geo_location = nearest_city;
            geo_location_found = true;

            // Check if this row's location matches the user's current location
            bool locations_match = are_locations_similar (data.location, nearest_city);

            if (locations_match) {
                loc_geo_icon.visible = true;
                data.geo = true; // Mark this location as geo-located
            } else {
                loc_geo_icon.visible = false;
                data.geo = false;
            }
        }
    }

    private bool are_locations_similar (GWeather.Location loc1, GWeather.Location loc2) {
        // First try exact equality
        if (loc1.equal (loc2)) {
            return true;
        }

        // Check if they're in the same country and timezone
        string? country1 = loc1.get_country ();
        string? country2 = loc2.get_country ();

        if (country1 != null && country2 != null && country1 == country2) {
            var tz1 = loc1.get_timezone ();
            var tz2 = loc2.get_timezone ();

            if (tz1 != null && tz2 != null) {
                string? tzid1 = tz1.get_identifier ();
                string? tzid2 = tz2.get_identifier ();

                if (tzid1 != null && tzid2 != null && tzid1 == tzid2) {
                    return true;
                }
            }
        }

        // Check if city names are the same (case-insensitive)
        string? city1 = loc1.get_city_name ();
        string? city2 = loc2.get_city_name ();

        if (city1 != null && city2 != null) {
            if (city1.down () == city2.down ()) {
                return true;
            }
        }

        // Check distance if both have coordinates
        if (loc1.has_coords () && loc2.has_coords ()) {
            double lat1, lon1, lat2, lon2;
            loc1.get_coords (out lat1, out lon1);
            loc2.get_coords (out lat2, out lon2);

            double distance = calculate_distance (lat1, lon1, lat2, lon2);
            // Consider locations within 50km as "similar" (same city area)
            return distance < 50.0;
        }

        return false;
    }

    private double calculate_distance (double lat1, double lon1, double lat2, double lon2) {
        const double EARTH_RADIUS = 6371.0; // km

        double dlat = Math.PI / 180.0 * (lat2 - lat1);
        double dlon = Math.PI / 180.0 * (lon2 - lon1);

        double a = Math.sin (dlat / 2) * Math.sin (dlat / 2)
            + Math.cos (Math.PI / 180.0 * lat1) * Math.cos (Math.PI / 180.0 * lat2)
            * Math.sin (dlon / 2) * Math.sin (dlon / 2);

        double c = 2 * Math.atan2 (Math.sqrt (a), Math.sqrt (1 - a));

        return EARTH_RADIUS * c;
    }

    private async GClue.Simple? get_gclue_simple () {
        try {
            var simple = yield new GClue.Simple ("com.fyralabs.Kairos", GClue.AccuracyLevel.CITY, null);
            return simple;
        } catch (Error e) {
            warning ("Failed to connect to GeoClue2 service: %s", e.message);
            return null;
        }
    }
}

[GtkTemplate (ui = "/com/fyralabs/Kairos/mainwindow.ui")]
public class Kairos.MainWindow : He.ApplicationWindow {
    public Utils.ContentStore locations;
    private GLib.Settings settings;
    public He.Application app { get; construct; }
    public SimpleActionGroup actions { get; construct; }
    public const string ACTION_PREFIX = "win.";
    public const string ACTION_ABOUT = "action_about";
    private const GLib.ActionEntry[] ACTION_ENTRIES = {
        { ACTION_ABOUT, action_about }
    };
    public static Gee.MultiMap<string, string> action_accelerators = new Gee.HashMultiMap<string, string> ();

    private AddedLocationRow? _selected_row = null;
    public AddedLocationRow? selected_row {
        get {
            return _selected_row;
        } set {
            _selected_row = value;
        }
    }

    [GtkChild]
    public unowned Bis.Carousel carousel;
    [GtkChild]
    public unowned Gtk.ListBox listbox2;
    [GtkChild]
    public unowned Gtk.Box main_box;
    [GtkChild]
    public unowned He.SideBar sidebar;
    [GtkChild]
    public unowned He.AppBar tb;
    [GtkChild]
    public unowned Gtk.MenuButton menu_button;
    [GtkChild]
    public unowned He.OverlayButton add_button;
    [GtkChild]
    public unowned He.EmptyPage empty_page;
    [GtkChild]
    public unowned Gtk.Stack stack;

    public MainWindow (He.Application application) {
        Object (
                app : application,
                application : application,
                icon_name: Config.APP_ID,
                title: _("Kairos")
        );
    }

    construct {
        settings = new GLib.Settings ("com.fyralabs.Kairos");
        // Actions
        actions = new SimpleActionGroup ();
        actions.add_action_entries (ACTION_ENTRIES, this);
        insert_action_group ("win", actions);

        foreach (var action in action_accelerators.get_keys ()) {
            var accels_array = action_accelerators[action].to_array ();
            accels_array += null;

            app.set_accels_for_action (ACTION_PREFIX + action, accels_array);
        }
        app.set_accels_for_action ("app.quit", { "<Ctrl>q" });
        app.set_accels_for_action ("win.action_keys", { "<Ctrl>question" });

        var theme = Gtk.IconTheme.get_for_display (Gdk.Display.get_default ());
        theme.add_resource_path ("/com/fyralabs/Kairos/");

        locations = new Utils.ContentStore ();
        locations.items_changed.connect ((position, removed, added) => {
            save ();
            stack.set_visible_child_name ("weather");
        });
        load ();
        use_geolocation.begin ((obj, res) => {
            use_geolocation.end (res);
        });

        listbox2.bind_model (locations, (data) => {
            var row = new AddedLocationRow ((Utils.ContentItem) data);
            var wp = new WeatherPage (this, row.data.location);
            wp.set_style (row.data.location);
            return row;
        });
        listbox2.select_row ((Gtk.ListBoxRow) listbox2.get_first_child ());

        set_size_request (360, 150);

        menu_button.get_popover ().has_arrow = false;

        empty_page.action_button.clicked.connect (() => {
            empty_button_clicked ();
        });
    }

    [GtkCallback]
    private void item_activated (Gtk.ListBoxRow? listbox_row) {
        var row = (AddedLocationRow) listbox_row;
        for (var car = 0; car <= carousel.get_n_pages (); car++) {
            if (locations.get_item (car) == row.data)
                carousel.scroll_to (carousel.get_nth_page (car), true);
        }

        row.loc_delete_button.clicked.connect (() => {
            for (var car = 0; car <= carousel.get_n_pages (); car++) {
                if (locations.get_item (car) == row.data)
                    carousel.remove (carousel.get_nth_page (car));
            }
            locations.remove (row.data);
            if (locations.get_n_items () == 0) {
                stack.set_visible_child_name ("empty");
                remove_css_class ("side-window-bg");
                menu_button.remove_css_class ("block-button");
                listbox2.remove_css_class ("block-row");
                sidebar.remove_css_class ("block-sidebar");
            }
        });
    }

    private void load () {
        locations.deserialize (settings.get_value ("locations"), Utils.ContentItem.deserialize);
        locations.foreach ((l) => {
            var wp = new WeatherPage (this, l.location);
            carousel.append (wp);
            // TODO Only need to queue what changed
            wp.queue_draw ();
        });
    }

    private void save () {
        settings.set_value ("locations", locations.serialize ());
    }

    private async void use_geolocation () {
        Utils.Geo.Info geo_info = new Utils.Geo.Info ();

        geo_info.location_changed.connect ((found_location) => {
            var item = (Utils.ContentItem?) locations.find ((l) => {
                return geo_info.is_location_similar (((Utils.ContentItem) l).location);
            });

            if (item != null) {
                return;
            }

            var wp = new WeatherPage (this, found_location);
            wp.set_style (found_location);
            add_found_location ((GWeather.Location) found_location);
            save ();
        });

        yield geo_info.seek ();
    }

    [GtkCallback]
    private void add_button_clicked () {
        var dialog = new WorldLocationFinder ((Gtk.Window) get_root (), this);

        dialog.location_added.connect (() => {
            var loc = dialog.get_selected_location ();
            if (loc != null)
                add_location ((GWeather.Location) loc);
            save ();

            dialog.destroy ();
        });
        dialog.present ();
    }

    private void empty_button_clicked () {
        var dialog = new WorldLocationFinder ((Gtk.Window) get_root (), this);

        dialog.location_added.connect (() => {
            var loc = dialog.get_selected_location ();
            if (loc != null)
                add_location ((GWeather.Location) loc);
            save ();

            dialog.destroy ();
        });
        dialog.present ();
    }

    private void add_location_item (Utils.ContentItem item) {
        locations.add (item);
        item.geo = false; // Regular manually-added location
        var wp = new WeatherPage (this, item.location);
        carousel.append (wp);
        save ();
    }

    private void add_found_location_item (Utils.ContentItem item) {
        locations.add_found (item);
        item.geo = true; // Mark as geo-located
        var wp = new WeatherPage (this, item.location);
        carousel.prepend (wp);
        save ();
    }

    public bool location_exists (GWeather.Location location) {
        var exists = false;
        var n = locations.get_n_items ();
        for (int i = 0; i < n; i++) {
            var l = (Utils.ContentItem) locations.get_object (i);
            if (l.location.equal (location)) {
                exists = true;
                break;
            }
        }

        return exists;
    }

    public void add_location (GWeather.Location location) {
        if (!location_exists (location)) {
            add_location_item (new Utils.ContentItem (location));
        }
    }

    public void add_found_location (GWeather.Location location) {
        if (!location_exists (location)) {
            add_found_location_item (new Utils.ContentItem (location));
        }
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
                                        { "Fyra Labs" },
                                        2023,
                                        He.AboutWindow.Licenses.GPLV3,
                                        He.Colors.BROWN
        );
        about.present ();
    }
}