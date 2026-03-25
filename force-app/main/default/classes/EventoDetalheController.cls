public without sharing class EventoDetalheController {

    public Evento__c evento { get; set; }
    public Id eventId { get; set; }

    public EventoDetalheController() {
        eventId = ApexPages.currentPage().getParameters().get('id');

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
                   Destaque__c
            FROM Evento__c
            WHERE Id = :eventId
            LIMIT 1
        ];

        if (!resultados.isEmpty()) {
            evento = resultados[0];
        }
    }

    public Boolean getHasEvento() {
        return evento != null;
    }
}