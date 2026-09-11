#include "languageHelper.h"
#include <algorithm>

LanguageHelper::LanguageHelper(QObject *parent) : QObject{parent} {}

QVariantList LanguageHelper::sortedLanguageEntries()
{
    const QStringList names = languageNames();
    QVariantList entries;
    entries.reserve(names.size());

    for (int i = 0; i < names.size(); ++i) {
        const auto lang = static_cast<Language>(i);
        entries.append(QVariantMap{
            {"name", names[i]},
            {"id",   i},
            {"code", localeCode(lang)},
            {"flag", flagEmoji(lang)}
        });
    }

    std::sort(entries.begin(), entries.end(), [](const QVariant& a, const QVariant& b) {
        return a.toMap().value(QStringLiteral("name")).toString()
             < b.toMap().value(QStringLiteral("name")).toString();
    });

    entries.append(QVariantMap{
        {"name", QStringLiteral("Not selected")},
        {"id",   static_cast<int>(NotSelected)},
        {"code", QStringLiteral("")},
        {"flag", QStringLiteral("")}
    });

    return entries;
}
