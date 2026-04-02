import os
import shutil
import re

root = r"c:\Users\migue\Desktop\Nova pasta\GLOBAZ tickets\force-app\main\default"

# 1. Pastas a eliminar completamente (Incompatíveis)
folders_to_delete = [
    "profiles",
    "translations",
    "managedContentTypes",
    "sharingRules",
    "reports",
    "dashboards"
]

# 2. Objetos de sistema que dão sempre erro
objects_to_delete = [
    "BatchJob", "BatchJobPart", "BatchJobPartFailedRecord", 
    "WorkBadge", "WorkBadgeDefinition", "WorkThanks", "WorkAccess",
    "DandBCompany", "DevopsEnvironment", "DevopsRequestInfo",
    "InvoiceLine", "PrivacyJobSession", "PrivacyRTBFRequest",
    "SocialPersona", "AgentforceSdrConfig", "Accounting",
    "CommSubscriptionChannelType", "NamespaceRegistry", "PaymentGroup",
    "ScratchOrgInfo", "ChangeRequest", "Problem"
]

def power_clean():
    # Eliminar pastas
    for folder in folders_to_delete:
        path = os.path.join(root, folder)
        if os.path.exists(path):
            shutil.rmtree(path)
            print(f"Eliminado: {folder}")

    # Eliminar objetos específicos
    obj_root = os.path.join(root, "objects")
    if os.path.exists(obj_root):
        for obj in objects_to_delete:
            path = os.path.join(obj_root, obj)
            if os.path.exists(path):
                shutil.rmtree(path)
                print(f"Eliminado Objeto: {obj}")

    # Limpeza de Layouts (RypplePost e campos de sistema)
    layout_root = os.path.join(root, "layouts")
    if os.path.exists(layout_root):
        for file in os.listdir(layout_root):
            if file.endswith(".xml"):
                path = os.path.join(layout_root, file)
                with open(path, 'r', encoding='utf-8') as f:
                    content = f.read()
                
                # Remove RypplePost e referências a objetos apagados
                content = re.sub(r'\s*<quickActionListItems>\s*<quickActionName>FeedItem\.RypplePost</quickActionName>\s*</quickActionListItems>', '', content)
                content = re.sub(r'\s*<platformActionListItems>\s*<actionName>FeedItem\.RypplePost</actionName>.*?</platformActionListItems>', '', content, flags=re.DOTALL)
                
                with open(path, 'w', encoding='utf-8') as f:
                    f.write(content)
        print("Layouts limpos!")

    # Limpeza do Site
    site_path = os.path.join(root, "sites", "Bilheteira_GLOBAZ.site-meta.xml")
    if os.path.exists(site_path):
        with open(site_path, 'r', encoding='utf-8') as f:
            content = f.read()
        content = re.sub(r'<siteAdmin>.*?</siteAdmin>', '<siteAdmin></siteAdmin>', content)
        content = re.sub(r'<siteGuestRecordDefaultOwner>.*?</siteGuestRecordDefaultOwner>', '<siteGuestRecordDefaultOwner></siteGuestRecordDefaultOwner>', content)
        with open(site_path, 'w', encoding='utf-8') as f:
            f.write(content)
        print("Site limpo!")

if __name__ == "__main__":
    power_clean()
