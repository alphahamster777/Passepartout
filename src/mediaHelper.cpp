#include "mediaHelper.h"

#include <QNetworkReply>
#include <QNetworkRequest>
#include <QJsonDocument>
#include <QJsonObject>
#include <QLocale>
#include <QUrl>
#include <QDir>
#include <QFile>
#include <QFileInfo>
#include <QBuffer>
#include <QImage>
#include <QImageReader>
#include <QDateTime>
#include <QStandardPaths>
#include <QCoreApplication>
#include <QPermission>

// Maps LanguageHelper::Language enum ordinals to QLocale
static QLocale localeFor(int langId) {
    switch (langId) {
    case 0: return QLocale(QLocale::English);
    case 1: return QLocale(QLocale::Chinese);
    case 2: return QLocale(QLocale::Hindi);
    case 3: return QLocale(QLocale::Spanish);
    case 4: return QLocale(QLocale::French);
    case 5: return QLocale(QLocale::Arabic);
    case 6: return QLocale(QLocale::Bengali);
    case 7: return QLocale(QLocale::Russian);
    case 8: return QLocale(QLocale::Portuguese);
    case 9: return QLocale(QLocale::Urdu);
    default: return QLocale(QLocale::English);
    }
}

MediaHelper::MediaHelper(QObject* parent)
    : QObject(parent)
    , m_nam(new QNetworkAccessManager(this))
    , m_tts(new QTextToSpeech(this))
{
    connect(m_tts, &QTextToSpeech::stateChanged, this, [this](QTextToSpeech::State) {
        emit speakingChanged();
    });
}

void MediaHelper::fetchWikimediaImageUrl(const QString& word, int cardIndex) {
    // Wikipedia REST API summary endpoint — returns JSON with a "thumbnail" object
    QString encoded = QString::fromUtf8(QUrl::toPercentEncoding(word));
    QUrl url(QStringLiteral("https://en.wikipedia.org/api/rest_v1/page/summary/") + encoded);
    QNetworkRequest req(url);
    req.setHeader(QNetworkRequest::UserAgentHeader, QStringLiteral("Passepartout/1.0"));

    auto* reply = m_nam->get(req);
    connect(reply, &QNetworkReply::finished, this, [this, reply, cardIndex]() {
        reply->deleteLater();
        if (reply->error() != QNetworkReply::NoError)
            return;
        auto obj = QJsonDocument::fromJson(reply->readAll()).object();
        QString imgUrl = obj[QStringLiteral("thumbnail")].toObject()
                             [QStringLiteral("source")].toString();
        if (!imgUrl.isEmpty())
            fetchAndCacheImage(imgUrl, cardIndex);
    });
}

void MediaHelper::speak(const QString& text, int languageId) {
    if (m_tts->state() == QTextToSpeech::Speaking)
        m_tts->stop();
    m_tts->setLocale(localeFor(languageId));
    m_tts->say(text);
}

void MediaHelper::stopSpeaking() {
    m_tts->stop();
}

bool MediaHelper::isSpeaking() const {
    return m_tts->state() == QTextToSpeech::Speaking;
}

// ── Permissions ───────────────────────────────────────────────────────────────

bool MediaHelper::hasMicrophonePermission() const {
    return qApp->checkPermission(QMicrophonePermission{}) == Qt::PermissionStatus::Granted;
}

bool MediaHelper::hasCameraPermission() const {
    return qApp->checkPermission(QCameraPermission{}) == Qt::PermissionStatus::Granted;
}

void MediaHelper::requestMicrophonePermission() {
    qApp->requestPermission(QMicrophonePermission{}, this, [this](const QPermission& perm) {
        if (perm.status() == Qt::PermissionStatus::Granted)
            emit microphonePermissionGranted();
    });
}

void MediaHelper::requestCameraPermission() {
    qApp->requestPermission(QCameraPermission{}, this, [this](const QPermission& perm) {
        if (perm.status() == Qt::PermissionStatus::Granted)
            emit cameraPermissionGranted();
    });
}

// ── Path helpers ──────────────────────────────────────────────────────────────

QString MediaHelper::newRecordingPath() const {
    QString dir = QStandardPaths::writableLocation(QStandardPaths::AppDataLocation)
                  + QStringLiteral("/recordings/");
    QDir().mkpath(dir);
    QString ts = QDateTime::currentDateTime().toString(QStringLiteral("yyyyMMdd_HHmmss"));
    return dir + QStringLiteral("rec_") + ts + QStringLiteral(".m4a");
}

QString MediaHelper::newPhotoPath() const {
    QString dir = QStandardPaths::writableLocation(QStandardPaths::AppDataLocation)
                  + QStringLiteral("/photos/");
    QDir().mkpath(dir);
    QString ts = QDateTime::currentDateTime().toString(QStringLiteral("yyyyMMdd_HHmmss"));
    return dir + QStringLiteral("photo_") + ts + QStringLiteral(".jpg");
}

// ── Private helpers ───────────────────────────────────────────────────────────

void MediaHelper::fetchAndCacheImage(const QString& imgUrl, int cardIndex) {
    QNetworkRequest req(imgUrl);
    req.setHeader(QNetworkRequest::UserAgentHeader, QStringLiteral("Passepartout/1.0"));
    auto* reply = m_nam->get(req);
    connect(reply, &QNetworkReply::finished, this, [this, reply, cardIndex]() {
        reply->deleteLater();
        if (reply->error() != QNetworkReply::NoError)
            return;

        // Wikipedia's CDN may serve WebP regardless of the URL extension.
        // Decode with QImageReader (auto-detects format) and re-save as PNG
        // so we always emit a format Qt can display on every platform.
        QByteArray data = reply->readAll();
        QBuffer buf(&data);
        buf.open(QIODevice::ReadOnly);
        QImageReader reader(&buf);
        QImage img = reader.read();
        if (img.isNull())
            return;

        QString dir = QStandardPaths::writableLocation(QStandardPaths::CacheLocation)
                      + QStringLiteral("/wiki_images/");
        QDir().mkpath(dir);
        QString path = dir + QString::number(cardIndex) + QStringLiteral(".png");
        if (img.save(path, "PNG"))
            emit imageFetched(cardIndex, QUrl::fromLocalFile(path).toString());
    });
}
