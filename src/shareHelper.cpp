#include "shareHelper.h"

#include <QDir>
#include <QFile>
#include <QThread>
#include <QTimer>
#include <QUrl>
#include <QUuid>
#include <QStandardPaths>

#ifdef Q_OS_ANDROID
#include <QJniObject>
#include <QJniEnvironment>
#endif

ShareHelper::ShareHelper(QObject *parent) : QObject(parent) {}

QString ShareHelper::shareableExportPath(const QString& setName) const {
    QString dir = QStandardPaths::writableLocation(QStandardPaths::AppDataLocation) + "/shared/";
    QDir().mkpath(dir);
    // Sanitize set name for use as filename
    QString safe = setName;
    safe.replace(QRegularExpression(QStringLiteral("[/\\\\:*?\"<>|]")), QStringLiteral("_"));
    return dir + safe + ".ppset";
}

void ShareHelper::checkIncomingFile() {
#ifdef Q_OS_ANDROID
    // A content:// read below runs on a worker thread and can take a while
    // (see comment further down) — while one is in flight, a retap of the
    // same share is a genuinely new, un-cleared intent that would otherwise
    // spawn a second overlapping read. Skip it here; the in-flight read
    // already has this exact file's contents and will complete on its own.
    if (m_incomingFileCheckInFlight) return;

    QJniObject activity = QJniObject::callStaticObjectMethod(
        "org/qtproject/qt/android/QtNative", "activity", "()Landroid/app/Activity;");
    if (!activity.isValid()) return;

    QJniObject intent = activity.callObjectMethod("getIntent", "()Landroid/content/Intent;");
    if (!intent.isValid()) return;

    QJniObject jAction = intent.callObjectMethod("getAction", "()Ljava/lang/String;");
    if (!jAction.isValid()) return;
    if (jAction.toString() != QStringLiteral("android.intent.action.VIEW"))
        return;

    QJniObject uri = intent.callObjectMethod("getData", "()Landroid/net/Uri;");
    if (!uri.isValid()) return;

    const QString uriStr = uri.callObjectMethod("toString", "()Ljava/lang/String;").toString();

    // Consume the pending intent now, before any of the (possibly slow)
    // work below — otherwise a resume that arrives while a content:// copy
    // is still running would see the same intent again and kick off a
    // second, overlapping read of the same file.
    intent.callObjectMethod("setData", "(Landroid/net/Uri;)Landroid/content/Intent;", nullptr);

    if (uriStr.startsWith(QLatin1String("file://"))) {
        emit incomingFileReady(uriStr);
        return;
    }

    // content:// URI — served by whichever app shared the file (e.g.
    // Telegram) over cross-process IPC, not local disk I/O. That app being
    // slow, busy, or hung can block this read for as long as it takes (or
    // indefinitely) — this method is called directly from QML on the UI
    // thread, so that read must happen on a worker thread instead, never
    // inline here, or a stuck sender freezes this app too.
    m_incomingFileCheckInFlight = true;
    // Identifies this specific attempt so a stale completion or timeout
    // from a superseded attempt can't clobber a later, unrelated one — see
    // both uses below.
    const int generation = ++m_incomingFileGeneration;
    // Unique per read — two overlapping reads (e.g. a retap landing while
    // an earlier one is still copying) must never write to the same path,
    // or whichever finishes last silently truncates/corrupts the other's
    // still-in-progress file.
    const QString tmpPath = QStandardPaths::writableLocation(QStandardPaths::CacheLocation)
                            + QStringLiteral("/incoming_") + QUuid::createUuid().toString(QUuid::Id128)
                            + QStringLiteral(".ppset");
    QThread* worker = QThread::create([this, uriStr, tmpPath, generation]() {
        // QFile's content:// support goes through JNI (ContentResolver)
        // under the hood — attach this thread to the JVM for the duration,
        // same as any other thread Qt didn't itself create for Android use.
        QJniEnvironment env;
        QString result;
        QFile src(uriStr);
        if (src.open(QIODevice::ReadOnly)) {
            QFile tmp(tmpPath);
            if (tmp.open(QIODevice::WriteOnly | QIODevice::Truncate)) {
                tmp.write(src.readAll());
                result = QStringLiteral("file://") + tmpPath;
            }
        }
        QMetaObject::invokeMethod(this, [this, result, generation]() {
            if (generation != m_incomingFileGeneration) return; // superseded — ignore
            m_incomingFileCheckInFlight = false;
            if (result.isEmpty())
                emit incomingFileFailed(tr("Couldn't read the shared file."));
            else
                emit incomingFileReady(result);
        }, Qt::QueuedConnection);
    });
    connect(worker, &QThread::finished, worker, &QObject::deleteLater);
    worker->start();

    // Safety net: a content:// read served by a stuck/hung sending app can
    // block this indefinitely. Without this, m_incomingFileCheckInFlight
    // would then stay true forever, silently ignoring every later share
    // attempt until the app is killed and relaunched. The worker thread
    // itself is left to finish (or never finish) on its own — there's no
    // safe way to cancel a blocked JNI call — but the app recovers either way.
    QTimer::singleShot(20000, this, [this, generation]() {
        if (generation != m_incomingFileGeneration || !m_incomingFileCheckInFlight) return;
        m_incomingFileCheckInFlight = false;
        emit incomingFileFailed(tr("Timed out reading the shared file."));
    });
#endif
}

void ShareHelper::shareText(const QString& text, const QString& title) {
#ifdef Q_OS_ANDROID
    QJniObject jText  = QJniObject::fromString(text);
    QJniObject jTitle = QJniObject::fromString(title);

    QJniObject intent("android/content/Intent");
    QJniObject action = QJniObject::fromString("android.intent.action.SEND");
    intent.callObjectMethod("setAction",
        "(Ljava/lang/String;)Landroid/content/Intent;",
        action.object<jstring>());

    QJniObject mimeType = QJniObject::fromString("text/plain");
    intent.callObjectMethod("setType",
        "(Ljava/lang/String;)Landroid/content/Intent;",
        mimeType.object<jstring>());

    QJniObject extraText = QJniObject::fromString("android.intent.extra.TEXT");
    intent.callObjectMethod("putExtra",
        "(Ljava/lang/String;Ljava/lang/String;)Landroid/content/Intent;",
        extraText.object<jstring>(), jText.object<jstring>());

    QJniObject extraSubject = QJniObject::fromString("android.intent.extra.SUBJECT");
    intent.callObjectMethod("putExtra",
        "(Ljava/lang/String;Ljava/lang/String;)Landroid/content/Intent;",
        extraSubject.object<jstring>(), jTitle.object<jstring>());

    QJniObject chooser = QJniObject::callStaticObjectMethod(
        "android/content/Intent",
        "createChooser",
        "(Landroid/content/Intent;Ljava/lang/CharSequence;)Landroid/content/Intent;",
        intent.object<jobject>(),
        jTitle.object<jstring>());

    QJniObject activity = QJniObject::callStaticObjectMethod(
        "org/qtproject/qt/android/QtNative",
        "activity",
        "()Landroid/app/Activity;");

    if (activity.isValid() && chooser.isValid()) {
        activity.callMethod<void>("startActivity",
            "(Landroid/content/Intent;)V",
            chooser.object<jobject>());
    }
#else
    Q_UNUSED(text)
    Q_UNUSED(title)
#endif
}

void ShareHelper::shareFile(const QString& filePath, const QString& title) {
#ifdef Q_OS_ANDROID
    // Resolve to a local path (strip file:// scheme if present)
    QString localPath = filePath;
    if (localPath.startsWith(QLatin1String("file://")))
        localPath = QUrl(filePath).toLocalFile();

    QJniObject activity = QJniObject::callStaticObjectMethod(
        "org/qtproject/qt/android/QtNative",
        "activity",
        "()Landroid/app/Activity;");
    if (!activity.isValid())
        return;

    QJniObject context = activity.callObjectMethod(
        "getApplicationContext", "()Landroid/content/Context;");
    if (!context.isValid())
        return;

    // Build authority string: <packageName>.qtprovider  (Qt's built-in FileProvider)
    QJniObject packageName = context.callObjectMethod("getPackageName", "()Ljava/lang/String;");
    QString authority = packageName.toString() + QStringLiteral(".qtprovider");

    // Create java.io.File for the local path
    QJniObject jFile("java/io/File",
        "(Ljava/lang/String;)V",
        QJniObject::fromString(localPath).object<jstring>());
    if (!jFile.isValid())
        return;

    // Get content URI from FileProvider
    QJniObject contentUri = QJniObject::callStaticObjectMethod(
        "androidx/core/content/FileProvider",
        "getUriForFile",
        "(Landroid/content/Context;Ljava/lang/String;Ljava/io/File;)Landroid/net/Uri;",
        context.object<jobject>(),
        QJniObject::fromString(authority).object<jstring>(),
        jFile.object<jobject>());
    if (!contentUri.isValid())
        return;

    // Build ACTION_SEND intent for the .ppset file
    QJniObject intent("android/content/Intent");
    intent.callObjectMethod("setAction",
        "(Ljava/lang/String;)Landroid/content/Intent;",
        QJniObject::fromString("android.intent.action.SEND").object<jstring>());
    intent.callObjectMethod("setType",
        "(Ljava/lang/String;)Landroid/content/Intent;",
        QJniObject::fromString("application/x-ppset").object<jstring>());

    // EXTRA_STREAM = content URI
    intent.callObjectMethod("putExtra",
        "(Ljava/lang/String;Landroid/os/Parcelable;)Landroid/content/Intent;",
        QJniObject::fromString("android.intent.extra.STREAM").object<jstring>(),
        contentUri.object<jobject>());

    // Grant recipient read access to the URI
    intent.callMethod<jobject>("addFlags", "(I)Landroid/content/Intent;", 1); // FLAG_GRANT_READ_URI_PERMISSION

    QJniObject chooser = QJniObject::callStaticObjectMethod(
        "android/content/Intent",
        "createChooser",
        "(Landroid/content/Intent;Ljava/lang/CharSequence;)Landroid/content/Intent;",
        intent.object<jobject>(),
        QJniObject::fromString(title).object<jstring>());

    if (chooser.isValid()) {
        activity.callMethod<void>("startActivity",
            "(Landroid/content/Intent;)V",
            chooser.object<jobject>());
    }
#else
    Q_UNUSED(filePath)
    Q_UNUSED(title)
#endif
}
