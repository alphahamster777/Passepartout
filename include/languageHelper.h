#pragma once

#include <QObject>
#include <QtQml/qqml.h>
#include <QStringList>
#include <QVariantList>
#include <QLocale>
#include <QHash>

class LanguageHelper : public QObject
{
    Q_OBJECT
    QML_ELEMENT
    QML_SINGLETON
public:
    enum Language {
        English         =  0,
        MandarinChinese =  1,
        Hindi           =  2,
        Spanish         =  3,
        French          =  4,
        StandardArabic  =  5,
        Bengali         =  6,
        Russian         =  7,
        Portuguese      =  8,
        Urdu            =  9,
        German          = 10,
        Japanese        = 11,
        Italian         = 12,
        Dutch           = 13,
        Polish          = 14,
        Vietnamese      = 15,
        Ukrainian       = 16,
        Persian         = 17,
        Swedish         = 18,
        Finnish         = 19,
        Czech           = 20,
        Hungarian       = 21,
        Korean          = 22,
        Romanian        = 23,
        Norwegian       = 24,
        Turkish         = 25,
        Indonesian      = 26,
        Hebrew          = 27,
        Serbian         = 28,
        Danish          = 29,
        Bulgarian       = 30,
        Catalan         = 31,
        Slovak          = 32,
        Thai            = 33,
        Greek           = 34,
        Lithuanian      = 35,
        Croatian        = 36,
        Estonian        = 37,
        Latvian         = 38,
        Albanian        = 39,
        Georgian        = 40,
        Armenian        = 41,
        Azerbaijani     = 42,
        Kazakh          = 43,
        Belarusian      = 44,
        Basque          = 45,
        Galician        = 46,
        Welsh           = 47,
        Tamil           = 48,
        Malay           = 49,
        Marathi         = 50,
        Swahili         = 51,
        Slovenian       = 52,
        Icelandic       = 53,
        Filipino        = 54,
        Afrikaans       = 55,
        NotSelected     = -1
    };
    Q_ENUM(Language)

    explicit LanguageHelper(QObject *parent = nullptr);

    // Returns {name, id} pairs sorted alphabetically, "Not selected" last.
    // Use this as the model for the language picker so the list is ordered.
    Q_INVOKABLE static QVariantList sortedLanguageEntries();

    // Returns display names indexed by enum value (index == enum ordinal).
    Q_INVOKABLE static QStringList languageNames() {
        return {
            "English",          //  0
            "Mandarin Chinese", //  1
            "Hindi",            //  2
            "Spanish",          //  3
            "French",           //  4
            "Standard Arabic",  //  5
            "Bengali",          //  6
            "Russian",          //  7
            "Portuguese",       //  8
            "Urdu",             //  9
            "German",           // 10
            "Japanese",         // 11
            "Italian",          // 12
            "Dutch",            // 13
            "Polish",           // 14
            "Vietnamese",       // 15
            "Ukrainian",        // 16
            "Persian",          // 17
            "Swedish",          // 18
            "Finnish",          // 19
            "Czech",            // 20
            "Hungarian",        // 21
            "Korean",           // 22
            "Romanian",         // 23
            "Norwegian",        // 24
            "Turkish",          // 25
            "Indonesian",       // 26
            "Hebrew",           // 27
            "Serbian",          // 28
            "Danish",           // 29
            "Bulgarian",        // 30
            "Catalan",          // 31
            "Slovak",           // 32
            "Thai",             // 33
            "Greek",            // 34
            "Lithuanian",       // 35
            "Croatian",         // 36
            "Estonian",         // 37
            "Latvian",          // 38
            "Albanian",         // 39
            "Georgian",         // 40
            "Armenian",         // 41
            "Azerbaijani",      // 42
            "Kazakh",           // 43
            "Belarusian",       // 44
            "Basque",           // 45
            "Galician",         // 46
            "Welsh",            // 47
            "Tamil",            // 48
            "Malay",            // 49
            "Marathi",          // 50
            "Swahili",          // 51
            "Slovenian",        // 52
            "Icelandic",        // 53
            "Filipino",         // 54
            "Afrikaans"         // 55
        };
    }

    Q_INVOKABLE static Language languageFromString(const QString &name) {
        static const QHash<QString, Language> mapping = {
            {"English",          English},
            {"Mandarin Chinese", MandarinChinese},
            {"Hindi",            Hindi},
            {"Spanish",          Spanish},
            {"French",           French},
            {"Standard Arabic",  StandardArabic},
            {"Bengali",          Bengali},
            {"Russian",          Russian},
            {"Portuguese",       Portuguese},
            {"Urdu",             Urdu},
            {"Not selected",     NotSelected},
            {"German",           German},
            {"Japanese",         Japanese},
            {"Italian",          Italian},
            {"Dutch",            Dutch},
            {"Polish",           Polish},
            {"Vietnamese",       Vietnamese},
            {"Ukrainian",        Ukrainian},
            {"Persian",          Persian},
            {"Swedish",          Swedish},
            {"Finnish",          Finnish},
            {"Czech",            Czech},
            {"Hungarian",        Hungarian},
            {"Korean",           Korean},
            {"Romanian",         Romanian},
            {"Norwegian",        Norwegian},
            {"Turkish",          Turkish},
            {"Indonesian",       Indonesian},
            {"Hebrew",           Hebrew},
            {"Serbian",          Serbian},
            {"Danish",           Danish},
            {"Bulgarian",        Bulgarian},
            {"Catalan",          Catalan},
            {"Slovak",           Slovak},
            {"Thai",             Thai},
            {"Greek",            Greek},
            {"Lithuanian",       Lithuanian},
            {"Croatian",         Croatian},
            {"Estonian",         Estonian},
            {"Latvian",          Latvian},
            {"Albanian",         Albanian},
            {"Georgian",         Georgian},
            {"Armenian",         Armenian},
            {"Azerbaijani",      Azerbaijani},
            {"Kazakh",           Kazakh},
            {"Belarusian",       Belarusian},
            {"Basque",           Basque},
            {"Galician",         Galician},
            {"Welsh",            Welsh},
            {"Tamil",            Tamil},
            {"Malay",            Malay},
            {"Marathi",          Marathi},
            {"Swahili",          Swahili},
            {"Slovenian",        Slovenian},
            {"Icelandic",        Icelandic},
            {"Filipino",         Filipino},
            {"Afrikaans",        Afrikaans}
        };
        return mapping.value(name, NotSelected);
    }

    // Native script display name for each language.
    Q_INVOKABLE static QString displayName(Language lang) {
        switch (lang) {
        case English:          return QStringLiteral("English");
        case MandarinChinese:  return QStringLiteral("普通话");
        case Hindi:            return QStringLiteral("हिन्दी");
        case Spanish:          return QStringLiteral("Español");
        case French:           return QStringLiteral("Français");
        case StandardArabic:   return QStringLiteral("العربية");
        case Bengali:          return QStringLiteral("বাংলা");
        case Russian:          return QStringLiteral("Русский");
        case Portuguese:       return QStringLiteral("Português");
        case Urdu:             return QStringLiteral("اردو");
        case German:           return QStringLiteral("Deutsch");
        case Japanese:         return QStringLiteral("日本語");
        case Italian:          return QStringLiteral("Italiano");
        case Dutch:            return QStringLiteral("Nederlands");
        case Polish:           return QStringLiteral("Polski");
        case Vietnamese:       return QStringLiteral("Tiếng Việt");
        case Ukrainian:        return QStringLiteral("Українська");
        case Persian:          return QStringLiteral("فارسی");
        case Swedish:          return QStringLiteral("Svenska");
        case Finnish:          return QStringLiteral("Suomi");
        case Czech:            return QStringLiteral("Čeština");
        case Hungarian:        return QStringLiteral("Magyar");
        case Korean:           return QStringLiteral("한국어");
        case Romanian:         return QStringLiteral("Română");
        case Norwegian:        return QStringLiteral("Norsk");
        case Turkish:          return QStringLiteral("Türkçe");
        case Indonesian:       return QStringLiteral("Bahasa Indonesia");
        case Hebrew:           return QStringLiteral("עברית");
        case Serbian:          return QStringLiteral("Српски");
        case Danish:           return QStringLiteral("Dansk");
        case Bulgarian:        return QStringLiteral("Български");
        case Catalan:          return QStringLiteral("Català");
        case Slovak:           return QStringLiteral("Slovenčina");
        case Thai:             return QStringLiteral("ภาษาไทย");
        case Greek:            return QStringLiteral("Ελληνικά");
        case Lithuanian:       return QStringLiteral("Lietuvių");
        case Croatian:         return QStringLiteral("Hrvatski");
        case Estonian:         return QStringLiteral("Eesti");
        case Latvian:          return QStringLiteral("Latviešu");
        case Albanian:         return QStringLiteral("Shqip");
        case Georgian:         return QStringLiteral("ქართული");
        case Armenian:         return QStringLiteral("Հայերեն");
        case Azerbaijani:      return QStringLiteral("Azərbaycanca");
        case Kazakh:           return QStringLiteral("Қазақша");
        case Belarusian:       return QStringLiteral("Беларуская");
        case Basque:           return QStringLiteral("Euskara");
        case Galician:         return QStringLiteral("Galego");
        case Welsh:            return QStringLiteral("Cymraeg");
        case Tamil:            return QStringLiteral("தமிழ்");
        case Malay:            return QStringLiteral("Bahasa Melayu");
        case Marathi:          return QStringLiteral("मराठी");
        case Swahili:          return QStringLiteral("Kiswahili");
        case Slovenian:        return QStringLiteral("Slovenščina");
        case Icelandic:        return QStringLiteral("Íslenska");
        case Filipino:         return QStringLiteral("Filipino");
        case Afrikaans:        return QStringLiteral("Afrikaans");
        case NotSelected:      return QStringLiteral("Not selected");
        default:               return QStringLiteral("Other");
        }
    }

    // BCP-47-ish locale code used both as the translation file suffix
    // (translations/app_<code>.ts / :/i18n/app_<code>.qm) and for QLocale
    // construction. Deliberately a plain lookup table rather than deriving
    // this from displayName()/QLocale::languageToCode() — several of these
    // (Standard Arabic, Mandarin Chinese, Filipino) need a specific script
    // or region variant that the generic mapping wouldn't reliably pick.
    Q_INVOKABLE static QString localeCode(Language lang) {
        static const QHash<Language, QString> mapping = {
            {English,          QStringLiteral("en")},
            {MandarinChinese,  QStringLiteral("zh_CN")},
            {Hindi,            QStringLiteral("hi")},
            {Spanish,          QStringLiteral("es")},
            {French,           QStringLiteral("fr")},
            {StandardArabic,   QStringLiteral("ar")},
            {Bengali,          QStringLiteral("bn")},
            {Russian,          QStringLiteral("ru")},
            {Portuguese,       QStringLiteral("pt")},
            {Urdu,             QStringLiteral("ur")},
            {German,           QStringLiteral("de")},
            {Japanese,         QStringLiteral("ja")},
            {Italian,          QStringLiteral("it")},
            {Dutch,            QStringLiteral("nl")},
            {Polish,           QStringLiteral("pl")},
            {Vietnamese,       QStringLiteral("vi")},
            {Ukrainian,        QStringLiteral("uk")},
            {Persian,          QStringLiteral("fa")},
            {Swedish,          QStringLiteral("sv")},
            {Finnish,          QStringLiteral("fi")},
            {Czech,            QStringLiteral("cs")},
            {Hungarian,        QStringLiteral("hu")},
            {Korean,           QStringLiteral("ko")},
            {Romanian,         QStringLiteral("ro")},
            {Norwegian,        QStringLiteral("nb")},
            {Turkish,          QStringLiteral("tr")},
            {Indonesian,       QStringLiteral("id")},
            {Hebrew,           QStringLiteral("he")},
            {Serbian,          QStringLiteral("sr")},
            {Danish,           QStringLiteral("da")},
            {Bulgarian,        QStringLiteral("bg")},
            {Catalan,          QStringLiteral("ca")},
            {Slovak,           QStringLiteral("sk")},
            {Thai,             QStringLiteral("th")},
            {Greek,            QStringLiteral("el")},
            {Lithuanian,       QStringLiteral("lt")},
            {Croatian,         QStringLiteral("hr")},
            {Estonian,         QStringLiteral("et")},
            {Latvian,          QStringLiteral("lv")},
            {Albanian,         QStringLiteral("sq")},
            {Georgian,         QStringLiteral("ka")},
            {Armenian,         QStringLiteral("hy")},
            {Azerbaijani,      QStringLiteral("az")},
            {Kazakh,           QStringLiteral("kk")},
            {Belarusian,       QStringLiteral("be")},
            {Basque,           QStringLiteral("eu")},
            {Galician,         QStringLiteral("gl")},
            {Welsh,            QStringLiteral("cy")},
            {Tamil,            QStringLiteral("ta")},
            {Malay,            QStringLiteral("ms")},
            {Marathi,          QStringLiteral("mr")},
            {Swahili,          QStringLiteral("sw")},
            {Slovenian,        QStringLiteral("sl")},
            {Icelandic,        QStringLiteral("is")},
            {Filipino,         QStringLiteral("fil")},
            {Afrikaans,        QStringLiteral("af")}
        };
        return mapping.value(lang, QStringLiteral("en"));
    }

    // A representative country flag for the language picker. Several of
    // these languages don't map to a single country (Arabic, English,
    // Spanish, Basque/Catalan/Galician all sharing Spain, etc.) — there's
    // no flag emoji for a language as such, only for places, so this picks
    // the country the language is named after/originates from, same choice
    // most language pickers (Duolingo etc.) settle on for the same reason.
    Q_INVOKABLE static QString flagEmoji(Language lang) {
        static const QHash<Language, QString> mapping = {
            {English,          QStringLiteral("🇬🇧")},
            {MandarinChinese,  QStringLiteral("🇨🇳")},
            {Hindi,            QStringLiteral("🇮🇳")},
            {Spanish,          QStringLiteral("🇪🇸")},
            {French,           QStringLiteral("🇫🇷")},
            {StandardArabic,   QStringLiteral("🇸🇦")},
            {Bengali,          QStringLiteral("🇧🇩")},
            {Russian,          QStringLiteral("🇷🇺")},
            {Portuguese,       QStringLiteral("🇵🇹")},
            {Urdu,             QStringLiteral("🇵🇰")},
            {German,           QStringLiteral("🇩🇪")},
            {Japanese,         QStringLiteral("🇯🇵")},
            {Italian,          QStringLiteral("🇮🇹")},
            {Dutch,            QStringLiteral("🇳🇱")},
            {Polish,           QStringLiteral("🇵🇱")},
            {Vietnamese,       QStringLiteral("🇻🇳")},
            {Ukrainian,        QStringLiteral("🇺🇦")},
            {Persian,          QStringLiteral("🇮🇷")},
            {Swedish,          QStringLiteral("🇸🇪")},
            {Finnish,          QStringLiteral("🇫🇮")},
            {Czech,            QStringLiteral("🇨🇿")},
            {Hungarian,        QStringLiteral("🇭🇺")},
            {Korean,           QStringLiteral("🇰🇷")},
            {Romanian,         QStringLiteral("🇷🇴")},
            {Norwegian,        QStringLiteral("🇳🇴")},
            {Turkish,          QStringLiteral("🇹🇷")},
            {Indonesian,       QStringLiteral("🇮🇩")},
            {Hebrew,           QStringLiteral("🇮🇱")},
            {Serbian,          QStringLiteral("🇷🇸")},
            {Danish,           QStringLiteral("🇩🇰")},
            {Bulgarian,        QStringLiteral("🇧🇬")},
            {Catalan,          QStringLiteral("🇪🇸")},
            {Slovak,           QStringLiteral("🇸🇰")},
            {Thai,             QStringLiteral("🇹🇭")},
            {Greek,            QStringLiteral("🇬🇷")},
            {Lithuanian,       QStringLiteral("🇱🇹")},
            {Croatian,         QStringLiteral("🇭🇷")},
            {Estonian,         QStringLiteral("🇪🇪")},
            {Latvian,          QStringLiteral("🇱🇻")},
            {Albanian,         QStringLiteral("🇦🇱")},
            {Georgian,         QStringLiteral("🇬🇪")},
            {Armenian,         QStringLiteral("🇦🇲")},
            {Azerbaijani,      QStringLiteral("🇦🇿")},
            {Kazakh,           QStringLiteral("🇰🇿")},
            {Belarusian,       QStringLiteral("🇧🇾")},
            {Basque,           QStringLiteral("🇪🇸")},
            {Galician,         QStringLiteral("🇪🇸")},
            {Welsh,            QStringLiteral("🇬🇧")},
            {Tamil,            QStringLiteral("🇮🇳")},
            {Malay,            QStringLiteral("🇲🇾")},
            {Marathi,          QStringLiteral("🇮🇳")},
            {Swahili,          QStringLiteral("🇹🇿")},
            {Slovenian,        QStringLiteral("🇸🇮")},
            {Icelandic,        QStringLiteral("🇮🇸")},
            {Filipino,         QStringLiteral("🇵🇭")},
            {Afrikaans,        QStringLiteral("🇿🇦")}
        };
        return mapping.value(lang, QStringLiteral("🏳️"));
    }

    // Best-effort match from the system/UI locale to one of our supported
    // languages, for picking a sensible interface language before the user
    // has ever chosen one explicitly. Matches on bare language code (e.g.
    // "pt_BR" and "pt_PT" both match Portuguese) since we don't distinguish
    // regional variants; falls back to English when nothing matches.
    Q_INVOKABLE static Language fromLocale(const QLocale &locale) {
        const QString code = locale.name().section('_', 0, 0);
        static const QHash<QString, Language> mapping = {
            {QStringLiteral("zh"), MandarinChinese},
            {QStringLiteral("hi"), Hindi},
            {QStringLiteral("es"), Spanish},
            {QStringLiteral("fr"), French},
            {QStringLiteral("ar"), StandardArabic},
            {QStringLiteral("bn"), Bengali},
            {QStringLiteral("ru"), Russian},
            {QStringLiteral("pt"), Portuguese},
            {QStringLiteral("ur"), Urdu},
            {QStringLiteral("de"), German},
            {QStringLiteral("ja"), Japanese},
            {QStringLiteral("it"), Italian},
            {QStringLiteral("nl"), Dutch},
            {QStringLiteral("pl"), Polish},
            {QStringLiteral("vi"), Vietnamese},
            {QStringLiteral("uk"), Ukrainian},
            {QStringLiteral("fa"), Persian},
            {QStringLiteral("sv"), Swedish},
            {QStringLiteral("fi"), Finnish},
            {QStringLiteral("cs"), Czech},
            {QStringLiteral("hu"), Hungarian},
            {QStringLiteral("ko"), Korean},
            {QStringLiteral("ro"), Romanian},
            {QStringLiteral("nb"), Norwegian},
            {QStringLiteral("nn"), Norwegian},
            {QStringLiteral("no"), Norwegian},
            {QStringLiteral("tr"), Turkish},
            {QStringLiteral("id"), Indonesian},
            {QStringLiteral("he"), Hebrew},
            {QStringLiteral("iw"), Hebrew},
            {QStringLiteral("sr"), Serbian},
            {QStringLiteral("da"), Danish},
            {QStringLiteral("bg"), Bulgarian},
            {QStringLiteral("ca"), Catalan},
            {QStringLiteral("sk"), Slovak},
            {QStringLiteral("th"), Thai},
            {QStringLiteral("el"), Greek},
            {QStringLiteral("lt"), Lithuanian},
            {QStringLiteral("hr"), Croatian},
            {QStringLiteral("et"), Estonian},
            {QStringLiteral("lv"), Latvian},
            {QStringLiteral("sq"), Albanian},
            {QStringLiteral("ka"), Georgian},
            {QStringLiteral("hy"), Armenian},
            {QStringLiteral("az"), Azerbaijani},
            {QStringLiteral("kk"), Kazakh},
            {QStringLiteral("be"), Belarusian},
            {QStringLiteral("eu"), Basque},
            {QStringLiteral("gl"), Galician},
            {QStringLiteral("cy"), Welsh},
            {QStringLiteral("ta"), Tamil},
            {QStringLiteral("ms"), Malay},
            {QStringLiteral("mr"), Marathi},
            {QStringLiteral("sw"), Swahili},
            {QStringLiteral("sl"), Slovenian},
            {QStringLiteral("is"), Icelandic},
            {QStringLiteral("fil"), Filipino},
            {QStringLiteral("tl"), Filipino},
            {QStringLiteral("af"), Afrikaans}
        };
        return mapping.value(code, English);
    }

    // Qt's QML_SINGLETON machinery only recognizes a static factory method
    // named exactly "create" — this doesn't currently need the engine
    // pointer, but naming it correctly avoids silently falling back to
    // default construction (see AppController::create for a case where
    // that fallback broke real behavior).
    static QObject* create(QQmlEngine*, QJSEngine*)
    {
        return new LanguageHelper();
    }
};
