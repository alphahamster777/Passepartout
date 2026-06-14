#include "shareHelper.h"

#ifdef Q_OS_ANDROID
#include <QJniObject>
#endif

ShareHelper::ShareHelper(QObject *parent) : QObject(parent) {}

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
