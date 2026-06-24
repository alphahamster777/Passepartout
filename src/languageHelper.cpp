#include "languageHelper.h"
#include <algorithm>

LanguageHelper::LanguageHelper(QObject *parent) : QObject{parent} {}

QVariantList LanguageHelper::sortedLanguageEntries()
{
    const QStringList names = languageNames();
    QVariantList entries;
    entries.reserve(names.size());

    for (int i = 0; i < names.size(); ++i) {
        if (i == static_cast<int>(NotSelected)) continue;
        entries.append(QVariantMap{{"name", names[i]}, {"id", i}});
    }

    std::sort(entries.begin(), entries.end(), [](const QVariant& a, const QVariant& b) {
        return a.toMap().value(QStringLiteral("name")).toString()
             < b.toMap().value(QStringLiteral("name")).toString();
    });

    entries.append(QVariantMap{
        {"name", names[static_cast<int>(NotSelected)]},
        {"id",   static_cast<int>(NotSelected)}
    });

    return entries;
}
