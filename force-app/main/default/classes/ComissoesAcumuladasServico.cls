public with sharing class ComissoesAcumuladasServico {

    public static void recalcularComissoes(Set<Id> accIds) {
        if (accIds == null || accIds.isEmpty()) return;

        // 1. Inicializa as contas e busca as taxas de comissão
        Map<Id, Account> contasParaAtualizar = new Map<Id, Account>();
        for (Account acc : [SELECT Id, TaxaComissao__c FROM Account WHERE Id IN :accIds]) {
            contasParaAtualizar.put(acc.Id, new Account(
                Id = acc.Id, 
                ComissoesAcumuladas__c = 0,
                TaxaComissao__c = acc.TaxaComissao__c // Guardamos para usar na matemática abaixo
            ));
        }

        // 2. Consulta agregada baseada em OrderItems (muito mais preciso que contar bilhetes)
        // Filtramos por itens que são bilhetes (código BLT-%) e ordens ativadas
        for (AggregateResult ar : [
            SELECT Order.Evento__r.Account__c accId, SUM(TotalPrice) total
            FROM OrderItem
            WHERE Order.Evento__r.Account__c IN :accIds
              AND Order.Status = 'Activated'
              AND PricebookEntry.Product2.ProductCode LIKE 'BLT-%'
            GROUP BY Order.Evento__r.Account__c
        ]) {
            Id accId = (Id) ar.get('accId');
            Decimal totalVendas = (Decimal) ar.get('total');
            
            if (contasParaAtualizar.containsKey(accId)) {
                Account acc = contasParaAtualizar.get(accId);
                Decimal taxa = acc.TaxaComissao__c != null ? acc.TaxaComissao__c : 0;
                
                // Calcula a comissão: (Total de Vendas * Taxa / 100)
                acc.ComissoesAcumuladas__c = (totalVendas * taxa / 100).setScale(2);
            }
        }

        // 3. DML final
        if (!contasParaAtualizar.isEmpty()) {
            update contasParaAtualizar.values();
        }
    }
}