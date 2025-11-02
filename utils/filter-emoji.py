import json

print("STARTING...")

with open("emoji-all.txt", "r", encoding="utf-8") as infile, open("emoji2.json", "w", encoding="utf-8") as outfile:
    items = []
    for line in infile:
        emoji = line.strip().split("\t")[0:2]

        if len(emoji) > 1:
            items.append({"emoji": emoji[0], "name": [emoji[1]]})

    json.dump(items, outfile, ensure_ascii=False, indent=2)

print("DONE")