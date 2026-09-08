#include "googleSignInHelper.h"

#include "firebaseConfig.h"

#include <QCryptographicHash>
#include <QDesktopServices>
#include <QJsonDocument>
#include <QJsonObject>
#include <QNetworkReply>
#include <QNetworkRequest>
#include <QRandomGenerator>
#include <QUrl>
#include <QUrlQuery>

#ifdef Q_OS_ANDROID
#include <QJniObject>
#include <QJniEnvironment>
#endif

namespace {
// "iOS"-type OAuth 2.0 Client ID created in Google Cloud Console, project
// Passepartout (passepartout-ca98f) — see googleSignInHelper.h's class
// comment for why that client type is used for an Android/PKCE flow.
constexpr auto kGoogleOAuthClientId =
    "675677561526-ggr3uedrnqv9u0a8kaduk14hhu52esf1.apps.googleusercontent.com";
// Google's documented pattern for that client type: the reversed client ID
// as a custom URL scheme. Also registered as an intent-filter in
// android/AndroidManifest.xml.
constexpr auto kGoogleOAuthRedirectUri =
    "com.googleusercontent.apps.675677561526-ggr3uedrnqv9u0a8kaduk14hhu52esf1:/oauth2redirect";

constexpr auto kGoogleAuthEndpoint = "https://accounts.google.com/o/oauth2/v2/auth";
constexpr auto kGoogleTokenEndpoint = "https://oauth2.googleapis.com/token";
constexpr auto kFirebaseSignInWithIdpEndpoint =
    "https://identitytoolkit.googleapis.com/v1/accounts:signInWithIdp";

QString randomUrlSafeString(int numBytes) {
    QByteArray bytes(numBytes, Qt::Uninitialized);
    for (int i = 0; i < numBytes; ++i)
        bytes[i] = static_cast<char>(QRandomGenerator::global()->bounded(256));
    return QString::fromLatin1(bytes.toBase64(QByteArray::Base64UrlEncoding | QByteArray::OmitTrailingEquals));
}

QString codeChallengeFor(const QString& codeVerifier) {
    const QByteArray hash = QCryptographicHash::hash(codeVerifier.toUtf8(), QCryptographicHash::Sha256);
    return QString::fromLatin1(hash.toBase64(QByteArray::Base64UrlEncoding | QByteArray::OmitTrailingEquals));
}
}

GoogleSignInHelper::GoogleSignInHelper(QObject* parent)
    : QObject(parent)
    , m_nam(new QNetworkAccessManager(this))
{
}

void GoogleSignInHelper::setSigningIn(bool value) {
    if (m_signingIn == value)
        return;
    m_signingIn = value;
    emit signingInChanged();
}

void GoogleSignInHelper::fail(const QString& error) {
    m_pendingCodeVerifier.clear();
    m_pendingState.clear();
    setSigningIn(false);
    emit signInFailed(error);
}

void GoogleSignInHelper::beginSignIn() {
    m_pendingCodeVerifier = randomUrlSafeString(32);
    m_pendingState = randomUrlSafeString(16);
    setSigningIn(true);

    QUrl url{QLatin1String(kGoogleAuthEndpoint)};
    QUrlQuery query;
    query.addQueryItem(QStringLiteral("client_id"), QLatin1String(kGoogleOAuthClientId));
    query.addQueryItem(QStringLiteral("redirect_uri"), QLatin1String(kGoogleOAuthRedirectUri));
    query.addQueryItem(QStringLiteral("response_type"), QStringLiteral("code"));
    query.addQueryItem(QStringLiteral("scope"), QStringLiteral("openid email profile"));
    query.addQueryItem(QStringLiteral("code_challenge"), codeChallengeFor(m_pendingCodeVerifier));
    query.addQueryItem(QStringLiteral("code_challenge_method"), QStringLiteral("S256"));
    query.addQueryItem(QStringLiteral("state"), m_pendingState);
    url.setQuery(query);

    // QDesktopServices::openUrl launches the system browser on every Qt
    // platform, Android included (via an ACTION_VIEW intent under the hood),
    // so no JNI is needed just to get the consent screen open.
    QDesktopServices::openUrl(url);
}

void GoogleSignInHelper::checkForPendingRedirect() {
    if (m_pendingCodeVerifier.isEmpty())
        return; // no sign-in in flight

#ifdef Q_OS_ANDROID
    QJniObject activity = QJniObject::callStaticObjectMethod(
        "org/qtproject/qt/android/QtNative", "activity", "()Landroid/app/Activity;");
    if (!activity.isValid())
        return;

    QJniObject intent = activity.callObjectMethod("getIntent", "()Landroid/content/Intent;");
    if (!intent.isValid())
        return;

    QJniObject jAction = intent.callObjectMethod("getAction", "()Ljava/lang/String;");
    if (!jAction.isValid() || jAction.toString() != QStringLiteral("android.intent.action.VIEW"))
        return;

    QJniObject jUri = intent.callObjectMethod("getData", "()Landroid/net/Uri;");
    if (!jUri.isValid())
        return;

    const QUrl uri(jUri.callObjectMethod("toString", "()Ljava/lang/String;").toString());
    const QUrl redirectBase{QLatin1String(kGoogleOAuthRedirectUri)};
    if (uri.scheme() != redirectBase.scheme())
        return; // some other VIEW intent (e.g. a .ppset file) — not ours

    const QUrlQuery params(uri);
    const QString code = params.queryItemValue(QStringLiteral("code"));
    const QString state = params.queryItemValue(QStringLiteral("state"));
    const QString error = params.queryItemValue(QStringLiteral("error"));

    // Consume the pending flow now, before the async exchange below, so a
    // second resume while that exchange is still in flight (or a later,
    // unrelated resume) doesn't reprocess this same intent/auth code — an
    // authorization code is single-use and would just fail the second time.
    // The verifier is captured into a local first since exchangeCodeForGoogleToken
    // still needs it — clearing the member wipes it, not just the "pending" marker.
    const QString expectedState = m_pendingState;
    const QString codeVerifier = m_pendingCodeVerifier;
    m_pendingCodeVerifier.clear();
    m_pendingState.clear();

    if (!error.isEmpty()) {
        setSigningIn(false);
        emit signInFailed(error);
        return;
    }
    if (code.isEmpty())
        return; // getIntent() still returning some unrelated/stale intent
    if (state != expectedState) {
        setSigningIn(false);
        emit signInFailed(tr("Sign-in response failed a security check — please try again."));
        return;
    }

    exchangeCodeForGoogleToken(code, codeVerifier);
#else
    // No OS-level custom-URL-scheme redirect delivery on desktop builds —
    // this flow is Android-first for now, same as GeminiHelper's
    // direct-call path being the desktop/local-testing option.
#endif
}

void GoogleSignInHelper::exchangeCodeForGoogleToken(const QString& code, const QString& codeVerifier) {
    QNetworkRequest req{QUrl(QLatin1String(kGoogleTokenEndpoint))};
    req.setHeader(QNetworkRequest::ContentTypeHeader, QStringLiteral("application/x-www-form-urlencoded"));
    req.setTransferTimeout(15000);

    QUrlQuery form;
    form.addQueryItem(QStringLiteral("code"), code);
    form.addQueryItem(QStringLiteral("client_id"), QLatin1String(kGoogleOAuthClientId));
    form.addQueryItem(QStringLiteral("redirect_uri"), QLatin1String(kGoogleOAuthRedirectUri));
    form.addQueryItem(QStringLiteral("grant_type"), QStringLiteral("authorization_code"));
    form.addQueryItem(QStringLiteral("code_verifier"), codeVerifier);

    auto* reply = m_nam->post(req, form.toString(QUrl::FullyEncoded).toUtf8());
    connect(reply, &QNetworkReply::finished, this, [this, reply]() {
        reply->deleteLater();
        const QByteArray raw = reply->readAll();
        if (reply->error() != QNetworkReply::NoError) {
            const auto errObj = QJsonDocument::fromJson(raw).object();
            const QString reason = errObj[QStringLiteral("error_description")].toString();
            fail(reason.isEmpty() ? tr("Google sign-in failed: %1").arg(reply->errorString())
                                   : tr("Google sign-in failed: %1").arg(reason));
            return;
        }
        const auto obj = QJsonDocument::fromJson(raw).object();
        const QString googleIdToken = obj[QStringLiteral("id_token")].toString();
        if (googleIdToken.isEmpty()) {
            fail(tr("Google sign-in response had no ID token."));
            return;
        }
        exchangeGoogleTokenForFirebase(googleIdToken);
    });
}

void GoogleSignInHelper::exchangeGoogleTokenForFirebase(const QString& googleIdToken) {
    QUrl url{QLatin1String(kFirebaseSignInWithIdpEndpoint)};
    QUrlQuery query;
    query.addQueryItem(QStringLiteral("key"), QLatin1String(FirebaseConfig::kWebApiKey));
    url.setQuery(query);

    QNetworkRequest req(url);
    req.setHeader(QNetworkRequest::ContentTypeHeader, QStringLiteral("application/json"));
    req.setTransferTimeout(15000);

    // requestUri isn't actually visited for this flow — Identity Toolkit
    // just requires some well-formed URI in the payload.
    QUrlQuery postBody;
    postBody.addQueryItem(QStringLiteral("id_token"), googleIdToken);
    postBody.addQueryItem(QStringLiteral("providerId"), QStringLiteral("google.com"));
    const QJsonObject body{
        {QStringLiteral("postBody"), postBody.toString(QUrl::FullyEncoded)},
        {QStringLiteral("requestUri"), QStringLiteral("http://localhost")},
        {QStringLiteral("returnSecureToken"), true}
    };

    auto* reply = m_nam->post(req, QJsonDocument(body).toJson(QJsonDocument::Compact));
    connect(reply, &QNetworkReply::finished, this, [this, reply]() {
        reply->deleteLater();
        const QByteArray raw = reply->readAll();
        if (reply->error() != QNetworkReply::NoError) {
            const auto errObj = QJsonDocument::fromJson(raw).object()[QStringLiteral("error")].toObject();
            const QString reason = errObj[QStringLiteral("message")].toString();
            fail(reason.isEmpty() ? tr("Couldn't complete sign-in: %1").arg(reply->errorString())
                                   : tr("Couldn't complete sign-in: %1").arg(reason));
            return;
        }
        const auto obj = QJsonDocument::fromJson(raw).object();
        const QString idToken = obj[QStringLiteral("idToken")].toString();
        const QString refreshToken = obj[QStringLiteral("refreshToken")].toString();
        const int expiresIn = obj[QStringLiteral("expiresIn")].toString().toInt();
        if (idToken.isEmpty() || refreshToken.isEmpty()) {
            fail(tr("Sign-in response was incomplete."));
            return;
        }
        setSigningIn(false);
        emit signInSucceeded(idToken, refreshToken, expiresIn);
    });
}
