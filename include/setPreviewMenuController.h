#pragma once

#include <QQmlListProperty>
#include <QObject>
#include <QtQml/qqml.h>

#include "recSetManager.h"

class SetPreviewMenuController : public QObject {
    Q_OBJECT
    QML_ELEMENT
    Q_PROPERTY(QList<QVariant> expressionList READ getExpressionList NOTIFY expressionListChanged)

public:
    explicit SetPreviewMenuController(QObject* parent = nullptr);
    Q_INVOKABLE void initialize(QObject* manager, int idx);

    QList<QVariant> getExpressionList() const;

public slots:
    // void startTests();

signals:
    void expressionListChanged();

private:
    RecSetManager* m_recSetManager;
    QList<QVariant> m_expressionList;
};
