Set<Id> promoterIds = new Set<Id>();
for (Evento__c e : [SELECT Account__c FROM Evento__c WHERE Account__c != null]) {
    promoterIds.add(e.Account__c);
}
if (!promoterIds.isEmpty()) {
    System.debug('>>> Recalculando comissões para ' + promoterIds.size() + ' promotores.');
    ComissoesAcumuladasServico.recalcularComissoes(promoterIds);
    System.debug('>>> Recálculo concluído.');
} else {
    System.debug('>>> Nenhum promotor encontrado com eventos.');
}
