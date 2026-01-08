import os
import re


SRC_DIR = "src"
LIB_DIR = os.path.join(SRC_DIR, "lib")
MAIN_FILE = os.path.join(SRC_DIR, "Main.lua")
OUTPUT_FILE = "SigmaSpy_Compiled.lua"


REGUI_FIX = 'loadstring(game:HttpGet("https://raw.githubusercontent.com/Jsssiee/Dear-ReGui/main/ReGui.lua"), "ReGui")()'

def read_file(path):
    with open(path, "r", encoding="utf-8") as f:
        return f.read()

def get_lib_content(lib_name):

    filename = lib_name.replace("@lib/", "")
    path = os.path.join(LIB_DIR, filename)
    
    if not os.path.exists(path):

        path = path.replace("%20", " ")
        
    if os.path.exists(path):
        content = read_file(path)
        

        if "Ui.lua" in filename:
            print(f"   [FIX] Patching ReGui link in {filename}...")

            content = re.sub(
                r'local ReGui = loadstring\(game:HttpGet\([\'"].*?ReGui\.lua[\'"]\), [\'"]ReGui[\'"]\)\(\)', 
                f'local ReGui = {REGUI_FIX}', 
                content
            )
        # ------------------------
        
        return content
    else:
        print(f"Error: File not found: {path}")
        return "-- File not found --"

def compile_project():
    print("--- Sigma Spy Compiler ---")
    
    if not os.path.exists(MAIN_FILE):
        print(f"Critical Error: {MAIN_FILE} not found!")
        return

    main_source = read_file(MAIN_FILE)

    # 1. Обработка --INSERT: @lib/File.lua
    # Это просто вставка кода напрямую
    def replacer_insert(match):
        path = match.group(1).strip()
        print(f"-> Inserting: {path}")
        return get_lib_content(path)

    main_source = re.sub(r'--INSERT:\s*(@lib/[^\s]+)', replacer_insert, main_source)

    def replacer_compile(match):
        path = match.group(1).strip()
        print(f"-> Compiling module: {path}")
        code = get_lib_content(path)

        return f"(function()\n{code}\nend)()"


    main_source = re.sub(r'[\'"]COMPILE:\s*(@lib/[^\'"]+)[\'"]', replacer_compile, main_source)


    with open(OUTPUT_FILE, "w", encoding="utf-8") as f:
        f.write("-- Compiled with Python Builder\n")
        f.write(main_source)

    print(f"\nDone! Script saved to: {OUTPUT_FILE}")

if __name__ == "__main__":
    compile_project()
