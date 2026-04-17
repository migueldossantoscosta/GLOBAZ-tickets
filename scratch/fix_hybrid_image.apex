Evento__c e = [SELECT Id FROM Evento__c WHERE Id = 'a04fj000001fzADAAY' LIMIT 1];
e.URLImagem__c = 'https://images.unsplash.com/photo-1540039155733-5bb30b53aa14?auto=format&fit=crop&w=1200&q=80';
update e;
System.debug('>>> Imagem do Hybrid Theory atualizada para URL pública.');
