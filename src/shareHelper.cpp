#include "shareHelper.h"

#include <QDir>
#include <QFile>
#include <QUrl>
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

QString ShareHelper::incomingFilePath() const {
#ifdef Q_OS_ANDROID
    QJniObject activity = QJniObject::callStaticObjectMethod(
        "org/qtproject/qt/android/QtNative", "activity", "()Landroid/app/Activity;");
    if (!activity.isValid()) return {};

    QJniObject intent = activity.callObjectMethod("getIntent", "()Landroid/content/Intent;");
    if (!intent.isValid()) return {};

    QJniObject jAction = intent.callObjectMethod("getAction", "()Ljava/lang/String;");
    if (!jAction.isValid()) return {};
    if (jAction.toString() != QStringLiteral("android.intent.action.VIEW"))
        return {};

    QJniObject uri = intent.callObjectMethod("getData", "()Landroid/net/Uri;");
    if (!uri.isValid()) return {};

    QString uriStr = uri.callObjectMethod("toString", "()Ljava/lang/String;").toString();
    if (uriStr.startsWith(QLatin1String("file://")))
        return uriStr;

    // content:// URI — Qt 6.4+ QFile reads content URIs natively on Android;
    // copy to a temp file so QZipReader (which needs a plain path) can open it.
    QFile src(uriStr);
    if (!src.open(QIODevice::ReadOnly))
        return {};

    QString tmpPath = QStandardPaths::writableLocation(QStandardPaths::CacheLocation)
                      + QStringLiteral("/incoming_set.ppset");
    QFile tmp(tmpPath);
    if (!tmp.open(QIODevice::WriteOnly | QIODevice::Truncate))
        return {};
    tmp.write(src.readAll());

    return QStringLiteral("file://") + tmpPath;
#else
    return {};
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
