#pragma once
#include <string>
// #include <optional>
#include <vector>
// #include <memory>

#include "dictRec.h"
#include "recSet.h"

class RecSetManager {
public:
    // Create a new word set
    bool createRecSet(const std::string& setName) {

        for (auto& RecSet : m_recSetVec) {
            if (RecSet.getSetName() == setName) {
                return false; //Word already present
            }
        }

        m_recSetVec.emplace_back(RecSet{setName});
        return true; // Word set not found
    }

    // Create a new word set
    bool deleteRecSet(const std::string& setName) {
        for (auto it = m_recSetVec.begin(); it != m_recSetVec.end(); ++it) {
            if (it->getSetName() == setName) {
                m_recSetVec.erase(it);  // Remove the element from the vector
                return true;           // Element successfully removed
            }
        }
        return false;  // Word set not found
    }

    // Edit an existing word set
    bool addRecToRecSet(const std::string& setName, const DictRec& newWord) {
        for (auto& recSet : m_recSetVec) {
            if (recSet.getSetName() == setName) {
                recSet.addWord(newWord);//???
                return true;
            }
        }
        return false; // Word set not found
    }

    // Remove a word from a word set
    bool removeRecFromRecSet(const std::string& setName, const DictRec& setElement) {
        for (auto& recSet : m_recSetVec) {
            if (recSet.getSetName() == setName) {
                return recSet.removeWord(setElement);
            }
        }
        return false; // Word set not found
    }

    // Get all word sets
    std::vector<RecSet> getAllRecSets() const { return m_recSetVec; }
private:
    std::vector<RecSet> m_recSetVec; // Collection of espresion sets to learn.
};
