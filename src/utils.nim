proc toString*(chars: openArray[char]): string =
  result = ""
  for c in chars:
    if c != '\0':
      result.add(c)
