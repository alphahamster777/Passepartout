#pragma once

#include <QObject>
#include <QString>
#include <QVariant>

#include "languageHelper.h"

class DictRec : public QObject {
    Q_OBJECT
public:
    DictRec(size_t exprlangID, size_t hintLangID, const QString& expression, const QString& hint,
            const QString& audioPath = {}, const QString& imagePath = {}, const QString& exampleUsage = {});

    DictRec(const DictRec& other);
    DictRec(DictRec&& other);
    DictRec& operator=(const DictRec& other);
    DictRec& operator=(DictRec&& other);

    // Getters
    Q_INVOKABLE int getExprLanguageID() const { return m_exprLangID; }
    Q_INVOKABLE int getHintLanguageID() const { return m_hintLangID; }
    Q_INVOKABLE QString getExpression() const { return m_expression; }
    Q_INVOKABLE QString getHint() const { return m_hint; }
    Q_INVOKABLE QString getImagePath() const { return m_imagePath; }
    Q_INVOKABLE QString getAudioPath() const { return m_audioPath; }
    Q_INVOKABLE QString getExampleUsage() const { return m_exampleUsage; }

    // Setters
    void setExprLangID(int languageID) { m_exprLangID = languageID; }
    void setHintLangID(int languageID) { m_hintLangID = languageID; }
    void setExpression(const QString& expression) { m_expression = expression; }
    void setMeaning(const QString& hint) { m_hint = hint; }
    void setAudioPath(QString& audioPath) { m_audioPath = audioPath; }
    void setImagePath(const QString& imagePath) { m_imagePath = imagePath; }
    void setExampleUsage(const QString& exampleUsage) { m_exampleUsage = exampleUsage; }

    // auto operator<=>(const DictRec& other) const;
    bool operator==(const DictRec& other) const;
    // bool operator<(const DictRec& other) const;

private:
    int m_exprLangID;
    int m_hintLangID = 0;
    QString m_expression;
    QString m_hint;
    QString m_audioPath;
    QString m_imagePath;
    QString m_exampleUsage;
};
