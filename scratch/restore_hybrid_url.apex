Evento__c e = [SELECT Id FROM Evento__c WHERE Id = 'a04fj000001fzADAAY' LIMIT 1];
e.URLImagem__c = 'https://orgfarm-64aee8f1dd-dev-ed--c.develop.vf.force.com/resource/1774969411000/HybridTheory?';
update e;
System.debug('>>> Restaurada a URL original do Hybrid Theory.');
