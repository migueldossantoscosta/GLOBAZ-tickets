trigger OrderTrigger on Order (after update) {
    Set<Id> accIds = new Set<Id>();
    for (Order o : Trigger.new) {
        Order oldO = Trigger.oldMap.get(o.Id);
        // Se a ordem foi ativada agora, recalcula as comissões do promotor
        if (o.Status == 'Activated' && oldO.Status != 'Activated' && o.Evento__c != null) {
            // Precisamos buscar o ID do promotor (Account__c no Evento)
            accIds.add(o.Evento__c); // Temporário: guardamos o ID do evento para buscar o promotor
        }
    }
    
    if (!accIds.isEmpty()) {
        Set<Id> promoterIds = new Set<Id>();
        for (Evento__c e : [SELECT Account__c FROM Evento__c WHERE Id IN :accIds]) {
            if (e.Account__c != null) promoterIds.add(e.Account__c);
        }
        if (!promoterIds.isEmpty()) {
            ComissoesAcumuladasServico.recalcularComissoes(promoterIds);
        }
    }
}
