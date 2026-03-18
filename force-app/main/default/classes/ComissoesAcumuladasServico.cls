public with sharing class ComissoesAcumuladasServico {

    public static void recalcularComissoes(Set<Id> accIds) {
        if (accIds == null || accIds.isEmpty()) return;

        Map<Id, Account> contasParaAtualizar = new Map<Id, Account>();
        for (Id accId : accIds) {
            contasParaAtualizar.put(accId, new Account(Id = accId, ComissoesAcumuladas__c = 0));
        }

        Map<Id, Decimal> eventoPrecoPorId   = new Map<Id, Decimal>();
        Map<Id, Decimal> eventoTaxaPorId    = new Map<Id, Decimal>();
        Map<Id, Id>      eventoAccountPorId = new Map<Id, Id>();

        for (Evento__c ev : [
            SELECT Id, PrecoBilhete__c, Account__c, Account__r.TaxaComissao__c
            FROM   Evento__c
            WHERE  Account__c IN :accIds
        ]) {
            Decimal preco = ev.PrecoBilhete__c != null ? ev.PrecoBilhete__c : 0;
            // FIX: verificar se Account__r existe antes de aceder à taxa
            Decimal taxa  = (ev.Account__r != null && ev.Account__r.TaxaComissao__c != null)
                            ? ev.Account__r.TaxaComissao__c : 0;

            eventoPrecoPorId.put(ev.Id,   preco);
            eventoTaxaPorId.put(ev.Id,    taxa);
            eventoAccountPorId.put(ev.Id, ev.Account__c);
        }

        for (AggregateResult ar : [
            SELECT Evento__c eId, COUNT(Id) qtd
            FROM   Bilhete__c
            WHERE  Evento__r.Account__c IN :accIds
              AND  EstadoBilhete__c = 'Vendido'
            GROUP BY Evento__c
        ]) {
            Id      eId           = (Id)      ar.get('eId');
            Integer totalBilhetes = (Integer) ar.get('qtd');

            if (!eventoAccountPorId.containsKey(eId)) continue;

            Id      accId = eventoAccountPorId.get(eId);
            Decimal preco = eventoPrecoPorId.get(eId);
            Decimal taxa  = eventoTaxaPorId.get(eId);

            Decimal comissaoDesteEvento = (preco * taxa / 100) * totalBilhetes;

            if (contasParaAtualizar.containsKey(accId)) {
                contasParaAtualizar.get(accId).ComissoesAcumuladas__c += comissaoDesteEvento;
            }
        }

        update contasParaAtualizar.values();
    }
}