#pragma once

#include <QJsonObject>
#include <QNetworkAccessManager>
#include <QObject>
#include <QVariantList>
#include <QtQml/qqml.h>

#include <functional>

// Talks to a Firebase Cloud Function that: verifies a Firebase Auth ID
// token, checks/increments a per-user monthly counter in Firestore, and only
// then calls Gemini and returns the words. The Gemini key lives only in the
// function's environment — never on this device — and usage is capped per
// user, unlike GeminiHelper's direct-call path (kept around for offline/
// no-deployment-needed local testing).
//
// Which of two quotas applies (functions/main.py's FREE_MONTHLY_LIMIT vs
// PRO_MONTHLY_LIMIT) is decided entirely by which Cloud Function URL this
// build was compiled with — see PASSEPARTOUT_TIER in CMakeLists.txt and the
// kFunctionUrl #if in the .cpp. There's no runtime "am I pro" flag.
//
// Everything here is plain HTTPS via QNetworkAccessManager (Firebase
// Authentication's REST API for anonymous sign-in, then a normal POST to the
// function), so — unlike an approach built on Firebase's native client SDKs
// — this works identically on every Qt platform without any per-platform
// native bridge.
//
// The Web API Key and Cloud Function URL are hardcoded in the .cpp — neither
// is a secret (Firebase's own docs say the Web API Key is safe to embed;
// the function URL is a public HTTPS endpoint that does nothing without a
// valid ID token), so there's no reason to make the user paste them in.
class FirebaseAiHelper : public QObject {
    Q_OBJECT
    QML_ELEMENT
    QML_SINGLETON

    Q_PROPERTY(bool generating READ isGenerating NOTIFY generatingChanged)
    // Remaining generations the signed-in user has left this month, the
    // monthly cap, and when it resets (ISO 8601 UTC) — -1 for
    // remaining/monthlyLimit until the first quota check/generation of this
    // session comes back, since Firestore is the source of truth and
    // there's nothing useful to guess before asking it.
    Q_PROPERTY(int remaining READ remaining NOTIFY quotaChanged)
    Q_PROPERTY(int monthlyLimit READ monthlyLimit NOTIFY quotaChanged)
    Q_PROPERTY(QString resetAt READ resetAt NOTIFY quotaChanged)

public:
    explicit FirebaseAiHelper(QObject* parent = nullptr);

    bool isGenerating() const { return m_generating; }
    int remaining() const { return m_remaining; }
    int monthlyLimit() const { return m_monthlyLimit; }
    QString resetAt() const { return m_resetAt; }

    Q_INVOKABLE void generateWordSet(const QString& theme, int fromLanguageId,
                                      int toLanguageId, int wordCount);
    Q_INVOKABLE void cancelGeneration();

    // Fetches remaining/monthlyLimit/resetAt without generating anything —
    // call when the AI dialog opens so the counter is populated before the
    // first Generate tap of the session. Fails silently (no generationFailed
    // emission) since it's a background convenience, not a user action.
    Q_INVOKABLE void refreshQuota();

    static QObject* qmlInstance(QQmlEngine*, QJSEngine*) { return new FirebaseAiHelper(); }

signals:
    void generatingChanged();
    void quotaChanged();
    void wordSetGenerated(const QVariantList& words);
    void generationFailed(const QString& error);

private:
    void setGenerating(bool value);

    // Reuses a still-valid ID token, refreshes an expired one, or signs in a
    // new anonymous user if there's no refresh token yet — then calls
    // `onReady` with either (true, idToken) or (false, errorString).
    void ensureSignedIn(std::function<void(bool ok, const QString& idTokenOrError)> onReady);
    void signInAnonymously(std::function<void(bool ok, const QString& idTokenOrError)> onReady);
    void refreshIdToken(std::function<void(bool ok, const QString& idTokenOrError)> onReady);
    void storeAuthResponse(const QJsonObject& obj, bool isRefreshResponse);
    void applyQuota(const QJsonObject& payload);

    void postGenerate(const QString& idToken, const QString& theme,
                       int fromLanguageId, int toLanguageId, int wordCount);

    QNetworkAccessManager* m_nam;

    QString m_idToken;
    QString m_refreshToken;
    qint64 m_idTokenExpiryEpochMs = 0;

    QNetworkReply* m_currentReply = nullptr;
    bool m_cancelled = false;
    bool m_generating = false;

    int m_remaining = -1;
    int m_monthlyLimit = -1;
    QString m_resetAt;
};
