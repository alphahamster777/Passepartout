#include "geminiHelper.h"

#include "languageHelper.h"

#include <QJsonArray>
#include <QJsonDocument>
#include <QJsonObject>
#include <QNetworkReply>
#include <QNetworkRequest>
#include <QSettings>
#include <QUrl>
#include <QUrlQuery>

namespace {
// Free-tier Gemini model as of this writing. Change here if Google renames
// or retires it — nothing else in this file needs to know the model name.
constexpr auto kModel = "gemini-3.6-flash";
constexpr auto kApiKeySettingsKey = "Gemini/apiKey";
}

GeminiHelper::GeminiHelper(QObject* parent)
    : QObject(parent)
    , m_nam(new QNetworkAccessManager(this))
{
    m_apiKey = QSettings().value(QLatin1String(kApiKeySettingsKey)).toString();
}

void GeminiHelper::setApiKey(const QString& key) {
    if (m_apiKey == key)
        return;
    m_apiKey = key;
    QSettings().setValue(QLatin1String(kApiKeySettingsKey), key);
    emit apiKeyChanged();
}

void GeminiHelper::cancelGeneration() {
    if (!m_currentReply)
        return;
    m_cancelled = true;
    m_currentReply->abort();
}

void GeminiHelper::setGenerating(bool value) {
    if (m_generating == value)
        return;
    m_generating = value;
    emit generatingChanged();
}

void GeminiHelper::generateWordSet(const QString& theme, int fromLanguageId,
                                    int toLanguageId, int wordCount) {
    if (m_apiKey.isEmpty()) {
        emit generationFailed(tr("No Gemini API key set."));
        return;
    }
    if (theme.trimmed().isEmpty()) {
        emit generationFailed(tr("Enter a theme first."));
        return;
    }

    const QString fromLang = LanguageHelper::displayName(static_cast<LanguageHelper::Language>(fromLanguageId));
    const QString toLang   = LanguageHelper::displayName(static_cast<LanguageHelper::Language>(toLanguageId));
    const int count = qBound(1, wordCount, 30);

    const QString prompt = QStringLiteral(
        "Generate exactly %1 vocabulary flashcards for a language learner on the theme \"%2\".\n"
        "\"expression\" must be a single word or short phrase in %3.\n"
        "\"hint\" must be its translation or definition in %4.\n"
        "\"exampleUsage\" must be one short example sentence in %3 that uses the expression.\n"
        "Do not repeat words. Keep entries concise.")
        .arg(count).arg(theme.trimmed(), fromLang, toLang);

    const QJsonObject schemaItem{
        {QStringLiteral("type"), QStringLiteral("OBJECT")},
        {QStringLiteral("properties"), QJsonObject{
            {QStringLiteral("expression"),   QJsonObject{{QStringLiteral("type"), QStringLiteral("STRING")}}},
            {QStringLiteral("hint"),         QJsonObject{{QStringLiteral("type"), QStringLiteral("STRING")}}},
            {QStringLiteral("exampleUsage"), QJsonObject{{QStringLiteral("type"), QStringLiteral("STRING")}}}
        }},
        {QStringLiteral("required"), QJsonArray{QStringLiteral("expression"), QStringLiteral("hint"), QStringLiteral("exampleUsage")}}
    };
    const QJsonObject schema{
        {QStringLiteral("type"), QStringLiteral("OBJECT")},
        {QStringLiteral("properties"), QJsonObject{
            {QStringLiteral("words"), QJsonObject{
                {QStringLiteral("type"), QStringLiteral("ARRAY")},
                {QStringLiteral("items"), schemaItem}
            }}
        }},
        {QStringLiteral("required"), QJsonArray{QStringLiteral("words")}}
    };

    const QJsonObject body{
        {QStringLiteral("contents"), QJsonArray{
            QJsonObject{
                {QStringLiteral("role"), QStringLiteral("user")},
                {QStringLiteral("parts"), QJsonArray{QJsonObject{{QStringLiteral("text"), prompt}}}}
            }
        }},
        {QStringLiteral("generationConfig"), QJsonObject{
            {QStringLiteral("responseMimeType"), QStringLiteral("application/json")},
            {QStringLiteral("responseSchema"), schema}
        }}
    };

    QUrl url(QStringLiteral("https://generativelanguage.googleapis.com/v1beta/models/%1:generateContent")
                 .arg(QLatin1String(kModel)));
    QUrlQuery query;
    query.addQueryItem(QStringLiteral("key"), m_apiKey);
    url.setQuery(query);

    QNetworkRequest req(url);
    req.setHeader(QNetworkRequest::ContentTypeHeader, QStringLiteral("application/json"));
    // Without this, a Gemini request that never gets a response (dropped
    // connection, stalled server) would hang indefinitely with no way for the
    // UI to know anything went wrong short of the user cancelling.
    req.setTransferTimeout(20000);

    setGenerating(true);
    m_cancelled = false;
    auto* reply = m_nam->post(req, QJsonDocument(body).toJson(QJsonDocument::Compact));
    m_currentReply = reply;
    connect(reply, &QNetworkReply::finished, this, [this, reply, fromLanguageId, toLanguageId]() {
        reply->deleteLater();
        setGenerating(false);
        if (m_currentReply == reply)
            m_currentReply = nullptr;

        const bool wasCancelled = m_cancelled;
        m_cancelled = false;
        if (wasCancelled)
            return;

        if (reply->error() != QNetworkReply::NoError) {
            emit generationFailed(reply->errorString() + QStringLiteral(" — ") + QString::fromUtf8(reply->readAll()));
            return;
        }

        const auto root = QJsonDocument::fromJson(reply->readAll()).object();
        const auto candidates = root[QStringLiteral("candidates")].toArray();
        if (candidates.isEmpty()) {
            emit generationFailed(tr("Gemini returned no result."));
            return;
        }
        const auto parts = candidates.first().toObject()[QStringLiteral("content")].toObject()
                                [QStringLiteral("parts")].toArray();
        if (parts.isEmpty()) {
            emit generationFailed(tr("Gemini returned an empty response."));
            return;
        }
        const QString text = parts.first().toObject()[QStringLiteral("text")].toString();
        const auto payload = QJsonDocument::fromJson(text.toUtf8()).object();
        const auto words = payload[QStringLiteral("words")].toArray();
        if (words.isEmpty()) {
            emit generationFailed(tr("Gemini returned no words."));
            return;
        }

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
        emit wordSetGenerated(result);
    });
}
