#pragma once

#include <QObject>
#include <QNetworkAccessManager>
#include <QtQml/qqml.h>

// Mandatory Google Sign-In via a browser-based OAuth 2.0 + PKCE flow — the
// standard approach for a "public" client (a distributed app can't safely
// embed a client secret the way a server could). No native Google Sign-In
// SDK involved, so this stays cross-platform the same way the rest of the
// Firebase integration does; Apple Sign-In will follow the same shape later.
//
// Flow: generate a PKCE pair -> open the system browser to Google's
// consent screen -> Google redirects to our registered custom-scheme URI
// -> Android brings this already-running app back to the foreground with
// that as its new Intent -> since there's no push notification for that
// into QML (see checkForPendingRedirect()'s comment), we poll for it when
// the app resumes -> exchange the resulting code for a Google ID token,
// then that for a Firebase ID token via Identity Toolkit's signInWithIdp,
// and emit the result for FirebaseAiHelper to adopt.
//
// REQUIRES SETUP: kGoogleOAuthClientId / kGoogleOAuthRedirectUri in the .cpp
// are placeholders. Create an OAuth 2.0 Client ID of type "iOS" in Google
// Cloud Console (Firebase Console enabling "Google" as a sign-in provider
// auto-creates a Web one, but this flow needs the "iOS" type specifically —
// it's the one Google documents for installed-app/custom-scheme redirects
// without a client secret) and fill in both constants, plus the matching
// intent-filter in android/AndroidManifest.xml, before this can work.
class GoogleSignInHelper : public QObject {
    Q_OBJECT
    QML_ELEMENT
    QML_SINGLETON

    Q_PROPERTY(bool signingIn READ isSigningIn NOTIFY signingInChanged)

public:
    explicit GoogleSignInHelper(QObject* parent = nullptr);

    bool isSigningIn() const { return m_signingIn; }

    // Opens the system browser to Google's consent screen.
    Q_INVOKABLE void beginSignIn();

    // Polls the current Activity's Intent for our pending OAuth redirect.
    // Android delivers the redirect via onNewIntent() on the already-running
    // app when the browser hands control back, but nothing in this project
    // re-publishes that as a Qt signal — so call this whenever the app
    // becomes active again (see Main.qml's Qt.application.state handling).
    // Safe to call anytime; a no-op if there's no sign-in in flight or no
    // matching pending intent.
    Q_INVOKABLE void checkForPendingRedirect();

    static QObject* qmlInstance(QQmlEngine*, QJSEngine*) { return new GoogleSignInHelper(); }

signals:
    void signingInChanged();
    void signInFailed(const QString& error);
    // idToken/refreshToken/expiresInSeconds are a Firebase session, ready for
    // FirebaseAiHelper.adoptSignIn() — wired via a QML Connections block
    // rather than a direct C++ dependency between the two singletons.
    void signInSucceeded(const QString& idToken, const QString& refreshToken, int expiresInSeconds);

private:
    void setSigningIn(bool value);
    void exchangeCodeForGoogleToken(const QString& code, const QString& codeVerifier);
    void exchangeGoogleTokenForFirebase(const QString& googleIdToken);
    void fail(const QString& error);

    QNetworkAccessManager* m_nam;
    QString m_pendingCodeVerifier;
    QString m_pendingState;
    bool m_signingIn = false;
};
