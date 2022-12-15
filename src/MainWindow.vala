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

    public Gtk.Box main_box;
    public He.DisclosureButton loc_delete_button;

    public AddedLocationRow (Utils.ContentItem data) {
        Object (data: data);

        lname = data.location.get_city_name ();
        location = data.location.get_country_name ();

        var loc_label = new Gtk.Label (lname);
        loc_label.halign = Gtk.Align.START;
        loc_label.add_css_class ("cb-title");
        var loc_ct_label = new Gtk.Label (location);
        loc_ct_label.halign = Gtk.Align.START;
        loc_ct_label.add_css_class ("cb-subtitle");

        loc_delete_button = new He.DisclosureButton ("user-trash-symbolic");
        loc_delete_button.halign = Gtk.Align.END;
        loc_delete_button.hexpand = true;

        var loc_box = new Gtk.Box (Gtk.Orientation.VERTICAL, 0);
        loc_box.append (loc_label);
        loc_box.append (loc_ct_label);

        main_box = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 0);
        main_box.add_css_class ("mini-content-block");
        main_box.append (loc_box);
        main_box.append (loc_delete_button);

        this.set_child (main_box);
    }
}

[GtkTemplate (ui = "/co/tauos/Kairos/mainwindow.ui")]
public class Kairos.MainWindow : He.ApplicationWindow {
    public Utils.ContentStore locations;
    private GLib.Settings settings;
    public He.Application app {get; construct;}
    public SimpleActionGroup actions { get; construct; }
    public const string ACTION_PREFIX = "win.";
    public const string ACTION_ABOUT = "action_about";
    private const GLib.ActionEntry[] ACTION_ENTRIES = {
          {ACTION_ABOUT, action_about }
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
    unowned Gtk.Button search_button;
    [GtkChild]
    unowned Gtk.Stack stack;
    [GtkChild]
    unowned Gtk.ListBox listbox2;
    [GtkChild]
    unowned He.AppBar titlebar;

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
        settings = new GLib.Settings ("co.tauos.Kairos");
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

        search_button.clicked.connect (() => {
            stack.visible_child_name = "list";
            titlebar.show_back = true;
            titlebar.remove_css_class ("scrim");
            search_button.visible = false;
        });

        locations = new Utils.ContentStore ();
        locations.items_changed.connect ((position, removed, added) => {
            save ();
        });
        load ();
        use_geolocation.begin ((obj, res) => {
            use_geolocation.end (res);
        });

        listbox2.bind_model (locations, (data) => {
            return new AddedLocationRow ((Utils.ContentItem) data);
        });

        stack.notify["visible-child-name"].connect (() => {
            if (stack.visible_child_name == "main")
                titlebar.show_back = false;
                titlebar.add_css_class ("scrim");
                search_button.visible = true;
        });

        set_size_request (360, 150);
    }

    [GtkCallback]
    private void item_activated (Gtk.ListBoxRow listbox_row) {
        var row = (AddedLocationRow) listbox_row;

        row.loc_delete_button.clicked.connect (() => {
            for (var car = 0; car <= carousel.get_n_pages (); car++) {
                if (locations.get_item (car) == row.data)
                    carousel.remove (carousel.get_nth_page (car));
            }
            locations.remove (row.data);
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
            carousel.prepend (wp);
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

    private void add_location_item (Utils.ContentItem item) {
        locations.add (item);
        var wp = new WeatherPage (this, item.location);
        carousel.append (wp);
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
            He.Colors.BROWN
        );
        about.present ();
    }
}
