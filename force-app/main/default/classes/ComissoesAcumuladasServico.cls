public with sharing class ComissoesAcumuladasServico {

    public static void recalcularComissoes(Set<Id> accIds) {
        if (accIds == null || accIds.isEmpty()) return;

        // Não recalcular comissões no contexto do site/guest
        if (UserInfo.getUserType() == 'Guest') return;

        // 1. Inicializa as contas a 0 (excelente para quando o último bilhete é apagado)
        Map<Id, Account> contasParaAtualizar = new Map<Id, Account>();
        for (Id accId : accIds) {
            contasParaAtualizar.put(accId, new Account(Id = accId, ComissoesAcumuladas__c = 0));
        }

        // 2. UM ÚNICO MAPA: O construtor do Map já cria a chave (Id) e o valor (Evento__c) automaticamente
        Map<Id, Evento__c> eventosMap = new Map<Id, Evento__c>([
            SELECT Id, PrecoBilhete__c, Account__c, Account__r.TaxaComissao__c
            FROM Evento__c
            WHERE Account__c IN :accIds
        ]);

        // 3. Consulta agregada
        for (AggregateResult ar : [
            SELECT Evento__c eId, COUNT(Id) qtd
            FROM Bilhete__c
            WHERE Evento__r.Account__c IN :accIds
              AND EstadoBilhete__c = 'Vendido'
            GROUP BY Evento__c
        ]) {
            Id eId = (Id) ar.get('eId');
            Integer totalBilhetes = (Integer) ar.get('qtd');

            // Verifica se o evento está no nosso mapa
            if (eventosMap.containsKey(eId)) {
                Evento__c ev = eventosMap.get(eId);
                Id accId = ev.Account__c;
                
                // Extrai e trata os nulos
                Decimal preco = ev.PrecoBilhete__c != null ? ev.PrecoBilhete__c : 0;
                Decimal taxa  = (ev.Account__r != null && ev.Account__r.TaxaComissao__c != null)
                                ? ev.Account__r.TaxaComissao__c : 0;

                // Faz a matemática e soma ao total da conta correspondente
                Decimal comissaoDesteEvento = (preco * taxa / 100) * totalBilhetes;
                contasParaAtualizar.get(accId).ComissoesAcumuladas__c += comissaoDesteEvento;
            }
        }

        // 4. DML final
        if (!contasParaAtualizar.isEmpty()) {
            update contasParaAtualizar.values();
        }
    }
}