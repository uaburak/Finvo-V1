import os

category_filepath = "./Finvo/Finvo/Core/Summary/Views/QuickActions/Categories/Models/CategoryModel.swift"

replacements = {
    # Housing
    '"Doğalgaz / Isınma"': '"Natural Gas / Heating"',
    '"Telefon Faturası"': '"Phone Bill"',
    
    # Groceries
    '"Kasap & Manav"': '"Butcher & Greengrocer"',
    '"Damacana Su"': '"Bottled Water"',
    '"Temizlik Malzemeleri"': '"Cleaning Supplies"',
    '"Tekel & Atıştırmalık"': '"Snacks & Alcohol"',
    
    # Dining
    '"Yeme İçme & Sosyal"': '"Dining & Social"',
    '"Restoran & Yemek"': '"Restaurant & Food"',
    '"Dışarıda Eğlence & Bar"': '"Nightlife & Bar"',
    
    # Tech
    '"Teknoloji & Yazılım"': '"Technology & Software"',
    '"Uygulama İçi Satın Alma"': '"In-App Purchase"',
    '"Domain & Hosting (Yıllık)"': '"Domain & Hosting (Yearly)"',
    '"Asset & Plugin Alımı"': '"Asset & Plugin"',
    '"Elektronik Cihaz"': '"Electronic Devices"',
    
    # Gaming
    '"Oyun & Donanım"': '"Gaming & Hardware"',
    '"Konsol Oyunu Satın Alma"': '"Console Game Purchase"',
    '"Steam / Epic Alışverişi"': '"Steam / Epic Purchase"',
    '"Oyun İçi Satın Alma"': '"In-Game Purchase"',
    '"Aksesuar (Kol, Kulaklık)"': '"Accessories (Controller, etc.)"',
    
    # Home
    '"Mobilya & Dekorasyon"': '"Furniture & Decoration"',
    '"Akıllı Ev Cihazları"': '"Smart Home Devices"',
    '"Ev Tamirat & Tadilat"': '"Home Repairs"',
    
    # Care
    '"Eczane & İlaç"': '"Pharmacy & Medicine"',
    '"Kişisel Bakım & Kozmetik"': '"Personal Care & Cosmetics"',
    
    # Clothes
    '"Çanta & Takı"': '"Bags & Jewelry"',
    
    # Education
    '"Eğitim & Gelişim"': '"Education & Development"',
    '"Kurs & Udemy"': '"Courses & Udemy"',
    '"Kitap & Dergi"': '"Books & Magazines"',
    '"Seminer & Etkinlik"': '"Seminars & Events"',
    
    # Travel
    '"Seyahat & Tatil"': '"Travel & Vacation"',
    '"Uçak / Otobüs Bileti"': '"Flight / Bus Ticket"',
    '"Otel / Konaklama"': '"Hotel / Accommodation"',
    '"Vize & Pasaport"': '"Visa & Passport"',
    '"Yolculuk Harcamaları"': '"Travel Expenses"',
    
    # Hobbies
    '"Hobi & Müzik"': '"Hobbies & Music"',
    '"Enstrüman Ekipmanı"': '"Instrument Equipment"',
    '"Konser & Etkinlik"': '"Concerts & Events"',
    '"Diğer Hobiler"': '"Other Hobbies"',
    
    # Gifts
    '"Hediye & Bağış"': '"Gifts & Donations"',
    '"Hediye Alımları"': '"Gift Purchases"',
    '"Bağış & Yardımlaşma"': '"Charity & Donations"',
    
    # Income
    '"Maaş & Ana Gelir"': '"Salary & Main Income"',
    '"Prim / Bonus"': '"Premium / Bonus"',
    '"Yol / Yemek Yardımı"': '"Transport / Meal Allowance"',
    
    '"Freelance & Projeler"': '"Freelance & Projects"',
    '"Dış Proje / Web Tasarım"': '"External Project / Web Design"',
    '"UI/UX Tasarım Satışı"': '"UI/UX Design Sales"',
    
    '"Pasif & Diğer"': '"Passive & Other"',
    '"Cashback / İadeler"': '"Cashback / Refunds"',
    '"İkinci El Satış"': '"Second Hand Sales"',
    '"Hediye / Diğer"': '"Gift / Other"'
}

with open(category_filepath, "r", encoding="utf-8") as f:
    content = f.read()

for tr, en in replacements.items():
    content = content.replace(tr, en)

with open(category_filepath, "w", encoding="utf-8") as f:
    f.write(content)

print("Patching CategoryModel categories complete.")
