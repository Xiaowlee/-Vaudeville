/**
 * Shorten cue copy for the phone card. The full cue still arrives and is
 * acknowledged; only what is drawn is cut to a few readable words.
 */
export function limitCueDisplay(
  text: string,
  limit: { maxWords: number; maxSentences: number },
): string {
  const { maxWords, maxSentences } = limit;
  if (!text || maxWords < 1 || maxSentences < 1) return text;

  let wordCount = 0;
  let sentenceCount = 0;
  let end = 0;

  for (const match of text.matchAll(/\S+/g)) {
    wordCount += 1;
    end = (match.index ?? 0) + match[0].length;
    if (/[.!?…]["')\]]*$/u.test(match[0])) sentenceCount += 1;
    if (wordCount >= maxWords || sentenceCount >= maxSentences) break;
  }

  if (end === 0) return text;
  if (end >= text.trimEnd().length) return text;
  return text.slice(0, end);
}
