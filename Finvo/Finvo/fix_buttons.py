import re
import glob
import os

files = glob.glob('/Users/burak/Desktop/Burak/Finvo V1/Kod/Finvo V1/Finvo/Finvo/**/*.swift', recursive=True)

for file in files:
    with open(file, 'r') as f:
        content = f.read()
    
    # We want to replace foregroundStyle(.white) or foregroundColor(.white) with .black
    # ONLY if it's near .glassProminent or .background(theme.brandPrimary)
    
    # Actually, if we just look for 'glassProminent' and if it is there, we find the Text( ... .foregroundStyle(.white) block
    if "glassProminent" in content or "background(theme.brandPrimary)" in content:
        # Just replace all .foregroundStyle(.white) inside Button label block.
        # But wait! A view might have white text elsewhere!
        
        # Safe regex: find `.foregroundStyle(.white)` that is followed by `.frame(maxWidth: .infinity`
        # Because in all these sheets, the button text has `.frame(maxWidth: .infinity`
        # Let's test this
        new_content = re.sub(r'\.foregroundStyle\(\.white\)(\s*)\.frame\(maxWidth: \.infinity', r'.foregroundStyle(.black)\1.frame(maxWidth: .infinity', content)
        new_content = re.sub(r'\.foregroundColor\(\.white\)(\s*)\.frame\(maxWidth: \.infinity', r'.foregroundColor(.black)\1.frame(maxWidth: .infinity', new_content)
        
        # Also let's check for specific files like LoginView where the button might be slightly different.
        if new_content != content:
            with open(file, 'w') as f:
                f.write(new_content)
            print(f"Fixed: {file}")

