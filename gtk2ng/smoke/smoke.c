/* GTK2 smoke test: builds a window with the widgets the distro's patches and
 * gtk2-ng touch, shows it for a moment and exits 0. Compile it against the
 * distro's own libgtk2.0-dev, then run the same binary with gtk2-ng installed:
 * that is the ABI test that matters. */
#include <gtk/gtk.h>
#include <gtk/gtkunixprint.h>

static gboolean quit(gpointer data) { gtk_main_quit(); return FALSE; }

int main(int argc, char **argv)
{
    gtk_init(&argc, &argv);

    GtkWidget *win = gtk_window_new(GTK_WINDOW_TOPLEVEL);
    GtkWidget *box = gtk_vbox_new(FALSE, 4);
    gtk_container_add(GTK_CONTAINER(win), box);

    gtk_box_pack_start(GTK_BOX(box), gtk_label_new("gtk2 smoke test"), FALSE, FALSE, 0);
    gtk_box_pack_start(GTK_BOX(box), gtk_entry_new(), FALSE, FALSE, 0);
    gtk_box_pack_start(GTK_BOX(box), gtk_button_new_from_stock(GTK_STOCK_OPEN), FALSE, FALSE, 0);
    gtk_box_pack_start(GTK_BOX(box), gtk_image_new_from_stock(GTK_STOCK_DIALOG_INFO, GTK_ICON_SIZE_DIALOG), FALSE, FALSE, 0);

    GtkListStore *store = gtk_list_store_new(2, G_TYPE_STRING, G_TYPE_INT);
    for (int i = 0; i < 50; i++) {
        GtkTreeIter it;
        gtk_list_store_append(store, &it);
        gtk_list_store_set(store, &it, 0, "row", 1, i, -1);
    }
    GtkWidget *tree = gtk_tree_view_new_with_model(GTK_TREE_MODEL(store));
    gtk_tree_view_append_column(GTK_TREE_VIEW(tree),
        gtk_tree_view_column_new_with_attributes("name", gtk_cell_renderer_text_new(), "text", 0, NULL));
    GtkWidget *scroll = gtk_scrolled_window_new(NULL, NULL);
    gtk_container_add(GTK_CONTAINER(scroll), tree);
    gtk_box_pack_start(GTK_BOX(box), scroll, TRUE, TRUE, 0);

    /* dialogs the distros patch (file chooser, print dialog): created and shown, not run */
    GtkWidget *fc = gtk_file_chooser_dialog_new("open", GTK_WINDOW(win), GTK_FILE_CHOOSER_ACTION_OPEN,
                        GTK_STOCK_CANCEL, GTK_RESPONSE_CANCEL, GTK_STOCK_OPEN, GTK_RESPONSE_ACCEPT, NULL);
    GtkWidget *pd = gtk_print_unix_dialog_new("print", GTK_WINDOW(win));

    gtk_widget_show_all(win);
    gtk_widget_show_all(fc);
    gtk_widget_show_all(pd);

    g_timeout_add(2000, quit, NULL);
    gtk_main();

    printf("SMOKE OK, GTK %u.%u.%u\n", gtk_major_version, gtk_minor_version, gtk_micro_version);
    return 0;
}
