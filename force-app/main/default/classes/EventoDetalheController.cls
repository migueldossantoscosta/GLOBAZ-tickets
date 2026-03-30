public without sharing class EventoDetalheController {

    public Evento__c evento       { get; set; }
    public Id        eventId      { get; set; }

    // Dados do utilizador logado (via cookie globaz_uid)
    public Id      currentAccountId   { get; set; }
    public String  currentAccountName { get; set; }
    public Boolean isLoggedIn         { get; set; }

    public Decimal precoDesde { get; set; }

    public EventoDetalheController() {
        eventId = ApexPages.currentPage().getParameters().get('id');
        precoDesde = 25.00; // Default fallback

        // Ler o cookie de sessão
        String uid = ApexPages.currentPage().getCookies().get('globaz_uid') != null
            ? ApexPages.currentPage().getCookies().get('globaz_uid').getValue()
            : null;

        isLoggedIn = false;
        if (String.isNotBlank(uid)) {
            try {
                List<Account> accs = [
                    SELECT Id, FirstName, LastName
                    FROM   Account
                    WHERE  Id = :uid
                    AND    IsPersonAccount = true
                    LIMIT  1
                ];
                if (!accs.isEmpty()) {
                    currentAccountId   = accs[0].Id;
                    currentAccountName = (accs[0].FirstName + ' ' + accs[0].LastName).trim();
                    isLoggedIn         = true;
                }
            } catch (Exception e) {
                // ID inválido — ignorar
            }
        }

        if (eventId != null) {
            loadEvento();
        }
    }

    private void loadEvento() {
        List<Evento__c> resultados = [
            SELECT Id,
                   Name,
                   DataEvento__c,
                   LocalizacaoEvento__c,
                   URLImagem__c,
                   CategoriaPrincipal__c,
                   Destaque__c,
                   Pricebook__c
            FROM Evento__c
            WHERE Id = :eventId
            LIMIT 1
        ];

        if (!resultados.isEmpty()) {
            evento = resultados[0];
            
            // Buscar preço dinâmico do BilheteiraController (que já tem IVA 23%)
            precoDesde = BilheteiraController.getPrecoBilhete(evento.Id);
        }
    }

    public Boolean getHasEvento() {
        return evento != null;
    }
}