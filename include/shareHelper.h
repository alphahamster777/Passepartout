#pragma once

#include <QObject>
#include <QtQml/qqml.h>

class ShareHelper : public QObject {
    Q_OBJECT
    QML_ELEMENT
    QML_SINGLETON
public:
    explicit ShareHelper(QObject *parent = nullptr);

    Q_INVOKABLE void shareText(const QString& text, const QString& title);

    static QObject* qmlInstance(QQmlEngine*, QJSEngine*) { return new ShareHelper(); }
};
