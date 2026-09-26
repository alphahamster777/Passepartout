#include "mediaHelper.h"

#include "contentFilter.h"

#include <QNetworkReply>
#include <QNetworkRequest>
#include <QJsonArray>
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
    case  0: return QLocale(QLocale::English);
    case  1: return QLocale(QLocale::Chinese);
    case  2: return QLocale(QLocale::Hindi);
    case  3: return QLocale(QLocale::Spanish);
    case  4: return QLocale(QLocale::French);
    case  5: return QLocale(QLocale::Arabic);
    case  6: return QLocale(QLocale::Bengali);
    case  7: return QLocale(QLocale::Russian);
    case  8: return QLocale(QLocale::Portuguese);
    case  9: return QLocale(QLocale::Urdu);
    case 10: return QLocale(QLocale::German);
    case 11: return QLocale(QLocale::Japanese);
    case 12: return QLocale(QLocale::Italian);
    case 13: return QLocale(QLocale::Dutch);
    case 14: return QLocale(QLocale::Polish);
    case 15: return QLocale(QLocale::Vietnamese);
    case 16: return QLocale(QLocale::Ukrainian);
    case 17: return QLocale(QLocale::Persian);
    case 18: return QLocale(QLocale::Swedish);
    case 19: return QLocale(QLocale::Finnish);
    case 20: return QLocale(QLocale::Czech);
    case 21: return QLocale(QLocale::Hungarian);
    case 22: return QLocale(QLocale::Korean);
    case 23: return QLocale(QLocale::Romanian);
    case 24: return QLocale(QLocale::NorwegianBokmal);
    case 25: return QLocale(QLocale::Turkish);
    case 26: return QLocale(QLocale::Indonesian);
    case 27: return QLocale(QLocale::Hebrew);
    case 28: return QLocale(QLocale::Serbian);
    case 29: return QLocale(QLocale::Danish);
    case 30: return QLocale(QLocale::Bulgarian);
    case 31: return QLocale(QLocale::Catalan);
    case 32: return QLocale(QLocale::Slovak);
    case 33: return QLocale(QLocale::Thai);
    case 34: return QLocale(QLocale::Greek);
    case 35: return QLocale(QLocale::Lithuanian);
    case 36: return QLocale(QLocale::Croatian);
    case 37: return QLocale(QLocale::Estonian);
    case 38: return QLocale(QLocale::Latvian);
    case 39: return QLocale(QLocale::Albanian);
    case 40: return QLocale(QLocale::Georgian);
    case 41: return QLocale(QLocale::Armenian);
    case 42: return QLocale(QLocale::Azerbaijani);
    case 43: return QLocale(QLocale::Kazakh);
    case 44: return QLocale(QLocale::Belarusian);
    case 45: return QLocale(QLocale::Basque);
    case 46: return QLocale(QLocale::Galician);
    case 47: return QLocale(QLocale::Welsh);
    case 48: return QLocale(QLocale::Tamil);
    case 49: return QLocale(QLocale::Malay);
    case 50: return QLocale(QLocale::Marathi);
    case 51: return QLocale(QLocale::Swahili);
    case 52: return QLocale(QLocale::Slovenian);
    case 53: return QLocale(QLocale::Icelandic);
    case 54: return QLocale(QLocale::Filipino);
    case 55: return QLocale(QLocale::Afrikaans);
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

// True if an Openverse result's own metadata (title + tags) contains a
// restricted term — a second line of defense for when the search word itself
// is innocent but the photo that matched it isn't.
static bool openverseResultIsRestricted(const QJsonObject& result) {
    QString metadata = result[QStringLiteral("title")].toString();
    for (const auto& tag : result[QStringLiteral("tags")].toArray()) {
        metadata += QLatin1Char(' ');
        metadata += tag.toObject()[QStringLiteral("name")].toString();
    }
    return result[QStringLiteral("mature")].toBool()
        || ContentFilter::containsRestrictedTerm(metadata, ContentFilter::Scope::ImageQuery);
}

void MediaHelper::fetchImageUrl(const QString& word, int cardIndex, int languageId) {
    Q_UNUSED(languageId); // kept for call-site compatibility — see header comment
    // A restricted word never reaches the image search at all — see the
    // header comment for why Openverse's own filter isn't enough by itself.
    if (ContentFilter::containsRestrictedTerm(word, ContentFilter::Scope::ImageQuery))
        return;

    // No API key required for this volume of traffic (a single lookup per
    // word). Every result is CC-licensed or public domain by construction,
    // and "mature=false" applies Openverse's own safe-search filter. Asks for
    // a page of candidates rather than just one so a result whose own
    // title/tags are restricted can be skipped in favor of the next.
    QString encoded = QString::fromUtf8(QUrl::toPercentEncoding(word));
    QUrl url(QStringLiteral("https://api.openverse.org/v1/images/?q=") + encoded
             + QStringLiteral("&page_size=20&mature=false"));
    QNetworkRequest req(url);
    req.setHeader(QNetworkRequest::UserAgentHeader, QStringLiteral("Passepartout/1.0"));

    auto* reply = m_nam->get(req);
    connect(reply, &QNetworkReply::finished, this, [this, reply, cardIndex]() {
        reply->deleteLater();
        if (reply->error() != QNetworkReply::NoError)
            return;
        const auto results = QJsonDocument::fromJson(reply->readAll())
                                 .object()[QStringLiteral("results")].toArray();
        for (const auto& value : results) {
            const auto result = value.toObject();
            if (openverseResultIsRestricted(result))
                continue;
            QString imgUrl = result[QStringLiteral("thumbnail")].toString();
            if (imgUrl.isEmpty())
                imgUrl = result[QStringLiteral("url")].toString();
            if (!imgUrl.isEmpty()) {
                fetchAndCacheImage(imgUrl, cardIndex);
                return;
            }
        }
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

        // The source CDN may serve WebP regardless of the URL extension.
        // Decode with QImageReader (auto-detects format) and re-save as PNG
        // so we always emit a format Qt can display on every platform.
        QByteArray data = reply->readAll();
        QBuffer buf(&data);
        buf.open(QIODevice::ReadOnly);
        QImageReader reader(&buf);
        QImage img = reader.read();
        if (img.isNull())
            return;

        QString dir = QStandardPaths::writableLocation(QStandardPaths::AppDataLocation)
                      + QStringLiteral("/wiki_images/");
        QDir().mkpath(dir);
        // Include timestamp so images from different word sets (or different fetch
        // sessions) never collide even when both sets have a word at the same index.
        QString ts = QDateTime::currentDateTime().toString(QStringLiteral("yyyyMMdd_HHmmsszzz"));
        QString path = dir + ts + QLatin1Char('_') + QString::number(cardIndex) + QStringLiteral(".png");
        if (img.save(path, "PNG"))
            emit imageFetched(cardIndex, QUrl::fromLocalFile(path).toString());
    });
}
