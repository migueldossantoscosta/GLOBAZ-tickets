public without sharing class GlobazSiteRegisterController {

    public String firstName { get; set; }
    public String lastName { get; set; }
    public String email { get; set; }
    public String phone { get; set; }
    public String birthdateText { get; set; }
    public String username { get; set; }
    public String communityNickname { get; set; }
    public String password { get; set; }
    public String confirmPassword { get; set; }
    public Boolean marketingOptIn { get; set; }
    public Boolean rgpdAccepted { get; set; }

    private static final String EXTERNAL_PROFILE_ID = 'YOUR_EXTERNAL_PROFILE_ID';

    public PageReference registerUser() {
        try {
            validateInput();

            Id personAccountRtId = getPersonAccountRecordTypeId();
            Id ownerId = getDefaultOwnerId();

            Account pa = new Account();
            pa.RecordTypeId = personAccountRtId;
            pa.FirstName = firstName;
            pa.LastName = lastName;
            pa.PersonEmail = email;
            pa.Phone = phone;

            // Campos custom teus — ajusta se os API names forem diferentes
            pa.Marketing__c = marketingOptIn;
            pa.RGPD__c = System.now();

            if (!String.isBlank(birthdateText)) {
                pa.DataNascimento__c = Date.valueOf(birthdateText);
            }

            insert pa;

            pa = [
                SELECT Id, PersonContactId, PersonEmail, FirstName, LastName
                FROM Account
                WHERE Id = :pa.Id
                LIMIT 1
            ];

            User u = new User();
            u.Username = username;
            u.Email = email;
            u.FirstName = firstName;
            u.LastName = lastName;
            u.CommunityNickname = communityNickname;
            u.Alias = buildAlias(firstName, lastName);
            u.TimeZoneSidKey = 'Europe/Lisbon';
            u.LocaleSidKey = 'pt_PT';
            u.EmailEncodingKey = 'UTF-8';
            u.LanguageLocaleKey = 'pt_PT';
            u.ProfileId = EXTERNAL_PROFILE_ID;
            u.ContactId = pa.PersonContactId;

            String newUserId = Site.createPortalUser(u, pa.Id, password);

            if (String.isBlank(newUserId)) {
                delete pa;
                ApexPages.addMessage(new ApexPages.Message(
                    ApexPages.Severity.ERROR,
                    'Não foi possível criar o utilizador externo.'
                ));
                return null;
            }

            PageReference loginPage = new PageReference('/apex/SiteLogin');
            loginPage.setRedirect(true);
            return loginPage;

        } catch (Exception e) {
            ApexPages.addMessage(new ApexPages.Message(
                ApexPages.Severity.ERROR,
                e.getMessage()
            ));
            return null;
        }
    }

    private void validateInput() {
        if (String.isBlank(firstName)) {
            throw new AuraHandledException('Indica o primeiro nome.');
        }
        if (String.isBlank(lastName)) {
            throw new AuraHandledException('Indica o último nome.');
        }
        if (String.isBlank(email)) {
            throw new AuraHandledException('Indica o email.');
        }
        if (String.isBlank(username)) {
            throw new AuraHandledException('Indica o username.');
        }
        if (String.isBlank(communityNickname)) {
            throw new AuraHandledException('Indica o community nickname.');
        }
        if (String.isBlank(password) || String.isBlank(confirmPassword)) {
            throw new AuraHandledException('Indica e confirma a password.');
        }
        if (password != confirmPassword) {
            throw new AuraHandledException('As passwords não coincidem.');
        }
        if (!rgpdAccepted) {
            throw new AuraHandledException('Tens de aceitar a política de privacidade.');
        }

        Integer existingAccounts = [
            SELECT COUNT()
            FROM Account
            WHERE IsPersonAccount = true
              AND PersonEmail = :email
        ];
        if (existingAccounts > 0) {
            throw new AuraHandledException('Já existe uma conta com este email.');
        }

        Integer existingUsers = [
            SELECT COUNT()
            FROM User
            WHERE Username = :username
        ];
        if (existingUsers > 0) {
            throw new AuraHandledException('Esse username já está em uso.');
        }

        if (!String.isBlank(birthdateText)) {
            try {
                Date.valueOf(birthdateText);
            } catch (Exception ex) {
                throw new AuraHandledException('A data de nascimento deve estar no formato AAAA-MM-DD.');
            }
        }
    }

    private static Id getPersonAccountRecordTypeId() {
    List<RecordType> personRT = [
        SELECT Id
        FROM RecordType
        WHERE SObjectType = 'Account'
          AND IsPersonType = true
        LIMIT 1
    ];

    if (personRT.isEmpty()) {
        throw new AuraHandledException('Não foi encontrado um Record Type de Person Account disponível.');
    }

    return personRT[0].Id;
    }

    private static Id getDefaultOwnerId() {
        // Idealmente substitui isto por um Custom Setting/Metadata
        // e usa um user interno com role.
        User u = [
            SELECT Id
            FROM User
            WHERE IsActive = true
              AND UserRoleId != null
            ORDER BY CreatedDate ASC
            LIMIT 1
        ];
        return u.Id;
    }

    private static String buildAlias(String fName, String lName) {
        String baseAlias = '';
        if (!String.isBlank(fName)) {
            baseAlias += fName.substring(0, Math.min(1, fName.length()));
        }
        if (!String.isBlank(lName)) {
            baseAlias += lName.substring(0, Math.min(7, lName.length()));
        }
        baseAlias = baseAlias.replaceAll('[^a-zA-Z0-9]', '');
        if (String.isBlank(baseAlias)) {
            baseAlias = 'globaz';
        }
        return baseAlias.substring(0, Math.min(8, baseAlias.length()));
    }
}