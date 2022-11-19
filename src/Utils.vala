namespace Kairos.Utils {
    public class ContentItem : GLib.Object {
        public string? name { get; set; }
        public GWeather.Location location { get; set; }
        public bool automatic { get; set; default = false; }

        public ContentItem (GWeather.Location location) {
            Object (location: location);
        }

        public void serialize (GLib.VariantBuilder builder) {
            if (!automatic) {
                builder.open (new GLib.VariantType ("a{sv}"));
                builder.add ("{sv}", "location", location.serialize ());
                builder.close ();
            }
        }
        public static ContentItem? deserialize (Variant location_variant) {
            GWeather.Location? location = null;
            string key;
            Variant val;
            var world = GWeather.Location.get_world ();
    
            if (world == null) {
                return null;
            }
    
            var iter = location_variant.iterator ();
            while (iter.next ("{sv}", out key, out val)) {
                if (key == "location") {
                    location = ((GWeather.Location) world).deserialize (val);
                }
            }
    
            if (location == null) {
                return null;
            } else if (((GWeather.Location) location).get_timezone_str () == null) {
                warning ("Invalid location “%s” – timezone unknown. Ignoring.",
                         ((GWeather.Location) location).get_name ());
                return null;
            } else {
                return new ContentItem ((GWeather.Location) location);
            }
        }
    }
    
    public class ContentStore : GLib.Object, GLib.ListModel {
        private ListStore store;
        private CompareDataFunc<ContentItem>? sort_func;
    
    
        public ContentStore () {
            store = new ListStore (typeof (ContentItem));
            store.items_changed.connect ((position, removed, added) => {
                items_changed (position, removed, added);
            });
        }
    
        public Type get_item_type () {
            return store.get_item_type ();
        }
    
        public uint get_n_items () {
            return store.get_n_items ();
        }
    
        public Object? get_item (uint position) {
            return store.get_item (position);
        }
    
        public void set_sorting (owned CompareDataFunc<ContentItem> sort) {
            sort_func = (owned) sort;
    
            // TODO: we should re-sort, but for now we only
            // set this before adding any item
            assert (store.get_n_items () == 0);
        }
    
        public void add (ContentItem item) {
            if (sort_func == null) {
                store.append (item);
            } else {
                store.insert_sorted (item, sort_func);
            }
        }
    
        public int get_index (ContentItem item) {
            int position = -1;
            var n = store.get_n_items ();
            for (int i = 0; i < n; i++) {
                var compared_item = (ContentItem) store.get_object (i);
                if (compared_item == item) {
                    position = i;
                    break;
                }
            }
            return position;
        }
    
        public void remove (ContentItem item) {
            var index = get_index (item);
            if (index != -1) {
                store.remove (index);
            }
        }
    
        public delegate void ForeachFunc (ContentItem item);
    
        public void foreach (ForeachFunc func) {
            var n = store.get_n_items ();
            for (int i = 0; i < n; i++) {
                func ((ContentItem) store.get_object (i));
            }
        }
    
        public delegate bool FindFunc (ContentItem item);
    
        public ContentItem? find (FindFunc func) {
            var n = store.get_n_items ();
            for (int i = 0; i < n; i++) {
                var item = (ContentItem) store.get_object (i);
                if (func (item)) {
                    return item;
                }
            }
            return null;
        }
    
        public void delete_item (ContentItem item) {
            var n = store.get_n_items ();
            for (int i = 0; i < n; i++) {
                var o = store.get_object (i);
                if (o == item) {
                    store.remove (i);
    
                    if (sort_func != null) {
                        store.sort (sort_func);
                    }
    
                    return;
                }
            }
        }
    
        public Variant serialize () {
            var builder = new GLib.VariantBuilder (new VariantType ("aa{sv}"));
            var n = store.get_n_items ();
            for (int i = 0; i < n; i++) {
                ((ContentItem) store.get_object (i)).serialize (builder);
            }
            return builder.end ();
        }
    
        public delegate ContentItem? DeserializeItemFunc (Variant v);
    
        public void deserialize (Variant variant, DeserializeItemFunc deserialize_item) {
            Variant item;
            var iter = variant.iterator ();
            while (iter.next ("@a{sv}", out item)) {
                ContentItem? i = deserialize_item (item);
                if (i != null) {
                    add ((ContentItem) i);
                }
            }
        }
    }

    public class Geo.Info : Object {
        public GClue.Location? geo_location { get; private set; default = null; }
    
        private GWeather.Location? found_location;
        private string? country_code;
        private GClue.Simple simple;
        private double minimal_distance;
    
        public signal void location_changed (GWeather.Location location);
    
        public Info () {
            country_code = null;
            found_location = null;
            minimal_distance = 1000.0d;
        }
    
        public async void seek () {
            try {
                simple = yield new GClue.Simple (Config.APP_ID, GClue.AccuracyLevel.CITY, null);
            } catch (Error e) {
                warning ("Failed to connect to GeoClue2 service: %s", e.message);
                return;
            }
    
            simple.notify["location"].connect (() => {
                on_location_updated.begin ();
            });
    
            on_location_updated.begin ();
        }
    
        public async void on_location_updated () {
            geo_location = simple.get_location ();
    
            yield seek_country_code ();
    
            yield search_locations ((GWeather.Location) GWeather.Location.get_world ());
    
            if (found_location != null) {
                location_changed ((GWeather.Location) found_location);
            }
        }
    
        private async void seek_country_code () requires (geo_location != null) {
            var location = new Geocode.Location (((GClue.Location) geo_location).latitude,
                                                    ((GClue.Location) geo_location).longitude);
            var reverse = new Geocode.Reverse.for_location (location);
    
            try {
                var place = yield reverse.resolve_async ();
    
                country_code = place.get_country_code ();
            } catch (Error e) {
                warning ("Failed to obtain country code: %s", e.message);
            }
        }
    
        private double deg_to_rad (double deg) {
            return Math.PI / 180.0d * deg;
        }
    
        private double get_distance (double latitude1, double longitude1, double latitude2, double longitude2) {
            const double EARTH_RADIUS = 6372.795d;
    
            double lat1 = deg_to_rad (latitude1);
            double lat2 = deg_to_rad (latitude2);
            double lon1 = deg_to_rad (longitude1);
            double lon2 = deg_to_rad (longitude2);
    
            return Math.acos (Math.cos (lat1) * Math.cos (lat2) * Math.cos (lon1 - lon2) +
                                Math.sin (lat1) * Math.sin (lat2)) * EARTH_RADIUS;
        }
    
        private async void search_locations (GWeather.Location location) requires (geo_location != null) {
            if (this.country_code != null) {
                string? loc_country_code = location.get_country ();
                if (loc_country_code != null) {
                    if (loc_country_code != this.country_code) {
                        return;
                    }
                }
            }
    
            var loc = location.next_child (null);
            while (loc != null) {
                if (loc.get_level () == GWeather.LocationLevel.CITY) {
                    if (loc.has_coords ()) {
                        double latitude, longitude, distance;
    
                        loc.get_coords (out latitude, out longitude);
                        distance = get_distance (((GClue.Location) geo_location).latitude,
                                                    ((GClue.Location) geo_location).longitude,
                                                    latitude,
                                                    longitude);
    
                        if (distance < minimal_distance) {
                            found_location = loc;
                            minimal_distance = distance;
                        }
                    }
                }
    
                yield search_locations (loc);
                loc = location.next_child (loc);
            }
        }
    
        public bool is_location_similar (GWeather.Location location) {
            if (this.found_location != null) {
                var country_code = location.get_country ();
                var found_country_code = ((GWeather.Location) found_location).get_country ();
                if (country_code != null && country_code == found_country_code) {
                    var timezone = location.get_timezone ();
                    var found_timezone = ((GWeather.Location) found_location).get_timezone ();
    
                    if (timezone != null && found_timezone != null) {
                        var tzid = timezone.get_identifier ();
                        var found_tzid = found_timezone.get_identifier ();
                        if (tzid == found_tzid) {
                            return true;
                        }
                    }
                }
            }
    
            return false;
        }
    }
}
