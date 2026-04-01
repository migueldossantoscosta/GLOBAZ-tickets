import os
import re

def clean_file(file_path):
    with open(file_path, 'r', encoding='utf-8') as f:
        content = f.read()

    # Remover QuickActions com RypplePost
    content = re.sub(r'\s*<quickActionListItems>\s*<quickActionName>FeedItem\.RypplePost</quickActionName>\s*</quickActionListItems>', '', content)
    # Remover PlatformActions com RypplePost
    content = re.sub(r'\s*<platformActionListItems>\s*<actionName>FeedItem\.RypplePost</actionName>.*?</platformActionListItems>', '', content, flags=re.DOTALL)
    # Limpar emails de site
    content = re.sub(r'<siteAdmin>.*?</siteAdmin>', '<siteAdmin></siteAdmin>', content)
    content = re.sub(r'<siteGuestRecordDefaultOwner>.*?</siteGuestRecordDefaultOwner>', '<siteGuestRecordDefaultOwner></siteGuestRecordDefaultOwner>', content)

    with open(file_path, 'w', encoding='utf-8') as f:
        f.write(content)

# Correr em todos os layouts e no site
root_dir = r"c:\Users\migue\Desktop\Nova pasta\GLOBAZ tickets\force-app\main\default"
for folder in ["layouts", "sites"]:
    folder_path = os.path.join(root_dir, folder)
    if os.path.exists(folder_path):
        for file in os.listdir(folder_path):
            if file.endswith(".xml"):
                clean_file(os.path.join(folder_path, file))

print("Limpeza concluída com sucesso!")
