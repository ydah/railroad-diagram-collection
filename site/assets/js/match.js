export const normalize = (value) => String(value).toLowerCase().replace(/[_\-\s]/g, "");

export function matchScore(query, value) {
  const key = normalize(value);
  if (!query || !key) return 0;
  if (key === query) return 100;
  if (key.startsWith(query)) return 80;
  if (key.includes(query)) return 60;
  let position = 0;
  let first = -1;
  let last = -1;
  for (let i = 0; i < key.length && position < query.length; i++) {
    if (key[i] !== query[position]) continue;
    if (first === -1) first = i;
    last = i;
    position++;
  }
  return position === query.length ? 40 - Math.min(39, last - first + 1 - query.length) : 0;
}

export function rankSearch(entries, query, limit = 20) {
  const key = normalize(query);
  if (!key) return [];
  return entries.map((entry, order) => ({
    entry,
    order,
    score: Math.max(...[entry.n, entry.a, ...(entry.t ?? [])].filter(Boolean).map((value) => matchScore(key, value)), 0),
  })).filter(({ score }) => score > 0)
    .sort((a, b) => b.score - a.score || a.order - b.order)
    .slice(0, limit).map(({ entry }) => entry);
}
