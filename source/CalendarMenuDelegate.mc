import Toybox.Lang;
import Toybox.System;
import Toybox.WatchUi;

class CalendarMenuDelegate extends WatchUi.MenuInputDelegate {

    var _view as CalendarView?;

    function initialize(view as CalendarView) {
        MenuInputDelegate.initialize();
        _view = view;
    }

    function onMenuItem(item as Symbol) as Void {
        System.println("CalendarMenuDelegate: " + item.toString());

        if (_view == null) {
            return;
        }

        var view = _view as CalendarView;

        if (item == :menu_mode_solar) {
            view.setDisplayMode(0);
        } else if (item == :menu_mode_lunar) {
            view.setDisplayMode(1);
        } else if (item == :menu_mode_both) {
            view.setDisplayMode(2);
        } else if (item == :menu_lang_zh_hans) {
            view.setLanguageMode(0);
        } else if (item == :menu_lang_zh_hant) {
            view.setLanguageMode(1);
        } else if (item == :menu_lang_en) {
            view.setLanguageMode(2);
        } else if (item == :menu_goto_today) {
            view.showCurrentMonth();
        }
    }
}
