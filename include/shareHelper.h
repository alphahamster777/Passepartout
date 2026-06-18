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

    // Returns the local file:// path of a .ppset file the app was asked to open
    // (ACTION_VIEW intent on Android). Empty string if the app was not opened via file.
    Q_INVOKABLE QString incomingFilePath() const;

    // Share plain text (existing)
    Q_INVOKABLE void shareText(const QString& text, const QString& title);

    // Returns a writable path for exporting a set as .ppset, then shareFile() it.
    // Files here are inside AppDataLocation so the Qt FileProvider can serve them.
    Q_INVOKABLE QString shareableExportPath(const QString& setName) const;

    // Share a local file via the system share sheet.
    // On Android uses FileProvider + ACTION_SEND; no-op on desktop.
    Q_INVOKABLE void shareFile(const QString& filePath, const QString& title);

    static QObject* qmlInstance(QQmlEngine*, QJSEngine*) { return new ShareHelper(); }
};
