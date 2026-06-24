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

// Maps LanguageHelper::Language enum ordinals to Wikipedia language codes
static QString wikipediaLangCode(int langId) {
    switch (langId) {
    case  1: return QStringLiteral("zh");
    case  2: return QStringLiteral("hi");
    case  3: return QStringLiteral("es");
    case  4: return QStringLiteral("fr");
    case  5: return QStringLiteral("ar");
    case  6: return QStringLiteral("bn");
    case  7: return QStringLiteral("ru");
    case  8: return QStringLiteral("pt");
    case  9: return QStringLiteral("ur");
    case 11: return QStringLiteral("de");
    case 12: return QStringLiteral("ja");
    case 13: return QStringLiteral("it");
    case 14: return QStringLiteral("nl");
    case 15: return QStringLiteral("pl");
    case 16: return QStringLiteral("vi");
    case 17: return QStringLiteral("uk");
    case 18: return QStringLiteral("fa");
    case 19: return QStringLiteral("sv");
    case 20: return QStringLiteral("fi");
    case 21: return QStringLiteral("cs");
    case 22: return QStringLiteral("hu");
    case 23: return QStringLiteral("ko");
    case 24: return QStringLiteral("ro");
    case 25: return QStringLiteral("no");
    case 26: return QStringLiteral("tr");
    case 27: return QStringLiteral("id");
    case 28: return QStringLiteral("he");
    case 29: return QStringLiteral("sr");
    case 30: return QStringLiteral("da");
    case 31: return QStringLiteral("bg");
    case 32: return QStringLiteral("ca");
    case 33: return QStringLiteral("sk");
    case 34: return QStringLiteral("th");
    case 35: return QStringLiteral("el");
    case 36: return QStringLiteral("lt");
    case 37: return QStringLiteral("hr");
    case 38: return QStringLiteral("et");
    case 39: return QStringLiteral("lv");
    case 40: return QStringLiteral("sq");
    case 41: return QStringLiteral("ka");
    case 42: return QStringLiteral("hy");
    case 43: return QStringLiteral("az");
    case 44: return QStringLiteral("kk");
    case 45: return QStringLiteral("be");
    case 46: return QStringLiteral("eu");
    case 47: return QStringLiteral("gl");
    case 48: return QStringLiteral("cy");
    case 49: return QStringLiteral("ta");
    case 50: return QStringLiteral("ms");
    case 51: return QStringLiteral("mr");
    case 52: return QStringLiteral("sw");
    case 53: return QStringLiteral("sl");
    case 54: return QStringLiteral("is");
    case 55: return QStringLiteral("tl");
    case 56: return QStringLiteral("af");
    default: return QStringLiteral("en");
    }
}

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
    case 11: return QLocale(QLocale::German);
    case 12: return QLocale(QLocale::Japanese);
    case 13: return QLocale(QLocale::Italian);
    case 14: return QLocale(QLocale::Dutch);
    case 15: return QLocale(QLocale::Polish);
    case 16: return QLocale(QLocale::Vietnamese);
    case 17: return QLocale(QLocale::Ukrainian);
    case 18: return QLocale(QLocale::Persian);
    case 19: return QLocale(QLocale::Swedish);
    case 20: return QLocale(QLocale::Finnish);
    case 21: return QLocale(QLocale::Czech);
    case 22: return QLocale(QLocale::Hungarian);
    case 23: return QLocale(QLocale::Korean);
    case 24: return QLocale(QLocale::Romanian);
    case 25: return QLocale(QLocale::NorwegianBokmal);
    case 26: return QLocale(QLocale::Turkish);
    case 27: return QLocale(QLocale::Indonesian);
    case 28: return QLocale(QLocale::Hebrew);
    case 29: return QLocale(QLocale::Serbian);
    case 30: return QLocale(QLocale::Danish);
    case 31: return QLocale(QLocale::Bulgarian);
    case 32: return QLocale(QLocale::Catalan);
    case 33: return QLocale(QLocale::Slovak);
    case 34: return QLocale(QLocale::Thai);
    case 35: return QLocale(QLocale::Greek);
    case 36: return QLocale(QLocale::Lithuanian);
    case 37: return QLocale(QLocale::Croatian);
    case 38: return QLocale(QLocale::Estonian);
    case 39: return QLocale(QLocale::Latvian);
    case 40: return QLocale(QLocale::Albanian);
    case 41: return QLocale(QLocale::Georgian);
    case 42: return QLocale(QLocale::Armenian);
    case 43: return QLocale(QLocale::Azerbaijani);
    case 44: return QLocale(QLocale::Kazakh);
    case 45: return QLocale(QLocale::Belarusian);
    case 46: return QLocale(QLocale::Basque);
    case 47: return QLocale(QLocale::Galician);
    case 48: return QLocale(QLocale::Welsh);
    case 49: return QLocale(QLocale::Tamil);
    case 50: return QLocale(QLocale::Malay);
    case 51: return QLocale(QLocale::Marathi);
    case 52: return QLocale(QLocale::Swahili);
    case 53: return QLocale(QLocale::Slovenian);
    case 54: return QLocale(QLocale::Icelandic);
    case 55: return QLocale(QLocale::Filipino);
    case 56: return QLocale(QLocale::Afrikaans);
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

void MediaHelper::fetchWikimediaImageUrl(const QString& word, int cardIndex, int languageId) {
    // Wikipedia REST API summary endpoint — returns JSON with a "thumbnail" object
    const QString lang = wikipediaLangCode(languageId);
    QString encoded = QString::fromUtf8(QUrl::toPercentEncoding(word));
    QUrl url(QStringLiteral("https://") + lang + QStringLiteral(".wikipedia.org/api/rest_v1/page/summary/") + encoded);
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
