#include "my_application.h"

#include <flutter_linux/flutter_linux.h>
#ifdef GDK_WINDOWING_X11
#include <gdk/gdkx.h>
#endif

#include "flutter/generated_plugin_registrant.h"

struct _MyApplication {
  GtkApplication parent_instance;
  char** dart_entrypoint_arguments;
};

G_DEFINE_TYPE(MyApplication, my_application, GTK_TYPE_APPLICATION)

// Called when first Flutter frame received.
static void first_frame_cb(MyApplication* self, FlView* view) {
  gtk_widget_show(gtk_widget_get_toplevel(GTK_WIDGET(view)));
}

static gchar* get_window_state_file_path() {
  const gchar* config_dir = g_get_user_config_dir();
  gchar* app_config_dir = g_build_filename(config_dir, "quitepaper", nullptr);
  g_mkdir_with_parents(app_config_dir, 0755);
  gchar* file_path = g_build_filename(app_config_dir, "window_state.json", nullptr);
  g_free(app_config_dir);
  return file_path;
}

static void save_window_state(GtkWindow* window) {
  gchar* path = get_window_state_file_path();
  gboolean is_maximized = gtk_window_is_maximized(window);
  gint width = 1280;
  gint height = 720;
  if (!is_maximized) {
    gtk_window_get_size(window, &width, &height);
  }
  gchar* contents = g_strdup_printf("{\"width\": %d, \"height\": %d, \"is_maximized\": %s}\n",
                                    width, height, is_maximized ? "true" : "false");
  g_file_set_contents(path, contents, -1, nullptr);
  g_free(contents);
  g_free(path);
}

static void load_window_state(GtkWindow* window) {
  gchar* path = get_window_state_file_path();
  gchar* contents = nullptr;
  if (g_file_get_contents(path, &contents, nullptr, nullptr)) {
    gint width = 1280;
    gint height = 720;
    gboolean is_maximized = FALSE;
    if (strstr(contents, "\"is_maximized\": true") != nullptr) {
      is_maximized = TRUE;
    }
    const gchar* w_ptr = strstr(contents, "\"width\":");
    const gchar* h_ptr = strstr(contents, "\"height\":");
    if (w_ptr != nullptr && sscanf(w_ptr, "\"width\": %d", &width) == 1) {
      if (width < 400) width = 1280;
    }
    if (h_ptr != nullptr && sscanf(h_ptr, "\"height\": %d", &height) == 1) {
      if (height < 300) height = 720;
    }
    gtk_window_set_default_size(window, width, height);
    if (is_maximized) {
      gtk_window_maximize(window);
    }
    g_free(contents);
  } else {
    gtk_window_set_default_size(window, 1280, 720);
  }
  g_free(path);
}

static gboolean on_window_delete_event(GtkWidget* widget, GdkEvent* event, gpointer data) {
  save_window_state(GTK_WINDOW(widget));
  return FALSE;
}

// Implements GApplication::activate.
static void my_application_activate(GApplication* application) {
  MyApplication* self = MY_APPLICATION(application);

  // Present and raise existing window if application is already active (single instance)
  GList* windows = gtk_application_get_windows(GTK_APPLICATION(application));
  if (windows != nullptr) {
    GtkWindow* existing_window = GTK_WINDOW(windows->data);
    gtk_window_present(existing_window);
    return;
  }

  GtkWindow* window =
      GTK_WINDOW(gtk_application_window_new(GTK_APPLICATION(application)));

  // Use a header bar when running in GNOME as this is the common style used
  // by applications and is the setup most users will be using (e.g. Ubuntu
  // desktop).
  // If running on X and not using GNOME then just use a traditional title bar
  // in case the window manager does more exotic layout, e.g. tiling.
  // If running on Wayland assume the header bar will work (may need changing
  // if future cases occur).
  gboolean use_header_bar = TRUE;
#ifdef GDK_WINDOWING_X11
  GdkScreen* screen = gtk_window_get_screen(window);
  if (GDK_IS_X11_SCREEN(screen)) {
    const gchar* wm_name = gdk_x11_screen_get_window_manager_name(screen);
    if (g_strcmp0(wm_name, "GNOME Shell") != 0) {
      use_header_bar = FALSE;
    }
  }
#endif
  if (use_header_bar) {
    GtkHeaderBar* header_bar = GTK_HEADER_BAR(gtk_header_bar_new());
    gtk_widget_show(GTK_WIDGET(header_bar));
    gtk_header_bar_set_title(header_bar, "Quiet Paper");
    gtk_header_bar_set_show_close_button(header_bar, TRUE);
    gtk_window_set_titlebar(window, GTK_WIDGET(header_bar));
    // Synchronize GTK HeaderBar title with Window title set by Flutter
    g_object_bind_property(window, "title", header_bar, "title", G_BINDING_DEFAULT);
  } else {
    gtk_window_set_title(window, "Quiet Paper");
  }

  // Load persisted window geometry (width, height, is_maximized)
  load_window_state(window);

  // Persist window geometry when closed
  g_signal_connect(window, "delete-event", G_CALLBACK(on_window_delete_event), nullptr);

  // Set window icon
  g_autoptr(GError) icon_error = nullptr;
  gtk_window_set_icon_from_file(window, "data/flutter_assets/assets/icons/icon.png", &icon_error);
  if (icon_error != nullptr) {
    g_clear_error(&icon_error);
    gtk_window_set_icon_from_file(window, "assets/icons/icon.png", nullptr);
  }

  g_autoptr(FlDartProject) project = fl_dart_project_new();
  fl_dart_project_set_dart_entrypoint_arguments(
      project, self->dart_entrypoint_arguments);

  FlView* view = fl_view_new(project);
  GdkRGBA background_color;
  // Background defaults to black, override it here if necessary, e.g. #00000000
  // for transparent.
  gdk_rgba_parse(&background_color, "#000000");
  fl_view_set_background_color(view, &background_color);
  gtk_widget_show(GTK_WIDGET(view));
  gtk_container_add(GTK_CONTAINER(window), GTK_WIDGET(view));

  // Show the window when Flutter renders.
  // Requires the view to be realized so we can start rendering.
  g_signal_connect_swapped(view, "first-frame", G_CALLBACK(first_frame_cb),
                           self);
  gtk_widget_realize(GTK_WIDGET(view));

  fl_register_plugins(FL_PLUGIN_REGISTRY(view));

  gtk_widget_grab_focus(GTK_WIDGET(view));
}

// Implements GApplication::local_command_line.
static gboolean my_application_local_command_line(GApplication* application,
                                                  gchar*** arguments,
                                                  int* exit_status) {
  MyApplication* self = MY_APPLICATION(application);
  // Strip out the first argument as it is the binary name.
  self->dart_entrypoint_arguments = g_strdupv(*arguments + 1);

  g_autoptr(GError) error = nullptr;
  if (!g_application_register(application, nullptr, &error)) {
    g_warning("Failed to register: %s", error->message);
    *exit_status = 1;
    return TRUE;
  }

  g_application_activate(application);
  *exit_status = 0;

  return TRUE;
}

// Implements GApplication::startup.
static void my_application_startup(GApplication* application) {
  // MyApplication* self = MY_APPLICATION(object);

  // Perform any actions required at application startup.

  G_APPLICATION_CLASS(my_application_parent_class)->startup(application);
}

// Implements GApplication::shutdown.
static void my_application_shutdown(GApplication* application) {
  // MyApplication* self = MY_APPLICATION(object);

  // Perform any actions required at application shutdown.

  G_APPLICATION_CLASS(my_application_parent_class)->shutdown(application);
}

// Implements GObject::dispose.
static void my_application_dispose(GObject* object) {
  MyApplication* self = MY_APPLICATION(object);
  g_clear_pointer(&self->dart_entrypoint_arguments, g_strfreev);
  G_OBJECT_CLASS(my_application_parent_class)->dispose(object);
}

static void my_application_class_init(MyApplicationClass* klass) {
  G_APPLICATION_CLASS(klass)->activate = my_application_activate;
  G_APPLICATION_CLASS(klass)->local_command_line =
      my_application_local_command_line;
  G_APPLICATION_CLASS(klass)->startup = my_application_startup;
  G_APPLICATION_CLASS(klass)->shutdown = my_application_shutdown;
  G_OBJECT_CLASS(klass)->dispose = my_application_dispose;
}

static void my_application_init(MyApplication* self) {}

MyApplication* my_application_new() {
  // Set the program name to the application ID, which helps various systems
  // like GTK and desktop environments map this running application to its
  // corresponding .desktop file. This ensures better integration by allowing
  // the application to be recognized beyond its binary name.
  g_set_prgname(APPLICATION_ID);

  return MY_APPLICATION(g_object_new(my_application_get_type(),
                                     "application-id", APPLICATION_ID, "flags",
                                     G_APPLICATION_DEFAULT_FLAGS, nullptr));
}
