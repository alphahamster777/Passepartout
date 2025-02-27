#pragma once

#include <QObject>
#include <QQmlListProperty>
#include <QQmlListProperty>
#include "recSetManager.h"

class SetPreviewMenuController : public QObject {
    Q_OBJECT
    Q_PROPERTY(QList<QVariant> expressionList READ getExpressionList NOTIFY expressionListChanged)

public:
    explicit SetPreviewMenuController(RecSetManager* manager, QObject* parent = nullptr);

    QList<QVariant> getExpressionList() const;

public slots:
    void startTests();

signals:
    void expressionListChanged();
    void navigateToTest(); // Signal to navigate to the test page

private:
    RecSetManager* m_recSetManager;
    QList<QVariant> m_expressionList;
};
