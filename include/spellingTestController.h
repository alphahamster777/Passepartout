#pragma once

#include <QObject>
#include <QString>
#include <QtQml/qqml.h>
// #include <memory>

#include "recSetManager.h"

class SpellingTestController : public QObject {
    Q_OBJECT
    QML_ELEMENT
    Q_PROPERTY(int totalQuestions READ totalQuestions  WRITE setTotalQuestions NOTIFY totalQuestionsChanged)
    Q_PROPERTY(int correctAnswers READ correctAnswers  WRITE setCorrectAnswers NOTIFY correctAnswersChanged)
    Q_PROPERTY(QString currentWord READ currentWord  WRITE setCurrentWord NOTIFY currentWordChanged)
    Q_PROPERTY(QString currentHint READ currentHint  WRITE setCurrentHint NOTIFY currentHintChanged)
    Q_PROPERTY(QString currentImageUrl READ currentImageUrl  WRITE setCurrentImageUrl NOTIFY currentImageUrlChanged) //todo rename to currentImageUrl
    Q_PROPERTY(QString currentAudioUrl READ currentAudioUrl  WRITE setCurrentAudioUrl NOTIFY currentAudioUrlChanged) //todo rename to currentAudioUrl

    // Q_PROPERTY(QList<> audioUrl READ audioUrl  WRITE setAudioUrl NOTIFY audioUrlChanged)
public:
    explicit SpellingTestController(QObject* parent = nullptr);
    Q_INVOKABLE void initialize(QObject* manager, int idx);

    Q_INVOKABLE void nextQuestion();
    int totalQuestions() const { return m_totalQuestions; }
    int correctAnswers() const { return m_correctAnswers; }
    QString currentWord() const { return m_currentWord; }
    QString currentHint() const { return m_currentHint; }
    QString currentImageUrl() const { return m_currentImageUrl; }
    QString currentAudioUrl() const { return m_currentAudioUrl; }

// Setters
    void setTotalQuestions(int totalQuestions) {
        if (m_totalQuestions != totalQuestions) {
            m_totalQuestions = totalQuestions;
            emit totalQuestionsChanged();
        }
    }

    void setCorrectAnswers(int correctAnswers) {
        if (m_correctAnswers != correctAnswers) {
            m_correctAnswers = correctAnswers;
            emit correctAnswersChanged();
        }
    }

    void setCurrentWord(const QString &currentWord) {
        if (m_currentWord != currentWord) {
            m_currentWord = currentWord;
            emit currentWordChanged();
        }
    }

    void setCurrentHint(const QString &currentHint) {
        if (m_currentHint != currentHint) {
            m_currentHint = currentHint;
            emit currentHintChanged();
        }
    }

    void setCurrentImageUrl(const QString &imageUrl) {
        if (m_currentImageUrl != imageUrl) {
            m_currentImageUrl = imageUrl;
            emit currentImageUrlChanged();
        }
    }

    void setCurrentAudioUrl(const QString &audioUrl) {
        if (m_currentAudioUrl != audioUrl) {
            m_currentAudioUrl = audioUrl;
            emit currentAudioUrlChanged();
        }
    }
signals:
    void totalQuestionsChanged();
    void correctAnswersChanged();
    void currentWordChanged();
    void currentHintChanged();
    void currentImageUrlChanged();
    void currentAudioUrlChanged();

private:
    ///tmp{
    int currentRecSetNum = 0;
    int currentDictRecNum = 0;
    ///tmp}
    RecSetManager* m_recSetManager;
    int m_totalQuestions = 0;
    int m_correctAnswers = 0;
    QString m_currentWord;
    QString m_currentHint;
    QString m_currentImageUrl;
    QString m_currentAudioUrl;
};
