public without sharing class EventoDetalheController {

    public Id        eventId              { get; set; }
    public Decimal   precoDesde           { get; set; }
    public Boolean   isLoggedIn           { get; set; }
    public String    currentAccountId     { get; set; }
    public String    currentAccountName   { get; set; }
    public Evento__c evento               { get; set; }
    public String    formattedDate        { get; set; }
    public String    urlImagem            { get; set; }
    public String    descricao            { get; set; }

    public EventoDetalheController() {
        String paramId = ApexPages.currentPage().getParameters().get('id');
        if (paramId != null && (paramId.length() == 15 || paramId.length() == 18)) {
            eventId = (Id)paramId;
        }
        precoDesde = 25.00;

        String uid = ApexPages.currentPage().getCookies().get('globaz_uid') != null
            ? ApexPages.currentPage().getCookies().get('globaz_uid').getValue()
            : null;

        isLoggedIn = false;
        if (String.isNotBlank(uid)) {
            try {
                List<Account> accs = [
                    SELECT Id, FirstName, LastName FROM Account WHERE Id = :uid AND IsPersonAccount = true LIMIT 1
                ];
                if (!accs.isEmpty()) {
                    currentAccountId   = accs[0].Id;
                    currentAccountName = (accs[0].FirstName + ' ' + accs[0].LastName).trim();
                    isLoggedIn         = true;
                }
            } catch (Exception e) {}
        }

        if (eventId != null) {
            loadEvento();
        }
    }

    private void loadEvento() {
        List<Evento__c> resultados = [
            SELECT Id, Name, DataEvento__c, LocalizacaoEvento__c, URLImagem__c,
                   CategoriaPrincipal__c, Destaque__c, Pricebook__c, DescricaoDetalhada__c
            FROM Evento__c
            WHERE Id = :eventId
            LIMIT 1
        ];

        if (!resultados.isEmpty()) {
            evento = resultados[0];
            // Mapeamento de URL ABSOLUTO para Site (Bypass de CORS definitivo)
            String rawUrl = evento.URLImagem__c;
            if (String.isNotBlank(rawUrl) && rawUrl.contains('/resource/')) {
                String resTail = rawUrl.substringAfter('/resource/');
                if (resTail.contains('?')) resTail = resTail.substringBefore('?');
                
                String prefix = Site.getPathPrefix();
                if (prefix == null) prefix = '';
                
                // Padrão estável de Site/Community (/sfsites/c/resource/...)
                urlImagem = prefix + '/sfsites/c/resource/' + resTail;
            } else {
                urlImagem = rawUrl;
            }
            
            descricao = evento.DescricaoDetalhada__c;
            precoDesde = BilheteiraController.getPrecoBilhete(evento.Id);
            if (evento.DataEvento__c != null) {
                formattedDate = evento.DataEvento__c.format('dd MMM yyyy HH:mm');
            } else {
                formattedDate = 'Data a anunciar';
            }
        }
    }

    public Boolean getHasEvento() {
        return evento != null;
    }
}