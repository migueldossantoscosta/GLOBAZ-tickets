public with sharing class CrmEventoMetricsController {
    
    @AuraEnabled(cacheable=true)
    public static EventoMetrics getMetrics(Id eventId) {
        // 1. Obter dados básicos do Evento
        Evento__c evt = [
            SELECT Id, CapacidadeMaxima__c, BilhetesVendidos__c, PrecoBilhete__c, BloquearVendas__c, EventoEsgotado__c
            FROM Evento__c
            WHERE Id = :eventId
            LIMIT 1
        ];

        // 2. Calcular Receita Real somando o TotalAmount das Encomendas Ativadas
        AggregateResult[] groupedResults = [
            SELECT SUM(TotalAmount) total 
            FROM Order 
            WHERE Evento__c = :eventId 
            AND (Status = 'Activated' OR Status = 'Completada' OR Status = 'Paga')
        ];
        
        Decimal receitaReal = 0;
        if (groupedResults.size() > 0 && groupedResults[0].get('total') != null) {
            receitaReal = (Decimal)groupedResults[0].get('total');
        }

        EventoMetrics m = new EventoMetrics();
        m.capacidadeTotal = (evt.CapacidadeMaxima__c != null) ? evt.CapacidadeMaxima__c.intValue() : 0;
        m.bilhetesVendidos = (evt.BilhetesVendidos__c != null) ? evt.BilhetesVendidos__c.intValue() : 0;
        
        // Atribuir a receita real calculada pelas Orders
        m.receitaTotal = receitaReal;
        
        // Bloqueado se atingiu lotação OU se foi bloqueado manualmente
        m.isEsgotado = evt.EventoEsgotado__c || evt.BloquearVendas__c;
        
        return m;
    }

    @AuraEnabled
    public static void bloquearVendas(Id eventId) {
        try {
            update new Evento__c(
                Id = eventId, 
                BloquearVendas__c = true
            );
        } catch (Exception e) {
            throw new AuraHandledException('Erro ao bloquear vendas: ' + e.getMessage());
        }
    }

    public class EventoMetrics {
        @AuraEnabled public Integer capacidadeTotal;
        @AuraEnabled public Integer bilhetesVendidos;
        @AuraEnabled public Decimal receitaTotal;
        @AuraEnabled public Boolean isEsgotado;
    }
}
