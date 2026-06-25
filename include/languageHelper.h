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

    static QObject* qmlInstance(QQmlEngine*, QJSEngine*)
    {
        return new LanguageHelper();
    }
};
