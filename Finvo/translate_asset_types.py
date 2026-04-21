import json

translations = {
    "Döviz": {"en": "Currency", "de": "Währung", "ru": "Валюта"},
    "Altın": {"en": "Gold", "de": "Gold", "ru": "Золото"},
    "Emtia": {"en": "Commodities", "de": "Rohstoffe", "ru": "Сырье"},
    "Borsa": {"en": "Stock Market", "de": "Börse", "ru": "Фондовый рынок"},
    "Kripto Para": {"en": "Cryptocurrency", "de": "Kryptowährung", "ru": "Криптовалюта"}
}

file_path = "Finvo/Localizable.xcstrings"
with open(file_path, "r", encoding="utf-8") as f:
    data = json.load(f)

for category, langs in translations.items():
    if category not in data["strings"]:
        data["strings"][category] = {
            "extractionState": "manual",
            "localizations": {
                "tr": { "stringUnit": { "state": "translated", "value": category } }
            }
        }
    for lang, translation in langs.items():
        if lang not in data["strings"][category]["localizations"]:
            data["strings"][category]["localizations"][lang] = {
                "stringUnit": { "state": "translated", "value": translation }
            }
        else:
            data["strings"][category]["localizations"][lang]["stringUnit"]["value"] = translation

with open(file_path, "w", encoding="utf-8") as f:
    json.dump(data, f, indent=2, ensure_ascii=False)
