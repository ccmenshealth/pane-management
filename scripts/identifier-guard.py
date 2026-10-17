#!/usr/bin/env python3
"""Identifier guard: fails when ADDED lines in a diff look like patient identifiers.

Checked patterns (on added lines only): SSN; labelled DOB with a plausible birth year; labelled MRN/FIN digits;
CCM-NNNNN record numbers; US phone numbers; LAST, FIRST (caps) next to a 5+ digit number; personal e-mail domains.
A line is allowed when it carries a synthetic marker (ROE/DOE/POE personas, 555-01xx phones, the 4711/471 synthetic number
block, CCM-471NN, example.com, or the words synthetic/fixture/placeholder/sentinel) or sits in a fixture path.
Output names file, line and pattern only; it never prints the matched text.

usage: identifier-guard.py --base <rev> --head <rev>      (scans `git diff base..head`)
       identifier-guard.py --staged                        (scans the index, for a pre-commit hook)
       identifier-guard.py --files f1 f2 ...               (scans whole files)
"""
import re, subprocess, sys, argparse

PATTERNS = {
    "ssn": re.compile(r"\b(?!000|666|9\d\d)\d{3}-(?!00)\d{2}-(?!0000)\d{4}\b"),
    "dob": re.compile(r"(?:(?i:(?<![a-z])(?:dob|date[\s_]*of[\s_]*birth|birth[\s_]*date|dateofbirth|birthdate))|(?<=[a-z])(?:DOB|Dob))(?![a-z])[^\n\d]{0,25}(\d{1,4}[/\-.]\d{1,2}[/\-.]\d{1,4})"),
    "mrn": re.compile(r"(?:(?i:(?<![a-z])mrn)|(?<=[a-z])Mrn|\bFIN)(?![a-z])[^\n\d]{0,15}(\d{5,14})\b"),
    "ccm": re.compile(r"(?i)\bCCM[-\s]?\d{5}\b"),
    "phone": re.compile(r"(?<![\d.])(?:\(\d{3}\)\s?\d{3}[-. ]\d{4}|\b\d{3}([-.])\d{3}\1\d{4}|\+1[\s-]?\d{3}[\s-]?\d{3}[\s-]?\d{4}|\+1\d{10})\b(?![\d.])"),
    "name_near_id": re.compile(r"\b[A-Z][A-Z'\-]{2,30}(?:\s[A-Z][A-Z'\-]{1,30})?,\s?[A-Z][A-Z'\-]{1,30}\b[^\n]{0,80}?(?:\b\d{5,14}\b|\b\d{1,2}/\d{1,2}/\d{2,4}\b)"),
    "email": re.compile(r"(?i)(?<![a-z0-9._%+\-])[a-z0-9._%+\-]{1,64}@(?:gmail|googlemail|yahoo|ymail|rocketmail|hotmail|outlook|icloud|mac|me|aol|live|msn|comcast|att|sbcglobal|verizon|cox|charter|earthlink|frontier|proton|protonmail|pm|gmx)\.(?:com|net|me|co\.uk)\b"),
}
LINE_MARKER = re.compile(r"(?i)\b(?:synthetic|fixture|placeholder|sentinel)\b")   # explicit, documented opt-out words only
SYNTH_VALUE = re.compile(r"\b(?:ROE|DOE|POE|BLOGGS|MOCKLEY|STUBBS|FAKEMAN)\b|555[-. ]?01\d\d|55501\d\d|\b4711\d*\b|(?i:CCM[-\s]?)?\b471\d{2}\b|(?i:CCM[-\s]?)(?:0000\d|12345|99999)\b")
PLACEHOLDER_DOB = re.compile(r"^(?:1900|1970)[-/.]0?1[-/.]0?1$|^0?1[-/.]0?1[-/.](?:1900|1970)$")
FIXTURE_PATH = re.compile(r"(?i)(^|/)(tests?|__tests__|fixtures?|__fixtures__|__mocks__|mocks?|e2e|replay|worlds?)(/|$)|\.(test|spec)\.[a-z]+$")
PLACEHOLDER_DATE = re.compile(r"^(?:190\d|20[2-9]\d)$")   # synthetic DOB years: 1900-1909 or 2020+ (patients born 1910-2019 are real)


def check_line(path, lineno, text, findings):
    if LINE_MARKER.search(text):
        return
    fixture = bool(FIXTURE_PATH.search(path))
    for name, rx in PATTERNS.items():
        if fixture and name in ("ccm", "mrn", "dob"):
            continue   # test fixtures may carry record-number/DOB shapes; names, phones, e-mails and SSNs are still checked there
        for m in rx.finditer(text):           # every match judged on its OWN text, not the line
            if SYNTH_VALUE.search(m.group(0)):
                continue
            if name == "dob":
                y = re.findall(r"\d{4}", m.group(1))
                if PLACEHOLDER_DOB.match(m.group(1)) or (y and PLACEHOLDER_DATE.match(y[0])):
                    continue
            findings.append((path, lineno, name))
            break


GIT_DIFF = ["git", "-c", "diff.noprefix=false", "-c", "diff.mnemonicPrefix=false", "diff", "--no-color", "--no-ext-diff", "--no-textconv", "--unified=0"]


def scan_diff(args):
    r = subprocess.run(GIT_DIFF + args, capture_output=True, text=True, errors="replace")
    if r.returncode != 0:                      # fail CLOSED: an unreadable diff is never "clean"
        sys.exit(f"identifier guard: git diff failed (exit {r.returncode}); refusing to pass")
    findings, path, lineno, in_hunk = [], None, 0, False
    for line in r.stdout.splitlines():
        if line.startswith("diff --git "):
            in_hunk, path = False, None
        elif not in_hunk and line.startswith("+++ "):
            path = line[6:] if line.startswith("+++ b/") else line[4:]
        elif line.startswith("@@"):
            in_hunk = True
            m = re.search(r"\+(\d+)", line)
            lineno = int(m.group(1)) - 1 if m else 0
        elif in_hunk and line.startswith("+"):
            lineno += 1
            if path and path != "/dev/null":
                check_line(path, lineno, line[1:], findings)
    return findings


def scan_files(paths):
    findings = []
    for p in paths:
        try:
            with open(p, encoding="utf-8", errors="replace") as f:
                for i, text in enumerate(f, 1):
                    check_line(p, i, text, findings)
        except OSError:
            continue
    return findings


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--base"); ap.add_argument("--head", default="HEAD"); ap.add_argument("--staged", action="store_true")
    ap.add_argument("--files", nargs="*"); ap.add_argument("--three-dot", action="store_true")
    a = ap.parse_args()
    if a.files:
        findings = scan_files(a.files)
    elif a.staged:
        findings = scan_diff(["--cached"])
    else:
        if not a.base:
            sys.exit("need --base <rev> (or --staged / --files)")
        findings = scan_diff([f"{a.base}...{a.head}" if a.three_dot else f"{a.base}..{a.head}", "--"])
    if findings:
        print("identifier guard: possible patient identifiers in added lines (file:line pattern). Use synthetic values (ROE/DOE personas, 555-01xx phones, 4711… numbers, CCM-471NN) or move the data out of the repo. If this is a push to the default branch, the text is already in history: tell Steve before doing anything else.")
        for p, n, k in findings:
            print(f"  {p}:{n} {k}")
        sys.exit(1)
    print("identifier guard: clean")


if __name__ == "__main__":
    main()
