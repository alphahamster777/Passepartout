#include "firebaseAiHelper.h"

#include "aiWordSetShared.h"
#include "firebaseConfig.h"
#include "languageHelper.h"

#include <QDateTime>
#include <QJsonDocument>
#include <QNetworkReply>
#include <QNetworkRequest>
#include <QSettings>
#include <QUrl>
#include <QUrlQuery>

namespace {
// Which Cloud Function (and therefore which monthly quota — see
// functions/main.py's FREE_MONTHLY_LIMIT / PRO_MONTHLY_LIMIT) this build
// talks to. Set by CMake's PASSEPARTOUT_TIER option; the Free build never
// contains the Pro URL at all, so there's no "I'm pro" flag to fake.
#if defined(PASSEPARTOUT_TIER_PRO)
constexpr auto kFunctionUrl = "https://europe-west1-passepartout-ca98f.cloudfunctions.net/generate_word_set_pro";
#else
constexpr auto kFunctionUrl = "https://europe-west1-passepartout-ca98f.cloudfunctions.net/generate_word_set_free";
#endif

constexpr auto kIdTokenSettingsKey = "Firebase/idToken";
constexpr auto kRefreshTokenSettingsKey = "Firebase/refreshToken";
constexpr auto kIdTokenExpirySettingsKey = "Firebase/idTokenExpiryEpochMs";

// Refresh a bit before actual expiry so a request never starts with a token
// that expires mid-flight.
constexpr qint64 kExpiryMarginMs = 60'000;
}

FirebaseAiHelper::FirebaseAiHelper(QObject* parent)
    : QObject(parent)
    , m_nam(new QNetworkAccessManager(this))
{
    QSettings s;
    m_idToken = s.value(QLatin1String(kIdTokenSettingsKey)).toString();
    m_refreshToken = s.value(QLatin1String(kRefreshTokenSettingsKey)).toString();
    m_idTokenExpiryEpochMs = s.value(QLatin1String(kIdTokenExpirySettingsKey), 0).toLongLong();
}

void FirebaseAiHelper::setGenerating(bool value) {
    if (m_generating == value)
        return;
    m_generating = value;
    emit generatingChanged();
}

void FirebaseAiHelper::applyQuota(const QJsonObject& payload) {
    bool changed = false;
    if (payload.contains(QStringLiteral("remaining"))) {
        m_remaining = payload[QStringLiteral("remaining")].toInt();
        changed = true;
    }
    if (payload.contains(QStringLiteral("limit"))) {
        m_monthlyLimit = payload[QStringLiteral("limit")].toInt();
        changed = true;
    }
    if (payload.contains(QStringLiteral("resetAt"))) {
        m_resetAt = payload[QStringLiteral("resetAt")].toString();
        changed = true;
    }
    if (changed)
        emit quotaChanged();
}

void FirebaseAiHelper::storeAuthResponse(const QJsonObject& obj, bool isRefreshResponse) {
    // The two Identity Toolkit endpoints name the same fields differently:
    // camelCase from accounts:signUp, snake_case from the token-refresh
    // endpoint. Both give expiresIn as a *string* number of seconds.
    const QString idToken = isRefreshResponse ? obj[QStringLiteral("id_token")].toString()
                                               : obj[QStringLiteral("idToken")].toString();
    const QString refreshToken = isRefreshResponse ? obj[QStringLiteral("refresh_token")].toString()
                                                    : obj[QStringLiteral("refreshToken")].toString();
    const QString expiresInStr = isRefreshResponse ? obj[QStringLiteral("expires_in")].toString()
                                                    : obj[QStringLiteral("expiresIn")].toString();
    const qint64 expiresInSecs = expiresInStr.toLongLong();

    const bool wasSignedIn = isSignedIn();
    m_idToken = idToken;
    m_refreshToken = refreshToken;
    m_idTokenExpiryEpochMs = QDateTime::currentMSecsSinceEpoch() + expiresInSecs * 1000;

    QSettings s;
    s.setValue(QLatin1String(kIdTokenSettingsKey), m_idToken);
    s.setValue(QLatin1String(kRefreshTokenSettingsKey), m_refreshToken);
    s.setValue(QLatin1String(kIdTokenExpirySettingsKey), m_idTokenExpiryEpochMs);
    if (wasSignedIn != isSignedIn())
        emit signedInChanged();
}

void FirebaseAiHelper::adoptSignIn(const QString& idToken, const QString& refreshToken, int expiresInSeconds) {
    // Same shape accounts:signUp's response takes in storeAuthResponse's
    // camelCase branch — reuse it rather than duplicating the QSettings writes.
    const QJsonObject asIfSignUpResponse{
        {QStringLiteral("idToken"), idToken},
        {QStringLiteral("refreshToken"), refreshToken},
        {QStringLiteral("expiresIn"), QString::number(expiresInSeconds)}
    };
    storeAuthResponse(asIfSignUpResponse, /*isRefreshResponse=*/false);
}

void FirebaseAiHelper::signOut() {
    const bool wasSignedIn = isSignedIn();
    m_idToken.clear();
    m_refreshToken.clear();
    m_idTokenExpiryEpochMs = 0;

    QSettings s;
    s.remove(QLatin1String(kIdTokenSettingsKey));
    s.remove(QLatin1String(kRefreshTokenSettingsKey));
    s.remove(QLatin1String(kIdTokenExpirySettingsKey));
    if (wasSignedIn)
        emit signedInChanged();
}

void FirebaseAiHelper::ensureSignedIn(std::function<void(bool, const QString&)> onReady) {
    const qint64 now = QDateTime::currentMSecsSinceEpoch();
    if (!m_idToken.isEmpty() && now < m_idTokenExpiryEpochMs - kExpiryMarginMs) {
        onReady(true, m_idToken);
        return;
    }
    if (!m_refreshToken.isEmpty()) {
        refreshIdToken(std::move(onReady));
        return;
    }
    onReady(false, tr("Not signed in."));
}

void FirebaseAiHelper::refreshIdToken(std::function<void(bool, const QString&)> onReady) {
    QUrl url(QStringLiteral("https://securetoken.googleapis.com/v1/token"));
    QUrlQuery query;
    query.addQueryItem(QStringLiteral("key"), QLatin1String(FirebaseConfig::kWebApiKey));
    url.setQuery(query);

    QNetworkRequest req(url);
    req.setHeader(QNetworkRequest::ContentTypeHeader, QStringLiteral("application/x-www-form-urlencoded"));
    req.setTransferTimeout(15000);

    QUrlQuery form;
    form.addQueryItem(QStringLiteral("grant_type"), QStringLiteral("refresh_token"));
    form.addQueryItem(QStringLiteral("refresh_token"), m_refreshToken);

    auto* reply = m_nam->post(req, form.toString(QUrl::FullyEncoded).toUtf8());
    connect(reply, &QNetworkReply::finished, this, [this, reply, onReady = std::move(onReady)]() mutable {
        reply->deleteLater();
        if (reply->error() != QNetworkReply::NoError) {
            // The stored refresh token itself may have been revoked/expired —
            // there's no anonymous fallback anymore, so this just means the
            // user needs to sign in again.
            signOut();
            onReady(false, tr("Your session expired — please sign in again."));
            return;
        }
        const auto obj = QJsonDocument::fromJson(reply->readAll()).object();
        storeAuthResponse(obj, /*isRefreshResponse=*/true);
        if (m_idToken.isEmpty()) {
            onReady(false, tr("Token refresh response had no token."));
            return;
        }
        onReady(true, m_idToken);
    });
}

void FirebaseAiHelper::refreshQuota() {
    ensureSignedIn([this](bool ok, const QString& idTokenOrError) {
        if (!ok)
            return; // silent — this is a background convenience, not a user action
        QNetworkRequest req{QUrl(QLatin1String(kFunctionUrl))};
        req.setHeader(QNetworkRequest::ContentTypeHeader, QStringLiteral("application/json"));
        req.setRawHeader("Authorization", "Bearer " + idTokenOrError.toUtf8());
        req.setTransferTimeout(15000);

        const QJsonObject body{{QStringLiteral("checkOnly"), true}};
        auto* reply = m_nam->post(req, QJsonDocument(body).toJson(QJsonDocument::Compact));
        connect(reply, &QNetworkReply::finished, this, [this, reply]() {
            reply->deleteLater();
            if (reply->error() != QNetworkReply::NoError)
                return;
            applyQuota(QJsonDocument::fromJson(reply->readAll()).object());
        });
    });
}

void FirebaseAiHelper::generateWordSet(const QString& theme, int fromLanguageId,
                                        int toLanguageId, int wordCount) {
    if (theme.trimmed().isEmpty()) {
        emit generationFailed(tr("Enter a theme first."));
        return;
    }

    setGenerating(true);
    m_cancelled = false;
    ensureSignedIn([this, theme, fromLanguageId, toLanguageId, wordCount]
                   (bool ok, const QString& idTokenOrError) {
        if (m_cancelled)
            return;
        if (!ok) {
            setGenerating(false);
            emit generationFailed(idTokenOrError);
            return;
        }
        postGenerate(idTokenOrError, theme, fromLanguageId, toLanguageId, wordCount);
    });
}

void FirebaseAiHelper::postGenerate(const QString& idToken, const QString& theme,
                                     int fromLanguageId, int toLanguageId, int wordCount) {
    const QString fromLang = LanguageHelper::displayName(static_cast<LanguageHelper::Language>(fromLanguageId));
    const QString toLang   = LanguageHelper::displayName(static_cast<LanguageHelper::Language>(toLanguageId));

    const QJsonObject body{
        {QStringLiteral("theme"), theme.trimmed()},
        {QStringLiteral("fromLanguage"), fromLang},
        {QStringLiteral("toLanguage"), toLang},
        {QStringLiteral("wordCount"), wordCount}
    };

    QNetworkRequest req{QUrl(QLatin1String(kFunctionUrl))};
    req.setHeader(QNetworkRequest::ContentTypeHeader, QStringLiteral("application/json"));
    req.setRawHeader("Authorization", "Bearer " + idToken.toUtf8());
    req.setTransferTimeout(30000); // the function itself calls Gemini, so allow more slack

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

        const int status = reply->attribute(QNetworkRequest::HttpStatusCodeAttribute).toInt();
        const QByteArray raw = reply->readAll();
        const auto payload = QJsonDocument::fromJson(raw).object();
        applyQuota(payload); // present on both success and the 429/limit-reached error

        if (reply->error() != QNetworkReply::NoError || status != 200) {
            QString message = payload[QStringLiteral("error")].toString();
            if (message.isEmpty())
                message = reply->errorString();
            if (status == 429)
                message = tr("Monthly limit reached — try again next month. (%1)").arg(message);
            else if (status == 401)
                message = tr("Not signed in — try again. (%1)").arg(message);
            else if (status == 503)
                // The *shared* Gemini key hit its own rate limit — distinct from
                // the per-user cap above, affects every user, not just this one.
                message = tr("⚠ DEBUG: shared Gemini key is rate-limited (%1)").arg(message);
            emit generationFailed(message);
            return;
        }

        const QVariantList result = AiWordSetShared::parseWords(
            payload[QStringLiteral("words")].toArray(), fromLanguageId, toLanguageId);
        if (result.isEmpty()) {
            emit generationFailed(tr("The backend returned no words."));
            return;
        }
        emit wordSetGenerated(result);
    });
}

void FirebaseAiHelper::cancelGeneration() {
    m_cancelled = true;
    if (m_currentReply)
        m_currentReply->abort();
    setGenerating(false);
}
