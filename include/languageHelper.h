#pragma once

#include <QObject>
#include <QtQml/qqml.h>
#include <QStringList>

class LanguageHelper : public QObject
{
    Q_OBJECT
    QML_ELEMENT
    QML_SINGLETON
public:
    enum Language {
        English,
        MandarinChinese,
        Hindi,
        Spanish,
        French,
        StandardArabic,
        Bengali,
        Russian,
        Portuguese,
        Urdu,
        NotSelected
    };
    Q_ENUM(Language)

    explicit LanguageHelper(QObject *parent = nullptr);

    // Return a QStringList of all enum‐names (exactly matching the Q_ENUM keys).
    Q_INVOKABLE static QStringList languageNames() {
        // Note: The order here must match the enum declaration order.
        return {
            "English",
            "Mandarin Chinese",
            "Hindi",
            "Spanish",
            "French",
            "Standard Arabic",
            "Bengali",
            "Russian",
            "Portuguese",
            "Urdu",
            "Not selected"
        };
    }

    Q_INVOKABLE static Language languageFromString(const QString &name) {
        static const QHash<QString, Language> mapping = {
            {"English", English},
            {"Mandarin Chinese", MandarinChinese},
            {"Hindi", Hindi},
            {"Spanish", Spanish},
            {"French", French},
            {"Standard Arabic", StandardArabic},
            {"Bengali", Bengali},
            {"Russian", Russian},
            {"Portuguese", Portuguese},
            {"Urdu", Urdu},
            {"Not selected", NotSelected}
        };
        return mapping.value(name, NotSelected);
    }

    // mapping function for user-friendly display string:
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
        default:               return QStringLiteral("Other");
        }
    }

    static QObject* qmlInstance(QQmlEngine*, QJSEngine*)
    {
        // Qt will call this exactly once and keep the returned pointer as “the”
        // singleton. Do not call “new AppController” anywhere else.
        return new LanguageHelper();
    }
};
