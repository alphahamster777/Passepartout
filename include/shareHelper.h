#pragma once

#include <QObject>
#include <QStandardPaths>
#include <QDir>
#include <QRegularExpression>
#include <QtQml/qqml.h>

class ShareHelper : public QObject {
    Q_OBJECT
    QML_ELEMENT
    QML_SINGLETON
public:
    explicit ShareHelper(QObject *parent = nullptr);

    // Checks whether the app was asked to open a .ppset file (ACTION_VIEW
    // intent on Android) and, if so, emits incomingFileReady(localPath) or
    // incomingFileFailed(error). No-op (no signal at all) if there's
    // nothing pending. Safe to call on every app resume, not just cold
    // start — the pending intent is consumed immediately so a later,
    // unrelated resume won't re-detect and re-import the same file.
    //
    // Deliberately asynchronous: a content:// URI (as opposed to file://)
    // is served by whatever app shared the file, over cross-process IPC —
    // reading it can block for as long as that other app takes to respond,
    // including indefinitely if it's busy or hung. This is invoked directly
    // from QML on the UI thread, so that read must never happen inline here;
    // it runs on a worker thread instead.
    Q_INVOKABLE void checkIncomingFile();

    // Share plain text (existing)
    Q_INVOKABLE void shareText(const QString& text, const QString& title);

    // Returns a writable path for exporting a set as .ppset, then shareFile() it.
    // Files here are inside AppDataLocation so the Qt FileProvider can serve them.
    Q_INVOKABLE QString shareableExportPath(const QString& setName) const;

    // Share a local file via the system share sheet.
    // On Android uses FileProvider + ACTION_SEND; no-op on desktop.
    Q_INVOKABLE void shareFile(const QString& filePath, const QString& title);

    // Must be named "create" — that's the only name Qt's QML_SINGLETON
    // machinery recognizes as a custom factory; anything else is silently
    // ignored in favor of default-constructing the singleton instead.
    static QObject* create(QQmlEngine*, QJSEngine*) { return new ShareHelper(); }

signals:
    void incomingFileReady(const QString& localPath);
    void incomingFileFailed(const QString& error);

private:
    bool m_incomingFileCheckInFlight = false;
    int m_incomingFileGeneration = 0;
};
