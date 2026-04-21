import json
import os

translations = {
    "Netflix": {"en": "Netflix", "de": "Netflix", "ru": "Netflix"},
    "Disney+": {"en": "Disney+", "de": "Disney+", "ru": "Disney+"},
    "YouTube Premium": {"en": "YouTube Premium", "de": "YouTube Premium", "ru": "YouTube Premium"},
    "Amazon Prime": {"en": "Amazon Prime", "de": "Amazon Prime", "ru": "Amazon Prime"},
    "BluTV": {"en": "BluTV", "de": "BluTV", "ru": "BluTV"},
    "MUBI": {"en": "MUBI", "de": "MUBI", "ru": "MUBI"},
    "Gain / Exxen": {"en": "Gain / Exxen", "de": "Gain / Exxen", "ru": "Gain / Exxen"},
    "Spotify": {"en": "Spotify", "de": "Spotify", "ru": "Spotify"},
    "Apple Music": {"en": "Apple Music", "de": "Apple Music", "ru": "Apple Music"},
    "Tidal / Deezer": {"en": "Tidal / Deezer", "de": "Tidal / Deezer", "ru": "Tidal / Deezer"},
    "PlayStation Plus": {"en": "PlayStation Plus", "de": "PlayStation Plus", "ru": "PlayStation Plus"},
    "Xbox Game Pass": {"en": "Xbox Game Pass", "de": "Xbox Game Pass", "ru": "Xbox Game Pass"},
    "Nintendo Online": {"en": "Nintendo Online", "de": "Nintendo Online", "ru": "Nintendo Online"},
    "EA Play": {"en": "EA Play", "de": "EA Play", "ru": "EA Play"},
    "Gemini Advanced": {"en": "Gemini Advanced", "de": "Gemini Advanced", "ru": "Gemini Advanced"},
    "ChatGPT Plus": {"en": "ChatGPT Plus", "de": "ChatGPT Plus", "ru": "ChatGPT Plus"},
    "Claude Pro": {"en": "Claude Pro", "de": "Claude Pro", "ru": "Claude Pro"},
    "GitHub Copilot": {"en": "GitHub Copilot", "de": "GitHub Copilot", "ru": "GitHub Copilot"},
    "Midjourney": {"en": "Midjourney", "de": "Midjourney", "ru": "Midjourney"},
    "Cursor IDE": {"en": "Cursor IDE", "de": "Cursor IDE", "ru": "Cursor IDE"},
    "Adobe Creative Cloud": {"en": "Adobe Creative Cloud", "de": "Adobe Creative Cloud", "ru": "Adobe Creative Cloud"},
    "Figma Pro": {"en": "Figma Pro", "de": "Figma Pro", "ru": "Figma Pro"},
    "Canva Pro": {"en": "Canva Pro", "de": "Canva Pro", "ru": "Canva Pro"},
    "Notion": {"en": "Notion", "de": "Notion", "ru": "Notion"},
    "iCloud+": {"en": "iCloud+", "de": "iCloud+", "ru": "iCloud+"},
    "Google One": {"en": "Google One", "de": "Google One", "ru": "Google One"},
    "Dropbox": {"en": "Dropbox", "de": "Dropbox", "ru": "Dropbox"},
    "Vercel / Supabase": {"en": "Vercel / Supabase", "de": "Vercel / Supabase", "ru": "Vercel / Supabase"},
    
    "Kredi Kartı Ödemesi": {"en": "Credit Card Payment", "de": "Kreditkartenzahlung", "ru": "Оплата кредитной картой"},
    "İhtiyaç Kredisi": {"en": "Personal Loan", "de": "Privatkredit", "ru": "Потребительский кредит"},
    "Araç / Konut Kredisi": {"en": "Auto / Home Loan", "de": "Auto- / Immobilienkredit", "ru": "Авто / Ипотечный кредит"},
    "KMH / Artı Para": {"en": "Overdraft", "de": "Dispokredit", "ru": "Овердрафт"},
    "EFT / Havale Ücreti": {"en": "Transfer Fee", "de": "Überweisungsgebühr", "ru": "Комиссия за перевод"},
    "Banka Aidatı": {"en": "Bank Fee", "de": "Bankgebühr", "ru": "Банковская комиссия"},
    
    "Akaryakıt / LPG": {"en": "Fuel / Gas", "de": "Kraftstoff / Benzin", "ru": "Топливо / Газ"},
    "Periyodik Bakım & Servis": {"en": "Maintenance & Service", "de": "Wartung & Service", "ru": "Техобслуживание и сервис"},
    "Trafik Sigortası & Kasko": {"en": "Car Insurance", "de": "Autoversicherung", "ru": "Страхование авто"},
    "Otopark & HGS": {"en": "Parking & Tolls", "de": "Parken & Maut", "ru": "Парковка и платные дороги"},
    "Oto Yıkama": {"en": "Car Wash", "de": "Autowäsche", "ru": "Автомойка"},
    "Taksi & Toplu Taşıma": {"en": "Taxi & Transit", "de": "Taxi & ÖPNV", "ru": "Такси и транспорт"},
    
    "Kira": {"en": "Rent", "de": "Miete", "ru": "Аренда"},
    "Elektrik": {"en": "Electricity", "de": "Strom", "ru": "Электричество"},
    "Su": {"en": "Water", "de": "Wasser", "ru": "Вода"},
    "Doğalgaz / Isınma": {"en": "Gas / Heating", "de": "Gas / Heizung", "ru": "Газ / Отопление"},
    "İnternet": {"en": "Internet", "de": "Internet", "ru": "Интернет"},
    "Telefon Faturası": {"en": "Phone Bill", "de": "Telefonrechnung", "ru": "Счет за телефон"},
    "Aidat": {"en": "Dues / HOA", "de": "Nebenkosten / Hausgeld", "ru": "Взносы / ТСЖ"},
    
    "Süpermarket": {"en": "Supermarket", "de": "Supermarkt", "ru": "Супермаркет"},
    "Kasap & Manav": {"en": "Butcher & Greengrocer", "de": "Metzger & Gemüsehändler", "ru": "Мясник и овощи"},
    "Damacana Su": {"en": "Bottled Water", "de": "Flaschenwasser", "ru": "Бутилированная вода"},
    "Temizlik Malzemeleri": {"en": "Cleaning Supplies", "de": "Reinigungsmittel", "ru": "Бытовая химия"},
    "Tekel & Atıştırmalık": {"en": "Snacks & Alcohol", "de": "Snacks & Alkohol", "ru": "Снеки и алкоголь"},
    
    "Restoran & Yemek": {"en": "Restaurant & Dining", "de": "Restaurant & Essen", "ru": "Рестораны и питание"},
    "Kahve & Çay": {"en": "Coffee & Tea", "de": "Kaffee & Tee", "ru": "Кофе и чай"},
    "Fast Food": {"en": "Fast Food", "de": "Fast Food", "ru": "Фастфуд"},
    "Dışarıda Eğlence & Bar": {"en": "Nightlife & Bars", "de": "Ausgehen & Bars", "ru": "Развлечения и бары"},
    
    "Uygulama İçi Satın Alma": {"en": "In-App Purchases", "de": "In-App-Käufe", "ru": "Покупки в приложении"},
    "Domain & Hosting (Yıllık)": {"en": "Domain & Hosting (Annual)", "de": "Domain & Hosting (Jährlich)", "ru": "Домен и хостинг (Год)"},
    "Asset & Plugin Alımı": {"en": "Assets & Plugins", "de": "Assets & Plugins", "ru": "Ассеты и плагины"},
    "Elektronik Cihaz": {"en": "Electronics", "de": "Elektronik", "ru": "Электроника"},
    
    "Konsol Oyunu Satın Alma": {"en": "Console Games", "de": "Konsolenspiele", "ru": "Игры для консолей"},
    "Steam / Epic Alışverişi": {"en": "Steam / Epic Purchases", "de": "Steam / Epic Einkäufe", "ru": "Покупки Steam / Epic"},
    "Oyun İçi Satın Alma": {"en": "In-Game Purchases", "de": "In-Game-Käufe", "ru": "Внутриигровые покупки"},
    "Aksesuar (Kol, Kulaklık)": {"en": "Accessories (Controller, Headset)", "de": "Zubehör (Controller, Headset)", "ru": "Аксессуары (Геймпад, Наушники)"},
    
    "Mobilya & Dekorasyon": {"en": "Furniture & Decor", "de": "Möbel & Deko", "ru": "Мебель и декор"},
    "Akıllı Ev Cihazları": {"en": "Smart Home Devices", "de": "Smart-Home-Geräte", "ru": "Умный дом"},
    "Ev Tamirat & Tadilat": {"en": "Home Repairs", "de": "Hausreparaturen", "ru": "Ремонт дома"},
    
    "Eczane & İlaç": {"en": "Pharmacy & Medicine", "de": "Apotheke & Medikamente", "ru": "Аптека и лекарства"},
    "Hastane & Doktor": {"en": "Hospital & Doctor", "de": "Krankenhaus & Arzt", "ru": "Больница и врач"},
    "Kuaför & Berber": {"en": "Hair Salon & Barber", "de": "Friseur & Barbier", "ru": "Парикмахерская и барбер"},
    "Kişisel Bakım & Kozmetik": {"en": "Personal Care & Cosmetics", "de": "Körperpflege & Kosmetik", "ru": "Уход за собой и косметика"},
    
    "Kıyafet": {"en": "Clothing", "de": "Kleidung", "ru": "Одежда"},
    "Ayakkabı": {"en": "Shoes", "de": "Schuhe", "ru": "Обувь"},
    "Çanta & Takı": {"en": "Bags & Jewelry", "de": "Taschen & Schmuck", "ru": "Сумки и украшения"},
    
    "Kurs & Udemy": {"en": "Courses & Udemy", "de": "Kurse & Udemy", "ru": "Курсы и Udemy"},
    "Kitap & Dergi": {"en": "Books & Magazines", "de": "Bücher & Magazine", "ru": "Книги и журналы"},
    "Seminer & Etkinlik": {"en": "Seminars & Events", "de": "Seminare & Events", "ru": "Семинары и мероприятия"},
    
    "Uçak / Otobüs Bileti": {"en": "Flight / Bus Tickets", "de": "Flug- / Bustickets", "ru": "Билеты на самолет / автобус"},
    "Otel / Konaklama": {"en": "Hotel / Accommodation", "de": "Hotel / Unterkunft", "ru": "Отель / Проживание"},
    "Vize & Pasaport": {"en": "Visa & Passport", "de": "Visum & Reisepass", "ru": "Виза и паспорт"},
    "Yolculuk Harcamaları": {"en": "Travel Expenses", "de": "Reisekosten", "ru": "Дорожные расходы"},
    
    "Enstrüman Ekipmanı": {"en": "Instrument Equipment", "de": "Instrument-Zubehör", "ru": "Оборудование для инструментов"},
    "Konser & Etkinlik": {"en": "Concerts & Events", "de": "Konzerte & Events", "ru": "Концерты и мероприятия"},
    "Diğer Hobiler": {"en": "Other Hobbies", "de": "Andere Hobbys", "ru": "Другие хобби"},
    
    "Hediye Alımları": {"en": "Gift Purchases", "de": "Geschenke", "ru": "Подарки"},
    "Bağış & Yardımlaşma": {"en": "Donations & Charity", "de": "Spenden & Wohltätigkeit", "ru": "Пожертвования"},
    
    "Maaş": {"en": "Salary", "de": "Gehalt", "ru": "Зарплата"},
    "Prim / Bonus": {"en": "Bonus / Premium", "de": "Bonus / Prämie", "ru": "Премия / Бонус"},
    "Yol / Yemek Yardımı": {"en": "Transport / Food Allowance", "de": "Fahrt- / Essenszuschuss", "ru": "Компенсация проезда / питания"},
    
    "App Store / IAP Geliri": {"en": "App Store / IAP Revenue", "de": "App Store / IAP Einnahmen", "ru": "Доход от App Store / IAP"},
    "Dış Proje / Web Tasarım": {"en": "Freelance / Web Design", "de": "Freelance / Webdesign", "ru": "Фриланс / Веб-дизайн"},
    "UI/UX Tasarım Satışı": {"en": "UI/UX Design Sales", "de": "UI/UX Design Verkauf", "ru": "Продажи UI/UX дизайна"},
    
    "Cashback / İadeler": {"en": "Cashback / Refunds", "de": "Cashback / Rückerstattungen", "ru": "Кэшбэк / Возвраты"},
    "İkinci El Satış": {"en": "Second Hand Sales", "de": "Verkauf aus zweiter Hand", "ru": "Продажа б/у вещей"},
    "Hediye / Diğer": {"en": "Gifts / Other", "de": "Geschenke / Sonstiges", "ru": "Подарки / Другое"}
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
