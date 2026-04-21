public class BilheteTriggerHandler extends TriggerHandler {

    protected override void afterInsert() {
        processarContas();
    }

    protected override void afterUpdate() {
        processarContas();
    }

    protected override void afterUndelete() {
        processarContas();
    }

    protected override void beforeUpdate() {
        marcarChaveComoCancelada();
    }

    protected override void beforeDelete() {
        processarContasDelecao();
    }

    private void marcarChaveComoCancelada() {
        for (Bilhete__c b : (List<Bilhete__c>)Trigger.new) {
            Bilhete__c oldB = (Bilhete__c)Trigger.oldMap.get(b.Id);
            // Se o estado mudou para Cancelado nesta transação
            if (b.EstadoBilhete__c == 'Cancelado' && oldB.EstadoBilhete__c != 'Cancelado') {
                if (String.isNotBlank(b.ChaveUnica__c) && !b.ChaveUnica__c.contains('-CANCELADO')) {
                    b.ChaveUnica__c += '-CANCELADO';
                }
            }
        }
    }

    private void processarContas() {
        // Ignora guest users para não onerar o checkout 
        if (UserInfo.getUserType() == 'Guest') return;
        
        Set<Id> accIds = new Set<Id>();
        for (Bilhete__c b : [
            SELECT Evento__r.Account__c
            FROM   Bilhete__c
            WHERE  Id IN :Trigger.newMap.keySet()
        ]) {
            if (b.Evento__r.Account__c != null) accIds.add(b.Evento__r.Account__c);
        }
        recalcularSeNecessario(accIds);
    }

    private void processarContasDelecao() {
        if (UserInfo.getUserType() == 'Guest') return;

        Set<Id> accIds = new Set<Id>();
        for (Bilhete__c b : [
            SELECT Evento__r.Account__c
            FROM   Bilhete__c
            WHERE  Id IN :Trigger.oldMap.keySet()
        ]) {
            if (b.Evento__r.Account__c != null) accIds.add(b.Evento__r.Account__c);
        }
        recalcularSeNecessario(accIds);
    }

    private void recalcularSeNecessario(Set<Id> accIds) {
        if (!accIds.isEmpty()) {
            ComissoesAcumuladasServico.recalcularComissoes(accIds);
        }
    }
}