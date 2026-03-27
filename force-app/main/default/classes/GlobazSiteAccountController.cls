public without sharing class GlobazSiteAccountController {

    /**
     * Account da pessoa autenticada (via uid na URL).
     */
    public Account account { get; private set; }
    public Boolean isLoggedIn { get; private set; }

    public GlobazSiteAccountController() {
        isLoggedIn = false;

        // Obtém uid da URL
        String accountId = ApexPages.currentPage().getParameters().get('uid');

        // Validação básica do parâmetro
        if (String.isBlank(accountId) || !isSalesforceId(accountId)) {
            // Sem uid válido -> não autenticado
            return;
        }

        try {
            // Carrega sempre a Account do uid recebido
            List<Account> accs = [
                SELECT Id, FirstName, LastName, PersonEmail, Phone, CreatedDate, IsPersonAccount
                FROM Account
                WHERE Id = :accountId
                LIMIT 1
            ];

            if (!accs.isEmpty()) {
                account = accs[0];
                // Considera autenticado se a conta existe
                isLoggedIn = true;
            }
        } catch (Exception e) {
            isLoggedIn = false;
        }
    }

    public Boolean getIsLoggedIn() {
        return isLoggedIn;
    }

    // Helper simples para validar formato de Id Salesforce (15/18 chars alfanumérico)
    private static Boolean isSalesforceId(String idStr) {
        if (String.isBlank(idStr)) return false;
        Integer len = idStr.length();
        if (len != 15 && len != 18) return false;
        // Verificação básica: alfanumérico
        for (Integer i = 0; i < len; i++) {
            String c = idStr.substring(i, i+1);
            if (!((c >= 'A' && c <= 'Z') || (c >= 'a' && c <= 'z') || (c >= '0' && c <= '9'))) {
                return false;
            }
        }
        return true;
    }
}
