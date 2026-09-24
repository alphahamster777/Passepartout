#pragma once

#include <QObject>
#include <QNetworkAccessManager>
#include <QTextToSpeech>
#include <QtQml/qqml.h>

class MediaHelper : public QObject {
    Q_OBJECT
    QML_ELEMENT
    QML_SINGLETON

    Q_PROPERTY(bool speaking READ isSpeaking NOTIFY speakingChanged)

public:
    explicit MediaHelper(QObject* parent = nullptr);

    // Fetch an openly-licensed (CC/public domain) thumbnail for a word via
    // Openverse, with its own "mature=false" filter applied server-side.
    // Used to also fall back to Wikipedia's raw page-summary thumbnail when
    // Openverse had nothing — dropped entirely (not just deprioritized):
    // Wikipedia is an uncensored encyclopedia with articles (and thumbnails)
    // on anatomy, art history, sexuality, etc., and its REST summary API has
    // no safe-search parameter at all, so there was no way to keep it as a
    // source and close that hole. This is what got the app rejected from
    // Google Play once already (Sexual Content policy, a nude painting
    // surfaced as a word's auto-fetched image) — do not reintroduce it.
    // languageId is accepted for call-site compatibility (it selected which
    // Wikipedia language edition to query) but unused now; Openverse search
    // isn't language-scoped. Emits imageFetched(cardIndex, url) when done;
    // silent on failure.
    Q_INVOKABLE void fetchImageUrl(const QString& word, int cardIndex, int languageId = 0);

    // Text-to-speech — languageId matches LanguageHelper::Language enum values
    Q_INVOKABLE void speak(const QString& text, int languageId);
    Q_INVOKABLE void stopSpeaking();
    Q_INVOKABLE bool isSpeaking() const;

    // Runtime permissions — request is async; result comes via signal.
    // On desktop permissions are always considered granted.
    Q_INVOKABLE bool hasMicrophonePermission() const;
    Q_INVOKABLE bool hasCameraPermission() const;
    Q_INVOKABLE void requestMicrophonePermission();
    Q_INVOKABLE void requestCameraPermission();

    // Returns a unique, writable output path for a new audio recording.
    Q_INVOKABLE QString newRecordingPath() const;

    // Returns a unique, writable output path for a camera photo.
    Q_INVOKABLE QString newPhotoPath() const;

    // Must be named "create" — that's the only name Qt's QML_SINGLETON
    // machinery recognizes as a custom factory; anything else is silently
    // ignored in favor of default-constructing the singleton instead.
    static QObject* create(QQmlEngine*, QJSEngine*) { return new MediaHelper(); }

signals:
    void imageFetched(int cardIndex, const QString& url);
    void speakingChanged();
    void microphonePermissionGranted();
    void cameraPermissionGranted();

private:
    void fetchAndCacheImage(const QString& imgUrl, int cardIndex);

    QNetworkAccessManager* m_nam;
    QTextToSpeech*         m_tts;
};
