#include "aiWordSetShared.h"

#include "languageHelper.h"

#include <QJsonArray>
#include <QJsonDocument>
#include <algorithm>

namespace AiWordSetShared {

QString buildPrompt(const QString& theme, int fromLanguageId, int toLanguageId, int wordCount) {
    const QString fromLang = LanguageHelper::displayName(static_cast<LanguageHelper::Language>(fromLanguageId));
    const QString toLang   = LanguageHelper::displayName(static_cast<LanguageHelper::Language>(toLanguageId));
    const int count = std::clamp(wordCount, 1, kMaxWordCount);
    const QString clippedTheme = theme.trimmed().left(kMaxThemeLength);

    return QStringLiteral(
        "Generate exactly %1 vocabulary flashcards for a language learner on the theme \"%2\".\n"
        "\"expression\" must be a single word or short phrase in %3.\n"
        "\"hint\" must be its translation or definition in %4.\n"
        "\"exampleUsage\" must be one short example sentence in %3 that uses the expression.\n"
        "Do not repeat words. Keep entries concise.")
        .arg(count).arg(clippedTheme, fromLang, toLang);
}

QJsonObject buildResponseSchema() {
    const QJsonObject schemaItem{
        {QStringLiteral("type"), QStringLiteral("OBJECT")},
        {QStringLiteral("properties"), QJsonObject{
            {QStringLiteral("expression"),   QJsonObject{{QStringLiteral("type"), QStringLiteral("STRING")}}},
            {QStringLiteral("hint"),         QJsonObject{{QStringLiteral("type"), QStringLiteral("STRING")}}},
            {QStringLiteral("exampleUsage"), QJsonObject{{QStringLiteral("type"), QStringLiteral("STRING")}}}
        }},
        {QStringLiteral("required"), QJsonArray{QStringLiteral("expression"), QStringLiteral("hint"), QStringLiteral("exampleUsage")}}
    };
    return QJsonObject{
        {QStringLiteral("type"), QStringLiteral("OBJECT")},
        {QStringLiteral("properties"), QJsonObject{
            {QStringLiteral("words"), QJsonObject{
                {QStringLiteral("type"), QStringLiteral("ARRAY")},
                {QStringLiteral("items"), schemaItem}
            }}
        }},
        {QStringLiteral("required"), QJsonArray{QStringLiteral("words")}}
    };
}

QVariantList parseWords(const QJsonArray& words, int fromLanguageId, int toLanguageId) {
    QVariantList result;
    result.reserve(words.size());
    for (const auto& w : words) {
        const auto obj = w.toObject();
        QVariantMap rec;
        rec[QStringLiteral("languageFrom")] = fromLanguageId;
        rec[QStringLiteral("languageTo")]   = toLanguageId;
        rec[QStringLiteral("expression")]   = obj[QStringLiteral("expression")].toString();
        rec[QStringLiteral("hint")]         = obj[QStringLiteral("hint")].toString();
        rec[QStringLiteral("exampleUsage")] = obj[QStringLiteral("exampleUsage")].toString();
        rec[QStringLiteral("audioPath")]    = QString();
        rec[QStringLiteral("imagePath")]    = QString();
        result.append(rec);
    }
    return result;
}

QVariantList parseWords(const QString& jsonText, int fromLanguageId, int toLanguageId) {
    const auto payload = QJsonDocument::fromJson(jsonText.toUtf8()).object();
    return parseWords(payload[QStringLiteral("words")].toArray(), fromLanguageId, toLanguageId);
}

}
