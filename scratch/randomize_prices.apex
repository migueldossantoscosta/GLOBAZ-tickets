List<Evento__c> evts = [SELECT Id, Name FROM Evento__c WHERE EstadoEvento__c != 'Cancelado'];
List<Pricebook2> pbs = [SELECT Id FROM Pricebook2 WHERE IsActive = true AND Name LIKE 'Pricebook - %'];

if(evts.isEmpty() || pbs.isEmpty()){
    System.debug('>>> Sem eventos ou pricebooks para processar.');
} else {
    for(Evento__c e : evts){
        Integer idx = Integer.valueOf(Math.floor(Math.random() * pbs.size()));
        e.Pricebook__c = pbs[idx].Id;
    }
    update evts;
    System.debug('>>> ' + evts.size() + ' eventos atualizados com pricebooks aleatórios.');
}
