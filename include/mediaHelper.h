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

    // Fetch the best Wikimedia/Wikipedia thumbnail URL for a word.
    // Emits imageFetched(cardIndex, url) when done; silent on failure.
    Q_INVOKABLE void fetchWikimediaImageUrl(const QString& word, int cardIndex, int languageId = 0);

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

    static QObject* qmlInstance(QQmlEngine*, QJSEngine*) { return new MediaHelper(); }

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
