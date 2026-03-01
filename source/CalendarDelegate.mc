import Toybox.Lang;
import Toybox.System;
import Toybox.WatchUi;

class CalendarDelegate extends WatchUi.BehaviorDelegate {

    var _view as CalendarView?;

    function initialize(view as CalendarView) {
        BehaviorDelegate.initialize();
        _view = view;
        System.println("CalendarDelegate: initialize");
    }

    function onPreviousPage() as Boolean {
        System.println("CalendarDelegate: onPreviousPage");
        if (_view != null) {
            (_view as CalendarView).markInput("PrevPage");
            (_view as CalendarView).showPreviousMonth();
            return true;
        }
        return false;
    }

    function onNextPage() as Boolean {
        System.println("CalendarDelegate: onNextPage");
        if (_view != null) {
            (_view as CalendarView).markInput("NextPage");
            (_view as CalendarView).showNextMonth();
            return true;
        }
        return false;
    }

    function onSelect() as Boolean {
        System.println("CalendarDelegate: onSelect");
        if (_view != null) {
            var view = _view as CalendarView;
            view.markInput("Select cycle mode");
            view.cycleDisplayMode();
            return true;
        }
        return false;
    }

    function onAction() as Boolean {
        System.println("CalendarDelegate: onAction");
        if (_view != null) {
            (_view as CalendarView).markInput("Action");
            (_view as CalendarView).showNextMonth();
            return true;
        }
        return false;
    }

    function onMenu() as Boolean {
        System.println("CalendarDelegate: onMenu");
        if (_view != null) {
            WatchUi.pushView(new Rez.Menus.MainMenu(), new CalendarMenuDelegate(_view as CalendarView), WatchUi.SLIDE_UP);
            return true;
        }
        return false;
    }

    function onKey(evt as WatchUi.KeyEvent) as Boolean {
        System.println("CalendarDelegate: onKey " + evt.toString());
        return false;
    }
}
