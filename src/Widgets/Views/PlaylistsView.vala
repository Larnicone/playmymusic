/*-
 * Copyright (c) 2017-2017 Artem Anufrij <artem.anufrij@live.de>
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU Lesser General Public License as published by
 * the Free Software Foundation, either version 2 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU Lesser General Public License for more details.
 *
 * You should have received a copy of the GNU Lesser General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/>.
 *
 * The Noise authors hereby grant permission for non-GPL compatible
 * GStreamer plugins to be used and distributed together with GStreamer
 * and Noise. This permission is above and beyond the permissions granted
 * by the GPL license by which Noise is covered. If you modify this code
 * you may extend this exception to your version of the code, but you are not
 * obligated to do so. If you do not wish to do so, delete this exception
 * statement from your version.
 *
 * Authored by: Artem Anufrij <artem.anufrij@live.de>
 */

namespace PlayMyMusic.Widgets.Views {
    public class PlaylistsView : Gtk.Grid {
        PlayMyMusic.Services.LibraryManager library_manager;
        PlayMyMusic.Settings settings;

        private string _filter = "";
        public string filter {
            get {
                return _filter;
            } set {
                if (_filter != value) {
                    _filter = value;
                    playlists.invalidate_filter ();
                }
            }
        }

        Gtk.FlowBox playlists;
        Gtk.Stack stack;
        Gtk.Popover new_playlist_popover;
        Gtk.Entry new_playlist_entry;
        Gtk.Button new_playlist_save;

        construct {
            settings = PlayMyMusic.Settings.get_default ();
            library_manager = PlayMyMusic.Services.LibraryManager.instance;
            library_manager.added_new_playlist.connect ((playlist) => {
                add_playlist (playlist);
                stack.set_visible_child_name ("content");
            });
            library_manager.removed_playlist.connect ((playlist) => {
                remove_playlist (playlist);
            });
            library_manager.player_state_changed.connect ((state) => {
                if (state == Gst.State.PLAYING && library_manager.player.play_mode == PlayMyMusic.Services.PlayMode.PLAYLIST) {
                    activate_by_track (library_manager.player.current_track);
                }
            });
        }

        public PlaylistsView () {
            build_ui ();
        }

        private void build_ui () {
            playlists = new Gtk.FlowBox ();
            playlists.margin = 24;
            playlists.margin_bottom = 0;
            playlists.halign = Gtk.Align.START;
            playlists.selection_mode = Gtk.SelectionMode.NONE;
            playlists.column_spacing = 24;
            playlists.set_sort_func (playlists_sort_func);
            playlists.set_filter_func (playlists_filter_func);
            playlists.homogeneous = true;

            var playlists_scroll = new Gtk.ScrolledWindow (null, null);
            playlists_scroll.add (playlists);

            var action_toolbar = new Gtk.ActionBar ();
            action_toolbar.get_style_context().add_class(Gtk.STYLE_CLASS_INLINE_TOOLBAR);

            var add_button = new Gtk.Button.from_icon_name ("list-add-symbolic");
            add_button.tooltip_text = _("Add a playlist");
            add_button.clicked.connect (() => {
                new_playlist_popover.set_relative_to (add_button);
                new_playlist_entry.text = "";
                new_playlist_save.sensitive = false;
                new_playlist_popover.show_all ();
            });
            action_toolbar.pack_start (add_button);

            new_playlist_popover = new Gtk.Popover (null);

            var new_playlist = new Gtk.Grid ();
            new_playlist.row_spacing = 6;
            new_playlist.column_spacing = 12;
            new_playlist.margin = 12;
            new_playlist_popover.add (new_playlist);

            new_playlist_entry = new Gtk.Entry ();
            new_playlist_save = new Gtk.Button.with_label (_("Add"));
            new_playlist_save.get_style_context ().add_class(Gtk.STYLE_CLASS_SUGGESTED_ACTION);
            new_playlist_save.sensitive = false;

            new_playlist_entry.changed.connect (() => {
                new_playlist_save.sensitive = valid_new_playlist ();
            });
            new_playlist_entry.key_press_event.connect ((key) => {
                if ((key.keyval == Gdk.Key.Return || key.keyval == Gdk.Key.KP_Enter) && Gdk.ModifierType.CONTROL_MASK in key.state && valid_new_playlist ()) {
                    save_new_playlist ();
                }
                return false;
            });
            new_playlist.attach (new_playlist_entry, 0, 0);

            new_playlist_save.clicked.connect (() => {
                save_new_playlist ();
            });
            new_playlist.attach (new_playlist_save, 0, 1);

            var welcome = new Granite.Widgets.Welcome (_("No Playlists"), _("Add playlist to your library."));
            welcome.append ("document-new", _("Add Playlist"), _("Add a playlist for manage your favorite songs."));
            welcome.activated.connect ((index) => {
                switch (index) {
                    case 0:
                        new_playlist_popover.set_relative_to (welcome.get_button_from_index (index));
                        new_playlist_popover.show_all ();
                        break;
                }
            });

            var content = new Gtk.Box (Gtk.Orientation.VERTICAL, 0);
            content.expand = true;
            content.pack_start (playlists_scroll, true, true, 0);
            content.pack_end (action_toolbar, false, false, 0);

            stack = new Gtk.Stack ();
            stack.add_named (welcome, "welcome");
            stack.add_named (content, "content");

            this.add (stack);
            this.show_all ();

            show_playlists_from_database.begin ();
        }

        private void save_new_playlist () {
            var playlist = new PlayMyMusic.Objects.Playlist ();
            playlist.title = new_playlist_entry.text.strip ();
            library_manager.db_manager.insert_playlist (playlist);
            new_playlist_popover.hide ();
        }

        private bool valid_new_playlist () {
            string new_title = new_playlist_entry.text.strip ();
            return new_title != "" && library_manager.db_manager.get_playlist_by_title (new_title) == null;
        }

        private void add_playlist (PlayMyMusic.Objects.Playlist playlist) {
            var p = new Widgets.Views.PlaylistView (playlist);
            playlist.updated.connect (() => {
                playlists.invalidate_sort ();
            });
            p.show_all ();
            playlists.min_children_per_line = library_manager.playlists.length ();
            playlists.max_children_per_line = playlists.min_children_per_line;
            playlists.add (p);
        }

        private void remove_playlist (PlayMyMusic.Objects.Playlist playlist) {
            foreach (var child in playlists.get_children ()) {
                if ((child as Widgets.Views.PlaylistView).playlist.ID == playlist.ID) {
                    playlists.remove (child);
                    child.destroy ();
                    playlists.min_children_per_line = library_manager.playlists.length ();
                    playlists.max_children_per_line = playlists.min_children_per_line;
                }
            }

            if (playlists.get_children ().length () == 0) {
                stack.set_visible_child_name ("welcome");
            }
        }

        public void activate_by_track (Objects.Track track) {
            activate_by_id (track.playlist.ID);
        }

        public Objects.Playlist? activate_by_id (int id) {
            foreach (var child in playlists.get_children ()) {
                if ((child as Widgets.Views.PlaylistView).playlist.ID == id) {
                    (child as Widgets.Views.PlaylistView).mark_playing_track (library_manager.player.current_track);
                    return (child as Widgets.Views.PlaylistView).playlist;
                }
            }
            return null;
        }

        private async void show_playlists_from_database () {
            foreach (var playlist in library_manager.playlists) {
                add_playlist (playlist);
            }

            if (playlists.get_children ().length () > 0) {
                stack.set_visible_child_name ("content");
            }
        }

        private int playlists_sort_func (Gtk.FlowBoxChild child1, Gtk.FlowBoxChild child2) {
            var item1 = (PlayMyMusic.Widgets.Views.PlaylistView)child1;
            var item2 = (PlayMyMusic.Widgets.Views.PlaylistView)child2;
            if (item1 != null && item2 != null) {
                return item1.title.collate (item2.title);
            }
            return 0;
        }

         private bool playlists_filter_func (Gtk.FlowBoxChild child) {
            if (filter.strip ().length == 0) {
                return true;
            }

            string[] filter_elements = filter.strip ().down ().split (" ");
            var playlist = (child as PlayMyMusic.Widgets.Views.PlaylistView).playlist;
            foreach (string filter_element in filter_elements) {
                if (!playlist.title.down ().contains (filter_element)) {
                    bool track_title = false;
                    foreach (var track in playlist.tracks) {
                        if (track.title.down ().contains (filter_element) || track.album.title.down ().contains (filter_element) || track.album.artist.name.down ().contains (filter_element)) {
                            track_title = true;
                        }
                    }
                    if (track_title) {
                        continue;
                    }
                    return false;
                }
            }
            return true;
        }
    }
}
