import json

translations = {
    "Türk Lirası": {"en": "Turkish Lira", "de": "Türkische Lira", "ru": "Турецкая лира"},
    "Amerikan Doları": {"en": "US Dollar", "de": "US-Dollar", "ru": "Доллар США"},
    "Euro": {"en": "Euro", "de": "Euro", "ru": "Евро"},
    "İngiliz Sterlini": {"en": "British Pound", "de": "Britisches Pfund", "ru": "Британский фунт"},
    "İsviçre Frangı": {"en": "Swiss Franc", "de": "Schweizer Franken", "ru": "Швейцарский франк"},
    "Kanada Doları": {"en": "Canadian Dollar", "de": "Kanadischer Dollar", "ru": "Канадский доллар"},
    "Rus Rublesi": {"en": "Russian Ruble", "de": "Russischer Rubel", "ru": "Российский рубль"},
    "BAE Dirhemi": {"en": "UAE Dirham", "de": "VAE-Dirham", "ru": "Дирхам ОАЭ"},
    "Avustralya Doları": {"en": "Australian Dollar", "de": "Australischer Dollar", "ru": "Австралийский доллар"},
    "Danimarka Kronu": {"en": "Danish Krone", "de": "Dänische Krone", "ru": "Датская крона"},
    "İsveç Kronu": {"en": "Swedish Krona", "de": "Schwedische Krone", "ru": "Шведская крона"},
    "Norveç Kronu": {"en": "Norwegian Krone", "de": "Norwegische Krone", "ru": "Норвежская крона"},
    "Japon Yeni": {"en": "Japanese Yen", "de": "Japanischer Yen", "ru": "Японская иена"},
    "Kuveyt Dinarı": {"en": "Kuwaiti Dinar", "de": "Kuwait-Dinar", "ru": "Кувейтский динар"},
    "Güney Afrika Randı": {"en": "South African Rand", "de": "Südafrikanischer Rand", "ru": "Южноафриканский рэнд"},
    "Bahreyn Dinarı": {"en": "Bahraini Dinar", "de": "Bahrain-Dinar", "ru": "Бахрейнский динар"},
    "Libya Dinarı": {"en": "Libyan Dinar", "de": "Libyscher Dinar", "ru": "Ливийский динар"},
    "Suudi Arabistan Riyali": {"en": "Saudi Riyal", "de": "Saudi-Riyal", "ru": "Саудовский риял"},
    "Irak Dinarı": {"en": "Iraqi Dinar", "de": "Irakischer Dinar", "ru": "Иракский динар"},
    "İsrail Şekeli": {"en": "Israeli New Shekel", "de": "Israelischer Schekel", "ru": "Израильский шекель"},
    "Hindistan Rupisi": {"en": "Indian Rupee", "de": "Indische Rupie", "ru": "Индийская рупия"},
    "Meksika Pesosu": {"en": "Mexican Peso", "de": "Mexikanischer Peso", "ru": "Мексиканское песо"},
    "Macar Forinti": {"en": "Hungarian Forint", "de": "Ungarischer Forint", "ru": "Венгерский форинт"},
    "Yeni Zelanda Doları": {"en": "New Zealand Dollar", "de": "Neuseeland-Dollar", "ru": "Новозеландский доллар"},
    "Brezilya Reali": {"en": "Brazilian Real", "de": "Brasilianischer Real", "ru": "Бразильский реал"},
    "Endonezya Rupisi": {"en": "Indonesian Rupiah", "de": "Indonesische Rupiah", "ru": "Индонезийская рупия"},
    "Çek Korunası": {"en": "Czech Koruna", "de": "Tschechische Krone", "ru": "Чешская крона"},
    "Polonya Zlotisi": {"en": "Polish Zloty", "de": "Polnischer Zloty", "ru": "Польский злотый"},
    "Rumen Leyi": {"en": "Romanian Leu", "de": "Rumänischer Leu", "ru": "Румынский лей"},
    "Çin Yuanı": {"en": "Chinese Yuan", "de": "Chinesischer Yuan", "ru": "Китайский юань"},
    "Arjantin Pesosu": {"en": "Argentine Peso", "de": "Argentinischer Peso", "ru": "Аргентинское песо"},
    "Arnavutluk Leki": {"en": "Albanian Lek", "de": "Albanischer Lek", "ru": "Албанский лек"},
    "Azerbaycan Manatı": {"en": "Azerbaijani Manat", "de": "Aserbaidschan-Manat", "ru": "Азербайджанский манат"},
    "Bosna Hersek Markı": {"en": "Bosnia-Herzegovina Convertible Mark", "de": "Bosnien-Herzegowina Konvertible Mark", "ru": "Конвертируемая марка Боснии и Герцеговины"},
    "Şili Pesosu": {"en": "Chilean Peso", "de": "Chilenischer Peso", "ru": "Чилийское песо"},
    "Kolombiya Pesosu": {"en": "Colombian Peso", "de": "Kolumbianischer Peso", "ru": "Колумбийское песо"},
    "Kosta Rika Kolonu": {"en": "Costa Rican Colón", "de": "Costa-Rica-Colón", "ru": "Коста-риканский колон"},
    "Cezayir Dinarı": {"en": "Algerian Dinar", "de": "Algerischer Dinar", "ru": "Алжирский динар"},
    "Mısır Lirası": {"en": "Egyptian Pound", "de": "Ägyptisches Pfund", "ru": "Египетский фунт"},
    "Hong Kong Doları": {"en": "Hong Kong Dollar", "de": "Hongkong-Dollar", "ru": "Гонконгский доллар"},
    "İzlanda Kronu": {"en": "Icelandic Króna", "de": "Isländische Krone", "ru": "Исландская крона"},
    "Güney Kore Wonu": {"en": "South Korean Won", "de": "Südkoreanischer Won", "ru": "Южнокорейская вона"},
    "Kazak Tengesi": {"en": "Kazakhstani Tenge", "de": "Kasachischer Tenge", "ru": "Казахстанский тенге"},
    "Lübnan Lirası": {"en": "Lebanese Pound", "de": "Libanesisches Pfund", "ru": "Ливанский фунт"},
    "Sri Lanka Rupisi": {"en": "Sri Lankan Rupee", "de": "Sri-Lanka-Rupie", "ru": "Шри-Ланкийская рупия"},
    "Fas Dirhemi": {"en": "Moroccan Dirham", "de": "Marokkanischer Dirham", "ru": "Марокканский дирхам"},
    "Moldova Leyi": {"en": "Moldovan Leu", "de": "Moldauischer Leu", "ru": "Молдавский лей"},
    "Makedon Dinarı": {"en": "Macedonian Denar", "de": "Mazedonischer Denar", "ru": "Македонский денар"},
    "Malezya Ringgiti": {"en": "Malaysian Ringgit", "de": "Malaysischer Ringgit", "ru": "Малайзийский ринггит"},
    "Umman Riyali": {"en": "Omani Rial", "de": "Omanischer Rial", "ru": "Оманский риал"},
    "Peru Solü": {"en": "Peruvian Sol", "de": "Peruanischer Sol", "ru": "Перуанский соль"},
    "Filipinler Pesosu": {"en": "Philippine Peso", "de": "Philippinischer Peso", "ru": "Филиппинское песо"},
    "Pakistan Rupisi": {"en": "Pakistani Rupee", "de": "Pakistanische Rupie", "ru": "Пакистанская рупия"},
    "Katar Riyali": {"en": "Qatari Riyal", "de": "Katar-Riyal", "ru": "Катарский риал"},
    "Sırp Dinarı": {"en": "Serbian Dinar", "de": "Serbischer Dinar", "ru": "Сербский динар"},
    "Singapur Doları": {"en": "Singapore Dollar", "de": "Singapur-Dollar", "ru": "Сингапурский доллар"},
    "Suriye Lirası": {"en": "Syrian Pound", "de": "Syrisches Pfund", "ru": "Сирийский фунт"},
    "Tayland Bahtı": {"en": "Thai Baht", "de": "Thailändischer Baht", "ru": "Тайский бат"},
    "Yeni Tayvan Doları": {"en": "New Taiwan Dollar", "de": "Neuer Taiwan-Dollar", "ru": "Новый тайваньский доллар"},
    "Ukrayna Grivnası": {"en": "Ukrainian Hryvnia", "de": "Ukrainische Hrywnja", "ru": "Украинская гривна"},
    "Uruguay Pesosu": {"en": "Uruguayan Peso", "de": "Uruguayischer Peso", "ru": "Уругвайское песо"},
    "Gürcistan Larisi": {"en": "Georgian Lari", "de": "Georgischer Lari", "ru": "Грузинский лари"},
    "Tunus Dinarı": {"en": "Tunisian Dinar", "de": "Tunesischer Dinar", "ru": "Тунисский динар"},
    "Bulgar Levası": {"en": "Bulgarian Lev", "de": "Bulgarischer Lew", "ru": "Болгарский лев"},
    "Gram Altın": {"en": "Gold Gram", "de": "Gold Gramm", "ru": "Золото (Грамм)"},
    "BIST 100 Endeksi": {"en": "BIST 100 Index", "de": "BIST 100 Index", "ru": "Индекс BIST 100"},
    "Bitcoin (Dijital)": {"en": "Bitcoin (Digital)", "de": "Bitcoin (Digital)", "ru": "Биткоин (цифровой)"},
    "Gümüş": {"en": "Silver", "de": "Silber", "ru": "Серебро"},
    "Brent Petrol": {"en": "Brent Crude Oil", "de": "Brent Rohöl", "ru": "Нефть марки Brent"},
    "Ons Altın": {"en": "Ounce Gold", "de": "Feinunze Gold", "ru": "Унция Золота"},
    "Has Altın (24 Ayar)": {"en": "Pure Gold (24k)", "de": "Feingold (24k)", "ru": "Чистое золото (24 карата)"},
    "Çeyrek Altın": {"en": "Quarter Gold", "de": "Viertelgold", "ru": "Четверть золота"},
    "Yarım Altın": {"en": "Half Gold", "de": "Halbes Gold", "ru": "Половина золота"},
    "Tam Altın": {"en": "Full Gold", "de": "Ganzes Gold", "ru": "Полное золото"},
    "Cumhuriyet Altını": {"en": "Republic Gold", "de": "Republik Gold", "ru": "Республиканское золото"},
    "Ata Altın": {"en": "Ata Gold", "de": "Ata Gold", "ru": "Золото Ата"},
    "14 Ayar Altın": {"en": "14k Gold", "de": "14-karätiges Gold", "ru": "Золото 14 карат"},
    "18 Ayar Altın": {"en": "18k Gold", "de": "18-karätiges Gold", "ru": "Золото 18 карат"},
    "Yeni İstanbul Altını": {"en": "New Istanbul Gold", "de": "Neues Istanbul Gold", "ru": "Новое стамбульское золото"},
    "İki Buçuklu Altın": {"en": "Two and a Half Gold", "de": "Zweieinhalb Gold", "ru": "Два с половиной золота"},
    "Beşli Altın": {"en": "Quintuple Gold", "de": "Fünffaches Gold", "ru": "Пятикратное золото"},
    "Gremse Altın": {"en": "Gremse Gold", "de": "Gremse Gold", "ru": "Золото Гремсе"},
    "Reşat Altın": {"en": "Reşat Gold", "de": "Reşat Gold", "ru": "Золото Решат"},
    "Hamit Altın": {"en": "Hamit Gold", "de": "Hamit Gold", "ru": "Золото Хамит"},
    "Platin": {"en": "Platinum", "de": "Platin", "ru": "Платина"},
    "Paladyum": {"en": "Palladium", "de": "Palladium", "ru": "Палладий"}
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
