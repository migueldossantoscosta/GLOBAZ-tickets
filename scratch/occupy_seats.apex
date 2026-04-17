
List<Bilhete__c> tkts = new List<Bilhete__c>();
for(Integer i=1; i<=6; i++) {
    tkts.add(new Bilhete__c(
        Evento__c = 'a04fj000001lGX8AAM',
        Fila__c = 'A',
        NumeroLugar__c = i,
        EstadoBilhete__c = 'Vendido'
    ));
}
insert tkts;
System.debug('Sucesso: A1-A6 ocupados.');
