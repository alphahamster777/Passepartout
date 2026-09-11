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
// Sign-in is mandatory and handled entirely by GoogleSignInHelper (Apple
// later) — this class no longer creates anonymous accounts itself. It just
// persists whatever session GoogleSignInHelper hands it (adoptSignIn()) and
// refreshes that session's token as needed; if there's no session yet,
// generateWordSet()/refreshQuota() fail with "not signed in" instead of
// silently signing someone in.
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
    // True once a session from GoogleSignInHelper has been adopted. QML uses
    // this to decide whether to show the AI dialog or a sign-in prompt.
    Q_PROPERTY(bool signedIn READ isSignedIn NOTIFY signedInChanged)

public:
    explicit FirebaseAiHelper(QObject* parent = nullptr);

    bool isGenerating() const { return m_generating; }
    int remaining() const { return m_remaining; }
    int monthlyLimit() const { return m_monthlyLimit; }
    QString resetAt() const { return m_resetAt; }
    bool isSignedIn() const { return !m_refreshToken.isEmpty(); }

    Q_INVOKABLE void generateWordSet(const QString& theme, int fromLanguageId,
                                      int toLanguageId, int wordCount);
    Q_INVOKABLE void cancelGeneration();

    // Fetches remaining/monthlyLimit/resetAt without generating anything —
    // call when the AI dialog opens so the counter is populated before the
    // first Generate tap of the session. Fails silently (no generationFailed
    // emission) since it's a background convenience, not a user action.
    Q_INVOKABLE void refreshQuota();

    // Persists a session obtained elsewhere (GoogleSignInHelper's OAuth
    // flow) — wired via a QML Connections block to that class's
    // signInSucceeded signal, keeping the two singletons decoupled in C++.
    Q_INVOKABLE void adoptSignIn(const QString& idToken, const QString& refreshToken,
                                  int expiresInSeconds);

    // Clears the local session. Does not revoke it server-side (Identity
    // Toolkit has no simple REST "log out" — the refresh token just stops
    // being used); good enough for "switch accounts" on this device.
    Q_INVOKABLE void signOut();

    // Must be named "create" — that's the only name Qt's QML_SINGLETON
    // machinery recognizes as a custom factory; anything else is silently
    // ignored in favor of default-constructing the singleton instead.
    static QObject* create(QQmlEngine*, QJSEngine*) { return new FirebaseAiHelper(); }

signals:
    void generatingChanged();
    void quotaChanged();
    void signedInChanged();
    void wordSetGenerated(const QVariantList& words);
    void generationFailed(const QString& error);

private:
    void setGenerating(bool value);

    // Reuses a still-valid ID token, or refreshes an expired one — calls
    // `onReady` with (true, idToken), or (false, "not signed in"/an error)
    // if there's no session at all or the refresh fails.
    void ensureSignedIn(std::function<void(bool ok, const QString& idTokenOrError)> onReady);
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
