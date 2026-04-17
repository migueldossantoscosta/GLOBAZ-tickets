
List<Bilhete__c> bills = [SELECT Id, Fila__c, Pessoa__c FROM Bilhete__c WHERE Evento__r.Name LIKE '%HYBRID%' AND Pessoa__c = null];
for (Bilhete__c b : bills) {
    // Assuming central based on clean letters A-N
    if (b.Fila__c != null && b.Fila__c.length() == 1) {
        b.Pessoa__c = 'plateia';
    }
}
update bills;
System.debug('>>> Fixed ' + bills.size() + ' Hybrid Theory tickets.');
