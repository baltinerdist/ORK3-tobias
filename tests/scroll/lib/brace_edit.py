"""
Helper: extract or replace a brace-balanced block in a source file, given an opening anchor.
Avoids the nested-brace failures of greedy/non-greedy regex on multi-level objects/functions.

Usage:
  import sys; sys.path.insert(0, 'tests/scroll/lib')
  from brace_edit import extract_block, replace_block, find_block
  body, start, end = extract_block(source_text, anchor='function renderFamily(')
  new_text = replace_block(source_text, anchor='function renderFamily(', new_body='...')
"""

def find_block(text, anchor, open_brace='{', close_brace='}'):
    """Return (body_start, body_end_exclusive) for the block following the anchor.
    body_start = index just after the opening brace; body_end_exclusive = index of the matching closing brace."""
    i = text.find(anchor)
    if i < 0:
        raise ValueError(f'anchor not found: {anchor!r}')
    j = text.find(open_brace, i + len(anchor))
    if j < 0:
        raise ValueError(f'no opening {open_brace!r} after anchor')
    depth = 1
    k = j + 1
    while k < len(text) and depth > 0:
        ch = text[k]
        # Skip strings (basic heuristic: " ' ` plus escapes)
        if ch in '"\'`':
            quote = ch
            k += 1
            while k < len(text) and text[k] != quote:
                if text[k] == '\\':
                    k += 2
                else:
                    k += 1
            k += 1
            continue
        # Skip line comments //
        if ch == '/' and k + 1 < len(text) and text[k+1] == '/':
            while k < len(text) and text[k] != '\n':
                k += 1
            continue
        # Skip block comments /* */
        if ch == '/' and k + 1 < len(text) and text[k+1] == '*':
            k += 2
            while k + 1 < len(text) and not (text[k] == '*' and text[k+1] == '/'):
                k += 1
            k += 2
            continue
        if ch == open_brace:
            depth += 1
        elif ch == close_brace:
            depth -= 1
            if depth == 0:
                return j + 1, k
        k += 1
    raise ValueError(f'unbalanced braces from anchor {anchor!r}')


def extract_block(text, anchor, open_brace='{', close_brace='}'):
    s, e = find_block(text, anchor, open_brace, close_brace)
    return text[s:e], s, e


def replace_block(text, anchor, new_body, open_brace='{', close_brace='}'):
    s, e = find_block(text, anchor, open_brace, close_brace)
    return text[:s] + new_body + text[e:]


if __name__ == '__main__':
    # Self-test
    sample = '''
    function foo(x) {
        if (x > 0) {
            return { a: 1, b: { c: 2 } };
        }
        return null;
    }
    var bar = 1;
    '''
    body, s, e = extract_block(sample, 'function foo(x) ')
    assert 'if (x > 0)' in body
    assert 'return null;' in body
    assert 'var bar' not in body
    print('brace_edit self-test OK')
