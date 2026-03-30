List<Bilhete__c> bilhetes = [SELECT Id FROM Bilhete__c WHERE EstadoBilhete__c = 'Vendido' ORDER BY CreatedDate DESC LIMIT 1];
if(!bilhetes.isEmpty()) {
    try {
        EnviarBilhetePDF.enviarEmailFuturo(new List<Id>{bilhetes[0].Id});
        System.debug('SUCESSO - CHAMADA FEITA PARA: ' + bilhetes[0].Id);
    } catch (Exception e) {
        System.debug('ERRO NA CHAMADA: ' + e.getMessage());
    }
} else {
    System.debug('NENHUM BILHETE VENDIDO ENCONTRADO.');
}
