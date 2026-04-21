import json
import re
import os

XCSTRINGS_PATH = 'Finvo/Finvo/Localizable.xcstrings'

def find_swift_files():
    swift_files = []
    for root, _, files in os.walk('Finvo/Finvo/Core'):
        for f in files:
            if f.endswith('.swift'):
                swift_files.append(os.path.join(root, f))
    return swift_files

def extract_strings(file_content):
    strings = set()
    
    # Text("...")
    matches = re.findall(r'Text\(\s*"([^"\\]+)"\s*\)', file_content)
    strings.update(matches)
    
    # "text".localized
    matches = re.findall(r'"([^"\\]+)"\.localized', file_content)
    strings.update(matches)
    
    # LocalizedStringKey("...")
    matches = re.findall(r'LocalizedStringKey\(\s*"([^"\\]+)"\s*\)', file_content)
    strings.update(matches)
    
    # String(localized: "...")
    matches = re.findall(r'String\(\s*localized:\s*"([^"\\]+)"\s*\)', file_content)
    strings.update(matches)

    # Some variables inside Text with string interp: Text("\(val) Text") -> not safe to parse with basic regex without matching %@, so we ignore it.
    
    return strings

def main():
    strings = set()
    for f in find_swift_files():
        with open(f, 'r', encoding='utf-8') as fr:
            content = fr.read()
            strings.update(extract_strings(content))

    # Add mock data
    mock_data = ["Abonelikler", "Banka & Finans", "Araba & Ulaşım", "Konut & Faturalar", "Market & Mutfak", "Yeme İçme & Sosyal", "Teknoloji & Yazılım", "Oyun & Donanım", "Ev & Yaşam", "Sağlık & Bakım", "Giyim & Aksesuar", "Eğitim & Gelişim", "Seyahat & Tatil", "Hobi & Müzik", "Hediye & Bağış", "Maaş & Ana Gelir", "Freelance & Projeler", "Pasif & Diğer", "Kişisel", "Paylaşımlı", "Genel Kullanım", "İş / Ticari", "Birikim", "Kurucu", "Yönetici", "Üye", "Görüntüleyici", "Davet Bekleniyor", "Günlük", "Haftalık", "Aylık", "Yıllık", "Gelir", "Gider"]
    strings.update(mock_data)

    with open(XCSTRINGS_PATH, 'r', encoding='utf-8') as f:
        data = json.load(f)

    if 'strings' not in data:
        data['strings'] = {}

    added = 0
    for s in strings:
        if s not in data['strings'] and len(s) > 0 and s.strip() != "":
            data['strings'][s] = {
                "extractionState": "manual",
                "localizations": {
                    "tr": {
                        "stringUnit": {
                            "state": "translated",
                            "value": s
                        }
                    }
                }
            }
            added += 1

    with open(XCSTRINGS_PATH, 'w', encoding='utf-8') as f:
        json.dump(data, f, ensure_ascii=False, indent=2)
        
    print(f"Added {added} missing strings.")

if __name__ == '__main__':
    main()
