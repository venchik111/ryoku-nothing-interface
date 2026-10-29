pragma Singleton
import QtQuick

// The shipped Ryoku translation catalogue at /usr/share/ryoku/i18n is the single
// language table for this lockscreen. The theme ships no per-language copy
// table; every visible string goes through I18n.tr() and falls back to the
// English key on a miss.
QtObject {
    id: i18n

    property string catalogDir: "/usr/share/ryoku/i18n"

    function _read(path) {
        var xhr = new XMLHttpRequest();
        try {
            xhr.open("GET", "file://" + path, false);
            xhr.send();
            if (xhr.status === 200 || xhr.status === 0)
                return xhr.responseText;
        } catch (e) {}
        return "";
    }

    readonly property var langs: {
        try {
            var t = i18n._read(i18n.catalogDir + "/langs.json");
            return t ? ((JSON.parse(t) || {}).languages || []) : [];
        } catch (e) {
            return [];
        }
    }

    // every spelling a locale maps by (code, English name, native name) -> code.
    readonly property var names: {
        var m = {};
        for (var i = 0; i < i18n.langs.length; i++) {
            var l = i18n.langs[i];
            m[l.code] = l.code;
            m[l.name] = l.code;
            m[l.native] = l.code;
        }
        return m;
    }

    // the active language from the system locale (pt_BR, then pt, else English).
    readonly property string lang: {
        var n = Qt.locale().name;
        if (i18n.names[n])
            return i18n.names[n];
        var base = n.split("_")[0];
        return i18n.names[base] || "en";
    }

    readonly property bool rtl: {
        for (var i = 0; i < i18n.langs.length; i++)
            if (i18n.langs[i].code === i18n.lang)
                return i18n.langs[i].dir === "rtl";
        return false;
    }
    readonly property int dir: i18n.rtl ? Qt.RightToLeft : Qt.LeftToRight

    // the active language's string map; English ships no file, so its keys are
    // the strings.
    readonly property var map: {
        if (i18n.lang === "en")
            return ({});
        try {
            var t = i18n._read(i18n.catalogDir + "/" + i18n.lang + ".json");
            return t ? (JSON.parse(t) || {}) : ({});
        } catch (e) {
            return ({});
        }
    }

    // English key in, translated string (or the key) out.
    function tr(s) {
        if (s === undefined || s === null || s === "")
            return s;
        var v = i18n.map["" + s];
        return v === undefined ? s : v;
    }
}
