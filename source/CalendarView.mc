import Toybox.Graphics;
import Toybox.Lang;
import Toybox.Math;
import Toybox.System;
import Toybox.Time;
import Toybox.Time.Gregorian;
import Toybox.WatchUi;
import Toybox.Application.Storage;

class CalendarView extends WatchUi.View {

    var _displayYear as Number;
    var _displayMonth as Number;

    var _todayYear as Number;
    var _todayMonth as Number;
    var _todayDay as Number;

    var _displayMode as Number; // 0=solar, 1=lunar, 2=both
    var _languageMode as Number; // 0=zh-Hans, 1=zh-Hant, 2=en
    var _debugText as String;
    var _lunarCacheYear as Number;
    var _lunarCacheMonth as Number;
    var _lunarDayTexts as Array<String>;

    function initialize() {
        View.initialize();

        var now = Gregorian.info(Time.now(), Time.FORMAT_SHORT);
        _displayYear = toNumber(now.year);
        _displayMonth = normalizeMonth(toNumber(now.month));

        _todayYear = toNumber(now.year);
        _todayMonth = normalizeMonth(toNumber(now.month));
        _todayDay = toNumber(now.day);

        _displayMode = 0;
        _languageMode = detectLanguageModeFromDevice();
        loadPersistedSettings();
        _debugText = "Ready";
        _lunarCacheYear = -1;
        _lunarCacheMonth = -1;
        _lunarDayTexts = [];
    }

    function onLayout(dc as Dc) as Void {
        // Draw fully in onUpdate.
    }

    function onUpdate(dc as Dc) as Void {
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_BLACK);
        dc.clear();

        var width = dc.getWidth();
        var height = dc.getHeight();
        var left = 16;
        var right = width - 16;
        var contentWidth = right - left;

        drawHeader(dc, left, contentWidth);
        drawWeekHeader(dc, left, contentWidth, 34);

        var gridTop = 48;
        var gridBottom = height - 30;
        drawCalendarGrid(dc, left, contentWidth, gridTop, gridBottom - gridTop);

        drawFooter(dc, left, contentWidth, height);
    }

    function showNextMonth() as Void {
        _displayMonth += 1;
        if (_displayMonth > 12) {
            _displayMonth = 1;
            _displayYear += 1;
        }
        _debugText = "Next month";
        System.println("CalendarView: showNextMonth => " + _displayYear.toString() + "-" + _displayMonth.toString());
        WatchUi.requestUpdate();
    }

    function showPreviousMonth() as Void {
        _displayMonth -= 1;
        if (_displayMonth < 1) {
            _displayMonth = 12;
            _displayYear -= 1;
        }
        _debugText = "Prev month";
        System.println("CalendarView: showPreviousMonth => " + _displayYear.toString() + "-" + _displayMonth.toString());
        WatchUi.requestUpdate();
    }

    function showCurrentMonth() as Void {
        _displayYear = _todayYear;
        _displayMonth = _todayMonth;
        _debugText = "Back to today";
        System.println("CalendarView: showCurrentMonth");
        WatchUi.requestUpdate();
    }

    function setDisplayMode(mode as Number) as Void {
        mode = clampMode(mode);

        _displayMode = mode;
        saveDisplayMode();
        _debugText = "Mode " + mode.toString();
        System.println("CalendarView: mode=" + mode.toString());
        WatchUi.requestUpdate();
    }

    function cycleDisplayMode() as Void {
        var nextMode = _displayMode + 1;
        if (nextMode > 2) {
            nextMode = 0;
        }
        setDisplayMode(nextMode);
    }

    function getDisplayMode() as Number {
        return _displayMode;
    }

    function setLanguageMode(mode as Number) as Void {
        mode = clampMode(mode);

        _languageMode = mode;
        saveLanguageMode();
        invalidateLunarCache();
        _debugText = "Lang " + mode.toString();
        WatchUi.requestUpdate();
    }

    function getLanguageMode() as Number {
        return _languageMode;
    }

    // Compatibility wrapper.
    function setLunarEnabled(enabled as Boolean) as Void {
        setDisplayMode(enabled ? 1 : 0);
    }

    // Compatibility wrapper.
    function isLunarEnabled() as Boolean {
        return _displayMode != 0;
    }

    function markInput(source as String) as Void {
        _debugText = source;
        System.println("CalendarView: input=" + source);
        WatchUi.requestUpdate();
    }

    function drawHeader(dc as Dc, left as Number, contentWidth as Number) as Void {
        var monthNames = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"];
        var monthIndex = normalizeMonth(_displayMonth) - 1;
        var title = monthNames[monthIndex] + " " + _displayYear.toString();
        var titleX = left + (contentWidth / 2);
        var titleY = 8;
        if (_languageMode == 0) {
            title = _displayYear.toString() + "." + _displayMonth.toString();
        } else if (_languageMode == 1) {
            title = _displayYear.toString() + "." + _displayMonth.toString();
        }

        if (_languageMode == 2) {
            dc.drawText(titleX, titleY, Graphics.FONT_SMALL, title, Graphics.TEXT_JUSTIFY_CENTER);
            return;
        }

        var zhHeaderFont = getChineseVectorFont(16);
        drawTextWithOptionalVector(dc, titleX, titleY, Graphics.FONT_SMALL, zhHeaderFont, title, Graphics.TEXT_JUSTIFY_CENTER);
    }

    function drawWeekHeader(dc as Dc, left as Number, contentWidth as Number, y as Number) as Void {
        var weekNames = getWeekNames();
        var cellWidth = contentWidth / 7;
        var weekFont = Graphics.FONT_XTINY;

        for (var i = 0; i < 7; i += 1) {
            var x = left + (i * cellWidth) + (cellWidth / 2);
            dc.drawText(x, y, weekFont, weekNames[i], Graphics.TEXT_JUSTIFY_CENTER);
        }

        dc.drawLine(left, y + dc.getFontHeight(weekFont) + 1, left + contentWidth, y + dc.getFontHeight(weekFont) + 1);
    }

    function drawCalendarGrid(dc as Dc, left as Number, contentWidth as Number, top as Number, gridHeight as Number) as Void {
        var month = normalizeMonth(_displayMonth);
        var firstDayWeekSun0 = getWeekdaySun0(_displayYear, month, 1);
        var firstDayWeekMon0 = (firstDayWeekSun0 + 6) % 7;

        var totalDays = getDaysInMonth(_displayYear, month);
        var cellWidth = contentWidth / 7;
        var cellHeight = gridHeight / 6;
        var solarFont = Graphics.FONT_XTINY;
        var lunarFont = Graphics.FONT_XTINY;
        var singleFont = Graphics.FONT_XTINY;
        var zhCellFont = (_languageMode == 2) ? null : getChineseVectorFont(10);
        var solarHeight = dc.getFontHeight(solarFont);
        var lunarHeight = getFontHeightWithOptionalVector(dc, lunarFont, zhCellFont);
        var singleHeight = getFontHeightWithOptionalVector(dc, singleFont, zhCellFont);

        var isLunarMode = (_displayMode == 1);
        var isBothMode = (_displayMode == 2);
        var useLunarData = isLunarMode || isBothMode;

        if (useLunarData) {
            ensureLunarMonthCache(_displayYear, month, totalDays);
        }

        for (var day = 1; day <= totalDays; day += 1) {
            var offset = firstDayWeekMon0 + day - 1;
            var row = Math.floor(offset / 7);
            var col = offset % 7;

            var cellX = left + (col * cellWidth);
            var cellY = top + (row * cellHeight);
            var textX = cellX + (cellWidth / 2);
            var isToday = (_displayYear == _todayYear) && (_displayMonth == _todayMonth) && (day == _todayDay);
            var solarText = day.toString();
            var lunarText = "";
            if (useLunarData) {
                lunarText = _lunarDayTexts[day - 1];
            }

            if (isToday) {
                dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_WHITE);
                dc.fillRectangle(cellX + 2, cellY + 1, cellWidth - 4, cellHeight - 2);
            }

            if (isBothMode) {
                var bothTextTop = cellY + maxNumber(0, Math.floor((cellHeight - (solarHeight + lunarHeight)) / 2));
                if (isToday) {
                    dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_WHITE);
                }
                dc.drawText(textX, bothTextTop, solarFont, solarText, Graphics.TEXT_JUSTIFY_CENTER);
                drawTextWithOptionalVector(
                    dc,
                    textX,
                    bothTextTop + solarHeight,
                    lunarFont,
                    zhCellFont,
                    lunarText,
                    Graphics.TEXT_JUSTIFY_CENTER
                );
            } else if (isLunarMode) {
                var lunarY = cellY + maxNumber(0, Math.floor((cellHeight - singleHeight) / 2));
                if (isToday) {
                    dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_WHITE);
                }
                drawTextWithOptionalVector(dc, textX, lunarY, singleFont, zhCellFont, lunarText, Graphics.TEXT_JUSTIFY_CENTER);
            } else {
                var solarY = cellY + maxNumber(0, Math.floor((cellHeight - singleHeight) / 2));
                if (isToday) {
                    dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_WHITE);
                }
                dc.drawText(textX, solarY, singleFont, solarText, Graphics.TEXT_JUSTIFY_CENTER);
            }

            if (isToday) {
                dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_BLACK);
            }
        }
    }

    function drawFooter(dc as Dc, left as Number, contentWidth as Number, height as Number) as Void {
        var footerText = "";

        if (_displayMode == 1) {
            var lunar = solarToLunar(_todayYear, _todayMonth, _todayDay);
            footerText = footerLunarLabel() + " " + lunarMonthText(lunar[:month], lunar[:isLeap]) + lunarDayText(lunar[:day]);
        } else if (_displayMode == 2) {
            footerText = currentTimeText();
        } else {
            footerText = footerTodayLabel() + " " + _todayYear.toString() + "-" + pad2(_todayMonth) + "-" + pad2(_todayDay);
        }

        dc.drawText(left + (contentWidth / 2), height - 24, Graphics.FONT_XTINY, footerText, Graphics.TEXT_JUSTIFY_CENTER);
    }

    function getWeekdaySun0(year as Number, month as Number, day as Number) as Number {
        var info = Gregorian.info(Gregorian.moment({
            :year => year,
            :month => month,
            :day => day,
            :hour => 0,
            :min => 0,
            :sec => 0
        }), Time.FORMAT_SHORT);

        var weekday = toNumber(info.day_of_week) - 1;
        if (weekday < 0) {
            return 0;
        }
        if (weekday > 6) {
            return 6;
        }
        return weekday;
    }

    function getDaysInMonth(year as Number, month as Number) as Number {
        if ((month == 1) || (month == 3) || (month == 5) || (month == 7) || (month == 8) || (month == 10) || (month == 12)) {
            return 31;
        }

        if ((month == 4) || (month == 6) || (month == 9) || (month == 11)) {
            return 30;
        }

        if (isLeapYear(year)) {
            return 29;
        }

        return 28;
    }

    function isLeapYear(year as Number) as Boolean {
        if ((year % 400) == 0) {
            return true;
        }

        if ((year % 100) == 0) {
            return false;
        }

        return (year % 4) == 0;
    }

    function solarToLunar(year as Number, month as Number, day as Number) as Dictionary {
        var offset = daysFromCivil(year, month, day) - daysFromCivil(1900, 1, 31);

        var lunarYear = 1900;
        var daysInLunarYear = 0;
        while (lunarYear < 2100) {
            daysInLunarYear = lunarYearDays(lunarYear);
            if (offset < daysInLunarYear) {
                break;
            }
            offset -= daysInLunarYear;
            lunarYear += 1;
        }

        var leap = leapMonth(lunarYear);
        var isLeap = false;
        var lunarMonth = 1;
        var daysInLunarMonth = 0;

        while (lunarMonth <= 12) {
            if (leap > 0 && lunarMonth == (leap + 1) && !isLeap) {
                lunarMonth -= 1;
                isLeap = true;
                daysInLunarMonth = leapDays(lunarYear);
            } else {
                daysInLunarMonth = monthDays(lunarYear, lunarMonth);
            }

            if (offset < daysInLunarMonth) {
                break;
            }

            offset -= daysInLunarMonth;

            if (isLeap && lunarMonth == leap) {
                isLeap = false;
            }

            lunarMonth += 1;
        }

        return {
            :year => lunarYear,
            :month => lunarMonth,
            :day => (offset + 1),
            :isLeap => isLeap
        };
    }

    function ensureLunarMonthCache(year as Number, month as Number, totalDays as Number) as Void {
        if ((_lunarCacheYear == year) && (_lunarCacheMonth == month) && (_lunarDayTexts.size() == totalDays)) {
            return;
        }

        _lunarDayTexts = [];

        var lunar = solarToLunar(year, month, 1);
        var lunarYear = lunar[:year];
        var lunarMonth = lunar[:month];
        var lunarDay = lunar[:day];
        var isLeap = lunar[:isLeap];

        for (var day = 1; day <= totalDays; day += 1) {
            _lunarDayTexts.add(lunarCellText(lunarMonth, lunarDay, isLeap));

            var daysInCurrentLunarMonth = isLeap ? leapDays(lunarYear) : monthDays(lunarYear, lunarMonth);
            lunarDay += 1;

            if (lunarDay > daysInCurrentLunarMonth) {
                lunarDay = 1;

                if (isLeap) {
                    isLeap = false;
                    lunarMonth += 1;
                } else {
                    var leap = leapMonth(lunarYear);
                    if (leap == lunarMonth) {
                        isLeap = true;
                    } else {
                        lunarMonth += 1;
                    }
                }

                if (lunarMonth > 12) {
                    lunarMonth = 1;
                    lunarYear += 1;
                    isLeap = false;
                }
            }
        }

        _lunarCacheYear = year;
        _lunarCacheMonth = month;
        System.println("CalendarView: lunar month cache built " + year.toString() + "-" + month.toString());
    }

    function invalidateLunarCache() as Void {
        _lunarCacheYear = -1;
        _lunarCacheMonth = -1;
        _lunarDayTexts = [];
    }

    function daysFromCivil(year as Number, month as Number, day as Number) as Number {
        var y = year;
        var m = month;
        if (m <= 2) {
            y -= 1;
        }

        var era = Math.floor(y / 400);
        var yoe = y - (era * 400);

        var monthIndex = m;
        if (m > 2) {
            monthIndex = m - 3;
        } else {
            monthIndex = m + 9;
        }

        var doy = Math.floor((153 * monthIndex + 2) / 5) + day - 1;
        var doe = yoe * 365 + Math.floor(yoe / 4) - Math.floor(yoe / 100) + doy;

        return era * 146097 + doe - 719468;
    }

    function lunarYearDays(year as Number) as Number {
        var sum = 348;
        var info = lunarInfo(year);

        for (var mask = 0x8000; mask > 0x8; mask = Math.floor(mask / 2)) {
            if ((info & mask) != 0) {
                sum += 1;
            }
        }

        return sum + leapDays(year);
    }

    function leapDays(year as Number) as Number {
        var info = lunarInfo(year);
        if (leapMonth(year) != 0) {
            if ((info & 0x10000) != 0) {
                return 30;
            }
            return 29;
        }
        return 0;
    }

    function leapMonth(year as Number) as Number {
        return lunarInfo(year) & 0xF;
    }

    function monthDays(year as Number, month as Number) as Number {
        var info = lunarInfo(year);
        var mask = Math.floor(0x10000 / pow2(month));
        if ((info & mask) != 0) {
            return 30;
        }
        return 29;
    }

    function pow2(n as Number) as Number {
        var value = 1;
        for (var i = 0; i < n; i += 1) {
            value *= 2;
        }
        return value;
    }

    function lunarMonthText(month as Number, isLeap as Boolean) as String {
        if (_languageMode == 2) {
            var en = "M" + month.toString();
            if (isLeap) {
                return "L" + en;
            }
            return en;
        }

        var names = ["正", "二", "三", "四", "五", "六", "七", "八", "九", "十", "冬", "腊"];
        if (_languageMode == 1) {
            names = ["正", "二", "三", "四", "五", "六", "七", "八", "九", "十", "冬", "臘"];
        }

        var text = names[month - 1] + "月";
        if (isLeap) {
            if (_languageMode == 1) {
                return "閏" + text;
            }
            return "闰" + text;
        }
        return text;
    }

    function lunarCellText(month as Number, day as Number, isLeap as Boolean) as String {
        if (day == 1) {
            return lunarMonthText(month, isLeap);
        }
        return lunarDayText(day);
    }

    function lunarDayText(day as Number) as String {
        if (_languageMode == 2) {
            return "D" + day.toString();
        }

        if (day == 10) { return "初十"; }
        if (day == 20) { return "二十"; }
        if (day == 30) { return "三十"; }

        var prefix = ["初", "十", "廿", "三"];
        var nums = ["", "一", "二", "三", "四", "五", "六", "七", "八", "九"];

        var p = Math.floor(day / 10);
        var n = day % 10;
        return prefix[p] + nums[n];
    }

    function getWeekNames() as Array<String> {
        if (_languageMode == 2) {
            return ["Mo", "Tu", "We", "Th", "Fr", "Sa", "Su"];
        }

        return ["一", "二", "三", "四", "五", "六", "日"];
    }

    function footerTodayLabel() as String {
        if (_languageMode == 2) {
            return "Today";
        }
        if (_languageMode == 1) {
            return "今日";
        }
        return "今天";
    }

    function footerLunarLabel() as String {
        if (_languageMode == 2) {
            return "Lunar";
        }
        if (_languageMode == 1) {
            return "農曆";
        }
        return "农历";
    }

    function footerBothLabel() as String {
        if (_languageMode == 2) {
            return "Both";
        }
        if (_languageMode == 1) {
            return "同時";
        }
        return "同时";
    }

    function currentTimeText() as String {
        var now = Gregorian.info(Time.now(), Time.FORMAT_SHORT);
        var hour = toNumber(now.hour);
        var minute = toNumber(now.min);
        return pad2(hour) + ":" + pad2(minute);
    }

    function detectLanguageModeFromDevice() as Number {
        var settings = System.getDeviceSettings();
        if (settings == null) {
            return 0;
        }

        if (!(settings has :systemLanguage)) {
            return 0;
        }

        var systemLanguage = settings.systemLanguage;

        if (systemLanguage == System.LANGUAGE_CHT) {
            return 1;
        }

        if (systemLanguage == System.LANGUAGE_ENG) {
            return 2;
        }

        return 0;
    }

    function loadPersistedSettings() as Void {
        var savedDisplay = Storage.getValue("display_mode");
        if (savedDisplay instanceof Number) {
            _displayMode = clampMode(savedDisplay as Number);
        }

        var savedLanguage = Storage.getValue("language_mode");
        if (savedLanguage instanceof Number) {
            _languageMode = clampMode(savedLanguage as Number);
        }
    }

    function saveDisplayMode() as Void {
        Storage.setValue("display_mode", _displayMode);
    }

    function saveLanguageMode() as Void {
        Storage.setValue("language_mode", _languageMode);
    }

    function lunarInfo(year as Number) as Number {
        var data = [
            0x04bd8,0x04ae0,0x0a570,0x054d5,0x0d260,0x0d950,0x16554,0x056a0,0x09ad0,0x055d2,
            0x04ae0,0x0a5b6,0x0a4d0,0x0d250,0x1d255,0x0b540,0x0d6a0,0x0ada2,0x095b0,0x14977,
            0x04970,0x0a4b0,0x0b4b5,0x06a50,0x06d40,0x1ab54,0x02b60,0x09570,0x052f2,0x04970,
            0x06566,0x0d4a0,0x0ea50,0x06e95,0x05ad0,0x02b60,0x186e3,0x092e0,0x1c8d7,0x0c950,
            0x0d4a0,0x1d8a6,0x0b550,0x056a0,0x1a5b4,0x025d0,0x092d0,0x0d2b2,0x0a950,0x0b557,
            0x06ca0,0x0b550,0x15355,0x04da0,0x0a5d0,0x14573,0x052d0,0x0a9a8,0x0e950,0x06aa0,
            0x0aea6,0x0ab50,0x04b60,0x0aae4,0x0a570,0x05260,0x0f263,0x0d950,0x05b57,0x056a0,
            0x096d0,0x04dd5,0x04ad0,0x0a4d0,0x0d4d4,0x0d250,0x0d558,0x0b540,0x0b5a0,0x195a6,
            0x095b0,0x049b0,0x0a974,0x0a4b0,0x0b27a,0x06a50,0x06d40,0x0af46,0x0ab60,0x09570,
            0x04af5,0x04970,0x064b0,0x074a3,0x0ea50,0x06b58,0x055c0,0x0ab60,0x096d5,0x092e0,
            0x0c960,0x0d954,0x0d4a0,0x0da50,0x07552,0x056a0,0x0abb7,0x025d0,0x092d0,0x0cab5,
            0x0a950,0x0b4a0,0x0baa4,0x0ad50,0x055d9,0x04ba0,0x0a5b0,0x15176,0x052b0,0x0a930,
            0x07954,0x06aa0,0x0ad50,0x05b52,0x04b60,0x0a6e6,0x0a4e0,0x0d260,0x0ea65,0x0d530,
            0x05aa0,0x076a3,0x096d0,0x04bd7,0x04ad0,0x0a4d0,0x1d0b6,0x0d250,0x0d520,0x0dd45,
            0x0b5a0,0x056d0,0x055b2,0x049b0,0x0a577,0x0a4b0,0x0aa50,0x1b255,0x06d20,0x0ada0,
            0x14b63
        ];

        var index = year - 1900;
        if (index < 0) {
            index = 0;
        }
        if (index >= data.size()) {
            index = data.size() - 1;
        }

        return data[index];
    }

    function pad2(v as Number) as String {
        if (v < 10) {
            return "0" + v.toString();
        }
        return v.toString();
    }

    function maxNumber(a as Number, b as Number) as Number {
        if (a > b) {
            return a;
        }
        return b;
    }

    function clampMode(mode as Number) as Number {
        if (mode < 0) {
            return 0;
        }
        if (mode > 2) {
            return 2;
        }
        return mode;
    }

    function getChineseVectorFont(size as Number) as Graphics.VectorFont? {
        if (!(Graphics has :getVectorFont)) {
            return null;
        }

        var faces = [
            "Noto Sans CJK SC",
            "NotoSansCJKsc-Regular",
            "PingFang SC",
            "Heiti SC",
            "Source Han Sans SC",
            "WenQuanYi Zen Hei",
            "Droid Sans Fallback"
        ];

        if (_languageMode == 1) {
            faces = [
                "Noto Sans CJK TC",
                "NotoSansCJKtc-Regular",
                "PingFang TC",
                "Heiti TC",
                "Source Han Sans TC",
                "Droid Sans Fallback"
            ];
        }

        return Graphics.getVectorFont({:face => faces, :size => size});
    }

    function getFontHeightWithOptionalVector(dc as Dc, fallbackFont, vectorFont as Graphics.VectorFont?) as Number {
        if (vectorFont != null) {
            return dc.getFontHeight(vectorFont as Graphics.VectorFont);
        }
        return dc.getFontHeight(fallbackFont);
    }

    function drawTextWithOptionalVector(dc as Dc, x as Number, y as Number, fallbackFont, vectorFont as Graphics.VectorFont?, text as String, justify as Number) as Void {
        if (vectorFont != null) {
            dc.drawText(x, y, vectorFont as Graphics.VectorFont, text, justify);
            return;
        }
        dc.drawText(x, y, fallbackFont, text, justify);
    }

    function toNumber(value as Object?) as Number {
        if (value == null) {
            return 0;
        }

        if (value instanceof Number) {
            return value as Number;
        }

        if (value instanceof String) {
            var s = (value as String).toLower();
            if ((s == "jan") || (s == "january")) { return 1; }
            if ((s == "feb") || (s == "february")) { return 2; }
            if ((s == "mar") || (s == "march")) { return 3; }
            if ((s == "apr") || (s == "april")) { return 4; }
            if (s == "may") { return 5; }
            if ((s == "jun") || (s == "june")) { return 6; }
            if ((s == "jul") || (s == "july")) { return 7; }
            if ((s == "aug") || (s == "august")) { return 8; }
            if ((s == "sep") || (s == "sept") || (s == "september")) { return 9; }
            if ((s == "oct") || (s == "october")) { return 10; }
            if ((s == "nov") || (s == "november")) { return 11; }
            if ((s == "dec") || (s == "december")) { return 12; }
            return (value as String).toNumber();
        }

        return 0;
    }

    function normalizeMonth(month as Number) as Number {
        if (month < 1) {
            return 1;
        }
        if (month > 12) {
            return 12;
        }
        return month;
    }
}
