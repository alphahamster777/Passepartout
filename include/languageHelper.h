#pragma once

#include <QObject>
#include <QtQml/qqml.h>
#include <QStringList>
#include <QVariantList>

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
        NotSelected     = 10,
        German          = 11,
        Japanese        = 12,
        Italian         = 13,
        Dutch           = 14,
        Polish          = 15,
        Vietnamese      = 16,
        Ukrainian       = 17,
        Persian         = 18,
        Swedish         = 19,
        Finnish         = 20,
        Czech           = 21,
        Hungarian       = 22,
        Korean          = 23,
        Romanian        = 24,
        Norwegian       = 25,
        Turkish         = 26,
        Indonesian      = 27,
        Hebrew          = 28,
        Serbian         = 29,
        Danish          = 30,
        Bulgarian       = 31,
        Catalan         = 32,
        Slovak          = 33,
        Thai            = 34,
        Greek           = 35,
        Lithuanian      = 36,
        Croatian        = 37,
        Estonian        = 38,
        Latvian         = 39,
        Albanian        = 40,
        Georgian        = 41,
        Armenian        = 42,
        Azerbaijani     = 43,
        Kazakh          = 44,
        Belarusian      = 45,
        Basque          = 46,
        Galician        = 47,
        Welsh           = 48,
        Tamil           = 49,
        Malay           = 50,
        Marathi         = 51,
        Swahili         = 52,
        Slovenian       = 53,
        Icelandic       = 54,
        Filipino        = 55,
        Afrikaans       = 56
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
            "Not selected",     // 10
            "German",           // 11
            "Japanese",         // 12
            "Italian",          // 13
            "Dutch",            // 14
            "Polish",           // 15
            "Vietnamese",       // 16
            "Ukrainian",        // 17
            "Persian",          // 18
            "Swedish",          // 19
            "Finnish",          // 20
            "Czech",            // 21
            "Hungarian",        // 22
            "Korean",           // 23
            "Romanian",         // 24
            "Norwegian",        // 25
            "Turkish",          // 26
            "Indonesian",       // 27
            "Hebrew",           // 28
            "Serbian",          // 29
            "Danish",           // 30
            "Bulgarian",        // 31
            "Catalan",          // 32
            "Slovak",           // 33
            "Thai",             // 34
            "Greek",            // 35
            "Lithuanian",       // 36
            "Croatian",         // 37
            "Estonian",         // 38
            "Latvian",          // 39
            "Albanian",         // 40
            "Georgian",         // 41
            "Armenian",         // 42
            "Azerbaijani",      // 43
            "Kazakh",           // 44
            "Belarusian",       // 45
            "Basque",           // 46
            "Galician",         // 47
            "Welsh",            // 48
            "Tamil",            // 49
            "Malay",            // 50
            "Marathi",          // 51
            "Swahili",          // 52
            "Slovenian",        // 53
            "Icelandic",        // 54
            "Filipino",         // 55
            "Afrikaans"         // 56
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
        default:               return QStringLiteral("Other");
        }
    }

    static QObject* qmlInstance(QQmlEngine*, QJSEngine*)
    {
        return new LanguageHelper();
    }
};
