for(Evento__c e : [SELECT Name, URLImagem__c FROM Evento__c]) {
    System.debug('--- EVENTO DATA ---');
    System.debug('Nome: ' + e.Name);
    System.debug('URL Imagem: ' + e.URLImagem__c);
}
