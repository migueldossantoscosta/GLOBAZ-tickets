public without sharing class GlobazSiteRegisterController {

    public class RegisterException extends Exception {}

    public String firstName { get; set; }
    public String lastName { get; set; }
    public String email { get; set; }
    public String phone { get; set; }
    public String birthdateText { get; set; }
    public String username { get; set; }
    public String password { get; set; }
    public String confirmPassword { get; set; }

    public Boolean marketingOptIn { get; set; }
    public Boolean rgpdAccepted { get; set; }

    public PageReference registerUser() {
        Savepoint sp = Database.setSavepoint();

        try {
            validateInput();

            Id personAccountRtId = getPersonAccountRecordTypeId();

            Account pa = new Account();
            pa.RecordTypeId = personAccountRtId;
            pa.OwnerId = getDefaultOwnerId();
            pa.FirstName = firstName;
            pa.LastName = lastName;
            pa.PersonEmail = email;
            pa.Phone = phone;
            pa.Marketing__c = marketingOptIn;

            if (rgpdAccepted) {
                pa.RGPD__c = System.now();
            }

            if (!String.isBlank(birthdateText)) {
                pa.DataNascimento__c = parseDatePT(birthdateText);
            }

            insert pa;

            pa = [
                SELECT Id, PersonContactId, OwnerId
                FROM Account
                WHERE Id = :pa.Id
                LIMIT 1
            ];

            User u = new User();
            u.Username = username;
            u.Email = email;
            u.FirstName = firstName;
            u.LastName = lastName;
            u.CommunityNickname = buildCommunityNickname();
            u.Alias = buildAlias(firstName, lastName);
            u.TimeZoneSidKey = 'Europe/Lisbon';
            u.LocaleSidKey = 'pt_PT';
            u.EmailEncodingKey = 'UTF-8';
            u.LanguageLocaleKey = 'pt_PT';
            u.ProfileId = getExternalProfileId();
            u.ContactId = pa.PersonContactId;

            String newUserId = Site.createPortalUser(u, pa.Id, password);

            if (String.isBlank(newUserId)) {
                Database.rollback(sp);

                ApexPages.addMessage(new ApexPages.Message(
                    ApexPages.Severity.ERROR,
                    'Não foi possível criar o utilizador externo. Verifica o profile externo, o owner da conta e as permissões do site.'
                ));
                return null;
            }

            PageReference loginPage = new PageReference('/apex/SiteLogin');
            loginPage.setRedirect(true);
            return loginPage;

        } catch (Exception e) {
            Database.rollback(sp);

            ApexPages.addMessage(new ApexPages.Message(
                ApexPages.Severity.ERROR,
                'Erro: ' + e.getMessage()
            ));
            System.debug('ERRO REGISTO GLOBAZ: ' + e.getMessage());
            System.debug(e.getStackTraceString());
            return null;
        }
    }

    private void validateInput() {
        if (String.isBlank(firstName)) {
            throw new RegisterException('Indica o primeiro nome.');
        }

        if (String.isBlank(lastName)) {
            throw new RegisterException('Indica o último nome.');
        }

        if (String.isBlank(email)) {
            throw new RegisterException('Indica o email.');
        }

        if (String.isBlank(username)) {
            throw new RegisterException('Indica o username.');
        }

        if (String.isBlank(password) || String.isBlank(confirmPassword)) {
            throw new RegisterException('Indica e confirma a password.');
        }

        if (password != confirmPassword) {
            throw new RegisterException('As passwords não coincidem.');
        }

        if (!rgpdAccepted) {
            throw new RegisterException('Tens de aceitar a política de privacidade.');
        }

        if (!String.isBlank(birthdateText)) {
            parseDatePT(birthdateText);
        }

        Integer existingAccounts = [
            SELECT COUNT()
            FROM Account
            WHERE IsPersonAccount = true
              AND PersonEmail = :email
        ];

        if (existingAccounts > 0) {
            throw new RegisterException('Já existe uma Person Account com este email.');
        }

        Integer existingUsers = [
            SELECT COUNT()
            FROM User
            WHERE Username = :username
        ];

        if (existingUsers > 0) {
            throw new RegisterException('Esse username já está em uso.');
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
            throw new RegisterException('Não foi encontrado um Record Type de Person Account disponível.');
        }

        return personRT[0].Id;
    }

    private static Id getExternalProfileId() {
        Profile p = [
            SELECT Id
            FROM Profile
            WHERE Name = 'Customer Community User'
            LIMIT 1
        ];
        return p.Id;
    }

    private static Id getDefaultOwnerId() {
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

    private Date parseDatePT(String inputDate) {
        try {
            String cleanDate = inputDate != null ? inputDate.trim() : '';

            if (String.isBlank(cleanDate)) {
                return null;
            }

            if (cleanDate.contains('/')) {
                List<String> parts = cleanDate.split('/');

                if (parts.size() != 3) {
                    throw new RegisterException('Data de nascimento inválida. Usa DD/MM/AAAA.');
                }

                Integer dia = Integer.valueOf(parts[0]);
                Integer mes = Integer.valueOf(parts[1]);
                Integer ano = Integer.valueOf(parts[2]);

                return Date.newInstance(ano, mes, dia);
            }

            if (cleanDate.contains('-')) {
                return Date.valueOf(cleanDate);
            }

            throw new RegisterException('Data de nascimento inválida. Usa DD/MM/AAAA.');
        } catch (Exception e) {
            throw new RegisterException('Data de nascimento inválida. Usa DD/MM/AAAA.');
        }
    }

    private String buildCommunityNickname() {
        String nick = '';

        if (!String.isBlank(firstName)) {
            nick += firstName.toLowerCase();
        }

        if (!String.isBlank(lastName)) {
            nick += '.' + lastName.toLowerCase();
        }

        nick += '.' + String.valueOf(DateTime.now().getTime()).right(5);
        return nick.replaceAll('[^a-zA-Z0-9\\._-]', '');
    }

    private static String buildAlias(String fName, String lName) {
        String aliasValue = '';

        if (!String.isBlank(fName)) {
            aliasValue += fName.substring(0, 1);
        }

        if (!String.isBlank(lName)) {
            aliasValue += lName.substring(0, Math.min(7, lName.length()));
        }

        aliasValue = aliasValue.replaceAll('[^a-zA-Z0-9]', '');

        if (String.isBlank(aliasValue)) {
            aliasValue = 'globaz';
        }

        return aliasValue.substring(0, Math.min(8, aliasValue.length()));
    }
}