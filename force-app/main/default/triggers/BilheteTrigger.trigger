trigger BilheteTrigger on Bilhete__c (after insert, after update, after undelete, before delete) {

    Set<Id> accIds = new Set<Id>();

    if (Trigger.isDelete) {
        for (Bilhete__c b : [
            SELECT Evento__r.Account__c
            FROM   Bilhete__c
            WHERE  Id IN :Trigger.oldMap.keySet()
        ]) {
            if (b.Evento__r.Account__c != null) accIds.add(b.Evento__r.Account__c);
        }
    } else {
        // after insert: Trigger.newMap já tem os Ids atribuídos
        // after update / after undelete: igual
        for (Bilhete__c b : [
            SELECT Evento__r.Account__c
            FROM   Bilhete__c
            WHERE  Id IN :Trigger.newMap.keySet()
        ]) {
            if (b.Evento__r.Account__c != null) accIds.add(b.Evento__r.Account__c);
        }
    }

    if (!accIds.isEmpty()) {
        ComissoesAcumuladasServico.recalcularComissoes(accIds);
    }
}