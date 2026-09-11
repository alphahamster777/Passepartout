#pragma once

#include <QObject>
#include <QNetworkAccessManager>
#include <QVariantList>
#include <QtQml/qqml.h>

// Talks to the Gemini API directly from the client. This is the first,
// local-testing phase of AI word-set generation — the API key lives only in
// this device's QSettings. A later phase moves the key and the request behind
// a small backend (first localhost, then a deployed server with auth) so a
// client-embedded key is never required.
class GeminiHelper : public QObject {
    Q_OBJECT
    QML_ELEMENT
    QML_SINGLETON

    Q_PROPERTY(QString apiKey READ apiKey WRITE setApiKey NOTIFY apiKeyChanged)
    Q_PROPERTY(bool generating READ isGenerating NOTIFY generatingChanged)

public:
    explicit GeminiHelper(QObject* parent = nullptr);

    QString apiKey() const { return m_apiKey; }
    void setApiKey(const QString& key);

    bool isGenerating() const { return m_generating; }

    // Asks Gemini for `wordCount` vocabulary entries on `theme`. `expression`
    // comes back in fromLanguageId, `hint` in toLanguageId (LanguageHelper::Language
    // ordinals). Emits wordSetGenerated on success, generationFailed on error.
    Q_INVOKABLE void generateWordSet(const QString& theme, int fromLanguageId,
                                      int toLanguageId, int wordCount);

    // Aborts the in-flight request, if any. Safe to call when nothing is running.
    // No generationFailed follows a user-initiated cancel.
    Q_INVOKABLE void cancelGeneration();

    // Must be named "create" — that's the only name Qt's QML_SINGLETON
    // machinery recognizes as a custom factory; anything else is silently
    // ignored in favor of default-constructing the singleton instead.
    static QObject* create(QQmlEngine*, QJSEngine*) { return new GeminiHelper(); }

signals:
    void apiKeyChanged();
    void generatingChanged();
    void wordSetGenerated(const QVariantList& words);
    void generationFailed(const QString& error);

private:
    void setGenerating(bool value);

    QNetworkAccessManager* m_nam;
    QString m_apiKey;
    bool m_generating = false;
    QNetworkReply* m_currentReply = nullptr;
    bool m_cancelled = false;
};
