"""Describe synthetic recognizer output, without turning fixtures into accuracy claims."""
import json
from pathlib import Path
import re
import sys
import unicodedata


def words(text, language):
    text = "".join(char for char in unicodedata.normalize("NFKD", text.lower()) if not unicodedata.combining(char))
    numbers = {"5": "cinco", "6": "seis"} if language.startswith("es") else {"5": "five", "6": "six"}
    return [numbers.get(word, word) for word in re.findall(r"\w+", text)]


def distance(expected, actual):
    row = list(range(len(actual) + 1))
    for i, left in enumerate(expected, 1):
        next_row = [i]
        for j, right in enumerate(actual, 1):
            next_row.append(min(next_row[-1] + 1, row[j] + 1, row[j - 1] + (left != right)))
        row = next_row
    return row[-1]


path = Path(sys.argv[1])
report = json.loads(path.read_text(encoding="utf-8-sig"))
for result in report["results"]:
    # Keep the original final and segmented callbacks in the report. Partial text
    # is not promoted to a committed result or used to hide a missing final.
    committed = " ".join(result.get("segments", [])).strip()
    final = result.get("transcript", "").strip()
    if final:
        committed = final
    result["scored_source"] = "final" if final else "committed_segments"
    result["committed_transcript"] = committed
    reference = words(result["expected_words"], result["language"])
    errors = distance(reference, words(committed, result["language"]))
    result["normalized_word_errors"] = errors
    result["reference_word_count"] = len(reference)
    result["normalized_word_error_rate"] = round(errors / len(reference), 4)
    print(f'{result["id"]}: errors={errors}/{len(reference)} native_error={result["error"]} first_partial_ms={result["first_partial_ms"]}')
    print(f"  {committed}")
output = path.with_name(path.stem + "-scored.json")
output.write_text(json.dumps(report, ensure_ascii=False, indent=2), encoding="utf-8")
print(output)
