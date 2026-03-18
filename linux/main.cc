#include "my_application.h"
#include <stdlib.h>

int main(int argc, char** argv) {
  // Force HiDPI mode (2x scaling)
  setenv("GDK_SCALE", "2", 0); 
  
  // GDK_DPI_SCALE is ignored on Wayland for GTK3, so we handle resizing in Dart.
  
  g_autoptr(MyApplication) app = my_application_new();
  return g_application_run(G_APPLICATION(app), argc, argv);
}
