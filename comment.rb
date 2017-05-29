def is_comment(row)
  h = row.to_h
  (h[h.keys.first] || '').strip[0] == '#' || h == {}
end
