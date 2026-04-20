/// Ukrainian vowel letters used for syllable counting.
const ukrainianVowels = {'А', 'Е', 'И', 'І', 'О', 'У', 'Є', 'Ї', 'Ю', 'Я'};

/// Counts syllables in a Ukrainian word by tallying vowels.
int countSyllables(String word) {
  return word.toUpperCase().split('').where(ukrainianVowels.contains).length;
}
