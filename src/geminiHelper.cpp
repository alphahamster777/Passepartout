#include "geminiHelper.h"

#include "aiWordSetShared.h"
#include "contentFilter.h"

#include <QJsonArray>
#include <QJsonDocument>
#include <QJsonObject>
#include <QNetworkReply>
#include <QNetworkRequest>
#include <QSettings>
#include <QUrl>
#include <QUrlQuery>

namespace {
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
    // Same refusal the Cloud Function gives (functions/main.py's
    // CONTENT_REFUSED_MESSAGE) — see its "Content safety" section.
    if (ContentFilter::containsRestrictedTerm(theme)) {
        emit generationFailed(tr("This theme can't be generated. Passepartout's AI only creates content "
                                 "suitable for all ages — sexual, profane or offensive topics aren't "
                                 "supported. Try a different theme."));
        return;
    }

    QJsonArray safetySettings;
    for (const auto* category : {"HARM_CATEGORY_SEXUALLY_EXPLICIT", "HARM_CATEGORY_HARASSMENT",
                                 "HARM_CATEGORY_HATE_SPEECH", "HARM_CATEGORY_DANGEROUS_CONTENT"}) {
        safetySettings.append(QJsonObject{
            {QStringLiteral("category"), QLatin1String(category)},
            {QStringLiteral("threshold"), QStringLiteral("BLOCK_LOW_AND_ABOVE")}
        });
    }

    const QJsonObject body{
        {QStringLiteral("contents"), QJsonArray{
            QJsonObject{
                {QStringLiteral("role"), QStringLiteral("user")},
                {QStringLiteral("parts"), QJsonArray{QJsonObject{
                    {QStringLiteral("text"), AiWordSetShared::buildPrompt(theme, fromLanguageId, toLanguageId, wordCount)}
                }}}
            }
        }},
        {QStringLiteral("safetySettings"), safetySettings},
        {QStringLiteral("generationConfig"), QJsonObject{
            {QStringLiteral("responseMimeType"), QStringLiteral("application/json")},
            {QStringLiteral("responseSchema"), AiWordSetShared::buildResponseSchema()}
        }}
    };

    QUrl url(QStringLiteral("https://generativelanguage.googleapis.com/v1beta/models/%1:generateContent")
                 .arg(QLatin1String(AiWordSetShared::kModelName)));
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
        QVariantList result = AiWordSetShared::parseWords(text, fromLanguageId, toLanguageId);
        result.removeIf([](const QVariant& word) {
            const auto map = word.toMap();
            return ContentFilter::containsRestrictedTerm(map.value(QStringLiteral("expression")).toString()
                                                         + QLatin1Char('\n') + map.value(QStringLiteral("hint")).toString()
                                                         + QLatin1Char('\n') + map.value(QStringLiteral("exampleUsage")).toString());
        });
        if (result.isEmpty()) {
            emit generationFailed(tr("Gemini returned no words."));
            return;
        }
        emit wordSetGenerated(result);
    });
}
