public without sharing class GlobazSiteAccountController {

    public Account account { get; private set; }
    public Boolean isLoggedIn { get; private set; }
    public List<Bilhete__c> bilhetesComprados { get; private set; }

    public GlobazSiteAccountController() {
        isLoggedIn = false;
        bilhetesComprados = new List<Bilhete__c>();

        String accountId = ApexPages.currentPage().getParameters().get('uid');

        if (String.isBlank(accountId) || !isSalesforceId(accountId)) {
            return;
        }

        try {
            List<Account> accs = [
                SELECT Id, FirstName, LastName, PersonEmail, Phone, CreatedDate, IsPersonAccount,
                       DataNascimento__c, CategoriaFavorita__c, Marketing__c, RGPD__c,
                       IBAN__c, Valido__c, Password__c, Idade__c, ValorTotalGasto__c,
                       DataUltimaCompra__c, NIF__c
                FROM Account
                WHERE Id = :accountId
                LIMIT 1
            ];

            if (!accs.isEmpty()) {
                account = accs[0];
                isLoggedIn = true;

                bilhetesComprados = [
                    SELECT Id, Name, Evento__r.Name, Fila__c, NumeroLugar__c, EstadoBilhete__c, CreatedDate
                    FROM Bilhete__c
                    WHERE Account__c = :accountId
                    ORDER BY CreatedDate DESC
                ];
            }
        } catch (Exception e) {
            isLoggedIn = false;
        }
    }

    public Boolean getIsLoggedIn() {
        return isLoggedIn;
    }

    @RemoteAction
    public static String guardarConta(Map<String, String> dados) {
        try {
            Id accountId = (Id)dados.get('Id');
            Account acc = new Account(Id = accountId);

            if(dados.containsKey('FirstName')) acc.FirstName = dados.get('FirstName');
            if(dados.containsKey('LastName')) acc.LastName = dados.get('LastName');
            if(dados.containsKey('PersonEmail')) acc.PersonEmail = dados.get('PersonEmail');
            if(dados.containsKey('Phone')) acc.Phone = dados.get('Phone');
            if(dados.containsKey('IBAN__c')) acc.IBAN__c = dados.get('IBAN__c');
            if(dados.containsKey('NIF__c')) acc.NIF__c = dados.get('NIF__c');
            if(dados.containsKey('Password__c')) acc.Password__c = dados.get('Password__c');
            if(dados.containsKey('CategoriaFavorita__c')) acc.CategoriaFavorita__c = dados.get('CategoriaFavorita__c');

            if(dados.containsKey('DataNascimento__c') && String.isNotBlank(dados.get('DataNascimento__c'))) {
                acc.DataNascimento__c = Date.valueOf(dados.get('DataNascimento__c'));
            } else if (dados.containsKey('DataNascimento__c')) {
                acc.DataNascimento__c = null;
            }

            if(dados.containsKey('Marketing__c')) acc.Marketing__c = Boolean.valueOf(dados.get('Marketing__c'));
            if(dados.containsKey('RGPD__c')) {
                if(dados.get('RGPD__c') == 'true') {
                    acc.RGPD__c = Datetime.now();
                } else {
                    acc.RGPD__c = null;
                }
            }
            // Idade, Gasto e UltimaCompra likely formulas / uneditable manually by normal form process

            update acc;
            return 'SUCESSO';
        } catch(Exception e) {
            return 'ERRO: ' + e.getMessage();
        }
    }

    private static Boolean isSalesforceId(String idStr) {
        if (String.isBlank(idStr)) return false;
        Integer len = idStr.length();
        if (len != 15 && len != 18) return false;
        for (Integer i = 0; i < len; i++) {
            String c = idStr.substring(i, i+1);
            if (!((c >= 'A' && c <= 'Z') || (c >= 'a' && c <= 'z') || (c >= '0' && c <= '9'))) {
                return false;
            }
        }
        return true;
    }
}
