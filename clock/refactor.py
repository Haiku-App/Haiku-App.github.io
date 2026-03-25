import re
import os

filepath = '/Users/reswin/Desktop/clock/clock/ContentView.swift'
with open(filepath, 'r') as f:
    content = f.read()

def extract_struct(name, src_content):
    pattern = r"struct\s+" + name + r"(<[^>]*>)?\s*:\s*[^{]*\{"
    match = re.search(pattern, src_content)
    if not match:
        print(f"Could not find struct {name}")
        return ""
    start_idx = match.start()
    
    brace_count = 0
    in_string = False
    escape_next = False
    
    # match.end() - 1 is the '{'
    for i in range(match.end() - 1, len(src_content)):
        char = src_content[i]
        
        if escape_next:
            escape_next = False
            continue
            
        if char == '\\':
            escape_next = True
            continue
            
        if char == '"':
            in_string = not in_string
            continue
            
        if not in_string:
            if char == '{':
                brace_count += 1
            elif char == '}':
                brace_count -= 1
                if brace_count == 0:
                    return src_content[start_idx:i+1]
    
    return ""

files_to_create = {
    "AddTaskView.swift": ["AddTaskView", "TaskRow"],
    "NewCategoryView.swift": ["NewCategoryView"],
    "ProfileAnalyticsView.swift": ["ProfileAnalyticsView", "StatCard", "DonutChart", "WeeklyTrendChart", "PeakFocusChart", "MomentumChart"],
    "ProfileSettingsView.swift": ["ProfileSettingsView"],
    "TodoView.swift": ["TodoView", "BrainDumpRow"],
    "HaikuProView.swift": ["HaikuProView", "ProFeatureRow", "PricingButton"]
}

new_content = content
for filename, structs in files_to_create.items():
    file_content = "import SwiftUI\nimport StoreKit\n\n"
    for struct in structs:
        struct_code = extract_struct(struct, content)
        if struct_code:
            file_content += struct_code + "\n\n"
            new_content = new_content.replace(struct_code, "")
        else:
            print(f"Warning: {struct} not found!")
    
    out_path = os.path.join('/Users/reswin/Desktop/clock/clock', filename)
    with open(out_path, 'w') as f:
        f.write(file_content)
    print(f"Written {out_path}")

# remove completely empty lines preserving basic spacing
new_content = re.sub(r'\n\s*\n', '\n\n', new_content)

with open(filepath, 'w') as f:
    f.write(new_content)
print("Updated ContentView.swift")
