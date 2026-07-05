#!/usr/bin/env python3
"""Enrich system/assets/scroll/packs/catalog.json with `collection` + `group`.

Derives two grouping fields from the existing catalog metadata so the scroll
designer's Art picker can offer type-based collections (a picker for borders,
a picker for award-type emblems, etc.). Reproducible — safe to re-run.

  collection: 'borders' | 'emblems' | 'backgrounds'   (top-level picker bucket)
  group:      a human label within the collection      (e.g. 'Dragon', 'Celtic (Gold)')

Run: python3 tools/scroll_pack_grouping.py
"""
import json
import os

CATALOG = os.path.join(os.path.dirname(__file__), '..', 'system', 'assets', 'scroll', 'packs', 'catalog.json')

# 'orders' art is the Amtgard "Order Images" collection.
CATEGORY_TO_COLLECTION = {'borders': 'borders', 'orders': 'order_images', 'backgrounds': 'backgrounds'}

# order in which groups should appear in each collection's type picker
GROUP_ORDER = {
    'borders': ['Celtic (Gold)', 'Ribbon', 'Rose & Vine', 'Knotwork', 'Scrollwork', 'Chain & Rope', 'Geometric', 'Ornamental B&W', 'Warlord', 'Side Panels', 'Other'],
    'order_images': ['Crown', 'Dragon', 'Lion', 'Rose', 'Owl', 'Warrior', 'Archery', 'Griffon', 'Hydra', 'Flame', 'Garber', 'Jovious', 'Masks', 'Masterhoods', 'Sashes', 'Smith', 'Zodiac', 'Logos', 'Other'],
    'backgrounds': ['Paper & Stone', 'Scenic'],
}

PAPER_BACKGROUNDS = {'brown_tea_stained.png', 'white_marble.png', 'gray_smoke.png'}


def border_group(name, tags):
    t = set(tags)
    if 'side' in t:
        return 'Side Panels'
    if 'chain' in t or 'rope' in t or 'braid' in t:
        return 'Chain & Rope'
    if 'geometric' in t or 'greek' in t:
        return 'Geometric'
    if 'celtic' in t or name.startswith('bluegold'):
        return 'Celtic (Gold)'
    if '2ribbon' in t:
        return 'Ribbon'
    if 'knotwork' in t:
        return 'Knotwork'
    if 'rose' in t or 'vine' in t or 'ivy' in t or 'floral' in t:
        return 'Rose & Vine'
    if 'scroll' in t or 'scrollwork' in t or 'nouveau' in t or 'ornate' in t:
        return 'Scrollwork'
    if 'warlord' in name or 'warlord' in t or 'warlordbw' in t:
        return 'Warlord'
    if 'blackwhite' in name:
        return 'Ornamental B&W'
    return 'Other'


def group_for(item):
    coll = CATEGORY_TO_COLLECTION.get(item.get('category'), 'order_images')
    name = item['file'].split('/')[-1]
    if coll == 'order_images':
        at = item.get('award_type') or 'other'
        return coll, at.replace('_', ' ').title()
    if coll == 'backgrounds':
        return coll, ('Paper & Stone' if name in PAPER_BACKGROUNDS else 'Scenic')
    return coll, border_group(name, item.get('tags', []))


def main():
    path = os.path.normpath(CATALOG)
    catalog = json.load(open(path))
    counts = {}
    for item in catalog:
        coll, grp = group_for(item)
        item['collection'] = coll
        item['group'] = grp
        counts.setdefault(coll, {}).setdefault(grp, 0)
        counts[coll][grp] += 1
    # stable sort: collection order, then GROUP_ORDER, then name
    def sort_key(it):
        coll = it['collection']
        order = GROUP_ORDER.get(coll, [])
        gi = order.index(it['group']) if it['group'] in order else len(order)
        return (list(CATEGORY_TO_COLLECTION.values()).index(coll), gi, it['file'])
    catalog.sort(key=sort_key)
    json.dump(catalog, open(path, 'w'), indent=1)
    for coll in ('borders', 'order_images', 'backgrounds'):
        print(coll + ':')
        for grp in GROUP_ORDER.get(coll, []):
            n = counts.get(coll, {}).get(grp, 0)
            if n:
                print('  %-16s %d' % (grp, n))


if __name__ == '__main__':
    main()
